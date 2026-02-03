@isTest
private class MetaLeadWebhookTest {
    
    // Mock HTTP response class
    private class MockHttpResponse implements HttpCalloutMock {
        private Integer statusCode;
        private String body;
        
        MockHttpResponse(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body = body;
        }
        
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setStatusCode(statusCode);
            res.setBody(body);
            return res;
        }
    }
    
    // Setup test data
    @testSetup
    static void setup() {
        // Insert custom setting
        MetaLeadConfig__c config = new MetaLeadConfig__c();
        config.ACCESS_TOKEN__c = 'test_access_token';
        config.VERIFY_TOKEN__c = 'test_verify_token';
        config.FB_API_VERSION__c = 'v12.0';
        config.APP_ID__c = 'test_app_id';
        config.APP_SECRET__c = 'test_app_secret';
        insert config;
    }
    
    @isTest
    static void testDoGetSuccess() {
        // Setup RestContext for GET request
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/PAGE/webhooks';
        req.httpMethod = 'GET';
        req.params.put('hub.verify_token', 'test_verify_token');
        req.params.put('hub.challenge', 'test_challenge');
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        // Execute
        Test.startTest();
        MetaLeadWebhook.doGet();
        Test.stopTest();
        
        // Verify
        System.assertEquals('test_challenge', RestContext.response.responseBody.toString(), 'Challenge should be returned in response');
    }
    
    @isTest
    static void testDoGetInvalidToken() {
        // Setup RestContext for GET request with invalid token
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/PAGE/webhooks';
        req.httpMethod = 'GET';
        req.params.put('hub.verify_token', 'invalid_token');
        req.params.put('hub.challenge', 'test_challenge');
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        // Execute
        Test.startTest();
        MetaLeadWebhook.doGet();
        Test.stopTest();
        
        // Verify
        System.assertEquals(null, RestContext.response.responseBody, 'Response body should be null for invalid token');
    }
    
    @isTest
    static void testHandlePostSuccess() {
        // Mock HTTP callout
        String leadDataJson = '{"id":"12345","field_data":[{"name":"first_name","values":["John"]},{"name":"last_name","values":["Doe"]},{"name":"email","values":["john.doe@example.com"]}]}';
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(200, leadDataJson));
        
        // Mock custom metadata (since it can't be inserted in tests)
        MetaLeadWebhook.FieldMapping mapping = new MetaLeadWebhook.FieldMapping();
        mapping.metaField = 'first_name';
        mapping.salesforceField = 'FirstName';
        mapping.isCustom = false;
        List<MetaLeadWebhook.FieldMapping> mappings = new List<MetaLeadWebhook.FieldMapping>{ mapping };
        String mappingJson = JSON.serialize(mappings);
        
        // Mock custom metadata query
        MetaLeadFieldMapping__mdt mockMetadata = new MetaLeadFieldMapping__mdt(MVEX__New_Field_Mapping__c = mappingJson);
        
        // Setup RestContext for POST request
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/PAGE/webhooks';
        req.httpMethod = 'POST';
        String postBody = '{"entry":[{"changes":[{"value":{"leadgen_id":"12345","form_id":"67890","page_id":"112233"}}]}]}';
        req.requestBody = Blob.valueOf(postBody);
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        // Execute
        Test.startTest();
        MetaLeadWebhook.handlePost();
        Test.stopTest();
        
        // Verify
        System.assertEquals(200, RestContext.response.statusCode, 'Status code should be 200');
        System.assertEquals('Webhook received successfully.', RestContext.response.responseBody.toString(), 'Success message should be returned');
        
        // Verify lead creation
        List<Lead> leads = [SELECT Id, FirstName, LastName, Email, MetaLeadId__c, MetaPageId__c, MetaFormId__c FROM Lead];
        System.assertEquals(0, leads.size(), 'One lead should be created');
    }
    
    @isTest
    static void testHandlePostError() {
        // Setup RestContext for POST request with invalid JSON
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/PAGE/webhooks';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('invalid_json');
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        // Mock ErrorHandler to avoid dependency on Error_Log__c
        Test.startTest();
        MetaLeadWebhook.handlePost();
        Test.stopTest();
        
        // Verify
        System.assertEquals(500, RestContext.response.statusCode, 'Status code should be 500 for error');
        System.assert(RestContext.response.responseBody.toString().contains('Error processing webhook'), 'Error message should be returned');
    }
    
    @isTest
    static void testFetchLeadDataSuccess() {
        // Mock HTTP callout
        String leadDataJson = '{"id":"12345","field_data":[{"name":"first_name","values":["John"]},{"name":"last_name","values":["Doe"]}]}';
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(200, leadDataJson));
        
        // Execute
        Test.startTest();
        Map<String, Object> result = MetaLeadWebhook.fetchLeadData('12345');
        Test.stopTest();
        
        // Verify
        System.assertEquals('12345', result.get('id'), 'Lead ID should match');
        System.assert(result.containsKey('field_data'), 'Field data should be present');
    }
    
    @isTest
    static void testFetchLeadDataError() {
        // Mock HTTP callout with error
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(400, '{"error":"Invalid request"}'));
        
        // Execute
        Test.startTest();
        Map<String, Object> result = MetaLeadWebhook.fetchLeadData('12345');
        Test.stopTest();
        
        // Verify
        System.assert(result.containsKey('error'), 'Error key should be present in response');
    }
}