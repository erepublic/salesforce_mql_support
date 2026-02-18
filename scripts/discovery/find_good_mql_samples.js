#!/usr/bin/env node
/**
 * Find "good" MQL samples for LLM testing.
 *
 * We want MQLs that have:
 * - meaningful MQL fields populated (notes, lead source detail, conversion/rejection context, links)
 * - enough activity/timeline signal (tasks/events/emails/campaign touches)
 * - scoring signal fields present on Contact (behavior/fit/threshold fields)
 *
 * This script uses `sf` CLI for auth/queries.
 *
 * Usage:
 *   node scripts/discovery/find_good_mql_samples.js --target-org mql-sandbox --since-days 365 --limit 200 --top 10
 */
/* eslint-disable no-console */

const { execFileSync } = require("node:child_process");

function parseArgs(argv) {
  const args = {};
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
  return args;
}

function runSfJson(sfArgs) {
  const out = execFileSync("sf", [...sfArgs, "--json"], {
    encoding: "utf8",
    maxBuffer: 50 * 1024 * 1024
  });
  // sf can emit a warning line before JSON sometimes; strip leading junk.
  const i = out.indexOf("{");
  const j = out.lastIndexOf("}");
  const raw = i >= 0 && j >= i ? out.slice(i, j + 1) : out;
  const parsed = JSON.parse(raw);
  if (parsed.status !== 0) {
    throw new Error(parsed?.message || "sf CLI error");
  }
  return parsed.result;
}

function queryRecords({ targetOrg, soql }) {
  const res = runSfJson([
    "data",
    "query",
    "--query",
    soql,
    "--target-org",
    targetOrg
  ]);
  return res?.records || [];
}

function safeInClause(ids) {
  const clean = (ids || []).filter(Boolean);
  if (!clean.length) return "(null)";
  const quoted = clean.map((id) => `'${String(id).replaceAll("'", "\\'")}'`);
  return `(${quoted.join(",")})`;
}

function boolish(v) {
  if (v === true) return true;
  if (v === false) return false;
  if (v === "true") return true;
  if (v === "false") return false;
  return null;
}

function scoreMqlRow(m) {
  let score = 0;
  const reasons = [];

  function add(points, why) {
    score += points;
    reasons.push({ points, why });
  }

  if (m.Lead_Notes__c) add(4, "has Lead_Notes__c");
  if (m.Lead_Source_Detail__c) add(2, "has Lead_Source_Detail__c");
  if (
    m.Lead_Detail_1__c ||
    m.Lead_Detail_2__c ||
    m.Lead_Detail_3__c ||
    m.Lead_Detail_4__c
  )
    add(1, "has Lead_Detail_*");

  if (m.Contact_Us__c) add(3, "linked Contact_Us__c");
  if (m.Campaign__c) add(2, "linked Campaign__c");
  if (m.Opportunity__c) add(3, "linked Opportunity__c");

  if (m.MQL_Status__c === "Converted") add(4, "MQL_Status__c Converted");
  if (m.MQL_Status__c === "Rejected") add(4, "MQL_Status__c Rejected");

  if (m.Conversion_Type__c) add(1, "has Conversion_Type__c");
  if (m.Product__c || m.Product_Name__c) add(1, "has Product");

  return { score, reasons };
}

function scoreContactSignals(c) {
  let score = 0;
  const reasons = [];

  function add(points, why) {
    score += points;
    reasons.push({ points, why });
  }

  const behaviorScore = c.HubSpot_Private_Sector_Behavior_Score__c;
  const behaviorDate = c.HubSpot_Private_Sector_Behavior_Date__c;
  const fitScore = c.HubSpot_Private_Sector_Contact_Fit__c;
  const fitThreshold = c.Contact_Fit_Threshold__c;
  const engagementScore = c.HubSpot_Engagement_Score__c;
  const engagementThreshold = c.HubSpot_Engagement_Score_Threshold__c;

  if (behaviorScore != null) add(2, "has behavior score");
  if (behaviorDate) add(1, "has behavior score date");
  if (fitScore != null) add(2, "has contact fit score");
  if (fitThreshold != null) add(2, "has contact fit threshold");
  if (engagementScore != null) add(1, "has engagement score");
  if (engagementThreshold != null) add(1, "has engagement score threshold");

  const nonQual = boolish(c.Private_Sector_Non_Qual__c);
  const acctNonQual = boolish(c.Private_Sector_Acct_Non_Qual__c);
  if (nonQual === false)
    add(1, "contact qualified (Private_Sector_Non_Qual__c=false)");
  if (acctNonQual === false)
    add(
      1,
      "account qualified flag on contact (Private_Sector_Acct_Non_Qual__c=false)"
    );

  return { score, reasons };
}

