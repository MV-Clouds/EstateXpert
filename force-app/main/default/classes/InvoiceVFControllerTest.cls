@isTest
private class InvoiceVFControllerTest {

    // @testSetup
    // static void setupData() {

    //     // Create Contact (Payer)
    //     Contact payer = new Contact(
    //         LastName = 'Test User',
    //         Email = 'test@test.com'
    //     );
    //     insert payer;

    //     // Create Listing
    //     MVEX__Listing__c listing = new MVEX__Listing__c(
    //         Name = 'Test Listing'
    //     );
    //     insert listing;

    //     // Create Payment Plan
    //     Payment_Plan__c plan = new Payment_Plan__c(
    //         Payer__c = payer.Id,
    //         Listing__c = listing.Id,
    //         Amount__c = 5000
    //     );
    //     insert plan;

    //     // Create Payment Schedules
    //     List<Payment_Schedule__c> schedules = new List<Payment_Schedule__c>{
    //         new Payment_Schedule__c(
    //             Payment_Plan__c = plan.Id,
    //             Amount__c = 1000,
    //             Due_Date__c = Date.today().addDays(10),
    //             Status__c = 'Upcoming'
    //         ),
    //         new Payment_Schedule__c(
    //             Payment_Plan__c = plan.Id,
    //             Amount__c = 2000,
    //             Due_Date__c = Date.today().addDays(20),
    //             Status__c = 'Upcoming'
    //         )
    //     };
    //     insert schedules;
    // }

    // // ---------------------------------------
    // // Constructor Test (Success)
    // // ---------------------------------------
    // @isTest
    // static void testConstructor_Success() {

    //     Payment_Plan__c plan = [SELECT Id FROM Payment_Plan__c LIMIT 1];

    //     Test.setCurrentPage(Page.CreatePaymentInvoiceVF);
    //     ApexPages.currentPage().getParameters().put('id', plan.Id);
    //     ApexPages.currentPage().getParameters().put('renderAsPDF', 'true');

    //     Test.startTest();

    //     InvoiceVFController ctrl = new InvoiceVFController();

    //     Test.stopTest();

    //     System.assertNotEquals(null, ctrl.listing);
    //     System.assert(ctrl.paymentSchedules.size() > 0);
    //     System.assert(ctrl.totalAmount > 0);
    //     System.assertEquals(true, ctrl.isRenderAsPDF);
    // }

    // // ---------------------------------------
    // // Constructor - Missing ID
    // // ---------------------------------------
    // @isTest
    // static void testConstructor_NoId() {

    //     Test.setCurrentPage(Page.CreatePaymentInvoiceVF);

    //     Test.startTest();

    //     InvoiceVFController ctrl = new InvoiceVFController();

    //     Test.stopTest();

    //     System.assertEquals(null, ctrl.paymentSchedules);
    // }

    // // ---------------------------------------
    // // saveInvoiceAsFile - Success
    // // ---------------------------------------
    // @isTest
    // static void testSaveInvoiceAsFile_Success() {

    //     Payment_Plan__c plan = [SELECT Id FROM Payment_Plan__c LIMIT 1];

    //     Blob pdfBlob = Blob.valueOf('Test PDF');
    //     String base64Pdf = EncodingUtil.base64Encode(pdfBlob);

    //     Test.startTest();

    //     String result = InvoiceVFController.saveInvoiceAsFile(plan.Id, base64Pdf);

    //     Test.stopTest();

    //     System.assertEquals(plan.Id, result);

    //     // Verify file created
    //     List<ContentDocumentLink> links = [
    //         SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId = :plan.Id
    //     ];
    //     System.assert(links.size() > 0);
    // }

    // // ---------------------------------------
    // // saveInvoiceAsFile - Invalid Base64
    // // ---------------------------------------
    // @isTest
    // static void testSaveInvoiceAsFile_InvalidBase64() {

    //     Payment_Plan__c plan = [SELECT Id FROM Payment_Plan__c LIMIT 1];

    //     Test.startTest();

    //     Boolean exceptionThrown = false;

    //     try {
    //         InvoiceVFController.saveInvoiceAsFile(plan.Id, 'INVALID_BASE64');
    //     } catch (Exception e) {
    //         exceptionThrown = true;
    //     }

    //     Test.stopTest();

    //     System.assertEquals(true, exceptionThrown);
    // }

    // // ---------------------------------------
    // // getVFPageContent
    // // ---------------------------------------
    // @isTest
    // static void testGetVFPageContent() {

    //     Payment_Plan__c plan = [SELECT Id FROM Payment_Plan__c LIMIT 1];

    //     Test.startTest();

    //     String html = InvoiceVFController.getVFPageContent(plan.Id);

    //     Test.stopTest();

    //     System.assert(html.contains('Test HTML'));
    // }

    // // ---------------------------------------
    // // getVFPagePDF (Handled safely)
    // // ---------------------------------------
    // @isTest
    // static void testGetVFPagePDF() {

    //     Payment_Plan__c plan = [SELECT Id FROM Payment_Plan__c LIMIT 1];

    //     Test.startTest();

    //     Boolean exceptionThrown = false;

    //     try {
    //         String result = InvoiceVFController.getVFPagePDF(plan.Id);
    //     } catch (Exception e) {
    //         exceptionThrown = true;
    //     }

    //     Test.stopTest();

    //     // In test context this method throws exception due to PDF validation
    //     System.assertEquals(true, exceptionThrown);
    // }
}