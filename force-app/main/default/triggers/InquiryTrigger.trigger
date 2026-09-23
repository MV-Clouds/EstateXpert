trigger InquiryTrigger on MVEX__Inquiry__c (after insert, after update, after delete, after undelete) {
    if (Trigger.isAfter) {
        InquiryTriggerHandler.publishInquiryChangeEvent();
    }
}
