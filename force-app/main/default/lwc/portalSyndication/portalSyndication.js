import { LightningElement, api, track } from 'lwc';
import fetchPortals from "@salesforce/apex/PortalSyndicationController.fetchPortals";
import createPortalListingRecord from "@salesforce/apex/PortalSyndicationController.createPortalListingRecord";
import { loadStyle } from 'lightning/platformResourceLoader';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
import { errorDebugger } from 'c/globalProperties';

export default class PortalSyndication extends LightningElement {
    @api recordId;
    @track portals = [];
    @track portalId;
    @track showSpinner = true;
    @track status;
    @track responseBody;
    @track errorBody;
    @track portalName;
    @track listingPopupId;
    @track isErrorPopup = false;
    @track subscription = {};
    @track channelName = '/event/MVEX__ResponseEvent__e';
    @track isDataAvailable = false;
    @track errorType = 'publish';
    @track isXMLForPF = false;

    /**
    * Method Name: connectedCallback
    * @description: Used to call fetchPortals method.
    * Created Date: 09/07/2024
    * Created By: Karan Singh
    */
    connectedCallback() {
        try {
            loadStyle(this, MulishFontCss);
            this.fetchPortalDatas();
        } catch (error) {
            errorDebugger('PortalSyndication', 'connectedCallback', error, 'warn', 'Error occurred while fetching the portal datas');
        }
    }

    /**
    * Method Name: fetchPortalDatas
    * @description: Used to fetch the portal datas.
    * Created Date: 12/07/2024
    * Last Updated: 24/12/2024
    * Created By: Karan Singh
    * Last Updated By: Karan Singh
    */
    fetchPortalDatas() {
        try {
            fetchPortals({ listingId: this.recordId })
            .then(data => {
                if (data) {
                    this.portals = data.portalData.map(portal => ({
                        ...portal,
                        buttonLabel: portal.flag ? 'Unpublish' : 'Publish',
                        buttonColor: portal.flag ? 'unpublish_css' : 'publish_css',
                        badgeColor: portal.flag ? 'active_cls' : 'inactive_cls',
                    }));
                    this.isXMLForPF = data.isXMLForPF;
                }

                this.isDataAvailable = this.portals.length > 0 ? true : false;
                let isPortal = this.checkPortals();
                if (isPortal) {
                    this.registerErrorListener();
                    this.handleSubscribe();
                }

                this.showSpinner = false;
            })
            .catch(error => {
                this.showSpinner = false;
                this.showToast('Error', error?.message || error?.body?.message, 'error');
            });
        } catch (error) {
            errorDebugger('PortalSyndication', 'fetchPortalDatas', error, 'warn', 'Error occurred while fetching the portal datas');
        }
    }

    /**
    * Method Name: checkPortals
    * @description: Used to check if the portals are present.
    * Created Date: 09/07/2024
    * Last Updated: 24/12/2024
    * Created By: Karan Singh
    * Last Updated By: Karan Singh
    */
    checkPortals() {
        try {
            return this.portals.some(record => (record.pname === 'Rightmove' || record.pname === 'Rightmove Overseas' || record.pname === 'Zoopla' || (record.pname === 'Propertyfinder' && !this.isXMLForPF)));
        } catch (error) {
            errorDebugger('PortalSyndication', 'checkPortals', error, 'warn', 'Error occurred while checking the portals');
            return false;
        }
    }

