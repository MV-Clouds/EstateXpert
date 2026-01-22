@RestResource(urlMapping='/Lead/*')
global without sharing class GoogleLeadsWebhook {
    @HttpPost
    global static void handleNotification() {
        try {
            // Grab the body from the request
            String requestBody = RestContext.request.requestBody.toString();
            if (String.isBlank(requestBody)) {
                ErrorHandler.insertErrorData(null, 'GoogleLeadsWebhook', 'handleNotification', 'Empty request body received.');
                return;
            }

            // Deserialize JSON into LeadData
            LeadData googleLead = (LeadData) JSON.deserialize(requestBody, LeadData.class);
            if (googleLead == null || googleLead.user_column_data == null) {
                ErrorHandler.insertErrorData(null, 'GoogleLeadsWebhook', 'handleNotification', 'Invalid or null JSON payload.');
                return;
            }

            // Retrieve saved Google key from GoogleLeadConfig__c
            String savedGoogleKey;
            List<GoogleLeadConfig__c> configs = [
                SELECT Google_Lead_Form_Secret__c 
                FROM GoogleLeadConfig__c WITH USER_MODE
                LIMIT 1
            ];
            if (!configs.isEmpty()) {
                savedGoogleKey = configs[0].Google_Lead_Form_Secret__c;
            }

            // Retrieve field mappings from GoogleLeadFieldMapping__mdt
            String fieldMappingsJson;
            List<GoogleLeadFieldMapping__mdt> fieldMappingsRecords = [
                SELECT Field_Mappings__c 
                FROM GoogleLeadFieldMapping__mdt 
                WITH USER_MODE
                LIMIT 1
            ];
            if (!fieldMappingsRecords.isEmpty()) {
                fieldMappingsJson = fieldMappingsRecords[0].Field_Mappings__c;
            }

            // Validate Google key
            String returnedGoogleKey = googleLead.google_key;
            if (String.isBlank(savedGoogleKey) || savedGoogleKey != returnedGoogleKey) {
                ErrorHandler.insertErrorData(null, 'GoogleLeadsWebhook', 'handleNotification', 'The google secret was incorrect. Captured secret: ' + returnedGoogleKey);
                return;
            }

            // Parse field mappings from JSON
            List<FieldMapping> fieldMappings = new List<FieldMapping>();
            if (String.isNotBlank(fieldMappingsJson)) {
                fieldMappings = (List<FieldMapping>) JSON.deserialize(fieldMappingsJson, List<FieldMapping>.class);
            }

            // Build map of user lead data
            Map<String, String> leadMap = new Map<String, String>();
            for (UserColumnData columnData : googleLead.user_column_data) {
                if (String.isNotBlank(columnData.column_id) && String.isNotBlank(columnData.string_value)) {
                    leadMap.put(columnData.column_id.toUpperCase(), columnData.string_value);
                }
            }

            // Create a new lead
            Lead newLead = new Lead();
            newLead.Status = 'Pending';
            newLead.Company = 'Mvclouds PVT LTD';

            // Apply field mappings
            for (FieldMapping mapping : fieldMappings) {
                String metaField = mapping.metaField.toUpperCase();
                String value = leadMap.get(metaField);
                
                // Truncate values based on Salesforce field length limits
                if (String.isNotBlank(value)) {
                    if (mapping.salesforceField == 'FirstName' && value.length() > 40) {
                        value = value.substring(0, 40);
                    } else if (mapping.salesforceField == 'LastName' && value.length() > 80) {
                        value = value.substring(0, 80);
                    } else if (mapping.salesforceField == 'Email' && value.length() > 80) {
                        value = value.substring(0, 80);
                    } else if (mapping.salesforceField == 'Phone' && value.length() > 40) {
                        value = value.substring(0, 40);
                    } else if (mapping.salesforceField == 'Company' && value.length() > 255) {
                        value = value.substring(0, 255);
                    }
                    
                    // Set the field value dynamically
                    newLead.put(mapping.salesforceField, value);
                }
            }

            // Handle GCLID separately if needed
            String gclid = leadMap.get('GCLID');
            if (String.isNotBlank(gclid)) {
                newLead.put('GCLID__c', gclid); // Assuming a custom field for GCLID
            }

            insert as user newLead;

        } catch (Exception e) {
            ErrorHandler.insertErrorData(null, 'GoogleLeadsWebhook', 'handleNotification', 'Error processing webhook: ' + e.getMessage() + '\nStack Trace: ' + e.getStackTraceString());
        }
    }

    // Wrapper class for deserializing Google Ads lead data
    global class LeadData {
        global String google_key;
        global List<UserColumnData> user_column_data;
    }

    // Wrapper class for user column data
    global class UserColumnData {
        global String column_id;
        global String string_value;
    }

    // Wrapper class for field mappings
    global class FieldMapping {
        global String metaField;
        global String salesforceField;
        global Boolean isCustom;
    }
}