public class Contact_Interest_Topics {
  public static void addTopics(Contact c, string productTopics) {
    if (productTopics != null && productTopics.length() > 0) {
      List<string> topics = productTopics.split(';');
      List<string> contactTopics = c.Topics_Interested_In__c != null &&
        c.Topics_Interested_In__c.length() > 0
        ? c.Topics_Interested_In__c.split(';')
        : new List<string>();
      for (string topic : topics) {
        if (contactTopics.indexOf(topic) == -1) {
          contactTopics.add(topic);
        }
      }
      c.Topics_Interested_In__c = String.join(contactTopics, ';');
    }
  }
}
