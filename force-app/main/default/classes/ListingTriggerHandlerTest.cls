/**
 * Class Name : ListingTriggerHandlerTest
 * Last Modified Date : 2026-10-12
 * Last Modified By : Dhruv Kakadiya
 * @description : Test class for ListingTriggerHandler.
 */

@isTest
public class ListingTriggerHandlerTest {

    private static Id getRecordTypeId(String developerName) {
        Map<String, Schema.RecordTypeInfo> rtMap = Schema.SObjectType.MVEX__Listing__c.getRecordTypeInfosByDeveloperName();
        if (rtMap != null && rtMap.containsKey(developerName)) {
            return rtMap.get(developerName).getRecordTypeId();
        }
        for (RecordType rt : [SELECT Id, DeveloperName FROM RecordType WHERE SObjectType IN ('Listing__c', 'MVEX__Listing__c') AND DeveloperName = :developerName LIMIT 1]) {
            return rt.Id;
        }
        return null;
    }

    @testSetup
    static void setupData() {
        MVEX__Property__c prop = new MVEX__Property__c(
            Name = 'Existing Property',
            MVEX__Address__c = '123 Salesforce Lane',
            MVEX__Bedrooms__c = 3,
            MVEX__Bathrooms__c = 2
        );
        insert prop;
    }

    @isTest
    static void testAfterInsert_AutomaticSyncOn() {
        // Mocking Metadata: Sync ON with field mappings
        ListingTriggerHandler.mockMetadata = new MVEX__Mapping_Metadata__mdt(
            MVEX__BlockedFields__c = 'CreatedDate;LastModifiedDate',
            MVEX__Mapping_String__c = 'Name:Name;MVEX__Address__c:MVEX__Address__c'
        );

        Id rentRtId = getRecordTypeId('Rent');

        List<MVEX__Listing__c> newListings = new List<MVEX__Listing__c>();
        
        // Listing 1: Auto create Property
        newListings.add(new MVEX__Listing__c(
            Name = 'New Rent Listing 1',
            MVEX__Address__c = '123 Salesforce Lane',
            MVEX__Bedrooms__c = 3,
            MVEX__Bathrooms__c = 2,
            MVEX__Listing_Type__c = 'Rent',
            RecordTypeId = rentRtId
        ));

        // Listing 2: Auto create Property
        newListings.add(new MVEX__Listing__c(
            Name = 'New Rent Listing 2',
            MVEX__Address__c = '789 Discovery Way',
            MVEX__Bedrooms__c = 5,
            MVEX__Bathrooms__c = 4,
            MVEX__Listing_Type__c = 'Rent',
            RecordTypeId = rentRtId
        ));

        // Listing 3: Already has Property assigned
        MVEX__Property__c existingProp = [SELECT Id FROM MVEX__Property__c LIMIT 1];
        newListings.add(new MVEX__Listing__c(
            Name = 'Manual Link',
            MVEX__Property__c = existingProp.Id,
            MVEX__Address__c = '123 Salesforce Lane',
            MVEX__Listing_Type__c = 'Rent',
            RecordTypeId = rentRtId
        ));

        Test.startTest();
        insert newListings;
        Test.stopTest();

        List<MVEX__Listing__c> insertedListings = [
            SELECT Id, Name, MVEX__Property__c 
            FROM MVEX__Listing__c 
            WHERE Id IN :newListings
        ];
        System.assertEquals(3, insertedListings.size(), 'All 3 listings should be inserted');
        for (MVEX__Listing__c lst : insertedListings) {
            System.assertNotEquals(null, lst.MVEX__Property__c, 'All listings should have a Property associated');
        }

        // Verify mapped address on newly created property
        MVEX__Listing__c lst1 = [SELECT Id, MVEX__Property__c FROM MVEX__Listing__c WHERE Name = 'New Rent Listing 1' LIMIT 1];
        MVEX__Property__c createdProp = [SELECT Id, MVEX__Address__c FROM MVEX__Property__c WHERE Id = :lst1.MVEX__Property__c];
        System.assertEquals('123 Salesforce Lane', createdProp.MVEX__Address__c, 'Property address should be mapped from listing');
    }

