@RestResource(urlMapping='/PAGE/webhooks/*')
global without sharing class MetaLeadWebhook {
    
    // --- Configuration Getters ---
    private static MVEX__MetaLeadConfig__c getConfig() { return MVEX__MetaLeadConfig__c.getInstance(); }
    private static String accessToken { get { return getConfig().MVEX__ACCESS_TOKEN__c; } set; }
    private static String verifyToken { get { return getConfig().MVEX__VERIFY_TOKEN__c; } set; }
    private static String fbApiVersion { get { return getConfig().MVEX__FB_API_VERSION__c; } set; }
    private static String appId { get { return getConfig().MVEX__APP_ID__c; } set; }
    private static String appSecret { get { return getConfig().MVEX__APP_SECRET__c; } set; }

    private static String pageId = '';
    private static String formId = '';
    private static String leadId = '';
    
    @HttpGet
    global static void doGet() {
        try{
            RestRequest request = RestContext.request;
            RestResponse response = RestContext.response;
            if (request.params.get('hub.verify_token') == verifyToken) {
                response.responseBody = Blob.valueOf(request.params.get('hub.challenge'));
            }
        } catch(Exception e){
            ErrorHandler.insertErrorData(e, 'MetaLeadWebhook', 'doGet', e.getMessage());
        }
    }
    
    @HttpPost
    global static void handlePost() {
        RestResponse res = RestContext.response;
        String rawPostData = RestContext.request.requestBody.toString();
        
        try {
            Map<String, Object> jsonData = (Map<String, Object>) JSON.deserializeUntyped(rawPostData);
            List<Object> entries = (List<Object>) jsonData.get('entry');
            
            if (entries != null && !entries.isEmpty()) {
                Map<String, Object> entry = (Map<String, Object>) entries[0];
                List<Object> changes = (List<Object>) entry.get('changes');
                
                if (changes != null && !changes.isEmpty()) {
                    Map<String, Object> change = (Map<String, Object>) changes[0];
                    Map<String, Object> value = (Map<String, Object>) change.get('value');
                    
                    leadId = String.valueOf(value.get('leadgen_id'));
                    formId = String.valueOf(value.get('form_id'));
                    pageId = String.valueOf(value.get('page_id'));
                    
                    if (String.isNotBlank(accessToken)) {
                        Map<String, Object> leadData = fetchLeadData(leadId);
                        String formName = fetchFormName(formId);
                        createSalesforceContact(leadData, formName);
                    }
                }
            }
            res.statusCode = 200;
            res.responseBody = Blob.valueOf('Webhook received successfully.');
        } catch (Exception e) {
            System.debug('Error: ' + e.getMessage());
            ErrorHandler.insertErrorData(e, 'MetaLeadWebhook', 'handlePost', e.getMessage());
            res.statusCode = 500;
            res.responseBody = Blob.valueOf('Error processing webhook: ' + e.getMessage());
        }
    }
    
    // API Call to get Lead Field Data
    public static Map<String, Object> fetchLeadData(String leadgenId) {
        String url = 'https://graph.facebook.com/' + fbApiVersion + '/' + leadgenId + 
                     '?fields=field_data,platform,created_time&access_token=' + EncodingUtil.urlEncode(accessToken, 'UTF-8');
        return makeGetRequest(url);
    }

    // New API Call to get Form Name
    public static String fetchFormName(String formId) {
        try{
            if(String.isBlank(formId)) return '';
            String url = 'https://graph.facebook.com/' + fbApiVersion + '/' + formId + 
                         '?fields=name&access_token=' + EncodingUtil.urlEncode(accessToken, 'UTF-8');
            
            Map<String, Object> response = makeGetRequest(url);
            if(response.containsKey('name')){
                return (String)response.get('name');
            }
            return '';
        }catch(Exception e){
            System.debug('Error fetching form name: ' + e.getMessage());
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
            System.debug('API Error: ' + e.getMessage());
            ErrorHandler.insertErrorData(e, 'MetaLeadWebhook', 'makeGetRequest', e.getMessage());
            return new Map<String, Object>();
        }
    }
    
    public class FieldMapping {
        public String metaField { get; set; }
        public String salesforceField { get; set; }
    }
    
    private static void createSalesforceContact(Map<String, Object> leadData, String formName) {
        if (leadData.containsKey('id')) {
            Contact newContact = new Contact();
            
            // --- 1. Store Full JSON ---
            // This stores the exact response in the Long Text Area field
            try {
                newContact.MVEX__Meta_Raw_JSON__c = JSON.serializePretty(leadData);
            } catch(Exception e) {
                System.debug('JSON too large for field');
            }

            // --- 2. Handle Platform ---
            String platform = leadData.containsKey('platform') ? (String) leadData.get('platform') : 'facebook';
            newContact.LeadSource = (platform == 'ig') ? 'Instagram' : 'Facebook';
            
            // --- 3. Store IDs and Form Name ---
            newContact.MVEX__MetaLeadId__c = leadId;
            newContact.MVEX__MetaPageId__c = pageId;
            newContact.MVEX__MetaFormId__c = formId;
            newContact.MVEX__Meta_Form_Name__c = formName; // Store the fetched name
            newContact.MVEX__Contact_Type__c = 'Buyer';

            // --- 4. Process Field Mappings ---
            MetaLeadFieldMapping__mdt mappingRecord = [SELECT MVEX__New_Field_Mapping__c FROM MetaLeadFieldMapping__mdt LIMIT 1];
            // Deserialize the JSON string into a list of mappings
            List<FieldMapping> fieldMappings = new List<FieldMapping>();
            if (mappingRecord != null && String.isNotBlank(mappingRecord.MVEX__New_Field_Mapping__c)) {
                fieldMappings = (List<FieldMapping>) JSON.deserialize(mappingRecord.MVEX__New_Field_Mapping__c, List<FieldMapping>.class);
            }
            
            // Create a map for easier lookup
            Map<String, FieldMapping> fieldMappingMap = new Map<String, FieldMapping>();
            for (FieldMapping mapping : fieldMappings) {
                fieldMappingMap.put(mapping.metaField, mapping);
            }
            
            // Process field data
            if (leadData.containsKey('field_data')) {
                List<Object> fieldData = (List<Object>) leadData.get('field_data');
                for (Object field : fieldData) {
                    Map<String, Object> fieldMap = (Map<String, Object>) field;
                    String fieldName = (String) fieldMap.get('name');
                    List<Object> values = (List<Object>) fieldMap.get('values');
                    String fieldValue = values != null && !values.isEmpty() ? String.valueOf(values[0]) : '';
                    
                    if (fieldMappingMap.containsKey(fieldName)) {
                        newContact.put(fieldMappingMap.get(fieldName).salesforceField, fieldValue);
                    }
                }
            }
            
            // --- 5. Insert ---
            try {
                insert newContact;
            } catch (Exception e) {
                ErrorHandler.insertErrorData(e, 'MetaLeadWebhook', 'createSalesforceLead', e.getMessage());
            }
        }
    }
}