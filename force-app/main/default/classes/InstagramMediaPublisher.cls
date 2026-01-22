public class InstagramMediaPublisher implements Schedulable {

    public String userId { get; set; }
    public String accessToken { get; set; }
    public String creationId { get; set; }
    public List<String> awsObjectKeys { get; set; }
    public List<String> awsObjectKeysToPreserve { get; set; }

    public InstagramMediaPublisher(String userId, String accessToken, String creationId, List<String> awsObjectKeys, List<String> awsObjectKeysToPreserve) {
        this.userId = userId;
        this.accessToken = accessToken;
        this.creationId = creationId;
        this.awsObjectKeys = awsObjectKeys;
        this.awsObjectKeysToPreserve = awsObjectKeysToPreserve;
    }

    public void execute(SchedulableContext sc) {
        publishMedia(userId, creationId, accessToken, awsObjectKeys, awsObjectKeysToPreserve);
    }

    @future(callout=true)
    public static void publishMedia(String userId, String creationId, String accessToken, List<String> awsObjectKeys, List<String> awsObjectKeysToPreserve) {
        Http http = new Http();
        HttpRequest publishReq = new HttpRequest();
        publishReq.setEndpoint('https://graph.instagram.com/v21.0/' + userId + '/media_publish');
        publishReq.setMethod('POST');
        publishReq.setHeader('Content-Type', 'application/json');

        Map<String, Object> publishRequestBody = new Map<String, Object>{
            'creation_id' => creationId,
            'access_token' => accessToken
        };
        publishReq.setBody(JSON.serialize(publishRequestBody));

        try {
            HttpResponse publishResponse = http.send(publishReq);

            if (publishResponse.getStatusCode() == 200) {

                AWS_Config__c awsData = AWS_Config__c.getOrgDefaults();
                String awsAccessKey = awsData.AWS_Access_Key__c;
                String awsSecretKey = awsData.AWS_Secret_Access_Key__c;
                String awsRegion = awsData.S3_Region_Name__c;
                String awsBucketName = awsData.S3_Bucket_Name__c;

                String endpoint = 'https://' + awsBucketName + '.s3.amazonaws.com/';
                String payload = '<Delete><Quiet>true</Quiet>';

                for(String objectKey : awsObjectKeys) {
                    if(!awsObjectKeysToPreserve.contains(objectKey)){
                        payload += '<Object><Key>' + objectKey + '</Key></Object>';
                    }
                }
                payload += '</Delete>';

                String contentMD5 = EncodingUtil.base64Encode(Crypto.generateDigest('MD5', Blob.valueOf(payload)));
                Map<String, String> headers = InstagramPostController.generateAWSHeaders(payload, contentMD5, awsAccessKey, awsSecretKey, awsRegion, awsBucketName);

                HttpRequest req = new HttpRequest();
                req.setEndpoint(endpoint + '?delete');
                req.setMethod('POST');
                req.setHeader('Content-Type', 'application/xml');
                req.setHeader('Content-MD5', contentMD5);
                
                for(String key : headers.keySet()){
                    req.setHeader(key, headers.get(key));
                }
                
                req.setBody(payload);
                
                Http http2 = new Http();
                HttpResponse res = http2.send(req);

                if(res.getStatusCode() != 200) {
                    throw new CalloutException('Failed to delete AWS objects: ' + res.getBody());
                }

            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'InstagramMediaPublisher', 'publishMedia', 'Error while publishing media.');
        }
    }
}