trigger RegistrationOnUpdate on Registration__c(before insert, before update) {
  /**
   * If a registration record's "Sponsor Company" (Sponsor_Company__c) is updated, and it matches
   * a contract "Sponsorship Name" (Sponsorship_Name__c) we set the contract ID. If not, we give an error.
   * The error should list our all allowed names for the sponsor field.
   *
   * The exception to this rule -- (because there always is one) is if the Reg_Source__c is 'T Team Spreadsheet'
   */
  for (Registration__c r : Trigger.new) {
    Boolean throwContractError = false;
    if (
      r.Event_Contract__c == null && String.isBlank(r.Sponsor_Company__c) &&
      Trigger.isUpdate || r.Event_Contract__c != null
    ) {
      // --> for cases where a contract needs to be deassigned, or is already assigned
    } else {
      if (
        String.isBlank(r.Sponsor_Company__c) &&
        r.Reg_Type__c == 'Sponsor' &&
        r.Reg_Source__c != 'T Team Spreadsheet' &&
        !r.Reg_Advisory_Board__c
      ) {
        throwContractError = true;
      } else if (!String.isBlank(r.Sponsor_Company__c)) {
        List<Contract> contracts = [
          SELECT Id, Sponsorship_Name__c
          FROM Contract
          WHERE
            Event_Passes__c > 0
            AND Sponsorship_Name__c = :r.Sponsor_Company__c
            AND Event__c = :r.Event__c
            AND Status IN ('Draft', 'Activated', 'Updated', 'Editing')
        ];
        if (!contracts.isEmpty()) {
          r.Event_Contract__c = contracts.get(0).Id;
        } else {
          throwContractError = true;
        }
      }
    }

    if (throwContractError) {
      String allowedNames = '';
      List<Contract> contracts = [
        SELECT Id, Sponsorship_Name__c
        FROM Contract
        WHERE
          Event_Passes__c > 0
          AND Event__c = :r.Event__c
          AND Status IN ('Draft', 'Activated', 'Updated', 'Editing')
      ];
      if (!contracts.isEmpty()) {
        for (Contract ct : contracts) {
          allowedNames += ', ' + ct.Sponsorship_Name__c;
        }
        r.addError(
          ' Please supply Sponsor Company that matches one of these contracts ' +
          allowedNames
        );
      }
    }
  }
}
