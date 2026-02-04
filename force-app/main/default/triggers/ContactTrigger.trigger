trigger ContactTrigger on Contact (after insert, before insert, before update, after update) {
    try {
        Map<String, Boolean> featureAvailability = new Map<String, Boolean>();
        for (MVEX__Control_Center_Feature__mdt mdt : [
            SELECT DeveloperName, MVEX__isAvailable__c 
            FROM MVEX__Control_Center_Feature__mdt 
            WHERE DeveloperName IN ('Custom_Lead_Assignment', 'Custom_Lead_Welcome_Message') WITH USER_MODE
        ]) {
            featureAvailability.put(mdt.DeveloperName, mdt.MVEX__isAvailable__c);
        }

        Boolean isLeadAssignmentEnabled = featureAvailability.get('Custom_Lead_Assignment');
        Boolean isWelcomeMessageEnabled = featureAvailability.get('Custom_Lead_Welcome_Message');

        if ((Trigger.isBefore && Trigger.isInsert) && isLeadAssignmentEnabled) {
            ContactTriggerHandler.handleLeadAssignment(Trigger.new, null);
        } else if ((Trigger.isBefore && Trigger.isUpdate) && isLeadAssignmentEnabled) {
            ContactTriggerHandler.handleLeadAssignment(Trigger.new, Trigger.oldMap);
        } else if (Trigger.isAfter && isWelcomeMessageEnabled) {
            ContactTriggerHandler.notifyOwner(Trigger.new, Trigger.oldMap);
        }
    } catch (Exception e) {
        String context = Trigger.isBefore ? 'handleLeadAssignment' : 'notifyOwner';
        ErrorHandler.insertErrordata(e, 'ContactTrigger', context, 'Error in trigger execution');
    }
}