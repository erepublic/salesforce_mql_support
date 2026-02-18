global class ef3_webservice {
  /*
pcio:	 	'a0Qa000000J507zEAB';
governing: 'a0Qa000000J4q7BEAR';
gt: 		'a0Qa000000J4s5tEAB';
em: 		'a0Qa000000J4s5yEAB';
CDE: 		'a0Qa000000J4s63EAB';
techwire: 	'a0Qa000000Oab3pEAB';
*/
  // the  @ReadOnly annotation allows me to retrieve more than 50,000 records
  @ReadOnly
  webService static String getMagazineRenewals(
    String StartEmail,
    String Magazine_id
  ) {
    String response = '';

    Date myDate = date.today();
    Date newDate = myDate.addMonths(-6);
    // if(Magazine_id == 'a0Qa000000J4s5tEAB') // govtech
    //		newDate = mydate.addMonths(-9);

    for (Subscription__c sub : [
      SELECT Subscriber__r.Email
      FROM Subscription__c
      WHERE
        Subscriber__r.Email > :StartEmail
        AND Status__c = 'Active'
        AND Qual_Date__c < :newDate
        AND Publication__r.Id = :Magazine_id
      ORDER BY Subscriber__r.Email
      LIMIT 1000
    ]) {
      response = response + ',' + sub.Subscriber__r.Email;
    }

    //System.debug(response);
    if (!String.isEmpty(response))
      return response.substring(1); // remove the starting comma
    return '';
  } // getMagazineRenewals()

  /*
	resets the CMS_Needs_to_Sync__c if the object is not updated in the meantime
	*/
  webService static void resetSyncFlag(
    String objectType,
    Id id,
    String cmsId,
    DateTime syncTime
  ) {
    String state;
    // the 'FOR UPDATE'  locks the item
    if (objectType == 'Contact') {
      Contact[] conts = [
        SELECT Id, CMS_Needs_to_Sync__c, MailingState
        FROM Contact
        WHERE Id = :id AND CMS_Needs_to_Sync__c = :syncTime
        LIMIT 1
        FOR UPDATE
      ];
      if (!conts.isEmpty()) {
        if (conts[0].MailingState != null) {
          state = conts[0].MailingState;
          state = state.toUpperCase();
          state = state.replaceAll(' ', '');
          conts[0].MailingState = state;
        }
        conts[0].CMS_Needs_to_Sync__c = null;
        conts[0].CMS_Last_Synced__c = datetime.now();
        conts[0].CMS_Contact_Id__c = cmsId;
        update conts[0];
      }
    } else if (objectType == 'Account') {
      Account[] accts = [
        SELECT Id, CMS_Needs_to_Sync__c, BillingState
        FROM Account
        WHERE Id = :id AND CMS_Needs_to_Sync__c = :syncTime
        LIMIT 1
        FOR UPDATE
      ];

      if (!accts.isEmpty()) {
        if (accts[0].BillingState != null) {
          state = accts[0].BillingState;
          state = state.toUpperCase();
          state = state.replaceAll(' ', '');
          accts[0].BillingState = state;
        }
        accts[0].CMS_Needs_to_Sync__c = null;
        accts[0].CMS_Last_Synced__c = datetime.now();
        update accts[0];
      }
    }
  }
}
