public with sharing class InstagramPostController {

    public static final String INSTAGRAM_ENDPOINT = System.label.InstagramEndPoint;
    
    public class MediaResponse {
        public String id { get; set; }
    }

    private static String getMediaTypeFromUrl(String mediaUrl) {
        if (String.isBlank(mediaUrl)) {
            return 'IMAGE';
        }
        
        String lowerUrl = mediaUrl.toLowerCase();
        if (lowerUrl.contains('?')) {
            lowerUrl = lowerUrl.substringBefore('?');
        }
        
        if (lowerUrl.endsWith('.mp4') || lowerUrl.endsWith('.mov')) {
            return 'REELS';
        }
        
        return 'IMAGE';
    }

    public static Map<String, String> generateAWSHeaders(String payload, String contentMD5, String awsAccessKey, String awsSecretKey, String awsRegion, String awsBucketName) {
        try {
            String service = 's3';
            String host = awsBucketName + '.s3.amazonaws.com';
            String algorithm = 'AWS4-HMAC-SHA256';
        
            Datetime now = Datetime.now();
            String amzDate = now.formatGMT('yyyyMMdd\'T\'HHmmss\'Z\'');
            String dateStamp = now.formatGMT('yyyyMMdd');
        
            String canonicalUri = '/';
            String canonicalQueryString = 'delete=';
            String canonicalHeaders = 'content-md5:' + contentMD5 + '\n' +
                                    'host:' + host + '\n' + 
                                    'x-amz-content-sha256:UNSIGNED-PAYLOAD\n' +
                                    'x-amz-date:' + amzDate + '\n';
            String signedHeaders = 'content-md5;host;x-amz-content-sha256;x-amz-date';
            String payloadHash = 'UNSIGNED-PAYLOAD';
        
            String canonicalRequest = 'POST\n' + 
                                    canonicalUri + '\n' +
                                    canonicalQueryString + '\n' +
                                    canonicalHeaders + '\n' +
                                    signedHeaders + '\n' +
                                    payloadHash;
        
            String credentialScope = dateStamp + '/' + awsRegion + '/' + service + '/aws4_request';
            String stringToSign = algorithm + '\n' +
                                amzDate + '\n' +
                                credentialScope + '\n' +
                                EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf(canonicalRequest)));
        
            Blob signingKey = getSignatureKey(awsSecretKey, dateStamp, awsRegion, service);
            String signature = EncodingUtil.convertToHex(Crypto.generateMac('HmacSHA256', Blob.valueOf(stringToSign), signingKey));
        
            String authorizationHeader = algorithm + ' Credential=' + awsAccessKey + '/' + credentialScope + ', SignedHeaders=' + signedHeaders + ', Signature=' + signature;
        
            Map<String, String> headers = new Map<String, String>();
            headers.put('Authorization', authorizationHeader);
            headers.put('x-amz-date', amzDate);
            headers.put('x-amz-content-sha256', 'UNSIGNED-PAYLOAD');
            headers.put('Content-MD5', contentMD5);
        
            return headers;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'InstagramPostController', 'generateAWSHeaders', 'Error while generating AWS headers.');
            return null;
        }
    }
    
    public static Blob getSignatureKey(String key, String dateStamp, String regionName, String serviceName) {
        try {
            Blob kDate = Crypto.generateMac('HmacSHA256', Blob.valueOf(dateStamp), Blob.valueOf('AWS4' + key));
            Blob kRegion = Crypto.generateMac('HmacSHA256', Blob.valueOf(regionName), kDate);
            Blob kService = Crypto.generateMac('HmacSHA256', Blob.valueOf(serviceName), kRegion);
            Blob kSigning = Crypto.generateMac('HmacSHA256', Blob.valueOf('aws4_request'), kService);
            return kSigning;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'InstagramPostController', 'getSignatureKey', 'Error while getting signature key.');
            return null;
        }
    }
    public static void deleteAwsImages(List<String> awsObjectKeys, List<String> awsObjectKeysToPreserve) {
        try {
            MVEX__AWS_Config__c awsData = MVEX__AWS_Config__c.getOrgDefaults();
            if (awsData == null || String.isBlank(awsData.MVEX__AWS_Access_Key__c)) return;
            
            String awsAccessKey = awsData.MVEX__AWS_Access_Key__c;
            String awsSecretKey = awsData.MVEX__AWS_Secret_Access_Key__c;
            String awsRegion = awsData.MVEX__S3_Region_Name__c;
            String awsBucketName = awsData.MVEX__S3_Bucket_Name__c;
            String endpoint = 'https://' + awsBucketName + '.s3.amazonaws.com/';
            
            List<String> keysToDelete = new List<String>();
            if (awsObjectKeys != null) {
                for(String objectKey : awsObjectKeys) {
                    if(awsObjectKeysToPreserve == null || !awsObjectKeysToPreserve.contains(objectKey)){
                        keysToDelete.add(objectKey);
                    }
                }
            }

            if (!keysToDelete.isEmpty()) {
                String payload = '<Delete><Quiet>true</Quiet>';
                for(String objectKey : keysToDelete) {
                    payload += '<Object><Key>' + objectKey + '</Key></Object>';
                }
                payload += '</Delete>';

                String contentMD5 = EncodingUtil.base64Encode(Crypto.generateDigest('MD5', Blob.valueOf(payload)));
                Map<String, String> headers = generateAWSHeaders(payload, contentMD5, awsAccessKey, awsSecretKey, awsRegion, awsBucketName);

                HttpRequest req = new HttpRequest();
                req.setTimeout(120000);
                req.setEndpoint(endpoint + '?delete');
                req.setMethod('POST');
                req.setHeader('Content-Type', 'application/xml');
                req.setHeader('Content-MD5', contentMD5);
                
                for(String key : headers.keySet()){
                    req.setHeader(key, headers.get(key));
                }
                
                req.setBody(payload);
                
                Http http = new Http();
                HttpResponse res = http.send(req);

                if(res.getStatusCode() != 200) {
                    ErrorHandler.insertErrordata(null, 'InstagramPostController', 'deleteAwsImages', 'Failed to delete AWS objects: ' + res.getBody());
                }
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'InstagramPostController', 'deleteAwsImages', 'Error while deleting AWS objects.');
        }
    }
    
    @AuraEnabled
    public static Map<String, String> getPropertyMediaUrls(String listingId) {

        try {
            Map<String, String> mediaUrlMap = new Map<String, String>();
    
            List<MVEX__Listing__c> listingRecords = [SELECT MVEX__Property__c FROM MVEX__Listing__c WHERE Id = :listingId WITH USER_MODE LIMIT 1];
        
            if (!listingRecords.isEmpty() && listingRecords[0].MVEX__Property__c != null) {
                MVEX__Listing__c listingRecord = listingRecords[0];
                List<MVEX__Property_File__c> propertyFiles = [SELECT Name, MVEX__BaseUrl__c,MVEX__Size__c,MVEX__ExternalLink__c FROM MVEX__Property_File__c 
                                                                WHERE MVEX__Property__c = :listingRecord.MVEX__Property__c AND MVEX__Size__c != null  WITH USER_MODE];
        
                for (MVEX__Property_File__c file : propertyFiles) {
                    if (String.isNotBlank(file.MVEX__ExternalLink__c)) {
                        mediaUrlMap.put(file.Name, file.MVEX__ExternalLink__c);
                    } else {
                        mediaUrlMap.put(file.Name, file.MVEX__BaseUrl__c);
                    }
                }
            }
        
            return mediaUrlMap;
        
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'InstagramPostController', 'getPropertyMediaUrls', 'Error while getting property media urls.');
            return null;
        }

    }

    @TestVisible
    private static OAuth_Configuration__mdt mockConfig;

    @AuraEnabled(cacheable=true)
    public static Boolean checkInstagramIntegration() {
        try {
            if (Test.isRunningTest() && mockConfig == null) {
                return true;
            }
            OAuth_Configuration__mdt instaOAuth = mockConfig;
            if (instaOAuth == null) {
                List<OAuth_Configuration__mdt> instaOAuthList = [
                    SELECT User_Id__c, Access_Token__c
                    FROM OAuth_Configuration__mdt
                    WHERE DeveloperName = 'Instagram_OAuth'
                    WITH USER_MODE
                    LIMIT 1
                ];
                if (!instaOAuthList.isEmpty()) {
                    instaOAuth = instaOAuthList[0];
                }
            }
            if (instaOAuth != null
                && String.isNotBlank(instaOAuth.User_Id__c)
                && String.isNotBlank(instaOAuth.Access_Token__c)) {
                return true;
            }
            return false;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'InstagramPostController', 'checkInstagramIntegration', 'Error while checking Instagram integration.');
            return false;
        }
    }

    public class InstagramPostResponse {
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String message { get; set; }
    }

    @AuraEnabled
    public static InstagramPostResponse postToInstagram(List<String> mediaUrls, String caption , List<String> awsObjectKeys , List<String> awsObjectKeysToPreserve) {
        InstagramPostResponse apexResponse = new InstagramPostResponse();
        try {
            String userId;
            String accessToken;
            String graphApiVersion = 'v24.0';

            if (Test.isRunningTest() && mockConfig == null) {
                userId = '1234567890';
                accessToken = 'mock_access_token';
            } else {
                OAuth_Configuration__mdt instaOAuth = mockConfig;
                if (instaOAuth == null) {
                    List<OAuth_Configuration__mdt> instaOAuthList = [
                        SELECT User_Id__c, Access_Token__c, API_Version__c
                        FROM OAuth_Configuration__mdt
                        WHERE DeveloperName = 'Instagram_OAuth'
                        WITH USER_MODE
                        LIMIT 1
                    ];
                    if (!instaOAuthList.isEmpty()) {
                        instaOAuth = instaOAuthList[0];
                    }
                }

                if (instaOAuth == null || String.isBlank(instaOAuth.User_Id__c) || String.isBlank(instaOAuth.Access_Token__c)) {
                    apexResponse.status = 'ERROR';
                    apexResponse.message = 'Instagram is not connected. Please connect your account first.';
                    deleteAwsImages(awsObjectKeys, awsObjectKeysToPreserve);
                    return apexResponse;
                }

                userId      = instaOAuth.User_Id__c;
                accessToken = instaOAuth.Access_Token__c;

                if (String.isNotBlank(instaOAuth.API_Version__c)) {
                    graphApiVersion = instaOAuth.API_Version__c.trim();
                }
                if (!graphApiVersion.toLowerCase().startsWith('v')) {
                    graphApiVersion = 'v' + graphApiVersion;
                }
            }

            Http http = new Http();

            if (mediaUrls.size() == 1) {
                String mediaUrl = mediaUrls[0];
                String mediaType = getMediaTypeFromUrl(mediaUrl);

                HttpRequest req = new HttpRequest();
                req.setEndpoint(INSTAGRAM_ENDPOINT + graphApiVersion + '/' + userId + '/media');
                req.setMethod('POST');
                req.setHeader('Content-Type', 'application/json');

                Map<String, Object> requestBody = new Map<String, Object>{
                    (mediaType == 'REELS' ? 'video_url' : 'image_url') => mediaUrl,
                    'access_token' => accessToken,
                    'caption' => caption
                };

                if(mediaType == 'REELS'){
                    requestBody.put('media_type', mediaType);
                }
                req.setBody(JSON.serialize(requestBody));

                HttpResponse response = http.send(req);

                if (response.getStatusCode() == 200) {
                    MediaResponse mediaResponse = (MediaResponse) JSON.deserialize(response.getBody(), MediaResponse.class);
                    String mediaContainerId = mediaResponse.id;

                    Map<String, Object> params = new Map<String, Object>{
                        'userId' => userId,
                        'accessToken' => accessToken,
                        'mediaContainerIds' => new List<String>(),
                        'creationId' => mediaContainerId,
                        'isCarousel' => false,
                        'caption' => caption,
                        'awsObjectKeys' => awsObjectKeys,
                        'awsObjectKeysToPreserve' => awsObjectKeysToPreserve
                    };

                    InstagramPostScheduler job = new InstagramPostScheduler(params);
                    String cronExpression = System.now().addMinutes(1).format('s m H d M \'?\' yyyy');
                    System.schedule('Instagram Media Publish ' + mediaContainerId, cronExpression, job);

                    apexResponse.status = 'SUCCESS';
                    apexResponse.message = 'Instagram post is successfully created.';
                    return apexResponse;
                } else {
                    String parsedErrorMessage = extractInstagramErrorMessage(response.getBody());
                    sendEmailNotification(response.getBody());
                    deleteAwsImages(awsObjectKeys, awsObjectKeysToPreserve);
                    apexResponse.status = 'ERROR';
                    apexResponse.message = 'Failed to create media container: ' + parsedErrorMessage;
                    return apexResponse;
                }
            } else {
                List<String> mediaContainerIds = new List<String>();

                for (String mediaUrl : mediaUrls) {
                    String mediaType = getMediaTypeFromUrl(mediaUrl);

                    HttpRequest req = new HttpRequest();
                    req.setTimeout(120000);
                    req.setEndpoint(INSTAGRAM_ENDPOINT + graphApiVersion + '/' + userId + '/media');
                    req.setMethod('POST');
                    req.setHeader('Content-Type', 'application/json');

                    Map<String, Object> requestBody = new Map<String, Object>{
                        (mediaType == 'REELS' ? 'video_url' : 'image_url') => mediaUrl,
                        'is_carousel_item' => true,
                        'access_token' => accessToken
                    };

                    if(mediaType == 'REELS'){
                        requestBody.put('media_type', mediaType);
                    }

                    req.setBody(JSON.serialize(requestBody));

                    HttpResponse response = http.send(req);

                    if (response.getStatusCode() == 200) {
                        MediaResponse mediaResponse = (MediaResponse) JSON.deserialize(response.getBody(), MediaResponse.class);
                        mediaContainerIds.add(mediaResponse.id);
                    } else {
                        String parsedErrorMessage = extractInstagramErrorMessage(response.getBody());
                        sendEmailNotification(response.getBody());
                        deleteAwsImages(awsObjectKeys, awsObjectKeysToPreserve);
                        apexResponse.status = 'ERROR';
                        apexResponse.message = 'Failed to create media container: ' + parsedErrorMessage;
                        return apexResponse;
                    }
                }

                Map<String, Object> params = new Map<String, Object>{
                    'userId' => userId,
                    'accessToken' => accessToken,
                    'mediaContainerIds' => mediaContainerIds,
                    'creationId' => '',
                    'isCarousel' => true,
                    'caption' => caption,
                    'awsObjectKeys' => awsObjectKeys,
                    'awsObjectKeysToPreserve' => awsObjectKeysToPreserve
                };

                InstagramPostScheduler job = new InstagramPostScheduler(params);
                String cronExpression = System.now().addMinutes(1).format('s m H d M \'?\' yyyy');
                System.schedule('Instagram Media Publish' + mediaContainerIds[0], cronExpression, job);

                apexResponse.status = 'SUCCESS';
                apexResponse.message = 'Media container created. Publishing scheduled.';
                return apexResponse;

            }
        } catch (Exception e) {
            sendEmailNotification(e.getMessage());
            ErrorHandler.insertErrordata(e, 'InstagramPostController', 'postToInstagram', 'Error while posting to instagram.');
            deleteAwsImages(awsObjectKeys, awsObjectKeysToPreserve);
            apexResponse.status = 'ERROR';
            apexResponse.message = 'Exception: ' + e.getMessage();
            return apexResponse;
        }
    }

    private static String extractInstagramErrorMessage(String responseBody) {
        if (String.isBlank(responseBody)) {
            return 'Unknown Error';
        }
        try {
            Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
            if (jsonResponse.containsKey('error')) {
                Map<String, Object> errorObj = (Map<String, Object>) jsonResponse.get('error');
                if (errorObj != null && errorObj.containsKey('message')) {
                    return (String) errorObj.get('message');
                }
            }
        } catch (Exception e) {
            // Ignore parsing error and just return the raw body
        }
        return responseBody;
    }

    public static void sendEmailNotification(String errorMessage) {
        try {
            String emailId = UserInfo.getUserEmail();
            String userName = UserInfo.getName();
            String errorEmailId = System.Label.ErrorNotificationEmail;
    
            List<EmailTemplate> emailTemplates = [SELECT Id, HtmlValue, Subject FROM EmailTemplate WHERE DeveloperName = 'Instagram_Error_Template' WITH USER_MODE LIMIT 1];
            
            if (emailTemplates.isEmpty()) {
                return;
            }
            
            EmailTemplate emailTemplate = emailTemplates[0];
        
            String emailBody = emailTemplate.HtmlValue;
            emailBody = emailBody.replace('{!errorDetails}', errorMessage);
            emailBody = emailBody.replace('{!User}', userName);
    
            if(emailId != null){
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(new String[] { emailId, errorEmailId});
                mail.setSubject(emailTemplate.Subject);
                mail.setHtmlBody(emailBody);
                Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
            }
                
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'InstagramPostController', 'sendEmailNotification', 'Error while sending email notification.');
        }

    }
}