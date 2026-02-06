public with sharing class InvoiceFlowHandler {
    @InvocableMethod(label='Process Invoice for payment Schedules via Flow' description='Receives a list of Payment_Schedule__c records from Flow, generates PDF invoices, and sends them as email attachments')
    public static void handleInvoices(List<FlowInputs> inputs) {
        // Collect all Payment_Schedule__c records and their IDs
        List<Payment_Schedule__c> installmentsFromFlow = new List<Payment_Schedule__c>();
        Set<Id> installmentIds = new Set<Id>();
        for (FlowInputs input : inputs) {
            if (input.installmentsFromFlow != null) {
                for (Payment_Schedule__c installment : input.installmentsFromFlow) {
                    // Only process records where Due_Date__c is today and Status__c is not 'Paid'
                    if (installment.Due_Date__c == Date.today() && installment.Status__c != 'Paid') {
                        installmentsFromFlow.add(installment);
                        installmentIds.add(installment.Id);
                    }
                }
            }
        }

        if (installmentsFromFlow.isEmpty()) {
            System.debug('No eligible Payment_Schedule__c records received from Flow (due today and not Paid). Exiting.');
            return;
        }

        // Query all necessary data in a single SOQL query
        Map<Id, Payment_Schedule__c> installmentMap = new Map<Id, Payment_Schedule__c>([
            SELECT Id, Amount__c, Due_Date__c, Installment_Type__c, Status__c, Payer__c, 
                   Payer__r.Email, Payment_Plan__r.Amount__c, Payment_Plan__r.Payer__c
            FROM Payment_Schedule__c
            WHERE Id IN :installmentIds
            WITH USER_MODE
        ]);

        System.debug('Processing ' + installmentMap.size() + ' eligible Payment_Schedule__c records.');

        // Process each Payment_Schedule__c record
        for (Payment_Schedule__c installment : installmentMap.values()) {
            try {
                // Validate Payer__c and email
                if (installment.Payer__c == null || String.isBlank(installment.Payer__r.Email)) {
                    ErrorHandler.insertErrorData(null, 'InvoiceFlowHandler', 'handleInvoices', 
                        'Error: Payer__c or Payer Email is null for Payment_Schedule__c Id: ' + installment.Id);
                    continue;
                }

                // Generate PDF invoice
                String base64Pdf;
                try {
                    base64Pdf = InvoiceInstallmentVFController.getVFPagePDF(installment.Id);
                } catch (Exception e) {
                    ErrorHandler.insertErrorData(e, 'InvoiceFlowHandler', 'handleInvoices', 
                        'Error generating PDF for Payment_Schedule__c Id: ' + installment.Id + ': ' + e.getMessage());
                    continue;
                }

                // Save the invoice as a file
                String invoiceId;
                try {
                    invoiceId = InvoiceInstallmentVFController.saveInvoiceAsFile(installment.Id, base64Pdf);
                } catch (Exception e) {
                    ErrorHandler.insertErrorData(e, 'InvoiceFlowHandler', 'handleInvoices', 
                        'Error saving invoice for Payment_Schedule__c Id: ' + installment.Id + ': ' + e.getMessage());
                    continue;
                }

                // Send the invoice email
                try {
                    String result = CreateInstallmentInvoiceController.sendInvoiceEmail(installment.Id, base64Pdf);
                    if (result != 'Success') {
                        ErrorHandler.insertErrorData(null, 'InvoiceFlowHandler', 'handleInvoices', 
                            'Error sending email for Payment_Schedule__c Id: ' + installment.Id + ': ' + result);
                    } else {
                        System.debug('Successfully sent invoice email for Payment_Schedule__c Id: ' + installment.Id);
                    }
                } catch (Exception e) {
                    ErrorHandler.insertErrorData(e, 'InvoiceFlowHandler', 'handleInvoices', 
                        'Error sending email for Payment_Schedule__c Id: ' + installment.Id + ': ' + e.getMessage());
                }
            } catch (Exception e) {
                ErrorHandler.insertErrorData(e, 'InvoiceFlowHandler', 'handleInvoices', 
                    'Unexpected error processing Payment_Schedule__c Id: ' + installment.Id + ': ' + e.getMessage());
            }
        }
    }

    public class FlowInputs {
        @InvocableVariable(description='List of Payment_Schedule__c records to process')
        public List<Payment_Schedule__c> installmentsFromFlow;
    }
}