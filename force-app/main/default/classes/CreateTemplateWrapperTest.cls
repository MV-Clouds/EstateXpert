@isTest
public class CreateTemplateWrapperTest {

    @isTest
    static void testStaticMarketingPayload() {
        CreateTemplateWrapper.TemplateWrapper templateWrapper = new CreateTemplateWrapper.TemplateWrapper(); 
        templateWrapper.templateName = 'WB Template';
        templateWrapper.tempLanguage = 'en';
        templateWrapper.templateCategory = 'Marketing';
        templateWrapper.templateType = 'Custom';
        templateWrapper.headAlternateTexts = new List<String>{'Sender Name'};
        templateWrapper.varAlternateTexts = new List<String>{'Recipient Name', 'Phone'};
        templateWrapper.templateBody = 'Hello {{1}}, This is an invitation for the annual event for 8 years of journey. Contact us for more details: {{2}}';
        templateWrapper.marketingOptText = 'Quick reply';

        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setBody('{"success": true}');

        Map<String, Object> payload = new Map<String, Object>{
            'category' => 'Marketing',
            'language' => 'en_US',
            'name' => 'test_temp_55',
            'components' => new List<Map<String, Object>>{
                new Map<String, Object>{
                    'type' => 'HEADER',
                    'format' => 'TEXT',
                    'text' => 'Event by {{1}}',
                    'example' => new Map<String, Object>{
                        'header_text' => new List<Object>{'{{Contact.Email}}'}
                    }
                },
                new Map<String, Object>{
                    'type' => 'BODY',
                    'text' => 'Hello {{1}}, This is an invitation for the annual event for 8 years of journey. Contact us for more details: {{2}}',
                    'example' => new Map<String, Object>{
                        'body_text' => new List<List<String>>{
                            new List<String>{'{{Contact.Name}}', '{{Contact.Phone}}'}
                        }
                    }
                },
                new Map<String, Object>{
                    'type' => 'FOOTER',
                    'text' => 'MV Clouds Pvt Ltd'
                },
                new Map<String, Object>{
                    'type' => 'BUTTONS',
                    'buttons' => new List<Map<String, Object>>{
                        new Map<String, Object>{
                            'type' => 'QUICK_REPLY',
                            'text' => 'Quick reply'
                        }
                    }
                }
            }
        };

        Map<String, Object> response = new Map<String, Object>{
            'success' => 'true',
            'id' => 'someMarketingId'
        };

        // Call method
        Test.startTest();
        Id templateId = CreateTemplateWrapper.handleSuccessResponse('someMarketingId', 'APPROVED', payload, templateWrapper);
        Test.stopTest();
    }

    @isTest
    static void testStaticAuthPayload() {
        CreateTemplateWrapper.TemplateWrapper templateWrapper = new CreateTemplateWrapper.TemplateWrapper(); 
        templateWrapper.templateName = 'Auth Template';
        templateWrapper.tempLanguage = 'en';
        templateWrapper.templateCategory = 'Authentication';
        templateWrapper.templateType = 'One-time passcode';
        templateWrapper.expireTime = 301;
        templateWrapper.templateBody = 'Hello {{1}}, Please use the following OTP for verification: {{2}}';
        templateWrapper.headAlternateTexts = new List<String>{'Header Email'};
        templateWrapper.varAlternateTexts = new List<String>{'Contact Name', 'OTP Code'};

        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setBody('{"success": true}');

        Map<String, Object> payload = new Map<String, Object>{
            'category' => 'Authentication',
            'language' => 'en_US',
            'name' => 'auth_template_001',
            'components' => new List<Map<String, Object>>{
                new Map<String, Object>{
                    'type' => 'HEADER',
                    'format' => 'TEXT',
                    'text' => 'Event by {{1}}',
                    'example' => new Map<String, Object>{
                        'header_text' => new List<Object>{'{{Contact.Email}}'}
                    }
                },
                new Map<String, Object>{
                    'type' => 'BODY',
                    'text' => 'Hello {{1}}, Please use the following OTP for verification: {{2}}',
                    'example' => new Map<String, Object>{
                        'body_text' => new List<List<String>>{
                            new List<String>{'{{Contact.Name}}', '{{Contact.OTP}}'}
                        }
                    }
                },
                new Map<String, Object>{
                    'type' => 'FOOTER',
                    'text' => 'Secure Login - WB'
                },
                new Map<String, Object>{
                    'type' => 'BUTTONS',
                    'buttons' => new List<Map<String, Object>>{
                        new Map<String, Object>{
                            'type' => 'OTP',
                            'text' => 'Verify Code',
                            'otp_type' => 'COPY_CODE'
                        }
                    }
                }
            }
        };

        Map<String, Object> response = new Map<String, Object>{
            'success' => 'true',
            'id' => 'auth_template_001'
        };

        Test.startTest();
        Id templateId = CreateTemplateWrapper.handleSuccessResponse('auth_template_001', 'APPROVED', payload, templateWrapper);
        Test.stopTest();
    }
}