/**
* Class Name : RightmoveJSONController
* Created By : Karan Singh
* Last Modified Date : 25/06/2024
* Last Modified By : Karan Singh
* @description : Used to build property info for Rightmove.
*/
public with sharing class RightmoveJSONController {
    
    /**
    * Method Name : buildJSON
    * @param fieldMap - Map<String, Object>
    * @param mediaList - List<Property_File__c>
    * @return String
    * @description : Used to build JSON for Rightmove.
    */
    public static String buildJSON(Map<String, Object> fieldMap, List<Property_File__c> mediaList, String portalName) {
        try {
            String escapedPortalName = String.escapeSingleQuotes(portalName);

            Map<String, Object> jsonMap = new Map<String, Object>();
        
            List<Portal_Listing_Mapping__c> portalListing = [SELECT Id, Name, Value_Mapping__c, Data_Type__c FROM Portal_Listing_Mapping__c WHERE Portal_Name__c =: escapedPortalName WITH USER_MODE];

            Map<String, String> valueMappingMap = new Map<String, String>();
            Map<String, String> dataTypeMap = new Map<String, String>();
            for (Portal_Listing_Mapping__c mapping : portalListing) {
                valueMappingMap.put(mapping.Name, mapping.Value_Mapping__c);
                dataTypeMap.put(mapping.Name, mapping.Data_Type__c);
            }
        
            for (String fieldName : fieldMap.keySet()) {
                String valueMapping = valueMappingMap.containsKey(fieldName) ? valueMappingMap.get(fieldName) : null;
                String dataType = dataTypeMap.containsKey(fieldName) ? dataTypeMap.get(fieldName) : null;
                Object value = conditionallyChangeValue(dataType, fieldMap.get(fieldName), valueMapping);
                processValue(jsonMap, fieldName, value);
            }

            List<Map<String, Object>> mediaContent = new List<Map<String, Object>>();
            for (Property_File__c mediaItem : mediaList) {
                Map<String, Object> mediaMap = new Map<String, Object>();
                Datetime lastModifiedDatetime = mediaItem.LastModifiedDate;
                String lastModifiedDate = lastModifiedDatetime.format('yyyy-MM-dd HH:mm:ss');
                
                // Rearrange the date to DD-MM-YYYY HH:MM:SS
                String[] dateTimeParts = lastModifiedDate.split(' ');
                String[] dateParts = dateTimeParts[0].split('-');
                String formattedLastModifiedDate = dateParts[2] + '-' + dateParts[1] + '-' + dateParts[0] + ' ' + dateTimeParts[1];
                
                String mediaURL = String.isNotBlank(mediaItem.ExternalLink__c) ? mediaItem.ExternalLink__c : mediaItem.BaseUrl__c;
                Integer mediaType = String.isNotBlank(mediaItem.Tags__c) ? urlType(mediaItem.Tags__c) : 1;
                mediaMap.put('media_type', mediaType);
                mediaMap.put('media_url', mediaURL);
                mediaMap.put('media_update_date', formattedLastModifiedDate);
                mediaContent.add(mediaMap);
            }
            
            // Adding media content to the property
            Map<String, Object> propertyMap = (Map<String, Object>)jsonMap.get('property');
            if (propertyMap == null) {
                propertyMap = new Map<String, Object>();
                jsonMap.put('property', propertyMap);
            }
            propertyMap.put('media', mediaContent);
            
            String jsonString = JSONController.createJSON(jsonMap);
            
            return jsonString;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'RightmoveJSONController', 'buildJSON', 'Error while building JSON for Rightmove.');
            return '{"status":"fail","reason":"Error while creating JSON Body: ' + e.getMessage() + '"}';
        }
    }

    /**
    * Method Name : processValue
    * @param parentMap - Map<String, Object>
    * @param key - String
    * @param value - Object
    * @return String
    * @description : Used to process value for Rightmove.
    */
    private static void processValue(Map<String, Object> parentMap, String key, Object value) {
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
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'RightmoveJSONController', 'processValue', 'Error while processing value for Zoopla.');
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
                        return Datetime.valueOfGmt((String) value).format('dd-MM-yyyy HH:mm:ss');
                    } else {
                        return ((Datetime) value).format('dd-MM-yyyy HH:mm:ss');
                    }
                } else if (dataType.equalsIgnoreCase('date')) {
                    if (value instanceof Datetime) {
                        return ((Datetime) value).format('dd-MM-yyyy');
                    } else {
                        return DateTime.newInstance((Date) value, Time.newInstance(0, 0, 0, 0)).format('dd-MM-yyyy');
                    }
                } else {
                    return String.valueOf(value);
                }
            } else {
                return value;
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'RightmoveJSONController', 'conditionallyChangeValue', 'Error while conditionally changing value for Zoopla and value is ' + value);
            return value;
        }
    }

    /**
    * Method Name : isArrayField
    * @param fieldName - String
    * @return String
    * @description : Used to check if field is array field for Rightmove.
    */
    public static Boolean isArrayField(String fieldName) {
        switch on fieldName {
            when 'features' {
                return true;
            }
            when 'parking' {
                return true;
            }
            when 'outside_space' {
                return true;
            }
            when 'accessibility' {
                return true;
            }
            when 'heating' {
                return true;
            }
            when 'comm_use_class' {
                return true;
            }
            when 'rooms' {
                return true;
            }
            when 'room_photo_urls' {
                return true;
            }
            when else {
                return false;
            }
        }
    }

    /**
    * Method Name : urlType
    * @param type - String
    * @return String
    * @description : Used to get url type for Rightmove.
    */
    public static Integer urlType(String type) {
        switch on type {
            when '360tour' {
                return 4;
            }
            when 'Floorplan' {
                return 2;
            }
            when 'Virtual Tour' {
                return 4;
            }
            when 'Audio Tour' {
                return 5;
            }
            when 'EPC' {
                return 6;
            }
            when 'EPC Graph' {
                return 7;
            }
            when 'Brochure' {
                return 3;
            }
            when else {
                return 1;
            }
        }
    }
}