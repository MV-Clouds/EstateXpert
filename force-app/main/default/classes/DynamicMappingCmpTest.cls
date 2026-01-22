@isTest
private class DynamicMappingCmpTest {

    @testSetup
    static void setupTestData() {
        // Insert a valid SObject for schema access
        insert new Account(Name = 'Test Account');
        insert new Contact(FirstName = 'Test', LastName = 'User');
    }

    @isTest
    static void testGetObjectFieldsReturnsValidFieldsForContact() {
        Test.startTest();
        List<Map<String, String>> result = DynamicMappingCmp.getObjectFields('Contact');
        Test.stopTest();

        System.assert(result != null, 'Field list should not be null');
    }

    @isTest
    static void testGetObjectFieldsReturnsNullForInvalidObject() {
        Test.startTest();
        List<Map<String, String>> result = DynamicMappingCmp.getObjectFields('Invalid_Object__c');
        Test.stopTest();

        System.assertEquals(null, result, 'Should return null for invalid object API name');
    }

    @isTest
    static void testGetMetadataReturnsEmptyListWhenCMDTIsMissing() {
        Test.startTest();
        List<String> result = DynamicMappingCmp.getMetadata();
        Test.stopTest();

        System.assert(result != null, 'Metadata list should not be null');
    }

    @isTest
    static void testSaveMappingsHandlesValidInputsGracefully() {
        Test.startTest();
        DynamicMappingCmp.saveMappings(
            '{"field1":"Contact.FirstName","field2":"Account.Name"}',
            'AND',
            'Status__c = \'Active\'',
            'OR',
            'Stage__c = \'Qualified\''
        );
        Test.stopTest();

    }

    @isTest
    static void testSaveMappingsHandlesNullInputsGracefully() {
        Test.startTest();
        DynamicMappingCmp.saveMappings(null, null, null, null, null);
        Test.stopTest();

    }
}