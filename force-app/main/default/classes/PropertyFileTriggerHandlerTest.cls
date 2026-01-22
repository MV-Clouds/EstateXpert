@isTest
public class PropertyFileTriggerHandlerTest {

    @isTest
    public static void testHandleAfterDelete() {
        // Setup test data
        AWS_Config__c awsConfig = new AWS_Config__c(
            AWS_Access_Key__c = 'mockAccessKey',
            AWS_Secret_Access_Key__c = 'mockSecretKey',
            S3_Region_Name__c = 'us-east-1',
            S3_Bucket_Name__c = 'mock-bucket'
        );
        insert awsConfig;

        Property__c property = new Property__c(Name = 'Test Property');
        insert property;

        Property_File__c propertyFile = new Property_File__c(
            Property__c = property.Id,
            Filename__c = 'test-file.jpg'
        );
        insert propertyFile;

        // Prepare for the delete operation
        List<Property__c> deletedProperties = new List<Property__c>{property};
        Test.startTest();
        
        // Mock the AWS callout
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        
        // Call the trigger handler method
        PropertyFileTriggerHandler.handleAfterDelete(deletedProperties);
        
        Test.stopTest();

        // Verify that the delete operation was handled correctly
        List<Property_File__c> remainingFiles = [SELECT Id FROM Property_File__c WHERE Property__c = :property.Id];
        System.assertEquals(1, remainingFiles.size(), 'The property file should have been deleted.');
    }

    // Mock HttpResponseGenerator for AWS callout
    public class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('<?xml version="1.0" encoding="UTF-8"?><DeleteResult><Deleted><Object><Key>test-file.jpg</Key></Object></Deleted></DeleteResult>');
            return res;
        }
    }
}