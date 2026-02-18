/*
Michael Tel August 2016
Updates a contract Roles and attachement based on a contract with master_contract__c =true linked to the same opportunity 

This is used through a button on the Contract object

Create a custom js button (setup/customize/contract/buttons) with the following script:

{!REQUIRESCRIPT("/soap/ajax/30.0/connection.js")} 
{!REQUIRESCRIPT("/soap/ajax/30.0/apex.js")} 

var lid = "{!Contract.Id}" ; 
var oid = "{!Contract.Primary_OpportunityId__c}";
var msg = sforce.apex.execute("contractUpdateRoles","updateRolesAndAttachments",{contract_id:lid, opportunity_id:oid } );

if(msg.indexOf('Error') > -1)
	alert(msg);
else
	location.reload(true);
*/

global class contractUpdateRoles {
  @AuraEnabled
  webService static String updateRolesAndAttachments(
    Id contract_id,
    Id opportunity_id
  ) {
    List<ContractContactRole> roles2Insert = new List<ContractContactRole>();
    List<ContentDocumentLink> attachments2Insert = new List<ContentDocumentLink>();

    // get the opportunity
    Contract[] this_contract = [
      SELECT Id, Primary_Opportunity__c
      FROM Contract
      WHERE Id = :contract_id
    ];

    if (this_contract.isEmpty())
      return 'Error: invalid Contract Id ' + contract_id;

    if (String.isBlank(this_contract[0].Primary_Opportunity__c))
      return 'No master contract was found!';

    Id opp_id = this_contract[0].Primary_Opportunity__c;

    // get all master contracts linked to our opportunity
    Contract[] contracts = [
      SELECT
        Id,
        LOI__c,
        Contact_Role_Changes__c,
        Branding_Guidelines__c,
        Website_Manual__c,
        Sales_Rep_Contracts__c,
        StartDate,
        CustomerSignedId
      FROM Contract
      WHERE Master_Contract__c = TRUE AND Primary_Opportunity__c = :opp_id
    ];

    if (contracts.isEmpty())
      return 'Error: No master contract was found!';

    if (contracts.size() > 1)
      return 'Error: More than one master contract was found!';

    Contract c = contracts[0];
    if (c.id == contract_id)
      return 'Error: This record is the master contract !';

    // copy fields from master to current contract
    Contract currrent_contract = new Contract(
      Id = contract_id,
      LOI__c = c.LOI__c,
      Branding_Guidelines__c = c.Branding_Guidelines__c,
      Website_Manual__c = c.Website_Manual__c,
      Sales_Rep_Contracts__c = c.Sales_Rep_Contracts__c,
      StartDate = c.StartDate,
      CustomerSignedId = c.CustomerSignedId,
      Contact_Role_Changes__c = c.Contact_Role_Changes__c
    );
    update currrent_contract;

    // link the atachements to this
    for (ContentDocumentLink a : [
      SELECT ContentDocumentId, ShareType
      FROM ContentDocumentLink
      WHERE LinkedEntityId = :c.Id
    ])
      insert new ContentDocumentLink(
        ContentDocumentId = a.ContentDocumentId,
        LinkedEntityId = contract_id,
        ShareType = a.ShareType
      );

    // insert roles
    for (ContractContactRole r : [
      SELECT Id, ContactId, Role, IsPrimary
      FROM ContractContactRole
      WHERE ContractId = :c.Id
    ])
      insert new ContractContactRole(
        ContractId = contract_id,
        ContactId = r.ContactId,
        Role = r.Role,
        IsPrimary = r.IsPrimary
      );

    return 'Success';
  }
}
