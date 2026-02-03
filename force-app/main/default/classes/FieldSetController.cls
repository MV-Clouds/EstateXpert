/**
* Class Name : FieldSetController
* Date : 30-07-2024
* Created By : Vyom Soni
*/
public with sharing class FieldSetController {

    /**
    * Method Name : fetchRecordTypes
    * @description : Fetches record types for the selected object.
    * @return List of RecordType.
    */
    @AuraEnabled
    public static List<RecordType> fetchRecordTypes(String sObjectApiName) {
        try {
             if (String.isBlank(sObjectApiName)) {
            throw new AuraHandledException('SObject API name is required');
        }

        return [
            SELECT Id, DeveloperName, Name, SObjectType
            FROM RecordType
            WHERE SObjectType = :sObjectApiName
            AND IsActive = true
            WITH USER_MODE
        ];
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching record types: ' + e.getMessage());
        }
    }

    public class FilterWrapper {
        @AuraEnabled
        public Map<String,List<Listing__c>> records  { get; set; }
        @AuraEnabled
        public Map<Id, String> medias { get; set; }
    }

    /**
     * Method Name : fetchListings
     * @description : Fetches listings based on the provided Property__c object.
     * @param listin Property__c object containing search criteria.
     * @return FilterWrapper containing listings and media URLs.
    */
    @AuraEnabled
    public static FilterWrapper fetchListings(Property__c listin){
        try {
            Map<String, Schema.SObjectField> fieldsMap = Schema.getGlobalDescribe().get('MVEX__Property__c').getDescribe().fields.getMap();
            String fieldList = '';
            for (String fieldName : fieldsMap.keySet()) {
                fieldList += fieldName + ', ';
            }
            fieldList = fieldList.removeEnd(', '); 
            // Add related child records from MVEX__Listings__r relationship
            fieldList += ', (SELECT Id, Name FROM MVEX__Listings__r WHERE MVEX__Status__c = \'Active\')';
            String query = 'SELECT ' + fieldList + ' FROM MVEX__Property__c WHERE ';

            // Add conditions based on input property fields
            Map<String, Object> bindVars = new Map<String, Object>();
            if (listin.Name != null && listin.Name != '') {
                if (String.isNotBlank(listin.Name)) {
                    String searchName = '%' + String.escapeSingleQuotes(listin.Name) + '%';
                    query += ' Name LIKE :searchName AND ';
                    bindVars.put('searchName', searchName);
                }
                query = query.removeEnd(' AND ');
            } else {
                return null;
            }            
            query += ' LIMIT 5000';
            
            List<Property__c> listinglst = Database.queryWithBinds(query, bindVars, AccessLevel.USER_MODE);
            if (listinglst.isEmpty()) {
                return null;
            }
            Set<Id> propertyIds = new Set<Id>();
            for (Property__c listingRec : listinglst) {
                Id propertyId = listingRec.Id;
                if (propertyId != null) {
                    propertyIds.add(propertyId);
                }
            }
            if (!Schema.sObjectType.Property_File__c.isAccessible()) {
                throw new AuraHandledException('You do not have permission to access Property File records.');
            }
            // Check if the user has read access to the necessary fields of Property_File__c
            if (!Schema.sObjectType.Property_File__c.fields.BaseUrl__c.isAccessible() ||
                !Schema.sObjectType.Property_File__c.fields.Property__c.isAccessible()) {
                throw new AuraHandledException('You do not have permission to access required fields of Property File records.');
            }
            List<Property_File__c> medias = [SELECT Id, BaseUrl__c, Property__c FROM Property_File__c WHERE Property__c IN :propertyIds WITH USER_MODE LIMIT 5000];
            Map<Id, String> propertyMediaUrlsMap = new Map<Id, String>();
            for (Property_File__c media : medias) {
                propertyMediaUrlsMap.put(media.Property__c, media.BaseUrl__c);
            }
            Map<String,List<Listing__c>> lstMap = new Map<String,List<Listing__c>>();
            List<Listing__c> lstIds = new List<Listing__c>();
            String addrField;
            for(Property__c c:listinglst){   
                if(c.Listings__r!=null && !c.Listings__r.isEmpty()){
                    for(Listing__c p : c.Listings__r){
                        addrField = '';
                        if(c.City__c!=null && c.City__c!='' && String.isNotBlank(c.City__c)){
                            addrField += c.City__c + ', '; 
                        }
                        else{
                            addrField += '';
                        }
                        if(c.State__c!=null && c.State__c!='' && String.isNotBlank(c.State__c)){
                            addrField += c.State__c + ', '; 
                        }
                        else{
                            addrField += '';
                        }
                        if(c.Country__c!=null && c.Country__c!='' && String.isNotBlank(c.Country__c)){
                            addrField += c.Country__c + ', '; 
                        }
                        else{
                            addrField += '';
                        }

                        if (addrField.endsWith(', ')) {
                            addrField = addrField.removeEnd(', ');
                        }


                        String propertyJson = JSON.serialize(c);
                        if(!lstMap.containsKey(c.Id+'::'+c.Name+'::'+addrField)){
                            lstMap.put(c.Id+'::'+c.Name+'::'+addrField+'::'+propertyJson,new List<Listing__c>());
                        }
                        lstMap.get(c.Id+'::'+c.Name+'::'+addrField+'::'+propertyJson).add(p);  
                    }
                }
                else{
                    addrField = '';
                    if(c.City__c!=null && c.City__c!='' && String.isNotBlank(c.City__c)){
                        addrField += c.City__c + ', '; 
                    }
                    else{
                        addrField += '';
                    }
                    if(c.State__c!=null && c.State__c!='' && String.isNotBlank(c.State__c)){
                        addrField += c.State__c + ', '; 
                    }
                    else{
                        addrField += '';
                    }
                    if(c.Country__c!=null && c.Country__c!='' && String.isNotBlank(c.Country__c)){
                        addrField += c.Country__c + ', '; 
                    }
                    else{
                        addrField += '';
                    }
                    if (addrField.endsWith(', ')) {
                        addrField = addrField.removeEnd(', ');
                    }
                    String propertyJson = JSON.serialize(c);
                    lstMap.put(c.Id+'::'+c.Name+'::'+addrField+'::'+propertyJson,new List<Listing__c>());
                }
            }

            FilterWrapper wc = new FilterWrapper();
            wc.medias = propertyMediaUrlsMap;
            wc.records = lstMap;
            return wc; 
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'FieldSetController', 'fetchListings', 'Error while fetching listings.');
            return null;
        }
    }


    /**
     * Method Name : fetchContacts
     * @description : Fetches contacts based on the provided Contact object and SOQL query.
     * @param listin Contact object containing search criteria.
     * @param soqlquery SOQL query to be executed.
     * @return List<Map<String, String>> containing contacts and their media URLs.
    */

    @AuraEnabled
    public static List<Map<String, String>> fetchContacts(Contact listin, String soqlquery) {
        try {
            if ((String.isNotBlank(listin.FirstName)) || (String.isNotBlank(listin.LastName))) {
                String queryFields = String.escapeSingleQuotes(soqlquery);
                String query = 'SELECT ' + queryFields + ' FROM Contact WHERE ';
                List<String> conditions = new List<String>();
                Map<String, Object> bindVars = new Map<String, Object>();
    
                if (String.isNotBlank(listin.FirstName)) {
                    conditions.add('FirstName LIKE :firstName');
                    bindVars.put('firstName', '%' + listin.FirstName + '%');
                }
                if (String.isNotBlank(listin.LastName)) {
                    conditions.add('LastName LIKE :lastName');
                    bindVars.put('lastName', '%' + listin.LastName + '%');
                }

                if(String.isNotBlank(listin.Email)) {
                    conditions.add('Email LIKE :email');
                    bindVars.put('email', '%' + listin.Email + '%');
                }
                if(String.isNotBlank(listin.Phone)) {
                    conditions.add('Phone LIKE :phone');
                    bindVars.put('phone', '%' + listin.Phone + '%');
                }
    
                query += String.join(conditions, ' OR ');
                query += ' LIMIT 5000';

                // Perform bind-based query
                List<Contact> listinglst = (List<Contact>) Database.queryWithBinds(query, bindVars, AccessLevel.USER_MODE);
                if (listinglst.isEmpty()) {
                    return null;
                }
    
                // Map fields to values
                List<String> fieldNames = soqlquery.split(',');
                List<Map<String, String>> contactList = new List<Map<String, String>>();
                for (Contact c : listinglst) {
                    Map<String, String> contactMap = new Map<String, String>();
                    for (String fieldName : fieldNames) {
                        String fieldValue = String.valueOf(c.get(fieldName.trim()));
                        contactMap.put(fieldName.trim(), fieldValue);
                    }
                    contactList.add(contactMap);
                }
                return contactList;
            } else {
                return null;
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'FieldSetController', 'fetchContacts', 'Error while fetching contacts.');
            return null;
        }
    }

    @AuraEnabled
    public static List<Map<String, Object>> getListingFieldsByRecordType(Id recordTypeId) {
        try {
            RecordType rt = [
                SELECT DeveloperName
                FROM RecordType
                WHERE Id = :recordTypeId
                AND SObjectType = 'MVEX__Listing__c'
                WITH USER_MODE
                LIMIT 1
            ];

            String fieldSetName;
            if (rt.DeveloperName == 'Sale') {
                fieldSetName = 'MVEX__ListingManagerFieldSet';
            } else if (rt.DeveloperName == 'Rent') {
                fieldSetName = 'MVEX__RentListingManager';
            } else {
                throw new AuraHandledException('Unsupported record type');
            }

            // Object describe
            Schema.DescribeSObjectResult objDescribe =
                MVEX__Listing__c.SObjectType.getDescribe();

            // Field sets
            Schema.FieldSet fs =
                objDescribe.fieldSets.getMap().get(fieldSetName);

            if (fs == null) {
                throw new AuraHandledException('Field set not found: ' + fieldSetName);
            }

            // Field map (IMPORTANT)
            Map<String, Schema.SObjectField> fieldMap =
                objDescribe.fields.getMap();

            List<Map<String, Object>> result = new List<Map<String, Object>>();

            for (Schema.FieldSetMember fsm : fs.getFields()) {

                Schema.SObjectField fieldRef =
                    fieldMap.get(fsm.getFieldPath());

                if (fieldRef == null) {
                    continue; // safety
                }

                Schema.DescribeFieldResult dfr =
                    fieldRef.getDescribe();

                Map<String, Object> fieldInfo = new Map<String, Object>();
                fieldInfo.put('APIName', fsm.getFieldPath());
                fieldInfo.put('Label', fsm.getLabel());
                fieldInfo.put('Type', String.valueOf(dfr.getType()));
            fieldInfo.put('Required', fsm.getRequired());

                result.add(fieldInfo);
            }

            return result;

        } catch (Exception e) {
            ErrorHandler.insertErrordata(
                e,
                'FieldSetController',
                'getListingFieldsByRecordType',
                'Error while getting listing fields by record type.'
            );
            throw new AuraHandledException(e.getMessage());
        }
    }

        @AuraEnabled
    public static List<Map<String, Object>> getContactFieldsByRecordType(Id recordTypeId) {
        try {
            RecordType rt = [
                SELECT DeveloperName
                FROM RecordType
                WHERE Id = :recordTypeId
                AND SObjectType = 'Contact'
                WITH USER_MODE
                LIMIT 1
            ];

            String fieldSetName;
            if (rt.DeveloperName == 'Company Contact' || rt.DeveloperName == 'Company_Contact') {
                fieldSetName = 'MVEX__CompanyContactFieldset';
            } else if (rt.DeveloperName == 'Individual Contact' || rt.DeveloperName == 'Individual_Contact') {
                fieldSetName = 'MVEX__MarketingListFieldSet';
            } else {
                throw new AuraHandledException('Unsupported record type');
            }

            // Object describe
            Schema.DescribeSObjectResult objDescribe =
                Contact.SObjectType.getDescribe();

            // Field sets
            Schema.FieldSet fs =
                objDescribe.fieldSets.getMap().get(fieldSetName);

            if (fs == null) {
                throw new AuraHandledException('Field set not found: ' + fieldSetName);
            }

            // Field map (IMPORTANT)
            Map<String, Schema.SObjectField> fieldMap =
                objDescribe.fields.getMap();

            List<Map<String, Object>> result = new List<Map<String, Object>>();

            for (Schema.FieldSetMember fsm : fs.getFields()) {

                Schema.SObjectField fieldRef =
                    fieldMap.get(fsm.getFieldPath());

                if (fieldRef == null) {
                    continue; // safety
                }

                Schema.DescribeFieldResult dfr =
                    fieldRef.getDescribe();

                Map<String, Object> fieldInfo = new Map<String, Object>();
                fieldInfo.put('APIName', fsm.getFieldPath());
                fieldInfo.put('Label', fsm.getLabel());
                fieldInfo.put('Type', String.valueOf(dfr.getType()));
            fieldInfo.put('Required', fsm.getRequired());

                result.add(fieldInfo);
            }

            return result;

        } catch (Exception e) {
            ErrorHandler.insertErrordata(
                e,
                'FieldSetController',
                'getContactFieldsByRecordType',
                'Error while getting contact fields by record type.'
            );
            throw new AuraHandledException(e.getMessage());
        }
    }

}