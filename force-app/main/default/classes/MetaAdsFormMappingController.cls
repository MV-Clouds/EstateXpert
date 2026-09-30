public with sharing class MetaAdsFormMappingController {

    /**
     * @description Fetches all connected pages for the System User
     */
    @AuraEnabled
    public static Map<String, Object> getConnectedPages() {
        Map<String, Object> resultMap = new Map<String, Object>();
        try {
            Meta_Token_Config__c tokenConfig = Meta_Token_Config__c.getOrgDefaults();
            if (tokenConfig == null || String.isBlank(tokenConfig.System_User_Token_1__c)) {
                resultMap.put('success', false);
                resultMap.put('message', 'Meta Ads is not connected.');
                return resultMap;
            }

            String systemUserToken = tokenConfig.System_User_Token_1__c + (String.isNotBlank(tokenConfig.System_User_Token_2__c) ? tokenConfig.System_User_Token_2__c : '');
            
            Integration_App_Config__mdt config = Integration_App_Config__mdt.getInstance('Meta_Ads');
            if (config == null) {
                resultMap.put('success', false);
                resultMap.put('message', 'Integration configuration for Meta Ads is missing.');
                return resultMap;
            }

            String GRAPH_API_VERSION = config.API_Version__c;
            String GRAPH_BASE_URL = config.Base_Url__c;

            Http http = new Http();
            HttpRequest pageReq = new HttpRequest();
            pageReq.setEndpoint(GRAPH_BASE_URL + '/' + GRAPH_API_VERSION + '/me/accounts?fields=id,name,access_token&access_token=' + EncodingUtil.urlEncode(systemUserToken, 'UTF-8'));
            pageReq.setMethod('GET');
            pageReq.setTimeout(20000);

            HttpResponse pageRes = http.send(pageReq);

            if (pageRes.getStatusCode() == 200) {
                Map<String, Object> pagesMap = (Map<String, Object>) JSON.deserializeUntyped(pageRes.getBody());
                if (pagesMap.containsKey('data')) {
                    resultMap.put('pages', pagesMap.get('data'));
                }
                resultMap.put('success', true);
            } else {
                resultMap.put('success', false);
                resultMap.put('message', 'Failed to fetch pages. ' + pageRes.getBody());
            }

        } catch (Exception e) {
            resultMap.put('success', false);
            resultMap.put('message', e.getMessage());
        }
        return resultMap;
    }

    /**
     * @description Fetches all forms and their fields (questions) for a specific page from the Meta API
     */
    @AuraEnabled
    public static Map<String, Object> getLeadForms(String pageId) {
        Map<String, Object> resultMap = new Map<String, Object>();
        try {
            Meta_Token_Config__c tokenConfig = Meta_Token_Config__c.getOrgDefaults();
            if (tokenConfig == null || String.isBlank(tokenConfig.System_User_Token_1__c)) {
                resultMap.put('success', false);
                resultMap.put('message', 'Meta Ads is not connected.');
                return resultMap;
            }

            String systemUserToken = tokenConfig.System_User_Token_1__c + (String.isNotBlank(tokenConfig.System_User_Token_2__c) ? tokenConfig.System_User_Token_2__c : '');
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
            
            // 1. Fetch Page Access Token on the fly using System User Token
            HttpRequest pageReq = new HttpRequest();
            pageReq.setEndpoint(GRAPH_BASE_URL + '/' + GRAPH_API_VERSION + '/' + pageId + '?fields=access_token&access_token=' + EncodingUtil.urlEncode(systemUserToken, 'UTF-8'));
            pageReq.setMethod('GET');
            pageReq.setTimeout(20000);
            HttpResponse pageRes = http.send(pageReq);
            
            String pageAccessToken = systemUserToken; // fallback
            if (pageRes.getStatusCode() == 200) {
                Map<String, Object> pMap = (Map<String, Object>) JSON.deserializeUntyped(pageRes.getBody());
                if (pMap.containsKey('access_token')) {
                    pageAccessToken = (String) pMap.get('access_token');
                }
            }
            
            // 2. Fetch Forms using the Page Access Token
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
                resultMap.put('message', 'Failed to fetch forms. HTTP ' + formRes.getStatusCode() + ' - ' + formRes.getBody());
            }

        } catch (Exception e) {
            resultMap.put('success', false);
            resultMap.put('message', e.getMessage());
        }
        return resultMap;
    }

    /**
     * @description Fetches all updateable and accessible fields on the Contact object,
     *              including whether each field is required (nillable=false + createable).
     *              Excludes system/audit fields that Salesforce auto-populates (OwnerId, RecordTypeId, etc.)
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getSalesforceLeadFields() {
        List<Map<String, String>> fields = new List<Map<String, String>>();

        // System-managed fields: Salesforce auto-populates these — never require mapping
        Set<String> SYSTEM_FIELDS = new Set<String>{
            'ownerid', 'recordtypeid', 'currencyisocode',
            'createdbyid', 'lastmodifiedbyid', 'masterrecordid'
        };

        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Contact.fields.getMap();
        for (String fieldName : fieldMap.keySet()) {
            Schema.DescribeFieldResult dfr = fieldMap.get(fieldName).getDescribe();

            // Skip system-managed fields entirely (not useful for user mapping)
            if (SYSTEM_FIELDS.contains(fieldName.toLowerCase())) {
                continue;
            }

            // Allow updateable, accessible, non-deprecated fields
            if (dfr.isAccessible() && dfr.isUpdateable() && !dfr.isDeprecatedAndHidden()) {
                // A field is truly required if:
                //   - It must be supplied on create (isCreateable)
                //   - It cannot be null (isNillable = false)
                //   - It has no static default value (getDefaultValue = null)
                //   - Salesforce does NOT auto-default it on insert (isDefaultedOnCreate = false)
                //     e.g. OwnerId is defaulted to the running user, so it is NOT user-required
                Boolean isRequired = dfr.isCreateable()
                    && !dfr.isNillable()
                    && dfr.getDefaultValue() == null
                    && !dfr.isDefaultedOnCreate();

                Map<String, String> f = new Map<String, String>();
                f.put('label',    dfr.getLabel() + ' (' + dfr.getName() + ')');
                f.put('value',    dfr.getName());
                f.put('apiName',  dfr.getName());
                f.put('type',     String.valueOf(dfr.getType()));
                f.put('required', String.valueOf(isRequired));
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
            MVEX__Configuration_Settings__c setting = [SELECT MVEX__Fields_Data__c FROM MVEX__Configuration_Settings__c WHERE Name = 'Meta Ads Mappings' WITH USER_MODE LIMIT 1];
            return setting.MVEX__Fields_Data__c;
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * @description Saves the updated mappings to Configuration_Settings__c and subscribes the webhook
     */
    @AuraEnabled
    public static Map<String, Object> saveMapping(String mappingJson, String pageId) {
        Map<String, Object> resultMap = new Map<String, Object>();
        try {
            if (String.isNotBlank(pageId)) {
                String errorMsg = subscribeWebhookOnTheFly(pageId);
                if (errorMsg != null) {
                    resultMap.put('success', false);
                    resultMap.put('message', errorMsg);
                    return resultMap;
                }
            }

            // NOW perform DML
            MVEX__Configuration_Settings__c setting;
            try {
                setting = [SELECT Id, MVEX__Fields_Data__c FROM MVEX__Configuration_Settings__c WHERE Name = 'Meta Ads Mappings' WITH USER_MODE LIMIT 1];
            } catch (Exception e) {
                setting = new MVEX__Configuration_Settings__c(Name = 'Meta Ads Mappings');
            }
            
            setting.MVEX__Fields_Data__c = mappingJson;
            setting.MVEX__Feature_Name__c = 'Meta Ads Mappings';
            
            upsert as user setting;
            
            resultMap.put('success', true);
        } catch (Exception e) {
            resultMap.put('success', false);
            resultMap.put('message', e.getMessage());
        }
        return resultMap;
    }

    private static String subscribeWebhookOnTheFly(String pageId) {
        Meta_Token_Config__c tokenConfig = Meta_Token_Config__c.getOrgDefaults();
        if (tokenConfig == null || String.isBlank(tokenConfig.System_User_Token_1__c)) {
            return null;
        }
        String systemUserToken = tokenConfig.System_User_Token_1__c + (String.isNotBlank(tokenConfig.System_User_Token_2__c) ? tokenConfig.System_User_Token_2__c : '');
        
        Integration_App_Config__mdt config = Integration_App_Config__mdt.getInstance('Meta_Ads');
        String graphApiVersion = config.API_Version__c;
        String graphBaseUrl = config.Base_Url__c;
        
        Http http = new Http();
        
        HttpRequest pageReq = new HttpRequest();
        pageReq.setEndpoint(graphBaseUrl + '/' + graphApiVersion + '/' + pageId + '?fields=access_token&access_token=' + EncodingUtil.urlEncode(systemUserToken, 'UTF-8'));
        pageReq.setMethod('GET');
        pageReq.setTimeout(20000);
        HttpResponse pageRes = http.send(pageReq);
        
        if (pageRes.getStatusCode() != 200) {
            return null; // Silent skip if page token fetch fails, could be intentional
        }
        
        Map<String, Object> pMap = (Map<String, Object>) JSON.deserializeUntyped(pageRes.getBody());
        if (!pMap.containsKey('access_token')) {
            return null;
        }
        String pageAccessToken = (String) pMap.get('access_token');
        
        HttpRequest subReq = new HttpRequest();
        subReq.setEndpoint(graphBaseUrl + '/' + graphApiVersion + '/' + pageId + '/subscribed_apps?subscribed_fields=leadgen&access_token=' + EncodingUtil.urlEncode(pageAccessToken, 'UTF-8'));
        subReq.setMethod('POST');
        subReq.setTimeout(20000);
        HttpResponse subRes = http.send(subReq);
        
        if (subRes.getStatusCode() != 200) {
            return 'Failed to subscribe webhook: ' + subRes.getBody();
        }
        
        return null; // Success
    }

    @AuraEnabled
    public static List<MVEX__Error_Handling__c> getFailedLeads(String formId) {
        List<MVEX__Error_Handling__c> allLeads = [SELECT Id, Name, CreatedDate, MVEX__Error_Body__c FROM MVEX__Error_Handling__c WHERE MVEX__Source_of_Error__c = 'MetaFailedLeads' ORDER BY CreatedDate DESC LIMIT 500];
        List<MVEX__Error_Handling__c> filtered = new List<MVEX__Error_Handling__c>();
        for (MVEX__Error_Handling__c err : allLeads) {
            if (String.isNotBlank(err.MVEX__Error_Body__c)) {
                try {
                    Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(err.MVEX__Error_Body__c);
                    if (payload.get('formId') == formId) {
                        filtered.add(err);
                    }
                } catch(Exception e) {
                    // Ignore parsing errors for individual records
                }
            }
        }
        return filtered;
    }

    @AuraEnabled
    public static String retryFailedLead(String errorRecordId) {
        try {
            MVEX__Error_Handling__c err = [SELECT Id, MVEX__Error_Body__c FROM MVEX__Error_Handling__c WHERE Id = :errorRecordId LIMIT 1];
            if (err == null || String.isBlank(err.MVEX__Error_Body__c)) {
                return 'Error record not found or body is empty.';
            }
            
            Map<String, Object> retryPayload = (Map<String, Object>) JSON.deserializeUntyped(err.MVEX__Error_Body__c);
            String lId = (String) retryPayload.get('leadId');
            String pId = (String) retryPayload.get('pageId');
            String fId = (String) retryPayload.get('formId');
            String fName = (String) retryPayload.get('formName');
            Map<String, Object> lData = (Map<String, Object>) retryPayload.get('leadData');
            
            String result = MetaLeadWebhook.createSalesforceContact(lData, fName, pId, fId, lId);
            if (result == 'Success') {
                delete err;
            }
            return result;
        } catch (Exception e) {
            return 'Retry Error: ' + e.getMessage();
        }
    }
}
