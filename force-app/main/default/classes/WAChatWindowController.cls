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
     * @description : Retrieves list of objects configured for WhatsApp Chat Window from MVEX__Object_Config__mdt
     * @return List<String>
     */
    @AuraEnabled
    public static List<String> getObjectPicklistOptions() {
        try {
            List<String> options = new List<String>();
            List<MVEX__Object_Config__mdt> objectConfigList = [SELECT MVEX__ChatWindowConfigInfo__c FROM MVEX__Object_Config__mdt WITH USER_MODE LIMIT 1];
            
            if (!objectConfigList.isEmpty() && String.isNotBlank(objectConfigList[0].MVEX__ChatWindowConfigInfo__c)) {
                Map<String, Object> chatConfigData = (Map<String, Object>) JSON.deserializeUntyped(objectConfigList[0].MVEX__ChatWindowConfigInfo__c);
                for (String key : chatConfigData.keySet()) {
                    options.add(key);
                }
            }
            return options;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WAChatWindowController', 'getObjectPicklistOptions', e.getMessage());
            return null;
        }
    }

    /**
     * @description : Resolves phoneField and nameField for a given object from MVEX__Object_Config__mdt custom metadata.
     *                Supports both map structure {"Contact": {"phoneField": "...", "nameField": "..."}}
     *                and string structure {"Contact": "MobilePhone"} as configured by whatsappConnectComp.
     * @param objectApiName - Name of the object (e.g. 'Contact')
     * @return Map<String, String> containing 'phoneField' and 'nameField'
     */
    public static Map<String, String> resolveObjectFields(String objectApiName) {
        Map<String, String> result = new Map<String, String>{
            'phoneField' => 'MobilePhone',
            'nameField' => 'Name'
        };

        if (String.isBlank(objectApiName)) {
            objectApiName = 'Contact';
        }

        try {
            List<MVEX__Object_Config__mdt> configList = [SELECT Id, MVEX__ObjectConfigInfo__c, MVEX__ChatWindowConfigInfo__c FROM MVEX__Object_Config__mdt 
                                                            WITH USER_MODE LIMIT 1];

            if (configList.isEmpty()) {
                return result;
            }

            MVEX__Object_Config__mdt cfg = configList[0];

            // 1. Check MVEX__ChatWindowConfigInfo__c
            if (String.isNotBlank(cfg.MVEX__ChatWindowConfigInfo__c)) {
                try {
                    Map<String, Object> chatConfigMap = (Map<String, Object>) JSON.deserializeUntyped(cfg.MVEX__ChatWindowConfigInfo__c);
                    if (chatConfigMap != null && chatConfigMap.containsKey(objectApiName)) {
                        Object objEntry = chatConfigMap.get(objectApiName);
                        if (objEntry instanceof Map<String, Object>) {
                            Map<String, Object> entryMap = (Map<String, Object>) objEntry;
                            if (entryMap.containsKey('phoneField') && entryMap.get('phoneField') != null) {
                                result.put('phoneField', String.valueOf(entryMap.get('phoneField')));
                            }
                            if (entryMap.containsKey('nameField') && entryMap.get('nameField') != null) {
                                result.put('nameField', String.valueOf(entryMap.get('nameField')));
                            }
                        } else if (objEntry instanceof String && String.isNotBlank(String.valueOf(objEntry))) {
                            result.put('phoneField', String.valueOf(objEntry));
                        }
                    }
                } catch (Exception ex) {
                    System.debug('Error parsing MVEX__ChatWindowConfigInfo__c: ' + ex.getMessage());
                }
            }

            // 2. Check MVEX__ObjectConfigInfo__c if phoneField is still blank or default
            if (String.isNotBlank(cfg.MVEX__ObjectConfigInfo__c)) {
                try {
                    Map<String, Object> objConfigMap = (Map<String, Object>) JSON.deserializeUntyped(cfg.MVEX__ObjectConfigInfo__c);
                    String configuredObj = (String) objConfigMap.get('object');
                    if (String.isBlank(configuredObj)) {
                        configuredObj = (String) objConfigMap.get('objectApiName');
                    }
                    if ((String.isBlank(configuredObj) || configuredObj.equalsIgnoreCase(objectApiName)) &&
                        objConfigMap.containsKey('phoneField') && objConfigMap.get('phoneField') != null) {
                        String pf = String.valueOf(objConfigMap.get('phoneField'));
                        if (String.isNotBlank(pf)) {
                            result.put('phoneField', pf);
                        }
                    }
                } catch (Exception ex) {
                    System.debug('Error parsing MVEX__ObjectConfigInfo__c: ' + ex.getMessage());
                }
            }

            // 3. Validate against SObject fields describe
            Schema.SObjectType sObjType = Schema.getGlobalDescribe().get(objectApiName);
            if (sObjType != null) {
                Map<String, Schema.SObjectField> fieldsMap = sObjType.getDescribe().fields.getMap();
                String resolvedPhone = result.get('phoneField');
                if (String.isNotBlank(resolvedPhone) && !fieldsMap.containsKey(resolvedPhone.toLowerCase())) {
                    if (fieldsMap.containsKey('mobilephone')) {
                        result.put('phoneField', 'MobilePhone');
                    } else if (fieldsMap.containsKey('phone')) {
                        result.put('phoneField', 'Phone');
                    }
                }
                String resolvedName = result.get('nameField');
                if (String.isNotBlank(resolvedName) && !fieldsMap.containsKey(resolvedName.toLowerCase()) && fieldsMap.containsKey('name')) {
                    result.put('nameField', 'Name');
                }
            }
        } catch (Exception e) {
            System.debug('Error in resolveObjectFields: ' + e.getMessage());
        }

        return result;
    }

    /**
     * @description : Retrieves contacts/records for the selected object with latest chat info and unread count
     * @param objectApiName - API name of the object (e.g., 'Contact', 'Lead')
     * @return Map<String, Map<String, Object>>
     */
    @AuraEnabled
    public static Map<String, Map<String, Object>> getChatsForSelectedObject(String objectApiName) {
        try {
            Map<String, String> fieldMapping = resolveObjectFields(objectApiName);
            String phoneField = fieldMapping.get('phoneField');
            String nameField = fieldMapping.get('nameField');

            List<sObject> recordData = new List<sObject>();
            if (String.isNotBlank(nameField) && String.isNotBlank(phoneField)) {
                String query = '';
                if (objectApiName == 'Lead') {
                    query = 'SELECT Id, ' + String.escapeSingleQuotes(nameField) + ', ' + String.escapeSingleQuotes(phoneField) + 
                            ' FROM ' + String.escapeSingleQuotes(objectApiName) + 
                            ' WHERE ' + String.escapeSingleQuotes(phoneField) + ' != null AND Status != \'Closed - Converted\' WITH USER_MODE LIMIT 50000';
                } else {
                    query = 'SELECT Id, ' + String.escapeSingleQuotes(nameField) + ', ' + String.escapeSingleQuotes(phoneField) + 
                            ' FROM ' + String.escapeSingleQuotes(objectApiName) + 
                            ' WHERE ' + String.escapeSingleQuotes(phoneField) + ' != null WITH USER_MODE LIMIT 50000';
                }
                recordData = Database.query(query);
            }
    
            Set<String> phoneSet = new Set<String>();
            for (sObject rec : recordData) {
                String phoneVal = (String) rec.get(phoneField);
                if (String.isNotBlank(phoneVal)) {
                    phoneSet.add(phoneVal);
                }
            }
    
            // Get last chat time per phone from WA_Chat__c
            Map<String, DateTime> phoneToLastChat = new Map<String, DateTime>();
            if (!phoneSet.isEmpty()) {
                List<AggregateResult> chatAgg = [SELECT Phone__c, MAX(CreatedDate) maxDate FROM WA_Chat__c WHERE Phone__c IN :phoneSet WITH USER_MODE GROUP BY Phone__c];
                for (AggregateResult ar : chatAgg) {
                    phoneToLastChat.put((String) ar.get('Phone__c'), (DateTime) ar.get('maxDate'));
                }
            }
    
            // Get count of unread inbound messages per phone
            Map<String, Integer> phoneToUnreadInboundCount = new Map<String, Integer>();
            if (!phoneSet.isEmpty()) {
                List<AggregateResult> unreadInboundAgg = [SELECT Phone__c, COUNT(Id) countId FROM WA_Chat__c WHERE Phone__c IN :phoneSet AND 
                                                                Message_Status__c != 'Seen' AND Type_of_Message__c = 'Inbound Messages' WITH USER_MODE GROUP BY Phone__c];
                for (AggregateResult ar : unreadInboundAgg) {
                    phoneToUnreadInboundCount.put((String) ar.get('Phone__c'), (Integer) ar.get('countId'));
                }
            }
    
            // Sort records by latest chat date descending
            recordData.sort(new RecordChatComparator(phoneToLastChat, phoneField));
    
            Map<String, Map<String, Object>> contactData = new Map<String, Map<String, Object>>();
            for (sObject rec : recordData) {
                Map<String, Object> contactDetails = new Map<String, Object>();
                String rPhone = (String) rec.get(phoneField);
                contactDetails.put('Id', (String) rec.get('Id'));
                contactDetails.put('Name', (String) rec.get(nameField));
                contactDetails.put('Phone', rPhone);
                contactDetails.put('unreadOutboundCount', phoneToUnreadInboundCount.containsKey(rPhone) ? phoneToUnreadInboundCount.get(rPhone) : 0);
                contactData.put((String) rec.get('Id'), contactDetails);
            }
    
            return contactData;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WAChatWindowController', 'getChatsForSelectedObject', e.getMessage());
            return null;
        }
    }

    // Inner comparator class for sorting contacts by chat date
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

            if (aDate > bDate) return -1;
            if (aDate < bDate) return 1;
            return 0;
        }
    }

    /**
     * @description : Fetches all chat history and available templates for the given record
     * @param contactId - Id of the record
     * @param objectApiName - API Name of the object
     * @return Map<String, Object>
     */
    @AuraEnabled
    public static Map<String, Object> getCombinedData(String contactId, String objectApiName) {
        Map<String, Object> combinedData = new Map<String, Object>();
        try {
            if (String.isBlank(objectApiName)) {
                objectApiName = 'Contact';
            }

            List<WA_Chat__c> chats = new List<WA_Chat__c>();
            List<WA_Template__c> templates = new List<WA_Template__c>();

            Map<String, String> fieldMapping = resolveObjectFields(objectApiName);
            String phoneField = fieldMapping.get('phoneField');
            String nameField = fieldMapping.get('nameField');

            sObject recordData;
            String phoneNumber = '';
            String recordName = '';

            Set<String> queryFields = new Set<String>{ 'Id' };
            if (String.isNotBlank(nameField)) {
                queryFields.add(nameField);
            } else {
                queryFields.add('Name');
            }
            if (String.isNotBlank(phoneField)) {
                queryFields.add(phoneField);
            }

            Schema.SObjectType sObjType = Schema.getGlobalDescribe().get(objectApiName);
            if (sObjType != null) {
                Map<String, Schema.SObjectField> fMap = sObjType.getDescribe().fields.getMap();
                if (fMap.containsKey('mobilephone')) queryFields.add('MobilePhone');
                if (fMap.containsKey('phone')) queryFields.add('Phone');
            }

            if (String.isNotBlank(contactId)) {
                String query = 'SELECT ' + String.join(new List<String>(queryFields), ', ') + 
                               ' FROM ' + String.escapeSingleQuotes(objectApiName) + ' WHERE Id = :contactId WITH USER_MODE LIMIT 1';
                List<sObject> recs = Database.query(query);
                if (!recs.isEmpty()) {
                    recordData = recs[0];
                    if (String.isNotBlank(phoneField) && recordData.get(phoneField) != null) {
                        phoneNumber = String.valueOf(recordData.get(phoneField));
                    }
                    if (String.isBlank(phoneNumber)) {
                        if (queryFields.contains('MobilePhone') && recordData.get('MobilePhone') != null) {
                            phoneNumber = String.valueOf(recordData.get('MobilePhone'));
                        } else if (queryFields.contains('Phone') && recordData.get('Phone') != null) {
                            phoneNumber = String.valueOf(recordData.get('Phone'));
                        }
                    }
                    if (String.isNotBlank(nameField) && recordData.get(nameField) != null) {
                        recordName = String.valueOf(recordData.get(nameField));
                    } else if (recordData.get('Name') != null) {
                        recordName = String.valueOf(recordData.get('Name'));
                    }
                }
            }

            if (String.isNotBlank(phoneNumber)) {
                String cleanPhone = phoneNumber.replaceAll('[\\s\\-\\(\\)\\.]+', '');
                String cleanWithPlus = cleanPhone.startsWith('+') ? cleanPhone : ('+' + cleanPhone);
                String cleanWithoutPlus = cleanPhone.startsWith('+') ? cleanPhone.substring(1) : cleanPhone;
                Set<String> phoneCandidates = new Set<String>{ phoneNumber, cleanPhone, cleanWithPlus, cleanWithoutPlus };

                chats = [SELECT Id, Type_of_Message__c, Message_ID__c, Message__c, Message_Status__c, Message_Type__c, Reply_to__c, Reaction__c, WA_Template__c, 
                           WA_Template__r.Template_Name__c, WA_Template__r.Header_Type__c, WA_Template__r.Header_Body__c, WA_Template__r.Template_Body__c, 
                           WA_Template__r.Footer_Body__c, WA_Template__r.Button_Body__c, WA_Template__r.Image_Header_Handle__c, CreatedDate, Phone__c, File_Data__c, 
                           Sent_Template_Details__c FROM WA_Chat__c WHERE Phone__c IN :phoneCandidates WITH USER_MODE ORDER BY CreatedDate ASC];
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
                if (objectNames.size() == 1 && objectNames.contains(objectApiName)) {
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
                        WA_Template__r.Footer_Body__c, WA_Template__r.Button_Body__c, WA_Template__r.Image_Header_Handle__c, CreatedDate, File_Data__c, 
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
     * @param objectApiName - API name of the object
     * @return Map<String, Object>
     */
    @AuraEnabled
    public static Map<String, Object> getTemplateData(String templateId, String contactId, String objectApiName) {
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
                                   ' FROM ' + String.escapeSingleQuotes(objectApiName) + ' WHERE Id = :contactId WITH USER_MODE LIMIT 1';
                    List<sObject> records = Database.query(query);
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
     * @param objectApiName - API Name of the record object
     * @param phoneNumber - Recipient phone number
     * @return Map<String, Object> - result containing newly created WA_Chat__c record
     */
    @AuraEnabled
    public static Map<String, Object> sendSelectedTemplate(String templateId, String recordId, String objectApiName, String phoneNumber) {
        Map<String, Object> result = new Map<String, Object>();
        try {
            if (String.isBlank(templateId) || String.isBlank(phoneNumber)) {
                result.put('success', false);
                result.put('message', 'Template Id and Phone Number are required.');
                return result;
            }

            Map<String, Object> templateData = getTemplateData(templateId, recordId, objectApiName);
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
            chat.Type_of_Message__c = 'Outbound Messages';
            chat.Message_Type__c = 'Template';
            chat.Sent_Template_Details__c = JSON.serialize(components);
            chat.Message_ID__c = whatsAppMessageID;
            chat.Message_Status__c = isCalloutSuccess ? 'Sent' : 'Failed';
            if (objectApiName == 'Contact' && String.isNotBlank(recordId)) {
                chat.Contact__c = recordId;
            }
            insert as user chat;

            // Re-query chat with complete template relationship fields for UI
            chat = [SELECT Id, Type_of_Message__c, Message_ID__c, Message__c, Message_Status__c, Message_Type__c, Reply_to__c, Reaction__c, WA_Template__c, 
                        WA_Template__r.Template_Name__c, WA_Template__r.Header_Type__c, WA_Template__r.Header_Body__c, WA_Template__r.Template_Body__c, 
                        WA_Template__r.Footer_Body__c, WA_Template__r.Button_Body__c, WA_Template__r.Image_Header_Handle__c, CreatedDate, Phone__c, 
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
     * @description : Builds WhatsApp interactive message payload JSON
     * @param templateId - Template Id
     * @param contactId - Record Id
     * @param objectApiName - API Name
     * @param phoneNumber - Recipient phone number
     * @return String
     */
    @AuraEnabled
    public static String buildInteractivePayload(String templateId, String contactId, String objectApiName, String phoneNumber) {
        try {
            Map<String, Object> templateData = getTemplateData(templateId, contactId, objectApiName);
            if (templateData == null || !templateData.containsKey('template')) {
                return null;
            }

            WA_Template__c template = (WA_Template__c) templateData.get('template');
            if (template == null || String.isBlank(template.Template_Body__c)) {
                return null;
            }

            String payload = template.Template_Body__c;
            if (String.isNotBlank(phoneNumber)) {
                String normalizedPhone = phoneNumber.replaceAll('\\s+', '');
                payload = payload.replace('{{RECIPIENT_NUMBER}}', normalizedPhone);
            }

            return payload;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WAChatWindowController', 'buildInteractivePayload', e.getMessage());
            return null;
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
            chat.Type_of_Message__c = 'Outbound Messages';
            chat.Message_Status__c = null;
            chat.Message_Type__c = messageType;
            chat.Reply_to__c = replyToChatId;
            Map<String, Object> fileData = new Map<String, Object>{ 'fileName' => fileName, 'mimeType' => mimeType };
            chat.File_Data__c = JSON.serialize(fileData);

            insert as user chat;
            chat = [SELECT Id, Type_of_Message__c, Message_ID__c, Message__c, Message_Status__c, Message_Type__c, Reply_to__c, Reaction__c, WA_Template__c, 
                        WA_Template__r.Template_Name__c, CreatedDate, File_Data__c FROM WA_Chat__c WHERE Id = :chat.Id WITH USER_MODE];

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
     * @param objectApiName - API Name of the object
     * @return List<WA_Template__c>
     */
    @AuraEnabled
    public static List<WA_Template__c> getTemplatesOnly(String objectApiName) {
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
                if (objectNames.size() == 1 && objectNames.contains(objectApiName)) {
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
}