public with sharing class download_transactions {
  public static c2g__codaCashEntry__c c;

  @AuraEnabled
  public static c2g__codaCashEntry__c getCashEntry(Id cashEntryId) {
    System.debug('called cashEntry' + cashEntryId);
    c = [
      SELECT Id, c2g__Type__c, Settlement_Batch_Id__c
      FROM c2g__codaCashEntry__c
      WHERE Id = :cashEntryId
    ];
    System.Debug('Dt' + c);
    return c;
  }
}
