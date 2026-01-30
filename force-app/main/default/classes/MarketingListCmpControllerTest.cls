@isTest
private class MarketingListCmpControllerTest {

    @testSetup
    static void setupData() {
        // Create contacts
        Contact contact = new Contact(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'test@example.com',
            Phone = '1234567890',
            Contact_Type__c = 'Buyer'
        );
        insert contact;

        Contact contact2 = new Contact(
            FirstName = 'Test2',
            LastName = 'User2',
            Email = 'test2@example.com',
            Phone = '9876543210',
            Contact_Type__c = 'Buyer'
        );
        insert contact2;

        // Create Lead
        Lead testLead = new Lead(
            FirstName = 'Lead',
            LastName = 'Test',
            Email = 'lead@example.com',
            Company = 'Test Company',
            Phone = '5555555555'
        );
        insert testLead;

        // Create Property and Listing for email template testing
        Property__c property = new Property__c(Name = 'Test Property');
        insert property;

        Listing__c listing = new Listing__c(Property__c = property.Id);
        insert listing;

        // Insert template and related data
        Template__c temp = new Template__c(
            Template_Name__c = 'Test Template',
            Subject__c = 'Test Subject',
            Object_API_Name__c = 'Contact'
        );
        insert temp;

        Template_Data__c bodyData = new Template_Data__c(
            Template__c = temp.Id,
            Template_Value_Simple__c = '<p>Hello {{#FirstName}}</p>',
            Value_Type__c = 'Body Value',
            Order_No_Simple__c = 1
        );
        insert bodyData;

        Template_Data__c extractedData = new Template_Data__c(
            Template__c = temp.Id,
            Template_Value_Simple__c = '{"objectFields":["{{#FirstName}}","{{#LastName}}"]}',
            Value_Type__c = 'Extracted Mapping Keys',
            Order_No_Simple__c = 2
        );
        insert extractedData;

        // Create Template for Lead
        Template__c leadTemp = new Template__c(
            Template_Name__c = 'Lead Template',
            Subject__c = 'Lead Subject',
            Object_API_Name__c = 'Lead'
        );
        insert leadTemp;

        Template_Data__c leadBodyData = new Template_Data__c(
            Template__c = leadTemp.Id,
            Template_Value_Simple__c = '<p>Hello Lead</p>',
            Value_Type__c = 'Body Value',
            Order_No_Simple__c = 1
        );
        insert leadBodyData;

        Template_Data__c leadExtractedData = new Template_Data__c(
            Template__c = leadTemp.Id,
            Template_Value_Simple__c = '{"objectFields":["{{#FirstName}}","{{#LastName}}"]}',
            Value_Type__c = 'Extracted Mapping Keys',
            Order_No_Simple__c = 2
        );
        insert leadExtractedData;

        // Create Marketing List Filter Config
        MarketingListFilterConfig__mdt filterConfig = new MarketingListFilterConfig__mdt(
            BlockedFields__c = 'Password__c;SSN__c'
        );

        // Create Configuration Settings
        Configuration_Settings__c configSettings = new Configuration_Settings__c(
            Feature_Name__c = 'Marketing List',
            Object_API_Name__c = 'Contact',
            Fields_Data__c = '[{"label":"First Name","value":"FirstName"},{"label":"Last Name","value":"LastName"}]',
            Page_Size__c = 50
        );
        insert configSettings;

        // Create Broadcast Group
        Broadcast_Group__c broadcastGroup = new Broadcast_Group__c(
            Name = 'Test Broadcast Group',
            Description__c = 'Test Description',
            Object_Name__c = 'Contact',
            Phone_Field__c = 'Phone'
        );
        insert broadcastGroup;

        // Create Broadcast Group Member
        Broadcast_Group_Member__c member = new Broadcast_Group_Member__c(
            Broadcast_Group_ID__c = broadcastGroup.Id,
            Contact_Id__c = contact.Id,
            Phone_Number__c = '1234567890'
        );
        insert member;
    }

    @isTest
    static void testGetContactData() {
        Test.startTest();
        MarketingListCmpController.WrapperClass result = MarketingListCmpController.getContactData();
        Test.stopTest();

        System.assert(result != null, 'Contact data wrapper should not be null');
    }

    @isTest
    static void testGetListViewId() {

        Test.startTest();
        String listViewId = MarketingListCmpController.getListViewId();
        Test.stopTest();

        System.assert(String.isNotBlank(listViewId), 'ListView ID should be returned');
    }

    @isTest
    static void testProcessBroadcastMessageWithObject() {
        String json = JSON.serialize(new Map<String, Object>{
            'objectApiName' => 'Contact',
            'listViewName' => 'AllContacts',
            'phoneNumbers' => new List<String>{'1234567890'},
            'description' => 'Test Broadcast',
            'name' => 'Broadcast Group A',
            'phoneField' => 'Phone'
        });

        Test.startTest();
        String resultId = MarketingListCmpController.processBroadcastMessageWithObject(json);
        Test.stopTest();

        System.assert(String.isNotBlank(resultId), 'Broadcast group ID should be returned');
    }

