public with sharing class GmailIntegrationControllerV1 {
        
        public String refreshToken { get; set; }
        public Boolean isFailed { get; set; }
        public String errorMessage { get; set; }
        public static String gmailEndpoint = System.label.Google_Endpoint;
        public static String gmailSendingEndpoint = System.label.Gmail_Sending_Endpoint;
        
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
                
                TempData__c settings = TempData__c.getOrgDefaults();
                String clientId = settings.Client_ID__c;
                String clientSecret = settings.Client_Secret__c;
                String redirectUrl = settings.Redirect_URI__c;
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
        
        
        public static void requestNewAccessToken(List<EmailWrapper> gmails, Map<String, Integer> remainingEmails, Map<String, Marketing_Campaign__c> campaign, Boolean IsCampaignData) {
            try {
                
                // Serialize parameters to JSON strings
                String gmailsJson = JSON.serialize(gmails);
                String remainingEmailsJson = JSON.serialize(remainingEmails);
                String campaignJson = JSON.serialize(campaign);
                String isCampaignDataString = String.valueOf(IsCampaignData);
                
                // Pass serialized parameters to sendEmail
                sendEmail(gmailsJson, remainingEmailsJson, campaignJson, isCampaignDataString);
            } catch (Exception e) {
                ErrorHandler.insertErrorData(e, 'GmailIntegrationControllerV1', 'requestNewAccessToken', 'Error in requestNewAccessToken.');
            }
        }
        
        @future(callout=true)
        public static void sendEmail(String gmailsJson, String remainingEmailsJson, String campaignJson, String isCampaignDataString) {
            try {
                // Deserialize parameters
                List<EmailWrapper> gmails = (List<EmailWrapper>) JSON.deserialize(gmailsJson, List<EmailWrapper>.class);
                Map<String, Integer> remainingEmails = (Map<String, Integer>) JSON.deserialize(remainingEmailsJson, Map<String, Integer>.class);
                Map<String, Marketing_Campaign__c> campaign = (Map<String, Marketing_Campaign__c>) JSON.deserialize(campaignJson, Map<String, Marketing_Campaign__c>.class);
                Boolean isCampaignData = Boolean.valueOf(isCampaignDataString);
        
                if (gmails == null || gmails.isEmpty()) {
                    return;
                }
        
                // Step 1: Refresh the access token
                GmailConfig__c settings = GmailConfig__c.getOrgDefaults();
                String clientId = settings.Client_ID__c;
                String clientSecret = settings.Client_Secret__c;
                String refreshToken = settings.Refresh_Token__c;
                String endPoint = gmailEndpoint + 'token';
        
                HttpRequest tokenReq = new HttpRequest();
                tokenReq.setEndpoint(endPoint);
                tokenReq.setMethod('POST');
                tokenReq.setHeader('Content-Type', 'application/x-www-form-urlencoded');
                tokenReq.setBody('client_id=' + clientId +
                    '&client_secret=' + clientSecret +
                    '&refresh_token=' + refreshToken +
                    '&grant_type=refresh_token');
        
                Http http = new Http();
                HttpResponse tokenRes = http.send(tokenReq);
        
                String accessToken;
                if (tokenRes.getStatusCode() == 200) {
                    Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(tokenRes.getBody());
                    accessToken = (String) jsonResponse.get('access_token');
                } else {
                    throw new CalloutException('Failed to get new access token: ' + tokenRes.getBody());
                }
        
                // Step 2: Process emails in batches
                Integer batchSize = 100;
                String batchAPIEndPoint = gmailSendingEndpoint + 'batch/gmail/v1';
                String boundary = 'batch_boundary_' + String.valueOf(Crypto.getRandomInteger());
                HttpRequest emailReq = new HttpRequest();
                emailReq.setEndpoint(batchAPIEndPoint);
                emailReq.setMethod('POST');
                emailReq.setHeader('Authorization', 'Bearer ' + accessToken);
                emailReq.setHeader('Content-Type', 'multipart/mixed; boundary=' + boundary);
        
                for (Integer i = 0; i < gmails.size(); i += batchSize) {
                    List<EmailWrapper> emailBatch = new List<EmailWrapper>();
                    for (Integer j = i; j < Math.min(i + batchSize, gmails.size()); j++) {
                        emailBatch.add(gmails[j]);
                    }
        
                    // Step 3: Prepare batch body
                    String body = '';
                    Map<String, Map<String, String>> consolidatedContactEmailInfoMap = new Map<String, Map<String, String>>();
                    Integer emailSize = 0;
        
                    for (EmailWrapper email : emailBatch) {
                        if (email.contactEmailInfoMap != null && !email.contactEmailInfoMap.isEmpty()) {
                            consolidatedContactEmailInfoMap.putAll(email.contactEmailInfoMap);
                        }
        
                        String rawEmail = 'To: ' + String.join(email.toAddresses, ',') + '\n' +
                            (email.ccAddresses != null && !email.ccAddresses.isEmpty() ? 'Cc: ' + String.join(email.ccAddresses, ',') + '\n' : '') +
                            (email.bccAddresses != null && !email.bccAddresses.isEmpty() ? 'Bcc: ' + String.join(email.bccAddresses, ',') + '\n' : '') +
                            'Subject: ' + email.subject + '\n' +
                            'Content-Type: multipart/mixed; boundary="mixed_boundary"\n\n' +
                            '--mixed_boundary\n' +
                            'Content-Type: text/html; charset=UTF-8\n\n' +
                            email.body + '\n\n' +
                            '--mixed_boundary--\n';
        
                        String encodedEmail = EncodingUtil.base64Encode(Blob.valueOf(rawEmail));
                        String jsonBody = '{"raw":"' + encodedEmail + '"}';
        
                        body += '--' + boundary + '\n' +
                            'Content-Type: application/http\n' +
                            'Content-Transfer-Encoding: binary\n\n' +
                            'POST ' + gmailSendingEndpoint + 'gmail/v1/users/me/messages/send\n' +
                            'Authorization: Bearer ' + accessToken + '\n' +
                            'Content-Type: application/json\n\n' +
                            jsonBody + '\n\n';
        
                        emailSize++;
                    }
        
                    body += '--' + boundary + '--';
                    emailReq.setBody(body);
        
                    // Send the HTTP request
                    HttpResponse emailRes = http.send(emailReq);
        
                    // Handle the response
                    if (emailRes.getStatusCode() != 200) {
                        if (isCampaignData) {
                            System.enqueueJob(new CampaignUpdateQueueable(remainingEmails, campaign, emailSize, 'Failed', emailRes.getBody()));
                        }
                    } else {
                        if (!consolidatedContactEmailInfoMap.isEmpty()) {
                            CreateActivityRecordsFromMail.createCaseEmailMessage(consolidatedContactEmailInfoMap);
                        }
                        if (isCampaignData) {
                            System.enqueueJob(new CampaignUpdateQueueable(remainingEmails, campaign, emailSize, 'Success', null));
                        }
                    }
                }
            } catch (Exception e) {
                ErrorHandler.insertErrorData(e, 'GmailIntegrationControllerV1', 'sendEmail', 'Error while sending email.');
            }
        }
    
    public class EmailWrapper {
        public List<String> toAddresses { get; set; }
        public List<String> ccAddresses { get; set; }
        public List<String> bccAddresses { get; set; }
        public String subject { get; set; }
        public String body { get; set; }
        public Map<String,Map<String,String>> contactEmailInfoMap {get; set;}
    }
    
}