public with sharing class CampaignUpdateQueueable implements Queueable, Database.AllowsCallouts {
    private Map<String, Integer> remainingEmailsMap;
    private Map<String, MVEX__Marketing_Campaign__c> campaignMap;
    private Integer emailSize;
    private String status;
    private String errorMessage;

    public CampaignUpdateQueueable(Map<String, Integer> remainingEmails, Map<String, MVEX__Marketing_Campaign__c> campaigns, Integer emailSize, String status, String errorMessage) {
        this.remainingEmailsMap = remainingEmails;
        this.campaignMap = campaigns;
        this.emailSize = emailSize;
        this.status = status;
        this.errorMessage = errorMessage;
    }

    public void execute(QueueableContext context) {
        try {
            List<MVEX__Marketing_Campaign__c> campaignsToUpdate = new List<MVEX__Marketing_Campaign__c>();

            for (String campaignId : this.remainingEmailsMap.keySet()) {
                MVEX__Marketing_Campaign__c campaignToUpdate = this.campaignMap.get(campaignId);
                if (campaignToUpdate != null) {
                    if (this.status == 'Failed') {
                        campaignToUpdate.MVEX__Status__c = 'Failed';
                        campaignToUpdate.MVEX__Failed_Reason__c = this.errorMessage;
                        campaignsToUpdate.add(campaignToUpdate);
                    } else {
                        EmailCampaignController.recalculateCampaignCounts((Id)campaignId);
                    }
                }
            }

            if (!campaignsToUpdate.isEmpty()) {
                update as user campaignsToUpdate;
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'CampaignUpdateQueueable', 'execute', 'Error while executing method.');
        }
    }
}