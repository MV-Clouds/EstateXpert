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
        @AuraEnabled public List<Checklist__c> checklist;
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
        result.checklist = new List<Checklist__c>();
        try {
            result.checklist = [SELECT Id, Name, Field_Name__c, Object_Name__c, Operator__c, Sequence__c, Value__c, Description__c, Data_Type__c FROM Checklist__c WHERE Object_Name__c = :objectName WITH USER_MODE ORDER BY Sequence__c NULLS LAST, Name];
            
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
                List<String> numberFields = new List<String>{'CURRENCY', 'DOUBLE', 'PHONE'};

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
        @AuraEnabled public String fieldName;
        @AuraEnabled public String description;
        @AuraEnabled public String fieldLabel;
        @AuraEnabled public String objectName;
        @AuraEnabled public String operator;
        @AuraEnabled public String value;
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

            if (Schema.sObjectType.Checklist__c.isCreateable() && Schema.sObjectType.Checklist__c.isUpdateable()) {
                checklistDataToShow.isEditable = true;
            }

            List<Checklist__c> checkList = [SELECT Id, Name, Field_Name__c, Object_Name__c, Operator__c, Sequence__c, Value__c, Description__c, Data_Type__c
                                            FROM Checklist__c WHERE Object_Name__c = :objectName WITH USER_MODE ORDER BY Sequence__c NULLS LAST, Name];

            List<Checklist_Item__c> checklistItem = [SELECT Id, Checklist__c, Is_Checked__c, Record_Id__c FROM Checklist_Item__c 
                                                        WHERE Record_Id__c = :recordId WITH USER_MODE];

            Schema.SObjectType sObjectType = Schema.getGlobalDescribe().get(objectName);
            if (sObjectType == null) {
                throw new AuraHandledException('Invalid object name: ' + objectName);
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

            for (Checklist__c item : checkList) {
                ChecklistWrapper wrapper = new ChecklistWrapper();
                wrapper.id = item.Id;
                wrapper.name = item.Name;
                wrapper.description = item.Description__c;
                wrapper.fieldName = item.Field_Name__c;
                wrapper.objectName = item.Object_Name__c;
                wrapper.operator = item.Operator__c;
                wrapper.value = item.Value__c;
                wrapper.completed = false;
                wrapper.showDropdown = false;
                wrapper.isDescription = item.Description__c != null && item.Description__c != '' ? true : false;

                // Set the field label
                if (item.Field_Name__c != null && fieldMap.containsKey(item.Field_Name__c)) {
                    wrapper.fieldLabel = fieldMap.get(item.Field_Name__c).getDescribe().getLabel();
                }

                // Check if Field_Name__c matches any field in the specified object and Value__c matches the value of that field
                setCompletedBasedOnField(wrapper, item, sObjectRecord, fieldMap);

                // Check if Checklist__c and checkList.id is same and Is_Checked__c is true
                for (Checklist_Item__c checklistItemRecord : checklistItem) {
                    if (checklistItemRecord.Checklist__c == item.Id && checklistItemRecord.Is_Checked__c == true && item.Field_Name__c == null) {
                        wrapper.completed = true;
                        break;
                    }
                }

                checklistDataToShow.checklistData.add(wrapper);
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
    * @param item - Checklist__c
    * @param sObjectRecord - SObject
    * @param fieldMap - Map<String, Schema.SObjectField>
    * @description : Used to return boolean value as per the cheklist conditions.
    * @return Boolean value.
    */
    public static void setCompletedBasedOnField(ChecklistWrapper wrapper, Checklist__c item, SObject sObjectRecord, Map<String, Schema.SObjectField> fieldMap) {
        try {
            if (sObjectRecord != null && item.Field_Name__c != null && item.Value__c != null) {
                Object fieldValue = sObjectRecord.get(item.Field_Name__c);
                if (fieldValue != null) {
                    if (item.Data_Type__c == 'NUMBER' && fieldValue instanceof Decimal) {
                        Decimal decimalValue = (Decimal) fieldValue;
                        fieldValue = decimalValue.setScale(0, RoundingMode.HALF_UP).intValue();
                    }

                    String fieldValueString = String.valueOf(fieldValue);
                    String itemValueString = item.Value__c;
    
                    if (item.Data_Type__c == 'DATE') {
                        Boolean status1 = changeDateFormat(item, fieldValue);
                        wrapper.completed = status1;
                    } else if (item.Data_Type__c == 'DATETIME') {
                        Boolean status2 = changeDateTimeFormat(item, fieldValue);
                        wrapper.completed = status2;
                    } else {
                        switch on item.Operator__c {
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
                    String itemValueString = item.Value__c;

                    switch on item.Operator__c {
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

    public static boolean changeDateFormat(Checklist__c item, Object fieldValue) {
        try {
            Date parsedDate = Date.valueOf(item.Value__c);
            if (fieldValue instanceof Date) {
                if (item.Operator__c == 'Equals' && ((Date) fieldValue).equals(parsedDate)) {
                    return true;
                } else if (item.Operator__c == 'Not Equals to' && !((Date) fieldValue).equals(parsedDate)) {
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

    public static boolean changeDateTimeFormat(Checklist__c item, Object fieldValue) {
        try {
            // Strip the 'Z' from the datetime string if present
            String dateTimeString = item.Value__c.replace('Z', '');
            Datetime parsedDatetime = Datetime.valueOfGmt(dateTimeString.replace('T', ' '));
            if (fieldValue instanceof Datetime) {
                if (item.Operator__c == 'Equals' && ((Datetime) fieldValue).equals(parsedDatetime)) {
                    return true;
                } else if (item.Operator__c == 'Not Equals to' && !((Datetime) fieldValue).equals(parsedDatetime)) {
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
            List<Checklist_Item__c> checklistItem = [SELECT Id, Is_Checked__c FROM Checklist_Item__c WHERE Checklist__c = :checklistId AND Record_Id__c = :recordId WITH USER_MODE LIMIT 1];
            if(checklistItem.size() > 0){
                for (Checklist_Item__c item : checklistItem) {
                    item.Is_Checked__c = completed;
                }
                
                update as user checklistItem;  
            } else {
                Checklist_Item__c newChecklistItem = new Checklist_Item__c();
                newChecklistItem.Checklist__c = checklistId;
                newChecklistItem.Is_Checked__c = completed;
                newChecklistItem.Record_Id__c = recordId;
                
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
        List<Checklist__c> recordsToCreate = new List<Checklist__c>();
        List<Checklist__c> recordsToUpdate = new List<Checklist__c>();
        List<Checklist__c> recordsToDelete = new List<Checklist__c>();

        try {
            for (Map<String, Object> fields : itemsToCreate) {
                Checklist__c newRecord = new Checklist__c();
                for (String fieldName : fields.keySet()) {
                    newRecord.put(fieldName, fields.get(fieldName));
                }
                recordsToCreate.add(newRecord);
            }

            for (Map<String, Object> fields : itemsToUpdate) {
                Checklist__c existingRecord = new Checklist__c(Id = (String) fields.get('Id'));
                for (String fieldName : fields.keySet()) {
                    if (fieldName != 'Id') {
                        existingRecord.put(fieldName, fields.get(fieldName));
                    }
                }
                recordsToUpdate.add(existingRecord);
            }

            for (String id : itemsToDelete) {
                recordsToDelete.add(new Checklist__c(Id = id));
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