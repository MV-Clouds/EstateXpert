/**
* Class Name: WhatsAppMessageBatch
* Test Class: BroadcastMessageControllerTest
* Description: This class is used to send WhatsApp messages in bulk using a batch process.
* Created Date: 03 April 2025
* Created By: Rachit Shah
*--------------------------------------------------------------------------------
**/

global with sharing class WhatsAppMessageBatch2 implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful {
    
    global String templateId;
    global List<Chat__c> chatsToProcess;
    global String broadcastId;
    global String objectApiName;
    global List<Chat__c> chatsToUpdate = new List<Chat__c>();
    global static List<WBConnect_Configuration__mdt> wbConfig = WBConnect_Configuration__mdt.getAll().values(); 
    global String phoneField;
    global MVEX__WhatsappTemplate__c template;
    global List<MVEX__Template_Variable__c> templateVariables;

    // Constructor to pass Chat__c list and template data
    global WhatsAppMessageBatch2(String tempId, List<Chat__c> chats, String brId, String objName, String phoneFieldName) {
        this.chatsToProcess = chats;
        this.templateId = tempId;
        this.broadcastId = brId;
        this.objectApiName = objName;
        this.phoneField = phoneFieldName;

        // Fetch template details
        List<MVEX__WhatsappTemplate__c> templates = [
            SELECT Id, MVEX__Template_Name__c, MVEX__Template_Id__c, MVEX__Language__c, 
                   MVEX__Template_Type__c, MVEX__Template_Category__c, MVEX__Template_SubCatagory__c,
                   MVEX__WBTemplate_Body__c, MVEX__WBHeader_Body__c, MVEX__WBFooter_Body__c, 
                   MVEX__Header_Type__c, MVEX__Button_Type__c, MVEX__Button_Label__c, 
                   MVEX__WBButton_Body__c, MVEX__File_Name__c, MVEX__WBImage_Header_Handle__c, 
                   MVEX__Status__c
            FROM MVEX__WhatsappTemplate__c
            WHERE Id = :tempId
            LIMIT 1
        ];
        
        this.template = !templates.isEmpty() ? templates[0] : null;
        
        // Fetch template variables
        this.templateVariables = [
            SELECT Id, MVEX__Field_Name__c, MVEX__Object_Name__c, MVEX__Type__c, MVEX__Alternate_Text__c
            FROM MVEX__Template_Variable__c
            WHERE MVEX__WhatsappTemplate__c = :tempId
            ORDER BY CreatedDate ASC
        ];
    }

    /*
    *********************************************************
    @description     : This method is used to start the batch process and send whatsapp message.
    @param           : bc - Batchable context 
    @return          : Database.QueryLocator - query to fetch all the chat records
    ********************************************************
    */
    global Database.QueryLocator start(Database.BatchableContext bc) {
        try {
            List<Id> chatIds = new List<Id>();
            for (Chat__c chat : this.chatsToProcess) {
                chatIds.add(chat.Id);
            } 
            return Database.getQueryLocator([SELECT Id, Phone__c, WhatsAppMessageId__c, Message_Status__c FROM Chat__c WHERE Id IN :chatIds WITH USER_MODE]);
        } catch (Exception e) {
            return Database.getQueryLocator([SELECT Id FROM Chat__c WHERE Id = null]);
        }
    }

    /*
    *********************************************************
    @description     : This method is used to execute the batch process.
    @param           : bc - Batchable context
    @param           : scope - Scope of the batch process
    ********************************************************
    */
    global void execute(Database.BatchableContext bc, List<Chat__c> chatList) {
        try {
            Chat__c chat = new Chat__c();
            if(chatList.size() > 0){
                chat = chatList[0];
            }
            String phone = chat.Phone__c;
            String requestBody;
            
            String query = 'SELECT Id, ' + this.phoneField + ' FROM ' + this.objectApiName + ' WHERE ' + this.phoneField + ' =: phone ORDER BY CreatedDate DESC LIMIT 1';

            List<sObject> records = Database.query(String.escapeSingleQuotes(query));
            if(records.size() > 0){
                Map<String, String> fieldValues = fetchFieldValuesForRecord(
                    this.templateVariables, records[0].Id, this.phoneField
                );
                
                String phoneNumber = fieldValues.get(this.phoneField);
                
                if (String.isBlank(phoneNumber)) {
                    System.debug('Phone number not found for record: ' + records[0].Id);
                    return;
                }
                
                requestBody = buildWhatsAppRequestBody(
                    this.template, this.templateVariables, fieldValues, phoneNumber
                );
                List<Chat__c> cht = sendWhatsAppMessage(chat.Id, requestBody);
                if(cht.size() > 0){
                    this.chatsToUpdate.add(cht[0]);
                }
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'WhatsAppMessageBatch', 'execute', 'Error while executing WhatsAppMessageBatch');
        }
    }

    /*
    *********************************************************
    @description     : This method is used to finish the batch process and update the chat records.
    @param           : bc - Batchable context
    @return          : void
    ********************************************************
    */
    
    global void finish(Database.BatchableContext bc) {
        try {
            if (this.chatsToUpdate.size() > 0) {
                Database.update(this.chatsToUpdate, false, AccessLevel.USER_MODE);
            }
    
            if(broadcastId != null){
                Broadcast__c br = new Broadcast__c(Id = this.broadcastId);
                br.Status__c = 'Completed';
                Database.update(br, false, AccessLevel.USER_MODE);
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'WhatsAppMessageBatch', 'finish', 'Error while finishing WhatsAppMessageBatch');
        }
    }

    /*
    *********************************************************
    @description     : Fetches field values for a single record based on template variables
    @param           : templateVariables - List of template variables
    @param           : recordId - The record ID to fetch values for
    @param           : phoneField - The phone field API name
    @return          : Map<String, String> of field names to values
    ********************************************************
    */
    public static Map<String, String> fetchFieldValuesForRecord(List<MVEX__Template_Variable__c> templateVariables, Id recordId, String phoneField) {
        Map<String, String> fieldValues = new Map<String, String>();

        try {
            if (recordId == null) {
                return fieldValues;
            }
            
            String objectName = templateVariables.isEmpty() ? String.valueOf(recordId.getSObjectType()) : templateVariables[0].MVEX__Object_Name__c;
            if (String.isBlank(objectName)) {
                objectName = String.valueOf(recordId.getSObjectType());
            }
            
            // Build field list for SOQL
            Set<String> fieldSet = new Set<String>();
            fieldSet.add(phoneField); // Always include phone field
            
            for (MVEX__Template_Variable__c variable : templateVariables) {
                if (String.isNotBlank(variable.MVEX__Field_Name__c)) {
                    fieldSet.add(variable.MVEX__Field_Name__c);
                }
            }
            
            if (fieldSet.isEmpty()) {
                return fieldValues;
            }
            
            // Build and execute dynamic SOQL for single record
            String query = 'SELECT Id, ' + String.join(new List<String>(fieldSet), ', ') + 
                        ' FROM ' + objectName + 
                        ' WHERE Id = :recordId LIMIT 1';
            
            List<SObject> records = Database.query(query);
            
            if (records.isEmpty()) {
                return fieldValues;
            }
            
            SObject record = records[0];
            
            // Extract phone field value
            Object phoneValue = getFieldValue(record, phoneField);
            fieldValues.put(phoneField, phoneValue != null ? String.valueOf(phoneValue) : '');
            
            // Extract template variable field values
            for (MVEX__Template_Variable__c variable : templateVariables) {
                String fieldName = variable.MVEX__Field_Name__c;
                if (String.isNotBlank(fieldName)) {
                    Object fieldValue = getFieldValue(record, fieldName);
                    String value = formatFieldValue(fieldValue);
                    
                    // Use alternate text if field value is null or empty
                    if (String.isBlank(value) && String.isNotBlank(variable.MVEX__Alternate_Text__c)) {
                        value = variable.MVEX__Alternate_Text__c;
                    }
                    
                    fieldValues.put(variable.MVEX__Field_Name__c, value);
                }
            }
            
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WhatsAppMessageBatch', 'fetchFieldValuesForRecord', e.getMessage());   
        }
        
        return fieldValues;
    }
    
    /*
    *********************************************************
    @description     : Formats field value with proper date/datetime formatting
    @param           : fieldValue - The field value to format
    @return          : String formatted value
    ********************************************************
    */
    public static String formatFieldValue(Object fieldValue) {
        if (fieldValue == null) {
            return '';
        }
        
        try {
            // Check if it's a Date
            if (fieldValue instanceof Date) {
                Date dateValue = (Date) fieldValue;
                return dateValue.format();
            }
            
            // Check if it's a DateTime
            if (fieldValue instanceof DateTime) {
                DateTime dateTimeValue = (DateTime) fieldValue;
                return dateTimeValue.format('dd MMM yyyy') + ' at ' + dateTimeValue.format('hh:mm a');
            }
            
            // For all other types, convert to string
            return String.valueOf(fieldValue);
            
        } catch (Exception e) {
            System.debug('Error formatting field value: ' + e.getMessage());
            return String.valueOf(fieldValue);
        }
    }
    
     /*
    *********************************************************
    @description     : Utility method to get field value from SObject, including relationship fields
    @param           : record - The SObject record
    @param           : fieldPath - The field API name or relationship path
    @return          : Object field value
    ********************************************************
    */
    public static Object getFieldValue(SObject record, String fieldPath) {

        try {
            if (record == null || String.isBlank(fieldPath)) {
                return null;
            }
            
            if (fieldPath.contains('.')) {
                // Handle relationship fields
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
            ErrorHandler.insertErrordata(e, 'WhatsAppMessageBatch', 'getFieldValue', e.getMessage());
            return null;
        }  
    }

    /*
    *********************************************************
    @description     : Static method to build WhatsApp request body
    @param           : template - The template record
    @param           : templateVariables - List of template variables
    @param           : fieldValues - Map of field names to values
    @param           : phoneNumber - The recipient phone number
    @return          : String JSON request body
    ********************************************************
    */
    public static String buildWhatsAppRequestBody(MVEX__WhatsappTemplate__c template, List<MVEX__Template_Variable__c> templateVariables, Map<String, String> fieldValues, String phoneNumber) {

        try {
            // Prepare template data structure
            Map<String, Object> data = new Map<String, Object>();
            data.put('templateName', template.MVEX__Template_Name__c);
            data.put('languageCode', template.MVEX__Language__c != null ? template.MVEX__Language__c : 'en_US');
            data.put('headerImageURL', template.MVEX__WBHeader_Body__c);
            data.put('headerType', template.MVEX__Header_Type__c);
            data.put('templateType', template.MVEX__Template_Category__c);
            
            // Separate header and body parameters based on variable type
            List<Object> headerParameters = new List<Object>();
            List<Object> bodyParameters = new List<Object>();
            
            for (MVEX__Template_Variable__c variable : templateVariables) {
                String fieldValue = fieldValues.get(variable.MVEX__Field_Name__c);
                
                // Use alternate text if field value is null or empty
                if (String.isBlank(fieldValue) && String.isNotBlank(variable.MVEX__Alternate_Text__c)) {
                    fieldValue = variable.MVEX__Alternate_Text__c;
                }
                
                // Add to appropriate list based on type
                if (variable.MVEX__Type__c != null && variable.MVEX__Type__c.equalsIgnoreCase('Header')) {
                    headerParameters.add(String.isNotBlank(fieldValue) ? fieldValue : '');
                } else {
                    bodyParameters.add(String.isNotBlank(fieldValue) ? fieldValue : '');
                }
            }
            
            data.put('headerParameters', headerParameters);
            data.put('bodyParameters', bodyParameters);
            
            // Handle button value if present
            if (String.isNotBlank(template.MVEX__WBButton_Body__c)) {
                Object rawData = JSON.deserializeUntyped(template.MVEX__WBButton_Body__c);
                List<Object> dataList = (List<Object>) rawData;
                
                List<Map<String, Object>> finalList = new List<Map<String, Object>>();
                for (Object item : dataList) {
                    finalList.add((Map<String, Object>) item);
                }
                
                data.put('buttonValue', finalList);
            } else {
                data.put('buttonValue', null);
            }
            
            return createJSONBody(phoneNumber, 'template', data);
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WhatsAppMessageBatch', 'buildWhatsAppRequestBody', e.getMessage());
            return null;
        }
        
    }


    /*
    *********************************************************
    @description     : Creates the complete JSON body for WhatsApp API request
    @param           : to - Phone number to send the message
    @param           : type - Type of the message
    @param           : data - Map of data to be included in the message
    @return          : String - JSON body
    ********************************************************
    */
    global static String createJSONBody(String to, String type, Map<String, Object> data) {
        try {
            // Base Payload Structure
            Map<String, Object> payload = new Map<String, Object>();
            payload.put('messaging_product', 'whatsapp');
            payload.put('to', to);
            payload.put('type', type);

            Map<String, Object> template = new Map<String, Object>();
            template.put('name', (String)data.get('templateName'));
            template.put('language', new Map<String, Object>{ 'code' => (String)data.get('languageCode') });

            List<Map<String, Object>> components = new List<Map<String, Object>>();

            // Header Parameters (Text)
            List<Object> headerParameters = (List<Object>)data.get('headerParameters');
            if (headerParameters != null && !headerParameters.isEmpty()) {
                List<Map<String, Object>> headerParams = new List<Map<String, Object>>();
                
                for (Object param : headerParameters) {
                    headerParams.add(new Map<String, Object>{ 'type' => 'text', 'text' => String.valueOf(param) });
                }
                
                components.add(new Map<String, Object>{ 'type' => 'header', 'parameters' => headerParams });
            }

            // Header Type (Media)
            String headerType = (String)data.get('headerType');
            String headerImageURL = (String)data.get('headerImageURL');
            if (headerType != null && headerImageURL != null && headerType.toLowerCase() != 'text') {
                components.add(new Map<String, Object>{
                    'type' => 'header',
                    'parameters' => new List<Map<String, Object>>{
                        new Map<String, Object>{
                            'type' => headerType.toLowerCase(),
                            headerType.toLowerCase() => new Map<String, Object>{ 'link' => headerImageURL }
                        }
                    }
                });
            }

            Integer randomCode;
            String randomCodeStr;
            if((String)data.get('templateType') == 'Authentication'){
                randomCode = Math.abs(Math.mod(Crypto.getRandomInteger(), 900000)) + 100000;
                randomCodeStr = String.valueOf(randomCode);
            }

            // Body Parameters
            List<Object> bodyParameters = (List<Object>)data.get('bodyParameters');
            if (bodyParameters != null && !bodyParameters.isEmpty()) {
                List<Map<String, Object>> bodyParams = new List<Map<String, Object>>();
                
                for (Object param : bodyParameters) {
                    bodyParams.add(new Map<String, Object>{ 'type' => 'text', 'text' => String.valueOf(param) });
                }
                
                components.add(new Map<String, Object>{ 'type' => 'body', 'parameters' => bodyParams });
            } else if((String)data.get('templateType') == 'Authentication'){
                components.add(new Map<String, Object>{
                    'type' => 'body',
                    'parameters' => new List<Map<String, Object>>{
                        new Map<String, Object>{ 'type' => 'text', 'text' => randomCodeStr }
                    }
                });
            }

            // Button Parameters
            List<Map<String, Object>> buttonValue = (List<Map<String, Object>>)data.get('buttonValue');
            if (buttonValue != null && !buttonValue.isEmpty()) {
                Integer index = 0;
                for (Map<String, Object> button : buttonValue) {
                    String buttonType = (String)button.get('type');
                    
                    if (buttonType == 'URL') {
                        String url = (String)button.get('url');
                        
                        if (url != null && url.contains('{{1}}')) {
                            components.add(new Map<String, Object>{
                                'type' => 'button',
                                'sub_type' => 'url',
                                'index' => String.valueOf(index),
                                'parameters' => new List<Map<String, Object>>{
                                    new Map<String, Object>{
                                        'type' => 'text',
                                        'text' => url.replace('{{1}}', '')
                                    }
                                }
                            });
                        }
                    } else if (buttonType == 'PHONE_NUMBER') {
                        // No parameters needed for phone number buttons
                        // They are static in the template
                    } else if (buttonType == 'QUICK_REPLY') {
                        // No parameters needed for quick reply buttons
                        // They are static in the template
                    } else if (buttonType == 'COPY_CODE') {
                        String couponCode = (String)button.get('example');
                        
                        if (String.isNotBlank(couponCode)) {
                            components.add(new Map<String, Object>{
                                'type' => 'button',
                                'sub_type' => 'copy_code',
                                'index' => String.valueOf(index),
                                'parameters' => new List<Map<String, Object>>{
                                    new Map<String, Object>{
                                        'type' => 'coupon_code',
                                        'coupon_code' => couponCode
                                    }
                                }
                            });
                        }
                    } else if (buttonType == 'CATALOG') {
                        // Catalog button implementation
                        String thumbnailProductId = (String)button.get('thumbnailProductId');
                        
                        if (String.isNotBlank(thumbnailProductId)) {
                            components.add(new Map<String, Object>{
                                'type' => 'button',
                                'sub_type' => 'catalog',
                                'index' => String.valueOf(index),
                                'parameters' => new List<Map<String, Object>>{
                                    new Map<String, Object>{
                                        'type' => 'action',
                                        'action' => new Map<String, Object>{
                                            'thumbnail_product_retailer_id' => thumbnailProductId
                                        }
                                    }
                                }
                            });
                        }
                    } else if (buttonType == 'MPM') {
                        // Multi-product message implementation
                        List<Object> sections = (List<Object>)button.get('sections');
                        
                        if (sections != null && !sections.isEmpty()) {
                            List<Map<String, Object>> sectionsList = new List<Map<String, Object>>();
                            
                            for (Object sectionObj : sections) {
                                Map<String, Object> section = (Map<String, Object>)sectionObj;
                                String title = (String)section.get('title');
                                List<Object> productItems = (List<Object>)section.get('product_items');
                                
                                if (productItems != null && !productItems.isEmpty()) {
                                    List<Map<String, Object>> productList = new List<Map<String, Object>>();
                                    
                                    for (Object productObj : productItems) {
                                        Map<String, Object> product = (Map<String, Object>)productObj;
                                        String productRetailerId = (String)product.get('product_retailer_id');
                                        
                                        if (String.isNotBlank(productRetailerId)) {
                                            productList.add(new Map<String, Object>{
                                                'product_retailer_id' => productRetailerId
                                            });
                                        }
                                    }
                                    
                                    if (!productList.isEmpty()) {
                                        sectionsList.add(new Map<String, Object>{
                                            'title' => title,
                                            'product_items' => productList
                                        });
                                    }
                                }
                            }
                            
                            if (!sectionsList.isEmpty()) {
                                components.add(new Map<String, Object>{
                                    'type' => 'button',
                                    'sub_type' => 'mpm',
                                    'index' => String.valueOf(index),
                                    'parameters' => new List<Map<String, Object>>{
                                        new Map<String, Object>{
                                            'type' => 'action',
                                            'action' => new Map<String, Object>{
                                                'sections' => sectionsList
                                            }
                                        }
                                    }
                                });
                            }
                        }
                    } else if (buttonType == 'FLOW') {
                        // Flow button implementation
                        String flowId = (String)button.get('flowId');
                        String flowToken = (String)button.get('flowToken');
                        Map<String, Object> flowActionPayload = (Map<String, Object>)button.get('flowActionPayload');
                        
                        if (String.isNotBlank(flowId)) {
                            Map<String, Object> actionParams = new Map<String, Object>{
                                'flow_message_version' => '3',
                                'flow_id' => flowId
                            };
                            
                            if (String.isNotBlank(flowToken)) {
                                actionParams.put('flow_token', flowToken);
                            }
                            
                            if (flowActionPayload != null && !flowActionPayload.isEmpty()) {
                                actionParams.put('flow_action_payload', flowActionPayload);
                            }
                            
                            components.add(new Map<String, Object>{
                                'type' => 'button',
                                'sub_type' => 'flow',
                                'index' => String.valueOf(index),
                                'parameters' => new List<Map<String, Object>>{
                                    new Map<String, Object>{
                                        'type' => 'action',
                                        'action' => actionParams
                                    }
                                }
                            });
                        }
                    }
                    
                    index++;
                }
            }

            // Add Components to Template
            if (!components.isEmpty()) {
                template.put('components', components);
            }

            payload.put('template', template);
            return JSON.serialize(payload);
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WhatsAppMessageBatch', 'createJSONBody', e.getMessage());
            return null;
        }
    }

    /*
    *********************************************************
    @description     : This method is used to send the WhatsApp message using the WhatsApp Business API.
    @param           : chatId - Id of the chat record
    @param           : jsonBody - JSON body to be sent
    @return          : List<Chat__c> - List of chat records
    ********************************************************
    */
    @AuraEnabled(cacheable=false)
    global static List<Chat__c> sendWhatsAppMessage(String chatId, String jsonBody) {
        try {
            List<Chat__c> chat = [SELECT Id, Phone__c, WhatsAppMessageId__c, Message_Status__c FROM Chat__c WHERE Id = :chatId WITH USER_MODE LIMIT 1];
    
            HttpRequest httpReq = new HttpRequest();
            String accessToken = wbConfig[0].Access_Token__c;
            String endpoint = wbConfig[0].API_Endpoint__c + '/' + wbConfig[0].API_Version__c + '/' + wbConfig[0].Phone_Number_Id__c + '/messages';
            httpReq.setEndpoint(endpoint);
            httpReq.setMethod('POST');
            httpReq.setHeader('Content-Type', 'application/json');
            httpReq.setHeader('Authorization', 'Bearer ' + accessToken);
            httpReq.setBody(jsonBody);
            Http http = new Http();
            HttpResponse response = http.send(httpReq);
            Integer statusCode = response.getStatusCode();
            if(response != null && statusCode == 200){
                String responseBody = response.getBody();
                Map<String, Object> jsonMap = (Map<String, Object>)JSON.deserializeUntyped(responseBody);
                List<Object> messages = (List<Object>)jsonMap.get('messages');
                Map<String, Object> firstMessage = (Map<String, Object>)messages[0];
                String whatsAppMessageID = (String) firstMessage.get('id');
                chat[0].WhatsAppMessageId__c = whatsAppMessageID;
                chat[0].Message_Status__c = 'Sent';
            }else{
                chat[0].Message_Status__c = 'Failed';
            }
            return chat;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'WhatsAppMessageBatch', 'sendWhatsAppMessage', 'Error while sending WhatsApp message');
            return null;
        }
    }

    @AuraEnabled
    global static Map<String, object> getTemplateData(String templateId, String recordId, String objectApiName){return null;}

    global static String generatePayloadFromTemplateData(Map<String, Object> templateData, String to) {return null;}
}