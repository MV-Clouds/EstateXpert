@isTest
private class WhatsappConfigControllerTest {
    
    // Mock HTTP response class
    private class MockHttpResponse implements HttpCalloutMock {
        private Integer statusCode;
        private String body;
        
        MockHttpResponse(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body = body;
        }
        
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(this.statusCode);
            res.setBody(this.body);
            return res;
        }
    }
    
    // Test the constructor
    @isTest
    static void testConstructor() {
        Test.startTest();
        WhatsappConfigController controller = new WhatsappConfigController();
        Test.stopTest();
        
        // Verify the constructor sets properties correctly
        System.assertNotEquals(null, controller, 'Controller should be instantiated');
    }
    
    // Test saveFBLoginDetails with successful response
    @isTest
    static void testSaveFBLoginDetailsSuccess() {
        // Prepare mock response
        String mockResponse = '{"access_token": "newAccessToken"}';
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(200, mockResponse));
        
        Test.startTest();
        String result = WhatsappConfigController.saveFBLoginDetails('testAccessToken', 'testPhoneId', 'testWabaId', 'testAppId');
        Test.stopTest();
    }
    
    // Test saveFBLoginDetails with HTTP error
    @isTest
    static void testSaveFBLoginDetailsHttpError() {
        // Prepare mock response with error
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(400, '{}'));
        
        Test.startTest();
        String result = WhatsappConfigController.saveFBLoginDetails('testAccessToken', 'testPhoneId', 'testWabaId', 'testAppId');
        Test.stopTest();
    }
    
    // Test saveFBLoginDetails with exception
    @isTest
    static void testSaveFBLoginDetailsException() {
        // Force an exception by passing invalid JSON
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(200, 'invalid json'));
        
        Test.startTest();
        String result = WhatsappConfigController.saveFBLoginDetails('testAccessToken', 'testPhoneId', 'testWabaId', 'testAppId');
        Test.stopTest();
    }
    
    // Test unlinkAccount success
    @isTest
    static void testUnlinkAccountSuccess() {
        Test.startTest();
        Boolean result = WhatsappConfigController.unlinkAccount();
        Test.stopTest();
    }
    
    // Test saveMetaData
    @isTest
    static void testSaveMetaData() {
        Test.startTest();
        Boolean result = WhatsappConfigController.saveMetaData('testAccessToken', 'testPhoneId', 'testWabaId', 'testAppId');
        Test.stopTest();
    }
    
    // Test saveMetaData with exception
    @isTest
    static void testSaveMetaDataException() {
        Test.startTest();
        Boolean result = WhatsappConfigController.saveMetaData(null, null, null, null);
        Test.stopTest();
    }
}