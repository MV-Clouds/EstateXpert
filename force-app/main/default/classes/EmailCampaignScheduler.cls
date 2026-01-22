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
                SELECT Id, Name, Remaining_Emails__c, Status__c, Total_Sent_Mails__c, Email_Type__c, Schedule_Type__c 
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
            
            for (EmailRequest req : emailRequests) {
                Marketing_Campaign__c campaignRecord = campaignMap.get(req.campaignId);
                if (campaignRecord.Schedule_Type__c != 'Contact Field') {
                    continue; // Skip if not contact field
                }
                String emailType = campaignRecord.Email_Type__c;
                Contact contact = contactMap.get(req.contactId);
                String processedBody = req.body;
                String templateDataId = req.templateDataId;
                
                if (contact != null) {
                    Map<String, Map<String, String>> mappingKeys = DataMappingControllerV2.getMappingsKeyValues(
                    new List<String>{templateDataId}, contact.Id, true
                    );
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
                
                // Find and mark Email_Member__c as Success
                String key = req.contactId + '-' + marketingEmails[0].Id; // Assuming one email per campaign for simplicity
                if (emailMembersToUpdate.containsKey(key)) {
                    emailMembersToUpdate.get(key).Status__c = 'Success';
                }
                
                if (emailType == 'single') {
                    Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                    
                    email.setToAddresses(new List<String>{req.email});
                    
                    if (req.ccAddresses != null) {
                        List<String> ccEmails = parseEmailAddresses(req.ccAddresses);
                        email.setCcAddresses(ccEmails);
                    }
                    
                    if (req.bccAddresses != null) {
                        List<String> bccEmails = parseEmailAddresses(req.bccAddresses);
                        email.setBccAddresses(bccEmails);
                    }
                    
                    email.setSubject(req.subject);
                    email.setHtmlBody(processedBody);
                    emails.add(email);
                    
                    contactEmailInfoMap.put(req.contactId, new Map<String, String>{
                        'subject' => req.subject,
                        'body' => processedBody,
                        'email' => req.email,
                        'cc' => req.ccAddresses,
                        'bcc' => req.bccAddresses
                    });
                }
            }
            
            try {
                if (!emails.isEmpty()) {
                    List<Messaging.SendEmailResult> sendEmailResults = Messaging.sendEmail(emails);
                    CreateActivityFromMail2.createCaseEmailMessage(contactEmailInfoMap);
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
                for (Email_Member__c em : emailMembersToUpdate.values()) {
                    em.Status__c = 'Failed';
                }
                if (!emailMembersToUpdate.isEmpty()) {
                    update as user emailMembersToUpdate.values();
                }
                
                // Recalculate campaign counts
                for (String campaignId : campaignIds) {
                    if (campaignMap.get(campaignId).Schedule_Type__c == 'Contact Field') {
                        EmailCampaignController.recalculateCampaignCounts(campaignId);
                    }
                }
                
                ErrorHandler.insertErrordata(e, 'EmailCampaignScheduler', 'sendEmails', 'Error while sending mails');
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
                throw new AuraHandledException('No access to object: ' + objectName);
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