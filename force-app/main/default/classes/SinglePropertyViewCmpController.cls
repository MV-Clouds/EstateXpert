public without sharing class SinglePropertyViewCmpController {
    // public class Wrapper {
    //     @AuraEnabled
    //     public List<Listing__c> listingData;
    //     @AuraEnabled
    //     public List<Property_File__c> listingImages;
    // }
    
    // @AuraEnabled
    // public static Wrapper getListingData(Id recordId) {
    //     try {
    //         List<Listing__c> listing = [SELECT Id, Name, Availability_Date__c, Available_From__c, Available_to__c, Bathrooms__c, Bedrooms__c, 
    //                                     Broker_s_Listing_ID__c, City__c, Completion_Date__c, Completion_Status__c, Description__c, Floor__c, 
    //                                     Furnished__c, House_Office_No__c, Listed_Date__c, MVEX__Address__c, Listing_Agent_Email__c, Listing_Agent_Firstname__c, Listing_Agent_Full_Name__c, 
    //                                     Listing_Agent_Lastname__c, Listing_Agent_Mobile_Phone__c, Listing_Price__c, Listing_Type__c, 
    //                                     Number_of_Cheques__c, Off_Market_Date__c, Off_Plan__c, On_Market_Date__c, Parking_Available__c, 
    //                                     Parking_Spaces__c, Private_Amenities__c, Property__c, Property_Category__c, Property_Status__c, Property_Sub_Type__c, 
    //                                     Property_Type__c, Rent_Frequency__c, Rental_Price__c, RERA_Permit_Number__c, Sale_Date__c, Sale_Price__c, Service_Charge__c, 
    //                                     Size__c, Sq_Ft__c, Status__c, Taxes__c, Year_Built__c FROM Listing__c WHERE Id = :recordId AND Status__c = 'Active' WITH USER_MODE LIMIT 1];
            
    //         List<Property_File__c> media = [SELECT Id, Name, BaseUrl__c FROM Property_File__c WHERE Property__c = :listing[0].Property__c WITH USER_MODE];
            
    //         Wrapper wr = new Wrapper();
    //         wr.listingData = listing;
    //         wr.listingImages = media;
    //         return wr;
    //     } catch (Exception e) {
    //         ErrorHandler.insertErrorData(e, 'SinglePropertyViewCmpController', 'getListingData', e.getMessage());
    //         Wrapper wr = new Wrapper();
    //         wr.listingData = new List<Listing__c>();
    //         wr.listingImages = new List<Property_File__c>();
    //         return wr;
    //     }
    // }

    // @AuraEnabled
    // public static Showing__c getShowingData(String showingId) {
    //     try {
    //         List<Showing__c> showings = [SELECT Id, Name, Buyer__c, Listing__c, Status__c, Scheduled_Date__c FROM Showing__c WHERE Id = :showingId WITH USER_MODE
    //                                         ORDER BY CreatedDate DESC LIMIT 1];
    //         if (showings.isEmpty()) {
    //             return null;
    //         }
    //         return showings[0];
    //     } catch (Exception e) {
    //         ErrorHandler.insertErrorData(e, 'SinglePropertyViewCmpController', 'getShowingData', e.getMessage());
    //         return null;
    //     }
    // }

    // @AuraEnabled
    // public static void updateShowingStatus(String showingId, String status, String reason) {
    //     try {
    //         List<Showing__c> showing = [SELECT Id, Status__c, Cancellation_Reason__c FROM Showing__c WHERE Id = :showingId WITH USER_MODE LIMIT 1];
    //         if (!showing.isEmpty()) {
    //             showing[0].Status__c = status;
    //             if (status == 'Cancelled') {
    //                 showing[0].Cancellation_Reason__c = reason;
    //             }
    //             update as user showing;
    //         }
    //     } catch (Exception e) {
    //         ErrorHandler.insertErrorData(e, 'SinglePropertyViewCmpController', 'updateShowingStatus', e.getMessage());
    //     }
    // }

    // @AuraEnabled
    // public static void updateShowingDate(String showingId, String status, Datetime newDate) {
    //     try {
    //         Showing__c showing = [SELECT Id, Reschedule_Date__c FROM Showing__c WHERE Id = :showingId WITH USER_MODE LIMIT 1];
    //         showing.Reschedule_Date__c = newDate;
    //         showing.Status__c = status;
    //         update as user showing;
    //     } catch (Exception e) {
    //         ErrorHandler.insertErrorData(e, 'SinglePropertyViewCmpController', 'TimesheetController', e.getMessage());
    //     }
    // }
}