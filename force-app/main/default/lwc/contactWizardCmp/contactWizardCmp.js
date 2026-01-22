import { LightningElement, api, track, wire } from 'lwc';
import getListOfFieldsForObjects from '@salesforce/apex/FieldSetController.getListOfFieldsForObjects';
import fetchContacts from '@salesforce/apex/FieldSetController.fetchContacts';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import Image from '@salesforce/resourceUrl/NewContactImg';
import { loadStyle } from 'lightning/platformResourceLoader';
import customcss from '@salesforce/resourceUrl/newListingCss';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
import { errorDebugger } from 'c/globalProperties';

export default class ContactWizardCmp extends NavigationMixin(LightningElement){
    @api objectName = 'Contact';
    @api recordId;
    @api fieldSet = 'MVEX__New_Contact';
    @track mylist = [];
    @track fields = [];
    @track tableFields = [{"label":"Name","fieldName":"Name"},{"label":"Email","fieldName":"Email"},{"label":"Phone","fieldName":"Phone"},{"label":"LeadSource","fieldName":"LeadSource"}];
    @track processedMyList = [];
    @track headerImage = Image;
    @api message;
    @track sortField = '';
    @track sortOrder = '';
    a_Record_URL
    firstname;
    lastname;
    phone;
    email;
    leadsource;
    isLoading = true;
    isLoading2 = false;
    isHandlingFieldChange = false;
    @track backParam = null;

    @wire(CurrentPageReference)
    currentPageReference;

    get foundDupli(){
        if(this.mylist.length < 1){
            return false;
        }else{
            return true;
        }
    }

    connectedCallback() {
        loadStyle(this, MulishFontCss);
        loadStyle(this, customcss);
        if (this.currentPageReference && this.currentPageReference.state) {
            this.backParam = this.currentPageReference.state.c__customParam;
        }
        this.loadFormData();
        this.a_Record_URL = window?.globalThis?.location?.origin;
    }

    loadFormData() {
        this.isLoading = true;
        getListOfFieldsForObjects({ objectApiName: this.objectName })
            .then(result => {
                if (result != null) {
                    this.fields = result;
                    this.error = undefined;
                }  
                this.isLoading = false;
            })
            .catch(error => {
                this.isLoading = false;
                this.error = error;
                errorDebugger('ContactWizardCmp', 'loadFormData:getListOfFieldsForObjects', error, 'warn', 'Error in Fetching Fields');
            })
            .finally(() => {
                this.isLoading = false; 
            });
    }

    handleButtonClick() {
        const inputFields = this.template.querySelectorAll('lightning-input-field');
        let fieldsData = {};
        inputFields.forEach(field => {
            fieldsData[field.fieldName] = field.value;
        });
        if (this.validateFields()) {
            this.template.querySelector('lightning-record-edit-form').submit(fieldsData);
        }
    }

