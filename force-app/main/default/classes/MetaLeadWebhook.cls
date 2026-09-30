@RestResource(urlMapping='/PAGE/webhooks/*')
global without sharing class MetaLeadWebhook {

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
        Meta_Token_Config__c cfg = Meta_Token_Config__c.getOrgDefaults();
        if (cfg == null || String.isBlank(cfg.System_User_Token_1__c)) {
            return null;
        }
        return cfg.System_User_Token_1__c + (String.isNotBlank(cfg.System_User_Token_2__c) ? cfg.System_User_Token_2__c : '');
    }

    /**
     * Returns the verify token from the legacy config (still used for GET verification).
     */
    private static String getVerifyToken() {
        MVEX__MetaLeadConfig__c cfg = MVEX__MetaLeadConfig__c.getInstance();
        return cfg != null ? cfg.MVEX__VERIFY_TOKEN__c : '';
    }

    /**
     * Fetches a Page Access Token on-the-fly using the System User Token.
     * This is the SAME approach used in MetaAdsFormMappingController which works correctly.
     */
    private static String getPageAccessToken(String pId, String systemUserToken, String apiVersion, String baseUrl) {
        try {
            String url = baseUrl + '/' + apiVersion + '/' + pId + '?fields=access_token&access_token=' + EncodingUtil.urlEncode(systemUserToken, 'UTF-8');
            Map<String, Object> resp = makeGetRequest(url);
            if (resp.containsKey('access_token')) {
                return (String) resp.get('access_token');
            }
        } catch (Exception e) {
            System.debug('Failed to get Page Access Token: ' + e.getMessage());
        }
        // Fallback: use System User Token directly
        return systemUserToken;
    }

    // ─── Webhook GET (verification handshake) ─────────────────────────────────────
    @HttpGet
    global static void doGet() {
        try {
            RestRequest  request  = RestContext.request;
            RestResponse response = RestContext.response;
            if (request.params.get('hub.verify_token') == getVerifyToken()) {
                response.responseBody = Blob.valueOf(request.params.get('hub.challenge'));
            }
        } catch (Exception e) {
            // ErrorHandler.insertErrorData(e, 'MetaLeadWebhook', 'doGet', e.getMessage());
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
                System.debug('MetaLeadWebhook: No System User Token found in Meta_Token_Config__c. Cannot fetch lead.');
                return;
            }

            Integration_App_Config__mdt config = Integration_App_Config__mdt.getInstance('Meta_Ads');
            String apiVersion = config != null ? config.API_Version__c : 'v19.0';
            String baseUrl    = config != null ? config.Base_Url__c    : 'https://graph.facebook.com';

            // Derive Page Access Token (same method used in MetaAdsFormMappingController)
            String pageAccessToken = getPageAccessToken(pageId, systemUserToken, apiVersion, baseUrl);

            Map<String, Object> leadData = fetchLeadData(leadId, pageAccessToken, apiVersion, baseUrl);
            String formName              = fetchFormName(formId, pageAccessToken, apiVersion, baseUrl);
            createSalesforceContact(leadData, formName, pageId, formId, leadId);

        } catch (Exception e) {
            System.debug('MetaLeadWebhook.handlePost Error: ' + e.getMessage() + ' | Line: ' + e.getLineNumber());
            // ErrorHandler.insertErrorData(e, 'MetaLeadWebhook', 'handlePost', e.getMessage());
        }
    }

    // ─── Graph API: fetch lead field data ─────────────────────────────────────────
    public static Map<String, Object> fetchLeadData(String leadgenId, String token, String apiVersion, String baseUrl) {
        String url = baseUrl + '/' + apiVersion + '/' + leadgenId
                   + '?fields=field_data,platform,created_time,campaign_id,campaign_name'
                   + '&access_token=' + EncodingUtil.urlEncode(token, 'UTF-8');
        return makeGetRequest(url);
    }

    // ─── Graph API: fetch form name ───────────────────────────────────────────────
    public static String fetchFormName(String fId, String token, String apiVersion, String baseUrl) {
        try {
            if (String.isBlank(fId)) return '';
            String url = baseUrl + '/' + apiVersion + '/' + fId
                       + '?fields=name&access_token=' + EncodingUtil.urlEncode(token, 'UTF-8');
            Map<String, Object> response = makeGetRequest(url);
            return response.containsKey('name') ? (String) response.get('name') : '';
        } catch (Exception e) {
            System.debug('Error fetching form name: ' + e.getMessage());
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
            System.debug('API Error: ' + e.getMessage());
            // ErrorHandler.insertErrorData(e, 'MetaLeadWebhook', 'makeGetRequest', e.getMessage());
            return new Map<String, Object>();
        }
    }
    

    public static String createSalesforceContact(Map<String, Object> leadData, String formName, String pId, String fId, String lId) {
        if (leadData.containsKey('id') || String.isNotBlank(lId)) {
            Contact newContact = new Contact();

            // --- 2. Handle Platform ---
            String platform = leadData.containsKey('platform') ? (String) leadData.get('platform') : 'facebook';
            newContact.LeadSource = (platform == 'ig') ? 'Instagram' : 'Facebook';
            
            // --- 3. Store Form Name ---
            newContact.MVEX__Meta_Form_Name__c = formName; // Store the fetched name
            newContact.MVEX__Contact_Type__c = 'Buyer';

            if (leadData.containsKey('campaign_id')) {
                newContact.MVEX__MetaCampaignId__c = (String) leadData.get('campaign_id');
            }
            if (leadData.containsKey('campaign_name')) {
                newContact.MVEX__Meta_Campaign_Name__c = (String) leadData.get('campaign_name');
            }

            // --- 4. Process Field Mappings ---
            Map<String, String> currentFormMapping = new Map<String, String>();
            try {
                List<MVEX__Configuration_Settings__c> settings = [SELECT MVEX__Fields_Data__c FROM MVEX__Configuration_Settings__c WHERE Name = 'Meta Ads Mappings' LIMIT 1];
                if (!settings.isEmpty() && String.isNotBlank(settings[0].MVEX__Fields_Data__c)) {
                    Map<String, Object> rootJson = (Map<String, Object>) JSON.deserializeUntyped(settings[0].MVEX__Fields_Data__c);
                    
                    if (rootJson.containsKey(pId)) {
                        Map<String, Object> pageObj = (Map<String, Object>) rootJson.get(pId);
                        if (pageObj.containsKey('forms')) {
                            Map<String, Object> formsObj = (Map<String, Object>) pageObj.get('forms');
                            if (formsObj.containsKey(fId)) {
                                Map<String, Object> formObj = (Map<String, Object>) formsObj.get(fId);
                                if (formObj.containsKey('mappings')) {
                                    Map<String, Object> mappingsObj = (Map<String, Object>) formObj.get('mappings');
                                    for (String metaField : mappingsObj.keySet()) {
                                        currentFormMapping.put(metaField, String.valueOf(mappingsObj.get(metaField)));
                                    }
                                }
                            }
                        }
                    }
                }
            } catch (Exception e) {
                System.debug('Error fetching/parsing mappings JSON: ' + e.getMessage());
            }
            
            // Process field data
            String unmappedData = '';
            
            if (leadData.containsKey('field_data')) {
                List<Object> fieldData = (List<Object>) leadData.get('field_data');
                for (Object field : fieldData) {
                    Map<String, Object> fieldMap = (Map<String, Object>) field;
                    String fieldName = (String) fieldMap.get('name');
                    List<Object> values = (List<Object>) fieldMap.get('values');
                    String fieldValue = values != null && !values.isEmpty() ? String.valueOf(values[0]) : '';
                    
                    if (String.isBlank(fieldValue)) continue;
                    
                    if (currentFormMapping.containsKey(fieldName)) {
                        String sfField = currentFormMapping.get(fieldName);
                        try {
                            newContact.put(sfField, fieldValue);
                        } catch (Exception e) {
                            System.debug('Failed to map ' + fieldName + ' to ' + sfField);
                            unmappedData += fieldName + ': ' + fieldValue + '\n';
                        }
                    } else {
                        // Smart Fallback for unmapped fields
                        String lowerName = fieldName.toLowerCase();
                        if (lowerName.contains('email') && String.isBlank(newContact.Email)) {
                            newContact.Email = fieldValue;
                        } else if (lowerName.contains('phone') && String.isBlank(newContact.Phone)) {
                            newContact.Phone = fieldValue;
                        } else if (lowerName == 'first_name' && String.isBlank(newContact.FirstName)) {
                            newContact.FirstName = fieldValue;
                        } else if (lowerName == 'last_name' && String.isBlank(newContact.LastName)) {
                            newContact.LastName = fieldValue;
                        } else if (lowerName == 'full_name' && String.isBlank(newContact.LastName)) {
                            List<String> nameParts = fieldValue.split(' ', 2);
                            if (nameParts.size() > 1) {
                                newContact.FirstName = nameParts[0];
                                newContact.LastName = nameParts[1];
                            } else {
                                newContact.LastName = fieldValue;
                            }
                        } else {
                            // Append unmapped fields to a string
                            unmappedData += fieldName + ': ' + fieldValue + '\n';
                        }
                    }
                }
            }

            // Append unmapped data to Description if any
            if (String.isNotBlank(unmappedData)) {
                String existingDesc = String.isNotBlank(newContact.Description) ? newContact.Description + '\n\n' : '';
                newContact.Description = existingDesc + '--- Unmapped Meta Lead Data ---\n' + unmappedData;
            }

            // --- 5. Required Field Fallback (Dynamic) ---
            if (String.isBlank(newContact.LastName)) {
                newContact.LastName = 'Unknown Meta Lead';
            }
            
            Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Contact.fields.getMap();
            for (String fieldName : fieldMap.keySet()) {
                Schema.DescribeFieldResult dfr = fieldMap.get(fieldName).getDescribe();
                
                // A field is strictly required if it is createable, not nillable, and not defaulted on create.
                if (dfr.isCreateable() && !dfr.isNillable() && !dfr.isDefaultedOnCreate()) {
                    // Check if value is already populated
                    Object currentVal = newContact.get(fieldName);
                    if (currentVal == null || (currentVal instanceof String && String.isBlank((String)currentVal))) {
                        Schema.DisplayType fType = dfr.getType();
                        try {
                            if (fType == Schema.DisplayType.String || fType == Schema.DisplayType.TextArea || fType == Schema.DisplayType.Phone || fType == Schema.DisplayType.Email || fType == Schema.DisplayType.URL) {
                                newContact.put(fieldName, 'Empty');
                            } else if (fType == Schema.DisplayType.Double || fType == Schema.DisplayType.Integer || fType == Schema.DisplayType.Currency || fType == Schema.DisplayType.Percent) {
                                newContact.put(fieldName, 0);
                            } else if (fType == Schema.DisplayType.Date) {
                                newContact.put(fieldName, Date.today());
                            } else if (fType == Schema.DisplayType.DateTime) {
                                newContact.put(fieldName, DateTime.now());
                            } else if (fType == Schema.DisplayType.Boolean) {
                                newContact.put(fieldName, false);
                            } else if (fType == Schema.DisplayType.Picklist || fType == Schema.DisplayType.MultiPicklist) {
                                List<Schema.PicklistEntry> ple = dfr.getPicklistValues();
                                if (!ple.isEmpty()) {
                                    newContact.put(fieldName, ple[0].getValue());
                                }
                            }
                        } catch (Exception e) {
                            System.debug('Could not assign fallback for required field: ' + fieldName);
                        }
                    }
                }
            }
            
            // --- 6. Insert ---
            Map<String, Object> retryPayload = new Map<String, Object>();
            retryPayload.put('leadId', lId);
            retryPayload.put('pageId', pId);
            retryPayload.put('formId', fId);
            retryPayload.put('formName', formName);
            retryPayload.put('leadData', leadData);
            
            try {
                Database.SaveResult sr = Database.insert(newContact, false);
                if (!sr.isSuccess()) {
                    MVEX__Error_Handling__c errRec = new MVEX__Error_Handling__c();
                    errRec.MVEX__Error_Body__c = JSON.serializePretty(retryPayload);
                    errRec.MVEX__Source_of_Error__c = 'MetaFailedLeads';
                    insert errRec;
                    return sr.getErrors()[0].getMessage();
                }
                return 'Success';
            } catch (Exception e) {
                MVEX__Error_Handling__c errRec = new MVEX__Error_Handling__c();
                errRec.MVEX__Error_Body__c = JSON.serializePretty(retryPayload);
                errRec.MVEX__Source_of_Error__c = 'MetaFailedLeads';
                insert errRec;
                return e.getMessage();
            }
        }
        return 'Invalid Lead Data';
    }
}