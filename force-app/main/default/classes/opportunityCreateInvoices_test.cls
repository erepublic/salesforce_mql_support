@isTest(SeeAllData=true)
global class opportunityCreateInvoices_test {
  static testMethod void test() {
    // pretend computer company: 001a000001JVDnXAAX
    testData.Retvals ret = testData.createOpportunityForAccount(
      Id.valueOf('001a000001JVDnXAAX'),
      5
    );
    Opportunity o = ret.opportunity;

    opportunityCreateInvoices.createSchedules(o.id, false);

    Date scheduleDate = Date.today();

    String[] descr = new List<String>{
      ' ',
      'CC ',
      'CHECK ',
      'ACH ',
      'testing ',
      ''
    };
    Integer i = 0;
    for (OpportunityLineItem product : [
      SELECT Id, TotalPrice
      FROM OpportunityLineItem
      WHERE OpportunityId = :o.Id
    ]) {
      // create a schedule for this lineitem
      OpportunityLineItemSchedule s = new OpportunityLineItemSchedule();
      s.OpportunityLineItemId = product.Id;
      s.Revenue = product.TotalPrice;
      s.Type = 'Revenue';
      s.ScheduleDate = scheduleDate;
      s.Description = descr[i++];
      insert s;
    }

    opportunityCreateInvoices.createInvoices(o.id);
    //opportunityCreateInvoices.createInvoices('00614000019lIhf');

    //Added 12/17/2025 by Lauren Fahndrich for Ticket #99923
    List<OpportunityLineItemSchedule> scheds = [
      SELECT Id, Description, Finance_Status__c
      FROM OpportunityLineItemSchedule
      WHERE OpportunityLineItem.OpportunityId = :o.Id
    ];

    // Only the ones invoiced (today or earlier, not already SIN) will be updated.
    // In your test, you insert schedules for today, so they should be billed.
    for (OpportunityLineItemSchedule s : scheds) {
      System.assertEquals(
        'Billed',
        s.Finance_Status__c,
        'Schedule should be marked Billed when SIN is stamped.'
      );
      System.assert(
        s.Description != null && s.Description.startsWith('SIN'),
        'Schedule Description should be prefixed with SIN.'
      );
    }
  }
}
