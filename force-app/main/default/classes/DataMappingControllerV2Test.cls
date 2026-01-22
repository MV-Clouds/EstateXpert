@isTest
private class DataMappingControllerV2Test {

    public static Blob imageBlob = Blob.valueOf('iVBORw0KGgoAAAANSUhEUgAAARAAAAB/CAIAAACovQp5AAAAAXNSR0IArs4c6QAAAERlWElmTU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAA6ABAAMAAAABAAEAAKACAAQAAAABAAABEKADAAQAAAABAAAAfwAAAADAZSePAAANGUlEQVR4Ae2dO4gUSxSGr5drauIqYmjgBoKbi+CCGCisKIiRgusjMTIQH2io+MDAyMQHgkaLoLCggSysIAZmCgYaGIr4QDA1uZ/3XA7l9kxPVU9NT/XuP8FQU33q1Om/zt+nnj2rPn/+/Jc+QkAIxCHwd5yYpISAEPiNgAgjPxACCQiIMAlgSVQIiDDyASGQgIA');

    @isTest
    static void Test1() {
        List<String> tempIds = new List<String>{
            createTemplateRecord().Id
        };

        String accountId = createAccountRecord().Id;

        Test.startTest();
        map<String, Map<String, String>> returnValue = DataMappingControllerV2.getMappingsKeyValues(tempIds, accountId, true);
        Test.stopTest();

        System.assertEquals(4, returnValue.size());
    }

    @isTest 
    static void converExceptions(){

        List<String> tempIds = new List<String>{
            templateRecordException().Id
        };

        String accountId = createAccountRecord().Id;
        
        Test.startTest();
        map<String, Map<String, String>> returnValue =  DataMappingControllerV2.getMappingsKeyValues(tempIds, accountId, true);
        Test.stopTest();

        System.assertEquals(4, returnValue.size());
    }
    

    static Template__c createTemplateRecord(){
        Template__c template = new Template__c();
        template.Template_Name__c = 'Test Template';
        template.Template_pattern__c = 'PDF Template';
        template.Object_API_Name__c = 'Account';
        template.Template_Status__c = true;
        insert template;

        Template_Page__c page = new Template_Page__c();
        page.Template__c = template.Id;
        page.Page_Number__c = 1;
        page.Page_Margin__c = '1;1;1;1';
        page.Page_Orientation__c = 'portrait';
        page.Page_Size__c = 'a4';
        page.Unit_of_Page_Configs__c = 'inch';
        insert page;

        String templateValue = templateValue();
        
        Template_Data__c templateField = new Template_Data__c();
        templateField.Template__c = template.Id;
        templateField.Value_Type__c	= 'Body Value';
        templateField.Template_Value_Simple__c = templateValue;
        templateField.Order_No_Simple__c =1;
        insert templateField;

        Template_Data__c templateField2 = new Template_Data__c();
        templateField2.Template__c = template.Id;
        templateField2.Value_Type__c	= 'Extracted Mapping Keys';
        templateField2.Template_Value_Simple__c = extractedKey();
        templateField2.Order_No_Simple__c =2;
        insert templateField2;

        return template;
    }

    static Template__c templateRecordException(){
        Template__c template = new Template__c();
        template.Template_Name__c = 'Test Template';
        template.Template_pattern__c = 'PDF Template';
        template.Object_API_Name__c = 'Account';
        template.Template_Status__c = true;
        insert template;

        Template_Data__c templateField2 = new Template_Data__c();
        templateField2.Template__c = template.Id;
        templateField2.Value_Type__c	= 'Extracted Mapping Keys';
        templateField2.Template_Value_Simple__c = '[{name : sfasf}]';
        templateField2.Order_No_Simple__c =2;
        insert templateField2;

        return template;
    }

    public static Template__c createMergeTemplate(){
        Template__c template = new Template__c();
        template.Template_Name__c = 'Test Template 2';
        template.Template_pattern__c = 'PDF Template';
        template.Object_API_Name__c = 'Account';
        template.Template_Status__c = true;
        insert template;

        Template_Data__c templateField = new Template_Data__c();
        templateField.Template__c = template.Id;
        templateField.Template_Value_Simple__c = 'test data 1234';
        templateField.Order_No_Simple__c =1;
        insert templateField;

        return template;
    }

