/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 04-05-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
@IsTest
private class WhatsAppWebhookTest {

    @testSetup static void setup() {
        // Create common test contact
        Contact testContact = new Contact(
                LastName = 'Test Contact', 
                Phone = '+919428234735'
            );
        Contact testContact2 = new Contact(
                LastName = 'Test Contact2', 
                Phone = '+919501082174'
            );
        Contact testContact3 = new Contact(
                LastName = 'Test Contact3', 
                Phone = '+919664599641'
            );
        Contact testContact4 = new Contact(
                LastName = 'Test Contact4', 
                Phone = '+919558680273'
            );
        List<Contact> conlist = new List<Contact>();
        conlist.add(testContact);
        conlist.add(testContact2);
        conlist.add(testContact3);
        insert conlist;      
        
        WhatsappTemplate__c temp = new WhatsappTemplate__c(
            Template_Name__c = 'hello_world',
            Status__c = 'In-Review',
            Template_Id__c = '138470518808412',
            MVEX__Template_Id__c = '138470518808412'
        );
        insert temp;

        Chat__c dummyChatReact = new Chat__c(
            WhatsAppMessageId__c = 'wamid.HBgMOTE5NjY0NTk5NjQxFQIAERgSNjMxRUI5Mzg0RTlBRTUwNEM5AA==',
            Phone__c = '+919664599641'
        );
        insert dummyChatReact;
    }
    
    @IsTest
    static void testDoGetWithValidToken() {
        // Setup mock HTTP request for GET
        RestRequest req = new RestRequest();
        req.requestURI = '/WBI/webhooks/v1/';
        req.httpMethod = 'GET';
        req.addParameter('hub.verify_token', 'WHATSAPPTOKEN');
        req.addParameter('hub.challenge', '319254377948692');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        // Execute the GET method
        WhatsAppWebhook.doGet();

        // Assert the response contains the expected challenge
        System.assertEquals('319254377948692', RestContext.response.responseBody.toString(), 'Expected the challenge to be returned.');
    }

    @IsTest
    static void testDoPostWithValidToken() {
        // Setup mock HTTP request for POST
        RestRequest req = new RestRequest();
        req.requestURI = '/WBI/webhooks/v1/';
        req.httpMethod = 'POST';
        req.addHeader('hub.verify_token', '7fa1634d4f849b8ced3a249ec4ce8bb7db4d8046');
        req.requestBody = Blob.valueOf('{"object":"whatsapp_business_account","entry":[{"id":"319254377948692","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"919558019600","phone_number_id":"397858113402150"},"contacts":[{"profile":{"name":"Rachit Shah"},"wa_id":"919428234735"}],"messages":[{"context":{"from":"919558019600","id":"wamid.HBgMOTE5NDI4MjM0NzM1FQIAERgSRjAwQzUxODZDQTcwQTIxREQwAA=="},"from":"919428234735","id":"wamid.HBgMOTE5NDI4MjM0NzM1FQIAEhggQkYwODA3RkY0RDJGMDg1REFENzU0OEM5MUEzMUFDMTUA","timestamp":"2147483647","type":"button","button":{"payload":"OPT-OUT","text":"OPT-OUT"}}]},"field":"messages"}]}]}');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        // Execute the POST method
        WhatsAppWebhook.doPost();

    }

    @IsTest
    static void testDoPostWithInvalidToken() {
        // Setup mock HTTP request for POST with invalid token
        RestRequest req = new RestRequest();
        req.requestURI = '/WBI/webhooks/v1/';
        req.httpMethod = 'POST';
        req.addHeader('hub.verify_token', 'INVALIDTOKEN');
        req.requestBody = Blob.valueOf('{"object":"whatsapp_business_account","entry":[{"id":"319254377948692","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"919558019600","phone_number_id":"397858113402150"},"contacts":[{"profile":{"name":"Rachit Shah"},"wa_id":"919428234735"}],"messages":[{"from":"919428234735","id":"wamid.HBgMOTE5NDI4MjM0NzM1FQIAEhggRDNCQzM4RjNDMkEwNzJDMUVBQkFGREZGOUFDRkZGN0EA","timestamp":"2147483647","text":{"body":"Reply to first one"},"type":"text"}]},"field":"messages"}]}]}');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        // Execute the POST method
        WhatsAppWebhook.doPost();
    }

