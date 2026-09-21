/**
 * @description Scheduled Apex to automatically refresh the Meta Long-Lived User Access Token
 *              before it expires (60 days). Should be scheduled to run every 30 days.
 *
 * HOW TO SCHEDULE (run once in Developer Console → Execute Anonymous):
 *
 *   MetaTokenRefreshScheduler.scheduleRefresh();
 *
 * This will schedule it to run on the 1st of every month at 2:00 AM.
 * Alternatively, schedule manually via Setup → Scheduled Jobs → Schedule Apex.
 */
global class MetaTokenRefreshScheduler implements Schedulable {

    /**
     * @description Convenience method to schedule this job programmatically.
     *              Call this once from Execute Anonymous after deploying.
     */
    global static void scheduleRefresh() {
        // Runs at 2:00 AM on the 1st of every month
        String cronExpr = '0 0 2 1 * ?';
        System.schedule('Meta Ads Token Auto-Refresh', cronExpr, new MetaTokenRefreshScheduler());
        System.debug('MetaTokenRefreshScheduler: Scheduled successfully. Runs 1st of every month at 2AM.');
    }

    global void execute(SchedulableContext sc) {
        refreshToken();
    }

    /**
     * @description Core refresh logic. Can also be called manually from Execute Anonymous
     *              to test: MetaTokenRefreshScheduler.refreshToken();
     */
    @future(callout=true)
    global static void refreshToken() {
        try {
            // 1. Load current token
            Meta_Token_Config__c cfg = Meta_Token_Config__c.getOrgDefaults();
            if (cfg == null || String.isBlank(cfg.System_User_Token_1__c)) {
                System.debug('MetaTokenRefreshScheduler: No token found in Meta_Token_Config__c. Skipping refresh.');
                return;
            }

            String currentToken = cfg.System_User_Token_1__c
                + (String.isNotBlank(cfg.System_User_Token_2__c) ? cfg.System_User_Token_2__c : '');

            // 2. Load app credentials
            Integration_App_Config__mdt config = Integration_App_Config__mdt.getInstance('Meta_Ads');
            if (config == null) {
                System.debug('MetaTokenRefreshScheduler: Integration_App_Config__mdt Meta_Ads record missing. Cannot refresh.');
                return;
            }

            String appId     = config.App_ID__c;
            String appSecret = config.App_Secret__c;
            String apiVer    = config.API_Version__c;
            String baseUrl   = config.Base_Url__c;

            // 3. Call Meta token refresh endpoint
            String refreshUrl = baseUrl + '/' + apiVer + '/oauth/access_token'
                + '?grant_type=fb_exchange_token'
                + '&client_id='         + EncodingUtil.urlEncode(appId, 'UTF-8')
                + '&client_secret='     + EncodingUtil.urlEncode(appSecret, 'UTF-8')
                + '&fb_exchange_token=' + EncodingUtil.urlEncode(currentToken, 'UTF-8');

            HttpRequest req = new HttpRequest();
            req.setEndpoint(refreshUrl);
            req.setMethod('GET');
            req.setTimeout(20000);

            Http http = new Http();
            HttpResponse res = http.send(req);

            Map<String, Object> tokenRes = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

            if (res.getStatusCode() != 200 || !tokenRes.containsKey('access_token')) {
                System.debug('MetaTokenRefreshScheduler: Token refresh failed. Response: ' + res.getBody());
                // ErrorHandler.insertErrorData(null, 'MetaTokenRefreshScheduler', 'refreshToken', 'Token refresh failed: ' + res.getBody());
                return;
            }

            String newToken = (String) tokenRes.get('access_token');

            // 4. Save the refreshed token back to custom setting
            if (newToken.length() <= 255) {
                cfg.System_User_Token_1__c = newToken;
                cfg.System_User_Token_2__c = null;
            } else {
                cfg.System_User_Token_1__c = newToken.substring(0, 255);
                cfg.System_User_Token_2__c = newToken.substring(255);
            }

            update cfg;

            System.debug('MetaTokenRefreshScheduler: Token refreshed successfully. New expiry: 60 days from now.');

        } catch (Exception e) {
            System.debug('MetaTokenRefreshScheduler: Exception during refresh - ' + e.getMessage());
            // ErrorHandler.insertErrorData(e, 'MetaTokenRefreshScheduler', 'refreshToken', e.getMessage());
        }
    }
}
