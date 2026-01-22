/**
* Class Name: WhatsAppMessageBatchSchedulable
* Test Class: BroadcastMessageControllerTest
* Description: This class is used to schedule the batch process.
* Created Date: 03 April 2025
* Created By: Rachit Shah
*--------------------------------------------------------------------------------
**/

global with sharing class WhatsAppMessageBatchSchedulable  {

    // global String templateId;
    // global List<Chat__c> chatRecs;
    // global String broadcastId;
    // global String objectApiName;
    // global String phoneField;
    
    // global WhatsAppMessageBatchSchedulable(String tempId, List<Chat__c> chats, String broadcastRecId, String objName, String phoneFieldName) {
    //     this.templateId = tempId;
    //     this.chatRecs = chats;
    //     this.broadcastId = broadcastRecId;
    //     this.objectApiName = objName;
    //     this.phoneField = phoneFieldName;
    // }
    
    // /*
    // *********************************************************
    // @description     : This method is used to execute the batch process.
    // @param           : bc - Batchable context
    // @param           : scope - Scope of the batch process
    // ********************************************************
    // */
    // global void execute(SchedulableContext context){
    //     WhatsAppMessageBatch batchJob = new WhatsAppMessageBatch(this.templateId, this.chatRecs, this.broadcastId, this.objectApiName, this.phoneField);
    //     Database.executeBatch(batchJob, 1);
    // }
}