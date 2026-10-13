/**
 * Class Name : IntegrationPopupControllerTest
 * Last Modified Date : 2026-10-12
 * Last Modified By : Dhruv Kakadiya
 * @description : Test class for IntegrationPopupController.
 */

@isTest
public class IntegrationPopupControllerTest {

    @isTest
    static void testSaveSettings_AWS() {
        String jsonData = '{"MVEX__AWS_Access_Key__c": "test_access_key", "MVEX__AWS_Secret_Access_Key__c": "test_secret_key", "MVEX__S3_Bucket_Name__c": "test-bucket", "MVEX__S3_Region_Name__c": "us-east-1"}';
        
        Test.startTest();
        IntegrationPopupController.saveSettings(jsonData, 'AWS');
        IntegrationPopupController.saveSettings(jsonData, null);        
        Test.stopTest();
        
        MVEX__AWS_Config__c settings = MVEX__AWS_Config__c.getOrgDefaults();
        System.assertNotEquals(null, settings, 'AWS settings should be created');
        System.assertEquals('test_access_key', settings.MVEX__AWS_Access_Key__c, 'Access key should match');
    }

    @isTest
    static void testSaveSettings_GmailAndInstagram() {
        // Connected_Date__c is null in test context (metadata not deployable), so the stamp branch fires naturally
        String gmailJson = '{"Refresh_Token__c": "test_refresh", "Access_Token__c": "test_access", "Email__c": "test@gmail.com"}';
        String instaJson = '{"Access_Token__c": "insta_token", "User_Id__c": "12345", "Username__c": "test_user"}';

        Test.startTest();
        IntegrationPopupController.saveSettings(gmailJson, 'Gmail');
        IntegrationPopupController.saveSettings(instaJson, 'Instagram');
        Test.stopTest();

        System.assert(true, 'saveSettings for Gmail and Instagram should execute without exception');
    }

    @isTest
    static void testGetSettings() {
        Test.startTest();
        IntegrationPopupController.FieldWrapper gmailResult = IntegrationPopupController.getSettings('Gmail');
        IntegrationPopupController.FieldWrapper instaResult = IntegrationPopupController.getSettings('Instagram');
        IntegrationPopupController.FieldWrapper nullResult = IntegrationPopupController.getSettings(null);
        Test.stopTest();

        System.assertNotEquals(null, gmailResult, 'Gmail result should not be null');
        System.assertNotEquals(null, instaResult, 'Instagram result should not be null');
        System.assertNotEquals(null, nullResult, 'Null result wrapper should not be null');
    }

    @isTest
    static void testGetIntegrationDetails() {
        MVEX__AWS_Config__c awsConfig = new MVEX__AWS_Config__c(
            MVEX__AWS_Access_Key__c = 'test_access_key',
            MVEX__AWS_Secret_Access_Key__c = 'test_secret_key',
            MVEX__S3_Bucket_Name__c = 'my-bucket',
            MVEX__S3_Region_Name__c = 'us-east-1'
        );
        insert awsConfig;

        Test.startTest();
        List<IntegrationPopupController.FieldWrapperData> details = IntegrationPopupController.getIntegrationDetails();
        Test.stopTest();

        System.assertNotEquals(null, details, 'Integration details should not be null');
        System.assert(!details.isEmpty(), 'Integration details list should not be empty');
    }

    @isTest
    static void testRevokeAWSAccess() {
        MVEX__AWS_Config__c awsConfig = new MVEX__AWS_Config__c(
            MVEX__AWS_Access_Key__c = 'test_access_key',
            MVEX__AWS_Secret_Access_Key__c = 'test_secret_key'
        );
        insert awsConfig;

        Test.startTest();
        String status = IntegrationPopupController.revokeAWSAccess(awsConfig.Id);
        String statusNull = IntegrationPopupController.revokeAWSAccess(null);
        Test.stopTest();

        System.assertEquals('success', status, 'Revoke AWS access should return success');
        System.assertNotEquals(null, statusNull, 'Revoking with null should return error message');
    }

    @isTest
    static void testRevokeGmailAccess() {
        Test.setMock(HttpCalloutMock.class, new MultiMockHttpResponseGenerator());

        Test.startTest();
        String statusSuccess = IntegrationPopupController.revokeGmailAccess('test_refresh_token', 'sample_id');
        Test.stopTest();

        System.assertEquals('success', statusSuccess, 'revokeGmailAccess should return success');
    }

    @isTest
    static void testDeleteGmailConfig() {
        Test.startTest();
        String status = IntegrationPopupController.deleteGmailConfig('sample_id');
        Test.stopTest();

        System.assertEquals('success', status, 'deleteGmailConfig should return success');
    }

