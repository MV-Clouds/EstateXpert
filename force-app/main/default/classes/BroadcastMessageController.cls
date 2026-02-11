public with sharing class BroadcastMessageController {

    @AuraEnabled
    public static Map<String, Object> getObjectConfigs() {
        try {
            Map<String, Object> result = new Map<String, Object>();
            List<Object_Config__mdt> objectConfigList = [
                SELECT ChatWindowConfigInfo__c 
                FROM Object_Config__mdt 
                WITH USER_MODE 
                LIMIT 1
            ];
    
            Map<String, Object> chatConfigData = (Map<String, Object>) JSON.deserializeUntyped(objectConfigList[0].ChatWindowConfigInfo__c);
            
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
    public static List<Broadcast_Group__c> getBroadcastGroups() {
        List<Broadcast_Group__c> broadcastGroups = new List<Broadcast_Group__c>();
        try {
            broadcastGroups = [SELECT Id, Name, Count_of_Members__c, Description__c, Object_Name__c, Phone_Field__c, Communication_Type__c FROM Broadcast_Group__c WITH USER_MODE ORDER BY LastModifiedDate DESC];
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'BroadcastMessageController', 'getBroadcastGroups', e.getMessage());
        }
        return broadcastGroups;
    }

    @AuraEnabled
    public static void deleteBroadcastGroup(Id groupId) {
        try {
            Broadcast_Group__c groupToDelete = [
                SELECT Id FROM Broadcast_Group__c 
                WHERE Id = :groupId 
                WITH USER_MODE 
                LIMIT 1
            ];
            delete as user groupToDelete;
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'BroadcastMessageController', 'deleteBroadcastGroup', e.getMessage());
        }
    }

    @AuraEnabled
    public static List<Broadcast__c> getBroadcastRecs() {
        List<Broadcast__c> broadcastRecs = new List<Broadcast__c>();
        try {
            broadcastRecs = [SELECT Id, Name, Recipient_Count__c, WhatsappTemplate__c, WhatsappTemplate__r.Template_Name__c, Status__c, Total_Sent__c, Total_Delivered__c, Total_Read__c, Total_Failed__c FROM Broadcast__c WITH USER_MODE ORDER BY LastModifiedDate DESC];
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'BroadcastMessageController', 'getBroadcastRecs', e.getMessage());
        }
        return broadcastRecs;
    }

    @AuraEnabled
    public static List<Map<String, Object>> getBroadcastRecsWithReplies() {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        try {
            List<Broadcast__c> broadcasts = [
                SELECT Id, Name,Status__c, CreatedDate, Recipient_Count__c,
                    Total_Sent__c, Total_Delivered__c, Total_Read__c,MVEX__WhatsappTemplate__r.MVEX__Template_Name__c
                FROM Broadcast__c 
                ORDER BY CreatedDate DESC
            ];

            Set<String> allPhones = new Set<String>();
            Map<Id, List<String>> broadcastToPhones = new Map<Id, List<String>>();

            // Collect phones
            for (Broadcast__c b : broadcasts) {
                List<Chat__c> chats = [
                    SELECT Phone__c FROM Chat__c 
                    WHERE WB_Broadcast__c = :b.Id 
                    AND Type_of_Message__c = 'Outbound Messages'
                    LIMIT 50000
                ];
                List<String> phones = new List<String>();
                for (Chat__c c : chats) {
                    phones.add(c.Phone__c);
                    allPhones.add(c.Phone__c);
                }
                broadcastToPhones.put(b.Id, phones);
            }

            // Latest status per phone
            Map<String, String> phoneStatus = new Map<String, String>();
            for (Chat__c c : [
                SELECT Phone__c, Message_Status__c 
                FROM Chat__c 
                WHERE Phone__c IN :allPhones 
                AND Type_of_Message__c = 'Outbound Messages'
                ORDER BY LastModifiedDate DESC
            ]) {
                if (!phoneStatus.containsKey(c.Phone__c)) {
                    phoneStatus.put(c.Phone__c, c.Message_Status__c);
                }
            }

            // Replies
            Map<String, Integer> phoneReplies = new Map<String, Integer>();
            for (AggregateResult ar : [
                SELECT Phone__c, COUNT(Id) cnt
                FROM Chat__c 
                WHERE Phone__c IN :allPhones
                AND Type_of_Message__c = 'Inbound Messages'
                GROUP BY Phone__c
            ]) {
                phoneReplies.put((String)ar.get('MVEX__Phone__c'), (Integer)ar.get('cnt'));
            }

            for (Broadcast__c b : broadcasts) {
                Integer sent = 0, delivered = 0, read = 0, replied = 0, failed = 0;
                for (String phone : broadcastToPhones.get(b.Id)) {
                    String st = phoneStatus.get(phone);
                    if (st == 'Sent') sent++;
                    else if (st == 'Delivered') delivered++;
                    else if (st == 'Seen') read++;
                    else if (st == 'failed') failed++;
                    if (phoneReplies.containsKey(phone)) replied += phoneReplies.get(phone);
                }

                result.add(new Map<String, Object>{
                    'Id' => b.Id,
                    'Name' => b.Name,
                    'MVEX__Status__c' => b.Status__c,
                    'MVEX__Recipient_Count__c' => b.Recipient_Count__c,
                    'MVEX__Total_Sent__c' => sent + delivered + read,
                    'MVEX__Total_Delivered__c' => delivered + read,
                    'MVEX__Total_Failed__c' => failed,
                    'MVEX__Total_Read__c' => read,
                    'MVEX__Total_Replies__c' => replied,
                    'MVEX__Template_Name__c' => b.MVEX__WhatsappTemplate__r.MVEX__Template_Name__c
                });
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'BroadcastMessageController', 'getBroadcastRecsWithReplies', e.getMessage());
        }
        return result;
    }

    @AuraEnabled
    public static Map<String, List<WhatsappTemplate__c>> getTemplatesByObject() {
        Map<String, List<WhatsappTemplate__c>> objectTemplateMap = new Map<String, List<WhatsappTemplate__c>>();
        try {
            List<WhatsappTemplate__c> templates = [
                SELECT Id, Template_Name__c, (SELECT Object_Name__c FROM WB_Template_Variables__r) 
                FROM WhatsappTemplate__c 
                WHERE Status__c = 'Active-Quality Pending'
                WITH USER_MODE 
                ORDER BY LastModifiedDate DESC
            ];
    
            for (WhatsappTemplate__c template : templates) {
                String objectName = template.WB_Template_Variables__r.isEmpty() ? 'Generic' : template.WB_Template_Variables__r[0].Object_Name__c;
                if (!objectTemplateMap.containsKey(objectName)) {
                    objectTemplateMap.put(objectName, new List<WhatsappTemplate__c>());
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

            Broadcast_Group__c broadcastGroup;

            if (isUpdate && String.isNotBlank(broadcastGroupId)) {
                broadcastGroup = [
                    SELECT Id, Name, Description__c, Object_Name__c, List_View__c, Phone_Field__c, Communication_Type__c, Email_Field__c
                    FROM Broadcast_Group__c
                    WHERE Id = :broadcastGroupId
                    WITH USER_MODE
                    LIMIT 1
                ];

                broadcastGroup.Name = name;
                broadcastGroup.Description__c = description;
                broadcastGroup.Object_Name__c = objectApiName;
                broadcastGroup.List_View__c = listViewName;
                broadcastGroup.Phone_Field__c = phoneField;
                broadcastGroup.Communication_Type__c = communicationType;
                broadcastGroup.Email_Field__c = emailField;

                Database.SaveResult updateResult = Database.update(broadcastGroup, false, AccessLevel.USER_MODE);
            } else {
                broadcastGroup = new Broadcast_Group__c(
                    Name = name,
                    Description__c = description,
                    Object_Name__c = objectApiName,
                    List_View__c = listViewName,
                    Phone_Field__c = phoneField,
                    Email_Field__c = emailField,
                    Communication_Type__c = communicationType
                );
                Database.SaveResult insertResult = Database.insert(broadcastGroup, false, AccessLevel.USER_MODE);
            }

            // Use Member_Record_Id__c as unique key for update
            Map<String, Broadcast_Group_Member__c> existingMembersMap = new Map<String, Broadcast_Group_Member__c>();
            if (isUpdate) {
                for (Broadcast_Group_Member__c member : [
                    SELECT Id, Member_Record_Id__c 
                    FROM Broadcast_Group_Member__c 
                    WHERE Broadcast_Group_ID__c = :broadcastGroup.Id
                    WITH USER_MODE
                ]) {
                    if (!String.isBlank(member.Member_Record_Id__c)) {
                        existingMembersMap.put(member.Member_Record_Id__c, member);
                    }
                }
            }

            List<Broadcast_Group_Member__c> newMembersToInsert = new List<Broadcast_Group_Member__c>();
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
                    Broadcast_Group_Member__c member = new Broadcast_Group_Member__c(
                        Broadcast_Group_ID__c = broadcastGroup.Id,
                        Member_Record_Id__c = recId
                    );
                    if (communicationType == 'Both') {
                        member.Phone_Number__c = recPhone;
                        member.Email__c = recEmail;
                    } else if (communicationType == 'Email') {
                        member.Email__c = recEmail;
                    } else {
                        member.Phone_Number__c = recPhone;
                    }
                    newMembersToInsert.add(member);
                }
            }

            List<Broadcast_Group_Member__c> membersToDelete = new List<Broadcast_Group_Member__c>();
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
            Broadcast_Group__c groupRecord = [
                SELECT Id, Name, Description__c, Object_Name__c, List_View__c, Phone_Field__c, Email_Field__c, Communication_Type__c
                FROM Broadcast_Group__c
                WHERE Id = :groupId
                WITH USER_MODE 
                LIMIT 1
            ];

            List<Broadcast_Group_Member__c> groupMembers = [
                SELECT Id, Phone_Number__c, Email__c, Name, Member_Record_Id__c 
                FROM Broadcast_Group_Member__c
                WHERE Broadcast_Group_ID__c = :groupId
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
            Broadcast__c broadcast = new Broadcast__c();
            broadcast.WhatsappTemplate__c = templateId;
            broadcast.Status__c = 'Pending';
            broadcast.Broadcast_Group_IDs__c = String.join(groupIds, ','); // Save all group IDs as a comma-separated string

            String objectApiName = '';
            String phoneField = '';
            List<Chat__c> chatRecs = new List<Chat__c>();

            if (groupIds.size() > 0) {
                List<Broadcast_Group__c> brGroupRecs = [SELECT Id, Name, Object_Name__c, Phone_Field__c FROM Broadcast_Group__c WHERE Id IN :groupIds 
                                                        WITH USER_MODE];
                if (brGroupRecs.size() > 0) {
                    objectApiName = brGroupRecs[0].Object_Name__c;
                    phoneField = brGroupRecs[0].Phone_Field__c;
                }

                List<Broadcast_Group_Member__c> groupMembers = new List<Broadcast_Group_Member__c>();
                groupMembers = [SELECT Id, Name, Phone_Number__c, Broadcast_Group_ID__c FROM Broadcast_Group_Member__c WHERE Broadcast_Group_ID__c IN :groupIds WITH USER_MODE];
                broadcast.Recipient_Count__c = groupMembers.size();
                Database.insert(broadcast, false, AccessLevel.USER_MODE);

                List<String> phoneList = new List<String>();
                if (groupMembers.size() > 0) {
                    for (Broadcast_Group_Member__c member : groupMembers) {
                        if (member.Phone_Number__c != null || member.Phone_Number__c != '') {
                            phoneList.add(member.Phone_Number__c);
                            Chat__c newChat = new Chat__c();
                            newChat.WhatsappTemplate__c = templateId;
                            newChat.Phone__c = member.Phone_Number__c;
                            newChat.Type_of_Message__c = 'OutBound Messages';
                            newChat.Message_Status__c = null;
                            newChat.Message_Type__c = 'Template';
                            newChat.WB_Broadcast__c = broadcast.Id;
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

                Broadcast__c br = new Broadcast__c(Id = broadcast.Id);
                br.Schedule_DateTime__c = userDateTime;
                Database.SaveResult updateResult = Database.update(br, false, AccessLevel.USER_MODE);

                String jobName = 'BroadcastSchedule_' + System.currentTimeMillis();
                System.schedule(jobName, cronExpression, batchSchedular);
            }
            return 'Success';
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
    public static List<Broadcast_Group__c> getBroadcastGroupsByBroadcastId(String broadcastId) {
        try {
            Broadcast__c broadcast = [
                SELECT Broadcast_Group_IDs__c 
                FROM Broadcast__c 
                WHERE Id = :broadcastId 
                WITH USER_MODE 
                LIMIT 1
            ];

            if (broadcast.Broadcast_Group_IDs__c == null) {
                return new List<Broadcast_Group__c>();
            }

            List<String> groupIds = broadcast.Broadcast_Group_IDs__c.split(',');
            return [
                SELECT Id, Name, Count_of_Members__c, Description__c, Object_Name__c, Phone_Field__c, Email_Field__c, Communication_Type__c
                FROM Broadcast_Group__c 
                WHERE Id IN :groupIds 
                WITH USER_MODE
            ];
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'BroadcastMessageController', 'getBroadcastGroupsByBroadcastId', e.getMessage());
            return new List<Broadcast_Group__c>();
        }
    }

    @AuraEnabled
    public static List<Map<String, Object>> getBroadcastGroupsWithStats(String broadcastId) {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        
        try {
            Broadcast__c broadcast = [
                SELECT Broadcast_Group_IDs__c, CreatedDate
                FROM Broadcast__c 
                WHERE Id = :broadcastId 
                WITH USER_MODE 
                LIMIT 1
            ];

            if (String.isBlank(broadcast.Broadcast_Group_IDs__c)) return result;

            List<String> groupIds = broadcast.Broadcast_Group_IDs__c.split(',');
            
            // Get groups
            List<Broadcast_Group__c> groups = [
                SELECT Id, Name, Count_of_Members__c, Description__c, Object_Name__c, Phone_Field__c, Email_Field__c, Communication_Type__c
                FROM Broadcast_Group__c 
                WHERE Id IN :groupIds 
                WITH USER_MODE
            ];

            // Get phones per group
            Map<Id, Set<String>> groupToPhones = new Map<Id, Set<String>>();
            for (Broadcast_Group_Member__c m : [
                SELECT Broadcast_Group_ID__c, Phone_Number__c 
                FROM Broadcast_Group_Member__c 
                WHERE Broadcast_Group_ID__c IN :groupIds AND Phone_Number__c != null
                WITH USER_MODE
            ]) {
                if (!groupToPhones.containsKey(m.Broadcast_Group_ID__c)) {
                    groupToPhones.put(m.Broadcast_Group_ID__c, new Set<String>());
                }
                groupToPhones.get(m.Broadcast_Group_ID__c).add(m.Phone_Number__c);
            }

            Set<String> allPhones = new Set<String>();
            for (Set<String> phones : groupToPhones.values()) allPhones.addAll(phones);

            // Get ONLY outbound messages for this broadcast
            List<Chat__c> outboundMessages = [
                SELECT Phone__c, Message_Status__c
                FROM Chat__c 
                WHERE Phone__c IN :allPhones
                AND WB_Broadcast__c = :broadcastId
                AND Type_of_Message__c = 'Outbound Messages'
                WITH USER_MODE
            ];

            // Count latest status per phone
            Map<String, String> phoneToStatus = new Map<String, String>();
            for (Chat__c msg : outboundMessages) {
                String status = msg.Message_Status__c;
                if (status == 'Seen' || status == 'Delivered' || status == 'Sent') {
                    phoneToStatus.put(msg.Phone__c, status);
                }
            }

            // Count replies
            Map<String, Integer> phoneToReplies = new Map<String, Integer>();
            for (AggregateResult ar : [
                SELECT Phone__c, COUNT(Id) cnt
                FROM Chat__c 
                WHERE Phone__c IN :allPhones
                AND Type_of_Message__c = 'Inbound Messages'
                AND CreatedDate >= :broadcast.CreatedDate
                GROUP BY Phone__c
            ]) {
                phoneToReplies.put((String)ar.get('MVEX__Phone__c'), (Integer)ar.get('cnt'));
            }

            // Build result
            Integer index = 1;
            for (Broadcast_Group__c grp : groups) {
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
                    'MVEX__Count_of_Members__c' => grp.Count_of_Members__c,
                    'MVEX__Description__c' => grp.Description__c,
                    'MVEX__Object_Name__c' => grp.Object_Name__c,
                    'MVEX__Phone_Field__c' => grp.Phone_Field__c,
                    'MVEX__Email_Field__c' => grp.Email_Field__c,
                    'index' => index++,
                    'MVEX__Total_Sent__c' => sent + delivered + seen,
                    'MVEX__Total_Delivered__c' => delivered + seen,
                    'MVEX__Total_Failed__c' => failed,
                    'MVEX__Total_Read__c' => seen,
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

            List<Broadcast_Group__c> groups = [SELECT Communication_Type__c FROM Broadcast_Group__c WHERE Id = :groupId WITH USER_MODE LIMIT 1];
            String communicationType = groups.isEmpty() ? 'Phone' : groups[0].Communication_Type__c;

            List<Broadcast_Group_Member__c> members = [
                SELECT Phone_Number__c, Email__c, Status__c 
                FROM Broadcast_Group_Member__c 
                WHERE Broadcast_Group_ID__c = :groupId 
                AND (Phone_Number__c != null OR Email__c != null) 
                WITH USER_MODE
            ];

            Map<String, String> valueToStatus = new Map<String, String>();
            Set<String> values = new Set<String>();

            for (Broadcast_Group_Member__c member : members) {
                String value = communicationType == 'Email' ? member.Email__c : member.Phone_Number__c;
                if (String.isNotBlank(value)) {
                    valueToStatus.put(value, member.Status__c);
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

            // Get broadcast creation date for reply filtering
            Broadcast__c broadcast = [SELECT CreatedDate FROM Broadcast__c WHERE Id = :broadcastId WITH USER_MODE LIMIT 1];
            
            // Get reply counts for each phone number
            Map<String, Boolean> phoneToHasReply = new Map<String, Boolean>();
            if (!values.isEmpty()) {
                List<Chat__c> replyMessages = [
                    SELECT Phone__c
                    FROM Chat__c 
                    WHERE Phone__c IN :values
                    AND Type_of_Message__c = 'Inbound Messages'
                    AND CreatedDate >= :broadcast.CreatedDate
                    WITH USER_MODE
                ];

                for (Chat__c reply : replyMessages) {
                    phoneToHasReply.put(reply.Phone__c, true);
                }
            }

            // Step 2: Get phone numbers and statuses
            Set<String> phoneNumbers = new Set<String>();
            for (Broadcast_Group_Member__c member : members) {
                phoneNumbers.add(member.Phone_Number__c);
            }

            if (phoneNumbers.isEmpty()) {
                return new List<BroadcastMemberWrapper>();
            }

            // Step 3: Fetch chat statuses using phone numbers
            Map<String, String> phoneToChatStatus = new Map<String, String>();
            List<Chat__c> broadcastRelatedChats = [SELECT Phone__c, Message_Status__c FROM Chat__c WHERE WB_Broadcast__c = :broadcastId AND Phone__c IN :phoneNumbers WITH SECURITY_ENFORCED];

            for (Chat__c chat : broadcastRelatedChats) {
                // If there are multiple chats per phone, you can decide to pick the latest or first one — adjust as needed
                if (!phoneToChatStatus.containsKey(chat.Phone__c)) {
                    phoneToChatStatus.put(chat.Phone__c, chat.Message_Status__c);
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
    public static String getSessionId() {
        String sessionId;
        try {
            if (Test.isRunningTest()) {
                sessionId = 'testSessionId';
            } else {
                sessionId = Page.UserSessionIdPage.getContent().toString();
            }
        } catch (Exception e) {
            ErrorHandler.insertErrordata(e, 'BroadcastMessageController', 'getSessionId', e.getMessage());
            sessionId = 'Error: ' + e.getMessage();
        }
        return sessionId;
    }
}