/**
 * 2018 -- TW
 * This class was made to allow programmatic merging of opportunities.
 *
 * Testing done in ContractMerge_test
 * */

global class OpportunityMerge {
  @AuraEnabled
  webService static String mergeOpps(Id winner, List<Id> losers) {
    // First clone the whole set of Opportunity Line Item objects to be merged into the winner by
    // pulling all of their fields then updating their OpportunityId to the winner.
    Map<Id, Id> olItemIdMap = new Map<Id, Id>();
    List<OpportunityLineItemSchedule> newSchedules = new List<OpportunityLineItemSchedule>();
    List<OpportunityLineItemSchedule> oldSchedules = new List<OpportunityLineItemSchedule>();
    Schema.DescribeSObjectResult dsoResult = OpportunityLineItem.sObjectType.getDescribe();
    List<String> fieldList = OpportunityMerge.getFieldList(
      Schema.SObjectType.OpportunityLineItem.fields.getMap(),
      true
    );
    String fieldNames = OpportunityMerge.getFieldNamesFromList(fieldList);
    String q =
      'select ' +
      fieldNames +
      ' from OpportunityLineItem where OpportunityId IN (\'' +
      String.join(losers, '\',\'') +
      '\')';
    for (OpportunityLineItem opr : Database.query(q)) {
      OpportunityLineItem oClone = opr.clone(false, true, true);
      oClone.OpportunityId = winner;
      insert oClone;
      olItemIdMap.put(opr.Id, oClone.Id); // Store old to new OLIs
    }

    // Retain OpportunityLineItemSchedule and create new ones with the Winner's OpportunityLineItemId
    for (OpportunityLineItemSchedule oliLoser : [
      SELECT Id, OpportunityLineItemId, Type, Quantity, Revenue, ScheduleDate
      FROM OpportunityLineItemSchedule
      WHERE OpportunityLineItemId IN :olItemIdMap.keySet()
    ]) {
      OpportunityLineItemSchedule newSchedule = oliLoser.clone(
        false,
        true,
        true
      );
      newSchedule.OpportunityLineItemId = olItemIdMap.get(
        oliLoser.OpportunityLineItemId
      );
      newSchedules.add(newSchedule);
      oldSchedules.add(oliLoser); // We add the old schedule to a list to delete later
    }
    // Perform bulk insert
    insert newSchedules;

    // Perform bulk delete
    delete oldSchedules;

    for (ContentDocumentLink cv : [
      SELECT Id, ContentDocumentId
      FROM ContentDocumentLink
      WHERE LinkedEntityId IN :losers
    ]) {
      ContentDocumentLink cdl = new ContentDocumentLink();
      cdl.ContentDocumentId = cv.ContentDocumentId;
      cdl.LinkedEntityId = winner;
      cdl.ShareType = 'I';
      insert cdl;
    }

    // Secondly, move over any agreements.
    for (Agreement__c agreementLoser : [
      SELECT Id, Opportunity__c
      FROM Agreement__c
      WHERE Opportunity__c IN :losers
    ]) {
      agreementLoser.Opportunity__c = winner;
      update agreementLoser;
    }

    // Thirdly, move over any contracts
    for (Contract ctLoser : [
      SELECT Id, Primary_Opportunity__c
      FROM Contract
      WHERE Primary_Opportunity__c IN :losers
    ]) {
      ctLoser.Primary_Opportunity__c = winner;
      update ctLoser;
    }

    // Fourthly, move over any split contracts
    for (Contract sCtLoser : [
      SELECT Id, Split_Opportunity__c
      FROM Contract
      WHERE Split_Opportunity__c IN :losers
    ]) {
      sCtLoser.Split_Opportunity__c = winner;
      update sCtLoser;
    }

    // fifthly, move over activity history
    list<Task> activityHistory = [
      SELECT Id, WhatId
      FROM Task t
      WHERE t.Status != 'Open' AND t.WhatId IN :losers
    ];

    for (Task loserActivityHistory : activityHistory) {
      loserActivityHistory.WhatId = winner;
      update loserActivityHistory;
    }

    // Move over Contact Roles  clone OpportunityContactRole and then insert
    Schema.DescribeSObjectResult dsoContactResult = OpportunityContactRole.sObjectType.getDescribe();
    List<String> ocrfieldList = OpportunityMerge.getFieldList(
      Schema.SObjectType.OpportunityContactRole.fields.getMap(),
      true
    );
    String ocrfieldNames = OpportunityMerge.getFieldNamesFromList(ocrfieldList);
    String ocrq =
      'select ' +
      ocrfieldNames +
      ' from OpportunityContactRole where OpportunityId IN (\'' +
      String.join(losers, '\',\'') +
      '\')';
    for (OpportunityContactRole ocr : Database.query(ocrq)) {
      OpportunityContactRole ocrClone = ocr.clone(false, true, true);
      ocrClone.OpportunityId = winner;
      insert ocrClone;
    }

    // Move over Projects
    for (SFL5_Projects__c projectLoser : [
      SELECT Id, Opportunity__c
      FROM SFL5_Projects__c
      WHERE Opportunity__c IN :losers
    ]) {
      projectLoser.Opportunity__c = winner;
      update projectLoser;
    }

    // Move over Tickets
    for (Ticket__c ticketLoser : [
      SELECT Id, Opportunity__c
      FROM Ticket__c
      WHERE Opportunity__c IN :losers
    ]) {
      ticketLoser.Opportunity__c = winner;
      update ticketLoser;
    }

    // if everything went well, we delete the losing opportunities
    for (Id loserId : losers) {
      Opportunity odl = new Opportunity(Id = loserId);
      delete odl;
    }

    // retain opportunity products schedule dates, amounts & comments

    return ('SUCCESS');
  }

  public static List<String> getFieldList(
    Map<String, Schema.SObjectField> fieldMap,
    Boolean selectAllFields
  ) {
    List<String> fieldList = new List<String>();

    //build dynamic list of fieldnames
    for (String fieldKey : fieldMap.keySet()) {
      Schema.SObjectField fsObj = fieldMap.get(fieldKey);
      Schema.DescribeFieldResult f = fsObj.getDescribe();
      String fieldName = f.getName();

      if (selectAllFields) {
        if (fieldName != 'TotalPrice' && fieldName != 'VersionData') {
          fieldList.add(fieldName);
        }
      } else {
        if (f.getName() == 'Id' || f.isNameField() || f.isCustom()) {
          fieldList.add(fieldName);
        }
      }
    }

    return fieldList;
  }
  public static String getFieldNamesFromList(List<String> fieldList) {
    String fieldNames = '';
    for (String field : fieldList) {
      if (fieldNames.length() > 0) {
        fieldNames += ',';
      }
      fieldNames += field;
    }

    return fieldNames;
  }
}
