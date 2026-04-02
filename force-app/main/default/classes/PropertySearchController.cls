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
        @AuraEnabled
        public Map<String, Map<String, String>> referenceNameMappings; 
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

    @AuraEnabled
    public static String getRecordName(String recordId, String objectApiName) {
        try {
            if (String.isBlank(recordId) || String.isBlank(objectApiName)) return '';
            String query = 'SELECT Name FROM ' + String.escapeSingleQuotes(objectApiName) + ' WHERE Id = :recordId LIMIT 1';
            List<SObject> records = Database.query(query, AccessLevel.USER_MODE);
            if (!records.isEmpty()) {
                return (String) records[0].get('Name');
            }
            return '';
        } catch (Exception e) {
            return '';
        }
    }
    
    /**
     * @description       : This apex class method is used for getting listing and inquiry data
     * @author            : MitrajSinh Gohil
     * @last modified on  : 26-03-2026
     * @last modified by  : Kajal Tiwari
     **/
    @AuraEnabled
    public static WrapperClass getRecords(String recId, String objectName, String filterType) {
        try {
            if (String.isBlank(objectName) && !String.isBlank(recId)) {
                objectName = Id.valueOf(recId).getSObjectType().getDescribe().getName();
            }

            WrapperClass wc = new WrapperClass();
            Set<Id> propertyIds = new Set<Id>();

            String listingFields = getAllFields('MVEX__Listing__c');
            String inquiryFields = getAllFields('MVEX__Inquiry__c');

            List<Listing__c> listings = new List<Listing__c>();
            List<Inquiry__c> inquiries = new List<Inquiry__c>();

            // ---------- COMMON: Fetch current record once ----------
            Listing__c currentListing;
            Inquiry__c currentInquiry;

            if (objectName == 'MVEX__Listing__c') {
                List<Listing__c> temp = Database.query(
                    'SELECT ' + listingFields + ' FROM MVEX__Listing__c WHERE Id = :recId',AccessLevel.USER_MODE);
                if (!temp.isEmpty()) currentListing = temp[0];
            }

            if (objectName == 'MVEX__Inquiry__c') {
                List<Inquiry__c> temp = Database.query(
                    'SELECT ' + inquiryFields + ' FROM MVEX__Inquiry__c WHERE Id = :recId',AccessLevel.USER_MODE);
                if (!temp.isEmpty()) currentInquiry = temp[0];
            }

            // ---------- LINKED ----------
            if (filterType == 'linked') {

                if (objectName == 'MVEX__Listing__c') {

                    inquiries = Database.query(
                        'SELECT ' + inquiryFields + ' FROM MVEX__Inquiry__c WHERE Id IN ' + '(SELECT MVEX__Inquiry__c FROM MVEX__Listing_Inquiry__c WHERE MVEX__Listing__c = :recId)',
                        AccessLevel.USER_MODE);

                    if (currentListing != null) {
                        listings.add(currentListing);
                    }
                }

                else if (objectName == 'MVEX__Inquiry__c') {

                    listings = Database.query(
                        'SELECT ' + listingFields +
                        ' FROM MVEX__Listing__c WHERE Id IN ' + '(SELECT MVEX__Listing__c FROM MVEX__Listing_Inquiry__c WHERE MVEX__Inquiry__c = :recId)',
                        AccessLevel.USER_MODE);

                    if (currentInquiry != null) {
                        inquiries.add(currentInquiry);
                    }
                }
            }

            // ---------- RELATED ----------
            else if (filterType == 'related') {

                if (objectName == 'MVEX__Listing__c') {

                    inquiries = Database.query(
                        'SELECT ' + inquiryFields + ' FROM MVEX__Inquiry__c WHERE MVEX__Listing__c = :recId',
                        AccessLevel.USER_MODE);

                    if (currentListing != null) {
                        listings.add(currentListing);
                    }
                }

                else if (objectName == 'MVEX__Inquiry__c') {

                    Id listingId = currentInquiry != null ? currentInquiry.MVEX__Listing__c : null;

                    if (listingId != null) {
                        listings = Database.query(
                            'SELECT ' + listingFields + ' FROM MVEX__Listing__c WHERE Id = :listingId',
                            AccessLevel.USER_MODE);
                    }

                    if (currentInquiry != null) {
                        inquiries.add(currentInquiry);
                    }
                }
            }

            // ---------- DEFAULT ----------
            else {

                if (objectName == 'MVEX__Listing__c') {

                    listings = Database.query(
                        'SELECT ' + listingFields +
                        ', (SELECT ' + inquiryFields + ' FROM MVEX__Inquirys__r)' + ' FROM MVEX__Listing__c WHERE Id = :recId',
                        AccessLevel.USER_MODE);

                    inquiries = Database.query(
                        'SELECT ' + inquiryFields + ' FROM MVEX__Inquiry__c',AccessLevel.USER_MODE);
                }

                else if (objectName == 'MVEX__Inquiry__c') {

                    if (currentInquiry != null) {
                        inquiries.add(currentInquiry);
                    }

                    listings = Database.query(
                        'SELECT ' + listingFields +
                        ', (SELECT ' + inquiryFields + ' FROM MVEX__Inquirys__r)' + ' FROM MVEX__Listing__c',
                        AccessLevel.USER_MODE);
                }
            }

            // ---------- property ids ----------
            for (Listing__c listing : listings) {
                if (listing.MVEX__Property__c != null) {
                    propertyIds.add(listing.MVEX__Property__c);
                }
            }

            wc.listings = listings;
            wc.inquiries = inquiries;
            
            // ---------- resolve reference field names ----------
            wc.referenceNameMappings = resolveInquiryReferenceNames(inquiries);

            // ---------- media ----------
            if (!propertyIds.isEmpty()) {
                Map<Id, String> mediaMap = new Map<Id, String>();

                for (Property_File__c media : [
                    SELECT Property__c, BaseUrl__c
                    FROM Property_File__c
                    WHERE Property__c IN :propertyIds
                    WITH USER_MODE
                ]) {
                    mediaMap.put(media.Property__c, media.BaseUrl__c);
                }

                wc.medias = mediaMap;
            } else {
                wc.medias = new Map<Id, String>();
            }

            return wc;

        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'PropertySearchController', 'getRecords', e.getStackTraceString());
            return null;
        }
    }
    
    /**
     * @description       : Helper method to resolve all reference field IDs in inquiries to their record names
     * @author            : Kajal Tiwari
     * @last modified on  : 01-04-2026
     * @last modified by  : Kajal Tiwari
     **/
    private static Map<String, Map<String, String>> resolveInquiryReferenceNames(List<Inquiry__c> inquiries) {
        Map<String, Map<String, String>> refMappings = new Map<String, Map<String, String>>();
        
        if (inquiries == null || inquiries.isEmpty()) {
            return refMappings;
        }
        
        try {
            // Get field descriptions for Inquiry__c
            Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.MVEX__Inquiry__c.fields.getMap();
            Map<String, Set<Id>> refIdsByField = new Map<String, Set<Id>>();
            
            // Collect all reference field IDs
            for (Inquiry__c inq : inquiries) {
                for (String fieldName : fieldMap.keySet()) {
                    Schema.DescribeFieldResult fieldDesc = fieldMap.get(fieldName).getDescribe();
                    
                    // Check if field is a reference/lookup field
                    if (fieldDesc.getType() == Schema.DisplayType.REFERENCE) {
                        Object fieldValue = inq.get(fieldName);
                        if (fieldValue != null && fieldValue instanceof Id) {
                            Id refId = (Id)fieldValue;
                            if (!refIdsByField.containsKey(fieldName)) {
                                refIdsByField.put(fieldName, new Set<Id>());
                            }
                            refIdsByField.get(fieldName).add(refId);
                        }
                    }
                }
            }
            
            // For each reference field, resolve IDs to Names
            for (String fieldName : refIdsByField.keySet()) {
                Set<Id> ids = refIdsByField.get(fieldName);
                if (ids.isEmpty()) continue;
                
                Map<String, String> nameMap = new Map<String, String>();
                
                try {
                    // Get the object type for this reference field
                    Schema.DescribeFieldResult fieldDesc = fieldMap.get(fieldName).getDescribe();
                    List<Schema.SObjectType> referenceTo = fieldDesc.getReferenceTo();
                    
                    if (!referenceTo.isEmpty()) {
                        String refObjectName = referenceTo[0].getDescribe().getName();
                        
                        // Query for names using dynamic SOQL
                        String soql = 'SELECT Id, Name FROM ' + refObjectName + ' WHERE Id IN :ids WITH USER_MODE';
                        for (SObject record : Database.query(soql)) {
                            nameMap.put((String)record.Id, (String)record.get('Name'));
                        }
                    }
                } catch (Exception e) {
                    // Log but continue processing other fields
                    ErrorHandler.insertErrorData(e, 'PropertySearchController', 'resolveInquiryReferenceNames', 'Error resolving reference field: ' + fieldName);
                }
                
                if (!nameMap.isEmpty()) {
                    refMappings.put(fieldName, nameMap);
                }
            }
            
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'PropertySearchController', 'resolveInquiryReferenceNames', e.getStackTraceString());
        }
        
        return refMappings;
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
                if (inquiry.containsKey('mvex__contact__c') && inquiry.get('mvex__contact__c') != null) {
                    contactIds.add((Id) inquiry.get('mvex__contact__c'));
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

    /**
     * @description       : This method checks if Business Account ID is configured in custom metadata
     * @last modified on  : 03-02-2026
     **/
    @AuraEnabled
    public static Boolean hasBusinessAccountId() {
        try {
            List<MVEX__WBConnect_Configuration__mdt> configs = [
                SELECT Id, MVEX__Business_Account_Id__c 
                FROM MVEX__WBConnect_Configuration__mdt 
                WHERE MVEX__Business_Account_Id__c != NULL 
                LIMIT 1
            ];
            return !configs.isEmpty() && String.isNotBlank(configs[0].MVEX__Business_Account_Id__c);
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'PropertySearchController', 'hasBusinessAccountId', 'Error while checking business account ID.');
            return false;
        }
    }

}