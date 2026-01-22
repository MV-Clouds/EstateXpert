import { LightningElement, track } from 'lwc';
import getBroadcastGroups from '@salesforce/apex/BroadcastMessageController.getBroadcastGroups';
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getTemplatesByObject from '@salesforce/apex/BroadcastMessageController.getTemplatesByObject';
import createChatRecods from '@salesforce/apex/BroadcastMessageController.createChatRecods';
import { subscribe, unsubscribe } from 'lightning/empApi';
import { NavigationMixin } from 'lightning/navigation';
import { loadStyle } from 'lightning/platformResourceLoader';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
import getBroadcastRecsWithReplies from '@salesforce/apex/BroadcastMessageController.getBroadcastRecsWithReplies';

export default class WbAllBroadcastPage extends NavigationMixin(LightningElement) {
    @track data = [];
    @track paginatedData = [];
    @track filteredData = [];
    @track broadcastGroups = [];
    @track filteredGroups = [];
    @track selectedGroupIds = [];
    @track templateOptions = []; // Will store the processed template options
    @track templateMap = new Map(); // Store the raw Map from Apex
    @track selectedTemplate = null;
    @track selectedDateTime;
    @track currentPage = 1;
    @track pageSize = 15;
    @track visiblePages = 5;
    @track isLoading = true;
    @track showPopup = false;
    @track selectedObjectName = '';
    @track popUpFirstPage = true;
    @track popUpSecondpage = false;
    @track popUpLastPage = false;
    @track popupHeader = 'Choose Broadcast Groups';

    @track selectedListValue = 'Broadcast';
    @track isBroadCastSelected = true;
    @track isTemplateVisible = false;
    @track showLicenseError = false;
    @track selectedRecordId = '';
    @track sortField = '';
    @track sortOrder = 'asc';

    subscription = {};
    channelName = '/event/BroadcastUpdateEvent__e';

    get showNoRecordsMessage() {
        return this.filteredData.length === 0;
    }

    get totalItems() {
        return this.filteredData.length;
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

    get isNextDisabled() {
        return this.selectedGroupIds.length === 0;
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
            this.loadBroadcastGroups();
            this.subscribeToPlatformEvent();
            this.loadAllTemplates(); // Load templates on component initialization
            
        } catch (e) {
            console.error('Error in connectedCallback:::', e.message);
        }
    }

    disconnectedCallback(){
        this.unsubscribeFromPlatformEvent();
    }

    // Load all templates once during initialization
    loadAllTemplates() {
        // this.isLoading = true;
        getTemplatesByObject()
            .then(result => {
                // Convert the Apex Map to JavaScript Map
                this.templateMap = new Map(Object.entries(result));                
                this.updateTemplateOptions(); // Update options based on selected object
            })
            .catch(error => {
                this.showToast('Error', 'Failed to load templates', 'error');
            })
    }

    updateTemplateOptions() {
        if (!this.selectedObjectName || this.templateMap.size === 0) {
            this.templateOptions = [];
            return;
        }

        let combinedTemplates = [];

        // Add object-specific templates
        if (this.templateMap.has(this.selectedObjectName)) {
            combinedTemplates = [...this.templateMap.get(this.selectedObjectName)];
        }

        // Add Generic templates
        if (this.templateMap.has('Generic')) {
            combinedTemplates = [...combinedTemplates, ...this.templateMap.get('Generic')];
        }

        // Convert to combobox options format
        this.templateOptions = combinedTemplates.map(template => ({
            label: template.MVEX__Template_Name__c,
            value: template.Id
        }));

        
    }

    subscribeToPlatformEvent() {
        subscribe(this.channelName, -1, (message) => {
            
            if(message.data.payload.MVEX__IsChanged__c === true){
                this.loadBroadcastGroups();
            }            
        })
        .then((response) => {
            this.subscription = response;
        })
        .catch(() => {
            this.showToast('Error', 'Failed to subscribe to platform event.', 'error');
        });
    }

