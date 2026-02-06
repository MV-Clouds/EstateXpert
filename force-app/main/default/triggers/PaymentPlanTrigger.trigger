trigger PaymentPlanTrigger on Payment_Plan__c (after insert, after update, after delete) {
    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            PaymentPlanTriggerHandler.handleAfterInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            PaymentPlanTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
        } else if (Trigger.isDelete) {
            PaymentPlanTriggerHandler.handleAfterDelete(Trigger.old);
        }
    }
}