public with sharing class TemplateBuilderController {

    public static List<Template_Data__c> recordToInsert_global = new List<Template_Data__c>();
    public static List<Template_Data__c> recordToUpdate_global = new List<Template_Data__c>();
    public static List<Template_Data__c> recordToDelete_global = new List<Template_Data__c>();

    public class ObjectInfoWrapper {
        @AuraEnabled public Map<String, String> objectData { get; set; }
        @AuraEnabled public List<String> picklistValues { get; set; }
        @AuraEnabled public String status { get; set; }
    }

    /** 
   * Method Name: getAllObjectNames
   * @description: Get all objects names
   * @return ObjectInfoWrapper.
   * Date: 17/09/2024 
   * Created By: Karan Singh
   */ 
    @AuraEnabled
    public static ObjectInfoWrapper getAllObjectNames() {
        ObjectInfoWrapper objInfo = new ObjectInfoWrapper();

        try {
            Map<String, String> objectNamesMap = new Map<String, String>();
        
            Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
            for (String objectName : globalDescribe.keySet()) {
                Schema.SObjectType objectType = globalDescribe.get(objectName);
                if (objectType != null && !objectType.getDescribe().isDeprecatedAndHidden()) {
                    Schema.DescribeSObjectResult objResult = objectType.getDescribe();
                    
                    if (objResult.isAccessible() && objResult.isUpdateable() && objResult.isCreateable() && objResult.isQueryable() &&  objResult.isSearchable() && !objResult.isCustomSetting()) {
                        objectNamesMap.put(objResult.getName(), objResult.getLabel());
                    }
                }
            }

            objInfo.objectData = objectNamesMap;

            Schema.DescribeFieldResult fieldResult = Template__c.Template_pattern__c.getDescribe();
            List<Schema.PicklistEntry> picklistEntries = fieldResult.getPicklistValues();
            List<String> picklistValues = new List<String>();

            for (Schema.PicklistEntry entry : picklistEntries) {
                picklistValues.add(entry.getLabel());
            }

            objInfo.picklistValues = picklistValues;
            objInfo.status = 'success';

        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'TemplateBuilderController', 'getAllObjectNames', e.getMessage());
            objInfo.status = e.getMessage();
        }

        return objInfo;
    } 

    /** 
   * Method Name: insertTemplate
   * @description: Insert Template
   * @return Template__c id.
   * Date: 17/09/2024 
   * Created By: Karan Singh
   */ 
    @AuraEnabled
    public static String insertTemplate(Template__c template) {
        try {
            insert as user template;
            return template.Id;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'TemplateBuilderController', 'insertTemplate', e.getMessage());
            return e.getMessage();
        }
    }

    /**
     * @description : Wrapper class used to Store sorce object information.
     */
    public class Obj_Label_API{
        @AuraEnabled public String label;
        @AuraEnabled public String name;
        @AuraEnabled public String nameField;
        @AuraEnabled public String nameFieldType;
    }

    /**
   * @param {String} objectApiName - API Name of the object to get fields for.
   * @return Obj_Label_API,
   * @description : Method to get Object Label, Object Name field and its type from Its Object API Name
   */
    @AuraEnabled
    public static Obj_Label_API getObjectNameField(String objectApiName){
        try {
            Obj_Label_API objInfo = new Obj_Label_API();
            Schema.SObjectType sobjType = Schema.getGlobalDescribe().get(objectApiName);
            Schema.DescribeSObjectResult r = sobjType.getDescribe();
            Map<String, Schema.SObjectField> mapOfFields = r.fields.getMap();
    
            objInfo.label = Schema.getGlobalDescribe().get(objectApiName).getDescribe().getLabel();
            
            for(Schema.SObjectField field : mapOfFields.values()){
                if(field.getDescribe().isNameField()){
                    objInfo.nameField = field.getDescribe().getName();
                    objInfo.nameFieldType = (String) String.valueOf(field.getDescribe().getType());
                    return objInfo;
                }
            }
    
            objInfo.nameField = 'Id';
            return objInfo;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'TemplateBuilderController', 'getObjectNameField', e.getMessage());
            return null;
        }
    }

    public class TemplateDataWrapper{
        @AuraEnabled public String templateBody;
        @AuraEnabled public String mappingKeyVsMappingValues;
        @AuraEnabled public String salesforceImages;
    }

    @AuraEnabled
    public static TemplateDataWrapper getRecordsByObject(String recordId, String templateId) {
        try {
            String escapedTemplateId = String.escapeSingleQuotes(templateId);

            TemplateDataWrapper tdw = new TemplateDataWrapper();
            tdw.templateBody = '';
    
            List<Template__c> temp = [SELECT Id, Template_Name__c,
                                    (SELECT Id, Template_Value_Simple__c,Value_Type__c FROM Template_Data__r WHERE Value_Type__c = 'Body Value' ORDER BY Order_No_Simple__c ASC),
                                    (SELECT Id, Page_Margin__c, Page_Orientation__c, Page_Size__c, Unit_of_Page_Configs__c, Show_Header__c, Show_Footer__c, Header_margin_top__c, Footer_margin_bottom__c FROM Template_Pages__r ORDER BY Page_Number__c ASC)
                                    FROM Template__c WHERE Id =: escapedTemplateId WITH USER_MODE LIMIT 1 ];
    
            if(temp.size() > 0){
                for(Template_Data__c fieldData : temp[0].Template_Data__r){
                    String value = fieldData.Template_Value_Simple__c != null ? fieldData.Template_Value_Simple__c : '';
                    if(fieldData.Value_Type__c == 'Body Value'){
                        tdw.templateBody += value;
                    }
                }    
            }
    
            Map<String, Map<String, String>> mappingKeys = DataMappingControllerV2.getMappingsKeyValues(new List<String>{templateId}, recordId, true);
    
            tdw.mappingKeyVsMappingValues = JSON.serialize(mappingKeys.get('objectNGeneral'));
            tdw.salesforceImages = JSON.serialize(mappingKeys.get('salesforceImages'));
            
            return tdw;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'TemplateBuilderController', 'getRecordsByObject', e.getMessage());
            return null;
        }

    }

    /** 
   * Method Name: getTemplates
   * @description: Retrieves all Template__c records.
   * @return List of Template__c records.
   * Date: 11/06/2024 
   * Created By: Rachit Shah 
   */ 
    
    @AuraEnabled
    public static List<Template__c> getTemplates() {
        try {
            List<Template__c> templates = [SELECT Id, Name, Template_Name__c, Object_Name__c, Object_API_Name__c, Template_Status__c, Template_Body__c, Template_pattern__c, Description__c, CreatedDate, LastModifiedDate, Subject__c FROM Template__c WITH USER_MODE ORDER BY CreatedDate DESC LIMIT 50000];
            return templates;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'TemplateBuilderController', 'getTemplates', e.getMessage());
            return null;
        }

    }

    /** 
   * Method Name: deleteTemplate
   * @description: Deletes a Template__c record by its Id.
   * @param templateId Id of the template to delete.
   * @return void.
   * Date: 11/06/2024 
   * Created By: Rachit Shah 
   */ 

    @AuraEnabled
    public static void deleteTemplate(String templateId) {
        try {
            String escapedTemplateId = String.escapeSingleQuotes(templateId);
            List<Template__c> template = [SELECT Id FROM Template__c WHERE Id = :escapedTemplateId WITH USER_MODE LIMIT 1];
            if (template.size() > 0) {
                delete as user template;
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'TemplateBuilderController', 'deleteTemplate', e.getMessage());
        }

    }
    
    /**
   * Method Name: updateTemplateStatus
   * @description: Updates the status of a Template__c record by its Id.
   * @param templateId Id of the template to update.
   * @param status New status value.
   * @return void.
   * Date: 12/06/2024
   * Created By: Rachit Shah
   */
    @AuraEnabled
    public static void updateTemplateStatus(String templateId, Boolean status) {
        try {
            String escapedTemplateId = String.escapeSingleQuotes(templateId);
            List<Template__c> template = [SELECT Id, Template_Status__c FROM Template__c WHERE Id = :escapedTemplateId WITH USER_MODE LIMIT 1];
            if (template.size() > 0) {
                template[0].Template_Status__c = status;
                update as user template;
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'TemplateBuilderController', 'updateTemplateStatus', e.getMessage());
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
        @auraEnabled public Template__c template;
        @auraEnabled public Template_Page__c pageConfigs;
    }

    /**
    * @param {String} templateId, Id of template going to edit.
    * @return retrunWrapper,
    * @description : Method to get template record, template data, template pages, field mappings and the latest object API name from template data.
    */
    @AuraEnabled
    public static retrunWrapper getTemplateData(String templateId){
        RetrunWrapper retrunWrapper = new RetrunWrapper();
        try {
            String escapedTemplateId = String.escapeSingleQuotes(templateId);
            List<Template__c> temp = [SELECT Id, Name, Object_API_Name__c, Template_Name__c, Template_pattern__c, Template_Status__c, Description__c, CreatedDate, LastModifiedDate, createdBy.Name, lastModifiedBy.Name,
                                        (SELECT Id, Name, Template__c, Template_Value_Simple__c, Order_No_Simple__c, Value_Type__c FROM Template_Data__r WHERE Value_Type__c != null ORDER BY Order_No_Simple__c ASC )
                                        FROM Template__c WHERE Id =: escapedTemplateId WITH USER_MODE LIMIT 1];

            if(temp.size() > 0){
                retrunWrapper.isSuccess = true;

                List<Template_Page__c> pageConfigs = [SELECT Id, Name, Template__c, Page_Margin__c, Page_Orientation__c, Page_Size__c, Unit_of_Page_Configs__c, Show_Header__c, Show_Footer__c, Header_margin_top__c, Footer_margin_bottom__c 
                                                        FROM Template_Page__c WHERE Template__c =: temp[0].Id WITH USER_MODE ORDER BY Page_Number__c ASC  LIMIT 1];

                if(pageConfigs.size() == 0){
                    Template_Page__c page = new Template_Page__c();
                    page.Template__c = temp[0].Id;
                    page.Page_Number__c = 1;
                    page.Page_Margin__c = '1;1;1;1';        // [top;bottom;left;right]
                    page.Page_Orientation__c = 'portrait';
                    page.Page_Size__c = 'a4';
                    page.Unit_of_Page_Configs__c = 'in';
                    page.Show_Header__c = true;
                    page.Header_margin_top__c = 0.10;          // px to inch
                    page.Show_Footer__c = true;
                    page.Footer_margin_bottom__c = 0.10;       // px to inch
                    insert as user page;
                    pageConfigs = [SELECT Id, Name, Template__c, Page_Margin__c, Page_Orientation__c, Page_Size__c, Unit_of_Page_Configs__c, Show_Header__c, Show_Footer__c, Header_margin_top__c, Footer_margin_bottom__c 
                                    FROM Template_Page__c WHERE Id =: page.Id WITH USER_MODE ORDER BY Page_Number__c ASC LIMIT 1];
                }

                retrunWrapper.template = temp[0];
                retrunWrapper.pageConfigs = pageConfigs[0];
            } else {
                retrunWrapper.returnMessage = 'Template Not Found';
                retrunWrapper.isSuccess = false;
            }

            return retrunWrapper;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'TemplateBuilderController', 'getTemplateData', e.getMessage());
            retrunWrapper.isSuccess = false;
            retrunWrapper.returnMessage = e.getMessage();
            return retrunWrapper;
        }
    }

    /**
    * @param {Template__c} templateRecord, template record with basic field values,
    * @param {Map<String, List<String>>}, templateValues, Tempalce data with value as per value type,
    * @param {Template_Page__c}, pageConfigs, page config recor dwith field values,
    * @return {String} , update status
    * @description : Method to Save the Template data, page configs and field mappings.
    *               1. Update the Template record.
    *               2. Update the Page Configs record.
    *               3. Update the Template data with header, footer, mapping key data and body(if batch save is not rerequired).
    */
    @AuraEnabled
    public static string saveTemplateApex(Template__c templateRecord, Map<String, List<String>> templateValues, Template_Page__c pageConfigs, Integer listingCount){
        try {

            List<Template__c> temp = [SELECT Id, Name, Object_API_Name__c, Template_Name__c, ListingMediaCount__c, Template_pattern__c, Template_Status__c, Description__c, CreatedDate, LastModifiedDate,
                                        (SELECT Id, Name, Template__c, Template_Value_Simple__c, Order_No_Simple__c, Value_Type__c FROM Template_Data__r ORDER BY Order_No_Simple__c),
                                        (SELECT Id FROM Template_Pages__r) FROM Template__c WHERE Id =: templateRecord.Id WITH USER_MODE LIMIT 1];

            if(temp.size() > 0){
                Template__c templateToUpdate = temp[0];
                templateToUpdate.Template_Name__c = templateRecord.Template_Name__c;
                templateToUpdate.Template_Status__c = templateRecord.Template_Status__c;
                templateToUpdate.Description__c = templateRecord.Description__c;
                templateToUpdate.ListingMediaCount__c = listingCount;

                if(templateValues != null && templateValues.keySet().size() > 0){
                    for(String valueType : templateValues.keySet()){
                        Map<String ,String> templateValuesMap = new Map<String ,String>();
                        if(templateValues?.get(valueType)?.size() > 0){
                            for(Integer i = 1; i <= templateValues.get(valueType).size(); i++){
                                templateValuesMap.put(String.valueOf(i), templateValues.get(valueType)[i-1]);
                            }
                        }
                        else{
                            templateValuesMap.put('1', '');
                        }
                        saveTempDataRecords_forValueTypes( templateValuesMap , new Map<String, String>{temp[0].Id => valueType}, true);
                    }

                    if(recordToUpdate_global.size() < 10000) {
                        update as user recordToUpdate_global;
                    }
                    if(recordToInsert_global.size() < 10000) {
                        insert as user recordToInsert_global;
                    }
                    if(recordToDelete_global.size() < 10000) {
                        delete as user recordToDelete_global;
                    }
                }
                
                update as user templateToUpdate;

                update pageConfigs;

                return 'Template Updated Successfully';
            } else {
                return 'Template Not Found';
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'TemplateBuilderController', 'saveTemplateApex', e.getMessage());
            return null;
        }
    }

    /**
     * @param {Map<String, string>}, templateDataList, Map of batchOrderNumver vs template Data
     * @param {Map<String, String>}, tempIdVsValueType, Map of tempate Id vs template Value,
     * @param {boolean}, isLastBatch, to indentify last batch,
     * @description : Method Save body content data into template data object for multiple value type (i.e., Body, header, footer, mappingKeys).
     * Here, We are using global list to update template Data record to avoid DML in loop....
     */
    @AuraEnabled
    public static String saveTempDataRecords_forValueTypes(Map<String, string> templateDataList ,Map<String, String> tempIdVsValueType, boolean isLastBatch){
        try {
            Map<String, List<Template_Data__c>> dataToUpdate = setupTemplateDataForUpdate(templateDataList, tempIdVsValueType, isLastBatch);

            List<Template_Data__c> recordToInsert = dataToUpdate?.get('recordToInsert');
            List<Template_Data__c> recordToUpdate = dataToUpdate?.get('recordToUpdate');
            List<Template_Data__c> recordToDelete = dataToUpdate?.get('recordToDelete');

            if(recordToInsert != null && recordToInsert.size() > 0) recordToInsert_global.addAll(recordToInsert);
            if(recordToUpdate != null && recordToUpdate.size() > 0) recordToUpdate_global.addAll(recordToUpdate);
            if(recordToDelete != null && recordToDelete.size() > 0) recordToDelete_global.addAll(recordToDelete);

            return isLastBatch ? 'last batch update successfully' : 'batch update successfully';
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'TemplateBuilderController', 'saveTempDataRecords_forValueTypes', e.getMessage());
            return null;
        }
    }

    /**
    * @param {Map<String, string>}, templateDataList, Map of batchOrderNumver vs template Data
    * @param {Map<String, String>}, tempIdVsValueType, Map of tempate Id vs template Value,
    * @param {boolean}, isLastBatch, to indentify last batch,
    * @description : Method Save body content data into template data object in multiple batch to handle large size.
    */
    @AuraEnabled
    public static String saveTempDataRecordsInBatch(Map<String, string> templateDataList ,Map<String, String> tempIdVsValueType, boolean isLastBatch){
        try {
            Map<String, List<Template_Data__c>> dataToUpdate = setupTemplateDataForUpdate(templateDataList, tempIdVsValueType, isLastBatch);

            List<Template_Data__c> recordToInsert = dataToUpdate?.get('recordToInsert');
            List<Template_Data__c> recordToUpdate = dataToUpdate?.get('recordToUpdate');
            List<Template_Data__c> recordToDelete = dataToUpdate?.get('recordToDelete');

            if(recordToUpdate.size() < 1000) {
                update as user recordToUpdate;
            }
            if(recordToInsert.size() < 1000) {
                insert as user recordToInsert;
            }
            if(recordToDelete.size() < 1000) {
                delete as user recordToDelete;
            }

            return isLastBatch ? 'last batch update successfully' : 'batch update successfully';
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'TemplateBuilderController', 'saveTempDataRecordsInBatch', e.getMessage());
            return null;
        }
    }

    /**
     * @param {Map<String, string>}, templateDataList, Map of batchOrderNumver vs template Data
     * @param {Map<String, String>}, tempIdVsValueType, Map of tempate Id vs template Value,
     * @param {boolean}, isLastBatch, to indentify last batch,
     * @description : Method Setup List of Tempalte Data from Insert, Update and Delete as per contnet going to save...
     */
    public static Map<String, List<Template_Data__c>> setupTemplateDataForUpdate(Map<String, string> templateDataList ,Map<String, String> tempIdVsValueType, boolean isLastBatch){
        try {
            List<String> batchOrderNumber = new List<String>(templateDataList.keySet());
            Integer startOrderNumber = batchOrderNumber.size() > 0 ? Integer.valueOf(batchOrderNumber[0]) : 0;
            Integer endOrderNumber = batchOrderNumber.size() > 0 ? Integer.valueOf(batchOrderNumber[batchOrderNumber.size() - 1]) : 0;
            
            String tempId = new List<String>(tempIdVsValueType.keySet())[0];
            String valueType = tempIdVsValueType.get(tempId);
            String escapedTempId = String.escapeSingleQuotes(tempId);
            String escapedValueType = String.escapeSingleQuotes(valueType);
            
            List<Template_Data__c> storedTempDataRecords = [SELECT Id, Order_No_Simple__c, Template_Value_Simple__c, Value_Type__c FROM Template_Data__c
                                                                WHERE Template__c = : escapedTempId AND Order_No_Simple__c >= :startOrderNumber AND Order_No_Simple__c <= :endOrderNumber
                                                                AND Value_Type__c =: escapedValueType WITH USER_MODE ORDER BY Order_No_Simple__c ASC];

            Integer batchedStoredRecords =  storedTempDataRecords.size();
                                                                
            List<Template_Data__c> recordToInsert = new List<Template_Data__c>();
            List<Template_Data__c> recordToUpdate = new List<Template_Data__c>();
            List<Template_Data__c> recordToDelete = new List<Template_Data__c>();

            if(batchedStoredRecords > 0){
                for(Integer i = startOrderNumber; i <= endOrderNumber; i++){
                    // If recieved data records  is lesser than or equal to total stored record...
                    // Update All Record as per order number....
                    if(i <= (batchedStoredRecords + startOrderNumber - 1)){
                        Template_Data__c dt = storedTempDataRecords[i - startOrderNumber];
                        dt.Template_Value_Simple__c = templateDataList.get(String.valueOf(i));
                        recordToUpdate.add(dt);
                    }
                    // If revied data records  is lesser than stored record...
                    // Update All Record as per order number....
                    else if(i > (batchedStoredRecords + startOrderNumber - 1)){
                        Template_Data__c dt = new Template_Data__c();
                        dt.Template__c = tempId;
                        dt.Template_Value_Simple__c = templateDataList.get(String.valueOf(i));
                        dt.Order_No_Simple__c = (i);
                        dt.Value_Type__c = ValueType;
                        recordToInsert.add(dt);
                    }
                }
            } else {
                for(integer i = startOrderNumber; i <= endOrderNumber; i++){
                    Template_Data__c dt = new Template_Data__c();
                    dt.Template__c = tempId;
                    dt.Template_Value_Simple__c = templateDataList.get(String.valueOf(i));
                    dt.Order_No_Simple__c = (i);
                    dt.Value_Type__c = ValueType;
                    recordToInsert.add(dt);
                }
            }

            Integer totalStoredDataRecords = Database.countQuery('SELECT Count() FROM Template_Data__c WHERE Template__c =: escapedTempId AND Value_Type__c =: escapedValueType', AccessLevel.USER_MODE);

            if(isLastBatch && endOrderNumber < totalStoredDataRecords){
                // if it is last batch and endOrderNumber is lesser than totalStoredDataRecords...
                // Delete additon template data record....
                List<Template_Data__c> templateDataToDelete = [SELECT Id, Order_No_Simple__c, Template_Value_Simple__c, Value_Type__c FROM Template_Data__c
                                                                WHERE Template__c = : tempId AND Order_No_Simple__c >= :endOrderNumber + 1
                                                                AND Order_No_Simple__c <= :totalStoredDataRecords AND Value_Type__c =: valueType WITH USER_MODE
                                                                ORDER BY Order_No_Simple__c ASC LIMIT 50000];
                
                recordToDelete.addAll(templateDataToDelete);
            }
            

            return new Map<String, List<Template_Data__c>>{
                'recordToInsert' => recordToInsert,
                'recordToUpdate' => recordToUpdate,
                'recordToDelete' => recordToDelete
            };
        } catch(Exception e) {
            ErrorHandler.insertErrorData(e, 'TemplateBuilderController', 'setupTemplateDataForUpdate', e.getMessage());
            return null;
        }
    }

    public class TemplateRecord {
        @AuraEnabled public String listingName;
        @AuraEnabled public List<Template__c> templates;
    }

    @AuraEnabled
    public static TemplateRecord getListingAndTemplates(String recordId){
        TemplateRecord templateRecord = new TemplateRecord();
        try {
            String escapedRecordId = String.escapeSingleQuotes(recordId);
            List<Listing__c> listing = [SELECT Id, Name FROM Listing__c WHERE Id = :escapedRecordId WITH USER_MODE LIMIT 1];
            if(listing.size() > 0){
                templateRecord.listingName = listing[0].Name;
            }
            List<Template__c> templates = [SELECT Id, Template_Name__c FROM Template__c WHERE Object_API_Name__c = 'Listing__c' AND Template_Status__c = true WITH USER_MODE ORDER BY Template_Name__c ASC];
            templateRecord.templates = templates;
            
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'ListingPDFGeneratorController', 'getListingAndTemplates', 'Error while getting List of template records.');
        }
        return templateRecord;
    }
}