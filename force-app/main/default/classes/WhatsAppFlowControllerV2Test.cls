@isTest
private class WhatsAppFlowControllerV2Test {

    @TestSetup
    static void setupTestData(){

        // Prepare existing flow data
        Flow__c existingFlow = new Flow__c(
            Flow_Id__c = 'flow-1',
            Flow_JSON__c = '{"screens":["QUESTION_ONE","QUESTION_TWO","QUESTION_THREE"],"version":"7.2"}'
        );
        insert existingFlow;

        AWS_Config__c awsConfig = new AWS_Config__c(
            AWS_Access_Key__c = 'testAccessKey',
            AWS_Secret_Access_Key__c = 'testSecretKey',
            S3_Bucket_Name__c = 'test-bucket',
            S3_Region_Name__c = 'us-east-1'
        );
        insert awsConfig;

        // Prepare Flow Screen records
        List<Flow_Screen__c> flowScreens = new List<Flow_Screen__c>();
        flowScreens.add(new Flow_Screen__c(
            Flow__c = existingFlow.Id,
            Screen_Id__c = 'QUESTION_ONE',
            Screen_Flow_Json__c = '{"id":"QUESTION_ONE","title":"Question One","layout":{"type":"SingleColumnLayout","children":[{"type":"Image","src":"https://wbconnect.s3.amazonaws.com/test-image-1.jpg"}]}}',
            Screen_Sequence_No__c = 1
        ));
        flowScreens.add(new Flow_Screen__c(
            Flow__c = existingFlow.Id,
            Screen_Id__c = 'QUESTION_TWO',
            Screen_Flow_Json__c = '{"id":"QUESTION_TWO","title":"Question Two","layout":{"type":"SingleColumnLayout","children":[{"type":"Image","src":"https://wbconnect.s3.amazonaws.com/test-image-2.png"}]}}',
            Screen_Sequence_No__c = 2
        ));
        flowScreens.add(new Flow_Screen__c(
            Flow__c = existingFlow.Id,
            Screen_Id__c = 'QUESTION_THREE',
            Screen_Flow_Json__c = '{"id":"QUESTION_THREE","title":"Question Three","layout":{"type":"SingleColumnLayout","children":[{"type":"Image","src":"https://wbconnect.s3.amazonaws.com/test-image-3.jpg"}]}}',
            Screen_Sequence_No__c = 3
        ));
        insert flowScreens;
    }

    // Mocking the HTTP response for testing
    static HttpResponse createMockResponse(String statusCode, String body){
        HttpResponse res = new HttpResponse();
        res.setStatusCode(Integer.valueOf(statusCode));
        res.setBody(body);
        return res;
    }

    @isTest
    public static void testGetAllJSONData() {
        
        Test.startTest();
        Map<String, String> flowJsonDataMap = WhatsAppFlowControllerV2.getAllJSONData();
        Test.stopTest();
    }

    @isTest
    public static void testGetFlowElementTypes(){
        Test.startTest();
        Map<String, List<WhatsAppFlowControllerV2.FlowElementDescriptor>> flowElementsTypes = WhatsAppFlowControllerV2.getFlowElementTypes();
        Test.stopTest();
    }

    @isTest
    public static void testSaveWhatsAppFlowCreateFlowSuccess(){

        // Create mock response for the HTTP request inside the controller
        HttpResponse mockResponse = createMockResponse('200', '{"Create Flow": {"value": {"id": "flow-1"}}}');
        MockHttpResponseGenerator mock = new MockHttpResponseGenerator(mockResponse);
        Test.setMock(HttpCalloutMock.class, mock);
        
        Test.startTest();
        // Call the method that makes the HTTP callout
        String flowId = WhatsAppFlowControllerV2.saveWhatsAppFlow('Test Flow', new List<String>{'SIGN_UP','CONTACT_US'}, '{"version": "7.2","screens": [{"id": "DEMO_SCREEN","title": "Demo","terminal": true,"layout": {"type": "SingleColumnLayout","children": [{"type":"Image","src":"https://www.vecteezy.com/free-photos/image"},{"type": "Footer","label": "Continue","on-click-action": {"name": "complete","payload": {}}}]}}]}', 'Send a survey', null, null);
        Test.stopTest();
    }

    @isTest
    public static void testSaveWhatsAppFlowCreateFlowFail(){

        // Create mock response for the HTTP request inside the controller
        HttpResponse mockResponse = createMockResponse('400', '{"error": {"message": "Bad Request"}}');
        MockHttpResponseGenerator mock = new MockHttpResponseGenerator(mockResponse);
        Test.setMock(HttpCalloutMock.class, mock);
        
        Test.startTest();
        // Call the method that makes the HTTP callout
        String flowId = WhatsAppFlowControllerV2.saveWhatsAppFlow('Test Flow', new List<String>{'SIGN_UP','CONTACT_US'}, '{"version": "7.2","screens": [{"id": "DEMO_SCREEN","title": "Demo","terminal": true,"layout": {"type": "SingleColumnLayout","children": [{"type": "Footer","label": "Continue","on-click-action": {"name": "complete","payload": {}}]}}]}', 'Send a survey', null, null);
        Test.stopTest();
    }

