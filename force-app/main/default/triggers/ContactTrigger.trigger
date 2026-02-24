trigger ContactTrigger on Contact (after insert, before insert, before update, after update) {
    if ((Trigger.isBefore && Trigger.isInsert)) {
        ContactTriggerHandler.handleLeadAssignment(Trigger.new, null);
    } else if ((Trigger.isBefore && Trigger.isUpdate)) {
        ContactTriggerHandler.handleLeadAssignment(Trigger.new, Trigger.oldMap);
    } else if (Trigger.isAfter) {
        ContactTriggerHandler.notifyOwner(Trigger.new, Trigger.oldMap);
    }
}