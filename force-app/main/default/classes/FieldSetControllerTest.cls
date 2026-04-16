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

    @isTest
    static void testFetchRecordTypes() {
        Test.startTest();
        List<RecordType> result = FieldSetController.fetchRecordTypes('Contact');
        List<RecordType> resultErr = FieldSetController.fetchRecordTypes('');
        Test.stopTest();
        System.assertNotEquals(null, result, 'Expected record types list');
    }
    
    @isTest
    static void testGetListingFieldsByRecordType() {
        Test.startTest();
        List<RecordType> rts = [SELECT Id FROM RecordType WHERE SObjectType = 'MVEX__Listing__c' AND DeveloperName = 'Sale' LIMIT 1];
        if(rts.size() > 0) {
            FieldSetController.getListingFieldsByRecordType(rts[0].Id);
        }
        List<RecordType> rts2 = [SELECT Id FROM RecordType WHERE SObjectType = 'MVEX__Listing__c' AND DeveloperName = 'Rent' LIMIT 1];
        if(rts2.size() > 0) {
            FieldSetController.getListingFieldsByRecordType(rts2[0].Id);
        }
        FieldSetController.getListingFieldsByRecordType(null); // Force exception
        Test.stopTest();
    }
    
    @isTest
    static void testGetContactFieldsByRecordType() {
        Test.startTest();
        List<RecordType> rts = [SELECT Id FROM RecordType WHERE SObjectType = 'Contact' LIMIT 1];
        if(rts.size() > 0) {
            FieldSetController.getContactFieldsByRecordType(rts[0].Id);
        }
        FieldSetController.getContactFieldsByRecordType(null); // Force exception
        Test.stopTest();
    }
    
    @isTest
    static void testExceptions() {
        Test.startTest();
        Property__c prop = new Property__c(); // Empty name
        FieldSetController.fetchListings(prop);
        FieldSetController.fetchListings(null);

        Contact listin = new Contact(FirstName = '', LastName = '', Email = 'test@example.com', Phone = '1234');
        FieldSetController.fetchContacts(listin, 'FirstName');

        Contact listinNull = new Contact(FirstName = '', LastName = '');
        FieldSetController.fetchContacts(listinNull, 'FirstName');

        Contact listin2 = new Contact(FirstName = 'J', LastName = 'D', Email = 'test@example.com', Phone = '12345');
        FieldSetController.fetchContacts(listin2, 'FirstName');

        FieldSetController.fetchContacts(null, null);
        Test.stopTest();
    }
    
    @isTest 
    static void testFetchListingsCoverage() {
        Property__c prop = new Property__c(Name = 'Test Property 2');
        insert prop;
        
        Test.startTest();
        FieldSetController.FilterWrapper wrapper = FieldSetController.fetchListings(prop);
        Test.stopTest();
    }
}