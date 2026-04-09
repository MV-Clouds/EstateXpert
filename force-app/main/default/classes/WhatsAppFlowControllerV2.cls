public with sharing class WhatsAppFlowControllerV2 {

    public static List<MVEX__WBConnect_Configuration__mdt> wbConfig = [SELECT Id, MVEX__API_Endpoint__c, MVEX__API_Version__c, MVEX__Access_Token__c, MVEX__Business_Account_Id__c FROM MVEX__WBConnect_Configuration__mdt LIMIT 1];


    @AuraEnabled
    public static Map<String, String> getAllJSONData() {
        Map<String, String> jsonDataMap = new Map<String, String>();
        try {
            List<MVEX__WBC_Flows_JSON__mdt> FlowJSON = [SELECT Id, MVEX__Default_JSON__c, MVEX__Collect_purchase_interest_JSON__c, MVEX__Customer_support_JSON__c, MVEX__Get_feedback_JSON__c, MVEX__Send_a_survey_JSON__c FROM MVEX__WBC_Flows_JSON__mdt LIMIT 1];
            
            if(!FlowJSON.isEmpty()) {
                jsonDataMap.put('Default', FlowJSON[0].MVEX__Default_JSON__c);
                jsonDataMap.put('Collect purchase interest', FlowJSON[0].MVEX__Collect_purchase_interest_JSON__c);
                jsonDataMap.put('Get feedback', FlowJSON[0].MVEX__Get_feedback_JSON__c);
                jsonDataMap.put('Send a survey', FlowJSON[0].MVEX__Send_a_survey_JSON__c);
                jsonDataMap.put('Customer support', FlowJSON[0].MVEX__Customer_support_JSON__c);
            }
        } catch (Exception e) {
            System.debug('Error retrieving all JSON data: ' + e.getMessage());
            ErrorHandler.insertErrordata(e, 'WhatsAppFlowControllerV2', 'getAllJSONData', e.getMessage());
        }
        return jsonDataMap;
    }


    @AuraEnabled
    public static Map<String, List<FlowElementDescriptor>> getFlowElementTypes() {

        Map<String, List<FlowElementDescriptor>> result = new Map<String, List<FlowElementDescriptor>>();

        try{
            List<WB_Flow_Element__mdt> records = [SELECT Label, DeveloperName, Type__c, Options__c, Is_Active__c, Element_Icon__c,Type_Icon__c  FROM WB_Flow_Element__mdt WHERE Is_Active__c = true];            
            
            for (WB_Flow_Element__mdt rec : records) {
                if(!result.containsKey(rec.Type__c)) {
                    result.put(rec.Type__c, new List<FlowElementDescriptor>());
                }
                FlowElementDescriptor descriptor = new FlowElementDescriptor();
                descriptor.label = rec.Label;
                descriptor.developerName = rec.DeveloperName;
                descriptor.type = rec.Type__c;
                descriptor.elementIcon = rec.Element_Icon__c;
                descriptor.typeIcon = rec.Type_Icon__c;
                descriptor.options = rec.Options__c;
                result.get(rec.Type__c).add(descriptor);
            }

        }catch(Exception e){
            System.debug('Error retrieving flow element types: ' + e.getMessage());
            ErrorHandler.insertErrordata(e, 'WhatsAppFlowControllerV2', 'getFlowElementTypes', e.getMessage());
        }

        return result;
    }

    public class FlowElementDescriptor {
        @AuraEnabled public String label;
        @AuraEnabled public String developerName;
        @AuraEnabled public String type;
        @AuraEnabled public String options; 
        @AuraEnabled public String elementIcon;
        @AuraEnabled public String typeIcon;
    }

    /**
     * Wrapper class for Meta API flow operations
     */
    public class MetaFlowResult {
        public Boolean success;
        public String flowId;
        public String errorMessage;
        
        public MetaFlowResult(Boolean success, String flowId, String errorMessage) {
            this.success = success;
            this.flowId = flowId;
            this.errorMessage = errorMessage;
        }
    }

    /**
     * Method Name  : saveWhatsAppFlow
     * @description : Saves WhatsApp flow - creates in Meta first, then saves to Salesforce
     * @param       : flowName, categories, flowJson, templateType, flowRecordId, metaFlowId
     * @return      : String - JSON response with success status and IDs
     */
    @AuraEnabled
    public static String saveWhatsAppFlow( String flowName, List<String> categories, String flowJson, String templateType, String flowRecordId, String metaFlowId) {
        Map<String, Object> response = new Map<String, Object>();
        
        try {
            // Validate WB Config
            if (wbConfig == null || wbConfig.isEmpty()) {
                response.put('success', false);
                response.put('message', 'WhatsApp Business configuration not found');
                return JSON.serialize(response);
            }

            // Convert image URLs to base64 for Meta API (original flowJson keeps URLs for database)
            String flowJsonForApi = convertImageUrlsToBase64(flowJson);

            // If this is a new flow (no metaFlowId), create it in Meta first
            if (String.isBlank(metaFlowId)) {
                MetaFlowResult createResult = createFlowInMeta(flowName, categories, flowJsonForApi);
                if (!createResult.success) {
                    response.put('success', false);
                    response.put('message', createResult.errorMessage);
                    ErrorHandler.insertErrordata(null, 'WhatsAppFlowControllerV2', 'saveWhatsAppFlow', 'Failed to create flow in Meta: ' + createResult.errorMessage);
                    return JSON.serialize(response);
                }
                metaFlowId = createResult.flowId;
            } else {
                // Update existing flow in Meta
                Boolean updateSuccess = updateFlowInMeta(metaFlowId, flowJsonForApi);
                if (!updateSuccess) {
                    response.put('success', false);
                    response.put('message', 'Failed to update flow in Meta');
                    return JSON.serialize(response);
                }
            }
            
            // Prepare flow JSON without screens for storage
            Map<String, Object> flowData = (Map<String, Object>) JSON.deserializeUntyped(flowJson);
            List<Object> screens = (List<Object>) flowData.get('screens');
            
            // Extract screen data before removing from flow JSON
            List<String> screenIdList = new List<String>();
            Map<String, Object> screenMap = new Map<String, Object>();
            
            if (screens != null && !screens.isEmpty()) {
                for (Object screenObj : screens) {
                    Map<String, Object> screen = (Map<String, Object>) screenObj;
                    String screenId = (String) screen.get('id');
                    screenIdList.add(screenId);
                    screenMap.put(screenId, screen);
                }
                
                // Replace screens with screen IDs only in flow JSON
                flowData.remove('screens');
                flowData.put('screens', screenIdList);
            }
            
            String flowJsonForStorage = JSON.serialize(flowData);
            
            // Now save/update in Salesforce using upsert
            MVEX__Flow__c flowRecord = new MVEX__Flow__c();
            
            if (String.isNotBlank(flowRecordId)) {
                flowRecord.Id = flowRecordId;
            }
            
            flowRecord.Flow_Name__c = flowName;
            flowRecord.Flow_Id__c = metaFlowId;
            flowRecord.Category__c = String.join(categories, ';');
            flowRecord.Flow_JSON__c = flowJsonForStorage;
            flowRecord.Template_Type__c = templateType;
            flowRecord.Status__c = 'Draft';
            
            upsert flowRecord;
            flowRecordId = flowRecord.Id;
            
            // Save/update screens in separate object
            if (!screenIdList.isEmpty()) {
                String screenResult = updateWBConnectFlowScreen(screenMap, screenIdList, flowRecordId);
                if (screenResult != 'success') {
                    response.put('success', false);
                    response.put('message', 'Flow saved but failed to update screens');
                    return JSON.serialize(response);
                }
            }
            
            response.put('success', true);
            response.put('message', 'Flow saved successfully');
            response.put('flowRecordId', flowRecordId);
            response.put('metaFlowId', metaFlowId);
            
        } catch (Exception e) {
            System.debug('Error saving WhatsApp flow: ' + e.getMessage());
            ErrorHandler.insertErrordata(e, 'WhatsAppFlowControllerV2', 'saveWhatsAppFlow', e.getMessage());
            response.put('success', false);
            response.put('message', e.getMessage());
        }
        
        return JSON.serialize(response);
    }

    /**
     * Method Name  : convertImageUrlsToBase64
     * @description : Converts all image public URLs to base64 in flow JSON
     * @param       : flowJson - JSON string containing the flow structure
     * @return      : String - Modified JSON with base64 images
     */
    private static String convertImageUrlsToBase64(String flowJson) {
        try {
            System.debug('Starting image URL to base64 conversion...');
            Map<String, Object> flowData = (Map<String, Object>) JSON.deserializeUntyped(flowJson);
            List<Object> screens = (List<Object>) flowData.get('screens');
            
            if (screens == null || screens.isEmpty()) {
                System.debug('No screens found in flow JSON');
                return flowJson;
            }
            
            Integer imageCount = 0;
            // Process each screen
            for (Object screenObj : screens) {
                Map<String, Object> screen = (Map<String, Object>) screenObj;
                Object layoutObj = screen.get('layout');
                
                if (layoutObj == null) {
                    continue;
                }
                
                Map<String, Object> layout = (Map<String, Object>) layoutObj;
                List<Object> children = (List<Object>) layout.get('children');
                
                if (children == null) {
                    continue;
                }
                
                // Process each child element
                Integer screenImages = processChildrenForImages(children);
                imageCount += screenImages;
            }
            
            System.debug('Converted ' + imageCount + ' images to base64');
            return JSON.serialize(flowData);
        } catch (Exception e) {
            System.debug('Error converting image URLs to base64: ' + e.getMessage());
            ErrorHandler.insertErrordata(e, 'WhatsAppFlowControllerV2', 'convertImageUrlsToBase64', e.getMessage());
            // Return original JSON if conversion fails
            return flowJson;
        }
    }
    
    /**
     * Method Name  : processChildrenForImages
     * @description : Recursively processes layout children to find and convert image URLs
     * @param       : children - List of layout children elements
     * @return      : Integer - count of images converted
     */
    private static Integer processChildrenForImages(List<Object> children) {
        if (children == null) {
            return 0;
        }
        
        Integer imageCount = 0;
        
        for (Object childObj : children) {
            Map<String, Object> child = (Map<String, Object>) childObj;
            String elementType = (String) child.get('type');
            
            // Check if this is an Image element
            if (elementType == 'Image') {
                String imageUrl = (String) child.get('src');
                
                // Only convert if it's a URL (not already base64)
                if (String.isNotBlank(imageUrl) && imageUrl.startsWith('http')) {
                    System.debug('Converting image URL: ' + imageUrl);
                    String base64Image = downloadAndConvertToBase64(imageUrl);
                    if (String.isNotBlank(base64Image)) {
                        child.put('src', base64Image);
                        imageCount++;
                        System.debug('Successfully converted image to base64');
                    } else {
                        System.debug('Failed to convert image: ' + imageUrl);
                    }
                } else if (String.isNotBlank(imageUrl) && imageUrl.startsWith('data:')) {
                    System.debug('Image already in base64 format, skipping: ' + imageUrl.substring(0, Math.min(50, imageUrl.length())) + '...');
                }
            }
            
            // Recursively process nested children (for containers like Form, etc.)
            List<Object> nestedChildren = (List<Object>) child.get('children');
            if (nestedChildren != null) {
                imageCount += processChildrenForImages(nestedChildren);
            }
        }
        
        return imageCount;
    }
    
    /**
     * Method Name  : downloadAndConvertToBase64
     * @description : Downloads image from URL and converts to base64 data URI
     * @param       : imageUrl - Public URL of the image
     * @return      : String - Base64 data URI or null if failed
     */
    private static String downloadAndConvertToBase64(String imageUrl) {
        try {
            System.debug('Downloading image from: ' + imageUrl);
            
            // Make HTTP request to download image
            HttpRequest request = new HttpRequest();
            request.setEndpoint(imageUrl);
            request.setMethod('GET');
            request.setTimeout(60000); // 60 seconds timeout
            
            Http http = new Http();
            HttpResponse response = http.send(request);
            
            System.debug('HTTP Response Status: ' + response.getStatusCode());
            
            if (response.getStatusCode() == 200) {
                Blob imageBlob = response.getBodyAsBlob();
                String base64Data = EncodingUtil.base64Encode(imageBlob);
                
                // Return as base64 string
                return base64Data;
            } else {
                System.debug('Failed to download image: ' + imageUrl + ' - Status: ' + response.getStatusCode() + ' - Body: ' + response.getBody());
                return null;
            }
        } catch (Exception e) {
            System.debug('Error downloading image from URL: ' + imageUrl + ' - ' + e.getMessage());
            ErrorHandler.insertErrordata(e, 'WhatsAppFlowControllerV2', 'downloadAndConvertToBase64', 'Failed to download and convert image: ' + imageUrl + ' - ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * Method Name  : createFlowInMeta
     * @description : Creates a new flow in Meta using Graph API
     * @param       : flowName, categories, flowJson
     * @return      : MetaFlowResult - Result object with success status and flow ID or error message
     */
    private static MetaFlowResult createFlowInMeta(String flowName, List<String> categories, String flowJson) {
        try {
            String accessToken = wbConfig[0].Access_Token__c;
            String endpoint = 'https://graph.facebook.com/v21.0/' + wbConfig[0].Business_Account_Id__c + '/flows';
            
            HttpRequest request = new HttpRequest();
            request.setEndpoint(endpoint);
            request.setMethod('POST');
            request.setHeader('Authorization', 'Bearer ' + accessToken);
            request.setHeader('Content-Type', 'application/json');
            
            String payload = JSON.serialize(new Map<String, Object>{
                'categories' => categories,
                'name' => flowName,
                'flow_json' => flowJson
            });
            request.setBody(payload);
            
            Http http = new Http();
            HttpResponse response = http.send(request);
            
            if (response.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                String flowId = (String) responseMap.get('id');
                return new MetaFlowResult(true, flowId, null);
            } else {
                // Parse Meta API error response
                String errorMessage = response.getBody();
                try {
                    Map<String, Object> errorResponse = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                    if (errorResponse.containsKey('error')) {
                        Map<String, Object> error = (Map<String, Object>) errorResponse.get('error');
                        
                        // Try to get user-friendly message first
                        if (error.containsKey('error_user_msg')) {
                            errorMessage = (String) error.get('error_user_msg');
                        } else if (error.containsKey('message')) {
                            errorMessage = (String) error.get('message');
                        }
                    }
                } catch (Exception parseEx) {
                    // If parsing fails, use raw response body
                    System.debug('Failed to parse error response: ' + parseEx.getMessage());
                }
                
                ErrorHandler.insertErrordata(null, 'WhatsAppFlowControllerV2', 'createFlowInMeta', 'Failed to create flow in Meta: ' + errorMessage);
                System.debug('Meta API Error: ' + response.getBody());
                return new MetaFlowResult(false, null, errorMessage);
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WhatsAppFlowControllerV2', 'createFlowInMeta', 'Failed to create flow in Meta: ' + e.getMessage());
            return new MetaFlowResult(false, null, 'Failed to create flow in Meta: ' + e.getMessage());
        }
    }

    /**
     * Method Name  : updateFlowInMeta
     * @description : Updates an existing flow in Meta using Graph API
     * @param       : metaFlowId, flowJson
     * @return      : Boolean - success status
     */
    private static Boolean updateFlowInMeta(String metaFlowId, String flowJson) {
        try {
            String fileName = 'flow.json';
            String assetType = 'FLOW_JSON';
            String boundary = '----WebKitFormBoundary7MA4YWxkTrZu0gW';

            // Build multipart form-data
            String filePart = '--' + boundary + '\r\n' +
                            'Content-Disposition: form-data; name="file"; filename="' + fileName + '"\r\n' +
                            'Content-Type: application/json\r\n' +
                            '\r\n' +
                            flowJson + '\r\n';
            String namePart = '--' + boundary + '\r\n' +
                            'Content-Disposition: form-data; name="name"\r\n' +
                            '\r\n' +
                            fileName + '\r\n';
            String assetTypePart = '--' + boundary + '\r\n' +
                                'Content-Disposition: form-data; name="asset_type"\r\n' +
                                '\r\n' +
                                assetType + '\r\n';
            String footer = '--' + boundary + '--\r\n';

            String bodyString = filePart + namePart + assetTypePart + footer;
            Blob bodyBlob = Blob.valueOf(bodyString);
            
            String accessToken = wbConfig[0].Access_Token__c;
            String endpoint = 'https://graph.facebook.com/v21.0/' + metaFlowId + '/assets';
            
            HttpRequest request = new HttpRequest();
            request.setEndpoint(endpoint);
            request.setMethod('POST');
            request.setHeader('Authorization', 'Bearer ' + accessToken);
            request.setHeader('Content-Type', 'multipart/form-data; boundary=' + boundary);
            request.setBodyAsBlob(bodyBlob);
            
            Http http = new Http();
            HttpResponse response = http.send(request);
            
            return response.getStatusCode() == 200;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WhatsAppFlowControllerV2', 'updateFlowInMeta', 'Failed to update flow in Meta: ' + e.getMessage());
            return false;
        }
    }

    /**
     * Method Name  : updateWBConnectFlowScreen
     * @description : Synchronously updates Flow_Screen__c records for a single flow using the Helper class.
     * @param       : screenMap, screenIdList, flowId
     * @return      : String - 'success' or 'failed'
     */
    public static String updateWBConnectFlowScreen(Map<String, Object> screenMap, List<String> screenIdList, Id flowId) {
        try {
            if (screenIdList == null || screenMap == null || flowId == null) {
                return 'failed';
            }

            Map<String, MVEX__Flow_Screen__c> existingScreensMap = new Map<String, MVEX__Flow_Screen__c>();
            for (MVEX__Flow_Screen__c screen : [
                SELECT Id, MVEX__Screen_Id__c, MVEX__Screen_Flow_Json__c, MVEX__Screen_Sequence_No__c 
                FROM MVEX__Flow_Screen__c 
                WHERE MVEX__Flow__c = :flowId
            ]) {
                existingScreensMap.put(screen.MVEX__Screen_Id__c, screen);
            }

            List<MVEX__Flow_Screen__c> toInsert = new List<MVEX__Flow_Screen__c>();
            List<MVEX__Flow_Screen__c> toUpdate = new List<MVEX__Flow_Screen__c>();
            List<MVEX__Flow_Screen__c> toDelete = new List<MVEX__Flow_Screen__c>();

            if (screenIdList != null || screenMap != null || flowId != null) {
                for (Integer i = 0; i < screenIdList.size(); i++) {
                    String screenId = screenIdList[i];
                    Object screenData = screenMap.get(screenId);
                    if (screenData == null) continue;
    
                    String screenJson = JSON.serialize(screenData);
                    Integer seq = i + 1;
    
                    // Try to find match and remove from map so we know it's "accounted for"
                    MVEX__Flow_Screen__c existing = existingScreensMap.remove(screenId);
    
                    if (existing != null) {
                        existing.MVEX__Screen_Flow_Json__c = screenJson;
                        existing.MVEX__Screen_Sequence_No__c = seq;
                        toUpdate.add(existing);
                    } else {
                        toInsert.add(new MVEX__Flow_Screen__c(
                            MVEX__Screen_Id__c = screenId,
                            MVEX__Screen_Flow_Json__c = screenJson,
                            MVEX__Screen_Sequence_No__c = seq,
                            MVEX__Flow__c = flowId // Or MVEX__Flow__c depending on your env
                        ));
                    }
                }
    
                // Anything left in existingScreensMap was not in the incoming list -> Delete
                toDelete.addAll(existingScreensMap.values());
            }


            if (!toInsert.isEmpty()) insert toInsert;
            if (!toUpdate.isEmpty()) update toUpdate;
            if (!toDelete.isEmpty()) delete toDelete;

            return 'success';

        } catch (Exception e) {
            System.debug('Error updating flow screens: ' + e.getMessage());
            ErrorHandler.insertErrordata(e, 'WhatsAppFlowControllerV2', 'updateWBConnectFlowScreen', 'Error in sync: ' + e.getMessage());
            return 'failed';
        }
    }

    /**
     * Method Name  : getFlowByIdWithScreens
     * @description : Retrieves flow data by ID including screens from Flow_Screen__c
     * @param       : flowId - The Salesforce record ID of the flow
     * @return      : String - JSON response with flow data including screens
     */
    @AuraEnabled
    public static String getFlowByIdWithScreens(String flowId) {
        Map<String, Object> response = new Map<String, Object>();
        
        try {
            // Query the flow record
            List<MVEX__Flow__c> flows = [
                SELECT Id, Flow_Name__c, Flow_Id__c, Category__c, Flow_JSON__c, 
                       Template_Type__c, Status__c, Parent_Flow__c
                FROM MVEX__Flow__c 
                WHERE Id = :flowId 
                LIMIT 1
            ];
            
            if (flows.isEmpty()) {
                response.put('success', false);
                response.put('message', 'Flow not found');
                return JSON.serialize(response);
            }
            
            MVEX__Flow__c flow = flows[0];
            
            // Check if this flow is a parent to any other flows
            Integer childFlowCount = [
                SELECT COUNT() 
                FROM MVEX__Flow__c 
                WHERE Parent_Flow__c = :flowId 
                LIMIT 1
            ];
            Boolean isParentFlow = childFlowCount > 0;
            
            // Parse the flow JSON to get screen IDs
            Map<String, Object> flowData = (Map<String, Object>) JSON.deserializeUntyped(flow.Flow_JSON__c);
            List<Object> screenIds = (List<Object>) flowData.get('screens');
            
            if (screenIds != null && !screenIds.isEmpty()) {
                // Query screen data
                List<Flow_Screen__c> screenRecords = [
                    SELECT Screen_Id__c, Screen_Flow_Json__c 
                    FROM Flow_Screen__c 
                    WHERE MVEX__Flow__c = :flowId
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
                flow.Flow_JSON__c = JSON.serialize(flowData);
            }
            
            response.put('success', true);
            response.put('data', flow);
            response.put('isParentFlow', isParentFlow);
            
        } catch (Exception e) {
            System.debug('Error retrieving flow by ID: ' + e.getMessage());
            ErrorHandler.insertErrordata(e, 'WhatsAppFlowControllerV2', 'getFlowByIdWithScreens', 'Could not retrieve flow by ID!');
            response.put('success', false);
            response.put('message', e.getMessage());
        }
        
        return JSON.serialize(response);
    }

    /**
     * Method Name  : publishWhatsAppFlow
     * @description : Publishes WhatsApp flow to Meta
     * @param       : metaFlowId, flowRecordId
     * @return      : String - JSON response with success status
     */
    @AuraEnabled
    public static String publishWhatsAppFlow(String metaFlowId, String flowRecordId) {
        Map<String, Object> response = new Map<String, Object>();
        
        try {
            // Validate WB Config
            if (wbConfig == null || wbConfig.isEmpty()) {
                response.put('success', false);
                response.put('message', 'WhatsApp Business configuration not found');
                return JSON.serialize(response);
            }

            // Publish flow in Meta
            String accessToken = wbConfig[0].Access_Token__c;
            String endpoint = 'https://graph.facebook.com/v21.0/' + metaFlowId + '/publish';
            
            HttpRequest request = new HttpRequest();
            request.setEndpoint(endpoint);
            request.setMethod('POST');
            request.setHeader('Authorization', 'Bearer ' + accessToken);
            
            Http http = new Http();
            HttpResponse httpResponse = http.send(request);
            
            if (httpResponse.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(httpResponse.getBody());
                Boolean successVal = (Boolean) responseMap.get('success');
                
                if (successVal == true) {
                    // Update flow record status
                    if (String.isNotBlank(flowRecordId)) {
                        MVEX__Flow__c flowRecord = new MVEX__Flow__c(
                            Id = flowRecordId,
                            Status__c = 'Published'
                        );
                        update flowRecord;
                    }
                    
                    response.put('success', true);
                    response.put('message', 'Flow published successfully');
                } else {
                    response.put('success', false);
                    response.put('message', 'Failed to publish flow');
                }
            } else {
                response.put('success', false);
                response.put('message', 'Failed to publish flow: ' + httpResponse.getBody());
            }
            
        } catch (Exception e) {
            System.debug('Error publishing WhatsApp flow: ' + e.getMessage());
            ErrorHandler.insertErrordata(e, 'WhatsAppFlowControllerV2', 'publishWhatsAppFlow', 'Failed to publish WhatsApp flow: ' + e.getMessage());
            response.put('success', false);
            response.put('message', e.getMessage());
        }
        
        return JSON.serialize(response);
    }


    @AuraEnabled
    public static String cloneWhatsAppFlow(String flowId, String newFlowName){

        List<MVEX__Flow__c> flowList = [SELECT Id, Flow_Name__c, Flow_Id__c, Category__c, Flow_JSON__c, Template_Type__c, Status__c FROM MVEX__Flow__c WHERE Id = :flowId LIMIT 1];

        if(flowList.isEmpty()){
            return JSON.serialize(new Map<String, Object>{'success' => false, 'message' => 'Flow not found'});
        }

        MVEX__Flow__c originalFlow = flowList[0];

        Http http = new Http();
        HttpRequest request = new HttpRequest();
        String accessToken = wbConfig[0].Access_Token__c;
        String endpoint = 'https://graph.facebook.com/v21.0/' + wbConfig[0].Business_Account_Id__c + '/flows';

        request.setEndpoint(endpoint);
        request.setMethod('POST');
        request.setHeader('Authorization', 'Bearer ' + accessToken);
        request.setHeader('Content-Type', 'application/json');

        String payload = JSON.serialize(new Map<String, Object>{
            'categories' => originalFlow.Category__c != null ? originalFlow.Category__c.split(';') : new List<String>(),
            'name' => newFlowName,
            'clone_flow_id' => originalFlow.Flow_Id__c
        });

        request.setBody(payload);
        HttpResponse response = http.send(request);
        if (response.getStatusCode() == 200) {
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            String newMetaFlowId = (String) responseMap.get('id');
            MVEX__Flow__c newFlow = new MVEX__Flow__c();
            newFlow.Flow_Name__c = newFlowName;
            newFlow.Flow_Id__c = newMetaFlowId;
            newFlow.Category__c = originalFlow.Category__c;
            newFlow.Flow_JSON__c = originalFlow.Flow_JSON__c;
            newFlow.Template_Type__c = originalFlow.Template_Type__c;
            newFlow.Status__c = 'Draft';
            newFlow.Parent_Flow__c = originalFlow.Id;
            insert newFlow;

            // Clone associated flow screens
            List<Flow_Screen__c> originalScreens = [
                SELECT Screen_Id__c, Screen_Flow_Json__c, Screen_Sequence_No__c
                FROM Flow_Screen__c
                WHERE MVEX__Flow__c = :flowId
                ORDER BY Screen_Sequence_No__c
            ];

            if (!originalScreens.isEmpty()) {
                List<Flow_Screen__c> newScreens = new List<Flow_Screen__c>();
                for (Flow_Screen__c originalScreen : originalScreens) {
                    Flow_Screen__c newScreen = new Flow_Screen__c();
                    newScreen.MVEX__Flow__c = newFlow.Id;
                    newScreen.Screen_Id__c = originalScreen.Screen_Id__c;
                    newScreen.Screen_Flow_Json__c = originalScreen.Screen_Flow_Json__c;
                    newScreen.Screen_Sequence_No__c = originalScreen.Screen_Sequence_No__c;
                    newScreens.add(newScreen);
                }
                insert newScreens;
            }

            return JSON.serialize(new Map<String, Object>{'success' => true, 'message' => 'Flow cloned successfully', 'flowRecordId' => newFlow.Id, 'metaFlowId' => newMetaFlowId});
        } else {
            return JSON.serialize(new Map<String, Object>{'success' => false, 'message' => 'Failed to clone flow: ' + response.getBody()});
        }
    }

}