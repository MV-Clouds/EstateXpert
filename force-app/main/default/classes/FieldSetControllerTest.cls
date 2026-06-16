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
        Map<String, Id> listingRecordTypeMap = new Map<String, Id>();
        for (RecordType rt : [SELECT Id, DeveloperName FROM RecordType WHERE SObjectType IN ('Listing__c', 'MVEX__Listing__c') AND DeveloperName IN ('Rent', 'Sale')]) {
            listingRecordTypeMap.put(rt.DeveloperName, rt.Id);
        }

        Listing__c listing = new Listing__c();
        listing.Name = 'Dev Test 12';
        listing.Property__c = propertyId;
        listing.Status__c = 'Active';
        listing.Listing_Type__c = 'Rent';
        if (listingRecordTypeMap.containsKey(listing.Listing_Type__c)) {
            listing.RecordTypeId = listingRecordTypeMap.get(listing.Listing_Type__c);
        }
        listing.Rent_Frequency__c = 'Monthly'; 
        listing.Property_Type__c = 'Villa';
        listing.Property_Sub_Type__c = 'Residential - Apartment';
        listing.Property_Category__c = 'Residential';
        listing.Country_Code__c = 'IN';
        listing.Street__c = 'Dev Test';
        listing.City__c = 'Dev Test';
        listing.State__c = 'Dev Test';
        listing.Zip_Postal_Code__c = '123456';
        listing.Description__c = 'Dev Test';
        listing.Listing_Price__c = 1000000;
        listing.Bedrooms__c = 3;
        listing.Bathrooms__c = 2;
        listing.Size__c = 1000;
        listing.Listed_Date__c = Date.today();
        listing.Furnished__c = 'Yes';
        listing.Property_Status__c = 'Vacant';
        listing.Year_Built__c = '2020';
        listing.Listing_Agent_Firstname__c = 'RK';
        listing.Listing_Agent_Lastname__c = 'Dev';
        listing.Listing_Agent_Email__c = 'rkdev@gmail.com';
        listing.Private_Amenities__c = 'Private Garden';
        listing.Completion_Status__c = 'Completed';
        listing.Available_From__c = Date.today();
        listing.Availability_Date__c = DateTime.now();
        listing.Bedrooms__c = 3;
        
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