/*
Michael Tel May 2015 - 2016
Creates one Sales Invoice for a group of Registration__c  records, marked with a 'contract' 
 all registrations will appear as line items

test event :  a0m14000006RMv2   CDE - Illinois CTO Summit 2015


 create a custom js button (setup/customize/contract/buttons) with the following script:
{!REQUIRESCRIPT("/soap/ajax/30.0/connection.js")} 
{!REQUIRESCRIPT("/soap/ajax/30.0/apex.js")} 

var cid = "{!Contract.Id}" ; 
// the non-batch version: var msg = sforce.apex.execute("ef3_batchRegistrationInvoice","createInvoice4Contract",{contractId:cid} );
var msg = sforce.apex.execute("ef3_batchLoader","load",{theClass:'ef3_batchRegistrationInvoice', theParams:cid} ); 
alert(msg);

 

*/

global class ef3_batchRegistrationInvoice implements Database.Batchable<sObject> {
  private final Id contractId;
  private final Id invoiceId;
  private final String invoiceName;

  global ef3_batchRegistrationInvoice(Id contract_Id) {
    this.contractId = contract_Id;

    Contract contract = [
      SELECT
        Id,
        Account.Id,
        Account.c2g__CODADescription1__c,
        PO__c,
        Billing_Address__c,
        Billing_Email__c,
        Billing_Title__c,
        Billing_Contact_Lookup__c,
        Authorize_net__c,
        Invoice_Number__c,
        Email_Cc_Contract__c,
        Special_Billing_Instructions__c,
        Invoicing_Method__c,
        Invoice_Description__c,
        Reference__c,
        Sales_Rep__c
      FROM Contract
      WHERE Id = :this.contractId
    ];

    contract.Invoice_Number__c = 'In Progress';
    update contract;

    c2g__codaInvoice__c invoice = createInvoice(contract);
    this.invoiceId = invoice.Id;
    this.invoiceName = invoice.Name;
  }

  /* Note you cannot set class properties in this function 
	    Do it in the constructor !
	*/
  global Database.QueryLocator start(Database.BatchableContext BC) {
    System.assertNotEquals(null, this.invoiceId, ' this.invoiceId is null !!!');

    Id cid = this.contractId;
    String query = 'SELECT Id, Attendee_Name__c,Contract__c, Reg_Fee__c, Event__c  FROM  Registration__c WHERE Contract__c =: cid  ORDER BY Attendee_Name__c';
    return Database.getQueryLocator(query);
  }

  global void execute(Database.BatchableContext BC, List<sObject> scope) {
    List<c2g__codaInvoiceLineItem__c> itemList = new List<c2g__codaInvoiceLineItem__c>(); // for bulk insert

    Product2 attendeeProduct = null;

    System.assertNotEquals(null, this.invoiceId, ' this.invoiceId is null !!!');

    for (sObject row : scope) {
      registration__c registration = (registration__c) row;
      if (attendeeProduct == null) {
        attendeeProduct = [
          SELECT Id
          FROM Product2
          WHERE
            Sponsorship__c = 'Attendee'
            AND EE_Event__c = :registration.Event__c
        ];
      }

      c2g__codaInvoiceLineItem__c li = new c2g__codaInvoiceLineItem__c(
        c2g__Invoice__c = this.invoiceId,
        Registration__c = registration.Id,
        c2g__Product__c = attendeeProduct.Id,
        c2g__Quantity__c = 1,
        c2g__UnitPrice__c = registration.Reg_Fee__c,
        c2g__DeriveUnitPriceFromProduct__c = false
      );
      itemList.add(li);
    }
    insert itemList;
  }

  global void finish(Database.BatchableContext BC) {
    Id cid = this.contractId;
    Contract contract = [
      SELECT Id, Status, invoice_Number__c, Invoice_Date__c, Sales_Invoice__c
      FROM Contract
      WHERE Id = :cid
    ];

    contract.Status = 'Completed'; //'Sales Invoice Created';
    contract.Invoice_Number__c = this.invoiceName;
    contract.Invoice_Date__c = date.today();
    contract.Sales_Invoice__c = this.invoiceId;
    update contract;
  }
  /*	
	// this is the old code that works for smaller batches ( less thatn 80 lineitems)
	webService static  String createInvoice4Contract(ID contractId)
	{	
		
		Contract contract = [SELECT   Id, Account.Id, Account.c2g__CODADescription1__c, PO__c, Billing_Address__c, Billing_Email__c,  Billing_Title__c, Billing_Contact_Lookup__c, Authorize_net__c,
		   Email_Cc_Contract__c, Special_Billing_Instructions__c,  Invoicing_Method__c, Invoice_Description__c, Reference__c   FROM Contract WHERE Id =: contractId];
		
		c2g__codaInvoice__c invoice = createInvoice(contract);
		
		Product2 attendeeProduct =null; 
		
		//List<Registration__c>              regList = new List<Registration__c>();
		List<c2g__codaInvoiceLineItem__c> itemList = new List<c2g__codaInvoiceLineItem__c>(); // for bulk insert
				
		List<Registration__c> registrations = [SELECT Id, Attendee_Name__c,Contract__c, Reg_Fee__c, Event__c  FROM  Registration__c WHERE Contract__c =: contractId  ORDER BY Attendee_Name__c ];
		for(Registration__c registration : registrations)
		{		
			if(attendeeProduct ==null){
				attendeeProduct = [SELECT Id FROM Product2 WHERE Sponsorship__c = 'Attendee' AND EE_Event__c =: registration.Event__c ];
			}
						
			c2g__codaInvoiceLineItem__c li = new c2g__codaInvoiceLineItem__c(
				c2g__Invoice__c = invoice.Id,
				Registration__c = registration.Id ,
				c2g__Product__c = attendeeProduct.Id,
				c2g__Quantity__c = 1,				
				c2g__UnitPrice__c = registration.Reg_Fee__c ,
				c2g__DeriveUnitPriceFromProduct__c = false
			);
			itemList.add(li);
		}
		insert itemList;
		
		
		// now we have to loop over the lineitems we just created to set the prices. Sigh...	
	//	itemList = [SELECT Id, Registration__c, c2g__UnitPrice__c FROM c2g__codaInvoiceLineItem__c WHERE c2g__Invoice__c =: invoice.Id];  
	//	
	//	integer idx = 0;
	//	for(Registration__c registration : registrations){
	//		c2g__codaInvoiceLineItem__c item = itemList.get(idx++);
	//		item.Registration__c   = registration.Id;
	//		item.c2g__UnitPrice__c = registration.Reg_Fee__c;
	//	}
	//	update itemList;
		
		
		contract.Status 			= 'Completed'; //'Sales Invoice Created';
		contract.Invoice_Number__c 	= invoice.Name;
		contract.Invoice_Date__c 	= date.today();
		contract.Sales_Invoice__c   = invoice.Id;
		update contract;
		
		return 'Created Invoice '+ invoice.Name +' for contract: '+ contractId;
	} 
*/

  static private c2g__codaInvoice__c createInvoice(Contract c) {
    c2g__codaInvoice__c invoice = new c2g__codaInvoice__c(
      //RecordTypeId 			= '01214000000AVjd',     // in progress
      c2g__Account__c = c.Account.Id,
      Client__c = c.Account.Id,
      Billing_Contact_IPS__c = c.Billing_Contact_Lookup__c,
      Billing_Title__c = c.Billing_Title__c,
      Invoice_Billing_Address__c = c.Billing_Address__c,
      Billing_Email__c = c.Billing_Email__c,
      Primary_Contact__c = c.Billing_Contact_Lookup__c,
      Primary_Title__c = c.Billing_Title__c,
      Primary_Contact_Address__c = c.Billing_Address__c,
      Primary_Email__c = c.Billing_Email__c,
      c2g__InvoiceDate__c = date.today(),
      PO_Number__c = c.PO__c,
      Invoice_Type__c = 'Standard',
      Special_Billing_Instructions__c = c.Special_Billing_Instructions__c,
      Invoicing_Method__c = c.Invoicing_Method__c,
      c2g__InvoiceDescription__c = c.Invoice_Description__c,
      //Terms__c				= c.Account.c2g__CODADescription1__c,
      Contract__c = c.Id,
      Email_Cc_SIN__c = c.Email_Cc_Contract__c,
      //Authorize_net__c        = c.Authorize_net__c,
      Sales_Rep__c = c.Sales_Rep__c,
      Authorize_Net_Transaction_ID__c = c.Reference__c
    );

    if (c.Authorize_net__c)
      invoice.CWO_Type__c = 'AUTH';

    insert invoice;

    invoice = [SELECT Id, Name FROM c2g__codaInvoice__c WHERE Id = :invoice.Id]; // reload invoice to get the name

    return invoice;
  }
}
