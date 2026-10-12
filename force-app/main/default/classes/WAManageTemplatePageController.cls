/**
 * @description       : Controller for managing WhatsApp message templates.
 *                      Handles fetching, picklist values, creation, editing, deletion, cloning,
 *                      uploading media, and sending preview WhatsApp message templates (WA_Template__c),
 *                      referencing OAuth_Configuration__mdt for the Whatsapp_OAuth custom metadata record.
 * @author            : Karan Singh
 * @last modified on  : 09/10/2026
 **/
public with sharing class WAManageTemplatePageController {
    
    private static final String CONFIG_DEV_NAME = 'Whatsapp_OAuth';

    @TestVisible
    private static OAuth_Configuration__mdt mockConfig;

    public static String uploadEndpoint;

    // List of allowed fields for polymorphic relationships (like Owner which can be User or Queue)
    public static List<String> polymorphismObjAllowedFields = new List<String>{
        'Alias', 'Email', 'FirstName', 'IsActive', 'LastName', 
        'LastReferencedDate', 'LastViewedDate', 'MiddleName', 'Name', 'Phone', 
        'Profile', 'Suffix', 'Title', 'Type', 'Username', 'UserRole', 'UserRoleId'
    };

    /**
     * @description : Retrieves the WhatsApp OAuth Custom Metadata configuration record for Whatsapp_OAuth
     * @return OAuth_Configuration__mdt
     */
    public static OAuth_Configuration__mdt getConfig() {
        try {
            if (mockConfig != null) {
                return mockConfig;
            }
            List<OAuth_Configuration__mdt> configs = [SELECT Id, DeveloperName, MasterLabel, Client_Id__c, Client_Secret__c, Config_Id__c, API_Version__c, 
                                                        Authorization_Endpoint__c, Token_Endpoint__c, Access_Token__c, Client_App_ID__c, Client_Business_Account_ID__c,
                                                        Client_Phone_Number_ID__c, Connected_Date__c, SystemModstamp FROM OAuth_Configuration__mdt
                                                        WHERE DeveloperName = :CONFIG_DEV_NAME WITH USER_MODE LIMIT 1];
            return configs.isEmpty() ? null : configs[0];
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WAManageTemplatePageController', 'getConfig', e.getMessage());
            return null;
        }
    }

    public static String getAccessToken() {
        OAuth_Configuration__mdt config = getConfig();
        return (config != null && config.Access_Token__c != null) ? config.Access_Token__c : '';
    }

    public static String getApiEndpoint() {
        OAuth_Configuration__mdt config = getConfig();
        return (config != null && String.isNotBlank(config.Authorization_Endpoint__c)) 
                ? config.Authorization_Endpoint__c.removeEnd('/') : 'https://graph.facebook.com';
    }

    public static String getApiVersion() {
        OAuth_Configuration__mdt config = getConfig();
        return (config != null && String.isNotBlank(config.API_Version__c)) 
                ? (config.API_Version__c.trim().startsWithIgnoreCase('v') ? config.API_Version__c.trim() : 'v' + config.API_Version__c.trim()) : 'v24.0';
    }

    public static String getBusinessAccountId() {
        OAuth_Configuration__mdt config = getConfig();
        return (config != null && config.Client_Business_Account_ID__c != null) ? config.Client_Business_Account_ID__c : '';
    }

    public static String getPhoneNumberId() {
        OAuth_Configuration__mdt config = getConfig();
        return (config != null && config.Client_Phone_Number_ID__c != null) ? config.Client_Phone_Number_ID__c : '';
    }

    public static String getAppId() {
        OAuth_Configuration__mdt config = getConfig();
        return (config != null && config.Client_App_ID__c != null) ? config.Client_App_ID__c : '';
    }

    /**
     * @description : Method to check if WhatsApp business account is configured using OAuth_Configuration__mdt
     * @return Boolean
     */
    @AuraEnabled(cacheable=true)
    public static Boolean hasBusinessAccountId() {
        try {
            OAuth_Configuration__mdt config = getConfig();
            return config != null && String.isNotBlank(config.Client_Business_Account_ID__c);
        } catch (Exception e) {
            return false;
        }
    }

    /*
    *********************************************************
    @description     : Used in waTemplateHomePage / template list to get all WA_Template__c records.
    @return          : List<WA_Template__c>
    ********************************************************
    */
    @AuraEnabled
    public static List<WA_Template__c> getWhatsAppTemplates() {
        try {
            List<WA_Template__c> templates = [SELECT Id, Name, Template_Id__c, Template_Name__c, Template_Category__c,
                                                toLabel(Language__c) LanguageLabel,
                                                File_Name__c, Image_Header_Handle__c, Status__c,
                                                LastModifiedById, LastModifiedDate, CreatedDate
                                                FROM WA_Template__c
                                                WITH USER_MODE
                                                ORDER BY LastModifiedDate DESC LIMIT 50000];
            return templates;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WAManageTemplatePageController', 'getWhatsAppTemplates', e.getMessage());
            return new List<WA_Template__c>();
        }
    }

    /*
    *********************************************************
    @description     : Send preview message using OAuth_Configuration__mdt configuration.
    @param           : jsonData - Serialized preview message payload
    @return          : errorMessage
    ********************************************************
    */
    @AuraEnabled
    public static String sendPreviewTemplate(String jsonData) {
        String errorMessage = null;
        try {
            OAuth_Configuration__mdt config = getConfig(); 
            if (config == null || String.isBlank(config.Access_Token__c) || String.isBlank(config.Client_Phone_Number_ID__c)) {
                errorMessage = 'WhatsApp configuration is missing or incomplete in Custom Metadata.';
                return errorMessage;
            }

            String token = getAccessToken();
            String endpoint = getApiEndpoint() + '/' + getApiVersion() + '/' + getPhoneNumberId() + '/messages';

            HttpRequest httpReq = new HttpRequest();
            httpReq.setEndpoint(endpoint);
            httpReq.setMethod('POST');
            httpReq.setHeader('Content-Type', 'application/json');
            httpReq.setHeader('Authorization', 'Bearer ' + token);
            httpReq.setBody(jsonData);

            Http http = new Http();
            HttpResponse response = http.send(httpReq);
            Integer statusCode = response.getStatusCode();
            if (statusCode != 200) {
                errorMessage = 'Failed to send Template';
                ErrorHandler.insertErrordata(null, 'WAManageTemplatePageController', 'sendPreviewTemplate', 'API Exception while sending preview message: ' + response.getBody());
            }

        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WAManageTemplatePageController', 'sendPreviewTemplate', e.getMessage());
        }
        return errorMessage;
    }

    /*
    *********************************************************
    @description     : Used to fetch all the fields related to object name
    @param           : objectName
    @return          : List<String> fieldNames
    ********************************************************
    */
    @AuraEnabled
    public static List<String> getObjectFields(String objectName) {
        List<String> fieldNames = new List<String>();
        try {
            Schema.DescribeSObjectResult objDescribe = Schema.getGlobalDescribe().get(objectName).getDescribe();
            Map<String, Schema.SObjectField> fieldsMap = objDescribe.fields.getMap();
            for (String fieldName : fieldsMap.keySet()) {
                fieldNames.add(fieldsMap.get(fieldName).getDescribe().getName()); 
            }
            fieldNames.sort();
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WAManageTemplatePageController', 'getObjectFields', e.getMessage());
        }
        return fieldNames;
    }

    /*
    *********************************************************
    @description     : Method to fetch fields for objects with optional relationship paths.
    @param           : objectNames - List of object API names to fetch fields for
                       relationshipPaths - Optional list of relationship paths
    @return          : Map<String, List<FieldOption>>
    ********************************************************
    */
    @AuraEnabled
    public static Map<String, List<FieldOption>> getObjectFieldsWithRelationships(List<String> objectNames, List<String> relationshipPaths) {
        Map<String, List<FieldOption>> resultMap = new Map<String, List<FieldOption>>();
        
        try {
            if (objectNames == null || objectNames.isEmpty()) {
                return resultMap;
            }
            
            Set<String> uniqueObjects = new Set<String>(objectNames);
            Boolean hasRelationshipPaths = relationshipPaths != null && !relationshipPaths.isEmpty();
            
            if (hasRelationshipPaths && uniqueObjects.size() == 1) {
                String objectName = new List<String>(uniqueObjects)[0];
                Set<String> uniquePaths = new Set<String>(relationshipPaths);
                
                for (String path : uniquePaths) {
                    try {
                        if (String.isBlank(path)) {
                            continue;
                        }
                        List<FieldOption> fieldOptions = getFieldsAtPath(objectName, path);
                        resultMap.put(path, fieldOptions);
                    } catch (Exception e) {
                        ErrorHandler.insertErrordata(e, 'WAManageTemplatePageController', 'getObjectFieldsWithRelationships', 'Error fetching fields for path ' + path);  
                        resultMap.put(path, new List<FieldOption>());
                    }
                }
            } else {
                for (String objectName : uniqueObjects) {
                    try {
                        if (String.isBlank(objectName)) {
                            continue;
                        }
                        List<FieldOption> fields = getFieldsAtPath(objectName, '');
                        resultMap.put(objectName, fields);
                    } catch (Exception e) {
                        ErrorHandler.insertErrordata(e, 'WAManageTemplatePageController', 'getObjectFieldsWithRelationships', 'Error fetching fields for object ' + objectName);
                        resultMap.put(objectName, new List<FieldOption>());
                    }
                }
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WAManageTemplatePageController', 'getObjectFieldsWithRelationships', e.getMessage());
            throw new AuraHandledException('Error fetching fields: ' + e.getMessage());
        }
        
        return resultMap;
    }

    private static List<FieldOption> getFieldsAtPath(String objectName, String relationshipPath) {
        String[] pathParts = relationshipPath.split('\\.');
        String currentObjectName = objectName;
        Boolean isPolymorphicPath = false;
        
        for (String part : pathParts) {
            Schema.DescribeSObjectResult objDescribe = Schema.getGlobalDescribe().get(currentObjectName).getDescribe();
            Map<String, Schema.SObjectField> fieldsMap = objDescribe.fields.getMap();
            
            for (String fieldName : fieldsMap.keySet()) {
                Schema.DescribeFieldResult fieldDescribe = fieldsMap.get(fieldName).getDescribe();
                String relationshipName = fieldDescribe.getRelationshipName();
                
                if (relationshipName == part) {
                    List<Schema.sObjectType> referenceTo = fieldDescribe.getReferenceTo();
                    if (!referenceTo.isEmpty()) {
                        if (referenceTo.size() > 1) {
                            isPolymorphicPath = true;
                        }
                        currentObjectName = referenceTo[0].getDescribe().getName();
                        break;
                    }
                }
            }
        }
        
        return getFieldsImmediate(currentObjectName, relationshipPath, isPolymorphicPath);
    }

    private static List<FieldOption> getFieldsImmediate(String objectName, String prefix, Boolean isPolymorphicParent) {
        List<FieldOption> fieldOptions = new List<FieldOption>();
        Set<String> allowedFieldsSet = new Set<String>(polymorphismObjAllowedFields);
        
        try {
            Schema.DescribeSObjectResult objDescribe = Schema.getGlobalDescribe().get(objectName).getDescribe();
            Map<String, Schema.SObjectField> fieldsMap = objDescribe.fields.getMap();
            
            for (String fieldName : fieldsMap.keySet()) {
                Schema.DescribeFieldResult fieldDescribe = fieldsMap.get(fieldName).getDescribe();
                String fieldApiName = fieldDescribe.getName();
                String fieldLabel = fieldDescribe.getLabel();
                Schema.DisplayType fieldType = fieldDescribe.getType();
                
                if (isPolymorphicParent) {
                    if (allowedFieldsSet.contains(fieldApiName)) {
                        String fullPath = String.isNotBlank(prefix) ? prefix + '.' + fieldApiName : fieldApiName;
                        FieldOption option = new FieldOption();
                        option.label = fieldLabel;
                        option.value = fullPath;
                        option.apiName = fieldApiName;
                        option.type = String.valueOf(fieldType);
                        option.isRelationship = false;
                        option.level = 0;
                        option.hasChildren = false;
                        fieldOptions.add(option);
                    }
                    continue;
                }
                
                String fullPath = String.isNotBlank(prefix) ? prefix + '.' + fieldApiName : fieldApiName;
                FieldOption option = new FieldOption();
                option.label = fieldLabel;
                option.value = fullPath;
                option.apiName = fieldApiName;
                option.type = String.valueOf(fieldType);
                option.isRelationship = false;
                option.level = 0;
                option.hasChildren = false;
                fieldOptions.add(option);
                
                if (fieldType == Schema.DisplayType.REFERENCE) {
                    List<Schema.sObjectType> referenceTo = fieldDescribe.getReferenceTo();
                    if (!referenceTo.isEmpty()) {
                        String relationshipName = fieldDescribe.getRelationshipName();
                        if (String.isNotBlank(relationshipName)) {
                            String relatedObjectName = referenceTo[0].getDescribe().getName();
                            String relatedObjectLabel = referenceTo[0].getDescribe().getLabel();
                            Boolean isPolymorphic = referenceTo.size() > 1;
                            
                            FieldOption relOption = new FieldOption();
                            relOption.label = fieldLabel + ' (' + relatedObjectLabel + ')';
                            relOption.value = String.isNotBlank(prefix) ? prefix + '.' + relationshipName : relationshipName;
                            relOption.apiName = relationshipName;
                            relOption.relationshipName = relationshipName;
                            relOption.type = 'RELATIONSHIP';
                            relOption.isRelationship = true;
                            relOption.level = 0;
                            relOption.hasChildren = true;
                            relOption.relatedObject = relatedObjectName;
                            relOption.isPolymorphic = isPolymorphic;
                            relOption.children = new List<FieldOption>();
                            
                            fieldOptions.add(relOption);
                        }
                    }
                }
            }
            
            fieldOptions.sort();
            
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WAManageTemplatePageController', 'getFieldsImmediate', e.getMessage());
        }
        
        return fieldOptions;
    }

    public class FieldOption implements Comparable {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String value { get; set; }
        @AuraEnabled public String apiName { get; set; }
        @AuraEnabled public String type { get; set; }
        @AuraEnabled public Boolean isRelationship { get; set; }
        @AuraEnabled public Integer level { get; set; }
        @AuraEnabled public Boolean hasChildren { get; set; }
        @AuraEnabled public String relatedObject { get; set; }
        @AuraEnabled public String relationshipName { get; set; }
        @AuraEnabled public Boolean isPolymorphic { get; set; }
        @AuraEnabled public List<FieldOption> children { get; set; }
        
        public FieldOption() {
            this.children = new List<FieldOption>();
            this.hasChildren = false;
            this.isRelationship = false;
            this.isPolymorphic = false;
        }
        
        public Integer compareTo(Object compareTo) {
            FieldOption compareToField = (FieldOption)compareTo;
            if (label == compareToField.label) return 0;
            if (label > compareToField.label) return 1;
            return -1;
        }
    }

    /*
    *********************************************************
    @description     : Fetch records based on the object name
    @param           : objectName
    @return          : List<sObject>
    ********************************************************
    */
    @AuraEnabled
    public static List<sObject> getRecordsBySObject(String objectName) {
        List<sObject> records = new List<sObject>();
        try {
            String query = 'SELECT Id, Name, Phone FROM ' + String.escapeSingleQuotes(objectName) + ' WHERE Phone != null LIMIT 200';           
            records = Database.query(query, AccessLevel.USER_MODE);
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WAManageTemplatePageController', 'getRecordsBySObject', e.getMessage());
        }
        return records;
    }

    /*
    *********************************************************
    @description     : Fetches template data and variable mapping using WA_Template__c and WA_Template_Variable__c.
    @param           : templateId
    @return          : TemplateDataWrapper
    ********************************************************
    */
    @AuraEnabled(cacheable=true)
    public static TemplateDataWrapper getDynamicObjectData(Id templateId) {
        TemplateDataWrapper wrapper = new TemplateDataWrapper();
        Set<String> objectNames = new Set<String>();
        Set<String> fieldNames = new Set<String>();
        wrapper.templateVariables = new List<Map<String, String>>();

        try {
            List<WA_Template__c> templates = [
                SELECT Id, Name, Template_Name__c, Button_Body__c, Status__c, Image_Header_Handle__c, Template_Id__c, Button_Label__c, Button_Type__c, File_Name__c,
                    Footer_Body__c, Header_Body__c, Header_Type__c, Language__c, Template_Body__c, 
                    Template_Category__c, Template_Miscellaneous_Data__c
                FROM WA_Template__c 
                WHERE Id = :templateId
                WITH USER_MODE
                ORDER BY LastModifiedDate DESC
                LIMIT 1
            ];

            if (templates.isEmpty()) {
                return wrapper; 
            }

            WA_Template__c template = templates[0];
            wrapper.template = template;

            if (template.Header_Type__c == 'Image' || template.Header_Type__c == 'Video' || template.Header_Type__c == 'Document') {
                wrapper.isImgUrl = true;
            }

            List<WA_Template_Variable__c> templateVariables = [
                SELECT Name, Object_Name__c, Field_Name__c, Type__c, Alternate_Text__c
                FROM WA_Template_Variable__c 
                WHERE WA_Template__c = :template.Id WITH USER_MODE
            ];

            if (!templateVariables.isEmpty()) {
                for (WA_Template_Variable__c variable : templateVariables) {
                    Map<String, String> mapping = new Map<String, String>();
                    mapping.put('type', variable.Type__c);
                    mapping.put('variable', variable.Name);
                    mapping.put('objName', variable.Object_Name__c);
                    mapping.put('alternateText', variable.Alternate_Text__c);
                    mapping.put('fieldName', variable.Field_Name__c);
                    wrapper.templateVariables.add(mapping);

                    objectNames.add(variable.Object_Name__c);
                    fieldNames.add(variable.Field_Name__c);
                }

                wrapper.objectNames = new List<String>(objectNames);
                wrapper.fieldNames = new List<String>(fieldNames);
            }

        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WAManageTemplatePageController', 'getDynamicObjectData', e.getMessage());
        }

        return wrapper;
    }

    /*
    *********************************************************
    @description     : Fetch records based on the dynamic object name, fieldname and recordid
    @param           : objectName, fieldNames, recordId
    @return          : Map<String, Object>
    ********************************************************
    */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> fetchDynamicRecordData(String objectName, List<String> fieldNames, String recordId) {
        Map<String, Object> resultMap = new Map<String, Object>();

        try {
            if (String.isEmpty(objectName) || fieldNames.isEmpty() || String.isEmpty(recordId)) {
                ErrorHandler.insertErrordata(null, 'WAManageTemplatePageController', 'fetchDynamicRecordData', 'Object name, field names or record ID cannot be empty.');
                throw new AuraHandledException('Invalid input parameters');
            }

            if (!fieldNames.contains('Phone')) {
                fieldNames.add('Phone');
            }
            String fields = String.join(fieldNames, ',');
            
            String queryString = 'SELECT ' + fields + ' FROM ' + String.escapeSingleQuotes(objectName) + ' WHERE Id = :recordId LIMIT 1';            
            List<SObject> queriedData = Database.query(queryString);

            if (!queriedData.isEmpty()) {
                resultMap.put('queriedData', queriedData[0]);  
            } else {
                resultMap.put('queriedData', null);
            }

        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WAManageTemplatePageController', 'fetchDynamicRecordData', e.getMessage());
            resultMap.put('error', e.getMessage());
        }

        return resultMap;
    }
   
    /*
    *********************************************************
    @description     : Replaces template variables from backend to handle sending of template variable using WA_Template__c.
    @param           : templateId, contactId
    @return          : Map<String, Object>
    ********************************************************
    */
    @AuraEnabled
    public static Map<String, Object> getTemplateDataWithReplacement(String templateId, String contactId) {
        try {
            Map<String, Object> templateData = new Map<String, Object>();
            List<WA_Template__c> templates = [SELECT Id, Name, Template_Name__c, Button_Body__c, Button_Label__c, Button_Type__c, Image_Header_Handle__c, 
                                                Footer_Body__c, Header_Body__c, Header_Type__c, Language__c, File_Name__c, 
                                                Template_Body__c, Template_Category__c, 
                                                Template_Variable_Count__c, Template_Miscellaneous_Data__c,
                                                (SELECT Id, Name, Field_Name__c, Object_Name__c, Type__c, Alternate_Text__c 
                                                    FROM WA_Template_Variables__r ORDER BY Name ASC) 
                                            FROM WA_Template__c 
                                            WHERE Id = :templateId 
                                            WITH USER_MODE];
            if (templates.size() > 0) {
                WA_Template__c template = templates[0];

                if (template.WA_Template_Variables__r.size() > 0) {
                    List<Object> headerVariables = new List<Object>();
                    List<Object> bodyVariables = new List<Object>();

                    if (String.isNotBlank(contactId)) {
                        Set<String> fieldSelectionCause = new Set<String>();
                        for (WA_Template_Variable__c tv : template.WA_Template_Variables__r) {
                            if (tv.Object_Name__c == 'Contact') {
                                fieldSelectionCause.add(tv.Field_Name__c);
                            } else {
                                fieldSelectionCause.add(tv.Object_Name__c + '.' + tv.Field_Name__c);
                            }
                        }

                        if (fieldSelectionCause.size() > 0) {
                            String query = 'SELECT Id, ' + String.join(fieldSelectionCause, ', ') + ' FROM Contact WHERE Id =:contactId';
                            List<Contact> contacts = Database.query(query);
                            if (contacts.size() > 0) {
                                Contact contactRecord = contacts[0];
                                for (WA_Template_Variable__c tv : template.WA_Template_Variables__r) {
                                    Object valueToReplace = '';
                                    if (tv.Object_Name__c == 'Contact') {
                                        valueToReplace = contactRecord.get(tv.Field_Name__c);
                                    } else {
                                        valueToReplace = contactRecord.getSObject(tv.Object_Name__c) != null ? 
                                                        contactRecord.getSObject(tv.Object_Name__c).get(tv.Field_Name__c) : null;
                                    }
                                    
                                    if (tv.Type__c == 'Header') {
                                        String replacement = (valueToReplace != null ? valueToReplace.toString() : 
                                                                (tv.Alternate_Text__c != null ? tv.Alternate_Text__c : ''));
                                    
                                        headerVariables.add(replacement);
                                        template.Header_Body__c = template.Header_Body__c != null ? template.Header_Body__c.replace(tv.Name, replacement) : '';
                                    } else if (tv.Type__c == 'Body') {
                                        String replacement = (valueToReplace != null ? valueToReplace.toString() : 
                                                                (tv.Alternate_Text__c != null ? tv.Alternate_Text__c : ''));
                                    
                                        bodyVariables.add(replacement);
                                        template.Template_Body__c = template.Template_Body__c != null ? template.Template_Body__c.replace(tv.Name, replacement) : '';
                                    }
                                }
                            }
                        }
                    } else {
                        for (WA_Template_Variable__c tv : template.WA_Template_Variables__r) {
                            if (tv.Type__c == 'Header') {
                                headerVariables.add(tv.Alternate_Text__c != null ? tv.Alternate_Text__c : '{{' + tv.Name + '}}');
                                template.Header_Body__c = template.Header_Body__c != null ? template.Header_Body__c.replace(tv.Name, 
                                                            tv.Alternate_Text__c != null ? tv.Alternate_Text__c : '{{' + tv.Name + '}}') : '';
                            } else if (tv.Type__c == 'Body') {
                                bodyVariables.add(tv.Alternate_Text__c != null ? tv.Alternate_Text__c : tv.Name);
                                template.Template_Body__c = template.Template_Body__c != null ? template.Template_Body__c.replace(tv.Name, 
                                                            tv.Alternate_Text__c != null ? tv.Alternate_Text__c : tv.Name) : '';
                            }
                        }
                    }

                    templateData.put('template', template);
                    templateData.put('headerParams', headerVariables);
                    templateData.put('bodyParams', bodyVariables);
                } else {
                    templateData.put('template', template);
                }

                return templateData;
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WAManageTemplatePageController', 'getTemplateDataWithReplacement', e.getMessage());
        }
        return null;
    }
   
    /*
    *********************************************************
    @description     : Get picklist values for Template_Category__c and Status__c from WA_Template__c.
    @return          : Map<String, List<String>>
    ********************************************************
    */
    @AuraEnabled(cacheable=true)
    public static Map<String, List<String>> getCategoryAndStatusPicklistValues() {
        Map<String, List<String>> picklistValues = new Map<String, List<String>>();
        List<String> categoryValues = new List<String>();
        List<String> statusValues = new List<String>();

        try {
            Schema.DescribeFieldResult categoryFieldResult = WA_Template__c.Template_Category__c.getDescribe();
            for (Schema.PicklistEntry entry : categoryFieldResult.getPicklistValues()) {
                categoryValues.add(entry.getLabel());
            }

            Schema.DescribeFieldResult statusFieldResult = WA_Template__c.Status__c.getDescribe();
            for (Schema.PicklistEntry entry : statusFieldResult.getPicklistValues()) {
                statusValues.add(entry.getLabel());
            }

            picklistValues.put('categories', categoryValues);
            picklistValues.put('statuses', statusValues);

            return picklistValues;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WAManageTemplatePageController', 'getCategoryAndStatusPicklistValues', e.getMessage());
            return null;
        }
    }

    /*
    *********************************************************
    @description     : Callout to create template in Meta Graph API and save WA_Template__c.
    @param           : serializedWrapper, payloadWrapper, templateName
    @return          : Map<String, Object>
    ********************************************************
    */
    @AuraEnabled
    public static Map<String, Object> createWhatsappTemplate(String serializedWrapper, String payloadWrapper, String templateName) {
        Map<String, Object> response = new Map<String, Object>();

        try {
            String wabaId = getBusinessAccountId();
            if (String.isBlank(wabaId)) {
                response.put('success', false);
                response.put('errorMessage', 'Business Account ID is not configured in Custom Metadata (OAuth_Configuration__mdt).');
                return response;
            }

            WATemplateWrapper.TemplateWrapper templateWrapper = (WATemplateWrapper.TemplateWrapper) JSON.deserialize(serializedWrapper, WATemplateWrapper.TemplateWrapper.class);
            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(payloadWrapper);

            String endpoint = getApiEndpoint() + '/' + getApiVersion() + '/' + wabaId + '/message_templates';
            String token = getAccessToken();
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + token);
            req.setBody(JSON.serialize(payload));
    
            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                Id templateId = WATemplateWrapper.handleSuccessResponse((String) responseMap.get('id'), (String) responseMap.get('status'), payload, templateWrapper);
                response.put('success', true);
                response.put('templateId', templateId); 
            } else {
                response.put('success', false);
                response.put('errorMessage', res.getBody());

                if (String.isNotBlank(templateWrapper.tempImgId)) {
                    List<ContentVersion> versions = [
                        SELECT ContentDocumentId 
                        FROM ContentVersion 
                        WHERE Id = :templateWrapper.tempImgId 
                        WITH USER_MODE 
                        LIMIT 1
                    ];

                    if (!versions.isEmpty() && Schema.sObjectType.ContentDocument.isDeletable()) {
                        delete new ContentDocument(Id = versions[0].ContentDocumentId);
                    }
                }

                ErrorHandler.insertErrordata(null, 'WAManageTemplatePageController', 'createWhatsappTemplate', 'HTTP callout failed with status: ' + res.getStatusCode() + ' - ' + res.getBody());
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WAManageTemplatePageController', 'createWhatsappTemplate', e.getMessage());
            if (e instanceof CalloutException && e.getMessage().containsIgnoreCase('Read timed out')) {
                response.put('success', false);
                response.put('status', 'warning');
                response.put('message', 'Template is being created, you will be notified once it is ready.');
                checkTemplateExistance(templateName, serializedWrapper, payloadWrapper);
            } else {
                response.put('success', false);
                response.put('status', 'error');
                response.put('message', e.getMessage());
            }
        }

        return response;
    }

    @future(callout=true)
    @AuraEnabled
    public static void checkTemplateExistance(String templateName, String serializedWrapper, String payloadWrapper) {
        try {
            String wabaId = getBusinessAccountId();
            if (String.isBlank(wabaId)) return;

            String endpoint = getApiEndpoint() + '/' + getApiVersion() + '/' + wabaId + '/message_templates?name=' + EncodingUtil.urlEncode(templateName, 'UTF-8');
            String token = getAccessToken();
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('GET');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + token);

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                List<Object> dataList = (List<Object>) responseMap.get('data');

                if (!dataList.isEmpty()) {
                    Map<String, Object> templateData = (Map<String, Object>) dataList[0];
                    String metaTemplateId = (String) templateData.get('id');
                    String metaTempStatus = (String) templateData.get('status');

                    WATemplateWrapper.TemplateWrapper templateWrapper = (WATemplateWrapper.TemplateWrapper) JSON.deserialize(serializedWrapper, WATemplateWrapper.TemplateWrapper.class);
                    Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(payloadWrapper);

                    Id templateId = WATemplateWrapper.handleSuccessResponse(metaTemplateId, metaTempStatus, payload, templateWrapper);

                    if (templateId != null) {
                        try {
                            Schema.SObjectType eventType = Schema.getGlobalDescribe().get('MVEX__Template_Update__e');
                            if (eventType == null) {
                                eventType = Schema.getGlobalDescribe().get('Template_Update__e');
                            }
                            if (eventType != null) {
                                sObject fetchAllTemplatesEvent = eventType.newSObject();
                                Map<String, Schema.SObjectField> fieldMap = eventType.getDescribe().fields.getMap();
                                if (fieldMap.containsKey('Fetch_All_Templates__c')) {
                                    fetchAllTemplatesEvent.put('Fetch_All_Templates__c', true);
                                } else if (fieldMap.containsKey('MVEX__Fetch_All_Templates__c')) {
                                    fetchAllTemplatesEvent.put('MVEX__Fetch_All_Templates__c', true);
                                }
                                EventBus.publish(fetchAllTemplatesEvent);
                            }
                        } catch (Exception peEx) {
                            System.debug('Could not publish template update event: ' + peEx.getMessage());
                        }
                    } else {
                        ErrorHandler.insertErrordata(null, 'WAManageTemplatePageController', 'checkTemplateExistance', 'Template Id not found in checkTemplateExistance for template ' + templateName);
                    }
                }
            } else {
                ErrorHandler.insertErrordata(null, 'WAManageTemplatePageController', 'checkTemplateExistance', 'API Call failed: ' + res.getStatusCode() + ' - ' + res.getBody());
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WAManageTemplatePageController', 'checkTemplateExistance', e.getMessage());
        }
    }

    /*
    *********************************************************
    @description     : Method to get session Id for uploading file to Meta using OAuth_Configuration__mdt.
    @param           : fileName, fileLength, fileType
    @return          : sessionId
    ********************************************************
    */
    @AuraEnabled
    public static String startUploadSession(String fileName, Integer fileLength, String fileType) {
        try {
            String appId = getAppId();
            if (String.isBlank(appId)) {
                return 'Application ID is not configured in Custom Metadata (OAuth_Configuration__mdt).';
            }

            Map<String, Object> payload = new Map<String, Object>();
            payload.put('file_name', fileName);
            payload.put('file_length', fileLength);
            payload.put('file_type', fileType);

            uploadEndpoint = getApiEndpoint() + '/' + getApiVersion() + '/' + appId + '/uploads';
            String token = getAccessToken();

            HttpRequest req = new HttpRequest();
            Http http = new Http();
            req.setEndpoint(uploadEndpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'OAuth ' + token);
            req.setBody(JSON.serialize(payload));

            HttpResponse res = http.send(req);
            if (res.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                String sessionId = (String) responseMap.get('id');
                if (sessionId != null && sessionId.startsWith('upload:')) {
                    sessionId = sessionId.replace('upload:', ''); 
                }
                return sessionId; 
            } else {
                ErrorHandler.insertErrordata(null, 'WAManageTemplatePageController', 'startUploadSession', 'HTTP callout failed with status: ' + res.getStatusCode() + ' - ' + res.getBody());
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WAManageTemplatePageController', 'startUploadSession', e.getMessage());
        }
        return null;
    }        

    /*
    *********************************************************
    @description     : Method to upload file chunk to Meta and get file handle.
    @param           : serializedWrapper, isAWSEnabled
    @return          : headerHandle JSON
    ********************************************************
    */
    @AuraEnabled
    public static String uploadFileChunk(String serializedWrapper, Boolean isAWSEnabled) {
        try {
            FileChunkWrapper fileWrapper = (FileChunkWrapper) JSON.deserialize(serializedWrapper, FileChunkWrapper.class);
            Blob fileBlob = EncodingUtil.base64Decode(fileWrapper.fileContent);

            HttpRequest req = new HttpRequest();
            Http http = new Http();

            String endpoint = getApiEndpoint() + '/' + getApiVersion() + '/upload:' + fileWrapper.uploadSessionId;
            String token = getAccessToken();

            req.setEndpoint(endpoint);
            req.setMethod('POST');            
            req.setHeader('Authorization', 'OAuth ' + token);
            req.setHeader('file_offset', String.valueOf(fileWrapper.chunkStart));
            req.setHeader('Content-Type', 'application/octet-stream');
            req.setBodyAsBlob(fileBlob);

            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200 || res.getStatusCode() == 206) {
                String resBody = res.getBody();
                Map<String, Object> responseMap = String.isNotBlank(resBody) ? (Map<String, Object>) JSON.deserializeUntyped(resBody) : null;
                
                Boolean isPartialRequest = false;
                if (responseMap != null && responseMap.containsKey('debug_info')) {
                    Map<String, Object> debugInfo = (Map<String, Object>) responseMap.get('debug_info');
                    if (debugInfo != null && debugInfo.get('type') == 'PartialRequestError') {
                        isPartialRequest = true;
                    }
                }

                if (responseMap != null && (responseMap.containsKey('error') || (responseMap.containsKey('debug_info') && !isPartialRequest))) {
                    ErrorHandler.insertErrordata(null, 'WAManageTemplatePageController', 'uploadFileChunk', 'Meta upload chunk error (' + res.getStatusCode() + '): ' + resBody);
                    return '';
                }

                String headerHandle = (responseMap != null && responseMap.containsKey('h')) ? (String) responseMap.get('h') : '';
                return JSON.serialize(new Map<String, String>{
                    'headerHandle' => headerHandle
                });
            } else {
                ErrorHandler.insertErrordata(null, 'WAManageTemplatePageController', 'uploadFileChunk', 'HTTP callout failed with status: ' + res.getStatusCode() + ' - ' + res.getBody());
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WAManageTemplatePageController', 'uploadFileChunk', e.getMessage());
        }
        return '';
    }
     
    /*
    *********************************************************
    @description     : Method used to delete WA_Template__c from Meta as well as from Salesforce.
    @param           : templateId
    @return          : Return the success or error message. 
    ********************************************************
    */
    @AuraEnabled
    public static String deleteTemplete(String templateId) {
        try {
            WA_Template__c wbTempRec = [SELECT Id, Name, Template_Name__c, Status__c, Template_Id__c FROM WA_Template__c WHERE Id = :templateId WITH USER_MODE LIMIT 1];

            // If template is Draft or hasn't been created in Meta, delete directly from Salesforce without Meta callout
            if (wbTempRec.Status__c == 'Draft' || wbTempRec.Status__c == 'DRAFT' || String.isBlank(wbTempRec.Template_Id__c) || wbTempRec.Template_Id__c == 'DRAFT') {
                if (WA_Template__c.sObjectType.getDescribe().isDeletable()) {
                    delete wbTempRec;
                }
                return 'Template deleted successfully';
            }

            String wabaId = getBusinessAccountId();
            if (String.isBlank(wabaId)) {
                return 'Business Account ID is not configured in Custom Metadata (OAuth_Configuration__mdt).';
            }
            
            String endpoint = getApiEndpoint() + '/' + getApiVersion() + '/' + wabaId + '/message_templates?name=' + wbTempRec.Template_Name__c;
            String token = getAccessToken();

            HttpRequest req = new HttpRequest();         
            req.setEndpoint(endpoint);
            req.setMethod('DELETE');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + token);
            Http http = new Http();
            HttpResponse res = http.send(req);

            Integer statusCode = res.getStatusCode();
            Boolean shouldDeleteFromSF = false;
            String returnMessage = '';

            if (statusCode == 400 && res.getBody().contains('Message template not found')) {
                shouldDeleteFromSF = true;
                returnMessage = 'Template not found in Meta and deleted from Salesforce successfully';                
            } else if (statusCode == 404) {
                shouldDeleteFromSF = true;
                returnMessage = 'Template not found in Meta and deleted from Salesforce successfully';
            } else if (statusCode == 200) {
                Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                Boolean success = (Boolean) jsonResponse.get('success');
                if (success) {
                    shouldDeleteFromSF = true;
                    returnMessage = 'Template deleted successfully';
                } else {
                    ErrorHandler.insertErrordata(null, 'WAManageTemplatePageController', 'deleteTemplete', res.getBody());
                    returnMessage = 'Template deletion failed in Meta';
                }
            } else {
                ErrorHandler.insertErrordata(null, 'WAManageTemplatePageController', 'deleteTemplete', res.getBody());
                returnMessage = 'Template deletion failed with status: ' + statusCode;
            }

            if (shouldDeleteFromSF && WA_Template__c.sObjectType.getDescribe().isDeletable()) {
                delete wbTempRec;
            }

            return returnMessage;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WAManageTemplatePageController', 'deleteTemplete', e.getMessage());
            return e.getMessage();
        }
    }

    /*
    *********************************************************
    @description     : Callout to edit template in Meta and update WA_Template__c.
    @param           : serializedWrapper, payloadWrapper, templateId, templateName
    @return          : Map<String, Object>
    ********************************************************
    */
    @AuraEnabled
    public static Map<String, Object> editWhatsappTemplate(String serializedWrapper, String payloadWrapper, String templateId, String templateName) {
        Map<String, Object> response = new Map<String, Object>();
        HttpResponse res = new HttpResponse();

        try {
            WATemplateWrapper.TemplateWrapper templateWrapper = (WATemplateWrapper.TemplateWrapper) JSON.deserialize(serializedWrapper, WATemplateWrapper.TemplateWrapper.class);

            String editEndpoint = getApiEndpoint() + '/' + getApiVersion() + '/' + templateId;
            String token = getAccessToken();

            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(payloadWrapper);
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(editEndpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + token);
            req.setBody(JSON.serialize(payload));
    
            Http http = new Http();
            res = http.send(req);

            if (res.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                Id updatedTemplateId = WATemplateWrapper.handleSuccessResponse((String) responseMap.get('id'), (String) responseMap.get('status'), payload, templateWrapper);
                response.put('success', true);
                
                if (updatedTemplateId != null) {
                    createTemplateEditHistory(updatedTemplateId, serializedWrapper, payloadWrapper);
                }
            } else if (res.getStatusCode() != 200 && String.isNotEmpty(res.getBody())) {
                try {
                    Map<String, Object> resMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                    if (resMap.containsKey('error')) {
                        Map<String, Object> errorMap = (Map<String, Object>) resMap.get('error');
                        String errorMessage = (String) errorMap.get('message');
                        Integer errorCode = (Integer) errorMap.get('code');

                        if (errorCode == 100 && errorMessage != null && errorMessage.toLowerCase().contains('file handle that has expired')) {
                            uploadFileToMetaAndGetHeaderHandle(templateName, serializedWrapper, payloadWrapper, templateId);
                        }
                    }
                } catch (Exception er) {
                    System.debug('Error parsing error response: ' + er.getMessage());
                }
                response.put('success', false);
                response.put('status', 'warning');
                response.put('message', 'Template is being updated, you will be notified once it is ready.');
            } else {
                response.put('success', false);
                response.put('errorMessage', res.getBody());
                ErrorHandler.insertErrordata(null, 'WAManageTemplatePageController', 'editWhatsappTemplate', 'HTTP callout failed with status: ' + res.getStatusCode() + ' and body: ' + res.getBody());
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(null, 'WAManageTemplatePageController', 'editWhatsappTemplate', 'Exception: ' + e.getMessage());
            if (e instanceof CalloutException && e.getMessage().containsIgnoreCase('Read timed out')) {
                response.put('success', false);
                response.put('status', 'warning');
                response.put('message', 'Template is being updated, you will be notified once it is ready.');
            } else {
                response.put('success', false);
                response.put('status', 'error');
                response.put('message', e.getMessage());
            }
        }
        return response;
   }

    /*
    *********************************************************
    @description     : Safely tracks template edit history using dynamic sObject.
    @param           : templateId, serializedWrapper, payloadWrapper
    ********************************************************
    */
    private static void createTemplateEditHistory(Id templateId, String serializedWrapper, String payloadWrapper) {
        try {
            Schema.SObjectType editHistoryType = Schema.getGlobalDescribe().get('Template_Edit_History__c');
            if (editHistoryType != null && editHistoryType.getDescribe().isCreateable()) {
                sObject editHistory = editHistoryType.newSObject();
                Map<String, Schema.SObjectField> fieldsMap = editHistoryType.getDescribe().fields.getMap();
                if (fieldsMap.containsKey('WA_Template__c')) {
                    editHistory.put('WA_Template__c', templateId);
                } else if (fieldsMap.containsKey('WhatsappTemplate__c')) {
                    editHistory.put('WhatsappTemplate__c', templateId);
                }
                if (fieldsMap.containsKey('Edited_Time__c')) {
                    editHistory.put('Edited_Time__c', System.now());
                }
                if (fieldsMap.containsKey('Serialized_Wrapper__c')) {
                    editHistory.put('Serialized_Wrapper__c', serializedWrapper);
                }
                if (fieldsMap.containsKey('Payload_JSON__c')) {
                    editHistory.put('Payload_JSON__c', payloadWrapper);
                }
                insert editHistory;
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WAManageTemplatePageController', 'createTemplateEditHistory', e.getMessage());
        }
    }
   
    @AuraEnabled
    public static String getMetaHeaderHandler(String fileUrlOrContentVersionId, String contentVersionId) {
        try {
            String headerHandleResult = '';
            Blob fileBlob;
            String mimeType;
            String fileName;
            Integer fileLength;

            if (String.isNotBlank(fileUrlOrContentVersionId) && fileUrlOrContentVersionId.contains('amazonaws.com')) {
                Http http = new Http();
                HttpRequest s3Req = new HttpRequest();
                s3Req.setEndpoint(fileUrlOrContentVersionId);
                s3Req.setMethod('GET');

                HttpResponse s3Res = http.send(s3Req);
                if (s3Res.getStatusCode() != 200) {
                    ErrorHandler.insertErrordata(null, 'WAManageTemplatePageController', 'getMetaHeaderHandler', 'HTTP callout failed with status: ' + s3Res.getStatusCode());
                    return '';
                }

                fileBlob = s3Res.getBodyAsBlob();
                mimeType = s3Res.getHeader('Content-Type');
                fileName = fileUrlOrContentVersionId.substring(fileUrlOrContentVersionId.lastIndexOf('/') + 1);
                fileLength = fileBlob.size();
            } else {
                ContentVersion cv = [SELECT Title, VersionData, FileExtension, ContentSize
                                     FROM ContentVersion
                                     WHERE Id = :contentVersionId
                                     LIMIT 1];
                fileBlob = cv.VersionData;
                fileName = cv.Title + '.' + cv.FileExtension;
                mimeType = getMimeTypeFromExtension(cv.FileExtension);
                fileLength = cv.ContentSize;
            }

            String uploadSessionId = startUploadSession(fileName, fileLength, mimeType);
            if (String.isBlank(uploadSessionId)) {
                return '';
            }

            FileChunkWrapper wrapper = new FileChunkWrapper();
            wrapper.uploadSessionId = uploadSessionId;
            wrapper.fileName = fileName;
            wrapper.fileContent = EncodingUtil.base64Encode(fileBlob);
            wrapper.chunkStart = 0;
            wrapper.chunkSize = fileLength;

            String serializedFileWrapper = JSON.serialize(wrapper);

            String resultJson = uploadFileChunk(serializedFileWrapper, false);
            if (String.isNotBlank(resultJson)) {
                Map<String, Object> resultMap = (Map<String, Object>) JSON.deserializeUntyped(resultJson);
                if (resultMap != null && resultMap.containsKey('headerHandle')) {
                    headerHandleResult = (String) resultMap.get('headerHandle');
                    return headerHandleResult;
                }
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WAManageTemplatePageController', 'getMetaHeaderHandler', e.getMessage());
        }
        return '';
    }

    @future(callout = true)
    public static void uploadFileToMetaAndGetHeaderHandle(String templateName, String serializedWrapper, String payloadWrapper, String tempalteId) {
        String headerHandleResult = '';
        String fileUrlOrContentVersionId = '';
        String contentVersionId = '';
        WATemplateWrapper.TemplateWrapper templateWrapper = (WATemplateWrapper.TemplateWrapper) JSON.deserialize(serializedWrapper, WATemplateWrapper.TemplateWrapper.class);

        fileUrlOrContentVersionId = templateWrapper.tempImgUrl;

        try {
            if (fileUrlOrContentVersionId != null && fileUrlOrContentVersionId.contains('amazonaws.com')) {
                Http http = new Http();
                HttpRequest s3Req = new HttpRequest();
                s3Req.setEndpoint(fileUrlOrContentVersionId);
                s3Req.setMethod('GET');

                HttpResponse s3Res = http.send(s3Req);
                if (s3Res.getStatusCode() != 200) {
                    ErrorHandler.insertErrordata(null, 'WAManageTemplatePageController', 'uploadFileToMetaAndGetHeaderHandle', 'HTTP callout failed with status: ' + s3Res.getStatusCode());
                    return;
                }
            } else {
                String jsonStr = templateWrapper.templateMiscellaneousData;

                if (!String.isBlank(jsonStr)) {
                    try {
                        Map<String, Object> miscData = (Map<String, Object>) JSON.deserializeUntyped(jsonStr);
                        contentVersionId = (String) miscData.get('contentVersionId');
                    } catch (Exception e) {
                        ErrorHandler.insertErrordata(e, 'WAManageTemplatePageController', 'uploadFileToMetaAndGetHeaderHandle', 'Failed to parse templateMiscellaneousData: ' + e.getMessage());
                    }
                }
            }

            headerHandleResult = getMetaHeaderHandler(fileUrlOrContentVersionId, contentVersionId);

            if (headerHandleResult != null && headerHandleResult != '') {
                payloadWrapper = payloadWrapper.replaceFirst('"header_handle":"[^"]+"', '"header_handle":"' + headerHandleResult + '"');
                templateWrapper.tempHeaderHandle = headerHandleResult;
                serializedWrapper = JSON.serialize(templateWrapper);
                editWhatsappTemplate(serializedWrapper, payloadWrapper, tempalteId, templateName);
            }

        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WAManageTemplatePageController', 'uploadFileToMetaAndGetHeaderHandle', e.getMessage());
        }
    }
    
    private static String getMimeTypeFromExtension(String ext) {
        ext = ext != null ? ext.toLowerCase() : '';
        if (ext == 'png') return 'image/png';
        if (ext == 'jpg' || ext == 'jpeg') return 'image/jpeg';
        if (ext == 'pdf') return 'application/pdf';
        if (ext == 'mp4') return 'video/mp4';
        if (ext == 'doc') return 'application/msword';
        if (ext == 'docx') return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
        if (ext == 'xls') return 'application/vnd.ms-excel';
        if (ext == 'xlsx') return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
        return 'application/octet-stream';
    }

    @AuraEnabled(cacheable=true)
    public static List<sObject> getAllFlows() {
        try {
            if (Schema.getGlobalDescribe().containsKey('Flow__c')) {
                return Database.query('SELECT Id, Flow_Id__c, Flow_Name__c, Flow_JSON__c, LastModifiedDate, Status__c FROM Flow__c WHERE Status__c = \'Published\' WITH USER_MODE ORDER BY CreatedDate DESC');
            }
            return new List<sObject>();
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WAManageTemplatePageController', 'getAllFlows', e.getMessage());
            return new List<sObject>();
        }
    }

    @AuraEnabled
    public static Map<String, String> getPreviewURLofWhatsAppFlow(String flowId) {
        try {
            OAuth_Configuration__mdt config = getConfig();
            if (config == null || String.isBlank(config.Access_Token__c)) {
                return new Map<String, String>{'status' => 'failed', 'error' => 'failed'};
            }

            String token = getAccessToken();
            String endpoint = getApiEndpoint() + '/' + getApiVersion() + '/' + flowId + '?fields=preview.invalidate(false)';
            HttpRequest request = new HttpRequest();
            request.setEndpoint(endpoint);
            request.setMethod('GET');
            request.setHeader('Authorization', 'Bearer ' + token);
            Http http = new Http();
            HttpResponse response = http.send(request);
            
            if (response.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                Map<String, Object> previewMap = (Map<String, Object>) responseMap.get('preview');
                String previewUrl = (String) previewMap.get('preview_url');
                return new Map<String, String>{'status' => '200', 'previewUrl' => previewUrl};
            } else {
                return new Map<String, String>{'status' => 'failed', 'error' => 'failed'};
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WAManageTemplatePageController', 'getPreviewURLofWhatsAppFlow', e.getMessage());
            return new Map<String, String>{'status' => 'failed', 'error' => 'failed'};
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getObjectsWithPhoneField() {
        List<Map<String, String>> objectList = new List<Map<String, String>>();
        
        try {
            List<FieldDefinition> phoneFields = [SELECT EntityDefinition.QualifiedApiName, EntityDefinition.Label FROM FieldDefinition WHERE DataType = 'Phone' AND EntityDefinition.IsCustomizable = true AND EntityDefinition.IsApexTriggerable = true AND EntityDefinition.IsQueryable = true WITH USER_MODE];
            Set<String> processedObjects = new Set<String>();
    
            for (FieldDefinition field : phoneFields) {
                String objectName = field.EntityDefinition.QualifiedApiName;
                if (!processedObjects.contains(objectName)) {
                    objectList.add(new Map<String, String>{
                        'label' => field.EntityDefinition.Label,
                        'value' => objectName
                    });
                    processedObjects.add(objectName);
                }
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WAManageTemplatePageController', 'getObjectsWithPhoneField', e.getMessage());
        }
    
        return objectList;
    }

    @AuraEnabled(cacheable=true)
    public static String getCompanyName() {
        return [SELECT Name FROM Organization LIMIT 1].Name;
    }

    @AuraEnabled
    public static String getAllFlowScreenIds(String flowId) {
        List<String> screenIds = new List<String>();

        try {
            if (Schema.getGlobalDescribe().containsKey('Flow__c')) {
                List<sObject> flowRecs = Database.query('SELECT Id, Flow_Id__c, Flow_Json__c FROM Flow__c WHERE Flow_Id__c = :flowId LIMIT 1');
                if (!flowRecs.isEmpty() && flowRecs[0].get('Flow_Json__c') != null) {
                    String jsonStr = (String) flowRecs[0].get('Flow_Json__c');
                    Map<String, Object> flowJson = (Map<String, Object>) JSON.deserializeUntyped(jsonStr);
                    if (flowJson.containsKey('screens')) {
                        List<Object> screens = (List<Object>) flowJson.get('screens');
                        for (Object scr : screens) {
                            Map<String, Object> scrMap = (Map<String, Object>) scr;
                            if (scrMap.containsKey('id')) {
                                screenIds.add((String) scrMap.get('id'));
                            }
                        }
                    }
                }
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WAManageTemplatePageController', 'getAllFlowScreenIds', e.getMessage());
        }

        return screenIds.isEmpty() ? '' : screenIds[0];
    }

    public class FileChunkWrapper {
        @AuraEnabled public String uploadSessionId;
        @AuraEnabled public String fileContent;
        @AuraEnabled public Integer chunkStart;
        @AuraEnabled public Integer chunkSize;
        @AuraEnabled public Long totalFileSize;
        @AuraEnabled public String fileName;
        @AuraEnabled public Boolean isLastChunk;
    }
    
    public class TemplateDataWrapper {
        @AuraEnabled public WA_Template__c template;
        @AuraEnabled public List<String> objectNames;
        @AuraEnabled public List<String> fieldNames;
        @AuraEnabled public List<Map<String, String>> templateVariables; 
        @AuraEnabled public Boolean isImgUrl;
    }

    /*
    *********************************************************
    @description     : Clones a WA_Template__c record and its WA_Template_Variable__c children
                       using user mode. Follows WATemplateHomePageController.cls pattern.
    @param           : templateId - Id of the source WA_Template__c to clone.
                       newName    - Value for Template_Name__c on the cloned record.
    @return          : Map<String,String> status, message, and clonedId
    ********************************************************
    */
    @AuraEnabled
    public static Map<String, String> cloneWBTemplate(String templateId, String newName) {
        Map<String, String> result = new Map<String, String>();
        try {
            String escapedTemplateId = String.escapeSingleQuotes(templateId);
            String escapedNewName    = String.escapeSingleQuotes(newName);

            List<WA_Template__c> sourceTemplates = [SELECT Id, Template_Name__c, Template_Category__c, Language__c, Header_Type__c, Header_Body__c, File_Name__c, 
                                                        Image_Header_Handle__c, Template_Body__c, Footer_Body__c, Button_Body__c, Button_Label__c, Button_Type__c,
                                                        Template_Miscellaneous_Data__c, (SELECT Name, Object_Name__c, Field_Name__c, Type__c, Alternate_Text__c 
                                                        FROM WA_Template_Variables__r ORDER BY Name ASC) FROM WA_Template__c WHERE Id = :escapedTemplateId 
                                                        WITH USER_MODE LIMIT 1];

            if (sourceTemplates.isEmpty()) {
                result.put('status',  'error');
                result.put('message', 'Template not found.');
                return result;
            }

            WA_Template__c source = sourceTemplates[0];

            WA_Template__c cloned = new WA_Template__c(
                Template_Name__c = escapedNewName,
                Template_Id__c = 'DRAFT',
                Status__c = 'Draft',
                Template_Category__c = source.Template_Category__c,
                Language__c = source.Language__c,
                Header_Type__c = source.Header_Type__c,
                Header_Body__c = source.Header_Body__c,
                File_Name__c = source.File_Name__c,
                Image_Header_Handle__c = source.Image_Header_Handle__c,
                Template_Body__c = source.Template_Body__c,
                Footer_Body__c = source.Footer_Body__c,
                Button_Body__c = source.Button_Body__c,
                Button_Label__c = source.Button_Label__c,
                Button_Type__c = source.Button_Type__c,
                Template_Miscellaneous_Data__c = source.Template_Miscellaneous_Data__c
            );

            insert as user cloned;

            List<WA_Template_Variable__c> variablesToInsert = new List<WA_Template_Variable__c>();
            for (WA_Template_Variable__c tv : source.WA_Template_Variables__r) {
                variablesToInsert.add(new WA_Template_Variable__c(
                    WA_Template__c = cloned.Id,
                    Object_Name__c = tv.Object_Name__c,
                    Field_Name__c = tv.Field_Name__c,
                    Type__c = tv.Type__c,
                    Alternate_Text__c = tv.Alternate_Text__c
                ));
            }
            if (!variablesToInsert.isEmpty()) {
                insert as user variablesToInsert;
            }

            result.put('status',   'success');
            result.put('message',  'WhatsApp template cloned successfully.');
            result.put('clonedId', cloned.Id);
            return result;

        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WAManageTemplatePageController', 'cloneWBTemplate', e.getMessage());
            result.put('status',  'error');
            result.put('message', 'Error cloning template: ' + e.getMessage());
            return result;
        }
    }

    @AuraEnabled
    public static Map<String, String> uploadFile(String base64Data, String fileName) {
        Map<String, String> resultMap = new Map<String, String>();
        try {
            ContentVersion cv = new ContentVersion();
            cv.Title = fileName;
            cv.PathOnClient = '/' + fileName;
            cv.VersionData = EncodingUtil.base64Decode(base64Data);
            insert as user cv;

            String publicUrl = getPublicLink(cv.Id);

            resultMap.put('contentVersionId', cv.Id);
            resultMap.put('publicUrl', publicUrl);
            return resultMap;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'WAManageTemplatePageController', 'uploadFile', e.getMessage());
            return null;
        }
    }

    @AuraEnabled
    public static String deleteFile(String contentVersionId) {
        try {

            // Get related ContentDocument
            List<ContentDocument> docs = [SELECT Id FROM ContentDocument WHERE LatestPublishedVersionId = :contentVersionId WITH USER_MODE LIMIT 1];
            if (!docs.isEmpty()) {
                Id contentDocumentId = docs[0].Id;
                
                delete as user docs;
                return 'File deleted successfully!';
            } else {
                return 'No file found to delete.';
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'WAManageTemplatePageController', 'deleteFile', e.getMessage());
            return 'Error: ' + e.getMessage();
        }
    }
    @AuraEnabled
    public static String getPublicLink(String contentVersionId) {
        try {
            // Get the related ContentDocument Id
            ContentVersion contentVersion = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :contentVersionId WITH USER_MODE LIMIT 1];
            
            // Create a new ContentDistribution (public link)
            ContentDistribution distribution = new ContentDistribution();
            distribution.Name = 'Public Link';
            distribution.ContentVersionId = contentVersion.Id;
            distribution.PreferencesAllowViewInBrowser= true;
            distribution.PreferencesLinkLatestVersion=true;
            distribution.PreferencesNotifyOnVisit=false;
            distribution.PreferencesPasswordRequired=false;
            distribution.PreferencesAllowOriginalDownload= true;

            insert as user distribution;
            
            // Query the created ContentDistribution to get the public URL
            distribution = [SELECT DistributionPublicUrl,ContentDownloadUrl FROM ContentDistribution WHERE Id = :distribution.Id WITH USER_MODE LIMIT 1];
        
            // Return the public URL
            return distribution.ContentDownloadUrl;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'WAManageTemplatePageController', 'getPublicLink', e.getMessage());
            return 'Error: ' + e.getMessage();
        }
    }
}