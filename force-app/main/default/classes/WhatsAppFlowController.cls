/**WBConnect_
 * Class Name    : WhatsAppFlowController
 * Test Class    : WhatsAppFlowController
 * @description  : Handles WhatsApp Flow operations like create, update, publish, delete, deprecate and fetch preview URL.
 * Created Date  : 
 * Created By    : Kavya Trivedi
 *--------------------------------------------------------------------------------
 * Modification History :
 * Date Modified : 01/09/2025 - Kavya Trivedi - Code refactor
 */
public with sharing class WhatsAppFlowController {
    
    public static List<MVEX__WBConnect_Configuration__mdt> wbConfig = MVEX__WBConnect_Configuration__mdt.getAll().values();     
    /**
     ******************************************************************************
     * Method Name  : getWhatsAppFlows
     * @description : Fetches all WhatsApp flows associated with the user's account.
     * @return      : List of Flow__c records
     ******************************************************************************
     */
    @AuraEnabled
    public static List<sObject> getWhatsAppFlows() {
        List<Flow__c> flowRecs = [SELECT Id, Flow_Name__c, Status__c, Flow_Id__c, Category__c, Template_Type__c, LastModifiedDate, CreatedDate FROM Flow__c ORDER BY LastModifiedDate DESC];
        return flowRecs;
    }

    /**
     *************************************************************************************
     * Method Name   : getWhatsAppFlowById
     * @description  : Fetches a specific WhatsApp flow by its Flow_Id__c.
     * @param flowId : The Flow_Id__c of the WhatsApp flow to be fetched.
     * @return       : List of Flow__c records matching the provided Flow_Id__c
     *************************************************************************************
     */
    @AuraEnabled
    public static List<Flow__c> getWhatsAppFlowById(String flowId) {
        try {
            // Query parent flow and child screens
            List<Flow__c> flowRecs = [
                SELECT Id,
                    Flow_Name__c,
                    Status__c,
                    Category__c,
                    Template_Type__c,
                    Flow_JSON__c,
                    LastModifiedDate,
                    (SELECT Id,
                            Screen_Id__c,
                            Screen_Flow_Json__c,
                            Screen_Sequence_No__c
                        FROM Flow_Screens__r
                        ORDER BY Screen_Sequence_No__c ASC)
                FROM Flow__c
                WHERE Flow_Id__c = :flowId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];

            if (flowRecs.isEmpty()) {
                return new List<Flow__c>();
            }

            Flow__c flow = flowRecs[0];
            List<Flow_Screen__c> screens = flow.Flow_Screens__r;

            // Rebuild the flow JSON from screen records
            if (screens != null && !screens.isEmpty()) {
                List<Object> screenJsonList = new List<Object>();

                for (Flow_Screen__c screenRec : screens) {
                    if (!String.isBlank(screenRec.Screen_Flow_Json__c)) {
                        Map<String, Object> screenMap = 
                            (Map<String, Object>) JSON.deserializeUntyped(screenRec.Screen_Flow_Json__c);
                        screenJsonList.add(screenMap);
                    }
                }

                // Merge back into Flow_JSON__c
                if (!String.isBlank(flow.Flow_JSON__c)) {
                    Map<String, Object> flowData = 
                        (Map<String, Object>) JSON.deserializeUntyped(flow.Flow_JSON__c);
                    flowData.put('screens', screenJsonList);
                    flow.Flow_JSON__c = JSON.serialize(flowData);
                }
            }

            return flowRecs;

        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WhatsAppFlowController', 'getWhatsAppFlowById', e.getMessage());
            return new List<Flow__c>();
        }
    }


    @AuraEnabled
    public static List<Flow_Submission__c> getFlowSubmissionByFlowId(Id flowId) {
        List<Flow_Submission__c> flowRecs = [SELECT Id, Submitter_Name__c, Submitter_Phone__c, Flow_Response_Mapping__c, CreatedDate FROM Flow_Submission__c WHERE WB_Flow__c = :flowId];
        return flowRecs.size() > 0 ? flowRecs : new List<Flow_Submission__c>();
    }

    @AuraEnabled
    public static List<Flow_Submission__c> getFlowSubmissionById(Id submissionId) {
        List<Flow_Submission__c> flowRecs = [SELECT Submitter_Name__c, Submitter_Phone__c, Flow_Response_Mapping__c, CreatedDate FROM Flow_Submission__c WHERE Id = :submissionId];
        return flowRecs.size() > 0 ? flowRecs : new List<Flow_Submission__c>();
    }

    /**
     *********************************************************************************************
     * Method Name  : getJSONData
     * @description : Retrieves JSON data for different WhatsApp flow types from custom metadata.
     * @param type  : The type of WhatsApp flow
     * @return      : JSON string corresponding to the specified flow type
     *********************************************************************************************
     */
    @AuraEnabled
    public static String getJSONData(String type) {
        String jsonString = '';
        try {
            List<MVEX__WBC_Flows_JSON__mdt> FlowJSON = [SELECT Id, MVEX__Default_JSON__c, MVEX__Collect_purchase_interest_JSON__c, MVEX__Customer_support_JSON__c, MVEX__Get_feedback_JSON__c, MVEX__Send_a_survey_JSON__c FROM MVEX__WBC_Flows_JSON__mdt WITH SECURITY_ENFORCED LIMIT 1];
            
            if(type == 'Default') {
                jsonString = FlowJSON[0].MVEX__Default_JSON__c;
            } else if(type == 'Collect purchase interest') {
                jsonString = FlowJSON[0].MVEX__Collect_purchase_interest_JSON__c;
            } else if(type == 'Get feedback') {
                jsonString = FlowJSON[0].MVEX__Get_feedback_JSON__c;
            } else if(type == 'Send a survey') {
                jsonString = FlowJSON[0].MVEX__Send_a_survey_JSON__c;
            } else if(type == 'Customer support') {
                jsonString = FlowJSON[0].MVEX__Customer_support_JSON__c;
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WhatsAppEmailServiceClass', 'getJSONData', e.getMessage());
        }
        return jsonString;
    }

    /**
     ********************************************************************************************************************************
     * Method Name         : createWhatsAppFlow
     * @description        : Creates a new WhatsApp flow using the Meta Graph API and optionally creates a corresponding record in Salesforce.
     * @param flowName     : The name of the WhatsApp flow to be created.
     * @param categories   : List of categories associated with the flow.
     * @param flowJson     : The JSON representation of the flow.
     * @param templateType : The type of template used for the flow.
     * @param createRecord : Boolean flag indicating whether to create a corresponding Salesforce record.
     * @return             : The ID of the created flow or an error message if creation fails.
     **********************************************************************************************************************************
     */
    @AuraEnabled
    public static String createWhatsAppFlow(String flowName, List<String> categories, String flowJson, String templateType, Boolean createRecord) {
        try {

            if (wbConfig==null || wbConfig.isEmpty()) {
                return 'Failed to create flow: Cannot create the flow because the WhatsApp Business configuration is not found. You need to add a WhatsApp Business configuration before creating the flow.';
            }
            String accessToken = wbConfig[0].MVEX__Access_Token__c;
            String endpoint = wbConfig[0].MVEX__APIEndpoint__c + '/' + wbConfig[0].MVEX__APIVersion__c + '/' + wbConfig[0].MVEX__Business_Account_Id__c + '/flows';
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

            System.debug('Response body = ' + response.getBody());
            
            if (response.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                String flowId = (String) responseMap.get('id');

                //Genrating screenIdList and screenMap for storing Flow_Screen__c records
                Map<String, Object> flowData = (Map<String, Object>) JSON.deserializeUntyped(flowJson);
                if(flowData == null || !flowData.containsKey('screens')){
                    return 'Failed to create flow : Screens data not found in response.';
                }
                List<Object> screens = (List<Object>) flowData.get('screens');
                List<String> screenIdList = new List<String>();
                Map<String, Object> screenMap = new Map<String, Object>();
                for(Object screenObj : screens){
                    Map<String, Object> screen = (Map<String, Object>) screenObj;
                    String screenId = (String) screen.get('id');
                    screenIdList.add(screenId);
                    screenMap.put(screenId, screen);
                }

                if(screenIdList.size() > 0){
                    flowData.remove('screens');
                    flowData.put('screens', screenIdList);
                    flowJson = JSON.serialize(flowData);
                }

                if (createRecord) {
                    
                    // Create a new Flow record
                    Flow__c flow = new Flow__c();
                    flow.Flow_Name__c = flowName;
                    flow.Status__c = 'Draft';
                    flow.Flow_Id__c = flowId;
                    flow.Flow_JSON__c = flowJson;
                    flow.Category__c = String.join(categories, ';');
                    flow.Template_Type__c = templateType;
    
                    insert flow;

                    // Storing Flow_Screen__c records
                    String screenStoreStatus = WhatsAppFlowControllerV2.updateWBConnectFlowScreen(screenMap, screenIdList, flow.Id);
                    if(screenStoreStatus == 'failed'){
                        return 'Failed to create flow : Could not store flow screens.';
                    }
                
                }
                return flowId;
            } else {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                Map<String, Object> errorMap = (Map<String, Object>) responseMap.get('error');
                String errorMessage = (String) errorMap.get('error_user_msg');
                return 'Failed to create flow : ' + errorMessage;
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WhatsAppEmailServiceClass', 'createWhatsAppFlow', e.getMessage());
            return 'Failed to create flow : ' + e.getMessage();
        }
    }

    /**
     ***********************************************************************************************************************************
     * Method Name     : updateWhatsAppFlow
     * @description    : Updates an existing WhatsApp flow using the Meta Graph API and updates the corresponding record in Salesforce.
     * @param flowId   : The ID of the WhatsApp flow to be updated.
     * @param flowJson : The updated JSON representation of the flow.
     * @return         : 'success' if the update is successful, otherwise 'failed'.
     ***********************************************************************************************************************************
     */
    @AuraEnabled
    public static String updateWhatsAppFlow(String flowId, String flowJson) {
        try {
            
            if (wbConfig==null || wbConfig.isEmpty()) {
                return 'failed';
            }

            String fileName = 'flow.json';
            String assetType = 'FLOW_JSON';
            // Create the multipart form-data boundary
            String boundary = '----WebKitFormBoundary7MA4YWxkTrZu0gW';

            // Build each form part with explicit line breaks
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

            // Combine the body as a single string
            String bodyString = filePart + namePart + assetTypePart + footer;

            // Convert the body to a Blob
            Blob bodyBlob = Blob.valueOf(bodyString);
          
            String accessToken = wbConfig[0].MVEX__Access_Token__c;
            String endpoint = wbConfig[0].MVEX__APIEndpoint__c + '/' + wbConfig[0].MVEX__APIVersion__c + '/' + flowId + '/assets';
            HttpRequest request = new HttpRequest();
            request.setEndpoint(endpoint);
            request.setMethod('POST');
            request.setHeader('Authorization', 'Bearer ' + accessToken);
            request.setHeader('Content-Type', 'multipart/form-data; boundary=' + boundary);
            request.setBodyAsBlob(bodyBlob);
            
            Http http = new Http();
            HttpResponse response = http.send(request);
            
            if (response.getStatusCode() == 200) {
                System.debug('Status Code: ' + response.getStatusCode());
                System.debug('Response Body: ' + response.getBody());

                List<Flow__c> flowRecs = [SELECT Id, Flow_JSON__c, Status__c, Flow_Id__c FROM Flow__c WHERE Flow_Id__c = :flowId WITH SECURITY_ENFORCED LIMIT 1];

                // Step 1 — Deserialize and prepare flow data
                Map<String, Object> flowData = (Map<String, Object>) JSON.deserializeUntyped(flowJson);
                if (flowData == null || !flowData.containsKey('screens')) {
                    return 'Failed: Screens data missing in flow JSON.';
                }

                List<Object> screens = (List<Object>) flowData.get('screens');
                List<String> screenIdList = new List<String>();
                Map<String, Object> screenMap = new Map<String, Object>();

                for (Object screenObj : screens) {
                    Map<String, Object> screen = (Map<String, Object>) screenObj;
                    String screenId = (String) screen.get('id');
                    screenIdList.add(screenId);
                    screenMap.put(screenId, screenObj);
                }

                // Replace screen objects with screen ID list before sending to Meta
                if (!screenIdList.isEmpty()) {
                    flowData.remove('screens');
                    flowData.put('screens', screenIdList);
                    flowJson = JSON.serialize(flowData);
                }
                
                if(flowRecs.size() > 0){
                    flowRecs[0].Flow_JSON__c = flowJson;
                    flowRecs[0].Status__c = 'Draft';
                    update as user flowRecs;

                    String screenUpdateStatus = WhatsAppFlowControllerV2.updateWBConnectFlowScreen(screenMap, screenIdList, flowRecs[0].Id);
                    if (screenUpdateStatus == 'failed') {
                        return 'Failed: Could not update flow screens.';
                    }
                }
                
                return 'sucess';
            } else {
                System.debug('Status Code: ' + response.getStatusCode());
                System.debug('Response Body: ' + response.getBody());
                return 'failed';
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WhatsAppEmailServiceClass', 'updateWhatsAppFlow', e.getMessage());
            return 'failed';
        }
    }

    /**
     **********************************************************************************************************************************
     * Method Name   : publishWhatsAppFlow
     * @description  : Publishes a WhatsApp flow using the Meta Graph API and updates the corresponding record in Salesforce.
     * @param flowId : The ID of the WhatsApp flow to be published.
     * @return       : 'success' if the publish is successful, otherwise an error message.
     **********************************************************************************************************************************
     */
    @AuraEnabled
    public static String publishWhatsAppFlow(String flowId) {
        try {

            if (wbConfig==null || wbConfig.isEmpty()) {
                return 'Failed to publish flow: Cannot publish the flow because the WhatsApp Business configuration is not found. You need to add a WhatsApp Business configuration before publishing the flow.';
            }
            String accessToken = wbConfig[0].Access_Token__c;
            String endpoint = wbConfig[0].APIEndpoint__c + '/' + wbConfig[0].APIVersion__c + '/' + flowId + '/publish';
            HttpRequest request = new HttpRequest();
            request.setEndpoint(endpoint);
            request.setMethod('POST');
            request.setHeader('Authorization', 'Bearer ' + accessToken);
            Http http = new Http();
            HttpResponse response = http.send(request);
            
            if (response.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                Boolean successVal = (Boolean) responseMap.get('success');
                if(successVal == true) {
                    List<Flow__c> flowRecs = [SELECT Id, Status__c, Flow_Id__c FROM Flow__c WHERE Flow_Id__c = :flowId WITH USER_MODE LIMIT 1];
                    if(flowRecs.size() > 0){
                        flowRecs[0].Status__c = 'Published';
                        update as user flowRecs;
                    }
                    return 'success';
                } else {
                    return 'Failed to publish flow';
                }
            } else {
                return 'Failed to publish flow : ' + response.getBody();
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WhatsAppEmailServiceClass', 'publishWhatsAppFlow', e.getMessage());
            return 'Failed to publish flow : ' + e.getMessage();
        }
    }

    /**
     ***********************************************************************************************************************************
     * Method Name     : deleteWhatsAppFlow
     * @description    : Deletes a WhatsApp flow using the Meta Graph API and removes the corresponding record from Salesforce.
     * @param flowId   : The ID of the WhatsApp flow to be deleted.
     * @return         : 'success' if the deletion is successful, otherwise 'failed'.
     ***********************************************************************************************************************************
     */
    @AuraEnabled
    public static String deleteWhatsAppFlow(String flowId) {
        try {

            if (wbConfig==null || wbConfig.isEmpty()) {
                return 'failed';
            }
            String accessToken = wbConfig[0].Access_Token__c;
            String endpoint = wbConfig[0].APIEndpoint__c + '/' + wbConfig[0].APIVersion__c + '/' + flowId;
            HttpRequest request = new HttpRequest();
            request.setEndpoint(endpoint);
            request.setMethod('DELETE');
            request.setHeader('Authorization', 'Bearer ' + accessToken);
            Http http = new Http();
            HttpResponse response = http.send(request);
            System.debug('response body = ' + response.getBody());
            if (response.getStatusCode() == 200) {
                List<Flow__c> flowRecs = [SELECT Id, Status__c, Flow_Id__c FROM Flow__c WHERE Flow_Id__c = :flowId WITH USER_MODE LIMIT 1];
                if(flowRecs.size() > 0){
                    delete as user flowRecs[0];
                }
                return 'sucess';
            } else {
                return 'failed';
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WhatsAppEmailServiceClass', 'deleteWhatsAppFlow', e.getMessage());
            return 'failed';
        }
    }

    /**
     ***********************************************************************************************************************************
     * Method Name     : deprecateWhatsAppFlow
     * @description    : Deprecates a WhatsApp flow using the Meta Graph API and updates the corresponding record in Salesforce.
     * @param flowId   : The ID of the WhatsApp flow to be deprecated.
     * @return         : 'success' if the deprecation is successful, otherwise 'failed'.
     ***********************************************************************************************************************************
     */
    @AuraEnabled
    public static String deprecateWhatsAppFlow(String flowId) {
        try {

            if (wbConfig==null || wbConfig.isEmpty()) {
                return 'failed';
            }
            String accessToken = wbConfig[0].Access_Token__c;
            String endpoint = wbConfig[0].APIEndpoint__c + '/' + wbConfig[0].APIVersion__c + '/' + flowId + '/deprecate';
            HttpRequest request = new HttpRequest();
            request.setEndpoint(endpoint);
            request.setMethod('POST');
            request.setHeader('Authorization', 'Bearer ' + accessToken);
            Http http = new Http();
            HttpResponse response = http.send(request);
            
            if (response.getStatusCode() == 200) {
                List<Flow__c> flowRecs = [SELECT Id, Status__c, Flow_Id__c FROM Flow__c WHERE Flow_Id__c = :flowId LIMIT 1];
                if(flowRecs.size() > 0){
                    flowRecs[0].Status__c = 'Deprecated';
                    update as user flowRecs[0];
                }
                return 'sucess';
            } else {
                return 'failed';
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WhatsAppEmailServiceClass', 'deprecateWhatsAppFlow', e.getMessage());
            return 'failed';
        }
    }

    /**
     ***********************************************************************************************************************************
     * Method Name   : getPreviewURLofWhatsAppFlow
     * @description  : Retrieves the preview URL of a WhatsApp flow using the Meta Graph API.
     * @param flowId : The ID of the WhatsApp flow.
     * @return       : The preview URL if successful, otherwise 'failed'.
     ***********************************************************************************************************************************
     */
    @AuraEnabled
    public static Map<String,String> getPreviewURLofWhatsAppFlow(String flowId) {
        try {
            if (wbConfig==null || wbConfig.isEmpty()) {
                return new Map<String,String>{'status' => 'failed', 'error' => 'failed'};
            }
            String accessToken = wbConfig[0].Access_Token__c;
            String endpoint = wbConfig[0].APIEndpoint__c + '/' + wbConfig[0].APIVersion__c + '/' + flowId + '?fields=preview.invalidate(false)';
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
                return new Map<String,String>{'status' => '200', 'previewUrl' => previewUrl};
            } else {
                return new Map<String,String>{'status' => 'failed', 'error' => 'failed'};
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WhatsAppEmailServiceClass', 'getPreviewURLofWhatsAppFlow', e.getMessage());
            return new Map<String,String>{'status' => 'failed', 'error' => 'failed'};
        }
    }
}