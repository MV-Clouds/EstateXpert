/**
 * @description       : This apex class is used to display property from the record page of listing and inquiry
 * @author            : MitrajSinh Gohil
 * @last modified on  : 25-07-2024
 * @last modified by  : Rachit Shah
 **/
public with sharing class PropertySearchController {
    
    /**
     * @description       : This wrapper class is used to send data from apex method
     * @author            : MitrajSinh Gohil
     * @last modified on  : 25-07-2024
     * @last modified by  : Rachit Shah
     **/
    public class WrapperClass {
        @AuraEnabled
        public List<Listing__c> listings;
        @AuraEnabled
        public List<Inquiry__c> inquiries;
        @AuraEnabled
        public Map<Id, String> medias;
    }
    
    @AuraEnabled
    public static string getObjectName(String recId){
        try {
            Id recordId = Id.valueOf(recId);
            String objectName = recordId.getSObjectType().getDescribe().getName();
            return objectName;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e,'PropertySearchController','getObjectName' , e.getStackTraceString());
            return '';
        }
    }
    
    
    
    /**
     * @description       : This apex class method is used for getting listing and inquiry data
     * @author            : MitrajSinh Gohil
     * @last modified on  : 25-07-2024
     * @last modified by  : Rachit Shah
     **/
    @AuraEnabled
    public static WrapperClass getRecords(String recId, String objectName) {
        try {
            if (String.isBlank(objectName) && !String.isBlank(recId)) {
                Id recordId = Id.valueOf(recId);
                objectName = recordId.getSObjectType().getDescribe().getName();
            }

            WrapperClass wc = new WrapperClass();
            Set<Id> propertyIds = new Set<Id>();
            List<Listing__c> listings = new List<Listing__c>();
            List<Inquiry__c> inquiries = new List<Inquiry__c>();
            List<Listing__c> currentListing = new List<Listing__c>();
            List<Inquiry__c> currentInquiry = new List<Inquiry__c>();
            
            String listingFields = String.escapeSingleQuotes(getAllFields('Listing__c'));
            String inquiryFields = String.escapeSingleQuotes(getAllFields('Inquiry__c'));
            
            String listingData = 'SELECT ' + listingFields + ', (SELECT ' + inquiryFields + ' FROM Inquiries__r) FROM Listing__c WHERE Id = :recId';
            String inquiryData = 'SELECT ' + inquiryFields + ' FROM Inquiry__c';
            
            String listingData2 = 'SELECT ' + listingFields + ', (SELECT ' + inquiryFields + ' FROM Inquiries__r) FROM Listing__c';
            String inquiryData2 = 'SELECT ' + inquiryFields + ' FROM Inquiry__c WHERE id =:recId';
            
            if (objectName == 'Listing__c') {
                currentListing = Database.query(listingData, AccessLevel.USER_MODE);
                inquiries = Database.query(inquiryData, AccessLevel.USER_MODE);

                wc.listings = currentListing;
                wc.inquiries = inquiries;
                
            }
            else if (objectName == 'Inquiry__c') {
                currentInquiry = Database.query(inquiryData2, AccessLevel.USER_MODE);
                listings = Database.query(listingData2, AccessLevel.USER_MODE);
                
                for (Listing__c listing : listings) {
                    propertyIds.add(listing.Property__c);
                }
                
                wc.listings = listings;
                wc.inquiries = currentInquiry;
            }

            List<Property_File__c> medias = [SELECT Id, BaseUrl__c, Property__c FROM Property_File__c WHERE Property__c IN :propertyIds WITH USER_MODE];
            Map<Id, String> propertyMediaUrlsMap = new Map<Id, String>();
            for (Property_File__c media : medias) {
                propertyMediaUrlsMap.put(media.Property__c, media.BaseUrl__c);
            }
            
            wc.medias = propertyMediaUrlsMap;
            
            return wc;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e,'PropertySearchController','getRecords' , e.getStackTraceString());
            return null;
        }
    }
    
    private static String getAllFields(String objectName) {
        try {
            Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
            if (globalDescribe.containsKey(objectName)) {
                Schema.SObjectType sObjectType = globalDescribe.get(objectName);
                Schema.DescribeSObjectResult describeResult = sObjectType.getDescribe();
                Map<String, Schema.SObjectField> fieldsMap = describeResult.fields.getMap();
                
                List<String> fieldNames = new List<String>();
                
                for (String fieldName : fieldsMap.keySet()) {
                    Schema.DescribeFieldResult fieldDescribe = fieldsMap.get(fieldName).getDescribe();
                    if (fieldDescribe.isAccessible()) {
                        fieldNames.add(fieldName);
                    }
                }
                
                return String.join(fieldNames, ',');
            } else {
                return '';
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e,'PropertySearchController','getAllFields' , e.getStackTraceString());
            return '';
        }
    }
    
    @AuraEnabled
    public static void sendEmail(String emailDataJson) {
        
        try {
            Map<String, Map<String, String>> contactEmailInfoMap = new Map<String, Map<String, String>>();
            Map<String, Object> emailData = (Map<String, Object>) JSON.deserializeUntyped(emailDataJson);
            
            String sendMethod = (String) emailData.get('sendMethod');
            String templateId = (String) emailData.get('templateId');
            String listingId = (String) emailData.get('listingId');
            
            List<Object> inquiryListRaw = (List<Object>) emailData.get('inquiry');
            List<Map<String, Object>> inquiries = new List<Map<String, Object>>();
            
            List<ContentVersion> listingContentVersion = [SELECT Title, VersionData, ContentDocumentId FROM ContentVersion WHERE FirstPublishLocationId = :listingId WITH USER_MODE ORDER BY CreatedDate DESC LIMIT 1];
            
            for (Object inquiryRaw : inquiryListRaw) {
                inquiries.add((Map<String, Object>) inquiryRaw);
            }
            
            List<GmailIntegrationControllerV1.EmailWrapper> gmails = new List<GmailIntegrationControllerV1.EmailWrapper>();
            List<OutlookIntegrationController.EmailWrapper> outlookMails = new List<OutlookIntegrationController.EmailWrapper>();
            String templateBody = '';
            
            List<Template__c> temp = [SELECT Id, Template_Name__c,Subject__c,
            (SELECT Id, Template_Value_Simple__c, Value_Type__c FROM Template_Data__r WHERE Value_Type__c = 'Body Value' ORDER BY Order_No_Simple__c ASC),
            (SELECT Id, Page_Margin__c, Page_Orientation__c, Page_Size__c, Unit_of_Page_Configs__c, Show_Header__c, Show_Footer__c, Header_margin_top__c, Footer_margin_bottom__c FROM Template_Pages__r ORDER BY Page_Number__c ASC)
            FROM Template__c WHERE Id = :templateId WITH USER_MODE LIMIT 1 ];
            
            if (temp.size() > 0) {
                for (Template_Data__c fieldData : temp[0].Template_Data__r) {
                    String value = fieldData.Template_Value_Simple__c != null ? fieldData.Template_Value_Simple__c : '';
                    if (fieldData.Value_Type__c == 'Body Value') {
                        templateBody += value;
                    }
                }
            }
            
            // Extract the Contact__c IDs from the inquiries
            List<Id> contactIds = new List<Id>();
            for (Map<String, Object> inquiry : inquiries) {
                if (inquiry.containsKey('contact__c') && inquiry.get('contact__c') != null) {
                    contactIds.add((Id) inquiry.get('contact__c'));
                }
            }

            // Query contact information based on Contact__c field
            List<Contact> contacts = [SELECT Id, Email, FirstName, LastName FROM Contact WHERE Id IN :contactIds WITH USER_MODE];

            List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
            
            for (Contact contact : contacts) {
                if (contact.Email != null && contact.Email != '') {
                    Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                    
                    Map<String, Map<String, String>> mappingKeys = DataMappingControllerV2.getMappingsKeyValues(new List<String>{templateId}, contact.Id, true);
                    Map<String, String> mappingKeyVsMappingValues = mappingKeys.get('objectNGeneral');
                    Map<String, String> salesforceImages = mappingKeys.get('salesforceImages');
                    
                    for (String key : mappingKeyVsMappingValues.keySet()) {
                        String escapedKey = Pattern.quote(key); // Escapes special characters in the key
                        templateBody = templateBody.replaceAll(escapedKey, mappingKeyVsMappingValues.get(key));
                    }
                    
                    for (String src : salesforceImages.keySet()) {
                        String escapedSrc = Pattern.quote(src); // Escapes special characters in the src
                        templateBody = templateBody.replaceAll(escapedSrc, salesforceImages.get(src));
                    }
                    
                    if (sendMethod == 'single') {
                        if (!listingContentVersion.isEmpty()) {
                            Messaging.EmailFileAttachment emailAttachment = new Messaging.EmailFileAttachment();
                            
                            emailAttachment.setFileName(listingContentVersion[0].Title);
                            emailAttachment.setBody(listingContentVersion[0].VersionData);
                            emailAttachment.setContentType('application/pdf');
                            
                            email.setFileAttachments(new Messaging.EmailFileAttachment[] { emailAttachment });
                        }
                        
                        email.setToAddresses(new List<String>{contact.Email});
                        email.setSubject(temp[0].Subject__c);
                        email.setHtmlBody(templateBody);
                        
                        String replyToEmail = Label.EmailMessageEmailService;
                        
                        if(replyToEmail != null){
                            email.setReplyTo(replyToEmail);
                        }
                        
                        emails.add(email);
                        
                        contactEmailInfoMap.put(contact.Id, new Map<String, String>{
                            'subject' => temp[0].Subject__c,
                            'body' => templateBody,
                            'email' => contact.Email,
                            'cc' => '',
                            'bcc' => ''
                        });
                        
                    } else if (sendMethod == 'outlook') {
                        OutlookIntegrationController.EmailWrapper singleOutlookMail = new OutlookIntegrationController.EmailWrapper();
                        singleOutlookMail.toAddresses = new List<String>{contact.Email};
                        singleOutlookMail.subject = temp[0].Subject__c;
                        singleOutlookMail.body = templateBody;
                        
                        if (singleOutlookMail.contactEmailInfoMap == null) {
                            singleOutlookMail.contactEmailInfoMap = new Map<String, Map<String, String>>();
                        }
                        
                        singleOutlookMail.contactEmailInfoMap.put(contact.Id, new Map<String, String>{
                            'subject' =>  temp[0].Subject__c,
                            'body' => templateBody,
                            'email' => contact.Email,
                            'cc' => '',
                            'bcc' => ''
                        });
                        
                        outlookMails.add(singleOutlookMail);
                    } else if (sendMethod == 'gmail') {
                        GmailIntegrationControllerV1.EmailWrapper singleGmail = new GmailIntegrationControllerV1.EmailWrapper();
                        singleGmail.toAddresses = new List<String>{contact.Email};
                        singleGmail.subject = temp[0].Subject__c;
                        singleGmail.body = templateBody;
                        
                        if (singleGmail.contactEmailInfoMap == null) {
                            singleGmail.contactEmailInfoMap = new Map<String, Map<String, String>>();
                        }
                        
                        singleGmail.contactEmailInfoMap.put(contact.Id, new Map<String, String>{
                            'subject' =>  temp[0].Subject__c,
                            'body' => templateBody,
                            'email' => contact.Email,
                            'cc' => '',
                            'bcc' => ''
                        });
                        
                        gmails.add(singleGmail);
                    }
                }
            }
            
            // Send emails through Salesforce
            if (!emails.isEmpty()) {
                List<Messaging.SendEmailResult> mrs = Messaging.sendEmail(emails);
                
                Boolean allEmailsSentSuccessfully = true;
                
                for (Messaging.SendEmailResult mr : mrs) {
                    if (!mr.isSuccess()) {
                        allEmailsSentSuccessfully = false;
                    }
                }
                
                if (allEmailsSentSuccessfully) {
                    deleteContentVersion(listingContentVersion);
                }
                
                CreateActivityFromMail2.createCaseEmailMessage(contactEmailInfoMap);
            }
            // Send emails through Gmail
            else if (!gmails.isEmpty()) {
                GmailIntegrationControllerV1.requestNewAccessToken(gmails,null,null,false);
            }
            // Send emails through Outlook
            else if (!outlookMails.isEmpty()) {
                OutlookIntegrationController.requestNewAccessToken(outlookMails,null,null,false);
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'PropertySearchController', 'sendEmail', 'Error while sending email.');
        }
        
    }
    
    public static void deleteContentVersion(List<ContentVersion> contentVersions) {
        try {
            if (contentVersions.isEmpty()) {
                return;
            }
            
            List<Id> contentDocumentIds = new List<Id>();
            for (ContentVersion contentVersion : contentVersions) {
                contentDocumentIds.add(contentVersion.ContentDocumentId);
            }
            
            List<ContentDocument> contentDocuments = [SELECT Id FROM ContentDocument WHERE Id IN :contentDocumentIds WITH USER_MODE];
            
            if (!contentDocuments.isEmpty()) {
                delete as user contentDocuments;
            }
            
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'PropertySearchController', 'deleteContentVersion', 'Error while deleting content version.');
        }
    }
    
    public class FieldWrapper {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public String type;
        @AuraEnabled public List<String> picklistValues;
        @AuraEnabled public String referenceTo;
    }
    
    public class ObjectFieldsWrapper {
        @AuraEnabled public List<FieldWrapper> fields;
    }
    
    @AuraEnabled
    public static ObjectFieldsWrapper getObjectFields(String objectName){
        ObjectFieldsWrapper result = new ObjectFieldsWrapper();
        result.fields = new List<FieldWrapper>();
        try {
            // Get the object's label
            Schema.DescribeSObjectResult describeSObjectResult = Schema.getGlobalDescribe().get(objectName).getDescribe();
            
            // Get the object's fields
            Map<String, Schema.SObjectField> fieldsMap = describeSObjectResult.fields.getMap();
            for (String fieldName : fieldsMap.keySet()) {
                Schema.DescribeFieldResult fieldDescribe = fieldsMap.get(fieldName).getDescribe();
                FieldWrapper fieldInfo = new FieldWrapper();
                fieldInfo.label = fieldDescribe.getLabel();
                fieldInfo.value = fieldName;
                
                List<String> textFields = new List<String>{'STRING', 'TEXTAREA', 'ID'};
                List<String> numberFields = new List<String>{'CURRENCY', 'DOUBLE', 'PHONE'};
                
                String fieldType = fieldDescribe.getType().name();
                
                if (textFields.contains(fieldType)) {
                    fieldInfo.type = 'TEXT';
                } else if (numberFields.contains(fieldType)) {
                    fieldInfo.type = 'NUMBER';
                } else {
                    fieldInfo.type = fieldType;
                }
                
                fieldInfo.picklistValues = new List<String>();
                
                if (fieldDescribe.getType() == Schema.DisplayType.Picklist || fieldDescribe.getType() == Schema.DisplayType.MultiPicklist) {
                    List<Schema.PicklistEntry> picklistEntries = fieldDescribe.getPicklistValues();
                    for (Schema.PicklistEntry entry : picklistEntries) {
                        fieldInfo.picklistValues.add(entry.getLabel());
                    }
                }
                
                else if (fieldDescribe.getType() == Schema.DisplayType.Boolean) {
                    fieldInfo.picklistValues.add('true');
                    fieldInfo.picklistValues.add('false');
                }
                
                else if (fieldDescribe.getType() == Schema.DisplayType.Reference) {
                    List<Schema.SObjectType> referenceToList = fieldDescribe.getReferenceTo();
                    if (!referenceToList.isEmpty()) {
                        fieldInfo.referenceTo = referenceToList[0].getDescribe().getName();
                    }
                }
                
                result.fields.add(fieldInfo);
            }
            
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'PropertySearchController', 'getObjectFields', 'Error while getting object fields.');
        }
        return result;
    }

    @AuraEnabled
    public static List<Map<String, String>> getContactsForInquiries(List<String> inquiryIds) {
        try {
            // Query inquiries with their related contacts
            Map<Id, Inquiry__c> inquiries = new Map<Id, Inquiry__c>([SELECT Id, Name, Contact__c FROM Inquiry__c WHERE Id IN :inquiryIds AND Contact__c != NULL WITH USER_MODE]);

            // Query contacts for the related Contact__c IDs
            Set<Id> contactIds = new Set<Id>();
            for (Inquiry__c inquiry : inquiries.values()) {
                contactIds.add(inquiry.Contact__c);
            }

            Map<Id, Contact> contacts = new Map<Id, Contact>([SELECT Id, Name, Phone FROM Contact WHERE Id IN :contactIds WITH USER_MODE]);

            // Build the result list with inquiry and contact details
            List<Map<String, String>> result = new List<Map<String, String>>();
            for (Inquiry__c inquiry : inquiries.values()) {
                Contact contact = contacts.get(inquiry.Contact__c);
                if (contact != null) {
                    result.add(new Map<String, String>{
                        'InquiryId' => inquiry.Id,
                        'InquiryName' => inquiry.Name,
                        'ContactId' => contact.Id,
                        'ContactName' => contact.Name,
                        'Phone' => contact.Phone
                    });
                }
            }

            return result;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'PropertySearchController', 'getContactsForInquiries', 'Error while getting contacts for inquiries.');
            return new List<Map<String, String>>();
        }
    }
}