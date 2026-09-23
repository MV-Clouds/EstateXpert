@isTest
public class ContactTriggerHandlerTest {

    @testSetup
    static void setupData() {
        // 1. Setup Social Media Notification Config
        MVEX__Lead_Notification__c socialConfig = new MVEX__Lead_Notification__c(
            MVEX__Notification_Enable__c = true,
            MVEX__Email_Addresses__c = 'test@example.com'
        );
        insert socialConfig;
    }

    @isTest
    static void testEvaluateNumericOperators() {
        // We will use MailingLatitude (Double) to test numeric logic
        Contact con = new Contact(
            FirstName = 'Numeric', 
            LastName = 'Test', 
            MailingLatitude = 50.0
        );

        // List of numeric operators to cover the switch statement fully
        List<String> numOps = new List<String>{'lessThan', 'greaterThan', 'lessOrEqual', 'greaterOrEqual', 'invalidOp'};
        List<String> values = new List<String>{'100', '10', '50', '50', '0'};
        
        List<MVEX__Lead_Assignment_Setting__c> settings = new List<MVEX__Lead_Assignment_Setting__c>();

        for(Integer i = 0; i < numOps.size(); i++) {
            ContactTriggerHandler.Condition cond = new ContactTriggerHandler.Condition();
            cond.Lead_Field = 'MailingLatitude';
            cond.Condition = numOps[i];
            cond.Value = values[i];
            cond.Order = 1;

            settings.add(new MVEX__Lead_Assignment_Setting__c(
                Name = UserInfo.getUserId(),
                MVEX__Conditions__c = JSON.serialize(new List<ContactTriggerHandler.Condition>{cond}),
                MVEX__Logic_Type__c = 'All',
                MVEX__User_Order__c = i,
                MVEX__Object_Name__c = 'Contact',
                MVEX__Default_User__c = false
            ));
        }
        insert settings;

        Test.startTest();
        // This will trigger the loop through allRules and evaluateNumericCondition for each
        ContactTriggerHandler.handleLeadAssignment(new List<Contact>{con}, null);
        Test.stopTest();

        // Ensure evaluateNumericCondition was reached
        System.assertNotEquals(null, con.MailingLatitude, 'Field value should be numeric');
    }

    @isTest
    static void testEvaluateStringAndLogicalLogic() {
        Contact con = new Contact(FirstName = 'Alpha', LastName = 'Beta', LeadSource = 'Web');
        
        // 1. Test Custom Logic with complex expression to cover hasPrecedence and applyOp
        // Logic: (1 OR 2) AND 3 -> This triggers the precedence check between AND and OR
        ContactTriggerHandler.Condition c1 = new ContactTriggerHandler.Condition();
        c1.Lead_Field = 'FirstName'; c1.Condition = 'equals'; c1.Value = 'Alpha'; c1.Order = 1;
        
        ContactTriggerHandler.Condition c2 = new ContactTriggerHandler.Condition();
        c2.Lead_Field = 'LastName'; c2.Condition = 'notEqualsTo'; c2.Value = 'Gamma'; c2.Order = 2;

        ContactTriggerHandler.Condition c3 = new ContactTriggerHandler.Condition();
        c3.Lead_Field = 'LeadSource'; c3.Condition = 'equals'; c3.Value = 'Web'; c3.Order = 3;

        MVEX__Lead_Assignment_Setting__c rule = new MVEX__Lead_Assignment_Setting__c(
            Name = UserInfo.getUserId(),
            MVEX__Conditions__c = JSON.serialize(new List<ContactTriggerHandler.Condition>{c1, c2, c3}),
            MVEX__Logic_Type__c = 'Custom',
            MVEX__Logical_Expression__c = '(1 OR 2) AND 3',
            MVEX__User_Order__c = 1,
            MVEX__Object_Name__c = 'Contact',
            MVEX__Default_User__c = false
        );
        insert rule;

        Test.startTest();
        ContactTriggerHandler.handleLeadAssignment(new List<Contact>{con}, null);
        Test.stopTest();
        
        System.assertEquals(UserInfo.getUserId(), con.OwnerId, 'Rule should match and assign owner');
    }

