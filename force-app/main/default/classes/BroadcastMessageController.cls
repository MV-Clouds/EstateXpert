public with sharing class BroadcastMessageController {

    @AuraEnabled
    public static Map<String, Object> getObjectConfigs() {
        try {
            Map<String, Object> result = new Map<String, Object>();
            List<MVEX__Object_Config__mdt> objectConfigList = [SELECT MVEX__ChatWindowConfigInfo__c FROM MVEX__Object_Config__mdt WITH USER_MODE LIMIT 1];
    
            Map<String, Object> chatConfigData = (Map<String, Object>) JSON.deserializeUntyped(objectConfigList[0].MVEX__ChatWindowConfigInfo__c);
            
            List<Map<String, String>> objectOptions = new List<Map<String, String>>();
            Map<String, Map<String, String>> configMap = new Map<String, Map<String, String>>();
    
            for (String objectApiName : chatConfigData.keySet()) {
                objectOptions.add(new Map<String, String> {
                    'label' => objectApiName,
                    'value' => objectApiName
                });
                Map<String, Object> config = (Map<String, Object>) chatConfigData.get(objectApiName);
                configMap.put(objectApiName, new Map<String, String>{
                    'nameField' => (String) config.get('nameField'),
                    'phoneField' => (String) config.get('phoneField'),
                    'emailField' => (String) config.get('emailField')
                });
            }
    
            result.put('objectOptions', objectOptions);
            result.put('configMap', configMap);
    
            return result;
    
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'BroadcastMessageController', 'getObjectConfigs', e.getMessage());
        }
        return new Map<String, Object>();
    }

    @AuraEnabled
    public static List<ListView> getListViewsForObject(String objectApiName) {
        List<ListView> listViews = new List<ListView>();
        try {
            listViews = [SELECT Id, Name FROM ListView WHERE SobjectType = :objectApiName WITH USER_MODE ORDER BY LastViewedDate DESC];
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'BroadcastMessageController', 'getListViewsForObject', e.getMessage());
        }
        return listViews;
    }

    @AuraEnabled
    public static List<MVEX__Broadcast_Group__c> getBroadcastGroups() {
        List<MVEX__Broadcast_Group__c> broadcastGroups = new List<MVEX__Broadcast_Group__c>();
        try {
            broadcastGroups = [SELECT Id, Name, MVEX__Count_of_Members__c, MVEX__Description__c, MVEX__Object_Name__c, MVEX__Phone_Field__c, MVEX__Communication_Type__c FROM MVEX__Broadcast_Group__c WHERE MVEX__Communication_Type__c IN ('Both', 'WhatsApp') WITH USER_MODE ORDER BY LastModifiedDate DESC];
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'BroadcastMessageController', 'getBroadcastGroups', e.getMessage());
        }
        return broadcastGroups;
    }

    @AuraEnabled
    public static List<MVEX__Broadcast_Group__c> getAllBroadcastGroups() {
        List<MVEX__Broadcast_Group__c> broadcastGroups = new List<MVEX__Broadcast_Group__c>();
        try {
            broadcastGroups = [SELECT Id, Name, MVEX__Count_of_Members__c, MVEX__Description__c, MVEX__Object_Name__c, MVEX__Phone_Field__c, MVEX__Communication_Type__c, CreatedDate FROM MVEX__Broadcast_Group__c WHERE MVEX__Communication_Type__c IN ('Both', 'WhatsApp', 'Email') WITH USER_MODE ORDER BY CreatedDate DESC];
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'BroadcastMessageController', 'getAllBroadcastGroups', e.getMessage());
        }
        return broadcastGroups;
    }

    @AuraEnabled
    public static List<MVEX__Broadcast_Group__c> getBroadcastEmailGroups() {
        List<MVEX__Broadcast_Group__c> broadcastGroups = new List<MVEX__Broadcast_Group__c>();
        try {
            broadcastGroups = [SELECT Id, Name, MVEX__Count_of_Members__c, MVEX__Description__c, MVEX__Object_Name__c, MVEX__Phone_Field__c, MVEX__Communication_Type__c FROM MVEX__Broadcast_Group__c WHERE MVEX__Communication_Type__c IN ('Both', 'Email') WITH USER_MODE ORDER BY LastModifiedDate DESC];
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'BroadcastMessageController', 'getBroadcastEmailGroups', e.getMessage());
        }
        return broadcastGroups;
    }

    @AuraEnabled
    public static List<String> getActiveCampaignsForGroup(Id groupId) {
        List<String> activeCampaignNames = new List<String>();
        try {
            String groupIdStr = String.valueOf(groupId);

            // Check WhatsApp Broadcasts (MVEX__Broadcast_Group_IDs__c is comma-separated)
            List<MVEX__Broadcast__c> broadcasts = [SELECT Id, Name, MVEX__Status__c, MVEX__Broadcast_Group_IDs__c FROM MVEX__Broadcast__c WHERE MVEX__Status__c != 'Completed' WITH USER_MODE LIMIT 50000];
            for (MVEX__Broadcast__c b : broadcasts) {
                if (String.isBlank(b.MVEX__Broadcast_Group_IDs__c)) continue;
                List<String> groupIds = b.MVEX__Broadcast_Group_IDs__c.split(',');
                for (String gId : groupIds) {
                    if (gId.trim() == groupIdStr) {
                        activeCampaignNames.add('Broadcast: ' + b.Name);
                        break;
                    }
                }
            }

            // Check Email Marketing Campaigns (MVEX__Selected_Broadcast_Groups__c is @@@ separated)
            List<MVEX__Marketing_Campaign__c> campaigns = [SELECT Id, MVEX__Label__c, MVEX__Status__c, MVEX__Selected_Broadcast_Groups__c FROM MVEX__Marketing_Campaign__c WHERE MVEX__Status__c != 'Completed' WITH USER_MODE LIMIT 50000];
            for (MVEX__Marketing_Campaign__c c : campaigns) {
                if (String.isBlank(c.MVEX__Selected_Broadcast_Groups__c)) continue;
                List<String> groupIds = c.MVEX__Selected_Broadcast_Groups__c.split('@@@');
                for (String gId : groupIds) {
                    if (gId.trim() == groupIdStr) {
                        activeCampaignNames.add('Campaign: ' + c.MVEX__Label__c);
                        break;
                    }
                }
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'BroadcastMessageController', 'getActiveCampaignsForGroup', e.getMessage());
        }
        return activeCampaignNames;
    }

    @AuraEnabled
    public static void deleteBroadcastGroup(Id groupId) {
        try {
            MVEX__Broadcast_Group__c groupToDelete = [SELECT Id FROM MVEX__Broadcast_Group__c WHERE Id = :groupId WITH USER_MODE LIMIT 1
            ];
            delete as user groupToDelete;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'BroadcastMessageController', 'deleteBroadcastGroup', e.getMessage());
        }
    }

    @AuraEnabled
    public static List<Map<String, Object>> getBroadcastRecsWithReplies() {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        try {
            List<MVEX__Broadcast__c> broadcasts = [SELECT Id, Name,MVEX__Status__c, CreatedDate, MVEX__Recipient_Count__c, MVEX__Schedule_DateTime__c,
                                                    MVEX__Total_Sent__c, MVEX__Total_Delivered__c, MVEX__Total_Read__c,MVEX__WhatsappTemplate__r.MVEX__Template_Name__c
                                                    FROM MVEX__Broadcast__c WITH USER_MODE ORDER BY CreatedDate DESC LIMIT 50000];

            Map<Id, Map<String, Integer>> broadcastStats = new Map<Id, Map<String, Integer>>();
            for (MVEX__Broadcast__c b : broadcasts) {
                broadcastStats.put(b.Id, new Map<String, Integer>{
                    'Sent' => 0, 'Delivered' => 0, 'Seen' => 0, 'Failed' => 0
                });
            }

            for (AggregateResult ar : [
                SELECT MVEX__WB_Broadcast__c broadcastId, MVEX__Message_Status__c status, COUNT(Id) cnt
                FROM MVEX__Chat__c
                WHERE MVEX__WB_Broadcast__c IN :broadcasts AND MVEX__Type_of_Message__c IN ('Outbound Messages', 'OutBound Messages')
                GROUP BY MVEX__WB_Broadcast__c, MVEX__Message_Status__c
            ]) {
                Id bId = (Id) ar.get('broadcastId');
                String status = (String) ar.get('status');
                Integer cnt = (Integer) ar.get('cnt');
                
                if (status == 'Sent') broadcastStats.get(bId).put('Sent', broadcastStats.get(bId).get('Sent') + cnt);
                else if (status == 'Delivered') broadcastStats.get(bId).put('Delivered', broadcastStats.get(bId).get('Delivered') + cnt);
                else if (status == 'Seen') broadcastStats.get(bId).put('Seen', broadcastStats.get(bId).get('Seen') + cnt);
                else if (status == 'Failed' || status == 'failed') broadcastStats.get(bId).put('Failed', broadcastStats.get(bId).get('Failed') + cnt);
            }

            for (MVEX__Broadcast__c b : broadcasts) {
                Integer sent = broadcastStats.get(b.Id).get('Sent');
                Integer delivered = broadcastStats.get(b.Id).get('Delivered');
                Integer read = broadcastStats.get(b.Id).get('Seen');
                Integer failed = broadcastStats.get(b.Id).get('Failed');

                result.add(new Map<String, Object>{
                    'Id' => b.Id,
                    'Name' => b.Name,
                    'MVEX__MVEX__Status__c' => b.MVEX__Status__c,
                    'CreatedDate' => b.CreatedDate,
                    'MVEX__MVEX__Recipient_Count__c' => b.MVEX__Recipient_Count__c,
                    'MVEX__Total_Sent__c' => sent + delivered + read,
                    'MVEX__MVEX__Total_Delivered__c' => delivered + read,
                    'MVEX__Total_Failed__c' => failed,
                    'MVEX__MVEX__Total_Read__c' => read,
                    'MVEX__Template_Name__c' => b.MVEX__WhatsappTemplate__r.MVEX__Template_Name__c,
                    'MVEX__Schedule_DateTime__c' => b.MVEX__Schedule_DateTime__c
                });
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'BroadcastMessageController', 'getBroadcastRecsWithReplies', e.getMessage());
        }
        return result;
    }

    @AuraEnabled
    public static Map<String, Object> getBroadcastRecord(Id broadcastId) {
        Map<String, Object> result = new Map<String, Object>();
        try {
            // Query single broadcast
            MVEX__Broadcast__c broadcast = [
                SELECT Id, Name, MVEX__Status__c, CreatedDate, MVEX__Recipient_Count__c, MVEX__Schedule_DateTime__c,
                    MVEX__Total_Sent__c, MVEX__Total_Delivered__c, MVEX__Total_Read__c,
                    MVEX__WhatsappTemplate__r.MVEX__Template_Name__c
                FROM MVEX__Broadcast__c 
                WHERE Id = :broadcastId
                LIMIT 1
            ];

            Integer sent = 0, delivered = 0, read = 0, failed = 0;

            for (AggregateResult ar : [
                SELECT MVEX__Message_Status__c status, COUNT(Id) cnt
                FROM MVEX__Chat__c
                WHERE MVEX__WB_Broadcast__c = :broadcastId AND MVEX__Type_of_Message__c IN ('Outbound Messages', 'OutBound Messages')
                GROUP BY MVEX__Message_Status__c
            ]) {
                String status = (String) ar.get('status');
                Integer cnt = (Integer) ar.get('cnt');
                
                if (status == 'Sent') sent += cnt;
                else if (status == 'Delivered') delivered += cnt;
                else if (status == 'Seen') read += cnt;
                else if (status == 'Failed' || status == 'failed') failed += cnt;
            }

            result.put('Id', broadcast.Id);
            result.put('Name', broadcast.Name);
            result.put('MVEX__MVEX__Status__c', broadcast.MVEX__Status__c);
            result.put('MVEX__MVEX__Recipient_Count__c', broadcast.MVEX__Recipient_Count__c);
            result.put('MVEX__Total_Sent__c', sent + delivered + read);
            result.put('MVEX__MVEX__Total_Delivered__c', delivered + read);
            result.put('MVEX__Total_Failed__c', failed);
            result.put('MVEX__MVEX__Total_Read__c', read);
            result.put('MVEX__Template_Name__c', broadcast.MVEX__WhatsappTemplate__r.MVEX__Template_Name__c);
            result.put('MVEX__Schedule_DateTime__c', broadcast.MVEX__Schedule_DateTime__c);
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'BroadcastMessageController', 'getBroadcastRecord', e.getMessage());
        }
        return result;
    }

    @AuraEnabled
    public static Map<String, List<MVEX__WhatsappTemplate__c>> getTemplatesByObject() {
        Map<String, List<MVEX__WhatsappTemplate__c>> objectTemplateMap = new Map<String, List<MVEX__WhatsappTemplate__c>>();
        try {
            List<MVEX__WhatsappTemplate__c> templates = [
                SELECT Id, MVEX__Template_Name__c, (SELECT MVEX__Object_Name__c FROM MVEX__WB_Template_Variables__r) 
                FROM MVEX__WhatsappTemplate__c 
                WHERE MVEX__Status__c = 'Active-Quality Pending'
                WITH USER_MODE 
                ORDER BY LastModifiedDate DESC
            ];
    
            for (MVEX__WhatsappTemplate__c template : templates) {
                String objectName = template.MVEX__WB_Template_Variables__r.isEmpty() ? 'Generic' : template.MVEX__WB_Template_Variables__r[0].MVEX__Object_Name__c;
                if (!objectTemplateMap.containsKey(objectName)) {
                    objectTemplateMap.put(objectName, new List<MVEX__WhatsappTemplate__c>());
                }
                objectTemplateMap.get(objectName).add(template);
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'BroadcastMessageController', 'getTemplatesByObject', e.getMessage());
        }
        return objectTemplateMap;
    }

    @AuraEnabled
    public static void processBroadcastMessageWithObject(String requestJson) {
        try {
            Map<String, Object> request = (Map<String, Object>) JSON.deserializeUntyped(requestJson);

            String objectApiName = (String) request.get('objectApiName');
            String listViewName = (String) request.get('listViewName');
            List<Object> recipientsRaw = (List<Object>) request.get('recipients');
            String description = (String) request.get('description');
            String name = (String) request.get('name');
            Boolean isUpdate = request.containsKey('isUpdate') ? (Boolean) request.get('isUpdate') : false;
            String broadcastGroupId = (String) request.get('broadcastGroupId');
            String phoneField = (String) request.get('phoneField');
            String emailField = (String) request.get('emailField');
            String communicationType = (String) request.get('communicationType');

            MVEX__Broadcast_Group__c broadcastGroup;

            if (isUpdate && String.isNotBlank(broadcastGroupId)) {
                broadcastGroup = [
                    SELECT Id, Name, MVEX__Description__c, MVEX__Object_Name__c, MVEX__List_View__c, MVEX__Phone_Field__c, MVEX__Communication_Type__c, MVEX__Email_Field__c
                    FROM MVEX__Broadcast_Group__c
                    WHERE Id = :broadcastGroupId
                    WITH USER_MODE
                    LIMIT 1
                ];

                broadcastGroup.Name = name;
                broadcastGroup.MVEX__Description__c = description;
                broadcastGroup.MVEX__Object_Name__c = objectApiName;
                broadcastGroup.MVEX__List_View__c = listViewName;
                broadcastGroup.MVEX__Phone_Field__c = phoneField;
                broadcastGroup.MVEX__Communication_Type__c = communicationType;
                broadcastGroup.MVEX__Email_Field__c = emailField;

                Database.SaveResult updateResult = Database.update(broadcastGroup, false, AccessLevel.USER_MODE);
            } else {
                broadcastGroup = new MVEX__Broadcast_Group__c(
                    Name = name,
                    MVEX__Description__c = description,
                    MVEX__Object_Name__c = objectApiName,
                    MVEX__List_View__c = listViewName,
                    MVEX__Phone_Field__c = phoneField,
                    MVEX__Email_Field__c = emailField,
                    MVEX__Communication_Type__c = communicationType
                );
                Database.SaveResult insertResult = Database.insert(broadcastGroup, false, AccessLevel.USER_MODE);
            }

            // Use MVEX__Member_Record_Id__c as unique key for update
            Map<String, MVEX__Broadcast_Group_Member__c> existingMembersMap = new Map<String, MVEX__Broadcast_Group_Member__c>();
            if (isUpdate) {
                for (MVEX__Broadcast_Group_Member__c member : [SELECT Id, MVEX__Member_Record_Id__c FROM MVEX__Broadcast_Group_Member__c 
                                                                WHERE MVEX__Broadcast_Group_ID__c = :broadcastGroup.Id WITH USER_MODE]) {
                    if (!String.isBlank(member.MVEX__Member_Record_Id__c)) {
                        existingMembersMap.put(member.MVEX__Member_Record_Id__c, member);
                    }
                }
            }

            List<MVEX__Broadcast_Group_Member__c> newMembersToInsert = new List<MVEX__Broadcast_Group_Member__c>();
            Set<String> receivedRecordIds = new Set<String>();

            for (Object recObj : recipientsRaw) {
                Map<String, Object> rec = (Map<String, Object>) recObj;
                String recId = (String) rec.get('Id');
                String recPhone = (String) rec.get('phone');
                String recEmail = (String) rec.get('email');

                if (String.isBlank(recId)) {
                    continue;
                }
                receivedRecordIds.add(recId);

                if (!existingMembersMap.containsKey(recId)) {
                    MVEX__Broadcast_Group_Member__c member = new MVEX__Broadcast_Group_Member__c(
                        MVEX__Broadcast_Group_ID__c = broadcastGroup.Id,
                        MVEX__Member_Record_Id__c = recId
                    );
                    if (communicationType == 'Both') {
                        member.MVEX__Phone_Number__c = recPhone;
                        member.MVEX__Email__c = recEmail;
                    } else if (communicationType == 'Email') {
                        member.MVEX__Email__c = recEmail;
                    } else {
                        member.MVEX__Phone_Number__c = recPhone;
                    }
                    newMembersToInsert.add(member);
                }
            }

            List<MVEX__Broadcast_Group_Member__c> membersToDelete = new List<MVEX__Broadcast_Group_Member__c>();
            for (String existingId : existingMembersMap.keySet()) {
                if (!receivedRecordIds.contains(existingId)) {
                    membersToDelete.add(existingMembersMap.get(existingId));
                }
            }

            if (!newMembersToInsert.isEmpty()) {
                Database.SaveResult[] insertResults = Database.insert(newMembersToInsert, false, AccessLevel.USER_MODE);
            }

            if (!membersToDelete.isEmpty()) {
                Database.DeleteResult[] deleteResults = Database.delete(membersToDelete, false, AccessLevel.USER_MODE);
            }

        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'BroadcastMessageController', 'processBroadcastMessageWithObject', e.getMessage());
        }
    }

    @AuraEnabled
    public static Map<String, Object> getBroadcastGroupDetails(String groupId) {
        try {
            MVEX__Broadcast_Group__c groupRecord = [
                SELECT Id, Name, MVEX__Description__c, MVEX__Object_Name__c, MVEX__List_View__c, MVEX__Phone_Field__c, MVEX__Email_Field__c, MVEX__Communication_Type__c
                FROM MVEX__Broadcast_Group__c
                WHERE Id = :groupId
                WITH USER_MODE 
                LIMIT 1
            ];

            List<MVEX__Broadcast_Group_Member__c> groupMembers = [
                SELECT Id, MVEX__Phone_Number__c, MVEX__Email__c, Name, MVEX__Member_Record_Id__c 
                FROM MVEX__Broadcast_Group_Member__c
                WHERE MVEX__Broadcast_Group_ID__c = :groupId
                WITH USER_MODE 
            ];

            Map<String, Object> response = new Map<String, Object>();
            response.put('group', groupRecord);
            response.put('members', groupMembers);
            return response;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'BroadcastMessageController', 'getBroadcastGroupDetails', e.getMessage());
        }
        return null;
    }

    @AuraEnabled
    public static String createChatRecods(String templateId, List<String> groupIds, Boolean isScheduled, String timeOfMessage) {
        try {
            MVEX__Broadcast__c broadcast = new MVEX__Broadcast__c();
            broadcast.MVEX__WhatsappTemplate__c = templateId;
            broadcast.MVEX__Status__c = 'Pending';
            broadcast.MVEX__Schedule_DateTime__c = DateTime.now();
            broadcast.MVEX__Broadcast_Group_IDs__c = String.join(groupIds, ','); // Save all group IDs as a comma-separated string

            String objectApiName = '';
            String phoneField = '';
            List<MVEX__Chat__c> chatRecs = new List<MVEX__Chat__c>();

            if (groupIds.size() > 0) {
                List<MVEX__Broadcast_Group__c> brGroupRecs = [SELECT Id, Name, MVEX__Object_Name__c, MVEX__Phone_Field__c FROM MVEX__Broadcast_Group__c WHERE Id IN :groupIds 
                                                        WITH USER_MODE];
                if (brGroupRecs.size() > 0) {
                    objectApiName = brGroupRecs[0].MVEX__Object_Name__c;
                    phoneField = brGroupRecs[0].MVEX__Phone_Field__c;
                }

                List<MVEX__Broadcast_Group_Member__c> groupMembers = new List<MVEX__Broadcast_Group_Member__c>();
                groupMembers = [SELECT Id, Name, MVEX__Phone_Number__c, MVEX__Broadcast_Group_ID__c FROM MVEX__Broadcast_Group_Member__c WHERE MVEX__Broadcast_Group_ID__c IN :groupIds WITH USER_MODE];
                broadcast.MVEX__Recipient_Count__c = groupMembers.size();
                Database.insert(broadcast, false, AccessLevel.USER_MODE);

                List<String> phoneList = new List<String>();
                if (groupMembers.size() > 0) {
                    for (MVEX__Broadcast_Group_Member__c member : groupMembers) {
                        if (member.MVEX__Phone_Number__c != null || member.MVEX__Phone_Number__c != '') {
                            phoneList.add(member.MVEX__Phone_Number__c);
                            MVEX__Chat__c newChat = new MVEX__Chat__c();
                            newChat.MVEX__WhatsappTemplate__c = templateId;
                            newChat.MVEX__Phone__c = member.MVEX__Phone_Number__c;
                            newChat.MVEX__Type_of_Message__c = 'OutBound Messages';
                            newChat.MVEX__Message_Status__c = null;
                            newChat.MVEX__Message_Type__c = 'Template';
                            newChat.MVEX__WB_Broadcast__c = broadcast.Id;
                            chatRecs.add(newChat);
                        }
                    }
                }

                if (chatRecs.size() > 0) {
                    Database.insert(chatRecs, false, AccessLevel.USER_MODE);
                }
            }

            if (isScheduled == false) {
                WhatsAppMessageBatch2 batchJob = new WhatsAppMessageBatch2(templateId, chatRecs, broadcast.Id, objectApiName, phoneField);
                Database.executeBatch(batchJob, 1);
            } else {
                timeOfMessage = timeOfMessage.replace('T', ' ').replace('Z', '');

                DateTime utcDateTime = DateTime.valueOf(timeOfMessage);

                // Convert UTC to user's timezone
                TimeZone userTimeZone = UserInfo.getTimeZone();
                DateTime userDateTime = utcDateTime.addSeconds(userTimeZone.getOffset(utcDateTime) / 1000);

                // Validate that the scheduled time is in the future
                if (userDateTime < DateTime.now()) {
                    return 'Scheduled time must be in the future.';
                }

                String formattedTime = userDateTime.format('hh:mm a');

                String cronExpression = getCronExpression(userDateTime);

                WhatsAppMessageBatchSchedulable2 batchSchedular = new WhatsAppMessageBatchSchedulable2(templateId, chatRecs, broadcast.Id, objectApiName, phoneField);

                MVEX__Broadcast__c br = new MVEX__Broadcast__c(Id = broadcast.Id);
                br.MVEX__Schedule_DateTime__c = userDateTime;
                Database.SaveResult updateResult = Database.update(br, false, AccessLevel.USER_MODE);

                String jobName = 'BroadcastSchedule_' + broadcast.Id;
                System.schedule(jobName, cronExpression, batchSchedular);
            }
            // return 'Success';
            return broadcast.Id;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'BroadcastMessageController', 'createChatRecods', e.getMessage());
            return 'Error: ' + e.getMessage();
        }
    }  

    public static String getCronExpression(DateTime dt) {
        String cronExpression = '0 ' + dt.minute() + ' ' + dt.hour() + ' ' + dt.day() + ' ' + dt.month() + ' ' + '?' + ' ' + dt.year();
        return cronExpression;
    }

    @AuraEnabled
    public static List<String> rescheduleBroadcast(String broadcastId, String action, String newScheduleTime) {
        try {
            String jobName = 'BroadcastSchedule_' + broadcastId;
            // Query for the scheduled job using the current user's session ID
            List<CronTrigger> jobs = [SELECT Id, CronExpression, NextFireTime FROM CronTrigger WHERE State = 'WAITING' AND CronJobDetail.Name=:jobName WITH USER_MODE LIMIT 1];

            if (jobs.isEmpty()) {
                return new List<String>{'Error', 'No scheduled job found for this broadcast.'};
            }

            System.debug('Aborted scheduled job for broadcast: ' + broadcastId);

            List<MVEX__Chat__c> chatRecs = [SELECT Id, MVEX__Phone__c FROM MVEX__Chat__c WHERE MVEX__WB_Broadcast__c = :broadcastId WITH USER_MODE];
            List<MVEX__Broadcast__c> broadcastRecs = new List<MVEX__Broadcast__c>();
            broadcastRecs =  [SELECT Id, Name, MVEX__WhatsappTemplate__c, MVEX__WhatsappTemplate__r.MVEX__Template_Name__c, MVEX__Broadcast_Group_IDs__c, MVEX__Status__c, MVEX__Schedule_DateTime__c FROM MVEX__Broadcast__c WHERE Id = :broadcastId WITH USER_MODE ORDER BY LastModifiedDate DESC];

            if (action == 'Reschedule') {
                // Validate the new schedule time
                if (String.isBlank(newScheduleTime)) {
                    System.debug('New schedule time is required for rescheduling.');
                    return new List<String>{'Error', 'Something went wrong while rescheduling the broadcast. Please try again.'};
                }

                String templateId = broadcastRecs[0].MVEX__WhatsappTemplate__c;
                String objectApiName = '';
                String phoneField = '';
                List<String> groupIds = new List<String>();
                if (broadcastRecs[0].MVEX__Broadcast_Group_IDs__c != null) {
                    groupIds = broadcastRecs[0].MVEX__Broadcast_Group_IDs__c.split(',');
                    List<MVEX__Broadcast_Group__c> brGroupRecs = [SELECT Id, Name, MVEX__Object_Name__c, MVEX__Phone_Field__c FROM MVEX__Broadcast_Group__c WHERE Id IN :groupIds];
                    if (brGroupRecs.size() > 0) {
                        objectApiName = brGroupRecs[0].MVEX__Object_Name__c;
                        phoneField = brGroupRecs[0].MVEX__Phone_Field__c;
                    }
                    System.debug('brGroupRecs: ' + brGroupRecs);
                }

                newScheduleTime = newScheduleTime.replace('T', ' ').replace('Z', '');

                DateTime utcDateTime = DateTime.valueOf(newScheduleTime);

                // Convert UTC to user's timezone
                TimeZone userTimeZone = UserInfo.getTimeZone();
                DateTime userDateTime = utcDateTime.addSeconds(userTimeZone.getOffset(utcDateTime) / 1000);

                // Validate that the scheduled time is in the future
                if (userDateTime < DateTime.now()) {
                    System.debug('Scheduled time must be in the future.');
                    return new List<String>{'Error', 'Scheduled time must be in the future.'};
                }
                
                System.abortJob(jobs[0].Id); // Abort the job if found

                System.debug('userDateTime: ' + userDateTime);

                String formattedTime = userDateTime.format('hh:mm a');

                String cronExpression = getCronExpression(userDateTime);

                WhatsAppMessageBatchSchedulable2 batchSchedular = new WhatsAppMessageBatchSchedulable2(templateId, chatRecs, broadcastId, objectApiName, phoneField);

                System.debug('batchSchedular: ' + batchSchedular);

                MVEX__Broadcast__c br = new MVEX__Broadcast__c(Id = broadcastId);
                br.MVEX__Schedule_DateTime__c = userDateTime;
                Database.SaveResult updateResult = Database.update(br, false, AccessLevel.USER_MODE);

                System.debug('updateResult: ' + updateResult);

                System.schedule(jobName, cronExpression, batchSchedular);

                return new List<String>{'Success', 'Broadcast rescheduled successfully.'};
            } else if (action == 'Delete Broadcast') {
                
                System.abortJob(jobs[0].Id); // Abort the job if found
                // Delete the Broadcast record and related Chat records
                delete chatRecs;
                delete broadcastRecs;

                return new List<String>{'Success', 'Broadcast deleted successfully.'};
            } else {
                return new List<String>{'Error', 'Invalid action specified. Please use "Reschedule" or "Delete Broadcast".'};
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'BroadcastMessageController', 'rescheduleBroadcast', e.getMessage());
            return new List<String>{'Error', 'Something went wrong while rescheduling the broadcast. Please try again.'};
        }
    }

    @AuraEnabled
    public static List<Map<String, Object>> getBroadcastGroupsWithStats(String broadcastId) {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        
        try {
            MVEX__Broadcast__c broadcast = [
                SELECT MVEX__Broadcast_Group_IDs__c, CreatedDate
                FROM MVEX__Broadcast__c 
                WHERE Id = :broadcastId 
                WITH USER_MODE 
                LIMIT 1
            ];

            if (String.isBlank(broadcast.MVEX__Broadcast_Group_IDs__c)) return result;

            List<String> groupIds = broadcast.MVEX__Broadcast_Group_IDs__c.split(',');
            
            // Get groups
            List<MVEX__Broadcast_Group__c> groups = [
                SELECT Id, Name, MVEX__Count_of_Members__c, MVEX__Description__c, MVEX__Object_Name__c, MVEX__Phone_Field__c, MVEX__Email_Field__c, MVEX__Communication_Type__c
                FROM MVEX__Broadcast_Group__c 
                WHERE Id IN :groupIds 
                WITH USER_MODE
            ];

            // Get phones per group
            Map<Id, Set<String>> groupToPhones = new Map<Id, Set<String>>();
            for (MVEX__Broadcast_Group_Member__c m : [
                SELECT MVEX__Broadcast_Group_ID__c, MVEX__Phone_Number__c 
                FROM MVEX__Broadcast_Group_Member__c 
                WHERE MVEX__Broadcast_Group_ID__c IN :groupIds AND MVEX__Phone_Number__c != null
                WITH USER_MODE
            ]) {
                if (!groupToPhones.containsKey(m.MVEX__Broadcast_Group_ID__c)) {
                    groupToPhones.put(m.MVEX__Broadcast_Group_ID__c, new Set<String>());
                }
                groupToPhones.get(m.MVEX__Broadcast_Group_ID__c).add(m.MVEX__Phone_Number__c);
            }

            Set<String> allPhones = new Set<String>();
            for (Set<String> phones : groupToPhones.values()) allPhones.addAll(phones);

            // Get ONLY outbound messages for this broadcast
            List<MVEX__Chat__c> outboundMessages = [
                SELECT MVEX__Phone__c, MVEX__Message_Status__c
                FROM MVEX__Chat__c 
                WHERE MVEX__Phone__c IN :allPhones
                AND MVEX__WB_Broadcast__c = :broadcastId
                AND MVEX__Type_of_Message__c = 'Outbound Messages'
                WITH USER_MODE
            ];

            // Count latest status per phone
            Map<String, String> phoneToStatus = new Map<String, String>();
            for (MVEX__Chat__c msg : outboundMessages) {
                String status = msg.MVEX__Message_Status__c;
                if (status == 'Seen' || status == 'Delivered' || status == 'Sent' || status == 'Failed') {
                    phoneToStatus.put(msg.MVEX__Phone__c, status);
                }
            }

            // Count replies
            Map<String, Integer> phoneToReplies = new Map<String, Integer>();
            for (AggregateResult ar : [
                SELECT MVEX__Phone__c phone, COUNT(Id) cnt
                FROM MVEX__Chat__c 
                WHERE MVEX__Phone__c IN :allPhones
                AND MVEX__Type_of_Message__c = 'Inbound Messages'
                AND CreatedDate >= :broadcast.CreatedDate
                GROUP BY MVEX__Phone__c
            ]) {
                phoneToReplies.put((String) ar.get('phone'), (Integer) ar.get('cnt'));
            }

            // Build result
            Integer index = 1;
            for (MVEX__Broadcast_Group__c grp : groups) {
                Integer sent = 0, delivered = 0, seen = 0, replied = 0, failed = 0;
                Set<String> phones = groupToPhones.get(grp.Id);
                if (phones != null) {
                    for (String phone : phones) {
                        String status = phoneToStatus.get(phone);
                        if (status == 'Sent') sent++;
                        else if (status == 'Delivered') delivered++;
                        else if (status == 'Seen') seen++;
                        else if (status == 'Failed') failed++;
                        if (phoneToReplies.containsKey(phone)) replied++;
                    }
                }

                Map<String, Object> stat = new Map<String, Object>{
                    'Id' => grp.Id,
                    'Name' => grp.Name,
                    'MVEX__MVEX__Count_of_Members__c' => grp.MVEX__Count_of_Members__c,
                    'MVEX__MVEX__Description__c' => grp.MVEX__Description__c,
                    'MVEX__MVEX__Object_Name__c' => grp.MVEX__Object_Name__c,
                    'MVEX__MVEX__Phone_Field__c' => grp.MVEX__Phone_Field__c,
                    'MVEX__MVEX__Email_Field__c' => grp.MVEX__Email_Field__c,
                    'index' => index++,
                    'MVEX__Total_Sent__c' => sent + delivered + seen,
                    'MVEX__MVEX__Total_Delivered__c' => delivered + seen,
                    'MVEX__Total_Failed__c' => failed,
                    'MVEX__MVEX__Total_Read__c' => seen,
                    'MVEX__Total_Replied__c' => replied
                };
                result.add(stat);
            }

        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'BroadcastMessageController', 'getBroadcastGroupsWithStats', e.getMessage());
        }
        return result;
    }

    public class BroadcastMemberWrapper {
        @AuraEnabled public SObject record;
        @AuraEnabled public String status;
        @AuraEnabled public Boolean hasReplied;
    }

    @AuraEnabled
    public static List<BroadcastMemberWrapper> getBroadcastMembersByGroupId(String groupId, String objectName, String broadcastId) {
        try {
            Map<String, Object> fullConfig = getObjectConfigs();
            Map<String, Object> configMap = (Map<String, Object>) fullConfig.get('configMap');
            Map<String, String> objectConfig = (Map<String, String>) configMap.get(objectName);

            String phoneField = objectConfig.get('phoneField');
            String emailField = objectConfig.get('emailField');
            String nameField = objectConfig.get('nameField');

            List<MVEX__Broadcast_Group__c> groups = [SELECT MVEX__Communication_Type__c FROM MVEX__Broadcast_Group__c WHERE Id = :groupId WITH USER_MODE LIMIT 1];
            String communicationType = groups.isEmpty() ? 'Phone' : groups[0].MVEX__Communication_Type__c;

            List<MVEX__Broadcast_Group_Member__c> members = [
                SELECT MVEX__Phone_Number__c, MVEX__Email__c, MVEX__Status__c 
                FROM MVEX__Broadcast_Group_Member__c 
                WHERE MVEX__Broadcast_Group_ID__c = :groupId 
                AND (MVEX__Phone_Number__c != null OR MVEX__Email__c != null) 
                WITH USER_MODE
            ];

            Map<String, String> valueToStatus = new Map<String, String>();
            Set<String> values = new Set<String>();

            for (MVEX__Broadcast_Group_Member__c member : members) {
                String value = communicationType == 'Email' ? member.MVEX__Email__c : member.MVEX__Phone_Number__c;
                if (String.isNotBlank(value)) {
                    valueToStatus.put(value, member.MVEX__Status__c);
                    values.add(value);
                }
            }

            if (values.isEmpty()) {
                return new List<BroadcastMemberWrapper>();
            }

            String queryFields = 'Id, Name, ' + phoneField;
            if (communicationType == 'Email' || communicationType == 'Both') {
                queryFields += ', ' + emailField;
            }

            String query = 'SELECT ' + queryFields + ' FROM ' + objectName + ' WHERE ' + (communicationType == 'Email' ? emailField : phoneField) + ' IN :values';
            String escapedQuery = String.escapeSingleQuotes(query);
            List<SObject> matchedRecords = Database.query(escapedQuery, AccessLevel.USER_MODE);

            // Get broadcast creation date for reply filtering (only when broadcastId is provided)
            Map<String, Boolean> phoneToHasReply = new Map<String, Boolean>();
            Map<String, String> phoneToChatStatus = new Map<String, String>();

            if (String.isNotBlank(broadcastId)) {
                MVEX__Broadcast__c broadcast = [SELECT CreatedDate FROM MVEX__Broadcast__c WHERE Id = :broadcastId WITH USER_MODE LIMIT 1];
                
                // Get reply counts for each phone number
                if (!values.isEmpty()) {
                    List<MVEX__Chat__c> replyMessages = [
                        SELECT MVEX__Phone__c
                        FROM MVEX__Chat__c 
                        WHERE MVEX__Phone__c IN :values
                        AND MVEX__Type_of_Message__c = 'Inbound Messages'
                        AND CreatedDate >= :broadcast.CreatedDate
                        WITH USER_MODE
                    ];

                    for (MVEX__Chat__c reply : replyMessages) {
                        phoneToHasReply.put(reply.MVEX__Phone__c, true);
                    }
                }

                // Step 2: Get phone numbers and statuses
                Set<String> phoneNumbers = new Set<String>();
                for (MVEX__Broadcast_Group_Member__c member : members) {
                    phoneNumbers.add(member.MVEX__Phone_Number__c);
                }

                if (!phoneNumbers.isEmpty()) {
                    // Step 3: Fetch chat statuses using phone numbers
                    List<MVEX__Chat__c> broadcastRelatedChats = [SELECT MVEX__Phone__c, MVEX__Message_Status__c FROM MVEX__Chat__c WHERE MVEX__WB_Broadcast__c = :broadcastId AND MVEX__Phone__c IN :phoneNumbers WITH SECURITY_ENFORCED];

                    for (MVEX__Chat__c chat : broadcastRelatedChats) {
                        if (!phoneToChatStatus.containsKey(chat.MVEX__Phone__c)) {
                            phoneToChatStatus.put(chat.MVEX__Phone__c, chat.MVEX__Message_Status__c);
                        }
                    }
                }
            }

            List<BroadcastMemberWrapper> result = new List<BroadcastMemberWrapper>();
            for (SObject record : matchedRecords) {
                String value = communicationType == 'Email' ? (String)record.get(emailField) : (String)record.get(phoneField);
                BroadcastMemberWrapper wrapper = new BroadcastMemberWrapper();
                wrapper.record = record;
                wrapper.status = phoneToChatStatus.get(value);
                wrapper.hasReplied = phoneToHasReply.containsKey(value) ? phoneToHasReply.get(value) : false;
                result.add(wrapper);
            }

            return result;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'BroadcastMessageController', 'getBroadcastMembersByGroupId', e.getMessage());
            return new List<BroadcastMemberWrapper>();
        }
    }

    @AuraEnabled
    public static Map<String, List<BroadcastMemberWrapper>> getAllBroadcastMembers(String broadcastId) {
        Map<String, List<BroadcastMemberWrapper>> groupMembersMap = new Map<String, List<BroadcastMemberWrapper>>();
        
        try {
            // Get broadcast and group IDs
            MVEX__Broadcast__c broadcast = [
                SELECT MVEX__Broadcast_Group_IDs__c, CreatedDate
                FROM MVEX__Broadcast__c 
                WHERE Id = :broadcastId 
                WITH USER_MODE 
                LIMIT 1
            ];

            if (String.isBlank(broadcast.MVEX__Broadcast_Group_IDs__c)) {
                return groupMembersMap;
            }

            List<String> groupIds = broadcast.MVEX__Broadcast_Group_IDs__c.split(',');
            
            // Get all groups
            Map<Id, MVEX__Broadcast_Group__c> groupsMap = new Map<Id, MVEX__Broadcast_Group__c>([
                SELECT Id, MVEX__Object_Name__c, MVEX__Communication_Type__c
                FROM MVEX__Broadcast_Group__c 
                WHERE Id IN :groupIds 
                WITH USER_MODE
            ]);

            // Get all group members for these groups
            List<MVEX__Broadcast_Group_Member__c> allMembers = [
                SELECT MVEX__Broadcast_Group_ID__c, MVEX__Phone_Number__c, MVEX__Email__c, MVEX__Status__c 
                FROM MVEX__Broadcast_Group_Member__c 
                WHERE MVEX__Broadcast_Group_ID__c IN :groupIds 
                AND (MVEX__Phone_Number__c != null OR MVEX__Email__c != null) 
                WITH USER_MODE
            ];

            // Organize members by group
            Map<Id, List<MVEX__Broadcast_Group_Member__c>> groupToMembersMap = new Map<Id, List<MVEX__Broadcast_Group_Member__c>>();
            Set<String> allPhones = new Set<String>();
            Set<String> allEmails = new Set<String>();
            
            for (MVEX__Broadcast_Group_Member__c member : allMembers) {
                if (!groupToMembersMap.containsKey(member.MVEX__Broadcast_Group_ID__c)) {
                    groupToMembersMap.put(member.MVEX__Broadcast_Group_ID__c, new List<MVEX__Broadcast_Group_Member__c>());
                }
                groupToMembersMap.get(member.MVEX__Broadcast_Group_ID__c).add(member);
                
                if (String.isNotBlank(member.MVEX__Phone_Number__c)) {
                    allPhones.add(member.MVEX__Phone_Number__c);
                }
                if (String.isNotBlank(member.MVEX__Email__c)) {
                    allEmails.add(member.MVEX__Email__c);
                }
            }

            // Get reply status for all phones
            Map<String, Boolean> phoneToHasReply = new Map<String, Boolean>();
            if (!allPhones.isEmpty()) {
                List<MVEX__Chat__c> replyMessages = [
                    SELECT MVEX__Phone__c
                    FROM MVEX__Chat__c 
                    WHERE MVEX__Phone__c IN :allPhones
                    AND MVEX__Type_of_Message__c = 'Inbound Messages'
                    AND CreatedDate >= :broadcast.CreatedDate
                    WITH USER_MODE
                ];

                for (MVEX__Chat__c reply : replyMessages) {
                    phoneToHasReply.put(reply.MVEX__Phone__c, true);
                }
            }

            // Get chat status for all phones
            Map<String, String> phoneToChatStatus = new Map<String, String>();
            if (!allPhones.isEmpty()) {
                List<MVEX__Chat__c> broadcastChats = [
                    SELECT MVEX__Phone__c, MVEX__Message_Status__c 
                    FROM MVEX__Chat__c 
                    WHERE MVEX__WB_Broadcast__c = :broadcastId 
                    AND MVEX__Phone__c IN :allPhones 
                    WITH SECURITY_ENFORCED
                ];

                for (MVEX__Chat__c chat : broadcastChats) {
                    if (!phoneToChatStatus.containsKey(chat.MVEX__Phone__c)) {
                        phoneToChatStatus.put(chat.MVEX__Phone__c, chat.MVEX__Message_Status__c);
                    }
                }
            }

            // Get object configs
            Map<String, Object> fullConfig = getObjectConfigs();
            Map<String, Object> configMap = (Map<String, Object>) fullConfig.get('configMap');

            // Process each group
            for (Id groupId : groupsMap.keySet()) {
                List<BroadcastMemberWrapper> memberWrappers = new List<BroadcastMemberWrapper>();
                MVEX__Broadcast_Group__c brodcastGroup = groupsMap.get(groupId);
                List<MVEX__Broadcast_Group_Member__c> groupMembers = groupToMembersMap.get(groupId);
                
                if (groupMembers == null || groupMembers.isEmpty()) {
                    groupMembersMap.put(groupId, memberWrappers);
                    continue;
                }

                String objectName = brodcastGroup.MVEX__Object_Name__c;
                String communicationType = brodcastGroup.MVEX__Communication_Type__c != null ? brodcastGroup.MVEX__Communication_Type__c : 'Phone';
                
                Map<String, String> objectConfig = (Map<String, String>) configMap.get(objectName);
                String phoneField = objectConfig.get('phoneField');
                String emailField = objectConfig.get('emailField');

                // Collect values for this group
                Set<String> values = new Set<String>();
                for (MVEX__Broadcast_Group_Member__c member : groupMembers) {
                    String value = communicationType == 'Email' ? member.MVEX__Email__c : member.MVEX__Phone_Number__c;
                    if (String.isNotBlank(value)) {
                        values.add(value);
                    }
                }

                if (values.isEmpty()) {
                    groupMembersMap.put(groupId, memberWrappers);
                    continue;
                }

                // Query records
                String queryFields = 'Id, Name, ' + phoneField;
                if (communicationType == 'Email' || communicationType == 'Both') {
                    queryFields += ', ' + emailField;
                }

                String query = 'SELECT ' + queryFields + ' FROM ' + objectName + ' WHERE ' + 
                              (communicationType == 'Email' ? emailField : phoneField) + ' IN :values';
                String escapedQuery = String.escapeSingleQuotes(query);
                List<SObject> matchedRecords = Database.query(escapedQuery, AccessLevel.USER_MODE);

                // Build wrappers
                for (SObject record : matchedRecords) {
                    String value = communicationType == 'Email' ? (String)record.get(emailField) : (String)record.get(phoneField);
                    BroadcastMemberWrapper wrapper = new BroadcastMemberWrapper();
                    wrapper.record = record;
                    wrapper.status = phoneToChatStatus.get(value);
                    wrapper.hasReplied = phoneToHasReply.containsKey(value) ? phoneToHasReply.get(value) : false;
                    memberWrappers.add(wrapper);
                }

                groupMembersMap.put(groupId, memberWrappers);
            }

        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'BroadcastMessageController', 'getAllBroadcastMembers', e.getMessage());
        }
        
        return groupMembersMap;
    }
}