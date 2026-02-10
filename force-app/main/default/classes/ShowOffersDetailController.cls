public with sharing class ShowOffersDetailController {
    
    /**
     * Wrapper class to hold offer details for timeline display
     */
    public class OfferWrapper {
        @AuraEnabled public Id offerId { get; set; }
        @AuraEnabled public String offerNumber { get; set; }
        @AuraEnabled public Date offerDate { get; set; }
        @AuraEnabled public Decimal offerAmount { get; set; }
        @AuraEnabled public String offerMadeBy { get; set; }
        @AuraEnabled public String buyerContactName { get; set; }
        @AuraEnabled public String sellerContactName { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public Date expirationDate { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public Boolean isFirstOffer { get; set; }
        @AuraEnabled public Integer sequenceNumber { get; set; }
    }
    
    /**
     * Response wrapper for the method
     */
    public class OfferTimelineResponse {
        @AuraEnabled public Boolean isSuccess { get; set; }
        @AuraEnabled public String errorMessage { get; set; }
        @AuraEnabled public List<OfferWrapper> offers { get; set; }
        
        public OfferTimelineResponse() {
            this.isSuccess = true;
            this.errorMessage = '';
            this.offers = new List<OfferWrapper>();
        }
    }
    
    /**
     * Method Name: getOfferTimeline
     * @description: Fetches the complete offer timeline starting from the first offer
     * @param recordId - The ID of any offer in the chain
     * @return OfferTimelineResponse - Complete offer timeline
     * Created Date: 10/02/2026
     * Created By: Karan Singh
     */
    @AuraEnabled(cacheable=true)
    public static OfferTimelineResponse getOfferTimeline(Id recordId) {
        OfferTimelineResponse response = new OfferTimelineResponse();
        
        try {
            // First, get the record to find the first offer ID
            MVEX__Offer__c currentOffer = [
                SELECT Id, MVEX__First_Offer_Id__c 
                FROM MVEX__Offer__c 
                WHERE Id = :recordId 
                WITH USER_MODE
                LIMIT 1
            ];
            
            Id firstOfferId = currentOffer.MVEX__First_Offer_Id__c;
            
            if (firstOfferId == null) {
                response.isSuccess = false;
                response.errorMessage = 'First Offer ID not found on this record.';
                return response;
            }
            
            // Get all offers related to this first offer
            Map<Id, MVEX__Offer__c> offerMap = new Map<Id, MVEX__Offer__c>([
                SELECT Id, 
                       Name,
                       MVEX__Offer_Date__c,
                       MVEX__Offer_Amount__c,
                       MVEX__Offer_made_by__c,
                       MVEX__Buyer_Contact__c,
                       MVEX__Buyer_Contact__r.Name,
                       MVEX__Seller_Contact__c,
                       MVEX__Seller_Contact__r.Name,
                       MVEX__Status__c,
                       MVEX__Offer_Expiration_Date__c,
                       MVEX__Description__c,
                       MVEX__Counter_Offer_for__c,
                       MVEX__First_Offer_Id__c
                FROM MVEX__Offer__c 
                WHERE MVEX__First_Offer_Id__c = :firstOfferId
                WITH USER_MODE
                ORDER BY MVEX__Offer_Date__c DESC
            ]);
            
            // Build the timeline by following the counter offer chain
            List<OfferWrapper> timeline = new List<OfferWrapper>();
            Id currentId = firstOfferId;
            Integer sequence = 1;
            Set<Id> processedIds = new Set<Id>();
            
            while (currentId != null && offerMap.containsKey(currentId) && !processedIds.contains(currentId)) {
                processedIds.add(currentId);
                MVEX__Offer__c offer = offerMap.get(currentId);
                
                OfferWrapper wrapper = new OfferWrapper();
                wrapper.offerId = offer.Id;
                wrapper.offerNumber = offer.Name;
                wrapper.offerDate = offer.MVEX__Offer_Date__c;
                wrapper.offerAmount = offer.MVEX__Offer_Amount__c;
                wrapper.offerMadeBy = offer.MVEX__Offer_made_by__c;
                wrapper.buyerContactName = offer.MVEX__Buyer_Contact__c != null ? offer.MVEX__Buyer_Contact__r.Name : '';
                wrapper.sellerContactName = offer.MVEX__Seller_Contact__c != null ? offer.MVEX__Seller_Contact__r.Name : '';
                wrapper.status = offer.MVEX__Status__c;
                wrapper.expirationDate = offer.MVEX__Offer_Expiration_Date__c;
                wrapper.description = offer.MVEX__Description__c;
                wrapper.isFirstOffer = (currentId == firstOfferId);
                wrapper.sequenceNumber = sequence++;
                
                timeline.add(wrapper);
                
                // Find the next offer in the chain (counter offer to this one)
                Id nextId = null;
                for (MVEX__Offer__c nextOffer : offerMap.values()) {
                    if (nextOffer.MVEX__Counter_Offer_for__c == currentId) {
                        nextId = nextOffer.Id;
                        break;
                    }
                }
                currentId = nextId;
            }
            
            response.offers = timeline;
            
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'ShowOffersDetailController', 'getOfferTimeline', e.getMessage());
            response.isSuccess = false;
            response.errorMessage = 'Error retrieving offer timeline: ' + e.getMessage();
        }
        
        return response;
    }
}