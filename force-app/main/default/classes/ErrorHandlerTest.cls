/**
 * Class Name : ErrorHandlerTest
 * Last Modified Date : 2026-10-13
 * Last Modified By : Dhruv Kakadiya
 * @description : Test class for ErrorHandler.
 * coverage : 100%
 */

@isTest
private with sharing class ErrorHandlerTest {

    @isTest
    public static void insertErrorMethodTest(){

        String test = 'Test method';

        DmlException d = new DmlException();
        d.setMessage(test);
        MVEX__Error_Handling__c insertErrorMethod = ErrorHandler.insertErrorData(d, 'Test Class', 'Test Method', 'Test Error');
        System.assertNotEquals(null, insertErrorMethod, 'Method Should not return null');                          
    }

    @isTest
    public static void catchExMethodTest(){
        String longClassName = 'A'.repeat(300);
        Test.startTest();
        MVEX__Error_Handling__c result = ErrorHandler.insertErrorData(null, longClassName, 'Test Method', 'Test Error');
        Test.stopTest();
        System.assertEquals(null, result, 'Method should return null when an exception is caught');
    }
}