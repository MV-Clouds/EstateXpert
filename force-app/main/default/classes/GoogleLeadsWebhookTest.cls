@IsTest
private class GoogleLeadsWebhookTest {
    
    private static final String FORM_ID = 'TEST_FORM_001';
    private static final String LEAD_ID = 'TEST_LEAD_001';

    @TestSetup
    static void setupData() {
        GoogleLeadsWebhook.MappingConfiguration firstNameMapping = new GoogleLeadsWebhook.MappingConfiguration();
        firstNameMapping.sourceType = 'google';
        firstNameMapping.googleField = 'FIRST_NAME';
        
        GoogleLeadsWebhook.MappingConfiguration lastNameMapping = new GoogleLeadsWebhook.MappingConfiguration();
        lastNameMapping.sourceType = 'google';
        lastNameMapping.googleField = 'LAST_NAME';
        
        GoogleLeadsWebhook.MappingConfiguration emailMapping = new GoogleLeadsWebhook.MappingConfiguration();
        emailMapping.sourceType = 'google';
        emailMapping.googleField = 'EMAIL';
        
        GoogleLeadsWebhook.MappingConfiguration phoneMapping = new GoogleLeadsWebhook.MappingConfiguration();
        phoneMapping.sourceType = 'google';
        phoneMapping.googleField = 'PHONE';
        
        GoogleLeadsWebhook.MappingConfiguration descriptionMapping = new GoogleLeadsWebhook.MappingConfiguration();
        descriptionMapping.sourceType = 'custom';
        descriptionMapping.customValue = 'Google Ads Lead';
        
        GoogleLeadsWebhook.FormConfiguration formConfig = new GoogleLeadsWebhook.FormConfiguration();
        formConfig.formName = 'Test Google Form';
        formConfig.mappings = new Map<String, GoogleLeadsWebhook.MappingConfiguration>{
            'FirstName'   => firstNameMapping,
            'LastName'    => lastNameMapping,
            'Email'       => emailMapping,
            'Phone'       => phoneMapping,
            'Description' => descriptionMapping
        };
        
        GoogleLeadsWebhook.AccountConfiguration accountConfig = new GoogleLeadsWebhook.AccountConfiguration();
        accountConfig.accountName = 'Test Account';
        accountConfig.loginCustomerId = '1234567890';
        accountConfig.forms = new Map<String, GoogleLeadsWebhook.FormConfiguration>{ FORM_ID => formConfig };
        
        Map<String, GoogleLeadsWebhook.AccountConfiguration> allConfigs = new Map<String, GoogleLeadsWebhook.AccountConfiguration>{ 'testAccount' => accountConfig };
        
        MVEX__Configuration_Settings__c config = new MVEX__Configuration_Settings__c(Name = GoogleLeadsWebhook.GOOGLE_MAPPING_NAME, MVEX__Fields_Data__c = JSON.serialize(allConfigs));
        
        insert config;
    }

    private static String buildValidPayload() {
        return JSON.serialize(new Map<String, Object>{
            'google_key' => GoogleLeadsWebhook.GOOGLE_SECRET,
            'form_id' => FORM_ID,
            'lead_id' => LEAD_ID,
            'gcl_id' => 'TEST_GCL_ID',
            'user_column_data' => new List<Object>{
                new Map<String, Object>{ 'column_id' => 'FIRST_NAME', 'string_value' => 'John'},
                new Map<String, Object>{ 'column_id' => 'LAST_NAME', 'string_value' => 'Doe' },
                new Map<String, Object>{ 'column_id' => 'EMAIL', 'string_value' => 'john.doe@example.com' },
                new Map<String, Object>{ 'column_id' => 'PHONE', 'string_value' => '9876543210' }
            }
        });
    }

    private static void setPostRequest(String body) {
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/Lead/';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf(body);
        
        RestContext.request = request;
        RestContext.response = new RestResponse();
    }
    
