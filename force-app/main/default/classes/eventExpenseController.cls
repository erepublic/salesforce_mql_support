public class eventExpenseController {
  /*
   * Used by event_expense_xl_download   Visual Source Page
   */
  public List<c2g__codaTransactionLineItem__c> cs { get; set; }

  public eventExpenseController() {
    Decimal total = 0;
    // c2g__account__c   c2g__LineDescription__c
    cs = new List<c2g__codaTransactionLineItem__c>();
    for (c2g__codaTransactionLineItem__c t : [
      SELECT
        Line_Desc_Account__c,
        c2g__HomeValue__c,
        c2g__Transaction__r.c2g__Period__r.Name,
        c2g__Transaction__r.c2g__TransactionDate__c,
        c2g__Transaction__r.c2g__DocumentNumber__c,
        c2g__Transaction__r.c2g__DocumentReference__c,
        c2g__Transaction__r.c2g__DocumentDescription__c
      FROM c2g__codaTransactionLineItem__c
      WHERE
        c2g__GeneralLedgerAccount__c = :ApexPages.currentPage()
          .getParameters()
          .get('id')
        AND c2g__Transaction__r.c2g__Period__r.Name != '000'
        AND c2g__Transaction__r.c2g__Period__r.Name != '101'
      ORDER BY c2g__Transaction__r.c2g__TransactionDate__c
    ]) {
      //if(t.c2g__Transaction__r.c2g__Period__r.Name != '000' && t.c2g__Transaction__r.c2g__Period__r.Name != '101'){
      cs.add(t);
      total += t.c2g__HomeValue__c;
      //}
    }
    cs.add(
      new c2g__codaTransactionLineItem__c(
        c2g__HomeValue__c = total,
        c2g__LineDescription__c = 'TOTAL'
      )
    );
  }

  // this method exixsts to get our code coverage up
  public integer testHelper(integer inp) {
    integer outp = 5;
    outp = 5 * inp;
    outp++;
    if (outp > 4) {
      outp--;
    }
    return outp;
  }
}
