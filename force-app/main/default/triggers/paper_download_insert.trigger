trigger paper_download_insert on Paper_Download__c(before insert) {
  Set<Id> contact_ids = new Set<Id>();
  Set<Id> paper_ids = new Set<Id>();

  for (Paper_Download__c pd : Trigger.new) {
    contact_ids.add(pd.Registrant__c);
    paper_ids.add(pd.Paper__c);
  }

  Map<Id, Contact> contacts = new Map<Id, Contact>();
  for (Contact c : [
    SELECT Id, Topics_Interested_In__c
    FROM Contact
    WHERE Id IN :contact_ids
  ]) {
    contacts.put(c.Id, c);
  }

  Map<Id, Paper__c> papers = new Map<Id, Paper__c>();
  for (Paper__c p : [
    SELECT Id, Contact_Interest_Topics__c
    FROM Paper__c
    WHERE Id IN :paper_ids
  ]) {
    papers.put(p.Id, p);
  }

  for (Paper_Download__c pd : Trigger.new) {
    Contact c = contacts.get(pd.Registrant__c);

    Contact_Interest_Topics.addTopics(
      c,
      papers.get(pd.Paper__c).Contact_Interest_Topics__c
    );
    pd.Paper_Contact_Interest_Topics__c = papers.get(pd.Paper__c)
      .Contact_Interest_Topics__c;
    contacts.put(pd.Registrant__c, c);
  }
  update (List<sObject>) contacts.values();
}
