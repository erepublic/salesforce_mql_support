//This trigger is inactive in the production environment (april 2025)
trigger account_ef3_trigger on Account(
  after insert,
  after update,
  before delete
) {
  String comma = '';
  String ids = '';
  Boolean isDifferent = false;
  String method = '';

  if (Trigger.isDelete) {
    //delete
    method = 'delete_account';
    for (Account oldAccount : Trigger.old) {
      ids += comma + oldAccount.Id;
      comma = ',';
    }
    isDifferent = true;
  } else {
    method = 'download_account';
    for (Account newAccount : Trigger.new) {
      //insert
      if (Trigger.isInsert) {
        ids += comma + newAccount.Id;
        comma = ',';
        isDifferent = true;
      }

      //update
      if (Trigger.isUpdate) {
        Account oldAccount = Trigger.oldMap.get(newAccount.Id);

        Set<String> fields = new Set<String>();
        fields.add('Name');
        fields.add('Website');
        fields.add('OwnerId');

        for (String field : fields) {
          try {
            if (newAccount.get(field) != oldAccount.get(field)) {
              isDifferent = true;
              break;
            }
          } catch (Exception e) {
          }
        }

        if (isDifferent) {
          ids += comma + newAccount.Id;
          comma = ',';
        }
      }
    }
  }

  //if change in Account record AND user is not OneForm admin user, then call URL
  if (isDifferent && !UserInfo.getUserId().contains('005a000000B8cGM')) {
    oneFormConnector.makeTheCall(ids, method);
  }
}
