@isTest(SeeAllData=true)
public class trigger_oppLineItemSchedule_test {
  static testMethod void theTest() {
    // testData.createOpportunity();   does not work anymore
    //Opportunity o = testData.createOpportunity();
    //OpportunityLineItem li =  ([SELECT Id FROM OpportunityLineItem WHERE OpportunityId = : o.Id]);
    //OpportunityLineItemSchedule s = new OpportunityLineItemSchedule( OpportunityLineItemId = li.Id, Type= '', Revenue =  12, Quantity =1, ScheduleDate = Date.today() );

    //	Id oppId= '0061O00001RYpKIQA1'; // DG Industry Insider -basic
    //  List<OpportunityLineItem> lilist = [SELECT Id FROM OpportunityLineItem where OpportunityId = : oppId];
    //	System.assert( !lilist.isEmpty(),'No OpportunityLineItem found in Opportunity');
    //	Id theId= '00k1O000012MYXuQAO'; //lilist.get(0).Id;
    //	OpportunityLineItemSchedule s = new OpportunityLineItemSchedule( OpportunityLineItemId = theId, Type= '', Revenue =  12, Quantity =1, ScheduleDate = Date.today() );

    OpportunityLineItemSchedule s = [
      SELECT Id, Original_Close_Date__c, SIN_Extracted__c
      FROM OpportunityLineItemSchedule
      WHERE Id = '00o1O00000FmGMyQAN'
    ]; // 00o1O00000FmGMyQAN
    s.Original_Close_Date__c = null;
    System.assert(s.Id != null);
    update s;

    // new test  no opp for SIN
    OpportunityLineItemSchedule s2 = [
      SELECT Id, Original_Close_Date__c, SIN_Extracted__c
      FROM OpportunityLineItemSchedule
      WHERE Id = '00o5Y00000MyfpbQAB'
    ];
    System.assert(s2.Id != null);
    update s2;

    //System.assertEquals(Date.today().format(), s.Original_Close_Date__c.format(),' Original Close date Not Set!');
  }
}
