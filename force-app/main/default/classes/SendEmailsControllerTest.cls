@IsTest
public class SendEmailsControllerTest {

    @testSetup
    static void setupData() {

        /* ---------------- CUSTOM SETTINGS ---------------- */

        OutlookConfig__c outlook = new OutlookConfig__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Refresh_Token_1__c = 'test-refresh-token'
        );
        insert outlook;

        GmailConfig__c gmail = new GmailConfig__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Refresh_Token__c = 'test-refresh-token'
        );
        insert gmail;
   

        /* ---------------- CUSTOM TEMPLATE OBJECT ---------------- */

        Template__c tmpl = new Template__c(
            Template_Name__c = 'Marketing Template 1',
            Subject__c = 'Custom Subject',
            Object_API_Name__c = 'Listing__c',
            Template_Status__c = true,
            Template_pattern__c = 'Marketing Template'
        );
        insert tmpl;

        Template_Data__c td1 = new Template_Data__c(
            Template__c = tmpl.Id,
            Value_Type__c = 'Body Value',
            Template_Value_Simple__c = 'Hello '
        );

        Template_Data__c td2 = new Template_Data__c(
            Template__c = tmpl.Id,
            Value_Type__c = 'Body Value',
            Template_Value_Simple__c = '{{Listing__c.Name}}'
        );

        insert new List<Template_Data__c>{ td1, td2 };

        /* ---------------- LISTING ---------------- */

        Listing__c listing = new Listing__c(
            Name = 'Test Listing',
            Address__c = 'Test Address',
            Listing_Type__c = 'Sale',
            Listing_Price__c = 500000,
            Status__c = 'Active'
        );
        insert listing;

        /* ---------------- CONTACT ---------------- */

        List<Contact> cons = new List<Contact>();
        for (Integer i = 0; i < 3; i++) {
            cons.add(new Contact(
                LastName = 'Contact ' + i,
                Email = 'test' + i + '@mail.com',
                Phone = '99999999' + i
            ));
        }
        insert cons;
    }

    /* ---------------- getMessagingServiceOptions ---------------- */
    @IsTest
    static void testGetMessagingServiceOptions() {

        Test.startTest();
        List<Map<String,String>> options = SendEmailsController.getMessagingServiceOptions();
        Test.stopTest();

        System.assert(options.size() >= 1, 'At least Single Messaging should exist');

        Set<String> values = new Set<String>();
        for (Map<String,String> m : options) {
            values.add(m.get('value'));
        }

        System.assert(values.contains('single'));
        System.assert(values.contains('outlook'));
        System.assert(values.contains('gmail'));
    }

    /* ---------------- getTemplatesByObject ---------------- */
    @IsTest
    static void testGetTemplatesByObject() {

        Test.startTest();
        Map<String,Object> res = SendEmailsController.getTemplatesByObject();
        Test.stopTest();

        System.assert(res.containsKey('emailTemplates'));
        System.assert(res.containsKey('customTemplates'));

        List<Object> emailTemps = (List<Object>)res.get('emailTemplates');
        List<Object> customTemps = (List<Object>)res.get('customTemplates');

        System.assert(emailTemps.size() > 0, 'Email templates should be returned');
        System.assert(customTemps.size() > 0, 'Custom templates should be returned');
    }

    /* ---------------- getListings ---------------- */
    @IsTest
    static void testGetListings() {

        Test.startTest();
        List<Listing__c> listings = SendEmailsController.getListings();
        Test.stopTest();

        System.assert(listings.size() > 0);
    }

    /* ---------------- getAllContacts ---------------- */
    @IsTest
    static void testGetAllContacts() {

        Test.startTest();
        List<Contact> contacts = SendEmailsController.getAllContacts();
        Test.stopTest();

        System.assert(contacts.size() >= 3);
    }
}