@isTest(SeeAllData=true)
global class opportunity_create_invoices_cont_test {
  static testMethod void test() {
    // pretend computer company: 001a000001JVDnXAAX
    testData.Retvals ret = testData.createOpportunityForAccount(
      Id.valueOf('001a000001JVDnXAAX'),
      5
    );
    Opportunity o = ret.opportunity;

    opportunity_create_invoices_apexcont.createSchedules(o.id, false);

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

    opportunity_create_invoices_apexcont.createInvoices(o.id);
    //opportunityCreateInvoices.createInvoices('00614000019lIhf');

    //Added 12/17/2025 by Lauren Fahndrich for Ticket #99923
    List<OpportunityLineItemSchedule> scheds = [
      SELECT Id, Description, Finance_Status__c
      FROM OpportunityLineItemSchedule
      WHERE OpportunityLineItem.OpportunityId = :o.Id
    ];

    for (OpportunityLineItemSchedule s : scheds) {
      // Schedules whose Description starts with 'SIN' are skipped by invoice logic,
      // but your descr array doesn't include SIN, so these should be updated.
      System.assertEquals('Billed', s.Finance_Status__c);
      System.assert(
        s.Description != null && s.Description.contains('|'),
        'Should have Sales Invoice Number added to Description.'
      );
    }
  }
}
