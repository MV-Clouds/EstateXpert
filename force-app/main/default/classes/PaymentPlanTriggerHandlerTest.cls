@isTest
private class PaymentPlanTriggerHandlerTest {

    // @testSetup
    // static void setupTestData() {

    //     // --- Post-Handover plan (Monthly construction) ---
    //     insert new Payment_Plan__c(
    //         Payment_Plan__c               = 'Post-Handover',
    //         Amount__c                     = 1000000,
    //         Down_Payment_Percentage__c    = 10,
    //         Construction_Period_Months__c = 12,
    //         Handover_Percentage__c        = 10,
    //         Post_Handover_Period_Months__c = 24,
    //         Construction_Installment_Frequency__c = 'Monthly',
    //         Next_Installment_Due_Date__c  = Date.today()
    //     );

    //     // --- Standard plan ---
    //     insert new Payment_Plan__c(
    //         Payment_Plan__c               = 'Standard',
    //         Amount__c                     = 500000,
    //         Down_Payment_Percentage__c    = 20,
    //         Construction_Period_Months__c = 12,
    //         Handover_Percentage__c        = 10,
    //         Construction_Percentage__c    = 70,
    //         Construction_Installment_Frequency__c = 'Monthly',
    //         Next_Installment_Due_Date__c  = Date.today()
    //     );

    //     // --- 10:90 plan ---
    //     insert new Payment_Plan__c(
    //         Payment_Plan__c               = '10:90',
    //         Amount__c                     = 800000,
    //         Down_Payment_Percentage__c    = 10,
    //         Construction_Period_Months__c = 6,
    //         Handover_Percentage__c        = 90,
    //         Next_Installment_Due_Date__c  = Date.today()
    //     );

    //     // --- Rent-to-Own plan ---
    //     insert new Payment_Plan__c(
    //         Payment_Plan__c              = 'Rent-to-Own',
    //         Amount__c                    = 600000,
    //         Rent_Duration_Months__c      = 24,
    //         Total_Rent_Percentage__c     = 80,
    //         Next_Installment_Due_Date__c = Date.today()
    //     );

    //     // --- 1% Monthly plan ---
    //     insert new Payment_Plan__c(
    //         Payment_Plan__c               = '1% Monthly',
    //         Amount__c                     = 1000000,
    //         Down_Payment_Percentage__c    = 10,
    //         Construction_Period_Months__c = 12,
    //         Handover_Percentage__c        = 10,
    //         Post_Handover_Period_Months__c = 12,
    //         Construction_Installment_Frequency__c = 'Monthly',
    //         Next_Installment_Due_Date__c  = Date.today()
    //     );
    // }

    // // =========================================================
    // // HELPER — fetch a fully-populated plan by type name
    // // =========================================================
    // private static Payment_Plan__c getPlan(String typeName) {
    //     return [SELECT Id, Payment_Plan__c, Amount__c, Down_Payment_Percentage__c,
    //                    Construction_Period_Months__c, Handover_Percentage__c,
    //                    Post_Handover_Period_Months__c, Rent_Duration_Months__c,
    //                    Total_Rent_Percentage__c, Construction_Installment_Frequency__c,
    //                    Construction_Percentage__c, Next_Installment_Due_Date__c, Payer__c
    //             FROM Payment_Plan__c WHERE Payment_Plan__c = :typeName LIMIT 1];
    // }

    // // =========================================================
    // // HELPER — count Payment_Schedule__c records by Installment_Type__c
    // // =========================================================
    // private static Map<String, Integer> countByType(List<Payment_Schedule__c> schedules) {
    //     Map<String, Integer> result = new Map<String, Integer>();
    //     for (Payment_Schedule__c s : schedules) {
    //         String t = s.Installment_Type__c;
    //         result.put(t, result.containsKey(t) ? result.get(t) + 1 : 1);
    //     }
    //     return result;
    // }

