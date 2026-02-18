public with sharing class SubmitRFPTicketController {
  public Ticket__c ticket {
    get {
      return ticket;
    }
    set;
  }

  public Ticket__c getTheRFPTicket() {
    return ticket;
  }

  public SubmitRFPTicketController() {
    this.ticket = new Ticket__c(RecordTypeId = '0121O000001lsssQAA'); // RecordType: RFP
  }

  // Debug code
  public String getUser() {
    //return [SELECT Id, Username, CompanyName FROM User WHERE CompanyName = 'e.Republic, Inc.' ORDER BY FirstName];
    return UserInfo.getName();
  }

  // Get e.republic users
  public List<selectOption> getErepublicUsers() {
    List<selectOption> options = new List<selectOption>();
    options.add(new selectOption(UserInfo.getUserId(), UserInfo.getName())); // set user as default pick
    return options;
  }

  public List<selectOption> getRFPAssignee() {
    List<selectOption> options = new List<selectOption>();
    for (User users : [
      SELECT Id, Name
      FROM User
      WHERE
        NAME IN (
          'Adam Fowler',
          'Zach Presnall',
          'Jeff Fahndrich',
          'Anthony Yanez'
        )
        AND isActive = TRUE
      ORDER BY FirstName
    ]) {
      options.add(new selectOption(users.Id, users.Name));
    }
    return options;
  }

  public List<selectOption> getAccount() {
    List<selectOption> options = new List<selectOption>();
    for (Account acc : [SELECT Id, Name FROM Account LIMIT 1000]) {
      options.add(new selectOption(acc.Id, acc.Name));
    }
    return options;
  }

  // check form
  public PageReference checkForm() {
    ticket.OwnerId = UserInfo.getUserId();
    ticket.CreatedById = UserInfo.getUserId();
    insert ticket;
    //String r = Url.getSalesforceBaseUrl()+''+ticket.id;
    String r = URL.getSalesforceBaseUrl().toExternalForm() + '/' + ticket.id;
    PageReference pageRef = new PageReference(r);
    pageRef.setRedirect(true);
    return pageRef;
  }
}
