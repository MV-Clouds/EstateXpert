/**
* Class Name : MarketingListFilterController
* Test Class : Pending
* Date : 23/06/2024
* Created By : Vyom Soni
* Last Modified Date : 08-07-2024
* Last Modified By : Vyom Soni
* @description : Used in MarektingListFilterCmp and MarketingListFilterAddCmp LWC components.
*/
public with sharing class MarketingListFilterController {
    /**
    * Method Name : getContactFields
    * @description : get the fields by parent object name.
    * @param ObjectApIName String value
    * @return List of Fields of all references of Contact.
    */
    @AuraEnabled
    public static List<FieldDetails> getContactFields(String objectApiName) {
        try{
            List<FieldDetails> fieldDetailsList = new List<FieldDetails>();

            MarketingListFilterConfig__mdt filterConfig = [SELECT BlockedFields__c FROM MarketingListFilterConfig__mdt WITH USER_MODE LIMIT 1];

            // Parse the blocked fields
            Set<String> blockedFields = new Set<String>();
            if (filterConfig != null && filterConfig.BlockedFields__c != null) {
                blockedFields.addAll(filterConfig.BlockedFields__c.split(';'));
            }

            // Get the Describe result for the given object
            Schema.DescribeSObjectResult objDescribe = Schema.getGlobalDescribe().get(objectApiName).getDescribe();

            // Get the fields map for the object
            Map<String, Schema.SObjectField> fieldsMap = objDescribe.fields.getMap();

            // Iterate through each field
            for (String fieldName : fieldsMap.keySet()) {
                if (blockedFields.contains(fieldName)) {
                    continue;
                }
                Schema.SObjectField field = fieldsMap.get(fieldName);
                Schema.DescribeFieldResult fieldDescribe = field.getDescribe();

                // Create a new FieldDetails object for each field
                FieldDetails fieldDetails = new FieldDetails();
                fieldDetails.fieldName = fieldDescribe.getLabel();
                fieldDetails.fieldAPIName = fieldDescribe.getName();
                fieldDetails.fieldType = String.valueOf(fieldDescribe.getType());

                // Check if the field is a reference field
                if (fieldDescribe.getType() == Schema.DisplayType.Reference) {
                    // Get the reference to the related objects
                    List<Schema.SObjectType> referenceTo = fieldDescribe.getReferenceTo();
                    if (!referenceTo.isEmpty()) {
                        fieldDetails.referenceObjectName = referenceTo[0].getDescribe().getName();
                    }
                }else{
                    fieldDetails.referenceObjectName = objectApiName;
                }

                // Check if the field is a picklist
                if (fieldDescribe.getType() == Schema.DisplayType.Picklist) {
                    List<PicklistValue> picklistValues = new List<PicklistValue>();
                    for (Schema.PicklistEntry picklistEntry : fieldDescribe.getPicklistValues()) {
                        PicklistValue picklistValue = new PicklistValue();
                        picklistValue.label = picklistEntry.getLabel();
                        picklistValue.value = picklistEntry.getValue();
                        picklistValues.add(picklistValue);
                    }
                    fieldDetails.picklistValues = picklistValues;
                }

                // Add the field details object to the list
                fieldDetailsList.add(fieldDetails);
            }

            return fieldDetailsList;
        }catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'MarketingListFilterController', 'getContactFields', e.getMessage());
            return null;
        }
    }

    /**
    * Class Name : FieldDetails
    * @description : this is a wrapper class to pass multiple values to the LWC component.
    */
    public class FieldDetails {
        @AuraEnabled
        public String fieldName { get; set; }
        @AuraEnabled
        public String fieldAPIName { get; set; }
        @AuraEnabled
        public String fieldType { get; set; }
        @AuraEnabled
        public String referenceObjectName { get; set; }
        @AuraEnabled
        public List<PicklistValue> picklistValues { get; set; }
    }

    /**
    * Class Name : PicklistValue
    * @description : this is a wrapper class to represent picklist values with label and value.
    */
    public class PicklistValue {
        @AuraEnabled
        public String label { get; set; }
        @AuraEnabled
        public String value { get; set; }
    }

    /**
    * Method Name : getPicklistValues
    * @description : get static fields picklist values.
    * @param apiName string field api name value.
    * @param objectName string object api name value.
    * @return List of picklist values.
    */
    @AuraEnabled
    public static List<Map<String, String>> getPicklistValues(String apiName ,String objectName) {
        try{
            String objectApiName =objectName ;
            String fieldApiName = apiName;
            List<Map<String, String>> picklistValues = new List<Map<String, String>>();
            
            Schema.SObjectType sObjectType = Schema.getGlobalDescribe().get(objectApiName);
            Schema.DescribeSObjectResult describeSObjectResult = sObjectType.getDescribe();
            Schema.DescribeFieldResult describeFieldResult = describeSObjectResult.fields.getMap().get(fieldApiName).getDescribe();
            
            List<Schema.PicklistEntry> picklistEntries = describeFieldResult.getPicklistValues();
            
            for (Schema.PicklistEntry entry : picklistEntries) {
                picklistValues.add(new Map<String, String>{'label' => entry.getLabel(), 'value' => entry.getValue()});
            }     
            return picklistValues;
        }catch(Exception e){
            ErrorHandler.insertErrorData(e, 'MarketingListFilterController', 'getPicklistValues', e.getMessage());
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

            // Build Contact query
            String contactQuery = 'SELECT ';
            List<String> contactFieldList = new List<String>(contactFields);
            if (!contactRelationships.isEmpty()) {
                for (String rel : contactRelationships) {
                    contactFieldList.add(rel + '.Id');
                }
            }
            contactQuery += String.join(contactFieldList, ', ');
            contactQuery += ' FROM Contact WHERE Contact_Type__c = \'Buyer\' and Contact_Type__c != NULL ORDER BY CreatedDate DESC LIMIT 1000';
            System.debug('Contact Query: ' + contactQuery);
            wrapper.contacts = Database.query(contactQuery, AccessLevel.USER_MODE);

            // Collect fields for Inquiry__c query
            Set<String> inquiryFields = new Set<String>{'Contact__c'};
            for (FilterCondition filter : inquiryFilters) {
                inquiryFields.add(filter.fieldPath);
            }

            // Build Inquiry__c query
            String inquiryQuery = 'SELECT ' + String.join(new List<String>(inquiryFields), ', ') + 
                                 ' FROM Inquiry__c WHERE Contact__c != NULL ORDER BY CreatedDate DESC LIMIT 10000';
            System.debug('Inquiry Query: ' + inquiryQuery);
            wrapper.inquiries = Database.query(inquiryQuery, AccessLevel.USER_MODE);

            return wrapper;
        } catch (Exception e) {
            System.debug('Error in getFilteredContacts: ' + e.getMessage() + ' at line ' + e.getLineNumber());
            ErrorHandler.insertErrorData(e, 'MarketingListFilterController', 'getFilteredContacts', e.getMessage());
            throw new AuraHandledException('Error retrieving filtered contacts: ' + e.getMessage());
        }
    }

    /**
     * Wrapper class to return data to LWC
     */
    public class FilterDataWrapper {
        @AuraEnabled
        public List<Contact> contacts { get; set; }
        @AuraEnabled
        public List<Inquiry__c> inquiries { get; set; }
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
    public class FilterCondition {
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
    * Method Name : getStaticFields
    * @description : get the static fields from the custom metadata.
    * @return String of JSON data.
    */
    @AuraEnabled
    public static String getStaticFields() {
        try{
            MarketingListFilterConfig__mdt filterConfig = [SELECT StaticFields__c FROM MarketingListFilterConfig__mdt WITH USER_MODE LIMIT 1];
            return filterConfig.StaticFields__c;
        }catch(Exception e){
            ErrorHandler.insertErrorData(e, 'MarketingListFilterController', 'getStaticFields', e.getMessage());
            return null;
        }
    }
}