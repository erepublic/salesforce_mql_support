public with sharing class eventSponsorship {
  public ID CompanyID { get; set; }
  public ID LineItemID { get; set; }
  public String CompanyName { get; set; }
  public String Stage { get; set; }
  public Decimal Amount { get; set; }
  public String Level { get; set; }
  public String StageName { get; set; }
  public String Team { get; set; }
  public String ReturningStatus { get; set; }
  public String Owner { get; set; }
  public String AccountOwner { get; set; }

  public eventSponsorship(OpportunityLineItem OpportunityProduct) {
    Integer LengthTruncate = 12;
    CompanyID = OpportunityProduct.Opportunity.AccountId;
    LineItemID = OpportunityProduct.Id;
    if (
      OpportunityProduct.AccountName__c != null &&
      OpportunityProduct.AccountName__c.length() > LengthTruncate
    ) {
      CompanyName = OpportunityProduct.AccountName__c.substring(
        0,
        LengthTruncate
      );
    } else {
      CompanyName = OpportunityProduct.AccountName__c;
    }
    Amount = OpportunityProduct.TotalPrice;
    Stage = OpportunityProduct.Opportunity.StageName;
    if (
      OpportunityProduct.Sponsorship_Level__c != null &&
      OpportunityProduct.Sponsorship_Level__c.length() > LengthTruncate
    ) {
      Level = OpportunityProduct.Sponsorship_Level__c.substring(
        0,
        LengthTruncate
      );
    } else {
      Level = OpportunityProduct.Sponsorship_Level__c;
    }
    StageName = OpportunityProduct.Opportunity.StageName;

    if (
      OpportunityProduct.Team__c != null &&
      OpportunityProduct.Team__c.split(' ', 2).size() == 2
    ) {
      List<String> Parts = OpportunityProduct.Team__c.split(' ', 2);
      Team = Parts[0].substring(0, 1) + Parts[1].substring(0, 1);
    } else {
      Team = OpportunityProduct.Team__c;
    }

    if (
      OpportunityProduct.Opportunity.Owner.Name != null &&
      OpportunityProduct.Opportunity.Owner.Name.split(' ', 2).size() == 2
    ) {
      List<String> Parts = OpportunityProduct.Opportunity.Owner.Name.split(
        ' ',
        2
      );
      Owner = Parts[0].substring(0, 1) + Parts[1].substring(0, 1);
    } else {
      Owner = OpportunityProduct.Opportunity.Owner.Name;
    }

    if (
      OpportunityProduct.Opportunity.Account.Owner.Name != null &&
      OpportunityProduct.Opportunity.Account.Owner.Name.split(' ', 2).size() ==
      2
    ) {
      List<String> Parts = OpportunityProduct.Opportunity.Account.Owner.Name.split(
        ' ',
        2
      );
      AccountOwner = Parts[0].substring(0, 1) + Parts[1].substring(0, 1);
    } else {
      AccountOwner = OpportunityProduct.Opportunity.Account.Owner.Name;
    }

    ReturningStatus = null;
    ReturningStatus = OpportunityProduct.Returning_Status__c;
  }
}
