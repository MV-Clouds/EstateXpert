/**
* Class Name : MarketingListCmpController
* Test Class : Pending
* Date : 21/06/2024
* Created By : Vyom Soni
* Last Modified Date : 08-07-2024
* Last Modified By : Vyom Soni
* @description : Used in the MarketingList lwc component
*/

public with sharing class MarketingListCmpController {
    /**
   * Class Name : WrapperClass
   * @description : this wrapper list set contacts and medias together.
   */
   public class WrapperClass{
       @AuraEnabled
       public List<Contact> contacts;  
       @AuraEnabled
       public Integer pageSize;
       @AuraEnabled
       public List<Map<String, String>> selectedFields;       
   }

   /**
   * Method Name : getContactData
   * @description : for the retrieve the contact data.
   * @return List<Contact>.
   */
   @AuraEnabled
   public static WrapperClass getContactData(){
       try {
            List<Map<String, String>> configuredFields = new List<Map<String, String>>();
            Integer pageSize = 30;

            List<MVEX__Configuration_Settings__c> configs = [SELECT MVEX__Fields_Data__c, MVEX__Page_Size__c FROM MVEX__Configuration_Settings__c 
                                                             WHERE MVEX__Feature_Name__c = 'Marketing_List_Fields' WITH USER_MODE LIMIT 1];

            if (!configs.isEmpty()) {
                MVEX__Configuration_Settings__c config = configs[0];
                String fieldsDataJson = config.MVEX__Fields_Data__c;
                if (String.isNotBlank(fieldsDataJson)) {
                    configuredFields = (List<Map<String, String>>) JSON.deserialize(fieldsDataJson, List<Map<String, String>>.class);
                }
                if (config.MVEX__Page_Size__c != null) {
                    pageSize = Integer.valueOf(config.MVEX__Page_Size__c);
                }
            }

            Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Contact.fields.getMap();
            List<String> allFields = new List<String>();
            
            for (String fieldName : fieldMap.keySet()) {
                allFields.add(fieldName);
            }

            MVEX__MarketingListFilterConfig__mdt filterConfig = [SELECT MVEX__BlockedFields__c FROM MVEX__MarketingListFilterConfig__mdt WITH USER_MODE LIMIT 1];

            Set<String> blockedFields = new Set<String>();
            if (filterConfig != null && filterConfig.MVEX__BlockedFields__c != null) {
                blockedFields.addAll(filterConfig.MVEX__BlockedFields__c.split(';'));
            }
            List<String> filteredFields = new List<String>();

            for (String fieldName : allFields) {
                if (!blockedFields.contains(fieldName)) {
                    Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fieldName).getDescribe();
                    if (fieldDescribe.isAccessible()) {
                        filteredFields.add(fieldName);
                    }
                }
            }

            Set<String> queryFieldNames = new Set<String>();
            for(String f : filteredFields) {
                queryFieldNames.add(f.toLowerCase());
            }

            for (Map<String, String> field : configuredFields) {
                String fieldApiname = field.get('fieldApiname');
                if (String.isNotBlank(fieldApiname) && !queryFieldNames.contains(fieldApiname.toLowerCase())) {
                    filteredFields.add(fieldApiname);
                    queryFieldNames.add(fieldApiname.toLowerCase());
                }
            }

            String contactFields = String.join(filteredFields, ', ');
            String queryFields = String.escapeSingleQuotes(contactFields);
            String query = 'SELECT ' + queryFields + ' FROM Contact LIMIT 50000';

            List<Contact> contacts = Database.query(query, AccessLevel.USER_MODE);

            WrapperClass wc = new WrapperClass();
            wc.contacts = contacts; 
            wc.pageSize = pageSize;
            wc.selectedFields = configuredFields;
        
           return wc;
       } catch (Exception e) {
           ErrorHandler.insertErrorData(e, 'MarketingListCmpController', 'getContactData', 'Error while getting contact data.');
           return null;
       }
   }
}