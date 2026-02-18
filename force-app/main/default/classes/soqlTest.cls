@isTest
public class soqlTest {
  //new_Description__c
  static testMethod void getTickets() {
    List<Ticket__c> t = [
      SELECT Id, Name, Description__c
      FROM Ticket__c
      ORDER BY CreatedDate DESC
      LIMIT 2000
    ];

    for (Ticket__c li : t) {
      String d1 = li.Description__c;
    }
  }
}
