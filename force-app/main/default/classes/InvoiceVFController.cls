public with sharing class InvoiceVFController {
    public Property__c property { get; set; }
    public List<Payment_Schedule__c> paymentSchedules { get; set; }
    public Decimal totalAmount { get; set; }
    public String generationDate { get; set; }
    public String paymentPlanId { get; set; }
    public Boolean isRenderAsPDF { get; set; }

    public InvoiceVFController() {
        paymentPlanId = ApexPages.currentPage().getParameters().get('id');
        String renderMode = ApexPages.currentPage().getParameters().get('renderAsPDF');
        isRenderAsPDF = (renderMode == 'true');

        initializeController();
    }

    private void initializeController() {
        if (String.isBlank(paymentPlanId)) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Payment Plan ID is missing.'));
            return;
        }

        try {
            List<Payment_Plan__c> paymentPlans = [
                SELECT Id, Property__c
                FROM Payment_Plan__c
                WHERE Id = :paymentPlanId
                WITH USER_MODE
                LIMIT 1
            ];

            if (paymentPlans.isEmpty()) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'No Payment_Plan__c record found for ID: ' + paymentPlanId));
                return;
            }

            Payment_Plan__c paymentPlan = paymentPlans[0];

            if (paymentPlan.Property__c != null) {
                property = [
                    SELECT Id, Name, CurrencyIsoCode, Completion_Status__c, Country__c, Furnished__c, 
                           Property_Sub_Type__c, Type__c, Address__c, Apartment_Number_and_Name__c, 
                           Area__c, Bathrooms__c, Bedrooms__c, City__c, Completion_Date__c, 
                           Country_Code__c, Description__c, Floor__c, Number_of_Parking_Spaces__c, 
                           Service_Charge__c, Size__c, State__c, Street__c, Subcommunity__c, Units__c, Year_Built__c, 
                           Zip_Postal_Code__c,Sale_Price__c
                    FROM Property__c
                    WHERE Id = :paymentPlan.Property__c
                    WITH USER_MODE
                    LIMIT 1
                ];
            } else {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'No Property associated with this Payment Plan.'));
                return;
            }
        } catch (Exception e) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Error fetching Property record: ' + e.getMessage()));
            return;
        }

        try {
            paymentSchedules = [
                SELECT Id, Installment_Type__c, Amount__c, Due_Date__c, Percentage__c, Status__c
                FROM Payment_Schedule__c
                WHERE Payment_Plan__c = :paymentPlanId
                WITH USER_MODE
                ORDER BY Due_Date__c ASC
            ];
        } catch (Exception e) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Error fetching Payment Schedules: ' + e.getMessage()));
            return;
        }

        totalAmount = 0;
        if (paymentSchedules != null) {
            for (Payment_Schedule__c ps : paymentSchedules) {
                totalAmount += ps.Amount__c != null ? ps.Amount__c : 0;
            }
        }

        generationDate = Date.today().format();
    }

    @AuraEnabled
    public static String saveInvoiceAsFile(String paymentPlanId, String base64Pdf) {
        try {
            List<Payment_Plan__c> paymentPlans = [
                SELECT Id, Payer__c, Amount__c
                FROM Payment_Plan__c
                WHERE Id = :paymentPlanId
                WITH USER_MODE
                LIMIT 1
            ];

            if (paymentPlans.isEmpty()) {
                throw new AuraHandledException('No Payment_Plan__c record found for ID: ' + paymentPlanId);
            }

            Payment_Plan__c paymentPlan = paymentPlans[0];

            List<Payment_Schedule__c> paymentSchedules = [
                SELECT Id, Due_Date__c
                FROM Payment_Schedule__c
                WHERE Payment_Plan__c = :paymentPlanId AND Due_Date__c != null
                WITH USER_MODE
                ORDER BY Due_Date__c ASC
                LIMIT 1
            ];
            Date dueDate = paymentSchedules.isEmpty() ? Date.today().addDays(30) : paymentSchedules[0].Due_Date__c;

            Blob pdfBlob;
            System.debug('Base64 PDF Length: ' + base64Pdf);
            
            try {
                pdfBlob = EncodingUtil.base64Decode(String.valueOf(base64Pdf));
                System.debug('Decoded PDF Blob Size: ' + pdfBlob.size());
            } catch (Exception e) {
                throw new AuraHandledException('Failed to decode Base64 PDF: ' + e.getMessage());
            }

            if (pdfBlob.size() == 0) {
                throw new AuraHandledException('Decoded PDF Blob is empty');
            }

            ContentVersion cv = new ContentVersion();
            cv.Title = 'Statement_' + Date.today().format();
            cv.PathOnClient = 'Statement_' + String.escapeSingleQuotes(paymentPlanId) + '.pdf';
            cv.VersionData = pdfBlob; // Use the decoded Blob
            cv.IsMajorVersion = true;
            insert as user cv;

            cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id WITH USER_MODE LIMIT 1];

            ContentDocumentLink cdlPaymentPlan = new ContentDocumentLink();
            cdlPaymentPlan.ContentDocumentId = cv.ContentDocumentId;
            cdlPaymentPlan.LinkedEntityId = String.escapeSingleQuotes(paymentPlanId);
            cdlPaymentPlan.ShareType = 'V';
            cdlPaymentPlan.Visibility = 'AllUsers';
            insert as user cdlPaymentPlan;

            return paymentPlanId;
        } catch (Exception e) {
            System.debug('Error in saveInvoiceAsFile: ' + e.getMessage());
            System.debug('Error in saveInvoiceAsFile2: ' + e.getLineNumber());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error saving invoice: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static String getVFPageContent(String paymentPlanId) {
        PageReference pageRef = Page.CreatePaymentInvoiceVF;
        pageRef.getParameters().put('id', paymentPlanId);
        pageRef.getParameters().put('renderAsPDF', 'false');
        return !Test.isRunningTest() ? pageRef.getContent().toString() : '<div>Test HTML</div>';
    }

    @AuraEnabled
    public static String getVFPagePDF(String paymentPlanId) {
        try {
            PageReference pageRef = Page.CreatePaymentInvoiceVF;
            pageRef.getParameters().put('id', paymentPlanId);
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