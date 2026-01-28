@isTest
public class OutlookIntegrationControllerTest {

    @isTest
    static void testRequestNewAccessToken() {
        OutlookConfig__c config = new OutlookConfig__c(
            Client_ID__c = 'testClientId',
            Client_Secret__c = 'testClientSecret',
            Refresh_Token_1__c = 'testRefreshToken',
            Refresh_Token_2__c = 'testRefreshToken'
        );
        insert config;

        List<OutlookIntegrationController.EmailWrapper> outlookMails = new List<OutlookIntegrationController.EmailWrapper>();
        
        OutlookIntegrationController.EmailWrapper emailWrapper = new OutlookIntegrationController.EmailWrapper();
        emailWrapper.toAddresses = new List<String>{'test@example.com'};
        emailWrapper.ccAddresses = new List<String>{'cc@example.com'};
        emailWrapper.bccAddresses = new List<String>{'bcc@example.com'};
        emailWrapper.subject = 'Test Email';
        emailWrapper.body = 'This is a test email.';

        outlookMails.add(emailWrapper);

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        Test.startTest();
        OutlookIntegrationController.requestNewAccessToken(outlookMails, new Map<String, Integer>(), new Map<String, Marketing_Campaign__c>(), false);
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM OutlookConfig__c], 'MVEX__OutlookConfig__c record should exist.');
    }

    @isTest
    static void testConstructor() {

        // Simulate the code parameter in the URL
        Test.setCurrentPageReference(new PageReference('/somePage?code=testAuthCode'));

        // Prepare mock response for HTTP callout
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        // Call the constructor
        Test.startTest();
        OutlookIntegrationController controller = new OutlookIntegrationController();
        Test.stopTest();

        // Assertions to verify constructor behavior
        System.assertNotEquals(null, controller.refreshToken, 'Refresh token should be populated.');
        System.assertEquals('', controller.errorMessage, 'Error message should be empty.');
    }

    @isTest
    static void testSendEmail() {
        List<OutlookIntegrationController.EmailWrapper> outlookMails = new List<OutlookIntegrationController.EmailWrapper>();
        
        // Correctly instantiate the EmailWrapper class and set properties
        OutlookIntegrationController.EmailWrapper emailWrapper = new OutlookIntegrationController.EmailWrapper();
        emailWrapper.toAddresses = new List<String>{'test@example.com'};
        emailWrapper.ccAddresses = new List<String>{'cc@example.com'};
        emailWrapper.bccAddresses = new List<String>{'bcc@example.com'};
        emailWrapper.subject = 'Test Email';
        emailWrapper.body = 'This is a test email.';

        outlookMails.add(emailWrapper);
        // Prepare mock response for HTTP callout
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        // Call the method
        Test.startTest();
        OutlookIntegrationController.sendEmail('mockAccessToken', JSON.serialize(outlookMails), null, null, false);
        Test.stopTest();

        System.assertEquals(1, outlookMails.size(), 'Emails list should contain one email.');
    }

    // Mock HTTP response generator
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"access_token": "mockAccessToken", "refresh_token": "newMockRefreshToken"}');
            return res;
        }
    }
}