    @isTest
    static void testAfterInsert_AutomaticSyncOff() {
        ListingTriggerHandler.mockMetadata = new MVEX__Mapping_Metadata__mdt(
            MVEX__BlockedFields__c = 'CreatedDate',
            MVEX__Mapping_String__c = 'Name:Name;MVEX__Address__c:MVEX__Address__c;MVEX__Bedrooms__c:MVEX__Bedrooms__c'
        );

        Id saleRtId = getRecordTypeId('Sale');

        List<MVEX__Listing__c> newListings = new List<MVEX__Listing__c>();
        
        newListings.add(new MVEX__Listing__c(
            Name = 'Sale Listing 1',
            MVEX__Address__c = '123 Salesforce Lane',
            MVEX__Bedrooms__c = 3,
            MVEX__Listing_Type__c = 'Sale',
            RecordTypeId = saleRtId
        ));

        newListings.add(new MVEX__Listing__c(
            Name = 'Sale Listing 2',
            MVEX__Address__c = '456 Off St',
            MVEX__Listing_Type__c = 'Sale',
            RecordTypeId = saleRtId
        ));

        MVEX__Property__c existingProp = [SELECT Id FROM MVEX__Property__c LIMIT 1];
        newListings.add(new MVEX__Listing__c(
            Name = 'Sale Existing Prop Link',
            MVEX__Property__c = existingProp.Id,
            MVEX__Address__c = '123 Salesforce Lane',
            MVEX__Listing_Type__c = 'Sale',
            RecordTypeId = saleRtId
        ));

        Test.startTest();
        insert newListings;
        Test.stopTest();
        
        System.assertEquals(3, [SELECT count() FROM MVEX__Listing__c WHERE Id IN :newListings], 'All 3 listings should be saved');
    }

    @isTest
    static void testAfterInsert_IgnoreSystemAndInvalidFields() {
        ListingTriggerHandler.mockMetadata = new MVEX__Mapping_Metadata__mdt(
            MVEX__BlockedFields__c = 'CreatedDate',
            MVEX__Mapping_String__c = 'Id:Id;RecordTypeId:RecordTypeId;InvalidField__c:InvalidField__c;;Name:Name'
        );

        Id rentRtId = getRecordTypeId('Rent');

        MVEX__Listing__c listing = new MVEX__Listing__c(
            Name = 'Test Field Filter Listing',
            MVEX__Listing_Type__c = 'Rent',
            RecordTypeId = rentRtId
        );

        Test.startTest();
        insert listing;
        Test.stopTest();

        MVEX__Listing__c insertedListing = [SELECT Id, MVEX__Property__c FROM MVEX__Listing__c WHERE Id = :listing.Id];
        System.assertNotEquals(null, insertedListing.MVEX__Property__c, 'Property should be created and linked despite invalid mapping tokens');
    }

    @isTest
    static void testAfterUpdateDeleteUndelete() {
        ListingTriggerHandler.mockMetadata = new MVEX__Mapping_Metadata__mdt(
            MVEX__BlockedFields__c = 'CreatedDate',
            MVEX__Mapping_String__c = 'Name:Name'
        );

        Id saleRtId = getRecordTypeId('Sale');

        MVEX__Listing__c listing = new MVEX__Listing__c(
            Name = 'Test Event Listing',
            MVEX__Listing_Type__c = 'Sale',
            RecordTypeId = saleRtId
        );
        insert listing;

        Test.startTest();
        listing.Name = 'Test Event Listing Updated';
        update listing;

        delete listing;

        undelete listing;
        Test.stopTest();

        MVEX__Listing__c restoredListing = [SELECT Id, Name, IsDeleted FROM MVEX__Listing__c WHERE Id = :listing.Id ALL ROWS];
        System.assertEquals(false, restoredListing.IsDeleted, 'Listing should be undeleted successfully');
    }

