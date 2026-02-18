/*
 Michael Tel march 2016
 
 From an opportunity, looks at all the payment schedules for all the opportunityLineitems (AKA opportunity products)
 and creates 1 invoice per date  with many lineitems, 1 for every schedule record
 
 to test in the sandbox:
 opportunityCreateInvoices.createInvoices('00614000019lIhf');    // big opportunity
 opportunityCreateInvoices.createInvoices('0061400001DfRjk');    // small opp


 create a custom js button (setup/customize/opportunity/buttons) with the following script:
New Button – “Create Invoices” 
 
{!REQUIRESCRIPT("/soap/ajax/30.0/connection.js")} 
{!REQUIRESCRIPT("/soap/ajax/30.0/apex.js")} 

var cid = "{!Opportunity.Id}" ; 
var msg = sforce.apex.execute("opportunityCreateInvoices","createInvoices",{opportunityId:cid} );
alert(msg);
 
 
New Button – “Schedule All Today” or “Schedule All Future”
 
{!REQUIRESCRIPT("/soap/ajax/30.0/connection.js")} 
{!REQUIRESCRIPT("/soap/ajax/30.0/apex.js")} 

var cid = "{!Opportunity.Id}" ; 
var msg = sforce.apex.execute("opportunityCreateInvoices","createSchedules",{opportunityId:cid,billIn8Years:false} );
alert(msg);
 */

