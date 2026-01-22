public with sharing class ListingMapController {
    @AuraEnabled
    public static MVEX__Listing__c getListingDetails(Id recordId) {
        try {
            if (recordId == null) {
                throw new AuraHandledException('Invalid record ID.');
            }

            MVEX__Listing__c listing = [SELECT Id, Name, MVEX__Sq_Ft__c, MVEX__Listing_Address__Street__s, MVEX__Listing_Address__City__s, MVEX__Listing_Address__StateCode__s, MVEX__Listing_Address__PostalCode__s,
                                    MVEX__Listing_Address__CountryCode__s FROM MVEX__Listing__c WHERE Id = :recordId WITH USER_MODE LIMIT 1];

            return listing;

        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'ListingMapController', 'getListingDetails', 'Error fetching listing');
            return null;
        }
    }
}