    // @isTest
    // public static void testSaveWhatsAppFlowCreateFlowFail400(){

    //     // Create mock response for the HTTP request inside the controller
    //     HttpResponse mockResponse = createMockResponse('400', '{"error": {"message": "Bad Request"}}');
    //     MockHttpResponseGenerator mock = new MockHttpResponseGenerator(mockResponse);
    //     Test.setMock(HttpCalloutMock.class, mock);
        
    //     Test.startTest();
    //     // Call the method that makes the HTTP callout
    //     String flowId = WhatsAppFlowControllerV2.saveWhatsAppFlow('Test Flow', new List<String>{'SIGN_UP','CONTACT_US'}, '{"version": "7.2","screens": [{"id": "DEMO_SCREEN","title": "Demo","terminal": true,"layout": {"type": "SingleColumnLayout","children": [{"type": "Footer","label": "Continue","on-click-action": {"name": "complete","payload": {}}]}}]}', 'Send a survey', null, null);
    //     Test.stopTest();
    // }


    @isTest
    public static void testSaveWhatsAppFlowUpdateFlowSuccess(){

        // Create mock response for the HTTP request inside the controller
        HttpResponse mockResponse = createMockResponse('200', '{"Create Flow": {"value": {"id": "flow-1"}}}');
        MockHttpResponseGenerator mock = new MockHttpResponseGenerator(mockResponse);
        Test.setMock(HttpCalloutMock.class, mock);
        
        Test.startTest();
        // Call the method that makes the HTTP callout
        String flowId = WhatsAppFlowControllerV2.saveWhatsAppFlow('Test Flow', new List<String>{'SIGN_UP','CONTACT_US'}, '{"version": "7.2","screens": [{"id": "DEMO_SCREEN","title": "Demo","terminal": true,"layout": {"type": "SingleColumnLayout","children": [{"type": "Footer","label": "Continue","on-click-action": {"name": "complete","payload": {}}}]}}]}', 'Send a survey', null, 'flow-1');
        Test.stopTest();
    }

    @isTest
    public static void testGetFlowByIdWithScreens(){
        Test.startTest();
        Flow__c flowRecord = [SELECT Id, Flow_Id__c, Flow_JSON__c FROM Flow__c LIMIT 1];
        String flowJson = WhatsAppFlowControllerV2.getFlowByIdWithScreens(flowRecord.Id);
        Test.stopTest();
    }
    
    @isTest
    public static void testPublishWhatsAppFlowSuccess(){
        // Create mock response for the HTTP request inside the controller
        HttpResponse mockResponse = createMockResponse('200', '{"Create Flow": {"value": {"id": "flow-1"}}}');
        MockHttpResponseGenerator mock = new MockHttpResponseGenerator(mockResponse);
        Test.setMock(HttpCalloutMock.class, mock);
        
        Test.startTest();
        Flow__c flowRecord = [SELECT Id, Flow_Id__c, Flow_JSON__c FROM Flow__c LIMIT 1];
        String result = WhatsAppFlowControllerV2.publishWhatsAppFlow('flow-1', flowRecord.Id);
        Test.stopTest();
    }

    @isTest
    public static void testPublishWhatsAppFlowFail(){
        Test.startTest();
        Flow__c flowRecord = [SELECT Id, Flow_Id__c, Flow_JSON__c FROM Flow__c LIMIT 1];
        String result = WhatsAppFlowControllerV2.publishWhatsAppFlow('flow-1', flowRecord.Id);
        Test.stopTest();
    }

    @isTest
    public static void testCloneWhatsAppFlowSuccess(){
        // Create mock response for the HTTP request inside the controller
        HttpResponse mockResponse = createMockResponse('200', '{"Create Flow": {"value": {"id": "flow-1"}}}');
        MockHttpResponseGenerator mock = new MockHttpResponseGenerator(mockResponse);
        Test.setMock(HttpCalloutMock.class, mock);
        
        Test.startTest();
        Flow__c flowRecord = [SELECT Id, Flow_Id__c, Flow_JSON__c FROM Flow__c LIMIT 1];
        String result = WhatsAppFlowControllerV2.cloneWhatsAppFlow(flowRecord.Id, 'Cloneed Flow');
        Test.stopTest();
    }

    @isTest
    public static void testDeleteFlowRecordTriggerBeforeDelete(){
        // Create mock response for AWS S3 delete operation
        HttpResponse mockResponse = createMockResponse('200', '<?xml version="1.0" encoding="UTF-8"?><DeleteResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/"></DeleteResult>');
        MockHttpResponseGenerator mock = new MockHttpResponseGenerator(mockResponse);
        Test.setMock(HttpCalloutMock.class, mock);
        
        // Query the existing flow record created in setup
        Flow__c flowRecord = [SELECT Id, Flow_Id__c, Flow_JSON__c FROM Flow__c LIMIT 1];
        
        Test.startTest();
        delete flowRecord;
        Test.stopTest();
        
        // Verify the record is deleted
        List<Flow__c> deletedFlows = [SELECT Id FROM Flow__c WHERE Id = :flowRecord.Id];
        System.assertEquals(0, deletedFlows.size(), 'Flow record should be deleted');
        
    }
}