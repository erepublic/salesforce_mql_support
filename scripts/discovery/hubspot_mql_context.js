#!/usr/bin/env node
/**
 * Discovery helper: pull HubSpot context needed to build an MQL narrative.
 *
 * Auth:
 *   export HUBSPOT_PRIVATE_APP_TOKEN=<your-private-app-token>
 *
 * Usage:
 *   node scripts/discovery/hubspot_mql_context.js --email person@company.com
 *   node scripts/discovery/hubspot_mql_context.js --hs-contact-id 12345
 *
 * Output:
 *   .local/discovery/hubspot/<timestamp>_<hsContactId>.json
 */

/* eslint-disable no-console */
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
    // Prefer the file during discovery so a user can iterate on tokens/scopes.
    process.env[key] = value;
  }
}

function parseArgs(argv) {
  const args = {};
  for (let i = 2; i < argv.length; i++) {
    const token = argv[i];
    if (!token.startsWith("--")) continue;
    const key = token.slice(2);
    const next = argv[i + 1];
    if (!next || next.startsWith("--")) {
      args[key] = true;
    } else {
      args[key] = next;
      i++;
    }
  }
  return args;
}

function ensureDir(dirPath) {
  fs.mkdirSync(dirPath, { recursive: true });
}

function nowStamp() {
  const d = new Date();
  const pad = (n) => String(n).padStart(2, "0");
  return `${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}_${pad(
    d.getHours()
  )}${pad(d.getMinutes())}${pad(d.getSeconds())}`;
}

function requireToken() {
  const token =
    process.env.HUBSPOT_PRIVATE_APP_TOKEN ||
    process.env.HUBSPOT_ACCESS_TOKEN ||
    process.env.HUBSPOT_TOKEN;
  if (!token) {
    throw new Error(
      "Missing HubSpot token. Set HUBSPOT_PRIVATE_APP_TOKEN (preferred) in your env or .env."
    );
  }
  return token;
}

async function hsFetchJson(token, url, options = {}) {
  const res = await fetch(url, {
    ...options,
    headers: {
      authorization: `Bearer ${token}`,
      "content-type": "application/json",
      ...(options.headers || {})
    }
  });

  const text = await res.text();
  let body;
  try {
    body = text ? JSON.parse(text) : null;
  } catch {
    body = { raw: text };
  }

  if (!res.ok) {
    const message = body?.message || body?.status || `HTTP ${res.status}`;
    throw new Error(`HubSpot API error: ${message}\nURL: ${url}`);
  }

  return body;
}

async function searchContactIdByEmail(token, email) {
  const url = "https://api.hubapi.com/crm/v3/objects/contacts/search";
  const body = await hsFetchJson(token, url, {
    method: "POST",
    body: JSON.stringify({
      filterGroups: [
        {
          filters: [{ propertyName: "email", operator: "EQ", value: email }]
        }
      ],
      limit: 1
    })
  });
  return body?.results?.[0]?.id || null;
}

async function listProperties(token, objectType) {
  // Used for discovery. In production, we should query an explicit allowlist.
  const url = `https://api.hubapi.com/crm/v3/properties/${encodeURIComponent(objectType)}`;
  const body = await hsFetchJson(token, url);
  return body?.results || [];
}

function selectPropertyNamesForNarrative(allProps, extraRegex, { maxProps }) {
  const coreNames = [
    "email",
    "firstname",
    "lastname",
    "company",
    "lifecyclestage",
    "hs_lead_status",
    // Contact Us signals written by Salesforce code in this repo
    "contact_request_topic",
    "salesforce_contact_message",
    // Common acquisition attribution properties
    "hs_analytics_source",
    "hs_analytics_source_data_1",
    "hs_analytics_source_data_2",
    "utm_source",
    "utm_medium",
    "utm_campaign",
    "utm_content",
    "utm_term",
    // Common conversion properties (names vary by portal)
    "first_conversion_event_name",
    "first_conversion_date",
    "recent_conversion_event_name",
    "recent_conversion_date"
  ];

  const coreSet = new Set(coreNames);
  const regex =
    extraRegex && String(extraRegex).trim()
      ? new RegExp(String(extraRegex), "i")
      : /(behavior|fit|score|lifecycle|lead|mql|conversion|utm|source|contact_request|salesforce_contact_message)/i;

  const discovered = allProps
    .map((p) => p.name)
    .filter((name) => coreSet.has(name) || regex.test(name))
    .sort();

  // Preserve explicit core order first, then remaining discovered.
  const ordered = [...coreNames.filter((n) => discovered.includes(n))];
  for (const name of discovered) {
    if (!ordered.includes(name)) ordered.push(name);
  }

  // Cap to avoid exceeding URL length limits (414) on GET object reads.
  const cap = Number.isFinite(maxProps) ? maxProps : 60;
  return ordered.slice(0, cap);
}

