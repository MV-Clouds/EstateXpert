@isTest
public class GoogleLeadFieldMappingControllerTest {

    @isTest
    static void test_getObjectFields() {
        List<Map<String, String>> result = GoogleLeadFieldMappingController.getObjectFields('Lead');
        System.assert(result != null, 'getObjectFields should not return null');
    }

    @isTest
    static void test_saveMappings() {
        String sampleJson = '[{"googleField":"g_name","leadField":"FirstName"}]';
        Test.startTest();
        GoogleLeadFieldMappingController.saveMappings(sampleJson, 'Google');
        Test.stopTest();
    }

    @isTest
    static void test_getMetadata() {
        String result = GoogleLeadFieldMappingController.getMetadata('Google');
    }

    @isTest
    static void test_getSocialMediaFieldsJson() {
        String result = GoogleLeadFieldMappingController.getSocialMediaFieldsJson('Google');
    }

    @isTest
    static void test_saveSocialMediaFieldsJson() {
        String sampleJson = '[{"fieldLabel":"Ad Name","fieldAPI":"G_Name__c"}]';
        Test.startTest();
        GoogleLeadFieldMappingController.saveSocialMediaFieldsJson(sampleJson, 'Google');
        Test.stopTest();
    }
}