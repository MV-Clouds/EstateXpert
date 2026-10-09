/**
 * Class Name : GoogleAdsFormMappingControllerTest
 * @description : Tests OAuth, lead form retrieval, mapping save/delete, webhook site handling, failed lead retry/discard and disconnection.
 */
@IsTest
private class GoogleAdsFormMappingControllerTest {

    private static final String ACCOUNT_ID    = '1234';
    private static final String LOGIN_ID      = '999';
    private static final String FORM_ID       = 'F1';
    private static final String OTHER_FORM_ID = 'F2';
    private static final String NEW_FORM_ID   = 'F9';
    private static final String LEAD_NAME     = 'Test Lead';

    private static final String MSG_NOT_CONNECTED    = 'Google Ads is not connected.';
    private static final String MSG_OAUTH_INCOMPLETE = 'Google Ads OAuth configuration is incomplete.';
    private static final String MSG_BASE_URL         = 'Google Ads API base URL or version is not configured.';
    private static final String MSG_WEBHOOK          = 'Webhook site is not configured. Select an active Force.com site first.';

    // Insert the saved mapping in @TestSetup so tests that make callouts do not hit the "uncommitted work pending" governor limit.
    @TestSetup
    static void setup() {
        insert new MVEX__Configuration_Settings__c(
            Name = GoogleLeadsWebhook.GOOGLE_MAPPING_NAME,
            MVEX__Feature_Name__c = GoogleLeadsWebhook.GOOGLE_MAPPING_NAME,
            MVEX__Fields_Data__c = mappingJson(ACCOUNT_ID, FORM_ID, 'FULL_NAME')
        );
    }

    @IsTest
    static void getFailedLeads_blankFormId_throws() {
        try {
            GoogleAdsFormMappingController.getFailedLeads(' ');
            Assert.fail('Expected AuraHandledException');
        } catch (AuraHandledException e) {
            Assert.areEqual('Form Id is required.', e.getMessage());
        }
    }

    @IsTest
    static void getFailedLeads_returnsMatchingRecordsAndSkipsUnparsable() {
        insert new List<MVEX__Error_Handling__c>{
            createError(envelope(FORM_ID,       'L1', 'boom',  leadPayload(FORM_ID,       'L1', true))),
            createError(JSON.serialize(leadPayload(FORM_ID, 'L2', true))),
            createError(envelope(OTHER_FORM_ID, 'L3', 'other', leadPayload(OTHER_FORM_ID, 'L3', true))),
            createError('not json')
        };

        List<GoogleAdsFormMappingController.FailedLead> result = GoogleAdsFormMappingController.getFailedLeads(FORM_ID);

        Map<String, GoogleAdsFormMappingController.FailedLead> byLeadId = new Map<String, GoogleAdsFormMappingController.FailedLead>();
        for (GoogleAdsFormMappingController.FailedLead fl : result) {
            byLeadId.put(fl.leadId, fl);
        }
        Assert.areEqual(2, result.size());
        Assert.areEqual('boom', byLeadId.get('L1').reason);
        Assert.areEqual('Unknown error (older record)', byLeadId.get('L2').reason);
    }

    @IsTest
    static void getFailedLeadCounts_nullInput_returnsEmptyMap() {
        Assert.isTrue(GoogleAdsFormMappingController.getFailedLeadCounts(null).isEmpty());
    }

    @IsTest
    static void getFailedLeadCounts_countsPerRequestedForm() {
        insert new List<MVEX__Error_Handling__c>{
            createError(envelope(FORM_ID,       'L1', 'x', leadPayload(FORM_ID,       'L1', true))),
            createError(JSON.serialize(leadPayload(FORM_ID, 'L2', true))),  // raw format also counted
            createError(envelope(OTHER_FORM_ID, 'L3', 'x', leadPayload(OTHER_FORM_ID, 'L3', true))),
            createError('not json')                                          // ignored
        };

        Map<String, Integer> counts = GoogleAdsFormMappingController.getFailedLeadCounts(new List<String>{ FORM_ID, OTHER_FORM_ID, 'F3', null, '' });

        Assert.areEqual(3, counts.size(), 'Null and blank keys must be excluded');
        Assert.areEqual(2, counts.get(FORM_ID));
        Assert.areEqual(1, counts.get(OTHER_FORM_ID));
        Assert.areEqual(0, counts.get('F3'));
    }

    @IsTest
    static void retryFailedLeads_emptyOrOverLimitList_throws() {
        List<String> tooMany = new List<String>();
        for (Integer i = 0; i < 201; i++) {
            tooMany.add('x' + i);
        }

        try {
            GoogleAdsFormMappingController.retryFailedLeads(new List<String>());
            Assert.fail('Expected AuraHandledException for empty list');
        } catch (AuraHandledException e) {
            Assert.areEqual('Select at least one failed lead to retry.', e.getMessage());
        }

        try {
            GoogleAdsFormMappingController.retryFailedLeads(tooMany);
            Assert.fail('Expected AuraHandledException for oversized list');
        } catch (AuraHandledException e) {
            Assert.areEqual('You can retry up to 200 leads at a time.', e.getMessage());
        }
    }

