trigger PropertyTrigger on Property__c (after insert, after update, after delete, after undelete, before insert, before update, before delete) {
    if(trigger.isBefore && trigger.isDelete){
        PropertyFileTriggerHandler.handleAfterDelete(Trigger.old);
    }
}