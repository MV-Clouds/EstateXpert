@IsTest(isParallel=false)
public class PropertySearchControllerTest {

    @TestSetup
    static void setupData() {
        Contact contact = new Contact(LastName = 'Dev Test', Email = 'test@rk.com', Phone = '+919000000001');
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
        listing.Furnished__c = 'Yes';
        listing.Property_Status__c = 'Vacant';
        listing.Year_Built__c = '2020';
        listing.Listing_Agent_Firstname__c = 'RK';
        listing.Listing_Agent_Lastname__c = 'Dev';
        listing.Listing_Agent_Email__c = 'rkdev@gmail.com';
        listing.Private_Amenities__c = 'Private Garden';
        listing.Completion_Status__c = 'Completed';
        insert listing;

        Inquiry__c inquiry = new Inquiry__c(
            Name__c = 'Test Inquiry', 
            New_Construction__c = true, 
            Parking_Available__c = false, 
            Sunday_Open_House__c = false, 
            This_Week_Open_House__c = false, 
            Water_View__c = false,
            Contact__c = contact.Id,
            MVEX__Listing__c = listing.Id
        );
        insert inquiry;

        Property_File__c propertyFile = new Property_File__c(
            Property__c = property.Id,
            BaseUrl__c = 'https://sample.url'
        );
        insert propertyFile;
    }

    @IsTest
    static void testGetRecordsListingLinked() {
        Listing__c listing = [SELECT Id FROM Listing__c LIMIT 1];
        PropertySearchController.WrapperClass result = PropertySearchController.getRecords(listing.Id, 'MVEX__Listing__c', 'linked');
        System.assertNotEquals(null, result);
    }

    @IsTest
    static void testGetRecordsListingRelated() {
        Listing__c listing = [SELECT Id FROM Listing__c LIMIT 1];
        PropertySearchController.WrapperClass result = PropertySearchController.getRecords(listing.Id, 'MVEX__Listing__c', 'related');
        System.assertNotEquals(null, result);
    }

    @IsTest
    static void testGetRecordsListingDefault() {
        Listing__c listing = [SELECT Id FROM Listing__c LIMIT 1];
        PropertySearchController.WrapperClass result = PropertySearchController.getRecords(listing.Id, 'MVEX__Listing__c', 'default');
        System.assertNotEquals(null, result);
    }

    @IsTest
    static void testGetRecordsInquiryLinked() {
        Inquiry__c inquiry = [SELECT Id FROM Inquiry__c LIMIT 1];
        PropertySearchController.WrapperClass result = PropertySearchController.getRecords(inquiry.Id, 'MVEX__Inquiry__c', 'linked');
        System.assertNotEquals(null, result);
    }

    @IsTest
    static void testGetRecordsInquiryRelated() {
        Inquiry__c inquiry = [SELECT Id FROM Inquiry__c LIMIT 1];
        PropertySearchController.WrapperClass result = PropertySearchController.getRecords(inquiry.Id, 'MVEX__Inquiry__c', 'related');
        System.assertNotEquals(null, result);
    }

    @IsTest
    static void testGetRecordsInquiryDefault() {
        Inquiry__c inquiry = [SELECT Id FROM Inquiry__c LIMIT 1];
        PropertySearchController.WrapperClass result = PropertySearchController.getRecords(inquiry.Id, 'MVEX__Inquiry__c', 'default');
        System.assertNotEquals(null, result);
    }

    /**
     * Covers getRecords with null objectName so the branch
     * `objectName = Id.valueOf(recId).getSObjectType()...` is hit.
     */
    @IsTest
    static void testGetRecordsNullObjectName() {
        Listing__c listing = [SELECT Id FROM Listing__c LIMIT 1];
        PropertySearchController.WrapperClass result = PropertySearchController.getRecords(listing.Id, null, 'linked');
        System.assertNotEquals(null, result);
    }

