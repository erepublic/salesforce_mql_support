trigger events on Events__c(before update, after insert) {
  String comma = '';
  String ids = '';
  String record_type = '';
  final String WEBINAR_TYPE = '01214000000AUym';
  final String MARKETING_WEBINAR_TYPE = '01214000000AVlo';
  final String STANDARD_EVENT_TYPE = '01230000000ueuw'; //01230000000ueuwAAA
  final String CUSTOM_EVENT_TYPE = '01230000000ueur';
  String trigger_type = '';
  if (Trigger.isInsert) {
    trigger_type += ' Insert';
  }
  if (Trigger.isUpdate) {
    trigger_type += ' Update';
  }
  if (Trigger.isDelete) {
    trigger_type += ' Delete';
  }

  for (Events__c newEvent : Trigger.new) {
    if (newEvent.Do_Not_Sync_to_CMS__c == true) {
      // if True then don't sync
      continue;
    }
    record_type = newEvent.RecordTypeId;
    record_type = record_type.substring(0, 15);
    if (
      Trigger.isInsert &&
      (record_type == WEBINAR_TYPE ||
      record_type == MARKETING_WEBINAR_TYPE ||
      record_type == STANDARD_EVENT_TYPE ||
      record_type == CUSTOM_EVENT_TYPE)
    ) {
      if (!ids.contains(newEvent.Id)) {
        ids += comma + newEvent.Id;
        comma = ',';
      }
    }
    if (Trigger.isUpdate) {
      Events__c oldEvent = Trigger.oldMap.get(newEvent.Id);

      // check if following fields have been changed
      Set<String> fields = new Set<String>();
      if (
        record_type == WEBINAR_TYPE ||
        record_type == MARKETING_WEBINAR_TYPE
      ) {
        fields.add('Brand__c');
        fields.add('Display_Title__c');
        fields.add('Event_Start_Date__c');
        fields.add('Event_Start_Time__c');
        fields.add('Duration_minutes__c');
        fields.add('Event_Month__c');
        fields.add('Lead_Guarantee__c');
        fields.add('Targeted_Registration__c');
        fields.add('Qualified_Leads__c');
        fields.add('Name');
        fields.add('RecordTypeId');
        fields.add('Registration_Coordinator__c');
        fields.add('Show_Flyin_Promo__c');
        fields.add('Registration_Closed__c');
        fields.add('Status__c');
      }
      if (record_type == CUSTOM_EVENT_TYPE) {
        // CUSTOM EVENT
        fields.add('Brand__c');
        fields.add('Display_Title__c');
        fields.add('Event_Manager__c');
        fields.add('Hide_Registration_Button__c');
        fields.add('Lead_Guarantee__c');
        fields.add('Targeted_Registration__c');
        fields.add('Name');
        fields.add('Qualified_Leads__c');
        fields.add('RecordTypeId');
        fields.add('Registration_Coordinator__c');
        //fields.add( 'Registration_Coordinator__r.Email' );
        fields.add('Show_Detail_Page__c');
        fields.add('Show_Listing__c');
        fields.add('Status__c');
        fields.add('Twitter_Hashtag__c');
        fields.add('Venue_City__c');
        fields.add('Venue_Main_Phone__c');
        fields.add('Venue_Name__c');
        fields.add('Venue_State__c');
        fields.add('Venue_Street__c');
        fields.add('Venue_Website__c');
        fields.add('Venue_Zip__c');
        fields.add('Registration_Closed__c');
      }
      if (record_type == STANDARD_EVENT_TYPE) {
        // STANDARD EVENT
        fields.add('Brand__c');
        fields.add('Status__c');
        fields.add('Cancel_by_Date__c');
        fields.add('Early_Bird_End_Date__c');
        fields.add('Event_End_Date__c');
        fields.add('Event_End_Time__c');
        fields.add('Event_Start_Date__c');
        fields.add('Event_Start_Time__c');
        fields.add('Event_Month__c');
        fields.add('Event_Type__c');
        fields.add('Event_Year__c');
        fields.add('Govt_Early_Bird_Discount__c');
        fields.add('Govt_Reg_Price__c');
        fields.add('Industry_Early_Bird_Discount__c');
        fields.add('Industry_Other_Discount__c');
        fields.add('Industry_Reg_Price__c');
        fields.add('Name');
        fields.add('Open_to_private_companies__c');
        fields.add('Qualified_Leads__c');
        fields.add('Qualified_Registration_Includes__c');
        fields.add('RecordTypeId');
        fields.add('Registration_Coordinator__c');
        fields.add('Registration_Open__c');
        fields.add('Registration_Closed__c');
        fields.add('Replace_ADBD_with_Planning_Committee__c');
        fields.add('Sponsor_Additional_Pass_Price__c');
        fields.add('Targeted_Registration__c');
        fields.add('Time_Zone__c');
        fields.add('Venue_City__c');
        fields.add('Venue_Main_Phone__c');
        fields.add('Venue_Name__c');
        fields.add('Venue_State__c');
        fields.add('Venue_Street__c');
        fields.add('Venue_Website__c');
        fields.add('Venue_Zip__c');
        fields.add('VCard_Threshold__c');
        fields.add('VDGS_Hub_Open_Date__c');
      }

      for (String field : fields) {
        try {
          if (newEvent.get(field) != oldEvent.get(field)) {
            if (!ids.contains(newEvent.Id)) {
              // add to list of ids
              ids += comma + newEvent.Id;
              comma = ',';
            }
          }
        } catch (Exception e) {
          System.debug(
            'The following exception has occurred while handling the ' +
              field +
              ' field: ' +
              e.getMessage()
          );
        }
      } // for field
    } //Trigger.isUpdate
  } // for newEvent

  if (ids.length() > 0 && !UserInfo.getUserId().contains('005a000000B8cGM')) {
    oneFormConnector.makeTheCall(
      ids,
      'download_event&record_type=' + record_type
    );
    System.debug(
      'Event Synched  record_type: ' + record_type + ' trigger: ' + trigger_type
    );
  } else {
    System.debug(
      'Event is NOT being synched  record_type: ' +
        record_type +
        ' trigger: ' +
        trigger_type
    );
  }
}
