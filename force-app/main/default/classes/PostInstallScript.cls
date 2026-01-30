global class PostInstallScript implements InstallHandler {
    
    global void onInstall(InstallContext context) {
        if (context.previousVersion() == null) {
            createDefaultConfigRecords();
        }
    }

    /**
     * Method to copy Metadata records to Custom Object records
     */
    private void createDefaultConfigRecords() {
        try {
            // 1. Query the Metadata (The "Templates")
            List<MVEX__recordManagerInquiryConfig__mdt> metadataRecords = [
                SELECT MasterLabel, DeveloperName, 
                       MVEX__Object_API_Name__c, 
                       MVEX__Feature_Name__c, 
                       MVEX__FieldsData__c, 
                       MVEX__PageSize__c, 
                       MVEX__Blocked_Fields__c
                FROM MVEX__recordManagerInquiryConfig__mdt
            ];

            List<MVEX__Configuration_Settings__c> settingsToInsert = new List<MVEX__Configuration_Settings__c>();

            // 2. Iterate and Map to Custom Object
            for (MVEX__recordManagerInquiryConfig__mdt meta : metadataRecords) {
                
                MVEX__Configuration_Settings__c setting = new MVEX__Configuration_Settings__c();
                
                // Truncate to 80 chars just in case, as Name field limit is 80
                setting.Name = meta.DeveloperName.left(80);
                
                // Map Custom Fields
                setting.MVEX__Object_API_Name__c = meta.MVEX__Object_API_Name__c;
                setting.MVEX__Feature_Name__c = meta.MVEX__Feature_Name__c;
                setting.MVEX__Fields_Data__c = meta.MVEX__FieldsData__c;
                setting.MVEX__Page_Size__c = meta.MVEX__PageSize__c;
                setting.MVEX__Blocked_Fields__c = meta.MVEX__Blocked_Fields__c;

                settingsToInsert.add(setting);
            }

            // 3. Insert Records
            if (!settingsToInsert.isEmpty()) {
                insert settingsToInsert;
            }

        } catch (Exception e) {
            // Log error or send email to admin if needed
            System.debug('Error in PostInstallScript: ' + e.getMessage());
        }
    }
}