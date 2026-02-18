/**
 *
 * When a new event is created, we automate the insertion of an 'Additional Pass(es)' product
 * because when it does not exist, it breaks the pre-event and onsite registration processes.
 *
 * UPDATE :: 1/29/20
 * This functionality is no longer wanted... We'll see if it causes trouble! ;)
 *
 * */
trigger Event_Additional_Products on Events__c(after update, after insert) {
  /*
	List<Events__c> adlPassNeededEvents = new List<Events__c>();
    List<Events__c> adlReceptionPassNeededEvents = new List<Events__c>();
  	for( Events__c ev : Trigger.new ){
        // -- check the record type of the event, it needs to be a standard event, with a nickname, 
        // without the words 'reg only' and within the next 60 days.
        Date now = System.now().date();
        Date sixtyDays = System.now().date().addDays(60);
        if( String.valueOf(ev.RecordTypeId).substring(0,15) == '01230000000ueuw' 
           	&& !String.isBlank(ev.Nickname__c)
          	&& !ev.Name.toLowerCase().contains('reg only')
          	&& ev.Event_Start_Date__c >= now
          	&& ev.Event_Start_Date__c <= sixtyDays ) {
           	// -- if the event has no parent we add the additional pass product to the event
            if( ev.Parent_Event__c == null && [SELECT Id
                FROM Product2 
                WHERE EE_Event__c = :ev.Id
				AND Sponsorship__c IN ('Additional Event Pass(es)', 'Additional Event Pass', 'Additional Pass')].isEmpty() ) {
                adlPassNeededEvents.add(ev);
            }
            // -- if the event has a parent, we add the reception pass to the event.
            if(ev.Parent_Event__c != null &&
              	[SELECT Id
                FROM Product2 
                WHERE EE_Event__c = :ev.Parent_Event__c
				AND Sponsorship__c IN ('Additional Reception Pass(es)', 'Additional Reception Pass')].isEmpty()) {
                Events__c parent = [SELECT Id, Nickname__c, Name FROM Events__c WHERE Id = :ev.Parent_Event__c];
                adlReceptionPassNeededEvents.add(parent);
            }
        }
    }
    if(! adlPassNeededEvents.isEmpty()) {
        Pricebook2 pb = [select Id from Pricebook2 where Name = 'Standard Price Book'];
        for(Events__c ev : adlPassNeededEvents) {
            Product2 adlPassProd = new Product2(Name = ev.Name+' - Additional Pass',
                                               Display_Name__c = ev.Name+' - Additional Pass',
                                               EE_Event__c = ev.Id,
                                               Family = 'EE',
                                               Event_Type__c = 'EE',
                                               Product_Type__c = 'Events',
                                               CanUseRevenueSchedule = true,
                                               Sponsorship__c = 'Additional Pass');
            insert adlPassProd;
            PricebookEntry pbe = new PricebookEntry (Product2ID=adlPassProd.id,
                                                 Pricebook2ID=pb.Id,
                                                 UnitPrice=500.00,
                                                 IsActive=true);
            insert pbe;
        }
    }
    if(! adlReceptionPassNeededEvents.isEmpty()) {
        Pricebook2 pb = [select Id from Pricebook2 where Name = 'Standard Price Book'];
        for(Events__c ev : adlReceptionPassNeededEvents) {
            Product2 adlPassProd = new Product2(Name = ev.Name+' - Additional Reception Pass',
                                               Display_Name__c = ev.Name+' - Additional Reception Pass',
                                               EE_Event__c = ev.Id,
                                               Family = 'EE',
                                               Event_Type__c = 'EE',
                                               Product_Type__c = 'Events',
                                               CanUseRevenueSchedule = true,
                                               Sponsorship__c = 'Additional Reception Pass');
            insert adlPassProd;
            PricebookEntry pbe = new PricebookEntry (Product2ID=adlPassProd.id,
                                                 Pricebook2ID=pb.Id,
                                                 UnitPrice=500.00,
                                                 IsActive=true);
            insert pbe;
        }
    }
	*/
}
