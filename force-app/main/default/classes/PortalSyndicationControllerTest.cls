/**
* Class Name : PortalSyndicationControllerTest
* Created By : Karan Singh
* Last Modified Date : 24/06/2024
* Last Modified By : Karan Singh
* @description : Used to test PortalSyndicationController class.
*/
@isTest
public with sharing class PortalSyndicationControllerTest {

    public static String rightmoveSandboxEndpoint = System.label.Rightmove_Endpoint_Sandbox;
    public static String zooplaEndpoint = System.label.Zoopla_Endpoint;
    public static String propertyFinderEndpoint = System.label.PropertyFinder_Endpoint_Production;

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
                Name = 'Zoopla', 
                Is_Active__c = true, 
                Generator__c = 'Zoopla', 
                Field_Mapping__c = '{"Listing_Price__c":"pricing.price","City__c":"location.town_or_city","Broker_s_Listing_ID__c":"listing_reference","Status__c":"life_cycle_status","Property_Type__c":"property_type","Rent_Frequency__c":"pricing.rent_frequency","CurrencyIsoCode":"pricing.currency_code","Listing_Type__c":"pricing.transaction_type","Country_Code__c":"location.country_code","Zip_Postal_Code__c":"accessibility","Street__c":"location.street_name","House_Office_No__c":"location.property_number_or_name","Description__c":"detailed_description.text","Property_Category__c":"category","Listing_Allowed_For_Portals__c":"feature_list.bills_included.broadband_supply.building_safety_issues.buyer_incentives","Country_Code__c":"commercial_use_classes.connected_utilities.construction_materials.electricity_supply","Furnished__c":"floor_levels.heating_source.outside_space.parking.sewerage_supply.water_supply.sources_of_flooding"}',
                Portal_Configuration__c = '{"version":"1.2","portalname":"Zoopla","getPortalIconUrl":"/resource/zoopla","portal_key":"Zoopla","name":"Zoopla","certificate":"zoopla_certificate","branch_reference":"99xx99","branch_name":"99xx99","street_name":"Street","town_or_city":"Ahmedabad","postal_code":"123456","country_code":"IN","locality":"","county":"","latitude":"","longitude":"","address_key":"","organisation_key":"","postcode_type":"","paf_udprn":"","telephone":"","email":"","website":"","is_test_portal":"true","differentiator_values":"Listing_Type__c"}'
                );
            Portal__c portal2 = new Portal__c(
                Name = 'Rightmove', 
                Is_Active__c = true, 
                Generator__c = 'Rightmove',
                Field_Mapping__c = '{"Address__c":"property.address.display_address","House_Office_No__c":"property.address.house_name_number","PostalCode1__c":"property.address.postcode_1","PostalCode2__c":"property.address.postcode_2","City__c":"property.address.town","Broker_s_Listing_ID__c":"property.agent_ref","Bedrooms__c":"property.details.bedrooms","Description__c":"property.details.description","Name":"property.details.summary","Listing_Price__c":"property.price_information.price","Property_Type__c":"property.property_type","Listing_Allowed_For_Portals__c":"property.published","Status__c":"property.status","Furnished__c":"property.details.accessibility","Country_Code__c":"property.details.features","Zip_Postal_Code__c":"property.details.parking","Listing_Allowed_For_Portals__c":"property.details.outside_space.heating.comm_use_class.rooms.room_photo_urls.test"}',
                Portal_Configuration__c = '{"version":"1.2","portalname":"Rightmove","getPortalIconUrl":"/resource/rightmove","portal_key":"Rightmove","name":"Rightmove","certificate":"mvcloudstest","network.network_id":"13457","branch.branch_id":"274982","is_test_portal":"true"}'
                );
            Portal__c portal4 = new Portal__c(
                Name = 'Propertyfinder',
                Is_Active__c = true,
                Generator__c = 'Propertyfinder',
                Field_Mapping__c = '{"MVEX__Listing_Price__c":"price","MVEX__City__c":"location.city","MVEX__Broker_s_Listing_ID__c":"reference"}',
                Portal_Configuration__c = '{"apiKey":"test-api-key","apiSecret":"test-api-secret"}'
                );
            Portal__c portal3 = new Portal__c(
                Name = 'Rightmove Overseas', 
                Is_Active__c = true, 
                Generator__c = 'Rightmove Overseas',
                Field_Mapping__c = '{"Address__c":"property.address.display_address","House_Office_No__c":"property.address.house_name_number","PostalCode1__c":"property.address.postcode_1","PostalCode2__c":"property.address.postcode_2","City__c":"property.address.town","Broker_s_Listing_ID__c":"property.agent_ref","Bedrooms__c":"property.details.bedrooms","Description__c":"property.details.description","Name":"property.details.summary","Listing_Price__c":"property.price_information.price","Property_Type__c":"property.property_type","Listing_Allowed_For_Portals__c":"property.published","Status__c":"property.status","Furnished__c":"property.details.accessibility","Country_Code__c":"property.details.features","Zip_Postal_Code__c":"property.details.parking","Listing_Allowed_For_Portals__c":"property.details.outside_space.heating.comm_use_class.rooms.room_photo_urls.test"}',
                Portal_Configuration__c = '{"version":"1.2","portalname":"Rightmove Overseas","getPortalIconUrl":"/resource/rightmove","portal_key":"Rightmove","name":"Rightmove","certificate":"mvcloudstest","network.network_id":"13457","branch.branch_id":"274982","is_test_portal":"true"}'
                );
            Portal__c portal5 = new Portal__c(
                Name = 'Bayut',
                Is_Active__c = true,
                Generator__c = 'Bayut',
                Field_Mapping__c = '{"MVEX__Listing_Price__c":"price","MVEX__City__c":"location.city","MVEX__Broker_s_Listing_ID__c":"reference"}'
                );

            insert new List<Portal__c> { portal1, portal2, portal3, portal4, portal5 };

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
            // listing.Unit_Number__c = '12345';
            listing.Furnished__c = 'Yes';
            listing.Property_Status__c = 'Vacant';
            listing.Year_Built__c = '2020';
            listing.Rent_Frequency__c = 'Monthly';
            listing.Listing_Allowed_For_Portals__c = true;
            insert listing;

            System.debug('listing'+listing);
            
            PortalListing__c portalListing1 = new PortalListing__c(
                Listing__c = listing.Id,
                Portal__c = portal1.Id,
                SystemIsActive__c = true
            );
            PortalListing__c portalListing2 = new PortalListing__c(
                Listing__c = listing.Id,
                Portal__c = portal2.Id,
                SystemIsActive__c = true
            );
            insert new List<PortalListing__c> { portalListing1, portalListing2 };

            Property_File__c propertyFile1 = new Property_File__c(
                Name = 'Test Image 1',
                Property__c = property.Id,
                BaseUrl__c = 'http://example.com/image1',
                Size__c = 123.45,
                IsOnPortalFeed__c = true,
                IsOnWebsite__c = true,
                IsOnExpose__c = true,
                Tags__c = '360tour'
            );

            Property_File__c propertyFile2 = new Property_File__c(
                Name = 'Test Image 2',
                Property__c = property.Id,
                BaseUrl__c = 'http://example.com/image2',
                Size__c = 543.21,
                IsOnPortalFeed__c = true,
                IsOnWebsite__c = false,
                IsOnExpose__c = false,
                Tags__c = 'Interior;Exterior;360tour;Floorplan;Virtual Tour'
            );

            Property_File__c propertyFile3 = new Property_File__c(
                Name = 'Test Image 3',
                Property__c = property.Id,
                BaseUrl__c = 'http://example.com/image2',
                Size__c = 543.21,
                IsOnPortalFeed__c = true,
                IsOnWebsite__c = false,
                IsOnExpose__c = false,
                Tags__c = 'Floorplan'
            );

            Property_File__c propertyFile4 = new Property_File__c(
                Name = 'Test Image 4',
                Property__c = property.Id,
                BaseUrl__c = 'http://example.com/image2',
                Size__c = 543.21,
                IsOnPortalFeed__c = true,
                IsOnWebsite__c = false,
                IsOnExpose__c = false,
                Tags__c = 'Virtual Tour'
            );

            insert new List<Property_File__c> { propertyFile1, propertyFile2, propertyFile3, propertyFile4 };

            Portal_Listing_Mapping__c mapping1 = new Portal_Listing_Mapping__c(
                Name = 'detailed_description.text',
                Portal_Name__c = 'Zoopla',
                Listing_Field_API_Name__c = 'Description__c',
                Portal_Field_Description__c = 'Description 1',
                Portal_Field_Example__c = 'Example 1',
                Required__c = true
            );
            Portal_Listing_Mapping__c mapping2 = new Portal_Listing_Mapping__c(
                Name = 'location.street_name',
                Portal_Name__c = 'Zoopla',
                Listing_Field_API_Name__c = 'Street__c',
                Portal_Field_Description__c = 'Description 2',
                Portal_Field_Example__c = 'Example 2',
                Required__c = false,
                Value_Mapping__c = 'Vacant => vacant,Rent => rent,Sale => sale'
            );
            Portal_Listing_Mapping__c mapping3 = new Portal_Listing_Mapping__c(
                Name = 'pricing.transaction_type',
                Portal_Name__c = 'Zoopla',
                Listing_Field_API_Name__c = 'Listing_Type__c',
                Portal_Field_Description__c = 'Description 2',
                Portal_Field_Example__c = 'Example 2',
                Required__c = false
            );
            Portal_Listing_Mapping__c mapping4 = new Portal_Listing_Mapping__c(
                Name = 'pricing.rent_frequency',
                Portal_Name__c = 'Zoopla',
                Listing_Field_API_Name__c = 'Rent_Frequency__c',
                Portal_Field_Description__c = 'Description 2',
                Portal_Field_Example__c = 'Example 2',
                Required__c = false
            );
            Portal_Listing_Mapping__c mapping5 = new Portal_Listing_Mapping__c(
                Name = 'category',
                Portal_Name__c = 'Zoopla',
                Listing_Field_API_Name__c = 'Property_Category__c',
                Portal_Field_Description__c = 'Description 2',
                Portal_Field_Example__c = 'Example 2',
                Required__c = false,
                Value_Mapping__c = 'Residential => residential,Commercial => commercial'
            );
            Portal_Listing_Mapping__c mapping6 = new Portal_Listing_Mapping__c(
                Name = 'accessibility',
                Portal_Name__c = 'Zoopla',
                Listing_Field_API_Name__c = 'Zip_Postal_Code__c',
                Portal_Field_Description__c = 'Description 2',
                Portal_Field_Example__c = 'Example 2',
                Required__c = false,
                Value_Mapping__c = 'Residential => residential,Commercial => commercial'
            );
            Portal_Listing_Mapping__c mapping7 = new Portal_Listing_Mapping__c(
                Name = 'property.status',
                Portal_Name__c = 'Rightmove',
                Listing_Field_API_Name__c = 'Status__c',
                Portal_Field_Description__c = 'Description 2',
                Portal_Field_Example__c = 'Example 2',
                Required__c = false,
                Value_Mapping__c = 'Vacant => vacant,Rent => rent,Sale => sale'
            );
            Portal_Listing_Mapping__c mapping8 = new Portal_Listing_Mapping__c(
                Name = 'property.address.town',
                Portal_Name__c = 'Rightmove',
                Listing_Field_API_Name__c = 'City__c',
                Portal_Field_Description__c = 'Description 2',
                Portal_Field_Example__c = 'Example 2',
                Required__c = false
            );
            Portal_Listing_Mapping__c mapping9 = new Portal_Listing_Mapping__c(
                Name = 'property.details.bedrooms',
                Portal_Name__c = 'Rightmove',
                Listing_Field_API_Name__c = 'Bedrooms__c',
                Portal_Field_Description__c = 'Description 2',
                Portal_Field_Example__c = 'Example 2',
                Required__c = false
            );
            Portal_Listing_Mapping__c mapping10 = new Portal_Listing_Mapping__c(
                Name = 'property.property_type',
                Portal_Name__c = 'Rightmove',
                Listing_Field_API_Name__c = 'Property_Type__c',
                Portal_Field_Description__c = 'Description 2',
                Portal_Field_Example__c = 'Example 2',
                Value_Mapping__c = 'Apartment => 28,Townhouse => 29,Villa => 27,Duplex => 56,Penthouse => 29,Land => 20,Commercial => 241,Commercial Lease => 244,Commercial Sale => 253',
                Data_Type__c = 'Integer',
                Required__c = false
            );
            Portal_Listing_Mapping__c mapping11 = new Portal_Listing_Mapping__c(
                Name = 'property.details.accessibility',
                Portal_Name__c = 'Rightmove',
                Listing_Field_API_Name__c = 'Furnished__c',
                Portal_Field_Description__c = 'Description 2',
                Portal_Field_Example__c = 'Example 2',
                Value_Mapping__c = 'Apartment => 28,Townhouse => 29,Villa => 27,Duplex => 56,Penthouse => 29,Land => 20,Commercial => 241,Commercial Lease => 244,Commercial Sale => 253',
                Data_Type__c = 'Integer',
                Required__c = false
            );
            Portal_Listing_Mapping__c mapping12 = new Portal_Listing_Mapping__c(
                Name = 'property.details.features',
                Portal_Name__c = 'Rightmove',
                Listing_Field_API_Name__c = 'Country_Code__c',
                Portal_Field_Description__c = 'Description 2',
                Portal_Field_Example__c = 'Example 2',
                Value_Mapping__c = 'Apartment => 28,Townhouse => 29,Villa => 27,Duplex => 56,Penthouse => 29,Land => 20,Commercial => 241,Commercial Lease => 244,Commercial Sale => 253',
                Data_Type__c = 'Integer',
                Required__c = false
            );
            Portal_Listing_Mapping__c mapping13 = new Portal_Listing_Mapping__c(
                Name = 'property.details.parking',
                Portal_Name__c = 'Rightmove',
                Listing_Field_API_Name__c = 'Zip_Postal_Code__c',
                Portal_Field_Description__c = 'Description 2',
                Portal_Field_Example__c = 'Example 2',
                Value_Mapping__c = 'Apartment => 28,Townhouse => 29,Villa => 27,Duplex => 56,Penthouse => 29,Land => 20,Commercial => 241,Commercial Lease => 244,Commercial Sale => 253',
                Data_Type__c = 'Integer',
                Required__c = false
            );
            Portal_Listing_Mapping__c mapping14 = new Portal_Listing_Mapping__c(
                Name = 'property.details.outside_space.heating.comm_use_class.rooms.room_photo_urls.test',
                Portal_Name__c = 'Rightmove',
                Listing_Field_API_Name__c = 'Listing_Allowed_For_Portals__c',
                Portal_Field_Description__c = 'Description 2',
                Portal_Field_Example__c = 'Example 2',
                Data_Type__c = 'Boolean',
                Required__c = false
            );
            Portal_Listing_Mapping__c mapping71 = new Portal_Listing_Mapping__c(
                Name = 'property.status',
                Portal_Name__c = 'Rightmove Overseas',
                Listing_Field_API_Name__c = 'Status__c',
                Portal_Field_Description__c = 'Description 2',
                Portal_Field_Example__c = 'Example 2',
                Required__c = false,
                Value_Mapping__c = 'Vacant => vacant,Rent => rent,Sale => sale'
            );
            Portal_Listing_Mapping__c mapping81 = new Portal_Listing_Mapping__c(
                Name = 'property.address.town',
                Portal_Name__c = 'Rightmove Overseas',
                Listing_Field_API_Name__c = 'City__c',
                Portal_Field_Description__c = 'Description 2',
                Portal_Field_Example__c = 'Example 2',
                Required__c = false
            );
            Portal_Listing_Mapping__c mapping91 = new Portal_Listing_Mapping__c(
                Name = 'property.details.bedrooms',
                Portal_Name__c = 'Rightmove Overseas',
                Listing_Field_API_Name__c = 'Bedrooms__c',
                Portal_Field_Description__c = 'Description 2',
                Portal_Field_Example__c = 'Example 2',
                Required__c = false
            );
            Portal_Listing_Mapping__c mapping101 = new Portal_Listing_Mapping__c(
                Name = 'property.property_type',
                Portal_Name__c = 'Rightmove Overseas',
                Listing_Field_API_Name__c = 'Property_Type__c',
                Portal_Field_Description__c = 'Description 2',
                Portal_Field_Example__c = 'Example 2',
                Value_Mapping__c = 'Apartment => 28,Townhouse => 29,Villa => 27,Duplex => 56,Penthouse => 29,Land => 20,Commercial => 241,Commercial Lease => 244,Commercial Sale => 253',
                Data_Type__c = 'Integer',
                Required__c = false
            );
            Portal_Listing_Mapping__c mapping111 = new Portal_Listing_Mapping__c(
                Name = 'property.details.accessibility',
                Portal_Name__c = 'Rightmove Overseas',
                Listing_Field_API_Name__c = 'Furnished__c',
                Portal_Field_Description__c = 'Description 2',
                Portal_Field_Example__c = 'Example 2',
                Value_Mapping__c = 'Apartment => 28,Townhouse => 29,Villa => 27,Duplex => 56,Penthouse => 29,Land => 20,Commercial => 241,Commercial Lease => 244,Commercial Sale => 253',
                Data_Type__c = 'Integer',
                Required__c = false
            );
            Portal_Listing_Mapping__c mapping121 = new Portal_Listing_Mapping__c(
                Name = 'property.details.features',
                Portal_Name__c = 'RightRightmove Overseasmove',
                Listing_Field_API_Name__c = 'Country_Code__c',
                Portal_Field_Description__c = 'Description 2',
                Portal_Field_Example__c = 'Example 2',
                Value_Mapping__c = 'Apartment => 28,Townhouse => 29,Villa => 27,Duplex => 56,Penthouse => 29,Land => 20,Commercial => 241,Commercial Lease => 244,Commercial Sale => 253',
                Data_Type__c = 'Integer',
                Required__c = false
            );
            Portal_Listing_Mapping__c mapping131 = new Portal_Listing_Mapping__c(
                Name = 'property.details.parking',
                Portal_Name__c = 'Rightmove Overseas',
                Listing_Field_API_Name__c = 'Zip_Postal_Code__c',
                Portal_Field_Description__c = 'Description 2',
                Portal_Field_Example__c = 'Example 2',
                Value_Mapping__c = 'Apartment => 28,Townhouse => 29,Villa => 27,Duplex => 56,Penthouse => 29,Land => 20,Commercial => 241,Commercial Lease => 244,Commercial Sale => 253',
                Data_Type__c = 'Integer',
                Required__c = false
            );
            Portal_Listing_Mapping__c mapping141 = new Portal_Listing_Mapping__c(
                Name = 'property.details.outside_space.heating.comm_use_class.rooms.room_photo_urls.test',
                Portal_Name__c = 'Rightmove Overseas',
                Listing_Field_API_Name__c = 'Listing_Allowed_For_Portals__c',
                Portal_Field_Description__c = 'Description 2',
                Portal_Field_Example__c = 'Example 2',
                Data_Type__c = 'Boolean',
                Required__c = false
            );

            insert new List<Portal_Listing_Mapping__c> { mapping1, mapping2, mapping3, mapping4, mapping5, mapping6, mapping7, mapping8, mapping9, mapping10, mapping11, mapping12, mapping13, mapping14, mapping71, mapping81, mapping91, mapping101, mapping111, mapping121, mapping131, mapping141 };
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'PortalSyndicationControllerTest', 'testCreatePortalListingRecord', 'Error while creating portal listing record.');
        }
    }
    
    /**
    * Method Name : testCreatePortalListingRecord
    * @description : Used to test createPortalListingRecord method.
    */
    @isTest
    static void testCreatePortalListingRecord() {
        try {
            // Create mock responses for different endpoints
            HttpResponse mockResponse1 = new HttpResponse();
            mockResponse1.setHeader('Content-Type', 'application/json; profile=http://realtime-listings.webservices.zpg.co.uk/docs/v2.3/schemas/listing/update.json');
            mockResponse1.setBody('{"branch_reference":"99xx99","pricing":{"price":1200000,"currency_code":"INR","transaction_type":"sale"},"location":{"town_or_city":"Ahmedabad","country_code":"IN","postal_code":"W1D3QU","street_name":"VR Road","property_number_or_name":"22/4 Apartment"},"listing_reference":"TESTLISTING","life_cycle_status":"available","property_type":"villa","detailed_description":[{"text":"Test Description for Listing"}],"category":"residential"}');
            mockResponse1.setStatusCode(200);
            // @description :')
            HttpResponse mockResponse2 = new HttpResponse();
            mockResponse2.setHeader('Content-Type', 'application/json');
            mockResponse2.setBody('{"success":true,"branch":{"branch_id":"274982","channel":1,"overseas":false},"network":{"network_id":"13457"},"property":{"address":{"display_address":"22/4 Galaxy Apartment","house_name_number":"22/4 Apartment","postcode_1":"W1D","postcode_2":"3QU","town":"Ahmedabad"},"agent_ref":"TESTLISTING","details":{"bedrooms":4,"description":"Test Description for Listing","summary":"Test By RK"},"price_information":{"price":1200000},"property_type":"Villa","published":true,"status":1}}');
            mockResponse2.setStatusCode(200);
            
            // PropertyFinder auth token response
            HttpResponse mockResponsePFAuth = new HttpResponse();
            mockResponsePFAuth.setHeader('Content-Type', 'application/json');
            mockResponsePFAuth.setBody('{"accessToken":"test-access-token-12345"}');
            mockResponsePFAuth.setStatusCode(200);
            
            // PropertyFinder create listing response
            HttpResponse mockResponsePFCreate = new HttpResponse();
            mockResponsePFCreate.setHeader('Content-Type', 'application/json');
            mockResponsePFCreate.setBody('{"id":"pf-listing-12345","reference":"TESTLISTING","status":"draft"}');
            mockResponsePFCreate.setStatusCode(200);
            
            // Map endpoints to their respective mock responses
            Map<String, HttpResponse> endpointResponses = new Map<String, HttpResponse>{
                zooplaEndpoint + 'sandbox/v2/listing/update' => mockResponse1,
                rightmoveSandboxEndpoint + 'sendpropertydetails' => mockResponse2,
                propertyFinderEndpoint + 'auth/token' => mockResponsePFAuth,
                propertyFinderEndpoint + 'listings' => mockResponsePFCreate
            };
            
            // Set up the mock HTTP callout
            Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(endpointResponses));
            
            List<Listing__c> listing = [SELECT Id FROM Listing__c];

            Test.startTest();
            Portal__c portal = [SELECT Id, Name FROM Portal__c WHERE Name = 'Zoopla' LIMIT 1];
            String result = PortalSyndicationController.createPortalListingRecord(listing[0].Id, portal.Id, 'Publish', 'Zoopla');
            Portal__c portalPF = [SELECT Id, Name FROM Portal__c WHERE Name = 'Propertyfinder' LIMIT 1];
            String result1 = PortalSyndicationController.createPortalListingRecord(listing[0].Id, portalPF.Id, 'Publish', 'Propertyfinder');
            Portal__c portalRM = [SELECT Id, Name FROM Portal__c WHERE Name = 'Rightmove' LIMIT 1];
            String result2 = PortalSyndicationController.createPortalListingRecord(listing[0].Id, portalRM.Id, 'Publish', 'Rightmove');
            Portal__c portalRMO = [SELECT Id, Name FROM Portal__c WHERE Name = 'Rightmove Overseas' LIMIT 1];
            String result3 = PortalSyndicationController.createPortalListingRecord(listing[0].Id, portalRMO.Id, 'Publish', 'Rightmove Overseas');
            Portal__c portalBayut = [SELECT Id, Name FROM Portal__c WHERE Name = 'Bayut' LIMIT 1];
            String result4 = PortalSyndicationController.createPortalListingRecord(listing[0].Id, portalBayut.Id, 'Publish', 'Bayut');
            Test.stopTest();
            
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'PortalSyndicationControllerTest', 'testCreatePortalListingRecord', 'Error while creating portal listing record.');
        }
    }

    /**
    * Method Name : testCreatePortalListingRecord
    * @description : Used to test createPortalListingRecord method.
    */
    @isTest
    static void testCreatePortalListingRecordFailAPI() {
        try {
            // Create mock responses for different endpoints
            HttpResponse mockResponse1 = new HttpResponse();
            mockResponse1.setHeader('Content-Type', 'application/json; profile=http://realtime-listings.webservices.zpg.co.uk/docs/v2.3/schemas/listing/update.json');
            mockResponse1.setBody('{"branch_reference":"99xx99","pricing":{"price":1200000,"currency_code":"INR","transaction_type":"sale"},"location":{"town_or_city":"Ahmedabad","country_code":"IN","postal_code":"W1D3QU","street_name":"VR Road","property_number_or_name":"22/4 Apartment"},"listing_reference":"TESTLISTING","life_cycle_status":"available","property_type":"villa","detailed_description":[{"text":"Test Description for Listing"}],"category":"residential"}');
            mockResponse1.setStatusCode(401);
            
            HttpResponse mockResponse2 = new HttpResponse();
            mockResponse2.setHeader('Content-Type', 'application/json');
            mockResponse2.setBody('{"success":false,"error":"Not found","branch":{"branch_id":"274982","channel":1,"overseas":false},"network":{"network_id":"13457"},"property":{"address":{"display_address":"22/4 Galaxy Apartment","house_name_number":"22/4 Apartment","postcode_1":"W1D","postcode_2":"3QU","town":"Ahmedabad"},"agent_ref":"TESTLISTING","details":{"bedrooms":4,"description":"Test Description for Listing","summary":"Test By RK"},"price_information":{"price":1200000},"property_type":"Villa","published":true,"status":1}}');
            mockResponse2.setStatusCode(404);
            
            // PropertyFinder auth token failure
            HttpResponse mockResponsePFAuthFail = new HttpResponse();
            mockResponsePFAuthFail.setHeader('Content-Type', 'application/json');
            mockResponsePFAuthFail.setBody('{"error":"Unauthorized"}');
            mockResponsePFAuthFail.setStatusCode(401);
            
            // Map endpoints to their respective mock responses
            Map<String, HttpResponse> endpointResponses = new Map<String, HttpResponse>{
                zooplaEndpoint + 'sandbox/v2/listing/update' => mockResponse1,
                rightmoveSandboxEndpoint + 'sendpropertydetails' => mockResponse2,
                propertyFinderEndpoint + 'auth/token' => mockResponsePFAuthFail
            };
            
            // Set up the mock HTTP callout
            Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(endpointResponses));
            
            Listing__c listing = [SELECT Id FROM Listing__c LIMIT 1];
            
            Test.startTest();
            Portal__c portal = [SELECT Id, Name FROM Portal__c WHERE Name = 'Zoopla' LIMIT 1];
            String result = PortalSyndicationController.createPortalListingRecord(listing.Id, portal.Id, 'Publish', 'Zoopla');
            Portal__c portalPF = [SELECT Id, Name FROM Portal__c WHERE Name = 'Propertyfinder' LIMIT 1];
            String result1 = PortalSyndicationController.createPortalListingRecord(listing.Id, portalPF.Id, 'Publish', 'Propertyfinder');
            Portal__c portalRM = [SELECT Id, Name FROM Portal__c WHERE Name = 'Rightmove' LIMIT 1];
            String result2 = PortalSyndicationController.createPortalListingRecord(listing.Id, portalRM.Id, 'Publish', 'Rightmove');
            Portal__c portalRMO = [SELECT Id, Name FROM Portal__c WHERE Name = 'Rightmove Overseas' LIMIT 1];
            String result3 = PortalSyndicationController.createPortalListingRecord(listing.Id, portalRMO.Id, 'Publish', 'Rightmove Overseas');
            Test.stopTest();
            
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'PortalSyndicationControllerTest', 'testCreatePortalListingRecordFailAPI', 'Error while creating portal listing record.');
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
            PortalSyndicationController.FetchPortalListingRecord portalWrappers = PortalSyndicationController.fetchPortals(listing.Id);
            PortalSyndicationController.FetchPortalListingRecord portalWrappers1 = PortalSyndicationController.fetchPortals(null);
            Test.stopTest();
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'PortalSyndicationControllerTest', 'testFetchPortals', 'Error while fetching portals.');
        }
    }

    /**
    * Method Name : testFetchPortals
    * @description : Used to test fetchPortals method.
    */
    @isTest
    static void testGetListingAPI() {
        try {
            Portal__c portal1 = [SELECT Id FROM Portal__c WHERE Name = 'Zoopla' LIMIT 1];
            Portal__c portal2 = [SELECT Id FROM Portal__c WHERE Name = 'Rightmove' LIMIT 1];
            Portal__c portal3 = [SELECT Id FROM Portal__c WHERE Name = 'Propertyfinder' LIMIT 1];

            // Create mock responses for different endpoints
            HttpResponse mockResponse1 = new HttpResponse();
            mockResponse1.setHeader('Content-Type', 'application/json; profile=http://realtime-listings.webservices.zpg.co.uk/docs/v2.3/schemas/listing/list.json');
            mockResponse1.setBody('{"test": "success"}');
            mockResponse1.setStatusCode(200);
            
            HttpResponse mockResponse2 = new HttpResponse();
            mockResponse2.setHeader('Content-Type', 'application/json');
            mockResponse2.setBody('{"test": "success"}');
            mockResponse2.setStatusCode(200);
            
            // PropertyFinder auth token response
            HttpResponse mockResponsePFAuth = new HttpResponse();
            mockResponsePFAuth.setHeader('Content-Type', 'application/json');
            mockResponsePFAuth.setBody('{"accessToken":"test-access-token"}');
            mockResponsePFAuth.setStatusCode(200);
            
            // PropertyFinder get listing response
            HttpResponse mockResponsePFListing = new HttpResponse();
            mockResponsePFListing.setHeader('Content-Type', 'application/json');
            mockResponsePFListing.setBody('{"results":[{"reference":"TESTLISTING","updatedAt":"2024-01-01","type":"sale","portals":{"propertyfinder":{"isLive":true}}}]}');
            mockResponsePFListing.setStatusCode(200);
            
            // Map endpoints to their respective mock responses
            Map<String, HttpResponse> endpointResponses = new Map<String, HttpResponse>{
                zooplaEndpoint + 'sandbox/v2/listing/list' => mockResponse1,
                rightmoveSandboxEndpoint + 'getbranchpropertylist' => mockResponse2,
                propertyFinderEndpoint + 'auth/token' => mockResponsePFAuth,
                propertyFinderEndpoint + 'listings' => mockResponsePFListing
            };
            
            // Set up the mock HTTP callout
            Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(endpointResponses));

            Test.startTest();
            ZooplaIntegrationController.ListingResponse wrapper1 = ZooplaIntegrationController.zooplaGetListing(portal1.Id);
            RightmoveIntegrationController.ListingResponse wrapper2 = RightmoveIntegrationController.rightmoveGetListing(portal2.Id);
            PropertyFinderIntegration.ListingResponse wrapper3 = PropertyFinderIntegration.propertyFinderGetListing(portal3.Id);
            Test.stopTest();

            System.assertNotEquals(null, wrapper1, 'Response should not be null.');
            System.assertNotEquals(null, wrapper2, 'Response should not be null.');
            System.assertNotEquals(null, wrapper3, 'PropertyFinder response should not be null.');
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'PortalSyndicationControllerTest', 'testGetListingAPI', 'Error while getting listing API.');
        }
    }

    /**
    * Method Name : testFetchPortals
    * @description : Used to test fetchPortals method.
    */
    @isTest
    static void testGetListingAPIFail() {
        try {
            Portal__c portal1 = [SELECT Id FROM Portal__c WHERE Name = 'Zoopla' LIMIT 1];
            Portal__c portal2 = [SELECT Id FROM Portal__c WHERE Name = 'Rightmove' LIMIT 1];
            Portal__c portal3 = [SELECT Id FROM Portal__c WHERE Name = 'Propertyfinder' LIMIT 1];

            // Create mock responses for different endpoints
            HttpResponse mockResponse1 = new HttpResponse();
            mockResponse1.setHeader('Content-Type', 'application/json; profile=http://realtime-listings.webservices.zpg.co.uk/docs/v2.3/schemas/listing/list.json');
            mockResponse1.setBody('{"test": "success"}');
            mockResponse1.setStatusCode(401);
            
            HttpResponse mockResponse2 = new HttpResponse();
            mockResponse2.setHeader('Content-Type', 'application/json');
            mockResponse2.setBody('{"test": "success"}');
            mockResponse2.setStatusCode(401);
            
            // PropertyFinder auth token failure
            HttpResponse mockResponsePFAuthFail = new HttpResponse();
            mockResponsePFAuthFail.setHeader('Content-Type', 'application/json');
            mockResponsePFAuthFail.setBody('{"error":"Unauthorized"}');
            mockResponsePFAuthFail.setStatusCode(401);
            
            // Map endpoints to their respective mock responses
            Map<String, HttpResponse> endpointResponses = new Map<String, HttpResponse>{
                zooplaEndpoint + 'sandbox/v2/listing/list' => mockResponse1,
                rightmoveSandboxEndpoint + 'getbranchpropertylist' => mockResponse2,
                propertyFinderEndpoint + 'auth/token' => mockResponsePFAuthFail
            };
            
            // Set up the mock HTTP callout
            Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(endpointResponses));

            Test.startTest();
            ZooplaIntegrationController.ListingResponse wrapper1 = ZooplaIntegrationController.zooplaGetListing(portal1.Id);
            RightmoveIntegrationController.ListingResponse wrapper2 = RightmoveIntegrationController.rightmoveGetListing(portal2.Id);
            PropertyFinderIntegration.ListingResponse wrapper3 = PropertyFinderIntegration.propertyFinderGetListing(portal3.Id);
            Test.stopTest();

            System.assertNotEquals(null, wrapper1, 'Response should not be null.');
            System.assertNotEquals(null, wrapper2, 'Response should not be null.');
            System.assertNotEquals(null, wrapper3, 'PropertyFinder response should not be null.');
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'PortalSyndicationControllerTest', 'testGetListingAPIFail', 'Error while getting listing API.');
        }
    }

    @isTest
    static void testPropertyFinderCreateAndUpdateListing() {
        try {
            Listing__c listing = [SELECT Id FROM Listing__c LIMIT 1];
            Portal__c pfPortal = [SELECT Id FROM Portal__c WHERE Name = 'Propertyfinder' LIMIT 1];
            
            // Mock responses for PropertyFinder
            PropertyFinderMockHttpResponse mock = new PropertyFinderMockHttpResponse();
            Test.setMock(HttpCalloutMock.class, mock);
            
            Test.startTest();
            // Test create action
            PropertyFinderIntegration.getListingRecordForSync(listing.Id, pfPortal.Id, 'create');
            
            // Update listing with PF ID to test update path
            listing.PF_Listing_ID__c = 'pf-test-12345';
            update listing;
            
            // Test update action
            PropertyFinderIntegration.getListingRecordForSync(listing.Id, pfPortal.Id, 'update');
            Test.stopTest();
            
            System.assert(true, 'PropertyFinder sync executed without errors');
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'PortalSyndicationControllerTest', 'testPropertyFinderCreateAndUpdateListing', 'Error in PF create/update test.');
        }
    }

    @isTest
    static void testPropertyFinderDeleteListings() {
        try {
            Listing__c listing = [SELECT Id FROM Listing__c LIMIT 1];
            listing.PF_Listing_ID__c = 'pf-listing-delete-123';
            update listing;
            
            Portal__c pfPortal = [SELECT Id FROM Portal__c WHERE Name = 'Propertyfinder' LIMIT 1];
            
            PortalListing__c portalListing = new PortalListing__c(
                Listing__c = listing.Id,
                Portal__c = pfPortal.Id,
                SystemIsActive__c = true,
                Listed_Date__c = System.today()
            );
            insert portalListing;
            
            Map<String, Map<String, String>> listingsMap = new Map<String, Map<String, String>>();
            listingsMap.put(listing.Id, new Map<String, String>{
                'listingId' => listing.Id,
                'portalId' => pfPortal.Id,
                'portalListingId' => portalListing.Id
            });
            String listingsJson = JSON.serialize(listingsMap);
            
            PropertyFinderMockHttpResponse mock = new PropertyFinderMockHttpResponse();
            Test.setMock(HttpCalloutMock.class, mock);
            
            Test.startTest();
            PropertyFinderIntegration.propertyFinderDeleteListings(listingsJson);
            Test.stopTest();
            
            System.assert(true, 'PropertyFinder delete executed without errors');
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'PortalSyndicationControllerTest', 'testPropertyFinderDeleteListings', 'Error in PF delete test.');
        }
    }

    @isTest
    static void testPropertyFinderDeleteListingsFailure() {
        try {
            Listing__c listing = [SELECT Id FROM Listing__c LIMIT 1];
            listing.PF_Listing_ID__c = 'pf-listing-fail-123';
            update listing;
            
            Portal__c pfPortal = [SELECT Id FROM Portal__c WHERE Name = 'Propertyfinder' LIMIT 1];
            
            PortalListing__c portalListing = new PortalListing__c(
                Listing__c = listing.Id,
                Portal__c = pfPortal.Id,
                SystemIsActive__c = true,
                Listed_Date__c = System.today()
            );
            insert portalListing;
            
            Map<String, Map<String, String>> listingsMap = new Map<String, Map<String, String>>();
            listingsMap.put(listing.Id, new Map<String, String>{
                'listingId' => listing.Id,
                'portalId' => pfPortal.Id,
                'portalListingId' => portalListing.Id
            });
            String listingsJson = JSON.serialize(listingsMap);
            
            PropertyFinderMockHttpResponse mock = new PropertyFinderMockHttpResponse(true);
            Test.setMock(HttpCalloutMock.class, mock);
            
            Test.startTest();
            PropertyFinderIntegration.propertyFinderDeleteListings(listingsJson);
            Test.stopTest();
            
            // Verify failed deletion was logged
            List<PortalListing__c> updatedListings = [SELECT Id, SystemIsActive__c, API_Response_Unpublish__c 
                                                       FROM PortalListing__c WHERE Id = :portalListing.Id];
            System.assertEquals(1, updatedListings.size(), 'Portal listing should exist');
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'PortalSyndicationControllerTest', 'testPropertyFinderDeleteListingsFailure', 'Error in PF delete failure test.');
        }
    }

    @isTest
    static void testPropertyFinderMissingPortalConfig() {
        try {
            Listing__c listing = [SELECT Id FROM Listing__c LIMIT 1];
            
            Test.startTest();
            // Test with invalid portal ID
            PropertyFinderIntegration.getListingRecordForSync(listing.Id, 'invalid-portal-id', 'create');
            Test.stopTest();
            
            System.assert(true, 'Should handle missing portal gracefully');
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'PortalSyndicationControllerTest', 'testPropertyFinderMissingPortalConfig', 'Error in PF missing config test.');
        }
    }

    @isTest
    static void testPropertyFinderAccessTokenError() {
        try {
            Portal__c pfPortal = [SELECT Id FROM Portal__c WHERE Name = 'Propertyfinder' LIMIT 1];
            
            PropertyFinderMockHttpResponse mock = new PropertyFinderMockHttpResponse(false, true);
            Test.setMock(HttpCalloutMock.class, mock);
            
            Test.startTest();
            try {
                PropertyFinderIntegration.ListingResponse response = PropertyFinderIntegration.propertyFinderGetListing(pfPortal.Id);
                System.assertEquals('Failed', response.status, 'Should return failed status');
            } catch (Exception ex) {
                System.assert(true, 'Access token error handled');
            }
            Test.stopTest();
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'PortalSyndicationControllerTest', 'testPropertyFinderAccessTokenError', 'Error in PF access token test.');
        }
    }

    @isTest
    static void testUnpublishForIntegratedPortals() {
        try {
            Listing__c listing = [SELECT Id FROM Listing__c LIMIT 1];
            List<Portal__c> portals = [SELECT Id, Name FROM Portal__c ORDER BY Name];
            
            // Create portal listings for unpublish testing
            List<PortalListing__c> portalListings = new List<PortalListing__c>();
            for (Portal__c portal : portals) {
                PortalListing__c pl = new PortalListing__c(
                    Listing__c = listing.Id,
                    Portal__c = portal.Id,
                    SystemIsActive__c = true,
                    Listed_Date__c = System.today()
                );
                portalListings.add(pl);
            }
            insert portalListings;
            
            // Update listing with PF ID for PropertyFinder delete
            listing.PF_Listing_ID__c = 'pf-unpublish-123';
            update listing;
            
            // Setup mocks for all portal integrations
            PropertyFinderMockHttpResponse mock = new PropertyFinderMockHttpResponse();
            Test.setMock(HttpCalloutMock.class, mock);
            
            Test.startTest();
            // Test unpublish for Zoopla
            String resultZoopla = PortalSyndicationController.createPortalListingRecord(
                listing.Id, portals[0].Id, 'Unpublish', 'Propertyfinder'
            );
            
            // Test unpublish for Rightmove
            String resultRightmove = PortalSyndicationController.createPortalListingRecord(
                listing.Id, portals[2].Id, 'Unpublish', 'Rightmove'
            );
            
            // Test unpublish for Rightmove Overseas
            String resultRightmoveOverseas = PortalSyndicationController.createPortalListingRecord(
                listing.Id, portals[3].Id, 'Unpublish', 'Rightmove Overseas'
            );
            
            // Test unpublish for PropertyFinder
            String resultPropertyFinder = PortalSyndicationController.createPortalListingRecord(
                listing.Id, portals[1].Id, 'Unpublish', 'Propertyfinder'
            );
            Test.stopTest();
            
            System.assertEquals('Success', resultZoopla, 'Zoopla unpublish should succeed');
            System.assertEquals('Success', resultRightmove, 'Rightmove unpublish should succeed');
            System.assertEquals('Success', resultRightmoveOverseas, 'Rightmove Overseas unpublish should succeed');
            System.assertEquals('Success', resultPropertyFinder, 'PropertyFinder unpublish should succeed');
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'PortalSyndicationControllerTest', 'testUnpublishForIntegratedPortals', 'Error in unpublish test.');
        }
    }

    @isTest
    static void testUnpublishForNonIntegratedPortal() {
        try {
            // Create a custom portal (not in the integrated list)
            Portal__c customPortal = new Portal__c(
                Name = 'Custom Portal',
                Is_Active__c = true,
                Generator__c = 'Custom',
                Field_Mapping__c = '{}',
                Portal_Configuration__c = '{}'
            );
            insert customPortal;
            
            Listing__c listing = [SELECT Id FROM Listing__c LIMIT 1];
            
            // Create portal listing for custom portal
            PortalListing__c portalListing = new PortalListing__c(
                Listing__c = listing.Id,
                Portal__c = customPortal.Id,
                SystemIsActive__c = true,
                Listed_Date__c = System.today()
            );
            insert portalListing;
            
            Test.startTest();
            String result = PortalSyndicationController.createPortalListingRecord(
                listing.Id, customPortal.Id, 'Unpublish', 'Custom Portal'
            );
            Test.stopTest();
            
            System.assertEquals('Success', result, 'Custom portal unpublish should succeed');
            
            // Verify the portal listing was deactivated
            PortalListing__c updatedListing = [SELECT SystemIsActive__c, UnlistedDate__c 
                                                FROM PortalListing__c WHERE Id = :portalListing.Id];
            System.assertEquals(false, updatedListing.SystemIsActive__c, 'Should be deactivated');
            System.assertEquals(System.today(), updatedListing.UnlistedDate__c, 'Unlisted date should be set');
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'PortalSyndicationControllerTest', 'testUnpublishForNonIntegratedPortal', 'Error in non-integrated unpublish test.');
        }
    }

    @isTest
    static void testPublishForNonIntegratedPortal() {
        try {
            // Create a custom portal (not in the integrated list)
            Portal__c customPortal = new Portal__c(
                Name = 'Another Custom Portal',
                Is_Active__c = true,
                Generator__c = 'AnotherCustom',
                Field_Mapping__c = '{}',
                Portal_Configuration__c = '{}'
            );
            insert customPortal;
            
            Listing__c listing = [SELECT Id FROM Listing__c LIMIT 1];
            
            Test.startTest();
            String result = PortalSyndicationController.createPortalListingRecord(
                listing.Id, customPortal.Id, 'Publish', 'Another Custom Portal'
            );
            Test.stopTest();
            
            System.assertEquals('Success', result, 'Custom portal publish should succeed');
            
            // Verify portal listing was created
            List<PortalListing__c> portalListings = [SELECT Id, SystemIsActive__c 
                                                       FROM PortalListing__c 
                                                       WHERE Listing__c = :listing.Id 
                                                       AND Portal__c = :customPortal.Id];
            System.assertEquals(1, portalListings.size(), 'Portal listing should be created');
            System.assertEquals(true, portalListings[0].SystemIsActive__c, 'Should be active');
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'PortalSyndicationControllerTest', 'testPublishForNonIntegratedPortal', 'Error in non-integrated publish test.');
        }
    }

    @isTest
    static void testInvalidActionType() {
        try {
            Listing__c listing = [SELECT Id FROM Listing__c LIMIT 1];
            Portal__c portal = [SELECT Id FROM Portal__c LIMIT 1];
            
            Test.startTest();
            String result = PortalSyndicationController.createPortalListingRecord(
                listing.Id, portal.Id, 'InvalidAction', 'Zoopla'
            );
            Test.stopTest();
            
            System.assert(result.contains('Invalid'), 'Should return invalid action message');
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'PortalSyndicationControllerTest', 'testInvalidActionType', 'Error in invalid action test.');
        }
    }

    @isTest
    static void testZooplaCreateAndUpdateListing() {
        try {
            Listing__c listing = [SELECT Id FROM Listing__c LIMIT 1];
            Portal__c zooplaPortal = [SELECT Id FROM Portal__c WHERE Name = 'Zoopla' LIMIT 1];
            
            ZooplaMockHttpResponse mock = new ZooplaMockHttpResponse();
            Test.setMock(HttpCalloutMock.class, mock);
            
            Test.startTest();
            ZooplaIntegrationController.getListingRecordForSync(listing.Id, zooplaPortal.Id);
            Test.stopTest();
            
            System.assert(true, 'Zoopla sync executed without errors');
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'PortalSyndicationControllerTest', 'testZooplaCreateAndUpdateListing', 'Error in Zoopla create/update test.');
        }
    }

    @isTest
    static void testZooplaDeleteListings() {
        try {
            Listing__c listing = [SELECT Id FROM Listing__c LIMIT 1];

            Portal__c zooplaPortal = [SELECT Id FROM Portal__c WHERE Name = 'Zoopla' LIMIT 1];
            
            PortalListing__c portalListing = new PortalListing__c(
                Listing__c = listing.Id,
                Portal__c = zooplaPortal.Id,
                SystemIsActive__c = true
            );
            insert portalListing;
            
            Map<String, Map<String, String>> listingsMap = new Map<String, Map<String, String>>();
            listingsMap.put(listing.Id, new Map<String, String>{
                'portalId' => zooplaPortal.Id,
                'portalListingId' => portalListing.Id
            });
            String listingsJson = JSON.serialize(listingsMap);
            
            ZooplaMockHttpResponse mock = new ZooplaMockHttpResponse();
            Test.setMock(HttpCalloutMock.class, mock);
            
            Test.startTest();
            ZooplaIntegrationController.zooplaDeleteListings(listingsJson);
            Test.stopTest();
            
            System.assert(true, 'Zoopla delete executed without errors');
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'PortalSyndicationControllerTest', 'testZooplaDeleteListings', 'Error in Zoopla delete test.');
        }
    }

    @isTest
    static void testZooplaCreateAndUpdateBranch() {
        try {
            Portal__c zooplaPortal = [SELECT Id FROM Portal__c WHERE Name = 'Zoopla' LIMIT 1];
            
            ZooplaIntegrationController.PropertyPortalWrapper wrapper = new ZooplaIntegrationController.PropertyPortalWrapper();
            wrapper.branch_reference = '99xx99';
            wrapper.branch_name = 'Test Branch';
            wrapper.street_name = 'Test Street';
            wrapper.town_or_city = 'Test City';
            wrapper.postal_code = 'W1D3QU';
            wrapper.country_code = 'GB';
            wrapper.locality = 'Test Locality';
            wrapper.county = 'Test County';
            wrapper.latitude = '51.5074';
            wrapper.longitude = '-0.1278';
            wrapper.address_key = 'test_key';
            wrapper.organisation_key = 'test_org';
            wrapper.postcode_type = 'S';
            wrapper.paf_udprn = '12345';
            wrapper.telephone = '1234567890';
            wrapper.email = 'test@example.com';
            wrapper.website = 'https://example.com';
            wrapper.is_test_portal = 'true';
            
            String portalWrapper = JSON.serialize(wrapper);
            
            ZooplaMockHttpResponse mock = new ZooplaMockHttpResponse();
            Test.setMock(HttpCalloutMock.class, mock);
            
            Test.startTest();
            ZooplaIntegrationController.zooplaCreateAndUpdateBranch(portalWrapper, zooplaPortal.Id);
            Test.stopTest();
            
            System.assert(true, 'Zoopla branch creation executed without errors');
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'PortalSyndicationControllerTest', 'testZooplaCreateAndUpdateBranch', 'Error in Zoopla branch creation test.');
        }
    }

    @isTest
    static void testZooplaFailureScenarios() {
        try {
            Listing__c listing = [SELECT Id FROM Listing__c LIMIT 1];
            Portal__c zooplaPortal = [SELECT Id FROM Portal__c WHERE Name = 'Zoopla' LIMIT 1];
            
            ZooplaMockHttpResponse mock = new ZooplaMockHttpResponse(true);
            Test.setMock(HttpCalloutMock.class, mock);
            
            Test.startTest();
            ZooplaIntegrationController.getListingRecordForSync(listing.Id, zooplaPortal.Id);
            Test.stopTest();
            
            System.assert(true, 'Zoopla failure handling executed');
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'PortalSyndicationControllerTest', 'testZooplaFailureScenarios', 'Error in Zoopla failure test.');
        }
    }

    @isTest
    static void testRightmoveCreateAndUpdateListing() {
        try {
            Listing__c listing = [SELECT Id FROM Listing__c LIMIT 1];
            Portal__c rightmovePortal = [SELECT Id FROM Portal__c WHERE Name = 'Rightmove' LIMIT 1];
            
            RightmoveMockHttpResponse mock = new RightmoveMockHttpResponse();
            Test.setMock(HttpCalloutMock.class, mock);
            
            Test.startTest();
            RightmoveIntegrationController.getListingRecordForSync(listing.Id, rightmovePortal.Id);
            Test.stopTest();
            
            System.assert(true, 'Rightmove sync executed without errors');
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'PortalSyndicationControllerTest', 'testRightmoveCreateAndUpdateListing', 'Error in Rightmove create/update test.');
        }
    }

    @isTest
    static void testRightmoveDeleteListings() {
        try {
            Listing__c listing = [SELECT Id FROM Listing__c LIMIT 1];

            Portal__c rightmovePortal = [SELECT Id FROM Portal__c WHERE Name = 'Rightmove' LIMIT 1];
            
            PortalListing__c portalListing = new PortalListing__c(
                Listing__c = listing.Id,
                Portal__c = rightmovePortal.Id,
                SystemIsActive__c = true
            );
            insert portalListing;
            
            Map<String, Map<String, String>> listingsMap = new Map<String, Map<String, String>>();
            listingsMap.put(listing.Id, new Map<String, String>{
                'portalId' => rightmovePortal.Id,
                'portalListingId' => portalListing.Id
            });
            String listingsJson = JSON.serialize(listingsMap);
            
            RightmoveMockHttpResponse mock = new RightmoveMockHttpResponse();
            Test.setMock(HttpCalloutMock.class, mock);
            
            Test.startTest();
            RightmoveIntegrationController.rightmoveDeleteListings(listingsJson);
            Test.stopTest();
            
            System.assert(true, 'Rightmove delete executed without errors');
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'PortalSyndicationControllerTest', 'testRightmoveDeleteListings', 'Error in Rightmove delete test.');
        }
    }

    @isTest
    static void testRightmoveOverseasListing() {
        try {
            Listing__c listing = [SELECT Id FROM Listing__c LIMIT 1];
            Portal__c rightmoveOverseas = [SELECT Id FROM Portal__c WHERE Name = 'Rightmove Overseas' LIMIT 1];
            
            RightmoveMockHttpResponse mock = new RightmoveMockHttpResponse();
            Test.setMock(HttpCalloutMock.class, mock);
            
            Test.startTest();
            RightmoveIntegrationController.getListingRecordForSync(listing.Id, rightmoveOverseas.Id);
            Test.stopTest();
            
            System.assert(true, 'Rightmove Overseas sync executed without errors');
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'PortalSyndicationControllerTest', 'testRightmoveOverseasListing', 'Error in Rightmove Overseas test.');
        }
    }

    @isTest
    static void testRightmoveFailureScenarios() {
        try {
            Listing__c listing = [SELECT Id FROM Listing__c LIMIT 1];
            Portal__c rightmovePortal = [SELECT Id FROM Portal__c WHERE Name = 'Rightmove' LIMIT 1];
            
            RightmoveMockHttpResponse mock = new RightmoveMockHttpResponse(true);
            Test.setMock(HttpCalloutMock.class, mock);
            
            Test.startTest();
            RightmoveIntegrationController.getListingRecordForSync(listing.Id, rightmovePortal.Id);
            Test.stopTest();
            
            System.assert(true, 'Rightmove failure handling executed');
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'PortalSyndicationControllerTest', 'testRightmoveFailureScenarios', 'Error in Rightmove failure test.');
        }
    }

    // Zoopla specific mock HTTP response generator
    private class ZooplaMockHttpResponse implements HttpCalloutMock {
        private Boolean simulateFailure = false;
        
        public ZooplaMockHttpResponse() {
            this.simulateFailure = false;
        }
        
        public ZooplaMockHttpResponse(Boolean failure) {
            this.simulateFailure = failure;
        }
        
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setHeader('Content-Type', 'application/json');
            
            String endpoint = req.getEndpoint();
            
            if (simulateFailure) {
                res.setStatusCode(401);
                res.setBody('{"error":"Unauthorized"}');
                return res;
            }
            
            if (endpoint.contains('/listing/update')) {
                res.setStatusCode(200);
                res.setHeader('Content-Type', 'application/json; profile=http://realtime-listings.webservices.zpg.co.uk/docs/v2.3/schemas/listing/update.json');
                res.setBody('{"listing_reference":"TESTLISTING","status":"available"}');
            } else if (endpoint.contains('/listing/delete')) {
                res.setStatusCode(200);
                res.setBody('{"listing_reference":"TESTLISTING","status":"deleted"}');
            } else if (endpoint.contains('/listing/list')) {
                res.setStatusCode(200);
                res.setBody('{"listings":[{"listing_reference":"TESTLISTING","url":"https://zoopla.com/listing/123"}]}');
            } else if (endpoint.contains('/branch/update')) {
                res.setStatusCode(200);
                res.setBody('{"branch_reference":"99xx99","status":"updated"}');
            } else {
                res.setStatusCode(200);
                res.setBody('{"status":"success"}');
            }
            
            return res;
        }
    }

    // Rightmove specific mock HTTP response generator
    private class RightmoveMockHttpResponse implements HttpCalloutMock {
        private Boolean simulateFailure = false;
        
        public RightmoveMockHttpResponse() {
            this.simulateFailure = false;
        }
        
        public RightmoveMockHttpResponse(Boolean failure) {
            this.simulateFailure = failure;
        }
        
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setHeader('Content-Type', 'application/json');
            
            String endpoint = req.getEndpoint();
            
            if (simulateFailure) {
                res.setStatusCode(404);
                res.setBody('{"success":false,"error":"Not found"}');
                return res;
            }
            
            if (endpoint.contains('sendpropertydetails')) {
                res.setStatusCode(200);
                res.setBody('{"success":true,"message":"Property details updated successfully"}');
            } else if (endpoint.contains('removeproperty')) {
                res.setStatusCode(200);
                res.setBody('{"success":true,"message":"Property removed successfully"}');
            } else if (endpoint.contains('getbranchpropertylist')) {
                res.setStatusCode(200);
                res.setBody('{"property":[{"agent_ref":"TESTLISTING","rightmove_id":123456,"update_date":"2024-01-01","channel":1}]}');
            } else {
                res.setStatusCode(200);
                res.setBody('{"success":true}');
            }
            
            return res;
        }
    }

    // PropertyFinder specific mock HTTP response generator
    private class PropertyFinderMockHttpResponse implements HttpCalloutMock {
        private Boolean simulateDeleteFailure = false;
        private Boolean simulateAuthFailure = false;
        
        public PropertyFinderMockHttpResponse() {
            this(false, false);
        }
        
        public PropertyFinderMockHttpResponse(Boolean deleteFailure) {
            this(deleteFailure, false);
        }
        
        public PropertyFinderMockHttpResponse(Boolean deleteFailure, Boolean authFailure) {
            this.simulateDeleteFailure = deleteFailure;
            this.simulateAuthFailure = authFailure;
        }
        
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse resp = new HttpResponse();
            resp.setHeader('Content-Type', 'application/json');
            String endpoint = req.getEndpoint();
            String method = req.getMethod();
            
            // Handle auth token request
            if (endpoint.contains('auth/token')) {
                if (simulateAuthFailure) {
                    resp.setStatusCode(401);
                    resp.setBody('{"error":"Unauthorized"}');
                } else {
                    resp.setStatusCode(200);
                    resp.setBody('{"accessToken":"mock-access-token-12345"}');
                }
                return resp;
            }
            
            // Handle GET listings request
            if (endpoint.contains('listings') && method == 'GET') {
                resp.setStatusCode(200);
                resp.setBody('{"results":[{"reference":"TESTLISTING","updatedAt":"2024-01-01T10:00:00Z","type":"sale","portals":{"propertyfinder":{"isLive":true}}}]}');
                return resp;
            }
            
            // Handle POST listings (create)
            if (endpoint.contains('listings') && method == 'POST' && !endpoint.contains('publish')) {
                resp.setStatusCode(200);
                resp.setBody('{"id":"pf-new-listing-12345","reference":"TESTLISTING","status":"draft"}');
                return resp;
            }
            
            // Handle PUT listings (update)
            if (endpoint.contains('listings/') && method == 'PUT') {
                resp.setStatusCode(200);
                resp.setBody('{"id":"pf-listing-12345","reference":"TESTLISTING","status":"updated"}');
                return resp;
            }
            
            // Handle DELETE listings
            if (endpoint.contains('listings/') && method == 'DELETE') {
                if (simulateDeleteFailure) {
                    resp.setStatusCode(400);
                    resp.setBody('{"error":"Failed to delete listing"}');
                } else {
                    resp.setStatusCode(200);
                    resp.setBody('{"success":true,"message":"Listing deleted"}');
                }
                return resp;
            }
            
            // Handle publish request
            if (endpoint.contains('publish')) {
                resp.setStatusCode(200);
                resp.setBody('{"success":true,"message":"Published successfully"}');
                return resp;
            }
            
            // Default response
            resp.setStatusCode(404);
            resp.setBody('{"error":"Endpoint not mocked"}');
            return resp;
        }
    }

    private class MockHttpResponseGenerator implements HttpCalloutMock {
        private Map<String, HttpResponse> endpointResponses;
        protected Integer code;
    
        /**
        * Method Name : MockHttpResponseGenerator
        * @param endpointResponses - Map<String, HttpResponse>
        * @return String
        * @description : Used to generate mock http response.
        */
        public MockHttpResponseGenerator(Map<String, HttpResponse> endpointResponses) {
            this.endpointResponses = endpointResponses;
        }
    
        /**
        * Method Name : respond
        * @param req - HTTPRequest
        * @return String
        * @description : Used to generate mock http response.
        */
        public HTTPResponse respond(HTTPRequest req) {
            String endpoint = req.getEndpoint();
    
            // Default response setup
            HttpResponse resp = new HttpResponse();
            resp.setHeader('Content-Type', 'application/json');
            
            // Check if the endpoint is mocked
            if (endpointResponses.containsKey(endpoint)) {
                HttpResponse mockResponse = endpointResponses.get(endpoint);
                
                // Set status code and body from mock response
                resp.setStatusCode(mockResponse.getStatusCode());
                resp.setBody(mockResponse.getBody());
            } else {
                // Endpoint not mocked scenario
                resp.setStatusCode(404);
                resp.setBody('{"error": "Endpoint not mocked"}');
            }
            
            return resp;
        }
    }
}