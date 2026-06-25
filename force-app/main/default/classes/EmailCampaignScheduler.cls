public with sharing class EmailCampaignScheduler {
    
    /**
     * Method Name: sendEmails
     * Date: 23/07/2024
     * Created By: Rachit Shah
     * @description: Sends emails to primary, cc, and bcc recipients, and updates Email_Member__c status to 'Success'.
     */
    @InvocableMethod(label='Contact Specific Send Email' description='Send emails to primary, cc, and bcc recipients for contact field-based campaigns')
    public static void sendEmails(List<EmailRequest> emailRequests) {
        try {
            Map<String, Map<String, String>> contactEmailInfoMap = new Map<String, Map<String, String>>();
            List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
            Set<String> campaignIds = new Set<String>();
            Set<String> contactIds = new Set<String>();
            Map<String, Email_Member__c> emailMembersToUpdate = new Map<String, Email_Member__c>();
            
            // Collect campaign and contact IDs
            for (EmailRequest req : emailRequests) {
                campaignIds.add(req.campaignId);
                contactIds.add(req.contactId);
            }
            
            Map<String, Marketing_Campaign__c> campaignMap = new Map<String, Marketing_Campaign__c>();
            if (!campaignIds.isEmpty()) {
                List<Marketing_Campaign__c> campaigns = [
                SELECT Id, Name, Remaining_Emails__c, Status__c, Total_Sent_Mails__c,
                       Email_Type__c, Schedule_Type__c, RelatedObject__c
                FROM Marketing_Campaign__c 
                WHERE Id IN :campaignIds WITH USER_MODE
            ];
                for (Marketing_Campaign__c campaign : campaigns) {
                    campaignMap.put(campaign.Id, campaign);
                }
            }
            
            Map<String, List<Id>> campaignToContactMap = new Map<String, List<Id>>();
            if (!campaignIds.isEmpty()) {
                List<Marketing_Campaign_Member__c> campaignMembers = [
                SELECT Id, Marketing_Campaign__c, Contact__c
                FROM Marketing_Campaign_Member__c
                WHERE Marketing_Campaign__c IN :campaignIds WITH USER_MODE
            ];
                for (Marketing_Campaign_Member__c member : campaignMembers) {
                    if (!campaignToContactMap.containsKey(member.Marketing_Campaign__c)) {
                        campaignToContactMap.put(member.Marketing_Campaign__c, new List<Id>());
                    }
                    campaignToContactMap.get(member.Marketing_Campaign__c).add(member.Contact__c);
                    contactIds.add(member.Contact__c);
                }
            }
            
            Map<String, Contact> contactMap = new Map<String, Contact>();
            if (!contactIds.isEmpty()) {
                List<Contact> contacts = getContacts(contactIds);
                for (Contact contact : contacts) {
                    contactMap.put(contact.Id, contact);
                }
            }
            
            // Query Email_Member__c records to update status
            Map<String, Set<Id>> campaignToEmailIdsMap = new Map<String, Set<Id>>();
            List<Marketing_Email__c> marketingEmails = [
            SELECT Id, Marketing_Campaign__c
            FROM Marketing_Email__c
            WHERE Marketing_Campaign__c IN :campaignIds WITH USER_MODE
        ];
            for (Marketing_Email__c email : marketingEmails) {
                if (!campaignToEmailIdsMap.containsKey(email.Marketing_Campaign__c)) {
                    campaignToEmailIdsMap.put(email.Marketing_Campaign__c, new Set<Id>());
                }
                campaignToEmailIdsMap.get(email.Marketing_Campaign__c).add(email.Id);
            }
            
            if (!campaignIds.isEmpty() && !contactIds.isEmpty()) {
                List<Email_Member__c> emailMembers = [
                SELECT Id, Contact__c, Marketing_Email__c, Status__c
                FROM Email_Member__c
                WHERE Contact__c IN :contactIds 
                AND Marketing_Email__c IN (SELECT Id FROM Marketing_Email__c WHERE Marketing_Campaign__c IN :campaignIds)
                AND Status__c = 'Pending'
                WITH USER_MODE
            ];
                for (Email_Member__c em : emailMembers) {
                    String key = em.Contact__c + '-' + em.Marketing_Email__c;
                    emailMembersToUpdate.put(key, em);
                }
            }
            
            // Build a cache of templateId -> extractedKeyMap for recipient field replacement.
            // This allows us to look up recipientFields keys per template without per-request SOQL.
            Set<Id> allTemplateDataIds = new Set<Id>();
            for (EmailRequest req : emailRequests) {
                if (req.templateDataId != null) {
                    allTemplateDataIds.add(req.templateDataId);
                }
            }
            Map<Id, Map<String, Object>> templateIdToExtractedKeyMap = new Map<Id, Map<String, Object>>();
            if (!allTemplateDataIds.isEmpty()) {
                List<Template__c> templateDataRecords = [
                    SELECT Id,
                        (SELECT Template_Value_Simple__c FROM Template_Data__r
                         WHERE Value_Type__c = 'Extracted Mapping Keys'
                         ORDER BY Order_No_Simple__c ASC)
                    FROM Template__c
                    WHERE Id IN :allTemplateDataIds WITH USER_MODE
                ];
            }

            for (EmailRequest req : emailRequests) {
                Marketing_Campaign__c campaignRecord = campaignMap.get(req.campaignId);
                if (campaignRecord.Schedule_Type__c != 'Contact Field') {
                    continue; // Skip if not contact field
                }
            }
            
            try {
                if (!emails.isEmpty()) {
                    List<Messaging.SendEmailResult> sendEmailResults = Messaging.sendEmail(emails);
                    CreateActivityRecordsFromMail.createCaseEmailMessage(contactEmailInfoMap);
                }
                
                // Update Email_Member__c records to 'Success'
                if (!emailMembersToUpdate.isEmpty()) {
                    update as user emailMembersToUpdate.values();
                }
                
                // Recalculate campaign counts
                for (String campaignId : campaignIds) {
                    if (campaignMap.get(campaignId).Schedule_Type__c == 'Contact Field') {
                        EmailCampaignController.recalculateCampaignCounts(campaignId);
                    }
                }
            } catch (Exception e) {
                System.debug('Error in Schedular');
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'EmailCampaignScheduler', 'sendEmails', 'Error while sending mails');
        }
    }
    
    /**
     * Method Name: parseEmailAddresses
     * Date: 23/07/2024
     * Created By: Rachit Shah
     * @description: Gets email addresses from the campaign data.
     */
    public static List<String> parseEmailAddresses(String addresses) {
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
            ErrorHandler.insertErrordata(e, 'EmailCampaignScheduler', 'parseEmailAddresses', 'Error while parsing mails');
            return null;
        }
    }
    
    /**
     * Method Name: getContacts
     * Date: 23/07/2024
     * Created By: Rachit Shah
     * @description: Gets all contact data.
     */
    public static List<Contact> getContacts(Set<String> contactIds) {
        try {
            List<String> fieldNames = getAllFieldNames('Contact');
            String query = 'SELECT ' + String.join(fieldNames, ', ') + ' FROM Contact WHERE Id IN :contactIds';
            List<Contact> contactRecords = Database.query(String.escapeSingleQuotes(query), AccessLevel.USER_MODE);
            return contactRecords;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'EmailCampaignScheduler', 'getContacts', 'Error while getting contacts');
            return null;
        }
    }
    
    /**
     * Method Name: getAllFieldNames
     * Date: 23/07/2024
     * Created By: Rachit Shah
     * @description: Gets all field names.
     */
    public static List<String> getAllFieldNames(String objectName) {
        try {
            List<String> fieldNames = new List<String>();
            Schema.SObjectType sObjectType = Schema.getGlobalDescribe().get(objectName);
            if (!sObjectType.getDescribe().isAccessible()) {
                ErrorHandler.insertErrordata(null, 'EmailCampaignScheduler', 'getAllFieldNames', 'No access to object: ' + objectName + ' at line 243.');
                return null;
            }
            Map<String, Schema.SObjectField> fields = sObjectType.getDescribe().fields.getMap();
            for (String fieldName : fields.keySet()) {
                Schema.SObjectField field = fields.get(fieldName);
                if (field.getDescribe().isAccessible()) {
                    fieldNames.add(fieldName);
                }
            }
            fieldNames.sort();
            return fieldNames;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'EmailCampaignScheduler', 'getAllFieldNames', 'Error while getting all field names');
            return null;
        }
    }
    
    /**
     * Method Name: EmailRequest
     * Date: 23/07/2024
     * Created By: Rachit Shah
     * @description: Wrapper class for getting all the data.
     */
    public class EmailRequest {
        @InvocableVariable(required=true description='Selected Contact Email address')
        public String email;
        
        @InvocableVariable(description='List of CC recipient email addresses')
        public String ccAddresses;
        
        @InvocableVariable(description='List of BCC recipient email addresses')
        public String bccAddresses;
        
        @InvocableVariable(required=true description='Subject of the email')
        public String subject;
        
        @InvocableVariable(required=true description='Body of the email')
        public String body;
        
        @InvocableVariable(required=true description='Campaign Id')
        public String campaignId;
        
        @InvocableVariable(required=true description='Contact Id for merge fields')
        public String contactId;
        
        @InvocableVariable(required=true description='Template Data Id')
        public String templateDataId;
        
    }
}