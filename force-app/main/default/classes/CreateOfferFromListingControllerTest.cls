@isTest
public class CreateOfferFromListingControllerTest {
    
    /**
     * Method Name: setupTestData
     * @description: Creates test data for listing and contact
     * Created Date: 10/02/2026
     * Created By: Karan Singh
     */
    @TestSetup
    static void setupTestData() {
        // Create a test contact for seller
        Contact sellerContact = new Contact(
            FirstName = 'Test',
            LastName = 'Seller',
            Email = 'testseller@example.com'
        );
        insert sellerContact;
        
        // Create a test contact for buyer
        Contact buyerContact = new Contact(
            FirstName = 'Test',
            LastName = 'Buyer',
            Email = 'testbuyer@example.com'
        );
        insert buyerContact;
        
        // Create a test listing
        MVEX__Listing__c testListing = new MVEX__Listing__c(
            Name = 'Test Listing',
            MVEX__Listing_Type__c = 'Sale',
            MVEX__Listing_Price__c = 500000,
            MVEX__Property_OwnerContact__c = sellerContact.Id,
            MVEX__Status__c = 'Active'
        );
        insert testListing;
        
        // Create a test offer
        MVEX__Offer__c testOffer = new MVEX__Offer__c(
            MVEX__Listing__c = testListing.Id,
            MVEX__Listing_Type__c = 'Sale',
            MVEX__Listing_Price__c = 500000,
            MVEX__Seller_Contact__c = sellerContact.Id,
            MVEX__Buyer_Contact__c = buyerContact.Id,
            MVEX__Offer_Amount__c = 480000,
            MVEX__Status__c = 'Pending',
            MVEX__Offer_Date__c = Date.today(),
            MVEX__Description__c = 'Test offer'
        );
        insert testOffer;
    }
    
    /**
     * Method Name: testGetListingDetailsSuccess
     * @description: Tests successful retrieval of listing details
     * Created Date: 10/02/2026
     * Created By: Karan Singh
     */
    @isTest
    static void testGetListingDetailsSuccess() {
        // Get the test listing
        MVEX__Listing__c testListing = [SELECT Id FROM MVEX__Listing__c LIMIT 1];
        
        Test.startTest();
        MVEX__Listing__c result = CreateOfferFromListingController.getListingDetails(testListing.Id);
        Test.stopTest();
        
        // Assertions
        System.assertNotEquals(null, result, 'Listing should be returned');
        System.assertEquals(testListing.Id, result.Id, 'Listing ID should match');
        System.assertEquals('Sale', result.MVEX__Listing_Type__c, 'Listing type should be Sale');
        System.assertEquals(500000, result.MVEX__Listing_Price__c, 'Listing price should be 500000');
        System.assertNotEquals(null, result.MVEX__Property_OwnerContact__c, 'Seller contact should not be null');
    }
    
    /**
     * Method Name: testGetListingDetailsWithInvalidId
     * @description: Tests error handling when listing ID is invalid
     * Created Date: 10/02/2026
     * Created By: Karan Singh
     */
    @isTest
    static void testGetListingDetailsWithInvalidId() {
        // Create a fake ID that doesn't exist
        Id fakeListingId = '001000000000000AAA';
        
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            CreateOfferFromListingController.getListingDetails(fakeListingId);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            System.assert(e.getMessage().contains('Error retrieving listing details'), 
                'Exception message should contain expected text');
        }
        Test.stopTest();
        
