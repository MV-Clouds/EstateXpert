@isTest
private class EmailCampaignControllerTest {
    
    @TestSetup
    static void setupTestData() {
        // Create Custom Settings for Gmail and Outlook configurations
        GmailConfig__c gmailConfig = new GmailConfig__c(Refresh_Token__c = 'test-token-gmail');
        insert gmailConfig;
        
        OutlookConfig__c outlookConfig = new OutlookConfig__c(Refresh_Token_1__c = 'test-token-outlook');
        insert outlookConfig;
        
        // Create a Property record for Listing
        Property__c property = new Property__c(Name = 'Test Property');
        insert property;
        
        // Create a Property File record
        Property_File__c propertyFile = new Property_File__c(
            Property__c = property.Id,
            BaseUrl__c = 'https://example.com/image.jpg',
            IsOnExpose__c = true,
            Size__c = 1024,
            Sort_on_Expose__c = 1
        );
        insert propertyFile;
        
        // Create a Listing record
        Listing__c listing = new Listing__c(Property__c = property.Id);
        insert listing;
        
        // Create a Template record
        Template__c template = new Template__c(
            Template_Name__c = 'Test Template',
            Template_pattern__c = 'Marketing Template',
            Template_Status__c = true,
            Object_API_Name__c = 'Contact',
            Subject__c = 'Test Subject'
        );
        insert template;
        
        // Create Template Data
        Template_Data__c templateData = new Template_Data__c(
            Template__c = template.Id,
            Template_Value_Simple__c = '{"key":"value"}',
            Value_Type__c = 'Extracted Mapping Keys',
            Order_No_Simple__c = 1
        );
        insert templateData;
        
        // Create Contacts
        List<Contact> contacts = new List<Contact>();
        contacts.add(new Contact(LastName = 'Test Contact 1', Email = 'test1@example.com', Birthdate = Date.today().addYears(-30)));
        contacts.add(new Contact(LastName = 'Test Contact 2', Email = 'test2@example.com'));
        insert contacts;
        
        
        // Create Marketing Campaign
        Marketing_Campaign__c campaign = new Marketing_Campaign__c(
            Label__c = 'Test Campaign',
            Is_Marketing_Campaign_Template__c = true,
            Email_Type__c = 'single',
            Schedule_Type__c = 'Specific Date',
            Start_Date__c = Date.today(),
            Campaign_Start_Date__c = Date.today(),
            RelatedObject__c = 'Contact'
        );
        insert campaign;
        
        // Create Marketing Campaign Members
        List<Marketing_Campaign_Member__c> members = new List<Marketing_Campaign_Member__c>();
        members.add(new Marketing_Campaign_Member__c(Marketing_Campaign__c = campaign.Id, RecipientId__c = contacts[0].Id, Contact_Type__c = 'Primary'));
        insert members;
        
        // Create Marketing Email
        Marketing_Email__c email = new Marketing_Email__c(
            Marketing_Campaign__c = campaign.Id,
            Subject__c = 'Test Email',
            Name = 'Test Email',
            Template_Id__c = template.Id,
            Days_After_Start_Date__c = 0,
            TimeToSend__c = Time.newInstance(12, 0, 0, 0),
            Send_Date_Time__c = DateTime.now().addDays(1),
            Listing__c = listing.Id
        );
        insert email;
        
        // Create Email Member
        Email_Member__c emailMember = new Email_Member__c(
            RecipientId__c = contacts[0].Id,
            Marketing_Email__c = email.Id,
            Schedule_Date_and_Time__c = DateTime.now().addDays(1),
            Status__c = 'Pending'
        );
        insert emailMember;
    }
    
    @isTest
    static void testGetEmailCampaignTemplates() {
        List<Marketing_Campaign__c> result = EmailCampaignController.getEmailCampaignTemplates();
        System.assertEquals(1, result.size(), 'Expected exactly one campaign template');
    }
    
