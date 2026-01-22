@IsTest
public class RecordManagersCmpControllerTest {
    
    @IsTest
    static void testGetListingFieldsParent() {
        Test.startTest();
        
        // Call the getListingFieldsParent method
        List<RecordManagersCmpController.FieldDetails> result = RecordManagersCmpController.getListingFieldsParent('Account');
        
        // Assertions
        System.assertNotEquals(null, result, 'The result should not be null.');
        System.assertNotEquals(0, result.size(), 'There should be some fields returned.');
        
        Test.stopTest();
    }
    
    @IsTest
    static void testSaveMappings() {
        Test.startTest();
        
        String checklistData = 'Test Checklist Data';
        Integer totalPages = 5;
        RecordManagersCmpController.saveMappings(checklistData, totalPages, 'MVEX__Listing__c', 'test');
        
        Test.stopTest();

        List<recordManagerConfig__mdt> metaData = [SELECT Id, MasterLabel FROM recordManagerConfig__mdt LIMIT 1];
        System.AssertNotEquals(0, metaData.size(), 'At least one metadata should be created.');
    }

    @IsTest
    static void testGetObjectFields() {
        Test.startTest();
        RecordManagersCmpController.RecordManagerData results = RecordManagersCmpController.getObjectFields('MVEX__Listing__c', 'Test F');
        Test.stopTest();

        System.assertNotEquals(null, results, 'The result should not be null.');
    }

    @IsTest
    static void testGetObjectFieldsWithMetaData() {
        Test.startTest();
        RecordManagersCmpController.RecordManagerData results = RecordManagersCmpController.getObjectFieldsWithMetaData('MVEX__Listing__c');
        Test.stopTest();

        System.assertNotEquals(null, results, 'The result should not be null.');
    }
}