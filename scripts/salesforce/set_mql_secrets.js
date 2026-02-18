#!/usr/bin/env node
/**
 * Upsert org-level secrets into the Hierarchy Custom Setting MqlSecrets__c.
 *
 * This uses `sf data ...` commands (Salesforce APIs) so secrets never touch Git.
 *
 * Required env vars (provide whichever you want to set):
 *   - MQL_API_GATEWAY_API_KEY
 *   - HUBSPOT_PRIVATE_APP_TOKEN
 *   - RECAPTCHA_SECRET_KEY
 *
 * Usage:
 *   node scripts/salesforce/set_mql_secrets.js --target-org mql-sandbox
 *   node scripts/salesforce/set_mql_secrets.js --target-org mql-prod
 */

/* eslint-disable no-console */
const cp = require("node:child_process");
const fs = require("node:fs");
const path = require("node:path");

function loadDotEnv() {
  const envPath = path.resolve(process.cwd(), ".env");
  if (!fs.existsSync(envPath)) return;
  const lines = fs.readFileSync(envPath, "utf8").split(/\r?\n/);
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const idx = trimmed.indexOf("=");
    if (idx === -1) continue;
    const key = trimmed.slice(0, idx).trim();
    let value = trimmed.slice(idx + 1).trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    // Don't overwrite an explicitly-provided env var.
    if (process.env[key] === undefined) process.env[key] = value;
  }
}

function runJson(cmd) {
  const out = cp
    .execSync(cmd, { stdio: ["ignore", "pipe", "pipe"] })
    .toString();
  return JSON.parse(out);
}

function tryExec(cmd) {
  try {
    cp.execSync(cmd, { stdio: ["ignore", "pipe", "pipe"] });
    return { ok: true };
  } catch (e) {
    return { ok: false, err: e };
  }
}

function parseArgs(argv) {
  const args = { targetOrg: null };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--target-org" || a === "-o") {
      args.targetOrg = argv[i + 1];
      i++;
    }
  }
  return args;
}

function main() {
  loadDotEnv();
  const args = parseArgs(process.argv.slice(2));
  if (!args.targetOrg) {
    console.error("Missing --target-org (e.g. mql-sandbox)");
    process.exit(2);
  }

  let apiKey = process.env.MQL_API_GATEWAY_API_KEY || "";
  const hubspot = process.env.HUBSPOT_PRIVATE_APP_TOKEN || "";
  const recaptcha = process.env.RECAPTCHA_SECRET_KEY || "";

  // Determine org + environment.
  const orgRes = runJson(
    `sf data query -o ${args.targetOrg} --json -q "SELECT Id, IsSandbox FROM Organization LIMIT 1"`
  );
  const orgId = orgRes?.result?.records?.[0]?.Id;
  const isSandbox = !!orgRes?.result?.records?.[0]?.IsSandbox;
  if (!orgId) {
    console.error("Could not determine Organization Id.");
    process.exit(1);
  }

  // If no API key was provided, try to migrate from existing CMDT (if present).
  if (!apiKey) {
    const environment = isSandbox ? "sandbox" : "production";
    try {
      const cmdtRes = runJson(
        `sf data query -o ${args.targetOrg} --json -q "SELECT ApiKey__c FROM TicketSummarizerEndpoint__mdt WHERE Environment__c='${environment}' LIMIT 1"`
      );
      const cmdtKey = cmdtRes?.result?.records?.[0]?.ApiKey__c;
      if (cmdtKey) apiKey = cmdtKey;
    } catch {
      // Ignore if CMDT isn't queryable in this org/user context.
    }
  }

  const updates = [];
  if (apiKey)
    updates.push(`ApiGatewayApiKey__c='${apiKey.replace(/'/g, "\\'")}'`);
  if (hubspot)
    updates.push(`HubspotPrivateAppToken__c='${hubspot.replace(/'/g, "\\'")}'`);
  if (recaptcha)
    updates.push(`RecaptchaSecretKey__c='${recaptcha.replace(/'/g, "\\'")}'`);

  if (updates.length === 0) {
    console.error(
      "No secrets provided. Set one of: MQL_API_GATEWAY_API_KEY, HUBSPOT_PRIVATE_APP_TOKEN, RECAPTCHA_SECRET_KEY"
    );
    process.exit(2);
  }

  // Try update first (fast path).
  const updateAttempt = tryExec(
    `sf data update record -o ${args.targetOrg} -s MqlSecrets__c -w "SetupOwnerId='${orgId}'" -v "${updates.join(
      " "
    )}" --json`
  );
  if (updateAttempt.ok) {
    console.log(`Updated MqlSecrets__c org-defaults in ${args.targetOrg}`);
    return;
  }

  // If update fails, create the org-defaults record.
  const createVals = [`SetupOwnerId='${orgId}'`, ...updates].join(" ");
  const createRes = tryExec(
    `sf data create record -o ${args.targetOrg} -s MqlSecrets__c -v "${createVals}" --json`
  );
  if (!createRes.ok) {
    console.error(
      "Failed to update or create MqlSecrets__c. Make sure metadata is deployed and you have permissions."
    );
    process.exit(1);
  }

  console.log(`Created MqlSecrets__c org-defaults in ${args.targetOrg}`);
}

main();
