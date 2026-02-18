/**
  this is a simple class just to start a batch process 
*/
global with sharing class ef3_batchLoader {
  @AuraEnabled
  webService static String load(String theClass, String theParams) {
    Id batchInstanceId = Database.executeBatch(
      new ef3_batchRegistrationInvoice((Id) theParams),
      50
    );
    return 'SUCCESS'; //:  batch process started for: ' + theClass ;
  }
}
