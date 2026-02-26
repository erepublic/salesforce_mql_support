Date reportStartDate = Date.newInstance(2026, 2, 19);
Date todayMinus7 = Date.today().addDays(-7);
Date todayMinus30 = Date.today().addDays(-30);

List<Contact> candidates = [
  SELECT Id
  FROM Contact
  WHERE CreatedDate >= :reportStartDate
  AND RecordTypeId = '012300000008caRAAQ'
  AND Contact_Status__c LIKE '%Active%'
  AND (
    MQL_Lifecycle_Stage__c = 'Unengaged' OR
    MQL_Lifecycle_Stage__c = 'Engaged' OR
    MQL_Lifecycle_Stage__c = 'Recycled' OR
    MQL_Lifecycle_Stage__c = null
  )
  AND Private_Sector_Non_Qual__c = false
  AND Private_Sector_Acct_Non_Qual__c = false
  AND HubSpot_Private_Sector_Behavior_Date__c >= :todayMinus7
  AND (
    Last_Date_MQL__c < :todayMinus30 OR
    Last_Date_MQL__c = null
  )
  AND (
    Last_Date_Recycled__c < :todayMinus30 OR
    Last_Date_Recycled__c = null
  )
  AND (
    (
      HubSpot_Private_Sector_Behavior_Score__c >= 30 AND
      (
        (
          Contact_Fit_Threshold__c = 'Medium' AND
          Account.Company_Fit_Threshold__c = 'Medium'
        ) OR
        (
          Contact_Fit_Threshold__c = 'High' AND
          (
            Account.Company_Fit_Threshold__c = 'Medium' OR
            Account.Company_Fit_Threshold__c = 'Low'
          )
        )
      )
    ) OR
    (
      HubSpot_Private_Sector_Behavior_Score__c >= 20 AND
      Account.Company_Fit_Threshold__c = 'High' AND
      (
        Contact_Fit_Threshold__c = 'High' OR
        Contact_Fit_Threshold__c = 'Medium'
      )
    )
  )
  AND Id NOT IN (
    SELECT ContactId
    FROM OpportunityContactRole
    WHERE Open_Opportunity__c = true
  )
];

Set<Id> candidateIds = new Set<Id>();
for (Contact c : candidates) {
  candidateIds.add(c.Id);
}

Set<Id> alreadyHasThresholdMql = new Set<Id>();
for (MQL__c existingMql : [
  SELECT Contact__c
  FROM MQL__c
  WHERE Contact__c IN :candidateIds
  AND Lead_Source__c = 'Fit and Behavior Threshold Reached'
]) {
  alreadyHasThresholdMql.add(existingMql.Contact__c);
}

List<MQL__c> toInsert = new List<MQL__c>();
for (Id contactId : candidateIds) {
  if (alreadyHasThresholdMql.contains(contactId)) {
    continue;
  }

  toInsert.add(new MQL__c(
    Contact__c = contactId,
    Lead_Source__c = 'Fit and Behavior Threshold Reached',
    MQL_Status__c = 'New',
    MQL_Date__c = Date.today()
  ));
}

if (!toInsert.isEmpty()) {
  insert toInsert;
}

System.debug('BACKFILL_CANDIDATES=' + candidateIds.size());
System.debug('BACKFILL_EXISTING=' + alreadyHasThresholdMql.size());
System.debug('BACKFILL_INSERTED=' + toInsert.size());
