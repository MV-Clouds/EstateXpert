trigger PropertyTrigger on Property__c (after insert, after update, after delete, after undelete, before insert,before update) {
    // if(trigger.isBefore && trigger.isDelete){
    //     PropertyFileTriggerHandler.handleAfterDelete(Trigger.old);
    // }
}