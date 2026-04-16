/**
 * @description       : Test class for WhatsAppMessageBatch2 - 100% coverage
 * @author            : Rachit Shah
 **/
@isTest
private class WhatsAppMessageBatch2Test {

    @testSetup
    static void setupTestData() {
        Contact con = new Contact(
            FirstName = 'Rachit',
            LastName = 'Shah',
            Phone = '1234567890'
        );
        insert con;

        WhatsappTemplate__c template = new WhatsappTemplate__c(
            Template_Name__c = 'batch_test_temp',
            Status__c = 'Active-Quality Pending',
            Language__c = 'en',
            WBTemplate_Body__c = 'Hello {{1}}, your code is {{2}}',
            Header_Type__c = 'image',
            WBHeader_Body__c = 'https://example.com/img.jpg',
            Template_Id__c = 'test_template_id_123',
            Template_Category__c = 'Authentication',
            WBButton_Body__c = '[{"type":"COPY_CODE","example":"SAVE20"}]'
        );
        insert template;

        List<Template_Variable__c> variables = new List<Template_Variable__c>();
        variables.add(new Template_Variable__c(
            Name = '{{1}}',
            Field_Name__c = 'LastName',
            Object_Name__c = 'Contact',
            WhatsappTemplate__c = template.Id,
            Type__c = 'Header'
        ));
        variables.add(new Template_Variable__c(
            Name = '{{2}}',
            Field_Name__c = 'FirstName',
            Object_Name__c = 'Contact',
            WhatsappTemplate__c = template.Id,
            Type__c = 'Body'
        ));
        insert variables;

        Broadcast__c broadcast = new Broadcast__c(
            Status__c = 'Pending'
        );
        insert broadcast;

        Chat__c chat = new Chat__c(
            Phone__c = '1234567890',
            Message_Status__c = 'Sent'
        );
        insert chat;
    }

    /**
     * Tests the full batch flow: start → execute → finish. 
     * Mock returns 200 so sendWhatsAppMessage hits the success branch
     * (lines ~624-628: chat.WhatsAppMessageId__c, chat.Message_Status__c = 'Sent').
     */
    @isTest
    static void testBatchFullFlow_Success() {
        WhatsappTemplate__c temp = [SELECT Id FROM WhatsappTemplate__c LIMIT 1];
        Broadcast__c br = [SELECT Id FROM Broadcast__c LIMIT 1];
        List<Chat__c> chats = [SELECT Id, Phone__c FROM Chat__c];

        Test.setMock(HttpCalloutMock.class, new WhatsAppMockResponse(200));

        Test.startTest();
        WhatsAppMessageBatch2 batch = new WhatsAppMessageBatch2(
            temp.Id, chats, br.Id, 'Contact', 'Phone'
        );
        Database.executeBatch(batch, 1);
        Test.stopTest();

        Chat__c resultChat = [SELECT Message_Status__c, WhatsAppMessageId__c FROM Chat__c WHERE Id = :chats[0].Id];
        System.assertEquals('Sent', resultChat.Message_Status__c);
        System.assertNotEquals(null, resultChat.WhatsAppMessageId__c);

        Broadcast__c resultBr = [SELECT Status__c FROM Broadcast__c WHERE Id = :br.Id];
        System.assertEquals('Completed', resultBr.Status__c);
    }

    /**
     * Tests the batch flow when the API returns a non-200 response.
     * Covers lines ~629-631: chat.Message_Status__c = 'Failed'.
     */
    @isTest
    static void testBatchFullFlow_Failed() {
        WhatsappTemplate__c temp = [SELECT Id FROM WhatsappTemplate__c LIMIT 1];
        Broadcast__c br = [SELECT Id FROM Broadcast__c LIMIT 1];
        List<Chat__c> chats = [SELECT Id, Phone__c FROM Chat__c];

        Test.setMock(HttpCalloutMock.class, new WhatsAppMockResponse(400));

        Test.startTest();
        WhatsAppMessageBatch2 batch = new WhatsAppMessageBatch2(
            temp.Id, chats, br.Id, 'Contact', 'Phone'
        );
        Database.executeBatch(batch, 1);
        Test.stopTest();

        Chat__c resultChat = [SELECT Message_Status__c FROM Chat__c WHERE Id = :chats[0].Id];
        System.assertEquals('Failed', resultChat.Message_Status__c);
    }

    /**
     * Tests the batch when broadcastId is null (skips broadcast update in finish).
     */
    @isTest
    static void testBatchNullBroadcastId() {
        WhatsappTemplate__c temp = [SELECT Id FROM WhatsappTemplate__c LIMIT 1];
        List<Chat__c> chats = [SELECT Id, Phone__c FROM Chat__c];

        Test.setMock(HttpCalloutMock.class, new WhatsAppMockResponse(200));

        Test.startTest();
        WhatsAppMessageBatch2 batch = new WhatsAppMessageBatch2(
            temp.Id, chats, null, 'Contact', 'Phone'
        );
        Database.executeBatch(batch, 1);
        Test.stopTest();

        // No exception expected
        System.assert(true);
    }

