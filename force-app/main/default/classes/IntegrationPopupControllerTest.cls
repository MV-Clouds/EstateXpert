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
        AWS_Config__c settings = AWS_Config__c.getOrgDefaults();
        System.assertNotEquals(null, settings, 'AWS settings should be created');
        System.assertEquals('test_access_key', settings.AWS_Access_Key__c, 'Access key should match');
    }

    @isTest
    static void testGetSettings() {
        // Setup test data
        AWS_Config__c awsConfig = new AWS_Config__c(
            AWS_Access_Key__c = 'access_key',
            AWS_Secret_Access_Key__c = 'secret_key',
            S3_Bucket_Name__c = 'test-bucket',
            S3_Region_Name__c = 'us-west-1'
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
        AWS_Config__c awsConfig = new AWS_Config__c(
            AWS_Access_Key__c = 'test_access_key',
            AWS_Secret_Access_Key__c = 'test_secret_key'
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
        AWS_Config__c awsConfig = new AWS_Config__c(
            AWS_Access_Key__c = 'test_access_key',
            AWS_Secret_Access_Key__c = 'test_secret_key'
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
        
        // Test Outlook
        String outlookJson = '{"MVEX__Client_ID__c": "outlook_client_id", "MVEX__Client_Secret__c": "outlook_secret", "MVEX__Redirect_URI__c": "https://test.com"}';
        IntegrationPopupController.saveSettings(outlookJson, 'Outlook');
        
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
        IntegrationPopupController.FieldWrapper outlookResult = IntegrationPopupController.getSettings('Outlook');
        IntegrationPopupController.FieldWrapper instaResult = IntegrationPopupController.getSettings('Instagram');
        IntegrationPopupController.FieldWrapper googleResult = IntegrationPopupController.getSettings('Google');
        IntegrationPopupController.FieldWrapper metaResult = IntegrationPopupController.getSettings('Meta');
        Test.stopTest();
        
        System.assertNotEquals(null, gmailResult, 'Gmail result should not be null');
        System.assertNotEquals(null, outlookResult, 'Outlook result should not be null');
        System.assertNotEquals(null, instaResult, 'Instagram result should not be null');
        System.assertNotEquals(null, googleResult, 'Google result should not be null');
        System.assertNotEquals(null, metaResult, 'Meta result should not be null');
    }

    @isTest
    static void testRevokeAllAccess() {
        // Setup Gmail config
        GmailConfig__c gmailConfig = new GmailConfig__c(
            Client_ID__c = 'test_client_id',
            Client_Secret__c = 'test_secret',
            Redirect_URI__c = 'https://test.com',
            Refresh_Token__c = 'test_refresh_token'
        );
        insert gmailConfig;
        
        // Setup Outlook config
        OutlookConfig__c outlookConfig = new OutlookConfig__c(
            Client_ID__c = 'test_client_id',
            Client_Secret__c = 'test_secret',
            Redirect_URI__c = 'https://test.com',
            Refresh_Token_1__c = 'test_refresh_token'
        );
        insert outlookConfig;
        
        // Setup WhatsApp config
        WhatsAppConfig__c whatsappConfig = new WhatsAppConfig__c();
        insert whatsappConfig;
        
        // Setup Instagram config
        IG_Configuration__c instaConfig = new IG_Configuration__c(
            ClientId__c = 'test_client_id',
            ClientSecret__c = 'test_secret'
        );
        insert instaConfig;
        
        // Setup Google config
        GoogleLeadConfig__c googleConfig = new GoogleLeadConfig__c(
            Google_Lead_Form_Secret__c = 'test-google-key'
        );
        insert googleConfig;
        
        // Setup Meta config
        MetaLeadConfig__c metaConfig = new MetaLeadConfig__c(
            ACCESS_TOKEN__c = 'test_access_token',
            VERIFY_TOKEN__c = 'test_verify_token',
            FB_API_VERSION__c = 'v12.0',
            APP_ID__c = 'test_app_id',
            APP_SECRET__c = 'test_app_secret'
        );
        insert metaConfig;
        
        // Mock HTTP callout
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        
        Test.startTest();
        String gmailStatus = IntegrationPopupController.revokeGmailAccess('test_refresh_token', gmailConfig.Id);
        String outlookStatus = IntegrationPopupController.revokeOutlookAccess('test_refresh_token', outlookConfig.Id);
        String whatsappStatus = IntegrationPopupController.revokeWhatsappAccess(whatsappConfig.Id);
        String instaStatus = IntegrationPopupController.revokeInstagramAccess(instaConfig.Id);
        String googleStatus = IntegrationPopupController.revokeGoogleAccess(googleConfig.Id, 'Google');
        String metaStatus = IntegrationPopupController.revokeGoogleAccess(metaConfig.Id, 'Meta');
        String invalidStatus = IntegrationPopupController.revokeGoogleAccess(null, 'Invalid');
        Test.stopTest();
        
        System.assertNotEquals(null, gmailStatus, 'Gmail status should not be null');
        System.assertNotEquals(null, outlookStatus, 'Outlook status should not be null');
        System.assertEquals('success', whatsappStatus, 'WhatsApp should be revoked successfully');
        System.assertEquals('success', instaStatus, 'Instagram should be revoked successfully');
    }

    @isTest
    static void testSocialMediaAndGoogleData() {
        // Setup Instagram config
        IG_Configuration__c instaConfig = new IG_Configuration__c(
            ClientId__c = 'test_client_id',
            ClientSecret__c = 'test_secret'
        );
        insert instaConfig;
        
        Test.startTest();
        List<IntegrationPopupController.SocialMediaDataWrapper> socialData = IntegrationPopupController.getSocialMediaData();
        List<IntegrationPopupController.FieldWrapperData> googleAdsData = IntegrationPopupController.getGoogleData();
        Test.stopTest();
        
        System.assertNotEquals(null, socialData, 'Social media data should not be null');
    }

    @isTest
    static void testSaveCustomTempDataAndGetSiteUrl() {
        Test.startTest();
        IntegrationPopupController.saveCustomTempData('test_client_id', 'test_secret', 'https://test.com');
        String gmailUrl = IntegrationPopupController.getSiteUrl(null, 'Gmail');
        String outlookUrl = IntegrationPopupController.getSiteUrl(null, 'Outlook');
        String instaUrl = IntegrationPopupController.getSiteUrl(null, 'Instagram');
        String existingUrl = IntegrationPopupController.getSiteUrl('https://existing.com', 'Gmail');
        Test.stopTest();
        
        TempData__c tempData = TempData__c.getOrgDefaults();
        System.assertEquals('test_client_id', tempData.Client_ID__c, 'Client ID should match');
        System.assertEquals('test_secret', tempData.Client_Secret__c, 'Client secret should match');
        System.assertEquals('https://existing.com', existingUrl, 'Should return existing URL');
    }

    @isTest
    static void testSiteData() {
        Test.startTest();
        List<IntegrationPopupController.FieldList> sites = IntegrationPopupController.siteData();
        Test.stopTest();
        
        System.assertNotEquals(null, sites, 'Site data should not be null');
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