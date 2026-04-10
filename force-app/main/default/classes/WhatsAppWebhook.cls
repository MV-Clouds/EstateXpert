/**
 * @File Name : WhatsAppWebhook.cls
 * @Description :
 * @Author :
 * @Last Modified By : ChangeMeIn@UserSettingsUnder.SFDoc
 * @Last Modified On : 04-21-2025
 * @Modification Log :
 *==============================================================================
 * Date Modified - Developer Name - Description
 * 18 Nov, 2024  - ChangeMeIn@UserSettingsUnder.SFDoc  -  Initial Version
 * 26 Mar, 2025  - Harsh Gandhi - Updated naming convention for files and made changes for saving files wih correct extentions
 **/
@RestResource(urlMapping = '/EXPDEMO/webhooks/v1/*')
global without sharing class WhatsAppWebhook{
    public static String currentTime = System.now().format('yyyy-MM-dd HH:mm:ss');
    public static String phoneNumberId = '';
    public static List<Object> messages = new List<Object>();
    public static List<MVEX__AWS_Config__c> configList = [SELECT Id, MVEX__AWS_Access_Key__c, MVEX__AWS_Secret_Access_Key__c, MVEX__S3_Bucket_Name__c, MVEX__S3_Region_Name__c, CreatedDate, LastModifiedDate FROM MVEX__AWS_Config__c LIMIT 1];
    public static MVEX__AWS_Config__c configData = !configList.isEmpty() ? configList[0] : null;

    @HttpGet // GET
    global static void doGet(){
        RestResponse response = RestContext.response;
        System.debug('Response ==>' + response);
        RestRequest request = RestContext.request;
        System.debug('request ==>' + request);
        if (request.params.get('hub.verify_token') == 'WHATSAPPTOKEN'){
            response.responseBody = Blob.valueOf(request.params.get('hub.challenge'));
        }
    }

    @HttpPost
    global static void doPost(){
        System.debug('InDoPost Method' + RestContext.request.headers.get('hub.verify_token'));
        System.debug('InDoPost Method2 ' + RestContext.request.params.get('hub.verify_token'));
        
        // Get WhatsApp's raw JSON data
        System.debug('InDoPost Method before Payload');
        String jsonString = RestContext.request.requestBody.toString();
        System.debug('InDoPost Method after payload:- ' + jsonString);
        try{
            processWhatsAppPayload(jsonString);
        } catch (Exception e){
            ErrorHandler.insertErrordata(e, 'WhatsAppWebhook', 'doPost', e.getMessage());
            System.debug('Error processing WhatsApp payload: ' + e.getMessage());
        }
    }

    public static void processWhatsAppPayload(String jsonString){
        try{
            System.debug('jsonString: ' + jsonString);
            parseMessages(jsonString);

            Map<String, Object> payload = (Map<String, Object>)JSON.deserializeUntyped(jsonString);
            System.debug('payload: ' + payload);

            List<Object> listofmessages = (List<Object>)payload.get('entry');
            Object messageobj = listofmessages[0];

            Map<String, Object> sender = new Map<String,Object>();
            if (messageobj != null){
                Map<String, Object> messageMap = (Map<String, Object>)messageobj;
                if (messageMap.get('changes') != null){
                    List<Object> changes = (List<Object>)messageMap.get('changes');
                    if (changes != null && !changes.isEmpty()){
                        Object changeObj = changes[0];
                        Map<String, Object> changeMap = (Map<String, Object>)changeObj;
                        Map<String, Object> value = (Map<String, Object>)changeMap.get('value');
                        Map<String, Object> metadata = (Map<String, Object>)value.get('metadata');
                        System.debug('value--->' + value);
                        // Extract the phone_number_id
                        phoneNumberId = (String) metadata.get('phone_number_id');
                        System.debug('phonenumberid -- ' + phoneNumberId);
                        messages = (List<Object>)value.get('messages');
                        List<Object> senders = new List<Object>();
                        senders = (List<Object>)value.get('contacts');
                        if(senders !=null && senders.size() > 0){
                            sender =  (Map<String, Object>) senders[0];
                        }
                    }
                }
            }

            if (messages != null){
                Map<String, Object> message = (Map<String, Object>)messages[0];
                processSingleMessage(message, sender);
            }
        } catch (Exception e){
            ErrorHandler.insertErrordata(e, 'WhatsAppWebhook', 'processWhatsAppPayload', e.getMessage());
            System.debug('Error in processWhatsAppPayload: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
        }
    }

    public static void processSingleMessage(Map<String, Object> message, Map<String, Object> sender){

        try{
            String senderId = (String) message.get('from');
            String messageType = (String) message.get('type');
            String whatsAppMessageID = (String) message.get('id');
            Map<String, Object> context = (Map<String, Object>)message.get('context');
            String contextId = '';
            if (context != null){
                contextId = (String) context.get('id');
                System.debug('Context ID ==> ' + contextId);
            }
            Map<String, Object> reactionMessage = (Map<String, Object>)message.get('reaction');
            String reactToMessageId = '';
            String reactedEmoji= '';
            if (reactionMessage != null){
                reactToMessageId = (String) reactionMessage.get('message_id');
                reactedEmoji= (String) reactionMessage.get('emoji');
                System.debug('Context ID ==> ' + reactToMessageId);
            }
            Integer timestampValue = Integer.valueOf(message.get('timestamp'));
            DateTime messageTime = DateTime.newInstanceGmt(1970, 1, 1, 0, 0, 0).addSeconds(timestampValue);
            // Check if it's within the last 10 minutes
            DateTime tenMinutesAgo = DateTime.now().addMinutes(-10);

            if (messageTime >= tenMinutesAgo) {
                System.debug('✅ Timestamp is within the last 10 minutes.');
            } else {
                System.debug('❌ Timestamp is older than 10 minutes.');
                return;
            }

            DateTime currentUTCDateTime = System.now();
            Timezone tzIST = Timezone.getTimeZone('Asia/Kolkata');
            Integer offsetMillis = tzIST.getOffset(currentUTCDateTime);
            Integer offsetHours = offsetMillis / (1000 * 60 * 60);
            Integer offsetMinutes = Math.abs(offsetMillis / (1000 * 60) - offsetHours * 60);
            DateTime currentISTDateTime = currentUTCDateTime.addHours(offsetHours).addMinutes(offsetMinutes);
            String formattedTime2 = currentISTDateTime.format('h:mm a');
            System.debug(formattedTime2);
            System.debug('whatsAppMessageID ==> ' + whatsAppMessageID);
            System.debug('senderId ==> ' + senderId);
            System.debug('messageType ==> ' + messageType);

            // Query to check if the message has already been processed
            List<Chat__c> existingChatRecords = [SELECT Id FROM Chat__c WHERE WhatsAppMessageId__c = :whatsAppMessageID LIMIT 1];
            if (!existingChatRecords.isEmpty()){
                System.debug('Message already processed: ' + whatsAppMessageID);
                return;
            }

            if (!senderId.contains('+')){
                senderId = '+' + senderId;
            }
            // Normalize phone number to remove spaces and formatting characters
            String formattedNumber = normalizePhoneNumber(senderId);

            Map<String, Object> profile = (Map<String, Object>) sender.get('profile');
            String senderName = (String) profile.get('name');
            String senderPhone = formattedNumber;
            List<User> userRecs = [SELECT Id, Name, Phone FROM User WHERE Phone = :formattedNumber LIMIT 1];
            String recordId = '';
            String recordName = '';
            String recordPhone = '';
            String objectApiName = '';
            SObject record;

            // Fetch metadata record from Object_Config__mdt
            List<MVEX__Object_Config__mdt> objectConfigList = [SELECT Id, MVEX__ObjectConfigInfo__c, MVEX__ChatWindowConfigInfo__c FROM MVEX__Object_Config__mdt LIMIT 1];
            if(objectConfigList.size() <= 0) {
                System.debug('Object Config not found!');
                return;
            } else {
                // Deserialize the JSON string from ObjectConfigInfo__c
                Map<String, Object> configData = (Map<String, Object>) JSON.deserializeUntyped(objectConfigList[0].MVEX__ObjectConfigInfo__c);
                Map<String, Object> chatConfigData = (Map<String, Object>) JSON.deserializeUntyped(objectConfigList[0].MVEX__ChatWindowConfigInfo__c);
                
                System.debug('configData'+ configData);
                System.debug('chatConfigData'+ chatConfigData);
    
                // Extract values from deserialized data
                objectApiName = (String) configData.get('objectApiName'); // e.g., 'Account'
                String phoneField = (String) configData.get('phoneField'); // e.g., 'Fax'
                System.debug('phoneField'+ phoneField);
                
                Map<String, Object> chatConfig = (Map<String, Object>) chatConfigData.get(objectApiName);
                String nameField = (String) chatConfig.get('nameField'); // e.g., 'Name'
                System.debug('nameField'+ nameField);
                
                System.debug('requiredFields'+ configData.get('requiredFields'));

                List<Object> requiredFieldsList = (List<Object>) configData.get('requiredFields'); 

                Map<String, Object> requiredFieldsMap = new Map<String, Object>();
                for (Object obj : requiredFieldsList) {
                    Map<String, Object> fieldData = (Map<String, Object>) obj;
                    requiredFieldsMap.put((String) fieldData.get('name'), fieldData); // Store the entire field data including type
                }
    
                // Query the object specified in objectApiName using dynamic SOQL
                String query = 'SELECT Id, Name, ' + phoneField + ' FROM ' + objectApiName + ' WHERE ' + phoneField + ' = :formattedNumber LIMIT 1';
                List<SObject> records = Database.query(query);
                
                if (!records.isEmpty()) {
                    record = records[0];
                    recordId = (String) record.get('Id');
                    recordName = (String) record.get('Name');
                    recordPhone = (String) record.get(phoneField);
                } else if (userRecs.isEmpty()) {
                    System.debug('inside debug --- ');
                    // Create a new record for the object specified in objectApiName
                    SObject newRecord = Schema.getGlobalDescribe().get(objectApiName).newSObject();
                    
                    // Populate required fields from metadata with type conversion
                    for (String fieldName : requiredFieldsMap.keySet()) {
                        Map<String, Object> fieldData = (Map<String, Object>) requiredFieldsMap.get(fieldName);
                        String value = (String) fieldData.get('value');
                        String fieldType = (String) fieldData.get('type');

                        if (fieldType == 'Date') {
                            // Convert string to Date (assuming value is in YYYY-MM-DD format)
                            if (value != null && value != '') {
                                List<String> dateParts = value.split('-');
                                if (dateParts.size() == 3) {
                                    newRecord.put(fieldName, Date.newInstance(Integer.valueOf(dateParts[0]), Integer.valueOf(dateParts[1]), Integer.valueOf(dateParts[2])));
                                }
                            }
                        } else if (fieldType == 'Datetime') {
                            // Convert string to Datetime (assuming value is in ISO 8601 format, e.g., YYYY-MM-DDTHH:mm:ssZ)
                            if (value != null && value != '') {
                                // Remove milliseconds and Z
                                String cleanValue = value.substring(0, 19).replace('T', ' ');

                                // Result: "2025-06-18 13:11:14"
                                Datetime myDate = Datetime.valueOf(cleanValue);

                                // Now you can assign to the record
                                newRecord.put(fieldName, myDate);
                                // newRecord.put(fieldName, Datetime.valueOf(value));
                            }
                        } else if(fieldType == 'Time'){
                            if (value != null && value != '') {
                                // Split the time components
                                List<String> parts = value.split(':');
                                Integer hour = Integer.valueOf(parts[0]);
                                Integer minute = Integer.valueOf(parts[1]);
                                
                                List<String> secMillis = parts[2].split('\\.');
                                Integer second = Integer.valueOf(secMillis[0]);
                                Integer millisecond = Integer.valueOf(secMillis[1]);
                                
                                // Now create Time instance
                                Time myTime = Time.newInstance(hour, minute, second, millisecond);
                                newRecord.put(fieldName, myTime);
                            }
                        } else if (fieldType == 'Boolean') {
                            // Convert string to Boolean
                            if (value != null && value != '') {
                                newRecord.put(fieldName, Boolean.valueOf(value));
                            }
                        } else if (fieldType == 'Double' || fieldType == 'Percent') {
                            // Convert string to Decimal
                            if (value != null && value != '') {
                                newRecord.put(fieldName, Decimal.valueOf(value));
                            }
                        } else {
                            // Handle String, Reference, Picklist, etc. as direct string assignment
                            newRecord.put(fieldName, value);
                        }
                    }

                    if(nameField != '' && nameField != null){
                        newRecord.put(nameField, senderName.length() > 80 ? senderName.substring(0, 80) : senderName);
                    } else {
                        newRecord.put('Name', senderName.length() > 80 ? senderName.substring(0, 80) : senderName);
                    }
                    if(phoneField != '' && phoneField != null){
                        newRecord.put(phoneField, senderPhone);
                    } else {
                        newRecord.put('Phone', senderPhone);
                    }
                    
                    insert newRecord;
                    record = newRecord;
                    
                    // Set the variables after insertion
                    recordId = (String) newRecord.get('Id');
                    recordName = (String) newRecord.get('Name');
                    recordPhone = (String) newRecord.get(phoneField);
                }
            }

            DateTime myDateTime = DateTime.now();
            // String formattedDate = myDateTime.format(' d MMM yyyy');
            Date formattedDate = myDateTime.date();

            Chat__c whatsappChat = new Chat__c();

            if (existingChatRecords.isEmpty()){

                if(messageType.equalsIgnoreCase('reaction')){
                    List<Chat__c> reactToChat = [SELECT Id, Reaction__c, Contact__c, Phone__c FROM Chat__c WHERE WhatsAppMessageId__c =:reactToMessageId];
                    if(reactToChat.size() > 0){
                        reactToChat[0].Reaction__c = reactToChat[0].Reaction__c!=null ? reactToChat[0].Reaction__c : '<|USER|>';
                        reactToChat[0].Reaction__c = reactToChat[0].Reaction__c.split('<|USER|>')[0] + '<|USER|>' + (reactedEmoji!=null ? reactedEmoji : '');
                        reactToChat[0].Last_Interaction_Date__c = System.now();
                        whatsappChat = reactToChat[0];
                        update whatsappChat;
                        Chat_Message__e reactEvent = new Chat_Message__e();
                        reactEvent.Chat_Data__c = JSON.serialize(whatsappChat);
                        reactEvent.Type__c = 'react';
                        // reactEvent.ContactId__c = whatsappChat.Contact__c;
                        reactEvent.ContactId__c = whatsappChat.Phone__c;
                        EventBus.publish(reactEvent);
                    }
                    return;
                }

                // whatsappChat.Contact__c = contact.Id;
                whatsappChat.Phone__c = senderPhone;
                whatsappChat.Type_of_Message__c = 'Inbound Messages';
                whatsappChat.Message_Type__c = messageType;
                whatsappChat.WhatsAppMessageId__c = whatsAppMessageID;
                whatsappChat.Date_of_Message__c = formattedDate;
                List<Chat__c> replyToChat = [SELECT Id FROM Chat__c WHERE WhatsAppMessageId__c != null AND WhatsAppMessageId__c =:contextId];
                whatsappChat.Reply_To__c = replyToChat.size() > 0 ? replyToChat[0].Id : null;

                if (messageType.equalsIgnoreCase('text')){
                    Map<String, Object> text = (Map<String, Object>) message.get('text');
                    String messageBody = '';
                    if(text != null && text.values() != null){
                        messageBody = (String) text.get('body');
                    }
                    whatsappChat.Message__c = messageBody;
                }
                if(userRecs.isEmpty()){
                    if (messageType.equalsIgnoreCase('image')){
                        Map<String, Object> image = (Map<String, Object>) message.get('image');
                        String imageId = (String) image.get('id');
                        String mimeType = (String) image.get('mime_type');
                        // String filename = whatsAppMessageID + '-' + mimeType;
                        String fileExtension = getFileExtension(mimeType);
                        String fileDateFormat = myDateTime.format('ddMMyyyy_HHmmss');
                        String filename = 'IMG-' + fileDateFormat + fileExtension;
    
                        Blob documentBody = handleMediaAttachment(imageId);
                        Map<String, Object> filedata = new Map<String, Object>();
                        if (documentBody != null){
                            if(configData != null) {
                                String fileUrl = AWSFilesController.uploadFileToS3(fileName, documentBody, mimeType);
                                whatsappChat.Message__c = fileUrl;
                                fileData = new Map<String, Object>{ 'fileName' => filename, 'mimeType' => mimeType };
                                whatsappChat.File_Data__c = JSON.serialize(filedata);
                            } else {
                                filedata = saveMediaToSalesforce(documentBody, filename, mimeType, recordId, objectApiName);
                                whatsappChat.Message__c = '/sfc/servlet.shepherd/version/download/'+filedata.get('contentVersionId');
                                whatsappChat.File_Data__c = JSON.serialize(fileData);
                            }
                        }
                    }
                    if (messageType.equalsIgnoreCase('document')){
                        Map<String, Object> document = (Map<String, Object>)message.get('document');
                        String mediaId = (String) document.get('id');
                        String mimeType = (String) document.get('mime_type');
                        // String filename = whatsAppMessageID + '-' + mimeType;
                        String name = (String) document.get('filename');
                        String fileExtension = getFileExtension(mimeType);
                        String filename = name + fileExtension;

                        Blob documentBody = handleMediaAttachment(mediaId);
    
                        Map<String, Object> filedata = new Map<String, Object>();
                        if (documentBody != null){
                            if(configData != null) {
                                String fileUrl = AWSFilesController.uploadFileToS3(fileName, documentBody, mimeType);
                                whatsappChat.Message__c = fileUrl;
                                fileData = new Map<String, Object>{ 'fileName' => filename, 'mimeType' => mimeType };
                                whatsappChat.File_Data__c = JSON.serialize(filedata);
                            } else {
                                filedata = saveMediaToSalesforce(documentBody, filename, mimeType, recordId, objectApiName);
                                whatsappChat.Message__c = '/sfc/servlet.shepherd/version/download/'+filedata.get('contentVersionId');
                                whatsappChat.File_Data__c = JSON.serialize(fileData);
                            }
                        }
                    }
                    if (messageType.equalsIgnoreCase('video')){
                        Map<String, Object> video = (Map<String, Object>) message.get('video');
                        String videoId = (String) video.get('id');
                        String mimeType = (String) video.get('mime_type');
                        // String filename = whatsAppMessageID + '-' + mimeType;
                        String fileExtension = getFileExtension(mimeType);
                        String fileDateFormat = myDateTime.format('ddMMyyyy_HHmmss');
                        String filename = 'VID-' + fileDateFormat + fileExtension;
    
                        Blob documentBody = handleMediaAttachment(videoId);
                        Map<String, Object> filedata = new Map<String, Object>();
                        if (documentBody != null){
                            if(configData != null) {
                                String fileUrl = AWSFilesController.uploadFileToS3(fileName, documentBody, mimeType);
                                whatsappChat.Message__c = fileUrl;
                                fileData = new Map<String, Object>{ 'fileName' => filename, 'mimeType' => mimeType };
                                whatsappChat.File_Data__c = JSON.serialize(filedata);
                            } else {
                                filedata = saveMediaToSalesforce(documentBody, filename, mimeType, recordId, objectApiName);
                                whatsappChat.Message__c = '/sfc/servlet.shepherd/version/download/'+filedata.get('contentVersionId');
                                whatsappChat.File_Data__c = JSON.serialize(fileData);
                            }
                        }
                    }
                    if (messageType.equalsIgnoreCase('audio')){
                        Map<String, Object> video = (Map<String, Object>) message.get('audio');
                        String audioId = (String) video.get('id');
                        String mimeType = (String) video.get('mime_type');
                        // String filename = whatsAppMessageID + '-' + mimeType;
                        String fileExtension = getFileExtension(mimeType);
                        String fileDateFormat = myDateTime.format('ddMMyyyy_HHmmss');
                        String filename = 'AUD-' + fileDateFormat + fileExtension;
    
                        Blob documentBody = handleMediaAttachment(audioId);
                        Map<String, Object> filedata = new Map<String, Object>();
                        if (documentBody != null){
                            if(configData != null) {
                                String fileUrl = AWSFilesController.uploadFileToS3(fileName, documentBody, mimeType);
                                whatsappChat.Message__c = fileUrl;
                                fileData = new Map<String, Object>{ 'fileName' => filename, 'mimeType' => mimeType };
                                whatsappChat.File_Data__c = JSON.serialize(filedata);
                            } else {
                                filedata = saveMediaToSalesforce(documentBody, filename, mimeType, recordId, objectApiName);
                                whatsappChat.Message__c = '/sfc/servlet.shepherd/version/download/'+filedata.get('contentVersionId');
                                whatsappChat.File_Data__c = JSON.serialize(fileData);
                            }
                        }
                    }
                    if (messageType.equalsIgnoreCase('button')){
                        Map<String, Object> button = (Map<String, Object>)message.get('button');
                        String payload = (String) button.get('payload');
                        String text = (String) button.get('text');
                        whatsappChat.Message__c = text;
                        if (contextId != null && contextId != ''){
                            whatsappChat.WhatsAppContextMessageID__c = contextId;
                        }
                        whatsappChat.Message_Type__c = 'text';
                        if (contextId != null && contextId != '') {
                            List<Chat__c> contextChats = [SELECT Id FROM Chat__c WHERE WhatsAppMessageId__c = :contextId LIMIT 1];
                            if (!contextChats.isEmpty()) {
                                List<Event> showings = [SELECT Id, Status__c, Scheduled_Date__c FROM Event WHERE Chat__c = :contextChats[0].Id LIMIT 1];
                                if (!showings.isEmpty()) {
                                    Event showing = showings[0];
                                    if (payload == 'Confirm Visit') {
                                        showing.Status__c = 'Scheduled';
                                    } else if (payload == 'Cancel') {
                                        showing.Status__c = 'Cancelled';
                                    }
                                    update showing;
                                    // Call sendWhatsAppResponse for Scheduled or Cancelled status
                                    sendWhatsAppResponse(showing.Id, showing.Status__c, senderPhone, contextId);
                                }
                            }
                        }
                    }
                }

                if (messageType.equalsIgnoreCase('interactive')) {
                    Map<String, Object> interactive = (Map<String, Object>)message.get('interactive');
                    System.debug('interactive: ' + interactive);
                    if (interactive != null) { 
                        String interactiveType = (String)interactive.get('type');
                        if (interactiveType == 'nfm_reply') {
                            Map<String, Object> nfmReply = (Map<String, Object>)interactive.get('nfm_reply');
                            System.debug('nfmReply : ' + nfmReply);
                            if (nfmReply != null) { 
                                String responseJson = (String)nfmReply.get('response_json');
                                System.debug('responseJson: ' + responseJson);
                                if (responseJson != null && contextId != null) {
                                    whatsappChat.Flow_Response_JSON__c = responseJson;

                                    Map<String, Object> flowData = getFlowJsonFromContextId(contextId);
                                    if (flowData != null) {
                                        String flowJson = (String) flowData.get('flowJson');
                                        Id flowRecordId = (Id) flowData.get('flowId');

                                        System.debug('Flow JSON associated with this response: ' + flowJson);
                                        String labelToValueJson = mapResponseToLabels(flowJson, responseJson);
                                        System.debug('Label-Value Mapped JSON: ' + labelToValueJson);

                                        createFlowSubmissionRecord(senderPhone, flowRecordId, labelToValueJson);
                                        Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(responseJson);
                                        String rescheduleDateStr = (String)responseMap.get('screen_0_reschedule_date_0');
                                        String rescheduleTimeStr = (String)responseMap.get('screen_0_reschedule_time_1');
                                        List<Chat__c> contextChats = [SELECT Id FROM Chat__c WHERE WhatsAppMessageId__c = :contextId LIMIT 1];
                                        System.debug('contextChats :'+contextChats);
                                        if (!contextChats.isEmpty()) {
                                            List<Event> showings = [SELECT Id, Status__c, MVEX__Scheduled_Date__c, MVEX__Showing_Duration__c FROM Event WHERE Chat__c = :contextChats[0].Id LIMIT 1];
                                            System.debug('showings :'+showings);
                                            if (!showings.isEmpty() && rescheduleDateStr != null && rescheduleTimeStr != null) {
                                                Event showing = showings[0];
                                                showing.Status__c = 'Rescheduled';
                                                List<String> dateParts = rescheduleDateStr.split('-');
                                                List<String> timeParts = rescheduleTimeStr.split(':');
                                                if (dateParts.size() == 3 && timeParts.size() == 2) {
                                                    // Parse date and time as local time in user's time zone
                                                    Datetime istDateTime = Datetime.newInstance(
                                                        Integer.valueOf(dateParts[0]),
                                                        Integer.valueOf(dateParts[1]),
                                                        Integer.valueOf(dateParts[2]),
                                                        Integer.valueOf(timeParts[0]),
                                                        Integer.valueOf(timeParts[1]),
                                                        0
                                                    );
                                                    // Convert to GMT for storage
                                                    Timezone userTz1 = Timezone.getTimeZone('Asia/Kolkata');
                                                    Integer offsetMillis1 = userTz1.getOffset(istDateTime);
                                                    Integer offsetHours1 = offsetMillis1 / (1000 * 60 * 60);
                                                    Integer offsetMinutes1 = Math.mod(offsetMillis1 / (1000 * 60), 60);
                                                    Datetime gmtDateTime = istDateTime.addHours(-offsetHours1).addMinutes(-offsetMinutes1);
                                                    showing.MVEX__Reschedule_Date__c = gmtDateTime;
                                                    showing.StartDateTime = gmtDateTime;
                                                    Integer duration = (Integer)showing.MVEX__Showing_Duration__c != null ? (Integer)showing.MVEX__Showing_Duration__c : 60;
                                                    showing.EndDateTime = gmtDateTime.addMinutes(duration);
                                                }
                                                System.debug('showing :'+showing);
                                                update showing;
                                                // Call sendWhatsAppResponse for Rescheduled status
                                                sendWhatsAppResponse(showing.Id, showing.Status__c, senderPhone, contextId);
                                            }
                                        }
                                    }
                                }
                            }
                            whatsappChat.Message_Type__c = 'interactive';
                            if (contextId != null && contextId != '') {
                                whatsappChat.WhatsAppContextMessageID__c = contextId;
                            }
                        }
                    }
                }
            }
            whatsappChat.Last_Interaction_Date__c = System.now();
            insert whatsappChat;
            // System.debug('Chat__c record created: ' + whatsappChat);
            Chat_Message__e newChatEvent = new Chat_Message__e();
            Chat__c chatToSend = [SELECT Id, Type_of_Message__c, WhatsAppMessageId__c, Message__c, Message_Status__c, Message_Type__c, Reply_To__c, Reaction__c, WhatsappTemplate__c, WhatsappTemplate__r.Name, CreatedDate, Last_Interaction_Date__c, Contact__c, Phone__c, File_Data__c FROM Chat__c WHERE Id =:whatsappChat.Id LIMIT 1];
            newChatEvent.Chat_Data__c = JSON.serialize(chatToSend);
            newChatEvent.Type__c = 'new';
            // newChatEvent.ContactId__c = whatsappChat.Contact__c;
            newChatEvent.ContactId__c = whatsappChat.Phone__c;
            EventBus.publish(newChatEvent);

            if(userRecs.isEmpty()){
                List<Chat__c> lastSentChat = [SELECT Id, Phone__c, CreatedById FROM Chat__c WHERE Phone__c = :formattedNumber AND Type_of_Message__c = 'Outbound Messages' ORDER BY CreatedDate DESC LIMIT 1];
                if (lastSentChat.size() > 0){
                    sendNotificationForContact(recordId, objectApiName, lastSentChat[0].CreatedById);
                } else {
                    sendNotificationForContact(recordId, objectApiName, null);
                }
            }

        } catch (Exception e){
            ErrorHandler.insertErrordata(e, 'WhatsAppWebhook', 'processSingleMessage', e.getMessage());
            System.debug('Error in processSingleMessage: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
        }
    }

    public static Map<String,Object> getFlowJsonFromContextId(String contextId) {
        try {
            if (String.isBlank(contextId)) return null;
    
            // Step 1: Get Chat__c record using contextId
            List<Chat__c> chatList = [SELECT Id, WhatsappTemplate__c FROM Chat__c WHERE WhatsAppMessageId__c = :contextId LIMIT 1];
    
            if (chatList.isEmpty()) return null;
            System.debug('ChatList: ' + chatList);
    
            Id whatsappTemplateId = chatList[0].WhatsappTemplate__c;
            if (whatsappTemplateId == null) return null;
    
            // Step 2: Get WhatsappTemplate__c record
            List<WhatsappTemplate__c> templateList = [SELECT Id, WBButton_Body__c FROM WhatsappTemplate__c WHERE Id = :whatsappTemplateId LIMIT 1];
    
            if (templateList.isEmpty()) return null;
            System.debug('TemplateList: ' + templateList);
    
            String buttonBodyJson = templateList[0].WBButton_Body__c;
            if (String.isBlank(buttonBodyJson)) return null;
    
            System.debug('Button Body JSON: ' + buttonBodyJson);
    
            // Step 3: Parse WBButton_Body__c JSON to extract flow_id
            List<Object> buttonArray = (List<Object>) JSON.deserializeUntyped(buttonBodyJson);
    
            String flowId;
            for (Object obj : buttonArray) {
                Map<String, Object> buttonObj = (Map<String, Object>) obj;
                if ((String) buttonObj.get('type') == 'FLOW' && buttonObj.containsKey('flow_id')) {
                    flowId = (String) buttonObj.get('flow_id');
                    break;
                }
            }
    
            if (String.isBlank(flowId)) return null;
    
            // Step 4: Query Flow__c using flowId
            List<Flow__c> flowList = [SELECT Id, Flow_JSON__c FROM Flow__c WHERE Flow_Id__c = :flowId LIMIT 1];
    
            if (flowList.isEmpty()) return null;
            System.debug('FlowList: ' + flowList);
    
            Flow__c flow = flowList[0];
        
            // Step 5: Reconstruct full flow JSON with screens
            String flowJsonWithScreens = flow.Flow_JSON__c;
            
            try {
                Map<String, Object> flowData = (Map<String, Object>) JSON.deserializeUntyped(flow.Flow_JSON__c);
                List<Object> screenIds = (List<Object>) flowData.get('screens');
                
                if (screenIds != null && !screenIds.isEmpty()) {
                    // Query screen data from Flow_Screen__c
                    List<Flow_Screen__c> screenRecords = [
                        SELECT Screen_Id__c, Screen_Flow_Json__c 
                        FROM Flow_Screen__c 
                        WHERE Flow__c = :flow.Id
                    ];
                    
                    // Build screen map
                    Map<String, Object> screenMap = new Map<String, Object>();
                    for (Flow_Screen__c screenRec : screenRecords) {
                        if (String.isNotBlank(screenRec.Screen_Flow_Json__c)) {
                            screenMap.put(screenRec.Screen_Id__c, JSON.deserializeUntyped(screenRec.Screen_Flow_Json__c));
                        }
                    }
                    
                    // Replace screen IDs with actual screen data
                    List<Object> fullScreens = new List<Object>();
                    for (Object screenIdObj : screenIds) {
                        String screenId = (String) screenIdObj;
                        if (screenMap.containsKey(screenId)) {
                            fullScreens.add(screenMap.get(screenId));
                        }
                    }
                    
                    // Update flow data with full screens
                    flowData.put('screens', fullScreens);
                    flowJsonWithScreens = JSON.serialize(flowData);
                }
            } catch (Exception ex) {
                System.debug('Error reconstructing flow JSON with screens: ' + ex.getMessage());
                // If reconstruction fails, return original JSON
            }

            return new Map<String, Object>{
                'flowJson' => flowJsonWithScreens,
                'flowId'   => flow.Id
            };
        } catch (Exception e){
            ErrorHandler.insertErrordata(e, 'WhatsAppWebhook', 'getFlowJsonFromContextId', e.getMessage());
            System.debug('Error in getFlowJsonFromContextId: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
            return null;
        }
    }

    public static void createFlowSubmissionRecord(String senderPhone, Id flowRecordId, String labelToValueJson) {
        try {
            // Step 1: Fetch config
            MVEX__Object_Config__mdt configMdt = [SELECT MVEX__ChatWindowConfigInfo__c FROM MVEX__Object_Config__mdt WHERE DeveloperName = 'objectConfigInfo' LIMIT 1];
            Map<String, Object> configMap = (Map<String, Object>) JSON.deserializeUntyped(configMdt.MVEX__ChatWindowConfigInfo__c);
    
            // Step 2: Dynamically construct SOSL RETURNING part
            List<String> returningParts = new List<String>();
            Map<String, String> objectToPhoneFieldMap = new Map<String, String>();
    
            for (String objectName : configMap.keySet()) {
                Map<String, Object> objConfig = (Map<String, Object>) configMap.get(objectName);
                String phoneField = (String) objConfig.get('phoneField');
    
                returningParts.add(objectName + '(Id, ' + phoneField + ')');
                objectToPhoneFieldMap.put(objectName, phoneField);
            }
    
            // Normalize phone number before search
            String normalizedPhone = normalizePhoneNumber(senderPhone);
            String soslQuery = 'FIND \'' + normalizedPhone + '\' IN PHONE FIELDS RETURNING ' + String.join(returningParts, ', ');
            System.debug('Dynamic SOSL Query: ' + soslQuery);
    
            // Step 3: Execute SOSL
            List<List<SObject>> results = Search.query(soslQuery);
            System.debug('SOSL Results: ' + results);
    
            // Step 4: Detect matched object
            String matchedObject = null;
            SObject matchedRecord = null;
    
            for (List<SObject> resultList : results) {
                if (!resultList.isEmpty()) {
                    matchedRecord = resultList[0];
                    matchedObject = matchedRecord.getSObjectType().getDescribe().getName();
                    break;
                }
            }
    
            System.debug('Matched object: ' + matchedObject);
            System.debug('Matched record: ' + matchedRecord);
    
            // Step 1: Get config for matched object
            Map<String, Object> matchedConfig = (Map<String, Object>) configMap.get(matchedObject);
            if (matchedConfig == null) {
                System.debug('No configuration found for matched object: ' + matchedObject);
                return;
            }
            
            String nameField = (String) matchedConfig.get('nameField');
            String phoneField = (String) matchedConfig.get('phoneField');
    
            // Step 2: Build dynamic query
            String normalizedPhoneForQuery = normalizePhoneNumber(senderPhone);
            String soql = 'SELECT ' + nameField + ' FROM ' + matchedObject + ' WHERE ' + phoneField + ' = :normalizedPhoneForQuery LIMIT 1';
    
            // Step 3: Execute dynamic query
            SObject matchedRecord1 = Database.query(soql);
    
            // Step 4: Access name
            String senderName = (String) matchedRecord1.get(nameField);
            System.debug('Name: ' + senderName);
    
            // Create and insert Flow_Submission__c record
            Flow_Submission__c submission = new Flow_Submission__c(
                WB_Flow__c = flowRecordId,
                Flow_Response_Mapping__c = labelToValueJson,
                Submitter_Phone__c = senderPhone,
                Submitter_Name__c = senderName
            );
            insert submission;
        } Catch (Exception e) {
            System.debug('Error in createFlowSubmissionRecord: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
             ErrorHandler.insertErrordata(e, 'WhatsAppWebhook', 'createFlowSubmissionRecord', e.getMessage());
        }
    }

    public static String mapResponseToLabels(String flowJsonStr, String responseJsonStr) {
        try {

            System.debug('flowJsonStr received in mapping method: ' + flowJsonStr);
            System.debug('responseJsonStr received in mapping method: ' + responseJsonStr);

            // Parse the flow definition and response JSON
            Map<String, Object> flowJson = (Map<String, Object>) JSON.deserializeUntyped(flowJsonStr);
            Map<String, Object> responseJson = (Map<String, Object>) JSON.deserializeUntyped(responseJsonStr);
            Map<String, Object> finalLabelToValueMap = new Map<String, Object>();

            System.debug('Flow JSON: ' + flowJson);
            System.debug('Response JSON: ' + responseJson);
            System.debug('Response JSON Keys Available: ' + String.join(new List<String>(responseJson.keySet()), ', '));
  
            // Extract screens array
            List<Object> screens = (List<Object>) flowJson.get('screens');
            Integer screenIndex = 0;
            
            // Track all field names that couldn't be matched for debugging
            List<String> unmatchedFields = new List<String>();
            
            // Check if response JSON might have nested structure by screen
            Boolean hasNestedStructure = false;
            for (String key : responseJson.keySet()) {
                if (key.startsWith('screen_') && responseJson.get(key) instanceof Map<String, Object>) {
                    hasNestedStructure = true;
                    break;
                }
            }
            System.debug('Response has nested screen structure: ' + hasNestedStructure);
    
            for (Object screenObj : screens) {
                Map<String, Object> screen = (Map<String, Object>) screenObj;
                String screenId = (String) screen.get('id');
                String screenTitle = screen.containsKey('title') ? (String)screen.get('title') : 'Screen ' + screenIndex;
                Map<String, Object> layout = (Map<String, Object>) screen.get('layout');
                Map<String, Object> screenData = (Map<String, Object>) screen.get('data');
                
                if (layout == null) {
                    System.debug('Warning: Screen at index ' + screenIndex + ' has no layout. Skipping.');
                    screenIndex++;
                    continue;
                }
                
                // Build a map of field name to expected data key from the screen's data section
                Map<String, String> fieldNameToDataKey = new Map<String, String>();
                if (screenData != null && !screenData.isEmpty()) {
                    for (String dataKey : screenData.keySet()) {
                        // Data keys follow pattern: screen_X_FIELDNAME_Y
                        // Extract FIELDNAME from the key
                        if (dataKey.startsWith('screen_' + screenIndex + '_')) {
                            String remaining = dataKey.substring(('screen_' + screenIndex + '_').length());
                            // Find the last underscore to separate field name from index
                            Integer lastUnderscore = remaining.lastIndexOf('_');
                            if (lastUnderscore > 0) {
                                String fieldName = remaining.substring(0, lastUnderscore);
                                fieldNameToDataKey.put(fieldName, dataKey);
                                System.debug('Screen ' + screenIndex + ': Mapped field "' + fieldName + '" to data key "' + dataKey + '"');
                            }
                        }
                    }
                }
                
                List<Object> layoutChildren = (List<Object>) layout.get('children');
    
                for (Object childObj : layoutChildren) {
                    Map<String, Object> child = (Map<String, Object>) childObj;
                    if (child.get('type') == 'Form') {
                        List<Object> formChildren = (List<Object>) child.get('children');
                        Integer fieldIndex = 0;
    
                        for (Object formFieldObj : formChildren) {
                            Map<String, Object> formField = (Map<String, Object>) formFieldObj;
    
                            if (formField.containsKey('name') && formField.containsKey('label')) {
                                String name = (String) formField.get('name');
                                String label = (String) formField.get('label');
    
                                Object matchedValue = null;
                                String matchedKey = null;
                                
                                // First, try to use the data key mapping from screen's data section
                                if (fieldNameToDataKey.containsKey(name)) {
                                    String dataKey = fieldNameToDataKey.get(name);
                                    if (responseJson.containsKey(dataKey)) {
                                        matchedValue = responseJson.get(dataKey);
                                        matchedKey = dataKey;
                                        System.debug('✓ Matched field "' + name + '" using data key "' + dataKey + '" with value: ' + matchedValue);
                                    }
                                }
                                
                                // If not found via data mapping, try other possible key patterns
                                if (matchedValue == null) {
                                    List<String> possibleKeys = new List<String>{
                                        name,                                                           // Direct name
                                        'screen_' + screenIndex + '_' + name + '_' + fieldIndex,       // Indexed pattern
                                        'screen_' + screenIndex + '_' + name,                          // Screen indexed
                                        screenId + '_' + name,                                         // Screen ID based
                                        name.toLowerCase(),                                            // Lowercase
                                        name.toUpperCase()                                             // Uppercase
                                    };
                                    
                                    // First, check if response has nested structure by screen
                                    if (hasNestedStructure) {
                                        List<String> nestedKeys = new List<String>{
                                            'screen_' + screenIndex,
                                            screenId
                                        };
                                        for (String nestedKey : nestedKeys) {
                                            if (responseJson.containsKey(nestedKey) && responseJson.get(nestedKey) instanceof Map<String, Object>) {
                                                Map<String, Object> nestedScreenData = (Map<String, Object>) responseJson.get(nestedKey);
                                                if (nestedScreenData.containsKey(name)) {
                                                    matchedValue = nestedScreenData.get(name);
                                                    matchedKey = nestedKey + '.' + name;
                                                    break;
                                                }
                                            }
                                        }
                                    }
                                    
                                    // If not found in nested structure, try flat structure
                                    if (matchedValue == null) {
                                        for (String key : possibleKeys) {
                                            if (responseJson.containsKey(key)) {
                                                matchedValue = responseJson.get(key);
                                                matchedKey = key;
                                                System.debug('✓ Matched field "' + name + '" using key "' + key + '" with value: ' + matchedValue);
                                                break;
                                            }
                                        }
                                    }
                                }
    
                                if (matchedValue != null) {
                                    // Handle Dropdown or CheckboxGroup
                                    if (formField.containsKey('data-source')) {
                                        List<Object> dataSource = (List<Object>) formField.get('data-source');
    
                                        // If the value is a List → CheckboxGroup
                                        if (matchedValue instanceof List<Object>) {
                                            List<Object> selectedTitles = new List<Object>();
                                            for (Object val : (List<Object>) matchedValue) {
                                                for (Object optionObj : dataSource) {
                                                    Map<String, Object> option = (Map<String, Object>) optionObj;
                                                    if (String.valueOf(option.get('id')) == String.valueOf(val)) {
                                                        selectedTitles.add(option.get('title'));
                                                        break;
                                                    }
                                                }
                                            }
                                            matchedValue = selectedTitles;
                                        }
                                        // If the value is a single item → Dropdown
                                        else {
                                            for (Object optionObj : dataSource) {
                                                Map<String, Object> option = (Map<String, Object>) optionObj;
                                                if (String.valueOf(option.get('id')) == String.valueOf(matchedValue)) {
                                                    matchedValue = option.get('title');
                                                    break;
                                                }
                                            }
                                        }
                                    }
    
                                    String keyLabel = screenTitle + ' - ' + label;
                                    
                                    // Handle duplicate labels by appending field name if key already exists
                                    if (finalLabelToValueMap.containsKey(keyLabel)) {
                                        keyLabel = screenTitle + ' - ' + label + ' (' + name + ')';
                                    }
                                    
                                    finalLabelToValueMap.put(keyLabel, matchedValue);
                                    System.debug('Added to final map: ' + keyLabel + ' = ' + matchedValue);
                                } else {
                                    // Track unmatched fields for debugging
                                    unmatchedFields.add(screenTitle + ' - ' + label + ' (field: ' + name + ')');
                                    System.debug('✗ Could not find value for field "' + name + '" (label: "' + label + '") in screen "' + screenTitle + '"');
                                }
                                fieldIndex++;
                            }
                        }
                    }
                }
                screenIndex++;
            }
    
            return JSON.serialize(finalLabelToValueMap);
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WhatsAppWebhook', 'mapResponseToLabels', e.getMessage());
            System.debug('Error in mapResponseToLabels: ' + e.getMessage() + ' at line ' + e.getLineNumber());
            return null;
        }
    }

    public static String getFileExtension(String mimeType){
        if (mimeType.equals('image/jpeg')){
            return '.jpeg';
        } else if (mimeType.equals('image/png')){
            return '.png';
        } else if (mimeType.equals('image/jpg')){
            return '.jpg';
        } else if (mimeType.equals('audio/mp3') || mimeType.equals('audio/mpeg')){
            return '.mp3';
        } else if (mimeType.equals('audio/aac')){
            return '.aac';
        } else if (mimeType.equals('audio/ogg; codecs=opus')){
            return '.ogg';
        } else if (mimeType.equals('video/mp4')){
            return '.mp4';
        } else if (mimeType.equals('video/3gp')){
            return '.3gp';
        } else if (mimeType.equals('application/pdf')){
            return '.pdf';
        } else if (mimeType.equals('application/msword')){
            return '.doc';
        } else if (mimeType.equals('application/vnd.openxmlformats-officedocument.wordprocessingml.document')){
            return '.docx';
        } else if (mimeType.equals('application/vnd.ms-powerpoint')){
            return '.ppt';
        } else if (mimeType.equals('application/vnd.openxmlformats-officedocument.presentationml.presentation')){
            return '.pptx';
        } else if (mimeType.equals('application/vnd.ms-excel')){
            return '.xls';
        } else if (mimeType.equals('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')){
            return '.xlsx';
        } else if (mimeType.equals('text/plain')){
            return '.txt';
        } else{
            return '.bin';
        }
    }

    // @future(callout=true)
    public static Blob handleMediaAttachment(String documentId){
        try{
            String accessToken = '';
            List<MVEX__WBConnect_Configuration__mdt> config = MVEX__WBConnect_Configuration__mdt.getAll().values();
            accessToken = config[0].MVEX__Access_Token__c;
            String mediaUrl = config[0].MVEX__APIEndpoint__c + '/' + config[0].MVEX__APIVersion__c + '/' + documentId;
            
            if (accessToken != ''){
                HttpRequest req = new HttpRequest();
                req.setEndpoint(mediaUrl);
                req.setMethod('GET');
                req.setHeader('Authorization', 'Bearer ' + accessToken);
                HttpResponse res;

                try{
                    Http http = new Http();
                    res = http.send(req);
                    System.debug('res:- '+res);

                    if (res.getStatusCode() == 200){
                        // Parse the metadata response
                        Map<String, Object> mediaMetadata = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
                        String downloadUrl = (String) mediaMetadata.get('url'); // Retrieve download URL from metadata
                        system.debug('mediaid url===> ' + downloadUrl);

                        // Download the media content
                        return downloadMediaContent(downloadUrl, accessToken);
                    } else{
                        ErrorHandler.insertErrordata(null, 'WhatsAppWebhook', 'handleMediaAttachment', 'Failed to retrieve media metadata. Status: ' + res.getStatus() + ', Response: ' + res.getBody());
                        System.debug('Failed to retrieve media metadata. Status: ' + res.getStatus() + ', Response: ' + res.getBody());
                        return null;
                    }
                } catch (Exception e){
                    ErrorHandler.insertErrordata(e, 'WhatsAppWebhook', 'handleMediaAttachment', e.getMessage());
                    System.debug('Error in handleMediaAttachment: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
                    return null;
                }
            } else{
                ErrorHandler.insertErrordata(null, 'WhatsAppWebhook', 'handleMediaAttachment', 'Failed to fetch access token or endpoint.');
                System.debug('Failed fetched access token and endpoint from custom labels');
                return null;
            }
        } catch (Exception e){
            ErrorHandler.insertErrordata(e, 'WhatsAppWebhook', 'processSingleMessage', e.getMessage());
            System.debug('Error in handleMediaAttachment: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
            return null;
        }
    }

    public static Blob downloadMediaContent(String mediaUrl, String accessToken){
        HttpRequest req = new HttpRequest();
        req.setEndpoint(mediaUrl);
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        HttpResponse res;

        try{
            Http http = new Http();
            res = http.send(req);

            if (res.getStatusCode() == 200){
                // Return the binary data
                return res.getBodyAsBlob();
            } else{
                ErrorHandler.insertErrordata(null, 'WhatsAppWebhook', 'downloadMediaContent', res.getBody());
                System.debug('Failed to download media. Status: ' + res.getStatus() + ', Response: ' + res.getBody());
                return null;
            }
        } catch (Exception e){
            ErrorHandler.insertErrordata(e, 'WhatsAppWebhook', 'downloadMediaContent', e.getMessage());
            System.debug('Error in downloadMediaContent: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
            return null;
        }
    }

    public static Map<String, Object> saveMediaToSalesforce(Blob mediaBlob, String filename, String mimeType, Id parentRecordId, String objectApiName){
        Map<String, Object> fileData = new Map<String, Object>();
        try{
            // Lead contact = [SELECT Id, Name, OwnerId FROM Lead WHERE Id = :parentRecordId LIMIT 1];
            // Query the object specified in objectApiName using dynamic SOQL
            String query = 'SELECT Id, CreatedById FROM ' + objectApiName + ' WHERE Id = :parentRecordId LIMIT 1';
            List<SObject> records = Database.query(query);
            SObject record = records[0];

            // Create ContentVersion with Contact's OwnerId
            System.debug('filename--> '+ filename);
            ContentVersion contentVersion = new ContentVersion(
                Title = filename, 
                VersionData = mediaBlob, 
                PathOnClient = filename, 
                ContentLocation = 'S', 
                OwnerId = (Id) record.get('CreatedById')
            );

            insert contentVersion;

            ContentVersion insertedContentVersion = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :contentVersion.Id LIMIT 1];
            String contentDocumentId = insertedContentVersion.ContentDocumentId;

            CDLWrapper cdlWrap = new CDLWrapper((String) record.get('Id'), contentDocumentId);
            String body = JSON.Serialize(cdlWrap);

            sendEmail(body);


            System.debug('Media file saved as ContentDocument Id: ' + contentDocumentId);

            // Construct fileData object
            fileData = new Map<String, Object>{ 'fileName' => filename, 'documentId' => contentDocumentId, 'contentVersionId' => contentVersion.Id, 'mimeType' => mimeType };

        } catch (Exception e){
            ErrorHandler.insertErrordata(e, 'WhatsAppWebhook', 'saveMediaToSalesforce', e.getMessage());
            System.debug('Error in saveMediaToSalesforce: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
        }
        return filedata;
    }

    public static void sendNotificationForContact(String recordId, String objectApiName, String addresseeId){
        try{
            String query = 'SELECT Id, Name, CreatedById FROM ' + objectApiName + ' WHERE Id = :recordId LIMIT 1';
            List<SObject> records = Database.query(query);
            sObject record = records[0];

            List<CustomNotificationType> cnType = [SELECT Id FROM CustomNotificationType WHERE DeveloperName = 'WBConnectNotification' LIMIT 1];

            // Id userId = Userinfo.getUserId();
            String messageContent = (String) record.get('Name') + ' has sent a new message. Tap to view.';
            // Prepare the custom notification object
            Set<String> addressee = new Set<String>();
            addressee.add((Id) record.get('CreatedById'));
            if( addresseeId != null && addresseeId != ''){
                addressee.add((Id) addresseeId);
            }
            Messaging.CustomNotification customNotificationObj = new Messaging.CustomNotification();
            customNotificationObj.setBody(messageContent);
            customNotificationObj.setTitle('New Whatsapp Message Received');
            customNotificationObj.setNotificationTypeId(cnType[0].Id);
            customNotificationObj.setTargetId((Id) record.get('Id'));
            customNotificationObj.send(addressee);

        } catch (Exception e){
            ErrorHandler.insertErrordata(e, 'WhatsAppWebhook', 'sendNotificationForContact', e.getMessage());
        }
    }

    public static void parseMessages(String jsonString){
        try{
            Map<String, Object> jsonMap = (Map<String, Object>)JSON.deserializeUntyped(jsonString);
            List<Object> entries = (List<Object>)jsonMap.get('entry');

            if (entries != null && !entries.isEmpty()){
                for (Object entryObj : entries){
                    Map<String, Object> entry = (Map<String, Object>)entryObj;
                    List<Object> changes = (List<Object>)entry.get('changes');

                    if (changes != null && !changes.isEmpty()){
                        for (Object changeObj : changes){
                            Map<String, Object> change = (Map<String, Object>)changeObj;
                            Map<String, Object> value = (Map<String, Object>)change.get('value');
                            List<Object> statuses = (List<Object>)value.get('statuses');

                            if (statuses != null && !statuses.isEmpty()){
                                for (Object statusObj : statuses){
                                    Map<String, Object> statusMap = (Map<String, Object>)statusObj;
                                    String status = (String) statusMap.get('status');
                                    String waid = statusMap!= null ? (String) statusMap.get('id') : null;

                                    List<Chat__c> waChats = [SELECT Id, Message_Status__c, WhatsAppMessageId__c, Phone__c FROM Chat__c WHERE WhatsAppMessageId__c = :waid LIMIT 1];
                                    if(waChats.size() > 0){
                                        Chat__c waChat = waChats[0];
                                        if (status == 'sent' && waChat.Message_Status__c != 'Delivered' && waChat.Message_Status__c != 'Seen'){
                                            waChat.Message_Status__c = 'Sent';
                                        } else if (status == 'delivered' && waChat.Message_Status__c != 'Seen'){
                                            waChat.Message_Status__c = 'Delivered';
                                        } else if (status == 'read'){
                                            waChat.Message_Status__c = 'Seen';
                                        } else if (status == 'failed') {
                                            waChat.Message_Status__c = 'Failed';
                                            // Extract error details and log the exception
                                            List<Object> errors = (List<Object>) statusMap.get('errors');
                                            if (errors != null && !errors.isEmpty()) {
                                                Map<String, Object> errorDetails = (Map<String, Object>) errors[0];
                                                ErrorHandler.insertErrordata(null, 'WhatsAppWebhook', 'parseMessages', 'Message failed to send. Error details: ' + JSON.serialize(errorDetails));
                                            } else {
                                                // Fallback if 'errors' object is missing
                                                ErrorHandler.insertErrordata(null, 'WhatsAppWebhook', 'parseMessages', 'Message failed to send. Error details: ' + JSON.serialize(statusMap));
                                            }
                                        }
                                        update waChat;
                                        Chat_Message__e statusChangeEvent = new Chat_Message__e();
                                        statusChangeEvent.Chat_Data__c = JSON.serialize(waChat);
                                        // statusChangeEvent.ContactId__c = waChat.Contact__c;
                                        statusChangeEvent.ContactId__c = waChat.Phone__c;
                                        statusChangeEvent.Type__c = 'status';
                                        EventBus.publish(statusChangeEvent);
                                    }

                                }
                            }

                            if (value.containsKey('event')){
                                String event = (String) value.get('event');
                                String templateId = String.valueOf(value.get('message_template_id'));
                                updateWhatsAppTemplateStatus(templateId, event);
                            }
                        }
                    }
                }
            }
        } catch (Exception e){
            ErrorHandler.insertErrordata(e, 'WhatsAppWebhook', 'parseMessages', e.getMessage());
            System.debug('Error in parseMessages: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
        }
    }

    // @future(callout = true)
    public static void updateWhatsAppTemplateStatus(String templateId, String event){
        try{
            List<WhatsappTemplate__c> templates = [SELECT Id, Status__c FROM WhatsappTemplate__c WHERE Template_Id__c = :templateId LIMIT 1];

            if (!templates.isEmpty()){
                WhatsappTemplate__c waTemplate = templates[0];

                if (event == 'APPROVED'){
                    waTemplate.Status__c = 'Active-Quality Pending';
                } else if (event == 'PENDING'){
                    waTemplate.Status__c = 'In-Review';
                } else if (event == 'REJECTED'){
                    waTemplate.Status__c = 'Rejected';
                }
                update waTemplate;

                MVEX__Template_Update__e templateStatusEvent = new MVEX__Template_Update__e();
                templateStatusEvent.MVEX__Template_Id__c = waTemplate.Id;
                templateStatusEvent.MVEX__Template_Status__c = waTemplate.Status__c;
                EventBus.publish(templateStatusEvent);

            } else{
                System.debug('No WhatsApp Template found for Template Id: ' + templateId);
            }
        } catch (Exception e){
            System.debug('Error in updateWhatsAppTemplateStatus: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
        }
    }

    @future(callout = true)
    public static void sendEmail(String body){
        try{
            EmailServicesAddress esa = [SELECT EmailDomainName, LocalPart FROM EmailServicesAddress WHERE Function.FunctionName =: 'EmailService_WhatsApp' LIMIT 1];
         
            Messaging.SingleEmailMessage emailNotification = new Messaging.SingleEmailMessage();        
            List<String> toAddresses = new List<String>();
            toAddresses.add(esa.LocalPart+'@' +esa.EmailDomainName);
            // if ( owea.size() > 0 ) {
            //     emailNotification.setOrgWideEmailAddressId(owea.get(0).Id);
            // }
            emailNotification.setToAddresses(toAddresses);
            emailNotification.setSubject('Three Object Form');
            emailNotification.setPlainTextBody(body);
            Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ emailNotification });


        } catch (Exception e){
            ErrorHandler.insertErrordata(e, 'WhatsAppWebhook', 'sendEmail', e.getMessage());
            System.debug('Error in sendEmailViaGmail: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
        }
    }

    public class CDLWrapper{
        public String linkedEntityId;
        public String contentDocumentId;
        public CDLWrapper(String linkedEntityId, String contentDocumentId){
            this.linkedEntityId = linkedEntityId;
            this.contentDocumentId = contentDocumentId;
        }
    }

    /**
     * Normalize phone number by removing spaces, dashes, parentheses, and other formatting characters
     * This ensures consistent phone number comparison regardless of formatting
     */
    public static String normalizePhoneNumber(String phoneNumber) {
        if (String.isBlank(phoneNumber)) {
            return phoneNumber;
        }
        // Remove all spaces, dashes, parentheses, and dots
        return phoneNumber.replaceAll('[\\s\\-\\(\\)\\.]+', '');
    }

    public static void sendWhatsAppResponse(String showingId, String status, String phoneNumber, String contextId) {
        try {
            // Define the message based on the showing status
            String message;
            if (status == 'Scheduled') {
                message = 'Thank you for confirming your site visit message.';
            } else if (status == 'Rescheduled') {
                message = 'Thank you for rescheduling the site visit. Please wait for the confirmation from our team.';
            } else if (status == 'Cancelled') {
                message = 'Your site visit has been successfully cancelled. We appreciate your notification. Please contact us if you have any further questions.';
            } else {
                return; // Exit if status is not recognized
            }

            // Create a new Chat__c record
            Chat__c chat = new Chat__c();
            chat.Message__c = message;
            chat.Phone__c = phoneNumber;
            chat.Type_of_Message__c = 'Outbound Messages';
            chat.Message_Type__c = 'text';
            chat.Message_Status__c = null;
            chat.Last_Interaction_Date__c = System.now();
            chat.Date_of_Message__c = Date.today();
            if (String.isNotBlank(contextId)) {
                List<Chat__c> contextChats = [SELECT Id FROM Chat__c WHERE WhatsAppMessageId__c = :contextId LIMIT 1];
                if (!contextChats.isEmpty()) {
                    chat.Reply_To__c = contextChats[0].Id;
                }
            }

            insert chat;

            // Link the Chat__c record to the Event record
            // Event showing = new Event(Id = showingId, Chat__c = chat.Id);
            // update showing;

            // Publish platform event for the new chat
            // Chat_Message__e newChatEvent = new Chat_Message__e();
            // Chat__c chatToSend = [SELECT Id, Type_of_Message__c, WhatsAppMessageId__c, Message__c, Message_Status__c, Message_Type__c, Reply_To__c, Reaction__c, WhatsappTemplate__c, WhatsappTemplate__r.Name, CreatedDate, Last_Interaction_Date__c, Phone__c, File_Data__c 
            //                     FROM Chat__c WHERE Id = :chat.Id LIMIT 1];
            // newChatEvent.Chat_Data__c = JSON.serialize(chatToSend);
            // newChatEvent.Type__c = 'new';
            // newChatEvent.ContactId__c = chatToSend.Phone__c;
            // EventBus.publish(newChatEvent);

            // Call the asynchronous method to send the WhatsApp message
            sendWhatsAppMessageAsync(chat.Id, showingId, phoneNumber, message, contextId);
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WhatsAppWebhook', 'sendWhatsAppResponse', e.getMessage());
            System.debug('Error in sendWhatsAppResponse: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
        }
    }

    @future(callout=true)
    public static void sendWhatsAppMessageAsync(String chatId, String showingId, String phoneNumber, String message, String contextId) {
        try {
            // Prepare JSON payload for WhatsApp message
            Map<String, Object> payload = new Map<String, Object>{
                'messaging_product' => 'whatsapp',
                'to' => phoneNumber.replace('+', ''), // Remove '+' from phone number
                'type' => 'text',
                'text' => new Map<String, Object>{ 'body' => message }
            };
            if (String.isNotBlank(contextId)) {
                payload.put('context', new Map<String, Object>{ 'message_id' => contextId });
            }
            String jsonData = JSON.serialize(payload);

            // Send WhatsApp message
            List<WBConnect_Configuration__mdt> config = WBConnect_Configuration__mdt.getAll().values();
            Chat__c chat = new Chat__c(Id = chatId);
            if (config.isEmpty()) {
                chat.Message_Status__c = 'Failed';
                update chat;
                return;
            }

            String accessToken = config[0].Access_Token__c;
            String endpoint = config[0].API_Endpoint__c + '/' + config[0].API_Version__c + '/' + config[0].Phone_Number_Id__c + '/messages';

            HttpRequest httpReq = new HttpRequest();
            httpReq.setEndpoint(endpoint);
            httpReq.setMethod('POST');
            httpReq.setHeader('Content-Type', 'application/json');
            httpReq.setHeader('Authorization', 'Bearer ' + accessToken);
            httpReq.setBody(jsonData);

            Http http = new Http();
            HttpResponse response = http.send(httpReq);
            Integer statusCode = response.getStatusCode();

            if (statusCode == 200) {
                Map<String, Object> jsonMap = (Map<String, Object>)JSON.deserializeUntyped(response.getBody());
                List<Object> messages = (List<Object>)jsonMap.get('messages');
                Map<String, Object> firstMessage = (Map<String, Object>)messages[0];
                String whatsAppMessageID = (String) firstMessage.get('id');

                chat.WhatsAppMessageId__c = whatsAppMessageID;
                chat.Message_Status__c = 'Sent';
            } else {
                chat.Message_Status__c = 'Failed';
            }

            update chat;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WhatsAppWebhook', 'sendWhatsAppMessageAsync', e.getMessage());
            System.debug('Error in sendWhatsAppMessageAsync: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
        }
    }
}