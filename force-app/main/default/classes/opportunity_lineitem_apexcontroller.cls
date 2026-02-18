global class opportunity_lineitem_apexcontroller {
  /*  used by: event_opportunity_lineitem_delete
   * deleting an event opportunity_product requires extra work
   * testcase: https://erepublic--michaels2.lightning.force.com/lightning/r/Opportunity/0061O00001MdPUwQAN/view
   */
  @AuraEnabled
  public static String delete_event_lineitem(ID line_item_id, String reason) {
    // String reason='asasa'; ID line_item_id = '00k1O00000wnRvyQAE';
    OpportunityLineItem l = [
      SELECT
        Id,
        OpportunityId,
        Opportunity.AccountId,
        Product2.EE_Event__c,
        Product2.Sponsorship__c,
        Returning_status__c
      FROM OpportunityLineItem
      WHERE Id = :line_item_id
      LIMIT 1
    ];
    ID accountId = l.Opportunity.AccountId;
    String sponsorship = l.Product2.Sponsorship__c;
    ID eventId = l.Product2.EE_Event__c;

    // use the for loops to deal with the case that no records are found
    for (Events__c thisEvent : [
      SELECT Id, Last_Years_Event__c
      FROM Events__c
      WHERE Id = :eventId
      LIMIT 1
    ]) {
      ID lastYearsEventId = thisEvent.Last_Years_Event__c;
      //System.debug('lastYearsEventId: '+lastYearsEventId );
      for (Product2 lastYearsProduct : [
        SELECT Id, Sponsorship__c
        FROM Product2
        WHERE EE_Event__c = :lastYearsEventId AND Sponsorship__c = :sponsorship
        LIMIT 1
      ]) {
        //System.debug('lastyearsproduct'+ lastYearsProduct);
        //System.debug('accountId '+ accountId);

        for (OpportunityLineItem oldLineItem : [
          SELECT Id, Returning_status__c, Product2.Sponsorship__c
          FROM OpportunityLineItem
          WHERE
            Opportunity.AccountId = :accountId
            AND Product2Id = :lastYearsProduct.Id
        ]) {
          //System.debug('oldLineItem '+oldLineItem );
          //System.debug('reason '+ reason);

          if (reason == '')
            return ('You must provide a reason for deleting this record');

          oldLineItem.Returning_status__c = reason;
          update oldLineItem;
        }
      }
    }

    delete l;
    // return the opportunity ID because we have to redirect the current page
    return ('SUCCESS|' + l.OpportunityId);
  }

  // used by:   contract_from_product lightning component
  @AuraEnabled
  webService static String create_contract(Id line_item_id) {
    return contractFromProduct.createContract(line_item_id);
  }

  @AuraEnabled
  webService static String create_content_project_actn(Id line_item_id) {
    return projectFromOppLineItem.createProject(line_item_id);
  }
}
