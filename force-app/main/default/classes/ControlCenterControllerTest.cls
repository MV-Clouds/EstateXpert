@isTest
public with sharing class ControlCenterControllerTest {

    @isTest
    static void testGetMetadataRecords() {
        Test.startTest();
        List<Control_Center_Feature__mdt> result = ControlCenterController.getMetadataRecords();
        Test.stopTest();

        System.assertNotEquals(null, result, 'The method should return a non-null list');
    }
}