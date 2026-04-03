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

        System.debug('Handling success response for template creation');
        System.debug('Meta Template ID: ' + metaTempId);
        System.debug('Meta Template Status: ' + metaTemplateStatus);
        System.debug('Payload: ' + payload);
        System.debug('Template Wrapper: ' + templateWrapper);

        Map<String, Object> response = new Map<String, Object>();
        Id templateId = null;
        try {
            // Deserialize the payload
            Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(payload));
            System.debug('Payload Map: ' + payloadMap);
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
            
            // Populate Template__c fields dynamically
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
            System.debug('Components: ' + components);
            List<VariableWrapper> headerVariables = templateWrapper.header_variables != null ? templateWrapper.header_variables : new List<VariableWrapper>(); 
            List<VariableWrapper> bodyVariables = templateWrapper.variables != null ? templateWrapper.variables : new List<VariableWrapper>();   

            System.debug('===== VARIABLE DEBUG START =====');
            System.debug('Header Variables Count: ' + (headerVariables != null ? headerVariables.size() : 0));
            System.debug('Body Variables Count: ' + (bodyVariables != null ? bodyVariables.size() : 0));
            if (headerVariables != null && !headerVariables.isEmpty()) {
                for (Integer i = 0; i < headerVariables.size(); i++) {
                    VariableWrapper hv = headerVariables[i];
                    System.debug('Header Var ' + i + ': objectName=' + hv.objectName + ', fieldName=' + hv.fieldName + ', alternateText=' + hv.alternateText);
                }
            }
            if (bodyVariables != null && !bodyVariables.isEmpty()) {
                for (Integer i = 0; i < bodyVariables.size(); i++) {
                    VariableWrapper bv = bodyVariables[i];
                    System.debug('Body Var ' + i + ': objectName=' + bv.objectName + ', fieldName=' + bv.fieldName + ', alternateText=' + bv.alternateText);
                }
            }
            System.debug('===== VARIABLE DEBUG END =====');

            Integer headerIndex = 0;
            Integer variableIndex = 0; 
            String headerMergeText = '';
    
            // Process components
            for (Object comp : components) {
                if (!(comp instanceof Map<String, Object>)) {
                    continue;
                }

                Map<String, Object> component = (Map<String, Object>) comp;
                System.debug('Component: ' + component);
                String type = (String) component.get('type');
                Map<String, Object> example = (Map<String, Object>) component.get('example');
                System.debug('Example: ' + example);

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
                        Pattern pattern = Pattern.compile('\\{\\{(\\d+)\\}\\}');
                        Matcher matcher = pattern.matcher((String) component.get('text'));

                        List<Template_Variable__c> existingHeaderVar = [ SELECT Id, Name FROM Template_Variable__c WHERE WhatsappTemplate__c = :whatsAppTemplate.Id AND Type__c = 'Header'];
                        if (!existingHeaderVar.isEmpty()) {
                            delete existingHeaderVar;
                        }

                        while (matcher.find() && headerIndex < headerVariables.size()) {
                            String placeholder = matcher.group();
                            VariableWrapper varData = headerVariables[headerIndex];
                            
                            System.debug('Processing Header Variable: placeholder=' + placeholder + ', objectName=' + varData.objectName + ', fieldName=' + varData.fieldName);
                            
                            if (varData.objectName != null && varData.fieldName != null) {
                                Template_Variable__c headerVariable = new Template_Variable__c(
                                    Name = placeholder,
                                    Object_Name__c = varData.objectName,
                                    Field_Name__c = varData.fieldName,
                                    Type__c = 'Header',
                                    Alternate_Text__c = varData.alternateText
                                );
                                variableRecords.add(headerVariable);
                                System.debug('Added Header Variable to list: ' + headerVariable);
                            } else {
                                System.debug('SKIPPED Header Variable - objectName or fieldName is null');
                            }
                            headerIndex++;
                        }
                    }
                }
                // BODY Component
                else if (type == 'BODY') {
                    Map<String, Object> result = handleBodyComponent(whatsAppTemplate.Template_Category__c, component, example);

                    System.debug('Body Component Result: ' + result);
                    
                    if(((String) result.get('bodyText')) != null){
                        whatsAppTemplate.WBTemplate_Body__c = String.isNotBlank((String) result.get('bodyText')) ? (String) result.get('bodyText') : '';

                        if(whatsAppTemplate.Template_Category__c != 'Authentication'){
                            Pattern pattern = Pattern.compile('\\{\\{(\\d+)\\}\\}');
                            Matcher matcher = pattern.matcher((String) result.get('bodyText'));
                            Set<String> processedBodyPlaceholders = new Set<String>();
        
                            List<Template_Variable__c> existingBodyVars = [ SELECT Id, Name FROM Template_Variable__c WHERE WhatsappTemplate__c = :whatsAppTemplate.Id AND Type__c = 'Body'];
        
                            if (!existingBodyVars.isEmpty()) {
                                delete existingBodyVars;
                            }
        
                            while (matcher.find()) {
                                String placeholder = matcher.group();
        
                                if (!processedBodyPlaceholders.contains(placeholder) && variableIndex < bodyVariables.size()) {
                                    processedBodyPlaceholders.add(placeholder);
                                    VariableWrapper varData = bodyVariables[variableIndex];
                            
                                    System.debug('Processing Body Variable: placeholder=' + placeholder + ', objectName=' + varData.objectName + ', fieldName=' + varData.fieldName);
                            
                                    if (varData.objectName != null && varData.fieldName != null) {
                                        Template_Variable__c bodyVariable = new Template_Variable__c(
                                            Name = placeholder,
                                            Object_Name__c = varData.objectName,
                                            Field_Name__c = varData.fieldName, 
                                            Type__c = 'Body',
                                            Alternate_Text__c = varData.alternateText
                                        );
                                        variableRecords.add(bodyVariable);
                                        System.debug('Added Body Variable to list: ' + bodyVariable);
                                    } else {
                                        System.debug('SKIPPED Body Variable - objectName or fieldName is null');
                                    }
                                    variableIndex++; 
                                }
                            }
                        }
                    }
                }
                // FOOTER Component
                else if (type == 'FOOTER' && whatsAppTemplate.Template_Category__c != 'Authentication') {
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
    
            upsert whatsAppTemplate;
            templateId = whatsAppTemplate.Id;

            System.debug('===== BEFORE VARIABLE UPSERT =====');
            System.debug('Template ID: ' + templateId);
            System.debug('Variable Records Count: ' + variableRecords.size());
            for (Template_Variable__c var : variableRecords) {
                System.debug('Variable to upsert: Name=' + var.Name + ', Object=' + var.Object_Name__c + ', Field=' + var.Field_Name__c);
            }
            System.debug('===== END VARIABLE UPSERT DEBUG =====');

            for (Template_Variable__c variable : variableRecords) {
                variable.WhatsappTemplate__c = whatsAppTemplate.Id;
            }

            if (!variableRecords.isEmpty()) {
                upsert variableRecords;
                System.debug('Successfully upserted ' + variableRecords.size() + ' variable records');
            } else {
                System.debug('WARNING: No variable records to upsert');
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
    @description     : Handle body component to extract body text.
    @param           : category,component,example - {String,Map<String, Object>,Map<String, Object>} 
    @return          : result - contains the body text.
    ********************************************************
    */
    private static Map<String, Object> handleBodyComponent(String category, Map<String, Object> component, Map<String, Object> example) {
        Map<String, Object> result = new Map<String, Object>(); 
        try {
            System.debug('Handling body component for category: ' + category);
            System.debug('Component: ' + component);
            String bodyText = (String) component.get('text');
    
            result.put('bodyText', bodyText);
            System.debug('Body Text: ' + bodyText);
            System.debug('Finished handling body component');
        } catch (Exception e) {
            // ErrorHandler.insertErrordata(e, 'CreateTemplateWrapper', 'handleBodyComponent', 'Error while handling body component.');
            result.put('bodyText', '');  
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
            // ErrorHandler.insertErrordata(e, 'CreateTemplateWrapper', 'handleButtonComponent', 'Error while handling button component.');
        }
        return buttonList; 
    }
    
    public class TemplateWrapper {      
        @AuraEnabled public String templateName;
        @AuraEnabled public String templateCategory;
        @AuraEnabled public String templateType;
        @AuraEnabled public String tempHeaderFormat;
        @AuraEnabled public String tempHeaderHandle;
        @AuraEnabled public String tempLanguage;
        @AuraEnabled public String tempHeaderText;
        @AuraEnabled public List<String> tempHeaderExample;
        @AuraEnabled public String templateBody;
        @AuraEnabled public List<String> templateBodyText;
        @AuraEnabled public String tempFooterText;
        @AuraEnabled public String typeOfButton;
        @AuraEnabled public String tempImgUrl;  // Required for media headers
        @AuraEnabled public String tempImgName; // Required for media headers
        @AuraEnabled public String tempImgId;   // Required for media headers
        @AuraEnabled public List<String> packagename;  
        @AuraEnabled public List<String> signaturename;  
        @AuraEnabled public String marketingOptText;  // Required for button opt-out identification
        @AuraEnabled public String templateMiscellaneousData;
        @AuraEnabled public List<VariableWrapper> variables;
        @AuraEnabled public List<VariableWrapper> header_variables;
    }
    
    public class VariableWrapper {
        @AuraEnabled public String placeholder;
        @AuraEnabled public String alternateText;
        @AuraEnabled public String objectName;
        @AuraEnabled public String fieldName;
        @AuraEnabled public String variableType;
    }
}