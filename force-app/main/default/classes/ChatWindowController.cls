/**
* Class Name: ChatWindowController
* Test Class: ChatWindowControllerTest
* @description: Used for handling various actions for the chat
* Created Date: 22 Nov, 2024
* Created By: Kevin Suvagiya
*--------------------------------------------------------------------------------
* Last Modified By: Kevin Suvagiya
* Last Modified Date: 03 Jan 2025
* Last Modification Description: Updated the field api name for template header, body and footer
*--------------------------------------------------------------------------------
* Modification History:
* Date Modified - Developer Name - Description
* 25 Nov, 2024  - Kevin Suvagiya - Added a method to link the chat record with the exception
* 05 Dec, 2024  - Kevin Suvagiya - Updated the createChat to create the contentDistribution record for the files
* 06 Dec, 2024  - Kevin Suvagiya - Added implementation for the theme preference logic
* 09 Dec, 2024  - Kevin Suvagiya - Added method to send the message to the user with http request
* 11 Dec, 2024  - Kevin Suvagiya - Added a method to fetch the full template data with replaced variables
* 19 Mar, 2025  - Harsh Gandhi - Updated dynamic Name & Phone field from custom metadata and Logic for only object related templates are visible for sending Updated methods getCombinedData & getTemplateData
* 26 Mar, 2025  - Harsh Gandhi - Updated Conditions to handle multiple media types in createChat method
* 22 Jan, 2026  - Rachit Shah - Added method to get merge field value for related object in template preview
**/
public with sharing class ChatWindowController {

    /* Variables to be used generally for the class 
    *********************************************************
    @variable wbConfig - {List<WBConnect_Configuration__mdt>} - Custom Metadata containing auth values for whatsapp
    @variable userPreferences - {List<User_Theme_Preference__c>} - Custom Setting for showing user theme as their preference
    *********************************************************
    */
    /* ---------------- Start ---------------- */
    public static List<MVEX__WBConnect_Configuration__mdt> wbConfig = MVEX__WBConnect_Configuration__mdt.getAll().values(); 
    public static List<MVEX__User_Theme_Preference__c> userPreferences = [SELECT MVEX__Theme__c FROM MVEX__User_Theme_Preference__c WHERE SetupOwnerId =: UserInfo.getUserId() WITH USER_MODE LIMIT 1];
    /* ----------------  End  ---------------- */
    
    @AuraEnabled
    public static List<String> getObjectPicklistOptions() {
        try {
            
            List<String> options = new List<String>();
            
            // Query metadata
            List<MVEX__Object_Config__mdt> objectConfigList = [ SELECT MVEX__ChatWindowConfigInfo__c FROM MVEX__Object_Config__mdt LIMIT 1];
            
            if (!objectConfigList.isEmpty()) {
                // Parse JSON
                Map<String, Object> chatConfigData = (Map<String, Object>) JSON.deserializeUntyped(objectConfigList[0].MVEX__ChatWindowConfigInfo__c);
                
                // Add keys to options list
                for (String key : chatConfigData.keySet()) {
                    options.add(key);
                }
            }
            
            return options;
        } catch (Exception e) {
            //ExceptionHandler.logException(new Map<String, Object>{'className' => 'ChatWindowController', 'methodName' => 'getObjectPicklistOptions', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null});
            return null;
        }
    }

    @AuraEnabled
    public static Map<String, Map<String, Object>> getChatsForSelectedObject(String objectApiName) {
        try {
            // Fetch metadata record from Object_Config__mdt
            List<MVEX__Object_Config__mdt> objectConfigList = [SELECT Id, MVEX__ObjectConfigInfo__c, MVEX__ChatWindowConfigInfo__c FROM MVEX__Object_Config__mdt LIMIT 1];
            String phoneField = '';
            String nameField = '';
            if(objectConfigList.size() <= 0) {
                System.debug('Object Config not found!');
            } else {
                // Deserialize the JSON string from ChatWindowConfigInfo__c
                Map<String, Object> chatConfigData = (Map<String, Object>) JSON.deserializeUntyped(objectConfigList[0].MVEX__ChatWindowConfigInfo__c);
                Map<String, Object> chatConfig = (Map<String, Object>) chatConfigData.get(objectApiName);
                phoneField = (String) chatConfig.get('phoneField');
                nameField = (String) chatConfig.get('nameField');
            }

            List<sObject> recordData;
            if(nameField != '' && phoneField != '') {
                String query ='';
                if(objectApiName == 'Lead'){
                    query = 'SELECT Id, ' +  nameField + ', ' +  phoneField + ' FROM ' + objectApiName + ' WHERE '+ phoneField +' != null AND Status != \'Closed - Converted\' LIMIT 50000';
                }
                else{
                    query = 'SELECT Id, ' +  nameField + ', ' +  phoneField + ' FROM ' + objectApiName + ' WHERE '+ phoneField +' != null LIMIT 50000';
                }
                recordData = Database.query(query);
            }
    
            // Build phone set from contacts
            Set<String> phoneSet = new Set<String>();
            for (sObject rec : recordData) {
                phoneSet.add((String) rec.get(phoneField));
            }
    
            // Get last chat time per phone from Chat__c
            Map<String, DateTime> phoneToLastChat = new Map<String, DateTime>();
            List<AggregateResult> chatAgg = [SELECT Phone__c, MAX(CreatedDate) maxDate FROM Chat__c WHERE Phone__c IN :phoneSet GROUP BY Phone__c];
    
            for (AggregateResult ar : chatAgg) {
                phoneToLastChat.put((String)ar.get('MVEX__Phone__c'), (DateTime)ar.get('maxDate'));
            }
    
            // Get count of unread outbound messages per phone
            Map<String, Integer> phoneToUnreadOutboundCount = new Map<String, Integer>();
            List<AggregateResult> unreadOutboundAgg = [ SELECT Phone__c, COUNT(Id) countId FROM Chat__c WHERE Phone__c IN :phoneSet AND Message_Status__c != 'Seen' AND Type_of_Message__c = 'Inbound Messages' GROUP BY Phone__c];
    
            for (AggregateResult ar : unreadOutboundAgg) {
                phoneToUnreadOutboundCount.put((String)ar.get('MVEX__Phone__c'), (Integer)ar.get('countId'));
            }
    
            // Sort the contacts by latest chat date descending
            recordData.sort(new RecordChatComparator(phoneToLastChat, phoneField));
    
            Map<String, Map<String, Object>> contactData = new Map<String, Map<String, Object>>();
            for (sObject rec : recordData) {
                Map<String, Object> contactDetails = new Map<String, Object>();
                contactDetails.put('Id', (String) rec.get('Id'));
                contactDetails.put('Name', (String) rec.get(nameField));
                contactDetails.put('Phone', (String) rec.get(phoneField));
                contactDetails.put('unreadOutboundCount', phoneToUnreadOutboundCount.containsKey((String) rec.get(phoneField)) ? phoneToUnreadOutboundCount.get((String) rec.get(phoneField)) : 0);
                contactData.put((String) rec.get('Id'), contactDetails);
            }
    
            return contactData;
        } catch (Exception e) {
            //ExceptionHandler.logException(new Map<String, Object>{'className' => 'ChatWindowController', 'methodName' => 'getContactsForChat', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null});
            return null;
        }
    }

    // Inner comparator class
    public class RecordChatComparator implements Comparator<sObject> {
        Map<String, DateTime> phoneToChatMap;
        String phoneFieldName;

        public RecordChatComparator(Map<String, DateTime> phoneChatMap, String phoneField) {
            this.phoneToChatMap = phoneChatMap;
            this.phoneFieldName = phoneField;
        }

        public Integer compare(sObject a, sObject b) {
            String aPhone = (String) a.get(phoneFieldName);
            String bPhone = (String) b.get(phoneFieldName);

            DateTime aDate = phoneToChatMap.containsKey(aPhone) ? phoneToChatMap.get(aPhone) : DateTime.newInstance(1900, 1, 1);
            DateTime bDate = phoneToChatMap.containsKey(bPhone) ? phoneToChatMap.get(bPhone) : DateTime.newInstance(1900, 1, 1);

            if (aDate > bDate) return -1; // Descending order
            if (aDate < bDate) return 1;
            return 0;
        }
    }

    /*
    *********************************************************
    @description     : Method is used to fetch all the chats 
    @param           : contactId - {String} - Id of the contact to fetch related chats only
    @return          : combinedData - {Map<String, Object>} - Map containing all the chats and theme preference
    ********************************************************
    */
    @AuraEnabled
    public static Map<String, Object> getCombinedData(String contactId, String objectApiName){

        Map<String, Object> combinedData = new Map<String, Object>();
        try {
            List<Chat__c> chats = new List<Chat__c>();
            List<WhatsappTemplate__c> templates = new List<WhatsappTemplate__c>();
            // Contact recordData = new Contact();
            MVEX__User_Theme_Preference__c userPreference = !userPreferences.isEmpty() ? userPreferences[0] : null;
            String theme = userPreference != null && userPreference.MVEX__Theme__c != null ? userPreference.MVEX__Theme__c : 'light'; // Default to Light

            // Fetch metadata record from Object_Config__mdt
            List<MVEX__Object_Config__mdt> objectConfigList = [SELECT Id, MVEX__ObjectConfigInfo__c, MVEX__ChatWindowConfigInfo__c FROM MVEX__Object_Config__mdt WITH USER_MODE LIMIT 1];
            String phoneField = '';
            String nameField = '';
            if(objectConfigList.size() <= 0) {
                System.debug('Object Config not found!');
                Map<String, Object> errorData = new Map<String, Object>{ 'error' => 'Object Configuration not found!' };
                return errorData;
            } else {
                // Deserialize the JSON string from ChatWindowConfigInfo__c
                if(objectConfigList[0].MVEX__ChatWindowConfigInfo__c == null) {
                    System.debug('Chat Config not found!');
                    Map<String, Object> errorData = new Map<String, Object>{ 'error' => 'Chat Configuration not found!' };
                    return errorData;
                }
                Map<String, Object> chatConfigData = (Map<String, Object>) JSON.deserializeUntyped(objectConfigList[0].MVEX__ChatWindowConfigInfo__c);
                Map<String, Object> chatConfig = (Map<String, Object>) chatConfigData.get(objectApiName);
                if(chatConfig == null) {
                    System.debug('Chat Config not found for the object "' + objectApiName+'"!');

                    Map<String, Object> errorData = new Map<String, Object>{ 'error' => 'Chat Configuration not found for the object ' + objectApiName+'!' };
                    return errorData;
                }
                phoneField = (String) chatConfig.get('phoneField');
                nameField = (String) chatConfig.get('nameField');
            }

            sObject recordData;
            String phoneNumber = '';
            String recordName = '';
            // recordData = [SELECT Id, Name, Phone FROM Contact WHERE Phone =:contactId WITH USER_MODE LIMIT 1];
            if(nameField != '' && phoneField != '') {
                String query = 'SELECT Id, ' +  nameField + ', ' +  phoneField + ' FROM ' + objectApiName + ' WHERE Id =: contactId LIMIT 1';
                recordData = Database.query(String.escapeSingleQuotes(query), AccessLevel.USER_MODE);
                phoneNumber = (String) recordData.get(phoneField);
                recordName = (String) recordData.get(nameField);
            }
            chats = [SELECT Id, Type_of_Message__c, WhatsAppMessageId__c, Message__c, Message_Status__c, Message_Type__c, Reply_To__c, Reaction__c, WhatsappTemplate__c, WhatsappTemplate__r.Template_Name__c, CreatedDate, Last_Interaction_Date__c, Phone__c, File_Data__c FROM Chat__c WHERE Phone__c =:phoneNumber WITH USER_MODE ORDER BY CreatedDate asc];
            //templates = [SELECT Id, Template_Name__c FROM Template__c WHERE Status__c = 'Active-Quality Pending' WITH USER_MODE ORDER BY LastModifiedDate desc];
            // Step 1: Get template IDs with matching child variables
            Set<Id> matchingTemplateIds = new Set<Id>();
            Map<Id, Set<String>> templateIdToObjectNames = new Map<Id, Set<String>>();
            for (Template_Variable__c tv : [
                SELECT WhatsappTemplate__c, Object_Name__c
                FROM Template_Variable__c
                WHERE WhatsappTemplate__r.Status__c = 'Active-Quality Pending'
            ]) {
                if (!templateIdToObjectNames.containsKey(tv.WhatsappTemplate__c)) {
                    templateIdToObjectNames.put(tv.WhatsappTemplate__c, new Set<String>());
                }
                templateIdToObjectNames.get(tv.WhatsappTemplate__c).add(tv.Object_Name__c);
            }

            for (Id templateId : templateIdToObjectNames.keySet()) {
                Set<String> objectNames = templateIdToObjectNames.get(templateId);
                if (objectNames.size() == 1 && objectNames.contains(objectApiName)) {
                    matchingTemplateIds.add(templateId);
                }
            }

            // Step 2: Fetch templates with matching child variables
            if (!matchingTemplateIds.isEmpty()) {
                templates.addAll(
                    [SELECT Id, Name, Template_Name__c, Template_Type__c FROM WhatsappTemplate__c WHERE Id IN :matchingTemplateIds WITH USER_MODE ORDER BY LastModifiedDate DESC
                ]);
            }

            // Step 3: Fetch templates that have **no** child variables
            List<WhatsappTemplate__c> templatesWithoutVariables = [SELECT Id, Name, Template_Name__c, Template_Type__c FROM WhatsappTemplate__c WHERE Status__c = 'Active-Quality Pending' AND Id NOT IN (SELECT WhatsappTemplate__c FROM Template_Variable__c) WITH USER_MODE ORDER BY LastModifiedDate DESC];

            // Step 3.1: Always include all Interactive Message templates.
            List<WhatsappTemplate__c> interactiveTemplates = [SELECT Id, Name, Template_Name__c, Template_Type__c FROM WhatsappTemplate__c WITH USER_MODE ORDER BY LastModifiedDate DESC];

            // Step 4: Combine results
            templates.addAll(templatesWithoutVariables);
            templates.addAll(interactiveTemplates);

            // Step 5: Deduplicate templates merged from multiple sources
            Map<Id, WhatsappTemplate__c> templateById = new Map<Id, WhatsappTemplate__c>();
            for (WhatsappTemplate__c t : templates) {
                templateById.put(t.Id, t);
            }
            templates = templateById.values();

            combinedData.put('chats', chats);
            combinedData.put('theme', theme);
            combinedData.put('templates', templates);
            combinedData.put('record', recordData);
            combinedData.put('phoneNumber', phoneNumber);
            combinedData.put('recordName', recordName);
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'ChatWindowController', 'getCombinedData', e.getMessage());
        }
        return combinedData;
    }

    /*
    *********************************************************
    @description     : Method is used to create a new chat message
    @param           : chatData - {Map<String, String>} - Map containing all the data to create a new chat
    @return          : chat - {Chat__c} - the newly created chat
    ********************************************************
    */
    @AuraEnabled
    public static Chat__c createChat(Map<String, String> chatData ){
        try {

            String message = chatData.get('message');
            String templateId = chatData.get('templateId');
            String messageType = chatData.get('messageType');
            String recordId = chatData.get('recordId');
            String replyToChatId = chatData.get('replyToChatId');
            String phoneNumber = chatData.get('phoneNumber');
            String objectName = chatData.get('objectName');

            Chat__c chat = new Chat__c();
            chat.Message__c = message;
            chat.WhatsappTemplate__c = templateId;
            chat.Phone__c = phoneNumber;
            chat.Type_of_Message__c	= 'OutBound Messages';
            chat.Message_Status__c = null;
            chat.Message_Type__c = messageType;
            chat.Reply_To__c = replyToChatId;
            chat.Object_Name__c = objectName;

            if(messageType == 'Image' || messageType == 'Document' || messageType == 'Video' || messageType == 'Audio'){
                List<ContentVersion> cv = [SELECT Id, ContentSize, Title, ContentDocumentId FROM ContentVersion WHERE Id =: message WITH USER_MODE];
                if(cv.size() < 1) {return null;}
                if(cv[0].ContentSize > 5000000){
                    ContentDocument cd = new ContentDocument(Id = cv[0].ContentDocumentId);
                    delete as user cd;
                    throw new AuraHandledException('FILE_SIZE_EXCEEDED');
                }
                ContentDistribution cd = new ContentDistribution();
                cd.Name = cv[0].Title;
                cd.ContentVersionId = message;
                cd.PreferencesAllowViewInBrowser= true;
                cd.PreferencesLinkLatestVersion=true;
                cd.PreferencesNotifyOnVisit=false;
                cd.PreferencesPasswordRequired=false;
                cd.PreferencesAllowOriginalDownload= true;
                insert as user cd;

                chat.Message__c = [SELECT ContentDownloadUrl FROM ContentDistribution WHERE Id=:cd.Id WITH USER_MODE].ContentDownloadUrl;
                Map<String, Object> fileData = new Map<String, Object>{ 'fileName' => cv[0].Title, 'documentId' => cv[0].ContentDocumentId, 'contentVersionId' => message };
                chat.File_Data__c = JSON.serialize(fileData);
            }
            insert as user chat;
            chat = [SELECT Id, Type_of_Message__c, WhatsAppMessageId__c, Message__c, Message_Status__c, Message_Type__c, Reply_To__c, Reaction__c, WhatsappTemplate__c, WhatsappTemplate__r.Template_Name__c, CreatedDate, Last_Interaction_Date__c, File_Data__c FROM Chat__c WHERE Id =:chat.Id WITH USER_MODE];
            return chat;
        } catch (Exception e) {
            if(e.getMessage().contains('STORAGE_LIMIT_EXCEEDED')){
                ErrorHandler.insertErrordata(e, 'ChatWindowController', 'createChat', 'STORAGE_LIMIT_EXCEEDED');
                throw new AuraHandledException('STORAGE_LIMIT_EXCEEDED');
            }
            ErrorHandler.insertErrordata(e, 'ChatWindowController', 'createChat', e.getMessage());
            return null;
        }
    }


    /*
    *********************************************************
    @description     : Method is used to update the reaction of any chat message
    @param           : chatId - {String} - Id of the chat to update
    @param           : reaction - {String} - reaction to be updated
    @return          : chat - {Chat__c} - the updated chat
    ********************************************************
    */
    @AuraEnabled
    public static Chat__c updateReaction(String chatId, String reaction){
        try{
            Chat__c chat = new Chat__c();
            chat.Id = chatId;
            chat.Reaction__c = reaction;
            update as user chat;
            return chat;
        }catch(Exception e){
            ErrorHandler.insertErrordata(e, 'ChatWindowController', 'updateReaction', e.getMessage());
            return null;
        }
    }

    /*
    *********************************************************
    @description     : Method is used to update the theme preference for the current user
    @param           : theme - {String} - The new theme preference ('Light' or 'Dark')
    @return          : isSuccess - {Boolean} - success message for js controller
    ********************************************************
    */
    @AuraEnabled
    public static Boolean updateThemePreference(String theme) {
        Boolean isSuccess = false;
        try {
            MVEX__User_Theme_Preference__c userPreference = new MVEX__User_Theme_Preference__c();
            if (userPreferences.isEmpty()) {
                userPreference.SetupOwnerId = UserInfo.getUserId();
            }else{
                userPreference = userPreferences[0];
            }
            userPreference.MVEX__Theme__c = theme;
            upsert as User userPreference;
            isSuccess = true;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'ChatWindowController', 'updateThemePreference', e.getMessage());
        }
        return isSuccess;
    }

    /*
    *********************************************************
    @description     : Method to send the messages from the chat window
    @param           : jsonData - {String} - The JSON Data to send as a request body
    @param           : chatId - {String} - Id of the related Chat
    @param           : isReaction - {String} - to specify if the action is for a reaction
    @param           : reaction - {String} - reaction string if the action is for a reaction
    @return          : resultMap - {Map<String, Object>} - containing errorMessage and a chat record
    ********************************************************
    */
    @AuraEnabled
    public static Map<String, Object> sendWhatsappMessage(String jsonData, String chatId, Boolean isReaction, String reaction) {
        Map<String, Object> resultMap = new Map<String, Object>{};
        Chat__c chat = new Chat__c(Id = chatId);
        try {
            HttpRequest httpReq = new HttpRequest();
            resultMap.put('errorMessage', null);
            // List<WBConnect_Configuration__mdt> wbConfig = WBConnect_Configuration__mdt.getAll().values(); 
            if(wbConfig==null || wbConfig.isEmpty()){
                if(!isReaction){
                    chat.Message_Status__c = 'Failed';
                }else{
                    chat.Reaction__c = '<|USER|>' + reaction.substringAfter('<|USER|>');
                }
                update as user chat;
                resultMap.put('errorMessage', 'METADATA_ERROR');
                resultMap.put('chat', chat);
                return resultMap;
            }

            System.debug('jsonData: ' + jsonData);
            String accessToken = wbConfig[0].MVEX__Access_Token__c;
            String endpoint = wbConfig[0].MVEX__APIEndpoint__c + '/' + wbConfig[0].MVEX__APIVersion__c + '/' + wbConfig[0].MVEX__Phone_Number_Id__c + '/messages';
            httpReq.setEndpoint(endpoint);
            httpReq.setMethod('POST');
            httpReq.setHeader('Content-Type', 'application/json');
            httpReq.setHeader('Authorization', 'Bearer ' + accessToken);
            httpReq.setBody(jsonData);
            Http http = new Http();
            HttpResponse response = http.send(httpReq);
            Integer statusCode = response.getStatusCode();
            if(response != null && statusCode == 200){
                String responseBody = response.getBody();
                Map<String, Object> jsonMap = (Map<String, Object>)JSON.deserializeUntyped(responseBody);
                List<Object> messages = (List<Object>)jsonMap.get('messages');
                Map<String, Object> firstMessage = (Map<String, Object>)messages[0];
                String whatsAppMessageID = (String) firstMessage.get('id');
                System.debug('WhatsApp Message ID: ' + whatsAppMessageID);
                // Update the chat record
                if(!isReaction){
                    chat.WhatsAppMessageId__c = whatsAppMessageID;
                    chat.Message_Status__c = 'Sent';
                }
            }else{
                System.debug('Error sending WhatsApp Message: '+response.getBody());
                if(!isReaction){
                    chat.Message_Status__c = 'Failed';
                }
                ErrorHandler.insertErrordata(null, 'ChatWindowController', 'sendWhatsappMessage', 'API Exception while sending a message');
            }

            // Step 1: Deserialize full JSON
            Map<String, Object> jsonMap = (Map<String, Object>) JSON.deserializeUntyped(jsonData);

            // Step 2: Persist template / interactive payload details for preview
            if (jsonMap.containsKey('template')) {
                // Standard template message – store only the components array
                Map<String, Object> templateMap = (Map<String, Object>) jsonMap.get('template');
                if (templateMap != null && templateMap.containsKey('components')) {
                    List<Object> componentsList = (List<Object>) templateMap.get('components');
                    String componentsJsonString = JSON.serialize(componentsList);
                    chat.Sent_Template_Details__c = componentsJsonString;
                }
            } else if (jsonMap.containsKey('interactive')) {
                // Interactive message – store the full payload JSON used for send
                // so that the TemplatePreview LWC can render an accurate preview
                chat.Sent_Template_Details__c = jsonData;
            }

            update as user chat;
            chat = [SELECT Id, Type_of_Message__c, WhatsAppMessageId__c, Message__c, Message_Status__c, Message_Type__c, Reply_To__c, Reaction__c, WhatsappTemplate__c, WhatsappTemplate__r.Template_Name__c, CreatedDate, Last_Interaction_Date__c FROM Chat__c WHERE Id =:chat.Id WITH USER_MODE];
            resultMap.put('chat', chat);
            return resultMap;

        } catch (Exception e) {
            if(!isReaction){
                chat.Message_Status__c = 'Failed';
                update as user chat;
            }
            ErrorHandler.insertErrordata(e, 'ChatWindowController', 'sendWhatsappMessage', e.getMessage());
        }
        resultMap.put('chat', chat);
        return resultMap;
    }

    /*
    *********************************************************
    @description     : Method to get the data for a specific template
    @param           : templateId - {String} - Id of the template to fetch
    @param           : contactId - {String} - Id of the contact to fetch related data for variables
    @return          : template - {Template__c} - Template object with full data of it
    ********************************************************
    */
    @AuraEnabled
    public static Map<String, object> getTemplateData(String templateId, String contactId, String objectApiName){
        try {
            Map<String, Object> templateData = new Map<String, Object>();
            List<WhatsappTemplate__c> templates = new List<WhatsappTemplate__c>();
            Set<Id> matchingTemplateIds = new Set<Id>();
            for (Template_Variable__c tv : [SELECT WhatsappTemplate__c FROM Template_Variable__c WHERE Object_Name__c = :objectApiName WITH USER_MODE]) {
                matchingTemplateIds.add(tv.WhatsappTemplate__c);
            }

            // Fetch template details
            if (!matchingTemplateIds.isEmpty()) {
                templates.addAll([
                    SELECT Id, Template_Name__c, Template_Miscellaneous_Data__c, WBButton_Body__c, Button_Label__c, Button_Type__c, WBFooter_Body__c, WBHeader_Body__c, Header_Type__c, Language__c, WBTemplate_Body__c, Template_Category__c, Template_SubCatagory__c, Template_Type__c, Template_Variable__c,
                        (SELECT Id, Name, Field_Name__c, Object_Name__c, Type__c, Alternate_Text__c FROM WB_Template_Variables__r) FROM WhatsappTemplate__c WHERE Id = :templateId AND Id IN :matchingTemplateIds WITH USER_MODE
                ]);
            }

            // Fetch templates without child variables
            List<WhatsappTemplate__c> templatesWithoutVariables = [
                SELECT Id, Template_Name__c, Template_Miscellaneous_Data__c, WBButton_Body__c, Button_Label__c, Button_Type__c, WBFooter_Body__c, WBHeader_Body__c, Header_Type__c, Language__c, WBTemplate_Body__c, Template_Category__c, Template_SubCatagory__c, Template_Type__c, Template_Variable__c,
                    (SELECT Id, Name, Field_Name__c, Object_Name__c, Type__c, Alternate_Text__c FROM WB_Template_Variables__r) FROM WhatsappTemplate__c WHERE Id = :templateId WITH USER_MODE
            ];
            templates.addAll(templatesWithoutVariables);

            if(templates.size() > 0 && templates[0].Template_Variable__c>0){
                WhatsappTemplate__c template= templates[0];
                Set<String> fieldSelectionCause = new Set<String>();
                for (Template_Variable__c tv : template.WB_Template_Variables__r) {
                    // Field_Name__c can contain relationship fields like 'CreatedBy.Name' or simple fields like 'Name'
                    if (String.isNotBlank(tv.Field_Name__c)) {
                        fieldSelectionCause.add(tv.Field_Name__c);
                    }
                }
                
                if(fieldSelectionCause.size() < 1){
                    templateData.put('template', templates[0]);
                    return templateData;
                }

                String query = 'SELECT ' + String.join(fieldSelectionCause, ', ') + ' FROM ' + objectApiName + ' WHERE Id =:contactId';
                List<sObject> records = Database.query(String.escapeSingleQuotes(query));
                List<Object> headerVariables = new List<Object>();
                List<Object> bodyVariables = new List<Object>();
                if(records.size() > 0){
                    sObject record = records[0];
                    for (Template_Variable__c tv: template.WB_Template_Variables__r) {
                        // Use getFieldValue to support relationship fields like 'CreatedBy.Name'
                        Object valueToReplace = getFieldValue(record, tv.Field_Name__c);
                        if (tv.Type__c == 'Header') {
                            headerVariables.add(valueToReplace != null ? valueToReplace.toString() : (tv.Alternate_Text__c!= null ? tv.Alternate_Text__c : ' '));
                            template.WBHeader_Body__c = template.WBHeader_Body__c.replace(tv.Name , valueToReplace != null ? valueToReplace.toString() : (tv.Alternate_Text__c!= null ? tv.Alternate_Text__c : ' ') );
                        }else if(tv.Type__c == 'Body'){
                            bodyVariables.add(valueToReplace != null ? valueToReplace.toString() : (tv.Alternate_Text__c!= null ? tv.Alternate_Text__c : ' '));
                            template.WBTemplate_Body__c = template.WBTemplate_Body__c.replace(tv.Name , valueToReplace != null ? valueToReplace.toString() : (tv.Alternate_Text__c!= null ? tv.Alternate_Text__c : ' ') );
                        }
                    }
                }

                if (template.Header_Type__c == 'Image') {
                    templateData.put('isImageUrl', true);
                }
                else if (template.Header_Type__c == 'Video') {
                    templateData.put('isImageUrl', true);
                }
                else if (template.Header_Type__c == 'Document') {
                    templateData.put('isImageUrl', true);
                }

                templateData.put('template', template);
                templateData.put('headerParams', headerVariables);
                templateData.put('bodyParams', bodyVariables);
                templateData.put('template', templates[0]);
                return templateData;
            } else if (templates.size() > 0 && templates[0].Template_Variable__c < 1){
                WhatsappTemplate__c template = templates[0];
                if (template.Header_Type__c == 'Image') {
                    templateData.put('isImageUrl', true);
                }
                else if (template.Header_Type__c == 'Video') {
                    templateData.put('isImageUrl', true);
                }
                else if (template.Header_Type__c == 'Document') {
                    templateData.put('isImageUrl', true);
                }

                templateData.put('template', templates[0]);
                return templateData;
            } else {
                return null;
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'ChatWindowController', 'getTemplateData', e.getMessage());
        }
        return null;
    }

    /*
    *********************************************************
    @description     : Builds the full WhatsApp interactive message payload JSON
                        from the stored template body by replacing dynamic
                        variables and recipient number in the backend.
    @param           : templateId - {String} - Id of the template to use
    @param           : contactId - {String} - Id of the record to resolve merge fields
    @param           : objectApiName - {String} - API name of the record object
    @param           : phoneNumber - {String} - Recipient phone number
    @return          : String - Final payload JSON with all placeholders replaced
    ********************************************************
    */
    @AuraEnabled
    public static String buildInteractivePayload(String templateId, String contactId, String objectApiName, String phoneNumber) {
        try {
            // Re‑use existing logic to resolve template variables for the given record
            Map<String, Object> templateData = getTemplateData(templateId, contactId, objectApiName);
            if (templateData == null || !templateData.containsKey('template')) {
                return null;
            }

            WhatsappTemplate__c template = (WhatsappTemplate__c)templateData.get('template');
            if (template == null || String.isBlank(template.WBTemplate_Body__c)) {
                return null;
            }

            String payload = template.WBTemplate_Body__c;

            // Replace the recipient number placeholder, if present
            if (!String.isBlank(phoneNumber)) {
                String normalizedPhone = phoneNumber.replaceAll('\\s+', '');
                payload = payload.replace('{{RECIPIENT_NUMBER}}', normalizedPhone);
            }

            return payload;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'ChatWindowController', 'buildInteractivePayload', e.getMessage());
            return null;
        }
    }

    /*
    *********************************************************
    @description     : Method to mark all unread message IDs as "read"
    @param           : messageIds - {List<String>} - List of chat IDs to be marked as read
    @return          : Integer - Count of successfully updated messages
    *********************************************************
    */
    @AuraEnabled
    public static Integer updateStatus(List<String> messageIds) {
        List<Chat__c> chats = [SELECT Id, WhatsAppMessageId__c, Message_Status__c FROM Chat__c WHERE Id IN :messageIds WITH USER_MODE];
        String accessToken = wbConfig[0].MVEX__Access_Token__c;
        String endpoint = wbConfig[0].MVEX__APIEndpoint__c + '/' + wbConfig[0].MVEX__APIVersion__c + '/' + wbConfig[0].MVEX__Phone_Number_Id__c + '/messages';
        
        List<Map<String, Object>> errorLogs = new List<Map<String, Object>>();
        Integer successCount = 0;

        try {
            // First, complete all callouts and collect errors
            for (Chat__c chat : chats) {
                // Skip messages without a valid WhatsApp Message ID
                if (String.isBlank(chat.WhatsAppMessageId__c)) {
                    continue;
                }
                
                String payload = JSON.serialize(new Map<String, Object>{
                    'messaging_product' => 'whatsapp',
                    'status' => 'read',
                    'message_id' => chat.WhatsAppMessageId__c
                });
                Http http = new Http();
                HttpRequest request = new HttpRequest();
                request.setEndpoint(endpoint);
                request.setMethod('POST');
                request.setHeader('Authorization', 'Bearer ' + accessToken);
                request.setHeader('Content-Type', 'application/json');
                request.setBody(payload);

                HttpResponse response = http.send(request);

                Integer statusCode = response.getStatusCode();
                if (statusCode != 200) {
                    // Collect error for later logging (after all callouts)
                    errorLogs.add(new Map<String, Object>{ 
                        'className' => 'ChatWindowController', 
                        'methodName' => 'updateStatus', 
                        'exceptionObj' => null, 
                        'isApiException' => true, 
                        'statusCode' => statusCode,
                        'chatId' => chat.Id,  
                        'moreDetails' => 'Error occurred for status update', 
                        'apiResponse' => response.getBody() 
                    });
                } else {
                    chat.Message_Status__c = 'Seen';
                    successCount++;
                }
            }
            
            // Update chats after all callouts are complete
            if (!chats.isEmpty()) {
                update as user chats;
            }
            
            // Log all errors after DML is complete (batch insert)
            if (!errorLogs.isEmpty()) {
                // ExceptionHandler.logMultipleExceptions(errorLogs);
            }
            
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'ChatWindowController', 'updateStatus', e.getMessage());
        }
        
        return successCount;
    }

    /*
    *********************************************************
    @description     : Method is used to create a new chat message for the Files which are stored in AWS
    @param           : chatData - {Map<String, String>} - Map containing all the data to create a new chat
    @return          : chat - {Chat__c} - the newly created chat
    ********************************************************
    */
    @AuraEnabled
    public static Chat__c createChatForAWSFiles(Map<String, String> chatData ){
        try {

            String message = chatData.get('message');
            String fileName = chatData.get('fileName');
            String mimeType = chatData.get('mimeType');
            String messageType = chatData.get('messageType');
            String recordId = chatData.get('recordId');
            String replyToChatId = chatData.get('replyToChatId');
            String phoneNumber = chatData.get('phoneNumber');

            Chat__c chat = new Chat__c();
            chat.Message__c = message;
            chat.Phone__c = phoneNumber;
            chat.Type_of_Message__c	= 'OutBound Messages';
            chat.Message_Status__c = null;
            chat.Message_Type__c = messageType;
            chat.Reply_To__c = replyToChatId;
            Map<String, Object> fileData = new Map<String, Object>{ 'fileName' => fileName, 'mimeType' => mimeType };
            chat.File_Data__c = JSON.serialize(fileData);

            insert as user chat;
            chat = [SELECT Id, Type_of_Message__c, WhatsAppMessageId__c, Message__c, Message_Status__c, Message_Type__c, Reply_To__c, Reaction__c, WhatsappTemplate__c, WhatsappTemplate__r.Template_Name__c, CreatedDate, Last_Interaction_Date__c, File_Data__c FROM Chat__c WHERE Id =:chat.Id WITH USER_MODE];

            return chat;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'ChatWindowController', 'createChatForAWSFiles', e.getMessage());
            return null;
        }
    }

    /**********************************************************
    @description     : Method to get the preview data for a specific template
    @param           : templateId - {String} - Id of the template to fetch
    @param           : chatId - {String} - Id of the chat to fetch related data for variables
    @return          : template - {Template__c} - Template object with full data of it
    ********************************************************
    */
    @AuraEnabled
    public static Map<String, object> getTemplatePreviewData(String templateId, String chatId){
        try {
            Map<String, Object> templateData = new Map<String, Object>();

            List<Chat__c> chatRecs = [SELECT Sent_Template_Details__c FROM Chat__c WHERE Id = :chatId WITH USER_MODE];
            if(chatRecs.size() > 0){
                String templateMergeDetails = chatRecs[0].Sent_Template_Details__c;
                if(String.isNotBlank(templateMergeDetails)){
                    templateData.put('templateMergeDetails', chatRecs[0]);
                }
            }

            List<WhatsappTemplate__c> templates = [SELECT Id, Template_Name__c, WBButton_Body__c, Button_Label__c, Button_Type__c, WBFooter_Body__c, WBHeader_Body__c, Header_Type__c, Language__c, WBTemplate_Body__c, Template_Category__c, Template_SubCatagory__c, MVEX__Template_Miscellaneous_Data__c, Template_Type__c, Template_Variable__c, (SELECT Id, Name, Field_Name__c, Object_Name__c, Type__c, Alternate_Text__c FROM WB_Template_Variables__r) FROM WhatsappTemplate__c WHERE Id = :templateId WITH USER_MODE ORDER BY CreatedDate DESC];

            if(templates.size() > 0){
                WhatsappTemplate__c template = templates[0];
                if (template.Header_Type__c == 'Image') {
                    templateData.put('isImageUrl', true);
                }
                else if (template.Header_Type__c == 'Video') {
                    templateData.put('isImageUrl', true);
                }
                else if (template.Header_Type__c == 'Document') {
                    templateData.put('isImageUrl', true);
                }

                templateData.put('template', templates[0]);
                return templateData;
            } else {
                return null;
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'ChatWindowController', 'getTemplatePreviewData', e.getMessage());
        }
        return null;
    }

    /*
    *********************************************************
    @description     : Gets field value from SObject, supporting relationship fields
    @param           : record - {SObject} - The SObject record
    @param           : fieldPath - {String} - The field path (e.g., 'Name' or 'CreatedBy.Name')
    @return          : Object - field value
    *********************************************************
    */
    public static Object getFieldValue(SObject record, String fieldPath) {
        try {
            if (record == null || String.isBlank(fieldPath)) {
                return null;
            }
            
            if (fieldPath.contains('.')) {
                // Handle relationship fields like 'CreatedBy.Name' or 'Account.Owner.Name'
                List<String> fieldParts = fieldPath.split('\\.');
                SObject currentRecord = record;
                
                // Traverse through the relationship chain
                for (Integer i = 0; i < fieldParts.size() - 1; i++) {
                    currentRecord = currentRecord.getSObject(fieldParts[i]);
                    if (currentRecord == null) {
                        return null;
                    }
                }
                
                // Get the final field value
                return currentRecord.get(fieldParts[fieldParts.size() - 1]);
            } else {
                // Simple field - direct access
                return record.get(fieldPath);
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'ChatWindowController', 'getFieldValue', e.getMessage());
            return null;
        }
    }

}