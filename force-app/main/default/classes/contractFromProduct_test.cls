@isTest(SeeAllData=true)
public class contractFromProduct_test {
  static testMethod void testContractFromProduct() {
    Opportunity o = testData.createOpportunity();
    OpportunityLineItem ls = [
      SELECT Id, Product2Id
      FROM OpportunityLineItem
      WHERE OpportunityId = :o.Id
      ORDER BY CreatedDate ASC
      LIMIT 1
    ];
    Product2 p = [
      SELECT Id, Product_Type__c
      FROM Product2
      WHERE Id = :ls.Product2Id
    ];
    //  part2(o); // events

    p.Product_Type__c = 'Navigator';
    update p;
    part2(o, '01214000000AV7y');
  }

  static testMethod void testContractFromProduct2() {
    Opportunity o = testData.createOpportunity();
    OpportunityLineItem ls = [
      SELECT Id, Product2Id
      FROM OpportunityLineItem
      WHERE OpportunityId = :o.Id
      ORDER BY CreatedDate ASC
      LIMIT 1
    ];
    Product2 p = [
      SELECT Id, Product_Type__c
      FROM Product2
      WHERE Id = :ls.Product2Id
    ];

    p.Product_Type__c = 'Insider';
    update p;
    part2(o, '01214000000AV7y');
  }

  static testMethod void testContractFromProduct3() {
    Opportunity o = testData.createOpportunity();
    OpportunityLineItem ls = [
      SELECT Id, Product2Id
      FROM OpportunityLineItem
      WHERE OpportunityId = :o.Id
      ORDER BY CreatedDate ASC
      LIMIT 1
    ];
    Product2 p = [
      SELECT Id, Product_Type__c
      FROM Product2
      WHERE Id = :ls.Product2Id
    ];

    p.Product_Type__c = 'Events';
    update p;
    part2(o, '012a0000001RKA9');
  }

  static void part2(Opportunity o, String expectedTypeId) {
    //System.debug('*** c '+ o.Id );
    OpportunityLineItem l = [
      SELECT Id
      FROM OpportunityLineItem
      WHERE OpportunityId = :o.Id
      ORDER BY CreatedDate ASC
      LIMIT 1
    ];

    contractFromProduct.createContract(l.Id);

    Contract Ct = [
      SELECT Id, RecordType.Id, RecordType.Name
      FROM Contract
      WHERE Primary_Opportunity__c = :o.Id
      ORDER BY CreatedDate ASC
      LIMIT 1
    ];

    System.debug('Ct *** ' + Ct.Id + ' ' + RecordType.Name);
    System.assert(
      String.valueOf(Ct.RecordType.Id).contains(expectedTypeId),
      true
    );
  }
}
