/**
* Class Name : InquiryTriggerHandler
* Created By : Karan Singh
* @description : Trigger handler for Inquiry__c to publish refresh events on DML
*/
public with sharing class InquiryTriggerHandler {

    /**
    * Method Name : publishInquiryChangeEvent
    * @description : Publishes RefreshEvent platform event when an inquiry is created, updated, deleted, or undeleted
    */
    public static void publishInquiryChangeEvent() {
        try {
            PlatformEventController.publishRefreshEvent('Inquiry');
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'InquiryTriggerHandler', 'publishInquiryChangeEvent', 'Failed to publish refresh event: ' + e.getMessage());
        }
    }
}
