/**
* Class Name : CreateActivityRecordsFromMail
* Test Class : CreateActivityRecordsFromMailTest
* Created By : Karan Singh
* Last Modified Date : 17/09/2026
* Last Modified By : Karan Singh
* @description : Handles the creation of EmailMessage, Attachment, and EmailMessageRelation activity records when emails are sent.
*/
public with sharing class CreateActivityRecordsFromMail {

    /**
    * Method Name : createCaseEmailMessage
    * @param contactEmailInfoMap Map of Contact Id to email detail map (subject, body, email, cc, bcc, attachment, etc.).
    * @description : Creates and inserts EmailMessage, Attachment, and EmailMessageRelation activity records for sent emails.
    */
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
            ErrorHandler.insertErrorData(e, 'CreateActivityRecordsFromMail', 'createCaseEmailMessage', 'Error while creating Case Email Message');
        }
    }

    /**
    * Method Name : buildEmailMessage
    * @param contactId The Contact record ID associated with the email.
    * @param emailInfo Map containing email attributes such as to address, subject, body, cc, and bcc.
    * @return EmailMessage Constructed EmailMessage record populated with sender, recipient, body, and contact details.
    * @description : Constructs an EmailMessage record from provided contact and email information.
    */
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
        caseEmailMessage.MVEX__Contact_ID__c = contactId;
        caseEmailMessage.Status = '3';
        return caseEmailMessage;
    }

    /**
    * Method Name : buildAttachment
    * @param contactId The Contact record ID to associate the attachment with.
    * @param emailInfo Map containing attachment content (base64) and attachment name.
    * @return Attachment Constructed Attachment record or null if no attachment data is present.
    * @description : Builds an Attachment record from base64 encoded content associated with the email.
    */
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

    /**
    * Method Name : buildEmailMessageRelation
    * @param caseEmailMessage The inserted EmailMessage record.
    * @return EmailMessageRelation Constructed EmailMessageRelation linking the EmailMessage to the contact.
    * @description : Creates an EmailMessageRelation record to link the EmailMessage with the related Contact.
    */
    private static EmailMessageRelation buildEmailMessageRelation(EmailMessage caseEmailMessage) {
        EmailMessageRelation emr = new EmailMessageRelation();
        emr.EmailMessageId = caseEmailMessage.Id;
        emr.RelationId = caseEmailMessage.MVEX__Contact_ID__c;
        emr.RelationType = 'FromAddress';
        emr.RelationAddress = caseEmailMessage.FromAddress;
        return emr;
    }
}