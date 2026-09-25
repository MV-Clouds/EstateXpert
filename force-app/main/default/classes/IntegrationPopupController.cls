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
    public static String GMAILENDPOINT = System.label.Google_Endpoint;
    public static String AWSS3ENDPOINT = System.label.AWS_S3_ENDPONT;
    public static String gmailEndpoint = System.label.Gmail_Sending_Endpoint;
    public static final String instagramEndpoint = System.label.InstagramEndPoint;

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
    * Method Name : validateAWSCredentials
    * @param accessKey : String - AWS Access Key
    * @param secretKey : String - AWS Secret Access Key
    * @param bucketName : String - AWS S3 Bucket Name
    * @param region : String - AWS S3 Region Name
    * @return String : 'SUCCESS' if valid, otherwise user-friendly error message.
    * @description : Validates AWS S3 credentials and bucket accessibility via server-side SigV4 callout.
    */
    @AuraEnabled
    public static String validateAWSCredentials(String accessKey, String secretKey, String bucketName, String region) {
        String trimmedKey = String.isNotBlank(accessKey) ? accessKey.trim() : '';
        String trimmedSecret = String.isNotBlank(secretKey) ? secretKey.trim() : '';
        String trimmedBucket = String.isNotBlank(bucketName) ? bucketName.trim() : '';
        String trimmedRegion = String.isNotBlank(region) ? region.trim().toLowerCase() : '';

        if (String.isBlank(trimmedKey)) {
            return 'AWS Access Key is required.';
        }
        if (String.isBlank(trimmedSecret)) {
            return 'AWS Secret Access Key is required.';
        }
        if (String.isBlank(trimmedBucket)) {
            return 'AWS S3 Bucket Name is required.';
        }
        if (String.isBlank(trimmedRegion)) {
            return 'AWS S3 Region Name is required.';
        }

        try {
            // First attempt: Virtual-hosted style (standard AWS S3 format)
            String host = (trimmedRegion == 'us-east-1') ? 
                          (trimmedBucket + '.s3.amazonaws.com') : 
                          (trimmedBucket + '.s3.' + trimmedRegion + '.amazonaws.com');
            String endpoint = 'https://' + host + '/?max-keys=0';
            
            HttpResponse res = sendS3ValidationRequest(trimmedKey, trimmedSecret, host, '/', 'max-keys=0', endpoint, trimmedRegion);
            return parseS3Response(res, trimmedRegion);
            
        } catch (System.CalloutException ce) {
            // If virtual-hosted endpoint is not in Remote Site Settings, fallback to path-style on s3.amazonaws.com
            if (ce.getMessage().contains('Unauthorized endpoint')) {
                try {
                    String host = 's3.amazonaws.com';
                    String endpoint = AWSS3ENDPOINT + trimmedBucket + '?max-keys=0';
                    HttpResponse res = sendS3ValidationRequest(trimmedKey, trimmedSecret, host, '/' + trimmedBucket, 'max-keys=0', endpoint, trimmedRegion);
                    return parseS3Response(res, trimmedRegion);
                } catch (Exception fallbackEx) {
                    String hostEndpoint = (trimmedRegion == 'us-east-1') ? (trimmedBucket + '.s3.amazonaws.com') : (trimmedBucket + '.s3.' + trimmedRegion + '.amazonaws.com');
                    return 'Unauthorized endpoint. Please add https://' + hostEndpoint;
                }
            }
            return 'Callout Error: ' + ce.getMessage();
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'IntegrationPopupController', 'validateAWSCredentials', 'Error while validating AWS credentials.');
            return 'Validation Error: ' + e.getMessage();
        }
    }

    private static HttpResponse sendS3ValidationRequest(String accessKey, String secretKey, String host, String canonicalUri, String canonicalQueryString, String endpoint, String region) {
        String service = 's3';
        String algorithm = 'AWS4-HMAC-SHA256';

        Datetime now = Datetime.now();
        String amzDate = now.formatGMT('yyyyMMdd\'T\'HHmmss\'Z\'');
        String dateStamp = now.formatGMT('yyyyMMdd');

        String payloadHash = EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf('')));

        String canonicalHeaders = 'host:' + host + '\n' +
                                  'x-amz-content-sha256:' + payloadHash + '\n' +
                                  'x-amz-date:' + amzDate + '\n';
        String signedHeaders = 'host;x-amz-content-sha256;x-amz-date';

        String canonicalRequest = 'GET\n' +
                                  canonicalUri + '\n' +
                                  canonicalQueryString + '\n' +
                                  canonicalHeaders + '\n' +
                                  signedHeaders + '\n' +
                                  payloadHash;

        String credentialScope = dateStamp + '/' + region + '/' + service + '/aws4_request';
        String stringToSign = algorithm + '\n' +
                              amzDate + '\n' +
                              credentialScope + '\n' +
                              EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf(canonicalRequest)));

        Blob kDate = Crypto.generateMac('HmacSHA256', Blob.valueOf(dateStamp), Blob.valueOf('AWS4' + secretKey));
        Blob kRegion = Crypto.generateMac('HmacSHA256', Blob.valueOf(region), kDate);
        Blob kService = Crypto.generateMac('HmacSHA256', Blob.valueOf(service), kRegion);
        Blob kSigning = Crypto.generateMac('HmacSHA256', Blob.valueOf('aws4_request'), kService);

        String signature = EncodingUtil.convertToHex(Crypto.generateMac('HmacSHA256', Blob.valueOf(stringToSign), kSigning));

        String authorizationHeader = algorithm + ' Credential=' + accessKey + '/' + credentialScope + 
                                     ', SignedHeaders=' + signedHeaders + ', Signature=' + signature;

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setHeader('Host', host);
        req.setHeader('x-amz-date', amzDate);
        req.setHeader('x-amz-content-sha256', payloadHash);
        req.setHeader('Authorization', authorizationHeader);
        req.setTimeout(20000);

        Http http = new Http();
        return http.send(req);
    }

    private static String parseS3Response(HttpResponse res, String region) {
        if (res.getStatusCode() == 200) {
            return 'SUCCESS';
        }

        String body = res.getBody();
        String errorCode = '';
        String errorMessage = '';
        if (String.isNotBlank(body)) {
            Matcher codeMatcher = Pattern.compile('<Code>(.*?)</Code>').matcher(body);
            if (codeMatcher.find()) {
                errorCode = codeMatcher.group(1);
            }
            Matcher msgMatcher = Pattern.compile('<Message>(.*?)</Message>').matcher(body);
            if (msgMatcher.find()) {
                errorMessage = msgMatcher.group(1);
            }
        }

        if (errorCode == 'InvalidAccessKeyId') {
            return 'Invalid Access Key: The AWS Access Key ID provided does not exist.';
        } else if (errorCode == 'SignatureDoesNotMatch') {
            return 'Invalid Secret Access Key: Signature does not match. Please verify your Secret Access Key.';
        } else if (errorCode == 'NoSuchBucket') {
            return 'Bucket Not Found: The specified S3 bucket does not exist.';
        } else if (errorCode == 'AccessDenied') {
            return 'Access Denied: The provided credentials do not have permission to access the S3 bucket.';
        } else if (errorCode == 'PermanentRedirect' || errorCode == 'AuthorizationHeaderMalformed' || res.getStatusCode() == 301) {
            String bucketRegion = res.getHeader('x-amz-bucket-region');
            if (String.isNotBlank(bucketRegion)) {
                return 'Region Mismatch: The bucket is located in region "' + bucketRegion + '", but you specified "' + region + '".';
            }
            return 'Region Mismatch: The specified region does not match the bucket region.';
        } else if (String.isNotBlank(errorMessage)) {
            return errorMessage;
        } else {
            return 'AWS validation failed with status code ' + res.getStatusCode() + ' (' + res.getStatus() + ').';
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
            gmailWrapper.isValid = gmailCredential != null && gmailCredential.MVEX__Client_ID__c != null && gmailCredential.MVEX__Client_Secret__c != null && gmailCredential.MVEX__Redirect_URI__c != null && gmailCredential.MVEX__Refresh_Token__c != null;
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
            String gmailRevokeEndpoint =  GMAILENDPOINT + 'revoke';
            // Initialize the HTTP request
            HttpRequest req = new HttpRequest();
            req.setEndpoint(gmailRevokeEndpoint);
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
            if (integrationType == 'Gmail') {
                MVEX__GmailConfig__c settings = MVEX__GmailConfig__c.getOrgDefaults();

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
                result.siteUrl = settings.MVEX__Redirect_URI__c;
            } else if (integrationType == 'Instagram') {
                MVEX__IG_Configuration__c instaSettings = MVEX__IG_Configuration__c.getOrgDefaults();

                List<MVEX__recordManagerConfig__mdt> mdtList = [SELECT MVEX__FieldsData__c FROM MVEX__recordManagerConfig__mdt where MVEX__Integration_Type__c = :integrationType LIMIT 1];
                
                if(!mdtList.isEmpty() && mdtList[0].MVEX__FieldsData__c != null) {
                    String[] parts = mdtList[0].MVEX__FieldsData__c.split(';');
                    if(parts.size() >= 3) {
                        instaSettings.MVEX__ClientId__c = parts[0];
                        instaSettings.MVEX__ClientSecret__c = parts[1];
                        instaSettings.MVEX__Redirect_URI__c = parts[2];
                    }
                }

                result.objectData = instaSettings;
                result.siteUrl = instaSettings.MVEX__Redirect_URI__c;
            }
            return result;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'IntegrationPopupController', 'getSettings', 'Error while getting settings.');
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
                // Return stub identifier so the LWC can save it during tests
                if (integrationType == 'Gmail') {
                    return 'SUCCESS|test@example.com';
                } else if (integrationType == 'Instagram') {
                    return 'SUCCESS|test_user';
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
    public static String validateInstagram(String userId, String accessToken) {
        if (String.isBlank(userId) || String.isBlank(accessToken)) {
            return 'Please fill in both User ID and Long-Lived Access Token.';
        }

        String graphApiVersion = 'v24.0';
        MVEX__IG_Configuration__c igConfig = MVEX__IG_Configuration__c.getOrgDefaults();
        if (igConfig != null) {
            String configVersion;
            try {
                configVersion = (String) igConfig.get('APIVersion__c');
            } catch (Exception e1) {
                configVersion = null;
            }
            if (String.isNotBlank(configVersion)) {
                graphApiVersion = configVersion.trim();
            }
        }
        if (String.isBlank(graphApiVersion)) {
            graphApiVersion = 'v24.0';
        }
        if (!graphApiVersion.toLowerCase().startsWith('v')) {
            graphApiVersion = 'v' + graphApiVersion;
        }
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setMethod('GET');
        String endpoint = instagramEndpoint + graphApiVersion + '/me?fields=id,user_id,username&access_token=' + EncodingUtil.urlEncode(accessToken.trim(), 'UTF-8');
        req.setEndpoint(endpoint);
        req.setTimeout(20000);

        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 200) {
            Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            String returnedUserId = (String) responseBody.get('user_id');
            String returnedId     = (String) responseBody.get('id');
            String username       = (String) responseBody.get('username');
            String trimmedUserId  = userId.trim();

            Boolean matches = (returnedUserId != null && returnedUserId.equals(trimmedUserId)) ||
                              (returnedId     != null && returnedId.equals(trimmedUserId));

            if (!matches) {
                return 'The provided User ID does not match the authenticated Instagram account.';
            }
            // Return username so LWC can persist it — format: SUCCESS|{username}
            return 'SUCCESS|' + (String.isNotBlank(username) ? username : trimmedUserId);
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
    public static String validateGmail(String refreshToken, String clientId) {
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
            // Token exchange succeeded — now fetch the user's email via userinfo endpoint
            Map<String, Object> tokenResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            String freshAccessToken = (String) tokenResponse.get('access_token');

            String userEmail = '';
            if (String.isNotBlank(freshAccessToken)) {
                try {
                    HttpRequest userReq = new HttpRequest();
                    userReq.setMethod('GET');
                    String endpoint = gmailEndpoint + 'oauth2/v2/userinfo';
                    userReq.setEndpoint(endpoint);
                    userReq.setHeader('Authorization', 'Bearer ' + freshAccessToken);
                    userReq.setTimeout(10000);

                    HttpResponse userRes = new Http().send(userReq);
                    if (userRes.getStatusCode() == 200) {
                        Map<String, Object> userInfo = (Map<String, Object>) JSON.deserializeUntyped(userRes.getBody());
                        userEmail = (String) userInfo.get('email');
                    }
                } catch (Exception ex) {
                    // Non-fatal — email fetch failed, return SUCCESS without email
                    ErrorHandler.insertErrorData(ex, 'IntegrationPopupController', 'validateGmail', 'Could not fetch Gmail userinfo: ' + ex.getMessage());
                }
            }

            // Return SUCCESS|{email} so LWC can persist the email address
            return 'SUCCESS|' + (String.isNotBlank(userEmail) ? userEmail : '');
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