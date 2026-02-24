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

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.containsKey('objectOptions'), 'Response should have objectOptions');
        System.assert(result.containsKey('configMap'), 'Response should have configMap');
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

    @isTest
    static void testGetBroadcastRecsWithReplies() {
        // Create broadcast with template
        WhatsappTemplate__c template = [SELECT Id FROM WhatsappTemplate__c LIMIT 1];
        Broadcast_Group__c testGroup = [SELECT Id FROM Broadcast_Group__c LIMIT 1];
        
        Broadcast__c broadcast = new Broadcast__c(
            WhatsappTemplate__c = template.Id,
            Status__c = 'Completed',
            Broadcast_Group_IDs__c = testGroup.Id
        );
        insert broadcast;
        
        // Create Chat records for testing
        List<Chat__c> chats = new List<Chat__c>();
        chats.add(new Chat__c(
            Phone__c = '1234567890',
            Type_of_Message__c = 'Outbound Messages',
            Message_Status__c = 'Sent'
        ));
        chats.add(new Chat__c(
            Phone__c = '1234567890',
            Type_of_Message__c = 'Inbound Messages',
            Message_Status__c = 'Seen'
        ));
        chats.add(new Chat__c(
            Phone__c = '9876543210',
            Type_of_Message__c = 'Outbound Messages',
            Message_Status__c = 'Delivered'
        ));
        insert chats;
        
        Test.startTest();
        List<Map<String, Object>> result = BroadcastMessageController.getBroadcastRecsWithReplies();
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.size() > 0, 'Should return broadcast records');
    }
    
    @isTest
    static void testGetCronExpression() {
        DateTime testDateTime = DateTime.newInstance(2025, 12, 31, 14, 30, 0);
        
        Test.startTest();
        String cronExpression = BroadcastMessageController.getCronExpression(testDateTime);
        Test.stopTest();
        
        System.assertNotEquals(null, cronExpression, 'Cron expression should not be null');
        System.assert(cronExpression.contains('30'), 'Should contain minute');
        System.assert(cronExpression.contains('14'), 'Should contain hour');
        System.assert(cronExpression.contains('31'), 'Should contain day');
        System.assert(cronExpression.contains('12'), 'Should contain month');
        System.assert(cronExpression.contains('2025'), 'Should contain year');
    }
    
    @isTest
    static void testGetBroadcastGroupsByBroadcastId_WithGroups() {
        WhatsappTemplate__c template = [SELECT Id FROM WhatsappTemplate__c LIMIT 1];
        Broadcast_Group__c testGroup = [SELECT Id FROM Broadcast_Group__c LIMIT 1];
        
        Broadcast__c broadcast = new Broadcast__c(
            WhatsappTemplate__c = template.Id,
            Status__c = 'Pending',
            Broadcast_Group_IDs__c = testGroup.Id
        );
        insert broadcast;
        
        Test.startTest();
        List<Broadcast_Group__c> groups = BroadcastMessageController.getBroadcastGroupsByBroadcastId(broadcast.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, groups, 'Groups should not be null');
        System.assertEquals(1, groups.size(), 'Should return one group');
    }
    
    @isTest
    static void testGetBroadcastGroupsWithStats() {
        WhatsappTemplate__c template = [SELECT Id FROM WhatsappTemplate__c LIMIT 1];
        Broadcast_Group__c testGroup = [SELECT Id FROM Broadcast_Group__c LIMIT 1];
        
        Broadcast__c broadcast = new Broadcast__c(
            WhatsappTemplate__c = template.Id,
            Status__c = 'Completed',
            Broadcast_Group_IDs__c = testGroup.Id
        );
        insert broadcast;
        
        Broadcast_Group_Member__c member = [SELECT Id, Phone_Number__c FROM Broadcast_Group_Member__c LIMIT 1];
        
        // Create Chat records
        List<Chat__c> chats = new List<Chat__c>();
        chats.add(new Chat__c(
            Phone__c = member.Phone_Number__c,
            Type_of_Message__c = 'Outbound Messages',
            Message_Status__c = 'Delivered'
        ));
        chats.add(new Chat__c(
            Phone__c = member.Phone_Number__c,
            Type_of_Message__c = 'Inbound Messages',
            Message_Status__c = 'Seen'
        ));
        insert chats;
        
        Test.startTest();
        List<Map<String, Object>> result = BroadcastMessageController.getBroadcastGroupsWithStats(broadcast.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
    }
    
    @isTest
    static void testProcessBroadcastMessageWithObject_WithRecipients() {
        Contact contact = [SELECT Id, Phone FROM Contact LIMIT 1];
        
        List<Map<String, Object>> recipients = new List<Map<String, Object>>();
        recipients.add(new Map<String, Object>{
            'Id' => contact.Id,
            'phone' => contact.Phone,
            'email' => 'test@example.com'
        });
        
        Map<String, Object> requestMap = new Map<String, Object>{
            'name' => 'Test Broadcast With Recipients',
            'description' => 'Test Description',
            'objectApiName' => 'Contact',
            'recipients' => recipients,
            'listViewName' => 'Test List View',
            'isUpdate' => false,
            'phoneField' => 'Phone',
            'emailField' => 'Email',
            'communicationType' => 'Phone'
        };
        
        String requestJson = JSON.serialize(requestMap);
        
        Test.startTest();
        BroadcastMessageController.processBroadcastMessageWithObject(requestJson);
        Test.stopTest();
    }
    
    @isTest
    static void testProcessBroadcastMessageWithObject_UpdateWithRecipients() {
        Broadcast_Group__c existingGroup = [SELECT Id FROM Broadcast_Group__c LIMIT 1];
        Contact contact = [SELECT Id, Phone FROM Contact LIMIT 1];
        
        List<Map<String, Object>> recipients = new List<Map<String, Object>>();
        recipients.add(new Map<String, Object>{
            'Id' => contact.Id,
            'phone' => '9999999999',
            'email' => 'updated@example.com'
        });
        
        Map<String, Object> requestMap = new Map<String, Object>{
            'name' => 'Updated Group',
            'description' => 'Updated Description',
            'objectApiName' => 'Contact',
            'recipients' => recipients,
            'listViewName' => 'Updated List View',
            'isUpdate' => true,
            'broadcastGroupId' => existingGroup.Id,
            'phoneField' => 'Phone',
            'emailField' => 'Email',
            'communicationType' => 'Both'
        };
        
        String requestJson = JSON.serialize(requestMap);
        
        Test.startTest();
        BroadcastMessageController.processBroadcastMessageWithObject(requestJson);
        Test.stopTest();
        
        Broadcast_Group__c updatedGroup = [SELECT Name, Communication_Type__c FROM Broadcast_Group__c WHERE Id = :existingGroup.Id];
        System.assertEquals('Updated Group', updatedGroup.Name, 'Group should be updated');
        System.assertEquals('Both', updatedGroup.Communication_Type__c, 'Communication type should be updated');
    }
    
    @isTest
    static void testGetBroadcastMembersByGroupId_WithBroadcast() {
        WhatsappTemplate__c template = [SELECT Id FROM WhatsappTemplate__c LIMIT 1];
        Broadcast_Group__c testGroup = [SELECT Id, Communication_Type__c FROM Broadcast_Group__c LIMIT 1];
        
        Broadcast__c broadcast = new Broadcast__c(
            WhatsappTemplate__c = template.Id,
            Status__c = 'Completed'
        );
        insert broadcast;
        
        Broadcast_Group_Member__c member = [SELECT Id, Phone_Number__c FROM Broadcast_Group_Member__c LIMIT 1];
        
        // Create Chat records for status and replies
        List<Chat__c> chats = new List<Chat__c>();
        chats.add(new Chat__c(
            Phone__c = member.Phone_Number__c,
            Type_of_Message__c = 'Outbound Messages',
            Message_Status__c = 'Seen'
        ));
        chats.add(new Chat__c(
            Phone__c = member.Phone_Number__c,
            Type_of_Message__c = 'Inbound Messages',
            Message_Status__c = 'Delivered'
        ));
        insert chats;
        
        Test.startTest();
        List<BroadcastMessageController.BroadcastMemberWrapper> result = 
            BroadcastMessageController.getBroadcastMembersByGroupId(testGroup.Id, 'Contact', broadcast.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
    }
    
    @isTest
    static void testGetBroadcastMembersByGroupId_EmailCommunication() {
        // Create a group with Email communication type
        Broadcast_Group__c emailGroup = new Broadcast_Group__c(
            Name = 'Email Test Group',
            Description__c = 'Test Email Group',
            Object_Name__c = 'Contact',
            Communication_Type__c = 'Email',
            Email_Field__c = 'Email'
        );
        insert emailGroup;
        
        Contact contact = [SELECT Id, Email FROM Contact LIMIT 1];
        contact.Email = 'test@example.com';
        update contact;
        
        Broadcast_Group_Member__c emailMember = new Broadcast_Group_Member__c(
            Broadcast_Group_ID__c = emailGroup.Id,
            Email__c = 'test@example.com',
            Member_Record_Id__c = contact.Id
        );
        insert emailMember;
        
        WhatsappTemplate__c template = [SELECT Id FROM WhatsappTemplate__c LIMIT 1];
        Broadcast__c broadcast = new Broadcast__c(
            WhatsappTemplate__c = template.Id,
            Status__c = 'Completed'
        );
        insert broadcast;
        
        Test.startTest();
        List<BroadcastMessageController.BroadcastMemberWrapper> result = 
            BroadcastMessageController.getBroadcastMembersByGroupId(emailGroup.Id, 'Contact', broadcast.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
    }

}