/**
* Class Name : MarketingListCmpController
* Test Class : MarketingListCmpControllerTest
* Date : 21/06/2024
* Created By : Vyom Soni
* Last Modified Date : 29-09-2026
* Last Modified By : Vyom Soni
* @description : Controller for Marketing List and Marketing List Filters
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
     * Wrapper class to return data to LWC
     */
    public virtual class FilterDataWrapper {
        @AuraEnabled
        public List<Contact> contacts { get; set; }
        @AuraEnabled
        public List<MVEX__Inquiry__c> inquiries { get; set; }
        @AuraEnabled
        public List<FilterCondition> contactFilters { get; set; }
        @AuraEnabled
        public List<FilterCondition> inquiryFilters { get; set; }
        @AuraEnabled
        public String customLogic { get; set; }
    }

    /**
     * Inner class to represent a filter condition
     */
    public virtual class FilterCondition {
        @AuraEnabled
        public String fieldPath { get; set; }
        @AuraEnabled
        public String operator { get; set; }
        @AuraEnabled
        public List<String> values { get; set; }
        @AuraEnabled
        public Boolean isNot { get; set; }
        @AuraEnabled
        public String type { get; set; }
        @AuraEnabled
        public Integer index { get; set; }
    }

   /**
   * Method Name : getContactData
   * @description : for the retrieve the contact data.
   * @return List<Contact>.
   */
   @AuraEnabled
   public static WrapperClass getContactData(){
       try {
            List<Map<String, String>> configuredFields = new List<Map<String, String>>();
            Integer pageSize = 30;

            List<MVEX__Configuration_Settings__c> configs = [SELECT MVEX__Fields_Data__c, MVEX__Page_Size__c FROM MVEX__Configuration_Settings__c 
                                                             WHERE MVEX__Feature_Name__c = 'Marketing_List_Fields' WITH USER_MODE LIMIT 1];

            if (!configs.isEmpty()) {
                MVEX__Configuration_Settings__c config = configs[0];
                String fieldsDataJson = config.MVEX__Fields_Data__c;
                if (String.isNotBlank(fieldsDataJson)) {
                    configuredFields = (List<Map<String, String>>) JSON.deserialize(fieldsDataJson, List<Map<String, String>>.class);
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
     * Method Name: getFilteredContacts
     * @description: Get filtered contacts based on the filter conditions and custom logic.
     * @param filterData JSON string containing contactFilters, inquiryFilters, and customLogic.
     * @return Wrapper containing Contact and Inquiry records with filter metadata.
     */
    @AuraEnabled
    public static FilterDataWrapper getFilteredContacts(String filterData) {
        try {
            // Parse filter data
            Map<String, Object> filterDataMap = (Map<String, Object>) JSON.deserializeUntyped(filterData);
            List<Object> contactFiltersRaw = (List<Object>) filterDataMap.get('contactFilters');
            List<Object> inquiryFiltersRaw = (List<Object>) filterDataMap.get('inquiryFilters');
            String customLogic = (String) filterDataMap.get('customLogic');

            // Convert raw filters to typed FilterCondition list
            List<FilterCondition> contactFilters = new List<FilterCondition>();
            if (contactFiltersRaw != null) {
                for (Object filterObj : contactFiltersRaw) {
                    contactFilters.add((FilterCondition) JSON.deserialize(JSON.serialize(filterObj), FilterCondition.class));
                }
            }
            List<FilterCondition> inquiryFilters = new List<FilterCondition>();
            if (inquiryFiltersRaw != null) {
                for (Object filterObj : inquiryFiltersRaw) {
                    inquiryFilters.add((FilterCondition) JSON.deserialize(JSON.serialize(filterObj), FilterCondition.class));
                }
            }

            // Initialize wrapper to return
            FilterDataWrapper wrapper = new FilterDataWrapper();
            wrapper.contactFilters = contactFilters;
            wrapper.inquiryFilters = inquiryFilters;
            wrapper.customLogic = customLogic;

            // Collect fields for Contact query
            Set<String> contactFields = new Set<String>{'Id', 'FirstName', 'LastName', 'Email'};
            Set<String> contactRelationships = new Set<String>();
            for (FilterCondition filter : contactFilters) {
                String fieldPath = filter.fieldPath;
                if (fieldPath.contains('.')) {
                    String relationship = fieldPath.substringBefore('.');
                    String field = fieldPath.substringAfter('.');
                    contactFields.add(field);
                    contactRelationships.add(relationship);
                } else {
                    contactFields.add(fieldPath);
                }
            }

            // Check field accessibility for Contact
            Map<String, Schema.SObjectField> contactFieldsMap = Schema.SObjectType.Contact.fields.getMap();
            Set<String> validContactFields = new Set<String>();
            for (String fieldName : contactFields) {
                if (fieldName == 'Id' || (contactFieldsMap.containsKey(fieldName) && contactFieldsMap.get(fieldName).getDescribe().isAccessible())) {
                    validContactFields.add(fieldName);
                }
            }
            contactFields = validContactFields;

            // Build Contact query
            String contactQuery = 'SELECT ';
            List<String> contactFieldList = new List<String>(contactFields);
            if (!contactRelationships.isEmpty()) {
                for (String rel : contactRelationships) {
                    contactFieldList.add(rel + '.Id');
                }
            }
            contactQuery += String.join(contactFieldList, ', ');
            contactQuery += ' FROM Contact ORDER BY CreatedDate DESC LIMIT 1000';
            wrapper.contacts = Database.query(contactQuery, AccessLevel.USER_MODE);

            // Collect fields for MVEX__Inquiry__c query
            Set<String> inquiryFields = new Set<String>{'MVEX__Contact__c'};
            for (FilterCondition filter : inquiryFilters) {
                inquiryFields.add(filter.fieldPath);
            }

            // Check field accessibility for MVEX__Inquiry__c
            Map<String, Schema.SObjectField> inquiryFieldsMap = Schema.SObjectType.MVEX__Inquiry__c.fields.getMap();
            Set<String> validInquiryFields = new Set<String>();
            for (String fieldName : inquiryFields) {
                if (fieldName == 'Id' || fieldName == 'MVEX__Contact__c' || (inquiryFieldsMap.containsKey(fieldName) && inquiryFieldsMap.get(fieldName).getDescribe().isAccessible())) {
                    validInquiryFields.add(fieldName);
                }
            }
            inquiryFields = validInquiryFields;

            // Build MVEX__Inquiry__c query
            String inquiryQuery = 'SELECT ' + String.join(new List<String>(inquiryFields), ', ') + 
                                 ' FROM MVEX__Inquiry__c WHERE MVEX__Contact__c != NULL ORDER BY CreatedDate DESC LIMIT 10000';
            wrapper.inquiries = Database.query(inquiryQuery, AccessLevel.USER_MODE);

            return wrapper;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'MarketingListCmpController', 'getFilteredContacts', e.getMessage());
            return null;
        }
    }
}