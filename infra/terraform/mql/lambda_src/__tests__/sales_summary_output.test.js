const { _internals } = require("../index.js");

test("deterministic sales summary includes required sections and validates", () => {
  const html = _internals.buildDeterministicSalesSummaryHtml({
    keyReasons: ["They directly requested follow-up (inbound intent)."],
    scoreInterpretation: ["Fit: Looks good based on eligibility checks."],
    fit: { concerns: [] },
    opportunity: { hasOpenOpportunity: false },
    recentEngagement: [
      { date: "2026-02-12", highlight: "Inbound request (Contact Us)" },
      { date: "2026-02-05", highlight: "Meeting logged - Intro call" }
    ]
  });

  expect(html).toContain("<p><strong>Why Sales Should Care</strong></p>");
  expect(html).toContain("<p><strong>Score Interpretation</strong></p>");
  expect(html).toContain("<p><strong>Most Recent Engagement</strong></p>");
  expect(html).toContain("<p><strong>Suggested Next Step</strong></p>");

  const v = _internals.validateSalesFacingHtml(html);
  expect(v.ok).toBe(true);
});

test("finalizeSalesSummaryHtml enforces section caps", () => {
  const base = [
    `<p><strong>Why Sales Should Care</strong></p>`,
    `<ul><li>A</li><li>B</li><li>C</li></ul>`,
    `<p><strong>Score Interpretation</strong></p>`,
    `<ul><li>A</li><li>B</li><li>C</li><li>D</li><li>E</li><li>F</li><li>G</li></ul>`,
    `<p><strong>Most Recent Engagement</strong></p>`,
    `<ul><li>2026-02-01 - A</li><li>2026-01-31 - B</li></ul>`,
    `<p><strong>Suggested Next Step</strong></p>`,
    `<ul><li>A</li><li>B</li><li>C</li></ul>`
  ].join("\n");

  const out = _internals.finalizeSalesSummaryHtml({
    html: base,
    instanceUrl: "https://example.my.salesforce.com",
    mql: {},
    opportunities: [],
    opportunityContactRoles: []
  });

  // Score Interpretation max=4
  const scoreBlock = out.split(
    "<p><strong>Score Interpretation</strong></p>"
  )[1];
  expect((scoreBlock.match(/<li>/g) || []).length).toBeGreaterThan(0);
  const firstScoreUl =
    (scoreBlock.match(/<ul>([\s\S]*?)<\/ul>/i) || [])[1] || "";
  expect((firstScoreUl.match(/<li>/g) || []).length).toBe(4);
  expect(scoreBlock).not.toContain("<li>E</li>");

  // Suggested Next Step max=2
  const nextBlock = out.split("<p><strong>Suggested Next Step</strong></p>")[1];
  expect((nextBlock.match(/<li>/g) || []).length).toBe(2);
  expect(nextBlock).not.toContain("<li>C</li>");
});

test("finalizeSalesSummaryHtml rewrites engagement section from canonical input", () => {
  const base = [
    `<p><strong>Why Sales Should Care</strong></p>`,
    `<ul><li>A</li><li>B</li><li>C</li></ul>`,
    `<p><strong>Score Interpretation</strong></p>`,
    `<ul><li>A</li><li>B</li><li>C</li></ul>`,
    `<p><strong>Most Recent Engagement</strong></p>`,
    `<ul><li>Marketing qualified lead created</li><li>Website activity recorded</li></ul>`,
    `<p><strong>Suggested Next Step</strong></p>`,
    `<ul><li>A</li></ul>`
  ].join("\n");

  const out = _internals.finalizeSalesSummaryHtml({
    html: base,
    salesNarrativeInput: {
      recentEngagement: [
        { date: "2026-02-12", highlight: "Marketing qualified lead created" },
        { date: "2026-02-05", highlight: "Website activity recorded." }
      ]
    },
    instanceUrl: "https://example.my.salesforce.com",
    mql: {},
    opportunities: [],
    opportunityContactRoles: []
  });

  expect(out).toContain("2026-02-12 - Marketing qualified lead created");
  expect(out).toContain("2026-02-05 - Website activity recorded.");
  expect(out).not.toContain("<li>Marketing qualified lead created</li>");
});

