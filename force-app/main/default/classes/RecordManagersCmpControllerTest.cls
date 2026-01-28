@IsTest
public class RecordManagersCmpControllerTest {
    
    @TestSetup
    static void setupTestData() {
        // Create Manager Config for Listing
        Configuration_Settings__c listingConfig = new Configuration_Settings__c(
            Name = 'Listing_Manager_MVEX__Listing__c',
            Object_API_Name__c = 'MVEX__Listing__c',
            Feature_Name__c = 'Listing Manager',
            Configuration_Type__c = 'Manager Config',
            Fields_Data__c = '[{"label":"Name","value":"Name"},{"label":"Status","value":"Status__c"}]',
            Page_Size__c = 25
        );
        insert listingConfig;

        // Create New Record Fields Config
        Configuration_Settings__c newFieldsConfig = new Configuration_Settings__c(
            Name = 'NewFields_MVEX__Listing__c',
            Object_API_Name__c = 'MVEX__Listing__c',
            Configuration_Type__c = 'New Record Fields',
            Fields_Data__c = '[{"label":"Property","value":"Property__c"}]'
        );
        insert newFieldsConfig;

        // Create Global Config with Blocked Fields
        Configuration_Settings__c globalConfig = new Configuration_Settings__c(
            Name = 'Global_Listing_Filter',
            Configuration_Type__c = 'Global Config',
            Feature_Name__c = 'Listing Filter Config',
            Blocked_Fields__c = 'Password__c;SSN__c;CreditCard__c'
        );
        insert globalConfig;

        // Create Inquiry Config
        Configuration_Settings__c inquiryConfig = new Configuration_Settings__c(
            Name = 'Inquiry_Manager_MVEX__Inquiry__c',
            Object_API_Name__c = 'MVEX__Inquiry__c',
            Feature_Name__c = 'Inquiry Manager',
            Configuration_Type__c = 'Manager Config',
            Fields_Data__c = '[{"label":"Name","value":"Name"}]',
            Page_Size__c = 30
        );
        insert inquiryConfig;

        // Create Listing Configuration
        Configuration_Settings__c listingConfigSpecial = new Configuration_Settings__c(
            Name = 'Listing_Config_Special',
            Object_API_Name__c = 'MVEX__Listing__c',
            Feature_Name__c = 'Listing_Configuration',
            Configuration_Type__c = 'Manager Config',
            Fields_Data__c = '[{"label":"Config Field","value":"ConfigField__c"}]',
            Page_Size__c = 40
        );
        insert listingConfigSpecial;
    }
    
    @IsTest
    static void testGetListingFieldsParent() {
        Test.startTest();
        List<RecordManagersCmpController.FieldDetails> result = RecordManagersCmpController.getListingFieldsParent('Account');
        Test.stopTest();

        System.assertNotEquals(null, result, 'The result should not be null.');
        System.assertNotEquals(0, result.size(), 'There should be some fields returned.');
    }

    @IsTest
    static void testGetListingFieldsParentWithBlockedFields() {
        Test.startTest();
        List<RecordManagersCmpController.FieldDetails> result = RecordManagersCmpController.getListingFieldsParent('MVEX__Listing__c');
        Test.stopTest();

        System.assertNotEquals(null, result, 'The result should not be null.');
        
        // Verify blocked fields are excluded
        for (RecordManagersCmpController.FieldDetails field : result) {
            System.assertNotEquals('Password__c', field.value, 'Blocked field should not be included');
            System.assertNotEquals('SSN__c', field.value, 'Blocked field should not be included');
        }
    }

    @IsTest
    static void testGetListingFieldsParentWithPicklistAndReference() {
        Test.startTest();
        List<RecordManagersCmpController.FieldDetails> result = RecordManagersCmpController.getListingFieldsParent('Contact');
        Test.stopTest();

        System.assertNotEquals(null, result, 'The result should not be null.');
        
        Boolean hasPicklist = false;
        Boolean hasReference = false;
        
        for (RecordManagersCmpController.FieldDetails field : result) {
            if (field.picklistValues != null && !field.picklistValues.isEmpty()) {
                hasPicklist = true;
            }
            if (field.referenceObjectName != null && field.referenceObjectName != 'Contact') {
                hasReference = true;
            }
        }
        
        System.assert(hasPicklist || hasReference, 'Should have picklist or reference fields');
    }
    
