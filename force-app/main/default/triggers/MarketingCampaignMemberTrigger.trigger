trigger MarketingCampaignMemberTrigger on Marketing_Campaign_Member__c (after delete) {
    // if (Trigger.isAfter && Trigger.isDelete) {
    //     try {
    //         // Collect campaign and contact IDs
    //         Set<Id> campaignIds = new Set<Id>();
    //         Set<Id> contactIds = new Set<Id>();
    //         for (Marketing_Campaign_Member__c member : Trigger.old) {
    //             campaignIds.add(member.Marketing_Campaign__c);
    //             contactIds.add(member.RecipientId__c);
    //         }

    //         // Fetch and delete associated Email_Member__c records
    //         List<Email_Member__c> emailMembersToDelete = [
    //             SELECT Id
    //             FROM Email_Member__c
    //             WHERE RecipientId__c IN :contactIds
    //             AND Marketing_Email__c IN (
    //                 SELECT Id
    //                 FROM Marketing_Email__c
    //                 WHERE Marketing_Campaign__c IN :campaignIds
    //             )
    //             WITH SECURITY_ENFORCED
    //         ];

    //         if (!emailMembersToDelete.isEmpty() && Schema.sObjectType.Email_Member__c.isDeletable()) {
    //             delete as user emailMembersToDelete;
    //         }

    //         for (Id campaignId : campaignIds) {
    //             // Recalculate campaign counts
    //             EmailCampaignController.recalculateCampaignCounts(campaignId);
    //         }
    //     } catch (Exception e) {
    //         // ErrorHandler.insert_errordata(e, 'MarketingCampaignMemberTrigger', 'afterDelete', 'Error deleting Email_Member__c records.');
    //     }
    // }
}