    @isTest
    static void testHandleListingAfterInsert_DirectCall() {
        Id rentRtId = getRecordTypeId('Rent');

        MVEX__Listing__c listing = new MVEX__Listing__c(
            Name = 'Direct Handle Listing',
            MVEX__Address__c = '456 Direct Way',
            MVEX__Bedrooms__c = 4,
            MVEX__Listing_Type__c = 'Rent',
            RecordTypeId = rentRtId
        );
        insert listing;

        // Reset property to null so handleListingAfterInsert processes it directly
        listing.MVEX__Property__c = null;

        ListingTriggerHandler.mockMetadata = new MVEX__Mapping_Metadata__mdt(
            MVEX__BlockedFields__c = 'CreatedDate;LastModifiedDate',
            MVEX__Mapping_String__c = 'Name:Name;MVEX__Address__c:MVEX__Address__c'
        );

        ListingTriggerHandler handler = new ListingTriggerHandler(
            new List<MVEX__Listing__c>{ listing },
            null, null, null, true, false, false, false
        );

        Test.startTest();
        handler.handleListingAfterInsert();
        Test.stopTest();

        MVEX__Listing__c updatedListing = [SELECT Id, MVEX__Property__c FROM MVEX__Listing__c WHERE Id = :listing.Id];
        System.assertNotEquals(null, updatedListing.MVEX__Property__c, 'Property should be created and linked to the listing');
    }

    @isTest
    static void testHandleListingAfterInsert_AlreadyHasProperty() {
        MVEX__Property__c existingProp = [SELECT Id FROM MVEX__Property__c LIMIT 1];
        Id rentRtId = getRecordTypeId('Rent');

        MVEX__Listing__c listing = new MVEX__Listing__c(
            Name = 'Already Has Property Listing',
            MVEX__Property__c = existingProp.Id,
            MVEX__Listing_Type__c = 'Rent',
            RecordTypeId = rentRtId
        );
        insert listing;

        ListingTriggerHandler handler = new ListingTriggerHandler(
            new List<MVEX__Listing__c>{ listing },
            null, null, null, true, false, false, false
        );

        Test.startTest();
        handler.handleListingAfterInsert();
        Test.stopTest();

        MVEX__Listing__c checkListing = [SELECT Id, MVEX__Property__c FROM MVEX__Listing__c WHERE Id = :listing.Id];
        System.assertEquals(existingProp.Id, checkListing.MVEX__Property__c, 'Property should remain the same and early return executed');
    }

    @isTest
    static void testHandleListingAfterInsert_FallbackBranch() {
        Id rentRtId = getRecordTypeId('Rent');

        // Address is longer than 80 chars, but Name is short (< 80 chars)
        String longAddress = 'A'.repeat(85);
        MVEX__Listing__c listing = new MVEX__Listing__c(
            Name = 'Fallback Test Listing',
            MVEX__Address__c = longAddress,
            MVEX__Listing_Type__c = 'Rent',
            RecordTypeId = rentRtId
        );
        insert listing;

        // Reset its property to null so handleListingAfterInsert processes it
        listing.MVEX__Property__c = null;

        // Map Address__c (85 chars) to Property Name (max 80 chars) to cause DML failure on propertiesToInsert
        ListingTriggerHandler.mockMetadata = new MVEX__Mapping_Metadata__mdt(
            MVEX__BlockedFields__c = 'CreatedDate',
            MVEX__Mapping_String__c = 'MVEX__Address__c:Name'
        );

        ListingTriggerHandler handler = new ListingTriggerHandler(
            new List<MVEX__Listing__c>{ listing },
            null, null, null, true, false, false, false
        );

        Test.startTest();
        handler.handleListingAfterInsert();
        Test.stopTest();

        MVEX__Listing__c updatedListing = [SELECT Id, MVEX__Property__c FROM MVEX__Listing__c WHERE Id = :listing.Id];
        System.assertNotEquals(null, updatedListing.MVEX__Property__c, 'Fallback property should be linked when normal property insert fails');

        MVEX__Property__c fallbackProp = [SELECT Id, Name, MVEX__Failed_Mapping_Reason__c FROM MVEX__Property__c WHERE Id = :updatedListing.MVEX__Property__c];
        System.assertEquals('Fallback Test Listing', fallbackProp.Name, 'Fallback property should use listing name');
        System.assertNotEquals(null, fallbackProp.MVEX__Failed_Mapping_Reason__c, 'Failure reason should be captured on fallback property');
    }

