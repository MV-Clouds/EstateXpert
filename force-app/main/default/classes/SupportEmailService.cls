public with sharing class SupportEmailService implements Messaging.InboundEmailHandler {
    public Messaging.InboundEmailResult handleInboundEmail(Messaging.InboundEmail email, Messaging.InboundEnvelope envelope) {

        try {
            Boolean isAvailable = false;

            String fromAddress = email.fromAddress;
            Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();
            String emailBody = email.plainTextBody;
            ParsedEmailWrapper parsedEmail = parseEmail(emailBody);

            String supportCaseId;
            String[] subjectParts = email.subject.split(' - Ticket ID ');
            if (subjectParts.size() > 1) {
                supportCaseId = subjectParts[1].replace('"', '');
            } else {
                supportCaseId = null;
            }

            Boolean isReplied = email.subject.startsWith('Re:');

            List<MVEX__Support_Case__c> supportList = [SELECT Id, MVEX__Description__c, MVEX__Email__c, MVEX__Name__c, MVEX__Priority__c, MVEX__Subject__c FROM MVEX__Support_Case__c WHERE Id = :supportCaseId WITH USER_MODE LIMIT 1];
            if (!supportList.isEmpty()) {
                isAvailable = true;
            } else {
                isAvailable = false;
            }
    
            if (!isAvailable) {
                Support_Case__c supportCase = new Support_Case__c();
                supportCase.Name__c = parsedEmail.fromName; 
                supportCase.Email__c = parsedEmail.emailAddress;
                supportCase.Subject__c = email.subject; 
                supportCase.Description__c = parsedEmail.body;
                supportCase.Priority__c = parsedEmail.priority;
                insert as user  supportCase;

                SendEmailToCustomer.sendAcknowledgmentEmail(supportCase);
        
                List<ContentVersion> contentVersions = new List<ContentVersion>();
                List<ContentDocumentLink> contentLinks = new List<ContentDocumentLink>();
        
                if (email.binaryAttachments != null && email.binaryAttachments.size() > 0) {
                    for (Messaging.InboundEmail.BinaryAttachment attachment : email.binaryAttachments) {
                        ContentVersion contentVersion = new ContentVersion();
                        String fileExtension = attachment.mimeTypeSubType.substringAfter('/');
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
                            String fileExtension = attachment.mimeTypeSubType.substringAfter('/');
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
                    emailInfo.put('fromAddress', email.fromAddress);
                    emailInfo.put('subject', email.subject);
                    emailInfo.put('body', email.plainTextBody);
                    supportEmailInfoMap.put(supportCaseId, emailInfo);
                    
                    createCaseEmailMessage(supportEmailInfoMap, email.binaryAttachments);
                }
            }
    
            result.success = true;
            return result;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'SupportEmailService', 'handleInboundEmail', 'Error while processing email.');
            return null;
        }

    }

    public class ParsedEmailWrapper {
        public String body { get; set; }
        public String fromName { get; set; }
        public String emailAddress { get; set; }
        public String priority { get; set; }
    }

    public static ParsedEmailWrapper parseEmail(String emailContent) {

        try {
            ParsedEmailWrapper emailWrapper = new ParsedEmailWrapper();
            String[] lines = emailContent.split('\n');
            for (String line : lines) {
                line = line.trim();
                if (line.startsWith('From :')) {
                    emailWrapper.fromName = line.substringAfter('From :').trim();
                }
                else if (line.startsWith('Email :')) {
                    emailWrapper.emailAddress = line.substringAfter('Email :').trim();
                }
                else if (line.startsWith('Priority :')) {
                    emailWrapper.priority = line.substringAfter('Priority :').trim();
                }
                else {
                    if (emailWrapper.body == null) {
                        emailWrapper.body = line;
                    } else {
                        emailWrapper.body += '\n' + line;
                    }
                }
            }
            return emailWrapper;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'SupportEmailService', 'parseEmail', 'Error while parsing email.');
            return null;
        }

    }

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