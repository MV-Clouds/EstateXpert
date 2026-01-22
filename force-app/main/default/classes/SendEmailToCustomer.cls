public with sharing class SendEmailToCustomer {
    public static void sendAcknowledgmentEmail(Support_Case__c supportCase) {
        try {
            if (supportCase.Email__c != null) {
                Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                email.setToAddresses(new String[] {supportCase.Email__c});
                email.setSubject('Acknowledgment of Your Support Request - Ticket ID ' + supportCase.Id);
                
                String emailBody = 'Dear ' + supportCase.Name__c + ',\n\n'
                    + 'Thank you for reaching out to us. Your support request has been successfully received. Below are the details:\n\n'
                    + 'Ticket ID: ' + supportCase.Id + '\n'
                    + 'Subject: ' + supportCase.Subject__c + '\n'
                    + 'Priority: ' + supportCase.Priority__c + '\n'
                    + 'Description: ' + supportCase.Description__c + '\n\n'
                    + 'Our support team will review your request and contact you shortly.\n\n'
                    + 'Thank you for your patience and for giving us the opportunity to assist you.\n\n'
                    + 'Best Regards,\n'
                    + 'The Support Team';
                
                email.setPlainTextBody(emailBody);
                Messaging.sendEmail(new Messaging.SingleEmailMessage[] {email});
            }
        } catch (Exception e) {
            ErrorHandler.insert_errordata(e, 'SupportEmailNotification', 'sendAcknowledgmentEmail', 'Error while sending acknowledgment email.');
        }
    }
}