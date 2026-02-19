#!/usr/bin/env node
/**
 * Find Salesforce MQLs whose Contacts have concrete HubSpot behavior signals.
 *
 * Why:
 * The "Fit and Behavior Threshold Reached" MQLs in sandbox can have a non-zero
 * behavior score in Salesforce but still have *no* page/conversion details
 * available in either Salesforce (no Sales_Lead__c web activity) or HubSpot
 * (hs_analytics_* empty). This script inverts the search:
 *   HubSpot (has pageviews / last url / conversions) -> Salesforce Contact -> latest MQL
 *
 * Usage:
 *   node scripts/discovery/find_hubspot_activity_mql_candidates.js --target-org mql-sandbox --limit 60 --top 15 --require-no-open-opps true
 */

/* eslint-disable no-console */
const fs = require("node:fs");
const path = require("node:path");
const { execFileSync } = require("node:child_process");

function parseArgs(argv) {
  const args = {
    targetOrg: "mql-sandbox",
    limit: 60,
    top: 15,
    requireNoOpenOpps: true
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
  if (args.limit != null) args.limit = Number(args.limit);
  if (args.top != null) args.top = Number(args.top);
  if (args["require-no-open-opps"] != null)
    args.requireNoOpenOpps = String(args["require-no-open-opps"]) !== "false";
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

function safeInClauseStrings(values) {
  const clean = (values || []).filter(Boolean);
  if (!clean.length) return "(null)";
  const quoted = clean.map((v) => `'${String(v).replaceAll("'", "\\'")}'`);
  return `(${quoted.join(",")})`;
}

function chunk(arr, size) {
  const out = [];
  for (let i = 0; i < arr.length; i += size) out.push(arr.slice(i, i + size));
  return out;
}

function loadEnvDotEnvIfPresent() {
  const envPath = path.resolve(process.cwd(), ".env");
  if (!fs.existsSync(envPath)) return;
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

function getHubspotTokenFromEnv() {
  loadEnvDotEnvIfPresent();
  return (
    process.env.HUBSPOT_PRIVATE_APP_TOKEN ||
    process.env.HUBSPOT_ACCESS_TOKEN ||
    process.env.HUBSPOT_TOKEN ||
    null
  );
}

function getHubspotBaseUrlFromEnv() {
  // Support the Lambda secret pattern too, but keep discovery simple.
  return process.env.HUBSPOT_BASE_URL || "https://api.hubapi.com";
}

async function hsSearchContacts({
  token,
  baseUrl,
  filterGroups,
  properties,
  limit,
  after
}) {
  const url = `${baseUrl.replace(/\/+$/, "")}/crm/v3/objects/contacts/search`;
  const body = {
    filterGroups,
    properties,
    limit,
    after
  };
  const ac = new AbortController();
  const t = setTimeout(() => ac.abort(), 5000);
  try {
    const res = await fetch(url, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify(body),
      signal: ac.signal
    });
    if (!res.ok) {
      const text = await res.text().catch(() => "");
      throw new Error(
        `HubSpot search failed: ${res.status} ${res.statusText} ${text.slice(0, 400)}`
      );
    }
    return await res.json();
  } finally {
    clearTimeout(t);
  }
}

function numOrNull(v) {
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
}

async function main() {
  const args = parseArgs(process.argv);
  const token = getHubspotTokenFromEnv();
  if (!token) {
    throw new Error(
      "Missing HubSpot token. Set HUBSPOT_PRIVATE_APP_TOKEN (or HUBSPOT_ACCESS_TOKEN) in your environment/.env."
    );
  }
  const baseUrl = getHubspotBaseUrlFromEnv();

  // 1) Pull HubSpot contacts with concrete behavior signals.
  const properties = [
    "email",
    "firstname",
    "lastname",
    "company",
    "lifecyclestage",
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

  // "GT 0 pageviews" tends to be the most reliable "specific behavior exists" filter.
  const filterGroups = [
    {
      filters: [
        {
          propertyName: "hs_analytics_num_page_views",
          operator: "GT",
          value: "0"
        }
      ]
    }
  ];

  let after = undefined;
  const hsContacts = [];
  while (hsContacts.length < args.limit) {
    const page = await hsSearchContacts({
      token,
      baseUrl,
      filterGroups,
      properties,
      limit: Math.min(100, args.limit - hsContacts.length),
      after
    });
    const results = Array.isArray(page?.results) ? page.results : [];
    hsContacts.push(...results);
    after = page?.paging?.next?.after;
    if (!after || results.length === 0) break;
  }

  const hsByEmail = new Map();
  for (const c of hsContacts) {
    const email = c?.properties?.email
      ? String(c.properties.email).toLowerCase()
      : null;
    if (!email) continue;
    // keep first match
    if (!hsByEmail.has(email)) hsByEmail.set(email, c);
  }

  const emails = Array.from(hsByEmail.keys());
  if (!emails.length) {
    console.log(
      JSON.stringify(
        { ok: true, reason: "No HubSpot contacts matched filters." },
        null,
        2
      )
    );
    return;
  }

  // 2) Map to Salesforce Contacts by Email.
  const sfContacts = [];
  for (const batch of chunk(emails, 40)) {
    const res = runSfJson([
      "data",
      "query",
      "--target-org",
      args.targetOrg,
      "--query",
      `SELECT Id, Email, AccountId FROM Contact WHERE Email IN ${safeInClauseStrings(batch)} LIMIT 2000`,
      "--json"
    ]);
    sfContacts.push(...(res?.result?.records || []));
  }

  const sfByEmail = new Map();
  for (const c of sfContacts) {
    const email = c?.Email ? String(c.Email).toLowerCase() : null;
    if (!email) continue;
    if (!sfByEmail.has(email)) sfByEmail.set(email, c);
  }

  const contactIds = Array.from(sfByEmail.values()).map((c) => c.Id);
  if (!contactIds.length) {
    console.log(
      JSON.stringify(
        {
          ok: true,
          reason: "No Salesforce contacts found for HubSpot emails.",
          hubspotEmails: emails.length
        },
        null,
        2
      )
    );
    return;
  }

  // 3) Latest MQL per contact.
  const mqlRes = runSfJson([
    "data",
    "query",
    "--target-org",
    args.targetOrg,
    "--query",
    `SELECT Id, Contact__c, CreatedDate, MQL_Status__c, Lead_Source__c, Opportunity__c
     FROM MQL__c
     WHERE Contact__c IN ${safeInClauseStrings(contactIds)}
     ORDER BY Contact__c, CreatedDate DESC
     LIMIT 5000`,
    "--json"
  ]);
  const mqls = mqlRes?.result?.records || [];
  const latestMqlByContactId = new Map();
  for (const m of mqls) {
    const cid = m.Contact__c;
    if (!cid) continue;
    if (!latestMqlByContactId.has(cid)) latestMqlByContactId.set(cid, m);
  }
  const contactsWithMql = latestMqlByContactId.size;

  // 4) Open opportunity count via OCR.
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
       WHERE ContactId IN ${safeInClauseStrings(contactIds)}
       AND Opportunity.IsClosed = false
       GROUP BY ContactId`,
      "--json"
    ]);
    const rows = ocrRes?.result?.records || [];
    openOppCountByContact = new Map(
      rows.map((r) => [r.contactId, Number(r.cnt || 0)])
    );
  } catch {
    // ignore; some orgs restrict relationship filters
  }

  // 5) Join + filter + rank.
  const joined = [];
  for (const [email, hs] of hsByEmail.entries()) {
    const sf = sfByEmail.get(email) || null;
    if (!sf) continue;
    const mql = latestMqlByContactId.get(sf.Id) || null;
    if (!mql) continue;
    const openOppCount = openOppCountByContact.get(sf.Id) || 0;
    if (args.requireNoOpenOpps && openOppCount > 0) continue;

    const props = hs?.properties || {};
    joined.push({
      mqlId: mql.Id,
      contactId: sf.Id,
      email,
      mqlCreatedDate: mql.CreatedDate,
      mqlStatus: mql.MQL_Status__c,
      leadSource: mql.Lead_Source__c,
      openOppCount,
      hubspot: {
        hsContactId: hs.id,
        lastUrl: props.hs_analytics_last_url || null,
        lastVisitTs: props.hs_analytics_last_visit_timestamp || null,
        numPageViews: numOrNull(props.hs_analytics_num_page_views),
        numVisits: numOrNull(props.hs_analytics_num_visits),
        recentConversion: props.recent_conversion_event_name || null,
        recentConversionDate: props.recent_conversion_date || null
      }
    });
  }

  joined.sort(
    (a, b) => (b.hubspot.numPageViews || 0) - (a.hubspot.numPageViews || 0)
  );
  const top = joined.slice(0, args.top);

  console.log(
    JSON.stringify(
      {
        targetOrg: args.targetOrg,
        hubspotMatched: emails.length,
        salesforceContactsMatched: contactIds.length,
        contactsWithMql,
        results: top
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
