public with sharing class InstagramPostController {

    public static final String INSTAGRAM_ENDPOINT = System.label.InstagramEndPoint;
    
    public class MediaResponse {
        public String id { get; set; }
    }

    @AuraEnabled
    public static Map<String, Object> createInstagramContainer(List<String> mediaUrls, String caption) {
        try {
            IG_Configuration__c instaCredential = IG_Configuration__c.getOrgDefaults();

            String userId = instaCredential.User_Id__c;
            String accessToken = instaCredential.Long_Access_Token__c;

            Http http = new Http();
            Map<String, Object> result = new Map<String, Object>();
            result.put('success', false);

            System.debug('Creating Instagram container with mediaURLS: ' + mediaUrls);

            if (mediaUrls.size() == 1) {
                String mediaUrl = mediaUrls[0];
                String mediaType = getMediaTypeFromUrl(mediaUrl);

                HttpRequest req = new HttpRequest();
                req.setEndpoint(INSTAGRAM_ENDPOINT + userId + '/media');
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

                    List<String> mediaContainerIds = new List<String>{mediaContainerId};

                    System.debug('Media container created with ID: ' + mediaContainerId);
                    System.debug('Media containers created with ID: ' + mediaContainerIds);
                    
                    result.put('success', true);
                    result.put('isCarousel', false);
                    result.put('containerIds', mediaContainerIds);
                    result.put('containerId', mediaContainerId);
                    result.put('message', 'Media container created successfully.');
                    
                    return result;
                } else {
                    result.put('message', 'Failed to create media container: ' + response.getBody());
                    return result;
                }
            } else {
                List<String> mediaContainerIds = new List<String>();

                for (String mediaUrl : mediaUrls) {
                    String mediaType = getMediaTypeFromUrl(mediaUrl);

                    HttpRequest req = new HttpRequest();
                    req.setEndpoint(INSTAGRAM_ENDPOINT + userId + '/media');
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
                        result.put('message', 'Failed to create media container: ' + response.getBody());
                        return result;
                    }
                }
                
                result.put('success', true);
                result.put('isCarousel', true);
                result.put('containerIds', mediaContainerIds);
                result.put('containerId', '');
                result.put('message', 'Media containers created successfully.');
                
                return result;
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'InstagramPostController', 'createInstagramContainer', 'Error while creating Instagram container.');
            Map<String, Object> result = new Map<String, Object>();
            result.put('success', false);
            result.put('message', 'Exception: ' + e.getMessage());
            return result;
        }
    }
    
    @AuraEnabled
    public static String publishToInstagram(String containerId, List<String> containerIds, Boolean isCarousel, String caption, List<String> awsObjectKeys, List<String> awsObjectKeysToPreserve) {
        try {
            IG_Configuration__c instaCredential = IG_Configuration__c.getOrgDefaults();

            String userId = instaCredential.User_Id__c;
            String accessToken = instaCredential.Long_Access_Token__c;
            
            Map<String, Object> params = new Map<String, Object>();
            params.put('userId', userId);
            params.put('accessToken', accessToken);
            params.put('caption', caption);
            params.put('awsObjectKeys', awsObjectKeys);
            params.put('awsObjectKeysToPreserve', awsObjectKeysToPreserve);
            
            System.debug('containerId: ' + containerId);
            System.debug('isCarousel: ' + isCarousel);
            System.debug('containerIds: ' + containerIds);
            
            if (isCarousel) {
                if (containerIds == null) {
                    containerIds = new List<String>();
                }
                params.put('mediaContainerIds', containerIds);
                params.put('creationId', '');
                params.put('isCarousel', true);
                
                InstagramPostScheduler job = new InstagramPostScheduler(params);
                String cronExpression = System.now().addMinutes(1).format('s m H d M \'?\'  yyyy');
                System.schedule('Instagram Media Publish' + containerIds[0], cronExpression, job);
            } else {
                params.put('mediaContainerIds', new List<String>());
                params.put('creationId', containerId);
                params.put('isCarousel', false);
                
                InstagramPostScheduler job = new InstagramPostScheduler(params);
                String cronExpression = System.now().addMinutes(1).format('s m H d M \'?\'  yyyy');
                System.schedule('Instagram Media Publish ' + containerId, cronExpression, job);
            }
            
            return 'Publishing scheduled successfully.';
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'InstagramPostController', 'publishToInstagram', 'Error while publishing to Instagram.');
            return 'Exception: ' + e.getMessage();
        }
    }

    private static String getMediaTypeFromUrl(String mediaUrl) {
        if (mediaUrl.toLowerCase().endsWith('.mp4')) {
            return 'REELS';
        } else {
            return 'IMAGE';
        }
    }

    @AuraEnabled(cacheable=true)
    public static AWS_Config__c getS3ConfigSettings() {
        try {
            return AWS_Config__c.getOrgDefaults();
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'InstagramPostController', 'getS3ConfigSettings', 'Error while getting S3 config settings.');
            return null;
        }
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
        
    @AuraEnabled
    public static Map<String, String> getPropertyMediaUrls(String listingId) {

        try {
            Map<String, String> mediaUrlMap = new Map<String, String>();
    
            Listing__c listingRecord = [
                SELECT Property__c 
                FROM Listing__c 
                WHERE Id = :listingId WITH USER_MODE
                LIMIT 1
            ];
        
            if (listingRecord != null && listingRecord.Property__c != null) {
                List<Property_File__c> propertyFiles = [
                    SELECT Name, BaseUrl__c 
                    FROM Property_File__c 
                    WHERE Property__c = :listingRecord.Property__c AND IsDeleted = false WITH USER_MODE
                ];
        
                for (Property_File__c file : propertyFiles) {
                    mediaUrlMap.put(file.Name, file.BaseUrl__c);
                }
            }
        
            return mediaUrlMap;
        
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'InstagramPostController', 'getPropertyMediaUrls', 'Error while getting property media urls.');
            return null;
        }

    }

    @AuraEnabled(cacheable=true)
    public static Boolean checkInstagramIntegration() {
        try {
            IG_Configuration__c instaCredential = IG_Configuration__c.getOrgDefaults();
            if (instaCredential != null && instaCredential.User_Id__c != null && instaCredential.Long_Access_Token__c != null) {
                return true;
            } else {
                return false;
            }
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

            IG_Configuration__c instaCredential = IG_Configuration__c.getOrgDefaults();

            String userId = instaCredential.User_Id__c;
            String accessToken = instaCredential.Long_Access_Token__c;

            Http http = new Http();

            if (mediaUrls.size() == 1) {
                String mediaUrl = mediaUrls[0];
                String mediaType = getMediaTypeFromUrl(mediaUrl);

                HttpRequest req = new HttpRequest();
                req.setEndpoint('https://graph.instagram.com/v21.0/' + userId + '/media');
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
                    apexResponse.message = 'Media container created. Publishing scheduled.';
                    return apexResponse;
                } else {
                    sendEmailNotification(response.getBody());
                    apexResponse.status = 'ERROR';
                    apexResponse.message = 'Failed to create media container: ' + response.getBody();
                    return apexResponse;

                }
            } else {
                List<String> mediaContainerIds = new List<String>();

                for (String mediaUrl : mediaUrls) {
                    String mediaType = getMediaTypeFromUrl(mediaUrl);

                    HttpRequest req = new HttpRequest();
                    req.setEndpoint('https://graph.instagram.com/v21.0/' + userId + '/media');
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
                        sendEmailNotification(response.getBody());
                        apexResponse.status = 'ERROR';
                        apexResponse.message = 'Failed to create media container: ' + response.getBody();
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
            apexResponse.status = 'ERROR';
            apexResponse.message = 'Exception: ' + e.getMessage();
            return apexResponse;
        }
    }

    public static void sendEmailNotification(String errorMessage) {

        try {
            
            String emailId = UserInfo.getUserEmail();
            // String emailId = 'karan.s@mvclouds.com';
            String userName = UserInfo.getName();
    
            EmailTemplate emailTemplate = [SELECT Id, HtmlValue, Subject FROM EmailTemplate WHERE DeveloperName = 'Instagram_Error_Template' WITH SECURITY_ENFORCED LIMIT 1];
        
            String emailBody = emailTemplate.HtmlValue;
            emailBody = emailBody.replace('{!errorDetails}', errorMessage);
            emailBody = emailBody.replace('{!User}', userName);
    
            GmailConfig__c settings = GmailConfig__c.getOrgDefaults();
    
            String refreshToken = settings.Refresh_Token__c;
    
            if(refreshToken != null && emailId != null){
                List<GmailIntegrationControllerV1.EmailWrapper> gmails = new List<GmailIntegrationControllerV1.EmailWrapper>();
    
                GmailIntegrationControllerV1.EmailWrapper singleGmail = new GmailIntegrationControllerV1.EmailWrapper();
                singleGmail.toAddresses = new List<String>{emailId};
                singleGmail.subject = emailTemplate.Subject;
                singleGmail.body = emailBody;
    
                gmails.add(singleGmail);
    
                GmailIntegrationControllerV1.requestNewAccessToken(gmails,null,null,false);
    
            }
            else if(emailId != null){
                    
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(new String[] { emailId });
                mail.setSubject(emailTemplate.Subject);
                mail.setHtmlBody(emailBody);
        
                Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
                System.debug('Email sent to user: ' + emailId);
            }
                
        } catch (Exception e) {
            System.debug('Error: ' + e.getMessage());
            System.debug('Error: ' + e.getLineNumber());
            ErrorHandler.insertErrordata(e, 'InstagramPostController', 'sendEmailNotification', 'Error while sending email notification.');
        }

    }
}