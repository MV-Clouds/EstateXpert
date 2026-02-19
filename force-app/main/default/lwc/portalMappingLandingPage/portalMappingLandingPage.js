import { LightningElement, track, api } from 'lwc';
import getObjectFields from '@salesforce/apex/PortalMappingController.getObjectFields';
import saveChangedFields from '@salesforce/apex/PortalMappingController.saveChangedFields';
import portalAction from '@salesforce/apex/PortalMappingController.portalAction';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { loadStyle } from 'lightning/platformResourceLoader';
import portalmappingcss from '@salesforce/resourceUrl/portalmappingcss';
import { errorDebugger } from 'c/globalProperties';

export default class PortalMappingLandingPage extends NavigationMixin(LightningElement) {

    @api portalId;
    @api portalGen;
    @api portalName;
    @api portalIconUrl;
    @api portalStatus;
    @api isCreateable;
    @api isXMLForPF;
    @track portalStatusToAssign;
    @track isInitalRender = true;
    @track originalMappingData = [];
    @track fieldWrapperList = [];
    @track finalList = [];
    @track MainListingOptions = [];
    @track isDataChanged = false;
    @track isRecordAvailable = true;
    @track isSpinner = true;
    @track showModal = false;
    @track portalNameToShow;
    @track showListingPopup = false;

    /**
    * Method Name: connectedCallback
    * @description: Used to call getListingFields method.
    * Created Date: 04/06/2024
    * Last Updated Date: 04/06/2024
    * Created By: Karan Singh
    * Last Updated By: Karan Singh
    */
    connectedCallback() {
        try {
            this.portalStatusToAssign = this.portalStatus;
            loadStyle(this, portalmappingcss);
            this.portalNameToShow = this.portalName;
            this.getListingFields();
        } catch (error) {
            errorDebugger('PortalMappingLandingPage', 'connectedCallback', error, 'warn', 'Error in connectedCallback');
        }
    }

    /**
    * Method Name: activeInactive
    * @description: Used to change the status as per portalStatusToAssign value.
    * Created Date: 04/06/2024
    * Created By: Karan Singh
    */
    get activeInactive(){
        return this.portalStatusToAssign === 'true' ? true : false;
    }

    /**
    * Method Name: isButtonsDisabled
    * @description: Returns true if no changes have been made to disable save and revert buttons.
    * Created Date: 17/02/2026
    * Created By: Karan Singh
    */
    get isButtonsDisabled() {
        return !this.isDataChanged;
    }

    /**
    * Method Name: getListingFields
    * @description: Used to get all custom metadata, blocked fields and Listing object fields values.
    * Created Date: 04/06/2024
    * Created By: Karan Singh
    */
    getListingFields() {
        this.isSpinner = true;
        this.originalMappingData = [];
        this.finalList = [];
        this.fieldWrapperList = [];
        this.MainListingOptions = [];
        try {
            getObjectFields({ portalName: this.portalGen, isXMLForPF: this.isXMLForPF })
                .then(data => {
                    if (data[0].portalMetadataRecords.length > 0) {
                        this.MainListingOptions = data[0].listingFields;
                        this.processFieldWrapperData(data);
                    } else {
                        this.isRecordAvailable = false;
                        this.isSpinner = false;
                    }

                })
                .catch(error => {
                    this.isSpinner = false;
                    errorDebugger('PortalMappingLandingPage', 'getListingFields', error, 'warn', 'Error occurred while fetching listing fields data from server');
                });
        } catch (error) {
            this.isSpinner = false;
            errorDebugger('PortalMappingLandingPage', 'getListingFields', error, 'warn', 'Error occurred while fetching listing fields data from server');
        }
        
    }

