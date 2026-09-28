trigger ContactTrigger on Contact (after insert, before insert, before update, after update, after delete) {
    if (Trigger.isBefore && Trigger.isInsert) {
        ContactTriggerHandler.handleLeadAssignment(Trigger.new, null);
    } else if (Trigger.isAfter) {
        if (Trigger.isInsert || Trigger.isUpdate) {
            ContactTriggerHandler.notifyOwner(Trigger.new, Trigger.oldMap);
        }
        ContactTriggerHandler.publishContactChangeEvent();
    }
}