    // /**
    //  * Post-Handover plan insert creates exactly 38 schedules
    //  * with the correct breakdown by installment type and Status = Upcoming.
    //  */
    // @isTest
    // static void testInsert_PostHandover_CreatesCorrectScheduleBreakdown() {
    //     // Arrange
    //     Payment_Plan__c plan = getPlan('Post-Handover');

    //     Test.startTest();
    //     List<Payment_Schedule__c> schedules = [
    //         SELECT Installment_Type__c, Status__c, Amount__c, Due_Date__c
    //         FROM Payment_Schedule__c WHERE Payment_Plan__c = :plan.Id
    //     ];
    //     Test.stopTest();

    //     System.assertEquals(38, schedules.size(), 'Post-Handover plan must produce 38 schedules.');

    //     // Assert — breakdown per type
    //     Map<String, Integer> counts = countByType(schedules);
    //     System.assertEquals(1,  counts.get('Down Payment'),  '1 down-payment schedule expected.');
    //     System.assertEquals(12, counts.get('Construction'),  '12 monthly construction schedules expected.');
    //     System.assertEquals(1,  counts.get('Handover'),      '1 handover schedule expected.');
    //     System.assertEquals(24, counts.get('Post-Handover'), '24 post-handover schedules expected.');

    //     // Assert — all schedules start as Upcoming
    //     for (Payment_Schedule__c s : schedules) {
    //         System.assertEquals('Upcoming', s.Status__c, 'Every new schedule must have Status = Upcoming.');
    //     }
    // }

    // /**
    //  * Standard plan insert produces 14 schedules with no Post-Handover entries.
    //  */
    // @isTest
    // static void testInsert_Standard_NoPostHandoverSchedules() {
    //     Payment_Plan__c plan = getPlan('Standard');

    //     Test.startTest();
    //     List<Payment_Schedule__c> schedules = [
    //         SELECT Installment_Type__c FROM Payment_Schedule__c WHERE Payment_Plan__c = :plan.Id
    //     ];
    //     Test.stopTest();

    //     System.assertEquals(14, schedules.size(), 'Standard plan must produce 14 schedules.');
    //     Map<String, Integer> counts = countByType(schedules);
    //     System.assert(!counts.containsKey('Post-Handover'),
    //         'Standard plan must not have Post-Handover schedules.');
    // }

    // /**
    //  * 10:90 plan insert produces only Down Payment + Handover (2 schedules).
    //  */
    // @isTest
    // static void testInsert_TenNinety_OnlyTwoSchedules() {
    //     Payment_Plan__c plan = getPlan('10:90');

    //     Test.startTest();
    //     List<Payment_Schedule__c> schedules = [
    //         SELECT Installment_Type__c FROM Payment_Schedule__c WHERE Payment_Plan__c = :plan.Id
    //     ];
    //     Test.stopTest();

    //     System.assertEquals(2, schedules.size(), '10:90 plan must produce exactly 2 schedules.');
    //     Map<String, Integer> counts = countByType(schedules);
    //     System.assertEquals(1, counts.get('Down Payment'), '1 down-payment schedule expected.');
    //     System.assertEquals(1, counts.get('Handover'),     '1 handover schedule expected.');
    // }

    // /**
    //  * Rent-to-Own plan insert creates 24 Rent schedules — no Down Payment.
    //  */
    // @isTest
    // static void testInsert_RentToOwn_OnlyRentSchedules() {
    //     Payment_Plan__c plan = getPlan('Rent-to-Own');

    //     Test.startTest();
    //     List<Payment_Schedule__c> schedules = [
    //         SELECT Installment_Type__c, Amount__c FROM Payment_Schedule__c WHERE Payment_Plan__c = :plan.Id
    //     ];
    //     Test.stopTest();

