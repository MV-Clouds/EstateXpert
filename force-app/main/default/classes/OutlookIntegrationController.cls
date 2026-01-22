public with sharing class OutlookIntegrationController {

    public String refreshToken { get; set; }
    public Boolean isFailed { get; set; }
    public String errorMessage { get; set; }
    public static String outlookEndpoint = System.label.Outlook_Endpoint + 'token';

    public OutlookIntegrationController() {
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

            HttpRequest req = new HttpRequest();
            req.setEndpoint(outlookEndpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            req.setBody('code=' + authCode +
                        '&client_id=' + clientId +
                        '&client_secret=' + clientSecret +
                        '&redirect_Uri=' + redirectUrl +
                        '&grant_type=authorization_code');
            
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
            isFailed = true;
            errorMessage = 'Failed to get refresh token: ' +  e.getMessage();
        }
    }
    
    public static void requestNewAccessToken(List<EmailWrapper> outlookMails, Map<String, Integer> remainingEmails, Map<String, Marketing_Campaign__c> campaign, Boolean IsCampaignData) {
        try {
            OutlookConfig__c settings = OutlookConfig__c.getOrgDefaults();
            String clientId = settings.Client_ID__c;
            String clientSecret = settings.Client_Secret__c;
            String refreshToken = settings.Refresh_Token_1__c + settings.Refresh_Token_2__c;
        
            HttpRequest req = new HttpRequest();
            req.setEndpoint(outlookEndpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            req.setBody('refresh_token=' + refreshToken +
                        '&client_id=' + clientId +
                        '&client_secret=' + clientSecret +
                        '&grant_type=refresh_token');
        
            Http http = new Http();
            HttpResponse res = http.send(req);
        
            if (res.getStatusCode() == 200) {
                Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                String newAccessToken = (String) jsonResponse.get('access_token');
        
                String remainingEmailsJson = '';
                String campaignJson = '';
                String outlookMailsJson = JSON.serialize(outlookMails);
    
                if(IsCampaignData){
                    remainingEmailsJson = JSON.serialize(remainingEmails);
                    campaignJson = JSON.serialize(campaign);
                }
    
                sendEmail(newAccessToken, outlookMailsJson, remainingEmailsJson, campaignJson, IsCampaignData);
            } else {
                throw new CalloutException('Failed to get new access token: ' + res.getBody());
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'OutlookIntegrationController', 'requestNewAccessToken', 'Error while getting new access token.');
        }


    }
    
    @future(callout=true)
    public static void sendEmail(String accessToken, String outlookMailsJson, String remainingEmailsJson, String campaignJson,Boolean IsCampaignData) {
        try {
            String outlookEndpoint = System.label.Outlook_Batch_Url;
            List<EmailWrapper> outlookMails = (List<EmailWrapper>) JSON.deserialize(outlookMailsJson, List<EmailWrapper>.class);

            Map<String, Integer> remainingEmails = new  Map<String, Integer>();
            Map<String, Marketing_Campaign__c> campaign = new  Map<String, Marketing_Campaign__c>();
    
            Map<String, Map<String, String>> consolidatedContactEmailInfoMap = new Map<String, Map<String, String>>();
    
            if(IsCampaignData){
                remainingEmails = (Map<String, Integer>) JSON.deserialize(remainingEmailsJson, Map<String, Integer>.class);
                campaign = (Map<String, Marketing_Campaign__c>) JSON.deserialize(campaignJson, Map<String, Marketing_Campaign__c>.class);
            }
        
            HttpRequest req = new HttpRequest();
            req.setEndpoint(outlookEndpoint);
            req.setMethod('POST');
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            req.setHeader('Content-Type', 'application/json');
        
            List<Map<String, Object>> batchRequests = new List<Map<String, Object>>();
        
            for (EmailWrapper emailWrapper : outlookMails) {
    
                if (emailWrapper.contactEmailInfoMap != null && !emailWrapper.contactEmailInfoMap.isEmpty()) {
                    consolidatedContactEmailInfoMap.putAll(emailWrapper.contactEmailInfoMap);
                }
    
                List<Map<String, Object>> toRecipients = new List<Map<String, Object>>();
                for (String email : emailWrapper.toAddresses) {
                    toRecipients.add(new Map<String, Object>{
                        'emailAddress' => new Map<String, String>{'address' => email}
                    });
                }
        
                List<Map<String, Object>> ccRecipients = new List<Map<String, Object>>();
                if (emailWrapper.ccAddresses != null && !emailWrapper.ccAddresses.isEmpty()) {
                    for (String cc : emailWrapper.ccAddresses) {
                        ccRecipients.add(new Map<String, Object>{
                            'emailAddress' => new Map<String, String>{'address' => cc}
                        });
                    }
                }
        
                List<Map<String, Object>> bccRecipients = new List<Map<String, Object>>();
                if (emailWrapper.bccAddresses != null && !emailWrapper.bccAddresses.isEmpty()) {
                    for (String bcc : emailWrapper.bccAddresses) {
                        bccRecipients.add(new Map<String, Object>{
                            'emailAddress' => new Map<String, String>{'address' => bcc}
                        });
                    }
                }
        
                Map<String, Object> emailMessage = new Map<String, Object>{
                    'subject' => emailWrapper.subject,
                    'body' => new Map<String, String>{
                        'contentType' => 'HTML',
                        'content' => emailWrapper.body
                    },
                    'bccRecipients' => bccRecipients,
                    'toRecipients' => toRecipients,
                    'ccRecipients' => ccRecipients
                };
        
                Map<String, Object> recipientMap = (Map<String, Object>)toRecipients[0];
                Map<String, String> emailAddressMap = (Map<String, String>)recipientMap.get('emailAddress');
                String emailAddress = emailAddressMap.get('address');
    
    
                batchRequests.add(new Map<String, Object>{
                    'id' => 'sendMail_' + emailAddress,
                    'method' => 'POST',
                    'url' => '/me/sendMail',
                    'body' => new Map<String, Object>{
                        'message' => emailMessage,
                        'saveToSentItems' => 'true'
                    },
                    'headers' => new Map<String, String>{
                        'Content-Type' => 'application/json'
                    }
                });
            }
        
            Map<String, Object> batchRequestBody = new Map<String, Object>{
                'requests' => batchRequests
            };
        
            req.setBody(JSON.serialize(batchRequestBody));
        
            Http http = new Http();
            HttpResponse res = http.send(req);
        
            if (res.getStatusCode() != 200) {
                if(IsCampaignData){
                    System.enqueueJob(new CampaignUpdateQueueable(remainingEmails, campaign, outlookMails.size(), 'Failed', res.getBody()));
                }

                throw new CalloutException('Failed to send batch email: ' + res.getBody());
            } else {
                if(consolidatedContactEmailInfoMap.size() > 0){
                    CreateActivityRecordsFromMail.createCaseEmailMessage(consolidatedContactEmailInfoMap);
                }
                
                if(IsCampaignData){
                    System.enqueueJob(new CampaignUpdateQueueable(remainingEmails, campaign, outlookMails.size(), 'Success', null));
                }
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'OutlookIntegrationController', 'sendEmail', 'Error while sending email.');
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