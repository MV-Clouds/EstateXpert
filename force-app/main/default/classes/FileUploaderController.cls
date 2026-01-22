public with sharing class FileUploaderController {
    // @AuraEnabled
    // public static Map<String, String> uploadFile(String base64Data, String fileName) {
    //     Map<String, String> resultMap = new Map<String, String>();
    //     try {
    //         ContentVersion cv = new ContentVersion();
    //         cv.Title = fileName;
    //         cv.PathOnClient = '/' + fileName;
    //         cv.VersionData = EncodingUtil.base64Decode(base64Data);
    //         insert as user cv;

    //         String publicUrl = getPublicLink(cv.Id);

    //         resultMap.put('contentVersionId', cv.Id);
    //         resultMap.put('publicUrl', publicUrl);
    //         return resultMap;
    //     } catch (Exception e) {
    //         ErrorHandler.insertErrorData(e, 'FileUploaderController', 'uploadFile', e.getMessage());
    //         return null;
    //     }
    // }

    // @AuraEnabled
    // public static String deleteFile(String contentVersionId) {
    //     try {

    //         // Get related ContentDocument
    //         List<ContentDocument> docs = [SELECT Id FROM ContentDocument WHERE LatestPublishedVersionId = :contentVersionId WITH USER_MODE LIMIT 1];
    //         if (!docs.isEmpty()) {
    //             Id contentDocumentId = docs[0].Id;
                
    //             delete as user docs;
    //             return 'File deleted successfully!';
    //         } else {
    //             return 'No file found to delete.';
    //         }
    //     } catch (Exception e) {
    //         ErrorHandler.insertErrorData(e, 'FileUploaderController', 'deleteFile', e.getMessage());
    //         return 'Error: ' + e.getMessage();
    //     }
    // }
    // @AuraEnabled
    // public static String getPublicLink(String contentVersionId) {
    //     try {
    //         // Get the related ContentDocument Id
    //         ContentVersion contentVersion = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :contentVersionId WITH USER_MODE LIMIT 1];
            
    //         // Create a new ContentDistribution (public link)
    //         ContentDistribution distribution = new ContentDistribution();
    //         distribution.Name = 'Public Link';
    //         distribution.ContentVersionId = contentVersion.Id;
    //         distribution.PreferencesAllowViewInBrowser= true;
    //         distribution.PreferencesLinkLatestVersion=true;
    //         distribution.PreferencesNotifyOnVisit=false;
    //         distribution.PreferencesPasswordRequired=false;
    //         distribution.PreferencesAllowOriginalDownload= true;

    //         insert as user distribution;
            
    //         // Query the created ContentDistribution to get the public URL
    //         distribution = [SELECT DistributionPublicUrl,ContentDownloadUrl FROM ContentDistribution WHERE Id = :distribution.Id WITH USER_MODE LIMIT 1];
        
    //         // Return the public URL
    //         return distribution.ContentDownloadUrl;
    //     } catch (Exception e) {
    //         ErrorHandler.insertErrorData(e, 'FileUploaderController', 'getPublicLink', e.getMessage());
    //         return 'Error: ' + e.getMessage();
    //     }
    // }
}