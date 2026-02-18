/**
 *
 * When Event Contracts are activated, and the event has a reception,
 * we add a corresponding contract to the reception with the number of
 * passes noted in the 'no_of_Reception_Passes__c' field for the corresponding
 * product's Sponsorship Level
 *
 * */
trigger Event_Contract_Trigger on Contract(before insert, before update) {
  List<Contract> contracts = new List<Contract>();
  for (Contract c : Trigger.new) {
    contracts.add(c);
  }
  for (Contract c : contracts) {
    if (
      c.Status == 'Draft' &&
      c.Event__c != null &&
      c.Sponsorship_Level__c != null
    ) {
      List<Product2> prods = [
        SELECT Id, Sponsorship__c, Additional_Pass_Limit__c
        FROM Product2
        WHERE
          EE_Event__c = :c.Event__c
          AND Sponsorship__c = :c.Sponsorship_Level__c
          AND Additional_Pass_Limit__c >= 1
      ];
      if (!prods.isEmpty() && c.Additional_Pass_Limit__c == 0) {
        c.Additional_Pass_Limit__c = prods.get(0).Additional_Pass_Limit__c;
      }
    } else if (
      (c.Status == 'Active' ||
      c.Status == 'Activated' ||
      c.Status == 'Updated') &&
      c.Event__c != null &&
      c.Sponsorship_Level__c != null
    ) {
      List<Product2> prods = [
        SELECT Id, Sponsorship__c, no_of_Reception_Passes__c
        FROM Product2
        WHERE
          EE_Event__c = :c.Event__c
          AND Sponsorship__c = :c.Sponsorship_Level__c
          AND no_of_Reception_Passes__c >= 1
      ];
      if (!prods.isEmpty()) {
        List<Events__c> receptionEvents = [
          SELECT Id
          FROM Events__c
          WHERE Parent_Event__c = :c.Event__c
        ];
        if (!receptionEvents.isEmpty()) {
          for (Events__c recEv : receptionEvents) {
            if (
              [
                  SELECT Id
                  FROM Contract
                  WHERE Event__c = :recEv.Id AND Related_Contract__c = :c.Id
                ]
                .isEmpty()
            ) {
              // reception contract does not yet exist, we clone the main event contract and update with prototype
              Contract newRecContract = c.clone(false, false, false, false);
              newRecContract.Event__c = recEv.Id;
              newRecContract.Event_Passes__c = prods.get(0)
                .no_of_Reception_Passes__c;
              newRecContract.Related_Contract__c = c.Id;
              newRecContract.Status = 'Draft';
              newRecContract.Change_Log__c = '';
              newRecContract.Contact_Role_Changes__c = '';
              newRecContract.Master_Contract__c = false;
              newRecContract.SpecialTerms = 'See main event for event contract.';
              insert newRecContract;
              newRecContract.Status = 'Activated';
              update newRecContract;
            } else {
              // reception contract does exist, update it?
            }
          }
        }
      }
    }
  }
}
