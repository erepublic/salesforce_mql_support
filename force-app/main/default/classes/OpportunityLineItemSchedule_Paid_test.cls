@isTest(SeeAllData=true)
public class OpportunityLineItemSchedule_Paid_test {
  static testMethod void test() {
    Test.startTest();

    List<OpportunityLineItemSchedule> updatedList = new List<OpportunityLineItemSchedule>();
    for (OpportunityLineItemSchedule s : [
      SELECT Id, Description, ScheduleDate, LastModifiedDate
      FROM OpportunityLineItemSchedule
      WHERE
        Description LIKE 'SIN%'
        AND Description LIKE '%PAID%'
        AND ScheduleDate = LAST_N_DAYS:90
      ORDER BY Id
      LIMIT 5
    ]) {
      String[] parts = s.Description.split('\\|');
      s.Description = parts[0]; //s.Description.substring(0,9);
      updatedList.add(s);
    }
    update updatedList;

    //  the real test
    OpportunityLineItemSchedule_Paid c = new OpportunityLineItemSchedule_Paid();
    c.markAsPaid();

    Test.stopTest();
  }
}
