public with sharing class GeminiTemplateGenerator {

    @AuraEnabled
    public static GeminiResponse generateTemplate(
            String prompt,
            String objectApiName,
            List<String> objectFieldKeys,
            List<String> generalFieldKeys,
            List<String> signatureKey,
            Boolean isForEmail) {       

        // ---- existing config loading ------------------------------------------------
        Gemini_API_Setting__mdt apiConfig = Gemini_API_Setting__mdt.getInstance('External_API_Config');
        if (apiConfig == null || String.isBlank(apiConfig.API_Key__c)) {
            throw new AuraHandledException('Gemini API Key missing.');
        }

        // ---- build a **rich** prompt that contains **all** keys --------------------
        String allKeys = String.join(
            new List<String> {
                '=== OBJECT FIELD KEYS ===\n'   + String.join(objectFieldKeys, '\n'),
                '\n=== GENERAL FIELD KEYS ===\n' + String.join(generalFieldKeys, '\n'),
                '\n=== SIGNATURE KEY ===\n'     + (signatureKey?.isEmpty() ? '' : signatureKey[0])
            },
            '\n\n'
        );
        String headerPrompt = '';
        if (isForEmail) {
           headerPrompt = '- the "header" and "Footer" MUST be empty in response\n';
        }else{
            headerPrompt = '- the "header" and "Footer" MUST be in the response\n';
        }

        String fullPrompt = prompt + '\n\n' +
            'You are a world-class email marketing designer. Create a **stunning, modern, responsive, professional marketing email template** using clean HTML and inline CSS.Do not use the table layout in the template. you can use the stylish table to only shows the details. and template should have atleast width of the 90%. \n\n' +
            'STRICT RULES:\n' +
            '- Use ONLY these merge field formats (exactly as shown, case-sensitive):\n' +
            allKeys + '\n' +
            '- NEVER invent new merge-field syntax.\n' +
            headerPrompt +'\n'+
            '- If user asks the add the images in the listing templates then you have to add the image tag like this <img src="https://estatexpertdemo-dev-ed.develop.lightning.force.com/resource/tempimage" data-origin="pm" data-name="listingMedia[1]" crossorigin="*" style="width: 75%; height: 75%;"> static resource url should same and data-name="listingMedia[1]" change the index for the other images in the template and index is always start from 1'+
            '- Return **only** valid JSON (no markdown, no code fences).\n\n' +
            'Example output:\n' +
            '{\n' +
            '  "header": "",\n' +
            '  "body": "...",\n' +
            '  "footer": "..."\n' +
            '}';

        // ---- HTTP call (unchanged) -------------------------------------------------
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-09-2025:generateContent?key=' + apiConfig.API_Key__c);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(120000);

        String payload = JSON.serialize(new Map<String, Object>{
            'contents' => new List<Object>{
                new Map<String, Object>{
                    'role' => 'user',
                    'parts' => new List<Object>{ new Map<String, Object>{ 'text' => fullPrompt } }
                }
            },
            'generationConfig' => new Map<String, Object>{ 'responseMimeType' => 'application/json' }
        });

        req.setBody(payload);
        HttpResponse res = http.send(req);

        // ---- response handling (unchanged except for the final return) ----------
        if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> candidates = (List<Object>) result.get('candidates');
            if (candidates == null || candidates.isEmpty()) {
                throw new AuraHandledException('No response from Gemini.');
            }
            Map<String, Object> content = (Map<String, Object>) ((Map<String, Object>) candidates[0]).get('content');
            List<Object> parts = (List<Object>) content.get('parts');
            String jsonText = (String) ((Map<String, Object>) parts[0]).get('text');

            jsonText = jsonText.replaceAll('```json|```', '').trim();

            try {
                GeminiResponse parsed = (GeminiResponse) JSON.deserialize(jsonText, GeminiResponse.class);
                // Force header to be empty for marketing
                if (prompt.toLowerCase().contains('marketing') || prompt.toLowerCase().contains('email')) {
                    parsed.header = '';
                }
                return parsed;
            } catch (Exception e) {
                throw new AuraHandledException('Invalid JSON from Gemini: ' + e.getMessage() + '\nRaw: ' + jsonText);
            }
        } else {
            throw new AuraHandledException('Gemini API error: ' + res.getStatusCode() + ' ' + res.getBody());
        }
    }

    @AuraEnabled
    public static GeminiResponse editTemplateWithGemini(
            String userPrompt,
            String currentHtml,
            String objectApiName,
            List<String> objectFieldKeys,
            List<String> generalFieldKeys,
            List<String> signatureKey,
            Boolean isForEmail) {

        Gemini_API_Setting__mdt apiConfig = Gemini_API_Setting__mdt.getInstance('External_API_Config');
        if (apiConfig == null || String.isBlank(apiConfig.API_Key__c)) {
            throw new AuraHandledException('Gemini API Key missing.');
        }

        // ---- Build key list (same as generate) --------------------
        String allKeys = String.join(
            new List<String>{
                '=== OBJECT FIELD KEYS ===\n' + String.join(objectFieldKeys, '\n'),
                '\n=== GENERAL FIELD KEYS ===\n' + String.join(generalFieldKeys, '\n'),
                '\n=== SIGNATURE KEY ===\n' + (signatureKey?.isEmpty() ? '' : signatureKey[0])
            },
            '\n\n'
        );

        // ---- Header/footer rule for email templates ----------------
        String headerFooterRule = isForEmail
            ? '- the "header" and "footer" MUST be empty in the response\n'
            : '- the "header" and "footer" MUST be present in the response\n';

        // ---- Full prompt that includes the *current* HTML ----------
        String fullPrompt = userPrompt + '\n\n' +
            'You are a world-class HTML-email designer. **Edit** the template below **exactly** as requested.\n' +
            'Preserve **every** merge field ({{#…}}, {{Doc.…}}, {{Sign.…}}). Do **not** invent new syntax.\n' +
            headerFooterRule +
            'Return **only** valid JSON with the three sections.\n\n' +
            'CURRENT TEMPLATE (do not delete any merge fields):\n' +
            '```html\n' + currentHtml + '\n```\n\n' +
            'EXAMPLE OUTPUT:\n' +
            '{\n' +
            ' "header": "",\n' +
            ' "body": "...",\n' +
            ' "footer": ""\n' +
            '}';

        // ---- HTTP call (same as generate) -------------------------
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-09-2025:generateContent?key=' + apiConfig.API_Key__c);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(120000);

        String payload = JSON.serialize(new Map<String, Object>{
            'contents' => new List<Object>{
                new Map<String, Object>{
                    'role' => 'user',
                    'parts' => new List<Object>{ new Map<String, Object>{ 'text' => fullPrompt } }
                }
            },
            'generationConfig' => new Map<String, Object>{ 'responseMimeType' => 'application/json' }
        });
        req.setBody(payload);

        HttpResponse res = http.send(req);

        // ---- Response handling ------------------------------------
        if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> candidates = (List<Object>) result.get('candidates');
            if (candidates == null || candidates.isEmpty()) {
                throw new AuraHandledException('No response from Gemini.');
            }
            Map<String, Object> content = (Map<String, Object>) ((Map<String, Object>) candidates[0]).get('content');
            List<Object> parts = (List<Object>) content.get('parts');
            String jsonText = (String) ((Map<String, Object>) parts[0]).get('text');

            // Strip possible markdown fences
            jsonText = jsonText.replaceAll('```json|```', '').trim();

            try {
                GeminiResponse parsed = (GeminiResponse) JSON.deserialize(jsonText, GeminiResponse.class);
                // Force empty header/footer for marketing/email
                if (isForEmail) {
                    parsed.header = '';
                    parsed.footer = '';
                }
                return parsed;
            } catch (Exception e) {
                throw new AuraHandledException('Invalid JSON from Gemini: ' + e.getMessage() + '\nRaw: ' + jsonText);
            }
        } else {
            throw new AuraHandledException('Gemini API error: ' + res.getStatusCode() + ' ' + res.getBody());
        }
    }

    public class GeminiResponse {
        @AuraEnabled public String header {get;set;}
        @AuraEnabled public String body   {get;set;}
        @AuraEnabled public String footer {get;set;}
    }
}