    @isTest
    static void testGetContacts() {
        List<Contact> result = EmailCampaignController.getContacts();
        System.assertEquals(2, result.size(), 'Expected exactly two contacts');
    }
    
    @isTest
    static void testGetCampaign() {
        Marketing_Campaign__c campaign = [SELECT Id FROM Marketing_Campaign__c LIMIT 1];
        Marketing_Campaign__c result = EmailCampaignController.getCampaign(campaign.Id);
        System.assertEquals('Contact', result.RelatedObject__c, 'Expected RelatedObject__c to be Contact');
    }
    
    @isTest
    static void testGetContactsByIds() {
        Set<Id> contactIds = new Set<Id>();
        for (Contact contact : [SELECT Id FROM Contact]) {
            contactIds.add(contact.Id);
        }
        List<Contact> result = EmailCampaignController.getContacts(contactIds);
        System.assertEquals(2, result.size(), 'Expected exactly two contacts');
    }
    
    @isTest
    static void testGetDateFieldsForPicklist() {
        List<Map<String, String>> result = EmailCampaignController.getDateFieldsForPicklist();
        System.assertNotEquals(0, result.size(), 'Expected at least one date field');
    }
    
    @isTest
    static void testGetQuickTemplates() {
        EmailCampaignController.TemplateDataForEmail result = EmailCampaignController.getQuickTemplates();
        System.assertEquals(1, result.marketingTemplates.size(), 'Expected exactly one marketing template');
    }
    
    @isTest
    static void testGetMarketingEmails() {
        Marketing_Campaign__c campaign = [SELECT Id FROM Marketing_Campaign__c LIMIT 1];
        List<Marketing_Email__c> result = EmailCampaignController.getMarketingEmails(campaign.Id);
        System.assertEquals(1, result.size(), 'Expected exactly one marketing email');
    }
    
    @isTest
    static void testGetMessagingServiceOptions() {
        List<Map<String, String>> result = EmailCampaignController.getMessagingServiceOptions();
        System.assertEquals(3, result.size(), 'Expected three messaging service options');
    }
    
    @isTest
    static void testCreateCampaignAndEmails() {
        Map<String, Object> campaignData = new Map<String, Object>{
            'campaignName' => 'New Test Campaign',
            'templateId' => '',
            'saveForFuture' => true,
            'messagingService' => 'single',
            'selectedContactDateField' => 'Birthdate',
            'relatedObject' => 'Contact',
            'selectedPrimaryRecipients' => new List<String>{[SELECT Id FROM Contact LIMIT 1].Id},
            'selectedCCRecipients' => new List<String>{},
            'selectedBCCRecipients' => new List<String>{},
            'specificDate' => String.valueOf(Date.today()),
            'emails' => new List<Map<String, Object>>{
                new Map<String, Object>{
                    'subject' => 'Test Email',
                    'name' => 'Test Email',
                    'template' => [SELECT Id FROM Template__c LIMIT 1].Id,
                    'daysAfterStartDate' => 0,
                    'timeToSend' => '12:00:00',
                    'selectedListingId' => [SELECT Id FROM Listing__c LIMIT 1].Id
                }
            }
        };
        String result = EmailCampaignController.createCampaignAndEmails(JSON.serialize(campaignData), false);
        System.assertNotEquals(null, result, 'Expected a valid campaign ID');
    }
    
