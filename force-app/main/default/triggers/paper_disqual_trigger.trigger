// Custom fields on the Contact object automatically disqualify downloads. Ticket #15751
// tested by paper_disqual_test
trigger paper_disqual_trigger on Paper_Download__c(before insert) {
  Set<Id> contact_ids = new Set<Id>();
  Set<Id> paper_ids = new Set<Id>();
  Map<Id, Paper_Download__c> m = new Map<Id, Paper_Download__c>();
  for (Paper_Download__c pd : Trigger.new) {
    contact_ids.add(pd.Registrant__c);
    paper_ids.add(pd.Paper__c);
  }
  Set<string> contact_emails = new Set<string>();
  if (contact_ids.size() > 0) {
    for (Contact ct : [
      SELECT Id, Email, Title_Filter_Universal_Bad_Title_1__c, Foreign_Domain__c
      FROM Contact
      WHERE Id IN :contact_ids
    ]) {
      contact_emails.add(ct.Email);
      if (ct.Title_Filter_Universal_Bad_Title_1__c || ct.Foreign_Domain__c) {
        for (Paper_Download__c pd : Trigger.new) {
          if (pd.Registrant__c == ct.Id) {
            pd.Non_Qual__c = true;
          }
        }
      }
    }
    for (Paper_Download__c pdl : [
      SELECT
        Id,
        Name,
        Registrant__r.Email,
        Registrant__r.Id,
        Paper__c,
        Registrant__c
      FROM Paper_Download__c
      WHERE
        Registrant__r.Email IN :contact_emails
        AND Paper__c IN :paper_ids
        AND Paper__r.Allow_Duplicates__c != TRUE
      ORDER BY Id DESC
    ]) {
      for (Paper_Download__c pd : Trigger.new) {
        if (
          pdl.Registrant__r.Id == pd.Registrant__c &&
          pd.Paper__c == pdl.Paper__c
        ) {
          pd.Non_Qual__c = true;
          String comment = 'duplicate ' + pdl.Name;
          pd.Comments__c = comment;
        }
      }
    }
  }

}
