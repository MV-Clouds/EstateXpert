public with sharing class InstagramController {

    public Boolean isRecordCreated { get; set; }
    public Boolean hasError { get; set; }
    public String errorMessage { get; set; }
    public String longLivedToken { get; set; }
    public String instagramUserId { get; set; }
    public static final String instagramEndpoint = System.label.InstagramEndPoint;
    
    public InstagramController() {
        isRecordCreated = false;
        hasError = false;
        errorMessage = '';
        longLivedToken = '';
        instagramUserId = '';
    }

     public PageReference getRefreshToken() {
        try {
            String authCode = ApexPages.currentPage().getParameters().get('code');
    
            if (authCode == null) {
                hasError = true;
                errorMessage = 'Authorization code not found. The authentication token has expired or is invalid.';
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, errorMessage));
                return null;
            }

            String clientId = '';
            String clientSecret = '';
            String redirectUrl = '';
            String tokenUrl = '';

            List<OAuth_Configuration__mdt> mdtList = [SELECT Client_Id__c, Client_Secret__c, Redirect_URI__c, Token_Endpoint__c FROM OAuth_Configuration__mdt WHERE DeveloperName = 'Instagram_OAuth' WITH USER_MODE LIMIT 1];
            if(!mdtList.isEmpty()) {
                clientId = mdtList[0].Client_Id__c;
                clientSecret = mdtList[0].Client_Secret__c;
                redirectUrl = mdtList[0].Redirect_URI__c;
                tokenUrl = mdtList[0].Token_Endpoint__c;
            }

            if(String.isBlank(clientId) || String.isBlank(clientSecret) || String.isBlank(redirectUrl)){
                hasError = true;
                errorMessage = 'Instagram Credentials configuration missing in Custom Metadata.';
                return null;
            }

            String body = 'client_id=' + EncodingUtil.urlEncode(clientId, 'UTF-8') +
                          '&client_secret=' + EncodingUtil.urlEncode(clientSecret, 'UTF-8') +
                          '&grant_type=authorization_code' +
                          '&redirect_uri=' + EncodingUtil.urlEncode(redirectUrl, 'UTF-8') +
                          '&code=' + EncodingUtil.urlEncode(authCode, 'UTF-8');
    
            HttpRequest req = new HttpRequest();
            req.setEndpoint(tokenUrl);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            req.setBody(body);
            Http http = new Http();
            HttpResponse res = http.send(req);
    
            if (res.getStatusCode() == 200) {
                Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                String accessToken = (String) responseBody.get('access_token');
                Long userId = (Long) responseBody.get('user_id');
                String sUserId = String.valueOf(userId);
                
                String longTermToken = getLongLivedAccessToken(accessToken, clientSecret);
                Boolean status = getUserId(accessToken, longTermToken);
    
                if (status) {
                    isRecordCreated = true;
                    longLivedToken = longTermToken;
                    instagramUserId = sUserId;
                } else {
                    hasError = true;
                    errorMessage = 'Failed to retrieve user information.';
                }
            } else {
                hasError = true;
                errorMessage = 'Failed to get access token. Please verify your credentials.';
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, errorMessage + ': ' + res.getBody()));
            }
            
        } catch (Exception e) {
            hasError = true;
            errorMessage = 'An unexpected error occurred. Please try again.';
            ErrorHandler.insertErrorData(e, 'InstagramController', 'getRefreshToken', 'Error while getting refresh token.');
        }
        
        return null;
    }

    @RemoteAction
    public static String getLongLivedAccessToken(String shortLivedToken, String clientSecret) { 
        try {
            String longTokenUrl = 'https://graph.instagram.com/access_token?grant_type=ig_exchange_token&client_secret=' + clientSecret + '&access_token=' + shortLivedToken;

            HttpRequest req = new HttpRequest();
            req.setEndpoint(longTokenUrl);
            req.setMethod('GET');
    
            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                String longTermAccessToken = (String) responseBody.get('access_token');
                    return longTermAccessToken;
            } else {
                ErrorHandler.insertErrordata(null, 'InstagramController', 'getLongLivedAccessToken', 'Failed to get long-lived token: ' + res.getBody() + ' and error at line no 99.');
                return null;
            }

        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'InstagramController', 'getLongLivedAccessToken', 'Error while getting long-lived token.');
            return null;
        }

    }

    public static Boolean getUserId(String accessToken, String longRefreshToken){
        try {
            String graphApiVersion = 'v24.0';
            try {
                List<OAuth_Configuration__mdt> instaConfigs = [
                    SELECT API_Version__c
                    FROM OAuth_Configuration__mdt
                    WHERE DeveloperName = 'Instagram_OAuth'
                    WITH USER_MODE
                    LIMIT 1
                ];
                if (!instaConfigs.isEmpty() && String.isNotBlank(instaConfigs[0].API_Version__c)) {
                    graphApiVersion = instaConfigs[0].API_Version__c.trim();
                }
            } catch (Exception e1) {
                graphApiVersion = 'v24.0';
            }
            if (String.isBlank(graphApiVersion)) {
                graphApiVersion = 'v24.0';
            }
            if (!graphApiVersion.toLowerCase().startsWith('v')) {
                graphApiVersion = 'v' + graphApiVersion;
            }
            Http http = new Http();
            HttpRequest request = new HttpRequest();
            
            request.setMethod('GET');
            request.setEndpoint(instagramEndpoint + graphApiVersion + '/me?fields=user_id,username&access_token=' + longRefreshToken);
            
            HttpResponse response = http.send(request);
            
            if (response.getStatusCode() == 200) {
                
                Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                String userId = (String) responseBody.get('user_id');
                    
                return true;
    
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'InstagramController', 'getUserId', 'Error while getting user id.');
        }
        
        return false;
    }
}