    @isTest
    static void testUpdateCampaignAndEmails() {
        Marketing_Campaign__c campaign = [SELECT Id FROM Marketing_Campaign__c LIMIT 1];
        Map<String, Object> campaignData = new Map<String, Object>{
            'campaignId' => campaign.Id,
            'campaignName' => 'Updated Test Campaign',
            'templateId' => '',
            'saveForFuture' => true,
            'messagingService' => 'single',
            'selectedContactDateField' => 'Birthdate',
            'relatedObject' => 'Contact',
            'selectedPrimaryRecipients' => new List<String>{[SELECT Id FROM Contact LIMIT 1].Id},
            'selectedCCRecipients' => new List<String>{},
            'selectedBCCRecipients' => new List<String>{},
            'specificDate' => String.valueOf(Date.today()),
            'emails' => new List<Map<String, Object>>{
                new Map<String, Object>{
                    'id' => [SELECT Id FROM Marketing_Email__c LIMIT 1].Id,
                    'subject' => 'Updated Email',
                    'name' => 'Updated Email',
                    'template' => [SELECT Id FROM Template__c LIMIT 1].Id,
                    'daysAfterStartDate' => 0,
                    'timeToSend' => '12:00:00',
                    'selectedListingId' => [SELECT Id FROM Listing__c LIMIT 1].Id,
                    'disabled' => false
                }
            },
            'deletedEmailList' => new List<String>{}
        };
        String result = EmailCampaignController.updateCampaignAndEmails(JSON.serialize(campaignData));
        System.assertEquals(campaign.Id, result, 'Expected the same campaign ID');
    }
    
    @isTest
    static void testRecalculateCampaignCounts() {
        Id campaignId = [SELECT Id FROM Marketing_Campaign__c LIMIT 1].Id;
        EmailCampaignController.recalculateCampaignCounts(campaignId);
        Marketing_Campaign__c campaign = [SELECT Total_Emails__c FROM Marketing_Campaign__c WHERE Id = :campaignId];
        System.assertEquals(1, campaign.Total_Emails__c, 'Expected one total email');
    }
    
    @isTest
    static void testCheckContactDateFields() {
        List<Map<String, Object>> contacts = new List<Map<String, Object>>{
            new Map<String, Object>{'value' => [SELECT Id FROM Contact LIMIT 1].Id}
        };
        Map<String, String> result = EmailCampaignController.checkContactDateFields(JSON.serialize(contacts), 'Birthdate');
        System.assertNotEquals(null, result, 'Expected a non-null result');
    }
    
    @isTest
    static void testGetCampaignMemberEmails() {
        Id campaignId = [SELECT Id FROM Marketing_Campaign__c LIMIT 1].Id;
        EmailCampaignController.getCampaignMemberEmails(campaignId);
    }
    
    @isTest
    static void testGetCampaignAndRelatedData() {
        Id campaignId = [SELECT Id FROM Marketing_Campaign__c LIMIT 1].Id;
        String result = EmailCampaignController.getCamapaignAndRelatedData(campaignId);
        System.assertNotEquals(null, result, 'Expected a valid JSON string');
    }
    
    @isTest
    static void testGetCampaigns() {
        List<Marketing_Campaign__c> result = EmailCampaignController.getCampaigns();
        System.assertEquals(1, result.size(), 'Expected exactly one campaign');
    }
    
    @isTest
    static void testDeleteCampaign() {
        Id campaignId = [SELECT Id FROM Marketing_Campaign__c LIMIT 1].Id;
        EmailCampaignController.deleteCampaign(campaignId);
        List<Marketing_Campaign__c> campaigns = [SELECT Id FROM Marketing_Campaign__c WHERE Id = :campaignId];
        System.assertEquals(0, campaigns.size(), 'Expected campaign to be deleted');
    }
    
    @isTest
    static void testSendEmails() {

        List<Contact> contacts = [SELECT Id FROM Contact];

        List<String> contactIds = new List<String>();

        for (Contact con : contacts){
            contactIds.add(con.Id);
        }

        EmailCampaignController.EmailRequests request = new EmailCampaignController.EmailRequests();
        request.toAddresses = contactIds;
        request.subject = 'Test Email';
        request.body = 'Test Body';
        request.campaignId = [SELECT Id FROM Marketing_Campaign__c LIMIT 1].Id;
        request.templateDataId = [SELECT Id FROM Template__c LIMIT 1].Id;
        request.listingId = [SELECT Id FROM Listing__c LIMIT 1].Id;
        request.RelatedObjectName = 'Contact';
        Test.startTest();
        EmailCampaignController.sendEmails(new List<EmailCampaignController.EmailRequests>{request});
        Test.stopTest();
    }
}