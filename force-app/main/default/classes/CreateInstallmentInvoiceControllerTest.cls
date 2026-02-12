@isTest
private class CreateInstallmentInvoiceControllerTest {
    
    // // Setup method to create test data
    // @TestSetup
    // static void setupTestData() {
    //     // Create Contact record (Payer)
    //     Contact payer = new Contact(
    //         LastName = 'Test Payer',
    //         Email = 'vyom.s@mvclouds.com'
    //     );
    //     Contact payerNoEmail = new Contact(
    //         LastName = 'Test Payer No Email'
    //     );
    //     insert new List<Contact>{payer, payerNoEmail};
        
    //     // Create Payment_Plan__c record
    //     Payment_Plan__c paymentPlan = new Payment_Plan__c(
    //         Payer__c = payer.Id
    //     );
    //     Payment_Plan__c paymentPlanNoEmail = new Payment_Plan__c(
    //         Payer__c = payerNoEmail.Id
    //     );
    //     insert new List<Payment_Plan__c>{paymentPlan, paymentPlanNoEmail};
        
    //     // Create Payment_Schedule__c record
    //     Payment_Schedule__c paymentSchedule = new Payment_Schedule__c(
    //         Payment_Plan__c = paymentPlan.Id,
    //         Installment_Type__c = 'Monthly',
    //         Amount__c = 10000,
    //         Due_Date__c = Date.today().addDays(30),
    //         Status__c = 'Upcoming'
    //     );
    //     Payment_Schedule__c paymentScheduleNoEmail = new Payment_Schedule__c(
    //         Payment_Plan__c = paymentPlanNoEmail.Id,
    //         Installment_Type__c = 'Monthly',
    //         Amount__c = 5000,
    //         Due_Date__c = Date.today().addDays(15),
    //         Status__c = 'Upcoming'
    //     );
    //     insert new List<Payment_Schedule__c>{paymentSchedule, paymentScheduleNoEmail};
        
    //     // Create EmailTemplate record
    //     System.runAs(new User(Id = UserInfo.getUserId())) {
    //         EmailTemplate template = new EmailTemplate(
    //             DeveloperName = 'InvoiceEmailTemplate',
    //             Name = 'Invoice Email',
    //             TemplateType = 'text',
    //             FolderId = UserInfo.getUserId(),
    //             Subject = 'Invoice for Payment',
    //             Body = 'Dear {{Contact.Name}}, please find your invoice attached.',
    //             HtmlValue = '<p>Dear {{Contact.Name}}, please find your invoice attached.</p>'
    //         );
    //         insert template;
    //     }
    // }
    
    // // Test getPayerDetails with valid Payment Schedule ID
    // @isTest
    // static void testGetPayerDetailsSuccess() {
    //     Payment_Schedule__c paymentSchedule = [SELECT Id FROM Payment_Schedule__c WHERE Payment_Plan__r.Payer__r.Email != null LIMIT 1];
        
    //     Test.startTest();
    //     Map<String, String> payerDetails = CreateInstallmentInvoiceController.getPayerDetails(paymentSchedule.Id);
    //     Test.stopTest();
        
    //     // Verify results
    //     System.assertNotEquals(null, payerDetails, 'Payer details should not be null');
    //     System.assertEquals('Test Payer', payerDetails.get('label'), 'Payer name should be Test Payer');
    //     System.assertEquals('payer@example.com', payerDetails.get('email'), 'Payer email should be payer@example.com');
    //     System.assertNotEquals(null, payerDetails.get('value'), 'Payer ID should be present');
    // }
    
    // // Test getPayerDetails with invalid Payment Schedule ID
    // @isTest
    // static void testGetPayerDetailsInvalidId() {
    //     Payment_Schedule__c paymentSchedule = [SELECT Id FROM Payment_Schedule__c WHERE Payment_Plan__r.Payer__r.Email != null LIMIT 1];
    //     Test.startTest();
    //     CreateInstallmentInvoiceController.getPayerDetails(paymentSchedule.Id);
    //     System.assert(false, 'Expected AuraHandledException for invalid ID');
    //     Test.stopTest();
    // }
    
    // // Test getPayerDetails with no Payer
    // @isTest
    // static void testGetPayerDetailsNoPayer() {
    //     Payment_Schedule__c paymentSchedule = [SELECT Id, Payment_Plan__c FROM Payment_Schedule__c WHERE Payment_Plan__r.Payer__r.Email != null LIMIT 1];
    //     Payment_Plan__c paymentPlan = [SELECT Id FROM Payment_Plan__c WHERE Id = :paymentSchedule.Payment_Plan__c];
    //     paymentPlan.Payer__c = null;
    //     update paymentPlan;
        
    //     Test.startTest();
    //     Map<String, String> payerDetails = CreateInstallmentInvoiceController.getPayerDetails(paymentSchedule.Id);
    //     Test.stopTest();
        
    //     // Verify empty results
    //     System.assertEquals(0, payerDetails.size(), 'Payer details should be empty when no Payer is associated');
    // }
    
