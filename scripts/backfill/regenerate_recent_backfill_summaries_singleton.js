/* eslint-disable no-console */
const fs = require("node:fs");
const { execFileSync } = require("node:child_process");

function runSfJson(args) {
  return JSON.parse(
    execFileSync("sf", args, {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"]
    })
  );
}

function sleep(ms) {
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);
}

const targetOrg = "mql-sandbox";
const query =
  "SELECT Id, Engagement_AI_Summary__c FROM MQL__c " +
  "WHERE Lead_Source__c = 'Fit and Behavior Threshold Reached' " +
  "AND CreatedDate >= 2026-02-20T19:08:34Z " +
  "ORDER BY CreatedDate DESC";

const records =
  runSfJson([
    "data",
    "query",
    "--target-org",
    targetOrg,
    "--query",
    query,
    "--json"
  ]).result.records || [];

const ids = records
  .filter((r) => r.Engagement_AI_Summary__c === null)
  .map((r) => r.Id)
  .filter(Boolean);

console.log(`Null summaries to process (singleton pass): ${ids.length}`);

for (let i = 0; i < ids.length; i++) {
  const id = ids[i];
  const apex = `MqlSummarizerCallout.triggerSummarizationForce(new Set<Id>{ '${id}' });\n`;
  const filePath = `/tmp/mql_force_single_${Date.now()}_${i}.apex`;
  fs.writeFileSync(filePath, apex, "utf8");
  execFileSync(
    "sf",
    ["apex", "run", "--target-org", targetOrg, "--file", filePath],
    { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] }
  );
  console.log(`Enqueued ${i + 1}/${ids.length}: ${id}`);
  if (i < ids.length - 1) sleep(12000);
}
