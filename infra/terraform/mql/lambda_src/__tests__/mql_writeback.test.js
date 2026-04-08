const { _internals } = require("../index.js");

describe("buildMqlSummaryUpdatePayload", () => {
  afterEach(() => {
    jest.useRealTimers();
  });

  test("stamps the initial alert datetime when the field exists and is blank", () => {
    jest.useFakeTimers();
    jest.setSystemTime(new Date("2026-04-07T17:15:00.000Z"));

    const payload = _internals.buildMqlSummaryUpdatePayload({
      summaryHtml: "<p>Summary</p>",
      mql: {
        Id: "a0Xxx0000000001",
        Initial_MQL_Alert_Send__c: null
      }
    });

    expect(payload).toEqual({
      Engagement_AI_Summary__c: "<p>Summary</p>",
      Initial_MQL_Alert_Send__c: "2026-04-07T17:15:00.000Z"
    });
  });

  test("does not restamp the initial alert datetime after it is already set", () => {
    const payload = _internals.buildMqlSummaryUpdatePayload({
      summaryHtml: "<p>Summary</p>",
      mql: {
        Id: "a0Xxx0000000001",
        Initial_MQL_Alert_Send__c: "2026-04-07T17:00:00.000Z"
      }
    });

    expect(payload).toEqual({
      Engagement_AI_Summary__c: "<p>Summary</p>"
    });
  });

  test("skips the alert field when the org has not deployed it yet", () => {
    const payload = _internals.buildMqlSummaryUpdatePayload({
      summaryHtml: "<p>Summary</p>",
      mql: {
        Id: "a0Xxx0000000001"
      }
    });

    expect(payload).toEqual({
      Engagement_AI_Summary__c: "<p>Summary</p>"
    });
  });
});
