#!/usr/bin/env node

const { spawnSync } = require("node:child_process");

const jobId = process.argv[2] || process.env.VALIDATION_JOB_ID;

if (!jobId) {
  console.error(
    "Missing validation job id. Pass it as an argument or set VALIDATION_JOB_ID."
  );
  console.error("Example: npm run sf:quick:prod -- 0AfXXXXXXXXXXXX");
  process.exit(1);
}

const result = spawnSync(
  "sf",
  ["project", "deploy", "quick", "--target-org", "mql-prod", "--job-id", jobId],
  { stdio: "inherit" }
);

if (result.error) {
  console.error(result.error.message);
  process.exit(1);
}

process.exit(result.status ?? 1);
