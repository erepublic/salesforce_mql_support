trigger trigger_oppLineItemSchedule on OpportunityLineItemSchedule(
  before insert,
  before update
) {
  // Michael Tel September 2022    Ticket#38873
  // test object:  trigger_oppLineItemSchedule_test
  List<Id> OLIIds = new List<Id>();
  List<String> AIds = new List<String>();
  Map<Id, OpportunityLineItemSchedule> OLISList = new Map<Id, OpportunityLineItemSchedule>();
  Map<String, OpportunityLineItemSchedule> OLISList2 = new Map<String, OpportunityLineItemSchedule>();

  for (OpportunityLineItemSchedule newSchedule : Trigger.new) {
    if (!String.isBlank(newSchedule.SIN_Extracted__c)) {
      AIds.add(newSchedule.SIN_Extracted__c);
      OLISList2.put(newSchedule.SIN_Extracted__c, newSchedule);
    }
    if (newSchedule.Original_Close_Date__c == null) {
      OLIIds.add(newSchedule.OpportunityLineItemId);
      OLISList.put(newSchedule.OpportunityLineItemId, newSchedule);
    }
  }

  List<OpportunityLineItem> OLIList = ([
    SELECT Id, Opportunity.CloseDate
    FROM OpportunityLineItem
    WHERE Id IN :OLIIds AND Opportunity.Current_Stage__c = 'Written'
  ]);

  List<c2g__codaInvoice__c> InvoiceList = ([
    SELECT Name, Id, Opportunity_Close_Date__c
    FROM c2g__codaInvoice__c
    WHERE Name IN :AIds
  ]);

  for (OpportunityLineItem oli : OLIList) {
    OpportunityLineItemSchedule olis = OLISList.get(oli.Id);
    if (oli.Opportunity.CloseDate != null) {
      olis.Original_Close_Date__c = oli.Opportunity.CloseDate;
    }
  }
  for (c2g__codaInvoice__c invoice : InvoiceList) {
    OpportunityLineItemSchedule olis2 = OLISList2.get(invoice.Name);

    if (
      invoice.Opportunity_Close_Date__c != null &&
      olis2.Override_OCD__c != true
    ) {
      olis2.Original_Close_Date__c = invoice.Opportunity_Close_Date__c;
    }
    olis2.Sales_Invoice__c = invoice.Id;
  }
}
