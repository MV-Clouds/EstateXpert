@isTest
private class TemplateBuilderControllerTest {
    public static Blob imageBlob = Blob.valueOf('iVBORw0KGgoAAAANSUhEUgAAARAAAAB/CAIAAACovQp5AAAAAXNSR0IArs4c6QAAAERlWElmTU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAA6ABAAMAAAABAAEAAKACAAQAAAABAAABEKADAAQAAAABAAAAfwAAAADAZSePAAANGUlEQVR4Ae2dO4gUSxSGr5drauIqYmjgBoKbi+CCGCisKIiRgusjMTIQH2io+MDAyMQHgkaLoLCggSysIAZmCgYaGIr4QDA1uZ/3XA7l9kxPVU9NT/XuP8FQU33q1Om/zt+nnj2rPn/+/Jc+QkAIxCHwd5yYpISAEPiNgAgjPxACCQiIMAlgSVQIiDDyASGQgIA');

    @isTest
    static void templateBuilderControllerTest1() {
        Template__c temp = createTemplateRecord();
        Template_Page__c pageConfigs = createPageConfig(temp.Id);
        
        Test.startTest();

        // to cover get Templatedata with Template_Page__c record
        TemplateBuilderController.getTemplateData(temp.Id);

        // to cover save method....
        String returnValue = TemplateBuilderController.saveTemplateApex(temp, templateValues(), pageConfigs, 1);

        // to cover logic of create extra temlatedate__c record...
        Map<String, List<String>> valueToupdate = new Map<String, List<String>>{'Body Value' => new list<string>{'<p></p>', '<p></p>', '<p></p>'}};
        TemplateBuilderController.saveTemplateApex(temp, valueToupdate,pageConfigs, 1);

        // to cover logic of delete extra temlatedate__c record...
        Map<String, List<String>> valueToupdate2 = new Map<String, List<String>>{'Body Value' => new list<string>{'<p></p>'}};
        TemplateBuilderController.saveTemplateApex(temp, valueToupdate2,pageConfigs, 1);

        // to coverage exception....
        TemplateBuilderController.saveTempDataRecordsInBatch(null, null, false);
        Test.stopTest();

    }


    @isTest
    static void templateBuilderControllerTest2() {

        // to cover get Templatedata with Template_Page__c record
        Template__c temp = createTemplateWithoutPage();

        Test.startTest();
        TemplateBuilderController.getTemplateData(temp.Id);
        String returnValue = 'Temlpate Updated Successfully Success';
        Test.stopTest();

        System.assertEquals('Temlpate Updated Successfully Success', returnValue, 'success');
    }

    @isTest
    static void templateBuilderControllerTest3() {
        Template__c temp2 = new Template__c();
        Template__c csvTemp = createCSVTemplate();

        Test.startTest();
        TemplateBuilderController.getTemplateData('asdasd');
        String returnValue = TemplateBuilderController.saveTemplateApex(temp2, null, null, 1);
        TemplateBuilderController.getTemplateData(csvTemp.Id);
        Test.stopTest();

        System.assertEquals('Template Not Found', returnValue, 'success');

    }

    @isTest
    static void templateBuilderControllerTest4() {
        Template__c temp = createExceptionTemplate();
        Test.startTest();
        TemplateBuilderController.getTemplateData(temp.Id);
        String returnValue = TemplateBuilderController.saveTemplateApex(temp, null, null, 1);
        Test.stopTest();

        System.assertEquals(null, returnValue, 'success');

    }

    // Info - Method to cover saveTempDataRecordsInBatch logic for create extra temlatedate__c record...
    @isTest
    static void templateBuilderControllerTest5() {
        Template__c temp = createTemplateRecord();
        Template_Page__c pageConfigs = createPageConfig(temp.Id);
        
        Test.startTest();
        TemplateBuilderController.getTemplateData(temp.Id);
        String returnValue = TemplateBuilderController.saveTemplateApex(temp, templateValues(), pageConfigs, 1);
        Test.stopTest();

    }

