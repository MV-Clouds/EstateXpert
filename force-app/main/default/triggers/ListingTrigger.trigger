trigger ListingTrigger on MVEX__Listing__c (after insert, after update, after delete, after undelete, before insert,before update) {
    
    ListingTriggerHandler handler = new ListingTriggerHandler(trigger.new, trigger.old, trigger.newMap, trigger.oldMap, trigger.isInsert,trigger.isUpdate, trigger.isDelete, trigger.isUndelete);

    if (trigger.isAfter) {
        if (trigger.isInsert) {
            handler.afterInsertEvent();
        } else if (trigger.isUpdate) {
            handler.afterUpdateEvent();
        } else if (trigger.isDelete) {
            handler.afterDeleteEvent();
        } else if (trigger.isUndelete) {
            handler.afterUndeleteEvent();
        }
    }
}