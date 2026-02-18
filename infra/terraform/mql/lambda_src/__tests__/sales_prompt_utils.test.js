const {
  buildSalesNarrativeInput,
  buildSalesEventLabel
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
    }
  });

  const s = JSON.stringify(out);
  expect(s).not.toMatch(/__c\b/);
  expect(s).not.toMatch(/HubSpot_/);
  expect(s).not.toMatch(/OpportunityContactRole/);
  expect(s).not.toMatch(/MQL__c/);
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
