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
        MVEX__OAuth_Configuration__mdt cfg = MVEX__OAuth_Configuration__mdt.getInstance('Meta_Ads_Config');
        if (cfg == null || String.isBlank(cfg.MVEX__Access_Token__c)) {
            return null;
        }
        return cfg.MVEX__Access_Token__c;
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

            MVEX__OAuth_Configuration__mdt oauthConfig = MVEX__OAuth_Configuration__mdt.getInstance('Meta_Ads_Config');
            String apiVersion = oauthConfig != null ? oauthConfig.MVEX__API_Version__c : 'v19.0';
            String baseUrl    = oauthConfig != null ? oauthConfig.MVEX__Base_URL__c : 'https://graph.facebook.com';

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
        String url = apiCtx.baseUrl + '/' + apiCtx.apiVersion + '/' + leadgenId
                   + '?fields=field_data,platform,created_time,campaign_id,campaign_name'
                   + '&access_token=' + EncodingUtil.urlEncode(apiCtx.token, 'UTF-8');
        return makeGetRequest(url);
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
    

    public static String createSalesforceContact(ContactContext ctx) {
        if (ctx.leadData.containsKey('id') || String.isNotBlank(ctx.leadId)) {
            Contact newContact = new Contact();

            // --- 2. Handle Platform ---
            String platform = ctx.leadData.containsKey('platform') ? (String) ctx.leadData.get('platform') : 'facebook';
            newContact.LeadSource = (platform == 'ig') ? 'Instagram' : 'Facebook';
            
            // --- 3. Store Form Name ---
            newContact.MVEX__Meta_Form_Name__c = ctx.formName; // Store the fetched name
            newContact.MVEX__Contact_Type__c = 'Buyer';

            if (ctx.leadData.containsKey('campaign_id')) {
                newContact.MVEX__MetaCampaignId__c = (String) ctx.leadData.get('campaign_id');
            }
            if (ctx.leadData.containsKey('campaign_name')) {
                newContact.MVEX__Meta_Campaign_Name__c = (String) ctx.leadData.get('campaign_name');
            }

            // --- 4. Process Field Mappings ---
            Map<String, List<String>> metaToSfFields = new Map<String, List<String>>();
            Map<String, String> sfToCustomValue = new Map<String, String>();
            try {
                String mappingJsonData = '';
                if (String.isNotBlank(ctx.mappingJsonOverride)) {
                    mappingJsonData = ctx.mappingJsonOverride;
                } else {
                    List<MVEX__Configuration_Settings__c> settings = [SELECT MVEX__Fields_Data__c FROM MVEX__Configuration_Settings__c WHERE Name = 'Meta Ads Mappings' WITH USER_MODE LIMIT 1];
                    if (!settings.isEmpty()) {
                        mappingJsonData = settings[0].MVEX__Fields_Data__c;
                    }
                }
                
                if (String.isNotBlank(mappingJsonData)) {
                    Map<String, Object> rootJson = (Map<String, Object>) JSON.deserializeUntyped(mappingJsonData);
                    
                    if (rootJson.containsKey(ctx.pageId)) {
                        Map<String, Object> pageObj = (Map<String, Object>) rootJson.get(ctx.pageId);
                        Map<String, Object> formsObj = new Map<String, Object>();
                        
                        if (pageObj.containsKey('forms')) {
                            formsObj = (Map<String, Object>) pageObj.get('forms');
                        } else {
                            // Fallback to old format where pageObj directly contains form IDs
                            formsObj = pageObj;
                        }
                        
                        if (formsObj.containsKey(ctx.formId)) {
                            Map<String, Object> formObj = (Map<String, Object>) formsObj.get(ctx.formId);
                            Map<String, Object> mappingsObj = new Map<String, Object>();
                            
                            if (formObj.containsKey('mappings')) {
                                mappingsObj = (Map<String, Object>) formObj.get('mappings');
                            } else {
                                // Fallback to old format where formObj directly contains mappings
                                mappingsObj = formObj;
                            }
                            for (String key : mappingsObj.keySet()) {
                                Object val = mappingsObj.get(key);
                                if (val instanceof Map<String, Object>) {
                                    // New format! key is Salesforce field.
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
                                    // Old format! key is Meta Field or "custom", val is Salesforce field.
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
                ErrorHandler.insertErrorData(e, 'MetaLeadWebhook', 'createSalesforceContact_fetchMappings', e.getMessage());
                // Ignore mapping fetch error
            }
            
            // Process field data
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
                            try {
                                newContact.put(sfField, fieldValue);
                            } catch (Exception e) {
                                ErrorHandler.insertErrorData(e, 'MetaLeadWebhook', 'createSalesforceContact_mapField', e.getMessage());
                                unmappedData += fieldName + ' (' + sfField + '): ' + fieldValue + '\n';
                            }
                        }
                    } else {
                        // Append unmapped fields to a string
                        unmappedData += fieldName + ': ' + fieldValue + '\n';
                    }
                }
            }
            
            // Apply custom value mappings
            for (String sfField : sfToCustomValue.keySet()) {
                String customValue = sfToCustomValue.get(sfField);
                try {
                    newContact.put(sfField, customValue);
                } catch (Exception e) {
                    ErrorHandler.insertErrorData(e, 'MetaLeadWebhook', 'createSalesforceContact_customValue', e.getMessage());
                    // mapping failure is ignored
                }
            }

            // Append unmapped data to Description if any
            if (String.isNotBlank(unmappedData)) {
                String existingDesc = String.isNotBlank(newContact.Description) ? newContact.Description + '\n\n' : '';
                newContact.Description = existingDesc + '--- Unmapped Meta Lead Data ---\n' + unmappedData;
            }

            // Removed Required Field Fallback (Dynamic)
            
            // --- 6. Insert ---
            Map<String, Object> retryPayload = new Map<String, Object>();
            retryPayload.put('leadId', ctx.leadId);
            retryPayload.put('pageId', ctx.pageId);
            retryPayload.put('formId', ctx.formId);
            retryPayload.put('formName', ctx.formName);
            retryPayload.put('leadData', ctx.leadData);
            
            try {
                Database.DMLOptions dml = new Database.DMLOptions();
                dml.DuplicateRuleHeader.allowSave = true;
                dml.DuplicateRuleHeader.runAsCurrentUser = true;
                Database.SaveResult sr = Database.insert(newContact, dml);
                if (!sr.isSuccess()) {
                    String errorMsg = sr.getErrors()[0].getMessage();
                    if (!ctx.isRetry) {
                        MVEX__Error_Handling__c errRec = new MVEX__Error_Handling__c();
                        errRec.MVEX__Error_Body__c = JSON.serializePretty(retryPayload);
                        errRec.MVEX__Source_of_Error__c = 'MetaFailedLeads';
                        errRec.MVEX__Error_Message__c = errorMsg;
                        insert errRec;
                    }
                    return errorMsg;
                }
                return 'Success';
            } catch (Exception e) {
                ErrorHandler.insertErrorData(e, 'MetaLeadWebhook', 'createSalesforceContact_insert', e.getMessage());
                if (!ctx.isRetry) {
                    MVEX__Error_Handling__c errRec = new MVEX__Error_Handling__c();
                    errRec.MVEX__Error_Body__c = JSON.serializePretty(retryPayload);
                    errRec.MVEX__Source_of_Error__c = 'MetaFailedLeads';
                    errRec.MVEX__Error_Message__c = e.getMessage();
                    insert errRec;
                }
                return e.getMessage();
            }
        }
        return 'Invalid Lead Data';
    }
}