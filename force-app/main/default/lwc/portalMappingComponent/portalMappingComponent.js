import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getPortalRecords from '@salesforce/apex/PortalMappingController.getPortalRecords';
import portalAction from '@salesforce/apex/PortalMappingController.portalAction';
import portalMappingIcon from '@salesforce/resourceUrl/iconimg';
import { loadStyle } from 'lightning/platformResourceLoader';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
import { errorDebugger } from 'c/globalProperties';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
export default class PortalMappingComponent extends NavigationMixin(LightningElement) {

    @track isInitalRender = true;
    @track clickedPortalName = '';
    @track clickedPortalIconURL = '';
    @track portalRecordList = [];
    @track isPortalData = true;
    @track showModal = false;
    @track portals = [];
    @track isSpinner = true;
    @track portalMappingIcon = portalMappingIcon;
    @track subscription = {};
    @track channelName = '/event/MVEX__ResponseEvent__e';
    @track errorBody;
    @track isErrorPopup = false;
    @track selectedPortalId;
    @track selectedPortalName;
    @track propertyEditModal = false;
    @track portalIconUrl;
    @track portalGen;
    @track isXMLForPF = false;

    /**
    * Method Name: connectedCallback
    * @description: Used to call getPortalRecord method.
    * Created Date: 04/06/2024
    * Updated Date: 23/12/2024
    * Created By: Karan Singh
    * Updated By: Karan Singh
    */
    connectedCallback() {
        try {
            loadStyle(this, MulishFontCss);
            this.getPortalRecord();
            this.registerErrorListener();
            this.handleSubscribe();
        } catch (error) {
            errorDebugger('PortalMappingComponent', 'connectedCallback', error, 'warn', 'Error in connectedCallback');
        }
    }

    /**
    * Method Name: getPortalRecord
    * @description: Used to make an Apex callout to retrieve all records of the Portal__c object.
    * Created Date: 04/06/2024
    * Created By: Karan Singh
    */
    getPortalRecord() {
        this.isSpinner = true;
        try {
            getPortalRecords()
                .then(result => {
                    this.portals = result.portalDetailsRecords;
                    this.isXMLForPF = result.isXMLForPF;
                    if (result.portalRecords.length > 0) {
                        this.portalRecordList = result.portalRecords.map((val, index) => ({
                            number: index + 1,
                            val: val
                        }));
                        this.isPortalData = true;
                    } else {
                        this.isPortalData = false;
                    }
                    this.isSpinner = false;
                })
                .catch(error => {
                    this.isSpinner = false;
                    errorDebugger('PortalMappingComponent', 'getPortalRecord', error, 'warn', 'Error in getPortalRecord');
                });
        } catch (error) {
            this.isSpinner = false;
            errorDebugger('PortalMappingComponent', 'getPortalRecord', error, 'warn', 'Error in getPortalRecord');
        }
    }

    /**
    * Method Name: registerErrorListener
    * @description: Used to register the error listener.
    * Created Date: 09/07/2024
    * Updated Date: 23/12/2024
    * Created By: Karan Singh
    * Updated By: Karan Singh
    */
    registerErrorListener() {
        try {
            onError(error => {
                errorDebugger('PortalMappingComponent', 'registerErrorListener', error, 'warn', 'Error in registerErrorListener');
            });
        } catch (error) {
            errorDebugger('PortalMappingComponent', 'registerErrorListener', error, 'warn', 'Error in registerErrorListener');
        }
    }

