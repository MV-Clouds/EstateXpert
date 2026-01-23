public with sharing class GeminiChatService {
    @AuraEnabled
    public static String sendFeedbackEmail(String subject, String description, String[] images) {
        // Unchanged from original code
        try {
            String[] toAddresses = Label.supportEmail.split(',');
            String userName = UserInfo.getName();
            String userEmail = UserInfo.getUserEmail();
            String orgId = UserInfo.getOrganizationId();
            
            String emailBody = 'Feedback Submission\n\n' +
                             'User: ' + userName + '\n' +
                             'Email: ' + userEmail + '\n' +
                             'Organization ID: ' + orgId + '\n\n' +
                             'Description:\n' + description;

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(toAddresses);
            mail.setSubject(subject);
            mail.setPlainTextBody(emailBody);

            if (images != null && !images.isEmpty()) {
                List<Messaging.EmailFileAttachment> attachments = new List<Messaging.EmailFileAttachment>();
                for (Integer i = 0; i < images.size(); i++) {
                    Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
                    attachment.setFileName('feedback_image_' + (i + 1) + '.png');
                    attachment.setBody(EncodingUtil.base64Decode(images[i]));
                    attachments.add(attachment);
                }
                mail.setFileAttachments(attachments);
            }

            Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[]{mail});
            if (results[0].isSuccess()) {
                return 'Success';
            } else {
                return 'Error: Failed to send email - ' + results[0].getErrors()[0].getMessage();
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'GeminiChatService', 'sendFeedbackEmail', e.getMessage());
            return 'Error: ' + e.getMessage();
        }
    }
}