/*
 * Gagan Saini March 2019
 * Unlock opportunity when there is no SIN number associated with products in an opportunity
 */

public with sharing class UnlockController {
  private ApexPages.StandardController standardController;
  public String message { get; set; }

  public UnlockController(ApexPages.StandardController standardController) {
    this.standardController = standardController;
  }

  public PageReference unlockOpportunity() {
    // Apex code for handling record from a Detail page goes here
    Id opportunityId = ApexPages.CurrentPage().getparameters().get('id');
    system.debug('opportunityId' + opportunityId);

    boolean canUnlockOpportunity = true;

    // get all the schedules for all the opportunity line items
    for (OpportunityLineItemSchedule schedule : [
      SELECT Id, Description
      FROM OpportunityLineItemSchedule
      WHERE OpportunityLineItem.OpportunityId = :opportunityId
    ]) {
      // Find the schedules that already have a sales invoice number
      if (
        (!String.isBlank(schedule.Description)) &&
        schedule.Description.length() >= 3 &&
        schedule.Description.substring(0, 3) == 'SIN'
      ) {
        // Cannot unlock opportunity
        canUnlockOpportunity = false;
        this.message = 'One or more products on this opportunity have been invoiced. Please submit \'Unlock Opp Request\'.';
        break;
      }
    }

    if (canUnlockOpportunity) {
      // Update RecordType for opportunity to Standard Unlocked
      // load the opportunity
      Opportunity opp = [
        SELECT Id, RecordTypeId
        FROM Opportunity
        WHERE Id = :opportunityId
      ];
      opp.RecordTypeId = '01214000001CDhm';
      this.message = 'Opportunity is unlocked';
      try {
        update opp;
      } catch (Exception e) {
        system.debug('exception' + ' ' + e.getMessage());
      }
    }

    return null;
  }
}
