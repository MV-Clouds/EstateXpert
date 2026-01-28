@RestResource(urlMapping='/PAGE/webhooks/*')
global without sharing class MetaLeadWebhook {
    // Fetch configuration from custom setting
    private static MetaLeadConfig__c getConfig() {
        return MetaLeadConfig__c.getInstance();
    }

    // Configuration variables sourced from custom setting
    private static String accessToken {
        get {
            MetaLeadConfig__c config = getConfig();
            return config.ACCESS_TOKEN__c;
        }
        set;
    }
    private static String verifyToken {
        get {
            MetaLeadConfig__c config = getConfig();
            return config.VERIFY_TOKEN__c;
        }
        set;
    }
    private static String fbApiVersion {
        get {
            MetaLeadConfig__c config = getConfig();
            return config.FB_API_VERSION__c;
        }
        set;
    }
    private static String appId {
        get {
            MetaLeadConfig__c config = getConfig();
            return config.APP_ID__c;
        }
        set;
    }
    private static String appSecret {
        get {
            MetaLeadConfig__c config = getConfig();
            return config.APP_SECRET__c;
        }
        set;
    }

    private static String pageId = '';
    private static String formId = '';
    private static String leadId = '';
    
    @HttpGet
    global static void doGet() {
        try{
            RestResponse response = RestContext.response;
            RestRequest request = RestContext.request;
            if (request.params.get('hub.verify_token') == verifyToken) {
                response.responseBody = Blob.valueOf(request.params.get('hub.challenge'));
            }
        }catch(Exception e){
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
                    String leadgenId = String.valueOf(value.get('leadgen_id'));
                    leadId = String.valueOf(value.get('leadgen_id'));
                    formId = String.valueOf(value.get('form_id'));
                    pageId = String.valueOf(value.get('page_id'));
                    
                    if (String.isNotBlank(accessToken)) {
                        Map<String, Object> leadData = fetchLeadData(leadgenId);
                        System.debug('leadData--->' + leadData);
                        createSalesforceContact(leadData);
                    }
                }
            }
            
            res.statusCode = 200;
            res.responseBody = Blob.valueOf('Webhook received successfully.');
        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf('Error processing webhook: ' + e.getMessage());
            ErrorHandler.insertErrorData(e, 'MetaLeadWebhook', 'handlePost', e.getMessage());
        }
    }
    
    public static Map<String, Object> fetchLeadData(String leadgenId) {
        // Request specific fields: field_data for form answers, platform for source (IG vs FB)
        String url = 'https://graph.facebook.com/' + fbApiVersion + '/' + leadgenId + 
                     '?fields=field_data,platform&access_token=' + EncodingUtil.urlEncode(accessToken, 'UTF-8');
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint(url);
        req.setMethod('GET');
        
        Http http = new Http();
        try {
            HTTPResponse res = http.send(req);
            return (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'MetaLeadWebhook', 'fetchLeadData', e.getMessage());
            return new Map<String, Object>{'error' => e.getMessage()};
        }
    }
    
    public class FieldMapping {
        public String metaField { get; set; }
        public String salesforceField { get; set; }
        public Boolean isCustom { get; set; }
    }
    
    private static void createSalesforceContact(Map<String, Object> leadData) {

        System.debug('leadData in createSalesforceContact--->' + leadData);
        if (leadData.containsKey('id')) {
            Contact newContact = new Contact();
            // Company field is not available on standard Contact object
            
            // Check platform field to separate Instagram vs Facebook leads
            String platform = '';
            if (leadData.containsKey('platform')) {
                platform = (String) leadData.get('platform');
            }
            
            if (platform == 'ig') {
                newContact.LeadSource = 'Instagram';
            } else {
                newContact.LeadSource = 'Facebook';
            }

            newContact.MetaLeadId__c = leadId;
            newContact.MetaPageId__c = pageId;
            newContact.MetaFormId__c = formId;
            
            // Fetch the mapping from custom metadata
            MetaLeadFieldMapping__mdt mappingRecord = [
                SELECT FieldMappingJson__c
                FROM MetaLeadFieldMapping__mdt
                LIMIT 1
            ];
            
            // Deserialize the JSON string into a list of mappings
            List<FieldMapping> fieldMappings = new List<FieldMapping>();
            if (mappingRecord != null && String.isNotBlank(mappingRecord.FieldMappingJson__c)) {
                fieldMappings = (List<FieldMapping>) JSON.deserialize(mappingRecord.FieldMappingJson__c, List<FieldMapping>.class);
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
                    
                    // Check if there's a mapping for this Meta field
                    if (fieldMappingMap.containsKey(fieldName)) {
                        FieldMapping mapping = fieldMappingMap.get(fieldName);
                        String sfField = mapping.salesforceField;
                        newContact.put(sfField, fieldValue);
                    }
                }
            }
            
            try {
                insert newContact;
            } catch (DmlException e) {
                ErrorHandler.insertErrorData(e, 'MetaLeadWebhook', 'createSalesforceLead', e.getMessage());
            }
        } else {
            ErrorHandler.insertErrorData(null, 'MetaLeadWebhook', 'createSalesforceLead', 'No valid lead data found');
        }
    }
}