async function getObjectById(
  token,
  objectType,
  objectId,
  { properties, propertiesWithHistory } = {}
) {
  const params = new URLSearchParams();
  for (const p of properties || []) params.append("properties", p);
  for (const p of propertiesWithHistory || [])
    params.append("propertiesWithHistory", p);
  params.set("archived", "false");

  const url = `https://api.hubapi.com/crm/v3/objects/${encodeURIComponent(
    objectType
  )}/${encodeURIComponent(objectId)}?${params.toString()}`;
  return hsFetchJson(token, url);
}

async function listAssociationIds(
  token,
  fromType,
  fromId,
  toType,
  limit = 500
) {
  const ids = [];
  let after = undefined;
  while (true) {
    const params = new URLSearchParams();
    params.set("limit", String(limit));
    if (after) params.set("after", after);

    const url = `https://api.hubapi.com/crm/v3/objects/${encodeURIComponent(
      fromType
    )}/${encodeURIComponent(fromId)}/associations/${encodeURIComponent(toType)}?${params.toString()}`;

    const body = await hsFetchJson(token, url);
    const results = body?.results || [];
    for (const r of results) {
      // HubSpot association APIs have returned different shapes over time:
      // - { toObjectId: <id> }
      // - { id: <associatedObjectId>, type: "contact_to_deal" }
      const associatedId = r?.toObjectId ?? r?.id;
      if (associatedId != null) ids.push(String(associatedId));
    }
    after = body?.paging?.next?.after;
    if (!after) break;
  }
  return Array.from(new Set(ids));
}

async function batchReadObjects(token, objectType, ids, properties) {
  if (!ids.length) return [];
  const url = `https://api.hubapi.com/crm/v3/objects/${encodeURIComponent(objectType)}/batch/read`;

  // HubSpot batch limits exist; keep it conservative.
  const chunkSize = 100;
  const chunks = [];
  for (let i = 0; i < ids.length; i += chunkSize)
    chunks.push(ids.slice(i, i + chunkSize));

  const allResults = [];
  for (const chunk of chunks) {
    const body = await hsFetchJson(token, url, {
      method: "POST",
      body: JSON.stringify({
        inputs: chunk.map((id) => ({ id })),
        properties
      })
    });
    allResults.push(...(body?.results || []));
  }
  return allResults;
}

function parseMs(value) {
  const n = Number(value);
  return Number.isFinite(n) ? n : null;
}

function recencyFilterAndCap(records, { sinceMs, max }) {
  const filtered = records
    .map((r) => {
      const createdAt = r?.createdAt ? Date.parse(r.createdAt) : null;
      const updatedAt = r?.updatedAt ? Date.parse(r.updatedAt) : null;
      return { ...r, _sortTs: updatedAt || createdAt || 0 };
    })
    .filter((r) => !sinceMs || r._sortTs >= sinceMs)
    .sort((a, b) => b._sortTs - a._sortTs)
    .slice(0, max);

  for (const r of filtered) delete r._sortTs;
  return filtered;
}

