public with sharing class Account_Controller {
  @AuraEnabled
  public static string getAccountNote(Id accountId) {
    Account act = [
      SELECT Id, Account_Priority_Notes__c
      FROM Account
      WHERE Id = :accountId
    ];
    return act.Account_Priority_Notes__c;
  }

  @AuraEnabled
  public static string saveAccountNote(
    Id accountId,
    String Account_Priority_Notes,
    String initialValue
  ) {
    Account act = [
      SELECT Id, Account_Priority_Notes__c
      FROM Account
      WHERE Id = :accountId
    ];
    if (act.Account_Priority_Notes__c != initialValue) {
      AuraHandledException e = new AuraHandledException(
        'The note changed while you were editing it. It cannot be saved without losing data.'
      );
      e.setMessage('prevented overwriting a note');
      throw e;
    } else {
      act.Account_Priority_Notes__c = Account_Priority_Notes;
      update act;
    }
    return 'success';
  }
}
