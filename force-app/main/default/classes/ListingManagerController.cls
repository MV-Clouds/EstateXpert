/**
* Class Name : ListingManagerController
* Date : 03-06-2024
* Created By : Vyom Soni
* Last Modified Date : 19-06-2024
* Last Modified By : Vyom Soni
* @description : Used in the ListingManager lwc component
*/

public with sharing class ListingManagerController {
    /**
    * Class Name : WrapperClass
    * @description : this wrapper list set listing and medias together.
    */
    public class WrapperClass{
        @AuraEnabled
        public List<Listing__c> listings;  
        @AuraEnabled
        public Map<Id, String> medias;  
        @AuraEnabled
        public Integer pageSize;
        @AuraEnabled
        public List<Map<String, String>> selectedFields;       
    }
    /**
    * Method Name : getListingData
    * @description : for the retrieve the listing data.
    * @return List<Listing__c>.
    */
    @AuraEnabled
    public static WrapperClass getListingData(){
        if (!Schema.sObjectType.Listing__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to access Listing records.');
        }
        try {
            String listingFields = 'Id,MVEX__City__c,MVEX__Status__c,MVEX__Bathrooms__c,MVEX__Listing__c.MVEX__Property__c,MVEX__Country__c,MVEX__State__c,MVEX__Street__c,Name,MVEX__Sq_Ft__c,MVEX__Listing_Address__CountryCode__s,MVEX__Listing_Address__StateCode__s,MVEX__Listing_Address__City__s,MVEX__Listing_Address__PostalCode__s,MVEX__Listing_Address__Street__s';
            List<Map<String, String>> configuredFields = getConfiguredFields(); // Method to get selected fields from the config

            if (configuredFields == null) {
                configuredFields = new List<Map<String, String>>();
            }

            if (!configuredFields.isEmpty()) {
                List<String> fieldNames = new List<String>();
                
                // Convert listingFields to a Set for easier comparison and remove extra spaces
                Set<String> existingFields = new Set<String>();
                for (String field : listingFields.split(',')) {
                    existingFields.add(field.trim());
                }

                // Add fields from configuredFields if they are not already in listingFields
                for (Map<String, String> field : configuredFields) {
                    String fieldApiname = field.get('fieldApiname').trim();
                    if (!existingFields.contains(fieldApiname)) {
                        fieldNames.add(fieldApiname);
                    }
                }
                
                // If there are new fields to add, append them to listingFields
                if (!fieldNames.isEmpty()) {
                    listingFields += ', ' + String.join(fieldNames, ', ');
                }
            }

            // Fetch pageSize from the custom metadata
            Integer pageSize = getPageSizeFromConfig(); 

            String query = 'SELECT ' + listingFields + ' FROM MVEX__Listing__c';
            // Fetch the listings with related records
            List<Listing__c> listing = Database.query(query, AccessLevel.USER_MODE);
            Set<Id> propertyIds = new Set<Id>();     

            for(Listing__c listingrec :listing) {
                Id propertyId = (Id)listingrec.get('MVEX__Property__c');
                if (propertyId != null) {
                    propertyIds.add(propertyId);
                }
            }

            List<Property_File__c> medias = [SELECT Id, BaseUrl__c, Property__c FROM Property_File__c WHERE Property__c IN:propertyIds WITH USER_MODE LIMIT 50000 ];

            Map<Id, String> propertyMediaUrlsMap = new Map<Id, String>();
            for (Property_File__c media : medias) {
                    propertyMediaUrlsMap.put(media.Property__c,media.BaseUrl__c);
            }
            WrapperClass wc = new WrapperClass();
            wc.listings = listing;
            wc.medias = propertyMediaUrlsMap;
            wc.pageSize = pageSize; // Include the pageSize in the WrapperClass
            wc.selectedFields = configuredFields; // Include the selected fields (APIName and Label) in the WrapperClass
         
            return wc;
            
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'ListingManagerController', 'getListingData', 'Error while getting listing data.');
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
            List<recordManagerConfig__mdt> configs = [SELECT FieldsData__c FROM recordManagerConfig__mdt WITH USER_MODE LIMIT 1];
            
            List<Map<String, String>> fields = new List<Map<String, String>>();
            
            if (!configs.isEmpty()) {
                recordManagerConfig__mdt config = configs[0];
                String fieldsDataJson = config.FieldsData__c;
                
                if (String.isNotBlank(fieldsDataJson)) {
                    // Deserialize JSON to List<Map<String, String>>
                    fields = (List<Map<String, String>>)JSON.deserialize(fieldsDataJson, List<Map<String, String>>.class);
                }
            }
            
            return fields;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'ListingManagerController', 'getConfiguredFields', 'Error while getting configured fields.');
            return null;
        }

    }

    // Helper method to get pageSize from metadata
    private static Integer getPageSizeFromConfig() {

        try {
            List<recordManagerConfig__mdt> configs = [SELECT PageSize__c FROM recordManagerConfig__mdt WITH USER_MODE LIMIT 1];

            if (!configs.isEmpty()) {
                recordManagerConfig__mdt config = configs[0];
                return config.PageSize__c != null ? Integer.valueOf(config.PageSize__c) : 30; // Default to 30 if not set
            }
            
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'ListingManagerController', 'getPageSizeFromConfig', 'Error while getting page size from config.');
        }
        
        return 30; // Default to 30 if no metadata found
    }
}