@isTest
private class LeadAssignmentControllerTest {
    
    @testSetup
    static void setupTestData() {
        // Create test rules
        Lead_Assignment_Setting__c rule1 = new Lead_Assignment_Setting__c(
            Name = 'Test Rule 1',
            Conditions__c = '{"field":"Status","operator":"equals","value":"New"}',
            Object_Name__c = 'Contact',
            Logic_Type__c = 'AND',
            Logical_Expression__c = '1',
            User_Order__c = 1,
            Do_Not_Reassign_Owner__c = false
        );
        Lead_Assignment_Setting__c rule2 = new Lead_Assignment_Setting__c(
            Name = 'Test Rule 2',
            Conditions__c = '{"field":"Status","operator":"equals","value":"Qualified"}',
            Object_Name__c = 'Contact',
            Logic_Type__c = 'OR',
            Logical_Expression__c = '1 OR 2',
            User_Order__c = 2,
            Do_Not_Reassign_Owner__c = true
        );
        insert new List<Lead_Assignment_Setting__c>{ rule1, rule2 };
    }
    
    @isTest
    static void testGetLeadAssignmentInitData() {
        Test.startTest();
        LeadAssignmentController.LeadAssignmentInitData result = 
            LeadAssignmentController.getLeadAssignmentInitData('Contact');
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
            'User_Order' => 3,
            'Do_Not_Reassign_Owner' => false
        };
        
        Test.startTest();
        String insertResult = LeadAssignmentController.manageRule('insert', insertRule);
        System.assert(insertResult.startsWith('a0'), 'Insert should return rule ID');
        
        // Test Update
        Map<String, Object> updateRule = new Map<String, Object>{
            'Id' => insertResult,
            'Name' => 'Updated Test Rule',
            'Conditions' => '{"field":"Status","operator":"equals","value":"Updated"}',
            'Object_Name' => 'Contact',
            'Logic_Type' => 'OR',
            'Logical_Expression' => '1 OR 2',
            'User_Order' => 4,
            'Do_Not_Reassign_Owner' => true
        };
        String updateResult = LeadAssignmentController.manageRule('update', updateRule);
        System.assertEquals(insertResult, updateResult, 'Update should return same rule ID');
        
        // Test Save (bulk update user orders)
        List<Lead_Assignment_Setting__c> existingRules = [
            SELECT Id FROM Lead_Assignment_Setting__c WHERE Object_Name__c = 'Contact' LIMIT 2
        ];
        List<Map<String, Object>> saveRules = new List<Map<String, Object>>{
            new Map<String, Object>{ 'Id' => existingRules[0].Id, 'User_Order' => 10 },
            new Map<String, Object>{ 'Id' => existingRules[1].Id, 'User_Order' => 20 }
        };
        String saveResult = LeadAssignmentController.manageRule('save', saveRules);
        System.assertEquals('Success', saveResult, 'Save should return Success');
        
        // Test Delete
        Map<String, Object> deleteRule = new Map<String, Object>{ 'Id' => insertResult };
        String deleteResult = LeadAssignmentController.manageRule('delete', deleteRule);
        System.assertEquals('Success', deleteResult, 'Delete should return Success');
        Test.stopTest();
    }
    
    @isTest
    static void testManageRuleValidations() {
        Test.startTest();
        
        // Test blank operation
        String result1 = LeadAssignmentController.manageRule('', new Map<String, Object>());
        System.assert(result1.contains('Operation name is required'), 'Should validate operation name');
        
        // Test null rule data
        String result2 = LeadAssignmentController.manageRule('insert', null);
        System.assert(result2.contains('Rule data is required'), 'Should validate rule data');
        
        // Test update without ID
        Map<String, Object> ruleWithoutId = new Map<String, Object>{ 'Name' => 'Test' };
        String result3 = LeadAssignmentController.manageRule('update', ruleWithoutId);
        System.assert(result3.contains('Valid rule ID is required'), 'Should validate rule ID for update');
        
        // Test delete without ID
        String result4 = LeadAssignmentController.manageRule('delete', new Map<String, Object>());
        System.assert(result4.contains('Rule ID is required'), 'Should validate rule ID for deletion');
        
        // Test invalid operation
        String result5 = LeadAssignmentController.manageRule('invalid', new Map<String, Object>());
        System.assert(result5.contains('Invalid operation'), 'Should handle invalid operation');
        
        // Test delete non-existent rule
        Map<String, Object> nonExistentRule = new Map<String, Object>{ 'Id' => 'a00000000000000' };
        String result6 = LeadAssignmentController.manageRule('delete', nonExistentRule);
        System.assert(result6.contains('Rule not found'), 'Should handle non-existent rule');
        
        Test.stopTest();
    }
}