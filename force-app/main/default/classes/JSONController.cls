/**
* Class Name : JSONController
* Test Class : JSONControllerTest
* Created By : Karan Singh
* Last Modified Date : 30/06/2024
* Last Modified By : Karan Singh
* @description : Used to build the JSON data.
*/
public with sharing class JSONController {
    
    /**
    * Method Name : createJSON
    * @param inputData to stored the input data
    * @return String that contains the JSON data.
    * @description : Used to build the JSON data.
    */
    public static String createJSON(Map<String, Object> inputData) {
        try {
            JSONGenerator gen = JSON.createGenerator(false);
            gen.writeStartObject();
            
            for (String key : inputData.keySet()) {
                writeField(gen, key, inputData.get(key));
            }
            
            gen.writeEndObject();
            return gen.getAsString();
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'JSONController', 'createJSON', 'Error while creating JSON data.');
            return '{"status":"fail","reason":"Error while creating JSON Body: ' + e.getMessage() + '"}';
        }
    }
    
    /**
    * Method Name : writeField
    * @param gen to stored the JSONGenerator object
    * @param key to stored the key
    * @param value to stored the value
    * @description : Used to write the field in the JSON data.
    */
    private static void writeField(JSONGenerator gen, String key, Object value) {
        try {
            if (value == null) {
                return;
            } else if (value instanceof Map<String, Object>) {
                gen.writeFieldName(key);
                gen.writeStartObject();
                Map<String, Object> mapValue = (Map<String, Object>) value;
                for (String subKey : mapValue.keySet()) {
                    writeField(gen, subKey, mapValue.get(subKey));
                }
                gen.writeEndObject();
            } else if (value instanceof List<Object>) {
                gen.writeFieldName(key);
                gen.writeStartArray();
                for (Object item : (List<Object>) value) {
                    if (item instanceof Map<String, Object>) {
                        gen.writeStartObject();
                        Map<String, Object> mapItem = (Map<String, Object>) item;
                        for (String subKey : mapItem.keySet()) {
                            writeField(gen, subKey, mapItem.get(subKey));
                        }
                        gen.writeEndObject();
                    } else {
                        if (item != null) {
                            gen.writeObject(item);
                        }
                    }
                }
                gen.writeEndArray();
            } else {
                gen.writeFieldName(key);
                gen.writeObject(value);
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'JSONController', 'writeField', 'Error while writing field in JSON data.');
        }
    }
    
}