@isTest
public class CheckListItemControllerTest {

    @testSetup
    static void setupTestData() {
        Contact contact = new Contact(LastName = 'Dev Test');
        insert contact;

        Property__c property = new Property__c(Name = 'Dev Test');
        insert property;

        Listing__c listing = new Listing__c();
        listing.Name = 'Dev Test 12';
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
        listing.Available_From__c = Date.today();
        listing.Availability_Date__c = DateTime.now();
        listing.Bedrooms__c = 3;

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
        
        insert new List<Listing__c> { listing, listing1 };

        // Create test data for Checklist__c
        List<Checklist__c> checklistRecords = new List<Checklist__c>();

        Checklist__c cheklist1 = new Checklist__c();
        cheklist1.Name = 'Test Checklist';
        cheklist1.Field_Name__c = 'Availability_Date__c';
        cheklist1.Object_Name__c = 'Listing__c';
        cheklist1.Operator__c = 'Equals';
        cheklist1.Sequence__c = 1;
        cheklist1.Value__c = DateTime.now().format();
        cheklist1.Data_Type__c = 'DATETIME';
        checklistRecords.add(cheklist1);

        Checklist__c cheklist2 = new Checklist__c();
        cheklist2.Name = 'Test Checklist';
        cheklist2.Field_Name__c = 'Available_From__c';
        cheklist2.Object_Name__c = 'Listing__c';
        cheklist2.Operator__c = 'Contains';
        cheklist2.Sequence__c = 2;
        cheklist2.Value__c = Date.today().format();
        cheklist2.Data_Type__c = 'DATE';
        checklistRecords.add(cheklist2);

        Checklist__c cheklist3 = new Checklist__c();
        cheklist3.Name = 'Test Checklist';
        cheklist3.Field_Name__c = 'Bedrooms__c';
        cheklist3.Object_Name__c = 'Listing__c';
        cheklist3.Operator__c = 'Not Equals to';
        cheklist3.Sequence__c = 3;
        cheklist3.Value__c = '4';
        checklistRecords.add(cheklist3);

        Checklist__c cheklist4 = new Checklist__c();
        cheklist4.Name = 'Test Checklist';
        cheklist4.Field_Name__c = 'Bedrooms__c';
        cheklist4.Object_Name__c = 'Listing__c';
        cheklist4.Operator__c = 'Not Contains';
        cheklist4.Sequence__c = 4;
        cheklist4.Value__c = '1';
        checklistRecords.add(cheklist4);

        Checklist__c cheklist5 = new Checklist__c();
        cheklist5.Name = 'Test Checklist';
        cheklist5.Field_Name__c = 'Available_to__c';
        cheklist5.Object_Name__c = 'Listing__c';
        cheklist5.Operator__c = 'Is Null';
        cheklist5.Sequence__c = 5;
        cheklist5.Value__c = 'true';
        checklistRecords.add(cheklist5);

        Checklist__c cheklist6 = new Checklist__c();
        cheklist6.Name = 'Test Checklist';
        cheklist6.Field_Name__c = 'Available_to__c';
        cheklist6.Object_Name__c = 'Listing__c';
        cheklist6.Operator__c = 'Equals';
        cheklist6.Sequence__c = 5;
        cheklist6.Value__c = 'true';
        checklistRecords.add(cheklist6);

        Checklist__c cheklist7 = new Checklist__c();
        cheklist7.Name = 'Test Checklist';
        cheklist7.Field_Name__c = 'Available_to__c';
        cheklist7.Object_Name__c = 'Listing__c';
        cheklist7.Operator__c = 'Not Equals to';
        cheklist7.Sequence__c = 5;
        cheklist7.Value__c = 'true';
        checklistRecords.add(cheklist7);

        Checklist__c cheklist8 = new Checklist__c();
        cheklist8.Name = 'Test Checklist';
        cheklist8.Field_Name__c = 'Available_to__c';
        cheklist8.Object_Name__c = 'Listing__c';
        cheklist8.Operator__c = 'Is Null';
        cheklist8.Sequence__c = 5;
        cheklist8.Value__c = 'false';
        checklistRecords.add(cheklist8);

        Checklist__c cheklist9 = new Checklist__c();
        cheklist9.Name = 'Test Checklist';
        cheklist9.Field_Name__c = 'Available_to__c';
        cheklist9.Object_Name__c = 'Listing__c';
        cheklist9.Operator__c = 'Contains';
        cheklist9.Sequence__c = 5;
        cheklist9.Value__c = 'true';
        checklistRecords.add(cheklist9);

        Checklist__c cheklist50 = new Checklist__c();
        cheklist50.Name = 'Test Checklist';
        cheklist50.Field_Name__c = 'Available_to__c';
        cheklist50.Object_Name__c = 'Listing__c';
        cheklist50.Operator__c = 'Not Contains';
        cheklist50.Sequence__c = 5;
        cheklist50.Value__c = 'true';
        checklistRecords.add(cheklist50);

        insert checklistRecords;

        // Create test data for Checklist_Item__c
        List<Checklist_Item__c> checklistItemRecords = new List<Checklist_Item__c>();
        for (Checklist__c checklist : checklistRecords) {
            checklistItemRecords.add(new Checklist_Item__c(
                Checklist__c = checklist.Id,
                Is_Checked__c = false,
                Record_Id__c = listing.Id
            ));
        }
        insert checklistItemRecords;

    }