    @IsTest
    static void testHandleNotification_Success() {
        setPostRequest(buildValidPayload());
        
        Test.startTest();
        GoogleLeadsWebhook.handleNotification();
        Test.stopTest();
        
        List<Contact> contacts = [SELECT Id, FirstName, LastName, Email, Phone, Description FROM Contact WHERE Email = 'john.doe@example.com'];
        
        System.assertEquals(1, contacts.size(), 'A Contact should have been created.');
        
        Contact con = contacts[0];
        
        System.assertEquals('John', con.FirstName);
        System.assertEquals('Doe', con.LastName);
        System.assertEquals('john.doe@example.com', con.Email);
        System.assertEquals('9876543210', con.Phone);
        System.assertEquals('Google Ads Lead', con.Description);
        
        System.assertEquals(0, [SELECT COUNT() FROM MVEX__Error_Handling__c WHERE MVEX__Source_of_Error__c = :GoogleLeadsWebhook.FAILED_SOURCE], 'A successful lead should not be stored as failed.');
    }

    @IsTest
    static void testGetFormConfiguration_Found() {
        Test.startTest();
        GoogleLeadsWebhook.FormConfiguration result = GoogleLeadsWebhook.getFormConfiguration(FORM_ID);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Form configuration should be found.');
        System.assertEquals('Test Google Form', result.formName);
        System.assertEquals(5, result.mappings.size());
    }
    
    @IsTest
    static void testGetFormConfiguration_NotFound() {
        Test.startTest();
        GoogleLeadsWebhook.FormConfiguration result = GoogleLeadsWebhook.getFormConfiguration('DOES_NOT_EXIST');
        Test.stopTest();
        
        System.assertEquals(null, result, 'Unknown form should return null.');
    }

    @IsTest
    static void testBuildContact() {
        GoogleLeadsWebhook.LeadData lead = new GoogleLeadsWebhook.LeadData();
        
        lead.google_key = GoogleLeadsWebhook.GOOGLE_SECRET;
        lead.form_id = FORM_ID;
        lead.lead_id = LEAD_ID;
        
        lead.user_column_data = new List<GoogleLeadsWebhook.UserColumnData>();
        
        GoogleLeadsWebhook.UserColumnData firstName = new GoogleLeadsWebhook.UserColumnData();
        firstName.column_id = ' first-name ';
        firstName.string_value = 'Jane';
        
        GoogleLeadsWebhook.UserColumnData lastName = new GoogleLeadsWebhook.UserColumnData();
        lastName.column_id = 'LAST NAME';
        lastName.string_value = 'Smith';
        
        GoogleLeadsWebhook.UserColumnData email = new GoogleLeadsWebhook.UserColumnData();
        email.column_id = 'email';
        email.string_value = 'jane.smith@example.com';
        
        lead.user_column_data.add(firstName);
        lead.user_column_data.add(lastName);
        lead.user_column_data.add(email);
        
        GoogleLeadsWebhook.FormConfiguration config = GoogleLeadsWebhook.getFormConfiguration(FORM_ID);
        
        Test.startTest();
        Contact con = GoogleLeadsWebhook.buildContact(lead, config);
        Test.stopTest();
        
        System.assertEquals('Jane', con.FirstName);
        System.assertEquals('Smith', con.LastName);
        System.assertEquals('jane.smith@example.com', con.Email);
        
        System.assertEquals('Google Ads Lead', con.Description);
    }

    @IsTest
    static void testHandleNotification_InvalidSecret() {
        Map<String, Object> payload = (Map<String, Object>)JSON.deserializeUntyped(buildValidPayload());
        
        payload.put('google_key', 'INVALID_SECRET');
        
        setPostRequest(JSON.serialize(payload));
        
        Test.startTest();
        GoogleLeadsWebhook.handleNotification();
        Test.stopTest();
        
        System.assertEquals(0, [SELECT COUNT() FROM Contact WHERE Email = 'john.doe@example.com'], 'No Contact should be created for an invalid secret.');
    }

    @IsTest
    static void testHandleNotification_EmptyBody() {
        setPostRequest('');
        
        Test.startTest();
        GoogleLeadsWebhook.handleNotification();
        Test.stopTest();
        
        System.assertEquals(0, [SELECT COUNT() FROM Contact WHERE Email = 'john.doe@example.com']);
    }
    
    @IsTest
    static void testHandleNotification_InvalidJson() {
        setPostRequest('{INVALID JSON');
        
        Test.startTest();
        GoogleLeadsWebhook.handleNotification();
        Test.stopTest();
        
        System.assertEquals(0, [SELECT COUNT() FROM Contact WHERE Email = 'john.doe@example.com']);
    }