    //     System.assertEquals(24, schedules.size(), 'Rent-to-Own plan must produce 24 rent schedules.');
    //     for (Payment_Schedule__c s : schedules) {
    //         System.assertEquals('Rent', s.Installment_Type__c, 'All schedules must be of type Rent.');
    //     }
    // }

    // /**
    //  * 1% Monthly plan creates 26 schedules including 12 Post-Handover entries.
    //  */
    // @isTest
    // static void testInsert_OnePercentMonthly_HasPostHandoverSchedules() {
    //     Payment_Plan__c plan = getPlan('1% Monthly');

    //     Test.startTest();
    //     List<Payment_Schedule__c> schedules = [
    //         SELECT Installment_Type__c FROM Payment_Schedule__c WHERE Payment_Plan__c = :plan.Id
    //     ];
    //     Test.stopTest();

    //     System.assertEquals(26, schedules.size(), '1% Monthly plan must produce 26 schedules.');
    //     System.assertEquals(12, countByType(schedules).get('Post-Handover'),
    //         '12 post-handover schedules expected for 1% Monthly plan.');
    // }

    // /**
    //  * Sum of all schedule amounts must equal the plan's total amount.
    //  */
    // @isTest
    // static void testInsert_ScheduleAmountsSumToTotalAmount() {
    //     Payment_Plan__c plan = getPlan('Post-Handover');

    //     Test.startTest();
    //     List<Payment_Schedule__c> schedules = [
    //         SELECT Amount__c FROM Payment_Schedule__c WHERE Payment_Plan__c = :plan.Id
    //     ];
    //     Test.stopTest();

    //     Decimal total = 0;
    //     for (Payment_Schedule__c s : schedules) { total += s.Amount__c; }
    //     System.assertEquals(plan.Amount__c, total.setScale(2),
    //         'Sum of all schedule amounts must equal the plan total amount.');
    // }

    // /**
    //  * Quarterly frequency: ceil(12/3) = 4 construction installments produced.
    //  */
    // @isTest
    // static void testInsert_QuarterlyFrequency_FourConstructionInstallments() {
    //     Test.startTest();
    //     Payment_Plan__c plan = new Payment_Plan__c(
    //         Payment_Plan__c               = 'Post-Handover',
    //         Amount__c                     = 1000000,
    //         Down_Payment_Percentage__c    = 10,
    //         Construction_Period_Months__c = 12,
    //         Handover_Percentage__c        = 10,
    //         Post_Handover_Period_Months__c = 12,
    //         Construction_Installment_Frequency__c = 'Quarterly',
    //         Next_Installment_Due_Date__c  = Date.today()
    //     );
    //     insert plan;
    //     Test.stopTest();

    //     List<Payment_Schedule__c> schedules = [
    //         SELECT Installment_Type__c FROM Payment_Schedule__c WHERE Payment_Plan__c = :plan.Id
    //     ];
    //     System.assertEquals(18, schedules.size(), 'Quarterly plan must produce 18 schedules.');
    //     System.assertEquals(4, countByType(schedules).get('Construction'),
    //         'Quarterly frequency must produce 4 construction installments over 12 months.');
    // }

    // /**
    //  * Semi-Annual frequency
    //  */
    // @isTest
    // static void testInsert_SemiAnnualFrequency_TwoConstructionInstallments() {
    //     Test.startTest();
    //     Payment_Plan__c plan = new Payment_Plan__c(
    //         Payment_Plan__c               = 'Post-Handover',
    //         Amount__c                     = 1000000,
    //         Down_Payment_Percentage__c    = 10,
    //         Construction_Period_Months__c = 12,
    //         Handover_Percentage__c        = 10,
    //         Post_Handover_Period_Months__c = 12,
    //         Construction_Installment_Frequency__c = 'Semi-Annually',
    //         Next_Installment_Due_Date__c  = Date.today()
    //     );
    //     insert plan;
    //     Test.stopTest();

