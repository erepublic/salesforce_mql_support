@isTest(SeeAllData=true)
global class ef3_batchRegistrationInvoice_test {
  static testMethod void test() {
    Id devRecordTypeId = Schema.SObjectType.Contract.getRecordTypeInfosByName()
      .get('Event Contract')
      .getRecordTypeId();
    Contract c = new Contract();
    c.AccountId = '001a000001JVDnX'; // pretend computer company
    c.PO__c = '123';
    c.Billing_Address__c = '100 blue Ravine Folsom';
    //c.Billing_Email__c 		= 'saul@ere.com';  // field is not writable !
    //c.Email_Billing__c      = 'saul@ere.com';  // ????
    c.Billing_Title__c = 'the man';
    c.Billing_Contact__c = '0033000000YCzfl'; //ryan saul
    c.Special_Billing_Instructions__c = ' nothing ';
    c.Sales_Rep__c = '005a000000B8cGM'; //oneform admin
    c.Invoicing_Method__c = 'Mail';
    c.Invoice_Description__c = 'description';

    c.RecordTypeId = devRecordTypeId;
    c.Type__c = 'Invoice';
    c.Status = 'Draft'; //'Ready to Bill';
    c.StartDate = date.today();

    c.Reg_Summary_Amount__c = 0;

    insert c;

    c.Status = 'Submitted to Finance';
    update c;

    Events__c event = testData.createEventWithRegistrations();
    Id testEventId = event.Id; //'a0m14000006RMv2';

    // create a small test batch
    integer counter = 0;
    for (Registration__c r : [
      SELECT Id, Name, Contract__c
      FROM Registration__c
      WHERE Event__c = :testEventId
    ]) {
      if (++counter > 5)
        break;

      r.Contract__c = c.Id;
      update r;
    }

    Test.startTest();
    //ef3_batchRegistrationInvoice.createInvoice4Contract(c.Id);  this was the old non batch way

    // batch process
    ef3_batchLoader.load('ef3_batchRegistrationInvoice', c.Id);

    Test.stopTest();
  }
}
