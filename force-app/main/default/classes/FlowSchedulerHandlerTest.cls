@isTest
private class FlowSchedulerHandlerTest {

    // @testSetup
    // static void setupData() {

    //     // Create Contact (Payer)
    //     Contact payer = new Contact(
    //         FirstName = 'Flow',
    //         LastName = 'User',
    //         Email = 'flowuser@test.com'
    //     );
    //     insert payer;

    //     // Create Email Template (used by PaymentScheduleReminder)
    //     Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

    //     User u = new User(
    //         Alias = 'flowu',
    //         Email = 'flowuser@test.com',
    //         EmailEncodingKey = 'UTF-8',
    //         LastName = 'FlowUser',
    //         LanguageLocaleKey = 'en_US',
    //         LocaleSidKey = 'en_US',
    //         ProfileId = p.Id,
    //         TimeZoneSidKey = 'Asia/Kolkata',
    //         UserName = 'flowuser' + System.currentTimeMillis() + '@test.com'
    //     );
    //     insert u;

    //     System.runAs(u) {
    //         EmailTemplate template = new EmailTemplate(
    //             Name = 'Payment Reminder Template',
    //             DeveloperName = 'PaymentReminderEmailTemplate',
    //             FolderId = UserInfo.getUserId(),
    //             TemplateType = 'text',
    //             Subject = 'Reminder',
    //             Body = 'Reminder Body'
    //         );
    //         insert template;
    //     }

    //     // Create Payment Schedule records
    //     List<Payment_Schedule__c> schedules = new List<Payment_Schedule__c>{
    //         new Payment_Schedule__c(
    //             Payer__c = payer.Id,
    //             Status__c = 'Upcoming'
    //         ),
    //         new Payment_Schedule__c(
    //             Payer__c = payer.Id,
    //             Status__c = 'Paid'
    //         )
    //     };

    //     insert schedules;
    // }

    // // ---------------------------------------
    // // Test: Valid Flow Input
    // // ---------------------------------------
    // @isTest
    // static void testHandleInstallments_Success() {

    //     List<Payment_Schedule__c> schedules = [
    //         SELECT Id, Payer__c, Status__c
    //         FROM Payment_Schedule__c
    //     ];

    //     // Prepare Flow input wrapper
    //     FlowSchedulerHandler.FlowInputs inputWrapper = new FlowSchedulerHandler.FlowInputs();
    //     inputWrapper.installmentsFromFlow = schedules;

    //     List<FlowSchedulerHandler.FlowInputs> inputs = new List<FlowSchedulerHandler.FlowInputs>{ inputWrapper };

    //     Test.startTest();

    //     FlowSchedulerHandler.handleInstallments(inputs);

    //     Test.stopTest();

    //     // Only one email should be sent (Upcoming one)
    //     System.assertEquals(1, Limits.getEmailInvocations());
    // }

    // // ---------------------------------------
    // // Test: Empty Input
    // // ---------------------------------------
    // @isTest
    // static void testHandleInstallments_EmptyInput() {

    //     List<FlowSchedulerHandler.FlowInputs> inputs = new List<FlowSchedulerHandler.FlowInputs>();

    //     Test.startTest();

    //     FlowSchedulerHandler.handleInstallments(inputs);

    //     Test.stopTest();

    // }

    // // ---------------------------------------
    // // Test: Null Installment List inside wrapper
    // // ---------------------------------------
    // @isTest
    // static void testHandleInstallments_NullInstallments() {

    //     FlowSchedulerHandler.FlowInputs inputWrapper = new FlowSchedulerHandler.FlowInputs();
    //     inputWrapper.installmentsFromFlow = null;

    //     List<FlowSchedulerHandler.FlowInputs> inputs = new List<FlowSchedulerHandler.FlowInputs>{ inputWrapper };

    //     Test.startTest();

    //     FlowSchedulerHandler.handleInstallments(inputs);

    //     Test.stopTest();

    // }
}