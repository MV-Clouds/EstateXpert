public with sharing class RecordManagersCmpController {

    public class RecordManagerData {
        @AuraEnabled public List<FieldDetails> fieldDetailsList;
        @AuraEnabled public List<String> metadataRecords;
    }
    
    public class FieldInfoWrapper {
        @AuraEnabled public String value;
        @AuraEnabled public String label;
    }

    /**
     * Method Name : getObjectFields
     * @description : get object fields.
     * @param objectApiName String value.
     */
    @AuraEnabled
    public static RecordManagerData getObjectFields(String objectApiName, String featureName) {
        try {
            RecordManagerData recordData = new RecordManagerData();
            List<FieldDetails> fieldDetailsList = new List<FieldDetails>();

            Schema.DescribeSObjectResult objDescribe = Schema.getGlobalDescribe().get(objectApiName).getDescribe();
            Map<String, Schema.SObjectField> fieldsMap = objDescribe.fields.getMap();

            for (String fieldName : fieldsMap.keySet()) {
                Schema.SObjectField field = fieldsMap.get(fieldName);
                Schema.DescribeFieldResult fieldDescribe = field.getDescribe();

                FieldDetails fieldDetails = new FieldDetails();
                fieldDetails.label = fieldDescribe.getLabel();
                fieldDetails.value = fieldDescribe.getName();
                fieldDetails.fieldType = String.valueOf(fieldDescribe.getType());

                if (fieldDescribe.getType() == Schema.DisplayType.Reference) {
                    List<Schema.SObjectType> referenceTo = fieldDescribe.getReferenceTo();
                    if (!referenceTo.isEmpty()) {
                        fieldDetails.referenceObjectName = referenceTo[0].getDescribe().getName();
                        fieldDetails.relationshipName = fieldDescribe.getRelationshipName();
                    }
                } else {
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
            recordData.fieldDetailsList = fieldDetailsList;

            List<String> metadataValues = new List<String>();
            String metadataType;
            if (featureName == 'Listing_Configuration' && objectApiName == 'MVEX__Listing__c') {
                metadataType = 'MVEX__listingData__mdt';
            }
            else if(objectApiName == 'MVEX__Listing__c'){
                metadataType = 'MVEX__recordManagerConfig__mdt';
            } else if(objectApiName == 'MVEX__Inquiry__c'){  // Add Inquiry support
                metadataType = 'MVEX__recordManagerInquiryConfig__mdt';
            } else {
                metadataType = 'MVEX__recordManagerMarketingConfig__mdt';
            }
            String query = 'SELECT MVEX__FieldsData__c, MVEX__PageSize__c FROM ' + String.escapeSingleQuotes(metadataType) + ' LIMIT 1';
            List<SObject> metadataRecords = Database.query(query, AccessLevel.USER_MODE);

            if (!metadataRecords.isEmpty()) {
                SObject metadataRecord = metadataRecords[0];
                metadataValues.add((String)metadataRecord.get('MVEX__FieldsData__c'));
                metadataValues.add(String.valueOf(metadataRecord.get('MVEX__PageSize__c')));
            }

            recordData.metadataRecords = metadataValues;

            return recordData;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'RecordManagersCmpController', 'getObjectFields', e.getMessage());
            return null;
        }
    }

    /**
     * Method Name : getObjectFieldsWithMetaData
     * @description : get object fields with metadata.
     * @param objectApiName String value.
     */
    @AuraEnabled
    public static RecordManagerData getObjectFieldsWithMetaData(String objectApiName) {
        try {
            String escapedObjectApiName = String.escapeSingleQuotes(objectApiName);
            RecordManagerData recordData = new RecordManagerData();
            List<FieldDetails> fieldDetailsList = new List<FieldDetails>();

            Schema.DescribeSObjectResult objDescribe = Schema.getGlobalDescribe().get(objectApiName).getDescribe();
            Map<String, Schema.SObjectField> fieldsMap = objDescribe.fields.getMap();

            for (String fieldName : fieldsMap.keySet()) {
                Schema.SObjectField field = fieldsMap.get(fieldName);
                Schema.DescribeFieldResult fieldDescribe = field.getDescribe();

                FieldDetails fieldDetails = new FieldDetails();
                fieldDetails.label = fieldDescribe.getLabel();
                fieldDetails.value = fieldDescribe.getName();
                fieldDetails.fieldType = String.valueOf(fieldDescribe.getType());

                fieldDetailsList.add(fieldDetails);
            }
            recordData.fieldDetailsList = fieldDetailsList;
            List<String> metadataValues = new List<String>();

            List<New_Record_Fields__mdt> metadataRecords = [SELECT Field_Data__c FROM New_Record_Fields__mdt WHERE Object_API_Name__c = :escapedObjectApiName WITH USER_MODE];
            if (!metadataRecords.isEmpty()) {
                New_Record_Fields__mdt metadataRecord = metadataRecords[0];
                metadataValues.add(metadataRecord.Field_Data__c);
            }

            recordData.metadataRecords = metadataValues;

            return recordData;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'MarketingListFilterController', 'getObjectFieldsWithMetaData', e.getMessage());
            return null;
        }
    }

   /**
    * Class Name : FieldDetails
    * @description : this is a wrapper class to pass multiple values to the LWC component.
    */
    public class FieldDetails {
        @AuraEnabled
        public String label { get; set; }
        @AuraEnabled
        public String value { get; set; }
        @AuraEnabled
        public String fieldType { get; set; }
        @AuraEnabled
        public String referenceObjectName { get; set; }
        @AuraEnabled
        public String relationshipName { get; set; }
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
     * Method Name : saveMappings
     * @description : save mapping in the of the fields.
     * @param checklistData String value.
     * @param totalPages Integer value.
     * @param objectApiName String value.
     */
    @AuraEnabled
    public static void saveMappings(String checklistData, Integer totalPages, String objectApiName,String featureName) {
        try {
            String metadataType;

            System.debug('Feature Name: ' + featureName);
            if (featureName == 'Listing_Configuration' && objectApiName == 'MVEX__Listing__c') {
                metadataType = 'listingData__mdt';
            }
            else if (objectApiName == 'MVEX__Listing__c') {
                metadataType = 'MVEX__recordManagerConfig__mdt';
            } else if (objectApiName == 'MVEX__Inquiry__c') {  // Add Inquiry support
                metadataType = 'MVEX__recordManagerInquiryConfig__mdt';
            } else {
                metadataType = 'MVEX__recordManagerMarketingConfig__mdt';
            }

            String developerName = 'RecordConfig';
            String masterLabel = 'RecordConfig';
            String query = 'SELECT MasterLabel, DeveloperName FROM ' + String.escapeSingleQuotes(metadataType) + ' LIMIT 1';
            List<SObject> metaList = Database.query(query, AccessLevel.USER_MODE);

            if (featureName == 'Listing_Configuration' && objectApiName == 'MVEX__Listing__c') {
                listingData__mdt config;
                if (!metaList.isEmpty()) {
                    config = (listingData__mdt) metaList[0];
                    developerName = config.DeveloperName;
                    masterLabel = config.MasterLabel;
                }
            }
            else if (objectApiName == 'MVEX__Listing__c') {
                recordManagerConfig__mdt config;
                if (!metaList.isEmpty()) {
                    config = (recordManagerConfig__mdt) metaList[0];
                    developerName = config.DeveloperName;
                    masterLabel = config.MasterLabel;
                }
            } else if (objectApiName == 'MVEX__Inquiry__c') {  // Add Inquiry support
                recordManagerInquiryConfig__mdt config;
                if (!metaList.isEmpty()) {
                    config = (recordManagerInquiryConfig__mdt) metaList[0];
                    developerName = config.DeveloperName;
                    masterLabel = config.MasterLabel;
                }
            } else {
                recordManagerMarketingConfig__mdt config;
                if (!metaList.isEmpty()) {
                    config = (recordManagerMarketingConfig__mdt) metaList[0];
                    developerName = config.DeveloperName;
                    masterLabel = config.MasterLabel;
                }
            }

            Metadata.CustomMetadata mdata = new Metadata.CustomMetadata();
            mdata.fullName = metadataType + '.' + developerName;
            mdata.label = masterLabel;

            Metadata.CustomMetadataValue fieldsDataValue = new Metadata.CustomMetadataValue();
            fieldsDataValue.field = 'MVEX__FieldsData__c';
            fieldsDataValue.value = checklistData;
            mdata.values.add(fieldsDataValue);

            Metadata.CustomMetadataValue pageSizeValue = new Metadata.CustomMetadataValue();
            pageSizeValue.field = 'MVEX__PageSize__c';
            pageSizeValue.value = totalPages;
            mdata.values.add(pageSizeValue);

            Metadata.DeployContainer container = new Metadata.DeployContainer();
            container.addMetadata(mdata);

            Metadata.Operations.enqueueDeployment(container, null);
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'RecordManagersCmpController', 'saveMappings', e.getStackTraceString());
        }
    }

    /**
     * Method Name : saveMappingsNewFields
     * @description : save mapping in the of the fields.
     * @param selectFieldsData String value.
     * @param objectApiName String value.
     */
    @AuraEnabled
    public static String saveMappingsNewFields(String selectFieldsData, String objectApiName) {
        try {
            String escapedObjectApiName = String.escapeSingleQuotes(objectApiName);
            List<New_Record_Fields__mdt> metaList = [SELECT MasterLabel, DeveloperName, Field_Data__c, Object_API_Name__c FROM New_Record_Fields__mdt WHERE Object_API_Name__c = :escapedObjectApiName WITH USER_MODE LIMIT 1];

            String devName = objectApiName.replace('', '').replace('__c', '') + 'Fields';
            String masterLabel = objectApiName.replace('', '').replace('__c', '') + 'Fields';

            New_Record_Fields__mdt config = new New_Record_Fields__mdt();

            if (!metaList.isEmpty()) {
                config = metaList[0];
                devName = config.DeveloperName;
                masterLabel = config.MasterLabel;
            }

            Metadata.CustomMetadata mdata = new Metadata.CustomMetadata();
            mdata.fullName = 'MVEX__New_Record_Fields__mdt.' + devName;
            mdata.label = masterLabel;
            
            Metadata.CustomMetadataValue instance = new Metadata.CustomMetadataValue();
            instance.field = 'MVEX__Field_Data__c';
            instance.value = selectFieldsData;
            mdata.values.add(instance);

            Metadata.CustomMetadataValue instance1 = new Metadata.CustomMetadataValue();
            instance1.field = 'MVEX__Object_API_Name__c';
            instance1.value = objectApiName;
            mdata.values.add(instance1);

            Metadata.DeployContainer container = new Metadata.DeployContainer();
            container.addMetadata(mdata);
            
            Metadata.Operations.enqueueDeployment(container, null);

            return 'success';
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e,'RecordManagersCmpController','saveMappingsNewFields' , e.getStackTraceString());
            return e.getMessage();
        }
    }

    /**
     * Method Name : getListingFieldsParent
     * @description : get listing fields parent.
     * @param objectApiName String value.
     */
    @AuraEnabled
    public static List<FieldDetails> getListingFieldsParent(String objectApiName) {

        try {
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
                fieldDetails.label = fieldDescribe.getLabel();
                fieldDetails.value = fieldDescribe.getName();
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
            ErrorHandler.insertErrorData(e, 'RecordManagersCmpController', 'getListingFieldsParent', 'Error while getting listing fields.');
            return null;
        }
    }
}