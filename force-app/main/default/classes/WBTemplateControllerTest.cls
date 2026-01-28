/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 04-08-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
@isTest
public class WBTemplateControllerTest {

    @testSetup
    static void setup() {
        try{
            List<WhatsappTemplate__c> templates = new List<WhatsappTemplate__c>();
            for (Integer i = 1; i <= 5; i++) {
                templates.add(new WhatsappTemplate__c(
                    Template_Name__c = 'Template' + i,
                    Template_Category__c = 'Marketing',
                    Status__c = 'Active-Quality Pending',
                    Template_Id__c = 'testId'
                ));
            }
            insert templates;

            List<Template_Variable__c> variables = new List<Template_Variable__c>();
            for (WhatsappTemplate__c template : [SELECT Id FROM WhatsappTemplate__c]) {
                variables.add(new Template_Variable__c(
                    WhatsappTemplate__c = template.Id,
                    Name = '{{1}}',
                    Object_Name__c = 'Contact',
                    Field_Name__c = 'FirstName',
                    Type__c = 'Header'
                ));
                variables.add(new Template_Variable__c(
                    WhatsappTemplate__c = template.Id,
                    Name = '{{1}}',
                    Object_Name__c = 'Contact',
                    Field_Name__c = 'Name',
                    Type__c = 'Body'
                ));
                // variables.add(new Template_Variable__c(
                //     WhatsappTemplate__c = template.Id,
                //     Name = '{{2}}',
                //     Object_Name__c = 'Account',
                //     Field_Name__c = 'Name',
                //     Type__c = 'Body'
                // ));
            }
            
            insert variables;
    
            List<Contact> contacts = new List<Contact>();
            for (Integer i = 1; i <= 5; i++) {
                contacts.add(new Contact(FirstName = 'Test' + i, LastName = 'User' + i));
            }
            insert contacts;

            Contact contact = new Contact(
                FirstName = 'John',
                LastName = 'Doe',
                Email = 'john.doe@example.com'
            );
            insert contact;
            
        } catch (Exception e) {
            // ExceptionHandler.logException(new Map<String, Object>{ 'className' => 'WBTemplateControllerTest', 'methodName' => 'setup', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null });
        }
    }
    
    @isTest
    static void testFetchWhatsAppTemplates() {
        try{
            List<WhatsappTemplate__c> templates = WBTemplateController.getWhatsAppTemplates();
        	System.assertEquals(5, templates.size(), 'Templates count should be 5');
        } catch (Exception e) {
            // ExceptionHandler.logException(new Map<String, Object>{ 'className' => 'WBTemplateControllerTest', 'methodName' => 'testFetchWhatsAppTemplates', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null });
        }
    }
    
    @isTest
    static void testRestrictTemplate() {
        try{
            List<WhatsappTemplate__c> templatesToInsert = new List<WhatsappTemplate__c>{
                new WhatsappTemplate__c(
                    Template_Name__c = 'Template6',
                    Template_Category__c = 'Marketing',
                    Status__c = 'Active-Quality Pending',
                    Template_Id__c = 'testId'
                )
            };
    
            WBTemplateController.restrictTemplates(templatesToInsert);
        } catch (Exception e) {
            // ExceptionHandler.logException(new Map<String, Object>{ 'className' => 'WBTemplateControllerTest', 'methodName' => 'testRestrictTemplate', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null });
        }
    }

      @isTest
    static void testGetDynamicObjectData_Success() {
        
        List<WhatsappTemplate__c> templatesToInsert = new List<WhatsappTemplate__c>{
            new WhatsappTemplate__c(
                Template_Name__c = 'Template6',
                Template_Category__c = 'Marketing',
                Status__c = 'Active-Quality Pending',
                Template_Id__c = 'testId',
                Header_Type__c = 'Image'
                )
            };
            
            WhatsappTemplate__c template = [SELECT Id FROM WhatsappTemplate__c LIMIT 1];

        insert templatesToInsert;


        Test.startTest();
        WBTemplateController.TemplateDataWrapper result = WBTemplateController.getDynamicObjectData(template.Id);
        Test.stopTest();

        System.assertEquals(template.Id, result.template.Id, 'Template Id should match');
    }
    
    @isTest
    static void testGetRecordsBySObject() {
        Test.startTest();        
        List<sObject> records = WBTemplateController.getRecordsBySObject('Contact');
        Test.stopTest();
    }
    
