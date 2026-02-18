@isTest
public class CampaignMemberOnChangeTest {
  @isTest
  static void testInsertCampaignMember() {
    Test.startTest();
    Contact c1 = testData.createContact(true);
    Campaign cp = testData.createCampaign(
      'Test Campaign 1',
      'Campaign_GT_GovTech_Navigator__c'
    );
    CampaignMember cm = new CampaignMember(
      CampaignId = cp.Id,
      ContactId = c1.Id
    );
    insert cm;
    Test.stopTest();
    Contact cf = [
      SELECT Id, Campaign_GT_GovTech_Navigator__c
      FROM Contact
      WHERE Id = :c1.Id
    ];
    System.assertEquals(true, cf.Campaign_GT_GovTech_Navigator__c);
  }

  @isTest
  static void testRemoveCampaignMember() {
    Test.startTest();
    Contact c2 = testData.createContact(true);
    Campaign cp = testData.createCampaign(
      'Test Campaign 2',
      'Campaign_GT_GovTech_Navigator__c'
    );
    CampaignMember cm = new CampaignMember(
      CampaignId = cp.Id,
      ContactId = c2.Id
    );
    insert cm;
    delete cm;
    Test.stopTest();
    Contact cf = [
      SELECT Id, Campaign_GT_GovTech_Navigator__c
      FROM Contact
      WHERE Id = :c2.Id
    ];
    System.assertEquals(false, cf.Campaign_GT_GovTech_Navigator__c);
  }
}
