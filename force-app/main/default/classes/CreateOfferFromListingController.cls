public with sharing class CreateOfferFromListingController {
    
    /**
     * Wrapper class to hold record details and object type information
     */
    public class RecordDetailsWrapper {
        @AuraEnabled public Boolean isSuccess { get; set; }
        @AuraEnabled public String errorMessage { get; set; }
        @AuraEnabled public String objectType { get; set; }
        @AuraEnabled public Id listingId { get; set; }
        @AuraEnabled public String listingType { get; set; }
        @AuraEnabled public Decimal listingPrice { get; set; }
        @AuraEnabled public Id sellerContact { get; set; }
        @AuraEnabled public Id buyerContact { get; set; }
        @AuraEnabled public String offerMadeBy { get; set; }
        @AuraEnabled public Decimal offerAmount { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public Date offerExpirationDate { get; set; }
        @AuraEnabled public Date targetCloseDate { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public Id counterOfferFor { get; set; }
        @AuraEnabled public String firstOfferId { get; set; }
        
        public RecordDetailsWrapper() {
            this.isSuccess = true;
            this.errorMessage = '';
        }
    }
    
    /**
     * Method Name: getRecordDetails
     * @description: Detects object type from record ID and returns appropriate details
     * @param recordId - The ID of the listing or offer record
     * @return RecordDetailsWrapper - Record details with object type
     * Created Date: 10/02/2026
     * Created By: Karan Singh
     */
    @AuraEnabled
    public static RecordDetailsWrapper getRecordDetails(Id recordId) {
        RecordDetailsWrapper wrapper = new RecordDetailsWrapper();
        try {
            // Get the object type from the record ID
            String objectName = recordId.getSObjectType().getDescribe().getName();
            
            if (objectName == 'MVEX__Listing__c') {
                wrapper.objectType = 'Listing';
                MVEX__Listing__c listing = getListingDetails(recordId);
                wrapper.listingId = listing.Id;
                wrapper.listingType = listing.MVEX__Listing_Type__c;
                wrapper.listingPrice = listing.MVEX__Listing_Price__c;
                wrapper.sellerContact = listing.MVEX__Property_OwnerContact__c;
            } else if (objectName == 'MVEX__Offer__c') {
                wrapper.objectType = 'Offer';
                MVEX__Offer__c offer = getOfferDetails(recordId);
                wrapper.listingId = offer.MVEX__Listing__c;
                wrapper.listingType = offer.MVEX__Listing_Type__c;
                wrapper.listingPrice = offer.MVEX__Listing_Price__c;
                wrapper.sellerContact = offer.MVEX__Seller_Contact__c;
                wrapper.buyerContact = offer.MVEX__Buyer_Contact__c;
                wrapper.offerMadeBy = offer.MVEX__Offer_made_by__c;
                wrapper.offerAmount = offer.MVEX__Offer_Amount__c;
                wrapper.status = offer.MVEX__Status__c;
                wrapper.offerExpirationDate = offer.MVEX__Offer_Expiration_Date__c;
                wrapper.targetCloseDate = offer.MVEX__Target_Close_Date__c;
                wrapper.description = offer.MVEX__Description__c;
                wrapper.counterOfferFor = recordId;
                wrapper.firstOfferId = offer.MVEX__First_Offer_Id__c;
            } else {
                wrapper.isSuccess = false;
                wrapper.errorMessage = 'Invalid record type. Expected Listing or Offer.';
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'CreateOfferFromListingController', 'getRecordDetails', e.getMessage());
            wrapper.isSuccess = false;
            wrapper.errorMessage = 'Error retrieving record details: ' + e.getMessage();
        }
        return wrapper;
    }
    
    /**
     * Method Name: getListingDetails
     * @description: Retrieves listing details to populate default values in the offer form
     * @param listingId - The ID of the listing record
     * @return MVEX__Listing__c - Listing record with required fields
     * Created Date: 10/02/2026
     * Created By: Karan Singh
     */
    @AuraEnabled
    public static MVEX__Listing__c getListingDetails(Id listingId) {
        try {
            MVEX__Listing__c listing = [
                SELECT Id, 
                       MVEX__Listing_Type__c,
                       MVEX__Listing_Price__c,
                       MVEX__Property_OwnerContact__c
                FROM MVEX__Listing__c 
                WHERE Id = :listingId 
                WITH USER_MODE
                LIMIT 1
            ];
            return listing;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'CreateOfferFromListingController', 'getListingDetails', e.getMessage());
            throw new AuraHandledException('Error retrieving listing details: ' + e.getMessage());
        }
    }

    /**
     * Method Name: getOfferDetails
     * @description: Retrieves offer details to populate default values for counter offer
     * @param offerId - The ID of the offer record
     * @return MVEX__Offer__c - Offer record with required fields
     * Created Date: 10/02/2026
     * Created By: Karan Singh
     */
    @AuraEnabled
    public static MVEX__Offer__c getOfferDetails(Id offerId) {
        try {
            MVEX__Offer__c offer = [
                SELECT Id,
                       MVEX__Listing__c,
                       MVEX__Listing_Type__c,
                       MVEX__Listing_Price__c,
                       MVEX__Seller_Contact__c,
                       MVEX__Buyer_Contact__c,
                       MVEX__Offer_made_by__c,
                       MVEX__Offer_Amount__c,
                       MVEX__Status__c,
                       MVEX__Offer_Expiration_Date__c,
                       MVEX__Target_Close_Date__c,
                       MVEX__Description__c,
                       MVEX__First_Offer_Id__c
                FROM MVEX__Offer__c 
                WHERE Id = :offerId 
                WITH USER_MODE
                LIMIT 1
            ];
            return offer;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'CreateOfferFromListingController', 'getOfferDetails', e.getMessage());
            throw new AuraHandledException('Error retrieving offer details: ' + e.getMessage());
        }
    }
    
    /**
     * Method Name: updateOfferRecord
     * @description: Updates the First Offer ID field to point to itself
     * @param sourceObjectType - The type of the source object ('Listing' or 'Offer')
     * @return Boolean - True if update was successful
     * Created Date: 10/02/2026
     * Created By: Karan Singh
     */
    @AuraEnabled
    public static Boolean updateOfferRecord(String sourceObjectType, Id offerId) {
        try {
            MVEX__Offer__c offer = new MVEX__Offer__c();
            offer.Id = offerId;
            if (sourceObjectType == 'Offer') {
                offer.MVEX__Status__c = 'Countered';
            } else if (sourceObjectType == 'Listing') {
                offer.MVEX__First_Offer_Id__c = String.valueOf(offerId);
                
                // Get Active Offer RecordType
                RecordType activeOfferRT = [
                    SELECT Id 
                    FROM RecordType 
                    WHERE SObjectType = 'MVEX__Offer__c' 
                    AND DeveloperName = 'Active' 
                    LIMIT 1
                ];
                
                if (activeOfferRT != null) {
                    offer.RecordTypeId = activeOfferRT.Id;
                }
            } else {
                return false;
            }

            update offer;
            return true;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'CreateOfferFromListingController', 'updateOfferRecord', e.getMessage());
            return false;
        }
    }
}