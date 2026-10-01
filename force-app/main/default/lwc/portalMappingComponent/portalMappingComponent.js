import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { loadStyle } from 'lightning/platformResourceLoader';
import { subscribe, unsubscribe } from 'lightning/empApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import FORM_FACTOR from '@salesforce/client/formFactor';

// Main Controller Methods
import getPortalRecords from '@salesforce/apex/PortalMappingController.getPortalRecords';
import portalAction from '@salesforce/apex/PortalMappingController.portalAction';

// Landing Page Methods
import getObjectFields from '@salesforce/apex/PortalMappingController.getObjectFields';
import saveChangedFields from '@salesforce/apex/PortalMappingController.saveChangedFields';
import getAllCustomFields from '@salesforce/apex/PortalMappingController.getAllCustomFields';

// Listing View Methods
import getXMLFeedListingsData from "@salesforce/apex/PortalMappingController.getXMLFeedListingsData";

// Popup Methods
import savePropertyPortalRecord from '@salesforce/apex/PortalMappingController.savePropertyPortalRecord';
import getAllEditDatas from '@salesforce/apex/PortalMappingController.getAllEditDatas';
import updatePropertyPortalRecord from '@salesforce/apex/PortalMappingController.updatePropertyPortalRecord';

// Resources
import portalMappingIcon from '@salesforce/resourceUrl/iconimg';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
import portalmappingcss from '@salesforce/resourceUrl/portalmappingcss';
import { errorDebugger } from 'c/globalProperties';

export default class PortalMappingComponent extends NavigationMixin(LightningElement) {
    // --- SHARED VARIABLES ---
    @track isSpinner = true;
    @track showMainView = true;
    @track showLandingPageView = false;
    @track isInitalRender = true;
    @track isMobileOrTablet = false;

    // --- MAIN COMPONENT VARIABLES ---
    @track portalRecordList = [];
    @track isPortalData = true;
    @track portals = [];
    @track portalMappingIcon = portalMappingIcon;
    @track subscription = {};
    @track channelName = '/event/MVEX__ResponseEvent__e';
    @track showModal = false; // New Popup
    @track propertyEditModal = false; // Setting Popup
    @track isErrorPopup = false;
    @track showListingPopup = false;
    
    @track selectedPortalId;
    @track selectedPortalName;
    @track portalIconUrl;
    @track portalGen;
    @track portalStatusToAssign;
    
    // Error popup variables
    @track jsonbody = '';
    @track errorPopupType = '';
    @track portalname = '';

    // --- LANDING PAGE VARIABLES ---
    @track originalMappingData = [];
    @track fieldWrapperList = [];
    @track finalList = [];
    @track MainListingOptions = [];
    @track isDataChanged = false;
    @track isRecordAvailable = true;
    @track isLandingButtonsDisabled = false;

    // --- NEW POPUP VARIABLES ---
    @track newPopupFields = [];
    @track pickListOptionsFields = [];
    @track sitePicklist = [];
    @track clickedPortalName = '';
    @track clickedPortalIconURL = '';

    // --- SETTING POPUP VARIABLES ---
    @track editPopupFields = [];
    @track editFieldDatas = [];
    @track changedPortalName = '';

    // --- PENDING ACTION VARIABLES (for messagePopup confirmation) ---
    pendingActionPortalId = '';
    pendingActionPortalName = '';
    pendingIsDelete = false;

    // --- LISTINGS VIEW VARIABLES ---
    @track listingsDatas = [];
    @track isDataAvailable = false;
    @track sortField = 'name';
    @track sortOrder = 'asc';

    // ==========================================
    // LIFECYCLE HOOKS
    // ==========================================
    connectedCallback() {
        if (FORM_FACTOR === 'Small' || FORM_FACTOR === 'Medium') {
            this.isMobileOrTablet = true;
        }
        this.handleSubscribe();
        this.getPortalRecord();
    }

    disconnectedCallback() {
        this.handleUnsubscribe();
    }

    renderedCallback() {
        if (this.isInitalRender) {
            Promise.all([
                loadStyle(this, MulishFontCss),
                loadStyle(this, portalmappingcss)
            ]).then(() => {
                this.isInitalRender = false;
            }).catch(error => {
                errorDebugger('PortalMappingComponent', 'renderedCallback', error, 'catch');
            });
        }
    }

    // ==========================================
    // MAIN COMPONENT LOGIC
    // ==========================================
    handleSubscribe() {
        const messageCallback = (response) => {
            console.log('New message received : ', JSON.stringify(response));
            try {
                if (response.data.payload.MVEX__Type__c === 'Zoopla Branch') {
                    if (response.data.payload.MVEX__IsSuccess__c) {
                        this.showToast('Success', response.data.payload.MVEX__Body__c, 'success');
                    } else {
                        if (response.data.payload.MVEX__Body__c) {
                            let errorBody = response.data.payload.MVEX__Body__c;
                            try {
                                JSON.parse(errorBody);
                                this.jsonbody = errorBody;
                            } catch (e) {
                                this.jsonbody = JSON.stringify([{ id: 1, message: errorBody, path: "-" }]);
                            }
                        } else {
                            this.jsonbody = JSON.stringify([{ id: 1, message: "Unknown error occurred", path: "-" }]);
                        }
                        this.portalname = "Zoopla";
                        this.errorPopupType = "Branch";
                        this.isErrorPopup = true;
                        this.isSpinner = false;
                    }
                }
            } catch (error) {
                errorDebugger('PortalMappingComponent', 'handleSubscribe', error, 'catch');
            }
        };

        subscribe(this.channelName, -1, messageCallback).then(response => {
            this.subscription = response;
        });
    }

    handleUnsubscribe() {
        unsubscribe(this.subscription, response => {});
    }

