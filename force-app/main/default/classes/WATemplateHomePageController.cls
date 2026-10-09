/**
 * @description       : Controller for the waTemplateHomePage LWC component.
 *                      Handles fetching, picklist values, deletion, and cloning of WhatsApp message templates (WA_Template__c),
 *                      referencing OAuth_Configuration__mdt for the Whatsapp_OAuth custom metadata record.
 * @author            : Karan Singh
 * @last modified on  : 09/10/2026
 **/
public with sharing class WATemplateHomePageController {
    
    private static final String CONFIG_DEV_NAME = 'Whatsapp_OAuth';

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
            List<OAuth_Configuration__mdt> configs = [SELECT Id, DeveloperName, MasterLabel, Client_Id__c, Client_Secret__c, Config_Id__c, API_Version__c, 
                                                        Authorization_Endpoint__c, Token_Endpoint__c, Access_Token__c, Client_App_ID__c, Client_Business_Account_ID__c,
                                                        Client_Phone_Number_ID__c, Connected_Date__c, SystemModstamp FROM OAuth_Configuration__mdt
                                                        WHERE DeveloperName = :CONFIG_DEV_NAME WITH USER_MODE LIMIT 1];
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
                                                Image_Header_Handle__c, Status__c, LastModifiedById, LastModifiedDate, CreatedDate FROM WA_Template__c 
                                                WITH USER_MODE ORDER BY LastModifiedDate DESC LIMIT 50000];
            return templates;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WATemplateHomePageController', 'getWhatsAppTemplates', e.getMessage());
            return new List<WA_Template__c>();
        }
    }

    /**
     * @description : Returns picklist values for Template_Category__c and Status__c from WA_Template__c
     * @return Map<String, List<String>>
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
            ErrorHandler.insertErrordata(e, 'WATemplateHomePageController', 'getCategoryAndStatusPicklistValues', e.getMessage());
            return null;
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
}