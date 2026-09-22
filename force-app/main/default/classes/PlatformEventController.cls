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
            MVEX__ResponseEvent__e event = new MVEX__ResponseEvent__e();
            event.MVEX__PortalName__c = portalName;
            event.MVEX__JSONBody__c = jsonBody;
            event.MVEX__Status__c = status;
            event.MVEX__Listing_Id__c = listingId;
            EventBus.publish(event);
        } catch (Exception e) {
            ErrorHandler.insertErrorData(e, 'PlatformEventController', 'publishEvent', 'Error while publishing event.');
        }

    }
}