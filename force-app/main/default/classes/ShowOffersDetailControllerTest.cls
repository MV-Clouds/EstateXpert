/**
 * @description Test class for ShowOffersDetailController
 * @author Karan Singh
 * @date 10/02/2026
 */
@isTest
private class ShowOffersDetailControllerTest {
    
    /**
     * @description Create test data for offer timeline tests
     */
    @TestSetup
    static void setupTestData() {
        // Create a test listing
        MVEX__Listing__c testListing = new MVEX__Listing__c(
            MVEX__Listing_Type__c = 'Sale',
            MVEX__Listing_Price__c = 500000,
            MVEX__Status__c = 'Active'
        );
        insert testListing;
        
        // Create contacts for buyer and seller
        Contact buyerContact = new Contact(
            FirstName = 'Test',
            LastName = 'Buyer',
            Email = 'testbuyer@example.com'
        );
        insert buyerContact;
        
        Contact sellerContact = new Contact(
            FirstName = 'Test',
            LastName = 'Seller',
            Email = 'testseller@example.com'
        );
        insert sellerContact;
        
        // Create first offer
        MVEX__Offer__c firstOffer = new MVEX__Offer__c(
            MVEX__Listing__c = testListing.Id,
            MVEX__Listing_Type__c = 'Sale',
            MVEX__Listing_Price__c = 500000,
            MVEX__Buyer_Contact__c = buyerContact.Id,
            MVEX__Seller_Contact__c = sellerContact.Id,
            MVEX__Offer_made_by__c = 'Buyer',
            MVEX__Offer_Amount__c = 480000,
            MVEX__Status__c = 'Pending',
            MVEX__Offer_Date__c = Date.today().addDays(-10),
            MVEX__Offer_Expiration_Date__c = Date.today().addDays(-3),
            MVEX__Description__c = 'First offer on the property'
        );
        insert firstOffer;
        
        // Update first offer to set its own ID as First_Offer_Id
        firstOffer.MVEX__First_Offer_Id__c = firstOffer.Id;
        update firstOffer;
        
        // Create first counter offer
        MVEX__Offer__c counterOffer1 = new MVEX__Offer__c(
            MVEX__Listing__c = testListing.Id,
            MVEX__Listing_Type__c = 'Sale',
            MVEX__Listing_Price__c = 500000,
            MVEX__Buyer_Contact__c = buyerContact.Id,
            MVEX__Seller_Contact__c = sellerContact.Id,
            MVEX__Offer_made_by__c = 'Seller',
            MVEX__Offer_Amount__c = 495000,
            MVEX__Status__c = 'Counter Offer',
            MVEX__Offer_Date__c = Date.today().addDays(-8),
            MVEX__Offer_Expiration_Date__c = Date.today().addDays(-1),
            MVEX__Description__c = 'Seller counter offer',
            MVEX__Counter_Offer_for__c = firstOffer.Id,
            MVEX__First_Offer_Id__c = firstOffer.Id
        );
        insert counterOffer1;
        
        // Create second counter offer
        MVEX__Offer__c counterOffer2 = new MVEX__Offer__c(
            MVEX__Listing__c = testListing.Id,
            MVEX__Listing_Type__c = 'Sale',
            MVEX__Listing_Price__c = 500000,
            MVEX__Buyer_Contact__c = buyerContact.Id,
            MVEX__Seller_Contact__c = sellerContact.Id,
            MVEX__Offer_made_by__c = 'Buyer',
            MVEX__Offer_Amount__c = 490000,
            MVEX__Status__c = 'Accepted',
            MVEX__Offer_Date__c = Date.today().addDays(-5),
            MVEX__Offer_Expiration_Date__c = Date.today().addDays(5),
            MVEX__Description__c = 'Final accepted offer',
            MVEX__Counter_Offer_for__c = counterOffer1.Id,
            MVEX__First_Offer_Id__c = firstOffer.Id
        );
        insert counterOffer2;
    }
    
