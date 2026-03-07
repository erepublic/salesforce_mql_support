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

function yyyyMmDd(iso) {
  const t = Date.parse(iso);
  if (!Number.isFinite(t)) return null;
  return new Date(t).toISOString().slice(0, 10);
}

function redactInlineText(s) {
  // Keep this conservative; we should not emit new PII into Salesforce fields.
  if (!s) return null;
  let out = String(s);
  // Email addresses
  out = out.replace(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi, "*@redacted");
  // Phone-ish sequences (very rough)
  out = out.replace(/\+?\d[\d\s().-]{7,}\d/g, "[redacted]");
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
        "Their title suggests a target market or product-area focus called out in the scoring guide."
      );
    }
    if (
      /\b(sales|account executive|account manager|business development|revenue)\b/i.test(
        lowerTitle
      )
    ) {
      pushUnique(
        positives,
        "Their title suggests a sales-oriented role, which supports contact fit in the scoring guide."
      );
    }
    if (
      /\b(marketing|demand generation|communications|brand|content)\b/i.test(
        lowerTitle
      )
    ) {
      pushUnique(
        positives,
        "Their title suggests a marketing-oriented role, which supports contact fit in the scoring guide."
      );
    }
    if (
      /\b(director|vp|vice president|head|chief|president|founder|owner)\b/i.test(
        lowerTitle
      )
    ) {
      pushUnique(
        positives,
        "Their title suggests director-level or higher seniority, which supports contact fit in the scoring guide."
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

  if (industry) {
    pushUnique(observations, `Account industry is recorded as ${industry}.`);
    pushUnique(
      positives,
      "Industry is one of the company-fit inputs used by the scoring guide."
    );
  } else {
    pushUnique(
      missingInputs,
      "Account industry is not available, so industry-based company-fit evidence is incomplete."
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
      "No direct state-contract, previous-customer, or competitor-detail fields are exposed here, so company-fit attribution is partial."
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
  engagementScore,
  engagementThreshold,
  hasInboundRequest,
  recentConversionName,
  fitEvidence,
  mqlDetails
}) {
  const behavior = toNumberOrNull(behaviorScore);
  const engagement = toNumberOrNull(engagementScore);
  const engagementCutoff = toNumberOrNull(engagementThreshold);
  let matchedRule = null;
  let requiredBehaviorScore = null;

  if (
    behavior !== null &&
    behavior >= 30 &&
    ((contactFitTier === "Medium" && companyFitTier === "Medium") ||
      (contactFitTier === "High" &&
        (companyFitTier === "Medium" || companyFitTier === "Low")))
  ) {
    matchedRule =
      companyFitTier === "Medium" && contactFitTier === "Medium"
        ? "Behavior 30+ with Medium company fit and Medium contact fit"
        : `Behavior 30+ with ${companyFitTier} company fit and High contact fit`;
    requiredBehaviorScore = 30;
  } else if (
    behavior !== null &&
    behavior >= 20 &&
    companyFitTier === "High" &&
    (contactFitTier === "High" || contactFitTier === "Medium")
  ) {
    matchedRule = `Behavior 20+ with High company fit and ${contactFitTier} contact fit`;
    requiredBehaviorScore = 20;
  }

  const gapToThreshold =
    behavior !== null && requiredBehaviorScore !== null
      ? behavior - requiredBehaviorScore
      : null;

  let summary = null;
  if (matchedRule && behavior !== null) {
    const gapText =
      gapToThreshold === 0
        ? "right at the threshold"
        : gapToThreshold > 0
          ? `${gapToThreshold} point${gapToThreshold === 1 ? "" : "s"} above the threshold`
          : `${Math.abs(gapToThreshold)} point${Math.abs(gapToThreshold) === 1 ? "" : "s"} below the threshold`;
    summary = `This record likely qualified through the fit-and-behavior rule because behavior score ${behavior} cleared the ${requiredBehaviorScore}-point cutoff for a ${String(
      companyFitTier || "unknown"
    ).toLowerCase()} company-fit account and a ${String(
      contactFitTier || "unknown"
    ).toLowerCase()} contact-fit profile (${gapText}).`;
  } else if (behavior !== null && (companyFitTier || contactFitTier)) {
    summary = `Behavior score ${behavior} is being evaluated alongside ${String(
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
  if (
    engagement !== null &&
    engagementCutoff !== null &&
    engagement >= engagementCutoff
  ) {
    supportingReasons.push(
      `Engagement score ${engagement} is also at or above its ${engagementCutoff}-point threshold.`
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
    behaviorScore: behavior,
    requiredBehaviorScore,
    gapToThreshold,
    engagementScore: engagement,
    engagementThreshold: engagementCutoff,
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
  websiteActivity
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

  const engagementScore = contact?.HubSpot_Engagement_Score__c;
  const engagementThreshold = contact?.HubSpot_Engagement_Score_Threshold__c;
  const engagementThresholdMet =
    Number.isFinite(Number(engagementScore)) &&
    Number.isFinite(Number(engagementThreshold)) &&
    Number(engagementScore) >= Number(engagementThreshold);

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
    engagementThresholdMet || recentHighMedCount14 >= 3
      ? "Strong"
      : recentHighMedCount30 >= 2
        ? "Moderate"
        : "Light";

  const hasInboundRequest =
    newestFirst.some((e) => e?.eventType === "contactUsSubmitted") ||
    String(mql?.Lead_Source__c || "")
      .toLowerCase()
      .includes("contact us") ||
    String(mql?.Lead_Source__c || "")
      .toLowerCase()
      .includes("contact");

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
  const thresholdExplanation = buildThresholdExplanation({
    behaviorScore,
    companyFitTier,
    contactFitTier,
    engagementScore,
    engagementThreshold,
    hasInboundRequest,
    recentConversionName,
    fitEvidence,
    mqlDetails
  });

  const keyReasons = [];
  if (hasInboundRequest)
    keyReasons.push("They directly requested follow-up (inbound intent).");
  if (engagementThresholdMet)
    keyReasons.push(
      "Recent engagement meets the marketing engagement threshold."
    );
  if (contactFitThresholdMet || contactFitIsTargetTier)
    keyReasons.push("Role/person-level fit meets the fit threshold.");
  if (Number.isFinite(Number(behaviorScore)) && Number(behaviorScore) > 0)
    keyReasons.push(
      "They have accumulated meaningful engagement over time (behavior score increased)."
    );
  if (recentConversionName)
    keyReasons.push("They recently converted on a high-intent offer.");
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
  if (analyticsBehavior?.emailEngagement?.recentSignals === true)
    keyReasons.push(
      "Recent marketing email engagement suggests active interest (opens/clicks)."
    );
  if (analyticsBehavior?.webActivity?.recentSignals === true)
    keyReasons.push(
      "Recent on-site activity suggests they are actively researching relevant content."
    );
  if (
    websiteActivity?.lastVisitAt &&
    isRecentIso(websiteActivity.lastVisitAt, 30)
  )
    keyReasons.push(
      "Recent website activity suggests active research (recent site visits/pageviews)."
    );
  for (const detail of mqlDetails.slice(0, 2)) {
    keyReasons.push(
      `Additional qualification context reinforces the threshold story: ${detail}.`
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
    const fitScoreText = Number(contactFitScore);
    const fitThresholdText = Number.isFinite(Number(contactFitThreshold))
      ? ` (threshold ${Number(contactFitThreshold)})`
      : contactFitTier
        ? ` (${contactFitTier} tier)`
        : "";
    scoreSignals.push({
      signal: "Fit score",
      scoreText: `${fitScoreText}${fitThresholdText}`,
      qualitative: fitBand,
      contributesToMql: contactFitQualifies,
      implication: contactFitQualifies
        ? "Profile fit is aligned, so outreach can focus on current priorities and buying timeline."
        : "Profile fit appears weaker, so confirm role and account suitability early in the first touch."
    });
  }

  if (Number.isFinite(Number(engagementScore))) {
    const engagementBand =
      qualitativeFromThreshold({
        score: engagementScore,
        threshold: engagementThreshold
      }) || intentStrength;
    const engagementScoreText = Number(engagementScore);
    const engagementThresholdText = Number.isFinite(Number(engagementThreshold))
      ? ` (threshold ${Number(engagementThreshold)})`
      : "";
    scoreSignals.push({
      signal: "Engagement score",
      scoreText: `${engagementScoreText}${engagementThresholdText}`,
      qualitative: engagementBand,
      contributesToMql: engagementThresholdMet,
      implication: engagementThresholdMet
        ? "Recent activity is high enough to justify timely outreach while intent is active."
        : "Engagement is building, so reference the strongest recent interactions to test urgency."
    });
  }

  if (Number.isFinite(Number(behaviorScore)) && Number(behaviorScore) > 0) {
    const b = Number(behaviorScore);
    scoreSignals.push({
      signal: "Behavior score",
      scoreText: String(b),
      qualitative: b >= 20 ? "Strong" : b >= 10 ? "Moderate" : "Light",
      contributesToMql: true,
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
      contributesToMql: true,
      implication:
        "A recent conversion suggests active evaluation, so outreach should anchor on that offer context."
    });
  }

  const scoreInterpretation = [];
  scoreInterpretation.push(`Fit: ${fitLooksGood ? "Strong" : "Moderate"}.`);
  scoreInterpretation.push(`Intent: ${intentStrength}.`);
  for (const s of scoreSignals.filter((x) => x?.contributesToMql)) {
    const scorePart = s.scoreText ? `Score ${s.scoreText}; ` : "";
    scoreInterpretation.push(
      `${s.signal}: ${scorePart}${s.qualitative}. ${s.implication}`
    );
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
      importance: e?.importance || null
    }))
    .filter((e) => e.date && e.highlight)
    .slice(0, 12);

  // Add a sales-friendly website activity bullet when we have a timestamp.
  // This is often present in HubSpot even when Salesforce activity history is sparse.
  const websiteLast = websiteActivity?.lastVisitAt
    ? yyyyMmDd(websiteActivity.lastVisitAt)
    : null;
  if (websiteLast) {
    const parts = [];
    const v = websiteActivity?.visits;
    const pv = websiteActivity?.pageViews;
    if (Number.isFinite(Number(v)) && Number(v) > 0)
      parts.push(`${v} site visits`);
    if (Number.isFinite(Number(pv)) && Number(pv) > 0)
      parts.push(`${pv} pages viewed`);
    const totals = parts.length ? ` (${parts.join(", ")} total)` : "";
    const recencyLabel = isRecentIso(websiteActivity.lastVisitAt, 90)
      ? "Website activity"
      : "Historical website activity";
    recentEngagement.push({
      date: websiteLast,
      highlight: `${recencyLabel} recorded${totals}.`,
      importance: "low"
    });
    recentEngagement.sort((a, b) => Date.parse(b.date) - Date.parse(a.date));
    // Cap after inserting synthetic event so the output remains predictable.
    if (recentEngagement.length > 12) recentEngagement.length = 12;
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
      analyticsBehavior && typeof analyticsBehavior === "object"
        ? analyticsBehavior
        : null,
    websiteActivity:
      websiteActivity && typeof websiteActivity === "object"
        ? {
            visits: websiteActivity.visits ?? null,
            pageViews: websiteActivity.pageViews ?? null,
            firstVisitDate: yyyyMmDd(websiteActivity.firstVisitAt) || null,
            lastVisitDate: yyyyMmDd(websiteActivity.lastVisitAt) || null
          }
        : null,
    mqlStatus: mql?.MQL_Status__c || null,
    mqlCreatedDate: yyyyMmDd(mql?.MQL_Date__c || mql?.CreatedDate) || null,
    companyContext,
    thresholdExplanation,
    mqlContext: {
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
    recentEngagement
  });
}

module.exports = {
  buildSalesNarrativeInput,
  buildSalesEventLabel,
  redactInlineText,
  yyyyMmDd
};
