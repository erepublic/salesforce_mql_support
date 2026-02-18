trigger subscription_expiration_before_save on Subscription__c(before insert) {
  for (Subscription__c new_sub : Trigger.new) {
    //select/find "Active" matching subscriptions with same publication name and subscriber
    List<Subscription__c> subscriptions = [
      SELECT Status__c, Publication__c, Subscriber__c
      FROM Subscription__c
      WHERE
        Status__c = 'Active'
        AND Publication__c = :new_sub.Publication__c
        AND Subscriber__c = :new_sub.Subscriber__c
    ];
    //for each of the matches, set the status to "Expired" before saving the new subscription
    for (Subscription__c s : subscriptions) {
      s.Status__c = 'Expired';
      update s;
    }
  }
}
