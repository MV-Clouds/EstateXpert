public with sharing class SendEmailsController {

    @AuraEnabled
    public static List<Map<String, String>> getMessagingServiceOptions() {
        List<Map<String, String>> optionsList = new List<Map<String, String>>();
        try {
            Map<String, String> optionsMap = new Map<String, String>();
            optionsMap.put('Single Messaging Service', 'single');
            
            MVEX__GmailConfig__c gmailConfig = MVEX__GmailConfig__c.getOrgDefaults();
            if (gmailConfig != null && !String.isBlank(gmailConfig.MVEX__Refresh_Token__c)) {
                optionsMap.put('Gmail', 'gmail');
            }
            
            for (String key : optionsMap.keySet()) {
                optionsList.add(new Map<String, String>{'label' => key, 'value' => optionsMap.get(key)});
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'SendEmailsController', 'getMessagingServiceOptions', e.getStackTraceString());
        }
        return optionsList;
    }
    
    @AuraEnabled
    public static Map<String, Object> getTemplatesByObject() {
        Map<String, Object> result = new Map<String, Object>();
        try {
            List<Map<String, Object>> emailTemplateOptions = new List<Map<String, Object>>();
            List<EmailTemplate> emailTemplates = [SELECT Id, Name, Subject, Body, HtmlValue, TemplateType, Folder.Name FROM EmailTemplate WHERE IsActive = true
                                                    WITH USER_MODE ORDER BY Name ASC LIMIT 50000];
            
            for (EmailTemplate template : emailTemplates) {
                emailTemplateOptions.add(new Map<String, Object>{
                    'label' => template.Name,
                    'value' => template.Id,
                    'type' => 'Email Template',
                    'subject' => template.Subject,
                    'body' => template.HtmlValue != null ? template.HtmlValue : template.Body,
                    'templateType' => template.TemplateType
                });
            }
            
            List<Map<String, Object>> customTemplateOptions = new List<Map<String, Object>>();
            List<MVEX__Template__c> customTemplates = [SELECT Id, MVEX__Template_Name__c, MVEX__Subject__c, MVEX__Object_API_Name__c,
                                                       (SELECT Id, MVEX__Template_Value_Simple__c, MVEX__Value_Type__c FROM MVEX__Template_Data__r 
                                                        WHERE MVEX__Value_Type__c = 'Body Value' ORDER BY MVEX__Order_No_Simple__c ASC)
                                                        FROM MVEX__Template__c WHERE MVEX__Template_Status__c = true AND MVEX__Template_pattern__c = 'Marketing Template'
                                                        WITH USER_MODE ORDER BY MVEX__Template_Name__c ASC];
            
            for (MVEX__Template__c template : customTemplates) {
                String templateBody = '';
                for (MVEX__Template_Data__c data : template.MVEX__Template_Data__r) {
                    if (data.MVEX__Value_Type__c == 'Body Value' && data.MVEX__Template_Value_Simple__c != null) {
                        templateBody += data.MVEX__Template_Value_Simple__c;
                    }
                }
            
                // Check for merge fields using regex
                Pattern mergeFieldPattern = Pattern.compile('\\{\\{[#/]?[a-zA-Z0-9_.]+}}');
                Matcher m = mergeFieldPattern.matcher(templateBody);
                String objectName = template.MVEX__Object_API_Name__c;
                
                if (!m.find()) {
                    objectName = 'Generic'; // No merge fields found
                }
            
                customTemplateOptions.add(new Map<String, Object>{
                    'label' => template.MVEX__Template_Name__c,
                    'value' => template.Id,
                    'type' => 'EstateXpert Template',
                    'subject' => template.MVEX__Subject__c,
                    'body' => templateBody,
                    'objectName' => objectName
                });
            }
            
            
            result.put('emailTemplates', emailTemplateOptions);
            result.put('customTemplates', customTemplateOptions);
            
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'SendEmailsController', 'getTemplatesByObject', e.getStackTraceString());
        }
        return result;
    }

    @AuraEnabled
    public static List<MVEX__Listing__c> getListings() {
        List<MVEX__Listing__c> listings = new List<MVEX__Listing__c>();
        try {
            listings = [SELECT Id, Name, MVEX__Address__c, MVEX__Listing_Type__c, MVEX__Listing_Price__c, MVEX__Status__c FROM MVEX__Listing__c WITH USER_MODE];
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'SendEmailsController', 'getListings', e.getStackTraceString());
        }
        return listings;
    }

    @AuraEnabled
    public static List<Contact> getAllContacts() {
        List<Contact> contacts = new List<Contact>();
        try {
            contacts = [SELECT Id, Name, Email, Phone 
                        FROM Contact 
                        WHERE Email != null 
                        WITH USER_MODE 
                        ORDER BY Name ASC LIMIT 50000];
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'SendEmailsController', 'getAllContacts', e.getStackTraceString());
        }
        return contacts;
    }
}