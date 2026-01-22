import { LightningElement, track, wire } from 'lwc';
import getWhatsAppFlows from '@salesforce/apex/WhatsAppFlowController.getWhatsAppFlows';
import publishWhatsAppFlow from '@salesforce/apex/WhatsAppFlowController.publishWhatsAppFlow';
import deleteWhatsAppFlow from '@salesforce/apex/WhatsAppFlowController.deleteWhatsAppFlow';
import deprecateWhatsAppFlow from '@salesforce/apex/WhatsAppFlowController.deprecateWhatsAppFlow';
import getPreviewURLofWhatsAppFlow from '@salesforce/apex/WhatsAppFlowController.getPreviewURLofWhatsAppFlow';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getObjectInfo, getPicklistValues } from "lightning/uiObjectInfoApi";
import FLOW_OBJECT from "@salesforce/schema/Flow__c";
import STATUS_FIELD from "@salesforce/schema/Flow__c.Status__c";
import { loadStyle } from 'lightning/platformResourceLoader';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
import { NavigationMixin } from 'lightning/navigation';

export default class WbAllFlowsPage extends NavigationMixin(LightningElement) {
    @track allRecords = [];
    @track filteredRecords = [];
    @track statusValues = '';
    @track statusOptions = [];
    @track searchInput;
    @track isLoading = true;
    @track flowPreviewURL = '';
    @track showPopup = false;
    @track isFlowDraft = false;
    @track showLicenseError = false;
    @track isEditMode = false;
    @track selectedFlowId = '';
    @track currentPage = 1;
    @track pageSize = 15;
    @track visiblePages = 5;
    @track paginatedData = [];

    @track isNameClicked = false;
    @track selectedFlowName = '';
    @track selectedFlowStatus = '';

    get showNoRecordsMessage() {
        return this.filteredRecords.length === 0;
    }

    get totalItems() {
        return this.filteredRecords.length;
    }
    
    get totalPages() {
        return Math.ceil(this.totalItems / this.pageSize);
    }
    
    get pageNumbers() {
        try {
            const totalPages = this.totalPages;
            const currentPage = this.currentPage;
            const visiblePages = this.visiblePages;

            let pages = [];

            if (totalPages <= visiblePages) {
                for (let i = 1; i <= totalPages; i++) {
                    pages.push({
                        number: i,
                        isEllipsis: false,
                        className: `pagination-button ${i === currentPage ? 'active' : ''}`
                    });
                }
            } else {
                pages.push({
                    number: 1,
                    isEllipsis: false,
                    className: `pagination-button ${currentPage === 1 ? 'active' : ''}`
                });

                if (currentPage > 3) {
                    pages.push({ isEllipsis: true });
                }

                let start = Math.max(2, currentPage - 1);
                let end = Math.min(currentPage + 1, totalPages - 1);

                for (let i = start; i <= end; i++) {
                    pages.push({
                        number: i,
                        isEllipsis: false,
                        className: `pagination-button ${i === currentPage ? 'active' : ''}`
                    });
                }

                if (currentPage < totalPages - 2) {
                    pages.push({ isEllipsis: true });
                }

                pages.push({
                    number: totalPages,
                    isEllipsis: false,
                    className: `pagination-button ${currentPage === totalPages ? 'active' : ''}`
                });
            }
            return pages;
        } catch (error) {
            this.showToast('Error', 'Error in pageNumbers->' + error, 'error');
            return null;
        }
    }
    
    get isFirstPage() {
        return this.currentPage === 1;
    }
    
    get isLastPage() {
        return this.currentPage === Math.ceil(this.totalItems / this.pageSize);
    }

    @wire(getObjectInfo, { objectApiName: FLOW_OBJECT })
    flowMetadata;

    @wire(getPicklistValues, { recordTypeId: "$flowMetadata.data.defaultRecordTypeId", fieldApiName: STATUS_FIELD })
    wiredPicklistValues({ error, data }) {
        if (data) {
            this.statusOptions = [
                { label: 'Status', value: '' },
                ...data.values
            ];
        } else if (error) {
            console.error(`Error fetching Status picklist values: ${error}`);
            this.statusOptions = [];
        }
    }

    connectedCallback(){
        try {
            loadStyle(this, MulishFontCss)
            .then(() => {
                console.log('External Css Loaded');
            })
            .catch(error => {
                console.log('Error occuring during loading external css', error);
            });
            this.fetchWhatsAppFlows();
        } catch (e) {
            console.error('Error in connectedCallback:::', e.message);
        }
    }

    // async checkLicenseStatus() {
    //     try {
    //         const isLicenseValid = await checkLicenseUsablility();
    //         if (!isLicenseValid) {
    //             this.showLicenseError = true;
    //         }
    //     } catch (error) {
    //         console.error('Error checking license:', error);
    //     }
    // }

