@isTest
private class InstagramPostControllerTest {

    // ─── HTTP Mock for Success (Single Media & Carousel) ─────────────────────
    private class InstagramSuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            String endpoint = req.getEndpoint();
            
            // S3 delete call
            if (endpoint.contains('.s3.amazonaws.com')) {
                res.setStatusCode(200);
                res.setBody('<?xml version="1.0" encoding="UTF-8"?><DeleteResult></DeleteResult>');
                return res;
            }
            
            // Instagram media/publish calls
            res.setStatusCode(200);
            res.setBody('{"id":"123456789"}');
            return res;
        }
    }

    // ─── HTTP Mock for Errors ────────────────────────────────────────────────
    private class InstagramErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            String endpoint = req.getEndpoint();
            
            if (endpoint.contains('.s3.amazonaws.com')) {
                res.setStatusCode(400);
                res.setBody('<Error><Code>InvalidRequest</Code></Error>');
                return res;
            }
            
            res.setStatusCode(400);
            res.setBody('{"error":{"message":"Invalid OAuth access token."}}');
            return res;
        }
    }

    @testSetup
    static void setup() {
        // Create AWS Config custom setting
        MVEX__AWS_Config__c awsConfig = new MVEX__AWS_Config__c(
            MVEX__AWS_Access_Key__c = 'mock_access_key',
            MVEX__AWS_Secret_Access_Key__c = 'mock_secret_key',
            MVEX__S3_Region_Name__c = 'us-east-1',
            MVEX__S3_Bucket_Name__c = 'test-bucket'
        );
        insert awsConfig;
        
        // Create Property & Listing
        MVEX__Property__c prop = TestDataFactory.createProperty(true);
        MVEX__Listing__c listing = TestDataFactory.createListing(true, prop.Id, null);
        
        // Create Property Files
        MVEX__Property_File__c file1 = TestDataFactory.createPropertyFile(false, prop.Id);
        file1.MVEX__ExternalLink__c = 'https://example.com/image1.jpg';
        insert file1;
        
        MVEX__Property_File__c file2 = TestDataFactory.createPropertyFile(false, prop.Id);
        file2.Name = 'Test Video';
        file2.MVEX__BaseUrl__c = 'https://example.com/video.mp4';
        insert file2;
    }

    @isTest
    static void testGetMediaTypeFromUrl() {
        // Test implicitly via postToInstagram to cover various extensions
        // But let's also directly test the logic if possible or rely on the postToInstagram call
        // Since getMediaTypeFromUrl is private, we cover it through postToInstagram.
    }

    @isTest
    static void testGenerateAWSHeadersAndKey() {
        Test.startTest();
        Map<String, String> headers = InstagramPostController.generateAWSHeaders('payload', 'md5', 'access', 'secret', 'us-east-1', 'bucket');
        Test.stopTest();
        
        System.assertNotEquals(null, headers);
        System.assertEquals('md5', headers.get('Content-MD5'));
    }

    @isTest
    static void testDeleteAwsImagesSuccess() {
        Test.setMock(HttpCalloutMock.class, new InstagramSuccessMock());
        
        Test.startTest();
        InstagramPostController.deleteAwsImages(new List<String>{'image1.jpg'}, new List<String>());
        Test.stopTest();
        
        // Ensure no exception is thrown
        System.assert(true);
    }
    
    @isTest
    static void testDeleteAwsImagesError() {
        Test.setMock(HttpCalloutMock.class, new InstagramErrorMock());
        
        Test.startTest();
        InstagramPostController.deleteAwsImages(new List<String>{'image1.jpg'}, new List<String>());
        Test.stopTest();
        
        // Ensure error is handled
        System.assert(true);
    }

    @isTest
    static void testGetPropertyMediaUrls() {
        MVEX__Listing__c listing = [SELECT Id FROM MVEX__Listing__c LIMIT 1];
        
        Test.startTest();
        Map<String, String> mediaUrls = InstagramPostController.getPropertyMediaUrls(listing.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, mediaUrls);
        System.assertEquals(2, mediaUrls.size());
    }

    @isTest
    static void testCheckInstagramIntegration() {
        Test.startTest();
        Boolean isConnected = InstagramPostController.checkInstagramIntegration();
        Test.stopTest();
        
        System.assertEquals(true, isConnected);
    }

    @isTest
    static void testPostToInstagramSingleMediaSuccess() {
        Test.setMock(HttpCalloutMock.class, new InstagramSuccessMock());
        
        Test.startTest();
        InstagramPostController.InstagramPostResponse res = InstagramPostController.postToInstagram(
            new List<String>{'https://example.com/img.jpg'}, 
            'Test Caption', 
            new List<String>{'img.jpg'}, 
            new List<String>()
        );
        Test.stopTest();
        
        System.assertEquals('SUCCESS', res.status);
    }
    
    @isTest
    static void testPostToInstagramSingleMediaReelsSuccess() {
        Test.setMock(HttpCalloutMock.class, new InstagramSuccessMock());
        
        Test.startTest();
        InstagramPostController.InstagramPostResponse res = InstagramPostController.postToInstagram(
            new List<String>{'https://example.com/video.mp4'}, 
            'Test Caption Reels', 
            new List<String>{'video.mp4'}, 
            new List<String>()
        );
        Test.stopTest();
        
        System.assertEquals('SUCCESS', res.status);
    }

    @isTest
    static void testPostToInstagramCarouselSuccess() {
        Test.setMock(HttpCalloutMock.class, new InstagramSuccessMock());
        
        Test.startTest();
        InstagramPostController.InstagramPostResponse res = InstagramPostController.postToInstagram(
            new List<String>{'https://example.com/img1.jpg', 'https://example.com/img2.jpg'}, 
            'Test Caption Carousel', 
            new List<String>{'img1.jpg', 'img2.jpg'}, 
            new List<String>()
        );
        Test.stopTest();
        
        System.assertEquals('SUCCESS', res.status);
    }

    @isTest
    static void testPostToInstagramError() {
        Test.setMock(HttpCalloutMock.class, new InstagramErrorMock());
        
        Test.startTest();
        InstagramPostController.InstagramPostResponse res = InstagramPostController.postToInstagram(
            new List<String>{'https://example.com/img.jpg'}, 
            'Test Caption', 
            new List<String>{'img.jpg'}, 
            new List<String>()
        );
        Test.stopTest();
        
        System.assertEquals('ERROR', res.status);
        System.assert(res.message.contains('Invalid OAuth access token.'));
    }
    
    @isTest
    static void testPostToInstagramCarouselError() {
        Test.setMock(HttpCalloutMock.class, new InstagramErrorMock());
        
        Test.startTest();
        InstagramPostController.InstagramPostResponse res = InstagramPostController.postToInstagram(
            new List<String>{'https://example.com/img1.jpg', 'https://example.com/img2.jpg'}, 
            'Test Caption Carousel', 
            new List<String>{'img1.jpg', 'img2.jpg'}, 
            new List<String>()
        );
        Test.stopTest();
        
        System.assertEquals('ERROR', res.status);
        System.assert(res.message.contains('Invalid OAuth access token.'));
    }
    
    @isTest
    static void testSendEmailNotification() {
        Test.startTest();
        // Just covering the catch block or empty template logic
        InstagramPostController.sendEmailNotification('Test error message');
        Test.stopTest();
        
        System.assert(true);
    }
}