    getPortalRecord() {
        this.isSpinner = true;
        getPortalRecords().then(result => {
            if (result) {
                if (result.portalDetailsRecords) {
                    this.portals = result.portalDetailsRecords.map(item => {
                        return {
                            portalName: item.portalName,
                            logoURL: item.logoURL,
                            Id: item.portalName 
                        };
                    });
                } else {
                    this.portals = [];
                }

                if (result.portalRecords && result.portalRecords.length > 0) {
                    this.isPortalData = true;
                    this.portalRecordList = result.portalRecords.map(element => {
                        return { val: element };
                    });
                } else {
                    this.isPortalData = false;
                    this.portalRecordList = [];
                }
            }
            this.isSpinner = false;
        }).catch(error => {
            this.isSpinner = false;
            let errMsg = 'Unknown error';
            if (error && error.body && error.body.message) {
                errMsg = error.body.message;
            } else if (error && error.message) {
                errMsg = error.message;
            } else if (typeof error === 'string') {
                errMsg = error;
            } else {
                try { errMsg = JSON.stringify(error); } catch(e){}
            }
            errorDebugger('PortalMappingComponent', 'getPortalRecord', error, 'catch');
            this.showToast('Error', `An error occurred: ${errMsg}`, 'error');
        });
    }

    handleClick(event) {
        event.preventDefault();
        this.selectedPortalId = event.currentTarget.dataset.portalid;
        this.selectedPortalName = event.currentTarget.dataset.portalname;
        this.portalIconUrl = event.currentTarget.dataset.portaliconurl;
        this.portalStatusToAssign = event.currentTarget.dataset.portalstatus;
        this.portalGen = event.currentTarget.dataset.portalgen;
        
        this.showMainView = false;
        this.showLandingPageView = true;
        this.getListingFields();
    }

    handleStatusChange(event) {
        let portalId = event.currentTarget.dataset.portalId;
        let pName = event.currentTarget.dataset.portalName;
        let isChecked = event.target.checked;
        
        this.pendingActionPortalId = portalId;
        this.pendingActionPortalName = pName;
        this.pendingIsDelete = false;
        this.pendingIsStatusChecked = isChecked;

        const messagePopup = this.template.querySelector('c-message-popup');
        if (isChecked) {
            messagePopup.showMessagePopup({
                title: 'Activate Portal Status?',
                message: `Are you sure you want to activate the ${pName} portal?`,
                status: 'warning'
            });
        } else {
            messagePopup.showMessagePopup({
                title: 'Deactivate Portal Status?',
                message: `Are you sure you want to deactivate the ${pName} portal?`,
                status: 'warning'
            });
        }
    }

    handleConfirmation(event) {
        if (event.detail === true || event.detail === 'true' || event.detail.isSuccess) {
            this.isSpinner = true;
            const actionName = this.pendingIsDelete ? 'delete' : (this.pendingIsStatusChecked ? 'activate' : 'deactivate');
            const portalId = this.pendingActionPortalId;
            const portalName = this.pendingActionPortalName;
            portalAction({ portalId: portalId, actionName: actionName })
                .then(result => {
                    this.isSpinner = false;
                    if (result === 'deleted') {
                        this.showToast('Success', `${portalName} portal deleted successfully`, 'success');
                        this.getPortalRecord();
                    } else if (result === 'activated') {
                        this.showToast('Success', `${portalName} portal activated successfully`, 'success');
                        this.getPortalRecord();
                    } else if (result === 'deactivated') {
                        this.showToast('Success', `${portalName} portal deactivated successfully`, 'success');
                        this.getPortalRecord();
                    } else {
                        this.showToast('Error', result || 'An error occurred', 'error');
                    }
                })
                .catch(error => {
                    this.isSpinner = false;
                    errorDebugger('PortalMappingComponent', 'portalAction', error, 'catch');
                    this.showToast('Error', 'An error occurred while performing the portal action.', 'error');
                });
        }
        // Reset pending state
        this.pendingActionPortalId = '';
        this.pendingActionPortalName = '';
        this.pendingIsDelete = false;
        this.pendingIsStatusChecked = false;
    }

    handleDelete(event) {
        let portalId = event.currentTarget.dataset.portalId;
        let pName = event.currentTarget.dataset.portalName;
        this.pendingActionPortalId = portalId;
        this.pendingActionPortalName = pName;
        this.pendingIsDelete = true;
        const messagePopup = this.template.querySelector('c-message-popup');
        messagePopup.showMessagePopup({
            title: 'Delete Portal Mapping?',
            message: `Are you sure you want to delete ${pName} Portal Mapping?`,
            status: 'warning'
        });
    }

    handleNew(event) {
        this.clickedPortalName = event.currentTarget.dataset.portalname;
        this.clickedPortalIconURL = event.currentTarget.dataset.portaliconurl;
        this.showModal = true;
        this.setNewPopupFields();
    }

    handleEditPortal(event) {
        this.selectedPortalId = event.currentTarget.dataset.portalId;
        this.portalIconUrl = event.currentTarget.dataset.portaliconurl;
        this.portalGen = event.currentTarget.dataset.portalgen;
        this.changedPortalName = this.portalGen;
        this.propertyEditModal = true;
        this.setSettingPopupFields();
    }

    handleHidePopup() {
        this.showModal = false;
        this.propertyEditModal = false;
        this.isErrorPopup = false;
    }

    handleHideAndRefreshPage() {
        this.showModal = false;
        this.propertyEditModal = false;
        this.isErrorPopup = false;
        this.getPortalRecord();
    }

    // ==========================================
    // LANDING PAGE LOGIC
    // ==========================================
    handleBackToMain(event) {
        if(event) event.preventDefault();
        this.showLandingPageView = false;
        this.showMainView = true;
        this.getPortalRecord();
    }