test("finalizeSalesSummaryHtml appends safe product/opportunity links and still validates", () => {
  const base = [
    `<p><strong>Why Sales Should Care</strong></p>`,
    `<ul><li>A</li><li>B</li><li>C</li></ul>`,
    `<p><strong>Score Interpretation</strong></p>`,
    `<ul><li>A</li><li>B</li><li>C</li></ul>`,
    `<p><strong>Most Recent Engagement</strong></p>`,
    `<ul><li>2026-02-01 - A</li><li>2026-01-31 - B</li></ul>`,
    `<p><strong>Suggested Next Step</strong></p>`,
    `<ul><li>A</li></ul>`
  ].join("\n");

  const out = _internals.finalizeSalesSummaryHtml({
    html: base,
    instanceUrl: "https://example.my.salesforce.com",
    mql: { Product__c: "01t14000005McabAAC", Product_Name__c: "Navigator" },
    opportunities: [
      { Id: "006VE00000SNA9rYAH", Name: "Test Opp", StageName: "Discover" }
    ],
    opportunityContactRoles: [
      {
        Id: "00Kxx0000000001",
        OpportunityId: "006VE00000SNA9rYAH",
        Open_Opportunity__c: true
      }
    ]
  });

  expect(out).toContain("<p><strong>Links</strong></p>");
  expect(out).toContain(
    'href="https://example.my.salesforce.com/01t14000005McabAAC"'
  );
  expect(out).toContain(
    'href="https://example.my.salesforce.com/006VE00000SNA9rYAH"'
  );
  expect(out).toContain("Product: Navigator");
  expect(out).toContain("Opportunity: Test Opp");

  const v = _internals.validateSalesFacingHtml(out);
  expect(v.ok).toBe(true);
});

test("finalizeSalesSummaryHtml closes dangling list tags before appending links", () => {
  const base =
    `<p><strong>Why Sales Should Care</strong></p><ul><li>A</li></ul>` +
    `<p><strong>Score Interpretation</strong></p><ul><li>B</li></ul>` +
    `<p><strong>Most Recent Engagement</strong></p><ul><li>2026-02-01 - A</li></ul>` +
    `<p><strong>Suggested Next Step</strong></p><ul><li>Broken next step`;

  const out = _internals.finalizeSalesSummaryHtml({
    html: base,
    instanceUrl: "https://example.my.salesforce.com",
    mql: { Product__c: "01t14000005McabAAC", Product_Name__c: "Navigator" },
    opportunities: [],
    opportunityContactRoles: []
  });

  expect(out).toContain("</li></ul>\n<p><strong>Links</strong></p>");
  const v = _internals.validateSalesFacingHtml(out);
  expect(v.ok).toBe(true);
});

test("deterministic sales summary mentions product-interest when present", () => {
  const html = _internals.buildDeterministicSalesSummaryHtml({
    productInterest: {
      topProducts: [
        { name: "Navigator", confidence: "High", evidence: ["URL: ..."] },
        { name: "GovTech", confidence: "Moderate", evidence: ["URL: ..."] }
      ]
    },
    keyReasons: ["Recent engagement meets the marketing engagement threshold."],
    scoreInterpretation: ["Fit: Looks good based on eligibility checks."],
    fit: { concerns: [] },
    opportunity: { hasOpenOpportunity: false },
    recentEngagement: []
  });

  expect(html).toContain("Likely areas of interest");
  expect(html).toContain("Navigator");
  const v = _internals.validateSalesFacingHtml(html);
  expect(v.ok).toBe(true);
});

