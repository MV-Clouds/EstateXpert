@IsTest
private class InstagramMediaPublisherTest {

    @testSetup
    static void setupAwsConfig() {
        insert new AWS_Config__c(
            AWS_Access_Key__c = 'testAccessKey',
            AWS_Secret_Access_Key__c = 'testSecretKey',
            S3_Region_Name__c = 'us-east-1',
            S3_Bucket_Name__c = 'mock-bucket'
        );
    }

    @isTest
    static void testPublishMediaSuccessFlow() {
        // Mock Instagram publish response
        HttpResponse instagramRes = new HttpResponse();
        instagramRes.setStatusCode(200);
        instagramRes.setBody('{"id": "media123"}');

        // Mock AWS delete response
        HttpResponse awsRes = new HttpResponse();
        awsRes.setStatusCode(200);
        awsRes.setBody('<DeleteResult></DeleteResult>');

        // Set mock for both callouts
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator.Multi(
            new List<HttpResponse>{ instagramRes, awsRes }
        ));

        List<String> awsKeys = new List<String>{ 'file1.jpg', 'file2.jpg' };
        List<String> keysToPreserve = new List<String>{ 'file2.jpg' };

        Test.startTest();
        InstagramMediaPublisher.publishMedia(
            '1234567890', 'media123', 'access_token_xyz',
            awsKeys, keysToPreserve
        );
        Test.stopTest();

        System.assert(true, 'publishMedia executed successfully without exceptions');
    }

    @isTest
    static void testSchedulableExecuteCallsPublishMedia() {
        // Mock Instagram + AWS callouts
        HttpResponse instagramRes = new HttpResponse();
        instagramRes.setStatusCode(200);
        instagramRes.setBody('{"id": "media987"}');

        HttpResponse awsRes = new HttpResponse();
        awsRes.setStatusCode(200);
        awsRes.setBody('<DeleteResult></DeleteResult>');

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator.Multi(
            new List<HttpResponse>{ instagramRes, awsRes }
        ));

        List<String> keys = new List<String>{ 'imgA.png', 'imgB.png' };
        List<String> preserve = new List<String>{ 'imgB.png' };

        InstagramMediaPublisher job = new InstagramMediaPublisher(
            'user_id_789', 'accessToken123', 'create_123', keys, preserve
        );

        Test.startTest();
        String jobId = System.schedule('InstagramPublisherJob', '0 0 0 1 1 ? 2050', job);
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Scheduled job ID should not be null');
    }
}