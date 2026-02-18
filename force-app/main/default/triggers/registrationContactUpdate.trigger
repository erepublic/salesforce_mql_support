/*
create by Justin Osterholt.
Updated by Michael Tel to make it work with bulk updates
*/

trigger registrationContactUpdate on Registration__c(after insert) {
  //Contact contacts = [Select EE_Tracking_Interested__c, EE_Tracking_Past_Participant__c FROM Contact Where Id = :registration_ids];
  //Events__c events = [Select Venue_State__c From Events__c WHERE Id = :event_ids];

  List<Contact> rlist = new List<Contact>();
  for (Registration__c reg : [
    SELECT
      Id,
      Name,
      Event__r.Id,
      Event__r.Venue_State__c,
      Brand__c,
      Registrant_Name__r.EE_Tracking_Interested__c,
      Registrant_Name__r.EE_Tracking_Past_Participant__c
    FROM Registration__c
    WHERE Id IN :Trigger.new
  ]) {
    if (reg.Event__r != null && reg.Registrant_Name__r != null) {
      Events__c event = reg.Event__r;
      Contact c = reg.Registrant_Name__r;
      if (event.Venue_State__c != null) {
        if (c.EE_Tracking_Interested__c == null) {
          c.EE_Tracking_Interested__c = event.Venue_State__c;
        } else if (
          !c.EE_Tracking_Interested__c.contains(event.Venue_State__c)
        ) {
          c.EE_Tracking_Interested__c += ';' + event.Venue_State__c;
        }

        if (c.EE_Tracking_Past_Participant__c == null) {
          c.EE_Tracking_Past_Participant__c = event.Venue_State__c;
        } else if (
          !c.EE_Tracking_Past_Participant__c.contains(event.Venue_State__c)
        ) {
          c.EE_Tracking_Past_Participant__c += ';' + event.Venue_State__c;
        }
      }
      rlist.add(c);
    }
  }
  if (!rlist.isEmpty()) {
    update rlist;
  }
}
