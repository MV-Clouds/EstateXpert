@isTest
private class MarketingEmailTriggerHandlerTest {

    @testSetup
    static void setupTestData() {
        Marketing_Campaign__c campaign = new Marketing_Campaign__c(SelectedContactDateField__c = 'Birthdate');
        insert campaign;

        Contact testContact = new Contact(FirstName = 'Test', LastName = 'Contact', Birthdate = Date.today());
        insert testContact;

        Marketing_Email__c email = new Marketing_Email__c(Name = 'Test Email', Marketing_Campaign__c = campaign.Id, TimeToSend__c = Time.newInstance(8, 0, 0, 0));
        insert email;

        Marketing_Campaign_Member__c campaignMember = new Marketing_Campaign_Member__c(Marketing_Campaign__c = campaign.Id, Contact__c = testContact.Id, Contact_Type__c = 'Primary');
        insert campaignMember;
    }

    @isTest
    static void testInsert() {
        Test.startTest();
        List<Marketing_Email__c> emails = [SELECT Id,Marketing_Campaign__c,TimeToSend__c FROM Marketing_Email__c];
        MarketingEmailTriggerHandler handler = new MarketingEmailTriggerHandler(emails, new List<Marketing_Email__c>(), new Map<Id, Marketing_Email__c>{ emails[0].Id => emails[0] }, new Map<Id, Marketing_Email__c>(), true, false, false, false);
        handler.onAfterInsert();
        Test.stopTest();

    }

    @isTest
    static void testUpdate() {
        String testName = 'Test Email';
        Marketing_Email__c updatedEmail = [SELECT Id,Name,Marketing_Campaign__c,TimeToSend__c FROM Marketing_Email__c WHERE NAME =:testName LIMIT 1];
        updatedEmail.Name = 'Updated Test Email';
        update updatedEmail;

        Contact contact = [SELECT Id FROM Contact LIMIT 1];

        Email_Member__c emailMember = new Email_Member__c(Contact__c = contact.Id, Marketing_Email__c = updatedEmail.Id, Schedule_Date_and_Time__c = DateTime.newInstance(Date.today(), Time.newInstance(8, 0, 0, 0)));
        insert emailMember;

        Test.startTest();
        List<Marketing_Email__c> emails = [SELECT Id,Marketing_Campaign__c,TimeToSend__c FROM Marketing_Email__c];
        MarketingEmailTriggerHandler handler = new MarketingEmailTriggerHandler(emails, new List<Marketing_Email__c>(), new Map<Id, Marketing_Email__c>{ emails[0].Id => emails[0] }, new Map<Id, Marketing_Email__c>{ updatedEmail.Id => updatedEmail }, false, true, false, false);
        handler.onAfterUpdate();
        Test.stopTest();

        List<Email_Member__c> updatedEmailMembers = [SELECT Id FROM Email_Member__c WHERE Marketing_Email__c = :updatedEmail.Id];
        System.assertEquals(1, updatedEmailMembers.size(), 'Expected one Email Member record to be updated');
        delete emails;
    }
}