/**
 * After an account is deleted we insert a history record so that external systems
 * using the Account.Id can track down a record that was merged or deleted for
 * whatever reason.
 *
 * Looking up a deleted account by ID example:
 *
 * SELECT Name,
 * Id
 * FROM Account
 * WHERE Id IN (SELECT Account_Reference__c FROM Account_Durable_History__c WHERE Account_Deleted_Id__c IN ('00314000029M6qn'))
 *
 * */
trigger Account_After_Delete on Account(after delete) {
  for (Account act : Trigger.old) {
    Account_Durable_History__c act_hist = new Account_Durable_History__c(
      Account_Deleted_Id__c = String.valueOf(act.Id).substring(0, 15)
    );
    if (act.MasterRecordId != null && act.MasterRecordId != act.Id) {
      act_hist.Account_Reference__c = act.MasterRecordId;
    }
    insert act_hist;
  }
}
