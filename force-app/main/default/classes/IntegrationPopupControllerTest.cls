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
}