    /**
     * @description Test successful retrieval of offer timeline from first offer
     */
    @isTest
    static void testGetOfferTimelineFromFirstOffer() {
        // Get the first offer
        MVEX__Offer__c firstOffer = [
            SELECT Id 
            FROM MVEX__Offer__c 
            WHERE MVEX__Counter_Offer_for__c = null 
            LIMIT 1
        ];
        
        Test.startTest();
        ShowOffersDetailController.OfferTimelineResponse response = 
            ShowOffersDetailController.getOfferTimeline(firstOffer.Id);
        Test.stopTest();
        
        // Assertions
        System.assertEquals(true, response.isSuccess, 'Response should be successful');
        System.assertEquals('', response.errorMessage, 'No error message expected');
        System.assertEquals(3, response.offers.size(), 'Should return 3 offers in timeline');
        
        // Verify first offer
        System.assertEquals(true, response.offers[0].isFirstOffer, 'First item should be marked as first offer');
        System.assertEquals(1, response.offers[0].sequenceNumber, 'First offer should have sequence 1');
        System.assertEquals('Buyer', response.offers[0].offerMadeBy, 'First offer made by Buyer');
        System.assertEquals(480000, response.offers[0].offerAmount, 'First offer amount should be 480000');
        
        // Verify counter offers are in sequence
        System.assertEquals(2, response.offers[1].sequenceNumber, 'Second offer should have sequence 2');
        System.assertEquals(3, response.offers[2].sequenceNumber, 'Third offer should have sequence 3');
    }
    
    /**
     * @description Test retrieval of offer timeline from middle offer (counter offer)
     */
    @isTest
    static void testGetOfferTimelineFromCounterOffer() {
        // Get a counter offer (not the first one)
        MVEX__Offer__c counterOffer = [
            SELECT Id 
            FROM MVEX__Offer__c 
            WHERE MVEX__Counter_Offer_for__c != null 
            ORDER BY MVEX__Offer_Date__c ASC
            LIMIT 1
        ];
        
        Test.startTest();
        ShowOffersDetailController.OfferTimelineResponse response = 
            ShowOffersDetailController.getOfferTimeline(counterOffer.Id);
        Test.stopTest();
        
        // Assertions
        System.assertEquals(true, response.isSuccess, 'Response should be successful');
        System.assertEquals(3, response.offers.size(), 'Should return complete timeline with 3 offers');
        System.assertEquals(true, response.offers[0].isFirstOffer, 'Timeline should start with first offer');
    }
    
    /**
     * @description Test retrieval of offer timeline from last offer in chain
     */
    @isTest
    static void testGetOfferTimelineFromLastOffer() {
        // Get the last offer in the chain (accepted offer)
        MVEX__Offer__c lastOffer = [
            SELECT Id 
            FROM MVEX__Offer__c 
            WHERE MVEX__Status__c = 'Accepted' 
            LIMIT 1
        ];
        
        Test.startTest();
        ShowOffersDetailController.OfferTimelineResponse response = 
            ShowOffersDetailController.getOfferTimeline(lastOffer.Id);
        Test.stopTest();
        
        // Assertions
        System.assertEquals(true, response.isSuccess, 'Response should be successful');
        System.assertEquals(3, response.offers.size(), 'Should return complete timeline');
        System.assertEquals('Accepted', response.offers[2].status, 'Last offer should be Accepted');
    }
    
    /**
     * @description Test offer timeline with all field values populated
     */
    @isTest
    static void testOfferTimelineWithAllFields() {
        MVEX__Offer__c firstOffer = [
            SELECT Id 
            FROM MVEX__Offer__c 
            WHERE MVEX__Counter_Offer_for__c = null 
            LIMIT 1
        ];
        
        Test.startTest();
        ShowOffersDetailController.OfferTimelineResponse response = 
            ShowOffersDetailController.getOfferTimeline(firstOffer.Id);
        Test.stopTest();
        
        // Verify all fields are populated correctly
        ShowOffersDetailController.OfferWrapper offer = response.offers[0];
        System.assertNotEquals(null, offer.offerId, 'Offer ID should be populated');
        System.assertNotEquals(null, offer.offerNumber, 'Offer number should be populated');
        System.assertNotEquals(null, offer.offerDate, 'Offer date should be populated');
        System.assertNotEquals(null, offer.offerAmount, 'Offer amount should be populated');
        System.assertNotEquals(null, offer.offerMadeBy, 'Offer made by should be populated');
        System.assertNotEquals(null, offer.buyerContactName, 'Buyer contact name should be populated');
        System.assertNotEquals(null, offer.sellerContactName, 'Seller contact name should be populated');
        System.assertNotEquals(null, offer.status, 'Status should be populated');
        System.assertNotEquals(null, offer.expirationDate, 'Expiration date should be populated');
        System.assertNotEquals(null, offer.description, 'Description should be populated');
    }
    
