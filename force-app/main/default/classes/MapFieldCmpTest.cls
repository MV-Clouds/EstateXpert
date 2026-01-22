@isTest
public class MapFieldCmpTest {
    
    @isTest
    static void testGetObjectFields() {
        Test.startTest();
        List<Map<String, String>> fields = MapFieldCmp.getObjectFields('MVEX__Listing__c');
        Test.stopTest();
        
        System.assertNotEquals(0, fields.size(), 'Fields list should not be empty');
        System.assert(fields[0].containsKey('label'), 'Field map should contain label key');
        System.assert(fields[0].containsKey('apiName'), 'Field map should contain apiName key');
        System.assert(fields[0].containsKey('dataType'), 'Field map should contain dataType key');
    }

    @isTest
    static void testsaveMappingFields() {
        Test.startTest();
        MapFieldCmp.saveMappings('testListing:testProperty;testListing2:testProperty2', true);
        Test.stopTest();
        
    }
    
    @isTest
    static void testGetMetadata() {
        Test.startTest();
        List<String> metadataValues = MapFieldCmp.getMetadata();
        Test.stopTest();
        
        System.assertEquals(2, metadataValues.size(), 'There should be exactly two metadata values returned');
    }
}