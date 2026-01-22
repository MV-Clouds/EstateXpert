public with sharing class GeminiChatService {
    // Replace with your Google API key and Pinecone details
    // private static final String GEMINI_API_KEY = 'AIzaSyAzzNG5wlULwCiH2cXBsEDcFpRnlA6xNZI'; // Your existing Gemini API key
    // private static final String PINECONE_API_KEY = 'pcsk_4jQkvE_7cU4xzy1jvZTjPfsAaKyXkqeQxPJWYsvmUPbJkh1o269AP2s5cWrcPRHxPytCM5';
    // private static final String PINECONE_INDEX_URL = 'https://salesforce-data-ufp31fc.svc.aped-4627-b74a.pinecone.io';
    // private static final String GEMINI_EMBEDDING_ENDPOINT = 'https://generativelanguage.googleapis.com/v1beta/models/embedding-001:embedContent';

    // @AuraEnabled
    // public static Object getListingFields() {
    //     try {
    //         Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
    //         if (!globalDescribe.containsKey('MVEX__Listing__c')) {
    //             return new Map<String, Object>{ 'error' => 'MVEX__Listing__c object does not exist.' };
    //         }

    //         Map<String, Schema.SObjectField> fieldMap = globalDescribe.get('MVEX__Listing__c').getDescribe().fields.getMap();
    //         List<Map<String, Object>> fields = new List<Map<String, Object>>();
    //         for (String fieldName : fieldMap.keySet()) {
    //             Schema.DescribeFieldResult field = fieldMap.get(fieldName).getDescribe();
    //             if (field.isAccessible()) {
    //                 fields.add(new Map<String, Object>{
    //                     'name' => field.getName(),
    //                     'label' => field.getLabel(),
    //                     'type' => String.valueOf(field.getType())
    //                 });
    //             }
    //         }
    //         return fields;
    //     } catch (Exception e) {
    //         ErrorHandler.insertErrorData(e, 'GeminiChatService', 'getListingFields', e.getMessage());
    //         return new Map<String, Object>{ 'error' => 'Error retrieving property fields: ' + e.getMessage() };
    //     }
    // }

    // @AuraEnabled
    // public static String getGeminiResponse(String userInput) {
    //     try {
    //         if (String.isBlank(userInput)) {
    //             return 'Error: User input is empty.';
    //         }

    //         String sanitizedInput = userInput.replaceAll('[\n\r\t]', ' ').trim();
    //         if (sanitizedInput.toLowerCase().startsWith('select')) {
    //             return executeDynamicQuery(sanitizedInput);
    //         }

    //         // Detect if the query is related to EstateXpert
    //         Boolean isEstateXpertQuery = detectEstateXpertQuery(sanitizedInput);
    //         String prompt;

    //         if (isEstateXpertQuery) {
    //             // Query Pinecone for relevant paragraphs
    //             String pineconeResponse = queryPinecone(sanitizedInput);
    //             if (pineconeResponse.startsWith('Error:')) {
    //                 return pineconeResponse; // Return error from Pinecone
    //             }

    //             // Parse Pinecone response to extract paragraphs
    //             List<String> relevantParagraphs = parsePineconeResponse(pineconeResponse);
    //             if (relevantParagraphs.isEmpty()) {
    //                 // Updated response to avoid mentioning documentation
    //                 prompt = 'I couldn\'t find information on that topic. Please try rephrasing your question or contact support for further assistance. ' +
    //                         'User Query: "' + sanitizedInput + '"';
    //             } else {
    //                 // Construct prompt with retrieved paragraphs
    //                 prompt = 'You are ChatXpert, a support bot for the EstateXpert product. Always refer to yourself as "ChatXpert" and never use "AI" when mentioning yourself. ' +
    //                         'Use the following relevant information to answer the user’s query. ' +
    //                         'Information: ' + String.join(relevantParagraphs, '\n') + '\n' +
    //                         'Provide a short, simple, and clear response in plain text. Do not use Markdown, bold, italics, stars, hashtags, or any special formatting. ' +
    //                         'If the provided information is insufficient, respond with: ' +
    //                         '"I couldn\'t find information on that topic. Please try rephrasing your question or contact support for further assistance." ' +
    //                         'User Query: "' + sanitizedInput + '"';
    //             }
    //         } else {
    //             prompt = 'You are ChatXpert, a support bot that only answers questions related to Salesforce or real estate. Always refer to yourself as "ChatXpert" and never use "AI" when mentioning yourself. ' +
    //                     'If the query is related to Salesforce (e.g., Apex, LWC, SOQL, Flows, custom objects, integrations) or real estate (e.g., properties, housing, rentals), provide a short, simple, and clear response in plain text. ' +
    //                     'Do not use Markdown, bold, italics, stars, hashtags, or any special formatting. ' +
    //                     'If the query is not related to Salesforce or real estate, respond with exactly this message: ' +
    //                     'ChatXpert can only assist with questions related to Salesforce or real estate. Please ask a relevant question or contact support. ' +
    //                     'User Query: "' + sanitizedInput + '"';
    //         }

    //         // Call Gemini API with the constructed prompt
    //         String endpoint = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent?key=' + GEMINI_API_KEY;
    //         String requestBody = JSON.serialize(new Map<String, Object>{
    //             'contents' => new List<Object>{
    //                 new Map<String, Object>{
    //                     'parts' => new List<Object>{
    //                         new Map<String, Object>{ 'text' => prompt }
    //                     }
    //                 }
    //             }
    //         });

    //         HttpRequest req = new HttpRequest();
    //         req.setEndpoint(endpoint);
    //         req.setMethod('POST');
    //         req.setTimeout(120000);
    //         req.setHeader('Content-Type', 'application/json');
    //         req.setBody(requestBody);

    //         Http http = new Http();
    //         HttpResponse res = http.send(req);

    //         if (res.getStatusCode() == 200) {
    //             Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
    //             List<Object> candidates = (List<Object>) response.get('candidates');
    //             if (candidates != null && !candidates.isEmpty()) {
    //                 Map<String, Object> candidate = (Map<String, Object>) candidates[0];
    //                 Map<String, Object> content = (Map<String, Object>) candidate.get('content');
    //                 List<Object> parts = (List<Object>) content.get('parts');
    //                 if (parts != null && !parts.isEmpty()) {
    //                     String responseText = String.valueOf(((Map<String, Object>) parts[0]).get('text'));
    //                     // Remove any residual Markdown or special characters
    //                     responseText = responseText.replaceAll('[\\*\\#\\`\\-\\[\\]\\(\\)]', '').trim();
    //                     return responseText;
    //                 }
    //             }
    //             return 'Error: No response from Gemini API.';
    //         } else {
    //             Map<String, Object> errorResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
    //             return 'Error: Gemini API call failed - ' + String.valueOf(errorResponse.get('error'));
    //         }
    //     } catch (Exception e) {
    //         ErrorHandler.insertErrorData(e, 'GeminiChatService', 'getGeminiResponse', e.getMessage());
    //         return 'Error processing request: ' + e.getMessage();
    //     }
    // }

    // private static String queryPinecone(String userInput) {
    //     try {
    //         // Step 1: Generate embedding for the user input using Gemini
    //         String embedding = getQueryEmbedding(userInput);
    //         if (embedding.startsWith('Error:')) {
    //             return embedding;
    //         }

    //         // Step 2: Query Pinecone with the embedding
    //         String pineconeRequestBody = JSON.serialize(new Map<String, Object>{
    //             'vector' => JSON.deserializeUntyped(embedding),
    //             'top_k' => 3, // Retrieve top 3 matching paragraphs
    //             'includeMetadata' => true // Ensure metadata (paragraph text) is included
    //         });

    //         HttpRequest req = new HttpRequest();
    //         req.setEndpoint(PINECONE_INDEX_URL + '/query');
    //         req.setMethod('POST');
    //         req.setTimeout(120000);
    //         req.setHeader('Content-Type', 'application/json');
    //         req.setHeader('Api-Key', PINECONE_API_KEY);
    //         req.setBody(pineconeRequestBody);

    //         Http http = new Http();
    //         HttpResponse res = http.send(req);
    //         System.debug('Pinecone Response: ' + res.getBody());
    //         System.debug('Pinecone Status Code: ' + res.getStatusCode());
    //         if (res.getStatusCode() == 200) {
    //             return res.getBody();
    //         } else {
    //             Map<String, Object> errorResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
    //             return 'Error: Pinecone API call failed - ' + String.valueOf(errorResponse.get('error'));
    //         }
    //     } catch (Exception e) {
    //         ErrorHandler.insertErrorData(e, 'GeminiChatService', 'queryPinecone', e.getMessage());
    //         return 'Error querying Pinecone: ' + e.getMessage();
    //     }
    // }

    // private static String getQueryEmbedding(String userInput) {
    //     try {
    //         String requestBody = JSON.serialize(new Map<String, Object>{
    //             'content' => new Map<String, Object>{
    //                 'parts' => new List<Object>{
    //                     new Map<String, Object>{ 'text' => userInput }
    //                 }
    //             }
    //         });

    //         HttpRequest req = new HttpRequest();
    //         req.setEndpoint(GEMINI_EMBEDDING_ENDPOINT + '?key=' + GEMINI_API_KEY);
    //         req.setMethod('POST');
    //         req.setTimeout(120000);
    //         req.setHeader('Content-Type', 'application/json');
    //         req.setBody(requestBody);

    //         Http http = new Http();
    //         HttpResponse res = http.send(req);

    //         if (res.getStatusCode() == 200) {
    //             Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
    //             Map<String, Object> embeddingData = (Map<String, Object>) response.get('embedding');
    //             if (embeddingData != null && embeddingData.containsKey('values')) {
    //                 return JSON.serialize(embeddingData.get('values'));
    //             }
    //             return 'Error: No embedding returned from Gemini API.';
    //         } else {
    //             Map<String, Object> errorResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
    //             return 'Error: Gemini embedding API call failed - ' + String.valueOf(errorResponse.get('error'));
    //         }
    //     } catch (Exception e) {
    //         ErrorHandler.insertErrorData(e, 'GeminiChatService', 'getQueryEmbedding', e.getMessage());
    //         return 'Error generating embedding: ' + e.getMessage();
    //     }
    // }

    // private static List<String> parsePineconeResponse(String pineconeResponse) {
    //     List<String> paragraphs = new List<String>();
    //     try {
    //         Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(pineconeResponse);
    //         List<Object> matches = (List<Object>) response.get('matches');
    //         if (matches != null) {
    //             for (Object matchObj : matches) {
    //                 Map<String, Object> match = (Map<String, Object>) matchObj;
    //                 Map<String, Object> metadata = (Map<String, Object>) match.get('metadata');
    //                 if (metadata != null && metadata.containsKey('text')) {
    //                     paragraphs.add(String.valueOf(metadata.get('text')));
    //                 }
    //             }
    //         }
    //     } catch (Exception e) {
    //         ErrorHandler.insertErrorData(e, 'GeminiChatService', 'parsePineconeResponse', e.getMessage());
    //     }
    //     return paragraphs;
    // }

    // private static Boolean detectEstateXpertQuery(String input) {
    //     String[] estateXpertKeywords = new String[]{
    //         'estatexpert', 'real estate platform', 'property management', 'listing management',
    //         'crm for real estate', 'estatexpert features', 'estatexpert pricing', 'estatexpert support'
    //     };
    //     for (String keyword : estateXpertKeywords) {
    //         if (input.toLowerCase().contains(keyword.toLowerCase())) {
    //             return true;
    //         }
    //     }
    //     return false;
    // }

    // @AuraEnabled
    // public static String sendFeedbackEmail(String subject, String description, String[] images) {
    //     // Unchanged from original code
    //     try {
    //         String[] toAddresses = Label.supportEmail.split(',');
    //         String userName = UserInfo.getName();
    //         String userEmail = UserInfo.getUserEmail();
    //         String orgId = UserInfo.getOrganizationId();
            
    //         String emailBody = 'Feedback Submission\n\n' +
    //                          'User: ' + userName + '\n' +
    //                          'Email: ' + userEmail + '\n' +
    //                          'Organization ID: ' + orgId + '\n\n' +
    //                          'Description:\n' + description;

    //         Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
    //         mail.setToAddresses(toAddresses);
    //         mail.setSubject(subject);
    //         mail.setPlainTextBody(emailBody);

    //         if (images != null && !images.isEmpty()) {
    //             List<Messaging.EmailFileAttachment> attachments = new List<Messaging.EmailFileAttachment>();
    //             for (Integer i = 0; i < images.size(); i++) {
    //                 Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
    //                 attachment.setFileName('feedback_image_' + (i + 1) + '.png');
    //                 attachment.setBody(EncodingUtil.base64Decode(images[i]));
    //                 attachments.add(attachment);
    //             }
    //             mail.setFileAttachments(attachments);
    //         }

    //         Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[]{mail});
    //         if (results[0].isSuccess()) {
    //             return 'Success';
    //         } else {
    //             return 'Error: Failed to send email - ' + results[0].getErrors()[0].getMessage();
    //         }
    //     } catch (Exception e) {
    //         ErrorHandler.insertErrorData(e, 'GeminiChatService', 'sendFeedbackEmail', e.getMessage());
    //         return 'Error: ' + e.getMessage();
    //     }
    // }

    // private static String executeDynamicQuery(String query) {
    //     // Unchanged from original code
    //     try {
    //         if (!query.toLowerCase().startsWith('select') || !query.contains('FROM Listing__c')) {
    //             return 'Error: Invalid query: Must query Listing__c';
    //         }

    //         String sanitizedQuery = query.replaceAll('[^a-zA-Z0-9_,=\\s\'"]', '');
    //         if (!sanitizedQuery.toLowerCase().contains(' limit ')) {
    //             sanitizedQuery += ' LIMIT 10';
    //         }

    //         String selectClause = sanitizedQuery.substring(6, sanitizedQuery.indexOf(' FROM ')).trim();
    //         List<String> fields = selectClause.split(',');
    //         Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
    //         Map<String, Schema.SObjectField> fieldMap = globalDescribe.get('Listing__c').getDescribe().fields.getMap();
    //         for (String field : fields) {
    //             String trimmedField = field.trim();
    //             if (!fieldMap.containsKey(trimmedField.toLowerCase()) && trimmedField.toLowerCase() != 'id') {
    //                 return 'Error: Invalid field in query: ' + trimmedField;
    //             }
    //         }

    //         List<SObject> properties = Database.query(sanitizedQuery);
    //         return JSON.serialize(properties);
    //     } catch (Exception e) {
    //         ErrorHandler.insertErrorData(e, 'GeminiChatService', 'executeDynamicQuery', e.getMessage());
    //         return 'Error executing query: ' + e.getMessage();
    //     }
    // }
}