    @IsTest
    static void retryFailedLeads_processesEachOutcomeCorrectly() {
        List<MVEX__Error_Handling__c> errors = new List<MVEX__Error_Handling__c>{
            // [0] succeeds – mapping exists, LastName populated
            createError(envelope(FORM_ID, 'L1', null, leadPayload(FORM_ID, 'L1', true))),
            // [1] no mapping for this form
            createError(envelope(OTHER_FORM_ID, 'L2', null, leadPayload(OTHER_FORM_ID, 'L2', true))),
            // [2] insert fails – LastName missing
            createError(envelope(FORM_ID, 'L3', null, leadPayload(FORM_ID, 'L3', false))),
            // [3] body cannot be parsed
            createError('not json')
        };
        insert errors;

        List<String> errorIds = new List<String>();
        for (MVEX__Error_Handling__c err : errors) {
            errorIds.add(err.Id);
        }

        List<GoogleAdsFormMappingController.RetryResult> results = GoogleAdsFormMappingController.retryFailedLeads(errorIds);

        Assert.areEqual(4, results.size());

        Map<String, GoogleAdsFormMappingController.RetryResult> byId = new Map<String, GoogleAdsFormMappingController.RetryResult>();
        for (GoogleAdsFormMappingController.RetryResult r : results) {
            byId.put(r.id, r);
        }

        // Success: contact created and error record deleted
        Assert.isTrue(byId.get(errors[0].Id).success);
        Assert.areEqual('Processed', byId.get(errors[0].Id).message);
        Assert.areEqual(1, [SELECT COUNT() FROM Contact]);
        Assert.areEqual(LEAD_NAME, [SELECT LastName FROM Contact LIMIT 1].LastName);

        // Three failures remain; success record was deleted
        Map<Id, MVEX__Error_Handling__c> remaining = new Map<Id, MVEX__Error_Handling__c>(
            [SELECT Id, MVEX__Error_Body__c FROM MVEX__Error_Handling__c WHERE Id IN :errorIds]
        );
        Assert.areEqual(3, remaining.size());
        Assert.isFalse(remaining.containsKey(errors[0].Id));

        // No-mapping: informative message written back into stored body
        GoogleAdsFormMappingController.RetryResult noMapping = byId.get(errors[1].Id);
        Assert.isFalse(noMapping.success);
        Assert.areEqual('No field mapping found for Form Id: ' + OTHER_FORM_ID, noMapping.message);
        Assert.areEqual(noMapping.message, storedReason(remaining.get(errors[1].Id)));

        // Insert failed: non-blank error message written back
        GoogleAdsFormMappingController.RetryResult insertFailed = byId.get(errors[2].Id);
        Assert.isFalse(insertFailed.success);
        Assert.isTrue(String.isNotBlank(insertFailed.message));
        Assert.areEqual(insertFailed.message, storedReason(remaining.get(errors[2].Id)));

        // Unparsable: original body left unchanged
        Assert.isFalse(byId.get(errors[3].Id).success);
        Assert.areEqual('not json', remaining.get(errors[3].Id).MVEX__Error_Body__c);
    }

    @IsTest
    static void discardFailedLeads_nullInput_throws() {
        try {
            GoogleAdsFormMappingController.discardFailedLeads(null);
            Assert.fail('Expected AuraHandledException');
        } catch (AuraHandledException e) {
            Assert.areEqual('Select at least one failed lead.', e.getMessage());
        }
    }

    @IsTest
    static void discardFailedLeads_deletesOnlyGoogleSourceRecords() {
        MVEX__Error_Handling__c nonGoogle = createError(JSON.serialize(leadPayload(FORM_ID, 'L9', true)));
        nonGoogle.MVEX__Source_of_Error__c = otherErrorSource();

        List<MVEX__Error_Handling__c> errors = new List<MVEX__Error_Handling__c>{
            createError(envelope(FORM_ID, 'L1', 'x', leadPayload(FORM_ID, 'L1', true))),
            createError(envelope(FORM_ID, 'L2', 'x', leadPayload(FORM_ID, 'L2', true))),
            createError(envelope(FORM_ID, 'L3', 'x', leadPayload(FORM_ID, 'L3', true))),
            nonGoogle
        };
        insert errors;

        // Target two Google-source records and one non-Google record
        Integer discarded = GoogleAdsFormMappingController.discardFailedLeads(new List<String>{ errors[0].Id, errors[1].Id, nonGoogle.Id });

        Assert.areEqual(2, discarded, 'Only Google-source records should be deleted');
        Assert.areEqual(2, [SELECT COUNT() FROM MVEX__Error_Handling__c WHERE Id IN (:errors[2].Id, :nonGoogle.Id)], 'Untargeted Google record and non-Google record must remain');
    }

