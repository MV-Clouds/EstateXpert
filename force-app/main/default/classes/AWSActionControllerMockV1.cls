public with sharing class AWSActionControllerMockV1 implements HttpCalloutMock{
    public HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        
        // Simulate successful responses based on the request method and endpoint
        if (req.getMethod() == 'PUT') {
            // Simulate successful S3 upload
            res.setStatusCode(200);
            res.setStatus('OK');
            res.setBody('<Success>Uploaded</Success>');
        } else if (req.getMethod() == 'POST' && req.getEndpoint().contains('?delete')) {
            // Simulate successful S3 delete
            res.setStatusCode(200);
            res.setStatus('OK');
            res.setBody('<DeleteResult><Deleted><Key>test-image.jpg</Key></Deleted></DeleteResult>');
        } else if (req.getMethod() == 'GET') {
            // Simulate successful S3 object retrieval
            res.setStatusCode(200);
            res.setStatus('OK');
            res.setBodyAsBlob(Blob.valueOf('test content'));
        } else {
            // Simulate failure for unrecognized requests
            res.setStatusCode(400);
            res.setStatus('Bad Request');
            res.setBody('<Error>Invalid request</Error>');
        }
        
        return res;
    }
}