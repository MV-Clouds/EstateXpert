import { LightningElement, api,track } from 'lwc';
import getRecordsBySObject from '@salesforce/apex/WBTemplateController.getRecordsBySObject';

export default class CustomLookupLwc extends LightningElement {
    @api placeholder = 'search...';
    @api iconName = 'standard:account';
    @api sObjectApiName = '';

    @track allRecords = []; 
    @track lstResult = [];
    @track hasRecords = true;
    @track searchKey = ''; 
    @track selectedRecord = {};
    @api disabled = false;

    connectedCallback() {
        this.fetchAllRecords();
    }

    fetchAllRecords() {
        
        try {
            getRecordsBySObject({objectName: this.sObjectApiName})
            .then((data) => {
                if (data) {
                    this.allRecords = [{ Id: '', Name: 'None' }, ...data]; 
                    this.lstResult =  this.allRecords;
                    this.hasRecords = data.length > 0;
                }
            })
            .catch((error) => {
                console.error('Error fetching lookup data:', error);
            });
        }catch(e){
            console.error('Something wrong while fetching contact data:', e);
        }
    }

    handleKeyChange(event) {
        if (this.disabled) return;
        try {
            const searchKey = event.target.value.toLowerCase();
            this.searchKey = searchKey;
            
            this.lstResult = this.allRecords.filter((record) =>
                record.Name.toLowerCase().includes(searchKey)
            );
            this.hasRecords = this.lstResult.length > 0;
        }catch(e){
            console.error('Something went wrong!', e);
        }
    }

    
    handelSelectedRecord(event) {
        if (this.disabled) return;
        event.stopPropagation();        
        try {
            const objId = event.target.getAttribute('data-recid');
            this.selectedRecord = this.lstResult.find((data) => data.Id === objId);
            this.lookupUpdatehandler(this.selectedRecord);
            this.handelSelectRecordHelper();
        }catch(e){
            console.error('Error while selecting records.', e);
        }
    }

    toggleResult(event){
        if (this.disabled) return;
        try {
            const lookupInputContainer = this.template.querySelector('.lookupInputContainer');
            const clsList = lookupInputContainer.classList;
            const whichEvent = event.target.getAttribute('data-source');
            switch(whichEvent) {
                case 'searchInputField':
                    clsList.add('slds-is-open');
                    break;
                case 'lookupContainer':
                    clsList.remove('slds-is-open');    
                break;                    
            }
        }catch(e){
            console.error('Something went wrong.', e);
        }  
    }

    handleRemove() {
        if (this.disabled) return;
        try {
            this.searchKey = '';
            this.selectedRecord = {};
            this.lstResult = this.allRecords; 
            this.hasRecords = this.allRecords.length > 0;
            this.lookupUpdatehandler(undefined);
    
            const searchBoxWrapper = this.template.querySelector('.searchBoxWrapper');
            searchBoxWrapper.classList.remove('slds-hide');
            searchBoxWrapper.classList.add('slds-show');
    
            const pillDiv = this.template.querySelector('.pillDiv');
            pillDiv.classList.remove('slds-show');
            pillDiv.classList.add('slds-hide');
        }catch(e){
            console.error('Error while removing contact.', e);
        }
    }

    handelSelectRecordHelper() {
        if (this.disabled) return;
        try {
            const lookupInputContainer = this.template.querySelector('.lookupInputContainer');
            lookupInputContainer.classList.remove('slds-is-open');

            const searchBoxWrapper = this.template.querySelector('.searchBoxWrapper');
            searchBoxWrapper.classList.remove('slds-show');
            searchBoxWrapper.classList.add('slds-hide');

            const pillDiv = this.template.querySelector('.pillDiv');
            pillDiv.classList.remove('slds-hide');
            pillDiv.classList.add('slds-show');
        }catch(e){
            console.error('Something went wrong!', e);
        }
    }

    lookupUpdatehandler(value) {
        const oEvent = new CustomEvent('lookupupdate', {
            // detail: { selectedRecord: value },
            detail: { selectedRecord: value || { Id: '', Name: 'None' } },
        });
        this.dispatchEvent(oEvent);
    }
}