    clearForm() {
        if(this.backParam == 'MarketingList'){
            let componentDef = {
                componentDef: "MVEX:marketingListCmp",
            };
            
            let encodedComponentDef = btoa(JSON.stringify(componentDef));
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: '/one/one.app#' + encodedComponentDef
                }
            });
        } else{
            this[NavigationMixin.Navigate]({
                type: 'standard__objectPage',
                attributes: {
                    objectApiName: 'Contact', // Your object API name
                    actionName: 'home' // Navigating to the object home page
                }
            });
        }
    }

    validateFields() {
        return [...this.template.querySelectorAll("lightning-input-field")].reduce((validSoFar, field) => {
            return (validSoFar && field.reportValidity());
        }, true);
    }

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

    handleError(event) {
        event.preventDefault();
        let msg = event.detail.detail;
        if(msg == 'Use one of these records?'){
            msg = 'Email is used in the other records. Please use another email.'
        }

        this.showToast('An error occurred while saving the record.', msg, 'error');
    }

    handleFieldChange(event) {   
        const fieldName = event.target.fieldName;
        const fieldValue = event.target.value;
        try {
            if (fieldName === 'FirstName') {
                this.firstname = fieldValue;
            } else if (fieldName === 'LastName') {
                this.lastname = fieldValue;
            }
            if (this.firstname !== '' ||this.lastname !== '' ) {
                if (fieldName === 'FirstName' || fieldName === 'LastName') {
                    this.fetchList();
                }
            }else{
                this.mylist = [];
            }
        } catch (error) {
            this.showToast('Fields Change', error, 'error');
        } finally {
            this.isHandlingFieldChange = false;
        }
    }
    
    fetchList() {
        try {
            let listObj = { 'sobjectType': 'Contact' };
            this.isLoading2 = true;
            if (this.firstname !== '' ||this.lastname !== '') {
                listObj.FirstName = this.firstname;
                listObj.LastName = this.lastname;
                let soqlquery = 'Id,'+this.tableFields.map(field => field.fieldName).join(',');
                fetchContacts({ listin: listObj,soqlquery: soqlquery })
                    .then(result => {
                        if(result != null){
                            if (Object.keys(result).length > 0 ) {
                                this.isLoading2 = false;
                                this.mylist = result;
                                this.processMyList();
                            }
                        } else {
                            this.mylist = [];
                            this.isLoading2 = false;
                        }
                    })
                    .catch(error => {
                        errorDebugger('ContactWizardCmp', 'fetchList:fetchContacts', error, 'warn', 'Error in Fetching Contacts');
                    });
            }else{
                this.mylist = [];
                this.isLoading2 = false;
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

    processMyList(){
        try{
            this.processedMyList = this.mylist.map(listing => {
            let orderedFields = this.tableFields.map(field => {
                let fieldValue;
                fieldValue = listing[field.fieldName] || '';
                return {
                    fieldName: field.fieldName,
                    value: fieldValue
                };
            });
                return {
                    Id: listing.Id,
                    Name: listing.Name,
                    orderedFields
                };
            });
        }catch(error){
            errorDebugger('ContactWizardCmp', 'processMyList', error, 'warn', 'Error in Processing Listings');
            return null;
        }
    }

     /**
    * Method Name : sortClick
    * @description : this methods apply the sorting on the all fields
    * date: 3/06/2024
    * Created By:Vyom Soni
    */
    sortClick(event) {
        try{
            const fieldName = event.currentTarget.dataset.id;
            if (this.sortField === fieldName) {
                this.sortOrder = this.sortOrder === 'asc' ? 'desc' : 'asc';
            } else {
                this.sortField = fieldName;
                this.sortOrder = 'asc';
            }
            this.sortData();
            this.updateSortIcons();
        }catch(error){
            errorDebugger('ContactWizardCmp', 'sortClick', error, 'warn', 'Error in Sorting');
        }
    }

    /**
    * Method Name : sortData
    * @description : this methods apply the sorting on the all fields
    * date: 3/06/2024
    * Created By:Vyom Soni
    */
    sortData() {
        try{
            this.processedMyList = [...this.processedMyList].sort((a, b) => {
                let aValue, bValue;
                aValue = a.orderedFields.find(field => field.fieldName === this.sortField).value;
                bValue = b.orderedFields.find(field => field.fieldName === this.sortField).value;
                if (typeof aValue === 'string' && typeof bValue === 'string') {
                    aValue = aValue.toLowerCase();
                    bValue = bValue.toLowerCase();
                }
                let compare = 0;
                if (aValue > bValue) {
                    compare = 1;
                } else if (aValue < bValue) {
                    compare = -1;
                }
                return this.sortOrder === 'asc' ? compare : -compare;
            });
        }catch(error){
            errorDebugger('ContactWizardCmp', 'sortData', error, 'warn', 'Error in Sorting');
            return null;
        }
    }

    /**
    * Method Name : updateSortIcons
    * @description : this method update the sort icons in the wrapbutton
    * date : 3/06/2024
    * Created By:Vyom Soni
    */
    updateSortIcons() {
        try{
            const allHeaders = this.template.querySelectorAll('.arrow-down-css svg');
            allHeaders.forEach(icon => {
                icon.classList.remove('rotate-asc', 'rotate-desc');
            });
            const currentHeader = this.template.querySelector('[data-index="' + this.sortField + '"]');
            if (currentHeader) {
                currentHeader.classList.add(this.sortOrder === 'asc' ? 'rotate-asc' : 'rotate-desc');
            }
        }catch(error){
            errorDebugger('ContactWizardCmp', 'updateSortIcons', error, 'warn', 'Error in Sorting');
        }
    }

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
    
    linkOpener(event) {
        try {
            let listingId = event.target.dataset.record;
            if(listingId != ''){
                window?.globalThis?.open(this.a_Record_URL+'/lightning/r/MVEX__Property__c/' + listingId + '/view', '_blank');
            }
        } catch (error) {
            this.showToast('Error to open property', error, 'error');
        }
    }

    linkOpenerListing(event) {
        try {
            let listingId = event.target.dataset.record;
            if(listingId != ''){
                    window?.globalThis?.open(this.a_Record_URL+'/lightning/r/MVEX__Listing__c/' + listingId + '/view', '_blank');
            }
        } catch (error) {
            this.showToast('Error to open listing', error, 'error');
        }
    }

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