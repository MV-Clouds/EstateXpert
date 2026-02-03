/**
 * Class Name : EmailCampaignController
 * Date : 23/07/2024
 * Created By : Rachit Shah
 * @description : Used for scheduling emails
 */

public with sharing class EmailCampaignController {
    
    /**
     * Method Name : getEmailCampaignTemplates 
     * Date : 23/07/2024
     * Created By : Rachit Shah
     * @description : Used for getting campaign data
     */
    @AuraEnabled(cacheable=true)
    public static List<Marketing_Campaign__c> getEmailCampaignTemplates() {
        try {
            List<Marketing_Campaign__c> templates = [SELECT Id, Label__c, From_Name__c, From_Address__c, Sender_Mode__c,Is_Marketing_Campaign_Template__c,Marketing_Campaign_Template__c,Campaign_Start_Date__c,Total_Sent_Mails__c	 FROM Marketing_Campaign__c WHERE Is_Marketing_Campaign_Template__c = true WITH USER_MODE ];
            
            return templates;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'EmailCampaignController', 'getEmailCampaignTemplates', 'Error while  getting getEmailCampaignTemplates');
            return null;
            
        }
    }
    
    /**
     * Method Name : getContacts
     * Date : 23/07/2024
     * Created By : Rachit Shah
     * @description : Used for getting contact data
     */
    @AuraEnabled(cacheable=true)
    public static List<Contact> getContacts() {
        try {
            return [SELECT Id, Name, Email FROM Contact WITH USER_MODE LIMIT 50000];
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'EmailCampaignController', 'getContacts', 'Error while getting data from contacts');
            return null;
        }
    }
    

    /**
     * Method Name : getCampaign
     * Date : 23/05/2025
     * Created By : Yash Parekh
     * @description : Used for getting Campaign data
     */
    @AuraEnabled(cacheable=true)
    public static Marketing_Campaign__c getCampaign(String campaignId) {
        try {
            return [SELECT Id,RelatedObject__c FROM Marketing_Campaign__c WHERE Id = :campaignId WITH USER_MODE];
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'EmailCampaignController', 'getCampaign', 'Error while getting data from campaign');
            return null;
        }
    }

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
    
    /**
     * Method Name : getDateFieldsForPicklist
     * Date : 23/07/2024
     * Created By : Rachit Shah
     * @description : Used for getting picklist values
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getDateFieldsForPicklist() {
        try {
            List<Map<String, String>> options = new List<Map<String, String>>();
            
            Map<String, Schema.SObjectField> contactFields = Schema.SObjectType.Contact.fields.getMap();
            
            Set<String> auditFieldsToExclude = new Set<String>{
                'createddate', 'lastmodifieddate', 'systemmodstamp', 'lastactivitydate', 'lastreferenceddate', 'lastvieweddate'
            };
            
            for (String fieldName : contactFields.keySet()) {
                String filedOrginalName = fieldName;
                Schema.DescribeFieldResult fieldDescribe = contactFields.get(fieldName).getDescribe();
                if (fieldDescribe.getType() == Schema.DisplayType.Date && !auditFieldsToExclude.contains(fieldName.toLowerCase())) {
                    options.add(new Map<String, String>{
                        'label' => fieldDescribe.getLabel(),
                        'value' => fieldDescribe.getName()
                    });
                }
            }
            
            return options;
            
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'EmailCampaignController', 'getDateFieldsForPicklist', 'Error while  getting data from getDateFieldsForPicklist ');
            return  null;
            
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
            
            List<Template__c> templates = [SELECT Id, Template_Name__c, Subject__c, Object_API_Name__c ,
                                        (SELECT Template_Value_Simple__c, Value_Type__c FROM Template_Data__r WHERE Value_Type__c = 'Body Value' ORDER BY Order_No_Simple__c ASC)
                                        FROM Template__c WHERE Template_pattern__c = 'Marketing Template' AND Template_Status__c = true WITH USER_MODE];
            for (Template__c template : templates) {
                String templateBody = '';
                
                for (Template_Data__c fieldData : template.Template_Data__r) {
                    String value = fieldData.Template_Value_Simple__c != null ? fieldData.Template_Value_Simple__c : '';
                    if (fieldData.Value_Type__c == 'Body Value') {
                        templateBody += value;
                    }
                }
                
                TemplateWrapper wrapper = new TemplateWrapper();
                wrapper.templateId = template.Id;
                wrapper.templateName = template.Template_Name__c;
                wrapper.subject = template.Subject__c;
                wrapper.body = templateBody;
                wrapper.objectApiName = template.Object_API_Name__c;
                
                templateWrappers.marketingTemplates.add(wrapper);
            }
            
            List<Template__c> templatedatas = [SELECT Id, Template_Name__c FROM Template__c WHERE Object_API_Name__c = 'MVEX__Listing__c' AND Template_Status__c = true WITH USER_MODE ORDER BY Template_Name__c ASC];
            
            for (Template__c template : templatedatas) {
                TemplateWrapper wrapper = new TemplateWrapper();
                wrapper.templateId = template.Id;
                wrapper.templateName = template.Template_Name__c;
                
                templateWrappers.listingTemplates.add(wrapper);
            }
            
            return templateWrappers;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'EmailCampaignController', 'getQuickTemplates', 'Error while retriving data in apex.');
            return null;
        }
    }
    
    /**
     * Method Name : getMarketingEmails
     * Date : 23/07/2024
     * Created By : Rachit Shah
     * @description : Used for getting marketing email data
     */
    @AuraEnabled(cacheable=true)
    public static List<Marketing_Email__c> getMarketingEmails(String templateId) {
        try {
            return [SELECT Id, Name, Marketing_Campaign__c ,Subject__c,Send_Date_Time__c,Days_After_Start_Date__c,TimeToSend__c,Listing__c, Template_Id__c,Template_Type__c	
                    FROM Marketing_Email__c 
                    WHERE Marketing_Campaign__c = :templateId WITH USER_MODE];
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'EmailCampaignController', 'getMarketingEmails', 'Error while retriving data in apex.');
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
            
            // Retrieve custom metadata: Outlook_Data__mdt
            OutlookConfig__c outlookConfig = OutlookConfig__c.getOrgDefaults();
            if (outlookConfig != null && !String.isBlank(outlookConfig.Refresh_Token_1__c)) {
                optionsMap.put('Outlook', 'outlook');
            }
            
            // Retrieve custom setting: GmailConfig__c
            GmailConfig__c gmailConfig = GmailConfig__c.getOrgDefaults();
            if (gmailConfig != null && !String.isBlank(gmailConfig.Refresh_Token__c)) {
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
            System.debug('DEBUG: Initial individual recipients count: ' + selectedPrimaryRecipientsSet.size());

            // Extract broadcast groups (IDs) from JSON payload
            List<String> selectedBroadcastGroups = new List<String>();
            if (campaignEmailDataMap.containsKey('selectedBroadcastGroups') && campaignEmailDataMap.get('selectedBroadcastGroups') != null) {
                for (Object groupId : (List<Object>) campaignEmailDataMap.get('selectedBroadcastGroups')) {
                    selectedBroadcastGroups.add(String.valueOf(groupId));
                }
            }
            System.debug('DEBUG: Selected broadcast groups count: ' + selectedBroadcastGroups.size());

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
                
                System.debug('DEBUG: Recipients found in groups: ' + broadcastRecipientIds.size());
                
                // 3. Add broadcast group recipients to selected primary recipients set (Set naturally handles duplicates)
                selectedPrimaryRecipientsSet.addAll(broadcastRecipientIds);
                
                System.debug('DEBUG: Total unique recipients after merge: ' + selectedPrimaryRecipientsSet.size());
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
            
            // Query contacts to validate emails and date fields
            String queryForFailedEmails = 'SELECT Id, Email';
            if (!String.isEmpty(selectedContactDateField)) {
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
            Marketing_Campaign__c campaign = new Marketing_Campaign__c(
                Label__c = campaignName,
                Is_Marketing_Campaign_Template__c = saveForFuture,
                Primary_Recipient__c = String.join(selectedPrimaryRecipients, '@@@'),
                BCC_Contacts__c = bccRecipients,
                CC_Contacts__c = ccRecipients,
                Total_Emails__c = 0,
                Email_Type__c = emailType,
                Failed_Emails__c = failedEmails,
                Status__c = isImmediateSend ? 'In Progress' : 'Pending', // Set status based on immediate send
                Schedule_Type__c = specificDate != null ? 'Specific Date' : 'Contact Field',
                RelatedObject__c = relatedObject,
                // ✨ ADDED: Store selected broadcast group IDs
                Selected_Broadcast_Groups__c = !selectedBroadcastGroups.isEmpty() ? String.join(selectedBroadcastGroups, '@@@') : null
            );
            
            if (specificDate != null) {
                campaign.Start_Date__c = specificDate;
                campaign.Campaign_Start_Date__c = specificDate;
            } else if (!String.isEmpty(selectedContactDateField)) {
                campaign.SelectedContactDateField__c = selectedContactDateField;
                campaign.Campaign_Start_Date__c = null;
            }
            if (!String.isEmpty(templateId)) {
                campaign.Marketing_Campaign_Template__c = templateId;
            }
            
            insert as user campaign;
        
            // Create campaign members for all unique recipients
            List<Marketing_Campaign_Member__c> marketingCampaignMembers = new List<Marketing_Campaign_Member__c>();
            for (String contactId : selectedPrimaryRecipients) {
                marketingCampaignMembers.add(new Marketing_Campaign_Member__c(
                    Marketing_Campaign__c = campaign.Id,
                    RecipientId__c = contactId,
                    Contact_Type__c = 'Primary'
                ));
            }
            
            // // Add CC recipients to campaign members
            // for (String ccRecipient : selectedCCRecipients) {
            //     // Extract ID from "id:email" format if needed
            //     String recipientId = ccRecipient;
            //     if (ccRecipient.contains(':')) {
            //         recipientId = ccRecipient.split(':')[0];
            //     }
            //     marketingCampaignMembers.add(new Marketing_Campaign_Member__c(
            //         Marketing_Campaign__c = campaign.Id,
            //         RecipientId__c = recipientId,
            //         Contact_Type__c = 'CC'
            //     ));
            // }
            
            // // Add BCC recipients to campaign members
            // for (String bccRecipient : selectedBCCRecipients) {
            //     // Extract ID from "id:email" format if needed
            //     String recipientId = bccRecipient;
            //     if (bccRecipient.contains(':')) {
            //         recipientId = bccRecipient.split(':')[0];
            //     }
            //     marketingCampaignMembers.add(new Marketing_Campaign_Member__c(
            //         Marketing_Campaign__c = campaign.Id,
            //         RecipientId__c = recipientId,
            //         Contact_Type__c = 'BCC'
            //     ));
            // }
            insert as user marketingCampaignMembers;
            
            // Group Marketing_Email__c by schedule to avoid duplicates for Specific Date
            Map<String, Marketing_Email__c> scheduleToEmailMap = new Map<String, Marketing_Email__c>();
            List<Marketing_Email__c> emailRecordsToInsert = new List<Marketing_Email__c>();
            for (Object emailDataObj : emails) {
                Map<String, Object> emailData = (Map<String, Object>) emailDataObj;
                String subject = String.valueOf(emailData.get('subject'));
                String name = String.valueOf(emailData.get('name'));
                String template = String.valueOf(emailData.get('template'));
                String templateType = String.valueOf(emailData.get('templateType'));
                Integer daysAfterStartDate = Integer.valueOf(emailData.get('daysAfterStartDate'));
                String timeString = (String) emailData.get('timeToSend');
                String selectedListingId = (String) emailData.get('selectedListingId');
                
                String scheduleKey = daysAfterStartDate + '-' + timeString;
                if (specificDate != null && scheduleToEmailMap.containsKey(scheduleKey)) {
                    continue; // Skip duplicate schedules
                }
                
                Marketing_Email__c emailCampaign = new Marketing_Email__c(Marketing_Campaign__c = campaign.Id);
                emailCampaign.Subject__c = subject;
                emailCampaign.Name = name;
                emailCampaign.Template_Id__c = template;
                emailCampaign.Template_Type__c = templateType;
                emailCampaign.Days_After_Start_Date__c = daysAfterStartDate;
                if (selectedListingId != null && selectedListingId != '' && (selectedListingId.length() == 15 || selectedListingId.length() == 18)) {
                    emailCampaign.Listing__c = selectedListingId;
                } else {
                    emailCampaign.Listing__c = null;
                }
                
                if (!String.isEmpty(timeString)) {
                    Time sendTime = Time.newInstance(
                        Integer.valueOf(timeString.split(':')[0]), 
                        Integer.valueOf(timeString.split(':')[1]), 
                        timeString.split(':').size() > 2 ? Integer.valueOf(timeString.split(':')[2]) : 0, 
                        0
                    );
                    emailCampaign.TimeToSend__c = sendTime;
                    
                    // For immediate send, set the send date time to current time
                    if (isImmediateSend && daysAfterStartDate == 0) {
                        DateTime now = DateTime.now();
                        emailCampaign.Send_Date_Time__c = now;
                    } else if (specificDate != null) {
                        DateTime sendDateTime = DateTime.newInstance(specificDate.addDays(daysAfterStartDate), sendTime);
                        emailCampaign.Send_Date_Time__c = sendDateTime;
                    }
                }
                emailRecordsToInsert.add(emailCampaign);
                if (specificDate != null) {
                    scheduleToEmailMap.put(scheduleKey, emailCampaign);
                }
            }
            insert as user emailRecordsToInsert;
            
            // Create Email_Member__c records with distinct schedules based on Schedule_Type__c
            List<Email_Member__c> emailMembersToInsert = new List<Email_Member__c>();
            Set<String> emailMemberKeys = new Set<String>();
            Set<Id> campaignIds = new Set<Id>{campaign.Id};
            List<Email_Member__c> existingEmailMembers = [
                SELECT RecipientId__c, Marketing_Email__c, Schedule_Date_and_Time__c
                FROM Email_Member__c
                WHERE Marketing_Email__c IN (SELECT Id FROM Marketing_Email__c WHERE Marketing_Campaign__c IN :campaignIds)
                WITH USER_MODE
            ];
            Set<String> existingKeys = new Set<String>();
            for (Email_Member__c em : existingEmailMembers) {
                existingKeys.add(em.RecipientId__c + '-' + em.Marketing_Email__c + '-' + String.valueOf(em.Schedule_Date_and_Time__c));
            }
            
            String scheduleType = specificDate != null ? 'Specific Date' : 'Contact Field';
            
            for (String contactId : selectedPrimaryRecipients) {
                if (!conMap.containsKey(contactId) || conMap.get(contactId) == null) {
                    failedEmails += marketingEmailCount;
                    for (Marketing_Email__c email : emailRecordsToInsert) {
                        Email_Member__c emailMember = new Email_Member__c(
                            RecipientId__c = contactId,
                            Marketing_Email__c = email.Id,
                            Schedule_Date_and_Time__c = null,
                            Status__c = 'Failed (No Email)'
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
                    for (Marketing_Email__c email : emailRecordsToInsert) {
                        Email_Member__c emailMember = new Email_Member__c(
                            RecipientId__c = contactId,
                            Marketing_Email__c = email.Id,
                            Schedule_Date_and_Time__c = null,
                            Status__c = 'Failed (Invalid Date)'
                        );
                        emailMembersToInsert.add(emailMember);
                    }
                    continue;
                }
                for (Marketing_Email__c email : emailRecordsToInsert) {
                    DateTime scheduledDateTime;
                    
                    // For immediate send, schedule for right now
                    if (isImmediateSend && email.Days_After_Start_Date__c == 0) {
                        scheduledDateTime = DateTime.now();
                    } else {
                        Date emailDate = scheduleBaseDate.addDays(Integer.valueOf(email.Days_After_Start_Date__c));
                        scheduledDateTime = DateTime.newInstance(emailDate, email.TimeToSend__c);
                    }
            
                    String memberKey = contactId + '-' + email.Id + '-' + String.valueOf(scheduledDateTime);
                    
                    if (!emailMemberKeys.contains(memberKey) && !existingKeys.contains(memberKey)) {
                        emailMembersToInsert.add(new Email_Member__c(
                            RecipientId__c = contactId,
                            Marketing_Email__c = email.Id,
                            Schedule_Date_and_Time__c = scheduledDateTime,
                            Status__c = 'Pending'
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
     * Method Name : updateCampaignAndEmails
     * Date : 23/07/2024
     * Created By : Rachit Shah
     * @description : Used for updating email campaign and emails record
     */
    @AuraEnabled
    public static String updateCampaignAndEmails(String jsonCampaignEmailData) {
        try {
            
            Map<String, Object> campaignEmailDataMap = (Map<String, Object>) JSON.deserializeUntyped(jsonCampaignEmailData);
            
            // Extract campaign details
            String campaignId = (String) campaignEmailDataMap.get('campaignId');
            String campaignName = (String) campaignEmailDataMap.get('campaignName');
            String templateId = (String) campaignEmailDataMap.get('templateId');
            Boolean saveForFuture = (Boolean) campaignEmailDataMap.get('saveForFuture');
            String emailType = (String) campaignEmailDataMap.get('messagingService');
            String selectedContactDateField = (String) campaignEmailDataMap.get('selectedContactDateField');
            String relatedObject = (String) campaignEmailDataMap.get('relatedObject');
            
            // --- RECIPIENT COLLECTION START ---

            // 1. Extract individual recipients first (IDs)
            Set<String> selectedPrimaryRecipientsSet = new Set<String>();
            if (campaignEmailDataMap.containsKey('selectedPrimaryRecipients')) {
                for (Object recipient : (List<Object>) campaignEmailDataMap.get('selectedPrimaryRecipients')) {
                    selectedPrimaryRecipientsSet.add((String) recipient);
                }
            }
            
            // 2. Extract selected broadcast groups (IDs) from JSON payload for saving
            List<String> selectedBroadcastGroups = new List<String>();
            if (campaignEmailDataMap.containsKey('selectedBroadcastGroups') && campaignEmailDataMap.get('selectedBroadcastGroups') != null) {
                for (Object groupId : (List<Object>) campaignEmailDataMap.get('selectedBroadcastGroups')) {
                    selectedBroadcastGroups.add(String.valueOf(groupId));
                }
            }

            // 3. Query recipients from broadcast groups if any selected and add them to the primary set (FIX for 0 recipients bug)
            if (!selectedBroadcastGroups.isEmpty()) {
                Set<String> broadcastRecipientIds = new Set<String>();
                
                String recipientIdField = 'MVEX__Member_Record_Id__c';
                String query = 'SELECT ' + recipientIdField + 
                                ' FROM MVEX__Broadcast_Group_Member__c' +
                                ' WHERE MVEX__Broadcast_Group_ID__c IN :selectedBroadcastGroups' +
                                ' AND ' + recipientIdField + ' != NULL' ;
                
                List<SObject> groupMembers = Database.query(String.escapeSingleQuotes(query));
                
                for (SObject member : groupMembers) {
                    String recipientId = (String)member.get(recipientIdField);
                    if (recipientId != null) {
                        broadcastRecipientIds.add(recipientId);
                    }
                }
                
                // Merge group members into the main set (Set handles duplicates)
                selectedPrimaryRecipientsSet.addAll(broadcastRecipientIds);
            }
            
            // Convert the merged Set back to a List for downstream processing/DML
            List<String> selectedPrimaryRecipients = new List<String>(selectedPrimaryRecipientsSet);

            // --- RECIPIENT COLLECTION END ---

            List<String> selectedCCRecipients = new List<String>();
            if (campaignEmailDataMap.containsKey('selectedCCRecipients')) {
                for (Object recipient : (List<Object>) campaignEmailDataMap.get('selectedCCRecipients')) {
                    selectedCCRecipients.add((String) recipient);
                }
            }
            List<String> selectedBCCRecipients = new List<String>();
            if (campaignEmailDataMap.containsKey('selectedBCCRecipients')) {
                for (Object recipient : (List<Object>) campaignEmailDataMap.get('selectedBCCRecipients')) {
                    selectedBCCRecipients.add((String) recipient);
                }
            }

            String ccRecipients = String.join(selectedCCRecipients, '@@@');
            String bccRecipients = String.join(selectedBCCRecipients, '@@@');
            
            // Extract emails
            List<Object> emails = (List<Object>) campaignEmailDataMap.get('emails');
            Integer marketingEmailCount = emails != null ? emails.size() : 0;
            
            // Determine start date
            Date specificDate = null;
            
            if (campaignEmailDataMap.containsKey('specificDate') && String.valueOf(campaignEmailDataMap.get('specificDate')) != '') {
                specificDate = Date.valueOf((String) campaignEmailDataMap.get('specificDate'));
            }
            
            // Query contacts to validate emails and date fields
            String queryForFailedEmails = 'SELECT Id, Email';
            if (!String.isEmpty(selectedContactDateField)) {
                queryForFailedEmails += ', ' + selectedContactDateField;
            }
            String objectName = 'Contact';
            // This query now uses the merged selectedPrimaryRecipients list
            queryForFailedEmails += ' FROM ' + objectName + ' WHERE Id IN :selectedPrimaryRecipients';
            
            List<SObject> contlst = Database.query(String.escapeSingleQuotes(queryForFailedEmails), AccessLevel.USER_MODE);
            // Track valid contacts and dates
            Map<Id, String> conMap = new Map<Id, String>();
            Map<Id, Date> contactIdToDateMap = new Map<Id, Date>();
            Integer failedEmails = 0;
            
            for (SObject con1 : contlst) {
                SObject con;  // Declare con outside if-else
                
                if (con1 instanceof Contact) {
                    con = (Contact) con1;
                } else {
                    // If neither Contact, skip this iteration
                    continue;
                }

                String email = (String)con.get('Email');
                Id conId = (Id)con.get('Id');
                                                
                if (email == null) {
                    failedEmails += marketingEmailCount;
                    conMap.put(conId, null);
                    continue;
                }
                                                
                if (!Pattern.matches('^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$', email)) {
                            failedEmails += marketingEmailCount;
                            conMap.put(conId, null);
                            continue;
                }
                            
                if (!String.isEmpty(selectedContactDateField)) {
                    Object fieldObj = con.get(selectedContactDateField);
                    if (fieldObj == null) {
                        failedEmails += marketingEmailCount;
                        conMap.put(conId, email);
                        continue;
                    }
                    
                    Date fieldValue = (Date)fieldObj;
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
                }
            }
                        
            // Fetch existing campaign
            Marketing_Campaign__c campaign = [
                SELECT Id, Label__c, Is_Marketing_Campaign_Template__c, BCC_Contacts__c, CC_Contacts__c, 
                    Status__c, Start_Date__c, SelectedContactDateField__c, Marketing_Campaign_Template__c, 
                    Campaign_Start_Date__c, Total_Emails__c, Remaining_Emails__c, Failed_Emails__c, Schedule_Type__c,RelatedObject__c,
                    Selected_Broadcast_Groups__c 
                FROM Marketing_Campaign__c 
                WHERE Id = :campaignId WITH USER_MODE LIMIT 1
            ];
            
            // Update campaign fields
            campaign.Label__c = campaignName;
            campaign.Is_Marketing_Campaign_Template__c = saveForFuture;
            campaign.BCC_Contacts__c = bccRecipients;
            campaign.CC_Contacts__c = ccRecipients;
            campaign.Email_Type__c = emailType;
            campaign.Status__c = 'Pending';
            campaign.Schedule_Type__c = specificDate != null ? 'Specific Date' : 'Contact Field';
            campaign.RelatedObject__c = relatedObject;
            // ✨ FIX 1: Update the Primary_Recipient__c field with the merged list of contacts/group members
            campaign.Primary_Recipient__c = String.join(selectedPrimaryRecipients, '@@@');
            // FIX 2: Save the selected broadcast group IDs for UI reload
            campaign.Selected_Broadcast_Groups__c = !selectedBroadcastGroups.isEmpty() ? String.join(selectedBroadcastGroups, '@@@') : null;
            
            if (specificDate != null) {
                campaign.Start_Date__c = specificDate;
                campaign.Campaign_Start_Date__c = specificDate;
            } else if (!String.isEmpty(selectedContactDateField)) {
                campaign.SelectedContactDateField__c = selectedContactDateField;
                campaign.Campaign_Start_Date__c = null;
            }
            if (!String.isEmpty(templateId)) {
                campaign.Marketing_Campaign_Template__c = templateId;
            }
                            
            update as user campaign;
            
            // Handle Marketing_Campaign_Member__c
            List<Marketing_Campaign_Member__c> existingMembers = [
                SELECT Id, RecipientId__c , Contact_Type__c, Marketing_Campaign__c
                FROM Marketing_Campaign_Member__c
                WHERE Marketing_Campaign__c = :campaignId WITH USER_MODE
            ];
            Set<Id> existingContactIds = new Set<Id>();
            for (Marketing_Campaign_Member__c member : existingMembers) {
                existingContactIds.add(member.RecipientId__c);
            }

            List<Marketing_Campaign_Member__c> membersToDelete = new List<Marketing_Campaign_Member__c>();
            for (Marketing_Campaign_Member__c member : existingMembers) {
                // Only keep primary recipients in the member table for reporting
                if (!selectedPrimaryRecipients.contains(member.RecipientId__c)) {
                    membersToDelete.add(member);
                }
            }
            
            delete as user membersToDelete;
            
            List<Marketing_Campaign_Member__c> newMembers = new List<Marketing_Campaign_Member__c>();
            for (String contactId : selectedPrimaryRecipients) {
                if (!existingContactIds.contains(contactId)) {
                    newMembers.add(new Marketing_Campaign_Member__c(
                    RecipientId__c = contactId,
                    Contact_Type__c = 'Primary',
                    Marketing_Campaign__c = campaign.Id
                    ));
                }
            }
            insert as user newMembers;
            
            // Handle Marketing_Email__c
            List<Marketing_Email__c> existingEmails = [
                SELECT Id, Name, Marketing_Campaign__c, Subject__c, Template_Id__c, Listing__c, Template_Type__c,
                Days_After_Start_Date__c, TimeToSend__c, Send_Date_Time__c
                FROM Marketing_Email__c
                WHERE Marketing_Campaign__c = :campaignId WITH USER_MODE
            ];
            Map<String, Marketing_Email__c> scheduleToEmailMap = new Map<String, Marketing_Email__c>();
            if (specificDate != null) {
                for (Marketing_Email__c email : existingEmails) {
                    String scheduleKey = email.Days_After_Start_Date__c + '-' + (email.TimeToSend__c != null ? String.valueOf(email.TimeToSend__c) : '');
                    scheduleToEmailMap.put(scheduleKey, email);
                }
            }
            
            Map<String, Marketing_Email__c> existingEmailMap = new Map<String, Marketing_Email__c>();
            for (Marketing_Email__c email : existingEmails) {
                existingEmailMap.put(email.Id, email);
            }
            
            List<Marketing_Email__c> emailRecordsToInsert = new List<Marketing_Email__c>();
            List<Marketing_Email__c> emailRecordsToUpdate = new List<Marketing_Email__c>();
            for (Object emailDataObj : emails) {
                Map<String, Object> emailData = (Map<String, Object>) emailDataObj;
                String emailId = String.valueOf(emailData.get('id'));
                String subject = String.valueOf(emailData.get('subject'));
                String name = String.valueOf(emailData.get('name'));
                String template = String.valueOf(emailData.get('template'));
                String templateType = String.valueOf(emailData.get('templateType'));
                Integer daysAfterStartDate = Integer.valueOf(emailData.get('daysAfterStartDate'));
                String timeString = (String) emailData.get('timeToSend');
                String selectedListingId = (String) emailData.get('selectedListingId');
                
                
                String scheduleKey = daysAfterStartDate + '-' + timeString;
                Marketing_Email__c emailCampaign;
                if (specificDate != null && scheduleToEmailMap.containsKey(scheduleKey)) {
                    emailCampaign = scheduleToEmailMap.get(scheduleKey);
                } else if (emailId != null && existingEmailMap.containsKey(emailId)) {
                    emailCampaign = new Marketing_Email__c(Id = emailId);
                } else {
                    emailCampaign = new Marketing_Email__c(Marketing_Campaign__c = campaign.Id);
                }
                
                emailCampaign.Subject__c = subject;
                emailCampaign.Name = name;
                emailCampaign.Template_Id__c = template;
                emailCampaign.Template_Type__c = String.valueOf(emailData.get('templateType'));
                emailCampaign.Days_After_Start_Date__c = daysAfterStartDate;
                                                
                if (selectedListingId != null && selectedListingId != '' && (selectedListingId.length() == 15 || selectedListingId.length() == 18)) {
                    emailCampaign.Listing__c = selectedListingId;
                } else {
                    emailCampaign.Listing__c = null;
                }

                if (!String.isEmpty(timeString)) {
                    List<String> timeParts = timeString.split(':');
                    if (timeParts.size() == 3) {
                        Integer hours = Integer.valueOf(timeParts[0]);
                        Integer minutes = Integer.valueOf(timeParts[1]);
                        Integer seconds = Integer.valueOf(timeParts[2]);
                        emailCampaign.TimeToSend__c = Time.newInstance(hours, minutes, seconds, 0);
                        if (specificDate != null) {
                            Date sendDate = specificDate.addDays(daysAfterStartDate);
                            emailCampaign.Send_Date_Time__c = DateTime.newInstance(sendDate, emailCampaign.TimeToSend__c);
                        }
                    }
                }
                
                if (specificDate != null && scheduleToEmailMap.containsKey(scheduleKey)) {
                    continue;
                } else if (emailId != null && existingEmailMap.containsKey(emailId)) {
                    Boolean isDisabled = Boolean.valueOf(emailData.get('disabled'));
                    if (!isDisabled || !String.isEmpty(selectedContactDateField)) {
                        emailRecordsToUpdate.add(emailCampaign);
                    }
                } else {
                    emailRecordsToInsert.add(emailCampaign);
                    if (specificDate != null) {
                        scheduleToEmailMap.put(scheduleKey, emailCampaign);
                    }
                }
            }

            if (!emailRecordsToInsert.isEmpty()) {
                insert as user emailRecordsToInsert;
            }
            if (!emailRecordsToUpdate.isEmpty()) {
                update as user emailRecordsToUpdate;
            }
            
            // Handle deleted emails
            List<Object> deletedEmails = (List<Object>) campaignEmailDataMap.get('deletedEmailList');
            Set<String> emailIdsToDelete = new Set<String>();
            for (Object emailId : deletedEmails) {
                if (String.valueOf(emailId).length() >= 15) {
                    emailIdsToDelete.add(String.valueOf(emailId));
                }
            }
            if (!emailIdsToDelete.isEmpty()) {
                List<Marketing_Email__c> emailsToDelete = [
                    SELECT Id FROM Marketing_Email__c 
                    WHERE Id IN :emailIdsToDelete WITH USER_MODE
                ];
                if (!emailsToDelete.isEmpty() && Schema.sObjectType.Marketing_Email__c.isDeletable()) {
                    delete as user emailsToDelete;
                }
            }
                        
            // Handle Email_Member__c with distinct schedules
            List<Email_Member__c> existingEmailMembers = [
                SELECT Id, RecipientId__c, Marketing_Email__c, Schedule_Date_and_Time__c, Status__c
                FROM Email_Member__c
                WHERE Marketing_Email__c IN (SELECT Id FROM Marketing_Email__c WHERE Marketing_Campaign__c = :campaignId) 
                AND IsDeleted = false
                WITH USER_MODE
            ];

            // Create a map to track existing Email_Member__c records by a composite key
            Map<String, Email_Member__c> existingEmailMemberMap = new Map<String, Email_Member__c>();
            for (Email_Member__c em : existingEmailMembers) {
                String key = em.Marketing_Email__c + '-' + em.RecipientId__c;
                existingEmailMemberMap.put(key, em);
            }

            List<Email_Member__c> emailMembersToInsert = new List<Email_Member__c>();
            List<Email_Member__c> emailMembersToUpdate = new List<Email_Member__c>();
            List<Email_Member__c> emailMembersToDelete = new List<Email_Member__c>();

            // Identify Email_Member__c records to delete
            for (Email_Member__c em : existingEmailMembers) {
                if (!selectedPrimaryRecipients.contains(em.RecipientId__c)) {
                    emailMembersToDelete.add(em);
                }
            }

            // Deduplicate allEmails to avoid processing the same Marketing_Email__c multiple times
            Set<Id> uniqueEmailIds = new Set<Id>();
            List<Marketing_Email__c> allEmails = new List<Marketing_Email__c>();
            // Exclude deleted email IDs
            Set<String> deletedEmailIds = new Set<String>();
            for (Object emailId : deletedEmails) {
                if (String.valueOf(emailId).length() >= 15) {
                    deletedEmailIds.add(String.valueOf(emailId));
                }
            }
            for (Marketing_Email__c email : existingEmails) {
                if (!deletedEmailIds.contains(email.Id)) {
                    uniqueEmailIds.add(email.Id);
                    allEmails.add(email);
                }
            }
            for (Marketing_Email__c email : emailRecordsToInsert) {
                if (!uniqueEmailIds.contains(email.Id) && !deletedEmailIds.contains(email.Id)) {
                    uniqueEmailIds.add(email.Id);
                    allEmails.add(email);
                }
            }
            for (Marketing_Email__c email : scheduleToEmailMap.values()) {
                if (!uniqueEmailIds.contains(email.Id) && !deletedEmailIds.contains(email.Id)) {
                    uniqueEmailIds.add(email.Id);
                    allEmails.add(email);
                }
            }

            String scheduleType = specificDate != null ? 'Specific Date' : 'Contact Field';

            // Track processed Email_Member__c records to avoid duplicates
            Set<String> processedEmailMemberKeys = new Set<String>();

            for (String contactId : selectedPrimaryRecipients) {
                if (!conMap.containsKey(contactId) || conMap.get(contactId) == null) {
                    failedEmails += allEmails.size();
                    for (Marketing_Email__c email : allEmails) {
                        String compositeKey = email.Id + '-' + contactId;
                        if (!processedEmailMemberKeys.contains(compositeKey) && !existingEmailMemberMap.containsKey(compositeKey)) {
                            Email_Member__c emailMember = new Email_Member__c(
                                RecipientId__c = contactId,
                                Marketing_Email__c = email.Id,
                                Schedule_Date_and_Time__c = null,
                                Status__c = 'Failed'
                            );
                            emailMembersToInsert.add(emailMember);
                            processedEmailMemberKeys.add(compositeKey);
                        }
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
                    failedEmails += allEmails.size();
                    for (Marketing_Email__c email : allEmails) {
                        String compositeKey = email.Id + '-' + contactId;
                        if (!processedEmailMemberKeys.contains(compositeKey) && !existingEmailMemberMap.containsKey(compositeKey)) {
                            Email_Member__c emailMember = new Email_Member__c(
                                RecipientId__c = contactId,
                                Marketing_Email__c = email.Id,
                                Schedule_Date_and_Time__c = null,
                                Status__c = 'Failed'
                            );
                            emailMembersToInsert.add(emailMember);
                            processedEmailMemberKeys.add(compositeKey);
                        }
                    }
                    continue;
                }

                for (Marketing_Email__c email : allEmails) {
                    if (email.TimeToSend__c == null) {
                        failedEmails++;
                        String compositeKey = email.Id + '-' + contactId;
                        if (!processedEmailMemberKeys.contains(compositeKey) && !existingEmailMemberMap.containsKey(compositeKey)) {
                            Email_Member__c emailMember = new Email_Member__c(
                                RecipientId__c = contactId,
                                Marketing_Email__c = email.Id,
                                Schedule_Date_and_Time__c = null,
                                Status__c = 'Failed'
                            );
                            emailMembersToInsert.add(emailMember);
                            processedEmailMemberKeys.add(compositeKey);
                        }
                        continue;
                    }

                    Date sendDate = scheduleBaseDate.addDays(email.Days_After_Start_Date__c != null ? email.Days_After_Start_Date__c.intValue() : 0);
                    DateTime scheduleDateTime = DateTime.newInstance(sendDate, email.TimeToSend__c);
                    String compositeKey = email.Id + '-' + contactId;
                    Email_Member__c existingMember = existingEmailMemberMap.get(compositeKey);
                    if (scheduleDateTime <= System.now()) {
                        if (existingMember == null || (existingMember.Status__c != 'Success' && existingMember.Status__c != 'Pending')) {
                            failedEmails++;
                            if (!processedEmailMemberKeys.contains(compositeKey) && !existingEmailMemberMap.containsKey(compositeKey)) {
                                Email_Member__c emailMember = new Email_Member__c(
                                    RecipientId__c = contactId,
                                    Marketing_Email__c = email.Id,
                                    Schedule_Date_and_Time__c = null,
                                    Status__c = 'Failed'
                                );
                                emailMembersToInsert.add(emailMember);
                                processedEmailMemberKeys.add(compositeKey);
                            }
                        }
                        continue;
                    }

                    if (existingMember != null) {
                        if (existingMember.Schedule_Date_and_Time__c != scheduleDateTime || existingMember.Status__c != 'Pending') {
                            existingMember.Schedule_Date_and_Time__c = scheduleDateTime;
                            existingMember.Status__c = 'Pending';
                            emailMembersToUpdate.add(existingMember);
                        }
                    } else {
                        if (!processedEmailMemberKeys.contains(compositeKey)) {
                            Email_Member__c emailMember = new Email_Member__c(
                                RecipientId__c = contactId,
                                Marketing_Email__c = email.Id,
                                Schedule_Date_and_Time__c = scheduleDateTime,
                                Status__c = 'Pending'
                            );
                            emailMembersToInsert.add(emailMember);
                            processedEmailMemberKeys.add(compositeKey);
                        }
                    }
                }
            }

            if (!emailMembersToDelete.isEmpty()) {
                delete as user emailMembersToDelete;
            }
            if (!emailMembersToInsert.isEmpty()) {
                insert as user emailMembersToInsert;
            }
            if (!emailMembersToUpdate.isEmpty()) {
                update as user emailMembersToUpdate;
            }
                        
            // Recalculate campaign counts
            recalculateCampaignCounts(campaignId);
            
            return campaign.Id;
        } catch (Exception e) {
            System.debug('Error in updateCampaignAndEmails: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            ErrorHandler.insertErrordata(e, 'EmailCampaignController', 'updateCampaignAndEmails', 'Error while updating campaign records.');
            return null;
        }
    }
                    
                    
    /**
     * Method Name : recalculateCampaignCounts
     * modified By : Yash Parekh
     * modified Date : 25/05/2025
     * Date : 06/05/2025
     * @description : Recalculates campaign counts based on Email_Member__c records
     */
    public static void recalculateCampaignCounts(Id campaignId) {
        try {
            Marketing_Campaign__c campaign = [
                SELECT Id, Total_Emails__c, Remaining_Emails__c, Failed_Emails__c, Total_Sent_Mails__c, Status__c
                FROM Marketing_Campaign__c
                WHERE Id = :campaignId WITH USER_MODE
                LIMIT 1
            ];
            List<Email_Member__c> emailMembers = [
                SELECT Id, Status__c, Schedule_Date_and_Time__c, Marketing_Email__r.Marketing_Campaign__c
                FROM Email_Member__c
                WHERE Marketing_Email__r.Marketing_Campaign__c = :campaignId
                WITH USER_MODE
            ];


            Integer totalEmails = 0;
            Integer remainingEmails = 0;
            Integer failedEmails = 0;
            Integer sentEmails = 0;

            for (Email_Member__c em : emailMembers) {
                totalEmails++;
                if (em.Status__c == 'Pending' && em.Schedule_Date_and_Time__c != null && em.Schedule_Date_and_Time__c > System.now()) {
                    remainingEmails++;
                } else if (em.Status__c != null && em.Status__c.contains('Failed')) {
                    failedEmails++;
                } else if (em.Status__c == 'Success') {
                    sentEmails++;
                }
            }

            campaign.Total_Emails__c = totalEmails;
            campaign.Remaining_Emails__c = remainingEmails;
            campaign.Failed_Emails__c = failedEmails;
            campaign.Total_Sent_Mails__c = sentEmails;
            campaign.Status__c = totalEmails == 0 ? 'Pending' : 
                                (remainingEmails == 0 && failedEmails == 0 && sentEmails > 0 ? 'Completed' : 
                                (sentEmails > 0 ? 'In Progress' : 'Pending'));


            update as user campaign;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'EmailCampaignController', 'recalculateCampaignCounts', 'Error recalculating campaign counts for campaignId: ' + campaignId);
        }
    }
                    
                    
    /**
     * Method Name : checkContactDateFields
     * Date : 23/07/2024
     * Created By : Rachit Shah
     * @description : Used for getting contact date fields dynamically
     */
    @AuraEnabled
    public static Map<String, String> checkContactDateFields(String contactsJson, String selectedContactDateField) {
        try {
            List<Object> selectedPrimaryRecipientsUntyped = (List<Object>) JSON.deserializeUntyped(contactsJson);
            List<Map<String, Object>> selectedPrimaryRecipients = new List<Map<String, Object>>();
            
            for (Object obj : selectedPrimaryRecipientsUntyped) {
                selectedPrimaryRecipients.add((Map<String, Object>) obj);
            }
            
            Set<String> contactIds = new Set<String>();
            for (Map<String, Object> contact : selectedPrimaryRecipients) {
                contactIds.add((String) contact.get('value'));
            }
            
            String selectedcontactFieldData = String.escapeSingleQuotes(selectedContactDateField);
            String fieldValueQuery = 'SELECT Id, ' + selectedcontactFieldData + ' FROM Contact WHERE Id IN :contactIds';
            List<Contact> contacts = Database.query(fieldValueQuery, AccessLevel.USER_MODE);
            Map<String, String> idToFieldValueMap = new Map<String, String>();
            for (Contact con : contacts) {
                idToFieldValueMap.put(con.Id, String.valueOf(con.get(selectedContactDateField)));
            }
            
            return idToFieldValueMap;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'EmailCampaignController', 'checkContactDateFields', 'Error while chech contact fields.');
            return null;
        }
    }
                    
                    
    @AuraEnabled
    public static List<CampaignMemberEmailInfo> getCampaignMemberEmails(String campaignId) {
        try {
            List<CampaignMemberEmailInfo> results = new List<CampaignMemberEmailInfo>();
            
            // Query Marketing_Campaign__c to get RelatedObject__c
            Marketing_Campaign__c campaign = [
                SELECT Id, RelatedObject__c
                FROM Marketing_Campaign__c
                WHERE Id = :campaignId
                WITH USER_MODE
                LIMIT 1
            ];
            String relatedObject = campaign.RelatedObject__c;

            // Determine which objects to query based on RelatedObject__c
            Set<String> recipientIds = new Set<String>();
            List<Marketing_Campaign_Member__c> campaignMembers = [
                SELECT RecipientId__c
                FROM Marketing_Campaign_Member__c
                WHERE Marketing_Campaign__c = :campaignId
                WITH USER_MODE
            ];
            for (Marketing_Campaign_Member__c member : campaignMembers) {
                recipientIds.add(member.RecipientId__c);
            }

            // Query Contacts based on RelatedObject__c
            Map<Id, SObject> recipients = new Map<Id, SObject>();
            if (relatedObject == 'Contact') {
                List<Contact> contacts = [
                    SELECT Id, Name, Email
                    FROM Contact
                    WHERE Id IN :recipientIds
                    WITH USER_MODE
                ];
                for (Contact con : contacts) {
                    recipients.put(con.Id, con);
                }
            }

            // Query Marketing_Email__c IDs separately to avoid semi-join sub-select
            Set<Id> marketingEmailIds = new Set<Id>();
            List<Marketing_Email__c> campaignEmails = [
                SELECT Id, Name
                FROM Marketing_Email__c
                WHERE Marketing_Campaign__c = :campaignId
                WITH USER_MODE
            ];
            for (Marketing_Email__c email : campaignEmails) {
                marketingEmailIds.add(email.Id);
            }

            // Query Email_Member__c records
            List<Email_Member__c> emailMembers = [
                SELECT RecipientId__c, Schedule_Date_and_Time__c, Marketing_Email__r.Name, Status__c
                FROM Email_Member__c
                WHERE RecipientId__c IN :recipientIds
                AND Marketing_Email__c IN :marketingEmailIds
                WITH USER_MODE
                ORDER BY RecipientId__c, Schedule_Date_and_Time__c
            ];
            Map<String, Email_Member__c> emailMemberMap = new Map<String, Email_Member__c>();
            for (Email_Member__c em : emailMembers) {
                String key = em.RecipientId__c + '-' + em.Marketing_Email__r.Name;
                emailMemberMap.put(key, em);
            }

            // Process results
            for (SObject recipient : recipients.values()) {
                String recipientId = recipient.Id;
                String recipientName = (String)recipient.get('Name');
                String recipientEmail = (String)recipient.get('Email');
                
                for (Marketing_Email__c email : campaignEmails) {
                    String key = recipientId + '-' + email.Name;
                    Email_Member__c em = emailMemberMap.get(key);
                    String status;
                    if (recipientEmail == null) {
                        status = 'Failed (No Email)';
                    }else if (em == null) {
                        status = 'Failed (No Schedule)';
                    }else if (em.Schedule_Date_and_Time__c == null) {
                        status = 'Failed (Invalid Schedule)';
                    }else if (em.Status__c == 'Success'){
                        status = 'Success';
                    }else if (em.Schedule_Date_and_Time__c > System.now().addMinutes(-5)) {
                        status = 'Pending';
                    } else {
                        status = 'Failed (Not Sent)';
                    }
                    results.add(new CampaignMemberEmailInfo(
                        recipientName,
                        recipientEmail,
                        email.Name,
                        em != null ? em.Schedule_Date_and_Time__c : null,
                        status
                    ));
                }
            }
            return results;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to fetch campaign member emails: ' + e.getMessage());
        }
    }
                    
    public class CampaignMemberEmailInfo {
        @AuraEnabled public String contactName;
        @AuraEnabled public String contactEmail;
        @AuraEnabled public String emailName;
        @AuraEnabled public DateTime sendTime;
        @AuraEnabled public String status;
        
        public CampaignMemberEmailInfo(String contactName, String contactEmail, String emailName, DateTime sendTime, String status) {
            this.contactName = contactName;
            this.contactEmail = contactEmail;
            this.emailName = emailName;
            this.sendTime = sendTime;
            this.status = status;
        }
    }
    
    /**
     * Method Name : getCamapaignAndRelatedData
     * Date : 23/07/2024
     * Created By : Rachit Shah
     * @description : Used for getting camapign and related email data
     */
    @AuraEnabled
    public static String getCamapaignAndRelatedData(String campaignId) {
        try {
            Marketing_Campaign__c campaign = [
            SELECT Id, Label__c, Sender_Mode__c, From_Address__c, From_Name__c, 
            Is_Marketing_Campaign_Template__c, BCC_Contacts__c, CC_Contacts__c, RelatedObject__c,
            Status__c, Start_Date__c, SelectedContactDateField__c,Marketing_Campaign_Template__c , Total_Sent_Mails__c,Campaign_Start_Date__c,Email_Type__c,
            Selected_Broadcast_Groups__c
            FROM Marketing_Campaign__c 
            WHERE Id = :campaignId WITH USER_MODE LIMIT 50000
            ];
            
            List<Marketing_Campaign_Member__c> marketingCampaignMembers = [SELECT Id,RecipientId__c,Contact_Type__c,Marketing_Campaign__c FROM Marketing_Campaign_Member__c WHERE Marketing_Campaign__c = :campaignId WITH USER_MODE];
            
            List<Marketing_Email__c> emailRecords = [SELECT Id,Name,Marketing_Campaign__c,Subject__c,Template_Id__c,Days_After_Start_Date__c,TimeToSend__c,Send_Date_Time__c,Listing__c, Template_Type__c FROM Marketing_Email__c WHERE Marketing_Campaign__c = :campaignId WITH USER_MODE];
            
            CampaignData campaignData = new CampaignData();
            campaignData.id = campaign.Id;
            campaignData.label = campaign.Label__c;
            campaignData.senderMode = campaign.Sender_Mode__c;
            campaignData.fromAddress = campaign.From_Address__c;
            campaignData.fromName = campaign.From_Name__c;
            campaignData.isMarketingCampaignTemplate = campaign.Is_Marketing_Campaign_Template__c;
            campaignData.bCCContacts = campaign.BCC_Contacts__c;
            campaignData.cCContacts = campaign.CC_Contacts__c;
            campaignData.status = campaign.Status__c;
            campaignData.startDate = campaign.Start_Date__c;
            campaignData.selectedContactDateField = campaign.SelectedContactDateField__c;
            campaignData.marketingCampaignMembers = marketingCampaignMembers;
            campaignData.emailRecords = emailRecords;
            campaignData.templateId = campaign.Marketing_Campaign_Template__c;
            campaignData.emailType = campaign.Email_Type__c;
            campaignData.relatedObject = campaign.RelatedObject__c;
            // ✨ ADDED: Assign the new field's value
            campaignData.selectedBroadcastGroups = campaign.Selected_Broadcast_Groups__c;
            
            String campaignJson = JSON.serialize(campaignData);
            
            return campaignJson;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'EmailCampaignController', 'getCamapaignAndRelatedData', 'Error while getting get  camapign and data');
            return null;
        }
    }
    
    /**
     * Method Name : getCampaigns
     * Date : 23/07/2024
     * Created By : Rachit Shah
     * @description : Used for getting campaign data
     */
    @AuraEnabled
    public static List<Marketing_Campaign__c> getCampaigns(){
        
        List<Marketing_Campaign__c> campaigns = new List<Marketing_Campaign__c>();
        
        try {
            campaigns = [SELECT Id, Name, Label__c, Start_Date__c , CreatedDate ,Failed_Emails__c, Status__c,Marketing_Campaign_Template__c,Is_Marketing_Campaign_Template__c,Remaining_Emails__c,Total_Emails__c,Campaign_Start_Date__c,Total_Sent_Mails__c,Schedule_Type__c	 FROM Marketing_Campaign__c WITH USER_MODE ORDER BY LastModifiedDate DESC LIMIT 50000];
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'EmailCampaignController', 'getCampaigns', 'Error while getting campaigns.');
        }
        
        return campaigns;
    }
                    
    /**
     * Method Name : deleteCampaign
     * Date : 23/07/2024
     * Created By : Rachit Shah
     * @description : Used for deleting camapign record
     */
    @AuraEnabled
    public static void deleteCampaign(Id campaignId) {
        try {
            Marketing_Campaign__c campaignToDelete = [SELECT Id FROM Marketing_Campaign__c WHERE Id = :campaignId WITH USER_MODE LIMIT 1];
            
            if(campaignToDelete != null) {
                delete as user campaignToDelete;
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'EmailCampaignController', 'deleteCampaign', 'Error while deleting camaoign');
        }
    }
                    
    /**
     * Method Name : sendEmails
     * Date : 23/07/2024
     * Created By : Rachit Shah
     * @description : Used for sending email from flow
     */
    @InvocableMethod(label='Send Emails (Specific Date)' description='Send emails to primary, cc, and bcc recipients for specific date campaigns')
    public static void sendEmails(List<EmailRequests> emailRequests) {
        try {
   
            System.debug('email request==> '+ emailRequests);
            System.debug('template body ==> '+ emailRequests[0].body);

            Map<String, Map<String, String>> contactEmailInfoMap = new Map<String, Map<String, String>>();
            Map<Id, String> templateBodyMap = new Map<Id, String>();
            List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

            List<GmailIntegrationControllerV1.EmailWrapper> gmails = new List<GmailIntegrationControllerV1.EmailWrapper>();
            List<OutlookIntegrationController.EmailWrapper> outlookMails = new List<OutlookIntegrationController.EmailWrapper>();
            Set<String> campaignIds = new Set<String>();
            Set<String> recipientIds = new Set<String>();

            String processedBody = ''; 

            // Track processed Email_Member__c IDs to avoid duplicates
            Set<String> processedKeys = new Set<String>();

            for (EmailRequests req : emailRequests) {
                if (req.toAddresses != null) {
                    recipientIds.addAll(req.toAddresses);
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
            for (EmailRequests req : emailRequests) {
                List<String> emailAddresses = new List<String>();
                for (String recipientId : req.toAddresses) {

                    SObject rec = idToRecipientMap.get(recipientId);
                    if (rec != null) {
                        String email = (String)rec.get('Email');
                        if (email != null) {
                            emailAddresses.add(email);
                            emailToRecipientIdMap.put(email, recipientId);
                        }
                    }
                }
                req.toAddresses = emailAddresses;
            }

            // Collect campaign IDs and template IDs, and map email addresses to recipient IDs
            for (EmailRequests req : emailRequests) {
                campaignIds.add(req.campaignId);
                templateIds.add(req.templateDataId);
                if (req.listingId != null && req.RelatedObjectName == 'MVEX__Listing__c') {
                    listingIds.add(req.listingId);
                }

                for (String toAddress : req.toAddresses) {
                    if (toAddress != null) {
                        emailToRecipientIdMap.put(toAddress, null);
                    }
                }
            }
            
            Map<String, Marketing_Campaign__c> campaignMap = new Map<String, Marketing_Campaign__c>();
            Map<String, List<Id>> campaignToRecipientMap = new Map<String, List<Id>>();
            Map<String, Set<Id>> campaignToEmailIdsMap = new Map<String, Set<Id>>();


            if (!campaignIds.isEmpty()) {
                List<Marketing_Campaign__c> campaigns = [
                    SELECT 
                        Id, Name, Status__c, Remaining_Emails__c, Total_Sent_Mails__c, 
                        Email_Type__c, Schedule_Type__c, RelatedObject__c,
                        (SELECT Id, RecipientId__c FROM Marketing_Campaign_Members__r),
                        (SELECT Id, Listing__c FROM Marketing_Emails__r)
                    FROM Marketing_Campaign__c 
                    WHERE Id IN :campaignIds
                    WITH USER_MODE
                ];
            
                for (Marketing_Campaign__c campaign : campaigns) {
                    campaignMap.put(campaign.Id, campaign);
                    remainingEmailsMap.put(campaign.Id, Integer.valueOf(campaign.Remaining_Emails__c));
            
                    // Process campaign members
                    List<Id> recipientListPerCampaign = new List<Id>();
                    for (Marketing_Campaign_Member__c member : campaign.Marketing_Campaign_Members__r) {
                        recipientListPerCampaign.add(member.RecipientId__c);
                        recipientIds.add(member.RecipientId__c);
                    }
                    campaignToRecipientMap.put(campaign.Id, recipientListPerCampaign);
            
                    // Process emails
                    Set<Id> emailIdsPerCampaign = new Set<Id>();
                    for (Marketing_Email__c email : campaign.Marketing_Emails__r) {
                        emailIdsPerCampaign.add(email.Id);
                    }
                    campaignToEmailIdsMap.put(campaign.Id, emailIdsPerCampaign);
                }
            }
            
            // Determine which objects to query based on RelatedObject__c
            Map<String, Set<Id>> objectToIdsMap = new Map<String, Set<Id>>{
                'Contact' => new Set<Id>()
            };
            for (String campaignId : campaignMap.keySet()) {
                String relatedObject = campaignMap.get(campaignId).RelatedObject__c;
                List<Id> recipientIdsForCampaign = campaignToRecipientMap.get(campaignId);
                if (recipientIdsForCampaign != null) {
                    if (relatedObject == 'Contact') {
                        objectToIdsMap.get('Contact').addAll(recipientIdsForCampaign);
                    }
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
            
            // Query Email_Member__c records to update status later
            Map<String, Email_Member__c> emailMembersToUpdate = new Map<String, Email_Member__c>();
            if (!campaignIds.isEmpty() && !recipientIds.isEmpty()) {
                List<Email_Member__c> emailMembers = [
                    SELECT Id, RecipientId__c, Marketing_Email__c, Status__c 
                    FROM Email_Member__c
                    WHERE RecipientId__c IN :recipientIds 
                    AND Marketing_Email__c IN (SELECT Id FROM Marketing_Email__c WHERE Marketing_Campaign__c IN :campaignIds)
                    AND Status__c = 'Pending'
                    WITH USER_MODE
                ];
                for (Email_Member__c em : emailMembers) {
                    String key = em.RecipientId__c + '-' + em.Marketing_Email__c;
                    emailMembersToUpdate.put(key, em);
                }
            }

            if (emailRequests[0].templateType == 'EmailTemplate') {
                System.debug('Processing EmailTemplate type emails: ' + emailRequests);
            
                Map<String, Set<String>> globalFieldMap = new Map<String, Set<String>>();
            
                // 1. Query templates
                List<EmailTemplate> templates = [
                    SELECT Id, HtmlValue, Body
                    FROM EmailTemplate
                    WHERE Id IN :templateIds
                    WITH USER_MODE
                ];
            
                // 2. Extract referenced object + fields
                for (EmailTemplate template : templates) {
                    String body = String.isNotBlank(template.HtmlValue) ? template.HtmlValue : template.Body;
                    if (body == null) continue;
            
                    Pattern pattern = Pattern.compile('\\{!([a-zA-Z0-9_]+)\\.([a-zA-Z0-9_.]+)\\}');
                    Matcher matcher = pattern.matcher(body);
            
                    while (matcher.find()) {
                        String objectName = matcher.group(1); 
                        String fieldPath = matcher.group(2);   // e.g., Owner.FullName
            
                        if (!globalFieldMap.containsKey(objectName)) {
                            globalFieldMap.put(objectName, new Set<String>());
                        }
                        globalFieldMap.get(objectName).add(fieldPath);
                    }
                }
            
                // 3. Build SOQL queries for each object
                Map<String, String> objectToQueryMap = new Map<String, String>();
                for (String objectName : globalFieldMap.keySet()) {
                    Set<String> fieldPaths = globalFieldMap.get(objectName);
                    String fieldListStr = String.join(new List<String>(fieldPaths), ',');
                    String soql = 'SELECT ' + fieldListStr + ' FROM ' + objectName;
                    objectToQueryMap.put(objectName, soql);
                }
            
                // 4. Build and Execute a single Composite Request
                Map<String, List<SObject>> objectToRecords = new Map<String, List<SObject>>();

                // The referenceId is used to link the request to its result.
                Integer counter = 0; 
                List<Map<String, Object>> compositeRequests = new List<Map<String, Object>>();

                // Build the list of sub-requests
                for (String objectName : objectToQueryMap.keySet()) {
                    String soql = objectToQueryMap.get(objectName);

                    Map<String, Object> subRequest = new Map<String, Object>();
                    subRequest.put('method', 'GET');
                    // The referenceId must be unique within the call
                    subRequest.put('referenceId', objectName + '_' + counter); 
                    // The URL for a SOQL query
                    subRequest.put('url', '/services/data/v58.0/query?q=' + EncodingUtil.urlEncode(soql, 'UTF-8'));
                    
                    compositeRequests.add(subRequest);
                    counter++;
                }

                String sessionId = Page.UserSessionIdPage.getContent().toString();

                // Create the main composite request body
                Map<String, Object> compositeBody = new Map<String, Object>();
                compositeBody.put('allOrNone', false); // false = process all requests even if one fails
                compositeBody.put('compositeRequest', compositeRequests);

                // 5. Make a single callout 🚀
                HttpRequest req = new HttpRequest();
                req.setEndpoint(URL.getOrgDomainUrl().toExternalForm() + '/services/data/v58.0/composite');
                req.setMethod('POST');
                req.setHeader('Content-Type', 'application/json');
                // Sets the session ID for authentication
                req.setHeader('Authorization', 'Bearer ' + sessionId); 
                req.setBody(JSON.serialize(compositeBody));

                Http http = new Http();
                HttpResponse res = http.send(req);

                // 6. Parse the response
                if (res.getStatusCode() == 200) {
                    Map<String, Object> results = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                    List<Object> compositeResponses = (List<Object>) results.get('compositeResponse');

                    for (Object subResponseObj : compositeResponses) {
                        Map<String, Object> subResponse = (Map<String, Object>) subResponseObj;
                        String referenceId = (String) subResponse.get('referenceId');
                        String objectName = referenceId.split('_')[0];

                        if ((Integer) subResponse.get('httpStatusCode') == 200) {
                            Map<String, Object> body = (Map<String, Object>) subResponse.get('body');
                            List<SObject> records = (List<SObject>) JSON.deserialize(JSON.serialize(body.get('records')), List<SObject>.class);
                            objectToRecords.put(objectName, records);
                        } else {
                            System.debug('⚠️ Failed query for ' + objectName + ': ' + subResponse.get('body'));
                        }
                    }
                } else {
                    System.debug('Composite API call failed: ' + res.getBody());
                }

                // Now the objectToRecords map is populated, just like in your original code.
                System.debug(objectToRecords);


                for (EmailRequests request : emailRequests) {
                    processedBody = request.body;

                    for (String toAddress : request.toAddresses) {

                        Marketing_Campaign__c campaignRecord = campaignMap.get(request.campaignId);
                        if (campaignRecord.Schedule_Type__c != 'Specific Date') {
                            continue; // Skip if not specific date
                        }

                        String emailType = campaignRecord.Email_Type__c;
                        
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
                        if (matchedKey == null) continue;
                        processedKeys.add(matchedKey);

                        String body = getTemplateBodyById(request.templateDataId, templates); // Utility to get template body

                        System.debug('Processing email for recipient: ' + toAddress + ', body: ' + body);
                        System.debug('Object to Records Map: ' + objectToRecords);
                        processedBody = replaceMergeFields(body, objectToRecords);

                        System.debug('Processed Body: ' + processedBody);

                        if (emailType == 'single') {
                            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                            String replyToEmail = Label.EmailMessageEmailService;
                            if (replyToEmail != null) {
                                email.setReplyTo(replyToEmail);
                            }
                            email.setToAddresses(new List<String>{toAddress});
                            if (request.ccAddresses != null) {
                                List<String> ccEmails = parseEmailAddresses(request.ccAddresses);
                                email.setCcAddresses(ccEmails);

                                System.debug('CC Emails: ' + ccEmails);
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
                    } else if (emailType == 'outlook') {
                        OutlookIntegrationController.EmailWrapper singleOutlookMail = new OutlookIntegrationController.EmailWrapper();
                        singleOutlookMail.toAddresses = new List<String>{toAddress};
                        if (request.ccAddresses != null) {
                            List<String> ccEmails = parseEmailAddresses(request.ccAddresses);
                            singleOutlookMail.ccAddresses = ccEmails;
                        }
                        if (request.bccContacts != null) {
                            List<String> bccEmails = parseEmailAddresses(request.bccContacts);
                            singleOutlookMail.bccAddresses = bccEmails;
                        }
                        singleOutlookMail.subject = request.subject;
                        singleOutlookMail.body = processedBody;
                        if (singleOutlookMail.contactEmailInfoMap == null) {
                            singleOutlookMail.contactEmailInfoMap = new Map<String, Map<String, String>>();
                        }
                        singleOutlookMail.contactEmailInfoMap.put(recipient.Id, new Map<String, String>{
                            'subject' => request.subject,
                            'body' => processedBody,
                            'email' => toAddress,
                            'cc' => request.ccAddresses,
                            'bcc' => request.bccContacts
                        });
                        outlookMails.add(singleOutlookMail);
                    }
                    
                    if (remainingEmailsMap.containsKey(request.campaignId) && remainingEmailsMap.get(request.campaignId) > 0) {
                        remainingEmailsMap.put(request.campaignId, remainingEmailsMap.get(request.campaignId) - 1);
                    }
                        
                    }
                    
                }
            
            }                    
            else if(emailRequests[0].templateType == 'EstateXpertTemplate') {
                
                List<Template__c> temps = [
                    SELECT Id, Name, Object_API_Name__c, Template_Name__c, Template_pattern__c, Template_Status__c, Description__c, CreatedDate, LastModifiedDate,
                        (SELECT Id, Name, Template_Value_Simple__c FROM Template_Data__r WHERE Value_Type__c = 'Extracted Mapping Keys' ORDER BY Order_No_Simple__c ASC)
                    FROM Template__c 
                    WHERE Id IN :templateIds WITH USER_MODE
                ];                    
                
                Set<Id> recipientObjectIds = new Set<Id>();
                for (EmailRequests request : emailRequests) {
                    for (String toAddress : request.toAddresses) {
                        SObject recipient = emailToRecipientMap.get(toAddress);
                        if (recipient != null) {
                            recipientObjectIds.add(recipient.Id);
                        }
                    }
                }

                Map<Id, Id> listingIdToPropertyId = new Map<Id, Id>();
                Map<String, Map<String, String>> listingImages = new Map<String, Map<String, String>>();

                for (Listing__c listing : [
                    SELECT Id, Property__c 
                    FROM Listing__c 
                    WHERE Id IN :listingIds
                    WITH USER_MODE
                ]) {
                    listingIdToPropertyId.put(listing.Id, listing.Property__c);
                }
        
                // Step 2: Get all Property_File__c records in a single query
                Map<Id, List<Property_File__c>> propertyIdToFiles = new Map<Id, List<Property_File__c>>();
                for (Property_File__c file : [
                    SELECT Id, BaseUrl__c, Property__c 
                    FROM Property_File__c 
                    WHERE Property__c IN :listingIdToPropertyId.values() 
                    AND IsOnExpose__c = true 
                    AND Size__c != null 
                    WITH USER_MODE
                    ORDER BY Sort_on_Expose__c ASC NULLS LAST, Name ASC
                ]) {
                    if (!propertyIdToFiles.containsKey(file.Property__c)) {
                        propertyIdToFiles.put(file.Property__c, new List<Property_File__c>());
                    }
                    propertyIdToFiles.get(file.Property__c).add(file);
                }
        
                // Step 3: Build the result map
                for (Id listingId : listingIds) {
                    Map<String, String> imageMap = new Map<String, String>();
                    Id propertyId = listingIdToPropertyId.get(listingId);
        
                    if (propertyId != null && propertyIdToFiles.containsKey(propertyId)) {
                        List<Property_File__c> mediaList = propertyIdToFiles.get(propertyId);
                        for (Integer i = 0; i < mediaList.size(); i++) {
                            imageMap.put('listingMedia[' + (i + 1) + ']', mediaList[i].BaseUrl__c);
                        }
                    }
        
                    listingImages.put(listingId, imageMap);
                }
                
                for (EmailRequests request : emailRequests) {

                    Marketing_Campaign__c campaignRecord = campaignMap.get(request.campaignId);
                    if (campaignRecord.Schedule_Type__c != 'Specific Date') {
                        continue; // Skip if not specific date
                    }

                    String emailType = campaignRecord.Email_Type__c;
                    String relatedObject = campaignRecord.RelatedObject__c;
                    processedBody = request.body;
     
                    String extractedKeyString = '';
                    List<Template__c> fieldData = new List<Template__c>();
                    if (!temps.isEmpty() && request.templateDataId != null) {
                        for (Template__c tempData : temps) {
                            if (tempData.Id == request.templateDataId) {
                                fieldData.add(tempData);
                            }
                        }
                        if (!fieldData.isEmpty()) {
                            extractedKeyString += fieldData[0].Template_Data__r.size() > 0 ? fieldData[0].Template_Data__r[0].Template_Value_Simple__c : '';
                        }
                    }
                    extractedKeyString = extractedKeyString != '' ? extractedKeyString : 'null';
                    String sourceObjectAPI = temps[0].Object_API_Name__c;
                    Map<String, Object> extractedKeyMap = (Map<String, Object>) JSON.deserializeUntyped(extractedKeyString);            
                    
                    for (String toAddress : request.toAddresses) {
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
                        if (request.RelatedObjectName == 'MVEX__Listing__c') {
                            mappingKeys = DataMappingControllerV2.getMappingsKeyValues2(extractedKeyMap, request.RelatedObjectName, listingIds, true);
                        } 
                        
                        if(request.RelatedObjectName == 'Contact') {
                            Set<Id> idsToMap = new Set<Id>();
                            idsToMap.add(recipient.Id);
                            mappingKeys = DataMappingControllerV2.getMappingsKeyValues2(extractedKeyMap, request.RelatedObjectName, idsToMap, true);

                        }

                        System.debug('mappingKeys: ' + mappingKeys);

                        processedKeys.add(matchedKey);
                        if (recipient != null) {
                            Map<String, String> mappingKeyVsMappingValues = mappingKeys.get('objectNGeneral');
                            Map<String, String> salesforceImages = mappingKeys.get('salesforceImages');
                            for (String key : mappingKeyVsMappingValues.keySet()) {
                                String escapedKey = Pattern.quote(key);
                                processedBody = processedBody.replaceAll(escapedKey, mappingKeyVsMappingValues.get(key));
                            }
                            for (String src : salesforceImages.keySet()) {
                                String escapedSrc = Pattern.quote(src);
                                processedBody = processedBody.replaceAll(escapedSrc, salesforceImages.get(src));
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
                                String replyToEmail = Label.EmailMessageEmailService;
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
                        } else if (emailType == 'outlook') {
                            OutlookIntegrationController.EmailWrapper singleOutlookMail = new OutlookIntegrationController.EmailWrapper();
                            singleOutlookMail.toAddresses = new List<String>{toAddress};
                            if (request.ccAddresses != null) {
                                List<String> ccEmails = parseEmailAddresses(request.ccAddresses);
                                singleOutlookMail.ccAddresses = ccEmails;
                            }
                            if (request.bccContacts != null) {
                                List<String> bccEmails = parseEmailAddresses(request.bccContacts);
                                singleOutlookMail.bccAddresses = bccEmails;
                            }
                            singleOutlookMail.subject = request.subject;
                            singleOutlookMail.body = processedBody;
                            if (singleOutlookMail.contactEmailInfoMap == null) {
                                singleOutlookMail.contactEmailInfoMap = new Map<String, Map<String, String>>();
                            }
                            singleOutlookMail.contactEmailInfoMap.put(recipient.Id, new Map<String, String>{
                                'subject' => request.subject,
                                'body' => processedBody,
                                'email' => toAddress,
                                'cc' => request.ccAddresses,
                                'bcc' => request.bccContacts
                            });
                            outlookMails.add(singleOutlookMail);
                        }
                        
                        if (remainingEmailsMap.containsKey(request.campaignId) && remainingEmailsMap.get(request.campaignId) > 0) {
                            remainingEmailsMap.put(request.campaignId, remainingEmailsMap.get(request.campaignId) - 1);
                        }
                    }      
                }
            }
            else{
                System.debug('Unsupported template type: ' + emailRequests[0].templateType);
                return;
            }

            try {
                List<Email_Member__c> emailMembersToUpdateList = new List<Email_Member__c>();
                for (String key : processedKeys) {
                    if (emailMembersToUpdate.containsKey(key)) {
                        Email_Member__c em = emailMembersToUpdate.get(key);
                        em.Status__c = 'Success';
                        emailMembersToUpdateList.add(em);
                    }
                }
                
                if (!emailMembersToUpdateList.isEmpty()) {
                    update as user emailMembersToUpdateList;
                }
                
                if (!emails.isEmpty()) {
                    Messaging.sendEmail(emails);
                    // CreateActivityFromMail.createCaseEmailMessage(contactEmailInfoMap);
                    System.enqueueJob(new CampaignUpdateQueueable(remainingEmailsMap, campaignMap, emails.size(), 'Success', null));
                } else if (!gmails.isEmpty()) {
                    GmailIntegrationControllerV1.requestNewAccessToken(gmails, remainingEmailsMap, campaignMap, true);
                } else if (!outlookMails.isEmpty()) {
                    OutlookIntegrationController.requestNewAccessToken(outlookMails, remainingEmailsMap, campaignMap, true);
                }
                
                // Recalculate campaign counts for all affected campaigns
                for (String campaignId : campaignIds) {
                    if (campaignMap.get(campaignId).Schedule_Type__c == 'Specific Date') {
                        recalculateCampaignCounts(campaignId);
                    }
                }
            } catch (Exception e) {
                System.enqueueJob(new CampaignUpdateQueueable(remainingEmailsMap, campaignMap, emails.size(), 'Failed', e.getMessage()));
                
                // Update Email_Member__c status to 'Failed' for processed records
                List<Email_Member__c> emailMembersToUpdateList = new List<Email_Member__c>();
                for (String key : processedKeys) {
                    if (emailMembersToUpdate.containsKey(key)) {
                        Email_Member__c em = emailMembersToUpdate.get(key);
                        em.Status__c = 'Failed';
                        emailMembersToUpdateList.add(em);
                    }
                }
                if (!emailMembersToUpdateList.isEmpty()) {
                    update as user emailMembersToUpdateList;
                }
                
                // Recalculate campaign counts
                for (String campaignId : campaignIds) {
                    if (campaignMap.get(campaignId).Schedule_Type__c == 'Specific Date') {
                        recalculateCampaignCounts(campaignId);
                    }
                }
            }
            
        } catch (Exception e) {
            System.debug('Error in sendEmails: ' + e.getMessage() + ' Line Number' + e.getLineNumber());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            
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
                throw new AuraHandledException('No access to object: ' + objectName);
            }
            
            Map<String, Schema.SObjectField> fields = sObjectType.getDescribe().fields.getMap();
            for(String fieldName : fields.keySet()) {
                fieldNames.add(fieldName);
            }
            fieldNames.sort();
            
            return fieldNames;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'EmailCampaignController', 'getAllFieldNames', 'Error while getting Contacts');
            return null;
        }
    }

    private static String getTemplateBodyById(Id templateId, List<EmailTemplate> templates) {
        for (EmailTemplate t : templates) {
            if (t.Id == templateId) {
                return String.isNotBlank(t.HtmlValue) ? t.HtmlValue : t.Body;
            }
        }
        return null;
    }
    
    private static String replaceMergeFields(String body, Map<String, List<SObject>> objectToRecords) {
        if (String.isBlank(body)) return body;
    
        // Replace standard {!Object.Field} and date functions like {!DATETIMEVALUE(Object.Field)}
        Pattern pattern = Pattern.compile('\\{!((?:DATETIMEVALUE\\(|DATEVALUE\\()?[a-zA-Z0-9_]+\\.[a-zA-Z0-9_.]+\\)?)}');
        Matcher matcher = pattern.matcher(body);
    
        while (matcher.find()) {
            String fullMatch = matcher.group(0);
            String raw = matcher.group(1);
    
            Boolean isDatetime = raw.startsWith('DATETIMEVALUE(');
            Boolean isDate = raw.startsWith('DATEVALUE(');
            String cleanPath = raw.replace('DATETIMEVALUE(', '').replace('DATEVALUE(', '').replace(')', '');
    
            List<String> parts = cleanPath.split('\\.');
            if (parts.size() < 2) continue;
    
            String objectName = parts[0];
            String fieldPath = parts[1]; // Simplified – nested fields not handled yet
    
            List<SObject> records = objectToRecords.get(objectName);
            if (records == null || records.isEmpty()) continue;
    
            Object value = records[0].get(fieldPath);
            if (value == null) continue;
    
            String replacement;
            if (isDatetime && value instanceof Datetime) {
                replacement = ((Datetime) value).format();
            } else if (isDate && value instanceof Date) {
                replacement = ((Date) value).format();
            } else {
                replacement = String.valueOf(value);
            }
    
            body = body.replace(fullMatch, replacement);
        }
    
        return body;
    }            
    
    /**
     * Method Name : CampaignData
     * Date : 23/07/2024
     * modified date : 21/05/2025
     * Created By : Rachit Shah
     * modified by : Yash Parekh
     * @description : wrapper class for camapign data
     */
    public class CampaignData {
        public String id;
        public String label;
        public String senderMode;
        public String fromAddress;
        public String fromName;
        public Boolean isMarketingCampaignTemplate;
        public String bCCContacts;
        public String cCContacts;
        public String status;
        public Date startDate;
        public String templateName;
        public String selectedContactDateField;
        public String templateId;
        public List<Marketing_Campaign_Member__c> marketingCampaignMembers;
        public List<Marketing_Email__c> emailRecords;
        public String emailType;
        public String relatedObject;
        // ✨ ADDED: Field to store the selected broadcast groups (IDs separated by '@@@')
        public String selectedBroadcastGroups; 
    }
}