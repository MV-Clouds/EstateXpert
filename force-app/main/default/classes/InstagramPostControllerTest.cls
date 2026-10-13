@isTest
private class InstagramPostControllerTest {
    private static final String AWS_ENDPOINT = 'test-bucket.s3.amazonaws.com';
    private static Integer callCount = 0;
    private static HttpRequest lastRequest;

    @testSetup
    static void setup() {
        insert new MVEX__AWS_Config__c(
            MVEX__AWS_Access_Key__c = 'mock_access_key',
            MVEX__AWS_Secret_Access_Key__c = 'mock_secret_key',
            MVEX__S3_Region_Name__c = 'us-east-1',
            MVEX__S3_Bucket_Name__c = 'test-bucket'
        );

        MVEX__Property__c propertyRecord = TestDataFactory.createProperty(true);
        MVEX__Listing__c listingRecord = TestDataFactory.createListing(true, propertyRecord.Id, null);

        MVEX__Property_File__c externalImage = TestDataFactory.createPropertyFile(true, propertyRecord.Id);
        externalImage.Name = 'External Image';
        externalImage.MVEX__BaseUrl__c = 'https://example.com/base-image.jpg';
        externalImage.MVEX__ExternalLink__c = 'https://example.com/external-image.jpg';
        externalImage.MVEX__Size__c = 100;
        update externalImage;

        MVEX__Property_File__c baseVideo = TestDataFactory.createPropertyFile(true, propertyRecord.Id);
        baseVideo.Name = 'Base Video';
        baseVideo.MVEX__BaseUrl__c = 'https://example.com/video.mp4';
        baseVideo.MVEX__Size__c = 200;
        update baseVideo;

        MVEX__Property_File__c noSizeImage = TestDataFactory.createPropertyFile(true, propertyRecord.Id);
        noSizeImage.Name = 'No Size Image';
        noSizeImage.MVEX__BaseUrl__c = 'https://example.com/ignored.jpg';
        noSizeImage.MVEX__Size__c = null;
        update noSizeImage;
    }

    private static OAuth_Configuration__mdt connectedInstagramConfig() {
        return new OAuth_Configuration__mdt(
            User_Id__c = '1234567890',
            Access_Token__c = 'mock_access_token',
            API_Version__c = '24.0',
            Base_URL__c = 'https://graph.instagram.com'
        );
    }

    @isTest
    static void generateAwsHeadersAndSignatureKey() {
        Map<String, String> headers = InstagramPostController.generateAWSHeaders(
            '<Delete/>',
            'base64-md5',
            'access-key',
            'secret-key',
            'us-east-1',
            'test-bucket'
        );
        Blob signatureKey = InstagramPostController.getSignatureKey(
            'secret-key',
            '20260101',
            'us-east-1',
            's3'
        );

        System.assertNotEquals(null, headers);
        System.assert(headers.get('Authorization').startsWith('AWS4-HMAC-SHA256 Credential=access-key/'));
        System.assertEquals('base64-md5', headers.get('Content-MD5'));
        System.assertEquals('UNSIGNED-PAYLOAD', headers.get('x-amz-content-sha256'));
        System.assertNotEquals(null, signatureKey);
        System.assertEquals(32, signatureKey.size());
    }

    @isTest
    static void deleteAwsImagesSkipsEmptyAndPreservedKeys() {
        callCount = 0;
        Test.setMock(HttpCalloutMock.class, new RecordingHttpMock(200, ''));

        Test.startTest();
        InstagramPostController.deleteAwsImages(null, null);
        InstagramPostController.deleteAwsImages(new List<String>(), new List<String>());
        InstagramPostController.deleteAwsImages(
            new List<String>{ 'keep.jpg' },
            new List<String>{ 'keep.jpg' }
        );
        InstagramPostController.deleteAwsImages(new List<String>{ 'remove.jpg' }, null);
        InstagramPostController.deleteAwsImages(new List<String>{ 'another.jpg' }, null);
        Test.stopTest();

        System.assertEquals(2, callCount);
    }

    @isTest
    static void deleteAwsImagesSendsOnlyUnpreservedKeysAndHandlesFailure() {
        callCount = 0;
        lastRequest = null;
        Test.setMock(HttpCalloutMock.class, new RecordingHttpMock(200, '', 400, '<Error/>'));

        Test.startTest();
        InstagramPostController.deleteAwsImages(
            new List<String>{ 'remove.jpg', 'keep.jpg' },
            new List<String>{ 'keep.jpg' }
        );
        System.assert(lastRequest.getBody().contains('<Key>remove.jpg</Key>'));
        System.assertEquals(false, lastRequest.getBody().contains('<Key>keep.jpg</Key>'));
        InstagramPostController.deleteAwsImages(new List<String>{ 'second-remove.jpg' }, null);
        Test.stopTest();

        System.assertEquals(2, callCount);
        System.assert(lastRequest.getEndpoint().contains(AWS_ENDPOINT));
        System.assert(lastRequest.getBody().contains('<Key>second-remove.jpg</Key>'));
    }