async function main() {
  loadDotEnv();
  const args = parseArgs(process.argv);
  const token = requireToken();
  const warnings = [];

  const email = args.email;
  const hsContactId = args["hs-contact-id"];
  const sinceDays = Number(args["since-days"] || 365);
  const maxPerType = Number(args["max-per-type"] || 50);
  const maxProperties = Number(args["max-properties"] || 60);
  const propertyRegex = args["property-regex"];

  let contactId = hsContactId || null;
  if (!contactId && email) {
    contactId = await searchContactIdByEmail(token, email);
  }
  if (!contactId) {
    throw new Error(
      "Unable to resolve HubSpot contact. Provide --hs-contact-id or --email."
    );
  }

  const outDir = path.resolve(process.cwd(), ".local", "discovery", "hubspot");
  ensureDir(outDir);

  async function safeListProperties(objectType) {
    try {
      return await listProperties(token, objectType);
    } catch (e) {
      warnings.push(
        `Missing permission or error listing properties for ${objectType}: ${e.message}`
      );
      return [];
    }
  }

  const contactProps = await safeListProperties("contacts");
  const companyProps = await safeListProperties("companies");
  const dealProps = await safeListProperties("deals");

  const contactPropertyNames = selectPropertyNamesForNarrative(
    contactProps,
    propertyRegex,
    {
      maxProps: maxProperties
    }
  );
  const companyPropertyNames = selectPropertyNamesForNarrative(
    companyProps,
    propertyRegex,
    {
      maxProps: maxProperties
    }
  );
  const dealPropertyNames = selectPropertyNamesForNarrative(
    dealProps,
    propertyRegex,
    {
      maxProps: maxProperties
    }
  );

  // Always include dealstage history so we can narrate pipeline movement.
  const dealPropertiesWithHistory = Array.from(
    new Set(["dealstage", ...dealPropertyNames])
  );
  const contactPropertiesWithHistory = contactPropertyNames;
  const companyPropertiesWithHistory = companyPropertyNames;

  const contact = await getObjectById(token, "contacts", contactId, {
    properties: contactPropertyNames,
    propertiesWithHistory: contactPropertiesWithHistory
  });

  // Associations we care about for MQL narrative.
  async function safeListAssociationIds(toType) {
    try {
      return await listAssociationIds(token, "contacts", contactId, toType);
    } catch (e) {
      warnings.push(
        `Missing permission or error listing associations to ${toType}: ${e.message}`
      );
      return [];
    }
  }

  const companyIds = await safeListAssociationIds("companies");
  const dealIds = await safeListAssociationIds("deals");

  // CRM activity objects (full scope requested, bounded by recency + caps).
  const activityTypes = ["notes", "calls", "meetings", "tasks", "emails"];
  const activityIdsByType = {};
  for (const type of activityTypes) {
    activityIdsByType[type] = await safeListAssociationIds(type);
  }

  // Companies/deals: use individual read so we can request propertiesWithHistory.
  // (Batch read does not support propertiesWithHistory.)
  const companies = [];
  if (companyIds.length) {
    for (const id of companyIds.slice(0, 10)) {
      try {
        companies.push(
          await getObjectById(token, "companies", id, {
            properties: companyPropertyNames,
            propertiesWithHistory: companyPropertiesWithHistory
          })
        );
      } catch (e) {
        warnings.push(
          `Missing permission or error reading company ${id}: ${e.message}`
        );
        break;
      }
    }
  }

  const deals = [];
  if (dealIds.length) {
    for (const id of dealIds.slice(0, 50)) {
      try {
        deals.push(
          await getObjectById(token, "deals", id, {
            properties: dealPropertyNames,
            propertiesWithHistory: dealPropertiesWithHistory
          })
        );
      } catch (e) {
        warnings.push(
          `Missing permission or error reading deal ${id}: ${e.message}`
        );
        break;
      }
    }
  }

  // Activities: use batch read for volume efficiency; pick stable, readable properties.
  const activityPropsByType = {
    notes: ["hs_note_body", "hs_timestamp", "hubspot_owner_id"],
    calls: [
      "hs_call_body",
      "hs_call_direction",
      "hs_timestamp",
      "hubspot_owner_id"
    ],
    meetings: [
      "hs_meeting_title",
      "hs_meeting_body",
      "hs_timestamp",
      "hubspot_owner_id"
    ],
    tasks: [
      "hs_task_subject",
      "hs_task_body",
      "hs_timestamp",
      "hubspot_owner_id",
      "hs_task_status"
    ],
    emails: [
      "hs_email_subject",
      "hs_email_text",
      "hs_timestamp",
      "hubspot_owner_id"
    ]
  };

  const sinceMs = sinceDays
    ? Date.now() - sinceDays * 24 * 60 * 60 * 1000
    : null;
  const activities = {};
  for (const type of activityTypes) {
    const ids = activityIdsByType[type] || [];
    const props = activityPropsByType[type] || [
      "hs_timestamp",
      "hubspot_owner_id"
    ];
    try {
      const read = await batchReadObjects(token, type, ids, props);
      activities[type] = recencyFilterAndCap(read, {
        sinceMs,
        max: maxPerType
      });
    } catch (e) {
      warnings.push(
        `Missing permission or error batch-reading ${type}: ${e.message}`
      );
      activities[type] = [];
    }
  }

  // Identify candidate scoring fields for docs: anything with score/fit/behavior/lifecycle/mql.
  const candidateContactProps = contactPropertyNames.filter((n) =>
    /(score|fit|behavior|lifecycle|lead|mql)/i.test(n)
  );

  const payload = {
    metadata: {
      collectedAt: new Date().toISOString(),
      inputs: {
        hsContactId: contactId,
        email: email || null,
        sinceDays,
        maxPerType
      },
      selectedProperties: {
        contactProperties: contactPropertyNames,
        companyProperties: companyPropertyNames,
        dealProperties: dealPropertyNames,
        dealPropertiesWithHistory
      },
      candidateNarrativeContactProperties: candidateContactProps,
      associationCounts: {
        companies: companyIds.length,
        deals: dealIds.length,
        notes: activityIdsByType.notes?.length || 0,
        calls: activityIdsByType.calls?.length || 0,
        meetings: activityIdsByType.meetings?.length || 0,
        tasks: activityIdsByType.tasks?.length || 0,
        emails: activityIdsByType.emails?.length || 0
      },
      warnings: [
        "This is a discovery tool; production Lambda should use explicit property allowlists and stricter redaction.",
        "Body fields (note/email/call text) may contain PII. Keep outputs in .local/ only.",
        ...warnings
      ]
    },
    contact,
    companies,
    deals,
    activities
  };

  const outPath = path.join(outDir, `${nowStamp()}_${contactId}.json`);
  fs.writeFileSync(outPath, JSON.stringify(payload, null, 2));
  console.log(outPath);
}

main().catch((e) => {
  console.error(e.message || e);
  process.exit(1);
});
