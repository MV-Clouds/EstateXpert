public with sharing class AgentCommissionReportController {
    public class CommissionData {
        @AuraEnabled public Decimal commission { get; set; }
        @AuraEnabled public Decimal overallCommission { get; set; }
        @AuraEnabled public Integer count { get; set; }
        @AuraEnabled public Decimal rentCommission { get; set; }
        @AuraEnabled public Decimal saleCommission { get; set; }
        @AuraEnabled public Decimal rentPrice { get; set; }
        @AuraEnabled public Decimal salePrice { get; set; }
        @AuraEnabled public Decimal totalPrice { get; set; }
        @AuraEnabled public Integer rentCount { get; set; }
        @AuraEnabled public Integer saleCount { get; set; }

        public CommissionData() {
            commission = 0;
            overallCommission = 0;
            count = 0;
            rentCommission = 0;
            saleCommission = 0;
            rentPrice = 0;
            salePrice = 0;
            totalPrice = 0;
            rentCount = 0;
            saleCount = 0;
        }
    }

    @AuraEnabled
    public static Map<String, Object> getRolesAndUsers() {
        try {
            Map<String, Object> response = new Map<String, Object>();
            List<String> roleNames = new List<String>();
            Map<String, List<String>> usersByRole = new Map<String, List<String>>();

            // Fetch custom setting values
            AgentCommissionData__c setting = AgentCommissionData__c.getOrgDefaults();
            Set<String> allowedProfiles = new Set<String>();
            Set<String> excludedUserNames = new Set<String>();

            if (setting != null) {
                if (String.isNotBlank(setting.Profile_Name__c)) {
                    for (String prof : setting.Profile_Name__c.split(',')) {
                        allowedProfiles.add(prof.trim());
                    }
                }
                if (String.isNotBlank(setting.User_Name__c)) {
                    for (String uname : setting.User_Name__c.split(',')) {
                        excludedUserNames.add(uname.trim());
                    }
                }
            }

            List<UserRole> roles = [SELECT Name FROM UserRole WHERE Name != null WITH USER_MODE ORDER BY Name];

            for (UserRole role : roles) {
                roleNames.add(role.Name);
                usersByRole.put(role.Name, new List<String>());
            }
            usersByRole.put('Unassigned', new List<String>());

            // Build dynamic query for users
            String userQuery = 'SELECT Name, UserRole.Name FROM User WHERE IsActive = true';
            if (!allowedProfiles.isEmpty()) {
                userQuery += ' AND Profile.Name IN :allowedProfiles';
            }
            if (!excludedUserNames.isEmpty()) {
                userQuery += ' AND Name NOT IN :excludedUserNames';
            }
            userQuery += ' ORDER BY Name';

            List<User> users = Database.query(userQuery, AccessLevel.USER_MODE);

            for (User user : users) {
                String roleName = user.UserRole != null ? user.UserRole.Name : 'Unassigned';
                usersByRole.get(roleName).add(user.Name);
            }

            response.put('roles', roleNames);
            response.put('usersByRole', usersByRole);
            response.put('currency', UserInfo.getDefaultCurrency());
            return response;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'CommissionReportController', 'getRolesAndUsers', e.getMessage());
        }

        return null;
    }

    @AuraEnabled
    public static Map<String, CommissionData> calculateAgentCommissions(Map<String, Object> agentData) {
        try {
            Map<String, CommissionData> resultMap = new Map<String, CommissionData>();
            String dateRange = (String)agentData.get('dateRange');
            String closingType = (String)agentData.get('closingType');
            String startDate = (String)agentData.get('startDate');
            String endDate = (String)agentData.get('endDate');
            String selectedRole = (String)agentData.get('selectedRole');
            String selectedUser = (String)agentData.get('selectedUser');

            String query = 'SELECT Id, MVEX__Closing_Type__c, MVEX__Agent_1_Name__c, MVEX__Agent_1_Commission__c, MVEX__Internal_Agent_Share__c, ' +
                'MVEX__Internal_Agent_2_Share__c, MVEX__Agent_2_Name__c, MVEX__Agent_2_Commission__c, MVEX__Agent_Commission__c, ' +
                'MVEX__Rental_Price__c, MVEX__Sale_Price__c, MVEX__Closing_Status__c, MVEX__ClosingDate__c FROM MVEX__Closing__c ' +
                'WHERE (MVEX__Agent_1_Name__c != null OR MVEX__Agent_2_Name__c != null) ';

            Map<String, Object> bindVars = new Map<String, Object>();

            if (selectedUser != 'All') {
                query += 'AND (MVEX__Agent_1_Name__c = :selectedUser OR MVEX__Agent_2_Name__c = :selectedUser) ';
                bindVars.put('selectedUser', selectedUser);
            } else if (selectedRole != 'All') {
                List<User> users = [
                    SELECT Name 
                    FROM User 
                    WHERE UserRole.Name = :selectedRole 
                    AND IsActive = true 
                    WITH USER_MODE
                ];
                Set<String> agentNames = new Set<String>();
                for (User u : users) {
                    agentNames.add(u.Name);
                }
                if (!agentNames.isEmpty()) {
                    query += 'AND (MVEX__Agent_1_Name__c IN :agentNames OR MVEX__Agent_2_Name__c IN :agentNames) ';
                    bindVars.put('agentNames', agentNames);
                } else {
                    return resultMap;
                }
            }

            if (closingType != 'All Closings') {
                if (closingType.contains('Rent')) {
                    query += 'AND MVEX__Closing_Type__c = \'Rent\' ';
                }
                if (closingType.contains('Sale')) {
                    query += 'AND MVEX__Closing_Type__c = \'Sale\' ';
                }
                if (closingType.contains('Open')) {
                    query += 'AND MVEX__Closing_Status__c = \'Open\' ';
                }
                if (closingType.contains('Closed')) {
                    query += 'AND MVEX__Closing_Status__c = \'Closed\' ';
                }
            } else {
                query += 'AND MVEX__Closing_Status__c != \'Canceled\' ';
            }
            List<Closing__c> closingRecords = Database.queryWithBinds(query, bindVars, AccessLevel.USER_MODE);
            if (dateRange != 'Lifetime') {
                DateRange dateRangeCalc = calculateDateRange(dateRange, startDate, endDate);
                query += 'AND (MVEX__Closing_Status__c = \'Open\' OR (MVEX__Closing_Status__c != \'Open\' AND MVEX__ClosingDate__c >= :startDateCalc AND MVEX__ClosingDate__c <= :endDateCalc)) ';
                bindVars.put('startDateCalc', dateRangeCalc.startDate);
                bindVars.put('endDateCalc', dateRangeCalc.endDate);
            }
            Set<String> processedAgentRecordKeys = new Set<String>();

            for (Closing__c record : closingRecords) {
                processAgent(record, record.Agent_1_Name__c, 
                    record.Internal_Agent_Share__c, 
                    record.Agent_Commission__c, 
                    selectedUser, resultMap, processedAgentRecordKeys);
                
                processAgent(record, record.Agent_2_Name__c, 
                    record.Internal_Agent_2_Share__c, 
                    record.Agent_2_Commission__c, 
                    selectedUser, resultMap, processedAgentRecordKeys);
            }

            return resultMap;
        } catch (Exception e) {
        
            ErrorHandler.insertErrordata(e, 'AgentCommissionReportController', 'calculateAgentCommissions', e.getMessage());
        }
        return null;
    }

    private static void processAgent(Closing__c record, String agentName, Decimal share, Decimal commission, 
                                   String selectedUser, Map<String, CommissionData> resultMap, 
                                   Set<String> processedAgentRecordKeys) {
                                    
        if (agentName == null || (selectedUser != 'All' && agentName != selectedUser)) return;

        String key = agentName + '_' + record.Id;
        if (processedAgentRecordKeys.contains(key)) return;

        if (!resultMap.containsKey(agentName)) {
            resultMap.put(agentName, new CommissionData());
        }

        CommissionData data = resultMap.get(agentName);
        data.commission += share != null ? share : 0;
        data.overallCommission += commission != null ? commission : 0;
        data.count += 1;

        if (String.isNotBlank(record.Closing_Type__c) && record.Closing_Type__c == 'Rent') {
            data.rentCommission += commission != null ? commission : 0;
            data.rentPrice += record.Rental_Price__c != null ? record.Rental_Price__c : 0;
            data.rentCount += 1;
        } else if (String.isNotBlank(record.Closing_Type__c) && record.Closing_Type__c == 'Sale') {
            data.saleCommission += commission != null ? commission : 0;
            data.salePrice += record.Sale_Price__c != null ? record.Sale_Price__c : 0;
            data.saleCount += 1;
        }
        data.totalPrice = data.rentPrice + data.salePrice;
        processedAgentRecordKeys.add(key);
    }

    private static DateRange calculateDateRange(String dateRange, String startDate, String endDate) {
        if (dateRange == 'Custom' && startDate != null && endDate != null) {
            return new DateRange(Date.valueOf(startDate), Date.valueOf(endDate));
        }

        Date today = Date.today();
        Date startDateCalc = today;
        Date endDateCalc = today;
        Integer year = today.year();
        Integer month = today.month();
        Integer quarter = ((month - 1) / 3) + 1;

        switch on dateRange {
            when 'Current FY' {
                startDateCalc = Date.newInstance(year, 1, 1);
            }
            when 'Previous FY' {
                startDateCalc = Date.newInstance(year - 1, 1, 1);
                endDateCalc = Date.newInstance(year - 1, 12, 31);
            }
            when 'Previous 2 FY' {
                startDateCalc = Date.newInstance(year - 2, 1, 1);
                endDateCalc = Date.newInstance(year - 1, 12, 31);
            }
            when 'Current FQ' {
                startDateCalc = Date.newInstance(year, (quarter - 1) * 3 + 1, 1);
            }
            when 'Previous FQ' {
                startDateCalc = Date.newInstance(year, (quarter - 2) * 3 + 1, 1);
                endDateCalc = Date.newInstance(year, (quarter - 1) * 3 + 1, 1).addDays(-1);
            }
            when 'Next FQ' {
                startDateCalc = Date.newInstance(year, quarter * 3 + 1, 1);
                endDateCalc = Date.newInstance(year, (quarter + 1) * 3 + 1, 1).addDays(-1);
            }
            when 'Current and Next FQ' {
                startDateCalc = Date.newInstance(year, (quarter - 1) * 3 + 1, 1);
                endDateCalc = Date.newInstance(year, (quarter + 1) * 3 + 1, 1).addDays(-1);
            }
            when 'Current and Previous FQ' {
                startDateCalc = Date.newInstance(year, (quarter - 2) * 3 + 1, 1);
            }
            when 'Current CY' {
                startDateCalc = Date.newInstance(year, 1, 1);
            }
            when 'Previous CY' {
                startDateCalc = Date.newInstance(year - 1, 1, 1);
                endDateCalc = Date.newInstance(year - 1, 12, 31);
            }
            when 'This Month' {
                startDateCalc = Date.newInstance(year, month, 1);
            }
            when 'Last Month' {
                startDateCalc = Date.newInstance(year, month, 1).addMonths(-1);
                endDateCalc = Date.newInstance(year, month, 1).addDays(-1);
            }
            when 'Last 7 Days', 'Last 30 Days', 'Last 60 Days', 'Last 90 Days' {
                Integer daysBack = Integer.valueOf(dateRange.replaceAll('[^0-9]', ''));
                startDateCalc = today.addDays(-daysBack);
            }
        }

        return new DateRange(startDateCalc, endDateCalc);
    }

    public class DateRange {
        @AuraEnabled public Date startDate { get; set; }
        @AuraEnabled public Date endDate { get; set; }

        public DateRange(Date startDate, Date endDate) {
            this.startDate = startDate;
            this.endDate = endDate;
        }
    }
}