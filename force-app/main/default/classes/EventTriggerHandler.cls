public with sharing class EventTriggerHandler {

    // public static void handleAfterInsert(List<Event> newEvents) {
    //     if (newEvents == null || newEvents.isEmpty()) {
    //         return;
    //     }

    //     try {
    //         Date today = Date.today();
    //         Datetime now = Datetime.now();

    //         // Collect WhatIds to query Inquiry__c in bulk
    //         Set<Id> inquiryIds = new Set<Id>();
    //         for (Event ev : newEvents) {
    //             if (ev != null && ev.WhatId != null && ev.WhatId.getSObjectType() == Inquiry__c.SObjectType) {
    //                 inquiryIds.add(ev.WhatId);
    //             }
    //         }

    //         // Map Inquiry Id to Inquiry records with Contact email
    //         Map<Id, Inquiry__c> inquiriesMap = new Map<Id, Inquiry__c>();
    //         if (!inquiryIds.isEmpty()) {
    //             inquiriesMap = new Map<Id, Inquiry__c>([SELECT Id, Contact__r.Email FROM Inquiry__c WHERE Id IN :inquiryIds AND Contact__r.Email != null WITH USER_MODE]);
    //         }

    //         List<Event> validEvents = new List<Event>();

    //         for (Event ev : newEvents) {
    //             if (ev != null && ev.StartDateTime != null) {
    //                 Date eventDate = ev.StartDateTime.date();

    //                 // Check event date and time
    //                 if (eventDate == today && ev.StartDateTime > now.addHours(1)) {
    //                     // Check Inquiry & Contact email existence
    //                     if (ev.WhatId != null 
    //                         && ev.WhatId.getSObjectType() == Inquiry__c.SObjectType
    //                         && inquiriesMap.containsKey(ev.WhatId)) {
    //                         validEvents.add(ev);
    //                     } else {
    //                         System.debug('Skipping Event ' + ev.Id + ' due to missing or invalid Inquiry/Contact email.');
    //                     }
    //                 } else {
    //                     System.debug('Skipping Event ' + ev.Id + ' due to date/time condition.');
    //                 }
    //             } else {
    //                 System.debug('Skipping Event due to null StartDateTime or Event.');
    //             }
    //         }

    //         for (Event ev : validEvents) {
    //             String jobName = 'EventReminder_Trigger_' + ev.Id + '_' + now.getTime();
    //             String cronExp = FlowEventHandler.generateCronExpression(now);
    //             System.schedule(jobName, cronExp, new EventReminderScheduler(ev.Id));
    //         }
    //     } catch (Exception e) {
    //         ErrorHandler.insertErrorData(e, 'EventTriggerHandler', 'handleAfterInsert', e.getMessage());
    //     }
    // }
}