    @isTest
    static void testSingleSendEmail() {
        Contact testCon = [SELECT Id, Email FROM Contact LIMIT 1];
        Template__c template = [SELECT Id FROM Template__c LIMIT 1];

        Map<String, Object> contactMap = new Map<String, Object>{
            'Id' => testCon.Id,
            'Email' => testCon.Email
        };

        Map<String, Object> requestMap = new Map<String, Object>{
            'sendMethod' => 'single',
            'templateId' => template.Id,
            'contacts' => new List<Object>{contactMap}
        };

        String jsonInput = JSON.serialize(requestMap);

        Test.startTest();
        MarketingListCmpController.sendEmail(jsonInput);
        Test.stopTest();

    }

    @isTest
    static void testGmailSendEmail() {
        Contact testCon = [SELECT Id, Email FROM Contact LIMIT 1];
        Template__c template = [SELECT Id FROM Template__c LIMIT 1];

        Map<String, Object> contactMap = new Map<String, Object>{
            'Id' => testCon.Id,
            'Email' => testCon.Email
        };

        Map<String, Object> requestMap = new Map<String, Object>{
            'sendMethod' => 'gmail',
            'templateId' => template.Id,
            'contacts' => new List<Object>{contactMap}
        };

        String jsonInput = JSON.serialize(requestMap);

        Test.startTest();
        MarketingListCmpController.sendEmail(jsonInput);
        Test.stopTest();

        
    }


    @isTest
    static void testOutlookSendEmail() {
        Contact testCon = [SELECT Id, Email FROM Contact LIMIT 1];
        Template__c template = [SELECT Id FROM Template__c LIMIT 1];

        Map<String, Object> contactMap = new Map<String, Object>{
            'Id' => testCon.Id,
            'Email' => testCon.Email
        };

        Map<String, Object> requestMap = new Map<String, Object>{
            'sendMethod' => 'outlook',
            'templateId' => template.Id,
            'contacts' => new List<Object>{contactMap},
            'objectName' => 'Contact'
        };

        String jsonInput = JSON.serialize(requestMap);

        Test.startTest();
        MarketingListCmpController.sendEmail(jsonInput);
        Test.stopTest();

        
    }

    @isTest
    static void testSendEmailWithBroadcastGroups() {
        Broadcast_Group__c broadcastGroup = [SELECT Id FROM Broadcast_Group__c LIMIT 1];
        Template__c template = [SELECT Id FROM Template__c WHERE Object_API_Name__c = 'Contact' LIMIT 1];

        Map<String, Object> requestMap = new Map<String, Object>{
            'sendMethod' => 'single',
            'templateId' => template.Id,
            'contacts' => new List<Object>(),
            'broadcastGroups' => new List<String>{broadcastGroup.Id},
            'objectName' => 'Contact',
            'templateType' => 'Marketing Template'
        };

        String jsonInput = JSON.serialize(requestMap);

        Test.startTest();
        MarketingListCmpController.sendEmail(jsonInput);
        Test.stopTest();
    }

    @isTest
    static void testSendEmailWithLeadObject() {
        Lead testLead = [SELECT Id, Email FROM Lead LIMIT 1];
        Template__c template = [SELECT Id FROM Template__c WHERE Object_API_Name__c = 'Lead' LIMIT 1];

        Map<String, Object> leadMap = new Map<String, Object>{
            'Id' => testLead.Id,
            'Email' => testLead.Email
        };

        Map<String, Object> requestMap = new Map<String, Object>{
            'sendMethod' => 'gmail',
            'templateId' => template.Id,
            'contacts' => new List<Object>{leadMap},
            'objectName' => 'Lead',
            'templateType' => 'Email Template'
        };

        String jsonInput = JSON.serialize(requestMap);

        Test.startTest();
        MarketingListCmpController.sendEmail(jsonInput);
        Test.stopTest();
    }

    @isTest
    static void testSendEmailWithListing() {
        Contact testCon = [SELECT Id, Email FROM Contact LIMIT 1];
        Template__c template = [SELECT Id FROM Template__c WHERE Object_API_Name__c = 'Contact' LIMIT 1];
        Listing__c listing = [SELECT Id FROM Listing__c LIMIT 1];

        Map<String, Object> contactMap = new Map<String, Object>{
            'Id' => testCon.Id,
            'Email' => testCon.Email
        };

        Map<String, Object> requestMap = new Map<String, Object>{
            'sendMethod' => 'single',
            'templateId' => template.Id,
            'contacts' => new List<Object>{contactMap},
            'objectName' => 'Contact',
            'selectedListing' => listing.Id
        };

        String jsonInput = JSON.serialize(requestMap);

        Test.startTest();
        MarketingListCmpController.sendEmail(jsonInput);
        Test.stopTest();
    }

