/**
* Class Name : SupportEmailService
* Test Class : SupportEmailServiceTest
* Created By : Karan Singh
* Created Date : 09/24/2026
* @description : Inbound email service handler to process customer support emails and create or update support cases.
*/
public with sharing class SupportEmailService implements Messaging.InboundEmailHandler {

    /**
    * Method Name : handleInboundEmail
    * @param email : Incoming InboundEmail object containing email headers, body, and attachments.
    * @param envelope : InboundEnvelope object containing sender and recipient routing information.
    * @return Messaging.InboundEmailResult : Result of the email handling process.
    * @description : Handles inbound support emails, creates new support cases, or links replies and attachments to existing cases.
    */
    public Messaging.InboundEmailResult handleInboundEmail(Messaging.InboundEmail email, Messaging.InboundEnvelope envelope) {
        try {
            Boolean isAvailable = false;

            String fromAddress = email.fromAddress;
            Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();
            String emailBody = email.plainTextBody;
            ParsedEmailWrapper parsedEmail = parseEmail(emailBody);

            String supportCaseId;
            if (email.subject != null && email.subject.contains(' - Ticket ID ')) {
                String[] subjectParts = email.subject.split(' - Ticket ID ');
                if (subjectParts.size() > 1) {
                    supportCaseId = subjectParts[1].replace('"', '').trim();
                }
            }

            Boolean isReplied = email.subject != null && email.subject.startsWith('Re:');

            List<MVEX__Support_Case__c> supportList = new List<MVEX__Support_Case__c>();
            if (String.isNotBlank(supportCaseId)) {
                supportList = [SELECT Id, MVEX__Description__c, MVEX__Email__c, MVEX__Name__c, MVEX__Priority__c, MVEX__Subject__c FROM MVEX__Support_Case__c WHERE Id = :supportCaseId WITH USER_MODE LIMIT 1];
            }
            if (!supportList.isEmpty()) {
                isAvailable = true;
            } else {
                isAvailable = false;
            }
    
            if (!isAvailable) {
                MVEX__Support_Case__c supportCase = new MVEX__Support_Case__c();

                // Name: Use parsed fromName if present, otherwise fallback to email.fromName
                String customerName = (parsedEmail != null && String.isNotBlank(parsedEmail.fromName)) ? parsedEmail.fromName : email.fromName;
                if (String.isBlank(customerName)) {
                    customerName = 'Support Customer';
                }

                // Email: Use parsed emailAddress, or fallback to email.replyTo, or envelope/fromAddress
                String customerEmail = '';
                if (parsedEmail != null && String.isNotBlank(parsedEmail.emailAddress)) {
                    customerEmail = parsedEmail.emailAddress;
                } else if (String.isNotBlank(email.replyTo)) {
                    customerEmail = email.replyTo;
                } else if (String.isNotBlank(email.fromAddress)) {
                    customerEmail = email.fromAddress;
                }

                // Priority: Use parsed priority if present, otherwise default to Medium
                String priorityVal = (parsedEmail != null && String.isNotBlank(parsedEmail.priority)) ? parsedEmail.priority : 'Medium';

                // Description: Use parsed body if present, otherwise email.plainTextBody
                String descriptionVal = (parsedEmail != null && String.isNotBlank(parsedEmail.body)) ? parsedEmail.body : email.plainTextBody;

                supportCase.MVEX__Name__c = customerName; 
                supportCase.MVEX__Email__c = customerEmail;
                supportCase.MVEX__From_Email__c = email.fromAddress;
                supportCase.MVEX__Subject__c = email.subject; 
                supportCase.MVEX__Description__c = descriptionVal;
                supportCase.MVEX__Priority__c = priorityVal;
                insert as user supportCase;

                SendEmailToCustomer.sendAcknowledgmentEmail(supportCase);
        
                List<ContentVersion> contentVersions = new List<ContentVersion>();
                List<ContentDocumentLink> contentLinks = new List<ContentDocumentLink>();
        
                if (email.binaryAttachments != null && email.binaryAttachments.size() > 0) {
                    for (Messaging.InboundEmail.BinaryAttachment attachment : email.binaryAttachments) {
                        ContentVersion contentVersion = new ContentVersion();
                        String fileExtension = (attachment.mimeTypeSubType != null && attachment.mimeTypeSubType.contains('/')) ? 
                                               attachment.mimeTypeSubType.substringAfter('/') : 'bin';
                        contentVersion.Title = attachment.fileName + '.' + fileExtension;
                        contentVersion.PathOnClient = attachment.fileName + '.' + fileExtension;
                        contentVersion.VersionData = attachment.body;
                        contentVersion.IsMajorVersion = true;
                        contentVersion.FirstPublishLocationId = supportCase.Id;
                        contentVersions.add(contentVersion);
                    }
        
                    if (!contentVersions.isEmpty()) {
                        insert as user contentVersions;   
                    }
                }
            } else {
                if (!isReplied) {
                    List<ContentVersion> contentVersions = new List<ContentVersion>();
                    List<ContentDocumentLink> contentLinks = new List<ContentDocumentLink>();
            
                    if (email.binaryAttachments != null && email.binaryAttachments.size() > 0) {
                        for (Messaging.InboundEmail.BinaryAttachment attachment : email.binaryAttachments) {
                            ContentVersion contentVersion = new ContentVersion();
                            String fileExtension = (attachment.mimeTypeSubType != null && attachment.mimeTypeSubType.contains('/')) ? 
                                                   attachment.mimeTypeSubType.substringAfter('/') : 'bin';
                            contentVersion.Title = attachment.fileName + '.' + fileExtension;
                            contentVersion.PathOnClient = attachment.fileName + '.' + fileExtension;
                            contentVersion.VersionData = attachment.body;
                            contentVersion.IsMajorVersion = true;
                            contentVersion.FirstPublishLocationId = supportCaseId;
                            contentVersions.add(contentVersion);
                        }
            
                        if (!contentVersions.isEmpty()) {
                            insert as user contentVersions;   
                        }
                    }

                    SendEmailToCustomer.sendAcknowledgmentEmail(supportList[0]);
                } else {

                    Map<String, Map<String, String>> supportEmailInfoMap = new Map<String, Map<String, String>>();
                    
                    Map<String, String> emailInfo = new Map<String, String>();
                    emailInfo.put('email', envelope.toAddress);
                    emailInfo.put('fromAddress', String.isNotBlank(email.replyTo) ? email.replyTo : email.fromAddress);
                    emailInfo.put('subject', email.subject);
                    emailInfo.put('body', email.plainTextBody);
                    supportEmailInfoMap.put(supportCaseId, emailInfo);
                    
                    createCaseEmailMessage(supportEmailInfoMap, email.binaryAttachments);
                }
            }
    
            result.success = true;
            return result;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'SupportEmailService', 'handleInboundEmail', 'Error while processing email: ' + e.getMessage());
            return null;
        }

    }

    /**
    * Class Name : ParsedEmailWrapper
    * @description : Wrapper class holding parsed email fields including name, email, priority, org id, and body.
    */
    public class ParsedEmailWrapper {
        public String body { get; set; }
        public String fromName { get; set; }
        public String emailAddress { get; set; }
        public String priority { get; set; }
        public String orgId { get; set; }
    }

    /**
    * Method Name : parseEmail
    * @param emailContent : String containing the plain text body of the incoming email.
    * @return ParsedEmailWrapper : Wrapper object populated with extracted customer details and description.
    * @description : Parses plain text email body to extract sender name, email address, priority, organization ID, and description.
    */
    public static ParsedEmailWrapper parseEmail(String emailContent) {

        try {
            ParsedEmailWrapper emailWrapper = new ParsedEmailWrapper();
            if (String.isBlank(emailContent)) {
                return emailWrapper;
            }

            String[] lines = emailContent.split('\n');
            Boolean inDescriptionSection = false;
            List<String> descriptionLines = new List<String>();
            List<String> fallbackBodyLines = new List<String>();

            for (String rawLine : lines) {
                String line = rawLine.trim();
                String lower = line.toLowerCase();

                // If currently capturing description section
                if (inDescriptionSection) {
                    descriptionLines.add(rawLine);
                    continue;
                }

                // From / User / Name
                if (lower.startsWith('from :') || lower.startsWith('from:') ||
                    lower.startsWith('user :') || lower.startsWith('user:') ||
                    lower.startsWith('name :') || lower.startsWith('name:')) {
                    emailWrapper.fromName = line.substringAfter(':').trim();
                }
                // Email
                else if (lower.startsWith('email :') || lower.startsWith('email:') ||
                         lower.startsWith('email address :') || lower.startsWith('email address:')) {
                    emailWrapper.emailAddress = line.substringAfter(':').trim();
                }
                // Priority
                else if (lower.startsWith('priority :') || lower.startsWith('priority:')) {
                    emailWrapper.priority = line.substringAfter(':').trim();
                }
                // Organization ID
                else if (lower.startsWith('organization id :') || lower.startsWith('organization id:') ||
                         lower.startsWith('org id :') || lower.startsWith('org id:') ||
                         lower.startsWith('organization :') || lower.startsWith('organization:')) {
                    emailWrapper.orgId = line.substringAfter(':').trim();
                }
                // Description section header
                else if (lower == 'description:' || lower == 'description :' ||
                         lower.startsWith('description:') || lower.startsWith('description :')) {
                    inDescriptionSection = true;
                    String textAfterColon = line.substringAfter(':').trim();
                    if (String.isNotBlank(textAfterColon)) {
                        descriptionLines.add(textAfterColon);
                    }
                }
                // Ignore submission title headers
                else if (lower == 'feedback submission' || lower == 'support request' || lower == 'new support request') {
                    continue;
                }
                else {
                    // Collect for legacy format or plain text emails without Description: header
                    if (String.isNotBlank(line) || !fallbackBodyLines.isEmpty()) {
                        fallbackBodyLines.add(rawLine);
                    }
                }
            }

            // Set body from description lines if Description header existed, otherwise from fallback body lines
            if (!descriptionLines.isEmpty()) {
                emailWrapper.body = String.join(descriptionLines, '\n').trim();
            } else if (!fallbackBodyLines.isEmpty()) {
                emailWrapper.body = String.join(fallbackBodyLines, '\n').trim();
            } else {
                emailWrapper.body = '';
            }

            return emailWrapper;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'SupportEmailService', 'parseEmail', 'Error while parsing email.');
            return null;
        }

    }

    /**
    * Method Name : createCaseEmailMessage
    * @param contactEmailInfoMap : Map of support case ID to email info attributes.
    * @param attachments : List of binary attachments to associate with the EmailMessage.
    * @description : Creates incoming EmailMessage records and attaches files to the related support case on email replies.
    */
    public static void createCaseEmailMessage(Map<String, Map<String, String>> contactEmailInfoMap, List<Messaging.InboundEmail.BinaryAttachment> attachments) {
        try {
            List<EmailMessage> emailMessagesToInsert = new List<EmailMessage>();
            List<EmailMessageRelation> emailMessageRelationsToInsert = new List<EmailMessageRelation>();
            List<ContentVersion> contentVersionsToInsert = new List<ContentVersion>();

            for (String supportId : contactEmailInfoMap.keySet()) {
                Map<String, String> emailInfo = contactEmailInfoMap.get(supportId);
                
                String toAddress = emailInfo.get('email');
                String subject = emailInfo.get('subject');
                String body = emailInfo.get('body');
                String fromAddress = emailInfo.get('fromAddress');

                EmailMessage caseEmailMessage = new EmailMessage();
                caseEmailMessage.FromAddress = fromAddress;
                caseEmailMessage.ToAddress = toAddress;
                caseEmailMessage.FromName = UserInfo.getUserName();
                caseEmailMessage.Subject = subject;
                caseEmailMessage.HtmlBody = body;
                caseEmailMessage.Incoming = true;
                caseEmailMessage.MessageDate = System.now();
                caseEmailMessage.RelatedToId = supportId;

                emailMessagesToInsert.add(caseEmailMessage);

                if (attachments != null && !attachments.isEmpty()) {
                    for (Messaging.InboundEmail.BinaryAttachment attachment : attachments) {
                        ContentVersion contentVersion = new ContentVersion();
                        contentVersion.Title = subject + ' - ' + fromAddress + ' - ' + attachment.filename;
                        contentVersion.PathOnClient = attachment.filename;
                        contentVersion.VersionData = attachment.body;
                        contentVersion.FirstPublishLocationId = supportId; 

                        contentVersionsToInsert.add(contentVersion);
                    }
                }
            }

            if (!emailMessagesToInsert.isEmpty()) {
                insert as user emailMessagesToInsert; 

                for (EmailMessage emailMessage : emailMessagesToInsert) {
                    emailMessage.Status = '2'; 
                }

                update as user emailMessagesToInsert; 

                if (!contentVersionsToInsert.isEmpty()) {
                    insert as user contentVersionsToInsert; 
                }
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'ReplyEmailService', 'createCaseEmailMessage', 'Error while creating Case Email Message');
        }
    }
}