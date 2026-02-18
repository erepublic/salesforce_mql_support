trigger Paper_ef3_sync on Paper__c(after insert, after update) {
  String comma = '';
  String ids = '';

  for (Paper__c p : Trigger.new) {
    ids += comma + p.Id;
    comma = ',';
  }

  if (ids.length() > 0) {
    oneFormConnector.makeTheCall(ids, 'salesforceDownloadPapers');
  }
}
