public with sharing class CreateActivityFromMail2 {
    public static void createCaseEmailMessage(Map<String, Map<String, String>> contactEmailInfoMap) {
        try {
            List<EmailMessage> emailMessagesToInsert = new List<EmailMessage>();
            List<EmailMessageRelation> emailMessageRelationsToInsert = new List<EmailMessageRelation>();
            List<Attachment> attachmentsToInsert = new List<Attachment>();

            for (String contactId : contactEmailInfoMap.keySet()) {
                Map<String, String> emailInfo = contactEmailInfoMap.get(contactId);
                
                EmailMessage caseEmailMessage = buildEmailMessage(contactId, emailInfo);
                emailMessagesToInsert.add(caseEmailMessage);

                Attachment attachment = buildAttachment(contactId, emailInfo);
                if (attachment != null) {
                    attachmentsToInsert.add(attachment);
                }
            }

            if (!emailMessagesToInsert.isEmpty()) {
                insert as user emailMessagesToInsert;
                
                for (EmailMessage caseEmailMessage : emailMessagesToInsert) {
                    emailMessageRelationsToInsert.add(buildEmailMessageRelation(caseEmailMessage));
                }

                if (!attachmentsToInsert.isEmpty()) {
                    insert as user attachmentsToInsert;
                }

                if (!emailMessageRelationsToInsert.isEmpty()) {
                    insert as user emailMessageRelationsToInsert;
                }
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'CreateActivityFromMail2', 'createCaseEmailMessage', 'Error while creating Case Email Message');
        }
    }

    // Helper methods to improve readability and maintainability
    private static EmailMessage buildEmailMessage(String contactId, Map<String, String> emailInfo) {
        EmailMessage caseEmailMessage = new EmailMessage();
        caseEmailMessage.FromAddress = UserInfo.getUserEmail();
        caseEmailMessage.ToAddress = emailInfo.get('email');
        caseEmailMessage.FromName = UserInfo.getUserName();
        caseEmailMessage.CcAddress = emailInfo.get('cc');
        caseEmailMessage.BccAddress = emailInfo.get('bcc');
        caseEmailMessage.Subject = emailInfo.get('subject');
        caseEmailMessage.HtmlBody = emailInfo.get('body');
        caseEmailMessage.Incoming = false;
        caseEmailMessage.MessageDate = System.now();
        caseEmailMessage.Contact_ID__c = contactId;
        caseEmailMessage.Status = '3';
        return caseEmailMessage;
    }

    private static Attachment buildAttachment(String contactId, Map<String, String> emailInfo) {
        String attachmentName = emailInfo.containsKey('attachmentName') ? emailInfo.get('attachmentName') : '';
        String attachmentContent = emailInfo.containsKey('attachmentContent') ? emailInfo.get('attachmentContent') : null;
        
        if (String.isNotBlank(attachmentName) && attachmentContent != null) {
            String contentVersionName = emailInfo.get('subject') + ' - ' + emailInfo.get('email') + ' - ' + attachmentName;
            Blob attachmentBlob = EncodingUtil.base64Decode(attachmentContent);
            
            Attachment attachment = new Attachment();
            attachment.Name = contentVersionName;
            attachment.Body = attachmentBlob;
            attachment.ParentId = contactId;
            attachment.ContentType = 'application/pdf';
            return attachment;
        }
        return null;
    }

    private static EmailMessageRelation buildEmailMessageRelation(EmailMessage caseEmailMessage) {
        EmailMessageRelation emr = new EmailMessageRelation();
        emr.EmailMessageId = caseEmailMessage.Id;
        emr.RelationId = caseEmailMessage.Contact_ID__c;
        emr.RelationType = 'FromAddress';
        emr.RelationAddress = caseEmailMessage.FromAddress;
        return emr;
    }
}