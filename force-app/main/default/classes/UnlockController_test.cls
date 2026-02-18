@isTest(seeAllData=true)
public class UnlockController_test {
  static testMethod void test_with_SIN() {
    try {
      Opportunity o = testData.createOpportunity();

      Date scheduleDate = Date.today();

      String[] descr = new List<String>{
        'SIN3042',
        'SIN3015 ',
        'SIN3745 ',
        'SIN3005 ',
        'SIN3085 ',
        'SIN3045'
      };
      Integer i = 0;
      for (OpportunityLineItem product : [
        SELECT Id, TotalPrice
        FROM OpportunityLineItem
        WHERE OpportunityId = :o.Id
      ]) {
        // create a schedule for this lineitem
        OpportunityLineItemSchedule s = new OpportunityLineItemSchedule();
        s.OpportunityLineItemId = product.Id;
        s.Revenue = product.TotalPrice;
        s.Type = 'Revenue';
        s.ScheduleDate = scheduleDate;
        s.Description = descr[i++];
        insert s;
      }
      System.debug('opportunityId Test' + o.Id);

      ApexPages.currentPage().getParameters().put('id', o.id);
      ApexPages.StandardController sc = new ApexPages.StandardController(o);
      UnlockController unlockControllerObj = new UnlockController(sc); //Instantiate the Class

      unlockControllerObj.unlockOpportunity(); //Call the Method
      Opportunity opptest = [
        SELECT Id, RecordTypeId
        FROM Opportunity
        WHERE Id = :o.id
      ];
      System.AssertNotEquals('01214000001CDhm', o.RecordTypeId);
      System.assertEquals(
        'One or more products on this opportunity have been invoiced. Please submit \'Unlock Opp Request\'.',
        unlockControllerObj.message
      );
    } catch (Exception e) {
      system.debug('exception' + ' ' + e.getMessage());
    }
  }

  static testMethod void test_without_SIN() {
    try {
      Opportunity o = testData.createOpportunity();

      Date scheduleDate = Date.today();

      String[] descr = new List<String>{
        ' ',
        'CC ',
        'CHECK ',
        'ACH ',
        'testing '
      };
      Integer i = 0;
      for (OpportunityLineItem product : [
        SELECT Id, TotalPrice
        FROM OpportunityLineItem
        WHERE OpportunityId = :o.Id
      ]) {
        // create a schedule for this lineitem
        OpportunityLineItemSchedule s = new OpportunityLineItemSchedule();
        s.OpportunityLineItemId = product.Id;
        s.Revenue = product.TotalPrice;
        s.Type = 'Revenue';
        s.ScheduleDate = scheduleDate;
        s.Description = descr[i++];
        insert s;
      }

      // loop through the code
      ApexPages.currentPage().getParameters().put('id', o.id);
      ApexPages.StandardController sc = new ApexPages.StandardController(o);
      UnlockController unlockControllerObj = new UnlockController(sc); //Instantiate the Class

      PageReference pg = unlockControllerObj.unlockOpportunity(); //Call the Method
      Opportunity opptest = [
        SELECT Id, RecordTypeId
        FROM Opportunity
        WHERE Id = :o.id
      ];
      System.assertEquals('01214000001CDhm', opptest.RecordTypeId);
      System.assertEquals(
        'Opportunity is unlocked',
        unlockControllerObj.message
      );
      System.assertEquals(null, pg);
    } catch (Exception e) {
      system.debug('exception' + ' ' + e.getMessage());
    }
  }
}