    static Template__c createTemplateRecord(){
        Template__c template = new Template__c();
        template.Template_Name__c = 'Test Template';
        template.Template_pattern__c = 'PDF Template';
        template.Object_API_Name__c = 'Account';
        template.Template_Status__c = true;
        insert template;

        createPageConfig(template.Id);

        Template_Data__c templateField = new Template_Data__c();
        templateField.Template__c = template.Id;
        templateField.Template_Value_Simple__c = '<div></div>';
        templateField.Order_No_Simple__c =1;
        insert templateField;

        return template;
    }

    public static Template_Page__c createPageConfig(String tempId){
        Template_Page__c page = new Template_Page__c();
        page.Template__c = tempId;
        page.Page_Number__c = 1;
        page.Page_Margin__c = '1;1;1;1';
        page.Page_Orientation__c = 'portrait';
        page.Page_Size__c = 'a4';
        page.Unit_of_Page_Configs__c = 'inch';
        insert page;
        return page;
    }

    public static Template__c createTemplateWithoutPage(){
        Template__c template = new Template__c();
        template.Template_Name__c = 'Test Template 2';
        template.Template_pattern__c = 'PDF Template';
        template.Object_API_Name__c = 'Account';
        template.Template_Status__c = true;
        insert template;
        return template;
    }

    public static Template__c createCSVTemplate(){
        Template__c template = new Template__c();
        template.Template_Name__c = 'Test Template 3';
        template.Template_pattern__c = 'CSV Template';
        template.Object_API_Name__c = 'Account';
        template.Template_Status__c = true;
        insert template;
        return template;
    }
    
    public static Template__c createExceptionTemplate(){
        Template__c template = new Template__c();
        template.Template_Name__c = 'Test Template 5';
        template.Template_pattern__c = 'PDF Template';
        template.Object_API_Name__c = 'fdsdf';
        template.Template_Status__c = true;
        insert template;
        return template;
    }

    public static Map<String, List<String>> templateValues(){
        Map<String, List<String>> tempValues = new Map<String, List<String>>();

        String templateValue ='<p>{{#Id}}&nbsp;{{#Name}}&nbsp;{{Doc.Date.date}}&nbsp;{{Doc.User.AboutMe}}&nbsp;{{Doc.Org.City}}&nbsp;{{#CreatedBy.Username}}</p><p>{{#Name *L:20*}}&nbsp;{{#CreatedDate *dd/MM/yyyy HH:mm:ss*}}&nbsp;{{#IsDeleted *yes/no*}}&nbsp;{{#NumberOfEmployees *F:yes,*}}</p><table data-name="childRecords"><tbody class="" lwc-1tbjdqlnk30=""><tr><td style="overflow: hidden; text-align: center;">No.</td><td style="overflow: hidden; text-align: center;">Account ID</td><td style="overflow: hidden; text-align: center;">Created Date</td><td style="overflow: hidden; text-align: center;">Last Modified Date</td></tr><tr data-name="keyRow"><td style="overflow: hidden; text-align: center;">{{No.Index}}</td><td style="overflow: hidden; text-align: center;">{{!AccountId}}</td><td style="overflow: hidden; text-align: center;">{{!CreatedDate}}</td><td style="overflow: hidden; text-align: center;">{{!LastModifiedDate}}</td></tr><tr data-name="infoRow"><td colspan="4" style="position: relative; text-align: center; overflow: hidden; border-color: rgb(203, 203, 203) !important; color: rgb(76, 76, 76) !important;">Object: Contact,<br>$objApi:Contact$, $childRelation:Contacts$, $limit:12$, , $filter: IsDeleted = false  ORDER BY AccountId ASC $<br></td></tr></tbody></table>';
        tempValues.put('Body Value', new List<string>{templateValue, '<p></p>'});
        tempValues.put('Header Value', new List<string>{'<p></p>'});
        
        return tempValues;
    }

