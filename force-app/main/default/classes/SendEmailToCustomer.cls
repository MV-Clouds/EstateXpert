/**
* Class Name : SendEmailToCustomer
* Test Class : SupportEmailServiceTest
* Created By : Karan Singh
* Created Date : 09/24/2026
* @description : Utility class used to send automated email notifications and acknowledgments to customers for support cases.
*/
public with sharing class SendEmailToCustomer {

    /**
    * Method Name : sendAcknowledgmentEmail
    * @param supportCase : MVEX__Support_Case__c record containing ticket details (Id, Name, Email, Subject, Priority, Description).
    * @description : Sends an acknowledgment email to the customer with ticket details once their support request is received.
    */
    public static void sendAcknowledgmentEmail(MVEX__Support_Case__c supportCase) {
        try {
            if (supportCase.MVEX__Email__c != null) {
                Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                email.setToAddresses(new String[] {supportCase.MVEX__Email__c});
                email.setSubject('Acknowledgment of Your Support Request - Ticket ID ' + supportCase.Id);
                
                String emailBody = 'Dear ' + supportCase.MVEX__Name__c + ',\n\n'
                    + 'Thank you for reaching out to us. Your support request has been successfully received. Below are the details:\n\n'
                    + 'Ticket ID: ' + supportCase.Id + '\n'
                    + 'Subject: ' + supportCase.MVEX__Subject__c + '\n'
                    + 'Priority: ' + supportCase.MVEX__Priority__c + '\n'
                    + 'Description: ' + supportCase.MVEX__Description__c + '\n\n'
                    + 'Our support team will review your request and contact you shortly.\n\n'
                    + 'Thank you for your patience and for giving us the opportunity to assist you.\n\n'
                    + 'Best Regards,\n'
                    + 'The Support Team';
                
                email.setPlainTextBody(emailBody);
                Messaging.sendEmail(new Messaging.SingleEmailMessage[] {email});
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'SupportEmailNotification', 'sendAcknowledgmentEmail', 'Error while sending acknowledgment email.');
        }
    }
}