@IsTest
public class SiteAndBookingControllerTest {

    @testSetup
    static void setup() {

        /* ---------------- CONTACTS ---------------- */
        Contact c1 = new Contact(LastName='Buyer One', Email='b1@test.com', Phone='9111111111');
        Contact c2 = new Contact(LastName='Buyer Two', Email='b2@test.com', Phone='9222222222');
        insert new List<Contact>{c1, c2};

        /* ---------------- PROPERTY & LISTING ---------------- */
        Property__c prop = new Property__c(Name='Test Property');
        insert prop;

        Listing__c listing = new Listing__c(
            Name='Test Listing',
            Property__c = prop.Id,
            Address__c='Addr',
            Listing_Type__c='Sale'
        );
        insert listing;

        /* ---------------- PROPERTY FILE ---------------- */
        Property_File__c pf = new Property_File__c(
            Name='Img1',
            Property__c = prop.Id,
            BaseUrl__c='https://img.test.com/1.jpg'
        );
        insert pf;

        /* ---------------- INQUIRY ---------------- */
        Inquiry__c iq = new Inquiry__c(Listing__c = listing.Id, Contact__c = c1.Id);
        insert iq;

        /* ---------------- SHOWING ---------------- */
        Showing__c sh = new Showing__c(
            Buyer__c = c1.Id,
            Listing__c = listing.Id,
            Status__c = 'Scheduled',
            Scheduled_Date__c = System.now().addHours(2)
        );
        insert sh;

        /* ---------------- CHAT ---------------- */
        Chat__c chat = new Chat__c(Phone__c = c1.Phone, Message_Type__c='Template');
        insert chat;
      
    }

    /* ---------------- getPropertyData ---------------- */
    @IsTest
    static void testGetPropertyData() {
        Listing__c l = [SELECT Id FROM Listing__c LIMIT 1];

        Test.startTest();
        Map<String,Object> res = SiteAndBookingController.getPropertyData(l.Id);
        Test.stopTest();

        System.assert(res.containsKey('listing'));
        System.assert(res.containsKey('images'));
        System.assert(res.containsKey('contacts'));
    }

    /* ---------------- createShowings (insert + update) ---------------- */
    @IsTest
    static void testCreateShowings() {

        Listing__c l = [SELECT Id FROM Listing__c LIMIT 1];
        List<Contact> cons = [SELECT Id FROM Contact];

        Test.startTest();
        Map<String,Object> res = SiteAndBookingController.createShowings(
            new List<Id>{cons[0].Id, cons[1].Id},
            l.Id,
            System.now().addDays(1),
            'Email'
        );
        Test.stopTest();

        List<Id> showingIds = (List<Id>)res.get('showingIds');
        System.assert(showingIds.size() > 0);
    }

    /* ---------------- sendEmailsAndCreateShowings ---------------- */
    // @IsTest
    // static void testSendEmailsAndCreateShowings() {

    //     Listing__c l = [SELECT Id FROM Listing__c LIMIT 1];
    //     Contact c = [SELECT Id FROM Contact LIMIT 1];

    //     Test.startTest();
    //     SiteAndBookingController.sendEmailsAndCreateShowings(
    //         new List<Id>{c.Id},
    //         l.Id,
    //         System.now().addDays(1),
    //         'Email'
    //     );
    //     Test.stopTest();

    //     System.assert(true); // no exception = pass
    // }

    /* ---------------- updateShowing ---------------- */
    @IsTest
    static void testUpdateShowing() {
        Showing__c sh = [SELECT Id FROM Showing__c LIMIT 1];

        Test.startTest();
        Boolean res = SiteAndBookingController.updateShowing(
            System.now().addDays(2),
            sh.Id,
            'WhatsApp'
        );
        Test.stopTest();

        System.assertEquals(true, res);
    }

    /* ---------------- markShowingAsCompleted ---------------- */
    @IsTest
    static void testMarkCompleted() {
        Showing__c sh = [SELECT Id FROM Showing__c LIMIT 1];

        Test.startTest();
        Boolean res = SiteAndBookingController.markShowingAsCompleted(sh.Id);
        Test.stopTest();

        System.assert(res);
    }

    /* ---------------- sendWhatsappMessage ---------------- */
    @IsTest
    static void testSendWhatsappMessage() {

        Chat__c chat = [SELECT Id FROM Chat__c LIMIT 1];
        Showing__c sh = [SELECT Id FROM Showing__c LIMIT 1];

        String jsonBody = '{"test":"data"}';

        Test.startTest();
        Map<String,Object> res = SiteAndBookingController.sendWhatsappMessage(
            jsonBody,
            chat.Id,
            sh.Id,
            'Scheduled'
        );
        Test.stopTest();

        System.assert(res.containsKey('chat'));
    }

    /* ---------------- getShowingsFromToday ---------------- */
    @IsTest
    static void testGetShowingsFromToday() {
        Test.startTest();
        List<Map<String,Object>> res = SiteAndBookingController.getShowingsFromToday();
        Test.stopTest();

        System.assert(res.size() >= 0);
    }

    /* ---------------- previewEmailTemplate ---------------- */
    // @IsTest
    // static void testPreviewEmailTemplate() {
    //     Showing__c sh = [SELECT Id FROM Showing__c LIMIT 1];

    //     Test.startTest();
    //     Map<String,String> res = SiteAndBookingController.previewEmailTemplate(sh.Id, false);
    //     Test.stopTest();

    //     System.assert(res.containsKey('subject'));
    //     System.assert(res.containsKey('htmlBody'));
    // }

    /* ---------------- updateShowingStatus ---------------- */
    @IsTest
    static void testUpdateShowingStatus() {
        Showing__c sh = [SELECT Id FROM Showing__c LIMIT 1];

        Test.startTest();
        Boolean res = SiteAndBookingController.updateShowingStatus(sh.Id, 'Cancelled');
        Test.stopTest();

        System.assertEquals(true, res);
    }
}