    @IsTest
    static void getGoogleAuthUrl_buildsUrlOrThrowsWhenConfigIncomplete() {
        OAuth_Configuration__mdt cfg = config();
        Boolean complete = String.isNotBlank(cfg.Client_Id__c) && String.isNotBlank(cfg.Authorization_Endpoint__c) && String.isNotBlank(cfg.Scope__c) && String.isNotBlank(cfg.Redirect_URI__c);

        try {
            String url = GoogleAdsFormMappingController.getGoogleAuthUrl();
            Assert.isTrue(complete, 'URL should only be built from a complete config');
            Assert.isTrue(url.startsWith(cfg.Authorization_Endpoint__c + '?client_id='));
            Assert.isTrue(url.contains('response_type=code') && url.contains('access_type=offline'));
        } catch (AuraHandledException e) {
            Assert.isFalse(complete, 'Exception expected only when config is incomplete');
            Assert.areEqual(MSG_OAUTH_INCOMPLETE, e.getMessage());
        }
    }

    @IsTest
    static void saveRefreshToken_blankToken_throws() {
        try {
            GoogleAdsFormMappingController.saveRefreshToken('');
            Assert.fail('Expected AuraHandledException');
        } catch (AuraHandledException e) {
            Assert.areEqual('Refresh token cannot be blank.', e.getMessage());
        }
    }

    @IsTest
    static void saveRefreshToken_validToken_returnsSuccess() {
        Assert.areEqual('success', GoogleAdsFormMappingController.saveRefreshToken('refresh-token'));
    }

    @IsTest
    static void getConnection_returnsAccountsOrReportsConfigProblem() {
        Test.setMock(HttpCalloutMock.class, new GoogleApiMock());
        // Not connected → empty list. Connected → needs valid token + base URL against the mock.
        String expectedFailure = isConnected() ? apiFailureMessage() : null;
        List<GoogleAdsFormMappingController.GoogleAdsAccount> accounts;
        String thrown;

        Test.startTest();
        try {
            accounts = GoogleAdsFormMappingController.getConnection();
        } catch (AuraHandledException e) {
            thrown = e.getMessage();
        }
        Test.stopTest();

        Assert.areEqual(expectedFailure, thrown);
        if (expectedFailure != null) {
            return;
        }
        if (!isConnected()) {
            Assert.isTrue(accounts.isEmpty());
            return;
        }
        Assert.areEqual(1, accounts.size());
        Assert.areEqual('222', accounts[0].id);
        Assert.areEqual('Test Account', accounts[0].descriptiveName);
        Assert.areEqual(false, accounts[0].manager);
        Assert.areEqual('111', accounts[0].loginCustomerId);
    }

    @IsTest
    static void getConnectionInfo_returnsProfileOrReportsConfigProblem() {
        Test.setMock(HttpCalloutMock.class, new GoogleApiMock());
        String expectedFailure = isConnected() ? tokenFailureMessage() : null;
        Map<String, Object> info;
        String thrown;

        Test.startTest();
        try {
            info = GoogleAdsFormMappingController.getConnectionInfo();
        } catch (AuraHandledException e) {
            thrown = e.getMessage();
        }
        Test.stopTest();

        Assert.areEqual(expectedFailure, thrown);
        if (expectedFailure != null) {
            return;
        }
        if (!isConnected()) {
            Assert.isTrue(info.isEmpty());
            return;
        }
        Assert.areEqual('Test User', info.get('name'));
        Assert.areEqual('test.user@example.com', info.get('email'));
        Assert.areEqual(config().Connected_At__c, info.get('connectedDate'));
    }

    @IsTest
    static void disconnectGoogleAds_removesOrPreservesMappingBasedOnConfig() {
        Test.setMock(HttpCalloutMock.class, new GoogleApiMock());
        // Not connected: mappings simply deleted. Connected: unsubscribe first (needs token + base URL).
        String expectedFailure = isConnected() ? apiFailureMessage() : null;

        Test.startTest();
        Map<String, Object> result = GoogleAdsFormMappingController.disconnectGoogleAds();
        Test.stopTest();

        Boolean expectedSuccess = expectedFailure == null;
        Assert.areEqual(expectedSuccess, (Boolean)result.get('success'), String.valueOf(result.get('message')));

        if (expectedSuccess) {
            Assert.areEqual('Google Ads disconnected successfully.', result.get('message'));
            Assert.areEqual(0, [SELECT COUNT() FROM MVEX__Configuration_Settings__c WHERE Name = :GoogleLeadsWebhook.GOOGLE_MAPPING_NAME]);
        } else {
            Assert.areEqual(expectedFailure, result.get('message'));
            Assert.areEqual(1, [SELECT COUNT() FROM MVEX__Configuration_Settings__c WHERE Name = :GoogleLeadsWebhook.GOOGLE_MAPPING_NAME], 'Mapping must be preserved when disconnect fails');
        }
    }

    @IsTest
    static void getFormsForAccount_invalidInputs_throw() {
        Map<String, String> expectedMessages = new Map<String, String>{
            '' => 'Google Ads account is required.',
            'not json' => 'Invalid Google Ads account data.',
            '{"id":"222"}' => 'Google Ads account information is incomplete.'
        };

        for (String input : expectedMessages.keySet()) {
            try {
                GoogleAdsFormMappingController.getFormsForAccount(input);
                Assert.fail('Expected AuraHandledException for: ' + input);
            } catch (AuraHandledException e) {
                Assert.areEqual(expectedMessages.get(input), e.getMessage());
            }
        }
    }

