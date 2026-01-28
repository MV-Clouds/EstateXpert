@isTest
public class EmailCampaignSchedulerTest {
    
    @testSetup
    static void setup() {
        // Create test contacts
        List<Contact> contacts = new List<Contact>();
        contacts.add(new Contact(LastName = 'Test Contact 1', Email = 'contact1@example.com', FirstName = 'John'));
        contacts.add(new Contact(LastName = 'Test Contact 2', Email = 'contact2@example.com', FirstName = 'Jane'));
        insert contacts;

        // Create test marketing campaigns with Schedule_Type__c
        List<Marketing_Campaign__c> campaigns = new List<Marketing_Campaign__c>();
        campaigns.add(new Marketing_Campaign__c(
            Label__c = 'Test Campaign 1',
            Is_Marketing_Campaign_Template__c = true,
            Email_Type__c = 'single',
            Schedule_Type__c = 'Specific Date',
            Start_Date__c = Date.today(),
            Campaign_Start_Date__c = Date.today(),
            RelatedObject__c = 'Contact',
            Remaining_Emails__c = 5,
            Status__c = 'New',
            Total_Sent_Mails__c = 0
        ));
        campaigns.add(new Marketing_Campaign__c(
            Label__c = 'Test Campaign 3',
            Is_Marketing_Campaign_Template__c = true,
            Email_Type__c = 'outlook',
            Schedule_Type__c = 'Specific Date',
            Start_Date__c = Date.today(),
            Campaign_Start_Date__c = Date.today(),
            RelatedObject__c = 'Contact',
            Remaining_Emails__c = 10,
            Status__c = 'New',
            Total_Sent_Mails__c = 0
        ));
        insert campaigns;

        // Create Marketing Campaign Members
        List<Marketing_Campaign_Member__c> members = new List<Marketing_Campaign_Member__c>();
        members.add(new Marketing_Campaign_Member__c(
            Marketing_Campaign__c = campaigns[0].Id,
            Contact__c = contacts[0].Id
        ));
        members.add(new Marketing_Campaign_Member__c(
            Marketing_Campaign__c = campaigns[1].Id,
            Contact__c = contacts[1].Id
        ));
        insert members;

        // Create Templates
        Template__c template = new Template__c();
        template.Template_Name__c = 'Test Template';
        template.Template_pattern__c = 'PDF Template';
        template.Object_API_Name__c = 'Contact';
        template.Template_Status__c = true;
        insert template;

        Template_Page__c page = new Template_Page__c();
        page.Template__c = template.Id;
        page.Page_Number__c = 1;
        page.Page_Margin__c = '1;1;1;1';
        page.Page_Orientation__c = 'portrait';
        page.Page_Size__c = 'a4';
        page.Unit_of_Page_Configs__c = 'inch';
        insert page;

        Template_Data__c templateField = new Template_Data__c();
        templateField.Template__c = template.Id;
        templateField.Value_Type__c = 'Body Value';
        templateField.Template_Value_Simple__c = '<html><body><p>Hello {!Contact.FirstName} {!Contact.LastName}</p></body></html>';
        templateField.Order_No_Simple__c = 1;
        insert templateField;

        Template_Data__c templateField2 = new Template_Data__c();
        templateField2.Template__c = template.Id;
        templateField2.Value_Type__c = 'Extracted Mapping Keys';
        templateField2.Template_Value_Simple__c = '["Contact.FirstName","Contact.LastName","Contact.Email"]';
        templateField2.Order_No_Simple__c = 2;
        insert templateField2;

        // Create Marketing Emails
        List<Marketing_Email__c> marketingEmails = new List<Marketing_Email__c>();
        marketingEmails.add(new Marketing_Email__c(
            Marketing_Campaign__c = campaigns[0].Id,
            Subject__c = 'Test Email 1',
            Name = 'Test Email 1',
            Template_Id__c = template.Id,
            Days_After_Start_Date__c = 0,
            TimeToSend__c = Time.newInstance(12, 0, 0, 0),
            Send_Date_Time__c = DateTime.now().addDays(1)
        ));
        marketingEmails.add(new Marketing_Email__c(
            Marketing_Campaign__c = campaigns[1].Id,
            Subject__c = 'Test Email 2',
            Name = 'Test Email 2',
            Template_Id__c = template.Id,
            Days_After_Start_Date__c = 0,
            TimeToSend__c = Time.newInstance(14, 0, 0, 0),
            Send_Date_Time__c = DateTime.now().addDays(2)
        ));
        insert marketingEmails;

        // Create Email Members
        List<Email_Member__c> emailMembers = new List<Email_Member__c>();
        emailMembers.add(new Email_Member__c(
            RecipientId__c = contacts[0].Id,
            Marketing_Email__c = marketingEmails[0].Id,
            Schedule_Date_and_Time__c = DateTime.now().addDays(1),
            Status__c = 'Sent'
        ));
        emailMembers.add(new Email_Member__c(
            RecipientId__c = contacts[1].Id,
            Marketing_Email__c = marketingEmails[1].Id,
            Schedule_Date_and_Time__c = DateTime.now().addDays(2),
            Status__c = 'Success'
        ));
        insert emailMembers;
    }

