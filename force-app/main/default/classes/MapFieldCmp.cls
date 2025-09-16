/**
* Class Name : MapFieldCmp
* Date : 28-07-2024
* Created By : Vyom Soni
* Last Modified Date : 03-07-2024
* Last Modified By : Vyom Soni
* @description : Used in the mapFields lwc component
*/
public with sharing class MapFieldCmp {
        
    /**
     * Method Name : getObjectFields
     * @description : get field data using schema builder.
     * @param ObjectApIName String value.
     * @return List of mappings.
     */
    @AuraEnabled
    public static List<Map<String, String>> getObjectFields(String objectName) {
        try {
            List<Map<String, String>> fieldDetails = new List<Map<String, String>>();    
    
            // Query Mapping_Metadata__mdt
            Mapping_Metadata__mdt metaData = [SELECT Mapping_String__c, Automatic_Sync__c, BlockedFields__c FROM Mapping_Metadata__mdt WITH USER_MODE LIMIT 1];
        
            Schema.DescribeSObjectResult describeResult = Schema.getGlobalDescribe().get(objectName).getDescribe();
        
            // Get all fields for the object
            Map<String, Schema.SObjectField> allFieldsMap = describeResult.fields.getMap();
        
            // Get unwritable fields
            Set<String> unwritableFields = new Set<String>();
            for (String fieldName : allFieldsMap.keySet()) {
                if (!allFieldsMap.get(fieldName).getDescribe().isUpdateable()) {
                    unwritableFields.add(fieldName);
                }
            }
    
            allFieldsMap.keySet().removeAll(unwritableFields);
    
            Set<String> blockedFields = new Set<String>();
            if (metaData.BlockedFields__c != null) {
                blockedFields.addAll(new List<String>(metaData.BlockedFields__c.split(';')));
            }

            allFieldsMap.keySet().removeAll(blockedFields);
        
            for (Schema.SObjectField field : allFieldsMap.values()) {
                Schema.DescribeFieldResult fieldDescribe = field.getDescribe();
        
                Map<String, String> fieldMap = new Map<String, String>();
                fieldMap.put('label', fieldDescribe.getLabel());
                fieldMap.put('apiName', fieldDescribe.getName());
        
                // Convert data type enum value to string
                String dataType = fieldDescribe.getType().name();
                fieldMap.put('dataType', dataType);
        
                fieldDetails.add(fieldMap);
            }
        
            return fieldDetails;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'MapFieldCmp', 'getObjectFields', 'Error while getting object fields.');
            return null;
        }

   }
   
   
    /**
     * Method Name : saveMappings
     * @description : save mapping in the of the fields.
     * @param mappingsData String value.
     * @param checkboxValue Boolean value.
     */
    @AuraEnabled
    public static void saveMappings(String mappingsData, Boolean checkboxValue){
        try {
            String devName = 'MappingString';
            String masterLabel = 'MappingString';

            List<Mapping_Metadata__mdt> metaList = [SELECT MasterLabel, DeveloperName, BlockedFields__c FROM Mapping_Metadata__mdt WITH USER_MODE LIMIT 1];

            Mapping_Metadata__mdt config = new Mapping_Metadata__mdt();

            if (!metaList.isEmpty()) {
                config = metaList[0];
                devName = config.DeveloperName;
                masterLabel = config.MasterLabel;
            }

            Metadata.CustomMetadata mdata = new Metadata.CustomMetadata();
            mdata.fullName = 'MVEX__Mapping_Metadata__mdt.' + devName;
            mdata.label = masterLabel;
            
            Metadata.CustomMetadataValue instance = new Metadata.CustomMetadataValue();
            instance.field = 'MVEX__Mapping_String__c';
            instance.value = mappingsData;
            mdata.values.add(instance);

            if (!metaList.isEmpty()) {
                Metadata.CustomMetadataValue instance1 = new Metadata.CustomMetadataValue();
                instance1.field = 'MVEX__BlockedFields__c';
                instance1.value = metaList[0].BlockedFields__c;
                mdata.values.add(instance1);
            }

            Metadata.CustomMetadataValue instance2 = new Metadata.CustomMetadataValue();
            instance2.field = 'MVEX__Automatic_Sync__c';
            instance2.value = checkboxValue;
            mdata.values.add(instance2);

            Metadata.DeployContainer container = new Metadata.DeployContainer();
            container.addMetadata(mdata);
            
            Metadata.Operations.enqueueDeployment(container, null);
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'MapFieldCmp', 'saveMappings', e.getMessage());
        }
    }

     /**
   * Method Name : getMetadata
   * @description : get the fieds pair stirng from the metadata.
   * @return List of string.
   */
    @AuraEnabled
    public static List<String> getMetadata() {
        try {
            List<String> metadataValues = new List<String>();
    
            // Fetch records
            List<Mapping_Metadata__mdt> metadataRecords = [SELECT Mapping_String__c, Automatic_Sync__c FROM Mapping_Metadata__mdt WITH USER_MODE LIMIT 1];
            
            // Check if records exist
            if (!metadataRecords.isEmpty()) {
                Mapping_Metadata__mdt metadataRecord = metadataRecords[0];
                
                // Add field values to the list
                metadataValues.add(metadataRecord.Mapping_String__c);
                metadataValues.add(String.valueOf(metadataRecord.Automatic_Sync__c));
            }
            
            return metadataValues;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'MapFieldCmp', 'getMetadata', 'Error while getting metadata.');
            return null;
        }
    }
}