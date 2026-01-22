@isTest
private with sharing class ErrorHandlerTest {

    @isTest
    public static void insertErrorMethodTest(){

        String test = 'Test method';

        DmlException d = new DmlException();
        d.setMessage(test);
        Error_Handling__c insertErrorMethod = ErrorHandler.insertErrordata(d,'Test Class','Test Method','Test Error');
        System.assertNotEquals(insertErrorMethod,null,'Method Should not return null');                          

    }
}