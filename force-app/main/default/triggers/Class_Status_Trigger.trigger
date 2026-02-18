trigger Class_Status_Trigger on Session_Status__c(after insert, after update) {
  List<Session_Status__c> statusesToCheck = new List<Session_Status__c>();
  for (Session_Status__c status : Trigger.new) {
    if (status.Complete_Pct__c >= 100.0) {
      statusesToCheck.add(status);
    }
  }
  // if a student has completed all sessions, we mark the class as complete
  if (!statusesToCheck.isEmpty()) {
    for (Session_Status__c status : statusesToCheck) {
      Session_Status__c sts = [
        SELECT Class_Session__r.Class__c
        FROM Session_Status__c
        WHERE Id = :status.Id
      ];
      List<Class_Session__c> sessionIds = [
        SELECT Id
        FROM Class_Session__c
        WHERE Class__c = :sts.Class_Session__r.Class__c
      ];
      List<Session_Status__c> statuses = [
        SELECT Id
        FROM Session_Status__c
        WHERE
          Class_Session__c IN :sessionIds
          AND Class_Reg__c = :status.Class_Reg__c
          AND Complete_Pct__c >= 100.0
      ];
      if (sessionIds.size() == statuses.size()) {
        Class_Reg__c student = [
          SELECT Id, Class_Complete__c
          FROM Class_Reg__c
          WHERE Id = :status.Class_Reg__c
        ];
        student.Class_Complete__c = true;
        DateTime dt = Datetime.now();
        student.Completed_At__c = dt;
        update student;
      }
    }
  }

}