    @isTest
    static void testGetObjectFields() {
        Test.startTest();
        CheckListItemController.ObjectFieldsWrapper result = CheckListItemController.getObjectFields('Listing__c');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testGetCheckList() {
        Listing__c testListing = [SELECT Id FROM Listing__c WHERE Name = 'Dev Test 12' LIMIT 1];

        Test.startTest();
        CheckListItemController.ChecklistProgressData result = CheckListItemController.getCheckList('Listing__c', testListing.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'The result should not be null.');
    }

    @isTest
    static void testCreateCheckListItem() {
        List<Listing__c> testListing = [SELECT Id FROM Listing__c LIMIT 2];
        Checklist__c testChecklist = [SELECT Id FROM Checklist__c LIMIT 1];

        Test.startTest();
        String result = CheckListItemController.createCheckListItem(testListing[0].Id, testChecklist.Id, true);
        String result1 = CheckListItemController.createCheckListItem(testListing[1].Id, testChecklist.Id, true);
        Test.stopTest();

        System.assertEquals('success', result, 'Result should be success');
        System.assertEquals('success', result1, 'Result should be success');

    }

    @isTest
    static void testManageChecklistRecords() {
        List<Map<String, Object>> itemsToCreate = new List<Map<String, Object>>();
        Map<String, Object> newItem = new Map<String, Object>{
            'Name' => 'New Checklist Item',
            'Field_Name__c' => 'Bedrooms__c',
            'Object_Name__c' => 'Listing__c',
            'Operator__c' => 'Equals',
            'Sequence__c' => 1,
            'Value__c' => '5',
            'Description__c' => 'New Description'
        };
        itemsToCreate.add(newItem);

        List<Map<String, Object>> itemsToUpdate = new List<Map<String, Object>>();
        Checklist__c existingChecklist = [SELECT Id FROM Checklist__c LIMIT 1];
        Map<String, Object> updateItem = new Map<String, Object>{
            'Id' => existingChecklist.Id,
            'Description__c' => 'Updated Description'
        };
        itemsToUpdate.add(updateItem);

        List<String> itemsToDelete = new List<String>();
        Checklist__c checklistToDelete = [SELECT Id FROM Checklist__c LIMIT 1 OFFSET 1];
        itemsToDelete.add(checklistToDelete.Id);

        Test.startTest();
        String result = CheckListItemController.manageChecklistRecords(itemsToCreate, itemsToUpdate, itemsToDelete);
        Test.stopTest();

        System.assertEquals('success', result, 'Result should be success');

    }
}