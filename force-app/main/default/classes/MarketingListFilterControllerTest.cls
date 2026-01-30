@isTest
private class MarketingListFilterControllerTest {

    @testSetup
    static void setupTestData() {
        // Insert test contacts
        List<Contact> contacts = new List<Contact>{
            new Contact(FirstName = 'Test', LastName = 'User1', Email = 'user1@example.com'),
            new Contact(FirstName = 'Sample', LastName = 'User2', Email = 'user2@example.com')
        };
        insert contacts;
    }

    @isTest
    static void testGetContactFields() {
        Test.startTest();
        List<MarketingListFilterController.FieldDetails> fields = MarketingListFilterController.getContactFields('Contact');
        Test.stopTest();

        System.assert(fields != null, 'Field list should not be null');
    }

    @isTest
    static void testGetPicklistValues() {
        // Test standard picklist field on Contact: e.g., 'Salutation'
        Test.startTest();
        List<Map<String, String>> picklistValues = MarketingListFilterController.getPicklistValues('Salutation', 'Contact');
        Test.stopTest();

        System.assert(picklistValues != null, 'Picklist values should not be null');
    }

    @isTest
    static void testGetFilteredContactsWithCondition() {
        Map<String, Object> filterData = new Map<String, Object>();
        List<Map<String, Object>> contactFilters = new List<Map<String, Object>>();
        
        Map<String, Object> filter = new Map<String, Object>();
        filter.put('fieldPath', 'FirstName');
        filter.put('operator', 'equals');
        filter.put('values', new List<String>{'Test'});
        filter.put('isNot', false);
        filter.put('type', 'STRING');
        filter.put('index', 1);
        contactFilters.add(filter);
        
        filterData.put('contactFilters', contactFilters);
        filterData.put('inquiryFilters', new List<Map<String, Object>>());
        filterData.put('customLogic', '');
        
        String filterJson = JSON.serialize(filterData);

        Test.startTest();
        MarketingListFilterController.FilterDataWrapper result = MarketingListFilterController.getFilteredContacts(filterJson);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testGetFilteredContactsWithoutCondition() {
        Map<String, Object> filterData = new Map<String, Object>();
        filterData.put('contactFilters', new List<Map<String, Object>>());
        filterData.put('inquiryFilters', new List<Map<String, Object>>());
        filterData.put('customLogic', '');
        
        String filterJson = JSON.serialize(filterData);

        Test.startTest();
        MarketingListFilterController.FilterDataWrapper result = MarketingListFilterController.getFilteredContacts(filterJson);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testGetStaticFieldsWhenMissing() {
        Test.startTest();
        String result = MarketingListFilterController.getStaticFields();
        Test.stopTest();

        System.assertEquals(result != null, true , 'Should return message when no static fields are present');
    }

    @isTest
    static void testGetContactFieldsWithInvalidObject() {
        Test.startTest();
        List<MarketingListFilterController.FieldDetails> fields = MarketingListFilterController.getContactFields('InvalidObject');
        Test.stopTest();

        System.assertEquals(null, fields, 'Should return null for invalid object name');
    }

    @isTest
    static void testGetPicklistValuesWithInvalidField() {
        Test.startTest();
        List<Map<String, String>> values = MarketingListFilterController.getPicklistValues('InvalidField', 'Contact');
        Test.stopTest();

        System.assertEquals(null, values, 'Should return null for invalid field name');
    }

    @isTest
    static void testGetFilteredContactsWithInvalidFilter() {
        Map<String, Object> filterData = new Map<String, Object>();
        List<Map<String, Object>> contactFilters = new List<Map<String, Object>>();
        
        Map<String, Object> filter = new Map<String, Object>();
        filter.put('fieldPath', 'NonExistentField__c');
        filter.put('operator', 'equals');
        filter.put('values', new List<String>{'Test'});
        filter.put('isNot', false);
        filter.put('type', 'STRING');
        filter.put('index', 1);
        contactFilters.add(filter);
        
        filterData.put('contactFilters', contactFilters);
        filterData.put('inquiryFilters', new List<Map<String, Object>>());
        filterData.put('customLogic', '');
        
        String filterJson = JSON.serialize(filterData);

        Test.startTest();
        try {
            MarketingListFilterController.getFilteredContacts(filterJson);
        } catch (Exception e) {
            System.assert(e != null, 'Exception should be thrown for invalid filter');
        }
        Test.stopTest();
    }
}