    getListingFields() {
        this.isSpinner = true;
        this.originalMappingData = [];
        this.finalList = [];
        this.fieldWrapperList = [];
        this.MainListingOptions = [];
        try {
            getObjectFields({ portalName: this.portalGen })
                .then(data => {
                    if (data && data.length > 0 && data[0].portalMetadataRecords && data[0].portalMetadataRecords.length > 0) {
                        this.MainListingOptions = data[0].listingFields;
                        this.processFieldWrapperData(data);
                    } else {
                        this.isRecordAvailable = false;
                        this.isSpinner = false;
                    }
                })
                .catch(error => {
                    this.isSpinner = false;
                    errorDebugger('PortalMappingComponent', 'getListingFields', error, 'catch');
                });
        } catch (error) {
            this.isSpinner = false;
            errorDebugger('PortalMappingComponent', 'getListingFields', error, 'catch');
        }
    }

    processFieldWrapperData(fieldWrapperList) {
        try {
            fieldWrapperList.forEach(fieldWrapper => {
                const { portalMetadataRecords, blockfields, listingFields } = fieldWrapper;
    
                const blockfieldsSet = new Set(blockfields);
    
                const filteredListingFields = listingFields.filter(
                    field => !blockfieldsSet.has(field.apiName)
                );
        
                portalMetadataRecords.forEach(record => {
                    const finalFilteredFields = filteredListingFields.filter(field => {
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

                    const hasSelectedOption = additionalOptions.some(opt => opt.value === record.MVEX__Listing_Field_API_Name__c);
                    const selectedOption = (!hasSelectedOption && record.MVEX__Listing_Field_API_Name__c)
                        ? [{ label: this.getListingLabel(record.MVEX__Listing_Field_API_Name__c), value: record.MVEX__Listing_Field_API_Name__c }]
                        : [];
        
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
                            ...selectedOption,
                            ...additionalOptions
                        ]
                    };
        
                    this.finalList = [...this.finalList, finalList];
                });
            });
    
            this.originalMappingData = JSON.parse(JSON.stringify(this.finalList));
            this.isRecordAvailable = this.finalList.length > 0;
            this.isDataChanged = false;
            this.isSpinner = false;
        } catch (error) {
            errorDebugger('PortalMappingComponent', 'processFieldWrapperData', error, 'warn');
        }
    }

    getListingLabel(listingFieldValue) {
        try {
            const listingOption = this.MainListingOptions.find(option => option.apiName === listingFieldValue);
            return listingOption ? listingOption.label : '';
        } catch (error) {
            errorDebugger('PortalMappingComponent', 'getListingLabel', error, 'warn');
            return '';
        }
    }

    handleComboboxChange(event) {
        try {
            this.isSpinner = true;
            this.isDataChanged = true;
            let index = event.currentTarget.dataset.index;
            let value = event.detail.value;

            let obj = this.finalList[index];
            obj.listingFieldAPIName = value;
            this.finalList[index] = obj;
            this.isSpinner = false;
        } catch (error) {
            this.isSpinner = false;
            errorDebugger('PortalMappingComponent', 'handleComboboxChange', error, 'warn');
        }
    }