    public static Template__c createMergeTemplateInActive(){
        Template__c template = new Template__c();
        template.Template_Name__c = 'Test Template 3';
        template.Template_pattern__c = 'PDF Template';
        template.Object_API_Name__c = 'Account';
        template.Template_Status__c = false;
        insert template;

        return template;
    }

    public static Template__c createMergeTemplateCSV(){
        Template__c template = new Template__c();
        template.Template_Name__c = 'Test Template 4';
        template.Template_pattern__c = 'CSV Template';
        template.Object_API_Name__c = 'Account';
        template.Template_Status__c = false;
        insert template;

        return template;
    }

    static Account createAccountRecord(){
        Account acc = new Account();
        acc.Name = 'test Account';
        acc.NumberOfEmployees  = 12;
        insert acc;

        List<Contact> childContacts = new List<Contact>();
        for(Integer i = 1; i < 10; i++){
            childContacts.add(createContact(i, acc.Id));
        }
        insert childContacts;

        return acc;
    }

    public static Contact createContact(Integer i, String accId){
        Contact con = new contact();
        con.lastName = 'test contact' + i;
        con.accountId = accId;
        return con;
    }

    public static ContentVersion createContentVersion(){
        ContentVersion cv = new ContentVersion();
        cv.Title = 'test image';
        cv.PathOnClient = 'test image.png';
        cv.VersionData = imageBlob;
        insert cv;

        return cv;
    }

    public static String createContentDistributuion(){

        ContentDistribution cd = new ContentDistribution(
            ContentVersionId = createContentVersion().Id,
            Name =  createContentVersion().Title
        );

        insert cd;

        return cd.ContentDownloadUrl;
    }

    public static string templateValue(){
        String mergeTempId = createMergeTemplate().Id;
        String inActiveMergeTempId = createMergeTemplateInActive().Id;
        String csvMergeTempId = createMergeTemplateCSV().Id;
        String contentDownloadUrl = createContentDistributuion();
        String orgDomain = URL.getOrgDomainURL().toExternalForm();
        String orgHost = orgDomain.substringBefore('.');

        String templateValue ='<p>{{#Id}}&nbsp;{{#Name}}&nbsp;{{Doc.Date.date}}&nbsp;{{Doc.User.AboutMe}}&nbsp;{{Doc.Org.City}}&nbsp;{{#CreatedBy.Username}}</p><p>{{#Name *L:20*}}&nbsp;{{#CreatedDate *dd/MM/yyyy HH:mm:ss*}}&nbsp;{{#IsDeleted *yes/no*}}&nbsp;{{#NumberOfEmployees *F:yes,*}}</p><table data-name="childRecords"><tbody class="" lwc-1tbjdqlnk30=""><tr><td style="overflow: hidden; text-align: center;">No.</td><td style="overflow: hidden; text-align: center;">Account ID</td><td style="overflow: hidden; text-align: center;">Created Date</td><td style="overflow: hidden; text-align: center;">Last Modified Date</td></tr><tr data-name="keyRow"><td style="overflow: hidden; text-align: center;">{{No.Index}}</td><td style="overflow: hidden; text-align: center;">{{!AccountId}}</td><td style="overflow: hidden; text-align: center;">{{!CreatedDate}}</td><td style="overflow: hidden; text-align: center;">{{!LastModifiedDate}}</td></tr><tr data-name="infoRow"><td colspan="4" style="position: relative; text-align: center; overflow: hidden; border-color: rgb(203, 203, 203) !important; color: rgb(76, 76, 76) !important;">Object: Contact,<br>$objApi:Contact$, $childRelation:Contacts$, $limit:12$, , $filter: WHERE IsDeleted = false  ORDER BY AccountId ASC $<br></td></tr></tbody></table>';
        templateValue += '{{Doc.Temp.'+mergeTempId+' *test merge temp*'+'}}';
        templateValue += '{{Doc.Temp.'+inActiveMergeTempId+' *test merge temp*'+'}}';
        templateValue += '{{Doc.Temp.'+csvMergeTempId+' *test merge temp*'+'}}';
        templateValue += '<img src="'+orgHost+contentDownloadUrl+'" data-origin="sf" style="width: 75%;">';
        return templateValue;
    }

