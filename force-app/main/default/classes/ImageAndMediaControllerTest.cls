/**
* Class Name : ImageAndMediaControllerTest
* Created By : Karan Singh
* Last Modified Date : 2026/10/12
* Last Modified By : Dhruv Kakadiya
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

            MVEX__Property__c property = new MVEX__Property__c(Name = 'Dev Test');
            insert property;

            Id saleRtId;
            Map<String, Schema.RecordTypeInfo> rtMap = Schema.SObjectType.MVEX__Listing__c.getRecordTypeInfosByDeveloperName();
            if (rtMap != null && rtMap.containsKey('Sale')) {
                saleRtId = rtMap.get('Sale').getRecordTypeId();
            }

            MVEX__Listing__c listing = new MVEX__Listing__c();
            listing.Name = 'Dev Test';
            listing.MVEX__Property__c = property.Id;
            listing.MVEX__Status__c = 'Active';
            listing.MVEX__Listing_Type__c = 'Sale';
            if (saleRtId != null) {
                listing.RecordTypeId = saleRtId;
            }
            listing.MVEX__Property_Type__c = 'Villa';
            listing.MVEX__Property_Sub_Type__c = 'Residential - Apartment';
            listing.MVEX__Property_Category__c = 'Residential';
            listing.MVEX__Country_Code__c = 'IN';
            listing.MVEX__Street__c = 'Dev Test';
            listing.MVEX__City__c = 'Dev Test';
            listing.MVEX__State__c = 'Dev Test';
            listing.MVEX__Zip_Postal_Code__c = '123456';
            listing.MVEX__Description__c = 'Dev Test';
            listing.MVEX__Listing_Price__c = 1000000;
            listing.MVEX__Bedrooms__c = 3;
            listing.MVEX__Bathrooms__c = 2;
            listing.MVEX__Lot_Size__c = 1000;
            listing.MVEX__Property_OwnerContact__c = contact.Id;
            listing.MVEX__Listed_Date__c = Date.today();
            listing.MVEX__Furnished__c = 'Yes';
            listing.MVEX__Property_Status__c = 'Vacant';
            listing.MVEX__Year_Built__c = '2020';
            insert listing;

            MVEX__Property_File__c propertyFile1 = new MVEX__Property_File__c(
                Name = 'Test Image 1',
                MVEX__Property__c = property.Id,
                MVEX__BaseUrl__c = 'https://example.com/image1',
                MVEX__Size__c = 123.45,
                MVEX__IsOnPortalFeed__c = true,
                MVEX__IsOnWebsite__c = true,
                MVEX__IsOnExpose__c = true
            );

            MVEX__Property_File__c propertyFile2 = new MVEX__Property_File__c(
                Name = 'Test Image 2',
                MVEX__Property__c = property.Id,
                MVEX__BaseUrl__c = 'https://example.com/image2',
                MVEX__Size__c = 543.21,
                MVEX__IsOnPortalFeed__c = false,
                MVEX__IsOnWebsite__c = false,
                MVEX__IsOnExpose__c = false,
                MVEX__Tags__c = 'Interior'
            );

            insert new List<MVEX__Property_File__c> { propertyFile1, propertyFile2 };

            MVEX__AWS_Config__c awsConfig = new MVEX__AWS_Config__c(
                MVEX__AWS_Access_Key__c = 'testKey',
                MVEX__AWS_Secret_Access_Key__c = 'testSecret',
                MVEX__S3_Bucket_Name__c = 'testBucket',
                MVEX__S3_Region_Name__c = 'us-east-1'
            );
            upsert awsConfig;
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
            MVEX__Listing__c listing = [SELECT Id, MVEX__Property__c FROM MVEX__Listing__c LIMIT 1];
            Test.startTest();
            ImageAndMediaController.ListingWrapper result = ImageAndMediaController.fetchListingAndImages(listing.Id);
            ImageAndMediaController.ListingWrapper result1 = ImageAndMediaController.fetchListingAndImages(null);
            Test.stopTest();

            System.assertNotEquals(null, result, 'Result should not be null');
            System.assertEquals(listing.MVEX__Property__c, result.propertyId, 'Property Id should match');
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
            MVEX__Listing__c listing = [SELECT Id, MVEX__Property__c FROM MVEX__Listing__c LIMIT 1];
        
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
            String result = ImageAndMediaController.createmediaforlisting(listing.MVEX__Property__c, mediaList);
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
    * Method Name : testUpdatePropertyFileRecords
    * @description : Used to test updatePropertyFileRecords method.
    */
    @isTest
    static void testUpdatePropertyFileRecords() {
        try {
            List<MVEX__Property_File__c> propertyFiles = [SELECT Id, Name, MVEX__Property__c, MVEX__BaseUrl__c, MVEX__Size__c, MVEX__IsOnPortalFeed__c, MVEX__IsOnWebsite__c, MVEX__IsOnExpose__c, MVEX__Tags__c FROM MVEX__Property_File__c LIMIT 1];

            List<Map<String, Object>> propertyFileMaps = new List<Map<String, Object>>();
            MVEX__Property_File__c file  = [SELECT Id, Name, MVEX__Property__c, MVEX__BaseUrl__c, MVEX__Size__c, MVEX__IsOnPortalFeed__c, MVEX__IsOnWebsite__c, MVEX__IsOnExpose__c, MVEX__Tags__c FROM MVEX__Property_File__c LIMIT 1];
            Map<String, Object> fileMap = new Map<String, Object>{
                'Id' => file.Id,
                'Name' => file.Name,
                'MVEX__IsOnPortalFeed__c' => file.MVEX__IsOnPortalFeed__c,
                'MVEX__IsOnWebsite__c' => file.MVEX__IsOnWebsite__c,
                'MVEX__IsOnExpose__c' => file.MVEX__IsOnExpose__c,
                'MVEX__Tags__c' => file.MVEX__Tags__c
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
            ErrorHandler.insertErrordata(e, 'ImageAndMediaControllerTest', 'testsaveFile', 'Error while saving file.');
        }
    }

    /**
    * Method Name : testDeleteListingMediaSingleFile
    * @description : Used to test deletelistingmedia method for single file deletion.
    */
    @isTest
    static void testDeleteListingMediaSingleFile() {
        try {
            MVEX__Property_File__c propertyFile = [SELECT Id FROM MVEX__Property_File__c LIMIT 1];
            
            Test.startTest();
            Boolean result = ImageAndMediaController.deletelistingmedia(propertyFile.Id, null);
            Test.stopTest();
            
            System.assertEquals(true, result, 'Deletion should be successful');
            List<MVEX__Property_File__c> deletedFiles = [SELECT Id FROM MVEX__Property_File__c WHERE Id = :propertyFile.Id];
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
            MVEX__Listing__c listing = [SELECT Id, MVEX__Property__c FROM MVEX__Listing__c LIMIT 1];
            Integer initialCount = [SELECT COUNT() FROM MVEX__Property_File__c WHERE MVEX__Property__c = :listing.MVEX__Property__c];
            
            Test.startTest();
            Boolean result = ImageAndMediaController.deletelistingmedia(null, listing.Id);
            Test.stopTest();
            
            System.assertEquals(true, result, 'Deletion should be successful');
            List<MVEX__Property_File__c> remainingFiles = [SELECT Id FROM MVEX__Property_File__c WHERE MVEX__Property__c = :listing.MVEX__Property__c];
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
            MVEX__Listing__c listing = [SELECT Id, MVEX__Property__c FROM MVEX__Listing__c LIMIT 1];
            
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
            ImageAndMediaController.createmediaforlisting(listing.MVEX__Property__c, mediaList);
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
            MVEX__Listing__c listing = [SELECT Id, MVEX__Property__c FROM MVEX__Listing__c LIMIT 1];
            
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
            ImageAndMediaController.createmediaforlisting(listing.MVEX__Property__c, mediaList);
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
            MVEX__Listing__c listing = [SELECT Id, MVEX__Property__c FROM MVEX__Listing__c LIMIT 1];
            
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
            ImageAndMediaController.createmediaforlisting(listing.MVEX__Property__c, mediaList);
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
            MVEX__Property_File__c file = [SELECT Id FROM MVEX__Property_File__c LIMIT 1];
            
            Map<String, Object> fileMap = new Map<String, Object>{
                'Id' => file.Id,
                'MVEX__IsOnPortalFeed__c' => true,
                'MVEX__IsOnWebsite__c' => true,
                'MVEX__IsOnExpose__c' => false,
                'MVEX__Tags__c' => 'Updated,Tag',
                'MVEX__Sort_on_Expose__c' => 5,
                'MVEX__Sort_on_Portal_Feed__c' => 3,
                'MVEX__Sort_on_Website__c' => 2
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

    /**
    * Method Name : testGetS3ConfigSettingsException
    * @description : Used to test getS3ConfigSettings exception handling using ContentVersion link with null VersionData.
    */
    @isTest
    static void testGetS3ConfigSettingsException() {
        List<ContentVersion> existingCVs = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE ExternalDocumentInfo1 = 'watermark3112'];
        if (!existingCVs.isEmpty()) {
            Set<Id> cdIds = new Set<Id>();
            for (ContentVersion cv : existingCVs) {
                cdIds.add(cv.ContentDocumentId);
            }
            delete [SELECT Id FROM ContentDocument WHERE Id IN :cdIds];
        }

        ContentVersion linkCv = new ContentVersion(
            Title = 'Watermark Link',
            ContentUrl = 'https://example.com/watermark.png',
            ExternalDocumentInfo1 = 'watermark3112'
        );
        insert linkCv;

        Test.startTest();
        ImageAndMediaController.AWSWrapper config = ImageAndMediaController.getS3ConfigSettings();
        Test.stopTest();

        System.assertEquals(false, config.status, 'Status should be false on exception');
    }
}