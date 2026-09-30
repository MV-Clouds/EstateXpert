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
    public static String createPortalRecords(String portalName) {
        try {
            MVEX__Portaldata__mdt portalMetaData = [SELECT MasterLabel, MVEX__Portal_Record__c, MVEX__Portal_Value__c FROM MVEX__Portaldata__mdt WHERE 
                                                        MVEX__Portal_Value__c = :portalName WITH USER_MODE LIMIT 1];

            Object jsonObject = JSON.deserializeUntyped(portalMetaData.MVEX__Portal_Record__c);
            if (jsonObject instanceof List<Object>) {
                List<Object> jsonList = (List<Object>) jsonObject;
                List<Map<String, Object>> jsonData = new List<Map<String, Object>>();
                for (Object item : jsonList) {
                    if (item instanceof Map<String, Object>) {
                        jsonData.add((Map<String, Object>) item);
                    } else {
                        ErrorHandler.insertErrorData(null, 'CreatePortalListingMappingRecords', 'createPortalRecords', 'Unexpected JSON structure for portal name - ' + portalName + ' at line number 34.');
                        return null;
                    }
                }

                List<MVEX__Portal_Listing_Mapping__c> newRecords = new List<MVEX__Portal_Listing_Mapping__c>();

                Map<String, String> stringMap = new Map<String, String>();
                
                for (Map<String, Object> recordData : jsonData) {
                    if (recordData.containsKey('MVEX__Listing_Field_API_Name__c') && recordData.get('MVEX__Listing_Field_API_Name__c') != null && recordData.containsKey('Name')) {
                        stringMap.put((String) recordData.get('MVEX__Listing_Field_API_Name__c'), (String) recordData.get('Name'));
                    }

                    MVEX__Portal_Listing_Mapping__c newRecord = new MVEX__Portal_Listing_Mapping__c();
                    
                    if (recordData.containsKey('Allowed_Field_Datatype__c')) {
                        newRecord.MVEX__Allowed_Field_Datatype__c = (String) recordData.get('Allowed_Field_Datatype__c');
                    }
                    if (recordData.containsKey('Data_Type__c')) {
                        newRecord.MVEX__Data_Type__c = (String) recordData.get('Data_Type__c');
                    }
                    if (recordData.containsKey('Listing_Field_API_Name__c')) {
                        newRecord.MVEX__Listing_Field_API_Name__c = (String) recordData.get('Listing_Field_API_Name__c');
                    }
                    if (recordData.containsKey('Portal_Field_Description__c')) {
                        newRecord.MVEX__Portal_Field_Description__c = (String) recordData.get('Portal_Field_Description__c');
                    }
                    if (recordData.containsKey('Portal_Field_Example__c')) {
                        newRecord.MVEX__Portal_Field_Example__c = (String) recordData.get('Portal_Field_Example__c');
                    }
                    if (recordData.containsKey('Portal_Name__c')) {
                        newRecord.MVEX__Portal_Name__c = (String) recordData.get('Portal_Name__c');
                    }
                    if (recordData.containsKey('Required__c')) {
                        newRecord.MVEX__Required__c = (Boolean) recordData.get('Required__c');
                    }
                    if (recordData.containsKey('Value_Mapping__c')) {
                        newRecord.MVEX__Value_Mapping__c = (String) recordData.get('Value_Mapping__c');
                    }
                    if (recordData.containsKey('Name')) {
                        newRecord.Name = (String) recordData.get('Name');
                    }
                    
                    newRecords.add(newRecord);
                }
                
                if (newRecords.size() > 0){
                    insert as user newRecords;
                }

                return JSON.serialize(stringMap);
            } else {
                ErrorHandler.insertErrorData(null, 'CreatePortalListingMappingRecords', 'createPortalRecords', 'Unexpected JSON structure for portal name - ' + portalName + ' at line number 94.');
                return null;
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'CreatePortalListingMappingRecords', 'createPortalRecords', 'Error while creating Portal_Listing_Mapping__c records for portal name - ' + portalName);
            return e.getMessage();
        }
    }
}