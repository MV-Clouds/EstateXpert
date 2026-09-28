/**
* Class Name : CheckListItemController
* Test Class : pending
* Created By : Karan Singh
* Last Modified Date : 23/12/2024
* Last Modified By : Karan Singh
* @description : Used to get object fields and name.
*/
public with sharing class CheckListItemController {

    /**
    * Class Name : FieldWrapper
    * @description : Used to get field label and value.
    */
    public class FieldWrapper {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public String type;
        @AuraEnabled public List<String> picklistValues;
        @AuraEnabled public String referenceTo;
    }

    /**
    * Class Name : ObjectFieldsWrapper
    * @description : Used to get object fields and name.
    */
    public class ObjectFieldsWrapper {
        @AuraEnabled public String label;
        @AuraEnabled public List<FieldWrapper> fields;
        @AuraEnabled public List<MVEX__Checklist__c> checklist;
    }

    /**
    * Method Name : getObjectFields
    * @param objectName - String
    * @description : Used to get object fields and name.
    * @return ObjectFieldsWrapper having return type ObjectFieldsWrapper.
    */
    @AuraEnabled
    public static ObjectFieldsWrapper getObjectFields(String objectName){
        ObjectFieldsWrapper result = new ObjectFieldsWrapper();
        result.fields = new List<FieldWrapper>();
        result.checklist = new List<MVEX__Checklist__c>();
        try {
            result.checklist = [SELECT Id, Name, MVEX__Field_Name__c, MVEX__Object_Name__c, MVEX__Operator__c, MVEX__Sequence__c, MVEX__Value__c, MVEX__Description__c, MVEX__Data_Type__c FROM MVEX__Checklist__c WHERE MVEX__Object_Name__c = :objectName WITH USER_MODE ORDER BY MVEX__Sequence__c NULLS LAST, Name];
            
            // Get the object's label
            Schema.DescribeSObjectResult describeSObjectResult = Schema.getGlobalDescribe().get(objectName).getDescribe();
            result.label = describeSObjectResult.getLabel();
            
            // Get the object's fields
            Map<String, Schema.SObjectField> fieldsMap = describeSObjectResult.fields.getMap();
            for (String fieldName : fieldsMap.keySet()) {
                Schema.DescribeFieldResult fieldDescribe = fieldsMap.get(fieldName).getDescribe();
                FieldWrapper fieldInfo = new FieldWrapper();
                fieldInfo.label = fieldDescribe.getLabel();
                fieldInfo.value = fieldName;

                List<String> textFields = new List<String>{'STRING', 'TEXTAREA', 'ID'};
                List<String> numberFields = new List<String>{'DOUBLE', 'PHONE'};

                String fieldType = fieldDescribe.getType().name();

                if (textFields.contains(fieldType)) {
                    fieldInfo.type = 'TEXT';
                } else if (numberFields.contains(fieldType)) {
                    fieldInfo.type = 'NUMBER';
                } else {
                    fieldInfo.type = fieldType;
                }

                fieldInfo.picklistValues = new List<String>();

                if (fieldDescribe.getType() == Schema.DisplayType.Picklist || fieldDescribe.getType() == Schema.DisplayType.MultiPicklist) {
                    List<Schema.PicklistEntry> picklistEntries = fieldDescribe.getPicklistValues();
                    for (Schema.PicklistEntry entry : picklistEntries) {
                        fieldInfo.picklistValues.add(entry.getLabel());
                    }
                }
                
                else if (fieldDescribe.getType() == Schema.DisplayType.Boolean) {
                    fieldInfo.picklistValues.add('true');
                    fieldInfo.picklistValues.add('false');
                }

                else if (fieldDescribe.getType() == Schema.DisplayType.Reference) {
                    List<Schema.SObjectType> referenceToList = fieldDescribe.getReferenceTo();
                    if (!referenceToList.isEmpty()) {
                        fieldInfo.referenceTo = referenceToList[0].getDescribe().getName();
                    }
                }

                result.fields.add(fieldInfo);
            }
            
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'CheckListItemController', 'getObjectFields', 'Error while getting object fields.');
        }
        return result;
    }

    /**
    * Class Name : ChecklistProgressData
    * @description : Used to get checklist progress details.
    */
    public class ChecklistProgressData {
        @AuraEnabled public Boolean isEditable;
        @AuraEnabled public List<ChecklistWrapper> checklistData;
    }

    /**
    * Class Name : ChecklistWrapper
    * @description : Used to get checklist details.
    */
    public class ChecklistWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String type;
        @AuraEnabled public String fieldName;
        @AuraEnabled public String description;
        @AuraEnabled public String fieldLabel;
        @AuraEnabled public String objectName;
        @AuraEnabled public String operator;
        @AuraEnabled public String value;
        @AuraEnabled public String displayValue;
        @AuraEnabled public Boolean completed;
        @AuraEnabled public Boolean showDropdown;
        @AuraEnabled public Boolean isDescription;
    }

    /**
    * Method Name : getCheckList
    * @param objectName - String
    * @param recordId - String
    * @description : Used to get checklist details.
    * @return List<ChecklistWrapper> having return type List<ChecklistWrapper>.
    */
    @AuraEnabled
    public static ChecklistProgressData getCheckList(String objectName, String recordId) {
        try {
            ChecklistProgressData checklistDataToShow = new ChecklistProgressData();
            checklistDataToShow.isEditable = false;
            checklistDataToShow.checklistData = new List<ChecklistWrapper>();

            if (Schema.sObjectType.MVEX__Checklist__c.isCreateable() && Schema.sObjectType.MVEX__Checklist__c.isUpdateable()) {
                checklistDataToShow.isEditable = true;
            }

            List<MVEX__Checklist__c> checkList = [SELECT Id, Name, MVEX__Field_Name__c, MVEX__Object_Name__c, MVEX__Operator__c, MVEX__Sequence__c, MVEX__Value__c, MVEX__Description__c, MVEX__Data_Type__c
                                            FROM MVEX__Checklist__c WHERE MVEX__Object_Name__c = :objectName WITH USER_MODE ORDER BY MVEX__Sequence__c NULLS LAST, Name];

            List<MVEX__Checklist_Item__c> checklistItem = [SELECT Id, MVEX__Checklist__c, MVEX__Is_Checked__c, MVEX__Record_Id__c FROM MVEX__Checklist_Item__c 
                                                        WHERE MVEX__Record_Id__c = :recordId WITH USER_MODE];

            Schema.SObjectType sObjectType = Schema.getGlobalDescribe().get(objectName);
            if (sObjectType == null) {
                ErrorHandler.insertErrordata(null, 'CheckListItemController', 'getCheckList', 'Invalid object name: ' + objectName + ' at line 156.');
                return null;
            }
            Schema.DescribeSObjectResult describeResult = sObjectType.getDescribe();
            Map<String, Schema.SObjectField> fieldMap = describeResult.fields.getMap();
            List<String> fieldNames = new List<String>(fieldMap.keySet());

            // Build dynamic SOQL query
            String allFieldsName = String.join(fieldNames, ',');
            String queryFields = String.escapeSingleQuotes(allFieldsName);
            String sobjectName = String.escapeSingleQuotes(objectName);
            String query = 'SELECT ' + queryFields + ' FROM ' + sobjectName + ' WHERE Id = :recordId LIMIT 1';
            SObject sObjectRecord = Database.query(query, AccessLevel.USER_MODE);

            for (MVEX__Checklist__c item : checkList) {
                ChecklistWrapper wrapper = new ChecklistWrapper();
                wrapper.id = item.Id;
                wrapper.name = item.Name;
                wrapper.description = item.MVEX__Description__c;
                wrapper.fieldName = item.MVEX__Field_Name__c;
                wrapper.objectName = item.MVEX__Object_Name__c;
                wrapper.operator = item.MVEX__Operator__c;
                wrapper.value = item.MVEX__Value__c;
                 wrapper.type = item.MVEX__Data_Type__c;
                wrapper.completed = false;
                wrapper.showDropdown = false;
                wrapper.isDescription = item.MVEX__Description__c != null && item.MVEX__Description__c != '' ? true : false;

                // Set the field label
                if (item.MVEX__Field_Name__c != null && fieldMap.containsKey(item.MVEX__Field_Name__c)) {
                    wrapper.fieldLabel = fieldMap.get(item.MVEX__Field_Name__c).getDescribe().getLabel();
                }

                // Check if MVEX__Field_Name__c matches any field in the specified object and MVEX__Value__c matches the value of that field
                setCompletedBasedOnField(wrapper, item, sObjectRecord, fieldMap);

                // Check if MVEX__Checklist__c and checkList.id is same and MVEX__Is_Checked__c is true
                for (MVEX__Checklist_Item__c checklistItemRecord : checklistItem) {
                    if (checklistItemRecord.MVEX__Checklist__c == item.Id && checklistItemRecord.MVEX__Is_Checked__c == true && item.MVEX__Field_Name__c == null) {
                        wrapper.completed = true;
                        break;
                    }
                }

                checklistDataToShow.checklistData.add(wrapper);
            }

            // Resolve Name for Reference values
            Map<String, Set<Id>> objectToIds = new Map<String, Set<Id>>();
            for (ChecklistWrapper wrap : checklistDataToShow.checklistData) {
                if (wrap.fieldName != null && fieldMap.containsKey(wrap.fieldName)) {
                    Schema.DescribeFieldResult dr = fieldMap.get(wrap.fieldName).getDescribe();
                    if (dr.getType() == Schema.DisplayType.Reference && wrap.value != null && wrap.value.length() >= 15) {
                        try {
                            Id recId = (Id) wrap.value;
                            if (dr.getReferenceTo().size() > 0) {
                                String sObjName = dr.getReferenceTo()[0].getDescribe().getName();
                                if (!objectToIds.containsKey(sObjName)) {
                                    objectToIds.put(sObjName, new Set<Id>());
                                }
                                objectToIds.get(sObjName).add(recId);
                            }
                        } catch (Exception e) {
                            // Ignore if not a valid ID
                        }
                    }
                }
            }

            Map<Id, String> idToName = new Map<Id, String>();
            for (String sObj : objectToIds.keySet()) {
                try {
                    String queryIds = '(' + String.join(new List<Id>(objectToIds.get(sObj)), '\',\'') + ')';
                    // We can use a simpler approach for the query
                    Set<Id> ids = objectToIds.get(sObj);
                    String q = 'SELECT Id, Name FROM ' + String.escapeSingleQuotes(sObj) + ' WHERE Id IN :ids';
                    List<SObject> recs = Database.query(q, AccessLevel.USER_MODE);
                    for (SObject r : recs) {
                        idToName.put(r.Id, (String) r.get('Name'));
                    }
                } catch (Exception e) {
                    // Ignore errors if 'Name' field is not available
                }
            }

            for (ChecklistWrapper wrap : checklistDataToShow.checklistData) {
                if (wrap.value != null && wrap.value.length() >= 15) {
                    try {
                        Id recId = (Id) wrap.value;
                        if (idToName.containsKey(recId)) {
                            wrap.displayValue = idToName.get(recId);
                        } else {
                            wrap.displayValue = wrap.value;
                        }
                    } catch (Exception e) {
                        wrap.displayValue = wrap.value;
                    }
                } else {
                    wrap.displayValue = wrap.value;
                }
            }

            return checklistDataToShow;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'CheckListItemController', 'getCheckList', 'Error while getting checklist.');
            return null;
        }
    }

    /**
    * Method Name : setCompletedBasedOnField
    * @param wrapper - ChecklistWrapper
    * @param item - MVEX__Checklist__c
    * @param sObjectRecord - SObject
    * @param fieldMap - Map<String, Schema.SObjectField>
    * @description : Used to return boolean value as per the cheklist conditions.
    * @return Boolean value.
    */
    public static void setCompletedBasedOnField(ChecklistWrapper wrapper, MVEX__Checklist__c item, SObject sObjectRecord, Map<String, Schema.SObjectField> fieldMap) {
        try {
            if (sObjectRecord != null && item.MVEX__Field_Name__c != null && item.MVEX__Value__c != null) {
                Object fieldValue = sObjectRecord.get(item.MVEX__Field_Name__c);
                if (fieldValue != null) {
                    if (item.MVEX__Data_Type__c == 'NUMBER' && fieldValue instanceof Decimal) {
                        Decimal decimalValue = (Decimal) fieldValue;
                        fieldValue = decimalValue.setScale(0, RoundingMode.HALF_UP).intValue();
                    }

                    String fieldValueString = String.valueOf(fieldValue);
                    String itemValueString = item.MVEX__Value__c;
    
                    if (item.MVEX__Data_Type__c == 'DATE') {
                        Boolean status1 = changeDateFormat(item, fieldValue);
                        wrapper.completed = status1;
                    } else if (item.MVEX__Data_Type__c == 'DATETIME') {
                        Boolean status2 = changeDateTimeFormat(item, fieldValue);
                        wrapper.completed = status2;
                    } else {
                        switch on item.MVEX__Operator__c {
                            when 'Equals' {
                                wrapper.completed = fieldValueString.equalsIgnoreCase(itemValueString);
                            }
                            when 'Not Equals to' {
                                wrapper.completed = !fieldValueString.equalsIgnoreCase(itemValueString);
                            }
                            when 'Is Null' {
                                wrapper.completed = itemValueString == 'false';
                            }
                            when 'Greater Than' {
                                wrapper.completed = Decimal.valueOf(fieldValueString) > Decimal.valueOf(itemValueString);
                            }
                            when 'Greater Than Equal To' {
                                wrapper.completed = Decimal.valueOf(fieldValueString) >= Decimal.valueOf(itemValueString);
                            }
                            when 'Less Than' {
                                wrapper.completed = Decimal.valueOf(fieldValueString) < Decimal.valueOf(itemValueString);
                            }
                            when 'Less Than Equal To' {
                                wrapper.completed = Decimal.valueOf(fieldValueString) <= Decimal.valueOf(itemValueString);
                            }
                            when 'Contains' {
                                wrapper.completed = fieldValueString.toLowerCase().contains(itemValueString.toLowerCase());
                            }
                            when 'Not Contains' {
                                wrapper.completed = !fieldValueString.toLowerCase().contains(itemValueString.toLowerCase());
                            }
                            when else {
                                wrapper.completed = false;
                            }
                        }
                    }
                } else {
                    String itemValueString = item.MVEX__Value__c;

                    switch on item.MVEX__Operator__c {
                        when 'Equals' {
                            wrapper.completed = false;
                        }
                        when 'Not Equals to' {
                            wrapper.completed = true;
                        }
                        when 'Is Null' {
                            wrapper.completed = itemValueString == 'true';
                        }
                        when 'Contains' {
                            wrapper.completed = false;
                        }
                        when 'Not Contains' {
                            wrapper.completed = true;
                        }
                        when else {
                            wrapper.completed = false;
                        }
                    }
                }
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'CheckListItemController', 'setCompletedBasedOnField', e.getMessage());
        }
    }

    public static boolean changeDateFormat(MVEX__Checklist__c item, Object fieldValue) {
        try {
            Date parsedDate = Date.valueOf(item.MVEX__Value__c);
            if (fieldValue instanceof Date) {
                if (item.MVEX__Operator__c == 'Equals' && ((Date) fieldValue).equals(parsedDate)) {
                    return true;
                } else if (item.MVEX__Operator__c == 'Not Equals to' && !((Date) fieldValue).equals(parsedDate)) {
                    return true;
                } else {
                    return false;
                }
            } else {
                return false;
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'CheckListItemController', 'changeDateFormat', e.getMessage());
            return false;
        }
    }

    public static boolean changeDateTimeFormat(MVEX__Checklist__c item, Object fieldValue) {
        try {
            // Strip the 'Z' from the datetime string if present
            String dateTimeString = item.MVEX__Value__c.replace('Z', '');
            Datetime parsedDatetime = Datetime.valueOfGmt(dateTimeString.replace('T', ' '));
            if (fieldValue instanceof Datetime) {
                if (item.MVEX__Operator__c == 'Equals' && ((Datetime) fieldValue).equals(parsedDatetime)) {
                    return true;
                } else if (item.MVEX__Operator__c == 'Not Equals to' && !((Datetime) fieldValue).equals(parsedDatetime)) {
                    return true;
                } else {
                    return false;
                }
            } else {
                return false;
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'CheckListItemController', 'changeDateTimeFormat', e.getMessage());
            return false;
        }
    }
    
    /**
    * Method Name : createCheckListItem
    * @param recordId - String
    * @param checklistId - String
    * @param completed - Boolean
    * @description : Used to create checklist item.
    * @return String having return type String.
    */
    @AuraEnabled
    public static string createCheckListItem(String recordId, String checklistId, Boolean completed){
        try {
            List<MVEX__Checklist_Item__c> checklistItem = [SELECT Id, MVEX__Is_Checked__c FROM MVEX__Checklist_Item__c WHERE MVEX__Checklist__c = :checklistId AND MVEX__Record_Id__c = :recordId WITH USER_MODE LIMIT 1];
            if(checklistItem.size() > 0){
                for (MVEX__Checklist_Item__c item : checklistItem) {
                    item.MVEX__Is_Checked__c = completed;
                }
                
                update as user checklistItem;  
            } else {
                MVEX__Checklist_Item__c newChecklistItem = new MVEX__Checklist_Item__c();
                newChecklistItem.MVEX__Checklist__c = checklistId;
                newChecklistItem.MVEX__Is_Checked__c = completed;
                newChecklistItem.MVEX__Record_Id__c = recordId;
                
                insert as user newChecklistItem;   

            }
            return 'success';
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'CheckListItemController', 'createCheckListItem', 'Error while creating checklist item.');
            return 'error' + e.getMessage() + e.getLineNumber();
        }
    }

    /**
    * Method Name : manageChecklistRecords
    * @param itemsToCreate - List<Map<String, Object>>
    * @param itemsToUpdate - List<Map<String, Object>>
    * @param itemsToDelete - List<String>
    * @description : Used to manage checklist records.
    * @return String having return type String.
    */
    @AuraEnabled
    public static String manageChecklistRecords(List<Map<String, Object>> itemsToCreate, List<Map<String, Object>> itemsToUpdate, List<String> itemsToDelete) {
        List<MVEX__Checklist__c> recordsToCreate = new List<MVEX__Checklist__c>();
        List<MVEX__Checklist__c> recordsToUpdate = new List<MVEX__Checklist__c>();
        List<MVEX__Checklist__c> recordsToDelete = new List<MVEX__Checklist__c>();

        try {
            for (Map<String, Object> fields : itemsToCreate) {
                MVEX__Checklist__c newRecord = new MVEX__Checklist__c();
                for (String fieldName : fields.keySet()) {
                    newRecord.put(fieldName, fields.get(fieldName));
                }
                recordsToCreate.add(newRecord);
            }

            for (Map<String, Object> fields : itemsToUpdate) {
                MVEX__Checklist__c existingRecord = new MVEX__Checklist__c(Id = (String) fields.get('Id'));
                for (String fieldName : fields.keySet()) {
                    if (fieldName != 'Id') {
                        existingRecord.put(fieldName, fields.get(fieldName));
                    }
                }
                recordsToUpdate.add(existingRecord);
            }

            for (String id : itemsToDelete) {
                recordsToDelete.add(new MVEX__Checklist__c(Id = id));
            }

            if (!recordsToCreate.isEmpty()) {
                insert as user recordsToCreate;
            }
            if (!recordsToUpdate.isEmpty()) {
                update as user recordsToUpdate;
            }
            if (!recordsToDelete.isEmpty()) {
                delete as user recordsToDelete;
            }

            return 'success';
        }catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'CheckListItemController', 'manageChecklistRecords', 'Error while managing checklist records.');
            return 'error' + e.getMessage() + e.getLineNumber();
        }
    }
}