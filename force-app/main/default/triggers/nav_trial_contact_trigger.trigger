trigger nav_trial_contact_trigger on Contact(
  after insert,
  before delete,
  before update
) {
  /*
    String ids ='';
    String method;
    
    List<Contact> contacts = new List<Contact>();
    if(Trigger.isDelete) // Delete
    {
        for (Contact c : Trigger.old) 
        {       
            if(c.Navigator_Trial_Status__c == 'In progress' )  
            {
                method = 'delete';
                ids += c.id + ',';
            }  
            
            if(c.TW_Trial_Status__c == 'In progress' )  
            {
                method = 'delete';
                ids += c.id + ',';
            } 
            
        }
    }
    else // New insert/update
    {
        for (Contact c : Trigger.new) 
        {       
            if(c.Navigator_Trial_Status__c == 'Cancel')  
            {
                method = 'end_user_trial';
                ids += c.id + ',';
				c.Navigator_Trial_Status__c = 'Canceling';
            }
            else if(c.Navigator_Trial_Status__c == 'Requested')
            {   
                method = 'start_user_trial';
                ids += c.id + ',';
                c.Navigator_Trial_Status__c = 'Starting';   // changing the status so we make no more than 1 call             
            }  
            
             if(c.TW_Trial_Status__c == 'Cancel')  
            {
                method = 'end_user_trial';
                ids += c.id + ',';
				c.TW_Trial_Status__c = 'Canceling';
            }
            else if(c.TW_Trial_Status__c == 'Requested')
            {   
                method = 'start_user_trial';
                ids += c.id + ',';
                c.TW_Trial_Status__c = 'Starting';   // changing the status so we make no more than 1 call             
            }   
            
            
            
        }
    }
    
    if(ids != '')
    {
        navConnector.makeTheCall('user', ids, method); 
    }
 */
}
