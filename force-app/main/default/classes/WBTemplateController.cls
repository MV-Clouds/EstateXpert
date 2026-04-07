/**
 * Class Name: WBTemplateController
 * Test Class: 
 * @description: Used in LWC components, it used to get the template record, 
                picklist value from static resource and callout for creation of template.
 * Date: 25/11/2024
 * Created By: Rachit Shah
 */
 /***********************************************************************
 MODIFICATION LOG*
* Last Update Date : 16/07/2025
* Updated By : Divij Modi
* Change Description : Added logic to create edit history record and code clean
* 22 Jan, 2025  - Rachit Shah - Added methods to fetch fields with relationship support and handle polymorphic relationships
* 06 Feb, 2026  - Rachit Shah  -  Updated code to handle the tenplate edit restriction which we have from meta
 ***********************************************************************/

public with sharing class WBTemplateController {
    
    // public static final MVEX__WBConnect_Configuration__mdt SETTINGS[0];
    public static List<MVEX__WBConnect_Configuration__mdt> SETTINGS = MVEX__WBConnect_Configuration__mdt.getAll().values(); 
    public static String accessToken = !SETTINGS.isEmpty() ? SETTINGS[0].MVEX__Access_Token__c : null;
    public static String uploadEndpoint;

   // List of allowed fields for polymorphic relationships (like Owner which can be User or Queue)
    public static List<String> polymorphismObjAllowedFields = new List<String>{
        'Alias', 'Email', 'FirstName', 'IsActive', 'LastName', 
        'LastReferencedDate', 'LastViewedDate', 'MiddleName', 'Name', 'Phone', 
        'Profile', 'Suffix', 'Title', 'Type', 'Username', 'UserRole', 'UserRoleId'
    };


     /*
    *********************************************************
    @description     : Used in WbAllTemplatePage to get all template record.
    @param           : 
    @return          : listName - Whatsapp Template record.
    ********************************************************
    */
    @AuraEnabled
    public static List<WhatsappTemplate__c> getWhatsAppTemplates() {
        try {

            // In the child query, we only need the latest 10 records to determine if the user can edit within the 30-day window.
            List<WhatsappTemplate__c> listName = [
                SELECT Id, Name, Template_Name__c, Template_Category__c,
                       toLabel(Language__c) LanguageLabel,
                       File_Name__c, WBImage_Header_Handle__c, Status__c,
                       LastModifiedById, LastModifiedDate, CreatedDate,
                       (SELECT Id, Edited_Time__c
                        FROM Template_Edit_Histories__r
                        ORDER BY Edited_Time__c DESC
                        LIMIT 10)
                FROM WhatsappTemplate__c
                WITH USER_MODE
                ORDER BY LastModifiedDate DESC
            ];
            return listName;
        } catch (Exception e) {
                ErrorHandler.insertErrordata(e, 'WBTemplateController', 'getWhatsAppTemplates', e.getMessage());
                return null;
        }
    }

    /*
    *********************************************************
    @description     : Send preview message.
    @param           : 
    @return          : errorMessage
    ********************************************************
    */
    @AuraEnabled
    public static String sendPreviewTemplate(String jsonData) {
        String errorMessage=null;
        try {
            HttpRequest httpReq = new HttpRequest();
            List<MVEX__WBConnect_Configuration__mdt> config = MVEX__WBConnect_Configuration__mdt.getAll().values(); 
            if(config==null && config.isEmpty()){
                errorMessage='Metadata records are missing.';
                return errorMessage;
            }
            String accessToken = config[0].MVEX__Access_Token__c;
            String endpoint = config[0].MVEX__APIEndpoint__c + '/' + config[0].MVEX__APIVersion__c + '/' + config[0].MVEX__Phone_Number_Id__c + '/messages';
            httpReq.setEndpoint(endpoint);
            httpReq.setMethod('POST');
            httpReq.setHeader('Content-Type', 'application/json');
            httpReq.setHeader('Authorization', 'Bearer ' + accessToken);
            httpReq.setBody(jsonData);
            Http http = new Http();
            HttpResponse response = http.send(httpReq);
            Integer statusCode = response.getStatusCode();
            if(statusCode != 200){
                errorMessage='Failed to send Template';
                ErrorHandler.insertErrordata(null, 'WBTemplateController', 'sendPreviewTemplate', 'API Exception while sending a message');
            }

        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WBTemplateController', 'sendPreviewTemplate', e.getMessage());
        }
        return errorMessage;
    }

    /*
    *********************************************************
    @description     : Used to fetch all the field related to object name
    @param           : 
    @return          : fieldNames - Return fields that query for the objectname that pass.
    ********************************************************
    */
    @AuraEnabled
    public static List<String> getObjectFields(String objectName) {
        // String objectName = 'Contact';
        List<String> fieldNames = new List<String>();
        try {
            Schema.DescribeSObjectResult objDescribe = Schema.getGlobalDescribe().get(objectName).getDescribe();
            Map<String, Schema.SObjectField> fieldsMap = objDescribe.fields.getMap();
            for (String fieldName : fieldsMap.keySet()) {
                fieldNames.add(fieldsMap.get(fieldName).getDescribe().getName()); 
            }
            fieldNames.sort();
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WBTemplateController', 'getObjectFields', e.getMessage());
        }
        return fieldNames;
    }

    /*
    *********************************************************
    @description     : Method to fetch fields for objects with optional relationship paths.
                      : Handles all cases:
                      : 1. Multiple objects at root level (relationshipPaths empty/null)
                      : 2. Single object with single relationship path
                      : 3. Single object with multiple relationship paths (bulk fetch - avoids loop callouts)
    @param           : objectNames - List of object API names to fetch fields for
                      : relationshipPaths - Optional list of relationship paths (empty/null for root level)
    @return          : Map<String, List<FieldOption>> - Map where key is objectName (for root) or path (for relationships)
    ********************************************************
    */
    @AuraEnabled
    public static Map<String, List<FieldOption>> getObjectFieldsWithRelationships(List<String> objectNames, List<String> relationshipPaths) {
        Map<String, List<FieldOption>> resultMap = new Map<String, List<FieldOption>>();
        
        try {
            if (objectNames == null || objectNames.isEmpty()) {
                return resultMap;
            }
            
            // Remove duplicates from objects
            Set<String> uniqueObjects = new Set<String>(objectNames);
            
            // Check if relationship paths are provided
            Boolean hasRelationshipPaths = relationshipPaths != null && !relationshipPaths.isEmpty();
            
            if (hasRelationshipPaths && uniqueObjects.size() == 1) {
                // CASE: Single object with relationship path(s) - key by path
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
                        System.debug('Error fetching fields for path ' + path + ': ' + e.getMessage());
                        ErrorHandler.insertErrordata(e, 'WBTemplateController', 'getObjectFieldsWithRelationships', 'Error fetching fields for path ' + path);  
                        resultMap.put(path, new List<FieldOption>());
                    }
                }
            } else {
                // CASE: Multiple objects OR single object at root level - key by objectName
                for (String objectName : uniqueObjects) {
                    try {
                        if (String.isBlank(objectName)) {
                            continue;
                        }
                        List<FieldOption> fields = getFieldsAtPath(objectName, '');
                        resultMap.put(objectName, fields);
                    } catch (Exception e) {
                        System.debug('Error fetching fields for object ' + objectName + ': ' + e.getMessage());
                        ErrorHandler.insertErrordata(e, 'WBTemplateController', 'getObjectFieldsWithRelationships', 'Error fetching fields for object ' + objectName);
                        resultMap.put(objectName, new List<FieldOption>());
                    }
                }
            }
        } catch (Exception e) {
            System.debug('Error in getObjectFieldsWithRelationships: ' + e.getMessage());
            ErrorHandler.insertErrordata(e, 'WBTemplateController', 'getObjectFieldsWithRelationships', e.getMessage());
            throw new AuraHandledException('Error fetching fields: ' + e.getMessage());
        }
        
        return resultMap;
    }

    /*
    *********************************************************
    @description     : Helper method to get fields at a specific relationship path
    @param           : objectName - The starting object API name
                      : relationshipPath - The relationship path to navigate
    @return          : List<FieldOption> - List of field options at the target object
    ********************************************************
    */

    private static List<FieldOption> getFieldsAtPath(String objectName, String relationshipPath) {
        String[] pathParts = relationshipPath.split('\\.');
        String currentObjectName = objectName;
        Boolean isPolymorphicPath = false;
        
        // Navigate through the path to find the target object
        for (String part : pathParts) {
            Schema.DescribeSObjectResult objDescribe = Schema.getGlobalDescribe().get(currentObjectName).getDescribe();
            Map<String, Schema.SObjectField> fieldsMap = objDescribe.fields.getMap();
            
            // Find the relationship field
            for (String fieldName : fieldsMap.keySet()) {
                Schema.DescribeFieldResult fieldDescribe = fieldsMap.get(fieldName).getDescribe();
                String relationshipName = fieldDescribe.getRelationshipName();
                
                if (relationshipName == part) {
                    List<Schema.sObjectType> referenceTo = fieldDescribe.getReferenceTo();
                    if (!referenceTo.isEmpty()) {
                        // Check if this relationship is polymorphic (points to multiple objects)
                        if (referenceTo.size() > 1) {
                            isPolymorphicPath = true;
                        }
                        currentObjectName = referenceTo[0].getDescribe().getName();
                        break;
                    }
                }
            }
        }
        
        // Get immediate fields of the target object
        return getFieldsImmediate(currentObjectName, relationshipPath, isPolymorphicPath);
    }

    /*
    *********************************************************
    @description     : Helper method to get immediate fields of an object
    @param           : objectName - The object API name
                      : prefix - The relationship path prefix for field values
                      : isPolymorphicParent - Whether the parent relationship is polymorphic
    @return          : List<FieldOption> - List of immediate field options
    ********************************************************
    */
    private static List<FieldOption> getFieldsImmediate(String objectName, String prefix, Boolean isPolymorphicParent) {
        List<FieldOption> fieldOptions = new List<FieldOption>();
        
        // Convert allowed fields to a Set for faster lookup
        Set<String> allowedFieldsSet = new Set<String>(polymorphismObjAllowedFields);
        
        try {
            Schema.DescribeSObjectResult objDescribe = Schema.getGlobalDescribe().get(objectName).getDescribe();
            Map<String, Schema.SObjectField> fieldsMap = objDescribe.fields.getMap();
            
            for (String fieldName : fieldsMap.keySet()) {
                Schema.DescribeFieldResult fieldDescribe = fieldsMap.get(fieldName).getDescribe();
                String fieldApiName = fieldDescribe.getName();
                String fieldLabel = fieldDescribe.getLabel();
                Schema.DisplayType fieldType = fieldDescribe.getType();
                
                // If parent is polymorphic, only show allowed fields and no relationships
                if (isPolymorphicParent) {
                    // Only add fields that are in the allowed list
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
                    continue; // Skip relationship processing for polymorphic parents
                }
                
                // Regular fields
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
                
                // Check for lookup/master-detail relationships
                if (fieldType == Schema.DisplayType.REFERENCE) {
                    List<Schema.sObjectType> referenceTo = fieldDescribe.getReferenceTo();
                    if (!referenceTo.isEmpty()) {
                        String relationshipName = fieldDescribe.getRelationshipName();
                        
                        // Debug log for Campaign field
                        if (objectName == 'Contact' && (fieldApiName == 'CampaignId' || fieldLabel.contains('Campaign'))) {
                            System.debug('===== Campaign Field Debug =====');
                            System.debug('Field API Name: ' + fieldApiName);
                            System.debug('Field Label: ' + fieldLabel);
                            System.debug('Relationship Name: ' + relationshipName);
                            System.debug('Reference To Size: ' + referenceTo.size());
                            if (!referenceTo.isEmpty()) {
                                System.debug('Related Object: ' + referenceTo[0].getDescribe().getName());
                            }
                            System.debug('================================');
                        }
                        
                        if (String.isNotBlank(relationshipName)) {
                            String relatedObjectName = referenceTo[0].getDescribe().getName();
                            String relatedObjectLabel = referenceTo[0].getDescribe().getLabel();
                            
                            // Check if this is a polymorphic relationship (points to multiple objects)
                            Boolean isPolymorphic = referenceTo.size() > 1;
                            
                            // Create relationship node (will be loaded lazily)
                            FieldOption relOption = new FieldOption();
                            relOption.label = fieldLabel + ' (' + relatedObjectLabel + ')';
                            relOption.value = String.isNotBlank(prefix) ? prefix + '.' + relationshipName : relationshipName;
                            relOption.apiName = relationshipName;
                            relOption.relationshipName = relationshipName; // Add explicit relationshipName property
                            relOption.type = 'RELATIONSHIP';
                            relOption.isRelationship = true;
                            relOption.level = 0;
                            relOption.hasChildren = true;
                            relOption.relatedObject = relatedObjectName;
                            relOption.isPolymorphic = isPolymorphic;
                            relOption.children = new List<FieldOption>(); // Empty, will be loaded on demand
                            
                            fieldOptions.add(relOption);
                        }
                    }
                }
            }
            
            // Sort all fields together to maintain alphabetical order
            fieldOptions.sort();
            
        } catch (Exception e) {
            System.debug('Error in getFieldsImmediate: ' + e.getMessage());
        }
        
        return fieldOptions;
    }

    // Wrapper class for field options
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
    @param           : 
    @return          : records - Return record that query for the objectname that pass.
    ********************************************************
    */
    @AuraEnabled
    public static List<sObject> getRecordsBySObject(String objectName) {
        String sObjectName=objectName;
        List<sObject> records = new List<sObject>();
        
        try {
            String query = 'SELECT Id, Name, Phone FROM ' + sObjectName + ' WHERE Phone != null LIMIT 200';           
            records = Database.query(String.escapeSingleQuotes(query), AccessLevel.USER_MODE);
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WBTemplateController', 'getRecordsBySObject', e.getMessage());
        }
        return records;
    }

    /*
    *********************************************************
    @description     : This method use to fetch template data and variable mapping done in js.
    @param           : 
    @return          : wrapper - Return wrapper that contain object name and field name from the Template Variable.
    ********************************************************
    */
    @AuraEnabled(cacheable=true)
    public static TemplateDataWrapper getDynamicObjectData(Id templateId) {
        TemplateDataWrapper wrapper = new TemplateDataWrapper();
        Set<String> objectNames = new Set<String>();
        Set<String> fieldNames = new Set<String>();
        wrapper.templateVariables = new List<Map<String, String>>();

        try {
            List<WhatsappTemplate__c> templates = [
                SELECT Id, Name,Template_Name__c, WBButton_Body__c, Status__c,WBImage_Header_Handle__c, Template_Id__c, Button_Label__c, Button_Type__c, File_Name__c,
                    WBFooter_Body__c, WBHeader_Body__c, Header_Type__c, Language__c, WBTemplate_Body__c, 
                    Template_Category__c, Template_Type__c , Template_Miscellaneous_Data__c
                FROM WhatsappTemplate__c 
                WHERE Id = :templateId
                WITH USER_MODE
                ORDER BY LastModifiedDate DESC
                LIMIT 1
            ];

            if (templates.isEmpty()) {
                return wrapper; 
            }

            WhatsappTemplate__c template = templates[0];
            wrapper.template = template;

            if (template.Header_Type__c == 'Image') {
                wrapper.isImgUrl = true;
            }
            else if (template.Header_Type__c == 'Video') {
                wrapper.isImgUrl = true;
            }
            else if (template.Header_Type__c == 'Document') {
                wrapper.isImgUrl = true;
            }
            

            List<Template_Variable__c> templateVariables = [
                SELECT Name, Object_Name__c, Field_Name__c, Type__c, Alternate_Text__c
                FROM Template_Variable__c 
                WHERE WhatsappTemplate__c = :template.Id WITH USER_MODE
            ];

            if (!templateVariables.isEmpty()) {
                for (Template_Variable__c variable : templateVariables) {
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
            ErrorHandler.insertErrordata(e, 'WBTemplateController', 'getDynamicObjectData', e.getMessage());
        }

        return wrapper;
    }

    /*
    *********************************************************
    @description     : Fetch records based on the dynamic object name, fieldname and recordid
    @param           : objectName, fieldNames, recordId
    @return          : resultMap {Map<String, Object>} - Return queried data.
    ********************************************************
    */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> fetchDynamicRecordData(String objectName, List<String> fieldNames, String recordId) {
        Map<String, Object> resultMap = new Map<String, Object>();

        try {
            if (String.isEmpty(objectName) || fieldNames.isEmpty() || String.isEmpty(recordId)) {
                ErrorHandler.insertErrordata(new AuraHandledException('Invalid input parameters'), 'WBTemplateController', 'fetchDynamicRecordData', 'Object name, field names or record ID cannot be empty.');
                throw new AuraHandledException('Invalid input parameters');
            }

            if (!fieldNames.contains('Phone')) {
                    fieldNames.add('Phone');
            }
            String fields = String.join(fieldNames, ',');
            
            String queryString = 'SELECT ' + fields + ' FROM ' + objectName + ' WHERE Id = :recordId LIMIT 1';            
            List<SObject> queriedData = Database.query(queryString);

            if (!queriedData.isEmpty()) {
                resultMap.put('queriedData', queriedData[0]);  
            } else {
                resultMap.put('queriedData', null);
            }

        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WBTemplateController', 'fetchDynamicRecordData', e.getMessage());
            resultMap.put('error', e.getMessage());
        }

        return resultMap;
    }
   
    /*
    *********************************************************
    @description     : It used to replace variable from backend to handle the sending of template variable.
    @param           : recordId
    @return          : result {Map<String, Object>} - Return the replace template content based on the template variable fields by fetching from contact object.
    ********************************************************
    */

    @AuraEnabled
    public static Map<String, Object> getTemplateDataWithReplacement(String templateId, String contactId) {
        try {
            Map<String, Object> templateData = new Map<String, Object>();
            List<WhatsappTemplate__c> templates = [SELECT Id, Name,Template_Name__c, WBButton_Body__c, Button_Label__c, Button_Type__c,WBImage_Header_Handle__c, 
                                                WBFooter_Body__c, WBHeader_Body__c, Header_Type__c, Language__c,File_Name__c, 
                                                WBTemplate_Body__c, Template_Category__c, 
                                                Template_Type__c, Template_Variable__c, Template_Miscellaneous_Data__c,
                                                (SELECT Id, Name, Field_Name__c, Object_Name__c, Type__c, Alternate_Text__c 
                                                    FROM WB_Template_Variables__r ORDER BY Name ASC) 
                                            FROM WhatsappTemplate__c 
                                            WHERE Id = :templateId 
                                            WITH USER_MODE];
            if (templates.size() > 0) {
                WhatsappTemplate__c template = templates[0];

                if (template.Template_Variable__c > 0) {
                    List<Object> headerVariables = new List<Object>();
                    List<Object> bodyVariables = new List<Object>();

                    // Scenario 1: Contact ID is passed
                    if (String.isNotBlank(contactId)) {
                        Set<String> fieldSelectionCause = new Set<String>();
                        for (Template_Variable__c tv : template.WB_Template_Variables__r) {
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
                                for (Template_Variable__c tv : template.WB_Template_Variables__r) {
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
                                        template.WBHeader_Body__c = template.WBHeader_Body__c.replace(tv.Name, replacement);
                                    } else if (tv.Type__c == 'Body') {
                                        String replacement = (valueToReplace != null ? valueToReplace.toString() : 
                                                                (tv.Alternate_Text__c != null ? tv.Alternate_Text__c : ''));
                                    
                                        bodyVariables.add(replacement);
                                        template.WBTemplate_Body__c = template.WBTemplate_Body__c.replace(tv.Name, replacement);
                                    }
                                    
                                }
                            }
                        }
                    } 
                    // Scenario 2: Contact ID not passed
                    else {
                        for (Template_Variable__c tv : template.WB_Template_Variables__r) {
                            if (tv.Type__c == 'Header') {
                                headerVariables.add(tv.Alternate_Text__c != null ? tv.Alternate_Text__c : '{{' + tv.Name + '}}');
                                template.WBHeader_Body__c = template.WBHeader_Body__c.replace(tv.Name, 
                                                            tv.Alternate_Text__c != null ? tv.Alternate_Text__c : '{{' + tv.Name + '}}');
                            } else if (tv.Type__c == 'Body') {
                                // bodyVariables.add(tv.Alternate_Text__c != null ? tv.Alternate_Text__c : '{{' + tv.Name + '}}');
                                bodyVariables.add(tv.Alternate_Text__c != null ? tv.Alternate_Text__c : tv.Name);
                                template.WBTemplate_Body__c = template.WBTemplate_Body__c.replace(tv.Name, 
                                                            tv.Alternate_Text__c != null ? tv.Alternate_Text__c : tv.Name);
                                                            // tv.Alternate_Text__c != null ? tv.Alternate_Text__c : '{{' + tv.Name + '}}');
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
            ErrorHandler.insertErrordata(e, 'WBTemplateController', 'getTemplateDataWithReplacement', e.getMessage());
        }
        return null;
    }
   
    /*
    *********************************************************
    @description     : Get picklist value for catagory and status used in WbAllTemplatePage to filter.
    @param           : 
    @return          : picklistValues {Map<String, List<String>>} - return picklist value for catagory and status from template object.
    ********************************************************
    */
    @AuraEnabled(cacheable=true)
    public static Map<String, List<String>> getCategoryAndStatusPicklistValues() {
        Map<String, List<String>> picklistValues = new Map<String, List<String>>();

        List<String> categoryValues = new List<String>();
        List<String> statusValues = new List<String>();

        try {
            // Fetch Category__c picklist values
            Schema.DescribeFieldResult categoryFieldResult = WhatsappTemplate__c.Template_Category__c.getDescribe();
            for (Schema.PicklistEntry entry : categoryFieldResult.getPicklistValues()) {
                categoryValues.add(entry.getLabel());
            }

            // Fetch Status__c picklist values
            Schema.DescribeFieldResult statusFieldResult = WhatsappTemplate__c.Status__c.getDescribe();
            for (Schema.PicklistEntry entry : statusFieldResult.getPicklistValues()) {
                statusValues.add(entry.getLabel());
            }

            picklistValues.put('categories', categoryValues);
            picklistValues.put('statuses', statusValues);

            return picklistValues;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WBTemplateController', 'getCategoryAndStatusPicklistValues', e.getMessage());
            return null;
        }
    }

    /*
    *********************************************************
    @description     : Callout to create template in the Meta and the Body creation and response handle in CreateTemplateWrapper Class.
    @param           : serializedWrapper - get serialize wrapper from the js to create template.
    @return          : response Map<String, Object> - return response with the template id.
    ********************************************************
    */
    @AuraEnabled
    public static Map<String, Object> createWhatsappTemplate(String serializedWrapper,String payloadWrapper, String templateName) {
        Map<String, Object> response = new Map<String, Object>();

        try {
            if (String.isBlank(SETTINGS[0].MVEX__Business_Account_Id__c)) {
                response.put('success', false);
                response.put('errorMessage', 'Business Account ID is not configured in the system.');
                return response;
            }

            CreateTemplateWrapper.TemplateWrapper templateWrapper = (CreateTemplateWrapper.TemplateWrapper) JSON.deserialize(serializedWrapper, CreateTemplateWrapper.TemplateWrapper.class);

            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(payloadWrapper);
            System.debug('payload :: '+payload);

            String endpoint = SETTINGS[0].MVEX__APIEndpoint__c + '/' + SETTINGS[0].MVEX__APIVersion__c + '/' + SETTINGS[0].MVEX__Business_Account_Id__c+'/message_templates';
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            req.setBody(JSON.serialize(payload));
    
            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                Id templateId = CreateTemplateWrapper.handleSuccessResponse((String) responseMap.get('id'), (String) responseMap.get('status'), payload, templateWrapper);
                response.put('success', true);
                response.put('templateId', templateId); 
            } else {
                response.put('success', false);
                response.put('errorMessage', res.getBody());
                // if (String.isNotBlank(templateWrapper.tempImgId)) {
                //     ContentDocument contentDoc = [SELECT Id FROM ContentDocument WHERE Id = :templateWrapper.tempImgId WITH USER_MODE LIMIT 1];
                //     if (Schema.sObjectType.ContentDocument.isDeletable()) {
                //         delete contentDoc;
                //     }
                // }

                if (String.isNotBlank(templateWrapper.tempImgId)) {
                    ContentVersion version = [
                        SELECT ContentDocument.Id 
                        FROM ContentVersion 
                        WHERE Id = :templateWrapper.tempImgId 
                        WITH USER_MODE 
                        LIMIT 1
                    ];

                    if (version != null && Schema.sObjectType.ContentDocument.isDeletable()) {
                        delete version.ContentDocument;
                    }
                }


                ErrorHandler.insertErrordata(new AuraHandledException('HTTP callout failed with status: ' + res.getStatusCode()), 'WBTemplateController', 'createWhatsappTemplate', 'HTTP callout failed with status: ' + res.getStatusCode());
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WBTemplateController', 'createWhatsappTemplate', e.getMessage());
            if (e instanceof CalloutException && e.getMessage().containsIgnoreCase('Read timed out')) {
                response.put('success', false);
                response.put('status', 'warning');
                response.put('message', 'Template is being created, you will be notified once it is ready.');
                checkTemplateExistance(templateName, serializedWrapper, payloadWrapper);
            }
            else{
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
            String endpoint = SETTINGS[0].MVEX__APIEndpoint__c + '/' + SETTINGS[0].MVEX__APIVersion__c + '/' + SETTINGS[0].MVEX__Business_Account_Id__c + '/message_templates?name=' + EncodingUtil.urlEncode(templateName, 'UTF-8');
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('GET');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + accessToken);

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                List<Object> dataList = (List<Object>) responseMap.get('data');

                if (!dataList.isEmpty()) {
                    // Get the first element from the list and cast it as a Map
                    Map<String, Object> templateData = (Map<String, Object>) dataList[0];

                    // Extract values
                    String metaTemplateId = (String) templateData.get('id');
                    String metaTempStatus = (String) templateData.get('status');

                    System.debug('Template ID: ' + metaTemplateId);
                    System.debug('Status: ' + metaTempStatus);

                    CreateTemplateWrapper.TemplateWrapper templateWrapper = (CreateTemplateWrapper.TemplateWrapper) JSON.deserialize(serializedWrapper, CreateTemplateWrapper.TemplateWrapper.class);
                    Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(payloadWrapper);

                    Id templateId = CreateTemplateWrapper.handleSuccessResponse(metaTemplateId, metaTempStatus, payload, templateWrapper);

                    if(templateId != null) {
                        MVEX__Template_Update__e fetchAllTemplatesEvent = new MVEX__Template_Update__e();
                        fetchAllTemplatesEvent.Fetch_All_Templates__c = true;
                        EventBus.publish(fetchAllTemplatesEvent);
                    } else {
                        ErrorHandler.insertErrordata(new AuraHandledException('Template Id not found in checkTemplateExistance for template ' + templateName), 'WBTemplateController', 'checkTemplateExistance', 'Template Id not found in checkTemplateExistance for template ' + templateName);
                    }
                }
            } else {
                ErrorHandler.insertErrordata(new AuraHandledException('API Call failed: ' + res.getStatusCode() + ' - ' + res.getBody()), 'WBTemplateController', 'checkTemplateExistance', 'API Call failed: ' + res.getStatusCode() + ' - ' + res.getBody());
                System.debug('API Call failed: ' + res.getStatusCode() + ' - ' + res.getBody());
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WBTemplateController', 'checkTemplateExistance', e.getMessage());
            System.debug('Exception occurred while checking template existence: ' + e.getMessage());
        }
    }

    /*
    *********************************************************
    @description     : Method to get session Id for uploading file to meta.
    @param           : fileName,fileLength,fileType - get the all parameter from the js as user select the file.
    @return          : sessionId - return sessionId to start upload file in meta.
    ********************************************************
    */
    @AuraEnabled
    public static String startUploadSession(String fileName, Integer fileLength, String fileType) {
        try {
            if (String.isBlank(SETTINGS[0].MVEX__Application_Id__c)) {
                return 'Application ID is not configured in the system.';
            }
            Map<String, Object> payload = new Map<String, Object>();
            payload.put('file_name', fileName);
            payload.put('file_length', fileLength);
            payload.put('file_type', fileType);
            uploadEndpoint = SETTINGS[0].MVEX__APIEndpoint__c + '/' + SETTINGS[0].MVEX__APIVersion__c + '/'+SETTINGS[0].MVEX__Application_Id__c+'/uploads';

            HttpRequest req = new HttpRequest();
            Http http = new Http();
            req.setEndpoint(uploadEndpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'OAuth ' + accessToken);
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

                ErrorHandler.insertErrordata(new AuraHandledException('HTTP callout failed with status: ' + res.getStatusCode()), 'WBTemplateController', 'startUploadSession', 'HTTP callout failed with status: ' + res.getStatusCode());
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WBTemplateController', 'startUploadSession', e.getMessage());
        }
        return null;
    }        

    /*
    *********************************************************
    @description     : Method to upload file to meta and get file handle which use to create body for image header.
    @param           : serializedWrapper - get serialize wrapper from the js with the detail of files.
    @return          : headerHandle - return headerHandle so that can used to build body for media template.
    ********************************************************
    */
    @AuraEnabled
    public static String uploadFileChunk(String serializedWrapper, Boolean isAWSEnabled) {
        try {
            
            FileChunkWrapper fileWrapper = (FileChunkWrapper) JSON.deserialize(serializedWrapper, FileChunkWrapper.class);

            Blob fileBlob = EncodingUtil.base64Decode(fileWrapper.fileContent);

            HttpRequest req = new HttpRequest();
            Http http = new Http();

            String endpoint = SETTINGS[0].MVEX__APIEndpoint__c + '/' + SETTINGS[0].MVEX__APIVersion__c + '/' + 'upload:' + fileWrapper.uploadSessionId;
            req.setEndpoint(endpoint);
            req.setMethod('POST');            
            req.setHeader('Authorization', 'OAuth ' + accessToken);
            req.setHeader('file_offset', String.valueOf(fileWrapper.chunkStart)); 
            req.setHeader('Content-Range', 'bytes ' + fileWrapper.chunkStart + '-' + (fileWrapper.chunkStart + fileWrapper.chunkSize - 1) + '/' + fileBlob.size());            
            
            req.setBodyAsBlob(fileBlob);

            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                String headerHandle = (String) responseMap.get('h');
                    return JSON.serialize(new Map<String, String>{
                        'headerHandle' => headerHandle
                    });
                // return headerHandle; 
            } else {
                ErrorHandler.insertErrordata(new AuraHandledException('HTTP callout failed with status: ' + res.getStatusCode()), 'WBTemplateController', 'uploadFileChunk', 'HTTP callout failed with status: ' + res.getStatusCode());
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WBTemplateController', 'uploadFileChunk', e.getMessage());
        }
        return '';
    }
     
    /*
    *********************************************************
    @description     : Method used to delete template from meta as well as from record page.
    @param           : templateId - using that can delete template.
    @return          : Return the success or error message. 
    ********************************************************
    */
    @AuraEnabled
    public static string deleteTemplete(String templateId){
        try {
            if (String.isBlank(SETTINGS[0].MVEX__Business_Account_Id__c)) {
                return 'Business Account ID is not configured in the system.';
            }

            WhatsappTemplate__c wbTempRec = [SELECT Id, Name,Template_Name__c FROM WhatsappTemplate__c WHERE Id =: templateId WITH USER_MODE LIMIT 1];
            
            String endpoint = SETTINGS[0].MVEX__APIEndpoint__c + '/' + SETTINGS[0].MVEX__APIVersion__c + '/' + SETTINGS[0].MVEX__Business_Account_Id__c+'/message_templates?name=' + wbTempRec.Template_Name__c;

            HttpRequest req = new HttpRequest();         
            req.setEndpoint(endpoint);
            req.setMethod('DELETE');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            Http http = new Http();
            HttpResponse res = http.send(req);

            Integer statusCode = res.getStatusCode();
            Boolean shouldDeleteFromSF = false;
            String returnMessage = '';

            if(statusCode == 400 && res.getBody().contains('Message template not found')){
                // Template doesn't exist in Meta, safe to delete from SF
                shouldDeleteFromSF = true;
                returnMessage = 'Template not found in Meta and deleted from Salesforce successfully';                
    
            } else if (statusCode == 404) {
                // Template doesn't exist in Meta, safe to delete from SF
                shouldDeleteFromSF = true;
                returnMessage = 'Template not found in Meta and deleted from Salesforce successfully';
            } else if (statusCode == 200) {
                Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                Boolean success = (Boolean) jsonResponse.get('success');
                if (success) {
                    shouldDeleteFromSF = true;
                    returnMessage = 'Template deleted successfully';
                } else {
                    ErrorHandler.insertErrordata(null, 'WBTemplateController', 'deleteTemplete', res.getBody());
                    returnMessage = 'Template deletion failed in Meta';
                }
            }else {
                ErrorHandler.insertErrordata(null, 'WBTemplateController', 'deleteTemplete', res.getBody());
                returnMessage = 'Template deletion failed with status: ' + statusCode;
            }

            // Delete from Salesforce if conditions are met
            if (shouldDeleteFromSF && WhatsappTemplate__c.sObjectType.getDescribe().isDeletable()) {
                delete wbTempRec;
            }

            return returnMessage;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WBTemplateController', 'deleteTemplete', e.getMessage());
            return e.getMessage();
        }
    }

    /*
    *********************************************************
    @description     : Callout to edit template in the Meta and the Body creation and response handle in CreateTemplateWrapper Class.
    @param           : serializedWrapper - get serialize wrapper from the js to create template.
    @return          : response Map<String, Object> - return response with the template id.
    ********************************************************
    */
    @AuraEnabled
    public static Map<String, Object> editWhatsappTemplate(String serializedWrapper,String payloadWrapper,String templateId, String templateName) {
        Map<String, Object> response = new Map<String, Object>();
        HttpResponse res = new HttpResponse();

        try {
            CreateTemplateWrapper.TemplateWrapper templateWrapper = (CreateTemplateWrapper.TemplateWrapper) JSON.deserialize(serializedWrapper, CreateTemplateWrapper.TemplateWrapper.class);

            String editEndpoint = SETTINGS[0].MVEX__APIEndpoint__c + '/' + SETTINGS[0].MVEX__APIVersion__c + '/'+templateId;

            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(payloadWrapper);
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(editEndpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            req.setBody(JSON.serialize(payload));
    
            Http http = new Http();
            res = http.send(req);

            if (res.getStatusCode() == 200) {
                    Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                    Id updatedTemplateId = CreateTemplateWrapper.handleSuccessResponse((String) responseMap.get('id'), (String) responseMap.get('status'), payload, templateWrapper);
                    response.put('success', true);
                    
                    // Create WB Template Edit History record to track the edit
                    if (updatedTemplateId != null) {
                        createTemplateEditHistory(updatedTemplateId, serializedWrapper, payloadWrapper);
                    }
            }
            else if (res.getStatusCode() != 200 && String.isNotEmpty(res.getBody())) {
                try {
                    Map<String, Object> resMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                    if (resMap.containsKey('error')) {
                        Map<String, Object> errorMap = (Map<String, Object>) resMap.get('error');
                        String errorMessage = (String) errorMap.get('message');
                        Integer errorCode = (Integer) errorMap.get('code');

                        if (errorCode == 100 && errorMessage != null &&
                            errorMessage.toLowerCase().contains('file handle that has expired')) {
                            // ✅ Handle expired file handle here
                            uploadFileToMetaAndGetHeaderHandle(templateName, serializedWrapper, payloadWrapper,templateId);
                            System.debug('File handle has expired. You may need to re-upload the media.');
                        }
                    }
                } catch (Exception er) {
                    System.debug('Error parsing error response: ' + er.getMessage());
                }
                response.put('success', false);
                response.put('status', 'warning');
                response.put('message', 'Template is being updated, you will be notified once it is ready.');
            }
            else {
                response.put('success', false);
                response.put('errorMessage', res.getBody());
                // if (String.isNotBlank(templateWrapper.tempImgId)) {
                //     ContentDocument contentDoc = [SELECT Id FROM ContentDocument WHERE Id = :templateWrapper.tempImgId WITH USER_MODE LIMIT 1];
                //     if (Schema.sObjectType.ContentDocument.isDeletable()) {
                //         delete contentDoc;
                //     }
                // }
                // if (String.isNotBlank(templateWrapper.tempImgId)) {
                //     ContentVersion version = [
                //         SELECT ContentDocument.Id 
                //         FROM ContentVersion 
                //         WHERE Id = :templateWrapper.tempImgId 
                //         WITH USER_MODE 
                //         LIMIT 1
                //     ];

                // }
                ErrorHandler.insertErrordata(null, 'WBTemplateController', 'editWhatsappTemplate', 'HTTP callout failed with status: ' + res.getStatusCode() + ' and body: ' + res.getBody());
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(null, 'WBTemplateController', 'editWhatsappTemplate', 'HTTP callout failed with status: ' + res.getStatusCode() + ' and body: ' + res.getBody());
            // response.put('status', 'error');
            // response.put('message', e.getMessage());
            if (e instanceof CalloutException && e.getMessage().containsIgnoreCase('Read timed out')) {
                response.put('success', false);
                response.put('status', 'warning');
                response.put('message', 'Template is being updated, you will be notified once it is ready.');
                // checkTemplateExistance(templateName, serializedWrapper, payloadWrapper);
            }
            else{
                response.put('success', false);
                response.put('status', 'error');
                response.put('message', e.getMessage());
            }
        }
        return response;
   }

    /*
    *********************************************************
    @description     : Creates a WB Template Edit History record to track template edits.
                       This is used to enforce the 24-hour edit restriction after approval.
    @param           : templateId - The Id of the template being edited
                       serializedWrapper - The serialized template wrapper data
                       payloadWrapper - The payload sent to Meta API
    @return          : void
    ********************************************************
    */
    private static void createTemplateEditHistory(Id templateId, String serializedWrapper, String payloadWrapper) {
        try {
            if (Schema.sObjectType.Template_Edit_History__c.isCreateable()) {
                Template_Edit_History__c editHistory = new Template_Edit_History__c();
                editHistory.WhatsappTemplate__c = templateId;
                editHistory.Edited_Time__c = System.now();
                editHistory.Serialized_Wrapper__c = serializedWrapper;
                editHistory.Payload_JSON__c = payloadWrapper;
                insert editHistory;
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WBTemplateController', 'createTemplateEditHistory', e.getMessage());
        }
    }

   
    @AuraEnabled
    public static string getMetaHeaderHandler(String fileUrlOrContentVersionId,String contentVersionId){
        try {
            String headerHandleResult = '';
            Blob fileBlob;
            String mimeType;
            String fileName;
            Integer fileLength;

            if (fileUrlOrContentVersionId.contains('amazonaws.com')){
                // ---- S3 FILE ----
                Http http = new Http();
                HttpRequest s3Req = new HttpRequest();
                s3Req.setEndpoint(fileUrlOrContentVersionId);
                s3Req.setMethod('GET');

                HttpResponse s3Res = http.send(s3Req);
                if (s3Res.getStatusCode() != 200){
                    ErrorHandler.insertErrordata(null, 'WBTemplateController', 'uploadFileToMetaAndGetHeaderHandle', 'HTTP callout failed with status: ' + s3Res.getStatusCode());

                    System.debug('❌ Failed to fetch file from S3. Status: ' + s3Res.getStatusCode());
                    return '';
                }

                fileBlob = s3Res.getBodyAsBlob();
                mimeType = s3Res.getHeader('Content-Type');
                fileName = fileUrlOrContentVersionId.substring(fileUrlOrContentVersionId.lastIndexOf('/') + 1);
                fileLength = fileBlob.size();
            }
            else{
                ContentVersion cv = [SELECT Title, VersionData, FileExtension, ContentSize
                                     FROM ContentVersion
                                     WHERE Id = :contentVersionId
                                     LIMIT 1];
                fileBlob = cv.VersionData;
                fileName = cv.Title + '.' + cv.FileExtension;
                mimeType = getMimeTypeFromExtension(cv.FileExtension);
                fileLength = cv.ContentSize;
            }

            // ---- START META UPLOAD SESSION ----
            String uploadSessionId = startUploadSession(fileName, fileLength, mimeType);
            if (String.isBlank(uploadSessionId)){
                System.debug('❌ Failed to start Meta upload session.');
                return '';
            }

            // ---- PREPARE FILE WRAPPER ----
            FileChunkWrapper wrapper = new FileChunkWrapper();
            wrapper.uploadSessionId = uploadSessionId;
            wrapper.fileName = fileName;
            wrapper.fileContent = EncodingUtil.base64Encode(fileBlob);
            wrapper.chunkStart = 0;
            wrapper.chunkSize = fileLength;

            String serializedFileWrapper = JSON.serialize(wrapper);

            // ---- UPLOAD TO META ----
            String resultJson = uploadFileChunk(serializedFileWrapper, false);
            Map<String, Object> resultMap = (Map<String, Object>)JSON.deserializeUntyped(resultJson);
            
            if (resultMap.containsKey('headerHandle')){
                headerHandleResult = (String) resultMap.get('headerHandle');
                return headerHandleResult;
            }

            
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WBTemplateController', 'getMetaHeaderHandler', e.getMessage());
        }
        return '';
    }

    @future(callout = true)
    public static void uploadFileToMetaAndGetHeaderHandle(String templateName, String serializedWrapper, String payloadWrapper, String tempalteId){
        String headerHandleResult = '';
        String fileUrlOrContentVersionId = '';
        String contentVersionId = '';
        CreateTemplateWrapper.TemplateWrapper templateWrapper = (CreateTemplateWrapper.TemplateWrapper)JSON.deserialize(serializedWrapper, CreateTemplateWrapper.TemplateWrapper.class);

        fileUrlOrContentVersionId = templateWrapper.tempImgUrl;

        try{
            Blob fileBlob;
            String mimeType;
            String fileName;
            Integer fileLength;

            if (fileUrlOrContentVersionId.contains('amazonaws.com')){
                // ---- S3 FILE ----
                Http http = new Http();
                HttpRequest s3Req = new HttpRequest();
                s3Req.setEndpoint(fileUrlOrContentVersionId);
                s3Req.setMethod('GET');

                HttpResponse s3Res = http.send(s3Req);
                if (s3Res.getStatusCode() != 200){
                    ErrorHandler.insertErrordata(null, 'WBTemplateController', 'uploadFileToMetaAndGetHeaderHandle', 'HTTP callout failed with status: ' + s3Res.getStatusCode() + ' and body: ' + s3Res.getBody());

                    System.debug('❌ Failed to fetch file from S3. Status: ' + s3Res.getStatusCode());
                    return;
                }

            } else{
                // ---- CONTENT VERSION FILE ----
                String jsonStr = templateWrapper.templateMiscellaneousData;

                if (!String.isBlank(jsonStr)){
                    try{
                        Map<String, Object> miscData = (Map<String, Object>)JSON.deserializeUntyped(jsonStr);
                        contentVersionId = (String) miscData.get('contentVersionId');
                        System.debug('ContentVersionId: ' + contentVersionId);
                    } catch (Exception e){
                        ErrorHandler.insertErrordata(e, 'WBTemplateController', 'uploadFileToMetaAndGetHeaderHandle', 'Failed to parse templateMiscellaneousData: ' + e.getMessage());
                        System.debug('Failed to parse templateMiscellaneousData: ' + e.getMessage());
                    }
                }
            }

            headerHandleResult = getMetaHeaderHandler(fileUrlOrContentVersionId, contentVersionId);

            if (headerHandleResult != null && headerHandleResult == ''){
                // Update the header_handle using regex
                payloadWrapper = payloadWrapper.replaceFirst('"header_handle":"[^"]+"', '"header_handle":"' + headerHandleResult + '"');
                templateWrapper.tempHeaderHandle = headerHandleResult;
                serializedWrapper = JSON.serialize(templateWrapper);
                System.debug('Updated serializedWrapper with new header handle: ' + serializedWrapper);
                editWhatsappTemplate(serializedWrapper, payloadWrapper, tempalteId, templateName);

            } else{
                System.debug('⚠ Upload completed but no headerHandle returned.');
            }

        } catch (Exception e){
            ErrorHandler.insertErrordata(e, 'WBTemplateController', 'uploadFileToMetaAndGetHeaderHandle', e.getMessage());
             System.debug('Exception in uploadFileToMetaAndGetHeaderHandle: ' + e.getMessage());
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
        return 'application/octet-stream'; // default fallback
    }


    @AuraEnabled(cacheable=true)
    public static List<Flow__c> getAllFlows() {
        try {
            return [SELECT Id,Flow_Id__c, Flow_Name__c,Flow_JSON__c, LastModifiedDate,Status__c FROM Flow__c  where Status__c =: 'Published' WITH USER_MODE ORDER BY CreatedDate DESC ];
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WBTemplateController', 'getAllFlows', e.getMessage());
            return new List<Flow__c>();
        }
    }


    /**
     ***********************************************************************************************************************************
     * Method Name   : getPreviewURLofWhatsAppFlow
     * @description  : Retrieves the preview URL of a WhatsApp flow using the Meta Graph API.
     * @param flowId : The ID of the WhatsApp flow.
     * @return       : The preview URL if successful, otherwise 'failed'.
     ***********************************************************************************************************************************
     */
    @AuraEnabled
    public static Map<String,String> getPreviewURLofWhatsAppFlow(String flowId) {
        try {

            if (SETTINGS==null || SETTINGS.isEmpty()) {
                return new Map<String,String>{'status' => 'failed', 'error' => 'failed'};
            }

            String accessToken = SETTINGS[0].MVEX__Access_Token__c;
            String endpoint = SETTINGS[0].MVEX__APIEndpoint__c + '/' + SETTINGS[0].MVEX__APIVersion__c + '/' + flowId + '?fields=preview.invalidate(false)';
            HttpRequest request = new HttpRequest();
            request.setEndpoint(endpoint);
            request.setMethod('GET');
            request.setHeader('Authorization', 'Bearer ' + accessToken);
            Http http = new Http();
            HttpResponse response = http.send(request);
            
            if (response.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                Map<String, Object> previewMap = (Map<String, Object>) responseMap.get('preview');
                String previewUrl = (String) previewMap.get('preview_url');
                return new Map<String,String>{'status' => '200', 'previewUrl' => previewUrl};
            } else {
                return new Map<String,String>{'status' => 'failed', 'error' => 'failed'};
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WhatsAppFlowController', 'getPreviewURLofWhatsAppFlow', 'Could not save the embedded sign up details in the metadata!');
            return new Map<String,String>{'status' => 'failed', 'error' => 'failed'};
        }
    }

    /*
    *********************************************************
    @description     : Method to get objects with phone field.
    @return          : List<Map<String, String>> - return list of objects with phone field.
    ********************************************************
    */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getObjectsWithPhoneField() {
        List<Map<String, String>> objectList = new List<Map<String, String>>();
        
        try {
            // Query FieldDefinition to fetch all objects having at least one Phone field
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
            ErrorHandler.insertErrordata(e, 'WBTemplateController', 'getObjectsWithPhoneField', e.getMessage());
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

        Flow__c flowRec = [SELECT Id, Flow_Id__c,Flow_Json__c FROM Flow__c WHERE Flow_Id__c = :flowId LIMIT 1];

        if (flowRec != null && String.isNotBlank(flowRec.Flow_Json__c)) {
            Map<String, Object> flowJson = (Map<String, Object>) JSON.deserializeUntyped(flowRec.Flow_Json__c);

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

        return screenIds[0];
    }

    public class FileChunkWrapper {
        @AuraEnabled public String uploadSessionId;
        @AuraEnabled public String fileContent;
        @AuraEnabled public Integer chunkStart;
        @AuraEnabled public Integer chunkSize;
        @AuraEnabled public String fileName;
        @AuraEnabled public Boolean isLastChunk;
    }
    
    public class TemplateDataWrapper {
        @AuraEnabled public WhatsappTemplate__c template;
        // @AuraEnabled public Object queriedData;
        @AuraEnabled public List<String> objectNames;
        @AuraEnabled public List<String> fieldNames;
        @AuraEnabled public List<Map<String, String>> templateVariables; 
        @AuraEnabled public Boolean isImgUrl;
    }
}