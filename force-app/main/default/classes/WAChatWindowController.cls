/**
 * @description       : Controller for the waChatWindow LWC component.
 *                      Handles fetching chats, templates, sending WhatsApp messages via Meta Graph API,
 *                      handling attachments, reactions, and status updates using OAuth_Configuration__mdt,
 *                      MVEX__Object_Config__mdt, WA_Chat__c, WA_Template__c, and WA_Template_Variable__c.
 * @author            : EstateXpert Team
 * @last modified on  : 14/10/2026
 **/
public with sharing class WAChatWindowController {    
    /**
     * @description : Retrieves the configured Contact phone field from MVEX__ChatWindowConfigInfo__c in MVEX__Object_Config__mdt
     * @return String - API name of the configured phone field on Contact
     */
    private static String getContactPhoneField() {
        try {
            List<MVEX__Object_Config__mdt> configList = [SELECT Id, MVEX__ChatWindowConfigInfo__c FROM MVEX__Object_Config__mdt WITH USER_MODE LIMIT 1];

            if (configList.isEmpty() || String.isBlank(configList[0].MVEX__ChatWindowConfigInfo__c)) {
                return null;
            }

            Map<String, Object> chatConfigMap = (Map<String, Object>) JSON.deserializeUntyped(configList[0].MVEX__ChatWindowConfigInfo__c);
            if (chatConfigMap != null) {
                Object contactEntry = null;
                for (String key : chatConfigMap.keySet()) {
                    if (key.equalsIgnoreCase('Contact')) {
                        contactEntry = chatConfigMap.get(key);
                        break;
                    }
                }

                String phoneField = null;
                if (contactEntry instanceof Map<String, Object>) {
                    Map<String, Object> entryMap = (Map<String, Object>) contactEntry;
                    if (entryMap.containsKey('phoneField') && entryMap.get('phoneField') != null) {
                        phoneField = String.valueOf(entryMap.get('phoneField')).trim();
                    }
                } else if (contactEntry instanceof String && String.isNotBlank(String.valueOf(contactEntry))) {
                    phoneField = String.valueOf(contactEntry).trim();
                }

                if (String.isNotBlank(phoneField)) {
                    Schema.DescribeSObjectResult describeResult = Contact.SObjectType.getDescribe();
                    if (describeResult.fields.getMap().containsKey(phoneField.toLowerCase())) {
                        return phoneField;
                    }
                }
            }
        } catch (Exception e) {
            System.debug('Error in getContactPhoneField: ' + e.getMessage());
        }
        return null;
    }

    /**
     * @description : Fetches all chat history and available templates for the given Contact record
     * @param contactId - Id of the Contact record
     * @return Map<String, Object>
     */
    @AuraEnabled
    public static Map<String, Object> getCombinedData(String contactId) {
        Map<String, Object> combinedData = new Map<String, Object>();
        try {
            List<WA_Chat__c> chats = new List<WA_Chat__c>();
            List<WA_Template__c> templates = new List<WA_Template__c>();

            String phoneField = getContactPhoneField();
            sObject recordData;
            String phoneNumber = '';
            String recordName = '';

            Set<String> queryFields = new Set<String>{ 'Id', 'Name' };
            if (String.isNotBlank(phoneField)) {
                queryFields.add(phoneField);
            }

            if (String.isNotBlank(contactId)) {
                String query = 'SELECT ' + String.join(new List<String>(queryFields), ', ') + 
                               ' FROM Contact WHERE Id = :contactId LIMIT 1';
                List<sObject> recs = Database.query(query, AccessLevel.USER_MODE);
                if (!recs.isEmpty()) {
                    recordData = recs[0];
                    if (String.isNotBlank(phoneField) && recordData.get(phoneField) != null) {
                        phoneNumber = String.valueOf(recordData.get(phoneField));
                    }
                    if (recordData.get('Name') != null) {
                        recordName = String.valueOf(recordData.get('Name'));
                    }
                }
            }

            if (String.isNotBlank(phoneNumber)) {
                Set<String> phoneCandidates = getPhoneCandidates(phoneNumber);

                chats = [SELECT Id, Type_of_Message__c, Message_ID__c, Message__c, Message_Status__c, Message_Type__c, Reply_to__c, Reaction__c, WA_Template__c, 
                           WA_Template__r.Template_Name__c, WA_Template__r.Header_Type__c, WA_Template__r.Header_Body__c, WA_Template__r.Template_Body__c, 
                           WA_Template__r.Footer_Body__c, WA_Template__r.Button_Body__c, WA_Template__r.Image_Header_Handle__c, CreatedDate, Phone__c, Normalize_Phone__c, File_Data__c, 
                           Sent_Template_Details__c FROM WA_Chat__c 
                           WHERE (Phone__c IN :phoneCandidates OR Normalize_Phone__c IN :phoneCandidates OR (Contact__c != null AND Contact__c = :contactId)) 
                           WITH USER_MODE ORDER BY CreatedDate ASC];
            } else if (String.isNotBlank(contactId)) {
                chats = [SELECT Id, Type_of_Message__c, Message_ID__c, Message__c, Message_Status__c, Message_Type__c, Reply_to__c, Reaction__c, WA_Template__c, 
                            WA_Template__r.Template_Name__c, WA_Template__r.Header_Type__c, WA_Template__r.Header_Body__c, WA_Template__r.Template_Body__c, 
                            WA_Template__r.Footer_Body__c, WA_Template__r.Button_Body__c, WA_Template__r.Image_Header_Handle__c, CreatedDate, Phone__c, Normalize_Phone__c, File_Data__c, 
                            Sent_Template_Details__c FROM WA_Chat__c WHERE Contact__c = :contactId WITH USER_MODE ORDER BY CreatedDate ASC];
            }

            // Fetch eligible templates
            Set<Id> matchingTemplateIds = new Set<Id>();
            Map<Id, Set<String>> templateIdToObjectNames = new Map<Id, Set<String>>();
            Set<Id> allTemplatesWithVariables = new Set<Id>();

            for (WA_Template_Variable__c tv : [SELECT WA_Template__c, Object_Name__c, WA_Template__r.Status__c FROM WA_Template_Variable__c WHERE WA_Template__c != null WITH USER_MODE]) {
                allTemplatesWithVariables.add(tv.WA_Template__c);
                if (tv.WA_Template__r.Status__c == 'Active-Quality Pending' && String.isNotBlank(tv.Object_Name__c)) {
                    if (!templateIdToObjectNames.containsKey(tv.WA_Template__c)) {
                        templateIdToObjectNames.put(tv.WA_Template__c, new Set<String>());
                    }
                    templateIdToObjectNames.get(tv.WA_Template__c).add(tv.Object_Name__c);
                }
            }

            for (Id templateId : templateIdToObjectNames.keySet()) {
                Set<String> objectNames = templateIdToObjectNames.get(templateId);
                if (objectNames.size() == 1 && objectNames.contains('Contact')) {
                    matchingTemplateIds.add(templateId);
                }
            }

            if (!matchingTemplateIds.isEmpty()) {
                templates.addAll([SELECT Id, Name, Template_Name__c, Header_Type__c, Template_Category__c, Language__c, Status__c FROM WA_Template__c 
                                    WHERE Id IN :matchingTemplateIds WITH USER_MODE ORDER BY LastModifiedDate DESC]);
            }

            List<WA_Template__c> templatesWithoutVariables = [SELECT Id, Name, Template_Name__c, Header_Type__c, Template_Category__c, Language__c, Status__c 
                                                                FROM WA_Template__c WHERE Status__c = 'Active-Quality Pending' AND Id NOT IN :allTemplatesWithVariables 
                                                                WITH USER_MODE ORDER BY LastModifiedDate DESC];
            templates.addAll(templatesWithoutVariables);

            // Deduplicate templates
            Map<Id, WA_Template__c> templateById = new Map<Id, WA_Template__c>();
            for (WA_Template__c t : templates) {
                templateById.put(t.Id, t);
            }
            templates = templateById.values();

            combinedData.put('chats', chats);
            combinedData.put('templates', templates);
            combinedData.put('record', recordData);
            combinedData.put('phoneNumber', phoneNumber);
            combinedData.put('recordName', recordName);
            combinedData.put('phoneField', phoneField);
        } catch (Exception e) {
            combinedData.put('error', e.getMessage());
            ErrorHandler.insertErrordata(e, 'WAChatWindowController', 'getCombinedData', e.getMessage());
        }
        return combinedData;
    }

    /**
     * @description : Method to create a new chat message
     * @param chatData - Map containing message details
     * @return WA_Chat__c - Created chat record
     */
    @AuraEnabled
    public static WA_Chat__c createChat(Map<String, String> chatData) {
        try {
            String message = chatData.get('message');
            String templateId = chatData.get('templateId');
            String messageType = chatData.get('messageType');
            String recordId = chatData.get('recordId');
            String replyToChatId = chatData.get('replyToChatId');
            String phoneNumber = chatData.get('phoneNumber');
            String objectName = chatData.get('objectName');

            WA_Chat__c chat = new WA_Chat__c();
            chat.Message__c = message;
            chat.WA_Template__c = templateId;
            chat.Phone__c = phoneNumber;
            chat.Normalize_Phone__c = normalizePhoneNumber(phoneNumber);
            chat.Type_of_Message__c = 'Outbound Messages';
            chat.Message_Status__c = null;
            chat.Message_Type__c = messageType;
            chat.Reply_to__c = replyToChatId;
            if (objectName == 'Contact' && String.isNotBlank(recordId)) {
                chat.Contact__c = recordId;
            }

            if (messageType == 'Image' || messageType == 'Document' || messageType == 'Video' || messageType == 'Audio') {
                List<ContentVersion> cv = [SELECT Id, ContentSize, Title, ContentDocumentId FROM ContentVersion WHERE Id = :message WITH USER_MODE];
                if (cv.isEmpty()) {
                    return null;
                }
                if (cv[0].ContentSize > 5000000) {
                    ContentDocument cd = new ContentDocument(Id = cv[0].ContentDocumentId);
                    delete as user cd;
                    throw new AuraHandledException('FILE_SIZE_EXCEEDED');
                }
                ContentDistribution cd = new ContentDistribution();
                cd.Name = cv[0].Title;
                cd.ContentVersionId = message;
                cd.PreferencesAllowViewInBrowser = true;
                cd.PreferencesLinkLatestVersion = true;
                cd.PreferencesNotifyOnVisit = false;
                cd.PreferencesPasswordRequired = false;
                cd.PreferencesAllowOriginalDownload = true;
                insert as user cd;

                chat.Message__c = [SELECT ContentDownloadUrl FROM ContentDistribution WHERE Id = :cd.Id WITH USER_MODE].ContentDownloadUrl;
                Map<String, Object> fileData = new Map<String, Object>{ 'fileName' => cv[0].Title, 'documentId' => cv[0].ContentDocumentId, 'contentVersionId' => message };
                chat.File_Data__c = JSON.serialize(fileData);
            }

            insert as user chat;

            chat = [SELECT Id, Type_of_Message__c, Message_ID__c, Message__c, Message_Status__c, Message_Type__c, Reply_to__c, Reaction__c, WA_Template__c, 
                        WA_Template__r.Template_Name__c, WA_Template__r.Header_Type__c, WA_Template__r.Header_Body__c, WA_Template__r.Template_Body__c, 
                        WA_Template__r.Footer_Body__c, WA_Template__r.Button_Body__c, WA_Template__r.Image_Header_Handle__c, CreatedDate, Phone__c, Normalize_Phone__c, File_Data__c, 
                        Sent_Template_Details__c FROM WA_Chat__c WHERE Id = :chat.Id WITH USER_MODE];
            return chat;
        } catch (Exception e) {
            if (e.getMessage().contains('STORAGE_LIMIT_EXCEEDED')) {
                ErrorHandler.insertErrordata(e, 'WAChatWindowController', 'createChat', 'STORAGE_LIMIT_EXCEEDED');
                throw new AuraHandledException('STORAGE_LIMIT_EXCEEDED');
            }
            ErrorHandler.insertErrordata(e, 'WAChatWindowController', 'createChat', e.getMessage());
            return null;
        }
    }

    /**
     * @description : Method to update the reaction on a chat message
     * @param chatId - Id of the chat
     * @param reaction - Emoji reaction string
     * @return WA_Chat__c
     */
    @AuraEnabled
    public static WA_Chat__c updateReaction(String chatId, String reaction) {
        try {
            WA_Chat__c chat = new WA_Chat__c();
            chat.Id = chatId;
            chat.Reaction__c = reaction;
            update as user chat;
            return chat;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WAChatWindowController', 'updateReaction', e.getMessage());
            return null;
        }
    }

    /**
     * @description : Method to send WhatsApp messages via Meta Graph API
     * @param jsonData - JSON payload for WhatsApp Cloud API
     * @param chatId - Id of related WA_Chat__c record
     * @param isReaction - Flag indicating whether message is a reaction
     * @param reaction - Reaction string
     * @return Map<String, Object>
     */
    @AuraEnabled
    public static Map<String, Object> sendWhatsappMessage(String jsonData, String chatId, Boolean isReaction, String reaction) {
        Map<String, Object> resultMap = new Map<String, Object>();
        WA_Chat__c chat = new WA_Chat__c(Id = chatId);
        try {
            resultMap.put('errorMessage', null);
            OAuth_Configuration__mdt config = WhatsappConnectController.getConfig();

            if (config == null || String.isBlank(config.Access_Token__c) || String.isBlank(config.Client_Phone_Number_ID__c)) {
                if (!isReaction) {
                    chat.Message_Status__c = 'Failed';
                } else if (reaction != null && reaction.contains('<|USER|>')) {
                    chat.Reaction__c = '<|USER|>' + reaction.substringAfter('<|USER|>');
                }
                update as user chat;
                resultMap.put('errorMessage', 'CUSTOM_SETTING_ERROR');
                resultMap.put('chat', chat);
                return resultMap;
            }

            String accessToken = config.Access_Token__c;
            String authEndpoint = config.Authorization_Endpoint__c != null ? config.Authorization_Endpoint__c.removeEnd('/') : 'https://graph.facebook.com';
            String apiVersion = config.API_Version__c != null ? config.API_Version__c : 'v26.0';
            String endpoint = authEndpoint + '/' + apiVersion + '/' + config.Client_Phone_Number_ID__c + '/messages';

            HttpRequest httpReq = new HttpRequest();
            httpReq.setEndpoint(endpoint);
            httpReq.setMethod('POST');
            httpReq.setHeader('Content-Type', 'application/json');
            httpReq.setHeader('Authorization', 'Bearer ' + accessToken);
            httpReq.setBody(jsonData);

            Http http = new Http();
            HttpResponse response = http.send(httpReq);
            Integer statusCode = response.getStatusCode();

            if (response != null && statusCode == 200) {
                String responseBody = response.getBody();
                Map<String, Object> jsonMap = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
                List<Object> messages = (List<Object>) jsonMap.get('messages');
                if (messages != null && !messages.isEmpty()) {
                    Map<String, Object> firstMessage = (Map<String, Object>) messages[0];
                    String whatsAppMessageID = (String) firstMessage.get('id');
                    if (!isReaction) {
                        chat.Message_ID__c = whatsAppMessageID;
                        chat.Message_Status__c = 'Sent';
                    }
                }
            } else {
                if (!isReaction) {
                    chat.Message_Status__c = 'Failed';
                }
                ErrorHandler.insertErrordata(null, 'WAChatWindowController', 'sendWhatsappMessage', 'API Exception sending message: ' + (response != null ? response.getBody() : 'No response'));
            }

            // Persist template components if applicable
            Map<String, Object> jsonMap = (Map<String, Object>) JSON.deserializeUntyped(jsonData);
            if (jsonMap.containsKey('template')) {
                Map<String, Object> templateMap = (Map<String, Object>) jsonMap.get('template');
                if (templateMap != null && templateMap.containsKey('components')) {
                    List<Object> componentsList = (List<Object>) templateMap.get('components');
                    chat.Sent_Template_Details__c = JSON.serialize(componentsList);
                }
            } else if (jsonMap.containsKey('interactive')) {
                chat.Sent_Template_Details__c = jsonData;
            }

            update as user chat;
            chat = [SELECT Id, Type_of_Message__c, Message_ID__c, Message__c, Message_Status__c, Message_Type__c, Reply_to__c, Reaction__c, WA_Template__c, 
                        WA_Template__r.Template_Name__c, WA_Template__r.Header_Type__c, WA_Template__r.Header_Body__c, WA_Template__r.Template_Body__c, 
                        WA_Template__r.Footer_Body__c, WA_Template__r.Button_Body__c, WA_Template__r.Image_Header_Handle__c, CreatedDate, Sent_Template_Details__c 
                        FROM WA_Chat__c WHERE Id = :chat.Id WITH USER_MODE];
            resultMap.put('chat', chat);
            return resultMap;

        } catch (Exception e) {
            if (!isReaction) {
                chat.Message_Status__c = 'Failed';
                try {
                    update as user chat;
                } catch (Exception ue) {}
            }
            ErrorHandler.insertErrordata(e, 'WAChatWindowController', 'sendWhatsappMessage', e.getMessage());
        }
        resultMap.put('chat', chat);
        return resultMap;
    }

    /**
     * @description : Method to fetch template data and resolved merge fields
     * @param templateId - Id of the WA_Template__c record
     * @param contactId - Id of the record to resolve variables
     * @return Map<String, Object>
     */
    @AuraEnabled
    public static Map<String, Object> getTemplateData(String templateId, String contactId) {
        try {
            Map<String, Object> templateData = new Map<String, Object>();
            List<WA_Template__c> templates = [SELECT Id, Template_Name__c, Template_Miscellaneous_Data__c, Button_Body__c, Button_Label__c, 
                                                Button_Type__c, Footer_Body__c, Header_Body__c, Header_Type__c, Language__c, 
                                                Template_Body__c, Template_Category__c, Template_Variable_Count__c,
                                                (SELECT Id, Name, Field_Name__c, Object_Name__c, Type__c, Alternate_Text__c FROM WA_Template_Variables__r) 
                                                FROM WA_Template__c WHERE Id = :templateId WITH USER_MODE LIMIT 1];

            if (templates.isEmpty()) {
                return null;
            }

            WA_Template__c template = templates[0];
            if (template.Header_Type__c == 'Image' || template.Header_Type__c == 'Video' || template.Header_Type__c == 'Document') {
                templateData.put('isImageUrl', true);
            }

            List<Object> headerVariables = new List<Object>();
            List<Object> bodyVariables = new List<Object>();

            if (template.WA_Template_Variables__r != null && !template.WA_Template_Variables__r.isEmpty() && String.isNotBlank(contactId)) {
                Set<String> fieldSelectionCause = new Set<String>();
                for (WA_Template_Variable__c tv : template.WA_Template_Variables__r) {
                    if (String.isNotBlank(tv.Field_Name__c)) {
                        fieldSelectionCause.add(tv.Field_Name__c);
                    }
                }

                if (!fieldSelectionCause.isEmpty()) {
                    String query = 'SELECT ' + String.join(new List<String>(fieldSelectionCause), ', ') + 
                                   ' FROM Contact WHERE Id = :contactId LIMIT 1';
                    List<sObject> records = Database.query(query, AccessLevel.USER_MODE);
                    if (!records.isEmpty()) {
                        sObject record = records[0];
                        for (WA_Template_Variable__c tv : template.WA_Template_Variables__r) {
                            Object valueToReplace = getFieldValue(record, tv.Field_Name__c);
                            String repVal = valueToReplace != null ? String.valueOf(valueToReplace) : (tv.Alternate_Text__c != null ? tv.Alternate_Text__c : '');
                            if (tv.Type__c == 'Header') {
                                headerVariables.add(repVal);
                                if (String.isNotBlank(template.Header_Body__c)) {
                                    template.Header_Body__c = template.Header_Body__c.replace(tv.Name, repVal);
                                }
                            } else if (tv.Type__c == 'Body') {
                                bodyVariables.add(repVal);
                                if (String.isNotBlank(template.Template_Body__c)) {
                                    template.Template_Body__c = template.Template_Body__c.replace(tv.Name, repVal);
                                }
                            }
                        }
                    }
                }
            }

            templateData.put('template', template);
            templateData.put('headerParams', headerVariables);
            templateData.put('bodyParams', bodyVariables);
            return templateData;

        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WAChatWindowController', 'getTemplateData', e.getMessage());
            return null;
        }
    }

    /**
     * @description : Builds and dispatches a WhatsApp template message directly from the Chat Window
     * @param templateId - Id of the WA_Template__c
     * @param recordId - Record Id (e.g., Contact or Lead Id)
     * @param phoneNumber - Recipient phone number
     * @return Map<String, Object> - result containing newly created WA_Chat__c record
     */
    @AuraEnabled
    public static Map<String, Object> sendSelectedTemplate(String templateId, String recordId, String phoneNumber) {
        Map<String, Object> result = new Map<String, Object>();
        try {
            if (String.isBlank(templateId) || String.isBlank(phoneNumber)) {
                result.put('success', false);
                result.put('message', 'Template Id and Phone Number are required.');
                return result;
            }

            Map<String, Object> templateData = getTemplateData(templateId, recordId);
            if (templateData == null || !templateData.containsKey('template')) {
                result.put('success', false);
                result.put('message', 'Template not found.');
                return result;
            }

            WA_Template__c template = (WA_Template__c) templateData.get('template');
            List<Object> headerParams = (List<Object>) templateData.get('headerParams');
            List<Object> bodyParams = (List<Object>) templateData.get('bodyParams');

            // Build components list
            List<Map<String, Object>> components = new List<Map<String, Object>>();

            // Header component
            if (headerParams != null && !headerParams.isEmpty()) {
                List<Map<String, Object>> hParams = new List<Map<String, Object>>();
                for (Object param : headerParams) {
                    hParams.add(new Map<String, Object>{ 'type' => 'text', 'text' => String.valueOf(param) });
                }
                components.add(new Map<String, Object>{ 'type' => 'header', 'parameters' => hParams });
            }

            // Body component
            if (bodyParams != null && !bodyParams.isEmpty()) {
                List<Map<String, Object>> bParams = new List<Map<String, Object>>();
                for (Object param : bodyParams) {
                    bParams.add(new Map<String, Object>{ 'type' => 'text', 'text' => String.valueOf(param) });
                }
                components.add(new Map<String, Object>{ 'type' => 'body', 'parameters' => bParams });
            }

            String lang = String.isNotBlank(template.Language__c) ? template.Language__c : 'en_US';
            String normalizedPhone = phoneNumber.replaceAll('[^0-9]', '');

            Map<String, Object> templatePayload = new Map<String, Object>{
                'messaging_product' => 'whatsapp',
                'to' => normalizedPhone,
                'type' => 'template',
                'template' => new Map<String, Object>{
                    'name' => template.Template_Name__c,
                    'language' => new Map<String, Object>{ 'code' => lang },
                    'components' => components
                }
            };

            String jsonPayload = JSON.serialize(templatePayload);

            // 1. MAKE HTTP CALLOUT FIRST (NO DML BEFORE THIS CALLOUT)
            OAuth_Configuration__mdt config = WhatsappConnectController.getConfig();
            if (config == null || String.isBlank(config.Access_Token__c) || String.isBlank(config.Client_Phone_Number_ID__c)) {
                result.put('success', false);
                result.put('message', 'WhatsApp OAuth configuration not found or access token is missing.');
                return result;
            }

            String accessToken = config.Access_Token__c;
            String authEndpoint = config.Authorization_Endpoint__c != null ? config.Authorization_Endpoint__c.removeEnd('/') : 'https://graph.facebook.com';
            String apiVersion = config.API_Version__c != null ? config.API_Version__c : 'v26.0';
            String endpoint = authEndpoint + '/' + apiVersion + '/' + config.Client_Phone_Number_ID__c + '/messages';

            HttpRequest httpReq = new HttpRequest();
            httpReq.setEndpoint(endpoint);
            httpReq.setMethod('POST');
            httpReq.setHeader('Content-Type', 'application/json');
            httpReq.setHeader('Authorization', 'Bearer ' + accessToken);
            httpReq.setBody(jsonPayload);

            Http http = new Http();
            HttpResponse response = http.send(httpReq);
            System.debug('Template status: ' + response.getStatusCode());
            System.debug('Template response: ' + response.getBody());
            Integer statusCode = response != null ? response.getStatusCode() : 0;
            String whatsAppMessageID = null;
            Boolean isCalloutSuccess = (statusCode == 200);

            if (isCalloutSuccess) {
                Map<String, Object> jsonMap = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                List<Object> messages = (List<Object>) jsonMap.get('messages');
                if (messages != null && !messages.isEmpty()) {
                    Map<String, Object> firstMsg = (Map<String, Object>) messages[0];
                    whatsAppMessageID = (String) firstMsg.get('id');
                }
            }

            // 2. NOW PERFORM DML (AFTER CALLOUT HAS COMPLETED)
            WA_Chat__c chat = new WA_Chat__c();
            chat.Message__c = String.isNotBlank(template.Template_Body__c) ? template.Template_Body__c : template.Template_Name__c;
            chat.WA_Template__c = template.Id;
            chat.Phone__c = phoneNumber;
            chat.Normalize_Phone__c = normalizePhoneNumber(phoneNumber);
            chat.Type_of_Message__c = 'Outbound Messages';
            chat.Message_Type__c = 'Template';
            chat.Sent_Template_Details__c = JSON.serialize(components);
            chat.Message_ID__c = whatsAppMessageID;
            chat.Message_Status__c = isCalloutSuccess ? 'Sent' : 'Failed';
            chat.Contact__c = recordId;

            insert as user chat;

            // Re-query chat with complete template relationship fields for UI
            chat = [SELECT Id, Type_of_Message__c, Message_ID__c, Message__c, Message_Status__c, Message_Type__c, Reply_to__c, Reaction__c, WA_Template__c, 
                        WA_Template__r.Template_Name__c, WA_Template__r.Header_Type__c, WA_Template__r.Header_Body__c, WA_Template__r.Template_Body__c, 
                        WA_Template__r.Footer_Body__c, WA_Template__r.Button_Body__c, WA_Template__r.Image_Header_Handle__c, CreatedDate, Phone__c, Normalize_Phone__c, 
                        File_Data__c, Sent_Template_Details__c FROM WA_Chat__c WHERE Id = :chat.Id WITH USER_MODE];

            // 3. Log error if callout failed (safe to log after callout)
            if (!isCalloutSuccess) {
                String errorBody = response != null ? response.getBody() : 'No response from WhatsApp API';
                ErrorHandler.insertErrordata(null, 'WAChatWindowController', 'sendSelectedTemplate', 'API Exception sending template: ' + errorBody);
                result.put('success', false);
                result.put('message', 'Failed to send template. WhatsApp API returned status ' + statusCode + ': ' + errorBody);
                result.put('chat', chat);
                return result;
            }

            result.put('success', true);
            result.put('chat', chat);
            return result;

        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WAChatWindowController', 'sendSelectedTemplate', e.getMessage());
            result.put('success', false);
            result.put('message', e.getMessage());
            return result;
        }
    }

    /**
     * @description : Marks list of message IDs as read/seen via WhatsApp API
     * @param messageIds - List of WA_Chat__c Ids
     * @return Integer - Count of updated messages
     */
    @AuraEnabled
    public static Integer updateStatus(List<String> messageIds) {
        Integer successCount = 0;
        if (messageIds == null || messageIds.isEmpty()) {
            return successCount;
        }

        try {
            List<WA_Chat__c> chats = [SELECT Id, Message_ID__c, Message_Status__c FROM WA_Chat__c WHERE Id IN :messageIds WITH USER_MODE];
            OAuth_Configuration__mdt config = WhatsappConnectController.getConfig();
            if (config == null || String.isBlank(config.Access_Token__c) || String.isBlank(config.Client_Phone_Number_ID__c)) {
                return successCount;
            }

            String accessToken = config.Access_Token__c;
            String authEndpoint = config.Authorization_Endpoint__c != null ? config.Authorization_Endpoint__c.removeEnd('/') : 'https://graph.facebook.com';
            String apiVersion = config.API_Version__c != null ? config.API_Version__c : 'v26.0';
            String endpoint = authEndpoint + '/' + apiVersion + '/' + config.Client_Phone_Number_ID__c + '/messages';

            for (WA_Chat__c chat : chats) {
                if (String.isBlank(chat.Message_ID__c)) {
                    continue;
                }

                String payload = JSON.serialize(new Map<String, Object>{
                    'messaging_product' => 'whatsapp',
                    'status' => 'read',
                    'message_id' => chat.Message_ID__c
                });

                Http http = new Http();
                HttpRequest request = new HttpRequest();
                request.setEndpoint(endpoint);
                request.setMethod('POST');
                request.setHeader('Authorization', 'Bearer ' + accessToken);
                request.setHeader('Content-Type', 'application/json');
                request.setBody(payload);

                HttpResponse response = http.send(request);
                if (response != null && response.getStatusCode() == 200) {
                    chat.Message_Status__c = 'Seen';
                    successCount++;
                }
            }

            if (!chats.isEmpty()) {
                update as user chats;
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WAChatWindowController', 'updateStatus', e.getMessage());
        }

        return successCount;
    }

    /**
     * @description : Creates a new chat message for files stored in AWS S3
     * @param chatData - Map containing file details
     * @return WA_Chat__c
     */
    @AuraEnabled
    public static WA_Chat__c createChatForAWSFiles(Map<String, String> chatData) {
        try {
            String message = chatData.get('message');
            String fileName = chatData.get('fileName');
            String mimeType = chatData.get('mimeType');
            String messageType = chatData.get('messageType');
            String recordId = chatData.get('recordId');
            String replyToChatId = chatData.get('replyToChatId');
            String phoneNumber = chatData.get('phoneNumber');

            WA_Chat__c chat = new WA_Chat__c();
            chat.Message__c = message;
            chat.Phone__c = phoneNumber;
            chat.Normalize_Phone__c = normalizePhoneNumber(phoneNumber);
            chat.Type_of_Message__c = 'Outbound Messages';
            chat.Message_Status__c = null;
            chat.Message_Type__c = messageType;
            chat.Reply_to__c = replyToChatId;
            Map<String, Object> fileData = new Map<String, Object>{ 'fileName' => fileName, 'mimeType' => mimeType };
            chat.File_Data__c = JSON.serialize(fileData);

            insert as user chat;
            chat = [SELECT Id, Type_of_Message__c, Message_ID__c, Message__c, Message_Status__c, Message_Type__c, Reply_to__c, Reaction__c, WA_Template__c, 
                        WA_Template__r.Template_Name__c, CreatedDate, Phone__c, Normalize_Phone__c, File_Data__c FROM WA_Chat__c WHERE Id = :chat.Id WITH USER_MODE];

            return chat;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WAChatWindowController', 'createChatForAWSFiles', e.getMessage());
            return null;
        }
    }

    /**
     * @description : Retrieves template preview data for an existing chat message
     * @param templateId - Id of the WA_Template__c
     * @param chatId - Id of the WA_Chat__c
     * @return Map<String, Object>
     */
    @AuraEnabled
    public static Map<String, Object> getTemplatePreviewData(String templateId, String chatId) {
        try {
            Map<String, Object> templateData = new Map<String, Object>();

            if (String.isNotBlank(chatId)) {
                List<WA_Chat__c> chatRecs = [SELECT Sent_Template_Details__c FROM WA_Chat__c WHERE Id = :chatId WITH USER_MODE];
                if (!chatRecs.isEmpty() && String.isNotBlank(chatRecs[0].Sent_Template_Details__c)) {
                    templateData.put('templateMergeDetails', chatRecs[0]);
                    templateData.put('sentTemplateDetails', chatRecs[0].Sent_Template_Details__c);
                }
            }

            List<WA_Template__c> templates = [SELECT Id, Template_Name__c, Button_Body__c, Button_Label__c, Button_Type__c, Footer_Body__c, Header_Body__c, 
                                                Header_Type__c, Language__c, Template_Body__c, Template_Category__c, Template_Miscellaneous_Data__c, 
                                                Template_Variable_Count__c,(SELECT Id, Name, Field_Name__c, Object_Name__c, Type__c, Alternate_Text__c 
                                                FROM WA_Template_Variables__r) FROM WA_Template__c WHERE Id = :templateId WITH USER_MODE ORDER BY CreatedDate DESC LIMIT 1];

            if (!templates.isEmpty()) {
                WA_Template__c template = templates[0];
                if (template.Header_Type__c == 'Image' || template.Header_Type__c == 'Video' || template.Header_Type__c == 'Document') {
                    templateData.put('isImageUrl', true);
                }
                templateData.put('template', template);
                return templateData;
            }
            return null;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WAChatWindowController', 'getTemplatePreviewData', e.getMessage());
            return null;
        }
    }

    /**
     * @description : Resolves relationship field path on an SObject (e.g. Account.Owner.Name)
     * @param record - SObject record
     * @param fieldPath - Field path string
     * @return Object
     */
    public static Object getFieldValue(SObject record, String fieldPath) {
        try {
            if (record == null || String.isBlank(fieldPath)) {
                return null;
            }
            
            if (fieldPath.contains('.')) {
                List<String> fieldParts = fieldPath.split('\\.');
                SObject currentRecord = record;
                for (Integer i = 0; i < fieldParts.size() - 1; i++) {
                    currentRecord = currentRecord.getSObject(fieldParts[i]);
                    if (currentRecord == null) {
                        return null;
                    }
                }
                return currentRecord.get(fieldParts[fieldParts.size() - 1]);
            } else {
                return record.get(fieldPath);
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WAChatWindowController', 'getFieldValue', e.getMessage());
            return null;
        }
    }

    /**
     * @description : Lightweight method to fetch approved templates for a given object
     * @return List<WA_Template__c>
     */
    @AuraEnabled
    public static List<WA_Template__c> getTemplatesOnly() {
        try {
            Set<Id> matchingTemplateIds = new Set<Id>();
            Set<Id> allTemplateIdsWithVariables = new Set<Id>();
            Map<Id, Set<String>> templateIdToObjectNames = new Map<Id, Set<String>>();

            for (WA_Template_Variable__c tv : [SELECT WA_Template__c, Object_Name__c, WA_Template__r.Status__c FROM WA_Template_Variable__c WHERE WA_Template__c != null WITH USER_MODE]) {
                allTemplateIdsWithVariables.add(tv.WA_Template__c);
                if (tv.WA_Template__r.Status__c == 'Active-Quality Pending' && String.isNotBlank(tv.Object_Name__c)) {
                    if (!templateIdToObjectNames.containsKey(tv.WA_Template__c)) {
                        templateIdToObjectNames.put(tv.WA_Template__c, new Set<String>());
                    }
                    templateIdToObjectNames.get(tv.WA_Template__c).add(tv.Object_Name__c);
                }
            }

            for (Id templateId : templateIdToObjectNames.keySet()) {
                Set<String> objectNames = templateIdToObjectNames.get(templateId);
                if (objectNames.size() == 1 && objectNames.contains('Contact')) {
                    matchingTemplateIds.add(templateId);
                }
            }

            return [SELECT Id, Name, Template_Name__c, Header_Type__c, Template_Category__c, Language__c, Status__c FROM WA_Template__c WHERE Id IN :matchingTemplateIds 
                    OR (Status__c = 'Active-Quality Pending' AND Id NOT IN :allTemplateIdsWithVariables) WITH USER_MODE ORDER BY LastModifiedDate DESC];
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WAChatWindowController', 'getTemplatesOnly', e.getMessage());
            return new List<WA_Template__c>();
        }
    }

    /**
     * @description : Normalizes a phone number by removing all non-digit characters for matching
     * @param phoneNumber - Input phone number
     * @return String - Digits-only normalized phone number
     */
    public static String normalizePhoneNumber(String phoneNumber) {
        if (String.isBlank(phoneNumber)) {
            return '';
        }
        return phoneNumber.replaceAll('[^0-9]', '');
    }

    /**
     * @description : Generates candidate variations of a phone number (raw and characters removed) for matching
     * @param phoneNumber - Input phone number
     * @return Set<String> - Set of candidate phone variations
     */
    public static Set<String> getPhoneCandidates(String phoneNumber) {
        Set<String> candidates = new Set<String>();
        if (String.isNotBlank(phoneNumber)) {
            candidates.add(phoneNumber.trim());
            candidates.add(normalizePhoneNumber(phoneNumber));
        }
        candidates.remove('');
        return candidates;
    }
}