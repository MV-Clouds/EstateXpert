/**
 * Class Name : ControlCenterController
 * Date : 09-06-2025
 * Created By: Vyom Soni
 * Last Modified Date : 12-06-2025
 * Last Modified By : Vyom Soni
 * @description : Controller for the EstateXpert Control Center LWC component
 */
public with sharing class ControlCenterController {
    
    /**
     * Method Name : getMetadataRecords
     * @description : Fetches the Control Center Feature metadata records to determine which features are available.
     * @return List of Control_Center_Feature__mdt records.
     */
    @AuraEnabled(cacheable=true)
    public static List<Control_Center_Feature__mdt> getMetadataRecords(){
        return [SELECT Id, DeveloperName, isAvailable__c FROM Control_Center_Feature__mdt WITH USER_MODE];
    }
}