    /**
     * @description Test error handling when offer has no First_Offer_Id
     */
    @isTest
    static void testGetOfferTimelineWithNoFirstOfferId() {
        // Create an offer without First_Offer_Id
        MVEX__Listing__c listing = [SELECT Id FROM MVEX__Listing__c LIMIT 1];
        Contact buyer = [SELECT Id FROM Contact WHERE LastName = 'Buyer' LIMIT 1];
        
        MVEX__Offer__c orphanOffer = new MVEX__Offer__c(
            MVEX__Listing__c = listing.Id,
            MVEX__Buyer_Contact__c = buyer.Id,
            MVEX__Offer_Amount__c = 450000,
            MVEX__Offer_Date__c = Date.today()
            // Intentionally not setting MVEX__First_Offer_Id__c
        );
        insert orphanOffer;
        
        Test.startTest();
        ShowOffersDetailController.OfferTimelineResponse response = 
            ShowOffersDetailController.getOfferTimeline(orphanOffer.Id);
        Test.stopTest();
        
        // Assertions
        System.assertEquals(false, response.isSuccess, 'Response should indicate failure');
        System.assertNotEquals('', response.errorMessage, 'Error message should be present');
        System.assert(response.errorMessage.contains('First Offer ID'), 'Error should mention First Offer ID');
    }
    
    /**
     * @description Test error handling with invalid record ID
     */
    @isTest
    static void testGetOfferTimelineWithInvalidId() {
        // Create a fake ID for an offer that doesn't exist
        Id fakeOfferId = '001000000000000AAA'; // Invalid ID format for Offer
        
        Test.startTest();
        ShowOffersDetailController.OfferTimelineResponse response;
        try {
            response = ShowOffersDetailController.getOfferTimeline(fakeOfferId);
        } catch (Exception e) {
            // If an exception is thrown, this is also acceptable
            System.assert(true, 'Exception thrown for invalid ID');
        }
        Test.stopTest();
        
        // If no exception, verify error response
        if (response != null) {
            System.assertEquals(false, response.isSuccess, 'Response should indicate failure');
        }
    }
    
    /**
     * @description Test sequence numbering in the timeline
     */
    @isTest
    static void testOfferSequenceNumbering() {
        MVEX__Offer__c firstOffer = [
            SELECT Id 
            FROM MVEX__Offer__c 
            WHERE MVEX__Counter_Offer_for__c = null 
            LIMIT 1
        ];
        
        Test.startTest();
        ShowOffersDetailController.OfferTimelineResponse response = 
            ShowOffersDetailController.getOfferTimeline(firstOffer.Id);
        Test.stopTest();
        
        // Verify sequence numbers are incremental
        for (Integer i = 0; i < response.offers.size(); i++) {
            System.assertEquals(i + 1, response.offers[i].sequenceNumber, 
                'Sequence number should be ' + (i + 1));
        }
    }
    
    /**
     * @description Test that offers are ordered by date
     */
    @isTest
    static void testOfferChronologicalOrder() {
        MVEX__Offer__c firstOffer = [
            SELECT Id 
            FROM MVEX__Offer__c 
            WHERE MVEX__Counter_Offer_for__c = null 
            LIMIT 1
        ];
        
        Test.startTest();
        ShowOffersDetailController.OfferTimelineResponse response = 
            ShowOffersDetailController.getOfferTimeline(firstOffer.Id);
        Test.stopTest();
        
        // Verify offers are in chronological order
        for (Integer i = 0; i < response.offers.size() - 1; i++) {
            Date currentDate = response.offers[i].offerDate;
            Date nextDate = response.offers[i + 1].offerDate;
            System.assert(currentDate <= nextDate, 
                'Offers should be in chronological order');
        }
    }
    
    /**
     * @description Test wrapper class initialization
     */
    @isTest
    static void testOfferTimelineResponseWrapper() {
        Test.startTest();
        ShowOffersDetailController.OfferTimelineResponse response = 
            new ShowOffersDetailController.OfferTimelineResponse();
        Test.stopTest();
        
        // Verify default values
        System.assertEquals(true, response.isSuccess, 'Default isSuccess should be true');
        System.assertEquals('', response.errorMessage, 'Default errorMessage should be empty');
        System.assertNotEquals(null, response.offers, 'Offers list should be initialized');
        System.assertEquals(0, response.offers.size(), 'Offers list should be empty');
    }
}