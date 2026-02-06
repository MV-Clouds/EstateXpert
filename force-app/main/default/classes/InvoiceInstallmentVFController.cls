public with sharing class InvoiceInstallmentVFController {
    public MVEX__Listing__c listing { get; set; }
    public Payment_Schedule__c paymentSchedule { get; set; }
    public Decimal totalAmount { get; set; }
    public String generationDate { get; set; }
    public String paymentScheduleId { get; set; }
    public Boolean isRenderAsPDF { get; set; }

    public InvoiceInstallmentVFController() {
        paymentScheduleId = ApexPages.currentPage().getParameters().get('id');
        String renderMode = ApexPages.currentPage().getParameters().get('renderAsPDF');
        isRenderAsPDF = (renderMode == 'true');

        initializeController();
    }

    private void initializeController() {
        if (String.isBlank(paymentScheduleId)) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Payment Schedule ID is missing.'));
            return;
        }

        try {
            List<Payment_Schedule__c> paymentSchedules = [
                SELECT Id, Payment_Plan__c, Payment_Plan__r.Listing__c, Installment_Type__c, Amount__c, Due_Date__c, Percentage__c, Status__c
                FROM Payment_Schedule__c
                WHERE Id = :paymentScheduleId
                WITH USER_MODE
                LIMIT 1
            ];

            if (paymentSchedules.isEmpty()) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'No Payment_Schedule__c record found for ID: ' + paymentScheduleId));
                return;
            }

            paymentSchedule = paymentSchedules[0];
            System.debug('Payment Schedule Data: ' + paymentSchedule); // Debug to confirm data

            if (paymentSchedule.Payment_Plan__r.Listing__c != null) {
                listing = [
                    SELECT Id, Name, CurrencyIsoCode, MVEX__Completion_Status__c, MVEX__Country__c, MVEX__Furnished__c, 
                           MVEX__Property_Sub_Type__c, MVEX__Property_Type__c, MVEX__Address__c, MVEX__House_Office_No__c, 
                           MVEX__Subcommunity__c, MVEX__Bathrooms__c, MVEX__Bedrooms__c, MVEX__City__c, MVEX__Completion_Date__c, 
                           MVEX__Country_Code__c, MVEX__Description__c, MVEX__Floor__c, MVEX__Number_of_Parking_Spaces__c, 
                           MVEX__Service_Charge__c, MVEX__Size__c, MVEX__State__c, MVEX__Street__c, MVEX__Units__c, MVEX__Year_Built__c, 
                           MVEX__Zip_Postal_Code__c,MVEX__Sale_Price__c
                    FROM MVEX__Listing__c
                    WHERE Id = :paymentSchedule.Payment_Plan__r.Listing__c
                    WITH USER_MODE
                    LIMIT 1
                ];
            } else {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'No Property associated with this Payment Schedule.'));
                return;
            }
        } catch (Exception e) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Error fetching Payment Schedule or Property record: ' + e.getMessage()));
            return;
        }

        totalAmount = paymentSchedule.Amount__c != null ? paymentSchedule.Amount__c : 0;
        System.debug('Total Amount: ' + totalAmount); // Debug to confirm total
        generationDate = Date.today().format();
    }

    @AuraEnabled
    public static String saveInvoiceAsFile(String paymentScheduleId, String base64Pdf) {
        try {
            paymentScheduleId = paymentScheduleId;
            List<Payment_Schedule__c> paymentSchedules = [
                SELECT Id, Payment_Plan__c, Payment_Plan__r.Payer__c, Amount__c, Due_Date__c
                FROM Payment_Schedule__c
                WHERE Id = :paymentScheduleId
                WITH USER_MODE
                LIMIT 1
            ];

            if (paymentSchedules.isEmpty()) {
                throw new AuraHandledException('No Payment_Schedule__c record found for ID: ' + paymentScheduleId);
            }

            Payment_Schedule__c paymentSchedule = paymentSchedules[0];
            Date dueDate = paymentSchedule.Due_Date__c != null ? paymentSchedule.Due_Date__c : Date.today().addDays(30);

            Blob pdfBlob;
            try {
                pdfBlob = EncodingUtil.base64Decode(base64Pdf);
                System.debug('Decoded PDF Blob Size: ' + pdfBlob.size());
            } catch (Exception e) {
                throw new AuraHandledException('Failed to decode Base64 PDF: ' + e.getMessage());
            }

            if (pdfBlob.size() == 0) {
                throw new AuraHandledException('Decoded PDF Blob is empty');
            }

            Invoice__c invoice = new Invoice__c();
            invoice.Status__c = 'Draft, Issued';
            invoice.Amount_Due__c = paymentSchedule.Amount__c != null ? paymentSchedule.Amount__c : 0;
            invoice.Amount_Paid__c = 0;
            invoice.Due_Date__c = dueDate;
            invoice.Issued_To__c = paymentSchedule.Payment_Plan__r.Payer__c;
            invoice.Payment_Schedule__c = paymentScheduleId;
            insert as user invoice;

            Invoice__c singleInvoice = [Select Id, Name from Invoice__c WHERE Id =: invoice.Id WITH USER_MODE];
            System.debug('Invoice1' + paymentScheduleId + '.pdf');
            System.debug('Invoice2' + paymentScheduleId + '.pdf');
            ContentVersion cv = new ContentVersion();
            cv.Title = 'Invoice_' + singleInvoice.Name + '_' + Date.today().format();
            cv.PathOnClient = 'Invoice_' + paymentScheduleId + '.pdf';
            cv.VersionData = pdfBlob;
            cv.IsMajorVersion = true;
            insert as user cv;

            cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id WITH USER_MODE LIMIT 1];

            ContentDocumentLink cdlPaymentSchedule = new ContentDocumentLink();
            cdlPaymentSchedule.ContentDocumentId = cv.ContentDocumentId;
            cdlPaymentSchedule.LinkedEntityId = paymentScheduleId;
            cdlPaymentSchedule.ShareType = 'V';
            cdlPaymentSchedule.Visibility = 'AllUsers';
            insert as user cdlPaymentSchedule;

            ContentDocumentLink cdlInvoice = new ContentDocumentLink();
            cdlInvoice.ContentDocumentId = cv.ContentDocumentId;
            cdlInvoice.LinkedEntityId = invoice.Id;
            cdlInvoice.ShareType = 'V';
            cdlInvoice.Visibility = 'AllUsers';
            insert as user cdlInvoice;

            return invoice.Id;
        } catch (Exception e) {
            System.debug('Error in saveInvoiceAsFile: ' + e.getMessage());
            throw new AuraHandledException('Error saving invoice: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static String getVFPageContent(String paymentScheduleId) {
        PageReference pageRef = Page.CreateInstallmentInvoice;
        pageRef.getParameters().put('id', paymentScheduleId);
        pageRef.getParameters().put('renderAsPDF', 'false');
        return !Test.isRunningTest() ? pageRef.getContent().toString() : '<div>Test HTML</div>';
    }

    @AuraEnabled
    public static String getVFPagePDF(String paymentScheduleId) {
        try {
            PageReference pageRef = Page.CreateInstallmentInvoice;
            pageRef.getParameters().put('id', paymentScheduleId);
            pageRef.getParameters().put('renderAsPDF', 'true');
            
            Blob pdfBlob = !Test.isRunningTest() ? pageRef.getContentAsPDF() : Blob.valueOf('Test PDF');
            System.debug('PDF Blob Size: ' + pdfBlob.size());
            System.debug('PDF Blob First 100 Bytes: ' + EncodingUtil.base64Encode(pdfBlob).substring(0, Math.min(100, pdfBlob.size())));
            
            String base64Pdf = EncodingUtil.base64Encode(pdfBlob);
            System.debug('Base64 PDF Length: ' + base64Pdf.length());
            System.debug('Base64 PDF First 100 Chars: ' + base64Pdf.substring(0, Math.min(100, base64Pdf.length())));

            if (!base64Pdf.startsWith('JVBERi0')) {
                System.debug('PDF Blob does not start with %PDF-: Possible error page');
                throw new AuraHandledException('Generated PDF is invalid. It might contain an error page instead of a PDF.');
            }
            
            return base64Pdf;
        } catch (Exception e) {
            System.debug('Error in getVFPagePDF: ' + e.getMessage());
            throw new AuraHandledException('Failed to generate PDF: ' + e.getMessage());
        }
    }
}