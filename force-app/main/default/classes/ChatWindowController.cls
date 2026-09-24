/**
 * Class Name: ChatWindowController
 * Test Class: ChatWindowControllerTest
 * @description: Used for handling various actions for the chat
 * Created Date: 22 Nov, 2024
 * Created By: Harsh Gandhi
 *
 * MODIFICATION LOG*
 * Last Update Date : 20/07/2026
 * Updated By : Harsh Gandhi
 * Change Description : Updated field api names, exception handling, content distribution for files, theme preferences, message sending, dynamic field mapping, multiple media types in createChat, and merge field resolution for related objects.
 */
public with sharing class ChatWindowController {

    /* Variables to be used generally for the class 
    *********************************************************
    @variable wbConfig - {List<WBConnect_Configuration__mdt>} - Custom Metadata containing auth values for whatsapp
    @variable userPreferences - {List<User_Theme_Preference__c>} - Custom Setting for showing user theme as their preference
    *********************************************************
    */
    /* ---------------- Start ---------------- */
    public static MVEX__WhatsAppConfig__c wbConfig = MVEX__WhatsAppConfig__c.getOrgDefaults(); 
    public static List<User_Theme_Preference__c> userPreferences = [SELECT Theme__c FROM User_Theme_Preference__c WHERE SetupOwnerId =: UserInfo.getUserId() WITH USER_MODE LIMIT 1];
    /* ----------------  End  ---------------- */

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
            List<MVEX__Chat__c> chats = new List<MVEX__Chat__c>();
            List<MVEX__WhatsappTemplate__c> templates = new List<MVEX__WhatsappTemplate__c>();
            // Contact recordData = new Contact();
            User_Theme_Preference__c userPreference = !userPreferences.isEmpty() ? userPreferences[0] : null;
            String theme = userPreference != null && userPreference.Theme__c != null ? userPreference.Theme__c : 'light'; // Default to Light

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
            chats = [SELECT Id, MVEX__Type_of_Message__c, MVEX__WhatsAppMessageId__c, MVEX__Message__c, MVEX__Message_Status__c, MVEX__Message_Type__c, MVEX__Reply_To__c, MVEX__Reaction__c, MVEX__WhatsappTemplate__c, MVEX__WhatsappTemplate__r.MVEX__Template_Name__c, CreatedDate, MVEX__Last_Interaction_Date__c, MVEX__Phone__c, MVEX__File_Data__c FROM MVEX__Chat__c WHERE MVEX__Phone__c =:phoneNumber WITH USER_MODE ORDER BY CreatedDate asc];
            //templates = [SELECT Id, MVEX__Template_Name__c FROM Template__c WHERE MVEX__Status__c = 'Active-Quality Pending' WITH USER_MODE ORDER BY LastModifiedDate desc];
            // Step 1: Get template IDs with matching child variables
            Set<Id> matchingTemplateIds = new Set<Id>();
            Map<Id, Set<String>> templateIdToObjectNames = new Map<Id, Set<String>>();
            for (MVEX__Template_Variable__c tv : [
                SELECT MVEX__WhatsappTemplate__c, MVEX__Object_Name__c
                FROM MVEX__Template_Variable__c
                WHERE MVEX__WhatsappTemplate__r.MVEX__Status__c = 'Active-Quality Pending'
            ]) {
                if (!templateIdToObjectNames.containsKey(tv.MVEX__WhatsappTemplate__c)) {
                    templateIdToObjectNames.put(tv.MVEX__WhatsappTemplate__c, new Set<String>());
                }
                templateIdToObjectNames.get(tv.MVEX__WhatsappTemplate__c).add(tv.MVEX__Object_Name__c);
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
                    [SELECT Id, Name, MVEX__Template_Name__c, MVEX__Template_Type__c FROM MVEX__WhatsappTemplate__c WHERE Id IN :matchingTemplateIds WITH USER_MODE ORDER BY LastModifiedDate DESC
                ]);
            }

            // Step 3: Fetch templates that have **no** child variables
            List<MVEX__WhatsappTemplate__c> templatesWithoutVariables = [SELECT Id, Name, MVEX__Template_Name__c, MVEX__Template_Type__c FROM MVEX__WhatsappTemplate__c WHERE MVEX__Status__c = 'Active-Quality Pending' AND Id NOT IN (SELECT MVEX__WhatsappTemplate__c FROM MVEX__Template_Variable__c) WITH USER_MODE ORDER BY LastModifiedDate DESC];

            // Step 3.1: Always include all Interactive Message templates.
            List<MVEX__WhatsappTemplate__c> interactiveTemplates = [SELECT Id, Name, MVEX__Template_Name__c, MVEX__Template_Type__c FROM MVEX__WhatsappTemplate__c WITH USER_MODE ORDER BY LastModifiedDate DESC];

            // Step 4: Combine results
            templates.addAll(templatesWithoutVariables);
            templates.addAll(interactiveTemplates);

            // Step 5: Deduplicate templates merged from multiple sources
            Map<Id, MVEX__WhatsappTemplate__c> templateById = new Map<Id, MVEX__WhatsappTemplate__c>();
            for (MVEX__WhatsappTemplate__c t : templates) {
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
    @return          : chat - {MVEX__Chat__c} - the newly created chat
    ********************************************************
    */
    @AuraEnabled
    public static MVEX__Chat__c createChat(Map<String, String> chatData ){
        try {

            String message = chatData.get('message');
            String templateId = chatData.get('templateId');
            String messageType = chatData.get('messageType');
            String recordId = chatData.get('recordId');
            String replyToChatId = chatData.get('replyToChatId');
            String phoneNumber = chatData.get('phoneNumber');
            String objectName = chatData.get('objectName');

            MVEX__Chat__c chat = new MVEX__Chat__c();
            chat.MVEX__Message__c = message;
            chat.MVEX__WhatsappTemplate__c = templateId;
            chat.MVEX__Phone__c = phoneNumber;
            chat.MVEX__Type_of_Message__c	= 'OutBound Messages';
            chat.MVEX__Message_Status__c = null;
            chat.MVEX__Message_Type__c = messageType;
            chat.MVEX__Reply_To__c = replyToChatId;
            chat.MVEX__Object_Name__c = objectName;

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

                chat.MVEX__Message__c = [SELECT ContentDownloadUrl FROM ContentDistribution WHERE Id=:cd.Id WITH USER_MODE].ContentDownloadUrl;
                Map<String, Object> fileData = new Map<String, Object>{ 'fileName' => cv[0].Title, 'documentId' => cv[0].ContentDocumentId, 'contentVersionId' => message };
                chat.MVEX__File_Data__c = JSON.serialize(fileData);
            }
            insert as user chat;
            chat = [SELECT Id, MVEX__Type_of_Message__c, MVEX__WhatsAppMessageId__c, MVEX__Message__c, MVEX__Message_Status__c, MVEX__Message_Type__c, MVEX__Reply_To__c, MVEX__Reaction__c, MVEX__WhatsappTemplate__c, MVEX__WhatsappTemplate__r.MVEX__Template_Name__c, CreatedDate, MVEX__Last_Interaction_Date__c, MVEX__File_Data__c FROM MVEX__Chat__c WHERE Id =:chat.Id WITH USER_MODE];
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
    @return          : chat - {MVEX__Chat__c} - the updated chat
    ********************************************************
    */
    @AuraEnabled
    public static MVEX__Chat__c updateReaction(String chatId, String reaction){
        try{
            MVEX__Chat__c chat = new MVEX__Chat__c();
            chat.Id = chatId;
            chat.MVEX__Reaction__c = reaction;
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
            User_Theme_Preference__c userPreference = new User_Theme_Preference__c();
            if (userPreferences.isEmpty()) {
                userPreference.SetupOwnerId = UserInfo.getUserId();
            }else{
                userPreference = userPreferences[0];
            }
            userPreference.Theme__c = theme;
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
        MVEX__Chat__c chat = new MVEX__Chat__c(Id = chatId);
        try {
            HttpRequest httpReq = new HttpRequest();
            resultMap.put('errorMessage', null);
            // List<WBConnect_Configuration__mdt> wbConfig = WBConnect_Configuration__mdt.getAll().values(); 
            if(wbConfig==null){
                if(!isReaction){
                    chat.MVEX__Message_Status__c = 'Failed';
                }else{
                    chat.MVEX__Reaction__c = '<|USER|>' + reaction.substringAfter('<|USER|>');
                }
                update as user chat;
                resultMap.put('errorMessage', 'CUSTOM_SETTING_ERROR');
                resultMap.put('chat', chat);
                return resultMap;
            }

            System.debug('jsonData: ' + jsonData);
            String accessToken = (wbConfig.MVEX__Access_Token_1__c != null ? wbConfig.MVEX__Access_Token_1__c : '') + (wbConfig.MVEX__Access_Token_2__c != null ? wbConfig.MVEX__Access_Token_2__c : '');
            String endpoint = wbConfig.MVEX__whatsapp_endpoint__c + '/' + wbConfig.MVEX__APIVersion__c + '/' + wbConfig.MVEX__Whatsapp_Phone_Number_Id__c + '/messages';
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
                    chat.MVEX__WhatsAppMessageId__c = whatsAppMessageID;
                    chat.MVEX__Message_Status__c = 'Sent';
                }
            }else{
                System.debug('Error sending WhatsApp Message: '+response.getBody());
                if(!isReaction){
                    chat.MVEX__Message_Status__c = 'Failed';
                }
                ErrorHandler.insertErrordata(null, 'ChatWindowController', 'sendWhatsappMessage', 'API Exception while sending a message and error at line 441');
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
                    chat.MVEX__Sent_Template_Details__c = componentsJsonString;
                }
            } else if (jsonMap.containsKey('interactive')) {
                // Interactive message – store the full payload JSON used for send
                // so that the TemplatePreview LWC can render an accurate preview
                chat.MVEX__Sent_Template_Details__c = jsonData;
            }

            update as user chat;
            chat = [SELECT Id, MVEX__Type_of_Message__c, MVEX__WhatsAppMessageId__c, MVEX__Message__c, MVEX__Message_Status__c, MVEX__Message_Type__c, MVEX__Reply_To__c, MVEX__Reaction__c, MVEX__WhatsappTemplate__c, MVEX__WhatsappTemplate__r.MVEX__Template_Name__c, CreatedDate, MVEX__Last_Interaction_Date__c FROM MVEX__Chat__c WHERE Id =:chat.Id WITH USER_MODE];
            resultMap.put('chat', chat);
            return resultMap;

        } catch (Exception e) {
            if(!isReaction){
                chat.MVEX__Message_Status__c = 'Failed';
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
            List<MVEX__WhatsappTemplate__c> templates = new List<MVEX__WhatsappTemplate__c>();
            Set<Id> matchingTemplateIds = new Set<Id>();
            for (MVEX__Template_Variable__c tv : [SELECT MVEX__WhatsappTemplate__c FROM MVEX__Template_Variable__c WHERE MVEX__Object_Name__c = :objectApiName WITH USER_MODE]) {
                matchingTemplateIds.add(tv.MVEX__WhatsappTemplate__c);
            }

            // Fetch template details
            if (!matchingTemplateIds.isEmpty()) {
                templates.addAll([SELECT Id, MVEX__Template_Name__c, MVEX__Template_Miscellaneous_Data__c, MVEX__WBButton_Body__c, MVEX__Button_Label__c, 
                                    MVEX__Button_Type__c, MVEX__WBFooter_Body__c, MVEX__WBHeader_Body__c, MVEX__Header_Type__c, MVEX__Language__c, 
                                    MVEX__WBTemplate_Body__c, MVEX__Template_Category__c, MVEX__Template_SubCatagory__c, MVEX__Template_Type__c, 
                                    MVEX__Template_Variable__c, (SELECT Id, Name, MVEX__Field_Name__c, MVEX__Object_Name__c, MVEX__Type__c, MVEX__Alternate_Text__c FROM 
                                    MVEX__WB_Template_Variables__r) FROM MVEX__WhatsappTemplate__c WHERE Id = :templateId AND Id IN :matchingTemplateIds WITH USER_MODE]);
            }

            // Fetch templates without child variables
            List<MVEX__WhatsappTemplate__c> templatesWithoutVariables = [SELECT Id, MVEX__Template_Name__c, MVEX__Template_Miscellaneous_Data__c, MVEX__WBButton_Body__c, 
                                                                            MVEX__Button_Label__c, MVEX__Button_Type__c, MVEX__WBFooter_Body__c, MVEX__WBHeader_Body__c, 
                                                                            MVEX__Header_Type__c, MVEX__Language__c, MVEX__WBTemplate_Body__c, MVEX__Template_Category__c, 
                                                                            MVEX__Template_SubCatagory__c, MVEX__Template_Type__c, MVEX__Template_Variable__c,
                                                                            (SELECT Id, Name, MVEX__Field_Name__c, MVEX__Object_Name__c, MVEX__Type__c, MVEX__Alternate_Text__c FROM 
                                                                            MVEX__WB_Template_Variables__r) FROM MVEX__WhatsappTemplate__c WHERE Id = :templateId WITH USER_MODE];
            templates.addAll(templatesWithoutVariables);

            if(templates.size() > 0 && templates[0].MVEX__Template_Variable__c>0){
                MVEX__WhatsappTemplate__c template= templates[0];
                Set<String> fieldSelectionCause = new Set<String>();
                for (MVEX__Template_Variable__c tv : template.MVEX__WB_Template_Variables__r) {
                    // MVEX__Field_Name__c can contain relationship fields like 'CreatedBy.Name' or simple fields like 'Name'
                    if (String.isNotBlank(tv.MVEX__Field_Name__c)) {
                        fieldSelectionCause.add(tv.MVEX__Field_Name__c);
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
                    for (MVEX__Template_Variable__c tv: template.MVEX__WB_Template_Variables__r) {
                        // Use getFieldValue to support relationship fields like 'CreatedBy.Name'
                        Object valueToReplace = getFieldValue(record, tv.MVEX__Field_Name__c);
                        if (tv.MVEX__Type__c == 'Header') {
                            headerVariables.add(valueToReplace != null ? valueToReplace.toString() : (tv.MVEX__Alternate_Text__c!= null ? tv.MVEX__Alternate_Text__c : ' '));
                            template.MVEX__WBHeader_Body__c = template.MVEX__WBHeader_Body__c.replace(tv.Name , valueToReplace != null ? valueToReplace.toString() : (tv.MVEX__Alternate_Text__c!= null ? tv.MVEX__Alternate_Text__c : ' ') );
                        }else if(tv.MVEX__Type__c == 'Body'){
                            bodyVariables.add(valueToReplace != null ? valueToReplace.toString() : (tv.MVEX__Alternate_Text__c!= null ? tv.MVEX__Alternate_Text__c : ' '));
                            template.MVEX__WBTemplate_Body__c = template.MVEX__WBTemplate_Body__c.replace(tv.Name , valueToReplace != null ? valueToReplace.toString() : (tv.MVEX__Alternate_Text__c!= null ? tv.MVEX__Alternate_Text__c : ' ') );
                        }
                    }
                }

                if (template.MVEX__Header_Type__c == 'Image') {
                    templateData.put('isImageUrl', true);
                }
                else if (template.MVEX__Header_Type__c == 'Video') {
                    templateData.put('isImageUrl', true);
                }
                else if (template.MVEX__Header_Type__c == 'Document') {
                    templateData.put('isImageUrl', true);
                }

                templateData.put('template', template);
                templateData.put('headerParams', headerVariables);
                templateData.put('bodyParams', bodyVariables);
                templateData.put('template', templates[0]);
                return templateData;
            } else if (templates.size() > 0 && templates[0].MVEX__Template_Variable__c < 1){
                MVEX__WhatsappTemplate__c template = templates[0];
                if (template.MVEX__Header_Type__c == 'Image') {
                    templateData.put('isImageUrl', true);
                }
                else if (template.MVEX__Header_Type__c == 'Video') {
                    templateData.put('isImageUrl', true);
                }
                else if (template.MVEX__Header_Type__c == 'Document') {
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

            MVEX__WhatsappTemplate__c template = (MVEX__WhatsappTemplate__c)templateData.get('template');
            if (template == null || String.isBlank(template.MVEX__WBTemplate_Body__c)) {
                return null;
            }

            String payload = template.MVEX__WBTemplate_Body__c;

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
        List<MVEX__Chat__c> chats = [SELECT Id, MVEX__WhatsAppMessageId__c, MVEX__Message_Status__c FROM MVEX__Chat__c WHERE Id IN :messageIds WITH USER_MODE];
        String accessToken = (wbConfig.MVEX__Access_Token_1__c != null ? wbConfig.MVEX__Access_Token_1__c : '') + (wbConfig.MVEX__Access_Token_2__c != null ? wbConfig.MVEX__Access_Token_2__c : '');
        String endpoint = wbConfig.MVEX__whatsapp_endpoint__c + '/' + wbConfig.MVEX__APIVersion__c + '/' + wbConfig.MVEX__Whatsapp_Phone_Number_Id__c + '/messages';
        
        List<Map<String, Object>> errorLogs = new List<Map<String, Object>>();
        Integer successCount = 0;

        try {
            // First, complete all callouts and collect errors
            for (MVEX__Chat__c chat : chats) {
                // Skip messages without a valid WhatsApp Message ID
                if (String.isBlank(chat.MVEX__WhatsAppMessageId__c)) {
                    continue;
                }
                
                String payload = JSON.serialize(new Map<String, Object>{
                    'messaging_product' => 'whatsapp',
                    'status' => 'read',
                    'message_id' => chat.MVEX__WhatsAppMessageId__c
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
                    chat.MVEX__Message_Status__c = 'Seen';
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
    @return          : chat - {MVEX__Chat__c} - the newly created chat
    ********************************************************
    */
    @AuraEnabled
    public static MVEX__Chat__c createChatForAWSFiles(Map<String, String> chatData ){
        try {

            String message = chatData.get('message');
            String fileName = chatData.get('fileName');
            String mimeType = chatData.get('mimeType');
            String messageType = chatData.get('messageType');
            String recordId = chatData.get('recordId');
            String replyToChatId = chatData.get('replyToChatId');
            String phoneNumber = chatData.get('phoneNumber');

            MVEX__Chat__c chat = new MVEX__Chat__c();
            chat.MVEX__Message__c = message;
            chat.MVEX__Phone__c = phoneNumber;
            chat.MVEX__Type_of_Message__c	= 'OutBound Messages';
            chat.MVEX__Message_Status__c = null;
            chat.MVEX__Message_Type__c = messageType;
            chat.MVEX__Reply_To__c = replyToChatId;
            Map<String, Object> fileData = new Map<String, Object>{ 'fileName' => fileName, 'mimeType' => mimeType };
            chat.MVEX__File_Data__c = JSON.serialize(fileData);

            insert as user chat;
            chat = [SELECT Id, MVEX__Type_of_Message__c, MVEX__WhatsAppMessageId__c, MVEX__Message__c, MVEX__Message_Status__c, MVEX__Message_Type__c, MVEX__Reply_To__c, MVEX__Reaction__c, MVEX__WhatsappTemplate__c, MVEX__WhatsappTemplate__r.MVEX__Template_Name__c, CreatedDate, MVEX__Last_Interaction_Date__c, MVEX__File_Data__c FROM MVEX__Chat__c WHERE Id =:chat.Id WITH USER_MODE];

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

            List<MVEX__Chat__c> chatRecs = [SELECT MVEX__Sent_Template_Details__c FROM MVEX__Chat__c WHERE Id = :chatId WITH USER_MODE];
            if(chatRecs.size() > 0){
                String templateMergeDetails = chatRecs[0].MVEX__Sent_Template_Details__c;
                if(String.isNotBlank(templateMergeDetails)){
                    // Store just the raw JSON string so LWC doesn't need to navigate
                    // SObject field names (which vary by namespace context)
                    templateData.put('templateMergeDetails', chatRecs[0]);
                    templateData.put('sentTemplateDetails', templateMergeDetails);
                }
            }

            List<MVEX__WhatsappTemplate__c> templates = [SELECT Id, MVEX__Template_Name__c, MVEX__WBButton_Body__c, MVEX__Button_Label__c, MVEX__Button_Type__c, 
                                                            MVEX__WBFooter_Body__c, MVEX__WBHeader_Body__c, MVEX__Header_Type__c, MVEX__Language__c, 
                                                            MVEX__WBTemplate_Body__c, MVEX__Template_Category__c, MVEX__Template_SubCatagory__c, 
                                                            MVEX__Template_Miscellaneous_Data__c, MVEX__Template_Type__c, MVEX__Template_Variable__c, 
                                                            (SELECT Id, Name, MVEX__Field_Name__c, MVEX__Object_Name__c, MVEX__Type__c, MVEX__Alternate_Text__c FROM 
                                                            MVEX__WB_Template_Variables__r) FROM MVEX__WhatsappTemplate__c WHERE Id = :templateId WITH USER_MODE 
                                                            ORDER BY CreatedDate DESC];

            if(templates.size() > 0){
                MVEX__WhatsappTemplate__c template = templates[0];
                if (template.MVEX__Header_Type__c == 'Image') {
                    templateData.put('isImageUrl', true);
                }
                else if (template.MVEX__Header_Type__c == 'Video') {
                    templateData.put('isImageUrl', true);
                }
                else if (template.MVEX__Header_Type__c == 'Document') {
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

    /*
    *********************************************************
    @description     : Lightweight method to fetch only the templates for a given object type.
                       Called from the ChatWindow LWC when a platform event signals that
                       template data has changed (insert, update, delete, undelete) so the
                       component can refresh its template list without re-fetching all chats.
    @param           : objectApiName - {String} - API name of the current record object
    @return          : List<MVEX__WhatsappTemplate__c> - List of available templates
    *********************************************************
    */
    @AuraEnabled
    public static List<MVEX__WhatsappTemplate__c> getTemplatesOnly(String objectApiName) {
        try {
            Set<Id> matchingTemplateIds = new Set<Id>();
            Set<Id> allTemplateIdsWithVariables = new Set<Id>();
            Map<Id, Set<String>> templateIdToObjectNames = new Map<Id, Set<String>>();
            for (MVEX__Template_Variable__c tv : [
                SELECT MVEX__WhatsappTemplate__c, MVEX__Object_Name__c, MVEX__WhatsappTemplate__r.MVEX__Status__c
                FROM MVEX__Template_Variable__c
            ]) {
                allTemplateIdsWithVariables.add(tv.MVEX__WhatsappTemplate__c);
                if (tv.MVEX__WhatsappTemplate__r.MVEX__Status__c == 'Active-Quality Pending') {
                    if (!templateIdToObjectNames.containsKey(tv.MVEX__WhatsappTemplate__c)) {
                        templateIdToObjectNames.put(tv.MVEX__WhatsappTemplate__c, new Set<String>());
                    }
                    templateIdToObjectNames.get(tv.MVEX__WhatsappTemplate__c).add(tv.MVEX__Object_Name__c);
                }
            }
            for (Id templateId : templateIdToObjectNames.keySet()) {
                Set<String> objectNames = templateIdToObjectNames.get(templateId);
                if (objectNames.size() == 1 && objectNames.contains(objectApiName)) {
                    matchingTemplateIds.add(templateId);
                }
            }

            return [
                SELECT Id, Name, MVEX__Template_Name__c, MVEX__Template_Type__c
                FROM MVEX__WhatsappTemplate__c
                WHERE Id IN :matchingTemplateIds
                   OR (MVEX__Status__c = 'Active-Quality Pending' AND Id NOT IN :allTemplateIdsWithVariables)
                   OR MVEX__Template_Type__c = 'Interactive Message'
                WITH USER_MODE
                ORDER BY LastModifiedDate DESC
            ];
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'ChatWindowController', 'getTemplatesOnly', e.getMessage());
            return new List<MVEX__WhatsappTemplate__c>();
        }
    }

}