global class OpportunityLineItemSchedule_Paid implements Schedulable {
  /*
    // run the following code in the "execute Anonymous" window to schedule this app to run every night at 4 am
    OpportunityLineItemSchedule_Paid m = new OpportunityLineItemSchedule_Paid();
    String sch = '0 0 5 * * ?';
    system.schedule('Set Paid invoices lineItemSchedules to paid', sch, m);

    // for testing:
    OpportunityLineItemSchedule_Paid m = new OpportunityLineItemSchedule_Paid();  m.markAsPaid();
    */

  global void execute(SchedulableContext SC) {
    markAsPaid();
  }

  global void markAsPaid() {
    List<OpportunityLineItemSchedule> updatedList = new List<OpportunityLineItemSchedule>();
    Set<String> paidInvoiceNames = new Set<String>();
    for (c2g__codaInvoice__c invoice : [
      SELECT Name
      FROM c2g__codaInvoice__c
      WHERE
        Payment_Status_Formula__c IN (
          'Paid',
          'CWO (Matched)',
          'CC Payment Received'
        )
        AND (c2g__DueDate__c = LAST_N_DAYS:270
        OR c2g__DueDate__c = NEXT_N_DAYS:365)
      ORDER BY c2g__DueDate__c DESC
    ]) {
      paidInvoiceNames.add(invoice.Name);
    }
    String str;
    for (OpportunityLineItemSchedule s : [
      SELECT Id, Description
      FROM OpportunityLineItemSchedule
      WHERE
        Description LIKE 'SIN%'
        AND (NOT Description LIKE '%PAID%')
        AND (NOT Description LIKE '%REFUND%')
        AND (NOT Description LIKE '%CANCEL%')
        AND ScheduleDate = LAST_N_DAYS:180
      ORDER BY ScheduleDate DESC
    ]) {
      String[] parts = s.Description.split('\\|');
      if (paidInvoiceNames.contains(parts[0])) {
        str = s.Description + '|PAID';
        if (str.length() > 79)
          s.Description = str.substring(0, 78);
        else
          s.Description = str;
        updatedList.add(s);
      }
    }

    if (!updatedList.isEmpty()) {
      update updatedList;
    }
  }
}
