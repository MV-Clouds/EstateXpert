@IsTest
public class SiteVisitReminderControllerTest {

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

        // Showing Record as Event
        Id showingRecordTypeId = Schema.SObjectType.Event.getRecordTypeInfosByDeveloperName().get('Showing').getRecordTypeId();
        Event showing = new Event(
            RecordTypeId = showingRecordTypeId,
            Buyer__c = con.Id,
            MVEX__Scheduled_Date__c = System.now().addDays(1),
            Status__c = 'Scheduled',
            Subject = 'Showing',
            MVEX__Showing_Duration__c = 60,
            StartDateTime = System.now().addDays(1)
        );
        insert showing;
    }

    @IsTest
    static void testSendShowingReminders() {

        // Mock callout
        //Test.setMock(HttpCalloutMock.class, new WhatsAppCalloutMock());

        Event sh = [SELECT Id FROM Event LIMIT 1];

        Test.startTest();
            SiteVisitReminderController.sendShowingReminders(
                new List<Id>{ sh.Id }
            );
        Test.stopTest(); // executes @future
       
        // Chat record should be created
        List<Chat__c> chats = [
            SELECT Id, Phone__c, Message_Type__c
            FROM Chat__c
        ];
        System.assertEquals(1, chats.size());
        System.assertEquals('Template', chats[0].Message_Type__c);
    }

    @IsTest
    static void testBuyerPhoneMissing() {

        Contact c = new Contact(LastName='No Phone');
        insert c;

        Id showingRecordTypeId = Schema.SObjectType.Event.getRecordTypeInfosByDeveloperName().get('Showing').getRecordTypeId();
        Event sh = new Event(
            RecordTypeId = showingRecordTypeId,
            Buyer__c = c.Id,
            Status__c = 'Scheduled',
            Scheduled_Date__c = System.now(),
            Subject = 'Showing',
            MVEX__Showing_Duration__c = 60,
            StartDateTime = System.now()
        );
        insert sh;

        Test.startTest();
            SiteVisitReminderController.sendShowingReminders(
                new List<Id>{ sh.Id }
            );
        Test.stopTest();

        // No chat should be created
        System.assertEquals(0, [SELECT COUNT() FROM Chat__c]);
    }

    @IsTest
    static void testStatusNotScheduled() {

        Contact c = new Contact(LastName='Buyer', Phone='911111111111');
        insert c;

        Id showingRecordTypeId = Schema.SObjectType.Event.getRecordTypeInfosByDeveloperName().get('Showing').getRecordTypeId();
        Event sh = new Event(
            RecordTypeId = showingRecordTypeId,
            Buyer__c = c.Id,
            Status__c = 'Completed',
            Scheduled_Date__c = System.now(),
            Subject = 'Showing',
            MVEX__Showing_Duration__c = 60,
            StartDateTime = System.now()
        );
        insert sh;

        Test.startTest();
            SiteVisitReminderController.sendShowingReminders(
                new List<Id>{ sh.Id }
            );
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Chat__c]);
    }
}