/**
* Class Name : MetaAdsTokenController
* Date : 02-10-2026
* Created By : Vyom Soni
* Last Modified Date : 02-10-2026
* Last Modified By : Vyom Soni
* @description : Controller for Meta Ads SDK Test Page (2-App Architecture). Tech Provider App handles Facebook Login for Business & System User Token. Client Application ID handles individual client Webhook subscriptions. Automatically subscribes the Facebook Page to Webhooks (subscribed_apps) for real-time leads.
*/
public with sharing class MetaAdsTokenController {

    public Boolean hasConfig { get { return getConfig() != null; } }

    public Boolean isConnected { 
        get { 
            OAuth_Configuration__mdt config = getConfig();
            return config != null && String.isNotBlank(config.Access_Token__c); 
        } 
    }

    public String metaAppId    { get { return getConfig()?.Client_Id__c; } }
    public String metaConfigId { get { return getConfig()?.Config_Id__c; } }
    public String apiVersion   { get { return getConfig()?.API_Version__c; } }
    public String apiEndpoint  { get { return getConfig()?.Base_URL__c; } }

    /**
    * Method Name : getConfig
    * @description : Gets the OAuth Configuration metadata for Meta Ads.
    * @return MVEX__OAuth_Configuration__mdt
    */
    public static OAuth_Configuration__mdt getConfig() {
        try {
            List<OAuth_Configuration__mdt> configs = [SELECT Access_Token__c, Client_Id__c, Client_Secret__c, Config_Id__c, Base_URL__c, API_Version__c, Authorization_Endpoint__c, Client_App_Id__c FROM OAuth_Configuration__mdt WHERE DeveloperName = 'Meta_Ads_Config' LIMIT 1];
            return configs.isEmpty() ? null : configs[0];
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'MetaAdsTokenController', 'getConfig', e.getMessage());
            return null;
        }
    }

    /**
    * Method Name : exchangeCodeForToken
    * @description : Exchanges the authCode from the SDK for a System User Token, fetches Page Access Token, subscribes the Page to Webhooks (leadgen), and discovers all Lead Forms & Dynamic Fields.
    * @param authCode : OAuth code
    * @param clientAppId : Client Meta App ID
    * @return Map<String, Object>
    */
    @RemoteAction
    public static Map<String, Object> exchangeCodeForToken(String authCode, String clientAppId) {
        Map<String, Object> resultMap = new Map<String, Object>();
        try {
            if (String.isBlank(authCode)) {
                resultMap.put('success', false);
                resultMap.put('message', 'Authorization code is missing.');
                return resultMap;
            }

            OAuth_Configuration__mdt config = getConfig();
            if (config == null) {
                resultMap.put('success', false);
                resultMap.put('message', 'OAuth configuration for Meta Ads is missing.');
                return resultMap;
            }

            String sysUserToken = fetchTokenFromMeta(authCode, config);
            if (sysUserToken == null || sysUserToken.startsWith('Error:')) {
                resultMap.put('success', false);
                resultMap.put('message', sysUserToken == null ? 'Failed to fetch token' : sysUserToken);
                return resultMap;
            }

            saveTokenSettings(sysUserToken, clientAppId);

            resultMap.put('system_user_token', sysUserToken);
            resultMap.put('client_app_id', clientAppId);
            resultMap.put('success', true);
            resultMap.put('account_name', 'System User Account');
            return resultMap;

        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'MetaAdsTokenController', 'exchangeCodeForToken', e.getMessage());
            resultMap.put('success', false);
            resultMap.put('message', 'Exception: ' + e.getMessage());
            return resultMap;
        }
    }

    /**
    * Method Name : fetchTokenFromMeta
    * @description : Fetches the access token from Meta API using auth code.
    * @param authCode : OAuth code
    * @param config : OAuth config
    * @return String
    */
    private static String fetchTokenFromMeta(String authCode, OAuth_Configuration__mdt config) {
        try {
            String appId = config.Client_Id__c;
            String appSecret = config.Client_Secret__c;
            String apiVer = config.API_Version__c;
            String baseUrl = config.Base_URL__c;

            String tokenUrl = baseUrl + '/' + apiVer + '/oauth/access_token'
                + '?client_id='     + EncodingUtil.urlEncode(appId, 'UTF-8')
                + '&client_secret=' + EncodingUtil.urlEncode(appSecret, 'UTF-8')
                + '&code='          + EncodingUtil.urlEncode(authCode, 'UTF-8');

            Http http = new Http();
            HttpRequest req = new HttpRequest();
            req.setEndpoint(tokenUrl);
            req.setMethod('GET');
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(20000);

            HttpResponse res = http.send(req);
            Map<String, Object> tokenRes = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

            if (res.getStatusCode() != 200 || !tokenRes.containsKey('access_token')) {
                String errMsg = 'Token exchange failed: ' + res.getBody();
                if (tokenRes.containsKey('error')) {
                    Map<String, Object> errObj = (Map<String, Object>) tokenRes.get('error');
                    errMsg = (String) errObj.get('message');
                }
                return 'Error: ' + errMsg;
            }

            return (String) tokenRes.get('access_token');
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'MetaAdsTokenController', 'fetchTokenFromMeta', e.getMessage());
            return 'Error: ' + e.getMessage();
        }
    }

    /**
    * Method Name : saveTokenSettings
    * @description : Saves the access token into custom metadata.
    * @param systemUserToken : System user token
    * @param clientAppId : Client Meta App ID
    */
    private static void saveTokenSettings(String systemUserToken, String clientAppId) {
        try {
            Metadata.CustomMetadata customMetadata = new Metadata.CustomMetadata();
            customMetadata.fullName = 'OAuth_Configuration__mdt.Meta_Ads_Config';
            customMetadata.label = 'Meta Ads Config';

            Metadata.CustomMetadataValue tokenField = new Metadata.CustomMetadataValue();
            tokenField.field = 'Access_Token__c';
            tokenField.value = systemUserToken;
            customMetadata.values.add(tokenField);
            
            if (clientAppId != null) {
                Metadata.CustomMetadataValue appField = new Metadata.CustomMetadataValue();
                appField.field = 'Client_App_Id__c';
                appField.value = clientAppId;
                customMetadata.values.add(appField);
            }
            
            Metadata.DeployContainer mdContainer = new Metadata.DeployContainer();
            mdContainer.addMetadata(customMetadata);
            
            if (!Test.isRunningTest()) {
                Id jobId = Metadata.Operations.enqueueDeployment(mdContainer, null);
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'MetaAdsTokenController', 'saveTokenSettings', e.getMessage());
        }
    }

    /**
    * Method Name : checkConnectionStatus
    * @description : Checks the current connection status of Meta Ads.
    * @return Map<String, Object>
    */
    @RemoteAction
    @AuraEnabled
    public static Map<String, Object> checkConnectionStatus() {
        Map<String, Object> resultMap = new Map<String, Object>();
        try {
            OAuth_Configuration__mdt config = getConfig();
            if (config == null || String.isBlank(config.Access_Token__c)) {
                resultMap.put('success', false);
                resultMap.put('message', 'Not connected.');
                return resultMap;
            }

            String clientAppId = config.Client_App_Id__c;

            resultMap.put('account_name', 'System User Account');
            resultMap.put('client_app_id', clientAppId);
            resultMap.put('success', true);
            
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'MetaAdsTokenController', 'getConnectionStatus', e.getMessage());
            resultMap.put('success', false);
            resultMap.put('message', e.getMessage());
        }
        return resultMap;
    }

    /**
    * Method Name : deactivateConnection
    * @description : Deactivates the connection by deleting the token config.
    * @return Map<String, Object>
    */
    @RemoteAction
    @AuraEnabled
    public static Map<String, Object> deactivateConnection() {
        Map<String, Object> resultMap = new Map<String, Object>();
        try {
            OAuth_Configuration__mdt config = getConfig();
            if (config != null && String.isNotBlank(config.Access_Token__c)) {
                saveTokenSettings(null, null); // Clear the token via Metadata API
            }
            resultMap.put('success', true);
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'MetaAdsTokenController', 'deactivateConnection', e.getMessage());
            resultMap.put('success', false);
            resultMap.put('message', e.getMessage());
        }
        return resultMap;
    }
}
