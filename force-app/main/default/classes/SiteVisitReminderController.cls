public with sharing class SiteVisitReminderController {
     @InvocableMethod(label='Send Showing Reminder' description='Sends WhatsApp reminder for showing')
    public static void sendShowingReminders(List<Id> showingIds) {
        for(Id showingId : showingIds){
            sendShowingReminder(showingId);
        }
    }

    private static void sendShowingReminder(String showingId) {
        try {
            Showing__c showing = [SELECT Id, Buyer__c, Buyer__r.Phone, Listing__c, Scheduled_Date__c, Status__c 
                                FROM Showing__c WHERE Id = :showingId WITH USER_MODE];
            if (showing.Buyer__r.Phone == null || showing.Status__c != 'Scheduled') {
                return;
            }

            WhatsappTemplate__c temp = [SELECT Id, Template_Name__c, Language__c, Header_Type__c, WBHeader_Body__c, 
                                        WBTemplate_Body__c, WBFooter_Body__c, WBButton_Body__c, Button_Type__c, 
                                        Button_Label__c, Template_Category__c 
                                        FROM WhatsappTemplate__c WHERE Template_SubCatagory__c = 'Reminder' WITH USER_MODE LIMIT 1];
            if (temp == null) {
                return;
            }
            String templateId = temp.Id;

            Map<String, Object> templateDataMap = ChatWindowController.getTemplateData(templateId, showingId, 'Showing__c');
            if (templateDataMap == null) {
                return;
            }

            WhatsappTemplate__c template = (WhatsappTemplate__c)templateDataMap.get('template');
            List<String> headerParams = new List<String>();
            List<String> bodyParams = new List<String>();

            if (templateDataMap.get('headerParams') != null) {
                for (Object param : (List<Object>)templateDataMap.get('headerParams')) {
                    headerParams.add(String.valueOf(param));
                }
            }
            if (templateDataMap.get('bodyParams') != null) {
                for (Object param : (List<Object>)templateDataMap.get('bodyParams')) {
                    bodyParams.add(String.valueOf(param));
                }
            }

            Chat__c chat = new Chat__c(
                Phone__c = showing.Buyer__r.Phone,
                Type_of_Message__c = 'OutBound Messages',
                Message_Status__c = null,
                Message_Type__c = 'Template',
                WhatsappTemplate__c = templateId
            );
            insert as user chat;

            String buttonValueStr = template.WBButton_Body__c != null ? template.WBButton_Body__c : '[]';
            List<Object> buttonValue = (List<Object>)JSON.deserializeUntyped(buttonValueStr);

            Map<String, Object> data = new Map<String, Object>{
                'templateName' => template.Template_Name__c,
                'languageCode' => template.Language__c,
                'headerImageURL' => template.WBHeader_Body__c,
                'headerType' => template.Header_Type__c,
                'headerParameters' => headerParams,
                'bodyParameters' => bodyParams,
                'buttonLabel' => template.Button_Label__c != null ? template.Button_Label__c : '',
                'buttonType' => template.Button_Type__c != null ? template.Button_Type__c : '',
                'buttonValue' => buttonValue,
                'templateCategory' => template.Template_Category__c
            };

            String jsonData = createJSONBody(showing.Buyer__r.Phone, 'template', data);

            // Call future method to handle the callout
            sendWhatsAppMessageFuture(jsonData, chat.Id, showingId);

            update as user showing;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'SiteAndBookingController', 'sendShowingReminder', e.getMessage());
        }
    }

    private static String createJSONBody(String to, String type, Map<String, Object> data) {
        try {
            Integer randomCode = Integer.valueOf(Math.floor(Math.random() * 900000) + 100000);
            String randomCodeStr = String.valueOf(randomCode);

            Map<String, Object> payload = new Map<String, Object>{
                'messaging_product' => 'whatsapp',
                'to' => to,
                'type' => type,
                'template' => new Map<String, Object>{
                    'name' => data.get('templateName'),
                    'language' => new Map<String, Object>{
                        'code' => data.get('languageCode')
                    }
                }
            };

            List<Object> components = new List<Object>();

            // Safely convert headerParameters to List<String>
            List<String> headerParameters = new List<String>();
            if (data.get('headerParameters') != null) {
                for (Object param : (List<Object>)data.get('headerParameters')) {
                    headerParameters.add(String.valueOf(param));
                }
            }

            if (!headerParameters.isEmpty()) {
                List<Object> headerParams = new List<Object>();
                for (String param : headerParameters) {
                    headerParams.add(new Map<String, Object>{'type' => 'text', 'text' => param});
                }
                components.add(new Map<String, Object>{'type' => 'header', 'parameters' => headerParams});
            }

            String headerType = (String)data.get('headerType');
            String headerImageURL = (String)data.get('headerImageURL');
            if (headerType != null && headerImageURL != null) {
                String paramType = headerType.toLowerCase();
                if (paramType == 'image' || paramType == 'video' || paramType == 'document') {
                    Map<String, Object> mediaMap = new Map<String, Object>{'link' => headerImageURL};
                    Map<String, Object> param = new Map<String, Object>{'type' => paramType, paramType => mediaMap};
                    components.add(new Map<String, Object>{'type' => 'header', 'parameters' => new List<Object>{param}});
                }
            }

            // Safely convert bodyParameters to List<String>
            List<String> bodyParameters = new List<String>();
            if (data.get('bodyParameters') != null) {
                for (Object param : (List<Object>)data.get('bodyParameters')) {
                    bodyParameters.add(String.valueOf(param));
                }
            }

            if (!bodyParameters.isEmpty()) {
                List<Object> bodyParams = new List<Object>();
                for (String param : bodyParameters) {
                    bodyParams.add(new Map<String, Object>{'type' => 'text', 'text' => param});
                }
                components.add(new Map<String, Object>{'type' => 'body', 'parameters' => bodyParams});
            } else if ('Authentication' == (String)data.get('templateCategory')) {
                components.add(new Map<String, Object>{'type' => 'body', 'parameters' => new List<Object>{new Map<String, Object>{'type' => 'text', 'text' => randomCodeStr}}});
            }

            List<Object> buttonValue = (List<Object>)data.get('buttonValue');
            if (buttonValue != null && !buttonValue.isEmpty()) {
                for (Integer index = 0; index < buttonValue.size(); index++) {
                    Map<String, Object> button = (Map<String, Object>)buttonValue.get(index);
                    String btnType = (String)button.get('type');
                    if (btnType == null) continue;
                    btnType = btnType.toUpperCase();

                    Map<String, Object> buttonComponent = new Map<String, Object>{
                        'type' => 'button',
                        'index' => index
                    };

                    List<Object> parameters = new List<Object>();

                    if (btnType == 'PHONE_NUMBER') {
                        buttonComponent.put('sub_type', 'voice_call');
                        parameters.add(new Map<String, Object>{'type' => 'text', 'text' => (String)button.get('phone_number')});
                    } else if (btnType == 'URL') {
                        buttonComponent.put('sub_type', 'url');
                        parameters.add(new Map<String, Object>{'type' => 'text', 'text' => (String)button.get('text')});
                    } else if (btnType == 'QUICK_REPLY') {
                        buttonComponent.put('sub_type', 'quick_reply');
                    } else if (btnType == 'FLOW') {
                        buttonComponent.put('sub_type', 'flow');
                        parameters.add(new Map<String, Object>{'type' => 'payload', 'payload' => 'PAYLOAD'});
                    } else if (btnType == 'COPY_CODE' || btnType == 'COUPON_CODE') {
                        buttonComponent.put('sub_type', 'copy_code');
                        parameters.add(new Map<String, Object>{'type' => 'coupon_code', 'coupon_code' => (String)button.get('example')});
                    } else if (btnType == 'OTP') {
                        if (((String)button.get('otp_type')).toUpperCase() == 'COPY_CODE') {
                            buttonComponent.put('sub_type', 'url');
                            parameters.add(new Map<String, Object>{'type' => 'text', 'text' => randomCodeStr});
                        }
                    }

                    if (!parameters.isEmpty()) {
                        buttonComponent.put('parameters', parameters);
                    }
                    components.add(buttonComponent);
                }
            }

            if (!components.isEmpty()) {
                ((Map<String, Object>)payload.get('template')).put('components', components);
            }

            return JSON.serialize(payload);
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'SiteAndBookingController', 'createJSONBody', e.getMessage());
            return null;
        }
    }

    @future(callout=true)
    public static void sendWhatsAppMessageFuture(String jsonData, String chatId, String showingId) {
        try {
            SiteAndBookingController.sendWhatsappMessage(jsonData, chatId, showingId, 'Scheduled');
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'SiteAndBookingController', 'sendWhatsAppMessageFuture', e.getMessage());
        }
    }
}