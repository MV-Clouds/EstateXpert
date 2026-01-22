/**
* Class Name : PortalSyndicationController
* Test Class : PortalSyndicationControllerTest
* Created By : Karan Singh
* Last Modified Date : 24/12/2024
* Last Modified By : Karan Singh
* @description : Used to create and manage PortalListing__c records.
*/
public with sharing class PortalSyndicationController {

    /**
    * Method Name : createPortalListingRecord
    * @param listingId to stored the Listing record Id
    * @param portalId to stored the Portal record Id
    * @param actionType to stored the action type
    * @param portalName to stored the portal name
    * @return String value
    * @description : Used to create and manage PortalListing__c records.
    */
    @AuraEnabled
    public static string createPortalListingRecord(String listingId, String portalId, String actionType, String portalName){
        try {
            List<Control_Center_Feature__mdt> controlCenterFeatureRecords = [SELECT isAvailable__c FROM Control_Center_Feature__mdt WHERE DeveloperName = 'Is_XML_For_PF' WITH USER_MODE LIMIT 1];
            Boolean isXmlForPfEnabled = controlCenterFeatureRecords.size() > 0 ? controlCenterFeatureRecords[0].isAvailable__c : false;

            List<String> portalNames = new List<String>();
            if (isXmlForPfEnabled) {
                portalNames = new List<String>{'Zoopla', 'Rightmove', 'Rightmove Overseas'};
            } else {
                portalNames = new List<String>{'Zoopla', 'Rightmove', 'Rightmove Overseas', 'Propertyfinder'};
            }

            if (actionType == 'Publish' && !portalNames.contains(portalName)) {
                PortalListing__c newPortalListing = new PortalListing__c();
                newPortalListing.Listing__c = listingId;
                newPortalListing.Portal__c = portalId;
                newPortalListing.SystemIsActive__c = true;
                newPortalListing.Listed_Date__c = System.today();
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
                List<PortalListing__c> portalListings = [SELECT Id, SystemIsActive__c FROM PortalListing__c WHERE Listing__c =: escapeListingId
                                                        AND Portal__c =: escapePortalId AND SystemIsActive__c = true WITH USER_MODE];
                if (!portalListings.isEmpty()) {
                    for (PortalListing__c portalListing : portalListings) {
                        portalListing.SystemIsActive__c = false;
                        portalListing.UnlistedDate__c = System.today();
                    }

                    update as user portalListings;
                }
            } else {
                return 'Invalid action type or portal name.';
            }

            return 'Success';

        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'PortalSyndicationController', 'createPortalListingRecord', 'Error while updating or creating PortalListing__c record.');
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

            List<Portal__c> portalList = new List<Portal__c>([SELECT Id, Name, Generator__c, (SELECT Id, SystemIsActive__c FROM Portals_Listing__r WHERE SystemIsActive__c = true and Listing__c =: listingId) FROM Portal__c WHERE Is_Active__c = TRUE WITH USER_MODE ORDER BY CreatedDate DESC LIMIT 1000]);

            Map<String, List<PortalListing__c>> portalStatuCheck = new Map<String, List<PortalListing__c>>();

            for (Portal__c portal : portalList) {
                if (portal.Portals_Listing__r != null && portal.Portals_Listing__r.size() > 0) {
                    portalStatuCheck.put(portal.Id, portal.Portals_Listing__r);
                } else {
                    portalStatuCheck.put(portal.Id, null);
                }
            }

            for (Portal__c portal : portalList) {
                PortalWrapper portalWrapper = new PortalWrapper();
                portalWrapper.id = portal.Id;
                portalWrapper.name = portal.Name;
                portalWrapper.pname = portal.Generator__c;
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

            List<Control_Center_Feature__mdt> controlCenterFeatureRecords = [SELECT isAvailable__c FROM Control_Center_Feature__mdt WHERE DeveloperName = 'Is_XML_For_PF' WITH USER_MODE LIMIT 1];
            portalWrpList.isXMLForPF = controlCenterFeatureRecords.size() > 0 ? controlCenterFeatureRecords[0].isAvailable__c : false;

            return portalWrpList;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'PortalSyndicationController', 'fetchPortals', 'Error while fetching portal records.');
            return null;
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
        @AuraEnabled public Boolean isXMLForPF;
    }
}