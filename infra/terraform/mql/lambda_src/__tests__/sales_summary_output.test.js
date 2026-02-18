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
