public with sharing class InstagramController {

    public Boolean isRecordCreated { get; set; }
    
    public InstagramController() {
        isRecordCreated = false;
    }

    public PageReference getRefreshToken() {
        try {
            String authCode = ApexPages.currentPage().getParameters().get('code');
    
            if (authCode == null) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Authorization code not found.'));
                return null;
            }
    
            TempData__c settings = TempData__c.getOrgDefaults();
            String clientId = settings.Client_ID__c;
            String clientSecret = settings.Client_Secret__c;
            String redirectUrl = settings.Redirect_URI__c;
            
            String tokenUrl = 'https://api.instagram.com/oauth/access_token';
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
                String sUserId = userId.format();
                
                String longTermToken = getLongLivedAccessToken(accessToken, clientSecret);
                Boolean status = getUserId(accessToken, longTermToken);
    
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.CONFIRM, 'Authorization successful.'));
    
                if (status) {
                    isRecordCreated = true;
                }
            } else {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Failed to get access token: ' + res.getBody()));
            }
            
        } catch (Exception e) {
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
                throw new AuraHandledException('Failed to get long-lived token: ' + res.getBody());
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'InstagramController', 'getLongLivedAccessToken', 'Error while getting long-lived token.');
            return null;
        }

    }

    public static Boolean getUserId(String accessToken, String longRefreshToken){
        try {
            Http http = new Http();
            HttpRequest request = new HttpRequest();
            
            request.setMethod('GET');
            request.setEndpoint('https://graph.instagram.com/v21.0/me?fields=user_id,username&access_token=' + longRefreshToken);
            
            HttpResponse response = http.send(request);
            
            if (response.getStatusCode() == 200) {
                
                Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                String userId = (String) responseBody.get('user_id');
                    
                saveCustomSettings(accessToken , longRefreshToken ,userId);
    
                return true;
    
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'InstagramController', 'getUserId', 'Error while getting user id.');
        }
        
        return false;
    }


    public static void saveCustomSettings(String accessToken, String longRefreshToken , String userId){
        try {
            PlatformEventController.publishEvent('Instagram', accessToken, longRefreshToken, userId);
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'InstagramController', 'saveCustomSettings', 'Error while saving custom settings.');
        }
    }
}