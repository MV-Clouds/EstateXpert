@IsTest
public class PropertySearchControllerTest {

    @TestSetup
    static void setupData() {
        Contact contact = new Contact(LastName = 'Dev Test', Email = 'test@rk.com');
        insert contact;

        Property__c property = new Property__c(Name = 'Dev Test');
        insert property;

        Listing__c listing = new Listing__c();
        listing.Name = 'Dev Test';
        listing.Property__c = property.Id;
        listing.Status__c = 'Active';
        listing.Listing_Type__c = 'Rent';
        listing.Rent_Frequency__c = 'Monthly'; 
        listing.Property_Type__c = 'Villa';
        listing.Property_Sub_Type__c = 'Residential - Apartment';
        listing.Property_Category__c = 'Residential';
        listing.Country_Code__c = 'IN';
        listing.Street__c = 'Dev Test';
        listing.City__c = 'Dev Test';
        listing.State__c = 'Dev Test';
        listing.Zip_Postal_Code__c = '123456';
        listing.Description__c = 'Dev Test';
        listing.Listing_Price__c = 1000000;
        listing.Bedrooms__c = 3;
        listing.Bathrooms__c = 2;
        listing.Size__c = 1000;
        listing.Property_OwnerContact__c = contact.Id;
        listing.Listed_Date__c = Date.today();
        // listing.Unit_Number__c = '12345';
        listing.Furnished__c = 'Yes';
        listing.Property_Status__c = 'Vacant';
        listing.Year_Built__c = '2020';
        listing.Listing_Agent_Firstname__c = 'RK';
        listing.Listing_Agent_Lastname__c = 'Dev';
        listing.Listing_Agent_Email__c = 'rkdev@gmail.com';
        listing.Private_Amenities__c = 'Private Garden';
        listing.Completion_Status__c = 'Completed';
        insert listing;

        // Create sample Inquiry__c record
        Inquiry__c inquiry = new Inquiry__c(Name__c = 'Test Inquiry', New_Construction__c = true, Parking_Available__c = false, Sunday_Open_House__c = false, This_Week_Open_House__c = false, Water_View__c = false);
        insert inquiry;

        // Create sample Property_File__c linked to the Listing
        Property_File__c propertyFile = new Property_File__c(
            Property__c = property.Id,
            BaseUrl__c = 'https://sample.url'
        );
        insert propertyFile;

    }

    @IsTest
    static void testGetRecordsWithListing() {
        // Get an existing Listing record
        Listing__c listing = [SELECT Id FROM Listing__c LIMIT 1];

        // Call the getRecords method for Listing__c
        PropertySearchController.WrapperClass result = PropertySearchController.getRecords(listing.Id, 'MVEX__Listing__c');

        // Assertions
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.listings, 'Listings should not be null');
        System.assertNotEquals(null, result.inquiries, 'Inquiries should not be null');
    }

    @IsTest
    static void testGetRecordsWithInquiry() {
        // Get an existing Inquiry record
        Inquiry__c inquiry = [SELECT Id FROM Inquiry__c LIMIT 1];

        // Call the getRecords method for Inquiry__c
        PropertySearchController.WrapperClass result = PropertySearchController.getRecords(inquiry.Id, 'MVEX__Inquiry__c');

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.listings, 'Listings should not be null');
        System.assertNotEquals(null, result.inquiries, 'Inquiries should not be null');
        System.assertNotEquals(null, result.medias, 'Medias should not be null');
    }

    @IsTest
    static void testGetObjectFields() {
        Test.startTest();
        PropertySearchController.ObjectFieldsWrapper result = PropertySearchController.getObjectFields('MVEX__Listing__c');        
        Test.stopTest();

        System.assertNotEquals(0, result.fields.size(), 'Result should not be null');
    }
}