    //     List<Payment_Schedule__c> schedules = [
    //         SELECT Installment_Type__c FROM Payment_Schedule__c WHERE Payment_Plan__c = :plan.Id
    //     ];
    //     System.assertEquals(2, countByType(schedules).get('Construction'),
    //         'Semi-Annual frequency must produce 2 construction installments over 12 months.');
    // }

    // /**
    //  * Schedule due dates must be non-decreasing.
    //  */
    // @isTest
    // static void testInsert_DueDatesAreNonDecreasing() {
    //     Payment_Plan__c plan = getPlan('Post-Handover');

    //     Test.startTest();
    //     List<Payment_Schedule__c> schedules = [
    //         SELECT Due_Date__c, Next_Installment_Index__c
    //         FROM Payment_Schedule__c WHERE Payment_Plan__c = :plan.Id
    //         ORDER BY Next_Installment_Index__c ASC
    //     ];
    //     Test.stopTest();

    //     // First schedule due date must equal the plan start date
    //     System.assertEquals(plan.Next_Installment_Due_Date__c, schedules[0].Due_Date__c,
    //         'First schedule due date must equal the plan start date.');

    //     for (Integer i = 1; i < schedules.size(); i++) {
    //         System.assert(schedules[i].Due_Date__c >= schedules[i - 1].Due_Date__c,
    //             'Schedule due dates must be non-decreasing.');
    //     }
    // }

    // /**
    //  * A Post-Handover plan missing required fields is skipped — no schedules created.
    //  */
    // @isTest
    // static void testInsert_MissingRequiredFields_NoSchedulesCreated() {
    //     Test.startTest();
    //     Payment_Plan__c invalid = new Payment_Plan__c(
    //         Payment_Plan__c               = 'Post-Handover',
    //         Amount__c                     = 500000,
    //         Down_Payment_Percentage__c    = 10,
    //         Next_Installment_Due_Date__c  = Date.today()
    //     );
    //     insert invalid;
    //     Test.stopTest();

    //     System.assertEquals(0,
    //         [SELECT COUNT() FROM Payment_Schedule__c WHERE Payment_Plan__c = :invalid.Id],
    //         'Invalid plan must not generate any schedules.');
    // }

    // /**
    //  * Rent-to-Own plan missing Rent_Duration_Months__c and Total_Rent_Percentage__c is skipped.
    //  */
    // @isTest
    // static void testInsert_RentToOwn_MissingRentFields_NoSchedulesCreated() {
    //     Test.startTest();
    //     Payment_Plan__c invalid = new Payment_Plan__c(
    //         Payment_Plan__c              = 'Rent-to-Own',
    //         Amount__c                    = 400000,
    //         Next_Installment_Due_Date__c = Date.today()
    //     );
    //     insert invalid;
    //     Test.stopTest();

    //     System.assertEquals(0,
    //         [SELECT COUNT() FROM Payment_Schedule__c WHERE Payment_Plan__c = :invalid.Id],
    //         'Rent-to-Own plan with missing rent fields must not generate schedules.');
    // }

    // /**
    //  * handleAfterInsert with an empty list does not throw.
    //  */
    // @isTest
    // static void testHandleAfterInsert_EmptyList_NoError() {
    //     Test.startTest();
    //     PaymentPlanTriggerHandler.handleAfterInsert(new List<Payment_Plan__c>());
    //     Test.stopTest();
    //     System.assert(true, 'Empty list must not cause an exception in handleAfterInsert.');
    // }

    // /**
    //  * Updating Amount__c on a Post-Handover plan triggers an in-place update
    //  */
    // @isTest
    // static void testUpdate_AmountChange_UpdatesSchedulesInPlace() {
    //     Payment_Plan__c plan = getPlan('Post-Handover');
    //     System.assertEquals(38,
    //         [SELECT COUNT() FROM Payment_Schedule__c WHERE Payment_Plan__c = :plan.Id],
    //         'Precondition: plan must have 38 schedules before update.');