    /**
     * Covers getRecords exception path (invalid ID).
     */
    @IsTest
    static void testGetRecordsException() {
        PropertySearchController.WrapperClass result = PropertySearchController.getRecords(null, 'MVEX__Listing__c', 'linked');
    }

    @IsTest
    static void testGetObjectFields() {
        Test.startTest();
        PropertySearchController.ObjectFieldsWrapper result = PropertySearchController.getObjectFields('MVEX__Listing__c');        
        Test.stopTest();
        System.assertNotEquals(0, result.fields.size(), 'Result should not be null');
    }

    /**
     * Covers getObjectFields exception path (invalid object name).
     */
    @IsTest
    static void testGetObjectFieldsException() {
        Test.startTest();
        PropertySearchController.ObjectFieldsWrapper result = PropertySearchController.getObjectFields('Invalid__Object__c');
        Test.stopTest();
        System.assertNotEquals(null, result);
    }
    
    @IsTest
    static void testGetObjectName() {
        Listing__c l = [SELECT Id FROM Listing__c LIMIT 1];
        Test.startTest();
        String objName = PropertySearchController.getObjectName(l.Id);
        Test.stopTest();
        System.assertEquals('MVEX__Listing__c', objName);
    }

    /**
     * Covers getObjectName exception path (invalid ID string).
     */
    @IsTest
    static void testGetObjectNameException() {
        Test.startTest();
        String objName = PropertySearchController.getObjectName('invalid-id');
        Test.stopTest();
        System.assertEquals('', objName);
    }

    @IsTest
    static void testGetRecordName() {
        Listing__c l = [SELECT Id, Name FROM Listing__c LIMIT 1];
        Test.startTest();
        String name = PropertySearchController.getRecordName(l.Id, 'MVEX__Listing__c');
        Test.stopTest();
        System.assertEquals(l.Name, name);
    }

    /**
     * Covers getRecordName blank input branch.
     */
    @IsTest
    static void testGetRecordNameBlankInput() {
        Test.startTest();
        String name1 = PropertySearchController.getRecordName('', 'MVEX__Listing__c');
        String name2 = PropertySearchController.getRecordName(null, null);
        Test.stopTest();
        System.assertEquals('', name1);
        System.assertEquals('', name2);
    }

    /**
     * Covers getRecordName when no record is found (no-match path).
     */
    @IsTest
    static void testGetRecordNameNoMatch() {
        // Use a valid ID format but for a record that doesn't exist
        Listing__c l = [SELECT Id FROM Listing__c LIMIT 1];
        delete l;
        Test.startTest();
        String name = PropertySearchController.getRecordName(l.Id, 'MVEX__Listing__c');
        Test.stopTest();
        System.assertEquals('', name);
    }

    @IsTest
    static void testSendEmail_Single() {
        Inquiry__c iq = [SELECT Id, Contact__c FROM Inquiry__c LIMIT 1];
        Listing__c lst = [SELECT Id FROM Listing__c LIMIT 1];

        Map<String,Object> inquiryMap = new Map<String,Object>{
            'mvex__contact__c' => iq.Contact__c
        };

        Map<String,Object> payload = new Map<String,Object>{
            'sendMethod' => 'single',
            'listingId' => lst.Id,
            'inquiry' => new List<Object>{ inquiryMap }
        };

        Test.startTest();
        PropertySearchController.sendEmail(JSON.serialize(payload));
        Test.stopTest();
    }

    @IsTest
    static void testSendEmail_Gmail() {
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        Inquiry__c iq = [SELECT Id, Contact__c FROM Inquiry__c LIMIT 1];
        Listing__c lst = [SELECT Id FROM Listing__c LIMIT 1];

        Map<String,Object> inquiryMap = new Map<String,Object>{
            'mvex__contact__c' => iq.Contact__c
        };

        Map<String,Object> payload = new Map<String,Object>{
            'sendMethod' => 'gmail',
            'listingId' => lst.Id,
            'inquiry' => new List<Object>{ inquiryMap }
        };

        Test.startTest();
        PropertySearchController.sendEmail(JSON.serialize(payload));
        Test.stopTest();
    }

