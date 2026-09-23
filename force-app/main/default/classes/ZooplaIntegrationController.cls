/**
* Class Name : ZooplaIntegrationController
* Created By : Karan Singh
* Last Modified Date : 25/06/2024
* Last Modified By : Karan Singh
* @description : Used to integrate Portal.
*/
public with sharing class ZooplaIntegrationController {

    public static String zooplaEndpoint = System.label.Zoopla_Endpoint;
    public static String zooplaDocEndpoint = System.label.Zoopla_Doc_Endpoint;

    public class ListingResponse {
        @AuraEnabled
        public String status;
        @AuraEnabled
        public String message;
        @AuraEnabled
        public List<Map<String, Object>> data;
    }
    
    @AuraEnabled
    public static ListingResponse zooplaGetListing(String portalId) {
        ListingResponse response = new ListingResponse();
        try {
            String escapedPortalId = String.escapeSingleQuotes(portalId);
            List<Portal__c> portalZoopla = [SELECT Id, Field_Mapping__c, Portal_Configuration__c, Is_Active__c FROM Portal__c 
                                            WHERE Id = :escapedPortalId AND Is_Active__c = true WITH USER_MODE LIMIT 1];
            
            if (portalZoopla.isEmpty()) {
                response.status = 'Failed';
                response.message = 'Portal configuration is missing.';
                return response;
            }
            
            Portal__c zooplaPortal = portalZoopla[0];
            Map<String, Object> configMap = (Map<String, Object>) JSON.deserializeUntyped(zooplaPortal.Portal_Configuration__c);
            
            String branchId = (String) configMap.get('branch_reference');
            Boolean isSandbox = configMap.containsKey('is_test_portal') ? Boolean.valueOf((String) configMap.get('is_test_portal')) : true;
            String certificateName = (String) configMap.get('certificate');
            
            String endpoint = isSandbox 
                ? zooplaEndpoint + 'sandbox/v2/listing/list' 
                : zooplaEndpoint + 'live/v2/listing/list';
            
            Http h3 = new Http();
            HttpRequest req3 = new HttpRequest();
            
            req3.setClientCertificateName(certificateName);
            req3.setHeader('Content-Type', 'application/json; profile=' + zooplaDocEndpoint + 'listing/list.json');
            req3.setBody('{ "branch_reference": "' + branchId + '" }');
            req3.setMethod('POST');
            req3.setEndpoint(endpoint);
            
            HttpResponse res3 = h3.send(req3);
            
            if (res3.getStatusCode() != 200) {
                response.status = 'Failed';
                response.message = res3.getBody();
                return response;
            }

            // Parse JSON response
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res3.getBody());
            
            List<Map<String, Object>> listings = new List<Map<String, Object>>();
            if (responseMap.containsKey('listings') && responseMap.get('listings') instanceof List<Object>) {
                for (Object obj : (List<Object>) responseMap.get('listings')) {
                    if (obj instanceof Map<String, Object>) {
                        listings.add((Map<String, Object>) obj);
                    }
                }
            }

            Set<String> listingReferences = new Set<String>();
            Map<String, String> listingUrls = new Map<String, String>();
            
            for (Map<String, Object> listing : listings) {
                String listingReference = (String) listing.get('listing_reference');
                String url = (String) listing.get('url');
                listingReferences.add(listingReference);
                listingUrls.put(listingReference, url);
            }
            
            // SOQL query to fetch matching records based on listing_reference
            List<Listing__c> properties = [SELECT Id, Name, Broker_s_Listing_ID__c FROM Listing__c WHERE Broker_s_Listing_ID__c IN :listingReferences 
                                            WITH USER_MODE ORDER BY Name ASC LIMIT 50000];
            
            // Prepare response
            List<Map<String, Object>> resultData = new List<Map<String, Object>>();
            
            for (Listing__c property : properties) {
                Map<String, Object> resultItem = new Map<String, Object>();
                resultItem.put('id', property.Id);
                resultItem.put('name', property.Name);
                resultItem.put('listing_reference', property.Broker_s_Listing_ID__c);
                resultItem.put('url', listingUrls.get(property.Broker_s_Listing_ID__c));
                resultData.add(resultItem);
            }
            
            response.status = 'Success';
            response.data = resultData;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'ZooplaIntegrationController', 'zooplaGetListing', 'Error while getting listing list from Zoopla.');
            response.status = 'Failed';
            response.message = e.getMessage();
        }
        return response;
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
            List<Portal__c> portalZoopla = [SELECT Id, Field_Mapping__c, Portal_Configuration__c, Is_Active__c FROM Portal__c 
                                            WHERE Id =: escapedPortalId AND Is_Active__c = true WITH USER_MODE LIMIT 1];

            if (portalZoopla.isEmpty()) {
                updatePortalListingRecord(listingId, portalId, 'Portal configuration is missing.', 'Exception');
                return;
            }

            Portal__c zooplaPortal = portalZoopla[0];

            Map<String, Object> jsonMap = (Map<String, Object>) JSON.deserializeUntyped(zooplaPortal.Field_Mapping__c);
            Map<String, Object> configMap = (Map<String, Object>) JSON.deserializeUntyped(zooplaPortal.Portal_Configuration__c);
            Map<String, Object> finalMapping = new Map<String, Object>();

            finalMapping.put('branch_reference', configMap.get('branch_reference'));
            Boolean isSandbox = configMap.containsKey('is_test_portal') ? Boolean.valueOf((String) configMap.get('is_test_portal')) : true;
            String certificateName = (String) configMap.get('certificate');

            List<String> fieldNames = new List<String>();
            for (String key : jsonMap.keySet()) {
                fieldNames.add(key);
            }

            String query = 'SELECT Id, MVEX__Property__c';
            for (String fieldName : fieldNames) {
                query += ', ' + fieldName;
            }
            query += ' FROM MVEX__Listing__c WHERE Id = :escapedListingId LIMIT 1';

            List<SObject> records = Database.query(query, AccessLevel.USER_MODE);

            if (!records.isEmpty()) {
                SObject listingRecord = records[0];
                String propertyId = (String) listingRecord.get('MVEX__Property__c');
                String escapedPropertyId = String.escapeSingleQuotes(propertyId);
                if (propertyId != null) {
                    List<Property_File__c> media = [SELECT Id, BaseUrl__c, ExternalLink__c, Tags__c FROM Property_File__c WHERE Property__c = :escapedPropertyId AND IsOnPortalFeed__c = true WITH USER_MODE ORDER BY Sort_on_Portal_Feed__c ASC NULLS LAST, Name ASC LIMIT 50000];

                    for (String key : jsonMap.keySet()) {
                        String label = (String) jsonMap.get(key);
                        finalMapping.put(label, listingRecord.get(key));
                    }

                    String requestBody = ZooplaJSONController.createInputData(finalMapping, media);
                    zooplaCreateAndUpdateListing(requestBody, portalZoopla[0].Id, records[0].Id, isSandbox, certificateName);
                }
            }
        } catch (Exception e) {
            updatePortalListingRecord(listingId, portalId, e.getMessage(), 'Exception');
            ErrorHandler.insertErrorData(e, 'ZooplaIntegrationController', 'getListingRecordForSync', 'Error while getting listing record.');
        }
    }

    /**
    * Method Name : zooplaCreateAndUpdateListing
    * @param requestBody - String
    * @param portalId - String
    * @param listingId - String
    * @param isSandbox - Boolean
    * @param certificateName - String
    * @description : Used to create and update listing in Zoopla.
    */
    @future(callout= true)
    public static void zooplaCreateAndUpdateListing(String requestBody, String portalId, String listingId, Boolean isSandbox, String certificateName) {
        try {
            String endpoint = isSandbox 
                ? zooplaEndpoint + 'sandbox/v2/listing/update' 
                : zooplaEndpoint + 'live/v2/listing/update';
            
            Http h3 = new Http();
            HttpRequest req3 = new HttpRequest();
            
            req3.setClientCertificateName(certificateName);
            req3.setHeader('Content-Type', 'application/json; profile=' + zooplaDocEndpoint + 'listing/update.json');
            req3.setHeader('ZPG-Listing-ETag', '');
            req3.setBody(requestBody);
            req3.setMethod('POST');
            req3.setEndpoint(endpoint);
            
            HttpResponse res3 = h3.send(req3);

            String responseBody = res3.getBody();

            if (res3.getStatusCode() == 200) {
                updatePortalListingRecord(listingId, portalId, responseBody, 'Success');
            } else {
                updatePortalListingRecord(listingId, portalId, responseBody, 'Failed');
            }
        } catch (Exception e) {
            updatePortalListingRecord(listingId, portalId, e.getMessage(), 'Exception');
            ErrorHandler.insertErrorData(e, 'ZooplaIntegrationController', 'zooplaCreateAndUpdateListing', 'Error while creating or updating listing in Zoopla.');
        }
    }

    /**
    * Method Name : zooplaDeleteListing
    * @param listingId - String
    * @description : Used to delete listing from Zoopla.
    */
    @future(callout=true)
    public static void zooplaDeleteListings(String listingsJson) {
        try {
            Map<String, Map<String, String>> listingsMap = (Map<String, Map<String, String>>) JSON.deserialize(listingsJson, Map<String, Map<String, String>>.class);
            
            Set<String> portalIds = new Set<String>();
            for (Map<String, String> listing : listingsMap.values()) {
                portalIds.add(listing.get('portalId'));
            }

            List<Portal__c> portalZoopla = [SELECT Id, Field_Mapping__c, Portal_Configuration__c, Is_Active__c FROM Portal__c WHERE Id IN :portalIds 
                                                AND Is_Active__c = true WITH USER_MODE];

            if (portalZoopla.isEmpty()) {
                return;
            }

            Map<Id, Portal__c> portalMap = new Map<Id, Portal__c>(portalZoopla);
            
            Set<String> listingIds = listingsMap.keySet();
            String query = 'SELECT Id, MVEX__Status__c, MVEX__Broker_s_Listing_ID__c FROM MVEX__Listing__c WHERE Id IN :listingIds';
            List<Listing__c> listings = Database.query(query, AccessLevel.USER_MODE);

            Http h3 = new Http();
            for (Listing__c listing : listings) {
                Map<String, String> listingMap = listingsMap.get(listing.Id);
                Portal__c portal = portalMap.get(listingMap.get('portalId'));
                
                if (portal != null) {
                    Map<String, Object> configMap = (Map<String, Object>) JSON.deserializeUntyped(portal.Portal_Configuration__c);
                    Boolean isSandbox = configMap.containsKey('is_test_portal') ? Boolean.valueOf((String) configMap.get('is_test_portal')) : true;
                    String certificateName = (String) configMap.get('certificate');
                    
                    String endpoint = isSandbox 
                        ? zooplaEndpoint + 'sandbox/v2/listing/delete' 
                        : zooplaEndpoint + 'live/v2/listing/delete';

                    HttpRequest req3 = new HttpRequest();
                    req3.setClientCertificateName(certificateName);
                    req3.setHeader('Content-Type', 'application/json; profile=' + zooplaDocEndpoint + 'listing/delete.json');
                    req3.setBody('{ "listing_reference": "' + listing.Broker_s_Listing_ID__c + '" }');
                    req3.setMethod('POST');
                    req3.setEndpoint(endpoint);
                    
                    HttpResponse res3 = h3.send(req3);
                }
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'ZooplaIntegrationController', 'zooplaDeleteListings', 'Error while deleting listing records on Zoopla.');
        }
    }

    /**
    * Class Name : PropertyPortalWrapper
    * @description : Used to create property portal wrapper.
    */
    public class PropertyPortalWrapper {
        public String branch_reference;
        public String branch_name;
        public String street_name;
        public String town_or_city;
        public String postal_code;
        public String country_code;
        public String locality;
        public String county;
        public String latitude;
        public String longitude;
        public String address_key;
        public String organisation_key;
        public String postcode_type;
        public String paf_udprn;
        public String telephone;
        public String email;
        public String website;
        public String is_test_portal;
    }

    /**
    * Method Name : zooplaCreateAndUpdateBranch
    * @param portalWrapper - String
    * @param portalId - String
    * @description : Used to create and update branch in Zoopla.
    */
    @future(callout= true)
    public static void zooplaCreateAndUpdateBranch(String portalWrapper, String portalId) {
        try {
            String escapedPortalId = String.escapeSingleQuotes(portalId);

            PropertyPortalWrapper wrapper = (PropertyPortalWrapper)JSON.deserialize(portalWrapper, PropertyPortalWrapper.class);
            
            String requestBody = BranchCreateAndUpdateJSON.buildJSON(
                wrapper.branch_reference,
                wrapper.branch_name,
                wrapper.street_name,
                wrapper.locality,
                wrapper.town_or_city,
                wrapper.county,
                wrapper.postal_code,
                wrapper.country_code,
                wrapper.latitude,
                wrapper.longitude,
                wrapper.address_key,
                wrapper.organisation_key,
                wrapper.paf_udprn,
                wrapper.postcode_type,
                wrapper.telephone,
                wrapper.email,
                wrapper.website
            );

            Boolean isSandbox = Boolean.valueOf(wrapper.is_test_portal);

            String endpoint = isSandbox 
                    ? zooplaEndpoint + 'sandbox/v2/branch/update' 
                    : zooplaEndpoint + 'live/v2/branch/update';

            Http h3 = new Http();
            HttpRequest req3 = new HttpRequest();
            
            req3.setClientCertificateName('zoopla_certificate');
            req3.setHeader('Content-Type', 'application/json; profile=' + zooplaDocEndpoint + 'branch/update.json');
            req3.setBody(requestBody);
            req3.setMethod('POST');
            req3.setEndpoint(endpoint);
            
            HttpResponse res3 = h3.send(req3);
            
            String responseBody = res3.getBody();

            List<Portal__c> portalList = [SELECT Id, Is_Active__c, Response__c FROM Portal__c WHERE Is_Active__c = true AND Id =: escapedPortalId WITH USER_MODE LIMIT 1];

            if (res3.getStatusCode() != 200) {
                PlatformEventController.publishEvent('Failed', responseBody, 'Zoopla Branch', !portalList.isEmpty() ? portalList[0].Id : null);
                if (!portalList.isEmpty()) {
                    delete as user portalList;
                }

            } else {
                if (!portalList.isEmpty()) {
                    portalList[0].Response__c = responseBody;
                    update as user portalList;   
                }
            }
            
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'ZooplaIntegrationController', 'zooplaCreateAndUpdateBranch', 'Error while creating or updating Branch in Zoopla.');
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
            PlatformEventController.publishEvent(status, apiResponse, 'Zoopla', listingId);
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'ZooplaIntegrationController', 'updatePortalListingRecord', 'Error while updating portal listing record.');
        }
    }
}