    @IsTest
    static void testProcessWhatsAppPayloadText() {
        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setHeader('Content-Type', 'application/json');
        mockResponse.setStatusCode(200);
        mockResponse.setBodyAsBlob(Blob.valueOf('mock-binary-data'));

        String jsonPayload = '{"object":"whatsapp_business_account","entry":[{"id":"319254377948692","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"919558019600","phone_number_id":"397858113402150"},"contacts":[{"profile":{"name":"Rachit Shah"},"wa_id":"919428234735"}],"messages":[{"from":"919428234735","id":"wamid.HBgMOTE5NDI4MjM0NzM1FQIAEhggRDNCQzM4RjNDMkEwNzJDMUVBQkFGREZGOUFDRkZGN0EA","timestamp":"2147483647","text":{"body":"Reply to first one"},"type":"text"}]},"field":"messages"}]}]}';
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(mockResponse));
        WhatsAppWebhook.processWhatsAppPayload(jsonPayload);
        Test.stopTest();
        System.assertEquals('397858113402150', WhatsAppWebhook.phoneNumberId, 'Expected phone number ID to be set.');
    }

    @IsTest
    static void testProcessWhatsAppPayloadVideo() {
        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setHeader('Content-Type', 'application/json');
        mockResponse.setStatusCode(200);
        mockResponse.setBodyAsBlob(Blob.valueOf('mock-binary-data'));

        String videojsonPayload = '{"object":"whatsapp_business_account","entry":[{"id":"319254377948692","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"919558019600","phone_number_id":"397858113402150"},"contacts":[{"profile":{"name":"Rachit Shah"},"wa_id":"919428234735"}],"messages":[{"from":"919428234735","id":"wamid.HBgMOTE5NDI4MjM0NzM1FQIAEhggNDE0MjFDQjJDOUZGNEIzMjI5RDc1NDlEODU5RUE5QzEA","timestamp":"2147483647","type":"video","video":{"mime_type":"video/mp4","sha256":"T1dLSnJNE3t4mnzLZWSjBWCe61sptppyhF/K//Brx4U=","id":"3827582537491666"}}]},"field":"messages"}]}]}';
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(mockResponse));
        WhatsAppWebhook.processWhatsAppPayload(videojsonPayload);
        Test.stopTest();
        System.assertEquals('397858113402150', WhatsAppWebhook.phoneNumberId, 'Expected phone number ID to be set.');
    }

    @IsTest
    static void testProcessWhatsAppPayloadAudio() {
        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setHeader('Content-Type', 'application/json');
        mockResponse.setStatusCode(200);
        mockResponse.setBodyAsBlob(Blob.valueOf('mock-binary-data'));

        String audiojsonPayload = '{"object":"whatsapp_business_account","entry":[{"id":"319254377948692","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"919558019600","phone_number_id":"397858113402150"},"contacts":[{"profile":{"name":"Rachit Shah"},"wa_id":"919428234735"}],"messages":[{"from":"919428234735","id":"wamid.HBgMOTE5NDI4MjM0NzM1FQIAEhggNDE0MjFDQjJDOUZGNEIzMjI5RDc1NDlEODU5RUE5QzEA","timestamp":"2147483647","type":"audio","audio":{"mime_type":"audio/mp3","sha256":"T1dLSnJNE3t4mnzLZWSjBWCe61sptppyhF/K//Brx4U=","id":"3827582537491666"}}]},"field":"messages"}]}]}';
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(mockResponse));
        WhatsAppWebhook.processWhatsAppPayload(audiojsonPayload);
        Test.stopTest();
        System.assertEquals('397858113402150', WhatsAppWebhook.phoneNumberId, 'Expected phone number ID to be set.');
    }

    @IsTest
    static void testProcessWhatsAppPayloadImage() {
        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setHeader('Content-Type', 'application/json');
        mockResponse.setStatusCode(200);
        mockResponse.setBodyAsBlob(Blob.valueOf('mock-binary-data'));

        String imagejsonPayload = '{"object":"whatsapp_business_account","entry":[{"id":"499269473267232","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"919328195415","phone_number_id":"544633438726755"},"contacts":[{"profile":{"name":"Rachit Shah"},"wa_id":"919664599641"}],"messages":[{"from":"919664599641","id":"wamid.HBgMOTE5NjY0NTk5NjQxFQIAEhggNTA0QTg1REVFMUVFNTNDODc2MDY0Q0Y2NEI5OTE3RTYA","timestamp":"2147483647","type":"image","image":{"mime_type":"image\\/jpeg","sha256":"5S\\/A4mJNraAT\\/AXCeuFFs5UWrLyr+4HIKu3Ub+UsYpw=","id":"1373448587344141"}}]},"field":"messages"}]}]}';
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(mockResponse));
        WhatsAppWebhook.processWhatsAppPayload(imagejsonPayload);
        Test.stopTest();
        System.assertEquals('544633438726755', WhatsAppWebhook.phoneNumberId, 'Expected phone number ID to be set.');
    }

    @IsTest
    static void testProcessWhatsAppPayloadDoc() {
        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setHeader('Content-Type', 'application/json');
        mockResponse.setStatusCode(200);
        mockResponse.setBodyAsBlob(Blob.valueOf('mock-binary-data'));

        String documentjsonPayload = '{"object":"whatsapp_business_account","entry":[{"id":"319254377948692","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"919558019600","phone_number_id":"397858113402150"},"contacts":[{"profile":{"name":"Rachit Shah"},"wa_id":"919428234735"}],"messages":[{"from":"919428234735","id":"wamid.HBgMOTE5NDI4MjM0NzM1FQIAEhggNDE0MjFDQjJDOUZGNEIzMjI5RDc1NDlEODU5RUE5QzEA","timestamp":"2147483647","type":"document","document":{"mime_type":"document/pdf","sha256":"T1dLSnJNE3t4mnzLZWSjBWCe61sptppyhF/K//Brx4U=","id":"3827582537491666"}}]},"field":"messages"}]}]}';
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(mockResponse));
        WhatsAppWebhook.processWhatsAppPayload(documentjsonPayload);
        Test.stopTest();
        System.assertEquals('397858113402150', WhatsAppWebhook.phoneNumberId, 'Expected phone number ID to be set.');
    }

    @IsTest
    static void testProcessWhatsAppPayloadReaction() {
        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setHeader('Content-Type', 'application/json');
        mockResponse.setStatusCode(200);
        mockResponse.setBodyAsBlob(Blob.valueOf('mock-binary-data'));

        String documentjsonPayload = '{"object":"whatsapp_business_account","entry":[{"id":"499269473267232","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"919558019600","phone_number_id":"397858113402150"},"contacts":[{"profile":{"name":"Rachit Shah"},"wa_id":"919664599641"}],"messages":[{"from":"919664599641","id":"wamid.HBgMOTE5NjY0NTk5NjQxFQIAEhggQjdDNEQ0OTk1ODQyNkEwQjExNDdBRDNEQjFCNkRBN0UA","timestamp":"2147483647","type":"reaction","reaction":{"message_id":"wamid.HBgMOTE5NjY0NTk5NjQxFQIAERgSNjMxRUI5Mzg0RTlBRTUwNEM5AA==","emoji":"\ud83d\udc4d"}}]},"field":"messages"}]}]}';
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(mockResponse));
        WhatsAppWebhook.processWhatsAppPayload(documentjsonPayload);
        Test.stopTest();
        System.assertEquals('397858113402150', WhatsAppWebhook.phoneNumberId, 'Expected phone number ID to be set.');
    }

    @IsTest
    static void testHandleMediaAttachment() {
        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setHeader('Content-Type', 'application/json');
        mockResponse.setStatusCode(200);
        mockResponse.setBody('{"url": "https://media-server.com/path-to-media"}');

        String documentId = '3827582537491666';
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(mockResponse));
        WhatsAppWebhook.handleMediaAttachment(documentId);
        Test.stopTest();
    }
    
    @IsTest
    static void testSaveMediaToSalesforce() {
        String documentId = '3827582537491666';
        Contact testcontact = [SELECT Id from Contact LIMIT 1];
        Test.startTest();
        WhatsAppWebhook.saveMediaToSalesforce(Blob.valueOf('mock-binary-data'), 'filename', 'filetype', testcontact.Id, 'Contact');
        Test.stopTest();
    }

    @isTest
    static void testGetFileExtension() {
        // Expected extensions
        System.assertEquals('.jpeg', WhatsAppWebhook.getFileExtension('image/jpeg'));
        System.assertEquals('.png', WhatsAppWebhook.getFileExtension('image/png'));
        System.assertEquals('.jpg', WhatsAppWebhook.getFileExtension('image/jpg'));
        System.assertEquals('.mp3', WhatsAppWebhook.getFileExtension('audio/mp3'));
        System.assertEquals('.mp3', WhatsAppWebhook.getFileExtension('audio/mpeg'));
        System.assertEquals('.aac', WhatsAppWebhook.getFileExtension('audio/aac'));
        System.assertEquals('.ogg', WhatsAppWebhook.getFileExtension('audio/ogg; codecs=opus'));
        System.assertEquals('.mp4', WhatsAppWebhook.getFileExtension('video/mp4'));
        System.assertEquals('.3gp', WhatsAppWebhook.getFileExtension('video/3gp'));
        System.assertEquals('.pdf', WhatsAppWebhook.getFileExtension('application/pdf'));
        System.assertEquals('.doc', WhatsAppWebhook.getFileExtension('application/msword'));
        System.assertEquals('.docx', WhatsAppWebhook.getFileExtension('application/vnd.openxmlformats-officedocument.wordprocessingml.document'));
        System.assertEquals('.ppt', WhatsAppWebhook.getFileExtension('application/vnd.ms-powerpoint'));
        System.assertEquals('.pptx', WhatsAppWebhook.getFileExtension('application/vnd.openxmlformats-officedocument.presentationml.presentation'));
        System.assertEquals('.xls', WhatsAppWebhook.getFileExtension('application/vnd.ms-excel'));
        System.assertEquals('.xlsx', WhatsAppWebhook.getFileExtension('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'));
        System.assertEquals('.txt', WhatsAppWebhook.getFileExtension('text/plain'));

        // Test invalid mime type
        System.assertEquals('.bin', WhatsAppWebhook.getFileExtension('unknown/mimetype'));
    }

    @isTest
    static void testUpdateWhatsAppTemplateStatus(){
        WhatsappTemplate__c testTemp = [SELECT Id, Template_Id__c, Status__c FROM WhatsappTemplate__c LIMIT 1];

        Test.startTest();
        WhatsAppWebhook.updateWhatsAppTemplateStatus(testTemp.Template_Id__c, 'APPROVED');

        WhatsAppWebhook.updateWhatsAppTemplateStatus(testTemp.Template_Id__c, 'PENDING');

        WhatsAppWebhook.updateWhatsAppTemplateStatus(testTemp.Template_Id__c, 'REJECTED');
        Test.stopTest();

        WhatsappTemplate__c updatedTemplate = [SELECT Id, Template_Id__c, Status__c FROM WhatsappTemplate__c WHERE Template_Id__c = :testTemp.Template_Id__c LIMIT 1];
        System.assertEquals('Rejected', updatedTemplate.Status__c);
    }

    @isTest
    static void testGetFlowJsonFromContextId() {
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];
        
        // Create Flow__c record
        Flow__c testFlow = new Flow__c(
            Flow_Id__c = 'test_flow_123',
            Flow_JSON__c = '{"screens": [{"layout": {"children": []}}]}'
        );
        insert testFlow;
        
        // Create WhatsappTemplate__c with flow button
        WhatsappTemplate__c template = new WhatsappTemplate__c(
            Template_Name__c = 'flow_template',
            Status__c = 'Active-Quality Pending',
            WBButton_Body__c = '[{"type": "FLOW", "flow_id": "test_flow_123"}]',
            MVEX__Template_Id__c = 'test_flow_template_123'
        );
        insert template;
        
        // Create Chat__c with template
        Chat__c chat = new Chat__c(
            WhatsAppMessageId__c = 'test_context_id_123',
            Contact__c = testContact.Id,
            WhatsappTemplate__c = template.Id
        );
        insert chat;
        
        Test.startTest();
        Map<String, Object> result = WhatsAppWebhook.getFlowJsonFromContextId('test_context_id_123');
        Map<String, Object> nullResult = WhatsAppWebhook.getFlowJsonFromContextId('');
        Map<String, Object> invalidResult = WhatsAppWebhook.getFlowJsonFromContextId('invalid_context');
        Test.stopTest();
        
        System.assertNotEquals(null, result);
        System.assertEquals(null, nullResult);
    }

    @isTest
    static void testCreateFlowSubmissionRecord() {
        Contact testContact = [SELECT Id, Phone FROM Contact WHERE Phone = '+919428234735' LIMIT 1];
        
        Flow__c testFlow = new Flow__c(
            Flow_Id__c = 'submission_flow',
            Flow_JSON__c = '{"screens": []}'
        );
        insert testFlow;
        
        String labelToValueJson = '{"field1": "value1", "field2": "value2"}';
        
        Test.startTest();
        WhatsAppWebhook.createFlowSubmissionRecord(testContact.Phone, testFlow.Id, labelToValueJson);
        Test.stopTest();
    }

    @isTest
    static void testMapResponseToLabels() {
        String flowJson = '{"screens": [{"layout": {"children": [{"type": "Form", "name": "form_1", "children": [{"type": "TextInput", "name": "field1", "label": "Field One"}]}]}}]}';
        String responseJson = '{"screen_0_form_0": {"field1": "test_value"}}';
        
        Test.startTest();
        String result = WhatsAppWebhook.mapResponseToLabels(flowJson, responseJson);
        Test.stopTest();
        
        System.assertNotEquals(null, result);
    }

    @isTest
    static void testDownloadMediaContent() {
        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setHeader('Content-Type', 'application/json');
        mockResponse.setStatusCode(200);
        mockResponse.setBodyAsBlob(Blob.valueOf('test-media-content'));
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(mockResponse));
        Blob result = WhatsAppWebhook.downloadMediaContent('https://test.com/media', 'test_token');
        Test.stopTest();
        
        System.assertNotEquals(null, result);
    }

    @isTest
    static void testSendNotificationForContact() {
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];
        User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        
        Test.startTest();
        WhatsAppWebhook.sendNotificationForContact(testContact.Id, 'Contact', testUser.Id);
        Test.stopTest();
    }

    @isTest
    static void testParseMessages() {
        String jsonString = '{"object":"whatsapp_business_account","entry":[{"id":"319254377948692","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"919558019600","phone_number_id":"397858113402150"},"statuses":[{"id":"wamid.test","status":"sent","timestamp":"2147483647","recipient_id":"919428234735"}]},"field":"messages"}]}]}';
        
        Test.startTest();
        WhatsAppWebhook.parseMessages(jsonString);
        Test.stopTest();
    }

    @isTest
    static void testSendEmail() {
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];
        ContentVersion cv = new ContentVersion(
            Title = 'TestDoc',
            PathOnClient = 'TestDoc.pdf',
            VersionData = Blob.valueOf('Test Content'),
            FirstPublishLocationId = testContact.Id
        );
        insert cv;
        
        ContentVersion insertedCV = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
        
        String body = '{"linkedEntityId":"' + testContact.Id + '","contentDocumentId":"' + insertedCV.ContentDocumentId + '"}';
        
        Test.startTest();
        WhatsAppWebhook.sendEmail(body);
        Test.stopTest();
    }

    @isTest
    static void testSendWhatsAppResponse() {
        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setStatusCode(200);
        mockResponse.setBody('{"success": true}');
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(mockResponse));
        WhatsAppWebhook.sendWhatsAppResponse('showing123', 'confirmed', '+919428234735', 'context123');
        Test.stopTest();
    }

    @isTest
    static void testSendWhatsAppMessageAsync() {
        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setStatusCode(200);
        mockResponse.setBody('{"messages": [{"id": "wamid.test123"}]}');
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(mockResponse));
        WhatsAppWebhook.sendWhatsAppMessageAsync('chat123', 'showing456', '+919428234735', 'Test message', 'context456');
        Test.stopTest();
    }

    @isTest
    static void testProcessWhatsAppPayloadButton() {
        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setHeader('Content-Type', 'application/json');
        mockResponse.setStatusCode(200);
        mockResponse.setBodyAsBlob(Blob.valueOf('mock-data'));

        String buttonPayload = '{"object":"whatsapp_business_account","entry":[{"id":"319254377948692","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"919558019600","phone_number_id":"397858113402150"},"contacts":[{"profile":{"name":"Test User"},"wa_id":"919428234735"}],"messages":[{"from":"919428234735","id":"wamid.button123","timestamp":"2147483647","type":"button","button":{"payload":"test_payload","text":"Click Me"}}]},"field":"messages"}]}]}';
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(mockResponse));
        WhatsAppWebhook.processWhatsAppPayload(buttonPayload);
        Test.stopTest();
    }

    @isTest
    static void testProcessWhatsAppPayloadInteractive() {
        Contact testContact = [SELECT Id, Phone FROM Contact WHERE Phone = '+919428234735' LIMIT 1];
        
        Flow__c testFlow = new Flow__c(
            Flow_Id__c = 'interactive_flow',
            Flow_JSON__c = '{"screens": [{"layout": {"children": [{"type": "Form", "name": "form1", "children": [{"type": "TextInput", "name": "name", "label": "Name"}]}]}}]}'
        );
        insert testFlow;
        
        WhatsappTemplate__c template = new WhatsappTemplate__c(
            Template_Name__c = 'interactive_template',
            Status__c = 'Active-Quality Pending',
            WBButton_Body__c = '[{"type": "FLOW", "flow_id": "interactive_flow"}]',
            MVEX__Template_Id__c = 'interactive_template_456'
        );
        insert template;
        
        Chat__c contextChat = new Chat__c(
            WhatsAppMessageId__c = 'context_interactive_123',
            Contact__c = testContact.Id,
            WhatsappTemplate__c = template.Id
        );
        insert contextChat;

        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setStatusCode(200);
        mockResponse.setBodyAsBlob(Blob.valueOf('mock-data'));

        String interactivePayload = '{"object":"whatsapp_business_account","entry":[{"id":"319254377948692","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"919558019600","phone_number_id":"397858113402150"},"contacts":[{"profile":{"name":"Test User"},"wa_id":"919428234735"}],"messages":[{"from":"919428234735","id":"wamid.interactive456","timestamp":"2147483647","type":"interactive","context":{"from":"919558019600","id":"context_interactive_123"},"interactive":{"type":"nfm_reply","nfm_reply":{"response_json":"{\\"screen_0_form_0\\":{\\"name\\":\\"John\\"}}", "body":"Flow response"}}}]},"field":"messages"}]}]}';
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(mockResponse));
        WhatsAppWebhook.processWhatsAppPayload(interactivePayload);
        Test.stopTest();
    }

    @isTest
    static void testCDLWrapperClass() {
        Test.startTest();
        WhatsAppWebhook.CDLWrapper wrapper = new WhatsAppWebhook.CDLWrapper('entityId123', 'docId456');
        Test.stopTest();
        
        System.assertEquals('entityId123', wrapper.linkedEntityId);
        System.assertEquals('docId456', wrapper.contentDocumentId);
    }

    @isTest
    static void testOldMessageTimestamp() {
        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setStatusCode(200);
        mockResponse.setBodyAsBlob(Blob.valueOf('mock-data'));

        // Message with old timestamp (older than 10 minutes)
        String oldPayload = '{"object":"whatsapp_business_account","entry":[{"id":"319254377948692","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"919558019600","phone_number_id":"397858113402150"},"contacts":[{"profile":{"name":"Test User"},"wa_id":"919428234735"}],"messages":[{"from":"919428234735","id":"wamid.old123","timestamp":"1000000000","type":"text","text":{"body":"Old message"}}]},"field":"messages"}]}]}';
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(mockResponse));
        WhatsAppWebhook.processWhatsAppPayload(oldPayload);
        Test.stopTest();
        
        // Should not create chat record for old messages
        List<Chat__c> chats = [SELECT Id FROM Chat__c WHERE WhatsAppMessageId__c = 'wamid.old123'];
        System.assertEquals(0, chats.size());
    }

    @isTest
    static void testDuplicateMessageHandling() {
        Contact testContact = [SELECT Id, Phone FROM Contact WHERE Phone = '+919428234735' LIMIT 1];
        
        // Create existing chat record
        Chat__c existingChat = new Chat__c(
            WhatsAppMessageId__c = 'wamid.duplicate123',
            Phone__c = testContact.Phone
        );
        insert existingChat;

        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setStatusCode(200);
        mockResponse.setBodyAsBlob(Blob.valueOf('mock-data'));

        String duplicatePayload = '{"object":"whatsapp_business_account","entry":[{"id":"319254377948692","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"919558019600","phone_number_id":"397858113402150"},"contacts":[{"profile":{"name":"Test User"},"wa_id":"919428234735"}],"messages":[{"from":"919428234735","id":"wamid.duplicate123","timestamp":"2147483647","type":"text","text":{"body":"Duplicate"}}]},"field":"messages"}]}]}';
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(mockResponse));
        WhatsAppWebhook.processWhatsAppPayload(duplicatePayload);
        Test.stopTest();
        
        // Should still have only one chat record
        List<Chat__c> chats = [SELECT Id FROM Chat__c WHERE WhatsAppMessageId__c = 'wamid.duplicate123'];
        System.assertEquals(1, chats.size());
    }

    @isTest
    static void testButtonPayloadWithShowing() {
        Contact testContact = [SELECT Id, Phone FROM Contact WHERE Phone = '+919428234735' LIMIT 1];
        
        // Create context chat
        Chat__c contextChat = new Chat__c(
            WhatsAppMessageId__c = 'wamid.context_showing',
            Phone__c = testContact.Phone
        );
        insert contextChat;
        
        // Create Showing__c record
        Showing__c showing = new Showing__c(
            Chat__c = contextChat.Id,
            Status__c = 'Waiting For Confirmation',
            Scheduled_Date__c = System.now().addDays(1)
        );
        insert showing;

        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setStatusCode(200);
        mockResponse.setBodyAsBlob(Blob.valueOf('mock-data'));

        // Test Confirm Visit button
        String confirmPayload = '{"object":"whatsapp_business_account","entry":[{"id":"319254377948692","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"919558019600","phone_number_id":"397858113402150"},"contacts":[{"profile":{"name":"Test User"},"wa_id":"919428234735"}],"messages":[{"from":"919428234735","id":"wamid.confirm123","timestamp":"2147483647","type":"button","context":{"from":"919558019600","id":"wamid.context_showing"},"button":{"payload":"Confirm Visit","text":"Confirm"}}]},"field":"messages"}]}]}';
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(mockResponse));
        WhatsAppWebhook.processWhatsAppPayload(confirmPayload);
        Test.stopTest();
        
        // Verify showing status updated
        Showing__c updatedShowing = [SELECT Status__c FROM Showing__c WHERE Id = :showing.Id];
        System.assertEquals('Scheduled', updatedShowing.Status__c);
    }

    @isTest
    static void testButtonPayloadCancelShowing() {
        Contact testContact = [SELECT Id, Phone FROM Contact WHERE Phone = '+919428234735' LIMIT 1];
        
        // Create context chat
        Chat__c contextChat = new Chat__c(
            WhatsAppMessageId__c = 'wamid.context_cancel',
            Phone__c = testContact.Phone
        );
        insert contextChat;
        
        // Create Showing__c record
        Showing__c showing = new Showing__c(
            Chat__c = contextChat.Id,
            Status__c = 'Waiting For Confirmation',
            Scheduled_Date__c = System.now().addDays(1)
        );
        insert showing;

        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setStatusCode(200);
        mockResponse.setBodyAsBlob(Blob.valueOf('mock-data'));

        // Test Cancel button
        String cancelPayload = '{"object":"whatsapp_business_account","entry":[{"id":"319254377948692","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"919558019600","phone_number_id":"397858113402150"},"contacts":[{"profile":{"name":"Test User"},"wa_id":"919428234735"}],"messages":[{"from":"919428234735","id":"wamid.cancel123","timestamp":"2147483647","type":"button","context":{"from":"919558019600","id":"wamid.context_cancel"},"button":{"payload":"Cancel","text":"Cancel"}}]},"field":"messages"}]}]}';
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(mockResponse));
        WhatsAppWebhook.processWhatsAppPayload(cancelPayload);
        Test.stopTest();
        
        // Verify showing status updated
        Showing__c updatedShowing = [SELECT Status__c FROM Showing__c WHERE Id = :showing.Id];
        System.assertEquals('Cancelled', updatedShowing.Status__c);
    }

    @isTest
    static void testInteractiveWithShowingReschedule() {
        Contact testContact = [SELECT Id, Phone FROM Contact WHERE Phone = '+919428234735' LIMIT 1];
        
        Flow__c testFlow = new Flow__c(
            Flow_Id__c = 'reschedule_flow',
            Flow_JSON__c = '{"screens": [{"layout": {"children": [{"type": "Form", "name": "form1", "children": [{"type": "DatePicker", "name": "reschedule_date", "label": "Date"}, {"type": "TimePicker", "name": "reschedule_time", "label": "Time"}]}]}}]}'
        );
        insert testFlow;
        
        WhatsappTemplate__c template = new WhatsappTemplate__c(
            Template_Name__c = 'reschedule_template',
            Status__c = 'Active-Quality Pending',
            WBButton_Body__c = '[{"type": "FLOW", "flow_id": "reschedule_flow"}]',
            MVEX__Template_Id__c = 'reschedule_template_789'
        );
        insert template;
        
        Chat__c contextChat = new Chat__c(
            WhatsAppMessageId__c = 'wamid.context_reschedule',
            Phone__c = testContact.Phone,
            WhatsappTemplate__c = template.Id
        );
        insert contextChat;
        
        // Create Showing__c record
        Showing__c showing = new Showing__c(
            Chat__c = contextChat.Id,
            Status__c = 'Scheduled',
            Scheduled_Date__c = System.now().addDays(1)
        );
        insert showing;

        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setStatusCode(200);
        mockResponse.setBodyAsBlob(Blob.valueOf('mock-data'));

        String reschedulePayload = '{"object":"whatsapp_business_account","entry":[{"id":"319254377948692","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"919558019600","phone_number_id":"397858113402150"},"contacts":[{"profile":{"name":"Test User"},"wa_id":"919428234735"}],"messages":[{"from":"919428234735","id":"wamid.reschedule456","timestamp":"2147483647","type":"interactive","context":{"from":"919558019600","id":"wamid.context_reschedule"},"interactive":{"type":"nfm_reply","nfm_reply":{"response_json":"{\\"screen_0_reschedule_date_0\\":\\"2026-02-15\\",\\"screen_0_reschedule_time_1\\":\\"14:30\\"}","body":"Reschedule response"}}}]},"field":"messages"}]}]}';
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(mockResponse));
        WhatsAppWebhook.processWhatsAppPayload(reschedulePayload);
        Test.stopTest();
        
        // Verify showing status updated to Rescheduled
        Showing__c updatedShowing = [SELECT Status__c, Reschedule_Date__c FROM Showing__c WHERE Id = :showing.Id];
        System.assertEquals('Rescheduled', updatedShowing.Status__c);
        System.assertNotEquals(null, updatedShowing.Reschedule_Date__c);
    }

    @isTest
    static void testGetFlowJsonEdgeCases() {
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];
        
        // Test with template without flow_id
        WhatsappTemplate__c templateNoFlow = new WhatsappTemplate__c(
            Template_Name__c = 'no_flow_template',
            Status__c = 'Active-Quality Pending',
            WBButton_Body__c = '[{"type": "URL", "url": "https://test.com"}]',
            MVEX__Template_Id__c = 'no_flow_template_001'
        );
        insert templateNoFlow;
        
        Chat__c chatNoFlow = new Chat__c(
            WhatsAppMessageId__c = 'no_flow_context',
            Phone__c = '+919428234735',
            WhatsappTemplate__c = templateNoFlow.Id
        );
        insert chatNoFlow;
        
        // Test with empty button body
        WhatsappTemplate__c templateEmpty = new WhatsappTemplate__c(
            Template_Name__c = 'empty_template',
            Status__c = 'Active-Quality Pending',
            MVEX__Template_Id__c = 'empty_template_002'
        );
        insert templateEmpty;
        
        Chat__c chatEmpty = new Chat__c(
            WhatsAppMessageId__c = 'empty_context',
            Phone__c = '+919428234735',
            WhatsappTemplate__c = templateEmpty.Id
        );
        insert chatEmpty;
        
        Test.startTest();
        Map<String, Object> resultNoFlow = WhatsAppWebhook.getFlowJsonFromContextId('no_flow_context');
        Map<String, Object> resultEmpty = WhatsAppWebhook.getFlowJsonFromContextId('empty_context');
        Test.stopTest();
        
        System.assertEquals(null, resultNoFlow);
        System.assertEquals(null, resultEmpty);
    }

    @isTest
    static void testDownloadMediaContentError() {
        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setStatusCode(404);
        mockResponse.setBody('{"error": "Not found"}');
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(mockResponse));
        Blob result = WhatsAppWebhook.downloadMediaContent('https://test.com/media', 'test_token');
        Test.stopTest();
        
        System.assertEquals(null, result);
    }

    @isTest
    static void testDoGetInvalidToken() {
        RestRequest req = new RestRequest();
        req.requestURI = '/WBI/webhooks/v1/';
        req.httpMethod = 'GET';
        req.addParameter('hub.verify_token', 'INVALIDTOKEN');
        req.addParameter('hub.challenge', '123456');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        WhatsAppWebhook.doGet();
        Test.stopTest();
        
        // Response should be empty for invalid token
        System.assertEquals(null, RestContext.response.responseBody);
    }

    @isTest
    static void testProcessWhatsAppPayloadWithException() {
        String invalidPayload = 'invalid json';
        
        Test.startTest();
        WhatsAppWebhook.processWhatsAppPayload(invalidPayload);
        Test.stopTest();
        
        // Should handle exception gracefully without throwing
    }

    @isTest
    static void testReactionWithEmptyReactToChat() {
        Contact testContact = [SELECT Id, Phone FROM Contact WHERE Phone = '+919664599641' LIMIT 1];
        
        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setStatusCode(200);
        mockResponse.setBodyAsBlob(Blob.valueOf('mock-data'));

        // Reaction to non-existent message
        String reactionPayload = '{"object":"whatsapp_business_account","entry":[{"id":"499269473267232","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"919558019600","phone_number_id":"397858113402150"},"contacts":[{"profile":{"name":"Test User"},"wa_id":"919664599641"}],"messages":[{"from":"919664599641","id":"wamid.reaction999","timestamp":"2147483647","type":"reaction","reaction":{"message_id":"wamid.nonexistent","emoji":"\ud83d\udc4d"}}]},"field":"messages"}]}]}';
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(mockResponse));
        WhatsAppWebhook.processWhatsAppPayload(reactionPayload);
        Test.stopTest();
        
        // Should not create new chat for reaction to non-existent message
        List<Chat__c> chats = [SELECT Id FROM Chat__c WHERE WhatsAppMessageId__c = 'wamid.reaction999'];
        System.assertEquals(0, chats.size());
    }

    @isTest
    static void testInteractiveWithoutShowingRecord() {
        Contact testContact = [SELECT Id, Phone FROM Contact WHERE Phone = '+919428234735' LIMIT 1];
        
        Flow__c testFlow = new Flow__c(
            Flow_Id__c = 'no_showing_flow',
            Flow_JSON__c = '{"screens": [{"layout": {"children": []}}]}'
        );
        insert testFlow;
        
        WhatsappTemplate__c template = new WhatsappTemplate__c(
            Template_Name__c = 'no_showing_template',
            Status__c = 'Active-Quality Pending',
            WBButton_Body__c = '[{"type": "FLOW", "flow_id": "no_showing_flow"}]',
            MVEX__Template_Id__c = 'no_showing_template_003'
        );
        insert template;
        
        Chat__c contextChat = new Chat__c(
            WhatsAppMessageId__c = 'wamid.context_no_showing',
            Phone__c = testContact.Phone,
            WhatsappTemplate__c = template.Id
        );
        insert contextChat;

        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setStatusCode(200);
        mockResponse.setBodyAsBlob(Blob.valueOf('mock-data'));

        String interactivePayload = '{"object":"whatsapp_business_account","entry":[{"id":"319254377948692","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"919558019600","phone_number_id":"397858113402150"},"contacts":[{"profile":{"name":"Test User"},"wa_id":"919428234735"}],"messages":[{"from":"919428234735","id":"wamid.no_showing789","timestamp":"2147483647","type":"interactive","context":{"from":"919558019600","id":"wamid.context_no_showing"},"interactive":{"type":"nfm_reply","nfm_reply":{"response_json":"{\\"field\\":\\"value\\"}","body":"Response"}}}]},"field":"messages"}]}]}';
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(mockResponse));
        WhatsAppWebhook.processWhatsAppPayload(interactivePayload);
        Test.stopTest();
        
        // Should create chat without crashing when no Showing__c exists
        List<Chat__c> chats = [SELECT Id FROM Chat__c WHERE WhatsAppMessageId__c = 'wamid.no_showing789'];
        System.assertEquals(1, chats.size());
    }
}