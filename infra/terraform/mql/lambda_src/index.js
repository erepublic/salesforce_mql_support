/* eslint-disable no-console */

// AWS Lambda (Node.js 20) handler for the MQL summarizer.
//
// This is deployed twice (sandbox + production) and driven by:
// - API Gateway stage (/sandbox|/production/summarize)
// - Lambda env var ENVIRONMENT (sandbox|production)
//
// It returns JSON:
//   { summaryHtml: "<p>...</p>", meta: {...} }
//
// If Salesforce/HubSpot secrets are not configured yet, it still returns a
// placeholder summary so the end-to-end callout path is verifiable.

const {
  SecretsManagerClient,
  GetSecretValueCommand
} = require("@aws-sdk/client-secrets-manager");
const crypto = require("crypto");

const secrets = new SecretsManagerClient({});

// Keep the canonical allowlist/timeline recipe inside the Lambda bundle so the
// deployed behavior matches what discovery emits.
const allowlist = require("./mql_allowlist_v1.json");
const {
  buildSalesNarrativeInput,
  redactInlineText
} = require("./sales_prompt_utils");

const productInterestRules = require("./product_interest_rules_v1.json");
const {
  buildEvidenceFromSalesLeadWebActivity,
  buildEvidenceFromCampaignMembers,
  buildEvidenceFromHubspotContactProps,
  inferProductInterest
} = require("./product_interest");
const {
  getHubspotToken,
  getHubspotBaseUrl,
  searchContactIdByEmail,
  getContactProperties
} = require("./hubspot_client");

// Cache describe results across warm Lambda invocations to reduce Salesforce
// round-trips and stay under API Gateway timeouts.
const sfDescribeCache = new Map();

function jsonResponse(statusCode, bodyObj) {
  return {
    statusCode,
    headers: { "content-type": "application/json" },
    body: JSON.stringify(bodyObj)
  };
}

function safeJsonParse(s) {
  try {
    return JSON.parse(s);
  } catch {
    return null;
  }
}

