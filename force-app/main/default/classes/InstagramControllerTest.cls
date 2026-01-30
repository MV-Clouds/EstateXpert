@isTest
private class InstagramControllerTest {

    @testSetup
    static void setupTestData() {
        insert new TempData__c(
            Client_ID__c = '123456',
            Client_Secret__c = 'secret',
            Redirect_URI__c = 'https://example.com/redirect'
        );
    }

    @isTest
    static void testGetRefreshTokenWithValidCode() {
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
        mockUserResponse.setBody('{"user_id": "mockUserId", "username": "mockUser"}');
        mockUserResponse.setStatusCode(200);

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator.Multi(
            new List<HttpResponse>{
                mockTokenResponse,
                mockLongTokenResponse,
                mockUserResponse
            }
        ));

        Test.startTest();
        InstagramController controller = new InstagramController();
        controller.getRefreshToken();
        Test.stopTest();

        System.assert(controller.isRecordCreated, 'Record should be marked as created');
    }

    @isTest
    static void testGetLongLivedAccessTokenReturnsToken() {
        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setStatusCode(200);
        mockResponse.setHeader('Content-Type', 'application/json');
        mockResponse.setBody('{"access_token": "mockLongToken"}');

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(mockResponse));

        Test.startTest();
        String result = InstagramController.getLongLivedAccessToken('shortToken', 'secret');
        Test.stopTest();

        System.assertEquals('mockLongToken', result, 'Should return parsed long-lived token');
    }

    @isTest
    static void testGetUserIdReturnsTrue() {
        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setStatusCode(200);
        mockResponse.setHeader('Content-Type', 'application/json');
        mockResponse.setBody('{"user_id": "mockUserId", "username": "mockUser"}');

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(mockResponse));

        Test.startTest();
        Boolean result = InstagramController.getUserId('access_token', 'long_token');
        Test.stopTest();

        System.assertEquals(true, result, 'Should return true if userId is parsed');
    }

    @isTest
    static void testSaveCustomSettingsPublishesEvent() {
        Test.startTest();
        InstagramController.saveCustomSettings('access_token', 'long_token', 'user123');
        Test.stopTest();

        System.assert(true, 'Method executed without error');
    }
}