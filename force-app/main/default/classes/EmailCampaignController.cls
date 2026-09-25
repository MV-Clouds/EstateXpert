/**
 * Class Name : EmailCampaignController
 * Date : 23/07/2024
 * Created By : Rachit Shah
 * @description : Used for scheduling emails
 */

public with sharing class EmailCampaignController {
    /**
     * Method Name : getContacts
     * Date : 23/07/2024
     * Created By : Rachit Shah
     * @description : Get all contact data for all the fields
     */
    public static List<Contact> getContacts(Set<Id> contactIds) {
        try {
            List<String> fieldNames = getAllFieldNames('Contact');
            
            String query = 'SELECT ' + String.join(fieldNames, ', ') + ' FROM Contact WHERE Id IN : contactIds AND Email != null';
            
            List<Contact> contactRecords = Database.query(String.escapeSingleQuotes(query), AccessLevel.USER_MODE);
            
            return contactRecords;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'EmailCampaignController', 'getContacts', 'Error while getting Contacts');
            return null;
            
        }
    }
    
    public class TemplateDataForEmail {
        @AuraEnabled public List<TemplateWrapper> marketingTemplates;
        @AuraEnabled public List<TemplateWrapper> listingTemplates;
        @AuraEnabled public List<EmailTemplate> emailTemplates;
    }
    
    public class TemplateWrapper {
        @AuraEnabled public String templateId;
        @AuraEnabled public String templateName;
        @AuraEnabled public String subject;
        @AuraEnabled public String body;
        @AuraEnabled public String objectApiName;
    }
    
    @AuraEnabled
    public static TemplateDataForEmail getQuickTemplates() {
        try {

            List<EmailTemplate> emailTemplate = [SELECT Id, Name, Subject, HtmlValue, RelatedEntityType FROM EmailTemplate WHERE IsActive = true WITH USER_MODE ORDER BY Name ASC];

            TemplateDataForEmail templateWrappers = new TemplateDataForEmail();
            templateWrappers.marketingTemplates = new List<TemplateWrapper>();
            templateWrappers.listingTemplates = new List<TemplateWrapper>();
            templateWrappers.emailTemplates = emailTemplate;
            
            List<MVEX__Template__c> templates = [SELECT Id, MVEX__Template_Name__c, MVEX__Subject__c, MVEX__Object_API_Name__c ,
                                        (SELECT MVEX__Template_Value_Simple__c, MVEX__Value_Type__c FROM MVEX__Template_Data__r WHERE MVEX__Value_Type__c = 'Body Value' ORDER BY MVEX__Order_No_Simple__c ASC)
                                        FROM MVEX__Template__c WHERE MVEX__Template_pattern__c = 'Marketing Template' AND MVEX__Template_Status__c = true WITH USER_MODE];
            for (MVEX__Template__c template : templates) {
                String templateBody = '';
                
                for (MVEX__Template_Data__c fieldData : template.MVEX__Template_Data__r) {
                    String value = fieldData.MVEX__Template_Value_Simple__c != null ? fieldData.MVEX__Template_Value_Simple__c : '';
                    if (fieldData.MVEX__Value_Type__c == 'Body Value') {
                        templateBody += value;
                    }
                }
                
                TemplateWrapper wrapper = new TemplateWrapper();
                wrapper.templateId = template.Id;
                wrapper.templateName = template.MVEX__Template_Name__c;
                wrapper.subject = template.MVEX__Subject__c;
                wrapper.body = templateBody;
                wrapper.objectApiName = template.MVEX__Object_API_Name__c;
                
                templateWrappers.marketingTemplates.add(wrapper);
            }
            
            List<MVEX__Template__c> templatedatas = [SELECT Id, MVEX__Template_Name__c FROM MVEX__Template__c WHERE MVEX__Object_API_Name__c = 'MVEX__Listing__c' AND MVEX__Template_Status__c = true WITH USER_MODE ORDER BY MVEX__Template_Name__c ASC];
            
            for (MVEX__Template__c template : templatedatas) {
                TemplateWrapper wrapper = new TemplateWrapper();
                wrapper.templateId = template.Id;
                wrapper.templateName = template.MVEX__Template_Name__c;
                
                templateWrappers.listingTemplates.add(wrapper);
            }
            
            return templateWrappers;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'EmailCampaignController', 'getQuickTemplates', 'Error while retriving data in apex.');
            return null;
        }
    }
    
    /**
     * Method Name : getMessagingServiceOptions
     * Date : 13/08/2024
     * Created By : Rachit Shah
     * @description : Return email options based on the intigration in the salesfroce org
     */
    @AuraEnabled
    public static List<Map<String, String>> getMessagingServiceOptions() {
        
        try {
            Map<String, String> optionsMap = new Map<String, String>();
            
            optionsMap.put('Single Messaging Service', 'single');
            
            // Retrieve custom setting: MVEX__GmailConfig__c
            MVEX__GmailConfig__c gmailConfig = MVEX__GmailConfig__c.getOrgDefaults();
            if (gmailConfig != null && !String.isBlank(gmailConfig.MVEX__Refresh_Token__c)) {
                optionsMap.put('Gmail', 'gmail');
            }
            
            // Convert map to list of options
            List<Map<String, String>> optionsList = new List<Map<String, String>>();
            for (String key : optionsMap.keySet()) {
                optionsList.add(new Map<String, String>{'label' => key, 'value' => optionsMap.get(key)});
            }
            
            return optionsList;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'EmailCampaignController', 'getMessagingServiceOptions', e.getStackTraceString());
            return null;
            
        }
    }
    
    /**
     * Method Name : createCampaignAndEmails
     * Date : 23/07/2024
     * Created By : Rachit Shah
     * @description : Used for creating email camapign and emails record
     */
    // In EmailCampaignController (around line 720)
    @AuraEnabled
    public static String createCampaignAndEmails(String jsonCampaignEmailData , Boolean isImmediateSend) {
        try {
            Map<String, Object> campaignEmailDataMap = (Map<String, Object>) JSON.deserializeUntyped(jsonCampaignEmailData);
            
            // Extract campaign details
            String campaignName = (String) campaignEmailDataMap.get('campaignName');
            String templateId = (String) campaignEmailDataMap.get('templateId');
            Boolean saveForFuture = (Boolean) campaignEmailDataMap.get('saveForFuture');
            String emailType = (String) campaignEmailDataMap.get('messagingService');
            String selectedContactDateField = (String) campaignEmailDataMap.get('selectedContactDateField');
            String relatedObject = (String) campaignEmailDataMap.get('relatedObject');
            
            // --- RECIPIENT COLLECTION START ---
            
            // 1. Extract individual recipients first - convert to Set for uniqueness
            Set<String> selectedPrimaryRecipientsSet = new Set<String>();
            if (campaignEmailDataMap.containsKey('selectedPrimaryRecipients')) {
                for (Object recipient : (List<Object>) campaignEmailDataMap.get('selectedPrimaryRecipients')) {
                    selectedPrimaryRecipientsSet.add(String.valueOf(recipient));
                }
            }

            // Extract broadcast groups (IDs) from JSON payload
            List<String> selectedBroadcastGroups = new List<String>();
            if (campaignEmailDataMap.containsKey('selectedBroadcastGroups') && campaignEmailDataMap.get('selectedBroadcastGroups') != null) {
                for (Object groupId : (List<Object>) campaignEmailDataMap.get('selectedBroadcastGroups')) {
                    selectedBroadcastGroups.add(String.valueOf(groupId));
                }
            }

            // 2. Query recipients from broadcast groups if any selected and add to the same set
            if (!selectedBroadcastGroups.isEmpty()) {
                Set<String> broadcastRecipientIds = new Set<String>();
                
                // Determine the correct recipient field to query based on relatedObject
                String recipientIdField = 'MVEX__Member_Record_Id__c';
                
                // Build dynamic SOQL query string
                String query = 'SELECT ' + recipientIdField + 
                            ' FROM MVEX__Broadcast_Group_Member__c' +
                            ' WHERE MVEX__Broadcast_Group_ID__c IN :selectedBroadcastGroups' +
                            ' AND ' + recipientIdField + ' != NULL' ;
                            
                // Execute dynamic query
                List<SObject> groupMembers = Database.query(String.escapeSingleQuotes(query));
                
                for (SObject member : groupMembers) {
                    String recipientId = (String)member.get(recipientIdField);
                    if (recipientId != null) {
                        broadcastRecipientIds.add(recipientId);
                    }
                }

                // 3. Add broadcast group recipients to selected primary recipients set (Set naturally handles duplicates)
                selectedPrimaryRecipientsSet.addAll(broadcastRecipientIds);
            }
            
            // Convert Set back to List for further processing
            List<String> selectedPrimaryRecipients = new List<String>(selectedPrimaryRecipientsSet);
            
            // --- RECIPIENT COLLECTION END ---
            
            // Extract CC recipients
            Set<String> selectedCCRecipients = new Set<String>();
            if (campaignEmailDataMap.containsKey('selectedCCRecipients')) {
                for (Object recipient : (List<Object>) campaignEmailDataMap.get('selectedCCRecipients')) {
                    selectedCCRecipients.add(String.valueOf(recipient));
                }
            }
            // Extract BCC recipients.  
            Set<String> selectedBCCRecipients = new Set<String>();
            if (campaignEmailDataMap.containsKey('selectedBCCRecipients')) {
                for (Object recipient : (List<Object>) campaignEmailDataMap.get('selectedBCCRecipients')) {
                    selectedBCCRecipients.add(String.valueOf(recipient));
                }
            }
            String ccRecipients = String.join(new List<String>(selectedCCRecipients), '@@@');
            String bccRecipients = String.join(new List<String>(selectedBCCRecipients), '@@@');

            // Determine start date
            Date specificDate = null;
            if (campaignEmailDataMap.containsKey('specificDate') && String.valueOf(campaignEmailDataMap.get('specificDate')) != '') {
                specificDate = Date.valueOf((String) campaignEmailDataMap.get('specificDate'));
            }
            
            List<Object> emails = (List<Object>) campaignEmailDataMap.get('emails');
            
            // Check accessibility of selectedContactDateField
            Map<String, SObjectField> contactFields = Contact.SObjectType.getDescribe().fields.getMap();
            Boolean isDateFieldAccessible = String.isBlank(selectedContactDateField) || 
                (contactFields.containsKey(selectedContactDateField) && contactFields.get(selectedContactDateField).getDescribe().isAccessible());

            // Query contacts to validate emails and date fields
            String queryForFailedEmails = 'SELECT Id, Email';
            if (!String.isEmpty(selectedContactDateField) && isDateFieldAccessible) {
                queryForFailedEmails += ', ' + selectedContactDateField;
            }
            String objectName = 'Contact';
            queryForFailedEmails += ' FROM ' + objectName + ' WHERE Id IN :selectedPrimaryRecipients';
            
            List<SObject> contlst = Database.query(String.escapeSingleQuotes(queryForFailedEmails), AccessLevel.USER_MODE);
            
            // Track valid contacts and dates
            Map<Id, String> conMap = new Map<Id, String>();
            Map<Id, Date> contactIdToDateMap = new Map<Id, Date>();
            Integer failedEmails = 0;
            Integer marketingEmailCount = emails != null ? emails.size() : 0;
            
            for (SObject con1 : contlst) {
                SObject con;  // Declare outside if-else
                
                if(con1 instanceof Contact) {
                    con = (Contact) con1;
                }
                
                // Now you can safely use con.Email and con.Id
                String email = (String) con.get('Email');
                Id conId = (Id) con.get('Id');
                
                if (email == null) {
                    failedEmails += marketingEmailCount;
                    continue;
                }
                
                if (!Pattern.matches('^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$', email)) {
                    failedEmails += marketingEmailCount;
                    continue;
                }
                
                if (!String.isEmpty(selectedContactDateField)) {
                    if (!isDateFieldAccessible) {
                        failedEmails += marketingEmailCount;
                        conMap.put(conId, email);
                        continue;
                    }
                    Object fieldValObj = con.get(selectedContactDateField);
                    if (fieldValObj == null) {
                        failedEmails += marketingEmailCount;
                        conMap.put(conId, email);
                        continue;
                    }
                    Date fieldValue = (Date) fieldValObj;
                    Date adjustedDate = fieldValue;
                    if (selectedContactDateField == 'Birthdate') {
                        Integer currentYear = System.today().year();
                        adjustedDate = Date.newInstance(currentYear, fieldValue.month(), fieldValue.day());
                        if (adjustedDate < System.today()) {
                            adjustedDate = adjustedDate.addYears(1);
                        }
                    } else if (selectedContactDateField == 'MVEX__Next_Available_Date__c' && fieldValue <= System.today()) {
                        failedEmails += marketingEmailCount;
                        conMap.put(conId, email);
                        continue;
                    }
                    contactIdToDateMap.put(conId, adjustedDate);
                    conMap.put(conId, email);
                } else {
                    conMap.put(conId, email);
                    contactIdToDateMap.put(conId, specificDate);
                }
            }
            
            // Create campaign - store both individual and broadcast group info
            MVEX__Marketing_Campaign__c campaign = new MVEX__Marketing_Campaign__c(
                MVEX__Label__c = campaignName,
                MVEX__Is_Marketing_Campaign_Template__c = saveForFuture,
                MVEX__Primary_Recipient__c = String.join(selectedPrimaryRecipients, '@@@'),
                MVEX__BCC_Contacts__c = bccRecipients,
                MVEX__CC_Contacts__c = ccRecipients,
                MVEX__Total_Emails__c = 0,
                MVEX__Email_Type__c = emailType,
                MVEX__Failed_Emails__c = failedEmails,
                MVEX__Status__c = isImmediateSend ? 'In Progress' : 'Pending', // Set status based on immediate send
                MVEX__Schedule_Type__c = specificDate != null ? 'Specific Date' : 'Contact Field',
                MVEX__RelatedObject__c = relatedObject,
                // ✨ ADDED: Store selected broadcast group IDs
                MVEX__Selected_Broadcast_Groups__c = !selectedBroadcastGroups.isEmpty() ? String.join(selectedBroadcastGroups, '@@@') : null
            );
            
            if (specificDate != null) {
                campaign.MVEX__Start_Date__c = specificDate;
                campaign.MVEX__Campaign_Start_Date__c = specificDate;
            } else if (!String.isEmpty(selectedContactDateField)) {
                campaign.MVEX__SelectedContactDateField__c = selectedContactDateField;
                campaign.MVEX__Campaign_Start_Date__c = null;
            }
            if (!String.isEmpty(templateId)) {
                campaign.MVEX__Marketing_Campaign_Template__c = templateId;
            }
            
            insert as user campaign;
        
            // Create campaign members for all unique recipients
            List<MVEX__Marketing_Campaign_Member__c> marketingCampaignMembers = new List<MVEX__Marketing_Campaign_Member__c>();
            for (String contactId : selectedPrimaryRecipients) {
                marketingCampaignMembers.add(new MVEX__Marketing_Campaign_Member__c(
                    MVEX__Marketing_Campaign__c = campaign.Id,
                    MVEX__RecipientId__c = contactId,
                    MVEX__Contact_Type__c = 'Primary'
                ));
            }
            
            insert as user marketingCampaignMembers;
            
            // Group MVEX__Marketing_Email__c by schedule to avoid duplicates for Specific Date
            Map<String, MVEX__Marketing_Email__c> scheduleToEmailMap = new Map<String, MVEX__Marketing_Email__c>();
            List<MVEX__Marketing_Email__c> emailRecordsToInsert = new List<MVEX__Marketing_Email__c>();
            Integer lastDays = -1;
            String lastTimeString = null;
            for (Object emailDataObj : emails) {
                Map<String, Object> emailData = (Map<String, Object>) emailDataObj;
                String subject = String.valueOf(emailData.get('subject'));
                String name = String.valueOf(emailData.get('name'));
                String template = String.valueOf(emailData.get('template'));
                String templateType = String.valueOf(emailData.get('templateType'));
                Integer daysAfterStartDate = Integer.valueOf(emailData.get('daysAfterStartDate'));
                if (daysAfterStartDate != null && (daysAfterStartDate < 0 || daysAfterStartDate > 365)) {
                    throw new AuraHandledException('Days after start date cannot exceed 365 days (1 year).');
                }
                if (daysAfterStartDate != null && daysAfterStartDate < lastDays) {
                    throw new AuraHandledException('Drip campaign emails must be scheduled in increasing chronological order.');
                }
                String timeString = (String) emailData.get('timeToSend');
                if (daysAfterStartDate != null && daysAfterStartDate == lastDays && lastTimeString != null && timeString != null) {
                    if (timeString <= lastTimeString) {
                        throw new AuraHandledException('Emails scheduled on the same day must have progressive send times.');
                    }
                }
                if (daysAfterStartDate != null) {
                    lastDays = daysAfterStartDate;
                    lastTimeString = timeString;
                }
                String selectedListingId = (String) emailData.get('selectedListingId');
                
                String scheduleKey = daysAfterStartDate + '-' + timeString;
                if (specificDate != null && scheduleToEmailMap.containsKey(scheduleKey)) {
                    continue; // Skip duplicate schedules
                }
                
                MVEX__Marketing_Email__c emailCampaign = new MVEX__Marketing_Email__c(MVEX__Marketing_Campaign__c = campaign.Id);
                emailCampaign.MVEX__Subject__c = subject;
                emailCampaign.Name = name;
                emailCampaign.MVEX__Template_Id__c = template;
                emailCampaign.MVEX__Template_Type__c = templateType;
                emailCampaign.MVEX__Days_After_Start_Date__c = daysAfterStartDate;
                if (selectedListingId != null && selectedListingId != '' && (selectedListingId.length() == 15 || selectedListingId.length() == 18)) {
                    emailCampaign.MVEX__Listing__c = selectedListingId;
                } else {
                    emailCampaign.MVEX__Listing__c = null;
                }
                
                if (!String.isEmpty(timeString)) {
                    Time sendTime = Time.newInstance(
                        Integer.valueOf(timeString.split(':')[0]), 
                        Integer.valueOf(timeString.split(':')[1]), 
                        timeString.split(':').size() > 2 ? Integer.valueOf(timeString.split(':')[2]) : 0, 
                        0
                    );
                    emailCampaign.MVEX__TimeToSend__c = sendTime;
                    
                    // For immediate send, set the send date time to current time
                    if (isImmediateSend && daysAfterStartDate == 0) {
                        DateTime now = DateTime.now();
                        emailCampaign.MVEX__Send_Date_Time__c = now;
                    } else if (specificDate != null) {
                        DateTime sendDateTime = DateTime.newInstanceGmt(specificDate.addDays(daysAfterStartDate), sendTime);
                        emailCampaign.MVEX__Send_Date_Time__c = sendDateTime;
                    }
                }
                emailRecordsToInsert.add(emailCampaign);
                if (specificDate != null) {
                    scheduleToEmailMap.put(scheduleKey, emailCampaign);
                }
            }
            insert as user emailRecordsToInsert;
            
            // Create MVEX__Email_Member__c records with distinct schedules based on MVEX__Schedule_Type__c
            List<MVEX__Email_Member__c> emailMembersToInsert = new List<MVEX__Email_Member__c>();
            Set<String> emailMemberKeys = new Set<String>();
            Set<Id> campaignIds = new Set<Id>{campaign.Id};
            List<MVEX__Email_Member__c> existingEmailMembers = [SELECT MVEX__RecipientId__c, MVEX__Marketing_Email__c, MVEX__Schedule_Date_and_Time__c
                                                                FROM MVEX__Email_Member__c WHERE MVEX__Marketing_Email__c IN (SELECT Id FROM MVEX__Marketing_Email__c 
                                                                WHERE MVEX__Marketing_Campaign__c IN :campaignIds) WITH USER_MODE];
            Set<String> existingKeys = new Set<String>();
            for (MVEX__Email_Member__c em : existingEmailMembers) {
                existingKeys.add(em.MVEX__RecipientId__c + '-' + em.MVEX__Marketing_Email__c + '-' + String.valueOf(em.MVEX__Schedule_Date_and_Time__c));
            }
            
            String scheduleType = specificDate != null ? 'Specific Date' : 'Contact Field';
            
            for (String contactId : selectedPrimaryRecipients) {
                if (!conMap.containsKey(contactId) || conMap.get(contactId) == null) {
                    failedEmails += marketingEmailCount;
                    for (MVEX__Marketing_Email__c email : emailRecordsToInsert) {
                        MVEX__Email_Member__c emailMember = new MVEX__Email_Member__c(
                            MVEX__RecipientId__c = contactId,
                            MVEX__Marketing_Email__c = email.Id,
                            MVEX__Schedule_Date_and_Time__c = null,
                            MVEX__Status__c = 'Failed (No Email)'
                        );
                        emailMembersToInsert.add(emailMember);
                    }
                    continue;
                }
                Date scheduleBaseDate;
                if (scheduleType == 'Specific Date') {
                    scheduleBaseDate = specificDate;
                } else {
                    scheduleBaseDate = contactIdToDateMap.get(contactId);
                }
                if (scheduleBaseDate == null) {
                    failedEmails += marketingEmailCount;
                    for (MVEX__Marketing_Email__c email : emailRecordsToInsert) {
                        MVEX__Email_Member__c emailMember = new MVEX__Email_Member__c(
                            MVEX__RecipientId__c = contactId,
                            MVEX__Marketing_Email__c = email.Id,
                            MVEX__Schedule_Date_and_Time__c = null,
                            MVEX__Status__c = 'Failed (Invalid Date)'
                        );
                        emailMembersToInsert.add(emailMember);
                    }
                    continue;
                }
                for (MVEX__Marketing_Email__c email : emailRecordsToInsert) {
                    DateTime scheduledDateTime;
                    
                    // For immediate send, schedule for right now
                    if (isImmediateSend && email.MVEX__Days_After_Start_Date__c == 0) {
                        scheduledDateTime = DateTime.now();
                    } else {
                        Date emailDate = scheduleBaseDate.addDays(Integer.valueOf(email.MVEX__Days_After_Start_Date__c));
                        scheduledDateTime = DateTime.newInstanceGmt(emailDate, email.MVEX__TimeToSend__c);
                    }
            
                    String memberKey = contactId + '-' + email.Id + '-' + String.valueOf(scheduledDateTime);
                    
                    if (!emailMemberKeys.contains(memberKey) && !existingKeys.contains(memberKey)) {
                        emailMembersToInsert.add(new MVEX__Email_Member__c(
                            MVEX__RecipientId__c = contactId,
                            MVEX__Marketing_Email__c = email.Id,
                            MVEX__Schedule_Date_and_Time__c = scheduledDateTime,
                            MVEX__Status__c = 'Pending'
                        ));
                        emailMemberKeys.add(memberKey);
                    }
                }
            }
            
            insert as user emailMembersToInsert;
            
            // Recalculate campaign counts
            recalculateCampaignCounts(campaign.Id);
            
            
            return campaign.Id;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'EmailCampaignController', 'createCampaignAndEmails', 'Error while creating campaign records.');
            return null;
        }
    }

    /**
     * Method Name : recalculateCampaignCounts
     * modified By : Yash Parekh
     * modified Date : 25/05/2025
     * Date : 06/05/2025
     * @description : Recalculates campaign counts based on MVEX__Email_Member__c records
     */
    public static void recalculateCampaignCounts(Id campaignId) {
        try {
            MVEX__Marketing_Campaign__c campaign = [
                SELECT Id, MVEX__Total_Emails__c, MVEX__Remaining_Emails__c, MVEX__Failed_Emails__c, MVEX__Total_Sent_Mails__c, MVEX__Status__c
                FROM MVEX__Marketing_Campaign__c
                WHERE Id = :campaignId WITH USER_MODE
                LIMIT 1
            ];
            List<MVEX__Email_Member__c> emailMembers = [
                SELECT Id, MVEX__Status__c, MVEX__Schedule_Date_and_Time__c, MVEX__Marketing_Email__r.MVEX__Marketing_Campaign__c
                FROM MVEX__Email_Member__c
                WHERE MVEX__Marketing_Email__r.MVEX__Marketing_Campaign__c = :campaignId
                WITH USER_MODE
            ];


            Integer totalEmails = 0;
            Integer remainingEmails = 0;
            Integer failedEmails = 0;
            Integer sentEmails = 0;

            for (MVEX__Email_Member__c em : emailMembers) {
                totalEmails++;
                if (em.MVEX__Status__c == 'Pending') {
                    remainingEmails++;
                } else if (em.MVEX__Status__c == 'Success') {
                    sentEmails++;
                } else {
                    // Any other status (Failed, Failed (No Email), Failed (Invalid Date), etc.) is counted as failed
                    failedEmails++;
                }
            }

            campaign.MVEX__Total_Emails__c = totalEmails;
            campaign.MVEX__Remaining_Emails__c = remainingEmails;
            campaign.MVEX__Failed_Emails__c = failedEmails;
            campaign.MVEX__Total_Sent_Mails__c = sentEmails;
            campaign.MVEX__Status__c = totalEmails == 0 ? 'Pending' : 
                                (remainingEmails == 0 ? 'Completed' : 
                                (sentEmails > 0 || failedEmails > 0 ? 'In Progress' : 'Pending'));


            update as user campaign;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'EmailCampaignController', 'recalculateCampaignCounts', 'Error recalculating campaign counts for campaignId: ' + campaignId);
        }
    }
                    
    /**
     * Method Name : sendEmails
     * Date : 23/07/2024
     * Created By : Rachit Shah
     * @description : Used for sending email from flow
     */
    public static Boolean isValidId(String idStr) {
        if (String.isBlank(idStr)) return false;
        if (idStr.equalsIgnoreCase('null') || idStr.equalsIgnoreCase('undefined')) return false;
        return (idStr.length() == 15 || idStr.length() == 18) && Pattern.matches('^[a-zA-Z0-9]{15,18}$', idStr);
    }

    @InvocableMethod(label='Send Emails (Specific Date)' description='Send emails to primary, cc, and bcc recipients for specific date campaigns')
    public static void sendEmails(List<EmailRequests> emailRequests) {
        try {
            Map<String, Map<String, String>> contactEmailInfoMap = new Map<String, Map<String, String>>();
            Map<Id, String> templateBodyMap = new Map<Id, String>();
            List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

            List<GmailIntegrationControllerV1.EmailWrapper> gmails = new List<GmailIntegrationControllerV1.EmailWrapper>();
            Set<String> campaignIds = new Set<String>();
            Set<String> recipientIds = new Set<String>();

            String processedBody = ''; 

            // Track processed MVEX__Email_Member__c IDs to avoid duplicates
            Set<String> processedKeys = new Set<String>();

            if (emailRequests != null) {
                for (EmailRequests req : emailRequests) {
                    if (req.toAddresses != null) {
                        for (String addr : req.toAddresses) {
                            if (isValidId(addr)) {
                                recipientIds.add(addr);
                            }
                        }
                    }
                }
            }
            Map<String, Integer> remainingEmailsMap = new Map<String, Integer>();
            Set<Id> templateIds = new Set<Id>();
            Set<Id> listingIds = new Set<Id>();
            Map<String, Id> emailToRecipientIdMap = new Map<String, Id>();

            // Query Contacts to map recipient IDs to emails
            Map<Id, SObject> idToRecipientMap = new Map<Id, SObject>();
            if (!recipientIds.isEmpty()) {
                List<Contact> contacts = [SELECT Id, Email FROM Contact WHERE Id IN :recipientIds WITH USER_MODE];
                for (Contact c : contacts) {
                    if (c.Email != null) {
                        idToRecipientMap.put(c.Id, c);
                    }
                }
            }

            // Now, replace req.toAddresses (ids) with actual emails for downstream logic
            if (emailRequests != null) {
                for (EmailRequests req : emailRequests) {
                    List<String> emailAddresses = new List<String>();
                    if (req.toAddresses != null) {
                        for (String recipientId : req.toAddresses) {
                            if (isValidId(recipientId)) {
                                SObject rec = idToRecipientMap.get((Id)recipientId);
                                if (rec != null) {
                                    String email = (String)rec.get('Email');
                                    if (email != null) {
                                        emailAddresses.add(email);
                                        emailToRecipientIdMap.put(email, (Id)recipientId);
                                    }
                                }
                            }
                        }
                    }
                    req.toAddresses = emailAddresses;
                }

                // Collect campaign IDs and template IDs, and map email addresses to recipient IDs
                for (EmailRequests req : emailRequests) {
                    if (isValidId(req.campaignId)) {
                        campaignIds.add(req.campaignId);
                    }
                    if (isValidId(req.templateDataId)) {
                        templateIds.add((Id)req.templateDataId);
                    }
                    if (isValidId(req.listingId) && String.isNotBlank(req.RelatedObjectName) && 
                        (req.RelatedObjectName.equalsIgnoreCase('MVEX__Listing__c') || req.RelatedObjectName.equalsIgnoreCase('MVEX__Listing__c'))) {
                        listingIds.add((Id)req.listingId);
                    }

                    if (req.toAddresses != null) {
                        for (String toAddress : req.toAddresses) {
                            if (toAddress != null) {
                                emailToRecipientIdMap.put(toAddress, null);
                            }
                        }
                    }
                }
            }
            
            Map<String, MVEX__Marketing_Campaign__c> campaignMap = new Map<String, MVEX__Marketing_Campaign__c>();
            Map<String, List<Id>> campaignToRecipientMap = new Map<String, List<Id>>();
            Map<String, Set<Id>> campaignToEmailIdsMap = new Map<String, Set<Id>>();


            if (!campaignIds.isEmpty()) {
                List<MVEX__Marketing_Campaign__c> campaigns = [
                    SELECT 
                        Id, Name, MVEX__Status__c, MVEX__Remaining_Emails__c, MVEX__Total_Sent_Mails__c, 
                        MVEX__Email_Type__c, MVEX__Schedule_Type__c, MVEX__RelatedObject__c,
                        (SELECT Id, MVEX__RecipientId__c FROM MVEX__Marketing_Campaign_Members__r),
                        (SELECT Id, MVEX__Listing__c FROM MVEX__Marketing_Emails__r)
                    FROM MVEX__Marketing_Campaign__c 
                    WHERE Id IN :campaignIds
                    WITH USER_MODE
                ];
            
                for (MVEX__Marketing_Campaign__c campaign : campaigns) {
                    campaignMap.put(campaign.Id, campaign);
                    remainingEmailsMap.put(campaign.Id, Integer.valueOf(campaign.MVEX__Remaining_Emails__c));
            
                    // Process campaign members - safely add to List<Id>
                    List<Id> recipientListPerCampaign = new List<Id>();
                    for (MVEX__Marketing_Campaign_Member__c member : campaign.MVEX__Marketing_Campaign_Members__r) {
                        if (isValidId(member.MVEX__RecipientId__c)) {
                            recipientListPerCampaign.add((Id)member.MVEX__RecipientId__c);
                            recipientIds.add(member.MVEX__RecipientId__c);
                        }
                    }
                    campaignToRecipientMap.put(campaign.Id, recipientListPerCampaign);
            
                    // Process emails
                    Set<Id> emailIdsPerCampaign = new Set<Id>();
                    for (MVEX__Marketing_Email__c email : campaign.MVEX__Marketing_Emails__r) {
                        emailIdsPerCampaign.add(email.Id);
                    }
                    campaignToEmailIdsMap.put(campaign.Id, emailIdsPerCampaign);
                }
            }
            
            // Determine which objects to query based on MVEX__RelatedObject__c
            Map<String, Set<Id>> objectToIdsMap = new Map<String, Set<Id>>{
                'Contact' => new Set<Id>()
            };
            for (String campaignId : campaignMap.keySet()) {
                List<Id> recipientIdsForCampaign = campaignToRecipientMap.get(campaignId);
                if (recipientIdsForCampaign != null) {
                    objectToIdsMap.get('Contact').addAll(recipientIdsForCampaign);
                }
            }
            
            // Query Contacts
            Map<String, SObject> emailToRecipientMap = new Map<String, SObject>();
            if (!objectToIdsMap.get('Contact').isEmpty()) {
                List<Contact> contactList = getContacts(objectToIdsMap.get('Contact'));
                for (Contact contact : contactList) {
                    if (contact.Email != null) {
                        emailToRecipientMap.put(contact.Email, contact);
                        emailToRecipientIdMap.put(contact.Email, contact.Id);
                    }
                }
            }
            
            // Query MVEX__Email_Member__c records to update status later
            Map<String, MVEX__Email_Member__c> emailMembersToUpdate = new Map<String, MVEX__Email_Member__c>();
            if (!campaignIds.isEmpty() && !recipientIds.isEmpty()) {
                List<MVEX__Email_Member__c> emailMembers = [
                    SELECT Id, MVEX__RecipientId__c, MVEX__Marketing_Email__c, MVEX__Status__c 
                    FROM MVEX__Email_Member__c
                    WHERE MVEX__RecipientId__c IN :recipientIds 
                    AND MVEX__Marketing_Email__c IN (SELECT Id FROM MVEX__Marketing_Email__c WHERE MVEX__Marketing_Campaign__c IN :campaignIds)
                    AND MVEX__Status__c = 'Pending'
                    WITH USER_MODE
                ];
                for (MVEX__Email_Member__c em : emailMembers) {
                    String key = em.MVEX__RecipientId__c + '-' + em.MVEX__Marketing_Email__c;
                    emailMembersToUpdate.put(key, em);
                }
            }
                
            List<MVEX__Template__c> temps = [
                SELECT Id, Name, MVEX__Object_API_Name__c, MVEX__Template_Name__c, MVEX__Template_pattern__c, MVEX__Template_Status__c, MVEX__Description__c, CreatedDate, LastModifiedDate,
                    (SELECT Id, Name, MVEX__Template_Value_Simple__c FROM MVEX__Template_Data__r WHERE MVEX__Value_Type__c = 'Extracted Mapping Keys' ORDER BY MVEX__Order_No_Simple__c ASC)
                FROM MVEX__Template__c 
                WHERE Id IN :templateIds WITH USER_MODE
            ];                    
            
            Set<Id> recipientObjectIds = new Set<Id>();
            for (EmailRequests request : emailRequests) {
                if (request.toAddresses != null) {
                    for (String toAddress : request.toAddresses) {
                        SObject recipient = emailToRecipientMap.get(toAddress);
                        if (recipient != null && recipient.Id != null) {
                            recipientObjectIds.add(recipient.Id);
                        }
                    }
                }
            }

            Map<Id, Id> listingIdToPropertyId = new Map<Id, Id>();
            Map<String, Map<String, String>> listingImages = new Map<String, Map<String, String>>();

            for (MVEX__Listing__c listing : [SELECT Id, MVEX__Property__c FROM MVEX__Listing__c WHERE Id IN :listingIds WITH USER_MODE LIMIT 5000]) {
                listingIdToPropertyId.put(listing.Id, listing.MVEX__Property__c);
            }
    
            // Step 2: Get all MVEX__Property_File__c records in a single query
            Map<Id, List<MVEX__Property_File__c>> propertyIdToFiles = new Map<Id, List<MVEX__Property_File__c>>();
            for (MVEX__Property_File__c file : [SELECT Id, MVEX__BaseUrl__c, MVEX__Property__c FROM MVEX__Property_File__c WHERE MVEX__Property__c IN :listingIdToPropertyId.values() 
                                                AND MVEX__IsOnExpose__c = true AND MVEX__Size__c != null WITH USER_MODE ORDER BY MVEX__Sort_on_Expose__c ASC NULLS LAST, Name ASC LIMIT 50000]) {
                if (!propertyIdToFiles.containsKey(file.MVEX__Property__c)) {
                    propertyIdToFiles.put(file.MVEX__Property__c, new List<MVEX__Property_File__c>());
                }
                propertyIdToFiles.get(file.MVEX__Property__c).add(file);
            }
    
            // Step 3: Build the result map
            for (Id listingId : listingIds) {
                Map<String, String> imageMap = new Map<String, String>();
                Id propertyId = listingIdToPropertyId.get(listingId);
    
                if (propertyId != null && propertyIdToFiles.containsKey(propertyId)) {
                    List<MVEX__Property_File__c> mediaList = propertyIdToFiles.get(propertyId);
                    for (Integer i = 0; i < mediaList.size(); i++) {
                        imageMap.put('listingMedia[' + (i + 1) + ']', mediaList[i].MVEX__BaseUrl__c);
                    }
                }
    
                listingImages.put(listingId, imageMap);
            }
            
            for (EmailRequests request : emailRequests) {

                MVEX__Marketing_Campaign__c campaignRecord = campaignMap.get(request.campaignId);
                if (campaignRecord == null || campaignRecord.MVEX__Schedule_Type__c != 'Specific Date') {
                    continue; // Skip if not specific date
                }

                String emailType = campaignRecord.MVEX__Email_Type__c;
                String relatedObject = campaignRecord.MVEX__RelatedObject__c;
    
                String extractedKeyString = '';
                List<MVEX__Template__c> fieldData = new List<MVEX__Template__c>();
                if (!temps.isEmpty() && request.templateDataId != null) {
                    for (MVEX__Template__c tempData : temps) {
                        if (tempData.Id == request.templateDataId) {
                            fieldData.add(tempData);
                        }
                    }
                    if (!fieldData.isEmpty()) {
                        extractedKeyString += fieldData[0].MVEX__Template_Data__r.size() > 0 ? fieldData[0].MVEX__Template_Data__r[0].MVEX__Template_Value_Simple__c : '';
                    }
                }
                extractedKeyString = extractedKeyString != '' ? extractedKeyString : 'null';
                String sourceObjectAPI = !temps.isEmpty() ? temps[0].MVEX__Object_API_Name__c : null;
                Map<String, Object> extractedKeyMap = extractedKeyString != 'null' ? (Map<String, Object>) JSON.deserializeUntyped(extractedKeyString) : new Map<String, Object>();            
                
                if (request.toAddresses != null) {
                    for (String toAddress : request.toAddresses) {
                        // Reset body per-recipient so substitutions from one recipient
                        // don't carry over into the next recipient's email.
                        processedBody = request.body;
                        SObject recipient = emailToRecipientMap.get(toAddress);
                        if (recipient == null) {
                            continue;
                        }
                        
                        String recipientId = recipient.Id;
                        Set<Id> emailIds = campaignToEmailIdsMap.get(request.campaignId);
                        if (emailIds == null) {
                            continue;
                        }
                        
                        String matchedKey;
                        for (Id emailId : emailIds) {
                            String key = recipientId + '-' + emailId;
                            if (emailMembersToUpdate.containsKey(key) && !processedKeys.contains(key)) {
                                matchedKey = key;
                                break;
                            }
                        }
                        
                        if (matchedKey == null) {
                            continue;
                        }

                        Map<String, Map<String, String>> mappingKeys;
                        String relObj = request.RelatedObjectName;
                        
                        if (String.isNotBlank(relObj)) {
                            if (relObj.equalsIgnoreCase('MVEX__Listing__c') || relObj.equalsIgnoreCase('MVEX__Listing__c')) {
                                mappingKeys = DataMappingControllerV2.getMappingsKeyValues2(extractedKeyMap, relObj, listingIds, true);
                            } else if (relObj.equalsIgnoreCase('Contact') && recipient != null && recipient.Id != null) {
                                Set<Id> idsToMap = new Set<Id>{recipient.Id};
                                mappingKeys = DataMappingControllerV2.getMappingsKeyValues2(extractedKeyMap, relObj, idsToMap, true);
                            } else if (recipient != null && recipient.Id != null) {
                                // Default fallback for other objects, assuming recipient.Id is the relevant ID
                                Set<Id> idsToMap = new Set<Id>{recipient.Id};
                                mappingKeys = DataMappingControllerV2.getMappingsKeyValues2(extractedKeyMap, relObj, idsToMap, true);
                            }
                        }

                    processedKeys.add(matchedKey);
                    if (recipient != null && mappingKeys != null) {
                        Map<String, String> mappingKeyVsMappingValues = mappingKeys.get('objectNGeneral');
                        Map<String, String> salesforceImages = mappingKeys.get('salesforceImages');
                        if (mappingKeyVsMappingValues != null) {
                            for (String key : mappingKeyVsMappingValues.keySet()) {
                                String escapedKey = Pattern.quote(key);
                                processedBody = processedBody.replaceAll(escapedKey, mappingKeyVsMappingValues.get(key));
                            }
                        }
                        if (salesforceImages != null) {
                            for (String src : salesforceImages.keySet()) {
                                String escapedSrc = Pattern.quote(src);
                                processedBody = processedBody.replaceAll(escapedSrc, salesforceImages.get(src));
                            }
                        }

                        // --- Recipient field replacement for Listing templates ---
                        // Replace {{EXPRecipient.<FieldAPI>}} keys with values from the To-recipient
                        // Contact's own fields. CC/BCC contacts are intentionally excluded here.
                        String relObjName = request.RelatedObjectName;
                        if (String.isNotBlank(relObjName) &&
                                (relObjName.equalsIgnoreCase('MVEX__Listing__c') || relObjName.equalsIgnoreCase('MVEX__Listing__c'))) {
                            Set<String> recipientFieldKeys = DataMappingControllerV2.collectRecipientFieldKeys(extractedKeyMap);
                            if (!recipientFieldKeys.isEmpty()) {
                                Contact recipientContact = (Contact) emailToRecipientMap.get(toAddress);
                                if (recipientContact != null) {
                                    Map<String, String> recipientReplacements =
                                        DataMappingControllerV2.getRecipientFieldReplacements(recipientFieldKeys, recipientContact);
                                    for (String rKey : recipientReplacements.keySet()) {
                                        processedBody = processedBody.replaceAll(
                                            Pattern.quote(rKey),
                                            recipientReplacements.get(rKey) != null ? recipientReplacements.get(rKey) : ''
                                        );
                                    }
                                }
                            }
                        }
                    }


                    if (recipient != null && listingImages != null && request.listingId != null) {
                        Map<String, String> imageMap = listingImages.get(request.listingId);
                    
                        if (imageMap != null) {
                            // Regex to match entire <img> tag with listingMedia[n] and extract the full tag
                            String imgTagRegex = '<img[^>]*data-name="(listingMedia\\[\\d+\\])"[^>]*src="[^"]+"[^>]*>';
                            Matcher matcher = Pattern.compile(imgTagRegex).matcher(processedBody);
                    
                            while (matcher.find()) {
                                String fullMatch = matcher.group(0); // The entire <img ...> tag
                                String mediaKey = null;
                    
                                // Extract the actual media key from the tag
                                Matcher keyMatcher = Pattern.compile('data-name="(listingMedia\\[\\d+\\])"').matcher(fullMatch);
                                if (keyMatcher.find()) {
                                    mediaKey = keyMatcher.group(1);
                                }
                    
                                if (mediaKey != null && imageMap.containsKey(mediaKey)) {
                                    String newSrc = imageMap.get(mediaKey);
                    
                                    if (newSrc != null) {
                                        // Replace only the src value inside the tag
                                        String updatedTag = fullMatch.replaceFirst('src="[^"]+"', 'src="' + newSrc + '"');
                    
                                        // Replace the old tag with the updated one in the body
                                        processedBody = processedBody.replace(fullMatch, updatedTag);
                                    }
                                }
                            }
                        }
                    }
                    
                    if (emailType == 'single') {
                            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                            String replyToEmail = 'replyemailservice@2399seg7dczkd2wdrur97lyz9f5kxoq6rsi3uyqam30un540ms.dm-9p5p6uac.ind136.apex.salesforce.com';
                            if (replyToEmail != null) {
                                email.setReplyTo(replyToEmail);
                            }
                            email.setToAddresses(new List<String>{toAddress});
                            if (request.ccAddresses != null) {
                                List<String> ccEmails = parseEmailAddresses(request.ccAddresses);
                                email.setCcAddresses(ccEmails);
                            }
                            if (request.bccContacts != null) {
                                List<String> bccEmails = parseEmailAddresses(request.bccContacts);
                                email.setBccAddresses(bccEmails);
                            }
                            email.setSubject(request.subject);
                            email.setHtmlBody(processedBody);
                            emails.add(email);
                            contactEmailInfoMap.put(recipient.Id, new Map<String, String>{
                                'subject' => request.subject,
                                'body' => processedBody,
                                'email' => toAddress,
                                'cc' => request.ccAddresses,
                                'bcc' => request.bccContacts
                            });
                    } else if (emailType == 'gmail') {
                        GmailIntegrationControllerV1.EmailWrapper singleGmail = new GmailIntegrationControllerV1.EmailWrapper();
                        singleGmail.toAddresses = new List<String>{toAddress};
                        if (request.ccAddresses != null) {
                            List<String> ccEmails = parseEmailAddresses(request.ccAddresses);
                            singleGmail.ccAddresses = ccEmails;
                        }
                        if (request.bccContacts != null) {
                            List<String> bccEmails = parseEmailAddresses(request.bccContacts);
                            singleGmail.bccAddresses = bccEmails;
                        }
                        singleGmail.subject = request.subject;
                        singleGmail.body = processedBody;
                        if (singleGmail.contactEmailInfoMap == null) {
                            singleGmail.contactEmailInfoMap = new Map<String, Map<String, String>>();
                        }
                        singleGmail.contactEmailInfoMap.put(recipient.Id, new Map<String, String>{
                            'subject' => request.subject,
                            'body' => processedBody,
                            'email' => toAddress,
                            'cc' => request.ccAddresses,
                            'bcc' => request.bccContacts
                        });
                        gmails.add(singleGmail);
                    }
                    
                    if (remainingEmailsMap.containsKey(request.campaignId) && remainingEmailsMap.get(request.campaignId) > 0) {
                        remainingEmailsMap.put(request.campaignId, remainingEmailsMap.get(request.campaignId) - 1);
                    }
                }      
            }
        }


            try {
                List<MVEX__Email_Member__c> emailMembersToUpdateList = new List<MVEX__Email_Member__c>();
                for (String key : processedKeys) {
                    if (emailMembersToUpdate.containsKey(key)) {
                        MVEX__Email_Member__c em = emailMembersToUpdate.get(key);
                        em.MVEX__Status__c = 'Success';
                        emailMembersToUpdateList.add(em);
                    }
                }
                
                if (!emailMembersToUpdateList.isEmpty()) {
                    update as user emailMembersToUpdateList;
                }
                
                if (!emails.isEmpty()) {
                    Messaging.sendEmail(emails);
                } else if (!gmails.isEmpty()) {
                    GmailIntegrationControllerV1.requestNewAccessToken(gmails, remainingEmailsMap, campaignMap, true);
                }

            } catch (Exception e) {
                // Update MVEX__Email_Member__c status to 'Failed' for processed records
                List<MVEX__Email_Member__c> emailMembersToUpdateList = new List<MVEX__Email_Member__c>();
                for (String key : processedKeys) {
                    if (emailMembersToUpdate.containsKey(key)) {
                        MVEX__Email_Member__c em = emailMembersToUpdate.get(key);
                        em.MVEX__Status__c = 'Failed';
                        emailMembersToUpdateList.add(em);
                    }
                }
                if (!emailMembersToUpdateList.isEmpty()) {
                    update as user emailMembersToUpdateList;
                }
            }
            
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'EmailCampaignController', 'sendEmails', 'Error while sending mail');
        }
    }

                    
                    
    /**
     * Method Name : EmailRequests
     * Date : 23/07/2024
     * Created By : Rachit Shah
     * @description : Wrapper class for get all data
     */
    public class EmailRequests {
        @InvocableVariable(required=true description='List of primary recipient email addresses')
        public List<String> toAddresses;
        
        @InvocableVariable(description='List of CC recipient email addresses')
        public String ccAddresses;
        
        @InvocableVariable(description='List of BCC recipient email addresses')
        public String bccContacts;
        
        @InvocableVariable(required=true description='Subject of the email')
        public String subject;
        
        @InvocableVariable(required=true description='Body of the email')
        public String body;
        
        @InvocableVariable(required=true description='Camapign Id')
        public String campaignId;
        
        @InvocableVariable(required=true description='Template Data Id')
        public String templateDataId;

        @InvocableVariable(description='Listing Id')
        public String listingId;
        
        @InvocableVariable(required=true description='Related Object Name')
        public String RelatedObjectName;

        @InvocableVariable(required=false description='Template Type')
        public String templateType;
        
    }
    
    /**
     * Method Name : parseEmailAddresses
     * Date : 23/07/2024
     * Created By : Rachit Shah
     * @description : getting email from the camapign data
     */
    
    private static List<String> parseEmailAddresses(String addresses) {
        
        try {
            List<String> emailList = new List<String>();
            List<String> addressPairs = addresses.split('@@@');
            for (String pair : addressPairs) {
                List<String> parts = pair.split(':');
                if (parts.size() == 2) {
                    emailList.add(parts[1]);
                }
            }
            return emailList;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'EmailCampaignController', 'parseEmailAddresses', 'Error while parsing Emails');
            return null;
        }
        
    }
    
    
    
    /**
     * Method Name : getAllFieldNames
     * Date : 23/07/2024
     * Created By : Rachit Shah
     * @description : get all fields name
     */
    public static List<String> getAllFieldNames(String objectName) {
        try {
            List<String> fieldNames = new List<String>();
            
            Schema.SObjectType sObjectType = Schema.getGlobalDescribe().get(objectName);
            if (!sObjectType.getDescribe().isAccessible()) {
                ErrorHandler.insertErrordata(null, 'EmailCampaignController', 'getAllFieldNames', 'No access to object: ' + objectName + ' at line 2267.');
                return null;
            }
            
            Map<String, Schema.SObjectField> fields = sObjectType.getDescribe().fields.getMap();
            for(Schema.SObjectField field : fields.values()) {
                Schema.DescribeFieldResult dr = field.getDescribe();
                if (dr.isAccessible()) {
                    fieldNames.add(dr.getName());
                }
            }
            fieldNames.sort();
            
            return fieldNames;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'EmailCampaignController', 'getAllFieldNames', 'Error while getting Contacts');
            return null;
        }
    }
}