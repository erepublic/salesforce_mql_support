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

const DEFAULT_SUMMARY_TIME_ZONE =
  process.env.MQL_SUMMARY_TIME_ZONE || "America/Los_Angeles";
const SUMMARY_ACTIVITY_WINDOW_DAYS = 60;
const dateFormatterCache = new Map();

function isSalesforceId(value) {
  const s = String(value || "").trim();
  return /^[A-Za-z0-9]{15}(?:[A-Za-z0-9]{3})?$/.test(s);
}

function yyyyMmDd(iso, timeZone = DEFAULT_SUMMARY_TIME_ZONE) {
  const raw = String(iso || "").trim();
  if (/^\d{4}-\d{2}-\d{2}$/.test(raw)) return raw;
  const t = Date.parse(iso);
  if (!Number.isFinite(t)) return null;
  let formatter = dateFormatterCache.get(timeZone);
  if (!formatter) {
    formatter = new Intl.DateTimeFormat("en-US", {
      timeZone,
      year: "numeric",
      month: "2-digit",
      day: "2-digit"
    });
    dateFormatterCache.set(timeZone, formatter);
  }
  const parts = formatter.formatToParts(new Date(t));
  const year = parts.find((part) => part.type === "year")?.value;
  const month = parts.find((part) => part.type === "month")?.value;
  const day = parts.find((part) => part.type === "day")?.value;
  return year && month && day ? `${year}-${month}-${day}` : null;
}

function redactInlineText(s) {
  // Keep this conservative; we should not emit new PII into Salesforce fields.
  if (!s) return null;
  let out = String(s);
  // Email addresses
  out = out.replace(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi, "*@redacted");
  // Phone-ish sequences (very rough)
  out = out.replace(/\+?\d[\d\s().-]{7,}\d/g, "[redacted]");
  // Salesforce-style record IDs should never be visible in seller-facing text.
  out = out.replace(/\b[A-Za-z0-9]{15}(?:[A-Za-z0-9]{3})?\b/g, (token) =>
    isSalesforceId(token) ? "[redacted]" : token
  );
  return out;
}

function isRecentIso(iso, days) {
  const t = Date.parse(iso);
  if (!Number.isFinite(t)) return false;
  const windowDays = Number.isFinite(Number(days)) ? Number(days) : 30;
  const cutoff = Date.now() - windowDays * 24 * 60 * 60 * 1000;
  return t >= cutoff;
}

function toNumberOrNull(v) {
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
}

const FREE_EMAIL_DOMAINS = new Set([
  "gmail.com",
  "yahoo.com",
  "hotmail.com",
  "outlook.com",
  "icloud.com",
  "aol.com",
  "protonmail.com",
  "me.com",
  "mac.com",
  "live.com"
]);

function cleanedText(value, maxLen) {
  const text = redactInlineText(value);
  if (!text) return null;
  const flat = String(text).replace(/\s+/g, " ").trim();
  if (!flat) return null;
  const max = Number.isFinite(Number(maxLen)) ? Number(maxLen) : 140;
  return flat.length > max ? `${flat.slice(0, max)}...` : flat;
}

function normalizeTier(value) {
  const raw = String(value || "")
    .trim()
    .toLowerCase();
  if (raw === "high") return "High";
  if (raw === "medium") return "Medium";
  if (raw === "low") return "Low";
  return null;
}

function isThresholdLeadSource(leadSource) {
  return (
    String(leadSource || "").trim() === "Fit and Behavior Threshold Reached"
  );
}

function isHandRaiserLeadSource(leadSource) {
  return String(leadSource || "").trim() === "Events Portal";
}

function deriveContactFitTierFromScore(score) {
  const n = toNumberOrNull(score);
  if (n === null) return null;
  if (n >= 4) return "High";
  if (n >= 1) return "Medium";
  return "Low";
}

function guideMeaning(kind, tier) {
  if (kind === "company") {
    if (tier === "High")
      return "High-fit companies are core targets in the scoring guide.";
    if (tier === "Medium")
      return "Medium-fit companies are potential targets, but may need more qualification.";
    if (tier === "Low")
      return "Low-fit companies are lower-priority or unclear targets in the scoring guide.";
  }
  if (kind === "contact") {
    if (tier === "High")
      return "High-fit contacts match the target buyer profile strongly in the scoring guide.";
    if (tier === "Medium")
      return "Medium-fit contacts show some buyer-profile alignment, but may need role verification.";
    if (tier === "Low")
      return "Low-fit contacts are weaker matches to the target buyer profile in the scoring guide.";
  }
  return null;
}

function extractEmailDomain(email) {
  const raw = String(email || "")
    .trim()
    .toLowerCase();
  const parts = raw.split("@");
  return parts.length === 2 ? parts[1] : null;
}

function pushUnique(list, value) {
  if (!value) return;
  if (!list.includes(value)) list.push(value);
}

function humanList(values) {
  const items = (values || []).filter(Boolean);
  if (!items.length) return null;
  if (items.length === 1) return items[0];
  if (items.length === 2) return `${items[0]} and ${items[1]}`;
  return `${items.slice(0, -1).join(", ")}, and ${items[items.length - 1]}`;
}

function describeRecentConversion(name) {
  const cleaned = cleanedText(name, 120);
  if (!cleaned) return null;
  const lower = cleaned.toLowerCase();
  if (/\b(webinar|event|conference|summit)\b/i.test(lower)) {
    return `They recently registered for ${cleaned}.`;
  }
  return `They recently converted on ${cleaned}.`;
}

function splitMultiValueText(value, { maxItems = 6, maxLen = 80 } = {}) {
  if (!value) return [];
  const rawItems = String(value)
    .split(/[;\n|]+/g)
    .map((item) => cleanedText(item, maxLen))
    .filter(Boolean);
  return Array.from(new Set(rawItems)).slice(0, maxItems);
}

function buildCustomerFootprint(account) {
  const productFamilies = [
    {
      name: "DEN",
      level: account?.DEN_Membership_Contract_Level__c,
      status: account?.DEN_Membership_Contract_Status__c
    },
    {
      name: "DGN",
      level: account?.DGN_Membership_Contract_Level__c,
      status: account?.DGN_Membership_Contract_Status__c
    },
    {
      name: "TW",
      level: account?.TW_Membership_Contract_Level__c,
      status: account?.TW_Membership_Contract_Status__c
    }
  ];

  return productFamilies
    .map((product) =>
      compactObject({
        product: product.name,
        level: cleanedText(product.level, 60),
        status: cleanedText(product.status, 60)
      })
    )
    .filter((product) => product.level || product.status);
}

