@isTest
public with sharing class InstagramPostControllerTest {

    @testSetup
    static void setupTestData() {
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
}