    //     Test.startTest();
    //     plan.Amount__c = 2000000;
    //     update plan;
    //     Test.stopTest();

    //     System.assertEquals(38,
    //         [SELECT COUNT() FROM Payment_Schedule__c WHERE Payment_Plan__c = :plan.Id],
    //         'Schedule count must remain 38 after an amount-only update.');
    // }

    // /**
    //  * Changing construction frequency Monthly → Quarterly forces recreation
    //  */
    // @isTest
    // static void testUpdate_FrequencyChange_RecreatesSchedules() {
    //     Payment_Plan__c plan = getPlan('Post-Handover');

    //     Test.startTest();
    //     plan.Construction_Installment_Frequency__c = 'Quarterly';
    //     update plan;
    //     Test.stopTest();

    //     List<Payment_Schedule__c> schedules = [
    //         SELECT Installment_Type__c FROM Payment_Schedule__c WHERE Payment_Plan__c = :plan.Id
    //     ];
    //     System.assertEquals(30, schedules.size(),
    //         'Switching to Quarterly must recreate schedules resulting in 30 total.');
    //     System.assertEquals(4, countByType(schedules).get('Construction'),
    //         'Recreated plan must have 4 quarterly construction schedules.');
    // }

    // /**
    //  * Changing Rent_Duration_Months__c on a Rent-to-Own plan recreates schedules
    //  * from 24 down to 12.
    //  */
    // @isTest
    // static void testUpdate_RentToOwn_DurationChange_RecreatesSchedules() {
    //     Payment_Plan__c plan = getPlan('Rent-to-Own');

    //     Test.startTest();
    //     plan.Rent_Duration_Months__c = 12;
    //     update plan;
    //     Test.stopTest();

    //     System.assertEquals(12,
    //         [SELECT COUNT() FROM Payment_Schedule__c WHERE Payment_Plan__c = :plan.Id],
    //         'After reducing rent duration to 12, exactly 12 rent schedules must exist.');
    // }

    // /**
    //  * Updating a field that is NOT tracked by hasPlanChanged leaves schedules untouched.
    //  */
    // @isTest
    // static void testUpdate_UntrackedFieldChange_SchedulesUnchanged() {
    //     Payment_Plan__c plan = getPlan('Standard');
    //     Integer beforeCount = [SELECT COUNT() FROM Payment_Schedule__c WHERE Payment_Plan__c = :plan.Id];

    //     Test.startTest();
    //     update plan; 
    //     Test.stopTest();

    //     System.assertEquals(beforeCount,
    //         [SELECT COUNT() FROM Payment_Schedule__c WHERE Payment_Plan__c = :plan.Id],
    //         'Schedule count must not change when no tracked field is updated.');
    // }

    // /**
    //  * Paid schedules survive a recreation triggered by a frequency change.
    //  */
    // @isTest
    // static void testUpdate_FrequencyChange_PaidSchedulesNotDeleted() {
    //     Payment_Plan__c plan = getPlan('Post-Handover');

    //     Payment_Schedule__c dp = [
    //         SELECT Id, Status__c FROM Payment_Schedule__c
    //         WHERE Payment_Plan__c = :plan.Id AND Installment_Type__c = 'Down Payment' LIMIT 1
    //     ];
    //     dp.Status__c = 'Paid';
    //     update dp;

    //     Test.startTest();
    //     plan.Construction_Installment_Frequency__c = 'Quarterly';
    //     update plan;
    //     Test.stopTest();

    //     List<Payment_Schedule__c> paid = [
    //         SELECT Id, Status__c FROM Payment_Schedule__c
    //         WHERE Payment_Plan__c = :plan.Id AND Status__c = 'Paid'
    //     ];
    //     System.assert(!paid.isEmpty(), 'Paid schedules must not be deleted during a recreation.');
    //     System.assertEquals('Paid', paid[0].Status__c, 'Preserved schedule must still be Paid.');
    // }

