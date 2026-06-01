/**
* Class Name : ListingManagerControllerTest
* Created By : Karan Singh
* Last Modified Date : 24/06/2024
* Last Modified By : Karan Singh
* @description : Test class for ListingManagerController.
*/
@isTest
public class ListingManagerControllerTest {
    
    /**
    * Method Name : testGetListingData
    * @description : Used to test getListingData method.
    */
    @isTest
    static void testGetListingData() {
        try {
            Account account = new Account(Name = 'Test Account');
            insert account;
            
            // Create Property
            Property__c property = new Property__c(Name = 'Test Property', Account__c = account.Id);
            insert property;

            // Create Listings
            Listing__c listing1 = new Listing__c(Name = 'Test Listing 1', Property__c = property.Id);
            Listing__c listing2 = new Listing__c(Name = 'Test Listing 2', Property__c = property.Id);
            insert new List<Listing__c>{ listing1, listing2 };

            // Create Property Files
            Property_File__c propertyFile1 = new Property_File__c(BaseUrl__c = 'https://example.com/file1.jpg', Property__c = property.Id);
            Property_File__c propertyFile2 = new Property_File__c(BaseUrl__c = 'https://example.com/file2.jpg', Property__c = property.Id);
            insert new List<Property_File__c>{ propertyFile1, propertyFile2 };

            // Test the getListingData method
            Test.startTest();
            ListingManagerController.WrapperClass result = ListingManagerController.getListingData();
            Test.stopTest();
            
            // Assert that listings are returned
            System.assertNotEquals(null, result);
            System.assertEquals(2, result.listings.size());
            
            // Assert that media URLs are returned correctly
            System.assertEquals(1, result.medias.size());
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'ListingManagerControllerTest', 'testGetListingData', 'Error while creating test data.');
        }
    }
}