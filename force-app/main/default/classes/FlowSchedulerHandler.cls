public with sharing class FlowSchedulerHandler {
    // @InvocableMethod(label='Process Payment Schedule Records via Flow' description='Receive List of Payment_Schedule__c records from Flow and send payment reminders')
    // public static void handleInstallments(List<FlowInputs> inputs) {
    //     try{

    //         // Collect all Payment_Schedule__c records and their IDs
    //         List<Payment_Schedule__c> installmentsFromFlow = new List<Payment_Schedule__c>();
    //         Set<Id> installmentIds = new Set<Id>();
    //         for (FlowInputs input : inputs) {
    //             if (input.installmentsFromFlow != null) {
    //                 installmentsFromFlow.addAll(input.installmentsFromFlow);
    //                 for (Payment_Schedule__c installment : input.installmentsFromFlow) {
    //                     installmentIds.add(installment.Id);
    //                 }
    //             }
    //         }
    
    //         if (installmentsFromFlow.isEmpty()) {
    //             System.debug('No Payment_Schedule__c records received from Flow. Exiting.');
    //             return;
    //         }
    
    //         // Query all necessary data in a single SOQL query
    //         Map<Id, Payment_Schedule__c> installmentMap = new Map<Id, Payment_Schedule__c>([ SELECT Id,Amount__c, Due_Date__c, Installment_Type__c, Status__c,Payer__c, Payer__r.Email,Payment_Plan__r.Amount__c, Payment_Plan__r.Payment_Plan__c FROM Payment_Schedule__c WHERE Id IN :installmentIds WITH USER_MODE]);
    
    //         System.debug('Queried ' + installmentMap.size() + ' Payment_Schedule__c records.');
    
    //         // Pass the map to PaymentScheduleReminder
    //         PaymentScheduleReminder reminder = new PaymentScheduleReminder();
    //         reminder.sendReminderEmails(installmentMap);
    //     }catch(Exception e){
    //         System.debug('Error processing payment schedule records: ' + e.getMessage());
    //     }
    // }

    // public class FlowInputs {
    //     @InvocableVariable
    //     public List<Payment_Schedule__c> installmentsFromFlow;
    // }
}