/**
* Class Name : RightmoveIntegrationController
* Created By : Karan Singh
* Last Modified Date : 25/06/2024
* Last Modified By : Karan Singh
* @description : Used to integrate Rightmove.
*/
public with sharing class RightmoveIntegrationController {

    public static String rightmoveProductionEndpoint = System.label.Rightmove_Endpoint_Production;
    public static String rightmoveSandboxEndpoint = System.label.Rightmove_Endpoint_Sandbox;

    public class ListingResponse {
        @AuraEnabled
        public String status;
        @AuraEnabled
        public String message;
        @AuraEnabled
        public List<Map<String, Object>> data;
    }

    /**
    * Method Name : rightmoveGetListing
    * @description : Used to get listing from Rightmove.
    */
    @AuraEnabled
    public static ListingResponse rightmoveGetListing(String portalId) {
        ListingResponse response = new ListingResponse();
        try {
            String escapedPortalId = String.escapeSingleQuotes(portalId);

            List<Portal__c> portalRightmove = [SELECT Id, Field_Mapping__c, Portal_Configuration__c, Is_Active__c FROM Portal__c WHERE Id =: escapedPortalId AND Is_Active__c = true WITH USER_MODE LIMIT 1];

            if (portalRightmove.isEmpty()) {
                response.status = 'Failed';
                response.message = 'Portal configuration is missing.';
                return response;
            }

            Portal__c rightmovePortal = portalRightmove[0];

            Map<String, Object> configMap = (Map<String, Object>) JSON.deserializeUntyped(rightmovePortal.Portal_Configuration__c);

            Integer branchId = Integer.valueOf((String) configMap.get('branch.branch_id'));
            Integer networkId = Integer.valueOf((String) configMap.get('network.network_id'));
            Boolean isSandbox = configMap.containsKey('is_test_portal') ? Boolean.valueOf((String) configMap.get('is_test_portal')) : true;
            String certificateName = (String) configMap.get('certificate');

            String endpoint = isSandbox 
                ? rightmoveSandboxEndpoint + 'getbranchpropertylist' 
                : rightmoveProductionEndpoint + 'getbranchpropertylist';

            Http h3 = new Http();
            HttpRequest req3 = new HttpRequest();
            
            req3.setClientCertificateName(certificateName);
            req3.setHeader('Content-Type', 'application/json;');
            req3.setBody('{ "network": { "network_id": ' + networkId + ' }, "branch": { "branch_id": ' + branchId + ' }}');
            req3.setMethod('POST');
            req3.setEndpoint(endpoint);
            
            HttpResponse res3 = h3.send(req3);
            
            if (res3.getStatusCode() != 200) {
                response.status = 'Failed';
                response.message = res3.getBody();
                return response;
            }

            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res3.getBody());
            
            List<Map<String, Object>> listings = new List<Map<String, Object>>();
            if (responseMap.containsKey('property') && responseMap.get('property') instanceof List<Object>) {
                for (Object obj : (List<Object>) responseMap.get('property')) {
                    if (obj instanceof Map<String, Object>) {
                        listings.add((Map<String, Object>) obj);
                    }
                }
            }

            Set<String> listingReferences = new Set<String>();
            Map<String, Map<String, Object>> listingInfo = new Map<String, Map<String, Object>>();
            
            for (Map<String, Object> listing : listings) {
                String listingReference = (String) listing.get('agent_ref');
                Integer rightmoveId = (Integer) listing.get('rightmove_id');
                String updateDate = (String) listing.get('update_date');
                String channel = listing.get('channel') == 1 ? 'Sales' : 'Lettings';
                listingReferences.add(listingReference);

                Map<String, Object> listingDetails = new Map<String, Object>();
                listingDetails.put('rightmoveId', rightmoveId);
                listingDetails.put('updateDate', updateDate);
                listingDetails.put('channel', channel);
                
                listingInfo.put(listingReference, listingDetails);
            }
            
            List<Listing__c> properties = [SELECT Id, Name, Broker_s_Listing_ID__c FROM Listing__c 
                                            WHERE Broker_s_Listing_ID__c IN :listingReferences WITH USER_MODE ORDER BY Name ASC];
            
            List<Map<String, Object>> resultData = new List<Map<String, Object>>();
            
            for (Listing__c property : properties) {
                Map<String, Object> resultItem = new Map<String, Object>();
                resultItem.put('id', property.Id);
                resultItem.put('name', property.Name);
                resultItem.put('listing_reference', property.Broker_s_Listing_ID__c);
                resultItem.put('rightmoveId', listingInfo.get(property.Broker_s_Listing_ID__c).get('rightmoveId'));
                resultItem.put('updateDate', listingInfo.get(property.Broker_s_Listing_ID__c).get('updateDate'));
                resultItem.put('channel', listingInfo.get(property.Broker_s_Listing_ID__c).get('channel'));
                resultData.add(resultItem);
            }
            
            response.status = 'Success';
            response.data = resultData;

            return response;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'RightmoveIntegrationController', 'rightmoveGetListing', 'Error while getting listing list from Rightmove.');
            response.status = 'Failed';
            response.message = e.getMessage();
            return response;
        }
    }

    /**
    * Method Name : getListingRecordForSync
    * @param listingId - String
    * @description : Used to get listing record for sync.
    */
    @AuraEnabled
    public static void getListingRecordForSync(String listingId, String portalId) {
        try {
            String escapedListingId = String.escapeSingleQuotes(listingId);
            String escapedPortalId = String.escapeSingleQuotes(portalId);

            List<Portal__c> portalRightmove = [SELECT Id, Field_Mapping__c, Portal_Configuration__c, Is_Active__c FROM Portal__c WHERE Id =: escapedPortalId AND Is_Active__c = true WITH USER_MODE LIMIT 1];

            if (portalRightmove.isEmpty()) {
                updatePortalListingRecord(listingId, portalId, 'Portal configuration is missing.', 'Exception');
                return;
            }

            Portal__c rightmovePortal = portalRightmove[0];

            Map<String, Object> jsonMap = (Map<String, Object>) JSON.deserializeUntyped(rightmovePortal.Field_Mapping__c);
            Map<String, Object> configMap = (Map<String, Object>) JSON.deserializeUntyped(rightmovePortal.Portal_Configuration__c);
            Map<String, Object> finalMapping = new Map<String, Object>();

            finalMapping.put('branch.branch_id', configMap.get('branch.branch_id'));
            finalMapping.put('network.network_id', configMap.get('network.network_id'));
            Boolean isSandbox = configMap.containsKey('is_test_portal') ? Boolean.valueOf((String) configMap.get('is_test_portal')) : true;
            String certificateName = (String) configMap.get('certificate');

            List<String> fieldNames = new List<String>();
            for (String key : jsonMap.keySet()) {
                fieldNames.add(key);
            }

            String query = 'SELECT Id, MVEX__Property__c, MVEX__Listing_Type__c';
            for (String fieldName : fieldNames) {
                query += ', ' + fieldName;
            }
            query += ' FROM MVEX__Listing__c WHERE Id = :escapedListingId';

            List<SObject> records = Database.query(query, AccessLevel.USER_MODE);

            if (!records.isEmpty()) {
                SObject listingRecord = records[0];
                String propertyId = (String) listingRecord.get('MVEX__Property__c');
                String listingType = (String) listingRecord.get('MVEX__Listing_Type__c');

                finalMapping.put('branch.channel', listingType == 'Sale' ? 1 : 2);
                finalMapping.put('branch.overseas', isOverseas(listingRecord));

                List<Property_File__c> media = [SELECT Id, BaseUrl__c, ExternalLink__c, Tags__c, LastModifiedDate FROM Property_File__c WHERE Property__c = :propertyId AND IsOnPortalFeed__c = true WITH USER_MODE Order BY Sort_on_Portal_Feed__c ASC NULLS LAST, Name ASC];

                for (String key : jsonMap.keySet()) {
                    String label = (String) jsonMap.get(key);
                    finalMapping.put(label, listingRecord.get(key));
                }

                String resultBody = RightmoveJSONController.buildJSON(finalMapping, media, 'Rightmove');
                rightmoveCreateAndUpdateListing(resultBody, listingId, rightmovePortal.Id, certificateName, isSandbox);
            }
            
        } catch (Exception e) {
            updatePortalListingRecord(listingId, portalId, e.getMessage(), 'Exception');
            ErrorHandler.insertErrorData(e, 'RightmoveIntegrationController', 'getListingRecordForSync', 'Error while getting listing record.');
        }
    }

    public static Boolean isOverseas(SObject listingRecord) {
        try {
            Boolean isOverseas = false;
            String isOversea = (String) listingRecord.get('MVEX__Is_Overseas__c');
            if (isOversea != null && isOversea != '') {
                isOverseas = Boolean.valueOf(isOversea);
            }
            return isOverseas;
        } catch (Exception e) {
            return false;
        }
    }

    /**
    * Method Name : rightmoveCreateAndUpdateListing
    * @param resultBody - String
    * @param listingId - String
    * @param portalId - String
    * @param certificateName - String
    * @param isSandbox - Boolean
    * @description : Used to create and update listing in Rightmove.
    */
    @future(callout= true)
    public static void rightmoveCreateAndUpdateListing(String resultBody, String listingId, String portalId, String certificateName, Boolean isSandbox) {
        try {
            String endpoint = isSandbox 
                ? rightmoveSandboxEndpoint + 'sendpropertydetails' 
                : rightmoveProductionEndpoint + 'sendpropertydetails';

            Http h3 = new Http();
            HttpRequest req3 = new HttpRequest();
            
            req3.setClientCertificateName(certificateName);
            req3.setHeader('Content-Type', 'application/json;');
            req3.setBody(resultBody);
            req3.setMethod('POST');
            req3.setEndpoint(endpoint);
            
            HttpResponse res3 = h3.send(req3);
            
            String responseBody = res3.getBody();

            Map<String, Object> jsonMap = (Map<String, Object>) JSON.deserializeUntyped(res3.getBody());
            Boolean successValue = (Boolean) jsonMap.get('success');

            if (res3.getStatusCode() == 200 && successValue) {
                updatePortalListingRecord(listingId, portalId, responseBody, 'Success');
            } else {
                updatePortalListingRecord(listingId, portalId, responseBody, 'Failed');
            }
        } catch (Exception e) {
            updatePortalListingRecord(listingId, portalId, e.getMessage(), 'Exception');
            ErrorHandler.insertErrorData(e, 'RightmoveIntegrationController', 'rightmoveCreateAndUpdateListing', 'Error while creating or updating listing in Rightmove.');
        }
    }

    /**
    * Method Name : rightmoveDeleteListing
    * @param listingId - String
    * @description : Used to delete listing from Rightmove.
    */
    @future(callout=true)
    public static void rightmoveDeleteListings(String listingsJson) {
        try {
            Map<String, Map<String, String>> listingsMap = (Map<String, Map<String, String>>) JSON.deserialize(listingsJson, Map<String, Map<String, String>>.class);
            
            Set<String> portalIds = new Set<String>();
            for (Map<String, String> listing : listingsMap.values()) {
                portalIds.add(listing.get('portalId'));
            }

            List<Portal__c> portalRightmove = [SELECT Id, Field_Mapping__c, Portal_Configuration__c, Is_Active__c FROM Portal__c 
                                                WHERE Id IN :portalIds AND Is_Active__c = true WITH USER_MODE];

            if (portalRightmove.isEmpty()) {
                return;
            }

            Map<Id, Portal__c> portalMap = new Map<Id, Portal__c>(portalRightmove);
            
            Set<String> listingIds = listingsMap.keySet();
            String query = 'SELECT Id, MVEX__Status__c, MVEX__Broker_s_Listing_ID__c FROM MVEX__Listing__c WHERE Id IN :listingIds';
            List<Listing__c> listings = Database.query(query, AccessLevel.USER_MODE);

            Http h3 = new Http();
            for (Listing__c listing : listings) {
                Map<String, String> listingMap = listingsMap.get(listing.Id);
                Portal__c portal = portalMap.get(listingMap.get('portalId'));
                
                if (portal != null) {
                    Map<String, Object> configMap = (Map<String, Object>) JSON.deserializeUntyped(portal.Portal_Configuration__c);
                    Integer branchId = Integer.valueOf((String) configMap.get('branch.branch_id'));
                    Integer networkId = Integer.valueOf((String) configMap.get('network.network_id'));
                    Boolean isSandbox = configMap.containsKey('is_test_portal') ? Boolean.valueOf((String) configMap.get('is_test_portal')) : true;
                    String certificateName = (String) configMap.get('certificate');

                    String endpoint = isSandbox 
                        ? rightmoveSandboxEndpoint + 'removeproperty' 
                        : rightmoveProductionEndpoint + 'removeproperty';

                    String body = '{ "network": { "network_id": ' + networkId + '}, "branch": { "branch_id": ' + branchId + ' }, "property": { "agent_ref": "' + listing.Broker_s_Listing_ID__c + '" }}';

                    HttpRequest req3 = new HttpRequest();
                    req3.setClientCertificateName(certificateName);
                    req3.setHeader('Content-Type', 'application/json;');
                    req3.setBody(body);
                    req3.setMethod('POST');
                    req3.setEndpoint(endpoint);
                    
                    HttpResponse res3 = h3.send(req3);
                }
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'RightmoveIntegrationController', 'rightmoveDeleteListings', 'Error while deleting listing records on Rightmove.');
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
            PlatformEventController.publishEvent(status, apiResponse, 'Rightmove', listingId);
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'RightmoveIntegrationController', 'updatePortalListingRecord', 'Error while updating portal listing record.');
        }
    }
}