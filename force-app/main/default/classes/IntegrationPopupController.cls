/**
* Class Name : IntegrationPopupController
* Test Class : IntegrationPopupControllerTest
* Created By : Karan Singh
* Last Modified Date : 08/08/2024
* Last Modified By : Karan Singh
* @description : Used to integrate with external systems.
*/
public with sharing class IntegrationPopupController {

    @TestVisible public static String mockValidationResult = null;

    /**
    * Method Name : createPortalListingRecord
    * @param jsonData : JSON data that contains listing data.
    * @param integrationType : String to stored the integration type.
    * @description : Used to save integration settings to database.
    */
    @AuraEnabled
    public static void saveSettings(String jsonData, String integrationType) {
        try {
            Map<String, Object> fieldMap = (Map<String, Object>) JSON.deserializeUntyped(jsonData);
            Map<String, String> stringFieldMap = new Map<String, String>();
            for (String key : fieldMap.keySet()) {
                if(key.endsWith('__c')){
                    stringFieldMap.put(key, (String) fieldMap.get(key));
                }
            }
    
            if (integrationType == 'AWS') {
                MVEX__AWS_Config__c awsSettings = MVEX__AWS_Config__c.getOrgDefaults();
                if (awsSettings == null) {
                    awsSettings = new MVEX__AWS_Config__c();
                    awsSettings.SetupOwnerId = UserInfo.getOrganizationId();
                }
    
                for (String apiName : stringFieldMap.keySet()) {
                    awsSettings.put(apiName, stringFieldMap.get(apiName));
                }
                
                upsert as user awsSettings;
    
            } else if (integrationType == 'Gmail') {
                MVEX__GmailConfig__c gmailSettings = MVEX__GmailConfig__c.getOrgDefaults();
                if (gmailSettings == null) {
                    gmailSettings = new MVEX__GmailConfig__c();
                    gmailSettings.SetupOwnerId = UserInfo.getOrganizationId();
                }
    
                for (String apiName : stringFieldMap.keySet()) {
                    // FIX: Removed the check that only saved Refresh Token. 
                    // Now it saves ClientID, Secret, and RedirectURI as well.
                    gmailSettings.put(apiName, stringFieldMap.get(apiName));
                }

                upsert as user gmailSettings;

            } else if (integrationType == 'Instagram') {
                MVEX__IG_Configuration__c instagramSettings = MVEX__IG_Configuration__c.getOrgDefaults();
                if (instagramSettings == null) {
                    instagramSettings = new MVEX__IG_Configuration__c();
                    instagramSettings.SetupOwnerId = UserInfo.getOrganizationId();
                }
    
                for (String apiName : stringFieldMap.keySet()) {
                    instagramSettings.put(apiName, stringFieldMap.get(apiName));
                }
    
                upsert as user instagramSettings;

            } else if (integrationType == 'Google') {
                MVEX__GoogleLeadConfig__c googleSettings = MVEX__GoogleLeadConfig__c.getOrgDefaults();
                if (googleSettings == null) {
                    googleSettings = new MVEX__GoogleLeadConfig__c();
                    googleSettings.SetupOwnerId = UserInfo.getOrganizationId();
                }
    
                for (String apiName : stringFieldMap.keySet()) {
                    googleSettings.put(apiName, stringFieldMap.get(apiName));
                }
    
                upsert as user googleSettings;

            } else if (integrationType == 'Meta') {
                MVEX__MetaLeadConfig__c metaSettings = MVEX__MetaLeadConfig__c.getOrgDefaults();
                if (metaSettings == null) {
                    metaSettings = new MVEX__MetaLeadConfig__c();
                    metaSettings.SetupOwnerId = UserInfo.getOrganizationId();
                }
    
                for (String apiName : stringFieldMap.keySet()) {
                    metaSettings.put(apiName, stringFieldMap.get(apiName));
                }
    
                upsert as user metaSettings;

            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'IntegrationPopupController', 'saveSettings', 'Error while saving settings.');
        }
    }
     
    /**
    * Class Name : FieldWrapper
    * @description : Wrapper class for storing field details
    */
    public class FieldWrapper {
        @AuraEnabled public String siteUrl;
        @AuraEnabled public Object objectData;
    }
    
    /**
    * Method Name : getSettings
    * @param integrationType : String to stored the integration type.
    * @return FieldWrapper : Wrapper class for storing field details.
    * @description : Method to get integration settings.
    */
    @AuraEnabled
    public static FieldWrapper getSettings(String integrationType) {
        FieldWrapper result = new FieldWrapper();
        try {
            if (integrationType == 'AWS') {
                result.objectData = MVEX__AWS_Config__c.getOrgDefaults();
            } else if (integrationType == 'Gmail') {
                MVEX__GmailConfig__c settings = MVEX__GmailConfig__c.getOrgDefaults();
                
                // Fetch Credentials from Custom Metadata
                List<MVEX__recordManagerConfig__mdt> mdtList = [SELECT MVEX__FieldsData__c FROM MVEX__recordManagerConfig__mdt where MVEX__Integration_Type__c = :integrationType LIMIT 1];
                
                if(!mdtList.isEmpty() && mdtList[0].MVEX__FieldsData__c != null) {
                    String[] parts = mdtList[0].MVEX__FieldsData__c.split(';');
                    if(parts.size() >= 3) {
                        settings.MVEX__Client_ID__c = parts[0];
                        settings.MVEX__Client_Secret__c = parts[1];
                        settings.MVEX__Redirect_URI__c = parts[2];
                    }
                }
                
                result.objectData = settings;
                // Use the redirect URI from metadata for siteUrl or fallback to helper
                if(settings.MVEX__Redirect_URI__c != null) {
                    result.siteUrl = settings.MVEX__Redirect_URI__c;
                } else {
                    result.siteUrl = getSiteUrl(settings.MVEX__Redirect_URI__c, 'Gmail');
                }
            } else if (integrationType == 'Instagram') {
                MVEX__IG_Configuration__c instaSettings = MVEX__IG_Configuration__c.getOrgDefaults();
                if (instaSettings == null) {
                    instaSettings = new MVEX__IG_Configuration__c();
                }

                  // Fetch Credentials from Custom Metadata
                List<MVEX__recordManagerConfig__mdt> mdtList = [SELECT MVEX__FieldsData__c FROM MVEX__recordManagerConfig__mdt where MVEX__Integration_Type__c = :integrationType LIMIT 1];
                
                Boolean isValidMetadata = false;
                if(!mdtList.isEmpty() && String.isNotBlank(mdtList[0].MVEX__FieldsData__c)) {
                    String[] parts = mdtList[0].MVEX__FieldsData__c.split(';');
                    if(parts.size() >= 3 && String.isNotBlank(parts[0]) && String.isNotBlank(parts[1]) && String.isNotBlank(parts[2])) {
                        instaSettings.MVEX__ClientId__c = parts[0].trim();
                        instaSettings.MVEX__ClientSecret__c = parts[1].trim();
                        instaSettings.MVEX__Redirect_URI__c = parts[2].trim();
                        isValidMetadata = true;
                    }
                }

                if (!isValidMetadata) {
                    instaSettings.MVEX__ClientId__c = null;
                    instaSettings.MVEX__ClientSecret__c = null;
                    instaSettings.MVEX__Redirect_URI__c = null;
                }

                result.objectData = instaSettings;
                result.siteUrl = getSiteUrl(instaSettings.MVEX__Redirect_URI__c, 'Instagram');
            } else if (integrationType == 'Google'){
                result.objectData = MVEX__GoogleLeadConfig__c.getOrgDefaults();
            } else if (integrationType == 'Meta'){
                result.objectData = MVEX__MetaLeadConfig__c.getOrgDefaults();
            }
            return result;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'IntegrationPopupController', 'getSettings', 'Error while getting settings.');
            return null;
        }
    }

    /**
    * Method Name : getSiteUrl
    * @param siteurl : String to stored the site url.
    * @param integrationName : String to stored the integration name.
    * @return String : Site url.
    * @description : Method to get site url.
    */
    @AuraEnabled
    public static string getSiteUrl(String siteurl, String integrationName){
        try {
            if (siteurl != null) {
                return siteurl;
            } else {
                String integraName;
                switch on integrationName {
                    when 'Gmail' {
                        integraName = 'MVEX__GmailIntPage';
                    }
                    when 'Instagram' {
                        integraName = 'MVEX__InstagramAccessToken';
                    }
                }
                String urlInstance = String.valueof(System.URL.getOrgDomainURL().toExternalForm());
                String s2;
                
                if (urlInstance.endsWithIgnoreCase('.develop.my.salesforce.com')) {
                    s2 = urlInstance.removeEndIgnoreCase('.develop.my.salesforce.com') + '--mvex.develop.vf.force.com/apex/'+integraName;
                } else if (urlInstance.endsWithIgnoreCase('.sandbox.my.salesforce.com')) {
                    s2 = urlInstance.removeEndIgnoreCase('.sandbox.my.salesforce.com') + '--mvex.sandbox.vf.force.com/apex/'+integraName;
                } else if (urlInstance.endsWithIgnoreCase('.scratch.my.salesforce.com')) {
                    s2 = urlInstance.removeEndIgnoreCase('.scratch.my.salesforce.com') + '--mvex.scratch.vf.force.com/apex/'+integraName;
                } else if(urlInstance.endsWithIgnoreCase('.my.salesforce.com')) {
                    s2 = urlInstance.removeEndIgnoreCase('.my.salesforce.com') + '--mvex.vf.force.com/apex/'+integraName;
                }
                return s2;
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'IntegrationPopupController', 'getSiteUrl', 'Error while getting site url.');
        }

        return null;
    }

    /**
    * Class Name : SocialMediaDataWrapper
    * @description : Wrapper class to store social media data.
    */
    public class SocialMediaDataWrapper {
        @AuraEnabled public Boolean isValid = false;
        @AuraEnabled public Object integrationData;
        @AuraEnabled public String integraName;
    }

    /**
    * Method Name : getSocialMediaData
    * @return List<SocialMediaDataWrapper> : Wrapper class to store social media data.
    * @description : Method to get social media data.
    */
    @AuraEnabled
    public static List<SocialMediaDataWrapper> getSocialMediaData() {
        List<SocialMediaDataWrapper> wrapperList = new List<SocialMediaDataWrapper>();

        try {
            MVEX__IG_Configuration__c instagramCredential = MVEX__IG_Configuration__c.getOrgDefaults();

            SocialMediaDataWrapper instagramWrapper = new SocialMediaDataWrapper();
            instagramWrapper.integraName = 'Instagram';
            instagramWrapper.isValid = instagramCredential.MVEX__ClientId__c != null && instagramCredential.MVEX__ClientSecret__c != null;
            instagramWrapper.integrationData = instagramCredential;
            wrapperList.add(instagramWrapper);

            return wrapperList;

        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'IntegrationPopupController', 'getSocialMediaData', 'Error while getting social media data.');
            return null;
        }
    }

    /**
    * Method Name : get
    * @return List<GoogleAdsDataWrapper> : Wrapper class to store social media data.
    * @description : Method to get social media data.
    */
    @AuraEnabled
    public static List<FieldWrapperData> getGoogleData() {
        List<FieldWrapperData> wrapperList = new List<FieldWrapperData>();

        try {
            MVEX__GoogleLeadConfig__c googleAdsCredential = MVEX__GoogleLeadConfig__c.getOrgDefaults();
            MVEX__MetaLeadConfig__c metaPageCredential = MVEX__MetaLeadConfig__c.getOrgDefaults();

            FieldWrapperData googleAdsWrapper = new FieldWrapperData();
            googleAdsWrapper.integrationName = 'GoogleAds';
            googleAdsWrapper.isValid = googleAdsCredential.MVEX__Google_lead_Form_Secret__c != null && googleAdsCredential.MVEX__Google_Ads_Endpoint__c != null;
            googleAdsWrapper.integrationData = googleAdsCredential;
            wrapperList.add(googleAdsWrapper);

            FieldWrapperData metaWrapper = new FieldWrapperData();
            metaWrapper.integrationName = 'Meta';
            metaWrapper.isValid = metaPageCredential.MVEX__ACCESS_TOKEN__c != null && metaPageCredential.MVEX__APP_SECRET__c != null;
            metaWrapper.integrationData = metaPageCredential;
            wrapperList.add(metaWrapper);

            return wrapperList;

        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'IntegrationPopupController', 'getSocialMediaData', 'Error while getting social media data.');
            return null;
        }
    }

    /**
    * Class Name : FieldWrapperData
    * @description : Wrapper class to store integration data.
    */
    public class FieldWrapperData {
        @AuraEnabled public Boolean isValid = false;
        @AuraEnabled public String integrationName;
        @AuraEnabled public Object integrationData;
    }

    /**
    * Method Name : getIntegrationDetails
    * @return List<FieldWrapperData> : Wrapper class to store integration data.
    * @description : Method to get integration details.
    */
    @AuraEnabled
    public static List<FieldWrapperData> getIntegrationDetails() {
        List<FieldWrapperData> wrapperList = new List<FieldWrapperData>();

        try {
            // Fetching integration details
            MVEX__AWS_Config__c awsCredential = MVEX__AWS_Config__c.getOrgDefaults();
            MVEX__GmailConfig__c gmailCredential = MVEX__GmailConfig__c.getOrgDefaults();
            MVEX__IG_Configuration__c instagramCredential = MVEX__IG_Configuration__c.getOrgDefaults();

            // Gmail Integration
            FieldWrapperData gmailWrapper = new FieldWrapperData();
            gmailWrapper.integrationName = 'Gmail';
            gmailWrapper.integrationData = gmailCredential;
            gmailWrapper.isValid = gmailCredential.MVEX__Client_ID__c != null && gmailCredential.MVEX__Client_Secret__c != null && gmailCredential.MVEX__Redirect_URI__c != null && gmailCredential.MVEX__Refresh_Token__c != null;
            wrapperList.add(gmailWrapper);

            FieldWrapperData awsWrapper = new FieldWrapperData();
            awsWrapper.integrationName = 'AWS';
            awsWrapper.integrationData = awsCredential;
            awsWrapper.isValid = awsCredential.MVEX__AWS_Access_Key__c != null && awsCredential.MVEX__AWS_Secret_Access_Key__c != null && awsCredential.MVEX__S3_Bucket_Name__c != null && awsCredential.MVEX__S3_Region_Name__c != null;
            wrapperList.add(awsWrapper);


            FieldWrapperData instagramWrapper = new FieldWrapperData();
            instagramWrapper.integrationName = 'Instagram';
            instagramWrapper.isValid = instagramCredential.MVEX__ClientId__c != null && instagramCredential.MVEX__ClientSecret__c != null;
            instagramWrapper.integrationData = instagramCredential;
            wrapperList.add(instagramWrapper);

            return wrapperList;

        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'IntegrationPopupController', 'getIntegrationDetails', 'Error while getting integration details.');
            return null;
        }
    }

    /**
    * Method Name : revokeGmailAccess
    * @param refreshToken : String to stored the refresh token.
    * @param recordId : String to stored the record id.
    * @return String : Status of revoke access.
    * @description : Method to revoke gmail access.
    */
    @AuraEnabled
    public static String revokeGmailAccess(String refreshToken, String recordId) {
        String status;
        try {
            // Initialize the HTTP request
            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://oauth2.googleapis.com/revoke');
            req.setMethod('POST');
            
            // Set the parameters for the request
            String requestBody = 'token=' + refreshToken;
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            req.setBody(requestBody);
            
            // Send the request
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            // Check the response
            if (res.getStatusCode() != 200) {
                ErrorHandler.insertErrordata(null, 'IntegrationPopupController', 'revokeGmailAccess', res.getBody() + 'and error at line 430');
            }

            status = deleteGmailConfig(recordId);
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'IntegrationPopupController', 'revokeGmailAccess', 'Error while revoking gmail access.');
            status = e.getMessage();
        }

        return status;
    }

    /**
    * Method Name : deleteGmailConfig
    * @param recordId : String to stored the record id.
    * @return String : Status of revoke access.
    * @description : Method to delete gmail config.
    */
    public static String deleteGmailConfig(String recordId){
        try {
            delete as user new MVEX__GmailConfig__c(Id = recordId);
            return 'success';
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'IntegrationPopupController', 'deleteGmailConfig', 'Error while deleting gmail config.');
            return e.getMessage();
        }
    }

    /**
    * Method Name : revokeAWSAccess
    * @param recordId : String to stored the record id.
    * @return String : Status of revoke access.
    * @description : Method to revoke aws access.
    */
    @AuraEnabled
    public static String revokeAWSAccess(String recordId){
        try {
            delete as user new MVEX__AWS_Config__c(Id = recordId);
            return 'success';
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'IntegrationPopupController', 'revokeAWSAccess', 'Error while revoking aws access.');
            return e.getMessage();
        }
    }

    @AuraEnabled
    public static string revokeInstagramAccess(String recordId){
        try {
            delete as user new MVEX__IG_Configuration__c(Id = recordId);
            return 'success';
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'IntegrationPopupController', 'revokeInstagramAccess', 'Error while revoking Instagram access.');
            return e.getMessage();
        }
    }

    /**
    * Method Name : revokeGoogleAccess
    * @param recordId : String to stored the record id.
    * @return String : Status of revoke access.
    * @description : Method to revoke whatsapp access.
    */
    @AuraEnabled
    public static string revokeGoogleAccess(String recordId,String integrationType){
        try {
            if(integrationType == 'Google'){
                delete as user new MVEX__GoogleLeadConfig__c(Id = recordId);
                return 'success';
            } else if(integrationType == 'Meta'){
                delete as user new MVEX__MetaLeadConfig__c(Id = recordId);
                return 'success';
            } else {
                return 'No integrationType match found';
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'IntegrationPopupController', 'revokeWhatsappAccess', 'Error while revoking whatsapp access.');
            return e.getMessage();
        }
    }

    /**
    * Wrapper Class Name : FieldList
    * @description : This Wrapper class used for method name getAllCustomFields.
    */
    public class FieldList {
        @AuraEnabled
        public String label { get; set; }
        @AuraEnabled
        public String value { get; set; }
        
        public FieldList(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    /**
    * Method Name : siteData
    * @return List<FieldList> : List of FieldList.
    * @description : Method to revoke whatsapp access.
    */
    @AuraEnabled
    public static List<FieldList> siteData(){
        List<FieldList> fieldList = new List<FieldList>();
        try {
            Set<Id> guestUserIds = new Set<Id>();
    
            List<Site> sites = [SELECT Id, GuestUserId, Name, Subdomain, UrlPathPrefix FROM Site WITH USER_MODE LIMIT 10];

            if (!sites.isEmpty()) {
                for (Site site : sites) {
                    guestUserIds.add(site.Id);
                }
                
                if (!guestUserIds.isEmpty()) {
                    List<SiteDetail> siteDetails = [SELECT SecureURL, DurableId FROM SiteDetail WHERE DurableId IN :guestUserIds WITH USER_MODE];
                    
                    Map<Id, String> siteUrlMap = new Map<Id, String>();
                    for (SiteDetail siteDetail : siteDetails) {
                        siteUrlMap.put(siteDetail.DurableId, siteDetail.SecureURL);
                    }

                    for (Site site : sites) {
                        if (siteUrlMap.containsKey(site.Id)) {
                            Map<String, String> resultMap = new Map<String, String>();
                            String siteLabel = site.Name;
                            String siteUrl = siteUrlMap.get(site.Id);
                            fieldList.add(new FieldList(siteLabel, siteUrl));
                        }
                    }
                }
            }

            return fieldList;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'IntegrationPopupController', 'siteData', 'Error while getting site data.');
            return null;
        }
    }

    /**
    * Method Name : validateIntegrationCredentials
    * @param integrationType : 'Instagram', 'Gmail', or 'AWS'
    * @param credential1 : Primary credential (Instagram userId / Gmail refreshToken / AWS accessKey)
    * @param credential2 : Secondary credential (Instagram accessToken / Gmail clientId / AWS secretKey)
    * @return String : 'SUCCESS' or a descriptive error message
    * @description : General credential validator. Routes to the appropriate API call
    *               based on integrationType. Replaces the previous Instagram-only method.
    */
    @AuraEnabled
    public static String validateIntegrationCredentials(String integrationType, String credential1, String credential2) {
        try {
            if (String.isBlank(integrationType)) {
                return 'Integration type is required.';
            }

            if (Test.isRunningTest()) {
                if (mockValidationResult != null) {
                    return mockValidationResult;
                }
                return 'SUCCESS';
            }

            if (integrationType == 'Instagram') {
                return validateInstagram(credential1, credential2);
            } else if (integrationType == 'Gmail') {
                return validateGmail(credential1, credential2);
            } 

            return 'Unsupported integration type: ' + integrationType;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'IntegrationPopupController', 'validateIntegrationCredentials', 'Error while validating credentials.');
            return 'Failed to validate credentials: ' + e.getMessage();
        }
    }

    /**
    * @description : Validates Instagram credentials against Graph API /me endpoint.
    *               credential1 = userId, credential2 = accessToken
    */
    private static String validateInstagram(String userId, String accessToken) {
        if (String.isBlank(userId) || String.isBlank(accessToken)) {
            return 'Please fill in both User ID and Long-Lived Access Token.';
        }

        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setMethod('GET');
        req.setEndpoint('https://graph.instagram.com/v21.0/me?fields=id,user_id,username&access_token=' + EncodingUtil.urlEncode(accessToken.trim(), 'UTF-8'));
        req.setTimeout(20000);

        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 200) {
            Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            String returnedUserId = (String) responseBody.get('user_id');
            String returnedId     = (String) responseBody.get('id');
            String trimmedUserId  = userId.trim();

            Boolean matches = (returnedUserId != null && returnedUserId.equals(trimmedUserId)) ||
                              (returnedId     != null && returnedId.equals(trimmedUserId));

            if (!matches) {
                return 'The provided User ID does not match the authenticated Instagram account.';
            }
            return 'SUCCESS';
        } else {
            Map<String, Object> errorResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            if (errorResponse != null && errorResponse.containsKey('error')) {
                Map<String, Object> errorDetail = (Map<String, Object>) errorResponse.get('error');
                if (errorDetail != null && errorDetail.containsKey('message')) {
                    return (String) errorDetail.get('message');
                }
            }
            return 'Invalid Instagram credentials. Please check your User ID and Access Token.';
        }
    }

    /**
    * @description : Validates a Gmail refresh token by exchanging it for an access token
    *               via Google's token endpoint. The tokeninfo endpoint cannot be used here
    *               because users provide a refresh token, not an access token.
    *               credential1 = refreshToken, credential2 = clientId (optional hint — we look up from metadata)
    */
    private static String validateGmail(String refreshToken, String clientId) {
        if (String.isBlank(refreshToken)) {
            return 'Please enter a valid Gmail Refresh Token.';
        }

        // Fetch Client ID and Client Secret from Custom Metadata
        String metaClientId     = clientId != null ? clientId.trim() : '';
        String metaClientSecret = '';

        List<MVEX__recordManagerConfig__mdt> mdtList = [
            SELECT MVEX__FieldsData__c FROM MVEX__recordManagerConfig__mdt
            WHERE MVEX__Integration_Type__c = 'Gmail' LIMIT 1
        ];
        if (!mdtList.isEmpty() && String.isNotBlank(mdtList[0].MVEX__FieldsData__c)) {
            String[] parts = mdtList[0].MVEX__FieldsData__c.split(';');
            if (parts.size() >= 2) {
                if (String.isBlank(metaClientId) && String.isNotBlank(parts[0])) {
                    metaClientId = parts[0].trim();
                }
                metaClientSecret = parts[1].trim();
            }
        }

        if (String.isBlank(metaClientId) || String.isBlank(metaClientSecret)) {
            return 'Gmail configuration is incomplete. Please check Custom Metadata (Client ID / Client Secret).';
        }

        // Exchange the refresh token for an access token — this validates the token
        String requestBody = 'grant_type=refresh_token' +
                             '&client_id='     + EncodingUtil.urlEncode(metaClientId,     'UTF-8') +
                             '&client_secret=' + EncodingUtil.urlEncode(metaClientSecret, 'UTF-8') +
                             '&refresh_token=' + EncodingUtil.urlEncode(refreshToken.trim(), 'UTF-8');

        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setMethod('POST');
        req.setEndpoint('https://oauth2.googleapis.com/token');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setBody(requestBody);
        req.setTimeout(20000);

        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 200) {
            return 'SUCCESS';
        } else {
            Map<String, Object> errorResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            if (errorResponse != null && errorResponse.containsKey('error_description')) {
                return (String) errorResponse.get('error_description');
            }
            if (errorResponse != null && errorResponse.containsKey('error')) {
                return 'Invalid Gmail credentials: ' + (String) errorResponse.get('error');
            }
            return 'Invalid Gmail Refresh Token. Please re-authorize and try again.';
        }
    }
}