    @IsTest
    static void getFormsForAccount_validAccount_returnsFormsOrReportsConfigProblem() {
        Test.setMock(HttpCalloutMock.class, new GoogleApiMock());
        String accountJson = JSON.serialize(new Map<String, Object>{ 'id' => '222', 'loginCustomerId' => '111' });
        String expectedFailure = apiFailureMessage();
        List<GoogleAdsFormMappingController.GoogleLeadForm> forms;
        String thrown;

        Test.startTest();
        try {
            forms = GoogleAdsFormMappingController.getFormsForAccount(accountJson);
        } catch (AuraHandledException e) {
            thrown = e.getMessage();
        }
        Test.stopTest();

        Assert.areEqual(expectedFailure, thrown);
        if (expectedFailure != null) {
            return;
        }
        Assert.areEqual(2, forms.size());
        Assert.areEqual('555', forms[0].id);
        Assert.areEqual('Form A', forms[0].name);
        Assert.areEqual('Headline', forms[0].headline);
        Assert.areEqual(new List<String>{ 'FULL_NAME' }, forms[0].fields);
        Assert.areEqual(new List<String>{ 'Budget?' }, forms[0].customQuestions);
        Assert.areEqual('customers/222/assets/556', forms[1].name); // falls back to the resource name
    }

    @IsTest
    static void getExistingMappings_returnsSavedJsonOrNull() {
        Assert.isTrue(GoogleAdsFormMappingController.getExistingMappings().contains(FORM_ID));
        delete [SELECT Id FROM MVEX__Configuration_Settings__c WHERE Name = :GoogleLeadsWebhook.GOOGLE_MAPPING_NAME];
        Assert.isNull(GoogleAdsFormMappingController.getExistingMappings());
    }

    @IsTest
    static void saveMapping_invalidInputs_returnFailureResponse() {
        Map<String, String> expectedMessages = new Map<String, String>{
            '' => 'Mapping data cannot be empty.',
            'not json' => 'Invalid mapping data.',
            '{}' => 'No mapping data was provided.',
            '{"1234":{"forms":{}}}' => 'Login customer ID is required for account 1234.',
            '{"1234":{"loginCustomerId":"999"}}' => 'Forms are required for account 1234.',
            '{"1234":{"loginCustomerId":"999","forms":{"F1":{}}}}' => 'Mappings are required for form F1.'
        };

        for (String input : expectedMessages.keySet()) {
            Map<String, Object> result = GoogleAdsFormMappingController.saveMapping(input);
            Assert.isFalse((Boolean)result.get('success'), 'Should fail for: ' + input);
            Assert.areEqual(expectedMessages.get(input), result.get('message'));
        }
    }

    @IsTest
    static void saveMapping_existingForm_updatesWithoutCallout() {
        String updatedJson = mappingJson(ACCOUNT_ID, FORM_ID, 'EMAIL');

        Map<String, Object> result = GoogleAdsFormMappingController.saveMapping(updatedJson);

        Assert.isTrue((Boolean)result.get('success'), String.valueOf(result.get('message')));
        Assert.areEqual('Google Ads mapping saved successfully.', result.get('message'));
        Assert.isTrue(savedMappingData().contains('EMAIL'));
    }

    @IsTest
    static void saveMapping_newForm_subscribesWebhookOrReportsConfigProblem() {
        Test.setMock(HttpCalloutMock.class, new GoogleApiMock());
        String expectedFailure = subscribeFailureMessage();

        Test.startTest();
        Map<String, Object> result =
            GoogleAdsFormMappingController.saveMapping(mappingJson(ACCOUNT_ID, NEW_FORM_ID, 'FULL_NAME'));
        Test.stopTest();

        Boolean expectedSuccess = expectedFailure == null;
        Assert.areEqual(expectedSuccess, (Boolean)result.get('success'), String.valueOf(result.get('message')));
        String saved = savedMappingData();

        if (expectedSuccess) {
            Assert.areEqual('Google Ads mapping saved successfully.', result.get('message'));
            Assert.isTrue(saved.contains(NEW_FORM_ID));
        } else {
            Assert.areEqual(expectedFailure, result.get('message'));
            Assert.isTrue(saved.contains('"' + FORM_ID + '"'), 'The existing mapping must be kept.');
            Assert.isFalse(saved.contains('"' + NEW_FORM_ID + '"'), 'The new form must not be saved.');
        }
    }

    @IsTest
    static void deleteMapping_missingArguments_returnsFailure() {
        Map<String, Object> result = GoogleAdsFormMappingController.deleteMapping(ACCOUNT_ID, '', FORM_ID);

        Assert.isFalse((Boolean)result.get('success'));
        Assert.areEqual('Account ID, Login Customer ID and Form ID are required.', result.get('message'));
    }

