public without sharing class SinglePropertyViewCmpController {
    public class Wrapper {
        @AuraEnabled
        public List<MVEX__Listing__c> listingData;
        @AuraEnabled
        public List<MVEX__Property_File__c> listingImages;
    }
    
    @AuraEnabled
    public static Wrapper getListingData(Id recordId) {
        try {
            List<MVEX__Listing__c> listing = [SELECT Id, Name, MVEX__Availability_Date__c, MVEX__Available_From__c, MVEX__Available_to__c, MVEX__Bathrooms__c, MVEX__Bedrooms__c,
                                        MVEX__Broker_s_Listing_ID__c, MVEX__City__c, MVEX__Completion_Date__c, MVEX__Completion_Status__c, MVEX__Description__c, MVEX__Floor__c,
                                        MVEX__Furnished__c, MVEX__House_Office_No__c, MVEX__Listed_Date__c, MVEX__Listing_Address__c, MVEX__Listing_Address__City__s,
                                        MVEX__Listing_Address__CountryCode__s, MVEX__Listing_Address__GeocodeAccuracy__s, MVEX__Listing_Address__Latitude__s,
                                        MVEX__Listing_Address__Longitude__s, MVEX__Listing_Address__PostalCode__s, MVEX__Listing_Address__StateCode__s,
                                        MVEX__Listing_Address__Street__s, MVEX__Listing_Agent_Email__c, MVEX__Listing_Agent_Firstname__c, MVEX__Listing_Agent_Full_Name__c,
                                        MVEX__Listing_Agent_Lastname__c, MVEX__Listing_Agent_Mobile_Phone__c, MVEX__Listing_Price__c, MVEX__Listing_Type__c,
                                        MVEX__Number_of_Cheques__c, MVEX__Off_Market_Date__c, MVEX__Off_Plan__c, MVEX__On_Market_Date__c, MVEX__Parking_Available__c,
                                        MVEX__Parking_Spaces__c, MVEX__Private_Amenities__c, MVEX__Property__c, MVEX__Property_Category__c, MVEX__Property_Status__c, MVEX__Property_Sub_Type__c,
                                        MVEX__Property_Type__c, MVEX__Rent_Frequency__c, MVEX__Rental_Price__c, MVEX__RERA_Permit_Number__c, MVEX__Sale_Date__c, MVEX__Sale_Price__c, MVEX__Service_Charge__c,
                                        MVEX__Lot_Size__c, MVEX__Sq_Ft__c, MVEX__Status__c, MVEX__Taxes__c, MVEX__Year_Built__c FROM MVEX__Listing__c WHERE Id = :recordId LIMIT 1];

            List<MVEX__Property_File__c> media = [SELECT Id, Name, MVEX__BaseUrl__c FROM MVEX__Property_File__c WHERE MVEX__Property__c = :listing[0].MVEX__Property__c];

            Wrapper wr = new Wrapper();
            wr.listingData = listing;
            wr.listingImages = media;
            return wr;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'SinglePropertyViewCmpController', 'getListingData', e.getMessage());
            Wrapper wr = new Wrapper();
            wr.listingData = new List<MVEX__Listing__c>();
            wr.listingImages = new List<MVEX__Property_File__c>();
            return wr;
        }
    }

    @AuraEnabled
    public static Event getShowingData(String showingId) {
        try {
            List<Event> showings = [
                SELECT Id, Subject, MVEX__Buyer__c, MVEX__Listing__c, MVEX__Status__c, MVEX__Scheduled_Date__c, MVEX__Reschedule_Date__c
                FROM Event
                WHERE Id = :showingId
                ORDER BY CreatedDate DESC LIMIT 1
            ];
            if (showings.isEmpty()) {
                return null;
            }
            return showings[0];
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'SinglePropertyViewCmpController', 'getShowingData', e.getMessage());
            return null;
        }
    }

    @AuraEnabled
    public static void updateShowingStatus(String showingId, String status, String reason) {
        try {
            List<Event> showing = [SELECT Id, MVEX__Status__c, MVEX__Cancellation_Reason__c FROM Event WHERE Id = :showingId LIMIT 1];
            if (!showing.isEmpty()) {
                showing[0].MVEX__Status__c = status;
                if (status == 'Cancelled') {
                    showing[0].MVEX__Cancellation_Reason__c = reason;
                }
                update showing;
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'SinglePropertyViewCmpController', 'updateShowingStatus', e.getMessage());
        }
    }

    @AuraEnabled
    public static void updateShowingDate(String showingId, String status, Datetime newDate) {
        try {
            Event showing = [SELECT Id, MVEX__Reschedule_Date__c, MVEX__Showing_Duration__c FROM Event WHERE Id = :showingId LIMIT 1];
            showing.MVEX__Reschedule_Date__c = newDate;
            showing.StartDateTime = newDate;
            Integer duration = (Integer)showing.MVEX__Showing_Duration__c != null ? (Integer)showing.MVEX__Showing_Duration__c : 60;
            showing.EndDateTime = newDate.addMinutes(duration);
            showing.MVEX__Status__c = status;
            update showing;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'SinglePropertyViewCmpController', 'updateShowingDate', e.getMessage());
        }
    }
}