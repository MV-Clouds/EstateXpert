public class InstagramPostScheduler implements Schedulable {

    public String userId { get; set; }
    public String creationId { get; set; }
    public String accessToken { get; set; }
    public Boolean isCarousel { get; set; }
    public List<String> mediaContainerIds { get; set; }
    public String caption { get; set; }
    public List<String> awsObjectKeys { get; set; }
    public List<String> awsObjectKeysToPreserve { get; set; }
    
    public class MediaResponse {
        public String id { get; set; }
    }

    public InstagramPostScheduler(Map<String, Object> params) {
        this.userId = (String) params.get('userId');
        this.accessToken = (String) params.get('accessToken');
        this.creationId = (String) params.get('creationId');
        this.mediaContainerIds = (List<String>) (params.containsKey('mediaContainerIds') ? params.get('mediaContainerIds') : new List<String>());
        this.isCarousel = (Boolean) (params.containsKey('isCarousel') ? params.get('isCarousel') : false);
        this.caption = (String) params.get('caption');
        this.awsObjectKeys = (List<String>) (params.containsKey('awsObjectKeys') ? params.get('awsObjectKeys') : new List<String>());
        this.awsObjectKeysToPreserve = (List<String>) (params.containsKey('awsObjectKeysToPreserve') ? params.get('awsObjectKeysToPreserve') : new List<String>());
    }

    public void execute(SchedulableContext sc) {
        if(!isCarousel){
            publishPost(userId, creationId, accessToken, awsObjectKeys, awsObjectKeysToPreserve);
        }else{
            publishPostWithContainer(userId, mediaContainerIds, accessToken, caption, awsObjectKeys, awsObjectKeysToPreserve);
        }
    }

    @future(callout=true)
    public static void publishPost(String userId, String creationId, String accessToken, List<String> awsObjectKeys, List<String> awsObjectKeysToPreserve) {
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

                if(res.getStatusCode() == 200) {
                    System.debug('Files successfully deleted' + res.getBody());
                }

            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'InstagramPostScheduler', 'publishPost', 'Error while publishing post.');
        }
    }

    @future(callout=true)
    public static void publishPostWithContainer(String userId, List<String> mediaContainerIds, String accessToken, String caption, List<String> awsObjectKeys, List<String> awsObjectKeysToPreserve) {

        try{
            
            Http http = new Http();

            HttpRequest albumReq = new HttpRequest();
            albumReq.setEndpoint('https://graph.instagram.com/v21.0/' + userId + '/media');
            albumReq.setMethod('POST');
            albumReq.setHeader('Content-Type', 'application/json');

            Map<String, Object> albumRequestBody = new Map<String, Object>{
                'caption' => caption,
                'media_type' => 'CAROUSEL',
                'children' => mediaContainerIds,
                'access_token' => accessToken
            };
            albumReq.setBody(JSON.serialize(albumRequestBody));

            HttpResponse albumResponse = http.send(albumReq);

            if (albumResponse.getStatusCode() == 200) {
                MediaResponse albumResponseData = (MediaResponse) JSON.deserialize(albumResponse.getBody(), MediaResponse.class);
                String albumContainerId = albumResponseData.id;

                InstagramMediaPublisher job = new InstagramMediaPublisher(userId, accessToken, albumContainerId, awsObjectKeys, awsObjectKeysToPreserve);    
                String cronExpression = System.now().addMinutes(1).format('s m H d M \'?\' yyyy');
                System.schedule('Publish Instagram Media' + albumContainerId, cronExpression, job);


            } 
        }catch(Exception e){
            ErrorHandler.insertErrordata(e, 'InstagramPostScheduler', 'publishPostWithContainer', 'Error while publishing post with container.');
        }
    }
}