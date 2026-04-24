#!/usr/bin/env node
/* eslint-disable no-console */

/**
 * FLS parity preflight check.
 *
 * For a given target org and a list of new/changed Contact (or other object)
 * fields, compares their FieldPermissions against a known-good "reference"
 * field and reports any profile or permission set that has Edit on the
 * reference but NOT on the target field.
 *
 * This catches the 2026-04-17 v1 payload regression class: new Contact
 * fields shipped without Edit FLS on the integration profile, so the
 * Contact PATCH from the Events Portal silently rejected, Set_to_MQL__c
 * never flipped, and 77 Opportunities were created with 0 MQLs.
 *
 * Usage:
 *   node scripts/check-fls-parity.js \
 *     --target-org ef3-prod \
 *     --reference Contact.Hand_Raiser_Source__c \
 *     --field Contact.Hand_Raiser_Payload_Version__c \
 *     --field Contact.Hand_Raiser_Campaign_Id__c
 *
 * Or let it auto-detect added field files vs a base ref:
 *   node scripts/check-fls-parity.js --target-org ef3-prod --base origin/main
 *
 * Config file (optional):
 *   .sf-fls-check.json at repo root can set defaults, e.g.:
 *   {
 *     "targetOrg": "ef3-prod",
 *     "reference": "Contact.Hand_Raiser_Source__c",
 *     "base": "origin/main",
 *     "ignorePrincipals": ["^profile:Analytics Cloud"]
 *   }
 *
 * Exit codes:
 *   0  all target fields match the reference's Edit principals
 *   1  at least one target field is missing Edit on one or more principals
 *   2  usage / invocation error
 */

const { spawnSync } = require("node:child_process");
const fs = require("node:fs");
const path = require("node:path");

const REPO_ROOT = path.resolve(__dirname, "..");
const CONFIG_PATH = path.join(REPO_ROOT, ".sf-fls-check.json");

function parseArgs(argv) {
  const out = { fields: [], ignorePrincipals: [] };
  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    const next = () => argv[++i];
    switch (a) {
      case "--target-org":
      case "-o":
        out.targetOrg = next();
        break;
      case "--reference":
      case "-r":
        out.reference = next();
        break;
      case "--field":
      case "-f":
        out.fields.push(next());
        break;
      case "--base":
      case "-b":
        out.base = next();
        break;
      case "--ignore-principal":
        out.ignorePrincipals.push(next());
        break;
      case "--help":
      case "-h":
        printUsageAndExit(0);
        break;
      default:
        console.error(`Unknown argument: ${a}`);
        printUsageAndExit(2);
    }
  }
  return out;
}

function printUsageAndExit(code) {
  console.error(
    [
      "Usage: node scripts/check-fls-parity.js \\",
      "         --target-org <alias> \\",
      "         [--reference Object.Field] \\",
      "         [--field Object.Field ...] \\",
      "         [--base <git-ref>] \\",
      "         [--ignore-principal <regex> ...]",
      "",
      "Defaults can also be supplied via .sf-fls-check.json at repo root."
    ].join("\n")
  );
  process.exit(code);
}

function loadConfig() {
  if (!fs.existsSync(CONFIG_PATH)) return {};
  try {
    return JSON.parse(fs.readFileSync(CONFIG_PATH, "utf8"));
  } catch (e) {
    console.error(`Failed to parse ${CONFIG_PATH}: ${e.message}`);
    process.exit(2);
  }
}

function run(cmd, args, opts = {}) {
  const res = spawnSync(cmd, args, { encoding: "utf8", ...opts });
  if (res.error) {
    throw new Error(`${cmd} ${args.join(" ")}: ${res.error.message}`);
  }
  if (res.status !== 0) {
    const stderr = (res.stderr || "").trim();
    throw new Error(
      `${cmd} ${args.join(" ")} exited ${res.status}${stderr ? `: ${stderr}` : ""}`
    );
  }
  return res.stdout;
}

function detectAddedFields(base) {
  let diff;
  try {
    diff = run("git", [
      "diff",
      "--name-status",
      `${base}..HEAD`,
      "--",
      "force-app/main/default/objects"
    ]);
  } catch (e) {
    console.error(`git diff failed (base=${base}): ${e.message}`);
    console.error(
      "Pass --field explicitly, or a different --base (e.g. main, origin/main, HEAD~1)."
    );
    process.exit(2);
  }
  const fields = [];
  for (const line of diff.split("\n")) {
    if (!line.trim()) continue;
    const [status, file] = line.split(/\s+/, 2);
    if (status !== "A") continue;
    // force-app/main/default/objects/<Object>/fields/<Field>.field-meta.xml
    const m = file.match(/objects\/([^/]+)\/fields\/([^/]+)\.field-meta\.xml$/);
    if (m) fields.push(`${m[1]}.${m[2]}`);
  }
  return fields;
}

function splitObjectField(full) {
  const i = full.indexOf(".");
  if (i < 0) throw new Error(`Expected Object.Field, got: ${full}`);
  return { object: full.slice(0, i), field: full.slice(i + 1) };
}

