/**
 * Class Name : WhatsappConnectController
 * @description : Controller for WhatsApp Connect SDK Page. Uses OAuth_Configuration__mdt Custom Metadata Type
 *                for configuration and storing connection credentials.
 */
public with sharing class WhatsappConnectController {

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

    private static final String CONFIG_DEV_NAME = 'Whatsapp_OAuth';

    @TestVisible
    private static OAuth_Configuration__mdt mockConfig;

    public WhatsappConnectController() {
        OAuth_Configuration__mdt config = getConfig();

        if (config != null) {
            clientId = config.Client_Id__c != null ? config.Client_Id__c : '';
            clientSecret = config.Client_Secret__c != null ? config.Client_Secret__c : '';
            configurationId = config.Config_Id__c != null ? config.Config_Id__c : '';
            apiVersion = String.isNotBlank(config.API_Version__c) ? config.API_Version__c : 'v24.0';
            apiEndpoint = String.isNotBlank(config.Authorization_Endpoint__c) ? config.Authorization_Endpoint__c : 'https://graph.facebook.com';

            appId = config.Client_App_ID__c != null ? config.Client_App_ID__c : '';
            businessAccountId = config.Client_Business_Account_ID__c != null ? config.Client_Business_Account_ID__c : '';
            phoneNumberId = config.Client_Phone_Number_ID__c != null ? config.Client_Phone_Number_ID__c : '';
            accessToken = config.Access_Token__c != null ? config.Access_Token__c : '';

            if (config.Connected_Date__c != null) {
                lastModifiedDate = config.Connected_Date__c.format('MM/dd/yyyy, hh:mm:ss a');
            } else if (config.SystemModstamp != null && String.isNotBlank(config.Client_Business_Account_ID__c)) {
                lastModifiedDate = config.SystemModstamp.format('MM/dd/yyyy, hh:mm:ss a');
            } else {
                lastModifiedDate = '';
            }
        } else {
            clientId = '';
            clientSecret = '';
            configurationId = '';
            apiVersion = 'v24.0';
            apiEndpoint = 'https://graph.facebook.com';
            appId = '';
            businessAccountId = '';
            phoneNumberId = '';
            accessToken = '';
            lastModifiedDate = '';
        }
    }

    /**
     * Method Name : getConfig
     * @description : Retrieves the WhatsApp OAuth Custom Metadata configuration record.
     * @return OAuth_Configuration__mdt
     */
    public static OAuth_Configuration__mdt getConfig() {
        try {
            if (mockConfig != null) {
                return mockConfig;
            }
            List<OAuth_Configuration__mdt> configs = [SELECT Id, DeveloperName, MasterLabel, Client_Id__c, Client_Secret__c, Config_Id__c, API_Version__c, 
                                                        Authorization_Endpoint__c, Token_Endpoint__c, Access_Token__c, Client_App_ID__c, Client_Business_Account_ID__c,
                                                        Client_Phone_Number_ID__c, Connected_Date__c, SystemModstamp FROM OAuth_Configuration__mdt
                                                        WHERE DeveloperName = :CONFIG_DEV_NAME WITH USER_MODE LIMIT 1];
            return configs.isEmpty() ? null : configs[0];
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'WhatsappConnectController', 'getConfig', e.getMessage());
            return null;
        }
    }

    @RemoteAction
    public static Boolean unlinkAccount() {
        try {
            Boolean isSuccess = saveMetaData(null, null, null, null);
            return isSuccess;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'WhatsappConnectController', 'unlinkAccount', e.getMessage());
            return false;
        }
    }

    @RemoteAction
    public static String saveFBLoginDetails(String sAccessToken, String phoneId, String wabaId, String appId) {
        try {
            OAuth_Configuration__mdt config = getConfig();
            if (config == null || String.isBlank(config.Client_Id__c) || String.isBlank(config.Client_Secret__c)) {
                return 'Failure';
            }

            String tokenEndpoint = config.Token_Endpoint__c;

            String tokenUrl = tokenEndpoint
                + '?grant_type=fb_exchange_token&client_id=' + EncodingUtil.urlEncode(config.Client_Id__c, 'UTF-8')
                + '&client_secret=' + EncodingUtil.urlEncode(config.Client_Secret__c, 'UTF-8')
                + '&fb_exchange_token=' + EncodingUtil.urlEncode(sAccessToken, 'UTF-8');

            HttpRequest req = new HttpRequest();
            req.setEndpoint(tokenUrl);
            req.setMethod('GET');
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                Map<String, Object> responseBody1 = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                String longLivedAccessToken = (String) responseBody1.get('access_token');
                Boolean isSuccess = saveMetaData(longLivedAccessToken, phoneId, wabaId, appId);
                if (isSuccess) {
                    return wabaId;
                }
            } else {
                ErrorHandler.insertErrorData(null, 'WhatsappConnectController', 'saveFBLoginDetails', 'Token exchange failed: ' + res.getStatusCode() + ' ' + res.getBody());
            }
            return null;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'WhatsappConnectController', 'saveFBLoginDetails', e.getMessage());
            return null;
        }
    }

    public static Boolean saveMetaData(String accessToken, String phoneId, String wabaId, String appId) {
        try {
            Metadata.CustomMetadata cmtRecord = new Metadata.CustomMetadata();
            cmtRecord.fullName = 'OAuth_Configuration__mdt.' + CONFIG_DEV_NAME;
            cmtRecord.label = 'Whatsapp OAuth';

            Metadata.CustomMetadataValue cmtAccessToken = new Metadata.CustomMetadataValue();
            cmtAccessToken.field = 'Access_Token__c';
            cmtAccessToken.value = String.isNotBlank(accessToken) ? accessToken : null;
            cmtRecord.values.add(cmtAccessToken);

            Metadata.CustomMetadataValue cmtPhoneId = new Metadata.CustomMetadataValue();
            cmtPhoneId.field = 'Client_Phone_Number_ID__c';
            cmtPhoneId.value = String.isNotBlank(phoneId) ? phoneId : null;
            cmtRecord.values.add(cmtPhoneId);

            Metadata.CustomMetadataValue cmtWabaId = new Metadata.CustomMetadataValue();
            cmtWabaId.field = 'Client_Business_Account_ID__c';
            cmtWabaId.value = String.isNotBlank(wabaId) ? wabaId : null;
            cmtRecord.values.add(cmtWabaId);

            Metadata.CustomMetadataValue cmtAppId = new Metadata.CustomMetadataValue();
            cmtAppId.field = 'Client_App_ID__c';
            cmtAppId.value = String.isNotBlank(appId) ? appId : null;
            cmtRecord.values.add(cmtAppId);

            Metadata.CustomMetadataValue cmtConnectedDate = new Metadata.CustomMetadataValue();
            cmtConnectedDate.field = 'Connected_Date__c';
            cmtConnectedDate.value = String.isNotBlank(wabaId) ? Datetime.now() : null;
            cmtRecord.values.add(cmtConnectedDate);

            Metadata.DeployContainer mdContainer = new Metadata.DeployContainer();
            mdContainer.addMetadata(cmtRecord);

            if (!Test.isRunningTest()) {
                Metadata.Operations.enqueueDeployment(mdContainer, null);
            }
            return true;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'WhatsappConnectController', 'saveMetaData', e.getMessage());
            return false;
        }
    }
}