public with sharing class FlowEventHandler {

    /*@InvocableMethod(label='Process Event Records from Flow' description='Receive List of Event records from Flow and schedule reminders')
    public static void handleEvents(List<FlowInputs> inputs) {

        try {
            List<Event> eventsFromFlow = new List<Event>();
            for (FlowInputs input : inputs) {
                if (input.eventsFromFlow != null) {
                    eventsFromFlow.addAll(input.eventsFromFlow);
                }
            }

            if(eventsFromFlow == null){
                return;
            }

            for (Event ev : eventsFromFlow) {
                if (ev.StartDateTime != null) {
                    // Calculate schedule time = Event.StartDateTime - 1 hour
                    Datetime scheduleTime = ev.StartDateTime.addHours(-1);
                    // Must be in the future to schedule
                    if (scheduleTime > Datetime.now()) {
                        // Build a unique job name
                        String jobName = 'EventReminder_' + ev.Id + '_' + Datetime.now().getTime();

                        // Create instance of schedulable class with event id
                        EventReminderScheduler schedJob = new EventReminderScheduler(ev.Id);
                        String cronExp = generateCronExpression(scheduleTime);

                        System.schedule(jobName, cronExp, schedJob);
                    }
                }
            }
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'FlowEventHandler', 'handleEvents', e.getMessage());
        }
        
    }

    // Helper to convert Datetime to CRON string for System.schedule()
    public static String generateCronExpression(Datetime dt) {
        Integer sec = dt.second();
        Integer min = dt.minute();
        Integer hour = dt.hour();
        Integer day = dt.day();
        Integer month = dt.month();
        // Day of week: ? means no specific value
        String cronExp = sec + ' ' + min + ' ' + hour + ' ' + day + ' ' + month + ' ?';
        return cronExp;
    }

    public class FlowInputs {
        @InvocableVariable(required=true)
        public List<Event> eventsFromFlow;
    }*/
}