    public static string extractedKey(){
        String key = '{\"objectFields\":[\"{{#Id}}\",\"{{#Name}}\",\"{{#CreatedBy.Username}}\",\"{{#Name *L:20*}}\",\"{{#CreatedDate *dd/MM/yyyy HH:mm:ss*}}\",\"{{#IsDeleted *yes/no*}}\",\"{{#NumberOfEmployees *F:yes,*}}\"],\"generalFields\":[\"{{Doc.Date.date}}\",\"{{Doc.User.AboutMe}}\",\"{{Doc.Org.City}}\"],\"mergeTempKeys\":[\"{{Temp.a09H3000000O5RbIAK *Demo temp*}}\"],\"childRecordTables\":[{\"tableHTML\":\"<table data-name=\\\"childRecords\\\"><tbody class=\\\"\\\"><tr><td style=\\\"overflow: hidden; text-align: center;\\\">No.</td><td style=\\\"overflow: hidden; text-align: center;\\\">Account ID</td><td style=\\\"overflow: hidden; text-align: center;\\\">Created Date</td><td style=\\\"overflow: hidden; text-align: center;\\\">Last Modified Date</td></tr><tr data-name=\\\"keyRow\\\"><td style=\\\"overflow: hidden; text-align: center;\\\">{{No.Index}}</td><td style=\\\"overflow: hidden; text-align: center;\\\">{{!AccountId}}</td><td style=\\\"overflow: hidden; text-align: center;\\\">{{!CreatedDate}}</td><td style=\\\"overflow: hidden; text-align: center;\\\">{{!LastModifiedDate}}</td></tr><tr data-name=\\\"infoRow\\\"><td colspan=\\\"4\\\" style=\\\"position: relative; text-align: center; overflow: hidden; border-color: rgb(203, 203, 203) !important; color: rgb(76, 76, 76) !important;\\\">Object: Contact,<br>$objApi:Contact$, $childRelation:Contacts$, $limit:12$, , $filter: WHERE IsDeleted = false  ORDER BY AccountId ASC $<br></td></tr></tbody></table>\",\"keyRow\":\"<tr data-name=\\\"keyRow\\\"><td style=\\\"overflow: hidden; text-align: center;\\\">{{No.Index}}</td><td style=\\\"overflow: hidden; text-align: center;\\\">{{!AccountId}}</td><td style=\\\"overflow: hidden; text-align: center;\\\">{{!CreatedDate}}</td><td style=\\\"overflow: hidden; text-align: center;\\\">{{!LastModifiedDate}}</td></tr>\",\"infoRow\":\"<tr data-name=\\\"infoRow\\\"><td colspan=\\\"4\\\" style=\\\"position: relative; text-align: center; overflow: hidden; border-color: rgb(203, 203, 203) !important; color: rgb(76, 76, 76) !important;\\\">Object: Contact,<br>$objApi:Contact$, $childRelation:Contacts$, $limit:12$, , $filter: WHERE IsDeleted = false  ORDER BY AccountId ASC $<br></td></tr>\",\"mappingFields\":[\"{{!AccountId}}\",\"{{!CreatedDate}}\",\"{{!LastModifiedDate}}\"]}],\"signatureKeys\":[\"{{Sign.DocGenius *Signature Key*}}\"],\"salesforceImages\":[\"https://sanrafael-module-4006-dev-ed.scratch.file.force.com/sfc/dist/version/download/?oid=00DH300000017YT&ids=068H30000005jnn&d=%2Fa%2FH3000000L2eg%2FjTUXdIXBeYL1pXuV21e5ks7HNe9148cT5ERU4e1yahw&asPdf=false\"]}';
        return key;
    }
}