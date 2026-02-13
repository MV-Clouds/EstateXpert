/**
* Class Name : MarketingListCmpController
* Test Class : Pending
* Date : 21/06/2024
* Created By : Vyom Soni
* Last Modified Date : 08-07-2024
* Last Modified By : Vyom Soni
* @description : Used in the MarketingList lwc component
*/

public with sharing class MarketingListCmpController {
    /**
   * Class Name : WrapperClass
   * @description : this wrapper list set contacts and medias together.
   */
   public class WrapperClass{
       @AuraEnabled
       public List<Contact> contacts;  
       @AuraEnabled
       public Integer pageSize;
       @AuraEnabled
       public List<Map<String, String>> selectedFields;       
   }

   /**
   * Method Name : getContactData
   * @description : for the retrieve the contact data.
   * @return List<Contact>.
   */
   @AuraEnabled
   public static WrapperClass getContactData(){
       try {
            List<Map<String, String>> configuredFields = getConfiguredFields(); // Method to get selected fields from the config

            Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Contact.fields.getMap();
            List<String> allFields = new List<String>();
            
            for (String fieldName : fieldMap.keySet()) {
                allFields.add(fieldName);
            }

            MarketingListFilterConfig__mdt filterConfig = [SELECT BlockedFields__c FROM MarketingListFilterConfig__mdt WITH USER_MODE LIMIT 1];

            Set<String> blockedFields = new Set<String>();
            if (filterConfig != null && filterConfig.BlockedFields__c != null) {
                blockedFields.addAll(filterConfig.BlockedFields__c.split(';'));
            }
            List<String> filteredFields = new List<String>();

            for (String fieldName : allFields) {
                if (!blockedFields.contains(fieldName)) {
                    filteredFields.add(fieldName);
                }
            }

            String contactFields = String.join(filteredFields, ', ');
            String queryFields = String.escapeSingleQuotes(contactFields);
            Integer pageSize = getPageSizeFromConfig();
            String query = 'SELECT ' + queryFields + ' FROM Contact';

            List<Contact> contacts = Database.query(query, AccessLevel.USER_MODE);

            WrapperClass wc = new WrapperClass();
            wc.contacts = contacts; 
            wc.pageSize = pageSize;
            wc.selectedFields = configuredFields;
        
           return wc;
       } catch (Exception e) {
           ErrorHandler.insertErrorData(e, 'MarketingListCmpController', 'getContactData', 'Error while getting contact data.');
           throw new AuraHandledException(e.getMessage());
       }
   }

    /**
    * Method Name : getConfiguredFields
    * @description : Retrieves the configured fields (API names and labels) from custom metadata.
    * @return List<Map<String, String>>.
    */
    private static List<Map<String, String>> getConfiguredFields() {
        try {
            // Query Custom Object instead of Metadata
            List<MVEX__Configuration_Settings__c> configs = [
                SELECT MVEX__Fields_Data__c 
                FROM MVEX__Configuration_Settings__c 
                WHERE MVEX__Feature_Name__c = 'Marketing List' 
                AND MVEX__Object_API_Name__c = 'Contact' 
                WITH USER_MODE 
                LIMIT 1
            ];
            
            List<Map<String, String>> fields = new List<Map<String, String>>();
            
            if (!configs.isEmpty()) {
                MVEX__Configuration_Settings__c config = configs[0];
                String fieldsDataJson = config.MVEX__Fields_Data__c;
                
                if (String.isNotBlank(fieldsDataJson)) {
                    // Deserialize JSON to List<Map<String, String>>
                    fields = (List<Map<String, String>>)JSON.deserialize(fieldsDataJson, List<Map<String, String>>.class);
                }
            }
            
            return fields;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'MarketingListCmpController', 'getConfiguredFields', 'Error while getting configured fields.');
            return null;
        }
    }

    // Helper method to get pageSize from metadata
    private static Integer getPageSizeFromConfig() {
        try {
            // Query Custom Object instead of Metadata
            List<MVEX__Configuration_Settings__c> configs = [
                SELECT MVEX__Page_Size__c 
                FROM MVEX__Configuration_Settings__c 
                WHERE MVEX__Feature_Name__c = 'Marketing List' 
                AND MVEX__Object_API_Name__c = 'Contact' 
                WITH USER_MODE 
                LIMIT 1
            ];
        
            if (!configs.isEmpty()) {
                MVEX__Configuration_Settings__c config = configs[0];
                return config.MVEX__Page_Size__c != null ? Integer.valueOf(config.MVEX__Page_Size__c) : 30; // Default to 30 if not set
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'MarketingListCmpController', 'getPageSizeFromConfig', 'Error while getting page size from config.');
        }
        return 30;
    }

    /**
     * Class Name : sendEmail
     * @description : send to mass email
     */
    @AuraEnabled
    public static void sendEmail(String emailDataJson) {
        try {
            Map<String, Map<String, String>> contactEmailInfoMap = new Map<String, Map<String, String>>();

            Map<String, Object> emailData = (Map<String, Object>) JSON.deserializeUntyped(emailDataJson);

            String sendMethod = (String) emailData.get('sendMethod');
            String templateId = (String) emailData.get('templateId');
            String objectName = (String) emailData.get('objectName');
            String templateType = (String) emailData.get('templateType');
            String selectedListing = (String) emailData.get('selectedListing');

            List<GmailIntegrationControllerV1.EmailWrapper> gmails = new List<GmailIntegrationControllerV1.EmailWrapper>();
            List<OutlookIntegrationController.EmailWrapper> outlookMails = new List<OutlookIntegrationController.EmailWrapper>();

            String originalTemplateBody = ''; // Store original template body

            List<Template__c> temp = [SELECT Id, Template_Name__c,
                                        (SELECT Id, Template_Value_Simple__c,Value_Type__c FROM Template_Data__r WHERE Value_Type__c = 'Body Value' ORDER BY Order_No_Simple__c ASC),
                                        (SELECT Id, Page_Margin__c, Page_Orientation__c, Page_Size__c, Unit_of_Page_Configs__c, Show_Header__c, Show_Footer__c, Header_margin_top__c, Footer_margin_bottom__c FROM Template_Pages__r ORDER BY Page_Number__c ASC)
                                        FROM Template__c WHERE Id =: templateId WITH USER_MODE LIMIT 1 ];

            if(temp.size() > 0){
                for(Template_Data__c fieldData : temp[0].Template_Data__r){
                    String value = fieldData.Template_Value_Simple__c != null ? fieldData.Template_Value_Simple__c : '';
                    if(fieldData.Value_Type__c == 'Body Value'){
                        originalTemplateBody += value; // Build original template body
                    }
                }    
            }
            
            // Process both individual contacts and broadcast groups
            Set<String> allContactIds = new Set<String>();
            
            // Add individual contacts
            List<Object> contactListRaw = (List<Object>) emailData.get('contacts');
            if (contactListRaw != null) {
                for (Object contactRaw : contactListRaw) {
                    Map<String, Object> contactMap = (Map<String, Object>) contactRaw;
                    String contactId = (String) contactMap.get('Id');
                    if (contactId != null) {
                        allContactIds.add(contactId);
                    }
                }
            }
            
            // Add contacts from broadcast groups
            List<Object> broadcastGroupsData = (List<Object>) emailData.get('broadcastGroups');
            if (broadcastGroupsData != null && !broadcastGroupsData.isEmpty()) {
                List<String> broadcastGroupIds = new List<String>();
                for (Object groupObj : broadcastGroupsData) {
                    broadcastGroupIds.add((String) groupObj);
                }
                
                // Query broadcast group members and add to contacts list
                List<Broadcast_Group_Member__c> groupMembers = [
                    SELECT Contact_Id__c, Contact_Id__r.Name, Contact_Id__r.Email
                    FROM Broadcast_Group_Member__c 
                    WHERE Broadcast_Group_ID__c IN :broadcastGroupIds
                    WITH USER_MODE
                ];
                
                for (Broadcast_Group_Member__c member : groupMembers) {
                    if (objectName == 'Contact' && member.Contact_Id__c != null) {
                        allContactIds.add(member.Contact_Id__c);
                    }
                }
                
                System.debug('Added ' + (allContactIds.size() - (contactListRaw != null ? contactListRaw.size() : 0)) + ' contacts from broadcast groups');
            }
            
            // Validate total recipients for messaging service limits
            if (sendMethod == 'outlook' && allContactIds.size() > 20) {
                throw new AuraHandledException('Outlook has a limit of 20 recipients. Total recipients: ' + allContactIds.size() + '. Please select fewer recipients or use a different messaging service.');
            }
            
            // Convert contact IDs to contact objects for processing
            List<Map<String, Object>> contacts = new List<Map<String, Object>>();
            
            // Query all contacts based on object type
            if (objectName == 'Contact') {
                List<Contact> contactRecords = [SELECT Id, Name, Email FROM Contact WHERE Id IN :allContactIds WITH USER_MODE];
                for (Contact con : contactRecords) {
                    contacts.add(new Map<String, Object>{
                        'Id' => con.Id,
                        'Name' => con.Name,
                        'Email' => con.Email
                    });
                }
            }
            
            List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

            List<Template__c> temps = [SELECT Id, Name,Label__c,Object_Name__c, Object_API_Name__c,Template_Body__c,Template_Type__c, Template_Name__c, Template_pattern__c, Template_Status__c, Description__c, CreatedDate, LastModifiedDate,Subject__c,
                                        (SELECT Id, Name, Template_Value_Simple__c FROM Template_Data__r WHERE Value_Type__c = 'Extracted Mapping Keys' ORDER BY Order_No_Simple__c ASC)
                                        FROM Template__c  WHERE Id =:templateId WITH USER_MODE];
            String extractedKeyString = '';

            // get extracted Keys stored in field...
            for(Template_Data__c fieldData : temps[0].Template_Data__r){
                extractedKeyString +=  fieldData.Template_Value_Simple__c;
            }

            extractedKeyString = extractedKeyString != '' ? extractedKeyString : 'null';
            String sourceObjectAPI = temps[0].Object_API_Name__c;
            // Type cast extracted key field value to key mappign keys, child object info and merge tempalte keys....
            Map<String, Object> extractedKeyMap = (Map<String, Object>) JSON.deserializeUntyped(extractedKeyString);

            Set<Id> conIds = new Set<Id>();

            for (Map<String, Object> contact : contacts) {
                String contactId = (String) contact.get('Id');
                conIds.add(contactId);
            }
            
            // Get mapping keys for all contacts at once
            Map<String, Map<String, String>> allContactMappingKeys = DataMappingControllerV2.getMappingsKeyValues2(extractedKeyMap, sourceObjectAPI, conIds, true);

            for (Map<String, Object> contact : contacts) {
                Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                String contactEmail = (String) contact.get('Email');
                String contactId = (String) contact.get('Id');
                
                if (contactEmail != null && contactEmail != '') {
                    // Create a fresh copy of the template body for each contact
                    String personalizedTemplateBody = originalTemplateBody;

                    // Get mapping keys specific to this contact
                    Map<String, Map<String, String>> contactSpecificMappingKeys = DataMappingControllerV2.getMappingsKeyValues2(extractedKeyMap, sourceObjectAPI, new Set<Id>{contactId}, true);
                    
                    Map<String, String> mappingKeyVsMappingValues = contactSpecificMappingKeys.get('objectNGeneral');
                    Map<String, String> salesforceImages = contactSpecificMappingKeys.get('salesforceImages');
            
                    // Replace merge fields in the personalized template body
                    if (mappingKeyVsMappingValues != null) {
                        for(String key : mappingKeyVsMappingValues.keySet()) {
                            String escapedKey = Pattern.quote(key); // Escapes special characters in the key
                            personalizedTemplateBody = personalizedTemplateBody.replaceAll(escapedKey, mappingKeyVsMappingValues.get(key));
                        }
                    }
                    
                    if (salesforceImages != null) {
                        for(String src : salesforceImages.keySet()) {
                            String escapedSrc = Pattern.quote(src); // Escapes special characters in the src
                            personalizedTemplateBody = personalizedTemplateBody.replaceAll(escapedSrc, salesforceImages.get(src));
                        }
                    }

                    if(sendMethod == 'single'){
                        email.setToAddresses(new List<String>{contactEmail});
                        email.setSubject(temps[0].Subject__c);
                        email.setHtmlBody(personalizedTemplateBody); // Use personalized body
                        String replyToEmail = Label.EmailMessageEmailService;

                        if(replyToEmail != null){
                            email.setReplyTo(replyToEmail);
                        }

                        emails.add(email);
                    } else if(sendMethod == 'outlook') {
                        OutlookIntegrationController.EmailWrapper singleOutlookMail = new OutlookIntegrationController.EmailWrapper();

                        singleOutlookMail.toAddresses = new List<String>{contactEmail};
                        singleOutlookMail.subject = temps[0].Subject__c;
                        singleOutlookMail.body = personalizedTemplateBody; // Use personalized body

                        outlookMails.add(singleOutlookMail);
                    } else if(sendMethod == 'gmail'){
                        GmailIntegrationControllerV1.EmailWrapper singleGmail = new GmailIntegrationControllerV1.EmailWrapper();
                        singleGmail.toAddresses = new List<String>{contactEmail};
                        singleGmail.subject = temps[0].Subject__c;
                        singleGmail.body = personalizedTemplateBody; // Use personalized body

                        gmails.add(singleGmail);
                    }
                }
            }

            System.debug('Total emails to send: ' + (emails.size() + gmails.size() + outlookMails.size()));
            System.debug('Individual contacts: ' + (contactListRaw != null ? contactListRaw.size() : 0));
            System.debug('Broadcast group contacts: ' + (allContactIds.size() - (contactListRaw != null ? contactListRaw.size() : 0)));
            System.debug('Total unique recipients: ' + allContactIds.size());

            if (!emails.isEmpty()) {
                Messaging.sendEmail(emails);
                CreateActivityFromMail2.createCaseEmailMessage(contactEmailInfoMap);
            }else if(!gmails.isEmpty()){
                GmailIntegrationControllerV1.requestNewAccessToken(gmails,null,null,false);
            }else if(!outlookMails.isEmpty()){
                OutlookIntegrationController.requestNewAccessToken(outlookMails,null,null,false);
            }
        } catch (Exception e) {
            System.debug('Error in sendEmail: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            ErrorHandler.insertErrorData(e, 'MarketingListCmpController', 'sendEmail', 'Error while sending email.');
        }
    }

    @AuraEnabled
    public static String getListViewId() {
        try {
            String objectName = 'Contact';
            String developerName = 'EX_Contacts';
            // Validate inputs
            if (String.isBlank(objectName) || String.isBlank(developerName)) {
                throw new AuraHandledException('Object name and developer name must not be blank');
            }

            // Query ListView with sanitized inputs
            List<ListView> listViews = [SELECT Id, Name FROM ListView WHERE SobjectType = :objectName AND DeveloperName = :developerName WITH USER_MODE LIMIT 1];

            // Check if any ListView was found
            if (listViews.isEmpty()) {
                throw new AuraHandledException('No ListView found for object: ' + objectName + ' and developer name: ' + developerName);
            }

            return listViews[0].Id;
        } catch (Exception e) {
            
            ErrorHandler.insertErrorData(e, 'MarketingListCmpController', 'getListViewId', 'Error while fetching ListView.');
            return 'Error: ' + e.getMessage();
        }
    }

    @AuraEnabled
    public static String processBroadcastMessageWithObject(String requestJson) {
        try {
            // Deserialize JSON to a generic map
            Map<String, Object> request = (Map<String, Object>) JSON.deserializeUntyped(requestJson);
    
            // Extract fields
            String objectApiName = (String) request.get('objectApiName');
            String listViewName = (String) request.get('listViewName');
            List<Object> phoneNumbersRaw = (List<Object>) request.get('phoneNumbers');
            List<String> phoneNumbers = new List<String>();
            for (Object phoneNumber : phoneNumbersRaw) {
                phoneNumbers.add((String) phoneNumber);
            }
            String description = (String) request.get('description');
            String name = (String) request.get('name');
            Boolean isUpdate = request.containsKey('isUpdate') ? (Boolean) request.get('isUpdate') : false;
            String broadcastGroupId = (String) request.get('broadcastGroupId');
            String phoneField = (String) request.get('phoneField');
            String communicationType = (String) request.get('communicationType');
    
            // Basic validation
            if (String.isBlank(objectApiName) || 
                String.isBlank(description) || 
                String.isBlank(name) || 
                String.isBlank(listViewName) ||
                String.isBlank(phoneField) || 
                phoneNumbers.isEmpty()) {
                throw new AuraHandledException('All fields in the request are required, including the broadcast group name');
            }
    
            Broadcast_Group__c broadcastGroup;
    
            broadcastGroup = new Broadcast_Group__c();
            broadcastGroup.Name = name;
            broadcastGroup.Description__c = description;
            broadcastGroup.Object_Name__c = objectApiName;
            broadcastGroup.List_View__c = listViewName;
            broadcastGroup.Phone_Field__c = phoneField;
            broadcastGroup.Communication_Type__c = communicationType;

            Database.SaveResult insertResult = Database.insert(broadcastGroup, false, AccessLevel.USER_MODE);
            if (!insertResult.isSuccess()) {
                throw new AuraHandledException('Failed to create broadcast group.');
            }
    
            // Handle group members
            Map<String, Broadcast_Group_Member__c> existingMembersMap = new Map<String, Broadcast_Group_Member__c>();
            if (isUpdate) {
                for (Broadcast_Group_Member__c member : [SELECT Id, Phone_Number__c FROM Broadcast_Group_Member__c WHERE Broadcast_Group_ID__c = :broadcastGroup.Id WITH USER_MODE]) {
                    existingMembersMap.put(member.Phone_Number__c, member);
                }
            }
    
            List<Broadcast_Group_Member__c> newMembersToInsert = new List<Broadcast_Group_Member__c>();
            Set<String> receivedPhoneNumbers = new Set<String>(phoneNumbers);
            Set<String> existingPhoneNumbers = existingMembersMap.keySet();
    
            for (String phone : receivedPhoneNumbers) {
                if (String.isNotBlank(phone) && !existingPhoneNumbers.contains(phone)) {
                    newMembersToInsert.add(new Broadcast_Group_Member__c(
                        Broadcast_Group_ID__c = broadcastGroup.Id,
                        Phone_Number__c = phone
                    ));
                }
            }
    
            List<Broadcast_Group_Member__c> membersToDelete = new List<Broadcast_Group_Member__c>();
            for (String existingPhone : existingPhoneNumbers) {
                if (!receivedPhoneNumbers.contains(existingPhone)) {
                    membersToDelete.add(existingMembersMap.get(existingPhone));
                }
            }
    
            if (!newMembersToInsert.isEmpty()) {
                Database.SaveResult[] insertResults = Database.insert(newMembersToInsert, false, AccessLevel.USER_MODE);
                for (Database.SaveResult res : insertResults) {
                    if (!res.isSuccess()) {
                        throw new AuraHandledException('Error inserting some broadcast group members.');
                    }
                }
            }
    
            if (!membersToDelete.isEmpty()) {
                Database.DeleteResult[] deleteResults = Database.delete(membersToDelete, false, AccessLevel.USER_MODE);
                for (Database.DeleteResult res : deleteResults) {
                    if (!res.isSuccess()) {
                        throw new AuraHandledException('Error deleting some broadcast group members.');
                    }
                }
            }
    
            return broadcastGroup.Id;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'MarketingListCmpController', 'processBroadcastMessageWithObject', e.getMessage());
            return 'Error: ' + e.getMessage();
        }
    }
}