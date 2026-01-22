public with sharing class EventReminderScheduler implements Schedulable {
    private Id eventId;

    // Constructor to pass Event Id
    public EventReminderScheduler(Id eventId) {
        this.eventId = eventId;
    }

    public void execute(SchedulableContext sc) {
        // Query event with related inquiry and contact details
        Event ev = [SELECT Id, Subject, StartDateTime, WhatId 
                    FROM Event 
                    WHERE Id = :eventId 
                    WITH USER_MODE
                    LIMIT 1];
        if (ev == null) {
            return;
        }

        // Query the related Inquiry and Contact email
        Inquiry__c inquiry = [SELECT Id, Name, Contact__r.Id, Contact__r.Email, Contact__r.FirstName, Contact__r.LastName 
                             FROM Inquiry__c 
                             WHERE Id = :ev.WhatId 
                             WITH USER_MODE
                             LIMIT 1];
        if (inquiry == null || inquiry.Contact__r == null || String.isBlank(inquiry.Contact__r.Email)) {
            return;
        }

        // Query the email template
        EmailTemplate template = [SELECT Id, HtmlValue, Subject 
                                 FROM EmailTemplate 
                                 WHERE DeveloperName = 'Event_Reminder_Template' 
                                 WITH USER_MODE
                                 LIMIT 1];
        if (template == null) {
            return;
        }

        // Get the HTML body and replace all merge fields
        String htmlBody = template.HtmlValue;
        if (htmlBody != null) {
            // Replace Contact merge fields
            htmlBody = htmlBody.replace('{!Contact.FirstName}', inquiry.Contact__r.FirstName != null ? inquiry.Contact__r.FirstName : '');
            htmlBody = htmlBody.replace('{!Contact.LastName}', inquiry.Contact__r.LastName != null ? inquiry.Contact__r.LastName : '');
            
            // Replace Event merge fields
            htmlBody = htmlBody.replace('{!Event.Subject}', ev.Subject != null ? ev.Subject : '');
            htmlBody = htmlBody.replace('{!Event.StartDateTime}', ev.StartDateTime != null ? ev.StartDateTime.format('MMMM d, yyyy h:mm a') : '');
            
            // Replace Inquiry merge field
            htmlBody = htmlBody.replace('{!Inquiry__c.Name}', inquiry.Name != null ? inquiry.Name : '');
        } else {
            return;
        }

        // Create the email message
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        
        // Set the recipient
        mail.setToAddresses(new List<String>{inquiry.Contact__r.Email});
        
        // Set the target object (Contact) for activity tracking
        mail.setTargetObjectId(inquiry.Contact__r.Id);
        
        // Set the WhatId to the Inquiry record for activity tracking
        mail.setWhatId(inquiry.Id);
        
        // Set the processed HTML body
        mail.setHtmlBody(htmlBody);
        
        // Set the email subject from the template or a default
        mail.setSubject(template.Subject != null ? template.Subject : 'Event Reminder');

        // Send the email
        try {
            Messaging.SendEmailResult[] results = Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{mail});
            if (results[0].isSuccess()) {
                System.debug('Email sent successfully to ' + inquiry.Contact__r.Email);
            } else {
                System.debug('Email sending failed: ' + results[0].getErrors()[0].getMessage());
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'EventReminderScheduler', 'execute', e.getMessage());
        }
    }
}