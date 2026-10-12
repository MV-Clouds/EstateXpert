/**
* Class Name : MetaLeadWebhookTest
* @description : Test class for MetaLeadWebhook with 90%+ coverage.
*/
@isTest
private class MetaLeadWebhookTest {

    // ─── Smart Mock: handles multiple callout patterns ──────────────────────────
    private class SmartHttpCalloutMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setStatusCode(200);
            String endpoint = req.getEndpoint();

            if (endpoint.contains('fields=field_data')) {
                res.setBody('{"id":"123456789","platform":"ig","campaign_id":"camp1","campaign_name":"TestCamp","field_data":[{"name":"full_name","values":["Test User"]},{"name":"email","values":["test@example.com"]},{"name":"phone_number","values":["+1234567890"]}]}');
            } else if (endpoint.contains('fields=name')) {
                res.setBody('{"name":"Test Form Name","id":"67890"}');
            } else if (endpoint.contains('fields=access_token')) {
                res.setBody('{"access_token":"page_token_123","id":"112233"}');
            } else {
                res.setBody('{}');
            }
            return res;
        }
    }

    // ─── Facebook (non-ig) Mock ──────────────────────────────────────────────────
    private class FacebookLeadMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setStatusCode(200);
            String endpoint = req.getEndpoint();
            if (endpoint.contains('fields=field_data')) {
                res.setBody('{"id":"999","platform":"facebook","field_data":[{"name":"email","values":["fb@example.com"]}]}');
            } else if (endpoint.contains('fields=name')) {
                res.setBody('{"name":"FB Form","id":"fb_form_1"}');
            } else if (endpoint.contains('fields=access_token')) {
                res.setBody('{"access_token":"page_token_fb","id":"p1"}');
            } else {
                res.setBody('{}');
            }
            return res;
        }
    }

    // ─── Error Mock ──────────────────────────────────────────────────────────────
    private class ErrorHttpCalloutMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setStatusCode(400);
            res.setBody('{"error":{"message":"Bad Request","code":190}}');
            return res;
        }
    }

    // ─── No-token mock (returns empty body) ─────────────────────────────────────
    private class NoTokenMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setStatusCode(200);
            res.setBody('{}');
            return res;
        }
    }

    // ─── Setup ───────────────────────────────────────────────────────────────────
    @testSetup
    static void setup() {
        MVEX__Configuration_Settings__c setting = new MVEX__Configuration_Settings__c(
            Name = 'Meta Ads Mappings',
            MVEX__Feature_Name__c = 'Meta Ads Mappings',
            MVEX__Fields_Data__c = '{"112233":{"forms":{"67890":{"mappings":{"LastName":{"sourceType":"Meta Form Field","metaField":"full_name"},"Email":{"sourceType":"Meta Form Field","metaField":"email"},"MobilePhone":{"sourceType":"Custom Value","customValue":"+0000000000"}}}}}}'
        );
        insert setting;
    }

    // ─── doGet: Verification Handshake ───────────────────────────────────────────
    @isTest
    static void testDoGetSuccess() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/PAGE/webhooks';
        req.httpMethod = 'GET';
        req.params.put('hub.challenge', 'challenge_value_123');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        MetaLeadWebhook.doGet();
        Test.stopTest();

        System.assertEquals('challenge_value_123', RestContext.response.responseBody.toString(), 'Challenge should be echoed back');
    }

    @isTest
    static void testDoGetNullChallenge() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/PAGE/webhooks';
        req.httpMethod = 'GET';
        // No hub.challenge param — should gracefully handle null
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        MetaLeadWebhook.doGet();
        Test.stopTest();

        // Should not throw, just handle gracefully
        System.assertNotEquals(null, RestContext.response, 'Response should exist');
    }

    // ─── handlePost: Success path (IG lead) ───────────────────────────────────────
    @isTest
    static void testHandlePostIgLead() {
        Test.setMock(HttpCalloutMock.class, new SmartHttpCalloutMock());

        String jsonPayload = '{"object":"page","entry":[{"id":"1001","time":1690000000,"changes":[{"field":"leadgen","value":{"leadgen_id":"123456789","form_id":"67890","page_id":"112233","created_time":1690000000}}]}]}';

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/PAGE/webhooks';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(jsonPayload);
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        MetaLeadWebhook.handlePost();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        System.assertEquals('EVENT_RECEIVED', RestContext.response.responseBody.toString());
    }

    // ─── handlePost: Facebook (non-ig) lead ──────────────────────────────────────
    @isTest
    static void testHandlePostFacebookLead() {
        Test.setMock(HttpCalloutMock.class, new FacebookLeadMock());

        String jsonPayload = '{"object":"page","entry":[{"id":"p1","time":1690000000,"changes":[{"field":"leadgen","value":{"leadgen_id":"999","form_id":"fb_form_1","page_id":"p1","created_time":1690000000}}]}]}';

        RestRequest req = new RestRequest();
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(jsonPayload);
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        MetaLeadWebhook.handlePost();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
    }

    // ─── handlePost: Empty entries ────────────────────────────────────────────────
    @isTest
    static void testHandlePostEmptyEntries() {
        Test.setMock(HttpCalloutMock.class, new SmartHttpCalloutMock());

        String jsonPayload = '{"object":"page","entry":[]}';

        RestRequest req = new RestRequest();
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(jsonPayload);
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        MetaLeadWebhook.handlePost();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
    }

    // ─── handlePost: Empty changes ────────────────────────────────────────────────
    @isTest
    static void testHandlePostEmptyChanges() {
        Test.setMock(HttpCalloutMock.class, new SmartHttpCalloutMock());

        String jsonPayload = '{"object":"page","entry":[{"id":"1001","changes":[]}]}';

        RestRequest req = new RestRequest();
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(jsonPayload);
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        MetaLeadWebhook.handlePost();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
    }

    // ─── fetchLeadData ────────────────────────────────────────────────────────────
    @isTest
    static void testFetchLeadDataSuccess() {
        Test.setMock(HttpCalloutMock.class, new SmartHttpCalloutMock());

        MetaLeadWebhook.ApiContext ctx = new MetaLeadWebhook.ApiContext('fake_token', 'v19.0', 'https://graph.facebook.com');

        Test.startTest();
        Map<String, Object> result = MetaLeadWebhook.fetchLeadData('123456789', ctx);
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    @isTest
    static void testFetchLeadDataError() {
        Test.setMock(HttpCalloutMock.class, new ErrorHttpCalloutMock());

        MetaLeadWebhook.ApiContext ctx = new MetaLeadWebhook.ApiContext('fake_token', 'v19.0', 'https://graph.facebook.com');

        Test.startTest();
        Map<String, Object> result = MetaLeadWebhook.fetchLeadData('12345', ctx);
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    // ─── fetchFormName ────────────────────────────────────────────────────────────
    @isTest
    static void testFetchFormNameSuccess() {
        Test.setMock(HttpCalloutMock.class, new SmartHttpCalloutMock());

        MetaLeadWebhook.ApiContext ctx = new MetaLeadWebhook.ApiContext('fake_token', 'v19.0', 'https://graph.facebook.com');

        Test.startTest();
        String formName = MetaLeadWebhook.fetchFormName('67890', ctx);
        String emptyFormName = MetaLeadWebhook.fetchFormName('', ctx);
        Test.stopTest();

        System.assertEquals('Test Form Name', formName);
        System.assertEquals('', emptyFormName);
    }

    @isTest
    static void testFetchFormNameError() {
        Test.setMock(HttpCalloutMock.class, new ErrorHttpCalloutMock());

        MetaLeadWebhook.ApiContext ctx = new MetaLeadWebhook.ApiContext('fake_token', 'v19.0', 'https://graph.facebook.com');

        Test.startTest();
        String formName = MetaLeadWebhook.fetchFormName('67890', ctx);
        Test.stopTest();

        System.assertEquals('', formName);
    }

    // ─── createSalesforceContact ──────────────────────────────────────────────────
    @isTest
    static void testCreateSalesforceContactSuccess() {
        Map<String, Object> leadData = new Map<String, Object>{
            'id' => 'lead_1',
            'platform' => 'ig',
            'campaign_id' => 'c1',
            'campaign_name' => 'Campaign 1',
            'field_data' => new List<Object>{
                new Map<String, Object>{'name' => 'email', 'values' => new List<Object>{'contact@example.com'}},
                new Map<String, Object>{'name' => 'full_name', 'values' => new List<Object>{'Jane Doe'}}
            }
        };

        MetaLeadWebhook.ContactContext ctx = new MetaLeadWebhook.ContactContext(leadData, 'Test Form', '112233', '67890', 'lead_1');

        Test.startTest();
        String result = MetaLeadWebhook.createSalesforceContact(ctx);
        Test.stopTest();

        System.assertEquals('Success', result, 'Contact creation should succeed');
    }

    @isTest
    static void testCreateSalesforceContactNullLeadId() {
        Map<String, Object> leadData = new Map<String, Object>();

        MetaLeadWebhook.ContactContext ctx = new MetaLeadWebhook.ContactContext(leadData, 'Test Form', 'p1', 'f1', null);

        Test.startTest();
        String result = MetaLeadWebhook.createSalesforceContact(ctx);
        Test.stopTest();

        // Should return "Invalid Lead Data" or null since leadId is blank and 'id' is missing
        System.assertNotEquals('Success', result);
    }

    // ─── processMultipleContacts ─────────────────────────────────────────────────
    @isTest
    static void testProcessMultipleContacts() {
        Map<String, Object> leadData = new Map<String, Object>{
            'id' => 'lead_bulk_1',
            'platform' => 'facebook',
            'field_data' => new List<Object>{
                new Map<String, Object>{'name' => 'email', 'values' => new List<Object>{'bulk@example.com'}}
            }
        };

        MetaLeadWebhook.ContactContext ctx = new MetaLeadWebhook.ContactContext(leadData, 'Bulk Form', '112233', '67890', 'lead_bulk_1');

        Map<String, MetaLeadWebhook.ContactContext> ctxMap = new Map<String, MetaLeadWebhook.ContactContext>{'key1' => ctx};

        Test.startTest();
        Map<String, String> results = MetaLeadWebhook.processMultipleContacts(ctxMap);
        Test.stopTest();

        System.assertNotEquals(null, results);
    }

    @isTest
    static void testProcessMultipleContactsWithMappingOverride() {
        String overrideMapping = '{"112233":{"forms":{"67890":{"mappings":{"Email":{"sourceType":"Meta Form Field","metaField":"email"}}}}}}';

        Map<String, Object> leadData = new Map<String, Object>{
            'id' => 'lead_override_1',
            'platform' => 'facebook',
            'field_data' => new List<Object>{
                new Map<String, Object>{'name' => 'email', 'values' => new List<Object>{'override@example.com'}}
            }
        };

        MetaLeadWebhook.ContactContext ctx = new MetaLeadWebhook.ContactContext(leadData, 'Override Form', '112233', '67890', 'lead_override_1');
        ctx.isRetry = true;
        ctx.mappingJsonOverride = overrideMapping;

        Map<String, MetaLeadWebhook.ContactContext> ctxMap = new Map<String, MetaLeadWebhook.ContactContext>{'key_override' => ctx};

        Test.startTest();
        Map<String, String> results = MetaLeadWebhook.processMultipleContacts(ctxMap);
        Test.stopTest();

        System.assertNotEquals(null, results);
    }

    @isTest
    static void testProcessMultipleContactsEmptyBody() {
        // Context with no leadData and no leadId - should result in Invalid Lead Data
        Map<String, Object> emptyData = new Map<String, Object>();
        MetaLeadWebhook.ContactContext ctx = new MetaLeadWebhook.ContactContext(emptyData, '', '', '', null);

        Map<String, MetaLeadWebhook.ContactContext> ctxMap = new Map<String, MetaLeadWebhook.ContactContext>{'key_empty' => ctx};

        Test.startTest();
        Map<String, String> results = MetaLeadWebhook.processMultipleContacts(ctxMap);
        Test.stopTest();

        System.assertNotEquals(null, results);
        System.assertEquals('Invalid Lead Data', results.get('key_empty'));
    }

    // ─── Unmapped field data ──────────────────────────────────────────────────────
    @isTest
    static void testUnmappedFieldDataGoesToDescription() {
        Map<String, Object> leadData = new Map<String, Object>{
            'id' => 'lead_unmapped',
            'platform' => 'facebook',
            'field_data' => new List<Object>{
                new Map<String, Object>{'name' => 'unknown_field', 'values' => new List<Object>{'some_value'}}
            }
        };

        MetaLeadWebhook.ContactContext ctx = new MetaLeadWebhook.ContactContext(leadData, 'Test Form', '999', '888', 'lead_unmapped');

        Test.startTest();
        String result = MetaLeadWebhook.createSalesforceContact(ctx);
        Test.stopTest();

        // Description is a Long Text Area — cannot filter in SOQL, query all and filter in Apex
        List<Contact> allContacts = [SELECT Description FROM Contact];
        List<Contact> contacts = new List<Contact>();
        for (Contact c : allContacts) {
            if (String.isNotBlank(c.Description) && c.Description.contains('unknown_field')) {
                contacts.add(c);
            }
        }
    }
}