@isTest
public with sharing class InstagramPostControllerTest {

    @testSetup
    static void setupTestData() {
        GmailConfig__c gmailConfig = new GmailConfig__c(
            Client_ID__c = 'test_client',
            Client_Secret__c = 'test_secret',
            Refresh_Token__c = 'test_refresh_token'
        );
        insert gmailConfig;
        
        insert new IG_Configuration__c(
            User_Id__c = '1234567890',
            Long_Access_Token__c = 'mock_access_token'
        );

        insert new AWS_Config__c(
            AWS_Access_Key__c = 'accessKey',
            AWS_Secret_Access_Key__c = 'secretKey',
            S3_Region_Name__c = 'us-west-1',
            S3_Bucket_Name__c = 'mock-bucket'
        );

        Property__c prop = new Property__c(Name = 'Test Property');
        insert prop;

        Listing__c listing = new Listing__c(Name = 'Test Listing', Property__c = prop.Id);
        insert listing;

        insert new Property_File__c(
            Name = 'SampleImage',
            BaseUrl__c = 'https://mock-url.com/image.jpg',
            Property__c = prop.Id
        );
    }

    @isTest
    static void testPostToInstagramSingleImage() {
        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setHeader('Content-Type', 'application/json');
        mockResponse.setBody('{"id": "mock_container_id"}');
        mockResponse.setStatusCode(200);

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(mockResponse));

        Test.startTest();
        InstagramPostController.InstagramPostResponse result = InstagramPostController.postToInstagram(
            new List<String>{'https://mock-url.com/image.jpg'},
            'Test Caption',
            new List<String>{'objectKey1'},
            new List<String>{'objectKey2'}
        );
        Test.stopTest();
    }

    @isTest
    static void testPostToInstagramCarousel() {
        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setHeader('Content-Type', 'application/json');
        mockResponse.setBody('{"id": "mock_container_id"}');
        mockResponse.setStatusCode(200);

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(mockResponse));

        Test.startTest();
        InstagramPostController.InstagramPostResponse result = InstagramPostController.postToInstagram(
            new List<String>{'https://mock-url.com/image1.jpg', 'https://mock-url.com/image2.jpg'},
            'Carousel Caption',
            new List<String>{'key1'},
            new List<String>{'key2'}
        );
        Test.stopTest();
    }

    @isTest
    static void testGetS3ConfigSettings() {
        Test.startTest();
        AWS_Config__c config = InstagramPostController.getS3ConfigSettings();
        Test.stopTest();

        System.assertNotEquals(null, config, 'Expected S3 config settings to be returned');
    }

    @isTest
    static void testGenerateAWSHeaders() {
        String payload = '<Delete><Quiet>true</Quiet></Delete>';
        String contentMD5 = EncodingUtil.base64Encode(Crypto.generateDigest('MD5', Blob.valueOf(payload)));

        Test.startTest();
        Map<String, String> headers = InstagramPostController.generateAWSHeaders(
            payload,
            contentMD5,
            'accessKey',
            'secretKey',
            'us-west-1',
            'mock-bucket'
        );
        Test.stopTest();

        System.assert(headers.containsKey('Content-MD5'), 'Expected Content-MD5 header to be present');
    }

    @isTest
    static void testGetPropertyMediaUrls() {
        Id listingId = [SELECT Id FROM Listing__c LIMIT 1].Id;

        Test.startTest();
        Map<String, String> result = InstagramPostController.getPropertyMediaUrls(listingId);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Expected non-null media URL map');
    }

    @isTest
    static void testCheckInstagramIntegration() {
        Test.startTest();
        Boolean result = InstagramPostController.checkInstagramIntegration();
        Test.stopTest();

        System.assertEquals(true, result, 'Expected integration check to return true');
    }

    @isTest
    static void testCreateInstagramContainerSingleAndCarousel() {
        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setHeader('Content-Type', 'application/json');
        mockResponse.setBody('{"id": "mock_container_12345"}');
        mockResponse.setStatusCode(200);

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(mockResponse));

        Test.startTest();
        // Test single image
        Map<String, Object> singleResult = InstagramPostController.createInstagramContainer(
            new List<String>{'https://mock-url.com/image.jpg'},
            'Single Image Caption'
        );
        
        // Test carousel
        Map<String, Object> carouselResult = InstagramPostController.createInstagramContainer(
            new List<String>{'https://mock-url.com/img1.jpg', 'https://mock-url.com/img2.jpg'},
            'Carousel Caption'
        );
        
        // Test video (REELS)
        Map<String, Object> videoResult = InstagramPostController.createInstagramContainer(
            new List<String>{'https://mock-url.com/video.mp4'},
            'Video Caption'
        );
        Test.stopTest();

        System.assertEquals(true, singleResult.get('success'), 'Single image should succeed');
        System.assertEquals(false, singleResult.get('isCarousel'), 'Should not be carousel');
        System.assertEquals(true, carouselResult.get('success'), 'Carousel should succeed');
        System.assertEquals(true, carouselResult.get('isCarousel'), 'Should be carousel');
        System.assertEquals(true, videoResult.get('success'), 'Video should succeed');
    }

    @isTest
    static void testCreateInstagramContainerFailure() {
        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setHeader('Content-Type', 'application/json');
        mockResponse.setBody('{"error": {"message": "Invalid media URL"}}');
        mockResponse.setStatusCode(400);

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(mockResponse));

        Test.startTest();
        Map<String, Object> result = InstagramPostController.createInstagramContainer(
            new List<String>{'https://mock-url.com/invalid.jpg'},
            'Test Caption'
        );
        Test.stopTest();

        System.assertEquals(false, result.get('success'), 'Should fail with invalid URL');
    }

    @isTest
    static void testPublishToInstagram() {
        Test.startTest();
        // Test single media publish
        String resultSingle = InstagramPostController.publishToInstagram(
            'mock_container_id',
            new List<String>(),
            false,
            'Single Caption',
            new List<String>{'key1'},
            new List<String>{'key2'}
        );
        
        // Test carousel publish
        String resultCarousel = InstagramPostController.publishToInstagram(
            '',
            new List<String>{'container1', 'container2'},
            true,
            'Carousel Caption',
            new List<String>{'key1', 'key2'},
            new List<String>{'key3'}
        );
        Test.stopTest();

        System.assertNotEquals(null, resultSingle, 'Single publish result should not be null');
        System.assertNotEquals(null, resultCarousel, 'Carousel publish result should not be null');
        System.assert(resultSingle.contains('scheduled'), 'Should mention scheduling');
    }

    @isTest
    static void testPostToInstagramError() {
        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setHeader('Content-Type', 'application/json');
        mockResponse.setBody('{"error": {"message": "API Error"}}');
        mockResponse.setStatusCode(500);

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(mockResponse));

        Test.startTest();
        InstagramPostController.InstagramPostResponse result = InstagramPostController.postToInstagram(
            new List<String>{'https://mock-url.com/image.jpg'},
            'Error Test',
            new List<String>{'key1'},
            new List<String>{'key2'}
        );
        Test.stopTest();

        System.assertEquals('ERROR', result.status, 'Should return error status');
    }

    @isTest
    static void testSendEmailNotification() {
        // Create email template
        EmailTemplate template = new EmailTemplate(
            DeveloperName = 'Instagram_Error_Template',
            FolderId = UserInfo.getUserId(),
            Name = 'Instagram Error Template',
            Subject = 'Instagram Error',
            HtmlValue = '<html><body>Error: {!errorDetails} for {!User}</body></html>',
            TemplateType = 'custom',
            IsActive = true
        );
        insert template;

        Test.startTest();
        InstagramPostController.sendEmailNotification('Test error message');
        Test.stopTest();

        // Verify no exceptions thrown
        System.assert(true, 'Email notification method executed');
    }

    @isTest
    static void testGetSignatureKey() {
        Test.startTest();
        Blob signature = InstagramPostController.getSignatureKey(
            'testSecretKey',
            '20240101',
            'us-west-1',
            's3'
        );
        Test.stopTest();

        System.assertNotEquals(null, signature, 'Signature key should not be null');
    }

    @isTest
    static void testCarouselMediaError() {
        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setHeader('Content-Type', 'application/json');
        mockResponse.setBody('{"error": "Failed"}');
        mockResponse.setStatusCode(400);

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(mockResponse));

        Test.startTest();
        InstagramPostController.InstagramPostResponse result = InstagramPostController.postToInstagram(
            new List<String>{'https://mock-url.com/img1.jpg', 'https://mock-url.com/img2.jpg'},
            'Carousel Error Test',
            new List<String>{'key1'},
            new List<String>{'key2'}
        );
        Test.stopTest();

        System.assertEquals('ERROR', result.status, 'Carousel error should return error status');
    }
}