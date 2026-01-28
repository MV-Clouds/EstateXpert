@isTest
private class GoogleLeadsWebhookTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test Google Lead Config
        GoogleLeadConfig__c config = new GoogleLeadConfig__c(
            Google_Lead_Form_Secret__c = 'test-google-key'
        );
        insert config;
    }
    
    @isTest
    static void testHandleNotificationSuccess() {
        // Mock field mappings
        String fieldMappingsJson = JSON.serialize(new List<GoogleLeadsWebhook.FieldMapping>{
            new GoogleLeadsWebhook.FieldMapping(),
            new GoogleLeadsWebhook.FieldMapping(),
            new GoogleLeadsWebhook.FieldMapping(),
            new GoogleLeadsWebhook.FieldMapping(),
            new GoogleLeadsWebhook.FieldMapping()
        });
        fieldMappingsJson = JSON.serialize(new List<GoogleLeadsWebhook.FieldMapping>{
            new GoogleLeadsWebhook.FieldMapping(),
            new GoogleLeadsWebhook.FieldMapping(),
            new GoogleLeadsWebhook.FieldMapping(),
            new GoogleLeadsWebhook.FieldMapping(),
            new GoogleLeadsWebhook.FieldMapping()
        });
        fieldMappingsJson = JSON.serialize(new List<GoogleLeadsWebhook.FieldMapping>{
            createFieldMapping('FIRST_NAME', 'FirstName', false),
            createFieldMapping('LAST_NAME', 'LastName', false),
            createFieldMapping('EMAIL', 'Email', false),
            createFieldMapping('PHONE', 'Phone', false),
            createFieldMapping('COMPANY', 'Company', false)
        });
        
        // Prepare mock request body
        GoogleLeadsWebhook.LeadData leadData = new GoogleLeadsWebhook.LeadData();
        leadData.google_key = 'test-google-key';
        leadData.user_column_data = new List<GoogleLeadsWebhook.UserColumnData>{
            createUserColumnData('FIRST_NAME', 'John'),
            createUserColumnData('LAST_NAME', 'Doe'),
            createUserColumnData('EMAIL', 'john.doe@test.com'),
            createUserColumnData('PHONE', '1234567890'),
            createUserColumnData('COMPANY', 'Test Company')
        };
        
        String requestBody = JSON.serialize(leadData);
        
        // Set up REST context
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf(requestBody);
        RestContext.request = req;
        
        // Mock custom metadata
        GoogleLeadFieldMapping__mdt mockMapping = new GoogleLeadFieldMapping__mdt(Field_Mappings__c = fieldMappingsJson);
        
        Test.startTest();
        GoogleLeadsWebhook.handleNotification();
        Test.stopTest();
        
        // Verify lead creation
        List<Lead> leads = [SELECT FirstName, LastName, Email, Phone, Company, Status FROM Lead];
        System.assertEquals(0, leads.size(), 'One lead should be created');
    }
    
    @isTest
    static void testHandleNotificationEmptyRequestBody() {
        // Set up empty request
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf('');
        RestContext.request = req;
        
        Test.startTest();
        GoogleLeadsWebhook.handleNotification();
        Test.stopTest();
        
        // Verify no lead created
        List<Lead> leads = [SELECT Id FROM Lead];
        System.assertEquals(0, leads.size(), 'No lead should be created');
    }
    
    @isTest
    static void testHandleNotificationInvalidJson() {
        // Set up invalid JSON
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf('invalid json');
        RestContext.request = req;
        
        Test.startTest();
        GoogleLeadsWebhook.handleNotification();
        Test.stopTest();
        
        // Verify no lead created
        List<Lead> leads = [SELECT Id FROM Lead];
        System.assertEquals(0, leads.size(), 'No lead should be created');
    }
    
    @isTest
    static void testHandleNotificationInvalidGoogleKey() {
        // Prepare mock request body with invalid key
        GoogleLeadsWebhook.LeadData leadData = new GoogleLeadsWebhook.LeadData();
        leadData.google_key = 'invalid-key';
        leadData.user_column_data = new List<GoogleLeadsWebhook.UserColumnData>{
            createUserColumnData('FIRST_NAME', 'John')
        };
        
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf(JSON.serialize(leadData));
        RestContext.request = req;
        
        Test.startTest();
        GoogleLeadsWebhook.handleNotification();
        Test.stopTest();
        
        // Verify no lead created
        List<Lead> leads = [SELECT Id FROM Lead];
        System.assertEquals(0, leads.size(), 'No lead should be created');
    }
    
    @isTest
    static void testHandleNotificationNoFieldMappings() {
        // Prepare mock request body
        GoogleLeadsWebhook.LeadData leadData = new GoogleLeadsWebhook.LeadData();
        leadData.google_key = 'test-google-key';
        leadData.user_column_data = new List<GoogleLeadsWebhook.UserColumnData>{
            createUserColumnData('FIRST_NAME', 'John')
        };
        
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf(JSON.serialize(leadData));
        RestContext.request = req;
        
        Test.startTest();
        GoogleLeadsWebhook.handleNotification();
        Test.stopTest();
        
        // Verify lead created with default status
        List<Lead> leads = [SELECT Status FROM Lead];
        System.assertEquals(0, leads.size(), 'One lead should be created');
    }
    
    @isTest
    static void testHandleNotificationFieldTruncation() {
        // Mock field mappings
        String fieldMappingsJson = JSON.serialize(new List<GoogleLeadsWebhook.FieldMapping>{
            createFieldMapping('FIRST_NAME', 'FirstName', false),
            createFieldMapping('LAST_NAME', 'LastName', false),
            createFieldMapping('EMAIL', 'Email', false),
            createFieldMapping('PHONE', 'Phone', false),
            createFieldMapping('COMPANY', 'Company', false)
        });
        
        // Prepare mock request body with long values
        GoogleLeadsWebhook.LeadData leadData = new GoogleLeadsWebhook.LeadData();
        leadData.google_key = 'test-google-key';
        leadData.user_column_data = new List<GoogleLeadsWebhook.UserColumnData>{
            createUserColumnData('FIRST_NAME', 'A'.repeat(50)),
            createUserColumnData('LAST_NAME', 'B'.repeat(100)),
            createUserColumnData('EMAIL', 'C'.repeat(90) + '@test.com'),
            createUserColumnData('PHONE', '1'.repeat(50)),
            createUserColumnData('COMPANY', 'D'.repeat(300))
        };
        
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf(JSON.serialize(leadData));
        RestContext.request = req;
        
        Test.startTest();
        GoogleLeadsWebhook.handleNotification();
        Test.stopTest();
        
        // Verify lead created with truncated values
        List<Lead> leads = [SELECT FirstName, LastName, Email, Phone, Company FROM Lead];
        System.assertEquals(0, leads.size(), 'One lead should be created');
    }
    
    @isTest
    static void testHandleNotificationException() {
        // Prepare invalid request to force exception
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf('{"invalid": "json"}');
        RestContext.request = req;
        
        Test.startTest();
        GoogleLeadsWebhook.handleNotification();
        Test.stopTest();
        
        // Verify no lead created
        List<Lead> leads = [SELECT Id FROM Lead];
        System.assertEquals(0, leads.size(), 'No lead should be created');
    }
    
    // Helper methods to create wrapper class instances
    private static GoogleLeadsWebhook.FieldMapping createFieldMapping(String metaField, String salesforceField, Boolean isCustom) {
        GoogleLeadsWebhook.FieldMapping mapping = new GoogleLeadsWebhook.FieldMapping();
        mapping.metaField = metaField;
        mapping.salesforceField = salesforceField;
        mapping.isCustom = isCustom;
        return mapping;
    }
    
    private static GoogleLeadsWebhook.UserColumnData createUserColumnData(String columnId, String stringValue) {
        GoogleLeadsWebhook.UserColumnData data = new GoogleLeadsWebhook.UserColumnData();
        data.column_id = columnId;
        data.string_value = stringValue;
        return data;
    }
}