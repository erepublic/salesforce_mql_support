trigger contact_prevent_dup_email on Contact(before insert, before update) {
  Map<String, Contact> emailMap = new Map<String, Contact>();
  if (Trigger.isInsert) {
    for (Contact c : Trigger.new) {
      if (c.AccountId == null) {
        c.addError('An Account is required');
        continue;
      }
      if (c.Email != null) {
        emailMap.put(c.Email, c);
      }
    }
  } else {
    // update
    for (Contact c : Trigger.new) {
      if (c.AccountId == null) {
        c.addError('An Account is required');
        continue;
      }
      Contact oldContact = Trigger.oldMap.get(c.Id);

      if (c.Email != null && c.Email != oldContact.Email) {
        emailMap.put(c.Email, c);
      }
    }
  }

  for (Contact dup : [
    SELECT Email
    FROM Contact
    WHERE Email IN :emailMap.keySet()
  ]) {
    Contact newContact = emailMap.get(dup.Email);
    if (newContact.Id != dup.Id)
      newContact.Email.addError(
        'A Contact with this email address already exists.' + dup.Email
      );
  }

}
