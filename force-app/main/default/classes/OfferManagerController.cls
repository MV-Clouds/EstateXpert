public with sharing class OfferManagerController {
    // @AuraEnabled
    // public static Map<String, Object> getOfferData(String listingId) {
    //     Map<String, Object> result = new Map<String, Object>();
    //     try {
    //         String escapeListingId = String.escapeSingleQuotes(listingId);
    //         List<Listing__c> listing = [SELECT Id, Name, Address__c, Listing_Type__c, Size__c, Property_Type__c, Property_Category__c, Bedrooms__c, Bathrooms__c, Description__c, 
    //                                         Listing_Price__c, Property__c, CurrencyIsoCode, Listing_Address__c FROM Listing__c WHERE Id = :escapeListingId WITH USER_MODE LIMIT 1];

    //         List<Property_File__c> propertyFiles = new List<Property_File__c>();
    //         if (!listing.isEmpty()) {
    //             propertyFiles = [SELECT Id, Name, BaseUrl__c FROM Property_File__c WHERE Property__c = :listing[0].Property__c WITH USER_MODE];
    //         }
    
    //         // Fetch completed showings to gather Buyer (Contact) Ids
    //         Set<Id> contactIds = new Set<Id>();
    //         for (Showing__c showing : [SELECT Buyer__c FROM Showing__c WHERE Listing__c = :escapeListingId AND Status__c = 'Completed' WITH USER_MODE]) {
    //             if (showing.Buyer__c != null) {
    //                 contactIds.add(showing.Buyer__c);
    //             }
    //         }

    //         // Fetch offers made on the listing
    //         List<Offer__c> offers = new List<Offer__c>();
    //         if (!contactIds.isEmpty()) {
    //             offers = [SELECT Id, Name, Status__c, Listing__c, Buyer_Contact__c, Buyer_Contact__r.Name, Offer_Amount__c, Offer_Date__c, Offer_Expiration_Date__c,
    //                        Earnest_Money_Deposit__c FROM Offer__c WHERE Listing__c = :escapeListingId AND Buyer_Contact__c IN :contactIds WITH USER_MODE ORDER BY Offer_Amount__c DESC];
    //         }
    
    //         // Final Response Map
    //         result.put('listing', listing.isEmpty() ? null : listing[0]);
    //         result.put('offers', offers);
    //         result.put('images', propertyFiles);
            
    //         return result;
    
    //     } catch (Exception e) {
    //         ErrorHandler.insertErrorData(e, 'OfferManagerController', 'getOfferData', e.getStackTraceString());
    //         return null;
    //     }
    // }

    // @AuraEnabled
    // public static List<OfferHistoryWrapper> getOfferHistory(String offerId) {
    //     List<OfferHistoryWrapper> historyData = new List<OfferHistoryWrapper>();
    //     try {
    //         String escapeOfferId = String.escapeSingleQuotes(offerId);
    //         // Field metadata
    //         Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Offer__c.fields.getMap();

    //         List<Offer__History> historyList = [SELECT Id, CreatedDate, CreatedBy.Name, Field, OldValue, NewValue, DataType FROM Offer__History
    //                                                 WHERE ParentId = :escapeOfferId WITH USER_MODE ORDER BY CreatedDate ASC];

    //         for (Offer__History h : historyList) {
    //             OfferHistoryWrapper wrapper = new OfferHistoryWrapper();
    //             wrapper.id = h.Id;
    //             wrapper.createdDate = h.CreatedDate;
    //             wrapper.createdBy = h.CreatedBy != null ? h.CreatedBy.Name : '';
    //             wrapper.fieldApiName = h.Field;
    //             wrapper.fieldLabel = fieldMap.containsKey(h.Field) ? fieldMap.get(h.Field).getDescribe().getLabel() : h.Field;
    //             wrapper.oldValue = h.OldValue != null ? String.valueOf(h.OldValue) : '';
    //             wrapper.newValue = h.NewValue != null ? String.valueOf(h.NewValue) : '';
    //             wrapper.dataType = h.DataType;

    //             historyData.add(wrapper);
    //         }

    //     } catch (Exception e) {
    //         ErrorHandler.insertErrorData(e, 'OfferManagerController', 'getOfferHistory', e.getStackTraceString());
    //     }

    //     return historyData;
    // }

    // @AuraEnabled
    // public static void updateOfferRecord(Offer__c offerData){
    //     try {
    //         if (offerData == null || offerData.Id == null) {
    //             throw new AuraHandledException('Offer data is required for update.');
    //         }
    //         // Perform DML operation to update the Offer record
    //         update as user offerData;
            
    //     } catch (Exception e) {
    //         ErrorHandler.insertErrorData(e, 'OfferManagerController', 'updateOfferRecord', e.getStackTraceString());
    //     }
    // }

    // public class OfferHistoryWrapper {
    //     @AuraEnabled public String id;
    //     @AuraEnabled public DateTime createdDate;
    //     @AuraEnabled public String createdBy;
    //     @AuraEnabled public String fieldApiName;
    //     @AuraEnabled public String fieldLabel;
    //     @AuraEnabled public String oldValue;
    //     @AuraEnabled public String newValue;
    //     @AuraEnabled public String dataType;
    // }
}