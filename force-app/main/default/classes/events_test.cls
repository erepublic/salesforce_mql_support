@isTest
private class events_test {
  static testMethod void myUnitTest() {
    Test.startTest();
    System.debug('Test 1 Standard event on create');
    Events__c event = testData.createEvent(true);
    //event.name = 'testing';
    event.Replace_ADBD_with_Planning_Committee__c = true;
    System.debug('Test 2 Standard event on update');
    update event;
    try {
      System.debug('Test 3 Standard event on delete');
      delete event; // Expected DMLException
    } catch (DmlException e) {
      // Assert that the expected error is thrown
      System.assertEquals(
        e.getMessage().contains('Only CmsAdmin can delete events'),
        true,
        'Error message not found'
      );
    }
    System.debug('Test 4 Standard event on create');
    Events__c custom_event = testData.createEvent(true);
    custom_event.RecordTypeId = testData.RECORD_TYPE_CUSTOM_EVENT;
    custom_event.name = 'custom event!';
    System.debug('Test 5 Custom event on update');
    update custom_event;

    System.debug('Test 6 Standard event on create');
    Events__c webinar = testData.createEvent(true);
    webinar.RecordTypeId = testData.RECORD_TYPE_WEBINAR;
    webinar.Duration_minutes__c = '60';
    System.debug('Test 7 webinar event on update');
    update webinar;
    //delete webinar;

    Test.stopTest();
  }
}
