public with sharing class MarketingEmailTriggerHandler {
    
    List<Marketing_Email__c> newMarketingEmails;
    List<Marketing_Email__c> oldMarketingEmails;
    Map<Id, Marketing_Email__c> newMarketingEmailsMap;
    Map<Id, Marketing_Email__c> oldMarketingEmailsMap;
    Boolean isInsert;
    Boolean isUpdate;
    Boolean isDelete;
    Boolean isUndelete;
    private static final String CLASS_NAME = 'MarketingEmailTriggerHandler';
    
    /**
     * Constructor for setting all the data from the trigger
     */
    public MarketingEmailTriggerHandler(List<Marketing_Email__c> newList, List<Marketing_Email__c> oldList, Map<Id, Marketing_Email__c> newMap, Map<Id, Marketing_Email__c> oldMap, Boolean isInsert, Boolean isUpdate, Boolean isDelete, Boolean isUndelete) {
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
        for (Marketing_Email__c email : oldMarketingEmails) {
            emailIds.add(email.Id);
            campaignIds.add(email.Marketing_Campaign__c);
        }

        // Fetch and delete associated Email_Member__c records
        List<Email_Member__c> emailMembersToDelete = [SELECT Id FROM Email_Member__c WHERE Marketing_Email__c IN :emailIds WITH USER_MODE];

        if (!emailMembersToDelete.isEmpty() && Schema.sObjectType.Email_Member__c.isDeletable()) {
            delete as user emailMembersToDelete;
        }
    }

    
    /**
     * Method to validate marketing email records
     */
    private void validateMarketingEmails(List<Marketing_Email__c> marketingEmails) {
        try {
            Set<Id> campaignIds = new Set<Id>();
            for (Marketing_Email__c email : marketingEmails) {
                campaignIds.add(email.Marketing_Campaign__c);
            }

            Map<Id, Marketing_Campaign__c> campaigns = new Map<Id, Marketing_Campaign__c>([SELECT Id, Schedule_Type__c, Start_Date__c, SelectedContactDateField__c FROM Marketing_Campaign__c WHERE Id IN :campaignIds WITH USER_MODE]);

            for (Marketing_Email__c email : marketingEmails) {
                Marketing_Campaign__c campaign = campaigns.get(email.Marketing_Campaign__c);
                if (campaign.Schedule_Type__c == 'Specific Date' && campaign.Start_Date__c == null) {
                    email.addError('Specific date must be set for campaigns with Specific Date schedule type.');
                }
                if (campaign.Schedule_Type__c == 'Contact Field' && String.isEmpty(campaign.SelectedContactDateField__c)) {
                    email.addError('Contact date field must be set for campaigns with Contact Field schedule type.');
                }
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'MarketingEmailTriggerHandler', 'validateMarketingEmails', 'Error validating marketing emails');
        }
    }
}