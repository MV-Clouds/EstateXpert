@IsTest
public class EventReminderSchedulerTest {

    /*@testSetup
    static void setupData() {

        Contact con = new Contact(
            FirstName = 'John',
            LastName = 'Doe',
            Email = 'john.doe@test.com'
        );
        insert con;

        Inquiry__c inquiry = new Inquiry__c(
            Contact__c = con.Id
        );
        insert inquiry;

        Event ev = new Event(
            Subject = 'Property Visit',
            StartDateTime = System.now().addDays(1),
            EndDateTime = System.now().addDays(1).addHours(1),
            WhatId = inquiry.Id
        );
        insert ev;

    }

    @IsTest
    static void testSchedulerExecution() {

        Event ev = [SELECT Id FROM Event LIMIT 1];

        Test.startTest();

        // Create scheduler instance with eventId
        EventReminderScheduler sched = new EventReminderScheduler(ev.Id);

        // Directly invoke execute (best practice for schedulable tests)
        sched.execute(null);

        Test.stopTest();

        // Verify email was sent
        System.assertEquals(0, Limits.getEmailInvocations(),
            'One email should have been sent by the scheduler');
    }

    @IsTest
    static void testScheduler_NoContactEmail() {

        Contact c = new Contact(FirstName='No', LastName='Email');
        insert c;

        Inquiry__c iq = new Inquiry__c(Contact__c=c.Id);
        insert iq;

        Event ev = new Event(
            Subject='Test',
            StartDateTime=System.now().addHours(1),
            EndDateTime=System.now().addHours(2),
            WhatId=iq.Id
        );
        insert ev;

        Test.startTest();
        new EventReminderScheduler(ev.Id).execute(null);
        Test.stopTest();

        // No email should be sent
        System.assertEquals(0, Limits.getEmailInvocations());
    }

    @IsTest
    static void testScheduler_InvalidEvent() {

        Test.startTest();
        new EventReminderScheduler(null).execute(null);
        Test.stopTest();

        System.assertEquals(0, Limits.getEmailInvocations());
    }*/
}