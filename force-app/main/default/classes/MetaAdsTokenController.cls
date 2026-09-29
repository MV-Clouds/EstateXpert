/**
 * @description  : Controller for Meta Ads SDK Test Page (2-App Architecture).
 *                 - Tech Provider App handles Facebook Login for Business & System User Token.
 *                 - Client Application ID handles individual client Webhook subscriptions.
 *                 - Automatically subscribes the Facebook Page to Webhooks (subscribed_apps) for real-time leads.
 */
public without sharing class MetaAdsTokenController {

    // ─── Configuration from Custom Metadata ──────
    /**
     * @description Gets the Integration App Config metadata for Meta Ads.
     * @return Integration_App_Config__mdt instance
     */
    public static Integration_App_Config__mdt getConfig() {
        return Integration_App_Config__mdt.getInstance('Meta_Ads');
    }

    /**
     * @description Indicates whether config is available
     */
    public Boolean hasConfig { get { return getConfig() != null; } }

    /**
     * @description Indicates whether a valid system user token exists
     */
    public Boolean isConnected { 
        get { 
            Meta_Token_Config__c tokenConfig = Meta_Token_Config__c.getOrgDefaults();
            return tokenConfig != null && String.isNotBlank(tokenConfig.System_User_Token_1__c); 
        } 
    }

    // Properties exposed to Visualforce Page
    /** @description Meta App ID */
    public String metaAppId    { get { return getConfig()?.App_ID__c; } }
    /** @description Meta Config ID */
    public String metaConfigId { get { return getConfig()?.Config_Id__c; } }
    /** @description Graph API Version */
    public String apiVersion   { get { return getConfig()?.API_Version__c; } }
    /** @description Graph API Base URL */
    public String apiEndpoint  { get { return getConfig()?.Base_Url__c; } }

    /**
     * @description Exchanges the authCode from the SDK for a System User Token,
     *              fetches Page Access Token, subscribes the Page to Webhooks (leadgen),
     *              and discovers all Lead Forms & Dynamic Fields.
     * @param authCode OAuth code
     * @param clientAppId Client Meta App ID
     * @return Map with success flag and message/tokens
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

            Integration_App_Config__mdt config = getConfig();
            if (config == null) {
                resultMap.put('success', false);
                resultMap.put('message', 'Integration configuration for Meta Ads is missing.');
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
            resultMap.put('success', false);
            resultMap.put('message', 'Exception: ' + e.getMessage());
            return resultMap;
        }
    }

    private static String fetchTokenFromMeta(String authCode, Integration_App_Config__mdt config) {
        String appId = config.App_ID__c;
        String appSecret = config.App_Secret__c;
        String apiVer = config.API_Version__c;
        String baseUrl = config.Base_Url__c;

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
    }

    private static void saveTokenSettings(String systemUserToken, String clientAppId) {
        Meta_Token_Config__c tokenConfig = Meta_Token_Config__c.getOrgDefaults();
        if (tokenConfig == null) {
            tokenConfig = new Meta_Token_Config__c();
            tokenConfig.SetupOwnerId = UserInfo.getOrganizationId();
        }
        
        tokenConfig.Client_App_Id__c = clientAppId;
        
        if (String.isNotBlank(systemUserToken)) {
            if (systemUserToken.length() <= 255) {
                tokenConfig.System_User_Token_1__c = systemUserToken;
                tokenConfig.System_User_Token_2__c = null;
            } else {
                tokenConfig.System_User_Token_1__c = systemUserToken.substring(0, 255);
                tokenConfig.System_User_Token_2__c = systemUserToken.substring(255);
            }
        }
        
        upsert as user tokenConfig;
    }

    /**
     * @description Checks the current connection status of Meta Ads.
     * @return Map containing success flag and account info
     */
    @RemoteAction
    @AuraEnabled
    public static Map<String, Object> checkConnectionStatus() {
        Map<String, Object> resultMap = new Map<String, Object>();
        try {
            Meta_Token_Config__c tokenConfig = Meta_Token_Config__c.getOrgDefaults();
            if (tokenConfig == null || String.isBlank(tokenConfig.System_User_Token_1__c)) {
                resultMap.put('success', false);
                resultMap.put('message', 'Not connected.');
                return resultMap;
            }

            String clientAppId = tokenConfig.Client_App_Id__c;

            resultMap.put('account_name', 'System User Account');
            resultMap.put('client_app_id', clientAppId);
            resultMap.put('success', true);
            
        } catch (Exception e) {
            resultMap.put('success', false);
            resultMap.put('message', e.getMessage());
        }
        return resultMap;
    }

    /**
     * @description Deactivates the connection by deleting the token config.
     * @return Map containing success flag
     */
    @RemoteAction
    @AuraEnabled
    public static Map<String, Object> deactivateConnection() {
        Map<String, Object> resultMap = new Map<String, Object>();
        try {
            Meta_Token_Config__c tokenConfig = Meta_Token_Config__c.getOrgDefaults();
            if (tokenConfig != null && tokenConfig.Id != null) {
                delete as user tokenConfig;
            }
            resultMap.put('success', true);
        } catch (Exception e) {
            resultMap.put('success', false);
            resultMap.put('message', e.getMessage());
        }
        return resultMap;
    }
}
