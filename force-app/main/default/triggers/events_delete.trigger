trigger events_delete on Events__c(before delete) {
  // only cmsAdmin can delete events

  for (Events__c oldEvent : Trigger.old) {
    if (!UserInfo.getUserId().contains('005a000000B8cGM')) {
      oldEvent.addError(
        'To delete an event you must submit a web support ticket. Only CmsAdmin can delete events'
      );
    }
  }
}
