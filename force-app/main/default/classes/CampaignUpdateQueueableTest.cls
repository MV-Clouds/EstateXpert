@isTest
public class CampaignUpdateQueueableTest {
    @testSetup
    static void setup() {
        // Insert test Marketing Campaigns
        List<Marketing_Campaign__c> campaigns = new List<Marketing_Campaign__c>();

        campaigns.add(new Marketing_Campaign__c(
            Remaining_Emails__c = 100.0,  // Decimal value
            Total_Sent_Mails__c = 0.0,    // Decimal value
            Status__c = 'Not Started'
        ));

        campaigns.add(new Marketing_Campaign__c(
            Remaining_Emails__c = 50.0,   // Decimal value
            Total_Sent_Mails__c = 50.0,   // Decimal value
            Status__c = 'In Progress'
        ));

        insert campaigns;
    }

    @isTest
    static void testExecute() {
        // Fetch the test campaigns
        List<Marketing_Campaign__c> campaigns = [SELECT Id, Name, Remaining_Emails__c, Total_Sent_Mails__c, Status__c FROM Marketing_Campaign__c];
        
        // Prepare test data
        Map<String, Integer> remainingEmailsMap = new Map<String, Integer>();  // Change to Integer
        Map<String, Marketing_Campaign__c> campaignMap = new Map<String, Marketing_Campaign__c>();

        // Prepare remaining emails map and campaign map
        for (Marketing_Campaign__c campaign : campaigns) {
            remainingEmailsMap.put(String.valueOf(campaign.Id), Integer.valueOf(String.valueOf(campaign.Remaining_Emails__c - 20.0)));  // Convert Decimal to Integer
            campaignMap.put(String.valueOf(campaign.Id), campaign);  // Use String for keys
        }

        Integer emailSize = 20;

        // Enqueue the Queueable job
        CampaignUpdateQueueable queueable = new CampaignUpdateQueueable(remainingEmailsMap, campaignMap, emailSize, 'Success', null);

        Test.startTest();
        System.enqueueJob(queueable);
        Test.stopTest();

        // Validate the results
        List<Marketing_Campaign__c> updatedCampaigns = [SELECT Id, Remaining_Emails__c, Total_Sent_Mails__c, Status__c FROM Marketing_Campaign__c];

        for (Marketing_Campaign__c campaign : updatedCampaigns) {
            Integer expectedRemainingEmails = remainingEmailsMap.get(String.valueOf(campaign.Id));  // Use Integer for expected value
            Decimal expectedTotalSentMails = campaignMap.get(String.valueOf(campaign.Id)).Total_Sent_Mails__c + emailSize;

            System.assertEquals(expectedRemainingEmails, campaign.Remaining_Emails__c.intValue(), 'Remaining Emails should be updated correctly'); // Use intValue() for comparison
            System.assertEquals(expectedTotalSentMails, campaign.Total_Sent_Mails__c, 'Total Sent Mails should be updated correctly');

            if (expectedRemainingEmails == 0) {
                System.assertEquals('Completed', campaign.Status__c, 'Campaign status should be set to Completed');
            } else {
                System.assertEquals('In Progress', campaign.Status__c, 'Campaign status should be In Progress');
            }
        }
    }
}