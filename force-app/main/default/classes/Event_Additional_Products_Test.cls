@isTest(SeeAllData=true)
public class Event_Additional_Products_Test {
  static testMethod void dummy() {
  }
  /*
	static testMethod void testCreateEventAndReception() {
    	Test.startTest();
        
        // create event.
    	Events__c masterEvent = testData.createEvent(false);
        masterEvent.Nickname__c = 'ME - Nck';
        masterEvent.Name = 'Master Event';
        insert masterEvent; 
        
        // expect that an additional pass pricing record has been created
        Product2 adlPassProd = [SELECT Id,
                                Name, 
                                Display_Name__c, 
                                EE_Event__c, 
                                Product_Type__c, 
                                IsActive, 
                                CanUseRevenueSchedule,
                               	Sponsorship__c,
                                Family
                                FROM Product2
                               	WHERE EE_Event__c = :masterEvent.id
                               	AND Sponsorship__c = 'Additional Pass'];
        // test for standard values.
        System.assertEquals(masterEvent.Name+' - Additional Pass', adlPassProd.Display_Name__c);
        System.assertEquals(masterEvent.Name+' - Additional Pass', adlPassProd.Name);
        System.assertEquals(masterEvent.Id, adlPassProd.EE_Event__c);
        System.assertEquals('EE', adlPassProd.Family);
        System.assertEquals(true, adlPassProd.CanUseRevenueSchedule);
        System.assertEquals('Additional Pass', adlPassProd.Sponsorship__c);
        
        PricebookEntry pbe = [SELECT Product2ID, 
                              Pricebook2ID, 
                              UnitPrice
                              FROM PricebookEntry 
                              WHERE Product2ID = :adlPassProd.Id];
        System.assertEquals(adlPassProd.Id, pbe.Product2ID);
        System.assertEquals(500, pbe.UnitPrice);
        
        // create reception event.
    	Events__c receptionEvent = testData.createEvent(false);
        receptionEvent.Nickname__c = 'ME - NN RC YO';
        receptionEvent.Name = 'Master Event Reception';
        receptionEvent.Parent_Event__c = masterEvent.id;
        insert receptionEvent;
        
        // expect that an additional pass pricing record has been created
        Product2 adlPassProd2 = [SELECT Id,
                                Name, 
                                Display_Name__c, 
                                EE_Event__c, 
                                Product_Type__c, 
                                IsActive, 
                                CanUseRevenueSchedule,
                               	Sponsorship__c,
                                Family
                                FROM Product2
                               	WHERE EE_Event__c = :masterEvent.id
                               	AND Sponsorship__c = 'Additional Reception Pass'];
        // test for standard values.
        System.assertEquals(masterEvent.Name+' - Additional Reception Pass', adlPassProd2.Display_Name__c);
        System.assertEquals(masterEvent.Name+' - Additional Reception Pass', adlPassProd2.Name);
        System.assertEquals(masterEvent.Id, adlPassProd2.EE_Event__c);
        System.assertEquals('EE', adlPassProd2.Family);
        System.assertEquals(true, adlPassProd2.CanUseRevenueSchedule);
        System.assertEquals('Additional Reception Pass', adlPassProd2.Sponsorship__c);
        
        PricebookEntry pbe2 = [SELECT Product2ID, 
                              Pricebook2ID, 
                              UnitPrice
                              FROM PricebookEntry 
                              WHERE Product2ID = :adlPassProd2.Id];
        System.assertEquals(adlPassProd2.Id, pbe2.Product2ID);
        System.assertEquals(500, pbe2.UnitPrice);
        
    	Test.stopTest();
    }
    
    static testMethod void testNameException() {
    	Test.startTest();
        // create event with the 'REG ONLY' flag.
    	Events__c masterEvent = testData.createEvent(false);
        masterEvent.Nickname__c = 'ME - Nck';
        masterEvent.Name = 'Master Event REG ONLY';
        insert masterEvent; 
        
        // expect that the additional passes were NOT created.
        System.assertEquals(true, [SELECT Id
                                FROM Product2
                               	WHERE EE_Event__c = :masterEvent.id
                               	AND Sponsorship__c = 'Additional Pass'].isEmpty());
        
        
    	Test.stopTest();
    }
    
    static testMethod void testDateException() {
    	Test.startTest();
        // create event starting 65 days from now.
    	Events__c masterEvent = testData.createEvent(false);
        masterEvent.Nickname__c = 'ME - Nck';
        masterEvent.Name = 'Master Event';
        masterEvent.Event_Start_Date__c = System.now().addDays(65).date();
        masterEvent.Event_End_Date__c = System.now().addDays(66).date();
        insert masterEvent; 
        
        // expect that the additional passes were NOT created.
        System.assertEquals(true, [SELECT Id
                                FROM Product2
                               	WHERE EE_Event__c = :masterEvent.id
                               	AND Sponsorship__c = 'Additional Pass'].isEmpty());
        
        // create event starting 10 days in the past.
    	Events__c pastEvent = testData.createEvent(false);
        pastEvent.Nickname__c = 'ME - Nck';
        pastEvent.Name = 'Master Event';
        pastEvent.Event_Start_Date__c = System.now().addDays(-1).date();
        insert pastEvent; 
        
        // expect that the additional passes were NOT created.
        System.assertEquals(true, [SELECT Id
                                FROM Product2
                               	WHERE EE_Event__c = :pastEvent.id
                               	AND Sponsorship__c = 'Additional Pass'].isEmpty());
    	Test.stopTest();
    }
	*/
}
