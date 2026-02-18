trigger contact_before_insert_update_delete on Contact(
  after insert,
  before update,
  before delete
) {
  String ids = '';
  String tw_ids = '';
  Set<Id> contactIds = new Set<Id>();
  Boolean isDifferent = false;
  String method = 'download_contact';

  Set<String> tw_fields = new Set<String>();
  tw_fields.add('Email');
  tw_fields.add('FirstName');
  tw_fields.add('LastName');
  tw_fields.add('AccountId');
  tw_fields.add('TW_User_Registered__c');
  tw_fields.add('TW_User_Expired__c');
  tw_fields.add('TW_Send_Welcome_Email__c');
  tw_fields.add('TW_Gets_Newsletter__c');
  tw_fields.add('TW_Member_Type__c');

  Set<String> fields = new Set<String>();
  //  fields.add( 'Email' );
  //  fields.add( 'FirstName' );
  //  fields.add( 'LastName' );
  //  fields.add( 'Account' );
  fields.add('Title');
  fields.add('Company_Name_Holder__c');
  fields.add('RecordType');
  fields.add('Department');
  fields.add('Phone');

  fields.add('MailingStreet');
  fields.add('MailingCity');
  fields.add('MailingState');
  fields.add('MailingCountry');
  fields.add('MailingPostalCode');
  fields.add('Demo_Branch_of_Govt__c');
  fields.add('Demo_Agency_Function__c');
  fields.add('Demo_Job_Function__c');
  fields.add('Demo_Job_Role__c');
  fields.add('Agency_Institution_Size__c');
  fields.add('Demo_Transaction_ID__c');
  fields.add('Demo_Type__c');
  fields.add('Demo_Date__c');
  fields.add('Demo_Refresh__c');
  fields.add('HasOptedOutOfEmail');

  String memberType;

  if (Trigger.isDelete) {
    //delete
    method = 'delete_contact';
    for (Contact oldContact : Trigger.old) {
      ids += ',' + oldContact.Id;
      if (!String.isEmpty(oldContact.TW_Member_Type__c))
        tw_ids += ',' + oldContact.Id;
    }

    if (Trigger.isBefore) {
      for (Contact oldContact : Trigger.old) {
        contactIds.add(oldContact.Id);
      }
    }
  }
  /*	
    else
    {
	    for( Contact newContact : Trigger.new){
	      	//insert
	      	if( Trigger.isInsert ){
	        	ids += ',' + newContact.Id;
	        	if(! String.isEmpty(newContact.TW_Member_Type__c))
      				tw_ids += ',' + newContact.Id;
	      	}
	
	      	//update
			else if( Trigger.isUpdate ){
	      		isDifferent = false;
	      	
	        	Contact oldContact  = Trigger.oldMap.get(newContact.Id);
	
				for( String field : tw_fields ){
				  try{
				    if( newContact.get(field) != oldContact.get(field) ){
				      tw_ids += ',' + newContact.Id;
				      ids 	 += ',' + newContact.Id;
				      isDifferent = true;
				      break;
				    }
				  }
				  catch( Exception e ){  }
				}
				
		        if(!isDifferent)
		        {
			        for( String field : fields ){
			          try{
			            if( newContact.get(field) != oldContact.get(field) ){
			              ids += ',' + newContact.Id;
			              break;
			            }
			          }
			          catch( Exception e ){ }
			        }
		        }      
	      	} //update
	    } //for
    } //else
  
*/

  /*
	if( !contactIds.isEmpty() ) {
		for( Contact c:  [SELECT Id, absorblms__Sync_with_Absorb__c FROM Contact WHERE Id in :contactIds] ) {
			if( c.absorblms__Sync_with_Absorb__c ) {
				for( Contact oldContact: Trigger.old ) {
					if( oldContact.Id == c.Id ) {
						oldContact.addError('deleting for this contact is prevented because Sync with Absorb is checked');
					}
				}
			}
		}
	}
*/
  //if change in contact record AND user is not OneForm admin user, then call URL
  if (
    !String.isEmpty(ids) &&
    !UserInfo.getUserId().contains('005a000000B8cGM') &&
    !Test.isRunningTest()
  ) {
    ids = ids.substring(1);
    String extra = '';
    //  	if(!String.isEmpty(tw_ids))
    //  		extra = '&id_groups[techwire]=' + tw_ids.substring(1);

    oneFormConnector.makeTheCall(ids, method, extra);
  }
}
