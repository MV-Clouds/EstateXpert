global with sharing class DocGenerateController {

    public static String paraData {get; set;}
    public static String selectedExtension {get; set;}
    public static String selectedChannels {get; set;}
    public static String recordId {get; set;}
    public static String fileName {get; set;}
    public static String templateId {get; set;}
    public static String useMode {get; set;}

    public static String headerHtml {get; set;}
    public static String bodyHtml {get; set;}
    public static String footerHtml {get; set;}

    public static String pageMargins {get; set;}
    public static String pageConfigUnit {get; set;}
    public static String pageSize {get; set;}
    public static String pageOrientation {get; set;}

    public static Decimal headerMarginTop {get; set;}
    public static Decimal footerMarginBottom {get; set;}
    public static Boolean showHeader {get; set;}
    public static Boolean showFooter {get; set;}

    public static Boolean isBatchRequired {get; set;}

    public static String mappingKeyVsMappingValues {get; set;}
    public static String salesforceImages {get; set;}
    public static String mergeTemplateKeys {get; set;}
    public static integer imageMaxSize {get; set;}

    public static String sessionId {get; set;}
    
    public static string apexError {get; set;}

    public static String listingImageMedia {get; set;}

    public static string awsAccessKey {get; set;}
    public static string awsSecretKey {get; set;}
    public static string awsRegion {get; set;}
    public static string awsBucketName {get; set;}

    /**
     * constructor :  DocGenerateController
     * @description : run when vf page call, entry point of all the vf page methods...
     */
    global DocGenerateController() {
        sessionId = GenerateDocumentController.getSessionId();
        getTemplateDetails();
    }

    /**
     * method : getTemplateDetails
     * @description : get template detail and tempate data and template page configuration for document generation
     */
    public static void getTemplateDetails(){
        try {
            if(ApexPages.currentPage().getParameters().get('paraData') != null){
                String paraData = ApexPages.currentPage().getParameters().get('paraData');
                Map<String, Object> rawData = (Map<String, Object>)JSON.deserializeUntyped(paraData);
    
                selectedExtension = (String)rawData.get('selectedExtension');
                selectedChannels = (String)rawData.get('selectedChannels');
                fileName = (String)rawData.get('fileName');
                useMode = (String)rawData.get('useMode') != null ? (String)rawData.get('useMode') : 'generate';

                templateId = (String)rawData.get('templateId');
                recordId = (String)rawData.get('recordId');

                bodyHtml = '';
                headerHtml = '';
                footerHtml = '';

                imageMaxSize = KeyMappingController.maxImageSize;
    
                List<MVEX__Template__c> temp = new List<MVEX__Template__c>();

                List<String> valueTypes = new List<String>{'Body Value', 'Header Value', 'Footer Value'};
                Integer totalTemplateDataRecords = Database.countQuery('SELECT Count() FROM MVEX__Template_Data__c WHERE MVEX__Template__c =: templateId AND MVEX__Value_Type__c IN :valueTypes');

                // If totalTemplateDataRecords > 25 ,mease there is higher changes to code exceed heap size limit...
                // So only send 'Header Value' and 'Footer values' and send body value is batch...
                isBatchRequired = totalTemplateDataRecords > 25;
                List<String> getValueTypes = new List<String>{'Header Value', 'Footer Value'};

                if(isBatchRequired == false){
                    getValueTypes.add('Body Value');
                }

                setTemplateDetails(getValueTypes, templateID, recordId);
            }
            else {
                apexError = 'Document generation request not well in defied.';
            }

        }
        catch (Exception e){
            apexError = e.getMessage();
            ErrorHandler.insertErrorData(e, 'DocGenerateController', 'getTemplateDetails', 'Error while getting template details.');
        }
    }

    /**
     * @method setTemplateDetails
     * @param getValueTypes, list of template types
     * @param templateID, template Id String
     * @param recordId, sorce record id
     * @description : method to collect template deatils and template data for document generation.
     */
    public static void setTemplateDetails(List<String> getValueTypes, String templateID, String recordId){
        try {
            List<MVEX__Template__c> temp = [SELECT Id, MVEX__Template_Name__c, 
                            (SELECT Id, MVEX__Template_Value_Simple__c, MVEX__Value_Type__c FROM MVEX__Template_Data__r WHERE MVEX__Value_Type__c IN: getValueTypes ORDER BY MVEX__Order_No_Simple__c ASC),
                            (SELECT Id, MVEX__Page_Margin__c, MVEX__Page_Orientation__c, MVEX__Page_Size__c, MVEX__Unit_of_Page_Configs__c, MVEX__Show_Header__c, MVEX__Show_Footer__c, MVEX__Header_margin_top__c, MVEX__Footer_margin_bottom__c FROM MVEX__Template_Pages__r ORDER BY MVEX__Page_Number__c ASC)
                            FROM MVEX__Template__c WHERE Id =: templateID WITH USER_MODE LIMIT 1 ];

            if(temp.size() > 0){
                MVEX__Template_Page__c pageConfigs = temp[0].MVEX__Template_Pages__r[0];
                showHeader = pageConfigs.MVEX__Show_Header__c;
                showFooter = pageConfigs.MVEX__Show_Footer__c;
                pageMargins = pageConfigs.MVEX__Page_Margin__c;
                pageConfigUnit = pageConfigs.MVEX__Unit_of_Page_Configs__c;
                pageOrientation = pageConfigs.MVEX__Page_Orientation__c;
                pageSize = pageConfigs.MVEX__Page_Size__c;
                headerMarginTop = pageConfigs.MVEX__Header_margin_top__c;
                footerMarginBottom = pageConfigs.MVEX__Footer_margin_bottom__c;
                
                for(MVEX__Template_Data__c fieldData : temp[0].MVEX__Template_Data__r){
                    String value = fieldData.MVEX__Template_Value_Simple__c != null ? fieldData.MVEX__Template_Value_Simple__c : '';
                    if(fieldData.MVEX__Value_Type__c == 'Body Value'){
                        bodyHtml += value;
                    }
                    else if(fieldData.MVEX__Value_Type__c == 'Header Value' && showHeader == true){
                        headerHtml += value;
                    }
                    else if(fieldData.MVEX__Value_Type__c == 'Footer Value' && showFooter == true){
                        footerHtml += value;
                    }
                }
            }
            else{
                apexError = 'Template not available for deleted.';
            }

            // ---- ----- ----- Collect all mapping key with actual value ---- ----- -----
            Map<String, Map<String, String>> mappingKeys = DataMappingControllerV2.getMappingsKeyValues(new List<String>{temp[0].Id}, recordId, true);

            mappingKeyVsMappingValues = JSON.serialize(mappingKeys.get('objectNGeneral'));
            salesforceImages = JSON.serialize(mappingKeys.get('salesforceImages'));
            mergeTemplateKeys = JSON.serialize(mappingKeys.get('margeTemplate'));
            listingImageMedia = JSON.serialize(mappingKeys.get('listingMediaImages'));

        } catch (Exception e) {
            apexError = e.getMessage();
            ErrorHandler.insertErrorData(e, 'DocGenerateController', 'setTemplateDetails', 'Error while setting template details.');
        }
    }

    /**
     * method : fetchTemplateData
     * @param offset
     * @param templateId
     * @param mappingKey
     * @return list<string>
     * @description : fetch template data in batch for large template data and merge template.
     */
    @RemoteAction
    global static list<string> fetchTemplateData(Integer offset, String templateId, String mappingKey){
        try {
            Boolean isLastBatch = false;
            List<String> bodyHtml = new List<String>();
    
            mappingKey = mappingKey != null ? mappingKey : '';
    
            List<MVEX__Template__c> temp = [SELECT Id, MVEX__Template_pattern__c, MVEX__Template_Name__c, MVEX__Template_Status__c FROM MVEX__Template__c WHERE Id =: templateId WITH USER_MODE LIMIT 1];
    
            if(temp.size() > 0 && temp[0]?.MVEX__Template_pattern__c == 'PDF Template' && temp[0]?.MVEX__Template_Status__c == true ){
    
                Integer batchSize = 25;
                
                Integer bodyValueRecords = Database.countQuery('SELECT Count() FROM MVEX__Template_Data__c WHERE MVEX__Template__c =: templateId AND MVEX__Value_Type__c = \'Body Value\'');
    
                Integer endIndex = (offset + batchSize) >= bodyValueRecords ? bodyValueRecords : (offset + batchSize);
                isLastBatch = (offset + batchSize) >= bodyValueRecords ? true : false;
    
                for(MVEX__Template_Data__c fieldData : [SELECT Id, MVEX__Order_No_Simple__c, MVEX__Template_Value_Simple__c, MVEX__Value_Type__c FROM MVEX__Template_Data__c
                                                    WHERE MVEX__Template__c = : templateId AND MVEX__Order_No_Simple__c >= :offset AND MVEX__Order_No_Simple__c <= :endIndex
                                                    AND MVEX__Value_Type__c =: 'Body Value' WITH USER_MODE ORDER BY MVEX__Order_No_Simple__c ASC]){
                    String data = fieldData.MVEX__Template_Value_Simple__c;
                    bodyHtml.add(data);
                }

                return new list<string>{string.valueOf(isLastBatch), string.join(bodyHtml,'').unescapeHtml4()};
            } else if (temp.size() > 0 && temp[0]?.MVEX__Template_pattern__c == 'PDF Template' && temp[0]?.MVEX__Template_Status__c == false) {
                String data = '<span style="color: red;"> '+mappingKey+' --- Inactive Template --- </span>';
                bodyHtml.add(data);
                isLastBatch = true;
                return new list<string>{string.valueOf(isLastBatch), string.join(bodyHtml,'').unescapeHtml4()};
            }
            
            // if none of the above condition matched...
            String data = '<span style="color: red;"> '+mappingKey+' --- Template Deleted or Invalid Template Merge Key ---  </span>';
            bodyHtml.add(data);
            isLastBatch = true;
            
            return new list<string>{string.valueOf(isLastBatch), string.join(bodyHtml,'').unescapeHtml4()};
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'DocGenerateController', 'fetchTemplateData', 'Error while fetching template data.');
            return new list<string>{'true', ''};
        } 
    }

    @Deprecated
    global static string fetchSignatureBase64(String id){
        return null;
    }
}