/**
* Class Name : SinglePropertyViewCmpControllerTest
* Created By : Karan Singh
* Last Modified Date : 27/01/2026
* Last Modified By : Karan Singh
* @description : Test class for SinglePropertyViewCmpController
*/
@isTest
public class SinglePropertyViewCmpControllerTest {
    
    @testSetup
    static void setupTestData() {
        try {
            Contact buyer = new Contact(LastName = 'Test Buyer', Email = 'buyer@test.com', Phone = '1234567890');
            insert buyer;
            
            Property__c property = new Property__c(Name = 'Test Property', Street__c = 'Test Street', City__c = 'Test City', State__c = 'Test State', Zip_Postal_Code__c = '12345');
            insert property;
            
            Listing__c activeListing = new Listing__c(
                Name = 'Active Test Listing',
                Property__c = property.Id,
                Status__c = 'Active',
                Listing_Type__c = 'Sale',
                Property_Type__c = 'Villa',
                Property_Category__c = 'Residential',
                Bedrooms__c = 3,
                Bathrooms__c = 2,
                Size__c = 2000,
                Listing_Price__c = 500000,
                Description__c = 'Test Description',
                Furnished__c = 'Yes',
                City__c = 'Test City'
            );
            insert activeListing;
            
            List<Property_File__c> files = new List<Property_File__c>();
            for (Integer i = 0; i < 3; i++) {
                files.add(new Property_File__c(Name = 'Test Image ' + i, Property__c = property.Id, BaseUrl__c = 'https://test.com/image' + i + '.jpg'));
            }
            insert files;
            
            Showing__c showing1 = new Showing__c(
                Buyer__c = buyer.Id,
                Listing__c = activeListing.Id,
                Status__c = 'Waiting For Confirmation',
                Scheduled_Date__c = System.now().addDays(1)
            );
            insert showing1;

        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'SinglePropertyViewCmpControllerTest', 'setupTestData', 'Error in test setup.');
        }
    }
    
    @isTest
    static void testGetListingData() {
        try {
            Listing__c listing = [SELECT Id FROM Listing__c WHERE Status__c = 'Active' LIMIT 1];
            
            Test.startTest();
            SinglePropertyViewCmpController.Wrapper result = SinglePropertyViewCmpController.getListingData(listing.Id);
            Test.stopTest();
            
            System.assertNotEquals(null, result, 'Wrapper should not be null');
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'SinglePropertyViewCmpControllerTest', 'testGetListingData', 'Error in test.');
        }
    }
    
    @isTest
    static void testGetShowingData() {
        try {
            Showing__c showing = [SELECT Id FROM Showing__c LIMIT 1];
            
            Test.startTest();
            Showing__c result = SinglePropertyViewCmpController.getShowingData(showing.Id);
            Test.stopTest();
            
            System.assertNotEquals(null, result, 'Showing should not be null');
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'SinglePropertyViewCmpControllerTest', 'testGetShowingData', 'Error in test.');
        }
    }
    
    @isTest
    static void testUpdateShowingStatus() {
        try {
            Showing__c showing = [SELECT Id FROM Showing__c LIMIT 1];
            
            Test.startTest();
            SinglePropertyViewCmpController.updateShowingStatus(showing.Id, 'Cancelled', 'Customer request');
            Test.stopTest();
            
            Showing__c updated = [SELECT Status__c FROM Showing__c WHERE Id = :showing.Id];
            System.assertEquals('Cancelled', updated.Status__c, 'Status should be updated to Cancelled');
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'SinglePropertyViewCmpControllerTest', 'testUpdateShowingStatus', 'Error in test.');
        }
    }
    
    @isTest
    static void testUpdateShowingDate() {
        try {
            Showing__c showing = [SELECT Id FROM Showing__c LIMIT 1];
            Datetime newDate = System.now().addDays(10);
            
            Test.startTest();
            SinglePropertyViewCmpController.updateShowingDate(showing.Id, 'Rescheduled', newDate);
            Test.stopTest();
            
            Showing__c updated = [SELECT Reschedule_Date__c FROM Showing__c WHERE Id = :showing.Id];
            System.assertEquals(newDate, updated.Reschedule_Date__c, 'Reschedule date should be updated');
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'SinglePropertyViewCmpControllerTest', 'testUpdateShowingDate', 'Error in test.');
        }
    }
}