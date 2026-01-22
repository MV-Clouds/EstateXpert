public with sharing class SupportRequestController {

    public class EmailResponse {
        @AuraEnabled public String message;
        @AuraEnabled public Boolean status;
    }

    @AuraEnabled
    public static EmailResponse sendEmail(String name, String email, String subject, String body, String priority, List<String> contentDocumentIds) {
        EmailResponse response = new EmailResponse();
        response.status = true;
        response.message = 'Email sent successfully.';
        try {
            List<Messaging.SingleEmailMessage> emailList = new List<Messaging.SingleEmailMessage>();
            String myCustomLabel = System.Label.supportEmail;
            List<String> toEmailAddress = new List<String>();
            if (myCustomLabel.contains(',')) {
                toEmailAddress.addAll(myCustomLabel.split(','));
            } else {
                toEmailAddress.add(myCustomLabel);
            }

            List<Messaging.Emailfileattachment> fileAttachments = new List<Messaging.Emailfileattachment>();

            List<ContentVersion> contentVersions = [SELECT VersionData, Title, FileExtension,ContentDocumentId FROM ContentVersion WHERE ContentDocumentId IN :contentDocumentIds WITH USER_MODE LIMIT 1000];
            for (ContentVersion contentVersion : contentVersions) {
                Messaging.Emailfileattachment efat = new Messaging.Emailfileattachment();
                efat.setFileName(contentVersion.Title);
                efat.setBody(contentVersion.VersionData);
                String fileExtension = contentVersion.FileExtension.toLowerCase();
                String contentType;
                if (fileExtension == 'png') {
                    contentType = 'image/png';
                } else if (fileExtension == 'jpg' || fileExtension == 'jpeg') {
                    contentType = 'image/jpeg';
                } else {
                    contentType = 'application/octet-stream'; // Default type for unknown extensions
                }
                efat.setContentType(contentType);
                fileAttachments.add(efat);
            }

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setSubject(subject);
            mail.setPlainTextBody(body + '\n\n\nFrom : ' + name + '\nEmail : ' + email + '\nPriority : ' + priority);
            mail.setToAddresses(toEmailAddress);
            if (!fileAttachments.isEmpty()) {
                mail.setFileAttachments(fileAttachments);
            }
            emailList.add(mail);

            List<Messaging.SendEmailResult> mrs = Messaging.sendEmail(emailList);
                
            Boolean allEmailsSentSuccessfully = true;

            for (Messaging.SendEmailResult mr : mrs) {
                if (!mr.isSuccess()) {
                    allEmailsSentSuccessfully = false;
                }
            }

            if (allEmailsSentSuccessfully) {
                deleteContentVersion(contentDocumentIds);
            }

        } catch (Exception e) {
            ErrorHandler.insert_errordata(e, 'SupportRequestController', 'sendEmail', 'Error while sending email.');
            response.status = false;
            response.message = e.getMessage();
        }
        return response;
    }

    public static void deleteContentVersion(List<String> contentDocumentIds) {
        try {
            List<ContentDocument> contentDocuments = [SELECT Id FROM ContentDocument WHERE Id IN :contentDocumentIds WITH USER_MODE LIMIT 1000];
            if (!contentDocuments.isEmpty()) {
                if (Schema.sObjectType.ContentDocument.isDeletable()) {
                    delete as user contentDocuments;
                }   
            }

        } catch (Exception e) {
            ErrorHandler.insert_errordata(e, 'SupportRequestController', 'deleteContentVersion', 'Error while deleting content version.');
        }
    }

    @AuraEnabled
    public static void deleteContentDocument(String contentDocumentId) {
        try {
            ContentDocument document = [SELECT Id FROM ContentDocument WHERE Id = :contentDocumentId WITH USER_MODE LIMIT 1];
            if (Schema.sObjectType.ContentDocument.isDeletable()) {
                delete as user document;
            }
        } catch (Exception e) {
            ErrorHandler.insert_errordata(e, 'SupportRequestController', 'deleteContentDocument', 'Error while deleting content version.');
        }
    }
}