    @isTest
    static void testSendEmailsWithContactField() {
        List<Marketing_Campaign__c> campaigns = [SELECT Id FROM Marketing_Campaign__c WHERE Schedule_Type__c = 'Specific Date' LIMIT 1];
        List<Contact> contacts = [SELECT Id, Email FROM Contact LIMIT 1];
        List<Template_Data__c> templates = [SELECT Id FROM Template_Data__c LIMIT 1];
        
        EmailCampaignScheduler.EmailRequest request = new EmailCampaignScheduler.EmailRequest();
        request.email = contacts[0].Email;
        request.ccAddresses = 'CC User:cc@example.com';
        request.bccAddresses = 'BCC User:bcc@example.com';
        request.subject = 'Test Subject';
        request.body = 'Hello {!Contact.FirstName}, this is a test.';
        request.campaignId = campaigns[0].Id;
        request.contactId = contacts[0].Id;
        request.templateDataId = templates[0].Id;
        
        Test.startTest();
        EmailCampaignScheduler.sendEmails(new List<EmailCampaignScheduler.EmailRequest>{request});
        Test.stopTest();
    }

    @isTest
    static void testSendEmailsNonContactField() {
        List<Marketing_Campaign__c> campaigns = [SELECT Id FROM Marketing_Campaign__c WHERE Schedule_Type__c = 'Specific Date' LIMIT 1];
        List<Contact> contacts = [SELECT Id, Email FROM Contact LIMIT 1];
        List<Template_Data__c> templates = [SELECT Id FROM Template_Data__c LIMIT 1];
        
        EmailCampaignScheduler.EmailRequest request = new EmailCampaignScheduler.EmailRequest();
        request.email = contacts[0].Email;
        request.subject = 'Test Subject';
        request.body = 'Test body';
        request.campaignId = campaigns[0].Id;
        request.contactId = contacts[0].Id;
        request.templateDataId = templates[0].Id;
        
        Test.startTest();
        EmailCampaignScheduler.sendEmails(new List<EmailCampaignScheduler.EmailRequest>{request});
        Test.stopTest();
        
        // Should skip non-contact field campaigns
    }

    @isTest
    static void testSendEmailsMultipleRequests() {
        List<Marketing_Campaign__c> campaigns = [SELECT Id FROM Marketing_Campaign__c WHERE Schedule_Type__c = 'Specific Date'];
        List<Contact> contacts = [SELECT Id, Email FROM Contact];
        List<Template_Data__c> templates = [SELECT Id FROM Template_Data__c];
        
        List<EmailCampaignScheduler.EmailRequest> requests = new List<EmailCampaignScheduler.EmailRequest>();
        
        for (Integer i = 0; i < contacts.size() && i < campaigns.size(); i++) {
            EmailCampaignScheduler.EmailRequest request = new EmailCampaignScheduler.EmailRequest();
            request.email = contacts[i].Email;
            request.subject = 'Test Subject ' + i;
            request.body = 'Test body ' + i;
            request.campaignId = campaigns[i].Id;
            request.contactId = contacts[i].Id;
            request.templateDataId = templates[0].Id;
            requests.add(request);
        }
        
        Test.startTest();
        EmailCampaignScheduler.sendEmails(requests);
        Test.stopTest();
    }

    @isTest
    static void testParseEmailAddresses() {
        Test.startTest();
        List<String> result = EmailCampaignScheduler.parseEmailAddresses('Name1:email1@test.com@@@Name2:email2@test.com@@@Name3:email3@test.com');
        Test.stopTest();
        
        System.assertEquals(3, result.size());
        System.assertEquals('email1@test.com', result[0]);
        System.assertEquals('email2@test.com', result[1]);
        System.assertEquals('email3@test.com', result[2]);
    }

