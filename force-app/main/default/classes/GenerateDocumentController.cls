public with sharing class GenerateDocumentController {
       
    /*
    *********************************************************
    @description      : Method is used to fetch the Query and count of records from the query
    @param {none}
    @return           : {String} - current session Id
    ********************************************************
    */
    // @AuraEnabled
    // public static String getSessionId(){
    //     String sessionId;
    //     try{
    //         if(Test.isRunningTest()) { 
    //             sessionId = 'testSessionId';
    //         }else{
    //             sessionId = Page.UserSessionIdPage.getContent().toString();
    //         }
    //     }catch(Exception e){
    //         ErrorHandler.insertErrorData(e, 'GenerateDocumentController', 'getSessionId', 'Error while getting session id.');
    //     }
    //     return sessionId;
    // }
}