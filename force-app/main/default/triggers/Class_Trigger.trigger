trigger Class_Trigger on Class__c(before update, after insert) {
  String comma = '';
  String ids = '';

  for (Class__c newClass : Trigger.new) {
    ids += comma + newClass.Id;
    comma = ',';
  }

  if (ids.length() > 0 && !UserInfo.getUserId().contains('005a000000B8cGM')) {
    oneFormConnector.makeTheCall(ids, 'download_class');
  }
}