function buildCompanyContext({ account, contact }) {
  const customerFootprint = buildCustomerFootprint(account);
  const competitors = splitMultiValueText(account?.Navigator_Competitor__c, {
    maxItems: 6,
    maxLen: 80
  });
  const interestTopics = splitMultiValueText(contact?.Topics_Interested_In__c, {
    maxItems: 6,
    maxLen: 60
  });

  return compactObject({
    companyName: cleanedText(
      account?.Name || contact?.Company_Name_Holder__c,
      120
    ),
    businessSummary: cleanedText(account?.Description, 240),
    industry: cleanedText(account?.Industry, 80),
    revenueBand: cleanedText(account?.Revenue_Category__c, 80),
    budgetRange: cleanedText(account?.Navigator_Budget_Range__c, 80),
    accountStage: cleanedText(account?.Navigator_Stage__c, 80),
    salesStatus: cleanedText(account?.Navigator_Sales_Status__c, 80),
    competitors: competitors.length ? competitors : null,
    competitorNotes: cleanedText(account?.Navigator_Competitor_Notes__c, 180),
    customerFootprint: customerFootprint.length ? customerFootprint : null,
    contactContext: {
      department: cleanedText(contact?.Department, 80),
      interestTopics: interestTopics.length ? interestTopics : null
    }
  });
}

function buildContactFitEvidence(contact) {
  const derivedTier =
    normalizeTier(contact?.Contact_Fit_Threshold__c) ||
    deriveContactFitTierFromScore(
      contact?.HubSpot_Private_Sector_Contact_Fit__c
    );

  const positives = [];
  const observations = [];
  const concerns = [];
  const missingInputs = [];
  const title = cleanedText(contact?.Title, 80);
  const status = cleanedText(contact?.Contact_Status__c, 80);
  const emailDomain = extractEmailDomain(contact?.Email);

  if (title) {
    const lowerTitle = title.toLowerCase();
    if (/\b(sled|event|events|conference|summit)\b/i.test(lowerTitle)) {
      pushUnique(
        positives,
        "Their title includes target-market or event-focused keywords used in the scoring guide."
      );
    }
    if (
      /\b(sales|account executive|account manager|business development|revenue)\b/i.test(
        lowerTitle
      )
    ) {
      pushUnique(
        positives,
        "Their title matches a sales-role criterion from the scoring guide."
      );
    }
    if (
      /\b(marketing|demand generation|communications|brand|content)\b/i.test(
        lowerTitle
      )
    ) {
      pushUnique(
        positives,
        "Their title matches a marketing-role criterion from the scoring guide."
      );
    }
    if (
      /\b(director|vp|vice president|head|chief|president|founder|owner)\b/i.test(
        lowerTitle
      )
    ) {
      pushUnique(
        positives,
        "Their title matches the director-or-higher seniority criterion from the scoring guide."
      );
    }
  } else {
    pushUnique(
      missingInputs,
      "Contact title is not available, so role and seniority evidence is incomplete."
    );
  }

  if (contact?.Title_Filter_Universal_Bad_Title_1__c === true) {
    pushUnique(
      concerns,
      "Their title appears to fall outside target buyer profiles."
    );
  }

  if (status && status.toLowerCase().includes("inactive")) {
    pushUnique(
      concerns,
      "Contact status is inactive, which is a disqualifier in the scoring guide."
    );
  }

  if (emailDomain) {
    if (FREE_EMAIL_DOMAINS.has(emailDomain)) {
      pushUnique(
        concerns,
        "The email domain appears to be personal/free, which is a strong negative fit signal in the scoring guide."
      );
    } else if (/\.(gov|mil|edu)$/i.test(emailDomain)) {
      pushUnique(
        concerns,
        "The email domain appears to be public-sector or education, which the scoring guide excludes from private-sector fit."
      );
    } else {
      pushUnique(
        observations,
        `Email domain suggests a company domain (${emailDomain}).`
      );
    }
  } else {
    pushUnique(
      missingInputs,
      "Contact email domain is unavailable, so domain-based fit checks are incomplete."
    );
  }

  if (contact?.Foreign_Domain__c === true) {
    pushUnique(
      concerns,
      "The contact is flagged with a foreign or non-target email domain."
    );
  }

  return compactObject({
    guideMeaning: guideMeaning("contact", derivedTier),
    positives,
    observations,
    concerns,
    missingInputs
  });
}

function buildCompanyFitEvidence(account) {
  const derivedTier = normalizeTier(account?.Company_Fit_Threshold__c);

  const positives = [];
  const observations = [];
  const concerns = [];
  const missingInputs = [];
  const industry = cleanedText(account?.Industry, 80);
  const competitor = cleanedText(account?.Navigator_Competitor__c, 80);
  const customerFootprint = buildCustomerFootprint(account);

  if (industry) {
    pushUnique(observations, `Account industry is recorded as ${industry}.`);
    pushUnique(
      positives,
      "Industry is one of the explicit company-fit criteria in the scoring guide."
    );
  } else {
    pushUnique(
      missingInputs,
      "Account industry is not available, so industry-based company-fit evidence is incomplete."
    );
  }

  if (customerFootprint.length) {
    pushUnique(
      positives,
      "Existing customer or contract history is present on the account, which matches the previous-customer criterion from the scoring guide."
    );
  } else {
    pushUnique(
      missingInputs,
      "No current-customer or contract-history evidence is exposed here, so previous-customer fit attribution is partial."
    );
  }

  if (competitor) {
    pushUnique(
      concerns,
      `A competitor overlap is noted on the account (${competitor}), which is a strong negative in the scoring guide.`
    );
  } else {
    pushUnique(
      missingInputs,
      "No direct state-contract detail is exposed here, so company-fit attribution is still partial."
    );
  }

  if (account?.Placeholder_Account__c === true) {
    pushUnique(
      concerns,
      "The account is marked as a placeholder, so company-fit inputs may be incomplete."
    );
  }

  return compactObject({
    guideMeaning: guideMeaning("company", derivedTier),
    positives,
    observations,
    concerns,
    missingInputs
  });
}

function collectMqlExplanationDetails(mql) {
  const values = [
    mql?.Lead_Source_Detail__c,
    mql?.Lead_Detail_1__c,
    mql?.Lead_Detail_2__c,
    mql?.Lead_Detail_3__c,
    mql?.Lead_Detail_4__c,
    mql?.Lead_Notes__c
  ];
  const details = [];
  for (const value of values) {
    const cleaned = cleanedText(value, 160);
    if (cleaned) pushUnique(details, cleaned);
    if (details.length >= 4) break;
  }
  return details;
}