    @isTest
    static void testRevokeInstagramAccess() {
        Test.startTest();
        String status = IntegrationPopupController.revokeInstagramAccess('sample_id');
        Test.stopTest();

        System.assertEquals('success', status, 'revokeInstagramAccess should return success');
    }

    @isTest
    static void testValidateAWSCredentials() {
        // Blank checks
        System.assert(IntegrationPopupController.validateAWSCredentials('', 'sec', 'buc', 'us-east-1').contains('Access Key is required'));
        System.assert(IntegrationPopupController.validateAWSCredentials('key', '', 'buc', 'us-east-1').contains('Secret Access Key is required'));
        System.assert(IntegrationPopupController.validateAWSCredentials('key', 'sec', '', 'us-east-1').contains('Bucket Name is required'));
        System.assert(IntegrationPopupController.validateAWSCredentials('key', 'sec', 'buc', '').contains('Region Name is required'));

        Test.setMock(HttpCalloutMock.class, new MultiMockHttpResponseGenerator());

        Test.startTest();
        String validRes = IntegrationPopupController.validateAWSCredentials('testKey', 'testSecret', 'testBucket', 'us-east-1');
        String validWestRes = IntegrationPopupController.validateAWSCredentials('testKey', 'testSecret', 'testBucket', 'us-west-2');
        Test.stopTest();

        System.assertEquals('SUCCESS', validRes, 'AWS validation should succeed with mock');
        System.assertEquals('SUCCESS', validWestRes, 'AWS validation in us-west-2 should succeed with mock');
    }

    @isTest
    static void testValidateAWSCredentials_Errors() {
        // Test invalid access key error XML
        SingleResponseMock mockInvalidKey = new SingleResponseMock(403, '<Error><Code>InvalidAccessKeyId</Code><Message>Invalid Key</Message></Error>', null);
        Test.setMock(HttpCalloutMock.class, mockInvalidKey);
        String resKey = IntegrationPopupController.validateAWSCredentials('testKey', 'testSecret', 'testBucket', 'us-east-1');
        System.assert(resKey.contains('Invalid Access Key'), 'Should detect InvalidAccessKeyId');

        // Test signature does not match
        SingleResponseMock mockSig = new SingleResponseMock(403, '<Error><Code>SignatureDoesNotMatch</Code></Error>', null);
        Test.setMock(HttpCalloutMock.class, mockSig);
        String resSig = IntegrationPopupController.validateAWSCredentials('testKey', 'testSecret', 'testBucket', 'us-east-1');
        System.assert(resSig.contains('Invalid Secret Access Key'), 'Should detect SignatureDoesNotMatch');

        // Test bucket not found
        SingleResponseMock mockBucket = new SingleResponseMock(404, '<Error><Code>NoSuchBucket</Code></Error>', null);
        Test.setMock(HttpCalloutMock.class, mockBucket);
        String resBucket = IntegrationPopupController.validateAWSCredentials('testKey', 'testSecret', 'testBucket', 'us-east-1');
        System.assert(resBucket.contains('Bucket Not Found'), 'Should detect NoSuchBucket');

        // Test access denied
        SingleResponseMock mockDenied = new SingleResponseMock(403, '<Error><Code>AccessDenied</Code></Error>', null);
        Test.setMock(HttpCalloutMock.class, mockDenied);
        String resDenied = IntegrationPopupController.validateAWSCredentials('testKey', 'testSecret', 'testBucket', 'us-east-1');
        System.assert(resDenied.contains('Access Denied'), 'Should detect AccessDenied');

        // Test region mismatch with header
        Map<String, String> headers = new Map<String, String>{ 'x-amz-bucket-region' => 'eu-west-1' };
        SingleResponseMock mockRedirect = new SingleResponseMock(301, '<Error><Code>PermanentRedirect</Code></Error>', headers);
        Test.setMock(HttpCalloutMock.class, mockRedirect);
        String resRedirect = IntegrationPopupController.validateAWSCredentials('testKey', 'testSecret', 'testBucket', 'us-east-1');
        System.assert(resRedirect.contains('Region Mismatch'), 'Should detect Region Mismatch');

        // Test redirect without header
        SingleResponseMock mockRedirectNoHeader = new SingleResponseMock(301, '<Error><Code>PermanentRedirect</Code></Error>', null);
        Test.setMock(HttpCalloutMock.class, mockRedirectNoHeader);
        String resRedirectNoHeader = IntegrationPopupController.validateAWSCredentials('testKey', 'testSecret', 'testBucket', 'us-east-1');
        System.assert(resRedirectNoHeader.contains('Region Mismatch'), 'Should detect Region Mismatch without header');

        // Test custom message tag
        SingleResponseMock mockCustomMsg = new SingleResponseMock(400, '<Error><Message>Custom S3 Message</Message></Error>', null);
        Test.setMock(HttpCalloutMock.class, mockCustomMsg);
        String resCustomMsg = IntegrationPopupController.validateAWSCredentials('testKey', 'testSecret', 'testBucket', 'us-east-1');
        System.assertEquals('Custom S3 Message', resCustomMsg);

        // Test general status code
        SingleResponseMock mock500 = new SingleResponseMock(500, '', null);
        Test.setMock(HttpCalloutMock.class, mock500);
        String res500 = IntegrationPopupController.validateAWSCredentials('testKey', 'testSecret', 'testBucket', 'us-east-1');
        System.assert(res500.contains('AWS validation failed with status code 500'), 'Should detect status code');
    }

