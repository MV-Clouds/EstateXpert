@isTest
private class AWSActionControllerTestV1 {
    // Test setup method to create necessary data
    @TestSetup
    static void setup() {
        // Create AWS configuration custom settings
        AWS_Config__c awsConfig = new AWS_Config__c(
            S3_Bucket_Name__c = 'test-bucket',
            AWS_Access_Key__c = 'test-key',
            AWS_Secret_Access_Key__c = 'test-secret',
            S3_Region_Name__c = 'us-east-1',
            Payloadhash__c = 'test-hash'
        );
        insert awsConfig;

        // Create a test property
        Property__c property = new Property__c(Name = 'Test Property');
        insert property;

        // Create a test Property_File__c record
        Property_File__c propertyFile = new Property_File__c(
            Name = 'test-image.jpg',
            Filename__c = 'test-image.jpg',
            Property__c = property.Id,
            BaseUrl__c = 'https://test-bucket.s3.amazonaws.com/test-image.jpg',
            MVEX__MimeType__c = 'image/jpeg',
            Size__c = 1024
        );
        insert propertyFile;
    }

    // Test successful file upload and media creation
    @isTest
    static void testUploadAndCreateMediaSuccess() {
        Property__c property = [SELECT Id FROM Property__c LIMIT 1];
        List<AWSActionControllerV1.FileDataWrapper> fileDataList = new List<AWSActionControllerV1.FileDataWrapper>();
        
        // Create test file and media data
        AWSActionControllerV1.FileWrapper file = new AWSActionControllerV1.FileWrapper();
        file.name = 'test-image-new.jpg';
        file.base64Data = EncodingUtil.base64Encode(Blob.valueOf('test content'));
        file.size = 1024;
        file.type = 'image/jpeg';
        file.isWatermarked = false;

        AWSActionControllerV1.MediaData media = new AWSActionControllerV1.MediaData();
        media.name = 'test-image-new.jpg';
        media.size = 1024;
        media.type = 'image/jpeg';
        media.isOnExpose = true;
        media.isOnPortalFeed = true;
        media.isOnWebsite = true;

        AWSActionControllerV1.FileDataWrapper wrapper = new AWSActionControllerV1.FileDataWrapper();
        wrapper.file = file;
        wrapper.media = media;
        fileDataList.add(wrapper);

        // Set mock HTTP response
        Test.setMock(HttpCalloutMock.class, new AWSActionControllerMockV1());

        Test.startTest();
        Map<String, String> response = AWSActionControllerV1.uploadAndCreateMedia(property.Id, fileDataList);
        Test.stopTest();

        // Assertions
        System.assertEquals('success', response.get('status'), 'Expected successful upload status');
        System.assertEquals('Files Uploaded Successfully', response.get('message'), 'Expected success message');
        
        List<Property_File__c> mediaRecords = [SELECT Id, Name, Filename__c, BaseUrl__c, Size__c, MVEX__MimeType__c 
                                              FROM Property_File__c 
                                              WHERE Property__c = :property.Id 
                                              AND Filename__c = 'test-image-new.jpg'];
        System.assertEquals(1, mediaRecords.size(), 'Expected one media record to be created');
        System.assertEquals('test-image-new.jpg', mediaRecords[0].Name, 'Expected correct file name');
        System.assertEquals('image/jpeg', mediaRecords[0].MVEX__MimeType__c, 'Expected correct MIME type');
    }

    // Test upload with null property ID
    @isTest
    static void testUploadAndCreateMediaNullPropertyId() {
        List<AWSActionControllerV1.FileDataWrapper> fileDataList = new List<AWSActionControllerV1.FileDataWrapper>();
        
        Test.startTest();
        Map<String, String> response = AWSActionControllerV1.uploadAndCreateMedia(null, fileDataList);
        Test.stopTest();

        // Assertions
        System.assertEquals('error', response.get('status'), 'Expected error status');
        System.assertEquals('Property ID is required', response.get('message'), 'Expected error message for null property ID');
    }

