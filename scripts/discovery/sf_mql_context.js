#!/usr/bin/env node
/**
 * Discovery helper: pull Salesforce context needed to build an MQL narrative.
 *
 * This script intentionally uses the Salesforce CLI (`sf`) for auth so we don't
 * reinvent OAuth flows in a one-off discovery tool.
 *
 * Usage:
 *   node scripts/discovery/sf_mql_context.js --contact-id 003... --target-org mql-sandbox
 *   node scripts/discovery/sf_mql_context.js --mql-id a1B... --target-org mql-sandbox
 *
 * Output:
 *   .local/discovery/sf/<timestamp>_<contactOrMqlId>.json
 */

/* eslint-disable no-console */
const { execFileSync } = require("node:child_process");
const fs = require("node:fs");
const path = require("node:path");

function safeJsonParse(text) {
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}

function loadAllowlist() {
  const allowlistPath = path.resolve(
    process.cwd(),
    "documentation",
    "mql_allowlist_v1.json"
  );
  if (!fs.existsSync(allowlistPath)) return null;
  return safeJsonParse(fs.readFileSync(allowlistPath, "utf8"));
}

function toIsoDateTime(value) {
  if (!value) return null;
  const t = Date.parse(value);
  if (Number.isFinite(t)) return new Date(t).toISOString();
  // Some Salesforce date fields come back as YYYY-MM-DD
  if (/^\d{4}-\d{2}-\d{2}$/.test(String(value)))
    return `${value}T00:00:00.000Z`;
  return null;
}

function redactEmailAddress(email) {
  if (!email || typeof email !== "string") return null;
  const m = email.match(/^([^@]+)@(.+)$/);
  if (!m) return email;
  return `*@${m[2]}`;
}