    @IsTest
    static void testSaveMappings() {
        Test.startTest();
        String checklistData = '[{"label":"Test Field","value":"TestField__c"}]';
        Integer totalPages = 5;
        RecordManagersCmpController.saveMappings(checklistData, totalPages, 'MVEX__Listing__c', 'test');
        Test.stopTest();

        List<Configuration_Settings__c> configs = [
            SELECT Id, Fields_Data__c, Page_Size__c 
            FROM Configuration_Settings__c 
            WHERE Object_API_Name__c = 'MVEX__Listing__c' 
            AND Feature_Name__c = 'Listing Manager'
            AND Configuration_Type__c = 'Manager Config'
        ];
        
        System.assertEquals(1, configs.size(), 'Config should be updated');
        System.assertEquals(5, configs[0].Page_Size__c, 'Page size should be updated');
    }

    @IsTest
    static void testSaveMappingsInsert() {
        // Delete existing config to test insert path
        delete [SELECT Id FROM Configuration_Settings__c WHERE Object_API_Name__c = 'Contact'];
        
        Test.startTest();
        String checklistData = '[{"label":"Name","value":"Name"}]';
        Integer totalPages = 10;
        RecordManagersCmpController.saveMappings(checklistData, totalPages, 'Contact', 'test');
        Test.stopTest();

        List<Configuration_Settings__c> configs = [
            SELECT Id, Fields_Data__c, Page_Size__c 
            FROM Configuration_Settings__c 
            WHERE Object_API_Name__c = 'Contact'
        ];
        
        System.assertEquals(1, configs.size(), 'New config should be inserted');
        System.assertEquals(10, configs[0].Page_Size__c, 'Page size should be set');
    }

    @IsTest
    static void testSaveMappingsInquiry() {
        Test.startTest();
        String checklistData = '[{"label":"Inquiry Field","value":"InquiryField__c"}]';
        Integer totalPages = 15;
        RecordManagersCmpController.saveMappings(checklistData, totalPages, 'MVEX__Inquiry__c', 'test');
        Test.stopTest();

        List<Configuration_Settings__c> configs = [
            SELECT Id, Feature_Name__c 
            FROM Configuration_Settings__c 
            WHERE Object_API_Name__c = 'MVEX__Inquiry__c'
            AND Feature_Name__c = 'Inquiry Manager'
        ];
        
        System.assertEquals(1, configs.size(), 'Inquiry config should exist');
    }

    @IsTest
    static void testSaveMappingsListingConfiguration() {
        Test.startTest();
        String checklistData = '[{"label":"Config","value":"Config__c"}]';
        Integer totalPages = 20;
        RecordManagersCmpController.saveMappings(checklistData, totalPages, 'MVEX__Listing__c', 'Listing_Configuration');
        Test.stopTest();

        List<Configuration_Settings__c> configs = [
            SELECT Id, Feature_Name__c 
            FROM Configuration_Settings__c 
            WHERE Object_API_Name__c = 'MVEX__Listing__c'
            AND Feature_Name__c = 'Listing_Configuration'
        ];
        
        System.assertEquals(1, configs.size(), 'Listing Configuration should exist');
    }

    @IsTest
    static void testGetObjectFields() {
        Test.startTest();
        RecordManagersCmpController.RecordManagerData results = RecordManagersCmpController.getObjectFields('MVEX__Listing__c', 'Test F');
        Test.stopTest();

        System.assertNotEquals(null, results, 'The result should not be null.');
        System.assertNotEquals(null, results.fieldDetailsList, 'Field details list should not be null');
        System.assertNotEquals(null, results.metadataRecords, 'Metadata records should not be null');
        System.assertEquals(2, results.metadataRecords.size(), 'Should have fields data and page size');
    }

    @IsTest
    static void testGetObjectFieldsInquiry() {
        Test.startTest();
        RecordManagersCmpController.RecordManagerData results = RecordManagersCmpController.getObjectFields('MVEX__Inquiry__c', 'test');
        Test.stopTest();

        System.assertNotEquals(null, results, 'The result should not be null.');
        System.assertNotEquals(null, results.metadataRecords, 'Metadata records should not be null');
    }

    @IsTest
    static void testGetObjectFieldsNoConfig() {
        Test.startTest();
        RecordManagersCmpController.RecordManagerData results = RecordManagersCmpController.getObjectFields('Account', 'test');
        Test.stopTest();

        System.assertNotEquals(null, results, 'The result should not be null.');
        System.assertNotEquals(null, results.fieldDetailsList, 'Field details list should not be null');
        System.assertEquals(0, results.metadataRecords.size(), 'Should have no metadata when config doesnt exist');
    }