function nowIso() {
  return new Date().toISOString();
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

function escapeHtml(s) {
  return String(s)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/\"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function sanitizeHtmlForSalesforceField(html) {
  // Salesforce HTML fields expect an HTML fragment. Keep this conservative and
  // predictable so we never store unsafe markup.
  //
  // Allowed tags: p, strong, ul, li, br, em, a
  // - Non-<a> tags have ALL attributes stripped.
  // - <a> is rewritten to a safe form: only https:// or / href; no JS/data; and
  //   we force target/rel for safety. (We append our own Salesforce links.)
  let s = String(html || "");

  // Normalize common Unicode punctuation to ASCII to avoid odd rendering.
  s = s
    .replace(/\u2014/g, "-") // em dash
    .replace(/\u2013/g, "-") // en dash
    .replace(/\u2018|\u2019/g, "'") // curly single quotes
    .replace(/\u201C|\u201D/g, '"'); // curly double quotes

  // Remove doctype and html/head/body wrappers.
  s = s.replace(/<!doctype[^>]*>/gi, "");
  s = s.replace(/<\s*html[^>]*>/gi, "").replace(/<\s*\/\s*html\s*>/gi, "");
  s = s.replace(/<\s*head[^>]*>[\s\S]*?<\s*\/\s*head\s*>/gi, "");
  s = s.replace(/<\s*body[^>]*>/gi, "").replace(/<\s*\/\s*body\s*>/gi, "");

  // Remove scripts/styles/links/meta (CSS or doc-head cruft).
  s = s.replace(/<\s*style[^>]*>[\s\S]*?<\s*\/\s*style\s*>/gi, "");
  s = s.replace(/<\s*script[^>]*>[\s\S]*?<\s*\/\s*script\s*>/gi, "");
  s = s.replace(/<\s*link[^>]*>/gi, "");
  s = s.replace(/<\s*meta[^>]*>/gi, "");

  // Strip any non-allowlisted tags entirely.
  s = s.replace(/<(?!\/?(p|strong|ul|li|br|em|a)\b)[^>]*>/gi, "");

  // Normalize <br> variants.
  s = s.replace(/<\s*br\s*>/gi, "<br/>").replace(/<\s*br\s*\/\s*>/gi, "<br/>");

  // Strip attributes from non-anchor allowed tags.
  s = s.replace(/<\s*(p|strong|ul|li|em)\b[^>]*>/gi, "<$1>");

  // Rewrite anchors to a safe subset.
  s = s.replace(/<\s*a\b[^>]*>/gi, (tag) => {
    const m = tag.match(/href\s*=\s*(['"])(.*?)\1/i);
    const hrefRaw = m ? String(m[2] || "").trim() : "";
    const href = hrefRaw;
    const safe =
      href &&
      (href.startsWith("https://") || href.startsWith("/")) &&
      !/^javascript:/i.test(href) &&
      !/^data:/i.test(href);
    if (!safe) return "<a>";
    return `<a href="${escapeHtml(href)}" target="_blank" rel="noopener">`;
  });

  // Tidy whitespace.
  s = s.replace(/\r\n/g, "\n").trim();
  return s;
}

function truncateHtmlForSalesforceField(html, maxChars) {
  // Engagement_AI_Summary__c is an Html field with a 32,768 char limit in SF.
  // Keep a little headroom to avoid edge cases (e.g. truncation notice).
  const max = Number.isFinite(Number(maxChars)) ? Number(maxChars) : 32000;
  let s = String(html || "");
  if (s.length <= max) return s;
  // Truncate safely at a character boundary. We avoid adding any non-ASCII chars.
  s = s.slice(0, max);
  return `${s}\n<p><em>Summary truncated for storage limits.</em></p>`;
}

function isSalesforceId(value) {
  const s = String(value || "").trim();
  return /^[A-Za-z0-9]{15,18}$/.test(s);
}

function safeSfRecordUrl(instanceUrl, recordId) {
  const base = String(instanceUrl || "")
    .trim()
    .replace(/\/+$/, "");
  if (!base.startsWith("https://")) return null;
  if (!isSalesforceId(recordId)) return null;
  return `${base}/${String(recordId).trim()}`;
}

function buildRelatedRecordsHtml({
  instanceUrl,
  mql,
  opportunities,
  opportunityContactRoles
}) {
  const links = [];

  // Product (from MQL.Product__c)
  if (mql?.Product__c) {
    const url = safeSfRecordUrl(instanceUrl, mql.Product__c);
    if (url) {
      const name = mql?.Product_Name__c
        ? String(mql.Product_Name__c).trim()
        : "";
      links.push({
        label: name ? `Product: ${name}` : "Product record",
        href: url
      });
    }
  }

  // Open opportunities (prefer OCR Open_Opportunity__c=true when present)
  const ocrList = Array.isArray(opportunityContactRoles)
    ? opportunityContactRoles
    : [];
  const hasOpenFlag = ocrList.some((r) =>
    r ? Object.prototype.hasOwnProperty.call(r, "Open_Opportunity__c") : false
  );
  const oppIdCandidates = [];
  if (mql?.Opportunity__c) oppIdCandidates.push(mql.Opportunity__c);
  for (const r of ocrList) {
    if (!r?.OpportunityId) continue;
    if (hasOpenFlag) {
      if (r.Open_Opportunity__c === true) oppIdCandidates.push(r.OpportunityId);
    } else {
      // If we don't have the open-opp flag in this org, fall back to "known OCR".
      oppIdCandidates.push(r.OpportunityId);
    }
  }
  const oppIds = Array.from(new Set(oppIdCandidates.filter(Boolean))).slice(
    0,
    5
  );

  const oppById = new Map((opportunities || []).map((o) => [o.Id, o]));
  for (const oppId of oppIds) {
    const url = safeSfRecordUrl(instanceUrl, oppId);
    if (!url) continue;
    const opp = oppById.get(oppId);
    const name = opp?.Name ? String(opp.Name).trim() : "";
    const stage = opp?.StageName ? String(opp.StageName).trim() : "";
    const label = name
      ? stage
        ? `Opportunity: ${name} (${stage})`
        : `Opportunity: ${name}`
      : "Opportunity record";
    links.push({ label, href: url });
  }

  if (!links.length) return "";
  const li = links
    .map(
      (x) =>
        `<li><a href="${escapeHtml(x.href)}" target="_blank" rel="noopener">${escapeHtml(x.label)}</a></li>`
    )
    .join("");
  return [`<p><strong>Links</strong></p>`, `<ul>${li}</ul>`].join("\n");
}

function enforceSalesSummarySectionCaps(html) {
  // Keep summaries succinct and predictable. We enforce caps post-generation so
  // the LLM can be a little messy without breaking the stored field.
  //
  // Note: engagement bullets are already date-prefixed upstream; we do not try
  // to "invent" dates here.
  const caps = new Map([
    ["Why Sales Should Care", 5],
    ["Score Interpretation", 4],
    ["Most Recent Engagement", 12],
    ["Suggested Next Step", 2]
  ]);

  let s = String(html || "");
  for (const [heading, maxItems] of caps.entries()) {
    const marker = `<p><strong>${heading}</strong></p>`;
    const idx = s.indexOf(marker);
    if (idx === -1) continue;
    const ulStart = s.indexOf("<ul>", idx);
    const ulEnd = ulStart === -1 ? -1 : s.indexOf("</ul>", ulStart);
    if (ulStart === -1 || ulEnd === -1) continue;
    const inner = s.slice(ulStart + 4, ulEnd);
    const items = inner.match(/<li>[\s\S]*?<\/li>/gi) || [];
    const kept = items.slice(0, maxItems).join("");
    s = `${s.slice(0, ulStart + 4)}${kept}${s.slice(ulEnd)}`;
  }
  return s;
}

function finalizeSalesSummaryHtml({
  html,
  instanceUrl,
  mql,
  opportunities,
  opportunityContactRoles
}) {
  let out = sanitizeHtmlForSalesforceField(html || "");
  out = enforceSalesSummarySectionCaps(out);

  const links = buildRelatedRecordsHtml({
    instanceUrl,
    mql,
    opportunities,
    opportunityContactRoles
  });
  if (links) out = `${out}\n${links}`;

  // Final pass: sanitize + truncate for field storage limits.
  out = truncateHtmlForSalesforceField(
    sanitizeHtmlForSalesforceField(out),
    32000
  );
  return out;
}

function looksLikeFieldOrIdLeak(s) {
  const text = String(s || "");
  if (!text) return false;

  // Allow Salesforce record IDs inside link href attributes, but never in
  // visible text. We strip href values before running leak detection.
  const scan = text.replace(/href\s*=\s*(['"])[\s\S]*?\1/gi, 'href=""');

  // Field/object naming patterns and common system tokens we never want in the
  // final Sales-facing HTML.
  const forbidden = [
    /__c\b/,
    /__r\b/,
    /\bHubSpot_/,
    /\bOpportunityContactRole\b/,
    /\bMQL__c\b/,
    /\bSalesforce\b/i,
    /\bHubSpot\b/i,
    // Common SF ID prefixes (15/18 char alphanum). Keep this conservative to
    // avoid false positives, while still blocking obvious leaks.
    /\b(?:003|00Q|00T|006|a0X)[A-Za-z0-9]{12,15}\b/
  ];
  return forbidden.some((re) => re.test(scan));
}

function validateSalesFacingHtml(html) {
  const s = String(html || "");
  const reasons = [];
  if (!s.trim()) reasons.push("empty_html");
  if (looksLikeFieldOrIdLeak(s)) reasons.push("field_or_id_leak");

  // Block obviously unsafe anchor schemes.
  const unsafeAnchor =
    /<\s*a\b[^>]*href\s*=\s*(['"])\s*(javascript:|data:)/i.test(s);
  if (unsafeAnchor) reasons.push("unsafe_anchor_href");

  const requiredHeadings = [
    "Why Sales Should Care",
    "Score Interpretation",
    "Most Recent Engagement",
    "Suggested Next Step"
  ];
  for (const h of requiredHeadings) {
    if (!s.includes(`<p><strong>${h}</strong></p>`))
      reasons.push(`missing_heading:${h}`);
  }

  return { ok: reasons.length === 0, reasons };
}

function buildDeterministicSalesSummaryHtml(salesNarrativeInput) {
  const input =
    salesNarrativeInput && typeof salesNarrativeInput === "object"
      ? salesNarrativeInput
      : {};

  const keyReasons = Array.isArray(input.keyReasons) ? input.keyReasons : [];
  const topProducts = Array.isArray(input?.productInterest?.topProducts)
    ? input.productInterest.topProducts
    : [];
  const scoreInterpretation = Array.isArray(input.scoreInterpretation)
    ? input.scoreInterpretation
    : [];
  const recentEngagement = Array.isArray(input.recentEngagement)
    ? input.recentEngagement
    : [];
  const fitConcerns = Array.isArray(input?.fit?.concerns)
    ? input.fit.concerns
    : [];

  const hasInbound = keyReasons.some((r) =>
    String(r || "")
      .toLowerCase()
      .includes("inbound")
  );

  const whySales = [];
  if (topProducts.length) {
    const names = topProducts
      .map((p) => String(p?.name || "").trim())
      .filter(Boolean)
      .slice(0, 3);
    if (names.length) {
      whySales.push(
        `Likely areas of interest based on recent web/marketing signals: ${names.join(
          ", "
        )}.`
      );
    }
  }
  const openOpps = Array.isArray(input?.opportunityContext?.openOpportunities)
    ? input.opportunityContext.openOpportunities
    : [];
  if (openOpps.length) {
    const prodSet = new Set();
    for (const o of openOpps) {
      for (const p of o?.products || []) {
        if (p) prodSet.add(String(p));
      }
    }
    const prodList = Array.from(prodSet).slice(0, 5);
    if (prodList.length) {
      whySales.push(
        `Open opportunity product(s) on the account include: ${prodList.join(
          ", "
        )}.`
      );
    }
  }
  for (const r of keyReasons) {
    if (!r) continue;
    whySales.push(String(r));
    if (whySales.length >= 6) break;
  }
  if (!whySales.length) {
    whySales.push(
      "Engagement and marketing signals suggest they may be evaluating solutions; review recent activity and prioritize outreach accordingly."
    );
  }

  const scoreBullets = [];
  for (const r of scoreInterpretation) {
    if (!r) continue;
    scoreBullets.push(String(r));
    if (scoreBullets.length >= 5) break;
  }
  if (fitConcerns.length) {
    for (const c of fitConcerns.slice(0, 3)) scoreBullets.push(String(c));
  }

  const engagementBullets = recentEngagement.slice(0, 12).map((e) => {
    const date = e?.date ? String(e.date) : "Unknown date";
    const highlight = e?.highlight
      ? String(e.highlight)
      : "Engagement activity";
    return `${date} - ${highlight}`;
  });

  // Suggested next steps: keep it actionable + verification-oriented.
  const nextSteps = [];
  if (hasInbound) {
    nextSteps.push(
      "Follow up quickly and reference their inbound request; confirm what prompted them to reach out and what timeline they are working on."
    );
  } else {
    nextSteps.push(
      "Use recent engagement as the opener and propose a short discovery call; confirm what they are evaluating and who else is involved."
    );
  }
  if (fitConcerns.length) {
    nextSteps.push(
      "Verify fit early (industry/eligibility, role, and company details) before investing a full-cycle effort."
    );
  }
  if (input?.opportunity?.hasOpenOpportunity === true) {
    nextSteps.push(
      "Check whether there is already an active opportunity and align outreach to the current stage and owner."
    );
  }

  function ul(items) {
    const list = (items || []).filter(Boolean);
    if (!list.length)
      return "<ul><li>Not enough information available.</li></ul>";
    return `<ul>${list.map((x) => `<li>${escapeHtml(x)}</li>`).join("")}</ul>`;
  }

  return [
    `<p><strong>Why Sales Should Care</strong></p>`,
    ul(whySales.slice(0, 6)),
    `<p><strong>Score Interpretation</strong></p>`,
    ul(scoreBullets.slice(0, 6)),
    `<p><strong>Most Recent Engagement</strong></p>`,
    ul(engagementBullets.slice(0, 12)),
    `<p><strong>Suggested Next Step</strong></p>`,
    ul(nextSteps.slice(0, 2))
  ].join("\n");
}

function buildOpenAiMessages({ salesNarrativeInput }) {
  const system = [
    "You are writing for Sales reps (non-technical).",
    "Use only the provided JSON; do not invent details.",
    "Return an HTML fragment only (no doctype/html/head/body).",
    "Use simple HTML only: <p>, <strong>, <ul>, <li>, <br/>, <em>.",
    "Do not include hyperlinks; Salesforce links are appended automatically.",
    "No CSS or styling (<style>, style=, class=, link/meta/script).",
    "Do not include Salesforce/HubSpot field names, object names, IDs, or JSON keys in the output.",
    "Do not include raw numeric scores; keep score language qualitative (Strong/Moderate/Light)."
  ].join("\n");

  const user = [
    "Write an HTML summary with these sections (use <p><strong>Section</strong></p> headings):",
    "1) Why Sales Should Care",
    "   - 3-6 bullets.",
    "   - Each bullet explains a SALES signal and why it matters (value-based).",
    "   - Avoid technical phrasing; write like a rep-to-rep handoff.",
    "   - If product-interest signals are present, include 1-2 bullets explicitly stating what they are likely evaluating and why (cite the evidence in plain language).",
    "   - If open opportunities include product names, call out the product(s) tied to those opportunities (this is often the clearest 'what they want').",
    "2) Score Interpretation",
    "   - 3-4 bullets interpreting Fit and Intent qualitatively (Strong/Moderate/Light).",
    "   - If an inbound request exists, treat as time-sensitive, but still flag any fit concerns.",
    "3) Most Recent Engagement",
    "   - 5-12 bullets, newest-first (most recent first).",
    "   - Each bullet MUST start with a date (YYYY-MM-DD) then a short plain-English highlight.",
    "   - If an engagement is tied to a specific opportunity/product, mention that product in the highlight.",
    "4) Suggested Next Step",
    "   - 1-2 bullets: best outreach angle + what to verify + urgency.",
    "   - If product-interest signals exist, tailor the outreach angle to those likely interests.",
    "",
    "Important constraints:",
    "- Do not include any field names, IDs, JSON keys, or system names.",
    "- Do not include numeric scores or threshold values; describe them qualitatively only.",
    "- If something is unclear/missing, say so plainly (do not guess).",
    "",
    "Structured input JSON (do not echo keys):",
    JSON.stringify(compactObject(salesNarrativeInput || {}))
  ].join("\n");

  return { system, user };
}

function buildBasicSummaryHtml({ env, mqlId, contactId, message }) {
  return [
    `<p><strong>MQL Engagement Summary</strong></p>`,
    `<p>Environment: ${escapeHtml(env || "unknown")}</p>`,
    `<p>MQL Id: ${escapeHtml(mqlId || "n/a")}</p>`,
    `<p>Contact Id: ${escapeHtml(contactId || "n/a")}</p>`,
    message ? `<p>${escapeHtml(message)}</p>` : "",
    `<p><em>Generated: ${escapeHtml(nowIso())}</em></p>`
  ]
    .filter(Boolean)
    .join("\n");
}

async function getSecretJson(secretArn) {
  if (!secretArn) return null;
  try {
    const out = await secrets.send(
      new GetSecretValueCommand({ SecretId: secretArn })
    );
    const raw = out.SecretString || null;
    if (!raw) return null;
    const parsed = safeJsonParse(raw);
    return parsed && typeof parsed === "object" ? parsed : null;
  } catch (err) {
    // Secret might exist with no value yet; treat as unconfigured.
    console.warn("secret_read_failed", {
      secretArn,
      name: err?.name,
      message: err?.message
    });
    return null;
  }
}

async function fetchWithTimeout(url, options, timeoutMs) {
  const controller = new AbortController();
  const t = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(url, { ...options, signal: controller.signal });
  } finally {
    clearTimeout(t);
  }
}

function base64UrlEncode(buf) {
  return Buffer.from(buf)
    .toString("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

function signJwtRs256({ header, payload, privateKeyPem }) {
  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedPayload = base64UrlEncode(JSON.stringify(payload));
  const signingInput = `${encodedHeader}.${encodedPayload}`;
  const signer = crypto.createSign("RSA-SHA256");
  signer.update(signingInput);
  const signature = signer.sign(privateKeyPem);
  const encodedSig = base64UrlEncode(signature);
  return `${signingInput}.${encodedSig}`;
}

async function salesforceJwtBearerLogin(sfSecret) {
  // Expected keys (minimal):
  // - loginUrl (e.g. https://test.salesforce.com or https://login.salesforce.com)
  // - clientId
  // - username
  // - privateKeyPem (PEM string, with newlines)
  const loginUrl = sfSecret?.loginUrl;
  const clientId = sfSecret?.clientId;
  const username = sfSecret?.username;
  const privateKeyPem = sfSecret?.privateKeyPem;

  if (!loginUrl || !clientId || !username || !privateKeyPem) {
    return null;
  }

  const nowSec = Math.floor(Date.now() / 1000);
  const jwt = signJwtRs256({
    header: { alg: "RS256", typ: "JWT" },
    payload: {
      iss: clientId,
      sub: username,
      aud: loginUrl,
      exp: nowSec + 3 * 60
    },
    privateKeyPem
  });

  const tokenUrl = `${loginUrl.replace(/\/+$/, "")}/services/oauth2/token`;
  const params = new URLSearchParams();
  params.set("grant_type", "urn:ietf:params:oauth:grant-type:jwt-bearer");
  params.set("assertion", jwt);

  const resp = await fetch(tokenUrl, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: params.toString()
  });

  const text = await resp.text();
  if (!resp.ok) {
    console.warn("sf_token_failed", {
      status: resp.status,
      body: text?.slice(0, 2000)
    });
    return null;
  }

  const json = safeJsonParse(text);
  if (!json?.access_token || !json?.instance_url) return null;
  return { accessToken: json.access_token, instanceUrl: json.instance_url };
}

async function salesforcePasswordLogin(sfSecret) {
  // Supports "username-password" OAuth flow.
  //
  // Accepts either camelCase keys or SF_* keys (so we can reuse your .env naming):
  // - loginUrl / SF_LOGIN_URL
  // - consumerKey / SF_CONSUMER_KEY
  // - consumerSecret / SF_CONSUMER_SECRET
  // - username / SF_USERNAME
  // - password / SF_PASSWORD
  const loginUrl = sfSecret?.loginUrl || sfSecret?.SF_LOGIN_URL;
  const consumerKey = sfSecret?.consumerKey || sfSecret?.SF_CONSUMER_KEY;
  const consumerSecret =
    sfSecret?.consumerSecret || sfSecret?.SF_CONSUMER_SECRET;
  const username = sfSecret?.username || sfSecret?.SF_USERNAME;
  const password = sfSecret?.password || sfSecret?.SF_PASSWORD;

  if (!loginUrl || !consumerKey || !consumerSecret || !username || !password) {
    return null;
  }

  const tokenUrl = `${String(loginUrl).replace(/\/+$/, "")}/services/oauth2/token`;
  const params = new URLSearchParams();
  params.set("grant_type", "password");
  params.set("client_id", consumerKey);
  params.set("client_secret", consumerSecret);
  params.set("username", username);
  params.set("password", password);

  const resp = await fetch(tokenUrl, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: params.toString()
  });

  const text = await resp.text();
  if (!resp.ok) {
    console.warn("sf_password_token_failed", {
      status: resp.status,
      body: text?.slice(0, 2000)
    });
    return null;
  }

  const json = safeJsonParse(text);
  if (!json?.access_token || !json?.instance_url) return null;
  return { accessToken: json.access_token, instanceUrl: json.instance_url };
}

async function salesforceLogin(sfSecret) {
  if (!sfSecret) return null;

  const authMethod =
    sfSecret?.authMethod ||
    sfSecret?.SF_AUTH_METHOD ||
    (sfSecret?.privateKeyPem ? "JwtBearer" : null);

  if (authMethod === "UserPassword") {
    return salesforcePasswordLogin(sfSecret);
  }

  // Default: JWT bearer if configured.
  return salesforceJwtBearerLogin(sfSecret);
}

async function sfQuery({ instanceUrl, accessToken, apiVersion, soql }) {
  const url = `${instanceUrl}/services/data/v${apiVersion}/query?q=${encodeURIComponent(soql)}`;
  const resp = await fetch(url, {
    headers: { authorization: `Bearer ${accessToken}` }
  });
  const text = await resp.text();
  if (!resp.ok) {
    throw new Error(
      `Salesforce query failed: ${resp.status}: ${text.slice(0, 2000)}`
    );
  }
  const json = safeJsonParse(text);
  return json;
}

async function sfDescribe({ instanceUrl, accessToken, apiVersion, sobject }) {
  const url = `${instanceUrl}/services/data/v${apiVersion}/sobjects/${encodeURIComponent(
    sobject
  )}/describe`;
  const resp = await fetch(url, {
    headers: { authorization: `Bearer ${accessToken}` }
  });
  const text = await resp.text();
  if (!resp.ok) {
    throw new Error(
      `Salesforce describe failed: ${resp.status}: ${text.slice(0, 2000)}`
    );
  }
  return safeJsonParse(text) || null;
}

async function sfDescribeCached({
  instanceUrl,
  accessToken,
  apiVersion,
  sobject
}) {
  const key = `${instanceUrl}|v${apiVersion}|${sobject}`;
  if (sfDescribeCache.has(key)) return sfDescribeCache.get(key);
  const d = await sfDescribe({ instanceUrl, accessToken, apiVersion, sobject });
  sfDescribeCache.set(key, d);
  return d;
}

async function sfGetLimits({ instanceUrl, accessToken, apiVersion }) {
  const url = `${instanceUrl}/services/data/v${apiVersion}/limits`;
  const resp = await fetch(url, {
    headers: { authorization: `Bearer ${accessToken}` }
  });
  const text = await resp.text();
  if (!resp.ok) {
    throw new Error(
      `Salesforce limits failed: ${resp.status}: ${text.slice(0, 500)}`
    );
  }
  return safeJsonParse(text) || null;
}

function buildSummaryFromSf({ env, mql, contact }) {
  const lines = [];
  const productName =
    mql?.Product__r?.Name || mql?.Product_Name__c || mql?.Product__c || "";
  const mqlDate = mql?.MQL_Date__c || mql?.CreatedDate || "";

  lines.push(`<p><strong>MQL Summary</strong></p>`);
  if (productName)
    lines.push(`<p>Product interest: ${escapeHtml(productName)}</p>`);
  if (mqlDate)
    lines.push(
      `<p>MQL created: ${escapeHtml(String(mqlDate).slice(0, 10))}</p>`
    );
  lines.push(
    `<p>Automated engagement narrative is temporarily unavailable. Review recent engagement activity and marketing signals in Salesforce.</p>`
  );
  return lines.join("\n");
}

function pickExistingFields(describe, desiredFields) {
  const fieldNames = new Set((describe?.fields || []).map((f) => f.name));
  return desiredFields.filter((f) => fieldNames.has(f));
}

function safeInClause(ids) {
  const clean = (ids || []).filter(Boolean);
  if (!clean.length) return "(null)";
  const quoted = clean.map((id) => `'${String(id).replaceAll("'", "\\'")}'`);
  return `(${quoted.join(",")})`;
}

async function trySfQueryRecords({
  instanceUrl,
  accessToken,
  apiVersion,
  soql
}) {
  try {
    const res = await sfQuery({ instanceUrl, accessToken, apiVersion, soql });
    return res?.records || [];
  } catch (e) {
    return null;
  }
}

function buildHistoryEventsPreview({
  allowlist,
  contact,
  mql,
  opportunityContactRoles,
  opportunities,
  opportunityLineItems,
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
  const oliList = Array.isArray(opportunityLineItems)
    ? opportunityLineItems
    : [];
  const productNamesByOppId = new Map();
  for (const oli of oliList) {
    const oppId = oli?.OpportunityId;
    const productName = oli?.PricebookEntry?.Product2?.Name || null;
    if (!oppId || !productName) continue;
    if (!productNamesByOppId.has(oppId)) productNamesByOppId.set(oppId, []);
    const list = productNamesByOppId.get(oppId);
    if (!list.includes(productName)) list.push(productName);
  }

  function normalizeTextSnippet(s, maxLen) {
    const raw = redactInlineText(s);
    if (!raw) return null;
    const flat = String(raw).replace(/\s+/g, " ").trim();
    if (!flat) return null;
    const max = Number.isFinite(maxLen) ? maxLen : 140;
    return flat.length > max ? `${flat.slice(0, max)}...` : flat;
  }

  function oppProductsLabel(oppId) {
    const list = productNamesByOppId.get(oppId) || [];
    const names = list
      .map((x) => String(x).trim())
      .filter(Boolean)
      .slice(0, 3);
    if (!names.length) return null;
    return names.join(", ");
  }

  function oppContextLabel(oppId) {
    const opp = oppById.get(oppId);
    if (!opp) return null;
    const parts = [];
    if (opp?.Name) parts.push(String(opp.Name));
    if (opp?.StageName) parts.push(String(opp.StageName));
    const products = oppProductsLabel(oppId);
    if (products) parts.push(products);
    return parts.length ? parts.join(" | ") : null;
  }

  function findLinkedOppId(id) {
    if (!id) return null;
    const s = String(id);
    if (oppById.has(s)) return s;
    return null;
  }

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
      detail: opp
        ? [
            opp?.Name,
            opp?.StageName,
            oppProductsLabel(opp.Id)
              ? `Products: ${oppProductsLabel(opp.Id)}`
              : null
          ]
            .filter(Boolean)
            .join(" | ") || undefined
        : undefined,
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
    const linkedOppId = findLinkedOppId(t.WhatId);
    const ctx = linkedOppId ? oppContextLabel(linkedOppId) : null;
    const detailParts = [];
    if (t.Subject) detailParts.push(String(t.Subject));
    const desc = normalizeTextSnippet(t.Description, 140);
    if (desc) detailParts.push(desc);
    if (ctx) detailParts.push(`Opportunity: ${ctx}`);
    pushEvent(allOptional, {
      occurredAt: toIsoDateTime(t.ActivityDate) || toIsoDateTime(t.CreatedDate),
      sourceSystem: "salesforce",
      sourceObjectType: "Task",
      sourceObjectId: t.Id,
      eventType: "taskCompleted",
      title: "Task completed",
      detail: detailParts.filter(Boolean).join(" - ") || undefined,
      importance: importanceFor("taskCompleted")
    });
  }

  const eventList = Array.isArray(events) ? events : [];
  for (const e of eventList) {
    const linkedOppId = findLinkedOppId(e.WhatId);
    const ctx = linkedOppId ? oppContextLabel(linkedOppId) : null;
    const detailParts = [];
    if (e.Subject) detailParts.push(String(e.Subject));
    const desc = normalizeTextSnippet(e.Description, 140);
    if (desc) detailParts.push(desc);
    if (ctx) detailParts.push(`Opportunity: ${ctx}`);
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
      detail: detailParts.filter(Boolean).join(" - ") || undefined,
      importance: importanceFor("meetingLogged")
    });
  }

  const emailList = Array.isArray(emailMessages) ? emailMessages : [];
  for (const em of emailList) {
    const linkedOppId =
      findLinkedOppId(em.RelatedToId) || findLinkedOppId(em.ParentId);
    const ctx = linkedOppId ? oppContextLabel(linkedOppId) : null;
    const snippet = normalizeTextSnippet(em.TextBody, 160);
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
          snippet ? `Snippet: ${snippet}` : null,
          em.Incoming === true
            ? "incoming"
            : em.Incoming === false
              ? "outgoing"
              : null,
          redactEmailAddress(em.FromAddress)
            ? `From: ${redactEmailAddress(em.FromAddress)}`
            : null,
          ctx ? `Opportunity: ${ctx}` : null
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

  // Sales consumers want the most recent activity first.
  const finalEvents = [...always, ...selectedOptional].sort(
    (a, b) => Date.parse(b.occurredAt) - Date.parse(a.occurredAt)
  );

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

function compactObject(obj) {
  if (!obj || typeof obj !== "object") return obj;
  if (Array.isArray(obj)) return obj.map(compactObject);
  const out = {};
  for (const [k, v] of Object.entries(obj)) {
    if (v === null || v === undefined) continue;
    if (typeof v === "string" && v.trim() === "") continue;
    out[k] = compactObject(v);
  }
  return out;
}

function simplifyHistoryEvents(events) {
  const list = Array.isArray(events) ? events : [];
  return list.map((e) => ({
    occurredAt: e?.occurredAt || null,
    eventType: e?.eventType || null,
    title: e?.title || null,
    detail: e?.detail ? String(e.detail).slice(0, 160) : null,
    importance: e?.importance || null
  }));
}

async function openaiChatCompletions({
  apiKey,
  model,
  messages,
  temperature,
  maxTokens,
  baseUrl,
  reasoningEffort
}) {
  const url = `${String(baseUrl || "https://api.openai.com/v1").replace(/\/+$/, "")}/chat/completions`;
  const payload = {
    model,
    messages
  };

  // Some newer model families (e.g. GPT-5) only support default sampling params.
  if (!/^gpt-5/i.test(String(model || "")) && typeof temperature === "number") {
    payload.temperature = temperature;
  }

  // Reasoning models can spend the entire completion budget on hidden reasoning
  // unless we constrain effort.
  if (/^gpt-5/i.test(String(model || "")) && reasoningEffort) {
    payload.reasoning_effort = reasoningEffort;
  }

  // Some newer model families (e.g. GPT-5) require `max_completion_tokens`
  // instead of `max_tokens`.
  if (Number.isFinite(maxTokens)) {
    if (/^gpt-5/i.test(String(model || "")))
      payload.max_completion_tokens = maxTokens;
    else payload.max_tokens = maxTokens;
  }

  const resp = await fetchWithTimeout(
    url,
    {
      method: "POST",
      headers: {
        authorization: `Bearer ${apiKey}`,
        "content-type": "application/json"
      },
      body: JSON.stringify(payload)
    },
    // Keep under API Gateway timeout budget.
    22000
  );
  const text = await resp.text();
  const json = safeJsonParse(text);
  if (!resp.ok) {
    throw new Error(`OpenAI error: ${resp.status}: ${text.slice(0, 2000)}`);
  }
  const content = json?.choices?.[0]?.message?.content || null;
  const usage = json?.usage || null;
  return { content, usage, raw: json };
}

exports.handler = async function handler(event) {
  const env = process.env.ENVIRONMENT || null;

  const bodyRaw = event?.body
    ? event.isBase64Encoded
      ? Buffer.from(event.body, "base64").toString("utf8")
      : event.body
    : "";
  const body = bodyRaw ? safeJsonParse(bodyRaw) : null;

  const mqlId = body?.mqlId || null;
  const contactId = body?.contactId || null;

  if (!mqlId) {
    return jsonResponse(400, {
      ok: false,
      error: "missing_mqlId",
      meta: { env, receivedAt: nowIso() }
    });
  }

  // Load secrets (may be unconfigured at first).
  const sfSecretArn = process.env.SALESFORCE_SECRET_ARN;
  const hsSecretArn = process.env.HUBSPOT_SECRET_ARN;
  const openaiSecretArn = process.env.OPENAI_SECRET_ARN;
  const sfSecret = await getSecretJson(sfSecretArn);
  const hsSecret = await getSecretJson(hsSecretArn);
  const openaiSecret = await getSecretJson(openaiSecretArn);

  let summaryHtml = null;
  const meta = {
    env,
    mqlId,
    contactId,
    requestId: event?.requestContext?.requestId || null,
    receivedAt: nowIso(),
    hasSalesforceSecret: Boolean(sfSecret),
    hasHubspotSecret: Boolean(hsSecret),
    hasOpenAiSecret: Boolean(openaiSecret)
  };

  // Try Salesforce fetch if configured.
  try {
    const sfAuth = await salesforceLogin(sfSecret);
    if (!sfAuth) {
      summaryHtml = buildBasicSummaryHtml({
        env,
        mqlId,
        contactId,
        message:
          "Salesforce secret not configured yet; returning placeholder summary."
      });
      return jsonResponse(200, { ok: true, summaryHtml, meta });
    }

    // Default to a conservative API version so production orgs on older versions still work.
    const apiVersion = sfSecret?.apiVersion || "65.0";
    meta.salesforce = {
      ok: false,
      apiVersion,
      instanceUrl: sfAuth.instanceUrl
    };

    // Optional connectivity ping (debug only). Saves time on normal requests.
    if (body?.debugLimitsPing === true) {
      const limits = await sfGetLimits({ ...sfAuth, apiVersion });
      meta.salesforce.limitsSample = limits
        ? {
            DailyApiRequests: limits.DailyApiRequests || null,
            DataStorageMB: limits.DataStorageMB || null
          }
        : null;
    }
    meta.salesforce.ok = true;

    // Keep activity queries bounded by default; the recipe itself enforces the
    // final event caps that go to the model.
    const sinceDays = Math.max(1, Math.min(365, Number(body?.sinceDays || 90)));
    const sinceExpr = `LAST_N_DAYS:${sinceDays}`;

    // Describe objects so we only query fields that exist in each org.
    // Cached across warm invocations to reduce round trips.
    async function describeCached(sobject) {
      return sfDescribeCached({ ...sfAuth, apiVersion, sobject });
    }

    const sfAllow = allowlist?.salesforce || {};
    const req = sfAllow?.requiredObjects || {};
    const opt = sfAllow?.optionalTimelineObjects || {};

    const desiredMqlFields = req["MQL__c"]?.fields || [
      "Id",
      "Contact__c",
      "MQL_Date__c",
      "Lead_Source__c"
    ];
    const desiredContactFields = req["Contact"]?.fields || [
      "Id",
      "Name",
      "Email",
      "AccountId"
    ];
    const desiredContactIdentityFields =
      req["Contact"]?.optionalIdentityFields || [];
    const desiredAccountFields = req["Account"]?.fields || ["Id", "Name"];
    const desiredOcrFields = req["OpportunityContactRole"]?.fields || [
      "Id",
      "ContactId",
      "OpportunityId",
      "CreatedDate"
    ];
    const desiredOppFields = req["Opportunity"]?.fields || [
      "Id",
      "Name",
      "StageName",
      "CreatedDate",
      "LastModifiedDate"
    ];

    let mql = null;
    let contact = null;
    let account = null;
    let ocr = [];
    let opportunities = [];
    let opportunityLineItems = [];
    let tasks = [];
    let events = [];
    let emailMessages = [];
    let campaignMembers = [];
    let contactUsSubmissions = [];
    let salesLeads = [];
    const history = {
      contactHistory: [],
      opportunityFieldHistory: [],
      mqlHistory: []
    };

    // 1) MQL
    try {
      const mqlDescribe = await describeCached("MQL__c");
      const mqlFields = pickExistingFields(mqlDescribe, desiredMqlFields);
      const mqlQ = `SELECT ${mqlFields.join(",")} FROM MQL__c WHERE Id = '${mqlId}' LIMIT 1`;
      const mqlRes = await sfQuery({ ...sfAuth, apiVersion, soql: mqlQ });
      mql = (mqlRes?.records && mqlRes.records[0]) || null;
    } catch (e) {
      // In production we may not have MQL__c deployed yet; keep returning 200 so
      // Salesforce callouts stay healthy during rollout.
      console.warn("sf_mql_query_failed", { message: e?.message });
      summaryHtml = buildBasicSummaryHtml({
        env,
        mqlId,
        contactId,
        message: `Salesforce connectivity OK, but could not query MQL__c yet: ${e?.message || "unknown error"}`
      });
      return jsonResponse(200, {
        ok: true,
        summaryHtml,
        meta: { ...meta, mqlQueryError: e?.message || "unknown" }
      });
    }

    // 2) Contact + Account
    const resolvedContactId = contactId || mql?.Contact__c || null;
    if (resolvedContactId) {
      const contactDescribe = await describeCached("Contact");
      const contactFields = pickExistingFields(contactDescribe, [
        ...desiredContactFields,
        ...desiredContactIdentityFields
      ]);
      const cQ = `SELECT ${contactFields.join(",")} FROM Contact WHERE Id = '${resolvedContactId}' LIMIT 1`;
      const cRes = await sfQuery({ ...sfAuth, apiVersion, soql: cQ });
      contact = (cRes?.records && cRes.records[0]) || null;
    }

    if (contact?.AccountId) {
      const accountDescribe = await describeCached("Account");
      const accountFields = pickExistingFields(
        accountDescribe,
        desiredAccountFields
      );
      const aQ = `SELECT ${accountFields.join(",")} FROM Account WHERE Id = '${contact.AccountId}' LIMIT 1`;
      const aRes = await sfQuery({ ...sfAuth, apiVersion, soql: aQ });
      account = (aRes?.records && aRes.records[0]) || null;
    }

    // 3) OpportunityContactRole + Opportunities (open opp detection)
    try {
      const ocrDescribe = await describeCached("OpportunityContactRole");
      const ocrFields = pickExistingFields(ocrDescribe, desiredOcrFields);
      const where =
        ocrFields.includes("Open_Opportunity__c") && contact?.Id
          ? `ContactId = '${contact.Id}' AND Open_Opportunity__c = true`
          : contact?.Id
            ? `ContactId = '${contact.Id}'`
            : null;
      if (where) {
        const ocrQ = `SELECT ${ocrFields.join(", ")} FROM OpportunityContactRole WHERE ${where} LIMIT 50`;
        ocr =
          (await trySfQueryRecords({ ...sfAuth, apiVersion, soql: ocrQ })) ||
          [];
      }
    } catch {
      // ignore
    }

    const oppIds = Array.from(
      new Set((ocr || []).map((r) => r.OpportunityId).filter(Boolean))
    );
    if (oppIds.length) {
      const oppDescribe = await describeCached("Opportunity");
      const oppFields = pickExistingFields(oppDescribe, desiredOppFields);
      const oppQ =
        `SELECT ${oppFields.join(", ")} FROM Opportunity WHERE Id IN ${safeInClause(oppIds)} ` +
        "ORDER BY LastModifiedDate DESC LIMIT 50";
      opportunities =
        (await trySfQueryRecords({ ...sfAuth, apiVersion, soql: oppQ })) || [];
    }

    // 3b) Opportunity products (best-effort). Prefer standard OpportunityLineItem.
    if (oppIds.length && opt?.OpportunityLineItem?.fields?.length) {
      const oliFields = opt.OpportunityLineItem.fields;
      const base =
        `SELECT ${oliFields.join(", ")} FROM OpportunityLineItem ` +
        `WHERE OpportunityId IN ${safeInClause(oppIds)} ` +
        "ORDER BY CreatedDate DESC LIMIT 200";
      const res = await trySfQueryRecords({
        ...sfAuth,
        apiVersion,
        soql: base
      });
      if (res === null && oliFields.some((f) => String(f).includes("."))) {
        const stripped = oliFields.filter((f) => !String(f).includes("."));
        const q2 =
          `SELECT ${stripped.join(", ")} FROM OpportunityLineItem ` +
          `WHERE OpportunityId IN ${safeInClause(oppIds)} ` +
          "ORDER BY CreatedDate DESC LIMIT 200";
        opportunityLineItems =
          (await trySfQueryRecords({ ...sfAuth, apiVersion, soql: q2 })) || [];
      } else {
        opportunityLineItems = res || [];
      }
    }

    // 4) Optional recency-bounded activity + timeline objects
    if (contact?.Id) {
      // Run independent timeline queries in parallel (big latency win).
      const promises = [];

      // Task
      promises.push(
        (async () => {
          if (!opt.Task?.fields?.length) return [];
          const taskFields = opt.Task.fields;
          const q =
            `SELECT ${taskFields.join(", ")} FROM Task WHERE WhoId = '${contact.Id}' AND CreatedDate = ${sinceExpr} ` +
            "ORDER BY ActivityDate DESC NULLS LAST, CreatedDate DESC LIMIT 100";
          return (
            (await trySfQueryRecords({ ...sfAuth, apiVersion, soql: q })) || []
          );
        })()
      );

      // Event
      promises.push(
        (async () => {
          if (!opt.Event?.fields?.length) return [];
          const eventFields = opt.Event.fields;
          const q =
            `SELECT ${eventFields.join(", ")} FROM Event WHERE WhoId = '${contact.Id}' AND CreatedDate = ${sinceExpr} ` +
            "ORDER BY StartDateTime DESC NULLS LAST, CreatedDate DESC LIMIT 100";
          return (
            (await trySfQueryRecords({ ...sfAuth, apiVersion, soql: q })) || []
          );
        })()
      );

      // EmailMessage (metadata-only)
      promises.push(
        (async () => {
          if (!opt.EmailMessage?.fields?.length) return [];
          const emailFields = opt.EmailMessage.fields;
          const whereParts = [
            `(RelatedToId = '${contact.Id}' OR ParentId = '${contact.Id}')`
          ];
          if (oppIds.length)
            whereParts.push(`RelatedToId IN ${safeInClause(oppIds)}`);
          const q =
            `SELECT ${emailFields.join(", ")} FROM EmailMessage ` +
            `WHERE (${whereParts.join(" OR ")}) AND CreatedDate = ${sinceExpr} ` +
            "ORDER BY MessageDate DESC NULLS LAST, CreatedDate DESC LIMIT 100";
          return (
            (await trySfQueryRecords({ ...sfAuth, apiVersion, soql: q })) || []
          );
        })()
      );

      // CampaignMember (longer lookback)
      promises.push(
        (async () => {
          if (!opt.CampaignMember?.fields?.length) return [];
          const cmFields = opt.CampaignMember.fields;
          const qBase =
            `SELECT ${cmFields.join(", ")} FROM CampaignMember WHERE ContactId = '${contact.Id}' AND CreatedDate = LAST_N_DAYS:365 ` +
            "ORDER BY CreatedDate DESC LIMIT 100";
          const cmRes = await trySfQueryRecords({
            ...sfAuth,
            apiVersion,
            soql: qBase
          });
          if (cmRes === null && cmFields.some((f) => String(f).includes("."))) {
            const stripped = cmFields.filter((f) => !String(f).includes("."));
            const q2 =
              `SELECT ${stripped.join(", ")} FROM CampaignMember WHERE ContactId = '${contact.Id}' AND CreatedDate = LAST_N_DAYS:365 ` +
              "ORDER BY CreatedDate DESC LIMIT 100";
            return (
              (await trySfQueryRecords({ ...sfAuth, apiVersion, soql: q2 })) ||
              []
            );
          }
          return cmRes || [];
        })()
      );

      // Contact Us submissions (query by email to catch pre-contact creation)
      promises.push(
        (async () => {
          if (!opt["Contact_Us__c"]?.fields?.length || !contact?.Email)
            return [];
          const cuFields = opt["Contact_Us__c"].fields;
          const emailEsc = String(contact.Email).replaceAll("'", "\\'");
          const q =
            `SELECT ${cuFields.join(", ")} FROM Contact_Us__c ` +
            `WHERE Email__c = '${emailEsc}' AND CreatedDate = LAST_N_DAYS:365 ` +
            "ORDER BY CreatedDate DESC LIMIT 50";
          return (
            (await trySfQueryRecords({ ...sfAuth, apiVersion, soql: q })) || []
          );
        })()
      );

      // Sales_Lead__c (Activity Alert) - stored web activity summaries from CMS.
      promises.push(
        (async () => {
          if (!opt["Sales_Lead__c"]?.fields?.length) return [];
          const slFields = opt["Sales_Lead__c"].fields;
          const q =
            `SELECT ${slFields.join(", ")} FROM Sales_Lead__c ` +
            `WHERE Contact__c = '${contact.Id}' AND CreatedDate = LAST_N_DAYS:365 ` +
            "ORDER BY Lead_Date__c DESC NULLS LAST, CreatedDate DESC LIMIT 10";
          return (
            (await trySfQueryRecords({ ...sfAuth, apiVersion, soql: q })) || []
          );
        })()
      );

      const [taskRes, eventRes, emailRes, campaignRes, contactUsRes, slRes] =
        await Promise.all(promises);
      tasks = taskRes;
      events = eventRes;
      emailMessages = emailRes;
      campaignMembers = campaignRes;
      contactUsSubmissions = contactUsRes;
      salesLeads = slRes;
    }

    // 5) Optional history tables (only if enabled in org)
    if (contact?.Id) {
      const fields = sfAllow?.historyTables?.ContactHistory?.fields || [];
      if (fields.length) {
        const q =
          `SELECT ContactId, ${fields.join(", ")} FROM ContactHistory WHERE ContactId = '${contact.Id}' AND CreatedDate = LAST_N_DAYS:180 ` +
          "ORDER BY CreatedDate DESC LIMIT 500";
        history.contactHistory =
          (await trySfQueryRecords({ ...sfAuth, apiVersion, soql: q })) || [];
      }
    }

    if (opportunities.length) {
      const fields =
        sfAllow?.historyTables?.OpportunityFieldHistory?.fields || [];
      const preferred =
        sfAllow?.historyTables?.OpportunityFieldHistory
          ?.preferredFieldFilters || [];
      if (fields.length) {
        const fieldFilter = preferred.length
          ? ` AND Field IN ${safeInClause(preferred)}`
          : "";
        const q =
          `SELECT OpportunityId, ${fields.join(", ")} FROM OpportunityFieldHistory ` +
          `WHERE OpportunityId IN ${safeInClause(opportunities.map((o) => o.Id))} AND CreatedDate = LAST_N_DAYS:180${fieldFilter} ` +
          "ORDER BY CreatedDate DESC LIMIT 500";
        history.opportunityFieldHistory =
          (await trySfQueryRecords({ ...sfAuth, apiVersion, soql: q })) || [];
      }
    }

    if (mql?.Id) {
      const fields = sfAllow?.historyTables?.["MQL__History"]?.fields || [];
      const preferred =
        sfAllow?.historyTables?.["MQL__History"]?.preferredFieldFilters || [];
      if (fields.length) {
        const fieldFilter = preferred.length
          ? ` AND Field IN ${safeInClause(preferred)}`
          : "";
        const q =
          `SELECT ParentId, ${fields.join(", ")} FROM MQL__History WHERE ParentId = '${mql.Id}' AND CreatedDate = LAST_N_DAYS:365${fieldFilter} ` +
          "ORDER BY CreatedDate DESC LIMIT 500";
        history.mqlHistory =
          (await trySfQueryRecords({ ...sfAuth, apiVersion, soql: q })) || [];
      }
    }

    const preview = buildHistoryEventsPreview({
      allowlist,
      contact,
      mql,
      opportunityContactRoles: ocr,
      opportunities,
      opportunityLineItems,
      tasks,
      events,
      emailMessages,
      campaignMembers,
      contactUsSubmissions,
      history,
      sinceDays
    });

    meta.timeline = preview?.metadata || null;

    // Product-interest enrichment (best-effort):
    // - Salesforce: Sales_Lead__c web activity summaries (if present)
    // - HubSpot: lightweight contact property snapshot (URLs, campaign/conversion props)
    let hubspotContactProps = null;
    if (hsSecret && contact?.Email) {
      const token = getHubspotToken(hsSecret);
      if (token) {
        const baseUrl = getHubspotBaseUrl(hsSecret);
        const timeoutMs = 2500;
        const hsContactId =
          contact?.Hubspot__c ||
          (contact?.HubSpot_Contact_Id__c
            ? String(contact.HubSpot_Contact_Id__c)
            : null);
        const resolvedId =
          hsContactId ||
          (await searchContactIdByEmail({
            token,
            baseUrl,
            email: contact.Email,
            timeoutMs
          }));
        if (resolvedId) {
          hubspotContactProps = await getContactProperties({
            token,
            baseUrl,
            hsContactId: resolvedId,
            timeoutMs,
            properties: [
              "hs_analytics_first_url",
              "hs_analytics_last_url",
              "hs_analytics_first_referrer",
              "hs_analytics_last_referrer",
              "hs_analytics_first_touch_converting_campaign",
              "hs_analytics_last_touch_converting_campaign",
              "hs_analytics_source",
              "hs_analytics_source_data_1",
              "hs_analytics_source_data_2",
              "utm_campaign",
              "utm_source",
              "utm_medium",
              "first_conversion_event_name",
              "recent_conversion_event_name"
            ]
          });
        }
      }
    }

    const evidence = [
      ...buildEvidenceFromSalesLeadWebActivity(salesLeads),
      ...buildEvidenceFromCampaignMembers(campaignMembers),
      ...buildEvidenceFromHubspotContactProps(hubspotContactProps)
    ];
    if (contact?.HubSpot_First_Conversion__c) {
      evidence.push({
        kind: "sf_conversion",
        category: "text",
        text: String(
          redactInlineText(contact.HubSpot_First_Conversion__c)
        ).slice(0, 280),
        occurredAt: contact?.HubSpot_First_Conversion_Date__c || null
      });
    }
    if (contact?.HubSpot_Recent_Conversion__c) {
      evidence.push({
        kind: "sf_conversion",
        category: "text",
        text: String(
          redactInlineText(contact.HubSpot_Recent_Conversion__c)
        ).slice(0, 280),
        occurredAt: contact?.HubSpot_Recent_Conversion_Date__c || null
      });
    }

    const productInterest = inferProductInterest({
      rulesConfig: productInterestRules,
      evidence
    });

    // Additional opportunity context for the model (Sales-friendly, bounded).
    const oppById = new Map((opportunities || []).map((o) => [o.Id, o]));
    const productsByOppId = new Map();
    for (const oli of opportunityLineItems || []) {
      const oppId = oli?.OpportunityId;
      const productName = oli?.PricebookEntry?.Product2?.Name || null;
      if (!oppId || !productName) continue;
      if (!productsByOppId.has(oppId)) productsByOppId.set(oppId, []);
      const list = productsByOppId.get(oppId);
      if (!list.includes(productName)) list.push(productName);
    }

    const opportunityContext = {
      openOpportunities: Array.from(oppById.values())
        .slice(0, 5)
        .map((o) => {
          const products = (productsByOppId.get(o.Id) || [])
            .map((x) => String(x).trim())
            .filter(Boolean)
            .slice(0, 4);
          const fallbackProducts = [
            o?.Opportunity_Product__c,
            o?.Primary_Product__c,
            o?.Product_Name__c,
            o?.Product__c
          ]
            .map((x) => (x ? String(x).trim() : null))
            .filter(Boolean)
            .slice(0, 2);
          const finalProducts = products.length ? products : fallbackProducts;
          return compactObject({
            name: o?.Name || null,
            stage: o?.StageName || null,
            products: finalProducts.length ? finalProducts : null
          });
        })
    };

    // If OpenAI is configured, prefer the LLM narrative, else fall back to a
    // deterministic HTML summary.
    const openaiApiKey =
      openaiSecret?.apiKey ||
      openaiSecret?.OPENAI_API_KEY ||
      openaiSecret?.key ||
      null;
    const openaiModel = openaiSecret?.model || "gpt-4o-mini";
    const openaiBaseUrl =
      openaiSecret?.baseUrl || openaiSecret?.OPENAI_BASE_URL || null;

    // Build a sales-first, business-language payload so the model does not echo
    // Salesforce/HubSpot field names back into the summary.
    const salesNarrativeInput = buildSalesNarrativeInput({
      mql,
      contact,
      account,
      opportunities,
      opportunityContactRoles: ocr,
      historyEvents: preview?.events || [],
      productInterest,
      opportunityContext
    });

    const deterministic = finalizeSalesSummaryHtml({
      html: buildDeterministicSalesSummaryHtml(salesNarrativeInput),
      instanceUrl: sfAuth.instanceUrl,
      mql,
      opportunities,
      opportunityContactRoles: ocr
    });

    if (openaiApiKey) {
      try {
        const { system, user } = buildOpenAiMessages({ salesNarrativeInput });

        const out = await openaiChatCompletions({
          apiKey: openaiApiKey,
          model: openaiModel,
          baseUrl: openaiBaseUrl,
          temperature: Number(openaiSecret?.temperature ?? 0.2),
          reasoningEffort:
            openaiSecret?.reasoningEffort ||
            openaiSecret?.reasoning_effort ||
            (/^gpt-5/i.test(String(openaiModel || "")) ? "minimal" : null),
          // GPT-5 family can burn a lot of "completion" tokens on reasoning; give
          // it enough budget to actually emit HTML, but keep latency bounded.
          maxTokens: (() => {
            const requested = Number(openaiSecret?.maxTokens ?? 1400);
            if (/^gpt-5/i.test(String(openaiModel || ""))) {
              const min = 800;
              const max = 1600;
              if (!Number.isFinite(requested)) return 1400;
              return Math.max(min, Math.min(requested, max));
            }
            return Number.isFinite(requested) ? requested : 900;
          })(),
          messages: [
            { role: "system", content: system },
            { role: "user", content: user }
          ]
        });

        const raw = String(out?.content || "").trim();
        // Strip common code-fence wrappers if the model ignores instructions.
        const cleaned = raw
          .replace(/^```[a-zA-Z]*\s*/, "")
          .replace(/\s*```$/, "")
          .trim();

        const cleanedFinal = cleaned
          ? finalizeSalesSummaryHtml({
              html: cleaned,
              instanceUrl: sfAuth.instanceUrl,
              mql,
              opportunities,
              opportunityContactRoles: ocr
            })
          : "";
        const validation = validateSalesFacingHtml(cleanedFinal);
        if (validation.ok) {
          summaryHtml = cleanedFinal;
          meta.llm = {
            ok: true,
            provider: "openai",
            model: openaiModel,
            usage: out?.usage || null
          };
          return jsonResponse(200, { ok: true, summaryHtml, meta });
        }

        const finishReason = out?.raw?.choices?.[0]?.finish_reason || null;
        meta.llm = {
          ok: false,
          provider: "openai",
          model: openaiModel,
          error: cleaned ? "invalid_html" : "empty_content",
          validation: validation?.reasons || null,
          finishReason,
          usage: out?.usage || null
        };
      } catch (e) {
        meta.llm = {
          ok: false,
          provider: "openai",
          model: openaiModel,
          error: e?.message || "unknown"
        };
      }

      // If OpenAI returns invalid output (field leakage / missing sections),
      // fall back to deterministic sales-first HTML rather than storing junk.
      summaryHtml = deterministic;
      return jsonResponse(200, { ok: true, summaryHtml, meta });
    }

    meta.llm = {
      ok: false,
      provider: "openai",
      model: openaiModel,
      error: "unconfigured"
    };
    summaryHtml = deterministic;
    return jsonResponse(200, { ok: true, summaryHtml, meta });
  } catch (err) {
    console.error("handler_error", { message: err?.message, name: err?.name });
    summaryHtml = buildBasicSummaryHtml({
      env,
      mqlId,
      contactId,
      message: `Error generating summary: ${err?.message || "unknown error"}`
    });
    // Return 200 so the pipeline is observable even if Salesforce creds fail.
    return jsonResponse(200, {
      ok: true,
      summaryHtml,
      meta: { ...meta, error: err?.message || "unknown" }
    });
  }
};

// Expose a small surface for unit tests (kept out of the summary output).
exports._internals = {
  buildHistoryEventsPreview,
  sanitizeHtmlForSalesforceField,
  validateSalesFacingHtml,
  buildDeterministicSalesSummaryHtml,
  buildRelatedRecordsHtml,
  enforceSalesSummarySectionCaps,
  finalizeSalesSummaryHtml,
  safeSfRecordUrl,
  buildOpenAiMessages,
  looksLikeFieldOrIdLeak
};
