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
        IntegrationPopupController.FieldList fieldInstance = new IntegrationPopupController.FieldList('Sample Label','Sample Value');
        IntegrationPopupController.SocialMediaDataWrapper sc = new IntegrationPopupController.SocialMediaDataWrapper();
        sc.isValid = false;
        sc.integrationData = null;
        sc.integrationData = false;
        
        Test.stopTest();

        // Verify the AWS data wrapper
        System.assertNotEquals(0, fieldWrapperData.size(), 'Should return one integration data wrapper');
    }

    @isTest
    static void testAllIntegrationTypes() {
        // Test Gmail
        String gmailJson = '{"MVEX__Client_ID__c": "gmail_client_id", "MVEX__Client_Secret__c": "gmail_secret", "MVEX__Redirect_URI__c": "https://test.com"}';
        IntegrationPopupController.saveSettings(gmailJson, 'Gmail');
        
        // Test Instagram
        String instaJson = '{"MVEX__ClientId__c": "insta_client_id", "MVEX__ClientSecret__c": "insta_secret"}';
        IntegrationPopupController.saveSettings(instaJson, 'Instagram');
        
        // Test Google
        String googleJson = '{"MVEX__Client_Id__c": "google_client_id", "MVEX__Client_Secret__c": "google_secret"}';
        IntegrationPopupController.saveSettings(googleJson, 'Google');
        
        // Test Meta
        String metaJson = '{"MVEX__Client_Id__c": "meta_client_id", "MVEX__Client_Secret__c": "meta_secret"}';
        IntegrationPopupController.saveSettings(metaJson, 'Meta');
        
        Test.startTest();
        IntegrationPopupController.FieldWrapper gmailResult = IntegrationPopupController.getSettings('Gmail');
        IntegrationPopupController.FieldWrapper instaResult = IntegrationPopupController.getSettings('Instagram');
        IntegrationPopupController.FieldWrapper googleResult = IntegrationPopupController.getSettings('Google');
        IntegrationPopupController.FieldWrapper metaResult = IntegrationPopupController.getSettings('Meta');
        Test.stopTest();
        
        System.assertNotEquals(null, gmailResult, 'Gmail result should not be null');
        System.assertNotEquals(null, instaResult, 'Instagram result should not be null');
        System.assertNotEquals(null, googleResult, 'Google result should not be null');
        System.assertNotEquals(null, metaResult, 'Meta result should not be null');
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
        
        // Setup Google config
        MVEX__GoogleLeadConfig__c googleConfig = new MVEX__GoogleLeadConfig__c(
            MVEX__Google_Lead_Form_Secret__c = 'test-google-key'
        );
        insert googleConfig;
        
        // Setup Meta config
        MVEX__MetaLeadConfig__c metaConfig = new MVEX__MetaLeadConfig__c(
            MVEX__ACCESS_TOKEN__c = 'test_access_token',
            MVEX__VERIFY_TOKEN__c = 'test_verify_token',
            MVEX__FB_API_VERSION__c = 'v12.0',
            MVEX__APP_ID__c = 'test_app_id',
            MVEX__APP_SECRET__c = 'test_app_secret'
        );
        insert metaConfig;
        
        // Mock HTTP callout
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        
        Test.startTest();
        String gmailStatus = IntegrationPopupController.revokeGmailAccess('test_refresh_token', gmailConfig.Id);
        String instaStatus = IntegrationPopupController.revokeInstagramAccess(instaConfig.Id);
        String googleStatus = IntegrationPopupController.revokeGoogleAccess(googleConfig.Id, 'Google');
        String metaStatus = IntegrationPopupController.revokeGoogleAccess(metaConfig.Id, 'Meta');
        String invalidStatus = IntegrationPopupController.revokeGoogleAccess(null, 'Invalid');
        Test.stopTest();
        
        System.assertNotEquals(null, gmailStatus, 'Gmail status should not be null');
        System.assertEquals('success', instaStatus, 'Instagram should be revoked successfully');
    }

    @isTest
    static void testSocialMediaAndGoogleData() {
        // Setup Instagram config
        MVEX__IG_Configuration__c instaConfig = new MVEX__IG_Configuration__c(
            MVEX__ClientId__c = 'test_client_id',
            MVEX__ClientSecret__c = 'test_secret'
        );
        insert instaConfig;
        
        Test.startTest();
        List<IntegrationPopupController.SocialMediaDataWrapper> socialData = IntegrationPopupController.getSocialMediaData();
        List<IntegrationPopupController.FieldWrapperData> googleAdsData = IntegrationPopupController.getGoogleData();
        Test.stopTest();
        
        System.assertNotEquals(null, socialData, 'Social media data should not be null');
    }

    @isTest
    static void testSiteData() {
        Test.startTest();
        List<IntegrationPopupController.FieldList> sites = IntegrationPopupController.siteData();
        Test.stopTest();
        
        System.assertNotEquals(null, sites, 'Site data should not be null');
    }

    @isTest
    static void testValidateIntegrationCredentials_Instagram() {
        Test.startTest();
        // Blank input
        String blankResult = IntegrationPopupController.validateIntegrationCredentials('Instagram', '', '');
        System.assertEquals('Please fill in both User ID and Long-Lived Access Token.', blankResult);

        // Default success in test context
        String successResult = IntegrationPopupController.validateIntegrationCredentials('Instagram', '123456', 'token123');
        System.assertEquals('SUCCESS', successResult);

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
        System.assertEquals('SUCCESS', successResult);
        Test.stopTest();
    }


    @isTest
    static void testValidateIntegrationCredentials_Unsupported() {
        Test.startTest();
        String result = IntegrationPopupController.validateIntegrationCredentials('Unknown', 'a', 'b');
        System.assert(result.contains('Unsupported'), 'Should return unsupported message');
        Test.stopTest();
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
}