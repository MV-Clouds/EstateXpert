/**
 * Class Name: CreateTemplateWrapper
 * Test Class: 
 * @description: Used in WBTemplateController Apex Class to create request body for template creation.
 * Date: 26/11/2024
 * Created By: Rachit Shah
 */
 /***********************************************************************
 MODIFICATION LOG*
 * Last Update Date : 12/12/2024
 * Updated By : Rachit Shah
 * Name of methods changed (Comma separated if more then one) : handleSuccessResponse
 * Change Description : Store actual variable {{1}} in the name field of template variable.
 ***********************************************************************/

 public with sharing class CreateTemplateWrapper {

    /*
    *********************************************************
    @description     : Handle response and store all in the template and template variable record.
    @param           : res,payload,response,templateWrapper - {HttpResponse,Map<String, Object>,Map<String, Object>,TemplateWrapper} 
    @return          : templateId of created template records.
    ********************************************************
    */

    public static Id handleSuccessResponse(String metaTempId, String metaTemplateStatus, Map<String, Object> payload, TemplateWrapper templateWrapper) {
        Map<String, Object> response = new Map<String, Object>();
        Id templateId = null;
        try {
            // Deserialize the payload
            Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(payload));
            
            // List<Map<String, String>> buttonDetails;
            String buttonDetails;
            String templatename = (String) payloadMap.get('name');
            WhatsappTemplate__c whatsAppTemplate;


            List<WhatsappTemplate__c> allTemplates = [
                SELECT Id, Name, Template_Name__c, Template_Id__c 
                FROM WhatsappTemplate__c
                WITH USER_MODE
            ];
            List<WhatsappTemplate__c> whatsAppTemplateList = new List<WhatsappTemplate__c>();
            for (WhatsappTemplate__c template : allTemplates) {
                if (template.Template_Name__c == (String) payloadMap.get('name')) {
                    whatsAppTemplateList.add(template);
                }
            }


            if (whatsAppTemplateList.isEmpty()) {
                whatsAppTemplate = new WhatsappTemplate__c();
            } else {
                whatsAppTemplate = whatsAppTemplateList[0];
                if (whatsAppTemplate.Template_Id__c != null) {
                    whatsAppTemplate.Template_Id__c = metaTempId != null ? metaTempId : whatsAppTemplate.Template_Id__c;
                }
            }
            
            // Populate WhatsappTemplate__c fields dynamically
            String status = metaTemplateStatus;
            whatsAppTemplate.Template_Id__c = metaTempId != null ? metaTempId : whatsAppTemplate.Template_Id__c;
            whatsAppTemplate.Status__c = (status == null || status == '') ? 'In-Review' : (status == 'PENDING') ? 'In-Review' : 
                                         (status == 'REJECTED') ? 'Rejected' : 
                                         (status == 'APPROVED') ? 'Active-Quality Pending' : '';
            whatsAppTemplate.Template_Name__c = (String) payloadMap.get('name');
            whatsAppTemplate.Template_Category__c = (String) payloadMap.get('category');
            whatsAppTemplate.Language__c = (String) payloadMap.get('language');
            whatsAppTemplate.Template_Type__c = templateWrapper.templateType;
            whatsAppTemplate.Template_Miscellaneous_Data__c = templateWrapper.templateMiscellaneousData;

            // Initialize variables for components
            List<Template_Variable__c> variableRecords = new List<Template_Variable__c>();
            List<Object> components = (List<Object>) payloadMap.get('components');
            List<String> headAlternateTexts = templateWrapper.headAlternateTexts; 
            List<String> varAlternateTexts = templateWrapper.varAlternateTexts;   

            Integer headerIndex = 0;
            Integer variableIndex = 0; 
            String headerMergeText = '';
    
            // Process components
            for (Object comp : components) {
                if (!(comp instanceof Map<String, Object>)) {
                    continue;
                }
                Map<String, Object> component = (Map<String, Object>) comp;
                String type = (String) component.get('type');
                Map<String, Object> example = (Map<String, Object>) component.get('example');

            

                if(whatsAppTemplate.Template_Category__c == 'Authentication'){
                    component.put('text',templateWrapper.templateBody);
                }

    
                // HEADER Component
                if (type == 'HEADER') {
                    whatsAppTemplate.Header_Type__c = (String) component.get('format');
                    if (((String) component.get('format') == 'IMAGE')||(((String) component.get('format') == 'VIDEO'))||(((String) component.get('format') == 'DOCUMENT'))) {
                        whatsAppTemplate.WBHeader_Body__c = templateWrapper.tempImgUrl;
                        whatsAppTemplate.File_Name__c = templateWrapper.tempImgName;
                        whatsAppTemplate.WBImage_Header_Handle__c = templateWrapper.tempHeaderHandle;
                    } else {
                        whatsAppTemplate.WBHeader_Body__c = (String) component.get('text');
                        
                    }
                    if (example != null && example.containsKey('header_text') && example.get('header_text') instanceof List<Object>) {
                        List<Object> headerExampleObj = (List<Object>) example.get('header_text');
                        Pattern pattern = Pattern.compile('\\{\\{(\\d+)\\}\\}');
                        Matcher matcher = pattern.matcher((String) component.get('text'));

                        if (!headerExampleObj.isEmpty()) {
                            while (matcher.find()) {
                                String placeholder = matcher.group();  
                                headerMergeText = (String) headerExampleObj[0];
                                headerMergeText = headerMergeText.replace('{{', '').replace('}}', '');
                                List<String> parts = headerMergeText.split('\\.');
                                if (parts.size() == 2) {
                                    List<Template_Variable__c> existingHeaderVar = [
                                        SELECT Id, Name
                                        FROM Template_Variable__c
                                        WHERE WhatsappTemplate__c = :whatsAppTemplate.Id
                                        AND Type__c = 'Header'
                                        WITH USER_MODE
                                    ];
                
                                    if (!existingHeaderVar.isEmpty()) {
                                        delete as user existingHeaderVar;
                                    }

                                    if (headerIndex < headAlternateTexts.size()) {
                                        Template_Variable__c headerVariable = new Template_Variable__c(
                                            Name = placeholder,
                                            Object_Name__c = parts[0],
                                            Field_Name__c = parts[1],
                                            Type__c = 'Header',
                                            Alternate_Text__c = headAlternateTexts[headerIndex]
                                        );
                                        variableRecords.add(headerVariable);
                                        headerIndex++;
                                    }                           
                                   
                                    headerIndex++;
                                }
                            }
                        }
                    }
                }
                // BODY Component
                else if (type == 'BODY') {
                    Map<String, Object> result = handleBodyComponent(whatsAppTemplate.Template_Category__c, component, example);
                    
                    if(((String) result.get('bodyText')) != null){
                        whatsAppTemplate.WBTemplate_Body__c = String.isNotBlank((String) result.get('bodyText')) ? (String) result.get('bodyText') : '';

                        if(whatsAppTemplate.Template_Category__c != 'Authentication'){
                            List<Map<String, String>> parsedFields = (List<Map<String, String>>) result.get('parsedFields');
                            String bodyMergeText = (String) result.get('bodyMergeText');
        
                            Pattern pattern = Pattern.compile('\\{\\{(\\d+)\\}\\}');
                            Matcher matcher = pattern.matcher((String) result.get('bodyText'));
                            Set<String> processedBodyPlaceholders = new Set<String>();
        
                            List<Template_Variable__c> existingBodyVars = [
                                SELECT Id, Name
                                FROM Template_Variable__c
                                WHERE WhatsappTemplate__c = :whatsAppTemplate.Id
                                AND Type__c = 'Body'
                                WITH USER_MODE
                            ];
        
                            if (!existingBodyVars.isEmpty()) {
                                delete as user existingBodyVars;
                            }
        
                            while (matcher.find()) {
                                String placeholder = matcher.group();
        
                                if (!processedBodyPlaceholders.contains(placeholder)) {
                                    processedBodyPlaceholders.add(placeholder);
                            
                                    if ((variableIndex < varAlternateTexts.size())) {
                                        Template_Variable__c bodyVariable ;
                                        bodyVariable = new Template_Variable__c(
                                            Name = placeholder,
                                            Object_Name__c = parsedFields[variableIndex].get('objectName'),
                                            Field_Name__c = parsedFields[variableIndex].get('fieldName'), 
                                            Type__c = 'Body',
                                            Alternate_Text__c = varAlternateTexts[variableIndex]
                                        );
                                        variableRecords.add(bodyVariable);
                                    }
                                    variableIndex++; 
                                }
                            }
                        }
                    }
                }
                // FOOTER Component
                else if (type == 'FOOTER') {
                    whatsAppTemplate.WBFooter_Body__c = (String) component.get('text');
                }
                // BUTTONS Component
                else if (type == 'BUTTONS') {
                    List<Object> buttons = (List<Object>) component.get('buttons');
                    for (Object buttonObj : buttons) {
                        if (buttonObj instanceof Map<String, Object>) {
                            Map<String, Object> button = (Map<String, Object>) buttonObj;
                            String buttonType = (String) button.get('type');
                            String buttonText = (String) button.get('text');
        
                            // ✅ Correct check for marketing opt-out
                            if (buttonText == templateWrapper.marketingOptText) {
                                button.put('isMarketingOpt', true);
                            }
                        }
                    }
                    buttonDetails = handleButtonComponent(component);
                    whatsAppTemplate.WBButton_Body__c = buttonDetails;
                    
                }
            }
    
            upsert as user whatsAppTemplate;
            templateId = whatsAppTemplate.Id;

            for (Template_Variable__c variable : variableRecords) {
                variable.WhatsappTemplate__c = whatsAppTemplate.Id;
            }

            if (!variableRecords.isEmpty()) {
                upsert as user variableRecords;
            }

            // Success response
            response.put('success', true);
            response.put('templateId', templateId);
    
        } catch (Exception e) {
            // Error response handling
            response.put('success', false);
            response.put('errorMessage', e.getMessage());
            ErrorHandler.insertErrordata(e, 'CreateTemplateWrapper', 'handleSuccessResponse', 'Error while handling success response.');
        }
        return templateId; 
    }
    
     /*
    *********************************************************
    @description     : Handle body to get the alternate text.
    @param           : category,component,example - {String,Map<String, Object>,Map<String, Object>} 
    @return          : result - contain the body text, parsefields use to create Template_Variable record.
    ********************************************************
    */
    private static Map<String, Object> handleBodyComponent(String category, Map<String, Object> component, Map<String, Object> example) {
        Map<String, Object> result = new Map<String, Object>(); 
        try {
            String bodyText = (String) component.get('text');
            String bodyMergeText = '';  
            List<Map<String, String>> parsedFields = new List<Map<String, String>>(); 
    
            if (example != null && example.containsKey('body_text')) {
                Object bodyTextObj = example.get('body_text');
    
                if (bodyTextObj instanceof List<Object>) {
                    List<Object> outerList = (List<Object>) bodyTextObj;
    
                    if (!outerList.isEmpty() && outerList[0] instanceof List<Object>) {
                        List<Object> innerList = (List<Object>) outerList[0];
                        List<String> stringList = new List<String>();
    
                        for (Object obj : innerList) {
                            if (obj instanceof String) {
                                String fieldRef = (String) obj;
                                stringList.add(fieldRef);
    
                                if (fieldRef.contains('.')) {
                                    fieldRef = fieldRef.replace('{{', '').replace('}}', '');
                                    List<String> parts = fieldRef.split('\\.');
                                    Map<String, String> fieldMap = new Map<String, String>();
                                    fieldMap.put('objectName',parts[0]);
                                    fieldMap.put('fieldName', parts[1]); 
                                    parsedFields.add(fieldMap);
                                }
                            }
                        }
    
                        if (!stringList.isEmpty()) {
                            bodyMergeText = String.join(stringList, ',');
                        }
                    }
                }
            }
    
            result.put('bodyText', bodyText);
            result.put('bodyMergeText', bodyMergeText);
            result.put('parsedFields', parsedFields); 
    
        } catch (Exception e) {
             ErrorHandler.insertErrordata(e, 'CreateTemplateWrapper', 'handleBodyComponent', 'Error while handling body component.');
            result.put('bodyText', '');  
            result.put('bodyMergeText', '');
            result.put('parsedFields', new List<Map<String, String>>()); 
        }
    
        return result; 
    }

      /*
    *********************************************************
    @description     : Handle buttons for different type of buttons.
    @param           : component - {Map<String, Object> 
    @return          : buttonDetails - contain type ,label and value of different buttons.
    ********************************************************
    */
    private static String handleButtonComponent(Map<String, Object> component) {
        String buttonList = '';
        try {
            List<Object> buttons = (List<Object>) component.get('buttons');
    
            if (buttons != null) {
                buttonList = (String) JSON.serialize(buttons);
                
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'CreateTemplateWrapper', 'handleButtonComponent', e.getMessage());
        }
        return buttonList; 
    }
    
      /*
    *********************************************************
    @description     : Used to format text
    @param           : bodyText - text that need to format.
    @return          : bodyText (String) - formatted bodytext.
    ********************************************************
    */
    

    public class TemplateWrapper {      
        @AuraEnabled public String templateName;
        @AuraEnabled public String templateCategory;
        @AuraEnabled public String templateType;
        @AuraEnabled public String tempHeaderFormat;
        @AuraEnabled public String tempHeaderHandle;
        @AuraEnabled public String tempLanguage;
        @AuraEnabled public String tempHeaderText;
        @AuraEnabled public List<String> tempHeaderExample;
        @AuraEnabled public List<String> headAlternateTexts;
        @AuraEnabled public List<String> varAlternateTexts;
        @AuraEnabled public String templateBody;
        @AuraEnabled public List<String> templateBodyText;
        @AuraEnabled public String tempFooterText;
        @AuraEnabled public String typeOfButton;
        @AuraEnabled public String url;
        @AuraEnabled public String tempImgUrl;
        @AuraEnabled public String tempImgName;
        @AuraEnabled public String tempImgId;
        @AuraEnabled public Integer expireTime;
        
        @AuraEnabled public Boolean autofillCheck;  
        @AuraEnabled public List<String> packagename;  
        @AuraEnabled public List<String> signaturename;  
        @AuraEnabled public String marketingOptText;  
        @AuraEnabled public String templateMiscellaneousData;
        
        @AuraEnabled public String selectedFlow;
        @AuraEnabled public Boolean isSecurityRecommedation;
        @AuraEnabled public Boolean isCodeExpiration;
        
    }

}