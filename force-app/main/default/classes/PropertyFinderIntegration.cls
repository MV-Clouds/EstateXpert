public with sharing class PropertyFinderIntegration {

    public static String propertyFinderProductionEndpoint = System.label.PropertyFinder_Endpoint_Production;

    public class ListingResponse {
        @AuraEnabled
        public String status;
        @AuraEnabled
        public String message;
        @AuraEnabled
        public List<Map<String, Object>> data;
    }

    @AuraEnabled
    public static ListingResponse propertyFinderGetListing(String portalId) {
        ListingResponse response = new ListingResponse();
        try {
            String escapePortalId = String.escapeSingleQuotes(portalId);

            List<Portal__c> portalPropertyFinder = [SELECT Id, Field_Mapping__c, Portal_Configuration__c, Is_Active__c FROM Portal__c 
                                                        WHERE Id =: escapePortalId AND Is_Active__c = true WITH USER_MODE LIMIT 1];

            if (portalPropertyFinder.isEmpty()) {
                response.status = 'Failed';
                response.message = 'Portal configuration is missing.';
                return response;
            }

            Portal__c propertyFinderPortal = portalPropertyFinder[0];
            Map<String, Object> configMap = (Map<String, Object>) JSON.deserializeUntyped(propertyFinderPortal.Portal_Configuration__c);

            String apiKey = (String) configMap.get('apiKey');
            String apiSecret = (String) configMap.get('apiSecret');
            String accessToken = getAccesstoken(apiKey, apiSecret);

            String endpoint = propertyFinderProductionEndpoint + 'listings';

            Http h3 = new Http();
            HttpRequest req3 = new HttpRequest();
            req3.setHeader('Authorization', 'Bearer ' + accessToken);
            req3.setMethod('GET');
            req3.setEndpoint(endpoint);
            
            HttpResponse res3 = h3.send(req3);

            if (res3.getStatusCode() != 200) {
                response.status = 'Failed';
                response.message = res3.getBody();
                return response;
            }

            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res3.getBody());

            List<Map<String, Object>> listings = new List<Map<String, Object>>();
            if (responseMap.containsKey('results') && responseMap.get('results') instanceof List<Object>) {
                for (Object obj : (List<Object>) responseMap.get('results')) {
                    if (obj instanceof Map<String, Object>) {
                        Map<String, Object> listing = (Map<String, Object>) obj;
                        // Check if listing is live on propertyfinder portal
                        if (listing.containsKey('portals') && listing.get('portals') instanceof Map<String, Object>) {
                            Map<String, Object> portals = (Map<String, Object>) listing.get('portals');
                            if (portals.containsKey('propertyfinder') && portals.get('propertyfinder') instanceof Map<String, Object>) {
                                Map<String, Object> pfPortal = (Map<String, Object>) portals.get('propertyfinder');
                                if (pfPortal.containsKey('isLive') && (Boolean) pfPortal.get('isLive')) {
                                    listings.add(listing);
                                }
                            }
                        }
                    }
                }
            }

            Set<String> listingReferences = new Set<String>();
            Map<String, Map<String, Object>> listingInfo = new Map<String, Map<String, Object>>();
            
            for (Map<String, Object> listing : listings) {
                String listingReference = (String) listing.get('reference');
                String updateDate = (String) listing.get('updatedAt');
                String channel = ((String) listing.get('type')).contains('sale') ? 'Sales' : 'Lettings';
                listingReferences.add(listingReference);

                Map<String, Object> listingDetails = new Map<String, Object>();
                listingDetails.put('updateDate', updateDate);
                listingDetails.put('channel', channel);
                
                listingInfo.put(listingReference, listingDetails);
            }
            
            List<Listing__c> properties = [SELECT Id, Name, Broker_s_Listing_ID__c FROM Listing__c WHERE Broker_s_Listing_ID__c IN :listingReferences 
                                            WITH USER_MODE ORDER BY Name ASC];

            List<Map<String, Object>> resultData = new List<Map<String, Object>>();
            
            for (Listing__c property : properties) {
                Map<String, Object> resultItem = new Map<String, Object>();
                resultItem.put('id', property.Id);
                resultItem.put('name', property.Name);
                resultItem.put('listing_reference', property.Broker_s_Listing_ID__c);
                resultItem.put('updateDate', listingInfo.get(property.Broker_s_Listing_ID__c).get('updateDate'));
                resultItem.put('channel', listingInfo.get(property.Broker_s_Listing_ID__c).get('channel'));
                resultData.add(resultItem);
            }
            
            response.status = 'Success';
            response.data = resultData;

            return response;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'PropertyFinderIntegration', 'propertyFinderGetListing', 'Error while getting listing list from PropertyFinder.');
            response.status = 'Failed';
            response.message = e.getMessage();
            return response;
        }
    }

    @AuraEnabled
    public static void getListingRecordForSync(String listingId, String portalId, String actionName) {
        try {
            String escapeListingId = String.escapeSingleQuotes(listingId);
            String escapePortalId = String.escapeSingleQuotes(portalId);
            String pfListingId = null;
            List<Portal__c> portalPropertyFinder = [SELECT Id, Field_Mapping__c, Portal_Configuration__c, Is_Active__c FROM Portal__c WHERE Id =: escapePortalId AND Is_Active__c = true WITH USER_MODE LIMIT 1];

            if (portalPropertyFinder.isEmpty()) {
                updatePortalListingRecord(listingId, portalId, 'Portal configuration is missing.', 'Exception');
                return;
            }

            Portal__c propertyFinderPortal = portalPropertyFinder[0];

            Map<String, Object> jsonMap = (Map<String, Object>) JSON.deserializeUntyped(propertyFinderPortal.Field_Mapping__c);
            Map<String, Object> configMap = (Map<String, Object>) JSON.deserializeUntyped(propertyFinderPortal.Portal_Configuration__c);
            Map<String, Object> finalMapping = new Map<String, Object>();

            String apiKey = (String) configMap.get('apiKey');
            String apiSecret = (String) configMap.get('apiSecret');

            List<String> fieldNames = new List<String>();
            for (String key : jsonMap.keySet()) {
                fieldNames.add(key);
            }

            String query = 'SELECT Id, MVEX__Property__c, MVEX__Listing_Type__c, MVEX__PF_Listing_ID__c';
            for (String fieldName : fieldNames) {
                query += ', ' + fieldName;
            }
            query += ' FROM MVEX__Listing__c WHERE Id = :escapeListingId';

            List<SObject> records = Database.query(query, AccessLevel.USER_MODE);

            if (!records.isEmpty()) {
                SObject listingRecord = records[0];
                String propertyId = null;
                if (listingRecord.get('MVEX__Property__c') != null) {
                    propertyId = (String) listingRecord.get('MVEX__Property__c');
                }

                if (listingRecord.get('MVEX__PF_Listing_ID__c') != null) {
                    pfListingId = (String) listingRecord.get('MVEX__PF_Listing_ID__c');
                }

                List<Property_File__c> media = [SELECT Id, BaseUrl__c, ExternalLink__c, Tags__c, MVEX__Original_Height__c, MVEX__Original_Width__c, LastModifiedDate FROM Property_File__c WHERE Property__c = :propertyId AND IsOnPortalFeed__c = true WITH USER_MODE Order BY Sort_on_Portal_Feed__c ASC NULLS LAST, Name ASC];
                
                for (String key : jsonMap.keySet()) {
                    String label = (String) jsonMap.get(key);
                    finalMapping.put(label, listingRecord.get(key));
                }

                String resultBody = PropertyFinderJSONBuilder.buildJSON(finalMapping, media);
                if (actionName == 'create') {
                    propertyFinderCreateListing(resultBody, listingId, propertyFinderPortal.Id, apiKey, apiSecret, pfListingId);
                } else if (actionName == 'update') {
                    propertyFinderUpdateListing(resultBody, listingId, propertyFinderPortal.Id, apiKey, apiSecret, pfListingId);
                }
            }
            
        } catch (Exception e) {
            updatePortalListingRecord(listingId, portalId, e.getMessage(), 'Exception');
            ErrorHandler.insertErrorData(e, 'PropertyFinderIntegration', 'getListingRecordForSync', 'Error while getting listing record.');
        }
    }

    @future(callout= true)
    public static void propertyFinderCreateListing(String resultBody, String listingId, String portalId, String apiKey, String apiSecret, String pfListingId) {
        try {
            if (pfListingId == null) {
                String endpoint = propertyFinderProductionEndpoint + 'listings';
                String accessToken = getAccesstoken(apiKey, apiSecret);

                Http h3 = new Http();
                HttpRequest req3 = new HttpRequest();
                req3.setHeader('Content-Type', 'application/json');
                req3.setHeader('Authorization', 'Bearer ' + accessToken);
                req3.setBody(resultBody);
                req3.setMethod('POST');
                req3.setEndpoint(endpoint);
                
                HttpResponse res3 = h3.send(req3);
                
                String responseBody = res3.getBody();

                Map<String, Object> jsonMap = (Map<String, Object>) JSON.deserializeUntyped(res3.getBody());

                if (res3.getStatusCode() == 200) {
                    updateListingWithPFListingId(listingId, jsonMap);
                    String pfListingNewId = (String) jsonMap.get('id');
                    System.enqueueJob(new PropertyFinderPublishQueueable(pfListingNewId, portalId, apiKey, apiSecret, pfListingNewId));
                } else {
                    updatePortalListingRecord(listingId, portalId, responseBody, 'Failed');
                }
            } else {
                propertyFinderUpdateListing(resultBody, listingId, portalId, apiKey, apiSecret, pfListingId);
            }
        } catch (Exception e) {
            updatePortalListingRecord(listingId, portalId, e.getMessage(), 'Exception');
            ErrorHandler.insertErrorData(e, 'PropertyFinderIntegration', 'propertyFinderCreateAndUpdateListing', 'Error while creating or updating listing in PropertyFinder.');
        }
    }

    public static void propertyFinderUpdateListing(String resultBody, String listingId, String portalId, String apiKey, String apiSecret, String pfListingId) {
        try {
            String endpoint = propertyFinderProductionEndpoint + 'listings/' + pfListingId;
            String accessToken = getAccesstoken(apiKey, apiSecret);

            Http h3 = new Http();
            HttpRequest req3 = new HttpRequest();
            
            req3.setHeader('Content-Type', 'application/json');
            req3.setHeader('Authorization', 'Bearer ' + accessToken);
            req3.setBody(resultBody);
            req3.setMethod('PUT');
            req3.setEndpoint(endpoint);
            
            HttpResponse res3 = h3.send(req3);
            
            String responseBody = res3.getBody();

            Map<String, Object> jsonMap = (Map<String, Object>) JSON.deserializeUntyped(res3.getBody());

            if (res3.getStatusCode() == 200) {
                updatePortalListingRecord(listingId, portalId, responseBody, 'Success');
                System.enqueueJob(new PropertyFinderPublishQueueable(listingId, portalId, apiKey, apiSecret, pfListingId));
            } else {
                updatePortalListingRecord(listingId, portalId, responseBody, 'Failed');
            }
        } catch (Exception e) {
            updatePortalListingRecord(listingId, portalId, e.getMessage(), 'Exception');
            ErrorHandler.insertErrorData(e, 'PropertyFinderIntegration', 'propertyFinderCreateAndUpdateListing', 'Error while creating or updating listing in PropertyFinder.');
        }
    }

    @future(callout=true)
    public static void propertyFinderDeleteListings(String listingsJson) {
        try {
            Map<String, Map<String, String>> listingsMap = (Map<String, Map<String, String>>) JSON.deserialize(listingsJson, Map<String, Map<String, String>>.class);

            Set<String> portalIds = new Set<String>();
            for (Map<String, String> listing : listingsMap.values()) {
                portalIds.add(listing.get('portalId'));
            }

            List<Portal__c> portalPropertyFinder = [SELECT Id, Field_Mapping__c, Portal_Configuration__c, Is_Active__c FROM Portal__c 
                                                    WHERE Id IN :portalIds AND Is_Active__c = true WITH USER_MODE];

            if (portalPropertyFinder.isEmpty()) {
                return;
            }

            Map<Id, Portal__c> portalMap = new Map<Id, Portal__c>(portalPropertyFinder);
            
            Set<String> listingIds = listingsMap.keySet();
            String query = 'SELECT Id, MVEX__PF_Listing_ID__c FROM MVEX__Listing__c WHERE Id IN :listingIds';
            List<Listing__c> listings = Database.query(query, AccessLevel.USER_MODE);

            // Map to store PortalListing Id and response code for failed deletions
            Map<String, Object> failedDeletions = new Map<String, Object>();
            Map<String, Object> failedDeletionsForListings = new Map<String, Object>();

            Http h3 = new Http();
            for (Listing__c listing : listings) {
                Map<String, String> listingMap = listingsMap.get(listing.Id);
                Portal__c portal = portalMap.get(listingMap.get('portalId'));
                String portalListingId = listingMap.get('portalListingId');
                
                if (portal != null && listing.PF_Listing_ID__c != null) {
                    Map<String, Object> configMap = (Map<String, Object>) JSON.deserializeUntyped(portal.Portal_Configuration__c);
                    String apiKey = (String) configMap.get('apiKey');
                    String apiSecret = (String) configMap.get('apiSecret');

                    String endpoint = propertyFinderProductionEndpoint + 'listings/' + listing.PF_Listing_ID__c;
                    String accessToken = getAccesstoken(apiKey, apiSecret);

                    HttpRequest req3 = new HttpRequest();
                    req3.setHeader('Content-Type', 'application/json');
                    req3.setMethod('DELETE');
                    req3.setEndpoint(endpoint);
                    req3.setHeader('Authorization', 'Bearer ' + accessToken);

                    HttpResponse res3 = h3.send(req3);

                    if (res3.getStatusCode() != 200 && portalListingId != null) {
                        failedDeletions.put(portalListingId, res3.getBody());
                        failedDeletionsForListings.put(listing.Id, res3.getBody());
                    }
                }
            }
            updatePortalListingRecordForDeletion(failedDeletions, failedDeletionsForListings, listingIds);
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'PropertyFinderIntegration', 'propertyFinderDeleteListings', 'Error while deleting listing records on PropertyFinder.');
        }
    }

    // Method to update PortalListing__c for failed deletions and store response in API_Response_Unpublish__c.
    // Note: Successful deletions are not updated in PortalListing__c; only failed deletions are processed and logged.
    public static void updatePortalListingRecordForDeletion(Map<String, Object> failedDeletions, Map<String, Object> failedDeletionsForListings, Set<String> listingIds) {
        if (failedDeletions == null || failedDeletions.isEmpty()) {
            return;
        }
        try {
            List<PortalListing__c> toUpdate = [SELECT Id, API_Response_Unpublish__c, SystemIsActive__c FROM PortalListing__c
                                                WHERE Id IN :failedDeletions.keySet() WITH USER_MODE];

            List<PortalListing__c> updateList = new List<PortalListing__c>();
            for (PortalListing__c pl : toUpdate) {
                pl.API_Response_Unpublish__c = String.valueOf(failedDeletions.get(pl.Id));
                pl.SystemIsActive__c = true;
                updateList.add(pl);
            }
            if (!updateList.isEmpty()) {
                update as user updateList;
            }

            List<String> listingIdList = new List<String>(listingIds);
            for (String listingId : listingIdList) {
                String response = (String) failedDeletionsForListings.get(listingId);
                PlatformEventController.publishEvent('Failed Delete', response, 'Property Finder', listingId);
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'PropertyFinderIntegration', 'updatePortalListingRecordForDeletion', 'Error while updating failed deletion responses.');
        }
    }

    public static void updateListingWithPFListingId(String listingId, Map<String, Object> jsonMap) {
        try {
            String pfListingId = (String) jsonMap.get('id');
            if (pfListingId != null) {
                // Update the listing record with the Property Finder listing ID
                List<Listing__c> listingsToUpdate = [SELECT Id, PF_Listing_ID__c FROM Listing__c WHERE Id =: listingId WITH USER_MODE];
                if (!listingsToUpdate.isEmpty()) {
                    listingsToUpdate[0].PF_Listing_ID__c = pfListingId;
                    update as user listingsToUpdate;
                }
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'PropertyFinderIntegration', 'updateListingWithPFListingId', 'Error while updating listing with Property Finder listing ID.');
        }
    }

    public static void updatePortalListingRecord(String listingId, String portalId, String apiResponse, String status) {
        try {
            if (status == 'Success') {
                PortalListing__c newPortalListing = new PortalListing__c();
                newPortalListing.Listing__c = listingId;
                newPortalListing.Portal__c = portalId;
                newPortalListing.SystemIsActive__c = true;
                newPortalListing.Listed_Date__c = System.today();
                newPortalListing.API_Response__c = apiResponse;
                insert as user newPortalListing;  
            }
            PlatformEventController.publishEvent(status, apiResponse, 'Property Finder', listingId);
        } catch (Exception e) {
            PlatformEventController.publishEvent('Exception', e.getMessage(), 'Property Finder', listingId);
            ErrorHandler.insertErrorData(e, 'PropertyFinderIntegration', 'updatePortalListingRecord', 'Error while updating portal listing record.');
        }
    }

    public static String getAccesstoken(String apiKey, String apiSecret) {
        try {
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
}