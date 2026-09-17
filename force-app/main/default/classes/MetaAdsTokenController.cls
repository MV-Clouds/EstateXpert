/**
 * @description  : Controller for Meta Ads SDK Test Page (2-App Architecture).
 *                 - Tech Provider App handles Facebook Login for Business & System User Token.
 *                 - Client Application ID handles individual client Webhook subscriptions.
 *                 - Automatically subscribes the Facebook Page to Webhooks (subscribed_apps) for real-time leads.
 */
public without sharing class MetaAdsTokenController {

    // ─── Configuration from Custom Metadata ──────
    public static Integration_App_Config__mdt getConfig() {
        return Integration_App_Config__mdt.getInstance('Meta_Ads');
    }

    public Boolean hasConfig { get { return getConfig() != null; } }

    public Boolean isConnected { 
        get { 
            Meta_Token_Config__c tokenConfig = Meta_Token_Config__c.getOrgDefaults();
            return tokenConfig != null && String.isNotBlank(tokenConfig.System_User_Token_1__c); 
        } 
    }

    // Properties exposed to Visualforce Page
    public String metaAppId    { get { return getConfig()?.App_ID__c; } }
    public String metaConfigId { get { return getConfig()?.Config_Id__c; } }
    public String apiVersion   { get { return getConfig()?.API_Version__c; } }
    public String apiEndpoint  { get { return getConfig()?.Base_Url__c; } }

    /**
     * @description Exchanges the authCode from the SDK for a System User Token,
     *              fetches Page Access Token, subscribes the Page to Webhooks (leadgen),
     *              and discovers all Lead Forms & Dynamic Fields.
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

            Http http = new Http();

            Integration_App_Config__mdt config = getConfig();
            if (config == null) {
                resultMap.put('success', false);
                resultMap.put('message', 'Integration configuration for Meta Ads is missing.');
                return resultMap;
            }

            String META_APP_ID = config.App_ID__c;
            String META_APP_SECRET = config.App_Secret__c;
            String GRAPH_API_VERSION = config.API_Version__c;
            String GRAPH_BASE_URL = config.Base_Url__c;

            // ── Step 1: Exchange Auth Code for Permanent System User Token ──
            String tokenUrl = GRAPH_BASE_URL + '/' + GRAPH_API_VERSION + '/oauth/access_token'
                + '?client_id='     + EncodingUtil.urlEncode(META_APP_ID,     'UTF-8')
                + '&client_secret=' + EncodingUtil.urlEncode(META_APP_SECRET, 'UTF-8')
                + '&code='          + EncodingUtil.urlEncode(authCode,        'UTF-8');

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
                resultMap.put('success', false);
                resultMap.put('message', errMsg);
                return resultMap;
            }

            String systemUserToken = (String) tokenRes.get('access_token');
            resultMap.put('system_user_token', systemUserToken);
            resultMap.put('client_app_id', clientAppId);

            // ── Step 2: Save Token to Custom Setting ──
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
            
            upsert tokenConfig;

            resultMap.put('success', true);
            resultMap.put('account_name', 'System User Account'); // For VF page display
            return resultMap;

        } catch (Exception e) {
            resultMap.put('success', false);
            resultMap.put('message', 'Exception: ' + e.getMessage() + ' (Line ' + e.getLineNumber() + ')');
            return resultMap;
        }
    }

    @RemoteAction
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

    @RemoteAction
    public static Map<String, Object> deactivateConnection() {
        Map<String, Object> resultMap = new Map<String, Object>();
        try {
            Meta_Token_Config__c tokenConfig = Meta_Token_Config__c.getOrgDefaults();
            if (tokenConfig != null && tokenConfig.Id != null) {
                delete tokenConfig;
            }
            resultMap.put('success', true);
        } catch (Exception e) {
            resultMap.put('success', false);
            resultMap.put('message', e.getMessage());
        }
        return resultMap;
    }
}
