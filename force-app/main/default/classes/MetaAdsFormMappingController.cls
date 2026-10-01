public with sharing class MetaAdsFormMappingController {

    /**
     * @description Fetches all connected pages for the System User
     */
    @AuraEnabled
    public static Map<String, Object> getConnectedPages() {
        Map<String, Object> resultMap = new Map<String, Object>();
        try {
            List<MVEX__OAuth_Configuration__mdt> tokenConfigs = [SELECT MVEX__Access_Token__c, MVEX__API_Version__c, MVEX__Base_URL__c, MVEX__Client_App_Id__c FROM MVEX__OAuth_Configuration__mdt WHERE DeveloperName = 'Meta_Ads_Config' WITH USER_MODE LIMIT 1];
            MVEX__OAuth_Configuration__mdt tokenConfig = tokenConfigs.isEmpty() ? null : tokenConfigs[0];
            if (tokenConfig == null || String.isBlank(tokenConfig.MVEX__Access_Token__c)) {
                resultMap.put('success', false);
                resultMap.put('message', 'Meta Ads is not connected.');
                return resultMap;
            }

            // Read directly from metadata — no manipulation
            String accessToken     = tokenConfig.MVEX__Access_Token__c;
            String graphApiVersion = tokenConfig.MVEX__API_Version__c;
            String graphBaseUrl    = tokenConfig.MVEX__Base_URL__c;

            Http http = new Http();
            HttpRequest pageReq = new HttpRequest();
            pageReq.setEndpoint(graphBaseUrl + '/' + graphApiVersion + '/me/accounts?fields=id,name,access_token&access_token=' + EncodingUtil.urlEncode(accessToken, 'UTF-8'));
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
                String errorMsg = 'HTTP ' + pageRes.getStatusCode();
                try {
                    Map<String, Object> errBody = (Map<String, Object>) JSON.deserializeUntyped(pageRes.getBody());
                    if (errBody.containsKey('error')) {
                        Map<String, Object> errObj = (Map<String, Object>) errBody.get('error');
                        errorMsg += ' | ' + errObj.get('message');
                    } else {
                        errorMsg += ' | ' + pageRes.getBody();
                    }
                } catch (Exception parseEx) {
                    ErrorHandler.insertErrorData(parseEx, 'MetaAdsFormMappingController', 'getConnectedPages', parseEx.getMessage());
                    errorMsg += ' | ' + pageRes.getBody();
                }
                resultMap.put('success', false);
                resultMap.put('message', 'Failed to fetch pages. ' + errorMsg);
            }

        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'MetaAdsFormMappingController', 'getConnectedPages', e.getMessage());
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
            List<MVEX__OAuth_Configuration__mdt> tokenConfigs = [SELECT MVEX__Access_Token__c, MVEX__API_Version__c, MVEX__Base_URL__c, MVEX__Client_App_Id__c FROM MVEX__OAuth_Configuration__mdt WHERE DeveloperName = 'Meta_Ads_Config' WITH USER_MODE LIMIT 1];
            MVEX__OAuth_Configuration__mdt tokenConfig = tokenConfigs.isEmpty() ? null : tokenConfigs[0];
            if (tokenConfig == null || String.isBlank(tokenConfig.MVEX__Access_Token__c)) {
                resultMap.put('success', false);
                resultMap.put('message', 'Meta Ads is not connected.');
                return resultMap;
            }

            // Read directly from metadata — no manipulation
            String accessToken     = tokenConfig.MVEX__Access_Token__c;
            String clientAppId     = tokenConfig.MVEX__Client_App_Id__c;
            String graphApiVersion = tokenConfig.MVEX__API_Version__c;
            String graphBaseUrl    = tokenConfig.MVEX__Base_URL__c;


            Http http = new Http();

            // ── Step 1: Fetch Page Access Token ───────────────────────────────
            HttpRequest pageReq = new HttpRequest();
            pageReq.setEndpoint(graphBaseUrl + '/' + graphApiVersion + '/' + pageId + '?fields=access_token&access_token=' + accessToken);
            pageReq.setMethod('GET');
            pageReq.setTimeout(20000);
            HttpResponse pageRes = http.send(pageReq);

            String pageAccessToken = accessToken; // fallback to system user token
            if (pageRes.getStatusCode() == 200) {
                Map<String, Object> pMap = (Map<String, Object>) JSON.deserializeUntyped(pageRes.getBody());
                if (pMap.containsKey('access_token')) {
                    pageAccessToken = (String) pMap.get('access_token');
                }
            }

            // ── Step 2: Fetch Lead Forms ──────────────────────────────────────
            HttpRequest formReq = new HttpRequest();
            formReq.setEndpoint(graphBaseUrl + '/' + graphApiVersion + '/' + pageId + '/leadgen_forms?fields=id,name,status,created_time,questions&access_token=' + pageAccessToken);
            formReq.setMethod('GET');
            formReq.setTimeout(20000);
            HttpResponse formRes = http.send(formReq);

            if (formRes.getStatusCode() == 200) {
                Map<String, Object> formMap = (Map<String, Object>) JSON.deserializeUntyped(formRes.getBody());
                List<Object> forms = formMap.containsKey('data') ? (List<Object>) formMap.get('data') : new List<Object>();
                resultMap.put('forms', forms);
                resultMap.put('client_app_id', clientAppId);
                resultMap.put('page_id', pageId);
                resultMap.put('success', true);
            } else {
                String errorMsg = 'HTTP ' + formRes.getStatusCode();
                try {
                    Map<String, Object> errBody = (Map<String, Object>) JSON.deserializeUntyped(formRes.getBody());
                    if (errBody.containsKey('error')) {
                        Map<String, Object> errObj = (Map<String, Object>) errBody.get('error');
                        errorMsg += ' | ' + errObj.get('message') + ' (Meta code: ' + errObj.get('code') + ')';
                    } else {
                        errorMsg += ' | ' + formRes.getBody();
                    }
                } catch (Exception parseEx) {
                    ErrorHandler.insertErrorData(parseEx, 'MetaAdsFormMappingController', 'getLeadForms', parseEx.getMessage());
                    errorMsg += ' | ' + formRes.getBody();
                }
                resultMap.put('success', false);
                resultMap.put('message', 'Failed to fetch forms. ' + errorMsg);
            }

        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'MetaAdsFormMappingController', 'getLeadForms', e.getMessage());
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
            'ownerid', 'recordtypeid', 'currencyisocode','createdbyid', 'lastmodifiedbyid', 'masterrecordid'
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
                
                if (dfr.getType() == Schema.DisplayType.Reference) {
                    List<Schema.sObjectType> refs = dfr.getReferenceTo();
                    if (!refs.isEmpty()) {
                        f.put('referenceTo', String.valueOf(refs[0]));
                    }
                }
                
                fields.add(f);
            }
        }

        return fields;
    }

    /**
     * @description Fetches the existing Meta Ads mappings from    MVEX__Configuration_Settings__c
     */
    @AuraEnabled
    public static String getExistingMappings() {
        try {
            MVEX__Configuration_Settings__c setting = [SELECT MVEX__Fields_Data__c FROM MVEX__Configuration_Settings__c WHERE Name = 'Meta Ads Mappings' WITH USER_MODE LIMIT 1];
            return setting.MVEX__Fields_Data__c;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'MetaAdsFormMappingController', 'getExistingMappings', e.getMessage());
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
            ErrorHandler.insertErrorData(e, 'MetaAdsFormMappingController', 'saveMapping', e.getMessage());
            resultMap.put('success', false);
            resultMap.put('message', e.getMessage());
        }
        return resultMap;
    }

    private static String subscribeWebhookOnTheFly(String pageId) {
        List<MVEX__OAuth_Configuration__mdt> tokenConfigs = [SELECT MVEX__Access_Token__c, MVEX__API_Version__c, MVEX__Base_URL__c, MVEX__Client_App_Id__c FROM MVEX__OAuth_Configuration__mdt WHERE DeveloperName = 'Meta_Ads_Config' LIMIT 1];
        MVEX__OAuth_Configuration__mdt tokenConfig = tokenConfigs.isEmpty() ? null : tokenConfigs[0];
        if (tokenConfig == null || String.isBlank(tokenConfig.MVEX__Access_Token__c)) {
            return null;
        }
        String systemUserToken = tokenConfig.MVEX__Access_Token__c;
        
        String graphApiVersion = tokenConfig.MVEX__API_Version__c;
        String graphBaseUrl = tokenConfig.MVEX__Base_URL__c;
        
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
        List<MVEX__Error_Handling__c> allLeads = [SELECT Id, Name, CreatedDate, MVEX__Error_Body__c, MVEX__Error_Message__c FROM MVEX__Error_Handling__c WHERE MVEX__Source_of_Error__c = 'MetaFailedLeads' WITH USER_MODE ORDER BY CreatedDate DESC LIMIT 500];
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
    public static String retryFailedLead(String errorRecordId, String mappingJsonOverride) {
        try {
            MVEX__Error_Handling__c err = [SELECT Id, MVEX__Error_Body__c FROM MVEX__Error_Handling__c WHERE Id = :errorRecordId WITH USER_MODE LIMIT 1];
            if (err == null || String.isBlank(err.MVEX__Error_Body__c)) {
                return 'Error record not found or body is empty.';
            }
            
            Map<String, Object> retryPayload = (Map<String, Object>) JSON.deserializeUntyped(err.MVEX__Error_Body__c);
            String lId = (String) retryPayload.get('leadId');
            String pId = (String) retryPayload.get('pageId');
            String fId = (String) retryPayload.get('formId');
            String fName = (String) retryPayload.get('formName');
            Map<String, Object> lData = (Map<String, Object>) retryPayload.get('leadData');
            
            MetaLeadWebhook.ContactContext ctx = new MetaLeadWebhook.ContactContext(lData, fName, pId, fId, lId);
            ctx.isRetry = true;
            ctx.mappingJsonOverride = mappingJsonOverride;
            String result = MetaLeadWebhook.createSalesforceContact(ctx);
            if (result == 'Success') {
                delete as user err;
            } else {
                err.MVEX__Error_Message__c = result;
                update as user err;
            }
            return result;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'MetaAdsFormMappingController', 'retryFailedLead', e.getMessage());
            return 'Retry Error: ' + e.getMessage();
        }
    }

    @AuraEnabled
    public static Map<String, String> retryMultipleFailedLeads(List<String> errorRecordIds) {
        Map<String, String> results = new Map<String, String>();
        for (String recordId : errorRecordIds) {
            results.put(recordId, retryFailedLead(recordId, null));
        }
        return results;
    }

    @AuraEnabled
    public static Boolean deleteFailedLeads(List<String> errorRecordIds) {
        try {
            List<MVEX__Error_Handling__c> toDelete = [SELECT Id FROM MVEX__Error_Handling__c WHERE Id IN :errorRecordIds WITH USER_MODE];
            if (!toDelete.isEmpty()) {
                delete as user toDelete;
            }
            return true;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'MetaAdsFormMappingController', 'deleteFailedLeads', e.getMessage());
            return false;
        }
    }

    @AuraEnabled
    public static List<Map<String, String>> getActiveSites() {
        List<Map<String, String>> sitesList = new List<Map<String, String>>();
        for (Site site : [SELECT Id, Name FROM Site WHERE Status = 'Active']) {
            try {
                SiteDetail detail = [SELECT SecureUrl FROM SiteDetail WHERE DurableId = :site.Id LIMIT 1];
                if (detail != null) {
                    Map<String, String> siteInfo = new Map<String, String>();
                    siteInfo.put('label', site.Name);
                    siteInfo.put('value', detail.SecureUrl);
                    sitesList.add(siteInfo);
                }
            } catch (Exception e) {}
        }
        return sitesList;
    }
}