    @IsTest
    static void testHandleNotification_InvalidPayload() {
        String body = JSON.serialize(
            new Map<String, Object>{
                'google_key' => GoogleLeadsWebhook.GOOGLE_SECRET,
                'form_id' => null,
                'lead_id' => LEAD_ID,
                'user_column_data' => new List<Object>()
            }
        );
        
        setPostRequest(body);
        
        Test.startTest();
        GoogleLeadsWebhook.handleNotification();
        Test.stopTest();
        
        System.assertEquals(0, [SELECT COUNT() FROM Contact WHERE Email = 'john.doe@example.com']);
    }

    @IsTest
    static void testHandleNotification_NoMapping() {
        String body = JSON.serialize(
            new Map<String, Object>{
                'google_key' => GoogleLeadsWebhook.GOOGLE_SECRET,
                'form_id' => 'UNKNOWN_FORM',
                'lead_id' => 'FAILED_LEAD_001',
                'user_column_data' => new List<Object>{
                    new Map<String, Object>{
                        'column_id' => 'FIRST_NAME',
                        'string_value' => 'Test'
                    }
                }
            }
        );
        
        setPostRequest(body);
        
        Test.startTest();
        GoogleLeadsWebhook.handleNotification();
        Test.stopTest();
        
        System.assertEquals(0, [SELECT COUNT() FROM Contact WHERE FirstName = 'Test']);
        
        List<MVEX__Error_Handling__c> errors = [SELECT Id, MVEX__Class_Name__c, MVEX__Method_Name__c, MVEX__Source_of_Error__c, MVEX__Error_Body__c FROM MVEX__Error_Handling__c WHERE MVEX__Source_of_Error__c =:GoogleLeadsWebhook.FAILED_SOURCE];
        
        System.assert(errors.size() > 0, 'The failed lead should be persisted.');
        System.assert(errors[0].MVEX__Error_Body__c.contains('UNKNOWN_FORM'), 'The error should contain the form Id.');
    }

    @IsTest
    static void testSaveFailedLead() {
        String body = JSON.serialize(
            new Map<String, Object>{
                'form_id' => 'FAILED_FORM',
                'lead_id' => 'FAILED_LEAD',
                'test' => 'value'
            }
        );
        
        Test.startTest();
        
        GoogleLeadsWebhook.saveFailedLead(body, null, null, 'Test failure');
        
        Test.stopTest();
        
        List<MVEX__Error_Handling__c> errors = [SELECT Id, MVEX__Class_Name__c, MVEX__Method_Name__c, MVEX__Source_of_Error__c, MVEX__Error_Body__c FROM MVEX__Error_Handling__c WHERE MVEX__Source_of_Error__c =:GoogleLeadsWebhook.FAILED_SOURCE];
        
        System.assertEquals(1, errors.size());
        System.assertEquals('GoogleLeadsWebhook', errors[0].MVEX__Class_Name__c);
        System.assertEquals('handleNotification', errors[0].MVEX__Method_Name__c);
        System.assert(errors[0].MVEX__Error_Body__c.contains('FAILED_FORM'));
        System.assert(errors[0].MVEX__Error_Body__c.contains('Test failure'));
    }

    @IsTest
    static void testBuildContact_BlankValuesIgnored() {
        GoogleLeadsWebhook.LeadData lead = new GoogleLeadsWebhook.LeadData();
        
        lead.form_id = FORM_ID;
        
        GoogleLeadsWebhook.UserColumnData firstName = new GoogleLeadsWebhook.UserColumnData();
        
        firstName.column_id = 'FIRST_NAME';
        firstName.string_value = '   ';
        
        lead.user_column_data = new List<GoogleLeadsWebhook.UserColumnData>{ firstName };
        
        GoogleLeadsWebhook.FormConfiguration config = GoogleLeadsWebhook.getFormConfiguration(FORM_ID);
        
        Test.startTest();
        Contact con = GoogleLeadsWebhook.buildContact(lead, config);
        Test.stopTest();
        
        System.assertEquals(null, con.FirstName, 'Blank Google values should not populate fields.');
        System.assertEquals('Google Ads Lead', con.Description, 'Custom mappings should still be populated.');
    }

