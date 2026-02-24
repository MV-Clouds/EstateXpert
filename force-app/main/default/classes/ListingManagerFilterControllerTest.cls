/**
* Class Name : ListingManagerFilterControllerTest
* Created By : Karan Singh
* Last Modified Date : 24/06/2024
* Last Modified By : Karan Singh
* @description : Test class for ListingManagerFilterController.
*/
@isTest
public class ListingManagerFilterControllerTest {

    /**
    * Method Name : testGetListingFields
    * @description : Used to test getListingFields method.
    */
    @isTest
    static void testGetListingFields() {
        try {
            Test.startTest();
            List<ListingManagerFilterController.FieldDetails> fields = ListingManagerFilterController.getListingFields('Account');
            Test.stopTest();

            // Assert that fields are returned
            System.assertNotEquals(null, fields);
            System.assert(fields.size() > 0, 'Field list should not be empty');

            // Check some field properties
            Boolean hasNameField = false;
            for (ListingManagerFilterController.FieldDetails field : fields) {
                if (field.fieldAPIName == 'Name') {
                    hasNameField = true;
                    break;
                }
            }
            System.assert(hasNameField, 'Field list should contain Name field');
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'ListingManagerFilterControllerTest', 'testGetListingFields', 'Error while testing getListingFields method.');
        }
    }

    /**
    * Method Name : testGetPicklistValues
    * @description : Used to test getPicklistValues method.
    */
    @isTest
    static void testGetPicklistValues() {
        try {
            Account account = new Account(Name = 'Test Account');
            insert account;

            // Test the getPicklistValues method
            Test.startTest();
            List<Map<String, String>> picklistValues = ListingManagerFilterController.getPicklistValues('Industry', 'Account');
            Test.stopTest();

            // Assert that picklist values are returned
            System.assertNotEquals(null, picklistValues);
            System.assert(picklistValues.size() > 0, 'Picklist values should not be empty');
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'ListingManagerFilterControllerTest', 'testGetPicklistValues', 'Error while testing getPicklistValues method.');
        }
    }

    @isTest
    static void testGetStaticFields() {
        Test.startTest();
        String result = ListingManagerFilterController.getStaticFields('MVEX__Listing__c','ListingManagerFilters');
        Test.stopTest();
    }

    @isTest
    static void testGetFilteredListings() {
        Test.startTest();
        String strnglst = ('Name = \'Test\'');
        List<MVEX__Listing__c> listings = ListingManagerFilterController.getFilteredListings(strnglst);

        Test.stopTest();

        System.assertNotEquals(null, listings, 'Result should not be null');
    }
}