    @IsTest
    static void testGetObjectFieldsWithMetaData() {
        Test.startTest();
        RecordManagersCmpController.RecordManagerData results = RecordManagersCmpController.getObjectFieldsWithMetaData('MVEX__Listing__c');
        Test.stopTest();

        System.assertNotEquals(null, results, 'The result should not be null.');
        System.assertNotEquals(null, results.fieldDetailsList, 'Field details list should not be null');
        System.assertNotEquals(null, results.metadataRecords, 'Metadata records should not be null');
        System.assertEquals(1, results.metadataRecords.size(), 'Should have new record fields data');
    }

    @IsTest
    static void testGetObjectFieldsWithMetaDataNoConfig() {
        Test.startTest();
        RecordManagersCmpController.RecordManagerData results = RecordManagersCmpController.getObjectFieldsWithMetaData('Account');
        Test.stopTest();

        System.assertNotEquals(null, results, 'The result should not be null.');
        System.assertEquals(0, results.metadataRecords.size(), 'Should have no metadata when config doesnt exist');
    }

    @IsTest
    static void testSaveMappingsNewFieldsInsert() {
        // Delete existing to test insert
        delete [SELECT Id FROM Configuration_Settings__c WHERE Configuration_Type__c = 'New Record Fields' AND Object_API_Name__c = 'Account'];
        
        Test.startTest();
        String selectFieldsData = '[{"label":"Account Name","value":"Name"}]';
        String result = RecordManagersCmpController.saveMappingsNewFields(selectFieldsData, 'Account');
        Test.stopTest();

        System.assertEquals('success', result, 'Should return success');
        
        List<Configuration_Settings__c> configs = [
            SELECT Id, Fields_Data__c 
            FROM Configuration_Settings__c 
            WHERE Object_API_Name__c = 'Account'
            AND Configuration_Type__c = 'New Record Fields'
        ];
        
        System.assertEquals(1, configs.size(), 'New record fields config should be inserted');
    }

    @IsTest
    static void testSaveMappingsNewFieldsUpdate() {
        Test.startTest();
        String selectFieldsData = '[{"label":"Updated Field","value":"UpdatedField__c"}]';
        String result = RecordManagersCmpController.saveMappingsNewFields(selectFieldsData, 'MVEX__Listing__c');
        Test.stopTest();

        System.assertEquals('success', result, 'Should return success');
        
        List<Configuration_Settings__c> configs = [
            SELECT Id, Fields_Data__c 
            FROM Configuration_Settings__c 
            WHERE Object_API_Name__c = 'MVEX__Listing__c'
            AND Configuration_Type__c = 'New Record Fields'
        ];
        
        System.assertEquals(1, configs.size(), 'Config should be updated');
        System.assert(configs[0].Fields_Data__c.contains('UpdatedField__c'), 'Fields data should be updated');
    }

    @IsTest
    static void testGetObjectFieldsWithReferenceAndPicklist() {
        Test.startTest();
        RecordManagersCmpController.RecordManagerData results = RecordManagersCmpController.getObjectFields('Contact', 'test');
        Test.stopTest();

        System.assertNotEquals(null, results, 'The result should not be null.');
        
        Boolean hasReferenceField = false;
        Boolean hasPicklistField = false;
        
        for (RecordManagersCmpController.FieldDetails field : results.fieldDetailsList) {
            if (field.relationshipName != null) {
                hasReferenceField = true;
            }
            if (field.picklistValues != null && !field.picklistValues.isEmpty()) {
                hasPicklistField = true;
                System.assertNotEquals(null, field.picklistValues[0].label, 'Picklist label should not be null');
                System.assertNotEquals(null, field.picklistValues[0].value, 'Picklist value should not be null');
            }
        }
        
        System.assert(hasReferenceField || hasPicklistField, 'Should have reference or picklist fields');
    }

    @IsTest
    static void testGetListingFieldsParentNoBlockedConfig() {
        // Delete global config to test without blocked fields
        delete [SELECT Id FROM Configuration_Settings__c WHERE Configuration_Type__c = 'Global Config'];
        
        Test.startTest();
        List<RecordManagersCmpController.FieldDetails> result = RecordManagersCmpController.getListingFieldsParent('MVEX__Listing__c');
        Test.stopTest();

        System.assertNotEquals(null, result, 'The result should not be null.');
        System.assertNotEquals(0, result.size(), 'Should return fields even without blocked config');
    }

    @IsTest
    static void testGetObjectFieldsMarketingList() {
        // Test Marketing List feature name mapping
        Test.startTest();
        RecordManagersCmpController.RecordManagerData results = RecordManagersCmpController.getObjectFields('Contact', 'Marketing List Test');
        Test.stopTest();

        System.assertNotEquals(null, results, 'The result should not be null.');
    }
}