    /**
    * Method Name: processFieldWrapperData
    * @description: Used to prepare list of all fields mapping to show in html.
    * @param: fieldWrapperList - List of all fields mapping.
    * Created Date: 04/06/2024
    * Last Updated Date: 04/06/2024
    * Created By: Karan Singh
    * Last Updated By: Karan Singh
    */
    processFieldWrapperData(fieldWrapperList) {
        try {
            fieldWrapperList.forEach(fieldWrapper => {
                const { portalMetadataRecords, blockfields, listingFields } = fieldWrapper;
    
                const blockfieldsSet = new Set(blockfields);
    
                const filteredListingFields = listingFields.filter(
                    field => !blockfieldsSet.has(field.apiName)
                );
    
                const filteredFields = filteredListingFields.filter(
                    field => !portalMetadataRecords.some(record => record.MVEX__Listing_Field_API_Name__c === field.apiName)
                );
        
                portalMetadataRecords.forEach(record => {
    
                    const finalFilteredFields = filteredFields.filter(field => {
                        switch (record.MVEX__Allowed_Field_Datatype__c) {
                            case 'String':
                                return ['REFERENCE', 'TEXTAREA', 'STRING', 'URL', 'MULTIPICKLIST', 'PICKLIST'].includes(field.dataType);
                            case 'Integer':
                                return ['INTEGER', 'DOUBLE'].includes(field.dataType);
                            case 'Date':
                                return ['DATE', 'DATETIME', 'TIME'].includes(field.dataType);
                            case 'Boolean':
                                return field.dataType === 'BOOLEAN';
                            case 'Email':
                                return field.dataType === 'EMAIL';
                            case 'Phone':
                                return field.dataType === 'PHONE';
                            case 'Currency':
                                return field.dataType === 'CURRENCY';
                            default:
                                return true;
                        }
                    });
        
                    const additionalOptions = finalFilteredFields.map(field => ({
                        label: field.label,
                        value: field.apiName
                    }));
        
                    const finalList = {
                        id: record.Id,
                        portalLabel: record.Name,
                        description: record.MVEX__Portal_Field_Description__c,
                        example: record.MVEX__Portal_Field_Example__c,
                        listingFieldAPIName: record.MVEX__Listing_Field_API_Name__c ? record.MVEX__Listing_Field_API_Name__c : '',
                        isRequired: record.MVEX__Required__c,
                        dataType: record.MVEX__Allowed_Field_Datatype__c,
                        listingFields: [
                            { label: 'None', value: '' },
                            ...(record.MVEX__Listing_Field_API_Name__c ? [{ label: this.getListingLabel(record.MVEX__Listing_Field_API_Name__c), value: record.MVEX__Listing_Field_API_Name__c }] : []),
                            ...additionalOptions
                        ]
                    };
        
                    this.finalList = [...this.finalList, finalList];
                });
            });
    
            this.originalMappingData = JSON.parse(JSON.stringify(this.finalList));
            this.isSpinner = false;
        } catch (error) {
            errorDebugger('PortalMappingLandingPage', 'processFieldWrapperData', error, 'warn', 'Error occurred while processing field wrapper data');
        }
    }
    

    /**
    * Method Name: getListingLabel
    * @description: Used to return Listing field label by getting the field api name.
    * @param {listingFieldValue} listingFieldValue Listing field value.
    * @return {Listing field label}
    * Created Date: 04/06/2024
    * Last Updated Date: 04/06/2024
    * Created By: Karan Singh
    * Last Updated By: Karan Singh
    */
    getListingLabel(listingFieldValue) {
        try {
            const listingOption = this.MainListingOptions.find(option => option.apiName === listingFieldValue);
            return listingOption ? listingOption.label : '';
        } catch (error) {
            errorDebugger('PortalMappingLandingPage', 'getListingLabel', error, 'warn', 'Error occurred while getting listing label');
            return '';
        }
    }

