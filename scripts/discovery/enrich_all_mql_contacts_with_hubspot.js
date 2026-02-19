#!/usr/bin/env node
/**
 * Enrich ALL sandbox MQL contacts with HubSpot behavior signals.
 *
 * This helps answer: "are we leaving out HubSpot behavior data?" vs "does the
 * sandbox MQL dataset simply not have HubSpot analytics/conversion details?"
 *
 * Usage:
 *   node scripts/discovery/enrich_all_mql_contacts_with_hubspot.js --target-org mql-sandbox --max-contacts 120
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
  const args = { targetOrg: "mql-sandbox", maxContacts: 120 };
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
  if (args["max-contacts"] != null)
    args.maxContacts = Number(args["max-contacts"]);
  return args;
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

function loadHubspotSecretFromEnvOrDotEnv() {
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

function num(v) {
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
}

async function main() {
  const args = parseArgs(process.argv);

  const mqlRes = runSfJson([
    "data",
    "query",
    "--target-org",
    args.targetOrg,
    "--query",
    "SELECT Id, Contact__c, CreatedDate, MQL_Status__c, Lead_Source__c, Opportunity__c FROM MQL__c ORDER BY CreatedDate DESC LIMIT 2000",
    "--json"
  ]);
  const mqls = mqlRes?.result?.records || [];
  const latestMqlByContactId = new Map();
  for (const m of mqls) {
    const cid = m.Contact__c;
    if (!cid) continue;
    // Query is ordered by CreatedDate DESC, so first per contact wins.
    if (!latestMqlByContactId.has(cid)) latestMqlByContactId.set(cid, m);
  }
  const contactIds = Array.from(
    new Set(mqls.map((m) => m.Contact__c).filter(Boolean))
  ).slice(0, args.maxContacts);

  const contactsRes = runSfJson([
    "data",
    "query",
    "--target-org",
    args.targetOrg,
    "--query",
    `SELECT Id, Email, Hubspot__c FROM Contact WHERE Id IN ${safeInClause(contactIds)} LIMIT 2000`,
    "--json"
  ]);
  const contacts = contactsRes?.result?.records || [];
  const contactById = new Map(contacts.map((c) => [c.Id, c]));

  // open opp counts
  let openOppCountByContact = new Map();
  try {
    const ocrRes = runSfJson([
      "data",
      "query",
      "--target-org",
      args.targetOrg,
      "--query",
      `SELECT ContactId contactId, COUNT(Id) cnt
       FROM OpportunityContactRole
       WHERE ContactId IN ${safeInClause(contactIds)}
       AND Opportunity.IsClosed = false
       GROUP BY ContactId`,
      "--json"
    ]);
    const rows = ocrRes?.result?.records || [];
    openOppCountByContact = new Map(
      rows.map((r) => [r.contactId, Number(r.cnt || 0)])
    );
  } catch {
    // ignore
  }

  const hsSecret = loadHubspotSecretFromEnvOrDotEnv();
  const token = getHubspotToken(hsSecret);
  const baseUrl = getHubspotBaseUrl(hsSecret);
  const timeoutMs = 4000;

  const hsPropsWanted = [
    "hs_analytics_last_url",
    "hs_analytics_last_visit_timestamp",
    "hs_analytics_num_page_views",
    "hs_analytics_num_visits",
    "recent_conversion_event_name",
    "recent_conversion_date",
    "first_conversion_event_name",
    "first_conversion_date",
    "engagement_score",
    "behavioral_interest__c"
  ];

  const enriched = [];
  for (const cid of contactIds) {
    const c = contactById.get(cid) || null;
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
            properties: hsPropsWanted,
            timeoutMs
          });
        }
      } catch (e) {
        hsError = e?.message || String(e);
      }
    }

    const openOppCount = openOppCountByContact.get(cid) || 0;
    const mql = latestMqlByContactId.get(cid) || null;
    enriched.push({
      contactId: cid,
      email,
      hsContactId: hsContactId || null,
      openOppCount,
      latestMql: mql
        ? {
            id: mql.Id,
            createdDate: mql.CreatedDate,
            status: mql.MQL_Status__c,
            leadSource: mql.Lead_Source__c,
            opportunityId: mql.Opportunity__c || null
          }
        : null,
      hubspot: {
        ok: Boolean(hsProps),
        lastUrl: hsProps?.hs_analytics_last_url || null,
        numPageViews: num(hsProps?.hs_analytics_num_page_views),
        numVisits: num(hsProps?.hs_analytics_num_visits),
        recentConversion: hsProps?.recent_conversion_event_name || null,
        recentConversionDate: hsProps?.recent_conversion_date || null,
        engagementScore: num(hsProps?.engagement_score),
        behavioralInterest: hsProps?.behavioral_interest__c || null,
        error: hsError
      }
    });
  }

  // keep only the ones with any meaningful signal
  const withSignals = enriched.filter((e) => {
    const hs = e.hubspot || {};
    return (
      (hs.numPageViews || 0) > 0 ||
      (hs.numVisits || 0) > 0 ||
      Boolean(hs.lastUrl) ||
      Boolean(hs.recentConversion)
    );
  });

  const outDir = path.resolve(
    process.cwd(),
    ".local",
    "discovery",
    "hubspot_enriched_all_mql_contacts"
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
          maxContacts: args.maxContacts
        },
        counts: {
          mqls: mqls.length,
          contactsConsidered: contactIds.length,
          withSignals: withSignals.length
        },
        results: withSignals
      },
      null,
      2
    )
  );

  console.log(outPath);
  console.log(JSON.stringify({ withSignals: withSignals.length }, null, 2));
}

main().catch((e) => {
  console.error(e?.message || e);
  process.exit(1);
});