    @isTest
    static void testFetchRecordBySObject() {
        try{
            Test.startTest();
            List<String> fields = WBTemplateController.getObjectFields('Contact');
            Test.stopTest();
            System.assert(fields.size() > 0, 'Records should be returned');        
            System.assert(fields.contains('Id'), 'Contact object should have an Id field');
            System.assert(fields.contains('FirstName'), 'Contact object should have FirstName field');
         } catch (Exception e) {
            // ExceptionHandler.logException(new Map<String, Object>{ 'className' => 'WBTemplateControllerTest', 'methodName' => 'testFetchRecordBySObject', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null });
        }
    }

    @isTest
    static void testFetchDynamicRecordData() {
        try{
             Contact contact = [SELECT Id FROM Contact LIMIT 1];
            List<String> fieldNames = new List<String>{'FirstName', 'LastName', 'Email'};
              Test.startTest();
            Map<String, Object> resultMap = WBTemplateController.fetchDynamicRecordData('Contact', fieldNames, contact.Id);
            Test.stopTest();
    
            System.assertNotEquals(resultMap.get('queriedData'), null, 'Queried data should not be null');        
            Contact resultContact = (Contact)resultMap.get('queriedData');
            System.assertEquals(resultContact.FirstName, 'Test1', 'FirstName should be John');
        } catch (Exception e) {
            // ExceptionHandler.logException(new Map<String, Object>{ 'className' => 'WBTemplateControllerTest', 'methodName' => 'testFetchDynamicRecordData', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null });
        }
    }
        
    @IsTest
    static void testGetTemplateDataWithContactId() {
        // Retrieve the test data
        WhatsappTemplate__c template = [SELECT Id FROM WhatsappTemplate__c WHERE Template_Variable__c>0 LIMIT 1];
        Contact contact = [SELECT Id FROM Contact LIMIT 1];

        // Call the method with a valid contactId
        Map<String, Object> result = WBTemplateController.getTemplateDataWithReplacement(template.Id, contact.Id);

        Map<String, Object> result2 = WBTemplateController.getTemplateDataWithReplacement(template.Id, null);
    }

    @isTest
    static void testGetPicklistValues() {
        try{
             Test.startTest();
            Map<String, List<String>> picklistValues = WBTemplateController.getCategoryAndStatusPicklistValues();
            Test.stopTest();
    
            System.assertNotEquals(picklistValues, null, 'Picklist values should not be null');
            System.assert(picklistValues.containsKey('categories'), 'Picklist should contain "categories" key');
        } catch (Exception e) {
            // ExceptionHandler.logException(new Map<String, Object>{ 'className' => 'WBTemplateControllerTest', 'methodName' => 'testGetPicklistValues', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null });
        }
    }

    @isTest
    static void testSendPreviewTemplate_Success() {
        Test.setMock(HttpCalloutMock.class, new TestHttpResponse(200));
        
        String jsonData = '{"templateName": "test_template", "languageCode": "en", "headerParameters": ["Header"], "bodyParameters": ["Body1", "Body2"], "buttonLabel": "Click Me", "buttonType": "url"}';
        
        Test.startTest();
        String result = WBTemplateController.sendPreviewTemplate(jsonData);
        Test.stopTest();
        
    }
    
    @isTest
    static void testSendPreviewTemplate_Failure() {
        Test.setMock(HttpCalloutMock.class, new TestHttpResponse(500));  
        
        String jsonData = '{"templateName": "test_template", "languageCode": "en", "headerParameters": ["Header"], "bodyParameters": ["Body1", "Body2"], "buttonLabel": "Click Me", "buttonType": "url"}';
        
        Test.startTest();
        String result = WBTemplateController.sendPreviewTemplate(jsonData);
        Test.stopTest();
    }


    @isTest
    static void testCreateWhatsappTemplate_Success() {
        String payload = '{ "name": "simple_template", "language": "en_US", "category": "UTILITY", "components": [ { "type": "BODY", "text": "Hello {{1}}, your order {{2}} is confirmed." } ] }';
        Map<String, Object> payloadTW = (Map<String, Object>) JSON.deserializeUntyped(payload);
            System.debug('payload :: '+payloadTW);
        CreateTemplateWrapper.TemplateWrapper mockTemplateWrapper = new CreateTemplateWrapper.TemplateWrapper();
        mockTemplateWrapper.templateName = 'Test Template';
        mockTemplateWrapper.tempLanguage = 'en';
        String serializedWrapper = JSON.serialize(mockTemplateWrapper);
        Test.setMock(HttpCalloutMock.class, new TestHttpResponse(200));
        Test.startTest();

        Map<String, Object> response = WBTemplateController.createWhatsappTemplate(serializedWrapper,payload,'simple_template');
        WBTemplateController.checkTemplateExistance('simple_template',serializedWrapper,payload);
        Test.stopTest();
    }

