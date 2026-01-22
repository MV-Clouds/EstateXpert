public with sharing class TimesheetController {

    // @AuraEnabled
    // public static Timesheet_Session__c getCurrentTimesheet(Id userId) {
    //     try {
    //         String escapeUserId = String.escapeSingleQuotes(userId);
    //         List<Timesheet_Session__c> sessions = [SELECT Id, Clock_In__c, Clock_Out__c, Status__c, Task_Name__c, Task_Description__c FROM Timesheet_Session__c
    //                                                 WHERE User__c = :escapeUserId AND Status__c IN ('Clocked In', 'Paused') WITH USER_MODE ORDER BY CreatedDate DESC LIMIT 1];

    //         return sessions.isEmpty() ? null : sessions[0];
    //     } catch (Exception e) {
    //         ErrorHandler.insertErrorData(e, 'TimesheetController', 'getCurrentTimesheet', e.getMessage());
    //         return null;
    //     }
    // }

    // @AuraEnabled
    // public static List<Timesheet_Session__c> getTimesheetEntries(Id userId, String selectedDate) {
    //     try {
    //         Date startDate = Date.valueOf(String.escapeSingleQuotes(selectedDate));
    //         Datetime startDateTime = Datetime.newInstance(startDate, Time.newInstance(0, 0, 0, 0));
    //         Datetime endDateTime = startDateTime.addDays(1);
    //         String escapeUserId = String.escapeSingleQuotes(userId);

    //         return [SELECT Id, Clock_In__c, Clock_Out__c, Status__c, Task_Name__c, Task_Description__c, Total_Session_Duration__c, User__r.Name, Name
    //                 FROM Timesheet_Session__c WHERE User__c = :escapeUserId AND Clock_In__c >= :startDateTime AND Clock_In__c < :endDateTime
    //                 WITH USER_MODE ORDER BY Clock_In__c DESC];
    //     } catch (Exception e) {
    //         ErrorHandler.insertErrorData(e, 'TimesheetController', 'getTimesheetEntries', e.getMessage());
    //         return new List<Timesheet_Session__c>();
    //     }
    // }

    // @AuraEnabled
    // public static void saveTimesheetEntry(Id userId, String clockIn, String clockOut, String status, String taskName, String taskDescription, Boolean isMannual) {
    //     try {
    //         // Parse clockIn and clockOut times
    //         Datetime clockInTime = parseIsoString(clockIn);
    //         Datetime clockOutTime = parseIsoString(clockOut);

    //         if(isMannual) {
    //             Timesheet_Session__c session = new Timesheet_Session__c(
    //                 User__c = userId,
    //                 Clock_In__c = clockInTime,
    //                 Clock_Out__c = clockOutTime,
    //                 Status__c = 'Mannual',
    //                 Task_Name__c = taskName,
    //                 Task_Description__c = taskDescription
    //             );
    //             insert as user session;
    //         } else {
    //             // Handle different statuses
    //             if (status == 'Clocked In') {
    //                 handleClockIn(userId, clockInTime, taskName, taskDescription);
    //             } else if (status == 'Paused' || status == 'Resumed') {
    //                 handlePauseOrResume(userId, clockInTime, status);
    //             } else if (status == 'Stopped') {
    //                 handleClockOut(userId, clockOutTime);
    //             }
    //         }

    //     } catch (Exception e) {
    //         ErrorHandler.insertErrorData(e, 'TimesheetController', 'saveTimesheetEntry', e.getMessage());
    //     }
    // }
    
    // // Handle Clock In
    // private static void handleClockIn(Id userId, Datetime clockInTime, String taskName, String taskDescription) {

    //     Timesheet_Session__c session = new Timesheet_Session__c(
    //         User__c = userId,
    //         Clock_In__c = clockInTime,
    //         Status__c = 'Clocked In',
    //         Task_Name__c = taskName,
    //         Task_Description__c = taskDescription
    //     );
    //     insert as user session;
    // }
    
    // // Handle Pause or Resume
    // private static void handlePauseOrResume(Id userId, Datetime actionTime, String status) {
    //     String escapeUserId = String.escapeSingleQuotes(userId);
    //     // Fetch the active session
    //     List<Timesheet_Session__c> activeSessions = [SELECT Id, Status__c FROM Timesheet_Session__c
    //                                                     WHERE User__c = :escapeUserId AND Status__c IN ('Clocked In', 'Paused')
    //                                                     WITH USER_MODE ORDER BY CreatedDate DESC LIMIT 1];

    //     Timesheet_Session__c activeSession = activeSessions[0];
    
    //     // Create a Timesheet Activity record
    //     Timesheet_Activity__c activity = new Timesheet_Activity__c(
    //         Timesheet_Session__c = activeSession.Id,
    //         Action__c = status,
    //         Action_Time__c = actionTime
    //     );
    //     insert as user activity;
    
    //     // Update the session status
    //     activeSession.Status__c = (status == 'Paused') ? 'Paused' : 'Clocked In';
    //     update as user activeSession;
    // }
    
    // // Handle Clock Out
    // private static void handleClockOut(Id userId, Datetime clockOutTime) {
    //     // Fetch the active or paused session
    //     List<Timesheet_Session__c> sessions = [SELECT Id, Clock_In__c, Status__c FROM Timesheet_Session__c
    //                                             WHERE User__c = :userId AND Status__c IN ('Clocked In', 'Paused')
    //                                             WITH USER_MODE ORDER BY CreatedDate DESC LIMIT 1];
    
    //     if (!sessions.isEmpty()) {
    //         Timesheet_Session__c session = sessions[0];
    //         session.Clock_Out__c = clockOutTime;
    //         session.Status__c = 'Stopped';
    //         update as user session;        
    //     }
    
    // }

    // @AuraEnabled
    // public static void deleteTimesheetEntry(Id sessionId) {
    //     try {
    //         String escapeSessionId = String.escapeSingleQuotes(sessionId);
    //         Timesheet_Session__c session = [SELECT Id FROM Timesheet_Session__c WHERE Id = :escapeSessionId WITH USER_MODE LIMIT 1];
    //         delete as user session;
    //     } catch (Exception e) {
    //         ErrorHandler.insertErrorData(e, 'TimesheetController', 'deleteTimesheetEntry', e.getMessage());
    //     }
    // }

    // public static Datetime parseIsoString(String iso) {
    //     if (String.isBlank(iso)) return null;

    //     iso = iso.replace('T', ' ').replace('Z', '');
    //     if (iso.contains('.')) {
    //         iso = iso.substring(0, iso.indexOf('.'));
    //     }

    //     return Datetime.valueOfGmt(iso);
    // }
}