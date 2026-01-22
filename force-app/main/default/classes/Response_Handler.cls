public with sharing class Response_Handler{
    // public static void store_Callout_Response(HttpResponse res,String classname, String methodname) {
    //     try{
    //         API_Responses__c response = new API_Responses__c();
    //         response.Response_Body__c = res.getBody();
    //         response.Response_Status_Code__c = String.valueOf(res.getStatusCode());
    //         response.Class_Name__c = classname;
    //         response.Method_Name__c = methodname;
        
    //         if(Schema.sObjectType.API_Responses__c.fields.Response_Body__c.isCreateable() &&
    //             Schema.sObjectType.API_Responses__c.fields.Response_Status_Code__c.isCreateable() &&
    //             Schema.sObjectType.API_Responses__c.fields.Class_Name__c.isCreateable() &&
    //             Schema.sObjectType.API_Responses__c.fields.Method_Name__c.isCreateable() &&
    //             Schema.sObjectType.API_Responses__c.fields.Response_Body__c.isAccessible() &&
    //             Schema.sObjectType.API_Responses__c.fields.Response_Status_Code__c.isAccessible() &&
    //             Schema.sObjectType.API_Responses__c.fields.Class_Name__c.isAccessible() &&
    //             Schema.sObjectType.API_Responses__c.fields.Method_Name__c.isAccessible()
    //         ){
    //             insert as user response;
    //         }
            
    //     } 
    //     catch (Exception error) {
    //         ErrorHandler.insertErrorData(error, 'Response_Handler', 'store_Callout_Response', error.getMessage());
    //     }
    // } 

    // public static void store_All_Callout_Response(List<HttpResponse> httpResponses,String classname, String methodname) {
    //     try{
    //         list<API_Responses__c> allResponseList = new list<API_Responses__c>();
    //         for (HttpResponse res : httpResponses) {   
    //             API_Responses__c response = new API_Responses__c();
    //             response.Response_Body__c = res.getBody();
    //             response.Response_Status_Code__c = String.valueOf(res.getStatusCode());
    //             response.Class_Name__c = classname;
    //             response.Method_Name__c = methodname;

    //             allResponseList.add(response);
    //         }
            
    //         insert as user allResponseList;
    //     } 
    //     catch (Exception error) {
    //         ErrorHandler.insertErrorData(error, 'Response_Handler', 'store_All_Callout_Response', error.getMessage());
    //     }
    // }

    // public static void store_All_Callout_Response_Map(Map<String, HttpResponse> httpResponses,String classname) {
    //     try{

    //         list<API_Responses__c> allResponseList = new list<API_Responses__c>();
    //         for (String responseKey : httpResponses.keySet()) {
    //             HttpResponse res = httpResponses.get(responseKey);

    //             API_Responses__c response = new API_Responses__c();
    //             response.Response_Body__c = res.getBody();
    //             response.Response_Status_Code__c = String.valueOf(res.getStatusCode());
    //             response.Class_Name__c = classname;
    //             response.Method_Name__c = responseKey;

    //             allResponseList.add(response);
    //         }
            
    //         insert as user allResponseList;
    //     } 
    //     catch (Exception error) {
    //         ErrorHandler.insertErrorData(error, 'Response_Handler', 'store_All_Callout_Response_Map', error.getMessage());
    //     }
    // } 
    
}