    @isTest
    static void testCreateWhatsappTemplate_Exception() {
        // Creating a mock TemplateWrapper
        CreateTemplateWrapper.TemplateWrapper mockTemplateWrapper = new CreateTemplateWrapper.TemplateWrapper();
        mockTemplateWrapper.templateName = 'Test Template';
        mockTemplateWrapper.tempLanguage = 'en';
        String serializedWrapper = JSON.serialize(mockTemplateWrapper);

        // Mock HTTP callout to return an error response
        
        Test.setMock(HttpCalloutMock.class, new TestHttpResponse(500));
        String payload = '{ "name": "simple_template", "language": "en_US", "category": "UTILITY", "components": [ { "type": "BODY", "text": "Hello {{1}}, your order {{2}} is confirmed." } ] }';

        Test.startTest();
        Map<String, Object> response = WBTemplateController.createWhatsappTemplate(serializedWrapper,payload, 'simple_template');
        Test.stopTest();

        // Assert that the error is caught and logged correctly
        // System.assertEquals('error', response.get('status'));
        // System.assertNotEquals(null, response.get('message'));
    }


     @isTest
    static void testCreateTemplateFailed() {
        CreateTemplateWrapper.TemplateWrapper mockTemplateWrapper = new CreateTemplateWrapper.TemplateWrapper();
        mockTemplateWrapper.templateName = 'Invalid Template';
        mockTemplateWrapper.tempLanguage = 'en';

        String serializedWrapper = JSON.serialize(mockTemplateWrapper);
        String payload = '{ "name": "simple_template", "language": "en_US", "category": "UTILITY", "components": [ { "type": "BODY", "text": "Hello {{1}}, your order {{2}} is confirmed." } ] }';

        Test.setMock(HttpCalloutMock.class, new TestHttpResponse(400));
        Test.startTest();
        Map<String, Object> response = WBTemplateController.createWhatsappTemplate(serializedWrapper,payload, 'simple_template');
        Test.stopTest();
    }


     @isTest
    static void testStartUploadSession_Success() {
        Test.setMock(HttpCalloutMock.class, new TestHttpResponse(200));

        Test.startTest();
        String sessionId = WBTemplateController.startUploadSession('testFile.txt', 1024, 'text/plain');
        Test.stopTest();

    }

    @isTest
    static void testStartUploadSession_Failure() {
        Test.setMock(HttpCalloutMock.class, new TestHttpResponse(400));

        Test.startTest();
        String sessionId = WBTemplateController.startUploadSession('testFile.txt', 1024, 'text/plain');
        Test.stopTest();

        System.assertEquals(sessionId, null, 'The session ID should be null in case of failure');
    }

       @isTest
    static void testUploadFileChunk_Success() {
        String mockResponseBody = '{"h": "header123"}';
        Test.setMock(HttpCalloutMock.class, new TestHttpResponse(200));
      
        WBTemplateController.FileChunkWrapper fileWrapper = new WBTemplateController.FileChunkWrapper();
        fileWrapper.uploadSessionId = 'upload123';
        fileWrapper.fileName = 'testFile.txt';
        fileWrapper.fileContent = EncodingUtil.base64Encode(Blob.valueOf('test content'));
        fileWrapper.chunkStart = 0;
        fileWrapper.chunkSize = 10;

        String serializedWrapper = JSON.serialize(fileWrapper);

        Test.startTest();
        String result = WBTemplateController.uploadFileChunk(serializedWrapper,false);
        Test.stopTest();
    }
    
     @isTest
    static void testUploadFileChunk_Failure() {
        String mockResponseBody = '{"error": "Invalid file chunk"}';
        Test.setMock(HttpCalloutMock.class, new TestHttpResponse(400));
      
        WBTemplateController.FileChunkWrapper fileWrapper = new WBTemplateController.FileChunkWrapper();
        fileWrapper.uploadSessionId = 'upload123';
        fileWrapper.fileName = 'testFile.txt';
        fileWrapper.fileContent = EncodingUtil.base64Encode(Blob.valueOf('test content'));
        fileWrapper.chunkStart = 0;
        fileWrapper.chunkSize = 10;

        String serializedWrapper = JSON.serialize(fileWrapper);

        Test.startTest();
        String result = WBTemplateController.uploadFileChunk(serializedWrapper,false);
        Test.stopTest();

        System.assertEquals(result, '', 'The result should be empty in case of failure');
    }
    
