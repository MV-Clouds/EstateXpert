import { LightningElement, api, wire, track } from 'lwc';
import fetchRecordTypes from '@salesforce/apex/FieldSetController.fetchRecordTypes';
import fetchListings from '@salesforce/apex/FieldSetController.fetchListings';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import Image from '@salesforce/resourceUrl/NewListingImages';
import { loadStyle } from 'lightning/platformResourceLoader';
import customcss from '@salesforce/resourceUrl/newListingCss';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
import { errorDebugger } from 'c/globalProperties';
import getListingFieldsByRecordType
    from '@salesforce/apex/FieldSetController.getListingFieldsByRecordType';

export default class ListingWizardCmp extends NavigationMixin(LightningElement) {
    @api objectName = 'MVEX__Listing__c';
    @api recordId;
    @track fields;
    @track mylist = [];
    @track headerImage = Image;
    @api message;
    @track a_Record_URL
    @track name;
    @track isLoading = true;
    @track isLoading2 = false;
    @track propertyId;
    @track propertyMediaUrls = [];
    @track firstCheck = true;
    @track backParam = null;
    @track recordTypes = [];
    debounceTimeout;

    @wire(CurrentPageReference)
    currentPageReference;

    get foundDupli() {
        if (this.mylist.length < 1) {
            return false;
        } else {
            return true;
        }
    }

    connectedCallback() {
        Promise.all([
            loadStyle(this, customcss),
            loadStyle(this, MulishFontCss)
        ]);
        if (this.currentPageReference && this.currentPageReference.state) {
            this.backParam = this.currentPageReference.state.c__customParam;
        }
        this.loadRecordTypes();
        this.a_Record_URL = window?.globalThis?.location?.origin;
    }

    loadRecordTypes() {
    fetchRecordTypes({ sObjectApiName: this.objectName })
        .then(result => {
            this.recordTypes = result.map(rt => ({
                label: rt.DeveloperName,
                value: rt.Id
            }));

            // ✅ Default to Sale
            const saleRT = result.find(rt => rt.DeveloperName === 'Sale');

            if (saleRT) {
                this.recordTypeId = saleRT.Id;
                this.loadFieldsByRecordType();
            }
        })
        .catch(error => {
            errorDebugger(
                'ListingWizardCmp',
                'loadRecordTypes',
                error,
                'warn',
                'Error in loadRecordTypes'
            );
        });
}

    handleRecordTypeChange(event) {
        this.recordTypeId = event.detail.value;
        this.mylist = [];
        this.loadFieldsByRecordType();
    }

    loadFieldsByRecordType() {
        if (!this.recordTypeId) {
            return;
        }

        this.isLoading = true;

        getListingFieldsByRecordType({ recordTypeId: this.recordTypeId })
            .then(result => {
                if (result) {
                    console.log('loadFieldsByRecordType', result);

                    // normalize for UI
                    this.fields = result.map(field => ({
                        ...field,
                        value: null
                    }));
                    console.log('loadFieldsByRecordType', this.fields);

                }
                this.isLoading = false;
            })
            .catch(error => {
                errorDebugger(
                    'ListingWizardCmp',
                    'loadFieldsByRecordType',
                    error,
                    'warn',
                    'Error loading fields by record type'
                );
                this.isLoading = false;
            });
    }


    /**
    * Method Name: handleButtonClick
    * @description: Handle button click.
    * Date: 15/09/2024
    * Created By: Vyom Soni
    */
    handleButtonClick() {
        const inputFields = this.template.querySelectorAll('lightning-input-field');
        let fieldsData = {};

        inputFields.forEach(field => {
            fieldsData[field.fieldName] = field.value;
        });

        fieldsData['MVEX__Property__c'] = this.propertyId;
        fieldsData['RecordTypeId'] = this.recordTypeId;

        if (this.validateFields()) {
            this.template.querySelector('lightning-record-edit-form').submit(fieldsData);
        }
    }

