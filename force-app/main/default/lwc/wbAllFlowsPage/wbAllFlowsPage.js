import { LightningElement, track, wire } from 'lwc';
import getWhatsAppFlows from '@salesforce/apex/WhatsAppFlowController.getWhatsAppFlows';
import publishWhatsAppFlow from '@salesforce/apex/WhatsAppFlowController.publishWhatsAppFlow';
import deleteWhatsAppFlow from '@salesforce/apex/WhatsAppFlowController.deleteWhatsAppFlow';
import deprecateWhatsAppFlow from '@salesforce/apex/WhatsAppFlowController.deprecateWhatsAppFlow';
import getFlowByIdWithScreens from '@salesforce/apex/WhatsAppFlowControllerV2.getFlowByIdWithScreens';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getObjectInfo, getPicklistValues } from "lightning/uiObjectInfoApi";
import FLOW_OBJECT from "@salesforce/schema/Flow__c";
import STATUS_FIELD from "@salesforce/schema/Flow__c.Status__c";
import { loadStyle } from 'lightning/platformResourceLoader';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
import { NavigationMixin } from 'lightning/navigation';
import FORM_FACTOR from '@salesforce/client/formFactor';

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
    @track isFlowVisible = true;
    @track iscreateflowvisible = false;
    @track isEditMode = false;
    @track isCloneFlow = false;
    @track cloneFlowName = '';
    @track selectedFlowId = '';
    @track currentPage = 1;
    @track pageSize = 20;
    @track visiblePages = 5;
    @track paginatedData = [];

    @track isNameClicked = false;
    @track selectedFlowName = '';
    @track selectedFlowStatus = '';
    @track selectedFlowJson = '';

    // Sorting variables
    @track sortField = 'MVEX__Flow_Name__c';
    @track sortOrder = 'asc';

    get showNoRecordsMessage() {
        return this.filteredRecords.length === 0;
    }

    get totalItems() {
        return this.filteredRecords.length;
    }
    
    get totalPages() {
        return Math.ceil(this.totalItems / this.pageSize);
    }

    get showPagination(){
        return this.totalPages > 1;
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

    get isMobileOrTablet() {
        return FORM_FACTOR === 'Small' || FORM_FACTOR === 'Medium';
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
            this.isFlowVisible = true;
            this.fetchWhatsAppFlows();
        } catch (e) {
            console.error('Error in connectedCallback:::', e.message);
        }
    }

    renderedCallback() {
        // Only update sort icons if we have data loaded
        if (this.allRecords && this.allRecords.length > 0) {
            this.updateSortIcons();
        }
    }

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
                            statusClass: this.getStatusClass(record.MVEX__Status__c),
                            LastModifiedDate: this.formatDate(record.LastModifiedDate)
                        };
                    });
                    this.sortData();
                    this.filterRecords();
                })
                .catch((error) => {
                    console.error(error);
                })
        } catch (error) {
            console.error('Error in fetchWhatsAppFlows : ' , error);
        }
    }

    /**
    * Method Name: getStatusClass
    * @description: Returns a CSS class name for the given status value — same pattern as displayCampaigns.
    * Date: 08/04/2026
    * Created By: Vyom Soni
    */
    getStatusClass(status) {
        switch (status) {
            case 'Draft':       return 'status-draft-class';
            case 'Published':   return 'status-published-class';
            case 'Deprecated':  return 'status-deprecated-class';
            default:            return 'status-default-class';
        }
    }

    showCreateFlow(){
        this.isEditMode = false;
        this.isFlowVisible = false;
        this.iscreateflowvisible = true;
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
            // Reset to first page whenever filters change so pagination recalculates correctly
            this.currentPage = 1;
            this.sortData();
            this.isLoading = false;
            this.updateShownData();
        } catch (error) {
            console.error('Error in filtering records:', error);
            this.isLoading = false;
        }
    }

    /**
    * Method Name : sortClick
    * @description : this methods apply the sorting on the all fields
    * Created Date: 03/06/2024
    * Created By: Karan Singh
    */
    sortClick(event) {
        try {
            const fieldName = event.currentTarget.dataset.id;
            if (this.sortField === fieldName) {
                this.sortOrder = this.sortOrder === 'asc' ? 'desc' : 'asc';
            } else {
                this.sortField = fieldName;
                this.sortOrder = 'asc';
            }
            this.sortData();
            this.updateSortIcons();
        } catch (error) {
            console.log('Error in sortClick --> ' + error);
        }
    }

    /**
    * Method Name : sortData
    * @description : Method used to apply sorting on the data
    * Created Date: 08/11/2024
    * Created By: Karan Singh
    */
   sortData() {
        try {
            let dataToSort = [...this.filteredRecords];

            dataToSort.sort((a, b) => {
                let aValue = a[this.sortField];
                let bValue = b[this.sortField];

                if (aValue === undefined) aValue = '';
                if (bValue === undefined) bValue = '';

                if (this.sortField === 'LastModifiedDate') {
                    aValue = new Date(aValue);
                    bValue = new Date(bValue);
                }

                if (typeof aValue === 'string' && typeof bValue === 'string') {
                    aValue = aValue.toLowerCase();
                    bValue = bValue.toLowerCase();
                }

                let compare = 0;
                if (aValue > bValue) compare = 1;
                else if (aValue < bValue) compare = -1;

                return this.sortOrder === 'asc' ? compare : -compare;
            });

            // Update filteredRecords
            this.filteredRecords = dataToSort.map((record, index) => ({
                ...record,
                serialNumber: index + 1
            }));

            // refresh pagination
            this.updateShownData();

        } catch (error) {
            console.log('Error in sortData --> ', error.stack);
        }
    }

    /**
    * Method Name : updateSortIcons
    * @description : this method update the sort icons in the wrapbutton
    * Created Date : 3/06/2024
    * Created By: Karan Singh
    */
    updateSortIcons() {
        try {
            // Remove icon rotation
            const allIcons = this.template.querySelectorAll('.slds-icon-utility-arrowdown svg');
            allIcons.forEach(icon => {
                icon.classList.remove('rotate-asc', 'rotate-desc');
            });

            // Remove active class from all headers
            const allHeaders = this.template.querySelectorAll('.sorting_header');
            allHeaders.forEach(header => {
                header.classList.remove('active-sort');
            });

            // Set active header
            const currentHeader = this.template.querySelector('[data-id="' + this.sortField + '"]');
            if (currentHeader) {
                currentHeader.classList.add('active-sort');

                const icon = currentHeader.querySelector('svg');
                if (icon) {
                    icon.classList.add(this.sortOrder === 'asc' ? 'rotate-asc' : 'rotate-desc');
                }
            }

        } catch (error) {
            console.log('Error in updateSortIcons --> ' + error);
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
        this.cloneFlowName = event.currentTarget.dataset.name;
        this.isEditMode = true;
        this.isFlowVisible = false;
        this.iscreateflowvisible = true;
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

    async previewTemplate(event){
        try {
            let recordId = event.currentTarget.dataset.id;
            this.showPopup = true;

            let matchingRecord = this.filteredRecords.find(record => record.Id === recordId);
            if (matchingRecord) {
                this.isFlowDraft = matchingRecord.MVEX__Status__c === 'Draft';
                this.selectedFlowId = recordId;
                this.selectedFlowName = matchingRecord.MVEX__Flow_Name__c || '';
                
                // Fetch full flow data with screens
                const resultString = await getFlowByIdWithScreens({ flowId: recordId });
                const result = JSON.parse(resultString);
                
                if (result && result.success) {
                    const flowData = result.data;
                    this.selectedFlowJson = flowData.MVEX__Flow_JSON__c || '{}';
                    this.showPopup = true;
                } else {
                    console.error('Failed to load flow data:', result.message);
                    this.showMessageToast('Error', result.message || 'Failed to load flow data', 'error');
                }
            }
        } catch (error) {
            this.showToast('Error', 'Failed to get flow preview', 'error');
            console.error('Error in getting Flow Preview URL:', error);
        }
    }

    closePopup(){
        this.showPopup = false;
        this.flowPreviewURL = '';
        this.selectedFlowId = '';
        this.selectedFlowName = '';
        this.selectedFlowJson = '';
    }

    publishFlow(){
        try {
            this.isLoading = true;
            let matchingRecord = this.filteredRecords.find(record => record.Id === this.selectedFlowId);
            if (matchingRecord) {
                publishWhatsAppFlow({flowId : matchingRecord.MVEX__Flow_Id__c})
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
                    .finally(() => {
                        this.isLoading = false;
                    });
            }
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
                let matchingRecord = this.filteredRecords.find(record => record.Id === this.selectedFlowId);
                if (matchingRecord) {
                    deleteWhatsAppFlow({flowId : matchingRecord.MVEX__Flow_Id__c})
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
                }
            } else if (this.selectedFlowStatus === 'Published') {
                this.isLoading = true;
                let matchingRecord = this.filteredRecords.find(record => record.Id === this.selectedFlowId);
                if (matchingRecord) {
                    deprecateWhatsAppFlow({flowId : matchingRecord.MVEX__Flow_Id__c})
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
                }
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

    handleBack(){
        this.iscreateflowvisible = false;
        this.isNameClicked = false;
        this.isFlowVisible = true;
        this.isEditMode = false;
        this.isCloneFlow = false;
        this.selectedFlowId = '';
        this.cloneFlowName = '';
        this.fetchWhatsAppFlows();
    }
}