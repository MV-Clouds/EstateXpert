public with sharing class TemplateRestrictTriggerHandler {
    public void publishEvent(String changeType) {
        try {
            Chat_Message__e reactEvent = new Chat_Message__e();
            reactEvent.Type__c = changeType;
            EventBus.publish(reactEvent);
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'TemplateRestrictTriggerHandler', 'publishEvent', e.getMessage());
        }
    }
}