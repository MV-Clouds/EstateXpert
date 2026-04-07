public with sharing class CreateInstallmentInvoiceController {
    // @AuraEnabled
    // public static Map<String, String> getPayerDetails(String paymentScheduleId) {
    //     try {
    //         Payment_Schedule__c paymentSchedule = [SELECT Id, Payment_Plan__c, Payment_Plan__r.Payer__c, Payment_Plan__r.Payer__r.Name, Payment_Plan__r.Payer__r.Email
    //                                                 FROM Payment_Schedule__c WHERE Id = :paymentScheduleId WITH USER_MODE LIMIT 1];
            
    //         Map<String, String> payerDetails = new Map<String, String>();
    //         if (paymentSchedule.Payment_Plan__r.Payer__c != null) {
    //             payerDetails.put('label', paymentSchedule.Payment_Plan__r.Payer__r.Name);
    //             payerDetails.put('value', paymentSchedule.Payment_Plan__r.Payer__c);
    //             payerDetails.put('email', paymentSchedule.Payment_Plan__r.Payer__r.Email);
    //         }
    //         return payerDetails;
    //     } catch (Exception e) {
    //         ErrorHandler.insertErrorData(e, 'CreateInstallmentInvoiceController', 'getPayerDetails', 'Error while fetching payer details');
    //         return new Map<String, String>();
    //     }
    // }

    // @AuraEnabled
    // public static String sendInvoiceEmail(String paymentScheduleId, String pdfBlob) {
    //     try {
    //         Payment_Schedule__c paymentSchedule = [SELECT Id, Name, Payment_Plan__c, Payment_Plan__r.Payer__c, Payment_Plan__r.Payer__r.Name, Payment_Plan__r.Payer__r.Email
    //                                                 FROM Payment_Schedule__c WHERE Id = :paymentScheduleId WITH USER_MODE LIMIT 1];
            
    //         if (paymentSchedule.Payment_Plan__r.Payer__r.Email == null) {
    //             return 'No valid email found for the payer';
    //         }

    //         EmailTemplate emailTemplate = [SELECT Id, Name, HtmlValue, Subject FROM EmailTemplate WHERE DeveloperName = 'InvoiceEmailTemplate' WITH USER_MODE LIMIT 1];

    //         if (emailTemplate == null) {
    //             return 'Email template not found';
    //         }

    //         Blob pdfData;
    //         try {
    //             pdfData = EncodingUtil.base64Decode(pdfBlob);
    //         } catch (Exception e) {
    //             return 'Invalid PDF data: ' + e.getMessage();
    //         }

    //         if (pdfData == null || pdfData.size() == 0) {
    //             return 'PDF data is empty or invalid';
    //         }

    //         Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
    //         mail.setToAddresses(new String[]{paymentSchedule.Payment_Plan__r.Payer__r.Email});
    //         mail.setTargetObjectId(paymentSchedule.Payment_Plan__r.Payer__c);
    //         mail.setSaveAsActivity(true);
    //         mail.setWhatId(paymentScheduleId);
    //         mail.setTemplateId(emailTemplate.Id);

    //         Messaging.EmailFileAttachment efa = new Messaging.EmailFileAttachment();
    //         efa.setFileName('Invoice.pdf');
    //         efa.setBody(pdfData);
    //         efa.setContentType('application/pdf');
    //         mail.setFileAttachments(new List<Messaging.EmailFileAttachment>{efa});

    //         Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[]{mail});

    //         if (results[0].isSuccess()) {
    //             return 'Success';
    //         }

    //         return 'Email send failed';
    //     } catch (Exception e) {
    //         ErrorHandler.insertErrorData(e, 'CreateInstallmentInvoiceController', 'sendInvoiceEmail', 'Error while sending invoice email');
    //         return e.getMessage();
    //     }
    // }
}