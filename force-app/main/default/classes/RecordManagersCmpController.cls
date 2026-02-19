public with sharing class RecordManagersCmpController {

    public class RecordManagerData {
        @AuraEnabled public List<FieldDetails> fieldDetailsList;
        @AuraEnabled public List<String> metadataRecords;
    }
    
    public class FieldInfoWrapper {
        @AuraEnabled public String value;
        @AuraEnabled public String label;
    }

    // --- HELPER TO IDENTIFY CONFIGURATION RECORDS ---
    // This maps the frontend "Feature Name" to the stored "Feature Name" in the custom object
    private static String getStoredFeatureName(String objectApiName, String featureName) {
        if (featureName == 'Listing_Configuration' && objectApiName == 'MVEX__Listing__c') {
            return 'Listing_Configuration';
        } else if (featureName == 'Listing_Filter_Config' && objectApiName == 'MVEX__Listing__c') {
            return 'Listing_Filter_Config';
        } else if (featureName == 'Inquiry_Filter_Config' && objectApiName == 'MVEX__Inquiry__c') {
            return 'Inquiry_Filter_Config';
        } else if (objectApiName == 'MVEX__Listing__c') {
            return 'Listing Manager'; 
        } else if (objectApiName == 'MVEX__Inquiry__c') {
            return 'Inquiry Manager';
        } else {
            return 'Marketing List';
        }
    }

    /**
     * Method Name : getObjectFields
     * @description : Get object fields and fetch configuration from Custom Object.
     */
    @AuraEnabled
    public static RecordManagerData getObjectFields(String objectApiName, String featureName) {
        try {
            RecordManagerData recordData = new RecordManagerData();
            List<FieldDetails> fieldDetailsList = new List<FieldDetails>();

            // 1. Get Schema Details
            Schema.DescribeSObjectResult objDescribe = Schema.getGlobalDescribe().get(objectApiName).getDescribe();
            Map<String, Schema.SObjectField> fieldsMap = objDescribe.fields.getMap();

            for (String fieldName : fieldsMap.keySet()) {
                Schema.SObjectField field = fieldsMap.get(fieldName);
                Schema.DescribeFieldResult fieldDescribe = field.getDescribe();

                FieldDetails fieldDetails = new FieldDetails();
                fieldDetails.label = fieldDescribe.getLabel();
                fieldDetails.value = fieldDescribe.getName();
                fieldDetails.fieldType = String.valueOf(fieldDescribe.getType());

                if (fieldDescribe.getType() == Schema.DisplayType.Reference) {
                    List<Schema.SObjectType> referenceTo = fieldDescribe.getReferenceTo();
                    if (!referenceTo.isEmpty()) {
                        fieldDetails.referenceObjectName = referenceTo[0].getDescribe().getName();
                        fieldDetails.relationshipName = fieldDescribe.getRelationshipName();
                    }
                } else {
                    fieldDetails.referenceObjectName = objectApiName;
                }

                if (fieldDescribe.getType() == Schema.DisplayType.Picklist) {
                    List<PicklistValue> picklistValues = new List<PicklistValue>();
                    for (Schema.PicklistEntry picklistEntry : fieldDescribe.getPicklistValues()) {
                        PicklistValue picklistValue = new PicklistValue();
                        picklistValue.label = picklistEntry.getLabel();
                        picklistValue.value = picklistEntry.getValue();
                        picklistValues.add(picklistValue);
                    }
                    fieldDetails.picklistValues = picklistValues;
                }

                fieldDetailsList.add(fieldDetails);
            }
            recordData.fieldDetailsList = fieldDetailsList;

            // 2. Fetch Configuration from Custom Object
            List<String> configValues = new List<String>();
            String storedFeatureName = getStoredFeatureName(objectApiName, featureName);
            
            // Query the generic Custom Object
            List<MVEX__Configuration_Settings__c> settings = [
                SELECT MVEX__Fields_Data__c, MVEX__Page_Size__c 
                FROM MVEX__Configuration_Settings__c 
                WHERE MVEX__Object_API_Name__c = :objectApiName 
                AND MVEX__Feature_Name__c = :storedFeatureName
                WITH USER_MODE 
                LIMIT 1
            ];

            if (!settings.isEmpty()) {
                MVEX__Configuration_Settings__c setting = settings[0];
                configValues.add(setting.MVEX__Fields_Data__c);
                configValues.add(String.valueOf(setting.MVEX__Page_Size__c));
            }

            recordData.metadataRecords = configValues;

            return recordData;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'RecordManagersCmpController', 'getObjectFields', e.getMessage());
            return null;
        }
    }

    /**
     * Method Name : getObjectFieldsWithMetaData
     * @description : Get configuration for "New Record Fields" logic.
     */
    @AuraEnabled
    public static RecordManagerData getObjectFieldsWithMetaData(String objectApiName) {
        try {
            RecordManagerData recordData = new RecordManagerData();
            List<FieldDetails> fieldDetailsList = new List<FieldDetails>();

            Schema.DescribeSObjectResult objDescribe = Schema.getGlobalDescribe().get(objectApiName).getDescribe();
            Map<String, Schema.SObjectField> fieldsMap = objDescribe.fields.getMap();

            for (String fieldName : fieldsMap.keySet()) {
                Schema.SObjectField field = fieldsMap.get(fieldName);
                Schema.DescribeFieldResult fieldDescribe = field.getDescribe();

                FieldDetails fieldDetails = new FieldDetails();
                fieldDetails.label = fieldDescribe.getLabel();
                fieldDetails.value = fieldDescribe.getName();
                fieldDetails.fieldType = String.valueOf(fieldDescribe.getType());

                fieldDetailsList.add(fieldDetails);
            }
            recordData.fieldDetailsList = fieldDetailsList;
            
            List<String> configValues = new List<String>();

            // Query Custom Object for 'New Record Fields' type
            List<MVEX__Configuration_Settings__c> settings = [
                SELECT MVEX__Fields_Data__c 
                FROM MVEX__Configuration_Settings__c 
                WHERE MVEX__Object_API_Name__c = :objectApiName 
                WITH USER_MODE 
                LIMIT 1
            ];

            if (!settings.isEmpty()) {
                configValues.add(settings[0].MVEX__Fields_Data__c);
            }

            recordData.metadataRecords = configValues;

            return recordData;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'RecordManagersCmpController', 'getObjectFieldsWithMetaData', e.getMessage());
            return null;
        }
    }

    public class FieldDetails {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String value { get; set; }
        @AuraEnabled public String fieldType { get; set; }
        @AuraEnabled public String referenceObjectName { get; set; }
        @AuraEnabled public String relationshipName { get; set; }
        @AuraEnabled public List<PicklistValue> picklistValues { get; set; }
    }

    public class PicklistValue {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String value { get; set; }
    }

    /**
     * Method Name : saveMappings
     * @description : Save mappings using standard DML on Custom Object (No Metadata Deploy needed).
     */
    @AuraEnabled
    public static String saveMappings(String checklistData, Integer totalPages, String objectApiName, String featureName) {
        try {
            String storedFeatureName = getStoredFeatureName(objectApiName, featureName);

            // Check if record exists
            List<MVEX__Configuration_Settings__c> settingsList = [
                SELECT Id 
                FROM MVEX__Configuration_Settings__c 
                WHERE MVEX__Object_API_Name__c = :objectApiName 
                AND MVEX__Feature_Name__c = :storedFeatureName
                WITH USER_MODE
                LIMIT 1
            ];

            MVEX__Configuration_Settings__c settingToSave;

            if (!settingsList.isEmpty()) {
                settingToSave = settingsList[0];
            } else {
                settingToSave = new MVEX__Configuration_Settings__c();
                settingToSave.MVEX__Object_API_Name__c = objectApiName;
                settingToSave.MVEX__Feature_Name__c = storedFeatureName;
                // Setting a Name is optional if Auto-Number, but good for reference
                settingToSave.Name = storedFeatureName.replaceAll(' ', '_') + '_' + objectApiName; 
            }

            settingToSave.MVEX__Fields_Data__c = checklistData;
            settingToSave.MVEX__Page_Size__c = totalPages;

            // Perform standard DML
            if (Schema.sObjectType.MVEX__Configuration_Settings__c.isUpdateable() || 
                Schema.sObjectType.MVEX__Configuration_Settings__c.isCreateable()) {
                upsert settingToSave;
            }

            return 'Success';

        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'RecordManagersCmpController', 'saveMappings', e.getStackTraceString());
            throw new AuraHandledException('Error saving settings: ' + e.getMessage());
        }
    }

    /**
     * Method Name : saveMappingsNewFields
     * @description : Save mappings for 'New Record Fields' type using DML.
     */
    @AuraEnabled
    public static String saveMappingsNewFields(String selectFieldsData, String objectApiName) {
        try {
            List<MVEX__Configuration_Settings__c> settingsList = [
                SELECT Id 
                FROM MVEX__Configuration_Settings__c 
                WHERE MVEX__Object_API_Name__c = :objectApiName 
                WITH USER_MODE
                LIMIT 1
            ];

            MVEX__Configuration_Settings__c settingToSave;

            if (!settingsList.isEmpty()) {
                settingToSave = settingsList[0];
            } else {
                settingToSave = new MVEX__Configuration_Settings__c();
                settingToSave.MVEX__Object_API_Name__c = objectApiName;
                settingToSave.Name = 'NewFields_' + objectApiName;
            }

            settingToSave.MVEX__Fields_Data__c = selectFieldsData;

            if (Schema.sObjectType.MVEX__Configuration_Settings__c.isUpdateable() || 
                Schema.sObjectType.MVEX__Configuration_Settings__c.isCreateable()) {
                upsert settingToSave;
            }

            return 'success';
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e,'RecordManagersCmpController','saveMappingsNewFields' , e.getStackTraceString());
            return e.getMessage();
        }
    }

    /**
     * Method Name : getListingFieldsParent
     * @description : Get listing fields excluding blocked ones defined in Global Config.
     */
    @AuraEnabled
    public static List<FieldDetails> getListingFieldsParent(String objectApiName) {
        try {
            List<FieldDetails> fieldDetailsList = new List<FieldDetails>();

            // Fetch Blocked Fields from the "Global Config" record in Custom Object
            List<MVEX__Configuration_Settings__c> configList = [
                SELECT MVEX__Blocked_Fields__c 
                FROM MVEX__Configuration_Settings__c 
                WHERE MVEX__Feature_Name__c = 'Listing Filter Config'
                WITH USER_MODE
                LIMIT 1
            ];

            Set<String> blockedFields = new Set<String>();
            if (!configList.isEmpty() && configList[0].MVEX__Blocked_Fields__c != null) {
                blockedFields.addAll(configList[0].MVEX__Blocked_Fields__c.split(';'));
            }
        
            Schema.DescribeSObjectResult objDescribe = Schema.getGlobalDescribe().get(objectApiName).getDescribe();
            Map<String, Schema.SObjectField> fieldsMap = objDescribe.fields.getMap();
        
            for (String fieldName : fieldsMap.keySet()) {
                if (blockedFields.contains(fieldName)) {
                    continue;
                }
                Schema.SObjectField field = fieldsMap.get(fieldName);
                Schema.DescribeFieldResult fieldDescribe = field.getDescribe();
        
                FieldDetails fieldDetails = new FieldDetails();
                fieldDetails.label = fieldDescribe.getLabel();
                fieldDetails.value = fieldDescribe.getName();
                fieldDetails.fieldType = String.valueOf(fieldDescribe.getType());

                if (fieldDescribe.getType() == Schema.DisplayType.Reference) {
                    List<Schema.SObjectType> referenceTo = fieldDescribe.getReferenceTo();
                    if (!referenceTo.isEmpty()) {
                        fieldDetails.referenceObjectName = referenceTo[0].getDescribe().getName();
                    }
                } else {
                    fieldDetails.referenceObjectName = objectApiName;
                }

                if (fieldDescribe.getType() == Schema.DisplayType.Picklist) {
                    List<PicklistValue> picklistValues = new List<PicklistValue>();
                    for (Schema.PicklistEntry picklistEntry : fieldDescribe.getPicklistValues()) {
                        PicklistValue picklistValue = new PicklistValue();
                        picklistValue.label = picklistEntry.getLabel();
                        picklistValue.value = picklistEntry.getValue();
                        picklistValues.add(picklistValue);
                    }
                    fieldDetails.picklistValues = picklistValues;
                }
                fieldDetailsList.add(fieldDetails);
            }
            return fieldDetailsList;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'RecordManagersCmpController', 'getListingFieldsParent', 'Error while getting listing fields.');
            return null;
        }
    }
}