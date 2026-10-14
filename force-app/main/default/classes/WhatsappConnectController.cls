/**
 * Class Name : WhatsappConnectController
 * @description : Controller for WhatsApp Connect SDK Page. Uses OAuth_Configuration__mdt Custom Metadata Type
 *                for configuration and storing connection credentials.
 */
public with sharing class WhatsappConnectController {

    public static String appId {get; set;}
    public static String businessAccountId {get; set;}
    public static String phoneNumberId {get; set;}
    public static String accessToken {get; set;}
    public static String apiVersion {get; set;}
    public static String apiEndpoint {get; set;}
    public static String clientId {get; set;}
    public static String configurationId {get; set;}
    public static String clientSecret {get; set;}
    public static String lastModifiedDate {get; set;}
    public static String namespace {get; set;}

    public static final String CONFIG_DEV_NAME = 'Whatsapp_OAuth';

    public WhatsappConnectController() {
        String className = WhatsappConnectController.class.getName();
        namespace = className.contains('.') ? className.substringBefore('.') : 'c';

        OAuth_Configuration__mdt config = getConfig();

        if (config != null) {
            clientId = config.Client_Id__c != null ? config.Client_Id__c : '';
            clientSecret = config.Client_Secret__c != null ? config.Client_Secret__c : '';
            configurationId = config.Config_Id__c != null ? config.Config_Id__c : '';
            apiVersion = String.isNotBlank(config.API_Version__c) ? config.API_Version__c : '26.0';
            apiEndpoint = String.isNotBlank(config.Authorization_Endpoint__c) ? config.Authorization_Endpoint__c : 'https://graph.facebook.com';

            appId = config.Client_App_ID__c != null ? config.Client_App_ID__c : '';
            businessAccountId = config.Client_Business_Account_ID__c != null ? config.Client_Business_Account_ID__c : '';
            phoneNumberId = config.Client_Phone_Number_ID__c != null ? config.Client_Phone_Number_ID__c : '';
            accessToken = config.Access_Token__c != null ? config.Access_Token__c : '';

            if (config.Connected_Date__c != null) {
                lastModifiedDate = config.Connected_Date__c.format('MM/dd/yyyy, hh:mm:ss a');
            } else if (config.SystemModstamp != null && String.isNotBlank(config.Client_Business_Account_ID__c)) {
                lastModifiedDate = config.SystemModstamp.format('MM/dd/yyyy, hh:mm:ss a');
            } else {
                lastModifiedDate = '';
            }
        } else {
            clientId = '';
            clientSecret = '';
            configurationId = '';
            apiVersion = '26.0';
            apiEndpoint = 'https://graph.facebook.com';
            appId = '';
            businessAccountId = '';
            phoneNumberId = '';
            accessToken = '';
            lastModifiedDate = '';
        }
    }

    /**
     * Method Name : getConfig
     * @description : Retrieves the WhatsApp OAuth Custom Metadata configuration record.
     * @return OAuth_Configuration__mdt
     */
    public static OAuth_Configuration__mdt getConfig() {
        try {
            List<OAuth_Configuration__mdt> configs = [SELECT Id, DeveloperName, MasterLabel, Client_Id__c, Client_Secret__c, Config_Id__c, API_Version__c, 
                                                        Authorization_Endpoint__c, Token_Endpoint__c, Access_Token__c, Client_App_ID__c, Client_Business_Account_ID__c,
                                                        Client_Phone_Number_ID__c, Connected_Date__c, SystemModstamp FROM OAuth_Configuration__mdt
                                                        WHERE DeveloperName = :CONFIG_DEV_NAME WITH USER_MODE LIMIT 1];
            return configs.isEmpty() ? null : configs[0];
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'WhatsappConnectController', 'getConfig', e.getMessage());
            return null;
        }
    }

    /**
     * Method Name : getIntegrationConfig
     * @description : Retrieves WhatsApp integration settings and connection status for LWC.
     * @return Map<String, Object> containing config parameters and isConnected flag.
     */
    @AuraEnabled
    public static Map<String, Object> getIntegrationConfig() {
        Map<String, Object> result = new Map<String, Object>();
        try {
            OAuth_Configuration__mdt config = getConfig();
            if (config != null) {
                result.put('clientId', config.Client_Id__c != null ? config.Client_Id__c : '');
                result.put('configurationId', config.Config_Id__c != null ? config.Config_Id__c : '');
                result.put('apiVersion', String.isNotBlank(config.API_Version__c) ? config.API_Version__c : '26.0');
                result.put('apiEndpoint', String.isNotBlank(config.Authorization_Endpoint__c) ? config.Authorization_Endpoint__c : 'https://graph.facebook.com');
                result.put('appId', config.Client_App_ID__c != null ? config.Client_App_ID__c : '');
                result.put('businessAccountId', config.Client_Business_Account_ID__c != null ? config.Client_Business_Account_ID__c : '');
                result.put('phoneNumberId', config.Client_Phone_Number_ID__c != null ? config.Client_Phone_Number_ID__c : '');
                result.put('accessToken', config.Access_Token__c != null ? config.Access_Token__c : '');

                String lastMod = '';
                if (config.Connected_Date__c != null) {
                    lastMod = config.Connected_Date__c.format('MM/dd/yyyy, hh:mm:ss a');
                } else if (config.SystemModstamp != null && String.isNotBlank(config.Client_Business_Account_ID__c)) {
                    lastMod = config.SystemModstamp.format('MM/dd/yyyy, hh:mm:ss a');
                }
                result.put('lastModifiedDate', lastMod);
                result.put('isConnected', String.isNotBlank(config.Client_Business_Account_ID__c));
            } else {
                result.put('clientId', '');
                result.put('configurationId', '');
                result.put('apiVersion', '26.0');
                result.put('apiEndpoint', 'https://graph.facebook.com');
                result.put('appId', '');
                result.put('businessAccountId', '');
                result.put('phoneNumberId', '');
                result.put('accessToken', '');
                result.put('lastModifiedDate', '');
                result.put('isConnected', false);
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'WhatsappConnectController', 'getIntegrationConfig', e.getMessage());
        }
        return result;
    }

    @AuraEnabled
    public static Boolean unlinkAccount() {
        try {
            Boolean isSuccess = saveMetaData(null, null, null, null);
            return isSuccess;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'WhatsappConnectController', 'unlinkAccount', e.getMessage());
            return false;
        }
    }

    /**
     * Method Name : verifyManualCredentials
     * @description : Validates WhatsApp credentials (Access Token, Phone Number ID, WABA ID, App ID)
     *                using a SINGLE HTTP Callout to Meta Graph API Batch endpoint.
     *                Bundles Phone Number check, WABA check, and App check into one request.
     *                Supports Permanent, Temporary, System User, and Business Access Tokens.
     * @param accessToken Meta Access Token (Permanent, Temporary, or System User)
     * @param phoneId Phone Number ID
     * @param wabaId WhatsApp Business Account ID
     * @param appId Meta Application ID
     * @return Map<String, Object> validation result with isValid flag, field key, and message.
     */
    @RemoteAction
    public static Map<String, Object> verifyManualCredentials(String accessToken, String phoneId, String wabaId, String appId) {
        Map<String, Object> response = new Map<String, Object>();
        try {
            if (String.isBlank(accessToken) || String.isBlank(phoneId) || String.isBlank(wabaId) || String.isBlank(appId)) {
                response.put('isValid', false);
                response.put('field', 'general');
                response.put('message', 'Please fill in all 4 fields (Meta App ID, WABA ID, Phone Number ID, and Access Token).');
                return response;
            }

            accessToken = accessToken.trim();
            phoneId = phoneId.replaceAll('\\s+', '');
            wabaId = wabaId.replaceAll('\\s+', '');
            appId = appId.replaceAll('\\s+', '');

            if (!phoneId.isNumeric()) {
                response.put('isValid', false);
                response.put('field', 'phone');
                response.put('message', 'The Phone Number ID must contain only digits (e.g., 105938472910).');
                return response;
            }

            if (!wabaId.isNumeric()) {
                response.put('isValid', false);
                response.put('field', 'waba');
                response.put('message', 'The WhatsApp Business Account ID (WABA ID) must contain only digits.');
                return response;
            }

            if (!appId.isNumeric()) {
                response.put('isValid', false);
                response.put('field', 'app');
                response.put('message', 'The Meta Application ID must contain only digits.');
                return response;
            }

            OAuth_Configuration__mdt config = getConfig();
            String baseEndpoint = (config != null && String.isNotBlank(config.Authorization_Endpoint__c)) 
                ? config.Authorization_Endpoint__c.removeEnd('/') 
                : 'https://graph.facebook.com';
            String apiVer = (config != null && String.isNotBlank(config.API_Version__c)) 
                ? (config.API_Version__c.trim().startsWithIgnoreCase('v') ? config.API_Version__c.trim() : 'v' + config.API_Version__c.trim()) 
                : 'v21.0';

            // Build Batch operations to validate all credentials in a SINGLE callout:
            // Op 0: Phone Number ID check (fields: id, display_phone_number)
            // Op 1: WhatsApp Business Account ID check (fields: id, name)
            // Op 2: Token's parent App introspection (/app)
            // Op 3: Direct Meta App ID verification
            List<Map<String, String>> batchOps = new List<Map<String, String>>();
            batchOps.add(new Map<String, String>{
                'method' => 'GET',
                'relative_url' => phoneId + '?fields=id,display_phone_number'
            });
            batchOps.add(new Map<String, String>{
                'method' => 'GET',
                'relative_url' => wabaId + '?fields=id,name'
            });
            batchOps.add(new Map<String, String>{
                'method' => 'GET',
                'relative_url' => 'app'
            });
            batchOps.add(new Map<String, String>{
                'method' => 'GET',
                'relative_url' => appId
            });

            String batchPayload = 'include_headers=false&batch=' + EncodingUtil.urlEncode(JSON.serialize(batchOps), 'UTF-8');

            HttpRequest req = new HttpRequest();
            req.setEndpoint(baseEndpoint + '/' + apiVer);
            req.setMethod('POST');
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            req.setTimeout(20000);
            req.setBody(batchPayload);

            Http http = new Http();
            HttpResponse res = http.send(req);

            // Handle Top-Level HTTP Error (e.g. invalid/expired token or server error)
            if (res.getStatusCode() != 200) {
                Map<String, Object> errBody = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                Map<String, Object> errMap = (errBody != null && errBody.containsKey('error')) ? (Map<String, Object>) errBody.get('error') : null;
                String errMsg = (errMap != null && errMap.containsKey('message')) ? (String) errMap.get('message') : res.getStatus();

                if (isTokenErrorMap(errMap)) {
                    response.put('isValid', false);
                    response.put('field', 'token');
                    response.put('message', 'The Access Token is invalid or expired: ' + errMsg);
                    return response;
                }

                response.put('isValid', false);
                response.put('field', 'general');
                response.put('message', 'Verification failed: ' + errMsg);
                return response;
            }

            // Parse Batch Results Array
            List<Object> batchResults = (List<Object>) JSON.deserializeUntyped(res.getBody());
            if (batchResults == null || batchResults.isEmpty()) {
                response.put('isValid', false);
                response.put('field', 'general');
                response.put('message', 'Empty verification response received from Meta.');
                return response;
            }

            // 1. Evaluate Operation 0: Phone Number ID
            Map<String, Object> phoneItem = (Map<String, Object>) batchResults.get(0);
            Integer phoneCode = (Integer) phoneItem.get('code');
            String phoneBodyStr = (String) phoneItem.get('body');
            Map<String, Object> phoneBody = String.isNotBlank(phoneBodyStr) 
                ? (Map<String, Object>) JSON.deserializeUntyped(phoneBodyStr) 
                : new Map<String, Object>();

            if (phoneCode != 200) {
                Map<String, Object> errMap = phoneBody.containsKey('error') ? (Map<String, Object>) phoneBody.get('error') : null;
                String errMsg = (errMap != null && errMap.containsKey('message')) ? (String) errMap.get('message') : 'HTTP ' + phoneCode;

                if (isTokenErrorMap(errMap)) {
                    response.put('isValid', false);
                    response.put('field', 'token');
                    response.put('message', 'The Access Token is invalid or expired: ' + errMsg);
                    return response;
                }

                response.put('isValid', false);
                response.put('field', 'phone');
                response.put('message', 'The Phone Number ID is invalid or cannot be accessed with this token: ' + errMsg);
                return response;
            }

            // 2. Evaluate Operation 1: WhatsApp Business Account ID (WABA ID)
            Map<String, Object> wabaItem = (Map<String, Object>) batchResults.get(1);
            Integer wabaCode = (Integer) wabaItem.get('code');
            String wabaBodyStr = (String) wabaItem.get('body');
            Map<String, Object> wabaBody = String.isNotBlank(wabaBodyStr) 
                ? (Map<String, Object>) JSON.deserializeUntyped(wabaBodyStr) 
                : new Map<String, Object>();

            if (wabaCode != 200) {
                Map<String, Object> errMap = wabaBody.containsKey('error') ? (Map<String, Object>) wabaBody.get('error') : null;
                String errMsg = (errMap != null && errMap.containsKey('message')) ? (String) errMap.get('message') : 'HTTP ' + wabaCode;

                if (isTokenErrorMap(errMap)) {
                    response.put('isValid', false);
                    response.put('field', 'token');
                    response.put('message', 'The Access Token is invalid or expired: ' + errMsg);
                    return response;
                }

                response.put('isValid', false);
                response.put('field', 'waba');
                response.put('message', 'The WhatsApp Business Account ID (WABA ID) is invalid or not accessible: ' + errMsg);
                return response;
            }

            // 3. Evaluate Operation 2 & 3: Meta Application ID
            Map<String, Object> appItem = (Map<String, Object>) batchResults.get(2);
            Integer appCode = (Integer) appItem.get('code');
            String appBodyStr = (String) appItem.get('body');
            Map<String, Object> appBody = String.isNotBlank(appBodyStr) 
                ? (Map<String, Object>) JSON.deserializeUntyped(appBodyStr) 
                : new Map<String, Object>();

            if (appCode == 200) {
                String tokenAppId = appBody.containsKey('id') ? String.valueOf(appBody.get('id')) : null;
                if (String.isNotBlank(tokenAppId) && tokenAppId != appId) {
                    response.put('isValid', false);
                    response.put('field', 'app');
                    response.put('message', 'The Access Token was generated under Meta App ID ' + tokenAppId + ', which does not match the entered App ID (' + appId + '). Please enter App ID: ' + tokenAppId);
                    return response;
                }
            } else {
                // If /app cannot be queried (e.g. some system user scopes), verify from direct app operation
                if (batchResults.size() > 3) {
                    Map<String, Object> directAppItem = (Map<String, Object>) batchResults.get(3);
                    Integer directCode = (Integer) directAppItem.get('code');
                    String directBodyStr = (String) directAppItem.get('body');
                    Map<String, Object> directBody = String.isNotBlank(directBodyStr) 
                        ? (Map<String, Object>) JSON.deserializeUntyped(directBodyStr) 
                        : new Map<String, Object>();

                    if (directCode != 200) {
                        Map<String, Object> errMap = directBody.containsKey('error') ? (Map<String, Object>) directBody.get('error') : null;
                        Integer errCode = (errMap != null && errMap.containsKey('code')) ? (Integer) errMap.get('code') : 0;
                        String errMsg = (errMap != null && errMap.containsKey('message')) ? (String) errMap.get('message') : '';

                        // Error code 10 means app exists on Meta, but token lacks App Admin role (normal for System Users)
                        if (errCode != 10 && !errMsg.containsIgnoreCase('capability')) {
                            if (errMsg.containsIgnoreCase('does not exist') || errCode == 100) {
                                response.put('isValid', false);
                                response.put('field', 'app');
                                response.put('message', 'The Meta Application ID does not exist: ' + errMsg);
                                return response;
                            }
                        }
                    }
                }
            }

            // All validations succeeded in the single callout
            response.put('isValid', true);
            return response;

        } catch (System.CalloutException ce) {
            ErrorHandler.insertErrorData(ce, 'WhatsappConnectController', 'verifyManualCredentials', ce.getMessage());
            response.put('isValid', false);
            response.put('field', 'general');
            response.put('message', 'Callout error during verification: ' + ce.getMessage());
            return response;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'WhatsappConnectController', 'verifyManualCredentials', e.getMessage());
            response.put('isValid', false);
            response.put('field', 'general');
            response.put('message', 'Error verifying credentials: ' + e.getMessage());
            return response;
        }
    }

    /**
     * Helper method to determine if a Meta error map indicates an invalid/expired token.
     */
    private static Boolean isTokenErrorMap(Map<String, Object> err) {
        if (err == null) {
            return false;
        }
        Integer code = err.containsKey('code') ? (Integer) err.get('code') : 0;
        String msg = err.containsKey('message') ? ((String) err.get('message')).toLowerCase() : '';

        if (code == 190 || code == 102 || code == 104 || code == 2500) {
            return true;
        }
        if (msg.contains('access token') || msg.contains('session has expired') 
            || msg.contains('invalid oauth') || msg.contains('error validating access token')
            || msg.contains('token was revoked') || msg.contains('malformed access token')
            || msg.contains('could not be decrypted') || msg.contains('user has logged out')
            || msg.contains('signature')) {
            return true;
        }
        return false;
    }

    @RemoteAction
    public static Boolean saveManualDetails(String accessToken, String phoneId, String wabaId, String appId) {
        try {
            if (String.isBlank(accessToken) || String.isBlank(phoneId) || String.isBlank(wabaId) || String.isBlank(appId)) {
                return false;
            }
            return saveMetaData(accessToken.trim(), phoneId.replaceAll('\\s+', ''), wabaId.replaceAll('\\s+', ''), appId.replaceAll('\\s+', ''));
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'WhatsappConnectController', 'saveManualDetails', e.getMessage());
            return false;
        }
    }

    @RemoteAction
    public static String saveFBLoginDetails(String sAccessToken, String phoneId, String wabaId, String appId) {
        try {
            OAuth_Configuration__mdt config = getConfig();
            if (config == null || String.isBlank(config.Client_Id__c) || String.isBlank(config.Client_Secret__c)) {
                return 'Failure';
            }

            String tokenEndpoint = config.Token_Endpoint__c;

            String tokenUrl = tokenEndpoint
                + '?grant_type=fb_exchange_token&client_id=' + EncodingUtil.urlEncode(config.Client_Id__c, 'UTF-8')
                + '&client_secret=' + EncodingUtil.urlEncode(config.Client_Secret__c, 'UTF-8')
                + '&fb_exchange_token=' + EncodingUtil.urlEncode(sAccessToken, 'UTF-8');

            HttpRequest req = new HttpRequest();
            req.setEndpoint(tokenUrl);
            req.setMethod('GET');
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                Map<String, Object> responseBody1 = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                String longLivedAccessToken = (String) responseBody1.get('access_token');
                Boolean isSuccess = saveMetaData(longLivedAccessToken, phoneId, wabaId, appId);
                if (isSuccess) {
                    return wabaId;
                }
            } else {
                ErrorHandler.insertErrorData(null, 'WhatsappConnectController', 'saveFBLoginDetails', 'Token exchange failed: ' + res.getStatusCode() + ' ' + res.getBody());
            }
            return null;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'WhatsappConnectController', 'saveFBLoginDetails', e.getMessage());
            return null;
        }
    }

    public static Boolean saveMetaData(String accessToken, String phoneId, String wabaId, String appId) {
        try {
            Metadata.CustomMetadata cmtRecord = new Metadata.CustomMetadata();
            cmtRecord.fullName = 'OAuth_Configuration__mdt.' + CONFIG_DEV_NAME;
            cmtRecord.label = 'Whatsapp OAuth';

            Metadata.CustomMetadataValue cmtAccessToken = new Metadata.CustomMetadataValue();
            cmtAccessToken.field = 'Access_Token__c';
            cmtAccessToken.value = String.isNotBlank(accessToken) ? accessToken : null;
            cmtRecord.values.add(cmtAccessToken);

            Metadata.CustomMetadataValue cmtPhoneId = new Metadata.CustomMetadataValue();
            cmtPhoneId.field = 'Client_Phone_Number_ID__c';
            cmtPhoneId.value = String.isNotBlank(phoneId) ? phoneId : null;
            cmtRecord.values.add(cmtPhoneId);

            Metadata.CustomMetadataValue cmtWabaId = new Metadata.CustomMetadataValue();
            cmtWabaId.field = 'Client_Business_Account_ID__c';
            cmtWabaId.value = String.isNotBlank(wabaId) ? wabaId : null;
            cmtRecord.values.add(cmtWabaId);

            Metadata.CustomMetadataValue cmtAppId = new Metadata.CustomMetadataValue();
            cmtAppId.field = 'Client_App_ID__c';
            cmtAppId.value = String.isNotBlank(appId) ? appId : null;
            cmtRecord.values.add(cmtAppId);

            Metadata.CustomMetadataValue cmtConnectedDate = new Metadata.CustomMetadataValue();
            cmtConnectedDate.field = 'Connected_Date__c';
            cmtConnectedDate.value = String.isNotBlank(wabaId) ? Datetime.now() : null;
            cmtRecord.values.add(cmtConnectedDate);

            Metadata.DeployContainer mdContainer = new Metadata.DeployContainer();
            mdContainer.addMetadata(cmtRecord);

            if (!Test.isRunningTest()) {
                Metadata.Operations.enqueueDeployment(mdContainer, null);
            }
            return true;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'WhatsappConnectController', 'saveMetaData', e.getMessage());
            return false;
        }
    }

    /**
     * Method Name : getContactObjectConfig
     * @description : Retrieves Contact phone fields, required fields, and saved MVEX__Object_Config__mdt configuration.
     * @return Map<String, Object> containing phone fields, required fields, and saved configuration.
     */
    @AuraEnabled
    public static Map<String, Object> getContactObjectConfig() {
        Map<String, Object> result = new Map<String, Object>();
        try {
            List<Map<String, String>> phoneFields = new List<Map<String, String>>();
            List<Map<String, Object>> requiredFields = new List<Map<String, Object>>();

            Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Contact.fields.getMap();
            for (Schema.SObjectField field : fieldMap.values()) {
                Schema.DescribeFieldResult dfr = field.getDescribe();

                // Fetch createable and accessible phone fields
                if (dfr.getType() == Schema.DisplayType.PHONE && dfr.isAccessible() && dfr.isCreateable() && !dfr.isCalculated()) {
                    phoneFields.add(new Map<String, String>{
                        'label' => dfr.getLabel(),
                        'value' => dfr.getName()
                    });
                }

                // Filter required fields for Contact creation
                if (dfr.isNillable() || dfr.isAutoNumber() || !dfr.isAccessible() || !dfr.isCreateable() || dfr.isCalculated() || dfr.isExternalId() || dfr.getType() == Schema.DisplayType.BOOLEAN) {
                    continue;
                }
                if (dfr.getName() == 'Id' || dfr.getName() == 'CreatedDate' || dfr.getName() == 'LastModifiedDate') {
                    continue;
                }

                Map<String, Object> fieldInfo = new Map<String, Object>{
                    'name' => dfr.getName(),
                    'label' => dfr.getLabel(),
                    'type' => dfr.getType().name(),
                    'value' => ''
                };

                if (dfr.getType() == Schema.DisplayType.Picklist) {
                    List<Map<String, String>> picklistValues = new List<Map<String, String>>();
                    for (Schema.PicklistEntry entry : dfr.getPicklistValues()) {
                        picklistValues.add(new Map<String, String>{
                            'label' => entry.getLabel(),
                            'value' => entry.getValue()
                        });
                    }
                    fieldInfo.put('picklistValues', picklistValues);
                    fieldInfo.put('value', dfr.getDefaultValue() != null ? String.valueOf(dfr.getDefaultValue()) : (picklistValues.isEmpty() ? '' : picklistValues[0].get('value')));
                } else if (dfr.getType() == Schema.DisplayType.Reference && !dfr.getReferenceTo().isEmpty()) {
                    fieldInfo.put('relatedObject', dfr.getReferenceTo()[0].getDescribe().getName());
                }

                requiredFields.add(fieldInfo);
            }

            // Retrieve saved configuration from MVEX__Object_Config__mdt
            Map<String, String> savedConfig = new Map<String, String>{
                'ObjectConfigInfo' => '{}',
                'ChatWindowConfigInfo' => '{}'
            };
            List<MVEX__Object_Config__mdt> configList = [SELECT MVEX__ObjectConfigInfo__c, MVEX__ChatWindowConfigInfo__c FROM MVEX__Object_Config__mdt WITH USER_MODE LIMIT 1];
            if (!configList.isEmpty()) {
                if (String.isNotBlank(configList[0].MVEX__ObjectConfigInfo__c)) {
                    savedConfig.put('ObjectConfigInfo', configList[0].MVEX__ObjectConfigInfo__c);
                }
                if (String.isNotBlank(configList[0].MVEX__ChatWindowConfigInfo__c)) {
                    savedConfig.put('ChatWindowConfigInfo', configList[0].MVEX__ChatWindowConfigInfo__c);
                }
            }

            result.put('phoneFields', phoneFields);
            result.put('requiredFields', requiredFields);
            result.put('savedConfig', savedConfig);
            result.put('success', true);
        } catch (Exception e) {
            result.put('success', false);
            result.put('message', e.getMessage());
            ErrorHandler.insertErrorData(e, 'WhatsappConnectController', 'getContactObjectConfig', e.getMessage());
        }
        return result;
    }

    /**
     * Method Name : saveContactObjectConfig
     * @description : Saves Contact phone field and webhook configuration to MVEX__Object_Config__mdt.
     * @param webhookJson JSON string for Webhook configuration
     * @param chatJson JSON string for Chat Window configuration
     * @return String 'Success' or error message
     */
    @AuraEnabled
    public static String saveContactObjectConfig(String webhookJson, String chatJson) {
        try {
            String devName = 'objectConfigInfo';
            String masterLabel = 'objectConfigInfo';

            List<MVEX__Object_Config__mdt> configList = [SELECT MasterLabel, DeveloperName, MVEX__ObjectConfigInfo__c, MVEX__ChatWindowConfigInfo__c FROM MVEX__Object_Config__mdt WITH USER_MODE LIMIT 1];
            if (!configList.isEmpty()) {
                devName = configList[0].DeveloperName;
                masterLabel = configList[0].MasterLabel;
            }

            Metadata.CustomMetadata mdata = new Metadata.CustomMetadata();
            mdata.fullName = 'MVEX__Object_Config__mdt.MVEX__' + devName;
            mdata.label = masterLabel;

            if (webhookJson != null) {
                Metadata.CustomMetadataValue instance1 = new Metadata.CustomMetadataValue();
                instance1.field = 'MVEX__ObjectConfigInfo__c';
                instance1.value = webhookJson;
                mdata.values.add(instance1);
            }

            if (chatJson != null) {
                Metadata.CustomMetadataValue instance2 = new Metadata.CustomMetadataValue();
                instance2.field = 'MVEX__ChatWindowConfigInfo__c';
                instance2.value = chatJson;
                mdata.values.add(instance2);
            }

            Metadata.DeployContainer container = new Metadata.DeployContainer();
            container.addMetadata(mdata);

            if (!Test.isRunningTest()) {
                Metadata.Operations.enqueueDeployment(container, null);
            }

            return 'Success';
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'WhatsappConnectController', 'saveContactObjectConfig', e.getMessage());
            return 'Error: ' + e.getMessage();
        }
    }

    @AuraEnabled
    public static String getRecordName(String objectApiName, String recordId) {
        try {
            if (String.isBlank(objectApiName) || String.isBlank(recordId)) {
                return '';
            }
            String query = 'SELECT Name FROM ' + String.escapeSingleQuotes(objectApiName) + ' WHERE Id = \'' + String.escapeSingleQuotes(recordId) + '\' WITH USER_MODE LIMIT 1';
            SObject record = Database.query(query);
            return (String) record.get('Name');
        } catch (Exception e) {
            return '';
        }
    }
}