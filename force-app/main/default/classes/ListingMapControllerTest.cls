@IsTest
public class ListingMapControllerTest {

    @testSetup
    static void setupData() {

        MVEX__Listing__c listing = new MVEX__Listing__c(
            Name = 'Test Listing',
            MVEX__Listing_Type__c = 'Sale',
            MVEX__Property_Category__c = 'Residential',
            MVEX__Property_Type__c = 'Apartment',
            MVEX__Sq_Ft__c = 1200        
        );
        insert listing;
    }

    /* ---------------- Positive Scenario ---------------- */
    @IsTest
    static void testGetListingDetails_success() {

        MVEX__Listing__c lst = [SELECT Id FROM MVEX__Listing__c LIMIT 1];

        Test.startTest();
        MVEX__Listing__c result = ListingMapController.getListingDetails(lst.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Listing should be returned');
        System.assertEquals(lst.Id, result.Id, 'Returned listing should match input Id');
    }

    /* ---------------- Null Id Scenario ---------------- */
    @IsTest
    static void testGetListingDetails_nullId() {

        Test.startTest();
        MVEX__Listing__c result = ListingMapController.getListingDetails(null);
        Test.stopTest();

        // Method catches exception and returns null
        System.assertEquals(null, result, 'Should return null when recordId is null');
    }
}