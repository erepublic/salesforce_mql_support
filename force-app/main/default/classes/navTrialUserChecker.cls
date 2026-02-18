global class navTrialUserChecker implements Schedulable {
  // this class will run every night and will set the account status to "renewal" or "expired" if necessary

  /*
    // run the following code in the "execute Anonymous" window to sceedule this app to run every night at 4 am
    navTrialUserChecker m = new navTrialUserChecker();
    String sch = '0 0 5 * * ?';
    system.schedule('Navigator Trial Users Expiration Check', sch, m);

    // for testing:
    navTrialUserChecker m = new navTrialUserChecker();  m.checkContacts();
  */
  // Emailer theEmailer = new Emailer();

  /*
  public static testMethod void myTest() {
    Test.startTest();
    navTrialUserChecker c = new navTrialUserChecker();
    c.checkContacts();
    Test.stopTest();
  }
  */

  global void execute(SchedulableContext SC) {
    checkContacts();
  }

  global void checkContacts() {
    List<Contact> uc = new List<Contact>();
    System.debug('navTrialUserChecker: checkContacts()');
    // Select Navigator_Trial_Status__c, c.Navigator_Trial_Expiration__c From Contact c WHERE Navigator_Trial_Expiration__c < TODAY AND Navigator_Trial_Status__c = 'Expired' AND Navigator_Trial_Status__c != 'none' LIMIT 100
    for (Contact c : [
      SELECT Navigator_Trial_Status__c, c.Navigator_Trial_Expiration__c
      FROM Contact c
      WHERE
        Navigator_Trial_Status__c = 'In Progress'
        AND Navigator_Trial_Expiration__c < TODAY
      LIMIT 100
    ]) {
      System.debug('Contact loop: ' + c);
      // change status to Expired, this will trigger the trigger that will call the navigator
      c.Navigator_Trial_Status__c = 'Expired';
      uc.add(c);
    }
    update uc;
  }
}
