/**
 * @description       : This apex class is used to display property from the record page of listing and inquiry
 * @author            : MitrajSinh Gohil
 * @last modified on  : 25-07-2024
 * @last modified by  : Rachit Shah
 **/
public with sharing class PropertySearchController {
    
    /**
     * @description       : This wrapper class is used to send data from apex method
     * @author            : MitrajSinh Gohil
     * @last modified on  : 25-07-2024
     * @last modified by  : Rachit Shah
     **/
    public class WrapperClass {
        @AuraEnabled
        public List<MVEX__Listing__c> listings;
        @AuraEnabled
        public List<MVEX__Inquiry__c> inquiries;
        @AuraEnabled
        public Map<Id, String> medias;
        @AuraEnabled
        public Map<String, Map<String, String>> referenceNameMappings; 
    }
    
    @AuraEnabled
    public static string getObjectName(String recId){
        try {
            Id recordId = Id.valueOf(recId);
            String objectName = recordId.getSObjectType().getDescribe().getName();
            return objectName;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e,'PropertySearchController','getObjectName' , e.getStackTraceString());
            return '';
        }
    }

    @AuraEnabled
    public static String getRecordName(String recordId, String objectApiName) {
        try {
            if (String.isBlank(recordId) || String.isBlank(objectApiName)) return '';
            String query = 'SELECT Name FROM ' + String.escapeSingleQuotes(objectApiName) + ' WHERE Id = :recordId LIMIT 1';
            List<SObject> records = Database.query(query, AccessLevel.USER_MODE);
            if (!records.isEmpty()) {
                return (String) records[0].get('Name');
            }
            return '';
        } catch (Exception e) {
            return '';
        }
    }
    
    /**
     * @description       : This apex class method is used for getting listing and inquiry data
     * @author            : MitrajSinh Gohil
     * @last modified on  : 26-03-2026
     * @last modified by  : Kajal Tiwari
     **/
    @AuraEnabled
    public static WrapperClass getRecords(String recId, String objectName, String filterType) {
        try {
            if (String.isBlank(objectName) && !String.isBlank(recId)) {
                objectName = Id.valueOf(recId).getSObjectType().getDescribe().getName();
            }

            WrapperClass wc = new WrapperClass();
            Set<Id> propertyIds = new Set<Id>();

            // Get configured fields to include in SOQL
            List<MVEX__Configuration_Settings__c> configs = [SELECT MVEX__Fields_Data__c FROM MVEX__Configuration_Settings__c 
                                                            WHERE MVEX__Feature_Name__c = 'Suggested_Listing_Fields' WITH USER_MODE LIMIT 1];
            
            Set<String> extraListingFields = new Set<String>();
            
            if (!configs.isEmpty() && String.isNotBlank(configs[0].MVEX__Fields_Data__c)) {
                List<Object> fieldsData = (List<Object>)JSON.deserializeUntyped(configs[0].MVEX__Fields_Data__c);
                for (Object obj : fieldsData) {
                    Map<String, Object> field = (Map<String, Object>)obj;
                    String fieldName = (String)field.get('fieldApiname');
                    if (String.isNotBlank(fieldName)) {
                        extraListingFields.add(fieldName.toLowerCase());
                    }
                }
            }

            String listingFieldsStr = getAllFields('MVEX__Listing__c');
            String inquiryFieldsStr = getAllFields('MVEX__Inquiry__c');
            
            Set<String> listingFieldsSet = new Set<String>(listingFieldsStr.toLowerCase().split(','));

            // Only add extra configured fields to the Listing query.
            // These fields come from 'Suggested_Listing_Fields' and belong to MVEX__Listing__c only.
            // Adding them to inquiryFieldsStr would cause a QueryException on MVEX__Inquiry__c.
            for (String f : extraListingFields) {
                if (!listingFieldsSet.contains(f)) {
                    listingFieldsStr += ',' + f;
                    listingFieldsSet.add(f);
                }
            }

            List<MVEX__Listing__c> listings = new List<MVEX__Listing__c>();
            List<MVEX__Inquiry__c> inquiries = new List<MVEX__Inquiry__c>();

            // ---------- COMMON: Fetch current record once ----------
            MVEX__Listing__c currentListing;
            MVEX__Inquiry__c currentInquiry;

            if (objectName == 'MVEX__Listing__c') {
                List<MVEX__Listing__c> temp = Database.query(
                    'SELECT ' + listingFieldsStr + ' FROM MVEX__Listing__c WHERE Id = :recId',AccessLevel.USER_MODE);
                if (!temp.isEmpty()) currentListing = temp[0];
            }

            if (objectName == 'MVEX__Inquiry__c') {
                List<MVEX__Inquiry__c> temp = Database.query(
                    'SELECT ' + inquiryFieldsStr + ' FROM MVEX__Inquiry__c WHERE Id = :recId',AccessLevel.USER_MODE);
                if (!temp.isEmpty()) currentInquiry = temp[0];
            }

            // ---------- LINKED ----------
            if (filterType == 'linked') {

                if (objectName == 'MVEX__Listing__c') {

                    inquiries = Database.query(
                        'SELECT ' + inquiryFieldsStr + ' FROM MVEX__Inquiry__c WHERE Id IN ' + '(SELECT MVEX__Inquiry__c FROM MVEX__Listing_Inquiry__c WHERE MVEX__Listing__c = :recId)',
                        AccessLevel.USER_MODE);

                    if (currentListing != null) {
                        listings.add(currentListing);
                    }
                }

                else if (objectName == 'MVEX__Inquiry__c') {

                    listings = Database.query(
                        'SELECT ' + listingFieldsStr +
                        ' FROM MVEX__Listing__c WHERE Id IN ' + '(SELECT MVEX__Listing__c FROM MVEX__Listing_Inquiry__c WHERE MVEX__Inquiry__c = :recId)',
                        AccessLevel.USER_MODE);

                    if (currentInquiry != null) {
                        inquiries.add(currentInquiry);
                    }
                }
            }

            // ---------- RELATED ----------
            else if (filterType == 'related') {

                if (objectName == 'MVEX__Listing__c') {

                    inquiries = Database.query(
                        'SELECT ' + inquiryFieldsStr + ' FROM MVEX__Inquiry__c WHERE MVEX__Listing__c = :recId',
                        AccessLevel.USER_MODE);

                    if (currentListing != null) {
                        listings.add(currentListing);
                    }
                }

                else if (objectName == 'MVEX__Inquiry__c') {

                    Id listingId = currentInquiry != null ? currentInquiry.MVEX__Listing__c : null;

                    if (listingId != null) {
                        listings = Database.query(
                            'SELECT ' + listingFieldsStr + ' FROM MVEX__Listing__c WHERE Id = :listingId',
                            AccessLevel.USER_MODE);
                    }

                    if (currentInquiry != null) {
                        inquiries.add(currentInquiry);
                    }
                }
            }

            // ---------- DEFAULT ----------
            else {

                if (objectName == 'MVEX__Listing__c') {

                    // Fetch ALL listings (no WHERE clause) so that the 'No Filter' option
                    // shows every listing in the org, not just the current one.
                    listings = Database.query(
                        'SELECT ' + listingFieldsStr +
                        ', (SELECT ' + inquiryFieldsStr + ' FROM MVEX__Inquirys__r)' + ' FROM MVEX__Listing__c',
                        AccessLevel.USER_MODE);

                    inquiries = Database.query(
                        'SELECT ' + inquiryFieldsStr + ' FROM MVEX__Inquiry__c',AccessLevel.USER_MODE);
                }

                else if (objectName == 'MVEX__Inquiry__c') {

                    if (currentInquiry != null) {
                        inquiries.add(currentInquiry);
                    }

                    listings = Database.query(
                        'SELECT ' + listingFieldsStr +
                        ', (SELECT ' + inquiryFieldsStr + ' FROM MVEX__Inquirys__r)' + ' FROM MVEX__Listing__c',
                        AccessLevel.USER_MODE);
                }
            }

            // ---------- property ids ----------
            for (MVEX__Listing__c listing : listings) {
                if (listing.MVEX__Property__c != null) {
                    propertyIds.add(listing.MVEX__Property__c);
                }
            }

            wc.listings = listings;
            wc.inquiries = inquiries;
            
            // ---------- resolve reference field names ----------
            wc.referenceNameMappings = resolveInquiryReferenceNames(inquiries);

            // ---------- media ----------
            if (!propertyIds.isEmpty()) {
                Map<Id, String> mediaMap = new Map<Id, String>();

                for (MVEX__Property_File__c media : [
                    SELECT MVEX__Property__c, MVEX__BaseUrl__c
                    FROM MVEX__Property_File__c
                    WHERE MVEX__Property__c IN :propertyIds
                    WITH USER_MODE
                ]) {
                    mediaMap.put(media.MVEX__Property__c, media.MVEX__BaseUrl__c);
                }

                wc.medias = mediaMap;
            } else {
                wc.medias = new Map<Id, String>();
            }

            return wc;

        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'PropertySearchController', 'getRecords', e.getStackTraceString());
            return null;
        }
    }
    
    /**
     * @description       : Helper method to resolve all reference field IDs in inquiries to their record names
     * @author            : Kajal Tiwari
     * @last modified on  : 01-04-2026
     * @last modified by  : Kajal Tiwari
     **/
    private static Map<String, Map<String, String>> resolveInquiryReferenceNames(List<MVEX__Inquiry__c> inquiries) {
        Map<String, Map<String, String>> refMappings = new Map<String, Map<String, String>>();
        
        if (inquiries == null || inquiries.isEmpty()) {
            return refMappings;
        }
        
        try {
            // Get field descriptions for MVEX__Inquiry__c (handling namespace dynamically)
            Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
            Schema.SObjectType inquiryType = globalDescribe.get('MVEX__Inquiry__c');
            if (inquiryType == null) {
                inquiryType = globalDescribe.get('MVEX__Inquiry__c');
            }
            Map<String, Schema.SObjectField> fieldMap = inquiryType != null ? inquiryType.getDescribe().fields.getMap() : new Map<String, Schema.SObjectField>();
            Map<String, Set<Id>> refIdsByField = new Map<String, Set<Id>>();
            
            // Collect all reference field IDs
            for (MVEX__Inquiry__c inq : inquiries) {
                for (String fieldName : fieldMap.keySet()) {
                    Schema.DescribeFieldResult fieldDesc = fieldMap.get(fieldName).getDescribe();
                    
                    // Check if field is a reference/lookup field
                    if (fieldDesc.getType() == Schema.DisplayType.REFERENCE) {
                        Object fieldValue = inq.get(fieldName);
                        if (fieldValue != null && fieldValue instanceof Id) {
                            Id refId = (Id)fieldValue;
                            if (!refIdsByField.containsKey(fieldName)) {
                                refIdsByField.put(fieldName, new Set<Id>());
                            }
                            refIdsByField.get(fieldName).add(refId);
                        }
                    }
                }
            }
            
            // For each reference field, resolve IDs to Names
            for (String fieldName : refIdsByField.keySet()) {
                Set<Id> ids = refIdsByField.get(fieldName);
                if (ids.isEmpty()) continue;
                
                Map<String, String> nameMap = new Map<String, String>();
                
                try {
                    // Get the object type for this reference field
                    Schema.DescribeFieldResult fieldDesc = fieldMap.get(fieldName).getDescribe();
                    List<Schema.SObjectType> referenceTo = fieldDesc.getReferenceTo();
                    
                    if (!referenceTo.isEmpty()) {
                        String refObjectName = referenceTo[0].getDescribe().getName();
                        
                        // Query for names using dynamic SOQL
                        String soql = 'SELECT Id, Name FROM ' + refObjectName + ' WHERE Id IN :ids WITH USER_MODE';
                        for (SObject record : Database.query(soql)) {
                            nameMap.put((String)record.Id, (String)record.get('Name'));
                        }
                    }
                } catch (Exception e) {
                    // Log but continue processing other fields
                    ErrorHandler.insertErrorData(e, 'PropertySearchController', 'resolveInquiryReferenceNames', 'Error resolving reference field: ' + fieldName);
                }
                
                if (!nameMap.isEmpty()) {
                    refMappings.put(fieldName, nameMap);
                }
            }
            
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'PropertySearchController', 'resolveInquiryReferenceNames', e.getStackTraceString());
        }
        
        return refMappings;
    }
    
    private static String getAllFields(String objectName) {
        try {
            Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
            if (globalDescribe.containsKey(objectName)) {
                Schema.SObjectType sObjectType = globalDescribe.get(objectName);
                Schema.DescribeSObjectResult describeResult = sObjectType.getDescribe();
                Map<String, Schema.SObjectField> fieldsMap = describeResult.fields.getMap();
                
                List<String> fieldNames = new List<String>();
                
                for (String fieldName : fieldsMap.keySet()) {
                    Schema.DescribeFieldResult fieldDescribe = fieldsMap.get(fieldName).getDescribe();
                    if (fieldDescribe.isAccessible()) {
                        fieldNames.add(fieldName);
                        
                        // For lookup/reference fields, also include the parent Name via relationship
                        // e.g. MVEX__Contact__c  ->  MVEX__Contact__r.Name
                        // This allows the LWC to read the display name directly from nested object
                        if (fieldDescribe.getType() == Schema.DisplayType.REFERENCE) {
                            String relName = fieldDescribe.getRelationshipName();
                            if (String.isNotBlank(relName)) {
                                try {
                                    // Verify the parent object has a Name field before adding
                                    List<Schema.SObjectType> refs = fieldDescribe.getReferenceTo();
                                    if (!refs.isEmpty()) {
                                        Map<String, Schema.SObjectField> parentFields = refs[0].getDescribe().fields.getMap();
                                        if (parentFields.containsKey('name') || parentFields.containsKey('Name')) {
                                            fieldNames.add(relName + '.Name');
                                        }
                                    }
                                } catch (Exception ex) {
                                    // Skip if parent object doesn't support Name field
                                }
                            }
                        }
                    }
                }
                
                return String.join(fieldNames, ',');
            } else {
                return '';
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e,'PropertySearchController','getAllFields' , e.getStackTraceString());
            return '';
        }
    }
    
    public class FieldWrapper {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public String type;
        @AuraEnabled public List<String> picklistValues;
        @AuraEnabled public List<Map<String, String>> picklistEntries;
        @AuraEnabled public String referenceTo;
    }
    
    public class ObjectFieldsWrapper {
        @AuraEnabled public List<FieldWrapper> fields;
    }
    
    @AuraEnabled
    public static ObjectFieldsWrapper getObjectFields(String objectName){
        ObjectFieldsWrapper result = new ObjectFieldsWrapper();
        result.fields = new List<FieldWrapper>();
        try {
            // Get the object's label
            Schema.DescribeSObjectResult describeSObjectResult = Schema.getGlobalDescribe().get(objectName).getDescribe();
            
            // Get the object's fields
            Map<String, Schema.SObjectField> fieldsMap = describeSObjectResult.fields.getMap();
            for (String fieldName : fieldsMap.keySet()) {
                Schema.DescribeFieldResult fieldDescribe = fieldsMap.get(fieldName).getDescribe();
                FieldWrapper fieldInfo = new FieldWrapper();
                fieldInfo.label = fieldDescribe.getLabel();
                fieldInfo.value = fieldName;
                
                List<String> textFields = new List<String>{'STRING', 'TEXTAREA', 'ID'};
                List<String> numberFields = new List<String>{'CURRENCY', 'DOUBLE', 'PHONE'};
                
                String fieldType = fieldDescribe.getType().name();
                
                if (textFields.contains(fieldType)) {
                    fieldInfo.type = 'TEXT';
                } else if (numberFields.contains(fieldType)) {
                    fieldInfo.type = 'NUMBER';
                } else {
                    fieldInfo.type = fieldType;
                }
                
                fieldInfo.picklistValues = new List<String>();
                fieldInfo.picklistEntries = new List<Map<String, String>>();
                
                if (fieldDescribe.getType() == Schema.DisplayType.Picklist || fieldDescribe.getType() == Schema.DisplayType.MultiPicklist) {
                    List<Schema.PicklistEntry> picklistEntries = fieldDescribe.getPicklistValues();
                    for (Schema.PicklistEntry entry : picklistEntries) {
                        fieldInfo.picklistValues.add(entry.getLabel());
                        fieldInfo.picklistEntries.add(new Map<String, String>{
                            'label' => entry.getLabel(),
                            'value' => entry.getValue()
                        });
                    }
                }
                
                else if (fieldDescribe.getType() == Schema.DisplayType.Boolean) {
                    fieldInfo.picklistValues.add('true');
                    fieldInfo.picklistValues.add('false');
                }
                
                else if (fieldDescribe.getType() == Schema.DisplayType.Reference) {
                    List<Schema.SObjectType> referenceToList = fieldDescribe.getReferenceTo();
                    if (!referenceToList.isEmpty()) {
                        fieldInfo.referenceTo = referenceToList[0].getDescribe().getName();
                    }
                }
                
                result.fields.add(fieldInfo);
            }
            
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'PropertySearchController', 'getObjectFields', 'Error while getting object fields.');
        }
        return result;
    }

    @AuraEnabled
    public static List<Map<String, String>> getContactsForInquiries(List<String> inquiryIds) {
        try {
            // Query inquiries with their related contacts
            Map<Id, MVEX__Inquiry__c> inquiries = new Map<Id, MVEX__Inquiry__c>([SELECT Id, Name, MVEX__Contact__c FROM MVEX__Inquiry__c WHERE Id IN :inquiryIds AND MVEX__Contact__c != NULL WITH USER_MODE]);

            // Query contacts for the related MVEX__Contact__c IDs
            Set<Id> contactIds = new Set<Id>();
            for (MVEX__Inquiry__c inquiry : inquiries.values()) {
                contactIds.add(inquiry.MVEX__Contact__c);
            }

            Map<Id, Contact> contacts = new Map<Id, Contact>([SELECT Id, Name, Phone FROM Contact WHERE Id IN :contactIds WITH USER_MODE]);

            // Build the result list with inquiry and contact details
            List<Map<String, String>> result = new List<Map<String, String>>();
            for (MVEX__Inquiry__c inquiry : inquiries.values()) {
                Contact contact = contacts.get(inquiry.MVEX__Contact__c);
                if (contact != null) {
                    result.add(new Map<String, String>{
                        'InquiryId' => inquiry.Id,
                        'InquiryName' => inquiry.Name,
                        'ContactId' => contact.Id,
                        'ContactName' => contact.Name,
                        'Phone' => contact.Phone
                    });
                }
            }

            return result;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'PropertySearchController', 'getContactsForInquiries', 'Error while getting contacts for inquiries.');
            return new List<Map<String, String>>();
        }
    }

    /**
     * @description       : This method checks if Business Account ID is configured in custom metadata
     * @last modified on  : 03-02-2026
     **/
    @AuraEnabled
    public static Boolean hasBusinessAccountId() {
        try {
            MVEX__WhatsAppConfig__c config = MVEX__WhatsAppConfig__c.getOrgDefaults();
            return config != null && String.isNotBlank(config.MVEX__Whatsapp_Business_Account_Id__c);
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'PropertySearchController', 'hasBusinessAccountId', 'Error while checking business account ID.');
            return false;
        }
    }

}