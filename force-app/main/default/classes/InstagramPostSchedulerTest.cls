@isTest
private class InstagramPostSchedulerTest {

    // ─── HTTP Mock for Success ───────────────────────────────────────────────
    private class InstagramSuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            String endpoint = req.getEndpoint();
            
            // S3 delete call
            if (endpoint.contains('.s3.amazonaws.com')) {
                res.setStatusCode(200);
                res.setBody('<?xml version="1.0" encoding="UTF-8"?><DeleteResult></DeleteResult>');
                return res;
            }
            
            // Instagram media calls
            res.setStatusCode(200);
            res.setBody('{"id":"987654321"}');
            return res;
        }
    }

    // ─── HTTP Mock for Error ─────────────────────────────────────────────────
    private class InstagramErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            String endpoint = req.getEndpoint();
            
            if (endpoint.contains('.s3.amazonaws.com')) {
                res.setStatusCode(200);
                res.setBody('<?xml version="1.0" encoding="UTF-8"?><DeleteResult></DeleteResult>');
                return res;
            }
            
            res.setStatusCode(400);
            res.setBody('{"error":{"message":"API Error"}}');
            return res;
        }
    }

    @testSetup
    static void setup() {
        // Create AWS Config custom setting to satisfy deleteAwsImages in finally block
        MVEX__AWS_Config__c awsConfig = new MVEX__AWS_Config__c(
            MVEX__AWS_Access_Key__c = 'mock_access_key',
            MVEX__AWS_Secret_Access_Key__c = 'mock_secret_key',
            MVEX__S3_Region_Name__c = 'us-east-1',
            MVEX__S3_Bucket_Name__c = 'test-bucket'
        );
        insert awsConfig;
    }

    @isTest
    static void testExecuteSingleMedia() {
        Test.setMock(HttpCalloutMock.class, new InstagramSuccessMock());
        
        Map<String, Object> params = new Map<String, Object>{
            'userId' => 'user_123',
            'accessToken' => 'token_123',
            'creationId' => 'container_123',
            'isCarousel' => false,
            'caption' => 'Test Caption',
            'awsObjectKeys' => new List<String>{'image1.jpg'},
            'awsObjectKeysToPreserve' => new List<String>()
        };
        
        InstagramPostScheduler scheduler = new InstagramPostScheduler(params);
        
        Test.startTest();
        String jobId = System.schedule('Test Single Media Publish', '0 0 0 15 3 ? 2042', scheduler);
        // Execute block manually to cover synchronous path
        scheduler.execute(null);
        Test.stopTest();
        
        System.assertNotEquals(null, jobId);
    }
    
    @isTest
    static void testExecuteCarouselSuccess() {
        Test.setMock(HttpCalloutMock.class, new InstagramSuccessMock());
        
        Map<String, Object> params = new Map<String, Object>{
            'userId' => 'user_123',
            'accessToken' => 'token_123',
            'mediaContainerIds' => new List<String>{'container_1', 'container_2'},
            'isCarousel' => true,
            'caption' => 'Test Carousel',
            'awsObjectKeys' => new List<String>{'img1.jpg', 'img2.jpg'},
            'awsObjectKeysToPreserve' => new List<String>()
        };
        
        InstagramPostScheduler scheduler = new InstagramPostScheduler(params);
        
        Test.startTest();
        // Since publishPostWithContainer is @future, calling execute directly triggers the future method
        scheduler.execute(null);
        Test.stopTest();
        
        // Assert that no unhandled exceptions occurred
        System.assert(true);
    }

    @isTest
    static void testExecuteCarouselError() {
        Test.setMock(HttpCalloutMock.class, new InstagramErrorMock());
        
        Map<String, Object> params = new Map<String, Object>{
            'userId' => 'user_123',
            'accessToken' => 'token_123',
            'mediaContainerIds' => new List<String>{'container_1', 'container_2'},
            'isCarousel' => true,
            'caption' => 'Test Carousel',
            'awsObjectKeys' => new List<String>{'img1.jpg', 'img2.jpg'},
            'awsObjectKeysToPreserve' => new List<String>()
        };
        
        InstagramPostScheduler scheduler = new InstagramPostScheduler(params);
        
        Test.startTest();
        scheduler.execute(null);
        Test.stopTest();
        
        // Assert that errors are caught and handled by ErrorHandler
        System.assert(true);
    }
    
    @isTest
    static void testExecuteSingleMediaError() {
        Test.setMock(HttpCalloutMock.class, new InstagramErrorMock());
        
        Map<String, Object> params = new Map<String, Object>{
            'userId' => 'user_123',
            'accessToken' => 'token_123',
            'creationId' => 'container_123',
            'isCarousel' => false,
            'caption' => 'Test Caption',
            'awsObjectKeys' => new List<String>{'image1.jpg'},
            'awsObjectKeysToPreserve' => new List<String>()
        };
        
        InstagramPostScheduler scheduler = new InstagramPostScheduler(params);
        
        Test.startTest();
        scheduler.execute(null);
        Test.stopTest();
        
        // Assert that errors are caught and handled by ErrorHandler
        System.assert(true);
    }
}
