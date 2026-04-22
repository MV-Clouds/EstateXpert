public with sharing class SiteAndBookingController {
    public static List<WBConnect_Configuration__mdt> wbConfig = WBConnect_Configuration__mdt.getAll().values();

    // ─────────────────────────────────────────────────────────────────────────
    // Helper: get the Record Type Id for "Showing" on Event
    // ─────────────────────────────────────────────────────────────────────────
    private static Id showingRecordTypeId {
        get {
            if (showingRecordTypeId == null) {
                Map<String, Schema.RecordTypeInfo> rtMap =
                    Schema.SObjectType.Event.getRecordTypeInfosByDeveloperName();
                if (rtMap.containsKey('Showing')) {
                    showingRecordTypeId = rtMap.get('Showing').getRecordTypeId();
                }
            }
            return showingRecordTypeId;
        }
        private set;
    }

    @AuraEnabled
    public static Map<String, Object> getPropertyData(String listingId) {
        try {
            String escapedListingId = String.escapeSingleQuotes(listingId);
            Map<String, Object> result = new Map<String, Object>();
    
            List<Listing__c> listing = [SELECT Id, Name, Address__c, Listing_Type__c, Size__c, Property_Type__c, Property_Category__c, Bedrooms__c, Bathrooms__c, Description__c,
                                        Listing_Price__c, Property__c, CurrencyIsoCode, Listing_Address__c FROM Listing__c WHERE Id = :escapedListingId WITH USER_MODE LIMIT 1];
    
            List<Property_File__c> propertyFiles = new List<Property_File__c>();
            Set<Id> contactIds = new Set<Id>();
            List<Inquiry__c> propertyInquiries = [SELECT Id, Contact__c FROM Inquiry__c WHERE Listing__c = :escapedListingId WITH USER_MODE];
            for (Inquiry__c inquiry : propertyInquiries) {
                if (inquiry.Contact__c != null) {
                    contactIds.add(inquiry.Contact__c);
                }
            }
    
            if (!listing.isEmpty()) {
                propertyFiles = [SELECT Id, Name, BaseUrl__c FROM Property_File__c WHERE Property__c = :listing[0].Property__c WITH USER_MODE];
            }

            // Fetch contacts
            List<Contact> contacts = [SELECT Id, Name, Email, Phone FROM Contact WHERE Id IN :contactIds WITH USER_MODE];

            // Fetch the most recent Showing Event per Buyer
            Map<Id, Event> contactToEvent = new Map<Id, Event>();
            if (!contactIds.isEmpty()) {
                List<Event> showingEvents = [
                    SELECT Id, Buyer__c, Status__c, MVEX__Scheduled_Date__c, MVEX__Reschedule_Date__c, Communication_Method__c
                    FROM Event
                    WHERE Buyer__c IN :contactIds
                      AND Listing__c = :escapedListingId
                      AND RecordTypeId = :showingRecordTypeId
                    ORDER BY CreatedDate DESC
                ];
                for (Event ev : showingEvents) {
                    // Keep only the most recent event per buyer
                    if (!contactToEvent.containsKey(ev.Buyer__c)) {
                        contactToEvent.put(ev.Buyer__c, ev);
                    }
                }
            }

            // Map contacts with showing details
            List<Map<String, Object>> formattedContacts = new List<Map<String, Object>>();
            for (Contact c : contacts) {
                Map<String, Object> contactMap = new Map<String, Object>();
                Event ev = contactToEvent.get(c.Id);
                contactMap.put('Id', c.Id);
                contactMap.put('Name', c.Name);
                contactMap.put('Email', c.Email);
                contactMap.put('MobilePhone', c.Phone);
                contactMap.put('ShowingId', ev == null ? '' : ev.Id);
                contactMap.put('ShowingStatus', ev == null ? 'Not Scheduled' : ev.Status__c);
                contactMap.put('ScheduleDate', ev == null ? '' : String.valueOf(ev.MVEX__Scheduled_Date__c));
                contactMap.put('RescheduleDate', ev == null ? '' : String.valueOf(ev.MVEX__Reschedule_Date__c));
                contactMap.put('CommunicationMethod', ev == null ? '' : ev.Communication_Method__c);
                formattedContacts.add(contactMap);
            }
            
            result.put('listing', listing);
            result.put('images', propertyFiles);
            result.put('contacts', formattedContacts);
            
            return result;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'SiteAndBookingController', 'getPropertyData', e.getMessage());
            return null;
        }
    }

    private static Integer parseDuration(String durationValue) {
        if (durationValue == '15 Minutes') return 15;
        if (durationValue == '30 Minutes') return 30;
        if (durationValue == '45 Minutes') return 45;
        if (durationValue == '1 Hour') return 60;
        if (durationValue == '1.5 Hours') return 90;
        if (durationValue == '2 Hours') return 120;
        return 60;
    }

    @AuraEnabled
    public static void sendEmailsAndCreateShowings(List<Id> contactIds, String listingId, Datetime scheduleDateTime, String durationValue, String communicationMethod, Boolean isReschedule) {
        try {
            // Determine the appropriate email template based on whether it's a schedule or reschedule
            String templateName = isReschedule ? 'RescheduleConfirmationEmail' : 'Showing_Confirmation';
            EmailTemplate template = [SELECT Id, Subject, HtmlValue, Body FROM EmailTemplate WHERE DeveloperName = :templateName WITH USER_MODE LIMIT 1];

            System.debug('scheduleDateTime: ' + scheduleDateTime);
            // Create or update showings
            Map<String, Object> showingResult = createShowings(contactIds, listingId, scheduleDateTime, durationValue, communicationMethod);
            List<Id> showingIds = (List<Id>)showingResult.get('showingIds');

            // Fetch inserted/updated showings with contact email
            List<Event> insertedShowings = [SELECT Id, Buyer__c, Buyer__r.Email FROM Event WHERE Id IN :showingIds];

            // Prepare emails
            List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
            for (Event show : insertedShowings) {
                if (show.Buyer__r.Email != null) {
                    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                    mail.setToAddresses(new List<String>{show.Buyer__r.Email});
                    mail.setTemplateId(template.Id);
                    mail.setTargetObjectId(show.Buyer__c); // Contact ID for recipient
                    mail.setWhatId(show.Id); // Event ID for merge fields
                    mail.setSaveAsActivity(false);
                    emails.add(mail);
                }
            }
            
            // Send emails
            Messaging.sendEmail(emails);
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'SiteAndBookingController', 'sendEmailsAndCreateShowings', e.getMessage());
        }
    }

    @AuraEnabled
    public static Map<String, Object> createShowings(List<Id> contactIds, String listingId, Datetime scheduleDateTime, String durationValue, String communicationMethod) {
        Map<String, Object> result = new Map<String, Object>();
        List<Id> showingIds = new List<Id>();
        Map<Id, Event> contactToShowing = new Map<Id, Event>();
        try {
            // Fetch existing showing Events for these contacts and listing
            Map<Id, Event> existingShowingsMap = new Map<Id, Event>();
            List<Event> existingShowings = [
                SELECT Id, Buyer__c, Listing__c, Status__c, MVEX__Scheduled_Date__c, MVEX__Showing_Duration__c
                FROM Event
                WHERE Buyer__c IN :contactIds
                  AND Listing__c = :listingId
                  AND RecordTypeId = :showingRecordTypeId
            ];
            for (Event s : existingShowings) {
                existingShowingsMap.put(s.Buyer__c, s);
            }

            List<Event> showingsToInsert = new List<Event>();
            List<Event> showingsToUpdate = new List<Event>();

            for (Id contactId : contactIds) {
                if (existingShowingsMap.containsKey(contactId)) {
                    // Update existing showing
                    Event existing = existingShowingsMap.get(contactId);
                    existing.Status__c = scheduleDateTime != null ? 'Waiting For Confirmation' : 'Scheduled';
                    if (scheduleDateTime != null) {
                        Integer durationMins = parseDuration(durationValue);
                        existing.MVEX__Scheduled_Date__c = scheduleDateTime;
                        existing.MVEX__Showing_Duration__c = durationMins;
                        existing.StartDateTime = scheduleDateTime;
                        existing.EndDateTime = scheduleDateTime.addMinutes(durationMins);
                    }
                    existing.Communication_Method__c = communicationMethod;
                    showingsToUpdate.add(existing);
                    showingIds.add(existing.Id);
                    contactToShowing.put(contactId, existing);
                } else {
                    // Create new showing Event
                    Event newShowing = new Event(
                        RecordTypeId = showingRecordTypeId,
                        Buyer__c = contactId,
                        Listing__c = listingId,
                        Status__c = scheduleDateTime != null ? 'Waiting For Confirmation' : 'Scheduled',
                        Communication_Method__c = communicationMethod,
                        Subject = 'Showing'
                    );
                    if (scheduleDateTime != null) {
                        Integer durationMins = parseDuration(durationValue);
                        newShowing.MVEX__Scheduled_Date__c = scheduleDateTime;
                        newShowing.MVEX__Showing_Duration__c = durationMins;
                        newShowing.StartDateTime = scheduleDateTime;
                        newShowing.EndDateTime = scheduleDateTime.addMinutes(durationMins);
                    } else {
                        newShowing.StartDateTime = System.now();
                        newShowing.MVEX__Showing_Duration__c = 60;
                        newShowing.EndDateTime = System.now().addMinutes(60);
                    }
                    showingsToInsert.add(newShowing);
                }
            }

            if (!showingsToInsert.isEmpty()) {
                insert showingsToInsert;
                for (Event s : showingsToInsert) {
                    showingIds.add(s.Id);
                    contactToShowing.put(s.Buyer__c, s);
                }
            }
            if (!showingsToUpdate.isEmpty()) {
                update showingsToUpdate;
            }

            result.put('showingIds', showingIds);
            // Convert contactToShowing to Map<String, Event> for serialization
            Map<String, Event> contactToShowingStringKey = new Map<String, Event>();
            for (Id contactId : contactToShowing.keySet()) {
                contactToShowingStringKey.put((String)contactId, contactToShowing.get(contactId));
            }
            result.put('contactToShowing', contactToShowingStringKey);

            return result;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'SiteAndBookingController', 'createShowings', e.getMessage());
            return null;
        }
    }

    @AuraEnabled
    public static Boolean updateShowing(Datetime rescheduleDateTime, String durationValue, String showingId, String communicationMethod) {
        try {
            if (String.isBlank(showingId) || rescheduleDateTime == null) {
                return false;
            }
            Integer durationMins = parseDuration(durationValue);
            Event showing = new Event(
                Id = showingId,
                MVEX__Reschedule_Date__c = rescheduleDateTime,
                Status__c = 'Rescheduled',
                Communication_Method__c = communicationMethod,
                MVEX__Showing_Duration__c = durationMins,
                StartDateTime = rescheduleDateTime,
                EndDateTime = rescheduleDateTime.addMinutes(durationMins)
            );
            update showing;
            return true;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'SiteAndBookingController', 'updateShowing', e.getMessage());
            return false;
        }
    }

    @AuraEnabled
    public static Boolean markShowingAsCompleted(String showingId) {
        try {
            if (String.isBlank(showingId)) {
                return false;
            }
            Event showing = new Event(
                Id = showingId,
                Status__c = 'Completed'
            );
            update showing;
            return true;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'SiteAndBookingController', 'markShowingAsCompleted', e.getMessage());
            return false;
        }
    }

    @AuraEnabled
    public static Map<String, Object> sendWhatsappMessage(String jsonData, String chatId, String showingId, String status) {
        Map<String, Object> resultMap = new Map<String, Object>{};
        Chat__c chat = new Chat__c(Id = chatId);
        try {
            HttpRequest httpReq = new HttpRequest();
            resultMap.put('errorMessage', null);

            if (wbConfig == null || wbConfig.isEmpty()) {
                chat.Message_Status__c = 'Failed';
                update as user chat;
                resultMap.put('errorMessage', 'METADATA_ERROR');
                resultMap.put('chat', chat);
                return resultMap;
            }

            String accessToken = wbConfig[0].Access_Token__c;
            String endpoint = wbConfig[0].APIEndpoint__c + '/' + wbConfig[0].APIVersion__c + '/' + wbConfig[0].Phone_Number_Id__c + '/messages';
            httpReq.setEndpoint(endpoint);
            httpReq.setMethod('POST');
            httpReq.setHeader('Content-Type', 'application/json');
            httpReq.setHeader('Authorization', 'Bearer ' + accessToken);
            httpReq.setBody(jsonData);
            Http http = new Http();
            HttpResponse response = http.send(httpReq);
            Integer statusCode = response.getStatusCode();
            System.debug('status Code: ' + statusCode);
            if (response != null && statusCode == 200) {
                String responseBody = response.getBody();
                Map<String, Object> jsonMap = (Map<String, Object>)JSON.deserializeUntyped(responseBody);
                List<Object> messages = (List<Object>)jsonMap.get('messages');
                Map<String, Object> firstMessage = (Map<String, Object>)messages[0];
                String whatsAppMessageID = (String) firstMessage.get('id');
                System.debug('WhatsAppMessageId__c: ' + whatsAppMessageID);
                System.debug('chatId: ' + chatId);
                System.debug('showingId: ' + showingId);
                // Update the chat record
                chat.WhatsAppMessageId__c = whatsAppMessageID;
                chat.Message_Status__c = 'Sent';
                if (String.isNotBlank(showingId)) {
                    Event showingToUpdate = new Event(Id = showingId);
                    showingToUpdate.Chat__c = chat.Id;
                    showingToUpdate.Status__c = status == 'Wait' ? 'Waiting For Confirmation' : status;
                    update showingToUpdate;
                }
            } else {
                chat.Message_Status__c = 'Failed';
                ErrorHandler.insertErrordata(null, 'SiteAndBookingController', 'sendWhatsappMessage', response.getStatusCode() + response.getBody() + ' and error at line 317');
            }

            resultMap.put('chat', chat);
        } catch (Exception e) {
            chat.Message_Status__c = 'Failed';
            ErrorHandler.insertErrordata(e, 'SiteAndBookingController', 'sendWhatsappMessage', e.getMessage());
            resultMap.put('errorMessage', e.getMessage());
            resultMap.put('chat', chat);
        }
        System.debug('chat: ' + chat);
        update as user chat;
        return resultMap;
    }

    @AuraEnabled
    public static List<Map<String, Object>> getShowingsFromToday() {
        try {
            Datetime todayStart = Datetime.newInstance(Date.today(), Time.newInstance(0, 0, 0, 0));

            List<Event> showings = [
                SELECT Id, Status__c, MVEX__Scheduled_Date__c, MVEX__Reschedule_Date__c, Buyer__r.Name, Listing__r.Name
                FROM Event
                WHERE (MVEX__Scheduled_Date__c >= :todayStart OR MVEX__Reschedule_Date__c >= :todayStart)
                  AND Status__c IN ('Waiting For Confirmation', 'Scheduled', 'Rescheduled')
                  AND RecordTypeId = :showingRecordTypeId
            ];

            List<Map<String, Object>> formattedShowings = new List<Map<String, Object>>();
            for (Event showing : showings) {
                Map<String, Object> showingMap = new Map<String, Object>();
                showingMap.put('Id', showing.Id);
                showingMap.put('MVEX__Status__c', showing.Status__c);
                showingMap.put('MVEX__Scheduled_Date__c', showing.MVEX__Scheduled_Date__c);
                showingMap.put('MVEX__Reschedule_Date__c', showing.MVEX__Reschedule_Date__c);
                showingMap.put('ContactName', showing.Buyer__r.Name);
                showingMap.put('ListingName', showing.Listing__r.Name);
                formattedShowings.add(showingMap);
            }
            
            return formattedShowings;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'SiteAndBookingController', 'getShowingsFromToday', e.getMessage());
            return null;
        }
    }

    @AuraEnabled(cacheable=false)
    public static Map<String,String> previewEmailTemplate(Id showingId, Boolean isReschedule, Id contactId, Id listingId, String dateStr, String timeStr) {
        try {
            Savepoint sp = Database.setSavepoint();
            Event showing;

            // 1. Create DateTime from date and time strings
            DateTime scheduledDateTime = System.now(); 
            if (String.isNotBlank(dateStr) && String.isNotBlank(timeStr)) {
                try {
                    String gmtDateTimeStr = dateStr + ' ' + timeStr + ':00';
                    scheduledDateTime = DateTime.valueOfGmt(gmtDateTimeStr);
                } catch (Exception e) {
                    System.debug('Error parsing date/time: ' + e.getMessage());
                }
            }

            // 2. Check if showing exists; if not, create a temporary one
            if (String.isNotBlank(showingId)) {
                List<Event> existingShowings = [SELECT Id, Buyer__c, Buyer__r.Email, Listing__c FROM Event WHERE Id = :showingId LIMIT 1];
                if (!existingShowings.isEmpty()) {
                    showing = existingShowings[0];
                    if (isReschedule && scheduledDateTime != null) {
                        showing.MVEX__Reschedule_Date__c = scheduledDateTime;
                        update showing;
                    }
                }
            } else if (contactId != null && listingId != null) {
                showing = new Event(
                    RecordTypeId = showingRecordTypeId,
                    Listing__c = listingId,
                    Buyer__c = contactId,
                    Status__c = 'Waiting For Confirmation',
                    MVEX__Scheduled_Date__c = scheduledDateTime,
                    Subject = 'Showing Preview',
                    StartDateTime = scheduledDateTime,
                    MVEX__Showing_Duration__c = 60,
                    EndDateTime = scheduledDateTime.addMinutes(60)
                );
                insert showing;
            }

            if (showing == null || showing.Id == null) {
                return null;
            }

            // 3. Refresh to get related data
            showing = [SELECT Id, Buyer__c, Buyer__r.Email, Listing__c FROM Event WHERE Id = :showing.Id LIMIT 1];

            // 4. Pick the correct EmailTemplate
            String templateName = isReschedule ? 'RescheduleConfirmationEmail' : 'Showing_Confirmation';
            EmailTemplate et = [SELECT Id FROM EmailTemplate WHERE DeveloperName = :templateName WITH USER_MODE LIMIT 1];

            // 5. Build email for preview using renderStoredEmailTemplate
            Messaging.SingleEmailMessage mail = Messaging.renderStoredEmailTemplate(et.Id, showing.Buyer__c, showing.Id);

            // 6. Rollback temporary insertion
            Database.rollback(sp);

            // 7. Return merged subject + HTML
            return new Map<String,String>{
                'subject'  => mail.getSubject(),
                'htmlBody' => mail.getHtmlBody()
            };
        }
        catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'SiteAndBookingController', 'previewEmailTemplate', e.getMessage());
            return null;
        }
    }

    @AuraEnabled
    public static Boolean updateShowingStatus(String showingId, String status) {
        try {
            if (String.isBlank(showingId) || String.isBlank(status)) {
                return false;
            }
            Event showing = new Event(
                Id = showingId,
                Status__c = status
            );
            update showing;
            return true;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'SiteAndBookingController', 'updateShowingStatus', e.getMessage());
            return false;
        }
    }
}