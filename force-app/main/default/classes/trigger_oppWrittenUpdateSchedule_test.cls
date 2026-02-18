@isTest(SeeAllData=true)
public class trigger_oppWrittenUpdateSchedule_test {
  static testMethod void theTest() {
    Opportunity o = testData.createOpportunity();
    OpportunityLineItem li = ([
      SELECT Id
      FROM OpportunityLineItem
      WHERE OpportunityId = :o.Id
      LIMIT 1
    ]);
    OpportunityLineItemSchedule s = new OpportunityLineItemSchedule(
      OpportunityLineItemId = li.Id,
      Type = 'Revenue',
      Revenue = 12,
      ScheduleDate = Date.today()
    );
    insert s;
    o.Written_Stage_CONFIRMED__c = true;
    o.StageName = 'Written';
    update o;
    OpportunityLineItemSchedule olisRes = [
      SELECT Original_Close_Date__c
      FROM OpportunityLineItemSchedule
      WHERE Id = :s.Id
    ];
    Opportunity oppRes = [SELECT CloseDate FROM Opportunity WHERE Id = :o.Id];
    System.assertNotEquals(o.CloseDate, null);
    System.assertEquals(olisRes.Original_Close_Date__c, o.CloseDate);
  }
}
