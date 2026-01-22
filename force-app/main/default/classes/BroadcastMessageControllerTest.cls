/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 04-05-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
@isTest
private class BroadcastMessageControllerTest {

    private static Id broadcastGroupId;
    private static Id broadcastMemberId;

    @testSetup
    static void setupTestData() {

        // Create contact record
        Contact contact = new Contact(
            FirstName = 'Test',
            LastName = 'User',
            Phone = '1234567890'
        );
        insert contact;

        // Create a Broadcast Group
        Broadcast_Group__c broadcastGroup = new Broadcast_Group__c(
            Name = 'Test Group',
            Description__c = 'Test Description',
            Object_Name__c = 'Contact',
            List_View__c = 'Test List View',
            Phone_Field__c = 'Phone'
        );
        insert broadcastGroup;
        broadcastGroupId = broadcastGroup.Id;

        // Create a Broadcast Group Member
        Broadcast_Group_Member__c member = new Broadcast_Group_Member__c(
            Broadcast_Group_ID__c = broadcastGroupId,
            Phone_Number__c = '1234567890',
            Status__c = 'Sent'
        );
        insert member;
        broadcastMemberId = member.Id;

        // Create a Template record
        WhatsappTemplate__c template = new WhatsappTemplate__c(
            Template_Name__c = 'Test_Template',
            Status__c = 'Active-Quality Pending',
            Language__c = 'en',
            WBTemplate_Body__c = 'Hello, {{1}}!',
            Header_Type__c = 'text',
            WBHeader_Body__c = 'Header Text',
            Template_Id__c	= 'testId',
            WBButton_Body__c = '[{"type":"COPY_CODE","example":"AADDFCGOP"}]'
        );


        WhatsappTemplate__c template2 = new WhatsappTemplate__c(
            Template_Name__c = 'Test_Template2',
            Status__c = 'Active-Quality Pending',
            Language__c = 'en',
            WBTemplate_Body__c = 'Hello, {{1}}!',
            Header_Type__c = 'text',
            WBHeader_Body__c = 'Header Text',
            Template_Id__c	= 'testId2',
            WBButton_Body__c	= '[{"type":"OTP","text":"Verify Code","otp_type":"COPY_CODE"}]'
        );

        insert new List<WhatsappTemplate__c>{template, template2};

        Template_Variable__c templateVariable = new Template_Variable__c(
            Name = 'Test Variable',
            Field_Name__c = 'LastName',
            Object_Name__c = 'Contact',
            Alternate_Text__c = 'Alternate Text',
            WhatsappTemplate__c = template.Id,
            Type__c = 'Header'
        );


        Template_Variable__c templateVariable2 = new Template_Variable__c(
            Name = 'Test Variable',
            Field_Name__c = 'LastName',
            Object_Name__c = 'Contact',
            Alternate_Text__c = 'Alternate Text',
            WhatsappTemplate__c = template2.Id,
            Type__c = 'Body'
        );

        insert new List<Template_Variable__c>{templateVariable, templateVariable2};

        // Create a Broadcast record with no group IDs
        Broadcast__c broadcast = new Broadcast__c(
            WhatsappTemplate__c = template.Id,
            Status__c = 'Pending'
        );
        insert broadcast;
        
    }

        
    // Mocking the HTTP response for testing
    static HttpResponse createMockResponse(String statusCode, String body) {
        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setStatusCode(Integer.valueOf(statusCode));
        mockResponse.setBody(body);
        return mockResponse;
    }

    @isTest
    static void testGetObjectConfigs() {
        Test.startTest();
        Map<String, Object> result = BroadcastMessageController.getObjectConfigs();
        Test.stopTest();

        // System.assertNotEquals(null, result, 'Result should not be null');
        // System.assert(result.containsKey('objectOptions'), 'Response should have objectOptions');
        // System.assert(result.containsKey('configMap'), 'Response should have configMap');
    }

    @isTest
    static void testGetListViewsForObject() {
        Test.startTest();
        List<ListView> listViews = BroadcastMessageController.getListViewsForObject('Account');
        Test.stopTest();

        System.assertNotEquals(null, listViews, 'List views should not be null');
    }

    @isTest
    static void testGetBroadcastGroups() {
        Test.startTest();
        List<Broadcast_Group__c> groups = BroadcastMessageController.getBroadcastGroups();
        Test.stopTest();

        System.assert(groups.size() > 0, 'There should be at least one broadcast group');
    }