    handleFlowNameClick(event) {
        try {
            event.preventDefault();
            const flowId = event.currentTarget.dataset.id;
            const flowName = event.currentTarget.dataset.name;
            this.isNameClicked = true;
            this.selectedFlowId = flowId;
            this.selectedFlowName = flowName;
        } catch (error) {
            this.showToast('Error', 'Error navigating to flow report', 'error');
            console.error('Error in handleFlowNameClick:', error);
        }
    }

    fetchWhatsAppFlows(){
        try {
            getWhatsAppFlows()
                .then((data) => {
                    this.allRecords = data.map((record, index) => {
                        return {
                            ...record,
                            serialNumber: index + 1,
                            isEditable: record.MVEX__Status__c === 'Published' || record.MVEX__Status__c === 'Draft',
                            isDraft: record.MVEX__Status__c === 'Draft',
                            isPublished: record.MVEX__Status__c === 'Published',
                            isDeprecated: record.MVEX__Status__c === 'Deprecated',
                            LastModifiedDate: this.formatDate(record.LastModifiedDate)
                        };
                    });
                    this.filterRecords();
                })
                .catch((error) => {
                    console.error(error);
                })
        } catch (error) {
            console.error('Error in fetchWhatsAppFlows : ' , error);
        }
    }

    showCreateFlow(){
        this.isEditMode = false;
        let cmpDef = {
            componentDef: "c:createFlowManagement",
            attributes: {
                isEditMode: this.isEditMode,
            }
        };

        let encodedDef = btoa(JSON.stringify(cmpDef));
            this[NavigationMixin.Navigate]({
            type: "standard__webPage",
            attributes: {
                url:  "/one/one.app#" + encodedDef                                                         
            }
        });
    }

    handleStatusChange(event) {
        this.statusValues = event.detail.value;
        this.filterRecords();
    }

    handleSearchInputChange(event) {
        this.searchInput = event.target.value.trim().toLowerCase();
        this.filterRecords();
    }

    filterRecords() {
        try {
            let filtered = [...this.allRecords];
    
            if (this.statusValues.length > 0) {
                filtered = filtered.filter(record => this.statusValues.includes(record.MVEX__Status__c));
            }
    
            if (this.searchInput) {
                filtered = filtered.filter(record => record.MVEX__Flow_Name__c.toLowerCase().includes(this.searchInput));
            }
    
            this.filteredRecords = filtered;
            this.isLoading = false;
            this.updateShownData();
        } catch (error) {
            console.error('Error in filtering records:', error);
            this.isLoading = false;
        }
    }

    updateShownData() {
        try {
            const startIndex = (this.currentPage - 1) * this.pageSize;
            const endIndex = Math.min(startIndex + this.pageSize, this.totalItems);
            this.paginatedData = this.filteredRecords.slice(startIndex, endIndex);
        } catch (error) {
            this.showToast('Error', 'Error updating shown data', 'error');
        }
    }

    handlePrevious() {
        try{
            if (this.currentPage > 1) {
                this.currentPage--;
                this.updateShownData();
            }
        }catch(error){
            this.showToast('Error', 'Error navigating to previous page', 'error');
        }
    }

    handleNext() {
        try{
            if (this.currentPage < this.totalPages) {
                this.currentPage++;
                this.updateShownData();
            }
        }catch(error){
            this.showToast('Error', 'Error navigating pages', 'error');
        }
    }

    handlePageChange(event) {
        try{
            const selectedPage = parseInt(event.target.getAttribute('data-id'), 10);
            if (selectedPage !== this.currentPage) {
                this.currentPage = selectedPage;
                this.updateShownData();
            }
        }catch(error){
            this.showToast('Error', 'Error navigating pages', 'error');
        }
    } 

    formatDate(dateString) {
        if (dateString) {
            const date = new Date(dateString);
            return date.toLocaleString('en-GB', {
                day: 'numeric',
                month: 'short',
                year: 'numeric',
                hour: '2-digit',
                minute: '2-digit',
                second: '2-digit',
                hour12: false,
                timeZone: 'UTC'
            });
        }
    }

    editFlow(event){
        this.selectedFlowId = event.currentTarget.dataset.id;
        this.isEditMode = true;
        let cmpDef = {
            componentDef: "c:createFlowManagement",
            attributes: {
                isEditMode: this.isEditMode,
                selectedFlowId: this.selectedFlowId
            }
        };

        let encodedDef = btoa(JSON.stringify(cmpDef));
            this[NavigationMixin.Navigate]({
            type: "standard__webPage",
            attributes: {
                url:  "/one/one.app#" + encodedDef                                                         
            }
        });
    }
    