    // // Test sendInvoiceEmail with valid data
    // @isTest
    // static void testSendInvoiceEmailSuccess() {
    //     Payment_Schedule__c paymentSchedule = [SELECT Id FROM Payment_Schedule__c WHERE Payment_Plan__r.Payer__r.Email != null LIMIT 1];
    //     String base64Pdf = 'JVBERi0xLjQKMSAwIG9iago8PC9UeXBlL0NhdGFsb2cvUGFnZXMgMiAwIFI+PgplbmRvYmo='; // Sample valid Base64 PDF
        
    //     Test.startTest();
    //     String result = CreateInstallmentInvoiceController.sendInvoiceEmail(paymentSchedule.Id, base64Pdf);
    //     Test.stopTest();
        
    // }
    
    // // Test sendInvoiceEmail with no email address
    // @isTest
    // static void testSendInvoiceEmailNoEmail() {
    //     Payment_Schedule__c paymentSchedule = [SELECT Id FROM Payment_Schedule__c WHERE Payment_Plan__r.Payer__r.Email = null LIMIT 1];
    //     String base64Pdf = 'JVBERi0xLjQKMSAwIG9iago8PC9UeXBlL0NhdGFsb2cvUGFnZXMgMiAwIFI+PgplbmRvYmo=';
        
    //     Test.startTest();
    //     String result = CreateInstallmentInvoiceController.sendInvoiceEmail(paymentSchedule.Id, base64Pdf);
    //     Test.stopTest();
        
    //     // Verify error
    //     System.assertEquals('No valid email found for the payer', result, 'Should return error for missing email');
    // }
    
    // // Test sendInvoiceEmail with no email template
    // @isTest
    // static void testSendInvoiceEmailNoTemplate() {
    //     Payment_Schedule__c paymentSchedule = [SELECT Id FROM Payment_Schedule__c WHERE Payment_Plan__r.Payer__r.Email != null LIMIT 1];
    //     String base64Pdf = 'JVBERi0xLjQKMSAwIG9iago8PC9UeXBlL0NhdGFsb2cvUGFnZXMgMiAwIFI+PgplbmRvYmo=';
    
        
    //     Test.startTest();
    //     String result = CreateInstallmentInvoiceController.sendInvoiceEmail(paymentSchedule.Id, base64Pdf);
    //     Test.stopTest();
    
    // }
    
    // // Test sendInvoiceEmail with invalid Base64
    // @isTest
    // static void testSendInvoiceEmailInvalidBase64() {
    //     Payment_Schedule__c paymentSchedule = [SELECT Id FROM Payment_Schedule__c WHERE Payment_Plan__r.Payer__r.Email != null LIMIT 1];
    //     String invalidBase64 = 'InvalidBase64String';
        
    //     Test.startTest();
    //     String result = CreateInstallmentInvoiceController.sendInvoiceEmail(paymentSchedule.Id, invalidBase64);
    //     Test.stopTest();
        
    // }
    
    // // Test sendInvoiceEmail with empty Base64
    // @isTest
    // static void testSendInvoiceEmailEmptyBase64() {
    //     Payment_Schedule__c paymentSchedule = [SELECT Id FROM Payment_Schedule__c WHERE Payment_Plan__r.Payer__r.Email != null LIMIT 1];
    //     String emptyBase64 = '';
        
    //     Test.startTest();
    //     String result = CreateInstallmentInvoiceController.sendInvoiceEmail(paymentSchedule.Id, emptyBase64);
    //     Test.stopTest();
        
    //     // Verify error
    //     System.assertEquals('PDF data is empty or invalid', result, 'Should return error for empty Base64');
    // }
    
    // // Test sendInvoiceEmail with email send failure
    // @isTest
    // static void testSendInvoiceEmailFailure() {
    //     Payment_Schedule__c paymentSchedule = [SELECT Id FROM Payment_Schedule__c WHERE Payment_Plan__r.Payer__r.Email != null LIMIT 1];
    //     String base64Pdf = 'JVBERi0xLjQKMSAwIG9iago8PC9UeXBlL0NhdGFsb2cvUGFnZXMgMiAwIFI+PgplbmRvYmo=';
        
    //     // Simulate email failure by setting an invalid email address
    //     Contact payer = [SELECT Id FROM Contact WHERE Email = 'vyom.s@mvclouds.com' LIMIT 1];
    //     payer.Email = 'syom@mvclouds.com';
    //     update payer;
        
    //     Test.startTest();
    //     String result = CreateInstallmentInvoiceController.sendInvoiceEmail(paymentSchedule.Id, base64Pdf);
    //     Test.stopTest();
        
    // }
    
    // // Test sendInvoiceEmail with exception
    // @isTest
    // static void testSendInvoiceEmailException() {
    //     String invalidId = 'invalidId';
    //     String base64Pdf = 'JVBERi0xLjQKMSAwIG9iago8PC9UeXBlL0NhdGFsb2cvUGFnZXMgMiAwIFI+PgplbmRvYmo=';
        
    //     Test.startTest();
    //     String result = CreateInstallmentInvoiceController.sendInvoiceEmail(invalidId, base64Pdf);
    //     Test.stopTest();
    
    // }
}