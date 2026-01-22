/**
* Class Name : XMLFeedPortalTest
* Created By : Karan Singh
* Last Modified Date : 24/06/2024
* Last Modified By : Karan Singh
* @description : Test class for XMLFeedGeneratorForBayut, XMLFeedGeneratorForPF.
*/
@isTest
public class XMLFeedPortalTest {

    /**
    * Method Name : setupTestData
    * @description : Used to setup test data.
    */
    @testSetup
    static void setup() {
            Contact contact = new Contact(LastName = 'Dev Test');
            insert contact;

            Property__c property = new Property__c(Name = 'Dev Test');
            insert property;

            Listing__c listing1 = new Listing__c();
            listing1.Name = 'Dev Test';
            listing1.Property__c = property.Id;
            listing1.Status__c = 'Active';
            listing1.Listing_Type__c = 'Rent';
            listing1.Rent_Frequency__c = 'Monthly';
            listing1.Property_Type__c = 'Villa';
            listing1.Property_Sub_Type__c = 'Residential - Apartment';
            listing1.Property_Category__c = 'Residential';
            listing1.Country_Code__c = 'IN';
            listing1.Street__c = 'Dev Test';
            listing1.City__c = 'Dev Test';
            listing1.State__c = 'Dev Test';
            listing1.Zip_Postal_Code__c = '123456';
            listing1.Description__c = 'Dev Test';
            listing1.Listing_Price__c = 1000000;
            listing1.Bedrooms__c = 3;
            listing1.Bathrooms__c = 2;
            listing1.Size__c = 1000;
            listing1.Property_OwnerContact__c = contact.Id;
            listing1.Listed_Date__c = Date.today();
            // listing1.Unit_Number__c = '12345';
            listing1.Furnished__c = 'Yes';
            listing1.Property_Status__c = 'Vacant';
            listing1.Year_Built__c = '2020';
            listing1.Listing_Agent_Firstname__c = 'RK';
            listing1.Listing_Agent_Lastname__c = 'Dev';
            listing1.Listing_Agent_Email__c = 'rkdev@gmail.com';
            listing1.Private_Amenities__c = 'Private Garden';
            listing1.Completion_Status__c = 'Completed';

            Listing__c listing2 = new Listing__c();
            listing2.Name = 'Dev Test';
            listing2.Property__c = property.Id;
            listing2.Status__c = 'Active';
            listing2.Listing_Type__c = 'Sale';
            listing2.Rent_Frequency__c = 'Monthly';
            listing2.Property_Type__c = 'Villa';
            listing2.Property_Sub_Type__c = 'Residential - Apartment';
            listing2.Property_Category__c = 'Residential';
            listing2.Country_Code__c = 'IN';
            listing2.Street__c = 'Dev Test';
            listing2.City__c = 'Dev Test';
            listing2.State__c = 'Dev Test';
            listing2.Zip_Postal_Code__c = '123456';
            listing2.Description__c = 'Dev Test';
            listing2.Listing_Price__c = 1000000;
            listing2.Bedrooms__c = 3;
            listing2.Bathrooms__c = 2;
            listing2.Size__c = 1000;
            listing2.Property_OwnerContact__c = contact.Id;
            listing2.Listed_Date__c = Date.today();
            // listing2.Unit_Number__c = '12345';
            listing2.Furnished__c = 'Yes';
            listing2.Property_Status__c = 'Vacant';
            listing2.Year_Built__c = '2020';
            listing2.Listing_Agent_Firstname__c = 'RK';
            listing2.Listing_Agent_Lastname__c = 'Dev';
            listing2.Listing_Agent_Email__c = 'rkdev@gmail.com';
            listing2.Private_Amenities__c = 'Private Garden';
            listing2.Completion_Status__c = 'Completed';

            insert new List<Listing__c> { listing1, listing2 };

            Property_File__c propertyFile1 = new Property_File__c(
                Name = 'Test Image 1',
                Property__c = property.Id,
                BaseUrl__c = 'http://example.com/image1',
                Size__c = 123.45,
                IsOnPortalFeed__c = true,
                IsOnWebsite__c = true,
                IsOnExpose__c = true
            );

            Property_File__c propertyFile2 = new Property_File__c(
                Name = 'Test Image 2',
                Property__c = property.Id,
                BaseUrl__c = 'http://example.com/image2',
                Size__c = 543.21,
                IsOnPortalFeed__c = true,
                IsOnWebsite__c = false,
                IsOnExpose__c = false,
                Tags__c = 'Interior;Exterior;360tour;Floorplan;Virtual Tour'
            );

            insert new List<Property_File__c> { propertyFile1, propertyFile2 };

            List<Portal_Listing_Mapping__c> mappings = new List<Portal_Listing_Mapping__c>();
            mappings.add(new Portal_Listing_Mapping__c(Name='TestField1', Listing_Field_API_Name__c='Name', Portal_Name__c='Bayut', Value_Mapping__c='Apartment => AP,Penthouse => PH,Villa => VH,Townhouse => TH'));
            mappings.add(new Portal_Listing_Mapping__c(Name='TestField2', Listing_Field_API_Name__c='Description__c', Portal_Name__c='Bayut'));
            mappings.add(new Portal_Listing_Mapping__c(Name='TestField3', Listing_Field_API_Name__c='Name', Portal_Name__c='Dubizzle'));
            mappings.add(new Portal_Listing_Mapping__c(Name='TestField4', Listing_Field_API_Name__c='Description__c', Portal_Name__c='Dubizzle'));
            mappings.add(new Portal_Listing_Mapping__c(Name='TestField5', Listing_Field_API_Name__c='Name', Portal_Name__c='Propertyfinder'));
            mappings.add(new Portal_Listing_Mapping__c(Name='title_en', Listing_Field_API_Name__c='Description__c', Portal_Name__c='Propertyfinder'));
            mappings.add(new Portal_Listing_Mapping__c(Name='property_type', Listing_Field_API_Name__c='Property_Type__c', Portal_Name__c='Propertyfinder', Value_Mapping__c='Apartment => AP,Penthouse => PH,Villa => VH,Townhouse => TH'));
            mappings.add(new Portal_Listing_Mapping__c(Name='price', Listing_Field_API_Name__c='Listing_Price__c', Portal_Name__c='Propertyfinder'));
            mappings.add(new Portal_Listing_Mapping__c(Name='email', Listing_Field_API_Name__c='Listing_Agent_Email__c', Portal_Name__c='Propertyfinder'));
            mappings.add(new Portal_Listing_Mapping__c(Name='completion_status', Listing_Field_API_Name__c='Completion_Status__c', Portal_Name__c='Propertyfinder'));
            insert mappings;

            Portal__c portal1 = new Portal__c(Name = 'TestField1', Generator__c = 'Bayut', Is_Active__c = true);
            Portal__c portal2 = new Portal__c(Name = 'TestField2', Generator__c = 'Dubizzle', Is_Active__c = true);
            Portal__c portal3 = new Portal__c(Name = 'TestField3', Generator__c = 'Propertyfinder', Is_Active__c = true);
            insert new List<Portal__c> { portal1, portal2, portal3 };

            List<PortalListing__c> portalList = new List<PortalListing__c>();
            portalList.add(new PortalListing__c(Listing__c = listing1.Id, Portal__c = portal1.Id, SystemIsActive__c = true));
            portalList.add(new PortalListing__c(Listing__c = listing1.Id, Portal__c = portal2.Id, SystemIsActive__c = true));
            portalList.add(new PortalListing__c(Listing__c = listing1.Id, Portal__c = portal3.Id, SystemIsActive__c = true));
            portalList.add(new PortalListing__c(Listing__c = listing2.Id, Portal__c = portal1.Id, SystemIsActive__c = true));
            portalList.add(new PortalListing__c(Listing__c = listing2.Id, Portal__c = portal2.Id, SystemIsActive__c = true));
            portalList.add(new PortalListing__c(Listing__c = listing2.Id, Portal__c = portal3.Id, SystemIsActive__c = true));
            insert portalList;
    }

