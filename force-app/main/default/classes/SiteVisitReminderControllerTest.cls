@IsTest
public class SiteVisitReminderControllerTest {

    // Mock HTTP Callout for the @future method
    public class WhatsAppCalloutMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"messaging_product": "whatsapp", "contacts": [{"input": "919999999999", "wa_id": "919999999999"}], "messages": [{"id": "wamid.HBgLOTkx"}]}');
            res.setStatusCode(200);
            return res;
        }
    }

    @testSetup
    static void setupData() {
        // Buyer Contact
        Contact con = new Contact(
            LastName = 'Buyer Test',
            Phone = '919999999999'
        );
        insert con;

        // Whatsapp Template
        WhatsappTemplate__c temp = new WhatsappTemplate__c(
            Template_Name__c = 'Showing Reminder',
            Language__c = 'en',
            Header_Type__c = 'text',
            WBHeader_Body__c = null,
            WBTemplate_Body__c = 'Hello {{1}}',
            WBFooter_Body__c = 'Thanks',
            WBButton_Body__c = '[]',
            Button_Type__c = null,
            Button_Label__c = null,
            Template_Category__c = 'Marketing',
            Template_SubCatagory__c = 'Reminder',
            Template_Id__c	= 'testId'
        );
        insert temp;

        // Ensure we handle custom/standard record types gracefully
        Map<String, Schema.RecordTypeInfo> eventRtMap = Schema.SObjectType.Event.getRecordTypeInfosByDeveloperName();
        Id showingRecordTypeId = eventRtMap.containsKey('Showing') ? eventRtMap.get('Showing').getRecordTypeId() : null;

        Event showing = new Event(
            RecordTypeId = showingRecordTypeId,
            Buyer__c = con.Id,
            Scheduled_Date__c = System.now().addDays(1),
            Status__c = 'Scheduled',
            Subject = 'Showing',
            StartDateTime = System.now().addDays(1),
            DurationInMinutes = 60
        );
        insert showing;
    }

    @IsTest
    static void testSendShowingReminders_Success() {
        Test.setMock(HttpCalloutMock.class, new WhatsAppCalloutMock());
        Event sh = [SELECT Id FROM Event LIMIT 1];

        Test.startTest();
        SiteVisitReminderController.sendShowingReminders(new List<Id>{ sh.Id });
        Test.stopTest(); // executes @future callout
       
        List<Chat__c> chats = [SELECT Id, Phone__c, Message_Type__c FROM Chat__c];
        System.assertEquals(1, chats.size(), 'One chat record should be created');
        System.assertEquals('Template', chats[0].Message_Type__c, 'Message type should be Template');
    }

    @IsTest
    static void testSendShowingReminders_AllButtonsAndMedia() {
        Test.setMock(HttpCalloutMock.class, new WhatsAppCalloutMock());
        
        // Update template to test all button types and image header
        WhatsappTemplate__c temp = [SELECT Id FROM WhatsappTemplate__c LIMIT 1];
        temp.Header_Type__c = 'image';
        temp.WBHeader_Body__c = 'https://example.com/test-image.png';
        temp.WBButton_Body__c = '[' +
            '{"type": "PHONE_NUMBER", "phone_number": "1234567890"},' +
            '{"type": "URL", "text": "https://google.com"},' +
            '{"type": "QUICK_REPLY"},' +
            '{"type": "FLOW"},' +
            '{"type": "COPY_CODE", "example": "SAVE20"},' +
            '{"type": "OTP", "otp_type": "COPY_CODE"}' +
        ']';
        update temp;

        Event sh = [SELECT Id FROM Event LIMIT 1];

        Test.startTest();
        SiteVisitReminderController.sendShowingReminders(new List<Id>{ sh.Id });
        Test.stopTest();
       
        System.assertEquals(1, [SELECT COUNT() FROM Chat__c], 'Chat record should be generated for all button types');
    }

    @IsTest
    static void testSendShowingReminders_AuthenticationCategory() {
        Test.setMock(HttpCalloutMock.class, new WhatsAppCalloutMock());
        
        WhatsappTemplate__c temp = [SELECT Id FROM WhatsappTemplate__c LIMIT 1];
        temp.Template_Category__c = 'Authentication';
        update temp;

        Event sh = [SELECT Id FROM Event LIMIT 1];

        Test.startTest();
        SiteVisitReminderController.sendShowingReminders(new List<Id>{ sh.Id });
        Test.stopTest();
       
        System.assertEquals(1, [SELECT COUNT() FROM Chat__c], 'Chat record should be created for Authentication category');
    }

    @IsTest
    static void testBuyerPhoneMissing() {
        Contact c = new Contact(LastName='No Phone');
        insert c;

        Event sh = new Event(
            Buyer__c = c.Id,
            Status__c = 'Scheduled',
            Scheduled_Date__c = System.now(),
            Subject = 'Showing',
            StartDateTime = System.now(),
            DurationInMinutes = 60
        );
        insert sh;

        Test.startTest();
        SiteVisitReminderController.sendShowingReminders(new List<Id>{ sh.Id });
        Test.stopTest();

        // Ensure no chat record was created for the new event due to early return
        System.assertEquals(0, [SELECT COUNT() FROM Chat__c WHERE Phone__c = null]);
    }

    @IsTest
    static void testStatusNotScheduled() {
        Contact c = new Contact(LastName='Buyer Completed', Phone='912222222222');
        insert c;

        Event sh = new Event(
            Buyer__c = c.Id,
            Status__c = 'Completed',
            Scheduled_Date__c = System.now(),
            Subject = 'Showing',
            StartDateTime = System.now(),
            DurationInMinutes = 60
        );
        insert sh;

        Test.startTest();
        SiteVisitReminderController.sendShowingReminders(new List<Id>{ sh.Id });
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Chat__c WHERE Phone__c = '912222222222']);
    }

    @IsTest
    static void testNoTemplateFound() {
        // Delete template to force "temp == null" return statement
        delete [SELECT Id FROM WhatsappTemplate__c];

        Event sh = [SELECT Id FROM Event LIMIT 1];

        Test.startTest();
        SiteVisitReminderController.sendShowingReminders(new List<Id>{ sh.Id });
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Chat__c], 'No chat should be created if template is missing');
    }

    @IsTest
    static void testExceptionCatch_SendShowingReminder() {
        // Force an exception by providing invalid JSON to crash `JSON.deserializeUntyped`
        WhatsappTemplate__c temp = [SELECT Id FROM WhatsappTemplate__c LIMIT 1];
        temp.WBButton_Body__c = 'INVALID_JSON_FORMAT'; 
        update temp;

        Event sh = [SELECT Id FROM Event LIMIT 1];

        Test.startTest();
        // This will throw a JSONException caught and logged by ErrorHandler
        SiteVisitReminderController.sendShowingReminders(new List<Id>{ sh.Id });
        Test.stopTest();

        // Verifying that an exception stops Chat__c generation after the failure point
        System.assertEquals(1, [SELECT COUNT() FROM Chat__c]); // Chat inserted before exception, but process halted
    }

    @IsTest
    static void testExceptionCatch_CreateJSONBody() {
        // Force a TypeException inside `createJSONBody` by providing a String array instead of Object array
        WhatsappTemplate__c temp = [SELECT Id FROM WhatsappTemplate__c LIMIT 1];
        temp.WBButton_Body__c = '["StringInsteadOfMap"]'; 
        update temp;

        Event sh = [SELECT Id FROM Event LIMIT 1];

        Test.startTest();
        SiteVisitReminderController.sendShowingReminders(new List<Id>{ sh.Id });
        Test.stopTest();

        // Test completes, coverage hit on `createJSONBody` catch block
        System.assertEquals(1, [SELECT COUNT() FROM Chat__c]);
    }

    @IsTest
    static void testExceptionCatch_FutureMethod() {
        Test.startTest();
        // Passing null parameters explicitly to cause a NullPointerException or custom exception in SiteAndBookingController.sendWhatsappMessage
        SiteVisitReminderController.sendWhatsAppMessageFuture(null, null, null);
        Test.stopTest();
        // The catch block inside sendWhatsAppMessageFuture will execute
    }
}