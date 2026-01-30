@isTest
private class WhatsappConfigControllerTest {
    
    // Setup method to create test data
    @TestSetup
    static void setupTestData() {
        // Create EmbeddedSignUpConfig__c record
        EmbeddedSignUpConfig__c config = new EmbeddedSignUpConfig__c(
            Client_Id__c = 'testClientId',
            Client_Secret__c = 'testClientSecret',
            Config_Id__c = 'testConfigId'
        );
        insert config;
    }
    
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
    
    // Test the constructor with valid metadata
    @isTest
    static void testConstructorWithValidData() {
        // Create mock metadata using a custom metadata type
        // Since we can't insert Custom Metadata in tests, we rely on existing data or mock
        Test.startTest();
        WhatsappConfigController controller = new WhatsappConfigController();
        Test.stopTest();
        
        // Verify the constructor sets properties correctly
        System.assertNotEquals(null, controller, 'Controller should be instantiated');
        System.assertEquals('testClientId', WhatsappConfigController.clientId, 'ClientId should be set');
        System.assertEquals('testClientSecret', WhatsappConfigController.clientSecret, 'ClientSecret should be set');
        System.assertEquals('testConfigId', WhatsappConfigController.configurationId, 'ConfigurationId should be set');
    }
    
    // Test the constructor with no metadata
    @isTest
    static void testConstructorWithNoData() {
        // Delete the setup data to simulate no records
        delete [SELECT Id FROM EmbeddedSignUpConfig__c];
        
        Test.startTest();
        WhatsappConfigController controller = new WhatsappConfigController();
        Test.stopTest();
        
        // Verify the constructor handles empty data
        System.assertEquals(null, WhatsappConfigController.clientId, 'clientId should be null');
        System.assertEquals(null, WhatsappConfigController.clientSecret, 'clientSecret should be null');
        System.assertEquals(null, WhatsappConfigController.configurationId, 'configurationId should be null');
    }
    
    // Test saveFBLoginDetails with successful response
    @isTest
    static void testSaveFBLoginDetailsSuccess() {
        // Prepare mock response
        String mockResponse = '{"access_token": "newAccessToken"}';
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(200, mockResponse));
        
        // Mock metadata deployment
        Test.startTest();
        String result = WhatsappConfigController.saveFBLoginDetails('testAccessToken', 'testPhoneId', 'testWabaId', 'testAppId');
        Test.stopTest();
        
    }
    
    // Test saveFBLoginDetails with no EmbeddedSignUpConfig
    @isTest
    static void testSaveFBLoginDetailsNoConfig() {
        // Delete the setup data
        delete [SELECT Id FROM EmbeddedSignUpConfig__c];
        
        Test.startTest();
        String result = WhatsappConfigController.saveFBLoginDetails('testAccessToken', 'testPhoneId', 'testWabaId', 'testAppId');
        Test.stopTest();
        
        // Verify failure
        System.assertEquals('Failure', result, 'Method should return Failure when no config exists');
    }
    
    // Test saveFBLoginDetails with HTTP error
    @isTest
    static void testSaveFBLoginDetailsHttpError() {
        // Prepare mock response with error
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(400, '{}'));
        
        Test.startTest();
        String result = WhatsappConfigController.saveFBLoginDetails('testAccessToken', 'testPhoneId', 'testWabaId', 'testAppId');
        Test.stopTest();
        
        // Verify null return on error
        System.assertEquals(null, result, 'Method should return null on HTTP error');
    }
    
    // Test saveFBLoginDetails with exception
    @isTest
    static void testSaveFBLoginDetailsException() {
        // Force an exception by passing invalid JSON
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(200, 'invalid json'));
        
        Test.startTest();
        String result = WhatsappConfigController.saveFBLoginDetails('testAccessToken', 'testPhoneId', 'testWabaId', 'testAppId');
        Test.stopTest();
        
        // Verify null return on exception
        System.assertEquals(null, result, 'Method should return null on exception');
    }
    
    // Test unlinkAccount success
    @isTest
    static void testUnlinkAccountSuccess() {
        Test.startTest();
        Boolean result = WhatsappConfigController.unlinkAccount();
        Test.stopTest();

    }
    
    // Test unlinkAccount with exception
    @isTest
    static void testUnlinkAccountException() {
        // Mock an exception by overriding saveMetaData
        WhatsappConfigController.saveMetaData(null, null, null, null); // This will cause a null pointer exception
        
        Test.startTest();
        Boolean result = WhatsappConfigController.unlinkAccount();
        Test.stopTest();
        
        // Verify false return on exception
        System.assertEquals(false, result, 'Method should return false on exception');
    }
    
    // Test saveMetaData with existing metadata
    @isTest
    static void testSaveMetaDataWithExistingData() {
        Test.startTest();
        Boolean result = WhatsappConfigController.saveMetaData('testAccessToken', 'testPhoneId', 'testWabaId', 'testAppId');
        Test.stopTest();
    }
    
    // Test saveMetaData with no existing metadata
    @isTest
    static void testSaveMetaDataWithNoData() {
        // Since we can't mock custom metadata queries, assume no records are returned
        Test.startTest();
        Boolean result = WhatsappConfigController.saveMetaData('testAccessToken', 'testPhoneId', 'testWabaId', 'testAppId');
        Test.stopTest();
        
    }
    
    // Test saveMetaData with exception
    @isTest
    static void testSaveMetaDataException() {
        // Simulate an exception by passing null values that might cause issues
        Test.startTest();
        Boolean result = WhatsappConfigController.saveMetaData(null, null, null, null);
        Test.stopTest();
    }
}