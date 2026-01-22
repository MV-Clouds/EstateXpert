/**
 * Component Name: WbAllTemplatePage
 * @description: Used LWC components to show all templates record.
 * Date: 25/11/2024
 * Created By: Rachit Shah
 */
 /***********************************************************************
MODIFICATION LOG*
 * Last Update Date : 30/04/2025
 * Updated By : Rachit Shah
 * Change Description :Code Rework
 ********************************************************************** */

import { LightningElement, track } from 'lwc';
import getWhatsAppTemplates from '@salesforce/apex/WBTemplateController.getWhatsAppTemplates';
import getCategoryAndStatusPicklistValues from '@salesforce/apex/WBTemplateController.getCategoryAndStatusPicklistValues';
import deleteTemplete from '@salesforce/apex/WBTemplateController.deleteTemplete';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
import { NavigationMixin } from 'lightning/navigation';
import { loadStyle } from 'lightning/platformResourceLoader';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';

export default class WbAllTemplatePage extends NavigationMixin(LightningElement) {
    @track isTemplateVisible = false;
    @track categoryValue='';
    @track timePeriodValue='';
    @track statusValues='';
    @track searchInput='';
    @track categoryOptions = [];
    @track statusOptions = [];
    @track allRecords = [];
    @track isLoading = true;
    @track filteredRecords=[];
    @track selectedTemplateId='';
    @track showPopup = false; 
    @track isFilterVisible = false;
    @track editTemplateId='';
    @track subscription = null;
    showFilters = false;
    channelName = '/event/Template_Update__e';

    get actionButtonClass(){
        return 'custom-button cus-btns' ;
    }

    get timePeriodOptions() {
        return [
            { label: 'All', value: '' },
            { label: 'Last 7 Days', value: 'last7days' },
            { label: 'Last 30 Days', value: 'last30days' },
            { label: 'Last 90 Days', value: 'last90days' }
        ];
    }


