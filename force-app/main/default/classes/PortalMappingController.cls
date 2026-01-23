/**
* Class Name : PortalMappingController
* Test Class : PortalMappingControllerTest
* Created By : Karan Singh
* Last Modified Date : 24/12/2024
* Last Modified By : Karan Singh
* @description : Used in portalMappingComponent and portalMappingLandingPage LWC components
*/
public with sharing class PortalMappingController {

    /**
    * Wrapper Class Name : ObjectFieldsWrapper
    * @description : This Wrapper class used for method name getPortalRecords to return Portal__c object records.
    */
    public class ObjectFieldsWrapper {
        @AuraEnabled public List<PortalDetailWrapper> portalDetailsRecords;
        @AuraEnabled public List<Portal__c> portalRecords;
        @AuraEnabled public Boolean isXMLForPF;
    }
    
    /**
    * Wrapper Class Name : PortalDetailWrapper
    * @description : This Wrapper class used for method name getPortalRecords to return Portal__c object records.
    */
    public class PortalDetailWrapper {
        @AuraEnabled public String portalName;
        @AuraEnabled public String logoURL;
        @AuraEnabled public Integer recordCount;
    
        public PortalDetailWrapper(String portalName, String logoURL, Integer recordCount) {
            this.portalName = portalName;
            this.logoURL = logoURL;
            this.recordCount = recordCount;
        }
    }
    
    /**
    * Method Name : getPortalRecords
    * @description : Get all the records of Portal__c object.
    * @return List of Portal__c records.
    */
    @AuraEnabled
    public static ObjectFieldsWrapper getPortalRecords(){
        ObjectFieldsWrapper result = new ObjectFieldsWrapper();
        result.portalDetailsRecords = new List<PortalDetailWrapper>();
        result.portalRecords = new List<Portal__c>();
        result.isXMLForPF = false;
        try {
            Map<String, Integer> generatorCountMap = new Map<String, Integer>();
    
            List<PortalDetail__mdt> portalMetaRecords = [SELECT MasterLabel, Logo_URL__c FROM PortalDetail__mdt WITH USER_MODE ORDER BY MasterLabel LIMIT 100];

            List<Control_Center_Feature__mdt> controlCenterFeatureRecords = [SELECT isAvailable__c FROM Control_Center_Feature__mdt WHERE DeveloperName = 'Is_XML_For_PF' WITH USER_MODE LIMIT 1];
            if (controlCenterFeatureRecords.size() > 0 && controlCenterFeatureRecords[0].isAvailable__c) {
                result.isXMLForPF = true;
            }

            List<AggregateResult> portalRecordsGroupedByGenerator = [SELECT Generator__c, COUNT(Id) recordCount FROM Portal__c WITH USER_MODE
                                                                        GROUP BY Generator__c LIMIT 50000];
    
            for (AggregateResult ar : portalRecordsGroupedByGenerator) {
                String generator = (String) ar.get('MVEX__Generator__c');
                Integer count = (Integer) ar.get('recordCount');
                generatorCountMap.put(generator, count);
            }
    
            for (PortalDetail__mdt portalDetail : portalMetaRecords) {
                String masterLabel = portalDetail.MasterLabel == 'Property Finder' ? 'Propertyfinder' : portalDetail.MasterLabel;
                String logoURL = portalDetail.Logo_URL__c;
                Integer recordCount = generatorCountMap.containsKey(masterLabel) ? generatorCountMap.get(masterLabel) : 0;
    
                result.portalDetailsRecords.add(new PortalDetailWrapper(masterLabel, logoURL, recordCount));
            }
    
            result.portalRecords = [SELECT Id, Endpoint__c, Generator__c, Name, Is_Active__c FROM Portal__c WITH USER_MODE ORDER BY Name LIMIT 50000];
    
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'PortalMappingController', 'getPortalRecords', 'Error while fetching Portal__c records.');
        }
        return result;
    }    

    /**
    * Wrapper Class Name : FieldWrapper
    * @description : This Wrapper class used for method name getObjectFields to return Custom Metadata, Custom Setting and Listing fields datas.
    */
    public class FieldWrapper {
        @AuraEnabled
        public List<Map<String, String>> portalMetadataRecords { get; set; }
        @AuraEnabled
        public Set<String> blockfields { get; set; }
        @AuraEnabled
        public List<Map<String, String>> listingFields { get; set; }
    
        public FieldWrapper(List<Map<String, String>> portalMetadataRecords, Set<String> blockfields, List<Map<String, String>> listingFields) {
            this.portalMetadataRecords = portalMetadataRecords;
            this.blockfields = blockfields;
            this.listingFields = listingFields;
        }
    }    

    /**
    * Method Name : getObjectFields
    * @description : Method is used to return Listing object fields, Portal Custom Metadat records and List of Blocked fields for Portal and Listing field mapping.
    * @param portalName String value.
    * @return List of FieldWrapper.
    * Last Update Date : 06/06/2024
    * Updated By : Karan Singh
    * Change Description : Replaced the custom metadata with custom object for portal listing field mapping.
    */
    @AuraEnabled
    public static List<FieldWrapper> getObjectFields(String portalName, Boolean isXMLForPF) {
        try {
            List<FieldWrapper> result = new List<FieldWrapper>();

            List<Map<String, String>> fieldDetails = new List<Map<String, String>>();

            List<Portal_Listing_Mapping__c> portalListingMap ;

            if (portalName == 'Propertyfinder' && isXMLForPF) {
                portalListingMap = [SELECT Id, Name, Listing_Field_API_Name__c, Portal_Field_Description__c, Portal_Field_Example__c, Required__c, Allowed_Field_Datatype__c FROM Portal_Listing_Mapping__c WHERE Portal_Name__c = 'Propertyfinder XML' WITH USER_MODE ORDER BY Required__c DESC, Name ASC];
            } else if (portalName != null) {
                portalListingMap = [SELECT Id, Name, Listing_Field_API_Name__c, Portal_Field_Description__c, Portal_Field_Example__c, Required__c, Allowed_Field_Datatype__c FROM Portal_Listing_Mapping__c WHERE Portal_Name__c =: portalName WITH USER_MODE ORDER BY Required__c DESC, Name ASC];
            }

            sObject blockFields = getBlockedFields(portalName);

            Set<String> blockedFields = new Set<String>();
            if (blockFields != null && blockFields.get('MVEX__Fields_Name__c') != null) {
                blockedFields = new Set<String>(((String)blockFields.get('MVEX__Fields_Name__c')).split(';'));
            }

            Schema.DescribeSObjectResult describeResult = Schema.getGlobalDescribe().get('MVEX__Listing__c').getDescribe();
            Map<String, Schema.SObjectField> allFieldsMap = describeResult.fields.getMap();
            
            List<FieldInfo> fieldsInfoList = new List<FieldInfo>();
            
            for (Schema.SObjectField field : allFieldsMap.values()) {
                Schema.DescribeFieldResult fieldDescribe = field.getDescribe();
                fieldsInfoList.add(new FieldInfo(fieldDescribe.getLabel(), fieldDescribe.getName(), fieldDescribe.getType())); // Pass field data type here
            }
            
            fieldsInfoList.sort();
            
            for (FieldInfo fieldInfo : fieldsInfoList) {
                Map<String, String> fieldMap = new Map<String, String>();
                fieldMap.put('label', fieldInfo.label);
                fieldMap.put('apiName', fieldInfo.apiName);
                fieldMap.put('dataType', String.valueOf(fieldInfo.dataType));
                fieldDetails.add(fieldMap);
            }

            List<Map<String, String>> portalMetadataDetails = new List<Map<String, String>>();
            for (Portal_Listing_Mapping__c record : portalListingMap) {
                Map<String, String> metadataMap = new Map<String, String>();
                metadataMap.put('Id', (String)record.get('Id'));
                metadataMap.put('Name', (String)record.get('Name'));
                metadataMap.put('MVEX__Listing_Field_API_Name__c', (String)record.get('MVEX__Listing_Field_API_Name__c'));
                metadataMap.put('MVEX__Portal_Field_Description__c', (String)record.get('MVEX__Portal_Field_Description__c'));
                metadataMap.put('MVEX__Portal_Field_Example__c', (String)record.get('MVEX__Portal_Field_Example__c'));
                metadataMap.put('MVEX__Allowed_Field_Datatype__c', (String)record.get('MVEX__Allowed_Field_Datatype__c'));

                Boolean requiredField = (Boolean)record.get('MVEX__Required__c');
                metadataMap.put('MVEX__Required__c', requiredField == true ? String.valueOf(requiredField) : '');

                portalMetadataDetails.add(metadataMap);
            }

            result.add(new FieldWrapper(portalMetadataDetails, blockedFields, fieldDetails));

            return result;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'PortalMappingController', 'getObjectFields', 'Error while fetching Portal__c records.');
            return null;
        }
    }

    /**
    * Method Name : getBlockedFields
    * @description : Method is used to get the blocked fields.
    * @param portalName: Name of the Portal.
    * @return sObject: Returns the custom setting record of the specified type and name.
    */
    public static sObject getBlockedFields(String portalName) {
        try {
            switch on portalName {
                when 'Propertyfinder' {
                    return BFFPF__c.getOrgDefaults();
                }
                when 'Zoopla' {
                    return BFFZ__c.getOrgDefaults();
                }
                when 'Bayut' {
                    return BFFB__c.getOrgDefaults();
                }
                when 'Rightmove' {
                    return BFFR__c.getOrgDefaults();
                }
                when 'Rightmove Overseas' {
                    return BFFRO__c.getOrgDefaults();
                }
                when 'Dubizzle' {
                    return BFFB__c.getOrgDefaults();
                }
                when else {
                    return null;
                }
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'PortalMappingController', 'getObjectFields', 'Error while fetching Portal__c records.');
            return null;
        }
    }

    /**
    * Method Name : compareTo
    * @description : Compares this FieldInfo object with the specified FieldInfo object for order based on the label property.
    * @return Integer: A negative integer, zero, or a positive integer if the label of this FieldInfo object is less than, equal to, or greater than the label of the specified FieldInfo object, respectively.
    */
    public class FieldInfo implements Comparable {
        public String label;
        public String apiName;
        public Schema.DisplayType dataType; // Change dataType variable type
        
        public FieldInfo(String label, String apiName, Schema.DisplayType dataType) { // Update constructor to include dataType of type Schema.DisplayType
            this.label = label;
            this.apiName = apiName;
            this.dataType = dataType;
        }
        
        public Integer compareTo(Object other) {
            FieldInfo otherFieldInfo = (FieldInfo) other;
            return this.label.compareTo(otherFieldInfo.label);
        }
    }

    /**
    * Method Name : saveChangedFields
    * @description : Method is used to save the Portal and Listing field mapping in custom metadata records.
    * @param changedFields List<Map<String, String>> value.
    * @param jsonList String value.
    * @param portalName String value.
    * @return deploy request Id.
    * Last Update Date : 07/06/2024
    * Updated By : Karan Singh
    * Change Description : Made the required changes for saving the PortalListingMapping records updates.
    */
    @AuraEnabled
    public static string saveChangedFields(List<Map<String, String>> changedFields, String jsonList, String portalId) {
        try {
            List<Portal_Listing_Mapping__c> recordsToUpdate = new List<Portal_Listing_Mapping__c>();

            for (Map<String, String> changedField : changedFields) {
                Portal_Listing_Mapping__c record = new Portal_Listing_Mapping__c();
                record.Id = changedField.get('Id');
                record.Listing_Field_API_Name__c = changedField.get('MVEX__Listing_Field_API_Name__c');

                recordsToUpdate.add(record);
            }

            if (!recordsToUpdate.isEmpty()) {
                update as user recordsToUpdate;

                List<Portal__c> portalToUpdate = [SELECT Id, Field_Mapping__c, Generator__c FROM Portal__c WHERE Id =: portalId WITH USER_MODE LIMIT 1];

                if (!portalToUpdate.isEmpty()) {
                    portalToUpdate[0].Field_Mapping__c = jsonList;
                    update as user portalToUpdate;
                } else {
                    return 'Portal not found.';
                }
            } else {
                return 'No changes to save.';
            }

            return 'Success';
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'PortalMappingController', 'saveChangedFields', 'Error while saving Portal_Listing_Mapping__c records.');
            return null;
        }
    }

    /**
    * Method Name : portalAction
    * @description : Method is used to active, deactive and delete the portal records.
    * @param portalId String value.
    * @param actionName String value.
    * @return status.
    */
    @AuraEnabled
    public static string portalAction(String portalId, String actionName) {
        try {
            List<Portal__c> portalAct = [SELECT Id, Is_Active__c FROM Portal__c WHERE Id =: portalId WITH USER_MODE];

            if (portalAct.isEmpty()) {
                return 'Portal not found.';
            }

            Portal__c portal = portalAct[0];
            
            switch on actionName {
                when 'deactivate' {
                    return updatePortalStatus(portal, false, 'deactivated');
                }
                when 'activate' {
                    return updatePortalStatus(portal, true, 'activated');
                }
                when 'delete' {
                    return deletePortal(portal);
                }
                when else {
                    return 'Invalid action.';
                }
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'PortalMappingController', 'portalAction', 'Error while performing Portal__c record actions.');
            return null;
        }
    }

    /**
    * Method Name : updatePortalStatus
    * @description : Method is used to update the Is_Active__c field value.
    * @param portal Portal__c value.
    * @param status Boolean value.
    * @param action String value.
    * @return update status.
    */
    private static String updatePortalStatus(Portal__c portal, Boolean status, String action) {
        try {
            portal.Is_Active__c = status;
            update as user portal;
            return action;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'PortalMappingController', 'updatePortalStatus', 'Error while updating Portal__c record.');
            return null;
        }

    }

    /**
    * Method Name : updatePortalStatus
    * @description : Method is used for deleting the Portal__c object record.
    * @param portal Portal__c value.
    * @return delete status.
    */
    private static String deletePortal(Portal__c portal) {
        try {
            delete as user portal;
            return 'deleted';
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'PortalMappingController', 'deletePortal', 'Error while deleting Portal__c record.');
            return null;
        }

    }

    /**
    * Wrapper Class Name : PropertyPortalWrapper
    * @description : This Wrapper class used for method name savePropertyPortalRecord.
    */
    public class PropertyPortalWrapper {
        @AuraEnabled public String name;
        @AuraEnabled public String portalname;
        @AuraEnabled public String getPortalIconUrl;
        @AuraEnabled public String certificate;
        @AuraEnabled public String branch_reference;
        @AuraEnabled public String branch_name;
        @AuraEnabled public String street_name;
        @AuraEnabled public String town_or_city;
        @AuraEnabled public String postal_code;
        @AuraEnabled public String country_code;
        @AuraEnabled public String is_test_portal;
        @AuraEnabled public String differentiator_values;
        @AuraEnabled public String xml_site;
        @AuraEnabled public Boolean isXMLForPF = false;
    }

    /**
    * Method Name : savePropertyPortalRecord
    * @description : Method is used for deleting the Portal__c object record.
    * @param portalWrapper propertyPortalWrapper value.
    * @param portalName String value.
    */
    @AuraEnabled
    public static String savePropertyPortalRecord(String portalWrapper, String portalName) {
        try {
            List<String> portalsName = new List<String>{'Propertyfinder', 'Bayut', 'Dubizzle'};
            
            if(portalName == null || portalName == '') {
                return 'Portal name is missing.';
            }
            String escapePortalName = String.escapeSingleQuotes(portalName);

            PropertyPortalWrapper wrapper = (PropertyPortalWrapper)JSON.deserialize(portalWrapper, PropertyPortalWrapper.class);
            List<Portal_Listing_Mapping__c> portalListingMaps = [SELECT Id, Listing_Field_API_Name__c, Name FROM Portal_Listing_Mapping__c WHERE Portal_Name__c =: escapePortalName AND Listing_Field_API_Name__c != null WITH USER_MODE];
            Map<String, String> jsonBodyMap = new Map<String, String>();
            String jsonBody = '';
            if(!portalListingMaps.isEmpty()) {
                for (Portal_Listing_Mapping__c mapping : portalListingMaps) {
                    jsonBodyMap.put(mapping.Listing_Field_API_Name__c, mapping.Name);
                }
                jsonBody = JSON.serialize(jsonBodyMap);
            } else {
                jsonBody = CreatePortalListingMappingRecords.createPortalRecords(portalName, wrapper.isXMLForPF);
            }

            String portalId;
            Portal__c newportal = new Portal__c();
            newportal.Name = wrapper.name;
            newportal.Endpoint__c = wrapper.getPortalIconUrl;
            newportal.Is_Active__c = true;
            newportal.Portal_Configuration__c = portalWrapper;
            newportal.Field_Mapping__c = jsonBody;
            newportal.Generator__c = wrapper.portalname == 'Property Finder' ? 'Propertyfinder' : wrapper.portalname;
            
            insert as user newportal;
            portalId = newportal.Id;

            if (portalsName.contains(newportal.Generator__c)) {
                updateNewlyCreatedPortalRecord(newportal.Generator__c, newportal.Id, wrapper.xml_site);
            }

            if (wrapper.portalname == 'Zoopla') {
                ZooplaIntegrationController.zooplaCreateAndUpdateBranch(portalWrapper, portalId);
            }

            return 'success';
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'PortalMappingController', 'savePropertyPortalRecord', 'Error while saving Portal__c record.');
            return e.getMessage();
        }
    }

    /**
    * Method Name : updatePropertyPortalRecord
    * @description : Method is used for deleting the Portal__c object record.
    * @param portalWrapper propertyPortalWrapper value.
    * @param portalName String value.
    */
    @AuraEnabled
    public static String updatePropertyPortalRecord(String portalWrapper, String portalName, String portalId) {
        try {
            List<String> portalsName = new List<String>{'Propertyfinder', 'Bayut', 'Dubizzle'};

            if(portalName == null || portalName == '') {
                return 'Portal name is missing.';
            }

            PropertyPortalWrapper wrapper = (PropertyPortalWrapper)JSON.deserialize(portalWrapper, PropertyPortalWrapper.class);
            
            Portal__c newportal = new Portal__c();
            newportal.Id = portalId;
            newportal.Name = wrapper.name;
            newportal.Endpoint__c = wrapper.getPortalIconUrl;
            newportal.Portal_Configuration__c = portalWrapper;
            newportal.Generator__c = wrapper.portalname == 'Property Finder' ? 'Propertyfinder' : wrapper.portalname;
            
            update as user newportal;

            if (portalsName.contains(newportal.Generator__c)) {
                updateNewlyCreatedPortalRecord(newportal.Generator__c, newportal.Id, wrapper.xml_site);
            }

            if (wrapper.portalname == 'Zoopla') {
                ZooplaIntegrationController.zooplaCreateAndUpdateBranch(portalWrapper, portalId);
            }

            return 'success';
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'PortalMappingController', 'savePropertyPortalRecord', 'Error while saving Portal__c record.');
            return e.getMessage();
        }
    }

    public static void updateNewlyCreatedPortalRecord(String portalName, String portalId, String xmlSite) {
        try {
            Portal__c portalRecord = new Portal__c();
            portalRecord.Id = portalId;
    
            if (portalName == 'Propertyfinder') {
                portalRecord.XML_Feed_URL__c = xmlSite + 'MVEX__XMLFeedForPF?Id=' + portalId;
            } else if (portalName == 'Bayut') {
                portalRecord.XML_Feed_URL__c = xmlSite + 'MVEX__XMLFeed?Id=' + portalId + '&isByt=true';
            } else if (portalName == 'Dubizzle') {
                portalRecord.XML_Feed_URL__c = xmlSite + 'MVEX__XMLFeed?Id=' + portalId + '&isDbzl=true';
            }
    
            update as user portalRecord;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'PortalMappingController', 'updateNewlyCreatedPortalRecord', 'Error while updating XML_Feed_URL__c for portal');
        }
    }
    

    /**
    * Wrapper Class Name : FieldList
    * @description : This Wrapper class used for method name getAllCustomFields.
    */
    public class FieldList {
        @AuraEnabled
        public String label { get; set; }
        @AuraEnabled
        public String value { get; set; }
        
        public FieldList(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }
    
    /**
    * Wrapper Class Name : SiteInfoWrapper
    * @description : This Wrapper class used for site info like site url and name.
    */
    public class SiteInfoWrapper {
        @AuraEnabled
        public List<FieldList> sitesDetails { get; set; }
        @AuraEnabled
        public List<FieldList> customFields { get; set; }
        @AuraEnabled
        public List<FieldList> fieldsValue { get; set; }
        
        public SiteInfoWrapper() {
            this.sitesDetails = new List<FieldList>();
            this.customFields = new List<FieldList>();
            this.fieldsValue = new List<FieldList>();
        }
    }

    /**
    * Method Name : getAllCustomFields
    * @description : Method is used for fetching all the custom fields from the Listing__c object.
    * @return List<FieldList> value.
    */
    @AuraEnabled
    public static SiteInfoWrapper getAllCustomFields() {
        SiteInfoWrapper siteInfoWrapper = new SiteInfoWrapper();
        
        try {
            Set<Id> guestUserIds = new Set<Id>();
    
            List<Site> sites = [SELECT Id, GuestUserId, Name, Subdomain, UrlPathPrefix FROM Site WITH USER_MODE LIMIT 10];

            if (!sites.isEmpty()) {
                for (Site site : sites) {
                    guestUserIds.add(site.Id);
                }
                
                if (!guestUserIds.isEmpty()) {
                    List<SiteDetail> siteDetails = [SELECT SecureURL, DurableId FROM SiteDetail WHERE DurableId IN :guestUserIds WITH USER_MODE];
                    
                    Map<Id, String> siteUrlMap = new Map<Id, String>();
                    for (SiteDetail siteDetail : siteDetails) {
                        siteUrlMap.put(siteDetail.DurableId, siteDetail.SecureURL);
                    }

                    for (Site site : sites) {
                        if (siteUrlMap.containsKey(site.Id)) {
                            Map<String, String> resultMap = new Map<String, String>();
                            String siteLabel = site.Name;
                            String siteUrl = siteUrlMap.get(site.Id);
                            siteInfoWrapper.sitesDetails.add(new FieldList(siteLabel, siteUrl));
                        }
                    }
                }
            }
    
            Schema.DescribeSObjectResult describeResult = Schema.getGlobalDescribe().get('MVEX__Listing__c').getDescribe();
            Map<String, Schema.SObjectField> fieldsMap = describeResult.fields.getMap();
    
            for (Schema.SObjectField field : fieldsMap.values()) {
                Schema.DescribeFieldResult fieldDescribe = field.getDescribe();
                if (fieldDescribe.isCustom()) {
                    String fieldLabel = fieldDescribe.getLabel();
                    String fieldApiName = fieldDescribe.getName();
                    siteInfoWrapper.customFields.add(new FieldList(fieldLabel, fieldApiName));
                }
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'PortalMappingController', 'getAllCustomFields', 'Error while fetching custom fields from Listing__c object.');
        }
        
        return siteInfoWrapper;
    }

    /**
    * Method Name : getAllEditDatas
    * @param portalId to stored the portal Id.
    * @description : Method is used for fetching all the editable fields from the Listing__c object.
    * @return SiteInfoWrapper.
    */
    @AuraEnabled
    public static SiteInfoWrapper getAllEditDatas(String portalId) {
        SiteInfoWrapper siteInfoWrapper = new SiteInfoWrapper();
        
        try {
            Set<Id> guestUserIds = new Set<Id>();
    
            List<Site> sites = [SELECT Id, GuestUserId, Name, Subdomain, UrlPathPrefix FROM Site WITH USER_MODE LIMIT 1000];

            if (!sites.isEmpty()) {
                for (Site site : sites) {
                    guestUserIds.add(site.Id);
                }
                
                if (!guestUserIds.isEmpty()) {
                    List<SiteDetail> siteDetails = [SELECT SecureURL, DurableId FROM SiteDetail WHERE DurableId IN :guestUserIds WITH USER_MODE];
                    
                    Map<Id, String> siteUrlMap = new Map<Id, String>();
                    for (SiteDetail siteDetail : siteDetails) {
                        siteUrlMap.put(siteDetail.DurableId, siteDetail.SecureURL);
                    }

                    for (Site site : sites) {
                        if (siteUrlMap.containsKey(site.Id)) {
                            Map<String, String> resultMap = new Map<String, String>();
                            String siteLabel = site.Name;
                            String siteUrl = siteUrlMap.get(site.Id);
                            siteInfoWrapper.sitesDetails.add(new FieldList(siteLabel, siteUrl));
                        }
                    }
                }
            }
    
            Schema.DescribeSObjectResult describeResult = Schema.getGlobalDescribe().get('MVEX__Listing__c').getDescribe();
            Map<String, Schema.SObjectField> fieldsMap = describeResult.fields.getMap();
    
            for (Schema.SObjectField field : fieldsMap.values()) {
                Schema.DescribeFieldResult fieldDescribe = field.getDescribe();
                if (fieldDescribe.isCustom()) {
                    String fieldLabel = fieldDescribe.getLabel();
                    String fieldApiName = fieldDescribe.getName();
                    siteInfoWrapper.customFields.add(new FieldList(fieldLabel, fieldApiName));
                }
            }

            List<Portal__c> portalData = [SELECT Id, Portal_Configuration__c, Generator__c FROM Portal__c WHERE Id =: portalId WITH USER_MODE LIMIT 1];

            if (!portalData.isEmpty()) {
                String fieldMappingJson = portalData[0].Portal_Configuration__c;
                Map<String, String> fieldMappingMap = (Map<String, String>) JSON.deserialize(fieldMappingJson, Map<String, String>.class);
                
                for (String apiName : fieldMappingMap.keySet()) {
                    String value = fieldMappingMap.get(apiName);
                    siteInfoWrapper.fieldsValue.add(new FieldList(apiName, value));
                }
            }

        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'PortalMappingController', 'getAllCustomFields', 'Error while fetching custom fields from Listing__c object.');
        }
        
        return siteInfoWrapper;
    }

    /**
    * Wrapper Class Name : ListingResponse
    * @description : This Wrapper class used for method name getXMLFeedListingsData.
    */
    public class ListingResponse {
        @AuraEnabled
        public String status;
        @AuraEnabled
        public String message;
        @AuraEnabled
        public List<Map<String, Object>> data;
    }

    /**
    * Method Name : getXMLFeedListingsData
    * @param portalId to stored the portal Id.
    * @description : Used to get listing data from XML Feed.
    * @return ListingResponse.
    */
    @AuraEnabled
    public static ListingResponse getXMLFeedListingsData(String portalId) {
        ListingResponse response = new ListingResponse();
        try {
            Set<Id> listingIds = new Set<Id>();

            List<PortalListing__c> portalListings = [SELECT Id, Listing__c, Portal__c FROM PortalListing__c WHERE Portal__c =: portalId AND SystemIsActive__c = True WITH USER_MODE];

            if (portalListings.isEmpty()) {
                response.status = 'Failed';
                response.message = 'No Portal Listings Data found.';
                return response;
            }

            for (PortalListing__c portalList : portalListings) {
                if (portalList.Listing__c != null) {
                    listingIds.add(portalList.Listing__c);
                }
            }

            List<Listing__c> properties = [SELECT Id, Name, Broker_s_Listing_ID__c, Listing_Type__c FROM Listing__c 
                                            WHERE Id IN :listingIds WITH USER_MODE ORDER BY Name ASC];
            
            // Prepare response
            List<Map<String, Object>> resultData = new List<Map<String, Object>>();
            
            for (Listing__c property : properties) {
                Map<String, Object> resultItem = new Map<String, Object>();
                resultItem.put('id', property.Id);
                resultItem.put('name', property.Name);
                resultItem.put('listing_reference', property.Broker_s_Listing_ID__c);
                resultItem.put('listing_type', property.Listing_Type__c);
                resultData.add(resultItem);
            }
            
            response.status = 'Success';
            response.data = resultData;

            return response;
            
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'PortalMappingController', 'getXMLFeedListingsData', 'Error while getting listing list.');
            response.status = 'Failed';
            response.message = e.getMessage();
            return response;
        }
    }
    
}