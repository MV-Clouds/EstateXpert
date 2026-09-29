/**
* Class Name : ListingManagerController
* Date : 03-06-2024
* Created By : Vyom Soni
* Last Modified Date : 29-09-2026
* Last Modified By : Vyom Soni
* @description : Controller for Listing Manager and Listing Manager Filters
*/

public with sharing class ListingManagerController {
    /**
    * Class Name : WrapperClass
    * @description : this wrapper list set listing and medias together.
    */
    public class WrapperClass{
        @AuraEnabled
        public List<MVEX__Listing__c> listings;  
        @AuraEnabled
        public Map<Id, String> medias;  
        @AuraEnabled
        public Integer pageSize;
        @AuraEnabled
        public List<Map<String, String>> selectedFields;       
    }

    /**
    * Class Name : FieldDetails
    * @description : this is a wrapper class to pass multiple values to the LWC component.
    */
    public virtual class FieldDetails {
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
    public virtual class PicklistValue {
        @AuraEnabled
        public String label { get; set; }
        @AuraEnabled
        public String value { get; set; }
    }

    /**
    * Method Name : getListingData
    * @description : for the retrieve the listing data.
    * @return List<MVEX__Listing__c>.
    */
    @AuraEnabled
    public static WrapperClass getListingData(){
        try {
            String listingFields = 'Id,MVEX__City__c,MVEX__Status__c,MVEX__Bathrooms__c,MVEX__Listing__c.MVEX__Property__c,MVEX__Country__c,MVEX__State__c,MVEX__Street__c,Name,MVEX__Sq_Ft__c,MVEX__Listing_Address__CountryCode__s,MVEX__Listing_Address__StateCode__s,MVEX__Listing_Address__City__s,MVEX__Listing_Address__PostalCode__s,MVEX__Listing_Address__Street__s,MVEX__Property_Type__c, MVEX__Property_Category__c';

            List<MVEX__Configuration_Settings__c> configs = [SELECT MVEX__Fields_Data__c, MVEX__Page_Size__c FROM MVEX__Configuration_Settings__c 
                                                                WHERE MVEX__Feature_Name__c = 'Listing_Manager_Fields' WITH USER_MODE LIMIT 1];

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

            Set<String> stateCountryApiNames = new Set<String>();

            Map<String, String> lowerToOriginalCase = new Map<String, String>();

            if (!configuredFields.isEmpty()) {
                List<String> fieldNames = new List<String>();

                Set<String> existingFields = new Set<String>();
                for (String field : listingFields.split(',')) {
                    existingFields.add(field.trim().toLowerCase());
                }

                for (Map<String, String> field : configuredFields) {
                    String fieldApiname = field.get('fieldApiname').trim();
                    String lowerApi    = fieldApiname.toLowerCase();

                    if (lowerApi.endsWith('__statecode__s') || lowerApi.endsWith('__state__s') || lowerApi.endsWith('__countrycode__s') || lowerApi.endsWith('__country__s')) {
                        stateCountryApiNames.add(lowerApi);
                        lowerToOriginalCase.put(lowerApi, fieldApiname);
                    }

                    if (!existingFields.contains(lowerApi)) {
                        fieldNames.add(fieldApiname);
                        existingFields.add(lowerApi);
                    }
                }

                if (!fieldNames.isEmpty()) {
                    listingFields += ', ' + String.join(fieldNames, ', ');
                }
            }

            String query = 'SELECT ' + listingFields + ' FROM MVEX__Listing__c';
            List<MVEX__Listing__c> listing = Database.query(query, AccessLevel.USER_MODE);

            Map<String, Map<String, String>> codeToLabelByField = new Map<String, Map<String, String>>();
            if (!stateCountryApiNames.isEmpty()) {
                Schema.DescribeSObjectResult objDescribe = MVEX__Listing__c.sObjectType.getDescribe();
                Map<String, Schema.SObjectField> fieldsMap = objDescribe.fields.getMap();

                for (String lowerApi : stateCountryApiNames) {
                    if (fieldsMap.containsKey(lowerApi)) {
                        Map<String, String> codeToLabel = new Map<String, String>();
                        for (Schema.PicklistEntry pe : fieldsMap.get(lowerApi).getDescribe().getPicklistValues()) {
                            codeToLabel.put(pe.getValue(), pe.getLabel());
                        }
                        codeToLabelByField.put(lowerApi, codeToLabel);
                    }
                }
            }

            Set<Id> propertyIds = new Set<Id>();     

            for(MVEX__Listing__c listingrec :listing) {
                Id propertyId = (Id)listingrec.get('MVEX__Property__c');
                if (propertyId != null) {
                    propertyIds.add(propertyId);
                }

                // Resolve state/country code → display label in-place on each record.
                for (String lowerApi : codeToLabelByField.keySet()) {
                    Object codeVal = listingrec.get(lowerApi);
                    if (codeVal != null) {
                        String resolvedLabel = codeToLabelByField.get(lowerApi).get(String.valueOf(codeVal));
                        if (resolvedLabel != null) {
                            // Use the original-case API name — SObject.put() is case-sensitive
                            listingrec.put(lowerToOriginalCase.get(lowerApi), resolvedLabel);
                        }
                    }
                }
            }

            List<MVEX__Property_File__c> medias = [SELECT Id, MVEX__BaseUrl__c, MVEX__Property__c FROM MVEX__Property_File__c WHERE MVEX__Property__c IN:propertyIds WITH USER_MODE LIMIT 50000 ];

            Map<Id, String> propertyMediaUrlsMap = new Map<Id, String>();
            for (MVEX__Property_File__c media : medias) {
                    propertyMediaUrlsMap.put(media.MVEX__Property__c,media.MVEX__BaseUrl__c);
            }
            WrapperClass wc = new WrapperClass();
            wc.listings = listing;
            wc.medias = propertyMediaUrlsMap;
            wc.pageSize = pageSize; // Include the pageSize in the WrapperClass
            wc.selectedFields = configuredFields; // Include the selected fields (APIName and Label) in the WrapperClass
         
            return wc;
            
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'ListingManagerController', 'getListingData', 'Error while getting listing data.');
            return null;
        }
    }

    /**
    * Method Name : getObjectFields
    * @description : get the fields by parent object name with conditional metadata query.
    * @param objectApiName String value.
    * @return List of Fields of all references of Listing or Contact.
    */
    @AuraEnabled
    public static List<FieldDetails> getObjectFields(String objectApiName) {
        try{
            List<FieldDetails> fieldDetailsList = new List<FieldDetails>();
    
            Set<String> blockedFields = new Set<String>();
            if (objectApiName == 'Contact' || objectApiName == 'MVEX__Inquiry__c') {
                List<MVEX__MarketingListFilterConfig__mdt> filterConfigs = [SELECT MVEX__BlockedFields__c FROM MVEX__MarketingListFilterConfig__mdt WITH USER_MODE LIMIT 1];
                if (!filterConfigs.isEmpty() && filterConfigs[0].MVEX__BlockedFields__c != null) {
                    blockedFields.addAll(filterConfigs[0].MVEX__BlockedFields__c.split(';'));
                }
            } else {
                List<MVEX__ListingManagerFilterConfig__mdt> filterConfigs = [SELECT MVEX__BlockedFields__c FROM MVEX__ListingManagerFilterConfig__mdt WITH USER_MODE LIMIT 1];
                if (!filterConfigs.isEmpty() && filterConfigs[0].MVEX__BlockedFields__c != null) {
                    blockedFields.addAll(filterConfigs[0].MVEX__BlockedFields__c.split(';'));
                }
            }

            Schema.DescribeSObjectResult objDescribe = Schema.getGlobalDescribe().get(objectApiName).getDescribe();
            Map<String, Schema.SObjectField> fieldsMap = objDescribe.fields.getMap();
            for (String fieldName : fieldsMap.keySet()) {
                if (blockedFields.contains(fieldName)) {
                    continue;
                }
                Schema.SObjectField field = fieldsMap.get(fieldName);
                Schema.DescribeFieldResult fieldDescribe = field.getDescribe();

                if (!fieldDescribe.isAccessible()) {
                    continue;
                }

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
    
                if (fieldDescribe.getType() == Schema.DisplayType.Picklist || fieldDescribe.getType() == Schema.DisplayType.MultiPicklist) {
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
            ErrorHandler.insertErrorData(e, 'ListingManagerController', 'getObjectFields', e.getMessage());
            return null;
        }
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
            String objectApiName = objectName;
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
            ErrorHandler.insertErrorData(e, 'ListingManagerController', 'getPicklistValues', e.getMessage());
            return null;
        }
    }

    /**
     * Method Name : getFilteredListings
     * @description : get the filtered listings.
     * @param filterConditions String of combined filter conditions.
     * @return List of MVEX__Listing__c records.
     */
    @AuraEnabled
    public static List<MVEX__Listing__c> getFilteredListings(String filterConditions) {
        try {
            String baseQuery = 'SELECT Id FROM MVEX__Listing__c';
            if (String.isNotBlank(filterConditions) && filterConditions != 'TRUE') {
                baseQuery += ' WHERE ' + filterConditions;
            }
            baseQuery += ' ORDER BY CreatedDate DESC';
            
            List<MVEX__Listing__c> listings = Database.query(baseQuery, AccessLevel.USER_MODE);
            return listings;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'ListingManagerController', 'getFilteredListings', e.getMessage());
            return new List<MVEX__Listing__c>();
        }
    }

    /**
    * Method Name : getStaticFields
    * @description : get the static fields from the custom object.
    * @return String of JSON data.
    */
    @AuraEnabled(cacheable=true)
    public static String getStaticFields(String objectApiName, String featureName) {
        try {
            MVEX__Configuration_Settings__c config = [SELECT MVEX__Fields_Data__c FROM MVEX__Configuration_Settings__c
                                                        WHERE MVEX__Feature_Name__c = :featureName LIMIT 1];

            return config.MVEX__Fields_Data__c;

        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'ListingManagerController', 'getStaticFields', e.getMessage());
            return null; 
        }
    }

    /**
    * Method Name : saveStaticFields
    * @description : save the static fields to the custom object.
    * @return void.
    */
    @AuraEnabled
    public static void saveStaticFields(String objectApiName, String featureName, String fieldsJson) {
        try {
            MVEX__Configuration_Settings__c config;

            List<MVEX__Configuration_Settings__c> existingConfigs = [SELECT Id FROM MVEX__Configuration_Settings__c
                                                                        WHERE MVEX__Feature_Name__c = :featureName LIMIT 1];

            if (!existingConfigs.isEmpty()) {
                config = existingConfigs[0];
            } else {
                config = new MVEX__Configuration_Settings__c();
                config.MVEX__Object_API_Name__c = objectApiName;
                config.MVEX__Feature_Name__c = featureName;
                config.Name = objectApiName + '_' + featureName;
            }

            config.MVEX__Fields_Data__c = fieldsJson;

            upsert config;

        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'ListingManagerController', 'saveStaticFields', e.getMessage());
        }
    }
}