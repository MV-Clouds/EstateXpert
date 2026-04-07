@isTest
private class CreatePaymentInvoiceControllerTest {

    // @testSetup
    // static void setupData() {

    //     // Create Contact (Payer)
    //     Contact payer = new Contact(
    //         FirstName = 'John',
    //         LastName = 'Doe',
    //         Email = 'john.doe@test.com'
    //     );
    //     insert payer;

    //     // Create Payment Plan
    //     Payment_Plan__c plan = new Payment_Plan__c(
    //         Payer__c = payer.Id
    //     );
    //     insert plan;

    //     // Create Email Template using runAs 
    //     Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

    //     User u = new User(
    //         Alias = 'testu',
    //         Email = 'testuser@test.com',
    //         EmailEncodingKey = 'UTF-8',
    //         LastName = 'Test',
    //         LanguageLocaleKey = 'en_US',
    //         LocaleSidKey = 'en_US',
    //         ProfileId = p.Id,
    //         TimeZoneSidKey = 'Asia/Kolkata',
    //         UserName = 'testuser' + System.currentTimeMillis() + '@test.com'
    //     );
    //     insert u;

    //     System.runAs(u) {
    //         EmailTemplate template = new EmailTemplate(
    //             Name = 'Statement Template',
    //             DeveloperName = 'StatementEmailTemplate',
    //             FolderId = UserInfo.getUserId(),
    //             TemplateType = 'text',
    //             Subject = 'Invoice Statement',
    //             Body = 'Test Email Body'
    //         );
    //         insert template;
    //     }
    // }

    // // -------------------------------
    // // Test getPayerDetails
    // // -------------------------------
    // @isTest
    // static void testGetPayerDetails() {

    //     Payment_Plan__c plan = [SELECT Id FROM Payment_Plan__c LIMIT 1];

    //     Test.startTest();
    //     Map<String, String> result = CreatePaymentInvoiceController.getPayerDetails(plan.Id);
    //     Test.stopTest();

    //     System.assertEquals(true, result.containsKey('label'));
    //     System.assertEquals(true, result.containsKey('value'));
    //     System.assertEquals(true, result.containsKey('email'));
    // }

    // // -------------------------------
    // // Test sendInvoiceEmail - Success
    // // -------------------------------
    // @isTest
    // static void testSendInvoiceEmail_Success() {

    //     Payment_Plan__c plan = [
    //         SELECT Id, Payer__c, Payer__r.Email 
    //         FROM Payment_Plan__c 
    //         LIMIT 1
    //     ];

    //     // Create valid base64 PDF string
    //     Blob pdfBlob = Blob.valueOf('Dummy PDF Content');
    //     String base64Pdf = EncodingUtil.base64Encode(pdfBlob);

    //     Test.startTest();

    //     String result = CreatePaymentInvoiceController.sendInvoiceEmail(plan.Id, base64Pdf);

    //     Test.stopTest();

    //     System.assertEquals(1, Limits.getEmailInvocations());
    // }

    // // -------------------------------
    // // Test sendInvoiceEmail - No Email
    // // -------------------------------
    // @isTest
    // static void testSendInvoiceEmail_NoEmail() {

    //     // Create contact without email
    //     Contact c = new Contact(LastName = 'NoEmail');
    //     insert c;

    //     Payment_Plan__c plan = new Payment_Plan__c(
    //         Payer__c = c.Id
    //     );
    //     insert plan;

    //     Blob pdfBlob = Blob.valueOf('Test');
    //     String base64Pdf = EncodingUtil.base64Encode(pdfBlob);

    //     Test.startTest();

    //     String result = CreatePaymentInvoiceController.sendInvoiceEmail(plan.Id, base64Pdf);

    //     Test.stopTest();

    //     System.assert(result.contains('No valid email'));
    // }

    // // -------------------------------
    // // Test sendInvoiceEmail - Invalid PDF
    // // -------------------------------
    // @isTest
    // static void testSendInvoiceEmail_InvalidPDF() {

    //     Payment_Plan__c plan = [SELECT Id FROM Payment_Plan__c LIMIT 1];

    //     Test.startTest();

    //     String result = CreatePaymentInvoiceController.sendInvoiceEmail(plan.Id, 'INVALID_BASE64');

    //     Test.stopTest();

    //     System.assert(result.contains('Invalid PDF data'));
    // }

    // // -------------------------------
    // // Test sendInvoiceEmail - Missing Template
    // // -------------------------------
    // @isTest
    // static void testSendInvoiceEmail_NoTemplate() {

    //     delete [SELECT Id FROM EmailTemplate WHERE DeveloperName = 'StatementEmailTemplate'];

    //     Payment_Plan__c plan = [SELECT Id FROM Payment_Plan__c LIMIT 1];

    //     Blob pdfBlob = Blob.valueOf('Test');
    //     String base64Pdf = EncodingUtil.base64Encode(pdfBlob);

    //     Test.startTest();

    //     String result = CreatePaymentInvoiceController.sendInvoiceEmail(plan.Id, base64Pdf);

    //     Test.stopTest();
    // }
}