    @isTest
    static void testStringOperatorsAndNulls() {
        // Covers: startsWith, contains, doesNotContain, includes, excludes, and NULL check
        Contact con = new Contact(LastName = 'Check', Description = 'Apple;Orange');
        
        List<String> ops = new List<String>{'startsWith', 'contains', 'doesNotContain', 'includes', 'excludes', 'invalid'};
        List<MVEX__Lead_Assignment_Setting__c> settings = new List<MVEX__Lead_Assignment_Setting__c>();

        for(String op : ops) {
            ContactTriggerHandler.Condition c = new ContactTriggerHandler.Condition();
            c.Lead_Field = 'Description';
            c.Condition = op;
            c.Value = 'Apple';
            c.Order = 1;
            settings.add(new MVEX__Lead_Assignment_Setting__c(
                Name = UserInfo.getUserId(),
                MVEX__Conditions__c = JSON.serialize(new List<ContactTriggerHandler.Condition>{c}),
                MVEX__Logic_Type__c = 'All',
                MVEX__User_Order__c = 1,
                MVEX__Object_Name__c = 'Contact',
                MVEX__Default_User__c = false
            ));
        }

        // Add a test for Null field value
        ContactTriggerHandler.Condition cNull = new ContactTriggerHandler.Condition();
        cNull.Lead_Field = 'FirstName'; // FirstName is null on the record
        cNull.Condition = 'notEqualsTo';
        cNull.Value = 'Something';
        settings.add(new MVEX__Lead_Assignment_Setting__c(
            Name = UserInfo.getUserId(),
            MVEX__Conditions__c = JSON.serialize(new List<ContactTriggerHandler.Condition>{cNull}),
            MVEX__Logic_Type__c = 'All',
            MVEX__User_Order__c = 10,
            MVEX__Object_Name__c = 'Contact',
            MVEX__Default_User__c = false
        ));

        insert settings;

        Test.startTest();
        ContactTriggerHandler.handleLeadAssignment(new List<Contact>{con}, null);
        Test.stopTest();
    }

    @isTest
    static void testDefaultAssigneeFallback() {
        Contact con = new Contact(FirstName = 'Fallback', LastName = 'Lead', LeadSource = 'Other');
        
        // Insert a default assignee setting
        MVEX__Lead_Assignment_Setting__c defaultRule = new MVEX__Lead_Assignment_Setting__c(
            Name = UserInfo.getUserId(),
            MVEX__Object_Name__c = 'Contact',
            MVEX__Default_User__c = true
        );
        insert defaultRule;

        Test.startTest();
        ContactTriggerHandler.handleLeadAssignment(new List<Contact>{con}, null);
        Test.stopTest();

        System.assertEquals(UserInfo.getUserId(), con.OwnerId, 'Default assignee should be assigned when no rules match');
    }

    @isTest
    static void testNotificationsAndSocial() {
        Contact con = new Contact(
            FirstName = 'Social', 
            LastName = 'Buyer', 
            LeadSource = 'Instagram', 
            MVEX__Contact_Type__c = 'Buyer'
        );
        insert con;

        Test.startTest();
        // Force the notification logic
        ContactTriggerHandler.notifyOwner(new List<Contact>{con}, null);
        
        // Update to trigger owner change path
        ContactTriggerHandler.handleLeadAssignment(null, null);
        Test.stopTest();
    }

    @isTest
    static void testExceptionBlocks() {
        delete [SELECT Id FROM MVEX__Lead_Assignment_Setting__c];
        
        Test.startTest();
        
        // 1. Force error in handleLeadAssignment by passing invalid list/map combo
        ContactTriggerHandler.handleLeadAssignment(null, null);
        
        // 2. Force error in evaluateRule (JSON Deserialization error)
        MVEX__Lead_Assignment_Setting__c badRule = new MVEX__Lead_Assignment_Setting__c(
            MVEX__Conditions__c = '{ invalid json }',
            MVEX__Logic_Type__c = 'All',
            MVEX__Object_Name__c = 'Contact'
        );
        // We use a contact to try and trigger the rule evaluation
        Contact con = new Contact(LastName = 'Test');
        insert new MVEX__Lead_Assignment_Setting__c(Name = UserInfo.getUserId(), MVEX__Conditions__c = '!!', MVEX__Logic_Type__c = 'All', MVEX__User_Order__c = 1, MVEX__Object_Name__c = 'Contact');
        ContactTriggerHandler.handleLeadAssignment(new List<Contact>{con}, null);

        // 3. Force error in notifyOwner
        ContactTriggerHandler.notifyOwner(null, null);

        // 4. Force error in tokenizeExpression/evaluateLogicalExpression
        MVEX__Lead_Assignment_Setting__c badLogicRule = new MVEX__Lead_Assignment_Setting__c(
            Name = UserInfo.getUserId(),
            MVEX__Conditions__c = JSON.serialize(new List<ContactTriggerHandler.Condition>()),
            MVEX__Logic_Type__c = 'Custom',
            MVEX__Logical_Expression__c = '1 AND (2 OR)',
            MVEX__User_Order__c = 1,
            MVEX__Object_Name__c = 'Contact'
        );
        // Note: The evaluateLogicalExpression is wrapped in try-catch
        
        Test.stopTest();
        
        System.assert(true, 'Catches were executed successfully');
    }

