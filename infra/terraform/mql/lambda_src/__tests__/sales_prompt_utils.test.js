const {
  buildSalesNarrativeInput,
  buildSalesEventLabel,
  isHandRaiserLeadSource
} = require("../sales_prompt_utils");

test("buildSalesEventLabel redacts emails", () => {
  const label = buildSalesEventLabel({
    eventType: "emailEngagement",
    title: "Email",
    detail: "Re: Pricing - from jane.doe@example.com"
  });
  expect(label).toContain("*@redacted");
  expect(label).not.toContain("jane.doe@example.com");
});

test("buildSalesEventLabel redacts Salesforce-style record ids", () => {
  const label = buildSalesEventLabel({
    eventType: "mqlConverted",
    title: "Converted",
    detail: "Created Opportunity | 006VE00000TkWFXYA3"
  });
  expect(label).toContain("[redacted]");
  expect(label).not.toContain("006VE00000TkWFXYA3");
});

test("buildSalesNarrativeInput sorts recentEngagement newest-first", () => {
  const out = buildSalesNarrativeInput({
    mql: {
      Lead_Source__c: "Fit and Behavior Threshold Reached",
      MQL_Date__c: "2026-02-01"
    },
    contact: {
      Private_Sector_Non_Qual__c: false,
      HubSpot_Engagement_Score__c: 10,
      HubSpot_Engagement_Score_Threshold__c: 5
    },
    account: { Private_Sector_Non_Qual__c: false },
    opportunities: [],
    opportunityContactRoles: [],
    historyEvents: [
      {
        occurredAt: "2026-01-10T00:00:00.000Z",
        eventType: "campaignTouch",
        title: "Campaign touch"
      },
      {
        occurredAt: "2026-02-12T00:00:00.000Z",
        eventType: "contactUsSubmitted",
        title: "Contact Us submitted"
      },
      {
        occurredAt: "2026-02-05T00:00:00.000Z",
        eventType: "meetingLogged",
        title: "Meeting logged"
      }
    ]
  });

  expect(out.recentEngagement[0].date).toBe("2026-02-12");
  expect(out.recentEngagement[1].date).toBe("2026-02-05");
  expect(out.recentEngagement[2].date).toBe("2026-01-10");
});

test("buildSalesNarrativeInput emits qualifying score signals with numeric and qualitative details", () => {
  const out = buildSalesNarrativeInput({
    mql: {
      Lead_Source__c: "Fit and Behavior Threshold Reached",
      MQL_Date__c: "2026-02-01"
    },
    contact: {
      Private_Sector_Non_Qual__c: false,
      HubSpot_Engagement_Score__c: 12,
      HubSpot_Engagement_Score_Threshold__c: 10,
      HubSpot_Private_Sector_Contact_Fit__c: 8,
      Contact_Fit_Threshold__c: 7,
      HubSpot_Private_Sector_Behavior_Score__c: 14,
      HubSpot_Recent_Conversion__c: "Navigator Guide"
    },
    account: { Private_Sector_Non_Qual__c: false },
    opportunities: [],
    opportunityContactRoles: [],
    historyEvents: [
      {
        occurredAt: "2026-02-12T00:00:00.000Z",
        eventType: "contactUsSubmitted",
        title: "Contact Us submitted"
      }
    ]
  });

  expect(Array.isArray(out.scoreSignals)).toBe(true);
  expect(
    out.scoreSignals.some(
      (s) =>
        s.signal === "Engagement score" &&
        s.scoreText === "12 (threshold 10)" &&
        s.qualitative === "Strong" &&
        s.contributesToMql === false
    )
  ).toBe(true);
  expect(
    out.scoreSignals.some(
      (s) =>
        s.signal === "Fit score" &&
        s.scoreText === "8 (threshold 7)" &&
        s.qualitative === "Strong" &&
        s.contributesToMql === true
    )
  ).toBe(true);
  expect(
    out.scoreInterpretation.some((b) =>
      b.includes("Engagement score: Score 12 (threshold 10); Strong.")
    )
  ).toBe(false);
  expect(
    out.scoreInterpretation.some((b) => b.includes("Inbound request: Urgent."))
  ).toBe(true);
});

