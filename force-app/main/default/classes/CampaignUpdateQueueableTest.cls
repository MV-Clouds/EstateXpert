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
    }
}