    deleteFlow(event){
        this.selectedFlowId = event.currentTarget.dataset.id;
        this.selectedFlowStatus = event.currentTarget.dataset.status;
        this.showMessagePopup('Warning','Delete WhatsApp Flow','Are you sure you want to delete this whatsapp flow? This action cannot be undone.');
    }

    deprecateFlow(event){
        this.selectedFlowId = event.currentTarget.dataset.id;
        this.selectedFlowStatus = event.currentTarget.dataset.status;
        this.showMessagePopup('Warning','Deprecate WhatsApp Flow','Are you sure you want to deprecate this whatsapp flow? This action cannot be undone.');
    }

    previewTemplate(event){
        try {
            let flowId = event.currentTarget.dataset.id;
            this.showPopup = true;

            let matchingRecord = this.filteredRecords.find(record => record.MVEX__Flow_Id__c === flowId);
            if (matchingRecord && matchingRecord.MVEX__Status__c === 'Draft') {
                this.isFlowDraft = true;
            }

            this.selectedFlowId = flowId;
            getPreviewURLofWhatsAppFlow({ flowId : flowId })
                .then((data) => {
                    if(data !== 'failed'){
                        this.flowPreviewURL = data;
                    } else {
                        this.showToast('Error', 'Failed to get flow preview', 'error');
                        console.error('Error in getting Flow Preview URL:', error);
                    }
                })
                .catch(error => {
                    this.showToast('Error', 'Failed to get flow preview', 'error');
                    console.error('Error in getting Flow Preview URL:', error);
                });
        } catch (error) {
            this.showToast('Error', 'Failed to get flow preview', 'error');
            console.error('Error in getting Flow Preview URL:', error);
        }
    }

    closePopup(){
        this.showPopup = false;
        this.flowPreviewURL = '';
        this.selectedFlowId = '';
    }

    publishFlow(){
        try {
            this.isLoading = true;
            publishWhatsAppFlow({flowId : this.selectedFlowId})
                .then((result) => {
                    if(!result.startsWith('Failed')){
                        this.closePopup();
                        this.fetchWhatsAppFlows();
                        this.showToast('Success', 'Flow Published Successfully', 'success');
                    } else {
                        this.showToast('Error', 'Failed to publish flow', 'error');
                        console.error('Error in publishing WhatsApp Flow:', error);
                    }
                })
                .catch((error) => {
                    this.showToast('Error', 'Failed to publish flow', 'error');
                    console.error('Failed to publish flow : ' , error);
                })
        } catch (error) {
            this.showToast('Error', 'Failed to publish flow', 'error');
            console.error('Error in publishFlow : ' , error);
        }
    }

    showToast(title, message, varient) {
        const toastEvent = new ShowToastEvent({title: title, message: message, variant: varient});
        this.dispatchEvent(toastEvent);
    }

    backToControlCenter() {
        this[NavigationMixin.Navigate]({
            type: "standard__navItemPage",
            attributes: {
                apiName: "MVEX__Control_Center",
            },
        });
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

    handleConfirmation(event) {
        if(event.detail === true){
            if (this.selectedFlowStatus === 'Draft') {
                this.isLoading = true;
                deleteWhatsAppFlow({flowId : this.selectedFlowId})
                    .then((result) => {
                        if(!result.startsWith('Failed')){
                            this.showToast('Success', 'Flow deleted successfully', 'success');
                            this.fetchWhatsAppFlows();
                        } else {
                            this.showToast('Error', 'Failed to delete flow', 'error');
                        }
                    })
                    .catch((error) => {
                        this.showToast('Error', 'Failed to delete flow', 'error');
                        console.error('Failed to delete flow : ' , error);
                    })
            } else if (this.selectedFlowStatus === 'Published') {
                this.isLoading = true;
                deprecateWhatsAppFlow({flowId : this.selectedFlowId})
                    .then((result) => {
                        if(!result.startsWith('Failed')){
                            this.showToast('Success', 'Flow deprecated successfully', 'success');
                            this.fetchWhatsAppFlows();
                        } else {
                            this.showToast('Error', 'Failed to deprecate flow', 'error');
                        }
                    })
                    .catch((error) => {
                        this.showToast('Error', 'Failed to deprecate flow', 'error');
                        console.error('Failed to deprecate flow : ' , error);
                    })
            } else {
                this.showToast('Error', 'Only flows in Draft or Published status can be deleted.', 'error');
                this.selectedFlowStatus = '';
                this.selectedFlowId = '';
            }
        } else {
            this.selectedFlowStatus = '';
            this.selectedFlowId = '';
        }
    }
}