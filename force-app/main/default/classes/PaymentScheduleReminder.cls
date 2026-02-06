public with sharing class PaymentScheduleReminder {
    public void sendReminderEmails(Map<Id, Payment_Schedule__c> installmentMap) {

        try {
            // Query the email template once
            List<EmailTemplate> template = [SELECT Id FROM EmailTemplate WHERE DeveloperName = 'PaymentReminderEmailTemplate' WITH USER_MODE];

            if (template.isEmpty()) {
                ErrorHandler.insertErrorData(null,'PaymentScheduleReminder','sendReminderEmails','Error: Email template not found.');
                return;
            }

            List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
            
            for (Payment_Schedule__c installment : installmentMap.values()) {
                
                // Check if Payer__c is null or if installment is already paid
                if (installment.Payer__c == null) {
                    ErrorHandler.insertErrorData(null,'PaymentScheduleReminder','sendReminderEmails','Error: Payer__c is null for Payment_Schedule__c Id: ' + installment.Id);
                    continue;
                }

                if (installment.Status__c != 'Paid') {
                    Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                    email.setTargetObjectId(installment.Payer__c);
                    email.setWhatId(installment.Id);
                    email.setTemplateId(template[0].Id);
                    email.setSaveAsActivity(true);
                    emails.add(email);
                }
            }

            if (!emails.isEmpty()) {
                Messaging.SendEmailResult[] results = Messaging.sendEmail(emails);
                for (Messaging.SendEmailResult result : results) {
                    if (result.isSuccess()) {
                        System.debug('Successfully sent payment reminder email for Payment_Schedule__c ');
                    } else {
                        ErrorHandler.insertErrorData( null,'PaymentScheduleReminder','sendReminderEmails','Error: Failed to send email for Payment_Schedule__c.');
                    }
                }
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData( e,'PaymentScheduleReminder','sendReminderEmails','Error while processing payment reminder emails.');
        }
    }
}