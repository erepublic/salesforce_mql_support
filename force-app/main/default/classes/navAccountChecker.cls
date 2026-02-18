global class navAccountChecker implements Schedulable {
  // global with sharing
  // this class will run every night and will set the account status to "renewal" or "expired" if necessary

  /*
    // run the following code in the "execute Anonymous" window to sceedule this app to run every night at 4 am
    	navAccountChecker m = new navAccountChecker();
		String sch = '0 0 4 * * ?';
		system.schedule('Navigator Contract Expiration Check', sch, m);

    // for testing:
    navAccountChecker m = new navAccountChecker();  m.checkAccounts();   
*/

  global void execute(SchedulableContext SC) {
    checkAccounts();
  }

  @TestVisible
  private void sendEmail(Account a, String theChange, String theType) {
    String[] toAddresses = new List<String>{
      'memberservices@centerdigitalgov.com'
    };
    String[] ccAddresses = new List<String>{ 'mtel@erepublic.com' };
    User rep;
    try {
      if (theType == 'DGN')
        rep = [
          SELECT Id, IsActive, Email
          FROM user
          WHERE Id = :a.DGN_Account_Rep__c
        ];
      else if (theType == 'DEN')
        rep = [
          SELECT Id, IsActive, Email
          FROM user
          WHERE Id = :a.DEN_Account_Rep__c
        ];
      else if (theType == 'EMN')
        rep = [
          SELECT Id, IsActive, Email
          FROM user
          WHERE Id = :a.EMN_Account_Rep__c
        ];
      if (rep.Email != '') {
        toAddresses = new List<String>{ rep.Email };
        ccAddresses = new List<String>{
          'memberservices@centerdigitalgov.com',
          'mtel@erepublic.com'
        };
      }
    } catch (Exception e) {
    }

    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();

    mail.setSubject('Account ' + theChange);

    mail.setToAddresses(toAddresses);
    mail.setCcAddresses(ccAddresses);
    //mail.setBccSender(false);
    //mail.setUseSignature(false);
    mail.setSenderDisplayName('Salesforce AutoJob');
    mail.setReplyTo('noreply@navigatorgov.com');

    String bodyText =
      'The ' +
      theType +
      ' Account status for: ' +
      a.Name +
      ' has changed to: ' +
      theChange;

    if (theChange == 'Renewal') {
      Date dueDate = date.today();
      dueDate = dueDate.addDays(7);

      if (rep != null && rep.IsActive) {
        Task task = new Task();
        task.OwnerId = rep.Id;
        //task.Account = a;
        task.Description =
          'Navigator contract for ' +
          a.Name +
          ' is almost expired, need to renew';
        task.Subject = 'Navigator Renewal';
        task.status = 'Not Started';
        task.ActivityDate = dueDate;

        insert task;
      }
      bodyText =
        bodyText +
        ' has changed to: ' +
        theChange +
        ' <br> A task has been created for you';
    }

    mail.setPlainTextBody(bodyText);
    Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
  }

  global void checkAccounts() {
    Integer counter = 0;
    ID accId;
    for (Account a : [
      SELECT
        a.Id,
        a.Name,
        a.Navigator_Trial_Expiration__pc,
        a.DGN_Contract_Status__c,
        a.DGN_Contract_Expiration__c,
        DGN_Account_Rep__c
      FROM Account a
      WHERE
        DGN_Contract_Status__c = 'Active'
        OR DGN_Contract_Status__c = 'Renewal'
    ]) {
      String theChange = '';

      Date RenewalDate = date.today();
      RenewalDate = RenewalDate.addDays(75);
      if (
        a.DGN_Contract_Status__c == 'Active' &&
        a.DGN_Contract_Expiration__c < RenewalDate
      ) {
        a.DGN_Contract_Status__c = 'Renewal';
        theChange = 'Renewal';
      }

      if (a.DGN_Contract_Expiration__c < date.today()) {
        a.DGN_Contract_Status__c = 'Expired';
        theChange = 'Expired';
      }

      if (theChange != '' && counter < 2) {
        counter += 1;
        System.debug('counter= ' + counter);
        sendEmail(a, theChange, 'DGN');

        update a;
      }
    }

    for (Account a : [
      SELECT
        a.Id,
        a.Name,
        a.Navigator_Trial_Expiration__pc,
        a.DEN_Contract_Status__c,
        a.DEN_Contract_Expiration__c,
        DEN_Account_Rep__c
      FROM Account a
      WHERE
        DEN_Contract_Status__c = 'Active'
        OR DEN_Contract_Status__c = 'Renewal'
    ]) {
      String theChange = '';

      Date RenewalDate = date.today();
      RenewalDate = RenewalDate.addDays(75);
      if (
        a.DEN_Contract_Status__c == 'Active' &&
        a.DEN_Contract_Expiration__c < RenewalDate
      ) {
        a.DEN_Contract_Status__c = 'Renewal';
        theChange = 'Renewal';
      }

      if (a.DEN_Contract_Expiration__c < date.today()) {
        a.DEN_Contract_Status__c = 'Expired';
        theChange = 'Expired';
      }

      if (theChange != '' && counter < 2) {
        counter += 1;
        System.debug('counter= ' + counter);
        sendEmail(a, theChange, 'DEN');
        update a;
      }
    }

    for (Account a : [
      SELECT
        a.Id,
        a.Name,
        a.Navigator_Trial_Expiration__pc,
        a.EMN_Contract_Status__c,
        a.EMN_Contract_Expiration__c,
        EMN_Account_Rep__c
      FROM Account a
      WHERE
        EMN_Contract_Status__c = 'Active'
        OR EMN_Contract_Status__c = 'Renewal'
    ]) {
      String theChange = '';

      Date RenewalDate = date.today();
      RenewalDate = RenewalDate.addDays(75);
      if (
        a.EMN_Contract_Status__c == 'Active' &&
        a.EMN_Contract_Expiration__c < RenewalDate
      ) {
        a.EMN_Contract_Status__c = 'Renewal';
        theChange = 'Renewal';
      }

      if (a.EMN_Contract_Expiration__c < date.today()) {
        a.EMN_Contract_Status__c = 'Expired';
        theChange = 'Expired';
      }

      if (theChange != '' && counter < 2) {
        counter += 1;
        System.debug('counter= ' + counter);
        sendEmail(a, theChange, 'EMN');
        update a;
      }
    }
  }
}
