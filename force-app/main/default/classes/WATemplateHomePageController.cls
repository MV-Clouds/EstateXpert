/**
 * @description       : Controller for the waTemplateHomePage LWC component.
 *                      Handles fetching, picklist values, deletion, and cloning of WhatsApp message templates (WA_Template__c),
 *                      referencing OAuth_Configuration__mdt for the Whatsapp_OAuth custom metadata record.
 * @author            : Karan Singh
 * @last modified on  : 09/10/2026
 **/
public with sharing class WATemplateHomePageController {
    @TestVisible
    private static OAuth_Configuration__mdt mockConfig;

    /**
     * @description : Retrieves the WhatsApp OAuth Custom Metadata configuration record for Whatsapp_OAuth
     * @return OAuth_Configuration__mdt
     */
    public static OAuth_Configuration__mdt getConfig() {
        try {
            if (mockConfig != null) {
                return mockConfig;
            }
            String CONFIGDEVNAME = WhatsappConnectController.CONFIG_DEV_NAME;

            List<OAuth_Configuration__mdt> configs = [SELECT Id, DeveloperName, MasterLabel, Client_Id__c, Client_Secret__c, Config_Id__c, API_Version__c, 
                                                        Authorization_Endpoint__c, Token_Endpoint__c, Access_Token__c, Client_App_ID__c, Client_Business_Account_ID__c,
                                                        Client_Phone_Number_ID__c, Connected_Date__c, SystemModstamp FROM OAuth_Configuration__mdt
                                                        WHERE DeveloperName = :CONFIGDEVNAME WITH USER_MODE LIMIT 1];
            return configs.isEmpty() ? null : configs[0];
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WATemplateHomePageController', 'getConfig', e.getMessage());
            return null;
        }
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

    /**
     * @description : Used in waTemplateHomePage to get all WA_Template__c template records.
     * @return List<WA_Template__c>
     */
    @AuraEnabled
    public static List<WA_Template__c> getWhatsAppTemplates() {
        try {
            List<WA_Template__c> templates = [SELECT Id, Name, Template_Name__c, Template_Category__c, toLabel(Language__c) LanguageLabel, File_Name__c, 
                                                Image_Header_Handle__c, Status__c, Quality_Rating__c, Rejection_Reason__c, Previous_Status__c,
                                                Last_Meta_Edit_Time__c, Edit_Timestamps_JSON__c, Edit_Count_30_Days__c, Last_Status_Update_Time__c,
                                                LastModifiedById, LastModifiedDate, CreatedDate FROM WA_Template__c 
                                                WITH USER_MODE ORDER BY LastModifiedDate DESC LIMIT 50000];
            return templates;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WATemplateHomePageController', 'getWhatsAppTemplates', e.getMessage());
            return new List<WA_Template__c>();
        }
    }



    /**
     * @description : Method used to delete template from Meta API as well as from Salesforce.
     * @param templateId - Id of WA_Template__c record to delete
     * @return String result message
     */
    @AuraEnabled
    public static String deleteTemplete(String templateId) {
        try {
            WA_Template__c wbTempRec = [SELECT Id, Name, Template_Name__c, Status__c, Template_Id__c FROM WA_Template__c WHERE Id = :templateId WITH USER_MODE LIMIT 1];

            // If template is Draft or has no Meta ID, delete directly from Salesforce
            if (wbTempRec.Status__c == 'Draft' || wbTempRec.Status__c == 'DRAFT' || String.isBlank(wbTempRec.Template_Id__c) || wbTempRec.Template_Id__c == 'DRAFT') {
                if (WA_Template__c.sObjectType.getDescribe().isDeletable()) {
                    delete wbTempRec;
                }
                return 'Template deleted successfully';
            }

            OAuth_Configuration__mdt config = getConfig();
            String wabaId = (config != null && config.Client_Business_Account_ID__c != null) ? config.Client_Business_Account_ID__c : '';
            if (String.isBlank(wabaId)) {
                return 'Business Account ID is not configured in the system.';
            }

            String apiEndpoint = (config != null && String.isNotBlank(config.Authorization_Endpoint__c)) 
                                    ? config.Authorization_Endpoint__c.removeEnd('/') : 'https://graph.facebook.com';
            String apiVersion = (config != null && String.isNotBlank(config.API_Version__c)) 
                                ? (config.API_Version__c.trim().startsWithIgnoreCase('v') ? config.API_Version__c.trim() : 'v' + config.API_Version__c.trim()) : 'v24.0';
            String token = (config != null && config.Access_Token__c != null) ? config.Access_Token__c : '';

            String endpoint = apiEndpoint + '/' + apiVersion + '/' + wabaId + '/message_templates?name=' + wbTempRec.Template_Name__c;

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
                    ErrorHandler.insertErrordata(null, 'WATemplateHomePageController', 'deleteTemplete', res.getBody());
                    returnMessage = 'Template deletion failed in Meta';
                }
            } else {
                ErrorHandler.insertErrordata(null, 'WATemplateHomePageController', 'deleteTemplete', res.getBody());
                returnMessage = 'Template deletion failed with status: ' + statusCode;
            }

            if (shouldDeleteFromSF && WA_Template__c.sObjectType.getDescribe().isDeletable()) {
                delete wbTempRec;
            }

            return returnMessage;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WATemplateHomePageController', 'deleteTemplete', e.getMessage());
            return e.getMessage();
        }
    }

    /**
     * @description : Clones a WA_Template__c record and its WA_Template_Variable__c children.
     * @param templateId - Id of the source WA_Template__c to clone.
     * @param newName    - Value for Template_Name__c on the cloned record.
     * @return Map<String,String> status, message, and clonedId
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
            ErrorHandler.insertErrordata(e, 'WATemplateHomePageController', 'cloneWBTemplate', e.getMessage());
            result.put('status',  'error');
            result.put('message', 'Error cloning template: ' + e.getMessage());
            return result;
        }
    }

    /*
    *********************************************************
    @description     : Method to get template preview data for waTemplatePreview component.
    @param           : templateId - {String} - Id of the WA_Template__c record
    @return          : Map<String, Object> containing template, isMediaHeader, and variables.
    ********************************************************
    */
    @AuraEnabled
    public static Map<String, Object> getTemplatePreviewData(String templateId) {
        try {
            Map<String, Object> templateData = new Map<String, Object>();
            if (String.isBlank(templateId)) {
                return templateData;
            }

            List<WA_Template__c> templates = [
                SELECT Id, Name, Template_Name__c, Button_Body__c, Button_Label__c, Button_Type__c, 
                       Footer_Body__c, Header_Body__c, Header_Type__c, toLabel(Language__c) LanguageLabel, Language__c, 
                       Template_Body__c, Template_Category__c, Template_Miscellaneous_Data__c, 
                       File_Name__c, Image_Header_Handle__c, Status__c, Quality_Rating__c,
                       (SELECT Id, Name, Field_Name__c, Object_Name__c, Type__c, Alternate_Text__c 
                        FROM WA_Template_Variables__r ORDER BY Name ASC) 
                FROM WA_Template__c 
                WHERE Id = :templateId 
                WITH USER_MODE 
                LIMIT 1
            ];

            if (templates.isEmpty()) {
                return templateData;
            }

            WA_Template__c template = templates[0];
            templateData.put('template', template);
            templateData.put('isMediaHeader', template.Header_Type__c == 'Image' || template.Header_Type__c == 'Video' || template.Header_Type__c == 'Document');

            List<Map<String, String>> variableList = new List<Map<String, String>>();
            Set<String> detectedObjects = new Set<String>();
            if (template.WA_Template_Variables__r != null) {
                for (WA_Template_Variable__c tv : template.WA_Template_Variables__r) {
                    Map<String, String> vMap = new Map<String, String>();
                    vMap.put('name', tv.Name);
                    vMap.put('type', tv.Type__c);
                    vMap.put('fieldName', tv.Field_Name__c);
                    vMap.put('objectName', tv.Object_Name__c);
                    vMap.put('alternateText', tv.Alternate_Text__c);
                    variableList.add(vMap);

                    if (String.isNotBlank(tv.Object_Name__c)) {
                        detectedObjects.add(tv.Object_Name__c);
                    }
                }
            }
            templateData.put('variables', variableList);
            templateData.put('detectedObjects', new List<String>(detectedObjects));

            return templateData;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WATemplateHomePageController', 'getTemplatePreviewData', e.getMessage());
            return new Map<String, Object>();
        }
    }

    /*
    *********************************************************
    @description     : Searches records of a specified sObject for variable replacement preview.
    @param           : objectName - API name of the sObject (e.g. Contact, Lead, Account)
    @param           : searchTerm - Search term to filter records by Name/Email
    @return          : List<Map<String, String>> containing id, title, subtitle, objectName
    ********************************************************
    */
    @AuraEnabled
    public static List<Map<String, String>> searchPreviewRecords(String objectName, String searchTerm) {
        List<Map<String, String>> results = new List<Map<String, String>>();
        try {
            if (String.isBlank(objectName)) {
                return results;
            }

            Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
            if (!globalDescribe.containsKey(objectName.toLowerCase())) {
                return results;
            }

            Schema.SObjectType sObjType = globalDescribe.get(objectName.toLowerCase());
            Schema.DescribeSObjectResult sObjDescribe = sObjType.getDescribe();
            if (!sObjDescribe.isAccessible()) {
                return results;
            }

            Map<String, Schema.SObjectField> fieldMap = sObjDescribe.fields.getMap();
            Boolean hasName = fieldMap.containsKey('name');
            Boolean hasFirstName = fieldMap.containsKey('firstname');
            Boolean hasLastName = fieldMap.containsKey('lastname');
            Boolean hasEmail = fieldMap.containsKey('email');
            Boolean hasPhone = fieldMap.containsKey('phone');

            List<String> selectFields = new List<String>{ 'Id' };
            if (hasName) selectFields.add('Name');
            if (hasFirstName) selectFields.add('FirstName');
            if (hasLastName) selectFields.add('LastName');
            if (hasEmail) selectFields.add('Email');
            if (hasPhone) selectFields.add('Phone');

            String query = 'SELECT ' + String.join(selectFields, ', ') + ' FROM ' + String.escapeSingleQuotes(objectName);

            String sanitizedTerm = (searchTerm != null) ? searchTerm.trim() : '';
            if (String.isNotBlank(sanitizedTerm)) {
                String filter = '%' + String.escapeSingleQuotes(sanitizedTerm) + '%';
                List<String> whereClauses = new List<String>();
                if (hasName) {
                    whereClauses.add('Name LIKE \'' + filter + '\'');
                } else if (hasLastName) {
                    whereClauses.add('LastName LIKE \'' + filter + '\'');
                }
                if (hasEmail) {
                    whereClauses.add('Email LIKE \'' + filter + '\'');
                }
                if (!whereClauses.isEmpty()) {
                    query += ' WHERE (' + String.join(whereClauses, ' OR ') + ')';
                }
            }

            query += ' WITH USER_MODE ORDER BY LastModifiedDate DESC LIMIT 10';

            List<SObject> records = Database.query(query);
            for (SObject rec : records) {
                Map<String, String> item = new Map<String, String>();
                item.put('id', (String) rec.get('Id'));

                String title = '';
                if (hasFirstName && hasLastName) {
                    String fn = (String) rec.get('FirstName');
                    String ln = (String) rec.get('LastName');
                    title = ((String.isNotBlank(fn) ? fn + ' ' : '') + (String.isNotBlank(ln) ? ln : '')).trim();
                }
                if (String.isBlank(title) && hasName) {
                    title = (String) rec.get('Name');
                }
                if (String.isBlank(title)) {
                    title = (String) rec.get('Id');
                }
                item.put('title', title);

                String subtitle = '';
                if (hasEmail && rec.get('Email') != null) {
                    subtitle = (String) rec.get('Email');
                } else if (hasPhone && rec.get('Phone') != null) {
                    subtitle = (String) rec.get('Phone');
                }
                item.put('subtitle', subtitle);
                item.put('objectName', objectName);

                results.add(item);
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WATemplateHomePageController', 'searchPreviewRecords', e.getMessage());
        }
        return results;
    }

    /*
    *********************************************************
    @description     : Returns template preview data with variable values replaced from a selected record.
    @param           : templateId - Id of the WA_Template__c record
    @param           : objectName - Object name of the record (e.g. Contact, Lead)
    @param           : recordId - Id of the record to fetch merge data from
    @return          : result {Map<String, Object>}
    ********************************************************
    */
    @AuraEnabled
    public static Map<String, Object> getTemplatePreviewDataWithRecord(String templateId, String objectName, String recordId) {
        try {
            Map<String, Object> templateData = new Map<String, Object>();
            if (String.isBlank(templateId)) {
                return templateData;
            }

            List<WA_Template__c> templates = [
                SELECT Id, Name, Template_Name__c, Button_Body__c, Button_Label__c, Button_Type__c, Image_Header_Handle__c, 
                       Footer_Body__c, Header_Body__c, Header_Type__c, toLabel(Language__c) LanguageLabel, Language__c, File_Name__c, 
                       Template_Body__c, Template_Category__c, Template_Miscellaneous_Data__c, Status__c, Quality_Rating__c,
                       (SELECT Id, Name, Field_Name__c, Object_Name__c, Type__c, Alternate_Text__c 
                        FROM WA_Template_Variables__r ORDER BY Name ASC) 
                FROM WA_Template__c 
                WHERE Id = :templateId 
                WITH USER_MODE 
                LIMIT 1
            ];

            if (templates.isEmpty()) {
                return templateData;
            }

            WA_Template__c template = templates[0];
            templateData.put('template', template);
            templateData.put('isMediaHeader', template.Header_Type__c == 'Image' || template.Header_Type__c == 'Video' || template.Header_Type__c == 'Document');

            List<Map<String, String>> variableList = new List<Map<String, String>>();
            Set<String> detectedObjects = new Set<String>();

            if (template.WA_Template_Variables__r != null) {
                for (WA_Template_Variable__c tv : template.WA_Template_Variables__r) {
                    Map<String, String> vMap = new Map<String, String>();
                    vMap.put('name', tv.Name);
                    vMap.put('type', tv.Type__c);
                    vMap.put('fieldName', tv.Field_Name__c);
                    vMap.put('objectName', tv.Object_Name__c);
                    vMap.put('alternateText', tv.Alternate_Text__c);
                    variableList.add(vMap);

                    if (String.isNotBlank(tv.Object_Name__c)) {
                        detectedObjects.add(tv.Object_Name__c);
                    }
                }
            }
            templateData.put('variables', variableList);
            templateData.put('detectedObjects', new List<String>(detectedObjects));

            String replacedHeader = template.Header_Body__c;
            String replacedBody = template.Template_Body__c;
            Map<String, String> replacements = new Map<String, String>();

            if (String.isNotBlank(recordId) && String.isNotBlank(objectName) && template.WA_Template_Variables__r != null && !template.WA_Template_Variables__r.isEmpty()) {
                Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
                if (globalDescribe.containsKey(objectName.toLowerCase())) {
                    Schema.DescribeSObjectResult objDescribe = globalDescribe.get(objectName.toLowerCase()).getDescribe();
                    Map<String, Schema.SObjectField> fieldMap = objDescribe.fields.getMap();

                    Set<String> queryFields = new Set<String>{ 'Id' };
                    for (WA_Template_Variable__c tv : template.WA_Template_Variables__r) {
                        if (String.isNotBlank(tv.Field_Name__c) && (String.isBlank(tv.Object_Name__c) || tv.Object_Name__c.equalsIgnoreCase(objectName))) {
                            String fName = tv.Field_Name__c.toLowerCase();
                            if (fieldMap.containsKey(fName)) {
                                queryFields.add(fieldMap.get(fName).getDescribe().getName());
                            } else if (tv.Field_Name__c.contains('.')) {
                                queryFields.add(tv.Field_Name__c);
                            }
                        }
                    }

                    String query = 'SELECT ' + String.join(new List<String>(queryFields), ', ') + ' FROM ' + String.escapeSingleQuotes(objectName) + ' WHERE Id = :recordId WITH USER_MODE LIMIT 1';
                    List<SObject> queriedRecords = Database.query(query);

                    if (!queriedRecords.isEmpty()) {
                        SObject record = queriedRecords[0];

                        for (WA_Template_Variable__c tv : template.WA_Template_Variables__r) {
                            Object val = null;
                            if (String.isNotBlank(tv.Field_Name__c) && (String.isBlank(tv.Object_Name__c) || tv.Object_Name__c.equalsIgnoreCase(objectName))) {
                                try {
                                    if (tv.Field_Name__c.contains('.')) {
                                        List<String> parts = tv.Field_Name__c.split('\\.');
                                        SObject currentObj = record;
                                        for (Integer i = 0; i < parts.size() - 1; i++) {
                                            if (currentObj != null) {
                                                currentObj = currentObj.getSObject(parts[i]);
                                            }
                                        }
                                        if (currentObj != null) {
                                            val = currentObj.get(parts[parts.size() - 1]);
                                        }
                                    } else {
                                        val = record.get(tv.Field_Name__c);
                                    }
                                } catch (Exception fieldEx) {
                                    System.debug('Error getting field value: ' + fieldEx.getMessage());
                                }
                            }

                            String replacement = (val != null) ? String.valueOf(val) : 
                                                 (String.isNotBlank(tv.Alternate_Text__c) ? tv.Alternate_Text__c : '');

                            String cleanVarName = tv.Name;
                            if (cleanVarName != null) {
                                cleanVarName = cleanVarName.replace('{', '').replace('}', '').trim();
                            }

                            if (String.isNotBlank(replacement)) {
                                replacements.put(cleanVarName, replacement);

                                if (String.isNotBlank(replacedHeader)) {
                                    replacedHeader = replacedHeader.replace('{{' + cleanVarName + '}}', replacement);
                                    replacedHeader = replacedHeader.replace('{' + cleanVarName + '}', replacement);
                                }
                                if (String.isNotBlank(replacedBody)) {
                                    replacedBody = replacedBody.replace('{{' + cleanVarName + '}}', replacement);
                                    replacedBody = replacedBody.replace('{' + cleanVarName + '}', replacement);
                                }
                            }
                        }
                    }
                }
            }

            templateData.put('replacedHeader', replacedHeader);
            templateData.put('replacedBody', replacedBody);
            templateData.put('replacements', replacements);

            return templateData;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WATemplateHomePageController', 'getTemplatePreviewDataWithRecord', e.getMessage());
            return new Map<String, Object>();
        }
    }

    /*
    *********************************************************
    @description     : Returns template data with merged variable replacements for preview.
    @param           : templateId - Id of the WA_Template__c record
    @param           : contactId - Optional contact Id to preview merge values
    @return          : result {Map<String, Object>}
    ********************************************************
    */
    @AuraEnabled
    public static Map<String, Object> getTemplateDataWithReplacement(String templateId, String contactId) {
        return getTemplatePreviewDataWithRecord(templateId, 'Contact', contactId);
    }
}