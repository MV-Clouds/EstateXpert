public class InstagramPostScheduler implements Schedulable {

    public String creationId { get; set; }
    public Boolean isCarousel { get; set; }
    public List<String> mediaContainerIds { get; set; }
    public String caption { get; set; }
    public List<String> awsObjectKeys { get; set; }
    public List<String> awsObjectKeysToPreserve { get; set; }

    public class MediaResponse {
        public String id { get; set; }
    }

    public InstagramPostScheduler(Map<String, Object> params) {
        this.creationId = (String) params.get('creationId');
        this.mediaContainerIds = (List<String>) (params.containsKey('mediaContainerIds') ? params.get('mediaContainerIds') : new List<String>());
        this.isCarousel = (Boolean) (params.containsKey('isCarousel') ? params.get('isCarousel') : false);
        this.caption = (String) params.get('caption');
        this.awsObjectKeys = (List<String>) (params.containsKey('awsObjectKeys') ? params.get('awsObjectKeys') : new List<String>());
        this.awsObjectKeysToPreserve = (List<String>) (params.containsKey('awsObjectKeysToPreserve') ? params.get('awsObjectKeysToPreserve') : new List<String>());
    }

    public void execute(SchedulableContext sc) {
        if(!isCarousel){
            publishPost(creationId, awsObjectKeys, awsObjectKeysToPreserve);
        }else{
            publishPostWithContainer(mediaContainerIds, caption, awsObjectKeys, awsObjectKeysToPreserve);
        }
    }

    @future(callout=true)
    public static void publishPost(String creationId, List<String> awsObjectKeys, List<String> awsObjectKeysToPreserve) {
        try {
            List<OAuth_Configuration__mdt> instaConfigs = [SELECT API_Version__c, Base_URL__c, User_Id__c, Access_Token__c FROM OAuth_Configuration__mdt WHERE DeveloperName = 'Instagram_OAuth' LIMIT 1];

            if (instaConfigs.isEmpty()) {
                throw new CalloutException('Instagram OAuth configuration was not found.');
            }

            OAuth_Configuration__mdt config = instaConfigs[0];

            String graphApiVersion = String.isNotBlank(config.API_Version__c) ? config.API_Version__c.trim() : '';

            if (!graphApiVersion.toLowerCase().startsWith('v')) {
                graphApiVersion = 'v' + graphApiVersion;
            }

            String baseUrl = String.isNotBlank(config.Base_URL__c) ? config.Base_URL__c.trim() : '';

            while (baseUrl.endsWith('/')) {
                baseUrl = baseUrl.substring(0, baseUrl.length() - 1);
            }

            String userId = config.User_Id__c;
            String accessToken = config.Access_Token__c;

            if (String.isBlank(creationId) || String.isBlank(baseUrl) || String.isBlank(userId) || String.isBlank(accessToken)) {
                throw new CalloutException('Instagram publication parameters are incomplete.');
            }

            HttpRequest publishReq = new HttpRequest();
            publishReq.setEndpoint(baseUrl + '/' + graphApiVersion + '/' + userId + '/media_publish');
            publishReq.setMethod('POST');
            publishReq.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            publishReq.setTimeout(120000);

            String requestBody = 'creation_id=' + EncodingUtil.urlEncode(creationId, 'UTF-8') + '&access_token=' + EncodingUtil.urlEncode(accessToken, 'UTF-8');

            publishReq.setBody(requestBody);

            Http http = new Http();
            HttpResponse publishResponse = http.send(publishReq);

            if (publishResponse.getStatusCode() != 200) {
                ErrorHandler.insertErrordata(null, 'InstagramPostScheduler', 'publishPost', 'Failed to publish post. HTTP ' + publishResponse.getStatusCode() + ': ' + publishResponse.getBody());
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'InstagramPostScheduler', 'publishPost', 'Error while publishing post.');
        } finally {
            InstagramPostController.deleteAwsImages(awsObjectKeys, awsObjectKeysToPreserve);
        }
    }

    @future(callout=true)
    public static void publishPostWithContainer(List<String> mediaContainerIds, String caption, List<String> awsObjectKeys, List<String> awsObjectKeysToPreserve) {
        Boolean scheduledForPublish = false;

        try {
            if (mediaContainerIds == null || mediaContainerIds.isEmpty()) {
                throw new CalloutException('Media container IDs cannot be empty.');
            }

            List<OAuth_Configuration__mdt> instaConfigs = [SELECT API_Version__c, Base_URL__c, User_Id__c, Access_Token__c FROM OAuth_Configuration__mdt WHERE DeveloperName = 'Instagram_OAuth' LIMIT 1];

            if (instaConfigs.isEmpty()) {
                throw new CalloutException('Instagram OAuth configuration was not found.');
            }

            OAuth_Configuration__mdt config = instaConfigs[0];

            String graphApiVersion = String.isNotBlank(config.API_Version__c) ? config.API_Version__c.trim() : '';

            if (!graphApiVersion.toLowerCase().startsWith('v')) {
                graphApiVersion = 'v' + graphApiVersion;
            }

            String baseUrl = String.isNotBlank(config.Base_URL__c) ? config.Base_URL__c.trim() : '';

            while (baseUrl.endsWith('/')) {
                baseUrl = baseUrl.substring(0, baseUrl.length() - 1);
            }

            String userId = config.User_Id__c;
            String accessToken = config.Access_Token__c;

            if (String.isBlank(baseUrl) || String.isBlank(userId) || String.isBlank(accessToken)) {
                throw new CalloutException('Instagram configuration is incomplete.');
            }

            HttpRequest albumReq = new HttpRequest();
            albumReq.setEndpoint(baseUrl + '/' + graphApiVersion + '/' + userId + '/media');
            albumReq.setMethod('POST');
            albumReq.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            albumReq.setTimeout(120000);

            String requestBody =
                'media_type=CAROUSEL' +
                '&children=' + EncodingUtil.urlEncode(String.join(mediaContainerIds, ','), 'UTF-8') +
                '&caption=' + EncodingUtil.urlEncode(caption == null ? '' : caption, 'UTF-8') +
                '&access_token=' + EncodingUtil.urlEncode(accessToken, 'UTF-8');

            albumReq.setBody(requestBody);

            Http http = new Http();
            HttpResponse albumResponse = http.send(albumReq);

            if (albumResponse.getStatusCode() != 200 && albumResponse.getStatusCode() != 201) {
                throw new CalloutException('Failed to create carousel container. HTTP ' + albumResponse.getStatusCode() + ': ' + albumResponse.getBody());
            }

            MediaResponse albumResponseData = (MediaResponse) JSON.deserialize(albumResponse.getBody(), MediaResponse.class);

            if (albumResponseData == null ||
                String.isBlank(albumResponseData.id)) {
                throw new CalloutException('Carousel container ID was not returned by Instagram.');
            }

            String albumContainerId = albumResponseData.id;

            Map<String, Object> params = new Map<String, Object>{
                'creationId' => albumContainerId,
                'isCarousel' => false,
                'awsObjectKeys' => awsObjectKeys == null ? new List<String>() : awsObjectKeys,
                'awsObjectKeysToPreserve' => awsObjectKeysToPreserve == null ? new List<String>() : awsObjectKeysToPreserve
            };

            InstagramPostScheduler job = new InstagramPostScheduler(params);

            String cronExpression = System.now().addMinutes(1).format('s m H d M \'?\' yyyy');

            System.schedule('PublishInstagram_' + albumContainerId, cronExpression, job);

            scheduledForPublish = true;

        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'InstagramPostScheduler', 'publishPostWithContainer', 'Error while creating or scheduling Instagram carousel.');
        } finally {
            if (!scheduledForPublish) {
                InstagramPostController.deleteAwsImages(awsObjectKeys, awsObjectKeysToPreserve);
            }
        }
    }
}