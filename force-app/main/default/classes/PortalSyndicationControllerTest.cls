/**
* Class Name : PortalSyndicationControllerTest
* Created By : Karan Singh
* Last Modified Date : 24/06/2024
* Last Modified By : Karan Singh
* @description : Used to test PortalSyndicationController class.
*/
@isTest
public with sharing class PortalSyndicationControllerTest {
    /**
    * Method Name : setupTestData
    * @description : Used to setup test data.
    */
    @testSetup
    static void setupTestData() {
        try {
            Contact contact = new Contact(LastName = 'Dev Test');
            insert contact;

            Property__c property = new Property__c(Name = 'Dev Test');
            insert property;

            Portal__c portal1 = new Portal__c(
                Name = 'Propertyfinder', 
                Is_Active__c = true, 
                Generator__c = 'Propertyfinder', 
                Field_Mapping__c = '{"MVEX__Listing_Price__c":"pricing.price","MVEX__City__c":"location.town_or_city","MVEX__Broker_s_Listing_ID__c":"listing_reference","MVEX__Status__c":"life_cycle_status","MVEX__Property_Type__c":"property_type","MVEX__Rent_Frequency__c":"pricing.rent_frequency","CurrencyIsoCode":"pricing.currency_code","MVEX__Listing_Type__c":"pricing.transaction_type","MVEX__Country_Code__c":"location.country_code","MVEX__Zip_Postal_Code__c":"accessibility","MVEX__Street__c":"location.street_name","MVEX__House_Office_No__c":"location.property_number_or_name","MVEX__Description__c":"detailed_description.text","MVEX__Property_Category__c":"category","MVEX__Listing_Allowed_For_Portals__c":"feature_list.bills_included.broadband_supply.building_safety_issues.buyer_incentives","MVEX__Country_Code__c":"commercial_use_classes.connected_utilities.construction_materials.electricity_supply","MVEX__Furnished__c":"floor_levels.heating_source.outside_space.parking.sewerage_supply.water_supply.sources_of_flooding"}',
                Portal_Configuration__c = '{"version":"1.2","portalname":"Propertyfinder","getPortalIconUrl":"/resource/propertyfinder","portal_key":"Propertyfinder","name":"Propertyfinder"}'
                );

            insert new List<Portal__c> { portal1 };

            Listing__c listing = new Listing__c();
            listing.Name = 'Dev Test';
            listing.Property__c = property.Id;
            listing.Status__c = 'Active';
            listing.Listing_Type__c = 'Rent';
            listing.Property_Type__c = 'Villa';
            listing.Property_Sub_Type__c = 'Residential - Apartment';
            listing.Property_Category__c = 'Residential';
            listing.Country_Code__c = 'IN';
            listing.Street__c = 'Dev Test';
            listing.City__c = 'Dev Test';
            listing.State__c = 'Dev Test';
            listing.Zip_Postal_Code__c = '123456';
            listing.Description__c = 'Dev Test';
            listing.Listing_Price__c = 1000000;
            listing.Bedrooms__c = 3;
            listing.Bathrooms__c = 2;
            listing.Size__c = 1000;
            listing.Property_OwnerContact__c = contact.Id;
            listing.Listed_Date__c = Date.today();
            listing.Furnished__c = 'Yes';
            listing.Property_Status__c = 'Vacant';
            listing.Year_Built__c = '2020';
            listing.Rent_Frequency__c = 'Monthly';
            listing.Listing_Allowed_For_Portals__c = true;
            insert listing;
            
            PortalListing__c portalListing1 = new PortalListing__c(
                Listing__c = listing.Id,
                Portal__c = portal1.Id,
                SystemIsActive__c = true
            );

            insert new List<PortalListing__c> { portalListing1 };

            Property_File__c propertyFile1 = new Property_File__c(
                Name = 'Test Image 1',
                Property__c = property.Id,
                BaseUrl__c = 'https://example.com/image1',
                Size__c = 123.45,
                IsOnPortalFeed__c = true,
                IsOnWebsite__c = true,
                IsOnExpose__c = true,
                Tags__c = '360tour'
            );

            Property_File__c propertyFile2 = new Property_File__c(
                Name = 'Test Image 2',
                Property__c = property.Id,
                BaseUrl__c = 'https://example.com/image2',
                Size__c = 543.21,
                IsOnPortalFeed__c = true,
                IsOnWebsite__c = false,
                IsOnExpose__c = false,
                Tags__c = 'Interior;Exterior;360tour;Floorplan;Virtual Tour'
            );

            Property_File__c propertyFile3 = new Property_File__c(
                Name = 'Test Image 3',
                Property__c = property.Id,
                BaseUrl__c = 'https://example.com/image2',
                Size__c = 543.21,
                IsOnPortalFeed__c = true,
                IsOnWebsite__c = false,
                IsOnExpose__c = false,
                Tags__c = 'Floorplan'
            );

            Property_File__c propertyFile4 = new Property_File__c(
                Name = 'Test Image 4',
                Property__c = property.Id,
                BaseUrl__c = 'https://example.com/image2',
                Size__c = 543.21,
                IsOnPortalFeed__c = true,
                IsOnWebsite__c = false,
                IsOnExpose__c = false,
                Tags__c = 'Virtual Tour'
            );

            insert new List<Property_File__c> { propertyFile1, propertyFile2, propertyFile3, propertyFile4 };

            Portal_Listing_Mapping__c mapping1 = new Portal_Listing_Mapping__c(
                Name = 'detailed_description.text',
                Portal_Name__c = 'Propertyfinder',
                Listing_Field_API_Name__c = 'MVEX__Description__c',
                Portal_Field_Description__c = 'Description 1',
                Portal_Field_Example__c = 'Example 1',
                Required__c = true
            );
            Portal_Listing_Mapping__c mapping2 = new Portal_Listing_Mapping__c(
                Name = 'location.street_name',
                Portal_Name__c = 'Propertyfinder',
                Listing_Field_API_Name__c = 'MVEX__Street__c',
                Portal_Field_Description__c = 'Description 2',
                Portal_Field_Example__c = 'Example 2',
                Required__c = false,
                Value_Mapping__c = 'Vacant => vacant,Rent => rent,Sale => sale'
            );
            Portal_Listing_Mapping__c mapping3 = new Portal_Listing_Mapping__c(
                Name = 'pricing.transaction_type',
                Portal_Name__c = 'Propertyfinder',
                Listing_Field_API_Name__c = 'MVEX__Listing_Type__c',
                Portal_Field_Description__c = 'Description 2',
                Portal_Field_Example__c = 'Example 2',
                Required__c = false
            );
            Portal_Listing_Mapping__c mapping4 = new Portal_Listing_Mapping__c(
                Name = 'pricing.rent_frequency',
                Portal_Name__c = 'Propertyfinder',
                Listing_Field_API_Name__c = 'MVEX__Rent_Frequency__c',
                Portal_Field_Description__c = 'Description 2',
                Portal_Field_Example__c = 'Example 2',
                Required__c = false
            );
            Portal_Listing_Mapping__c mapping5 = new Portal_Listing_Mapping__c(
                Name = 'category',
                Portal_Name__c = 'Propertyfinder',
                Listing_Field_API_Name__c = 'MVEX__Property_Category__c',
                Portal_Field_Description__c = 'Description 2',
                Portal_Field_Example__c = 'Example 2',
                Required__c = false,
                Value_Mapping__c = 'Residential => residential,Commercial => commercial'
            );
            Portal_Listing_Mapping__c mapping6 = new Portal_Listing_Mapping__c(
                Name = 'accessibility',
                Portal_Name__c = 'Propertyfinder',
                Listing_Field_API_Name__c = 'MVEX__Zip_Postal_Code__c',
                Portal_Field_Description__c = 'Description 2',
                Portal_Field_Example__c = 'Example 2',
                Required__c = false,
                Value_Mapping__c = 'Residential => residential,Commercial => commercial'
            );

            insert new List<Portal_Listing_Mapping__c> { mapping1, mapping2, mapping3, mapping4, mapping5, mapping6 };
        } catch (Exception e) {
            ErrorHandler.insert_errordata(e, 'PortalSyndicationControllerTest', 'testCreatePortalListingRecord', 'Error while creating portal listing record.');
        }
    }
    
    /**
    * Method Name : testCreatePortalListingRecord
    * @description : Used to test createPortalListingRecord method.
    */
    @isTest
    static void testCreatePortalListingRecord() {
        try {            
            Listing__c listing = [SELECT Id FROM Listing__c LIMIT 1];
            List<Portal__c> portal = [SELECT Id FROM Portal__c LIMIT 2];
            
            Test.startTest();
            String result = PortalSyndicationController.createPortalListingRecord(listing.Id, portal[0].Id, 'Publish', 'Propertyfinder');
            String result1 = PortalSyndicationController.createPortalListingRecord(listing.Id, portal[1].Id, 'Publish', 'Bayut');
            Test.stopTest();
            
            System.assertEquals('Success', result, 'Expected success message.');
            System.assertEquals('Success', result1, 'Expected success message.');
            
            List<PortalListing__c> portalListings = [SELECT Id, Listing__c, Portal__c, SystemIsActive__c, Listed_Date__c, UnlistedDate__c FROM PortalListing__c WHERE Listing__c = :listing.Id AND Portal__c = :portal[0].Id];
            System.assertEquals(2, portalListings.size(), 'Expected two PortalListing records.');
            
        } catch (Exception e) {
            ErrorHandler.insert_errordata(e, 'PortalSyndicationControllerTest', 'testCreatePortalListingRecord', 'Error while creating portal listing record.');
        }
    }

    /**
    * Method Name : testFetchPortals
    * @description : Used to test fetchPortals method.
    */
    @isTest
    static void testFetchPortals() {
        try {
            // Retrieve the test data
            Listing__c listing = [SELECT Id FROM Listing__c LIMIT 1];
            
            // Test the fetchPortals method
            Test.startTest();
            List<PortalSyndicationController.PortalWrapper> portalWrappers = PortalSyndicationController.fetchPortals(listing.Id);
            List<PortalSyndicationController.PortalWrapper> portalWrappers1 = PortalSyndicationController.fetchPortals(null);
            Test.stopTest();
            
            // Verify the result
            System.assertEquals(1, portalWrappers.size(), 'Expected one PortalWrapper.');
            
            PortalSyndicationController.PortalWrapper portalWrapper = portalWrappers[0];
            System.assertEquals('Propertyfinder', portalWrapper.name, 'Expected portal name to be Propertyfinder.');
        } catch (Exception e) {
            ErrorHandler.insert_errordata(e, 'PortalSyndicationControllerTest', 'testFetchPortals', 'Error while fetching portals.');
        }
    }
}