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

    @isTest
    static void testGetObjectPicklistOptions() {
        Test.startTest();
        List<String> options = ChatWindowController.getObjectPicklistOptions();
        Test.stopTest();
    }

    @isTest
    static void testGetChatsForSelectedObjectContact() {
        Test.startTest();
        Map<String, Map<String, Object>> result = ChatWindowController.getChatsForSelectedObject('Contact');
        Test.stopTest();
    }

    @isTest
    static void testGetChatsForSelectedObjectLead() {
        Lead testLead = new Lead(LastName = 'Test Lead', Company = 'Test Company', Phone = '1234567890', Status = 'Open - Not Contacted');
        insert testLead;

        Test.startTest();
        Map<String, Map<String, Object>> result = ChatWindowController.getChatsForSelectedObject('Lead');
        Test.stopTest();
    }

    @isTest
    static void testGetChatsForSelectedObjectException() {
        Test.startTest();
        Map<String, Map<String, Object>> result = ChatWindowController.getChatsForSelectedObject('InvalidObject123__c');
        Test.stopTest();
    }

    @isTest
    static void testBuildInteractivePayload() {
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];
        
        WhatsappTemplate__c testTemplate = new WhatsappTemplate__c(
            Template_Name__c = 'Test Template',
            WBTemplate_Body__c = 'Test Payload {{RECIPIENT_NUMBER}}',
            Header_Type__c = 'Text',
            MVEX__Template_Id__c = 'Test Temp'
        );
        insert testTemplate;
        
        Test.startTest();
        String payload = ChatWindowController.buildInteractivePayload(testTemplate.Id, testContact.Id, 'Contact', '1234567890');
        Test.stopTest();
        System.assertNotEquals(null, payload);
    }
    
    @isTest
    static void testBuildInteractivePayloadException() {
        Test.startTest();
        String payload = ChatWindowController.buildInteractivePayload(null, null, null, null);
        Test.stopTest();
        System.assertEquals(null, payload);
    }

    @isTest
    static void testGetTemplatePreviewData() {
        Chat__c testChat = [SELECT Id FROM Chat__c LIMIT 1];
        testChat.Sent_Template_Details__c = '{"some": "detail"}';
        update testChat;

        WhatsappTemplate__c testTemplate = new WhatsappTemplate__c(
            Template_Name__c = 'Test Template Preview',
            Header_Type__c = 'Image',
            WBTemplate_Body__c = 'Test Payload Preview',
            MVEX__Template_Id__c = 'Test Temp'
        );
        insert testTemplate;

        Test.startTest();
        Map<String, Object> result = ChatWindowController.getTemplatePreviewData(testTemplate.Id, testChat.Id);
        Test.stopTest();
        System.assertNotEquals(null, result);
    }
    
    @isTest
    static void testGetTemplatePreviewDataVideo() {
        Chat__c testChat = [SELECT Id FROM Chat__c LIMIT 1];

        WhatsappTemplate__c testTemplate = new WhatsappTemplate__c(
            Template_Name__c = 'Test Template Preview',
            Header_Type__c = 'Video',
            WBTemplate_Body__c = 'Test Payload Preview',
            MVEX__Template_Id__c = 'Test Temp'
        );
        insert testTemplate;

        Test.startTest();
        Map<String, Object> result = ChatWindowController.getTemplatePreviewData(testTemplate.Id, testChat.Id);
        Test.stopTest();
    }
    
    @isTest
    static void testGetTemplatePreviewDataDocument() {
        Chat__c testChat = [SELECT Id FROM Chat__c LIMIT 1];

        WhatsappTemplate__c testTemplate = new WhatsappTemplate__c(
            Template_Name__c = 'Test Template Preview',
            Header_Type__c = 'Document',
            WBTemplate_Body__c = 'Test Payload Preview',
            MVEX__Template_Id__c = 'Test Temp'
        );
        insert testTemplate;

        Test.startTest();
        Map<String, Object> result = ChatWindowController.getTemplatePreviewData(testTemplate.Id, testChat.Id);
        Test.stopTest();
    }
    
    @isTest
    static void testGetTemplatePreviewDataException() {
        Test.startTest();
        Map<String, Object> result = ChatWindowController.getTemplatePreviewData(null, null);
        Test.stopTest();
    }

    @isTest
    static void testGetFieldValue() {
        Contact testContact = [SELECT Id, AccountId FROM Contact LIMIT 1];
        Test.startTest();
        Object val1 = ChatWindowController.getFieldValue(testContact, 'AccountId');
        
        Contact testContactWithRelation = [SELECT Id, Account.Name FROM Contact WHERE Id = :testContact.Id LIMIT 1];
        Object val2 = ChatWindowController.getFieldValue(testContactWithRelation, 'Account.Name');
        
        Object val3 = ChatWindowController.getFieldValue(testContact, 'Invalid_Field__c');
        Object val4 = ChatWindowController.getFieldValue(testContact, 'Invalid.Relation.Field');
        Object val5 = ChatWindowController.getFieldValue(null, 'AccountId');
        Test.stopTest();
        
        System.assertNotEquals(null, val2);
    }

    @isTest
    static void testGetCombinedDataException() {
        Test.startTest();
        Map<String, Object> result = ChatWindowController.getCombinedData(null, null);
        Test.stopTest();
    }

    @isTest
    static void testCreateChatExceptions() {
        Test.startTest();
        Map<String, String> chatData = new Map<String, String>{
            'messageType' => 'Image',
            'message' => '069000000000000'
        };
        Chat__c chat = ChatWindowController.createChat(chatData);
        System.assertEquals(null, chat);
        Test.stopTest();
    }

    @isTest
    static void testCreateChatAWSException() {
        Test.startTest();
        ChatWindowController.createChatForAWSFiles(null);
        Test.stopTest();
    }

    @isTest
    static void testUpdateReactionException() {
        Test.startTest();
        ChatWindowController.updateReaction(null, null);
        Test.stopTest();
    }

    @isTest
    static void testUpdateThemePreferenceException() {
        Test.startTest();
        try{
            String tooLongTheme = 'A';
            while(tooLongTheme.length() < 300) { tooLongTheme += tooLongTheme; }
            ChatWindowController.updateThemePreference(tooLongTheme);
        }catch(Exception e){}
        Test.stopTest();
    }

    @isTest
    static void testSendWhatsappMessageWithTemplate() {
        Chat__c testChat = [SELECT Id FROM Chat__c LIMIT 1];
        String jsonData = '{"template": {"components": [{"type": "header"}]}}';
        
        test.setMock(HttpCalloutMock.class, new TestSendMessage(200, '{"messaging_product":"whatsapp","messages":[{"id":"testId"}]}'));
        Test.startTest();
        ChatWindowController.sendWhatsappMessage(jsonData, testChat.Id, false, null);
        Test.stopTest();
    }
    
    @isTest
    static void testSendWhatsappMessageWithInteractive() {
        Chat__c testChat = [SELECT Id FROM Chat__c LIMIT 1];
        String jsonData = '{"interactive": {"type": "button", "body": {"text": "test"}}}';
        
        test.setMock(HttpCalloutMock.class, new TestSendMessage(200, '{"messaging_product":"whatsapp","messages":[{"id":"testId"}]}'));
        Test.startTest();
        ChatWindowController.sendWhatsappMessage(jsonData, testChat.Id, false, null);
        Test.stopTest();
    }

    @isTest
    static void testGetTemplateDataException() {
        Test.startTest();
        ChatWindowController.getTemplateData(null, null, null);
        Test.stopTest();
    }

    @isTest
    static void testGetTemplateDataDocumentVideo() {
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];

        WhatsappTemplate__c testTemplateVideo = new WhatsappTemplate__c(
            Template_Name__c = 'Test Temp Video',
            Header_Type__c = 'Video',
            MVEX__Template_Id__c = 'Test temp'
        );
        insert testTemplateVideo;
        
        WhatsappTemplate__c testTemplateDoc = new WhatsappTemplate__c(
            Template_Name__c = 'Test Temp Doc',
            Header_Type__c = 'Document',
            MVEX__Template_Id__c = 'Test Temp'
        );
        insert testTemplateDoc;

        Test.startTest();
        ChatWindowController.getTemplateData(testTemplateVideo.Id, testContact.Id, 'Contact');
        ChatWindowController.getTemplateData(testTemplateDoc.Id, testContact.Id, 'Contact');
        Test.stopTest();
    }
    
    @isTest
    static void testGetTemplateDataWithVariablesDocVideoImg() {
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];

        WhatsappTemplate__c testTemplateDoc = new WhatsappTemplate__c(
            Template_Name__c = 'Test Temp Doc2',
            Header_Type__c = 'Document',
            WBHeader_Body__c = 'Doc {{1}}',
            MVEX__Template_Id__c = 'Test temp'
        );
        insert testTemplateDoc;
        
        Template_Variable__c testVariable1 = new Template_Variable__c(
            Name = '{{1}}',
            Field_Name__c = 'FirstName',
            Object_Name__c = 'Contact',
            Type__c = 'Header',
            Alternate_Text__c = 'name',
            WhatsappTemplate__c = testTemplateDoc.Id
        );
        insert testVariable1;

        WhatsappTemplate__c testTemplateVid = new WhatsappTemplate__c(
            Template_Name__c = 'Test Temp Vid2',
            Header_Type__c = 'Video',
            WBHeader_Body__c = 'Vid {{1}}',
            MVEX__Template_Id__c = 'Test Temp'
        );
        insert testTemplateVid;

        Template_Variable__c testVariable2 = new Template_Variable__c(
            Name = '{{1}}',
            Field_Name__c = 'FirstName',
            Object_Name__c = 'Contact',
            Type__c = 'Header',
            Alternate_Text__c = 'name',
            WhatsappTemplate__c = testTemplateVid.Id
        );
        insert testVariable2;
        
        WhatsappTemplate__c testTemplateImg = new WhatsappTemplate__c(
            Template_Name__c = 'Test Temp Img2',
            Header_Type__c = 'Image',
            WBHeader_Body__c = 'Img {{1}}',
            MVEX__Template_Id__c = 'Test Temp'
        );
        insert testTemplateImg;

        Template_Variable__c testVariable3 = new Template_Variable__c(
            Name = '{{1}}',
            Field_Name__c = 'FirstName',
            Object_Name__c = 'Contact',
            Type__c = 'Header',
            Alternate_Text__c = 'name',
            WhatsappTemplate__c = testTemplateImg.Id
        );
        insert testVariable3;

        Test.startTest();
        ChatWindowController.getTemplateData(testTemplateDoc.Id, testContact.Id, 'Contact');
        ChatWindowController.getTemplateData(testTemplateVid.Id, testContact.Id, 'Contact');
        ChatWindowController.getTemplateData(testTemplateImg.Id, testContact.Id, 'Contact');
        Test.stopTest();
    }
}