global class projectFromOppLineItem {
  @AuraEnabled
  webService static String createProject(Id line_item_id) {
    // Special_Terms_del__c,
    OpportunityLineItem l = [
      SELECT
        Id,
        Contract__c,
        Special_Terms_del__c,
        OpportunityId,
        Opportunity.Account.Concierge_1__c,
        Opportunity.Account.Id,
        Product2Id,
        Product2.Product_Category__c,
        Opportunity.Owner.Id,
        TotalPrice,
        AccountName__c,
        Project_Name_Text__c,
        Project_Name__c
      FROM OpportunityLineItem
      WHERE Id = :line_item_id
    ];
    if (l.Project_Name__c != null) {
      throw new AuraHandledException(
        'Project already exists! Please delete it or remove it from this Opportunity to create a new one.'
      );
    }
    if (
      l.Project_Name_Text__c == null || String.isBlank(l.Project_Name_Text__c)
    ) {
      throw new AuraHandledException('Project Name cannot be blank!');
    }
    Id ProjOwnerId;
    if (l.Opportunity.Account.Concierge_1__c == null) {
      ProjOwnerId = UserInfo.getUserId();
    } else {
      ProjOwnerId = l.Opportunity.Account.Concierge_1__c;
    }
    // Id projRecordTypeId = [Select IsSandbox FROM Organization LIMIT 1].IsSandbox ? '0121D000005fICG' : '0125Y000001bPG9';
    SFL5_Projects__c pj = new SFL5_Projects__c(
      Name = l.Project_Name_Text__c,
      RecordTypeId = '0125Y000001bPG9',
      Sales_Rep__c = l.Opportunity.Owner.Id,
      Contract__c = l.Contract__c,
      Project_Owner__c = ProjOwnerId,
      Product__c = l.Product2.Product_Category__c,
      Client__c = l.Opportunity.Account.Id,
      Project_Phase__c = 'Waiting',
      Project_Status__c = 'Waiting',
      Project_Deliverables__c = l.Special_Terms_del__c
    );

    try {
      insert pj;
      l.Project_Name__c = pj.Id;
      //if(True)throw new AuraHandledException(pj.Id);
      update l;
    } catch (DMLException error) {
      system.debug('Error: ' + error.getMessage());
    }

    return ('SUCCESS');
  }
}