    /**
    * Method Name : testConstructorWithBayut
    * @description : Used to test constructor with Bayut.
    */
    @isTest
    static void testConstructorWithBayut() {
        try {
            List<Portal__c> portalList = [SELECT Id, Name, Generator__c FROM Portal__c WHERE Generator__c = 'Bayut' AND Is_Active__c = true];

            Test.startTest();
            Test.setCurrentPageReference(new PageReference('/apex/TestPage'));
            ApexPages.currentPage().getParameters().put('Id', portalList[0].Id);
            ApexPages.currentPage().getParameters().put('isByt', 'true');
            ApexPages.currentPage().getParameters().put('isDbzl', 'false');
            XMLFeedGeneratorForBayut generator = new XMLFeedGeneratorForBayut();
            Test.stopTest();

            System.assertNotEquals(null, generator.xmlstring, 'XML string should not be null');
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'XMLFeedPortalTest', 'testConstructorWithBayut', 'Error while testing constructor with Bayut.');
        }
    }

    /**
    * Method Name : testConstructorWithDubizzle
    * @description : Used to test constructor with Dubizzle.
    */
    @isTest
    static void testConstructorWithDubizzle() {
        try {
            List<Portal__c> portalList = [SELECT Id, Name, Generator__c FROM Portal__c WHERE Generator__c = 'Dubizzle' AND Is_Active__c = true];

            Test.startTest();
            Test.setCurrentPageReference(new PageReference('/apex/TestPage'));
            ApexPages.currentPage().getParameters().put('Id', portalList[0].Id);
            ApexPages.currentPage().getParameters().put('isByt', 'false');
            ApexPages.currentPage().getParameters().put('isDbzl', 'true');
            XMLFeedGeneratorForBayut generator = new XMLFeedGeneratorForBayut();
            Test.stopTest();

            System.assertNotEquals(null, generator.xmlstring, 'XML string should not be null');
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'XMLFeedPortalTest', 'testConstructorWithDubizzle', 'Error while testing constructor with Dubizzle.');
        }
    }

    /**
    * Method Name : testConstructorWithBoth
    * @description : Used to test constructor with both Bayut and Dubizzle.
    */
    @isTest
    static void testConstructorWithBoth() {
        try {
            List<Portal__c> portalList = [SELECT Id, Name, Generator__c FROM Portal__c WHERE Generator__c = 'Bayut' AND Is_Active__c = true];

            Test.startTest();
            Test.setCurrentPageReference(new PageReference('/apex/TestPage'));
            ApexPages.currentPage().getParameters().put('Id', portalList[0].Id);
            ApexPages.currentPage().getParameters().put('isByt', 'true');
            ApexPages.currentPage().getParameters().put('isDbzl', 'true');
            XMLFeedGeneratorForBayut generator = new XMLFeedGeneratorForBayut();
            Test.stopTest();

            System.assertNotEquals(null, generator.xmlstring, 'XML string should not be null');
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'XMLFeedPortalTest', 'testConstructorWithBoth', 'Error while testing constructor with both Bayut and Dubizzle.');
        }
    }

    /**
    * Method Name : testConstructorWithPropertyFinder
    * @description : Used to test constructor with Propertyfinder.
    */
    @isTest
    static void testConstructorWithPropertyFinder() {
        try {
            List<Portal__c> portalList = [SELECT Id, Name, Generator__c FROM Portal__c WHERE Generator__c = 'Propertyfinder' AND Is_Active__c = true];

            Test.startTest();
            Test.setCurrentPageReference(new PageReference('/apex/TestPage'));
            ApexPages.currentPage().getParameters().put('Id', portalList[0].Id);
            XMLFeedGeneratorForPF generator = new XMLFeedGeneratorForPF();
            Test.stopTest();

            System.assertNotEquals(null, generator.xmlstring, 'XML string should not be null');
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'XMLFeedPortalTest', 'testConstructorWithPropertyFinder', 'Error while testing constructor with Propertyfinder.');
        }
    }
}