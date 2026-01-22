/**
* Class Name : DynamicMappingCmp
* Date : 28-07-2024
* Created By : Vyom Soni
* Last Modified Date : 01/01/2025
* Last Modified By : Karan Singh
* @description : Used in the mapFields lwc component
*/
public with sharing class DynamicMappingCmp {
        
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
            Dynamicmapping__mdt metaData = [SELECT Mapping_String__c, Autometic_Sync__c, BlockedFields__c FROM Dynamicmapping__mdt WITH USER_MODE ORDER BY SystemModstamp DESC LIMIT 1];
        
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
            ErrorHandler.insertErrorData(e,'DynamicMappingCmp','getObjectFields' , e.getStackTraceString());
            return null;
        }
   }
   
    /**
    * Method Name : saveMappings
    * @description : save mapping in the of the fields.
    * @param mappingsData String value.
    * @param logicalCondition String value.
    */
    @AuraEnabled
    public static void saveMappings(String mappingsData, String listingLogic, String conditionValueListing, String inquiryLogic, String conditionValueInquiry) {
        try {
            String devName = 'MappingString';
            String masterLabel = 'MappingString';

            List<Dynamicmapping__mdt> metaList = [SELECT MasterLabel, DeveloperName, Mapping_String__c, Listing_Logic__c, Listing_Condition__c, Inquiry_Logic__c, Inquiry_Condition__c FROM Dynamicmapping__mdt WITH USER_MODE ORDER BY SystemModstamp DESC LIMIT 1];

            Dynamicmapping__mdt config = new Dynamicmapping__mdt();

            if (!metaList.isEmpty()) {
                config = metaList[0];
                devName = config.DeveloperName;
                masterLabel = config.MasterLabel;
            }

            Metadata.CustomMetadata mdata = new Metadata.CustomMetadata();
            mdata.fullName = 'MVEX__Dynamicmapping__mdt.'+ devName;
            mdata.label = masterLabel;
            
            Metadata.CustomMetadataValue instance = new Metadata.CustomMetadataValue();
            instance.field = 'MVEX__Mapping_String__c';
            instance.value = mappingsData;
            mdata.values.add(instance);

            Metadata.CustomMetadataValue instance2 = new Metadata.CustomMetadataValue();
            instance2.field = 'MVEX__Listing_Logic__c';
            instance2.value = listingLogic;
            mdata.values.add(instance2);

            Metadata.CustomMetadataValue instance3 = new Metadata.CustomMetadataValue();
            instance3.field = 'MVEX__Listing_Condition__c';
            instance3.value = conditionValueListing;
            mdata.values.add(instance3);


            Metadata.CustomMetadataValue instance4 = new Metadata.CustomMetadataValue();
            instance4.field = 'MVEX__Inquiry_Logic__c';
            instance4.value = inquiryLogic;
            mdata.values.add(instance4);


            Metadata.CustomMetadataValue instance5 = new Metadata.CustomMetadataValue();
            instance5.field = 'MVEX__Inquiry_Condition__c';
            instance5.value = conditionValueInquiry;
            mdata.values.add(instance5);

            Metadata.DeployContainer container = new Metadata.DeployContainer();
            container.addMetadata(mdata);
            
            Metadata.Operations.enqueueDeployment(container, null);

        } catch (Exception e) {
            ErrorHandler.insertErrorData(e,'DynamicMappingCmp','saveMappings' , e.getStackTraceString());
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
            List<Dynamicmapping__mdt> metadataRecords = [SELECT Autometic_Sync__c, MasterLabel, DeveloperName, Mapping_String__c, Listing_Logic__c, Listing_Condition__c, Inquiry_Logic__c, Inquiry_Condition__c From Dynamicmapping__mdt WITH USER_MODE ORDER BY SystemModstamp DESC LIMIT 1];

            // Check if records exist
            if (!metadataRecords.isEmpty()) {
                Dynamicmapping__mdt	 metadataRecord = metadataRecords[0];
                
                // Add field values to the list
                metadataValues.add(metadataRecord.Mapping_String__c != null ? metadataRecord.Mapping_String__c : '');
                metadataValues.add(String.valueOf(metadataRecord.Listing_Logic__c != null ? metadataRecord.Listing_Logic__c : ''));
                metadataValues.add(String.valueOf(metadataRecord.Listing_Condition__c != null ? metadataRecord.Listing_Condition__c : ''));
                metadataValues.add(String.valueOf(metadataRecord.Inquiry_Logic__c != null ? metadataRecord.Inquiry_Logic__c : ''));
                metadataValues.add(String.valueOf(metadataRecord.Inquiry_Condition__c != null ? metadataRecord.Inquiry_Condition__c : ''));
            }

            return metadataValues;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e,'DynamicMappingCmp','getMetadata' , e.getStackTraceString());
            return null;
        }
    }
}