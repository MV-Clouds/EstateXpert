public with sharing class ChatWindowController {

    public static List<WBConnect_Configuration__mdt> wbConfig = WBConnect_Configuration__mdt.getAll().values(); 
    public static List<User_Theme_Preference__c> userPreferences = [SELECT Theme__c FROM User_Theme_Preference__c WHERE SetupOwnerId =: UserInfo.getUserId() WITH USER_MODE LIMIT 1];

    @AuraEnabled
    public static Map<String, Object> getCombinedData(String contactId, String objectApiName){
        Map<String, Object> combinedData = new Map<String, Object>();
        try {
            List<Chat__c> chats = new List<Chat__c>();
            List<WhatsappTemplate__c> templates = new List<WhatsappTemplate__c>();
            User_Theme_Preference__c userPreference = !userPreferences.isEmpty() ? userPreferences[0] : null;
            String theme = userPreference != null && userPreference.Theme__c != null ? userPreference.Theme__c : 'light';

            List<Object_Config__mdt> objectConfigList = [SELECT Id, ObjectConfigInfo__c, ChatWindowConfigInfo__c FROM Object_Config__mdt WITH USER_MODE LIMIT 1];
            String phoneField = '';
            String nameField = '';
            if(objectConfigList.size() <= 0) {
                System.debug('Object Config not found!');
            } else {
                Map<String, Object> chatConfigData = (Map<String, Object>) JSON.deserializeUntyped(objectConfigList[0].ChatWindowConfigInfo__c);
                Map<String, Object> chatConfig = (Map<String, Object>) chatConfigData.get(objectApiName);
                phoneField = (String) chatConfig.get('phoneField');
                nameField = (String) chatConfig.get('nameField');
            }

            sObject recordData;
            String phoneNumber = '';
            String recordName = '';
            if(nameField != '' && phoneField != '') {
                String query = 'SELECT Id, ' +  nameField + ', ' +  phoneField + ' FROM ' + objectApiName + ' WHERE Id =: contactId LIMIT 1';
                recordData = Database.query(String.escapeSingleQuotes(query), AccessLevel.USER_MODE);
                phoneNumber = (String) recordData.get(phoneField);
                recordName = (String) recordData.get(nameField);
            }

            Integer pageSize = 50;
            chats = [SELECT Id, Type_of_Message__c, WhatsAppMessageId__c, Message__c, Message_Status__c, Message_Type__c, Reply_To__c, Reaction__c, WhatsappTemplate__c, WhatsappTemplate__r.Template_Name__c, CreatedDate, Last_Interaction_Date__c, Phone__c, File_Data__c FROM Chat__c WHERE Phone__c =:phoneNumber WITH USER_MODE ORDER BY CreatedDate DESC LIMIT 50];
            
            Set<Id> matchingTemplateIds = new Set<Id>();
            for (Template_Variable__c tv : [SELECT WhatsappTemplate__c FROM Template_Variable__c WHERE Object_Name__c = :objectApiName WITH USER_MODE]) {
                matchingTemplateIds.add(tv.WhatsappTemplate__c);
            }
            if (!matchingTemplateIds.isEmpty()) {
                templates.addAll(
                    [SELECT Id, Template_Name__c FROM WhatsappTemplate__c WHERE Status__c = 'Active-Quality Pending' AND Id IN :matchingTemplateIds WITH USER_MODE ORDER BY LastModifiedDate DESC
                ]);
            }
            List<WhatsappTemplate__c> templatesWithoutVariables = [SELECT Id, Template_Name__c FROM WhatsappTemplate__c WHERE Status__c = 'Active-Quality Pending' AND Id NOT IN (SELECT WhatsappTemplate__c FROM Template_Variable__c) WITH USER_MODE ORDER BY LastModifiedDate DESC];
            templates.addAll(templatesWithoutVariables);

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

    @AuraEnabled
    public static List<Chat__c> getOlderChats(String phoneNumber, Integer pageNumber, Integer pageSize) {
        Integer offset = (pageNumber - 1) * pageSize;
        return [
            SELECT Id, Type_of_Message__c, WhatsAppMessageId__c, Message__c, Message_Status__c, Message_Type__c, Reply_To__c, Reaction__c, WhatsappTemplate__c, WhatsappTemplate__r.Template_Name__c, CreatedDate, Last_Interaction_Date__c, Phone__c, File_Data__c 
            FROM Chat__c 
            WHERE Phone__c = :phoneNumber 
            WITH USER_MODE 
            ORDER BY CreatedDate DESC 
            LIMIT :pageSize 
            OFFSET :offset
        ];
    }

    @AuraEnabled
    public static Chat__c createChat(Map<String, String> chatData ){
        try {

            String message = chatData.get('message');
            String templateId = chatData.get('templateId');
            String messageType = chatData.get('messageType');
            String recordId = chatData.get('recordId');
            String replyToChatId = chatData.get('replyToChatId');
            String phoneNumber = chatData.get('phoneNumber');

            Chat__c chat = new Chat__c();
            chat.Message__c = message;
            chat.WhatsappTemplate__c = templateId;
            chat.Phone__c = phoneNumber;
            chat.Type_of_Message__c	= 'OutBound Messages';
            chat.Message_Status__c = null;
            chat.Message_Type__c = messageType;
            chat.Reply_To__c = replyToChatId;

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
                throw new AuraHandledException('STORAGE_LIMIT_EXCEEDED');
            }
            ErrorHandler.insertErrordata(e, 'ChatWindowController', 'createChat', e.getMessage());
            return null;
        }
    }

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

    @AuraEnabled
    public static Map<String, Object> sendWhatsappMessage(String jsonData, String chatId, Boolean isReaction, String reaction) {
        Map<String, Object> resultMap = new Map<String, Object>{};
        Chat__c chat = new Chat__c(Id = chatId);
        try {
            HttpRequest httpReq = new HttpRequest();
            resultMap.put('errorMessage', null);
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
            String accessToken = wbConfig[0].Access_Token__c;
            String endpoint = wbConfig[0].API_Endpoint__c + '/' + wbConfig[0].API_Version__c + '/' + wbConfig[0].Phone_Number_Id__c + '/messages';
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
                if(!isReaction){
                    chat.WhatsAppMessageId__c = whatsAppMessageID;
                    chat.Message_Status__c = 'Sent';
                }
            }else{
                if(!isReaction){
                    chat.Message_Status__c = 'Failed';
                }
                resultMap.put('errorMessage', 'API_ERROR');
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

    @AuraEnabled
    public static Map<String, Object> getTemplateData(String templateId, String contactId, String objectApiName) {
        try {
            Map<String, Object> templateData = new Map<String, Object>();
            List<WhatsappTemplate__c> templates = new List<WhatsappTemplate__c>();
            Set<Id> matchingTemplateIds = new Set<Id>();
            for (Template_Variable__c tv : [SELECT WhatsappTemplate__c FROM Template_Variable__c WHERE Object_Name__c = :objectApiName WITH USER_MODE]) {
                matchingTemplateIds.add(tv.WhatsappTemplate__c);
            }
            if (!matchingTemplateIds.isEmpty()) {
                templates.addAll([
                    SELECT Id, Template_Name__c, WBButton_Body__c, Button_Label__c, Button_Type__c, WBFooter_Body__c, WBHeader_Body__c, Header_Type__c, Language__c, WBTemplate_Body__c, Template_Category__c, Template_SubCatagory__c, Template_Type__c, Template_Variable__c,
                        (SELECT Id, Name, Field_Name__c, Object_Name__c, Type__c, Alternate_Text__c FROM WB_Template_Variables__r) FROM WhatsappTemplate__c WHERE Id = :templateId AND Id IN :matchingTemplateIds WITH USER_MODE
                ]);
            }
            List<WhatsappTemplate__c> templatesWithoutVariables = [
                SELECT Id, Template_Name__c, WBButton_Body__c, Button_Label__c, Button_Type__c, WBFooter_Body__c, WBHeader_Body__c, Header_Type__c, Language__c, WBTemplate_Body__c, Template_Category__c, Template_SubCatagory__c, Template_Type__c, Template_Variable__c,
                    (SELECT Id, Name, Field_Name__c, Object_Name__c, Type__c, Alternate_Text__c FROM WB_Template_Variables__r) FROM WhatsappTemplate__c WHERE Id = :templateId AND Id NOT IN (SELECT WhatsappTemplate__c FROM Template_Variable__c) WITH USER_MODE
            ];
            templates.addAll(templatesWithoutVariables);

            if(templates.size() > 0 && templates[0].Template_Variable__c>0){
                WhatsappTemplate__c template= templates[0];
                Set<String> fieldSelectionCause = new Set<String>();
                for (Template_Variable__c tv : template.WB_Template_Variables__r) {
                    if (tv.Object_Name__c == objectApiName) {
                        fieldSelectionCause.add(tv.Field_Name__c);
                    } else {
                        try {
                            fieldSelectionCause.add(tv.Object_Name__c + '.' + tv.Field_Name__c);
                        } catch (Exception ex) {
                            System.debug('Invalid relationship: ' + tv.Object_Name__c + ' for ' + objectApiName);
                        }
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
                
                if (records.size() > 0) {
                    SObject record = records[0];
                    String userTimeZone = UserInfo.getTimeZone().getID();
                    
                    for (Template_Variable__c tv : template.WB_Template_Variables__r) {
                        Object valueToReplace = null;
                        if (tv.Object_Name__c == objectApiName) {
                            valueToReplace = record.get(tv.Field_Name__c);
                        } else {
                            try {
                                SObject relatedRecord = record.getSObject(tv.Object_Name__c);
                                valueToReplace = (relatedRecord != null) ? relatedRecord.get(tv.Field_Name__c) : null;
                            } catch (Exception ex) {
                                valueToReplace = null;
                            }
                        }

                        String formattedValue = '';
                        if (valueToReplace instanceof Datetime) {
                            Datetime dtValue = (Datetime)valueToReplace;
                            formattedValue = dtValue != null ? dtValue.format('yyyy-MM-dd HH:mm', userTimeZone) : (tv.Alternate_Text__c != null ? tv.Alternate_Text__c : ' ');
                        } else {
                            formattedValue = valueToReplace != null ? valueToReplace.toString() : (tv.Alternate_Text__c != null ? tv.Alternate_Text__c : ' ');
                        }

                        if (tv.Type__c == 'Header') {
                            headerVariables.add(formattedValue);
                            template.WBHeader_Body__c = template.WBHeader_Body__c.replace(tv.Name, formattedValue);
                        } else if (tv.Type__c == 'Body') {
                            bodyVariables.add(formattedValue);
                            template.WBTemplate_Body__c = template.WBTemplate_Body__c.replace(tv.Name, formattedValue);
                        }
                    }
                }

                if (template.Header_Type__c == 'Image' || template.Header_Type__c == 'Video' || template.Header_Type__c == 'Document') {
                    templateData.put('isImageUrl', true);
                }

                templateData.put('template', template);
                templateData.put('headerParams', headerVariables);
                templateData.put('bodyParams', bodyVariables);
                return templateData;
            } else if (templates.size() > 0 && templates[0].Template_Variable__c < 1) {
                WhatsappTemplate__c template = templates[0];
                if (template.Header_Type__c == 'Image' || template.Header_Type__c == 'Video' || template.Header_Type__c == 'Document') {
                    templateData.put('isImageUrl', true);
                }
                templateData.put('template', template);
                return templateData;
            } else {
                return null;
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'ChatWindowController', 'getTemplateData', e.getMessage());
            return null;
        }
    }

    @AuraEnabled
    public static void updateStatus(List<String> messageIds) {
        List<Chat__c> chats = new List<Chat__c>();
        chats = [SELECT Id, WhatsAppMessageId__c, Message_Status__c FROM Chat__c WHERE Id IN :messageIds WITH USER_MODE];
        String accessToken = wbConfig[0].Access_Token__c;
        String endpoint = wbConfig[0].API_Endpoint__c + '/' + wbConfig[0].API_Version__c + '/' + wbConfig[0].Phone_Number_Id__c + '/messages';

        try {
            for (Chat__c chat : chats) {
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
                if (statusCode == 200) {
                    chat.Message_Status__c = 'Seen';
                }
            }
            update as user chats;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'ChatWindowController', 'updateStatus', e.getMessage());
        }
    }

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

}