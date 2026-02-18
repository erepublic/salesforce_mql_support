public with sharing class ticket_buttons_apexcontroller {
  @AuraEnabled
  public static void close_ticket(Id recordId) {
    Ticket__c ticket = [
      SELECT Id, Name, Phase__c
      FROM Ticket__c
      WHERE Id = :recordId
      LIMIT 1
    ];
    ticket.Phase__c = 'Closed';
    update ticket;
  }
}
