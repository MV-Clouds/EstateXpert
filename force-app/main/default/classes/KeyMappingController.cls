public with sharing class KeyMappingController {

    public static string mappingSymbol = '#';
    public static string childKeySymbol = '!';
    public static string tableIndexKey = '{{No.Index}}';
    public static string relatedObjKey = '{{#mappingKey}}';
    public static string generalFieldkeys = '{{Doc.mappingKey}}';
    public static string mergeTemplatekeys = '{{Temp.tempId}}';
    public static string formattingKeys = '*formatKey*';
    public static string signatureKey = '{{Sign.EXP *Signature Key*}}';
    public static List<string> imgTyes = new List<string>{'png','jpg','jpeg','avif','webp','heic','ico','jfif','jps','jpe'};
    public static integer maxImageSize = 20*1000*1000;  // 20MB
    public static list<string> polymorphismObjAllowdFields = new list<string>
    {
        'Alias', 'Email', 'FirstName', 'IsActive', 'LastName', 
        'LastReferencedDate', 'LastViewedDate', 'MiddleName', 'Name', 'Phone', 
        'Profile', 'Suffix', 'Title', 'Type', 'Username', 'UserRole', 'UserRoleId'
    };


    /**
     * Method Name : getFieldMappingKeys
     * @param sourceObjectAPI string 
     * @param getParentFields Boolean
     * @return retrunWrapper class
     * @description : Get Mapping Key for source object and its replated object.
     */
    @AuraEnabled
    public static retrunWrapper getFieldMappingKeys(String sourceObjectAPI, Boolean getParentFields, String templateId){
        RetrunWrapper retrunWrapper = new RetrunWrapper();
        try {
            if (templateId != null) {
                List<Template__c> tem = [SELECT Id, ListingMediaCount__c FROM Template__c WHERE Id =: templateId WITH USER_MODE];
                retrunWrapper.listingMediaCount = tem[0].ListingMediaCount__c != null ? tem[0].ListingMediaCount__c.round().intValue() : 1;
            }
            
            list<MappingObjects> objWithFields = new list<MappingObjects>();

            Obj_Label_API objLabelAPI = new Obj_Label_API();
            String sourceObjectName = Schema.getGlobalDescribe().get(sourceObjectAPI).getDescribe().getName();
            String sourceObjectLabel = Schema.getGlobalDescribe().get(sourceObjectAPI).getDescribe().getLabel();
            objLabelAPI.name = sourceObjectName;
            objLabelAPI.label = sourceObjectLabel;


            // add base (self) object in Object List...
            List<Schema.DescribeFieldResult> objectFieldSelf = getObjectFields(sourceObjectName, sourceObjectName);
            list<MappingFields> fieldMappingListSelf = new list<MappingFields>();
            for(Schema.DescribeFieldResult field : objectFieldSelf){
                if((String)String.valueOf(field.getType()) != 'ADDRESS' && (String)String.valueOf(field.getType()) != 'LOCATION'){
                    fieldMappingListSelf.add(createMappingFieldInstance(field, '', 'objectFields'));
                }
            }
            MappingObjects mapObjSelf = new MappingObjects();
            mapObjSelf.label = sourceObjectLabel;
            mapObjSelf.name = sourceObjectName;
            mapObjSelf.objectAPI = sourceObjectName;
            mapObjSelf.objectLabel = sourceObjectLabel;
            mapObjSelf.fieldMappings = fieldMappingListSelf;
            objWithFields.add(mapObjSelf);

            List<RelatedObjInfo> relatedObjects = getRelatedObjects(sourceObjectAPI);
            if(getParentFields == true){
                // add related Object in Object list...
                for(RelatedObjInfo relatedObj : relatedObjects){
                    MappingObjects mapObj = createMappingObj(relatedObj, sourceObjectLabel);
                    objWithFields.add(mapObj);
                }
            }

            // Assign Valus to Return Wrapper...
            retrunWrapper.isSuccess = getParentFields == true ? (relatedObjects != null ? true : false) : true;
            retrunWrapper.returnMessage = 'success';
            retrunWrapper.objectLabelAPI = objLabelAPI;
            retrunWrapper.fieldMappingsWithObj = objWithFields;
            return retrunWrapper;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'KeyMappingController', 'getFieldMappingKeys', e.getMessage());
            retrunWrapper.isSuccess = false;
            retrunWrapper.returnMessage = e.getMessage();
            return retrunWrapper;
        }
    }

    /**
     * Method Name : getRelatedObjects
     * @param sourceObjectAPI string
     * @return List<RelatedObjInfo> class
     * @description : Get Related Object using schema class
     */
    public static List<RelatedObjInfo> getRelatedObjects(String sourceObjectAPI) {
        try {
            Set<String> parentObjects = new Set<String>();
            List<RelatedObjInfo> relatedObjs = new List<RelatedObjInfo>();
            Map<String, Schema.SObjectField> mapOfFields = Schema.getGlobalDescribe().get(sourceObjectAPI).getDescribe().fields.getMap();
            for(String fieldName : mapOfFields.keySet()){
                Schema.SObjectField fieldObj = mapOfFields.get(fieldName);
                Schema.DescribeFieldResult field = fieldObj.getDescribe();
                if(field.getType() == Schema.DisplayType.REFERENCE){
                    RelatedObjInfo relatedObj = new RelatedObjInfo();
                    string fieldLabel = field.getLabel().contains(' ID') == true ? field.getLabel().substringBefore(' ID') : field.getLabel();
                    relatedObj.parentObjFieldLabel = fieldLabel;
                    relatedObj.parentObjRelationshipName = field.getRelationshipName();
                    relatedObj.parentObjFieldApi = fieldName;
                    relatedObj.parentObjApi = string.valueOf(field.getReferenceTo()[0]);
                    relatedObj.isCustome = field.isCustom();
                    relatedObjs.add(relatedObj);
                    parentObjects.add(string.valueOf(field.getReferenceTo()[0]));
                }
            }

            return relatedObjs;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'KeyMappingController', 'getRelatedObjects', 'Error while getting related objects.');
            return null;
        }
    }

    /**
     * Method Name : createMappingObj
     * @param relatedObj class
     * @param sourceObjectLabel string
     * @return List<RelatedObjInfo>, list of RelatedObjInfo class
     * @description : Method to collect object information using MappingObjects wrapper class
     */
    public static MappingObjects createMappingObj(RelatedObjInfo relatedObj, string sourceObjectLabel){

        try {
            list<MappingFields> fieldMappingList = new list<MappingFields>();
    
            // get Object Information...
            Schema.SObjectType sobjType = Schema.getGlobalDescribe().get(relatedObj.parentObjApi);
            String objLabel = sobjType.getDescribe().getLabel();
            String objName = relatedObj.parentObjApi;
    
            List<Schema.DescribeFieldResult> objectField = getObjectFields(relatedObj.parentObjApi, relatedObj.parentObjFieldApi);
            for(Schema.DescribeFieldResult field : objectField){
                // Does not incluse Compound fields...
                if((String)String.valueOf(field.getType()) != 'ADDRESS' && (String)String.valueOf(field.getType()) != 'LOCATION'){
                    fieldMappingList.add(createMappingFieldInstance(field, relatedObj.parentObjRelationshipName + '.', 'objectFields'));
                }
            }
    
            MappingObjects mapObj = new MappingObjects();
            mapObj.label = sourceObjectLabel +' > '+relatedObj.parentObjFieldLabel;
            mapObj.name = relatedObj.parentObjFieldApi;
            mapObj.objectAPI = relatedObj.parentObjApi;
            mapObj.objectLabel = objLabel;
            mapObj.fieldMappings = fieldMappingList;
    
            return mapObj;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'KeyMappingController', 'createMappingObj', 'Error while creating mapping object.');
            return null;
        }

    }

    /**
     * Method Name : getObjectFields
     * @param objAPI string
     * @return List<Schema.DescribeFieldResult>, list of Schema.DescribeFieldResult class
     * @description : Method to collect object field and its using schema class.
     */
    public static List<Schema.DescribeFieldResult> getObjectFields(String objAPI, String parentObjFieldApi){
        try {
            List<Schema.DescribeFieldResult> objectFields = new List<Schema.DescribeFieldResult>();

            Schema.SObjectType sobjType = Schema.getGlobalDescribe().get(objAPI);
            Schema.DescribeSObjectResult r = sobjType.getDescribe();
            Map<String, Schema.SObjectField> mapOfFields = r.fields.getMap();
            List<String> fieldsList = new List<String>(mapOfFields.keySet());
            fieldsList.sort();

            for(String fieldName : fieldsList){
                Schema.SObjectField field = mapOfFields.get(fieldName);
                Schema.DescribeFieldResult f = field.getDescribe();
                String fieldAPI = f.getName();
                if(String.valueOf(f.getType()) != 'BASE64'){
                    /**
                     * Here we are checking Object is polymorphism Object or not
                     * if user object is polymorphism then only add allowed field.
                     * Please refre : https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_name.htm?_ga=2.58130601.2080047266.1727784915-1598596746.1726841271
                     */
                    
                    if(objAPI != 'Group' && parentObjFieldApi != 'whatid' && parentObjFieldApi != 'whoid'){
                        objectFields.add(f);
                    }
                    else if(polymorphismObjAllowdFields.contains(fieldAPI) || f.isCustom()){
                        objectFields.add(f);
                    }
                }
            }

            return objectFields;

        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'KeyMappingController', 'getObjectFields', 'Error while getting object fields.');
            return null;
        }
    }

    /**
     * Method Name : getObjectFields
     * @param objAPI string
     * @return List<Schema.DescribeFieldResult>, list of Schema.DescribeFieldResult class
     * @description : Method to collect object field and its using schema class.
     */
    @AuraEnabled
    public static RetrunWrapper getChildObjects(string sourceObjectAPI){
        RetrunWrapper retrunWrapper = new RetrunWrapper();
        try {
            list<MappingObjects> childObjs = new list<MappingObjects>();

            Schema.SObjectType sobjType = Schema.getGlobalDescribe().get(sourceObjectAPI);
            Schema.DescribeSObjectResult sourceObj = sobjType.getDescribe();
            List<Schema.ChildRelationship> childObjects = sourceObj.getChildRelationships();
            for(Schema.ChildRelationship child :  childObjects){
                if(child.getRelationshipName() != null){
                    Schema.DescribeSObjectResult childObj = child.getChildSObject().getDescribe();
                    Schema.DescribeFieldResult childField = child.getField().getDescribe();
    
                    MappingObjects childObject = new MappingObjects();
                    childObject.label = childObj.getLabel();
                    // childObject.name = childObj.getName();
                    childObject.name = child.getRelationshipName();
                    childObject.objectAPI =  childObj.getName();
                    childObject.objectLabel = childObj.getLabel();
                    childObject.additionalInfo = childField.getLabel() + ' ('+ childField.getName() +')';
                    childObjs.add(childObject);
                }

            }

            retrunWrapper.isSuccess = true;
            retrunWrapper.fieldMappingsWithObj = childObjs;
            return retrunWrapper;

        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'KeyMappingController', 'getChildObjects', e.getMessage());
            retrunWrapper.isSuccess = false;
            return retrunWrapper;
        }
    }

    /**
     * Method Name : getGeneralFields
     * @return RetrunWrapper, RetrunWrapper class
     * @description : Method to collect All General Field for mapping keys.
     */
    @AuraEnabled
    public static RetrunWrapper getGeneralFields(){
        RetrunWrapper retrunWrapper = new RetrunWrapper();
        try {

            list<MappingObjects> customObj = new list<MappingObjects>();

            // create mapping for document creation Dates...
            customObj.add(getCreationDateMappings());

            MappingObjects userObject = new MappingObjects();
            userObject.label = 'User Details';
            userObject.name = 'creationUser';
            list<MappingFields> userObjFields = new list<MappingFields>();
            List<Schema.DescribeFieldResult> userObjFieldsSchema = getObjectFields('User', 'user');
            for(Schema.DescribeFieldResult f : userObjFieldsSchema){
                if((String)String.valueOf(f.getType()) != 'ADDRESS' && (String)String.valueOf(f.getType()) != 'LOCATION'){
                    MappingFields field = createMappingFieldInstance(f, 'User.', 'generalFields');
                    userObjFields.add(field);
                }
            }
            userObject.fieldMappings = userObjFields;
            customObj.add(userObject);

            MappingObjects organizationObject = new MappingObjects();
            organizationObject.label = 'Organization Details';
            organizationObject.name = 'organization';
            list<MappingFields> organization = new list<MappingFields>();
            List<Schema.DescribeFieldResult> organizationObjFieldsSchema = getObjectFields('Organization', 'organization');
            for(Schema.DescribeFieldResult f : organizationObjFieldsSchema){
                if((String)String.valueOf(f.getType()) != 'ADDRESS' && (String)String.valueOf(f.getType()) != 'LOCATION'){
                    MappingFields field = createMappingFieldInstance(f, 'Org.', 'generalFields');
                    organization.add(field);
                }
            }
            organizationObject.fieldMappings = organization;
            customObj.add(organizationObject);

            retrunWrapper.isSuccess = true;
            retrunWrapper.fieldMappingsWithObj = customObj;
            return retrunWrapper;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'KeyMappingController', 'getGeneralFields', e.getMessage());
            retrunWrapper.isSuccess = false;
            retrunWrapper.returnMessage = e.getMessage();
            return retrunWrapper;
        }
    }
    /**
     * Method Name : getCreationDateMappings
     * @return MappingObjects, MappingObjects class
     * @description : Method to create date mapping keys.
     */
    public static MappingObjects getCreationDateMappings(){
        MappingObjects dateMapping = new MappingObjects();
        dateMapping.label = 'Dates';
        dateMapping.name = 'creationDates';
        try {

            list<MappingFields> dateFields = new list<MappingFields>();

            map<string, string> dateFormats = dateFormats();

            for(string dateInfo : dateFormats.keySet()){
                string fieldName = 'Date.'+dateInfo;
                string fieldKey = generalFieldkeys.replace('mappingKey', 'Date.'+dateInfo);
                String fieldLabel = dateFormats.get(dateInfo).split(';')[0];
                String fieldType = dateFormats.get(dateInfo).split(';')[1];
                String isFormatReq = dateFormats.get(dateInfo).split(';')[2];

                MappingFields fieldMapping = new MappingFields();
                fieldMapping.label = fieldLabel;
                fieldMapping.name = fieldName;
                fieldMapping.key = fieldKey;
                fieldMapping.type = fieldType;
                fieldMapping.isFormatReq = Boolean.valueOf(isFormatReq);

                dateFields.add(fieldMapping);
            }

            dateMapping.fieldMappings = dateFields;
            return dateMapping;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'KeyMappingController', 'getCreationDateMappings', 'Error while getting creation date mappings.');
            return dateMapping;
        }
    }

    /**
     * Method Name : dateFormats
     * @return map<string, string>
     * @description : Method to create option for creation date mapping key.
     */
    public static map<string, string> dateFormats(){
        datetime cTime = datetime.now();

        map<string, string> dateFormats = new map<string, string>{
         // 'key' =>        'label;fieldType;isFormatReq;value'
            'date'      => 'Document Creation Date & Time;DATETIME;true;' + cTime,
            'time'      => 'Document Creation Time;TIME;true;' + cTime.format('HH:mm:ss'),
            'Wday'      => 'Document Creation Week Day;INTEGER;false;' + cTime.format('F'),
            'Mday'      => 'Document Creation Month Day;INTEGER;false;' + cTime.format('dd'),
            'Yday'      => 'Document Creation Year Day;INTEGER;false;' + cTime.format('DDD'),
            'WdayName'  => 'Document Creation Week Day Name;STRING;true;' + cTime.format('EEEEE'),
            'month'     => 'Document Creation Month;INTEGER;false;'+ cTime.format('MM'),
            'monthName' => 'Document Creation Month Name;STRING;true;'+ cTime.format('MMMMM'),
            'Year'      => 'Document Creation Year;STRING;false;'+ cTime.format('yyyy')
        };

        return dateFormats;      
    }

    /**
     * Method Name : getMerginTemplateKeys
     * @param sourceObjectAPI string
     * @return RetrunWrapper
     * @description : Method to create mapping key for merge template.
     */
    @AuraEnabled
    public static RetrunWrapper getMerginTemplateKeys(string sourceObjectAPI, String templateId){
        RetrunWrapper retrunWrapper = new RetrunWrapper();
        try {
            List<Template__c> activeTemps = [SELECT Id, Name, Template_Name__c FROM Template__c WHERE Template_Status__c = true AND Id != :templateId AND Template_pattern__c IN ('PDF Template') AND Object_API_Name__c =: sourceObjectAPI WITH USER_MODE];
            if(activeTemps != null){
                list<MappingObjects> fieldMappingsWithObj = new list<MappingObjects>();
                MappingObjects mergeTemps = new MappingObjects();
                list<MappingFields> fieldMappings = new list<MappingFields>();
                mergeTemps.name = 'Merge Tempaltes';
                mergeTemps.name = 'megreTempaltes';
                for(Template__c temp : activeTemps){
                    MappingFields tempKeys = new MappingFields();
                    tempKeys.label = temp.Template_Name__c;
                    tempKeys.name = temp.Id;
                    tempKeys.key = mergeTemplatekeys.replace('tempId', temp.Id +' '+ formattingKeys.replace('formatKey', temp.Template_Name__c));
                    fieldMappings.add(tempKeys);
                }
                mergeTemps.fieldMappings = fieldMappings;
                fieldMappingsWithObj.add(mergeTemps);
                retrunWrapper.fieldMappingsWithObj = fieldMappingsWithObj;
            }
            else{
                retrunWrapper.returnMessage = 'There is No Active Tempale Avalibale To Merge';
            }

            retrunWrapper.isSuccess = true;
            return retrunWrapper;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'KeyMappingController', 'getMerginTemplateKeys', e.getMessage());
            retrunWrapper.isSuccess = false;
            retrunWrapper.returnMessage = e.getMessage();
            return retrunWrapper;
        }
    }

    /**
     * Method Name : getAllContentVersionImgs
     * @return RetrunWrapper
     * @description : Method to collect all content version.
    */
    @AuraEnabled
    public static RetrunWrapper getAllContentVersionImgs(String templateType){
        RetrunWrapper retrunWrapper = new RetrunWrapper();
        try {
            // for Google Doc Template we have set max image size to 1000MB, meanse no size limit
            maxImageSize = templateType == 'Google Doc Template' ? 1000*1000*1000 : maxImageSize;

            List<ContentVersion>  allImgCV = new List<ContentVersion>();
            if (maxImageSize != null) {
                allImgCV = [SELECT Id, Title, FileExtension, FileType, VersionDataUrl, ContentSize, IsLatest, ContentDocumentId FROM ContentVersion WHERE FileExtension IN: imgTyes AND IsLatest = true AND ContentSize < :maxImageSize WITH USER_MODE];
            }

            /**
             * Note : We only allow image with public download url, So we get ContentDownloadUrl from ContentDistribution.
             * There are some contentVersion that not allow public sharing, so we can not create ContentDistribution for corresponding contentVersion. 
             */

            if(allImgCV.size() > 0){
                Map<Id, String> cvIdVsImageUrl = new Map<Id, String>();
    
                Set<Id> cDocIds = new Set<Id>();

                for(ContentVersion cv : allImgCV){
                    cDocIds.add(cv.ContentDocumentId);
                }

                // System.debug('total images : ' + cDocIds.size());

                // ...Get All ContentDistribution for existing ContentVersion...
                List<ContentDistribution> allICDs = [SELECT Id, ContentVersionId, ContentDocumentId FROM ContentDistribution WHERE ContentDocumentId IN :cDocIds WITH USER_MODE];

                // ...Collect all ContentVersion Id which have ContentDistribution created...
                Set<Id> cdAvilabeFor = new Set<Id>();
                for(ContentDistribution cd : allICDs){
                    cdAvilabeFor.add(cd.ContentDocumentId);
                }

                // ...Collect all ContentDocumentation Id which does not have ContentDistribution created...
                // ... It mease we does not have public download and share link for these images....
                Set<Id> cdNotAvailabeFor = new Set<Id>(cDocIds);
                cdNotAvailabeFor.removeAll(cdAvilabeFor);

                // collect all ContentVersion with sharing to create ContentDistribution on it...
                Map<Id, String> cdTocreatefor = new Map<Id, String>();
                for(ContentVersion cv : allImgCV){
                    if(cdNotAvailabeFor.contains(cv.ContentDocumentId)){
                        cdTocreatefor.put(cv.Id, cv.Title);
                    }
                }

                // Create ContentDistribution Object for ContentVersion which does not have Cd...
                List<ContentDistribution> cdToCreate = new List<ContentDistribution>();
                for(Id cvId : cdTocreatefor.keySet()){
                    ContentDistribution cd = new ContentDistribution();
                    cd.ContentVersionId = cvId;
                    cd.Name = cdTocreatefor.get(cvId);
                    cdToCreate.add(cd);
                }

                // ...Collect all ContentDocumnet for debug purpose to check whether the are created or not...
                Set<Id> cdWithPublicSharing = new Set<Id>();
                Set<Id> cdWithoutPublicSharing = new Set<Id>();

                // Insert ContentDistribution using Database.insert to avoid rollback and get insert result for each ContentDistribution
                if(cdToCreate.size() > 0){
                    Database.SaveResult[] results = Database.insert(cdToCreate, false, AccessLevel.USER_MODE);
                    // Iterate through the results to check which records were successful and which failed
                    for (Integer i = 0; i < results.size(); i++) {
                        if (results[i].isSuccess()) {
                            // Record was successfully inserted
                            // System.debug('Successfully inserted record: ' + cdToCreate[i].Id);
                            cdWithPublicSharing.add(cdToCreate[i].Id);
                        } else {
                            // Record failed to insert, Mease Image does not have public char option...
                            cdWithoutPublicSharing.add(cdToCreate[i].Id);
                        }
                    }
                }

                // Agian Quuery all ContentDistribution with ContentDownloadUrl...
                // At this time we have ContentDistribution for all ContentVersion that have public sharing....
                List<ContentDistribution> allICDs2 = new List<ContentDistribution>(); 
                if (maxImageSize != null) {
                    allICDs2 = [SELECT Id, ContentVersionId, ContentVersion.Title, ContentVersion.FileExtension, ContentVersion.FileType, ContentVersion.ContentSize, ContentDownloadUrl FROM ContentDistribution WHERE ContentDocumentId IN :cDocIds AND ContentVersion.IsLatest =true AND ContentVersion.ContentSize < :maxImageSize WITH USER_MODE];
                }

                // Collect ContentVersion and ContentDownloadUrl into map...
                for(ContentDistribution cd : allICDs2){
                    cvIdVsImageUrl.put(cd.ContentVersionId, cd.ContentDownloadUrl);
                }

                retrunWrapper.cdImages = allICDs2;
                retrunWrapper.isSuccess = true;
            }
            else{
                retrunWrapper.returnMessage = 'zero_imgs';
                retrunWrapper.isSuccess = false;
            }
            
            return retrunWrapper;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'KeyMappingController', 'getAllContentVersionImgs', e.getMessage());
            retrunWrapper.isSuccess = false;
            retrunWrapper.returnMessage = e.getMessage();
            return retrunWrapper;
        }
    }
    
    /**
     * Method Name : getSignatureInfo
     * @return Decimal
     * @description : Method to collect signature size.
    */
    @AuraEnabled 
    public static Decimal getSignatureInfo(String templateId){
        Decimal signatureSize = 50;
        
        List<Template__c> temp = new List<Template__c>();
        if (templateId != null) {
            temp = [SELECT Id, Signature_Size__c FROM Template__c WHERE Id =: templateId WITH USER_MODE];
        }

        if(temp.size() > 0){
            signatureSize = temp[0].Signature_Size__c != null ? temp[0].Signature_Size__c : 50;
        }
        
        return signatureSize;
    }

    /**
     * Method Name : updateSignatureInfo
     * @return boolean
     * @description : Method to update signature size.
    */
    @AuraEnabled 
    public static boolean updateSignatureInfo(String templateId, Decimal signatureSize){
        try {
            Template__c temp = new Template__c(Id = templateId, Signature_Size__c = signatureSize);
            update as user temp;
            return true;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'KeyMappingController', 'updateSignatureInfo', e.getMessage());
            return false;
        }
    }

    /**
     * Method Name : createMappingFieldInstance
     * @param field
     * @param parentObjKey
     * @param mappingType
     * @return MappingFields
     * @description : Method to create MappingFields instance to store field information and generate mapping key using that infos.
    */
    public static MappingFields createMappingFieldInstance(Schema.DescribeFieldResult field, string parentObjKey, string mappingType){
        try {
            String fieldKey = '';
            if(mappingType == 'objectFields'){
                fieldKey = relatedObjKey.replace('mappingKey', parentObjKey+field.getName());
            }
            else if(mappingType == 'generalFields'){
                fieldKey = generalFieldkeys.replace('mappingKey', parentObjKey+field.getName());
            }

            MappingFields fieldMapping = new MappingFields();
            fieldMapping.label = (String)String.valueOf(field.getLabel());
            fieldMapping.name = parentObjKey + (String)String.valueOf(field.getName());
            fieldMapping.key = fieldKey;

            String fieldType = (String)String.valueOf(field.getType());
            fieldMapping.type = fieldType;

            if( fieldType == 'DATE' || fieldType == 'DATETIME' ||  fieldType == 'TIME' || fieldType == 'BOOLEAN' || fieldType == 'STRING' || 
                fieldType == 'INTEGER' || fieldType == 'DOUBLE' || fieldType == 'CURRENCY' || fieldType == 'PERCENT'){
                fieldMapping.isFormatReq = true;
            }
            else { 
                fieldMapping.isFormatReq = false; 
            }

            // Check if the field is a picklist
            if(field.getType() == Schema.DisplayType.PICKLIST || field.getType() == Schema.DisplayType.MULTIPICKLIST) {
                // Get picklist values
                // Add picklist values to the field wrapper
                fieldMapping.picklistValues = getPicklistValue(field);
            } else {
                // For non-picklist fields, set picklist values to null
                fieldMapping.picklistValues = null;
            }

            fieldMapping.isSearchable = field.isFilterable();

            return fieldMapping;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'KeyMappingController', 'createMappingFieldInstance', 'Error while creating mapping field instance.');
            return null;
        }
    }

    /**
     * Method Name : getPicklistValue
     * @param field
     * @return list<String>
     * @description : Method to get picklist values for picklist field.
    */
    public static list<String> getPicklistValue(Schema.DescribeFieldResult field){

        try {
            List<String> picklistValues = new List<String>();
            Schema.PicklistEntry[] picklistEntries = field.getPicklistValues();
            if(picklistEntries != null && picklistEntries.size() > 0) {
                for(Schema.PicklistEntry entry : picklistEntries) {
                    picklistValues.add(entry.getLabel());
                }
            }
            return picklistValues;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'KeyMappingController', 'getPicklistValue', 'Error while getting picklist values.');
            return null;
        }

    }

    /**
     * Method Name : formattingFieldKeys
     * 
     * @return RetrunWrapper
     * @description : Method to craete formatting key to generate formated field key to format field value.
    */
    @AuraEnabled
    public static RetrunWrapper formattingFieldKeys(){

        try {
            RetrunWrapper retrunWrapper = new RetrunWrapper();
            list<FormattingField> listOFformattingField = new list<FormattingField>();
    
            FormattingField dateFormatting = new FormattingField();
            map<string, string> dateFormats = new map<string, string>{
                'dd/MM/yyyy' => 'DD/MM/YYYY (31/12/2023)',
                'dd/MM/yy' => 'DD/MM/YY (31/12/23)',
                'MM/dd/yyyy' => 'MM/DD/YYYY (12/31/2023)',
                'MM/dd/yy' => 'MM/DD/YY (12/31/23)',
                'yyyy/MM/dd' => 'YYYY/MM/DD (2023/12/31)',
                'dd MMMM yyyy' => 'DD Month YYYY (31 December 2023)',
                'dd MMM yyyy' => 'DD Mon YYYY (31 Dec 2023)',
                'dd MMMM, yyyy' => 'DD Month, YYYY (31 December, 2023)',
                'dd MMM, yyyy' => 'DD Mon, YYYY (31 Dec, 2023)',
                'MMMM dd, yyyy' => 'Month DD, YYYY (December 31, 2023)',
                'MMM dd, yyyy' => 'Mon DD, YYYY (December 31, 2023)',
                'yyyy, MMMM dd' => 'YYYY, Month DD (2023, December 31)',
                'yyyy, MMM dd' => 'YYYY, Mon DD (2023, December 31)'
            };
            dateFormatting.formatType = 'DATE';
            list<MappingFields> mappingFields = new list<MappingFields>();
            for(string formatType : dateFormats.keyset()){
                MappingFields dateFormat = new MappingFields();
                dateFormat.label = dateFormats.get(formatType);
                dateFormat.name = formatType;
                dateFormat.formatKey = formattingKeys.replace('formatKey', formatType);
                mappingFields.add(dateFormat);
            }
            dateFormatting.fieldMappings = mappingFields;
            listOFformattingField.add(dateFormatting);
    
            FormattingField timeFormatting = new FormattingField();
            map<String, String> timeFormats = new map<String, String>{
                'HH:mm:ss' => 'HH:mm:ss (12:59:00)',
                'HH:mm' => 'HH:mm (12:59)',
                'HH' => 'HH (12)',
                'mm' => 'mm (59)',
                'ss' => 'ss (00)',
                'hh:mm:ss aaa' => 'hh:mm:ss aaa (12:59:00 PM)',
                'hh:mm aaa' => 'hh:mm aaa (12:59 PM)'
            };
            timeFormatting.formatType = 'TIME';
            list<MappingFields> mappingFields2 = new list<MappingFields>();
            for(string formatType : timeFormats.keyset()){
                MappingFields timeFormat = new MappingFields();
                timeFormat.label = timeFormats.get(formatType);
                timeFormat.name = formatType;
                timeFormat.formatKey = formattingKeys.replace('formatKey', formatType);
                mappingFields2.add(timeFormat);
            }
            timeFormatting.fieldMappings = mappingFields2;
            listOFformattingField.add(timeFormatting);
    
            retrunWrapper.isSuccess = true;
            retrunWrapper.fieldFormatting = listOFformattingField;
            retrunWrapper.signatureKey = signatureKey;
            return retrunWrapper;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'KeyMappingController', 'formattingFieldKeys', 'Error while formatting field keys.');
            return null;
        }

    }

    /**
     * @description : Wrapper class used to return values to lwc component.
     * It is generic class that used by mupltiple methods.
     */
    public class RetrunWrapper{
        @AuraEnabled public boolean isSuccess;
        @AuraEnabled public String returnMessage;
        @AuraEnabled public Obj_Label_API objectLabelAPI;
        @AuraEnabled public list<MappingObjects> fieldMappingsWithObj;
        @auraEnabled public Template__c template;
        @auraEnabled public List<ContentDistribution> cdImages;
        @auraEnabled public list<FormattingField> fieldFormatting;
        @AuraEnabled public String signatureKey;
        @AuraEnabled public Integer listingMediaCount;
     }

     /**
      * @description : wrapper class to create combobox option directly from apex.
      It store Object API name and label
      */
    public class Obj_Label_API{
        @AuraEnabled public String label;
        @AuraEnabled public String name;
    }

    /**
     * @description : wrapper class to information of sObjects.
     */
    public class MappingObjects{
        @AuraEnabled public String label;
        @AuraEnabled public String name;
        @AuraEnabled public String fieldAPI;
        @auraEnabled public String objectLabel;
        @auraEnabled public String objectAPI;
        @auraEnabled public String additionalInfo;
        @AuraEnabled public list<MappingFields> fieldMappings;
    }

    /**
     * @description : wrapper class to information of object's field.
     */
    public class MappingFields{
        @AuraEnabled public String label;
        @AuraEnabled public String name;
        @AuraEnabled public String key;
        @AuraEnabled public String type;
        @AuraEnabled public String formatKey;
        @AuraEnabled public Boolean isSearchable;
        @AuraEnabled public Boolean isFormatReq;
        @AuraEnabled public Boolean isDate;
        @AuraEnabled public Boolean isDateTime;
        @AuraEnabled public Boolean isCheckbox;
        @AuraEnabled public Boolean isPhone;
        @AuraEnabled public Boolean isURL;
        @AuraEnabled public List<String> picklistValues;
    }

    /**
     * @description : wrapper class to information of source object's related(parent) object's information.
     */
    public class RelatedObjInfo{
        @auraEnabled public string parentObjFieldLabel;
        @auraEnabled public string parentObjRelationshipName;
        @auraEnabled public string parentObjFieldApi;
        @auraEnabled public string parentObjApi;
        @auraEnabled public boolean isCustome;
    }

    /**
     * @description : wrapper class to information of formatting field type and respective format options as list.
     */
    public class FormattingField{
        @AuraEnabled public string formatType;
        @AuraEnabled public list<MappingFields> fieldMappings;
    }
}