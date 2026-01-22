public with sharing class ListingMapController {
    @AuraEnabled
    public static Listing__c getListingDetails(Id recordId) {
        try {
            if (recordId == null) {
                throw new AuraHandledException('Invalid record ID.');
            }

            Listing__c listing = [SELECT Id, Name, Sq_Ft__c, MVEX__Address__c FROM Listing__c WHERE Id = :recordId WITH USER_MODE LIMIT 1];

            return listing;

        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'ListingMapController', 'getListingDetails', 'Error fetching listing');
            return null;
        }
    }
}