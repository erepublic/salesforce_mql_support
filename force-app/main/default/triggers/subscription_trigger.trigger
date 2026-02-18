/*
 * Michael Tel September 20 2017    Ticket #
 */
trigger subscription_trigger on Subscription__c(after insert) {
  Set<Id> contact_ids = new Set<Id>();
  Set<Id> publication_ids = new Set<Id>();
  for (Subscription__c sub : Trigger.new) {
    contact_ids.add(sub.Subscriber__c);
    if (!publication_ids.contains(sub.Publication__c)) {
      publication_ids.add(sub.Publication__c);
    }
  }

  Map<Id, Contact> contacts = new Map<Id, Contact>();
  for (Contact c : [
    SELECT Id, Topics_Interested_In__c
    FROM Contact
    WHERE Id IN :contact_ids
  ]) {
    contacts.put(c.Id, c);
  }

  Map<Id, Publication__c> publications = new Map<Id, Publication__c>();
  for (Publication__c p : [
    SELECT Id, Contact_Interest_Topics__c
    FROM Publication__c
    WHERE Id IN :publication_ids
  ]) {
    publications.put(p.Id, p);
  }

  // CDE: 'a0Qa000000J4s63EAB'  GOV: a0Qa000000J4q7BEAR   GT: a0Qa000000J4s5tEAB       no more EM: a0Qa000000J4s5yEAB
  for (Subscription__c sub : Trigger.new) {
    Contact c = contacts.get(sub.Subscriber__c);
    if (c != null) {
      if (
        sub.Publication__c != null &&
        publications.get(sub.Publication__c) != null
      ) {
        String topics = publications.get(sub.Publication__c)
          .Contact_Interest_Topics__c;
        if (topics != null) {
          Contact_Interest_Topics.addTopics(c, topics);
        }
      }
    }
    contacts.put(sub.Subscriber__c, c);
  }
  update (List<sObject>) contacts.values();
}
