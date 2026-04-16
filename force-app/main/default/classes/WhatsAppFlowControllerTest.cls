@isTest
public class WhatsAppFlowControllerTest {

    @TestSetup
    static void setupTestData() {
        // Create a sample Contact record
        Flow__c flow = new Flow__c(Flow_Id__c = '12345');
        insert flow;
    }
    
    // Mocking the HTTP response for testing
    static HttpResponse createMockResponse(String statusCode, String body) {
        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setStatusCode(Integer.valueOf(statusCode));
        mockResponse.setBody(body);
        return mockResponse;
    }

    @isTest
    public static void testGetWhatsAppFlows() {
        // Create mock response for the HTTP request inside the controller
        HttpResponse mockResponse = createMockResponse('200', '{"id":"12345","name":"Test Flow"}');
        MockHttpResponseGenerator mock = new MockHttpResponseGenerator(mockResponse);
        Test.setMock(HttpCalloutMock.class, mock);

        // Run the test
        Test.startTest();
        List<sObject> flows = WhatsAppFlowController.getWhatsAppFlows();
        Test.stopTest();

        // Asserting the expected result
        System.assertNotEquals(flows, null, 'Expected flows to not be null');
    }

    @isTest
    public static void testGetJSONData() {
        // Create mock response for the HTTP request inside the controller
        HttpResponse mockResponse = createMockResponse('200', '{"Default_JSON__c":"{\"key\":\"value\"}"}');
        MockHttpResponseGenerator mock = new MockHttpResponseGenerator(mockResponse);
        Test.setMock(HttpCalloutMock.class, mock);

        // Run the test
        Test.startTest();
        String jsonData = WhatsAppFlowController.getJSONData('Default');
        String jsonData2 = WhatsAppFlowController.getJSONData('Collect purchase interest');
        String jsonData3 = WhatsAppFlowController.getJSONData('Get feedback');
        String jsonData4 = WhatsAppFlowController.getJSONData('Send a survey');
        String jsonData5 = WhatsAppFlowController.getJSONData('Customer support');
        Test.stopTest();

        // Asserting the expected result
        System.assertNotEquals(jsonData, null, 'Expected JSON data to not be null');
    }

    @isTest
    public static void testCreateWhatsAppFlow() {
        // Create mock response for the HTTP request inside the controller
        String mockResponseBody = '{"id":"67890"}';
        HttpResponse mockResponse = createMockResponse('200', mockResponseBody);
        MockHttpResponseGenerator mock = new MockHttpResponseGenerator(mockResponse);
        Test.setMock(HttpCalloutMock.class, mock);

        // Run the test
        Test.startTest();
        String flowId = WhatsAppFlowController.createWhatsAppFlow('Test Flow', new List<String>{'OTHER'}, '{"key":"value"}', 'Send a survey', true);
        Test.stopTest();

        // Asserting the expected result
        System.assertNotEquals(flowId, null, 'Expected flow ID to be returned');
    }

    @isTest
    public static void testCreateWhatsAppFlowFail() {
        // Create mock response for the HTTP request inside the controller
        String mockResponseBody = '{"id":"67890"}';
        HttpResponse mockResponse = createMockResponse('403', mockResponseBody);
        MockHttpResponseGenerator mock = new MockHttpResponseGenerator(mockResponse);
        Test.setMock(HttpCalloutMock.class, mock);

        // Run the test
        Test.startTest();
        String flowId = WhatsAppFlowController.createWhatsAppFlow('Test Flow', new List<String>{'OTHER'}, '{"key":"value"}', 'Send a survey', true);
        Test.stopTest();

        // Asserting the expected result
        System.assertNotEquals(flowId, null, 'Expected flow ID to be returned');
    }

    @isTest
    public static void testUpdateWhatsAppFlow() {
        // Create mock response for the HTTP request inside the controller
        HttpResponse mockResponse = createMockResponse('200', '{}');
        MockHttpResponseGenerator mock = new MockHttpResponseGenerator(mockResponse);
        Test.setMock(HttpCalloutMock.class, mock);

        // Run the test
        Test.startTest();
        String result = WhatsAppFlowController.updateWhatsAppFlow('12345', '{"key":"value"}');
        Test.stopTest();
    }

