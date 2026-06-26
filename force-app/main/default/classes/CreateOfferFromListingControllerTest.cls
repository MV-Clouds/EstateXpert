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
            MVEX__Status__c = 'Draft',
            MVEX__Offer_Date__c = Date.today(),
            MVEX__Description__c = 'Test offer',
            MVEX__Offer_made_by__c = 'Buyer'
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
    }
    
    /**
     * Method Name: testUpdateOfferRecordWithOfferSource
     * @description: Tests updateOfferRecord when sourceObjectType is 'Offer'
     * Created Date: 2026-06-26
     * Created By: Karan Singh
     */
    @isTest
    static void testUpdateOfferRecordWithOfferSource() {
        // Get the test offer
        MVEX__Offer__c testOffer = [SELECT Id, MVEX__Status__c FROM MVEX__Offer__c LIMIT 1];
        System.assertNotEquals('Countered', testOffer.MVEX__Status__c, 'Initial status should not be Countered');
        
        Test.startTest();
        Boolean result = CreateOfferFromListingController.updateOfferRecord('Offer', testOffer.Id);
        Test.stopTest();
        
        // Assertions
        System.assertEquals(true, result, 'Update should be successful');
        MVEX__Offer__c updatedOffer = [SELECT MVEX__Status__c FROM MVEX__Offer__c WHERE Id = :testOffer.Id];
        System.assertEquals('Countered', updatedOffer.MVEX__Status__c, 'Status should be updated to Countered');
    }
    
    /**
     * Method Name: testUpdateOfferRecordWithListingSource
     * @description: Tests updateOfferRecord when sourceObjectType is 'Listing'
     * Created Date: 2026-06-26
     * Created By: Karan Singh
     */
    @isTest
    static void testUpdateOfferRecordWithListingSource() {
        // Get the test offer
        MVEX__Offer__c testOffer = [SELECT Id FROM MVEX__Offer__c LIMIT 1];
        
        // Check if Active RecordType exists for MVEX__Offer__c to decide the expected result
        List<RecordType> activeRecordTypes = [SELECT Id FROM RecordType WHERE SObjectType = 'MVEX__Offer__c' AND DeveloperName = 'Active' LIMIT 1];
        Boolean expectedResult = !activeRecordTypes.isEmpty();
        
        Test.startTest();
        Boolean result = CreateOfferFromListingController.updateOfferRecord('Listing', testOffer.Id);
        Test.stopTest();
        
        // Assertions
        System.assertEquals(expectedResult, result, 'Result should match whether RecordType exists');
        if (expectedResult) {
            MVEX__Offer__c updatedOffer = [SELECT MVEX__First_Offer_Id__c, RecordTypeId FROM MVEX__Offer__c WHERE Id = :testOffer.Id];
            System.assertEquals(String.valueOf(testOffer.Id), updatedOffer.MVEX__First_Offer_Id__c, 'First Offer ID should be set to the offer ID');
            System.assertEquals(activeRecordTypes[0].Id, updatedOffer.RecordTypeId, 'Record Type ID should be updated to Active RecordType');
        }
    }
    
    /**
     * Method Name: testUpdateOfferRecordWithInvalidSource
     * @description: Tests updateOfferRecord when sourceObjectType is invalid
     * Created Date: 2026-06-26
     * Created By: Karan Singh
     */
    @isTest
    static void testUpdateOfferRecordWithInvalidSource() {
        // Get the test offer
        MVEX__Offer__c testOffer = [SELECT Id FROM MVEX__Offer__c LIMIT 1];
        
        Test.startTest();
        Boolean result = CreateOfferFromListingController.updateOfferRecord('InvalidSource', testOffer.Id);
        Test.stopTest();
        
        // Assertions
        System.assertEquals(false, result, 'Update should return false for invalid source type');
    }

    /**
     * Method Name: testUpdateOfferRecordException
     * @description: Tests updateOfferRecord error handling when a DML/Query exception occurs
     * Created Date: 2026-06-26
     * Created By: Karan Singh
     */
    @isTest
    static void testUpdateOfferRecordException() {
        Test.startTest();
        // Pass null for offerId which will cause a DML exception on update
        Boolean result = CreateOfferFromListingController.updateOfferRecord('Offer', null);
        Test.stopTest();
        
        // Assertions
        System.assertEquals(false, result, 'Update should return false when exception occurs');
    }
}