test("buildSalesNarrativeInput adds threshold explanation and raw fit evidence", () => {
  const out = buildSalesNarrativeInput({
    mql: {
      Lead_Source__c: "Fit and Behavior Threshold Reached",
      Lead_Source_Detail__c: "Threshold rerouted after behavior spike",
      Lead_Detail_1__c: "Attended pricing webinar",
      MQL_Date__c: "2026-02-01"
    },
    contact: {
      Title: "Director of Marketing",
      Email: "buyer@acme.com",
      Contact_Status__c: "Active",
      Private_Sector_Non_Qual__c: false,
      HubSpot_Private_Sector_Behavior_Score__c: 22,
      HubSpot_Private_Sector_Contact_Fit__c: 5,
      Contact_Fit_Threshold__c: "Medium",
      HubSpot_Engagement_Score__c: 14,
      HubSpot_Engagement_Score_Threshold__c: 10
    },
    account: {
      Private_Sector_Non_Qual__c: false,
      Company_Fit_Threshold__c: "High",
      Industry: "Software"
    },
    opportunities: [],
    opportunityContactRoles: [],
    historyEvents: []
  });

  expect(out.thresholdExplanation.matchedRule).toBe(
    "Behavior 20+ with High company fit and Medium contact fit"
  );
  expect(out.thresholdExplanation.summary).toContain("behavior score 22");
  expect(out.fitEvidence.contact.positives).toContain(
    "Their title matches a marketing-role criterion from the scoring guide."
  );
  expect(out.fitEvidence.contact.positives).toContain(
    "Their title matches the director-or-higher seniority criterion from the scoring guide."
  );
  expect(out.fitEvidence.company.observations).toContain(
    "Account industry is recorded as Software."
  );
  expect(out.mqlContext.explanationDetails[0]).toContain(
    "Threshold rerouted after behavior spike"
  );
  expect(out.scoreSignals.some((s) => s.signal === "Threshold path")).toBe(
    false
  );
  expect(out.scoreInterpretation.some((b) => b.startsWith("Threshold:"))).toBe(
    false
  );
});

test("buildSalesNarrativeInput keeps partial evidence explicit when raw inputs are missing", () => {
  const out = buildSalesNarrativeInput({
    mql: {
      Lead_Source__c: "Fit and Behavior Threshold Reached",
      MQL_Date__c: "2026-02-01"
    },
    contact: {
      Email: "prospect@gmail.com",
      Private_Sector_Non_Qual__c: false,
      HubSpot_Private_Sector_Behavior_Score__c: 18,
      HubSpot_Private_Sector_Contact_Fit__c: 0,
      Contact_Fit_Threshold__c: "Low"
    },
    account: {
      Private_Sector_Non_Qual__c: false,
      Company_Fit_Threshold__c: "Low"
    },
    opportunities: [],
    opportunityContactRoles: [],
    historyEvents: []
  });

  expect(out.thresholdExplanation.summary).toContain(
    "only partially visible from the available fields"
  );
  expect(out.fitEvidence.contact.concerns).toContain(
    "The email domain appears to be personal/free, which is a strong negative fit signal in the scoring guide."
  );
  expect(out.fitEvidence.contact.missingInputs).toContain(
    "Contact title is not available, so role and seniority evidence is incomplete."
  );
  expect(out.fitEvidence.company.missingInputs).toContain(
    "Account industry is not available, so industry-based company-fit evidence is incomplete."
  );
});

test("buildSalesNarrativeInput includes compact company context for seller-facing enrichment", () => {
  const out = buildSalesNarrativeInput({
    mql: {
      Lead_Source__c: "Contact Us",
      Product_Name__c: "Navigator",
      MQL_Date__c: "2026-02-01"
    },
    contact: {
      Private_Sector_Non_Qual__c: false,
      Company_Name_Holder__c: "Acme Corp",
      Department: "Revenue Operations",
      Topics_Interested_In__c: "Procurement;Market Intelligence"
    },
    account: {
      Name: "Acme Corporation",
      Description:
        "B2B software company that sells procurement workflow tools to enterprise teams.",
      Industry: "Software",
      Revenue_Category__c: "$100M-$500M",
      Navigator_Budget_Range__c: "$250k-$500k",
      Navigator_Stage__c: "Active",
      Navigator_Sales_Status__c: "Prospecting",
      DEN_Membership_Contract_Level__c: "Premium",
      DEN_Membership_Contract_Status__c: "Active"
    },
    opportunities: [],
    opportunityContactRoles: [],
    historyEvents: []
  });

  expect(out.companyContext.companyName).toBe("Acme Corporation");
  expect(out.companyContext.businessSummary).toContain("B2B software company");
  expect(out.companyContext.revenueBand).toBe("$100M-$500M");
  expect(out.companyContext.budgetRange).toBe("$250k-$500k");
  expect(out.companyContext.accountStage).toBe("Active");
  expect(out.companyContext.salesStatus).toBe("Prospecting");
  expect(out.companyContext.customerFootprint).toEqual([
    { product: "DEN", level: "Premium", status: "Active" }
  ]);
  expect(out.companyContext.contactContext.department).toBe(
    "Revenue Operations"
  );
  expect(out.companyContext.contactContext.interestTopics).toEqual([
    "Procurement",
    "Market Intelligence"
  ]);
});

