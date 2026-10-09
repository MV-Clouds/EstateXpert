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

    private static final String CONFIG_DEV_NAME = 'Whatsapp_OAuth';

    @TestVisible
    private static OAuth_Configuration__mdt mockConfig;

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
            if (mockConfig != null) {
                return mockConfig;
            }
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
     *                by making an HTTP Callout to Meta Graph API from Apex.
     * @param accessToken Meta Permanent Access Token
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
            phoneId = phoneId.trim();
            wabaId = wabaId.trim();
            appId = appId.trim();

            OAuth_Configuration__mdt config = getConfig();
            String baseEndpoint = (config != null && String.isNotBlank(config.Authorization_Endpoint__c)) 
                ? config.Authorization_Endpoint__c.trim() 
                : 'https://graph.facebook.com';
            String apiVer = (config != null && String.isNotBlank(config.API_Version__c)) 
                ? config.API_Version__c.trim() 
                : 'v21.0';
            if (!apiVer.startsWith('v')) {
                apiVer = 'v' + apiVer;
            }

            Http http = new Http();

            // 1. Verify Phone Number ID & Access Token
            HttpRequest phoneReq = new HttpRequest();
            phoneReq.setEndpoint(baseEndpoint + '/' + apiVer + '/' + EncodingUtil.urlEncode(phoneId, 'UTF-8') + '?fields=id,display_phone_number,whatsapp_business_account&access_token=' + EncodingUtil.urlEncode(accessToken, 'UTF-8'));
            phoneReq.setMethod('GET');
            phoneReq.setTimeout(15000);
            HttpResponse phoneRes = http.send(phoneReq);

            if (phoneRes.getStatusCode() != 200) {
                Map<String, Object> errBody = (Map<String, Object>) JSON.deserializeUntyped(phoneRes.getBody());
                Map<String, Object> errMap = (errBody != null && errBody.containsKey('error')) ? (Map<String, Object>) errBody.get('error') : null;
                Integer errCode = (errMap != null && errMap.containsKey('code')) ? (Integer) errMap.get('code') : 0;
                String errMsg = (errMap != null && errMap.containsKey('message')) ? (String) errMap.get('message') : phoneRes.getStatus();

                if (errCode == 190 || (errMsg != null && errMsg.toLowerCase().contains('access token'))) {
                    response.put('isValid', false);
                    response.put('field', 'token');
                    response.put('message', 'The Permanent Access Token is invalid or expired. Please check your token.');
                    return response;
                }

                response.put('isValid', false);
                response.put('field', 'phone');
                response.put('message', 'The Phone Number ID is invalid or cannot be accessed with this token.');
                return response;
            }

            // 2. Verify WhatsApp Business Account ID (WABA ID)
            HttpRequest wabaReq = new HttpRequest();
            wabaReq.setEndpoint(baseEndpoint + '/' + apiVer + '/' + EncodingUtil.urlEncode(wabaId, 'UTF-8') + '?access_token=' + EncodingUtil.urlEncode(accessToken, 'UTF-8'));
            wabaReq.setMethod('GET');
            wabaReq.setTimeout(15000);
            HttpResponse wabaRes = http.send(wabaReq);

            if (wabaRes.getStatusCode() != 200) {
                Map<String, Object> errBody = (Map<String, Object>) JSON.deserializeUntyped(wabaRes.getBody());
                Map<String, Object> errMap = (errBody != null && errBody.containsKey('error')) ? (Map<String, Object>) errBody.get('error') : null;
                Integer errCode = (errMap != null && errMap.containsKey('code')) ? (Integer) errMap.get('code') : 0;
                String errMsg = (errMap != null && errMap.containsKey('message')) ? (String) errMap.get('message') : wabaRes.getStatus();

                if (errCode == 190 || (errMsg != null && errMsg.toLowerCase().contains('access token'))) {
                    response.put('isValid', false);
                    response.put('field', 'token');
                    response.put('message', 'The Permanent Access Token is invalid or expired. Please check your token.');
                    return response;
                }

                response.put('isValid', false);
                response.put('field', 'waba');
                response.put('message', 'The WhatsApp Business Account ID (WABA ID) is invalid or not accessible with this token.');
                return response;
            }

            // 3. Verify Meta Application ID
            HttpRequest appReq = new HttpRequest();
            appReq.setEndpoint(baseEndpoint + '/' + apiVer + '/' + EncodingUtil.urlEncode(appId, 'UTF-8') + '?access_token=' + EncodingUtil.urlEncode(accessToken, 'UTF-8'));
            appReq.setMethod('GET');
            appReq.setTimeout(15000);
            HttpResponse appRes = http.send(appReq);

            if (appRes.getStatusCode() != 200) {
                Map<String, Object> errBody = (Map<String, Object>) JSON.deserializeUntyped(appRes.getBody());
                Map<String, Object> errMap = (errBody != null && errBody.containsKey('error')) ? (Map<String, Object>) errBody.get('error') : null;
                String errMsg = (errMap != null && errMap.containsKey('message')) ? (String) errMap.get('message') : 'Please check your App ID.';

                response.put('isValid', false);
                response.put('field', 'app');
                response.put('message', 'The Meta Application ID is incorrect: ' + errMsg);
                return response;
            }

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

    @RemoteAction
    public static Boolean saveManualDetails(String accessToken, String phoneId, String wabaId, String appId) {
        try {
            if (String.isBlank(accessToken) || String.isBlank(phoneId) || String.isBlank(wabaId) || String.isBlank(appId)) {
                return false;
            }
            return saveMetaData(accessToken.trim(), phoneId.trim(), wabaId.trim(), appId.trim());
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