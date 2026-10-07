/**
* Class Name : GoogleAdsFormMappingController
* Test Class : GoogleAdsFormMappingControllerTest
* Created By : Salmanhaider Aghariya
* Last Modified Date : 05/10/2026
* Last Modified By : Salmanhaider Aghariya
* @description : Used to manage Google Ads integration, OAuth authentication,
* Google Lead Forms, field mappings, webhook subscriptions, failed lead
* processing, Salesforce field mappings and Google Ads disconnection.
*/
public with sharing class GoogleAdsFormMappingController {

    private static final String CLASS_NAME = 'GoogleAdsFormMappingController';
    private static final String GOOGLE_CONFIG_DEV_NAME = 'Google_Ads_Config';
    private static final String GOOGLE_MAPPING_NAME = GoogleLeadsWebhook.GOOGLE_MAPPING_NAME;
    private static final String GOOGLE_FAILED_SOURCE = GoogleLeadsWebhook.FAILED_SOURCE;
    private static final String WEBHOOK_PATH = '/services/apexrest/Lead';
    private static final Integer MAX_RETRY_BATCH = 200;
    private static final Set<String> SYSTEM_FIELDS = new Set<String>{
        'ownerid', 'recordtypeid', 'currencyisocode', 'createdbyid', 'lastmodifiedbyid', 'masterrecordid'
    };

    /**
    * Method Name : auraError
    * Created By : Salmanhaider Aghariya
    * Last Modified Date : 05/10/2026
    * Last Modified By : Salmanhaider Aghariya
    * @param message to store the error message
    * @return AuraHandledException
    * @description : Used to create an AuraHandledException with a custom error message.
    */
    private static AuraHandledException auraError(String message) {
        AuraHandledException e = new AuraHandledException(message);
        e.setMessage(message);
        return e;
    }

    /**
    * Method Name : response
    * Created By : Salmanhaider Aghariya
    * Last Modified Date : 05/10/2026
    * Last Modified By : Salmanhaider Aghariya
    * @param success to store the operation status
    * @param message to store the response message
    * @return Map containing success status and message
    * @description : Used to create a standard response for Aura-enabled methods.
    */
    private static Map<String, Object> response(Boolean success, String message) {
        return new Map<String, Object>{ 'success' => success, 'message' => message };
    }

    /**
    * Method Name : logError
    * Created By : Salmanhaider Aghariya
    * Last Modified Date : 05/10/2026
    * Last Modified By : Salmanhaider Aghariya
    * @param e to store the exception
    * @param methodName to store the name of the failing method
    * @description : Used to log an exception without letting a logging failure hide the original error.
    */
    private static void logError(Exception e, String methodName) {
        try {
            ErrorHandler.insertErrorData(e, CLASS_NAME, methodName, e.getStackTraceString());
        } catch (Exception logException) {
            System.debug(LoggingLevel.ERROR, 'Error logging failed in ' + methodName + ': ' + logException.getMessage());
        }
    }

    /**
    * Method Name : encode
    * Created By : Salmanhaider Aghariya
    * Last Modified Date : 05/10/2026
    * Last Modified By : Salmanhaider Aghariya
    * @param value to store the value that needs to be encoded
    * @return URL encoded String
    * @description : Used to URL encode the supplied value.
    */
    private static String encode(String value) {
        try {
            return value == null ? '' : EncodingUtil.urlEncode(value, 'UTF-8');
        } catch (Exception e) {
            throw auraError('Failed to encode value. ' + e.getMessage());
        }
    }

    /**
    * Method Name : str
    * Created By : Salmanhaider Aghariya
    * Last Modified Date : 05/10/2026
    * Last Modified By : Salmanhaider Aghariya
    * @param value to store the value that needs to be converted to String
    * @return String value
    * @description : Used to safely convert an Object value to String.
    */
    private static String str(Object value) {
        return value == null ? null : String.valueOf(value);
    }

    /**
    * Method Name : getGoogleOAuthConfiguration
    * Created By : Salmanhaider Aghariya
    * Last Modified Date : 05/10/2026
    * Last Modified By : Salmanhaider Aghariya
    * @return OAuth_Configuration__mdt configuration record
    * @description : Used to retrieve the Google Ads OAuth configuration.
    */
    private static OAuth_Configuration__mdt getGoogleOAuthConfiguration() {
        try {
            OAuth_Configuration__mdt config = OAuth_Configuration__mdt.getInstance(GOOGLE_CONFIG_DEV_NAME);
            if (config == null) {
                throw auraError('Google Ads OAuth configuration was not found.');
            }
            return config;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw auraError('Failed to read Google Ads OAuth configuration. ' + e.getMessage());
        }
    }

    /**
    * Method Name : getBaseUrl
    * Created By : Salmanhaider Aghariya
    * Last Modified Date : 05/10/2026
    * Last Modified By : Salmanhaider Aghariya
    * @param config to store the Google OAuth configuration
    * @return Google Ads API base URL
    * @description : Used to generate the Google Ads API base URL.
    */
    private static String getBaseUrl(OAuth_Configuration__mdt config) {
        if (config == null || String.isBlank(config.Base_URL__c) || String.isBlank(config.API_Version__c)) {
            throw auraError('Google Ads API base URL or version is not configured.');
        }
        return config.Base_URL__c + config.API_Version__c;
    }

    /**
    * Method Name : getMappingSetting
    * Created By : Salmanhaider Aghariya
    * Last Modified Date : 05/10/2026
    * Last Modified By : Salmanhaider Aghariya
    * @return MVEX__Configuration_Settings__c mapping record
    * @description : Used to retrieve the Google Ads mapping configuration.
    */
    private static MVEX__Configuration_Settings__c getMappingSetting() {
        try {
            List<MVEX__Configuration_Settings__c> settings = [SELECT Id, MVEX__Fields_Data__c FROM MVEX__Configuration_Settings__c WHERE Name = :GOOGLE_MAPPING_NAME WITH USER_MODE LIMIT 1];
            return settings.isEmpty() ? null : settings[0];
        } catch (Exception e) {
            throw auraError('Failed to read the Google Ads mapping configuration. ' + e.getMessage());
        }
    }

    /**
    * Method Name : getMappingData
    * Created By : Salmanhaider Aghariya
    * Last Modified Date : 05/10/2026
    * Last Modified By : Salmanhaider Aghariya
    * @param setting to store the mapping configuration record
    * @return Mapping data
    * @description : Used to deserialize the saved Google Ads mapping configuration.
    */
    private static Map<String, Object> getMappingData(MVEX__Configuration_Settings__c setting) {
        if (setting == null || String.isBlank(setting.MVEX__Fields_Data__c)) {
            return new Map<String, Object>();
        }
        try {
            return (Map<String, Object>)JSON.deserializeUntyped(setting.MVEX__Fields_Data__c);
        } catch (Exception e) {
            throw auraError('The saved Google Ads mapping is invalid. ' + e.getMessage());
        }
    }

    /**
    * Method Name : updateConfigField
    * Created By : Salmanhaider Aghariya
    * Last Modified Date : 05/10/2026
    * Last Modified By : Salmanhaider Aghariya
    * @param fieldValues to store the custom metadata field names and values
    * @description : Used to update Google OAuth custom metadata fields asynchronously.
    */
    private static void updateConfigField(Map<String, String> fieldValues) {
        try {
            if (fieldValues == null || fieldValues.isEmpty()) {
                throw auraError('At least one Google OAuth configuration field is required.');
            }
            OAuth_Configuration__mdt config = getGoogleOAuthConfiguration();

            Metadata.CustomMetadata record = new Metadata.CustomMetadata();
            record.fullName = 'OAuth_Configuration__mdt.' + config.DeveloperName;
            record.label = config.MasterLabel;

            for (String fieldName : fieldValues.keySet()) {
                Metadata.CustomMetadataValue fieldValue = new Metadata.CustomMetadataValue();
                fieldValue.field = fieldName;
                fieldValue.value = fieldValues.get(fieldName);
                record.values.add(fieldValue);
            }

            Metadata.DeployContainer container = new Metadata.DeployContainer();
            container.addMetadata(record);
            Metadata.Operations.enqueueDeployment(container, null);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw auraError('Failed to update Google OAuth configuration. ' + e.getMessage());
        }
    }

    /**
    * Method Name : getFailedLeads
    * Created By : Salmanhaider Aghariya
    * Last Modified Date : 05/10/2026
    * Last Modified By : Salmanhaider Aghariya
    * @param formId to store the Google Lead Form Id
    * @return List of FailedLead records for the form
    * @description : Used to retrieve failed leads logged for the given form.
    */
    @AuraEnabled
    public static List<FailedLead> getFailedLeads(String formId) {
        try {
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
                    System.debug(LoggingLevel.WARN, 'Skipped unparsable failed lead ' + err.Id + ': ' + e.getMessage());
                }
            }
            return result;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            logError(e, 'getFailedLeads');
            throw auraError('Failed to retrieve failed leads.');
        }
    }

    /**
    * Method Name : getFailedLeadCounts
    * @param formIds Google Lead Form Ids to count failed leads for
    * @return Map from form Id to its failed lead count
    * @description : Counts recent failed leads for the supplied forms.
    */
    @AuraEnabled
    public static Map<String, Integer> getFailedLeadCounts(List<String> formIds) {
        try {
            Set<String> requestedFormIds = new Set<String>();
            if (formIds != null) {
                requestedFormIds.addAll(formIds);
            }
            requestedFormIds.remove(null);
            requestedFormIds.remove('');

            Map<String, Integer> countsByFormId = new Map<String, Integer>();
            for (String formId : requestedFormIds) {
                countsByFormId.put(formId, 0);
            }
            if (requestedFormIds.isEmpty()) {
                return countsByFormId;
            }

            for (MVEX__Error_Handling__c err : [
                SELECT Id, MVEX__Error_Body__c
                FROM MVEX__Error_Handling__c
                WHERE MVEX__Source_of_Error__c = :GOOGLE_FAILED_SOURCE
                WITH USER_MODE
                ORDER BY CreatedDate DESC
                LIMIT 2000
            ]) {
                if (String.isBlank(err.MVEX__Error_Body__c)) {
                    continue;
                }
                try {
                    Map<String, Object> parsed = (Map<String, Object>)JSON.deserializeUntyped(err.MVEX__Error_Body__c);
                    String formId = getFormIdFromBody(parsed);
                    if (requestedFormIds.contains(formId)) {
                        countsByFormId.put(formId, countsByFormId.get(formId) + 1);
                    }
                } catch (Exception e) {
                    System.debug(LoggingLevel.WARN, 'Skipped unparsable failed lead ' + err.Id + ': ' + e.getMessage());
                }
            }
            return countsByFormId;
        } catch (Exception e) {
            logError(e, 'getFailedLeadCounts');
            throw auraError('Failed to retrieve failed lead counts.');
        }
    }

    /**
    * Method Name : retryFailedLeads
    * Created By : Salmanhaider Aghariya
    * Last Modified Date : 05/10/2026
    * Last Modified By : Salmanhaider Aghariya
    * @param errorIds to store the failed lead error record Ids
    * @return List of RetryResult for each selected record
    * @description : Used to retry failed leads using the saved mapping (save the mapping first if it was changed).
    */
    @AuraEnabled
    public static List<RetryResult> retryFailedLeads(List<String> errorIds) {
        try {
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
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            logError(e, 'retryFailedLeads');
            throw auraError('Failed to retry the selected leads.');
        }
    }

    /**
    * Method Name : discardFailedLeads
    * Created By : Salmanhaider Aghariya
    * Last Modified Date : 05/10/2026
    * Last Modified By : Salmanhaider Aghariya
    * @param errorIds to store the failed lead error record Ids
    * @return Number of discarded records
    * @description : Used to delete the selected failed lead records.
    */
    @AuraEnabled
    public static Integer discardFailedLeads(List<String> errorIds) {
        try {
            if (errorIds == null || errorIds.isEmpty()) {
                throw auraError('Select at least one failed lead.');
            }
            List<MVEX__Error_Handling__c> records = [SELECT Id FROM MVEX__Error_Handling__c WHERE Id IN :errorIds AND MVEX__Source_of_Error__c = :GOOGLE_FAILED_SOURCE WITH USER_MODE];
            delete as user records;
            return records.size();
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            logError(e, 'discardFailedLeads');
            throw auraError('Failed to discard the selected leads.');
        }
    }

    /**
    * Method Name : getFormIdFromBody
    * Created By : Salmanhaider Aghariya
    * Last Modified Date : 05/10/2026
    * Last Modified By : Salmanhaider Aghariya
    * @param parsed to store the parsed error body
    * @return Google Lead Form Id
    * @description : Used to read the form Id from a new ({formId, payload}) or older (raw Google payload) record.
    */
    private static String getFormIdFromBody(Map<String, Object> parsed) {
        return str(parsed.containsKey('payload') ? parsed.get('formId') : parsed.get('form_id'));
    }

    /**
    * Method Name : getLeadIdFromBody
    * Created By : Salmanhaider Aghariya
    * Last Modified Date : 05/10/2026
    * Last Modified By : Salmanhaider Aghariya
    * @param parsed to store the parsed error body
    * @return Google Lead Id
    * @description : Used to read the lead Id from a new ({leadId, payload}) or older (raw Google payload) record.
    */
    private static String getLeadIdFromBody(Map<String, Object> parsed) {
        return str(parsed.containsKey('payload') ? parsed.get('leadId') : parsed.get('lead_id'));
    }

    /**
    * Method Name : toLeadData
    * Created By : Salmanhaider Aghariya
    * Last Modified Date : 05/10/2026
    * Last Modified By : Salmanhaider Aghariya
    * @param parsed to store the parsed error body
    * @return GoogleLeadsWebhook.LeadData
    * @description : Used to convert a stored error body into lead data.
    */
    private static GoogleLeadsWebhook.LeadData toLeadData(Map<String, Object> parsed) {
        try {
            Object payload = parsed.containsKey('payload') ? parsed.get('payload') : parsed;
            return (GoogleLeadsWebhook.LeadData)JSON.deserialize(JSON.serialize(payload), GoogleLeadsWebhook.LeadData.class);
        } catch (Exception e) {
            throw auraError('Invalid lead payload. ' + e.getMessage());
        }
    }

    /**
    * Method Name : withReason
    * Created By : Salmanhaider Aghariya
    * Last Modified Date : 05/10/2026
    * Last Modified By : Salmanhaider Aghariya
    * @param parsed to store the parsed error body
    * @param originalBody to store the original error body
    * @param reason to store the failure reason
    * @return Serialized error body including the reason
    * @description : Used to add a failure reason to a stored error body.
    */
    private static String withReason(Map<String, Object> parsed, String originalBody, String reason) {
        if (parsed == null) {
            return originalBody;
        }
        try {
            Map<String, Object> envelope = parsed.containsKey('payload') ? parsed : new Map<String, Object>{ 'formId' => getFormIdFromBody(parsed), 'leadId' => getLeadIdFromBody(parsed), 'payload' => parsed };
            envelope.put('reason', String.isBlank(reason) ? 'Unknown error' : reason);
            return JSON.serialize(envelope);
        } catch (Exception e) {
            return originalBody;
        }
    }

    /**
    * Method Name : getGoogleAuthUrl
    * Created By : Salmanhaider Aghariya
    * Last Modified Date : 05/10/2026
    * Last Modified By : Salmanhaider Aghariya
    * @return Google OAuth authorization URL
    * @description : Used to build the Google OAuth authorization URL.
    */
    @AuraEnabled(cacheable=false)
    public static String getGoogleAuthUrl() {
        try {
            OAuth_Configuration__mdt config = getGoogleOAuthConfiguration();

            if (String.isBlank(config.Client_Id__c) || String.isBlank(config.Authorization_Endpoint__c) || String.isBlank(config.Scope__c) || String.isBlank(config.Redirect_URI__c)) {
                throw auraError('Google Ads OAuth configuration is incomplete.');
            }

            return config.Authorization_Endpoint__c
                + '?client_id=' + encode(config.Client_Id__c)
                + '&redirect_uri=' + encode(config.Redirect_URI__c)
                + '&response_type=code'
                + '&scope=' + encode(config.Scope__c)
                + '&access_type=offline'
                + '&prompt=consent'
                + '&state=' + encode('Google_Ads_Config');
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            logError(e, 'getGoogleAuthUrl');
            throw auraError('Failed to generate the Google authorization URL.');
        }
    }

    /**
    * Method Name : saveRefreshToken
    * Created By : Salmanhaider Aghariya
    * Last Modified Date : 05/10/2026
    * Last Modified By : Salmanhaider Aghariya
    * @param refreshToken to store the Google refresh token
    * @return success String
    * @description : Used to save the Google refresh token and connection timestamp in OAuth configuration.
    */
    @AuraEnabled
    public static String saveRefreshToken(String refreshToken) {
        try {
            if (String.isBlank(refreshToken)) {
                throw auraError('Refresh token cannot be blank.');
            }

            Map<String, String> fieldValues = new Map<String, String>();
            fieldValues.put('Refresh_Token__c', refreshToken);
            fieldValues.put('Connected_At__c', System.now().formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''));
            updateConfigField(fieldValues);
            return 'success';
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            logError(e, 'saveRefreshToken');
            throw auraError('Failed to save Google Ads refresh token.');
        }
    }

    /**
    * Method Name : getConnection
    * Created By : Salmanhaider Aghariya
    * Last Modified Date : 05/10/2026
    * Last Modified By : Salmanhaider Aghariya
    * @return List of accessible Google Ads accounts
    * @description : Used to retrieve the connected Google Ads accounts.
    */
    @AuraEnabled(cacheable=false)
    public static List<GoogleAdsAccount> getConnection() {
        try {
            OAuth_Configuration__mdt config = getGoogleOAuthConfiguration();

            if (String.isBlank(config.Refresh_Token__c)) {
                return new List<GoogleAdsAccount>();
            }
            return getAllAccounts(getAccessToken(), getBaseUrl(config));
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            logError(e, 'getConnection');
            throw auraError('Failed to retrieve the Google Ads connection.');
        }
    }

    /**
    * Method Name : getConnectionInfo
    * Created By : Salmanhaider Aghariya
    * Last Modified Date : 05/10/2026
    * Last Modified By : Salmanhaider Aghariya
    * @return Map with name, email, and connectedDate values for the LWC connection card
    * @description : Retrieves Google account details at runtime and the persisted connection timestamp.
    */
    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getConnectionInfo() {
        try {
            OAuth_Configuration__mdt config = getGoogleOAuthConfiguration();

            if (String.isBlank(config.Refresh_Token__c)) {
                return new Map<String, Object>();
            }
            Map<String, String> userInfo = getGoogleUserInfo(getAccessTokenForRefreshToken(config, config.Refresh_Token__c));
            System.debug(LoggingLevel.INFO, 'Retrieved Google user info: ' + userInfo);
            Map<String, Object> connectionInfo = new Map<String, Object>();
            connectionInfo.put('name', userInfo.get('name'));
            connectionInfo.put('email', userInfo.get('email'));
            connectionInfo.put('connectedDate', config.Connected_At__c);
            return connectionInfo;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            logError(e, 'getConnectionInfo');
            throw auraError('Failed to retrieve the Google Ads connection Info.');
        }
    }

    /**
    * Method Name : getAccessToken
    * Created By : Salmanhaider Aghariya
    * Last Modified Date : 05/10/2026
    * Last Modified By : Salmanhaider Aghariya
    * @return Google access token
    * @description : Used to exchange the refresh token for a new access token.
    */
    private static String getAccessToken() {
        try {
            OAuth_Configuration__mdt config = getGoogleOAuthConfiguration();
            if (String.isBlank(config.Refresh_Token__c)) {
                throw auraError('Google Ads is not connected.');
            }
            return getAccessTokenForRefreshToken(config, config.Refresh_Token__c);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw auraError('Failed to obtain Google Ads access token. ' + e.getMessage());
        }
    }

    /**
    * Method Name : getAccessTokenForRefreshToken
    * @param config Google Ads OAuth configuration
    * @param refreshToken Google refresh token to exchange
    * @return Google access token
    * @description : Exchanges the supplied refresh token for a Google access token.
    */
    private static String getAccessTokenForRefreshToken(OAuth_Configuration__mdt config, String refreshToken) {
        try {
            if (config == null || String.isBlank(config.Client_Id__c) || String.isBlank(config.Client_Secret__c) || String.isBlank(config.Token_Endpoint__c)) {
                throw auraError('Google Ads OAuth configuration is incomplete.');
            }
            if (String.isBlank(refreshToken)) {
                throw auraError('Google Ads is not connected.');
            }
            HttpRequest request = new HttpRequest();
            request.setEndpoint(config.Token_Endpoint__c);
            request.setMethod('POST');
            request.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            request.setBody(
                'client_id=' + encode(config.Client_Id__c) +
                '&client_secret=' + encode(config.Client_Secret__c) +
                '&refresh_token=' + encode(refreshToken) +
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
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw auraError('Failed to obtain Google Ads access token. ' + e.getMessage());
        }
    }

    /**
    * Method Name : getGoogleUserInfo
    * @param accessToken Google access token
    * @return User name and email
    * @description : Retrieves the Google profile details used by the connection card.
    */
    private static Map<String, String> getGoogleUserInfo(String accessToken) {
        HttpRequest request = new HttpRequest();
        request.setEndpoint('https://www.googleapis.com/oauth2/v2/userinfo');
        request.setMethod('GET');
        request.setHeader('Authorization', 'Bearer ' + accessToken);

        HttpResponse response = new Http().send(request);
        if (response.getStatusCode() != 200) {
            throw auraError('Failed to retrieve Google account details. ' + response.getBody());
        }

        Map<String, Object> userInfo = (Map<String, Object>)JSON.deserializeUntyped(response.getBody());
        Map<String, String> accountInfo = new Map<String, String>();
        accountInfo.put('name', String.isBlank(str(userInfo.get('name'))) ? '' : str(userInfo.get('name')));
        accountInfo.put('email', String.isBlank(str(userInfo.get('email'))) ? '' : str(userInfo.get('email')));
        return accountInfo;
    }

    /**
    * Method Name : callGoogleAds
    * Created By : Salmanhaider Aghariya
    * Last Modified Date : 05/10/2026
    * Last Modified By : Salmanhaider Aghariya
    * @param method to store the HTTP method
    * @param endpoint to store the API endpoint
    * @param accessToken to store the Google access token
    * @param loginCustomerId to store the manager account Id
    * @param body to store the request body
    * @return HttpResponse
    * @description : Used to build and send every Google Ads API call.
    */
    private static HttpResponse callGoogleAds(String method, String endpoint, String accessToken, String loginCustomerId, Map<String, Object> body) {
        try {
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
        } catch (Exception e) {
            throw auraError('Google Ads API call failed. ' + e.getMessage());
        }
    }

    /**
    * Method Name : searchGoogleAds
    * Created By : Salmanhaider Aghariya
    * Last Modified Date : 05/10/2026
    * Last Modified By : Salmanhaider Aghariya
    * @param accessToken to store the Google access token
    * @param baseUrl to store the Google Ads API base URL
    * @param customerId to store the customer Id
    * @param loginCustomerId to store the manager account Id
    * @param query to store the GAQL query
    * @param errorPrefix to store the error message prefix
    * @return Parsed API response
    * @description : Used to run a GAQL query; throws with errorPrefix on failure.
    */
    private static Map<String, Object> searchGoogleAds(String accessToken, String baseUrl, String customerId, String loginCustomerId, String query, String errorPrefix) {
        try {
            HttpResponse response = callGoogleAds('POST', baseUrl + '/customers/' + customerId + '/googleAds:search', accessToken, loginCustomerId, new Map<String, Object>{ 'query' => query });
            if (response.getStatusCode() != 200) {
                throw auraError(errorPrefix + ' ' + response.getBody());
            }
            return (Map<String, Object>)JSON.deserializeUntyped(response.getBody());
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw auraError(errorPrefix + ' ' + e.getMessage());
        }
    }

    /**
    * Method Name : getAllAccounts
    * Created By : Salmanhaider Aghariya
    * Last Modified Date : 05/10/2026
    * Last Modified By : Salmanhaider Aghariya
    * @param accessToken to store the Google access token
    * @param baseUrl to store the Google Ads API base URL
    * @return List of Google Ads accounts
    * @description : Used to list every accessible customer and its client accounts.
    */
    private static List<GoogleAdsAccount> getAllAccounts(String accessToken, String baseUrl) {
        try {
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
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw auraError('Failed to retrieve Google Ads accounts. ' + e.getMessage());
        }
    }

    /**
    * Method Name : getCustomerAccounts
    * Created By : Salmanhaider Aghariya
    * Last Modified Date : 05/10/2026
    * Last Modified By : Salmanhaider Aghariya
    * @param accessToken to store the Google access token
    * @param customerId to store the customer Id
    * @param baseUrl to store the Google Ads API base URL
    * @return List of client accounts for the customer
    * @description : Used to retrieve the client accounts under a customer.
    */
    private static List<GoogleAdsAccount> getCustomerAccounts(String accessToken, String customerId, String baseUrl) {
        try {
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
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw auraError('Failed to retrieve Google Ads customer accounts. ' + e.getMessage());
        }
    }

    /**
    * Method Name : getFormsForAccount
    * Created By : Salmanhaider Aghariya
    * Last Modified Date : 05/10/2026
    * Last Modified By : Salmanhaider Aghariya
    * @param accountString to store the serialized GoogleAdsAccount
    * @return List of Google Lead Forms
    * @description : Used to retrieve the lead forms of the selected Google Ads account.
    */
    @AuraEnabled(cacheable=false)
    public static List<GoogleLeadForm> getFormsForAccount(String accountString) {
        try {
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
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            logError(e, 'getFormsForAccount');
            throw auraError('Failed to retrieve Google Lead Forms.');
        }
    }

    /**
    * Method Name : collectStrings
    * Created By : Salmanhaider Aghariya
    * Last Modified Date : 05/10/2026
    * Last Modified By : Salmanhaider Aghariya
    * @param items to store the JSON array
    * @param key to store the key to read from each item
    * @return List of values
    * @description : Used to pull one key out of each map in a JSON array.
    */
    private static List<String> collectStrings(Object items, String key) {
        List<String> values = new List<String>();
        if (items == null) {
            return values;
        }
        try {
            for (Object item : (List<Object>)items) {
                Object value = item == null ? null : ((Map<String, Object>)item).get(key);
                if (value != null) {
                    values.add(String.valueOf(value));
                }
            }
        } catch (Exception e) {
            throw auraError('Invalid Google Lead Form data. ' + e.getMessage());
        }
        return values;
    }

    /**
    * Method Name : getExistingMappings
    * Created By : Salmanhaider Aghariya
    * Last Modified Date : 05/10/2026
    * Last Modified By : Salmanhaider Aghariya
    * @return Saved mapping JSON
    * @description : Used to retrieve the saved Google Ads mapping JSON.
    */
    @AuraEnabled
    public static String getExistingMappings() {
        try {
            MVEX__Configuration_Settings__c setting = getMappingSetting();
            return setting == null ? null : setting.MVEX__Fields_Data__c;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            logError(e, 'getExistingMappings');
            throw auraError('Failed to retrieve the existing mappings.');
        }
    }

    /**
    * Method Name : saveMapping
    * Created By : Salmanhaider Aghariya
    * Last Modified Date : 05/10/2026
    * Last Modified By : Salmanhaider Aghariya
    * @param mappingJson to store the mapping JSON
    * @return Map containing success status and message
    * @description : Used to save the mapping and subscribe the webhook for newly added forms.
    */
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
            logError(e, 'saveMapping');
            return response(false, e.getMessage());
        }
    }

    /**
    * Method Name : validateMappingStructure
    * Created By : Salmanhaider Aghariya
    * Last Modified Date : 05/10/2026
    * Last Modified By : Salmanhaider Aghariya
    * @param mappingData to store the mapping data
    * @description : Used to validate the {accountId: {loginCustomerId, forms: {formId: {mappings}}}} structure.
    */
    private static void validateMappingStructure(Map<String, Object> mappingData) {
        try {
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
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw auraError('Invalid mapping structure. ' + e.getMessage());
        }
    }

    /**
    * Method Name : collectForms
    * Created By : Salmanhaider Aghariya
    * Last Modified Date : 05/10/2026
    * Last Modified By : Salmanhaider Aghariya
    * @param mappingData to store the mapping data
    * @return List of maps with accountId, formId and loginCustomerId
    * @description : Used to flatten the mapping data into one entry per form.
    */
    private static List<Map<String, String>> collectForms(Map<String, Object> mappingData) {
        List<Map<String, String>> resources = new List<Map<String, String>>();
        try {
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
        } catch (Exception e) {
            throw auraError('Invalid mapping structure. ' + e.getMessage());
        }
        return resources;
    }

    /**
    * Method Name : deleteMapping
    * Created By : Salmanhaider Aghariya
    * Last Modified Date : 05/10/2026
    * Last Modified By : Salmanhaider Aghariya
    * @param accountId to store the Google Ads account Id
    * @param loginCustomerId to store the manager account Id
    * @param formId to store the Google Lead Form Id
    * @return Map containing success status and message
    * @description : Used to unsubscribe the webhook and delete the mapping of a form.
    */
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
            Map<String, Object> forms = accountData == null ? null : (Map<String, Object>)accountData.get('forms');
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
            logError(e, 'deleteMapping');
            return response(false, e.getMessage());
        }
    }

    /**
    * Method Name : disconnectGoogleAds
    * Created By : Salmanhaider Aghariya
    * Last Modified Date : 05/10/2026
    * Last Modified By : Salmanhaider Aghariya
    * @return Map containing success status and message
    * @description : Used to unsubscribe all forms, revoke the token and remove the saved mappings.
    */
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
            logError(e, 'disconnectGoogleAds');
            return response(false, e.getMessage());
        }
    }

    /**
    * Method Name : revokeGoogleRefreshToken
    * Created By : Salmanhaider Aghariya
    * Last Modified Date : 05/10/2026
    * Last Modified By : Salmanhaider Aghariya
    * @param refreshToken to store the Google refresh token
    * @description : Used to revoke the refresh token at Google.
    */
    private static void revokeGoogleRefreshToken(String refreshToken) {
        try {
            HttpRequest request = new HttpRequest();
            request.setEndpoint('https://oauth2.googleapis.com/revoke');
            request.setMethod('POST');
            request.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            request.setBody('token=' + encode(refreshToken));
            HttpResponse response = new Http().send(request);

            // 400 means the token is already revoked or invalid, which is acceptable here.
            if (response.getStatusCode() != 200 && response.getStatusCode() != 400) {
                throw auraError('Failed to revoke Google refresh token. Status: ' + response.getStatusCode() + ' Response: ' + response.getBody());
            }
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw auraError('Failed to revoke Google refresh token. ' + e.getMessage());
        }
    }

    /**
    * Method Name : clearStoredRefreshToken
    * Created By : Salmanhaider Aghariya
    * Last Modified Date : 05/10/2026
    * Last Modified By : Salmanhaider Aghariya
    * @description : Used to clear the stored refresh token asynchronously.
    */
    @future
    private static void clearStoredRefreshToken() {
        try {
            updateConfigField(new Map<String, String>{
                'Refresh_Token__c' => '',
                'Connected_At__c' => null
            });
        } catch (Exception e) {
            logError(e, 'clearStoredRefreshToken');
        }
    }

    /**
    * Method Name : subscribeWebhook
    * Created By : Salmanhaider Aghariya
    * Last Modified Date : 05/10/2026
    * Last Modified By : Salmanhaider Aghariya
    * @param resources to store the forms that need a webhook subscription
    * @description : Used to subscribe the webhook delivery method on the given lead forms.
    */
    private static void subscribeWebhook(List<Map<String, String>> resources) {
        if (resources == null || resources.isEmpty()) {
            return;
        }
        try {
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
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw auraError('Failed to subscribe Google Ads webhook. ' + e.getMessage());
        }
    }

    /**
    * Method Name : mutateDeliveryMethods
    * Created By : Salmanhaider Aghariya
    * Last Modified Date : 05/10/2026
    * Last Modified By : Salmanhaider Aghariya
    * @param accessToken to store the Google access token
    * @param config to store the Google OAuth configuration
    * @param resource to store the account, form and login customer Ids
    * @param deliveryMethods to store the delivery methods (empty list = unsubscribe)
    * @param action to store the action name used in error messages
    * @description : Used to set the delivery methods of a lead form.
    */
    private static void mutateDeliveryMethods(String accessToken, OAuth_Configuration__mdt config, Map<String, String> resource, List<Object> deliveryMethods, String action) {
        try {
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
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw auraError('Failed to ' + action + ' Google Ads webhook. ' + e.getMessage());
        }
    }

    /**
    * Method Name : getWebhookEndpoint
    * Created By : Salmanhaider Aghariya
    * Last Modified Date : 05/10/2026
    * Last Modified By : Salmanhaider Aghariya
    * @return Full webhook endpoint URL
    * @description : Used to build the webhook endpoint from the configured site URL.
    */
    private static String getWebhookEndpoint() {
        String siteUrl = getGoogleOAuthConfiguration().Webhook_URL__c;
        if (String.isBlank(siteUrl)) {
            throw auraError('Webhook site is not configured. Select an active Force.com site first.');
        }
        return siteUrl.trim().removeEnd('/') + WEBHOOK_PATH;
    }

    /**
    * Method Name : hasExistingMappings
    * Created By : Salmanhaider Aghariya
    * Last Modified Date : 05/10/2026
    * Last Modified By : Salmanhaider Aghariya
    * @return True if at least one mapping exists
    * @description : Used to check whether any Google Ads mapping is saved.
    */
    private static Boolean hasExistingMappings() {
        return !getMappingData(getMappingSetting()).isEmpty();
    }

    /**
    * Method Name : getWebhookUrl
    * Created By : Salmanhaider Aghariya
    * Last Modified Date : 05/10/2026
    * Last Modified By : Salmanhaider Aghariya
    * @return Configured webhook site URL
    * @description : Used to retrieve the configured webhook site URL.
    */
    @AuraEnabled(cacheable=false)
    public static String getWebhookUrl() {
        try {
            return getGoogleOAuthConfiguration().Webhook_URL__c;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            logError(e, 'getWebhookUrl');
            throw auraError('Failed to retrieve the webhook URL.');
        }
    }

    /**
    * Method Name : getActiveSites
    * Created By : Salmanhaider Aghariya
    * Last Modified Date : 07/10/2026
    * Last Modified By : Salmanhaider Aghariya
    * @return List of active Force.com site options
    * @description : Used to retrieve active sites (setup objects, so USER_MODE is not used).
    */
    @AuraEnabled(cacheable=false)
    public static List<SiteOption> getActiveSites() {
        try {
            List<SiteOption> options = new List<SiteOption>();

            List<Site> sites = [SELECT Id, MasterLabel FROM Site WHERE Status = 'Active' AND SiteType = 'Visualforce' ORDER BY MasterLabel LIMIT 50];

            if (sites.isEmpty()) {
                return options;
            }

            Set<String> siteKeys = new Set<String>();

            for (Site site : sites) {
                siteKeys.add(String.valueOf(site.Id).left(15));
            }

            Map<String, String> secureUrlBySiteKey = new Map<String, String>();

            for (SiteDetail detail : [SELECT DurableId, SecureUrl FROM SiteDetail WHERE DurableId IN :siteKeys]) {
                if (String.isNotBlank(detail.SecureUrl)) {
                    secureUrlBySiteKey.put(detail.DurableId, detail.SecureUrl.trim().removeEnd('/'));
                }
            }

            for (Site site : sites) {
                String siteKey = String.valueOf(site.Id).left(15);
                String url = secureUrlBySiteKey.get(siteKey);

                if (String.isBlank(url)) {
                    continue;
                }

                SiteOption option = new SiteOption();
                option.value = url;
                option.label = site.MasterLabel + ' (' + url + ')';
                options.add(option);
            }

            return options;
        } catch (Exception e) {
            logError(e, 'getActiveSites');
            throw auraError('Failed to retrieve active sites.');
        }
    }

    /**
    * Method Name : saveWebhookUrl
    * Created By : Salmanhaider Aghariya
    * Last Modified Date : 05/10/2026
    * Last Modified By : Salmanhaider Aghariya
    * @param siteUrl to store the selected site URL
    * @return success String
    * @description : Used to save the webhook site; blocked while mappings exist for a different site.
    */
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

            updateConfigField(new Map<String, String>{ 'Webhook_URL__c' => normalized });
            return 'success';
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            logError(e, 'saveWebhookUrl');
            throw auraError('Failed to save the webhook site.');
        }
    }

    /**
    * Method Name : getSalesforceLeadFields
    * Created By : Salmanhaider Aghariya
    * Last Modified Date : 05/10/2026
    * Last Modified By : Salmanhaider Aghariya
    * @return List of Contact field details
    * @description : Used to retrieve mappable Contact fields. Cacheable, so errors are not logged via DML.
    */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getSalesforceLeadFields() {
        try {
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
        } catch (Exception e) {
            throw auraError('Failed to retrieve Salesforce fields. ' + e.getMessage());
        }
    }

    /**
    * @description : Wrapper for a Google Ads account.
    * Created By : Salmanhaider Aghariya
    * Last Modified Date : 05/10/2026
    * Last Modified By : Salmanhaider Aghariya
    */
    public class GoogleAdsAccount {
        @AuraEnabled public String id;
        @AuraEnabled public String descriptiveName;
        @AuraEnabled public Boolean manager;
        @AuraEnabled public String loginCustomerId;
    }

    /**
    * @description : Wrapper for a Google Lead Form.
    * Created By : Salmanhaider Aghariya
    * Last Modified Date : 05/10/2026
    * Last Modified By : Salmanhaider Aghariya
    */
    public class GoogleLeadForm {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String headline;
        @AuraEnabled public List<String> fields;
        @AuraEnabled public List<String> customQuestions;
    }

    /**
    * @description : Wrapper for a failed lead record.
    * Created By : Salmanhaider Aghariya
    * Last Modified Date : 05/10/2026
    * Last Modified By : Salmanhaider Aghariya
    */
    public class FailedLead {
        @AuraEnabled public String id;
        @AuraEnabled public String leadId;
        @AuraEnabled public Datetime receivedOn;
        @AuraEnabled public String reason;
    }

    /**
    * @description : Wrapper for the result of a failed lead retry.
    * Created By : Salmanhaider Aghariya
    * Last Modified Date : 05/10/2026
    * Last Modified By : Salmanhaider Aghariya
    */
    public class RetryResult {
        @AuraEnabled public String id;
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
    }

    /**
    * @description : Wrapper for an active site option.
    * Created By : Salmanhaider Aghariya
    * Last Modified Date : 05/10/2026
    * Last Modified By : Salmanhaider Aghariya
    */
    public class SiteOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
    }
}