    /**
    * Method Name: handleSubscribe
    * @description: Used to subscribe to the platform event channel.
    * Created Date: 09/07/2024
    * Created By: Karan Singh
    */
    handleSubscribe() {
        try {
            const self = this;
            const messageCallback = function (response) {
                let obj = JSON.parse(JSON.stringify(response));
                let objData = obj.data.payload;
                let status = objData.MVEX__Status__c;
                let responseBody = objData.MVEX__JSONBody__c;
                let portalName = objData.MVEX__PortalName__c;
                if (portalName === 'Zoopla Branch') {
                    if (status === 'Failed') {
                        let errorDetails = [];
                        let responseBodyParsed = JSON.parse(responseBody);
                        if (responseBodyParsed.errors) {
                            errorDetails.push(...responseBodyParsed.errors.map(error => ({
                                message: error.message,
                                path: error.path
                            })));
                            errorDetails = JSON.stringify(errorDetails);
                        }

                        self.errorBody = errorDetails;
                        self.isErrorPopup = true;
                        self.getPortalRecord();
                    }
                }
            };

            subscribe(self.channelName, -1, messageCallback).then(response => {
                self.subscription = response;
            });
        } catch (error) {
            errorDebugger('PortalMappingComponent', 'handleSubscribe', error, 'warn', 'Failed to subscribe to platform event channel for Zoopla Branch portal updates');
        }
    }

    /**
    * Method Name: handleHidePopup
    * @description: Used to close the new popup modal.
    * Created Date: 04/06/2024
    * Updated Date: 23/12/2024
    * Created By: Karan Singh
    * Updated By: Karan Singh
    */
    handleHidePopup(event) {
        try {
            this.showModal = event.details;
            this.isErrorPopup = event.details;
            this.propertyEditModal = event.details;
            this.selectedPortalId = null;
            this.portalIconUrl = null;
            this.portalGen = null;
        } catch (error) {
            errorDebugger('PortalMappingComponent', 'handleHidePopup', error, 'warn', 'Failed to hide popup modal in handleHidePopup method');
        }
    }

    /**
    * Method Name: handleHideAndRefreshPage
    * @description: Used to close the new popup modal and refresh the page.
    * Created Date: 04/06/2024
    * Updated Date: 23/12/2024
    * Created By: Karan Singh
    * Updated By: Karan Singh
    */
    handleHideAndRefreshPage(event) {
        try {
            this.showModal = event.details;
            this.isErrorPopup = event.details;
            this.propertyEditModal = event.details;
            this.selectedPortalId = null;
            this.portalIconUrl = null;
            this.portalGen = null;
            this.getPortalRecord();
        } catch (error) {
            errorDebugger('PortalMappingComponent', 'handleHideAndRefreshPage', error, 'warn', 'Failed to hide and refresh page in handleHideAndRefreshPage method');
        }
    }

    /**
    * Method Name: handleClick
    * @description: Used to navigate to portalMappingLandingPage by firing custom event.
    * Date: 04/06/2024
    * Updated: 17/02/2026
    * Created By: Karan Singh
    * Updated By: Karan Singh
    * Change Description: Changed to fire custom event for control center navigation.
    */
    handleClick(event) {
        try {
            event.preventDefault();
            let portalId = event.currentTarget.dataset.portalid;
            let portalName = event.currentTarget.dataset.portalname;
            let portalIconURL = event.currentTarget.dataset.portaliconurl;
            let portalStatus = event.currentTarget.dataset.portalstatus;
            let portalGen = event.currentTarget.dataset.portalgen;

            // Fire custom event for control center to handle navigation
            const navigateEvent = new CustomEvent('portalnavigate', {
                detail: {
                    portalId: portalId,
                    portalGen: portalGen,
                    portalName: portalName,
                    portalIconUrl: portalIconURL,
                    portalStatus: portalStatus,
                    isXMLForPF: this.isXMLForPF
                },
                bubbles: true,
                composed: true
            });
            this.dispatchEvent(navigateEvent);
        } catch (error) {
            errorDebugger('PortalMappingComponent', 'handleClick', error, 'warn', 'Failed to navigate to portalMappingLandingPage in handleClick method');
        }
    }

    /**
    * Method Name: handleNew
    * @description: Used to pass Portal name and Portal icon image URL to newPopUp lwc component.
    * Created Date: 04/06/2024
    * Updated Date: 23/12/2024
    * Created By: Karan Singh
    * Updated By: Karan Singh
    */
    handleNew(event) {
        try {
            this.clickedPortalName = event.currentTarget.dataset.portalname;
            this.clickedPortalIconURL = event.currentTarget.dataset.portaliconurl;
            this.showModal = true;
        } catch (error) {
            errorDebugger('PortalMappingComponent', 'handleNew', error, 'warn', 'Failed to pass Portal name and Portal icon image URL to newPopUp lwc component in handleNew method');
        }
    }