    @IsTest
    static void deleteMapping_whenNothingToDelete_returnsSuccessWithMessage() {
        // Unknown account
        Map<String, Object> result = GoogleAdsFormMappingController.deleteMapping('unknown', LOGIN_ID, FORM_ID);
        Assert.isTrue((Boolean)result.get('success'));
        Assert.areEqual('Account mapping does not exist.', result.get('message'));

        // Known account, unknown form
        result = GoogleAdsFormMappingController.deleteMapping(ACCOUNT_ID, LOGIN_ID, 'unknown');
        Assert.isTrue((Boolean)result.get('success'));
        Assert.areEqual('Form mapping does not exist.', result.get('message'));

        // Setting exists but Fields_Data__c is blank
        MVEX__Configuration_Settings__c setting = [SELECT Id FROM MVEX__Configuration_Settings__c WHERE Name = :GoogleLeadsWebhook.GOOGLE_MAPPING_NAME];
        setting.MVEX__Fields_Data__c = null;
        update setting;
        result = GoogleAdsFormMappingController.deleteMapping(ACCOUNT_ID, LOGIN_ID, FORM_ID);
        Assert.isTrue((Boolean)result.get('success'));
        Assert.areEqual('Mapping does not exist.', result.get('message'));

        // No setting record at all
        delete setting;
        result = GoogleAdsFormMappingController.deleteMapping(ACCOUNT_ID, LOGIN_ID, FORM_ID);
        Assert.isTrue((Boolean)result.get('success'));
        Assert.areEqual('Mapping configuration does not exist.', result.get('message'));
    }

    @IsTest
    static void deleteMapping_existingForm_unsubscribesOrReportsConfigProblem() {
        Test.setMock(HttpCalloutMock.class, new GoogleApiMock());
        String expectedFailure = apiFailureMessage();

        Test.startTest();
        Map<String, Object> result =
            GoogleAdsFormMappingController.deleteMapping(ACCOUNT_ID, LOGIN_ID, FORM_ID);
        Test.stopTest();

        Boolean expectedSuccess = expectedFailure == null;
        Assert.areEqual(expectedSuccess, (Boolean)result.get('success'), String.valueOf(result.get('message')));

        if (expectedSuccess) {
            Assert.areEqual('Mapping deleted successfully.', result.get('message'));
            Assert.isNull(savedMappingData(), 'Setting must be cleared when the last form is removed');
        } else {
            Assert.areEqual(expectedFailure, result.get('message'));
            Assert.isTrue(savedMappingData().contains(FORM_ID), 'Mapping must stay when unsubscribing fails.');
        }
    }

    @IsTest
    static void getWebhookUrl_returnsConfiguredUrl() {
        Assert.areEqual(config().Webhook_URL__c, GoogleAdsFormMappingController.getWebhookUrl());
    }

    @IsTest
    static void getActiveSites_returnsWellFormedOptions() {
        List<GoogleAdsFormMappingController.SiteOption> options = GoogleAdsFormMappingController.getActiveSites();

        Assert.isNotNull(options);
        for (GoogleAdsFormMappingController.SiteOption option : options) {
            Assert.isTrue(String.isNotBlank(option.value));
            Assert.isTrue(option.label.contains(option.value));
        }
    }

    @IsTest
    static void saveWebhookUrl_invalidInputs_throw() {
        Map<String, String> expectedMessages = new Map<String, String>{
            '' => 'Select a Force.com site.',
            'https://not-an-active-site.example.com' => 'The selected site is not an active Force.com site.'
        };

        for (String siteUrl : expectedMessages.keySet()) {
            try {
                GoogleAdsFormMappingController.saveWebhookUrl(siteUrl);
                Assert.fail('Expected AuraHandledException for: ' + siteUrl);
            } catch (AuraHandledException e) {
                Assert.areEqual(expectedMessages.get(siteUrl), e.getMessage());
            }
        }
    }

    @IsTest
    static void saveWebhookUrl_activeSite_savedWhenNoMappingsExist() {
        List<GoogleAdsFormMappingController.SiteOption> sites = GoogleAdsFormMappingController.getActiveSites();
        if (sites.isEmpty()) {
            return; // org has no active Force.com site – skip
        }
        delete [SELECT Id FROM MVEX__Configuration_Settings__c WHERE Name = :GoogleLeadsWebhook.GOOGLE_MAPPING_NAME];

        // Trailing slash should be accepted and normalised
        Assert.areEqual('success', GoogleAdsFormMappingController.saveWebhookUrl(sites[0].value + '/'));
    }

    @IsTest
    static void saveWebhookUrl_differentSiteBlockedWhileMappingsExist() {
        String current = config().Webhook_URL__c;
        String differentSite;
        for (GoogleAdsFormMappingController.SiteOption option : GoogleAdsFormMappingController.getActiveSites()) {
            if (String.isNotBlank(current) && option.value != current.trim().removeEnd('/')) {
                differentSite = option.value;
                break;
            }
        }
        if (differentSite == null) {
            return; // needs an existing webhook URL plus a second active site – skip
        }

        try {
            GoogleAdsFormMappingController.saveWebhookUrl(differentSite);
            Assert.fail('Expected AuraHandledException');
        } catch (AuraHandledException e) {
            Assert.areEqual('The webhook site cannot be changed while mappings exist. Delete all mappings first.', e.getMessage());
        }
    }

