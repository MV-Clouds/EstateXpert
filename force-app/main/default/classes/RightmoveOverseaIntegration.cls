/**
* Class Name : RightmoveOverseaIntegration
* Created By : Karan Singh
* Last Modified Date : 30/10/2024
* Last Modified By : Karan Singh
* @description : Used to integrate Rightmove Overseas.
*/
public with sharing class RightmoveOverseaIntegration {

    /**
    * Method Name : getListingRecordForSync
    * @param listingId - String
    * @description : Used to get listing record for sync.
    */
    @AuraEnabled
    public static void getListingRecordForSync(String listingId, String portalId){
        try {
            String escapedListingId = String.escapeSingleQuotes(listingId);
            String escapedPortalId = String.escapeSingleQuotes(portalId);

            List<MVEX__Portal__c> portalRightmove = [SELECT Id, MVEX__Field_Mapping__c, MVEX__Portal_Configuration__c, MVEX__Is_Active__c FROM MVEX__Portal__c WHERE Id =: escapedPortalId AND MVEX__Is_Active__c = true WITH USER_MODE LIMIT 1];

            if (portalRightmove.isEmpty()) {
                updatePortalListingRecord(listingId, portalId, 'Portal configuration is missing.', 'Exception');
                return;
            }

            MVEX__Portal__c rightmovePortal = portalRightmove[0];

            Map<String, Object> jsonMap = (Map<String, Object>) JSON.deserializeUntyped(rightmovePortal.MVEX__Field_Mapping__c);
            Map<String, Object> configMap = (Map<String, Object>) JSON.deserializeUntyped(rightmovePortal.MVEX__Portal_Configuration__c);
            Map<String, Object> finalMapping = new Map<String, Object>();

            finalMapping.put('branch.branch_id', configMap.get('branch.branch_id'));
            finalMapping.put('network.network_id', configMap.get('network.network_id'));
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
            query += ' FROM MVEX__Listing__c WHERE Id = :escapedListingId';

            List<SObject> records = Database.query(query, AccessLevel.USER_MODE);

            if (!records.isEmpty()) {
                SObject listingRecord = records[0];
                String propertyId = (String) listingRecord.get('MVEX__Property__c');

                List<MVEX__Property_File__c> media = [SELECT Id, MVEX__BaseUrl__c, MVEX__ExternalLink__c, MVEX__Tags__c, LastModifiedDate FROM MVEX__Property_File__c WHERE MVEX__Property__c = :propertyId AND MVEX__IsOnPortalFeed__c = true WITH USER_MODE Order BY MVEX__Sort_on_Portal_Feed__c ASC NULLS LAST, Name ASC];

                for (String key : jsonMap.keySet()) {
                    String label = (String) jsonMap.get(key);
                    finalMapping.put(label, listingRecord.get(key));
                }

                String resultBody = RightmoveJSONController.buildJSON(finalMapping, media, 'Rightmove Overseas');
                RightmoveIntegrationController.rightmoveCreateAndUpdateListing(resultBody, listingId, rightmovePortal.Id, certificateName, isSandbox);
            }
        } catch (Exception e) {
            updatePortalListingRecord(listingId, portalId, e.getMessage(), 'Exception');
            ErrorHandler.insertErrorData(e, 'RightmoveOverseaIntegration', 'getListingRecordForSync', 'Error while getting listing record.');
        }
    }

    public static void updatePortalListingRecord(String listingId, String portalId, String apiResponse, String status) {
        try {
            if (status == 'Success') {
                MVEX__PortalListing__c newPortalListing = new MVEX__PortalListing__c();
                newPortalListing.MVEX__Listing__c = listingId;
                newPortalListing.MVEX__Portal__c = portalId;
                newPortalListing.MVEX__SystemIsActive__c = true;
                newPortalListing.MVEX__Listed_Date__c = System.today();
                newPortalListing.MVEX__API_Response__c = apiResponse;
                insert as user newPortalListing;  
            }
            PlatformEventController.publishEvent(status, apiResponse, 'Rightmove Overseas', listingId);
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'RightmoveOverseaIntegration', 'updatePortalListingRecord', 'Error while updating portal listing record.');
        }
    }
}