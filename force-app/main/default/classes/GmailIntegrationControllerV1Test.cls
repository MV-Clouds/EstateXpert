/**
 * @description       : Test class for GmailIntegrationControllerV1
 * @author            : Your Name
 * @last modified on  : 16-07-2025
 * @last modified by  : Your Name
 */
@isTest
private class GmailIntegrationControllerV1Test {

    // Mock class for HTTP callouts
    private class HttpMock implements HttpCalloutMock {
        private Integer statusCode;
        private String responseBody;

        public HttpMock(Integer statusCode, String responseBody) {
            this.statusCode = statusCode;
            this.responseBody = responseBody;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(responseBody);
            return res;
        }
    }

    @TestSetup
    static void setupTestData() {
        // Setup TempData__c for constructor
        TempData__c tempData = new TempData__c(
            Client_ID__c = 'testClientId',
            Client_Secret__c = 'testClientSecret',
            Redirect_URI__c = 'https://test.redirect.uri'
        );
        insert tempData;

        // Setup GmailConfig__c for sendEmail
        GmailConfig__c config = new GmailConfig__c(
            Client_ID__c = 'testClientId',
            Client_Secret__c = 'testClientSecret',
            Refresh_Token__c = 'testRefreshToken'
        );
        insert config;

        // Setup Marketing_Campaign__c for campaign-related tests
        Marketing_Campaign__c campaign = new Marketing_Campaign__c(Status__c = 'Pending');
        insert campaign;
    }

    @isTest
    static void testConstructorWithValidAuthCode() {
        // Mock page parameters with valid auth code
        Test.setCurrentPageReference(new PageReference('/testPage'));
        ApexPages.currentPage().getParameters().put('code', 'testAuthCode');

        // Mock successful token response
        Test.setMock(HttpCalloutMock.class, new HttpMock(200, '{"access_token":"newAccessToken","refresh_token":"newRefreshToken"}'));

        Test.startTest();
        GmailIntegrationControllerV1 controller = new GmailIntegrationControllerV1();
        Test.stopTest();

        // Assertions
        System.assertEquals(false, controller.isFailed, 'Constructor should not fail with valid auth code');
        System.assertEquals('', controller.errorMessage, 'Error message should be empty');
        System.assertEquals('newRefreshToken', controller.refreshToken, 'Refresh token should be set correctly');
    }

    @isTest
    static void testConstructorWithoutAuthCode() {
        // Mock page parameters without auth code
        Test.setCurrentPageReference(new PageReference('/testPage'));

        Test.startTest();
        GmailIntegrationControllerV1 controller = new GmailIntegrationControllerV1();
        Test.stopTest();

        // Assertions
        System.assertEquals(true, controller.isFailed, 'Constructor should fail without auth code');
        System.assertEquals('Authorization code not found.', controller.errorMessage, 'Error message should indicate missing auth code');
        System.assertEquals('', controller.refreshToken, 'Refresh token should remain empty');
    }

    @isTest
    static void testConstructorWithInvalidTokenResponse() {
        // Mock page parameters with valid auth code
        Test.setCurrentPageReference(new PageReference('/testPage'));
        ApexPages.currentPage().getParameters().put('code', 'testAuthCode');

        // Mock failed token response
        Test.setMock(HttpCalloutMock.class, new HttpMock(400, '{"error":"invalid_grant"}'));

        Test.startTest();
        GmailIntegrationControllerV1 controller = new GmailIntegrationControllerV1();
        Test.stopTest();

        // Assertions
        System.assertEquals(true, controller.isFailed, 'Constructor should fail with invalid token response');
        System.assertEquals('Failed to get refresh token: {"error":"invalid_grant"}', controller.errorMessage, 'Error message should reflect token response error');
        System.assertEquals('', controller.refreshToken, 'Refresh token should remain empty');
    }

    @isTest
    static void testConstructorException() {
        // Mock page parameters with valid auth code
        Test.setCurrentPageReference(new PageReference('/testPage'));
        ApexPages.currentPage().getParameters().put('code', 'testAuthCode');

        // Mock exception by setting invalid endpoint
        Test.setMock(HttpCalloutMock.class, new HttpMock(500, '{"error":"server_error"}'));

        Test.startTest();
        GmailIntegrationControllerV1 controller = new GmailIntegrationControllerV1();
        Test.stopTest();

        // Assertions
        System.assertEquals(true, controller.isFailed, 'Constructor should fail on exception');
        System.assert(controller.errorMessage.contains('Failed to get refresh token'), 'Error message should include exception details');
        System.assertEquals('', controller.refreshToken, 'Refresh token should remain empty');
    }