    @IsTest
    static void getSalesforceLeadFields_returnsMappableContactFields() {
        Map<String, Map<String, String>> byApiName = new Map<String, Map<String, String>>();
        for (Map<String, String> field : GoogleAdsFormMappingController.getSalesforceLeadFields()) {
            byApiName.put(field.get('apiName').toLowerCase(), field);
        }

        Assert.isTrue(byApiName.containsKey('lastname'));
        Assert.areEqual('true', byApiName.get('lastname').get('required'));
        Assert.isTrue(byApiName.get('lastname').get('label').contains('(LastName)'));

        Assert.isTrue(byApiName.containsKey('accountid'));
        Assert.areEqual('Account', byApiName.get('accountid').get('referenceTo'));

        Assert.isFalse(byApiName.containsKey('ownerid'), 'System fields must be excluded.');
    }

    private static OAuth_Configuration__mdt config() {
        return OAuth_Configuration__mdt.getInstance('Google_Ads_Config');
    }

    private static Boolean isConnected() {
        return String.isNotBlank(config().Refresh_Token__c);
    }

    private static String tokenFailureMessage() {
        OAuth_Configuration__mdt c = config();
        if (String.isBlank(c.Refresh_Token__c)) {
            return MSG_NOT_CONNECTED;
        }
        if (String.isBlank(c.Client_Id__c) || String.isBlank(c.Client_Secret__c) || String.isBlank(c.Token_Endpoint__c)) {
            return MSG_OAUTH_INCOMPLETE;
        }
        return null;
    }

    private static String apiFailureMessage() {
        String tokenFailure = tokenFailureMessage();
        if (tokenFailure != null) {
            return tokenFailure;
        }
        OAuth_Configuration__mdt c = config();
        return (String.isBlank(c.Base_URL__c) || String.isBlank(c.API_Version__c)) ? MSG_BASE_URL : null;
    }

    private static String subscribeFailureMessage() {
        String tokenFailure = tokenFailureMessage();
        if (tokenFailure != null) {
            return tokenFailure;
        }
        if (String.isBlank(config().Webhook_URL__c)) {
            return MSG_WEBHOOK;
        }
        return apiFailureMessage();
    }

    private static String mappingJson(String accountId, String formId, String googleField) {
        return JSON.serialize(new Map<String, Object>{
            accountId => new Map<String, Object>{
                'accountName' => 'Test Account',
                'loginCustomerId' => LOGIN_ID,
                'forms' => new Map<String, Object>{
                    formId => new Map<String, Object>{
                        'formName' => 'Test Form',
                        'mappings' => new Map<String, Object>{
                            'LastName' => new Map<String, Object>{
                                'sourceType' => 'google',
                                'googleField' => googleField
                            }
                        }
                    }
                }
            }
        });
    }

    private static Map<String, Object> leadPayload(String formId, String leadId, Boolean includeName) {
        List<Object> columns = new List<Object>{ new Map<String, Object>{ 'column_id' => 'EMAIL', 'string_value' => 'test@example.com' } };
        if (includeName) {
            columns.add(new Map<String, Object>{ 'column_id' => 'FULL_NAME', 'string_value' => LEAD_NAME });
        }
        return new Map<String, Object>{
            'google_key' => GoogleLeadsWebhook.GOOGLE_SECRET,
            'form_id' => formId,
            'lead_id' => leadId,
            'user_column_data' => columns
        };
    }

    private static String envelope(String formId, String leadId, String reason, Map<String, Object> payload) {
        return JSON.serialize(new Map<String, Object>{
            'formId' => formId,
            'leadId' => leadId,
            'reason' => reason,
            'payload' => payload
        });
    }

    private static MVEX__Error_Handling__c createError(String body) {
        return new MVEX__Error_Handling__c(
            MVEX__Class_Name__c = 'GoogleLeadsWebhook',
            MVEX__Method_Name__c = 'handleNotification',
            MVEX__Source_of_Error__c = GoogleLeadsWebhook.FAILED_SOURCE,
            MVEX__Error_Body__c = body
        );
    }

    private static String storedReason(MVEX__Error_Handling__c error) {
        return String.valueOf(((Map<String, Object>)JSON.deserializeUntyped(error.MVEX__Error_Body__c)).get('reason'));
    }

    private static String otherErrorSource() {
        for (Schema.PicklistEntry entry : MVEX__Error_Handling__c.MVEX__Source_of_Error__c.getDescribe().getPicklistValues()) {
            if (entry.isActive() && entry.getValue() != GoogleLeadsWebhook.FAILED_SOURCE) {
                return entry.getValue();
            }
        }
        return 'SomethingElse'; // text field: any non-Google value works
    }

    private static String savedMappingData() {
        List<MVEX__Configuration_Settings__c> settings = [SELECT MVEX__Fields_Data__c FROM   MVEX__Configuration_Settings__c WHERE  Name = :GoogleLeadsWebhook.GOOGLE_MAPPING_NAME];
        return settings.isEmpty() ? null : settings[0].MVEX__Fields_Data__c;
    }

    private class GoogleApiMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            String endpoint = request.getEndpoint();
            String body;

