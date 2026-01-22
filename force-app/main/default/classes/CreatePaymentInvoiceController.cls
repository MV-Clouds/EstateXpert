public with sharing class CreatePaymentInvoiceController {
    // @AuraEnabled
    // public static Map<String, String> getPayerDetails(String paymentPlanId) {
    //     try {
    //         Payment_Plan__c paymentPlan = [SELECT Id, Payer__c, Payer__r.Name, Payer__r.Email FROM Payment_Plan__c WHERE Id = :paymentPlanId WITH USER_MODE LIMIT 1];
            
    //         Map<String, String> payerDetails = new Map<String, String>();
    //         if (paymentPlan.Payer__c != null) {
    //             payerDetails.put('label', paymentPlan.Payer__r.Name);
    //             payerDetails.put('value', paymentPlan.Payer__c);
    //             payerDetails.put('email', paymentPlan.Payer__r.Email);
    //         }
    //         return payerDetails;
    //     } catch (Exception e) {
    //         ErrorHandler.insertErrorData(e, 'CreatePaymentInvoiceController', 'getPayerDetails', 'Error while fetching payer details');
    //         return new Map<String, String>();
    //     }
    // }

    // @AuraEnabled
    // public static String sendInvoiceEmail(String paymentPlanId, String pdfBlob) {
    //     try {
    //         Payment_Plan__c paymentPlan = [SELECT Id, Name, Payer__c, Payer__r.Name, Payer__r.Email FROM Payment_Plan__c WHERE Id = :paymentPlanId WITH USER_MODE LIMIT 1];
            
    //         if (paymentPlan.Payer__r.Email == null) {
    //             return 'No valid email found for the payer';
    //         }

    //         EmailTemplate emailTemplate = [SELECT Id, Name, HtmlValue, Subject FROM EmailTemplate WHERE DeveloperName = 'StatementEmailTemplate' WITH USER_MODE LIMIT 1];

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
    //         mail.setToAddresses(new String[]{paymentPlan.Payer__r.Email});
    //         mail.setTargetObjectId(paymentPlan.Payer__c);
    //         mail.setSaveAsActivity(true);
    //         mail.setWhatId(paymentPlanId);
    //         mail.setTemplateId(emailTemplate.Id);

    //         Messaging.EmailFileAttachment efa = new Messaging.EmailFileAttachment();
    //         efa.setFileName('Statement.pdf');
    //         efa.setBody(pdfData); // Use the decoded Blob
    //         efa.setContentType('application/pdf');
    //         mail.setFileAttachments(new List<Messaging.EmailFileAttachment>{efa});

    //         Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[]{mail});

    //         if (results[0].isSuccess()) {
    //             return 'Success';
    //         }

    //         return 'Email send failed';
    //     } catch (Exception e) {
    //         ErrorHandler.insertErrorData(e, 'CreatePaymentInvoiceController', 'sendInvoiceEmail', 'Error while sending invoice email');
    //         return e.getMessage();
    //     }
    // }
}