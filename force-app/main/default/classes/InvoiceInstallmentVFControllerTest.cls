@isTest
private class InvoiceInstallmentVFControllerTest {

    @testSetup
    static void setupData() {

        // Create Contact (Payer)
        Contact payer = new Contact(
            FirstName = 'Invoice',
            LastName = 'User',
            Email = 'invoice@test.com'
        );
        insert payer;

        // Create Listing (MVEX__Listing__c)
        MVEX__Listing__c listing = new MVEX__Listing__c(
            Name = 'Test Property'
        );
        insert listing;

        // Create Payment Plan
        Payment_Plan__c plan = new Payment_Plan__c(
            Payer__c = payer.Id,
            Listing__c = listing.Id
        );
        insert plan;

        // Create Payment Schedule
        Payment_Schedule__c schedule = new Payment_Schedule__c(
            Payment_Plan__c = plan.Id,
            Amount__c = 1000,
            Due_Date__c = Date.today().addDays(10),
            Status__c = 'Upcoming'
        );
        insert schedule;
    }

    // ---------------------------------------
    // Test Constructor - Success
    // ---------------------------------------
    @isTest
    static void testConstructor_Success() {

        Payment_Schedule__c schedule = [SELECT Id FROM Payment_Schedule__c LIMIT 1];

        Test.setCurrentPage(Page.CreateInstallmentInvoice);
        ApexPages.currentPage().getParameters().put('id', schedule.Id);
        ApexPages.currentPage().getParameters().put('renderAsPDF', 'true');

        Test.startTest();

        InvoiceInstallmentVFController controller = new InvoiceInstallmentVFController();

        Test.stopTest();

        System.assertNotEquals(null, controller.paymentSchedule);
        System.assertEquals(true, controller.isRenderAsPDF);
        System.assertEquals(1000, controller.totalAmount);
    }

    // ---------------------------------------
    // Test Constructor - Missing ID
    // ---------------------------------------
    @isTest
    static void testConstructor_NoId() {

        Test.setCurrentPage(Page.CreateInstallmentInvoice);

        Test.startTest();
        InvoiceInstallmentVFController controller = new InvoiceInstallmentVFController();
        Test.stopTest();

        System.assertEquals(null, controller.paymentSchedule);
    }

    // ---------------------------------------
    // Test saveInvoiceAsFile - Success
    // ---------------------------------------
    @isTest
    static void testSaveInvoiceAsFile_Success() {

        Payment_Schedule__c schedule = [SELECT Id FROM Payment_Schedule__c LIMIT 1];

        Blob pdfBlob = Blob.valueOf('Test PDF Content');
        String base64Pdf = EncodingUtil.base64Encode(pdfBlob);

        Test.startTest();
        String invoiceId = InvoiceInstallmentVFController.saveInvoiceAsFile(schedule.Id, base64Pdf);
        Test.stopTest();

        System.assertNotEquals(null, invoiceId);

        // Verify Invoice created
        Invoice__c inv = [SELECT Id FROM Invoice__c WHERE Id = :invoiceId];
        System.assertNotEquals(null, inv);

        // Verify ContentDocumentLink created
        List<ContentDocumentLink> links = [
            SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId = :invoiceId
        ];
        System.assert(links.size() > 0);
    }

    // ---------------------------------------
    // Test saveInvoiceAsFile - Invalid Base64
    // ---------------------------------------
    @isTest
    static void testSaveInvoiceAsFile_InvalidBase64() {

        Payment_Schedule__c schedule = [SELECT Id FROM Payment_Schedule__c LIMIT 1];

        Test.startTest();
        Boolean exceptionThrown = false;

        try {
            InvoiceInstallmentVFController.saveInvoiceAsFile(schedule.Id, 'INVALID_BASE64');
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'Exception should be thrown for invalid base64');
    }

    // ---------------------------------------
    // Test getVFPageContent
    // --------------------------------------- 
    @isTest
    static void testGetVFPageContent() {

        Payment_Schedule__c schedule = [SELECT Id FROM Payment_Schedule__c LIMIT 1];

        Test.startTest();
        String html = InvoiceInstallmentVFController.getVFPageContent(schedule.Id);
        Test.stopTest();

        System.assert(html.contains('Test HTML'));
    }

    // ---------------------------------------
    // Test getVFPagePDF
    // ---------------------------------------
    @isTest
    static void testGetVFPagePDF() {

        Payment_Schedule__c schedule = [SELECT Id FROM Payment_Schedule__c LIMIT 1];

        Test.startTest();
        String base64Pdf = InvoiceInstallmentVFController.getVFPagePDF(schedule.Id);
        Test.stopTest();

        System.assertNotEquals(null, base64Pdf);
    }

}