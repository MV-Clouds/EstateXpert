public with sharing class GoogleAdsFormMappingController {

    private static final String GOOGLE_CONFIG_DEV_NAME = 'Google_Ads_Config';
    private static final String GOOGLE_MAPPING_NAME = GoogleLeadsWebhook.GOOGLE_MAPPING_NAME;
    private static final String GOOGLE_FAILED_SOURCE = GoogleLeadsWebhook.FAILED_SOURCE;
    private static final String WEBHOOK_PATH = '/services/apexrest/Lead';
    private static final Integer MAX_RETRY_BATCH = 200;

    private static final Set<String> SYSTEM_FIELDS = new Set<String>{
        'ownerid', 'recordtypeid', 'currencyisocode', 'createdbyid', 'lastmodifiedbyid', 'masterrecordid'
    };

    // AuraHandledException.getMessage() returns "Script-thrown exception" unless setMessage() is called.
    private static AuraHandledException auraError(String message) {
        AuraHandledException e = new AuraHandledException(message);
        e.setMessage(message);
        return e;
    }

    private static Map<String, Object> response(Boolean success, String message) {
        return new Map<String, Object>{ 'success' => success, 'message' => message };
    }

    private static String enc(String value) {
        return EncodingUtil.urlEncode(value, 'UTF-8');
    }

    private static String str(Object value) {
        return value == null ? null : String.valueOf(value);
    }

    private static OAuth_Configuration__mdt getGoogleOAuthConfiguration() {
        OAuth_Configuration__mdt config = OAuth_Configuration__mdt.getInstance(GOOGLE_CONFIG_DEV_NAME);
        if (config == null) {
            throw auraError('Google Ads OAuth configuration was not found.');
        }
        return config;
    }

    private static String getBaseUrl(OAuth_Configuration__mdt config) {
        return config.Base_URL__c + config.API_Version__c;
    }

    private static MVEX__Configuration_Settings__c getMappingSetting() {
        List<MVEX__Configuration_Settings__c> settings = [SELECT Id, MVEX__Fields_Data__c FROM MVEX__Configuration_Settings__c WHERE Name = :GOOGLE_MAPPING_NAME WITH USER_MODE LIMIT 1];
        return settings.isEmpty() ? null : settings[0];
    }

    private static Map<String, Object> getMappingData(MVEX__Configuration_Settings__c setting) {
        if (setting == null || String.isBlank(setting.MVEX__Fields_Data__c)) {
            return new Map<String, Object>();
        }
        return (Map<String, Object>)JSON.deserializeUntyped(setting.MVEX__Fields_Data__c);
    }

    // Updates one field of the Google OAuth custom metadata record (async deployment).
    private static void updateConfigField(String fieldName, String value) {
        OAuth_Configuration__mdt config = getGoogleOAuthConfiguration();

        Metadata.CustomMetadata record = new Metadata.CustomMetadata();
        record.fullName = 'OAuth_Configuration__mdt.' + config.DeveloperName;
        record.label = config.MasterLabel;

        Metadata.CustomMetadataValue fieldValue = new Metadata.CustomMetadataValue();
        fieldValue.field = fieldName;
        fieldValue.value = value;
        record.values.add(fieldValue);

        Metadata.DeployContainer container = new Metadata.DeployContainer();
        container.addMetadata(record);
        Metadata.Operations.enqueueDeployment(container, null);
    }

    @AuraEnabled
    public static List<FailedLead> getFailedLeads(String formId) {
        if (String.isBlank(formId)) {
            throw auraError('Form Id is required.');
        }
        List<FailedLead> result = new List<FailedLead>();

        for (MVEX__Error_Handling__c err : [SELECT Id, CreatedDate, MVEX__Error_Body__c FROM MVEX__Error_Handling__c WHERE MVEX__Source_of_Error__c = :GOOGLE_FAILED_SOURCE WITH USER_MODE ORDER BY CreatedDate DESC LIMIT 2000]) {
            if (String.isBlank(err.MVEX__Error_Body__c)) {
                continue;
            }
            try {
                Map<String, Object> parsed = (Map<String, Object>)JSON.deserializeUntyped(err.MVEX__Error_Body__c);
                if (formId != getFormIdFromBody(parsed)) {
                    continue;
                }
                FailedLead fl = new FailedLead();
                fl.id = err.Id;
                fl.receivedOn = err.CreatedDate;
                fl.leadId = getLeadIdFromBody(parsed);
                fl.reason = parsed.containsKey('reason') ? String.valueOf(parsed.get('reason')) : 'Unknown error (older record)';
                result.add(fl);
            } catch (Exception e) {
                // skip records that cannot be parsed
            }
        }
        return result;
    }

    // Uses the SAVED mapping, so save the mapping first when it was changed.
    @AuraEnabled
    public static List<RetryResult> retryFailedLeads(List<String> errorIds) {
        if (errorIds == null || errorIds.isEmpty()) {
            throw auraError('Select at least one failed lead to retry.');
        }
        if (errorIds.size() > MAX_RETRY_BATCH) {
            throw auraError('You can retry up to ' + MAX_RETRY_BATCH + ' leads at a time.');
        }

        List<MVEX__Error_Handling__c> errors = [SELECT Id, MVEX__Error_Body__c FROM MVEX__Error_Handling__c WHERE Id IN :errorIds AND MVEX__Source_of_Error__c = :GOOGLE_FAILED_SOURCE WITH USER_MODE];

        List<RetryResult> results = new List<RetryResult>();
        List<Contact> contacts = new List<Contact>();
        List<MVEX__Error_Handling__c> pendingErrors = new List<MVEX__Error_Handling__c>();
        List<RetryResult> pendingResults = new List<RetryResult>();
        Map<String, Map<String, Object>> parsedById = new Map<String, Map<String, Object>>();
        Map<String, GoogleLeadsWebhook.FormConfiguration> configCache = new Map<String, GoogleLeadsWebhook.FormConfiguration>();
        List<MVEX__Error_Handling__c> toUpdate = new List<MVEX__Error_Handling__c>();

        for (MVEX__Error_Handling__c err : errors) {
            RetryResult r = new RetryResult();
            r.id = err.Id;
            r.success = false;
            results.add(r);
            try {
                Map<String, Object> parsed = (Map<String, Object>)JSON.deserializeUntyped(err.MVEX__Error_Body__c);
                parsedById.put(err.Id, parsed);

                GoogleLeadsWebhook.LeadData lead = toLeadData(parsed);
                String formId = getFormIdFromBody(parsed);

                if (!configCache.containsKey(formId)) {
                    configCache.put(formId, GoogleLeadsWebhook.getFormConfiguration(formId));
                }
                GoogleLeadsWebhook.FormConfiguration cfg = configCache.get(formId);
                if (cfg == null || cfg.mappings == null || cfg.mappings.isEmpty()) {
                    throw new GoogleLeadsWebhook.LeadProcessingException('No field mapping found for Form Id: ' + formId);
                }

                contacts.add(GoogleLeadsWebhook.buildContact(lead, cfg));
                pendingErrors.add(err);
                pendingResults.add(r);
            } catch (Exception e) {
                r.message = e.getMessage();
                err.MVEX__Error_Body__c = withReason(parsedById.get(err.Id), err.MVEX__Error_Body__c, r.message);
                toUpdate.add(err);
            }
        }

        if (!contacts.isEmpty()) {
            List<Database.SaveResult> saveResults = Database.insert(contacts, false);
            List<Id> toDelete = new List<Id>();

            for (Integer i = 0; i < saveResults.size(); i++) {
                if (saveResults[i].isSuccess()) {
                    pendingResults[i].success = true;
                    pendingResults[i].message = 'Processed';
                    toDelete.add(pendingErrors[i].Id);
                } else {
                    String msg = saveResults[i].getErrors()[0].getMessage();
                    pendingResults[i].message = msg;
                    pendingErrors[i].MVEX__Error_Body__c = withReason(parsedById.get(pendingErrors[i].Id), pendingErrors[i].MVEX__Error_Body__c, msg);
                    toUpdate.add(pendingErrors[i]);
                }
            }
            if (!toDelete.isEmpty()) {
                Database.delete(toDelete, false);
            }
        }
        if (!toUpdate.isEmpty()) {
            Database.update(toUpdate, false);
        }
        return results;
    }

    @AuraEnabled
    public static Integer discardFailedLeads(List<String> errorIds) {
        if (errorIds == null || errorIds.isEmpty()) {
            throw auraError('Select at least one failed lead.');
        }
        List<MVEX__Error_Handling__c> records = [SELECT Id FROM MVEX__Error_Handling__c WHERE Id IN :errorIds AND MVEX__Source_of_Error__c = :GOOGLE_FAILED_SOURCE WITH USER_MODE];
        delete as user records;
        return records.size();
    }

    // New records: {formId, leadId, reason, payload:{...}}. Older records: the raw Google payload.
    private static String getFormIdFromBody(Map<String, Object> parsed) {
        return str(parsed.containsKey('payload') ? parsed.get('formId') : parsed.get('form_id'));
    }

    private static String getLeadIdFromBody(Map<String, Object> parsed) {
        return str(parsed.containsKey('payload') ? parsed.get('leadId') : parsed.get('lead_id'));
    }

    private static GoogleLeadsWebhook.LeadData toLeadData(Map<String, Object> parsed) {
        Object payload = parsed.containsKey('payload') ? parsed.get('payload') : parsed;
        return (GoogleLeadsWebhook.LeadData)JSON.deserialize(JSON.serialize(payload), GoogleLeadsWebhook.LeadData.class);
    }

    private static String withReason(Map<String, Object> parsed, String originalBody, String reason) {
        if (parsed == null) {
            return originalBody;
        }
        Map<String, Object> envelope = parsed.containsKey('payload')
            ? parsed
            : new Map<String, Object>{ 'formId' => getFormIdFromBody(parsed), 'leadId' => getLeadIdFromBody(parsed), 'payload' => parsed };
        envelope.put('reason', String.isBlank(reason) ? 'Unknown error' : reason.left(1000));
        return JSON.serialize(envelope);
    }

    @AuraEnabled(cacheable=false)
    public static String getGoogleAuthUrl() {
        OAuth_Configuration__mdt config = getGoogleOAuthConfiguration();

        if (String.isBlank(config.Client_Id__c) || String.isBlank(config.Authorization_Endpoint__c) || String.isBlank(config.Scope__c)) {
            throw auraError('Google Ads OAuth configuration is incomplete.');
        }

        return config.Authorization_Endpoint__c
            + '?client_id=' + enc(config.Client_Id__c)
            + '&redirect_uri=' + enc(config.Redirect_URI__c)
            + '&response_type=code'
            + '&scope=' + enc(config.Scope__c)
            + '&access_type=offline'
            + '&prompt=consent'
            + '&state=' + enc(UserInfo.getUserId());
    }

    @AuraEnabled
    public static String saveRefreshToken(String refreshToken) {
        try {
            if (String.isBlank(refreshToken)) {
                throw auraError('Refresh token cannot be blank.');
            }
            updateConfigField('Refresh_Token__c', refreshToken);
            return 'success';
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'GoogleAdsFormMappingController', 'saveRefreshToken', e.getStackTraceString());
            throw auraError('Failed to save Google Ads refresh token.');
        }
    }

    @AuraEnabled(cacheable=false)
    public static List<GoogleAdsAccount> getConnection() {
        OAuth_Configuration__mdt config = getGoogleOAuthConfiguration();

        if (String.isBlank(config.Refresh_Token__c)) {
            return new List<GoogleAdsAccount>();
        }
        return getAllAccounts(getAccessToken(), getBaseUrl(config));
    }

    private static String getAccessToken() {
        OAuth_Configuration__mdt config = getGoogleOAuthConfiguration();

        if (String.isBlank(config.Client_Id__c) || String.isBlank(config.Client_Secret__c) || String.isBlank(config.Token_Endpoint__c)) {
            throw auraError('Google Ads OAuth configuration is incomplete.');
        }
        if (String.isBlank(config.Refresh_Token__c)) {
            throw auraError('Google Ads is not connected.');
        }

        HttpRequest request = new HttpRequest();
        request.setEndpoint(config.Token_Endpoint__c);
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        request.setBody(
            'client_id=' + enc(config.Client_Id__c) +
            '&client_secret=' + enc(config.Client_Secret__c) +
            '&refresh_token=' + enc(config.Refresh_Token__c) +
            '&grant_type=refresh_token'
        );

        HttpResponse response = new Http().send(request);
        if (response.getStatusCode() != 200) {
            throw auraError('Failed to obtain Google Ads access token. ' + response.getBody());
        }

        String accessToken = (String)((Map<String, Object>)JSON.deserializeUntyped(response.getBody())).get('access_token');
        if (String.isBlank(accessToken)) {
            throw auraError('Google did not return an access token.');
        }
        return accessToken;
    }

    // One place that builds every Google Ads API call.
    private static HttpResponse callGoogleAds(String method, String endpoint, String accessToken, String loginCustomerId, Map<String, Object> body) {
        HttpRequest request = new HttpRequest();
        request.setEndpoint(endpoint);
        request.setMethod(method);
        request.setHeader('Authorization', 'Bearer ' + accessToken);
        if (String.isNotBlank(loginCustomerId)) {
            request.setHeader('login-customer-id', loginCustomerId);
        }
        if (body != null) {
            request.setHeader('Content-Type', 'application/json');
            request.setBody(JSON.serialize(body));
        }
        return new Http().send(request);
    }

    // Runs a GAQL query and returns the parsed response; throws with errorPrefix on failure.
    private static Map<String, Object> searchGoogleAds(String accessToken, String baseUrl, String customerId, String loginCustomerId, String query, String errorPrefix) {
        HttpResponse response = callGoogleAds('POST', baseUrl + '/customers/' + customerId + '/googleAds:search', accessToken, loginCustomerId, new Map<String, Object>{ 'query' => query });
        if (response.getStatusCode() != 200) {
            throw auraError(errorPrefix + ' ' + response.getBody());
        }
        return (Map<String, Object>)JSON.deserializeUntyped(response.getBody());
    }

    private static List<GoogleAdsAccount> getAllAccounts(String accessToken, String baseUrl) {
        List<GoogleAdsAccount> accounts = new List<GoogleAdsAccount>();

        HttpResponse response = callGoogleAds('GET', baseUrl + '/customers:listAccessibleCustomers', accessToken, null, null);
        if (response.getStatusCode() != 200) {
            throw auraError('Failed to retrieve Google Ads accounts. ' + response.getBody());
        }

        List<Object> resourceNames = (List<Object>)((Map<String, Object>)JSON.deserializeUntyped(response.getBody())).get('resourceNames');
        if (resourceNames == null) {
            return accounts;
        }

        for (Object resourceName : resourceNames) {
            accounts.addAll(getCustomerAccounts(accessToken, String.valueOf(resourceName).replace('customers/', ''), baseUrl));
        }
        return accounts;
    }

    private static List<GoogleAdsAccount> getCustomerAccounts(String accessToken, String customerId, String baseUrl) {
        List<GoogleAdsAccount> accounts = new List<GoogleAdsAccount>();

        Map<String, Object> data = searchGoogleAds(
            accessToken, baseUrl, customerId, null,
            'SELECT customer_client.id, customer_client.descriptive_name, customer_client.manager FROM customer_client',
            'Failed to retrieve Google Ads customer accounts.'
        );

        List<Object> results = (List<Object>)data.get('results');
        if (results == null) {
            return accounts;
        }

        for (Object resultObject : results) {
            Map<String, Object> customer = (Map<String, Object>)((Map<String, Object>)resultObject).get('customerClient');
            if (customer == null) {
                continue;
            }
            GoogleAdsAccount account = new GoogleAdsAccount();
            account.id = str(customer.get('id'));
            account.descriptiveName = str(customer.get('descriptiveName'));
            account.manager = customer.get('manager') == null ? false : (Boolean)customer.get('manager');
            account.loginCustomerId = customerId;
            accounts.add(account);
        }
        return accounts;
    }

    @AuraEnabled(cacheable=false)
    public static List<GoogleLeadForm> getFormsForAccount(String accountString) {
        if (String.isBlank(accountString)) {
            throw auraError('Google Ads account is required.');
        }

        GoogleAdsAccount account;
        try {
            account = (GoogleAdsAccount)JSON.deserialize(accountString, GoogleAdsAccount.class);
        } catch (Exception e) {
            throw auraError('Invalid Google Ads account data.');
        }
        if (account == null || String.isBlank(account.id) || String.isBlank(account.loginCustomerId)) {
            throw auraError('Google Ads account information is incomplete.');
        }

        Map<String, Object> data = searchGoogleAds(
            getAccessToken(), getBaseUrl(getGoogleOAuthConfiguration()), account.id, account.loginCustomerId,
            'SELECT asset.id, asset.resource_name, asset.name, asset.lead_form_asset.headline, asset.lead_form_asset.fields, asset.lead_form_asset.custom_question_fields FROM asset WHERE asset.type = \'LEAD_FORM\'',
            'Failed to retrieve Google Lead Forms.'
        );

        List<GoogleLeadForm> forms = new List<GoogleLeadForm>();
        List<Object> results = (List<Object>)data.get('results');
        if (results == null) {
            return forms;
        }

        for (Object resultObject : results) {
            Map<String, Object> asset = (Map<String, Object>)((Map<String, Object>)resultObject).get('asset');
            if (asset == null) {
                continue;
            }

            GoogleLeadForm form = new GoogleLeadForm();
            form.id = str(asset.get('id'));
            form.name = String.isBlank(str(asset.get('name'))) ? str(asset.get('resourceName')) : str(asset.get('name'));
            form.fields = new List<String>();
            form.customQuestions = new List<String>();
            forms.add(form);

            Map<String, Object> leadForm = (Map<String, Object>)asset.get('leadFormAsset');
            if (leadForm == null) {
                continue;
            }

            form.headline = str(leadForm.get('headline'));
            form.fields = collectStrings(leadForm.get('fields'), 'inputType');
            form.customQuestions = collectStrings(leadForm.get('customQuestionFields'), 'customQuestionText');
        }
        return forms;
    }

    // Pulls one key out of each map in a JSON array.
    private static List<String> collectStrings(Object items, String key) {
        List<String> values = new List<String>();
        if (items == null) {
            return values;
        }
        for (Object item : (List<Object>)items) {
            Object value = item == null ? null : ((Map<String, Object>)item).get(key);
            if (value != null) {
                values.add(String.valueOf(value));
            }
        }
        return values;
    }

    @AuraEnabled
    public static String getExistingMappings() {
        MVEX__Configuration_Settings__c setting = getMappingSetting();
        return setting == null ? null : setting.MVEX__Fields_Data__c;
    }

    @AuraEnabled
    public static Map<String, Object> saveMapping(String mappingJson) {
        try {
            if (String.isBlank(mappingJson)) {
                throw auraError('Mapping data cannot be empty.');
            }

            Map<String, Object> mappingData;
            try {
                mappingData = (Map<String, Object>)JSON.deserializeUntyped(mappingJson);
            } catch (Exception e) {
                throw auraError('Invalid mapping data.');
            }
            validateMappingStructure(mappingData);

            MVEX__Configuration_Settings__c setting = getMappingSetting();
            if (setting == null) {
                setting = new MVEX__Configuration_Settings__c(Name = GOOGLE_MAPPING_NAME);
            }

            // Only forms that were not already saved need a new webhook subscription.
            Set<String> alreadySubscribed = new Set<String>();
            for (Map<String, String> form : collectForms(getMappingData(setting))) {
                alreadySubscribed.add(form.get('accountId') + '_' + form.get('formId'));
            }
            List<Map<String, String>> formsToSubscribe = new List<Map<String, String>>();
            for (Map<String, String> form : collectForms(mappingData)) {
                if (!alreadySubscribed.contains(form.get('accountId') + '_' + form.get('formId'))) {
                    formsToSubscribe.add(form);
                }
            }
            subscribeWebhook(formsToSubscribe);

            setting.MVEX__Fields_Data__c = JSON.serialize(mappingData);
            setting.MVEX__Feature_Name__c = GOOGLE_MAPPING_NAME;
            upsert as user setting;

            return response(true, 'Google Ads mapping saved successfully.');
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'GoogleAdsFormMappingController', 'saveMapping', e.getStackTraceString());
            return response(false, e.getMessage());
        }
    }

    private static void validateMappingStructure(Map<String, Object> mappingData) {
        if (mappingData == null || mappingData.isEmpty()) {
            throw auraError('No mapping data was provided.');
        }

        for (String accountId : mappingData.keySet()) {
            Map<String, Object> accountData = (Map<String, Object>)mappingData.get(accountId);
            if (accountData == null) {
                throw auraError('Invalid Google Ads account mapping.');
            }
            if (!accountData.containsKey('loginCustomerId')) {
                throw auraError('Login customer ID is required for account ' + accountId + '.');
            }
            if (!accountData.containsKey('forms')) {
                throw auraError('Forms are required for account ' + accountId + '.');
            }

            Map<String, Object> forms = (Map<String, Object>)accountData.get('forms');
            if (forms == null) {
                throw auraError('Invalid forms data for account ' + accountId + '.');
            }

            for (String formId : forms.keySet()) {
                Map<String, Object> form = (Map<String, Object>)forms.get(formId);
                if (form == null) {
                    throw auraError('Invalid form mapping for form ' + formId + '.');
                }
                if (!form.containsKey('mappings')) {
                    throw auraError('Mappings are required for form ' + formId + '.');
                }
            }
        }
    }

    // Flattens {accountId: {loginCustomerId, forms: {formId: ...}}} into one entry per form.
    private static List<Map<String, String>> collectForms(Map<String, Object> mappingData) {
        List<Map<String, String>> resources = new List<Map<String, String>>();

        for (String accountId : mappingData.keySet()) {
            Map<String, Object> accountData = (Map<String, Object>)mappingData.get(accountId);
            Map<String, Object> forms = accountData == null ? null : (Map<String, Object>)accountData.get('forms');
            if (forms == null) {
                continue;
            }
            String loginCustomerId = String.valueOf(accountData.get('loginCustomerId'));

            for (String formId : forms.keySet()) {
                resources.add(new Map<String, String>{
                    'accountId' => accountId,
                    'formId' => formId,
                    'loginCustomerId' => loginCustomerId
                });
            }
        }
        return resources;
    }

    @AuraEnabled
    public static Map<String, Object> deleteMapping(String accountId, String loginCustomerId, String formId) {
        try {
            if (String.isBlank(accountId) || String.isBlank(loginCustomerId) || String.isBlank(formId)) {
                throw auraError('Account ID, Login Customer ID and Form ID are required.');
            }

            MVEX__Configuration_Settings__c setting = getMappingSetting();
            if (setting == null) {
                return response(true, 'Mapping configuration does not exist.');
            }
            if (String.isBlank(setting.MVEX__Fields_Data__c)) {
                return response(true, 'Mapping does not exist.');
            }

            Map<String, Object> mappingData = getMappingData(setting);
            if (!mappingData.containsKey(accountId)) {
                return response(true, 'Account mapping does not exist.');
            }

            Map<String, Object> accountData = (Map<String, Object>)mappingData.get(accountId);
            Map<String, Object> forms = (Map<String, Object>)accountData.get('forms');
            if (forms == null || !forms.containsKey(formId)) {
                return response(true, 'Form mapping does not exist.');
            }

            mutateDeliveryMethods(
                getAccessToken(), getGoogleOAuthConfiguration(),
                new Map<String, String>{ 'accountId' => accountId, 'loginCustomerId' => loginCustomerId, 'formId' => formId },
                new List<Object>(), 'unsubscribe'
            );

            forms.remove(formId);
            if (forms.isEmpty()) {
                mappingData.remove(accountId);
            }

            setting.MVEX__Fields_Data__c = mappingData.isEmpty() ? null : JSON.serialize(mappingData);
            setting.MVEX__Feature_Name__c = GOOGLE_MAPPING_NAME;
            update as user setting;

            return response(true, 'Mapping deleted successfully.');
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'GoogleAdsFormMappingController', 'deleteMapping', e.getStackTraceString());
            return response(false, e.getMessage());
        }
    }

    @AuraEnabled
    public static Map<String, Object> disconnectGoogleAds() {
        try {
            MVEX__Configuration_Settings__c setting = getMappingSetting();
            OAuth_Configuration__mdt config = getGoogleOAuthConfiguration();
            String refreshToken = config.Refresh_Token__c;

            if (String.isNotBlank(refreshToken)) {
                List<Map<String, String>> mappedForms = collectForms(getMappingData(setting));
                if (!mappedForms.isEmpty()) {
                    String accessToken = getAccessToken();
                    for (Map<String, String> mappedForm : mappedForms) {
                        if (String.isNotBlank(mappedForm.get('loginCustomerId'))) {
                            mutateDeliveryMethods(accessToken, config, mappedForm, new List<Object>(), 'unsubscribe');
                        }
                    }
                }
                revokeGoogleRefreshToken(refreshToken);
            }

            if (setting != null) {
                delete as user setting;
            }
            if (String.isNotBlank(refreshToken)) {
                clearStoredRefreshToken();
            }

            return response(true, 'Google Ads disconnected successfully.');
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'GoogleAdsFormMappingController', 'disconnectGoogleAds', e.getStackTraceString());
            return response(false, e.getMessage());
        }
    }

    private static void revokeGoogleRefreshToken(String refreshToken) {
        HttpRequest request = new HttpRequest();
        request.setEndpoint('https://oauth2.googleapis.com/revoke');
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        request.setBody('token=' + enc(refreshToken));
        HttpResponse response = new Http().send(request);

        if (response.getStatusCode() != 200 && response.getStatusCode() != 400) {
            throw auraError('Failed to revoke Google refresh token. Status: ' + response.getStatusCode() + ' Response: ' + response.getBody());
        }
    }

    @future
    private static void clearStoredRefreshToken() {
        updateConfigField('Refresh_Token__c', '');
    }

    private static void subscribeWebhook(List<Map<String, String>> resources) {
        if (resources == null || resources.isEmpty()) {
            return;
        }

        OAuth_Configuration__mdt config = getGoogleOAuthConfiguration();
        String accessToken = getAccessToken();

        List<Object> deliveryMethods = new List<Object>{
            new Map<String, Object>{
                'webhook' => new Map<String, Object>{
                    'advertiser_webhook_url' => getWebhookEndpoint(),
                    'google_secret' => GoogleLeadsWebhook.GOOGLE_SECRET,
                    'payload_schema_version' => 3
                }
            }
        };

        for (Map<String, String> resource : resources) {
            if (String.isBlank(resource.get('accountId')) || String.isBlank(resource.get('formId')) || String.isBlank(resource.get('loginCustomerId'))) {
                throw auraError('Invalid Google Lead Form subscription data.');
            }
            mutateDeliveryMethods(accessToken, config, resource, deliveryMethods, 'subscribe');
        }
    }

    // Sets the lead form's delivery methods (empty list = unsubscribe).
    private static void mutateDeliveryMethods(String accessToken, OAuth_Configuration__mdt config, Map<String, String> resource, List<Object> deliveryMethods, String action) {
        String accountId = resource.get('accountId');
        String formId = resource.get('formId');

        Map<String, Object> operation = new Map<String, Object>{
            'update' => new Map<String, Object>{
                'resourceName' => 'customers/' + accountId + '/assets/' + formId,
                'leadFormAsset' => new Map<String, Object>{ 'deliveryMethods' => deliveryMethods }
            },
            'updateMask' => 'lead_form_asset.delivery_methods'
        };

        HttpResponse response = callGoogleAds(
            'POST', getBaseUrl(config) + '/customers/' + accountId + '/assets:mutate',
            accessToken, resource.get('loginCustomerId'),
            new Map<String, Object>{ 'operations' => new List<Object>{ operation } }
        );

        if (response.getStatusCode() != 200 && response.getStatusCode() != 204) {
            throw auraError('Failed to ' + action + ' Google Ads webhook. Account: ' + accountId + ', Form: ' + formId + ', Status: ' + response.getStatusCode() + ', Response: ' + response.getBody());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getSalesforceLeadFields() {
        List<Map<String, String>> fields = new List<Map<String, String>>();

        for (Schema.SObjectField token : Schema.SObjectType.Contact.fields.getMap().values()) {
            Schema.DescribeFieldResult dfr = token.getDescribe();

            if (SYSTEM_FIELDS.contains(dfr.getName().toLowerCase()) || !dfr.isAccessible() || !dfr.isUpdateable() || dfr.isDeprecatedAndHidden()) {
                continue;
            }

            Boolean isRequired = dfr.isCreateable() && !dfr.isNillable() && dfr.getDefaultValue() == null && !dfr.isDefaultedOnCreate();

            Map<String, String> f = new Map<String, String>{
                'label' => dfr.getLabel() + ' (' + dfr.getName() + ')',
                'value' => dfr.getName(),
                'apiName' => dfr.getName(),
                'type' => String.valueOf(dfr.getType()),
                'required' => String.valueOf(isRequired)
            };

            if (dfr.getType() == Schema.DisplayType.REFERENCE) {
                List<Schema.SObjectType> referenceObjects = dfr.getReferenceTo();
                if (referenceObjects != null && !referenceObjects.isEmpty()) {
                    f.put('referenceTo', referenceObjects[0].getDescribe().getName());
                }
            }
            fields.add(f);
        }
        return fields;
    }

    private static String getWebhookEndpoint() {
        String siteUrl = getGoogleOAuthConfiguration().Webhook_URL__c;
        if (String.isBlank(siteUrl)) {
            throw auraError('Webhook site is not configured. Select an active Force.com site first.');
        }
        return siteUrl.trim().removeEnd('/') + WEBHOOK_PATH;
    }

    private static Boolean hasExistingMappings() {
        return !getMappingData(getMappingSetting()).isEmpty();
    }

    @AuraEnabled(cacheable=false)
    public static String getWebhookUrl() {
        return getGoogleOAuthConfiguration().Webhook_URL__c;
    }

    @AuraEnabled(cacheable=false)
    public static List<SiteOption> getActiveSites() {
        List<SiteOption> options = new List<SiteOption>();
        // Site / SiteDetail are setup objects, so USER_MODE is intentionally not used here.
        for (Site s : [SELECT Id, MasterLabel FROM Site WHERE Status = 'Active' AND SiteType = 'Visualforce' ORDER BY MasterLabel LIMIT 50]) {
            try {
                String siteKey = String.valueOf(s.Id).left(15);
                List<SiteDetail> details = [SELECT SecureUrl FROM SiteDetail WHERE DurableId = :siteKey LIMIT 1];
                if (details.isEmpty() || String.isBlank(details[0].SecureUrl)) {
                    continue;
                }
                String url = details[0].SecureUrl.trim().removeEnd('/');
                SiteOption option = new SiteOption();
                option.value = url;
                option.label = s.MasterLabel + ' (' + url + ')';
                options.add(option);
            } catch (Exception e) {
                // skip sites whose details cannot be read
            }
        }
        return options;
    }

    @AuraEnabled
    public static String saveWebhookUrl(String siteUrl) {
        try {
            if (String.isBlank(siteUrl)) {
                throw auraError('Select a Force.com site.');
            }
            String normalized = siteUrl.trim().removeEnd('/');

            // Only allow URLs that belong to an active site
            Boolean valid = false;
            for (SiteOption option : getActiveSites()) {
                if (option.value == normalized) {
                    valid = true;
                    break;
                }
            }
            if (!valid) {
                throw auraError('The selected site is not an active Force.com site.');
            }

            String current = getGoogleOAuthConfiguration().Webhook_URL__c;
            if (String.isNotBlank(current) && current.trim().removeEnd('/') != normalized && hasExistingMappings()) {
                throw auraError('The webhook site cannot be changed while mappings exist. Delete all mappings first.');
            }

            updateConfigField('Webhook_URL__c', normalized);
            return 'success';
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'GoogleAdsFormMappingController', 'saveWebhookUrl', e.getStackTraceString());
            throw auraError('Failed to save the webhook site.');
        }
    }

    public class GoogleAdsAccount {
        @AuraEnabled public String id;
        @AuraEnabled public String descriptiveName;
        @AuraEnabled public Boolean manager;
        @AuraEnabled public String loginCustomerId;
    }

    public class GoogleLeadForm {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String headline;
        @AuraEnabled public List<String> fields;
        @AuraEnabled public List<String> customQuestions;
    }

    public class FailedLead {
        @AuraEnabled public String id;
        @AuraEnabled public String leadId;
        @AuraEnabled public Datetime receivedOn;
        @AuraEnabled public String reason;
    }

    public class RetryResult {
        @AuraEnabled public String id;
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
    }

    public class SiteOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
    }
}