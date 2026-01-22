/**
* Class Name : PropertyFileTriggerHandler
* Created By : Karan Singh
* @description : This class is used to handle trigger events for Property_File__c object.
*/

public with sharing class PropertyFileTriggerHandler {
    
    /**
     * Method Name : handleAfterDelete
     * @description : Handles the after delete event for Property_File__c records.
     * @param deletedPropertyFiles List of deleted Property_File__c records.
     */
    public static void handleAfterDelete(List<Property__c> deletedPropertyFiles) {

        try {
            List<AWS_Config__c> awsSettingsList = [SELECT Id, AWS_Access_Key__c, AWS_Secret_Access_Key__c, S3_Bucket_Name__c, S3_Region_Name__c, Payloadhash__c FROM AWS_Config__c WHERE SetupOwnerId = :UserInfo.getOrganizationId() WITH USER_MODE LIMIT 1];

            if (awsSettingsList.isEmpty()) {
                return;
            }

            AWS_Config__c settings = awsSettingsList[0];
            String awsBucket = settings.S3_Bucket_Name__c;
            String awsKey = settings.AWS_Access_Key__c;
            String awsSecret = settings.AWS_Secret_Access_Key__c;
            String awsRegion = settings.S3_Region_Name__c;
            String payloadHash = settings.Payloadhash__c;

            Set<Id> propertyIds = new Set<Id>();
             
            for(Property__c property : deletedPropertyFiles) {
                propertyIds.add(property.Id);
            }
    
            List<Property_File__c> propertyFilesToDelete = [SELECT Id, Filename__c FROM Property_File__c WHERE Property__c IN :propertyIds WITH USER_MODE LIMIT 1000];
    
            List<String> fileNames = new List<String>();
            
            for(Property_File__c propertyFile : propertyFilesToDelete){
                fileNames.add(propertyFile.Filename__c); 
            }
            
            if(fileNames.isEmpty() == false){
                deleteImagesFromS3(fileNames, awsBucket, awsKey, awsSecret, awsRegion, payloadHash);
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'PropertyFileTriggerHandler', 'handleAfterDelete', 'Error while deleting property files from S3.');
        }
    }
    
    /**
     * Method Name : deleteImagesFromS3
     * @description : Deletes images from S3 bucket.
     * @param fileNames List of file names to be deleted.
     * @param awsBucket AWS S3 bucket name.
     * @param awsKey AWS access key.
     * @param awsSecret AWS secret access key.
     * @param awsRegion AWS region name.
     * @param payloadHash Payload hash for the request.
     */
    @future(callout=true)
    public static void deleteImagesFromS3(List<String> fileNames, String awsBucket, String awsKey, String awsSecret, String awsRegion, String payloadHash) {
        try {
            String endpoint = 'https://' + awsBucket + '.s3.amazonaws.com/';
            String payload = '<Delete><Quiet>true</Quiet>';
            
            for(String fileName : fileNames) {
                payload += '<Object><Key>' + fileName + '</Key></Object>';
            }
            payload += '</Delete>';
            
            String contentMD5 = EncodingUtil.base64Encode(Crypto.generateDigest('MD5', Blob.valueOf(payload)));
            
            Map<String, String> headers = generateAWSHeaders(payload, contentMD5, awsBucket, awsKey, awsSecret, awsRegion, payloadHash);
            
            HttpRequest req = new HttpRequest();
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
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'PropertyFileTriggerHandler', 'deleteImagesFromS3', 'Error while deleting property files from S3.');
        }
    }
    
    /**
     * Method Name : generateAWSHeaders
     * @description : Generates AWS headers for the request.
     * @param payload The request payload.
     * @param contentMD5 MD5 hash of the payload.
     * @param awsBucket AWS S3 bucket name.
     * @param awsKey AWS access key.
     * @param awsSecret AWS secret access key.
     * @param awsRegion AWS region name.
     * @param payloadHash Payload hash for the request.
     * @return Map of headers to be used in the request.
     */
    public static Map<String, String> generateAWSHeaders(String payload, String contentMD5, String awsBucket, String awsKey, String awsSecret, String awsRegion, String payloadHash) {
        try {
            String service = 's3';
            String host = awsBucket + '.s3.amazonaws.com';
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
        
            String canonicalRequest = 'POST\n' + 
                                    canonicalUri + '\n' +
                                    canonicalQueryString + '\n' +
                                    canonicalHeaders + '\n' +
                                    signedHeaders + '\n' +
                                    payloadHash;
            
            String awsType = 'aws4_request';
        
            String credentialScope = dateStamp + '/' + awsRegion + '/' + service + '/' + awsType;
            String stringToSign = algorithm + '\n' +
                                amzDate + '\n' +
                                credentialScope + '\n' +
                                EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf(canonicalRequest)));
        
            Blob signingKey = getSignatureKey(dateStamp, service, awsRegion, awsSecret);
            String signature = EncodingUtil.convertToHex(Crypto.generateMac('HmacSHA256', Blob.valueOf(stringToSign), signingKey));
        
            String algorithmWithCre = algorithm + ' Credential=' + awsKey;
            String mainCap = ', SignedHeaders=' + signedHeaders + ', Signature=' + signature;

            String authorizationHeader = algorithmWithCre + '/' + credentialScope + mainCap;
        
            Map<String, String> headers = new Map<String, String>();
            headers.put('Authorization', authorizationHeader);
            headers.put('x-amz-date', amzDate);
            headers.put('x-amz-content-sha256', 'UNSIGNED-PAYLOAD');
            headers.put('Content-MD5', contentMD5);
        
            return headers;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'PropertyFileTriggerHandler', 'generateAWSHeaders', 'Error while generating AWS headers.');
            return null;
        }
    }

    /**
     * Method Name : getSignatureKey
     * @description : Generates the signature key for AWS request.
     * @param dateStamp The date in 'yyyyMMdd' format.
     * @param serviceName The AWS service name (e.g., 's3').
     * @param awsRegion The AWS region name (e.g., 'us-west-2').
     * @param awsSecret The AWS secret access key.
     * @return Blob representing the signature key.
     */
    public static Blob getSignatureKey(String dateStamp, String serviceName, String awsRegion, String awsSecret) {
        try {
            Blob kDate = Crypto.generateMac('HmacSHA256', Blob.valueOf(dateStamp), Blob.valueOf('AWS4' + awsSecret));
            Blob kRegion = Crypto.generateMac('HmacSHA256', Blob.valueOf(awsRegion), kDate);
            Blob kService = Crypto.generateMac('HmacSHA256', Blob.valueOf(serviceName), kRegion);
            Blob kSigning = Crypto.generateMac('HmacSHA256', Blob.valueOf('aws4_request'), kService);
            return kSigning;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'PropertyFileTriggerHandler', 'getSignatureKey', 'Error while getting signature key.');
            return null;
        }
    }
    
}