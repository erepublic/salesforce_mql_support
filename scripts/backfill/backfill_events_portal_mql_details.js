/* eslint-disable no-console */
const fs = require("node:fs");
const path = require("node:path");
const { execFileSync } = require("node:child_process");

function runSfJson(args) {
  return JSON.parse(
    execFileSync("sf", args, {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"]
    })
  );
}

function parseArgs(argv) {
  const args = {
    targetOrg: "mql-prod",
    apply: false,
    limit: null,
    createdAfter: null,
    outputDir: "/tmp",
    waitMinutes: 30
  };

  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--target-org") args.targetOrg = String(argv[++i] || "").trim();
    else if (a === "--apply") args.apply = true;
    else if (a === "--limit") args.limit = Number(argv[++i]);
    else if (a === "--created-after")
      args.createdAfter = String(argv[++i] || "").trim();
    else if (a === "--output-dir")
      args.outputDir = String(argv[++i] || "").trim();
    else if (a === "--wait-minutes") args.waitMinutes = Number(argv[++i]);
  }

  if (!args.targetOrg) throw new Error("Missing --target-org");
  if (
    args.limit !== null &&
    (!Number.isInteger(args.limit) || args.limit <= 0)
  ) {
    throw new Error("--limit must be a positive integer");
  }
  if (
    !Number.isInteger(args.waitMinutes) ||
    args.waitMinutes <= 0 ||
    args.waitMinutes > 120
  ) {
    throw new Error("--wait-minutes must be an integer between 1 and 120");
  }

  return args;
}

function buildQuery({ limit, createdAfter }) {
  const whereParts = [
    "Lead_Source__c = 'Events Portal'",
    "Opportunity__c != null",
    "(" +
      [
        "Lead_Source_Detail__c = null",
        "Lead_Detail_1__c = null",
        "Lead_Detail_2__c = null",
        "Lead_Detail_3__c = null",
        "Lead_Detail_4__c = null",
        "Campaign__c = null"
      ].join(" OR ") +
      ")"
  ];

  if (createdAfter) {
    whereParts.push(`CreatedDate >= ${createdAfter}`);
  }

  let q =
    "SELECT " +
    [
      "Id",
      "CreatedDate",
      "Lead_Source_Detail__c",
      "Lead_Detail_1__c",
      "Lead_Detail_2__c",
      "Lead_Detail_3__c",
      "Lead_Detail_4__c",
      "Campaign__c",
      "Opportunity__c",
      "Opportunity__r.Lead_Source_Detail__c",
      "Opportunity__r.Lead_Detail_1__c",
      "Opportunity__r.Lead_Detail_2__c",
      "Opportunity__r.Lead_Detail_3__c",
      "Opportunity__r.Lead_Detail_4__c",
      "Opportunity__r.CampaignId"
    ].join(", ") +
    " FROM MQL__c WHERE " +
    whereParts.join(" AND ") +
    " ORDER BY CreatedDate DESC";

  if (limit) q += ` LIMIT ${limit}`;
  return q;
}

function escapeCsv(value) {
  if (value === null || value === undefined) return "";
  const s = String(value);
  if (/[",\n\r]/.test(s)) return `"${s.replace(/"/g, '""')}"`;
  return s;
}

function toCsv(rows, headers) {
  const lines = [headers.join(",")];
  for (const row of rows) {
    const line = headers.map((h) => escapeCsv(row[h])).join(",");
    lines.push(line);
  }
  return lines.join("\n") + "\n";
}

function pickBackfillRow(mql) {
  const opp = mql.Opportunity__r || {};
  const out = { Id: mql.Id };
  let changed = false;

  const fieldPairs = [
    ["Lead_Source_Detail__c", "Lead_Source_Detail__c"],
    ["Lead_Detail_1__c", "Lead_Detail_1__c"],
    ["Lead_Detail_2__c", "Lead_Detail_2__c"],
    ["Lead_Detail_3__c", "Lead_Detail_3__c"],
    ["Lead_Detail_4__c", "Lead_Detail_4__c"]
  ];

  for (const [mqlField, oppField] of fieldPairs) {
    const mqlVal = mql[mqlField];
    const oppVal = opp[oppField];
    if ((mqlVal === null || mqlVal === "") && oppVal) {
      out[mqlField] = String(oppVal);
      changed = true;
    }
  }

  if ((mql.Campaign__c === null || mql.Campaign__c === "") && opp.CampaignId) {
    out.Campaign__c = String(opp.CampaignId);
    changed = true;
  }

  return changed ? out : null;
}

function summarize(rows) {
  const counters = {
    Lead_Source_Detail__c: 0,
    Lead_Detail_1__c: 0,
    Lead_Detail_2__c: 0,
    Lead_Detail_3__c: 0,
    Lead_Detail_4__c: 0,
    Campaign__c: 0
  };

  for (const row of rows) {
    for (const key of Object.keys(counters)) {
      if (Object.prototype.hasOwnProperty.call(row, key)) counters[key] += 1;
    }
  }
  return counters;
}

function main() {
  const args = parseArgs(process.argv);
  const soql = buildQuery(args);

  const res = runSfJson([
    "data",
    "query",
    "--target-org",
    args.targetOrg,
    "--query",
    soql,
    "--json"
  ]);
  const records = res?.result?.records || [];

  const updates = [];
  for (const r of records) {
    const row = pickBackfillRow(r);
    if (row) updates.push(row);
  }

  const stats = summarize(updates);
  console.log(
    JSON.stringify(
      {
        mode: args.apply ? "apply" : "dry-run",
        targetOrg: args.targetOrg,
        queriedRecords: records.length,
        updateCandidates: updates.length,
        fieldFillCounts: stats
      },
      null,
      2
    )
  );

  if (updates.length === 0) {
    console.log("No update candidates found.");
    return;
  }

  const fileName = `mql_events_portal_backfill_${Date.now()}.csv`;
  const filePath = path.join(args.outputDir, fileName);
  const headers = [
    "Id",
    "Lead_Source_Detail__c",
    "Lead_Detail_1__c",
    "Lead_Detail_2__c",
    "Lead_Detail_3__c",
    "Lead_Detail_4__c",
    "Campaign__c"
  ];
  const csv = toCsv(updates, headers);
  fs.writeFileSync(filePath, csv, "utf8");
  console.log(`CSV written: ${filePath}`);

  if (!args.apply) {
    console.log("Dry-run complete. Re-run with --apply to execute updates.");
    return;
  }

  const updateRes = runSfJson([
    "data",
    "update",
    "bulk",
    "--target-org",
    args.targetOrg,
    "--sobject",
    "MQL__c",
    "--file",
    filePath,
    "--line-ending",
    "LF",
    "--wait",
    String(args.waitMinutes),
    "--json"
  ]);

  const result = updateRes?.result || {};
  console.log(
    JSON.stringify(
      {
        jobId: result.jobId || null,
        state: result.state || null,
        numberRecordsProcessed: result.numberRecordsProcessed ?? null,
        numberRecordsFailed: result.numberRecordsFailed ?? null
      },
      null,
      2
    )
  );
}

main();
