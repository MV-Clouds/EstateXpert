@isTest
public class CreateActivityFromMailTest {

    @testSetup
    static void setupTestData() {
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'testuser@example.com'
        );
        insert testContact;
    }

    @isTest
    static void testEmailMessageInserted() {
        // Arrange
        Contact contact = [SELECT Id, Email FROM Contact LIMIT 1];
        String base64Content = EncodingUtil.base64Encode(Blob.valueOf('PDF file content'));

        Map<String, String> emailInfo = new Map<String, String>{
            'email' => contact.Email,
            'cc' => 'cc@example.com',
            'bcc' => 'bcc@example.com',
            'subject' => 'Email Subject',
            'body' => '<p>Hello Email</p>',
            'attachmentName' => 'sample.pdf',
            'attachmentContent' => base64Content
        };
        Map<String, Map<String, String>> emailMap = new Map<String, Map<String, String>>{
            contact.Id => emailInfo
        };

        // Act
        Test.startTest();
        CreateActivityFromMail2.createCaseEmailMessage(emailMap);
        Test.stopTest();

        // Assert 1: EmailMessage inserted
        Integer emailCount = [SELECT COUNT() FROM EmailMessage WHERE Contact_ID__c = :contact.Id];
        System.assertEquals(1, emailCount, 'Should insert 1 EmailMessage');
    }

    @isTest
    static void testAttachmentInserted() {
        // Arrange
        Contact contact = [SELECT Id, Email FROM Contact LIMIT 1];
        String base64Content = EncodingUtil.base64Encode(Blob.valueOf('Attachment content'));

        Map<String, String> emailInfo = new Map<String, String>{
            'email' => contact.Email,
            'cc' => '',
            'bcc' => '',
            'subject' => 'With Attachment',
            'body' => 'Test body',
            'attachmentName' => 'Attachment.pdf',
            'attachmentContent' => base64Content
        };
        Map<String, Map<String, String>> emailMap = new Map<String, Map<String, String>>{
            contact.Id => emailInfo
        };

        // Act
        Test.startTest();
        CreateActivityFromMail2.createCaseEmailMessage(emailMap);
        Test.stopTest();

        // Assert 2: Attachment inserted
        Integer attachmentCount = [SELECT COUNT() FROM Attachment WHERE ParentId = :contact.Id];
        System.assertEquals(1, attachmentCount, 'Should insert 1 Attachment');
    }

    @isTest
    static void testEmailMessageRelationInserted() {
        // Arrange
        Contact contact = [SELECT Id, Email FROM Contact LIMIT 1];
        String base64Content = EncodingUtil.base64Encode(Blob.valueOf('Some content'));

        Map<String, String> emailInfo = new Map<String, String>{
            'email' => contact.Email,
            'cc' => '',
            'bcc' => '',
            'subject' => 'With Relation',
            'body' => 'Test',
            'attachmentName' => 'Test.pdf',
            'attachmentContent' => base64Content
        };
        Map<String, Map<String, String>> emailMap = new Map<String, Map<String, String>>{
            contact.Id => emailInfo
        };

        // Act
        Test.startTest();
        CreateActivityFromMail2.createCaseEmailMessage(emailMap);
        Test.stopTest();

        // Assert 3: EmailMessageRelation inserted
        Integer relationCount = [SELECT COUNT() FROM EmailMessageRelation WHERE RelationId = :contact.Id];
        System.assertEquals(1, relationCount, 'Should insert 1 EmailMessageRelation');
    }

    @isTest
    static void testNoAttachmentWhenNotProvided() {
        // Arrange
        Contact contact = [SELECT Id, Email FROM Contact LIMIT 1];

        Map<String, String> emailInfo = new Map<String, String>{
            'email' => contact.Email,
            'subject' => 'No Attachment',
            'body' => 'No file here'
            // No attachmentName or attachmentContent
        };
        Map<String, Map<String, String>> emailMap = new Map<String, Map<String, String>>{
            contact.Id => emailInfo
        };

        // Act
        Test.startTest();
        CreateActivityFromMail2.createCaseEmailMessage(emailMap);
        Test.stopTest();

        // Assert 4: No attachment inserted
        Integer attachmentCount = [SELECT COUNT() FROM Attachment WHERE ParentId = :contact.Id];
        System.assertEquals(0, attachmentCount, 'Should insert 0 Attachments');
    }

}