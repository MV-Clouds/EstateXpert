public with sharing class GmailIntegrationControllerV1 {
        
    public String refreshToken { get; set; }
    public Boolean isFailed { get; set; }
    public String errorMessage { get; set; }
    public static String gmailEndpoint = System.label.Google_Endpoint;
    public static String gmailSendingEndpoint = System.label.Gmail_Sending_Endpoint;
    @TestVisible public static List<MVEX__recordManagerConfig__mdt> mockMetadata = null;

        
    public GmailIntegrationControllerV1() {
        isFailed = false;
        errorMessage = '';
        refreshToken = '';
        try {
            String authCode = ApexPages.currentPage().getParameters().get('code');
            
            if (authCode == null) {
                isFailed = true;
                errorMessage = 'Authorization code not found.';
                return;
            }

            String clientId = '';
            String clientSecret = '';
            String redirectUrl = '';
            
            List<MVEX__recordManagerConfig__mdt> mdtList = mockMetadata != null ? mockMetadata : [SELECT MVEX__FieldsData__c FROM MVEX__recordManagerConfig__mdt WHERE 
                                                                                                    DeveloperName = 'RecordConfig' LIMIT 1];
            if(!mdtList.isEmpty() && mdtList[0].MVEX__FieldsData__c != null) {
                String[] parts = mdtList[0].MVEX__FieldsData__c.split(';');
                if(parts.size() >= 3) {
                    clientId = parts[0];
                    clientSecret = parts[1];
                    redirectUrl = parts[2];
                }
            }

            if(String.isBlank(clientId) || String.isBlank(clientSecret) || String.isBlank(redirectUrl)){
                isFailed = true;
                errorMessage = 'Gmail Credentials configuration missing in Custom Metadata.';
                return;
            }
            
            String endPoint = gmailEndpoint + 'token';
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endPoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            req.setBody('code=' + authCode +
                '&client_id=' + clientId +
                '&client_secret=' + clientSecret +
                '&redirect_uri=' + redirectUrl +
                '&scope=' + gmailSendingEndpoint + 'auth/gmail.send&access_type=offline&grant_type=authorization_code');
            
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