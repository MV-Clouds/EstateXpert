/**
* Class Name : ZooplaJSONController
* Created By : Karan Singh
* Last Modified Date : 25/06/2024
* Last Modified By : Karan Singh
* @description : Used to create input data for Zoopla.
*/
public with sharing class ZooplaJSONController {

    /**
    * Method Name : createInputData
    * @param finalMapping - Map<String, Object>
    * @param mediaList - List<Property_File__c>
    * @return String
    * @description : Used to create input data for Zoopla.
    */
    public static String createInputData(Map<String, Object> finalMapping, List<Property_File__c> mediaList) {
        try {
            Map<String, Object> inputData = new Map<String, Object>();
    
            List<Portal_Listing_Mapping__c> portalListing = [SELECT Id, Name, Value_Mapping__c, Data_Type__c FROM Portal_Listing_Mapping__c WHERE Portal_Name__c = 'Zoopla' WITH USER_MODE];
        
            Map<String, String> valueMappingMap = new Map<String, String>();
            Map<String, String> dataTypeMap = new Map<String, String>();
            for (Portal_Listing_Mapping__c mapping : portalListing) {
                valueMappingMap.put(mapping.Name, mapping.Value_Mapping__c);
                dataTypeMap.put(mapping.Name, mapping.Data_Type__c);
            }
        
            for (String fieldName : finalMapping.keySet()) {
                String valueMapping = valueMappingMap.containsKey(fieldName) ? valueMappingMap.get(fieldName) : null;
                String dataType = dataTypeMap.containsKey(fieldName) ? dataTypeMap.get(fieldName) : null;
                Object value = conditionallyChangeValue(dataType, finalMapping.get(fieldName), valueMapping);
                processValue(inputData, fieldName, value);
            }
        
            List<Map<String, Object>> content = new List<Map<String, Object>>();
            for (Property_File__c mediaItem : mediaList) {
                Map<String, Object> mediaMap = new Map<String, Object>();
                String mediaURL = String.isNotBlank(mediaItem.ExternalLink__c) ? mediaItem.ExternalLink__c : mediaItem.BaseUrl__c;
                mediaMap.put('url', mediaURL);
                mediaMap.put('type', urlType(mediaItem.Tags__c));
                content.add(mediaMap);
            }
            inputData.put('content', content);
        
            String jsonBODY = JSONController.createJSON(inputData);
        
            return jsonBODY;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'ZooplaJSONController', 'createInputData', 'Error while creating input data for Zoopla.');
            return '{"status":"fail","reason":"Error while creating JSON Body: ' + e.getMessage() + '"}';
        }
    }
    
    /**
    * Method Name : processValue
    * @param parentMap - Map<String, Object>
    * @param key - String
    * @param value - Object
    * @return String
    * @description : Used to process value for Zoopla.
    */
    public static void processValue(Map<String, Object> parentMap, String key, Object value) {
        try {
            if (key.contains('.')) {
                String[] fieldNames = key.split('\\.');
                Map<String, Object> currentMap = parentMap;
                for (Integer i = 0; i < fieldNames.size(); i++) {
                    String field = fieldNames[i];
                    if (i == fieldNames.size() - 1) {
                        if (isArrayField(field)) {
                            if (!currentMap.containsKey(field)) {
                                currentMap.put(field, new List<Object>());
                            }
                            ((List<Object>) currentMap.get(field)).add(value);
                        } else {
                            currentMap.put(field, value);
                        }
                    } else {
                        if (isArrayField(field)) {
                            if (!currentMap.containsKey(field)) {
                                currentMap.put(field, new List<Object>());
                            }
                            if (((List<Object>) currentMap.get(field)).isEmpty()) {
                                Map<String, Object> nestedMap = new Map<String, Object>();
                                ((List<Object>) currentMap.get(field)).add(nestedMap);
                                currentMap = nestedMap;
                            } else {
                                currentMap = (Map<String, Object>) ((List<Object>) currentMap.get(field)).get(0);
                            }
                        } else {
                            if (!currentMap.containsKey(field) || !(currentMap.get(field) instanceof Map<String, Object>)) {
                                currentMap.put(field, new Map<String, Object>());
                            }
                            currentMap = (Map<String, Object>) currentMap.get(field);
                        }
                    }
                }
            } else {
                if (isArrayField(key)) {
                    if (!parentMap.containsKey(key)) {
                        parentMap.put(key, new List<Object>());
                    }
                    ((List<Object>) parentMap.get(key)).add(value);
                } else {
                    parentMap.put(key, value);
                }
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'ZooplaJSONController', 'processValue', 'Error while processing value for Zoopla.');
        }
    }
    
    /**
    * Method Name : urlType
    * @param type - String
    * @return String
    * @description : Used to get url type for Zoopla.
    */
    public static String urlType(String type) {
        switch on type {
            when '360tour' {
                return 'virtual_tour';
            }
            when 'Floorplan' {
                return 'floor_plan';
            }
            when 'Virtual Tour' {
                return 'virtual_tour';
            }
            when else {
                return 'image';
            }
        }
    }

    /**
    * Method Name : conditionallyChangeValue
    * @param dataType - String
    * @param value - Object
    * @param valueMapping - String
    * @return Object
    * @description : Used to conditionally change value for Rightmove.
    */
    public static Object conditionallyChangeValue(String dataType, Object value, String valueMapping) {
        try {
            if (value == null) {
                return null;
            }
            
            Map<String, String> valueMap = new Map<String, String>();
            if (valueMapping != null && valueMapping != '') {
                valueMapping = valueMapping.replaceAll('\\r\\n|\\r|\\n', '');
                for (String mapping : valueMapping.split(',')) {
                    List<String> keyValue = mapping.split('=>');
                    if (keyValue.size() == 2) {
                        valueMap.put(keyValue[0].trim(), keyValue[1].trim());
                    }
                }
            }

            if (value instanceof String && valueMap.containsKey((String) value)) {
                value = valueMap.get((String) value);
            }

            if (dataType != null) {
                if (dataType.equalsIgnoreCase('integer')) {
                    if (value instanceof String) {
                        return Integer.valueOf((String) value);
                    } else if (value instanceof Decimal) { 
                        return ((Decimal) value).intValue();
                    } else {
                        return (Integer) value;
                    }
                } else if (dataType.equalsIgnoreCase('boolean')) {
                    if (value instanceof String) {
                        return Boolean.valueOf((String) value);
                    } else {
                        return (Boolean) value;
                    }
                } else if (dataType.equalsIgnoreCase('datetime')) {
                    if (value instanceof String) {
                        return Datetime.valueOfGmt((String) value).format('yyyy-MM-dd\'T\'HH:mm:ss');
                    } else {
                        return ((Datetime) value).format('yyyy-MM-dd\'T\'HH:mm:ss');
                    }
                } else if (dataType.equalsIgnoreCase('date')) {
                    if (value instanceof Datetime) {
                        return ((Datetime) value).format('yyyy-MM-dd');
                    } else {
                        return DateTime.newInstance((Date) value, Time.newInstance(0, 0, 0, 0)).format('yyyy-MM-dd');
                    }
                } else {
                    return String.valueOf(value);
                }
            } else {
                return value;
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'ZooplaJSONController', 'conditionallyChangeValue', 'Error while conditionally changing value for Zoopla and value is ' + value);
            return value;
        }
    }
    
    /**
    * Method Name : isArrayField
    * @param fieldName - String
    * @return Boolean
    * @description : Used to check if field is array field for Zoopla.
    */
    public static Boolean isArrayField(String fieldName) {
        switch on fieldName {
            when 'accessibility' {
                return true;
            }
            when 'bills_included' {
                return true;
            }
            when 'broadband_supply' {
                return true;
            }
            when 'building_safety_issues' {
                return true;
            }
            when 'buyer_incentives' {
                return true;
            }
            when 'commercial_use_classes' {
                return true;
            }
            when 'connected_utilities' {
                return true;
            }
            when 'construction_materials' {
                return true;
            }
            when 'detailed_description' {
                return true;
            }
            when 'electricity_supply' {
                return true;
            }
            when 'feature_list' {
                return true;
            }
            when 'floor_levels' {
                return true;
            }
            when 'heating_source' {
                return true;
            }
            when 'outside_space' {
                return true;
            }
            when 'parking' {
                return true;
            }
            when 'sewerage_supply' {
                return true;
            }
            when 'water_supply' {
                return true;
            }
            when 'sources_of_flooding' {
                return true;
            }
            when else {
                return false;
            }
        }
    }
}