    @isTest
    static void getPropertyMediaUrlsReturnsExternalAndBaseUrls() {
        MVEX__Listing__c listing = [SELECT Id FROM MVEX__Listing__c LIMIT 1];

        Map<String, String> urls = InstagramPostController.getPropertyMediaUrls(listing.Id);
        Map<String, String> missingListingUrls = InstagramPostController.getPropertyMediaUrls(null);

        System.assertEquals(2, urls.size());
        System.assertEquals('https://example.com/external-image.jpg', urls.get('External Image'));
        System.assertEquals('https://example.com/video.mp4', urls.get('Base Video'));
        System.assertEquals(0, missingListingUrls.size());
    }

    @isTest
    static void checkInstagramIntegrationUsesConfiguredCredentials() {
        InstagramPostController.mockConfig = null;
        System.assertEquals(true, InstagramPostController.checkInstagramIntegration());

        InstagramPostController.mockConfig = new OAuth_Configuration__mdt(
            User_Id__c = '1234567890',
            Access_Token__c = 'mock_access_token'
        );
        System.assertEquals(true, InstagramPostController.checkInstagramIntegration());

        InstagramPostController.mockConfig = new OAuth_Configuration__mdt(User_Id__c = '1234567890');
        System.assertEquals(false, InstagramPostController.checkInstagramIntegration());

        InstagramPostController.mockConfig = new OAuth_Configuration__mdt(Access_Token__c = 'mock_access_token');
        System.assertEquals(false, InstagramPostController.checkInstagramIntegration());
        InstagramPostController.mockConfig = null;
    }

    @isTest
    static void postToInstagramPostsSingleImage() {
        callCount = 0;
        Test.setMock(HttpCalloutMock.class, new RecordingHttpMock(200, '{"id":"container-image"}'));
        InstagramPostController.mockConfig = null;

        Test.startTest();
        InstagramPostController.InstagramPostResponse imageResponse = InstagramPostController.postToInstagram(
            new List<String>{ 'https://example.com/image.jpg?size=large' },
            'Image caption',
            new List<String>(),
            new List<String>()
        );
        Test.stopTest();

        System.assertEquals('SUCCESS', imageResponse.status);
        System.assertEquals(1, callCount);
    }

    @isTest
    static void postToInstagramPostsSingleReel() {
        callCount = 0;
        Test.setMock(HttpCalloutMock.class, new RecordingHttpMock(200, '{"id":"container-reel"}'));
        InstagramPostController.mockConfig = null;

        Test.startTest();
        InstagramPostController.InstagramPostResponse reelResponse = InstagramPostController.postToInstagram(
            new List<String>{ 'https://example.com/video.MOV?size=large' },
            'Reel caption',
            new List<String>(),
            new List<String>()
        );
        Test.stopTest();

        System.assertEquals('SUCCESS', reelResponse.status);
        System.assertEquals(1, callCount);
        System.assert(lastRequest.getBody().contains('"media_type":"REELS"'));
        System.assert(lastRequest.getBody().contains('"video_url":"https://example.com/video.MOV?size=large"'));
    }

    @isTest
    static void postToInstagramPostsCarouselOfImagesAndVideo() {
        callCount = 0;
        Test.setMock(HttpCalloutMock.class, new RecordingHttpMock(200, '{"id":"container-2"}'));
        InstagramPostController.mockConfig = connectedInstagramConfig();

        Test.startTest();
        InstagramPostController.InstagramPostResponse postResponse = InstagramPostController.postToInstagram(
            new List<String>{ 'https://example.com/image.jpg', 'https://example.com/video.mp4' },
            'Carousel caption',
            new List<String>(),
            new List<String>()
        );
        Test.stopTest();

        System.assertEquals('SUCCESS', postResponse.status);
        System.assertEquals('Media container created. Publishing scheduled.', postResponse.message);
        System.assertEquals(2, callCount);
        System.assert(lastRequest.getBody().contains('"is_carousel_item":true'));
        System.assert(lastRequest.getBody().contains('"video_url":"https://example.com/video.mp4"'));
        InstagramPostController.mockConfig = null;
    }

