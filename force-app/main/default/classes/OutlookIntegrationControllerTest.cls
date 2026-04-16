@isTest
public class OutlookIntegrationControllerTest {

    private class HttpMock implements HttpCalloutMock {
        private Integer statusCode;
        private String responseBody;

        public HttpMock(Integer statusCode, String responseBody) {
            this.statusCode = statusCode;
            this.responseBody = responseBody;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            if (req.getEndpoint().contains('token')) {
                res.setStatusCode(this.responseBody.contains('batch_failed') ? 200 : statusCode);
                res.setBody(this.responseBody.contains('batch_failed') ? '{"access_token":"newAccessToken","refresh_token":"newRefreshToken"}' : responseBody);
                return res;
            } else {
                res.setStatusCode(statusCode);
                res.setBody(responseBody);
                return res;
            }
        }
    }

    @TestSetup
    static void setupTestData() {
        TempData__c tempData = new TempData__c(
            Client_ID__c = 'testClientId',
            Client_Secret__c = 'testClientSecret',
            Redirect_URI__c = 'https://test.redirect.uri'
        );
        insert tempData;
        
        OutlookConfig__c config = new OutlookConfig__c(
            Client_ID__c = 'testClientId',
            Client_Secret__c = 'testClientSecret',
            Refresh_Token_1__c = 'testRefreshToken',
            Refresh_Token_2__c = 'testRefreshToken2'
        );
        insert config;

        Marketing_Campaign__c campaign = new Marketing_Campaign__c(Status__c = 'Pending');
        insert campaign;
    }

    @isTest
    static void testConstructorWithValidAuthCode() {
        Test.setCurrentPageReference(new PageReference('/somePage?code=testAuthCode'));
        Test.setMock(HttpCalloutMock.class, new HttpMock(200, '{"access_token": "mockAccessToken", "refresh_token": "newMockRefreshToken"}'));

        Test.startTest();
        OutlookIntegrationController controller = new OutlookIntegrationController();
        Test.stopTest();

        System.assertNotEquals(null, controller.refreshToken);
        System.assertEquals('', controller.errorMessage);
        System.assertEquals(false, controller.isFailed);
    }
    
    @isTest
    static void testConstructorWithoutAuthCode() {
        Test.setCurrentPageReference(new PageReference('/somePage'));
        Test.startTest();
        OutlookIntegrationController controller = new OutlookIntegrationController();
        Test.stopTest();
        System.assertEquals(true, controller.isFailed);
    }
    
    @isTest
    static void testConstructorException() {
        Test.setCurrentPageReference(new PageReference('/somePage?code=testAuthCode'));
        Test.setMock(HttpCalloutMock.class, new HttpMock(500, 'server error'));
        Test.startTest();
        OutlookIntegrationController controller = new OutlookIntegrationController();
        Test.stopTest();
        System.assertEquals(true, controller.isFailed);
    }
    
    @isTest
    static void testConstructorMissingRefreshToken() {
        Test.setCurrentPageReference(new PageReference('/somePage?code=testAuthCode'));
        Test.setMock(HttpCalloutMock.class, new HttpMock(200, '{"access_token": "mockAccessToken"}'));
        Test.startTest();
        OutlookIntegrationController controller = new OutlookIntegrationController();
        Test.stopTest();
        System.assertEquals(true, controller.isFailed);
    }

    @isTest
    static void testRequestNewAccessTokenException() {
        Test.startTest();
        OutlookIntegrationController.requestNewAccessToken(null, null, null, false);
        Test.stopTest();
    }

