public with sharing class FileDownloadController {
    public String fileContentType { get; set; }
    public Blob fileDownload { get; set; }

    public FileDownloadController() {
        String fileName = ApexPages.currentPage().getParameters().get('fileName');
        
        if (String.isBlank(fileName)) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Missing file name'));
            return;
        }

        try {
            // AWS Config
            List<AWS_Config__c> configList = [SELECT Id, AWS_Access_Key__c, AWS_Secret_Access_Key__c, S3_Bucket_Name__c, S3_Region_Name__c, CreatedDate, LastModifiedDate FROM AWS_Config__c WITH USER_MODE LIMIT 1];
            if (!configList.isEmpty()) {
                AWS_Config__c configData = configList[0];
                String bucketName = configData.S3_Bucket_Name__c;
                Http http = new Http();
                HttpRequest request = new HttpRequest();
                request.setEndpoint('https://' + bucketName + '.s3.amazonaws.com/' + fileName);
                request.setMethod('GET');
                HttpResponse response = http.send(request);
    
                if (response.getStatusCode() == 200) {
                    fileDownload = response.getBodyAsBlob();
                    ApexPages.currentPage().getHeaders().put('Content-Disposition', 'attachment; filename="' + fileName + '"');
                } else {
                    ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Failed to download file from AWS'));
                }
            } else {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'AWS Configuration is not found'));
            }
        } catch (Exception e) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Error: ' + e.getMessage()));
        }
    }
}