function buildThresholdExplanation({
  behaviorScore,
  companyFitTier,
  contactFitTier,
  hasInboundRequest,
  recentConversionName,
  fitEvidence,
  mqlDetails
}) {
  const behavior = toNumberOrNull(behaviorScore);
  let matchedRule = null;

  if (
    behavior !== null &&
    behavior >= 30 &&
    ((contactFitTier === "Medium" && companyFitTier === "Medium") ||
      (contactFitTier === "High" &&
        (companyFitTier === "Medium" || companyFitTier === "Low")))
  ) {
    matchedRule =
      companyFitTier === "Medium" && contactFitTier === "Medium"
        ? "Behavior threshold with Medium company fit and Medium contact fit"
        : `Behavior threshold with ${companyFitTier} company fit and High contact fit`;
  } else if (
    behavior !== null &&
    behavior >= 20 &&
    companyFitTier === "High" &&
    (contactFitTier === "High" || contactFitTier === "Medium")
  ) {
    matchedRule = `Behavior threshold with High company fit and ${contactFitTier} contact fit`;
  }

  let summary = null;
  if (matchedRule && behavior !== null) {
    summary = `This record likely qualified through the fit-and-behavior rule because recent activity was strong enough for a ${String(
      companyFitTier || "unknown"
    ).toLowerCase()} company-fit account and a ${String(
      contactFitTier || "unknown"
    ).toLowerCase()} contact-fit profile.`;
  } else if (behavior !== null && (companyFitTier || contactFitTier)) {
    summary = `Recent activity is being evaluated alongside ${String(
      companyFitTier || "unknown"
    ).toLowerCase()} company fit and ${String(
      contactFitTier || "unknown"
    ).toLowerCase()} contact fit, but the exact threshold combination is only partially visible from the available fields.`;
  }

  const supportingReasons = [];
  const contactReasons = [
    ...(fitEvidence?.contact?.positives || []),
    ...(fitEvidence?.contact?.concerns || [])
  ].slice(0, 2);
  const companyReasons = [
    ...(fitEvidence?.company?.positives || []),
    ...(fitEvidence?.company?.concerns || [])
  ].slice(0, 2);

  if (contactReasons.length) {
    supportingReasons.push(
      `Contact-fit evidence points to ${humanList(contactReasons).toLowerCase()}`
    );
  }
  if (companyReasons.length) {
    supportingReasons.push(
      `Company-fit evidence points to ${humanList(companyReasons).toLowerCase()}`
    );
  }
  if (hasInboundRequest) {
    supportingReasons.push(
      "There is also inbound intent, which increases urgency even though the threshold path is behavior-led."
    );
  }
  if (recentConversionName) {
    supportingReasons.push(
      "A recent conversion provides additional evidence of active evaluation."
    );
  }
  if (Array.isArray(mqlDetails) && mqlDetails.length) {
    supportingReasons.push(
      `Additional qualification context mentions: ${humanList(mqlDetails.slice(0, 2))}.`
    );
  }

  return compactObject({
    qualificationType: "Fit and behavior threshold",
    matchedRule,
    summary,
    companyFitTier,
    contactFitTier,
    supportingReasons,
    evidenceLevel: matchedRule
      ? "direct threshold match"
      : "partial threshold match"
  });
}

function qualitativeFromThreshold({ score, threshold }) {
  const s = toNumberOrNull(score);
  const t = toNumberOrNull(threshold);
  if (s === null || t === null || t <= 0) return null;
  if (s >= t) return "Strong";
  if (s >= t * 0.75) return "Moderate";
  return "Light";
}

function buildSalesEventLabel(e) {
  const eventType = String(e?.eventType || "");
  const title = String(e?.title || "").trim();
  const detail = String(e?.detail || "").trim();

  const typeMap = {
    contactUsSubmitted: "Inbound request (Contact Us)",
    mqlCreated: "Marketing qualified lead created",
    mqlConverted: "Converted to opportunity",
    mqlRejected: "Marked not a fit / not ready",
    openOpportunityDetected: "Already associated with an open opportunity",
    opportunityStageChanged: "Opportunity moved stages",
    meetingLogged: "Meeting logged",
    taskCompleted: "Sales activity completed",
    emailEngagement: "Email activity",
    campaignTouch: "Marketing touch"
  };

  const base = typeMap[eventType] || title || "Engagement activity";
  if (!detail) return base;
  return `${base} - ${redactInlineText(detail)}`;
}

