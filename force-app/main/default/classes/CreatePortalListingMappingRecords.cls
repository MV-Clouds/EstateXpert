/**
* Class Name : CreatePortalListingMappingRecords
* Test Class : CreatePortalListingMappingRecordsTest
* Created By : Karan Singh
* Last Modified Date : 09/09/2024
* Last Modified By : Karan Singh
* @description : Used in portalMappingComponent and portalMappingLandingPage LWC components
*/
public with sharing class CreatePortalListingMappingRecords {
    
    /**
    * Method Name : createPortalRecords
    * @param portalName - Name of the portal.
    * @description : Create records of Portal_Listing_Mapping__c object.
    * @return List of Portal_Listing_Mapping__c records.
    */
    public static String createPortalRecords(String portalName, Boolean isXMLForPF) {
        try {
            Portaldata__mdt portalMetaData = new Portaldata__mdt();
            if (portalName == 'Propertyfinder' && isXMLForPF) {
                portalMetaData = [SELECT MasterLabel, Portal_Record__c, Portal_Value__c FROM Portaldata__mdt WHERE Portal_Value__c = 'Propertyfinder XML' WITH USER_MODE LIMIT 1];
            } else {
                portalMetaData = [SELECT MasterLabel, Portal_Record__c, Portal_Value__c FROM Portaldata__mdt WHERE Portal_Value__c = :portalName WITH USER_MODE LIMIT 1];
            }

            Object jsonObject = JSON.deserializeUntyped(portalMetaData.Portal_Record__c);
            if (jsonObject instanceof List<Object>) {
                List<Object> jsonList = (List<Object>) jsonObject;
                List<Map<String, Object>> jsonData = new List<Map<String, Object>>();
                for (Object item : jsonList) {
                    if (item instanceof Map<String, Object>) {
                        jsonData.add((Map<String, Object>) item);
                    } else {
                        throw new TypeException('Unexpected JSON structure.');
                    }
                }

                List<Portal_Listing_Mapping__c> newRecords = new List<Portal_Listing_Mapping__c>();

                Map<String, String> stringMap = new Map<String, String>();
                
                for (Map<String, Object> recordData : jsonData) {
                    if (recordData.containsKey('Listing_Field_API_Name__c') && recordData.get('Listing_Field_API_Name__c') != null && recordData.containsKey('Name')) {
                        stringMap.put((String) recordData.get('Listing_Field_API_Name__c'), (String) recordData.get('Name'));
                    }

                    Portal_Listing_Mapping__c newRecord = new Portal_Listing_Mapping__c();
                    
                    if (recordData.containsKey('Allowed_Field_Datatype__c')) {
                        newRecord.Allowed_Field_Datatype__c = (String) recordData.get('Allowed_Field_Datatype__c');
                    }
                    if (recordData.containsKey('Data_Type__c')) {
                        newRecord.Data_Type__c = (String) recordData.get('Data_Type__c');
                    }
                    if (recordData.containsKey('Listing_Field_API_Name__c')) {
                        newRecord.Listing_Field_API_Name__c = (String) recordData.get('Listing_Field_API_Name__c');
                    }
                    if (recordData.containsKey('Portal_Field_Description__c')) {
                        newRecord.Portal_Field_Description__c = (String) recordData.get('Portal_Field_Description__c');
                    }
                    if (recordData.containsKey('Portal_Field_Example__c')) {
                        newRecord.Portal_Field_Example__c = (String) recordData.get('Portal_Field_Example__c');
                    }
                    if (recordData.containsKey('Portal_Name__c')) {
                        if (portalName == 'Propertyfinder' && isXMLForPF) {
                            newRecord.Portal_Name__c = 'Propertyfinder XML';
                        } else {
                            newRecord.Portal_Name__c = (String) recordData.get('Portal_Name__c');
                        }
                    }
                    if (recordData.containsKey('Required__c')) {
                        newRecord.Required__c = (Boolean) recordData.get('Required__c');
                    }
                    if (recordData.containsKey('Value_Mapping__c')) {
                        newRecord.Value_Mapping__c = (String) recordData.get('Value_Mapping__c');
                    }
                    if (recordData.containsKey('Name')) {
                        newRecord.Name = (String) recordData.get('Name');
                    }
                    
                    newRecords.add(newRecord);
                }
                
                if (newRecords.size() > 0){
                    insert as user newRecords;

                    createBlockFieldsRecord(portalName);
                }

                return JSON.serialize(stringMap);
            } else {
                throw new TypeException('Unexpected JSON structure.');
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'CreatePortalListingMappingRecords', 'createPortalRecords', 'Error while creating Portal_Listing_Mapping__c records for portal name - ' + portalName);
            return e.getMessage();
        }
    }

    /**
    * Method Name : createBlockFieldsRecord
    * @param portalName - Name of the portal.
    * @description : Method is used to create the block fields record.
    */
    public static void createBlockFieldsRecord(String portalName) {

        try {
            if (portalName == 'Propertyfinder') {

                BFFPF__c propertyFinderSettings = BFFPF__c.getOrgDefaults();
                if (propertyFinderSettings == null) {
                    propertyFinderSettings = new BFFPF__c();
                    propertyFinderSettings.SetupOwnerId = UserInfo.getOrganizationId();
                }
                propertyFinderSettings.Fields_Name__c = 'Id;MVEX__Property__c;LastModifiedDate;MVEX__Listing_Type__c;MVEX__Rent_Frequency__c';
                    
                upsert as user propertyFinderSettings;

            } else if (portalName == 'Zoopla') {

                BFFZ__c zooplaSettings = BFFZ__c.getOrgDefaults();
                if (zooplaSettings == null) {
                    zooplaSettings = new BFFZ__c();
                    zooplaSettings.SetupOwnerId = UserInfo.getOrganizationId();
                }
                zooplaSettings.Fields_Name__c = 'Id;MVEX__Property__c';
                
                upsert as user zooplaSettings;

            } else if (portalName == 'Bayut') {

                BFFB__c bayutSettings = BFFB__c.getOrgDefaults();
                if (bayutSettings == null) {
                    bayutSettings = new BFFB__c();
                    bayutSettings.SetupOwnerId = UserInfo.getOrganizationId();
                }
                bayutSettings.Fields_Name__c = 'Id;MVEX__Property__c;LastModifiedDate';

                upsert as user  bayutSettings;
                    
            } else if (portalName == 'Rightmove') {

                BFFR__c rightmoveSettings = BFFR__c.getOrgDefaults();
                if (rightmoveSettings == null) {
                    rightmoveSettings = new BFFR__c();
                    rightmoveSettings.SetupOwnerId = UserInfo.getOrganizationId();
                }
                rightmoveSettings.Fields_Name__c = 'Id;MVEX__Property__c;MVEX__Listing_Type__c';

                upsert as user rightmoveSettings;

            } else if (portalName == 'Rightmove Overseas') {

                BFFRO__c rightmoveOverseasSettings = BFFRO__c.getOrgDefaults();
                if (rightmoveOverseasSettings == null) {
                    rightmoveOverseasSettings = new BFFRO__c();
                    rightmoveOverseasSettings.SetupOwnerId = UserInfo.getOrganizationId();
                }
                rightmoveOverseasSettings.Fields_Name__c = 'Id;MVEX__Property__c';

                upsert as user rightmoveOverseasSettings;

            } else if (portalName == 'Dubizzle') {
                
                BFFB__c bayutSettings = BFFB__c.getOrgDefaults();
                if (bayutSettings == null) {
                    bayutSettings = new BFFB__c();
                    bayutSettings.SetupOwnerId = UserInfo.getOrganizationId();
                }
                bayutSettings.Fields_Name__c = 'Id;MVEX__Property__c;LastModifiedDate';

                upsert as user bayutSettings;
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'CreatePortalListingMappingRecords', 'createBlockFieldsRecord', 'Error while creating the block fields record for portal name - ' + portalName);
        }
    }
}