test("deterministic sales summary keeps score interpretation qualitative and suppresses engagement score", () => {
  const html = _internals.buildDeterministicSalesSummaryHtml({
    scoreSignals: [
      {
        signal: "Engagement score",
        scoreText: "12 (threshold 10)",
        qualitative: "Strong",
        contributesToMql: true,
        implication:
          "Recent activity is high enough to justify timely outreach while intent is active."
      },
      {
        signal: "Behavior",
        qualitative: "Strong",
        contributesToMql: true,
        implication:
          "Cumulative engagement indicates sustained interest, not a one-off interaction."
      },
      {
        signal: "Inbound request",
        qualitative: "Urgent",
        contributesToMql: true,
        implication:
          "They asked for follow-up directly, so speed-to-contact is critical to preserve momentum."
      }
    ],
    scoreInterpretation: [],
    fit: {
      concerns: [],
      looksGood: true,
      companyTier: "High",
      contactTier: "Medium"
    },
    intent: { strength: "Strong" },
    opportunity: { hasOpenOpportunity: false },
    recentEngagement: [{ date: "2026-02-12", highlight: "Inbound request" }]
  });

  expect(html).not.toContain("Engagement score");
  expect(html).toContain("Fit: Strong.");
  expect(html).toContain("Intent: Strong.");
  expect(html).toContain("Behavior: Strong.");
  expect(html).toContain("Inbound request: Urgent.");
  const v = _internals.validateSalesFacingHtml(html);
  expect(v.ok).toBe(true);
});

test("extractSalesforceIdsFromText finds ids in raw values and URLs", () => {
  expect(_internals.extractSalesforceIdsFromText("A0mjw000003fcw5iac")).toEqual(
    ["A0mjw000003fcw5iac"]
  );
  expect(
    _internals.extractSalesforceIdsFromText(
      "https://erepublic.my.salesforce.com/A0mjw000003fcw5iac"
    )
  ).toEqual(["A0mjw000003fcw5iac"]);
});

test("resolveSalesforceReferenceInfo returns the first resolved label match", () => {
  const resolved = new Map([
    [
      "A0mjw000003fcw5iac",
      { label: "California Public Sector CIO Academy", kind: "record" }
    ]
  ]);
  expect(
    _internals.resolveSalesforceReferenceInfo(
      "https://erepublic.my.salesforce.com/A0mjw000003fcw5iac",
      resolved
    )
  ).toEqual({
    label: "California Public Sector CIO Academy",
    kind: "record"
  });
});

test("buildSalesforceRecordLabel falls back to the object label", () => {
  expect(
    _internals.buildSalesforceRecordLabel({
      record: null,
      fieldNames: ["Name", "Title"],
      fallbackLabel: "Event or Conference"
    })
  ).toBe("Event or Conference");
});

test("deriveRecentConversionSummaryOverride uses resolved event labels for generic portal conversions", () => {
  expect(
    _internals.deriveRecentConversionSummaryOverride({
      contact: {
        HubSpot_Recent_Conversion__c:
          "Event Portal Integration - Clicked Sponsor Link and Logged In",
        HubSpot_Recent_Conversion_Date__c: "2026-04-08"
      },
      hubspotPageHistory: [
        {
          occurredAt: "2026-04-08T16:20:00.000Z",
          resolvedLabel: "EE - Colorado Digital Government Summit 2026",
          resolvedLabelKind: "record"
        }
      ],
      analyticsBehavior: null
    })
  ).toBe(
    'They recently clicked the sponsor link and logged into the event portal for "EE - Colorado Digital Government Summit 2026".'
  );
});

test("deriveRecentConversionSummaryOverride ignores non-specific object fallback labels", () => {
  expect(
    _internals.deriveRecentConversionSummaryOverride({
      contact: {
        HubSpot_Recent_Conversion__c: "Event Portal Integration - Logins",
        HubSpot_Recent_Conversion_Date__c: "2026-04-08"
      },
      hubspotPageHistory: [
        {
          occurredAt: "2026-04-08T16:20:00.000Z",
          resolvedLabel: "Event or Conference",
          resolvedLabelKind: "object"
        }
      ],
      analyticsBehavior: null
    })
  ).toBe(null);
});

