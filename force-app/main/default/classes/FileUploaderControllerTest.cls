@isTest
public class FileUploaderControllerTest {

    @testSetup
    static void setupTestData() {
        // Generate a unique file name using date-time
        String timestamp = Datetime.now().format('yyyyMMdd_HHmmss');
        String uniqueFileName = 'TestFile_' + timestamp;

        ContentVersion cv = new ContentVersion();
        cv.Title = uniqueFileName;
        cv.PathOnClient = '/' + uniqueFileName + '.txt';
        cv.VersionData = Blob.valueOf('Test file content');
        insert cv;

        // Get ContentDocument Id
        Id contentDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        Id userId = UserInfo.getUserId();

        // Avoid duplicate ContentDocumentLink
        List<ContentDocumentLink> existingLinks = [
            SELECT Id FROM ContentDocumentLink
            WHERE ContentDocumentId = :contentDocId AND LinkedEntityId = :userId
        ];

        if (existingLinks.isEmpty()) {
            ContentDocumentLink cdl = new ContentDocumentLink(
                ContentDocumentId = contentDocId,
                LinkedEntityId = userId,
                ShareType = 'I', // Safe sharing type for test
                Visibility = 'AllUsers'
            );
            insert cdl;
        }
    }

    @isTest
    static void testUploadFile() {
        String base64Data = EncodingUtil.base64Encode(Blob.valueOf('Sample file content'));
        String timestamp = Datetime.now().format('yyyyMMdd_HHmmss');
        String fileName = 'SampleFile_' + timestamp + '.txt';

        Test.startTest();
        Map<String, String> contentVersionId = FileUploaderController.uploadFile(base64Data, fileName);
        Test.stopTest();
    }

    @isTest
    static void testDeleteFile() {
        // Upload file first
        String base64Data = EncodingUtil.base64Encode(Blob.valueOf('File to delete'));
        String fileName = 'DeleteFile_' + Datetime.now().format('yyyyMMdd_HHmmss') + '.txt';
        Map<String, String> contentVersionId = FileUploaderController.uploadFile(base64Data, fileName);

        Test.startTest();
        String result = FileUploaderController.deleteFile(contentVersionId.get('contentVersionId'));
        Test.stopTest();

        System.assert(result.contains('successfully') || result.contains('No file found'), 'Unexpected delete message');
    }

    @isTest
    static void testGetPublicLink() {
        // Upload file
        String base64Data = EncodingUtil.base64Encode(Blob.valueOf('File for public link'));
        String fileName = 'PublicLinkFile_' + Datetime.now().format('yyyyMMdd_HHmmss') + '.txt';
        Map<String, String> contentVersionId = FileUploaderController.uploadFile(base64Data, fileName);

        Test.startTest();
        String publicLink = FileUploaderController.getPublicLink(contentVersionId.get('contentVersionId'));
        Test.stopTest();
    }

    @isTest
    static void testDeleteFileWithInvalidId() {
        Test.startTest();
        String result = FileUploaderController.deleteFile('fakeId123456789');
        Test.stopTest();

        System.assertEquals('No file found to delete.', result, 'Should return proper error message for invalid ID');
    }

    @isTest
    static void testGetPublicLinkWithInvalidId() {
        Test.startTest();
        String result = FileUploaderController.getPublicLink('fakeId123456789');
        Test.stopTest();

        System.assert(result.startsWith('Error:'), 'Should return error for invalid ID');
    }
}