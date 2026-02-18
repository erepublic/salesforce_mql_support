public with sharing class contact_from_role_apexcontroller {
  public static ID contactId = null;
  public static Contact c;

  //public void contact_from_role_apexcontroller(){}

  @AuraEnabled
  public static Job_Role__c getRole(Id roleId) {
    List<Job_Role__c> roles = [
      SELECT
        Id,
        Contact__c,
        Job_Role_Title__c,
        Department__c,
        Job_Role_Organization__c,
        Job_Role_Mailing_Street__c,
        Job_Role_Mailing_Street_2__c,
        Job_Role_Mailing_City__c,
        Job_Role_Mailing_State__c,
        Job_Role_Mailing_Zip_Code__c,
        Job_Role_Email__c,
        Job_Role_Phone_Number__c,
        Job_Role_Phone_Number_Extension__c
      FROM Job_Role__c
      WHERE Id = :roleId
      LIMIT 1
    ];
    if (!roles.isEmpty()) {
      Job_Role__c r = roles[0];
      contactId = r.Contact__c;
      c = [
        SELECT
          Id,
          Name,
          Title,
          Department,
          Company_Name_Holder__c,
          MailingCity,
          MailingState,
          MailingCountry,
          MailingPostalCode,
          MailingStreet,
          Email,
          Phone,
          Phone_Extension__c
        FROM Contact
        WHERE id = :contactId
        LIMIT 1
      ];
      return r;
    }
    return null;
  }

  @AuraEnabled
  public static Contact getContact(Id roleId) {
    if (contactId == null) {
      List<Job_Role__c> roles = [
        SELECT Id, Contact__c
        FROM Job_Role__c
        WHERE Id = :roleId
        LIMIT 1
      ];
      if (!roles.isEmpty()) {
        Job_Role__c r = roles[0];
        contactId = r.Contact__c;
      }
    }

    c = [
      SELECT
        Id,
        Name,
        Title,
        Department,
        Company_Name_Holder__c,
        MailingCity,
        MailingState,
        MailingCountry,
        MailingPostalCode,
        MailingStreet,
        Email,
        Phone,
        Phone_Extension__c
      FROM Contact
      WHERE id = :contactId
      LIMIT 1
    ];
    return c;
  }

  @AuraEnabled
  public static String saveContact(Contact contact) {
    List<Contact> contacts = new List<Contact>();
    contacts.add(contact);

    Database.UpsertResult[] results = Database.upsert(contacts, false);
    if (results[0].isSuccess())
      return 'Success';
    else {
      Database.Error[] errors = results[0].getErrors();
      return errors[0].getMessage();
    }
  }
}
