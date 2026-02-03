public without sharing class WhatsappConfigController {

    public static String whatsappBusinessAppId {get; set;}
    public static String clientId {get; set;}
    public static String configurationId {get; set;}
    public static String clientSecret {get; set;}

    public WhatsappConfigController() {
        List<WBConnect_Configuration__mdt> metaList = [SELECT MasterLabel, Business_Account_Id__c FROM WBConnect_Configuration__mdt WITH USER_MODE];
        if (metaList.size() > 0) {
            whatsappBusinessAppId = metaList[0].Business_Account_Id__c;
        } else {
            whatsappBusinessAppId = '';
        }

        List<EmbeddedSignUpConfig__c> embeddedConfig = [SELECT Id, Config_Id__c, Client_Secret__c, Client_Id__c FROM EmbeddedSignUpConfig__c WITH USER_MODE];
        if (embeddedConfig.size() > 0) {
            clientId = embeddedConfig[0].Client_Id__c;
            clientSecret = embeddedConfig[0].Client_Secret__c;
            configurationId = embeddedConfig[0].Config_Id__c;
        }
    }

    @AuraEnabled
    public static Boolean unlinkAccount() {
        try {
            Boolean isSuccess = saveMetaData('', '', '', '');
            if (isSuccess) {
                return true;
            }
            return false;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'WhatsappConfigController', 'unlinkAccount', e.getMessage());
            throw new AuraHandledException('Error unlinking account: ' + e.getMessage());
        }
    }

    @RemoteAction
    public static String saveFBLoginDetails(String sAccessToken, String phoneId, String wabaId, String appId) {
        try {
            List<EmbeddedSignUpConfig__c> embeddedConfig = [SELECT Id, Config_Id__c, Client_Secret__c, Client_Id__c FROM EmbeddedSignUpConfig__c WITH USER_MODE];
            if (embeddedConfig.size() < 1) {
                return 'Failure';
            }
            
            String tokenUrl = 'https://graph.facebook.com/v21.0/oauth/access_token?grant_type=fb_exchange_token&client_id=' + embeddedConfig[0].Client_Id__c + '&client_secret=' + embeddedConfig[0].Client_Secret__c + '&fb_exchange_token=' + sAccessToken;
            HttpRequest req = new HttpRequest();
            req.setEndpoint(tokenUrl);
            req.setMethod('GET');
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() == 200) {
                Map<String, Object> responseBody1 = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                String accessToken = (String) responseBody1.get('access_token');
                Boolean isSuccess = saveMetaData(accessToken, phoneId, wabaId, appId);
                if (isSuccess) {
                    return wabaId;
                }
            }
            return null;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'WhatsappConfigController', 'saveFBLoginDetails', e.getMessage());
            return null;
        }
    }

    public static Boolean saveMetaData(String accessToken, String phoneId, String wabaId, String appId) {
        try {
            List<WBConnect_Configuration__mdt> metaList = [SELECT MasterLabel, DeveloperName FROM WBConnect_Configuration__mdt WITH USER_MODE];

            Metadata.CustomMetadata mdata = new Metadata.CustomMetadata();
            if (metaList.size() > 0) {
                mdata.fullName = 'MVEX__WBConnect_Configuration__mdt.' + metaList[0].DeveloperName; 
                mdata.label = metaList[0].MasterLabel;
            } else {
                mdata.fullName = 'MVEX__WBConnect_Configuration__mdt.MVEX__WBConnect_Configuration'; 
                mdata.label = 'WB_Connect_Config_Details';
            }

            Metadata.CustomMetadataValue instance1 = new Metadata.CustomMetadataValue();
            instance1.field = 'MVEX__Business_Account_Id__c';
            instance1.value = wabaId;
            mdata.values.add(instance1);

            Metadata.CustomMetadataValue instance2 = new Metadata.CustomMetadataValue();
            instance2.field = 'MVEX__Phone_Number_Id__c';
            instance2.value = phoneId;
            mdata.values.add(instance2);

            Metadata.CustomMetadataValue instance3 = new Metadata.CustomMetadataValue();
            instance3.field = 'MVEX__Access_Token__c';
            instance3.value = accessToken;
            mdata.values.add(instance3);

            Metadata.CustomMetadataValue instance4 = new Metadata.CustomMetadataValue();
            instance4.field = 'MVEX__Application_Id__c';
            instance4.value = appId;
            mdata.values.add(instance4);

            Metadata.CustomMetadataValue instance5 = new Metadata.CustomMetadataValue();
            instance5.field = 'MVEX__API_Endpoint__c';
            instance5.value = 'https://graph.facebook.com';
            mdata.values.add(instance5);

            Metadata.CustomMetadataValue instance6 = new Metadata.CustomMetadataValue();
            instance6.field = 'MVEX__API_Version__c';
            instance6.value = 'v22.0';
            mdata.values.add(instance6);

            Metadata.DeployContainer container = new Metadata.DeployContainer();
            container.addMetadata(mdata);
            
            Id jobId = Metadata.Operations.enqueueDeployment(container, null);
            return true;
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'WhatsappConfigController', 'saveMetaData', e.getMessage());
            return false;
        }
    }
}