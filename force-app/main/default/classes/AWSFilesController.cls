public without sharing class AWSFilesController {

    public static List<AWS_Config__c> configList = [SELECT Id, AWS_Access_Key__c, AWS_Secret_Access_Key__c, S3_Bucket_Name__c, S3_Region_Name__c, CreatedDate, LastModifiedDate FROM AWS_Config__c WITH USER_MODE LIMIT 1];
    
    public static String uploadFileToS3(String fileName, Blob fileBody, String contentType) {
        String publicURL = '';
        try {
            AWS_Config__c configData = !configList.isEmpty() ? configList[0] : null;
            
            if(configData != null) {
                String endpoint = 'https://' + configData.S3_Bucket_Name__c + '.s3.amazonaws.com/' + fileName;
                
                // Calculate Content-MD5
                String contentMD5 = EncodingUtil.base64Encode(Crypto.generateDigest('MD5', fileBody));
                String payloadHash = EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', fileBody));
                
                Map<String, String> headers = generateAWSUploadHeaders(fileName, contentMD5, payloadHash, contentType, configData.AWS_Access_Key__c, configData.AWS_Secret_Access_Key__c, configData.S3_Region_Name__c, configData.S3_Bucket_Name__c);
                
                HttpRequest req = new HttpRequest();
                req.setEndpoint(endpoint);
                req.setMethod('PUT');
                req.setHeader('Content-Type', contentType);
                req.setHeader('Content-MD5', contentMD5);
                
                for(String key : headers.keySet()) {
                    req.setHeader(key, headers.get(key));
                }
                
                req.setBodyAsBlob(fileBody);
                // req.setTimeout(120000); // Set timeout to 2 minutes for larger files
                
                Http http = new Http();
                HttpResponse res = http.send(req);
                
                if(res.getStatusCode() == 200) {
                    publicUrl = 'https://' + configData.S3_Bucket_Name__c + '.s3.' + configData.S3_Region_Name__c + '.amazonaws.com/' + fileName;
                    System.debug('File successfully uploaded to S3. Public URL: ' + publicUrl);
                } else {
                    System.debug('Failed to upload file: ' + res.getStatusCode() + ' - ' + res.getBody());
                }
            } else {
                System.debug('AWS Config Data is empty! Please enter Access Key and Secret Access Key!');
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'AWSFilesController', 'uploadFileToS3', e.getMessage());
        }
        return publicURL;
    }

    public static Map<String, String> generateAWSUploadHeaders(String fileName, String contentMD5, String payloadHash, String contentType, String awsAccessKey, String awsSecretKey, String awsRegion, String awsBucketName) {
        try {
            String service = 's3';
            String host = awsBucketName + '.s3.amazonaws.com';
            String algorithm = 'AWS4-HMAC-SHA256';
            
            Datetime now = Datetime.now();
            String amzDate = now.formatGMT('yyyyMMdd\'T\'HHmmss\'Z\'');
            String dateStamp = now.formatGMT('yyyyMMdd');
            
            String canonicalUri = '/' + fileName;
            String canonicalQueryString = '';
            String canonicalHeaders = 'content-md5:' + contentMD5 + '\n' +
                                    'content-type:' + contentType + '\n' +
                                    'host:' + host + '\n' +
                                    'x-amz-content-sha256:' + payloadHash + '\n' +
                                    'x-amz-date:' + amzDate + '\n';
            String signedHeaders = 'content-md5;content-type;host;x-amz-content-sha256;x-amz-date';
            
            String canonicalRequest = 'PUT\n' +
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
            
            String authorizationHeader = algorithm + ' Credential=' + awsAccessKey + '/' + credentialScope + 
                                       ', SignedHeaders=' + signedHeaders + ', Signature=' + signature;
            
            Map<String, String> headers = new Map<String, String>();
            headers.put('Authorization', authorizationHeader);
            headers.put('x-amz-date', amzDate);
            headers.put('x-amz-content-sha256', payloadHash);
            headers.put('Content-MD5', contentMD5);
            
            return headers;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'AWSFilesController', 'generateAWSUploadHeaders', e.getMessage());
            return null;
        }
    }

    @AuraEnabled
    public static void deleteImagesFromS3(List<String> fileNames) {
        try {
            AWS_Config__c configData = !configList.isEmpty() ? configList[0] : null;

            if(configData != null){
                String endpoint = 'https://' + configData.S3_Bucket_Name__c + '.s3.amazonaws.com/';
                String payload = '<Delete><Quiet>true</Quiet>';
                
                for(String fileName : fileNames) {
                    payload += '<Object><Key>' + fileName + '</Key></Object>';
                }
                payload += '</Delete>';
                
                String contentMD5 = EncodingUtil.base64Encode(Crypto.generateDigest('MD5', Blob.valueOf(payload)));
                
                Map<String, String> headers = generateAWSHeaders(payload, contentMD5, configData.AWS_Access_Key__c, configData.AWS_Secret_Access_Key__c, configData.S3_Region_Name__c, configData.S3_Bucket_Name__c);
                
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
                
                if(res.getStatusCode() == 200) {
                    System.debug('Files successfully deleted' + res.getBody());
                } else {
                    System.debug('Failed to delete files: ' + res.getBody());
                }
            } else {
                System.debug('AWS Config Data is empty! Please enter Access Key and Secret Access Key!');
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'AWSFilesController', 'deleteImagesFromS3', e.getMessage());
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
            ErrorHandler.insertErrordata(e, 'AWSFilesController', 'generateAWSHeaders', e.getMessage());
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
            ErrorHandler.insertErrordata(e, 'AWSFilesController', 'getSignatureKey', e.getMessage());
            return null;
        }
    }

    @AuraEnabled
    public static AWS_Config__c getS3ConfigSettings(){
        try {
            AWS_Config__c configData = !configList.isEmpty() ? configList[0] : null;
            return configData;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'AWSFilesController', 'getS3ConfigSettings', e.getMessage());
            return null;
        }
    }
}