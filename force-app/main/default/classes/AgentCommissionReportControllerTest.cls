@isTest
public class AgentCommissionReportControllerTest {
    
    @testSetup
    static void setupTestData() {
        // Create custom setting
        AgentCommissionData__c setting = new AgentCommissionData__c();
        insert setting;

        // Get test user info
        User currentUser = [SELECT Id, Name, UserRoleId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        String currentUserName = currentUser.Name;

        // Create Closing records for current user
        insert new List<Closing__c>{
            new Closing__c(
                Closing_Type__c = 'Rent',
                Agent_1_Name__c = currentUserName,
                Agent_Commission__c = 800,
                Rental_Price__c = 12000,
                Closing_Status__c = 'Closed',
                ClosingDate__c = Date.today()
            ),
            new Closing__c(
                Closing_Type__c = 'Sale',
                Agent_2_Name__c = currentUserName,
                Agent_2_Commission__c = 1800,
                Sale_Price__c = 90000,
                Closing_Status__c = 'Closed',
                ClosingDate__c = Date.today()
            )
        };
    }

    @isTest
    static void testGetRolesAndUsers_hasRoles() {
        Test.startTest();
        Map<String, Object> result = AgentCommissionReportController.getRolesAndUsers();
        Test.stopTest();

        List<String> roles = (List<String>) result.get('roles');
        System.assert(!roles.isEmpty(), 'Should return at least one role');
    }

    @isTest
    static void testGetRolesAndUsers_hasUsersByRole() {
        Test.startTest();
        Map<String, Object> result = AgentCommissionReportController.getRolesAndUsers();
        Test.stopTest();

        Map<String, List<String>> usersByRole = (Map<String, List<String>>) result.get('usersByRole');
        System.assert(!usersByRole.isEmpty(), 'Should return users grouped by role');
    }

    @isTest
    static void testCalculateAgentCommissions_withUserFilter() {
        String currentUserName = [SELECT Name FROM User WHERE Id = :UserInfo.getUserId()].Name;

        Map<String, Object> params = new Map<String, Object>{
            'dateRange' => 'Lifetime',
            'closingType' => 'All Closings',
            'startDate' => '',
            'endDate' => '',
            'selectedRole' => 'All',
            'selectedUser' => currentUserName
        };

        Test.startTest();
        Map<String, AgentCommissionReportController.CommissionData> result = AgentCommissionReportController.calculateAgentCommissions(params);
        Test.stopTest();

        System.assert(result.containsKey(currentUserName), 'Commission should be calculated for test context user');
    }

    @isTest
    static void testCalculateAgentCommissions_withRoleFilter() {
        User currentUser = [SELECT Name, UserRole.Name FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        String roleName = currentUser.UserRole != null ? currentUser.UserRole.Name : 'No Role Assigned';
        
        Map<String, Object> params = new Map<String, Object>{
            'dateRange' => 'Lifetime',
            'closingType' => 'All Closings',
            'startDate' => '',
            'endDate' => '',
            'selectedRole' => roleName,
            'selectedUser' => 'All'
        };

        Test.startTest();
        Map<String, AgentCommissionReportController.CommissionData> result = AgentCommissionReportController.calculateAgentCommissions(params);
        Test.stopTest();

        System.assert(result.containsKey(currentUser.Name), 'Commission should be calculated for role-based user');
    }

    @isTest
    static void testCalculateAgentCommissions_customDateRange() {
        String currentUserName = [SELECT Name FROM User WHERE Id = :UserInfo.getUserId()].Name;

        Map<String, Object> params = new Map<String, Object>{
            'dateRange' => 'Custom',
            'closingType' => 'All Closings',
            'startDate' => String.valueOf(Date.today().addDays(-5)),
            'endDate' => String.valueOf(Date.today().addDays(5)),
            'selectedRole' => 'All',
            'selectedUser' => currentUserName
        };

        Test.startTest();
        Map<String, AgentCommissionReportController.CommissionData> result = AgentCommissionReportController.calculateAgentCommissions(params);
        Test.stopTest();

        System.assert(result.containsKey(currentUserName), 'Custom date range should yield commission data');
    }

    @isTest
    static void testCalculateAgentCommissions_rentOnly() {
        String currentUserName = [SELECT Name FROM User WHERE Id = :UserInfo.getUserId()].Name;

        Map<String, Object> params = new Map<String, Object>{
            'dateRange' => 'Lifetime',
            'closingType' => 'Rent',
            'startDate' => '',
            'endDate' => '',
            'selectedRole' => 'All',
            'selectedUser' => currentUserName
        };

        Test.startTest();
        Map<String, AgentCommissionReportController.CommissionData> result = AgentCommissionReportController.calculateAgentCommissions(params);
        Test.stopTest();

        AgentCommissionReportController.CommissionData data = result.get(currentUserName);
        System.assert(data.rentCount > 0, 'Should include rent closings only');
    }

    @isTest
    static void testCalculateAgentCommissions_saleOnly() {
        String currentUserName = [SELECT Name FROM User WHERE Id = :UserInfo.getUserId()].Name;

        Map<String, Object> params = new Map<String, Object>{
            'dateRange' => 'Lifetime',
            'closingType' => 'Sale',
            'startDate' => '',
            'endDate' => '',
            'selectedRole' => 'All',
            'selectedUser' => currentUserName
        };

        Test.startTest();
        Map<String, AgentCommissionReportController.CommissionData> result = AgentCommissionReportController.calculateAgentCommissions(params);
        Test.stopTest();

        AgentCommissionReportController.CommissionData data = result.get(currentUserName);
        System.assert(data.saleCount > 0, 'Should include sale closings only');
    }

    @isTest
    static void testCalculateAgentCommissions_excludeCanceled() {
        String currentUserName = [SELECT Name FROM User WHERE Id = :UserInfo.getUserId()].Name;

        Closing__c canceled = new Closing__c(
            Closing_Type__c = 'Sale',
            Agent_1_Name__c = currentUserName,
            Agent_Commission__c = 1000,
            Sale_Price__c = 50000,
            Closing_Status__c = 'Canceled',
            ClosingDate__c = Date.today()
        );
        insert canceled;

        Map<String, Object> params = new Map<String, Object>{
            'dateRange' => 'Lifetime',
            'closingType' => 'All Closings',
            'startDate' => '',
            'endDate' => '',
            'selectedRole' => 'All',
            'selectedUser' => currentUserName
        };

        Test.startTest();
        Map<String, AgentCommissionReportController.CommissionData> result = AgentCommissionReportController.calculateAgentCommissions(params);
        Test.stopTest();

        System.assert(result.containsKey(currentUserName), 'User should have commission data');
    }

    @isTest
    static void testCalculateAgentCommissions_last7Days() {
        String currentUserName = [SELECT Name FROM User WHERE Id = :UserInfo.getUserId()].Name;

        insert new Closing__c(
            Closing_Type__c = 'Sale',
            Agent_1_Name__c = currentUserName,
            Agent_Commission__c = 1200,
            Sale_Price__c = 60000,
            Closing_Status__c = 'Closed',
            ClosingDate__c = Date.today().addDays(-2) // Within last 7 days
        );

        Map<String, Object> params = new Map<String, Object>{
            'dateRange' => 'Last 7 Days',
            'closingType' => 'All Closings',
            'startDate' => '',
            'endDate' => '',
            'selectedRole' => 'All',
            'selectedUser' => currentUserName
        };

        Test.startTest();
        Map<String, AgentCommissionReportController.CommissionData> result = AgentCommissionReportController.calculateAgentCommissions(params);
        Test.stopTest();

        System.assert(result.containsKey(currentUserName), 'Should return data for last 7 days');
    }
}