/* eslint-disable no-console */

const { execFileSync } = require("node:child_process");

function runSfJson(args) {
  const out = execFileSync("sf", args, {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"]
  });
  return JSON.parse(out);
}

function parseArgs(argv) {
  const args = { targetOrg: "mql-sandbox" };
  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--target-org") args.targetOrg = String(argv[++i] || "").trim();
  }
  if (!args.targetOrg) throw new Error("invalid --target-org");
  return args;
}

function main() {
  const { targetOrg } = parseArgs(process.argv);
  const res = runSfJson([
    "data",
    "query",
    "--target-org",
    targetOrg,
    "--query",
    "SELECT Id, Engagement_AI_Summary__c, LastModifiedDate FROM MQL__c ORDER BY CreatedDate DESC",
    "--json"
  ]);

  const records = res?.result?.records || [];
  const total = records.length;
  let nonNull = 0;
  let empty = 0;
  let technicalLeak = 0;
  let salesish = 0;
  let withLinksSection = 0;
  let withAnchors = 0;

  for (const r of records) {
    const s = r?.Engagement_AI_Summary__c;
    if (s === null || s === undefined || String(s).trim() === "") {
      empty += 1;
      continue;
    }
    nonNull += 1;

    const str = String(s);
    if (
      /contactSignals\.|accountSignals\.|opportunitySignals\.|HubSpot_|__c\b|MQL__c|OpportunityContactRole/.test(
        str
      )
    ) {
      technicalLeak += 1;
    }
    if (
      /Why Sales Should Care|Most Recent Engagement|Suggested Next Step|Score Interpretation/.test(
        str
      ) &&
      !/contactSignals\.|HubSpot_|__c\b/.test(str)
    ) {
      salesish += 1;
    }

    if (str.includes("<p><strong>Links</strong></p>")) withLinksSection += 1;
    if ((str.match(/<a\b/gi) || []).length > 0) withAnchors += 1;
  }

  console.log(
    JSON.stringify(
      {
        total,
        nonNull,
        empty,
        technicalLeak,
        salesish,
        withLinksSection,
        withAnchors
      },
      null,
      2
    )
  );
}

main();
