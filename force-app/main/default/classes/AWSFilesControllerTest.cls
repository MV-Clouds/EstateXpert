@isTest
private class AWSFilesControllerTest {

    @testSetup
    static void setupTestData() {
        AWS_Config__c config = new AWS_Config__c(
            AWS_Access_Key__c = 'testAccessKey',
            AWS_Secret_Access_Key__c = 'testSecretKey',
            S3_Bucket_Name__c = 'test-bucket',
            S3_Region_Name__c = 'us-east-1'
        );
        insert config;
    }

    @isTest
    static void testUploadFileToS3_Success() {
        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setStatusCode(200);
        mockResponse.setBody('File uploaded successfully');

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(mockResponse));

        Blob fileContent = Blob.valueOf('Test file content');
        String contentType = 'text/plain';
        String fileName = 'test-file.txt';

        Test.startTest();
        String publicUrl = AWSFilesController.uploadFileToS3(fileName, fileContent, contentType);
        Test.stopTest();

        System.assertNotEquals('', publicUrl, 'Public URL should not be empty on success');
    }

    @isTest
    static void testUploadFileToS3_Failure() {
        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setStatusCode(403);
        mockResponse.setBody('Access Denied');

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(mockResponse));

        Blob fileContent = Blob.valueOf('Test file content');
        String contentType = 'text/plain';
        String fileName = 'test-file.txt';

        Test.startTest();
        String publicUrl = AWSFilesController.uploadFileToS3(fileName, fileContent, contentType);
        Test.stopTest();

        System.assertEquals('', publicUrl, 'Public URL should be empty on failure');
    }

    @isTest
    static void testDeleteImagesFromS3_Success() {
        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setStatusCode(200);
        mockResponse.setBody('Files deleted successfully');

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(mockResponse));

        List<String> fileNames = new List<String>{ 'file1.txt', 'file2.txt' };

        Test.startTest();
        AWSFilesController.deleteImagesFromS3(fileNames);
        Test.stopTest();
    }

    @isTest
    static void testDeleteImagesFromS3_Failure() {
        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setStatusCode(403);
        mockResponse.setBody('Access Denied');

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(mockResponse));

        List<String> fileNames = new List<String>{ 'file1.txt', 'file2.txt' };

        Test.startTest();
        AWSFilesController.deleteImagesFromS3(fileNames);
        Test.stopTest();
    }

    @isTest
    static void testGenerateAWSUploadHeaders() {
        Blob fileContent = Blob.valueOf('Test file content');
        String fileName = 'test-file.txt';
        String contentMD5 = EncodingUtil.base64Encode(Crypto.generateDigest('MD5', fileContent));
        String payloadHash = EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', fileContent));
        String contentType = 'text/plain';

        AWS_Config__c config = [SELECT AWS_Access_Key__c, AWS_Secret_Access_Key__c, S3_Region_Name__c, S3_Bucket_Name__c FROM AWS_Config__c LIMIT 1];

        Test.startTest();
        Map<String, String> headers = AWSFilesController.generateAWSUploadHeaders(
            fileName,
            contentMD5,
            payloadHash,
            contentType,
            config.AWS_Access_Key__c,
            config.AWS_Secret_Access_Key__c,
            config.S3_Region_Name__c,
            config.S3_Bucket_Name__c
        );
        Test.stopTest();

        System.assertNotEquals(null, headers.get('Authorization'));
        System.assertNotEquals(null, headers.get('x-amz-date'));
    }

    @isTest
    static void testGenerateAWSHeaders() {
        String payload = '<Delete><Quiet>true</Quiet><Object><Key>file1.txt</Key></Object></Delete>';
        String contentMD5 = EncodingUtil.base64Encode(Crypto.generateDigest('MD5', Blob.valueOf(payload)));

        AWS_Config__c config = [SELECT AWS_Access_Key__c, AWS_Secret_Access_Key__c, S3_Region_Name__c, S3_Bucket_Name__c FROM AWS_Config__c LIMIT 1];

        Test.startTest();
        Map<String, String> headers = AWSFilesController.generateAWSHeaders(
            payload,
            contentMD5,
            config.AWS_Access_Key__c,
            config.AWS_Secret_Access_Key__c,
            config.S3_Region_Name__c,
            config.S3_Bucket_Name__c
        );
        Test.stopTest();

        System.assertNotEquals(null, headers.get('Authorization'));
        System.assertNotEquals(null, headers.get('x-amz-date'));
    }

    @isTest
    static void testGetSignatureKey() {
        Blob signatureKey = AWSFilesController.getSignatureKey(
            'testSecretKey',
            '20250101',
            'us-east-1',
            's3'
        );
        System.assertNotEquals(null, signatureKey);
    }

    @isTest
    static void testGetS3ConfigSettings() {
        Test.startTest();
        AWS_Config__c config = AWSFilesController.getS3ConfigSettings();
        Test.stopTest();

        System.assertNotEquals(null, config);
        System.assertEquals('test-bucket', config.S3_Bucket_Name__c);
    }
}