    /**
    * Method Name: registerErrorListener
    * @description: Used to register the error listener.
    * Created Date: 09/07/2024
    * Last Updated: 24/12/2024
    * Created By: Karan Singh
    * Last Updated By: Karan Singh
    */
    registerErrorListener() {
        try {
            onError(error => {
                errorDebugger('PortalSyndication', 'registerErrorListener', error, 'warn', 'Error occurred while registering the error listener');
            });
        } catch (error) {
            errorDebugger('PortalSyndication', 'registerErrorListener', error, 'warn', 'Error occurred while registering the error listener');
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
                self.status = objData.MVEX__Status__c;
                self.responseBody = objData.MVEX__JSONBody__c;
                self.portalName = objData.MVEX__PortalName__c;
                self.listingPopupId = objData.MVEX__Listing_Id__c;
                if (self.recordId === self.listingPopupId) {
                    if (self.status === 'Failed') {
                        let errorDetails = [];
                        let responseBodyParsed = JSON.parse(self.responseBody);
                        if (self.portalName === 'Zoopla' && responseBodyParsed.errors) {
                            errorDetails.push(...responseBodyParsed.errors.map(error => ({
                                message: error.message,
                                path: error.path
                            })));
                            errorDetails = JSON.stringify(errorDetails);
                        } else if (self.portalName === 'Rightmove' || self.portalName === 'Rightmove Overseas') {
                            if (responseBodyParsed.errors) {
                                errorDetails.push(...responseBodyParsed.errors.map(error => ({
                                    message: error.error_description,
                                    path: error.error_value != null ? error.error_value : ''
                                })));
                            }
                            if (responseBodyParsed.warnings) {
                                errorDetails.push(...responseBodyParsed.warnings.map(warning => ({
                                    message: warning.warning_description,
                                    path: warning.warning_value != null ? warning.warning_value : ''
                                })));
                            }
                            if (!responseBodyParsed.success) {
                                errorDetails.push({
                                    message: responseBodyParsed.message,
                                    path: ''
                                });
                            }

                            errorDetails = JSON.stringify(errorDetails);
                        } else if (self.portalName === 'Property Finder' && !this.isXMLForPF) {
                            // Handle Property Finder error structure
                            if (responseBodyParsed.errors && Array.isArray(responseBodyParsed.errors)) {
                                errorDetails.push(...responseBodyParsed.errors.map(error => ({
                                    message: error.detail || '',
                                    pointer: error.pointer || ''
                                })));
                            } else {
                                // fallback if errors array is missing
                                errorDetails.push({
                                    message: responseBodyParsed.detail || '',
                                    pointer: responseBodyParsed.type || ''
                                });
                            }
                            errorDetails = JSON.stringify(errorDetails);
                        }

                        self.errorBody = errorDetails;
                        self.errorType = 'publish';
                        self.isErrorPopup = true;
                        self.refreshComponent();
                    } else if (self.status === 'Refresh') {
                        self.showToast('Error', 'Please publish the listing again on Zoopla or Rightmove.', 'error');
                        self.refreshComponent();
                    } else if (self.status === 'Exception') {
                        let errorDetails = [];
                        errorDetails.push({
                            message: self.responseBody,
                            path: ''
                        });

                        errorDetails = JSON.stringify(errorDetails);
                        self.errorBody = errorDetails;
                        self.isErrorPopup = true;
                        self.errorType = 'publish';
                        self.refreshComponent();
                    } else if (self.status === 'Failed Delete') {
                        let errorDetails = [];
                        let responseBody = JSON.parse(self.responseBody);
                        errorDetails.push({
                            message: responseBody.detail || self.responseBody,
                            path: ''
                        });
                        errorDetails = JSON.stringify(errorDetails);
                        self.errorBody = errorDetails;
                        self.errorType = 'delete';
                        self.isErrorPopup = true;
                        self.refreshComponent();
                    } else {
                        self.refreshComponent();
                    }
                }
            };

            subscribe(self.channelName, -1, messageCallback).then(response => {
                self.subscription = response;
            });
        } catch (error) {
            errorDebugger('PortalSyndication', 'handleSubscribe', error, 'warn', 'Error occurred while subscribing to the platform event channel');
        }
    }

    /**
    * Method Name: refreshComponent
    * @description: Used to refresh the component.
    * Created Date: 09/07/2024
    * Last Updated: 24/12/2024
    * Created By: Karan Singh
    * Last Updated By: Karan Singh
    */
    refreshComponent() {
        try {
            this.showSpinner = true;
            fetchPortals({ listingId: this.recordId })
                .then(data => {
                    this.portals = data.portalData.map(portal => ({
                        ...portal,
                        buttonLabel: portal.flag ? 'Unpublish' : 'Publish',
                        buttonColor: portal.flag ? 'unpublish_css' : 'publish_css',
                        badgeColor: portal.flag ? 'active_cls' : 'inactive_cls',
                    }));
                    this.showSpinner = false;
                })
                .catch(error => {
                    this.showSpinner = false;
                    this.showToast('Error', error?.message || error?.body?.message, 'error');
                });
        } catch (error) {
            errorDebugger('PortalSyndication', 'refreshComponent', error, 'warn', 'Error occurred while refreshing the component');
            this.showSpinner = false;
        }
    }

    /**
    * Method Name: refreshComponent
    * @description: Used to refresh the component.
    * Created Date: 09/07/2024
    * Last Updated: 24/12/2024
    * Created By: Karan Singh
    * Last Updated By: Karan Singh
    */
    handleToggleStatus(event) {
        try {
            this.showSpinner = true;
            let portalName = event.currentTarget.dataset.pname;
            let rowId = event.currentTarget.dataset.id;
            let actionType = event.currentTarget.dataset.buttonLabel;
            this.handleButtonClick(rowId, actionType, portalName);
        } catch (error) {
            errorDebugger('PortalSyndication', 'handleToggleStatus', error, 'warn', 'Error occurred while toggling the status');
            this.showSpinner = false;
        }
    }

    /**
    * Method Name: handleButtonClick
    * @description: Used to handle the button click.
    * Created Date: 09/07/2024
    * Last Updated: 24/12/2024
    * Created By: Karan Singh
    * Last Updated By: Karan Singh
    */
    handleButtonClick(rowId, actionType, portalName) {
        try {
            createPortalListingRecord({ portalId: rowId, listingId: this.recordId, actionType: actionType, portalName: portalName })
            .then(result => {
                if (result === 'Success') {
                    if (!this.checkForPortal(portalName, actionType)) {
                        this.refreshComponent();
                    }
                } else {
                    this.showToast('Error', result, 'error');
                    this.showSpinner = false;
                }
            })
            .catch(error => {
                this.showSpinner = false;
                this.showToast('Error', error?.message || error?.body?.message, 'error');
            });
        } catch (error) {
            errorDebugger('PortalSyndication', 'handleButtonClick', error, 'warn', 'Error occurred while handling the button click');
            this.showSpinner = false;
        }
    }

    /**
    * Method Name: checkForPortal
    * @description: Used to check if the spinner is visible.
    * Created Date: 09/07/2024
    * Last Updated: 24/12/2024
    * Created By: Karan Singh
    * Last Updated By: Karan Singh
    */
    checkForPortal(portalName, actionType) {
        try {
            if ((portalName === 'Zoopla' || portalName === 'Rightmove' || portalName === 'Rightmove Overseas' || (portalName === 'Propertyfinder' && !this.isXMLForPF)) && actionType === 'Publish') {
                return true;
            } else if (portalName === 'Propertyfinder' && actionType === 'Unpublish' && !this.isXMLForPF) {
                return true;
            }
    
            return false;
        } catch (error) {
            errorDebugger('PortalSyndication', 'checkForPortal', error, 'warn', 'Error occurred while checking if the spinner is visible');
            return false;
        }
    }

    /**
    * Method Name: handleHidePopup
    * @description: Used to hide the popup.
    * Created Date: 09/07/2024
    * Last Updated: 24/12/2024
    * Created By: Karan Singh
    * Last Updated By: Karan Singh
    */
    handleHidePopup(event) {
        try {
            this.isErrorPopup = event.details;
        } catch (error) {
            errorDebugger('PortalSyndication', 'handleHidePopup', error, 'warn', 'Error occurred while hiding the popup');
            this.isErrorPopup = false;
        }
    }

    /**
    * Method Name: handleHidePopup
    * @description: Used to hide the popup.
    * Created Date: 09/07/2024
    * Last Updated: 24/12/2024
    * Created By: Karan Singh
    * Last Updated By: Karan Singh
    */
    showToast(title, message, variant) {
        try {
            if (typeof window !== 'undefined') {
                const event = new ShowToastEvent({
                    title: title,
                    message: message,
                    variant: variant,
                });
                this.dispatchEvent(event);
            }
        } catch (error) {
            errorDebugger('PortalSyndication', 'showToast', error, 'warn', 'Error occurred while showing the toast');
        }
    }

    /**
    * Method Name: disconnectedCallback
    * @description: Used to unsubscribe from the platform event channel.
    * Created Date: 09/07/2024
    * Last Updated: 24/12/2024
    * Created By: Karan Singh
    * Last Updated By: Karan Singh
    */
    disconnectedCallback() {
        try {
            unsubscribe(this.subscription, response => {
                errorDebugger('PortalSyndication', 'disconnectedCallback', response, 'info', 'Unsubscribed from platform event channel');
            });
        } catch (error) {
            errorDebugger('PortalSyndication', 'disconnectedCallback', error, 'warn', 'Error occurred while unsubscribing from the platform event channel');
        }
    }
}