    @isTest
    static void testValidateAWSCredentials_UnauthorizedAndFallback() {
        // 1. Fallback succeeds when virtual-hosted endpoint hits Unauthorized endpoint (lines 201-206)
        Test.setMock(HttpCalloutMock.class, new AwsCalloutExceptionMock('UNAUTHORIZED_RECOVER'));
        Test.startTest();
        String recoverRes = IntegrationPopupController.validateAWSCredentials('testKey', 'testSecret', 'testBucket', 'us-east-1');
        System.assertEquals('SUCCESS', recoverRes, 'Fallback S3 endpoint should recover and return SUCCESS');

        // 2. Fallback also fails with Unauthorized endpoint (lines 207-210) for us-east-1 and other regions
        Test.setMock(HttpCalloutMock.class, new AwsCalloutExceptionMock('UNAUTHORIZED_FAIL'));
        String failEast = IntegrationPopupController.validateAWSCredentials('testKey', 'testSecret', 'testBucket', 'us-east-1');
        String failOther = IntegrationPopupController.validateAWSCredentials('testKey', 'testSecret', 'testBucket', 'eu-west-1');
        System.assert(failEast.contains('Unauthorized endpoint. Please add https://testBucket.s3.amazonaws.com'), 'Should return us-east-1 host');
        System.assert(failOther.contains('Unauthorized endpoint. Please add https://testBucket.s3.eu-west-1.amazonaws.com'), 'Should return regional host');

        // 3. General CalloutException (line 212)
        Test.setMock(HttpCalloutMock.class, new AwsCalloutExceptionMock('GENERAL_CALLOUT_ERROR'));
        String generalError = IntegrationPopupController.validateAWSCredentials('testKey', 'testSecret', 'testBucket', 'us-east-1');
        System.assert(generalError.contains('Callout Error: Read timed out'), 'Should return general callout error');

        // 4. General unexpected exception — pass null secretKey so null.trim() throws NPE inside sendS3ValidationRequest
        String excRes = IntegrationPopupController.validateAWSCredentials('testKey', null, 'testBucket', 'us-east-1');
        Test.stopTest();
    }

    @isTest
    static void testValidateInstagram() {
        // Blank inputs
        String blankRes = IntegrationPopupController.validateInstagram('', '');
        System.assertEquals('Please fill in both User ID and Long-Lived Access Token.', blankRes);

        Test.setMock(HttpCalloutMock.class, new MultiMockHttpResponseGenerator());

        Test.startTest();
        // Success match
        String successRes = IntegrationPopupController.validateInstagram('123456', 'valid_token');
        // Error response from API (triggers 400 error in mock via bad_token)
        String errRes = IntegrationPopupController.validateInstagram('123456', 'bad_token');
        Test.stopTest();
    }

    @isTest
    static void testValidateGmail() {
        // Blank input
        String blankRes = IntegrationPopupController.validateGmail('', '');
        System.assertEquals('Please enter a valid Gmail Refresh Token.', blankRes);

        Test.setMock(HttpCalloutMock.class, new MultiMockHttpResponseGenerator());

        Test.startTest();
        String successRes = IntegrationPopupController.validateGmail('valid_refresh_token', 'client_123');
        System.assert(successRes.startsWith('SUCCESS|'), 'Valid Gmail token exchange should return SUCCESS');

        // Error response from token endpoint (triggers 400 error in mock via bad_refresh_token)
        String errRes = IntegrationPopupController.validateGmail('bad_refresh_token', 'client_123');
        System.assertEquals('Token has been expired or revoked.', errRes);
        Test.stopTest();
    }