function mergeCountsById(rows, idField, countField) {
  const m = new Map();
  for (const r of rows || []) {
    const id = r?.[idField];
    const c = Number(r?.[countField] ?? 0);
    if (id) m.set(id, c);
  }
  return m;
}

async function main() {
  const args = parseArgs(process.argv);
  const targetOrg = args["target-org"] || "mql-sandbox";
  const sinceDays = Math.max(
    1,
    Math.min(365, Number(args["since-days"] || 365))
  );
  const limit = Math.max(10, Math.min(500, Number(args.limit || 200)));
  const top = Math.max(5, Math.min(50, Number(args.top || 10)));
  const jsonOnly = args["json-only"] === true;
  const leadSourceFilter = args["lead-source"]
    ? String(args["lead-source"])
    : null;

  const sinceExpr = `LAST_N_DAYS:${sinceDays}`;

  const mqlWhere = [`CreatedDate = ${sinceExpr}`];
  if (leadSourceFilter) {
    mqlWhere.push(
      `Lead_Source__c = '${leadSourceFilter.replaceAll("'", "\\'")}'`
    );
  }

  const mqlSoql =
    "SELECT Id, CreatedDate, LastModifiedDate, Contact__c, " +
    "Lead_Source__c, Lead_Source_Detail__c, Lead_Detail_1__c, Lead_Detail_2__c, Lead_Detail_3__c, Lead_Detail_4__c, " +
    "Lead_Notes__c, MQL_Status__c, Conversion_Type__c, Conversion_Date__c, Opportunity__c, Campaign__c, Contact_Us__c, " +
    "Product__c, Product_Name__c " +
    `FROM MQL__c WHERE ${mqlWhere.join(" AND ")} ORDER BY CreatedDate DESC LIMIT ${limit}`;

  if (!jsonOnly)
    console.log(
      `Querying recent MQLs (sinceDays=${sinceDays}, limit=${limit})...`
    );
  const mqls = queryRecords({ targetOrg, soql: mqlSoql });
  if (!mqls.length) {
    if (!jsonOnly) console.log("No MQLs found in window.");
    process.exit(0);
  }

  const contactIds = Array.from(
    new Set(mqls.map((m) => m.Contact__c).filter(Boolean))
  );
  const contactSoql =
    "SELECT Id, " +
    "Private_Sector_Non_Qual__c, Private_Sector_Acct_Non_Qual__c, " +
    "HubSpot_Private_Sector_Behavior_Score__c, HubSpot_Private_Sector_Behavior_Date__c, " +
    "HubSpot_Private_Sector_Contact_Fit__c, Contact_Fit_Threshold__c, " +
    "HubSpot_Engagement_Score__c, HubSpot_Engagement_Score_Threshold__c " +
    `FROM Contact WHERE Id IN ${safeInClause(contactIds)} LIMIT ${Math.min(contactIds.length, 2000)}`;

  if (!jsonOnly)
    console.log(`Querying ${contactIds.length} Contacts for score signals...`);
  const contacts = queryRecords({ targetOrg, soql: contactSoql });
  const contactById = new Map(contacts.map((c) => [c.Id, c]));

  if (!jsonOnly)
    console.log(
      "Querying activity counts (Tasks/Events/EmailMessage/CampaignMember)..."
    );
  const whoIn = safeInClause(contactIds);

  const taskCounts = mergeCountsById(
    queryRecords({
      targetOrg,
      soql: `SELECT WhoId whoId, COUNT(Id) cnt FROM Task WHERE WhoId IN ${whoIn} AND CreatedDate = ${sinceExpr} GROUP BY WhoId`
    }),
    "whoId",
    "cnt"
  );
  const eventCounts = mergeCountsById(
    queryRecords({
      targetOrg,
      soql: `SELECT WhoId whoId, COUNT(Id) cnt FROM Event WHERE WhoId IN ${whoIn} AND CreatedDate = ${sinceExpr} GROUP BY WhoId`
    }),
    "whoId",
    "cnt"
  );

  // EmailMessage is often permissioned; treat failures as zero.
  let emailCounts = new Map();
  try {
    emailCounts = mergeCountsById(
      queryRecords({
        targetOrg,
        soql: `SELECT ParentId whoId, COUNT(Id) cnt FROM EmailMessage WHERE ParentId IN ${whoIn} AND CreatedDate = ${sinceExpr} GROUP BY ParentId`
      }),
      "whoId",
      "cnt"
    );
  } catch {
    // ignore
  }

  let campaignCounts = new Map();
  try {
    campaignCounts = mergeCountsById(
      queryRecords({
        targetOrg,
        soql: `SELECT ContactId whoId, COUNT(Id) cnt FROM CampaignMember WHERE ContactId IN ${whoIn} AND CreatedDate = LAST_N_DAYS:365 GROUP BY ContactId`
      }),
      "whoId",
      "cnt"
    );
  } catch {
    // ignore
  }

  function activityScoreFor(contactId) {
    const t = Number(taskCounts.get(contactId) || 0);
    const e = Number(eventCounts.get(contactId) || 0);
    const em = Number(emailCounts.get(contactId) || 0);
    const cm = Number(campaignCounts.get(contactId) || 0);
    const score =
      Math.min(t, 10) * 0.6 +
      Math.min(e, 10) * 0.6 +
      Math.min(em, 10) * 0.3 +
      Math.min(cm, 10) * 0.3;
    return {
      score,
      counts: { tasks: t, events: e, emails: em, campaignMembers: cm }
    };
  }

  const ranked = mqls
    .map((m) => {
      const base = scoreMqlRow(m);
      const c = m.Contact__c ? contactById.get(m.Contact__c) : null;
      const cs = c ? scoreContactSignals(c) : { score: 0, reasons: [] };
      const act = m.Contact__c
        ? activityScoreFor(m.Contact__c)
        : { score: 0, counts: {} };
      const total = base.score + cs.score + act.score;
      return {
        mqlId: m.Id,
        contactId: m.Contact__c || null,
        createdDate: m.CreatedDate,
        leadSource: m.Lead_Source__c || null,
        status: m.MQL_Status__c || null,
        totalScore: Math.round(total * 10) / 10,
        activityCounts: act.counts,
        why: [
          ...base.reasons,
          ...cs.reasons,
          {
            points: act.score,
            why: `activityCounts=${JSON.stringify(act.counts)}`
          }
        ].sort((a, b) => b.points - a.points)
      };
    })
    .sort((a, b) => b.totalScore - a.totalScore)
    .slice(0, top);

  if (!jsonOnly) {
    console.log("\nTop candidates:");
    for (const r of ranked) {
      console.log(
        `- ${r.mqlId} (score=${r.totalScore}) leadSource=${r.leadSource || "n/a"} status=${r.status || "n/a"} tasks=${r.activityCounts.tasks || 0} events=${r.activityCounts.events || 0} emails=${r.activityCounts.emails || 0} campaigns=${r.activityCounts.campaignMembers || 0}`
      );
    }
    console.log("");
  }

  const payload = {
    targetOrg,
    sinceDays,
    limit,
    top,
    leadSourceFilter,
    results: ranked
  };
  if (jsonOnly) {
    process.stdout.write(JSON.stringify(payload));
  } else {
    console.log("JSON:");
    console.log(JSON.stringify(payload, null, 2));
  }
}

main().catch((e) => {
  console.error(e?.message || e);
  process.exit(1);
});
