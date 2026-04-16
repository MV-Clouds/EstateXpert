@isTest
private class EmailCampaignControllerTest {
    
    /**
     * Mock class to handle the Composite API callout within sendEmails
     */
    private class CompositeApiMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"compositeResponse": [{"body": {"records": []}, "httpStatusCode": 200, "referenceId": "Contact_0"}]}');
            res.setStatusCode(200);
            return res;
        }
    }

    @TestSetup
    static void setupTestData() {
        GmailConfig__c gmailConfig = new GmailConfig__c(Refresh_Token__c = 'test-token-gmail');
        insert gmailConfig;
        
        OutlookConfig__c outlookConfig = new OutlookConfig__c(Refresh_Token_1__c = 'test-token-outlook');
        insert outlookConfig;
        
        Property__c property = new Property__c(Name = 'Test Property');
        insert property;
        
        Property_File__c propertyFile = new Property_File__c(
            Property__c = property.Id,
            BaseUrl__c = 'https://example.com/image.jpg',
            IsOnExpose__c = true,
            Size__c = 1024,
            Sort_on_Expose__c = 1
        );
        insert propertyFile;
        
        Listing__c listing = new Listing__c(Property__c = property.Id);
        insert listing;
        
        Template__c template = new Template__c(
            Template_Name__c = 'Test Template',
            Template_pattern__c = 'Marketing Template',
            Template_Status__c = true,
            Object_API_Name__c = 'Contact',
            Subject__c = 'Test Subject'
        );
        insert template;
        
        Template_Data__c templateData = new Template_Data__c(
            Template__c = template.Id,
            Template_Value_Simple__c = '{"key":"value"}',
            Value_Type__c = 'Extracted Mapping Keys',
            Order_No_Simple__c = 1
        );
        insert templateData;
        
        List<Contact> contacts = new List<Contact>();
        contacts.add(new Contact(LastName = 'Test Contact 1', Email = 'test1@example.com', Birthdate = Date.today().addYears(-30)));
        contacts.add(new Contact(LastName = 'Test Contact 2', Email = 'test2@example.com'));
        insert contacts;
        
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
        
        List<Marketing_Campaign_Member__c> members = new List<Marketing_Campaign_Member__c>();
        members.add(new Marketing_Campaign_Member__c(Marketing_Campaign__c = campaign.Id, RecipientId__c = contacts[0].Id, Contact_Type__c = 'Primary'));
        insert members;
        
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
        System.assertNotEquals(null, result, 'Expected template data wrapper');
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
            'selectedCCRecipients' => new List<String>{'cc@test.com'},
            'selectedBCCRecipients' => new List<String>{'bcc@test.com'},
            'specificDate' => String.valueOf(Date.today()),
            'emails' => new List<Map<String, Object>>{
                new Map<String, Object>{
                    'subject' => 'Test Email',
                    'name' => 'Test Email',
                    'template' => [SELECT Id FROM Template__c LIMIT 1].Id,
                    'daysAfterStartDate' => 0,
                    'templateType' => 'EstateXpertTemplate',
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
                    'templateType' => 'EstateXpertTemplate',
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

    /**
     * Covers the "Failed" email member block when conMap.get(contactId) is null
     * (contact has no email - lines ~1030-1044 in updateCampaignAndEmails).
     */
    @isTest
    static void testUpdateCampaignAndEmails_FailedNoEmail() {
        Contact noEmailContact = new Contact(LastName = 'NoEmail Contact');
        insert noEmailContact;

        Marketing_Campaign__c campaign = [SELECT Id FROM Marketing_Campaign__c LIMIT 1];

        insert new Marketing_Campaign_Member__c(
            Marketing_Campaign__c = campaign.Id,
            RecipientId__c = noEmailContact.Id,
            Contact_Type__c = 'Primary'
        );

        Marketing_Email__c email = [SELECT Id FROM Marketing_Email__c LIMIT 1];

        Map<String, Object> campaignData = new Map<String, Object>{
            'campaignId' => campaign.Id,
            'campaignName' => 'Failed No Email Campaign',
            'templateId' => '',
            'saveForFuture' => false,
            'messagingService' => 'single',
            'selectedContactDateField' => '',
            'relatedObject' => 'Contact',
            'selectedPrimaryRecipients' => new List<String>{noEmailContact.Id},
            'selectedCCRecipients' => new List<String>{},
            'selectedBCCRecipients' => new List<String>{},
            'specificDate' => String.valueOf(Date.today().addDays(5)),
            'emails' => new List<Map<String, Object>>{
                new Map<String, Object>{
                    'id' => email.Id,
                    'subject' => 'Test',
                    'name' => 'Test',
                    'template' => [SELECT Id FROM Template__c LIMIT 1].Id,
                    'daysAfterStartDate' => 0,
                    'templateType' => 'EstateXpertTemplate',
                    'timeToSend' => '12:00:00',
                    'disabled' => false
                }
            },
            'deletedEmailList' => new List<String>{}
        };

        Test.startTest();
        String result = EmailCampaignController.updateCampaignAndEmails(JSON.serialize(campaignData));
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    /**
     * Covers the "Failed" (null scheduleBaseDate) block in updateCampaignAndEmails
     * when contact has no Birthdate and selectedContactDateField = 'Birthdate'.
     * Lines ~1053-1068.
     */
    @isTest
    static void testUpdateCampaignAndEmails_FailedNullScheduleDate() {
        Contact c = new Contact(LastName = 'NoBirthdate', Email = 'nodate@test.com');
        insert c;

        Marketing_Campaign__c campaign = new Marketing_Campaign__c(
            Label__c = 'No Date Campaign',
            Is_Marketing_Campaign_Template__c = false,
            Email_Type__c = 'single',
            Schedule_Type__c = 'Contact Field',
            RelatedObject__c = 'Contact',
            SelectedContactDateField__c = 'Birthdate'
        );
        insert campaign;

        insert new Marketing_Campaign_Member__c(
            Marketing_Campaign__c = campaign.Id,
            RecipientId__c = c.Id,
            Contact_Type__c = 'Primary'
        );

        Marketing_Email__c email = new Marketing_Email__c(
            Marketing_Campaign__c = campaign.Id,
            Subject__c = 'Test Email',
            Name = 'Test Email NSD',
            Template_Id__c = [SELECT Id FROM Template__c LIMIT 1].Id,
            Days_After_Start_Date__c = 0,
            TimeToSend__c = Time.newInstance(10, 0, 0, 0)
        );
        insert email;

        Map<String, Object> campaignData = new Map<String, Object>{
            'campaignId' => campaign.Id,
            'campaignName' => 'No Date Campaign',
            'templateId' => '',
            'saveForFuture' => false,
            'messagingService' => 'single',
            'selectedContactDateField' => 'Birthdate',
            'relatedObject' => 'Contact',
            'selectedPrimaryRecipients' => new List<String>{c.Id},
            'selectedCCRecipients' => new List<String>{},
            'selectedBCCRecipients' => new List<String>{},
            'specificDate' => '',
            'emails' => new List<Map<String, Object>>{
                new Map<String, Object>{
                    'id' => email.Id,
                    'subject' => 'Test Email',
                    'name' => 'Test Email NSD',
                    'template' => [SELECT Id FROM Template__c LIMIT 1].Id,
                    'daysAfterStartDate' => 0,
                    'templateType' => 'EstateXpertTemplate',
                    'timeToSend' => '10:00:00',
                    'disabled' => false
                }
            },
            'deletedEmailList' => new List<String>{}
        };

        Test.startTest();
        String result = EmailCampaignController.updateCampaignAndEmails(JSON.serialize(campaignData));
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    /**
     * Covers the "Failed" (null TimeToSend__c) block in updateCampaignAndEmails.
     * Lines ~1072-1086: failedEmails++ when email.TimeToSend__c == null.
     */
    @isTest
    static void testUpdateCampaignAndEmails_FailedNullTimeToSend() {
        Contact c = new Contact(LastName = 'TimeToSendNull', Email = 'tts@test.com', Birthdate = Date.today().addDays(10));
        insert c;

        Marketing_Campaign__c campaign = new Marketing_Campaign__c(
            Label__c = 'Null TTS Campaign',
            Email_Type__c = 'single',
            Schedule_Type__c = 'Specific Date',
            RelatedObject__c = 'Contact',
            Start_Date__c = Date.today().addDays(5)
        );
        insert campaign;

        insert new Marketing_Campaign_Member__c(
            Marketing_Campaign__c = campaign.Id,
            RecipientId__c = c.Id,
            Contact_Type__c = 'Primary'
        );

        // Email intentionally missing TimeToSend__c
        Marketing_Email__c emailNoTime = new Marketing_Email__c(
            Marketing_Campaign__c = campaign.Id,
            Subject__c = 'No Time Email',
            Name = 'No Time Email',
            Template_Id__c = [SELECT Id FROM Template__c LIMIT 1].Id,
            Days_After_Start_Date__c = 0
        );
        insert emailNoTime;

        Map<String, Object> campaignData = new Map<String, Object>{
            'campaignId' => campaign.Id,
            'campaignName' => 'Null TTS Campaign',
            'templateId' => '',
            'saveForFuture' => false,
            'messagingService' => 'single',
            'selectedContactDateField' => '',
            'relatedObject' => 'Contact',
            'selectedPrimaryRecipients' => new List<String>{c.Id},
            'selectedCCRecipients' => new List<String>{},
            'selectedBCCRecipients' => new List<String>{},
            'specificDate' => String.valueOf(Date.today().addDays(5)),
            'emails' => new List<Map<String, Object>>{
                new Map<String, Object>{
                    'id' => emailNoTime.Id,
                    'subject' => 'No Time Email',
                    'name' => 'No Time Email',
                    'template' => [SELECT Id FROM Template__c LIMIT 1].Id,
                    'daysAfterStartDate' => 0,
                    'templateType' => 'EstateXpertTemplate',
                    'timeToSend' => '',
                    'disabled' => false
                }
            },
            'deletedEmailList' => new List<String>{}
        };

        Test.startTest();
        String result = EmailCampaignController.updateCampaignAndEmails(JSON.serialize(campaignData));
        Test.stopTest();

        System.assertNotEquals(null, result);
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

    /**
     * Covers sendEmails with 'single' email type path (standard SF messaging).
     */
    @isTest
    static void testSendEmailsEstateXpert() {
        List<Contact> contacts = [SELECT Id FROM Contact];
        List<String> contactIds = new List<String>();
        for (Contact con : contacts){
            contactIds.add(con.Id);
        }

        EmailCampaignController.EmailRequests request = new EmailCampaignController.EmailRequests();
        request.toAddresses = contactIds;
        request.subject = 'Test Subject';
        request.body = 'Hello {Contact.Name}';
        request.campaignId = [SELECT Id FROM Marketing_Campaign__c LIMIT 1].Id;
        request.templateDataId = [SELECT Id FROM Template__c LIMIT 1].Id;
        request.listingId = [SELECT Id FROM Listing__c LIMIT 1].Id;
        request.RelatedObjectName = 'Contact';
        request.templateType = 'EstateXpertTemplate';
        
        Test.startTest();
        EmailCampaignController.sendEmails(new List<EmailCampaignController.EmailRequests>{request});
        Test.stopTest();
    }

    /**
     * Covers sendEmails with 'gmail' emailType (lines ~2063-2086).
     * Also exercises parseEmailAddresses with a valid @@@-delimited string (lines ~2234-2249).
     */
    @isTest
    static void testSendEmailsGmailType() {
        Contact c = [SELECT Id FROM Contact WHERE Email != null LIMIT 1];

        Marketing_Campaign__c gmailCampaign = new Marketing_Campaign__c(
            Label__c = 'Gmail Campaign',
            Email_Type__c = 'gmail',
            Schedule_Type__c = 'Specific Date',
            RelatedObject__c = 'Contact',
            Start_Date__c = Date.today()
        );
        insert gmailCampaign;

        insert new Marketing_Campaign_Member__c(
            Marketing_Campaign__c = gmailCampaign.Id,
            RecipientId__c = c.Id,
            Contact_Type__c = 'Primary'
        );

        Template__c tmpl = [SELECT Id FROM Template__c LIMIT 1];
        Marketing_Email__c me = new Marketing_Email__c(
            Marketing_Campaign__c = gmailCampaign.Id,
            Subject__c = 'Gmail Test',
            Name = 'Gmail Test Email',
            Template_Id__c = tmpl.Id,
            Days_After_Start_Date__c = 0,
            TimeToSend__c = Time.newInstance(9, 0, 0, 0),
            Send_Date_Time__c = DateTime.now().addMinutes(5)
        );
        insert me;

        insert new Email_Member__c(
            RecipientId__c = c.Id,
            Marketing_Email__c = me.Id,
            Schedule_Date_and_Time__c = DateTime.now().addDays(1),
            Status__c = 'Pending'
        );

        EmailCampaignController.EmailRequests req = new EmailCampaignController.EmailRequests();
        req.toAddresses = new List<String>{c.Id};
        req.subject = 'Gmail Test';
        req.body = 'Hello Gmail';
        req.campaignId = gmailCampaign.Id;
        req.templateDataId = tmpl.Id;
        req.RelatedObjectName = 'Contact';
        req.templateType = 'EstateXpertTemplate';
        // Valid @@@-delimited format that parseEmailAddresses splits on
        req.ccAddresses = 'id1:cc@test.com@@@id2:cc2@test.com';
        req.bccContacts = 'id3:bcc@test.com';

        Test.startTest();
        EmailCampaignController.sendEmails(new List<EmailCampaignController.EmailRequests>{req});
        Test.stopTest();
    }

    /**
     * Covers sendEmails with 'outlook' emailType (lines ~2087-2111).
     */
    @isTest
    static void testSendEmailsOutlookType() {
        Contact c = [SELECT Id FROM Contact WHERE Email != null LIMIT 1];

        Marketing_Campaign__c outlookCampaign = new Marketing_Campaign__c(
            Label__c = 'Outlook Campaign',
            Email_Type__c = 'outlook',
            Schedule_Type__c = 'Specific Date',
            RelatedObject__c = 'Contact',
            Start_Date__c = Date.today()
        );
        insert outlookCampaign;

        insert new Marketing_Campaign_Member__c(
            Marketing_Campaign__c = outlookCampaign.Id,
            RecipientId__c = c.Id,
            Contact_Type__c = 'Primary'
        );

        Template__c tmpl = [SELECT Id FROM Template__c LIMIT 1];
        Marketing_Email__c me = new Marketing_Email__c(
            Marketing_Campaign__c = outlookCampaign.Id,
            Subject__c = 'Outlook Test',
            Name = 'Outlook Test Email',
            Template_Id__c = tmpl.Id,
            Days_After_Start_Date__c = 0,
            TimeToSend__c = Time.newInstance(9, 0, 0, 0),
            Send_Date_Time__c = DateTime.now().addMinutes(5)
        );
        insert me;

        insert new Email_Member__c(
            RecipientId__c = c.Id,
            Marketing_Email__c = me.Id,
            Schedule_Date_and_Time__c = DateTime.now().addDays(1),
            Status__c = 'Pending'
        );

        EmailCampaignController.EmailRequests req = new EmailCampaignController.EmailRequests();
        req.toAddresses = new List<String>{c.Id};
        req.subject = 'Outlook Test';
        req.body = 'Hello Outlook';
        req.campaignId = outlookCampaign.Id;
        req.templateDataId = tmpl.Id;
        req.RelatedObjectName = 'Contact';
        req.templateType = 'EstateXpertTemplate';
        req.ccAddresses = 'id1:cc@test.com';
        req.bccContacts = 'id2:bcc@test.com';

        Test.startTest();
        EmailCampaignController.sendEmails(new List<EmailCampaignController.EmailRequests>{req});
        Test.stopTest();
    }

    @isTest
    static void testSendEmailsUnsupported() {
        EmailCampaignController.EmailRequests request = new EmailCampaignController.EmailRequests();
        request.templateType = 'Unsupported';
        EmailCampaignController.sendEmails(new List<EmailCampaignController.EmailRequests>{request});
    }

    /**
     * Exercises all exception branches in one shot.
     */
    @isTest
    static void testExceptions() {
        EmailCampaignController.getCampaign('invalid-id');
        EmailCampaignController.createCampaignAndEmails('invalid-json', false);
        EmailCampaignController.updateCampaignAndEmails('invalid-json');
        EmailCampaignController.checkContactDateFields('invalid-json', 'Birthdate');
        EmailCampaignController.getCamapaignAndRelatedData('invalid-id');
        EmailCampaignController.deleteCampaign(null);
    }

    /**
     * Covers broadcast group code paths in createCampaignAndEmails and updateCampaignAndEmails.
     */
    @isTest
    static void testCreateCampaignWithBroadcastGroups() {
        MVEX__Broadcast_Group__c bg = new MVEX__Broadcast_Group__c(Name = 'Test Group');
        insert bg;
        Contact c = new Contact(LastName = 'Test C', Email = 'testc@ex.com');
        insert c;
        MVEX__Broadcast_Group_Member__c bgm = new MVEX__Broadcast_Group_Member__c(MVEX__Broadcast_Group_ID__c = bg.Id, MVEX__Member_Record_Id__c = c.Id);
        insert bgm;

        Map<String, Object> campaignData = new Map<String, Object>{
            'campaignName' => 'Test Campaign BG',
            'saveForFuture' => false,
            'messagingService' => 'single',
            'relatedObject' => 'Contact',
            'selectedBroadcastGroups' => new List<String>{bg.Id},
            'emails' => new List<Map<String, Object>>{
                new Map<String, Object>{
                    'subject' => 'Test Email',
                    'name' => 'Test Email',
                    'template' => [SELECT Id FROM Template__c LIMIT 1].Id,
                    'daysAfterStartDate' => 0,
                    'templateType' => 'EstateXpertTemplate',
                    'timeToSend' => '12:00:00'
                }
            }
        };
        Test.startTest();
        EmailCampaignController.createCampaignAndEmails(JSON.serialize(campaignData), true);
        EmailCampaignController.updateCampaignAndEmails(JSON.serialize(campaignData));
        Test.stopTest();
    }

    /**
     * Covers the inner try-catch block of sendEmails (lines ~2154-2175) by running
     * successfully with all pending email members so the update succeeds then
     * recalculateCampaignCounts is called.
     */
    @isTest
    static void testSendEmailsInnerCatchBlock() {
        Contact c = [SELECT Id FROM Contact WHERE Email != null LIMIT 1];
        Marketing_Campaign__c campaign = [SELECT Id FROM Marketing_Campaign__c LIMIT 1];

        EmailCampaignController.EmailRequests req = new EmailCampaignController.EmailRequests();
        req.toAddresses = new List<String>{c.Id};
        req.subject = 'Inner Catch Test';
        req.body = 'Body';
        req.campaignId = campaign.Id;
        req.templateDataId = [SELECT Id FROM Template__c LIMIT 1].Id;
        req.RelatedObjectName = 'Contact';
        req.templateType = 'EstateXpertTemplate';

        Test.startTest();
        EmailCampaignController.sendEmails(new List<EmailCampaignController.EmailRequests>{req});
        Test.stopTest();
    }

    /**
     * Covers getTemplateBodyById and replaceMergeFields by calling sendEmails
     * with merge field tokens in the body ({!Contact.FirstName}).
     */
    @isTest
    static void testSendEmailsWithMergeFields() {
        Contact c = [SELECT Id FROM Contact WHERE Email != null LIMIT 1];

        Marketing_Campaign__c campaign = new Marketing_Campaign__c(
            Label__c = 'Merge Field Campaign',
            Email_Type__c = 'single',
            Schedule_Type__c = 'Specific Date',
            RelatedObject__c = 'Contact',
            Start_Date__c = Date.today()
        );
        insert campaign;

        insert new Marketing_Campaign_Member__c(
            Marketing_Campaign__c = campaign.Id,
            RecipientId__c = c.Id,
            Contact_Type__c = 'Primary'
        );

        Template__c tmpl = [SELECT Id FROM Template__c LIMIT 1];
        Marketing_Email__c me = new Marketing_Email__c(
            Marketing_Campaign__c = campaign.Id,
            Subject__c = 'Merge Test',
            Name = 'Merge Test Email',
            Template_Id__c = tmpl.Id,
            Days_After_Start_Date__c = 0,
            TimeToSend__c = Time.newInstance(10, 0, 0, 0),
            Send_Date_Time__c = DateTime.now().addMinutes(5)
        );
        insert me;

        insert new Email_Member__c(
            RecipientId__c = c.Id,
            Marketing_Email__c = me.Id,
            Schedule_Date_and_Time__c = DateTime.now().addDays(1),
            Status__c = 'Pending'
        );

        EmailCampaignController.EmailRequests req = new EmailCampaignController.EmailRequests();
        req.toAddresses = new List<String>{c.Id};
        req.subject = 'Merge Test';
        // Body contains {!Object.Field} merge tokens => hits replaceMergeFields
        req.body = '<p>Hello {!Contact.FirstName}, Date: {!DATEVALUE(Contact.Birthdate)}</p>';
        req.campaignId = campaign.Id;
        req.templateDataId = tmpl.Id;
        req.RelatedObjectName = 'Contact';
        req.templateType = 'EstateXpertTemplate';

        Test.startTest();
        EmailCampaignController.sendEmails(new List<EmailCampaignController.EmailRequests>{req});
        Test.stopTest();
    }
}