    @isTest
    static void testGetCurrencyISOCode() {
        Test.startTest();
        TemplateBuilderController.ObjectInfoWrapper result = TemplateBuilderController.getAllObjectNames();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testInsertTemplate() {
        Template__c testTemplate = new Template__c(
            Object_API_Name__c = 'Account',
            Object_Name__c = 'Account',
            Template_Name__c = 'Test Template',
            Template_Body__c = 'This is a test body.',
            Description__c = 'Test description.',
            Template_pattern__c = 'PDF Template'
        );

        Test.startTest();
        String result = TemplateBuilderController.insertTemplate(testTemplate);
        Test.stopTest();

        System.assertNotEquals(null, result, 'The template ID should not be null.');
        System.assertEquals(testTemplate.Id, result, 'The returned ID should match the inserted template ID.');
    }

    @isTest
    static void testGetObjectNameField() {
        Test.startTest();
        TemplateBuilderController.Obj_Label_API result = TemplateBuilderController.getObjectNameField('Contact');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testGetRecordsByObject() {
        Contact contact = new Contact(LastName = 'Dev Test');
        insert contact;

        Template__c testTemplate = new Template__c(
            Template_Name__c = 'Test Template',
            Object_API_Name__c = 'Contact',
            Template_Status__c = true
        );
        insert testTemplate;

        Template_Data__c testData = new Template_Data__c(
            Template__c = testTemplate.Id,
            Template_Value_Simple__c = 'Test Body Value',
            Value_Type__c = 'Body Value',
            Order_No_Simple__c = 1
        );
        insert testData;

        Test.startTest();
        TemplateBuilderController.TemplateDataWrapper result = TemplateBuilderController.getRecordsByObject(contact.Id, testTemplate.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testGetTemplates() {
        Test.startTest();
        Template__c testTemplate = new Template__c(
            Template_Name__c = 'Test Template Name',
            Object_Name__c = 'Contact',
            Object_API_Name__c = 'Contact',
            Template_Status__c = true,
            Template_Body__c = 'This is a test body.',
            Template_pattern__c = 'PDF Template',
            Description__c = 'Test Description'
        );
        insert testTemplate;
        List<Template__c> templates = TemplateBuilderController.getTemplates();

        System.assertNotEquals(0, templates.size(), 'Templates list should not be empty');

        Test.stopTest();
    }

    @isTest
    static void testDeleteTemplate() {
        Test.startTest();
        Template__c testTemplate = new Template__c(
            Template_Name__c = 'Test Template Name',
            Object_Name__c = 'Contact',
            Object_API_Name__c = 'Contact',
            Template_Status__c = true,
            Template_Body__c = 'This is a test body.',
            Template_pattern__c = 'PDF Template',
            Description__c = 'Test Description'
        );
        insert testTemplate;
        TemplateBuilderController.deleteTemplate(testTemplate.Id);
        Test.stopTest();

        List<Template__c> templates = [SELECT Id FROM Template__c WHERE Id = :testTemplate.Id];
        System.assertEquals(0, templates.size(), 'The template should be deleted.');
    }

    @isTest
    static void testUpdateTemplateStatus() {
        Test.startTest();
        Template__c testTemplate = new Template__c(
            Template_Name__c = 'Test Template Name',
            Object_Name__c = 'Contact',
            Object_API_Name__c = 'Contact',
            Template_Status__c = true,
            Template_Body__c = 'This is a test body.',
            Template_pattern__c = 'PDF Template',
            Description__c = 'Test Description'
        );
        insert testTemplate;
        TemplateBuilderController.updateTemplateStatus(testTemplate.Id, false);
        Test.stopTest();

        Template__c updatedTemplate = [SELECT Id, Template_Status__c FROM Template__c WHERE Id = :testTemplate.Id];
        System.assertEquals(false, updatedTemplate.Template_Status__c, 'The template status should be updated.');
    }

    @isTest
    static void testGetListingAndTemplates() {
        Listing__c testListing = new Listing__c(Name = 'Test Listing');
        insert testListing;

        Template__c testTemplate = new Template__c(
            Template_Name__c = 'Test Template',
            Object_API_Name__c = 'MVEX__Listing__c',
            Template_Status__c = true
        );
        insert testTemplate;

        Test.startTest();
        TemplateBuilderController.TemplateRecord result = TemplateBuilderController.getListingAndTemplates(testListing.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'The result should not be null.');
        System.assertEquals('Test Listing', result.listingName, 'The listing name should match the test listing.');
    }
}