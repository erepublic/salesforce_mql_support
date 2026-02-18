trigger paper_download on Paper_Download__c(
  after insert,
  before delete,
  before update
) {
  String registrants = ''; // emails of all the registrants
  String disquals = ''; // emails of all the registrants that are deleted or disqualified
  String extraData = '';
  String paperId = '';

  if (Trigger.isDelete) {
    //delete
    for (Paper_Download__c download : Trigger.old) {
      paperId = download.Paper__c;
      if (!disquals.contains(download.Registrant_Email__c))
        disquals += ',' + download.Registrant_Email__c;
    }
  } else {
    //insert or update
    for (Paper_Download__c download : Trigger.new) {
      paperId = download.Paper__c;

      if (
        download.Non_Qual__c == true &&
        !disquals.contains(download.Registrant_Email__c)
      )
        disquals += ',' + download.Registrant_Email__c;
      else if (
        download.Non_Qual__c == false &&
        !registrants.contains(download.Registrant_Email__c)
      )
        registrants += ',' + download.Registrant_Email__c;
    } //for
  }

  // if change in Paper_Download__c field AND user is not Eloqua Admin, then call URL and pass Paper__c IDs

  if (registrants.length() > 0)
    extraData += '&registrants=' + registrants.substring(1);
  if (disquals.length() > 0)
    extraData += '&disquals=' + disquals.substring(1);

  if (!UserInfo.getUserId().contains('005a000000B8cGM'))
    oneFormConnector.makeTheCall(paperId, 'download_paper', extraData);

}