    // /**
    //  * Paid schedules must not be overwritten by updateExistingSchedules.
    //  */
    // @isTest
    // static void testUpdate_PaidScheduleAmountNotModified() {
    //     Payment_Plan__c plan = getPlan('Standard');

    //     Payment_Schedule__c dp = [
    //         SELECT Id, Status__c, Amount__c FROM Payment_Schedule__c
    //         WHERE Payment_Plan__c = :plan.Id AND Installment_Type__c = 'Down Payment' LIMIT 1
    //     ];
    //     Decimal originalAmount = dp.Amount__c;
    //     dp.Status__c = 'Paid';
    //     update dp;

    //     Test.startTest();
    //     plan.Amount__c = 999999;
    //     update plan;
    //     Test.stopTest();

    //     Payment_Schedule__c refreshed = [SELECT Amount__c FROM Payment_Schedule__c WHERE Id = :dp.Id];
    //     System.assertEquals(originalAmount, refreshed.Amount__c,
    //         'Paid schedule amount must not be modified by updateExistingSchedules.');
    // }

    // /**
    //  * handleAfterUpdate with empty collections does not throw.
    //  */
    // @isTest
    // static void testHandleAfterUpdate_EmptyCollections_NoError() {
    //     Test.startTest();
    //     PaymentPlanTriggerHandler.handleAfterUpdate(
    //         new List<Payment_Plan__c>(),
    //         new Map<Id, Payment_Plan__c>()
    //     );
    //     Test.stopTest();
    //     System.assert(true, 'Empty collections must not cause an exception in handleAfterUpdate.');
    // }

    // /**
    //  * Deleting a Standard plan removes all its unpaid schedules.
    //  */
    // @isTest
    // static void testDelete_StandardPlan_AllUnpaidSchedulesRemoved() {
    //     Payment_Plan__c plan = getPlan('Standard');
    //     System.assert(
    //         [SELECT COUNT() FROM Payment_Schedule__c WHERE Payment_Plan__c = :plan.Id] > 0,
    //         'Precondition: schedules must exist before deletion.'
    //     );

    //     Test.startTest();
    //     delete plan;
    //     Test.stopTest();

    //     System.assertEquals(0,
    //         [SELECT COUNT() FROM Payment_Schedule__c WHERE Payment_Plan__c = :plan.Id],
    //         'All unpaid schedules must be deleted when a plan is deleted.');
    // }

    // /**
    //  * Deleting a plan preserves Paid schedules (handleAfterDelete skips Status = Paid).
    //  */
    // @isTest
    // static void testDelete_PaidSchedulesPreservedAfterPlanDelete() {
    //     Payment_Plan__c plan = getPlan('10:90');

    //     // Mark Down Payment as Paid
    //     Payment_Schedule__c dp = [
    //         SELECT Id FROM Payment_Schedule__c
    //         WHERE Payment_Plan__c = :plan.Id AND Installment_Type__c = 'Down Payment' LIMIT 1
    //     ];
    //     dp.Status__c = 'Paid';
    //     update dp;

    //     Test.startTest();
    //     delete plan;
    //     Test.stopTest();

    //     List<Payment_Schedule__c> paid = [SELECT Id, Status__c FROM Payment_Schedule__c WHERE Id = :dp.Id];
    //     System.assertEquals(1, paid.size(), 'Paid schedule must survive plan deletion.');
    //     System.assertEquals('Paid', paid[0].Status__c, 'Schedule must still be Paid after plan deletion.');
    // }

    // /**
    //  * handleAfterDelete with an empty list does not throw.
    //  */
    // @isTest
    // static void testHandleAfterDelete_EmptyList_NoError() {
    //     Test.startTest();
    //     PaymentPlanTriggerHandler.handleAfterDelete(new List<Payment_Plan__c>());
    //     Test.stopTest();
    //     System.assert(true, 'Empty list must not cause an exception in handleAfterDelete.');
    // }