    // Test upload with empty file list
    @isTest
    static void testUploadAndCreateMediaEmptyFileList() {
        Property__c property = [SELECT Id FROM Property__c LIMIT 1];
        
        Test.startTest();
        Map<String, String> response = AWSActionControllerV1.uploadAndCreateMedia(property.Id, new List<AWSActionControllerV1.FileDataWrapper>());
        Test.stopTest();

        // Assertions
        System.assertEquals('error', response.get('status'), 'Expected error status');
        System.assertEquals('No files provided for upload', response.get('message'), 'Expected error message for empty file list');
    }

    // Test successful single image deletion
    @isTest
    static void testDeleteAWSImageSuccess() {
        Property_File__c propertyFile = [SELECT Id, Filename__c FROM Property_File__c LIMIT 1];

        // Set mock HTTP response
        Test.setMock(HttpCalloutMock.class, new AWSActionControllerMockV1());

        Test.startTest();
        Map<String, String> response = AWSActionControllerV1.deleteAWSImage(propertyFile.Id);
        Test.stopTest();

        // Assertions
        System.assertEquals('success', response.get('status'), 'Expected successful deletion status');
        System.assertEquals('Media file deleted successfully.', response.get('message'), 'Expected success message');
        
        List<Property_File__c> remainingFiles = [SELECT Id FROM Property_File__c WHERE Id = :propertyFile.Id];
        System.assertEquals(0, remainingFiles.size(), 'Expected the Property_File__c record to be deleted');
    }

    // Test deletion with invalid file ID
    @isTest
    static void testDeleteAWSImageInvalidId() {
        Test.startTest();
        Map<String, String> response = AWSActionControllerV1.deleteAWSImage('invalidId');
        Test.stopTest();

        // Assertions
        System.assertEquals('error', response.get('status'), 'Expected error status');
        System.assertEquals('Property file not found', response.get('message'), 'Expected error message for invalid ID');
    }

    // Test successful deletion of all images for a property
    @isTest
    static void testDeleteAllAWSImagesSuccess() {
        Property__c property = [SELECT Id FROM Property__c LIMIT 1];

        // Set mock HTTP response
        Test.setMock(HttpCalloutMock.class, new AWSActionControllerMockV1());

        Test.startTest();
        Map<String, String> response = AWSActionControllerV1.deleteAllAWSImages(property.Id);
        Test.stopTest();

        // Assertions
        System.assertEquals('success', response.get('status'), 'Expected successful deletion status');
        System.assertEquals('All media files deleted successfully.', response.get('message'), 'Expected success message');
        
        List<Property_File__c> remainingFiles = [SELECT Id FROM Property_File__c WHERE Property__c = :property.Id];
        System.assertEquals(0, remainingFiles.size(), 'Expected all Property_File__c records to be deleted');
    }

    // Test deletion of all images with invalid property ID
    @isTest
    static void testDeleteAllAWSImagesInvalidId() {
        Test.startTest();
        Map<String, String> response = AWSActionControllerV1.deleteAllAWSImages('invalidId');
        Test.stopTest();

        // Assertions
        System.assertEquals('error', response.get('status'), 'Expected error status');
        System.assertEquals('No files found for the property', response.get('message'), 'Expected error message for invalid property ID');
    }

    // Test successful retrieval of Base64 data
    @isTest
    static void testGetBase64DataSuccess() {
        Property_File__c propertyFile = [SELECT Id, Filename__c, MVEX__MimeType__c FROM Property_File__c LIMIT 1];

        // Set mock HTTP response
        Test.setMock(HttpCalloutMock.class, new AWSActionControllerMockV1());

        Test.startTest();
        Map<String, String> response = AWSActionControllerV1.getBase64Data(propertyFile.Id);
        Test.stopTest();

        // Assertions
        System.assertEquals('success', response.get('status'), 'Expected successful retrieval status');
        System.assertEquals('S3 object fetched successfully', response.get('message'), 'Expected success message');
        System.assert(response.get('data').startsWith('data:image/jpeg;base64,'), 'Expected Base64 data with correct MIME type');
    }

    // Test Base64 retrieval with invalid file ID
    @isTest
    static void testGetBase64DataInvalidId() {
        Test.startTest();
        Map<String, String> response = AWSActionControllerV1.getBase64Data('invalidId');
        Test.stopTest();

        // Assertions
        System.assertEquals('error', response.get('status'), 'Expected error status');
    }
}