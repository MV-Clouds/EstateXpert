public with sharing class MarketingEmailTriggerHandler {
    
    List<MVEX__Marketing_Email__c> newMarketingEmails;
    List<MVEX__Marketing_Email__c> oldMarketingEmails;
    Map<Id, MVEX__Marketing_Email__c> newMarketingEmailsMap;
    Map<Id, MVEX__Marketing_Email__c> oldMarketingEmailsMap;
    Boolean isInsert;
    Boolean isUpdate;
    Boolean isDelete;
    Boolean isUndelete;
    private static final String CLASS_NAME = 'MarketingEmailTriggerHandler';
    
    /**
     * Constructor for setting all the data from the trigger
     */
    public MarketingEmailTriggerHandler(List<MVEX__Marketing_Email__c> newList, List<MVEX__Marketing_Email__c> oldList, Map<Id, MVEX__Marketing_Email__c> newMap, Map<Id, MVEX__Marketing_Email__c> oldMap, Boolean isInsert, Boolean isUpdate, Boolean isDelete, Boolean isUndelete) {
        this.newMarketingEmails = newList;
        this.oldMarketingEmails = oldList;
        this.newMarketingEmailsMap = newMap;
        this.oldMarketingEmailsMap = oldMap;
        this.isInsert = isInsert;
        this.isUpdate = isUpdate;
        this.isDelete = isDelete;
        this.isUndelete = isUndelete;
    }
    
    /**
     * Method to run after insert event
     */
    public void onAfterInsert() {
        validateMarketingEmails(newMarketingEmails);
    }
    
    /**
     * Method to run after update event
     */
    public void onAfterUpdate() {
        validateMarketingEmails(newMarketingEmails);
    }


    /**
     * Method to run after delete event
     */
    public void onAfterDelete() {
        Set<Id> emailIds = new Set<Id>();
        Set<Id> campaignIds = new Set<Id>();
        for (MVEX__Marketing_Email__c email : oldMarketingEmails) {
            emailIds.add(email.Id);
            campaignIds.add(email.MVEX__Marketing_Campaign__c);
        }

        // Fetch and delete associated Email_Member__c records
        List<MVEX__Email_Member__c> emailMembersToDelete = [SELECT Id FROM MVEX__Email_Member__c WHERE MVEX__Marketing_Email__c IN :emailIds WITH USER_MODE];

        if (!emailMembersToDelete.isEmpty() && Schema.sObjectType.MVEX__Email_Member__c.isDeletable()) {
            delete as user emailMembersToDelete;
        }
    }

    
    /**
     * Method to validate marketing email records
     */
    private void validateMarketingEmails(List<MVEX__Marketing_Email__c> marketingEmails) {
        try {
            Set<Id> campaignIds = new Set<Id>();
            for (MVEX__Marketing_Email__c email : marketingEmails) {
                campaignIds.add(email.MVEX__Marketing_Campaign__c);
            }

            Map<Id, MVEX__Marketing_Campaign__c> campaigns = new Map<Id, MVEX__Marketing_Campaign__c>([SELECT Id, MVEX__Schedule_Type__c, MVEX__Start_Date__c, MVEX__SelectedContactDateField__c FROM MVEX__Marketing_Campaign__c WHERE Id IN :campaignIds WITH USER_MODE]);

            for (MVEX__Marketing_Email__c email : marketingEmails) {
                MVEX__Marketing_Campaign__c campaign = campaigns.get(email.MVEX__Marketing_Campaign__c);
                if (campaign.MVEX__Schedule_Type__c == 'Specific Date' && campaign.MVEX__Start_Date__c == null) {
                    email.addError('Specific date must be set for campaigns with Specific Date schedule type.');
                }
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'MarketingEmailTriggerHandler', 'validateMarketingEmails', 'Error validating marketing emails');
        }
    }
}