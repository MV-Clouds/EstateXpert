global class PostInstallScript implements InstallHandler {
    
    global void onInstall(InstallContext context) {
        // Change 1: Run on both fresh install (null) and updates
        createDefaultConfigRecords();
        // Change 2: Handle Custom Setting from Custom Label
        setupEmbeddedSignUpConfig();
    }

    /**
     * Method to copy Metadata records to Custom Object records
     */
    private void createDefaultConfigRecords() {
        try {
            // Define the required features for Change 1
            Set<String> requiredFeatures = new Set<String>{
                'ListingManagerFilters', 'Inquiry Manager', 'Listing Manager', 'Marketing List', 'Listing_Configuration'
            };

            // Query existing records to prevent duplicates
            Set<String> existingFeatures = new Set<String>();
            for (MVEX__Configuration_Settings__c existing : [SELECT MVEX__Feature_Name__c FROM MVEX__Configuration_Settings__c WHERE MVEX__Feature_Name__c IN :requiredFeatures]) {
                existingFeatures.add(existing.MVEX__Feature_Name__c);
            }

            // 1. Query the Metadata (The "Templates")
            List<MVEX__recordManagerInquiryConfig__mdt> metadataRecords = [
                SELECT MasterLabel, DeveloperName, 
                       MVEX__Object_API_Name__c, 
                       MVEX__Feature_Name__c, 
                       MVEX__FieldsData__c, 
                       MVEX__PageSize__c, 
                       MVEX__Blocked_Fields__c
                FROM MVEX__recordManagerInquiryConfig__mdt
                WHERE MVEX__Feature_Name__c IN :requiredFeatures
            ];

            List<MVEX__Configuration_Settings__c> settingsToInsert = new List<MVEX__Configuration_Settings__c>();

            // 2. Iterate and Map to Custom Object
            for (MVEX__recordManagerInquiryConfig__mdt meta : metadataRecords) {
                // Only create if the record for this feature doesn't exist
                if (!existingFeatures.contains(meta.MVEX__Feature_Name__c)) {
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
            }

            // 3. Insert Records
            if (!settingsToInsert.isEmpty()) {
                insert settingsToInsert;
            }

        } catch (Exception e) {
            // Log error or send email to admin if needed
            System.debug('Error in PostInstallScript: ' + e.getMessage());
            ErrorHandler.insertErrorData(e, 'PostInstallScript', 'createDefaultConfigRecords', 'Error while creating  record.');
        }
    }

    /**
     * Change 2: Logic to insert Custom Setting from Custom Label
     */
    private void setupEmbeddedSignUpConfig() {
        try {
            String labelValue = System.Label.WhatsappConfig;
            if (String.isNotBlank(labelValue)) {
                List<String> parts = labelValue.split(';');
                
                // Ensure we have exactly 3 parts: ClientId;ClientSecret;ConfigId
                if (parts.size() >= 3) {
                    MVEX__EmbeddedSignUpConfig__c config = MVEX__EmbeddedSignUpConfig__c.getOrgDefaults();
                    
                    config.MVEX__Client_Id__c = parts[0].trim();
                    config.MVEX__Client_Secret__c = parts[1].trim();
                    config.MVEX__Config_Id__c = parts[2].trim();
                    
                    upsert config;
                }
            }
        } catch (Exception e) {
            System.debug('Error setting up EmbeddedSignUpConfig: ' + e.getMessage());
            ErrorHandler.insertErrorData(e, 'PostInstallScript', 'setupEmbeddedSignUpConfig', 'Error while updating or creating PortalListing__c record.');
        }
    }
}