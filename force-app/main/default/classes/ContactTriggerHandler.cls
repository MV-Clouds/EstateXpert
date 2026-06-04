public without sharing class ContactTriggerHandler {
    public class Condition {
        @AuraEnabled
        public String Lead_Field { get; set; }
        @AuraEnabled
        public String Condition { get; set; }
        @AuraEnabled
        public String Value { get; set; }
        @AuraEnabled
        public Integer Order { get; set; }
    }

    private static Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get('Contact').getDescribe().fields.getMap();

    public static void handleLeadAssignment(List<Contact> newLeads, Map<Id, Contact> oldLeadMap) {
        try {
            List<Lead_Assignment_Setting__c> allRules = [
                SELECT Name, Conditions__c, Logic_Type__c, Logical_Expression__c, User_Order__c
                FROM Lead_Assignment_Setting__c
                ORDER BY User_Order__c ASC
            ];

            if (allRules.isEmpty()) {
                return;
            }

            Boolean isInsert = (oldLeadMap == null);


            List<Contact> leadsToProcess = new List<Contact>();
            for (Contact lead : newLeads) {
                if (isInsert && !lead.Is_Converted__c) {
                    leadsToProcess.add(lead);
                }
            }

            if (leadsToProcess.isEmpty()) {
                return;
            }

            User sysAdmin = null;
            List<User> sysAdmins = [SELECT Id FROM User WHERE Profile.Name = 'System Administrator' AND IsActive = TRUE LIMIT 1];
            if (!sysAdmins.isEmpty()) {
                sysAdmin = sysAdmins[0];
            }

            for (Contact lead : leadsToProcess) {
                Boolean isAssigned = false;
                for (Lead_Assignment_Setting__c rule : allRules) {
                    Boolean isMatch = evaluateRule(lead, rule, fieldMap);
                    if (isMatch) {
                        lead.OwnerId = rule.Name;
                        isAssigned = true;
                        break;
                    }
                }
                if (!isAssigned && sysAdmin != null) {
                    lead.OwnerId = sysAdmin.Id;
                }
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'LeadAssignmentHandler', 'handleLeadAssignment', 'Error during handleLeadAssignment');
        }
    }

    private static Boolean evaluateRule(Contact lead, Lead_Assignment_Setting__c rule, Map<String, Schema.SObjectField> fieldMap) {
        try {
            List<Condition> conditions = (List<Condition>) JSON.deserialize(rule.Conditions__c, List<Condition>.class);
            if (conditions == null || conditions.isEmpty()) {
                return false;
            }

            Map<Integer, Boolean> conditionResults = new Map<Integer, Boolean>();
            for (Condition cond : conditions) {
                Boolean result = evaluateSingleCondition(lead, cond, fieldMap);
                conditionResults.put(cond.Order, result);
            }

            if ('All'.equalsIgnoreCase(rule.Logic_Type__c)) {
                for (Boolean result : conditionResults.values()) {
                    if (!result) {
                        return false;
                    }
                }
                return true;
            } else if ('Custom'.equalsIgnoreCase(rule.Logic_Type__c) && !String.isBlank(rule.Logical_Expression__c)) {
                Boolean customResult = evaluateLogicalExpression(rule.Logical_Expression__c, conditionResults);
                return customResult;
            }

            return false;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'LeadAssignmentHandler', 'evaluateRule', 'Error during evaluateRule for rule: ' + rule.Name);
            return false;
        }
    }

    private static Boolean evaluateSingleCondition(Contact lead, Condition cond, Map<String, Schema.SObjectField> fieldMap) {
        try {
            if (String.isBlank(cond.Lead_Field) || !fieldMap.containsKey(cond.Lead_Field.toLowerCase())) {
                return false;
            }

            Object fieldValue = lead.get(cond.Lead_Field);
            String compareValue = cond.Value;
            String operator = cond.Condition;

            if (fieldValue == null) {
                Boolean result = 'notEqualsTo'.equalsIgnoreCase(operator) && compareValue != null;
                return result;
            }

            Set<String> numericOperators = new Set<String>{'lessThan', 'greaterThan', 'lessOrEqual', 'greaterOrEqual'};
            if (numericOperators.contains(operator)) {
                Boolean result = evaluateNumericCondition(fieldValue, operator, compareValue);
                return result;
            } else {
                Boolean result = evaluateStringCondition(String.valueOf(fieldValue), operator, compareValue);
                return result;
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'LeadAssignmentHandler', 'evaluateSingleCondition', 'Error during evaluateSingleCondition for field: ' + cond.Lead_Field);
            return false;
        }
    }

    private static Boolean evaluateNumericCondition(Object fieldValue, String operator, String compareValue) {
        try {
            if (!(fieldValue instanceof Decimal || fieldValue instanceof Integer || fieldValue instanceof Double)) {
                return false;
            }
            Decimal fieldValueDecimal = Decimal.valueOf(String.valueOf(fieldValue));
            Decimal compareValueDecimal = Decimal.valueOf(compareValue);

            switch on operator {
                when 'lessThan' {
                    Boolean result = fieldValueDecimal < compareValueDecimal;
                    return result;
                }
                when 'greaterThan' {
                    Boolean result = fieldValueDecimal > compareValueDecimal;
                    return result;
                }
                when 'lessOrEqual' {
                    Boolean result = fieldValueDecimal <= compareValueDecimal;
                    return result;
                }
                when 'greaterOrEqual' {
                    Boolean result = fieldValueDecimal >= compareValueDecimal;
                    return result;
                }
                when else {
                    return false;
                }
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'LeadAssignmentHandler', 'evaluateNumericCondition', 'Error during evaluateNumericCondition');
            return false;
        }
    }

    private static Boolean evaluateStringCondition(String fieldValueStr, String operator, String compareValue) {
        try {
            switch on operator {
                when 'equals' {
                    Boolean result = fieldValueStr.equalsIgnoreCase(compareValue);
                    return result;
                }
                when 'notEqualsTo' {
                    Boolean result = !fieldValueStr.equalsIgnoreCase(compareValue);
                    return result;
                }
                when 'startsWith' {
                    Boolean result = fieldValueStr.toLowerCase().startsWith(compareValue.toLowerCase());
                    return result;
                }
                when 'contains' {
                    Boolean result = fieldValueStr.containsIgnoreCase(compareValue);
                    return result;
                }
                when 'doesNotContain' {
                    Boolean result = !fieldValueStr.containsIgnoreCase(compareValue);
                    return result;
                }
                when 'includes' {
                    Boolean result = fieldValueStr.split(';').contains(compareValue);
                    return result;
                }
                when 'excludes' {
                    Boolean result = !fieldValueStr.split(';').contains(compareValue);
                    return result;
                }
                when else {
                    return false;
                }
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'LeadAssignmentHandler', 'evaluateStringCondition', 'Error during evaluateStringCondition');
            return false;
        }
    }

    private static Boolean evaluateLogicalExpression(String expression, Map<Integer, Boolean> conditionResults) {
        try {
            List<String> tokens = tokenizeExpression(expression);
            List<Boolean> values = new List<Boolean>();
            List<String> ops = new List<String>();

            for (String token : tokens) {
                if (Pattern.matches('\\d+', token)) {
                    Integer index = Integer.valueOf(token);
                    if (!conditionResults.containsKey(index)) {
                        return false;
                    }
                    values.add(conditionResults.get(index));
                } else if (token == '(') {
                    ops.add(token);
                } else if (token == ')') {
                    while (!ops.isEmpty() && ops.get(ops.size() - 1) != '(') {
                        values.add(applyOp(ops.remove(ops.size() - 1), values.remove(values.size() - 1), values.remove(values.size() - 1)));
                    }
                    if (!ops.isEmpty()) {
                        ops.remove(ops.size() - 1);
                    }
                } else if (token == 'AND' || token == 'OR') {
                    while (!ops.isEmpty() && hasPrecedence(token, ops.get(ops.size() - 1))) {
                        values.add(applyOp(ops.remove(ops.size() - 1), values.remove(values.size() - 1), values.remove(values.size() - 1)));
                    }
                    ops.add(token);
                }
            }

            while (!ops.isEmpty()) {
                values.add(applyOp(ops.remove(ops.size() - 1), values.remove(values.size() - 1), values.remove(values.size() - 1)));
            }
            Boolean result = !values.isEmpty() ? values.get(0) : false;
            return result;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'LeadAssignmentHandler', 'evaluateLogicalExpression', 'Error during evaluateLogicalExpression');
            return false;
        }
    }

    private static List<String> tokenizeExpression(String expression) {
        try {
            expression = expression.replace('(', ' ( ').replace(')', ' ) ');
            List<String> tokens = expression.toUpperCase().split(' ');
            List<String> cleanedTokens = new List<String>();
            for (String token : tokens) {
                if (!String.isBlank(token)) {
                    cleanedTokens.add(token);
                }
            }

            return cleanedTokens;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'LeadAssignmentHandler', 'tokenizeExpression', 'Error during tokenizeExpression');
            return new List<String>();
        }
    }

    private static Boolean hasPrecedence(String op1, String op2) {
        try {
            if (op2 == '(' || op2 == ')') {
                return false;
            }
            if ((op1 == 'AND') && (op2 == 'OR')) {
                return false;
            }
            return true;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'LeadAssignmentHandler', 'hasPrecedence', 'Error during hasPrecedence');
            return false;
        }
    }

    private static Boolean applyOp(String op, Boolean b2, Boolean b1) {
        try {
            if (op == 'AND') {
                return b1 && b2;
            }
            if (op == 'OR') {
                return b1 || b2;
            }
            return false;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'LeadAssignmentHandler', 'applyOp', 'Error during applyOp');
            return false;
        }
    }

    public static void notifyOwner(List<Contact> newLeads, Map<Id, Contact> oldLeadMap) {
        try {
            if (oldLeadMap == null) {
                sendSocialMediaNotifications(newLeads);
            }

            Set<Id> ownerIdsToNotify = new Set<Id>();
            Map<Id, String> ownerIdToLeadName = new Map<Id, String>();
            Map<Id, Id> ownerIdToLeadId = new Map<Id, Id>();
            List<Contact> welcomeEmailContacts = new List<Contact>();

            for (Contact newLead : newLeads) {
                Boolean isInsert = (oldLeadMap == null || !oldLeadMap.containsKey(newLead.Id));
                Contact oldLead = isInsert ? null : oldLeadMap.get(newLead.Id);
                String fullName = String.join(
                    new List<String>{ newLead.FirstName, newLead.LastName },
                    ' '
                ).trim();

                if (isInsert && newLead.OwnerId != null) {
                    ownerIdsToNotify.add(newLead.OwnerId);
                    ownerIdToLeadName.put(newLead.OwnerId, fullName);
                    ownerIdToLeadId.put(newLead.OwnerId, newLead.Id);
                } else if (!isInsert && newLead.OwnerId != oldLead.OwnerId && newLead.OwnerId != null) {
                    ownerIdsToNotify.add(newLead.OwnerId);
                    ownerIdToLeadName.put(newLead.OwnerId, fullName);
                    ownerIdToLeadId.put(newLead.OwnerId, newLead.Id);
                }

                // Collect newly-inserted Buyer / Renter contacts for welcome email
                if (isInsert && String.isNotBlank(newLead.MVEX__Contact_Type__c)) {
                    Boolean isBuyerOrRenter = false;
                    for (String ct : newLead.MVEX__Contact_Type__c.split(';')) {
                        if (ct.trim() == 'Buyer' || ct.trim() == 'Renter') {
                            isBuyerOrRenter = true;
                            break;
                        }
                    }
                    if (isBuyerOrRenter) {
                        welcomeEmailContacts.add(newLead);
                    }
                }
            }

            List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

            if (!welcomeEmailContacts.isEmpty()) {
                List<EmailTemplate> welcomeTemplates = [SELECT Id FROM EmailTemplate WHERE DeveloperName = 'Lead_Welcome_Email' LIMIT 1];
                if (!welcomeTemplates.isEmpty()) {
                    for (Contact con : welcomeEmailContacts) {
                        Messaging.SingleEmailMessage welcomeMail = new Messaging.SingleEmailMessage();
                        welcomeMail.setTargetObjectId(con.Id);
                        welcomeMail.setTreatTargetObjectAsRecipient(true);
                        welcomeMail.setTemplateId(welcomeTemplates[0].Id);
                        welcomeMail.setSaveAsActivity(false);
                        emails.add(welcomeMail);
                    }
                }
            }

            if (!ownerIdsToNotify.isEmpty()) {
                Map<Id, User> userMap = new Map<Id, User>([SELECT Id, Email FROM User WHERE Id IN :ownerIdsToNotify AND Email != null]);

                List<EmailTemplate> ownerTemplates = [SELECT Id FROM EmailTemplate WHERE DeveloperName = 'Lead_Assigned_Notification' LIMIT 1];

                for (Id ownerId : ownerIdsToNotify) {
                    Id leadId = ownerIdToLeadId.get(ownerId);

                    if (userMap.containsKey(ownerId) && !ownerTemplates.isEmpty()) {
                        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                        mail.setTargetObjectId(ownerId);
                        mail.setWhatId(leadId);
                        mail.setTemplateId(ownerTemplates[0].Id);
                        mail.setSaveAsActivity(false);
                        emails.add(mail);
                    }
                }
            }

            if (!emails.isEmpty()) {
                Messaging.sendEmail(emails, false);
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'LeadAssignmentHandler', 'notifyOwner', 'Error during notifyOwner');
        }
    }


    private static void sendSocialMediaNotifications(List<Contact> leads) {
        try {
            MVEX__Lead_Notification__c config = MVEX__Lead_Notification__c.getOrgDefaults();
            if (config == null || !config.MVEX__Notification_Enable__c || String.isBlank(config.MVEX__Email_Addresses__c)) {
                return;
            }
            
            List<Contact> buyerSocialLeads = new List<Contact>();
            Set<String> validSources = new Set<String>{'Instagram', 'Facebook'};
            
            for (Contact con : leads) {
                if (con.LeadSource != null && validSources.contains(con.LeadSource) && 
                    con.MVEX__Contact_Type__c == 'Buyer') {
                    buyerSocialLeads.add(con);
                }
            }

            if (buyerSocialLeads.isEmpty()) return;

            List<String> emailList = new List<String>();
            for (String email : config.MVEX__Email_Addresses__c.split(';')) {
                if (String.isNotBlank(email)) emailList.add(email.trim());
            }
            if (emailList.isEmpty()) return;

            List<EmailTemplate> templates = [SELECT Id, Subject FROM EmailTemplate WHERE DeveloperName = 'Social_Media_Lead_Notification' LIMIT 1];
            if (templates.isEmpty()) return;

            Id orgWideEmailId = null;
            List<OrgWideEmailAddress> owea = [SELECT Id FROM OrgWideEmailAddress WHERE DisplayName = 'GuestUserMail' LIMIT 1];
            if (!owea.isEmpty()) {
                orgWideEmailId = owea[0].Id;
            }

            List<Messaging.SingleEmailMessage> emailQueue = new List<Messaging.SingleEmailMessage>();
            
            for (Contact con : buyerSocialLeads) {
                for (String email : emailList) {
                    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                    mail.setToAddresses(new List<String>{email});
                    mail.setTargetObjectId(con.Id);
                    mail.setTreatTargetObjectAsRecipient(false); 
                    mail.setTemplateId(templates[0].Id);
                    mail.setSaveAsActivity(false);
                    
                    if (orgWideEmailId != null) {
                        mail.setOrgWideEmailAddressId(orgWideEmailId);
                    }
                    
                    emailQueue.add(mail);
                }
            }

            if (!emailQueue.isEmpty()) {
                Messaging.sendEmail(emailQueue, false);
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'LeadAssignmentHandler', 'sendSocialMediaNotifications', 'Failed to send social template email');
        }
    }
}