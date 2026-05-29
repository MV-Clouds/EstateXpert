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
    
    public void handleListingAfterInsert() {
        // If the property is already assigned at creation time, nothing to do.
        List<Listing__c> listingsNeedingProperty = new List<Listing__c>();
        for (Listing__c listing : recordNewList) {
            if (listing.Property__c == null) {
                listingsNeedingProperty.add(listing);
            }
        }

        if (listingsNeedingProperty.isEmpty()) {
            return; 
        }

        Boolean propertiesInserted = false;
        List<Property__c> propertiesToInsert = new List<Property__c>();

        try {
            Mapping_Metadata__mdt metaData;
            if (Test.isRunningTest() && mockMetadata != null) {
                metaData = mockMetadata;
            } else {
                metaData = [SELECT Mapping_String__c, Automatic_Sync__c, BlockedFields__c
                            FROM Mapping_Metadata__mdt WITH USER_MODE LIMIT 1];
            }

            Map<String, Schema.SObjectField> listingFieldsMap = Schema.SObjectType.Listing__c.fields.getMap();
            Map<String, Schema.SObjectField> propertyFieldsMap = Schema.SObjectType.Property__c.fields.getMap();

            Boolean isAutoSync = metaData.Automatic_Sync__c == true;

            if (isAutoSync) {
                Set<String> writableListingFields = new Set<String>();
                for (String f : listingFieldsMap.keySet()) {
                    if (listingFieldsMap.get(f).getDescribe().isUpdateable()) {
                        writableListingFields.add(f); // keys are already lowercase
                    }
                }

                Set<String> writablePropertyFields = new Set<String>();
                for (String f : propertyFieldsMap.keySet()) {
                    if (propertyFieldsMap.get(f).getDescribe().isUpdateable()) {
                        writablePropertyFields.add(f);
                    }
                }

                // Intersection: fields with the same API name on both objects
                Set<String> matchingFields = new Set<String>(writableListingFields);
                matchingFields.retainAll(writablePropertyFields);

                // Build one Property record per qualifying listing
                for (Listing__c listing : listingsNeedingProperty) {
                    Property__c prop = new Property__c();
                    for (String fieldName : matchingFields) {
                        // Skip system-managed fields that must not be set manually
                        if (fieldName.equalsIgnoreCase('Id') ||
                                fieldName.equalsIgnoreCase('RecordTypeId')) {
                            continue;
                        }
                        try {
                            Object val = listing.get(fieldName);
                            if (val != null) {
                                prop.put(fieldName, val);
                            }
                        } catch (Exception ignored) {
                            // Field is absent on this Listing record — skip silently
                        }
                    }

                    final String LISTING_ADDR_PREFIX  = 'mvex__listing_address__';
                    final String PROPERTY_ADDR_PREFIX = 'mvex__property_address__';
                    for (String listingFieldKey : listingFieldsMap.keySet()) {
                        if (!listingFieldKey.startsWith(LISTING_ADDR_PREFIX)) {
                            continue;
                        }
                        // Sub-field suffix, e.g. 'street__s', 'city__s'
                        String suffix = listingFieldKey.substring(LISTING_ADDR_PREFIX.length());
                        String propertyFieldKey = PROPERTY_ADDR_PREFIX + suffix;

                        if (!propertyFieldsMap.containsKey(propertyFieldKey)) {
                            continue; // Matching address sub-field does not exist on Property
                        }
                        Schema.DescribeFieldResult propAddrDescribe =
                            propertyFieldsMap.get(propertyFieldKey).getDescribe();
                        if (!propAddrDescribe.isCreateable() && !propAddrDescribe.isUpdateable()) {
                            continue; // Sub-field is read-only — skip
                        }
                        try {
                            Object val = listing.get(listingFieldKey);
                            if (val != null) {
                                prop.put(propertyFieldKey, val);
                            }
                        } catch (Exception ignored) {
                            // Sub-field not populated — skip silently
                        }
                    }

                    propertiesToInsert.add(prop);
                }

            } else {
                Map<String, String> fieldMappings = new Map<String, String>();
                if (metaData.Mapping_String__c != null) {
                    for (String pair : metaData.Mapping_String__c.split(';')) {
                        List<String> parts = pair.split(':');
                        if (parts.size() == 2 &&
                                String.isNotBlank(parts[0]) &&
                                String.isNotBlank(parts[1])) {
                            fieldMappings.put(parts[0].trim(), parts[1].trim());
                        }
                    }
                }

                for (Listing__c listing : listingsNeedingProperty) {
                    Property__c prop = new Property__c();

                    for (String listingField : fieldMappings.keySet()) {
                        String propertyField = fieldMappings.get(listingField);

                        // Guard: skip reserved / system fields
                        if (String.isBlank(propertyField) ||
                                propertyField.equalsIgnoreCase('Id') ||
                                propertyField.equalsIgnoreCase('RecordTypeId')) {
                            continue;
                        }

                        // Guard: verify the target field exists on Property__c
                        Schema.SObjectField propFieldToken =
                            propertyFieldsMap.get(propertyField.toLowerCase());
                        if (propFieldToken == null) {
                            continue; // Field doesn't exist on Property — skip
                        }

                        // Guard: field must be settable (createable or updateable)
                        Schema.DescribeFieldResult propDescribe = propFieldToken.getDescribe();
                        if (!propDescribe.isCreateable() && !propDescribe.isUpdateable()) {
                            continue; // Read-only field — skip
                        }

                        try {
                            Object val = listing.get(listingField);
                            if (val != null) {
                                prop.put(propertyField, val);
                            }
                        } catch (Exception ignored) {
                            // Field absent or incompatible — skip silently
                        }
                    }
                    propertiesToInsert.add(prop);
                }
            }

            if (!propertiesToInsert.isEmpty()) {
                insert as user propertiesToInsert;
                propertiesInserted = true;
            }
            List<Listing__c> listingsToUpdate = new List<Listing__c>();
            for (Integer i = 0; i < listingsNeedingProperty.size(); i++) {
                listingsToUpdate.add(new Listing__c(
                    Id         = listingsNeedingProperty[i].Id,
                    Property__c = propertiesToInsert[i].Id
                ));
            }

            if (!listingsToUpdate.isEmpty()) {
                update as user listingsToUpdate;
            }

        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'ListingTriggerHandler', 'handleListingAfterInsert', 'Error while executing listing trigger handler');
            if (!propertiesInserted) {
                try {
                    List<Property__c> fallbackProperties = new List<Property__c>();
                    for (Listing__c listing : listingsNeedingProperty) {
                        Property__c fallback = new Property__c();
                        fallback.Name = listing.Name;
                        fallback.MVEX__Failed_Mapping_Reason__c = e.getMessage();
                        fallbackProperties.add(fallback);
                    }

                    if (!fallbackProperties.isEmpty()) {
                        insert as user fallbackProperties;
                    }

                    List<Listing__c> listingsToUpdate = new List<Listing__c>();
                    for (Integer i = 0; i < listingsNeedingProperty.size(); i++) {
                        listingsToUpdate.add(new Listing__c(
                            Id          = listingsNeedingProperty[i].Id,
                            Property__c = fallbackProperties[i].Id
                        ));
                    }
                    if (!listingsToUpdate.isEmpty()) {
                        update as user listingsToUpdate;
                    }

                } catch (Exception fallbackEx) {
                    ErrorHandler.insertErrordata(fallbackEx, 'ListingTriggerHandler', 'handleListingAfterInsert', 'Error creating fallback property record');
                }
            }
        }
    }
}