test("deterministic sales summary includes threshold-path and fit-evidence explanations", () => {
  const html = _internals.buildDeterministicSalesSummaryHtml({
    thresholdExplanation: {
      matchedRule:
        "Behavior threshold with High company fit and Medium contact fit",
      summary:
        "This record likely qualified through the fit-and-behavior rule because recent activity was strong enough for a high company-fit account and a medium contact-fit profile.",
      companyFitTier: "High",
      contactFitTier: "Medium",
      supportingReasons: [
        "Contact-fit evidence points to their title suggests a marketing-oriented role."
      ]
    },
    fitEvidence: {
      contact: {
        positives: [
          "Their title suggests a marketing-oriented role, which supports contact fit in the scoring guide."
        ]
      },
      company: {
        observations: ["Account industry is recorded as Software."]
      }
    },
    mqlContext: {
      qualificationMode: "threshold",
      explanationDetails: ["Attended pricing webinar"]
    },
    scoreSignals: [],
    scoreInterpretation: [],
    fit: {
      concerns: [],
      looksGood: true,
      companyTier: "High",
      contactTier: "Medium"
    },
    opportunity: { hasOpenOpportunity: false },
    recentEngagement: [{ date: "2026-02-12", highlight: "Inbound request" }]
  });

  expect(html).toContain("Fit: Strong.");
  expect(html).toContain(
    "Qualification source: This appears to be a lead-scoring MQL driven by sustained activity."
  );
  expect(html).toContain(
    "Contact-fit evidence points to their title suggests a marketing-oriented role."
  );
  expect(html).not.toContain("Behavior 22");
  expect(html).toContain(
    "anchor the conversation on the trigger, request, or content interaction that qualified them"
  );
  const v = _internals.validateSalesFacingHtml(html);
  expect(v.ok).toBe(true);
});

test("deterministic sales summary uses business issue, decision, and mutual-plan guidance in next steps", () => {
  const html = _internals.buildDeterministicSalesSummaryHtml({
    productInterest: {
      topProducts: [
        { name: "Navigator", confidence: "High", evidence: ["URL: ..."] }
      ]
    },
    fit: {
      concerns: ["Account eligibility checks are missing or unclear."]
    },
    opportunity: { hasOpenOpportunity: true },
    opportunityContext: {
      companyRecent: {
        hasRecentOpportunities: true
      }
    },
    keyReasons: ["They directly requested follow-up (inbound intent)."],
    scoreInterpretation: [],
    recentEngagement: [{ date: "2026-02-12", highlight: "Inbound request" }]
  });

  expect(html).toContain(
    "confirm the business issue behind the activity, why it matters now, and how they will measure success"
  );
  expect(html).toContain(
    "Identify who else is involved in the decision and who can approve next steps"
  );
  expect(html).toContain(
    "leave the conversation with a mutual next action or meeting on the calendar"
  );
  expect(html).toContain(
    "align outreach to the current opportunity stage and owner"
  );
  const v = _internals.validateSalesFacingHtml(html);
  expect(v.ok).toBe(true);
});

test("deterministic sales summary uses engagement themes in next steps", () => {
  const html = _internals.buildDeterministicSalesSummaryHtml({
    engagementThemes: [
      "procurement and RFP research",
      "cybersecurity events and council programming"
    ],
    fit: { concerns: [] },
    opportunity: { hasOpenOpportunity: false },
    scoreInterpretation: [],
    recentEngagement: [
      {
        date: "2026-03-29",
        highlight: 'Visited the "City Manager Innovation Council" page.'
      }
    ]
  });

  expect(html).toContain(
    "lead with their recent interest in procurement and RFP research and cybersecurity events and council programming"
  );
  expect(html).toContain(
    "verify whether the recent procurement and RFP research and cybersecurity events and council programming activity maps to an active initiative"
  );
  const v = _internals.validateSalesFacingHtml(html);
  expect(v.ok).toBe(true);
});

test("deterministic sales summary uses company context when present", () => {
  const html = _internals.buildDeterministicSalesSummaryHtml({
    companyContext: {
      businessSummary:
        "B2B software company selling procurement workflow tools to enterprise teams.",
      industry: "Software",
      revenueBand: "$100M-$500M",
      budgetRange: "$250k-$500k",
      accountStage: "Active",
      salesStatus: "Prospecting",
      customerFootprint: [
        { product: "DEN", level: "Premium", status: "Active" }
      ],
      contactContext: {
        department: "Revenue Operations",
        interestTopics: ["Procurement", "Market Intelligence"]
      }
    },
    keyReasons: [],
    scoreInterpretation: [],
    fit: { concerns: [] },
    opportunity: { hasOpenOpportunity: false },
    recentEngagement: [{ date: "2026-02-12", highlight: "Campaign touch" }]
  });

  expect(html).toContain("Company background:");
  expect(html).toContain("Existing account footprint suggests");
  expect(html).toContain("<p><strong>Score Interpretation</strong></p>");
  expect(html).toContain(
    "position the outreach against the account&#39;s existing product footprint"
  );
  const v = _internals.validateSalesFacingHtml(html);
  expect(v.ok).toBe(true);
});

