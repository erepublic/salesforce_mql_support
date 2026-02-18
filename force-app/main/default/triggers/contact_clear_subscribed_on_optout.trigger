/*
 Michael Tel 6/3/2016    Ticket 7707
 This is a trigger to clear out the Subscribed status of Contacts in Salesforce when they opt out globally.  
 This will prevent them from receving an onslaught of email when we get them to opt back in globally later.
  test with contact_before_insert_update_delete_test
*/
trigger contact_clear_subscribed_on_optout on Contact(before update) {
  Set<String> fields = new Set<String>();

  fields.add('Email_Group_Awards_CDE__c');
  fields.add('Email_Group_Awards_CDG__c');
  fields.add('Email_Group_Awards_GOV__c');

  fields.add('Email_Group_Circ_CDE_Digital_Ed__c');
  fields.add('Email_Group_Circ_CDE_Renewal__c');
  fields.add('Email_Group_Circ_EM_Digital_Ed__c');
  fields.add('Email_Group_Circulation_EM_Renewal__c');
  fields.add('Email_Group_Circ_GOV_Digital_Ed__c');
  fields.add('Email_Group_Circ_GOV_Renewal__c');
  fields.add('Email_Group_Circ_GT_Digital_Ed__c');
  fields.add('Email_Group_Circ_GT_Renewal__c');

  fields.add('Email_Group_Events_CDE__c');
  fields.add('Email_Group_Events_CDG__c');
  fields.add('Email_Group_Events_EE__c');
  fields.add('Email_Group_Events_EM__c');
  fields.add('Email_Group_Events_GOV__c');
  fields.add('Email_Group_Events_GT__c');
  fields.add('Email_Group_Events_TW__c');

  fields.add('Email_Group_News_GOV_Market_Insight__c');
  fields.add('Email_Group_News_GOV_Finance__c');
  fields.add('Email_Group_News_GOV_Finance_Weekly__c');
  fields.add('Email_Group_News_GOV_GOV_Daily__c');
  fields.add('Email_Group_News_GOV_Health__c');
  fields.add('Email_Group_News_GOV_Human_Services__c');
  fields.add('Email_Group_News_GOV_Infrastructure__c');
  fields.add('Email_Group_News_GOV_Politics__c');
  fields.add('Email_Group_News_GOV_Future_of_Fin__c');
  fields.add('Email_Group_News_GOV_Future_of_Sec__c');
  fields.add('Email_Group_News_GOV_Future_of_Work__c');
  fields.add('Email_Group_News_GOV_Future_of_Comm__c');

  fields.add('Email_Group_News_GT_Market_Insight__c');
  fields.add('Email_Group_News_GT_Cybersecurity__c');
  fields.add('Email_Group_News_GT_Biz__c');
  fields.add('Email_Group_News_GT_DC__c');
  fields.add('Email_Group_News_GT_EM_News__c');
  fields.add('Email_Group_News_GT_Futurestructure__c');
  fields.add('Email_Group_News_GT_GovTech_Daily__c');
  fields.add('Email_Group_News_GT_Special_Dist__c');
  fields.add('Email_Group_News_GT_AI__c');

  fields.add('Email_Group_News_ER_SLED__c');
  fields.add('Email_Group_News_EM_Market_Insight__c');
  fields.add('Email_Group_News_CDE_Market_Insight__c');
  fields.add('Email_Group_News_CDE_HED__c');
  fields.add('Email_Group_News_CDE_K_12__c');
  fields.add('Email_Group_News_Industry_Insider__c');
  fields.add('Email_Group_News_TW_TW_Weekly__c');
  fields.add('Email_Group_News_NAV_Member__c');
  fields.add('Email_Group_News_NAV_Nav_Blast__c');
  fields.add('Email_Group_News_NAV_Navigator__c');
  fields.add('Email_Group_News_NAV_Prospect__c');

  fields.add('Email_Group_Papers_CDE__c');
  fields.add('Email_Group_Papers_EM__c');
  fields.add('Email_Group_Papers_GOV__c');
  fields.add('Email_Group_Papers_GT__c');
  fields.add('Email_Group_Promo_CDE__c');
  fields.add('Email_Group_Promo_EM__c');
  fields.add('Email_Group_Promo_GOV__c');
  fields.add('Email_Group_Promo_GT__c');
  fields.add('Email_Group_Promo_Partner_Opt_In__c');
  fields.add('Email_Group_Promo_TW__c');
  fields.add('Email_Group_Surveys_GT__c');

  for (Contact c : Trigger.new) {
    Contact oldRec = Trigger.oldMap.get(c.Id);
    if (c.HasOptedOutOfEmail == true && oldRec.HasOptedOutOfEmail == false) {
      for (String field : fields) {
        try {
          String es = (String) c.get(field);
          if (es == 'Subscribed (Internal)' || es == 'Subscribed (Customer)') {
            c.put(field, '');
          }
        } catch (Exception e) {
        }
      }
    }
  }
}
