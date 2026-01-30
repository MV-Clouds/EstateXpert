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
    public static String signatureImageCvId {get; set;}
    public static String signatureKey {get; set;}
    public static Decimal signatureSize {get; set;}
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

                signatureKey = KeyMappingController.signatureKey;
                imageMaxSize = KeyMappingController.maxImageSize;
    
                List<Template__c> temp = new List<Template__c>();

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
            List<Template__c> temp = [SELECT Id, Template_Name__c, Signature_Size__c, 
                            (SELECT Id, Template_Value_Simple__c,Value_Type__c FROM Template_Data__r WHERE Value_Type__c IN: getValueTypes ORDER BY Order_No_Simple__c ASC),
                            (SELECT Id, Page_Margin__c, Page_Orientation__c, Page_Size__c, Unit_of_Page_Configs__c, Show_Header__c, Show_Footer__c, Header_margin_top__c, Footer_margin_bottom__c FROM Template_Pages__r ORDER BY Page_Number__c ASC)
                            FROM Template__c WHERE Id =: templateID WITH USER_MODE LIMIT 1 ];

            if(temp.size() > 0){
                Template_Page__c pageConfigs = temp[0].Template_Pages__r[0];
                showHeader = pageConfigs.Show_Header__c;
                showFooter = pageConfigs.Show_Footer__c;
                pageMargins = pageConfigs.Page_Margin__c;
                pageConfigUnit = pageConfigs.Unit_of_Page_Configs__c;
                pageOrientation = pageConfigs.Page_Orientation__c;
                pageSize = pageConfigs.Page_Size__c;
                headerMarginTop = pageConfigs.Header_margin_top__c;
                footerMarginBottom = pageConfigs.Footer_margin_bottom__c;
                
                for(Template_Data__c fieldData : temp[0].Template_Data__r){
                    String value = fieldData.Template_Value_Simple__c != null ? fieldData.Template_Value_Simple__c : '';
                    if(fieldData.Value_Type__c == 'Body Value'){
                        bodyHtml += value;
                    }
                    else if(fieldData.Value_Type__c == 'Header Value' && showHeader == true){
                        headerHtml += value;
                    }
                    else if(fieldData.Value_Type__c == 'Footer Value' && showFooter == true){
                        footerHtml += value;
                    }
                }    

                signatureSize = temp[0].Signature_Size__c != null ? temp[0].Signature_Size__c : 50;
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
            signatureImageCvId = JSON.serialize(mappingKeys.get('signatureImage'));

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
    
            List<Template__c> temp = [SELECT Id, Template_pattern__c, Template_Name__c, Template_Status__c FROM Template__c WHERE Id =: templateId WITH USER_MODE LIMIT 1];
    
            if(temp.size() > 0 && temp[0]?.Template_pattern__c == 'PDF Template' && temp[0]?.Template_Status__c == true ){
    
                Integer batchSize = 25;
                
                Integer bodyValueRecords = Database.countQuery('SELECT Count() FROM MVEX__Template_Data__c WHERE MVEX__Template__c =: templateId AND MVEX__Value_Type__c = \'Body Value\'');
    
                Integer endIndex = (offset + batchSize) >= bodyValueRecords ? bodyValueRecords : (offset + batchSize);
                isLastBatch = (offset + batchSize) >= bodyValueRecords ? true : false;
    
                for(Template_Data__c fieldData : [SELECT Id, Order_No_Simple__c, Template_Value_Simple__c, Value_Type__c FROM Template_Data__c
                                                    WHERE Template__c = : templateId AND Order_No_Simple__c >= :offset AND Order_No_Simple__c <= :endIndex
                                                    AND Value_Type__c =: 'Body Value' WITH USER_MODE ORDER BY Order_No_Simple__c ASC]){
                    String data = fieldData.Template_Value_Simple__c;
                    bodyHtml.add(data);
                }

                return new list<string>{string.valueOf(isLastBatch), string.join(bodyHtml,'').unescapeHtml4()};
            } else if (temp.size() > 0 && temp[0]?.Template_pattern__c == 'PDF Template' && temp[0]?.Template_Status__c == false) {
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

    public static void getS3ConfigSettings(){
        try {
            AWS_Config__c awsData = AWS_Config__c.getOrgDefaults();
            awsAccessKey = awsData.AWS_Access_Key__c;
            awsSecretKey = awsData.AWS_Secret_Access_Key__c;
            awsRegion = awsData.S3_Region_Name__c;
            awsBucketName = awsData.S3_Bucket_Name__c;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'ImageAndMediaController', 'getS3ConfigSettings', 'Error while getting AWS_Config__c record.');
        }
    }

    @RemoteAction
    global static string fetchSignatureBase64(String id){
        return null;
    }
}