test("buildSalesNarrativeInput uses specific recent conversion naming and last-30-day website wording", () => {
  const out = buildSalesNarrativeInput({
    mql: {
      Lead_Source__c: "Registered for Webinar",
      MQL_Date__c: "2026-02-01"
    },
    contact: {
      Private_Sector_Non_Qual__c: false,
      HubSpot_Recent_Conversion__c: "XYZ Webinar"
    },
    account: { Private_Sector_Non_Qual__c: false },
    opportunities: [],
    opportunityContactRoles: [],
    historyEvents: [],
    websiteActivity: {
      lastVisitAt: new Date().toISOString(),
      visits: 38,
      pageViews: 28
    }
  });

  expect(out.keyReasons).toContain("They recently registered for XYZ Webinar.");
  expect(
    out.recentEngagement.some((item) => item.highlight.includes("last 30 days"))
  ).toBe(true);
  expect(
    out.recentEngagement.some((item) =>
      item.highlight.includes("38 site visits")
    )
  ).toBe(false);
});

test("buildSalesNarrativeInput marks non-threshold MQLs as lead-source driven", () => {
  const out = buildSalesNarrativeInput({
    mql: {
      Lead_Source__c: "Registered for Webinar",
      MQL_Date__c: "2026-02-01"
    },
    contact: {
      Private_Sector_Non_Qual__c: false,
      HubSpot_Private_Sector_Behavior_Score__c: 6,
      HubSpot_Engagement_Score__c: 12,
      HubSpot_Engagement_Score_Threshold__c: 10
    },
    account: { Private_Sector_Non_Qual__c: false },
    opportunities: [],
    opportunityContactRoles: [],
    historyEvents: []
  });

  expect(out.mqlContext.qualificationMode).toBe("lead-source");
  expect(out.thresholdExplanation).toBeUndefined();
  expect(
    out.scoreInterpretation.some((item) =>
      item.includes("not the fit-and-behavior threshold")
    )
  ).toBe(true);
  expect(
    out.scoreSignals.some(
      (item) =>
        item.signal === "Behavior score" && item.contributesToMql === false
    )
  ).toBe(true);
});

test("buildSalesNarrativeInput compacts recent company opportunity context", () => {
  const out = buildSalesNarrativeInput({
    mql: {
      Lead_Source__c: "Fit and Behavior Threshold Reached",
      MQL_Date__c: "2026-02-01"
    },
    contact: {
      Private_Sector_Non_Qual__c: false,
      HubSpot_Engagement_Score__c: 12,
      HubSpot_Engagement_Score_Threshold__c: 10
    },
    account: { Private_Sector_Non_Qual__c: false },
    opportunities: [],
    companyOpportunities: [],
    opportunityContactRoles: [],
    historyEvents: [],
    opportunityContext: {
      companyRecentOpportunities: [
        {
          name: "Navigator Expansion",
          stage: "Proposal",
          status: "Open",
          closeDate: "2026-02-20",
          amountBand: "$100k-$499k",
          products: ["Navigator", "Workflow"]
        },
        {
          name: "DEN Renewal",
          stage: "Closed Won",
          status: "Closed won",
          closeDate: "2026-01-15",
          products: ["DEN"]
        }
      ]
    }
  });

  expect(out.opportunityContext.companyRecent.hasRecentOpportunities).toBe(
    true
  );
  expect(out.opportunityContext.companyRecent.recentOpportunityCount).toBe(2);
  expect(out.opportunityContext.companyRecent.openOpportunityCount).toBe(1);
  expect(out.opportunityContext.companyRecent.recentStageNames).toEqual([
    "Proposal",
    "Closed Won"
  ]);
  expect(out.opportunityContext.companyRecent.recentProducts).toEqual([
    "Navigator",
    "Workflow",
    "DEN"
  ]);
  expect(out.opportunityContext.companyRecent.recentDeals).toEqual([
    {
      name: "Navigator Expansion",
      stage: "Proposal",
      status: "Open",
      closeDate: "2026-02-20",
      amountBand: "$100k-$499k",
      products: ["Navigator", "Workflow"]
    },
    {
      name: "DEN Renewal",
      stage: "Closed Won",
      status: "Closed won",
      closeDate: "2026-01-15",
      products: ["DEN"]
    }
  ]);

  const s = JSON.stringify(out);
  expect(s).not.toContain("companyRecentOpportunities");
});

