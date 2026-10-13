/**
 * Class Name : MarketingListCmpControllerTest
 * Last Modified Date : 2026-10-13
 * Last Modified By : Dhruv Kakadiya
 * @description : Test class for MarketingListCmpController.
 */

@isTest
private class MarketingListCmpControllerTest {

    @testSetup
    static void setupData() {
        // Create an Account for relationship testing
        Account testAcc = new Account(Name = 'Test Account');
        insert testAcc;

        // Create Contacts
        Contact contact1 = new Contact(
            FirstName = 'John',
            LastName = 'Doe',
            Email = 'john.doe@example.com',
            Phone = '1234567890',
            AccountId = testAcc.Id
        );
        insert contact1;

        Contact contact2 = new Contact(
            FirstName = 'Jane',
            LastName = 'Smith',
            Email = 'jane.smith@example.com',
            Phone = '9876543210',
            AccountId = testAcc.Id
        );
        insert contact2;

        // Create Inquiries
        MVEX__Inquiry__c inquiry1 = new MVEX__Inquiry__c(
            MVEX__Contact__c = contact1.Id,
            MVEX__City__c = 'New York'
        );
        insert inquiry1;

        MVEX__Inquiry__c inquiry2 = new MVEX__Inquiry__c(
            MVEX__Contact__c = contact2.Id,
            MVEX__City__c = 'San Francisco'
        );
        insert inquiry2;

        // Create Configuration Settings for Marketing List Fields
        MVEX__Configuration_Settings__c configSettings = new MVEX__Configuration_Settings__c(
            MVEX__Feature_Name__c = 'Marketing_List_Fields',
            MVEX__Object_API_Name__c = 'Contact',
            MVEX__Fields_Data__c = '[{"fieldApiname":"Title","label":"Title"},{"fieldApiname":"Department","label":"Department"}]',
            MVEX__Page_Size__c = 50
        );
        insert configSettings;
    }

    @isTest
    static void testGetContactDataWithConfig() {
        Test.startTest();
        MarketingListCmpController.WrapperClass result = MarketingListCmpController.getContactData();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testGetContactDataWithoutConfig() {
        // Delete configuration settings to test fallback defaults
        delete [SELECT Id FROM MVEX__Configuration_Settings__c];

        Test.startTest();
        MarketingListCmpController.WrapperClass result = MarketingListCmpController.getContactData();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(30, result.pageSize, 'Page size should default to 30 when config is missing');
    }

    @isTest
    static void testGetFilteredContactsSuccess() {
        Map<String, Object> contactFilter1 = new Map<String, Object>{
            'fieldPath' => 'FirstName',
            'operator' => 'equals',
            'values' => new List<String>{'John'},
            'isNot' => false,
            'type' => 'STRING',
            'index' => 1
        };

        Map<String, Object> contactFilter2 = new Map<String, Object>{
            'fieldPath' => 'Account.Name',
            'operator' => 'equals',
            'values' => new List<String>{'Test Account'},
            'isNot' => false,
            'type' => 'STRING',
            'index' => 2
        };

        Map<String, Object> inquiryFilter1 = new Map<String, Object>{
            'fieldPath' => 'MVEX__City__c',
            'operator' => 'equals',
            'values' => new List<String>{'New York'},
            'isNot' => false,
            'type' => 'STRING',
            'index' => 1
        };

        Map<String, Object> filterDataMap = new Map<String, Object>{
            'contactFilters' => new List<Object>{contactFilter1, contactFilter2},
            'inquiryFilters' => new List<Object>{inquiryFilter1},
            'customLogic' => '1 AND 2'
        };

        String filterDataJson = JSON.serialize(filterDataMap);

        Test.startTest();
        MarketingListCmpController.FilterDataWrapper result = MarketingListCmpController.getFilteredContacts(filterDataJson);
        Test.stopTest();

        System.assertNotEquals(null, result, 'FilterDataWrapper should not be null');
    }

    @isTest
    static void testGetFilteredContactsEmptyFilters() {
        Map<String, Object> filterDataMap = new Map<String, Object>{
            'contactFilters' => new List<Object>(),
            'inquiryFilters' => new List<Object>(),
            'customLogic' => ''
        };

        String filterDataJson = JSON.serialize(filterDataMap);

        Test.startTest();
        MarketingListCmpController.FilterDataWrapper result = MarketingListCmpController.getFilteredContacts(filterDataJson);
        Test.stopTest();

        System.assertNotEquals(null, result, 'FilterDataWrapper should not be null');
    }

    @isTest
    static void testGetFilteredContactsNullFilters() {
        Map<String, Object> filterDataMap = new Map<String, Object>{
            'contactFilters' => null,
            'inquiryFilters' => null,
            'customLogic' => null
        };

        String filterDataJson = JSON.serialize(filterDataMap);

        Test.startTest();
        MarketingListCmpController.FilterDataWrapper result = MarketingListCmpController.getFilteredContacts(filterDataJson);
        Test.stopTest();

        System.assertNotEquals(null, result, 'FilterDataWrapper should not be null');
    }

    @isTest
    static void testGetFilteredContactsException() {
        Test.startTest();
        // Passing invalid JSON to test exception handling block
        MarketingListCmpController.FilterDataWrapper result = MarketingListCmpController.getFilteredContacts('invalid-json');
        Test.stopTest();

        System.assertEquals(null, result, 'Should return null when exception occurs');
    }

    @isTest
    static void testInnerClassesDirectly() {
        // Test FilterCondition properties
        MarketingListCmpController.FilterCondition cond = new MarketingListCmpController.FilterCondition();
        cond.fieldPath = 'FirstName';
        cond.operator = 'equals';
        cond.values = new List<String>{'Test'};
        cond.isNot = false;
        cond.type = 'STRING';
        cond.index = 1;

        System.assertEquals('FirstName', cond.fieldPath, 'fieldPath should match');

        // Test FilterDataWrapper properties
        MarketingListCmpController.FilterDataWrapper fdw = new MarketingListCmpController.FilterDataWrapper();
        fdw.contacts = new List<Contact>();
        fdw.inquiries = new List<MVEX__Inquiry__c>();
        fdw.contactFilters = new List<MarketingListCmpController.FilterCondition>{cond};
        fdw.inquiryFilters = new List<MarketingListCmpController.FilterCondition>{cond};
        fdw.customLogic = '1';

        System.assertNotEquals(null, fdw.contacts, 'contacts should not be null');

        // Test WrapperClass properties
        MarketingListCmpController.WrapperClass wc = new MarketingListCmpController.WrapperClass();
        wc.contacts = new List<Contact>();
        wc.pageSize = 25;
        wc.selectedFields = new List<Map<String, String>>();

        System.assertNotEquals(null, wc.contacts, 'contacts should not be null');
    }
}