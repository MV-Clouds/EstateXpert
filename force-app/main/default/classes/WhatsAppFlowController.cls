/**
 * Class Name    : WhatsAppFlowController
 * Test Class    : WhatsAppFlowController
 * @description  : Handles WhatsApp Flow operations like create, update, publish, delete, deprecate and fetch preview URL.
 * Created By    : Harsh Gandhi
 *
 * MODIFICATION LOG*
 * Last Update Date : 20/07/2026
 * Updated By : Harsh Gandhi
 * Change Description : Code refactor
 */
public with sharing class WhatsAppFlowController {
    
    public static MVEX__WhatsAppConfig__c wbConfig = MVEX__WhatsAppConfig__c.getOrgDefaults();     
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

            if (wbConfig==null) {
                return 'Failed to publish flow: Cannot publish the flow because the WhatsApp Business configuration is not found. You need to add a WhatsApp Business configuration before publishing the flow.';
            }
            String accessToken = (wbConfig.MVEX__Access_Token_1__c != null ? wbConfig.MVEX__Access_Token_1__c : '') + (wbConfig.MVEX__Access_Token_2__c != null ? wbConfig.MVEX__Access_Token_2__c : '');
            String endpoint = wbConfig.MVEX__whatsapp_endpoint__c + '/' + wbConfig.MVEX__APIVersion__c + '/' + flowId + '/publish';
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

            if (wbConfig==null) {
                return 'failed';
            }
            String accessToken = (wbConfig.MVEX__Access_Token_1__c != null ? wbConfig.MVEX__Access_Token_1__c : '') + (wbConfig.MVEX__Access_Token_2__c != null ? wbConfig.MVEX__Access_Token_2__c : '');
            String endpoint = wbConfig.MVEX__whatsapp_endpoint__c + '/' + wbConfig.MVEX__APIVersion__c + '/' + flowId;
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

            if (wbConfig==null) {
                return 'failed';
            }
            String accessToken = (wbConfig.MVEX__Access_Token_1__c != null ? wbConfig.MVEX__Access_Token_1__c : '') + (wbConfig.MVEX__Access_Token_2__c != null ? wbConfig.MVEX__Access_Token_2__c : '');
            String endpoint = wbConfig.MVEX__whatsapp_endpoint__c + '/' + wbConfig.MVEX__APIVersion__c + '/' + flowId + '/deprecate';
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
            if (wbConfig==null) {
                return new Map<String,String>{'status' => 'failed', 'error' => 'failed'};
            }
            String accessToken = (wbConfig.MVEX__Access_Token_1__c != null ? wbConfig.MVEX__Access_Token_1__c : '') + (wbConfig.MVEX__Access_Token_2__c != null ? wbConfig.MVEX__Access_Token_2__c : '');
            String endpoint = wbConfig.MVEX__whatsapp_endpoint__c + '/' + wbConfig.MVEX__APIVersion__c + '/' + flowId + '?fields=preview.invalidate(false)';
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

    /**
     ***********************************************************************************************************************************
     * Method Name     : publishAndDeprecateWhatsAppFlow
     * @description    : For a 'Published Draft' flow — publishes the latest edits to Meta first,
     *                   then immediately deprecates the flow. This is the required two-step process
     *                   because Meta does not allow direct deletion/deprecation of a published flow
     *                   that has pending draft edits.
     * @param flowId   : The Meta Flow ID (Flow_Id__c) of the flow to publish and then deprecate.
     * @return         : JSON string with success status and message.
     ***********************************************************************************************************************************
     */
    @AuraEnabled
    public static String publishAndDeprecateWhatsAppFlow(String flowId) {
        Map<String, Object> response = new Map<String, Object>();
        try {
            if (wbConfig == null) {
                response.put('success', false);
                response.put('message', 'WhatsApp Business configuration not found.');
                return JSON.serialize(response);
            }

            String accessToken = (wbConfig.MVEX__Access_Token_1__c != null ? wbConfig.MVEX__Access_Token_1__c : '')
                               + (wbConfig.MVEX__Access_Token_2__c != null ? wbConfig.MVEX__Access_Token_2__c : '');

            // ── Step 1: Publish the flow ──────────────────────────────────────────────
            String publishEndpoint = wbConfig.MVEX__whatsapp_endpoint__c + '/' + wbConfig.MVEX__APIVersion__c + '/' + flowId + '/publish';
            HttpRequest publishReq = new HttpRequest();
            publishReq.setEndpoint(publishEndpoint);
            publishReq.setMethod('POST');
            publishReq.setHeader('Authorization', 'Bearer ' + accessToken);

            Http http = new Http();
            HttpResponse publishRes = http.send(publishReq);

            if (publishRes.getStatusCode() != 200) {
                response.put('success', false);
                response.put('message', 'Failed to publish flow before deprecating: ' + publishRes.getBody());
                ErrorHandler.insertErrordata(null, 'WhatsAppFlowController', 'publishAndDeprecateWhatsAppFlow', 'Publish step failed: ' + publishRes.getBody());
                return JSON.serialize(response);
            }

            Map<String, Object> publishMap = (Map<String, Object>) JSON.deserializeUntyped(publishRes.getBody());
            Boolean publishSuccess = (Boolean) publishMap.get('success');
            if (publishSuccess != true) {
                response.put('success', false);
                response.put('message', 'Meta did not confirm flow publish. Deprecation aborted.');
                return JSON.serialize(response);
            }

            // ── Step 2: Deprecate the (now-published) flow ───────────────────────────
            String deprecateEndpoint = wbConfig.MVEX__whatsapp_endpoint__c + '/' + wbConfig.MVEX__APIVersion__c + '/' + flowId + '/deprecate';
            HttpRequest deprecateReq = new HttpRequest();
            deprecateReq.setEndpoint(deprecateEndpoint);
            deprecateReq.setMethod('POST');
            deprecateReq.setHeader('Authorization', 'Bearer ' + accessToken);

            HttpResponse deprecateRes = http.send(deprecateReq);

            if (deprecateRes.getStatusCode() != 200) {
                // Publish succeeded but deprecate failed — at least update Salesforce to Published
                List<Flow__c> flowRecs = [SELECT Id, Status__c FROM Flow__c WHERE Flow_Id__c = :flowId LIMIT 1];
                if (!flowRecs.isEmpty()) {
                    flowRecs[0].Status__c = 'Published';
                    update as user flowRecs[0];
                }
                response.put('success', false);
                response.put('message', 'Flow was published successfully but deprecation failed: ' + deprecateRes.getBody());
                ErrorHandler.insertErrordata(null, 'WhatsAppFlowController', 'publishAndDeprecateWhatsAppFlow', 'Deprecate step failed: ' + deprecateRes.getBody());
                return JSON.serialize(response);
            }

            // ── Step 3: Update Salesforce record to Deprecated ───────────────────────
            List<Flow__c> flowRecs = [SELECT Id, Status__c FROM Flow__c WHERE Flow_Id__c = :flowId LIMIT 1];
            if (!flowRecs.isEmpty()) {
                flowRecs[0].Status__c = 'Deprecated';
                update as user flowRecs[0];
            }

            response.put('success', true);
            response.put('message', 'Flow published and deprecated successfully.');
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WhatsAppFlowController', 'publishAndDeprecateWhatsAppFlow', e.getMessage());
            response.put('success', false);
            response.put('message', e.getMessage());
        }
        return JSON.serialize(response);
    }
}