    // Method to unsubscribe from the Platform Event
    unsubscribeFromPlatformEvent() {
        if (this.subscription) {
            unsubscribe(this.subscription, () => {
            });
        }
    }

    loadBroadcastGroups() {
        getBroadcastRecsWithReplies()
            .then(result => {
                this.data = result.map((item, index) => ({
                    ...item,
                    index : index + 1,
                }));                 
    
                this.filteredData = [...this.data];
                this.updateShownData();
            })
            .catch(() => {
                this.showToast('Error', 'Failed to load broadcast groups', 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
    
    updateShownData() {
        try {
            const startIndex = (this.currentPage - 1) * this.pageSize;
            const endIndex = Math.min(startIndex + this.pageSize, this.totalItems);
            this.paginatedData = this.filteredData.slice(startIndex, endIndex).map((item, index) => ({
                ...item,
                index: startIndex + index + 1 // Recalculate index for current page
            }));
        } catch (error) {
            this.showToast('Error', 'Error updating shown data', 'error');
        }
    }

    handleSearch(event) {
        try {
            if(event.detail.value.trim().toLowerCase() != null) {
                this.filteredData = this.data.filter(item => 
                    item.Name &&
                    item.Name.toLowerCase().includes(event.detail.value.trim().toLowerCase())
                );
                if (this.sortField) {
                    this.sortData();
                } else {
                    this.updateShownData();
                }
            }
        } catch (error) {
            this.showToast('Error', 'Error searching', 'error');
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
    newBroadcast(){
        this.showPopup = true;
        this.isLoading = true;

        getBroadcastGroups()
            .then(result => {
                this.broadcastGroups = result;
                this.filteredGroups = [...this.broadcastGroups.filter(item => item.MVEX__Communication_Type__c != 'Email')];
            })
            .catch(() => {
                this.showToast('Error', 'Error fetching broadcast groups', 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleSearchPopup(event) {
        const searchValue = event.target.value.trim().toLowerCase();
    
        // Filter the broadcast groups based on the search value
        this.filteredGroups = this.broadcastGroups.filter(group =>
            group.Name.toLowerCase().includes(searchValue)
        );
    
        // Ensure the IsChecked property is updated for filtered groups
        this.filteredGroups = this.filteredGroups.map(group => ({
            ...group,
            IsChecked: this.selectedGroupIds.some(selected => selected.Id === group.Id)
        }));
    }
    // Handle group selection
    handleGroupSelection(event) {
        try {
            const groupId = event.target.dataset.id;
            const selectedGroup = this.broadcastGroups.find(group => group.Id === groupId);
    
            if (event.target.checked) {
                // Add group ID to selected list if checked
                if (!this.selectedGroupIds.some(group => group.Id === groupId)) {
                    this.selectedGroupIds = [
                        ...this.selectedGroupIds,
                        { Id: groupId, ObjName: selectedGroup.MVEX__Object_Name__c,Name:selectedGroup.Name } // Store both Id and Name
                    ];
                }
            } else {
                // Remove group ID if unchecked
                this.selectedGroupIds = this.selectedGroupIds.filter(group => group.Id !== groupId);
            }
    
            this.selectedObjectName = this.selectedGroupIds[0]?.ObjName || '';
    
            // Update filteredGroups to reflect selection
            this.filteredGroups = this.filteredGroups.map(group => ({
                ...group,
                IsChecked: this.selectedGroupIds.some(selected => selected.Id === group.Id)
            }));
        } catch (error) {
            this.showToast('Error', 'Error handling group selection', 'error');
        }
    }

    handleNextOnPopup() {
        try {
            const firstObjName = this.selectedGroupIds[0]?.ObjName;
            const allSameObjName = this.selectedGroupIds.every(group => group.ObjName === firstObjName);
            
            if(!allSameObjName){
                this.showToast('Error!', 'Please select groups with the same object name', 'error');
                return;
            }

            this.updateTemplateOptions();
    
            this.popupHeader = 'Choose Template';
            this.popUpFirstPage = false;
            this.popUpSecondpage = true;
        } catch (error) {
            this.showToast('Error!', 'Please select template', 'error');
        }
    }

    handleInputChange(event){
        const { name, value } = event.target;
        switch(name) {
            case 'template':
                this.selectedTemplate = value;
            break;
            case 'dateTime':
                this.selectedDateTime = value;                
            break;
        }
    }

    handleCloseOnPopup() {
        this.showPopup = false;
        this.popUpFirstPage = true;
        this.popUpSecondpage = false;
        this.popUpLastPage = false;
        this.popupHeader = 'Select Groups';
    
        // Reset the selected values
        this.selectedGroupIds = [];
        this.selectedTemplate = '';
        this.selectedDateTime = '';
    
        // Reset the filteredGroups and update IsChecked property
        this.filteredGroups = this.broadcastGroups.map(group => ({
            ...group,
            IsChecked: false
        }));
    }

    handlePreviousOnPopup(){
        this.popupHeader = 'Choose Broadcast Groups';
        this.selectedTemplate = '';
        this.popUpFirstPage = true;
        this.popUpSecondpage = false;
    }

    handleSchedulePopup(){

        if(this.selectedTemplate === '' || this.selectedTemplate === null){
            this.showToast('Error!', 'Please select template', 'error');
            return;
        }

        this.popupHeader = 'Select Date and Time'

        this.popUpFirstPage = false;
        this.popUpSecondpage = false;
        this.popUpLastPage = true;
    }

    handlePreviousLastpage(){
        this.popupHeader = 'Choose Template';
        this.popUpFirstPage = false;
        this.popUpSecondpage = true;
        this.popUpLastPage = false;

    }

    handleSchedule(){

        if(this.selectedDateTime === '' || this.selectedDateTime === null){
            this.showToast('Error!', 'Please select date and time', 'error');
            return;
        }     

        const selectedTime = new Date(this.selectedDateTime);
        const now = new Date();

        if (selectedTime < now) {
            this.showToast('Error!', 'Selected date and time cannot be in the past', 'error');
            return;
        }   

        let grpIdList = this.selectedGroupIds.map(record => record.Id);

        createChatRecods({templateId: this.selectedTemplate, groupIds: grpIdList, isScheduled: true, timeOfMessage: this.selectedDateTime})
            .then(result => {
                if (result === 'Success') {
                    this.showToast('Success', 'Broadcast sent successfully', 'success');
                    this.handleCloseOnPopup();
                } else {
                    this.showToast('Error', `Broadcast sent failed - ${result}`, 'error');
                }
            })
            .catch(error => {
                this.showToast('Error', `Broadcast sent failed - ${error}`, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
        
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

    handleSendOnPopup(){

        if(this.selectedTemplate === '' || this.selectedTemplate === null){
            this.showToast('Error!', 'Please select template', 'error');
            return;
        }

        this.isLoading = true;
        let grpIdList = this.selectedGroupIds.map(record => record.Id);

        createChatRecods({templateId: this.selectedTemplate, groupIds: grpIdList, isScheduled: false, timeOfMessage: ''})
            .then(result => {
                if (result === 'Success') {
                    this.showToast('Success', 'Broadcast sent successfully', 'success');
                    this.handleCloseOnPopup();
                } else {
                    this.showToast('Error', `Broadcast sent failed - ${result}`, 'error');
                }
            })
            .catch(error => {
                this.showToast('Error', `Broadcast sent failed - ${error}`, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
    
    handleNameClick(event) {

        try {
            this.selectedRecordId = event.target.dataset.recordId;

            const record = this.data.find(item => item.Id === this.selectedRecordId); 

            let componentDef = {
                componentDef: "c:broadcastReportComp",
                attributes: {
                    recordId: this.selectedRecordId,
                    record: record,
                    templateName: record?.TemplateName || '—'
                }
            };

            let jsonString = JSON.stringify(componentDef);
            // Modern approach: convert to UTF-8 bytes then base64
            let encodedComponentDef = btoa(new TextEncoder().encode(jsonString).reduce((data, byte) => data + String.fromCharCode(byte), ''));
    
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: '/one/one.app#' + encodedComponentDef
                }
            });
        } catch (error) {
            console.log('error stack--> ',error.stack);
            
        }
    }
    
    showToast(title ,message, status){
        this.dispatchEvent(new ShowToastEvent({title: title, message: message, variant: status}));
    }

    sortClick(event) {
        try {
            const fieldName = event.currentTarget.dataset.id;
            if (fieldName === 'index') return; // Prevent sorting on index column
            if (this.sortField === fieldName) {
                this.sortOrder = this.sortOrder === 'asc' ? 'desc' : 'asc';
            } else {
                this.sortField = fieldName;
                this.sortOrder = 'asc';
            }
            this.sortData();
            this.updateSortIcons();
            this.updateShownData();
        } catch (error) {
            this.showToast('Error', 'Error in sorting: ' + error.message, 'error');
        }
    }

    // Natural sort function for alphanumeric strings
    naturalSort(a, b) {
        const aValue = a.toString().toLowerCase();
        const bValue = b.toString().toLowerCase();
        
        // Split string into parts of numbers and non-numbers
        const re = /(\d+)|(\D+)/g;
        const aParts = aValue.match(re) || [];
        const bParts = bValue.match(re) || [];

        for (let i = 0; i < Math.min(aParts.length, bParts.length); i++) {
            const aPart = aParts[i];
            const bPart = bParts[i];

            // If both parts are numbers, compare numerically
            if (!isNaN(aPart) && !isNaN(bPart)) {
                const aNum = parseInt(aPart, 10);
                const bNum = parseInt(bPart, 10);
                if (aNum !== bNum) {
                    return aNum - bNum;
                }
            } else {
                // Compare strings
                if (aPart !== bPart) {
                    return aPart.localeCompare(bPart);
                }
            }
        }
        return aParts.length - bParts.length;
    }

    sortData() {
        try {
            this.filteredData = [...this.filteredData].sort((a, b) => {
                let aValue = a[this.sortField] || '';
                let bValue = b[this.sortField] || '';

                // Handle different field types
                if (this.sortField === 'Name') {
                    // Use natural sort for Name field
                    const compare = this.naturalSort(aValue, bValue);
                    return this.sortOrder === 'asc' ? compare : -compare;
                } else if (this.sortField === 'MVEX__Status__c') {
                    aValue = aValue.toString().toLowerCase();
                    bValue = bValue.toString().toLowerCase();
                    let compare = aValue.localeCompare(bValue);
                    return this.sortOrder === 'asc' ? compare : -compare;
                } else if (this.sortField.includes('__c')) {
                    // Handle numeric fields
                    aValue = Number(aValue) || 0;
                    bValue = Number(bValue) || 0;
                    let compare = aValue - bValue;
                    return this.sortOrder === 'asc' ? compare : -compare;
                }
                return 0;
            });
        } catch (error) {
            this.showToast('Error', 'Error in sortData: ' + error.message, 'error');
        }
    }

    updateSortIcons() {
        try {
            const allHeaders = this.template.querySelectorAll('.sorting_header svg');
            allHeaders.forEach(icon => {
                icon.classList.remove('rotate-asc', 'rotate-desc');
                icon.closest('.slds-icon_container').style.opacity = '0.3';
            });

            if (this.sortField) {
                const currentHeader = this.template.querySelector(`[data-index="${this.sortField}"]`);
                if (currentHeader) {
                    currentHeader.classList.add(this.sortOrder === 'asc' ? 'rotate-asc' : 'rotate-desc');
                    currentHeader.closest('.slds-icon_container').style.opacity = '1';
                }
            }
        } catch (error) {
            this.showToast('Error', 'Error in updateSortIcons: ' + error.message, 'error');
        }
    }
}