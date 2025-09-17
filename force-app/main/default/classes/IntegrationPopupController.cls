/**
* Class Name : IntegrationPopupController
* Test Class : IntegrationPopupControllerTest
* Created By : Karan Singh
* Last Modified Date : 08/08/2024
* Last Modified By : Karan Singh
* @description : Used to integrate with external systems.
*/
public with sharing class IntegrationPopupController {

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
                AWS_Config__c awsSettings = AWS_Config__c.getOrgDefaults();
                if (awsSettings == null) {
                    awsSettings = new AWS_Config__c();
                    awsSettings.SetupOwnerId = UserInfo.getOrganizationId();
                }
    
                for (String apiName : stringFieldMap.keySet()) {
                    awsSettings.put(apiName, stringFieldMap.get(apiName));
                }
                
                upsert as user awsSettings;
    
            } else if (integrationType == 'Gmail') {
                GmailConfig__c gmailSettings = GmailConfig__c.getOrgDefaults();
                if (gmailSettings == null) {
                    gmailSettings = new GmailConfig__c();
                    gmailSettings.SetupOwnerId = UserInfo.getOrganizationId();
                }
    
                for (String apiName : stringFieldMap.keySet()) {
                    gmailSettings.put(apiName, stringFieldMap.get(apiName));
                }

                upsert as user gmailSettings;

            } else if (integrationType == 'Outlook') {
                OutlookConfig__c outlookSettings = OutlookConfig__c.getOrgDefaults();
                if (outlookSettings == null) {
                    outlookSettings = new OutlookConfig__c();
                    outlookSettings.SetupOwnerId = UserInfo.getOrganizationId();
                }
    
                for (String apiName : stringFieldMap.keySet()) {
                    if (apiName == 'MVEX__Refresh_Token__c') {
                        String refreshToken = (String) stringFieldMap.get(apiName);
                        if (refreshToken != null && refreshToken.length() > 255) {
                            outlookSettings.Refresh_Token_1__c = refreshToken.substring(0, 255);
                            outlookSettings.Refresh_Token_2__c = refreshToken.substring(255);
                        } else {
                            outlookSettings.Refresh_Token_1__c = refreshToken;
                            outlookSettings.Refresh_Token_2__c = '';
                        }
                    } else {
                        outlookSettings.put(apiName, stringFieldMap.get(apiName));
                    }
                }
    
                upsert as user outlookSettings;

            } else if (integrationType == 'Facebook') {
                FacebookConfig__c facebookSettings = FacebookConfig__c.getOrgDefaults();
                if (facebookSettings == null) {
                    facebookSettings = new FacebookConfig__c();
                    facebookSettings.SetupOwnerId = UserInfo.getOrganizationId();
                }
    
                for (String apiName : stringFieldMap.keySet()) {
                    facebookSettings.put(apiName, stringFieldMap.get(apiName));
                }
    
                upsert as user facebookSettings;
    
            } else if (integrationType == 'Instagram') {
                IG_Configuration__c instagramSettings = IG_Configuration__c.getOrgDefaults();
                if (instagramSettings == null) {
                    instagramSettings = new IG_Configuration__c();
                    instagramSettings.SetupOwnerId = UserInfo.getOrganizationId();
                }
    
                for (String apiName : stringFieldMap.keySet()) {
                    instagramSettings.put(apiName, stringFieldMap.get(apiName));
                }
    
                upsert as user instagramSettings;

            } else if (integrationType == 'Google') {
                GoogleLeadConfig__c googleSettings = GoogleLeadConfig__c.getOrgDefaults();
                if (googleSettings == null) {
                    googleSettings = new GoogleLeadConfig__c();
                    googleSettings.SetupOwnerId = UserInfo.getOrganizationId();
                }
    
                for (String apiName : stringFieldMap.keySet()) {
                    googleSettings.put(apiName, stringFieldMap.get(apiName));
                }
    
                upsert as user googleSettings;

            } else if (integrationType == 'Meta') {
                MetaLeadConfig__c metaSettings = MetaLeadConfig__c.getOrgDefaults();
                if (metaSettings == null) {
                    metaSettings = new MetaLeadConfig__c();
                    metaSettings.SetupOwnerId = UserInfo.getOrganizationId();
                }
    
                for (String apiName : stringFieldMap.keySet()) {
                    metaSettings.put(apiName, stringFieldMap.get(apiName));
                }
    
                upsert as user metaSettings;

            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'IntegrationPopupController', 'saveSettings', 'Error while saving settings.');
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
                List<AWS_Config__c> awsCredential = [SELECT Id, AWS_Secret_Access_Key__c, MVEX__AWS_Access_Key__c, S3_Bucket_Name__c, S3_Region_Name__c FROM AWS_Config__c WHERE SetupOwnerId = :UserInfo.getOrganizationId() WITH USER_MODE LIMIT 1];
                if (awsCredential.size() > 0) {
                    Map<String, Object> awsData = new Map<String, Object>{
                        'Id' => awsCredential[0].Id,
                        'MVEX__S3_Bucket_Name__c' => awsCredential[0].S3_Bucket_Name__c,
                        'MVEX__S3_Region_Name__c' => awsCredential[0].S3_Region_Name__c,
                        'MVEX__AWS_Access_Key__c' => awsCredential[0].MVEX__AWS_Access_Key__c != null ? '[SENSITIVE_DATA_MASKED]' : awsCredential[0].MVEX__AWS_Access_Key__c,
                        'MVEX__AWS_Secret_Access_Key__c' => awsCredential[0].AWS_Secret_Access_Key__c != null ? '[SENSITIVE_DATA_MASKED]' : awsCredential[0].AWS_Secret_Access_Key__c
                    };
                    result.objectData = awsData;
                } else {
                    result.objectData = new AWS_Config__c();
                }
            } else if (integrationType == 'Gmail') {
                List<GmailConfig__c> gmailCredential = [SELECT Id, Client_ID__c, Client_Secret__c, Refresh_Token__c, Redirect_URI__c FROM GmailConfig__c WHERE SetupOwnerId = :UserInfo.getOrganizationId() WITH USER_MODE LIMIT 1];
                if (gmailCredential.size() > 0) {
                    Map<String, Object> gmailData = new Map<String, Object>{
                        'Id' => gmailCredential[0].Id,
                        'MVEX__Client_ID__c' => gmailCredential[0].Client_ID__c != null ? '[SENSITIVE_DATA_MASKED]' : gmailCredential[0].Client_ID__c,
                        'MVEX__Client_Secret__c' => gmailCredential[0].Client_Secret__c != null ? '[SENSITIVE_DATA_MASKED]' : gmailCredential[0].Client_Secret__c,
                        'MVEX__Refresh_Token__c' => gmailCredential[0].Refresh_Token__c != null ? '[SENSITIVE_DATA_MASKED]' : gmailCredential[0].Refresh_Token__c,
                        'MVEX__Redirect_URI__c' => gmailCredential[0].Redirect_URI__c
                    };
                    result.objectData = gmailData;
                    result.siteUrl = getSiteUrl(gmailCredential[0].Redirect_URI__c, 'Gmail');
                } else {
                    result.objectData = new GmailConfig__c();
                }
            } else if (integrationType == 'Outlook') {
                List<OutlookConfig__c> outlookCredential = [SELECT Id, Client_ID__c, Client_Secret__c, Refresh_Token_1__c, Refresh_Token_2__c, Redirect_URI__c FROM OutlookConfig__c WHERE SetupOwnerId = :UserInfo.getOrganizationId() WITH USER_MODE LIMIT 1];
                if (outlookCredential.size() > 0) {
                    Map<String, Object> outlookData = new Map<String, Object>{
                        'Id' => outlookCredential[0].Id,
                        'MVEX__Client_ID__c' => outlookCredential[0].Client_ID__c != null ? '[SENSITIVE_DATA_MASKED]' : outlookCredential[0].Client_ID__c,
                        'MVEX__Client_Secret__c' => outlookCredential[0].Client_Secret__c != null ? '[SENSITIVE_DATA_MASKED]' : outlookCredential[0].Client_Secret__c,
                        'MVEX__Refresh_Token__c' => outlookCredential[0].Refresh_Token_1__c != null && outlookCredential[0].Refresh_Token_2__c != null ? '[SENSITIVE_DATA_MASKED]' : outlookCredential[0].Refresh_Token_1__c,
                        'MVEX__Redirect_URI__c' => outlookCredential[0].Redirect_URI__c
                    };
                    result.objectData = outlookData;
                    result.siteUrl = getSiteUrl(outlookCredential[0].Redirect_URI__c, 'Outlook');
                } else {
                    result.objectData = new OutlookConfig__c();
                }
            } else if (integrationType == 'Instagram') {
                List<IG_Configuration__c> instagramCredential = [SELECT Id, AccessToken__c, ClientId__c, ClientSecret__c, Long_Access_Token__c, Redirect_URI__c, User_Id__c FROM IG_Configuration__c WHERE SetupOwnerId = :UserInfo.getOrganizationId() WITH USER_MODE LIMIT 1];
                if (instagramCredential.size() > 0) {
                    Map<String, Object> instagramData = new Map<String, Object>{
                        'Id' => instagramCredential[0].Id,
                        'MVEX__Access_Token__c' => instagramCredential[0].AccessToken__c != null ? '[SENSITIVE_DATA_MASKED]' : instagramCredential[0].AccessToken__c,
                        'MVEX__ClientId__c' => instagramCredential[0].ClientId__c != null ? '[SENSITIVE_DATA_MASKED]' : instagramCredential[0].ClientId__c,
                        'MVEX__ClientSecret__c' => instagramCredential[0].ClientSecret__c != null ? '[SENSITIVE_DATA_MASKED]' : instagramCredential[0].ClientSecret__c,
                        'MVEX__Long_Access_Token__c' => instagramCredential[0].Long_Access_Token__c != null ? '[SENSITIVE_DATA_MASKED]' : instagramCredential[0].Long_Access_Token__c,
                        'MVEX__Redirect_URI__c' => instagramCredential[0].Redirect_URI__c,
                        'MVEX__User_Id__c' => instagramCredential[0].User_Id__c
                    };
                    result.objectData = instagramData;
                    result.siteUrl = getSiteUrl(instagramCredential[0].Redirect_URI__c, 'Instagram');
                } else {
                    result.objectData = new IG_Configuration__c();
                }
            } else if (integrationType == 'Google'){
                result.objectData = GoogleLeadConfig__c.getOrgDefaults();
            } else if (integrationType == 'Meta'){
                List<MetaLeadConfig__c> metaPageCredential = [SELECT Id, ACCESS_TOKEN__c, APP_SECRET__c, VERIFY_TOKEN__c, APP_ID__c, FB_API_VERSION__c, META_PAGE_ENDPOINT__c FROM MetaLeadConfig__c WHERE SetupOwnerId = :UserInfo.getOrganizationId() WITH USER_MODE LIMIT 1];
                if (metaPageCredential.size() > 0) {
                    Map<String, Object> metaPageData = new Map<String, Object>{
                        'Id' => metaPageCredential[0].Id,
                        'MVEX__APP_ID__c' => metaPageCredential[0].APP_ID__c,
                        'MVEX__FB_API_VERSION__c' => metaPageCredential[0].FB_API_VERSION__c,
                        'MVEX__META_PAGE_ENDPOINT__c' => metaPageCredential[0].META_PAGE_ENDPOINT__c,
                        'MVEX__ACCESS_TOKEN__c' => metaPageCredential[0].ACCESS_TOKEN__c != null ? '[SENSITIVE_DATA_MASKED]' : metaPageCredential[0].ACCESS_TOKEN__c,
                        'MVEX__APP_SECRET__c' => metaPageCredential[0].APP_SECRET__c != null ? '[SENSITIVE_DATA_MASKED]' : metaPageCredential[0].APP_SECRET__c,
                        'MVEX__VERIFY_TOKEN__c' => metaPageCredential[0].VERIFY_TOKEN__c != null ? '[SENSITIVE_DATA_MASKED]' : metaPageCredential[0].VERIFY_TOKEN__c
                    };
                    result.objectData = metaPageData;
                } else {
                    result.objectData = new MetaLeadConfig__c();
                }
            } else {
                throw new IllegalArgumentException('Invalid integration type: ' + integrationType);
            }
            return result;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'IntegrationPopupController', 'getSettings', 'Error while getting settings.');
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
                    when 'Outlook' {
                        integraName = 'MVEX__AzureADLoc';
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
            ErrorHandler.insertErrorData(e, 'IntegrationPopupController', 'getSiteUrl', 'Error while getting site url.');
        }

        return null;
    }

    /**
    * Method Name : saveCustomTempData
    * @param clientId : String to stored the client id.
    * @param clientSecret : String to stored the client secret.
    * @param redirectURI : String to stored the redirect URI.
    * @description : Method to save custom temp data.
    */
    @AuraEnabled
    public static void saveCustomTempData(String clientId, String clientSecret, String redirectURI){
        try {
            TempData__c tempDataSettings = TempData__c.getOrgDefaults();
            if (tempDataSettings == null) {
                tempDataSettings = new TempData__c();
                tempDataSettings.SetupOwnerId = UserInfo.getOrganizationId();
            }
            tempDataSettings.Client_ID__c = clientId;
            tempDataSettings.Client_Secret__c = clientSecret;
            tempDataSettings.Redirect_URI__c = redirectURI;

            upsert as user tempDataSettings;

        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'IntegrationPopupController', 'saveCustomTempData', 'Error while saving custom temp data.');
        }
    }

    /**
    * Class Name : SocialMediaDataWrapper
    * @description : Wrapper class to store social media data.
    */
    public class SocialMediaDataWrapper {
        @AuraEnabled public Boolean isValid = false;
        @AuraEnabled public Object integrationData;
        @AuraEnabled public String integrationName;
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
            List<IG_Configuration__c> instagramCredential = [SELECT Id, AccessToken__c, ClientId__c, ClientSecret__c, Long_Access_Token__c, Redirect_URI__c, User_Id__c, CreatedDate, LastModifiedDate FROM IG_Configuration__c WHERE SetupOwnerId = :UserInfo.getOrganizationId() WITH USER_MODE LIMIT 1];

            SocialMediaDataWrapper instagramWrapper = new SocialMediaDataWrapper();
            instagramWrapper.integrationName = 'Instagram';
            if (instagramCredential.size() > 0) {
                Map<String, Object> instagramData = new Map<String, Object>{
                    'Id' => instagramCredential[0].Id,
                    'RedirectURI' => instagramCredential[0].Redirect_URI__c,
                    'UserId' => instagramCredential[0].User_Id__c,
                    'CreatedDate' => instagramCredential[0].CreatedDate,
                    'LastModifiedDate' => instagramCredential[0].LastModifiedDate
                };
                instagramWrapper.integrationData = instagramData;
                instagramWrapper.isValid =  instagramCredential[0].ClientId__c != null && instagramCredential[0].ClientSecret__c != null && instagramCredential[0].Redirect_URI__c != null && instagramCredential[0].AccessToken__c != null;
            } else {
                instagramWrapper.integrationData = new IG_Configuration__c();
                instagramWrapper.isValid = false;
            }
            wrapperList.add(instagramWrapper);

            return wrapperList;

        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'IntegrationPopupController', 'getSocialMediaData', 'Error while getting social media data.');
            return null;
        }
    }

    /**
    * Method Name : get
    * @return List<GoogleAdsDataWrapper> : Wrapper class to store social media data.
    * @description : Method to get social media data.
    */
    @AuraEnabled
    public static List<FieldWrapperData> getGoogleData(String integrationName) {
        List<FieldWrapperData> wrapperList = new List<FieldWrapperData>();

        try {
            if(integrationName == 'GoogleAds'){
                GoogleLeadConfig__c googleAdsCredential = GoogleLeadConfig__c.getOrgDefaults();
    
                FieldWrapperData googleAdsWrapper = new FieldWrapperData();
                googleAdsWrapper.integrationName = 'GoogleAds';
                googleAdsWrapper.isValid = googleAdsCredential.Google_lead_Form_Secret__c != null && googleAdsCredential.Google_Ads_Endpoint__c != null;
                googleAdsWrapper.integrationData = googleAdsCredential;
                wrapperList.add(googleAdsWrapper);
            } else {
                List<MetaLeadConfig__c> metaPageCredential = [SELECT Id, ACCESS_TOKEN__c, APP_ID__c, APP_SECRET__c, FB_API_VERSION__c, META_PAGE_ENDPOINT__c, CreatedDate, LastModifiedDate FROM MetaLeadConfig__c WHERE SetupOwnerId = :UserInfo.getOrganizationId() WITH USER_MODE LIMIT 1];
                
                FieldWrapperData metaWrapper = new FieldWrapperData();
                metaWrapper.integrationName = 'Meta';
                if (metaPageCredential.size() > 0) {
                    Map<String, Object> outlookData = new Map<String, Object>{
                        'Id' => metaPageCredential[0].Id,
                        'APPID' => metaPageCredential[0].APP_ID__c,
                        'FBAPIVERSION' => metaPageCredential[0].FB_API_VERSION__c,
                        'METAPAGEENDPOINT' => metaPageCredential[0].META_PAGE_ENDPOINT__c,
                        'CreatedDate' => metaPageCredential[0].CreatedDate,
                        'LastModifiedDate' => metaPageCredential[0].LastModifiedDate
                    };
                    metaWrapper.integrationData = outlookData;
                    metaWrapper.isValid = metaPageCredential[0].ACCESS_TOKEN__c != null && metaPageCredential[0].APP_SECRET__c != null && metaPageCredential[0].FB_API_VERSION__c != null && metaPageCredential[0].META_PAGE_ENDPOINT__c != null;
                } else {
                    metaWrapper.integrationData = new MetaLeadConfig__c();
                    metaWrapper.isValid = false;
                }
                wrapperList.add(metaWrapper);
            }

            return wrapperList;

        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'IntegrationPopupController', 'getSocialMediaData', 'Error while getting social media data.');
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
            List<AWS_Config__c> awsCredential = [SELECT Id, AWS_Access_Key__c, AWS_Secret_Access_Key__c, S3_Bucket_Name__c, S3_Region_Name__c, CreatedDate, LastModifiedDate FROM AWS_Config__c WHERE SetupOwnerId = :UserInfo.getOrganizationId() WITH USER_MODE LIMIT 1];
            List<GmailConfig__c> gmailCredential = [SELECT Id, Client_ID__c, Client_Secret__c, Redirect_URI__c, Refresh_Token__c, CreatedDate, LastModifiedDate FROM GmailConfig__c WHERE SetupOwnerId = :UserInfo.getOrganizationId() WITH USER_MODE LIMIT 1];
            List<OutlookConfig__c> outlookCredential = [SELECT Id, Client_ID__c, Client_Secret__c, Redirect_URI__c, Refresh_Token_1__c, Refresh_Token_2__c, CreatedDate, LastModifiedDate FROM OutlookConfig__c WHERE SetupOwnerId = :UserInfo.getOrganizationId() WITH USER_MODE LIMIT 1];

            // Outlook Integration
            FieldWrapperData outlookWrapper = new FieldWrapperData();
            outlookWrapper.integrationName = 'Outlook';
            if (outlookCredential.size() > 0) {
                Map<String, Object> outlookData = new Map<String, Object>{
                    'Id' => outlookCredential[0].Id,
                    'RedirectURI' => outlookCredential[0].Redirect_URI__c,
                    'CreatedDate' => outlookCredential[0].CreatedDate,
                    'LastModifiedDate' => outlookCredential[0].LastModifiedDate
                };
                outlookWrapper.integrationData = outlookData;
                outlookWrapper.isValid = outlookCredential[0].Client_ID__c != null && outlookCredential[0].Client_Secret__c != null && outlookCredential[0].Redirect_URI__c != null && outlookCredential[0].Refresh_Token_1__c != null;
            } else {
                outlookWrapper.integrationData = new OutlookConfig__c();
                outlookWrapper.isValid = false;
            }
            wrapperList.add(outlookWrapper);

            // Gmail Integration
            FieldWrapperData gmailWrapper = new FieldWrapperData();
            gmailWrapper.integrationName = 'Gmail';
            if (gmailCredential.size() > 0) {
                Map<String, Object> gmailData = new Map<String, Object>{
                    'Id' => gmailCredential[0].Id,
                    'RedirectURI' => gmailCredential[0].Redirect_URI__c,
                    'CreatedDate' => gmailCredential[0].CreatedDate,
                    'LastModifiedDate' => gmailCredential[0].LastModifiedDate
                };
                gmailWrapper.integrationData = gmailData;
                gmailWrapper.isValid = gmailCredential[0].Client_ID__c != null && gmailCredential[0].Client_Secret__c != null && gmailCredential[0].Redirect_URI__c != null && gmailCredential[0].Refresh_Token__c != null;
            } else {
                gmailWrapper.integrationData = new GmailConfig__c();
                gmailWrapper.isValid = false;
            }
            wrapperList.add(gmailWrapper);

            FieldWrapperData awsWrapper = new FieldWrapperData();
            awsWrapper.integrationName = 'AWS';
            if (gmailCredential.size() > 0) {
                Map<String, Object> awsData = new Map<String, Object>{
                    'Id' => awsCredential[0].Id,
                    'S3BucketName' => awsCredential[0].S3_Bucket_Name__c,
                    'S3RegionName' => awsCredential[0].S3_Region_Name__c,
                    'CreatedDate' => awsCredential[0].CreatedDate,
                    'LastModifiedDate' => awsCredential[0].LastModifiedDate
                };
                awsWrapper.integrationData = awsData;
                awsWrapper.isValid = awsCredential[0].AWS_Access_Key__c != null && awsCredential[0].AWS_Secret_Access_Key__c != null && awsCredential[0].S3_Bucket_Name__c != null && awsCredential[0].S3_Region_Name__c != null;
            } else {
                awsWrapper.integrationData = new AWS_Config__c();
                awsWrapper.isValid = false;
            }
            wrapperList.add(awsWrapper);

            return wrapperList;

        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'IntegrationPopupController', 'getIntegrationDetails', 'Error while getting integration details.');
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
    public static String revokeGmailAccess(String recordId) {
        String status;
        try {
            List<GmailConfig__c> gmailCredential = [SELECT Id, Client_ID__c, Client_Secret__c, Redirect_URI__c, Refresh_Token__c, CreatedDate, LastModifiedDate FROM GmailConfig__c WHERE Id = :recordId WITH USER_MODE LIMIT 1];
            if (gmailCredential.size() == 0) {
                return 'Gmail configuration not found.';
            }
            // Initialize the HTTP request
            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://oauth2.googleapis.com/revoke');
            req.setMethod('POST');
            String refreshToken = gmailCredential[0].Refresh_Token__c;
            // Set the parameters for the request
            String requestBody = 'token=' + refreshToken;
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            req.setBody(requestBody);
            
            // Send the request
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            // Check the response
            if (res.getStatusCode() == 200) {
                status = deleteGmailConfig(recordId);
            } else {
                status = res.getBody();
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'IntegrationPopupController', 'revokeGmailAccess', 'Error while revoking gmail access.');
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
            delete as user new GmailConfig__c(Id = recordId);
            return 'success';
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'IntegrationPopupController', 'deleteGmailConfig', 'Error while deleting gmail config.');
            return e.getMessage();
        }
    }

    /**
    * Method Name : revokeOutlookAccess
    * @param refreshToken : String to stored the refresh token.
    * @param recordId : String to stored the record id.
    * @return String : Status of revoke access.
    * @description : Method to revoke outlook access.
    */
    @AuraEnabled
    public static String revokeOutlookAccess(String recordId) {
        String status;
        try {
            List<OutlookConfig__c> outlookCredential = [SELECT Id, Client_ID__c, Client_Secret__c, Redirect_URI__c, Refresh_Token_1__c, Refresh_Token_2__c, CreatedDate, LastModifiedDate FROM OutlookConfig__c WHERE Id = :recordId WITH USER_MODE LIMIT 1];
            if (outlookCredential.size() == 0) {
                return 'Outlook configuration not found.';
            }
            String refreshToken = outlookCredential[0].Refresh_Token_1__c + outlookCredential[0].Refresh_Token_2__c;
            // Initialize the HTTP request
            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://login.microsoftonline.com/common/oauth2/v2.0/logout');
            req.setMethod('POST');
            
            // Set the parameters for the request
            String requestBody = 'token=' + refreshToken;
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            req.setBody(requestBody);
            
            // Send the request
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            // Check the response
            if (res.getStatusCode() == 200) {
                status = deleteOutlookMetadata(recordId);
            } else {
                status = res.getBody();
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'IntegrationPopupController', 'revokeOutlookAccess', 'Error while revoking outlook access.');
            status = e.getMessage();
        }

        return status;
    }

    /**
    * Method Name : deleteOutlookMetadata
    * @param recordId : String to stored the record id.
    * @return String : Status of revoke access.
    * @description : Method to delete outlook config.
    */
    public static String deleteOutlookMetadata(String recordId){
        try {
            delete as user new OutlookConfig__c(Id = recordId);
            return 'success';
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'IntegrationPopupController', 'deleteOutlookMetadata', 'Error while deleting outlook metadata.');
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
            delete as user new AWS_Config__c(Id = recordId);
            return 'success';
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'IntegrationPopupController', 'revokeAWSAccess', 'Error while revoking aws access.');
            return e.getMessage();
        }
    }

    /**
    * Method Name : revokeWhatsappAccess
    * @param recordId : String to stored the record id.
    * @return String : Status of revoke access.
    * @description : Method to revoke whatsapp access.
    */
    @AuraEnabled
    public static string revokeWhatsappAccess(String recordId){
        try {
            delete as user new WhatsAppConfig__c(Id = recordId);
            return 'success';
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'IntegrationPopupController', 'revokeWhatsappAccess', 'Error while revoking whatsapp access.');
            return e.getMessage();
        }
    }

    @AuraEnabled
    public static string revokeInstagramAccess(String recordId){
        try {
            delete as user new IG_Configuration__c(Id = recordId);
            return 'success';
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'IntegrationPopupController', 'revokeInstagramAccess', 'Error while revoking Instagram access.');
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
                delete as user new GoogleLeadConfig__c(Id = recordId);
                return 'success';
            } else if(integrationType == 'Meta'){
                delete as user new MetaLeadConfig__c(Id = recordId);
                return 'success';
            } else {
                return 'No integrationType match found';
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'IntegrationPopupController', 'revokeWhatsappAccess', 'Error while revoking whatsapp access.');
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
            ErrorHandler.insertErrorData(e, 'IntegrationPopupController', 'siteData', 'Error while getting site data.');
            return null;
        }
    }
}