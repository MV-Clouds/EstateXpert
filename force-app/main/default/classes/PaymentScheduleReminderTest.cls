@isTest
private class PaymentScheduleReminderTest {

    @testSetup
    static void setupTestData() {

        // Create a user for runAs
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            Alias = 'testu',
            Email = 'testuser@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Test',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            UserName = 'testuser' + System.currentTimeMillis() + '@test.com'
        );
        insert u;   

        // Create EmailTemplate inside runAs (separate setup context)
        System.runAs(u) {
            EmailTemplate template = new EmailTemplate(
                Name = 'Payment Reminder Template',
                DeveloperName = 'PaymentReminderEmailTemplate',
                FolderId = UserInfo.getUserId(),
                TemplateType = 'text',
                Subject = 'Payment Reminder',
                Body = 'Reminder email body'
            );
            insert template;
        }

        // Create non-setup data AFTER
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'test@example.com'
        );
        insert testContact;

        List<Payment_Schedule__c> schedules = new List<Payment_Schedule__c>{
            new Payment_Schedule__c(
                Payer__c = testContact.Id,
                Status__c = 'Upcoming'
            ),
            new Payment_Schedule__c(
                Payer__c = testContact.Id,
                Status__c = 'Paid'
            ),
            new Payment_Schedule__c(
                Status__c = 'Upcoming'
            )
        };

        insert schedules;
    }

    @isTest
    static void testSendReminderEmails() {

        Map<Id, Payment_Schedule__c> installmentMap = new Map<Id, Payment_Schedule__c>(
            [SELECT Id, Payer__c, Status__c FROM Payment_Schedule__c]
        );

        Test.startTest();

        new PaymentScheduleReminder().sendReminderEmails(installmentMap);

        Test.stopTest();

        System.assertEquals(1, Limits.getEmailInvocations());
    }
}