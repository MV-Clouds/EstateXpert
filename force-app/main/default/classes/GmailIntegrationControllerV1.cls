public with sharing class GmailIntegrationControllerV1 {
        
    public String refreshToken { get; set; }
    public Boolean isFailed { get; set; }
    public String errorMessage { get; set; }

        
    public GmailIntegrationControllerV1() {
        isFailed = false;
        errorMessage = '';
        refreshToken = '';
        try {
            String authCode = ApexPages.currentPage().getParameters().get('code');
            String state = ApexPages.currentPage().getParameters().get('state');

            if (authCode == null) {
                isFailed = true;
                errorMessage = 'Authorization code not found.';
                return;
            }

            if (state == null || (state != 'Google_Ads_Config' && state != 'Gmail_OAuth')) {
                isFailed = true;
                errorMessage = 'Invalid state parameter.';
                return;
            }

            String CONFIG_DEV_NAME = state;

            OAuth_Configuration__mdt oAuthConfig = OAuth_Configuration__mdt.getInstance(CONFIG_DEV_NAME);

            String clientId = oAuthConfig.Client_Id__c;
            String clientSecret = oAuthConfig.Client_Secret__c;
            String redirectUrl = oAuthConfig.Redirect_URI__c;

            if(String.isBlank(clientId) || String.isBlank(clientSecret) || String.isBlank(redirectUrl)){
                isFailed = true;
                errorMessage = 'Gmail Credentials configuration missing in Custom Metadata.';
                return;
            }
            
            String endPoint = oAuthConfig.Token_Endpoint__c;
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endPoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            req.setBody('code=' + authCode +
                '&client_id=' + clientId +
                '&client_secret=' + clientSecret +
                '&redirect_uri=' + redirectUrl +
                '&scope=' + oAuthConfig.Scope__c + '&access_type=offline&grant_type=authorization_code');
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            String tokensJson = res.getBody();
                            
            if (res.getStatusCode() == 200) {
                Map<String, Object> tokenResponse = (Map<String, Object>) JSON.deserializeUntyped(tokensJson);
                
                if (tokenResponse.containsKey('refresh_token')) {
                    refreshToken = (String) tokenResponse.get('refresh_token');
                } else {
                    isFailed = true;
                    errorMessage = 'Failed to get refresh token.';
                }
                
            } else {
                isFailed = true;
                errorMessage = 'Failed to get refresh token: ' + tokensJson;
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'GmailIntegrationControllerV1', 'Constuctor', e.getMessage());
            isFailed = true;
            errorMessage = 'Failed to get refresh token: ' +  e.getMessage();
        }
    }
}