public class InstagramPostScheduler implements Schedulable {

    public String userId { get; set; }
    public String creationId { get; set; }
    public String accessToken { get; set; }
    public Boolean isCarousel { get; set; }
    public List<String> mediaContainerIds { get; set; }
    public String caption { get; set; }
    public List<String> awsObjectKeys { get; set; }
    public List<String> awsObjectKeysToPreserve { get; set; }
    public static final String INSTAGRAM_ENDPOINT = System.label.InstagramEndPoint;
    
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
        String graphApiVersion = 'v24.0';
        try {
            List<OAuth_Configuration__mdt> instaConfigs = [
                SELECT API_Version__c
                FROM OAuth_Configuration__mdt
                WHERE DeveloperName = 'Instagram_OAuth'
                WITH USER_MODE
                LIMIT 1
            ];
            if (!instaConfigs.isEmpty() && String.isNotBlank(instaConfigs[0].API_Version__c)) {
                graphApiVersion = instaConfigs[0].API_Version__c.trim();
            }
        } catch (Exception e1) {
            graphApiVersion = 'v24.0';
        }
        if (String.isBlank(graphApiVersion)) {
            graphApiVersion = 'v24.0';
        }
        if (!graphApiVersion.toLowerCase().startsWith('v')) {
            graphApiVersion = 'v' + graphApiVersion;
        }
        Http http = new Http();
        HttpRequest publishReq = new HttpRequest();
        publishReq.setEndpoint(INSTAGRAM_ENDPOINT + graphApiVersion + '/' + userId + '/media_publish');
        publishReq.setMethod('POST');
        publishReq.setHeader('Content-Type', 'application/json');

        Map<String, Object> publishRequestBody = new Map<String, Object>{
            'creation_id' => creationId,
            'access_token' => accessToken
        };
        publishReq.setBody(JSON.serialize(publishRequestBody));

        try {
            HttpResponse publishResponse = http.send(publishReq);

            if (publishResponse.getStatusCode() != 200) {
                ErrorHandler.insertErrordata(null, 'InstagramPostScheduler', 'publishPost', 'Failed to publish post: ' + publishResponse.getBody());
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'InstagramPostScheduler', 'publishPost', 'Error while publishing post.');
        } finally {
            InstagramPostController.deleteAwsImages(awsObjectKeys, awsObjectKeysToPreserve);
        }
    }

    @future(callout=true)
    public static void publishPostWithContainer(String userId, List<String> mediaContainerIds, String accessToken, String caption, List<String> awsObjectKeys, List<String> awsObjectKeysToPreserve) {

        try{
            
            Http http = new Http();

            HttpRequest albumReq = new HttpRequest();
            albumReq.setEndpoint(INSTAGRAM_ENDPOINT + 'v25.0/' + userId + '/media');
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

                Map<String, Object> params = new Map<String, Object>{
                    'userId' => userId,
                    'accessToken' => accessToken,
                    'creationId' => albumContainerId,
                    'isCarousel' => false,
                    'awsObjectKeys' => awsObjectKeys,
                    'awsObjectKeysToPreserve' => awsObjectKeysToPreserve
                };
                InstagramPostScheduler job = new InstagramPostScheduler(params);    
                String cronExpression = System.now().addMinutes(1).format('s m H d M \'?\' yyyy');
                System.schedule('Publish Instagram Media' + albumContainerId, cronExpression, job);
                return;
            } else {
                ErrorHandler.insertErrordata(null, 'InstagramPostScheduler', 'publishPostWithContainer', 'Failed to create album container: ' + albumResponse.getBody());
            }
        }catch(Exception e){
            ErrorHandler.insertErrordata(e, 'InstagramPostScheduler', 'publishPostWithContainer', 'Error while publishing post with container.');
        } finally {
            InstagramPostController.deleteAwsImages(awsObjectKeys, awsObjectKeysToPreserve);
        }
    }
}