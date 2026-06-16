@isTest
public class ListingTriggerHandlerTest {

    @testSetup
    static void setupData() {
        // Create an existing property to test the "Matching Key" logic
        Property__c prop = new Property__c(
            Name = 'Match Me',
            Address__c = '123 Salesforce Lane',
            Bedrooms__c = 3,
            Bathrooms__c = 2
        );
        insert prop;
    }

    @isTest
    static void testAfterInsert_AutomaticSyncOn() {
        // Mocking Metadata: Sync ON
        ListingTriggerHandler.mockMetadata = new Mapping_Metadata__mdt(
            Automatic_Sync__c = true,
            BlockedFields__c = 'CreatedDate;LastModifiedDate',
            Mapping_String__c = 'Name:Name;Address__c:Address__c'
        );

        Map<String, Id> listingRecordTypeMap = new Map<String, Id>();
        for (RecordType rt : [SELECT Id, DeveloperName FROM RecordType WHERE SObjectType IN ('Listing__c', 'MVEX__Listing__c') AND DeveloperName IN ('Rent', 'Sale')]) {
            listingRecordTypeMap.put(rt.DeveloperName, rt.Id);
        }

        List<Listing__c> newListings = new List<Listing__c>();
        
        // 1. Coverage for matchingPropertiesMap.containsKey(propertyKey) == true
        newListings.add(new Listing__c(
            Name = 'Match Me',
            Address__c = '123 Salesforce Lane',
            Bedrooms__c = 3,
            Bathrooms__c = 2,
            Listing_Type__c = 'Rent',
            RecordTypeId = listingRecordTypeMap.get('Rent')
        ));

        // 2. Coverage for else branch (Create a new property)
        newListings.add(new Listing__c(
            Name = 'Unique Listing',
            Address__c = '789 Discovery Way',
            Bedrooms__c = 5,
            Bathrooms__c = 4,
            Listing_Type__c = 'Rent',
            RecordTypeId = listingRecordTypeMap.get('Rent')
        ));

        // 3. Coverage for existingPropertiesMap branch (Property__c != null)
        Property__c existingProp = [SELECT Id FROM Property__c LIMIT 1];
        newListings.add(new Listing__c(
            Name = 'Manual Link',
            Property__c = existingProp.Id,
            Address__c = '123 Salesforce Lane',
            Listing_Type__c = 'Rent',
            RecordTypeId = listingRecordTypeMap.get('Rent')
        ));

        Test.startTest();
        insert newListings;
        Test.stopTest();
    }

    @isTest
    static void testAfterInsert_AutomaticSyncOff() {
        // Mocking Metadata: Sync OFF
        ListingTriggerHandler.mockMetadata = new Mapping_Metadata__mdt(
            Automatic_Sync__c = false,
            BlockedFields__c = 'CreatedDate',
            Mapping_String__c = 'Name:Name;Address__c:Address__c;Bedrooms__c:Bedrooms__c'
        );

        Map<String, Id> listingRecordTypeMap = new Map<String, Id>();
        for (RecordType rt : [SELECT Id, DeveloperName FROM RecordType WHERE SObjectType IN ('Listing__c', 'MVEX__Listing__c') AND DeveloperName IN ('Rent', 'Sale')]) {
            listingRecordTypeMap.put(rt.DeveloperName, rt.Id);
        }

        List<Listing__c> newListings = new List<Listing__c>();
        
        // Match existing
        newListings.add(new Listing__c(
            Name = 'Match Me',
            Address__c = '123 Salesforce Lane',
            Bedrooms__c = 3,
            Listing_Type__c = 'Sale',
            RecordTypeId = listingRecordTypeMap.get('Sale')
        ));

        // Create new
        newListings.add(new Listing__c(
            Name = 'Sync Off New',
            Address__c = '456 Off St',
            Listing_Type__c = 'Sale',
            RecordTypeId = listingRecordTypeMap.get('Sale')
        ));

        // Create with existing property
        Property__c existingProp = [SELECT Id FROM Property__c LIMIT 1];
        newListings.add(new Listing__c(
            Name = 'Sync Off Existing Prop',
            Property__c = existingProp.Id,
            Address__c = '123 Salesforce Lane',
            Listing_Type__c = 'Sale',
            RecordTypeId = listingRecordTypeMap.get('Sale')
        ));

        Test.startTest();
        insert newListings;
        Test.stopTest();
        
        System.assertEquals(2, [SELECT count() FROM Listing__c WHERE Name LIKE 'Match Me%' OR Name = 'Sync Off New']);
    }
}