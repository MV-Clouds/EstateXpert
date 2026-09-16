public with sharing class MetaAdsFormMappingController {

    /**
     * @description Fetches all forms and their fields (questions) from the Meta API
     */
    @AuraEnabled
    public static Map<String, Object> getFormsAndFields() {
        Map<String, Object> resultMap = new Map<String, Object>();
        try {
            Meta_Token_Config__c tokenConfig = Meta_Token_Config__c.getOrgDefaults();
            if (tokenConfig == null || String.isBlank(tokenConfig.Page_Access_Token_1__c)) {
                resultMap.put('success', false);
                resultMap.put('message', 'Meta Ads is not connected.');
                return resultMap;
            }

            String pageAccessToken = tokenConfig.Page_Access_Token_1__c + (String.isNotBlank(tokenConfig.Page_Access_Token_2__c) ? tokenConfig.Page_Access_Token_2__c : '');
            String pageId = tokenConfig.Page_Id__c;
            String clientAppId = tokenConfig.Client_App_Id__c;

            Integration_App_Config__mdt config = Integration_App_Config__mdt.getInstance('Meta_Ads');
            if (config == null) {
                resultMap.put('success', false);
                resultMap.put('message', 'Integration configuration for Meta Ads is missing.');
                return resultMap;
            }

            String GRAPH_API_VERSION = config.API_Version__c;
            String GRAPH_BASE_URL = config.Base_Url__c;

            Http http = new Http();
            HttpRequest formReq = new HttpRequest();
            formReq.setEndpoint(GRAPH_BASE_URL + '/' + GRAPH_API_VERSION + '/' + pageId + '/leadgen_forms?fields=id,name,status,created_time,questions&access_token=' + EncodingUtil.urlEncode(pageAccessToken, 'UTF-8'));
            formReq.setMethod('GET');
            formReq.setTimeout(20000);

            HttpResponse formRes = http.send(formReq);

            if (formRes.getStatusCode() == 200) {
                Map<String, Object> formMap = (Map<String, Object>) JSON.deserializeUntyped(formRes.getBody());
                if (formMap.containsKey('data')) {
                    resultMap.put('forms', formMap.get('data'));
                }
                resultMap.put('client_app_id', clientAppId);
                resultMap.put('page_id', pageId);
                resultMap.put('success', true);
            } else {
                resultMap.put('success', false);
                resultMap.put('message', 'Failed to fetch forms. ' + formRes.getBody());
            }

        } catch (Exception e) {
            resultMap.put('success', false);
            resultMap.put('message', e.getMessage());
        }
        return resultMap;
    }

    /**
     * @description Fetches all updateable and accessible fields on the Lead object
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getSalesforceLeadFields() {
        List<Map<String, String>> fields = new List<Map<String, String>>();
        
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Lead.fields.getMap();
        for (String fieldName : fieldMap.keySet()) {
            Schema.DescribeFieldResult dfr = fieldMap.get(fieldName).getDescribe();
            
            // Allow updateable fields that aren't deprecated
            if (dfr.isAccessible() && dfr.isUpdateable() && !dfr.isDeprecatedAndHidden()) {
                Map<String, String> f = new Map<String, String>();
                f.put('label', dfr.getLabel() + ' (' + dfr.getName() + ')');
                f.put('value', dfr.getName());
                fields.add(f);
            }
        }
        
        return fields;
    }

    /**
     * @description Fetches the existing Meta Ads mappings from Configuration_Settings__c
     */
    @AuraEnabled
    public static String getExistingMappings() {
        try {
            MVEX__Configuration_Settings__c setting = [SELECT MVEX__Fields_Data__c FROM MVEX__Configuration_Settings__c WHERE Name = 'Meta Ads Mappings' LIMIT 1];
            return setting.MVEX__Fields_Data__c;
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * @description Saves the updated mappings to Configuration_Settings__c
     */
    @AuraEnabled
    public static Map<String, Object> saveMapping(String mappingJson) {
        Map<String, Object> resultMap = new Map<String, Object>();
        try {
            MVEX__Configuration_Settings__c setting;
            
            try {
                setting = [SELECT Id, MVEX__Fields_Data__c FROM MVEX__Configuration_Settings__c WHERE Name = 'Meta Ads Mappings' LIMIT 1];
            } catch (Exception e) {
                setting = new MVEX__Configuration_Settings__c(Name = 'Meta Ads Mappings');
            }
            
            setting.MVEX__Fields_Data__c = mappingJson;
            // Assuming there's a MVEX__Feature_Name__c field to populate based on other similar configs
            setting.MVEX__Feature_Name__c = 'Meta Ads Mappings';
            
            upsert setting;
            
            resultMap.put('success', true);
        } catch (Exception e) {
            resultMap.put('success', false);
            resultMap.put('message', e.getMessage());
        }
        return resultMap;
    }
}