        // Assertion
        System.assertEquals(true, exceptionThrown, 'Exception should have been thrown for invalid ID');
    }
    
    /**
     * Method Name: testGetListingDetailsWithNullId
     * @description: Tests error handling when listing ID is null
     * Created Date: 10/02/2026
     * Created By: Karan Singh
     */
    @isTest
    static void testGetListingDetailsWithNullId() {
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            CreateOfferFromListingController.getListingDetails(null);
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        
        // Assertion
        System.assertEquals(true, exceptionThrown, 'Exception should have been thrown for null ID');
    }
    
    /**
     * Method Name: testGetListingDetailsWithAllFields
     * @description: Tests that all required fields are properly returned
     * Created Date: 10/02/2026
     * Created By: Karan Singh
     */
    @isTest
    static void testGetListingDetailsWithAllFields() {
        // Get the test listing
        MVEX__Listing__c testListing = [SELECT Id FROM MVEX__Listing__c LIMIT 1];
        
        Test.startTest();
        MVEX__Listing__c result = CreateOfferFromListingController.getListingDetails(testListing.Id);
        Test.stopTest();
        
        // Verify all fields are accessible
        System.assertNotEquals(null, result.Id, 'Id should not be null');
        System.assertNotEquals(null, result.MVEX__Listing_Type__c, 'Listing Type should not be null');
        System.assertNotEquals(null, result.MVEX__Listing_Price__c, 'Listing Price should not be null');
        System.assertNotEquals(null, result.MVEX__Property_OwnerContact__c, 'Seller Contact should not be null');
    }
    
    /**
     * Method Name: testGetOfferDetailsSuccess
     * @description: Tests successful retrieval of offer details
     * Created Date: 10/02/2026
     * Created By: Karan Singh
     */
    @isTest
    static void testGetOfferDetailsSuccess() {
        // Get the test offer
        MVEX__Offer__c testOffer = [SELECT Id FROM MVEX__Offer__c LIMIT 1];
        
        Test.startTest();
        MVEX__Offer__c result = CreateOfferFromListingController.getOfferDetails(testOffer.Id);
        Test.stopTest();
        
        // Assertions
        System.assertNotEquals(null, result, 'Offer should be returned');
        System.assertEquals(testOffer.Id, result.Id, 'Offer ID should match');
        System.assertEquals('Sale', result.MVEX__Listing_Type__c, 'Listing type should be Sale');
        System.assertEquals(500000, result.MVEX__Listing_Price__c, 'Listing price should be 500000');
        System.assertEquals(480000, result.MVEX__Offer_Amount__c, 'Offer amount should be 480000');
        System.assertEquals('Pending', result.MVEX__Status__c, 'Status should be Pending');
        System.assertNotEquals(null, result.MVEX__Listing__c, 'Listing should not be null');
    }
    
    /**
     * Method Name: testGetOfferDetailsWithInvalidId
     * @description: Tests error handling when offer ID is invalid
     * Created Date: 10/02/2026
     * Created By: Karan Singh
     */
    @isTest
    static void testGetOfferDetailsWithInvalidId() {
        // Create a fake ID that doesn't exist
        Id fakeOfferId = '001000000000000AAA';
        
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            CreateOfferFromListingController.getOfferDetails(fakeOfferId);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            System.assert(e.getMessage().contains('Error retrieving offer details'), 
                'Exception message should contain expected text');
        }
        Test.stopTest();
        
        // Assertion
        System.assertEquals(true, exceptionThrown, 'Exception should have been thrown for invalid ID');
    }
    
    /**
     * Method Name: testGetOfferDetailsWithAllFields
     * @description: Tests that all required fields are properly returned from offer
     * Created Date: 10/02/2026
     * Created By: Karan Singh
     */
    @isTest
    static void testGetOfferDetailsWithAllFields() {
        // Get the test offer
        MVEX__Offer__c testOffer = [SELECT Id FROM MVEX__Offer__c LIMIT 1];
        
        Test.startTest();
        MVEX__Offer__c result = CreateOfferFromListingController.getOfferDetails(testOffer.Id);
        Test.stopTest();
        
        // Verify all fields are accessible
        System.assertNotEquals(null, result.Id, 'Id should not be null');
        System.assertNotEquals(null, result.MVEX__Listing__c, 'Listing should not be null');
        System.assertNotEquals(null, result.MVEX__Listing_Type__c, 'Listing Type should not be null');
        System.assertNotEquals(null, result.MVEX__Listing_Price__c, 'Listing Price should not be null');
        System.assertNotEquals(null, result.MVEX__Seller_Contact__c, 'Seller Contact should not be null');
        System.assertNotEquals(null, result.MVEX__Buyer_Contact__c, 'Buyer Contact should not be null');
    }
    
    /**
     * Method Name: testGetRecordDetailsWithListing
     * @description: Tests getRecordDetails with a Listing record
     * Created Date: 10/02/2026
     * Created By: Karan Singh
     */
    @isTest
    static void testGetRecordDetailsWithListing() {
        // Get the test listing
        MVEX__Listing__c testListing = [SELECT Id FROM MVEX__Listing__c LIMIT 1];
        
        Test.startTest();
        CreateOfferFromListingController.RecordDetailsWrapper result = 
            CreateOfferFromListingController.getRecordDetails(testListing.Id);
        Test.stopTest();
        
        // Assertions
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(true, result.isSuccess, 'Should be successful');
        System.assertEquals('', result.errorMessage, 'Error message should be empty');
        System.assertEquals('Listing', result.objectType, 'Object type should be Listing');
        System.assertEquals(testListing.Id, result.listingId, 'Listing ID should match');
        System.assertEquals('Sale', result.listingType, 'Listing type should be Sale');
        System.assertEquals(500000, result.listingPrice, 'Listing price should be 500000');
        System.assertNotEquals(null, result.sellerContact, 'Seller contact should not be null');
    }
    
    /**
     * Method Name: testGetRecordDetailsWithOffer
     * @description: Tests getRecordDetails with an Offer record
     * Created Date: 10/02/2026
     * Created By: Karan Singh
     */
    @isTest
    static void testGetRecordDetailsWithOffer() {
        // Get the test offer
        MVEX__Offer__c testOffer = [SELECT Id FROM MVEX__Offer__c LIMIT 1];
        
        Test.startTest();
        CreateOfferFromListingController.RecordDetailsWrapper result = 
            CreateOfferFromListingController.getRecordDetails(testOffer.Id);
        Test.stopTest();
        
        // Assertions
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(true, result.isSuccess, 'Should be successful');
        System.assertEquals('', result.errorMessage, 'Error message should be empty');
        System.assertEquals('Offer', result.objectType, 'Object type should be Offer');
        System.assertNotEquals(null, result.listingId, 'Listing ID should not be null');
        System.assertEquals('Sale', result.listingType, 'Listing type should be Sale');
        System.assertEquals(500000, result.listingPrice, 'Listing price should be 500000');
        System.assertEquals(480000, result.offerAmount, 'Offer amount should be 480000');
        System.assertEquals('Pending', result.status, 'Status should be Pending');
        System.assertEquals(testOffer.Id, result.counterOfferFor, 'Counter offer for should match offer ID');
    }
    
    /**
     * Method Name: testGetRecordDetailsWithInvalidId
     * @description: Tests getRecordDetails with an invalid record ID
     * Created Date: 10/02/2026
     * Created By: Karan Singh
     */
    @isTest
    static void testGetRecordDetailsWithInvalidId() {
        // Create a fake ID that doesn't exist
        Id fakeId = '001000000000000AAA';
        
        Test.startTest();
        CreateOfferFromListingController.RecordDetailsWrapper result = 
            CreateOfferFromListingController.getRecordDetails(fakeId);
        Test.stopTest();
        
        // Assertions
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(false, result.isSuccess, 'Should not be successful');
        System.assertNotEquals('', result.errorMessage, 'Error message should not be empty');
        System.assert(result.errorMessage.contains('Error retrieving record details'), 
            'Error message should contain expected text');
    }
}