function sfQuery(targetOrg, soql) {
  const raw = run("sf", [
    "data",
    "query",
    "--target-org",
    targetOrg,
    "-q",
    soql,
    "--result-format",
    "json"
  ]);
  const parsed = JSON.parse(raw);
  if (parsed.status !== 0) {
    throw new Error(`sf data query failed: ${JSON.stringify(parsed)}`);
  }
  return parsed.result.records || [];
}

function principalKey(record) {
  // Profile mirror PermissionSets populate Parent.Profile.Name; collapse them
  // to a single "profile:<name>" principal.
  const profileName = record?.Parent?.Profile?.Name;
  if (profileName) return `profile:${profileName}`;
  const psLabel =
    record?.Parent?.Label || record?.Parent?.Name || "(unknown permset)";
  return `permset:${psLabel}`;
}

function fetchEditPrincipals(targetOrg, objectName, fieldApiName) {
  const soql =
    `SELECT Parent.Name, Parent.Label, Parent.Profile.Name, ` +
    `PermissionsRead, PermissionsEdit ` +
    `FROM FieldPermissions ` +
    `WHERE SObjectType = '${objectName}' ` +
    `AND Field = '${objectName}.${fieldApiName}' ` +
    `AND PermissionsEdit = true`;
  const records = sfQuery(targetOrg, soql);
  return new Set(records.map(principalKey));
}

function filterPrincipals(principals, ignorePatterns) {
  if (!ignorePatterns.length) return principals;
  const regexes = ignorePatterns.map((p) => new RegExp(p));
  const kept = new Set();
  for (const p of principals) {
    if (!regexes.some((r) => r.test(p))) kept.add(p);
  }
  return kept;
}

function main() {
  const cfg = loadConfig();
  const args = parseArgs(process.argv);

  const targetOrg = args.targetOrg || cfg.targetOrg;
  const reference = args.reference || cfg.reference;
  const base = args.base || cfg.base || "origin/main";
  const ignorePrincipals = [
    ...(cfg.ignorePrincipals || []),
    ...args.ignorePrincipals
  ];

  if (!targetOrg) {
    console.error("Missing --target-org (or targetOrg in .sf-fls-check.json).");
    printUsageAndExit(2);
  }
  if (!reference) {
    console.error(
      "Missing --reference (or reference in .sf-fls-check.json). " +
        "Pick a known-good field, e.g. Contact.Hand_Raiser_Source__c."
    );
    printUsageAndExit(2);
  }

  let fields = args.fields.slice();
  if (!fields.length) {
    console.error(
      `No --field specified; auto-detecting added field XMLs from git diff ${base}..HEAD`
    );
    fields = detectAddedFields(base);
  }
  if (!fields.length) {
    console.log("No target fields to check. Nothing to do.");
    process.exit(0);
  }

  const ref = splitObjectField(reference);
  console.error(
    `Reference: ${reference} in org=${targetOrg}. Fetching Edit principals...`
  );
  const refPrincipals = filterPrincipals(
    fetchEditPrincipals(targetOrg, ref.object, ref.field),
    ignorePrincipals
  );
  if (!refPrincipals.size) {
    console.error(
      `Reference field ${reference} has no Edit grants in ${targetOrg}. ` +
        "Refusing to continue (would approve any field as a match). " +
        "Pick a different --reference."
    );
    process.exit(2);
  }
  console.error(
    `Reference Edit principals (${refPrincipals.size}):\n  - ` +
      [...refPrincipals].sort().join("\n  - ")
  );

  let anyMissing = false;
  for (const full of fields) {
    const { object, field } = splitObjectField(full);
    if (object !== ref.object) {
      console.error(
        `Skipping ${full}: object mismatch with reference ${reference}.`
      );
      continue;
    }
    const targetPrincipals = filterPrincipals(
      fetchEditPrincipals(targetOrg, object, field),
      ignorePrincipals
    );
    const missing = [...refPrincipals]
      .filter((p) => !targetPrincipals.has(p))
      .sort();
    const extra = [...targetPrincipals]
      .filter((p) => !refPrincipals.has(p))
      .sort();

    if (missing.length === 0) {
      console.log(`OK   ${full} (${targetPrincipals.size} Edit principals)`);
    } else {
      anyMissing = true;
      console.log(
        `FAIL ${full} missing Edit on ${missing.length} principal(s):`
      );
      for (const p of missing) console.log(`       - ${p}`);
    }
    if (extra.length) {
      console.log(
        `INFO ${full} has Edit on ${extra.length} principal(s) not on reference:`
      );
      for (const p of extra) console.log(`       + ${p}`);
    }
  }

  if (anyMissing) {
    console.error(
      "\nOne or more fields lack Edit FLS parity with the reference field. " +
        "Update the relevant Profile/PermissionSet XMLs and redeploy before " +
        "promoting any integration that writes these fields."
    );
    process.exit(1);
  }
  console.log("\nAll target fields match reference Edit principals.");
  process.exit(0);
}

main();
