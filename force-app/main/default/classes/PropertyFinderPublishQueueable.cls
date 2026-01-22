public class PropertyFinderPublishQueueable implements Queueable, Database.AllowsCallouts {
    private String listingId;
    private String portalId;
    private String apiKey;
    private String apiSecret;
    private String pfListingId;

    // Constructor to accept parameters
    public PropertyFinderPublishQueueable(String listingId, String portalId, String apiKey, String apiSecret, String pfListingId) {
        this.listingId = listingId;
        this.portalId = portalId;
        this.apiKey = apiKey;
        this.apiSecret = apiSecret;
        this.pfListingId = pfListingId;
    }

    private static String getAccesstoken(String apiKey, String apiSecret) {
        try {
            String propertyFinderProductionEndpoint = System.label.PropertyFinder_Endpoint_Production;
            String endpoint = propertyFinderProductionEndpoint + 'auth/token';
            Http h3 = new Http();
            HttpRequest req3 = new HttpRequest();
            
            req3.setHeader('Content-Type', 'application/json');
            req3.setBody('{ "apiKey": "' + apiKey + '", "apiSecret": "' + apiSecret + '" }');
            req3.setMethod('POST');
            req3.setEndpoint(endpoint);
            
            HttpResponse res3 = h3.send(req3);
            if (res3.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res3.getBody());
                return (String) responseMap.get('accessToken');
            } else {
                throw new AuraHandledException('Failed to get access token: ' + res3.getBody());
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'PropertyFinderIntegration', 'getAccesstoken', 'Error while getting access token.');
            throw e;
        }
    }

    public void execute(QueueableContext context) {
        try {
            if (pfListingId == null) {
                PropertyFinderIntegration.updatePortalListingRecord(listingId, portalId, 'Property Finder Listing ID is missing.', 'Exception');
                return;
            }
            String propertyFinderProductionEndpoint = System.label.PropertyFinder_Endpoint_Production;
            String endpoint = propertyFinderProductionEndpoint + 'listings/' + pfListingId + '/publish';
            String accessToken = getAccesstoken(apiKey, apiSecret);

            Http h3 = new Http();
            HttpRequest req3 = new HttpRequest();
            req3.setHeader('Content-Type', 'application/json');
            req3.setHeader('Authorization', 'Bearer ' + accessToken);
            req3.setMethod('POST');
            req3.setEndpoint(endpoint);
            
            HttpResponse res3 = h3.send(req3);
            
            String responseBody = res3.getBody();

            if (res3.getStatusCode() == 200) {
                PropertyFinderIntegration.updatePortalListingRecord(listingId, portalId, responseBody, 'Success');
            } else {
                PropertyFinderIntegration.updatePortalListingRecord(listingId, portalId, responseBody, 'Failed');
            }
        } catch (Exception e) {
            PropertyFinderIntegration.updatePortalListingRecord(listingId, portalId, e.getMessage(), 'Exception');
            ErrorHandler.insertErrorData(e, 'PropertyFinderIntegration', 'propertyFinderPublishListing', 'Error while publishing listing on PropertyFinder.');
        }
    }
}