    @IsTest
    static void testBuildContact_InvalidSalesforceField() {
        GoogleLeadsWebhook.MappingConfiguration mapping = new GoogleLeadsWebhook.MappingConfiguration();
        
        mapping.sourceType = 'custom';
        mapping.customValue = 'Test';
        
        GoogleLeadsWebhook.FormConfiguration config = new GoogleLeadsWebhook.FormConfiguration();
        
        config.formName = 'Invalid Field Test';
        config.mappings = new Map<String, GoogleLeadsWebhook.MappingConfiguration>{ 'This_Field_Does_Not_Exist__c' => mapping };
        
        GoogleLeadsWebhook.LeadData lead = new GoogleLeadsWebhook.LeadData();
        
        lead.form_id = FORM_ID;
        lead.user_column_data = new List<GoogleLeadsWebhook.UserColumnData>();
        
        Test.startTest();
        
        Boolean exceptionThrown = false;
        
        try {
            GoogleLeadsWebhook.buildContact(lead, config);
        } catch (GoogleLeadsWebhook.LeadProcessingException e) {
            exceptionThrown = true;
            
            System.assert(e.getMessage().contains('does not exist on Contact'));
        }
        
        Test.stopTest();
        
        System.assertEquals(true, exceptionThrown, 'An invalid Contact field should throw LeadProcessingException.');
    }
    
    @IsTest
    static void testGoogleFieldNormalizationThroughBuildContact() {
        GoogleLeadsWebhook.LeadData lead = new GoogleLeadsWebhook.LeadData();
        
        lead.form_id = FORM_ID;
        
        GoogleLeadsWebhook.UserColumnData firstName = new GoogleLeadsWebhook.UserColumnData();
        
        firstName.column_id = '  first-name!!!  ';
        firstName.string_value = 'Normalized';
        
        lead.user_column_data = new List<GoogleLeadsWebhook.UserColumnData>{ firstName };
        
        GoogleLeadsWebhook.FormConfiguration config = GoogleLeadsWebhook.getFormConfiguration(FORM_ID);
        
        Test.startTest();
        Contact con = GoogleLeadsWebhook.buildContact(lead, config);
        Test.stopTest();
        
        System.assertEquals('Normalized', con.FirstName, 'Google field normalization should work.');
    }

    @IsTest
    static void testBuildContact_NullUserColumnData() {
        GoogleLeadsWebhook.LeadData lead = new GoogleLeadsWebhook.LeadData();
        
        lead.form_id = FORM_ID;
        lead.user_column_data = null;
        
        GoogleLeadsWebhook.FormConfiguration config = GoogleLeadsWebhook.getFormConfiguration(FORM_ID);
        
        Test.startTest();
        Contact con = GoogleLeadsWebhook.buildContact(lead, config);
        Test.stopTest();
        
        System.assertEquals(null, con.FirstName);
        
        System.assertEquals('Google Ads Lead', con.Description);
    }
    
    @IsTest
    static void testBuildContact_NullMapping() {
        GoogleLeadsWebhook.FormConfiguration config = new GoogleLeadsWebhook.FormConfiguration();
        
        config.formName = 'Null Mapping Test';
        config.mappings = new Map<String, GoogleLeadsWebhook.MappingConfiguration>{ 'FirstName' => null };
        
        GoogleLeadsWebhook.LeadData lead = new GoogleLeadsWebhook.LeadData();
        
        lead.form_id = FORM_ID;
        
        lead.user_column_data = new List<GoogleLeadsWebhook.UserColumnData>();
        
        Test.startTest();
        Contact con = GoogleLeadsWebhook.buildContact(lead, config);
        Test.stopTest();
        
        System.assertEquals(null, con.FirstName);
    }
    
    @IsTest
    static void testBuildContact_UnknownSourceType() {
        GoogleLeadsWebhook.MappingConfiguration mapping = new GoogleLeadsWebhook.MappingConfiguration();
        
        mapping.sourceType = 'unknown';
        mapping.googleField = 'FIRST_NAME';
        mapping.customValue = 'Should Not Be Used';
        
        GoogleLeadsWebhook.FormConfiguration config = new GoogleLeadsWebhook.FormConfiguration();
        
        config.formName = 'Unknown Source Test';
        config.mappings = new Map<String, GoogleLeadsWebhook.MappingConfiguration>{ 'FirstName' => mapping };
        
        GoogleLeadsWebhook.LeadData lead = new GoogleLeadsWebhook.LeadData();
        
        lead.form_id = FORM_ID;
        
        GoogleLeadsWebhook.UserColumnData firstName = new GoogleLeadsWebhook.UserColumnData();
        
        firstName.column_id = 'FIRST_NAME';
        firstName.string_value = 'John';
        
        lead.user_column_data = new List<GoogleLeadsWebhook.UserColumnData>{ firstName };
        
        Test.startTest();
        Contact con = GoogleLeadsWebhook.buildContact(lead, config);
        Test.stopTest();
        
        System.assertEquals(null, con.FirstName, 'Unknown source types should not resolve a value.');
    }
    
