/**
* Class Name : PortalSyndicationController
* Test Class : PortalSyndicationControllerTest
* Created By : Karan Singh
* Last Modified Date : 24/12/2024
* Last Modified By : Karan Singh
* @description : Used to create and manage MVEX__PortalListing__c records.
*/
public with sharing class PortalSyndicationController {

    /**
    * Method Name : createPortalListingRecord
    * @param listingId to stored the Listing record Id
    * @param portalId to stored the Portal record Id
    * @param actionType to stored the action type
    * @param portalName to stored the portal name
    * @return String value
    * @description : Used to create and manage MVEX__PortalListing__c records.
    */
    @AuraEnabled
    public static string createPortalListingRecord(String listingId, String portalId, String actionType, String portalName){
        try {
            List<String> portalNames = new List<String>{'Zoopla', 'Rightmove', 'Rightmove Overseas', 'Propertyfinder'};

            if (actionType == 'Publish' && !portalNames.contains(portalName)) {
                MVEX__PortalListing__c newPortalListing = new MVEX__PortalListing__c();
                newPortalListing.MVEX__Listing__c = listingId;
                newPortalListing.MVEX__Portal__c = portalId;
                newPortalListing.MVEX__SystemIsActive__c = true;
                newPortalListing.MVEX__Listed_Date__c = System.today();
                insert as user newPortalListing;   
            } else if (actionType == 'Publish' && portalNames.contains(portalName)) {
                if (portalName == 'Zoopla') {
                    ZooplaIntegrationController.getListingRecordForSync(listingId, portalId);
                } else if (portalName == 'Rightmove') {
                    RightmoveIntegrationController.getListingRecordForSync(listingId, portalId);
                } else if (portalName == 'Rightmove Overseas') {
                    RightmoveOverseaIntegration.getListingRecordForSync(listingId, portalId);
                } else if (portalName == 'Propertyfinder') {
                    PropertyFinderIntegration.getListingRecordForSync(listingId, portalId, 'create');
                }
            } else if (actionType == 'Unpublish' && portalNames.contains(portalName)) {
                Map<String, Map<String, String>> listingsMap = new Map<String, Map<String, String>>();
                listingsMap.put(listingId, new Map<String, String>{
                    'listingId' => listingId,
                    'portalId' => portalId
                });
                String listingsJson = JSON.serialize(listingsMap);

                if (portalName == 'Zoopla') {
                    ZooplaIntegrationController.zooplaDeleteListings(listingsJson);
                } else if (portalName == 'Rightmove' || portalName == 'Rightmove Overseas') {
                    RightmoveIntegrationController.rightmoveDeleteListings(listingsJson);
                } else if (portalName == 'Propertyfinder') {
                    PropertyFinderIntegration.propertyFinderDeleteListings(listingsJson);
                }
            } else if (actionType == 'Unpublish' && !portalNames.contains(portalName)) {
                String escapeListingId = String.escapeSingleQuotes(listingId);
                String escapePortalId = String.escapeSingleQuotes(portalId);
                List<MVEX__PortalListing__c> portalListings = [SELECT Id, MVEX__SystemIsActive__c FROM MVEX__PortalListing__c WHERE MVEX__Listing__c =: escapeListingId
                                                        AND MVEX__Portal__c =: escapePortalId AND MVEX__SystemIsActive__c = true WITH USER_MODE];
                if (!portalListings.isEmpty()) {
                    for (MVEX__PortalListing__c portalListing : portalListings) {
                        portalListing.MVEX__SystemIsActive__c = false;
                        portalListing.MVEX__UnlistedDate__c = System.today();
                    }

                    update as user portalListings;
                }
            } else {
                return 'Invalid action type or portal name.';
            }

            return 'Success';

        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'PortalSyndicationController', 'createPortalListingRecord', 'Error while updating or creating MVEX__PortalListing__c record.');
            return e.getMessage();
        }
    }

    /**
    * Method Name : fetchPortals
    * @param listingId to stored the Listing record Id
    * @return List<PortalWrapper> that contains portal data.
    * @description : Used to fetch portal records.
    */
    @AuraEnabled
    public static FetchPortalListingRecord fetchPortals(String listingId){
        try {
            FetchPortalListingRecord portalWrpList = new FetchPortalListingRecord();
            portalWrpList.portalData = new List<PortalWrapper>();

            List<MVEX__Portal__c> portalList = new List<MVEX__Portal__c>([SELECT Id, Name, MVEX__Generator__c, (SELECT Id, MVEX__SystemIsActive__c FROM MVEX__Portals_Listing__r WHERE MVEX__SystemIsActive__c = true and MVEX__Listing__c =: listingId) FROM MVEX__Portal__c WHERE MVEX__Is_Active__c = TRUE WITH USER_MODE ORDER BY CreatedDate DESC LIMIT 1000]);

            Map<String, List<MVEX__PortalListing__c>> portalStatuCheck = new Map<String, List<MVEX__PortalListing__c>>();

            for (MVEX__Portal__c portal : portalList) {
                if (portal.MVEX__Portals_Listing__r != null && portal.MVEX__Portals_Listing__r.size() > 0) {
                    portalStatuCheck.put(portal.Id, portal.MVEX__Portals_Listing__r);
                } else {
                    portalStatuCheck.put(portal.Id, null);
                }
            }

            for (MVEX__Portal__c portal : portalList) {
                PortalWrapper portalWrapper = new PortalWrapper();
                portalWrapper.id = portal.Id;
                portalWrapper.name = portal.Name;
                portalWrapper.pname = portal.MVEX__Generator__c;
                portalWrapper.status = portalStatuCheck?.get(portal?.Id) != null && portalStatuCheck?.get(portal?.Id)?.size() > 0 ? 'Active' : 'Inactive';
                if (portalWrapper.status == 'Active') {
                    portalWrapper.buttonColor = 'destructive';
                    portalWrapper.buttonLabel = 'Unpublish';
                    portalWrapper.badgeColor = 'slds-badge slds-theme_success';
                    portalWrapper.flag = true;
                } else {
                    portalWrapper.buttonColor = 'brand';
                    portalWrapper.buttonLabel = 'Publish';
                    portalWrapper.badgeColor = 'slds-badge';
                    portalWrapper.flag = false;

                }
                portalWrpList.portalData.add(portalWrapper);
            }

            portalWrpList.zooplaFieldMappings = getZooplaFieldMappings();

            return portalWrpList;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'PortalSyndicationController', 'fetchPortals', 'Error while fetching portal records.');
            return null;
        }
    }

    /**
    * Method Name : getZooplaFieldMappings
    * @return Map<String, String> of lowercase portal field name to Listing field label.
    * @description : Used to get mapping between Zoopla portal fields and Salesforce Listing field labels.
    */
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getZooplaFieldMappings() {
        try {
            Map<String, String> fieldMappingMap = new Map<String, String>();

            Map<String, String> apiNameToLabelMap = new Map<String, String>();
            Schema.DescribeSObjectResult describeResult;
            if (Schema.getGlobalDescribe().containsKey('MVEX__Listing__c')) {
                describeResult = Schema.getGlobalDescribe().get('MVEX__Listing__c').getDescribe();
            } else if (Schema.getGlobalDescribe().containsKey('Listing__c')) {
                describeResult = Schema.getGlobalDescribe().get('Listing__c').getDescribe();
            }

            if (describeResult != null) {
                for (Schema.SObjectField field : describeResult.fields.getMap().values()) {
                    Schema.DescribeFieldResult dfr = field.getDescribe();
                    apiNameToLabelMap.put(dfr.getName().toLowerCase(), dfr.getLabel());
                }
            }

            List<MVEX__Portal_Listing_Mapping__c> mappings = [
                SELECT Id, Name, MVEX__Listing_Field_API_Name__c 
                FROM MVEX__Portal_Listing_Mapping__c 
                WHERE MVEX__Portal_Name__c = 'Zoopla' 
                AND MVEX__Listing_Field_API_Name__c != null 
                WITH USER_MODE
            ];

            for (MVEX__Portal_Listing_Mapping__c mapping : mappings) {
                if (String.isNotBlank(mapping.Name) && String.isNotBlank(mapping.MVEX__Listing_Field_API_Name__c)) {
                    String apiName = mapping.MVEX__Listing_Field_API_Name__c.trim();
                    String label = apiNameToLabelMap.get(apiName.toLowerCase());
                    if (String.isBlank(label)) {
                        String cleanApiName = apiName.replaceFirst('(?i)^mvex__', '');
                        label = apiNameToLabelMap.get(cleanApiName.toLowerCase());
                    }
                    if (String.isBlank(label)) {
                        label = apiNameToLabelMap.get(('mvex__' + apiName).toLowerCase());
                    }
                    fieldMappingMap.put(mapping.Name.toLowerCase(), String.isNotBlank(label) ? label : apiName);
                }
            }

            // Default mappings for media / content
            fieldMappingMap.put('content', 'Listing Media');
            fieldMappingMap.put('content.url', 'Listing Media (URL)');
            fieldMappingMap.put('content.type', 'Listing Media (Type)');

            // Map base parent names if child is mapped
            if (fieldMappingMap.containsKey('detailed_description.text') && !fieldMappingMap.containsKey('detailed_description')) {
                fieldMappingMap.put('detailed_description', fieldMappingMap.get('detailed_description.text'));
            }

            return fieldMappingMap;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'PortalSyndicationController', 'getZooplaFieldMappings', 'Error while fetching Zoopla field mappings.');
            return new Map<String, String>();
        }
    }

    /**
    * Method Name : PortalWrapper
    * @param Id to stored the Portal record Id
    * @param flag to stored the flag value
    * @param name to stored the portal name
    * @param pname to stored the portal generator name
    * @param status to stored the portal status
    * @param buttonColor to stored the button color
    * @param buttonLabel to stored the button label
    * @param badgeColor to stored the badge color
    * @description : Used to store portal data.
    */
    public class PortalWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public Boolean flag;
        @AuraEnabled public String name;
        @AuraEnabled public String pname;
        @AuraEnabled public String status;
        @AuraEnabled public String buttonColor;
        @AuraEnabled public String buttonLabel;
        @AuraEnabled public String badgeColor;
    }

    public class FetchPortalListingRecord {
        @AuraEnabled public List<PortalWrapper> portalData;
        @AuraEnabled public Map<String, String> zooplaFieldMappings;
    }
}