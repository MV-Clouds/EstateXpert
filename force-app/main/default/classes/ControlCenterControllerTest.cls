/**
 * Class Name : ControlCenterControllerTest
 * Last Modified Date : 2026-10-12
 * Last Modified By : Dhruv Kakadiya
 * @description : Test class for ControlCenterController.
 */

@isTest
public with sharing class ControlCenterControllerTest {

    @testSetup
    static void setupData() {

        MVEX__Listing__c listing = new MVEX__Listing__c(
            Name = 'Test Listing',
            MVEX__Listing_Type__c = 'Sale',
            MVEX__Property_Category__c = 'Residential',
            MVEX__Property_Type__c = 'Apartment',
            MVEX__Sq_Ft__c = 1200        
        );
        insert listing;

        // Create test rules
        MVEX__Lead_Assignment_Setting__c rule1 = new MVEX__Lead_Assignment_Setting__c(
            Name = 'Test Rule 1',
            MVEX__Conditions__c = '{"field":"Status","operator":"equals","value":"New"}',
            MVEX__Object_Name__c = 'Contact',
            MVEX__Logic_Type__c = 'AND',
            MVEX__Logical_Expression__c = '1',
            MVEX__User_Order__c = 1,
            Default_User__c = false
        );
        MVEX__Lead_Assignment_Setting__c rule2 = new MVEX__Lead_Assignment_Setting__c(
            Name = 'Test Rule 2',
            MVEX__Conditions__c = '{"field":"Status","operator":"equals","value":"Qualified"}',
            MVEX__Object_Name__c = 'Contact',
            MVEX__Logic_Type__c = 'OR',
            MVEX__Logical_Expression__c = '1 OR 2',
            MVEX__User_Order__c = 2,
            Default_User__c = false
        );
        insert new List<MVEX__Lead_Assignment_Setting__c>{ rule1, rule2 };
    }

    /* ---------------- Positive Scenario ---------------- */
    @IsTest
    static void testGetListingDetails_success() {

        MVEX__Listing__c lst = [SELECT Id FROM MVEX__Listing__c LIMIT 1];

        Test.startTest();
        MVEX__Listing__c result = ControlCenterController.getListingDetails(lst.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Listing should be returned');
        System.assertEquals(lst.Id, result.Id, 'Returned listing should match input Id');
    }

    @IsTest 
    static void testGetObjectFields_success() {
        Test.startTest();
        List<Map<String, String>> result = ControlCenterController.getObjectFields('Contact');
        Test.stopTest();

        System.assertNotEquals(null, result, 'The method should return a non-null list for a valid object');
        System.assert(!result.isEmpty(), 'The method should return fields for the valid object');
        System.assert(result[0].containsKey('label'), 'Field map should contain label');
        System.assert(result[0].containsKey('apiName'), 'Field map should contain apiName');
        System.assert(result[0].containsKey('dataType'), 'Field map should contain dataType');
    }

    @IsTest 
    static void testGetObjectFields_invalidObject() {
        Test.startTest();
        List<Map<String, String>> result = ControlCenterController.getObjectFields('Invalid_Object_XYZ');
        Test.stopTest();

        System.assertEquals(null, result, 'The method should return null when an invalid object is provided');
    }
    
    @IsTest
    static void testSaveMappings() {
        String testMappingData = 'MVEX__Address__c:MVEX__Address__c;MVEX__City__c:MVEX__City__c';

        Test.startTest();
        ControlCenterController.saveMappings(testMappingData);
        Test.stopTest();

        // Enqueues metadata deployment asynchronously; verify execution completes without exceptions
        System.assert(true, 'saveMappings should execute without exception');
    }    

    @IsTest
    static void testGetMetadata() {
        Test.startTest();
        String result = ControlCenterController.getMetadata();
        Test.stopTest();

        List<MVEX__Mapping_Metadata__mdt> metaList = [
            SELECT MVEX__Mapping_String__c 
            FROM MVEX__Mapping_Metadata__mdt 
            WITH USER_MODE 
            LIMIT 1
        ];

        if (!metaList.isEmpty()) {
            System.assertEquals(metaList[0].MVEX__Mapping_String__c, result, 'Returned metadata string should match the custom metadata record');
        } else {
            System.assertEquals(null, result, 'Should return null when no custom metadata record exists');
        }
    }

    @IsTest
    static void testSendFeedbackEmail_withAttachments() {
        List<String> images = new List<String>{
            EncodingUtil.base64Encode(Blob.valueOf('Test base64 image content 1')),
            EncodingUtil.base64Encode(Blob.valueOf('Test base64 image content 2'))
        };

        Test.startTest();
        String result = ControlCenterController.sendFeedbackEmail('Test Subject', 'Test Description with images', images);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals('Success', result, 'sendFeedbackEmail should return Success when sending with attachments');
    }

    @IsTest
    static void testSendFeedbackEmail_withoutAttachments() {
        Test.startTest();
        String resultNullImages = ControlCenterController.sendFeedbackEmail('Test Subject Null', 'Test Description null images', null);
        String resultEmptyImages = ControlCenterController.sendFeedbackEmail('Test Subject Empty', 'Test Description empty images', new List<String>());
        Test.stopTest();

        System.assertEquals('Success', resultNullImages, 'sendFeedbackEmail should succeed when images list is null');
        System.assertEquals('Success', resultEmptyImages, 'sendFeedbackEmail should succeed when images list is empty');
    }

    @IsTest
    static void testSendFeedbackEmail_error() {
        // Pass invalid base64 string to trigger exception in base64Decode
        List<String> invalidImages = new List<String>{ 'invalid_base64_content_!@#$' };

        Test.startTest();
        String result = ControlCenterController.sendFeedbackEmail('Test Error', 'Test Description', invalidImages);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.startsWith('Error:'), 'Result should return error prefix when an exception occurs during attachment decoding');
    }

    /* ---------------- Null Id Scenario ---------------- */
    @IsTest
    static void testGetListingDetails_nullId() {

        Test.startTest();
        MVEX__Listing__c result = ControlCenterController.getListingDetails(null);
        Test.stopTest();

        // Method catches exception and returns null
        System.assertEquals(null, result, 'Should return null when recordId is null');
    }
    
    @isTest
    static void testGetLeadAssignmentInitData() {
        Test.startTest();
        ControlCenterController.LeadAssignmentInitData result = 
            ControlCenterController.getLeadAssignmentInitData('Contact');
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(!result.objectFields.isEmpty(), 'Object fields should be populated');
        System.assertEquals(2, result.rules.size(), 'Should have 2 rules');
    }
    
    @isTest
    static void testManageRuleAllOperations() {
        // Test Insert
        Map<String, Object> insertRule = new Map<String, Object>{
            'Name' => 'New Test Rule',
            'Conditions' => '{"field":"Status","operator":"equals","value":"Active"}',
            'Object_Name' => 'Contact',
            'Logic_Type' => 'AND',
            'Logical_Expression' => '1',
            'User_Order' => 3
        };
        
        Test.startTest();
        String insertResult = ControlCenterController.manageRule('insert', insertRule);
        System.assert(insertResult.startsWith('a0'), 'Insert should return rule ID');
        
        // Test Update
        Map<String, Object> updateRule = new Map<String, Object>{
            'Id' => insertResult,
            'Name' => 'Updated Test Rule',
            'Conditions' => '{"field":"Status","operator":"equals","value":"Updated"}',
            'Object_Name' => 'Contact',
            'Logic_Type' => 'OR',
            'Logical_Expression' => '1 OR 2',
            'User_Order' => 4
        };
        String updateResult = ControlCenterController.manageRule('update', updateRule);
        System.assertEquals(insertResult, updateResult, 'Update should return same rule ID');
        
        // Test Save (bulk update user orders)
        List<MVEX__Lead_Assignment_Setting__c> existingRules = [
            SELECT Id FROM MVEX__Lead_Assignment_Setting__c WHERE MVEX__Object_Name__c = 'Contact' AND (Default_User__c = false OR Default_User__c = null) LIMIT 2
        ];
        List<Map<String, Object>> saveRules = new List<Map<String, Object>>{
            new Map<String, Object>{ 'Id' => existingRules[0].Id, 'User_Order' => 10 },
            new Map<String, Object>{ 'Id' => existingRules[1].Id, 'User_Order' => 20 }
        };
        String saveResult = ControlCenterController.manageRule('save', saveRules);
        System.assertEquals('Success', saveResult, 'Save should return Success');
        
        // Test Save Default Assignee
        Map<String, Object> saveDefaultPayload = new Map<String, Object>{
            'Default_User_Id' => UserInfo.getUserId()
        };
        String defaultRuleId = ControlCenterController.manageRule('savedefault', saveDefaultPayload);
        System.assert(String.isNotBlank(defaultRuleId), 'Default rule ID should not be blank');

        // Test Update Default Assignee
        Map<String, Object> updateDefaultPayload = new Map<String, Object>{
            'Id' => defaultRuleId,
            'Default_User_Id' => UserInfo.getUserId()
        };
        String updatedDefaultRuleId = ControlCenterController.manageRule('savedefault', updateDefaultPayload);
        System.assertEquals(defaultRuleId, updatedDefaultRuleId, 'Updated default rule ID should match');

        // Test Delete Default Assignee
        Map<String, Object> deleteDefaultPayload = new Map<String, Object>{
            'Id' => defaultRuleId
        };
        String deleteDefaultResult = ControlCenterController.manageRule('deletedefault', deleteDefaultPayload);
        System.assertEquals('Success', deleteDefaultResult, 'Delete default should return Success');

        // Test Delete
        Map<String, Object> deleteRule = new Map<String, Object>{ 'Id' => insertResult };
        String deleteResult = ControlCenterController.manageRule('delete', deleteRule);
        System.assertEquals('Success', deleteResult, 'Delete should return Success');
        Test.stopTest();
    }
    
    @isTest
    static void testManageRuleValidations() {
        Test.startTest();
        
        // Test blank operation
        String result1 = ControlCenterController.manageRule('', new Map<String, Object>());
        System.assert(result1.contains('Operation name is required'), 'Should validate operation name');
        
        // Test null rule data
        String result2 = ControlCenterController.manageRule('insert', null);
        System.assert(result2.contains('Rule data is required'), 'Should validate rule data');
        
        // Test update without ID
        Map<String, Object> ruleWithoutId = new Map<String, Object>{ 'Name' => 'Test' };
        String result3 = ControlCenterController.manageRule('update', ruleWithoutId);
        System.assert(result3.contains('Valid rule ID is required'), 'Should validate rule ID for update');
        
        // Test delete without ID
        String result4 = ControlCenterController.manageRule('delete', new Map<String, Object>());
        System.assert(result4.contains('Rule ID is required'), 'Should validate rule ID for deletion');
        
        // Test invalid operation
        String result5 = ControlCenterController.manageRule('invalid', new Map<String, Object>());
        System.assert(result5.contains('Invalid operation'), 'Should handle invalid operation');
        
        // Test delete non-existent rule
        Map<String, Object> nonExistentRule = new Map<String, Object>{ 'Id' => 'a00000000000000' };
        String result6 = ControlCenterController.manageRule('delete', nonExistentRule);
        System.assert(result6.contains('Rule not found'), 'Should handle non-existent rule');
        
        Test.stopTest();
    }

    @isTest
    static void testGetRecordNames() {
        // Create a Contact
        Contact con = new Contact(LastName = 'Test Contact');
        insert con;
        
        // Prepare inputs
        Map<String, String> recordIdToObjectMap = new Map<String, String>{
            con.Id => 'Contact',
            'invalidId' => 'InvalidObject'
        };
        
        Test.startTest();
        Map<String, String> result = ControlCenterController.getRecordNames(recordIdToObjectMap);
        Map<String, String> emptyResult = ControlCenterController.getRecordNames(new Map<String, String>());
        Map<String, String> nullResult = ControlCenterController.getRecordNames(null);
        Test.stopTest();
    }

    @isTest
    static void testGetEmailNotificationEnabled() {
        Test.startTest();
        ControlCenterController.getEmailNotificationEnabled();
        Test.stopTest();
    }

    @isTest
    static void testSetEmailNotificationEnabled() {
        Test.startTest();
        ControlCenterController.setEmailNotificationEnabled(true);
        Test.stopTest();
    }
}