    // /**
    //  * Bulk insert: 50 Standard plans each produce 8 schedules = 400 total.
    //  */
    // @isTest
    // static void testBulkInsert_FiftyStandardPlans_AllGetSchedules() {
    //     List<Payment_Plan__c> plans = new List<Payment_Plan__c>();
    //     for (Integer i = 0; i < 50; i++) {
    //         plans.add(new Payment_Plan__c(
    //             Payment_Plan__c               = 'Standard',
    //             Amount__c                     = 100000 + i,
    //             Down_Payment_Percentage__c    = 20,
    //             Construction_Period_Months__c = 6,
    //             Handover_Percentage__c        = 10,
    //             Construction_Percentage__c    = 70,
    //             Construction_Installment_Frequency__c = 'Monthly',
    //             Next_Installment_Due_Date__c  = Date.today()
    //         ));
    //     }

    //     Test.startTest();
    //     insert plans;
    //     Test.stopTest();

    //     Set<Id> planIds = new Map<Id, Payment_Plan__c>(plans).keySet();
    //     System.assertEquals(50 * 8,
    //         [SELECT COUNT() FROM Payment_Schedule__c WHERE Payment_Plan__c IN :planIds],
    //         'Each of the 50 Standard plans must have 8 schedules (400 total).');
    // }

    // /**
    //  * Bulk update: 20 plans updated — schedule counts remain correct.
    //  */
    // @isTest
    // static void testBulkUpdate_TwentyPlans_AllSchedulesUpdated() {
    //     List<Payment_Plan__c> plans = new List<Payment_Plan__c>();
    //     for (Integer i = 0; i < 20; i++) {
    //         plans.add(new Payment_Plan__c(
    //             Payment_Plan__c               = 'Standard',
    //             Amount__c                     = 200000,
    //             Down_Payment_Percentage__c    = 20,
    //             Construction_Period_Months__c = 6,
    //             Handover_Percentage__c        = 10,
    //             Construction_Percentage__c    = 70,
    //             Construction_Installment_Frequency__c = 'Monthly',
    //             Next_Installment_Due_Date__c  = Date.today()
    //         ));
    //     }
    //     insert plans;

    //     Test.startTest();
    //     for (Payment_Plan__c p : plans) { p.Amount__c = 300000; }
    //     update plans;
    //     Test.stopTest();

    //     Set<Id> planIds = new Map<Id, Payment_Plan__c>(plans).keySet();
    //     System.assertEquals(20 * 8,
    //         [SELECT COUNT() FROM Payment_Schedule__c WHERE Payment_Plan__c IN :planIds],
    //         'All 20 plans must still have 8 schedules each after a bulk amount update.');
    // }

    // /**
    //  * Bulk delete: 20 plans deleted — all unpaid schedules removed.
    //  */
    // @isTest
    // static void testBulkDelete_TwentyPlans_AllSchedulesRemoved() {
    //     List<Payment_Plan__c> plans = new List<Payment_Plan__c>();
    //     for (Integer i = 0; i < 20; i++) {
    //         plans.add(new Payment_Plan__c(
    //             Payment_Plan__c               = '10:90',
    //             Amount__c                     = 500000,
    //             Down_Payment_Percentage__c    = 10,
    //             Construction_Period_Months__c = 3,
    //             Handover_Percentage__c        = 90,
    //             Next_Installment_Due_Date__c  = Date.today()
    //         ));
    //     }
    //     insert plans;
    //     Set<Id> planIds = new Map<Id, Payment_Plan__c>(plans).keySet();

    //     Test.startTest();
    //     delete plans;
    //     Test.stopTest();

    //     System.assertEquals(0,
    //         [SELECT COUNT() FROM Payment_Schedule__c WHERE Payment_Plan__c IN :planIds],
    //         'All schedules for 20 deleted plans must be removed.');
    // }
}