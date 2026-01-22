/**
* Class Name : AWSActionController
* Created By : Karan Singh
* Last Modified Date : 05/11/2025
* Last Modified By : Karan Singh
* @description : Handles AWS S3 file uploads, deletions, and presigned URL generation using AWS Signature V4.
*/
public with sharing class AWSActionControllerV1 {
    private static final String CTL = 'AWSActionController';
    private static final String ACTIVITY = 'ImageUploadActivity';
    private static String awsBucket;
    private static String awsKey;
    private static String awsSecret;
    private static String awsRegion;
    private static String payloadHash;
    private static String awsType = 'aws4_request';

    /**
    * Method Name : uploadAndCreateMedia
    * @param propertyId The ID of the property to associate with the media.
    * @param fileDataList List of FileDataWrapper containing file and media metadata.
    * @return Map<String, String> Response map with status and message indicating success or error.
    * @description : Uploads files to AWS S3 and creates corresponding Property_File__c records.
    */
    @AuraEnabled
    public static Map<String, String> uploadAndCreateMedia(Id propertyId, List<FileDataWrapper> fileDataList) {
        Map<String, String> response = new Map<String, String>();
        try {
            if (propertyId == null) {
                response.put('status', 'error');
                response.put('message', 'Property ID is required');
                return response;
            }

            if (fileDataList == null || fileDataList.isEmpty()) {
                response.put('status', 'error');
                response.put('message', 'No files provided for upload');
                return response;
            }

            initializeAWSConfig();
            List<String> fileURLs = new List<String>();
            List<MediaData> mediaList = new List<MediaData>();

            // Upload files to AWS S3
            for (FileDataWrapper fileData : fileDataList) {
                FileWrapper file = fileData.file;
                MediaData media = fileData.media;

                Blob fileBody = EncodingUtil.base64Decode(file.base64Data);

                String fileUrl = uploadObject(media.name, fileBody);
                fileURLs.add(fileUrl);

                // Update media data with uploaded URL
                media.externalUrl = media.type != 'video/mp4' ? fileUrl : media.externalUrl;
                media.externalVideoUrl = media.type == 'video/mp4' ? fileUrl : media.externalVideoUrl;
                mediaList.add(media);
            }

            // Create media records
            List<Property_File__c> mediaToInsert = new List<Property_File__c>();
            for (MediaData media : mediaList) {
                Property_File__c mediaRecord = new Property_File__c();
                mediaRecord.BaseUrl__c = media.externalUrl;
                if (media.name != '' && media.name != null) {
                    if (media.name.length() > 80) {
                        String truncatedName = media.name.substring(0, 80);
                        mediaRecord.Name = truncatedName;
                        mediaRecord.Filename__c = media.name;
                    } else {
                        mediaRecord.Name = media.name;
                        mediaRecord.Filename__c = media.name;
                    }
                }
                mediaRecord.Size__c = media.size;
                mediaRecord.Property__c = propertyId;
                mediaRecord.ExternalLink__c = media.externalVideoUrl;
                mediaRecord.IsOnExpose__c = media.isOnExpose;
                mediaRecord.IsOnPortalFeed__c = media.isOnPortalFeed;
                mediaRecord.IsOnWebsite__c = media.isOnWebsite;
                mediaRecord.MVEX__MimeType__c = media.type;
                mediaToInsert.add(mediaRecord);
            }

            if (!mediaToInsert.isEmpty() && 
                Schema.sObjectType.Property_File__c.isCreateable() &&
                Schema.sObjectType.Property_File__c.fields.BaseUrl__c.isCreateable() &&
                Schema.sObjectType.Property_File__c.fields.Tags__c.isCreateable() &&
                Schema.sObjectType.Property_File__c.fields.Name.isCreateable() &&
                Schema.sObjectType.Property_File__c.fields.Filename__c.isCreateable() &&
                Schema.sObjectType.Property_File__c.fields.ExternalLink__c.isCreateable() &&
                Schema.sObjectType.Property_File__c.fields.Size__c.isCreateable() &&
                Schema.sObjectType.Property_File__c.fields.Property__c.isCreateable() &&
                Schema.sObjectType.Property_File__c.fields.IsOnExpose__c.isCreateable() &&
                Schema.sObjectType.Property_File__c.fields.IsOnPortalFeed__c.isCreateable() &&
                Schema.sObjectType.Property_File__c.fields.IsOnWebsite__c.isCreateable() &&
                Schema.sObjectType.Property_File__c.fields.MVEX__MimeType__c.isCreateable()) {
                insert as user mediaToInsert;
                response.put('status', 'success');
                response.put('message', 'Files Uploaded Successfully');
            } else {
                response.put('status', 'error');
                response.put('message', 'Media list is empty or insufficient permissions');
            }
            
            return response;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, CTL, 'uploadAndCreateMedia', ACTIVITY);
            response.put('status', 'error');
            response.put('message', 'Unexpected error: ' + e.getMessage());
            return response;
        }
    }

    /**
    * Class Name : FileDataWrapper
    * @description : Wrapper class to hold file and media metadata for AWS S3 uploads.
    */
    public class FileDataWrapper {
        @AuraEnabled public FileWrapper file { get; set; }
        @AuraEnabled public MediaData media { get; set; }
    }

    /**
    * Class Name : MediaData
    * @description : Wrapper class to store metadata for media files, including URLs, size, and visibility settings.
    */
    public class MediaData {
        @AuraEnabled public String externalUrl { get; set; }
        @AuraEnabled public String externalVideoUrl { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public Decimal size { get; set; }
        @AuraEnabled public String type { get; set; }
        @AuraEnabled public Boolean isOnExpose { get; set; }
        @AuraEnabled public Boolean isOnPortalFeed { get; set; }
        @AuraEnabled public Boolean isOnWebsite { get; set; }
    }

    /**
    * Method Name : deleteAWSImage
    * @param propertyFileId The ID of the Property_File__c record to delete.
    * @return Map<String, String> Response map with status and message indicating success or error.
    * @description : Deletes a single image from AWS S3 and its associated Property_File__c record.
    */
    @AuraEnabled
    public static Map<String,String> deleteAWSImage(String propertyFileId) {
        Map<String, String> response = new Map<String, String>();
        try {
            if (String.isBlank(propertyFileId)) {
                response.put('status', 'error');
                response.put('message', 'Property File ID is required');
                return response;
            }

            List<Property_File__c> propertyFile = [SELECT Filename__c FROM Property_File__c WHERE Id = :propertyFileId WITH USER_MODE LIMIT 1];
            
            if (propertyFile.isEmpty()) {
                response.put('status', 'error');
                response.put('message', 'Property file not found');
                return response;
            }

            initializeAWSConfig();
            return deleteImagesFromS3(new List<String>{propertyFile[0].Filename__c}, propertyFileId, null);
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, CTL, 'deleteAWSImage', ACTIVITY);
            response.put('status', 'error');
            response.put('message', 'Failed to delete image: ' + e.getMessage());
            return response;
        }
    }

    /**
    * Method Name : deleteAllAWSImages
    * @param propertyId The ID of the property whose associated files will be deleted.
    * @return Map<String, String> Response map with status and message indicating success or error.
    * @description : Deletes all images associated with a property from AWS S3 and their Property_File__c records.
    */
    @AuraEnabled
    public static Map<String,String> deleteAllAWSImages(String propertyId) {
        Map<String, String> response = new Map<String, String>();
        try {
            if (String.isBlank(propertyId)) {
                response.put('status', 'error');
                response.put('message', 'Property ID is required');
                return response;
            }

            List<Property_File__c> propertyFiles = [SELECT Filename__c FROM Property_File__c WHERE Property__c = :propertyId WITH USER_MODE LIMIT 1000];
            
            if (propertyFiles.isEmpty()) {
                response.put('status', 'error');
                response.put('message', 'No files found for the property');
                return response;
            }

            initializeAWSConfig();
            List<String> fileNames = new List<String>();
            for (Property_File__c file : propertyFiles) {
                fileNames.add(file.Filename__c);
            }
            
            return deleteImagesFromS3(fileNames, null, propertyId);
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, CTL, 'deleteAllAWSImages', ACTIVITY);
            response.put('status', 'error');
            response.put('message', 'Failed to delete images: ' + e.getMessage());
            return response;
        }
    }

    /**
    * Method Name : getBase64Data
    * @param propertyFileId The ID of the Property_File__c record to fetch.
    * @return Map<String, String> Response map with status, message, and Base64-encoded file data.
    * @description : Retrieves an image from AWS S3 and returns its Base64-encoded data with MIME type.
    */
    @AuraEnabled
    public static Map<String,String> getBase64Data(String propertyFileId) {
        Map<String, String> response = new Map<String, String>();
        try {
            if (String.isBlank(propertyFileId)) {
                response.put('status', 'error');
                response.put('message', 'Property File ID is required');
                return response;
            }

            // Query the Property File record to get the S3 awsKey and MIME type
            List<Property_File__c> propertyFile = [SELECT Filename__c, MVEX__MimeType__c FROM Property_File__c WHERE Id = :propertyFileId WITH USER_MODE LIMIT 1];

            if (propertyFile.isEmpty()) {
                response.put('status', 'error');
                response.put('message', 'Property file not found');
                return response;
            }

            initializeAWSConfig();
            String fileName = propertyFile[0].Filename__c;
            String mimeType = propertyFile[0].MVEX__MimeType__c != null ? propertyFile[0].MVEX__MimeType__c : 'image/jpeg';
            String encodedFileName = EncodingUtil.urlEncode(fileName, 'UTF-8').replace('+', '%20');
            String endpoint = 'https://' + awsBucket + '.s3.' + awsRegion + '.amazonaws.com/' + encodedFileName;

            // Generate headers for GET request
            String contentType = contentType(fileName.substringAfterLast('.').toLowerCase());
            String amzDate = Datetime.now().formatGMT('yyyyMMdd\'T\'HHmmss\'Z\'');
            String dateStamp = Datetime.now().formatGMT('yyyyMMdd');
            String service = 's3';
            String algorithm = 'AWS4-HMAC-SHA256';

            String canonicalUri = '/' + encodedFileName;
            String canonicalQueryString = '';
            String canonicalHeaders = 'host:' + awsBucket + '.s3.' + awsRegion + '.amazonaws.com\n' +
                                     'x-amz-content-sha256:' + payloadHash + '\n' +
                                     'x-amz-date:' + amzDate + '\n';
            String signedHeaders = 'host;x-amz-content-sha256;x-amz-date';

            String canonicalRequest = 'GET\n' +
                                    canonicalUri + '\n' +
                                    canonicalQueryString + '\n' +
                                    canonicalHeaders + '\n' +
                                    signedHeaders + '\n' +
                                    payloadHash;

            String credentialScope = dateStamp + '/' + awsRegion + '/' + service + '/' + awsType;            
            String stringToSign = algorithm + '\n' +
                                 amzDate + '\n' +
                                 credentialScope + '\n' +
                                 EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf(canonicalRequest)));

            Blob signingKey = getSignatureKey(dateStamp, service);
            String signature = EncodingUtil.convertToHex(Crypto.generateMac('HmacSHA256', Blob.valueOf(stringToSign), signingKey));

            String algorithmWithCre = algorithm + ' Credential=' + awsKey;
            String mainCap = ', SignedHeaders=' + signedHeaders + ', Signature=' + signature;

            String authorizationHeader = algorithmWithCre + '/' + credentialScope + mainCap;

            // Create HTTP request to fetch the S3 object
            HttpRequest req = new HttpRequest();
            req.setMethod('GET');
            req.setEndpoint(endpoint);
            req.setHeader('Host', awsBucket + '.s3.' + awsRegion + '.amazonaws.com');
            req.setHeader('x-amz-date', amzDate);
            req.setHeader('x-amz-content-sha256', payloadHash);
            req.setHeader('Authorization', authorizationHeader);
            req.setHeader('Accept', '*/*');

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() != 200) {
                response.put('status', 'error');
                response.put('message', 'Failed to fetch S3 object: ' + res.getStatus() + ' ' + res.getBody());
                return response;
            }

            // Get the binary content
            Blob imageBlob = res.getBodyAsBlob();

            // Convert to Base64
            String base64String = EncodingUtil.base64Encode(imageBlob);

            // Return Base64 string with MIME type prefix
            response.put('status', 'success');
            response.put('message', 'S3 object fetched successfully');
            response.put('data', 'data:' + mimeType + ';base64,' + base64String);
            return response;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, CTL, 'getBase64Data', ACTIVITY);
            response.put('status', 'error');
            response.put('message', 'Failed to fetch Base64 data: ' + e.getMessage());
            return response;
        }
    }

    /**
    * Method Name : initializeAWSConfig
    * @return void
    * @description : Initializes AWS configuration by retrieving awsBucket, awsKey, awsSecret, and awsRegion from custom settings.
    */
    private static void initializeAWSConfig() {
        List<AWS_Config__c> awsSettingsList = [SELECT Id, AWS_Access_Key__c, AWS_Secret_Access_Key__c, S3_Bucket_Name__c, S3_Region_Name__c, Payloadhash__c FROM AWS_Config__c WHERE SetupOwnerId = :UserInfo.getOrganizationId() WITH USER_MODE LIMIT 1];

        if (awsSettingsList.isEmpty()) {
            throw new AuraHandledException('AWS configuration not found');
        }

        AWS_Config__c settings = awsSettingsList[0];
        awsBucket = settings.S3_Bucket_Name__c;
        awsKey = settings.AWS_Access_Key__c;
        awsSecret = settings.AWS_Secret_Access_Key__c;
        awsRegion = settings.S3_Region_Name__c;
        payloadHash = settings.Payloadhash__c;

        if (String.isBlank(awsBucket) || String.isBlank(awsKey) || String.isBlank(awsSecret) || String.isBlank(awsRegion)) {
            throw new AuraHandledException('AWS configuration is missing or incomplete');
        }
    }

    /**
    * Method Name : uploadObject
    * @param fileName The name of the file to upload.
    * @param body The Blob content of the file.
    * @return String The URL of the uploaded file in AWS S3.
    * @description : Uploads a file to AWS S3 and returns its public URL.
    */
    private static String uploadObject(String fileName, Blob body) {
        try {
            String encodedFileName = EncodingUtil.urlEncode(fileName, 'UTF-8').replace('+', '%20');
            String endpoint = 'https://' + awsBucket + '.s3.amazonaws.com/' + encodedFileName;
            String contentType = contentType(fileName.substringAfterLast('.').toLowerCase());
            String contentMD5 = EncodingUtil.base64Encode(Crypto.generateDigest('MD5', body));
            Map<String, String> headers = generateAWSHeaders('PUT', body, contentMD5, contentType, encodedFileName);

            HttpRequest req = new HttpRequest();
            req.setMethod('PUT');
            req.setBodyAsBlob(body);
            req.setEndpoint(endpoint);
            req.setHeader('Content-Type', contentType);
            req.setHeader('Content-MD5', contentMD5);
            for (String headerKey : headers.keySet()) {
                req.setHeader(headerKey, headers.get(headerKey));
            }

            Http http = new Http();
            HTTPResponse res = http.send(req);

            if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
                return 'https://' + awsBucket + '.s3.amazonaws.com/' + encodedFileName;
            }
            throw new AuraHandledException('S3 upload failed with status ' + res.getStatusCode() + ': ' + res.getStatus());
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, CTL, 'uploadObject', ACTIVITY);
            throw new AuraHandledException('S3 upload error: ' + e.getMessage());
        }
    }

    /**
    * Method Name : deleteImagesFromS3
    * @param fileNames List of file names to delete from AWS S3.
    * @param fileId The ID of a single Property_File__c record to delete (optional).
    * @param propertyId The ID of the property to delete all associated files (optional).
    * @return Map<String, String> Response map with status and message indicating success or error.
    * @description : Deletes specified files from AWS S3 and associated Property_File__c records.
    */
    private static Map<String,String> deleteImagesFromS3(List<String> fileNames, String fileId, String propertyId) {
        Map<String, String> response = new Map<String, String>();
        try {
            String endpoint = 'https://' + awsBucket + '.s3.amazonaws.com/';
            String payload = '<Delete><Quiet>true</Quiet>';
            for (String fileName : fileNames) {
                payload += '<Object><Key>' + fileName + '</Key></Object>';
            }
            payload += '</Delete>';

            String contentMD5 = EncodingUtil.base64Encode(Crypto.generateDigest('MD5', Blob.valueOf(payload)));
            Map<String, String> headers = generateAWSHeaders('POST', Blob.valueOf(payload), contentMD5, 'application/xml', '');

            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint + '?delete');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/xml');
            req.setHeader('Content-MD5', contentMD5);
            for (String headerKey : headers.keySet()) {
                req.setHeader(headerKey, headers.get(headerKey));
            }
            req.setBody(payload);

            Http http = new Http();
            HTTPResponse res = http.send(req);

            if (res.getStatusCode() != 200) {
                response.put('status', 'error');
                response.put('message', 'S3 delete failed with status ' + res.getStatusCode());
                return response;
            } else {
                return deletelistingmedia(fileId, propertyId);
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, CTL, 'deleteImagesFromS3', ACTIVITY);
            response.put('status', 'error');
            response.put('message', 'S3 delete error: ' + e.getMessage());
            return response;
        }
    }

    /**
    * Method Name : contentType
    * @param fileType The file extension (e.g., 'png', 'jpg').
    * @return String The corresponding MIME type for the file extension.
    * @description : Returns the MIME type for a given file extension, defaulting to 'application/octet-stream' if unknown.
    */
    private static String contentType(String fileType) {
        Map<String, String> contentTypes = new Map<String, String>{
            'png' => 'image/png',
            'jpg' => 'image/jpeg',
            'jpeg' => 'image/jpeg',
            'mp4' => 'video/mp4'
        };
        return contentTypes.get(fileType.toLowerCase()) != null ? contentTypes.get(fileType.toLowerCase()) : 'application/octet-stream';
    }

    /**
    * Method Name : generateAWSHeaders
    * @param method The HTTP method (e.g., 'PUT', 'POST').
    * @param payload The request payload as a Blob.
    * @param contentMD5 The MD5 hash of the payload.
    * @param contentType The MIME type of the payload.
    * @param fileName The name of the file (optional).
    * @return Map<String, String> Map of HTTP headers for AWS S3 authentication.
    * @description : Generates AWS Signature V4 headers for S3 requests.
    */
    private static Map<String, String> generateAWSHeaders(String method, Blob payload, String contentMD5, String contentType, String fileName) {
        try {
            String service = 's3';
            String host = awsBucket + '.s3.amazonaws.com';
            String algorithm = 'AWS4-HMAC-SHA256';
            
            Datetime now = Datetime.now();
            String amzDate = now.formatGMT('yyyyMMdd\'T\'HHmmss\'Z\'');
            String dateStamp = now.formatGMT('yyyyMMdd');

            String canonicalUri = String.isBlank(fileName) ? '/' : '/' + fileName;
            String canonicalQueryString = method == 'POST' ? 'delete=' : '';
            String canonicalHeaders = 'content-md5:' + contentMD5 + '\n' +
                                    'content-type:' + contentType + '\n' +
                                    'host:' + host + '\n' +
                                    (method == 'PUT' ? 'x-amz-acl:public-read\n' : '') +
                                    'x-amz-content-sha256:UNSIGNED-PAYLOAD\n' +
                                    'x-amz-date:' + amzDate + '\n';
            String signedHeaders = method == 'PUT' ? 
                'content-md5;content-type;host;x-amz-acl;x-amz-content-sha256;x-amz-date' : 
                'content-md5;content-type;host;x-amz-content-sha256;x-amz-date';

            String canonicalRequest = method + '\n' + 
                                    canonicalUri + '\n' +
                                    canonicalQueryString + '\n' +
                                    canonicalHeaders + '\n' +
                                    signedHeaders + '\n' +
                                    payloadHash;

            String credentialScope = dateStamp + '/' + awsRegion + '/' + service+ '/' + awsType;
            String stringToSign = algorithm + '\n' +
                                amzDate + '\n' +
                                credentialScope + '\n' +
                                EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf(canonicalRequest)));

            Blob signingKey = getSignatureKey(dateStamp, service);
            String signature = EncodingUtil.convertToHex(Crypto.generateMac('HmacSHA256', Blob.valueOf(stringToSign), signingKey));

            String algorithmWithCre = algorithm + ' Credential=' + awsKey;
            String mainCap = ', SignedHeaders=' + signedHeaders + ', Signature=' + signature;

            String authorizationHeader = algorithmWithCre + '/' + credentialScope + mainCap;

            Map<String, String> headers = new Map<String, String>{
                'Authorization' => authorizationHeader,
                'x-amz-date' => amzDate,
                'x-amz-content-sha256' => 'UNSIGNED-PAYLOAD',
                'Content-MD5' => contentMD5,
                'Content-Type' => contentType
            };
            if (method == 'PUT') {
                headers.put('x-amz-acl', 'public-read');
            }

            return headers;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, CTL, 'generateAWSHeaders', ACTIVITY);
            throw new AuraHandledException('Failed to generate AWS headers: ' + e.getMessage());
        }
    }

    /**
    * Method Name : getSignatureKey
    * @param awsKey The AWS access awsKey.
    * @param dateStamp The date stamp in 'yyyyMMdd' format.
    * @param regionName The AWS awsRegion name.
    * @param serviceName The AWS service name (e.g., 's3').
    * @return Blob The derived signing awsKey for AWS Signature V4.
    * @description : Generates a signing awsKey for AWS Signature V4 authentication.
    */
    private static Blob getSignatureKey(String dateStamp, String serviceName) {
        Blob kDate = Crypto.generateMac('HmacSHA256', Blob.valueOf(dateStamp), Blob.valueOf('AWS4' + awsSecret));
        Blob kRegion = Crypto.generateMac('HmacSHA256', Blob.valueOf(awsRegion), kDate);
        Blob kService = Crypto.generateMac('HmacSHA256', Blob.valueOf(serviceName), kRegion);
        return Crypto.generateMac('HmacSHA256', Blob.valueOf('aws4_request'), kService);
    }

    /**
    * Class Name : FileWrapper
    * @description : Wrapper class to store file metadata, including name, Base64 data, size, and watermark status.
    */
    public class FileWrapper {
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String base64Data { get; set; }
        @AuraEnabled public Decimal size { get; set; }
        @AuraEnabled public String type { get; set; }
        @AuraEnabled public Boolean isWatermarked { get; set; }
    }

    /**
    * Method Name : deletelistingmedia
    * @param fileId The ID of a single Property_File__c record to delete (optional).
    * @param propertyId The ID of the property to delete all associated files (optional).
    * @return Map<String, String> Response map with status and message indicating success or error.
    * @description : Deletes Property_File__c records for a single file or all files associated with a property.
    */
    public static Map<String, String> deletelistingmedia(String fileId, String propertyId){
        Map<String, String> response = new Map<String, String>();
        try {
            if (fileId != null) {
                List<Property_File__c> propertyFile = [SELECT Id FROM Property_File__c WHERE Id =: fileId WITH USER_MODE LIMIT 1];
                if (propertyFile.size() > 0 && Schema.sObjectType.Property_File__c.isDeletable()) {
                    delete as user propertyFile[0];
                    response.put('status', 'success');
                    response.put('message', 'Media file deleted successfully.');
                }
            } else if (propertyId != null) {
                List<Property_File__c> propertyFiles = [SELECT Id, Property__c FROM Property_File__c WHERE Property__c = :propertyId WITH USER_MODE LIMIT 1000];
                if (propertyFiles.size() > 0 && Schema.sObjectType.Property_File__c.isDeletable()) {
                    delete as user propertyFiles;
                    response.put('status', 'success');
                    response.put('message', 'All media files deleted successfully.');
                }
            }
            return response;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, CTL, 'deletelistingmedia', 'Error while deleting Media record.');
            response.put('status', 'error');
            response.put('message', 'Error while deleting Media record: ' + e.getMessage());
            return response;
        }
    }
}