    @isTest
    static void testRequestNewAccessTokenSuccess() {
        List<OutlookIntegrationController.EmailWrapper> outlookMails = new List<OutlookIntegrationController.EmailWrapper>();
        OutlookIntegrationController.EmailWrapper emailWrapper = new OutlookIntegrationController.EmailWrapper();
        emailWrapper.toAddresses = new List<String>{'test@example.com'};
        emailWrapper.ccAddresses = new List<String>{'cc@example.com'};
        emailWrapper.bccAddresses = new List<String>{'bcc@example.com'};
        emailWrapper.subject = 'Test Email';
        emailWrapper.body = 'This is a test email.';
        outlookMails.add(emailWrapper);
        
        Test.setMock(HttpCalloutMock.class, new HttpMock(200, '{"access_token": "mockAccessToken", "refresh_token": "newMockRefreshToken"}'));
        Test.startTest();
        OutlookIntegrationController.requestNewAccessToken(outlookMails, new Map<String, Integer>(), new Map<String, Marketing_Campaign__c>(), true);
        Test.stopTest();
    }

    @isTest
    static void testSendEmailSuccess() {
        List<OutlookIntegrationController.EmailWrapper> outlookMails = new List<OutlookIntegrationController.EmailWrapper>();
        OutlookIntegrationController.EmailWrapper emailWrapper = new OutlookIntegrationController.EmailWrapper();
        emailWrapper.toAddresses = new List<String>{'test@example.com'};
        emailWrapper.ccAddresses = new List<String>{'cc@example.com'};
        emailWrapper.bccAddresses = new List<String>{'bcc@example.com'};
        emailWrapper.subject = 'Test Email';
        emailWrapper.body = 'This is a test email.';
        emailWrapper.contactEmailInfoMap = new Map<String, Map<String, String>>{
            '003000000000001' => new Map<String, String>{
                'subject' => 'Test Subject',
                'body' => 'Test Body',
                'email' => 'test@example.com'
            }
        };
        outlookMails.add(emailWrapper);
        
        Map<String, Integer> remainingEmails = new Map<String, Integer>{ 'test@example.com' => 1 };
        Map<String, Marketing_Campaign__c> campaign = new Map<String, Marketing_Campaign__c>{
            'test@example.com' => [SELECT Id, Name FROM Marketing_Campaign__c LIMIT 1]
        };

        Test.setMock(HttpCalloutMock.class, new HttpMock(200, '{"access_token":"newAccessToken"}'));

        Test.startTest();
        OutlookIntegrationController.sendEmail(JSON.serialize(outlookMails), JSON.serialize(remainingEmails), JSON.serialize(campaign), true);
        Test.stopTest();
    }
    
    @isTest
    static void testSendEmailFailedToken() {
        List<OutlookIntegrationController.EmailWrapper> emailList = new List<OutlookIntegrationController.EmailWrapper>{new OutlookIntegrationController.EmailWrapper()};
        
        Test.setMock(HttpCalloutMock.class, new HttpMock(400, '{"error":"invalid_grant"}'));

        Test.startTest();
        OutlookIntegrationController.sendEmail(JSON.serialize(emailList), JSON.serialize(new Map<String, Integer>()), JSON.serialize(new Map<String, Marketing_Campaign__c>()), false);
        Test.stopTest();
    }
    
    @isTest
    static void testSendEmailBatchFailed() {
        List<OutlookIntegrationController.EmailWrapper> outlookMails = new List<OutlookIntegrationController.EmailWrapper>();
        OutlookIntegrationController.EmailWrapper emailWrapper = new OutlookIntegrationController.EmailWrapper();
        emailWrapper.toAddresses = new List<String>{'test@example.com'};
        outlookMails.add(emailWrapper);
        
        Map<String, Integer> remainingEmails = new Map<String, Integer>{ 'test@example.com' => 1 };
        Map<String, Marketing_Campaign__c> campaign = new Map<String, Marketing_Campaign__c>{
            'test@example.com' => [SELECT Id, Name FROM Marketing_Campaign__c LIMIT 1]
        };

        Test.setMock(HttpCalloutMock.class, new HttpMock(400, 'batch_failed'));

        Test.startTest();
        OutlookIntegrationController.sendEmail(JSON.serialize(outlookMails), JSON.serialize(remainingEmails), JSON.serialize(campaign), true);
        Test.stopTest();
    }
    
    @isTest
    static void testSendEmailException() {
        Test.startTest();
        OutlookIntegrationController.sendEmail('invalid json', null, null, false);
        Test.stopTest();
    }
}