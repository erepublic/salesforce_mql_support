trigger Papers_Update_Trigger on Paper__c(before update) {
  if (!UserInfo.getUserId().contains('005a000000B8cGM')) {
    for (Paper__c p : Trigger.new) {
      if (String.isBlank(p.Asset_Type__c)) {
        p.addError('Asset Type is required!');
      }
    }
  }
}
