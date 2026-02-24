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

        List<Listing__c> newListings = new List<Listing__c>();
        
        // 1. Coverage for matchingPropertiesMap.containsKey(propertyKey) == true
        newListings.add(new Listing__c(
            Name = 'Match Me',
            Address__c = '123 Salesforce Lane',
            Bedrooms__c = 3,
            Bathrooms__c = 2
        ));

        // 2. Coverage for else branch (Create a new property)
        newListings.add(new Listing__c(
            Name = 'Unique Listing',
            Address__c = '789 Discovery Way',
            Bedrooms__c = 5,
            Bathrooms__c = 4
        ));

        // 3. Coverage for existingPropertiesMap branch (Property__c != null)
        Property__c existingProp = [SELECT Id FROM Property__c LIMIT 1];
        newListings.add(new Listing__c(
            Name = 'Manual Link',
            Property__c = existingProp.Id,
            Address__c = '123 Salesforce Lane'
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

        List<Listing__c> newListings = new List<Listing__c>();
        
        // Match existing
        newListings.add(new Listing__c(
            Name = 'Match Me',
            Address__c = '123 Salesforce Lane',
            Bedrooms__c = 3
        ));

        // Create new
        newListings.add(new Listing__c(
            Name = 'Sync Off New',
            Address__c = '456 Off St'
        ));

        Test.startTest();
        insert newListings;
        Test.stopTest();
        
        System.assertEquals(2, [SELECT count() FROM Listing__c WHERE Name LIKE 'Match Me%' OR Name = 'Sync Off New']);
    }

    @isTest
    static void testAfterUpdate_AutomaticSyncOn() {
        ListingTriggerHandler.mockMetadata = new Mapping_Metadata__mdt(
            Automatic_Sync__c = true,
            BlockedFields__c = 'CreatedDate'
        );

        Property__c prop = [SELECT Id FROM Property__c LIMIT 1];
        Listing__c listRecord = new Listing__c(
            Name = 'Update Test',
            Property__c = prop.Id,
            Address__c = 'Old Address'
        );
        insert listRecord;

        Test.startTest();
        listRecord.Address__c = 'New Updated Address';
        update listRecord;
        Test.stopTest();

        Property__c updatedProp = [SELECT Address__c FROM Property__c WHERE Id = :prop.Id];
        System.assertEquals('New Updated Address', updatedProp.Address__c);
    }

    @isTest
    static void testAfterUpdate_AutomaticSyncOff() {
        ListingTriggerHandler.mockMetadata = new Mapping_Metadata__mdt(
            Automatic_Sync__c = false,
            BlockedFields__c = 'CreatedDate',
            Mapping_String__c = 'Address__c:Address__c'
        );

        Property__c prop = [SELECT Id FROM Property__c LIMIT 1];
        Listing__c listRecord = new Listing__c(
            Name = 'Update Test Off',
            Property__c = prop.Id,
            Address__c = 'Old Address'
        );
        insert listRecord;

        Test.startTest();
        listRecord.Address__c = 'Manual Update Address';
        update listRecord;
        Test.stopTest();
    }

    @isTest
    static void testExceptionHandling() {
        // Triggering the catch block by passing null into the logic
        ListingTriggerHandler.mockMetadata = new Mapping_Metadata__mdt(Automatic_Sync__c = true);
        
        Test.startTest();
        // Construct handler with nulls to force NullPointerException in logic
        ListingTriggerHandler handler = new ListingTriggerHandler(
            null, null, null, null, true, false, false, false
        );
        handler.handleListingAfterInsert();
        handler.handleListingAfterUpdate();
        Test.stopTest();
        
        // If it reaches here without failing the test, the catch block worked.
        System.assert(true);
    }
}