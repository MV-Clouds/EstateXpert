/**
 * Class Name : ListingManagerControllerTest
 * Created By : Karan Singh
 * Last Modified Date : 2026-06-26
 * Last Modified By : Karan Singh
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
            Listing_Type__c = 'Rent',
            RecordTypeId = listingRecordTypeMap.get('Rent')
        );
        MVEX__Listing__c listing2 = new MVEX__Listing__c(
            Name = 'Test Listing 2', 
            MVEX__Property__c = property.Id,
            MVEX__City__c = 'Los Angeles',
            MVEX__Status__c = 'Active',
            MVEX__Bathrooms__c = 3,
            MVEX__Sq_Ft__c = 1500,
            Listing_Type__c = 'Sale',
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
}