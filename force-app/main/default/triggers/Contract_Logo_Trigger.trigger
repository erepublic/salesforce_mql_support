trigger Contract_Logo_Trigger on Contract(after update) {
  String comma = '';
  String updateIds = '';
  for (Id ContractId : Trigger.newMap.keySet()) {
    if (
      Trigger.oldMap.get(ContractId).Website_Full_DisplayURL__c !=
      Trigger.newMap.get(ContractId).Website_Full_DisplayURL__c
    ) {
      updateIds += comma + ContractId;
      comma = ',';
    }
  }
  if (
    updateIds.length() > 0 && !UserInfo.getUserId().contains('005a000000B8cGM')
  ) {
    oneFormConnector.makeTheCall(updateIds, 'rebuild_sponsor_logo_cache');
  }
}