test("salesNarrativeInput does not contain raw field-name tokens", () => {
  const out = buildSalesNarrativeInput({
    mql: { Lead_Source__c: "Email", Product_Name__c: "Navigator" },
    contact: { Private_Sector_Non_Qual__c: false },
    account: { Private_Sector_Non_Qual__c: false },
    opportunities: [],
    opportunityContactRoles: [],
    historyEvents: [],
    productInterest: {
      topProducts: [
        {
          name: "Navigator",
          confidence: "High",
          evidence: ["URL: http://www.govtech.com/navigator/numbers/x.html"]
        }
      ]
    },
    analyticsBehavior: {
      webActivity: {
        recentSignals: true,
        topPaths: [{ value: "/content/opportunities/rfp/123", count: 2 }]
      },
      emailEngagement: {
        recentSignals: true,
        mailgunTopEvents: [{ value: "opened", count: 3 }]
      }
    }
  });

  const s = JSON.stringify(out);
  expect(s).not.toMatch(/__c\b/);
  expect(s).not.toMatch(/HubSpot_/);
  expect(s).not.toMatch(/OpportunityContactRole/);
  expect(s).not.toMatch(/MQL__c/);
});

test("isHandRaiserLeadSource identifies Events Portal correctly", () => {
  expect(isHandRaiserLeadSource("Events Portal")).toBe(true);
  expect(isHandRaiserLeadSource("events portal")).toBe(false);
  expect(isHandRaiserLeadSource("Fit and Behavior Threshold Reached")).toBe(
    false
  );
  expect(isHandRaiserLeadSource(null)).toBe(false);
  expect(isHandRaiserLeadSource("")).toBe(false);
});

test("buildSalesNarrativeInput sets qualificationMode=hand-raiser for Events Portal MQL", () => {
  const out = buildSalesNarrativeInput({
    mql: {
      Lead_Source__c: "Events Portal",
      MQL_Date__c: "2026-03-01"
    },
    contact: {
      Private_Sector_Non_Qual__c: false
    },
    account: { Private_Sector_Non_Qual__c: false },
    opportunities: [],
    opportunityContactRoles: [],
    historyEvents: []
  });

  expect(out.mqlContext.qualificationMode).toBe("hand-raiser");
  expect(out.intent.strength).toBe("Strong");
  expect(
    out.keyReasons.some((r) =>
      String(r).toLowerCase().includes("raised their hand")
    )
  ).toBe(true);
  expect(
    out.scoreInterpretation.some((s) =>
      String(s).toLowerCase().includes("events portal")
    )
  ).toBe(true);
  expect(
    out.keyReasons.some((r) =>
      String(r).toLowerCase().includes("not by threshold")
    )
  ).toBe(false);
});

test("buildSalesNarrativeInput does not emit hand-raiser reason for threshold MQL", () => {
  const out = buildSalesNarrativeInput({
    mql: {
      Lead_Source__c: "Fit and Behavior Threshold Reached",
      MQL_Date__c: "2026-03-01"
    },
    contact: { Private_Sector_Non_Qual__c: false },
    account: { Private_Sector_Non_Qual__c: false },
    opportunities: [],
    opportunityContactRoles: [],
    historyEvents: []
  });

  expect(out.mqlContext.qualificationMode).toBe("threshold");
  expect(
    out.keyReasons.some((r) =>
      String(r).toLowerCase().includes("raised their hand")
    )
  ).toBe(false);
});

test("buildHistoryEventsPreview returns events newest-first", () => {
  const { _internals } = require("../index.js");

  const allow = {
    defaults: { recencyWindowDays: 365, maxEvents: 25, capsByEventType: {} },
    timelineRecipe: {
      importance: { high: ["mqlCreated", "taskCompleted"], medium: [], low: [] }
    }
  };

  const preview = _internals.buildHistoryEventsPreview({
    allowlist: allow,
    contact: { Id: "003xx0000000001", Email: "a@b.com", Name: "Test" },
    mql: {
      Id: "a0Xxx0000000001",
      Lead_Source__c: "Email",
      MQL_Date__c: "2026-01-01",
      CreatedDate: "2026-01-01T00:00:00.000Z"
    },
    opportunityContactRoles: [],
    opportunities: [],
    tasks: [
      {
        Id: "00Txx0000000001",
        Status: "Completed",
        Subject: "Left voicemail",
        ActivityDate: "2026-02-10",
        CreatedDate: "2026-02-10T00:00:00.000Z"
      }
    ],
    events: [],
    emailMessages: [],
    campaignMembers: [],
    contactUsSubmissions: [],
    history: {},
    sinceDays: 365
  });

  expect(preview.events[0].occurredAt.startsWith("2026-02-10")).toBe(true);
  expect(
    preview.events[preview.events.length - 1].occurredAt.startsWith(
      "2026-01-01"
    )
  ).toBe(true);
});
