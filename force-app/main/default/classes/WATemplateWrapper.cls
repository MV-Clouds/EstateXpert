/**
 * @description       : Wrapper and helper class for handling WhatsApp message template records (WA_Template__c)
 *                      and their variable mappings (WA_Template_Variable__c), referencing OAuth_Configuration__mdt
 *                      for Whatsapp_OAuth metadata configuration.
 * @author            : Karan Singh
 * @last modified on  : 12/10/2026
 **/
public with sharing class WATemplateWrapper {
    @TestVisible
    private static OAuth_Configuration__mdt mockConfig;

    /**
     * @description : Retrieves the WhatsApp OAuth Custom Metadata configuration record for Whatsapp_OAuth
     * @return OAuth_Configuration__mdt
     */
    public static OAuth_Configuration__mdt getConfig() {
        try {
            if (mockConfig != null) {
                return mockConfig;
            }
            String CONFIGDEVNAME = WhatsappConnectController.CONFIG_DEV_NAME;

            List<OAuth_Configuration__mdt> configs = [SELECT Id, DeveloperName, MasterLabel, Client_Id__c, Client_Secret__c, Config_Id__c, API_Version__c, 
                                                        Authorization_Endpoint__c, Token_Endpoint__c, Access_Token__c, Client_App_ID__c, Client_Business_Account_ID__c,
                                                        Client_Phone_Number_ID__c, Connected_Date__c, SystemModstamp FROM OAuth_Configuration__mdt
                                                        WHERE DeveloperName = :CONFIGDEVNAME WITH USER_MODE LIMIT 1];
            return configs.isEmpty() ? null : configs[0];
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'WATemplateWrapper', 'getConfig', e.getMessage());
            return null;
        }
    }

    /*
    *********************************************************
    @description     : Handle response and store all in the template (WA_Template__c) and template variable (WA_Template_Variable__c) records.
    @param           : metaTempId, metaTemplateStatus, payload, templateWrapper
    @return          : templateId of created/updated WA_Template__c record.
    ********************************************************
    */
    public static Id handleSuccessResponse(String metaTempId, String metaTemplateStatus, Map<String, Object> payload, TemplateWrapper templateWrapper) {
        Id templateId = null;
        try {
            if (templateWrapper == null) {
                return null;
            }

            // Deserialize the payload if provided
            Map<String, Object> payloadMap = (payload != null) 
                ? (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(payload)) 
                : new Map<String, Object>();

            String templateName = String.isNotBlank(templateWrapper.templateName) 
                ? templateWrapper.templateName 
                : (String) payloadMap.get('name');

            // Find existing WA_Template__c by name or Meta template ID
            List<WA_Template__c> existingTemplates = [SELECT Id, Name, Template_Name__c, Template_Id__c FROM WA_Template__c WHERE (Template_Name__c = :templateName 
                                                        AND Template_Name__c != null) OR (Template_Id__c = :metaTempId AND Template_Id__c != null) 
                                                        WITH USER_MODE LIMIT 1];

            WA_Template__c whatsAppTemplate;
            if (!existingTemplates.isEmpty()) {
                whatsAppTemplate = existingTemplates[0];
            } else {
                whatsAppTemplate = new WA_Template__c();
            }

            // Populate WA_Template__c fields
            if (metaTempId != null) {
                whatsAppTemplate.Template_Id__c = metaTempId;
            }
            whatsAppTemplate.Status__c = String.isNotBlank(metaTemplateStatus) 
                ? metaTemplateStatus 
                : (whatsAppTemplate.Status__c != null ? whatsAppTemplate.Status__c : 'PENDING');
            whatsAppTemplate.Template_Name__c = templateName;
            whatsAppTemplate.Template_Category__c = String.isNotBlank(templateWrapper.templateCategory) 
                ? templateWrapper.templateCategory 
                : (String) payloadMap.get('category');
            whatsAppTemplate.Language__c = String.isNotBlank(templateWrapper.tempLanguage) 
                ? templateWrapper.tempLanguage 
                : (String) payloadMap.get('language');
            whatsAppTemplate.Template_Miscellaneous_Data__c = templateWrapper.templateMiscellaneousData;

            // Initialize variable records
            List<WA_Template_Variable__c> variableRecords = new List<WA_Template_Variable__c>();
            List<Object> components = (List<Object>) payloadMap.get('components');

            List<VariableWrapper> headerVariables = templateWrapper.header_variables != null ? templateWrapper.header_variables : new List<VariableWrapper>(); 
            List<VariableWrapper> bodyVariables = templateWrapper.variables != null ? templateWrapper.variables : new List<VariableWrapper>();   

            Integer headerIndex = 0;
            Integer variableIndex = 0;

            // Process payload components if available
            if (components != null && !components.isEmpty()) {
                for (Object comp : components) {
                    if (!(comp instanceof Map<String, Object>)) {
                        continue;
                    }

                    Map<String, Object> component = (Map<String, Object>) comp;
                    String type = (String) component.get('type');
                    Map<String, Object> example = (Map<String, Object>) component.get('example');

                    // HEADER Component
                    if (type == 'HEADER') {
                        whatsAppTemplate.Header_Type__c = (String) component.get('format');
                        if (whatsAppTemplate.Header_Type__c == 'IMAGE' || whatsAppTemplate.Header_Type__c == 'VIDEO' || whatsAppTemplate.Header_Type__c == 'DOCUMENT') {
                            whatsAppTemplate.Header_Body__c = templateWrapper.tempImgUrl;
                            whatsAppTemplate.File_Name__c = templateWrapper.tempImgName;
                            whatsAppTemplate.Image_Header_Handle__c = templateWrapper.tempHeaderHandle;
                        } else {
                            whatsAppTemplate.Header_Body__c = (String) component.get('text');
                        }

                        if (example != null && (example.containsKey('header_text') || example.containsKey('header_text_named_params'))) {
                            Pattern pattern = Pattern.compile('\\{\\{([^}]+)\\}\\}');
                            Matcher matcher = pattern.matcher((String) component.get('text'));

                            while (matcher.find() && headerIndex < headerVariables.size()) {
                                String placeholder = matcher.group();
                                VariableWrapper varData = headerVariables[headerIndex];
                                if (varData.objectName != null && varData.fieldName != null) {
                                    variableRecords.add(new WA_Template_Variable__c(
                                        Name = placeholder,
                                        Object_Name__c = varData.objectName,
                                        Field_Name__c = varData.fieldName,
                                        Type__c = 'Header',
                                        Alternate_Text__c = varData.alternateText
                                    ));
                                }
                                headerIndex++;
                            }
                        }
                    }
                    // BODY Component
                    else if (type == 'BODY') {
                        Map<String, Object> result = handleBodyComponent(component);
                        if (result.get('bodyText') != null) {
                            whatsAppTemplate.Template_Body__c = String.isNotBlank((String) result.get('bodyText')) ? (String) result.get('bodyText') : '';

                            Pattern pattern = Pattern.compile('\\{\\{([^}]+)\\}\\}');
                            Matcher matcher = pattern.matcher((String) result.get('bodyText'));
                            Set<String> processedBodyPlaceholders = new Set<String>();

                            while (matcher.find()) {
                                String placeholder = matcher.group();
                                if (!processedBodyPlaceholders.contains(placeholder) && variableIndex < bodyVariables.size()) {
                                    processedBodyPlaceholders.add(placeholder);
                                    VariableWrapper varData = bodyVariables[variableIndex];
                                    if (varData.objectName != null && varData.fieldName != null) {
                                        variableRecords.add(new WA_Template_Variable__c(
                                            Name = placeholder,
                                            Object_Name__c = varData.objectName,
                                            Field_Name__c = varData.fieldName, 
                                            Type__c = 'Body',
                                            Alternate_Text__c = varData.alternateText
                                        ));
                                    }
                                    variableIndex++;
                                }
                            }
                        }
                    }
                    // FOOTER Component
                    else if (type == 'FOOTER') {
                        whatsAppTemplate.Footer_Body__c = (String) component.get('text');
                    }
                    // BUTTONS Component
                    else if (type == 'BUTTONS') {
                        List<Object> buttons = (List<Object>) component.get('buttons');
                        if (buttons != null) {
                            for (Object buttonObj : buttons) {
                                if (buttonObj instanceof Map<String, Object>) {
                                    Map<String, Object> button = (Map<String, Object>) buttonObj;
                                    String buttonText = (String) button.get('text');
                                    if (buttonText == templateWrapper.marketingOptText) {
                                        button.put('isMarketingOpt', true);
                                    }
                                }
                            }
                        }
                        String buttonDetails = handleButtonComponent(component);
                        whatsAppTemplate.Button_Body__c = buttonDetails;
                    }
                }
            } else {
                // If components array was not passed, use wrapper fields directly
                whatsAppTemplate.Header_Type__c = templateWrapper.tempHeaderFormat;
                whatsAppTemplate.Header_Body__c = templateWrapper.tempHeaderText;
                whatsAppTemplate.Image_Header_Handle__c = templateWrapper.tempHeaderHandle;
                whatsAppTemplate.File_Name__c = templateWrapper.tempImgName;
                whatsAppTemplate.Template_Body__c = templateWrapper.templateBody;
                whatsAppTemplate.Footer_Body__c = templateWrapper.tempFooterText;
                whatsAppTemplate.Button_Body__c = templateWrapper.typeOfButton;
            }

            // If header/body was not populated from components, fallback to wrapper
            if (String.isBlank(whatsAppTemplate.Template_Body__c) && String.isNotBlank(templateWrapper.templateBody)) {
                whatsAppTemplate.Template_Body__c = templateWrapper.templateBody;
            }
            if (String.isBlank(whatsAppTemplate.Header_Body__c) && String.isNotBlank(templateWrapper.tempHeaderText)) {
                whatsAppTemplate.Header_Body__c = templateWrapper.tempHeaderText;
            }
            if (String.isBlank(whatsAppTemplate.Footer_Body__c) && String.isNotBlank(templateWrapper.tempFooterText)) {
                whatsAppTemplate.Footer_Body__c = templateWrapper.tempFooterText;
            }
            if (String.isBlank(whatsAppTemplate.Button_Body__c) && String.isNotBlank(templateWrapper.typeOfButton)) {
                whatsAppTemplate.Button_Body__c = templateWrapper.typeOfButton;
            }
            if (String.isBlank(whatsAppTemplate.Header_Type__c) && String.isNotBlank(templateWrapper.tempHeaderFormat)) {
                whatsAppTemplate.Header_Type__c = templateWrapper.tempHeaderFormat;
            }
            if (String.isBlank(whatsAppTemplate.File_Name__c) && String.isNotBlank(templateWrapper.tempImgName)) {
                whatsAppTemplate.File_Name__c = templateWrapper.tempImgName;
            }
            if (String.isBlank(whatsAppTemplate.Image_Header_Handle__c) && String.isNotBlank(templateWrapper.tempHeaderHandle)) {
                whatsAppTemplate.Image_Header_Handle__c = templateWrapper.tempHeaderHandle;
            }

            upsert as user whatsAppTemplate;
            templateId = whatsAppTemplate.Id;

            // Delete existing WA_Template_Variable__c records for this template
            List<WA_Template_Variable__c> existingVars = [
                SELECT Id FROM WA_Template_Variable__c 
                WHERE WA_Template__c = :templateId 
                WITH USER_MODE
            ];
            if (!existingVars.isEmpty() && WA_Template_Variable__c.sObjectType.getDescribe().isDeletable()) {
                delete existingVars;
            }

            // If variables were not mapped via payload matching, map directly from templateWrapper
            if (variableRecords.isEmpty()) {
                if (templateWrapper.variables != null) {
                    for (VariableWrapper vw : templateWrapper.variables) {
                        if (vw.objectName != null && vw.fieldName != null) {
                            variableRecords.add(new WA_Template_Variable__c(
                                WA_Template__c = templateId,
                                Name = vw.placeholder,
                                Object_Name__c = vw.objectName,
                                Field_Name__c = vw.fieldName,
                                Type__c = 'Body',
                                Alternate_Text__c = vw.alternateText
                            ));
                        }
                    }
                }
                if (templateWrapper.header_variables != null) {
                    for (VariableWrapper vw : templateWrapper.header_variables) {
                        if (vw.objectName != null && vw.fieldName != null) {
                            variableRecords.add(new WA_Template_Variable__c(
                                WA_Template__c = templateId,
                                Name = vw.placeholder,
                                Object_Name__c = vw.objectName,
                                Field_Name__c = vw.fieldName,
                                Type__c = 'Header',
                                Alternate_Text__c = vw.alternateText
                            ));
                        }
                    }
                }
            } else {
                for (WA_Template_Variable__c variable : variableRecords) {
                    variable.WA_Template__c = templateId;
                }
            }

            if (!variableRecords.isEmpty() && WA_Template_Variable__c.sObjectType.getDescribe().isCreateable()) {
                insert as user variableRecords;
            }

        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'WATemplateWrapper', 'handleSuccessResponse', e.getMessage());
        }
        return templateId; 
    }
    
    /*
    *********************************************************
    @description     : Handle body component to extract body text.
    @param           : component - Map<String, Object>
    @return          : result - contains the body text.
    ********************************************************
    */
    private static Map<String, Object> handleBodyComponent(Map<String, Object> component) {
        Map<String, Object> result = new Map<String, Object>(); 
        try {
            String bodyText = (String) component.get('text');
            result.put('bodyText', bodyText != null ? bodyText : '');
        } catch (Exception e) {
            result.put('bodyText', '');  
        }
        return result; 
    }

    /*
    *********************************************************
    @description     : Handle buttons for different type of buttons.
    @param           : component - Map<String, Object>
    @return          : buttonDetails - JSON string of button list
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
            ErrorHandler.insertErrorData(e, 'WATemplateWrapper', 'handleButtonComponent', e.getMessage());
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