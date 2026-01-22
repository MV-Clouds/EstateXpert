public with sharing class ControlCenterController {
    @AuraEnabled(cacheable=true)
    public static List<Control_Center_Feature__mdt> getMetadataRecords(){
        try {
            List<Control_Center_Feature__mdt> metadataRecords = [SELECT Id, DeveloperName, isAvailable__c FROM Control_Center_Feature__mdt WITH USER_MODE];

            if (!metadataRecords.isEmpty()) {
                return metadataRecords;
            } else {
                return new List<Control_Center_Feature__mdt>();
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'ControlCenterController', 'getMetadataRecords', e.getMessage());
            return new List<Control_Center_Feature__mdt>();
        }
    }
}