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

function chunk(arr, size) {
  const out = [];
  for (let i = 0; i < arr.length; i += size) out.push(arr.slice(i, i + size));
  return out;
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
console.log(`Null summaries to process: ${ids.length}`);

const batches = chunk(ids, 5);
for (let i = 0; i < batches.length; i++) {
  const setLiteral = batches[i].map((id) => `'${id}'`).join(", ");
  const apex = `MqlSummarizerCallout.triggerSummarizationForce(new Set<Id>{ ${setLiteral} });\n`;
  const filePath = `/tmp/mql_force_${Date.now()}_${i}.apex`;
  fs.writeFileSync(filePath, apex, "utf8");
  execFileSync(
    "sf",
    ["apex", "run", "--target-org", targetOrg, "--file", filePath],
    { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] }
  );
  console.log(
    `Enqueued batch ${i + 1}/${batches.length} (size=${batches[i].length})`
  );
  if (i < batches.length - 1) sleep(8000);
}
