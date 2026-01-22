/**
 * Class Name : GoogleLeadFieldMappingController
 * Date : 09-06-2025
 * Created By: Vyom Soni
 * Last Modified Date : 12-06-2025
 * Last Modified By : Vyom Soni
 * @description : Controller for the SocialMediaFieldMapping LWC component
 */
public with sharing class GoogleLeadFieldMappingController {
    
    /**
     * Method Name : getObjectFields
     * @description : Retrieve field data for the Lead object using Schema.
     * @param objectName String value.
     * @return List of field details.
     */
    @AuraEnabled
    public static List<Map<String, String>> getObjectFields(String objectName) {
        try {
            List<Map<String, String>> fieldDetails = new List<Map<String, String>>();    
            Schema.DescribeSObjectResult describeResult = Schema.getGlobalDescribe().get(objectName).getDescribe();
            Map<String, Schema.SObjectField> allFieldsMap = describeResult.fields.getMap();
            
            // Filter out unwritable fields
            Set<String> unwritableFields = new Set<String>();
            for (String fieldName : allFieldsMap.keySet()) {
                if (!allFieldsMap.get(fieldName).getDescribe().isUpdateable()) {
                    unwritableFields.add(fieldName);
                }
            }
            allFieldsMap.keySet().removeAll(unwritableFields);
            
            for (Schema.SObjectField field : allFieldsMap.values()) {
                Schema.DescribeFieldResult fieldDescribe = field.getDescribe();
                Map<String, String> fieldMap = new Map<String, String>();
                fieldMap.put('label', fieldDescribe.getLabel());
                fieldMap.put('apiName', fieldDescribe.getName());
                fieldMap.put('dataType', fieldDescribe.getType().name());
                fieldDetails.add(fieldMap);
            }
            
            return fieldDetails;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'GoogleLeadFieldMappingController', 'getObjectFields', 'Error while getting object fields.');
            return null;
        }
    }
    
    /**
     * Method Name : saveMappings
     * @description : Save field mappings to the appropriate custom metadata type.
     * @param mappingsData String value (JSON string).
     * @param integrationType String value ('Google' or 'Meta').
     */
    @AuraEnabled
    public static void saveMappings(String mappingsData, String integrationType) {
        try {
            String devName = integrationType == 'Meta' ? 'FieldMappings' : 'GoogleLeadMapping';
            String masterLabel = integrationType == 'Meta' ? 'FieldMappings' : 'Google Lead Mapping';
            String metadataType = integrationType == 'Meta' ? 'MVEX__MetaLeadFieldMapping__mdt' : 'MVEX__GoogleLeadFieldMapping__mdt';
            String fieldName = integrationType == 'Meta' ? 'MVEX__FieldMappingJson__c' : 'MVEX__Field_Mappings__c';

            Metadata.CustomMetadata mdata = new Metadata.CustomMetadata();
            mdata.fullName = metadataType + '.' + devName;
            mdata.label = masterLabel;
            
            Metadata.CustomMetadataValue instance = new Metadata.CustomMetadataValue();
            instance.field = fieldName;
            instance.value = mappingsData;
            mdata.values.add(instance);

            Metadata.DeployContainer container = new Metadata.DeployContainer();
            container.addMetadata(mdata);
            
            // Deploy metadata asynchronously
            Metadata.Operations.enqueueDeployment(container, null);
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'GoogleLeadFieldMappingController', 'saveMappings', e.getMessage());
        }
    }

    /**
     * Method Name : getMetadata
     * @description : Retrieve field mappings from the appropriate custom metadata type.
     * @param integrationType String value ('Google' or 'Meta').
     * @return String of JSON mappings.
     */
    @AuraEnabled
    public static String getMetadata(String integrationType) {
        try {
            String metadataType = integrationType == 'Meta' ? 'MVEX__MetaLeadFieldMapping__mdt' : 'MVEX__GoogleLeadFieldMapping__mdt';
            String fieldName = integrationType == 'Meta' ? 'MVEX__FieldMappingJson__c' : 'MVEX__Field_Mappings__c';
            String query = 'SELECT ' + fieldName + ' FROM ' + metadataType + ' ORDER BY SystemModstamp DESC LIMIT 1';
            List<SObject> metadataRecords = Database.query(String.escapeSingleQuotes(query), AccessLevel.USER_MODE);
            
            if (!metadataRecords.isEmpty()) {
                return (String)metadataRecords[0].get(fieldName);
            }
            return null;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'GoogleLeadFieldMappingController', 'getMetadata', 'Error while getting metadata for ' + integrationType);
            return null;
        }
    }

    /**
     * Method Name : getSocialMediaFieldsJson
     * @description : Retrieve the JSON string of social media fields from Form_Fields__mdt.
     * @param integrationType String value ('Google' or 'Meta').
     * @return String of JSON containing social media fields.
     */
    @AuraEnabled
    public static String getSocialMediaFieldsJson(String integrationType) {
        try {
            String fieldName = integrationType == 'Meta' ? 'MVEX__Meta_Ads_Fields__c' : 'MVEX__Google_Ads_Fields__c';
            String query = 'SELECT ' + fieldName + ' FROM MVEX__Form_Fields__mdt LIMIT 1';
            List<SObject> configRecords = Database.query(String.escapeSingleQuotes(query), AccessLevel.USER_MODE);
            
            if (!configRecords.isEmpty()) {
                return (String)configRecords[0].get(fieldName);
            }
            return '[]';
        } catch (Exception e) {
            System.debug('e'+e.getMessage());
            ErrorHandler.insertErrorData(e, 'GoogleLeadFieldMappingController', 'getSocialMediaFieldsJson', 'Error while retrieving ' + integrationType + ' fields.');
            return null;
        }
    }

    /**
     * Method Name : saveSocialMediaFieldsJson
     * @description : Save the JSON string of social media fields to Form_Fields__mdt.
     * @param fieldsJson String value (JSON string of fields).
     * @param integrationType String value ('Google' or 'Meta').
     */
    @AuraEnabled
    public static void saveSocialMediaFieldsJson(String fieldsJson, String integrationType) {
        try {
            String devName = 'Default_Configuration';
            String masterLabel = 'Default_Configuration';
            String fieldName = integrationType == 'Meta' ? 'MVEX__Meta_Ads_Fields__c' : 'MVEX__Google_Ads_Fields__c';

            Metadata.CustomMetadata mdata = new Metadata.CustomMetadata();
            mdata.fullName = 'MVEX__Form_Fields__mdt.' + devName;
            mdata.label = masterLabel;
            
            Metadata.CustomMetadataValue instance = new Metadata.CustomMetadataValue();
            instance.field = fieldName;
            instance.value = fieldsJson;
            mdata.values.add(instance);

            Metadata.DeployContainer container = new Metadata.DeployContainer();
            container.addMetadata(mdata);
            
            // Deploy metadata asynchronously
            Metadata.Operations.enqueueDeployment(container, null);
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'GoogleLeadFieldMappingController', 'saveSocialMediaFieldsJson', 'Error while saving ' + integrationType + ' fields: ' + e.getMessage());
        }
    }
}