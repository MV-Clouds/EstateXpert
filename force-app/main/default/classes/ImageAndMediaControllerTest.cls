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

    /**
    * Method Name : testDeleteListingMediaSingleFile
    * @description : Used to test deletelistingmedia method for single file deletion.
    */
    @isTest
    static void testDeleteListingMediaSingleFile() {
        try {
            Property_File__c propertyFile = [SELECT Id FROM Property_File__c LIMIT 1];
            
            Test.startTest();
            Boolean result = ImageAndMediaController.deletelistingmedia(propertyFile.Id, null);
            Test.stopTest();
            
            System.assertEquals(true, result, 'Deletion should be successful');
            List<Property_File__c> deletedFiles = [SELECT Id FROM Property_File__c WHERE Id = :propertyFile.Id];
            System.assertEquals(0, deletedFiles.size(), 'File should be deleted');
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'ImageAndMediaControllerTest', 'testDeleteListingMediaSingleFile', 'Error while deleting single file.');
        }
    }

    /**
    * Method Name : testDeleteListingMediaAllFiles
    * @description : Used to test deletelistingmedia method for all files deletion.
    */
    @isTest
    static void testDeleteListingMediaAllFiles() {
        try {
            Listing__c listing = [SELECT Id, Property__c FROM Listing__c LIMIT 1];
            Integer initialCount = [SELECT COUNT() FROM Property_File__c WHERE Property__c = :listing.Property__c];
            
            Test.startTest();
            Boolean result = ImageAndMediaController.deletelistingmedia(null, listing.Id);
            Test.stopTest();
            
            System.assertEquals(true, result, 'Deletion should be successful');
            List<Property_File__c> remainingFiles = [SELECT Id FROM Property_File__c WHERE Property__c = :listing.Property__c];
            System.assertEquals(0, remainingFiles.size(), 'All files should be deleted');
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'ImageAndMediaControllerTest', 'testDeleteListingMediaAllFiles', 'Error while deleting all files.');
        }
    }

    /**
    * Method Name : testCreateMediaWithEmptyName
    * @description : Used to test createmediaforlisting with empty name.
    */
    @isTest
    static void testCreateMediaWithEmptyName() {
        try {
            Listing__c listing = [SELECT Id FROM Listing__c LIMIT 1];
            
            ImageAndMediaController.MediaData media = new ImageAndMediaController.MediaData();
            media.name = '';
            media.size = 100;
            media.externalUrl = 'https://example.com/emptyname';
            media.externalVideoUrl = '';
            media.isOnExpose = false;
            media.isOnPortalFeed = false;
            media.isOnWebsite = false;
            media.type = 'image/jpeg';

            List<ImageAndMediaController.MediaData> mediaList = new List<ImageAndMediaController.MediaData>{ media };

            Test.startTest();
            ImageAndMediaController.createmediaforlisting(listing.Id, mediaList);
            Test.stopTest();
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'ImageAndMediaControllerTest', 'testCreateMediaWithEmptyName', 'Error while creating media with empty name.');
        }
    }

    /**
    * Method Name : testCreateMediaWithNullName
    * @description : Used to test createmediaforlisting with null name.
    */
    @isTest
    static void testCreateMediaWithNullName() {
        try {
            Listing__c listing = [SELECT Id FROM Listing__c LIMIT 1];
            
            ImageAndMediaController.MediaData media = new ImageAndMediaController.MediaData();
            media.name = null;
            media.size = 150;
            media.externalUrl = 'https://example.com/nullname';
            media.externalVideoUrl = 'https://example.com/video';
            media.isOnExpose = true;
            media.isOnPortalFeed = true;
            media.isOnWebsite = true;
            media.type = 'video/mp4';

            List<ImageAndMediaController.MediaData> mediaList = new List<ImageAndMediaController.MediaData>{ media };

            Test.startTest();
            ImageAndMediaController.createmediaforlisting(listing.Id, mediaList);
            Test.stopTest();
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'ImageAndMediaControllerTest', 'testCreateMediaWithNullName', 'Error while creating media with null name.');
        }
    }

    /**
    * Method Name : testCreateMediaWithShortName
    * @description : Used to test createmediaforlisting with name less than 80 characters.
    */
    @isTest
    static void testCreateMediaWithShortName() {
        try {
            Listing__c listing = [SELECT Id FROM Listing__c LIMIT 1];
            
            ImageAndMediaController.MediaData media = new ImageAndMediaController.MediaData();
            media.name = 'Short Name';
            media.size = 200;
            media.externalUrl = 'https://example.com/shortname';
            media.externalVideoUrl = '';
            media.isOnExpose = true;
            media.isOnPortalFeed = false;
            media.isOnWebsite = true;
            media.type = 'image/png';

            List<ImageAndMediaController.MediaData> mediaList = new List<ImageAndMediaController.MediaData>{ media };

            Test.startTest();
            ImageAndMediaController.createmediaforlisting(listing.Id, mediaList);
            Test.stopTest();
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'ImageAndMediaControllerTest', 'testCreateMediaWithShortName', 'Error while creating media with short name.');
        }
    }

    /**
    * Method Name : testUpdatePropertyFileRecordsEmpty
    * @description : Used to test updatePropertyFileRecords with empty list.
    */
    @isTest
    static void testUpdatePropertyFileRecordsEmpty() {
        try {
            List<Map<String, Object>> emptyList = new List<Map<String, Object>>();
            
            Test.startTest();
            String result = ImageAndMediaController.updatePropertyFileRecords(emptyList);
            Test.stopTest();

            System.assertEquals('Property Media List is Empty or not accessible.', result, 'Should return empty message');
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'ImageAndMediaControllerTest', 'testUpdatePropertyFileRecordsEmpty', 'Error while testing empty update.');
        }
    }

    /**
    * Method Name : testUpdatePropertyFileRecordsMultipleFields
    * @description : Used to test updatePropertyFileRecords with multiple fields.
    */
    @isTest
    static void testUpdatePropertyFileRecordsMultipleFields() {
        try {
            Property_File__c file = [SELECT Id FROM Property_File__c LIMIT 1];
            
            Map<String, Object> fileMap = new Map<String, Object>{
                'Id' => file.Id,
                'IsOnPortalFeed__c' => true,
                'IsOnWebsite__c' => true,
                'IsOnExpose__c' => false,
                'Tags__c' => 'Updated,Tag',
                'Sort_on_Expose__c' => 5,
                'Sort_on_Portal_Feed__c' => 3,
                'Sort_on_Website__c' => 2
            };
            
            Test.startTest();
            ImageAndMediaController.updatePropertyFileRecords(new List<Map<String, Object>>{fileMap});
            Test.stopTest();
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'ImageAndMediaControllerTest', 'testUpdatePropertyFileRecordsMultipleFields', 'Error while updating multiple fields.');
        }
    }

    /**
    * Method Name : testDeleteFilesWithInvalidId
    * @description : Used to test deleteFiles with invalid ContentVersion ID.
    */
    @isTest
    static void testDeleteFilesWithInvalidId() {
        try {
            Test.startTest();
            ImageAndMediaController.deleteFiles('invalidId123');
            Test.stopTest();
            
            System.assert(true, 'Method should handle invalid ID gracefully');
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'ImageAndMediaControllerTest', 'testDeleteFilesWithInvalidId', 'Error while testing invalid delete.');
        }
    }

    /**
    * Method Name : testGetContentVersionDataEmpty
    * @description : Used to test getContentVersionData when no records exist.
    */
    @isTest
    static void testGetContentVersionDataEmpty() {
        try {
            // Delete any existing watermark content versions
            List<ContentVersion> existingCVs = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE ExternalDocumentInfo1 = 'watermark3112'];
            if (!existingCVs.isEmpty()) {
                Set<Id> cdIds = new Set<Id>();
                for (ContentVersion cv : existingCVs) {
                    cdIds.add(cv.ContentDocumentId);
                }
                List<ContentDocument> cds = [SELECT Id FROM ContentDocument WHERE Id IN :cdIds];
                delete cds;
            }
            
            Test.startTest();
            List<ContentVersion> result = ImageAndMediaController.getContentVersionData();
            Test.stopTest();
            
            System.assertEquals(null, result, 'Should return null when no records exist');
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'ImageAndMediaControllerTest', 'testGetContentVersionDataEmpty', 'Error while testing empty content version data.');
        }
    }

    /**
    * Method Name : testFetchListingAndImagesNoRecords
    * @description : Used to test fetchListingAndImages when no listing found.
    */
    @isTest
    static void testFetchListingAndImagesNoRecords() {
        try {
            Test.startTest();
            ImageAndMediaController.ListingWrapper result = ImageAndMediaController.fetchListingAndImages('invalidId123456789012345');
            Test.stopTest();
            
            System.assertEquals('No Record Found.', result.status, 'Should return no record found status');
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'ImageAndMediaControllerTest', 'testFetchListingAndImagesNoRecords', 'Error while testing no records scenario.');
        }
    }

    /**
    * Method Name : testGetS3ConfigSettingsWithoutWatermark
    * @description : Used to test getS3ConfigSettings without watermark content version.
    */
    @isTest
    static void testGetS3ConfigSettingsWithoutWatermark() {
        try {
            // Delete watermark content versions
            List<ContentVersion> existingCVs = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE ExternalDocumentInfo1 = 'watermark3112'];
            if (!existingCVs.isEmpty()) {
                Set<Id> cdIds = new Set<Id>();
                for (ContentVersion cv : existingCVs) {
                    cdIds.add(cv.ContentDocumentId);
                }
                List<ContentDocument> cds = [SELECT Id FROM ContentDocument WHERE Id IN :cdIds];
                delete cds;
            }
            
            Test.startTest();
            ImageAndMediaController.AWSWrapper config = ImageAndMediaController.getS3ConfigSettings();
            Test.stopTest();

            System.assertEquals('', config.contentVersionData, 'Content version data should be empty');
            System.assertEquals(true, config.status, 'Status should be true');
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'ImageAndMediaControllerTest', 'testGetS3ConfigSettingsWithoutWatermark', 'Error while testing config without watermark.');
        }
    }
}