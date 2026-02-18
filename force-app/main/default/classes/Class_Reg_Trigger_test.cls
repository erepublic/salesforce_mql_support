@isTest
public with sharing class Class_Reg_Trigger_test {
  static testMethod void myUnitTest() {
    Test.startTest();
    Contact registrant = testData.createContact();
    Class_Reg__c class1 = new Class_Reg__c(
      Non_Qual__c = true,
      Contact__c = registrant.Id,
      Class__c = testData.createClassWithBrand('GOVERNING').Id
    );
    insert class1;
    // Class__c cl1r = [SELECT Brand__c FROM Class__c WHERE Id = :class1.Class__c];
    // System.assertEquals(cl1r.Brand__c, 'GOVERNING');
    // Contact ct1 =  [SELECT Last_GOV_Class__c FROM Contact WHERE Id = :registrant.Id];
    // System.assertEquals(ct1.Last_GOV_Class__c, class1.Id);

    // Class_Reg__c class2 = new Class_Reg__c(
    //     Non_Qual__c = TRUE,
    //     Contact__c = registrant.Id,
    //     Class__c = testData.createClassWithBrand('GOVTECH').Id
    // );
    // insert class2;
    // Contact ct2 =  [SELECT Last_GT_Class__c FROM Contact WHERE Id = :registrant.Id];
    // System.assertEquals(ct2.Last_GT_Class__c, class2.Id);

    // Class_Reg__c class3 = new Class_Reg__c(
    //     Non_Qual__c = TRUE,
    //     Contact__c = registrant.Id,
    //     Class__c = testData.createClassWithBrand('CDE').Id
    // );
    // insert class3;
    // Contact ct3 =  [SELECT Last_CDE_Class__c FROM Contact WHERE Id = :registrant.Id];
    // System.assertEquals(ct3.Last_CDE_Class__c, class3.Id);

    // Class_Reg__c class4 = new Class_Reg__c(
    //     Non_Qual__c = TRUE,
    //     Contact__c = registrant.Id,
    //     Class__c = testData.createClassWithBrand('EMERGENCYMGMT').Id
    // );
    // insert class4;
    // Contact ct4 =  [SELECT Last_EM_Class__c FROM Contact WHERE Id = :registrant.Id];
    // System.assertEquals(ct4.Last_EM_Class__c, class4.Id);

    // class1.Non_Qual__c = FALSE;
    // update class1;
    // class2.Non_Qual__c = TRUE;
    // update class1;

    // delete class1;

    Test.stopTest();
  }
}
