public with sharing class SendEmailsController {

    @AuraEnabled
    public static List<Map<String, String>> getMessagingServiceOptions() {
        List<Map<String, String>> optionsList = new List<Map<String, String>>();
        try {
            Map<String, String> optionsMap = new Map<String, String>();
            optionsMap.put('Single Messaging Service', 'single');
            
            OutlookConfig__c outlookConfig = OutlookConfig__c.getOrgDefaults();
            if (outlookConfig != null && !String.isBlank(outlookConfig.Refresh_Token_1__c)) {
                optionsMap.put('Outlook', 'outlook');
            }
            
            GmailConfig__c gmailConfig = GmailConfig__c.getOrgDefaults();
            if (gmailConfig != null && !String.isBlank(gmailConfig.Refresh_Token__c)) {
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
            List<EmailTemplate> emailTemplates = [
                SELECT Id, Name, Subject, Body, HtmlValue, TemplateType, Folder.Name
                FROM EmailTemplate 
                WHERE IsActive = true
                WITH USER_MODE
                ORDER BY Name ASC
            ];
            
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
            List<Template__c> customTemplates = [
                SELECT Id, Template_Name__c, Subject__c, Object_API_Name__c,
                       (SELECT Id, Template_Value_Simple__c, Value_Type__c 
                        FROM Template_Data__r 
                        WHERE Value_Type__c = 'Body Value' 
                        ORDER BY Order_No_Simple__c ASC)
                FROM Template__c 
                WHERE Template_Status__c = true AND Template_pattern__c = 'Marketing Template'
                WITH USER_MODE
                ORDER BY Template_Name__c ASC
            ];
            
            for (Template__c template : customTemplates) {
                String templateBody = '';
                for (Template_Data__c data : template.Template_Data__r) {
                    if (data.Value_Type__c == 'Body Value' && data.Template_Value_Simple__c != null) {
                        templateBody += data.Template_Value_Simple__c;
                    }
                }
            
                // Check for merge fields using regex
                Pattern mergeFieldPattern = Pattern.compile('\\{\\{[#/]?[a-zA-Z0-9_.]+}}');
                Matcher m = mergeFieldPattern.matcher(templateBody);
                String objectName = template.Object_API_Name__c;
                
                if (!m.find()) {
                    objectName = 'Generic'; // No merge fields found
                }
            
                customTemplateOptions.add(new Map<String, Object>{
                    'label' => template.Template_Name__c,
                    'value' => template.Id,
                    'type' => 'EstateXpert Template',
                    'subject' => template.Subject__c,
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
    public static List<Listing__c> getListings() {
        List<Listing__c> listings = new List<Listing__c>();
        try {
            listings = [SELECT Id, Name, Address__c, Listing_Type__c, Listing_Price__c, Status__c FROM Listing__c WITH USER_MODE];
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