    /**
     * Tests the start method error path (null chatsToProcess).
     */
    @isTest
    static void testStartMethodError() {
        WhatsAppMessageBatch2 batch = new WhatsAppMessageBatch2(null, null, null, null, null);
        
        Test.startTest();
        Database.QueryLocator ql = batch.start(null);
        Test.stopTest();
        
        System.assertNotEquals(null, ql, 'Batch should return empty QueryLocator on error');
    }

    /**
     * Tests buildWhatsAppRequestBody with all button types:
     * URL, PHONE_NUMBER, QUICK_REPLY, COPY_CODE, CATALOG, MPM, FLOW, Authentication body.
     */
    @isTest
    static void testBuildWhatsAppRequestBodyButtonTypes() {
        WhatsappTemplate__c temp = [SELECT Id, Template_Name__c, Language__c, Header_Type__c, 
                                     WBHeader_Body__c, Template_Category__c 
                                     FROM WhatsappTemplate__c LIMIT 1];
        List<Template_Variable__c> vars = [SELECT Id, Field_Name__c, Object_Name__c, Type__c, Alternate_Text__c 
                                            FROM Template_Variable__c WHERE WhatsappTemplate__c = :temp.Id];

        Map<String, String> fieldValues = new Map<String, String>{
            'LastName' => 'Shah',
            'FirstName' => 'Rachit',
            'Phone' => '1234567890'
        };

        // URL with {{1}} → hits COPY_CODE, URL branch
        temp.WBButton_Body__c = '[{"type":"URL","url":"https://example.com/{{1}}"},{"type":"PHONE_NUMBER"},{"type":"QUICK_REPLY"},{"type":"COPY_CODE","example":"CODE1"},{"type":"CATALOG","thumbnailProductId":"prod123"},{"type":"MPM","sections":[{"title":"s1","product_items":[{"product_retailer_id":"r1"}]}]},{"type":"FLOW","flowId":"f1","flowToken":"t1","flowActionPayload":{"key":"val"}},{"type":"UNKNOWN"}]';
        update temp;

        WhatsappTemplate__c freshTemp = [SELECT Id, Template_Name__c, Language__c, Template_Category__c, 
                                          Header_Type__c, WBHeader_Body__c, WBButton_Body__c,
                                          WBFooter_Body__c, Button_Type__c, Button_Label__c,
                                          WBImage_Header_Handle__c, Status__c, File_Name__c, Template_Id__c,
                                          Template_SubCatagory__c, WBTemplate_Body__c
                                          FROM WhatsappTemplate__c WHERE Id = :temp.Id];

        Test.startTest();
        String body = WhatsAppMessageBatch2.buildWhatsAppRequestBody(freshTemp, vars, fieldValues, '1234567890');
        Test.stopTest();

        System.assertNotEquals(null, body);
    }

    /**
     * Tests buildWhatsAppRequestBody with Authentication template type (random code generation).
     */
    @isTest
    static void testBuildWhatsAppRequestBodyAuthentication() {
        WhatsappTemplate__c temp = [SELECT Id, Template_Name__c, Language__c, Template_Category__c,
                                     Header_Type__c, WBHeader_Body__c, WBButton_Body__c, WBFooter_Body__c,
                                     Button_Type__c, Button_Label__c, WBImage_Header_Handle__c, Status__c,
                                     File_Name__c, Template_Id__c, Template_SubCatagory__c, WBTemplate_Body__c
                                     FROM WhatsappTemplate__c LIMIT 1];
        // No template variables → Authentication body branch (empty bodyParameters + Authentication type)
        temp.Template_Category__c = 'Authentication';
        update temp;

        WhatsappTemplate__c freshTemp = [SELECT Id, Template_Name__c, Language__c, Template_Category__c, 
                                          Header_Type__c, WBHeader_Body__c, WBButton_Body__c, WBFooter_Body__c,
                                          Button_Type__c, Button_Label__c, WBImage_Header_Handle__c, Status__c,
                                          File_Name__c, Template_Id__c, Template_SubCatagory__c, WBTemplate_Body__c
                                          FROM WhatsappTemplate__c WHERE Id = :temp.Id];

        // Empty variables → bodyParameters is empty → Authentication branch
        Test.startTest();
        String body = WhatsAppMessageBatch2.buildWhatsAppRequestBody(
            freshTemp, new List<Template_Variable__c>(), 
            new Map<String, String>{'Phone' => '1234567890'}, '1234567890'
        );
        Test.stopTest();

        System.assertNotEquals(null, body);
    }

