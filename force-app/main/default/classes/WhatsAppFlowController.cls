public with sharing class WhatsAppFlowController {

    public static List<WBConnect_Configuration__mdt> wbConfig = WBConnect_Configuration__mdt.getAll().values(); 
    
    @AuraEnabled
    public static List<sObject> getWhatsAppFlows() {
        List<Flow__c> flowRecs = [SELECT Id, Flow_Name__c, Status__c, Flow_Id__c, Category__c, Template_Type__c, LastModifiedDate, CreatedDate FROM Flow__c WITH USER_MODE ORDER BY LastModifiedDate DESC];
        return flowRecs;
    }

    @AuraEnabled
    public static List<Flow__c> getWhatsAppFlowById(String flowId) {
        List<Flow__c> flowRecs = [SELECT Id, Flow_Name__c, Status__c, Category__c, Template_Type__c, Flow_JSON__c, LastModifiedDate FROM Flow__c WHERE Flow_Id__c = :flowId WITH USER_MODE LIMIT 1];
        return flowRecs.size() > 0 ? flowRecs : new List<Flow__c>();
    }

    @AuraEnabled
    public static List<Flow_Submission__c> getFlowSubmissionByFlowId(Id flowId) {
        List<Flow_Submission__c> flowRecs = [SELECT Id, Submitter_Name__c, Submitter_Phone__c, Flow_Response_Mapping__c, CreatedDate FROM Flow_Submission__c WHERE WB_Flow__c = :flowId WITH USER_MODE];
        return flowRecs.size() > 0 ? flowRecs : new List<Flow_Submission__c>();
    }

    @AuraEnabled
    public static List<Flow_Submission__c> getFlowSubmissionById(Id submissionId) {
        List<Flow_Submission__c> flowRecs = [SELECT Submitter_Name__c, Submitter_Phone__c, Flow_Response_Mapping__c, CreatedDate FROM Flow_Submission__c WHERE Id = :submissionId WITH USER_MODE];
        return flowRecs.size() > 0 ? flowRecs : new List<Flow_Submission__c>();
    }

    @AuraEnabled
    public static String getJSONData(String type) {
        String jsonString = '';
        try {
            List<WBC_Flows_JSON__mdt> flowJSON = [SELECT Id, Default_JSON__c, Collect_purchase_interest_JSON__c, Customer_support_JSON__c, Get_feedback_JSON__c, Send_a_survey_JSON__c FROM WBC_Flows_JSON__mdt WITH USER_MODE LIMIT 1];
            
            if(type == 'Default') {
                jsonString = flowJSON[0].Default_JSON__c;
            } else if(type == 'Collect purchase interest') {
                jsonString = flowJSON[0].Collect_purchase_interest_JSON__c;
            } else if(type == 'Get feedback') {
                jsonString = flowJSON[0].Get_feedback_JSON__c;
            } else if(type == 'Send a survey') {
                jsonString = flowJSON[0].Send_a_survey_JSON__c;
            } else if(type == 'Customer support') {
                jsonString = flowJSON[0].Customer_support_JSON__c;
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WhatsAppEmailServiceClass', 'getJSONData', e.getMessage());
        }
        return jsonString;
    }

    @AuraEnabled
    public static String createWhatsAppFlow(String flowName, List<String> categories, String flowJson, String templateType) {
        try {
            String accessToken = wbConfig[0].Access_Token__c;
            String endpoint = wbConfig[0].API_Endpoint__c + '/' + wbConfig[0].API_Version__c + '/' + wbConfig[0].Business_Account_Id__c + '/flows';
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

                // Create a new Flow record
                Flow__c flow = new Flow__c();
                flow.Flow_Name__c = flowName;
                flow.Status__c = 'Draft';
                flow.Flow_Id__c = flowId;
                flow.Flow_JSON__c = flowJson;
                flow.Category__c = String.join(categories, ';');
                flow.Template_Type__c = templateType;

                insert as user flow;
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

    @AuraEnabled
    public static String updateWhatsAppFlow(String flowId, String flowJson) {
        try {
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
          
            String accessToken = wbConfig[0].Access_Token__c;
            String endpoint = wbConfig[0].API_Endpoint__c + '/' + wbConfig[0].API_Version__c + '/' + flowId + '/assets';
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

                List<Flow__c> flowRecs = [SELECT Id, Flow_JSON__c, Status__c, Flow_Id__c FROM Flow__c WHERE Flow_Id__c = :flowId WITH USER_MODE LIMIT 1];
                if(flowRecs.size() > 0){
                    flowRecs[0].Flow_JSON__c = flowJson;
                    flowRecs[0].Status__c = 'Draft';
                    update as user flowRecs;
                }
                
                return 'sucess';
            } else {
                return 'failed';
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'WhatsAppEmailServiceClass', 'updateWhatsAppFlow', e.getMessage());
            return 'failed';
        }
    }

    @AuraEnabled
    public static String publishWhatsAppFlow(String flowId) {
        try {
            String accessToken = wbConfig[0].Access_Token__c;
            String endpoint = wbConfig[0].API_Endpoint__c + '/' + wbConfig[0].API_Version__c + '/' + flowId + '/publish';
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

    @AuraEnabled
    public static String deleteWhatsAppFlow(String flowId) {
        try {
            String accessToken = wbConfig[0].Access_Token__c;
            String endpoint = wbConfig[0].API_Endpoint__c + '/' + wbConfig[0].API_Version__c + '/' + flowId;
            HttpRequest request = new HttpRequest();
            request.setEndpoint(endpoint);
            request.setMethod('DELETE');
            request.setHeader('Authorization', 'Bearer ' + accessToken);
            Http http = new Http();
            HttpResponse response = http.send(request);
            
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

    @AuraEnabled
    public static String deprecateWhatsAppFlow(String flowId) {
        try {
            String accessToken = wbConfig[0].Access_Token__c;
            String endpoint = wbConfig[0].API_Endpoint__c + '/' + wbConfig[0].API_Version__c + '/' + flowId + '/deprecate';
            HttpRequest request = new HttpRequest();
            request.setEndpoint(endpoint);
            request.setMethod('POST');
            request.setHeader('Authorization', 'Bearer ' + accessToken);
            Http http = new Http();
            HttpResponse response = http.send(request);
            
            if (response.getStatusCode() == 200) {
                List<Flow__c> flowRecs = [SELECT Id, Status__c, Flow_Id__c FROM Flow__c WHERE Flow_Id__c = :flowId WITH USER_MODE LIMIT 1];
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

    @AuraEnabled
    public static String getPreviewURLofWhatsAppFlow(String flowId) {
        try {
            String accessToken = wbConfig[0].Access_Token__c;
            String endpoint = wbConfig[0].API_Endpoint__c + '/' + wbConfig[0].API_Version__c + '/' + flowId + '?fields=preview.invalidate(false)';
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
            ErrorHandler.insertErrordata(e, 'WhatsAppEmailServiceClass', 'getPreviewURLofWhatsAppFlow', e.getMessage());
            return 'failed';
        }
    }
}