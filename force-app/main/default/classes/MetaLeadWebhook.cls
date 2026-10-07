@RestResource(urlMapping='/PAGE/webhooks/*')
global with sharing class MetaLeadWebhook {

    public class ApiContext {
        public String token;
        public String apiVersion;
        public String baseUrl;
        public ApiContext(String token, String apiVersion, String baseUrl) {
            this.token = token;
            this.apiVersion = apiVersion;
            this.baseUrl = baseUrl;
        }
    }

    public class ContactContext {
        public Map<String, Object> leadData;
        public String formName;
        public String pageId;
        public String formId;
        public String leadId;
        public Boolean isRetry;
        public String mappingJsonOverride;
        
        public ContactContext(Map<String, Object> leadData, String formName, String pageId, String formId, String leadId) {
            this.leadData = leadData;
            this.formName = formName;
            this.pageId = pageId;
            this.formId = formId;
            this.leadId = leadId;
            this.isRetry = false;
        }
    }

    // ─── IDs parsed from the webhook payload ─────────────────────────────────────
    private static String pageId  = '';
    private static String formId  = '';
    private static String leadId  = '';

    // ─── Token helpers ────────────────────────────────────────────────────────────
    /**
     * Returns the System User Token stored by the SDK (Meta_Token_Config__c).
     * This is the CORRECT token source — the old MVEX__MetaLeadConfig__c is legacy.
     */
    private static String getSystemUserToken() {
        try {
            List<OAuth_Configuration__mdt> cfgs = [SELECT Access_Token__c FROM OAuth_Configuration__mdt WHERE DeveloperName = 'Meta_Ads_Config' WITH USER_MODE LIMIT 1];
            if (cfgs.isEmpty() || String.isBlank(cfgs[0].Access_Token__c)) {
                return null;
            }
            return cfgs[0].Access_Token__c;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'MetaLeadWebhook', 'getSystemUserToken', e.getMessage());
            return null;
        }
    }

    /**
     * Fetches a Page Access Token on-the-fly using the System User Token.
     * This is the SAME approach used in MetaAdsFormMappingController which works correctly.
     */
    private static String getPageAccessToken(String pId, ApiContext apiCtx) {
        try {
            String url = apiCtx.baseUrl + '/' + apiCtx.apiVersion + '/' + pId + '?fields=access_token&access_token=' + EncodingUtil.urlEncode(apiCtx.token, 'UTF-8');
            Map<String, Object> resp = makeGetRequest(url);
            if (resp.containsKey('access_token')) {
                return (String) resp.get('access_token');
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'MetaLeadWebhook', 'getPageAccessToken', e.getMessage());
            // Ignore exception
        }
        // Fallback: use System User Token directly
        return apiCtx.token;
    }

    // ─── Webhook GET (verification handshake) ─────────────────────────────────────
    @HttpGet
    global static void doGet() {
        try {
            RestRequest  request  = RestContext.request;
            RestResponse response = RestContext.response;
            response.responseBody = Blob.valueOf(request.params.get('hub.challenge'));
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'MetaLeadWebhook', 'doGet', e.getMessage());
        }
    }

    // ─── Webhook POST (lead received) ─────────────────────────────────────────────
    @HttpPost
    global static void handlePost() {
        RestResponse res = RestContext.response;
        // Always respond 200 immediately so Meta doesn't retry
        res.statusCode = 200;
        res.responseBody = Blob.valueOf('EVENT_RECEIVED');

        try {
            String rawPostData = RestContext.request.requestBody.toString();
            Map<String, Object> jsonData = (Map<String, Object>) JSON.deserializeUntyped(rawPostData);
            List<Object> entries = (List<Object>) jsonData.get('entry');

            if (entries == null || entries.isEmpty()) return;

            Map<String, Object> entry   = (Map<String, Object>) entries[0];
            List<Object>        changes = (List<Object>) entry.get('changes');
            if (changes == null || changes.isEmpty()) return;

            Map<String, Object> change = (Map<String, Object>) changes[0];
            Map<String, Object> value  = (Map<String, Object>) change.get('value');

            leadId = String.valueOf(value.get('leadgen_id'));
            formId = String.valueOf(value.get('form_id'));
            pageId = String.valueOf(value.get('page_id'));

            // Resolve the correct token chain
            String systemUserToken = getSystemUserToken();
            if (String.isBlank(systemUserToken)) {
                return;
            }

            List<OAuth_Configuration__mdt> oauthConfigs = [SELECT API_Version__c, Base_URL__c FROM OAuth_Configuration__mdt WHERE DeveloperName = 'Meta_Ads_Config' WITH USER_MODE LIMIT 1];
            OAuth_Configuration__mdt oauthConfig = !oauthConfigs.isEmpty() ? oauthConfigs[0] : null;
            String apiVersion = oauthConfig != null ? oauthConfig.API_Version__c : 'v19.0';
            String baseUrl    = oauthConfig != null ? oauthConfig.Base_URL__c : 'https://graph.facebook.com';

            // Derive Page Access Token (same method used in MetaAdsFormMappingController)
            ApiContext sysCtx = new ApiContext(systemUserToken, apiVersion, baseUrl);
            String pageAccessToken = getPageAccessToken(pageId, sysCtx);

            ApiContext pageCtx = new ApiContext(pageAccessToken, apiVersion, baseUrl);
            Map<String, Object> leadData = fetchLeadData(leadId, pageCtx);
            String formName = fetchFormName(formId, pageCtx);
            
            ContactContext cCtx = new ContactContext(leadData, formName, pageId, formId, leadId);
            createSalesforceContact(cCtx);

        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'MetaLeadWebhook', 'handlePost', e.getMessage());
        }
    }

    // ─── Graph API: fetch lead field data ─────────────────────────────────────────
    public static Map<String, Object> fetchLeadData(String leadgenId, ApiContext apiCtx) {
        try {
            String url = apiCtx.baseUrl + '/' + apiCtx.apiVersion + '/' + leadgenId
                       + '?fields=field_data,platform,created_time,campaign_id,campaign_name'
                       + '&access_token=' + EncodingUtil.urlEncode(apiCtx.token, 'UTF-8');
            return makeGetRequest(url);
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'MetaLeadWebhook', 'fetchLeadData', e.getMessage());
            return new Map<String, Object>();
        }
    }

    // ─── Graph API: fetch form name ───────────────────────────────────────────────
    public static String fetchFormName(String fId, ApiContext apiCtx) {
        try {
            if (String.isBlank(fId)) return '';
            String url = apiCtx.baseUrl + '/' + apiCtx.apiVersion + '/' + fId
                       + '?fields=name&access_token=' + EncodingUtil.urlEncode(apiCtx.token, 'UTF-8');
            Map<String, Object> response = makeGetRequest(url);
            return response.containsKey('name') ? (String) response.get('name') : '';
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'MetaLeadWebhook', 'fetchFormName', e.getMessage());
            return '';
        }
    }

    // Helper for Callouts
    private static Map<String, Object> makeGetRequest(String url) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(url);
        req.setMethod('GET');
        Http http = new Http();
        try {
            HTTPResponse res = http.send(req);
            return (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'MetaLeadWebhook', 'makeGetRequest', e.getMessage());
            return new Map<String, Object>();
        }
    }

    /**
     * Method Name : buildContact
     * @description : Builds a Salesforce Contact record from Meta Lead Data.
     * @param ctx ContactContext
     * @param mappingJsonData String JSON mappings
     * @return Contact
     */
    private static Contact buildContact(ContactContext ctx, String mappingJsonData) {
        try {
            if (!ctx.leadData.containsKey('id') && String.isBlank(ctx.leadId)) {
                return null;
            }
            
            Contact newContact = new Contact();
            String platform = ctx.leadData.containsKey('platform') ? (String) ctx.leadData.get('platform') : 'facebook';
            newContact.LeadSource = (platform == 'ig') ? 'Instagram' : 'Facebook';
            newContact.MVEX__Meta_Form_Name__c = ctx.formName;
            newContact.MVEX__Contact_Type__c = 'Buyer';

            if (ctx.leadData.containsKey('campaign_id')) {
                newContact.MVEX__MetaCampaignId__c = (String) ctx.leadData.get('campaign_id');
            }
            if (ctx.leadData.containsKey('campaign_name')) {
                newContact.MVEX__Meta_Campaign_Name__c = (String) ctx.leadData.get('campaign_name');
            }

            Map<String, List<String>> metaToSfFields = new Map<String, List<String>>();
            Map<String, String> sfToCustomValue = new Map<String, String>();
            
            try {
                if (String.isNotBlank(mappingJsonData)) {
                    Map<String, Object> rootJson = (Map<String, Object>) JSON.deserializeUntyped(mappingJsonData);
                    if (rootJson.containsKey(ctx.pageId)) {
                        Map<String, Object> pageObj = (Map<String, Object>) rootJson.get(ctx.pageId);
                        Map<String, Object> formsObj = pageObj.containsKey('forms') ? (Map<String, Object>) pageObj.get('forms') : pageObj;
                        
                        if (formsObj.containsKey(ctx.formId)) {
                            Map<String, Object> formObj = (Map<String, Object>) formsObj.get(ctx.formId);
                            Map<String, Object> mappingsObj = formObj.containsKey('mappings') ? (Map<String, Object>) formObj.get('mappings') : formObj;
                            
                            for (String key : mappingsObj.keySet()) {
                                Object val = mappingsObj.get(key);
                                if (val instanceof Map<String, Object>) {
                                    Map<String, Object> fieldObj = (Map<String, Object>) val;
                                    String sType = (String) fieldObj.get('sourceType');
                                    if (sType == 'Meta Form Field') {
                                        String mField = (String) fieldObj.get('metaField');
                                        if (String.isNotBlank(mField)) {
                                            if (!metaToSfFields.containsKey(mField)) metaToSfFields.put(mField, new List<String>());
                                            metaToSfFields.get(mField).add(key);
                                        }
                                    } else if (sType == 'Custom Value') {
                                        String cVal = (String) fieldObj.get('customValue');
                                        if (String.isNotBlank(cVal)) {
                                            sfToCustomValue.put(key, cVal);
                                        }
                                    }
                                } else {
                                    String sfField = String.valueOf(val);
                                    if (key.startsWith('"') && key.endsWith('"')) {
                                        sfToCustomValue.put(sfField, key.substring(1, key.length() - 1));
                                    } else {
                                        if (!metaToSfFields.containsKey(key)) metaToSfFields.put(key, new List<String>());
                                        metaToSfFields.get(key).add(sfField);
                                    }
                                }
                            }
                        }
                    }
                }
            } catch (Exception e) {
                ErrorHandler.insertErrorData(e, 'MetaLeadWebhook', 'buildContact_fetchMappings', e.getMessage());
            }

            String unmappedData = '';
            if (ctx.leadData.containsKey('field_data')) {
                List<Object> fieldData = (List<Object>) ctx.leadData.get('field_data');
                for (Object field : fieldData) {
                    Map<String, Object> fieldMap = (Map<String, Object>) field;
                    String fieldName = (String) fieldMap.get('name');
                    List<Object> values = (List<Object>) fieldMap.get('values');
                    String fieldValue = values != null && !values.isEmpty() ? String.valueOf(values[0]) : '';
                    
                    if (String.isBlank(fieldValue)) continue;
                    
                    if (metaToSfFields.containsKey(fieldName)) {
                        for (String sfField : metaToSfFields.get(fieldName)) {
                            newContact.put(sfField, fieldValue);
                        }
                    } else {
                        unmappedData += fieldName + ': ' + fieldValue + '\n';
                    }
                }
            }

            for (String sfField : sfToCustomValue.keySet()) {
                newContact.put(sfField, sfToCustomValue.get(sfField));
            }

            if (String.isNotBlank(unmappedData)) {
                String existingDesc = String.isNotBlank(newContact.Description) ? newContact.Description + '\n\n' : '';
                newContact.Description = existingDesc + '--- Unmapped Meta Lead Data ---\n' + unmappedData;
            }

            return newContact;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'MetaLeadWebhook', 'buildContact', e.getMessage());
            return null;
        }
    }

    /**
     * Method Name : processMultipleContacts
     * @description : Processes multiple contacts in bulk to avoid SOQL/DML in loops.
     * @param ctxMap Map of unique identifier to ContactContext
     * @return Map of unique identifier to result string
     */
    public static Map<String, String> processMultipleContacts(Map<String, ContactContext> ctxMap) {
        try {
            Map<String, String> results = new Map<String, String>();
            List<Contact> contactsToInsert = new List<Contact>();
            List<String> orderedCtxKeys = new List<String>();
            List<ContactContext> orderedCtxs = new List<ContactContext>();
            
            // 1. Fetch Mapping ONCE
            String bulkMappingJsonData = '';
            try {
                List<MVEX__Configuration_Settings__c> settings = [SELECT MVEX__Fields_Data__c FROM MVEX__Configuration_Settings__c WHERE Name = 'Meta Ads Mappings' WITH USER_MODE LIMIT 1];
                if (!settings.isEmpty()) {
                    bulkMappingJsonData = settings[0].MVEX__Fields_Data__c;
                }
            } catch (Exception e) {
                ErrorHandler.insertErrorData(e, 'MetaLeadWebhook', 'processMultipleContacts_fetchMappings', e.getMessage());
            }

            // 2. Build Contacts
            for (String ctxId : ctxMap.keySet()) {
                ContactContext ctx = ctxMap.get(ctxId);
                String mappingToUse = String.isNotBlank(ctx.mappingJsonOverride) ? ctx.mappingJsonOverride : bulkMappingJsonData;
                
                Contact c = buildContact(ctx, mappingToUse);
                if (c != null) {
                    contactsToInsert.add(c);
                    orderedCtxKeys.add(ctxId);
                    orderedCtxs.add(ctx);
                } else {
                    results.put(ctxId, 'Invalid Lead Data');
                }
            }

            // 3. Insert Bulk
            if (!contactsToInsert.isEmpty()) {
                try {
                    Database.DMLOptions dml = new Database.DMLOptions();
                    dml.DuplicateRuleHeader.allowSave = true;
                    dml.DuplicateRuleHeader.runAsCurrentUser = true;
                    List<Database.SaveResult> srs = Database.insert(contactsToInsert, dml);
                    
                    List<MVEX__Error_Handling__c> errsToInsert = new List<MVEX__Error_Handling__c>();

                    for (Integer i = 0; i < srs.size(); i++) {
                        Database.SaveResult sr = srs[i];
                        String ctxId = orderedCtxKeys[i];
                        ContactContext ctx = orderedCtxs[i];
                        
                        if (sr.isSuccess()) {
                            results.put(ctxId, 'Success');
                        } else {
                            String errorMsg = sr.getErrors()[0].getMessage();
                            results.put(ctxId, errorMsg);
                            
                            if (!ctx.isRetry) {
                                Map<String, Object> retryPayload = new Map<String, Object>();
                                retryPayload.put('leadId', ctx.leadId);
                                retryPayload.put('pageId', ctx.pageId);
                                retryPayload.put('formId', ctx.formId);
                                retryPayload.put('formName', ctx.formName);
                                retryPayload.put('leadData', ctx.leadData);

                                MVEX__Error_Handling__c errRec = new MVEX__Error_Handling__c();
                                errRec.MVEX__Error_Body__c = JSON.serializePretty(retryPayload);
                                errRec.MVEX__Source_of_Error__c = 'MetaFailedLeads';
                                errRec.MVEX__Error_Message__c = errorMsg;
                                errsToInsert.add(errRec);
                            }
                        }
                    }
                    
                    if (!errsToInsert.isEmpty()) {
                        insert errsToInsert;
                    }

                } catch (Exception e) {
                    ErrorHandler.insertErrorData(e, 'MetaLeadWebhook', 'processMultipleContacts_insert', e.getMessage());
                    // Mark all un-successful as failed due to exception
                    for (String ctxId : orderedCtxKeys) {
                        if (!results.containsKey(ctxId)) {
                            results.put(ctxId, e.getMessage());
                        }
                    }
                }
            }
            return results;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'MetaLeadWebhook', 'processMultipleContacts', e.getMessage());
            return new Map<String, String>();
        }
    }

    /**
     * Method Name : createSalesforceContact
     * @description : Processes the lead data and creates/inserts a Salesforce Contact. Kept for backwards compatibility.
     * @param ctx ContactContext
     * @return String
     */
    public static String createSalesforceContact(ContactContext ctx) {
        try {
            Map<String, ContactContext> mapCtx = new Map<String, ContactContext>();
            mapCtx.put('single', ctx);
            Map<String, String> res = processMultipleContacts(mapCtx);
            return res.get('single');
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'MetaLeadWebhook', 'createSalesforceContact', e.getMessage());
            return e.getMessage();
        }
    }
}