@isTest
private class FileDownloadControllerTest {

    @isTest
    static void testFileDownloadSuccess() {
        AWS_Config__c config = new AWS_Config__c(
            AWS_Access_Key__c = 'testAccessKey',
            AWS_Secret_Access_Key__c = 'testSecretKey',
            S3_Bucket_Name__c = 'test-bucket',
            S3_Region_Name__c = 'us-east-1'
        );
        insert config;

        Test.setCurrentPageReference(new PageReference('/apex/FileDownloadPage'));
        ApexPages.currentPage().getParameters().put('fileName', 'test-file.txt');

        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setStatusCode(200);
        mockResponse.setBodyAsBlob(Blob.valueOf('Test file content'));

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(mockResponse));

        Test.startTest();
        FileDownloadController controller = new FileDownloadController();
        Test.stopTest();

        System.assertNotEquals(null, controller.fileDownload);
        System.assertEquals('Test file content', controller.fileDownload.toString());
    }

    @isTest
    static void testMissingFileName() {
        Test.setCurrentPageReference(new PageReference('/apex/FileDownloadPage'));

        Test.startTest();
        FileDownloadController controller = new FileDownloadController();
        Test.stopTest();

        System.assertEquals(1, ApexPages.getMessages().size());
        System.assertEquals('Missing file name', ApexPages.getMessages()[0].getSummary());
    }

    @isTest
    static void testAWSConfigNotFound() {
        Test.setCurrentPageReference(new PageReference('/apex/FileDownloadPage'));
        ApexPages.currentPage().getParameters().put('fileName', 'test-file.txt');

        Test.startTest();
        FileDownloadController controller = new FileDownloadController();
        Test.stopTest();

        System.assertEquals(1, ApexPages.getMessages().size());
        System.assertEquals('AWS Configuration is not found', ApexPages.getMessages()[0].getSummary());
    }

    @isTest
    static void testDownloadFailure() {
        AWS_Config__c config = new AWS_Config__c(
            AWS_Access_Key__c = 'testAccessKey',
            AWS_Secret_Access_Key__c = 'testSecretKey',
            S3_Bucket_Name__c = 'test-bucket',
            S3_Region_Name__c = 'us-east-1'
        );
        insert config;

        Test.setCurrentPageReference(new PageReference('/apex/FileDownloadPage'));
        ApexPages.currentPage().getParameters().put('fileName', 'test-file.txt');

        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setStatusCode(404);
        mockResponse.setBody('File not found');

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(mockResponse));

        Test.startTest();
        FileDownloadController controller = new FileDownloadController();
        Test.stopTest();

        System.assertEquals(1, ApexPages.getMessages().size());
        System.assertEquals('Failed to download file from AWS', ApexPages.getMessages()[0].getSummary());
    }
}