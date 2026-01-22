/**
* Class Name : ListingManagerFilterController
* Test Class : Pending
* Created By : Vyom Soni
* Last Modified Date : 07-06-2024
* Last Modified By : Vyom Soni
* @description : Used in portalMappingComponent and portalMappingLandingPage LWC components
*/

public with sharing class ListingManagerFilterController {

    /**
    * Method Name : getListingFields
    * @description : get the fields by parent object name.
    * @param ObjectApIName String value.
    * @return List of Fields of all references of Listing.
    */
    @AuraEnabled
    public static List<FieldDetails> getListingFields(String objectApiName) {
        try{
            List<FieldDetails> fieldDetailsList = new List<FieldDetails>();
    
            ListingManagerFilterConfig__mdt filterConfig = [SELECT BlockedFields__c FROM ListingManagerFilterConfig__mdt WITH USER_MODE LIMIT 1];

            Set<String> blockedFields = new Set<String>();
            if (filterConfig != null && filterConfig.BlockedFields__c != null) {
                blockedFields.addAll(filterConfig.BlockedFields__c.split(';'));
            }

            Schema.DescribeSObjectResult objDescribe = Schema.getGlobalDescribe().get(objectApiName).getDescribe();
            Map<String, Schema.SObjectField> fieldsMap = objDescribe.fields.getMap();
            for (String fieldName : fieldsMap.keySet()) {
                if (blockedFields.contains(fieldName)) {
                    continue;
                }
                Schema.SObjectField field = fieldsMap.get(fieldName);
                Schema.DescribeFieldResult fieldDescribe = field.getDescribe();

                FieldDetails fieldDetails = new FieldDetails();
                fieldDetails.fieldName = fieldDescribe.getLabel();
                fieldDetails.fieldAPIName = fieldDescribe.getName();
                fieldDetails.fieldType = String.valueOf(fieldDescribe.getType());
    
                if (fieldDescribe.getType() == Schema.DisplayType.Reference) {
                    List<Schema.SObjectType> referenceTo = fieldDescribe.getReferenceTo();
                    if (!referenceTo.isEmpty()) {
                        fieldDetails.referenceObjectName = referenceTo[0].getDescribe().getName();
                    }
                }else{
                    fieldDetails.referenceObjectName = objectApiName;
                }
    
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
    
                fieldDetailsList.add(fieldDetails);
            }
    
            return fieldDetailsList;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'ListingManagerFilterController', 'getListingFields', e.getMessage());
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
            ErrorHandler.insertErrorData(e, 'ListingManagerFilterController', 'getPicklistValues', e.getMessage());
            return null;
        }
    }

    /**
     * Method Name : getFilteredListings
     * @description : get the filtered listings.
     * @param filterConditions String of combined filter conditions.
     * @return List of Listing__c records.
     */
    @AuraEnabled
    public static List<Listing__c> getFilteredListings(String filterConditions) {
        try {
            String baseQuery = 'SELECT Id FROM Listing__c';
            if (String.isNotBlank(filterConditions) && filterConditions != 'TRUE') {
                // Avoid double-escaping by ensuring the input is clean
                baseQuery += ' WHERE ' + filterConditions;
            }
            baseQuery += ' ORDER BY CreatedDate DESC';
            System.debug('baseQuery: ' + baseQuery);
            
            List<Listing__c> listings = Database.query(baseQuery, AccessLevel.USER_MODE);
            System.debug('Listings retrieved: ' + listings.size());
            return listings;
        } catch (Exception e) {
            System.debug('Error in getFilteredListings: ' + e.getMessage() + ' at line ' + e.getLineNumber());
            ErrorHandler.insertErrorData(e, 'ListingManagerFilterController', 'getFilteredListings', e.getMessage());
            return null;
        }
    }

    /**
    * Method Name : getStaticFields
    * @description : get the static fields from the custom metadata.
    * @return String of JSON data.
    */
    @AuraEnabled
    public static String getStaticFields() {
        try {
            ListingManagerFilterConfig__mdt filterConfig = [SELECT StaticFields__c FROM ListingManagerFilterConfig__mdt WITH USER_MODE LIMIT 1];
            return filterConfig.StaticFields__c;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'ListingManagerFilterController', 'getStaticFields', e.getMessage());
            return null;
        }
    }
}