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
                    // FIX: Removed the check that only saved Refresh Token. 
                    // Now it saves ClientID, Secret, and RedirectURI as well.
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
                result.objectData = AWS_Config__c.getOrgDefaults();
            } else if (integrationType == 'Gmail') {
                GmailConfig__c settings = GmailConfig__c.getOrgDefaults();
                
                // Fetch Credentials from Custom Metadata
                List<MVEX__recordManagerConfig__mdt> mdtList = [SELECT MVEX__FieldsData__c FROM MVEX__recordManagerConfig__mdt LIMIT 1];
                
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
            } else if (integrationType == 'Outlook') {
                OutlookConfig__c outlookSettings = OutlookConfig__c.getOrgDefaults();
                result.objectData = outlookSettings;
                result.siteUrl = getSiteUrl(outlookSettings.Redirect_URI__c, 'Outlook');
            } else if (integrationType == 'Instagram') {
                IG_Configuration__c instaSettings = IG_Configuration__c.getOrgDefaults();
                result.objectData = instaSettings;
                result.siteUrl = getSiteUrl(instaSettings.Redirect_URI__c, 'Instagram');
            } else if (integrationType == 'Google'){
                result.objectData = GoogleLeadConfig__c.getOrgDefaults();
            } else if (integrationType == 'Meta'){
                result.objectData = MetaLeadConfig__c.getOrgDefaults();
            } else {
                throw new IllegalArgumentException('Invalid integration type: ' + integrationType);
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
            ErrorHandler.insertErrordata(e, 'IntegrationPopupController', 'getSiteUrl', 'Error while getting site url.');
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
            ErrorHandler.insertErrordata(e, 'IntegrationPopupController', 'saveCustomTempData', 'Error while saving custom temp data.');
        }
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
            IG_Configuration__c instagramCredential = IG_Configuration__c.getOrgDefaults();

            SocialMediaDataWrapper instagramWrapper = new SocialMediaDataWrapper();
            instagramWrapper.integraName = 'Instagram';
            instagramWrapper.isValid = instagramCredential.ClientId__c != null && instagramCredential.ClientSecret__c != null;
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
                MetaLeadConfig__c metaPageCredential = MetaLeadConfig__c.getOrgDefaults();
                FieldWrapperData metaWrapper = new FieldWrapperData();
                metaWrapper.integrationName = 'Meta';
                metaWrapper.isValid = metaPageCredential.ACCESS_TOKEN__c != null && metaPageCredential.APP_SECRET__c != null;
                metaWrapper.integrationData = metaPageCredential;
                wrapperList.add(metaWrapper);
            }

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
            AWS_Config__c awsCredential = AWS_Config__c.getOrgDefaults();
            GmailConfig__c gmailCredential = GmailConfig__c.getOrgDefaults();
            OutlookConfig__c outlookCredential = OutlookConfig__c.getOrgDefaults();
            IG_Configuration__c instagramCredential = IG_Configuration__c.getOrgDefaults();

            // Outlook Integration
            FieldWrapperData outlookWrapper = new FieldWrapperData();
            outlookWrapper.integrationName = 'Outlook';
            outlookWrapper.integrationData = outlookCredential;
            outlookWrapper.isValid = outlookCredential.Client_ID__c != null && outlookCredential.Client_Secret__c != null && outlookCredential.Redirect_URI__c != null && outlookCredential.Refresh_Token_1__c != null;
            wrapperList.add(outlookWrapper);

            // Gmail Integration
            FieldWrapperData gmailWrapper = new FieldWrapperData();
            gmailWrapper.integrationName = 'Gmail';
            gmailWrapper.integrationData = gmailCredential;
            gmailWrapper.isValid = gmailCredential.Client_ID__c != null && gmailCredential.Client_Secret__c != null && gmailCredential.Redirect_URI__c != null && gmailCredential.Refresh_Token__c != null;
            wrapperList.add(gmailWrapper);

            FieldWrapperData awsWrapper = new FieldWrapperData();
            awsWrapper.integrationName = 'AWS';
            awsWrapper.integrationData = awsCredential;
            awsWrapper.isValid = awsCredential.AWS_Access_Key__c != null && awsCredential.AWS_Secret_Access_Key__c != null && awsCredential.S3_Bucket_Name__c != null && awsCredential.S3_Region_Name__c != null;
            wrapperList.add(awsWrapper);

            FieldWrapperData instagramWrapper = new FieldWrapperData();
            instagramWrapper.integrationName = 'Instagram';
            instagramWrapper.isValid = instagramCredential.ClientId__c != null && instagramCredential.ClientSecret__c != null;
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
            if (res.getStatusCode() == 200) {
                status = deleteGmailConfig(recordId);
            } else {
                status = res.getBody();
            }
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
            delete as user new GmailConfig__c(Id = recordId);
            return 'success';
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'IntegrationPopupController', 'deleteGmailConfig', 'Error while deleting gmail config.');
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
    public static String revokeOutlookAccess(String refreshToken, String recordId) {
        String status;
        try {
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
            ErrorHandler.insertErrordata(e, 'IntegrationPopupController', 'revokeOutlookAccess', 'Error while revoking outlook access.');
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
            ErrorHandler.insertErrordata(e, 'IntegrationPopupController', 'deleteOutlookMetadata', 'Error while deleting outlook metadata.');
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
            ErrorHandler.insertErrordata(e, 'IntegrationPopupController', 'revokeAWSAccess', 'Error while revoking aws access.');
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
            ErrorHandler.insertErrordata(e, 'IntegrationPopupController', 'revokeWhatsappAccess', 'Error while revoking whatsapp access.');
            return e.getMessage();
        }
    }

    @AuraEnabled
    public static string revokeInstagramAccess(String recordId){
        try {
            delete as user new IG_Configuration__c(Id = recordId);
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
                delete as user new GoogleLeadConfig__c(Id = recordId);
                return 'success';
            } else if(integrationType == 'Meta'){
                delete as user new MetaLeadConfig__c(Id = recordId);
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
}