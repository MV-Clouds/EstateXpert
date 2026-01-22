/**
 * Class Name: WBTemplateController
 * Test Class: 
 * @description: Used in LWC components, it used to get the template record, 
                picklist value from static resource and callout for creation of template.
 * Date: 25/11/2024
 * Created By: Rachit Shah
 */
 /***********************************************************************
 MODIFICATION LOG*
 * Last Update Date : 24/12/2024
 * Updated By : Rachit Shah
 * Name of methods changed (Comma separated if more then one) : restrictTemplates,sendPreviewTemplate
 * Change Description : 
 ***********************************************************************/

 public with sharing class WBTemplateController {
    
    // public static final WBConnect_Configuration__mdt SETTINGS[0];
    public static List<WBConnect_Configuration__mdt> SETTINGS = WBConnect_Configuration__mdt.getAll().values(); 
    public static String accessToken = !SETTINGS.isEmpty() ? SETTINGS[0].Access_Token__c : null;
    public static String uploadEndpoint;


     /*
   *********************************************************
   @description     : Used in WbAllTemplatePage to get all template record.
   @param           : 
   @return          : listName - Whatsapp Template record.
   ********************************************************
   */
 @AuraEnabled
   public static List<WhatsappTemplate__c> getWhatsAppTemplates() {
       try {
           List<WhatsappTemplate__c> listName = [SELECT Id, Name,Template_Name__c, Template_Category__c, toLabel(Language__c) LanguageLabel,File_Name__c,WBImage_Header_Handle__c, Status__c, LastModifiedById,LastModifiedDate, CreatedDate 
           FROM WhatsappTemplate__c WITH USER_MODE ORDER BY LastModifiedDate DESC];

           return listName;
       } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WBTemplateController', 'getWhatsAppTemplates', e.getMessage());
            return null;
       }
   }

       /*
   *********************************************************
   @description     : trigger handle to handle limit of 5 records.
   @param           : 
   @return          : void
   ********************************************************
   */
   public static void restrictTemplates(List<WhatsappTemplate__c> templates) {
       try {
           Integer totalTemplates = [SELECT COUNT() FROM WhatsappTemplate__c WITH USER_MODE];
           
           if (totalTemplates + templates.size() > 20) {
               if (!Test.isRunningTest()) {
                   for (WhatsappTemplate__c template : templates) {
                       template.addError('You cannot create more than 20 Template records.');
                   }
               } 
           }
       } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WBTemplateController', 'restrictTemplates', e.getMessage());
       }
   }
   
       /*
   *********************************************************
   @description     : Send preview message.
   @param           : 
   @return          : errorMessage
   ********************************************************
   */
   @AuraEnabled
   public static String sendPreviewTemplate(String jsonData) {
       String errorMessage=null;
       try {
           HttpRequest httpReq = new HttpRequest();
           List<WBConnect_Configuration__mdt> config = WBConnect_Configuration__mdt.getAll().values(); 
           if(config==null && config.isEmpty()){
               errorMessage='Metadata records are missing.';
               return errorMessage;
           }
           String accessToken = config[0].Access_Token__c;
           String endpoint = config[0].API_Endpoint__c + '/' + config[0].API_Version__c + '/' + config[0].Phone_Number_Id__c + '/messages';
           httpReq.setEndpoint(endpoint);
           httpReq.setMethod('POST');
           httpReq.setHeader('Content-Type', 'application/json');
           httpReq.setHeader('Authorization', 'Bearer ' + accessToken);
           httpReq.setBody(jsonData);
           Http http = new Http();
           HttpResponse response = http.send(httpReq);
           Integer statusCode = response.getStatusCode();
           if(statusCode != 200){
               errorMessage='Failed to send Template';
           }

       } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WBTemplateController', 'sendPreviewTemplate', e.getMessage());
       }
       return errorMessage;
   }

    /*
   *********************************************************
   @description     : Used to fetch all the field related to object name
   @param           : 
   @return          : fieldNames - Return fields that query for the objectname that pass.
   ********************************************************
   */
   @AuraEnabled(cacheable=true)
   public static List<String> getObjectFields(String objectName) {
       // String objectName = 'Contact';
       List<String> fieldNames = new List<String>();
       try {
           Schema.DescribeSObjectResult objDescribe = Schema.getGlobalDescribe().get(objectName).getDescribe();
           Map<String, Schema.SObjectField> fieldsMap = objDescribe.fields.getMap();
           for (String fieldName : fieldsMap.keySet()) {
               fieldNames.add(fieldsMap.get(fieldName).getDescribe().getName()); 
           }
           fieldNames.sort();
       } catch (Exception e) {
           ErrorHandler.insertErrordata(e, 'WBTemplateController', 'getObjectFields', e.getMessage());
       }
       return fieldNames;
   }

   /*
   *********************************************************
   @description     : Fetch records based on the object name
   @param           : 
   @return          : records - Return record that query for the objectname that pass.
   ********************************************************
   */
   @AuraEnabled(cacheable=true)
   public static List<sObject> getRecordsBySObject(String objectName) {
       String sObjectName=objectName;
       List<sObject> records = new List<sObject>();
       
       try {
           String query = 'SELECT Id, Name, Phone FROM ' + sObjectName + ' WHERE Phone != null LIMIT 200';           
           records = Database.query(String.escapeSingleQuotes(query), AccessLevel.USER_MODE);
       } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WBTemplateController', 'getRecordsBySObject', e.getMessage());
       }
       return records;
   }




   /*
   *********************************************************
   @description     : This method use to fetch template data and variable mapping done in js.
   @param           : 
   @return          : wrapper - Return wrapper that contain object name and field name from the Template Variable.
   ********************************************************
   */
   @AuraEnabled(cacheable=true)
   public static TemplateDataWrapper getDynamicObjectData(Id templateId) {
       TemplateDataWrapper wrapper = new TemplateDataWrapper();
       Set<String> objectNames = new Set<String>();
       Set<String> fieldNames = new Set<String>();
       wrapper.templateVariables = new List<Map<String, String>>();

       try {
           List<WhatsappTemplate__c> templates = [
               SELECT Id, Name,Template_Name__c, WBButton_Body__c, Status__c,WBImage_Header_Handle__c, Template_Id__c, Button_Label__c, Button_Type__c, File_Name__c,
                   WBFooter_Body__c, WBHeader_Body__c, Header_Type__c, Language__c, WBTemplate_Body__c, 
                   Template_Category__c, Template_Type__c , Template_Miscellaneous_Data__c
               FROM WhatsappTemplate__c 
               WHERE Id = :templateId WITH USER_MODE
               ORDER BY LastModifiedDate DESC
               LIMIT 1
           ];

           if (templates.isEmpty()) {
               return wrapper; 
           }

           WhatsappTemplate__c template = templates[0];
           wrapper.template = template;

           if (template.Header_Type__c == 'Image') {
               wrapper.isImgUrl = true;
           }
           else if (template.Header_Type__c == 'Video') {
               wrapper.isImgUrl = true;
           }
           else if (template.Header_Type__c == 'Document') {
               wrapper.isImgUrl = true;
           }
           

           List<Template_Variable__c> templateVariables = [
               SELECT Name, Object_Name__c, Field_Name__c, Type__c, Alternate_Text__c
               FROM Template_Variable__c 
               WHERE WhatsappTemplate__c = :template.Id WITH USER_MODE
           ];

           if (!templateVariables.isEmpty()) {
               for (Template_Variable__c variable : templateVariables) {
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
            ErrorHandler.insertErrordata(e, 'WBTemplateController', 'getDynamicObjectData', e.getMessage());
       }

       return wrapper;
   }

   /*
   *********************************************************
   @description     : Fetch records based on the dynamic object name, fieldname and recordid
   @param           : objectName, fieldNames, recordId
   @return          : resultMap {Map<String, Object>} - Return queried data.
   ********************************************************
   */
   @AuraEnabled(cacheable=true)
   public static Map<String, Object> fetchDynamicRecordData(String objectName, List<String> fieldNames, String recordId) {
       Map<String, Object> resultMap = new Map<String, Object>();

       try {

           if (!fieldNames.contains('Phone')) {
                   fieldNames.add('Phone');
           }
           String fields = String.join(fieldNames, ',');
           
           String queryString = 'SELECT ' + fields + ' FROM ' + objectName + ' WHERE Id = :recordId LIMIT 1'; 
           List<SObject> queriedData = Database.query(String.escapeSingleQuotes(queryString), AccessLevel.USER_MODE);

           if (!queriedData.isEmpty()) {
               resultMap.put('queriedData', queriedData[0]);  
           } else {
               resultMap.put('queriedData', null);
           }

       } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WBTemplateController', 'fetchDynamicRecordData', e.getMessage());
            resultMap.put('error', e.getMessage());
       }

       return resultMap;
   }
   
    /*
   *********************************************************
   @description     : It used to replace variable from backend to handle the sending of template variable.
   @param           : recordId
   @return          : result {Map<String, Object>} - Return the replace template content based on the template variable fields by fetching from contact object.
   ********************************************************
   */

   @AuraEnabled
   public static Map<String, Object> getTemplateDataWithReplacement(String templateId, String contactId) {
       try {
           Map<String, Object> templateData = new Map<String, Object>();
           List<WhatsappTemplate__c> templates = [SELECT Id, Name,Template_Name__c, WBButton_Body__c, Button_Label__c, Button_Type__c,WBImage_Header_Handle__c, 
                                               WBFooter_Body__c, WBHeader_Body__c, Header_Type__c, Language__c,File_Name__c, 
                                               WBTemplate_Body__c, Template_Category__c, 
                                               Template_Type__c, Template_Variable__c, Template_Miscellaneous_Data__c,
                                               (SELECT Id, Name, Field_Name__c, Object_Name__c, Type__c, Alternate_Text__c 
                                                   FROM WB_Template_Variables__r ORDER BY Name ASC) 
                                           FROM WhatsappTemplate__c 
                                           WHERE Id = :templateId 
                                           WITH USER_MODE];
           if (templates.size() > 0) {
            WhatsappTemplate__c template = templates[0];

               if (template.Template_Variable__c > 0) {
                   List<Object> headerVariables = new List<Object>();
                   List<Object> bodyVariables = new List<Object>();

                   // Scenario 1: Contact ID is passed
                   if (String.isNotBlank(contactId)) {
                       Set<String> fieldSelectionCause = new Set<String>();
                       for (Template_Variable__c tv : template.WB_Template_Variables__r) {
                           if (tv.Object_Name__c == 'Contact') {
                               fieldSelectionCause.add(tv.Field_Name__c);
                           } else {
                               fieldSelectionCause.add(tv.Object_Name__c + '.' + tv.Field_Name__c);
                           }
                       }

                       if (fieldSelectionCause.size() > 0) {
                           String query = 'SELECT Id, ' + String.join(fieldSelectionCause, ', ') + ' FROM Contact WHERE Id =:contactId';
                           List<Contact> contacts = Database.query(String.escapeSingleQuotes(query), AccessLevel.USER_MODE);
                           if (contacts.size() > 0) {
                               Contact contactRecord = contacts[0];
                               for (Template_Variable__c tv : template.WB_Template_Variables__r) {
                                   Object valueToReplace = '';
                                   if (tv.Object_Name__c == 'Contact') {
                                       valueToReplace = contactRecord.get(tv.Field_Name__c);
                                   } else {
                                       valueToReplace = contactRecord.getSObject(tv.Object_Name__c) != null ? 
                                                       contactRecord.getSObject(tv.Object_Name__c).get(tv.Field_Name__c) : null;
                                   }
                                   
                                   if (tv.Type__c == 'Header') {
                                       String replacement = (valueToReplace != null ? valueToReplace.toString() : 
                                                             (tv.Alternate_Text__c != null ? tv.Alternate_Text__c : ''));
                                   
                                       headerVariables.add(replacement);
                                       template.WBHeader_Body__c = template.WBHeader_Body__c.replace(tv.Name, replacement);
                                   } else if (tv.Type__c == 'Body') {
                                       String replacement = (valueToReplace != null ? valueToReplace.toString() : 
                                                             (tv.Alternate_Text__c != null ? tv.Alternate_Text__c : ''));
                                   
                                       bodyVariables.add(replacement);
                                       template.WBTemplate_Body__c = template.WBTemplate_Body__c.replace(tv.Name, replacement);
                                   }
                                   
                               }
                           }
                       }
                   } 
                   // Scenario 2: Contact ID not passed
                   else {
                       for (Template_Variable__c tv : template.WB_Template_Variables__r) {
                           if (tv.Type__c == 'Header') {
                               headerVariables.add(tv.Alternate_Text__c != null ? tv.Alternate_Text__c : '{{' + tv.Name + '}}');
                               template.WBHeader_Body__c = template.WBHeader_Body__c.replace(tv.Name, 
                                                           tv.Alternate_Text__c != null ? tv.Alternate_Text__c : '{{' + tv.Name + '}}');
                           } else if (tv.Type__c == 'Body') {
                               // bodyVariables.add(tv.Alternate_Text__c != null ? tv.Alternate_Text__c : '{{' + tv.Name + '}}');
                               bodyVariables.add(tv.Alternate_Text__c != null ? tv.Alternate_Text__c : tv.Name);
                               template.WBTemplate_Body__c = template.WBTemplate_Body__c.replace(tv.Name, 
                                                           tv.Alternate_Text__c != null ? tv.Alternate_Text__c : tv.Name);
                                                           // tv.Alternate_Text__c != null ? tv.Alternate_Text__c : '{{' + tv.Name + '}}');
                           }
                       }
                   }

                   templateData.put('template', template);
                   templateData.put('headerParams', headerVariables);
                   templateData.put('bodyParams', bodyVariables);
               } else {
                   templateData.put('template', template);
               }

               return templateData;
           }
       } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WBTemplateController', 'getTemplateDataWithReplacement', e.getMessage());
    }
       return null;
   }
   
      /*
   *********************************************************
   @description     : Get picklist value for catagory and status used in WbAllTemplatePage to filter.
   @param           : 
   @return          : picklistValues {Map<String, List<String>>} - return picklist value for catagory and status from template object.
   ********************************************************
   */
   @AuraEnabled(cacheable=true)
   public static Map<String, List<String>> getCategoryAndStatusPicklistValues() {
       Map<String, List<String>> picklistValues = new Map<String, List<String>>();

       List<String> categoryValues = new List<String>();
       List<String> statusValues = new List<String>();

       try {
           // Fetch Category__c picklist values
           Schema.DescribeFieldResult categoryFieldResult = WhatsappTemplate__c.Template_Category__c.getDescribe();
           for (Schema.PicklistEntry entry : categoryFieldResult.getPicklistValues()) {
               categoryValues.add(entry.getLabel());
           }

           // Fetch Status__c picklist values
           Schema.DescribeFieldResult statusFieldResult = WhatsappTemplate__c.Status__c.getDescribe();
           for (Schema.PicklistEntry entry : statusFieldResult.getPicklistValues()) {
               statusValues.add(entry.getLabel());
           }

           picklistValues.put('categories', categoryValues);
           picklistValues.put('statuses', statusValues);

           return picklistValues;
       } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WBTemplateController', 'getCategoryAndStatusPicklistValues', e.getMessage());
        return null;
       }
       
   }

   /*
   *********************************************************
   @description     : Callout to create template in the Meta and the Body creation and response handle in CreateTemplateWrapper Class.
   @param           : serializedWrapper - get serialize wrapper from the js to create template.
   @return          : response Map<String, Object> - return response with the template id.
   ********************************************************
   */
    @AuraEnabled
    public static Map<String, Object> createWhatsappTemplate(String serializedWrapper,String payloadWrapper, String templateName) {
        Map<String, Object> response = new Map<String, Object>();

        try {
            if (String.isBlank(SETTINGS[0].Business_Account_Id__c)) {
                response.put('success', false);
                response.put('errorMessage', 'Business Account ID is not configured in the system.');
                return response;
            }

            CreateTemplateWrapper.TemplateWrapper templateWrapper = (CreateTemplateWrapper.TemplateWrapper) JSON.deserialize(serializedWrapper, CreateTemplateWrapper.TemplateWrapper.class);

            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(payloadWrapper);
            System.debug('payload :: '+payload);
            String endpoint = SETTINGS[0].API_Endpoint__c + '/' + SETTINGS[0].API_Version__c + '/' + SETTINGS[0].Business_Account_Id__c+'/message_templates';
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            req.setBody(JSON.serialize(payload));
    
            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                Id templateId = CreateTemplateWrapper.handleSuccessResponse((String) responseMap.get('id'), (String) responseMap.get('status'), payload, templateWrapper);
                response.put('success', true);
                response.put('templateId', templateId); 
            } else {
                response.put('success', false);
                response.put('errorMessage', res.getBody());

                if (String.isNotBlank(templateWrapper.tempImgId)) {
                    ContentVersion version = [
                        SELECT ContentDocument.Id 
                        FROM ContentVersion 
                        WHERE Id = :templateWrapper.tempImgId 
                        WITH USER_MODE 
                        LIMIT 1
                    ];

                    if (version != null) {
                        delete as user version.ContentDocument;
                    }
                }

            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WBTemplateController', 'createWhatsappTemplate', e.getMessage());
            if (e instanceof CalloutException && e.getMessage().containsIgnoreCase('Read timed out')) {
                response.put('success', false);
                response.put('status', 'warning');
                response.put('message', 'Template is being created, you will be notified once it is ready.');
                checkTemplateExistance(templateName, serializedWrapper, payloadWrapper);
            }
            else{
                response.put('success', false);
                response.put('status', 'error');
                response.put('message', e.getMessage());
            }
        }

        return response;
    }

    @future(callout=true)
    public static void checkTemplateExistance(String templateName, String serializedWrapper, String payloadWrapper) {
        try {
            String endpoint = SETTINGS[0].API_Endpoint__c + '/' + SETTINGS[0].API_Version__c + '/' + SETTINGS[0].Business_Account_Id__c + '/message_templates?name=' + EncodingUtil.urlEncode(templateName, 'UTF-8');
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('GET');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + accessToken);

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                List<Object> dataList = (List<Object>) responseMap.get('data');

                if (!dataList.isEmpty()) {
                    // Get the first element from the list and cast it as a Map
                    Map<String, Object> templateData = (Map<String, Object>) dataList[0];

                    // Extract values
                    String metaTemplateId = (String) templateData.get('id');
                    String metaTempStatus = (String) templateData.get('status');

                    CreateTemplateWrapper.TemplateWrapper templateWrapper = (CreateTemplateWrapper.TemplateWrapper) JSON.deserialize(serializedWrapper, CreateTemplateWrapper.TemplateWrapper.class);
                    Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(payloadWrapper);

                    Id templateId = CreateTemplateWrapper.handleSuccessResponse(metaTemplateId, metaTempStatus, payload, templateWrapper);

                    if(templateId != null) {
                        Template_Update__e fetchAllTemplatesEvent = new Template_Update__e();
                        fetchAllTemplatesEvent.Fetch_All_Templates__c = true;
                        EventBus.publish(fetchAllTemplatesEvent);
                    }
                }
            } else {
                System.debug('API Call failed: ' + res.getStatusCode() + ' - ' + res.getBody());
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WBTemplateController', 'checkTemplateExistance', e.getMessage());
        }
    }

   /*
   *********************************************************
   @description     : Method to get session Id for uploading file to meta.
   @param           : fileName,fileLength,fileType - get the all parameter from the js as user select the file.
   @return          : sessionId - return sessionId to start upload file in meta.
   ********************************************************
   */
   @AuraEnabled
   public static String startUploadSession(String fileName, Integer fileLength, String fileType) {
       try {
           if (String.isBlank(SETTINGS[0].Application_Id__c)) {
               return 'Application ID is not configured in the system.';
           }
           Map<String, Object> payload = new Map<String, Object>();
           payload.put('file_name', fileName);
           payload.put('file_length', fileLength);
           payload.put('file_type', fileType);
           uploadEndpoint = SETTINGS[0].API_Endpoint__c + '/' + SETTINGS[0].API_Version__c + '/'+SETTINGS[0].Application_Id__c+'/uploads';

           HttpRequest req = new HttpRequest();
           Http http = new Http();
           req.setEndpoint(uploadEndpoint);
           req.setMethod('POST');
           req.setHeader('Content-Type', 'application/json');
           req.setHeader('Authorization', 'OAuth ' + accessToken);
           req.setBody(JSON.serialize(payload));

           HttpResponse res = http.send(req);
           if (res.getStatusCode() == 200) {
               Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
               String sessionId = (String) responseMap.get('id');
               if (sessionId != null && sessionId.startsWith('upload:')) {
                   sessionId = sessionId.replace('upload:', ''); 
               }

               return sessionId; 
           }
       } catch (Exception e) {
           ErrorHandler.insertErrordata(e, 'WBTemplateController', 'startUploadSession', e.getMessage());
       }
       return null;
   }        

   /*
   *********************************************************
   @description     : Method to upload file to meta and get file handle which use to create body for image header.
   @param           : serializedWrapper - get serialize wrapper from the js with the detail of files.
   @return          : headerHandle - return headerHandle so that can used to build body for media template.
   ********************************************************
   */
   @AuraEnabled
   public static String uploadFileChunk(String serializedWrapper, Boolean isAWSEnabled) {
       try {
           
           FileChunkWrapper fileWrapper = (FileChunkWrapper) JSON.deserialize(serializedWrapper, FileChunkWrapper.class);

           Blob fileBlob = EncodingUtil.base64Decode(fileWrapper.fileContent);

           HttpRequest req = new HttpRequest();
           Http http = new Http();

           String endpoint = SETTINGS[0].API_Endpoint__c + '/' + SETTINGS[0].API_Version__c + '/' + 'upload:' + fileWrapper.uploadSessionId;
           req.setEndpoint(endpoint);
           req.setMethod('POST');            
           req.setHeader('Authorization', 'OAuth ' + accessToken);
           req.setHeader('file_offset', String.valueOf(fileWrapper.chunkStart)); 
           req.setHeader('Content-Range', 'bytes ' + fileWrapper.chunkStart + '-' + (fileWrapper.chunkStart + fileWrapper.chunkSize - 1) + '/' + fileBlob.size());            
           
           req.setBodyAsBlob(fileBlob);

           HttpResponse res = http.send(req);

           if (res.getStatusCode() == 200) {
               Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
               String headerHandle = (String) responseMap.get('h');
                return JSON.serialize(new Map<String, String>{
                    'headerHandle' => headerHandle
                });
           }
       } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WBTemplateController', 'uploadFileChunk', e.getMessage());
       }
       return '';
   }
     
   /*
   *********************************************************
   @description     : Method used to delete template from meta as well as from record page.
   @param           : templateId - using that can delete template.
   @return          : Return the success or error message. 
   ********************************************************
   */
   @AuraEnabled
   public static string deleteTemplete(String templateId){
       try {
           if (String.isBlank(SETTINGS[0].Business_Account_Id__c)) {
               return 'Business Account ID is not configured in the system.';
           }

           WhatsappTemplate__c wbTempRec = [SELECT Id, Name,Template_Name__c FROM WhatsappTemplate__c WHERE Id =: templateId WITH USER_MODE LIMIT 1];
           
           String endpoint = SETTINGS[0].API_Endpoint__c + '/' + SETTINGS[0].API_Version__c + '/' + SETTINGS[0].Business_Account_Id__c+'/message_templates?name=' + wbTempRec.Template_Name__c;

           HttpRequest req = new HttpRequest();         
           req.setEndpoint(endpoint);
           req.setMethod('DELETE');
           req.setHeader('Content-Type', 'application/json');
           req.setHeader('Authorization', 'Bearer ' + accessToken);
           Http http = new Http();
           HttpResponse res = http.send(req);

           if (res.getBody() != null && res.getBody() != '') {
               Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
               Boolean success = (Boolean) jsonResponse.get('success');
               if (success) {
                   if(WhatsappTemplate__c.sObjectType.getDescribe().isDeletable()){
                       DELETE wbTempRec;
                   }
                   return 'Template deleted successfully';
               } else {
                   return 'Template is not deleted';
               }
           } else {
               return 'Template is not deleted';
           }
       } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WBTemplateController', 'deleteTemplete', e.getMessage());
            return e.getMessage();
       }
   }

    /*
   *********************************************************
   @description     : Callout to edit template in the Meta and the Body creation and response handle in CreateTemplateWrapper Class.
   @param           : serializedWrapper - get serialize wrapper from the js to create template.
   @return          : response Map<String, Object> - return response with the template id.
   ********************************************************
   */
    @AuraEnabled
    public static Map<String, Object> editWhatsappTemplate(String serializedWrapper,String payloadWrapper,String templateId) {
        Map<String, Object> response = new Map<String, Object>();

        try {
            CreateTemplateWrapper.TemplateWrapper templateWrapper = (CreateTemplateWrapper.TemplateWrapper) JSON.deserialize(serializedWrapper, CreateTemplateWrapper.TemplateWrapper.class);
            String editEndpoint = SETTINGS[0].API_Endpoint__c + '/' + SETTINGS[0].API_Version__c + '/'+templateId;
            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(payloadWrapper);
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(editEndpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            req.setBody(JSON.serialize(payload));
    
            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                System.debug('res.getBody(): ' + res.getStatusCode());
                    Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                    CreateTemplateWrapper.handleSuccessResponse((String) responseMap.get('id'), (String) responseMap.get('status'), payload, templateWrapper);
                response.put('success', true);
            } else {
                response.put('success', false);
                response.put('errorMessage', res.getBody());

                if (String.isNotBlank(templateWrapper.tempImgId)) {
                    ContentVersion version = [
                        SELECT ContentDocument.Id 
                        FROM ContentVersion 
                        WHERE Id = :templateWrapper.tempImgId 
                        WITH USER_MODE 
                        LIMIT 1
                    ];

                    if (version != null) {
                        delete as user version.ContentDocument;
                    }
                }
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WBTemplateController', 'editWhatsappTemplate', e.getMessage());
            response.put('status', 'error');
            response.put('message', e.getMessage());
        }
       return response;
   }

   @AuraEnabled(cacheable=true)
   public static List<Flow__c> getAllFlows() {
       try {
           return [SELECT Id,Flow_Id__c, Flow_Name__c,Flow_JSON__c, LastModifiedDate,Status__c FROM Flow__c  where Status__c =: 'Published' WITH USER_MODE ORDER BY CreatedDate DESC ];
       } catch (Exception e) {
             ErrorHandler.insertErrordata(e, 'WBTemplateController', 'getAllFlows', e.getMessage());
        }
        return new List<Flow__c>();
   }

   @AuraEnabled
   public static String getPreviewURLofWhatsAppFlow(String flowId) {
       try {
           List<WBConnect_Configuration__mdt> wbConfig = WBConnect_Configuration__mdt.getAll().values(); 

           String accessToken = wbConfig[0].Access_Token__c;
           String endpoint = SETTINGS[0].API_Endpoint__c + '/' + SETTINGS[0].API_Version__c + '/' + flowId + '?fields=preview.invalidate(false)';
           HttpRequest request = new HttpRequest();
           request.setEndpoint(endpoint);
           request.setMethod('GET');
           request.setHeader('Authorization', 'Bearer ' + accessToken);
           Http http = new Http();
           HttpResponse response = http.send(request);
           
           if (response.getStatusCode() == 200) {
               Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
               Map<String, Object> previewMap = (Map<String, Object>) responseMap.get('preview');
               String previewUrl = (String) previewMap.get('preview_url');
               return previewUrl;
           } else {
               return 'failed';
           }
       } catch (Exception e) {
           ErrorHandler.insertErrordata(e, 'WBTemplateController', 'getPreviewURLofWhatsAppFlow', e.getMessage());
           return 'failed';
       }
   }

   /*
    *********************************************************
    @description     : Method to get objects with phone field.
    @return          : List<Map<String, String>> - return list of objects with phone field.
    ********************************************************
    */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getObjectsWithPhoneField() {
        List<Map<String, String>> objectList = new List<Map<String, String>>();
        
        try {
            // Query FieldDefinition to fetch all objects having at least one Phone field
            List<FieldDefinition> phoneFields = [SELECT EntityDefinition.QualifiedApiName, EntityDefinition.Label FROM FieldDefinition WHERE DataType = 'Phone' AND EntityDefinition.IsCustomizable = true AND EntityDefinition.IsApexTriggerable = true AND EntityDefinition.IsQueryable = true WITH USER_MODE];
            
            Set<String> processedObjects = new Set<String>();
    
            for (FieldDefinition field : phoneFields) {
                String objectName = field.EntityDefinition.QualifiedApiName;
                if (!processedObjects.contains(objectName)) {
                    objectList.add(new Map<String, String>{
                        'label' => field.EntityDefinition.Label,
                        'value' => objectName
                    });
                    processedObjects.add(objectName);
                }
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WBTemplateController', 'getObjectsWithPhoneField', e.getMessage());
        }
    
        return objectList;
    }

    @AuraEnabled(cacheable=true)
    public static String getCompanyName() {
        return [SELECT Name FROM Organization WITH USER_MODE LIMIT 1].Name;
    }

   public class FileChunkWrapper {
       @AuraEnabled public String uploadSessionId;
       @AuraEnabled public String fileContent;
       @AuraEnabled public Integer chunkStart;
       @AuraEnabled public Integer chunkSize;
       @AuraEnabled public String fileName;
       @AuraEnabled public Boolean isLastChunk;
   }
   public class TemplateDataWrapper {
       @AuraEnabled public WhatsappTemplate__c template;
       // @AuraEnabled public Object queriedData;
       @AuraEnabled public List<String> objectNames;
       @AuraEnabled public List<String> fieldNames;
       @AuraEnabled public List<Map<String, String>> templateVariables; 
       @AuraEnabled public Boolean isImgUrl;
   }
   
}