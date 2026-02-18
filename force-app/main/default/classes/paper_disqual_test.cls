@isTest
public class paper_disqual_test {
  static testMethod void disqualTest() {
    Test.startTest();

    // test that a bad title is disqualified
    Contact disqualRegistrant = testData.createContact(false);
    disqualRegistrant.Title = 'retired';
    insert disqualRegistrant;

    Contact ct = [
      SELECT Title_Filter_Universal_Bad_Title_1__c
      FROM Contact
      WHERE Id = :disqualRegistrant.Id
    ];

    System.assertEquals(true, ct.Title_Filter_Universal_Bad_Title_1__c);

    Paper_Download__c paper = new Paper_Download__c(
      Registrant__c = ct.Id,
      Paper__c = testData.createPaper('GOVTECH').Id
    );
    insert paper;

    Paper_Download__c pdl = [
      SELECT Non_Qual__c
      FROM Paper_Download__c
      WHERE Id = :paper.Id
    ];

    System.assertEquals(true, pdl.Non_Qual__c);

    // test that a foreign email address is disqualified
    Contact disqualRegistrant2 = testData.createContact(false);
    disqualRegistrant2.Email = 'test@something.uk';
    insert disqualRegistrant2;

    Contact ct2 = [
      SELECT Foreign_Domain__c
      FROM Contact
      WHERE Id = :disqualRegistrant2.Id
    ];

    System.assertEquals(true, ct2.Foreign_Domain__c);

    Paper_Download__c paper2 = new Paper_Download__c(
      Registrant__c = disqualRegistrant2.Id,
      Paper__c = testData.createPaper('GOVTECH').Id
    );
    insert paper2;

    Paper_Download__c pdl2 = [
      SELECT Non_Qual__c
      FROM Paper_Download__c
      WHERE Id = :paper2.Id
    ];

    System.assertEquals(true, pdl2.Non_Qual__c);
    Test.stopTest();
  }

  static testMethod void preventDupesTest() {
    Test.startTest();
    Paper__c paper = testData.createPaper('GOVTECH');
    Contact contact = testData.createContact(true);
    Paper_Download__c dl1 = new Paper_Download__c(
      Registrant__c = contact.Id,
      Paper__c = paper.Id
    );
    insert dl1;
    Paper_Download__c dl2 = new Paper_Download__c(
      Registrant__c = contact.Id,
      Paper__c = paper.Id
    );
    insert dl2;
    Paper_Download__c dl2_5 = new Paper_Download__c(
      Registrant__c = contact.Id,
      Paper__c = paper.Id
    );
    insert dl2_5;
    Paper_Download__c qualRes = [
      SELECT Name, Non_Qual__c, Comments__c
      FROM Paper_Download__c
      WHERE Id = :dl1.Id
    ];
    Paper_Download__c disqualRes = [
      SELECT Name, Non_Qual__c, Comments__c
      FROM Paper_Download__c
      WHERE Id = :dl2.Id
    ];
    Paper_Download__c disqualRes2_5 = [
      SELECT Name, Non_Qual__c, Comments__c
      FROM Paper_Download__c
      WHERE Id = :dl2_5.Id
    ];
    System.assertEquals(true, qualRes.Non_Qual__c); // changed
    System.assertEquals(true, disqualRes.Non_Qual__c);
    String comment = 'duplicate ' + qualRes.Name;
    System.assertEquals(comment, disqualRes.Comments__c);
    System.assertEquals(comment, disqualRes2_5.Comments__c);

    Paper__c paper2 = testData.createPaper('GOVTECH');
    paper2.Allow_Duplicates__c = true;
    update paper2;
    Contact contact2 = testData.createContact(true);
    Paper_Download__c dl3 = new Paper_Download__c(
      Registrant__c = contact2.Id,
      Paper__c = paper2.Id
    );
    insert dl3;
    Paper_Download__c dl4 = new Paper_Download__c(
      Registrant__c = contact2.Id,
      Paper__c = paper2.Id
    );
    insert dl4;
    Paper_Download__c qualRes2 = [
      SELECT Name, Non_Qual__c, Comments__c
      FROM Paper_Download__c
      WHERE Id = :dl3.Id
    ];
    Paper_Download__c disqualRes2 = [
      SELECT Name, Non_Qual__c, Comments__c
      FROM Paper_Download__c
      WHERE Id = :dl4.Id
    ];
    System.assertEquals(true, qualRes2.Non_Qual__c); // changed
    System.assertEquals(true, disqualRes2.Non_Qual__c); // changed
    Test.stopTest();
  }
}
