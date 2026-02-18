@isTest(SeeAllData=true)
public class QR_Code_Trigger_test {
  static testMethod void testNewFormat() {
    QR_Scan__c qrc4 = new QR_Scan__c(
      App_Scan_ID__c = 12353,
      Data_Scanned__c = '//_T1234567890AB/Clinton Bill',
      Tmp_Scanner_Id__c = '_T1234567888CC',
      Notes__c = ' Nice guy!',
      Scan_Intent__c = 'General',
      Event_or_Conference__c = 'a0m14000007u0JlAAI'
    );
    insert qrc4;
    // new scan with real reg id.
    QR_Scan__c qrc5 = new QR_Scan__c(
      App_Scan_ID__c = 12354,
      Data_Scanned__c = '//a0l1O00000F2KbK/Williams Tim',
      Tmp_Scanner_Id__c = 'a0l1O00000F2HK6',
      Notes__c = 'Why did they let developers in?',
      Scan_Intent__c = 'General',
      Event_or_Conference__c = 'a0m1O000008hQxO'
    );
    insert qrc5;
    // the registrations that are created with the event will have TMPORARY_ID '_T1234567888CC' and '_T1234567890AB'
    Events__c event = testdata.createEventWithRegistrations();

    QR_Scan__c qrc3 = new QR_Scan__c(
      App_Scan_ID__c = 12355,
      Data_Scanned__c = '//_T1234567888CC/Jackson Joe',
      Tmp_Scanner_Id__c = '_T1234567890AB',
      Event_or_Conference__c = event.Id
    );
    insert qrc3;
  }

  static testMethod void testDuplicateQRInsert() {
    // testing old style
    QR_Scan__c qrc = new QR_Scan__c(
      Scanned__c = 'a0l1O00000Eq36UQAR',
      Scanner__c = 'a0l1O00000EqG3eQAF',
      Event_or_Conference__c = 'a0m14000007u0JlAAI'
    );
    insert qrc;

    QR_Scan__c qrc2 = new QR_Scan__c(
      Scanned__c = 'a0l1O00000Eq36UQAR',
      Scanner__c = 'a0l1O00000EqG3eQAF',
      Event_or_Conference__c = 'a0m14000007u0JlAAI'
    );

    try {
      insert qrc2;
      System.assert(false, 'duplicate scan insert not prevented');
    } catch (Exception e) {
      System.assert(
        e.getMessage().contains('duplicate scan insert prevented'),
        true
      );
    }

    QR_Scan__c qrc3 = new QR_Scan__c(
      App_Scan_ID__c = 12355,
      Data_Scanned__c = '//_T1234567888CC/Jackson Joe',
      Tmp_Scanner_Id__c = '_T1234567890AB',
      Event_or_Conference__c = 'a0m14000007u0JlAAI'
    );
    insert qrc3;

    QR_Scan__c qrc4 = new QR_Scan__c(
      App_Scan_ID__c = 12355,
      Data_Scanned__c = '//_T1234567888CC/Jackson Joe',
      Tmp_Scanner_Id__c = '_T1234567890AB',
      Event_or_Conference__c = 'a0m14000007u0JlAAI'
    );
    try {
      insert qrc4;
      System.assert(false, 'duplicate scan insert not prevented');
    } catch (Exception e) {
      System.assert(
        e.getMessage().contains('duplicate scan insert prevented'),
        true
      );
    }
  }
}