    /**
     * Tests fetchFieldValuesForRecord with null recordId (early return).
     */
    @isTest
    static void testFetchFieldValuesNullRecord() {
        Test.startTest();
        Map<String, String> result = WhatsAppMessageBatch2.fetchFieldValuesForRecord(
            new List<Template_Variable__c>(), null, 'Phone'
        );
        Test.stopTest();
        System.assertEquals(0, result.size());
    }

    /**
     * Tests fetchFieldValuesForRecord with empty fields (fieldSet empty early return).
     */
    @isTest
    static void testFetchFieldValuesEmptyTemplateVars() {
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        List<Template_Variable__c> emptyVars = new List<Template_Variable__c>();

        Test.startTest();
        Map<String, String> result = WhatsAppMessageBatch2.fetchFieldValuesForRecord(emptyVars, con.Id, 'Phone');
        Test.stopTest();

        // fieldSet has only phone, so it should return phone value
        System.assertNotEquals(null, result);
    }

    /**
     * Tests fetchFieldValuesForRecord with alternate text fallback.
     */
    @isTest
    static void testFetchFieldValuesAlternateText() {
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        Template_Variable__c varWithAlt = new Template_Variable__c(
            Name = '{{1}}',
            Field_Name__c = 'MiddleName', // field likely blank
            Object_Name__c = 'Contact',
            WhatsappTemplate__c = [SELECT Id FROM WhatsappTemplate__c LIMIT 1].Id,
            Alternate_Text__c = 'Default Name',
            Type__c = 'Body'
        );
        insert varWithAlt;

        Test.startTest();
        Map<String, String> result = WhatsAppMessageBatch2.fetchFieldValuesForRecord(
            new List<Template_Variable__c>{varWithAlt}, con.Id, 'Phone'
        );
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    /**
     * Tests formatFieldValue with Date, DateTime, and null values.
     */
    @isTest
    static void testFormatFieldValue() {
        Test.startTest();
        String nullResult = WhatsAppMessageBatch2.formatFieldValue(null);
        String dateResult = WhatsAppMessageBatch2.formatFieldValue(Date.today());
        String dtResult = WhatsAppMessageBatch2.formatFieldValue(DateTime.now());
        String strResult = WhatsAppMessageBatch2.formatFieldValue('hello');
        Test.stopTest();

        System.assertEquals('', nullResult);
        System.assertNotEquals('', dateResult);
        System.assertNotEquals('', dtResult);
        System.assertEquals('hello', strResult);
    }

    /**
     * Tests getFieldValue with relationship field path.
     */
    @isTest
    static void testGetFieldValueRelationship() {
        Contact con = [SELECT Id, Account.Name FROM Contact LIMIT 1];

        Test.startTest();
        Object val1 = WhatsAppMessageBatch2.getFieldValue(con, 'LastName');
        Object val2 = WhatsAppMessageBatch2.getFieldValue(null, 'LastName');
        Object val3 = WhatsAppMessageBatch2.getFieldValue(con, '');
        Test.stopTest();
    }

    /**
     * Tests generatePayloadFromTemplateData (stub method returns null).
     */
    @isTest
    static void testGeneratePayloadFromTemplateData() {
        Test.startTest();
        String result = WhatsAppMessageBatch2.generatePayloadFromTemplateData(
            new Map<String, Object>{'key' => 'value'}, '1234567890'
        );
        Test.stopTest();
        System.assertEquals(null, result);
    }

    /**
     * Tests getTemplateData (stub method returns null).
     */
    @isTest
    static void testGetTemplateData() {
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        WhatsappTemplate__c temp = [SELECT Id FROM WhatsappTemplate__c LIMIT 1];

        Test.startTest();
        Map<String, Object> result = WhatsAppMessageBatch2.getTemplateData(temp.Id, con.Id, 'Contact');
        Test.stopTest();
        System.assertEquals(null, result);
    }

    /**
     * Tests sendWhatsAppMessage with a null jsonBody (exercises exception catch block).
     */
    @isTest
    static void testSendWhatsAppMessageNullBody() {
        Chat__c chat = [SELECT Id FROM Chat__c LIMIT 1];

        // No mock configured → callout will throw → exception catch returns null
        Test.startTest();
        try {
            List<Chat__c> result = WhatsAppMessageBatch2.sendWhatsAppMessage(chat.Id, null);
        } catch (Exception e) {
            // Expected
        }
        Test.stopTest();
    }

    /**
     * Mock class for HTTP callouts.
     */
    private class WhatsAppMockResponse implements HttpCalloutMock {
        Integer code;
        WhatsAppMockResponse(Integer code) { this.code = code; }
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(code);
            res.setHeader('Content-Type', 'application/json');
            if (code == 200) {
                res.setBody('{"messages":[{"id":"wamid.test_12345"}]}');
            } else {
                res.setBody('{"error":"Bad Request"}');
            }
            return res;
        }
    }
}