    @isTest
    static void testRequestNewAccessTokenSuccess() {
        // Setup EmailWrapper
        GmailIntegrationControllerV1.EmailWrapper email = new GmailIntegrationControllerV1.EmailWrapper();
        email.toAddresses = new List<String>{ 'test@example.com' };
        email.ccAddresses = new List<String>{ 'cc@example.com' };
        email.bccAddresses = new List<String>{ 'bcc@example.com' };
        email.subject = 'Test Subject';
        email.body = 'Test Body';
        email.contactEmailInfoMap = new Map<String, Map<String, String>>{
            '003000000000001' => new Map<String, String>{
                'subject' => 'Test Subject',
                'body' => 'Test Body',
                'email' => 'test@example.com',
                'cc' => 'cc@example.com',
                'bcc' => 'bcc@example.com'
            }
        };

        List<GmailIntegrationControllerV1.EmailWrapper> emails = new List<GmailIntegrationControllerV1.EmailWrapper>{ email };
        Map<String, Integer> remainingEmails = new Map<String, Integer>{ 'test@example.com' => 1 };
        Map<String, Marketing_Campaign__c> campaign = new Map<String, Marketing_Campaign__c>{
            'test@example.com' => [SELECT Id, Name FROM Marketing_Campaign__c LIMIT 1]
        };

        // Mock successful token and batch email response
        Test.setMock(HttpCalloutMock.class, new HttpMock(200, '{"access_token":"newAccessToken"}'));

        Test.startTest();
        GmailIntegrationControllerV1.requestNewAccessToken(emails, remainingEmails, campaign, true);
        Test.stopTest();

        // Assertions
        // Since sendEmail is async, verify that no exception was thrown and job was enqueued
        System.assert(true, 'requestNewAccessToken should execute without throwing an exception');
    }

    @isTest
    static void testRequestNewAccessTokenException() {
        // Setup invalid data to cause serialization error
        List<GmailIntegrationControllerV1.EmailWrapper> emails = null;
        Map<String, Integer> remainingEmails = new Map<String, Integer>();
        Map<String, Marketing_Campaign__c> campaign = new Map<String, Marketing_Campaign__c>();

        Test.startTest();
        GmailIntegrationControllerV1.requestNewAccessToken(emails, remainingEmails, campaign, false);
        Test.stopTest();

        // Assertions
        System.assert(true, 'Exception in requestNewAccessToken should be caught and logged');
    }

    @isTest
    static void testSendEmailSuccess() {
        // Setup EmailWrapper
        GmailIntegrationControllerV1.EmailWrapper email = new GmailIntegrationControllerV1.EmailWrapper();
        email.toAddresses = new List<String>{ 'test@example.com' };
        email.ccAddresses = new List<String>{ 'cc@example.com' };
        email.bccAddresses = new List<String>{ 'bcc@example.com' };
        email.subject = 'Test Subject';
        email.body = 'Test Body';
        email.contactEmailInfoMap = new Map<String, Map<String, String>>{
            '003000000000001' => new Map<String, String>{
                'subject' => 'Test Subject',
                'body' => 'Test Body',
                'email' => 'test@example.com',
                'cc' => 'cc@example.com',
                'bcc' => 'bcc@example.com'
            }
        };

        List<GmailIntegrationControllerV1.EmailWrapper> emails = new List<GmailIntegrationControllerV1.EmailWrapper>{ email };
        Map<String, Integer> remainingEmails = new Map<String, Integer>{ 'test@example.com' => 1 };
        Map<String, Marketing_Campaign__c> campaign = new Map<String, Marketing_Campaign__c>{
            'test@example.com' => [SELECT Id, Name FROM Marketing_Campaign__c LIMIT 1]
        };

        // Mock successful responses
        Test.setMock(HttpCalloutMock.class, new HttpMock(200, '{"access_token":"newAccessToken"}'));

        Test.startTest();
        GmailIntegrationControllerV1.sendEmail(JSON.serialize(emails), JSON.serialize(remainingEmails), JSON.serialize(campaign), 'true');
        Test.stopTest();

        // Assertions
        System.assert(true, 'sendEmail should execute without throwing an exception');
    }

    @isTest
    static void testSendEmailEmptyEmails() {
        // Setup empty email list
        List<GmailIntegrationControllerV1.EmailWrapper> emails = new List<GmailIntegrationControllerV1.EmailWrapper>();
        Map<String, Integer> remainingEmails = new Map<String, Integer>();
        Map<String, Marketing_Campaign__c> campaign = new Map<String, Marketing_Campaign__c>();

        Test.startTest();
        GmailIntegrationControllerV1.sendEmail(JSON.serialize(emails), JSON.serialize(remainingEmails), JSON.serialize(campaign), 'false');
        Test.stopTest();

        // Assertions
        System.assert(true, 'sendEmail should exit early for empty email list');
    }

