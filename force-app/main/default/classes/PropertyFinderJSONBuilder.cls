public with sharing class PropertyFinderJSONBuilder {
    
    public static String buildJSON(Map<String, Object> fieldMap, List<Property_File__c> mediaList) {
        try {
            Map<String, Object> jsonMap = new Map<String, Object>();
        
            List<Portal_Listing_Mapping__c> portalListing = [SELECT Id, Name, Value_Mapping__c, Data_Type__c FROM Portal_Listing_Mapping__c WHERE Portal_Name__c =: 'Propertyfinder' WITH USER_MODE];

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

            // Build media section
            Map<String, Object> mediaMap = new Map<String, Object>();
            List<Map<String, Object>> imagesList = new List<Map<String, Object>>();
            Map<String, String> videosMap = new Map<String, String>();

            for (Property_File__c mediaItem : mediaList) {
                String mediaURL = String.isNotBlank(mediaItem.ExternalLink__c) ? mediaItem.ExternalLink__c : mediaItem.BaseUrl__c;
                String mediaType = String.isNotBlank(mediaItem.Tags__c) ? mediaItem.Tags__c : 'original';
                
                if (mediaType == '360tour' || mediaType == 'Virtual Tour') {
                    // Add to videos section
                    if (mediaType == '360tour') {
                        videosMap.put('view360', mediaURL);
                    } else if (mediaType == 'Virtual Tour') {
                        videosMap.put('default', mediaURL);
                    }
                } else {
                    // Add to images section
                    Map<String, Object> imageMap = new Map<String, Object>();
                    Map<String, Object> sizeMap = new Map<String, Object>();
                    
                    sizeMap.put('height', mediaItem.MVEX__Original_Height__c != null ? Integer.valueOf(mediaItem.MVEX__Original_Height__c) : 0);
                    sizeMap.put('url', String.isNotBlank(mediaURL) ? mediaURL : null);
                    sizeMap.put('width', mediaItem.MVEX__Original_Width__c != null ? Integer.valueOf(mediaItem.MVEX__Original_Width__c) : 0);
                    
                    // Skip if URL is null or empty
                    if (sizeMap.get('url') != null) {
                        // Map the media type to the appropriate image size
                        if (mediaType == 'original') {
                            imageMap.put('original', sizeMap);
                        } else if (mediaType == 'thumbnail') {
                            imageMap.put('thumbnail', sizeMap);
                        } else if (mediaType == 'watermarked') {
                            imageMap.put('watermarked', sizeMap);
                        } else if (mediaType == 'large') {
                            imageMap.put('large', sizeMap);
                        } else if (mediaType == 'medium') {
                            imageMap.put('medium', sizeMap);
                        } else {
                            imageMap.put('original', sizeMap); // Default to original if type is unknown
                        }
                        
                        imagesList.add(imageMap);
                    }
                }
            }
            
            // Only add non-empty lists/maps to mediaMap
            if (!imagesList.isEmpty()) {
                mediaMap.put('images', imagesList);
            }
            if (!videosMap.isEmpty()) {
                mediaMap.put('videos', videosMap);
            }
            
            // Add media to jsonMap only if it contains data
            if (!mediaMap.isEmpty()) {
                jsonMap.put('media', mediaMap);
            }
            
            String jsonString = JSONController.createJSON(jsonMap);
            
            return jsonString;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'PropertyFinderJSONBuilder', 'buildJSON', 'Error while building JSON for Property Finder.');
            return '{"status":"fail","reason":"Error while creating JSON Body: ' + e.getMessage() + '"}';
        }
    }

    private static void processValue(Map<String, Object> parentMap, String key, Object value) {
        try {
            // Skip null or empty values
            if (isEmptyValue(value)) {
                return;
            }

            if (key.contains('.')) {
                String[] fieldNames = key.split('\\.');
                Map<String, Object> currentMap = parentMap;
                
                for (Integer i = 0; i < fieldNames.size() - 1; i++) {
                    String field = fieldNames[i];
                    if (!currentMap.containsKey(field) || currentMap.get(field) == null) {
                        if (isArrayField(field)) {
                            currentMap.put(field, new List<Object>{new Map<String, Object>()});
                        } else {
                            currentMap.put(field, new Map<String, Object>());
                        }
                    }
                    
                    if (isArrayField(field)) {
                        currentMap = (Map<String, Object>) ((List<Object>) currentMap.get(field))[0];
                    } else {
                        currentMap = (Map<String, Object>) currentMap.get(field);
                    }
                }
                
                String lastField = fieldNames[fieldNames.size() - 1];
                if (isArrayField(lastField)) {
                    if (!currentMap.containsKey(lastField)) {
                        currentMap.put(lastField, new List<Object>());
                    }
                    ((List<Object>) currentMap.get(lastField)).add(value);
                } else {
                    currentMap.put(lastField, value);
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
            ErrorHandler.insertErrorData(e, 'PropertyFinderJSONBuilder', 'processValue', 'skip field for processing due to null value');
        }
    }

    private static Object conditionallyChangeValue(String dataType, Object value, String valueMapping) {
        try {
            if (isEmptyValue(value)) {
                return null;
            }

            Map<String, String> valueMap = new Map<String, String>();
            if (valueMapping != null && valueMapping != '') {
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
                        return Datetime.valueOfGmt((String) value).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
                    } else {
                        return ((Datetime) value).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
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
            ErrorHandler.insertErrorData(e, 'PropertyFinderJSONBuilder', 'conditionallyChangeValue', 'Error while conditionally changing value for Property Finder and value is ' + value);
            return value;
        }
    }

    private static Boolean isEmptyValue(Object value) {
        if (value == null) {
            return true;
        }
        if (value instanceof String && String.isBlank((String) value)) {
            return true;
        }
        if (value instanceof List<Object> && ((List<Object>) value).isEmpty()) {
            return true;
        }
        if (value instanceof Map<String, Object> && ((Map<String, Object>) value).isEmpty()) {
            return true;
        }
        return false;
    }

    public static Boolean isArrayField(String fieldName) {
        switch on fieldName {
            when 'amenities', 'paymentMethods', 'images' {
                return true;
            }
            when else {
                return false;
            }
        }
    }
}