    get filterClass() {
        return this.isFilterVisible ? 'combobox-container visible' : 'combobox-container hidden';
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
            this.isTemplateVisible = true;
            this.fetchCategoryAndStatusOptions();
            this.fetchAllTemplate(true);
            this.registerPlatformEventListener();
        } catch (e) {
            console.error('Error in connectedCallback:::', e.message);
        }
    }


    disconnectedCallback() {
        this.unregisterPlatformEventListener(); 
    }

    registerPlatformEventListener() {
        const messageCallback = (event) => {
            const payload = event.data.payload;
            // this.updateRecord(payload.Template_Id__c, payload.Template_Status__c);

            // Call updateRecord only if Template_Id__c and Template_Status__c are present
            if (payload.MVEX__Template_Id__c && payload.MVEX__Template_Status__c) {
                this.updateRecord(payload.MVEX__Template_Id__c, payload.MVEX__Template_Status__c);
            }

            // Call a different method if Fetch_All_Templates__c is present
            if (payload.MVEX__Fetch_All_Templates__c) {
                this.fetchAllTemplate(false); // Replace with your actual method name
            }
        };

        subscribe(this.channelName, -1, messageCallback)
            .then((response) => {
                this.subscription = response;
            })
            .catch((error) => {
                console.error('Error subscribing to platform event:', error);
            });

        onError((error) => {
            console.error('Streaming API error:', error);
        });
    }

    unregisterPlatformEventListener() {
        if (this.subscription) {
            unsubscribe(this.subscription, (response) => {
            });
        }
    }

    updateRecord(templateId, newStatus) {
        const recordIndex = this.allRecords.findIndex((record) => record.Id === templateId);
        if (recordIndex !== -1) {
            const updatedRecord = { ...this.allRecords[recordIndex], MVEX__Status__c: newStatus };
            updatedRecord.isButtonDisabled = newStatus === 'In-Review';
            updatedRecord.cssClass = updatedRecord.isButtonDisabled ? 'action edit disabled' : 'action edit';

            this.allRecords[recordIndex] = updatedRecord;
            this.filteredRecords = [...this.allRecords]; 
        }
    }

    fetchCategoryAndStatusOptions() {
        getCategoryAndStatusPicklistValues()
            .then(data => {
                if (data) {
                    this.categoryOptions = [{ label: 'All', value: '' }, ...data.categories.map(categoryData => ({ label: categoryData, value: categoryData }))];
                    this.statusOptions = [{ label: 'All', value: '' }, ...data.statuses.map(statudData => ({ label: statudData, value: statudData }))];
                }
            })
            .catch(error => {
                console.error('Error fetching category and status picklist values: ', error);
            });
    }

    fetchAllTemplate(showSpinner){
        if(showSpinner){
            this.isLoading=true;
        }
        // this.isLoading=true;
        getWhatsAppTemplates()
        .then(data => {
            try {
                if (data) {
                    this.allRecords = data.map((record, index) => {
                        const isButtonDisabled = record.MVEX__Status__c === 'In-Review';
                        
                        return {
                            ...record,
                            id: record.Id,
                            serialNumber: index + 1, 
                            LastModifiedDate: this.formatDate(record.LastModifiedDate),
                            isButtonDisabled,
                            cssClass: isButtonDisabled ? 'action edit disabled' : 'action edit'
                        };
                    });                    
                    this.filteredRecords = [...this.allRecords];
                    this.isLoading=false;
                } else if (error) {
                    console.error('Error fetching WhatsApp templates: ', error);
                    this.isLoading=false;
                }
            } catch (err) {
                console.error('Unexpected error in wiredTemplates: ', err);
                this.isLoading=false;
            }
        })
        .catch(error => {
            console.error(error);
            this.isLoading=false;
        });
    }

    handleTemplateUpdate(event) {
        this.allRecords = event.detail; 
        this.filteredRecords = [...this.allRecords];
    }

    showCreateTemplate(){
        let cmpDef = {
            componentDef: "c:wbTemplateParent",
        };

        let encodedDef = btoa(JSON.stringify(cmpDef));
            this[NavigationMixin.Navigate]({
            type: "standard__webPage",
            attributes: {
                url:  "/one/one.app#" + encodedDef                                                         
            }
        });
    }

    handleChange(event) {
        try {
            const fieldName = event.target.name; 
            const value = event.detail?.value || event.target.value; 
        
            switch (fieldName) {
                case 'category':
                    this.categoryValue = value;
                    break;
                case 'timePeriod':
                    this.timePeriodValue = value;
                    break;
                case 'status':
                    this.statusValues = value;
                    break;
                case 'searchInput':
                    this.searchInput = value.toLowerCase();
                    break;
                default:
                    console.warn(`Unhandled field: ${fieldName}`);
                    break;
            }
            this.filterRecords();
        } catch (error) {
            console.error('Error while handling changes in the filter.',error);
        }
    }
  
    formatDate(dateString) {
        if (!dateString) return '';
        const options = { year: 'numeric', month: 'short', day: 'numeric' };
        return new Date(dateString).toLocaleDateString(undefined, options);
    }

    filterRecords() {
        try {
            let filtered = [...this.allRecords];

            if (this.categoryValue) {
                filtered = filtered.filter(record => record.MVEX__Template_Category__c === this.categoryValue);
            }
    
            if (this.timePeriodValue) {
                const today = new Date();
                let fromDate;
                if (this.timePeriodValue === 'last7days') {
                    fromDate = new Date(today.setDate(today.getDate() - 8));
                } else if (this.timePeriodValue === 'last30days') {
                    fromDate = new Date(today.setDate(today.getDate() - 30));
                } else if (this.timePeriodValue === 'last90days') {
                    fromDate = new Date(today.setDate(today.getDate() - 90));
                }
                filtered = filtered.filter(record => new Date(record.CreatedDate) >= fromDate);
            }
            if (this.statusValues.length > 0) {
                filtered = filtered.filter(record => this.statusValues.includes(record.MVEX__Status__c));
            }
    
            if (this.searchInput) {
                filtered = filtered.filter(record => record.MVEX__Template_Name__c.toLowerCase().includes(this.searchInput));
            }
    
            this.filteredRecords = filtered;

        } catch (error) {
            this.showToastError('An error occurred while filtering the records.');
        }
       
    }

    deleteTemplate(event){
        this.editTemplateId = event.currentTarget.dataset.id;
        this.showMessagePopup('Warning','Delete WhatsApp Template','Are you sure you want to delete this whatsapp template? This action cannot be undone.');
    }

    previewTemplate(event) {
        this.selectedTemplateId =  event.currentTarget.dataset.id;
        this.showPopup = true;
    }

    editTemplate(event) {
        const recordId = event.currentTarget.dataset.id;        
        const foundRecord = this.filteredRecords.find(r => r.id === recordId);
    
        if (foundRecord && foundRecord.isButtonDisabled) {
            return;  
        }
    
        this.editTemplateId = recordId;
        let cmpDef = {
            componentDef: "c:wbTemplateParent",
            attributes: {
                edittemplateid: this.editTemplateId
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
    

    handlePopupClose() {
        this.showPopup = false; 
    }

    showToastError(message) {
        const toastEvent = new ShowToastEvent({
            title: 'Error',
            message,
            variant: 'error'
        });
        this.dispatchEvent(toastEvent);
    }

        /*
    * Method Name: backToControlCenter
    * @description: Method to go back in the control center
    * Date: 23/06/2024
    * Created By: Rachit Shah
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
            console.log('error--> ',error);
        }
    }
    

    showToastSuccess(message) {
        const toastEvent = new ShowToastEvent({
            title: 'Success',
            message,
            variant: 'success'
        });
        this.dispatchEvent(toastEvent);
    }

    toggleFilterVisibility() {
        this.showFilters = !this.showFilters;
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
            this.isLoading=true;
            const recordId = this.editTemplateId;
            if(recordId !== undefined){
                deleteTemplete({templateId: recordId})
                .then(data => {
                    if(data === 'Template deleted successfully'){
                        this.showToastSuccess('Template deleted successfully');
                        this.allRecords = this.allRecords.filter(record => record.Id !== recordId); 
                        this.allRecords = this.allRecords.map((record, index) => ({
                            ...record,
                            serialNumber: index + 1
                        }));   
                        this.filteredRecords = [...this.allRecords];                    
                        this.isLoading=false;
                    }else{
                        this.showToastError('Error in deleting template');
                        this.isLoading=false;
                    }
                })
                .catch(error => {
                    console.error(error);
                    this.showToastError('Error in deleting template');
                    this.isLoading=false;
                    this.editTemplateId = '';
                });
            } else{
                this.showToastError('Template not found');
                this.isLoading=false;
                this.editTemplateId = '';
            }
        } else {
            this.editTemplateId = '';
        }
    }
}