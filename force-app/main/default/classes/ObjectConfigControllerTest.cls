/**
* Class Name: ObjectConfigControllerTest
* @description: Test class for ObjectConfigController.
* Created Date: 1 Apr, 2025
* Created By: Rachit Shah
*--------------------------------------------------------------------------------
* Last Modified By: 
* Last Modified Date: 
* Last Modification Description: 
**/
@IsTest
public with sharing class ObjectConfigControllerTest {

    @TestSetup
    static void setupTestData() {
        // Create a sample Contact record
        Contact contact = new Contact(FirstName = 'Test', LastName = 'User', Phone = '1234567890');
        insert contact;
    }

    @IsTest
    static void testGetObjectsWithPhoneField() {
        Test.startTest();
        List<Map<String, String>> result = ObjectConfigController.getObjectsWithPhoneField();
        Test.stopTest();

        System.assertNotEquals(0, result.size(), 'Expected phone field objects');
    }

    @IsTest
    static void testGetRequiredFields() {
        Test.startTest();
        List<Map<String, Object>> result = ObjectConfigController.getRequiredFields('Contact');
        Test.stopTest();

        System.assertNotEquals(0, result.size(), 'Expected required fields');
        System.assertEquals('Phone', ((List<Map<String, String>>)result[0].get('phoneFields'))[0].get('value'), 'Expected phone field');
    }

    @IsTest
    static void testGetTextAndPhoneFields() {
        Test.startTest();
        List<Map<String, Object>> result = ObjectConfigController.getTextAndPhoneFields('Contact');
        Test.stopTest();

        System.assertNotEquals(0, result.size(), 'Expected text and phone fields');
    }

    @IsTest
    static void testGetUserConfig() {
        Test.startTest();
        Map<String, String> result = ObjectConfigController.getUserConfig();
        Test.stopTest();

        System.assertNotEquals(null, result.get('ObjectConfigInfo'), 'Expected ObjectConfigInfo data');
    }

    @IsTest
    static void testSaveUserConfig() {
        Test.startTest();
        String jsonData = '{"objectApiName":"Contact","phoneField":"Phone"}';
        String jsonDataForChat = '{"Contact":{"nameField":"LastName","phoneField":"Phone"}}';

        String result = ObjectConfigController.saveUserConfig(jsonData, jsonDataForChat);
        Test.stopTest();

        System.assertNotEquals('sucess', result, 'Expected success response');
    }

    @IsTest
    static void testGetRecordName() {
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];

        Test.startTest();
        String recordName = ObjectConfigController.getRecordName(testContact.Id, 'Contact');
        Test.stopTest();

        System.assertEquals('Test User', recordName, 'Expected contact name');
    }
}