    @isTest
    public static void testUpdateWhatsAppFlowWithScreens() {
        HttpResponse mockResponse = createMockResponse('200', '{}');
        MockHttpResponseGenerator mock = new MockHttpResponseGenerator(mockResponse);
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        String validJson = '{"screens":[{"id":"screen1"}]}';
        String result = WhatsAppFlowController.updateWhatsAppFlow('12345', validJson);
        Test.stopTest();
    }

    @isTest
    public static void testPublishWhatsAppFlow() {
        // Create mock response for the HTTP request inside the controller
        String mockResponseBody = '{"success":true}';
        HttpResponse mockResponse = createMockResponse('200', mockResponseBody);
        MockHttpResponseGenerator mock = new MockHttpResponseGenerator(mockResponse);
        Test.setMock(HttpCalloutMock.class, mock);

        // Run the test
        Test.startTest();
        String result = WhatsAppFlowController.publishWhatsAppFlow('12345');
        Test.stopTest();

        // Asserting the expected result
        System.assertEquals(result, 'success', 'Expected success response');
    }

    @isTest
    public static void testDeleteWhatsAppFlow() {
        // Create mock response for the HTTP request inside the controller
        HttpResponse mockResponse = createMockResponse('200', '{}');
        MockHttpResponseGenerator mock = new MockHttpResponseGenerator(mockResponse);
        Test.setMock(HttpCalloutMock.class, mock);

        // Run the test
        Test.startTest();
        String result = WhatsAppFlowController.deleteWhatsAppFlow('12345');
        Test.stopTest();

        // Asserting the expected result
        System.assertEquals(result, 'sucess', 'Expected success response');
    }

    @isTest
    public static void testDeprecateWhatsAppFlow() {
        // Create mock response for the HTTP request inside the controller
        HttpResponse mockResponse = createMockResponse('200', '{}');
        MockHttpResponseGenerator mock = new MockHttpResponseGenerator(mockResponse);
        Test.setMock(HttpCalloutMock.class, mock);

        // Run the test
        Test.startTest();
        String result = WhatsAppFlowController.deprecateWhatsAppFlow('12345');
        Test.stopTest();

        // Asserting the expected result
        System.assertEquals(result, 'sucess', 'Expected success response');
    }

    @isTest
    public static void testGetPreviewURLofWhatsAppFlow() {
        // Create mock response for the HTTP request inside the controller
        String mockResponseBody = '{"preview":{"preview_url":"https://example.com"}}';
        HttpResponse mockResponse = createMockResponse('200', mockResponseBody);
        MockHttpResponseGenerator mock = new MockHttpResponseGenerator(mockResponse);
        Test.setMock(HttpCalloutMock.class, mock);

        // Run the test
        Test.startTest();
        Map<String,String> result = WhatsAppFlowController.getPreviewURLofWhatsAppFlow('12345');
        Test.stopTest();
        
        // Asserting the expected result
        System.assertEquals('200', result.get('status'), 'Expected status to be 200');
        System.assertEquals('https://example.com', result.get('previewUrl'), 'Expected preview URL to be https://example.com');
    }

    @isTest
    public static void testGetWhatsAppFlowById() {
        Flow__c testFlow = [SELECT Id, Flow_Id__c FROM Flow__c LIMIT 1];
        testFlow.Flow_JSON__c = '{"screens": []}';
        update testFlow;
        
        Flow_Screen__c fsc = new Flow_Screen__c();
        fsc.Flow__c = testFlow.Id;
        fsc.Screen_Id__c = 'screen1';
        fsc.Screen_Flow_Json__c = '{"id":"screen1"}';
        fsc.Screen_Sequence_No__c = 1;
        insert fsc;
        
        List<Flow__c> result = WhatsAppFlowController.getWhatsAppFlowById(testFlow.Flow_Id__c);
        System.assertNotEquals(0, result.size());
    }
}