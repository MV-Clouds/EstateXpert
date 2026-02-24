/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 12-16-2024
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
@IsTest
global class WhatsAppHttpMock implements HttpCalloutMock {
    global HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"messaging_product": "whatsapp", "contacts": [{"input": "1234567890", "wa_id": "1234567890"}], "messages": [{"id": "wamid.HBgLMTIzNDU2Nzg5MBUUCAsMDAwMDAwMDAwMDAwAA=="}]}');
        res.setStatusCode(200);
        return res;
    }
}