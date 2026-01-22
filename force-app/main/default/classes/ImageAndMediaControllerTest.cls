/**
* Class Name : ImageAndMediaControllerTest
* Created By : Karan Singh
* Last Modified Date : 24/06/2024
* Last Modified By : Karan Singh
* @description : Test class for ImageAndMediaController.
*/
@isTest
public with sharing class ImageAndMediaControllerTest {
    
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

            Listing__c listing = new Listing__c();
            listing.Name = 'Dev Test';
            listing.Property__c = property.Id;
            listing.Status__c = 'Active';
            listing.Listing_Type__c = 'Sale';
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
            insert listing;

            Property_File__c propertyFile1 = new Property_File__c(
                Name = 'Test Image 1',
                Property__c = property.Id,
                BaseUrl__c = 'https://example.com/image1',
                Size__c = 123.45,
                IsOnPortalFeed__c = true,
                IsOnWebsite__c = true,
                IsOnExpose__c = true
            );

            Property_File__c propertyFile2 = new Property_File__c(
                Name = 'Test Image 2',
                Property__c = property.Id,
                BaseUrl__c = 'https://example.com/image2',
                Size__c = 543.21,
                IsOnPortalFeed__c = false,
                IsOnWebsite__c = false,
                IsOnExpose__c = false,
                Tags__c = 'Interior'
            );

            insert new List<Property_File__c> { propertyFile1, propertyFile2 };
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'ImageAndMediaControllerTest', 'setupTestData', 'Error while creating test data.');
        }
    }

    /**
    * Method Name : testFetchListingAndImages
    * @description : Used to test fetchListingAndImages method.
    */
    @isTest
    static void testFetchListingAndImages() {
        try {
            Listing__c listing = [SELECT Id, Property__c FROM Listing__c LIMIT 1];
            Test.startTest();
            ImageAndMediaController.ListingWrapper result = ImageAndMediaController.fetchListingAndImages(listing.Id);
            ImageAndMediaController.ListingWrapper result1 = ImageAndMediaController.fetchListingAndImages(null);
            Test.stopTest();

            System.assertNotEquals(null, result, 'Result should not be null');
            System.assertEquals(listing.Property__c, result.propertyId, 'Property Id should match');
            System.assertEquals(2, result.listingImages.size(), 'There should be 2 images');
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'ImageAndMediaControllerTest', 'testFetchListingAndImages', 'Error while fetching listing and images.');
        }
    }

    /**
    * Method Name : testCreateMediaForListing
    * @description : Used to test createmediaforlisting method.
    */
    @isTest
    static void testCreateMediaForListing() {
        try {
            Listing__c listing = [SELECT Id FROM Listing__c LIMIT 1];
        
            ImageAndMediaController.MediaData media1 = new ImageAndMediaController.MediaData();
            media1.name = 'Morbi a metus. Phasellus enim erat, vestibulum vel, aliquam a, posuere eu, velit.';
            media1.size = 123;
            media1.externalUrl = 'https://example.com/newimage1';
            media1.externalVideoUrl = 'https://example.com/newvideo1';
            media1.isOnExpose = true;
            media1.isOnPortalFeed = false;
            media1.isOnWebsite = true;
            
            ImageAndMediaController.MediaData media2 = new ImageAndMediaController.MediaData();
            media2.name = 'New Image 2';
            media2.size = 123;
            media2.externalUrl = 'https://example.com/newimage2';
            media2.externalVideoUrl = 'https://example.com/newvideo2';
            media2.isOnExpose = false;
            media2.isOnPortalFeed = true;
            media2.isOnWebsite = false;

            List<ImageAndMediaController.MediaData> mediaList = new List<ImageAndMediaController.MediaData>{ media1, media2 };

            Test.startTest();
            String result = ImageAndMediaController.createmediaforlisting(listing.Id, mediaList);
            String result1 = ImageAndMediaController.createmediaforlisting(null, null);
            Test.stopTest();

            System.assert(result != null, 'Media should be created successfully');
                        
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'ImageAndMediaControllerTest', 'testCreateMediaForListing', 'Error while creating media for listing.');
        }
    }

    /**
    * Method Name : testGetS3ConfigSettings
    * @description : Used to test gets3configsettings method.
    */
    @isTest
    static void testGetS3ConfigSettings() {
        try {
            Test.startTest();
            ImageAndMediaController.AWSWrapper config = ImageAndMediaController.getS3ConfigSettings();            
            Test.stopTest();

            System.assertNotEquals(null, config, 'Config settings should not be null');
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'ImageAndMediaControllerTest', 'testGetS3ConfigSettings', 'Error while getting S3 config settings.');
        }
    }

    /**
    * Method Name : testGetS3ConfigSettings
    * @description : Used to test gets3configsettings method.
    */
    @isTest
    static void testUpdatePropertyFileRecords() {
        try {
            List<Property_File__c> propertyFiles = [SELECT Id, Name, Property__c, BaseUrl__c, Size__c, IsOnPortalFeed__c, IsOnWebsite__c, IsOnExpose__c, Tags__c FROM Property_File__c LIMIT 1];

            List<Map<String, Object>> propertyFileMaps = new List<Map<String, Object>>();
            Property_File__c file  = [SELECT Id, Name, Property__c, BaseUrl__c, Size__c, IsOnPortalFeed__c, IsOnWebsite__c, IsOnExpose__c, Tags__c FROM Property_File__c LIMIT 1];
            Map<String, Object> fileMap = new Map<String, Object>{
                'Id' => file.Id,
                'Name' => file.Name,
                'IsOnPortalFeed__c' => file.IsOnPortalFeed__c,
                'IsOnWebsite__c' => file.IsOnWebsite__c,
                'IsOnExpose__c' => file.IsOnExpose__c,
                'Tags__c' => file.Tags__c
            };
            propertyFileMaps.add(fileMap);            

            // Call the method to test
            Test.startTest();
            String result = ImageAndMediaController.updatePropertyFileRecords(propertyFileMaps);
            Test.stopTest();

            // Add assertions here
            System.assertEquals('success', result, 'Method should return success');
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'ImageAndMediaControllerTest', 'testUpdatePropertyFileRecords', 'Error while updating property file records.');
        }
    }
    
    /**
    * Method Name : testsaveFile
    * @description : Used to test saveFile method.
    */
    @isTest
    static void testsaveFile() {
        try {
            Test.startTest();
            ContentVersion cv = ImageAndMediaController.saveFile('Testfilename','Testbase64data'); 
            ImageAndMediaController.deleteFiles(cv.id);
            ImageAndMediaController.getContentVersionData();
            Test.stopTest();
           System.assert(cv != null, 'Contentversion inserted.');
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'ImageAndMediaControllerTest', 'testGetS3ConfigSettings', 'Error while getting S3 config settings.');
        }
    }
}