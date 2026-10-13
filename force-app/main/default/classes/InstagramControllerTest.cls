/**
 * Class Name : InstagramControllerTest
 * Last Modified Date : 2026-10-12
 * Last Modified By : Dhruv Kakadiya
 * @description : Test class for InstagramController with complete branch coverage and self-contained mocks.
 */
@isTest
private class InstagramControllerTest {
    private static final String TOKEN_ENDPOINT = 'https://instagram.example.com/oauth/access_token';
    private static final String GRAPH_BASE_URL = 'https://graph.instagram.example.com';

    private static OAuth_Configuration__mdt configuredInstagramOAuth() {
        return new OAuth_Configuration__mdt(
            Client_Id__c = 'test-client-id',
            Client_Secret__c = 'test-client-secret',
            Redirect_URI__c = 'https://salesforce.example.com/callback',
            Token_Endpoint__c = TOKEN_ENDPOINT,
            API_Version__c = '24.0',
            Base_URL__c = GRAPH_BASE_URL
        );
    }

    private static HttpResponse response(Integer statusCode, String body) {
        HttpResponse result = new HttpResponse();
        result.setStatusCode(statusCode);
        result.setHeader('Content-Type', 'application/json');
        result.setBody(body);
        return result;
    }

    @isTest
    static void constructorInitializesState() {
        InstagramController controller = new InstagramController();

        System.assertEquals(false, controller.isRecordCreated);
        System.assertEquals(false, controller.hasError);
        System.assertEquals('', controller.errorMessage);
        System.assertEquals('', controller.longLivedToken);
        System.assertEquals('', controller.instagramUserId);
    }

    @isTest
    static void getRefreshTokenRejectsMissingCode() {
        Test.setCurrentPage(new PageReference('/apex/InstagramCallback'));
        InstagramController controller = new InstagramController();

        Test.startTest();
        controller.getRefreshToken();
        Test.stopTest();

        System.assertEquals(true, controller.hasError);
        System.assertEquals('Authorization code not found. The authentication token has expired or is invalid.',controller.errorMessage);
        System.assertEquals(1, ApexPages.getMessages().size());
    }

    @isTest
    static void getRefreshTokenRejectsIncompleteOAuthConfiguration() {
        Test.setCurrentPage(new PageReference('/apex/InstagramCallback'));
        ApexPages.currentPage().getParameters().put('code', 'auth-code');
        InstagramController.testInstagramConfiguration = new OAuth_Configuration__mdt();
        InstagramController controller = new InstagramController();

        Test.startTest();
        controller.getRefreshToken();
        Test.stopTest();

        System.assertEquals(true, controller.hasError);
        System.assertEquals('Instagram Credentials configuration missing in Custom Metadata.', controller.errorMessage);
        System.assertEquals(false, controller.isRecordCreated);
    }

    @isTest
    static void getRefreshTokenHandlesTokenEndpointFailure() {
        Test.setCurrentPage(new PageReference('/apex/InstagramCallback'));
        ApexPages.currentPage().getParameters().put('code', 'auth-code');
        InstagramController.testInstagramConfiguration = configuredInstagramOAuth();
        Test.setMock(HttpCalloutMock.class, new StaticResponseMock(400, '{"error":"invalid_grant"}'));
        InstagramController controller = new InstagramController();

        Test.startTest();
        controller.getRefreshToken();
        Test.stopTest();

        System.assertEquals(true, controller.hasError);
        System.assertEquals('Failed to get access token. Please verify your credentials.', controller.errorMessage);
        System.assertEquals(1, ApexPages.getMessages().size());
    }

    @isTest
    static void getRefreshTokenCompletesOAuthFlow() {
        Test.setCurrentPage(new PageReference('/apex/InstagramCallback'));
        ApexPages.currentPage().getParameters().put('code', 'auth code');
        InstagramController.testInstagramConfiguration = configuredInstagramOAuth();
        Test.setMock(HttpCalloutMock.class, new OAuthFlowMock(true));
        InstagramController controller = new InstagramController();

        Test.startTest();
        controller.getRefreshToken();
        Test.stopTest();

        System.assertEquals(true, controller.isRecordCreated);
        System.assertEquals(false, controller.hasError);
        System.assertEquals('long-lived-token', controller.longLivedToken);
        System.assertEquals('1234567890', controller.instagramUserId);
    }

    @isTest
    static void getRefreshTokenReportsUserLookupFailure() {
        Test.setCurrentPage(new PageReference('/apex/InstagramCallback'));
        ApexPages.currentPage().getParameters().put('code', 'auth-code');
        InstagramController.testInstagramConfiguration = configuredInstagramOAuth();
        Test.setMock(HttpCalloutMock.class, new OAuthFlowMock(false));
        InstagramController controller = new InstagramController();

        Test.startTest();
        controller.getRefreshToken();
        Test.stopTest();

        System.assertEquals(false, controller.isRecordCreated);
        System.assertEquals(true, controller.hasError);
        System.assertEquals('Failed to retrieve user information.', controller.errorMessage);
    }

    @isTest
    static void getLongLivedAccessTokenReturnsTokenOrNullOnFailure() {
        Test.setMock(HttpCalloutMock.class, new StaticResponseMock(200, '{"access_token":"long-token"}'));
        System.assertEquals('long-token', InstagramController.getLongLivedAccessToken('short-token', 'secret'));

        Test.setMock(HttpCalloutMock.class, new StaticResponseMock(400, '{"error":"invalid_token"}'));
        System.assertEquals(null, InstagramController.getLongLivedAccessToken('short-token', 'secret'));

        Test.setMock(HttpCalloutMock.class, new StaticResponseMock(200, 'not-json'));
        System.assertEquals(null, InstagramController.getLongLivedAccessToken('short-token', 'secret'));
    }

    @isTest
    static void getUserIdReturnsFalseForFailures() {
        InstagramController.testInstagramConfiguration = configuredInstagramOAuth();
        Test.setMock(HttpCalloutMock.class, new StaticResponseMock(401, '{"error":"invalid_token"}'));
        System.assertEquals(false, InstagramController.getUserId('short-token', 'long-token'));

        Test.setMock(HttpCalloutMock.class, new StaticResponseMock(200, 'not-json'));
        System.assertEquals(false, InstagramController.getUserId('short-token', 'long-token'));
    }

    private class StaticResponseMock implements HttpCalloutMock {
        private Integer statusCode;
        private String body;

        StaticResponseMock(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body = body;
        }

        public HttpResponse respond(HttpRequest request) {
            return response(statusCode, body);
        }
    }

    private class OAuthFlowMock implements HttpCalloutMock {
        private Boolean userLookupSucceeds;
        private Integer requestCount = 0;

        OAuthFlowMock(Boolean userLookupSucceeds) {
            this.userLookupSucceeds = userLookupSucceeds;
        }

        public HttpResponse respond(HttpRequest request) {
            requestCount++;
            if (request.getEndpoint().contains('ig_exchange_token')) {
                return response(200, '{"access_token":"long-lived-token"}');
            }
            if (request.getEndpoint().contains('/me?fields=user_id,username')) {
                return userLookupSucceeds ? response(200, '{"user_id":"1234567890","username":"test_user"}') : response(401, '{"error":{"message":"Unauthorized"}}');
            }
            return response(200, '{"access_token":"short-lived-token","user_id":1234567890}');
        }
    }
}