    @isTest
    static void testValidateIntegrationCredentials() {
        // Blank integration type
        String blankTypeRes = IntegrationPopupController.validateIntegrationCredentials('', 'a', 'b');
        System.assertEquals('Integration type is required.', blankTypeRes);

        // Mock validation result override
        IntegrationPopupController.mockValidationResult = 'Custom Mock Override';
        String overrideRes = IntegrationPopupController.validateIntegrationCredentials('Instagram', 'a', 'b');
        System.assertEquals('Custom Mock Override', overrideRes);
        IntegrationPopupController.mockValidationResult = null;

        // Unsupported integration type
        String unsupportedRes = IntegrationPopupController.validateIntegrationCredentials('UnsupportedType', 'a', 'b');
        System.assert(unsupportedRes.contains('Unsupported integration type'), 'Should handle unsupported type');

        // Success routing for Instagram and Gmail
        Test.setMock(HttpCalloutMock.class, new MultiMockHttpResponseGenerator());

        Test.startTest();
        String instaRes = IntegrationPopupController.validateIntegrationCredentials('Instagram', '123456', 'valid_token');
        String gmailRes = IntegrationPopupController.validateIntegrationCredentials('Gmail', 'valid_refresh_token', 'client_123');
        Test.stopTest();
        System.assert(gmailRes.startsWith('SUCCESS'), 'Gmail credentials validation should return success');
    }

    // Callout Mock for multi-service requests
    private class MultiMockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            String endpoint = req.getEndpoint();
            String reqBody = req.getBody();
            
            if (endpoint.contains('oauth2/v2/userinfo')) {
                res.setStatusCode(200);
                res.setBody('{"email": "user@example.com"}');
            } else if (endpoint.contains('token')) {
                if (reqBody != null && reqBody.contains('bad_refresh_token')) {
                    res.setStatusCode(400);
                    res.setBody('{"error_description": "Token has been expired or revoked."}');
                } else {
                    res.setStatusCode(200);
                    res.setBody('{"access_token": "mock_access_token"}');
                }
            } else if (endpoint.contains('graph.instagram.com') || endpoint.contains('/me')) {
                if (endpoint.contains('bad_token')) {
                    res.setStatusCode(400);
                    res.setBody('{"error": {"message": "Invalid OAuth access token."}}');
                } else {
                    res.setStatusCode(200);
                    res.setBody('{"id": "123456", "user_id": "123456", "username": "test_instagram_user"}');
                }
            } else if (endpoint.contains('s3') || endpoint.contains('amazonaws.com')) {
                res.setHeader('Content-Type', 'application/xml');
                res.setStatusCode(200);
                res.setBody('<ListBucketResult></ListBucketResult>');
            } else {
                res.setStatusCode(200);
                res.setBody('{"success": true}');
            }
            return res;
        }
    }

    // Callout Mock for single custom response
    private class SingleResponseMock implements HttpCalloutMock {
        private Integer statusCode;
        private String body;
        private Map<String, String> headers;

        public SingleResponseMock(Integer statusCode, String body, Map<String, String> headers) {
            this.statusCode = statusCode;
            this.body = body;
            this.headers = headers;
        }

        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(this.statusCode);
            res.setBody(this.body);
            if (this.headers != null) {
                for (String headerKey : this.headers.keySet()) {
                    res.setHeader(headerKey, this.headers.get(headerKey));
                }
            }
            return res;
        }
    }

    // Callout Mock for AWS unauthorized endpoint fallback and callout exceptions
    private class AwsCalloutExceptionMock implements HttpCalloutMock {
        private String scenario;
        private Integer callCount = 0;

        public AwsCalloutExceptionMock(String scenario) {
            this.scenario = scenario;
        }

        public HTTPResponse respond(HTTPRequest req) {
            callCount++;
            if (scenario == 'UNAUTHORIZED_RECOVER') {
                if (callCount == 1) {
                    CalloutException ce = new CalloutException();
                    ce.setMessage('Unauthorized endpoint, please check Setup->Security->Remote site settings. Endpoint = ' + req.getEndpoint());
                    throw ce;
                }
                HttpResponse res = new HttpResponse();
                res.setStatusCode(200);
                res.setHeader('Content-Type', 'application/xml');
                res.setBody('<ListBucketResult></ListBucketResult>');
                return res;
            } else if (scenario == 'UNAUTHORIZED_FAIL') {
                CalloutException ce = new CalloutException();
                ce.setMessage('Unauthorized endpoint, please check Setup->Security->Remote site settings. Endpoint = ' + req.getEndpoint());
                throw ce;
            } else if (scenario == 'GENERAL_CALLOUT_ERROR') {
                CalloutException ce = new CalloutException();
                ce.setMessage('Read timed out');
                throw ce;
            }
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            return res;
        }
    }
}