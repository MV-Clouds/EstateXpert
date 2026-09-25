/**
* Class Name : SendEmailsController
* Test Class : SendEmailsControllerTest
* Created By : Karan Singh
* Last Modified Date : 17/09/2026
* Last Modified By : Karan Singh
* @description : Controller for handling email templates, messaging service options, listings, and contacts for SendEmails component.
*/
public with sharing class SendEmailsController {

    /**
    * Method Name : getMessagingServiceOptions
    * @return List<Map<String, String>> List of available messaging service options with label and value.
    * @description : Retrieves available messaging service options such as Single Messaging Service and Gmail if configured.
    */
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
    
    /**
    * Method Name : getTemplatesByObject
    * @return Map<String, Object> Map containing email templates and EstateXpert custom marketing templates.
    * @description : Fetches active standard EmailTemplate records and custom MVEX__Template__c records with body data and merge fields.
    */
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

    /**
    * Method Name : getListings
    * @return List<MVEX__Listing__c> List of listing records with address, type, price, and status.
    * @description : Retrieves listing records for template merge preview and campaign selection.
    */
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

    /**
    * Method Name : getAllContacts
    * @return List<Contact> List of contact records that have an email address.
    * @description : Retrieves all active contacts with email addresses ordered by Name.
    */
    @AuraEnabled
    public static List<Contact> getAllContacts() {
        List<Contact> contacts = new List<Contact>();
        try {
            contacts = [SELECT Id, Name, Email, Phone FROM Contact WHERE Email != null WITH USER_MODE ORDER BY Name ASC LIMIT 50000];
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'SendEmailsController', 'getAllContacts', e.getStackTraceString());
        }
        return contacts;
    }


    /**
    * Method Name : sendEmails
    * @param templateId The ID of the selected Template__c or EmailTemplate.
    * @param relatedObject The related object API name (e.g., 'Contact' or 'MVEX__Listing__c').
    * @param messagingService The service to send through ('single' or 'gmail').
    * @param listingId Optional listing ID when sending a listing-based template.
    * @param primaryContactIds List of Contact record IDs selected as primary recipients.
    * @param broadcastGroupIds List of Broadcast Group record IDs selected.
    * @param ccContactIds List of Contact record IDs selected as CC recipients.
    * @description : Directly sends emails to selected contacts and broadcast group members with merge fields and listing media replacements without creating campaign tracking records.
    */
    @AuraEnabled
    public static Map<String, String> sendEmails(String templateId, String relatedObject, String messagingService, String listingId, List<String> primaryContactIds, List<String> broadcastGroupIds, List<String> ccContactIds) {
        Map<String, String> result = new Map<String, String>();
        try {
            if (String.isBlank(templateId)) {
                result.put('status', 'error');
                result.put('message', 'Please select an email template.');
                return result;
            }

            Set<Id> allPrimaryContactIds = new Set<Id>();
            if (primaryContactIds != null) {
                for (String cid : primaryContactIds) {
                    if (isValidId(cid)) {
                        allPrimaryContactIds.add((Id)cid);
                    }
                }
            }

            // Extract recipients from broadcast groups if selected
            if (broadcastGroupIds != null && !broadcastGroupIds.isEmpty()) {
                List<MVEX__Broadcast_Group_Member__c> groupMembers = [SELECT MVEX__Member_Record_Id__c FROM MVEX__Broadcast_Group_Member__c WHERE MVEX__Broadcast_Group_ID__c IN :broadcastGroupIds 
                                                                        AND MVEX__Member_Record_Id__c != null WITH USER_MODE];
                for (MVEX__Broadcast_Group_Member__c member : groupMembers) {
                    if (isValidId(member.MVEX__Member_Record_Id__c)) {
                        allPrimaryContactIds.add((Id)member.MVEX__Member_Record_Id__c);
                    }
                }
            }

            if (allPrimaryContactIds.isEmpty()) {
                result.put('status', 'error');
                result.put('message', 'Please select at least one contact or broadcast group.');
                return result;
            }

            // CC emails
            List<String> ccEmailList = new List<String>();
            Set<Id> allCcContactIds = new Set<Id>();
            if (ccContactIds != null) {
                for (String ccId : ccContactIds) {
                    if (isValidId(ccId)) {
                        allCcContactIds.add((Id)ccId);
                    }
                }
            }
            if (!allCcContactIds.isEmpty()) {
                for (Contact ccContact : [SELECT Id, Email FROM Contact WHERE Id IN :allCcContactIds AND Email != null WITH USER_MODE]) {
                    ccEmailList.add(ccContact.Email);
                }
            }

            // Query Primary Contacts with all accessible fields
            List<String> fieldNames = getAllFieldNames('Contact');
            String contactQuery = 'SELECT ' + String.join(fieldNames, ', ') + ' FROM Contact WHERE Id IN :allPrimaryContactIds AND Email != null';
            List<Contact> primaryContacts = Database.query(String.escapeSingleQuotes(contactQuery), AccessLevel.USER_MODE);

            if (primaryContacts.isEmpty()) {
                result.put('status', 'error');
                result.put('message', 'None of the selected contacts have a valid email address.');
                return result;
            }

            // Retrieve Template Data
            String templateSubject = '';
            String rawBody = '';
            Map<String, Object> extractedKeyMap = new Map<String, Object>();
            Boolean isCustomTemplate = false;

            List<MVEX__Template__c> temps = [SELECT Id, Name, MVEX__Object_API_Name__c, MVEX__Template_Name__c, MVEX__Template_pattern__c, MVEX__Template_Status__c, MVEX__Description__c, MVEX__Subject__c,
                                                (SELECT Id, Name, MVEX__Template_Value_Simple__c, MVEX__Value_Type__c FROM MVEX__Template_Data__r 
                                                WHERE MVEX__Value_Type__c IN ('Extracted Mapping Keys', 'Body Value') ORDER BY MVEX__Order_No_Simple__c ASC)
                                                FROM MVEX__Template__c WHERE Id = :templateId WITH USER_MODE];

            if (!temps.isEmpty()) {
                isCustomTemplate = true;
                templateSubject = temps[0].MVEX__Subject__c;
                if (String.isBlank(relatedObject)) {
                    relatedObject = temps[0].MVEX__Object_API_Name__c;
                }

                String extractedKeyString = '';
                for (MVEX__Template_Data__c fieldData : temps[0].MVEX__Template_Data__r) {
                    if (fieldData.MVEX__Value_Type__c == 'Body Value' && fieldData.MVEX__Template_Value_Simple__c != null) {
                        rawBody += fieldData.MVEX__Template_Value_Simple__c;
                    } else if (fieldData.MVEX__Value_Type__c == 'Extracted Mapping Keys' && fieldData.MVEX__Template_Value_Simple__c != null) {
                        extractedKeyString += fieldData.MVEX__Template_Value_Simple__c;
                    }
                }

                if (String.isNotBlank(extractedKeyString) && extractedKeyString != 'null') {
                    extractedKeyMap = (Map<String, Object>) JSON.deserializeUntyped(extractedKeyString);
                }
            } else {
                List<EmailTemplate> standardTemplates = [
                    SELECT Id, Name, Subject, HtmlValue, Body 
                    FROM EmailTemplate 
                    WHERE Id = :templateId WITH USER_MODE
                ];
                if (!standardTemplates.isEmpty()) {
                    templateSubject = standardTemplates[0].Subject;
                    rawBody = standardTemplates[0].HtmlValue != null ? standardTemplates[0].HtmlValue : standardTemplates[0].Body;
                } else {
                    result.put('status', 'error');
                    result.put('message', 'Selected template could not be found.');
                    return result;
                }
            }

            Boolean isListingTemplate = String.isNotBlank(relatedObject) && (relatedObject.equalsIgnoreCase('MVEX__Listing__c') || relatedObject.equalsIgnoreCase('Listing__c'));

            // Process Listing Mapping and Images if listingId provided
            if (isListingTemplate && isValidId(listingId)) {
                // 1. Replace Listing fields in rawBody
                if (!extractedKeyMap.isEmpty()) {
                    Map<String, Map<String, String>> listingMappingKeys = DataMappingControllerV2.getMappingsKeyValues2(extractedKeyMap, 'MVEX__Listing__c', new Set<Id>{(Id)listingId}, true);
                    if (listingMappingKeys != null) {
                        Map<String, String> mappingKeyVsValues = listingMappingKeys.get('objectNGeneral');
                        Map<String, String> salesforceImages = listingMappingKeys.get('salesforceImages');
                        if (mappingKeyVsValues != null) {
                            for (String key : mappingKeyVsValues.keySet()) {
                                rawBody = rawBody.replaceAll(Pattern.quote(key), mappingKeyVsValues.get(key) != null ? mappingKeyVsValues.get(key) : '');
                            }
                        }
                        if (salesforceImages != null) {
                            for (String src : salesforceImages.keySet()) {
                                rawBody = rawBody.replaceAll(Pattern.quote(src), salesforceImages.get(src) != null ? salesforceImages.get(src) : '');
                            }
                        }
                    }
                }

                // 2. Replace Listing Media Images (listingMedia[n])
                List<MVEX__Listing__c> listings = [SELECT Id, MVEX__Property__c FROM MVEX__Listing__c WHERE Id = :listingId WITH USER_MODE LIMIT 1];
                if (!listings.isEmpty() && listings[0].MVEX__Property__c != null) {
                    Id propertyId = listings[0].MVEX__Property__c;
                    List<MVEX__Property_File__c> files = [SELECT Id, MVEX__BaseUrl__c FROM MVEX__Property_File__c WHERE MVEX__Property__c = :propertyId 
                                                            AND MVEX__IsOnExpose__c = true AND MVEX__Size__c != null WITH USER_MODE 
                                                            ORDER BY MVEX__Sort_on_Expose__c ASC NULLS LAST, Name ASC LIMIT 50000];
                    Map<String, String> listingImageMap = new Map<String, String>();
                    for (Integer i = 0; i < files.size(); i++) {
                        listingImageMap.put('listingMedia[' + (i + 1) + ']', files[i].MVEX__BaseUrl__c);
                    }

                    if (!listingImageMap.isEmpty()) {
                        String imgTagRegex = '<img[^>]*data-name="(listingMedia\\[\\d+\\])"[^>]*src="[^"]+"[^>]*>';
                        Matcher matcher = Pattern.compile(imgTagRegex).matcher(rawBody);
                        while (matcher.find()) {
                            String fullMatch = matcher.group(0);
                            Matcher keyMatcher = Pattern.compile('data-name="(listingMedia\\[\\d+\\])"').matcher(fullMatch);
                            if (keyMatcher.find()) {
                                String mediaKey = keyMatcher.group(1);
                                if (listingImageMap.containsKey(mediaKey) && listingImageMap.get(mediaKey) != null) {
                                    String updatedTag = fullMatch.replaceFirst('src="[^"]+"', 'src="' + listingImageMap.get(mediaKey) + '"');
                                    rawBody = rawBody.replace(fullMatch, updatedTag);
                                }
                            }
                        }
                    }
                }
            }

            // Recipient field keys for listing template
            Set<String> recipientFieldKeys = (isListingTemplate && !extractedKeyMap.isEmpty()) ? DataMappingControllerV2.collectRecipientFieldKeys(extractedKeyMap) : new Set<String>();

            // Build individual emails
            List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();
            List<GmailIntegrationControllerV1.EmailWrapper> gmailsToSend = new List<GmailIntegrationControllerV1.EmailWrapper>();
            Map<String, Map<String, String>> contactEmailInfoMap = new Map<String, Map<String, String>>();

            for (Contact recipientContact : primaryContacts) {
                String personalizedBody = rawBody;

                if (isListingTemplate) {
                    if (!recipientFieldKeys.isEmpty()) {
                        Map<String, String> recipientReplacements = DataMappingControllerV2.getRecipientFieldReplacements(recipientFieldKeys, recipientContact);
                        for (String rKey : recipientReplacements.keySet()) {
                            personalizedBody = personalizedBody.replaceAll(Pattern.quote(rKey), recipientReplacements.get(rKey) != null ? recipientReplacements.get(rKey) : '');
                        }
                    }
                } else if (isCustomTemplate && !extractedKeyMap.isEmpty()) {
                    // Contact template or Generic: map contact-specific fields
                    Map<String, Map<String, String>> contactMappingKeys = DataMappingControllerV2.getMappingsKeyValues2(extractedKeyMap, 'Contact', new Set<Id>{recipientContact.Id}, true);
                    if (contactMappingKeys != null) {
                        Map<String, String> mappingKeyVsValues = contactMappingKeys.get('objectNGeneral');
                        Map<String, String> salesforceImages = contactMappingKeys.get('salesforceImages');
                        if (mappingKeyVsValues != null) {
                            for (String key : mappingKeyVsValues.keySet()) {
                                personalizedBody = personalizedBody.replaceAll(Pattern.quote(key), mappingKeyVsValues.get(key) != null ? mappingKeyVsValues.get(key) : '');
                            }
                        }
                        if (salesforceImages != null) {
                            for (String src : salesforceImages.keySet()) {
                                personalizedBody = personalizedBody.replaceAll(Pattern.quote(src), salesforceImages.get(src) != null ? salesforceImages.get(src) : '');
                            }
                        }
                    }
                }

                String finalSubject = String.isNotBlank(templateSubject) ? templateSubject : 'Email from EstateXpert';

                if (messagingService == 'gmail') {
                    GmailIntegrationControllerV1.EmailWrapper singleGmail = new GmailIntegrationControllerV1.EmailWrapper();
                    singleGmail.toAddresses = new List<String>{recipientContact.Email};
                    if (!ccEmailList.isEmpty()) {
                        singleGmail.ccAddresses = ccEmailList;
                    }
                    singleGmail.subject = finalSubject;
                    singleGmail.body = personalizedBody;
                    singleGmail.contactEmailInfoMap = new Map<String, Map<String, String>>();
                    singleGmail.contactEmailInfoMap.put(recipientContact.Id, new Map<String, String>{
                        'subject' => finalSubject,
                        'body' => personalizedBody,
                        'email' => recipientContact.Email,
                        'cc' => String.join(ccEmailList, '@@@'),
                        'bcc' => ''
                    });
                    gmailsToSend.add(singleGmail);
                } else {
                    Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                    email.setToAddresses(new List<String>{recipientContact.Email});
                    if (!ccEmailList.isEmpty()) {
                        email.setCcAddresses(ccEmailList);
                    }
                    email.setSubject(finalSubject);
                    email.setHtmlBody(personalizedBody);
                    emailsToSend.add(email);

                    contactEmailInfoMap.put(recipientContact.Id, new Map<String, String>{
                        'subject' => finalSubject,
                        'body' => personalizedBody,
                        'email' => recipientContact.Email,
                        'cc' => String.join(ccEmailList, '@@@'),
                        'bcc' => ''
                    });
                }
            }

            if (!emailsToSend.isEmpty()) {
                Messaging.sendEmail(emailsToSend);
                try {
                    CreateActivityRecordsFromMail.createCaseEmailMessage(contactEmailInfoMap);
                } catch (Exception ex) {
                    ErrorHandler.insertErrorData(ex, 'SendEmailsController', 'sendEmails', 'Error creating activity records: ' + ex.getMessage());
                }
            } else if (!gmailsToSend.isEmpty()) {
                GmailIntegrationControllerV1.requestNewAccessToken(gmailsToSend, null, null, false);
            }

            result.put('status', 'success');
            result.put('message', 'Emails sent successfully!');
            return result;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'SendEmailsController', 'sendEmails', e.getMessage() + ' - ' + e.getStackTraceString());
            result.put('status', 'error');
            result.put('message', e.getMessage());
            return result;
        }
    }

    /**
    * Method Name : isValidId
    * @param idStr String representation of Salesforce Id.
    * @return Boolean True if valid 15 or 18 character Id.
    * @description : Validates if a string is a valid Salesforce record Id.
    */
    private static Boolean isValidId(String idStr) {
        if (String.isBlank(idStr)) return false;
        if (idStr.equalsIgnoreCase('null') || idStr.equalsIgnoreCase('undefined')) return false;
        return (idStr.length() == 15 || idStr.length() == 18) && Pattern.matches('^[a-zA-Z0-9]{15,18}$', idStr);
    }

    /**
    * Method Name : getAllFieldNames
    * @param objectName SObject API name.
    * @return List<String> List of accessible field names for the SObject.
    * @description : Retrieves all accessible field names for an object dynamically.
    */
    private static List<String> getAllFieldNames(String objectName) {
        try {
            List<String> fieldNames = new List<String>();
            Schema.SObjectType sObjectType = Schema.getGlobalDescribe().get(objectName);
            if (sObjectType != null && sObjectType.getDescribe().isAccessible()) {
                Map<String, Schema.SObjectField> fields = sObjectType.getDescribe().fields.getMap();
                for (Schema.SObjectField field : fields.values()) {
                    Schema.DescribeFieldResult dr = field.getDescribe();
                    if (dr.isAccessible()) {
                        fieldNames.add(dr.getName());
                    }
                }
                fieldNames.sort();
            }
            if (fieldNames.isEmpty()) {
                fieldNames.addAll(new List<String>{'Id', 'Email', 'Name', 'FirstName', 'LastName'});
            }
            return fieldNames;
        } catch (Exception e) {
            return new List<String>{'Id', 'Email', 'Name', 'FirstName', 'LastName'};
        }
    }
}