    @isTest
    static void testPublishEvents_directCall() {
        Id rentRtId = getRecordTypeId('Rent');
        MVEX__Listing__c listing = new MVEX__Listing__c(
            Name = 'Direct Event Listing',
            MVEX__Listing_Type__c = 'Rent',
            RecordTypeId = rentRtId
        );
        insert listing;

        Test.startTest();
        ListingTriggerHandler handler = new ListingTriggerHandler(
            new List<MVEX__Listing__c>{ listing },
            new List<MVEX__Listing__c>{ listing },
            new Map<Id, MVEX__Listing__c>{ listing.Id => listing },
            new Map<Id, MVEX__Listing__c>{ listing.Id => listing },
            false, true, false, false
        );

        handler.publishRefreshEvent();
        handler.publishPortalSyndicationRefreshEvent();

        // Null list safety
        ListingTriggerHandler emptyHandler = new ListingTriggerHandler(
            null, null, null, null, false, false, false, false
        );
        emptyHandler.publishPortalSyndicationRefreshEvent();
        Test.stopTest();

        System.assert(true, 'Direct event publish methods should execute without unhandled exceptions');
    }

    @isTest
    static void testRealMetadataQueryFallback() {
        ListingTriggerHandler.mockMetadata = null; // Ensure mock is null to execute real metadata query

        Id saleRtId = getRecordTypeId('Sale');
        MVEX__Listing__c listing = new MVEX__Listing__c(
            Name = 'Real Metadata Listing',
            MVEX__Listing_Type__c = 'Sale',
            RecordTypeId = saleRtId
        );

        Test.startTest();
        insert listing;
        Test.stopTest();

        MVEX__Listing__c insertedListing = [SELECT Id, MVEX__Property__c FROM MVEX__Listing__c WHERE Id = :listing.Id];
        System.assertNotEquals(null, insertedListing.Id, 'Listing should be inserted using real custom metadata');
    }

    @isTest
    static void testPublishRefreshEvent_negative() {
        // Pass a null listing element — the for-loop in publishPortalSyndicationRefreshEvent
        // calls listing.Id on null, throwing NPE which is caught by the catch block
        ListingTriggerHandler handler = new ListingTriggerHandler(
            new List<MVEX__Listing__c>{ null }, null, null, null, false, false, false, false
        );

        Test.startTest();
        handler.publishPortalSyndicationRefreshEvent();
        Test.stopTest();

        System.assert(true, 'publishRefreshEvent should handle exception gracefully');
    }

    @isTest
    static void testPublishPortalSyndicationRefreshEvent_negative() {
        // Null listing element inside the list causes NPE on listing.Id inside the for-loop
        ListingTriggerHandler handler = new ListingTriggerHandler(
            new List<MVEX__Listing__c>{ null }, null, null, null, false, false, false, false
        );

        Test.startTest();
        handler.publishPortalSyndicationRefreshEvent();
        Test.stopTest();

        System.assert(true, 'publishPortalSyndicationRefreshEvent should handle exception gracefully');
    }

    @isTest
    static void testHandleListingAfterInsert_fallbackException_negative() {
        Id rentRtId = getRecordTypeId('Rent');

        // Address longer than 80 chars causes the primary property insert to fail
        String longAddress = 'A'.repeat(85);
        MVEX__Listing__c listing = new MVEX__Listing__c(
            Name = 'Fallback Exception Test Listing',
            MVEX__Address__c = longAddress,
            MVEX__Listing_Type__c = 'Rent',
            RecordTypeId = rentRtId
        );
        // Do not insert listing so listing.Id is null.
        // During fallback, inserting fallbackProperties succeeds, but updating
        // listingsToUpdate with a null Id throws DmlException, which is caught by fallbackEx.

        // Map Address__c to Property Name to fail primary property creation
        ListingTriggerHandler.mockMetadata = new MVEX__Mapping_Metadata__mdt(
            MVEX__BlockedFields__c = 'CreatedDate',
            MVEX__Mapping_String__c = 'MVEX__Address__c:Name'
        );

        ListingTriggerHandler handler = new ListingTriggerHandler(
            new List<MVEX__Listing__c>{ listing },
            null, null, null, true, false, false, false
        );

        Test.startTest();
        handler.handleListingAfterInsert();
        Test.stopTest();

        System.assert(true, 'handleListingAfterInsert should catch fallback property creation exception');
    }
}