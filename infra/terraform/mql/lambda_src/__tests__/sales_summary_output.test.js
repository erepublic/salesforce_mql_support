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

  // Score Interpretation max=6
  const scoreBlock = out.split(
    "<p><strong>Score Interpretation</strong></p>"
  )[1];
  expect((scoreBlock.match(/<li>/g) || []).length).toBeGreaterThan(0);
  const firstScoreUl =
    (scoreBlock.match(/<ul>([\s\S]*?)<\/ul>/i) || [])[1] || "";
  expect((firstScoreUl.match(/<li>/g) || []).length).toBe(6);
  expect(scoreBlock).not.toContain("<li>G</li>");

  // Suggested Next Step max=2
  const nextBlock = out.split("<p><strong>Suggested Next Step</strong></p>")[1];
  expect((nextBlock.match(/<li>/g) || []).length).toBe(2);
  expect(nextBlock).not.toContain("<li>C</li>");
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

test("deterministic sales summary renders qualifying score signals with numeric and value framing", () => {
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
        signal: "Inbound request",
        qualitative: "Urgent",
        contributesToMql: true,
        implication:
          "They asked for follow-up directly, so speed-to-contact is critical to preserve momentum."
      }
    ],
    scoreInterpretation: [],
    fit: { concerns: [] },
    opportunity: { hasOpenOpportunity: false },
    recentEngagement: [{ date: "2026-02-12", highlight: "Inbound request" }]
  });

  expect(html).toContain("Engagement score: Score 12 (threshold 10); Strong.");
  expect(html).toContain("Inbound request: Urgent.");
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

  // Guard against accidental raw field tokens in prompt input.
  expect(user).not.toMatch(/__c\b/);
  expect(user).not.toMatch(/\bHubSpot_/);
});
