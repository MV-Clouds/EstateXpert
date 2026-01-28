public with sharing class ControlCenterController {
    @AuraEnabled(cacheable=true)
    public static List<Control_Center_Feature__mdt> getMetadataRecords(){
        List<Control_Center_Feature__mdt> metadataRecords = [SELECT Id, DeveloperName, isAvailable__c FROM Control_Center_Feature__mdt WITH USER_MODE];
        return metadataRecords;
    }
}