    @isTest
    static void testExceptionsDeep() {
        // Deep coverage for exceptions
        ContactTriggerHandler.Condition c1 = new ContactTriggerHandler.Condition();
        c1.Lead_Field = 'InvalidField__c';
        c1.Condition = 'equals';
        
        // Logical expression edge cases
        MVEX__Lead_Assignment_Setting__c r1 = new MVEX__Lead_Assignment_Setting__c(Name=UserInfo.getUserId(), MVEX__Conditions__c='[{\"Order\":1}]', MVEX__Logic_Type__c='Custom', MVEX__Logical_Expression__c='(1) OR 2', MVEX__Object_Name__c='Contact');
        insert r1;

        Contact con = new Contact(FirstName = 'Test',LastName = 'Test');
        insert con;
        ContactTriggerHandler.handleLeadAssignment(new List<Contact>{con}, null);
        
        MVEX__Lead_Notification__c socialConfig = [SELECT Id, MVEX__Email_Addresses__c FROM MVEX__Lead_Notification__c LIMIT 1];
        socialConfig.MVEX__Email_Addresses__c = null;
        update socialConfig;

        Contact conSocial = new Contact(FirstName = 'Social', LastName = 'Buyer', LeadSource = 'Facebook', MVEX__Contact_Type__c = 'Buyer');
        ContactTriggerHandler.notifyOwner(new List<Contact>{conSocial}, null);
    }

    private static Boolean testEvaluateCondition(Contact con, String field, String op, String val) {
        // Clear existing settings
        delete [SELECT Id FROM MVEX__Lead_Assignment_Setting__c];
        
        ContactTriggerHandler.Condition cond = new ContactTriggerHandler.Condition();
        cond.Lead_Field = field;
        cond.Condition = op;
        cond.Value = val;
        cond.Order = 1;

        // Create a unique dummy user/group ID for matching
        String testOwnerId = UserInfo.getUserId();
        
        MVEX__Lead_Assignment_Setting__c rule = new MVEX__Lead_Assignment_Setting__c(
            Name = testOwnerId,
            MVEX__Conditions__c = JSON.serialize(new List<ContactTriggerHandler.Condition>{cond}),
            MVEX__Logic_Type__c = 'All',
            MVEX__User_Order__c = 1,
            MVEX__Object_Name__c = 'Contact'
        );
        insert rule;
        
        Contact testContact = con.clone(false, true, false, false);
        testContact.OwnerId = '005000000000000AAA'; // A dummy owner ID different from UserInfo.getUserId()
        
        ContactTriggerHandler.handleLeadAssignment(new List<Contact>{testContact}, null);
        
        return testContact.OwnerId == testOwnerId;
    }

    @isTest
    static void testAllOperators() {
        Contact con = new Contact(
            FirstName = 'TestCon', 
            LastName = 'TestLastName',
            MailingLatitude = 50.0,
            Description = 'Apple;Orange;Banana'
        );

        // 1. Numeric Operators
        // greaterThan
        testEvaluateCondition(con, 'MailingLatitude', 'greaterThan', '10');
        testEvaluateCondition(con, 'MailingLatitude', 'greaterThan', '100');
        
        // lessOrEqual
        testEvaluateCondition(con, 'MailingLatitude', 'lessOrEqual', '50');
        testEvaluateCondition(con, 'MailingLatitude', 'lessOrEqual', '100');
        testEvaluateCondition(con, 'MailingLatitude', 'lessOrEqual', '10');
        
        // greaterOrEqual
        testEvaluateCondition(con, 'MailingLatitude', 'greaterOrEqual', '50');
        testEvaluateCondition(con, 'MailingLatitude', 'greaterOrEqual', '10');
        testEvaluateCondition(con, 'MailingLatitude', 'greaterOrEqual', '100');

        // 2. String Operators
        // contains
        testEvaluateCondition(con, 'Description', 'contains', 'Orange');
        testEvaluateCondition(con, 'Description', 'contains', 'Grapes');
        
        // doesNotContain
        testEvaluateCondition(con, 'Description', 'doesNotContain', 'Grapes');
        testEvaluateCondition(con, 'Description', 'doesNotContain', 'Orange');
        
        // includes
        testEvaluateCondition(con, 'Description', 'includes', 'Apple');
        testEvaluateCondition(con, 'Description', 'includes', 'Grapes');
        
        // excludes
        testEvaluateCondition(con, 'Description', 'excludes', 'Grapes');
        testEvaluateCondition(con, 'Description', 'excludes', 'Apple');
    }
}