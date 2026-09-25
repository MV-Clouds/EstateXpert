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
            Integer pageSize = getPageSizeFromConfig();
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
    * Method Name : getConfiguredFields
    * @description : Retrieves the configured fields (API names and labels) from custom metadata.
    * @return List<Map<String, String>>.
    */
    private static List<Map<String, String>> getConfiguredFields() {
        try {
            // Query Custom Object instead of Metadata
            List<MVEX__Configuration_Settings__c> configs = [SELECT MVEX__Fields_Data__c  FROM MVEX__Configuration_Settings__c 
                                                            WHERE MVEX__Feature_Name__c = 'Marketing_List_Fields' WITH USER_MODE LIMIT 1];
            
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
            List<MVEX__Configuration_Settings__c> configs = [SELECT MVEX__Page_Size__c FROM MVEX__Configuration_Settings__c 
                                                            WHERE MVEX__Feature_Name__c = 'Marketing_List_Fields' WITH USER_MODE LIMIT 1];
        
            if (!configs.isEmpty()) {
                MVEX__Configuration_Settings__c config = configs[0];
                return config.MVEX__Page_Size__c != null ? Integer.valueOf(config.MVEX__Page_Size__c) : 30; // Default to 30 if not set
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'MarketingListCmpController', 'getPageSizeFromConfig', 'Error while getting page size from config.');
        }
        return 30;
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