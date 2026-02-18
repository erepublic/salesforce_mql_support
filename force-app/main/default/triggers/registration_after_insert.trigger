trigger registration_after_insert on Registration__c(after insert) {
  String ids = '';
  Map<String, ID> id_map = new Map<String, ID>();
  Set<Id> contact_ids = new Set<Id>();
  Set<Id> event_ids = new Set<Id>();
  for (Registration__c reg : Trigger.new) {
    if (!ids.contains(reg.Id)) {
      ids += ',' + reg.Id;
    }

    if (!String.isBlank(reg.Temporary_Id__c)) {
      id_map.put(reg.Temporary_Id__c, reg.Id);
    }
    if (!String.isBlank(reg.Registrant_Name__c)) {
      if (!contact_ids.contains(reg.Registrant_Name__c)) {
        contact_ids.add(reg.Registrant_Name__c);
      }
      if (!event_ids.contains(reg.Event__c)) {
        event_ids.add(reg.Event__c);
      }
    }
  }
  if (ids.length() > 0 && !UserInfo.getUserId().contains('005a000000B8cGM'))
    oneFormConnector.makeTheCall(
      ids.substring(1),
      'download_event_registration'
    );

  if (!id_map.isEmpty()) {
    List<QR_Scan__c> scans = new List<QR_Scan__c>();
    for (QR_Scan__c s : [
      SELECT Tmp_Scanned_Id__c, Tmp_Scanner_Id__c, Scanned__c, Scanner__c
      FROM QR_Scan__c
      WHERE
        Tmp_Scanned_Id__c IN :id_map.keySet()
        OR Tmp_Scanner_Id__c IN :id_map.keySet()
    ]) {
      if (
        !String.isBlank(s.Tmp_Scanned_Id__c) &&
        id_map.containsKey(s.Tmp_Scanned_Id__c)
      ) {
        s.Scanned__c = id_map.get(s.Tmp_Scanned_Id__c);
        if (!scans.contains(s))
          scans.add(s);
      }
      if (
        !String.isBlank(s.Tmp_Scanner_Id__c) &&
        id_map.containsKey(s.Tmp_Scanner_Id__c)
      ) {
        s.Scanner__c = id_map.get(s.Tmp_Scanner_Id__c);
        if (!scans.contains(s))
          scans.add(s);
      }
    }

    if (!scans.isEmpty())
      update scans;
  }

  Map<Id, Contact> contacts = new Map<Id, Contact>();
  for (Contact c : [
    SELECT Id, Topics_Interested_In__c
    FROM Contact
    WHERE Id IN :contact_ids
  ]) {
    contacts.put(c.Id, c);
  }

  Map<Id, Events__c> events = new Map<Id, Events__c>();
  for (Events__c p : [
    SELECT Id, Contact_Interest_Topics__c
    FROM Events__c
    WHERE Id IN :event_ids
  ]) {
    events.put(p.Id, p);
  }

  List<Contact> contacts_to_update = new List<Contact>();
  for (Registration__c reg : Trigger.new) {
    Contact c = contacts.get(reg.Registrant_Name__c);
    Events__c event = events.get(reg.Event__c);
    if (c != null && event != null) {
      Contact_Interest_Topics.addTopics(c, event.Contact_Interest_Topics__c);
      contacts_to_update.add(c);
    }
  }
  update contacts_to_update;
}
