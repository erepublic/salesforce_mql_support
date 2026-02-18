trigger Class_Reg_Trigger on Class_Reg__c(after insert) {
  // Salesforce makes it difficult to delete code, so this is the best alternative.
  // This feature is removed via this request: https://erepublic.lightning.force.com/lightning/r/Ticket__c/a0w5Y00000qRCOXQA4/view

  Set<Id> contact_ids = new Set<Id>();
  for (Class_Reg__c pd : Trigger.new) {
    contact_ids.add(pd.Contact__c);
  }

  //   Map<Id, Contact> contacts = new Map<Id, Contact>();
  //   for( Contact c:  [SELECT Id FROM Contact WHERE Id in :contact_ids ] ){
  //     contacts.put(c.Id, c);
  //   }

  //   for( Class_Reg__c pd : Trigger.new ){
  //     Contact c = contacts.get(pd.Contact__c);
  //     if( c != null ) {
  //       Class__c cls = [SELECT Brand__c FROM Class__c WHERE Id = :pd.Class__c];
  //         if(cls.Brand__c == 'CDE')
  //           c.Last_CDE_Class__c = pd.Id;
  //         else if(cls.Brand__c == 'EMERGENCYMGMT')
  //           c.Last_EM_Class__c = pd.Id;
  //         else if(cls.Brand__c == 'GOVERNING')
  //           c.Last_GOV_Class__c = pd.Id;
  //         else //GT , TEchwire etc
  //           c.Last_GT_Class__c = pd.Id;

  //         contacts.put(pd.Contact__c, c);
  //     }

  //  }
  //   update (List<sObject>)contacts.values();

}
