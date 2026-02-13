@isTest
public class FieldSetControllerTest {
    
    // Utility method to create a test Property record
    private static Property__c createTestProperty() {
        Property__c property = new Property__c(
            Name = 'Test Listing',
            City__c = 'Test City',
            State__c = 'Test State',
            Country__c = 'India'
        );
        insert property;
        return property;
    }

    // Utility method to create a test Listing record
    private static Listing__c createTestListing(Id propertyId) {
        Listing__c listing = new Listing__c(
            Name = 'Test Listing',
            Property__c = propertyId,
            Status__c = 'Active'
        );
        insert listing;
        return listing;
    }
    
    @isTest
    static void testFetchListings() {
        // Test data setup
        Property__c testProperty = createTestProperty();
        createTestListing(testProperty.Id);
        
        Test.startTest();
        FieldSetController.FilterWrapper wrapper = FieldSetController.fetchListings(testProperty);
        Test.stopTest();

        System.assertNotEquals(null, wrapper, 'Result should not be null');
    }

    @isTest
    static void testFetchContacts() {
        // Test data setup
        Contact testContact = new Contact(FirstName = 'John', LastName = 'Doe');
        insert testContact;
        
        Test.startTest();
        // Invoke the method
        List<Map<String, String>> contactList = FieldSetController.fetchContacts(testContact, 'FirstName, LastName');
        
        // Validate the results
        System.assertEquals(1, contactList.size(), 'Expected one contact in the list');
        System.assertEquals('John', contactList[0].get('FirstName'), 'Expected first name to be John');
        System.assertEquals('Doe', contactList[0].get('LastName'), 'Expected last name to be Doe');
        Test.stopTest();
    }

    // @isTest
    // static void testFetchRecordTypes() {
    //     Test.startTest();
    //     List<RecordType> recordTypeList = FieldSetController.fetchRecordTypes();
        
    //     System.assertNotEquals(0, recordTypeList.size(), 'Expected one recordtype in the list');
    //     Test.stopTest();
    // }

    // @isTest
    // static void testGetListOfFieldsForObjects() {
    //     Test.startTest();
    //     List<Map<String, Object>> listOfFieldsAndObject = FieldSetController.getListOfFieldsForObjects('MVEX__Listing__c');
        
    //     System.assertNotEquals(0, listOfFieldsAndObject.size(), 'Expected one recordtype in the list');
    //     Test.stopTest();
    // }
}