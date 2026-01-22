/**
* Class Name : PlatformEventController
* Test Class : pending
* Created By : Karan Singh
* Last Modified Date : 09/07/2024
* Last Modified By : Karan Singh
* @description : Used to publish event.
*/
public with sharing class PlatformEventController {

    /**
    * Method Name : publishEvent
    * @param {string} status - The status of the event.
    * @param {string} jsonBody - The body of the event.
    * @param {string} portalName - The name of the portal.
    * @param {string} listingId - The Id of the current lisitng.
    * @description : Used to publish event.
    */
    public static void publishEvent(String status, String jsonBody, String portalName, String listingId) {
        try {
            ResponseEvent__e event = new ResponseEvent__e();
            event.PortalName__c = portalName;
            event.JSONBody__c = jsonBody;
            event.Status__c = status;
            event.Listing_Id__c = listingId;
            EventBus.publish(event);
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'PlatformEventController', 'publishEvent', 'Error while publishing event.');
        }

    }
}