function titleizeSlug(slug) {
  const cleaned = String(slug || "")
    .replace(/\.[a-z0-9]{1,6}$/i, "")
    .replace(/[_-]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
  if (!cleaned) return null;
  return cleaned.replace(/\b\w+/g, (word) => {
    if (/^\d+$/.test(word)) return word;
    return word.charAt(0).toUpperCase() + word.slice(1).toLowerCase();
  });
}

function preferredResolvedLabel(...values) {
  for (const value of values) {
    const cleaned = cleanedText(value, 120);
    if (cleaned && cleaned !== "[redacted]") return cleaned;
  }
  return null;
}

function labelFromPath(pathValue) {
  let raw = String(pathValue || "").trim();
  if (!raw) return null;
  try {
    raw = new URL(raw).pathname || raw;
  } catch {
    raw = raw.split(/[?#]/)[0];
  }
  if (!raw) return null;
  const originalSegments = raw
    .split("/")
    .map((segment) => segment.trim())
    .filter(Boolean);
  const lowerOriginalSegments = originalSegments.map((segment) =>
    segment.toLowerCase()
  );
  if (
    lowerOriginalSegments.some((segment) =>
      [
        "login",
        "auth",
        "authenticate",
        "authentication",
        "member",
        "members"
      ].includes(segment)
    )
  ) {
    return null;
  }
  if (lowerOriginalSegments.includes("rfp")) return "RFP Opportunity";
  if (
    lowerOriginalSegments.includes("dev_opp") ||
    lowerOriginalSegments.includes("devopp")
  ) {
    return "Development Opportunity";
  }
  if (
    lowerOriginalSegments.includes("prerfp") ||
    lowerOriginalSegments.includes("pre_rfp")
  ) {
    return "Pre-RFP Opportunity";
  }

  const segments = originalSegments.filter(
    (segment) => !/^\d+$/.test(segment) && !isSalesforceId(segment)
  );
  const ignored = new Set([
    "content",
    "article",
    "articles",
    "topic",
    "topics",
    "page",
    "pages",
    "post",
    "posts",
    "tag",
    "tags",
    "category",
    "categories",
    "resource",
    "resources",
    "rfp",
    "opportunity",
    "opportunities",
    "login",
    "auth",
    "authenticate",
    "authentication",
    "member",
    "members"
  ]);
  for (let i = segments.length - 1; i >= 0; i--) {
    const segment = segments[i];
    if (!segment || ignored.has(segment.toLowerCase())) continue;
    const label = titleizeSlug(segment);
    if (label) return label;
  }
  return null;
}

function humanizeAnalyticsAction(actionName) {
  const raw = cleanedText(actionName, 120);
  if (!raw) return null;
  const lower = raw.toLowerCase();

  const savedSearchMappings = [
    {
      pattern: /^emailed\.opportunities\.marketalert\.daily\.savedsearch$/,
      label: "Received a saved-search email for market alerts."
    },
    {
      pattern: /^emailed\.opportunities\.rfp\.daily\.savedsearch$/,
      label: "Received a saved-search email for RFP opportunities."
    },
    {
      pattern: /^emailed\.opportunities\.devopp\.daily\.savedsearch$/,
      label: "Received a saved-search email for development opportunities."
    }
  ];
  for (const item of savedSearchMappings) {
    if (item.pattern.test(lower)) return null;
  }

  if (lower.includes("savedsearch")) {
    return null;
  }

  const normalized = raw
    .replace(/\./g, " ")
    .replace(/_/g, " ")
    .replace(/\s+/g, " ")
    .trim();
  const titleized = titleizeSlug(normalized);
  return titleized ? `Interacted with "${titleized}".` : null;
}

function buildAnalyticsActionHighlight(action) {
  const lowerAction = String(action?.action || "")
    .trim()
    .toLowerCase();
  const resolvedValueLabel = preferredResolvedLabel(action?.resolvedValueLabel);
  const resolvedPathLabel = preferredResolvedLabel(
    action?.resolvedPathLabel,
    action?.resolvedLabel
  );
  const valueLabel = cleanedText(action?.value, 120);
  const safeValue =
    valueLabel && !/^\d+$/.test(valueLabel)
      ? redactInlineText(valueLabel)
      : null;
  const usableValue =
    safeValue && !/^\[redacted\](?:\s+\[redacted\])*$/i.test(safeValue)
      ? safeValue
      : null;
  const pathLabel =
    resolvedPathLabel || labelFromPath(action?.path || action?.url);

  if (lowerAction.includes("savedsearch")) return null;
  if (
    (resolvedValueLabel || usableValue) &&
    /(email|mail)/.test(lowerAction) &&
    /click/.test(lowerAction)
  ) {
    return `Clicked "${resolvedValueLabel || usableValue}" email.`;
  }
  if (
    (resolvedValueLabel || usableValue) &&
    /(email|mail)/.test(lowerAction) &&
    /open/.test(lowerAction)
  ) {
    return `Opened "${resolvedValueLabel || usableValue}" email.`;
  }
  if (
    (resolvedValueLabel || usableValue) &&
    /(register|registration)/.test(lowerAction)
  ) {
    return `Registered for "${resolvedValueLabel || usableValue}".`;
  }
  if (pathLabel) return `Visited the "${pathLabel}" page.`;
  if (resolvedValueLabel || usableValue) {
    return `Interacted with "${resolvedValueLabel || usableValue}".`;
  }
  return humanizeAnalyticsAction(action?.action);
}

function engagementSpecificityScore(item) {
  const highlight = String(item?.highlight || "").toLowerCase();
  let score = 0;
  if (/^visited the "|^clicked "|^opened "|^registered for /.test(highlight)) {
    score += 3;
  }
  if (highlight.includes('"')) score += 1;
  if (
    /marketing qualified lead created|website activity recorded/.test(highlight)
  ) {
    score -= 1;
  }
  return score;
}

function collectEngagementThemes({
  recentEngagement,
  analyticsBehavior,
  recentConversionName,
  supplementalEngagementEvidence
}) {
  const textPool = [];
  for (const item of Array.isArray(recentEngagement) ? recentEngagement : []) {
    if (item?.highlight) textPool.push(String(item.highlight));
  }
  if (recentConversionName) textPool.push(String(recentConversionName));
  for (const item of Array.isArray(supplementalEngagementEvidence)
    ? supplementalEngagementEvidence
    : []) {
    if (item?.resolvedLabel) textPool.push(String(item.resolvedLabel));
    if (item?.text) textPool.push(String(item.text));
  }
  for (const pv of Array.isArray(
    analyticsBehavior?.webActivity?.recentPageviews
  )
    ? analyticsBehavior.webActivity.recentPageviews
    : []) {
    if (pv?.resolvedLabel) textPool.push(String(pv.resolvedLabel));
    if (pv?.path) textPool.push(String(pv.path));
  }
  for (const action of Array.isArray(
    analyticsBehavior?.webActivity?.recentActions
  )
    ? analyticsBehavior.webActivity.recentActions
    : []) {
    if (action?.resolvedPathLabel)
      textPool.push(String(action.resolvedPathLabel));
    if (action?.resolvedValueLabel)
      textPool.push(String(action.resolvedValueLabel));
    if (action?.path) textPool.push(String(action.path));
    if (action?.action) textPool.push(String(action.action));
    if (action?.value) textPool.push(String(action.value));
  }

  const themes = [];
  const definitions = [
    {
      label: "procurement and RFP research",
      patterns: [
        /\brfp\b/i,
        /\bprocurement\b/i,
        /development opportunit/i,
        /market alert/i
      ]
    },
    {
      label: "city-manager and council leadership programs",
      patterns: [/city manager/i, /innovation council/i, /\bcouncil\b/i]
    },
    {
      label: "cybersecurity events and council programming",
      patterns: [/cybersecurity/i, /cyber leaders/i, /cyberwar/i]
    }
  ];

  for (const def of definitions) {
    if (
      textPool.some((text) =>
        def.patterns.some((pattern) => pattern.test(text))
      )
    ) {
      themes.push(def.label);
    }
  }
  return themes.slice(0, 3);
}

function highlightFromSupplementalEvidence(item) {
  const explicitLabel = preferredResolvedLabel(item?.resolvedLabel);
  if (explicitLabel) return `Visited the "${explicitLabel}" page.`;
  const raw = String(item?.text || "").trim();
  if (!raw) return null;
  let pathname = null;
  try {
    pathname = new URL(raw).pathname || null;
  } catch {
    pathname = raw;
  }
  const label = labelFromPath(pathname);
  if (!label) return null;
  return `Visited the "${label}" page.`;
}

function buildSupplementalRecentEngagement({ supplementalEngagementEvidence }) {
  const items = [];
  const seen = new Set();
  for (const item of Array.isArray(supplementalEngagementEvidence)
    ? supplementalEngagementEvidence
    : []) {
    if (!isRecentIso(item?.occurredAt, SUMMARY_ACTIVITY_WINDOW_DAYS)) continue;
    const highlight = highlightFromSupplementalEvidence(item);
    const date = yyyyMmDd(item?.occurredAt);
    if (!date || !highlight) continue;
    const key = `${date}|${highlight}`;
    if (seen.has(key)) continue;
    seen.add(key);
    items.push({
      date,
      highlight,
      importance: "medium"
    });
  }
  return items;
}

function buildHubspotRecentEngagement({ hubspotPageHistory }) {
  const items = [];
  const seen = new Set();
  for (const item of Array.isArray(hubspotPageHistory)
    ? hubspotPageHistory
    : []) {
    if (!isRecentIso(item?.occurredAt, SUMMARY_ACTIVITY_WINDOW_DAYS)) continue;
    const label =
      preferredResolvedLabel(item?.resolvedLabel) || labelFromPath(item?.path);
    const date = yyyyMmDd(item?.occurredAt);
    if (!date || !label) continue;
    const key = `${date}|${label}`;
    if (seen.has(key)) continue;
    seen.add(key);
    items.push({
      date,
      highlight: `Visited the "${label}" page.`,
      importance: "high",
      source: "hubspot"
    });
    if (items.length >= 6) break;
  }
  return items;
}

function normalizeHubspotEmailSegment(segment) {
  const raw = cleanedText(segment, 120);
  if (!raw) return null;
  const replaced = raw
    .replace(/\bGT\b/gi, "GovTech")
    .replace(/\bAI\b/gi, "Artificial Intelligence")
    .replace(/\bCDE\b/gi, "Center for Digital Education")
    .replace(/\bCDG\b/gi, "Center for Digital Government");
  const words = replaced
    .split(/\s+/)
    .map((word) => {
      if (/^(GovTech|AI)$/i.test(word)) return word;
      if (/^Artificial$/i.test(word)) return "Artificial";
      if (/^Intelligence$/i.test(word)) return "Intelligence";
      return word.charAt(0).toUpperCase() + word.slice(1).toLowerCase();
    })
    .join(" ");
  return cleanedText(words, 120);
}

function labelFromHubspotEmailName(name) {
  const raw = cleanedText(name, 160);
  if (!raw) return null;
  const segments = raw
    .split("|")
    .map((part) => cleanedText(part, 120))
    .filter(Boolean);
  if (!segments.length) return raw;
  const generic = new Set(["marketing", "news", "newsletter", "html", "text"]);
  const preferredSegments = segments
    .filter(
      (segment) =>
        !generic.has(segment.toLowerCase()) &&
        !/^\d{4}\.\d{2}\.\d{2}$/i.test(segment) &&
        !/^\d{1,2}:\d{2}(am|pm)?$/i.test(segment) &&
        !/^gt\d+\b/i.test(segment) &&
        !/\bhouse ad\b/i.test(segment)
    )
    .map((segment) => normalizeHubspotEmailSegment(segment))
    .filter(Boolean);
  const uniqueSegments = Array.from(new Set(preferredSegments));
  if (!uniqueSegments.length) return null;
  if (uniqueSegments.length === 1) return uniqueSegments[0];
  return `${uniqueSegments[0]} ${uniqueSegments[1]}`.trim();
}

function highlightForEmailClick({ subject, emailName }) {
  const cleanSubject = cleanedText(subject, 140);
  if (cleanSubject) {
    return `Clicked the "${cleanSubject}" marketing email.`;
  }
  const emailLabel = labelFromHubspotEmailName(emailName);
  if (emailLabel) {
    return `Clicked a ${emailLabel.toLowerCase()} marketing email.`;
  }
  return "Clicked a HubSpot marketing email.";
}

function buildHubspotEmailRecentEngagement({ hubspotEmailEngagement }) {
  const recentClicks = Array.isArray(hubspotEmailEngagement?.recentClicks)
    ? hubspotEmailEngagement.recentClicks
    : [];
  if (recentClicks.length) {
    const items = [];
    const seen = new Set();
    for (const click of recentClicks) {
      if (!isRecentIso(click?.occurredAt, SUMMARY_ACTIVITY_WINDOW_DAYS))
        continue;
      const date = yyyyMmDd(click?.occurredAt);
      if (!date) continue;
      const highlight = highlightForEmailClick({
        subject: click?.subject,
        emailName: click?.emailName
      });
      const key = `${date}|${highlight}`;
      if (seen.has(key)) continue;
      seen.add(key);
      items.push({
        date,
        highlight,
        importance: "high",
        source: "hubspot"
      });
      if (items.length >= 6) break;
    }
    if (items.length) return items;
  }

  const lastClickAt = hubspotEmailEngagement?.lastClickAt || null;
  if (!isRecentIso(lastClickAt, SUMMARY_ACTIVITY_WINDOW_DAYS)) return [];
  const date = yyyyMmDd(lastClickAt);
  if (!date) return [];
  return [
    {
      date,
      highlight: highlightForEmailClick({
        subject: null,
        emailName: hubspotEmailEngagement?.lastEmailName
      }),
      importance: "high",
      source: "hubspot"
    }
  ];
}

function buildAnalyticsRecentEngagement({
  analyticsBehavior,
  recentConversionName,
  recentConversionDate,
  recentConversionSummaryOverride,
  suppressWebActivityHighlights
}) {
  const items = [];
  const seen = new Set();

  function pushItem(date, highlight, importance) {
    const yyyyMmDdDate = yyyyMmDd(date);
    const cleanHighlight = cleanedText(highlight, 180);
    if (!yyyyMmDdDate || !cleanHighlight) return;
    const key = `${yyyyMmDdDate}|${cleanHighlight}`;
    if (seen.has(key)) return;
    seen.add(key);
    items.push({
      date: yyyyMmDdDate,
      highlight: cleanHighlight,
      importance: importance || "medium",
      source: "analytics"
    });
  }

  if (
    recentConversionName &&
    recentConversionDate &&
    isRecentIso(recentConversionDate, SUMMARY_ACTIVITY_WINDOW_DAYS)
  ) {
    const conversionSummary =
      recentConversionSummaryOverride ||
      describeRecentConversion(recentConversionName) ||
      `Recent conversion - ${redactInlineText(recentConversionName)}.`;
    pushItem(recentConversionDate, conversionSummary, "medium");
  }

  const pageviews = Array.isArray(
    analyticsBehavior?.webActivity?.recentPageviews
  )
    ? analyticsBehavior.webActivity.recentPageviews
    : [];
  const actions = Array.isArray(analyticsBehavior?.webActivity?.recentActions)
    ? analyticsBehavior.webActivity.recentActions
    : [];
  if (!suppressWebActivityHighlights) {
    for (const pv of pageviews
      .filter((item) =>
        isRecentIso(item?.occurredAt, SUMMARY_ACTIVITY_WINDOW_DAYS)
      )
      .slice(0, 4)) {
      const label =
        preferredResolvedLabel(pv?.resolvedLabel) || labelFromPath(pv?.path);
      if (!label) continue;
      pushItem(
        pv?.occurredAt,
        `Visited the "${label}" page.`,
        analyticsBehavior?.webActivity?.recentSignals ? "medium" : "low"
      );
    }

    for (const action of actions
      .filter((item) =>
        isRecentIso(item?.occurredAt, SUMMARY_ACTIVITY_WINDOW_DAYS)
      )
      .slice(0, 3)) {
      const actionHighlight = buildAnalyticsActionHighlight(action);
      if (!actionHighlight) continue;
      pushItem(
        action?.occurredAt,
        actionHighlight,
        analyticsBehavior?.webActivity?.recentSignals ? "medium" : "low"
      );
    }
  }

  return items;
}

function buildCompanyRecentOpportunityContext({
  companyOpportunities,
  opportunityContext
}) {
  const contextualRecent = Array.isArray(
    opportunityContext?.companyRecentOpportunities
  )
    ? opportunityContext.companyRecentOpportunities
    : [];
  const fallbackRecent = Array.isArray(companyOpportunities)
    ? companyOpportunities.map((o) =>
        compactObject({
          name: o?.Name || null,
          stage: o?.StageName || null,
          status:
            o?.IsClosed === true
              ? o?.IsWon === true
                ? "Closed won"
                : "Closed lost"
              : "Open",
          closeDate: o?.CloseDate || null
        })
      )
    : [];
  const recent = contextualRecent.length ? contextualRecent : fallbackRecent;
  const normalizedDeals = recent
    .map((opp) => {
      const products = Array.isArray(opp?.products)
        ? opp.products
            .map((item) => cleanedText(item, 60))
            .filter(Boolean)
            .slice(0, 4)
        : [];
      return compactObject({
        name: cleanedText(opp?.name, 120),
        stage: cleanedText(opp?.stage, 80),
        status: cleanedText(opp?.status, 40),
        closeDate: yyyyMmDd(opp?.closeDate) || null,
        amountBand: cleanedText(opp?.amountBand, 40),
        products: products.length ? products : null
      });
    })
    .filter(
      (opp) =>
        opp?.name ||
        opp?.stage ||
        opp?.status ||
        opp?.closeDate ||
        opp?.amountBand ||
        (Array.isArray(opp?.products) && opp.products.length)
    );
  const stageNames = Array.from(
    new Set(normalizedDeals.map((opp) => opp?.stage).filter(Boolean))
  ).slice(0, 5);
  const recentProducts = Array.from(
    new Set(
      normalizedDeals.flatMap((opp) =>
        Array.isArray(opp?.products) ? opp.products : []
      )
    )
  ).slice(0, 6);
  const openOpportunityCount = normalizedDeals.filter(
    (opp) => opp?.status === "Open"
  ).length;

  return compactObject({
    hasRecentOpportunities: normalizedDeals.length > 0,
    recentOpportunityCount: normalizedDeals.length || null,
    openOpportunityCount: openOpportunityCount || null,
    recentStageNames: stageNames.length ? stageNames : null,
    recentProducts: recentProducts.length ? recentProducts : null,
    recentDeals: normalizedDeals.slice(0, 3)
  });
}

function buildSalesNarrativeInput({
  mql,
  contact,
  account,
  opportunities,
  companyOpportunities,
  opportunityContactRoles,
  historyEvents,
  productInterest,
  opportunityContext,
  analyticsBehavior,
  hubspotPageHistory,
  hubspotEmailEngagement,
  websiteActivity,
  supplementalEngagementEvidence,
  recentConversionSummaryOverride
}) {
  const events = Array.isArray(historyEvents) ? historyEvents : [];
  const newestFirst = [...events].sort(
    (a, b) => Date.parse(b.occurredAt) - Date.parse(a.occurredAt)
  );

  const fitGateContact = contact?.Private_Sector_Non_Qual__c;
  const fitGateAccount = account?.Private_Sector_Non_Qual__c;

  const fitConcerns = [];
  if (fitGateContact === true)
    fitConcerns.push(
      "Contact is flagged as not eligible for private-sector outreach."
    );
  if (fitGateAccount === true)
    fitConcerns.push(
      "Account is flagged as not eligible for private-sector outreach."
    );
  if (fitGateContact === null || fitGateContact === undefined)
    fitConcerns.push("Contact eligibility checks are missing or unclear.");
  if (fitGateAccount === null || fitGateAccount === undefined)
    fitConcerns.push("Account eligibility checks are missing or unclear.");
  if (account?.Placeholder_Account__c === true) {
    fitConcerns.push(
      "Company details may be incomplete (new or placeholder account)."
    );
  }

  const fitLooksGood = fitGateContact === false && fitGateAccount === false;
  const isThresholdMql = isThresholdLeadSource(mql?.Lead_Source__c);
  const isHandRaiserMql = isHandRaiserLeadSource(mql?.Lead_Source__c);

  const contactFitScore = contact?.HubSpot_Private_Sector_Contact_Fit__c;
  const contactFitThreshold = contact?.Contact_Fit_Threshold__c;
  const contactFitTierFromThreshold = normalizeTier(contactFitThreshold);
  const contactFitTierFromScore =
    deriveContactFitTierFromScore(contactFitScore);
  const contactFitTier = contactFitTierFromThreshold || contactFitTierFromScore;
  const companyFitTier = normalizeTier(account?.Company_Fit_Threshold__c);
  const contactFitThresholdMet =
    Number.isFinite(Number(contactFitScore)) &&
    Number.isFinite(Number(contactFitThreshold)) &&
    Number(contactFitScore) >= Number(contactFitThreshold);
  const contactFitIsTargetTier =
    contactFitTier === "High" || contactFitTier === "Medium";
  const contactFitQualifies = contactFitThresholdMet || contactFitIsTargetTier;

  const behaviorScore = contact?.HubSpot_Private_Sector_Behavior_Score__c;
  const lastEngagementDate = contact?.HubSpot_Last_Engagement_Date__c || null;
  const recentConversionName = contact?.HubSpot_Recent_Conversion__c || null;
  const recentConversionDate =
    contact?.HubSpot_Recent_Conversion_Date__c || null;
  const recentConversionSummary =
    recentConversionSummaryOverride ||
    describeRecentConversion(recentConversionName);
  const hasInboundRequest =
    newestFirst.some((e) => e?.eventType === "contactUsSubmitted") ||
    String(mql?.Lead_Source__c || "")
      .toLowerCase()
      .includes("contact us") ||
    String(mql?.Lead_Source__c || "")
      .toLowerCase()
      .includes("contact");

  const now = Date.now();
  const days14 = now - 14 * 24 * 60 * 60 * 1000;
  const days30 = now - 30 * 24 * 60 * 60 * 1000;
  const recentHighMedCount14 = newestFirst.filter((e) => {
    const t = Date.parse(e?.occurredAt);
    if (!Number.isFinite(t) || t < days14) return false;
    return e?.importance === "high" || e?.importance === "medium";
  }).length;
  const recentHighMedCount30 = newestFirst.filter((e) => {
    const t = Date.parse(e?.occurredAt);
    if (!Number.isFinite(t) || t < days30) return false;
    return e?.importance === "high" || e?.importance === "medium";
  }).length;

  const intentStrength =
    isHandRaiserMql ||
    hasInboundRequest ||
    recentConversionSummary ||
    Number(behaviorScore) >= 20 ||
    recentHighMedCount14 >= 3
      ? "Strong"
      : Number(behaviorScore) >= 10 || recentHighMedCount30 >= 2
        ? "Moderate"
        : "Light";

  const opportunitySignals = {
    hasOpenOpportunity:
      (opportunityContactRoles || []).some(
        (r) => r?.Open_Opportunity__c === true
      ) || false,
    openOpportunityCount: Array.from(
      new Set(
        (opportunityContactRoles || [])
          .map((r) => r?.OpportunityId)
          .filter(Boolean)
      )
    ).length,
    stageNames: Array.from(
      new Set((opportunities || []).map((o) => o?.StageName).filter(Boolean))
    ).slice(0, 5)
  };
  const companyRecentOpportunityContext = buildCompanyRecentOpportunityContext({
    companyOpportunities,
    opportunityContext
  });

  const fitEvidence = {
    company: buildCompanyFitEvidence(account),
    contact: buildContactFitEvidence(contact)
  };
  const companyContext = buildCompanyContext({ account, contact });
  const mqlDetails = collectMqlExplanationDetails(mql);
  const thresholdExplanation = isThresholdMql
    ? buildThresholdExplanation({
        behaviorScore,
        companyFitTier,
        contactFitTier,
        hasInboundRequest,
        recentConversionName,
        fitEvidence,
        mqlDetails
      })
    : null;

  const keyReasons = [];
  if (hasInboundRequest)
    keyReasons.push("They directly requested follow-up (inbound intent).");
  if (isHandRaiserMql)
    keyReasons.push(
      "This contact raised their hand at an event and is directly linked to an opportunity via the Events Portal."
    );
  if (!isThresholdMql && !isHandRaiserMql && mql?.Lead_Source__c)
    keyReasons.push(
      `This MQL appears to be driven by ${cleanedText(mql.Lead_Source__c, 100)}, not by Lead scoring.`
    );
  if (contactFitThresholdMet || contactFitIsTargetTier)
    keyReasons.push("Role and persona clues align with the fit criteria.");
  if (
    isThresholdMql &&
    Number.isFinite(Number(behaviorScore)) &&
    Number(behaviorScore) > 0
  )
    keyReasons.push(
      "Recent activity was strong enough to qualify this contact through lead scoring."
    );
  if (recentConversionSummary) keyReasons.push(recentConversionSummary);
  if (companyRecentOpportunityContext?.hasRecentOpportunities === true) {
    if (Array.isArray(companyRecentOpportunityContext?.recentProducts)) {
      keyReasons.push(
        `Recent account opportunity activity points to ${humanList(
          companyRecentOpportunityContext.recentProducts.slice(0, 3)
        )} as active buying areas.`
      );
    } else {
      keyReasons.push(
        "Recent account opportunity activity suggests there may already be active company buying motion."
      );
    }
  }
  if (analyticsBehavior?.webActivity?.recentSignals === true)
    keyReasons.push(
      "Recent on-site activity suggests they are actively researching relevant content."
    );
  if (
    websiteActivity?.lastVisitAt &&
    isRecentIso(websiteActivity.lastVisitAt, 30)
  )
    keyReasons.push(
      "Recent website activity in the last 30 days suggests active research."
    );
  for (const detail of mqlDetails.slice(0, 2)) {
    keyReasons.push(
      `${isThresholdMql ? "Additional qualification context reinforces the Lead scoring story" : "Additional qualification context"}: ${detail}.`
    );
  }
  for (const positive of fitEvidence?.contact?.positives || []) {
    keyReasons.push(positive);
    if (keyReasons.length >= 10) break;
  }

  const scoreSignals = [];

  if (Number.isFinite(Number(contactFitScore))) {
    const fitBand =
      qualitativeFromThreshold({
        score: contactFitScore,
        threshold: contactFitThreshold
      }) ||
      (contactFitTier === "High"
        ? "Strong"
        : contactFitTier === "Medium"
          ? "Moderate"
          : "Light");
    scoreSignals.push({
      signal: "Fit",
      scoreText: null,
      qualitative: fitBand,
      contributesToMql: isThresholdMql && contactFitQualifies,
      implication: contactFitQualifies
        ? "Profile fit is aligned, so outreach can focus on current priorities and buying timeline."
        : "Profile fit appears weaker, so confirm role and account suitability early in the first touch."
    });
  }

  if (Number.isFinite(Number(behaviorScore)) && Number(behaviorScore) > 0) {
    const b = Number(behaviorScore);
    scoreSignals.push({
      signal: "Behavior",
      scoreText: null,
      qualitative: b >= 20 ? "Strong" : b >= 10 ? "Moderate" : "Light",
      contributesToMql: isThresholdMql,
      implication:
        "Cumulative engagement indicates sustained interest, not a one-off interaction."
    });
  }

  if (hasInboundRequest) {
    scoreSignals.push({
      signal: "Inbound request",
      scoreText: null,
      qualitative: "Urgent",
      contributesToMql: true,
      implication:
        "They asked for follow-up directly, so speed-to-contact is critical to preserve momentum."
    });
  }

  if (recentConversionName) {
    scoreSignals.push({
      signal: "Recent conversion",
      scoreText: null,
      qualitative: "Strong",
      contributesToMql: !isThresholdMql,
      implication:
        "A recent conversion suggests active evaluation, so outreach should anchor on that specific offer or event."
    });
  }

  const scoreInterpretation = [];
  scoreInterpretation.push(`Fit: ${fitLooksGood ? "Strong" : "Moderate"}.`);
  scoreInterpretation.push(`Intent: ${intentStrength}.`);
  if (!isThresholdMql && mql?.Lead_Source__c) {
    if (isHandRaiserMql) {
      scoreInterpretation.push(
        "Qualification source: Hand raiser — contact registered directly via Events Portal and is linked to an opportunity."
      );
    } else {
      scoreInterpretation.push(
        `Qualification source: This MQL appears tied to ${cleanedText(mql.Lead_Source__c, 100)}, not the Lead scoring path.`
      );
    }
  }
  for (const s of scoreSignals.filter((x) => x?.contributesToMql)) {
    scoreInterpretation.push(`${s.signal}: ${s.qualitative}. ${s.implication}`);
  }
  for (const reason of thresholdExplanation?.supportingReasons || []) {
    scoreInterpretation.push(reason);
  }
  if (hasInboundRequest)
    scoreInterpretation.push(
      "Inbound request makes this time-sensitive, but still verify fit."
    );

  // Only include items that can be rendered with the required YYYY-MM-DD prefix.
  // If we pass null dates to the model, it tends to output "Unknown date", which
  // breaks the stored summary format contract.
  const recentEngagement = newestFirst
    .map((e) => ({
      date: yyyyMmDd(e?.occurredAt) || null,
      highlight: buildSalesEventLabel(e),
      importance: e?.importance || null,
      source: "salesforce"
    }))
    .filter((e) => e.date && e.highlight);

  const hubspotRecentEngagement = buildHubspotRecentEngagement({
    hubspotPageHistory
  });
  for (const supplemental of hubspotRecentEngagement) {
    recentEngagement.push(supplemental);
  }
  for (const supplemental of buildHubspotEmailRecentEngagement({
    hubspotEmailEngagement
  })) {
    recentEngagement.push(supplemental);
  }

  for (const supplemental of buildAnalyticsRecentEngagement({
    analyticsBehavior,
    recentConversionName,
    recentConversionDate,
    recentConversionSummaryOverride,
    suppressWebActivityHighlights: hubspotRecentEngagement.length > 0
  })) {
    recentEngagement.push(supplemental);
  }
  for (const supplemental of buildSupplementalRecentEngagement({
    supplementalEngagementEvidence
  })) {
    recentEngagement.push(supplemental);
  }

  recentEngagement.sort((a, b) => {
    const dateDelta = Date.parse(b.date) - Date.parse(a.date);
    if (dateDelta !== 0) return dateDelta;
    const rank = { high: 3, medium: 2, low: 1 };
    const importanceDelta =
      (rank[b.importance] || 0) - (rank[a.importance] || 0);
    if (importanceDelta !== 0) return importanceDelta;
    const sourceRank = { hubspot: 3, analytics: 2, salesforce: 1 };
    const sourceDelta =
      (sourceRank[b.source] || 0) - (sourceRank[a.source] || 0);
    if (sourceDelta !== 0) return sourceDelta;
    return engagementSpecificityScore(b) - engagementSpecificityScore(a);
  });
  const seenRecentEngagement = new Set();
  const dedupedRecentEngagement = [];
  for (const item of recentEngagement) {
    const key = `${item.date}|${item.highlight}`;
    if (seenRecentEngagement.has(key)) continue;
    seenRecentEngagement.add(key);
    dedupedRecentEngagement.push(item);
    if (dedupedRecentEngagement.length >= 12) break;
  }

  // Add a sales-friendly website activity bullet when we have a timestamp.
  // This is often present in HubSpot even when Salesforce activity history is sparse.
  const websiteLast = websiteActivity?.lastVisitAt
    ? yyyyMmDd(websiteActivity.lastVisitAt)
    : null;
  const hasSpecificResearchSignals = dedupedRecentEngagement.some((item) =>
    /^(Visited the "|Clicked "|Opened "|Registered for ")/.test(
      String(item?.highlight || "")
    )
  );
  if (
    websiteLast &&
    isRecentIso(websiteActivity.lastVisitAt, 30) &&
    !hasSpecificResearchSignals
  ) {
    dedupedRecentEngagement.push({
      date: websiteLast,
      highlight: "Website activity recorded in the last 30 days.",
      importance: "low"
    });
    dedupedRecentEngagement.sort(
      (a, b) => Date.parse(b.date) - Date.parse(a.date)
    );
    // Cap after inserting synthetic event so the output remains predictable.
    if (dedupedRecentEngagement.length > 12)
      dedupedRecentEngagement.length = 12;
  }

  return compactObject({
    product: mql?.Product_Name__c || mql?.Product__c || null,
    productInterest:
      productInterest && typeof productInterest === "object"
        ? productInterest
        : null,
    opportunityContext: compactObject({
      openOpportunities: Array.isArray(opportunityContext?.openOpportunities)
        ? opportunityContext.openOpportunities
        : null,
      companyRecent: companyRecentOpportunityContext
    }),
    analyticsBehavior:
      analyticsBehavior?.webActivity &&
      typeof analyticsBehavior.webActivity === "object"
        ? { webActivity: analyticsBehavior.webActivity }
        : null,
    websiteActivity:
      websiteActivity && typeof websiteActivity === "object"
        ? {
            windowDays: 30,
            firstVisitDate: yyyyMmDd(websiteActivity.firstVisitAt) || null,
            lastVisitDate: yyyyMmDd(websiteActivity.lastVisitAt) || null
          }
        : null,
    mqlStatus: mql?.MQL_Status__c || null,
    mqlCreatedDate: yyyyMmDd(mql?.MQL_Date__c || mql?.CreatedDate) || null,
    companyContext,
    thresholdExplanation,
    mqlContext: {
      qualificationMode: isThresholdMql
        ? "threshold"
        : isHandRaiserMql
          ? "hand-raiser"
          : "lead-source",
      leadSource: cleanedText(mql?.Lead_Source__c, 80),
      explanationDetails: mqlDetails
    },
    fit: {
      looksGood: fitLooksGood,
      concerns: fitConcerns,
      companyTier: companyFitTier,
      contactTier: contactFitTier
    },
    fitEvidence,
    intent: {
      strength: intentStrength,
      drivers: keyReasons,
      lastEngagementDate: yyyyMmDd(lastEngagementDate),
      recentConversion: recentConversionName
        ? redactInlineText(recentConversionName)
        : null,
      recentConversionDate: yyyyMmDd(recentConversionDate)
    },
    opportunity: opportunitySignals,
    scoreSignals,
    keyReasons,
    scoreInterpretation,
    engagementThemes: collectEngagementThemes({
      recentEngagement: dedupedRecentEngagement,
      analyticsBehavior,
      recentConversionName,
      supplementalEngagementEvidence
    }),
    recentEngagement: dedupedRecentEngagement
  });
}

module.exports = {
  buildSalesNarrativeInput,
  buildSalesEventLabel,
  redactInlineText,
  yyyyMmDd,
  isHandRaiserLeadSource,
  labelFromPath
};