    @isTest
    static void testSendEmailWithMixedContactsAndBroadcastGroups() {
        Contact testCon = [SELECT Id, Email FROM Contact WHERE Email = 'test@example.com' LIMIT 1];
        Broadcast_Group__c broadcastGroup = [SELECT Id FROM Broadcast_Group__c LIMIT 1];
        Template__c template = [SELECT Id FROM Template__c WHERE Object_API_Name__c = 'Contact' LIMIT 1];

        Map<String, Object> contactMap = new Map<String, Object>{
            'Id' => testCon.Id,
            'Email' => testCon.Email
        };

        Map<String, Object> requestMap = new Map<String, Object>{
            'sendMethod' => 'outlook',
            'templateId' => template.Id,
            'contacts' => new List<Object>{contactMap},
            'broadcastGroups' => new List<String>{broadcastGroup.Id},
            'objectName' => 'Contact'
        };

        String jsonInput = JSON.serialize(requestMap);

        Test.startTest();
        MarketingListCmpController.sendEmail(jsonInput);
        Test.stopTest();
    }

    @isTest
    static void testProcessBroadcastMessageUpdate() {
        Broadcast_Group__c existingGroup = [SELECT Id FROM Broadcast_Group__c LIMIT 1];
        
        String json = JSON.serialize(new Map<String, Object>{
            'objectApiName' => 'Contact',
            'listViewName' => 'AllContacts',
            'phoneNumbers' => new List<String>{'9999999999', '8888888888'},
            'description' => 'Updated Description',
            'name' => 'Updated Broadcast Group',
            'phoneField' => 'Phone',
            'isUpdate' => true,
            'broadcastGroupId' => existingGroup.Id
        });

        Test.startTest();
        String resultId = MarketingListCmpController.processBroadcastMessageWithObject(json);
        Test.stopTest();

        System.assert(String.isNotBlank(resultId), 'Should return updated broadcast group ID');
    }

    @isTest
    static void testProcessBroadcastMessageMissingFields() {
        String json = JSON.serialize(new Map<String, Object>{
            'objectApiName' => 'Contact',
            'phoneNumbers' => new List<String>{'1234567890'}
        });

        Test.startTest();
        String result = MarketingListCmpController.processBroadcastMessageWithObject(json);
        Test.stopTest();

        System.assert(result.contains('Error'), 'Should return error for missing fields');
    }

    @isTest
    static void testProcessBroadcastMessageEmptyPhoneNumbers() {
        String json = JSON.serialize(new Map<String, Object>{
            'objectApiName' => 'Contact',
            'listViewName' => 'AllContacts',
            'phoneNumbers' => new List<String>(),
            'description' => 'Test',
            'name' => 'Test Group',
            'phoneField' => 'Phone'
        });

        Test.startTest();
        String result = MarketingListCmpController.processBroadcastMessageWithObject(json);
        Test.stopTest();

        System.assert(result.contains('Error'), 'Should return error for empty phone numbers');
    }

    @isTest
    static void testGetListViewIdNotFound() {
        Test.startTest();
        String result = MarketingListCmpController.getListViewId();
        Test.stopTest();

        System.assert(String.isNotBlank(result), 'Should return result even if ListView not found');
    }

    @isTest
    static void testGetContactDataWithConfiguration() {
        Test.startTest();
        MarketingListCmpController.WrapperClass result = MarketingListCmpController.getContactData();
        Test.stopTest();

        System.assert(result != null, 'Contact data wrapper should not be null');
        System.assertEquals(50, result.pageSize, 'Page size should be from config');
        System.assert(result.selectedFields != null, 'Selected fields should not be null');
        System.assert(result.contacts != null, 'Contacts list should not be null');
    }

    @isTest
    static void testGetContactDataWithoutConfiguration() {
        // Delete configuration settings
        delete [SELECT Id FROM Configuration_Settings__c];

        Test.startTest();
        MarketingListCmpController.WrapperClass result = MarketingListCmpController.getContactData();
        Test.stopTest();

        System.assert(result != null, 'Contact data wrapper should not be null');
        System.assertEquals(30, result.pageSize, 'Page size should default to 30');
    }

    @isTest
    static void testSendEmailWithNullContacts() {
        Template__c template = [SELECT Id FROM Template__c WHERE Object_API_Name__c = 'Contact' LIMIT 1];

        Map<String, Object> requestMap = new Map<String, Object>{
            'sendMethod' => 'single',
            'templateId' => template.Id,
            'contacts' => null,
            'objectName' => 'Contact'
        };

        String jsonInput = JSON.serialize(requestMap);

        Test.startTest();
        MarketingListCmpController.sendEmail(jsonInput);
        Test.stopTest();
    }

    @isTest
    static void testSendEmailWithEmptyEmail() {
        Contact testCon = [SELECT Id FROM Contact LIMIT 1];
        Template__c template = [SELECT Id FROM Template__c WHERE Object_API_Name__c = 'Contact' LIMIT 1];

        Map<String, Object> contactMap = new Map<String, Object>{
            'Id' => testCon.Id,
            'Email' => ''
        };

        Map<String, Object> requestMap = new Map<String, Object>{
            'sendMethod' => 'single',
            'templateId' => template.Id,
            'contacts' => new List<Object>{contactMap},
            'objectName' => 'Contact'
        };

        String jsonInput = JSON.serialize(requestMap);

        Test.startTest();
        MarketingListCmpController.sendEmail(jsonInput);
        Test.stopTest();
    }
}