    /**
    * Method Name: clearForm
    * @description: Clear form.
    * Date: 15/09/2024
    * Created By: Vyom Soni
    */
    clearForm() {
        if (this.backParam == 'ListingManager') {
            let componentDef = {
                componentDef: "MVEX:listingManager",
            };

            let encodedComponentDef = btoa(JSON.stringify(componentDef));
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: '/one/one.app#' + encodedComponentDef
                }
            });
        } else {
            this[NavigationMixin.Navigate]({
                type: 'standard__objectPage',
                attributes: {
                    objectApiName: 'MVEX__Listing__c',
                    actionName: 'home'
                }
            });
        }
    }

    /**
    * Method Name: validateFields
    * @description: Validate fields.
    * Date: 15/09/2024
    * Created By: Vyom Soni
    */
    validateFields() {
        const inputFields = [...this.template.querySelectorAll("lightning-input-field")];
        const comboboxes = [...this.template.querySelectorAll("lightning-combobox")];

        const inputFieldsValid = inputFields.reduce((validSoFar, field) => {
            return (validSoFar && field.reportValidity());
        }, true);

        const comboboxesValid = comboboxes.reduce((validSoFar, combobox) => {
            return (validSoFar && combobox.reportValidity());
        }, true);

        return inputFieldsValid && comboboxesValid;
    }

    /**
    * Method Name: handleSuccess
    * @description: Handle success.
    * Date: 15/09/2024
    * Created By: Vyom Soni
    */
    handleSuccess(event) {
        this.showToast('Record Save', 'Record Saved Successfully', 'success');
        const recordId = event.detail.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                actionName: 'view'
            }
        });
    }

    /**
    * Method Name: handleError
    * @description: Handle error.
    * Date: 15/09/2024
    * Created By: Vyom Soni
    */
    handleError(event) {
        event.preventDefault();
        let msg = event.detail.detail;
        this.showToast('An error occurred while saving the record.', msg, 'error');
    }

    /**
    * Method Name: handleFieldChange
    * @description: Handle field change.
    * Date: 15/09/2024
    * Created By: Vyom Soni
    */
    handleFieldChange(event) {
        const fieldName = event.target.fieldName;
        const fieldValue = event.target.value;

        try {
            if (fieldName === 'Name') {
                this.name = fieldValue;

                //  Clear previous debounce
                window.clearTimeout(this.debounceTimeout);

                if (this.name && this.name.trim() !== '') {
                    // ✅ Debounce API call
                    this.debounceTimeout = window.setTimeout(() => {
                        this.fetchList();
                    }, 500); // 300–500ms is ideal
                } else {
                    this.mylist = [];
                }
            }
        } catch (error) {
            this.showToast('Fields Change', error, 'error');
        }
    }

    /**
    * Method Name: fetchList
    * @description: Fetch list.
    * Date: 15/09/2024
    * Created By: Vyom Soni
    */
    fetchList() {
        try {
            let listObj = { 'sobjectType': 'MVEX__Property__c' };
            this.isLoading2 = true;
            if (this.name != '') {
                listObj.Name = this.name;
                fetchListings({ listin: listObj })
                    .then(result => {

                        this.mylist = [];
                        if (result != null) {
                            this.propertyMediaUrls = result.medias;
                            if (Object.keys(result.records).length > 0) {
                                this.mylist = [];
                                for (let key in result.records) {
                                    if (key.split('::')[0] != '') {
                                        const propertyData = JSON.parse(key.split('::')[3]);
                                        delete propertyData.attributes;
                                        delete propertyData.MVEX__Listings__r;
                                        this.mylist.push({
                                            value: result.records[key],
                                            key: key.split('::')[0],
                                            name: key.split('::')[1],
                                            address: key.split('::')[2],
                                            property: propertyData
                                        });
                                    }
                                }
                                this.isLoading2 = false;
                                this.mylist.forEach(listing => {
                                    const propId = listing.key;
                                    listing.media_url = this.propertyMediaUrls[propId] ? this.propertyMediaUrls[propId] : '/resource/MVEX__blankImage';
                                });
                            }
                        } else {
                            this.mylist = [];
                            this.isLoading2 = false;
                        }
                    })
                    .catch(error => {
                        errorDebugger('ListingWizardCmp', 'fetchList', error, 'warn', 'Error in fetchList');
                    });
            } else {
                this.isLoading2 = false;
                this.mylist = [];
            }

        } catch (error) {
            if (typeof window !== 'undefined') {
                this.dispatchEvent(new CustomEvent('error', {
                    detail: {
                        method: 'ListingPage, Method: fetchList()',
                        error: error.message
                    }
                }));
            }
        }
    }

    /**
    * Method Name: getPropertyById
    * @description: Get property by id.
    * Date: 15/09/2024
    * Created By: Vyom Soni
    */
    getPropertyById(propertyId) {
        const item = this.mylist.find(element => element.property && element.property.Id === propertyId);
        return item ? item.property : null;
    }

    /**
    * Method Name: getRadio
    * @description: Get radio.
    * Date: 15/09/2024
    * Created By: Vyom Soni
    */
    getRadio(event) {
        try {
            this.mylist = this.mylist.map(item => {
                return { ...item, ischecked: false };
            });
            const index = event.currentTarget.dataset.index;
            this.mylist[index].ischecked = true;
            this.firstCheck = false;
            this.propertyId = event.target.value;
            const item = this.getPropertyById(this.propertyId);

            // Clear all field values first
            this.fields = this.fields.map(field => {
                return { ...field, value: null };
            });

            // Then update with new values if item exists
            if (item) {
                this.fields = this.fields.map(field => {
                    if (item[field.APIName]) {
                        return {
                            ...field,
                            value: item[field.APIName]
                        };
                    }
                    return field;
                });
            }
        } catch (e) {
            this.showToast('Error selecting property', e.message || 'An error occurred while selecting the property.', 'error');
        }
    }

    /**
    * Method Name: firstRadio
    * @description: First radio.
    * Date: 15/09/2024
    * Created By: Vyom Soni
    */
    firstRadio() {
        this.mylist = this.mylist.map(item => {
            return { ...item, ischecked: false };
        });
        this.fields = this.fields.map(field => {
            return { ...field, value: null };
        });
        this.firstCheck = true;
    }

    /**
    * Method Name: handleAcco
    * @description: Handle accordian.
    * Date: 15/09/2024
    * Created By: Vyom Soni
    */
    handleAcco(event) {
        try {
            event.currentTarget.querySelector('.showIconclass').classList.toggle('rotateIcon');
            this.id2 = event.currentTarget.id;
            this.id2 = this.id2.split('-')[0];
            const cols = this.template.querySelectorAll('[data-id="' + this.id2 + '"]');

            cols.forEach(e => {
                e.classList.toggle('showH');
            })

        } catch (error) {
            this.showToast('Handle the listing accordian', error, 'error');
        }
    }

    /**
    * Method Name: linkOpener
    * @description: Link opener.
    * Date: 15/09/2024
    * Created By: Vyom Soni
    */
    linkOpener(event) {
        try {
            const listingId = event.target.dataset.record;

            if (listingId) {
                this[NavigationMixin.GenerateUrl]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: listingId,
                        objectApiName: 'MVEX__Property__c',
                        actionName: 'view',
                    },
                }).then((url) => {
                    window?.globalThis?.open(url, '_blank');
                });
            } else {
                this.showToast('Error', 'Invalid or missing record ID', 'error');
            }
        } catch (error) {
            errorDebugger('ListingWizardCmp', 'linkOpener', error, 'warn', 'Error in linkOpener');
            this.showToast('Error', 'Failed to open the record. Please try again.', 'error');
        }
    }

    /**
    * Method Name: linkOpenerListing
    * @description: Link opener listing.
    * Date: 15/09/2024
    * Created By: Vyom Soni
    */
    linkOpenerListing(event) {
        try {
            const listingId = event.target.dataset.record;
            if (listingId) {
                this[NavigationMixin.GenerateUrl]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: listingId,
                        objectApiName: 'MVEX__Listing__c',
                        actionName: 'view',
                    },
                }).then((url) => {
                    window?.globalThis?.open(url, '_blank');
                });
            } else {
                this.showToast('Error', 'Invalid or missing record ID', 'error');
            }
        } catch (error) {
            errorDebugger('ListingWizardCmp', 'linkOpenerListing', error, 'warn', 'Error in linkOpenerListing');
            this.showToast('Error', 'Failed to open the listing. Please try again.', 'error');
        }
    }

    /**
    * Method Name: showToast
    * @description: Show toast.
    * Date: 15/09/2024
    * Created By: Vyom Soni
    */
    showToast(title, message, variant) {
        if (typeof window !== 'undefined') {
            const toastEvent = new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            });
            this.dispatchEvent(toastEvent);
        }
    }
}