function buildHistoryEventsPreview({
  allowlist,
  contact,
  mql,
  opportunityContactRoles,
  opportunities,
  tasks,
  events,
  emailMessages,
  campaignMembers,
  contactUsSubmissions,
  history,
  sinceDays
}) {
  const defaults = allowlist?.defaults || {};
  const recipe = allowlist?.timelineRecipe || {};
  const maxOptional = Number(defaults.maxEvents || 25);
  const capsByEventType = defaults.capsByEventType || {};
  const windowDays = Number(sinceDays || defaults.recencyWindowDays || 365);
  const windowStartMs = Date.now() - windowDays * 24 * 60 * 60 * 1000;

  const importanceMap = recipe.importance || {};
  const importanceByEventType = new Map();
  for (const level of ["high", "medium", "low"]) {
    for (const eventType of importanceMap[level] || [])
      importanceByEventType.set(eventType, level);
  }

  function importanceFor(eventType) {
    return importanceByEventType.get(eventType) || "low";
  }

  function capFor(eventType) {
    const cap = capsByEventType[eventType];
    return Number.isFinite(cap) ? cap : 9999;
  }

  function pushEvent(arr, e) {
    if (!e?.occurredAt) return;
    arr.push(e);
  }

  const allAlways = [];
  const allOptional = [];

  // Always include: MQL created/converted/rejected.
  if (mql?.Id) {
    const createdAt =
      toIsoDateTime(mql.MQL_Date__c) || toIsoDateTime(mql.CreatedDate);
    pushEvent(allAlways, {
      occurredAt: createdAt,
      sourceSystem: "salesforce",
      sourceObjectType: "MQL__c",
      sourceObjectId: mql.Id,
      eventType: "mqlCreated",
      title: "MQL created",
      detail:
        [mql.Lead_Source__c, mql.Product_Name__c || mql.Product__c]
          .filter(Boolean)
          .join(" | ") || undefined,
      importance: importanceFor("mqlCreated")
    });

    if (mql.MQL_Status__c === "Converted") {
      const convertedAt =
        toIsoDateTime(mql.Conversion_Date__c) ||
        toIsoDateTime(mql.LastModifiedDate) ||
        createdAt;
      pushEvent(allAlways, {
        occurredAt: convertedAt,
        sourceSystem: "salesforce",
        sourceObjectType: "MQL__c",
        sourceObjectId: mql.Id,
        eventType: "mqlConverted",
        title: "MQL converted",
        detail:
          [mql.Conversion_Type__c, mql.Opportunity__c]
            .filter(Boolean)
            .join(" | ") || undefined,
        importance: importanceFor("mqlConverted")
      });
    }

    if (mql.MQL_Status__c === "Rejected") {
      const statusChange = (history?.mqlHistory || [])
        .filter(
          (h) =>
            h.Field === "MQL_Status__c" &&
            String(h.NewValue || "") === "Rejected"
        )
        .sort(
          (a, b) => Date.parse(b.CreatedDate) - Date.parse(a.CreatedDate)
        )[0];
      const rejectedAt =
        toIsoDateTime(statusChange?.CreatedDate) ||
        toIsoDateTime(mql.LastModifiedDate) ||
        createdAt;
      pushEvent(allAlways, {
        occurredAt: rejectedAt,
        sourceSystem: "salesforce",
        sourceObjectType: "MQL__c",
        sourceObjectId: mql.Id,
        eventType: "mqlRejected",
        title: "MQL rejected",
        detail: undefined,
        importance: importanceFor("mqlRejected")
      });
    }
  }

  // Always include: Open opp via OCR + latest stage changes if available.
  const ocrList = Array.isArray(opportunityContactRoles)
    ? opportunityContactRoles
    : [];
  const oppById = new Map((opportunities || []).map((o) => [o.Id, o]));
  for (const ocr of ocrList) {
    if (!ocr?.Open_Opportunity__c) continue;
    const opp = oppById.get(ocr.OpportunityId);
    pushEvent(allAlways, {
      occurredAt:
        toIsoDateTime(ocr.CreatedDate) || toIsoDateTime(opp?.CreatedDate),
      sourceSystem: "salesforce",
      sourceObjectType: "OpportunityContactRole",
      sourceObjectId: ocr.Id,
      eventType: "openOpportunityDetected",
      title: "Open opportunity detected",
      detail:
        [opp?.Name, opp?.StageName].filter(Boolean).join(" | ") || undefined,
      importance: importanceFor("openOpportunityDetected")
    });
  }

  const oppHist = Array.isArray(history?.opportunityFieldHistory)
    ? history.opportunityFieldHistory
    : [];
  for (const h of oppHist) {
    if (h?.Field !== "StageName") continue;
    pushEvent(allAlways, {
      occurredAt: toIsoDateTime(h.CreatedDate),
      sourceSystem: "salesforce",
      sourceObjectType: "Opportunity",
      sourceObjectId: h.OpportunityId || "unknown",
      eventType: "opportunityStageChanged",
      title: "Opportunity stage changed",
      detail:
        [h.OldValue, "->", h.NewValue].filter(Boolean).join(" ") || undefined,
      importance: importanceFor("opportunityStageChanged")
    });
  }

  // Optional: completed tasks, meetings, emails (metadata-only), campaigns, Contact Us.
  const taskList = Array.isArray(tasks) ? tasks : [];
  for (const t of taskList) {
    if (String(t.Status || "").toLowerCase() !== "completed") continue;
    pushEvent(allOptional, {
      occurredAt: toIsoDateTime(t.ActivityDate) || toIsoDateTime(t.CreatedDate),
      sourceSystem: "salesforce",
      sourceObjectType: "Task",
      sourceObjectId: t.Id,
      eventType: "taskCompleted",
      title: "Task completed",
      detail: t.Subject || undefined,
      importance: importanceFor("taskCompleted")
    });
  }

  const eventList = Array.isArray(events) ? events : [];
  for (const e of eventList) {
    pushEvent(allOptional, {
      occurredAt:
        toIsoDateTime(e.StartDateTime) ||
        toIsoDateTime(e.ActivityDate) ||
        toIsoDateTime(e.CreatedDate),
      sourceSystem: "salesforce",
      sourceObjectType: "Event",
      sourceObjectId: e.Id,
      eventType: "meetingLogged",
      title: "Meeting logged",
      detail: e.Subject || undefined,
      importance: importanceFor("meetingLogged")
    });
  }

  const emailList = Array.isArray(emailMessages) ? emailMessages : [];
  for (const em of emailList) {
    pushEvent(allOptional, {
      occurredAt:
        toIsoDateTime(em.MessageDate) || toIsoDateTime(em.CreatedDate),
      sourceSystem: "salesforce",
      sourceObjectType: "EmailMessage",
      sourceObjectId: em.Id,
      eventType: "emailEngagement",
      title: "Email",
      detail:
        [
          em.Subject,
          em.Incoming === true
            ? "incoming"
            : em.Incoming === false
              ? "outgoing"
              : null,
          redactEmailAddress(em.FromAddress)
        ]
          .filter(Boolean)
          .join(" | ") || undefined,
      importance: importanceFor("emailEngagement")
    });
  }

  const cmList = Array.isArray(campaignMembers) ? campaignMembers : [];
  for (const cm of cmList) {
    pushEvent(allOptional, {
      occurredAt:
        toIsoDateTime(cm.FirstRespondedDate) || toIsoDateTime(cm.CreatedDate),
      sourceSystem: "salesforce",
      sourceObjectType: "CampaignMember",
      sourceObjectId: cm.Id,
      eventType: "campaignTouch",
      title: "Campaign touch",
      detail:
        [
          cm.Campaign?.Name,
          cm.Status,
          cm.HasResponded === true ? "responded" : null
        ]
          .filter(Boolean)
          .join(" | ") || undefined,
      importance: importanceFor("campaignTouch")
    });
  }

  const cuList = Array.isArray(contactUsSubmissions)
    ? contactUsSubmissions
    : [];
  for (const cu of cuList) {
    pushEvent(allOptional, {
      occurredAt: toIsoDateTime(cu.CreatedDate),
      sourceSystem: "salesforce",
      sourceObjectType: "Contact_Us__c",
      sourceObjectId: cu.Id,
      eventType: "contactUsSubmitted",
      title: "Contact Us submitted",
      detail:
        [cu.Topic__c, cu.Source__c].filter(Boolean).join(" | ") || undefined,
      importance: importanceFor("contactUsSubmitted")
    });
  }

  function withinWindow(e) {
    const ms = Date.parse(e.occurredAt);
    return Number.isFinite(ms) && ms >= windowStartMs;
  }

  function dedupe(eventsArr) {
    const seen = new Set();
    const out = [];
    for (const e of eventsArr) {
      const ms = Date.parse(e.occurredAt);
      const bucket = Number.isFinite(ms) ? Math.floor(ms / 60000) : 0;
      const key = `${e.eventType}|${e.sourceObjectId}|${bucket}`;
      if (seen.has(key)) continue;
      seen.add(key);
      out.push(e);
    }
    return out;
  }

  function sortAsc(eventsArr) {
    return eventsArr.sort(
      (a, b) => Date.parse(a.occurredAt) - Date.parse(b.occurredAt)
    );
  }

  function applyPerTypeCaps(eventsArr) {
    const counts = new Map();
    const out = [];
    for (const e of eventsArr) {
      const n = counts.get(e.eventType) || 0;
      if (n >= capFor(e.eventType)) continue;
      counts.set(e.eventType, n + 1);
      out.push(e);
    }
    return out;
  }

  const always = applyPerTypeCaps(sortAsc(dedupe(allAlways)));

  const optionalCandidates = dedupe(allOptional)
    .filter(withinWindow)
    .sort((a, b) => Date.parse(b.occurredAt) - Date.parse(a.occurredAt));
  const perTypeCounts = new Map();
  const selectedOptional = [];
  for (const e of optionalCandidates) {
    if (selectedOptional.length >= maxOptional) break;
    const n = perTypeCounts.get(e.eventType) || 0;
    if (n >= capFor(e.eventType)) continue;
    perTypeCounts.set(e.eventType, n + 1);
    selectedOptional.push(e);
  }

  const finalEvents = sortAsc([...always, ...selectedOptional]);

  return {
    metadata: {
      generatedAt: new Date().toISOString(),
      allowlistVersion: allowlist?.version || null,
      recencyWindowDays: windowDays,
      maxOptionalEvents: maxOptional,
      includedCounts: {
        always: always.length,
        optional: selectedOptional.length,
        total: finalEvents.length
      }
    },
    contact: {
      id: contact?.Id || null,
      name: contact?.Name || null,
      emailRedacted: redactEmailAddress(contact?.Email) || null,
      accountId: contact?.AccountId || null
    },
    mql: mql?.Id ? { id: mql.Id, status: mql.MQL_Status__c || null } : null,
    events: finalEvents
  };
}

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
    if (!process.env[key]) process.env[key] = value;
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

