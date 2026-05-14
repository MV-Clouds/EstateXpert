public without sharing class WhatsappConfigController {

    public static String appId {get; set;}
    public static String businessAccountId {get; set;}
    public static String phoneNumberId {get; set;}
    public static String accessToken {get; set;}
    public static String apiVersion {get; set;}
    public static String apiEndpoint {get; set;}
    public static String clientId {get; set;}
    public static String configurationId {get; set;}
    public static String clientSecret {get; set;}
    public static String lastModifiedDate {get; set;}

    public WhatsappConfigController() {
        MVEX__WhatsAppConfig__c config = MVEX__WhatsAppConfig__c.getOrgDefaults();
        List<String> EndpointVersion = System.Label.Whatsapp_Endpoint.split(';');
        
        apiVersion = EndpointVersion.size() > 1 ? EndpointVersion[1] : 'v24.0';
        apiEndpoint = EndpointVersion.size() > 0 ? EndpointVersion[0] : 'https://graph.facebook.com';

        if (config != null && config.Id != null) {
            appId = config.MVEX__Whatsapp_App_Id__c;
            businessAccountId = config.MVEX__Whatsapp_Business_Account_Id__c;
            phoneNumberId = config.MVEX__Whatsapp_Phone_Number_Id__c;
            accessToken = (config.MVEX__Access_Token_1__c != null ? config.MVEX__Access_Token_1__c : '') + (config.MVEX__Access_Token_2__c != null ? config.MVEX__Access_Token_2__c : '');
            lastModifiedDate = config.LastModifiedDate != null ? config.LastModifiedDate.format('MM/dd/yyyy, hh:mm:ss a') : '';
        } else {
            appId = '';
            businessAccountId = '';
            phoneNumberId = '';
            accessToken = '';
            lastModifiedDate = '';
        }

        List<MVEX__WBConnect_Configuration__mdt> embeddedConfig = [SELECT Id, Config_Id__c, Client_Secret__c, Client_Id__c FROM MVEX__WBConnect_Configuration__mdt order by SystemModstamp desc];
        if (embeddedConfig.size() > 0) {
            clientId = embeddedConfig[0].Client_Id__c;
            clientSecret = embeddedConfig[0].Client_Secret__c;
            configurationId = embeddedConfig[0].Config_Id__c;
        }
    }

    @RemoteAction
    public static Boolean unlinkAccount() {
        try {
            Boolean isSuccess = saveMetaData('', '', '', '');
            if (isSuccess) {
                return true;
            }
            return false;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'WhatsappConfigController', 'unlinkAccount', e.getMessage());
            return false;
        }
    }

    @RemoteAction
    public static String saveFBLoginDetails(String sAccessToken, String phoneId, String wabaId, String appId) {
        try {
            List<MVEX__WBConnect_Configuration__mdt> embeddedConfig = [SELECT Id, Config_Id__c, Client_Secret__c, Client_Id__c FROM MVEX__WBConnect_Configuration__mdt order by SystemModstamp desc];
            if (embeddedConfig.size() < 1) {
                return 'Failure';
            }
            
            String tokenUrl = 'https://graph.facebook.com/v21.0/oauth/access_token?grant_type=fb_exchange_token&client_id=' + embeddedConfig[0].Client_Id__c + '&client_secret=' + embeddedConfig[0].Client_Secret__c + '&fb_exchange_token=' + sAccessToken;
            HttpRequest req = new HttpRequest();
            req.setEndpoint(tokenUrl);
            req.setMethod('GET');
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() == 200) {
                Map<String, Object> responseBody1 = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                String accessToken = (String) responseBody1.get('access_token');
                Boolean isSuccess = saveMetaData(accessToken, phoneId, wabaId, appId);
                if (isSuccess) {
                    return wabaId;
                }
            }
            return null;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'WhatsappConfigController', 'saveFBLoginDetails', e.getMessage());
            return null;
        }
    }

    public static Boolean saveMetaData(String accessToken, String phoneId, String wabaId, String appId) {
        try {
            MVEX__WhatsAppConfig__c config = MVEX__WhatsAppConfig__c.getOrgDefaults();
            
            if (accessToken != null && accessToken.length() > 255) {
                config.MVEX__Access_Token_1__c = accessToken.substring(0, 255);
                config.MVEX__Access_Token_2__c = accessToken.substring(255);
            } else {
                config.MVEX__Access_Token_1__c = accessToken;
                config.MVEX__Access_Token_2__c = '';
            }
            
            config.MVEX__Whatsapp_Business_Account_Id__c = wabaId;
            config.MVEX__Whatsapp_Phone_Number_Id__c = phoneId;
            config.MVEX__Whatsapp_App_Id__c = appId;
            config.MVEX__whatsapp_endpoint__c = 'https://graph.facebook.com';
            config.MVEX__APIVersion__c = 'v24.0';
            
            upsert config;
            return true;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'WhatsappConfigController', 'saveMetaData', e.getMessage());
            return false;
        }
    }
}