            if (endpoint.contains('listAccessibleCustomers')) {
                body = '{"resourceNames":["customers/111"]}';
            } else if (endpoint.contains('googleAds:search') && request.getBody().contains('customer_client')) {
                body = '{"results":[{"customerClient":{"id":"222","descriptiveName":"Test Account","manager":false}}]}';
            } else if (endpoint.contains('googleAds:search')) {
                body = '{"results":['
                    + '{"asset":{"id":"555","name":"Form A","leadFormAsset":{"headline":"Headline",'
                    +   '"fields":[{"inputType":"FULL_NAME"}],"customQuestionFields":[{"customQuestionText":"Budget?"}]}}},'
                    + '{"asset":{"id":"556","resourceName":"customers/222/assets/556"}},'
                    + '{}]}';
            } else if (endpoint.contains('userinfo')) {
                body = '{"name":"Test User","email":"test.user@example.com"}';
            } else if (endpoint.contains('assets:mutate') || endpoint.contains('revoke')) {
                body = '{}';
            } else {
                body = '{"access_token":"test-access-token"}'; // token endpoint
            }

            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setHeader('Content-Type', 'application/json');
            response.setBody(body);
            return response;
        }
    }

    private class FailingApiMock implements HttpCalloutMock {
        private final Map<String, Integer> statusByEndpoint;
        private final Map<String, String>  bodyByEndpoint;

        /** @param overrides keys are URL substrings; values are '<statusCode>|<responseBody>' */
        FailingApiMock(Map<String, String> overrides) {
            statusByEndpoint = new Map<String, Integer>();
            bodyByEndpoint   = new Map<String, String>();
            for (String key : overrides.keySet()) {
                List<String> parts = overrides.get(key).split('\\|', 2);
                statusByEndpoint.put(key, Integer.valueOf(parts[0]));
                bodyByEndpoint.put(key,   parts.size() > 1 ? parts[1] : '{}');
            }
        }

        public HttpResponse respond(HttpRequest request) {
            String endpoint = request.getEndpoint();
            for (String key : statusByEndpoint.keySet()) {
                if (endpoint.contains(key)) {
                    HttpResponse resp = new HttpResponse();
                    resp.setStatusCode(statusByEndpoint.get(key));
                    resp.setHeader('Content-Type', 'application/json');
                    resp.setBody(bodyByEndpoint.get(key));
                    return resp;
                }
            }
            return new GoogleApiMock().respond(request);
        }
    }

    @IsTest
    static void deleteMapping_corruptStoredJson_returnsFailure() {
        MVEX__Configuration_Settings__c setting = [SELECT Id FROM MVEX__Configuration_Settings__c WHERE Name = :GoogleLeadsWebhook.GOOGLE_MAPPING_NAME];
        setting.MVEX__Fields_Data__c = '[1,2,3]';
        update setting;

        Map<String, Object> result = GoogleAdsFormMappingController.deleteMapping(ACCOUNT_ID, LOGIN_ID, FORM_ID);

        Assert.isFalse((Boolean)result.get('success'));
        Assert.isTrue(String.valueOf(result.get('message')).contains('invalid'), 'Message should describe the invalid mapping');
    }

    @IsTest
    static void saveMapping_nullAccountEntry_returnsFailure() {
        Map<String, Object> data = new Map<String, Object>{ ACCOUNT_ID => null };
        Map<String, Object> result = GoogleAdsFormMappingController.saveMapping(JSON.serialize(data));

        Assert.isFalse((Boolean)result.get('success'));
        Assert.areEqual('Invalid Google Ads account mapping.', result.get('message'));
    }

    @IsTest
    static void saveMapping_nullFormsValue_returnsFailure() {
        Map<String, Object> data = new Map<String, Object>{
            ACCOUNT_ID => new Map<String, Object>{
                'loginCustomerId' => LOGIN_ID,
                'forms' => null
            }
        };
        Map<String, Object> result = GoogleAdsFormMappingController.saveMapping(JSON.serialize(data));

        Assert.isFalse((Boolean)result.get('success'));
        Assert.areEqual('Invalid forms data for account ' + ACCOUNT_ID + '.', result.get('message'));
    }

    @IsTest
    static void saveMapping_nullFormEntry_returnsFailure() {
        Map<String, Object> data = new Map<String, Object>{
            ACCOUNT_ID => new Map<String, Object>{
                'loginCustomerId' => LOGIN_ID,
                'forms' => new Map<String, Object>{ FORM_ID => null }
            }
        };
        Map<String, Object> result = GoogleAdsFormMappingController.saveMapping(JSON.serialize(data));

        Assert.isFalse((Boolean)result.get('success'));
        Assert.areEqual('Invalid form mapping for form ' + FORM_ID + '.', result.get('message'));
    }

    @IsTest
    static void discardFailedLeads_emptyList_throws() {
        try {
            GoogleAdsFormMappingController.discardFailedLeads(new List<String>());
            Assert.fail('Expected AuraHandledException');
        } catch (AuraHandledException e) {
            Assert.areEqual('Select at least one failed lead.', e.getMessage());
        }
    }

    @IsTest
    static void retryFailedLeads_nullList_throws() {
        try {
            GoogleAdsFormMappingController.retryFailedLeads(null);
            Assert.fail('Expected AuraHandledException');
        } catch (AuraHandledException e) {
            Assert.areEqual('Select at least one failed lead to retry.', e.getMessage());
        }
    }

    @IsTest
    static void getConnection_tokenEndpointNon200_throwsAccessTokenError() {
        if (!isConnected() || apiFailureMessage() != null) {
            return;
        }
        Test.setMock(HttpCalloutMock.class,
            new FailingApiMock(new Map<String, String>{ 'token' => '401|{"error":"invalid_grant"}' })
        );
        try {
            Test.startTest();
            GoogleAdsFormMappingController.getConnection();
            Test.stopTest();
            Assert.fail('Expected AuraHandledException');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('Failed to obtain Google Ads access token'), 'Unexpected message: ' + e.getMessage());
        }
    }

    @IsTest
    static void getConnection_tokenEndpointMissingToken_throwsBlankTokenError() {
        if (!isConnected() || apiFailureMessage() != null) {
            return;
        }
        Test.setMock(HttpCalloutMock.class, new FailingApiMock(new Map<String, String>{ 'token' => '200|{}' }));
        try {
            Test.startTest();
            GoogleAdsFormMappingController.getConnection();
            Test.stopTest();
            Assert.fail('Expected AuraHandledException');
        } catch (AuraHandledException e) {
            Assert.areEqual('Google did not return an access token.', e.getMessage());
        }
    }

    @IsTest
    static void getConnectionInfo_userinfoNon200_throwsAccountDetailsError() {
        if (!isConnected() || tokenFailureMessage() != null) {
            return;
        }
        Test.setMock(HttpCalloutMock.class, new FailingApiMock(new Map<String, String>{ 'userinfo' => '403|{"error":"access_denied"}' }));
        try {
            Test.startTest();
            GoogleAdsFormMappingController.getConnectionInfo();
            Test.stopTest();
            Assert.fail('Expected AuraHandledException');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('Failed to retrieve Google account details'), 'Unexpected message: ' + e.getMessage());
        }
    }

    @IsTest
    static void getConnection_listCustomersNon200_throwsAccountsError() {
        if (!isConnected() || apiFailureMessage() != null) {
            return;
        }
        Test.setMock(HttpCalloutMock.class, new FailingApiMock(new Map<String, String>{ 'listAccessibleCustomers' => '500|{"error":"internal"}' }));
        try {
            Test.startTest();
            GoogleAdsFormMappingController.getConnection();
            Test.stopTest();
            Assert.fail('Expected AuraHandledException');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('Failed to retrieve Google Ads accounts'), 'Unexpected message: ' + e.getMessage());
        }
    }

    @IsTest
    static void getFormsForAccount_searchNon200_throwsFormsError() {
        if (!isConnected() || apiFailureMessage() != null) {
            return;
        }
        String accountJson = JSON.serialize(new Map<String, Object>{ 'id' => '222', 'loginCustomerId' => '111' });
        Test.setMock(HttpCalloutMock.class, new FailingApiMock(new Map<String, String>{ 'googleAds:search' => '500|{"error":"internal"}' }));
        try {
            Test.startTest();
            GoogleAdsFormMappingController.getFormsForAccount(accountJson);
            Test.stopTest();
            Assert.fail('Expected AuraHandledException');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('Failed to retrieve Google Lead Forms'), 'Unexpected message: ' + e.getMessage());
        }
    }

    @IsTest
    static void saveMapping_mutateFails_returnsFailureResponse() {
        if (subscribeFailureMessage() != null) {
            return;
        }
        Test.setMock(HttpCalloutMock.class, new FailingApiMock(new Map<String, String>{ 'assets:mutate' => '500|{"error":"internal"}' }));
        Test.startTest();
        Map<String, Object> result = GoogleAdsFormMappingController.saveMapping(mappingJson(ACCOUNT_ID, NEW_FORM_ID, 'FULL_NAME'));
        Test.stopTest();

        Assert.isFalse((Boolean)result.get('success'));
        Assert.isTrue(String.valueOf(result.get('message')).contains('Failed to subscribe Google Ads webhook') || String.valueOf(result.get('message')).contains('Failed to'), 'Unexpected message: ' + result.get('message'));
        Assert.isFalse(savedMappingData().contains('"' + NEW_FORM_ID + '"'), 'New form must not be saved when subscription fails');
    }

    @IsTest
    static void deleteMapping_mutateFails_returnsFailureAndPreservesMapping() {
        if (apiFailureMessage() != null) {
            return; // token or base URL not configured – skip
        }
        Test.setMock(HttpCalloutMock.class,
            new FailingApiMock(new Map<String, String>{ 'assets:mutate' => '500|{"error":"internal"}' })
        );
        Test.startTest();
        Map<String, Object> result = GoogleAdsFormMappingController.deleteMapping(ACCOUNT_ID, LOGIN_ID, FORM_ID);
        Test.stopTest();

        Assert.isFalse((Boolean)result.get('success'));
        Assert.isTrue(savedMappingData().contains('"' + FORM_ID + '"'), 'Mapping must be preserved when unsubscribe fails');
    }
}