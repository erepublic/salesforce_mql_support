#!/usr/bin/env node
/**
 * Enrich Salesforce MQL candidates with HubSpot behavior signals.
 *
 * Purpose:
 * - For "high-signal" MQLs (fit + behavior thresholds met) that are NOT tied to
 *   open opportunities, we often have little/no Salesforce-side timeline.
 * - This script pulls HubSpot contact properties like last URL / last visit
 *   timestamps / conversions so we can see what behavior data we might be
 *   leaving out of the narrative.
 *
 * Usage:
 *   node scripts/discovery/enrich_mql_candidates_with_hubspot.js --target-org mql-sandbox --top 20 --since-days 0
 *
 * Output:
 *   .local/discovery/hubspot_enriched_candidates/<timestamp>_<targetOrg>.json
 */

/* eslint-disable no-console */
const fs = require("node:fs");
const path = require("node:path");
const { execFileSync } = require("node:child_process");

const {
  getHubspotToken,
  getHubspotBaseUrl,
  searchContactIdByEmail,
  getContactProperties
} = require("../../infra/terraform/mql/lambda_src/hubspot_client");

function parseArgs(argv) {
  const args = {
    targetOrg: "mql-sandbox",
    top: 30,
    limit: 2000,
    sinceDays: 0,
    noOpenOpportunities: true,
    requireQualified: true
  };
  for (let i = 2; i < argv.length; i++) {
    const t = argv[i];
    if (!t.startsWith("--")) continue;
    const k = t.slice(2);
    const next = argv[i + 1];
    if (!next || next.startsWith("--")) args[k] = true;
    else {
      args[k] = next;
      i++;
    }
  }
  if (args["target-org"]) args.targetOrg = String(args["target-org"]).trim();
  if (args.top != null) args.top = Number(args.top);
  if (args.limit != null) args.limit = Number(args.limit);
  if (args["since-days"] != null) args.sinceDays = Number(args["since-days"]);
  if (!args.targetOrg) throw new Error("missing --target-org");
  return args;
}

function ensureDir(p) {
  fs.mkdirSync(p, { recursive: true });
}

function nowStamp() {
  const d = new Date();
  const pad = (n) => String(n).padStart(2, "0");
  return `${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}_${pad(
    d.getHours()
  )}${pad(d.getMinutes())}${pad(d.getSeconds())}`;
}

function run(cmd, args, opts = {}) {
  return execFileSync(cmd, args, {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
    ...opts
  });
}

function runSfJson(args) {
  const out = run("sf", args);
  return JSON.parse(out);
}

function safeInClause(ids) {
  const clean = (ids || []).filter(Boolean);
  if (!clean.length) return "(null)";
  const quoted = clean.map((id) => `'${String(id).replaceAll("'", "\\'")}'`);
  return `(${quoted.join(",")})`;
}

function toIsoDateFromMs(ms) {
  const n = Number(ms);
  if (!Number.isFinite(n)) return null;
  // HubSpot often returns "0" or empty for timestamps when unknown.
  if (n <= 0) return null;
  const d = new Date(n);
  return Number.isFinite(d.getTime()) ? d.toISOString().slice(0, 10) : null;
}

function pick(obj, key) {
  const v = obj ? obj[key] : null;
  return v === undefined ? null : v;
}

function formatUrlForDebug(url) {
  if (!url) return null;
  try {
    const u = new URL(String(url));
    u.search = "";
    u.hash = "";
    return u.toString();
  } catch {
    return String(url).slice(0, 240);
  }
}

function loadHubspotSecretFromEnvOrDotEnv() {
  // Mirrors discovery pattern: allow .env for local iteration.
  const envPath = path.resolve(process.cwd(), ".env");
  if (fs.existsSync(envPath)) {
    const lines = fs.readFileSync(envPath, "utf8").split(/\r?\n/);
    for (const line of lines) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith("#")) continue;
      const idx = trimmed.indexOf("=");
      if (idx === -1) continue;
      const k = trimmed.slice(0, idx).trim();
      let v = trimmed.slice(idx + 1).trim();
      if (
        (v.startsWith('"') && v.endsWith('"')) ||
        (v.startsWith("'") && v.endsWith("'"))
      ) {
        v = v.slice(1, -1);
      }
      if (!process.env[k]) process.env[k] = v;
    }
  }

  const token =
    process.env.HUBSPOT_PRIVATE_APP_TOKEN ||
    process.env.HUBSPOT_ACCESS_TOKEN ||
    process.env.HUBSPOT_TOKEN ||
    null;
  if (!token) return null;
  return { HUBSPOT_PRIVATE_APP_TOKEN: token };
}

