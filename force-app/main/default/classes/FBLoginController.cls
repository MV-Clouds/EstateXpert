global with sharing class FBLoginController {
    // @RemoteAction
    // global static String saveFBLoginDetails(String sAccessToken, String userId, String clientId, String clientSecret, String configId, String phoneId, String accountId){
    //     WhatsAppConfig__c config = WhatsAppConfig__c.getOrgDefaults();
    //     String whatsappEndpoint = config.Whatsapp_Endpoint__c;
    //     String tokenUrl = whatsappEndpoint + 'v21.0/oauth/access_token?grant_type=fb_exchange_token&client_id='+clientId+'&client_secret='+clientSecret+'&fb_exchange_token='+sAccessToken;
    //     HttpRequest req = new HttpRequest();
    //     req.setEndpoint(tokenUrl);
    //     req.setMethod('GET');
    //     req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
    //     Http http = new Http();
    //     HttpResponse res = http.send(req);
        
    //     if (res.getStatusCode() == 200) {
    //         Map<String, Object> responseBody1 = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
    //         String accessToken = (String) responseBody1.get('access_token');
    //         saveMetaData(accessToken, userId, clientId, clientSecret, configId, phoneId, accountId);
    //     }
    //     return 'Success';   
    // }

    // public static void saveMetaData(String accessToken, String userId,String clientId, String clientSecret, String configId,String phoneId, String accountId ){
    //     try {
    //         WhatsAppConfig__c settings = WhatsAppConfig__c.getOrgDefaults();

    //         if (settings == null) {
    //             settings = new WhatsAppConfig__c();
    //         }
    //         settings.Whatsapp_App_Id__c = clientId;
    //         settings.WhatsApp_Client_Secret__c = clientSecret;
    //         settings.Whatsapp_Configure_Id__c = configId;
    //         settings.Access_Token_For_Whatsapp__c = accessToken;
    //         settings.Whatsapp_Business_Account_Id__c = accountId; 
    //         settings.Whatsapp_Phone_Number_Id__c = phoneId; 
    //         settings.Whatsapp_Endpoint__c = 'https://graph.facebook.com/v22.0/'+phoneId+'/messages';
    //         settings.Whatsapp_Template_Endpoint__c = 'https://graph.facebook.com/v22.0/'+accountId+'/message_templates';

    //         upsert as user settings;
    //     } catch (Exception e) {
    //         ErrorHandler.insertErrorData(e, 'FBLoginController', 'saveMetaData', e.getMessage());
    //     }

    // }
}