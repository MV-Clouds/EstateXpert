trigger TemplateRestrictTrigger on WhatsappTemplate__c (after insert, after update, after delete, after undelete) {
    if (Trigger.isAfter && (Trigger.isInsert || Trigger.isUpdate || Trigger.isDelete || Trigger.isUndelete)) {
        TemplateRestrictTriggerHandler handler = new TemplateRestrictTriggerHandler();
        handler.publishEvent(Trigger.isDelete ? 'delete' : Trigger.isUndelete ? 'undelete' : 'refresh-template');
    }
}