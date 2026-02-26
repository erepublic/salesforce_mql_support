trigger ContactSetToMqlTrigger on Contact(after insert, after update) {
  if (Trigger.isAfter && Trigger.isInsert) {
    ContactSetToMqlTriggerHandler.handleAfterInsert(Trigger.new);
  }

  if (Trigger.isAfter && Trigger.isUpdate) {
    ContactSetToMqlTriggerHandler.handleAfterUpdate(
      Trigger.new,
      Trigger.oldMap
    );
  }
}