    /**
    * Method Name: handleBack
    * @description: Used to navigate back to Portal Mapping main page.
    * Created Date: 04/06/2024
    * Created By: Karan Singh
    */
    handleBack(event) {
        try {
            event.preventDefault();
            let componentDef = {
                componentDef: "MVEX:portalMappingComponent",
            };
            let encodedComponentDef = btoa(JSON.stringify(componentDef));
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: '/one/one.app#' + encodedComponentDef
                }
            });
        } catch (error) {
            errorDebugger('PortalMappingLandingPage', 'handleBack', error, 'warn', 'Error occurred while navigating back to Portal Mapping main page');
        }
    }

    /**
    * Method Name: handleSave
    * @description: Used to save custom metadata records.
    * Date: 04/06/2024
    * Created By: Karan Singh
    * Last Update Date : 06/06/2024
    * Updated By : Karan Singh
    * Change Description : Changed the variable name from masterLabel to portalLabel and passed the id to apex class instead of masterLabel.
    */
    handleSave() {
        try {
            this.isSpinner = true;
            if (this.isDataChanged) {
                let isValid = true;
                let errorMessage = 'Please fill all required fields:';
    
                this.finalList.forEach((record) => {
                    if (record.isRequired && !record.listingFieldAPIName) {
                        isValid = false;
                        errorMessage += ` ${record.portalLabel},`;
                    }
                });
    
                if (!isValid) {
                    this.showToast('Error', errorMessage.slice(0, -1), 'error');
                    this.isSpinner = false;
                    return;
                }
    
                const changedFields = this.finalList.filter((record, index) => {
                    return record.listingFieldAPIName !== this.originalMappingData[index].listingFieldAPIName;
                }).map(record => ({
                    Id: record.id,
                    MVEX__Listing_Field_API_Name__c: record.listingFieldAPIName
                }));

                const jsonList = {};
                this.finalList.forEach(record => {
                    if (record.listingFieldAPIName) {
                        jsonList[record.listingFieldAPIName] = record.portalLabel;
                    }
                });
                
                if (changedFields.length > 0) {
                    saveChangedFields({ changedFields, jsonList: JSON.stringify(jsonList), portalId: this.portalId })
                        .then(() => {
                            this.showToast('Success', 'Record saved successfully', 'success');
                            this.isDataChanged = false;
                            this.getListingFields();
                        })
                        .catch(error => {
                            this.isSpinner = false;
                            errorDebugger('PortalMappingLandingPage', 'handleSave', error, 'warn', 'Error occurred while saving custom metadata records');
                            this.showToast('Error', 'Failed to save record', 'error');
                        });
                } else {
                    this.isSpinner = false;
                }
            } else {
                this.isSpinner = false;
            }
        } catch (error) {
            this.isSpinner = false;
            errorDebugger('PortalMappingLandingPage', 'handleSave', error, 'warn', 'Error occurred while saving custom metadata records');
        }
    }

    /**
    * Method Name: showToast
    * @description: Used to show toast message.
    * @param: title - title of toast message.
    * @param: mesaage - message to show in toast message.
    * @param: variant- type of toast message.
    * Created Date: 04/06/2024
    * Last Updated Date: 23/12/2024
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
            errorDebugger('PortalMappingLandingPage', 'showToast', error, 'warn', 'Error occurred while showing toast message');
        }
    }

    /**
    * Method Name: handleComboboxChange
    * @description: Used to update the combobox list of each mapping.
    * Created Date: 04/06/2024
    * Created By: Karan Singh
    */
    handleComboboxChange(event) {
        try {
            const selectedIndex = event.currentTarget.dataset.index;
            const selectedValue = event.detail.value;
            const dataType = event.currentTarget.dataset.datatype;
            this.isDataChanged = true;

            if (selectedValue == '') {
                let previousValue;
                this.finalList = this.finalList.map((pair, index) => {
                    if (index === parseInt(selectedIndex, 10)) {
                        previousValue = pair.listingFieldAPIName;
                        return { ...pair, listingFieldAPIName: selectedValue };
                    }
                    return pair;
                });

                if (previousValue != '') {
                    this.finalList.forEach((pair, index) => {
                        if (index !== parseInt(selectedIndex, 10)) {
                            const customOptions = [...pair.listingFields, { label: this.getListingLabel(previousValue), value: previousValue }];
                            pair.listingFields = customOptions;
                        }
                    });
                }

            } else {
                let previousValue;
                this.finalList = this.finalList.map((pair, index) => {
                    if (index === parseInt(selectedIndex, 10)) {
                        previousValue = pair.listingFieldAPIName;
                        return { ...pair, listingFieldAPIName: selectedValue };
                    }
                    return pair;
                });
                this.finalList.forEach((pair, index) => {
                    if (index !== parseInt(selectedIndex, 10) && pair.dataType === dataType) {
                        var customOptions = pair.listingFields.filter(option => option.value !== selectedValue);
                        if (previousValue != '') {
                            customOptions = customOptions.concat({ label: this.getListingLabel(previousValue), value: previousValue });
                        }
                        pair.listingFields = customOptions;
                    }
                });
            }
        } catch (error) {
            errorDebugger('PortalMappingLandingPage', 'handleComboboxChange', error, 'warn', 'Error occurred while updating the combobox list of each mapping');
        }
        this.saveBtnDisable = false;
    }

    /**
    * Method Name: revertTheChanges
    * @description: Used to revert back to the previous changes.
    * Created Date: 04/06/2024
    * Last Updated Date: 17/02/2026
    * Created By: Karan Singh
    * Last Updated By: Karan Singh
    */
    revertTheChanges() {
        try {
            if (this.isDataChanged) {
                this.finalList = JSON.parse(JSON.stringify(this.originalMappingData));
                this.isDataChanged = false;
                this.showToast('Success', 'Changes reverted successfully', 'success');
            }
        } catch (error) {
            errorDebugger('PortalMappingLandingPage', 'revertTheChanges', error, 'warn', 'Error occurred while reverting back to the previous changes');
        }
    }

    /**
    * Method Name: currentPortalAction
    * @description: Used to change the active status and deleting the portal record by making apex callout.
    * Created Date: 04/06/2024
    * Created By: Karan Singh
    */
    currentPortalAction(event) {
        try {
            this.isSpinner = true;
            var btnName = event.target.dataset.name;
            portalAction({ portalId: this.portalId, actionName: btnName })
                .then(result => {
                    this.isSpinner = false;
                    if (result == 'deactivated') {
                        this.showToast('Success', 'The portal has been successfully deactivated.', 'success');
                        this.portalStatusToAssign = 'false';
                    } else if (result == 'activated') {
                        this.showToast('Success', 'The portal has been successfully activated.', 'success');
                        this.portalStatusToAssign = 'true';
                    } else if (result == 'deleted') {
                        this.showToast('Success', 'The portal has been successfully deleted.', 'success');
                        let componentDef = {
                            componentDef: "MVEX:portalMappingComponent",
                        };
                        let encodedComponentDef = btoa(JSON.stringify(componentDef));
                        this[NavigationMixin.Navigate]({
                            type: 'standard__webPage',
                            attributes: {
                                url: '/one/one.app#' + encodedComponentDef
                            }
                        });
                    }
                })
                .catch(error => {
                    this.isSpinner = false;
                    errorDebugger('PortalMappingLandingPage', 'currentPortalAction', error, 'warn', 'Error occurred while changing the active status and deleting the portal record by making apex callout');
                    this.showToast('Error', 'Failed to save record', 'error');
                });
        } catch (error) {
            this.isSpinner = false;
            errorDebugger('PortalMappingLandingPage', 'currentPortalAction', error, 'warn', 'Error occurred while changing the active status and deleting the portal record by making apex callout');
        }
    }

    /**
    * Method Name: handleEdit
    * @description: Used to open the new popup modal.
    * Created Date: 04/06/2024
    * Last Updated Date: 23/12/2024
    * Created By: Karan Singh
    * Last Updated By: Karan Singh
    */
    handleEdit() {
        try {
            this.showModal = true;
        } catch (error) {
            errorDebugger('PortalMappingLandingPage', 'handleEdit', error, 'warn', 'Error occurred while opening the new popup modal');
        }
    }

    /**
    * Method Name: handleHidePopup
    * @description: Used to close the new popup modal.
    * Created Date: 04/06/2024
    * Last Updated Date: 23/12/2024
    * Created By: Karan Singh
    * Last Updated By: Karan Singh
    */
    handleHidePopup() {
        try {
            this.showModal = false;
        } catch (error) {
            errorDebugger('PortalMappingLandingPage', 'handleHidePopup', error, 'warn', 'Error occurred while closing the new popup modal');
        }
    }

    /**
    * Method Name: handleHideAndRefreshPage
    * @description: Used to close the new popup modal and refresh the page.
    * Created Date: 04/06/2024
    * Last Updated Date: 23/12/2024
    * Created By: Karan Singh
    * Last Updated By: Karan Singh
    */
    handleHideAndRefreshPage(event) {
        try {
            const newPortalName = event.detail;
            this.showModal = false;
            this.portalNameToShow = newPortalName;
            this.getListingFields();
        } catch (error) {
            errorDebugger('PortalMappingLandingPage', 'handleHideAndRefreshPage', error, 'warn', 'Error occurred while closing the new popup modal and refreshing the page');
        }
    }

    /**
    * Method Name: viewListOfPortals
    * @description: Used to view the list of portals.
    * Created Date: 04/06/2024
    * Last Updated Date: 23/12/2024
    * Created By: Karan Singh
    * Last Updated By: Karan Singh
    */
    viewListOfPortals() {
        try {
            this.showListingPopup = true;
        } catch (error) {
            errorDebugger('PortalMappingLandingPage', 'viewListOfPortals', error, 'warn', 'Error occurred while viewing the list of portals');
        }
    }

    /**
    * Method Name: handleCloseListingViewPopup
    * @description: Used to close the new popup modal.
    * Created Date: 04/06/2024
    * Last Updated Date: 23/12/2024
    * Created By: Karan Singh
    * Last Updated By: Karan Singh
    */
    handleCloseListingViewPopup() {
        try {
            this.showListingPopup = false;
        } catch (error) {
            errorDebugger('PortalMappingLandingPage', 'handleCloseListingViewPopup', error, 'warn', 'Error occurred while closing the new popup modal');
        }
    }
}