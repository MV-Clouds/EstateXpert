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
    public static String gmailSendEndpoint = System.label.Gmail_Sending_Endpoint;
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
                // Only SubscriberControlled fields (Refresh_Token__c, Access_Token__c, Email__c, Connected_Date__c)
                String refreshTokenValue = stringFieldMap.get('Refresh_Token__c');
                String accessTokenValue  = stringFieldMap.get('Access_Token__c');
                String emailValue        = stringFieldMap.get('Email__c');

                List<OAuth_Configuration__mdt> gmailOAuthList = [
                    SELECT Id, DeveloperName, Refresh_Token__c, Access_Token__c, Email__c, Connected_Date__c
                    FROM OAuth_Configuration__mdt
                    WHERE DeveloperName = 'Gmail_OAuth'
                    WITH USER_MODE
                    LIMIT 1
                ];

                if (!gmailOAuthList.isEmpty()) {
                    Metadata.CustomMetadata cmtRecord = new Metadata.CustomMetadata();
                    cmtRecord.fullName  = 'OAuth_Configuration__mdt.Gmail_OAuth';
                    cmtRecord.label     = gmailOAuthList[0].DeveloperName;

                    if (refreshTokenValue != null) {
                        Metadata.CustomMetadataValue cmtRefreshToken = new Metadata.CustomMetadataValue();
                        cmtRefreshToken.field = 'Refresh_Token__c';
                        cmtRefreshToken.value = refreshTokenValue;
                        cmtRecord.values.add(cmtRefreshToken);
                    }
                    if (accessTokenValue != null) {
                        Metadata.CustomMetadataValue cmtAccessToken = new Metadata.CustomMetadataValue();
                        cmtAccessToken.field = 'Access_Token__c';
                        cmtAccessToken.value = accessTokenValue;
                        cmtRecord.values.add(cmtAccessToken);
                    }
                    if (emailValue != null) {
                        Metadata.CustomMetadataValue cmtEmail = new Metadata.CustomMetadataValue();
                        cmtEmail.field = 'Email__c';
                        cmtEmail.value = emailValue;
                        cmtRecord.values.add(cmtEmail);
                    }

                    // Stamp Connected_Date__c only when a refresh token is being saved (i.e. first connect)
                    // and only if it hasn't been set yet — preserve the original connection date on re-saves.
                    if (String.isNotBlank(refreshTokenValue) && gmailOAuthList[0].Connected_Date__c == null) {
                        Metadata.CustomMetadataValue cmtConnectedDate = new Metadata.CustomMetadataValue();
                        cmtConnectedDate.field = 'Connected_Date__c';
                        cmtConnectedDate.value = Datetime.now();
                        cmtRecord.values.add(cmtConnectedDate);
                    }

                    Metadata.DeployContainer mdContainer = new Metadata.DeployContainer();
                    mdContainer.addMetadata(cmtRecord);
                    Metadata.Operations.enqueueDeployment(mdContainer, null);
                }

            } else if (integrationType == 'Instagram') {
                // Only SubscriberControlled fields (Access_Token__c, User_Id__c, Username__c, Connected_Date__c)
                // can be written at runtime via Metadata.deployContainer.
                String accessTokenValue = stringFieldMap.containsKey('Access_Token__c') ? stringFieldMap.get('Access_Token__c') : stringFieldMap.get('MVEX__Long_Access_Token__c');
                String userIdValue      = stringFieldMap.containsKey('User_Id__c') ? stringFieldMap.get('User_Id__c') : stringFieldMap.get('MVEX__User_Id__c');
                String usernameValue    = stringFieldMap.get('Username__c');

                List<OAuth_Configuration__mdt> instaOAuthList = [
                    SELECT Id, DeveloperName, Access_Token__c, User_Id__c, Username__c, Connected_Date__c
                    FROM OAuth_Configuration__mdt
                    WHERE DeveloperName = 'Instagram_OAuth'
                    WITH USER_MODE
                    LIMIT 1
                ];

                if (!instaOAuthList.isEmpty()) {
                    Metadata.CustomMetadata cmtRecord = new Metadata.CustomMetadata();
                    cmtRecord.fullName = 'OAuth_Configuration__mdt.Instagram_OAuth';
                    cmtRecord.label    = instaOAuthList[0].DeveloperName;

                    if (accessTokenValue != null) {
                        Metadata.CustomMetadataValue cmtAccessToken = new Metadata.CustomMetadataValue();
                        cmtAccessToken.field = 'Access_Token__c';
                        cmtAccessToken.value = accessTokenValue;
                        cmtRecord.values.add(cmtAccessToken);
                    }
                    if (userIdValue != null) {
                        Metadata.CustomMetadataValue cmtUserId = new Metadata.CustomMetadataValue();
                        cmtUserId.field = 'User_Id__c';
                        cmtUserId.value = userIdValue;
                        cmtRecord.values.add(cmtUserId);
                    }
                    if (usernameValue != null) {
                        Metadata.CustomMetadataValue cmtUsername = new Metadata.CustomMetadataValue();
                        cmtUsername.field = 'Username__c';
                        cmtUsername.value = usernameValue;
                        cmtRecord.values.add(cmtUsername);
                    }

                    // Stamp Connected_Date__c only on first connect (when token is set and date not yet stored)
                    if (String.isNotBlank(accessTokenValue) && instaOAuthList[0].Connected_Date__c == null) {
                        Metadata.CustomMetadataValue cmtConnectedDate = new Metadata.CustomMetadataValue();
                        cmtConnectedDate.field = 'Connected_Date__c';
                        cmtConnectedDate.value = Datetime.now();
                        cmtRecord.values.add(cmtConnectedDate);
                    }

                    Metadata.DeployContainer mdContainer = new Metadata.DeployContainer();
                    mdContainer.addMetadata(cmtRecord);
                    Metadata.Operations.enqueueDeployment(mdContainer, null);
                }
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

            // Gmail — read from OAuth_Configuration__mdt (Custom Metadata Type)
            // NOTE: CreatedDate/LastModifiedDate are NOT queryable on CMT. SystemModstamp IS.
            List<OAuth_Configuration__mdt> gmailOAuthList = [
                SELECT Client_Id__c, Client_Secret__c, Redirect_URI__c, Refresh_Token__c, Email__c,
                       Connected_Date__c, SystemModstamp
                FROM OAuth_Configuration__mdt
                WHERE DeveloperName = 'Gmail_OAuth'
                WITH USER_MODE
                LIMIT 1
            ];

            // Gmail Integration
            FieldWrapperData gmailWrapper = new FieldWrapperData();
            gmailWrapper.integrationName = 'Gmail';
            if (!gmailOAuthList.isEmpty()) {
                OAuth_Configuration__mdt gmailCredential = gmailOAuthList[0];
                gmailWrapper.integrationData = gmailCredential;
                gmailWrapper.isValid = String.isNotBlank(gmailCredential.Client_Id__c)
                                    && String.isNotBlank(gmailCredential.Client_Secret__c)
                                    && String.isNotBlank(gmailCredential.Redirect_URI__c)
                                    && String.isNotBlank(gmailCredential.Refresh_Token__c);
            } else {
                gmailWrapper.integrationData = null;
                gmailWrapper.isValid = false;
            }
            wrapperList.add(gmailWrapper);

            FieldWrapperData awsWrapper = new FieldWrapperData();
            awsWrapper.integrationName = 'AWS';
            awsWrapper.integrationData = awsCredential;
            awsWrapper.isValid = awsCredential.MVEX__AWS_Access_Key__c != null && awsCredential.MVEX__AWS_Secret_Access_Key__c != null && awsCredential.MVEX__S3_Bucket_Name__c != null && awsCredential.MVEX__S3_Region_Name__c != null;
            wrapperList.add(awsWrapper);

            // Instagram — read from OAuth_Configuration__mdt
            List<OAuth_Configuration__mdt> instaOAuthList = [
                SELECT Client_Id__c, Client_Secret__c, Redirect_URI__c, Access_Token__c,
                       User_Id__c, Username__c, Connected_Date__c, SystemModstamp
                FROM OAuth_Configuration__mdt
                WHERE DeveloperName = 'Instagram_OAuth'
                WITH USER_MODE
                LIMIT 1
            ];

            FieldWrapperData instagramWrapper = new FieldWrapperData();
            instagramWrapper.integrationName = 'Instagram';
            if (!instaOAuthList.isEmpty()) {
                OAuth_Configuration__mdt instaCredential = instaOAuthList[0];
                instagramWrapper.integrationData = instaCredential;
                instagramWrapper.isValid = String.isNotBlank(instaCredential.Client_Id__c)
                                        && String.isNotBlank(instaCredential.Access_Token__c)
                                        && String.isNotBlank(instaCredential.User_Id__c);
            } else {
                instagramWrapper.integrationData = null;
                instagramWrapper.isValid = false;
            }
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
    * @description : Clears the SubscriberControlled token fields (Refresh_Token__c, Access_Token__c, Email__c)
    *               on the Gmail_OAuth Custom Metadata record.
    */
    public static String deleteGmailConfig(String recordId){
        try {
            Metadata.CustomMetadata cmtRecord = new Metadata.CustomMetadata();
            cmtRecord.fullName = 'OAuth_Configuration__mdt.Gmail_OAuth';
            cmtRecord.label    = 'Gmail OAuth';

            Metadata.CustomMetadataValue cmtRefreshToken = new Metadata.CustomMetadataValue();
            cmtRefreshToken.field = 'Refresh_Token__c';
            cmtRefreshToken.value = null;
            cmtRecord.values.add(cmtRefreshToken);

            Metadata.CustomMetadataValue cmtAccessToken = new Metadata.CustomMetadataValue();
            cmtAccessToken.field = 'Access_Token__c';
            cmtAccessToken.value = null;
            cmtRecord.values.add(cmtAccessToken);

            Metadata.CustomMetadataValue cmtEmail = new Metadata.CustomMetadataValue();
            cmtEmail.field = 'Email__c';
            cmtEmail.value = null;
            cmtRecord.values.add(cmtEmail);

            Metadata.CustomMetadataValue cmtConnectedDate = new Metadata.CustomMetadataValue();
            cmtConnectedDate.field = 'Connected_Date__c';
            cmtConnectedDate.value = null;
            cmtRecord.values.add(cmtConnectedDate);

            Metadata.DeployContainer mdContainer = new Metadata.DeployContainer();
            mdContainer.addMetadata(cmtRecord);
            Metadata.Operations.enqueueDeployment(mdContainer, null);

            return 'success';
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'IntegrationPopupController', 'deleteGmailConfig', 'Error while clearing Gmail OAuth config.');
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
    public static String revokeInstagramAccess(String recordId) {
        try {
            Metadata.CustomMetadata cmtRecord = new Metadata.CustomMetadata();
            cmtRecord.fullName = 'OAuth_Configuration__mdt.Instagram_OAuth';
            cmtRecord.label    = 'Instagram OAuth';

            Metadata.CustomMetadataValue cmtAccessToken = new Metadata.CustomMetadataValue();
            cmtAccessToken.field = 'Access_Token__c';
            cmtAccessToken.value = null;
            cmtRecord.values.add(cmtAccessToken);

            Metadata.CustomMetadataValue cmtUserId = new Metadata.CustomMetadataValue();
            cmtUserId.field = 'User_Id__c';
            cmtUserId.value = null;
            cmtRecord.values.add(cmtUserId);

            Metadata.CustomMetadataValue cmtUsername = new Metadata.CustomMetadataValue();
            cmtUsername.field = 'Username__c';
            cmtUsername.value = null;
            cmtRecord.values.add(cmtUsername);

            Metadata.CustomMetadataValue cmtConnectedDate = new Metadata.CustomMetadataValue();
            cmtConnectedDate.field = 'Connected_Date__c';
            cmtConnectedDate.value = null;
            cmtRecord.values.add(cmtConnectedDate);

            Metadata.DeployContainer mdContainer = new Metadata.DeployContainer();
            mdContainer.addMetadata(cmtRecord);
            Metadata.Operations.enqueueDeployment(mdContainer, null);

            return 'success';
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'IntegrationPopupController', 'revokeInstagramAccess', 'Error while revoking Instagram access.');
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
                List<OAuth_Configuration__mdt> gmailOAuth = [
                    SELECT Client_Id__c, Client_Secret__c, Redirect_URI__c, Token_Endpoint__c, Refresh_Token__c, Email__c
                    FROM OAuth_Configuration__mdt
                    WHERE DeveloperName = 'Gmail_OAuth'
                    WITH USER_MODE
                    LIMIT 1
                ];

                if (!gmailOAuth.isEmpty()) {
                    result.objectData = gmailOAuth[0];
                    result.siteUrl    = gmailOAuth[0].Redirect_URI__c;
                }
            } else if (integrationType == 'Instagram') {
                List<OAuth_Configuration__mdt> instaOAuth = [
                    SELECT Client_Id__c, Client_Secret__c, Redirect_URI__c, Token_Endpoint__c,
                           Access_Token__c, User_Id__c, Username__c
                    FROM OAuth_Configuration__mdt
                    WHERE DeveloperName = 'Instagram_OAuth'
                    WITH USER_MODE
                    LIMIT 1
                ];

                if (!instaOAuth.isEmpty()) {
                    result.objectData = instaOAuth[0];
                    result.siteUrl    = instaOAuth[0].Redirect_URI__c;
                }
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
        String metaClientId = clientId != null ? clientId.trim() : '';
        String metaClientSecret = '';

        List<OAuth_Configuration__mdt> gmailOAuth = [SELECT Client_Id__c, Client_Secret__c, Redirect_URI__c, Token_Endpoint__c FROM OAuth_Configuration__mdt WHERE DeveloperName = 'Gmail_OAuth' WITH USER_MODE LIMIT 1];
        if (!gmailOAuth.isEmpty()) {
            if (String.isBlank(metaClientId) && String.isNotBlank(gmailOAuth[0].Client_Id__c)) {
                metaClientId = gmailOAuth[0].Client_Id__c.trim();
            }
            metaClientSecret = gmailOAuth[0].Client_Secret__c.trim();
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
        req.setEndpoint(GMAILENDPOINT + 'token');
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
                    String endpoint = gmailSendEndpoint + 'oauth2/v2/userinfo';
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