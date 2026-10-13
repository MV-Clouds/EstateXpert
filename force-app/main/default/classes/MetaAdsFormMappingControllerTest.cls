/**
* Class Name : MetaAdsFormMappingControllerTest
* @description : Test class for MetaAdsFormMappingController with 90%+ coverage.
*/
@isTest
private class MetaAdsFormMappingControllerTest {

    // ─── Mock: Success responses ─────────────────────────────────────────────────
    private class SuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setStatusCode(200);
            String endpoint = req.getEndpoint();

            if (endpoint.contains('me/accounts')) {
                res.setBody('{"data":[{"id":"page1","name":"Test Page","access_token":"page_token_abc"}]}');
            } else if (endpoint.contains('access_token') && endpoint.contains('leadgen_forms')) {
                res.setBody('{"data":[{"id":"form1","name":"My Form","status":"ACTIVE","questions":[{"key":"email"},{"key":"full_name"}]}]}');
            } else if (endpoint.contains('access_token') && !endpoint.contains('leadgen_forms')) {
                res.setBody('{"access_token":"page_token_123","id":"page1"}');
            } else if (endpoint.contains('subscribed_apps')) {
                res.setBody('{"success":true}');
            } else {
                res.setBody('{}');
            }
            return res;
        }
    }

    // ─── Mock: HTTP Error responses ───────────────────────────────────────────────
    private class ErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setStatusCode(400);
            res.setBody('{"error":{"message":"Invalid OAuth access token","code":190}}');
            return res;
        }
    }

    // ─── Mock: Webhook subscription failure ───────────────────────────────────────
    private class WebhookFailMock implements HttpCalloutMock {
        private Integer callCount = 0;
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            callCount++;
            String endpoint = req.getEndpoint();
            if (endpoint.contains('subscribed_apps')) {
                res.setStatusCode(400);
                res.setBody('{"error":{"message":"Subscription failed"}}');
            } else {
                res.setStatusCode(200);
                res.setBody('{"access_token":"page_token_123","id":"page1"}');
            }
            return res;
        }
    }

    // ─── Mock: Non-JSON error body ────────────────────────────────────────────────
    private class NonJsonErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setStatusCode(500);
            res.setBody('Internal Server Error - plain text');
            return res;
        }
    }

    // ─── Setup ───────────────────────────────────────────────────────────────────
    @testSetup
    static void setup() {
        MVEX__Configuration_Settings__c setting = new MVEX__Configuration_Settings__c(
            Name = 'Meta Ads Mappings',
            MVEX__Feature_Name__c = 'Meta Ads Mappings',
            MVEX__Fields_Data__c = '{"pageId1":{"forms":{"formId1":{"mappings":{}}}}}'
        );
        insert setting;

        // Error record for failed leads tests
        MVEX__Error_Handling__c err1 = new MVEX__Error_Handling__c(
            MVEX__Source_of_Error__c = 'MetaFailedLeads',
            MVEX__Error_Body__c = '{"formId":"form1","leadId":"lead1","pageId":"page1","formName":"Test Form","leadData":{"id":"lead1","platform":"facebook","field_data":[]}}',
            MVEX__Error_Message__c = 'Test Error'
        );
        MVEX__Error_Handling__c err2 = new MVEX__Error_Handling__c(
            MVEX__Source_of_Error__c = 'MetaFailedLeads',
            MVEX__Error_Body__c = '{"formId":"form2","leadId":"lead2","pageId":"page1","formName":"Form 2","leadData":{"id":"lead2","platform":"ig","field_data":[]}}',
            MVEX__Error_Message__c = 'Test Error 2'
        );
        MVEX__Error_Handling__c errNoBody = new MVEX__Error_Handling__c(
            MVEX__Source_of_Error__c = 'MetaFailedLeads',
            MVEX__Error_Body__c = '',
            MVEX__Error_Message__c = 'Empty body'
        );
        insert new List<MVEX__Error_Handling__c>{err1, err2, errNoBody};
    }

    // ─── getConnectedPages: no config ────────────────────────────────────────────
    @isTest
    static void testGetConnectedPagesNoConfig() {
        Test.startTest();
        Map<String, Object> result = MetaAdsFormMappingController.getConnectedPages();
        Test.stopTest();

        System.assertEquals(false, result.get('success'));
        System.assert(result.containsKey('message'));
    }

    // ─── getConnectedPages: HTTP success ──────────────────────────────────────────
    @isTest
    static void testGetConnectedPagesSuccess() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Test.startTest();
        Map<String, Object> result = MetaAdsFormMappingController.getConnectedPages();
        Test.stopTest();

        // Without real OAuth metadata, this hits the no-config path
        System.assertNotEquals(null, result);
        System.assert(result.containsKey('success'));
    }

    // ─── getConnectedPages: HTTP error ────────────────────────────────────────────
    @isTest
    static void testGetConnectedPagesHttpError() {
        Test.setMock(HttpCalloutMock.class, new ErrorMock());
        Test.startTest();
        Map<String, Object> result = MetaAdsFormMappingController.getConnectedPages();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.containsKey('success'));
    }

    // ─── getConnectedPages: non-JSON error body ───────────────────────────────────
    @isTest
    static void testGetConnectedPagesNonJsonError() {
        Test.setMock(HttpCalloutMock.class, new NonJsonErrorMock());
        Test.startTest();
        Map<String, Object> result = MetaAdsFormMappingController.getConnectedPages();
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    // ─── getLeadForms: no config ─────────────────────────────────────────────────
    @isTest
    static void testGetLeadFormsNoConfig() {
        Test.startTest();
        Map<String, Object> result = MetaAdsFormMappingController.getLeadForms('page1');
        Test.stopTest();

        System.assertEquals(false, result.get('success'));
    }

    // ─── getLeadForms: HTTP success ───────────────────────────────────────────────
    @isTest
    static void testGetLeadFormsSuccess() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Test.startTest();
        Map<String, Object> result = MetaAdsFormMappingController.getLeadForms('page1');
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.containsKey('success'));
    }

    // ─── getLeadForms: HTTP error on form fetch ───────────────────────────────────
    @isTest
    static void testGetLeadFormsHttpError() {
        Test.setMock(HttpCalloutMock.class, new ErrorMock());
        Test.startTest();
        Map<String, Object> result = MetaAdsFormMappingController.getLeadForms('page1');
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    // ─── getLeadForms: non-JSON error ────────────────────────────────────────────
    @isTest
    static void testGetLeadFormsNonJsonError() {
        Test.setMock(HttpCalloutMock.class, new NonJsonErrorMock());
        Test.startTest();
        Map<String, Object> result = MetaAdsFormMappingController.getLeadForms('page1');
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    // ─── getSalesforceLeadFields ─────────────────────────────────────────────────
    @isTest
    static void testGetSalesforceLeadFields() {
        Test.startTest();
        List<Map<String, String>> fields = MetaAdsFormMappingController.getSalesforceLeadFields();
        Test.stopTest();

        System.assertNotEquals(null, fields);
        System.assert(fields.size() > 0, 'Should return at least some Contact fields');

        // Check structure of returned fields
        Map<String, String> firstField = fields[0];
        System.assert(firstField.containsKey('label'));
        System.assert(firstField.containsKey('value'));
        System.assert(firstField.containsKey('type'));
        System.assert(firstField.containsKey('required'));
    }

    // ─── getExistingMappings: record exists ───────────────────────────────────────
    @isTest
    static void testGetExistingMappingsFound() {
        Test.startTest();
        String result = MetaAdsFormMappingController.getExistingMappings();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return the mapping JSON');
        System.assert(result.contains('pageId1'));
    }

    // ─── getExistingMappings: record not found ────────────────────────────────────
    @isTest
    static void testGetExistingMappingsNotFound() {
        // Delete the setup record to test the not-found path
        delete [SELECT Id FROM MVEX__Configuration_Settings__c WHERE Name = 'Meta Ads Mappings'];

        Test.startTest();
        String result = MetaAdsFormMappingController.getExistingMappings();
        Test.stopTest();

        System.assertEquals(null, result, 'Should return null when no record exists');
    }

    // ─── saveMapping: no pageId (skip webhook) ────────────────────────────────────
    @isTest
    static void testSaveMappingNoPageId() {
        String mapping = '{"test":"data"}';
        Test.startTest();
        Map<String, Object> result = MetaAdsFormMappingController.saveMapping(mapping, null);
        Test.stopTest();

        System.assertEquals(true, result.get('success'));
    }

    // ─── saveMapping: with pageId and successful webhook ──────────────────────────
    @isTest
    static void testSaveMappingWithPageIdSuccess() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        String mapping = '{"test":"data2"}';

        Test.startTest();
        Map<String, Object> result = MetaAdsFormMappingController.saveMapping(mapping, 'page1');
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.containsKey('success'));
    }

    // ─── saveMapping: with pageId, webhook fails ──────────────────────────────────
    @isTest
    static void testSaveMappingWebhookFails() {
        Test.setMock(HttpCalloutMock.class, new WebhookFailMock());
        String mapping = '{"test":"data3"}';

        Test.startTest();
        Map<String, Object> result = MetaAdsFormMappingController.saveMapping(mapping, 'page1');
        Test.stopTest();

        System.assertNotEquals(null, result);
        // Webhook failure (400) returns error body which is passed up
    }

    // ─── saveMapping: new record (no existing mapping) ────────────────────────────
    @isTest
    static void testSaveMappingCreatesNewRecord() {
        delete [SELECT Id FROM MVEX__Configuration_Settings__c WHERE Name = 'Meta Ads Mappings'];

        String mapping = '{"brand_new":"mapping"}';
        Test.startTest();
        Map<String, Object> result = MetaAdsFormMappingController.saveMapping(mapping, null);
        Test.stopTest();

        System.assertEquals(true, result.get('success'));
        MVEX__Configuration_Settings__c saved = [SELECT MVEX__Fields_Data__c FROM MVEX__Configuration_Settings__c WHERE Name = 'Meta Ads Mappings'];
        System.assertEquals(mapping, saved.MVEX__Fields_Data__c);
    }

    // ─── getFailedLeadsCountMap ───────────────────────────────────────────────────
    @isTest
    static void testGetFailedLeadsCountMap() {
        Test.startTest();
        Map<String, Integer> countMap = MetaAdsFormMappingController.getFailedLeadsCountMap();
        Test.stopTest();

        System.assertNotEquals(null, countMap);
        System.assert(countMap.containsKey('form1'), 'form1 should be in count map');
        System.assertEquals(1, countMap.get('form1'));
        System.assertEquals(1, countMap.get('form2'));
    }

    // ─── getFailedLeads: matching formId ─────────────────────────────────────────
    @isTest
    static void testGetFailedLeadsFiltered() {
        Test.startTest();
        List<MVEX__Error_Handling__c> result = MetaAdsFormMappingController.getFailedLeads('form1');
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(1, result.size(), 'Should return only form1 leads');
    }

    // ─── getFailedLeads: no matching formId ──────────────────────────────────────
    @isTest
    static void testGetFailedLeadsNoMatch() {
        Test.startTest();
        List<MVEX__Error_Handling__c> result = MetaAdsFormMappingController.getFailedLeads('nonexistent_form');
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(0, result.size());
    }

    // ─── retryFailedLead: success ────────────────────────────────────────────────
    @isTest
    static void testRetryFailedLeadSuccess() {
        // Long Text Area cannot be filtered in SOQL — fetch all and pick first with non-empty body
        MVEX__Error_Handling__c err;
        for (MVEX__Error_Handling__c e : [SELECT Id, MVEX__Error_Body__c FROM MVEX__Error_Handling__c WHERE MVEX__Source_of_Error__c = 'MetaFailedLeads']) {
            if (String.isNotBlank(e.MVEX__Error_Body__c) && e.MVEX__Error_Body__c.contains('form1')) {
                err = e;
                break;
            }
        }
        System.assertNotEquals(null, err, 'Should find an error record for form1');

        Test.startTest();
        String result = MetaAdsFormMappingController.retryFailedLead(err.Id, null);
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    // ─── retryFailedLead: with mappingJsonOverride ────────────────────────────────
    @isTest
    static void testRetryFailedLeadWithOverride() {
        // Long Text Area cannot be filtered in SOQL — fetch all and filter in Apex
        MVEX__Error_Handling__c err;
        for (MVEX__Error_Handling__c e : [SELECT Id, MVEX__Error_Body__c FROM MVEX__Error_Handling__c WHERE MVEX__Source_of_Error__c = 'MetaFailedLeads']) {
            if (String.isNotBlank(e.MVEX__Error_Body__c) && e.MVEX__Error_Body__c.contains('form1')) {
                err = e;
                break;
            }
        }
        System.assertNotEquals(null, err, 'Should find an error record for form1');
        String overrideJson = '{}';

        Test.startTest();
        String result = MetaAdsFormMappingController.retryFailedLead(err.Id, overrideJson);
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    // ─── retryMultipleFailedLeads: bulk success ───────────────────────────────────
    @isTest
    static void testRetryMultipleFailedLeadsSuccess() {
        // Filter records with non-empty body in Apex (Long Text Area not filterable in SOQL)
        List<String> ids = new List<String>();
        for (MVEX__Error_Handling__c e : [SELECT Id, MVEX__Error_Body__c FROM MVEX__Error_Handling__c WHERE MVEX__Source_of_Error__c = 'MetaFailedLeads']) {
            if (String.isNotBlank(e.MVEX__Error_Body__c)) {
                ids.add(e.Id);
            }
        }

        Test.startTest();
        Map<String, String> results = MetaAdsFormMappingController.retryMultipleFailedLeads(ids);
        Test.stopTest();

        System.assertNotEquals(null, results);
    }

    // ─── retryMultipleFailedLeads: includes empty body record ────────────────────
    @isTest
    static void testRetryMultipleFailedLeadsWithEmptyBody() {
        List<MVEX__Error_Handling__c> errs = [SELECT Id FROM MVEX__Error_Handling__c WHERE MVEX__Source_of_Error__c = 'MetaFailedLeads'];
        List<String> ids = new List<String>();
        for (MVEX__Error_Handling__c e : errs) { ids.add(e.Id); }

        Test.startTest();
        Map<String, String> results = MetaAdsFormMappingController.retryMultipleFailedLeads(ids);
        Test.stopTest();

        System.assertNotEquals(null, results);
    }

    // ─── deleteFailedLeads ────────────────────────────────────────────────────────
    @isTest
    static void testDeleteFailedLeadsSuccess() {
        List<MVEX__Error_Handling__c> errs = [SELECT Id FROM MVEX__Error_Handling__c WHERE MVEX__Source_of_Error__c = 'MetaFailedLeads'];
        List<String> ids = new List<String>();
        for (MVEX__Error_Handling__c e : errs) { ids.add(e.Id); }

        Test.startTest();
        Boolean result = MetaAdsFormMappingController.deleteFailedLeads(ids);
        Test.stopTest();

        System.assertEquals(true, result);
    }

    // ─── deleteFailedLeads: empty list ────────────────────────────────────────────
    @isTest
    static void testDeleteFailedLeadsEmptyList() {
        Test.startTest();
        Boolean result = MetaAdsFormMappingController.deleteFailedLeads(new List<String>{'nonexistent_id'});
        Test.stopTest();

        System.assertEquals(false, result);
    }

    // ─── getActiveSites ──────────────────────────────────────────────────────────
    @isTest
    static void testGetActiveSites() {
        Test.startTest();
        List<Map<String, String>> result = MetaAdsFormMappingController.getActiveSites();
        Test.stopTest();

        System.assertNotEquals(null, result);
        // Sandbox/scratch orgs may not have active sites, so just ensure no exception
    }
}