    @isTest
    static void testDeleteBroadcastGroup() {
        
        Broadcast_Group__c tempGroup = [SELECT Id, Name FROM Broadcast_Group__c LIMIT 1];

        Test.startTest();
        BroadcastMessageController.deleteBroadcastGroup(tempGroup.Id);
        Test.stopTest();

        // count query
        Integer count = [SELECT COUNT() FROM Broadcast_Group__c WHERE Id = :tempGroup.Id];
        System.assertEquals(0, count, 'Broadcast group should be deleted');

    }

    @isTest
    static void testGetBroadcastRecs() {
        Test.startTest();
        List<Broadcast__c> broadcasts = BroadcastMessageController.getBroadcastRecs();
        Test.stopTest();

        System.assertNotEquals(null, broadcasts, 'Broadcast records should not be null');
    }

    @isTest
    static void testGetTemplatesByObject() {
        Test.startTest();
        Map<String, List<WhatsappTemplate__c>> templatesMap = BroadcastMessageController.getTemplatesByObject();
        Test.stopTest();

        System.assert(templatesMap.size() > 0, 'There should be at least one template mapped');
    }

    @isTest
    static void testProcessBroadcastMessageWithObject_Insert() {
        Map<String, Object> requestMap = new Map<String, Object>{
            'name' => 'New Broadcast Group',
            'description' => 'Test Description',
            'objectApiName' => 'Account',
            'phoneNumbers' => new List<String>{'9876543210'},
            'listViewName' => 'Test List View',
            'isUpdate' => false,
            'phoneField' => 'Phone'
        };
        
        String requestJson = JSON.serialize(requestMap);
    
        Test.startTest();
        BroadcastMessageController.processBroadcastMessageWithObject(requestJson);
        Test.stopTest();
    
        Broadcast_Group__c createdGroup = [SELECT Id, Name FROM Broadcast_Group__c WHERE Name = 'New Broadcast Group' LIMIT 1];
        System.assertNotEquals(null, createdGroup, 'Broadcast group should be created');
    }
    

    @isTest
    static void testProcessBroadcastMessageWithObject_Update() {
        // First create a broadcast group for update
        Broadcast_Group__c tempGroup = new Broadcast_Group__c(
            Name = 'Old Name',
            Description__c = 'Old Description',
            Object_Name__c = 'Account',
            List_View__c = 'Old List View',
            Phone_Field__c = 'Phone'
        );
        insert tempGroup;
    
        Map<String, Object> requestMap = new Map<String, Object>{
            'name' => 'Updated Group Name',
            'description' => 'Updated Description',
            'objectApiName' => 'Account',
            'phoneNumbers' => new List<String>{'1234567890', '9876543210'},
            'listViewName' => 'Updated List View',
            'isUpdate' => true,
            'broadcastGroupId' => tempGroup.Id,
            'phoneField' => 'Phone'
        };
    
        String requestJson = JSON.serialize(requestMap);
    
        Test.startTest();
        BroadcastMessageController.processBroadcastMessageWithObject(requestJson);
        Test.stopTest();
    
        Broadcast_Group__c updatedGroup = [SELECT Name, Description__c FROM Broadcast_Group__c WHERE Id = :tempGroup.Id];
        System.assertEquals('Updated Group Name', updatedGroup.Name, 'Broadcast group name should be updated');
    }
    
    @isTest
    static void testGetBroadcastGroupDetails() {

        Broadcast_Group__c tempGroup = [SELECT Id, Description__c, Object_Name__c FROM Broadcast_Group__c LIMIT 1];

        Test.startTest();
        Map<String, Object> groupDetails = BroadcastMessageController.getBroadcastGroupDetails(tempGroup.Id);
        Test.stopTest();

        System.assertNotEquals(null, groupDetails, 'Group details should not be null');
    }