    @isTest
    static void postToInstagramHandlesDisconnectedAccountAndInputErrors() {
        callCount = 0;
        InstagramPostController.mockConfig = new OAuth_Configuration__mdt();
        Test.setMock(HttpCalloutMock.class, new RecordingHttpMock(200, ''));

        Test.startTest();
        InstagramPostController.InstagramPostResponse disconnectedResponse = InstagramPostController.postToInstagram(
            new List<String>{ 'https://example.com/image.jpg' },
            'Caption',
            new List<String>(),
            new List<String>()
        );
        InstagramPostController.mockConfig = connectedInstagramConfig();
        InstagramPostController.InstagramPostResponse nullMediaResponse = InstagramPostController.postToInstagram(
            null,
            'Caption',
            new List<String>(),
            new List<String>()
        );
        Test.stopTest();

        System.assertEquals('ERROR', disconnectedResponse.status);
        System.assert(disconnectedResponse.message.contains('Instagram is not connected'));
        System.assertEquals('ERROR', nullMediaResponse.status);
        System.assert(nullMediaResponse.message.startsWith('Exception:'));
        System.assertEquals(0, callCount);
        InstagramPostController.mockConfig = null;
    }

    @isTest
    static void postToInstagramParsesSingleError() {
        callCount = 0;
        Test.setMock(HttpCalloutMock.class, new RecordingHttpMock(400, '{"error":{"message":"Invalid access token"}}'));
        InstagramPostController.mockConfig = null;

        Test.startTest();
        InstagramPostController.InstagramPostResponse imageError = InstagramPostController.postToInstagram(
            new List<String>{ 'https://example.com/image.jpg' },
            'Caption',
            new List<String>(),
            new List<String>()
        );
        Test.stopTest();

        System.assertEquals('ERROR', imageError.status);
        System.assert(imageError.message.contains('Invalid access token'));

        InstagramPostController.mockConfig = null;
    }

    @isTest
    static void postToInstagramParsesCarouselError() {
        callCount = 0;
        Test.setMock(HttpCalloutMock.class, new RecordingHttpMock(200, '{"id":"child-1"}', 400, '{"error":{"message":"Carousel child failed"}}'));
        Test.startTest();
        InstagramPostController.InstagramPostResponse carouselError = InstagramPostController.postToInstagram(
            new List<String>{ 'https://example.com/image1.jpg', 'https://example.com/image2.jpg' },
            'Caption',
            new List<String>(),
            new List<String>()
        );
        Test.stopTest();

        System.assertEquals('ERROR', carouselError.status);
        System.assert(carouselError.message.contains('Carousel child failed'));
        InstagramPostController.mockConfig = null;
    }

    @isTest
    static void postToInstagramHandlesNonJsonInstagramErrors() {
        callCount = 0;
        Test.setMock(HttpCalloutMock.class, new RecordingHttpMock(400, 'Instagram unavailable'));
        InstagramPostController.mockConfig = null;

        Test.startTest();
        InstagramPostController.InstagramPostResponse postResponse = InstagramPostController.postToInstagram(
            new List<String>{ 'https://example.com/image.jpg' },
            'Caption',
            new List<String>(),
            new List<String>()
        );
        Test.stopTest();

        System.assertEquals('ERROR', postResponse.status);
        System.assert(postResponse.message.contains('Instagram unavailable'));
        InstagramPostController.mockConfig = null;
    }

    @isTest
    static void sendEmailNotificationHandlesMissingTemplate() {
        Test.startTest();
        InstagramPostController.sendEmailNotification('Instagram test error');
        Test.stopTest();
        System.assert(Limits.getEmailInvocations() <= 1);
    }

    private class RecordingHttpMock implements HttpCalloutMock {
        private Integer statusCode;
        private String body;
        private Integer secondStatusCode;
        private String secondBody;

        RecordingHttpMock(Integer statusCode, String body) {
            this(statusCode, body, statusCode, body);
        }

        RecordingHttpMock(Integer statusCode, String body, Integer secondStatusCode, String secondBody) {
            this.statusCode = statusCode;
            this.body = body;
            this.secondStatusCode = secondStatusCode;
            this.secondBody = secondBody;
        }

        public HttpResponse respond(HttpRequest request) {
            InstagramPostControllerTest.callCount++;
            InstagramPostControllerTest.lastRequest = request;
            Integer responseStatus = InstagramPostControllerTest.callCount == 2 ? secondStatusCode : statusCode;
            String responseBody = InstagramPostControllerTest.callCount == 2 ? secondBody : body;
            HttpResponse response = new HttpResponse();
            response.setStatusCode(responseStatus);
            response.setBody(responseBody);
            return response;
        }
    }
}
