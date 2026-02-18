/*
- author: Nathaniel Bockoven
- created: 2014-10-29
- description: Sync with Oneform
changed by Michael Tel 7/8/2015   to prevent people from inserting and deleting registrations into webinars

changed by Tim Williams 2/6/2018   on update sync to the CMS

 testing is done by eventAttendeeNotification_test  : delete reg;

*/

trigger registration on Registration__c(
  before update,
  before insert,
  before delete
) {
  // String email = '';
  String ids = '';
  List<String> emailAddresses = new List<String>();
  List<String> updateIds = new List<String>{};

  String method = 'download_event_registration';

  String extraData = '';

  Events__c event = null;

  ID webinarType = '01214000000AUymAAG';
  // String uid = (String) UserInfo.getUserId();
  // boolean isAdmin =   uid.contains('005a000000B8cGM') || uid.contains('00530000001usfp');

  // inner function
  String comma = ''; // only used by addToList
  void addToList(ID id) {
    if (!ids.contains(id)) {
      ids += comma + id;
      comma = ',';
    }
  }

  void setExtraData() {
    if (emailAddresses.isEmpty())
      return;

    String emails = '';
    for (String e : emailAddresses)
      emails = emails + ',' + e;

    extraData =
      '&event_id=' +
      event.OneForm_ID__c +
      '&emails=' +
      emails.substring(1);
    emailAddresses.clear();
  }

  ID profileId = UserInfo.getProfileId();
  boolean isAdmin = (profileId == '00e30000000vQoq' ||
  profileId == '00e14000000jUTB' ||
  profileId == '00e1O000001x96V'); //system Admin || system admin 1

  if (Trigger.isDelete) {
    String emails = '';
    for (Registration__c reg : Trigger.old) {
      if (event == null) {
        event = [
          SELECT Id, OneForm_ID__c, RecordTypeId
          FROM Events__c
          WHERE Id = :reg.Event__c
          LIMIT 1
        ];
      }
      if (webinarType == event.RecordTypeId && !isAdmin)
        reg.addError(
          'No No No, You are not allowed to delete Webinar Registrations ! '
        );
      else {
        addToList(event.Id);
        method = 'delete_event_registration';
        //emails = emails + ',' +reg.Registrant_Email__c;
        emailAddresses.add(reg.Registrant_Email__c);
      }

      // if we have 10 emails make a call
      if (emailAddresses.size() >= 10) {
        setExtraData();
        oneFormConnector.makeTheCall(ids, method, extraData);
        ids = '';
      }
    } // for each reg
    setExtraData(); // to pick up the remaining
  }  //delete
  else {
    for (Registration__c newReg : Trigger.new) {
      //List<Events__c> es = [SELECT Id, RecordTypeId from Events__c WHERE  Id = :newReg.Event__c limit 1];
      if (event == null) {
        event = [
          SELECT Id, Contact_Interest_Topics__c, RecordTypeId
          FROM Events__c
          WHERE Id = :newReg.Event__c
          LIMIT 1
        ];
      }

      if (Trigger.isUpdate) {
        Registration__c oldReg = Trigger.oldMap.get(newReg.Id);
        updateIds.add(newReg.Id);

        // not allowed to change registrant  for any event type
        if (
          newReg.get('Registrant_Name__c') !=
          oldReg.get('Registrant_Name__c') &&
          oldReg.get('Registrant_Name__c') != null
        ) {
          newReg.addError(
            'No No No, You are not allowed to change the registrant! '
          );
        }

        // check if following fields have been changed
        Set<String> fields = new Set<String>();
        fields.add('Non_Qual__c');
        fields.add('Reg_Advisory_Board__c');
        fields.add('Reg_Type__c');
        fields.add('Exclude_From_Mailing_List__c');
        fields.add('Reg_Speaker__c');

        for (String field : fields) {
          try {
            if (newReg.get(field) != oldReg.get(field)) {
              addToList(newReg.Id);
            }
          } catch (Exception e) {
            // System.debug( e );
          }
        } // for field
      }

      if (Trigger.isInsert) {
        if (event != null) {
          // Contact_Interest_Topics__c
          newReg.Event_Contact_Interest_Topics__c = event.Contact_Interest_Topics__c;
        }
      }
    } //for (Registration__c newReg : Trigger.new )
  } // not a delete
  if (ids.length() > 0 && !UserInfo.getUserId().contains('005a000000B8cGM')) {
    oneFormConnector.makeTheCall(ids, method, extraData);
  }
  if (
    !updateIds.isEmpty() && !UserInfo.getUserId().contains('005a000000B8cGM')
  ) {
    String updateIdList = String.join(updateIds, ',');
    oneFormConnector.makeTheCall(updateIdList, 'update_event_registration');
  }
}
