/**
 * Class Name : ListingManagerControllerTest
 * Created By : Karan Singh
 * Last Modified Date : 2026-10-12
 * Last Modified By : Dhruv Kakadiya
 * @description : Test class for ListingManagerController.
 */
@isTest
public class ListingManagerControllerTest {
    
    @TestSetup
    static void setupTestData() {
        // Create Property
        MVEX__Property__c property = new MVEX__Property__c(Name = 'Test Property');
        insert property;

        Map<String, Id> listingRecordTypeMap = new Map<String, Id>();
        for (RecordType rt : [SELECT Id, DeveloperName FROM RecordType WHERE SObjectType IN ('Listing__c', 'MVEX__Listing__c') AND DeveloperName IN ('Rent', 'Sale')]) {
            listingRecordTypeMap.put(rt.DeveloperName, rt.Id);
        }

        // Create Listings with normal standard custom fields
        MVEX__Listing__c listing1 = new MVEX__Listing__c(
            Name = 'Test Listing 1', 
            MVEX__Property__c = property.Id,
            MVEX__City__c = 'New York',
            MVEX__Status__c = 'Active',
            MVEX__Bathrooms__c = 2,
            MVEX__Sq_Ft__c = 1200,
            MVEX__Listing_Type__c = 'Rent',
            RecordTypeId = listingRecordTypeMap.get('Rent')
        );
        MVEX__Listing__c listing2 = new MVEX__Listing__c(
            Name = 'Test Listing 2', 
            MVEX__Property__c = property.Id,
            MVEX__City__c = 'Los Angeles',
            MVEX__Status__c = 'Active',
            MVEX__Bathrooms__c = 3,
            MVEX__Sq_Ft__c = 1500,
            MVEX__Listing_Type__c = 'Sale',
            RecordTypeId = listingRecordTypeMap.get('Sale')
        );
        insert new List<MVEX__Listing__c>{ listing1, listing2 };

        // Create Property Files
        MVEX__Property_File__c propertyFile1 = new MVEX__Property_File__c(
            MVEX__BaseUrl__c = 'https://example.com/file1.jpg', 
            MVEX__Property__c = property.Id
        );
        MVEX__Property_File__c propertyFile2 = new MVEX__Property_File__c(
            MVEX__BaseUrl__c = 'https://example.com/file2.jpg', 
            MVEX__Property__c = property.Id
        );
        insert new List<MVEX__Property_File__c>{ propertyFile1, propertyFile2 };

        // Create Configuration Settings with normal fields instead of listing address fields
        MVEX__Configuration_Settings__c config = new MVEX__Configuration_Settings__c(
            MVEX__Feature_Name__c = 'Listing_Manager_Fields',
            MVEX__Fields_Data__c = '[{"fieldApiname":"MVEX__City__c","label":"City"},{"fieldApiname":"MVEX__Status__c","label":"Status"},{"fieldApiname":"MVEX__Sq_Ft__c","label":"Sq Ft"}]',
            MVEX__Page_Size__c = 15
        );
        insert config;
    }
    
    /**
     * Method Name : testGetListingDataWithConfig
     * @description : Tests getListingData with active custom configuration.
     */
    @isTest
    static void testGetListingDataWithConfig() {
        Test.startTest();
        ListingManagerController.WrapperClass result = ListingManagerController.getListingData();
        Test.stopTest();
        
        // Assertions
        System.assertNotEquals(null, result, 'Result wrapper should not be null');
        System.assertEquals(2, result.listings.size(), 'Should return 2 listings');
        System.assertEquals(1, result.medias.size(), 'Should map media URLs by property ID');
        System.assertEquals(15, result.pageSize, 'Page size should match configuration');
        System.assertNotEquals(null, result.selectedFields, 'Selected fields list should not be null');
        System.assertEquals(3, result.selectedFields.size(), 'Should have 3 configured fields');
    }

    /**
     * Method Name : testGetListingDataWithoutConfig
     * @description : Tests getListingData when no configuration settings record exists.
     */
    @isTest
    static void testGetListingDataWithoutConfig() {
        // Delete the configuration record created in setup
        List<MVEX__Configuration_Settings__c> configs = [SELECT Id FROM MVEX__Configuration_Settings__c];
        delete configs;

        Test.startTest();
        ListingManagerController.WrapperClass result = ListingManagerController.getListingData();
        Test.stopTest();
        
        // Assertions
        System.assertNotEquals(null, result, 'Result wrapper should not be null');
        System.assertEquals(2, result.listings.size(), 'Should return 2 listings');
        System.assertEquals(30, result.pageSize, 'Page size should default to 30');
        System.assertEquals(0, result.selectedFields.size(), 'Selected fields should be empty');
    }

    /**
     * Method Name : testGetObjectFields_listing
     * @description : Tests getObjectFields for MVEX__Listing__c with filter metadata and field describes.
     */
    @isTest
    static void testGetObjectFields_listing() {
        Test.startTest();
        List<ListingManagerController.FieldDetails> fields = ListingManagerController.getObjectFields('MVEX__Listing__c');
        Test.stopTest();

        System.assertNotEquals(null, fields, 'Field details list should not be null');
    }

    /**
     * Method Name : testGetObjectFields_contact
     * @description : Tests getObjectFields for Contact using marketing filter metadata.
     */
    @isTest
    static void testGetObjectFields_contact() {
        Test.startTest();
        List<ListingManagerController.FieldDetails> fields = ListingManagerController.getObjectFields('Contact');
        Test.stopTest();

        System.assertNotEquals(null, fields, 'Contact field details list should not be null');
    }