test("deterministic sales summary uses recent company opportunity context when present", () => {
  const html = _internals.buildDeterministicSalesSummaryHtml({
    opportunityContext: {
      companyRecent: {
        hasRecentOpportunities: true,
        recentOpportunityCount: 2,
        openOpportunityCount: 1,
        recentStageNames: ["Proposal", "Closed Won"],
        recentProducts: ["Navigator", "Workflow"],
        recentDeals: [
          { name: "Navigator Expansion", stage: "Proposal", status: "Open" },
          { name: "DEN Renewal", stage: "Closed Won", status: "Closed won" }
        ]
      }
    },
    keyReasons: [],
    scoreInterpretation: [],
    fit: { concerns: [] },
    opportunity: { hasOpenOpportunity: false },
    recentEngagement: [{ date: "2026-02-12", highlight: "Campaign touch" }]
  });

  expect(html).toContain(
    "Recent account opportunity history suggests active buying motion"
  );
  expect(html).toContain("recent product focus includes Navigator, Workflow");
  expect(html).toContain("Navigator Expansion - Proposal - Open");
  expect(html).toContain(
    "confirm whether this contact maps to an active or adjacent deal already in play"
  );
  const v = _internals.validateSalesFacingHtml(html);
  expect(v.ok).toBe(true);
});

test("validator rejects obvious field-name leakage and missing headings", () => {
  const bad1 =
    "<p><strong>Why Sales Should Care</strong></p><ul><li>Contact_Fit_Threshold__c = 5</li></ul>";
  const v1 = _internals.validateSalesFacingHtml(bad1);
  expect(v1.ok).toBe(false);
  expect(v1.reasons.join("|")).toContain("field_or_id_leak");

  const bad2 = "<p><strong>Why Sales Should Care</strong></p><p>hello</p>";
  const v2 = _internals.validateSalesFacingHtml(bad2);
  expect(v2.ok).toBe(false);
  expect(v2.reasons.join("|")).toContain(
    "missing_heading:Score Interpretation"
  );
});

test("OpenAI prompt builder embeds only compacted salesNarrativeInput", () => {
  const { user } = _internals.buildOpenAiMessages({
    salesNarrativeInput: {
      product: "Navigator",
      keyReasons: [
        "Recent engagement meets the marketing engagement threshold."
      ],
      recentEngagement: [{ date: "2026-02-12", highlight: "Campaign touch" }]
    }
  });

  expect(user).toContain("Most Recent Engagement");
  expect(user).toContain("newest-first");
  expect(user).toContain("qualification path qualitatively");
  expect(user).toContain("fit attribution is partial");
  expect(user).toContain("current customer footprint");
  expect(user).toContain("department or interest-topic context");
  expect(user).toContain("recent company opportunity history");
  expect(user).toContain("active account motion");
  expect(user).toContain("Do not output more than 4 bullets");
  expect(user).toContain("Prioritize the 4 most decision-useful bullets");
  expect(user).toContain("Business Issue / Value / Power / Plan flow");
  expect(user).toContain("mutual next meeting or checkpoint");
  expect(user).toContain("do not name the framework");
  expect(user).toContain("Do not mention engagement score");
  expect(user).toContain("Do not infer email engagement from analytics alone");
  expect(user).toContain(
    "Do not turn passive saved-search email receipts into engagement bullets"
  );
  expect(user).toContain("If engagement themes are present");
  expect(user).not.toContain("email opens/clicks");

  // Guard against accidental raw field tokens in prompt input.
  expect(user).not.toMatch(/__c\b/);
  expect(user).not.toMatch(/\bHubSpot_/);
});
