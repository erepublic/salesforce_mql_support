public with sharing class SubmitWebTicketController {
  // test https://erepublic--michaels2.lightning.force.com/apex/submit_web_ticket

  public Ticket__c ticket {
    get {
      return ticket;
    }
    set;
  }

  public Ticket__c getTheDarnTicket() {
    return ticket;
  }

  public SubmitWebTicketController() {
    this.ticket = new Ticket__c(RecordTypeId = '01230000001R3Yk'); // RecordType: WEB
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

  public List<selectOption> getDevelopers() {
    List<selectOption> options = new List<selectOption>();
    options.add(new selectOption('', ''));
    for (User users : [
      SELECT Id, Name
      FROM User
      WHERE Department = 'IT' AND isActive = TRUE
      ORDER BY FirstName
    ]) {
      options.add(new selectOption(users.Id, users.Name));
    }
    return options;
  }

  // check form
  public PageReference checkForm() {
    ticket.OwnerId = UserInfo.getUserId();
    ticket.CreatedById = UserInfo.getUserId();
    insert ticket;
    //String r = Url.getSalesforceBaseUrl()+''+ticket.id;    getOrgDomainURL()  or getCurrentRequestURL()
    //String r = URL.getSalesforceBaseUrl().toExternalForm() + '/' + ticket.id;
    String r = URL.getOrgDomainURL().toExternalForm() + '/' + ticket.id;
    PageReference pageRef = new PageReference(r);
    pageRef.setRedirect(true);
    return pageRef;
  }
}