    @IsTest
    static void testDuplicateGoogleFields_LastValueWins() {
        GoogleLeadsWebhook.LeadData lead = new GoogleLeadsWebhook.LeadData();
        
        lead.form_id = FORM_ID;
        
        GoogleLeadsWebhook.UserColumnData first = new GoogleLeadsWebhook.UserColumnData();
        
        first.column_id = 'FIRST_NAME';
        first.string_value = 'First Value';
        
        GoogleLeadsWebhook.UserColumnData second = new GoogleLeadsWebhook.UserColumnData();
        
        second.column_id = 'FIRST_NAME';
        second.string_value = 'Second Value';
        
        lead.user_column_data = new List<GoogleLeadsWebhook.UserColumnData>{ first, second };
        
        GoogleLeadsWebhook.FormConfiguration config = GoogleLeadsWebhook.getFormConfiguration(FORM_ID);
        
        Test.startTest();
        Contact con = GoogleLeadsWebhook.buildContact(lead, config);
        Test.stopTest();
        
        System.assertEquals('Second Value', con.FirstName);
    }
    
    @IsTest
    static void testHandleNotification_InvalidContactFieldGetsSavedAsFailedLead() {
        
        GoogleLeadsWebhook.MappingConfiguration badMapping = new GoogleLeadsWebhook.MappingConfiguration();
        
        badMapping.sourceType = 'google';
        badMapping.googleField = 'FIRST_NAME';
        
        GoogleLeadsWebhook.FormConfiguration badForm = new GoogleLeadsWebhook.FormConfiguration();
        
        badForm.formName = 'Bad Form';
        badForm.mappings = new Map<String, GoogleLeadsWebhook.MappingConfiguration>{ 'Definitely_Not_A_Contact_Field__c' => badMapping };
        
        GoogleLeadsWebhook.AccountConfiguration account = new GoogleLeadsWebhook.AccountConfiguration();
        
        account.accountName = 'Bad Account';
        account.forms = new Map<String, GoogleLeadsWebhook.FormConfiguration>{ 'BAD_FORM_001' => badForm };
        
        Map<String, GoogleLeadsWebhook.AccountConfiguration> configMap = new Map<String, GoogleLeadsWebhook.AccountConfiguration>{ 'badAccount' => account };
        
        MVEX__Configuration_Settings__c config = [SELECT Id FROM MVEX__Configuration_Settings__c WHERE Name = :GoogleLeadsWebhook.GOOGLE_MAPPING_NAME LIMIT 1];
        
        config.MVEX__Fields_Data__c = JSON.serialize(configMap);
        
        update config;
        
        String body = JSON.serialize(
        new Map<String, Object>{
            'google_key' => GoogleLeadsWebhook.GOOGLE_SECRET,
            'form_id' => 'BAD_FORM_001',
            'lead_id' => 'BAD_LEAD_001',
            'user_column_data' => new List<Object>{
                new Map<String, Object>{
                    'column_id' => 'FIRST_NAME',
                    'string_value' => 'John'
                }
            }
        }
        );
        
        setPostRequest(body);
        
        Test.startTest();
        GoogleLeadsWebhook.handleNotification();
        Test.stopTest();
        
        System.assertEquals(0, [SELECT COUNT() FROM Contact WHERE FirstName = 'John']);
        
        List<MVEX__Error_Handling__c> errors = [SELECT Id, MVEX__Error_Body__c FROM MVEX__Error_Handling__c WHERE MVEX__Source_of_Error__c =:GoogleLeadsWebhook.FAILED_SOURCE];
        
        System.assert(errors.size() > 0, 'The failed Contact creation should be persisted.');
        System.assert(errors[0].MVEX__Error_Body__c.contains('Definitely_Not_A_Contact_Field__c'));
    }
}