    @isTest
    static void testParseEmailAddressesInvalid() {
        Test.startTest();
        List<String> result = EmailCampaignScheduler.parseEmailAddresses('InvalidFormat');
        Test.stopTest();
        
        System.assertEquals(0, result.size());
    }

    @isTest
    static void testParseEmailAddressesEmpty() {
        Test.startTest();
        List<String> result = EmailCampaignScheduler.parseEmailAddresses('');
        Test.stopTest();
        
        System.assertNotEquals(null, result);
    }

    @isTest
    static void testGetContacts() {
        List<Contact> contacts = [SELECT Id FROM Contact];
        Set<String> contactIds = new Set<String>();
        for (Contact c : contacts) {
            contactIds.add(c.Id);
        }
        
        Test.startTest();
        List<Contact> result = EmailCampaignScheduler.getContacts(contactIds);
        Test.stopTest();
        
        System.assertEquals(contacts.size(), result.size());
    }

    @isTest
    static void testGetContactsEmpty() {
        Set<String> emptyIds = new Set<String>();
        
        Test.startTest();
        List<Contact> result = EmailCampaignScheduler.getContacts(emptyIds);
        Test.stopTest();
        
        System.assertEquals(0, result.size());
    }

    @isTest
    static void testGetAllFieldNames() {
        Test.startTest();
        List<String> result = EmailCampaignScheduler.getAllFieldNames('Contact');
        Test.stopTest();
        
        System.assertNotEquals(null, result);
        System.assert(result.size() > 0, 'Should return field names');
        System.assert(result.contains('id'), 'Should contain Id field');
    }

    @isTest
    static void testGetAllFieldNamesLead() {
        Test.startTest();
        List<String> result = EmailCampaignScheduler.getAllFieldNames('Lead');
        Test.stopTest();
        
        System.assertNotEquals(null, result);
        System.assert(result.size() > 0, 'Should return field names');
    }

    @isTest
    static void testSendEmailsWithNullContact() {
        List<Marketing_Campaign__c> campaigns = [SELECT Id FROM Marketing_Campaign__c WHERE Schedule_Type__c = 'Specific Date' LIMIT 1];
        List<Template_Data__c> templates = [SELECT Id FROM Template_Data__c LIMIT 1];
        
        // Use a fake contact ID that doesn't exist
        EmailCampaignScheduler.EmailRequest request = new EmailCampaignScheduler.EmailRequest();
        request.email = 'fake@example.com';
        request.subject = 'Test';
        request.body = 'Test body';
        request.campaignId = campaigns[0].Id;
        request.contactId = '003000000000000AAA'; // Fake ID
        request.templateDataId = templates[0].Id;
        
        Test.startTest();
        EmailCampaignScheduler.sendEmails(new List<EmailCampaignScheduler.EmailRequest>{request});
        Test.stopTest();
    }

    @isTest
    static void testSendEmailsExceptionHandling() {
        // Create a request with invalid data to trigger exception
        EmailCampaignScheduler.EmailRequest request = new EmailCampaignScheduler.EmailRequest();
        request.email = null;
        request.subject = 'Test';
        request.body = 'Test';
        request.campaignId = null;
        request.contactId = null;
        request.templateDataId = null;
        
        Test.startTest();
        try {
            EmailCampaignScheduler.sendEmails(new List<EmailCampaignScheduler.EmailRequest>{request});
        } catch (Exception e) {
            // Exception expected
        }
        Test.stopTest();
    }

    @isTest
    static void testEmailRequestWrapperClass() {
        EmailCampaignScheduler.EmailRequest request = new EmailCampaignScheduler.EmailRequest();
        request.email = 'test@example.com';
        request.ccAddresses = 'cc@example.com';
        request.bccAddresses = 'bcc@example.com';
        request.subject = 'Subject';
        request.body = 'Body';
        request.campaignId = 'campaignId';
        request.contactId = 'contactId';
        request.templateDataId = 'templateId';
        
        System.assertEquals('test@example.com', request.email);
        System.assertEquals('cc@example.com', request.ccAddresses);
        System.assertEquals('bcc@example.com', request.bccAddresses);
        System.assertEquals('Subject', request.subject);
        System.assertEquals('Body', request.body);
    }
}