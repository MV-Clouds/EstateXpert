@RestResource(urlMapping='/Lead/*')
global with sharing class GoogleLeadsWebhook {

    // Shared with GoogleAdsFormMappingController so each value lives in one place.
    public static final String GOOGLE_MAPPING_NAME = 'Google Ads Mappings';
    public static final String GOOGLE_SECRET = 'EstateXpert-GoogleAds-Webhook-Secret';
    public static final String FAILED_SOURCE = 'GoogleFailedLeads';

    private static final Set<Schema.DisplayType> TEXT_TYPES = new Set<Schema.DisplayType>{
        Schema.DisplayType.STRING, Schema.DisplayType.TEXTAREA, Schema.DisplayType.EMAIL,
        Schema.DisplayType.PHONE, Schema.DisplayType.URL
    };

    private static Map<String, Schema.SObjectField> contactFieldMap;

    public class LeadProcessingException extends Exception {}

    @HttpPost
    global static void handleNotification() {
        String requestBody = '';
        String formId;
        String leadId;
        try {
            requestBody = RestContext.request.requestBody.toString();
            if (String.isBlank(requestBody)) {
                logError('Empty request body received.');
                return;
            }

            LeadData googleLead = (LeadData)JSON.deserialize(requestBody, LeadData.class);

            if (googleLead == null || googleLead.user_column_data == null || String.isBlank(googleLead.form_id)) {
                logError('Invalid Google Lead payload.');
                return;
            }
            if (GOOGLE_SECRET != googleLead.google_key) {
                logError('Invalid Google Secret.');
                return;
            }

            formId = googleLead.form_id;
            leadId = googleLead.lead_id;

            FormConfiguration formConfiguration = getFormConfiguration(formId);
            if (formConfiguration == null || formConfiguration.mappings == null || formConfiguration.mappings.isEmpty()) {
                // Keep the lead so it can be retried once a mapping exists.
                saveFailedLead(requestBody, formId, leadId, 'No field mapping found for Form Id: ' + formId);
                return;
            }

            insert buildContact(googleLead, formConfiguration);
        } catch (Exception e) {
            saveFailedLead(requestBody, formId, leadId, e.getMessage());
        }
    }

    // ---------- shared with GoogleAdsFormMappingController (retry uses the same path) ----------
    public static FormConfiguration getFormConfiguration(String formId) {
        List<MVEX__Configuration_Settings__c> configs = [SELECT MVEX__Fields_Data__c FROM MVEX__Configuration_Settings__c WHERE Name = :GOOGLE_MAPPING_NAME WITH USER_MODE LIMIT 1];
        if (configs.isEmpty() || String.isBlank(configs[0].MVEX__Fields_Data__c)) {
            return null;
        }
        Map<String, AccountConfiguration> accountConfigs = (Map<String, AccountConfiguration>)JSON.deserialize(configs[0].MVEX__Fields_Data__c, Map<String, AccountConfiguration>.class);
        return findFormConfiguration(accountConfigs, formId);
    }

    public static Contact buildContact(LeadData googleLead, FormConfiguration formConfiguration) {
        Map<String, String> leadMap = buildLeadMap(googleLead.user_column_data);
        Map<String, Schema.SObjectField> fieldMap = getContactFields();
        Contact con = new Contact();

        for (String salesforceField : formConfiguration.mappings.keySet()) {
            String value = resolveValue(formConfiguration.mappings.get(salesforceField), leadMap);
            if (String.isBlank(value)) {
                continue;
            }

            Schema.SObjectField token = fieldMap.get(salesforceField);
            if (token == null) {
                throw new LeadProcessingException('Salesforce field "' + salesforceField + '" does not exist on Contact.');
            }

            try {
                con.put(salesforceField, coerceValue(token.getDescribe(), value.trim()));
            } catch (Exception ex) {
                throw new LeadProcessingException('Unable to populate "' + salesforceField + '": ' + ex.getMessage());
            }
        }
        return con;
    }

    // Stores the failed lead in an envelope so the UI can show the reason and retry later.
    public static void saveFailedLead(String requestBody, String formId, String leadId, String reason) {
        if (String.isBlank(requestBody)) {
            logError(reason);
            return;
        }
        try {
            Object payload;
            try {
                payload = JSON.deserializeUntyped(requestBody);
            } catch (Exception ignore) {
                payload = requestBody;
            }
            if (String.isBlank(formId) && payload instanceof Map<String, Object>) {
                Object f = ((Map<String, Object>)payload).get('form_id');
                formId = f == null ? null : String.valueOf(f);
            }

            MVEX__Error_Handling__c error = new MVEX__Error_Handling__c();
            error.MVEX__Class_Name__c = 'GoogleLeadsWebhook';
            error.MVEX__Method_Name__c = 'handleNotification';
            error.MVEX__Source_of_Error__c = FAILED_SOURCE;
            error.MVEX__Error_Body__c = JSON.serialize(new Map<String, Object>{
                'formId' => formId,
                'leadId' => leadId,
                'reason' => String.isBlank(reason) ? 'Unknown error' : reason.left(1000),
                'payload' => payload
            });
            insert error;
        } catch (Exception e) {
            logError('Could not store failed lead: ' + e.getMessage());
        }
    }

    // ---------- helpers ----------
    // Describe is cached: retry builds up to 200 contacts in one transaction.
    private static Map<String, Schema.SObjectField> getContactFields() {
        if (contactFieldMap == null) {
            contactFieldMap = Schema.SObjectType.Contact.fields.getMap();
        }
        return contactFieldMap;
    }

    private static String resolveValue(MappingConfiguration mapping, Map<String, String> leadMap) {
        if (mapping == null) {
            return null;
        }
        if (mapping.sourceType == 'google' && String.isNotBlank(mapping.googleField)) {
            return leadMap.get(normalizeGoogleField(mapping.googleField));
        }
        if (mapping.sourceType == 'custom') {
            return mapping.customValue;
        }
        return null;
    }

    // Converts to the field's type; text values are cut to the field's own max length.
    private static Object coerceValue(Schema.DescribeFieldResult field, String value) {
        Schema.DisplayType fieldType = field.getType();
        switch on fieldType {
            when BOOLEAN {
                return value.equalsIgnoreCase('true') || value.equalsIgnoreCase('yes') || value == '1';
            }
            when DATE {
                return Date.valueOf(value);
            }
            when INTEGER {
                return Integer.valueOf(value);
            }
            when DOUBLE, CURRENCY, PERCENT {
                return Decimal.valueOf(value);
            }
            when else {
                Integer maxLength = field.getLength();
                return TEXT_TYPES.contains(fieldType) && maxLength > 0 && value.length() > maxLength ? value.substring(0, maxLength) : value;
            }
        }
    }

    private static FormConfiguration findFormConfiguration(Map<String, AccountConfiguration> accountConfigs, String formId) {
        if (accountConfigs == null || accountConfigs.isEmpty() || String.isBlank(formId)) {
            return null;
        }
        for (AccountConfiguration account : accountConfigs.values()) {
            if (account != null && account.forms != null && account.forms.containsKey(formId)) {
                return account.forms.get(formId);
            }
        }
        return null;
    }

    private static Map<String, String> buildLeadMap(List<UserColumnData> userColumnData) {
        Map<String, String> leadMap = new Map<String, String>();
        if (userColumnData == null) {
            return leadMap;
        }
        for (UserColumnData column : userColumnData) {
            if (column == null || String.isBlank(column.column_id)) {
                continue;
            }
            String normalizedKey = normalizeGoogleField(column.column_id);
            if (String.isNotBlank(normalizedKey)) {
                leadMap.put(normalizedKey, column.string_value);
            }
        }
        return leadMap;
    }

    private static String normalizeGoogleField(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        return value.trim().toUpperCase().replaceAll('[^A-Z0-9]+', '_').replaceAll('^_+|_+$', '');
    }

    private static void logError(String message) {
        ErrorHandler.insertErrorData(null, 'GoogleLeadsWebhook', 'handleNotification', message);
    }

    global class LeadData {
        global String google_key;
        global String form_id;
        global String lead_id;
        global List<UserColumnData> user_column_data;
        global String gcl_id;
    }

    global class UserColumnData {
        global String column_id;
        global String string_value;
    }

    global class AccountConfiguration {
        global String accountName;
        global String loginCustomerId;
        global Map<String, FormConfiguration> forms;
    }

    global class FormConfiguration {
        global String formName;
        global Map<String, MappingConfiguration> mappings;
    }

    global class MappingConfiguration {
        global String sourceType;
        global String googleField;
        global String customValue;
    }
}