async function main() {
  const args = parseArgs(process.argv);

  // 1) Get candidate list from existing Salesforce discovery logic.
  const candidateJson = run("node", [
    "scripts/discovery/find_good_mql_samples.js",
    "--target-org",
    args.targetOrg,
    "--since-days",
    String(args.sinceDays),
    "--limit",
    String(args.limit),
    "--top",
    String(args.top),
    "--no-open-opportunities",
    args.noOpenOpportunities ? "true" : "false",
    "--require-qualified",
    args.requireQualified ? "true" : "false",
    "--json-only"
  ]);
  const candidates = JSON.parse(candidateJson);
  const results = Array.isArray(candidates?.results) ? candidates.results : [];
  if (!results.length) {
    console.log(
      JSON.stringify(
        { ok: true, targetOrg: args.targetOrg, results: [] },
        null,
        2
      )
    );
    return;
  }

  // 2) Pull Contact emails for HubSpot lookup.
  const contactIds = Array.from(
    new Set(results.map((r) => r.contactId).filter(Boolean))
  );
  const contactRes = runSfJson([
    "data",
    "query",
    "--target-org",
    args.targetOrg,
    "--query",
    `SELECT Id, Email, Hubspot__c FROM Contact WHERE Id IN ${safeInClause(contactIds)} LIMIT 2000`,
    "--json"
  ]);
  const contacts = contactRes?.result?.records || [];
  const contactById = new Map(contacts.map((c) => [c.Id, c]));

  // 3) HubSpot enrichment.
  const hsSecret = loadHubspotSecretFromEnvOrDotEnv();
  const token = getHubspotToken(hsSecret);
  const baseUrl = getHubspotBaseUrl(hsSecret);
  const timeoutMs = 3500;

  const enriched = [];
  for (const r of results) {
    const c = contactById.get(r.contactId) || null;
    const email = c?.Email || null;
    let hsContactId = c?.Hubspot__c || null;
    let hsProps = null;
    let hsError = null;

    if (token && email) {
      try {
        const resolved =
          hsContactId ||
          (await searchContactIdByEmail({ token, baseUrl, email, timeoutMs }));
        hsContactId = resolved || hsContactId;
        if (resolved) {
          hsProps = await getContactProperties({
            token,
            baseUrl,
            hsContactId: resolved,
            timeoutMs,
            properties: [
              "hs_analytics_last_url",
              "hs_analytics_last_timestamp",
              "hs_analytics_last_visit_timestamp",
              "hs_analytics_num_page_views",
              "hs_analytics_num_visits",
              "hs_analytics_average_page_views",
              "hs_analytics_first_touch_converting_campaign",
              "hs_analytics_last_touch_converting_campaign",
              "recent_conversion_event_name",
              "recent_conversion_date",
              "first_conversion_event_name",
              "first_conversion_date",
              "engagement_score",
              "engagement_score_threshold",
              "hs_intent_page_views_last_30_days",
              "behavioral_interest__c",
              "industry_behavior_score",
              "industry_behavior_score_threshold",
              "industry_fit",
              "industry_fit_threshold"
            ]
          });
        }
      } catch (e) {
        hsError = e?.message || String(e);
      }
    }

    const lastUrl =
      formatUrlForDebug(pick(hsProps, "hs_analytics_last_url")) || null;
    const lastVisit =
      toIsoDateFromMs(pick(hsProps, "hs_analytics_last_visit_timestamp")) ||
      toIsoDateFromMs(pick(hsProps, "hs_analytics_last_timestamp")) ||
      null;

    enriched.push({
      ...r,
      contactEmail: email,
      hubspot: {
        ok: Boolean(hsProps),
        hsContactId: hsContactId || null,
        lastVisitDate: lastVisit,
        lastUrl,
        numPageViews: pick(hsProps, "hs_analytics_num_page_views"),
        numVisits: pick(hsProps, "hs_analytics_num_visits"),
        intentPageViewsLast30Days: pick(
          hsProps,
          "hs_intent_page_views_last_30_days"
        ),
        recentConversion: pick(hsProps, "recent_conversion_event_name"),
        recentConversionDate: pick(hsProps, "recent_conversion_date"),
        lastTouchCampaign: pick(
          hsProps,
          "hs_analytics_last_touch_converting_campaign"
        ),
        behavioralInterest: pick(hsProps, "behavioral_interest__c"),
        error: hsError
      }
    });
  }

  const outDir = path.resolve(
    process.cwd(),
    ".local",
    "discovery",
    "hubspot_enriched_candidates"
  );
  ensureDir(outDir);
  const outPath = path.join(outDir, `${nowStamp()}_${args.targetOrg}.json`);
  fs.writeFileSync(
    outPath,
    JSON.stringify(
      {
        metadata: {
          generatedAt: new Date().toISOString(),
          targetOrg: args.targetOrg,
          args: {
            sinceDays: args.sinceDays,
            limit: args.limit,
            top: args.top,
            noOpenOpportunities: args.noOpenOpportunities,
            requireQualified: args.requireQualified
          }
        },
        results: enriched
      },
      null,
      2
    )
  );

  console.log(outPath);
  console.log(
    JSON.stringify(
      {
        count: enriched.length,
        withHubspot: enriched.filter((x) => x.hubspot?.ok).length,
        withLastUrl: enriched.filter((x) => x.hubspot?.lastUrl).length
      },
      null,
      2
    )
  );
}

main().catch((e) => {
  console.error(e?.message || e);
  process.exit(1);
});
