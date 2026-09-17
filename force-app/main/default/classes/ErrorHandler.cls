/**
 * Class Name : ErrorHandler
 * Test Class : Pending
 * Created By : Mitrajsinh Gohil
 * Date : 12/06/2024
 * @description : Used to create Error log records for Error_Handling__c Object for both Aexp methods and JS methods
 */
public with sharing class ErrorHandler{
    /**
     Method Name : insertErrorData
     @param e to stored the Exception
     @param classname to stored the class name
     @param methodname to stored the method name
     @param ErrorBody to stored the Error Body
     @param Source to stored the Source of Error ex:- Apex or JS
     @return Error_Handling__c - reocrd of Error_Handling__c object
     @description insert error data into the obeject as record
     */
    public static MVEX__Error_Handling__c insertErrorData(Exception e, String classname, String methodname, String ErrorBody){
        try{

            String class_name = classname;
            String method_name = methodname;
            String Error_Body = ErrorBody;

            MVEX__Error_Handling__c error = new MVEX__Error_Handling__c();

            if (e != null) {
                error.MVEX__Error_Message__c = e.getMessage();
                error.MVEX__Error_Type__c = e.getTypeName();
                error.MVEX__Line_Number__c = String.valueOf(e.getLineNumber());
                error.MVEX__Label__c = e.getTypeName() + ' In ' + class_name + ' Of ' + method_name;
            }
            error.MVEX__Class_Name__c = class_name;
            error.MVEX__Method_Name__c = method_name;
            error.MVEX__Error_Body__c = Error_Body;
            error.MVEX__Source_of_Error__c = 'Apex';

            insert as user error;
            return error;

        } catch (Exception error){
            return null;
        }
    }
}