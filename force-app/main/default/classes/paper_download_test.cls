@isTest
private class paper_download_test {
  static testMethod void myUnitTest() {
    Test.startTest();
    Contact registrant = testData.createContact();
    Paper_Download__c paper = new Paper_Download__c(
      Non_Qual__c = true,
      Registrant__c = registrant.Id,
      Paper__c = testData.createPaper('GOVERNING').Id
    );
    insert paper;

    Paper_Download__c paper2 = new Paper_Download__c(
      Non_Qual__c = true,
      Registrant__c = registrant.Id,
      Paper__c = testData.createPaper('GT').Id
    );
    insert paper2;

    Paper_Download__c paper3 = new Paper_Download__c(
      Non_Qual__c = true,
      Registrant__c = registrant.Id,
      Paper__c = testData.createPaper('CDE').Id
    );
    insert paper3;

    paper.Non_Qual__c = false;
    update paper;
    paper.Non_Qual__c = true;
    update paper;

    delete paper;

    Test.stopTest();
  }
}
