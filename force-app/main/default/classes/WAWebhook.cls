@RestResource(urlMapping = '/EXP/WhatsApp/Webhook/*')
global without sharing class WAWebhook {
    public static String currentTime = System.now().format('yyyy-MM-dd HH:mm:ss');
    public static String phoneNumberId = '';
    public static List<Object> messages = new List<Object>();
    public static List<MVEX__AWS_Config__c> configList = [SELECT Id, MVEX__AWS_Access_Key__c, MVEX__AWS_Secret_Access_Key__c, MVEX__S3_Bucket_Name__c, MVEX__S3_Region_Name__c, CreatedDate, LastModifiedDate FROM MVEX__AWS_Config__c LIMIT 1];
    public static MVEX__AWS_Config__c configData = !configList.isEmpty() ? configList[0] : null;

    private static final String CONFIG_DEV_NAME = 'Whatsapp_OAuth';

    @HttpGet
    global static void doGet() {
        RestResponse response = RestContext.response;
        RestRequest request = RestContext.request;
        if (request.params.get('hub.verify_token') == 'EXPWHATSAPPTOKEN') {
            response.responseBody = Blob.valueOf(request.params.get('hub.challenge'));
        }
    }

    @HttpPost
    global static void doPost() {
        String jsonString = RestContext.request.requestBody.toString();
        try {
            processWhatsAppPayload(jsonString);
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WAWebhook', 'doPost', e.getMessage());
        }
    }

    public static void processWhatsAppPayload(String jsonString) {
        try {
            parseMessages(jsonString);
            Map<String, Object> payload = (Map<String, Object>)JSON.deserializeUntyped(jsonString);

            List<Object> listofmessages = (List<Object>)payload.get('entry');
            Object messageobj = listofmessages[0];

            Map<String, Object> sender = new Map<String, Object>();
            if (messageobj != null) {
                Map<String, Object> messageMap = (Map<String, Object>)messageobj;
                if (messageMap.get('changes') != null) {
                    List<Object> changes = (List<Object>)messageMap.get('changes');
                    if (changes != null && !changes.isEmpty()) {
                        Object changeObj = changes[0];
                        Map<String, Object> changeMap = (Map<String, Object>)changeObj;
                        Map<String, Object> value = (Map<String, Object>)changeMap.get('value');
                        Map<String, Object> metadata = (Map<String, Object>)value.get('metadata');
                        if (metadata != null && metadata.containsKey('phone_number_id') && metadata.get('phone_number_id') != null) {
                            phoneNumberId = (String) metadata.get('phone_number_id');
                        }
                        messages = (List<Object>)value.get('messages');
                        List<Object> senders = (List<Object>)value.get('contacts');
                        if (senders != null && !senders.isEmpty()) {
                            sender = (Map<String, Object>) senders[0];
                        }
                    }
                }
            }

            if (messages != null && !messages.isEmpty()) {
                Map<String, Object> message = (Map<String, Object>)messages[0];
                processSingleMessage(message, sender);
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WAWebhook', 'processWhatsAppPayload', e.getMessage() + ' jsonstring -> ' + jsonString);
        }
    }

    public static void processSingleMessage(Map<String, Object> message, Map<String, Object> sender) {
        try {
            String senderId = (String) message.get('from');
            String messageType = (String) message.get('type');
            String whatsAppMessageID = (String) message.get('id');
            Map<String, Object> context = (Map<String, Object>)message.get('context');
            String contextId = '';
            if (context != null) {
                contextId = (String) context.get('id');
            }
            Map<String, Object> reactionMessage = (Map<String, Object>)message.get('reaction');
            String reactToMessageId = '';
            String reactedEmoji = '';
            if (reactionMessage != null) {
                reactToMessageId = (String) reactionMessage.get('message_id');
                reactedEmoji = (String) reactionMessage.get('emoji');
            }
            Integer timestampValue = Integer.valueOf(message.get('timestamp'));
            DateTime messageTime = DateTime.newInstanceGmt(1970, 1, 1, 0, 0, 0).addSeconds(timestampValue);
            DateTime tenMinutesAgo = DateTime.now().addMinutes(-10);

            if (messageTime < tenMinutesAgo) {
                System.debug('Timestamp is older than 10 minutes.');
                return;
            }

            // Query to check if the message has already been processed
            List<WA_Chat__c> existingChatRecords = [SELECT Id FROM WA_Chat__c WHERE Message_ID__c = :whatsAppMessageID LIMIT 1];
            if (!existingChatRecords.isEmpty()) {
                return;
            }

            if (!senderId.contains('+')) {
                senderId = '+' + senderId;
            }
            String formattedNumber = normalizePhoneNumber(senderId);

            Map<String, Object> profile = (Map<String, Object>) sender.get('profile');
            String senderName = profile != null ? (String) profile.get('name') : '';
            String senderPhone = formattedNumber;
            List<User> userRecs = [SELECT Id, Name, Phone FROM User WHERE Phone = :formattedNumber LIMIT 1];
            String strippedNumber = formattedNumber.replace('+', '');
            String recordId = '';
            String recordName = '';
            String recordPhone = '';
            String objectApiName = 'Contact';

            // Retrieve ObjectConfigInfo from Metadata (object is always Contact)
            Map<String, Object> objConfigMap = getObjectConfigInfo();

            // Resolve configured phone field from ObjectConfigInfo on Contact
            String phoneField = 'Phone';
            if (objConfigMap.containsKey('phoneField') && objConfigMap.get('phoneField') != null && String.isNotBlank(String.valueOf(objConfigMap.get('phoneField')))) {
                String configuredPhone = String.valueOf(objConfigMap.get('phoneField')).trim();
                Map<String, Schema.SObjectField> contactFieldsMap = Contact.SObjectType.getDescribe().fields.getMap();
                if (contactFieldsMap.containsKey(configuredPhone.toLowerCase())) {
                    phoneField = contactFieldsMap.get(configuredPhone.toLowerCase()).getDescribe().getName();
                }
            }

            // Build candidate phone formats for matching existing Contact
            Set<String> phoneCandidates = new Set<String>{ senderPhone, formattedNumber, strippedNumber };
            if (String.isNotBlank(strippedNumber)) {
                if (strippedNumber.length() > 10) {
                    phoneCandidates.add(strippedNumber.substring(strippedNumber.length() - 10));
                    phoneCandidates.add('0' + strippedNumber.substring(strippedNumber.length() - 10));
                }
                phoneCandidates.add('+' + strippedNumber);
            }

            // Search for existing Contact by configured phone field
            Contact contactRecord = null;
            try {
                String query = 'SELECT Id, Name, ' + String.escapeSingleQuotes(phoneField) + 
                               ' FROM Contact WHERE ' + String.escapeSingleQuotes(phoneField) + ' IN :phoneCandidates LIMIT 1';
                List<Contact> records = Database.query(query);
                if (!records.isEmpty()) {
                    contactRecord = records[0];
                }
            } catch (Exception qEx) {
                System.debug('Error querying Contact by ' + phoneField + ': ' + qEx.getMessage());
            }

            if (contactRecord != null) {
                recordId = contactRecord.Id;
                recordName = contactRecord.Name;
                recordPhone = String.valueOf(contactRecord.get(phoneField));
            } else {
                // Contact not found -> Create new Contact using requiredFields from ObjectConfigInfo
                Contact newContact = new Contact();
                Map<String, Schema.SObjectField> contactFields = Contact.SObjectType.getDescribe().fields.getMap();

                // 1. Set configured phone field
                if (contactFields.containsKey(phoneField.toLowerCase()) && contactFields.get(phoneField.toLowerCase()).getDescribe().isCreateable()) {
                    newContact.put(phoneField, senderPhone);
                } else {
                    newContact.Phone = senderPhone;
                }

                // 2. Set required fields from ObjectConfigInfo (e.g. OwnerId, LastName, etc.)
                Boolean lastNameSet = false;
                if (objConfigMap.containsKey('requiredFields') && objConfigMap.get('requiredFields') instanceof List<Object>) {
                    List<Object> requiredFieldsList = (List<Object>) objConfigMap.get('requiredFields');
                    for (Object item : requiredFieldsList) {
                        if (item instanceof Map<String, Object>) {
                            Map<String, Object> fieldData = (Map<String, Object>) item;
                            String fName = fieldData.get('name') != null ? String.valueOf(fieldData.get('name')).trim() : null;
                            Object fVal = fieldData.get('value');

                            if (String.isNotBlank(fName) && contactFields.containsKey(fName.toLowerCase())) {
                                Schema.DescribeFieldResult dfr = contactFields.get(fName.toLowerCase()).getDescribe();
                                if (dfr.isCreateable() && fVal != null && String.isNotBlank(String.valueOf(fVal))) {
                                    String realFieldName = dfr.getName();
                                    String strVal = String.valueOf(fVal).trim();

                                    try {
                                        Schema.DisplayType dType = dfr.getType();
                                        if (dType == Schema.DisplayType.REFERENCE) {
                                            if (strVal.length() == 15 || strVal.length() == 18) {
                                                newContact.put(realFieldName, Id.valueOf(strVal));
                                            }
                                        } else if (dType == Schema.DisplayType.BOOLEAN) {
                                            newContact.put(realFieldName, Boolean.valueOf(strVal));
                                        } else if (dType == Schema.DisplayType.INTEGER) {
                                            newContact.put(realFieldName, Integer.valueOf(strVal));
                                        } else if (dType == Schema.DisplayType.DOUBLE || dType == Schema.DisplayType.PERCENT || dType == Schema.DisplayType.CURRENCY) {
                                            newContact.put(realFieldName, Decimal.valueOf(strVal));
                                        } else if (dType == Schema.DisplayType.DATE) {
                                            newContact.put(realFieldName, Date.valueOf(strVal));
                                        } else if (dType == Schema.DisplayType.DATETIME) {
                                            newContact.put(realFieldName, Datetime.valueOf(strVal.replace('T', ' ')));
                                        } else {
                                            newContact.put(realFieldName, strVal);
                                        }

                                        if (realFieldName.equalsIgnoreCase('LastName')) {
                                            lastNameSet = true;
                                        }
                                    } catch (Exception fieldEx) {
                                        System.debug('Error setting field ' + realFieldName + ' on new Contact: ' + fieldEx.getMessage());
                                    }
                                }
                            }
                        }
                    }
                }

                // 3. Ensure LastName is populated (standard Contact requirement)
                if (!lastNameSet || String.isBlank(newContact.LastName)) {
                    newContact.LastName = String.isNotBlank(senderName) ? senderName : 'WhatsApp User';
                } else if (String.isNotBlank(senderName) && String.isBlank(newContact.FirstName)) {
                    newContact.FirstName = senderName.length() > 40 ? senderName.substring(0, 40) : senderName;
                }

                try {
                    insert newContact;
                    recordId = newContact.Id;
                    recordName = (String.isNotBlank(newContact.FirstName) ? newContact.FirstName + ' ' : '') + newContact.LastName;
                    recordPhone = senderPhone;
                } catch (Exception insertEx) {
                    ErrorHandler.insertErrordata(insertEx, 'WAWebhook', 'processSingleMessage_insertContact', 'Failed to insert contact: ' + insertEx.getMessage());
                }
            }

            DateTime myDateTime = DateTime.now();
            WA_Chat__c whatsappChat = new WA_Chat__c();

            if (existingChatRecords.isEmpty()) {
                if (messageType.equalsIgnoreCase('reaction')) {
                    List<WA_Chat__c> reactToChat = [SELECT Id, Reaction__c, Contact__c, Phone__c FROM WA_Chat__c WHERE Message_ID__c = :reactToMessageId];
                    if (!reactToChat.isEmpty()) {
                        reactToChat[0].Reaction__c = reactToChat[0].Reaction__c != null ? reactToChat[0].Reaction__c : '<|USER|>';
                        reactToChat[0].Reaction__c = reactToChat[0].Reaction__c.split('<|USER|>')[0] + '<|USER|>' + (reactedEmoji != null ? reactedEmoji : '');
                        whatsappChat = reactToChat[0];
                        update whatsappChat;
                        publishRefreshEvent('Chat', whatsappChat.Phone__c);
                    }
                    return;
                }

                whatsappChat.Phone__c = senderPhone;
                whatsappChat.Type_of_Message__c = 'Inbound Messages';
                whatsappChat.Message_Type__c = messageType;
                whatsappChat.Message_ID__c = whatsAppMessageID;
                if (String.isNotBlank(recordId)) {
                    whatsappChat.Contact__c = recordId;
                }

                if (String.isNotBlank(contextId)) {
                    List<WA_Chat__c> replyToChat = [SELECT Id FROM WA_Chat__c WHERE Message_ID__c != null AND Message_ID__c = :contextId LIMIT 1];
                    whatsappChat.Reply_to__c = !replyToChat.isEmpty() ? replyToChat[0].Id : null;
                }

                if (messageType.equalsIgnoreCase('text')) {
                    Map<String, Object> text = (Map<String, Object>) message.get('text');
                    String messageBody = '';
                    if (text != null && text.values() != null) {
                        messageBody = (String) text.get('body');
                    }
                    whatsappChat.Message__c = messageBody;
                }

                if (messageType.equalsIgnoreCase('image')) {
                        Map<String, Object> image = (Map<String, Object>) message.get('image');
                        String imageId = (String) image.get('id');
                        String mimeType = (String) image.get('mime_type');
                        String fileExtension = getFileExtension(mimeType);
                        String fileDateFormat = myDateTime.format('ddMMyyyy_HHmmss');
                        String filename = 'IMG-' + fileDateFormat + fileExtension;
    
                        Blob documentBody = handleMediaAttachment(imageId);
                        Map<String, Object> filedata = new Map<String, Object>();
                        if (documentBody != null) {
                            if (configData != null) {
                                String fileUrl = AWSFilesManager.uploadFileToS3(filename, documentBody, mimeType);
                                whatsappChat.Message__c = fileUrl;
                                filedata = new Map<String, Object>{ 'fileName' => filename, 'mimeType' => mimeType };
                                whatsappChat.File_Data__c = JSON.serialize(filedata);
                            } else {
                                filedata = saveMediaToSalesforce(documentBody, filename, mimeType, recordId, objectApiName);
                                whatsappChat.Message__c = '/sfc/servlet.shepherd/version/download/' + filedata.get('contentVersionId');
                                whatsappChat.File_Data__c = JSON.serialize(filedata);
                            }
                        }
                    }
                    if (messageType.equalsIgnoreCase('document')) {
                        Map<String, Object> document = (Map<String, Object>)message.get('document');
                        String mediaId = (String) document.get('id');
                        String mimeType = (String) document.get('mime_type');
                        String name = (String) document.get('filename');
                        String fileExtension = getFileExtension(mimeType);
                        String filename = name + fileExtension;

                        Blob documentBody = handleMediaAttachment(mediaId);
                        Map<String, Object> filedata = new Map<String, Object>();
                        if (documentBody != null) {
                            if (configData != null) {
                                String fileUrl = AWSFilesManager.uploadFileToS3(filename, documentBody, mimeType);
                                whatsappChat.Message__c = fileUrl;
                                filedata = new Map<String, Object>{ 'fileName' => filename, 'mimeType' => mimeType };
                                whatsappChat.File_Data__c = JSON.serialize(filedata);
                            } else {
                                filedata = saveMediaToSalesforce(documentBody, filename, mimeType, recordId, objectApiName);
                                whatsappChat.Message__c = '/sfc/servlet.shepherd/version/download/' + filedata.get('contentVersionId');
                                whatsappChat.File_Data__c = JSON.serialize(filedata);
                            }
                        }
                    }
                    if (messageType.equalsIgnoreCase('video')) {
                        Map<String, Object> video = (Map<String, Object>) message.get('video');
                        String videoId = (String) video.get('id');
                        String mimeType = (String) video.get('mime_type');
                        String fileExtension = getFileExtension(mimeType);
                        String fileDateFormat = myDateTime.format('ddMMyyyy_HHmmss');
                        String filename = 'VID-' + fileDateFormat + fileExtension;
    
                        Blob documentBody = handleMediaAttachment(videoId);
                        Map<String, Object> filedata = new Map<String, Object>();
                        if (documentBody != null) {
                            if (configData != null) {
                                String fileUrl = AWSFilesManager.uploadFileToS3(filename, documentBody, mimeType);
                                whatsappChat.Message__c = fileUrl;
                                filedata = new Map<String, Object>{ 'fileName' => filename, 'mimeType' => mimeType };
                                whatsappChat.File_Data__c = JSON.serialize(filedata);
                            } else {
                                filedata = saveMediaToSalesforce(documentBody, filename, mimeType, recordId, objectApiName);
                                whatsappChat.Message__c = '/sfc/servlet.shepherd/version/download/' + filedata.get('contentVersionId');
                                whatsappChat.File_Data__c = JSON.serialize(filedata);
                            }
                        }
                    }
                    if (messageType.equalsIgnoreCase('audio')) {
                        Map<String, Object> audio = (Map<String, Object>) message.get('audio');
                        String audioId = (String) audio.get('id');
                        String mimeType = (String) audio.get('mime_type');
                        String fileExtension = getFileExtension(mimeType);
                        String fileDateFormat = myDateTime.format('ddMMyyyy_HHmmss');
                        String filename = 'AUD-' + fileDateFormat + fileExtension;
    
                        Blob documentBody = handleMediaAttachment(audioId);
                        Map<String, Object> filedata = new Map<String, Object>();
                        if (documentBody != null) {
                            if (configData != null) {
                                String fileUrl = AWSFilesManager.uploadFileToS3(filename, documentBody, mimeType);
                                whatsappChat.Message__c = fileUrl;
                                filedata = new Map<String, Object>{ 'fileName' => filename, 'mimeType' => mimeType };
                                whatsappChat.File_Data__c = JSON.serialize(filedata);
                            } else {
                                filedata = saveMediaToSalesforce(documentBody, filename, mimeType, recordId, objectApiName);
                                whatsappChat.Message__c = '/sfc/servlet.shepherd/version/download/' + filedata.get('contentVersionId');
                                whatsappChat.File_Data__c = JSON.serialize(filedata);
                            }
                        }
                    }
                    if (messageType.equalsIgnoreCase('button')) {
                        Map<String, Object> button = (Map<String, Object>)message.get('button');
                        String text = (String) button.get('text');
                        whatsappChat.Message__c = text;
                        if (String.isNotBlank(contextId)) {
                            whatsappChat.Message_Context_ID__c = contextId;
                        }
                        whatsappChat.Message_Type__c = 'Text';
                    }
                    if (messageType.equalsIgnoreCase('interactive')) {
                        Map<String, Object> interactive = (Map<String, Object>)message.get('interactive');
                        if (interactive != null) { 
                            String interactiveType = (String) interactive.get('type');
                            String text = '';
                            if (interactiveType == 'button_reply') {
                                Map<String, Object> buttonReply = (Map<String, Object>) interactive.get('button_reply');
                                if (buttonReply != null) {
                                    text = (String) buttonReply.get('title');
                                }
                            } else if (interactiveType == 'list_reply') {
                                Map<String, Object> listReply = (Map<String, Object>) interactive.get('list_reply');
                                if (listReply != null) {
                                    text = (String) listReply.get('title');
                                }
                            }
                            whatsappChat.Message__c = text;
                            whatsappChat.Message_Type__c = 'Interactive';
                            if (String.isNotBlank(contextId)) {
                                whatsappChat.Message_Context_ID__c = contextId;
                            }
                        }
                    }
                }

            insert whatsappChat;

            List<WA_Chat__c> chatList = [SELECT Id, Type_of_Message__c, Message_ID__c, Message__c, Message_Status__c, Message_Type__c, Reply_to__c, Reaction__c, WA_Template__c, WA_Template__r.Template_Name__c, WA_Template__r.Name, CreatedDate, Contact__c, Phone__c, File_Data__c FROM WA_Chat__c WHERE Id = :whatsappChat.Id LIMIT 1];
            WA_Chat__c chatToSend = !chatList.isEmpty() ? chatList[0] : whatsappChat;
            publishRefreshEvent('Chat', whatsappChat.Phone__c);

            if (userRecs.isEmpty()) {
                List<WA_Chat__c> lastSentChat = [SELECT Id, Phone__c, CreatedById FROM WA_Chat__c WHERE Phone__c = :formattedNumber AND Type_of_Message__c = 'Outbound Messages' ORDER BY CreatedDate DESC LIMIT 1];
                if (String.isNotBlank(recordId)) {
                    if (!lastSentChat.isEmpty()) {
                        sendNotificationForContact(recordId, objectApiName, lastSentChat[0].CreatedById);
                    } else {
                        sendNotificationForContact(recordId, objectApiName, null);
                    }
                }
            }

        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WAWebhook', 'processSingleMessage', e.getMessage() + ' (Line: ' + e.getLineNumber() + ')');
        }
    }

    public static String getFileExtension(String mimeType) {
        if (mimeType.equals('image/jpeg')) {
            return '.jpeg';
        } else if (mimeType.equals('image/png')) {
            return '.png';
        } else if (mimeType.equals('image/jpg')) {
            return '.jpg';
        } else if (mimeType.equals('audio/mp3') || mimeType.equals('audio/mpeg')) {
            return '.mp3';
        } else if (mimeType.equals('audio/aac')) {
            return '.aac';
        } else if (mimeType.equals('audio/ogg; codecs=opus')) {
            return '.ogg';
        } else if (mimeType.equals('video/mp4')) {
            return '.mp4';
        } else if (mimeType.equals('video/3gp')) {
            return '.3gp';
        } else if (mimeType.equals('application/pdf')) {
            return '.pdf';
        } else if (mimeType.equals('application/msword')) {
            return '.doc';
        } else if (mimeType.equals('application/vnd.openxmlformats-officedocument.wordprocessingml.document')) {
            return '.docx';
        } else if (mimeType.equals('application/vnd.ms-powerpoint')) {
            return '.ppt';
        } else if (mimeType.equals('application/vnd.openxmlformats-officedocument.presentationml.presentation')) {
            return '.pptx';
        } else if (mimeType.equals('application/vnd.ms-excel')) {
            return '.xls';
        } else if (mimeType.equals('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')) {
            return '.xlsx';
        } else if (mimeType.equals('text/plain')) {
            return '.txt';
        } else {
            return '.bin';
        }
    }

    public static Blob handleMediaAttachment(String documentId) {
        try {
            List<OAuth_Configuration__mdt> configs = [SELECT Id, DeveloperName, MasterLabel, API_Version__c, 
                                                        Authorization_Endpoint__c, Access_Token__c, Client_Phone_Number_ID__c 
                                                        FROM OAuth_Configuration__mdt 
                                                        WHERE DeveloperName = :CONFIG_DEV_NAME LIMIT 1];

            if(configs.isEmpty()) {
                return null;
            }
            
            String accessToken = configs[0].Access_Token__c;
            String apiEndpoint = configs[0].Authorization_Endpoint__c;
            String apiVersion = configs[0].API_Version__c;
            
            String mediaUrl = apiEndpoint + '/' + apiVersion + '/' + documentId;
            
            if (String.isNotBlank(accessToken)) {
                HttpRequest req = new HttpRequest();
                req.setEndpoint(mediaUrl);
                req.setMethod('GET');
                req.setHeader('Authorization', 'Bearer ' + accessToken);

                try {
                    Http http = new Http();
                    HttpResponse res = http.send(req);

                    if (res.getStatusCode() == 200) {
                        Map<String, Object> mediaMetadata = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
                        String downloadUrl = (String) mediaMetadata.get('url');
                        return downloadMediaContent(downloadUrl, accessToken);
                    } else {
                        ErrorHandler.insertErrordata(null, 'WAWebhook', 'handleMediaAttachment', 'Failed to retrieve media metadata. Status: ' + res.getStatus() + ', Response: ' + res.getBody());
                        return null;
                    }
                } catch (Exception e) {
                    ErrorHandler.insertErrordata(e, 'WAWebhook', 'handleMediaAttachment', e.getMessage());
                    return null;
                }
            } else {
                ErrorHandler.insertErrordata(null, 'WAWebhook', 'handleMediaAttachment', 'Failed to fetch access token or endpoint.');
                return null;
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WAWebhook', 'handleMediaAttachment', e.getMessage());
            return null;
        }
    }

    public static Blob downloadMediaContent(String mediaUrl, String accessToken) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(mediaUrl);
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + accessToken);

        try {
            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                return res.getBodyAsBlob();
            } else {
                ErrorHandler.insertErrordata(null, 'WAWebhook', 'downloadMediaContent', res.getBody());
                return null;
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WAWebhook', 'downloadMediaContent', e.getMessage());
            return null;
        }
    }

    public static Map<String, Object> saveMediaToSalesforce(Blob mediaBlob, String filename, String mimeType, Id parentRecordId, String objectApiName) {
        Map<String, Object> fileData = new Map<String, Object>();
        try {
            String query = 'SELECT Id, CreatedById FROM ' + objectApiName + ' WHERE Id = :parentRecordId LIMIT 1';
            List<SObject> records = Database.query(query);
            if (records.isEmpty()) {
                return fileData;
            }
            SObject record = records[0];

            ContentVersion contentVersion = new ContentVersion(
                Title = filename, 
                VersionData = mediaBlob, 
                PathOnClient = filename, 
                ContentLocation = 'S', 
                OwnerId = (Id) record.get('CreatedById')
            );
            insert contentVersion;

            List<ContentVersion> cvList = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :contentVersion.Id LIMIT 1];
            String contentDocumentId = !cvList.isEmpty() ? cvList[0].ContentDocumentId : null;

            fileData = new Map<String, Object>{ 'fileName' => filename, 'documentId' => contentDocumentId, 'contentVersionId' => contentVersion.Id, 'mimeType' => mimeType };
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WAWebhook', 'saveMediaToSalesforce', e.getMessage());
        }
        return fileData;
    }

    public static void sendNotificationForContact(String recordId, String objectApiName, String addresseeId) {
        try {
            if (String.isBlank(recordId) || (recordId.length() != 15 && recordId.length() != 18)) {
                return;
            }
            if (String.isBlank(objectApiName)) {
                objectApiName = 'Contact';
            }
            Schema.SObjectType sObjType = Schema.getGlobalDescribe().get(objectApiName);
            if (sObjType == null) {
                return;
            }
            Map<String, Schema.SObjectField> sObjFields = sObjType.getDescribe().fields.getMap();
            String nameCol = sObjFields.containsKey('name') ? 'Name' : (sObjFields.containsKey('lastname') ? 'LastName' : 'Id');
            String query = 'SELECT Id, ' + nameCol + ', CreatedById FROM ' + String.escapeSingleQuotes(objectApiName) + ' WHERE Id = :recordId LIMIT 1';
            List<SObject> records = Database.query(query);
            if (records.isEmpty()) {
                return;
            }
            sObject record = records[0];

            List<CustomNotificationType> cnType = [SELECT Id FROM CustomNotificationType WHERE DeveloperName = 'EXP_WA_Chat' LIMIT 1];
            if (cnType.isEmpty()) {
                return;
            }

            String recDisplayName = record.get(nameCol) != null ? String.valueOf(record.get(nameCol)) : 'WhatsApp Contact';
            String messageContent = recDisplayName + ' has sent a new message. Tap to view.';
            Set<String> addressee = new Set<String>();
            if (record.get('CreatedById') != null) {
                addressee.add(String.valueOf(record.get('CreatedById')));
            }
            if (String.isNotBlank(addresseeId)) {
                addressee.add(addresseeId);
            }
            if (addressee.isEmpty()) {
                return;
            }
            Messaging.CustomNotification customNotificationObj = new Messaging.CustomNotification();
            customNotificationObj.setBody(messageContent);
            customNotificationObj.setTitle('New Whatsapp Message Received');
            customNotificationObj.setNotificationTypeId(cnType[0].Id);
            customNotificationObj.setTargetId((Id) record.get('Id'));
            customNotificationObj.send(addressee);
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WAWebhook', 'sendNotificationForContact', e.getMessage());
        }
    }

    public static void parseMessages(String jsonString) {
        try {
            Map<String, Object> jsonMap = (Map<String, Object>)JSON.deserializeUntyped(jsonString);
            List<Object> entries = (List<Object>)jsonMap.get('entry');

            if (entries != null && !entries.isEmpty()) {
                for (Object entryObj : entries) {
                    Map<String, Object> entry = (Map<String, Object>)entryObj;
                    List<Object> changes = (List<Object>)entry.get('changes');

                    if (changes != null && !changes.isEmpty()) {
                        for (Object changeObj : changes) {
                            Map<String, Object> change = (Map<String, Object>)changeObj;
                            Map<String, Object> value = (Map<String, Object>)change.get('value');
                            List<Object> statuses = (List<Object>)value.get('statuses');

                            if (statuses != null && !statuses.isEmpty()) {
                                for (Object statusObj : statuses) {
                                    Map<String, Object> statusMap = (Map<String, Object>)statusObj;
                                    String status = (String) statusMap.get('status');
                                    String waid = statusMap != null ? (String) statusMap.get('id') : null;

                                    List<WA_Chat__c> waChats = [SELECT Id, Message_Status__c, Message_ID__c, Phone__c FROM WA_Chat__c WHERE Message_ID__c = :waid LIMIT 1];
                                    if (!waChats.isEmpty()) {
                                        WA_Chat__c waChat = waChats[0];
                                        if (status == 'sent' && waChat.Message_Status__c != 'Delivered' && waChat.Message_Status__c != 'Seen') {
                                            waChat.Message_Status__c = 'Sent';
                                        } else if (status == 'delivered' && waChat.Message_Status__c != 'Seen') {
                                            waChat.Message_Status__c = 'Delivered';
                                        } else if (status == 'read') {
                                            waChat.Message_Status__c = 'Seen';
                                        } else if (status == 'failed') {
                                            waChat.Message_Status__c = 'Failed';
                                            List<Object> errors = (List<Object>) statusMap.get('errors');
                                            if (errors != null && !errors.isEmpty()) {
                                                Map<String, Object> errorDetails = (Map<String, Object>) errors[0];
                                                ErrorHandler.insertErrordata(null, 'WAWebhook', 'parseMessages', 'Message failed to send. Error details: ' + JSON.serialize(errorDetails));
                                            } else {
                                                ErrorHandler.insertErrordata(null, 'WAWebhook', 'parseMessages', 'Message failed to send. Error details: ' + JSON.serialize(statusMap));
                                            }
                                        }
                                        update waChat;
                                        publishRefreshEvent('Chat', waChat.Phone__c);
                                    }
                                }
                            }

                            if (value.containsKey('event')) {
                                String event = (String) value.get('event');
                                String templateId = String.valueOf(value.get('message_template_id'));
                                updateWhatsAppTemplateStatus(templateId, event, value);
                            }
                        }
                    }
                }
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WAWebhook', 'parseMessages', e.getMessage());
        }
    }

    public static void updateWhatsAppTemplateStatus(String templateId, String event) {
        updateWhatsAppTemplateStatus(templateId, event, null);
    }

    public static void updateWhatsAppTemplateStatus(String templateId, String event, Map<String, Object> valueMap) {
        try {
            List<WA_Template__c> templates = [SELECT Id, Status__c, Previous_Status__c, Quality_Rating__c, Rejection_Reason__c, Last_Status_Update_Time__c 
                                                FROM WA_Template__c WHERE Template_Id__c = :templateId LIMIT 1];

            if (!templates.isEmpty()) {
                WA_Template__c waTemplate = templates[0];
                waTemplate.Previous_Status__c = waTemplate.Status__c;
                waTemplate.Last_Status_Update_Time__c = System.now();

                String upperEvent = String.isNotBlank(event) ? event.toUpperCase() : '';
                if (upperEvent == 'APPROVED') {
                    waTemplate.Status__c = 'Active-Quality Pending';
                    waTemplate.Rejection_Reason__c = null;
                } else if (upperEvent == 'PENDING' || upperEvent == 'IN_REVIEW') {
                    waTemplate.Status__c = 'In-Review';
                } else if (upperEvent == 'REJECTED') {
                    waTemplate.Status__c = 'Rejected';
                } else if (upperEvent == 'PAUSED') {
                    waTemplate.Status__c = 'Paused';
                } else if (upperEvent == 'DISABLED') {
                    waTemplate.Status__c = 'Disabled';
                }

                if (valueMap != null) {
                    if (valueMap.containsKey('reason') && valueMap.get('reason') != null) {
                        String r = String.valueOf(valueMap.get('reason')).trim();
                        if (String.isNotBlank(r) && !r.equalsIgnoreCase('NONE')) {
                            if (valueMap.containsKey('other_info') && valueMap.get('other_info') != null) {
                                String other = String.valueOf(valueMap.get('other_info')).trim();
                                if (String.isNotBlank(other) && !other.equalsIgnoreCase('NONE')) {
                                    r += ' - ' + other;
                                }
                            }
                            waTemplate.Rejection_Reason__c = r;
                        } else {
                            waTemplate.Rejection_Reason__c = null;
                        }
                    }
                    if (valueMap.containsKey('new_quality_score') && valueMap.get('new_quality_score') != null) {
                        waTemplate.Quality_Rating__c = String.valueOf(valueMap.get('new_quality_score'));
                    }
                }

                update waTemplate;

                publishRefreshEvent('Template', null);
            } else {
                System.debug('No WhatsApp Template found for Template Id: ' + templateId);
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WAWebhook', 'updateWhatsAppTemplateStatus', e.getMessage());
            System.debug('Error in updateWhatsAppTemplateStatus: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
        }
    }

    public static String normalizePhoneNumber(String phoneNumber) {
        if (String.isBlank(phoneNumber)) {
            return phoneNumber;
        }
        return phoneNumber.replaceAll('[\\s\\-\\(\\)\\.]+', '');
    }

    public static void publishRefreshEvent(String type, String phone) {
        try {
            String cleanPhone = normalizePhoneNumber(phone);
            WA_Refresh_Event__e refreshEvt = new WA_Refresh_Event__e();
            refreshEvt.Type__c = type;
            refreshEvt.Phone__c = cleanPhone;
            EventBus.publish(refreshEvt);
        } catch (Exception e) {
            System.debug('Could not publish WA_Refresh_Event__e: ' + e.getMessage());
        }
    }

    /**
     * @description : Retrieves ObjectConfigInfo JSON from Custom Metadata (MVEX__Object_Config__mdt)
     * @return Map<String, Object>
     */
    public static Map<String, Object> getObjectConfigInfo() {
        try {
            List<MVEX__Object_Config__mdt> configList = [SELECT Id, MVEX__ObjectConfigInfo__c FROM MVEX__Object_Config__mdt LIMIT 1];

            if (!configList.isEmpty() && String.isNotBlank(configList[0].MVEX__ObjectConfigInfo__c)) {
                return (Map<String, Object>) JSON.deserializeUntyped(configList[0].MVEX__ObjectConfigInfo__c);
            }
        } catch (Exception e) {
            System.debug('Error in getObjectConfigInfo: ' + e.getMessage());
        }

        return new Map<String, Object>();
    }
}