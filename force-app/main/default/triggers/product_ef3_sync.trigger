trigger product_ef3_sync on Product2(after insert, after update) {
  String comma = '';
  String ids = '';

  for (Product2 p : Trigger.new) {
    if (p.EE_Event__c != null) {
      ids += comma + p.Id;
      comma = ',';
    }
  }

  if (ids.length() > 0) {
    oneFormConnector.makeTheCall(ids, 'downloadSalesForceProduct');
  }
}