function runSfJson(sfArgs) {
  try {
    // `sf sobject describe --json` can be large; increase buffer to avoid ENOBUFS.
    const out = execFileSync("sf", [...sfArgs, "--json"], {
      encoding: "utf8",
      maxBuffer: 50 * 1024 * 1024
    });
    const parsed = JSON.parse(out);
    if (parsed.status !== 0) {
      const message = parsed?.message || "Unknown sf CLI error";
      throw new Error(message);
    }
    return parsed.result;
  } catch (e) {
    const hint =
      "Failed to run `sf`. Ensure Salesforce CLI is installed and you are authenticated, e.g. `npm run sf:auth:sandbox`.";
    throw new Error(`${hint}\nUnderlying error: ${e.message}`);
  }
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

function pickExistingFields(describe, desiredFields) {
  const fieldNames = new Set((describe?.fields || []).map((f) => f.name));
  return desiredFields.filter((f) => fieldNames.has(f));
}

function soqlSelect(objectName, fields, whereClause) {
  return `SELECT ${fields.join(", ")} FROM ${objectName} WHERE ${whereClause}`;
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

function describeSObject({ targetOrg, sobject }) {
  return runSfJson([
    "sobject",
    "describe",
    "--sobject",
    sobject,
    "--target-org",
    targetOrg
  ]);
}

function safeInClause(ids) {
  if (!ids.length) return "(null)";
  const quoted = ids.map((id) => `'${String(id).replaceAll("'", "\\'")}'`);
  return `(${quoted.join(",")})`;
}

async function main() {
  loadDotEnv();
  const args = parseArgs(process.argv);
  const targetOrg = args["target-org"] || "mql-sandbox";
  const contactId = args["contact-id"];
  const mqlId = args["mql-id"];

  if (!contactId && !mqlId) {
    console.error("Provide either --contact-id or --mql-id");
    process.exit(2);
  }

  const outDir = path.resolve(process.cwd(), ".local", "discovery", "sf");
  ensureDir(outDir);

  // Describe key objects so we can build queries that won't fail across orgs.
  const contactDescribe = describeSObject({ targetOrg, sobject: "Contact" });
  const accountDescribe = describeSObject({ targetOrg, sobject: "Account" });
  const mqlDescribe = describeSObject({ targetOrg, sobject: "MQL__c" });
  const ocrDescribe = describeSObject({
    targetOrg,
    sobject: "OpportunityContactRole"
  });
  const oppDescribe = describeSObject({ targetOrg, sobject: "Opportunity" });

  const desiredContactFieldsBase = [
    "Id",
    "FirstName",
    "LastName",
    "Name",
    "Email",
    "Phone",
    "AccountId",
    "OwnerId",
    "RecordTypeId",
    "CreatedDate",
    "LastModifiedDate",
    // MQL gating / lifecycle (referenced in flows/spec)
    "Set_to_MQL__c",
    "MQL_Lifecycle_Stage__c",
    "Last_Date_MQL__c",
    "Last_Date_Recycled__c",
    "Contact_Status__c",
    "Private_Sector_Non_Qual__c",
    "Private_Sector_Acct_Non_Qual__c",
    // HubSpot score inputs used by the trigger flow
    "HubSpot_Private_Sector_Behavior_Score__c",
    "HubSpot_Private_Sector_Behavior_Date__c",
    "HubSpot_Private_Sector_Contact_Fit__c",
    "Contact_Fit_Threshold__c",

    // HubSpot marketing context (synced into Salesforce; useful for narrative)
    "HubSpot_Engagement_Score__c",
    "HubSpot_Engagement_Score_Threshold__c",
    "HubSpot_First_Conversion__c",
    "HubSpot_First_Conversion_Date__c",
    "HubSpot_Recent_Conversion__c",
    "HubSpot_Recent_Conversion_Date__c",
    "HubSpot_Last_Engagement_Date__c",
    "HubSpot_Sends_Since_Last_Engagement__c",
    "HubSpot_Last_Marketing_Email_Name__c",
    "HubSpot_Last_Marketing_Email_Open_Date__c",
    "HubSpot_Last_Marketing_Email_Send_Date__c",

    // Contact-side AI summary mirror (used by MQL creation mapping in flows)
    "Engagement_AI_Summary__c"
  ];

  // If the org has a stored HubSpot identity field, include it so we can avoid
  // email-based lookup (email is still the fallback).
  const contactFieldMeta = contactDescribe?.fields || [];
  const hubspotIdentityFieldCandidates = contactFieldMeta
    .map((f) => f.name)
    .filter((name) => {
      if (!name) return false;
      // Likely identity keys.
      if (/hs_object_id/i.test(name)) return true;
      if (/(^|_)vid(__c)?$/i.test(name)) return true;
      if (/hubspot.*(contact|person)?.*id/i.test(name)) return true;
      if (/hubspot.*object.*id/i.test(name)) return true;
      // Common legacy field name seen in some orgs.
      if (/^Hubspot__c$/i.test(name)) return true;
      return false;
    })
    .sort();

  const desiredContactFields = Array.from(
    new Set([...desiredContactFieldsBase, ...hubspotIdentityFieldCandidates])
  );

  const desiredAccountFields = [
    "Id",
    "Name",
    "OwnerId",
    "RecordTypeId",
    "CreatedDate",
    "LastModifiedDate",
    "Placeholder_Account__c",
    "Private_Sector_Non_Qual__c",
    "Company_Fit_Threshold__c"
  ];

  const desiredMqlFields = [
    "Id",
    "Name",
    "OwnerId",
    "CreatedDate",
    "LastModifiedDate",
    "MQL_Date__c",
    "MQL_Status__c",
    "Contact__c",
    "Contact_Name__c",
    "Email__c",
    "Phone__c",
    "Organization__c",
    "Lead_Source__c",
    "Lead_Source_Detail__c",
    "Lead_Detail_1__c",
    "Lead_Detail_2__c",
    "Lead_Detail_3__c",
    "Lead_Detail_4__c",
    "Lead_Notes__c",
    "Product__c",
    "Product_Name__c",
    "Campaign__c",
    "Opportunity__c",
    "Conversion_Date__c",
    "Conversion_Type__c",
    "Converted_By__c",
    "Contact_Us__c",
    "Engagement_AI_Summary__c"
  ];

  const desiredOcrFields = [
    "Id",
    "ContactId",
    "OpportunityId",
    "CreatedDate",
    // Custom formula field referenced by the Set_to_MQL flow
    "Open_Opportunity__c"
  ];

  const desiredOppFields = [
    "Id",
    "Name",
    "StageName",
    "IsClosed",
    "IsWon",
    "CloseDate",
    "Amount",
    "OwnerId",
    "AccountId",
    "CreatedDate",
    "LastModifiedDate"
  ];

  const contactFields = pickExistingFields(
    contactDescribe,
    desiredContactFields
  );
  const accountFields = pickExistingFields(
    accountDescribe,
    desiredAccountFields
  );
  const mqlFields = pickExistingFields(mqlDescribe, desiredMqlFields);
  const ocrFields = pickExistingFields(ocrDescribe, desiredOcrFields);
  const oppFields = pickExistingFields(oppDescribe, desiredOppFields);

  let contact = null;
  let mql = null;

  if (mqlId) {
    const mqlRecords = queryRecords({
      targetOrg,
      soql: soqlSelect("MQL__c", mqlFields, `Id = '${mqlId}' LIMIT 1`)
    });
    mql = mqlRecords[0] || null;
    if (mql?.Contact__c) {
      const contactRecords = queryRecords({
        targetOrg,
        soql: soqlSelect(
          "Contact",
          contactFields,
          `Id = '${mql.Contact__c}' LIMIT 1`
        )
      });
      contact = contactRecords[0] || null;
    }
  } else {
    const contactRecords = queryRecords({
      targetOrg,
      soql: soqlSelect("Contact", contactFields, `Id = '${contactId}' LIMIT 1`)
    });
    contact = contactRecords[0] || null;
  }

  if (!contact) {
    console.error("Contact not found (or insufficient access).");
    process.exit(3);
  }

  // Get latest MQL for contact if we weren't provided one.
  if (!mql) {
    const mqlRecords = queryRecords({
      targetOrg,
      soql:
        `SELECT ${mqlFields.join(", ")} FROM MQL__c WHERE Contact__c = '${contact.Id}' ` +
        "ORDER BY CreatedDate DESC LIMIT 1"
    });
    mql = mqlRecords[0] || null;
  }

  const account = contact.AccountId
    ? queryRecords({
        targetOrg,
        soql: soqlSelect(
          "Account",
          accountFields,
          `Id = '${contact.AccountId}' LIMIT 1`
        )
      })[0] || null
    : null;

  // Open opportunity detection as implemented in the flow:
  // OCR where ContactId = contact.Id and Open_Opportunity__c = true
  const ocrWhere = ocrFields.includes("Open_Opportunity__c")
    ? `ContactId = '${contact.Id}' AND Open_Opportunity__c = true`
    : `ContactId = '${contact.Id}'`;

  const ocr = queryRecords({
    targetOrg,
    soql: `SELECT ${ocrFields.join(", ")} FROM OpportunityContactRole WHERE ${ocrWhere} LIMIT 50`
  });

  const oppIds = Array.from(
    new Set(ocr.map((r) => r.OpportunityId).filter(Boolean))
  );
  const opportunities = oppIds.length
    ? queryRecords({
        targetOrg,
        soql: `SELECT ${oppFields.join(", ")} FROM Opportunity WHERE Id IN ${safeInClause(
          oppIds
        )} ORDER BY LastModifiedDate DESC LIMIT 50`
      })
    : [];

  // Recent activities (Salesforce-side). We keep these bounded.
  const sinceDays = Number(args["since-days"] || 90);
  const sinceExpr = `LAST_N_DAYS:${sinceDays}`;

  const tasks = queryRecords({
    targetOrg,
    soql:
      "SELECT Id, Subject, Status, Priority, ActivityDate, CreatedDate, LastModifiedDate, " +
      "WhoId, WhatId, OwnerId, Type " +
      `FROM Task WHERE WhoId = '${contact.Id}' AND CreatedDate = ${sinceExpr} ` +
      "ORDER BY ActivityDate DESC NULLS LAST, CreatedDate DESC LIMIT 200"
  });

  const events = queryRecords({
    targetOrg,
    soql:
      "SELECT Id, Subject, ActivityDate, StartDateTime, EndDateTime, CreatedDate, LastModifiedDate, " +
      "WhoId, WhatId, OwnerId, Location " +
      `FROM Event WHERE WhoId = '${contact.Id}' AND CreatedDate = ${sinceExpr} ` +
      "ORDER BY StartDateTime DESC NULLS LAST, CreatedDate DESC LIMIT 200"
  });

  // Optional CRM timeline objects. These can be permissioned differently by org.
  function tryQueryRecords(soql) {
    try {
      return queryRecords({ targetOrg, soql });
    } catch (e) {
      return null;
    }
  }

  // EmailMessage can be sensitive. We intentionally omit body fields from discovery output.
  const emailMessages = tryQueryRecords(
    "SELECT Id, Subject, FromAddress, ToAddress, MessageDate, Status, Incoming, " +
      "CreatedDate, LastModifiedDate, ParentId, RelatedToId " +
      "FROM EmailMessage " +
      `WHERE (RelatedToId = '${contact.Id}' OR ParentId = '${contact.Id}') AND CreatedDate = ${sinceExpr} ` +
      "ORDER BY MessageDate DESC NULLS LAST, CreatedDate DESC LIMIT 200"
  );

  // Campaign touches are often essential for the narrative (even if campaigns are a separate project).
  const campaignMembers = tryQueryRecords(
    "SELECT Id, CampaignId, Campaign.Name, Status, HasResponded, FirstRespondedDate, CreatedDate " +
      "FROM CampaignMember " +
      `WHERE ContactId = '${contact.Id}' AND CreatedDate = LAST_N_DAYS:365 ` +
      "ORDER BY CreatedDate DESC LIMIT 200"
  );

  // Contact Us submissions exist as a Salesforce object in this repo; useful for narrative root cause.
  // We prefer querying by Contact email to catch cases where Contact is created after submission.
  const contactUsSubmissions =
    contact.Email && String(contact.Email).trim()
      ? tryQueryRecords(
          "SELECT Id, Topic__c, Source__c, CreatedDate " +
            "FROM Contact_Us__c " +
            `WHERE Email__c = '${String(contact.Email).replaceAll("'", "\\'")}' AND CreatedDate = LAST_N_DAYS:365 ` +
            "ORDER BY CreatedDate DESC LIMIT 50"
        )
      : null;

  // Optional: history tables (only if enabled in org). We probe by trying a small query.
  function tryQueryHistory(soql) {
    try {
      return queryRecords({ targetOrg, soql });
    } catch (e) {
      return null;
    }
  }

  const contactHistory = tryQueryHistory(
    "SELECT ContactId, Field, OldValue, NewValue, CreatedDate, CreatedById " +
      `FROM ContactHistory WHERE ContactId = '${contact.Id}' AND CreatedDate = LAST_N_DAYS:180 ` +
      "ORDER BY CreatedDate DESC LIMIT 500"
  );

  const oppHistory = opportunities.length
    ? tryQueryHistory(
        "SELECT OpportunityId, Field, OldValue, NewValue, CreatedDate, CreatedById " +
          `FROM OpportunityFieldHistory WHERE OpportunityId IN ${safeInClause(
            opportunities.map((o) => o.Id)
          )} AND CreatedDate = LAST_N_DAYS:180 ` +
          "ORDER BY CreatedDate DESC LIMIT 500"
      )
    : null;

  const mqlHistory = mql?.Id
    ? tryQueryHistory(
        "SELECT ParentId, Field, OldValue, NewValue, CreatedDate, CreatedById " +
          `FROM MQL__History WHERE ParentId = '${mql.Id}' AND CreatedDate = LAST_N_DAYS:365 ` +
          "ORDER BY CreatedDate DESC LIMIT 500"
      )
    : null;

  // Discover candidate HubSpot id fields on Contact (if present).
  const hubspotIdCandidates = (contactDescribe?.fields || [])
    .map((f) => f.name)
    .filter((name) => /hubspot|hs_|vid|objectid/i.test(name))
    .sort();

  const payload = {
    metadata: {
      collectedAt: new Date().toISOString(),
      targetOrg,
      inputs: { contactId: contactId || null, mqlId: mqlId || null, sinceDays },
      fieldSets: {
        contactFields,
        accountFields,
        mqlFields,
        ocrFields,
        oppFields
      },
      hubspotIdCandidates
    },
    contact,
    account,
    mql,
    opportunityContactRoles: ocr,
    opportunities,
    tasks,
    events,
    emailMessages: emailMessages || undefined,
    campaignMembers: campaignMembers || undefined,
    contactUsSubmissions: contactUsSubmissions || undefined,
    history: {
      contactHistory: contactHistory || undefined,
      opportunityFieldHistory: oppHistory || undefined,
      mqlHistory: mqlHistory || undefined
    }
  };

  const basisId = mqlId || contactId || contact.Id;
  const outPath = path.join(outDir, `${nowStamp()}_${basisId}.json`);
  fs.writeFileSync(outPath, JSON.stringify(payload, null, 2));

  // Emit a smaller, LLM-facing preview stream using the canonical recipe.
  const allowlist = loadAllowlist();
  if (allowlist) {
    const preview = buildHistoryEventsPreview({
      allowlist,
      contact,
      mql,
      opportunityContactRoles: ocr,
      opportunities,
      tasks,
      events,
      emailMessages: emailMessages || [],
      campaignMembers: campaignMembers || [],
      contactUsSubmissions: contactUsSubmissions || [],
      history: {
        contactHistory: contactHistory || [],
        opportunityFieldHistory: oppHistory || [],
        mqlHistory: mqlHistory || []
      },
      sinceDays
    });
    const previewPath = outPath.replace(
      /\.json$/,
      "_history_events_preview.json"
    );
    fs.writeFileSync(previewPath, JSON.stringify(preview, null, 2));
  }

  console.log(outPath);
}

main().catch((e) => {
  console.error(e.message || e);
  process.exit(1);
});
