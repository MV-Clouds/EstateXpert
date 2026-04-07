@IsTest(isParallel=false)
public class SupportRequestControllerTest {
    private static ContentVersion createTestContentVersion(String extension) {
        String uniqueToken = String.valueOf(DateTime.now().getTime()) + '_' + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        ContentVersion contentVersion = new ContentVersion();
        contentVersion.Title = 'Test_Document_' + uniqueToken;
        contentVersion.PathOnClient = 'TestPath_' + uniqueToken + '.' + extension;
        contentVersion.VersionData = Blob.valueOf('Test Data ' + uniqueToken);
        contentVersion.IsMajorVersion = true;
        return contentVersion;
    }

    @IsTest
    static void testSendEmailSuccess() {
        // Setup test data
        String name = 'Test User';
        String email = 'testuser@example.com';
        String subject = 'Test Subject';
        String body = 'Test Body';
        String priority = 'High';

        // Create a ContentVersion for testing
        ContentVersion contentVersion = createTestContentVersion('png');
        insert contentVersion;

        // Retrieve the ContentDocumentId from the inserted ContentVersion
        ContentVersion insertedContentVersion = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :contentVersion.Id LIMIT 1];
        System.assertNotEquals(null, insertedContentVersion, 'ContentVersion should be inserted successfully');
        List<String> contentDocumentIds = new List<String>{insertedContentVersion.ContentDocumentId};

        // Test method
        Test.startTest();
        SupportRequestController.EmailResponse response = SupportRequestController.sendEmail(name, email, subject, body, priority, contentDocumentIds);
        Test.stopTest();
    }

    @IsTest
    static void testSendEmailSuccess1() {
        // Setup test data
        String name = 'Test User';
        String email = 'testuser@example.com';
        String subject = 'Test Subject';
        String body = 'Test Body';
        String priority = 'High';

        // Create a ContentVersion for testing
        ContentVersion contentVersion = createTestContentVersion('jpg');
        insert contentVersion;

        // Retrieve the ContentDocumentId from the inserted ContentVersion
        ContentVersion insertedContentVersion = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :contentVersion.Id LIMIT 1];
        System.assertNotEquals(null, insertedContentVersion, 'ContentVersion should be inserted successfully');
        List<String> contentDocumentIds = new List<String>{insertedContentVersion.ContentDocumentId};

        // Test method
        Test.startTest();
        SupportRequestController.EmailResponse response = SupportRequestController.sendEmail(name, email, subject, body, priority, contentDocumentIds);
        Test.stopTest();
    }

    @IsTest
    static void testSendEmailSuccess2() {
        // Setup test data
        String name = 'Test User';
        String email = 'testuser@example.com';
        String subject = 'Test Subject';
        String body = 'Test Body';
        String priority = 'High';

        // Create a ContentVersion for testing
        ContentVersion contentVersion = createTestContentVersion('webp');
        insert contentVersion;

        // Retrieve the ContentDocumentId from the inserted ContentVersion
        ContentVersion insertedContentVersion = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :contentVersion.Id LIMIT 1];
        System.assertNotEquals(null, insertedContentVersion, 'ContentVersion should be inserted successfully');
        List<String> contentDocumentIds = new List<String>{insertedContentVersion.ContentDocumentId};

        // Test method
        Test.startTest();
        SupportRequestController.EmailResponse response = SupportRequestController.sendEmail(name, email, subject, body, priority, contentDocumentIds);
        Test.stopTest();
    }

    @IsTest
    static void testDeleteContentVersion() {
        // Create a ContentVersion for testing
        ContentVersion contentVersion = createTestContentVersion('png');
        insert contentVersion;

        // Retrieve the ContentDocumentId from the inserted ContentVersion
        ContentVersion insertedContentVersion = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :contentVersion.Id LIMIT 1];
        System.assertNotEquals(null, insertedContentVersion, 'ContentVersion should be inserted successfully');
        List<String> contentDocumentIds = new List<String>{insertedContentVersion.ContentDocumentId};

        // Test method
        Test.startTest();
        SupportRequestController.deleteContentVersion(contentDocumentIds);
        Test.stopTest();

        // Assert the deletion
        List<ContentDocument> docs = [SELECT Id FROM ContentDocument WHERE Id IN :contentDocumentIds];
        System.assertEquals(0, docs.size(), 'ContentDocument should be deleted');
    }

    @IsTest
    static void testDeleteContentDocument() {
        // Create a ContentVersion for testing
        ContentVersion contentVersion = createTestContentVersion('png');
        insert contentVersion;

        // Retrieve the ContentDocumentId from the inserted ContentVersion
        ContentVersion insertedContentVersion = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :contentVersion.Id LIMIT 1];
        System.assertNotEquals(null, insertedContentVersion, 'ContentVersion should be inserted successfully');

        // Test method
        Test.startTest();
        SupportRequestController.deleteContentDocument(insertedContentVersion.ContentDocumentId);
        Test.stopTest();

        // Assert the deletion
        List<ContentDocument> docs = [SELECT Id FROM ContentDocument WHERE Id = :insertedContentVersion.ContentDocumentId];
        System.assertEquals(0, docs.size(), 'ContentDocument should be deleted');
    }
}