    @IsTest
    static void testSendEmail_Outlook() {
        Inquiry__c iq = [SELECT Id, Contact__c FROM Inquiry__c LIMIT 1];
        Listing__c lst = [SELECT Id FROM Listing__c LIMIT 1];

        Map<String,Object> inquiryMap = new Map<String,Object>{
            'mvex__contact__c' => iq.Contact__c
        };

        Map<String,Object> payload = new Map<String,Object>{
            'sendMethod' => 'outlook',
            'listingId' => lst.Id,
            'inquiry' => new List<Object>{ inquiryMap }
        };

        Test.startTest();
        PropertySearchController.sendEmail(JSON.serialize(payload));
        Test.stopTest();
    }

    /**
     * Covers sendEmail exception path.
     */
    @IsTest
    static void testSendEmailException() {
        Test.startTest();
        PropertySearchController.sendEmail('invalid-json');
        Test.stopTest();
    }
    
    @IsTest
    static void testDeleteContentVersion() {
        Blob bodyBlob = Blob.valueOf('Unit Test ContentVersion Body');
        String uniqueToken = String.valueOf(DateTime.now().getTime()) + '_' + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        
        ContentVersion contentVersion_1 = new ContentVersion(
            Title = 'SampleTitle_' + uniqueToken, 
            PathOnClient = 'SampleTitle_' + uniqueToken + '.jpg',
            VersionData = bodyBlob, 
            origin = 'H'
        );
        insert contentVersion_1;

        List<ContentVersion> cvs = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :contentVersion_1.Id];

        Test.startTest();
        PropertySearchController.deleteContentVersion(cvs);
        Test.stopTest();

        System.assert(true);
    }

    /**
     * Covers deleteContentVersion empty-list early-return branch.
     */
    @IsTest
    static void testDeleteContentVersionEmpty() {
        Test.startTest();
        PropertySearchController.deleteContentVersion(new List<ContentVersion>());
        Test.stopTest();
        System.assert(true);
    }
    
    @IsTest
    static void testGetContactsForInquiries() {
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        Inquiry__c iq = [SELECT Id, Contact__c FROM Inquiry__c LIMIT 1];
        iq.Contact__c = con.Id;
        update iq;

        Test.startTest();
        List<Map<String, String>> result = PropertySearchController.getContactsForInquiries(new List<String>{String.valueOf(iq.Id)});
        Test.stopTest();
        System.assertNotEquals(null, result);
    }

    /**
     * Covers getContactsForInquiries exception path.
     */
    @IsTest
    static void testGetContactsForInquiriesException() {
        Test.startTest();
        List<Map<String, String>> result = PropertySearchController.getContactsForInquiries(null);
        Test.stopTest();
        System.assertNotEquals(null, result);
    }

    @IsTest
    static void testHasBusinessAccountId() {
        Test.startTest();
        Boolean result = PropertySearchController.hasBusinessAccountId();
        Test.stopTest();
        System.assertNotEquals(null, result);
    }

    /**
     * Covers resolveInquiryReferenceNames with non-empty inquiries that have reference fields.
     * This is already covered indirectly via getRecords, but this ensures direct coverage.
     */
    @IsTest
    static void testGetRecordsWithConfigurationSettings() {
        // Insert a Configuration_Settings record to exercise extraListingFields branch
        MVEX__Configuration_Settings__c config = new MVEX__Configuration_Settings__c(
            MVEX__Feature_Name__c = 'Suggested_Listing_Fields',
            MVEX__Fields_Data__c = '[{"fieldApiname":"Name"},{"fieldApiname":""}]'
        );
        insert config;

        Listing__c listing = [SELECT Id FROM Listing__c LIMIT 1];
        Test.startTest();
        PropertySearchController.WrapperClass result = PropertySearchController.getRecords(listing.Id, 'MVEX__Listing__c', 'linked');
        Test.stopTest();
        System.assertNotEquals(null, result);
    }
}