    /**
     * Method Name : testGetObjectFields_invalidObject
     * @description : Tests getObjectFields exception handling for non-existent object.
     */
    @isTest
    static void testGetObjectFields_invalidObject() {
        Test.startTest();
        List<ListingManagerController.FieldDetails> fields = ListingManagerController.getObjectFields('Invalid_Object_XYZ');
        Test.stopTest();

        System.assertEquals(null, fields, 'Should return null when an invalid object is provided');
    }

    /**
     * Method Name : testGetPicklistValues_success
     * @description : Tests getPicklistValues for a valid picklist field on MVEX__Listing__c.
     */
    @isTest
    static void testGetPicklistValues_success() {
        Test.startTest();
        List<Map<String, String>> picklistValues = ListingManagerController.getPicklistValues('MVEX__Listing_Type__c', 'MVEX__Listing__c');
        Test.stopTest();

        System.assertNotEquals(null, picklistValues, 'Picklist values list should not be null');
        System.assert(!picklistValues.isEmpty(), 'Picklist values should be populated for MVEX__Listing_Type__c');
    }

    /**
     * Method Name : testGetPicklistValues_invalid
     * @description : Tests getPicklistValues exception handling with invalid field.
     */
    @isTest
    static void testGetPicklistValues_invalid() {
        Test.startTest();
        List<Map<String, String>> picklistValues = ListingManagerController.getPicklistValues('Non_Existent_Field', 'MVEX__Listing__c');
        Test.stopTest();

        System.assertEquals(null, picklistValues, 'Should return null when invalid field is provided');
    }

    /**
     * Method Name : testGetFilteredListings_all
     * @description : Tests getFilteredListings with TRUE or blank condition returning all listings.
     */
    @isTest
    static void testGetFilteredListings_all() {
        Test.startTest();
        List<MVEX__Listing__c> resultTrue = ListingManagerController.getFilteredListings('TRUE');
        List<MVEX__Listing__c> resultBlank = ListingManagerController.getFilteredListings('');
        Test.stopTest();

        System.assertEquals(2, resultTrue.size(), 'Should return all 2 listings when filter is TRUE');
        System.assertEquals(2, resultBlank.size(), 'Should return all 2 listings when filter is blank');
    }

    /**
     * Method Name : testGetFilteredListings_withCondition
     * @description : Tests getFilteredListings with a specific WHERE condition.
     */
    @isTest
    static void testGetFilteredListings_withCondition() {
        Test.startTest();
        List<MVEX__Listing__c> result = ListingManagerController.getFilteredListings('MVEX__City__c = \'New York\'');
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Should return 1 listing matching city New York');
    }

    /**
     * Method Name : testGetFilteredListings_invalidCondition
     * @description : Tests getFilteredListings exception handling when condition syntax is invalid.
     */
    @isTest
    static void testGetFilteredListings_invalidCondition() {
        Test.startTest();
        List<MVEX__Listing__c> result = ListingManagerController.getFilteredListings('InvalidField__c = \'XYZ\'');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(0, result.size(), 'Should return empty list on query exception');
    }

    /**
     * Method Name : testGetStaticFields_existing
     * @description : Tests getStaticFields when configuration record exists.
     */
    @isTest
    static void testGetStaticFields_existing() {
        Test.startTest();
        String result = ListingManagerController.getStaticFields('MVEX__Listing__c', 'Listing_Manager_Fields');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return fields JSON string when feature exists');
        System.assert(result.contains('MVEX__City__c'), 'Returned JSON should contain configured fields');
    }

    /**
     * Method Name : testGetStaticFields_nonExisting
     * @description : Tests getStaticFields when configuration record does not exist.
     */
    @isTest
    static void testGetStaticFields_nonExisting() {
        Test.startTest();
        String result = ListingManagerController.getStaticFields('MVEX__Listing__c', 'Non_Existing_Feature');
        Test.stopTest();

        System.assertEquals(null, result, 'Should return null when configuration record does not exist');
    }

    /**
     * Method Name : testSaveStaticFields_updateExisting
     * @description : Tests saveStaticFields updating an existing configuration record.
     */
    @isTest
    static void testSaveStaticFields_updateExisting() {
        String updatedJson = '[{"fieldApiname":"Name","label":"Listing Name"}]';

        Test.startTest();
        ListingManagerController.saveStaticFields('MVEX__Listing__c', 'Listing_Manager_Fields', updatedJson);
        Test.stopTest();

        MVEX__Configuration_Settings__c updatedConfig = [
            SELECT MVEX__Fields_Data__c 
            FROM MVEX__Configuration_Settings__c 
            WHERE MVEX__Feature_Name__c = 'Listing_Manager_Fields' 
            LIMIT 1
        ];
        System.assertEquals(updatedJson, updatedConfig.MVEX__Fields_Data__c, 'Configuration should be updated with new fields JSON');
    }

    /**
     * Method Name : testSaveStaticFields_createNew
     * @description : Tests saveStaticFields inserting a new configuration record when none exists.
     */
    @isTest
    static void testSaveStaticFields_createNew() {
        String newJson = '[{"fieldApiname":"LastName","label":"Last Name"}]';

        Test.startTest();
        ListingManagerController.saveStaticFields('Contact', 'Marketing_List_Custom_Feature', newJson);
        Test.stopTest();

        List<MVEX__Configuration_Settings__c> createdConfigs = [
            SELECT MVEX__Fields_Data__c, MVEX__Object_API_Name__c, MVEX__Feature_Name__c 
            FROM MVEX__Configuration_Settings__c 
            WHERE MVEX__Feature_Name__c = 'Marketing_List_Custom_Feature'
        ];
        System.assertEquals(1, createdConfigs.size(), 'New configuration setting should be created');
    }
}