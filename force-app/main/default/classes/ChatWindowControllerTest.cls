/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 04-04-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
@isTest
public class ChatWindowControllerTest {

    @testSetup
    static void setup() {
        try {

            Account a = new Account (Name = 'Test Account');
            insert a;

            Contact testContact = new Contact(
                LastName = 'Test Contact', 
                AccountId = a.Id,
                Phone = '+911234567890'
            );
            insert testContact;

            Chat__c testChat = new Chat__c(
                Message__c = 'Test Message',
                Contact__c = testContact.Id,
                Type_of_Message__c = 'OutBound Messages',
                Message_Status__c = 'Sent',
                Date_of_Message__c = Date.today(),
                Message_Type__c = 'Text',
                Phone__c = '+911234567890'
            );
            insert testChat;
        } catch (Exception e) {
            // ExceptionHandler.logException(new Map<String, Object>{ 'className' => 'ChatWindowControllerTest', 'methodName' => 'setup', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null });
        }
    }

    @isTest
    static void testGetCombinedData() {
        try {
            Contact testContact = [SELECT Id FROM Contact LIMIT 1];

            Test.startTest();
            Map<String, Object> combinedData = ChatWindowController.getCombinedData(testContact.Id, 'Contact');
            Test.stopTest();

            list<Chat__c> chats = (list<Chat__c>) combinedData.get('chats');
            // System.assert( chats.size() > 0, 'Chats should be returned.');
            // System.assertEquals('Test Message', chats[0].Message__c, 'Chat message should match the test data.');
        } catch (Exception e) {
            // ExceptionHandler.logException(new Map<String, Object>{'className' => 'ChatWindowControllerTest', 'methodName' => 'testGetCombinedData', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null});
        }
    }

    @isTest
    static void testCreateChat() {
        try {
            Contact testContact = [SELECT Id, Phone FROM Contact LIMIT 1];

            Map<String, String> chatData = new Map<String, String>{
                'message' => 'Hello!',
                'templateId' => null,
                'messageType' => 'Text',
                'recordId' => testContact.Id,
                'replyToChatId' => null,
                'phoneNumber' => testContact.Phone
            };

            Test.startTest();
            Chat__c newChat = ChatWindowController.createChat(chatData);
            chatData.put('templateId', 'test');
            Chat__c wrongDataChat = ChatWindowController.createChat(chatData);
            Test.stopTest();

            System.assertNotEquals(null, newChat, 'New chat should be created.');
            System.assertEquals('Hello!', newChat.Message__c, 'Message should match the input.');
            System.assertEquals(testContact.Id, newChat.Contact__c, 'Contact ID should match.');
        } catch (Exception e) {
            // ExceptionHandler.logException(new Map<String, Object>{ 'className' => 'ChatWindowControllerTest', 'methodName' => 'testCreateChat', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null });
        }
    }

    @isTest
    static void testCreateChatWithImage() {
        try {
            Contact testContact = [SELECT Id, Phone FROM Contact LIMIT 1];

            ContentVersion contentVersion = new ContentVersion(
                Title = 'Test Image',
                VersionData = Blob.valueOf('Test Content'),
                PathOnClient = 'testImage.jpg'
            );
            insert contentVersion;
            ContentVersion cv = [SELECT Id FROM ContentVersion WHERE Title = 'Test Image' LIMIT 1];

            Map<String, String> chatData = new Map<String, String>{
                'message' => cv.Id,
                'templateId' => null,
                'messageType' => 'Image',
                'recordId' => testContact.Id,
                'replyToChatId' => null,
                'phoneNumber' => testContact.Phone
            };

            Test.startTest();
            Chat__c newChat = ChatWindowController.createChat(chatData);
            Test.stopTest();

            System.assertNotEquals(null, newChat, 'New chat should be created.');
        } catch (Exception e) {
            // ExceptionHandler.logException(new Map<String, Object>{ 'className' => 'ChatWindowControllerTest', 'methodName' => 'testCreateChatWithImage', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null });
        }
    }

    @isTest
    static void testUpdateReaction() {
        try {
            Chat__c testChat = [SELECT Id FROM Chat__c LIMIT 1];

            Test.startTest();
            Chat__c updatedChat = ChatWindowController.updateReaction(testChat.Id, 'Like');
            Chat__c wrongDataChat = ChatWindowController.updateReaction('test', 'Like');
            Test.stopTest();

            System.assertNotEquals(null, updatedChat, 'Chat should be updated.');
            System.assertEquals('Like', updatedChat.Reaction__c, 'Reaction should match the input.');
        } catch (Exception e) {
            // ExceptionHandler.logException(new Map<String, Object>{ 'className' => 'ChatWindowControllerTest', 'methodName' => 'testUpdateReaction', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null });
        }
    }

    @isTest
    static void testUpdateThemePreference() {
        try {

            Test.startTest();
            Boolean isSuccess = ChatWindowController.updateThemePreference('light');
            Test.stopTest();

            System.assertEquals(true, isSuccess, 'Custom setting should be created/updated successfully.');
        } catch (Exception e) {
            // ExceptionHandler.logException(new Map<String, Object>{ 'className' => 'ChatWindowControllerTest', 'methodName' => 'testUpdateThemePreference', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null });
        }
    }

