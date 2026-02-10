@isTest
private class MetaLeadWebhookTest {

    // --- 1. Smart Mock to handle multiple different API calls ---
    private class SmartHttpCalloutMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setStatusCode(200);
            
            String endpoint = req.getEndpoint();
            
            // Response for Lead Data (contains field_data)
            if (endpoint.contains('fields=field_data')) {
                String leadResponse = '{' +
                    '"id": "123456789",' +
                    '"created_time": "2023-01-01T12:00:00+0000",' +
                    '"platform": "ig",' + 
                    '"field_data": [' +
                        '{"name": "full_name", "values": ["Test User"]},' +
                        '{"name": "email", "values": ["test@example.com"]},' +
                        '{"name": "phone_number", "values": ["+1234567890"]}' +
                    ']' +
                '}';
                res.setBody(leadResponse);
            } 
            // Response for Form Name (contains fields=name)
            else if (endpoint.contains('fields=name')) {
                res.setBody('{"name": "Test Form Name", "id": "67890"}');
            } 
            // Default/Fallback
            else {
                res.setBody('{}');
            }
            return res;
        }
    }
    
    // --- 2. Mock for Error Scenarios ---
    private class ErrorHttpCalloutMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setStatusCode(400);
            res.setBody('{"error": {"message": "Bad Request"}}');
            return res;
        }
    }

    // --- 3. Test Setup ---
    @testSetup
    static void setup() {
        // Insert custom setting with MVEX namespace fields
        MVEX__MetaLeadConfig__c config = new MVEX__MetaLeadConfig__c();
        config.MVEX__ACCESS_TOKEN__c = 'test_access_token';
        config.MVEX__VERIFY_TOKEN__c = 'test_verify_token';
        config.MVEX__FB_API_VERSION__c = 'v18.0';
        config.MVEX__APP_ID__c = 'test_app_id';
        config.MVEX__APP_SECRET__c = 'test_app_secret';
        insert config;
    }

    // --- 4. GET Verification Tests ---
    @isTest
    static void testDoGetSuccess() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/PAGE/webhooks';
        req.httpMethod = 'GET';
        req.params.put('hub.verify_token', 'test_verify_token');
        req.params.put('hub.challenge', 'challenge_accepted');
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        MetaLeadWebhook.doGet();
        Test.stopTest();
        
        System.assertEquals('challenge_accepted', RestContext.response.responseBody.toString(), 'Challenge should match');
    }

    @isTest
    static void testDoGetFail() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/PAGE/webhooks';
        req.httpMethod = 'GET';
        req.params.put('hub.verify_token', 'wrong_token');
        req.params.put('hub.challenge', 'challenge_accepted');
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        MetaLeadWebhook.doGet();
        Test.stopTest();
        
        System.assertEquals(null, RestContext.response.responseBody, 'Response should be empty for invalid token');
    }

    // --- 5. POST Handling Tests (Main Logic) ---
    @isTest
    static void testHandlePostSuccess() {
        // Register the Smart Mock to handle both Lead and Form Name callouts
        Test.setMock(HttpCalloutMock.class, new SmartHttpCalloutMock());

        // Prepare Webhook JSON Payload
        String jsonPayload = '{' +
            '"object": "page",' +
            '"entry": [{' +
                '"id": "1001",' +
                '"time": 1690000000,' +
                '"changes": [{' +
                    '"field": "leadgen",' +
                    '"value": {' +
                        '"leadgen_id": "123456789",' +
                        '"form_id": "67890",' +
                        '"page_id": "112233",' +
                        '"created_time": 1690000000' +
                    '}' +
                '}]' +
            '}]' +
        '}';

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/PAGE/webhooks';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(jsonPayload);
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        MetaLeadWebhook.handlePost();
        Test.stopTest();

        // --- Verifications ---
        System.assertEquals(200, RestContext.response.statusCode, 'Status should be 200');

        // Check Contact Creation (Class creates Contact, not Lead)
        List<Contact> createdContacts = [
            SELECT Id, LeadSource, MVEX__MetaLeadId__c, MVEX__Meta_Form_Name__c, MVEX__Contact_Type__c, MVEX__Meta_Raw_JSON__c 
            FROM Contact 
            WHERE MVEX__MetaLeadId__c = '123456789'
        ];

        System.assertEquals(1, createdContacts.size(), 'A contact should be created');
        Contact c = createdContacts[0];
        
        // Assert Mappings and Logic
        System.assertEquals('Instagram', c.LeadSource, 'Platform IG should map to Instagram');
        System.assertEquals('Test Form Name', c.MVEX__Meta_Form_Name__c, 'Form Name should be fetched via API');
        System.assertEquals('Buyer', c.MVEX__Contact_Type__c, 'Contact Type should be Buyer');
        System.assert(c.MVEX__Meta_Raw_JSON__c != null, 'Raw JSON should be stored');
    }

    @isTest
    static void testHandlePostInvalidJson() {
        // Test malformed JSON to trigger exception handling
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/PAGE/webhooks';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{ "bad": "json" '); // Missing closing brace
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        MetaLeadWebhook.handlePost();
        Test.stopTest();

        System.assertEquals(500, RestContext.response.statusCode);
        System.assert(RestContext.response.responseBody.toString().contains('Error'), 'Should return error message');
    }

    // --- 6. Individual Method Unit Tests ---

    @isTest
    static void testFetchFormName() {
        Test.setMock(HttpCalloutMock.class, new SmartHttpCalloutMock());
        
        Test.startTest();
        String formName = MetaLeadWebhook.fetchFormName('67890');
        String emptyName = MetaLeadWebhook.fetchFormName('');
        Test.stopTest();
        
        System.assertEquals('Test Form Name', formName);
        System.assertEquals('', emptyName);
    }
    
    @isTest
    static void testFetchFormNameError() {
        Test.setMock(HttpCalloutMock.class, new ErrorHttpCalloutMock());
        
        Test.startTest();
        // This should hit the catch block or return empty if key not found
        String formName = MetaLeadWebhook.fetchFormName('67890');
        Test.stopTest();
        
        System.assertEquals('', formName, 'Should return empty string on API error');
    }

    @isTest
    static void testFetchLeadDataError() {
        Test.setMock(HttpCalloutMock.class, new ErrorHttpCalloutMock());
        
        Test.startTest();
        Map<String, Object> res = MetaLeadWebhook.fetchLeadData('12345');
        Test.stopTest();
        
        // API returns a map, usually containing error details or empty on failure in helper
        System.assert(res != null); 
    }
}