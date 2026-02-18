const rules = require("../product_interest_rules_v1.json");
const {
  extractUrlsFromText,
  sanitizeUrl,
  inferProductInterest,
  buildEvidenceFromSalesLeadWebActivity
} = require("../product_interest");

test("extractUrlsFromText extracts http(s) URLs and strips query/hash", () => {
  const urls = extractUrlsFromText(
    "2/1/2019 15:19 - visit - http://www.govtech.com/navigator/numbers/x.html?email=jane@example.com#frag"
  );
  expect(urls.length).toBe(1);
  expect(urls[0]).toContain("http://www.govtech.com/navigator/numbers/x.html");
  expect(urls[0]).not.toContain("email=jane@example.com");
  expect(urls[0]).not.toContain("#");
});

test("sanitizeUrl returns null for invalid URLs", () => {
  expect(sanitizeUrl("not a url")).toBe(null);
});

test("inferProductInterest matches Navigator from navigator URLs", () => {
  const out = inferProductInterest({
    rulesConfig: rules,
    evidence: [
      {
        kind: "sf_web_activity_url",
        category: "url",
        text: "http://www.govtech.com/navigator/numbers/how-states-spend.html",
        occurredAt: "2019-02-01"
      }
    ]
  });

  const names = (out.topProducts || []).map((p) => p.name);
  expect(names).toContain("Navigator");
});

test("buildEvidenceFromSalesLeadWebActivity extracts multiple URL evidence entries", () => {
  const evidence = buildEvidenceFromSalesLeadWebActivity([
    {
      Lead_Date__c: "2019-02-04",
      Web_Activity_Summary__c:
        "2/1/2019 17:49 - visit - http://www.govtech.com/computing/Digital-States-2018.html\n" +
        "2/1/2019 15:19 - visit - http://www.govtech.com/navigator/numbers/how-states-spend.html\n"
    }
  ]);

  expect(evidence.length).toBeGreaterThan(0);
  expect(evidence.some((e) => String(e.text).includes("govtech.com"))).toBe(
    true
  );
});
