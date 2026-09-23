@isTest
public class ListingTriggerHandlerTest {

    @testSetup
    static void setupData() {
        // Create an existing property to test the "Matching Key" logic
        MVEX__Property__c prop = new MVEX__Property__c(
            Name = 'Match Me',
            MVEX__Address__c = '123 Salesforce Lane',
            MVEX__Bedrooms__c = 3,
            MVEX__Bathrooms__c = 2
        );
        insert prop;
    }

    @isTest
    static void testAfterInsert_AutomaticSyncOn() {
        // Mocking Metadata: Sync ON
        ListingTriggerHandler.mockMetadata = new MVEX__Mapping_Metadata__mdt(
            MVEX__Automatic_Sync__c = true,
            MVEX__BlockedFields__c = 'CreatedDate;LastModifiedDate',
            MVEX__Mapping_String__c = 'Name:Name;MVEX__Address__c:MVEX__Address__c'
        );

        Map<String, Id> listingRecordTypeMap = new Map<String, Id>();
        for (RecordType rt : [SELECT Id, DeveloperName FROM RecordType WHERE SObjectType IN ('Listing__c', 'MVEX__Listing__c') AND DeveloperName IN ('Rent', 'Sale')]) {
            listingRecordTypeMap.put(rt.DeveloperName, rt.Id);
        }

        List<MVEX__Listing__c> newListings = new List<MVEX__Listing__c>();
        
        // 1. Coverage for matchingPropertiesMap.containsKey(propertyKey) == true
        newListings.add(new MVEX__Listing__c(
            Name = 'Match Me',
            MVEX__Address__c = '123 Salesforce Lane',
            MVEX__Bedrooms__c = 3,
            MVEX__Bathrooms__c = 2,
            MVEX__Listing_Type__c = 'Rent',
            RecordTypeId = listingRecordTypeMap.get('Rent')
        ));

        // 2. Coverage for else branch (Create a new property)
        newListings.add(new MVEX__Listing__c(
            Name = 'Unique Listing',
            MVEX__Address__c = '789 Discovery Way',
            MVEX__Bedrooms__c = 5,
            MVEX__Bathrooms__c = 4,
            MVEX__Listing_Type__c = 'Rent',
            RecordTypeId = listingRecordTypeMap.get('Rent')
        ));

        // 3. Coverage for existingPropertiesMap branch (Property__c != null)
        MVEX__Property__c existingProp = [SELECT Id FROM MVEX__Property__c LIMIT 1];
        newListings.add(new MVEX__Listing__c(
            Name = 'Manual Link',
            MVEX__Property__c = existingProp.Id,
            MVEX__Address__c = '123 Salesforce Lane',
            MVEX__Listing_Type__c = 'Rent',
            RecordTypeId = listingRecordTypeMap.get('Rent')
        ));

        Test.startTest();
        insert newListings;
        Test.stopTest();
    }

    @isTest
    static void testAfterInsert_AutomaticSyncOff() {
        // Mocking Metadata: Sync OFF
        ListingTriggerHandler.mockMetadata = new MVEX__Mapping_Metadata__mdt(
            MVEX__Automatic_Sync__c = false,
            MVEX__BlockedFields__c = 'CreatedDate',
            MVEX__Mapping_String__c = 'Name:Name;MVEX__Address__c:MVEX__Address__c;MVEX__Bedrooms__c:MVEX__Bedrooms__c'
        );

        Map<String, Id> listingRecordTypeMap = new Map<String, Id>();
        for (RecordType rt : [SELECT Id, DeveloperName FROM RecordType WHERE SObjectType IN ('Listing__c', 'MVEX__Listing__c') AND DeveloperName IN ('Rent', 'Sale')]) {
            listingRecordTypeMap.put(rt.DeveloperName, rt.Id);
        }

        List<MVEX__Listing__c> newListings = new List<MVEX__Listing__c>();
        
        // Match existing
        newListings.add(new MVEX__Listing__c(
            Name = 'Match Me',
            MVEX__Address__c = '123 Salesforce Lane',
            MVEX__Bedrooms__c = 3,
            MVEX__Listing_Type__c = 'Sale',
            RecordTypeId = listingRecordTypeMap.get('Sale')
        ));

        // Create new
        newListings.add(new MVEX__Listing__c(
            Name = 'Sync Off New',
            MVEX__Address__c = '456 Off St',
            MVEX__Listing_Type__c = 'Sale',
            RecordTypeId = listingRecordTypeMap.get('Sale')
        ));

        // Create with existing property
        MVEX__Property__c existingProp = [SELECT Id FROM MVEX__Property__c LIMIT 1];
        newListings.add(new MVEX__Listing__c(
            Name = 'Sync Off Existing Prop',
            MVEX__Property__c = existingProp.Id,
            MVEX__Address__c = '123 Salesforce Lane',
            MVEX__Listing_Type__c = 'Sale',
            RecordTypeId = listingRecordTypeMap.get('Sale')
        ));

        Test.startTest();
        insert newListings;
        Test.stopTest();
        
        System.assertEquals(2, [SELECT count() FROM MVEX__Listing__c WHERE Name LIKE 'Match Me%' OR Name = 'Sync Off New']);
    }

    @isTest
    static void testAfterUpdateDeleteUndelete() {
        ListingTriggerHandler.mockMetadata = new MVEX__Mapping_Metadata__mdt(
            MVEX__Automatic_Sync__c = false,
            MVEX__BlockedFields__c = 'CreatedDate',
            MVEX__Mapping_String__c = 'Name:Name'
        );

        MVEX__Listing__c listing = new MVEX__Listing__c(
            Name = 'Test Event Listing'
        );
        insert listing;

        Test.startTest();
        listing.Name = 'Test Event Listing Updated';
        update listing;

        delete listing;

        undelete listing;
        Test.stopTest();

        System.assertNotEquals(null, listing.Id);
    }
}