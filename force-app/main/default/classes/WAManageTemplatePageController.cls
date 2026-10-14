/**
 * @description       : Controller for managing WhatsApp message templates.
 *                      Handles fetching, picklist values, creation, editing, deletion, cloning,
 *                      uploading media, and sending preview WhatsApp message templates (WA_Template__c),
 *                      referencing OAuth_Configuration__mdt for the Whatsapp_OAuth custom metadata record.
 * @author            : Karan Singh
 * @last modified on  : 09/10/2026
 **/
public with sharing class WAManageTemplatePageController {

    /**
     * @description : Retrieves the WhatsApp OAuth Custom Metadata configuration record for Whatsapp_OAuth
     * @return OAuth_Configuration__mdt
     */
    public static OAuth_Configuration__mdt getConfig() {
        try {
            String CONFIGDEVNAME = WhatsappConnectController.CONFIG_DEV_NAME;

            List<OAuth_Configuration__mdt> configs = [SELECT Id, DeveloperName, MasterLabel, Client_Id__c, Client_Secret__c, Config_Id__c, API_Version__c, 
                                                        Authorization_Endpoint__c, Token_Endpoint__c, Access_Token__c, Client_App_ID__c, Client_Business_Account_ID__c,
                                                        Client_Phone_Number_ID__c, Connected_Date__c, SystemModstamp FROM OAuth_Configuration__mdt
                                                        WHERE DeveloperName = :CONFIGDEVNAME WITH USER_MODE LIMIT 1];
            return configs.isEmpty() ? null : configs[0];
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WAManageTemplatePageController', 'getConfig', e.getMessage());
            return null;
        }
    }

    /*
    *********************************************************
    @description     : Used in waTemplateHomePage / template list to get all WA_Template__c records.
    @return          : List<WA_Template__c>
    ********************************************************
    */
    @AuraEnabled
    public static List<WA_Template__c> getWhatsAppTemplates() {
        try {
            List<WA_Template__c> templates = [SELECT Id, Name, Template_Id__c, Template_Name__c, Template_Category__c, toLabel(Language__c) LanguageLabel,
                                                File_Name__c, Image_Header_Handle__c, Status__c, LastModifiedById, LastModifiedDate, CreatedDate
                                                FROM WA_Template__c WITH USER_MODE ORDER BY LastModifiedDate DESC LIMIT 50000];
            return templates;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WAManageTemplatePageController', 'getWhatsAppTemplates', e.getMessage());
            return new List<WA_Template__c>();
        }
    }

    /*
    *********************************************************
    @description     : Used to fetch all the fields directly related to object name
    @param           : objectName
    @return          : List<Map<String, String>> fieldOptions
    ********************************************************
    */
    @AuraEnabled
    public static List<Map<String, String>> getObjectFields(String objectName) {
        List<Map<String, String>> fieldList = new List<Map<String, String>>();
        try {
            if (String.isBlank(objectName)) {
                return fieldList;
            }
            Schema.SObjectType sObjectType = Schema.getGlobalDescribe().get(objectName);
            if (sObjectType != null) {
                Map<String, Schema.SObjectField> fieldsMap = sObjectType.getDescribe().fields.getMap();
                for (Schema.SObjectField field : fieldsMap.values()) {
                    Schema.DescribeFieldResult fieldDescribe = field.getDescribe();
                    fieldList.add(new Map<String, String>{
                        'label' => fieldDescribe.getLabel(),
                        'value' => fieldDescribe.getName()
                    });
                }
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WAManageTemplatePageController', 'getObjectFields', e.getMessage());
        }
        return fieldList;
    }


    /*
    *********************************************************
    @description     : Fetches template data and variable mapping using WA_Template__c and WA_Template_Variable__c.
    @param           : templateId
    @return          : TemplateDataWrapper
    ********************************************************
    */
    @AuraEnabled
    public static TemplateDataWrapper getDynamicObjectData(Id templateId) {
        TemplateDataWrapper wrapper = new TemplateDataWrapper();
        Set<String> objectNames = new Set<String>();
        Set<String> fieldNames = new Set<String>();
        wrapper.templateVariables = new List<Map<String, String>>();

        try {
            List<WA_Template__c> templates = [SELECT Id, Name, Template_Name__c, Button_Body__c, Status__c, Image_Header_Handle__c, Template_Id__c, Button_Label__c, 
                                                Button_Type__c, File_Name__c, Footer_Body__c, Header_Body__c, Header_Type__c, Language__c, Template_Body__c, 
                                                Template_Category__c, Template_Miscellaneous_Data__c, Last_Meta_Edit_Time__c, Edit_Timestamps_JSON__c,
                                                Edit_Count_30_Days__c, Quality_Rating__c, Rejection_Reason__c, Previous_Status__c
                                                FROM WA_Template__c  WHERE Id = :templateId WITH USER_MODE
                                                ORDER BY LastModifiedDate DESC LIMIT 1];

            if (templates.isEmpty()) {
                return wrapper; 
            }

            WA_Template__c template = templates[0];
            wrapper.template = template;

            // Evaluate edit eligibility based on Meta 24h & 30-day policies
            Map<String, Object> eligibility = evaluateEditEligibility(template);
            wrapper.canEdit = (Boolean) eligibility.get('canEdit');
            wrapper.editBlockReason = (String) eligibility.get('reason');
            wrapper.hoursRemaining = (Integer) eligibility.get('hoursRemaining');
            wrapper.minutesRemaining = (Integer) eligibility.get('minutesRemaining');
            wrapper.editsUsed30Days = (Integer) eligibility.get('editsUsed30Days');
            wrapper.editsRemaining30Days = (Integer) eligibility.get('editsRemaining30Days');

            if (template.Header_Type__c == 'Image' || template.Header_Type__c == 'Video' || template.Header_Type__c == 'Document') {
                wrapper.isImgUrl = true;
            }

            List<WA_Template_Variable__c> templateVariables = [SELECT Name, Object_Name__c, Field_Name__c, Type__c, Alternate_Text__c FROM WA_Template_Variable__c 
                                                                WHERE WA_Template__c = :template.Id WITH USER_MODE];

            if (!templateVariables.isEmpty()) {
                for (WA_Template_Variable__c variable : templateVariables) {
                    Map<String, String> mapping = new Map<String, String>();
                    mapping.put('type', variable.Type__c);
                    mapping.put('variable', variable.Name);
                    mapping.put('objName', variable.Object_Name__c);
                    mapping.put('alternateText', variable.Alternate_Text__c);
                    mapping.put('fieldName', variable.Field_Name__c);
                    wrapper.templateVariables.add(mapping);

                    objectNames.add(variable.Object_Name__c);
                    fieldNames.add(variable.Field_Name__c);
                }

                wrapper.objectNames = new List<String>(objectNames);
                wrapper.fieldNames = new List<String>(fieldNames);
            }

        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WAManageTemplatePageController', 'getDynamicObjectData', e.getMessage());
        }

        return wrapper;
    }

    /*
    *********************************************************
    @description     : Callout to create template in Meta Graph API and save WA_Template__c.
    @param           : serializedWrapper, payloadWrapper, templateName
    @return          : Map<String, Object>
    ********************************************************
    */
    @AuraEnabled
    public static Map<String, Object> createWhatsappTemplate(String serializedWrapper, String payloadWrapper, String templateName) {
        Map<String, Object> response = new Map<String, Object>();

        try {
            OAuth_Configuration__mdt config = getConfig();
            if(config == null){
                response.put('success', false);
                response.put('errorMessage', 'OAuth_Configuration__mdt is not configured in Custom Metadata (OAuth_Configuration__mdt).');
                return response;
            }

            if(String.isBlank(config.Access_Token__c) || String.isBlank(config.Client_Business_Account_ID__c) || String.isBlank(config.API_Version__c) || String.isBlank(config.Authorization_Endpoint__c)){
                response.put('success', false);
                response.put('errorMessage', 'One of the following is not configured in Custom Metadata (OAuth_Configuration__mdt): Access Token, Business Account ID, API Version, Authorization Endpoint.');
                return response;
            }

            String wabaId = config.Client_Business_Account_ID__c;
            String token = config.Access_Token__c;
            String apiVersion = config.API_Version__c;
            String endpoint = config.Authorization_Endpoint__c.removeEnd('/') + '/' + apiVersion + '/' + wabaId + '/message_templates';

            WATemplateWrapper.TemplateWrapper templateWrapper = (WATemplateWrapper.TemplateWrapper) JSON.deserialize(serializedWrapper, WATemplateWrapper.TemplateWrapper.class);
            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(payloadWrapper);
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + token);
            req.setBody(JSON.serialize(payload));
    
            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                Id templateId = WATemplateWrapper.handleSuccessResponse((String) responseMap.get('id'), (String) responseMap.get('status'), payload, templateWrapper);
                response.put('success', true);
                response.put('templateId', templateId); 
            } else {
                response.put('success', false);
                response.put('errorMessage', res.getBody());

                if (String.isNotBlank(templateWrapper.tempImgId)) {
                    List<ContentVersion> versions = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :templateWrapper.tempImgId WITH USER_MODE LIMIT 1];

                    if (!versions.isEmpty() && Schema.sObjectType.ContentDocument.isDeletable()) {
                        delete new ContentDocument(Id = versions[0].ContentDocumentId);
                    }
                }

                ErrorHandler.insertErrordata(null, 'WAManageTemplatePageController', 'createWhatsappTemplate', 'HTTP callout failed with status: ' + res.getStatusCode() + ' - ' + res.getBody());
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WAManageTemplatePageController', 'createWhatsappTemplate', e.getMessage());
            if (e instanceof CalloutException && e.getMessage().containsIgnoreCase('Read timed out')) {
                response.put('success', false);
                response.put('status', 'warning');
                response.put('message', 'Template is being created, you will be notified once it is ready.');
            } else {
                response.put('success', false);
                response.put('status', 'error');
                response.put('message', e.getMessage());
            }
        }

        return response;
    }

    /*
    *********************************************************
    @description     : Method to get session Id for uploading file to Meta using OAuth_Configuration__mdt.
    @param           : fileName, fileLength, fileType
    @return          : sessionId
    ********************************************************
    */
    public static String startUploadSession(String fileName, Integer fileLength, String fileType, OAuth_Configuration__mdt config) {
        try {
            String appId = config.Client_App_ID__c;
            String apiVersion = config.API_Version__c;
            String endpoint = config.Authorization_Endpoint__c + '/' + apiVersion + '/' + appId + '/uploads';
            String token = config.Access_Token__c;

            Map<String, Object> payload = new Map<String, Object>();
            payload.put('file_name', fileName);
            payload.put('file_length', fileLength);
            payload.put('file_type', fileType);

            HttpRequest req = new HttpRequest();
            Http http = new Http();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'OAuth ' + token);
            req.setBody(JSON.serialize(payload));

            HttpResponse res = http.send(req);
            if (res.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                String sessionId = (String) responseMap.get('id');
                if (sessionId != null && sessionId.startsWith('upload:')) {
                    sessionId = sessionId.replace('upload:', ''); 
                }
                return sessionId; 
            } else {
                ErrorHandler.insertErrordata(null, 'WAManageTemplatePageController', 'startUploadSession', 'HTTP callout failed with status: ' + res.getStatusCode() + ' - ' + res.getBody());
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WAManageTemplatePageController', 'startUploadSession', e.getMessage());
        }
        return null;
    }        

    /*
    *********************************************************
    @description     : Method to upload file chunk to Meta and get file handle.
    @param           : serializedWrapper, isAWSEnabled
    @return          : headerHandle JSON
    ********************************************************
    */
    public static String uploadFileChunk(String serializedWrapper, Boolean isAWSEnabled, OAuth_Configuration__mdt config) {
        try {
            String token = config.Access_Token__c;

            FileChunkWrapper fileWrapper = (FileChunkWrapper) JSON.deserialize(serializedWrapper, FileChunkWrapper.class);
            Blob fileBlob = EncodingUtil.base64Decode(fileWrapper.fileContent);
            String endpoint = config.Authorization_Endpoint__c + '/' + config.API_Version__c + '/upload:' + fileWrapper.uploadSessionId;

            HttpRequest req = new HttpRequest();
            Http http = new Http();

            req.setEndpoint(endpoint);
            req.setMethod('POST');            
            req.setHeader('Authorization', 'OAuth ' + token);
            req.setHeader('file_offset', String.valueOf(fileWrapper.chunkStart));
            req.setHeader('Content-Type', 'application/octet-stream');
            req.setBodyAsBlob(fileBlob);

            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200 || res.getStatusCode() == 206) {
                String resBody = res.getBody();
                Map<String, Object> responseMap = String.isNotBlank(resBody) ? (Map<String, Object>) JSON.deserializeUntyped(resBody) : null;
                
                Boolean isPartialRequest = false;
                if (responseMap != null && responseMap.containsKey('debug_info')) {
                    Map<String, Object> debugInfo = (Map<String, Object>) responseMap.get('debug_info');
                    if (debugInfo != null && debugInfo.get('type') == 'PartialRequestError') {
                        isPartialRequest = true;
                    }
                }

                if (responseMap != null && (responseMap.containsKey('error') || (responseMap.containsKey('debug_info') && !isPartialRequest))) {
                    ErrorHandler.insertErrordata(null, 'WAManageTemplatePageController', 'uploadFileChunk', 'Meta upload chunk error (' + res.getStatusCode() + '): ' + resBody);
                    return '';
                }

                String headerHandle = (responseMap != null && responseMap.containsKey('h')) ? (String) responseMap.get('h') : '';
                return JSON.serialize(new Map<String, String>{
                    'headerHandle' => headerHandle
                });
            } else {
                ErrorHandler.insertErrordata(null, 'WAManageTemplatePageController', 'uploadFileChunk', 'HTTP callout failed with status: ' + res.getStatusCode() + ' - ' + res.getBody());
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WAManageTemplatePageController', 'uploadFileChunk', e.getMessage());
        }
        return '';
    }

    /*
    *********************************************************
    @description     : Callout to edit template in Meta and update WA_Template__c.
    @param           : serializedWrapper, payloadWrapper, templateId, templateName
    @return          : Map<String, Object>
    ********************************************************
    */
    @AuraEnabled
    public static Map<String, Object> editWhatsappTemplate(String serializedWrapper, String payloadWrapper, String templateId, String templateName) {
        Map<String, Object> response = new Map<String, Object>();
        HttpResponse res = new HttpResponse();

        try {
            OAuth_Configuration__mdt config = getConfig();

            if(config == null){
                response.put('success', false);
                response.put('status', 'error');
                response.put('message', 'OAuth_Configuration__mdt is not configured in Custom Metadata (OAuth_Configuration__mdt).');
                return response;
            }

            if(String.isBlank(config.Access_Token__c) || String.isBlank(config.API_Version__c) || String.isBlank(config.Authorization_Endpoint__c)){
                response.put('success', false);
                response.put('errorMessage', 'One of the following is not configured in Custom Metadata (OAuth_Configuration__mdt): Access Token, Business Account ID, API Version, Authorization Endpoint.');
                return response;
            }

            // Pre-callout eligibility validation against Meta 24h & 30-day rules
            List<WA_Template__c> currentTemps = [SELECT Id, Status__c, Last_Meta_Edit_Time__c, Edit_Timestamps_JSON__c, Edit_Count_30_Days__c FROM WA_Template__c 
                                                    WHERE (Template_Id__c = :templateId AND Template_Id__c != null) OR (Template_Name__c = :templateName AND 
                                                    Template_Name__c != null) WITH USER_MODE LIMIT 1];
            if (!currentTemps.isEmpty()) {
                Map<String, Object> eligibility = evaluateEditEligibility(currentTemps[0]);
                if (eligibility.get('canEdit') == false) {
                    response.put('success', false);
                    response.put('status', 'error');
                    response.put('message', (String) eligibility.get('reason'));
                    return response;
                }
            }
            
            String token = config.Access_Token__c;
            String apiVersion = config.API_Version__c;
            String endpoint = config.Authorization_Endpoint__c + '/' + apiVersion + '/' + templateId;

            WATemplateWrapper.TemplateWrapper templateWrapper = (WATemplateWrapper.TemplateWrapper) JSON.deserialize(serializedWrapper, WATemplateWrapper.TemplateWrapper.class);

            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(payloadWrapper);

            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + token);
            req.setBody(JSON.serialize(payload));
    
            Http http = new Http();
            res = http.send(req);

            if (res.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                Id updatedTemplateId = WATemplateWrapper.handleSuccessResponse((String) responseMap.get('id'), (String) responseMap.get('status'), payload, templateWrapper);
                response.put('success', true);
                response.put('status', 'success');
                response.put('message', 'Template is being updated, you will be notified once it is ready.');
            } else if (res.getStatusCode() != 200 && String.isNotEmpty(res.getBody())) {
                try {
                    Map<String, Object> resMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                    if (resMap.containsKey('error')) {
                        Map<String, Object> errorMap = (Map<String, Object>) resMap.get('error');
                        String errorMessage = (String) errorMap.get('message');
                        Integer errorCode = (Integer) errorMap.get('code');

                        if (errorCode == 100 && errorMessage != null && errorMessage.toLowerCase().contains('file handle that has expired')) {
                            uploadFileToMetaAndGetHeaderHandle(templateName, serializedWrapper, payloadWrapper, templateId);
                        }
                    }
                } catch (Exception er) {
                    System.debug('Error parsing error response: ' + er.getMessage());
                }
                response.put('success', false);
                response.put('status', 'warning');
                response.put('message', 'Template is being updated, you will be notified once it is ready.');
            } else {
                response.put('success', false);
                response.put('errorMessage', res.getBody());
                ErrorHandler.insertErrordata(null, 'WAManageTemplatePageController', 'editWhatsappTemplate', 'HTTP callout failed with status: ' + res.getStatusCode() + ' and body: ' + res.getBody());
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(null, 'WAManageTemplatePageController', 'editWhatsappTemplate', 'Exception: ' + e.getMessage());
            if (e instanceof CalloutException && e.getMessage().containsIgnoreCase('Read timed out')) {
                response.put('success', false);
                response.put('status', 'warning');
                response.put('message', 'Template is being updated, you will be notified once it is ready.');
            } else {
                response.put('success', false);
                response.put('status', 'error');
                response.put('message', e.getMessage());
            }
        }
        return response;
   }

    /*
    *********************************************************
    @description     : Purges timestamps older than 30 days and returns active list.
    @param           : timestampsJson - JSON array string of ISO dates
    @return          : List<String>
    ********************************************************
    */
    public static List<String> purgeAndGetActiveTimestamps(String timestampsJson) {
        List<String> activeTimestamps = new List<String>();
        if (String.isNotBlank(timestampsJson)) {
            try {
                List<Object> rawList = (List<Object>) JSON.deserializeUntyped(timestampsJson);
                DateTime thirtyDaysAgo = System.now().addDays(-30);
                for (Object obj : rawList) {
                    String strDate = String.valueOf(obj);
                    DateTime dt = (DateTime) JSON.deserialize('"' + strDate + '"', DateTime.class);
                    if (dt >= thirtyDaysAgo) {
                        activeTimestamps.add(strDate);
                    }
                }
            } catch (Exception ex) {
                // ignore parse issue
            }
        }
        return activeTimestamps;
    }

    /*
    *********************************************************
    @description     : Evaluates edit eligibility against Meta policies.
    @param           : template - WA_Template__c record
    @return          : Map<String, Object> (canEdit, reason, hoursRemaining, etc.)
    ********************************************************
    */
    public static Map<String, Object> evaluateEditEligibility(WA_Template__c template) {
        Map<String, Object> result = new Map<String, Object>();
        result.put('canEdit', true);
        result.put('reason', '');
        result.put('hoursRemaining', 0);
        result.put('minutesRemaining', 0);

        if (template == null) {
            return result;
        }

        String status = template.Status__c != null ? template.Status__c.toUpperCase() : '';

        // 1. Cannot edit if PENDING / IN-REVIEW
        if (status == 'PENDING' || status == 'IN-REVIEW' || status == 'IN_REVIEW') {
            result.put('canEdit', false);
            result.put('reason', 'This template is currently under review by Meta and cannot be edited until approved or rejected.');
            return result;
        }

        // 2. Cannot edit if PENDING_DELETION
        if (status == 'PENDING_DELETION') {
            result.put('canEdit', false);
            result.put('reason', 'This template is scheduled for deletion and cannot be edited.');
            return result;
        }

        // 3. 24-Hour Cooldown for approved templates
        if (template.Last_Meta_Edit_Time__c != null) {
            DateTime cooldownEnd = template.Last_Meta_Edit_Time__c.addHours(24);
            if (System.now() < cooldownEnd) {
                Long msRemaining = cooldownEnd.getTime() - System.now().getTime();
                Long totalMinutes = msRemaining / (60 * 1000);
                Integer hours = (Integer)(totalMinutes / 60);
                Integer minutes = (Integer)(Math.mod(totalMinutes, 60));

                result.put('canEdit', false);
                result.put('hoursRemaining', hours);
                result.put('minutesRemaining', minutes);
                result.put('reason', 'Meta permits only 1 edit every 24 hours for approved templates. You can edit this template in ' + hours + ' hr ' + minutes + ' min.');
                return result;
            }
        }

        // 4. Max 10 edits in rolling 30 days
        List<String> activeTimestamps = purgeAndGetActiveTimestamps(template.Edit_Timestamps_JSON__c);
        Integer editsUsed = activeTimestamps.size();
        result.put('editsUsed30Days', editsUsed);
        result.put('editsRemaining30Days', Math.max(0, 10 - editsUsed));

        if (editsUsed >= 10) {
            result.put('canEdit', false);
            result.put('reason', 'This template has reached Meta\'s maximum limit of 10 edits in a rolling 30-day window.');
            return result;
        }

        return result;
    }
   
    @AuraEnabled
    public static String getMetaHeaderHandler(String fileUrlOrContentVersionId, String contentVersionId) {
        try {
            String headerHandleResult = '';
            Blob fileBlob;
            String mimeType;
            String fileName;
            Integer fileLength;

            OAuth_Configuration__mdt config = getConfig();

            if(config == null){
                return 'OAuth_Configuration__mdt is not configured in Custom Metadata (OAuth_Configuration__mdt).';
            }

            if(String.isBlank(config.Client_App_ID__c) || String.isBlank(config.API_Version__c) || String.isBlank(config.Authorization_Endpoint__c)){
                return 'One of the following is not configured in Custom Metadata (OAuth_Configuration__mdt): Client App ID, API Version, Authorization Endpoint, Upload Endpoint.';
            }

            if (String.isNotBlank(fileUrlOrContentVersionId) && fileUrlOrContentVersionId.contains('amazonaws.com')) {
                Http http = new Http();
                HttpRequest s3Req = new HttpRequest();
                s3Req.setEndpoint(fileUrlOrContentVersionId);
                s3Req.setMethod('GET');

                HttpResponse s3Res = http.send(s3Req);
                if (s3Res.getStatusCode() != 200) {
                    ErrorHandler.insertErrordata(null, 'WAManageTemplatePageController', 'getMetaHeaderHandler', 'HTTP callout failed with status: ' + s3Res.getStatusCode());
                    return '';
                }

                fileBlob = s3Res.getBodyAsBlob();
                mimeType = s3Res.getHeader('Content-Type');
                fileName = fileUrlOrContentVersionId.substring(fileUrlOrContentVersionId.lastIndexOf('/') + 1);
                fileLength = fileBlob.size();
            } else {
                ContentVersion cv = [SELECT Title, VersionData, FileExtension, ContentSize FROM ContentVersion WHERE Id = :contentVersionId WITH USER_MODE LIMIT 1];
                fileBlob = cv.VersionData;
                fileName = cv.Title + '.' + cv.FileExtension;
                mimeType = getMimeTypeFromExtension(cv.FileExtension);
                fileLength = cv.ContentSize;
            }

            String uploadSessionId = startUploadSession(fileName, fileLength, mimeType, config);
            if (String.isBlank(uploadSessionId)) {
                return '';
            }

            FileChunkWrapper wrapper = new FileChunkWrapper();
            wrapper.uploadSessionId = uploadSessionId;
            wrapper.fileName = fileName;
            wrapper.fileContent = EncodingUtil.base64Encode(fileBlob);
            wrapper.chunkStart = 0;
            wrapper.chunkSize = fileLength;

            String serializedFileWrapper = JSON.serialize(wrapper);

            String resultJson = uploadFileChunk(serializedFileWrapper, false, config);
            if (String.isNotBlank(resultJson)) {
                Map<String, Object> resultMap = (Map<String, Object>) JSON.deserializeUntyped(resultJson);
                if (resultMap != null && resultMap.containsKey('headerHandle')) {
                    headerHandleResult = (String) resultMap.get('headerHandle');
                    return headerHandleResult;
                }
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WAManageTemplatePageController', 'getMetaHeaderHandler', e.getMessage());
        }
        return '';
    }

    @future(callout = true)
    public static void uploadFileToMetaAndGetHeaderHandle(String templateName, String serializedWrapper, String payloadWrapper, String tempalteId) {
        String headerHandleResult = '';
        String fileUrlOrContentVersionId = '';
        String contentVersionId = '';
        WATemplateWrapper.TemplateWrapper templateWrapper = (WATemplateWrapper.TemplateWrapper) JSON.deserialize(serializedWrapper, WATemplateWrapper.TemplateWrapper.class);

        fileUrlOrContentVersionId = templateWrapper.tempImgUrl;

        try {
            if (fileUrlOrContentVersionId != null && fileUrlOrContentVersionId.contains('amazonaws.com')) {
                Http http = new Http();
                HttpRequest s3Req = new HttpRequest();
                s3Req.setEndpoint(fileUrlOrContentVersionId);
                s3Req.setMethod('GET');

                HttpResponse s3Res = http.send(s3Req);
                if (s3Res.getStatusCode() != 200) {
                    ErrorHandler.insertErrordata(null, 'WAManageTemplatePageController', 'uploadFileToMetaAndGetHeaderHandle', 'HTTP callout failed with status: ' + s3Res.getStatusCode());
                    return;
                }
            } else {
                String jsonStr = templateWrapper.templateMiscellaneousData;

                if (!String.isBlank(jsonStr)) {
                    try {
                        Map<String, Object> miscData = (Map<String, Object>) JSON.deserializeUntyped(jsonStr);
                        contentVersionId = (String) miscData.get('contentVersionId');
                    } catch (Exception e) {
                        ErrorHandler.insertErrordata(e, 'WAManageTemplatePageController', 'uploadFileToMetaAndGetHeaderHandle', 'Failed to parse templateMiscellaneousData: ' + e.getMessage());
                    }
                }
            }

            headerHandleResult = getMetaHeaderHandler(fileUrlOrContentVersionId, contentVersionId);

            if (headerHandleResult != null && headerHandleResult != '') {
                payloadWrapper = payloadWrapper.replaceFirst('"header_handle":"[^"]+"', '"header_handle":"' + headerHandleResult + '"');
                templateWrapper.tempHeaderHandle = headerHandleResult;
                serializedWrapper = JSON.serialize(templateWrapper);
                editWhatsappTemplate(serializedWrapper, payloadWrapper, tempalteId, templateName);
            }

        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WAManageTemplatePageController', 'uploadFileToMetaAndGetHeaderHandle', e.getMessage());
        }
    }
    
    private static String getMimeTypeFromExtension(String ext) {
        ext = ext != null ? ext.toLowerCase() : '';
        if (ext == 'png') return 'image/png';
        if (ext == 'jpg' || ext == 'jpeg') return 'image/jpeg';
        if (ext == 'pdf') return 'application/pdf';
        if (ext == 'mp4') return 'video/mp4';
        if (ext == 'doc') return 'application/msword';
        if (ext == 'docx') return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
        if (ext == 'xls') return 'application/vnd.ms-excel';
        if (ext == 'xlsx') return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
        return 'application/octet-stream';
    }

    public class FileChunkWrapper {
        @AuraEnabled public String uploadSessionId;
        @AuraEnabled public String fileContent;
        @AuraEnabled public Integer chunkStart;
        @AuraEnabled public Integer chunkSize;
        @AuraEnabled public Long totalFileSize;
        @AuraEnabled public String fileName;
        @AuraEnabled public Boolean isLastChunk;
    }
    
    public class TemplateDataWrapper {
        @AuraEnabled public WA_Template__c template;
        @AuraEnabled public List<String> objectNames;
        @AuraEnabled public List<String> fieldNames;
        @AuraEnabled public List<Map<String, String>> templateVariables; 
        @AuraEnabled public Boolean isImgUrl;
        @AuraEnabled public Boolean canEdit;
        @AuraEnabled public String editBlockReason;
        @AuraEnabled public Integer hoursRemaining;
        @AuraEnabled public Integer minutesRemaining;
        @AuraEnabled public Integer editsUsed30Days;
        @AuraEnabled public Integer editsRemaining30Days;
    }

    @AuraEnabled
    public static Map<String, String> uploadFile(String base64Data, String fileName) {
        Map<String, String> resultMap = new Map<String, String>();
        try {
            ContentVersion cv = new ContentVersion();
            cv.Title = fileName;
            cv.PathOnClient = '/' + fileName;
            cv.VersionData = EncodingUtil.base64Decode(base64Data);
            insert as user cv;

            String publicUrl = getPublicLink(cv.Id);

            resultMap.put('contentVersionId', cv.Id);
            resultMap.put('publicUrl', publicUrl);
            return resultMap;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'WAManageTemplatePageController', 'uploadFile', e.getMessage());
            return null;
        }
    }

    @AuraEnabled
    public static String deleteFile(String contentVersionId) {
        try {
            List<ContentDocument> docs = [SELECT Id FROM ContentDocument WHERE LatestPublishedVersionId = :contentVersionId WITH USER_MODE LIMIT 1];
            if (!docs.isEmpty()) {
                Id contentDocumentId = docs[0].Id;
                
                delete as user docs;
                return 'File deleted successfully!';
            } else {
                return 'No file found to delete.';
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'WAManageTemplatePageController', 'deleteFile', e.getMessage());
            return 'Error: ' + e.getMessage();
        }
    }

    public static String getPublicLink(String contentVersionId) {
        try {
            // Get the related ContentDocument Id
            ContentVersion contentVersion = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :contentVersionId WITH USER_MODE LIMIT 1];
            
            // Create a new ContentDistribution (public link)
            ContentDistribution distribution = new ContentDistribution();
            distribution.Name = 'Public Link';
            distribution.ContentVersionId = contentVersion.Id;
            distribution.PreferencesAllowViewInBrowser= true;
            distribution.PreferencesLinkLatestVersion=true;
            distribution.PreferencesNotifyOnVisit=false;
            distribution.PreferencesPasswordRequired=false;
            distribution.PreferencesAllowOriginalDownload= true;

            insert as user distribution;
            
            // Query the created ContentDistribution to get the public URL
            distribution = [SELECT DistributionPublicUrl,ContentDownloadUrl FROM ContentDistribution WHERE Id = :distribution.Id WITH USER_MODE LIMIT 1];
        
            // Return the public URL
            return distribution.ContentDownloadUrl;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'WAManageTemplatePageController', 'getPublicLink', e.getMessage());
            return 'Error: ' + e.getMessage();
        }
    }
}