    /**
    * Method Name: backToControlCenter
    * @description: Used to Navigate to the main ControlCenter page.
    * Created Date: 04/06/2024
    * Created By: Karan Singh
    */
    backToControlCenter(event) {
        try {
            event.preventDefault();
            this[NavigationMixin.Navigate]({
                type: "standard__navItemPage",
                attributes: {
                    apiName: "MVEX__Control_Center",
                },
            });
        } catch (error) {
            errorDebugger('PortalMappingComponent', 'backToControlCenter', error, 'warn', 'Failed to navigate to the main ControlCenter page in backToControlCenter method');
        }
    }

    /**
    * Method Name: disconnectedCallback
    * @description: Used to unsubscribe from the platform event channel.
    * Created Date: 09/07/2024
    * Updated Date: 23/12/2024
    * Created By: Karan Singh
    * Updated By: Karan Singh
    */
    disconnectedCallback() {
        try {
            unsubscribe(this.subscription, response => {
                errorDebugger('PortalMappingComponent', 'disconnectedCallback', response, 'info', 'Unsubscribed from platform event channel');
            });
        } catch (error) {
            errorDebugger('PortalMappingComponent', 'disconnectedCallback', error, 'warn', 'Failed to unsubscribe from the platform event channel in disconnectedCallback method');
        }
    }

    handleDelete(event) {
        this.selectedPortalId = event.currentTarget.dataset.portalId;
        this.selectedPortalName = event.currentTarget.dataset.portalName;
        this.showMessagePopup('Warning', 'Do you want to delete this portal?', `Are you sure you want to delete the ${this.selectedPortalName} portal? This action cannot be undone.`);
    }

    /**
    * Method Name: handleConfirmation
    * @description: Used to handle the confirmation of the delete action.
    * Created Date: 17/07/2025
    * Created By: Rachit Shah
    **/
    handleConfirmation(event) {

        if(event.detail === true){
            this.selectedPortalAction(this.selectedPortalId, this.selectedPortalName, 'delete');
        }
        else{
            this.selectedPortalId = null;
            this.selectedPortalName = null;
        }

    }

    handleStatusChange(event) {
        this.selectedPortalId = event.currentTarget.dataset.portalId;
        this.selectedPortalName = event.currentTarget.dataset.portalName;
        let isChecked = event.currentTarget.checked;
        let actionName = isChecked ? 'activate' : 'deactivate';
        this.selectedPortalAction(this.selectedPortalId, this.selectedPortalName, actionName);
    }

    handleEditPortal(event) {
        this.selectedPortalId = event.currentTarget.dataset.portalId;
        this.portalIconUrl = event.currentTarget.dataset.portaliconurl;
        this.portalGen = event.currentTarget.dataset.portalgen;
        this.propertyEditModal = true;
    }

    selectedPortalAction(portalId, portalName, actionName) {
        try {
            this.isSpinner = true;
            portalAction({ portalId, actionName })
                .then(result => {
                    this.isSpinner = false;
                    if (result === 'deactivated') {
                        this.showToast('Success', 'The ' + portalName + ' portal has been successfully deactivated.', 'success');
                    } else if (result === 'activated') {
                        this.showToast('Success', 'The ' + portalName + ' portal has been successfully activated.', 'success');
                    } else if (result === 'deleted') {
                        this.showToast('Success', 'The ' + portalName + ' portal has been successfully deleted.', 'success');
                    }
                    this.getPortalRecord();
                    this.selectedPortalId = null;
                    this.selectedPortalName = null;
                })
                .catch(error => {
                    this.isSpinner = false;
                    console.log('Error in selectedPortalAction:', error);
                    this.showToast('Error', 'Failed to update record', 'error');
                });
        } catch (error) {
            this.isSpinner = false;
            console.log('Error in selectedPortalAction:', error);
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    showMessagePopup(Status, Title, Message) {
        const messageContainer = this.template.querySelector('c-message-popup')
        if (messageContainer) {
            messageContainer.showMessagePopup({
                status: Status,
                title: Title,
                message: Message,
            });
        }
    }

}