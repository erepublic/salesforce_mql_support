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

function buildSalesNarrativeInput({
  mql,
  contact,
  account,
  opportunities,
  opportunityContactRoles,
  historyEvents,
  productInterest,
  opportunityContext
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
  const contactFitThresholdMet =
    Number.isFinite(Number(contactFitScore)) &&
    Number.isFinite(Number(contactFitThreshold)) &&
    Number(contactFitScore) >= Number(contactFitThreshold);

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

  const keyReasons = [];
  if (hasInboundRequest)
    keyReasons.push("They directly requested follow-up (inbound intent).");
  if (engagementThresholdMet)
    keyReasons.push(
      "Recent engagement meets the marketing engagement threshold."
    );
  if (contactFitThresholdMet)
    keyReasons.push("Role/person-level fit meets the fit threshold.");
  if (Number.isFinite(Number(behaviorScore)) && Number(behaviorScore) > 0)
    keyReasons.push(
      "They have accumulated meaningful engagement over time (behavior score increased)."
    );
  if (recentConversionName)
    keyReasons.push("They recently converted on a high-intent offer.");

  const scoreInterpretation = [];
  scoreInterpretation.push(
    fitLooksGood
      ? "Fit: Looks good based on eligibility checks."
      : "Fit: Review needed due to eligibility concerns."
  );
  scoreInterpretation.push(
    `Intent: ${intentStrength}, based on recent engagement and conversions.`
  );
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

  return compactObject({
    product: mql?.Product_Name__c || mql?.Product__c || null,
    productInterest:
      productInterest && typeof productInterest === "object"
        ? productInterest
        : null,
    opportunityContext:
      opportunityContext && typeof opportunityContext === "object"
        ? opportunityContext
        : null,
    mqlStatus: mql?.MQL_Status__c || null,
    mqlCreatedDate: yyyyMmDd(mql?.MQL_Date__c || mql?.CreatedDate) || null,
    fit: {
      looksGood: fitLooksGood,
      concerns: fitConcerns
    },
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
