/**
 * @description       : Test class for WhatsAppMessageBatch2 covering Batchable and Payload logic
 * @author            : Rachit Shah
 **/
@isTest
private class WhatsAppMessageBatch2Test {

    @testSetup
    static void setupTestData() {
        // 1. Create Source Contact
        Contact con = new Contact(
            FirstName = 'Rachit',
            LastName = 'Shah',
            Phone = '1234567890'
        );
        insert con;

        // 2. Create Whatsapp Template (Providing the missing Required Field: Template_Id__c)
        WhatsappTemplate__c template = new WhatsappTemplate__c(
            Template_Name__c = 'batch_test_temp',
            Status__c = 'Active-Quality Pending',
            Language__c = 'en',
            WBTemplate_Body__c = 'Hello {{1}}, your code is {{2}}',
            Header_Type__c = 'text',
            WBHeader_Body__c = 'Update for {{1}}',
            Template_Id__c = 'test_template_id_123', // FIXED: Required field added
            Template_Category__c = 'Authentication',
            WBButton_Body__c = '[{"type":"COPY_CODE","example":"SAVE20"}]'
        );
        insert template;

        // 3. Create Template Variables
        // Note: Template_Variable__c (count) increments automatically via roll-up/formula
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

        // 4. Create Broadcast record
        Broadcast__c broadcast = new Broadcast__c(
            Status__c = 'Pending'
        );
        insert broadcast;

        // 5. Create Chat records for batch processing
        Chat__c chat = new Chat__c(
            Phone__c = '1234567890',
            Message_Status__c = 'Sent'
        );
        insert chat;
    }

    /**
     * @description Tests the start, execute, and finish methods of the batch
     */
    @isTest
    static void testBatchFullFlow() {
        WhatsappTemplate__c temp = [SELECT Id FROM WhatsappTemplate__c LIMIT 1];
        Broadcast__c br = [SELECT Id FROM Broadcast__c LIMIT 1];
        List<Chat__c> chats = [SELECT Id, Phone__c FROM Chat__c];

        // Setup Mock Callout
        Test.setMock(HttpCalloutMock.class, new WhatsAppMockResponse(200));

        Test.startTest();
        WhatsAppMessageBatch2 batch = new WhatsAppMessageBatch2(
            temp.Id, 
            chats, 
            br.Id, 
            'Contact', 
            'Phone'
        );
        Database.executeBatch(batch, 1);
        Test.stopTest();

        // Validate Chat Update
        Chat__c resultChat = [SELECT Message_Status__c, WhatsAppMessageId__c FROM Chat__c WHERE Id = :chats[0].Id];
        System.assertEquals('Sent', resultChat.Message_Status__c);
        System.assertNotEquals(null, resultChat.WhatsAppMessageId__c);

        // Validate Broadcast Status
        Broadcast__c resultBr = [SELECT Status__c FROM Broadcast__c WHERE Id = :br.Id];
        System.assertEquals('Completed', resultBr.Status__c);
    }

    /**
     * @description Specifically tests the payload generation logic for various button types
     */
    @isTest
    static void testPayloadGeneration() {
        WhatsappTemplate__c temp = [SELECT Id, Template_Name__c, Language__c, Header_Type__c, WBHeader_Body__c, Template_Category__c FROM WhatsappTemplate__c LIMIT 1];
        
        // Update template to test varied button types in the createJSONBody switch statement
        temp.WBButton_Body__c = '[{"type":"PHONE_NUMBER","phone_number":"91123"}, {"type":"OTP"}, {"type":"COPY_CODE","example":"CODE1"}]';
        update temp;

        Map<String, Object> templateData = new Map<String, Object>{
            'template' => temp,
            'headerParams' => new List<Object>{'HeaderValue'},
            'bodyParams' => new List<Object>{'BodyValue'},
            'templateType' => 'Authentication'
        };

        Test.startTest();
        String jsonPayload = WhatsAppMessageBatch2.generatePayloadFromTemplateData(templateData, '1234567890');
        Test.stopTest();

        System.assertNotEquals(null, jsonPayload);
        System.assert(jsonPayload.contains('copy_code'));
    }

    /**
     * @description Test error handling in the start method
     */
    @isTest
    static void testStartMethodError() {
        // Triggering the catch block by passing invalid data
        WhatsAppMessageBatch2 batch = new WhatsAppMessageBatch2(null, null, null, null, null);
        
        Test.startTest();
        Database.QueryLocator ql = batch.start(null);
        Test.stopTest();
        
        System.assertNotEquals(null, ql, 'Batch should return empty QueryLocator on error');
    }

    /**
     * @description Mock class for HTTP Callouts
     */
    private class WhatsAppMockResponse implements HttpCalloutMock {
        Integer code;
        WhatsAppMockResponse(Integer code) { this.code = code; }
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(code);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"messages":[{"id":"wamid.test_12345"}]}');
            return res;
        }
    }
}