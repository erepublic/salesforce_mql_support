@isTest
public with sharing class Class_Status_Trigger_test {
  public static testMethod void testStatusAndCompletion() {
    Class__c cl = testData.createClass();
    Class_Reg__c st = testData.createStudent(cl.Id);
    System.assertEquals(false, st.Class_Complete__c);
    List<Class_Session__c> sessions = [
      SELECT Id
      FROM Class_Session__c
      WHERE Class__c = :cl.Id
    ];
    for (Class_Session__c cs : sessions) {
      Session_Status__c cst = new Session_Status__c(
        Class_Reg__c = st.Id,
        Class_Session__c = cs.Id,
        Complete_Pct__c = 50.0
      );
      insert cst;
    }
    Class_Reg__c st_status = [
      SELECT Class_Complete__c
      FROM Class_Reg__c
      WHERE Id = :st.Id
    ];
    System.assertEquals(false, st_status.Class_Complete__c);
    List<Session_Status__c> statuses = [
      SELECT Id, Complete_Pct__c
      FROM Session_Status__c
      WHERE Class_Reg__c = :st.Id AND Class_Session__r.Class__c = :cl.Id
    ];
    System.assertEquals(2, statuses.size());
    for (Session_Status__c status : statuses) {
      status.Complete_Pct__c = 100.0;
      update status;
    }
    Class_Reg__c st_status2 = [
      SELECT Class_Complete__c
      FROM Class_Reg__c
      WHERE Id = :st.Id
    ];
    System.assertEquals(true, st_status2.Class_Complete__c);
  }
}
