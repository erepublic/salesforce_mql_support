/*
Michael Tel August 2016
Creates a contract from an opportunityLineItem (Product) 

This used through a button on the opportunityLineItem object

Create a custom js button (setup/customize/opportunityLineItem/buttons) with the following script:

{!REQUIRESCRIPT("/soap/ajax/30.0/connection.js")} 
{!REQUIRESCRIPT("/soap/ajax/30.0/apex.js")} 

var lid = "{!OpportunityLineItem.ID__c}" ; 
var msg = sforce.apex.execute("contractFromProduct","createContract",{line_item_id:lid} );
if(msg.indexOf('Error') > -1)
    alert(msg);
else
    location.reload(true);
    */

global class contractFromProduct {
  static Map<String, String> levels = new Map<String, String>{
    '01t140000053tHO' => '(NO LEVEL)',
    '01t140000053qfm' => 'Basic',
    '01t140000053qfr' => 'Basic',
    '01t140000053qfw' => 'Plus',
    '01t140000053qg1' => 'Plus',
    '01t140000053qg6' => 'Premium',
    '01t140000053qgB' => 'Premium',
    '01t14000005MqZQ' => 'Individual Monthly',
    '01t140000053qgG' => '',
    '01t1400000540YA' => '',
    '01t140000053qgL' => 'Basic',
    '01t140000053qgQ' => 'Basic',
    '01t140000053qgV' => 'Plus',
    '01t140000053qga' => 'Plus',
    '01t140000053qgf' => 'Premium',
    '01t140000053qgk' => 'Premium',
    '01t14000005MqZL' => 'Individual Monthly',
    '01t140000053qgp' => ''
  };

  @AuraEnabled
  webService static String createContract(Id line_item_id) {
    OpportunityLineItem l = [
      SELECT Id, Contract__c, OpportunityId, Product2Id
      FROM OpportunityLineItem
      WHERE Id = :line_item_id
    ];

    if (!String.isBlank((String) l.Contract__c))
      return ('ERROR: This opportunity-product already has a contract');

    Opportunity o = [
      SELECT
        Id,
        AccountId,
        Account.Name,
        Primary_Contact__c,
        CloseDate,
        OwnerId,
        Resign_Reminder_Date__c
      FROM Opportunity
      WHERE Id = :l.OpportunityId
    ];
    Product2 p = [
      SELECT
        Id,
        Membership_Status__c,
        Family,
        Contract_Type__c,
        Product_Type__c,
        Event_Type__c,
        EE_Event__c,
        Product_Platform__c,
        Sponsorship__c,
        Event_Passes__c,
        Includes_Badge_Scanner__c
      FROM Product2
      WHERE Id = :l.Product2Id
    ];

    Contract c = new Contract(
      AccountId = o.AccountId,
      CustomerSignedId = o.Primary_Contact__c,
      CustomerSignedDate = o.CloseDate,
      Status = 'Draft',
      Primary_Opportunity__c = o.Id,
      Sales_Rep__c = o.OwnerId,
      Resign_Reminder_Date__c = O.Resign_Reminder_Date__c,
      RecordTypeId = '01214000000AV7y' // type Delivery Contract
    );
    /*
     * Ticket: a0w1O00000ofshBQAQ
     * No longer change the record type on creation.
     * */
    if (p.Product_Type__c == 'Events') {
      c.RecordTypeId = '012a0000001RKA9';
      c.Sales_Rep_Contracts__c = o.OwnerId;
      c.Event__c = p.EE_Event__c;
      c.Type__c = p.Event_Type__c; //p.Family;
      c.Sponsorship_Level__c = p.Sponsorship__c;
      c.Includes_Badge_Scanner__c = p.Includes_Badge_Scanner__c;
      //c.Branding_Guidelines__c= o.Account.Name;
      c.Event_Passes__c = p.Event_Passes__c;
      c.Default_Event_Passes__c = p.Event_Passes__c;
    } else if (p.Product_Type__c == 'Insider') {
      //c.RecordTypeId= '01214000000AUmM';
      c.Sales_Rep_Contracts__c = o.OwnerId;
      c.Membership_Status__c = p.Membership_Status__c;
    } else if (p.Product_Type__c == 'Navigator') {
      //c.RecordTypeId= '012a0000001RS86'; 01214000000AV7y ??
      c.Sales_Rep_Contracts__c = o.OwnerId;
      c.Membership_Status__c = p.Membership_Status__c;
      c.Membership_Level__c = levels.get(p.Id);
      c.Type__c = p.Contract_Type__c;
    }

    insert c;
    l.Contract__c = c.Id;
    update l;
    return ('SUCCESS');
  }
}