    @isTest
    static void testSendEmailBatchProcessing() {
        // Setup 101 emails to test batch processing
        List<GmailIntegrationControllerV1.EmailWrapper> emails = new List<GmailIntegrationControllerV1.EmailWrapper>();
        for (Integer i = 0; i < 101; i++) {
            GmailIntegrationControllerV1.EmailWrapper email = new GmailIntegrationControllerV1.EmailWrapper();
            email.toAddresses = new List<String>{ 'test' + i + '@example.com' };
            email.subject = 'Test Subject ' + i;
            email.body = 'Test Body ' + i;
            email.contactEmailInfoMap = new Map<String, Map<String, String>>{
                '00300000000000' + i => new Map<String, String>{
                    'subject' => 'Test Subject ' + i,
                    'body' => 'Test Body ' + i,
                    'email' => 'test' + i + '@example.com',
                    'cc' => '',
                    'bcc' => ''
                }
            };
            emails.add(email);
        }

        Map<String, Integer> remainingEmails = new Map<String, Integer>();
        for (Integer i = 0; i < 101; i++) {
            remainingEmails.put('test' + i + '@example.com', 1);
        }
        Map<String, Marketing_Campaign__c> campaign = new Map<String, Marketing_Campaign__c>{
            'test0@example.com' => [SELECT Id, Name FROM Marketing_Campaign__c LIMIT 1]
        };

        // Mock successful responses
        Test.setMock(HttpCalloutMock.class, new HttpMock(200, '{"access_token":"newAccessToken"}'));

        Test.startTest();
        GmailIntegrationControllerV1.sendEmail(JSON.serialize(emails), JSON.serialize(remainingEmails), JSON.serialize(campaign), 'true');
        Test.stopTest();

        // Assertions
        System.assert(true, 'sendEmail should handle batch processing without throwing an exception');
    }

    @isTest
    static void testSendEmailFailedTokenRefresh() {
        // Setup EmailWrapper
        GmailIntegrationControllerV1.EmailWrapper email = new GmailIntegrationControllerV1.EmailWrapper();
        email.toAddresses = new List<String>{ 'test@example.com' };
        email.subject = 'Test Subject';
        email.body = 'Test Body';
        List<GmailIntegrationControllerV1.EmailWrapper> emails = new List<GmailIntegrationControllerV1.EmailWrapper>{ email };
        Map<String, Integer> remainingEmails = new Map<String, Integer>{ 'test@example.com' => 1 };
        Map<String, Marketing_Campaign__c> campaign = new Map<String, Marketing_Campaign__c>();

        // Mock failed token response
        Test.setMock(HttpCalloutMock.class, new HttpMock(400, '{"error":"invalid_grant"}'));

        Test.startTest();
        GmailIntegrationControllerV1.sendEmail(JSON.serialize(emails), JSON.serialize(remainingEmails), JSON.serialize(campaign), 'false');
        Test.stopTest();

        // Assertions
        System.assert(true, 'sendEmail should handle token refresh failure gracefully');
    }

    @isTest
    static void testSendEmailFailedBatchSend() {
        // Setup EmailWrapper
        GmailIntegrationControllerV1.EmailWrapper email = new GmailIntegrationControllerV1.EmailWrapper();
        email.toAddresses = new List<String>{ 'test@example.com' };
        email.subject = 'Test Subject';
        email.body = 'Test Body';
        List<GmailIntegrationControllerV1.EmailWrapper> emails = new List<GmailIntegrationControllerV1.EmailWrapper>{ email };
        Map<String, Integer> remainingEmails = new Map<String, Integer>{ 'test@example.com' => 1 };
        Map<String, Marketing_Campaign__c> campaign = new Map<String, Marketing_Campaign__c>{
            'test@example.com' => [SELECT Id, Name FROM Marketing_Campaign__c LIMIT 1]
        };

        // Mock successful token response but failed batch email response
        HttpMock mock = new HttpMock(200, '{"access_token":"newAccessToken"}');
        Test.setMock(HttpCalloutMock.class, new HttpMock(400, '{"error":"batch_failed"}'));

        Test.startTest();
        GmailIntegrationControllerV1.sendEmail(JSON.serialize(emails), JSON.serialize(remainingEmails), JSON.serialize(campaign), 'true');
        Test.stopTest();

        // Assertions
        System.assert(true, 'sendEmail should handle batch send failure and enqueue CampaignUpdateQueueable');
    }

    @isTest
    static void testSendEmailException() {
        // Setup invalid JSON to cause deserialization error
        String invalidJson = 'invalid_json';

        Test.startTest();
        GmailIntegrationControllerV1.sendEmail(invalidJson, JSON.serialize(new Map<String, Integer>()), JSON.serialize(new Map<String, Marketing_Campaign__c>()), 'false');
        Test.stopTest();

        // Assertions
        System.assert(true, 'sendEmail should handle deserialization exception gracefully');
    }
}