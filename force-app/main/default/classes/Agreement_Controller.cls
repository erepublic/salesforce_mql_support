/*
{!REQUIRESCRIPT("/soap/ajax/30.0/connection.js")} 
{!REQUIRESCRIPT("/soap/ajax/30.0/apex.js")} 

var cid = "{!Agreement__c.Id}" ; 
var msg = sforce.apex.execute("Agreement_Controller","sendEmail",{agreementId:cid} );
alert(msg);
window.location.reload();
//cms.erepublic.com/common/images/erepublic-cms-logo.png
*/

global class Agreement_Controller {
  @AuraEnabled
  webService static String createLink(Id agreementId) {
    Agreement__c a = [
      SELECT Id, Name, Status__c, Agreement_Link__c
      FROM Agreement__c
      WHERE Id = :agreementId
    ];

    String retString = checkAttachments(agreementId);
    if (retString != 'success')
      return retString;

    // lock the agreement record
    a.RecordTypeId = '01214000001FvYm'; // staging: '0124B0000008rmB'  live: 01214000001FvYm;  // change to locked
    a.Status__c = 'Out for Signature';
    a.Agreement_Link__c = 'https://sf_tools.erepublic.com/agreement?id=' + a.Id;
    a.Unsigned_PDF__c =
      'https://sf_tools.erepublic.com/agreement/submit/?action=PRINT&blank_form=1&id=' +
      a.Id;

    update a;
    return 'success';
  }

  @AuraEnabled
  webService static String sendEmail(Id agreementId) {
    Agreement__c a = [
      SELECT
        Id,
        Name,
        Status__c,
        Email__c,
        Main_Contact__r.Email,
        Description__c,
        Amount__c,
        Email_Cc__c,
        Account__r.Name,
        Email_Message__c,
        Sales_Admin__r.Email,
        Sales_Rep__r.Email,
        Sales_Rep__r.Name,
        Sales_Rep__r.Phone
      FROM Agreement__c
      WHERE Id = :agreementId
    ];

    String retString = checkAttachments(agreementId);
    if (retString != 'success')
      return retString;

    // a.Email_Cc__c is a string of email addresses delimited with ';'
    String[] ccEmails = new List<String>{
      a.Sales_Rep__r.Email,
      a.Sales_Admin__r.Email
    };
    if (a.Email_Cc__c != null && a.Email_Cc__c != '') {
      String emails = a.Email_Cc__c.replaceAll(' ', '');
      for (String s : emails.split(';'))
        ccEmails.add(s);
    }

    // send email
    Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
    msg.setToAddresses(new List<String>{ a.Main_Contact__r.Email });
    msg.setCcAddresses(ccEmails);

    String defaultMsg =
      'Attached is an order form for review / signature.<br>' +
      'Please contact me directly with any questions.<br>' +
      'Thank you for your interest and we look forward to working with you.';

    String email_msg = a.Email_Message__c == null
      ? defaultMsg
      : a.Email_Message__c;

    String body =
      '<div style=" width:100%; background-color: #eaeaea;   font-family: Helvetica,Arial,sans-serif;">' +
      '<table  cellspacing="0"  align="center" border="0" ><tr>' +
      '<td style="background-color:white" width="30" ></td>' +
      '<td style="background-color:white" width="550" >' +
      '<p>' +
      email_msg +
      '</p><p>' +
      'Thank you,<br>' +
      a.Sales_Rep__r.Name +
      '<br>' +
      '<a href="mailto:' +
      a.Sales_Rep__r.Email +
      '"/>' +
      a.Sales_Rep__r.Email +
      '</a><br>' +
      a.Sales_Rep__r.Phone +
      '<br>' +
      '</p>' +
      '<img src="https://media.erepublic.com/image/erepublic-logo.png" width="240"  />' +
      '<p style="line-height:5px"></p>' +
      '<table width="100%" cellpadding="30"  align="center" border="0"><tr><td style=" text-align:center; background-color: #0082c8;  color:white; ">' +
      '<img src="https://media.erepublic.com/image/e-sign-icon-white.png" width="80" height="80"  />' +
      '<p style="margin-top:30px; margin-bottom:20px; font-size:1.2em; ">' +
      a.Sales_Rep__r.Name +
      ' sent you a document to review and sign.</p>' +
      '<table cellpadding="15"  align="center"><tr><td  style="background-color: #f4731f; " >' +
      '<a href="https://sf_tools.erepublic.com/agreement?id=' +
      a.Id +
      '" style="background-color: #f4731f; color:white; font-size:1.3em; text-decoration:none; "  > Review Contract </a>' +
      '</td></tr></table>' +
      '</td></tr></table>' +
      '<p> &nbsp;</p><p> &nbsp;</p>' +
      '</td>' +
      '<td style="background-color:white" width="30" ></td>' +
      '</tr></table>';

    msg.setHtmlBody(body);
    msg.setSubject(
      'Please Sign: Contract #' + a.Name + '- e.Republic / ' + a.Account__r.Name
    );

    Messaging.SingleEmailMessage[] messages = new List<Messaging.SingleEmailMessage>{
      msg
    };
    if (!Test.isRunningTest()) {
      Messaging.SendEmailResult[] results = Messaging.sendEmail(messages);
    }

    // create task with email body
    Id rtid = '01230000000POXx'; //default_task
    date today = date.Today();
    Task task = new Task(
      Subject = 'Email Sent: Out for Signature - ' + today.format(),
      Description = email_msg.stripHtmlTags(),
      ActivityDate = date.Today(),
      Activity_Category__c = 'Written Comm',
      Activity_Type__c = 'E-mail',
      OwnerId = UserInfo.getUserId(),
      WhatId = a.Id,
      RecordTypeId = rtid,
      Status = 'Completed'
    );
    insert task;

    String return_msg = 'success';
    /*
        if (! results[0].success) {
            return_msg = 'The email failed to send: ' + results[0].errors[0].message;
		}
        */

    // lock the agreement record
    a.RecordTypeId = '01214000001FvYm'; // staging: '0124B0000008rmB'  live: 01214000001FvYm;  // change to locked
    a.Status__c = 'Out for Signature';
    a.Agreement_Link__c = 'https://sf_tools.erepublic.com/agreement?id=' + a.Id;

    update a;

    return return_msg;
  }

  static String checkAttachments(Id agreementId) {
    //List<Attachment> alist = [SELECT Id,  Name FROM Attachment WHERE ParentId = :agreementId];
    List<ContentDocumentLink> alist = [
      SELECT ContentDocumentId
      FROM ContentDocumentLink
      WHERE LinkedEntityId = :agreementId
    ];
    if (alist.size() != 1) {
      return 'There needs to be exactly 1 attached File, the details pdf';
    }

    List<ContentDocument> dlist = [
      SELECT Id, FileExtension, Title
      FROM ContentDocument
      WHERE Id = :alist[0].ContentDocumentId
    ];

    if (dlist[0].FileExtension != 'pdf') {
      return 'ERROR: The attached Contract must be a .pdf file. Please re-attach as PDF';
    }
    return 'success';
  }
}
