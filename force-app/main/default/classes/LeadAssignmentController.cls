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
            result.rules = [SELECT Id, Name, MVEX__Conditions__c, MVEX__Logic_Type__c, MVEX__Logical_Expression__c, MVEX__User_Order__c, MVEX__Object_Name__c
                            FROM MVEX__Lead_Assignment_Setting__c WHERE MVEX__Object_Name__c = 'Contact'  AND (Default_User__c = false OR Default_User__c = null) WITH USER_MODE ORDER BY MVEX__User_Order__c];

            // Get the default assignee record (Default_User__c = true; Name stores the userId)
            List<MVEX__Lead_Assignment_Setting__c> defaultRules = [
                SELECT Id, Name, Default_User__c
                FROM MVEX__Lead_Assignment_Setting__c
                WHERE MVEX__Object_Name__c = 'Contact' AND Default_User__c = true
                WITH USER_MODE LIMIT 1
            ];
            if (!defaultRules.isEmpty()) {
                result.defaultRule = defaultRules[0];
            }
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
                MVEX__Lead_Assignment_Setting__c newRule = new MVEX__Lead_Assignment_Setting__c();
                newRule.Name = (String)rule.get('Name');
                newRule.MVEX__Conditions__c = (String)rule.get('Conditions');
                newRule.MVEX__Object_Name__c = (String)rule.get('Object_Name');
                newRule.MVEX__Logic_Type__c = (String)rule.get('Logic_Type');
                newRule.MVEX__Logical_Expression__c = (String)rule.get('Logical_Expression');
                newRule.MVEX__User_Order__c = Integer.valueOf(rule.get('User_Order'));
                newRule.Default_User__c = false;

                insert as user newRule;
                return newRule.Id;
            } else if (operationLower == 'update') {
                Map<String, Object> rule = (Map<String, Object>)JSON.deserializeUntyped(jsonString);
                if (!rule.containsKey('Id') || String.isBlank((String)rule.get('Id'))) {
                    return 'Valid rule ID is required for update.';
                }
                MVEX__Lead_Assignment_Setting__c existingRule = new MVEX__Lead_Assignment_Setting__c();
                existingRule.Id = (String)rule.get('Id');
                existingRule.Name = (String)rule.get('Name');
                existingRule.MVEX__Conditions__c = (String)rule.get('Conditions');
                existingRule.MVEX__Object_Name__c = (String)rule.get('Object_Name');
                existingRule.MVEX__Logic_Type__c = (String)rule.get('Logic_Type');
                existingRule.MVEX__Logical_Expression__c = (String)rule.get('Logical_Expression');
                existingRule.MVEX__User_Order__c = Integer.valueOf(rule.get('User_Order'));

                update as user existingRule;
                return existingRule.Id;
            } else if (operationLower == 'save') {
                List<Object> rules = (List<Object>)JSON.deserializeUntyped(jsonString);
                if (rules == null || rules.isEmpty()) {
                    return 'No rules provided to save.';
                }
                List<MVEX__Lead_Assignment_Setting__c> rulesToUpdate = new List<MVEX__Lead_Assignment_Setting__c>();
                for (Object ruleObj : rules) {
                    Map<String, Object> ruleMap = (Map<String, Object>)ruleObj;
                    if (!ruleMap.containsKey('Id') || String.isBlank((String)ruleMap.get('Id'))) {
                        return 'Valid rule ID is required for order update.';
                    }
                    MVEX__Lead_Assignment_Setting__c rule = new MVEX__Lead_Assignment_Setting__c();
                    rule.Id = (String)ruleMap.get('Id');
                    rule.MVEX__User_Order__c = Integer.valueOf(ruleMap.get('User_Order'));
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
                List<MVEX__Lead_Assignment_Setting__c> rulesToDelete = [
                    SELECT Id FROM MVEX__Lead_Assignment_Setting__c 
                    WHERE Id = :ruleId AND MVEX__Object_Name__c = 'Contact'  
                    AND (Default_User__c = false OR Default_User__c = null)
                    WITH USER_MODE LIMIT 1
                ];
                if (!rulesToDelete.isEmpty()) {
                    delete as user rulesToDelete;
                } else {
                    return 'Rule not found for Rule ID: ' + ruleId;
                }
                return 'Success';
            } else if (operationLower == 'savedefault') {
                // upsert the default assignee record.
                Map<String, Object> rule = (Map<String, Object>)JSON.deserializeUntyped(jsonString);
                String defaultUserId = (String)rule.get('Default_User_Id');
                String existingId    = (String)rule.get('Id');

                if (String.isBlank(defaultUserId)) {
                    return 'Default User ID is required.';
                }

                MVEX__Lead_Assignment_Setting__c defaultRule = new MVEX__Lead_Assignment_Setting__c();
                if (String.isNotBlank(existingId)) {
                    defaultRule.Id = existingId;
                } else {
                    // Check if a default assignee record already exists in database
                    List<MVEX__Lead_Assignment_Setting__c> existingDefaults = [
                        SELECT Id FROM MVEX__Lead_Assignment_Setting__c
                        WHERE MVEX__Object_Name__c = 'Contact' AND Default_User__c = true
                        WITH USER_MODE LIMIT 1
                    ];
                    if (!existingDefaults.isEmpty()) {
                        defaultRule.Id = existingDefaults[0].Id;
                    }
                }
                defaultRule.Name                        = defaultUserId;  // userId stored in Name
                defaultRule.Default_User__c             = true;           // boolean flag
                defaultRule.MVEX__Object_Name__c        = 'Contact';
                defaultRule.MVEX__Conditions__c         = null;
                defaultRule.MVEX__Logic_Type__c         = null;
                defaultRule.MVEX__Logical_Expression__c = null;
                defaultRule.MVEX__User_Order__c         = null;

                upsert as user defaultRule;
                return defaultRule.Id;
            } else if (operationLower == 'deletedefault') {
                // Remove the default assignee record (identified by Default_User__c = true)
                Map<String, Object> rule = (Map<String, Object>)JSON.deserializeUntyped(jsonString);
                String defaultId = (String)rule.get('Id');
                List<MVEX__Lead_Assignment_Setting__c> toDelete;
                if (String.isNotBlank(defaultId)) {
                    toDelete = [
                        SELECT Id FROM MVEX__Lead_Assignment_Setting__c
                        WHERE Id = :defaultId AND Default_User__c = true
                        WITH USER_MODE LIMIT 1
                    ];
                } else {
                    toDelete = [
                        SELECT Id FROM MVEX__Lead_Assignment_Setting__c
                        WHERE MVEX__Object_Name__c = 'Contact' AND Default_User__c = true
                        WITH USER_MODE LIMIT 1
                    ];
                }
                if (!toDelete.isEmpty()) {
                    delete as user toDelete;
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

    /**
     * Bulk resolve record IDs to Names.
     * @param recordIdToObjectMap  Map of recordId (String) → objectApiName (String)
     * @return Map of recordId (String) → display name (String)
     */
    @AuraEnabled
    public static Map<String, String> getRecordNames(Map<String, String> recordIdToObjectMap) {
        Map<String, String> result = new Map<String, String>();
        if (recordIdToObjectMap == null || recordIdToObjectMap.isEmpty()) {
            return result;
        }

        // Group IDs by object so we can issue one query per object
        Map<String, List<String>> objectToIds = new Map<String, List<String>>();
        for (String recId : recordIdToObjectMap.keySet()) {
            String objName = recordIdToObjectMap.get(recId);
            if (String.isNotBlank(objName)) {
                if (!objectToIds.containsKey(objName)) {
                    objectToIds.put(objName, new List<String>());
                }
                objectToIds.get(objName).add(recId);
            }
        }

        for (String objName : objectToIds.keySet()) {
            try {
                // Check if the object has a Name field
                Map<String, Schema.SObjectField> fieldMap =
                    Schema.getGlobalDescribe().get(objName)?.getDescribe().fields.getMap();
                if (fieldMap == null || !fieldMap.containsKey('name')) {
                    // No Name field – fall back to ID for all records of this object
                    for (String recId : objectToIds.get(objName)) {
                        result.put(recId, recId);
                    }
                    continue;
                }

                List<String> ids = objectToIds.get(objName);
                String query = 'SELECT Id, Name FROM ' + objName + ' WHERE Id IN :ids WITH USER_MODE';
                List<SObject> records = Database.query(query);
                for (SObject rec : records) {
                    result.put((String)rec.get('Id'), (String)rec.get('Name'));
                }
            } catch (Exception e) {
                // If query fails, fall back to IDs
                for (String recId : objectToIds.get(objName)) {
                    result.put(recId, recId);
                }
            }
        }
        return result;
    }

    /**
     * Retrieves the email notification enabled setting for lead assignment.
     * Reads MVEX__Fields_Data__c ('true'/'false') from the config record
     * Name = 'Lead_Assignment_Notification'. Defaults to true if not found.
     */
    @AuraEnabled
    public static Boolean getEmailNotificationEnabled() {
        try {
            List<MVEX__Configuration_Settings__c> configs = [
                SELECT MVEX__Fields_Data__c
                FROM MVEX__Configuration_Settings__c
                WHERE Name = 'Lead_Assignment_Notification'
                WITH USER_MODE LIMIT 1
            ];
            if (!configs.isEmpty() && configs[0].MVEX__Fields_Data__c != null) {
                return configs[0].MVEX__Fields_Data__c.trim().equalsIgnoreCase('true');
            }
            return true; 
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'LeadAssignmentController', 'getEmailNotificationEnabled', 'Error fetching email notification setting.');
            return true;
        }
    }

    /**
     * Saves the email notification enabled setting for lead assignment.
     * Upserts a Configuration_Settings__c record keyed by Name = 'Lead_Assignment_Notification',
     * storing 'true' or 'false' in MVEX__Fields_Data__c.
     */
    @AuraEnabled
    public static void setEmailNotificationEnabled(Boolean isEnabled) {
        try {
            List<MVEX__Configuration_Settings__c> configs = [
                SELECT Id
                FROM MVEX__Configuration_Settings__c
                WHERE Name = 'Lead_Assignment_Notification'
                WITH USER_MODE LIMIT 1
            ];
            MVEX__Configuration_Settings__c config = configs.isEmpty()
                ? new MVEX__Configuration_Settings__c(Name = 'Lead_Assignment_Notification', MVEX__Feature_Name__c = 'Lead_Assignment_Notification')
                : configs[0];
            config.MVEX__Fields_Data__c = isEnabled ? 'true' : 'false';
            upsert as user config;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'LeadAssignmentController', 'setEmailNotificationEnabled', 'Error saving email notification setting.');
            throw e;
        }
    }

    public class LeadAssignmentInitData {
        @AuraEnabled public List<FieldWrapper> objectFields = new List<FieldWrapper>();
        @AuraEnabled public List<User> users = new List<User>();
        @AuraEnabled public List<MVEX__Lead_Assignment_Setting__c> rules = new List<MVEX__Lead_Assignment_Setting__c>();
        @AuraEnabled public MVEX__Lead_Assignment_Setting__c defaultRule;
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