    @isTest
    static void testCreateChatRecods_ImmediateExecution() {

        HttpResponse mockResponse = createMockResponse('200', '{"messages":[{"id":"wamid.HBgLMjM0NTY3ODkwVBIJDQAAAB"}]}');
        MockHttpResponseGenerator mock = new MockHttpResponseGenerator(mockResponse);
        Test.setMock(HttpCalloutMock.class, mock);

        WhatsappTemplate__c testTemplate = [SELECT Id, Name, Template_Id__c FROM WhatsappTemplate__c WHERE Template_Id__c = 'testId' LIMIT 1];
        Broadcast_Group__c tempGroup = [SELECT Id, Name FROM Broadcast_Group__c LIMIT 1];

        Test.startTest();
        String result = BroadcastMessageController.createChatRecods(testTemplate.Id, new List<String>{tempGroup.Id}, false, '');
        Test.stopTest();
        
        System.assertEquals('Success', result, 'Method should return Success');
        List<Broadcast__c> broadcasts = [SELECT Id FROM Broadcast__c];
        System.assert(broadcasts.size() > 0, 'Broadcast record should be created');
        
        List<Chat__c> chats = [SELECT Id FROM Chat__c];
        System.assert(chats.size() > 0, 'Chat records should be created');
    }

    @isTest
    static void testCreateChatRecods_ImmediateExecutionWitBody() {

        HttpResponse mockResponse = createMockResponse('200', '{"messages":[{"id":"wamid.HBgLMjM0NTY3ODkwVBIJDQAAAB"}]}');
        MockHttpResponseGenerator mock = new MockHttpResponseGenerator(mockResponse);
        Test.setMock(HttpCalloutMock.class, mock);

        WhatsappTemplate__c testTemplate = [SELECT Id, Name, Template_Id__c FROM WhatsappTemplate__c WHERE Template_Id__c = 'testId2' LIMIT 1];
        Broadcast_Group__c tempGroup = [SELECT Id, Name FROM Broadcast_Group__c LIMIT 1];

        Test.startTest();
        String result = BroadcastMessageController.createChatRecods(testTemplate.Id, new List<String>{tempGroup.Id}, false, '');
        Test.stopTest();
        
        System.assertEquals('Success', result, 'Method should return Success');
        List<Broadcast__c> broadcasts = [SELECT Id FROM Broadcast__c];
        System.assert(broadcasts.size() > 0, 'Broadcast record should be created');
        
        List<Chat__c> chats = [SELECT Id FROM Chat__c];
        System.assert(chats.size() > 0, 'Chat records should be created');
    }

    @isTest
    static void testCreateChatRecods_ScheduledExecution() {

        DateTime futureDateTime = DateTime.now().addDays(1);
        String futureTime = futureDateTime.format('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
        
        WhatsappTemplate__c testTemplate = [SELECT Id, Name FROM WhatsappTemplate__c LIMIT 1];
        Broadcast_Group__c tempGroup = [SELECT Id, Name FROM Broadcast_Group__c LIMIT 1];

        Test.startTest();
        String result = BroadcastMessageController.createChatRecods(testTemplate.Id, new List<String>{tempGroup.Id}, true, futureTime);
        Test.stopTest();

        System.assertEquals('Success', result, 'Method should return Success');
        List<Broadcast__c> broadcasts = [SELECT Id, Schedule_DateTime__c FROM Broadcast__c];
        System.assert(broadcasts.size() > 0, 'Broadcast record should be created');
    }

    @isTest
    static void testGetBroadcastGroupsByBroadcastId_NoGroups() {

        Broadcast__c broadcast = [SELECT Id, WhatsappTemplate__c, Status__c FROM Broadcast__c LIMIT 1];

        Test.startTest();
        List<Broadcast_Group__c> groups = BroadcastMessageController.getBroadcastGroupsByBroadcastId(broadcast.Id);
        Test.stopTest();

        System.assertNotEquals(null, groups, 'Returned list should not be null');
        System.assertEquals(0, groups.size(), 'There should be no broadcast groups returned');
    }

    @isTest
    static void testGetBroadcastMembersByGroupId() {
        Test.startTest();

        // Provide the groupId and objectName
        Broadcast_Group__c groups = [SELECT Id FROM Broadcast_Group__c LIMIT 1];
        String objectName = 'Contact'; // Make sure 'Lead' is configured correctly in getObjectConfigs()

        List<BroadcastMessageController.BroadcastMemberWrapper> result = BroadcastMessageController.getBroadcastMembersByGroupId(groups.Id, objectName, null);

        Test.stopTest();
    }

    @isTest
    static void testGetSessionId() {
        Test.startTest();
        String sessionId = BroadcastMessageController.getSessionId();
        Test.stopTest();

        System.assertEquals('testSessionId', sessionId, 'Should return test session Id when running tests');
    }

}