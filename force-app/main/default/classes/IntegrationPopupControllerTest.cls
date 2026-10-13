@isTest
public class IntegrationPopupControllerTest {
    @isTest
    static void testSaveSettings() {
        // Setup test data
        String jsonData = '{"MVEX__AWS_Access_Key__c": "test_access_key", "MVEX__AWS_Secret_Access_Key__c": "test_secret_key"}';
        
        Test.startTest();
        IntegrationPopupController.saveSettings(jsonData, 'AWS');
        IntegrationPopupController.saveSettings(jsonData, null);        
        Test.stopTest();
        
        // Verify the AWS_Config__c settings were saved
        MVEX__AWS_Config__c settings = MVEX__AWS_Config__c.getOrgDefaults();
        System.assertNotEquals(null, settings, 'AWS settings should be created');
        System.assertEquals('test_access_key', settings.MVEX__AWS_Access_Key__c, 'Access key should match');
    }

    @isTest
    static void testGetSettings() {
        // Setup test data
        MVEX__AWS_Config__c awsConfig = new MVEX__AWS_Config__c(
            MVEX__AWS_Access_Key__c = 'access_key',
            MVEX__AWS_Secret_Access_Key__c = 'secret_key',
            MVEX__S3_Bucket_Name__c = 'test-bucket',
            MVEX__S3_Region_Name__c = 'us-west-1'
        );
        insert awsConfig;

        Test.startTest();
        IntegrationPopupController.FieldWrapper result = IntegrationPopupController.getSettings('AWS');
        IntegrationPopupController.FieldWrapper result1 = IntegrationPopupController.getSettings(null);
        Test.stopTest();

        // Verify the returned settings
        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testGetAuthorizationUrl() {
        OAuth_Configuration__mdt gmailConfig = OAuth_Configuration__mdt.getInstance('Gmail_OAuth');
        Boolean gmailConfigured = gmailConfig != null
            && String.isNotBlank(gmailConfig.Client_Id__c)
            && String.isNotBlank(gmailConfig.Redirect_URI__c)
            && String.isNotBlank(gmailConfig.Authorization_Endpoint__c)
            && String.isNotBlank(gmailConfig.Scope__c);

        try {
            String gmailUrl = IntegrationPopupController.getAuthorizationUrl('Gmail');
            System.assert(gmailConfigured, 'Gmail URL should only be generated from a complete configuration.');
            System.assert(gmailUrl.startsWith(gmailConfig.Authorization_Endpoint__c + '?client_id='));
            System.assert(gmailUrl.contains('&state=Gmail_OAuth'));
            System.assert(gmailUrl.contains('&scope=' + EncodingUtil.urlEncode(gmailConfig.Scope__c, 'UTF-8')));
        } catch (AuraHandledException e) {
            System.assert(!gmailConfigured, 'Gmail URL generation should fail only for incomplete configuration.');
        }

        OAuth_Configuration__mdt instagramConfig = OAuth_Configuration__mdt.getInstance('Instagram_OAuth');
        Boolean instagramConfigured = instagramConfig != null
            && String.isNotBlank(instagramConfig.Client_Id__c)
            && String.isNotBlank(instagramConfig.Redirect_URI__c)
            && String.isNotBlank(instagramConfig.Authorization_Endpoint__c)
            && String.isNotBlank(instagramConfig.Scope__c);

        try {
            String instagramUrl = IntegrationPopupController.getAuthorizationUrl('Instagram');
            System.assert(instagramConfigured, 'Instagram URL should only be generated from a complete configuration.');
            System.assert(instagramUrl.startsWith(instagramConfig.Authorization_Endpoint__c + '?client_id='));
            System.assert(instagramUrl.contains('&scope=' + EncodingUtil.urlEncode(instagramConfig.Scope__c, 'UTF-8')));
        } catch (AuraHandledException e) {
            System.assert(!instagramConfigured, 'Instagram URL generation should fail only for incomplete configuration.');
        }
    }

    @isTest
    static void testGetAuthorizationUrlRejectsUnsupportedIntegration() {
        try {
            IntegrationPopupController.getAuthorizationUrl('AWS');
            System.assert(false, 'Unsupported integration types should be rejected.');
        } catch (AuraHandledException e) {
            System.assertEquals('Unsupported integration type.', e.getMessage());
        }
    }
    
    @isTest
    static void testRevokeAWSAccess() {
        // Setup test data
        MVEX__AWS_Config__c awsConfig = new MVEX__AWS_Config__c(
            MVEX__AWS_Access_Key__c = 'test_access_key',
            MVEX__AWS_Secret_Access_Key__c = 'test_secret_key'
        );
        insert awsConfig;

        Test.startTest();
        String status = IntegrationPopupController.revokeAWSAccess(awsConfig.Id);
        String status1 = IntegrationPopupController.revokeAWSAccess(null);
        Test.stopTest();

        System.assertNotEquals(null, status, 'Status should not be null');
    }

    @isTest
    static void testGetIntegrationDetails() {
        MVEX__AWS_Config__c awsConfig = new MVEX__AWS_Config__c(
            MVEX__AWS_Access_Key__c = 'test_access_key',
            MVEX__AWS_Secret_Access_Key__c = 'test_secret_key'
        );
        insert awsConfig;

        Test.startTest();
        List<IntegrationPopupController.FieldWrapperData> fieldWrapperData = IntegrationPopupController.getIntegrationDetails();
        Test.stopTest();

        System.assertNotEquals(null, fieldWrapperData, 'Integration details should be returned.');
        System.assertEquals(3, fieldWrapperData.size(), 'AWS, Gmail, and Instagram integrations should be returned.');
    }

    @isTest
    static void testAllIntegrationTypes() {
        String gmailJson = '{"Refresh_Token__c": "gmail_refresh_token", "Access_Token__c": "gmail_access_token", "Username__c": "gmail@example.com"}';
        IntegrationPopupController.saveSettings(gmailJson, 'Gmail');

        String instaJson = '{"Access_Token__c": "instagram_access_token", "User_Id__c": "12345", "Username__c": "test_user"}';
        IntegrationPopupController.saveSettings(instaJson, 'Instagram');
        
        Test.startTest();
        IntegrationPopupController.FieldWrapper gmailResult = IntegrationPopupController.getSettings('Gmail');
        IntegrationPopupController.FieldWrapper instaResult = IntegrationPopupController.getSettings('Instagram');
        String gmailDeleteStatus = IntegrationPopupController.deleteGmailConfig();
        Test.stopTest();
        
        System.assertNotEquals(null, gmailResult, 'Gmail result should not be null');
        System.assertNotEquals(null, instaResult, 'Instagram result should not be null');
        System.assertEquals('success', gmailDeleteStatus, 'Gmail token metadata should be cleared successfully.');
    }

    @isTest
    static void testRevokeAllAccess() {
        // Setup Gmail config
        MVEX__GmailConfig__c gmailConfig = new MVEX__GmailConfig__c(
            MVEX__Client_ID__c = 'test_client_id',
            MVEX__Client_Secret__c = 'test_secret',
            MVEX__Redirect_URI__c = 'https://test.com',
            MVEX__Refresh_Token__c = 'test_refresh_token'
        );
        insert gmailConfig;
        
        // Setup WhatsApp config
        MVEX__WhatsAppConfig__c whatsappConfig = new MVEX__WhatsAppConfig__c();
        insert whatsappConfig;
        
        // Setup Instagram config
        MVEX__IG_Configuration__c instaConfig = new MVEX__IG_Configuration__c(
            MVEX__ClientId__c = 'test_client_id',
            MVEX__ClientSecret__c = 'test_secret'
        );
        insert instaConfig;
        
        // Mock HTTP callout
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        
        Test.startTest();
        String gmailStatus = IntegrationPopupController.revokeGmailAccess();
        String instaStatus = IntegrationPopupController.revokeInstagramAccess();
        Test.stopTest();
        
        System.assertNotEquals(null, gmailStatus, 'Gmail status should not be null');
        System.assertEquals('success', instaStatus, 'Instagram should be revoked successfully');
    }

    @isTest
    static void testValidateIntegrationCredentials_Instagram() {
        Test.startTest();
        // Blank input
        String blankResult = IntegrationPopupController.validateIntegrationCredentials('Instagram', '', '');
        System.assertEquals('Please fill in both User ID and Long-Lived Access Token.', blankResult);

        // Default success in test context
        String successResult = IntegrationPopupController.validateIntegrationCredentials('Instagram', '123456', 'token123');
        System.assertEquals('SUCCESS|test_user', successResult);

        // Mock failure
        IntegrationPopupController.mockValidationResult = 'Invalid Instagram credentials. Please check your User ID and Access Token.';
        String failResult = IntegrationPopupController.validateIntegrationCredentials('Instagram', '123456', 'bad_token');
        System.assertEquals('Invalid Instagram credentials. Please check your User ID and Access Token.', failResult);
        IntegrationPopupController.mockValidationResult = null;
        Test.stopTest();
    }

    @isTest
    static void testValidateIntegrationCredentials_Gmail() {
        Test.startTest();
        // Blank token
        String blankResult = IntegrationPopupController.validateIntegrationCredentials('Gmail', '', '');
        System.assertEquals('Please enter a valid Gmail Refresh Token.', blankResult);

        // Default success in test context
        String successResult = IntegrationPopupController.validateIntegrationCredentials('Gmail', 'refresh_token_123', 'client_id');
        System.assertEquals('SUCCESS|test@example.com', successResult);
        Test.stopTest();
    }


    @isTest
    static void testValidateIntegrationCredentials_Unsupported() {
        Test.startTest();
        String result = IntegrationPopupController.validateIntegrationCredentials('Unknown', 'a', 'b');
        System.assert(result.contains('Unsupported'), 'Should return unsupported message');
        Test.stopTest();
    }

    @isTest
    static void testValidateAWSCredentialsRequiredFields() {
        System.assertEquals('AWS Access Key is required.', IntegrationPopupController.validateAWSCredentials('', 'secret', 'bucket', 'us-east-1'));
        System.assertEquals('AWS Secret Access Key is required.', IntegrationPopupController.validateAWSCredentials('key', '', 'bucket', 'us-east-1'));
        System.assertEquals('AWS S3 Bucket Name is required.', IntegrationPopupController.validateAWSCredentials('key', 'secret', '', 'us-east-1'));
        System.assertEquals('AWS S3 Region Name is required.', IntegrationPopupController.validateAWSCredentials('key', 'secret', 'bucket', ''));
    }

    @isTest
    static void testValidateAWSCredentialsResponses() {
        Test.setMock(HttpCalloutMock.class, new StaticHttpResponseMock(200, ''));
        System.assertEquals('SUCCESS', IntegrationPopupController.validateAWSCredentials('key', 'secret', 'bucket', 'us-east-1'));

        List<String> responseBodies = new List<String>{
            '<Error><Code>InvalidAccessKeyId</Code></Error>',
            '<Error><Code>SignatureDoesNotMatch</Code></Error>',
            '<Error><Code>NoSuchBucket</Code></Error>',
            '<Error><Code>AccessDenied</Code></Error>',
            '<Error><Code>PermanentRedirect</Code></Error>',
            '<Error><Message>Unexpected S3 error</Message></Error>',
            ''
        };
        List<Integer> statusCodes = new List<Integer>{ 403, 403, 404, 403, 301, 500, 418 };
        List<String> expectedMessages = new List<String>{
            'Invalid Access Key: The AWS Access Key ID provided does not exist.',
            'Invalid Secret Access Key: Signature does not match. Please verify your Secret Access Key.',
            'Bucket Not Found: The specified S3 bucket does not exist.',
            'Access Denied: The provided credentials do not have permission to access the S3 bucket.',
            'Region Mismatch: The specified region does not match the bucket region.',
            'Unexpected S3 error',
            'AWS validation failed with status code 418 (Mock error status).'
        };

        for (Integer i = 0; i < responseBodies.size(); i++) {
            Test.setMock(HttpCalloutMock.class, new StaticHttpResponseMock(statusCodes[i], responseBodies[i]));
            System.assertEquals(expectedMessages[i], IntegrationPopupController.validateAWSCredentials('key', 'secret', 'bucket', 'us-east-1'));
        }

        Test.setMock(HttpCalloutMock.class, new StaticHttpResponseMock(301, '<Error><Code>PermanentRedirect</Code></Error>', 'x-amz-bucket-region', 'us-west-2'));
        System.assertEquals(
            'Region Mismatch: The bucket is located in region "us-west-2", but you specified "us-east-1".',
            IntegrationPopupController.validateAWSCredentials('key', 'secret', 'bucket', 'us-east-1')
        );
    }

    @isTest
    static void testValidateInstagramResponses() {
        Test.setMock(HttpCalloutMock.class, new StaticHttpResponseMock(200, '{"user_id":"12345","username":"test_user"}'));
        System.assertEquals('SUCCESS|test_user', IntegrationPopupController.validateInstagram('12345', 'token'));

        Test.setMock(HttpCalloutMock.class, new StaticHttpResponseMock(200, '{"id":"12345"}'));
        System.assertEquals('SUCCESS|12345', IntegrationPopupController.validateInstagram('12345', 'token'));

        Test.setMock(HttpCalloutMock.class, new StaticHttpResponseMock(200, '{"user_id":"different","id":"different"}'));
        System.assertEquals(
            'The provided User ID does not match the authenticated Instagram account.',
            IntegrationPopupController.validateInstagram('12345', 'token')
        );

        Test.setMock(HttpCalloutMock.class, new StaticHttpResponseMock(400, '{"error":{"message":"Instagram token rejected"}}'));
        System.assertEquals('Instagram token rejected', IntegrationPopupController.validateInstagram('12345', 'token'));

        Test.setMock(HttpCalloutMock.class, new StaticHttpResponseMock(400, '{}'));
        System.assertEquals(
            'Invalid Instagram credentials. Please check your User ID and Access Token.',
            IntegrationPopupController.validateInstagram('12345', 'token')
        );
    }

    @isTest
    static void testValidateGmailResponses() {
        OAuth_Configuration__mdt gmailConfig = OAuth_Configuration__mdt.getInstance('Gmail_OAuth');
        if (gmailConfig == null || String.isBlank(gmailConfig.Client_Secret__c)
            || String.isBlank(gmailConfig.Token_Endpoint__c) || String.isBlank(gmailConfig.Base_URL__c)) {
            System.assert(
                IntegrationPopupController.validateGmail('refresh_token', null).contains('configuration is incomplete'),
                'Gmail validation should report incomplete OAuth configuration.'
            );
            return;
        }

        Test.setMock(HttpCalloutMock.class, new GmailValidationMock());
        System.assertEquals('SUCCESS|test@example.com', IntegrationPopupController.validateGmail('refresh_token', null));

        Test.setMock(HttpCalloutMock.class, new StaticHttpResponseMock(401, '{"error_description":"Refresh token expired"}'));
        System.assertEquals('Refresh token expired', IntegrationPopupController.validateGmail('refresh_token', null));

        Test.setMock(HttpCalloutMock.class, new StaticHttpResponseMock(401, '{"error":"invalid_grant"}'));
        System.assertEquals('Invalid Gmail credentials: invalid_grant', IntegrationPopupController.validateGmail('refresh_token', null));

        Test.setMock(HttpCalloutMock.class, new StaticHttpResponseMock(401, '{}'));
        System.assertEquals(
            'Invalid Gmail Refresh Token. Please re-authorize and try again.',
            IntegrationPopupController.validateGmail('refresh_token', null)
        );
    }

    // Mock HTTP Response Generator
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{"success": true}');
            return res;
        }
    }

    private class StaticHttpResponseMock implements HttpCalloutMock {
        private Integer statusCode;
        private String body;
        private String headerName;
        private String headerValue;

        StaticHttpResponseMock(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body = body;
        }

        StaticHttpResponseMock(Integer statusCode, String body, String headerName, String headerValue) {
            this.statusCode = statusCode;
            this.body = body;
            this.headerName = headerName;
            this.headerValue = headerValue;
        }

        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(statusCode);
            response.setStatus('Mock error status');
            response.setBody(body);
            if (headerName != null) {
                response.setHeader(headerName, headerValue);
            }
            return response;
        }
    }

    private class GmailValidationMock implements HttpCalloutMock {
        private Integer requestCount = 0;

        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            if (requestCount++ == 0) {
                response.setBody('{"access_token":"fresh_access_token"}');
            } else {
                response.setBody('{"email":"test@example.com"}');
            }
            return response;
        }
    }
}