global class opportunityCreateInvoices {
  static Integer numInvoices = 0;

  webService static String createSchedules(
    ID opportunityId,
    boolean billIn8Years
  ) {
    Date scheduleDate = Date.today();
    if (billIn8Years)
      scheduleDate = scheduleDate.addYears(10);

    List<ID> OpportunityIdList = new List<ID>();
    OpportunityIdList.add(opportunityId);

    /* Ryan thinks we should not include the split opprtunity   
	Opportunity o = [Select Id,  Split_Opportunity__c	From Opportunity WHERE Id =: opportunityId];				
	if(!String.isBlank(o.Split_Opportunity__c))
		OpportunityIdList.add(o.Split_Opportunity__c);
*/

    List<OpportunityLineItemSchedule> scheduleList = new List<OpportunityLineItemSchedule>();

    // get OpportunityLineItems  and loop over them
    Set<ID> ProductIds = new Set<ID>(); // OpportunityLineItems  and products are the same
    for (OpportunityLineItem product : [
      SELECT Id, TotalPrice
      FROM OpportunityLineItem
      WHERE IsDeleted = FALSE AND OpportunityId IN :OpportunityIdList
    ]) {
      // make list of ids for mass query, and keep them in an array
      ProductIds.add(product.Id);

      // create a schedule for this lineitem
      OpportunityLineItemSchedule s = new OpportunityLineItemSchedule();
      s.OpportunityLineItemId = product.Id;
      s.Revenue = product.TotalPrice;
      s.Type = 'Revenue';
      s.ScheduleDate = scheduleDate;

      //Added 12/17/2025 by Lauren Fahndrich for Ticket #99923
      if (billIn8Years) {
        s.Finance_Status__c = 'Future';
      }

      scheduleList.add(s);
    }

    // check if there are no existing schedules
    OpportunityLineItemSchedule[] schedules = [
      SELECT Id, IsDeleted, Type
      FROM OpportunityLineItemSchedule
      WHERE IsDeleted = FALSE AND OpportunityLineItemId IN :ProductIds
    ];
    if (!schedules.isEmpty()) {
      System.debug('existing schedules: ' + schedules);
      return 'ERROR There are already some schedules!';
    }
    // there were no existing schedules, so now we can insert our schedules
    insert scheduleList;
    System.debug('SUCCESS number of schedules created: ' + scheduleList.size());
    return 'SUCCESS number of schedules created: ' + scheduleList.size();
  }

  //===========================================================================================================
  webService static String createInvoices(ID opportunityId) {
    Set<ID> ProductIds = new Set<ID>(); // OpportunityLineItems  and products are the same
    Set<ID> Product2Ids = new Set<ID>();
    Set<ID> ProductIdsWithSchedule = new Set<ID>(); // the list of items that have a schedule, should match item_ids

    Map<ID, String> Product2NamesMap = new Map<ID, String>();
    Map<ID, OpportunityLineItem> ProductMap = new Map<ID, OpportunityLineItem>(); // LineItems and product are the same
    Map<ID, String> Product2Map = new Map<ID, String>();

    List<c2g__codaInvoiceLineItem__c> invoiceLineItemsACH = new List<c2g__codaInvoiceLineItem__c>();
    List<c2g__codaInvoiceLineItem__c> invoiceLineItemsCC = new List<c2g__codaInvoiceLineItem__c>();
    List<c2g__codaInvoiceLineItem__c> invoiceLineItemsCHK = new List<c2g__codaInvoiceLineItem__c>();
    List<c2g__codaInvoiceLineItem__c> invoiceLineItemsAUTH = new List<c2g__codaInvoiceLineItem__c>();
    List<OpportunityLineItemSchedule> schedulesCHK = new List<OpportunityLineItemSchedule>();
    List<OpportunityLineItemSchedule> schedulesCC = new List<OpportunityLineItemSchedule>();
    List<OpportunityLineItemSchedule> schedulesACH = new List<OpportunityLineItemSchedule>();
    List<OpportunityLineItemSchedule> schedulesAUTH = new List<OpportunityLineItemSchedule>();

    Map<Date, List<c2g__codaInvoiceLineItem__c>> invoiceLineItemsByDate = new Map<Date, List<c2g__codaInvoiceLineItem__c>>(); // invoice Lines by date
    Map<Date, List<OpportunityLineItemSchedule>> schedulesByDate = new Map<Date, List<OpportunityLineItemSchedule>>(); // schedulesByDate, by date, so we can update them the the invoice name
    Map<Date, String> typeByDate = new Map<Date, String>(); // contains the type of the invoice for that day

    boolean partiallyBilled = false;

    List<ID> OpportunityIdList = new List<ID>();

    // load the opportunity
    Opportunity o = [
      SELECT
        Id,
        Billing_Status__c,
        Invoicing_Method_BILL_TO__c,
        Bill_To__c,
        Account.Id,
        Split_Opportunity__c,
        PO__c,
        Billing_Priority__c,
        Email_Cc__c,
        Billing_Contact__c,
        Billing_Title__c,
        Billing_Address__c,
        Billing_Email__c,
        Primary_Contact__c,
        Primary_Title__c,
        Primary_Address__c,
        Primary_Email__c,
        Special_Billing_Instructions__c,
        Invoice_Description__c,
        OwnerId,
        Sales_Admin__c
      FROM Opportunity
      WHERE Id = :opportunityId
    ];

    // combine it with the split opportunity in a list
    OpportunityIdList.add(opportunityId);
    if (!String.isBlank(o.Split_Opportunity__c))
      OpportunityIdList.add(o.Split_Opportunity__c);

    // get invoice linetitems from the opportunity list and loop over them
    for (OpportunityLineItem product : [
      SELECT Id, Name, Product2Id
      FROM OpportunityLineItem
      WHERE OpportunityId IN :OpportunityIdList
    ]) {
      // make list of ids for mass query, and keep them in an array
      ProductIds.add(product.Id);
      ProductMap.put(product.Id, product);
      Product2Ids.add(product.Product2Id);
    }
    // changed Name to Display_Name__c 7/20/2016
    for (Product2 p2 : [
      SELECT Id, Display_Name__c
      FROM Product2
      WHERE Id IN :Product2Ids
    ]) {
      Product2NamesMap.put(p2.Id, p2.Display_Name__c);
    }

    // get all the schedules for all the opportunity line items
    for (OpportunityLineItemSchedule schedule : [
      SELECT
        Id,
        OpportunityLineItemId,
        Type,
        Revenue,
        Description,
        Quantity,
        ScheduleDate
      FROM OpportunityLineItemSchedule
      WHERE OpportunityLineItemId IN :ProductIds
    ]) {
      ProductIdsWithSchedule.add(schedule.OpportunityLineItemId);

      boolean specialSchedule = false;

      // do a few checks
      if (schedule.Revenue <= 0)
        continue;

      // we only create invoices for today and earlier
      if (schedule.ScheduleDate > Date.today()) {
        partiallyBilled = true;
        continue;
      }

      // skip the schedules that already have a sales invoice number
      if (
        (!String.isBlank(schedule.Description)) &&
        schedule.Description.length() >= 3 &&
        schedule.Description.substring(0, 3) == 'SIN'
      )
        continue;

      // create a Sales Invoice LineItem
      OpportunityLineItem oli = ProductMap.get(schedule.OpportunityLineItemId);
      c2g__codaInvoiceLineItem__c li = new c2g__codaInvoiceLineItem__c(
        Schedule_Comment__c = schedule.Description,
        c2g__UnitPrice__c = schedule.Revenue,
        c2g__DeriveUnitPriceFromProduct__c = false,
        c2g__LineDescription__c = Product2NamesMap.get(oli.Product2Id),
        c2g__Product__c = oli.Product2Id
      );

      // and add it to a list depending on the description
      /*					
		// check for special   schedules witha aprefix:  cc   chk or	
		if(! String.isBlank(schedule.Description) ){
			if(schedule.Description.length() >= 2 && schedule.Description.substring(0,2) == 'CC'){
				invoiceLineItemsCC.add(li);
				schedulesCC.add(schedule);
				specialSchedule = true;	
			} else if(schedule.Description.length() >= 5 && schedule.Description.substring(0,5) == 'CHECK'){
				invoiceLineItemsCHK.add(li);
				schedulesCHK.add(schedule);
				specialSchedule = true;	
			} else if(schedule.Description.length() >= 4 && schedule.Description.substring(0,4) == 'AUTH'){
				invoiceLineItemsAUTH.add(li);
				schedulesAUTH.add(schedule);
				specialSchedule = true;		
			}else if(schedule.Description.length() >= 3 && schedule.Description.substring(0,3) == 'ACH'){
				invoiceLineItemsACH.add(li);
				schedulesACH.add(schedule);
				specialSchedule = true;	
			}
		} 
 */
      // the regular schedules are grouped by date
      //if(! specialSchedule){
      if (!invoiceLineItemsByDate.containsKey(schedule.ScheduleDate)) {
        invoiceLineItemsByDate.put(
          schedule.ScheduleDate,
          new List<c2g__codaInvoiceLineItem__c>()
        );
        schedulesByDate.put(
          schedule.ScheduleDate,
          new List<OpportunityLineItemSchedule>()
        );
        if (!String.isBlank(schedule.Description)) {
          if (
            schedule.Description.length() >= 2 &&
            schedule.Description.substring(0, 2) == 'CC'
          )
            typeByDate.put(schedule.ScheduleDate, 'CC');
          else if (
            schedule.Description.length() >= 5 &&
            schedule.Description.substring(0, 5) == 'CHECK'
          )
            typeByDate.put(schedule.ScheduleDate, 'CHECK');
          else if (
            schedule.Description.length() >= 4 &&
            schedule.Description.substring(0, 4) == 'AUTH'
          )
            typeByDate.put(schedule.ScheduleDate, 'AUTH');
          else if (
            schedule.Description.length() >= 3 &&
            schedule.Description.substring(0, 3) == 'ACH'
          )
            typeByDate.put(schedule.ScheduleDate, 'ACH');
        }
      }

      invoiceLineItemsByDate.get(schedule.ScheduleDate).add(li);
      schedulesByDate.get(schedule.ScheduleDate).add(schedule);
      //}
    }

    // check if all lineitems (products)   had a schedule
    if (ProductIdsWithSchedule.size() < ProductIds.size())
      return 'ERROR Not all products have a schedule'; //-------------------------------->

    List<c2g__codaInvoiceLineItem__c> finalList = new List<c2g__codaInvoiceLineItem__c>();
    List<OpportunityLineItemSchedule> updatedScheduleList = new List<OpportunityLineItemSchedule>();

    // now loop through the invoiceLineItemsByDate and make an invoice for each date
    for (Date theDate : invoiceLineItemsByDate.keySet()) {
      String cwo_type = typeByDate.get(theDate);
      List<c2g__codaInvoiceLineItem__c> lineItems = invoiceLineItemsByDate.get(
        theDate
      );

      String auth_id = null;
      if (cwo_type == 'AUTH') {
        for (c2g__codaInvoiceLineItem__c li : lineItems) {
          auth_id = li.Schedule_Comment__c.substring(4);
        }
      }

      c2g__codaInvoice__c invoice = createInvoice(
        o,
        theDate,
        cwo_type,
        auth_id
      );

      for (c2g__codaInvoiceLineItem__c li : lineItems) {
        li.c2g__Invoice__c = invoice.Id;
        finalList.add(li);
      }

      // add the SIN number to the schedulesByDate
      List<OpportunityLineItemSchedule> slist = schedulesByDate.get(theDate);
      for (OpportunityLineItemSchedule s : slist) {
        s.Description =
          invoice.name +
          '| ' +
          ((String.isBlank(s.Description)) ? '' : s.Description);

        //Added 12/17/2025 by Lauren Fahndrich for Ticket #99923
        s.Finance_Status__c = 'Billed';

        updatedScheduleList.add(s);
      }
    }
    /*	
	// create the special invoices
	 
	if(! invoiceLineItemsCHK.isEmpty()){
		c2g__codaInvoice__c invoice = createInvoice(o, Date.today(), 'CHECK',null);	
		for (c2g__codaInvoiceLineItem__c li : invoiceLineItemsCHK) {
			li.c2g__Invoice__c = invoice.Id;
			finalList.add(li);			
		}			
		for (OpportunityLineItemSchedule s : schedulesCHK){
			s.Description = invoice.name+ '| ' +   ( (String.isBlank(s.Description)) ? '': s.Description);
			updatedScheduleList.add(s);
		}		
	}
	if(! invoiceLineItemsCC.isEmpty()){
		c2g__codaInvoice__c invoice = createInvoice(o, Date.today(),'CC',null);	
		for (c2g__codaInvoiceLineItem__c li : invoiceLineItemsCC) {
			li.c2g__Invoice__c = invoice.Id;
			finalList.add(li);			
		}			
		for (OpportunityLineItemSchedule s : schedulesCC){
			s.Description = invoice.name+ '| ' +   ( (String.isBlank(s.Description)) ? '': s.Description);
			updatedScheduleList.add(s);
		}		
	}
	if(! invoiceLineItemsACH.isEmpty()){
		c2g__codaInvoice__c invoice = createInvoice(o, Date.today(), 'ACH',null);	
		for (c2g__codaInvoiceLineItem__c li : invoiceLineItemsACH) {
			li.c2g__Invoice__c = invoice.Id;
			finalList.add(li);			
		}			
		for (OpportunityLineItemSchedule s : schedulesACH){
			s.Description = invoice.name+ '| ' +   ( (String.isBlank(s.Description)) ? '': s.Description);
			updatedScheduleList.add(s);
		}		
	}
	if(! invoiceLineItemsAUTH.isEmpty()){
		String auth_id;
		for (c2g__codaInvoiceLineItem__c li : invoiceLineItemsAUTH) 
			 auth_id = li.Schedule_Comment__c.substring(4);
			 
		c2g__codaInvoice__c invoice = createInvoice(o, Date.today(), 'AUTH', auth_id);	
		for (c2g__codaInvoiceLineItem__c li : invoiceLineItemsAUTH) {
			li.c2g__Invoice__c = invoice.Id;
			finalList.add(li);			
		}			
		for (OpportunityLineItemSchedule s : schedulesAUTH){
			s.Description = invoice.name+ '| ' +   ( (String.isBlank(s.Description)) ? '': s.Description);
			updatedScheduleList.add(s);
		}		
	}
*/

    insert finalList;
    update updatedScheduleList;

    // now we have to update the opportunity
    o.Billing_Status__c = partiallyBilled
      ? 'Partially Billed'
      : 'Billed in Full';
    update o;

    // and the split opportunity
    if (!String.isBlank(o.Split_Opportunity__c)) {
      Opportunity oSplit = [
        SELECT Id, Billing_Status__c
        FROM Opportunity
        WHERE Id = :o.Split_Opportunity__c
      ];
      oSplit.Billing_Status__c = o.Billing_Status__c;
      update oSplit;
    }

    return 'SUCCESS ' +
      o.Billing_Status__c +
      ',  Number of invoices created: ' +
      numInvoices;
  }

  static private c2g__codaInvoice__c createInvoice(
    Opportunity o,
    Date scheduleDate,
    String cwo_type,
    String auth_id
  ) {
    String invoicing_method = 'Email';
    if (o.Invoicing_Method_BILL_TO__c != '')
      invoicing_method = o.Invoicing_Method_BILL_TO__c;

    c2g__codaInvoice__c invoice = new c2g__codaInvoice__c(
      RecordTypeId = '01214000000AVjd', // in progress
      c2g__InvoiceStatus__c = 'In Progress',
      Invoicing_Method__c = invoicing_method,
      c2g__Account__c = o.Bill_To__c,
      Client__c = o.Account.Id,
      c2g__Opportunity__c = o.Id,
      Split_Opportunity__c = o.Split_Opportunity__c,
      c2g__InvoiceDate__c = scheduleDate,
      PO_Number__c = o.PO__c,
      Billing_Priority__c = o.Billing_Priority__c,
      Email_Cc_SIN__c = o.Email_Cc__c,
      Billing_Contact_IPS__c = o.Billing_Contact__c,
      Billing_Title__c = o.Billing_Title__c,
      Invoice_Billing_Address__c = o.Billing_Address__c.replaceAll(
        '<br>',
        '\n'
      ),
      Billing_Email__c = o.Billing_Email__c,
      Primary_Contact__c = o.Primary_Contact__c,
      Primary_Title__c = o.Primary_Title__c,
      Primary_Contact_Address__c = o.Primary_Address__c.replaceAll(
        '<br>',
        '\n'
      ),
      Primary_Email__c = o.Primary_Email__c,
      Special_Billing_Instructions__c = o.Special_Billing_Instructions__c,
      c2g__InvoiceDescription__c = o.Invoice_Description__c,
      Sales_Rep__c = o.OwnerId,
      Sales_Admin__c = o.Sales_Admin__c,
      //Invoicing_Requirements__c = o.Invoicing_Requirements__c,
      //PO_Finance_Notes__c		= o.PO_Finance_Notes_Opp__c,
      //Terms__c				= o.Terms__c,
      c2g__InvoiceCurrency__c = 'a1F5Y00000DbLhA'
      //c2g__CustomerReference__c  = ?
    );

    if (cwo_type != null)
      invoice.CWO_Type__c = cwo_type;

    if (auth_id != null)
      invoice.Authorize_Net_Transaction_ID__c = auth_id;

    insert invoice;

    invoice = [SELECT Id, Name FROM c2g__codaInvoice__c WHERE Id = :invoice.Id]; // reload invoice to get the name

    numInvoices++;

    return invoice;
  }
}
