trigger QR_Code_Trigger on QR_Scan__c(before insert) {
  Map<String, ID> id_map = new Map<String, ID>();
  List<String> tmp_ids = new List<String>();

  for (QR_Scan__c scan : Trigger.new) {
    if (String.isBlank(scan.Tmp_Scanner_Id__c)) {
      // OLD FORMAT SCANS THIS CAN BE REMOVE around Juli 20202
      // uniquenes will be provided by Unique_Id field instead
      if (
        ![
            SELECT Id
            FROM QR_Scan__c
            WHERE
              Scanned__c = :scan.Scanned__c
              AND Scanner__c = :scan.Scanner__c
              AND Scanned_At__c = :scan.Scanned_At__c
          ]
          .isEmpty()
      ) {
        scan.adderror('duplicate scan insert prevented');
      }
      return;
    } else {
      if (
        ![
            SELECT Id
            FROM QR_Scan__c
            WHERE
              App_Scan_ID__c = :scan.App_Scan_ID__c
              AND Scanned_At__c = :scan.Scanned_At__c
          ]
          .isEmpty()
      ) {
        scan.adderror('duplicate scan insert prevented');
      }
    }
    // NEW FORMAT SCANS

    // now we unpack the qr_code_string
    // NEW FORMAT: /contract_id(if_available)/salesforce_reg_id|temporary_id/name/extra
    List<String> parts = scan.Data_Scanned__c.split('/');
    // scan.Event_or_Conference__c= parts[0];
    if (parts[2].startsWith('_T')) {
      scan.Tmp_Scanned_Id__c = parts[2];
      tmp_ids.add(parts[2]);
    } else {
      scan.Scanned__c = parts[2];
    }

    // check  Tmp_Scanner_Id__c to see if it really is a tmp id
    if (scan.Tmp_Scanner_Id__c.startsWith('_T')) {
      tmp_ids.add(scan.Tmp_Scanner_Id__c);
    } else {
      // its not a tmp_id but a real SF_ID
      scan.Scanner__c = scan.Tmp_Scanner_Id__c;
      scan.Tmp_Scanner_Id__c = '';
    }
  }

  if (!tmp_ids.isEmpty()) {
    for (Registration__c r : [
      SELECT Id, Temporary_Id__c
      FROM Registration__c
      WHERE Temporary_Id__c IN :tmp_ids
    ]) {
      id_map.put(r.Temporary_Id__c, r.Id);
    }
    for (QR_Scan__c scan : Trigger.new) {
      if (!String.isBlank(scan.Tmp_Scanner_Id__c)) {
        if (id_map.containsKey(scan.Tmp_Scanner_Id__c))
          scan.Scanner__c = id_map.get(scan.Tmp_Scanner_Id__c);
      }
      if (!String.isBlank(scan.Tmp_Scanned_Id__c)) {
        if (id_map.containsKey(scan.Tmp_Scanned_Id__c))
          scan.Scanned__c = id_map.get(scan.Tmp_Scanned_Id__c);
      }
    }
  }
}
