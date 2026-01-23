public without sharing class DataMappingControllerV2 {

    public static List<sObject> querySObject2(String query,Set<Id> recordIds){
        try {
            return Database.query(query, AccessLevel.USER_MODE);
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'DataMappingControllerV2', 'querySObject2', e.getMessage());
            return null;
        }
    }

    public static map<String, Object> getSobjectAsMapForIds(List<String> fieldList, String objectAPI, Set<Id> recordIds){
        map<String, Object> sobjectAsMap = new map<String, Object>();
        try {
            if(fieldList.size() > 0){

                Set<String> fieldsToQuery = new Set<String>(fieldList);
                fieldsToQuery.add('Id');
    
                String fieldApiString = string.join(fieldsToQuery, ',');
                String dynamicQuery = 'SELECT ' + String.escapeSingleQuotes(fieldApiString) + ' FROM '+ String.escapeSingleQuotes(objectAPI) +' WHERE Id IN: recordIds LIMIT 50000';
    
                // userObj = Database.query(dynamicQuery, recordId);
                List<sObject> sObj = querySObject2(dynamicQuery,recordIds);

                for (sObject record : sObj) {
                    String recordId = (String) record.get('Id');
                    sobjectAsMap.put(recordId, record);
                }
                return sobjectAsMap;
            }
            return sobjectAsMap;

        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'DataMappingControllerV2', 'getSobjectAsMapForIds', e.getMessage());
            return sobjectAsMap;
        }
    }

    public static map<String, String> mapKeysWithValue2(FieldListClass fieldLists, List<ExtractedKeys> extractedKeys,String objAPI, Set<Id> recordIds){
        Map<String, String> extractedKeyWithData = new Map<String, String>();
        try {

            Map<String, String> dt = KeyMappingController.dateFormats();
            Map<string, string> dateVal = new Map<string, string>();
            for(string d : dt.keySet()){
                dateVal.put(d, dt.get(d).split(';')[3]);
            }
            String dateValueString = JSON.serialize(dateVal);
            Map<String, Object> dateValus = (Map<String, Object>) JSON.deserializeUntyped(dateValueString);
            
            // Converting sObject into map<String, Object> will make easy to get parent object data from it....
            String userId = UserInfo.getUserId();
            map<String, Object> userObject = getSobjectAsMap(fieldLists.userFields, 'User', userId);
            
            String orgId = UserInfo.getOrganizationId();
            map<String, Object> orgObject = getSobjectAsMap(fieldLists.orgFields, 'Organization', orgId);
            
            map<String, Object> sourceObject = getSobjectAsMapForIds(fieldLists.objectFields, objAPI, recordIds);

            for(ExtractedKeys ext : extractedKeys){
                String fieldValue = '';
                if(ext.fieldAPI.contains('.')){
                    string replationshipName = ext.fieldAPI.substringBefore('.');
                    string fieldName = ext.fieldAPI.substringAfter('.');
                    switch on replationshipName{
                        when 'Date'{
                            fieldValue = getFieldValue(ext, dateValus);
                        }
                        when 'User'{
                            fieldValue = getFieldValue(ext, userObject);
                        }
                        when 'Org'{
                            fieldValue = getFieldValue(ext, orgObject);
                        }
                        when else{
                            fieldValue = getFieldValue(ext, sourceObject);
                        }
                    }
                }else{
                    fieldValue = getFieldValue(ext, sourceObject);
                }
                fieldValue = fieldValue != null ? fieldValue : '';
                extractedKeyWithData.put(ext.mappingKey, fieldValue);
            }
            return extractedKeyWithData;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'DataMappingControllerV2', 'mapKeysWithValue2', e.getMessage());
            return extractedKeyWithData;
        }
    }


    public static Map<String, String> getMappingKeyVsValue2(List<String> mappingKeyList,String sourceObjectAPI, Set<Id> recordIds){
        Map<String, String> extractedKeyWithData = new Map<String, String>();
        try {

            List<ExtractedKeys> extractedKeys = new List<ExtractedKeys>();

            extractedKeys.addAll(getValidKeys(mappingKeyList, sourceObjectAPI, '#'));
            extractedKeys.addAll(getValidKeys(mappingKeyList, sourceObjectAPI, 'Doc.'));

            FieldListClass fieldLists = new FieldListClass();

            for(ExtractedKeys ext : extractedKeys){
                if(ext.fieldAPI.contains('.')){
                    string replationshipName = ext.fieldAPI.substringBefore('.');
                    string fieldName = ext.fieldAPI.substringAfter('.');
                    switch on replationshipName{
                        when 'Date'{
                            fieldLists.dateFields.add(fieldName);
                        }
                        when 'User'{
                            fieldLists.userFields.add(fieldName);
                        }
                        when 'Org'{
                            fieldLists.orgFields.add(fieldName);
                        }
                        when else{
                            fieldLists.objectFields.add(ext.fieldAPI);
                        }
                    }
                }else{
                    fieldLists.objectFields.add(ext.fieldAPI);
                }
            }
            return mapKeysWithValue2(fieldLists, extractedKeys, sourceObjectAPI,recordIds);
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'DataMappingControllerV2', 'getMappingKeyVsValue2', e.getMessage());
            return extractedKeyWithData;
        }
    }

    public static map<String, Map<String, String>> getMappingsKeyValues2(Map<String, Object> extractedKeyMap,String sourceObjectAPI, Set<Id> recordIds, Boolean includeMergTemKeys){
        Map<String, Map<String, String>> mapingKeyVsValuesGroup = new Map<String, Map<String, String>>{
            'objectNGeneral' => new map<string, string>(),
            'margeTemplate' => new map<string, string>(),
            'salesforceImages' => new map<string, string>(),
            'listingMediaImages' => new map<string, string>()
        };
        try {
         

                Set<String> extractedKeys = collectMappingKeys(extractedKeyMap);

                Map<String, String> mappigKeysValue = getMappingKeyVsValue2(new List<String>(extractedKeys), sourceObjectAPI, recordIds);
                mapingKeyVsValuesGroup?.get('objectNGeneral')?.putAll(mappigKeysValue);

                Map<String, String> sfImagesSRCVsID = getSFimageVsId(extractedKeyMap);
                mapingKeyVsValuesGroup?.get('salesforceImages')?.putAll(sfImagesSRCVsID);

                if(includeMergTemKeys == true){
                    set<String> mergTemplateKeys = collectMergeTemplateKeys(extractedKeyMap);
                }
                                        
            return mapingKeyVsValuesGroup;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'DataMappingControllerV2', 'getMappingsKeyValues2', e.getMessage());
            return mapingKeyVsValuesGroup;
        }
    }

    public static map<String, Map<String, String>> getMappingsKeyValues1(List<Template__c> temps, String recordId, Boolean includeMergTemKeys){
        Map<String, Map<String, String>> mapingKeyVsValuesGroup = new Map<String, Map<String, String>>{
            'objectNGeneral' => new map<string, string>(),
            'margeTemplate' => new map<string, string>(),
            'salesforceImages' => new map<string, string>(),
            'listingMediaImages' => new map<string, string>()
        };
        try {
                String extractedKeyString = '';
                String sourceObjectAPI = '';

                if(!temps.isEmpty()){
                    for(Template_Data__c fieldData : temps[0].Template_Data__r){
                        extractedKeyString +=  fieldData.Template_Value_Simple__c;
                    }

                    extractedKeyString = extractedKeyString != '' ? extractedKeyString : 'null';

                    sourceObjectAPI = temps[0].Object_API_Name__c;
                }

                Map<String, Object> extractedKeyMap = (Map<String, Object>) JSON.deserializeUntyped(extractedKeyString);
                // Collect and Store mapping keys in to set of string from keys stored in field...
                Set<String> extractedKeys = collectMappingKeys(extractedKeyMap);
                // collect mapping key values for object field and general fields....
                Map<String, String> mappigKeysValue = getMappingKeyVsValue(new List<String>(extractedKeys), sourceObjectAPI, recordId);
                mapingKeyVsValuesGroup?.get('objectNGeneral')?.putAll(mappigKeysValue);

                // Collect and Store Salesforce image SRC in to set ...
                Map<String, String> sfImagesSRCVsID = getSFimageVsId(extractedKeyMap);
                mapingKeyVsValuesGroup?.get('salesforceImages')?.putAll(sfImagesSRCVsID);

                // this varibale will be FALSE when it call from "getKeyNValueFromMergeTemps" Method...
                if(includeMergTemKeys == true){
                    // collect merge template key from keys stored in field ...
                    set<String> mergTemplateKeys = collectMergeTemplateKeys(extractedKeyMap);

                    // create map for merge template key with Values....
                    map<String, Map<String, String>> keyWithValues = getKeyNValueFromMergeTemps(new List<String>(mergTemplateKeys), sourceObjectAPI, recordId);

                    // colelct extracted key with actual value from marge template add them into exsiting map of main tempalte.
                    mapingKeyVsValuesGroup?.get('objectNGeneral')?.putAll(keyWithValues?.get('objectNGeneral'));
                    mapingKeyVsValuesGroup?.get('salesforceImages')?.putAll(keyWithValues?.get('salesforceImages'));
                    mapingKeyVsValuesGroup?.get('margeTemplate')?.putAll(keyWithValues?.get('margeTemplate'));

                    // Note : no need to add signatureImage for merge tempalte key, because signature key will be same for each template...
                }
                                        
            return mapingKeyVsValuesGroup;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'DataMappingControllerV2', 'getMappingsKeyValues1', e.getMessage());
            return mapingKeyVsValuesGroup;
        }
    }
   
    /**
     * @method getMappingsKeyValues,
     * @param templateIDs, List of template Ids,
     * @param recordId, source record is,
     * @param includeMergTemKeys, if you want to get marged tempalte, key mark it true,
     * 
     * @description : Main method from where you can extract mapping key with its actual value, (for simple tempalte)...
     * this method run two time, first when we call it from docGenerateController with template on which document going to creare &
     * second when template have merge templates with list of template as parameter...
     */
    public static map<String, Map<String, String>> getMappingsKeyValues(List<String> templateIDs, String recordId, Boolean includeMergTemKeys){
        Map<String, Map<String, String>> mapingKeyVsValuesGroup = new Map<String, Map<String, String>>{
            'objectNGeneral' => new map<string, string>(),
            'margeTemplate' => new map<string, string>(),
            'salesforceImages' => new map<string, string>(),
            'listingMediaImages' => new map<string, string>()
        };
        try {
            List<Template__c> temps = [SELECT Id, Name, Object_API_Name__c, Template_Name__c, Template_pattern__c, Template_Status__c, Description__c, CreatedDate, LastModifiedDate,
                                      (SELECT Id, Name, Template_Value_Simple__c FROM Template_Data__r WHERE Value_Type__c = 'Extracted Mapping Keys' ORDER BY Order_No_Simple__c ASC)
                                       FROM Template__c  WHERE Id In :templateIDs];

            for(Template__c temp : temps){
                String extractedKeyString = '';

                // get extracted Keys stored in field...
                for(Template_Data__c fieldData : temp.Template_Data__r){
                    extractedKeyString +=  fieldData.Template_Value_Simple__c;
                }

                extractedKeyString = extractedKeyString != '' ? extractedKeyString : 'null';

                String sourceObjectAPI = temp.Object_API_Name__c;

                // Type cast extracted key field value to key mappign keys, child object info and merge tempalte keys....
                Map<String, Object> extractedKeyMap = (Map<String, Object>) JSON.deserializeUntyped(extractedKeyString);
    
                // Collect and Store mapping keys in to set of string from keys stored in field...
                Set<String> extractedKeys = collectMappingKeys(extractedKeyMap);
                // collect mapping key values for object field and general fields....
                Map<String, String> mappigKeysValue = getMappingKeyVsValue(new List<String>(extractedKeys), sourceObjectAPI, recordId);
                mapingKeyVsValuesGroup?.get('objectNGeneral')?.putAll(mappigKeysValue);

                // Collect and Store Salesforce image SRC in to set ...
                Map<String, String> sfImagesSRCVsID = getSFimageVsId(extractedKeyMap);
                mapingKeyVsValuesGroup?.get('salesforceImages')?.putAll(sfImagesSRCVsID);

                Map<String, String> listingimages = getListingMediaImages(recordId);
                mapingKeyVsValuesGroup?.get('listingMediaImages')?.putAll(listingimages);
                
                // this varibale will be FALSE when it call from "getKeyNValueFromMergeTemps" Method...
                if(includeMergTemKeys == true){
                    set<String> mergTemplateKeys = collectMergeTemplateKeys(extractedKeyMap);

                    // create map for merge template key with Values....
                    map<String, Map<String, String>> keyWithValues = getKeyNValueFromMergeTemps(new List<String>(mergTemplateKeys), sourceObjectAPI, recordId);

                    // colelct extracted key with actual value from marge template add them into exsiting map of main tempalte.
                    mapingKeyVsValuesGroup?.get('objectNGeneral')?.putAll(keyWithValues?.get('objectNGeneral'));
                    mapingKeyVsValuesGroup?.get('salesforceImages')?.putAll(keyWithValues?.get('salesforceImages'));
                    mapingKeyVsValuesGroup?.get('margeTemplate')?.putAll(keyWithValues?.get('margeTemplate'));

                    // Note : no need to add signatureImage for merge tempalte key, because signature key will be same for each template...
                }
            }
                                        
            return mapingKeyVsValuesGroup;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'DataMappingControllerV2', 'getMappingsKeyValues', e.getMessage());
            return mapingKeyVsValuesGroup;
        }
    }

    /**
     * @param extractedKeyMap, Map of keyType vs list of keys in object form,
     * @description : extract and collect all the object and general field's key from all mapping keys.
     */
    public static Set<String> collectMappingKeys(Map<String, Object> extractedKeyMap){
        Set<String> extractedKeys = new Set<String>();
        try {
            
            Object objectFields = extractedKeyMap?.get('objectFields') != null ? extractedKeyMap.get('objectFields') : (Object) JSON.deserializeUntyped('[]');
            String objectFieldString = JSON.serialize(objectFields);
            List<Object> objectFieldKeys = (List<Object>) JSON.deserializeUntyped(objectFieldString);
    
            Object generalFields = (extractedKeyMap != null && extractedKeyMap?.get('generalFields') != null) ? extractedKeyMap.get('generalFields') : (Object) JSON.deserializeUntyped('[]');
            String generalFieldString = JSON.serialize(generalFields);
            List<Object> generalFieldKeys = (List<Object>) JSON.deserializeUntyped(generalFieldString);

            for(Object key : objectFieldKeys){
                extractedKeys.add((String) key);
            }
            for(Object key : generalFieldKeys){
                extractedKeys.add((String) key);
            }

            return extractedKeys;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'DataMappingControllerV2', 'collectMappingKeys', e.getMessage());
            return extractedKeys;
        }
    }
    /**
     * @param extractedKeyMap, Map of keyType vs list of keys in object form,
     * @description : extract and collect merge template keys.
     */
    public static Set<String> collectMergeTemplateKeys(Map<String, Object> extractedKeyMap){
        set<String> mergTemplateKeys = new set<String>();
        try {
            
            Object mergeTempKeys = extractedKeyMap?.get('mergeTempKeys') != null ? extractedKeyMap.get('mergeTempKeys') : (Object) JSON.deserializeUntyped('[]');
            String mergerTempString = JSON.serialize(mergeTempKeys);
            List<Object> mergerTempKeys = (List<Object>) JSON.deserializeUntyped(mergerTempString);

            for(Object key : mergerTempKeys){
                mergTemplateKeys.add((String) key);
            }

            return mergTemplateKeys;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'DataMappingControllerV2', 'collectMergeTemplateKeys', e.getMessage());
            return mergTemplateKeys;
        }
    }

    /**
     * @param extractedKeyMap,  Map of keyType vs list of keys in object form,
     * @description : Methods to collect all SRC with content version id
     * @return map of string(imageSrc) and String(imageId)
     */
    public static Map<String, String> getSFimageVsId(Map<String, Object> extractedKeyMap){
        Map<String, String> sfImages = new  Map<String,String>();
        try {
            
            Object sfImageSRCs = extractedKeyMap?.get('salesforceImages') != null ? extractedKeyMap.get('salesforceImages') : (Object) JSON.deserializeUntyped('[]');
            String sfImagesSRCString = JSON.serialize(sfImageSRCs);
            List<Object> sfImgKeys = (List<Object>) JSON.deserializeUntyped(sfImagesSRCString);

            for(Object key : sfImgKeys){
                String src = (String) key;
                sfImages.put(src, src.substringBetween('&ids=', '&d='));
            }

            return sfImages;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'DataMappingControllerV2', 'getSFimageVsId', e.getMessage());
            return sfImages;
        }
    }

    // === === Method to Replace value with object field's, parent object field's and General field's mapping key ==== ====
    /**
     * @param mappingKeyList, list of mapping keys,
     * @param sourceObjectAPI, API name of source object,
     * @param recordId, Id or source record,
     * 
     * @description : Method to get actual value of mapping for object field and general fiels...
     * @return map String(mapping Key) vs String(actual value)...
     * If Code find any false key or invalid key, it will return same key as its actual value...
     */
    public static Map<String, String> getMappingKeyVsValue(List<String> mappingKeyList,String sourceObjectAPI, String recordId){
        Map<String, String> extractedKeyWithData = new Map<String, String>();
        try {

            List<ExtractedKeys> extractedKeys = new List<ExtractedKeys>();

            extractedKeys.addAll(getValidKeys(mappingKeyList, sourceObjectAPI, '#'));
            extractedKeys.addAll(getValidKeys(mappingKeyList, sourceObjectAPI, 'Doc.'));

            FieldListClass fieldLists = new FieldListClass();

            for(ExtractedKeys ext : extractedKeys){
                if(ext.fieldAPI.contains('.')){
                    string replationshipName = ext.fieldAPI.substringBefore('.');
                    string fieldName = ext.fieldAPI.substringAfter('.');
                    switch on replationshipName{
                        when 'Date'{
                            fieldLists.dateFields.add(fieldName);
                        }
                        when 'User'{
                            fieldLists.userFields.add(fieldName);
                        }
                        when 'Org'{
                            fieldLists.orgFields.add(fieldName);
                        }
                        when else{
                            fieldLists.objectFields.add(ext.fieldAPI);
                        }
                    }
                }else{
                    fieldLists.objectFields.add(ext.fieldAPI);
                }
            }

            return mapKeysWithValue(fieldLists, extractedKeys, new list<String>{recordId, sourceObjectAPI});
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'DataMappingControllerV2', 'getMappingKeyVsValue', e.getMessage());
            return extractedKeyWithData;
        }
    }

    /**
     * @param fieldLists, wrapper class to store multiple type fields list,
     * @param extractedKeys, Map of keyType vs list of keys in object form,
     * @param recordIdNobjAPI, List of string with recordId at 0 index and Object Api name at 1 index,
     * 
     * @description : get key value for each object, date, user and organization field type...
     * @return map String(mapping Key) vs String(actual value)...
     */
    public static map<String, String> mapKeysWithValue(FieldListClass fieldLists, List<ExtractedKeys> extractedKeys, list<String> recordIdNobjAPI){
        Map<String, String> extractedKeyWithData = new Map<String, String>();
        try {

            String recordId = recordIdNobjAPI[0];
            String objAPI = recordIdNobjAPI[1];

            Map<String, String> dt = KeyMappingController.dateFormats();
            Map<string, string> dateVal = new Map<string, string>();
            for(string d : dt.keySet()){
                dateVal.put(d, dt.get(d).split(';')[3]);
            }
            String dateValueString = JSON.serialize(dateVal);
            Map<String, Object> dateValus = (Map<String, Object>) JSON.deserializeUntyped(dateValueString);
            
            // Converting sObject into map<String, Object> will make easy to get parent object data from it....

            String userId = UserInfo.getUserId();
            map<String, Object> userObject = getSobjectAsMap(fieldLists.userFields, 'User', userId);
            
            String orgId = UserInfo.getOrganizationId();
            map<String, Object> orgObject = getSobjectAsMap(fieldLists.orgFields, 'Organization', orgId);
            
            map<String, Object> sourceObject = getSobjectAsMap(fieldLists.objectFields, objAPI, recordId);

            for(ExtractedKeys ext : extractedKeys){
                String fieldValue = '';
                if(ext.fieldAPI.contains('.')){
                    string replationshipName = ext.fieldAPI.substringBefore('.');
                    string fieldName = ext.fieldAPI.substringAfter('.');
                    switch on replationshipName{
                        when 'Date'{
                            fieldValue = getFieldValue(ext, dateValus);
                        }
                        when 'User'{
                            fieldValue = getFieldValue(ext, userObject);
                        }
                        when 'Org'{
                            fieldValue = getFieldValue(ext, orgObject);
                        }
                        when else{
                            fieldValue = getFieldValue(ext, sourceObject);
                        }
                    }
                }else{
                    fieldValue = getFieldValue(ext, sourceObject);
                }

                fieldValue = fieldValue != null ? fieldValue : '';
                extractedKeyWithData.put(ext.mappingKey, fieldValue);
            }

            return extractedKeyWithData;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'DataMappingControllerV2', 'mapKeysWithValue', e.getMessage());
            return extractedKeyWithData;
        }
    }

    /**
     * @param fieldList, List of field to retive using SOQL,
     * @param objectAPI, Sorce objcet API Name,
     * @param recordId, Id or source record,
     * 
     * @description : Retrive Object data as sObject using SOQL and Covert it into Map of string & string
     */
    public static map<String, Object> getSobjectAsMap(List<String> fieldList, String objectAPI, string recordId){
        map<String, Object> sobjectAsMap = new map<String, Object>();
        try {
            if(fieldList.size() > 0){

                Set<String> fieldsToQuery = new Set<String>(fieldList);
                fieldsToQuery.add('Id');
    
                String fieldApiString = string.join(fieldsToQuery, ',');
                String dynamicQuery = 'SELECT ' + String.escapeSingleQuotes(fieldApiString) + ' FROM '+ String.escapeSingleQuotes(objectAPI) +' WHERE Id =: recordId LIMIT 1';
    
                // userObj = Database.query(dynamicQuery, recordId);
                sObject sObj = querySObject(dynamicQuery, recordId, objectAPI);
    
                String sObjString = JSON.serialize(sObj);
                sobjectAsMap = (Map<String, Object>) JSON.deserializeUntyped(sObjString);
                return sobjectAsMap;
            }
            return sobjectAsMap;

        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'DataMappingControllerV2', 'getSobjectAsMap', e.getMessage());
            return sobjectAsMap;
        }
    }

    // ==== === ==== Method to collect all mapping keys with value of merge templates ==== ===== =====
    /**
     * @param margeTempKeyList, List of merger tempalte keys,
     * @param sourceObjectAPI, Sorce objcet API Name,
     * @param recordId, Id of source record,
     * 
     * @description : Extract and collect merge tempalte key from all extracted key store in field...
     */
    public static map<String, Map<String, String>> getKeyNValueFromMergeTemps(List<String> margeTempKeyList, String sourceObjectAPI, String recordId){
        map<String, Map<String, String>> keyWithValuesGroup = new map<String, Map<String, String>>{
            'objectNGeneral' => new map<string, string>(),
            'margeTemplate' => new map<string, string>(),
            'salesforceImages' => new map<string, string>()
        };
        try {
            
            // --- ---- Extract abd collect Template Ids from merge template keys ---- ----
            Map<String, String> templateIds = extractMergeTemplateIds(margeTempKeyList);

            // --- --- Collect mapping keys from merge template records --- ---
            List<Template__c> mergeTemps = [SELECT Id,Object_API_Name__c,
                                            (SELECT Id, Name, Template_Value_Simple__c FROM Template_Data__r WHERE Value_Type__c = 'Extracted Mapping Keys' ORDER BY Order_No_Simple__c ASC)
                                            FROM Template__c WHERE Id IN :templateIds.values() AND Template_pattern__c = 'PDF Template' AND Object_API_Name__c =:sourceObjectAPI AND Template_Status__c = true WITH USER_MODE ];
            
            List<String> validTemplateListIds = new List<String>();
            for(Template__c temp : mergeTemps){
                validTemplateListIds.add(temp.Id);
            }

            // Get Mapping Key Values from the merge templates... Add with existing merge and value
            map<String, Map<String, String>> keyWithValues = getMappingsKeyValues(validTemplateListIds, recordId, false);
            // map<String, Map<String, String>> keyWithValues = getMappingsKeyValues1(mergeTemps, recordId, false);
            keyWithValuesGroup?.get('objectNGeneral')?.putAll(keyWithValues.get('objectNGeneral'));
            keyWithValuesGroup?.get('salesforceImages')?.putAll(keyWithValues.get('salesforceImages'));

            // add marge template Keys with template Id...
            keyWithValuesGroup?.get('margeTemplate')?.putAll(templateIds);
            // keyWithValues.putAll(templateIds);

            return keyWithValuesGroup;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'DataMappingControllerV2', 'getKeyNValueFromMergeTemps', e.getMessage());
            return keyWithValuesGroup;
        }
    }

    /**
     * @param margeTempKeyList, List of merger tempalte keys,
     * @description : Extracting template Ids from tempalte keys...
     */
    public static Map<String, String> extractMergeTemplateIds(List<String> margeTempKeyList){
        try {
            Map<String, String> templateIds = new Map<String, String>();
            for(String key : margeTempKeyList){
                String subMapping = key.substringBetween('{{','}}');
                // Used Switch instead of if/else to avoid pmd error of congantive complexity....
                Switch on String.valueOf(subMapping.startsWith('Temp.')){
                    when 'true'{
                        String subString = subMapping.substringAfter('Temp.');
                        String templateId = subString.contains('*') ? subString.substringBefore('*').trim() : subString.trim();
                        templateIds.put(key, templateId);
                    }
                }
            }

            return templateIds;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'DataMappingControllerV2', 'extractMergeTemplateIds', e.getMessage());
            return new Map<String, String>();
        }
    }

    // ==== ===== ====== ===== GENERERIC METHODS ======= ======== ========== =====

    /**
     * @param ext, wrapper class to store mapping key infos,
     * @param valueData, map of fieldName with value,
     * 
     * @description : generic method to getfield value as per its key type and field type with formatting...
     */
    public static string getFieldValue(ExtractedKeys ext, map<string, Object> valueData){
        try {

            String fieldValue = '';
            
            if(ext.fieldAPI.contains('.') == true){
                String relationShipName = ext.fieldAPI.substringBefore('.');
                String fieldName = ext.fieldAPI.substringAfter('.');
                switch on relationShipName{
                    when 'Date', 'User', 'Org'{
                        fieldValue = (String) String.valueOf(valueData?.get(fieldName));
                    }
                    when else{
                        // field comes in this block must me sorce object's parent object's field...
                        Map<String, Object> parentObj = (Map<String, Object>) valueData?.get(relationShipName);
                        fieldValue = (String) String.valueOf(parentObj?.get(fieldName));
                    }
                }
            }
            else{                

                for (String key : valueData.keySet()) {
                    Object obj = valueData.get(key);
                    if (obj instanceof SObject) {

                        SObject record = (SObject)obj;
                        fieldValue = (String) String.valueOf(record?.get(ext.fieldAPI));  
                        break;
                    }
                    else{
                        fieldValue = (String) String.valueOf(valueData?.get(ext.fieldAPI));  
                    }                                            
                }
            }

            if(ext.formatType != null && ext.formatType != '' && fieldValue != '' && fieldValue != null){
                // field required formatting...
                switch on ext.fieldType{
                    when 'DATETIME', 'DATE', 'TIME'{
                        fieldValue = formatDateTime(fieldValue, ext.formatType, ext.fieldType);
                    }
                    when 'BOOLEAN'{
                        fieldValue = formatBoolean(fieldValue, ext.formatType);
                    }
                    when 'STRING'{
                        fieldValue = formatString(fieldValue, ext.formatType);
                    }
                    when 'INTEGER', 'DOUBLE', 'CURRENCY', 'PERCENT'{
                        fieldValue = formatNumber(fieldValue, ext.formatType);
                    }
                }
            }
            else if(fieldValue != '' && fieldValue != null && ext.fieldType == 'DATETIME' && fieldValue.contains('+')){
                // If DateTime field value consist of timezone offset then convert to GMT. field required formatting...
                Datetime dt1 = (Datetime) JSON.deserialize('"' + fieldValue + '"', Datetime.class);
                fieldValue = dt1.format('yyyy-MM-dd HH:mm:ss');
            }

            ext.value = fieldValue;

            return fieldValue;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'DataMappingControllerV2', 'getFieldValue', e.getMessage());
            return ext.mappingKey;
        }
    }

    /**
     * @param mappingKeyList, list mapping keys,
     * @param sourceObjectAPI, Sorce objcet API Name,
     * @param startingSymbol, symbol to identify fields...
     * 
     * @description : generic Method to verify all key and collect only valid keys...
     */
    public static List<ExtractedKeys> getValidKeys(List<string> mappingKeyList, String sourceObjectAPI, String startingSymbol){
        List<ExtractedKeys> extractedKeys = new List<ExtractedKeys>();
        try {

            List<KeyMappingController.MappingFields> objectWithFields = new List<KeyMappingController.MappingFields>();
            Map<String, String> validFields = getValidFields(startingSymbol, sourceObjectAPI);

            // System.debug('validFields : ' + validFields);
            // for(String fieldAPI : validFields.keySet()){
            //     System.debug('validFields : ' + fieldAPI);
            // }


            for(String key : mappingKeyList){
                String subMapping = key.substringBetween('{{','}}');
                // Used Switch instead of if/else to avoid pmd error of congantive complexity....
                Switch on String.valueOf(subMapping.startsWith(startingSymbol)){
                    when 'true'{
                        String subString = subMapping.substringAfter(startingSymbol);
                        String fieldAPI = '';
                        String formateType = '';
                        if(subString.contains('*')){
                            fieldAPI = subString.substringBefore('*').trim();
                            formateType = subString.substringBetween('*').trim();
                        }
                        else{
                            fieldAPI = subString.trim();
                        }

                        if(validFields.keySet().contains(fieldAPI)){
                            ExtractedKeys ext = new ExtractedKeys();
                            ext.fieldAPI = fieldAPI;
                            ext.formatType = formateType;
                            ext.fieldType = validFields.get(fieldAPI);
                            ext.mappingKey = key;
                            extractedKeys.add(ext);
                        }
                    }
                }
            }
            return extractedKeys;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'DataMappingControllerV2', 'getValidKeys', e.getMessage());
            return extractedKeys;
        }
    }

    /**
     * @param startingSymbol, symbol to identify fields...
     * @param sourceObjectAPI, Sorce objcet API Name,
     * 
     * @description : generic Method to get all object valid keys...
     */
    public static Map<String, String> getValidFields(String startingSymbol, String sourceObjectAPI){
        Map<String, String> validFields = new Map<String, String>();
        try {
            if(startingSymbol == 'Doc.'){
                validFields.putAll(getObjectFields('User', false, 'User'));
                validFields.putAll(getObjectFields('organization', false, 'Org'));
    
                map<string, string> dateFormats = KeyMappingController.dateFormats();
                for(string dateInfo : dateFormats.keySet()){
                    validFields.put('Date.'+dateInfo, dateFormats.get(dateInfo).split(';')[1]);
                }
            }
            else{
                validFields.putAll(getObjectFields(sourceObjectAPI, true, null));
            }
            return validFields;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'DataMappingControllerV2', 'getValidFields', e.getMessage());
            return validFields;
        }
    }

    /**
     * @param sourceObjectAPI, Sorce objcet API Name,
     * @param getParentFields, make it true of you want to get parent object fields
     * @description : generic Method to get Source object and Its paret objects fields...
     */
    public static Map<String, String> getObjectFields(String sourceObjectAPI, Boolean getParentFields, String relationShipName){
        Map<String, String> objectFields = new Map<String, String>();
        try {
                // add base Object fields....
                objectFields.putAll(fetchObjectFields(sourceObjectAPI, 'normal', relationShipName));

                // Fetch parent Obejct(reference fields...)
                Map<String, String> parentObject = new Map<String, String>();
                if(getParentFields){
                    parentObject.putAll(fetchObjectFields(sourceObjectAPI, 'reference', null));
                }

                // get all the fields from the parent object
                for(String relation : parentObject.keyset()){
                    String parentAPI = parentObject.get(relation);
                    objectFields.putAll(fetchObjectFields(parentAPI, 'normal', relation));
                }

            return objectFields;

        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'DataMappingControllerV2', 'getObjectFields', e.getMessage());
            return objectFields;
        }
    }

    /**
     * @param objectAPI, Sorce objcet API Name,
     * @param fieldType, Its type of obejct field in source object, 'refrence' meanse parent object,
     * @param replationshipName, if we are getting value for field of parent object, add replationshipName with field api match mapping key
     * 
     * @description : generic Method to fetch object field using schema and modify api name as per replationshipName
     */
    public static map<String, string> fetchObjectFields(String objectAPI, String fieldType, String replationshipName){
        Map<String, String> fields = new Map<String, String>();
        try {
            // Schema.SObjectType sobjType = Schema.getGlobalDescribe().get(objectAPI);

            // System.debug('Object found: ' + sobjType);
            // One-liner approach
String namespace = DataMappingControllerV2.class.getName().contains('.') 
    ? DataMappingControllerV2.class.getName().substringBefore('.') + '__' 
    : '';

Schema.SObjectType sobjType = Schema.getGlobalDescribe().get(namespace + objectAPI);
System.debug('Object found: ' + sobjType);
System.debug('namespace: ' + namespace);
            Schema.DescribeSObjectResult r = sobjType.getDescribe();
            Map<String, Schema.SObjectField> mapOfFields = r.fields.getMap();
            List<String> fieldsList = new List<String>(mapOfFields.keySet());
            fieldsList.sort();

            for(String fieldName : fieldsList){
                Schema.SObjectField f = mapOfFields.get(fieldName);
                Schema.DescribeFieldResult field = f.getDescribe();
                if(field.getType() == Schema.DisplayType.REFERENCE && fieldType == 'reference'){
                    fields.put(field.getRelationshipName(), string.valueOf(field.getReferenceTo()[0]));
                    // fields.put(parentAPI, parentReplationshipName)
                }
                else{
                    if((String)String.valueOf(field.getType()) != 'ADDRESS' && (String)String.valueOf(field.getType()) != 'LOCATION' && fieldType == 'normal'){
                        String fieldAPI = (String) String.valueOf(field.getName());

                        if(objectAPI != 'Group' && replationshipName != 'What' && replationshipName != 'Who'){

                            fieldAPI = replationshipName == null ? fieldAPI : replationshipName +'.'+ fieldAPI;
                            fields.put(fieldAPI , (String)  String.valueOf(field.getType()));
                        }
                        else if(KeyMappingController.polymorphismObjAllowdFields.contains(fieldAPI) || field.isCustom()){
                            fieldAPI = replationshipName == null ? fieldAPI : replationshipName +'.'+ fieldAPI;
                            fields.put(fieldAPI , (String)  String.valueOf(field.getType()));
                        }
                    }
                }
            }

            return fields;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'DataMappingControllerV2', 'fetchObjectFields', e.getMessage());
            return fields;
        }
    }
    /**
     * @param query, string query
     * @param recordId, Id of source record,
     * @param sourceObject,  Sorce objcet API Name,
     * 
     * @description : generic method to query object using Database.query
     * This is used to solve one of the PMD error...
     */
    public static sObject querySObject(String query, String recordId, String sourceObject){
        try {
            return Database.query(query);
        } catch (Exception e) {
            Schema.SObjectType sObjectType = Schema.getGlobalDescribe().get(sourceObject);
            return  sObjectType.newSObject();
        }
    }
 
    // ====== METHODS TO FORAMT FIELD VALUE =======

    /**
     * @description : formate date, time and Datetime fields.
     */
    public static string formatDateTime(string fieldValue, string formatType, String fieldType){
        String userTimeZone = (String)String.valueOf(UserInfo.getTimeZone().getID());

        Datetime dt;
        if(fieldType == 'DATETIME'){
            // Add "T" for parse Date time
            if(!fieldValue.contains('T')){
                fieldValue = fieldValue.replace(' ', 'T');
            }

            // If DateTime field value consist of timezone offset then convert to GMT. field required formatting...
            dt = (Datetime) JSON.deserialize('"' + fieldValue + '"', Datetime.class);
            // dt = Datetime.valueOf(dt1.format('yyyy-MM-dd HH:mm:ss'));
        }
        else if(fieldType == 'DATE'){
            // Else do the normal DateTime conversion....
            dt = (Datetime) JSON.deserialize('"' + fieldValue + '"', Date.class);
        }
        else if(fieldType == 'TIME'){

            String TimeOnly = fieldValue?.substringBefore('.');
            String hr = TimeOnly?.split(':')[0];
            String min = TimeOnly?.split(':')[1];
            String sec = TimeOnly?.split(':')[2];

            Time timeValue = Time.newInstance(Integer.valueOf(hr), Integer.valueOf(min), Integer.valueOf(sec), 0);
            Date dateValue = Date.today(); 

            dt = Datetime.newInstance(dateValue, timeValue);
        }

        fieldValue = dt.format(formatType, userTimeZone);

        return fieldValue;
    }
    /**
     * @description : formate boolean (checkbox) fields.
     */
    public static string formatBoolean(string fieldValue, string formatType){
        fieldValue = fieldValue == 'true' ? formatType.substringBefore('/') : formatType.substringAfter('/');

        return fieldValue;
    }
    /**
     * @description : formate String (text) fields.
     */
    public static string formatString(string fieldValue, string formatType){
        Integer endIndex = (Integer) Integer.valueOf(formatType.substringAfter('L:'));
        endIndex = endIndex > fieldValue.length() ? fieldValue.length() : endIndex;             // endIndex must be less than value string length...
        fieldValue = fieldValue.substring(0, endIndex);

        return fieldValue;
    }
    /**
     * @description : formate Number, Precentage and Currecy fields.
     */
    public static string formatNumber(string fieldValue, string formatType){
        Decimal val = (Decimal) Decimal.valueOf(fieldValue);
        String format = formatType.substringBetween('F:', ',');
        String decimalPlaces = formatType.substringBetween('dP:', ',');
        String roundMode = formatType.substringBetween('rM:', ',');

        if(decimalPlaces != null){
            if(roundMode != null){
                System.RoundingMode rM = System.RoundingMode.valueOf(roundMode);
                val = val.setScale(Integer.valueOf(decimalPlaces), rM);
            }
            else{
                val = val.setScale(Integer.valueOf(decimalPlaces));
            }
        }

        if(format == 'yes'){
            fieldValue = val.format();

            // Standard format() method remove decimal if user did't set any decimal places at time of field creation...
            // So, when decimalPlaces is not 0, add decimal from our end as per formatKey...
            if(decimalPlaces != null && decimalPlaces != '0'){
                string valStr = (String) String.valueOf(val);
                String decimalValue = (String) String.valueOf(valStr.substringAfter('.'));
                if(fieldValue.contains('.')){
                    // when fieldValue contains any decimals..., remove standard decimal palces and add custom decimal palces...
                    fieldValue = val.format().substringBefore('.') + '.'+ decimalValue;
                }
                else{
                    // when fieldValue not contains any decimals...
                    fieldValue = val.format() + '.'+ decimalValue;
                }
            }

        }
        else{
            fieldValue = String.valueOf(val);
        }

        return fieldValue;
    }

    /**
    * Method Name : getListingMediaImages
    * @param String - listingId.
    * @description : Method to get Listing Media Images.
    * @return Map<String, String>.
    */
    public static Map<String, String> getListingMediaImages(String listingId){
        Map<String, String> images = new Map<String, String>();
        try {
            List<Listing__c> listingRecord = [SELECT Id, Property__c FROM Listing__c WHERE Id =: listingId WITH USER_MODE LIMIT 1];
            if (!listingRecord.isEmpty()) {
                
                String propertyId = listingRecord[0].Property__c;

                List<Property_File__c> media = [SELECT Id, BaseUrl__c FROM Property_File__c WHERE Property__c =: propertyId AND IsOnExpose__c = true AND Size__c != null WITH USER_MODE Order BY Sort_on_Expose__c ASC NULLS LAST, Name ASC];
                if (!media.isEmpty()) {
                    for (Integer i = 0; i < media.size(); i++) {
                        Property_File__c mediaItem = media[i];
                        images.put('listingMedia[' + (i + 1) + ']', mediaItem.BaseUrl__c);
                    }     
                }
            }
            return images;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'DataMappingControllerV2', 'getListingMediaImages', e.getMessage());
            return images;
        }
    }

    public static Map<String, Map<String, String>> getListingMediaImagesForMultipleRecords(Set<Id> listingIds) {
        Map<String, Map<String, String>> result = new Map<String, Map<String, String>>();
    
        if (listingIds == null || listingIds.isEmpty()) {
            return result;
        }
    
        try {
            // Step 1: Get all listings with their Property__c
            Map<Id, Id> listingIdToPropertyId = new Map<Id, Id>();
            for (Listing__c listing : [
                SELECT Id, Property__c 
                FROM Listing__c 
                WHERE Id IN :listingIds
                WITH USER_MODE
            ]) {
                listingIdToPropertyId.put(listing.Id, listing.Property__c);
            }
    
            // Step 2: Get all Property_File__c records in a single query
            Map<Id, List<Property_File__c>> propertyIdToFiles = new Map<Id, List<Property_File__c>>();
            for (Property_File__c file : [
                SELECT Id, BaseUrl__c, Property__c 
                FROM Property_File__c 
                WHERE Property__c IN :listingIdToPropertyId.values() 
                AND IsOnExpose__c = true 
                AND Size__c != null 
                WITH USER_MODE
                ORDER BY Sort_on_Expose__c ASC NULLS LAST, Name ASC
            ]) {
                if (!propertyIdToFiles.containsKey(file.Property__c)) {
                    propertyIdToFiles.put(file.Property__c, new List<Property_File__c>());
                }
                propertyIdToFiles.get(file.Property__c).add(file);
            }
    
            // Step 3: Build the result map
            for (Id listingId : listingIds) {
                Map<String, String> imageMap = new Map<String, String>();
                Id propertyId = listingIdToPropertyId.get(listingId);
    
                if (propertyId != null && propertyIdToFiles.containsKey(propertyId)) {
                    List<Property_File__c> mediaList = propertyIdToFiles.get(propertyId);
                    for (Integer i = 0; i < mediaList.size(); i++) {
                        imageMap.put('listingMedia[' + (i + 1) + ']', mediaList[i].BaseUrl__c);
                    }
                }
    
                result.put(listingId, imageMap);
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'DataMappingControllerV2', 'getListingMediaImagesForMultipleRecords', 'Error while getting multiple listing media images.');
        }
    
        return result;
    }    

    // === === === WRAPPER CLASSES ==== ===== ===

    /**
     * @description : wrapper class to store extracted key's info.
     */
    public class ExtractedKeys{
        @AuraEnabled public String mappingKey;
        @AuraEnabled public String fieldAPI;
        @AuraEnabled public String fieldType;
        @AuraEnabled public String formatType;
        @AuraEnabled public String value;
    }

    /**
     * @description : wrapper class to store extracted child Table info.
     */
    public class ChildTableInfo{
        @auraEnabled public String tableHTML;
        @AuraEnabled public String keyRow;
        @AuraEnabled public String infoRow;
        @AuraEnabled public String modifiedTableHTML; 
        @AuraEnabled public String queryFilters;
        @AuraEnabled public String queryLimit;
        @AuraEnabled public String childObjetAPI;
        @AuraEnabled public String childRelationshipName;
        @AuraEnabled public String mainRecordQuery;
        @AuraEnabled public String sourceObjectAPI;
        @AuraEnabled public List<String> mappingFields;
        @AuraEnabled public List<String> queryFields;
    }

    /**
     * @description : wrapper class to store list of fileds for multiple key type.
     */
    public class FieldListClass{
        @AuraEnabled public List<String> objectFields = new List<String>();
        @AuraEnabled public List<String> dateFields = new List<String>();
        @AuraEnabled public List<String> orgFields = new List<String>();
        @AuraEnabled public List<String> userFields = new List<String>();
    }
      

}