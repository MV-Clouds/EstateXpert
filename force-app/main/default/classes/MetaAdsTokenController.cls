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
            return tokenConfig != null && String.isNotBlank(tokenConfig.Page_Access_Token_1__c); 
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

            // ── Step 2: Fetch Connected Pages & Page Tokens via /me/accounts ──
            HttpRequest pageReq = new HttpRequest();
            pageReq.setEndpoint(GRAPH_BASE_URL + '/' + GRAPH_API_VERSION + '/me/accounts?fields=id,name,access_token,tasks&access_token=' + EncodingUtil.urlEncode(systemUserToken, 'UTF-8'));
            pageReq.setMethod('GET');
            pageReq.setTimeout(20000);

            HttpResponse pageRes = http.send(pageReq);
            Map<String, Object> pagesMap = (Map<String, Object>) JSON.deserializeUntyped(pageRes.getBody());
            List<Object> pagesList = pagesMap.containsKey('data') ? (List<Object>) pagesMap.get('data') : new List<Object>();

            // ── Step 3: Extract Page Token & Page ID ──
            String pageAccessToken = systemUserToken;
            String foundPageId = null;
            String foundPageName = null;

            if (!pagesList.isEmpty()) {
                Map<String, Object> firstPage = (Map<String, Object>) pagesList[0];
                foundPageId = (String) firstPage.get('id');
                foundPageName = (String) firstPage.get('name');
                if (firstPage.containsKey('access_token')) {
                    pageAccessToken = (String) firstPage.get('access_token');
                }
            } else {
                // Fallback direct check for demo page
                HttpRequest directPageReq = new HttpRequest();
                directPageReq.setEndpoint(GRAPH_BASE_URL + '/' + GRAPH_API_VERSION + '/1224679970734324?fields=id,name,access_token&access_token=' + EncodingUtil.urlEncode(systemUserToken, 'UTF-8'));
                directPageReq.setMethod('GET');
                HttpResponse directRes = http.send(directPageReq);
                if (directRes.getStatusCode() == 200) {
                    Map<String, Object> dpMap = (Map<String, Object>) JSON.deserializeUntyped(directRes.getBody());
                    foundPageId = (String) dpMap.get('id');
                    foundPageName = (String) dpMap.get('name');
                    if (dpMap.containsKey('access_token')) {
                        pageAccessToken = (String) dpMap.get('access_token');
                    }
                    pagesList.add(dpMap);
                }
            }

            resultMap.put('pages', pagesList);
            resultMap.put('page_access_token', pageAccessToken);
            resultMap.put('page_id', foundPageId);
            resultMap.put('page_name', foundPageName);

            // ── Step 4: Subscribe the Page to Webhooks (subscribed_apps) for Real-Time Leads ──
            Boolean webhookSubscribed = false;
            String webhookSubscribedMsg = '';

            if (String.isNotBlank(foundPageId)) {
                try {
                    String subUrl = GRAPH_BASE_URL + '/' + GRAPH_API_VERSION + '/' + foundPageId + '/subscribed_apps'
                        + '?subscribed_fields=leadgen'
                        + '&access_token=' + EncodingUtil.urlEncode(pageAccessToken, 'UTF-8');

                    HttpRequest subReq = new HttpRequest();
                    subReq.setEndpoint(subUrl);
                    subReq.setMethod('POST');
                    subReq.setHeader('Content-Type', 'application/json');
                    subReq.setTimeout(20000);

                    HttpResponse subRes = http.send(subReq);
                    System.debug('[MetaAdsTokenController] subscribed_apps Status: ' + subRes.getStatusCode());
                    System.debug('[MetaAdsTokenController] subscribed_apps Body: ' + subRes.getBody());

                    Map<String, Object> subMap = (Map<String, Object>) JSON.deserializeUntyped(subRes.getBody());
                    if (subRes.getStatusCode() == 200 && subMap.containsKey('success') && (Boolean) subMap.get('success') == true) {
                        webhookSubscribed = true;
                        webhookSubscribedMsg = 'Successfully subscribed to real-time leads (leadgen).';
                    } else {
                        webhookSubscribedMsg = subRes.getBody();
                    }
                } catch (Exception subEx) {
                    webhookSubscribedMsg = 'Subscription call error: ' + subEx.getMessage();
                }
            }

            resultMap.put('webhook_subscribed', webhookSubscribed);
            resultMap.put('webhook_message', webhookSubscribedMsg);

            // ── Step 5: Automatically Fetch Lead Forms & Dynamic Fields ──
            if (String.isNotBlank(foundPageId)) {
                HttpRequest formReq = new HttpRequest();
                formReq.setEndpoint(GRAPH_BASE_URL + '/' + GRAPH_API_VERSION + '/' + foundPageId + '/leadgen_forms?fields=id,name,status,created_time,questions&access_token=' + EncodingUtil.urlEncode(pageAccessToken, 'UTF-8'));
                formReq.setMethod('GET');
                formReq.setTimeout(20000);

                HttpResponse formRes = http.send(formReq);
                Map<String, Object> formMap = (Map<String, Object>) JSON.deserializeUntyped(formRes.getBody());
                if (formMap.containsKey('data')) {
                    resultMap.put('forms', formMap.get('data'));
                }
            }

            // ── Step 6: Save Tokens to Custom Setting ──
            Meta_Token_Config__c tokenConfig = Meta_Token_Config__c.getOrgDefaults();
            if (tokenConfig == null) {
                tokenConfig = new Meta_Token_Config__c();
                tokenConfig.SetupOwnerId = UserInfo.getOrganizationId();
            }
            
            tokenConfig.Client_App_Id__c = clientAppId;
            tokenConfig.Page_Id__c = foundPageId;
            
            if (String.isNotBlank(systemUserToken)) {
                if (systemUserToken.length() <= 255) {
                    tokenConfig.System_User_Token_1__c = systemUserToken;
                    tokenConfig.System_User_Token_2__c = null;
                } else {
                    tokenConfig.System_User_Token_1__c = systemUserToken.substring(0, 255);
                    tokenConfig.System_User_Token_2__c = systemUserToken.substring(255);
                }
            }
            
            if (String.isNotBlank(pageAccessToken)) {
                if (pageAccessToken.length() <= 255) {
                    tokenConfig.Page_Access_Token_1__c = pageAccessToken;
                    tokenConfig.Page_Access_Token_2__c = null;
                } else {
                    tokenConfig.Page_Access_Token_1__c = pageAccessToken.substring(0, 255);
                    tokenConfig.Page_Access_Token_2__c = pageAccessToken.substring(255);
                }
            }
            
            upsert tokenConfig;

            resultMap.put('success', true);
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
            if (tokenConfig == null || String.isBlank(tokenConfig.Page_Access_Token_1__c)) {
                resultMap.put('success', false);
                resultMap.put('message', 'Not connected.');
                return resultMap;
            }

            String pageAccessToken = tokenConfig.Page_Access_Token_1__c + (String.isNotBlank(tokenConfig.Page_Access_Token_2__c) ? tokenConfig.Page_Access_Token_2__c : '');
            String pageId = tokenConfig.Page_Id__c;
            String clientAppId = tokenConfig.Client_App_Id__c;

            Integration_App_Config__mdt config = getConfig();
            if (config == null) {
                resultMap.put('success', false);
                return resultMap;
            }

            String GRAPH_API_VERSION = config.API_Version__c;
            String GRAPH_BASE_URL = config.Base_Url__c;

            Http http = new Http();
            
            // Fetch Page Name
            HttpRequest pageReq = new HttpRequest();
            pageReq.setEndpoint(GRAPH_BASE_URL + '/' + GRAPH_API_VERSION + '/' + pageId + '?fields=name&access_token=' + EncodingUtil.urlEncode(pageAccessToken, 'UTF-8'));
            pageReq.setMethod('GET');
            pageReq.setTimeout(20000);
            HttpResponse pageRes = http.send(pageReq);
            
            String foundPageName = pageId;
            if (pageRes.getStatusCode() == 200) {
                Map<String, Object> pMap = (Map<String, Object>) JSON.deserializeUntyped(pageRes.getBody());
                if (pMap.containsKey('name')) {
                    foundPageName = (String) pMap.get('name');
                }
            }

            // Fetch Forms
            HttpRequest formReq = new HttpRequest();
            formReq.setEndpoint(GRAPH_BASE_URL + '/' + GRAPH_API_VERSION + '/' + pageId + '/leadgen_forms?fields=id,name,status,created_time,questions&access_token=' + EncodingUtil.urlEncode(pageAccessToken, 'UTF-8'));
            formReq.setMethod('GET');
            formReq.setTimeout(20000);
            HttpResponse formRes = http.send(formReq);

            if (formRes.getStatusCode() == 200) {
                Map<String, Object> formMap = (Map<String, Object>) JSON.deserializeUntyped(formRes.getBody());
                if (formMap.containsKey('data')) {
                    resultMap.put('forms', formMap.get('data'));
                }
            }

            resultMap.put('page_access_token', pageAccessToken);
            resultMap.put('page_id', pageId);
            resultMap.put('page_name', foundPageName);
            resultMap.put('client_app_id', clientAppId);
            resultMap.put('webhook_subscribed', true);
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
