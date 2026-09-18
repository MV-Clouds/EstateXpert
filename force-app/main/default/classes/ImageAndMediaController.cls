/**
* Class Name : ImageAndMediaController
* Test Class : ImageAndMediaControllerTest
* Created By : Karan Singh
* Last Modified Date : 08/08/2024
* Last Modified By : Karan Singh
* @description : Used to get, create and sort the images related to property.
*/
public with sharing class ImageAndMediaController {

    /**
    * Class Name : ListingWrapper
    * @description : Used to store the property id and images data.
    */
    public class ListingWrapper {
        @AuraEnabled
        public String propertyId { get; set; }
        @AuraEnabled
        public List<MVEX__Property_File__c> listingImages { get; set; }
        @AuraEnabled
        public String status { get; set; }
    }

    /**
    * Method Name : fetchListingAndImages
    * @param recordId to stored the Listing record Id
    * @return ListingWrapper that contains property id and images data.
    * @description : Used to get the listing and images data.
    */
    @AuraEnabled
    public static ListingWrapper fetchListingAndImages(String recordId){

        ListingWrapper newWrap = new ListingWrapper();

        try {
            List<MVEX__Listing__c> listingRecord = [SELECT Id, MVEX__Property__c FROM MVEX__Listing__c WHERE Id =: recordId WITH USER_MODE LIMIT 1];
            if (!listingRecord.isEmpty()) {
                List<MVEX__Property_File__c> listingImages = [SELECT Id, MVEX__BaseUrl__c, MVEX__Tags__c, Name, MVEX__ExternalLink__c, MVEX__Size__c, MVEX__Property__c, 
                                                                MVEX__IsOnPortalFeed__c, MVEX__IsOnWebsite__c, MVEX__IsOnExpose__c, MVEX__Sort_on_Expose__c, 
                                                                MVEX__Sort_on_Portal_Feed__c, MVEX__Sort_on_Website__c, MVEX__Filename__c, MVEX__MimeType__c FROM 
                                                                MVEX__Property_File__c WHERE MVEX__Property__c =: listingRecord[0].MVEX__Property__c 
                                                                WITH USER_MODE ORDER BY Name];
                listingImages.sort();

                newWrap.propertyId = listingRecord[0].MVEX__Property__c;
                newWrap.listingImages = listingImages;
                newWrap.status = 'success';

                return newWrap;
            } else {
                newWrap.status = 'No Record Found.';
                return newWrap;
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'ImageAndMediaController', 'fetchListingAndImages', 'Error while getting listing record.');
            newWrap.status = e.getMessage();
            return newWrap;
        }
    }

    /**
    * Method Name : createmediaforlisting
    * @param recordId to stored the Listing record Id
    * @param mediaList to stored the images data
    * @return Boolean value
    * @description : Used to create new MVEX__Property_File__c records.
    */
    @AuraEnabled
    public static String createmediaforlisting(Id recordId, List<MediaData> mediaList){
        try {
            List<MVEX__Property_File__c> mediaToInsert = new List<MVEX__Property_File__c>();

            for (MediaData media : mediaList) {
                MVEX__Property_File__c mediaRecord = new MVEX__Property_File__c();
                mediaRecord.MVEX__BaseUrl__c = media.externalUrl;
                if(media.name != '' && media.name != null){
                    if (media.name.length() > 80) { 
                        String truncatedName = media.name.substring(0, 80);
                        mediaRecord.Name = truncatedName; 
                        mediaRecord.MVEX__Filename__c = media.name;
                    } else {
                        mediaRecord.Name = media.name;
                        mediaRecord.MVEX__Filename__c = media.name;
                    }
                }
                mediaRecord.MVEX__Size__c = media.size;
                mediaRecord.MVEX__Property__c = recordId;
                mediaRecord.MVEX__ExternalLink__c = media.externalVideoUrl;
                mediaRecord.MVEX__IsOnExpose__c = media.IsOnExpose;
                mediaRecord.MVEX__IsOnPortalFeed__c = media.IsOnPortalFeed;
                mediaRecord.MVEX__IsOnWebsite__c = media.IsOnWebsite;
                mediaRecord.MVEX__MimeType__c = media.type;
                mediaToInsert.add(mediaRecord);
            }
            
            if (!mediaToInsert.isEmpty()) {
                insert as user mediaToInsert;
                return 'success';
            } else {
                return 'Property Media List is Empty.';
            }
            
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'ImageAndMediaController', 'createmediaforlisting', 'Error while creating MVEX__Property_File__c record.');
            return e.getMessage();
        }
    }
    
    /**
    * Class Name : MediaData
    * @description : Used to store the media data.
    */
    public class MediaData {
        @AuraEnabled
        public String name { get; set; }
        @AuraEnabled
        public Decimal size { get; set; }
        @AuraEnabled
        public String externalUrl { get; set; }
        @AuraEnabled
        public String externalVideoUrl { get; set; }
        @AuraEnabled
        public Boolean isOnExpose { get; set; }
        @AuraEnabled
        public Boolean isOnPortalFeed { get; set; }
        @AuraEnabled
        public Boolean isOnWebsite { get; set; }
        @AuraEnabled
        public String type { get; set; }
    }

    /**
    * Method Name : deletelistingmedia
    * @param id to stored the MVEX__Property_File__c record Id
    * @param propertyId to stored the property Id
    * @return Boolean value
    * @description : Used to delete MVEX__Property_File__c records.
    */
    @AuraEnabled
    public static Boolean deletelistingmedia(String id,String propertyId){
        try {
            if (id != null) {
                List<MVEX__Property_File__c> record = [SELECT Id FROM MVEX__Property_File__c WHERE Id = :id WITH USER_MODE LIMIT 1];
                if (Schema.sObjectType.MVEX__Property_File__c.isDeletable()) {
                    delete as user record;
                }
            } else if (propertyId != null) {
                List<MVEX__Listing__c> listing = [SELECT Id, MVEX__Property__c FROM MVEX__Listing__c WHERE Id= :propertyId WITH USER_MODE LIMIT 1];
                if (!listing.isEmpty()) {
                    List<MVEX__Property_File__c> allMedia = [SELECT Id, MVEX__Property__c FROM MVEX__Property_File__c WHERE MVEX__Property__c = :listing[0].MVEX__Property__c];
                    if (allMedia != null) {
                        delete as user allMedia;
                    }
                }
            }   
            return true;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'ImageAndMediaController', 'deletelistingmedia', 'Error while deleting MVEX__Property_File__c record.');
            return false;
        }
    }

    /**
    * Class Name : AWSWrapper
    * @description : Used to store the custom settings and images data.
    */
    public class AWSWrapper {
        @AuraEnabled
        public Boolean status { get; set; }
        @AuraEnabled
        public String contentVersionData { get; set; }
        @AuraEnabled
        public MVEX__AWS_Config__c awsConfigData  { get; set; }
        @AuraEnabled
        public Boolean isIntegrated  { get; set; }
    }

    /**
    * Method Name : getS3ConfigSettings
    * @return MVEX__AWS_Config__c details
    * @description : Used to return the MVEX__AWS_Config__c custom setting record.
    */
    @AuraEnabled
    public static AWSWrapper getS3ConfigSettings(){
        AWSWrapper newWrap = new AWSWrapper();
        try {
            List<ContentVersion>  cvList = [SELECT Id, ContentSize, Title, FileType, VersionDataUrl, VersionData FROM ContentVersion WHERE ExternalDocumentInfo1 = 'watermark3112' AND isLatest = true WITH USER_MODE];
            newWrap.contentVersionData = cvList.size() > 0 ? EncodingUtil.base64Encode(cvList[0].VersionData) : '';

            MVEX__AWS_Config__c awsCredential = MVEX__AWS_Config__c.getOrgDefaults();
            newWrap.awsConfigData = awsCredential;

            newWrap.isIntegrated = awsCredential.MVEX__AWS_Access_Key__c != null && awsCredential.MVEX__AWS_Secret_Access_Key__c != null && awsCredential.MVEX__S3_Bucket_Name__c != null && awsCredential.MVEX__S3_Region_Name__c != null;

            newWrap.status = true;

            return newWrap;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'ImageAndMediaController', 'getS3ConfigSettings', 'Error while getting MVEX__AWS_Config__c record.');
            newWrap.contentVersionData = e.getMessage();
            newWrap.status = false;
            return newWrap;
        }
        
    }

    /**
    * Method Name : updatePropertyFileRecords
    * @param itemsToUpdate to stored the MVEX__Property_File__c records
    * @return String value
    * @description : Used to update the MVEX__Property_File__c records.
    */
    @AuraEnabled
    public static String updatePropertyFileRecords(List<Map<String, Object>> itemsToUpdate) {
        try {
            List<MVEX__Property_File__c> recordsToUpdate = new List<MVEX__Property_File__c>();

            for (Map<String, Object> fields : itemsToUpdate) {
                MVEX__Property_File__c existingRecord = new MVEX__Property_File__c(Id = (String) fields.get('Id'));
                for (String fieldName : fields.keySet()) {
                    if (fieldName != 'Id') {
                        existingRecord.put(fieldName, fields.get(fieldName));
                    }
                }
                recordsToUpdate.add(existingRecord);
            }

            if (!recordsToUpdate.isEmpty()) {
                update as user recordsToUpdate;
            } else {
                return 'Property Media List is Empty or not accessible.';
            }

            return 'success';
        }catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'ImageAndMediaController', 'updatePropertyFileRecords', 'Error while updating MVEX__Property_File__c records.');
            return 'error' + e.getMessage() + e.getLineNumber();
        }
    }

    /**
    * Method Name : saveFile
    * @param strFileName to stored the Filename
    * @param base64Data to stored the Filedata
    * @return ContentVersion data
    * @description : Used to create the ContentVersion record.
    */
    @AuraEnabled
    public static ContentVersion saveFile(String strFileName, String base64Data) {  
        try {
            base64Data = EncodingUtil.urlDecode(base64Data, 'UTF-8');
            ContentVersion cv = new ContentVersion();
            cv.Title = strFileName;
            cv.PathOnClient = '/' + strFileName;
            cv.VersionData = EncodingUtil.base64Decode(base64Data);
            cv.ExternalDocumentInfo1 = 'watermark3112';
            
            insert as user cv;

            return cv;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'ImageAndMediaController', 'saveFile', 'Error while create ContentVersion record.');
            return null;
        }
    }

    /**
    * Method Name : deleteFiles
    * @param contentVersionRecId to stored the contentversion record id.
    * @description : Used to delete the ContentVersion record.
    */
    @AuraEnabled
    public static void deleteFiles(String contentVersionRecId){ 
        try {
            List<ContentVersion> cvList = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id =: contentVersionRecId WITH USER_MODE];

            if (!cvList.isEmpty()) {
                List<ContentDocument> cdList = [SELECT Id FROM ContentDocument WHERE Id =: cvList[0].ContentDocumentId WITH USER_MODE];

                if (!cdList.isEmpty()) {
                    delete as user cdList;
                }
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'ImageAndMediaController', 'deleteFiles', 'Error while deleting ContentVersion record.');
        }
    }

    /**
    * Method Name : saveFile
    * @param strFileName to stored the Filename
    * @param base64Data to stored the Filedata
    * @return ContentVersion data
    * @description : Used to create the ContentVersion record.
    */
    @AuraEnabled
    public static List<ContentVersion> getContentVersionData(){
        try {
            List<ContentVersion> cvList = [SELECT Id, ContentSize, Title, FileType, VersionDataUrl FROM ContentVersion WHERE ExternalDocumentInfo1 = 'watermark3112' WITH USER_MODE];

            if (!cvList.isEmpty()) {
                return cvList;
            }

            return null;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'ImageAndMediaController', 'deleteFiles', 'Error while deleting ContentVersion record.');
            return null;
        }
    }
    
}