/**
 * Class Name : InstagramControllerTest
 * Last Modified Date : 2026-10-12
 * Last Modified By : Dhruv Kakadiya
 * @description : Test class for InstagramController with complete branch coverage and self-contained mocks.
 */
@isTest
private class InstagramControllerTest {

    @isTest
    static void testConstructor() {
        InstagramController controller = new InstagramController();
        System.assertEquals(false, controller.isRecordCreated, 'isRecordCreated should initialize to false');
        System.assertEquals(false, controller.hasError, 'hasError should initialize to false');
        System.assertEquals('', controller.errorMessage, 'errorMessage should initialize to blank');
        System.assertEquals('', controller.longLivedToken, 'longLivedToken should initialize to blank');
        System.assertEquals('', controller.instagramUserId, 'instagramUserId should initialize to blank');
    }

    @isTest
    static void testGetRefreshToken_NoAuthCode() {
        Test.setCurrentPage(new PageReference('/apex/Dummy'));
        // No 'code' parameter passed

        Test.startTest();
        InstagramController controller = new InstagramController();
        PageReference result = controller.getRefreshToken();
        Test.stopTest();

        System.assertEquals(null, result, 'PageReference should be null');
        System.assertEquals(true, controller.hasError, 'hasError should be true when code is missing');
        System.assert(controller.errorMessage.contains('Authorization code not found'), 'Error message should indicate missing authorization code');
    }

    @isTest
    static void testGetRefreshToken_Success() {
        Test.setCurrentPage(new PageReference('/apex/Dummy'));
        ApexPages.currentPage().getParameters().put('code', 'mockAuthCode');

        HttpResponse mockTokenResponse = new HttpResponse();
        mockTokenResponse.setHeader('Content-Type', 'application/json');
        mockTokenResponse.setBody('{"access_token": "short_lived_token", "user_id": 1234567890}');
        mockTokenResponse.setStatusCode(200);

        HttpResponse mockLongTokenResponse = new HttpResponse();
        mockLongTokenResponse.setHeader('Content-Type', 'application/json');
        mockLongTokenResponse.setBody('{"access_token": "long_lived_token"}');
        mockLongTokenResponse.setStatusCode(200);

        HttpResponse mockUserResponse = new HttpResponse();
        mockUserResponse.setHeader('Content-Type', 'application/json');
        mockUserResponse.setBody('{"user_id": "1234567890", "username": "mockUser"}');
        mockUserResponse.setStatusCode(200);

        Test.setMock(HttpCalloutMock.class, new SequentialMock(
            new List<HttpResponse>{
                mockTokenResponse,
                mockLongTokenResponse,
                mockUserResponse
            }
        ));

        Test.startTest();
        InstagramController controller = new InstagramController();
        PageReference result = controller.getRefreshToken();
        Test.stopTest();

        System.assertEquals(null, result, 'PageReference should be null');
    }

    @isTest
    static void testGetRefreshToken_TokenEndpointFails() {
        Test.setCurrentPage(new PageReference('/apex/Dummy'));
        ApexPages.currentPage().getParameters().put('code', 'invalidAuthCode');

        HttpResponse mockErrorResponse = new HttpResponse();
        mockErrorResponse.setHeader('Content-Type', 'application/json');
        mockErrorResponse.setBody('{"error": {"message": "Invalid verification code"}}');
        mockErrorResponse.setStatusCode(400);

        Test.setMock(HttpCalloutMock.class, new SingleMock(mockErrorResponse));

        Test.startTest();
        InstagramController controller = new InstagramController();
        PageReference result = controller.getRefreshToken();
        Test.stopTest();

        System.assertEquals(null, result, 'PageReference should be null');
    }

    @isTest
    static void testGetRefreshToken_GetUserIdFails() {
        Test.setCurrentPage(new PageReference('/apex/Dummy'));
        ApexPages.currentPage().getParameters().put('code', 'mockAuthCode');

        // Response 1: Token success
        HttpResponse mockTokenResponse = new HttpResponse();
        mockTokenResponse.setHeader('Content-Type', 'application/json');
        mockTokenResponse.setBody('{"access_token": "short_lived_token", "user_id": 1234567890}');
        mockTokenResponse.setStatusCode(200);

        // Response 2: Long token success
        HttpResponse mockLongTokenResponse = new HttpResponse();
        mockLongTokenResponse.setHeader('Content-Type', 'application/json');
        mockLongTokenResponse.setBody('{"access_token": "long_lived_token"}');
        mockLongTokenResponse.setStatusCode(200);

        // Response 3: User verification fails (e.g. 400 error)
        HttpResponse mockUserResponse = new HttpResponse();
        mockUserResponse.setHeader('Content-Type', 'application/json');
        mockUserResponse.setBody('{"error": "Unauthorized"}');
        mockUserResponse.setStatusCode(400);

        Test.setMock(HttpCalloutMock.class, new SequentialMock(
            new List<HttpResponse>{
                mockTokenResponse,
                mockLongTokenResponse,
                mockUserResponse
            }
        ));

        Test.startTest();
        InstagramController controller = new InstagramController();
        PageReference result = controller.getRefreshToken();
        Test.stopTest();

        System.assertEquals(null, result, 'PageReference should be null');
    }

