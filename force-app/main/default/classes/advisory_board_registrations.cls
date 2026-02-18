global class advisory_board_registrations {
  /* called from a button
   * creates or updates an event registration for each adboard member
   * and launches a flow to send an email to the Reg Coordinator
   */
  @AuraEnabled
  webService static String createRegistrations(Id eventId) {
    integer regUpdated = 0;
    integer regCreated = 0;

    //LIST<Id> memberIds =  new LIST<Id>();
    SET<Id> memberIdsSet = new Set<Id>(); // use a set so we can remove items
    SET<Id> industryIdsSet = new Set<Id>(); // use a set so we can search for ids
    LIST<Advisory_Board_Member__c> ABmembers = Database.query(
      'SELECT Contact__r.Id , Contact__r.AB_Type__c FROM Advisory_Board_Member__c WHERE Event__c = :eventId '
    );
    for (Advisory_Board_Member__c a : ABmembers) {
      memberIdsSet.add(a.Contact__r.Id);
      if (a.Contact__r.AB_Type__c == 'Industry')
        industryIdsSet.add(a.Contact__r.Id);
    }

    // get existing registrations
    LIST<Registration__c> existingRegistrations = Database.query(
      'SELECT Id, Registrant_Name__r.Id, Reg_Advisory_Board__c FROM Registration__c WHERE  Event__c = :eventId  AND Registrant_Name__r.Id IN :memberIdsSet '
    );

    if (!existingRegistrations.isEmpty()) {
      // loop through them, update them and remove the id from the list
      for (Registration__c reg : existingRegistrations) {
        reg.Reg_Advisory_Board__c = true;
        memberIdsSet.remove(reg.Registrant_Name__r.Id);
        //system.debug('update: '+reg.Registrant_Name__r.Id );
        regUpdated++;
      }
      update existingRegistrations;
    }
    if (!memberIdsSet.isEmpty()) {
      // if there are still ids in the set
      // create an registration for each member still on the list
      LIST<Registration__c> newRegistrations = new List<Registration__c>();

      for (Id id : memberIdsSet) {
        String rtype = industryIdsSet.contains(id)
          ? 'Sponsor'
          : 'Govt Attendee';
        Registration__c newReg = new Registration__c(
          Reg_Advisory_Board__c = true,
          Event__c = eventId,
          Registrant_Name__c = id,
          Reg_Date__c = Date.today(),
          Reg_Source__c = 'T Team Spreadsheet',
          Reg_Type__c = rtype //'Govt Attendee'  // or 'Sponsor'
        );
        if (rtype == 'Sponsor')
          newReg.Non_Qual__c = true;

        regCreated++;
        newRegistrations.add(newReg);
      }
      insert newRegistrations;

      // Only call the flow to send an email if registrations were created
      if (regCreated > 0) {
        // Create a map to pass the event ID and registration counts to the flow
        Map<String, Object> flowInputs = new Map<String, Object>();
        flowInputs.put('var_Event_Id', eventId);
        flowInputs.put('var_Registrations_Created', regCreated);

        // Invoke the flow
        Flow.Interview.Event_or_Conference_AL_ADBD_Registered_Email_Alert flow = new Flow.Interview.Event_or_Conference_AL_ADBD_Registered_Email_Alert(
          flowInputs
        );
        flow.start();
      }
    }

    return ' ' +
      regUpdated +
      ' registrations updated, \n' +
      regCreated +
      ' registrations created';
  }
}
