/**
* Class Name: ObjectConfigController
* Test Class: 
* @description: Used for handling object configuration for webhook class and chat window
* Created Date: 12 Mar, 2025
* Created By: Rachit Shah
**/
public with sharing class ObjectConfigController {
    
    /*
    *********************************************************
    @description     : Method to get objects with phone field.
    @return          : List<Map<String, String>> - return list of objects with phone field.
    ********************************************************
    */
    @AuraEnabled
    public static List<Map<String, String>> getObjectsWithPhoneField() {
        List<Map<String, String>> objectList = new List<Map<String, String>>();
        try {
            // Query FieldDefinition to fetch all objects having at least one Phone field
            List<FieldDefinition> phoneFields = [SELECT EntityDefinition.QualifiedApiName, EntityDefinition.Label, QualifiedApiName FROM FieldDefinition WHERE (DataType = 'Phone' OR DataType = 'Email') AND EntityDefinition.IsCustomizable = true AND EntityDefinition.IsApexTriggerable = true AND EntityDefinition.IsQueryable = true WITH USER_MODE];

            Set<String> processedObjects = new Set<String>();

            // Get Object Descriptions
            Map<String, Schema.SObjectType> schemaMap = Schema.getGlobalDescribe();

            for (FieldDefinition field : phoneFields) {
                String objectName = field.EntityDefinition.QualifiedApiName;
                
                // Ensure object exists in schema description
                if (schemaMap.containsKey(objectName)) {
                    Schema.DescribeSObjectResult objDescribe = schemaMap.get(objectName).getDescribe();

                    // Check field-level permissions
                    if (objDescribe.fields.getMap().containsKey(field.QualifiedApiName)) {
                        Schema.DescribeFieldResult fieldDescribe = objDescribe.fields.getMap().get(field.QualifiedApiName).getDescribe();

                        if (fieldDescribe.isAccessible() && fieldDescribe.isCreateable()) {
                            if (!processedObjects.contains(objectName)) {
                                objectList.add(new Map<String, String>{
                                    'label' => field.EntityDefinition.Label,
                                    'value' => objectName
                                });
                                processedObjects.add(objectName);
                            }
                        }
                    }
                }
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'ObjectConfigController', 'getObjectsWithPhoneField', e.getStackTraceString());
        }
        return objectList;
    }

    /*
    *********************************************************
    @description     : Fetch required fields for the selected object
    @return          : List<Map<String, Object>> - return list of required, phone, and email fields for the selected object.
    ********************************************************
    */
    @AuraEnabled
    public static List<Map<String, Object>> getRequiredFields(String objectName) {
        try {
            List<Map<String, Object>> requiredFields = new List<Map<String, Object>>();
            List<Map<String, String>> phoneFields = new List<Map<String, String>>();
            List<Map<String, String>> textFields = new List<Map<String, String>>();
            List<Map<String, String>> emailFields = new List<Map<String, String>>(); // Added emailFields
            
            Schema.DescribeSObjectResult objectDescribe = Schema.getGlobalDescribe().get(objectName).getDescribe();
            Map<String, Schema.SObjectField> fieldMap = objectDescribe.fields.getMap();
            
            for (Schema.SObjectField field : fieldMap.values()) {
                Schema.DescribeFieldResult fieldDescribe = field.getDescribe();

                // Handle Phone fields
                if (fieldDescribe.getType() == Schema.DisplayType.PHONE && fieldDescribe.isAccessible() && fieldDescribe.isCreateable()) {
                    Map<String, String> phoneFieldInfo = new Map<String, String>();
                    phoneFieldInfo.put('label', fieldDescribe.getLabel());
                    phoneFieldInfo.put('value', fieldDescribe.getName());
                    phoneFields.add(phoneFieldInfo);
                }

                // Handle Text fields (only STRING type, excluding TEXTAREA, LONGTEXTAREA, RICHTEXT)
                if (fieldDescribe.getType() == Schema.DisplayType.STRING && fieldDescribe.isAccessible() && fieldDescribe.isCreateable()) {
                    Map<String, String> textFieldInfo = new Map<String, String>();
                    textFieldInfo.put('label', fieldDescribe.getLabel());
                    textFieldInfo.put('value', fieldDescribe.getName());
                    textFields.add(textFieldInfo);
                }

                // Handle Email fields
                if (fieldDescribe.getType() == Schema.DisplayType.EMAIL && fieldDescribe.isAccessible() && fieldDescribe.isCreateable()) {
                    Map<String, String> emailFieldInfo = new Map<String, String>();
                    emailFieldInfo.put('label', fieldDescribe.getLabel());
                    emailFieldInfo.put('value', fieldDescribe.getName());
                    emailFields.add(emailFieldInfo);
                }

                // Skip fields that shouldn't be included
                if (fieldDescribe.isNillable() || fieldDescribe.isAutoNumber() || !fieldDescribe.isAccessible() || 
                    !fieldDescribe.isCreateable() || fieldDescribe.isCalculated() || fieldDescribe.isExternalId()) {
                    continue;
                } else if (fieldDescribe.getType() == Schema.DisplayType.BOOLEAN) {
                    continue;
                } else if (fieldDescribe.getName() == 'CreatedDate' || fieldDescribe.getName() == 'LastModifiedDate' || 
                           fieldDescribe.getName() == 'SystemModstamp' || fieldDescribe.getName() == 'Id' || 
                           fieldDescribe.getName() == 'CreatedById' || fieldDescribe.getName() == 'LastModifiedById') {
                    continue;
                }
                
                Map<String, Object> fieldInfo = new Map<String, Object>();
                fieldInfo.put('name', fieldDescribe.getName());
                fieldInfo.put('label', fieldDescribe.getLabel());
                fieldInfo.put('type', fieldDescribe.getType().name());
    
                // Handle picklist values
                if (fieldDescribe.getType() == Schema.DisplayType.Picklist) {
                    List<Schema.PicklistEntry> picklistEntries = fieldDescribe.getPicklistValues();
                    List<Map<String, String>> picklistValuesSet = new List<Map<String, String>>();
    
                    for (Schema.PicklistEntry entry : picklistEntries) {
                        Map<String, String> picklistSet = new Map<String, String>();
                        picklistSet.put('label', entry.getLabel());
                        picklistSet.put('value', entry.getValue());
                        picklistValuesSet.add(picklistSet);
                    }
    
                    fieldInfo.put('picklistValues', picklistValuesSet);
                    String defaultValue = fieldDescribe.getDefaultValue() != null ? 
                        String.valueOf(fieldDescribe.getDefaultValue()) : 
                        (picklistValuesSet.isEmpty() ? '' : picklistValuesSet[0].get('value'));
                    fieldInfo.put('value', defaultValue);
                } 
                
                // Handle lookup fields
                else if (fieldDescribe.getType() == Schema.DisplayType.Reference) {
                    String relatedObject = fieldDescribe.getReferenceTo()[0].getDescribe().getName();
                    fieldInfo.put('value', '');
                    fieldInfo.put('relatedObject', relatedObject);
                    fieldInfo.put('relatedRecordName', '');
                }
    
                requiredFields.add(fieldInfo);
            }

            // Create the final response structure
            Map<String, Object> responseMap = new Map<String, Object>();
            responseMap.put('phoneFields', phoneFields);
            responseMap.put('textFields', textFields);
            responseMap.put('emailFields', emailFields); // Added emailFields
            responseMap.put('requiredFields', requiredFields);
            
            List<Map<String, Object>> finalResponse = new List<Map<String, Object>>();
            finalResponse.add(responseMap);
            
            return finalResponse;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'ObjectConfigController', 'getRequiredFields', e.getStackTraceString());
            return null;
        }
    }
    
    /*
    *********************************************************
    @description     : Fetch text, phone, and email fields for the selected object
    @return          : List<Map<String, Object>> - return list of text, phone, and email fields for the selected object.
    ********************************************************
    */
    @AuraEnabled
    public static List<Map<String, Object>> getTextAndPhoneFields(String objectName) {
        try {
            List<Map<String, String>> phoneFields = new List<Map<String, String>>();
            List<Map<String, String>> textFields = new List<Map<String, String>>();
            List<Map<String, String>> emailFields = new List<Map<String, String>>(); // Added emailFields
            
            Schema.DescribeSObjectResult objectDescribe = Schema.getGlobalDescribe().get(objectName).getDescribe();
            Map<String, Schema.SObjectField> fieldMap = objectDescribe.fields.getMap();
            
            for (Schema.SObjectField field : fieldMap.values()) {
                Schema.DescribeFieldResult fieldDescribe = field.getDescribe();

                // Handle Phone fields
                if (fieldDescribe.getType() == Schema.DisplayType.PHONE && fieldDescribe.isAccessible() && 
                    fieldDescribe.isCreateable() && !fieldDescribe.isAutoNumber() && !fieldDescribe.isCalculated()) {
                    Map<String, String> phoneFieldInfo = new Map<String, String>();
                    phoneFieldInfo.put('label', fieldDescribe.getLabel());
                    phoneFieldInfo.put('value', fieldDescribe.getName());
                    phoneFields.add(phoneFieldInfo);
                }

                // Handle Text fields (only STRING type, excluding TEXTAREA, LONGTEXTAREA, RICHTEXT)
                if (fieldDescribe.getType() == Schema.DisplayType.STRING && fieldDescribe.isAccessible() && 
                    fieldDescribe.isCreateable() && !fieldDescribe.isAutoNumber() && !fieldDescribe.isCalculated()) {
                    Map<String, String> textFieldInfo = new Map<String, String>();
                    textFieldInfo.put('label', fieldDescribe.getLabel());
                    textFieldInfo.put('value', fieldDescribe.getName());
                    textFields.add(textFieldInfo);
                }

                // Handle Email fields
                if (fieldDescribe.getType() == Schema.DisplayType.EMAIL && fieldDescribe.isAccessible() && 
                    fieldDescribe.isCreateable() && !fieldDescribe.isAutoNumber() && !fieldDescribe.isCalculated()) {
                    Map<String, String> emailFieldInfo = new Map<String, String>();
                    emailFieldInfo.put('label', fieldDescribe.getLabel());
                    emailFieldInfo.put('value', fieldDescribe.getName());
                    emailFields.add(emailFieldInfo);
                }
            }

            // Create the final response structure
            Map<String, Object> responseMap = new Map<String, Object>();
            responseMap.put('phoneFields', phoneFields);
            responseMap.put('textFields', textFields);
            responseMap.put('emailFields', emailFields); // Added emailFields
            
            // Wrap the response map in a list to match the desired format
            List<Map<String, Object>> finalResponse = new List<Map<String, Object>>();
            finalResponse.add(responseMap);
            
            return finalResponse;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'ObjectConfigController', 'getTextAndPhoneFields', e.getStackTraceString());
            return null;
        }
    }

    /*
    *********************************************************
    @description     : Fetch saved configuration from Custom Metadata
    @return          : Map<String, String> - return JSON strings of configuration.
    ********************************************************
    */
    @AuraEnabled
    public static Map<String, String> getUserConfig() {
        Map<String, String> configMap = new Map<String, String>();
        try {
            List<Object_Config__mdt> config = [SELECT ObjectConfigInfo__c, ChatWindowConfigInfo__c FROM Object_Config__mdt WITH USER_MODE LIMIT 1];
            if(config.size() > 0) {
                configMap.put('ObjectConfigInfo', config[0].ObjectConfigInfo__c);
                configMap.put('ChatWindowConfigInfo', config[0].ChatWindowConfigInfo__c);
            } else {
                configMap.put('ObjectConfigInfo', '{}');
                configMap.put('ChatWindowConfigInfo', '{}');
            }
            return configMap;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'ObjectConfigController', 'getUserConfig', e.getStackTraceString());
            configMap.put('ObjectConfigInfo', '{}');
            configMap.put('ChatWindowConfigInfo', '{}');
        }
        return configMap;
    }

    /*
    *********************************************************
    @description     : Save configuration by updating the same Custom Metadata record
    @return          : String - return status of operation.
    ********************************************************
    */
    @AuraEnabled
    public static String saveUserConfig(String jsonData, String jsonDataForChat) {
        try {
            String devName = 'objectConfigInfo';
            String masterLabel = 'objectConfigInfo';

            List<Object_Config__mdt> configList = [SELECT MasterLabel, DeveloperName, ObjectConfigInfo__c, ChatWindowConfigInfo__c FROM Object_Config__mdt WITH USER_MODE LIMIT 1];
            Object_Config__mdt config = new Object_Config__mdt();

            if (!configList.isEmpty()) {
                config = configList[0];
                devName = config.DeveloperName;
                masterLabel = config.MasterLabel;
            }

            Metadata.CustomMetadata mdata = new Metadata.CustomMetadata();
            mdata.fullName = 'MVEX__Object_Config__mdt.MVEX__' + devName; 
            mdata.label = masterLabel;

            if (jsonData != null) {
                Metadata.CustomMetadataValue instance1 = new Metadata.CustomMetadataValue();
                instance1.field = 'MVEX__ObjectConfigInfo__c';
                instance1.value = jsonData;
                mdata.values.add(instance1);
            }

            if (jsonDataForChat != null) {
                Metadata.CustomMetadataValue instance2 = new Metadata.CustomMetadataValue();
                instance2.field = 'MVEX__ChatWindowConfigInfo__c';
                instance2.value = jsonDataForChat;
                mdata.values.add(instance2);
            }

            Metadata.DeployContainer container = new Metadata.DeployContainer();
            container.addMetadata(mdata);

            Metadata.Operations.enqueueDeployment(container, null);

            return 'Success';
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'ObjectConfigController', 'saveUserConfig', e.getStackTraceString());
            return 'Error: ' + e.getMessage();
        }
    }
    
    /*
    *********************************************************
    @description     : Get record name from record ID.
    @return          : String - return name of the record.
    ********************************************************
    */
    @AuraEnabled
    public static String getRecordName(String recordId, String objectApiName) {
        try {
            if (String.isBlank(recordId) || String.isBlank(objectApiName)) {
                return '';
            }
            List<SObject> records = new List<SObject>();
            String query = 'SELECT Name FROM ' + String.escapeSingleQuotes(objectApiName) + ' WHERE Id = :recordId LIMIT 1';
            records = Database.query(query, AccessLevel.USER_MODE);
            return records.size() != 0 ? (String)records[0].get('Name') : '';
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'ObjectConfigController', 'getRecordName', e.getStackTraceString());
            return '';
        }
    }
}