    @isTest
    static void testGetRefreshToken_Exception() {
        Test.setCurrentPage(new PageReference('/apex/Dummy'));
        ApexPages.currentPage().getParameters().put('code', 'mockAuthCode');

        Test.setMock(HttpCalloutMock.class, new ThrowingMock());

        Test.startTest();
        InstagramController controller = new InstagramController();
        PageReference result = controller.getRefreshToken();
        Test.stopTest();

        System.assertEquals(null, result, 'PageReference should be null');
        System.assertEquals(true, controller.hasError, 'hasError should be true when exception thrown');
        System.assert(controller.errorMessage.contains('An unexpected error occurred'), 'Should indicate unexpected error');
    }

    @isTest
    static void testGetLongLivedAccessToken_Success() {
        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setStatusCode(200);
        mockResponse.setHeader('Content-Type', 'application/json');
        mockResponse.setBody('{"access_token": "mockLongToken"}');

        Test.setMock(HttpCalloutMock.class, new SingleMock(mockResponse));

        Test.startTest();
        String result = InstagramController.getLongLivedAccessToken('shortToken', 'secret');
        Test.stopTest();

        System.assertEquals('mockLongToken', result, 'Should return parsed long-lived token');
    }

    @isTest
    static void testGetLongLivedAccessToken_Failure() {
        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setStatusCode(400);
        mockResponse.setHeader('Content-Type', 'application/json');
        mockResponse.setBody('{"error": {"message": "Invalid token"}}');

        Test.setMock(HttpCalloutMock.class, new SingleMock(mockResponse));

        Test.startTest();
        String result = InstagramController.getLongLivedAccessToken('shortToken', 'secret');
        Test.stopTest();

        System.assertEquals(null, result, 'Should return null on non-200 status code');
    }

    @isTest
    static void testGetLongLivedAccessToken_Exception() {
        Test.setMock(HttpCalloutMock.class, new ThrowingMock());

        Test.startTest();
        String result = InstagramController.getLongLivedAccessToken('shortToken', 'secret');
        Test.stopTest();

        System.assertEquals(null, result, 'Should return null on exception');
    }

    @isTest
    static void testGetUserId_Success() {
        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setStatusCode(200);
        mockResponse.setHeader('Content-Type', 'application/json');
        mockResponse.setBody('{"user_id": "mockUserId", "username": "mockUser"}');

        Test.setMock(HttpCalloutMock.class, new SingleMock(mockResponse));

        Test.startTest();
        Boolean result = InstagramController.getUserId('access_token', 'long_token');
        Test.stopTest();

        System.assertEquals(true, result, 'Should return true if userId is parsed');
    }

    @isTest
    static void testGetUserId_Failure() {
        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setStatusCode(400);
        mockResponse.setHeader('Content-Type', 'application/json');
        mockResponse.setBody('{"error": {"message": "Invalid request"}}');

        Test.setMock(HttpCalloutMock.class, new SingleMock(mockResponse));

        Test.startTest();
        Boolean result = InstagramController.getUserId('access_token', 'long_token');
        Test.stopTest();

        System.assertEquals(false, result, 'Should return false on non-200 response');
    }

    @isTest
    static void testGetUserId_Exception() {
        Test.setMock(HttpCalloutMock.class, new ThrowingMock());

        Test.startTest();
        Boolean result = InstagramController.getUserId('access_token', 'long_token');
        Test.stopTest();

        System.assertEquals(false, result, 'Should return false on exception');
    }

    // --- Mock Generators ---

    private class SequentialMock implements HttpCalloutMock {
        private List<HttpResponse> responses;
        private Integer index = 0;

        public SequentialMock(List<HttpResponse> responses) {
            this.responses = responses;
        }

        public HttpResponse respond(HttpRequest req) {
            if (index < responses.size()) {
                return responses[index++];
            }
            HttpResponse fallbackRes = new HttpResponse();
            fallbackRes.setStatusCode(500);
            fallbackRes.setBody('Unexpected callout');
            return fallbackRes;
        }
    }

    private class SingleMock implements HttpCalloutMock {
        private HttpResponse response;

        public SingleMock(HttpResponse response) {
            this.response = response;
        }

        public HttpResponse respond(HttpRequest req) {
            return this.response;
        }
    }

    private class ThrowingMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            throw new CalloutException('Simulated network callout exception');
        }
    }
}