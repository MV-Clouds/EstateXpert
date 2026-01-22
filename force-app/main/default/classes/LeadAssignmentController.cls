public with sharing class LeadAssignmentController {
    @AuraEnabled
    public static LeadAssignmentInitData getLeadAssignmentInitData(String objectName) {
        LeadAssignmentInitData result = new LeadAssignmentInitData();
        try {
            // Get object fields with picklist values
            Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(objectName).getDescribe().fields.getMap();
            for (Schema.SObjectField field : fieldMap.values()) {
                Schema.DescribeFieldResult describe = field.getDescribe();
                String referenceTo = describe.getReferenceTo().size() > 0 ? String.valueOf(describe.getReferenceTo()[0]) : null;
                FieldWrapper fw = new FieldWrapper(
                    describe.getLabel(),
                    describe.getName(),
                    String.valueOf(describe.getType()),
                    referenceTo
                );
                // Add picklist values if applicable
                if (describe.getType() == Schema.DisplayType.Picklist || describe.getType() == Schema.DisplayType.MultiPicklist) {
                    List<String> picklistValues = new List<String>();
                    for (Schema.PicklistEntry entry : describe.getPicklistValues()) {
                        if (entry.isActive()) {
                            picklistValues.add(entry.getValue());
                        }
                    }
                    fw.picklistValues = picklistValues;
                }
                result.objectFields.add(fw);
            }

            String clarUsers = System.Label.CLAR_Users;
            Map<String, Object> clarUsersMap = (Map<String, Object>)JSON.deserializeUntyped(clarUsers);

            Boolean isProfile = clarUsersMap.containsKey('isProfile') ? (Boolean)clarUsersMap.get('isProfile') : false;
            Boolean isRole = clarUsersMap.containsKey('isRole') ? (Boolean)clarUsersMap.get('isRole') : false;
            List<Object> profileNames = clarUsersMap.containsKey('Profiles') ? (List<Object>)clarUsersMap.get('Profiles') : new List<Object>();
            List<Object> roleNames = clarUsersMap.containsKey('Roles') ? (List<Object>)clarUsersMap.get('Roles') : new List<Object>();

            // Convert List<Object> to List<String>
            List<String> profiles = new List<String>();
            for (Object p : profileNames) {
                profiles.add((String)p);
            }
            List<String> roles = new List<String>();
            for (Object r : roleNames) {
                roles.add((String)r);
            }

            String userQuery = 'SELECT Id, Name FROM User WHERE IsActive = true';
            if (isProfile && !profiles.isEmpty()) {
                userQuery += ' AND Profile.Name IN :profiles';
            }
            if (isRole && !roles.isEmpty()) {
                userQuery += ' AND UserRole.Name IN :roles';
            }
            userQuery += ' WITH USER_MODE ORDER BY Name';

            result.users = Database.query(userQuery);

            // Get rules
            result.rules = [SELECT Id, Name, Conditions__c, Logic_Type__c, Logical_Expression__c, User_Order__c, Object_Name__c, Do_Not_Reassign_Owner__c
                            FROM Lead_Assignment_Setting__c WHERE Object_Name__c = 'Contact' WITH USER_MODE ORDER BY User_Order__c];

            return result;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'LeadAssignmentController', 'getLeadAssignmentInitData', 'Error while fetching init data.');
            return new LeadAssignmentInitData();
        }
    }

    @AuraEnabled
    public static String manageRule(String operation, Object ruleData) {
        try {
            if (String.isBlank(operation)) {
                return 'Operation name is required.';
            }

            if (ruleData == null) {
                return 'Rule data is required.';
            }

            String operationLower = operation.toLowerCase();
            String jsonString = JSON.serialize(ruleData);

            if (operationLower == 'insert') {
                Map<String, Object> rule = (Map<String, Object>)JSON.deserializeUntyped(jsonString);
                Lead_Assignment_Setting__c newRule = new Lead_Assignment_Setting__c();
                newRule.Name = (String)rule.get('Name');
                newRule.Conditions__c = (String)rule.get('Conditions');
                newRule.Object_Name__c = (String)rule.get('Object_Name');
                newRule.Logic_Type__c = (String)rule.get('Logic_Type');
                newRule.Logical_Expression__c = (String)rule.get('Logical_Expression');
                newRule.User_Order__c = Integer.valueOf(rule.get('User_Order'));
                newRule.Do_Not_Reassign_Owner__c = Boolean.valueOf(rule.get('Do_Not_Reassign_Owner'));

                insert as user newRule;
                return newRule.Id;
            } else if (operationLower == 'update') {
                Map<String, Object> rule = (Map<String, Object>)JSON.deserializeUntyped(jsonString);
                if (!rule.containsKey('Id') || String.isBlank((String)rule.get('Id'))) {
                    return 'Valid rule ID is required for update.';
                }
                Lead_Assignment_Setting__c existingRule = new Lead_Assignment_Setting__c();
                existingRule.Id = (String)rule.get('Id');
                existingRule.Name = (String)rule.get('Name');
                existingRule.Conditions__c = (String)rule.get('Conditions');
                existingRule.Object_Name__c = (String)rule.get('Object_Name');
                existingRule.Logic_Type__c = (String)rule.get('Logic_Type');
                existingRule.Logical_Expression__c = (String)rule.get('Logical_Expression');
                existingRule.User_Order__c = Integer.valueOf(rule.get('User_Order'));
                existingRule.Do_Not_Reassign_Owner__c = Boolean.valueOf(rule.get('Do_Not_Reassign_Owner'));

                update as user existingRule;
                return existingRule.Id;
            } else if (operationLower == 'save') {
                List<Object> rules = (List<Object>)JSON.deserializeUntyped(jsonString);
                if (rules == null || rules.isEmpty()) {
                    return 'No rules provided to save.';
                }
                List<Lead_Assignment_Setting__c> rulesToUpdate = new List<Lead_Assignment_Setting__c>();
                for (Object ruleObj : rules) {
                    Map<String, Object> ruleMap = (Map<String, Object>)ruleObj;
                    if (!ruleMap.containsKey('Id') || String.isBlank((String)ruleMap.get('Id'))) {
                        return 'Valid rule ID is required for order update.';
                    }
                    Lead_Assignment_Setting__c rule = new Lead_Assignment_Setting__c();
                    rule.Id = (String)ruleMap.get('Id');
                    rule.User_Order__c = Integer.valueOf(ruleMap.get('User_Order'));
                    rulesToUpdate.add(rule);
                }
                if (!rulesToUpdate.isEmpty()) {
                    update as user rulesToUpdate;
                }
                return 'Success';
            } else if (operationLower == 'delete') {
                Map<String, Object> rule = (Map<String, Object>)JSON.deserializeUntyped(jsonString);
                String ruleId = (String)rule.get('Id');
                if (String.isBlank(ruleId)) {
                    return 'Rule ID is required for deletion.';
                }
                List<Lead_Assignment_Setting__c> rulesToDelete = [
                    SELECT Id FROM Lead_Assignment_Setting__c 
                    WHERE Id = :ruleId AND Object_Name__c = 'Contact' 
                    WITH USER_MODE LIMIT 1
                ];
                if (!rulesToDelete.isEmpty()) {
                    delete as user rulesToDelete;
                } else {
                    return 'Rule not found for Rule ID: ' + ruleId;
                }
                return 'Success';
            } else {
                return 'Invalid operation: ' + operation;
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'LeadAssignmentController', 'manageRule', 'Error during ' + operation + ' operation.');
            return e.getMessage();
        }
    }

    public class LeadAssignmentInitData {
        @AuraEnabled public List<FieldWrapper> objectFields = new List<FieldWrapper>();
        @AuraEnabled public List<User> users = new List<User>();
        @AuraEnabled public List<Lead_Assignment_Setting__c> rules = new List<Lead_Assignment_Setting__c>();
    }

    public class FieldWrapper {
        @AuraEnabled public String label;
        @AuraEnabled public String apiName;
        @AuraEnabled public String dataType;
        @AuraEnabled public String referenceTo;
        @AuraEnabled public List<String> picklistValues;

        public FieldWrapper(String label, String apiName, String dataType, String referenceTo) {
            this.label = label;
            this.apiName = apiName;
            this.dataType = dataType;
            this.referenceTo = referenceTo;
            this.picklistValues = new List<String>();
        }
    }
}