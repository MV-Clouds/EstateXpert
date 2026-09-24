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
            List<MVEX__Configuration_Settings__c> configs = [SELECT MVEX__Fields_Data__c, MVEX__Page_Size__c FROM MVEX__Configuration_Settings__c 
                                                                WHERE MVEX__Feature_Name__c = 'Marketing_List_Fields' WITH USER_MODE LIMIT 1];

            List<Map<String, String>> configuredFields = new List<Map<String, String>>();
            Integer pageSize = 30;

            if (!configs.isEmpty()) {
                MVEX__Configuration_Settings__c config = configs[0];
                if (String.isNotBlank(config.MVEX__Fields_Data__c)) {
                    configuredFields = (List<Map<String, String>>)JSON.deserialize(config.MVEX__Fields_Data__c, List<Map<String, String>>.class);
                }
                if (config.MVEX__Page_Size__c != null) {
                    pageSize = Integer.valueOf(config.MVEX__Page_Size__c);
                }
            }

            Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Contact.fields.getMap();
            List<String> allFields = new List<String>();
            
            for (String fieldName : fieldMap.keySet()) {
                allFields.add(fieldName);
            }

            MVEX__MarketingListFilterConfig__mdt filterConfig = [SELECT MVEX__BlockedFields__c FROM MVEX__MarketingListFilterConfig__mdt WITH USER_MODE LIMIT 1];

            Set<String> blockedFields = new Set<String>();
            if (filterConfig != null && filterConfig.MVEX__BlockedFields__c != null) {
                blockedFields.addAll(filterConfig.MVEX__BlockedFields__c.split(';'));
            }
            List<String> filteredFields = new List<String>();

            for (String fieldName : allFields) {
                if (!blockedFields.contains(fieldName)) {
                    Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fieldName).getDescribe();
                    if (fieldDescribe.isAccessible()) {
                        filteredFields.add(fieldName);
                    }
                }
            }

            Set<String> queryFieldNames = new Set<String>();
            for(String f : filteredFields) {
                queryFieldNames.add(f.toLowerCase());
            }

            for (Map<String, String> field : configuredFields) {
                String fieldApiname = field.get('fieldApiname');
                if (String.isNotBlank(fieldApiname) && !queryFieldNames.contains(fieldApiname.toLowerCase())) {
                    filteredFields.add(fieldApiname);
                    queryFieldNames.add(fieldApiname.toLowerCase());
                }
            }

            String contactFields = String.join(filteredFields, ', ');
            String queryFields = String.escapeSingleQuotes(contactFields);
            String query = 'SELECT ' + queryFields + ' FROM Contact LIMIT 50000';

            List<Contact> contacts = Database.query(query, AccessLevel.USER_MODE);

            WrapperClass wc = new WrapperClass();
            wc.contacts = contacts; 
            wc.pageSize = pageSize;
            wc.selectedFields = configuredFields;
        
           return wc;
       } catch (Exception e) {
           ErrorHandler.insertErrorData(e, 'MarketingListCmpController', 'getContactData', 'Error while getting contact data.');
           return null;
       }
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

            String originalTemplateBody = ''; // Store original template body

            List<MVEX__Template__c> temp = [SELECT Id, MVEX__Template_Name__c,
                                        (SELECT Id, MVEX__Template_Value_Simple__c,MVEX__Value_Type__c FROM MVEX__Template_Data__r WHERE MVEX__Value_Type__c = 'Body Value' ORDER BY MVEX__Order_No_Simple__c ASC),
                                        (SELECT Id, MVEX__Page_Margin__c, MVEX__Page_Orientation__c, MVEX__Page_Size__c, MVEX__Unit_of_Page_Configs__c, MVEX__Show_Header__c, MVEX__Show_Footer__c, MVEX__Header_margin_top__c, MVEX__Footer_margin_bottom__c FROM MVEX__Template_Pages__r ORDER BY MVEX__Page_Number__c ASC)
                                        FROM MVEX__Template__c WHERE Id =: templateId WITH USER_MODE LIMIT 1 ];

            if(temp.size() > 0){
                for(MVEX__Template_Data__c fieldData : temp[0].MVEX__Template_Data__r){
                    String value = fieldData.MVEX__Template_Value_Simple__c != null ? fieldData.MVEX__Template_Value_Simple__c : '';
                    if(fieldData.MVEX__Value_Type__c == 'Body Value'){
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
                List<MVEX__Broadcast_Group_Member__c> groupMembers = [
                    SELECT MVEX__Contact_Id__c, MVEX__Contact_Id__r.Name, MVEX__Contact_Id__r.Email
                    FROM MVEX__Broadcast_Group_Member__c 
                    WHERE MVEX__Broadcast_Group_ID__c IN :broadcastGroupIds
                    WITH USER_MODE
                ];
                
                for (MVEX__Broadcast_Group_Member__c member : groupMembers) {
                    if (objectName == 'Contact' && member.MVEX__Contact_Id__c != null) {
                        allContactIds.add(member.MVEX__Contact_Id__c);
                    }
                }
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

            List<MVEX__Template__c> temps = [SELECT Id, Name,MVEX__Label__c,MVEX__Object_Name__c, MVEX__Object_API_Name__c,MVEX__Template_Body__c,MVEX__Template_Type__c, MVEX__Template_Name__c, MVEX__Template_pattern__c, MVEX__Template_Status__c, MVEX__Description__c, CreatedDate, LastModifiedDate,MVEX__Subject__c,
                                        (SELECT Id, Name, MVEX__Template_Value_Simple__c FROM MVEX__Template_Data__r WHERE MVEX__Value_Type__c = 'Extracted Mapping Keys' ORDER BY MVEX__Order_No_Simple__c ASC)
                                        FROM MVEX__Template__c  WHERE Id =:templateId WITH USER_MODE];
            String extractedKeyString = '';

            // get extracted Keys stored in field...
            for(MVEX__Template_Data__c fieldData : temps[0].MVEX__Template_Data__r){
                extractedKeyString +=  fieldData.MVEX__Template_Value_Simple__c;
            }

            extractedKeyString = extractedKeyString != '' ? extractedKeyString : 'null';
            String sourceObjectAPI = temps[0].MVEX__Object_API_Name__c;
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
                        email.setSubject(temps[0].MVEX__Subject__c);
                        email.setHtmlBody(personalizedTemplateBody); // Use personalized body
                        String replyToEmail = 'replyemailservice@2399seg7dczkd2wdrur97lyz9f5kxoq6rsi3uyqam30un540ms.dm-9p5p6uac.ind136.apex.salesforce.com';

                        if(replyToEmail != null){
                            email.setReplyTo(replyToEmail);
                        }

                        emails.add(email);
                    } else if(sendMethod == 'gmail'){
                        GmailIntegrationControllerV1.EmailWrapper singleGmail = new GmailIntegrationControllerV1.EmailWrapper();
                        singleGmail.toAddresses = new List<String>{contactEmail};
                        singleGmail.subject = temps[0].MVEX__Subject__c;
                        singleGmail.body = personalizedTemplateBody; // Use personalized body

                        gmails.add(singleGmail);
                    }
                }
            }

            if (!emails.isEmpty()) {
                Messaging.sendEmail(emails);
                CreateActivityRecordsFromMail.createCaseEmailMessage(contactEmailInfoMap);
            } else if(!gmails.isEmpty()){
                GmailIntegrationControllerV1.requestNewAccessToken(gmails,null,null,false);
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'MarketingListCmpController', 'sendEmail', 'Error while sending email.');
        }
    }

    @AuraEnabled
    public static String getListViewId() {
        try {
            String objectName = 'Contact';
            String developerName = 'EX_Contacts';

            // Query ListView with sanitized inputs
            List<ListView> listViews = [SELECT Id, Name FROM ListView WHERE SobjectType = :objectName AND DeveloperName = :developerName WITH USER_MODE LIMIT 1];

            // Check if any ListView was found
            if (listViews.isEmpty()) {
                ErrorHandler.insertErrorData(null, 'MarketingListCmpController', 'getListViewId', 'No ListView found for object: ' + objectName + ' and developer name: ' + developerName + ' at line 344.');
                return 'Error: No ListView found for the specified object and developer name.';
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
    
            MVEX__Broadcast_Group__c broadcastGroup;
    
            broadcastGroup = new MVEX__Broadcast_Group__c();
            broadcastGroup.Name = name;
            broadcastGroup.MVEX__Description__c = description;
            broadcastGroup.MVEX__Object_Name__c = objectApiName;
            broadcastGroup.MVEX__List_View__c = listViewName;
            broadcastGroup.MVEX__Phone_Field__c = phoneField;
            broadcastGroup.MVEX__Communication_Type__c = communicationType;

            Database.SaveResult insertResult = Database.insert(broadcastGroup, false, AccessLevel.USER_MODE);
            if (!insertResult.isSuccess()) {
                ErrorHandler.insertErrorData(null, 'MarketingListCmpController', 'processBroadcastMessageWithObject', 'Failed to create broadcast group and error at line 388.');
                return 'Failed to create broadcast group.';
            }
    
            // Handle group members
            Map<String, MVEX__Broadcast_Group_Member__c> existingMembersMap = new Map<String, MVEX__Broadcast_Group_Member__c>();
            if (isUpdate) {
                for (MVEX__Broadcast_Group_Member__c member : [SELECT Id, MVEX__Phone_Number__c FROM MVEX__Broadcast_Group_Member__c WHERE MVEX__Broadcast_Group_ID__c = :broadcastGroup.Id WITH USER_MODE]) {
                    existingMembersMap.put(member.MVEX__Phone_Number__c, member);
                }
            }
    
            List<MVEX__Broadcast_Group_Member__c> newMembersToInsert = new List<MVEX__Broadcast_Group_Member__c>();
            Set<String> receivedPhoneNumbers = new Set<String>(phoneNumbers);
            Set<String> existingPhoneNumbers = existingMembersMap.keySet();
    
            for (String phone : receivedPhoneNumbers) {
                if (String.isNotBlank(phone) && !existingPhoneNumbers.contains(phone)) {
                    newMembersToInsert.add(new MVEX__Broadcast_Group_Member__c(
                        MVEX__Broadcast_Group_ID__c = broadcastGroup.Id,
                        MVEX__Phone_Number__c = phone
                    ));
                }
            }
    
            List<MVEX__Broadcast_Group_Member__c> membersToDelete = new List<MVEX__Broadcast_Group_Member__c>();
            for (String existingPhone : existingPhoneNumbers) {
                if (!receivedPhoneNumbers.contains(existingPhone)) {
                    membersToDelete.add(existingMembersMap.get(existingPhone));
                }
            }
    
            if (!newMembersToInsert.isEmpty()) {
                Database.SaveResult[] insertResults = Database.insert(newMembersToInsert, false, AccessLevel.USER_MODE);
            }
    
            if (!membersToDelete.isEmpty()) {
                Database.DeleteResult[] deleteResults = Database.delete(membersToDelete, false, AccessLevel.USER_MODE);
            }
    
            return broadcastGroup.Id;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'MarketingListCmpController', 'processBroadcastMessageWithObject', e.getMessage());
            return 'Error: ' + e.getMessage();
        }
    }
}