    @isTest
    static void testDeleteTemplate_Success() {
        WhatsappTemplate__c template = new WhatsappTemplate__c(Template_Name__c = 'Test Template',Template_Category__c = 'Marketing', Template_Id__c = 'testId');
        insert template;

     	Test.setMock(HttpCalloutMock.class, new TestHttpResponse(200));
        Test.startTest();
        String result = WBTemplateController.deleteTemplete(template.Id);
        Test.stopTest();
	}

    @isTest
    static void testDeleteTemplate_Failure() {
        Test.startTest();
        String result = WBTemplateController.deleteTemplete('test');
        Test.stopTest();
	}

    public class TestHttpResponse implements HttpCalloutMock {

        Integer statusCode;

        TestHttpResponse(Integer statusCode){
            this.statusCode = statusCode;
        }

        public HTTPResponse respond(HTTPRequest req) {

            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(statusCode);
            res.setBody('{\"success\": false}');
            return res;
        }
    }

     @isTest
    public static void testEditWhatsappTemplate_Success() {
        Test.setMock(HttpCalloutMock.class, new TestHttpResponse(200));

        String templateId = [SELECT Id FROM WhatsappTemplate__c LIMIT 1][0].Id;
        CreateTemplateWrapper.TemplateWrapper wrapper = new CreateTemplateWrapper.TemplateWrapper();
        wrapper.templateName = 'Test Template';
        wrapper.templateCategory = 'Marketing';
        wrapper.templateType = 'Text';
        wrapper.tempLanguage = 'en';
        wrapper.templateBody = 'Hello {{1}}, this is a test message.';
        wrapper.templateBodyText = new List<String>{'Example Body Text'};

        String serializedWrapper = JSON.serialize(wrapper);
        String payload = '{ "name": "simple_template", "language": "en_US", "category": "UTILITY", "components": [ { "type": "BODY", "text": "Hello {{1}}, your order {{2}} is confirmed." } ] }';
        Test.startTest();
        Map<String, Object> response = WBTemplateController.editWhatsappTemplate(serializedWrapper,payload, templateId);
        Test.stopTest();

        // System.assertEquals(true, response.get('success'));
    }

    @isTest
    public static void testEditWhatsappTemplate_Failure() {
        Test.setMock(HttpCalloutMock.class, new TestHttpResponse(400));

        String templateId = 'invalid_id';
        CreateTemplateWrapper.TemplateWrapper wrapper = new CreateTemplateWrapper.TemplateWrapper();
        wrapper.templateName = 'Invalid Template';
        wrapper.templateCategory = 'Marketing';
        wrapper.templateType = 'Text';
        wrapper.tempLanguage = 'en';
        wrapper.templateBody = 'Invalid test message.';
        wrapper.templateBodyText = new List<String>{'Invalid Body Text'};
        String payload = '{ "name": "simple_template", "language": "en_US", "category": "UTILITY", "components": [ { "type": "BODY", "text": "Hello {{1}}, your order {{2}} is confirmed." } ] }';
        String serializedWrapper = JSON.serialize(wrapper);

        Test.startTest();
        Map<String, Object> response = WBTemplateController.editWhatsappTemplate(serializedWrapper,payload ,templateId);
        Test.stopTest();
        // System.assertEquals(false, response.get('success'));
        // System.assertNotEquals(null, response.get('errorMessage'));
    }

    @isTest
    public static void testEditWhatsappTemplate_Exception() {
        // This test is for simulating an exception.

        String templateId = '12345';
        String invalidSerializedWrapper = '{"invalid":"data"}';
        String payload = '{ "name": "simple_template", "language": "en_US", "category": "UTILITY", "components": [ { "type": "BODY", "text": "Hello {{1}}, your order {{2}} is confirmed." } ] }';
        Test.startTest();
        Map<String, Object> response = WBTemplateController.editWhatsappTemplate(invalidSerializedWrapper, payload,templateId);
        Test.stopTest();
        System.assertEquals('error', response.get('status'));
        System.assertNotEquals(null, response.get('message'));

    }

    @isTest
    static void testGetCompanyName() {
        // Call the method
        Test.startTest();
        String companyName = WBTemplateController.getCompanyName();
        WBTemplateController.getObjectsWithPhoneField();
        Test.stopTest();
        
        // Assert that it returns a non-null value
        System.assertNotEquals(null, companyName, 'Company name should not be null');
    }
    
    
}