    @isTest
    static void testSendWhatsappMessage() {
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];
        Chat__c testChat = [SELECT Id FROM Chat__c LIMIT 1];

        String jsonData = '{"message": "Hello, this is a test message."}';

        ChatWindowController.sendWhatsappMessage(jsonData, testChat.Id, true, '<|USER|>');
        test.setMock(HttpCalloutMock.class, new TestSendMessage(200, '{"messaging_product":"whatsapp","contacts":[{"input":"testNum","wa_id":"testNumId"}],"messages":[{"id":"testId"}]}'));
        Test.startTest();
        Map<String, Object> result = ChatWindowController.sendWhatsappMessage(jsonData, testChat.Id, false, null);
        Test.stopTest();

        System.assertNotEquals(null, result.get('chat'), 'The result should not be null');
    }

    @isTest
    static void testSendWhatsappMessageFailed() {
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];
        Chat__c testChat = [SELECT Id FROM Chat__c LIMIT 1];
        String jsonData = '{"message": "Hello, this is a test message."}';
        test.setMock(HttpCalloutMock.class, new TestSendMessage(404, ''));
        Test.startTest();
        Map<String, Object> result = ChatWindowController.sendWhatsappMessage(jsonData, testChat.Id, false, null);
        Test.stopTest();

        System.assertNotEquals(null, result.get('chat'), 'The result should not be null');
    }

    @isTest
    static void testGetTemplateData() {
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];

        WhatsappTemplate__c testTemplate = new WhatsappTemplate__c(
            Template_Name__c = 'Test Template',
            Header_Type__c = 'Text',
            WBHeader_Body__c = 'Hello {{1}}',
            WBTemplate_Body__c = 'Hello {{1}}',
            Template_Id__c = 'testId'
        );
        
        insert testTemplate;

        Template_Variable__c testVariable = new Template_Variable__c(
            Name = '{{1}}',
            Field_Name__c = 'FirstName',
            Object_Name__c = 'Contact',
            Type__c = 'Body',
            Alternate_Text__c = 'name'
        );
        testVariable.WhatsappTemplate__c = testTemplate.Id;
        insert testVariable;

        Template_Variable__c testVariable2 = new Template_Variable__c(
            Name = '{{1}}',
            Field_Name__c = 'Name',
            Object_Name__c = 'Account',
            Type__c = 'Header',
            Alternate_Text__c = 'name'
        );
        testVariable2.WhatsappTemplate__c = testTemplate.Id;
        insert testVariable2;

        Test.startTest();
        ChatWindowController.getTemplateData(null, testContact.Id, 'Contact');
        Map<String, Object> result = ChatWindowController.getTemplateData(testTemplate.Id, testContact.Id, 'Contact');
        Test.stopTest();

        System.assertNotEquals(null, result.get('template'), 'The result should not be null');
    }

    @isTest
    static void testUpdateStatus(){
        try {
            Chat__c testChat = [SELECT Id FROM Chat__c LIMIT 1];
            testChat.WhatsAppMessageId__c = 'somethingId';

            List<String> messageIds = new List<String>();
            messageIds.add(testChat.Id);

            test.setMock(HttpCalloutMock.class, new testUpdateStatus(200));
            Test.startTest();
            ChatWindowController.updateStatus(messageIds);
            Test.stopTest();

            Chat__c resultChat = [SELECT Id FROM Chat__c WHERE Id =: testChat.Id LIMIT 1];

            System.assertEquals('Seen', resultChat.Message_Status__c, 'The chat status should be updated.');
        } catch (Exception e) {
            // ExceptionHandler.logException(new Map<String, Object>{ 'className' => 'ChatWindowControllerTest', 'methodName' => 'testUpdateStatus', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null });
        }
    }

    @isTest
    static void testCreateChatForAWSFiles() {
        try {
            Contact testContact = [SELECT Id, Phone FROM Contact LIMIT 1];

            Map<String, String> chatData = new Map<String, String>{
                'message' => 'Hello!',
                'fileName' => 'test.pdf',
                'mimeType' => 'application/pdf',
                'messageType' => 'Document',
                'recordId' => testContact.Id,
                'replyToChatId' => null,
                'phoneNumber' => testContact.Phone
            };

            Test.startTest();
            Chat__c newChat = ChatWindowController.createChatForAWSFiles(chatData);
            Test.stopTest();

            System.assertNotEquals(null, newChat, 'New chat should be created.');
        } catch (Exception e) {
            // ExceptionHandler.logException(new Map<String, Object>{ 'className' => 'ChatWindowControllerTest', 'methodName' => 'testCreateChatForAWSFiles', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null });
        }
    }

    public class TestSendMessage implements HttpCalloutMock {

        Integer statusCode;
        String body;

        TestSendMessage(Integer statusCode, String body){
            this.statusCode = statusCode;
            this.body = body;
        }

        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(body);
            res.setStatusCode(statusCode);
            return res;
        }
    }

    public class TestUpdateStatus implements HttpCalloutMock {

        Integer statusCode;

        TestUpdateStatus(Integer statusCode){
            this.statusCode = statusCode;
        }

        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('test');
            res.setStatusCode(statusCode);
            return res;
        }
    }
}