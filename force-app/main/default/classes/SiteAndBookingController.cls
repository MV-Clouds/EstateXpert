public with sharing class SiteAndBookingController {
    public static List<WBConnect_Configuration__mdt> wbConfig = WBConnect_Configuration__mdt.getAll().values(); 

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
            
            // Fetch related Contacts with Showing details
            List<Contact> contacts = [SELECT Id, Name, Email, Phone,
                                    (SELECT Id, Status__c, Scheduled_Date__c, Reschedule_Date__c, Communication_Method__c FROM Showings__r WHERE Listing__c = :escapedListingId ORDER BY CreatedDate DESC LIMIT 1)
                                    FROM Contact WHERE Id IN :contactIds WITH USER_MODE];
            
            // Map contacts with showing details
            List<Map<String, Object>> formattedContacts = new List<Map<String, Object>>();
            for (Contact c : contacts) {
                Map<String, Object> contactMap = new Map<String, Object>();
                contactMap.put('Id', c.Id);
                contactMap.put('Name', c.Name);
                contactMap.put('Email', c.Email);
                contactMap.put('MobilePhone', c.Phone);
                contactMap.put('ShowingId', c.Showings__r.isEmpty() ? '' : c.Showings__r[0].Id);
                contactMap.put('ShowingStatus', c.Showings__r.isEmpty() ? 'Not Scheduled' : c.Showings__r[0].Status__c);
                contactMap.put('ScheduleDate', c.Showings__r.isEmpty() ? '' : String.valueOf(c.Showings__r[0].Scheduled_Date__c));
                contactMap.put('RescheduleDate', c.Showings__r.isEmpty() ? '' : String.valueOf(c.Showings__r[0].Reschedule_Date__c));
                contactMap.put('CommunicationMethod', c.Showings__r.isEmpty() ? '' : c.Showings__r[0].Communication_Method__c);
                
                formattedContacts.add(contactMap);
            }
            
            result.put('listing', listing);
            result.put('images', propertyFiles);
            result.put('contacts', formattedContacts);
            
            return result;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'SiteAndBookingController', 'getPropertyData', e.getMessage());
            throw new AuraHandledException('Error fetching property data: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void sendEmailsAndCreateShowings(List<Id> contactIds, String listingId, Datetime scheduleDateTime, String communicationMethod) {
        try {
            // Determine the appropriate email template based on whether it's a schedule or reschedule
            String templateName = scheduleDateTime != null ? 'Showing_Confirmation' : 'RescheduleConfirmationEmail';
            EmailTemplate template = [SELECT Id, Subject, HtmlValue, Body FROM EmailTemplate WHERE DeveloperName = :templateName WITH USER_MODE LIMIT 1];

            System.debug('scheduleDateTime: ' + scheduleDateTime);
            // Create or update showings
            Map<String, Object> showingResult = createShowings(contactIds, listingId, scheduleDateTime, communicationMethod);
            List<Id> showingIds = (List<Id>)showingResult.get('showingIds');

            // Fetch inserted/updated showings with contact email
            List<Showing__c> insertedShowings = [SELECT Id, Buyer__c, Buyer__r.Email FROM Showing__c WHERE Id IN :showingIds WITH USER_MODE];


            // Prepare emails
            List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
            for (Showing__c show : insertedShowings) {
                if (show.Buyer__r.Email != null) {
                    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                    mail.setToAddresses(new List<String>{show.Buyer__r.Email});
                    mail.setTemplateId(template.Id);
                    mail.setTargetObjectId(show.Buyer__c); // Contact ID for recipient
                    mail.setWhatId(show.Id); // Showing ID for merge fields
                    mail.setSaveAsActivity(true);
                    emails.add(mail);
                }
            }
            
            // Send emails
            Messaging.sendEmail(emails);
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'SiteAndBookingController', 'sendEmailsAndCreateShowings', e.getMessage());
            throw new AuraHandledException('Error sending emails and creating showings: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static Map<String, Object> createShowings(List<Id> contactIds, String listingId, Datetime scheduleDateTime, String communicationMethod) {
        Map<String, Object> result = new Map<String, Object>();
        List<Id> showingIds = new List<Id>();
        Map<Id, Showing__c> contactToShowing = new Map<Id, Showing__c>();
        try {
            // Fetch existing showings for these contacts and listing
            Map<Id, Showing__c> existingShowingsMap = new Map<Id, Showing__c>();
            List<Showing__c> existingShowings = [SELECT Id, Buyer__c, Listing__c, Status__c, Scheduled_Date__c FROM Showing__c WHERE Buyer__c IN :contactIds AND Listing__c = :listingId WITH USER_MODE];
            for (Showing__c s : existingShowings) {
                existingShowingsMap.put(s.Buyer__c, s);
            }

            List<Showing__c> showingsToInsert = new List<Showing__c>();
            List<Showing__c> showingsToUpdate = new List<Showing__c>();

            for (Id contactId : contactIds) {
                if (existingShowingsMap.containsKey(contactId)) {
                    // Update existing showing
                    Showing__c existing = existingShowingsMap.get(contactId);
                    existing.Status__c = scheduleDateTime != null ? 'Waiting For Confirmation' : 'Scheduled';
                    existing.Scheduled_Date__c = scheduleDateTime;
                    existing.Communication_Method__c = communicationMethod;
                    showingsToUpdate.add(existing);
                    showingIds.add(existing.Id);
                    contactToShowing.put(contactId, existing);
                } else {
                    // Create new showing
                    Showing__c newShowing = new Showing__c(
                        Buyer__c = contactId,
                        Listing__c = listingId,
                        Status__c = scheduleDateTime != null ? 'Waiting For Confirmation' : 'Scheduled',
                        Scheduled_Date__c = scheduleDateTime,
                        Communication_Method__c = communicationMethod
                    );
                    showingsToInsert.add(newShowing);
                }
            }

            if (!showingsToInsert.isEmpty()) {
                insert as user showingsToInsert;
                for (Showing__c s : showingsToInsert) {
                    showingIds.add(s.Id);
                    contactToShowing.put(s.Buyer__c, s);
                }
            }
            if (!showingsToUpdate.isEmpty()) {
                update as user showingsToUpdate;
            }

            result.put('showingIds', showingIds);
            // Convert contactToShowing to Map<String, Showing__c> for serialization
            Map<String, Showing__c> contactToShowingStringKey = new Map<String, Showing__c>();
            for (Id contactId : contactToShowing.keySet()) {
                contactToShowingStringKey.put((String)contactId, contactToShowing.get(contactId));
            }
            result.put('contactToShowing', contactToShowingStringKey);

            return result;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'SiteAndBookingController', 'createShowings', e.getMessage());
            throw new AuraHandledException('Error creating showings: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static Boolean updateShowing(Datetime rescheduleDateTime, String showingId, String communicationMethod) {
        try {
            if (String.isBlank(showingId) || rescheduleDateTime == null) {
                return false;
            }
            Showing__c showing = new Showing__c(
                Id = showingId,
                Reschedule_Date__c = rescheduleDateTime,
                Status__c = 'Rescheduled',
                Communication_Method__c = communicationMethod
            );
            update as user showing;
            return true;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'SiteAndBookingController', 'updateShowing', e.getMessage());
            throw new AuraHandledException('Error updating showing: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static Boolean markShowingAsCompleted(String showingId) {
        try {
            if (String.isBlank(showingId)) {
                return false;
            }
            Showing__c showing = new Showing__c(
                Id = showingId,
                Status__c = 'Completed'
            );
            update as user showing;
            return true;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'SiteAndBookingController', 'markShowingAsCompleted', e.getMessage());
            throw new AuraHandledException('Error marking showing as completed: ' + e.getMessage());
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
            String endpoint = wbConfig[0].API_Endpoint__c + '/' + wbConfig[0].API_Version__c + '/' + wbConfig[0].Phone_Number_Id__c + '/messages';
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
                Showing__c showingToUpdate = new Showing__c(Id = showingId);
                showingToUpdate.Chat__c = chat.Id;
                showingToUpdate.Status__c = status == 'Wait' ? 'Waiting For Confirmation' : status;
                update as user showingToUpdate;
            } else {
                chat.Message_Status__c = 'Failed';
                ErrorHandler.insertErrordata(null, 'SiteAndBookingController', 'sendWhatsappMessage', response.getStatusCode() + response.getBody());
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
            
            List<Showing__c> showings = [
                SELECT Id, Status__c, Scheduled_Date__c, Reschedule_Date__c, Buyer__r.Name, Listing__r.Name
                FROM Showing__c
                WHERE (Scheduled_Date__c >= :todayStart OR Reschedule_Date__c >= :todayStart)
                WITH USER_MODE
            ];
            
            List<Map<String, Object>> formattedShowings = new List<Map<String, Object>>();
            for (Showing__c showing : showings) {
                Map<String, Object> showingMap = new Map<String, Object>();
                showingMap.put('Id', showing.Id);
                showingMap.put('Status__c', showing.Status__c);
                showingMap.put('Scheduled_Date__c', showing.Scheduled_Date__c);
                showingMap.put('Reschedule_Date__c', showing.Reschedule_Date__c);
                showingMap.put('ContactName', showing.Buyer__r.Name);
                showingMap.put('ListingName', showing.Listing__r.Name);
                formattedShowings.add(showingMap);
            }
            
            return formattedShowings;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'SiteAndBookingController', 'getShowingsFromToday', e.getMessage());
            throw new AuraHandledException('Error fetching showings: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=false)
    public static Map<String,String> previewEmailTemplate(Id showingId, Boolean isReschedule, Id contactId, Id listingId,  String dateStr, 
    String timeStr ) {
        try {
            Savepoint sp = Database.setSavepoint();
            Showing__c showing;

             // ---------------------------------------------------------
            // 1. Create DateTime from date and time strings
            // ---------------------------------------------------------
            DateTime scheduledDateTime = System.now(); // Default to now
            
            if (dateStr != null && timeStr != null) {
                    // Parse the date string
                    List<String> dateParts = dateStr.split('-');
                    Date selectedDate = Date.newInstance(
                        Integer.valueOf(dateParts[0]),  // year
                        Integer.valueOf(dateParts[1]),  // month  
                        Integer.valueOf(dateParts[2])   // day
                    );
                    
                    // Parse the time string
                    List<String> timeParts = timeStr.split(':');
                    Integer hour = Integer.valueOf(timeParts[0]);  // 15
                    Integer minute = Integer.valueOf(timeParts[1]); // 57
                    
                    String gmtDateTimeStr = dateStr + ' ' + timeStr + ':00';
                    scheduledDateTime = DateTime.valueOfGmt(gmtDateTimeStr);
                
            }

            // ---------------------------------------------------------
            // 2. Check if showing exists; if not, create a temporary one
            // ---------------------------------------------------------
            List<Showing__c> existingShowings = [
                SELECT Id, Buyer__c, Buyer__r.Email, Listing__c
                FROM Showing__c 
                WHERE Id = :showingId WITH USER_MODE
                LIMIT 1
            ];

            if (!existingShowings.isEmpty()) {
                showing = existingShowings[0];

                if (isReschedule && scheduledDateTime != null) {
                    showing.Reschedule_Date__c = scheduledDateTime;
                    update showing;
                }
                
            } else if (contactId != null && listingId != null) {
                // Create a temporary showing for preview purposes
                showing = new Showing__c();
                showing.Listing__c = listingId;
                showing.Buyer__c = contactId;
                showing.Status__c = 'Waiting For Confirmation';
                showing.Scheduled_Date__c = scheduledDateTime; 
                
                // Insert temporarily for preview
                insert showing;
            } else {
                throw new AuraHandledException('Either showingId must exist, or both contactId and listingId must be provided for preview.');
            }

            // ---------------------------------------------------------
            // 3. Refresh to get related data
            // ---------------------------------------------------------
            showing = [
                SELECT Id, Buyer__c, Buyer__r.Email, Listing__c, Listing__r.Name
                FROM Showing__c 
                WHERE Id = :showing.Id WITH USER_MODE
                LIMIT 1
            ];

            // ---------------------------------------------------------
            // 4. Pick the correct EmailTemplate
            // ---------------------------------------------------------
            String templateName = isReschedule 
                ? 'RescheduleConfirmationEmail' 
                : 'Showing_Confirmation';

            EmailTemplate et = [
                SELECT Id 
                FROM EmailTemplate 
                WHERE DeveloperName = :templateName WITH USER_MODE
                LIMIT 1
            ];

            // ---------------------------------------------------------
            // 5. Build email for preview
            // ---------------------------------------------------------
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setTemplateId(et.Id);
            mail.setTargetObjectId(showing.Buyer__c);
            mail.setWhatId(showing.Id);
            mail.setToAddresses(new List<String>{ showing.Buyer__r.Email });
            mail.setSaveAsActivity(false);

            // ---------------------------------------------------------
            // 6. Send (will be rolled back) → gets merged body
            // ---------------------------------------------------------
            Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ mail });

            // ---------------------------------------------------------
            // 7. Rollback all changes (temporary showing + email activity)
            // ---------------------------------------------------------
            Database.rollback(sp);

            // ---------------------------------------------------------
            // 8. Return merged subject + HTML
            // ---------------------------------------------------------
            return new Map<String,String>{
                'subject'  => mail.getSubject(),
                'htmlBody' => mail.getHtmlBody()
            };
        }
        catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Boolean updateShowingStatus(String showingId, String status) {
        try {
            if (String.isBlank(showingId) || String.isBlank(status)) {
                return false;
            }
            Showing__c showing = new Showing__c(
                Id = showingId,
                Status__c = status
            );
            update as user showing;
            return true;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'SiteAndBookingController', 'updateShowingStatus', e.getMessage());
            throw new AuraHandledException('Error updating showing status: ' + e.getMessage());
        }
    }
}