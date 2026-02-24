public with sharing class ListingTriggerHandler {
    
    List<Listing__c> recordNewList = new List<Listing__c>();
    List<Listing__c> recordOldList = new List<Listing__c>();
    Map<Id, Listing__c> recordNewMap = new Map<Id, Listing__c>();
    Map<Id, Listing__c> recordOldMap = new Map<Id, Listing__c>();
    Boolean isInsert ;
    Boolean isUpdate ;
    Boolean isDelete = false;
    Boolean isUndelete = false;
    private static final string CLASS_NAME = 'ListingTriggerHandler';
    public static Boolean isFirstTime = true;

    // Added for Test Coverage to bypass metadata query
    @TestVisible
    private static Mapping_Metadata__mdt mockMetadata;

    public ListingTriggerHandler(List<Listing__c> newList, List<Listing__c> oldList, Map<Id, Listing__c> newMap, Map<Id, Listing__c> oldMap, Boolean isInsert, Boolean isUpdate, Boolean isDelete, Boolean isUndelete) {
        this.recordNewList = newList;
        this.recordOldList = oldList;
        this.recordNewMap = newMap;
        this.recordOldMap = oldMap;
        this.isInsert = isInsert;
        this.isUpdate = isUpdate;
        this.isDelete = isDelete;
        this.isUndelete = isUndelete;
    }

    public void afterInsertEvent() {
        handleListingAfterInsert();
    }

    public void afterUpdateEvent(){
        handleListingAfterUpdate();
    }
    
    //Main Methods
    public void handleListingAfterInsert() {
        try {
            //Get mapping from the metadata record
            Mapping_Metadata__mdt metaData;
            if(Test.isRunningTest() && mockMetadata != null) {
                metaData = mockMetadata;
            } else {
                metaData = [SELECT Mapping_String__c, Automatic_Sync__c, BlockedFields__c FROM Mapping_Metadata__mdt WITH USER_MODE LIMIT 1];
            }
            
            Map<String, String> fieldMappings = new Map<String, String>();
            
            if(metaData.Mapping_String__c != null){
                String[] mappingPairs = metaData.Mapping_String__c.split(';');
                for (String pair : mappingPairs) {
                    String[] parts = pair.split(':');
                    if (parts.size() == 2) {
                        fieldMappings.put(parts[0], parts[1]);
                    }
                }
            }

            
            //Get All fields and exclude the audit and unwritable fields
            Map<String, Schema.SObjectField> listingFieldsMap = Schema.SObjectType.Listing__c.fields.getMap();
            Set<String> listingFields = listingFieldsMap.keySet();
            
            Map<String, Schema.SObjectField> propertyFieldsMap = Schema.SObjectType.Property__c.fields.getMap();
            Set<String> propertyFields = propertyFieldsMap.keySet();

            //When Automatic sync is on
            if(metaData.Automatic_Sync__c != null && metaData.Automatic_Sync__c == true){
                
                Set<String> auditFields = new Set<String>(metaData.BlockedFields__c.split(';'));
                for (String auditField : auditFields) {
                    if (listingFields.contains(auditField)) {
                        listingFields.remove(auditField);
                    }
                    if (propertyFields.contains(auditField)) {
                        propertyFields.remove(auditField);
                    }
                }
                
                Set<String> unwritableFieldsForListing = new Set<String>();
                for (String fieldName : listingFields) {
                    if (!listingFieldsMap.get(fieldName).getDescribe().isUpdateable()) {
                        unwritableFieldsForListing.add(fieldName);
                    }
                }
                listingFields.removeAll(unwritableFieldsForListing);
                
                Set<String> unwritableFieldsForProperty = new Set<String>();
                for (String fieldName : propertyFields) {
                    if (!propertyFieldsMap.get(fieldName).getDescribe().isUpdateable()) {
                        unwritableFieldsForProperty.add(fieldName);
                    }
                }
                propertyFields.removeAll(unwritableFieldsForProperty);
                
                Set<String> matchingFields = new Set<String>(listingFields);
                matchingFields.retainAll(propertyFields);

                List<Property__c> newProperties = new List<Property__c>();

                Map<Id, Property__c> existingPropertiesMap = new Map<Id, Property__c>();

                for (Listing__c newListing : recordNewList) {
                    if (newListing.Property__c != null) {
                        existingPropertiesMap.put(newListing.Id, new Property__c(Id = newListing.Property__c));
                    }
                }

                Map<String, Property__c> matchingPropertiesMap = new Map<String, Property__c>();
                
                for (Property__c existingProperty : [SELECT Id, Name, Address__c, Bedrooms__c, Bathrooms__c FROM Property__c WITH USER_MODE LIMIT 5000]) {
                    String propertyKey = existingProperty.Name + '|' + existingProperty.Address__c + '|' + existingProperty.Bedrooms__c + '|' + existingProperty.Bathrooms__c;
                    matchingPropertiesMap.put(propertyKey, existingProperty);
                }
                
                for (Listing__c newListing : recordNewList) {
                    if (newListing.Property__c == null) {
                        String propertyKey = newListing.Name + '|' + newListing.Address__c + '|' + newListing.Bedrooms__c	 + '|' + newListing.Bathrooms__c;
                        if (matchingPropertiesMap.containsKey(propertyKey)) {
                            Property__c existingProperty = matchingPropertiesMap.get(propertyKey);
                            for (String field : matchingFields) {
                                if (field != 'Id' && field != 'Name' && field != 'RecordTypeId' && listingFieldsMap.get(field).getDescribe().getType() == propertyFieldsMap.get(field).getDescribe().getType()) {
                                    existingProperty.put(field, newListing.get(field));
                                }
                            }
                            newProperties.add(existingProperty);
                        } else {
                            // Create a new property
                            Property__c property = new Property__c();
                            for (String field : matchingFields) {
                                if (field != 'RecordTypeId' && listingFieldsMap.get(field).getDescribe().getType() == propertyFieldsMap.get(field).getDescribe().getType()) {
                                    property.put(field, newListing.get(field));
                                }
                            }
                            newProperties.add(property);
                        }
                    } else {
                        Property__c property = existingPropertiesMap.get(newListing.Id);
                        for (String field : matchingFields) {
                            if (field != 'RecordTypeId' && field != 'Id' && field != 'Name' && listingFieldsMap.get(field).getDescribe().getType() == propertyFieldsMap.get(field).getDescribe().getType()) {
                                property.put(field, newListing.get(field));
                            }
                        }
                        newProperties.add(property);
                    }
                }

                
                if (!newProperties.isEmpty()) {
                    if(Schema.sObjectType.Property__c.isCreateable() && Schema.sObjectType.Property__c.isUpdateable()){
                        upsert as user newProperties;
                    }

                    List<Listing__c> listingsToUpdate = new List<Listing__c>();
                    for (Integer i = 0; i < recordNewList.size(); i++) {
                        if (recordNewList[i].Property__c == null) {
                            listingsToUpdate.add(new Listing__c(
                                Id = recordNewList[i].Id,
                                Property__c = newProperties[i].Id
                            ));
                        }
                    }
                    
                    if(Schema.sObjectType.Listing__c.isUpdateable()){
                        update as user listingsToUpdate;
                    }
                }
            } else {
                //when Automatic sync is off
                List<Property__c> newProperties = new List<Property__c>();

                Map<Id, Property__c> existingPropertiesMap = new Map<Id, Property__c>();

                for (Listing__c newListing : recordNewList) {
                    if (newListing.Property__c != null) {
                        existingPropertiesMap.put(newListing.Id, new Property__c(Id = newListing.Property__c));
                    }
                }
                
                Map<String, Property__c> matchingPropertiesMap = new Map<String, Property__c>();
                
                for (Property__c existingProperty : [SELECT Id, Name, Address__c, Bedrooms__c, Bathrooms__c FROM Property__c WITH USER_MODE LIMIT 5000]) {
                    String propertyKey = existingProperty.Name + '|' + existingProperty.Address__c + '|' + existingProperty.Bedrooms__c + '|' + existingProperty.Bathrooms__c;
                    matchingPropertiesMap.put(propertyKey, existingProperty);
                }
                
                
                for (Listing__c listing : recordNewList) {
                    if (listing.Property__c == null) {
                        String propertyKey = listing.Name + '|' + listing.Address__c + '|' + listing.Bedrooms__c	 + '|' + listing.Bathrooms__c;
                        if (matchingPropertiesMap.containsKey(propertyKey)) {
                            Property__c existingProperty = matchingPropertiesMap.get(propertyKey);
                            for (String listingField : fieldMappings.keySet()) {
                                if (listing.get(listingField) != null) {
                                    String propertyField = fieldMappings.get(listingField);
                                    if(propertyField != 'Id' && Schema.SObjectType.Property__c.fields.getMap().get(propertyField).getDescribe().isUpdateable() && propertyField != 'RecordTypeId' && listingFieldsMap.get(propertyField).getDescribe().getType() == propertyFieldsMap.get(propertyField).getDescribe().getType()){
                                        existingProperty.put(propertyField, listing.get(listingField));  
                                    }
                                }
                            }
                            newProperties.add(existingProperty);
                        }
                        else{
                            Property__c property = new Property__c(); 
                            for (String listingField : fieldMappings.keySet()) {
                                if (listing.get(listingField) != null) {
                                    String propertyField = fieldMappings.get(listingField);
                                    if(propertyField != 'Id' && Schema.SObjectType.Property__c.fields.getMap().get(propertyField).getDescribe().isUpdateable() && propertyField != 'RecordTypeId'&& listingFieldsMap.get(propertyField).getDescribe().getType() == propertyFieldsMap.get(propertyField).getDescribe().getType()){
                                        property.put(propertyField, listing.get(listingField));  
                                    }
                                }
                            }
                            newProperties.add(property);
                        }

                    }
                    else{
                        Property__c property = existingPropertiesMap.get(listing.Id);
                        for (String listingField : fieldMappings.keySet()) {
                            if (listing.get(listingField) != null && listingField != 'Name') {
                                String propertyField = fieldMappings.get(listingField);
                                if(propertyField != 'Id' && Schema.SObjectType.Property__c.fields.getMap().get(propertyField).getDescribe().isUpdateable() && propertyField != 'RecordTypeId' && listingFieldsMap.get(propertyField).getDescribe().getType() == propertyFieldsMap.get(propertyField).getDescribe().getType()){
                                    property.put(propertyField, listing.get(listingField));  
                                }
                            }
                        }
                        newProperties.add(property);

                    }

                }
                
                if (!newProperties.isEmpty() && Schema.sObjectType.Property__c.isCreateable() && Schema.sObjectType.Property__c.isUpdateable()) {
                    upsert as user newProperties;
                    
                    List<Listing__c> listingsToUpdate = new List<Listing__c>();
                    for (Integer i = 0; i < recordNewList.size(); i++) {
                        listingsToUpdate.add(new Listing__c(
                            Id = recordNewList[i].Id,
                            Property__c = newProperties[i].Id
                        ));
                    }
                    
                    if(Schema.sObjectType.Listing__c.isUpdateable()){
                        update as user listingsToUpdate;
                    }
                }
            }
        } catch(Exception e) {
            ErrorHandler.insertErrordata(e, 'ListingTriggerHandler', 'handleListingAfterInsert', 'Error while exectuing logicc listing trigger handler');
        }
    }

    public void handleListingAfterUpdate() {
        try {
            Mapping_Metadata__mdt metaData;
            if(Test.isRunningTest() && mockMetadata != null) {
                metaData = mockMetadata;
            } else {
                metaData = [SELECT Mapping_String__c, Automatic_Sync__c, BlockedFields__c FROM Mapping_Metadata__mdt WITH USER_MODE LIMIT 1];
            }
            
            Map<String, String> fieldMappings = new Map<String, String>();

            if(metaData.Mapping_String__c !=  null){
                String[] mappingPairs = metaData.Mapping_String__c.split(';');
                for (String pair : mappingPairs) {
                    String[] parts = pair.split(':');
                    if (parts.size() == 2) {
                        fieldMappings.put(parts[0], parts[1]);
                        
                    }
                }
            }

            if (recordNewList.isEmpty()) {
                return;
            }
            
            //When Automatic sync is on
            if (metaData.Automatic_Sync__c != null && metaData.Automatic_Sync__c == true) {
                List<Property__c> propertiesToUpdate = new List<Property__c>();
                Set<Id> propertyIds = new Set<Id>();
                for (Listing__c newListing : recordNewList) {
                    if (newListing.Property__c != null) {
                        propertyIds.add(newListing.Property__c);
                    }
                }
                Map<Id, Property__c> existingPropertiesMap = new Map<Id, Property__c>();
                if (!propertyIds.isEmpty()) {
                    for (Property__c existingProperty : [SELECT Id FROM Property__c WHERE Id IN :propertyIds WITH USER_MODE LIMIT 5000]) {
                        existingPropertiesMap.put(existingProperty.Id, existingProperty);
                    }
                }
                
                for (Listing__c newListing : recordNewList) {
                    if (newListing.Property__c != null && existingPropertiesMap.containsKey(newListing.Property__c)) {
                        Property__c existingProperty = existingPropertiesMap.get(newListing.Property__c);
                        Map<String, Object> listingFields = newListing.getPopulatedFieldsAsMap();
                        for (String fieldName : listingFields.keySet()) {
                            if (!fieldName.startsWith('System') && Schema.SObjectType.Property__c.fields.getMap().containsKey(fieldName) && Schema.SObjectType.Property__c.fields.getMap().get(fieldName).getDescribe().isUpdateable() && fieldName != 'Id' && fieldName != 'RecordTypeId') {
                                Schema.DescribeFieldResult listingFieldDescribe = Schema.SObjectType.Listing__c.fields.getMap().get(fieldName).getDescribe();
                                Schema.DescribeFieldResult propertyFieldDescribe = Schema.SObjectType.Property__c.fields.getMap().get(fieldName).getDescribe();
                                if (listingFieldDescribe.getType() == propertyFieldDescribe.getType()) {
                                    existingProperty.put(fieldName, newListing.get(fieldName));
                                }
                            }
                        }
                        propertiesToUpdate.add(existingProperty);
                    }
                }
                
                
                if (!propertiesToUpdate.isEmpty() && Schema.sObjectType.Property__c.isUpdateable()) {
                    update as user propertiesToUpdate;
                }
            }
            else {
                // When Automatic sync is off
                List<Property__c> propertiesToUpdate = new List<Property__c>();
            
                Map<Id, Property__c> existingPropertiesMap = new Map<Id, Property__c>();
                
                for (Listing__c newListing : recordNewList) {
                    if (newListing.Property__c != null) {
                        existingPropertiesMap.put(newListing.Id, new Property__c(Id = newListing.Property__c));
                    }
                }
            
                for (Listing__c newListing : recordNewList) {
                    if (newListing.Property__c != null) {
                        Property__c property = existingPropertiesMap.get(newListing.Id);
                        if (property != null) {
                            for (String listingField : fieldMappings.keySet()) {
                                String propertyField = fieldMappings.get(listingField);
                                if (newListing.get(listingField) != null && !metaData.BlockedFields__c.contains(propertyField) && propertyField != 'Id') {
                                    Schema.DescribeFieldResult listingFieldDescribe = Schema.SObjectType.Listing__c.fields.getMap().get(listingField).getDescribe();
                                    Schema.DescribeFieldResult propertyFieldDescribe = Schema.SObjectType.Property__c.fields.getMap().get(propertyField).getDescribe();
                                    if (listingFieldDescribe.getType() == propertyFieldDescribe.getType()) {
                                        property.put(propertyField, newListing.get(listingField));
                                    }
                                }
                            }
                            propertiesToUpdate.add(property);
                        }
                    }
                }
    
            
                if (!propertiesToUpdate.isEmpty() && Schema.sObjectType.Property__c.isUpdateable()) {
                    update as user propertiesToUpdate; 
                }
            }
            
            
        } catch(Exception e) {
            ErrorHandler.insertErrordata(e, 'ListingTriggerHandler', 'handleListingAfterUpdate', 'Error while exectuing logicc listing trigger handler');
        }
    }    
}