    handleLandingSave() {
        try {
            this.isSpinner = true;
            if (this.isDataChanged) {
                let isValid = true;
                let errorMessage = 'Please fill all required fields:';

                this.finalList.forEach(item => {
                    if (item.isRequired && (!item.listingFieldAPIName || item.listingFieldAPIName === 'None' || item.listingFieldAPIName === '')) {
                        isValid = false;
                        errorMessage += ` ${item.portalLabel},`;
                    }
                });

                if (!isValid) {
                    errorMessage = errorMessage.replace(/,$/, '.');
                    this.showToast('Error', errorMessage, 'error');
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
                    if (record.listingFieldAPIName && record.listingFieldAPIName !== 'None') {
                        jsonList[record.listingFieldAPIName] = record.portalLabel;
                    }
                });
    
                if (changedFields.length > 0) {
                    saveChangedFields({ changedFields: changedFields, jsonList: JSON.stringify(jsonList), portalId: this.selectedPortalId })
                        .then(result => {
                            if (result === 'Success') {
                                this.showToast('Success', 'Fields Mapping Saved Successfully', 'success');
                                this.isDataChanged = false;
                                this.getListingFields();
                            } else {
                                this.showToast('Error', result || 'Something went wrong', 'error');
                            }
                            this.isSpinner = false;
                        })
                        .catch(error => {
                            this.isSpinner = false;
                            errorDebugger('PortalMappingComponent', 'saveChangedFields', error, 'catch');
                            this.showToast('Error', 'An error occurred while saving the fields mapping.', 'error');
                        });
                } else {
                    this.isSpinner = false;
                    this.showToast('Warning', 'No actual changes were made.', 'warning');
                }
            } else {
                this.isSpinner = false;
                this.showToast('Warning', 'No changes to save.', 'warning');
            }
        } catch (error) {
            this.isSpinner = false;
            errorDebugger('PortalMappingComponent', 'handleLandingSave', error, 'catch');
        }
    }

    revertTheChanges() {
        if (this.isDataChanged) {
            this.isSpinner = true;
            this.fieldWrapperList = JSON.parse(JSON.stringify(this.originalMappingData));
            let mapData = [];

            this.fieldWrapperList.forEach(item => {
                let finalDataMap = {};
                finalDataMap.portalFieldAPIName = item.PortalFieldAPIName;
                finalDataMap.portalLabel = item.PortalLabel;
                finalDataMap.listingFieldAPIName = item.ListingFieldAPIName || 'None';
                finalDataMap.dataType = item.DataType;
                finalDataMap.isRequired = item.IsRequired;
                finalDataMap.description = item.Description;
                finalDataMap.example = item.Example;
                finalDataMap.listingFields = this.MainListingOptions;

                mapData.push(finalDataMap);
            });
            this.finalList = mapData;
            this.isDataChanged = false;
            this.isSpinner = false;
        } else {
            this.showToast('Warning', 'No changes to revert.', 'warning');
        }
    }

    viewListOfPortals() {
        this.showListingPopup = true;
        this.getListingsData();
    }

    // ==========================================
    // NEW POPUP LOGIC
    // ==========================================
    setNewPopupFields() {
        this.isSpinner = true;
        this.newPopupFields = [];
        this.pickListOptionsFields = [];
        this.sitePicklist = [];
        getAllCustomFields()
            .then(result => {
                if (result) {
                    this.pickListOptionsFields = result.customFields.sort((a, b) => a.label.localeCompare(b.label));
                    this.sitePicklist = result.sitesDetails;
                }
                this.initializeNewPopupFields();
            })
            .catch(error => {
                this.isSpinner = false;
                errorDebugger('PortalMappingComponent', 'getAllCustomFields (New Popup)', error, 'catch');
            });
    }

    initializeNewPopupFields() {
        try {
            const commonFields = [
                { id: 1, fieldName: 'Selected Portal', fieldAPIName: 'portal_key', datatype: 'none', value: this.clickedPortalName, isRequired: false, placeHolder: this.clickedPortalName, helpText: '', isFirst: true, isPicklist: false },
                { id: 2, fieldName: 'Title', fieldAPIName: 'name', datatype: 'text', value: '', isRequired: true, placeHolder: this.clickedPortalName, helpText: 'Define a characteristic title for the portal.', isFirst: false, isPicklist: false },
            ];
    
            if (this.clickedPortalName === 'Zoopla') {
                this.newPopupFields = [
                    ...commonFields,
                    { id: 4, fieldName: 'Certificate Name', fieldAPIName: 'certificate', datatype: 'text', value: '', isRequired: true, placeHolder: 'zoopla_certificate', helpText: 'Name of the certificate uploaded in Salesforce.', isFirst: false, isPicklist: false },
                    { id: 5, fieldName: 'Branch Reference', fieldAPIName: 'branch_reference', datatype: 'text', value: '', isRequired: true, placeHolder: '"1234";"kd-789d"', helpText: 'Your unique identifier for the branch.', isFirst: false, isPicklist: false },
                    { id: 6, fieldName: 'Branch Name', fieldAPIName: 'branch_name', datatype: 'text', value: '', isRequired: true, placeHolder: '"Estate Agent Ltd - Shepherd Bush"', helpText: 'The name of the branch. This is usually the name of the company and may also include some location information in order to differentiate it from the other branches of the company.', isFirst: false, isPicklist: false },
                    { id: 7, fieldName: 'Street Name', fieldAPIName: 'street_name', datatype: 'text', value: '', isRequired: false, placeHolder: '"Barker Road";"Chestnut Street"', helpText: 'The name of the road on which the branch is principally adjacent.', isFirst: false, isPicklist: false },
                    { id: 8, fieldName: 'Town or City', fieldAPIName: 'town_or_city', datatype: 'text', value: '', isRequired: false, placeHolder: '"Birmingham";"San Francisco"', helpText: 'The nearest large urban area to the branch.', isFirst: false, isPicklist: false },
                    { id: 9, fieldName: 'Postal Code', fieldAPIName: 'postal_code', datatype: 'text', value: '', isRequired: false, placeHolder: '"B19 4JY";"94112"', helpText: 'The postal area code issued by the primary postal service in the country. For example, for the UK, this would be Royal Mails postcode; for the US, the United States Postal Services ZIP code.', isFirst: false, isPicklist: false },
                    { id: 10, fieldName: 'Country Code', fieldAPIName: 'country_code', datatype: 'text', value: '', isRequired: false, placeHolder: '"GB";"US"', helpText: 'The ISO 3166-2 (preferred) or ISO 3166-1 alpha-2 country code.', isFirst: false, isPicklist: false },
                    { id: 11, fieldName: 'Locality', fieldAPIName: 'locality', datatype: 'text', value: '', isRequired: false, placeHolder: '"Sutton Coldfield";"North Beach"', helpText: 'The familiar name of the area as it is referred to by local residents. This is usually a traditional, historic name and may refer to an aspect of the area which has ceased to exist.', isFirst: false, isPicklist: false },
                    { id: 12, fieldName: 'County', fieldAPIName: 'county', datatype: 'text', value: '', isRequired: false, placeHolder: '"West Midlands";"California"', helpText: 'The largest territorial area division within the country which the property resides in. (Synonymous with e.g.: province; principality.)', isFirst: false, isPicklist: false },
                    { id: 13, fieldName: 'Latitude', fieldAPIName: 'latitude', datatype: 'number', value: '', isRequired: false, placeHolder: '-90.0000000;54.123456;90.000000', helpText: 'The latitude, measured in degrees, of the branch.', isFirst: false, isPicklist: false },
                    { id: 14, fieldName: 'Longitude', fieldAPIName: 'longitude', datatype: 'number', value: '', isRequired: false, placeHolder: '-90.0000000;54.123456;90.000000', helpText: 'The longitude, measured in degrees, of the branch.', isFirst: false, isPicklist: false },
                    { id: 15, fieldName: 'Address Key', fieldAPIName: 'address_key', datatype: 'text', value: '', isRequired: false, placeHolder: '"02341509', helpText: 'The 8-digit Postcode Address File (PAF) Address Key.', isFirst: false, isPicklist: false },
                    { id: 16, fieldName: 'Organisation Key', fieldAPIName: 'organisation_key', datatype: 'text', value: '', isRequired: false, placeHolder: '"0000000";"0001150"', helpText: 'The 8-digit Postcode Address File (PAF) Organisation Key.', isFirst: false, isPicklist: false },
                    { id: 17, fieldName: 'Postcode Type', fieldAPIName: 'postcode_type', datatype: 'text', value: '', isRequired: false, placeHolder: '"L";"S"', helpText: 'The Postcode Address File (PAF) Postcode Type.', isFirst: false, isPicklist: false },
                    { id: 18, fieldName: 'PAF UDPRN', fieldAPIName: 'paf_udprn', datatype: 'text', value: '', isRequired: false, placeHolder: '"00001234"', helpText: 'Royal Mails Unique Delivery Point Reference Number (UDPRN).', isFirst: false, isPicklist: false },
                    { id: 19, fieldName: 'Telephone', fieldAPIName: 'telephone', datatype: 'text', value: '', isRequired: false, placeHolder: '"020232424433";"+1 246-123-4562"', helpText: 'Telephone number.', isFirst: false, isPicklist: false },
                    { id: 20, fieldName: 'Email', fieldAPIName: 'email', datatype: 'email', value: '', isRequired: false, placeHolder: '"test@rk.com"', helpText: 'Email address.', isFirst: false, isPicklist: false },
                    { id: 21, fieldName: 'Website', fieldAPIName: 'website', datatype: 'text', value: '', isRequired: false, placeHolder: '"http://www.estateagent.co.uk"', helpText: 'The URI-encoded URL for the branchs website, or that of its parent company if it doesnt have one of its own.', isFirst: false, isPicklist: false },
                    { id: 22, fieldName: 'Test Portal', fieldAPIName: 'is_test_portal', datatype: 'text', value: '', isRequired: true, placeHolder: 'true/false', helpText: 'If set to true feeds will be exported to the Zoopla sandbox.', isFirst: false, isPicklist: true, picklistOptions: [{ label: 'True', value: 'true' }, { label: 'False', value: 'false' }] },
                    { id: 23, fieldName: 'Feed Selector Field', fieldAPIName: 'differentiator_values', datatype: 'picklist', value: '', isRequired: false, placeHolder: 'Select a field', helpText: 'Define a field that separates different portal feeds.', isFirst: false, picklistOptions: this.pickListOptionsFields , isPicklist: true},
                    { id: 24, fieldName: 'Sync Branch Details with Zoopla', fieldAPIName: 'sync_branch_with_zoopla', datatype: 'checkbox', value: false, isRequired: false, placeHolder: '', helpText: 'When enabled, branch details will be sent directly to Zoopla. Keep this disabled to only save the configuration in Salesforce.', isFirst: false, isPicklist: false, isCheckbox: true }
                ];
            } else if (this.clickedPortalName === 'Rightmove' || this.clickedPortalName === 'Rightmove Overseas') {
                this.newPopupFields = [
                    ...commonFields,
                    { id: 4, fieldName: 'Certificate Name', fieldAPIName: 'certificate', datatype: 'text', value: '', isRequired: true, placeHolder: 'rightmove_certificate', helpText: 'Name of the certificate uploaded in Salesforce.', isFirst: false, isPicklist: false },
                    { id: 5, fieldName: 'Network ID', fieldAPIName: 'network.network_id', datatype: 'number', value: '', isRequired: true, placeHolder: '12345', helpText: 'Network Id provided by Rightmove.', isFirst: false, isPicklist: false },
                    { id: 6, fieldName: 'Branch ID', fieldAPIName: 'branch.branch_id', datatype: 'number', value: '', isRequired: true, placeHolder: '67890', helpText: 'Unique Rightmove reference for this branch.', isFirst: false, isPicklist: false },
                    { id: 7, fieldName: 'Use Sandbox', fieldAPIName: 'is_test_portal', datatype: 'text', value: '', isRequired: true, placeHolder: 'true/false', helpText: 'If set to true feeds will be exported to the Rightmove sandbox.', isFirst: false, isPicklist: true, picklistOptions: [{ label: 'True', value: 'true' }, { label: 'False', value: 'false' }] },
                ];
            } else if (this.clickedPortalName === 'Propertyfinder') {
                this.newPopupFields = [
                    ...commonFields,
                    { id: 4, fieldName: 'API Key', fieldAPIName: 'apiKey', datatype: 'text', value: '', isRequired: true, placeHolder: '<API_KEY>', helpText: 'Enter the API key obtained from the PF Expert application.', isFirst: false, isPicklist: false },
                    { id: 5, fieldName: 'API Secret', fieldAPIName: 'apiSecret', datatype: 'text', value: '', isRequired: true, placeHolder: '<API_SECRET>', helpText: 'Enter the API secret obtained from the PF Expert application.', isFirst: false, isPicklist: false },
                ];
            } else {
                this.newPopupFields = [
                    ...commonFields,
                    { id: 3, fieldName: 'Select Site', fieldAPIName: 'xml_site', datatype: 'picklist', value: '', isRequired: true, placeHolder: 'Select a Force.com Site', helpText: 'Select a force.com site and also provide the Apex Class, VF Page, Object and Fields permission to the selected site guest user.', isFirst: false, picklistOptions: this.sitePicklist , isPicklist: true}
                ];
            }
            this.isSpinner = false;
        } catch (error) {
            errorDebugger('PortalMappingComponent', 'initializeNewPopupFields', error, 'warn');
            this.isSpinner = false;
        }
    }

    handleNewPopupChange(event) {
        let value = event.detail.value;
        let index = event.currentTarget.dataset.index;
        let obj = this.newPopupFields[index];
        obj.value = value;
        this.newPopupFields[index] = obj;
    }

    handleNewPopupCheckboxChange(event) {
        let fieldName = event.target.dataset.field;
        let value = event.target.checked;
        let index = this.newPopupFields.findIndex(x => x.fieldName === fieldName);
        if (index !== -1) {
            let obj = this.newPopupFields[index];
            obj.value = value;
            this.newPopupFields[index] = obj;
        }
    }

    getNewPopupFieldValue(event) {
        let value = event.target.value;
        let fieldName = event.target.dataset.field;
        let index = this.newPopupFields.findIndex(x => x.fieldName === fieldName);
        if (index !== -1) {
            let obj = this.newPopupFields[index];
            obj.value = value;
            this.newPopupFields[index] = obj;
        }
    }

    validateNewPopupFields() {
        let isValid = true;
        this.newPopupFields.forEach(field => {
            if (field.isRequired && (!field.value || field.value.trim() === '')) {
                isValid = false;
            }
        });
        return isValid;
    }

    saveNewPortalRecord() {
        if (!this.validateNewPopupFields()) {
            this.showToast('Error', 'Please fill all the required fields.', 'error');
            return;
        }
        
        this.isSpinner = true;
        let mapData = {};
        this.newPopupFields.forEach(field => {
            if(field.isCheckbox) {
                mapData[field.fieldAPIName] = field.value === true ? 'true' : 'false';
            } else {
                mapData[field.fieldAPIName] = field.value ? field.value : '';
            }
        });
        // Always include the portal name and icon URL for Apex
        mapData['portalname'] = this.clickedPortalName;
        mapData['getPortalIconUrl'] = this.clickedPortalIconURL;

        savePropertyPortalRecord({ portalWrapper: JSON.stringify(mapData), portalName: this.clickedPortalName })
            .then(result => {
                if (result === 'success' || result === 'Success') {
                    this.showToast('Success', 'Portal Created Successfully', 'success');
                    this.handleHideAndRefreshPage();
                } else {
                    this.showToast('Error', result || 'An error occurred while creating the portal.', 'error');
                }
                this.isSpinner = false;
            })
            .catch(error => {
                this.isSpinner = false;
                errorDebugger('PortalMappingComponent', 'savePropertyPortalRecord', error, 'catch');
                this.showToast('Error', 'An error occurred while saving the portal record.', 'error');
            });
    }

    // ==========================================
    // SETTING POPUP LOGIC
    // ==========================================
    setSettingPopupFields() {
        this.isSpinner = true;
        this.editPopupFields = [];
        this.pickListOptionsFields = [];
        this.sitePicklist = [];
        
        getAllEditDatas({ portalId: this.selectedPortalId })
            .then(result => {
                if (result) {
                    this.pickListOptionsFields = result.customFields;
                    this.sitePicklist = result.sitesDetails;
                    this.editFieldDatas = result.fieldsValue;
                    this.initializeSettingPopupFields();
                } else {
                    this.isSpinner = false;
                }
            })
            .catch(error => {
                this.isSpinner = false;
                errorDebugger('PortalMappingComponent', 'getAllEditDatas', error, 'catch');
            });
    }

    initializeSettingPopupFields() {
        try {
            const commonFields = [
                { id: 1, fieldName: 'Selected Portal', fieldAPIName: 'portal_key', datatype: 'none', value: this.changedPortalName, isRequired: false, placeHolder: this.changedPortalName, helpText: '', isFirst: true, isPicklist: false },
                { id: 2, fieldName: 'Title', fieldAPIName: 'name', datatype: 'text', value: '', isRequired: true, placeHolder: this.changedPortalName, helpText: 'Define a characteristic title for the portal.', isFirst: false, isPicklist: false },
            ];
    
            if (this.changedPortalName === 'Zoopla') {
                this.editPopupFields = [
                    ...commonFields,
                    { id: 4, fieldName: 'Certificate Name', fieldAPIName: 'certificate', datatype: 'text', value: '', isRequired: true, placeHolder: 'zoopla_certificate', helpText: 'Name of the certificate uploaded in Salesforce.', isFirst: false, isPicklist: false },
                    { id: 5, fieldName: 'Branch Reference', fieldAPIName: 'branch_reference', datatype: 'text', value: '', isRequired: true, placeHolder: '"1234";"kd-789d"', helpText: 'Your unique identifier for the branch.', isFirst: false, isPicklist: false },
                    { id: 6, fieldName: 'Branch Name', fieldAPIName: 'branch_name', datatype: 'text', value: '', isRequired: true, placeHolder: '"Estate Agent Ltd - Shepherd Bush"', helpText: 'The name of the branch. This is usually the name of the company and may also include some location information in order to differentiate it from the other branches of the company.', isFirst: false, isPicklist: false },
                    { id: 7, fieldName: 'Street Name', fieldAPIName: 'street_name', datatype: 'text', value: '', isRequired: false, placeHolder: '"Barker Road";"Chestnut Street"', helpText: 'The name of the road on which the branch is principally adjacent.', isFirst: false, isPicklist: false },
                    { id: 8, fieldName: 'Town or City', fieldAPIName: 'town_or_city', datatype: 'text', value: '', isRequired: false, placeHolder: '"Birmingham";"San Francisco"', helpText: 'The nearest large urban area to the branch.', isFirst: false, isPicklist: false },
                    { id: 9, fieldName: 'Postal Code', fieldAPIName: 'postal_code', datatype: 'text', value: '', isRequired: false, placeHolder: '"B19 4JY";"94112"', helpText: 'The postal area code issued by the primary postal service in the country. For example, for the UK, this would be Royal Mails postcode; for the US, the United States Postal Services ZIP code.', isFirst: false, isPicklist: false },
                    { id: 10, fieldName: 'Country Code', fieldAPIName: 'country_code', datatype: 'text', value: '', isRequired: false, placeHolder: '"GB";"US"', helpText: 'The ISO 3166-2 (preferred) or ISO 3166-1 alpha-2 country code.', isFirst: false, isPicklist: false },
                    { id: 11, fieldName: 'Locality', fieldAPIName: 'locality', datatype: 'text', value: '', isRequired: false, placeHolder: '"Sutton Coldfield";"North Beach"', helpText: 'The familiar name of the area as it is referred to by local residents. This is usually a traditional, historic name and may refer to an aspect of the area which has ceased to exist.', isFirst: false, isPicklist: false },
                    { id: 12, fieldName: 'County', fieldAPIName: 'county', datatype: 'text', value: '', isRequired: false, placeHolder: '"West Midlands";"California"', helpText: 'The largest territorial area division within the country which the property resides in. (Synonymous with e.g.: province; principality.)', isFirst: false, isPicklist: false },
                    { id: 13, fieldName: 'Latitude', fieldAPIName: 'latitude', datatype: 'number', value: '', isRequired: false, placeHolder: '-90.0000000;54.123456;90.000000', helpText: 'The latitude, measured in degrees, of the branch.', isFirst: false, isPicklist: false },
                    { id: 14, fieldName: 'Longitude', fieldAPIName: 'longitude', datatype: 'number', value: '', isRequired: false, placeHolder: '-90.0000000;54.123456;90.000000', helpText: 'The longitude, measured in degrees, of the branch.', isFirst: false, isPicklist: false },
                    { id: 15, fieldName: 'Address Key', fieldAPIName: 'address_key', datatype: 'text', value: '', isRequired: false, placeHolder: '"02341509', helpText: 'The 8-digit Postcode Address File (PAF) Address Key.', isFirst: false, isPicklist: false },
                    { id: 16, fieldName: 'Organisation Key', fieldAPIName: 'organisation_key', datatype: 'text', value: '', isRequired: false, placeHolder: '"0000000";"0001150"', helpText: 'The 8-digit Postcode Address File (PAF) Organisation Key.', isFirst: false, isPicklist: false },
                    { id: 17, fieldName: 'Postcode Type', fieldAPIName: 'postcode_type', datatype: 'text', value: '', isRequired: false, placeHolder: '"L";"S"', helpText: 'The Postcode Address File (PAF) Postcode Type.', isFirst: false, isPicklist: false },
                    { id: 18, fieldName: 'PAF UDPRN', fieldAPIName: 'paf_udprn', datatype: 'text', value: '', isRequired: false, placeHolder: '"00001234"', helpText: 'Royal Mails Unique Delivery Point Reference Number (UDPRN).', isFirst: false, isPicklist: false },
                    { id: 19, fieldName: 'Telephone', fieldAPIName: 'telephone', datatype: 'text', value: '', isRequired: false, placeHolder: '"020232424433";"+1 246-123-4562"', helpText: 'Telephone number.', isFirst: false, isPicklist: false },
                    { id: 20, fieldName: 'Email', fieldAPIName: 'email', datatype: 'email', value: '', isRequired: false, placeHolder: '"test@rk.com"', helpText: 'Email address.', isFirst: false, isPicklist: false },
                    { id: 21, fieldName: 'Website', fieldAPIName: 'website', datatype: 'text', value: '', isRequired: false, placeHolder: '"http://www.estateagent.co.uk"', helpText: 'The URI-encoded URL for the branchs website, or that of its parent company if it doesnt have one of its own.', isFirst: false, isPicklist: false },
                    { id: 22, fieldName: 'Test Portal', fieldAPIName: 'is_test_portal', datatype: 'text', value: '', isRequired: true, placeHolder: 'true/false', helpText: 'If set to true feeds will be exported to the Zoopla sandbox.', isFirst: false, isPicklist: true, picklistOptions: [{ label: 'True', value: 'true' }, { label: 'False', value: 'false' }] },
                    { id: 23, fieldName: 'Feed Selector Field', fieldAPIName: 'differentiator_values', datatype: 'picklist', value: '', isRequired: false, placeHolder: 'Select a field', helpText: 'Define a field that separates different portal feeds.', isFirst: false, picklistOptions: this.pickListOptionsFields , isPicklist: true},
                    { id: 24, fieldName: 'Sync Branch Details with Zoopla', fieldAPIName: 'sync_branch_with_zoopla', datatype: 'checkbox', value: false, isRequired: false, placeHolder: '', helpText: 'When enabled, branch details will be sent directly to Zoopla. Keep this disabled to only save the configuration in Salesforce.', isFirst: false, isPicklist: false, isCheckbox: true }
                ];
            } else if (this.changedPortalName === 'Rightmove' || this.changedPortalName === 'Rightmove Overseas') {
                this.editPopupFields = [
                    ...commonFields,
                    { id: 4, fieldName: 'Certificate Name', fieldAPIName: 'certificate', datatype: 'text', value: '', isRequired: true, placeHolder: 'rightmove_certificate', helpText: 'Name of the certificate uploaded in Salesforce.', isFirst: false, isPicklist: false },
                    { id: 5, fieldName: 'Network ID', fieldAPIName: 'network.network_id', datatype: 'number', value: '', isRequired: true, placeHolder: '12345', helpText: 'Network Id provided by Rightmove.', isFirst: false, isPicklist: false },
                    { id: 6, fieldName: 'Branch ID', fieldAPIName: 'branch.branch_id', datatype: 'number', value: '', isRequired: true, placeHolder: '67890', helpText: 'Unique Rightmove reference for this branch.', isFirst: false, isPicklist: false },
                    { id: 7, fieldName: 'Use Sandbox', fieldAPIName: 'is_test_portal', datatype: 'text', value: '', isRequired: true, placeHolder: 'true/false', helpText: 'If set to true feeds will be exported to the Rightmove sandbox.', isFirst: false, isPicklist: true, picklistOptions: [{ label: 'True', value: 'true' }, { label: 'False', value: 'false' }] },
                ];
            } else if (this.changedPortalName === 'Propertyfinder') {
                this.editPopupFields = [
                    ...commonFields,
                    { id: 4, fieldName: 'API Key', fieldAPIName: 'apiKey', datatype: 'text', value: '', isRequired: true, placeHolder: '<API_KEY>', helpText: 'Enter the API key obtained from the PF Expert application.', isFirst: false, isPicklist: false },
                    { id: 5, fieldName: 'API Secret', fieldAPIName: 'apiSecret', datatype: 'text', value: '', isRequired: true, placeHolder: '<API_SECRET>', helpText: 'Enter the API secret obtained from the PF Expert application.', isFirst: false, isPicklist: false },
                ];
            } else {
                this.editPopupFields = [
                    ...commonFields,
                    { id: 3, fieldName: 'Select Site', fieldAPIName: 'xml_site', datatype: 'picklist', value: '', isRequired: true, placeHolder: 'Select a Force.com Site', helpText: 'Select a force.com site and also provide the Apex Class, VF Page, Object and Fields permission to the selected site guest user.', isFirst: false, picklistOptions: this.sitePicklist , isPicklist: true}
                ];
            }
    
            this.editPopupFields.forEach(field => {
                const fieldData = this.editFieldDatas.find(data => data.label === field.fieldAPIName);
                if (fieldData) {
                    field.value = fieldData.value;
                }
                if (field.isCheckbox) {
                    field.value = fieldData && fieldData.value === 'true' ? true : false;
                }
            });
        
            this.isSpinner = false;
        } catch (error) {
            errorDebugger('PortalMappingComponent', 'initializeSettingPopupFields', error, 'warn');
            this.isSpinner = false;
        }
    }

    handleSettingPopupChange(event) {
        let value = event.detail.value;
        let index = event.currentTarget.dataset.index;
        let obj = this.editPopupFields[index];
        obj.value = value;
        this.editPopupFields[index] = obj;
    }

    handleSettingPopupCheckboxChange(event) {
        let fieldName = event.target.dataset.field;
        let value = event.target.checked;
        let index = this.editPopupFields.findIndex(x => x.fieldName === fieldName);
        if (index !== -1) {
            let obj = this.editPopupFields[index];
            obj.value = value;
            this.editPopupFields[index] = obj;
        }
    }

    getSettingPopupFieldValue(event) {
        let value = event.target.value;
        let fieldName = event.target.dataset.field;
        let index = this.editPopupFields.findIndex(x => x.fieldName === fieldName);
        if (index !== -1) {
            let obj = this.editPopupFields[index];
            obj.value = value;
            this.editPopupFields[index] = obj;
        }
    }

    validateSettingPopupFields() {
        let isValid = true;
        this.editPopupFields.forEach(field => {
            if (field.isRequired && (!field.value || field.value.toString().trim() === '')) {
                isValid = false;
            }
        });
        return isValid;
    }

    updateExistingPortalRecord() {
        if (!this.validateSettingPopupFields()) {
            this.showToast('Error', 'Please fill all the required fields.', 'error');
            return;
        }

        this.isSpinner = true;
        let mapData = {};
        this.editPopupFields.forEach(field => {
            if(field.isCheckbox) {
                mapData[field.fieldAPIName] = field.value === true ? 'true' : 'false';
            } else {
                mapData[field.fieldAPIName] = field.value ? field.value : '';
            }
        });

        updatePropertyPortalRecord({ portalWrapper: JSON.stringify(mapData), portalName: this.changedPortalName, portalId: this.selectedPortalId })
            .then(result => {
                if (result === 'success') {
                    this.showToast('Success', 'Portal Mapping Updated Successfully', 'success');
                    this.handleHideAndRefreshPage();
                } else {
                    this.showToast('Error', result, 'error');
                }
                this.isSpinner = false;
            })
            .catch(error => {
                this.isSpinner = false;
                errorDebugger('PortalMappingComponent', 'updatePropertyPortalRecord', error, 'catch');
                this.showToast('Error', 'An error occurred while updating the portal record.', 'error');
            });
    }

    // ==========================================
    // LISTINGS VIEW LOGIC
    // ==========================================
    handleCloseListingViewPopup() {
        this.showListingPopup = false;
    }

    getListingsData() {
        this.isSpinner = true;
        getXMLFeedListingsData({ portalId: this.selectedPortalId })
            .then(result => {
                if (result.isSuccess) {
                    let parsedData = JSON.parse(result.data);
                    if (parsedData.length > 0) {
                        this.isDataAvailable = true;
                        this.listingsDatas = parsedData.map(item => {
                            return {
                                name: item.listingName,
                                listing_reference: item.listingReference,
                                listing_type: item.listingType,
                                id: item.listingId
                            };
                        });
                        // sort initially by name asc
                        this.listingsDatas.sort((a, b) => a.name.localeCompare(b.name));
                    } else {
                        this.isDataAvailable = false;
                        this.listingsDatas = [];
                    }
                } else {
                    this.isDataAvailable = false;
                    this.listingsDatas = [];
                    if(result.msg && result.msg.trim() !== ''){
                        this.showToast('Error', result.msg, 'error');
                    }
                }
                this.isSpinner = false;
            })
            .catch(error => {
                this.isSpinner = false;
                this.isDataAvailable = false;
                this.listingsDatas = [];
                errorDebugger('PortalMappingComponent', 'getXMLFeedListingsData', error, 'catch');
            });
    }

    redirectToListing(event) {
        let listingId = event.currentTarget.dataset.id;
        this[NavigationMixin.GenerateUrl]({
            type: 'standard__recordPage',
            attributes: {
                recordId: listingId,
                actionName: 'view',
            },
        }).then(url => {
            window.open(url, "_blank");
        });
    }

    sortClick(event) {
        const field = event.currentTarget.dataset.id;
        if (this.sortField === field) {
            this.sortOrder = this.sortOrder === 'asc' ? 'desc' : 'asc';
        } else {
            this.sortField = field;
            this.sortOrder = 'asc';
        }
        
        const reverse = this.sortOrder === 'asc' ? 1 : -1;
        
        let data = JSON.parse(JSON.stringify(this.listingsDatas));
        data.sort((a, b) => {
            let valA = a[field] ? a[field].toLowerCase() : '';
            let valB = b[field] ? b[field].toLowerCase() : '';
            return reverse * valA.localeCompare(valB);
        });
        
        this.listingsDatas = data;
        
        this.template.querySelectorAll('.sort-cover').forEach(element => {
            element.classList.remove('ascending', 'descending');
            let iconElement = element.querySelector('.exp-arrow-icon');
            if (iconElement) {
                iconElement.classList.remove('asc', 'desc');
            }
        });
        
        const sortedColumn = this.template.querySelector(`th[data-id="${field}"] .sort-cover`);
        if (sortedColumn) {
            sortedColumn.classList.add(this.sortOrder === 'asc' ? 'ascending' : 'descending');
            let iconElement = sortedColumn.querySelector('.exp-arrow-icon');
            if (iconElement) {
                iconElement.classList.add(this.sortOrder === 'asc' ? 'asc' : 'desc');
            }
        }
    }

    // ==========================================
    // UTILS
    // ==========================================
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(event);
    }
}