public with sharing class PaymentPlanTriggerHandler {
    // Handle after insert: Processes new Payment_Plan__c records to create related Payment_Schedule__c records
    public static void handleAfterInsert(List<Payment_Plan__c> newPaymentPlans) {
        List<Payment_Schedule__c> schedulesToInsert = new List<Payment_Schedule__c>();
        
        for (Payment_Plan__c plan : newPaymentPlans) {
            if (isValidPaymentPlan(plan)) {
                createPaymentSchedules(plan, schedulesToInsert);
            } 
        }

        insertSchedules(schedulesToInsert);
    }

    // Handle after update: Processes updated Payment_Plan__c records to update or recreate related Payment_Schedule__c records
    public static void handleAfterUpdate(List<Payment_Plan__c> newPlans, Map<Id, Payment_Plan__c> oldPlansMap) {
        List<Payment_Schedule__c> schedulesToInsert = new List<Payment_Schedule__c>();
        List<Payment_Schedule__c> schedulesToUpdate = new List<Payment_Schedule__c>();
        Set<Id> planIdsToProcess = new Set<Id>();
        Set<Id> planIdsToRecreate = new Set<Id>();
        
        for (Payment_Plan__c newPlan : newPlans) {
            Payment_Plan__c oldPlan = oldPlansMap.get(newPlan.Id);
            if (isValidPaymentPlan(newPlan) && hasPlanChanged(newPlan, oldPlan)) {
                planIdsToProcess.add(newPlan.Id);
            }
        }

        if (!planIdsToProcess.isEmpty()) {
            Map<Id, List<Payment_Schedule__c>> schedulesByPlanId = new Map<Id, List<Payment_Schedule__c>>();
            for (Payment_Schedule__c schedule : [SELECT Id, Payment_Plan__c, Installment_Type__c, Amount__c, Due_Date__c, Percentage__c, Status__c, Next_Installment_Index__c
                                                    FROM Payment_Schedule__c WHERE Payment_Plan__c IN :planIdsToProcess WITH USER_MODE ORDER BY Payment_Plan__c, Due_Date__c ASC]) {
                if (!schedulesByPlanId.containsKey(schedule.Payment_Plan__c)) {
                    schedulesByPlanId.put(schedule.Payment_Plan__c, new List<Payment_Schedule__c>());
                }
                schedulesByPlanId.get(schedule.Payment_Plan__c).add(schedule);
            }

            for (Payment_Plan__c newPlan : newPlans) {
                if (!planIdsToProcess.contains(newPlan.Id)) {
                    continue;
                }

                Integer expectedSchedules = calculateExpectedSchedules(newPlan);
                List<Payment_Schedule__c> existingSchedules = schedulesByPlanId.containsKey(newPlan.Id) 
                    ? schedulesByPlanId.get(newPlan.Id) 
                    : new List<Payment_Schedule__c>();

                if (existingSchedules.size() != expectedSchedules) {
                    planIdsToRecreate.add(newPlan.Id);
                    createPaymentSchedules(newPlan, schedulesToInsert);
                } else {
                    updateExistingSchedules(newPlan, existingSchedules, schedulesToUpdate);
                }
            }

            if (!planIdsToRecreate.isEmpty()) {
                List<Payment_Schedule__c> schedulesToDelete = [SELECT Id FROM Payment_Schedule__c WHERE Payment_Plan__c IN :planIdsToRecreate AND Status__c != 'Paid' WITH USER_MODE];
                try {
                    if (!schedulesToDelete.isEmpty()) {
                        delete as user schedulesToDelete;
                    }
                } catch (Exception e) {
                    ErrorHandler.insertErrorData(e, 'PaymentPlanTriggerHandler', 'handleAfterUpdate', 'Error while deleting Payment_Schedule__c records.');
                    for (Payment_Plan__c plan : newPlans) {
                        if (planIdsToRecreate.contains(plan.Id)) {
                            plan.addError('Failed to delete existing schedules: ' + e.getMessage());
                        }
                    }
                    return;
                }

                insertSchedules(schedulesToInsert);
            }

            if (!schedulesToUpdate.isEmpty()) {
                try {
                    update as user schedulesToUpdate;
                } catch (Exception e) {
                    ErrorHandler.insertErrorData(e, 'PaymentPlanTriggerHandler', 'handleAfterUpdate', 'Error while updating Payment_Schedule__c records.');
                }
            }
        }
    }

    // Handle after delete: Deletes unpaid Payment_Schedule__c records related to deleted Payment_Plan__c records
    public static void handleAfterDelete(List<Payment_Plan__c> oldPlans) {
        Set<Id> planIds = new Set<Id>();
        for (Payment_Plan__c plan : oldPlans) {
            planIds.add(plan.Id);
        }

        List<Payment_Schedule__c> schedulesToDelete = [SELECT Id, Payment_Plan__c, Status__c FROM Payment_Schedule__c WHERE Payment_Plan__c IN :planIds WITH USER_MODE];
        
        List<Payment_Schedule__c> unpaidSchedulesToDelete = new List<Payment_Schedule__c>();
        for (Payment_Schedule__c schedule : schedulesToDelete) {
            if (schedule.Status__c != 'Paid') {
                unpaidSchedulesToDelete.add(schedule);
            }
        }

        if (!unpaidSchedulesToDelete.isEmpty()) {
            try {
                delete as user unpaidSchedulesToDelete;
            } catch (Exception e) {
                ErrorHandler.insertErrorData(e, 'PaymentPlanTriggerHandler', 'handleAfterDelete', 'Error while deleting Payment_Schedule__c records.');
            }
        } 
    }

    // Helper method to validate Payment_Plan__c record
    private static Boolean isValidPaymentPlan(Payment_Plan__c plan) {
        Boolean isValid = plan.Payment_Plan__c != null && 
                          plan.Amount__c != null && 
                          plan.Next_Installment_Due_Date__c != null;
        if (plan.Payment_Plan__c != 'Rent-to-Own') {
            isValid = isValid && plan.Down_Payment_Percentage__c != null && 
                      plan.Construction_Period_Months__c != null && 
                      plan.Handover_Percentage__c != null;
        }
        if (plan.Payment_Plan__c == 'Rent-to-Own') {
            isValid = isValid && plan.Rent_Duration_Months__c != null && 
                      plan.Total_Rent_Percentage__c != null;
        } else if (plan.Payment_Plan__c != 'Standard' && plan.Payment_Plan__c != '10:90') {
            isValid = isValid && plan.Post_Handover_Period_Months__c != null;
        }
        return isValid;
    }

    // Helper method to check if plan has changed
    private static Boolean hasPlanChanged(Payment_Plan__c newPlan, Payment_Plan__c oldPlan) {
        Boolean hasChanged = newPlan.Amount__c != oldPlan.Amount__c ||
                            newPlan.Down_Payment_Percentage__c != oldPlan.Down_Payment_Percentage__c ||
                            newPlan.Construction_Period_Months__c != oldPlan.Construction_Period_Months__c ||
                            newPlan.Handover_Percentage__c != oldPlan.Handover_Percentage__c ||
                            newPlan.Post_Handover_Period_Months__c != oldPlan.Post_Handover_Period_Months__c ||
                            newPlan.Payment_Plan__c != oldPlan.Payment_Plan__c ||
                            newPlan.Construction_Installment_Frequency__c != oldPlan.Construction_Installment_Frequency__c ||
                            newPlan.Rent_Duration_Months__c != oldPlan.Rent_Duration_Months__c ||
                            newPlan.Total_Rent_Percentage__c != oldPlan.Total_Rent_Percentage__c ||
                            newPlan.Next_Installment_Due_Date__c != oldPlan.Next_Installment_Due_Date__c;
        return hasChanged;
    }

    // Helper method to calculate expected number of schedules
    private static Integer calculateExpectedSchedules(Payment_Plan__c plan) {
        Integer constructionMonths = (Integer)plan.Construction_Period_Months__c;
        Integer postHandoverMonths = (Integer)plan.Post_Handover_Period_Months__c;
        Integer rentDurationMonths = (Integer)plan.Rent_Duration_Months__c;
        String frequency = plan.Construction_Installment_Frequency__c != null ? plan.Construction_Installment_Frequency__c : 'Monthly';
        
        Integer constructionInstallments = 0;
        if (plan.Payment_Plan__c != 'Rent-to-Own' && plan.Payment_Plan__c != '10:90') {
            if (frequency == 'Monthly') {
                constructionInstallments = constructionMonths;
            } else if (frequency == 'Quarterly') {
                constructionInstallments = (Integer)Math.ceil(constructionMonths / 3.0);
            } else if (frequency == 'Semi-Annually') {
                constructionInstallments = (Integer)Math.ceil(constructionMonths / 6.0);
            } else {
                constructionInstallments = constructionMonths;
            }
        }

        Integer expectedSchedules;
        if (plan.Payment_Plan__c == '10:90') {
            expectedSchedules = 1 + 1; // Down Payment + Handover
        } else if (plan.Payment_Plan__c == 'Rent-to-Own') {
            expectedSchedules = rentDurationMonths != null ? rentDurationMonths : 0; // Number of rent payments
        } else if (plan.Payment_Plan__c == 'Standard') {
            expectedSchedules = 1 + constructionInstallments + 1; // Down Payment + Construction + Handover (no post-handover)
        } else {
            expectedSchedules = 1 + constructionInstallments + 1 + postHandoverMonths; // Down Payment + Construction + Handover + Post-Handover
        }
        
        return expectedSchedules;
    }

    // Helper method to create Payment_Schedule__c records
    private static void createPaymentSchedules(Payment_Plan__c plan, List<Payment_Schedule__c> schedulesToInsert) {
        try {
            Decimal totalAmount = plan.Amount__c;
            Decimal downPaymentPercent = plan.Down_Payment_Percentage__c;
            Integer constructionMonths = (Integer)plan.Construction_Period_Months__c;
            Decimal handoverPercent = plan.Handover_Percentage__c;
            Integer postHandoverMonths = (Integer)plan.Post_Handover_Period_Months__c;
            Integer rentDurationMonths = (Integer)plan.Rent_Duration_Months__c;
            Decimal totalRentPercent = plan.Total_Rent_Percentage__c;
            String frequency = plan.Construction_Installment_Frequency__c != null ? plan.Construction_Installment_Frequency__c : 'Monthly';
            Decimal constructionPercent = plan.Construction_Percentage__c != null ? plan.Construction_Percentage__c : 
                (plan.Payment_Plan__c == 'Standard' ? 100 - downPaymentPercent - handoverPercent : 10.0);
            Date startDate = plan.Next_Installment_Due_Date__c;

            if (plan.Payment_Plan__c != 'Rent-to-Own' && (constructionMonths <= 0 || handoverPercent <= 0 || (plan.Payment_Plan__c != 'Standard' && postHandoverMonths <= 0) || startDate == null)) {
                throw new PaymentPlanTriggerHandlerException('Construction Period, Handover Percentage, Post-Handover Period, and Next Installment Due Date must be valid for non-Rent-to-Own plans.');
            }

            if (plan.Payment_Plan__c == 'Standard' && (downPaymentPercent + handoverPercent + constructionPercent) != 100) {
                throw new PaymentPlanTriggerHandlerException('Total percentage for Standard plan must equal 100%.');
            }

            Decimal downPaymentAmount = 0;
            Decimal handoverAmount = 0;
            if (plan.Payment_Plan__c != 'Rent-to-Own' ){
                downPaymentAmount = (downPaymentPercent / 100) * totalAmount;
                handoverAmount = (handoverPercent / 100) * totalAmount;
            }

            Integer constructionInstallments = 0;
            Integer monthsPerInstallment = 1;
            if (plan.Payment_Plan__c != 'Rent-to-Own' && plan.Payment_Plan__c != '10:90') {
                if (frequency == 'Monthly') {
                    constructionInstallments = constructionMonths;
                    monthsPerInstallment = 1;
                } else if (frequency == 'Quarterly') {
                    constructionInstallments = (Integer)Math.ceil(constructionMonths / 3.0);
                    monthsPerInstallment = 3;
                } else if (frequency == 'Semi-Annually') {
                    constructionInstallments = (Integer)Math.ceil(constructionMonths / 6.0);
                    monthsPerInstallment = 6;
                } else {
                    constructionInstallments = constructionMonths;
                    monthsPerInstallment = 1;
                }
            }

            Decimal totalConstructionPayments = downPaymentAmount + (constructionPercent / 100) * totalAmount;
            Decimal remainingAfterHandover;
            if (plan.Payment_Plan__c == '10:90') {
                totalConstructionPayments = downPaymentAmount;
                remainingAfterHandover = totalAmount - downPaymentAmount - handoverAmount;
            } else if (plan.Payment_Plan__c == 'Rent-to-Own') {
                totalConstructionPayments = 0; // No construction payments for Rent-to-Own
                remainingAfterHandover = 0; // Handled by rent payments
            } else if (plan.Payment_Plan__c == 'Standard') {
                totalConstructionPayments = downPaymentAmount + ((constructionPercent / 100) * totalAmount);
                remainingAfterHandover = totalAmount - totalConstructionPayments - handoverAmount;
            } else {
                totalConstructionPayments = downPaymentAmount + (constructionPercent / 100) * totalAmount;
                remainingAfterHandover = totalAmount - totalConstructionPayments - handoverAmount;
            }

            if (remainingAfterHandover < 0 && plan.Payment_Plan__c != 'Rent-to-Own' && plan.Payment_Plan__c != 'Standard') {
                throw new PaymentPlanTriggerHandlerException('Payment percentages result in a negative remaining balance.');
            }

            Decimal postHandoverMonthlyAmount = (plan.Payment_Plan__c != 'Standard' && plan.Payment_Plan__c != 'Rent-to-Own' && postHandoverMonths > 0) ? remainingAfterHandover / postHandoverMonths : 0;

            Integer installmentIndex = 0;

            if (plan.Payment_Plan__c != 'Rent-to-Own' ) {
                Payment_Schedule__c downPayment = new Payment_Schedule__c(
                    Payment_Plan__c = plan.Id,
                    Payer__c = plan.Payer__c,
                    Amount__c = downPaymentAmount,
                    Due_Date__c = startDate,
                    Percentage__c = downPaymentPercent,
                    Status__c = 'Upcoming',
                    Installment_Type__c = 'Down Payment',
                    Next_Installment_Index__c = installmentIndex++
                );
                schedulesToInsert.add(downPayment);
            }

            if (plan.Payment_Plan__c == 'Rent-to-Own' && rentDurationMonths != null && totalRentPercent != null) {
                Decimal totalRentAmount = (totalRentPercent / 100) * totalAmount;
                Decimal monthlyRentAmount = totalRentAmount / rentDurationMonths;

                for (Integer i = 0; i < rentDurationMonths; i++) {
                    Payment_Schedule__c rentPayment = new Payment_Schedule__c(
                        Payment_Plan__c = plan.Id,
                        Payer__c = plan.Payer__c,
                        Amount__c = monthlyRentAmount,
                        Due_Date__c = startDate.addMonths(i + 1),
                        Percentage__c = (monthlyRentAmount / totalAmount) * 100,
                        Status__c = 'Upcoming',
                        Installment_Type__c = 'Rent',
                        Next_Installment_Index__c = installmentIndex++
                    );
                    schedulesToInsert.add(rentPayment);
                }
            } else if (plan.Payment_Plan__c != '10:90') {
                if (plan.Payment_Plan__c != 'Rent-to-Own') {
                    Decimal constructionTotal = (constructionPercent / 100) * totalAmount;
                    for (Integer i = 1; i <= constructionInstallments; i++) {
                        Payment_Schedule__c constructionPayment = new Payment_Schedule__c(
                            Payment_Plan__c = plan.Id,
                            Payer__c = plan.Payer__c,
                            Amount__c = constructionTotal / constructionInstallments,
                            Due_Date__c = startDate.addMonths(i * monthsPerInstallment),
                            Percentage__c = (constructionPercent / constructionInstallments),
                            Status__c = 'Upcoming',
                            Installment_Type__c = 'Construction',
                            Next_Installment_Index__c = installmentIndex++
                        );
                        schedulesToInsert.add(constructionPayment);
                    }
                }
            }

            if (plan.Payment_Plan__c != 'Rent-to-Own') {
                Payment_Schedule__c handoverPayment = new Payment_Schedule__c(
                    Payment_Plan__c = plan.Id,
                    Payer__c = plan.Payer__c,
                    Amount__c = handoverAmount,
                    Due_Date__c = startDate.addMonths(constructionMonths),
                    Percentage__c = handoverPercent,
                    Status__c = 'Upcoming',
                    Installment_Type__c = 'Handover',
                    Next_Installment_Index__c = installmentIndex++
                );
                schedulesToInsert.add(handoverPayment);
            }

            if ((plan.Payment_Plan__c == 'Post-Handover' || plan.Payment_Plan__c == '1% Monthly') && plan.Payment_Plan__c != 'Rent-to-Own' && postHandoverMonths > 0) {
                for (Integer i = 1; i <= postHandoverMonths; i++) {
                    Payment_Schedule__c postHandoverPayment = new Payment_Schedule__c(
                        Payment_Plan__c = plan.Id,
                        Payer__c = plan.Payer__c,
                        Amount__c = postHandoverMonthlyAmount,
                        Due_Date__c = startDate.addMonths(constructionMonths + i),
                        Percentage__c = (postHandoverMonthlyAmount / totalAmount) * 100,
                        Status__c = 'Upcoming',
                        Installment_Type__c = 'Post-Handover',
                        Next_Installment_Index__c = installmentIndex++
                    );
                    schedulesToInsert.add(postHandoverPayment);
                }
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'PaymentPlanTriggerHandler', 'createPaymentSchedules', 'Error while creating Payment_Schedule__c records.');
            plan.addError('Failed to create schedules: ' + e.getMessage());
        }
    }

    // Helper method to update existing Payment_Schedule__c records
    private static void updateExistingSchedules(Payment_Plan__c plan, List<Payment_Schedule__c> existingSchedules, List<Payment_Schedule__c> schedulesToUpdate) {
        try {
            Decimal totalAmount = plan.Amount__c;
            Decimal downPaymentPercent = plan.Down_Payment_Percentage__c;
            Integer constructionMonths = (Integer)plan.Construction_Period_Months__c;
            Decimal handoverPercent = plan.Handover_Percentage__c;
            Integer postHandoverMonths = (Integer)plan.Post_Handover_Period_Months__c;
            Integer rentDurationMonths = (Integer)plan.Rent_Duration_Months__c;
            Decimal totalRentPercent = plan.Total_Rent_Percentage__c;
            String frequency = plan.Construction_Installment_Frequency__c != null ? plan.Construction_Installment_Frequency__c : 'Monthly';
            Decimal constructionPercent = plan.Construction_Percentage__c != null ? plan.Construction_Percentage__c : 
                (plan.Payment_Plan__c == 'Standard' ? 100 - downPaymentPercent - handoverPercent : 10.0);
            Date startDate = plan.Next_Installment_Due_Date__c;

            if (plan.Payment_Plan__c != 'Rent-to-Own' && (constructionMonths <= 0 || handoverPercent <= 0 || (plan.Payment_Plan__c != 'Standard' && postHandoverMonths <= 0) || startDate == null)) {
                throw new PaymentPlanTriggerHandlerException('Construction Period, Handover Percentage, Post-Handover Period, and Next Installment Due Date must be valid for non-Rent-to-Own plans.');
            }

            if (plan.Payment_Plan__c == 'Standard' && (downPaymentPercent + handoverPercent + constructionPercent) != 100) {
                throw new PaymentPlanTriggerHandlerException('Total percentage for Standard plan must equal 100%.');
            }

            Decimal downPaymentAmount = 0;
            Decimal handoverAmount = 0;
            if(plan.Payment_Plan__c == 'Rent-to-Own' && rentDurationMonths <= 0) {
                downPaymentAmount = (downPaymentPercent / 100) * totalAmount;
                handoverAmount = (handoverPercent / 100) * totalAmount;
            }

            Integer constructionInstallments = 0;
            Integer monthsPerInstallment = 1;
            if (plan.Payment_Plan__c != 'Rent-to-Own' && plan.Payment_Plan__c != '10:90') {
                if (frequency == 'Monthly') {
                    constructionInstallments = constructionMonths;
                    monthsPerInstallment = 1;
                } else if (frequency == 'Quarterly') {
                    constructionInstallments = (Integer)Math.ceil(constructionMonths / 3.0);
                    monthsPerInstallment = 3;
                } else if (frequency == 'Semi-Annually') {
                    constructionInstallments = (Integer)Math.ceil(constructionMonths / 6.0);
                    monthsPerInstallment = 6;
                } else {
                    constructionInstallments = constructionMonths;
                    monthsPerInstallment = 1;
                }
            }

            Decimal totalConstructionPayments;
            Decimal remainingAfterHandover;
            if (plan.Payment_Plan__c == '10:90') {
                totalConstructionPayments = downPaymentAmount;
                remainingAfterHandover = totalAmount - downPaymentAmount - handoverAmount;
            } else if (plan.Payment_Plan__c == 'Rent-to-Own') {
                totalConstructionPayments = 0; // No construction payments for Rent-to-Own
                remainingAfterHandover = 0; // Handled by rent payments
            } else if (plan.Payment_Plan__c == 'Standard') {
                totalConstructionPayments = downPaymentAmount + ((constructionPercent / 100) * totalAmount);
                remainingAfterHandover = totalAmount - totalConstructionPayments - handoverAmount;
            } else {
                totalConstructionPayments = downPaymentAmount + (constructionPercent / 100) * totalAmount;
                remainingAfterHandover = totalAmount - totalConstructionPayments - handoverAmount;
            }

            if (remainingAfterHandover < 0 && plan.Payment_Plan__c != 'Rent-to-Own' && plan.Payment_Plan__c != 'Standard') {
                throw new PaymentPlanTriggerHandlerException('Payment percentages result in a negative remaining balance.');
            }

            Decimal postHandoverMonthlyAmount = (plan.Payment_Plan__c != 'Standard' && plan.Payment_Plan__c != 'Rent-to-Own' && postHandoverMonths > 0) ? remainingAfterHandover / postHandoverMonths : 0;
            Decimal monthlyRentAmount = (plan.Payment_Plan__c == 'Rent-to-Own' && rentDurationMonths != null && totalRentPercent != null) 
                ? ((totalRentPercent / 100) * totalAmount) / rentDurationMonths 
                : 0;

            Map<String, List<Payment_Schedule__c>> schedulesByType = new Map<String, List<Payment_Schedule__c>>();
            for (Payment_Schedule__c sch : existingSchedules) {
                if (!schedulesByType.containsKey(sch.Installment_Type__c)) {
                    schedulesByType.put(sch.Installment_Type__c, new List<Payment_Schedule__c>());
                }
                schedulesByType.get(sch.Installment_Type__c).add(sch);
            }

            Integer installmentIndex = 0;

            if (schedulesByType.containsKey('Down Payment') && (plan.Payment_Plan__c != 'Rent-to-Own')) {
                Payment_Schedule__c downPayment = schedulesByType.get('Down Payment')[0];
                if (downPayment.Status__c != 'Paid') {
                    downPayment.Amount__c = downPaymentAmount;
                    downPayment.Percentage__c = downPaymentPercent;
                    downPayment.Due_Date__c = startDate;
                    downPayment.Payer__c = plan.Payer__c;
                    downPayment.Next_Installment_Index__c = installmentIndex++;
                    schedulesToUpdate.add(downPayment);
                }
            }

            if (schedulesByType.containsKey('Rent') && plan.Payment_Plan__c == 'Rent-to-Own' && rentDurationMonths != null && totalRentPercent != null) {
                List<Payment_Schedule__c> rentSchedules = schedulesByType.get('Rent');
                for (Integer i = 0; i < rentSchedules.size() && i < rentDurationMonths; i++) {
                    Payment_Schedule__c rentSchedule = rentSchedules[i];
                    if (rentSchedule.Status__c != 'Paid') {
                        rentSchedule.Amount__c = monthlyRentAmount;
                        rentSchedule.Percentage__c = (monthlyRentAmount / totalAmount) * 100;
                        rentSchedule.Due_Date__c = startDate.addMonths(i + 1);
                        rentSchedule.Payer__c = plan.Payer__c;
                        rentSchedule.Next_Installment_Index__c = installmentIndex++;
                        schedulesToUpdate.add(rentSchedule);
                    }
                }
            } else if (schedulesByType.containsKey('Construction') && plan.Payment_Plan__c != '10:90' && plan.Payment_Plan__c != 'Rent-to-Own') {
                List<Payment_Schedule__c> constructionSchedules = schedulesByType.get('Construction');
                Decimal constructionTotal = (constructionPercent / 100) * totalAmount;
                for (Integer i = 0; i < constructionSchedules.size(); i++) {
                    Payment_Schedule__c constructionSchedule = constructionSchedules[i];
                    if (constructionSchedule.Status__c != 'Paid') {
                        constructionSchedule.Amount__c = constructionTotal / constructionInstallments;
                        constructionSchedule.Percentage__c = (constructionPercent / constructionInstallments);
                        constructionSchedule.Due_Date__c = startDate.addMonths((i + 1) * monthsPerInstallment);
                        constructionSchedule.Payer__c = plan.Payer__c;
                        constructionSchedule.Next_Installment_Index__c = installmentIndex++;
                        schedulesToUpdate.add(constructionSchedule);
                    }
                }
            }

            if (schedulesByType.containsKey('Handover') && plan.Payment_Plan__c != 'Rent-to-Own') {
                Payment_Schedule__c handoverPayment = schedulesByType.get('Handover')[0];
                if (handoverPayment.Status__c != 'Paid') {
                    handoverPayment.Amount__c = handoverAmount;
                    handoverPayment.Percentage__c = handoverPercent;
                    handoverPayment.Due_Date__c = startDate.addMonths(constructionMonths);
                    handoverPayment.Payer__c = plan.Payer__c;
                    handoverPayment.Next_Installment_Index__c = installmentIndex++;
                    schedulesToUpdate.add(handoverPayment);
                }
            }

            if (schedulesByType.containsKey('Post-Handover') && (plan.Payment_Plan__c == 'Post-Handover' || plan.Payment_Plan__c == '1% Monthly') && plan.Payment_Plan__c != 'Rent-to-Own') {
                List<Payment_Schedule__c> postHandoverSchedules = schedulesByType.get('Post-Handover');
                for (Integer i = 0; i < postHandoverSchedules.size(); i++) {
                    Payment_Schedule__c postHandoverSchedule = postHandoverSchedules[i];
                    if (postHandoverSchedule.Status__c != 'Paid') {
                        postHandoverSchedule.Amount__c = postHandoverMonthlyAmount;
                        postHandoverSchedule.Percentage__c = (postHandoverMonthlyAmount / totalAmount) * 100;
                        postHandoverSchedule.Due_Date__c = startDate.addMonths(constructionMonths + i + 1);
                        postHandoverSchedule.Payer__c = plan.Payer__c;
                        postHandoverSchedule.Next_Installment_Index__c = installmentIndex++;
                        schedulesToUpdate.add(postHandoverSchedule);
                    }
                }
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'PaymentPlanTriggerHandler', 'updateExistingSchedules', 'Error while updating Payment_Schedule__c records.');
            plan.addError('Failed to update schedules: ' + e.getMessage());
        }
    }

    private static void insertSchedules(List<Payment_Schedule__c> schedulesToInsert) {
        if (!schedulesToInsert.isEmpty()) {
            try {
                insert as user schedulesToInsert;
            } catch (Exception e) {
                ErrorHandler.insertErrorData(e, 'PaymentPlanTriggerHandler', 'insertSchedules', 'Error while inserting Payment_Schedule__c records.');
                throw new PaymentPlanTriggerHandlerException('Failed to insert schedules: ' + e.getMessage());
            }
        }
    }

    public class PaymentPlanTriggerHandlerException extends Exception {}
}