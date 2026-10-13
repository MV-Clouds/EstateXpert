import { LightningElement, track, api, wire } from 'lwc';
import getWhatsAppTemplates from '@salesforce/apex/WATemplateHomePageController.getWhatsAppTemplates';
import hasBusinessAccountId from '@salesforce/apex/WATemplateHomePageController.hasBusinessAccountId';
import deleteTemplete from '@salesforce/apex/WATemplateHomePageController.deleteTemplete';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
import { NavigationMixin } from 'lightning/navigation';
import { loadStyle } from 'lightning/platformResourceLoader';
import globalStyles from '@salesforce/resourceUrl/globalStyles';
import FORM_FACTOR from '@salesforce/client/formFactor';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import WA_TEMPLATE_OBJECT from '@salesforce/schema/WA_Template__c';
import TEMPLATE_CATEGORY_FIELD from '@salesforce/schema/WA_Template__c.Template_Category__c';
import STATUS_FIELD from '@salesforce/schema/WA_Template__c.Status__c';

export default class WaTemplateHomePage extends NavigationMixin(LightningElement) {
    @track hasBusinessAccountConfigured = false;
    @track categoryValue = '';
    @track timePeriodValue = '';
    @track statusValues = '';
    @track searchInput = '';
    @track categoryOptions = [
        { label: 'All', value: '' },
        { label: 'Marketing', value: 'Marketing' },
        { label: 'Utility', value: 'Utility' }
    ];
    @track statusOptions = [
        { label: 'All', value: '' },
        { label: 'Active-Quality Pending', value: 'Active-Quality Pending' },
        { label: 'In-Review', value: 'In-Review' },
        { label: 'Disabled', value: 'Disabled' },
        { label: 'Rejected', value: 'Rejected' }
    ];
    @track allRecords = [];
    @track isLoading = true;
    @track filteredRecords = [];
    @track visibleRecords = [];
    @track openActionMenuId = null;
    @track openActionMenuUpwards = false;
    @track subscription = null;
    @track sortField = 'LastModifiedDate';
    @track sortOrder = 'desc';
    @track showFilters = false;
    channelName = '/event/MVEX__Template_Update__e';
    @track isManageTemplateView = false;
    @track manageTemplateId = null;
    @track isCloneMode = false;
    @track showDeleteModal = false;
    @track deletingTemplateRecord = null;

    // Pagination properties
    @track pageSize = 20;
    @track currentPage = 1;
    @track visiblePages = 5;

    get totalItems() {
        return this.filteredRecords.length;
    }

    get totalPages() {
        return Math.ceil(this.totalItems / this.pageSize) || 0;
    }

    get showPagination() {
        return this.totalItems > 0;
    }

    get isFirstPage() {
        return this.currentPage === 1;
    }

    get isLastPage() {
        return this.currentPage === this.totalPages || this.totalPages === 0;
    }

    get isFilterApplied() {
        return Boolean(this.categoryValue || this.statusValues || this.timePeriodValue);
    }

    get filterIconColor() {
        return this.showFilters ? '#ffffff' : '#445058';
    }

    get filterBtnClass() {
        return 'filter-toggle-btn' + (this.showFilters ? ' active' : '');
    }

    get pageSizeOptions() {
        const sizes = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100];
        return sizes.map(size => ({
            label: String(size),
            value: size,
            isSelected: this.pageSize === size
        }));
    }

    get recordCountInfo() {
        if (!this.totalItems) return '0 - 0 of 0';
        const start = (this.currentPage - 1) * this.pageSize + 1;
        const end = Math.min(this.currentPage * this.pageSize, this.totalItems);
        return `${start} - ${end} of ${this.totalItems}`;
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
                        className: `exp-pagination-button ${i === currentPage ? 'active' : ''}`
                    });
                }
            } else {
                pages.push({
                    number: 1,
                    isEllipsis: false,
                    className: `exp-pagination-button ${currentPage === 1 ? 'active' : ''}`
                });
                if (currentPage > 3) {
                    pages.push({ isEllipsis: true, number: 'ellipsis-start' });
                }
                let start = Math.max(2, currentPage - 1);
                let end = Math.min(currentPage + 1, totalPages - 1);
                for (let i = start; i <= end; i++) {
                    pages.push({
                        number: i,
                        isEllipsis: false,
                        className: `exp-pagination-button ${i === currentPage ? 'active' : ''}`
                    });
                }
                if (currentPage < totalPages - 2) {
                    pages.push({ isEllipsis: true, number: 'ellipsis-end' });
                }
                pages.push({
                    number: totalPages,
                    isEllipsis: false,
                    className: `exp-pagination-button ${currentPage === totalPages ? 'active' : ''}`
                });
            }
            return pages;
        } catch (error) {
            return [];
        }
    }

    get timePeriodOptions() {
        return [
            { label: 'All', value: '' },
            { label: 'Last 7 Days', value: 'last7days' },
            { label: 'Last 30 Days', value: 'last30days' },
            { label: 'Last 90 Days', value: 'last90days' }
        ];
    }

    get categoryOptionsList() {
        return this.categoryOptions.map(option => ({
            ...option,
            selected: option.value === this.categoryValue
        }));
    }

    get statusOptionsList() {
        return this.statusOptions.map(option => ({
            ...option,
            selected: option.value === this.statusValues
        }));
    }

    get timePeriodOptionsList() {
        return this.timePeriodOptions.map(option => ({
            ...option,
            selected: option.value === this.timePeriodValue
        }));
    }

    get isMobileOrTablet() {
        return FORM_FACTOR === 'Small' || FORM_FACTOR === 'Medium';
    }

    async connectedCallback() {
        try {
            window?.globalThis?.addEventListener('click', this.handleDocumentClick);
            loadStyle(this, globalStyles);

            await this.checkBusinessAccountConfig();
            if (!this.hasBusinessAccountConfigured) {
                this.isLoading = false;
                return;
            }

            this.fetchAllTemplate(true);
            this.registerPlatformEventListener();
        } catch (e) {
            console.error('Error in connectedCallback:', e.message);
        }
    }

    async checkBusinessAccountConfig() {
        try {
            const result = await hasBusinessAccountId();
            this.hasBusinessAccountConfigured = !!result;
        } catch (error) {
            console.error('Error checking business account configuration:', error);
            this.hasBusinessAccountConfigured = false;
        }
    }

    renderedCallback() {
        if (this.allRecords && this.allRecords.length > 0) {
            this.updateSortIcons();
        }
    }

    disconnectedCallback() {
        try {
            window?.globalThis?.removeEventListener('click', this.handleDocumentClick);
        } catch (error) {
            console.warn('Error removing document click listener', error);
        }
        this.unregisterPlatformEventListener(); 
    }

    handleDocumentClick = () => {
        if (this.openActionMenuId) {
            this.openActionMenuId = null;
            this.openActionMenuUpwards = false;
            this.updateShownData();
        }
    };

    toggleActionMenu(event) {
        event.stopPropagation();
        const recId = event.currentTarget.dataset.id;
        if (this.openActionMenuId === recId) {
            this.openActionMenuId = null;
            this.openActionMenuUpwards = false;
        } else {
            this.openActionMenuId = recId;
            const button = event.currentTarget;
            const container = this.template.querySelector('.exp-table-content');
            if (button && container) {
                const btnRect = button.getBoundingClientRect();
                const contRect = container.getBoundingClientRect();
                const spaceBelow = contRect.bottom - btnRect.bottom;
                const spaceAbove = btnRect.top - contRect.top;
                // Only open upwards if it does NOT fit below (spaceBelow < 170px) AND fits above (spaceAbove >= 170px)
                this.openActionMenuUpwards = spaceBelow < 170 && spaceAbove >= 170;
            } else {
                this.openActionMenuUpwards = false;
            }
        }
        this.updateShownData();
    }

    handleDropdownClick(event) {
        event.stopPropagation();
    }

    handleActionClick(event) {
        event.stopPropagation();
        const action = event.currentTarget.dataset.action;
        const recordId = event.currentTarget.dataset.id;
        this.openActionMenuId = null;
        this.openActionMenuUpwards = false;
        this.updateShownData();

        if (action === 'Edit') {
            const targetRecord = this.allRecords.find(r => r.Id === recordId);
            if (targetRecord) {
                if (targetRecord.isEditDisabled) {
                    this.showToastError(targetRecord.editDisabledReason || 'This template cannot be edited due to Meta restrictions.');
                    return;
                }
            }

            this.manageTemplateId = recordId;
            this.isCloneMode = false;
            this.isManageTemplateView = true;
            this.dispatchEvent(new CustomEvent('templatenavigate', {
                bubbles: true,
                composed: true,
                detail: { title: 'Edit Template', parentTitle: 'Message Templates' }
            }));
        } else if (action === 'Clone') {
            this.manageTemplateId = recordId;
            this.isCloneMode = true;
            this.isManageTemplateView = true;
            this.dispatchEvent(new CustomEvent('templatenavigate', {
                bubbles: true,
                composed: true,
                detail: { title: 'Clone Template', parentTitle: 'Message Templates' }
            }));
        } else if (action === 'Preview') {
            this.manageTemplateId = recordId;
            this.isCloneMode = false;
            this.isManageTemplateView = true;
            this.dispatchEvent(new CustomEvent('templatenavigate', {
                bubbles: true,
                composed: true,
                detail: { title: 'Preview Template', parentTitle: 'Message Templates' }
            }));
        } else if (action === 'Delete') {
            const targetRecord = this.allRecords.find(r => r.Id === recordId);
            this.deletingTemplateRecord = targetRecord || { Id: recordId, Template_Name__c: 'this template' };
            const popup = this.template.querySelector('c-message-popup');
            if (popup) {
                const tempName = this.deletingTemplateRecord.Template_Name__c || 'this template';
                popup.showMessagePopup({
                    status: 'warning',
                    title: 'Delete WhatsApp Template',
                    message: `Are you sure you want to delete template "${tempName}"? Deleting this template permanently removes it from Meta across all languages. Meta locks this template name for 30 days.`
                });
            }
        }
    }

    handleDeleteConfirmation(event) {
        if (event.detail === true) {
            this.confirmDeleteTemplate();
        } else {
            this.deletingTemplateRecord = null;
        }
    }

    confirmDeleteTemplate() {
        if (!this.deletingTemplateRecord || !this.deletingTemplateRecord.Id) {
            return;
        }
        const recId = this.deletingTemplateRecord.Id;
        this.isLoading = true;
        deleteTemplete({ templateId: recId })
            .then((result) => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Success',
                    message: result || 'Template deleted successfully',
                    variant: 'success'
                }));
                this.deletingTemplateRecord = null;
                this.fetchAllTemplate(false);
            })
            .catch((error) => {
                this.isLoading = false;
                this.deletingTemplateRecord = null;
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error',
                    message: (error.body && error.body.message) || error.message || 'Error deleting template',
                    variant: 'error'
                }));
            });
    }

    handleCloseManageTemplate() {
        this.isManageTemplateView = false;
        this.manageTemplateId = null;
        this.isCloneMode = false;
        this.fetchAllTemplate(false);
        this.dispatchEvent(new CustomEvent('templatenavigate', {
            bubbles: true,
            composed: true,
            detail: { title: 'Message Templates', parentTitle: '' }
        }));
    }

    @api
    resetView() {
        this.isManageTemplateView = false;
        this.manageTemplateId = null;
        this.isCloneMode = false;
    }

    showWorkInProgressToast() {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Info',
                message: 'Work is in progress',
                variant: 'info'
            })
        );
    }

    registerPlatformEventListener() {
        const messageCallback = (event) => {
            const payload = event.data?.payload;
            if (!payload) return;

            const templateId = payload.Template_Id__c || payload.MVEX__Template_Id__c;
            const templateStatus = payload.Template_Status__c || payload.MVEX__Template_Status__c;
            const shouldFetchAll = payload.Fetch_All_Templates__c || payload.MVEX__Fetch_All_Templates__c;

            if (templateId && templateStatus) {
                this.updateRecord(templateId, templateStatus);
            }

            if (shouldFetchAll) {
                this.fetchAllTemplate(false);
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
            unsubscribe(this.subscription, () => {});
        }
    }

    updateRecord(templateId, newStatus) {
        const recordIndex = this.allRecords.findIndex((record) => record.Id === templateId);
        if (recordIndex !== -1) {
            const updatedRecord = { 
                ...this.allRecords[recordIndex], 
                Status__c: newStatus,
                statusClass: this.getStatusClass(newStatus)
            };

            this.allRecords[recordIndex] = updatedRecord;
            this.filterRecords();
        }
    }

    @wire(getObjectInfo, { objectApiName: WA_TEMPLATE_OBJECT })
    waTemplateMetadata;

    @wire(getPicklistValues, {
        recordTypeId: '$waTemplateMetadata.data.defaultRecordTypeId',
        fieldApiName: TEMPLATE_CATEGORY_FIELD
    })
    wiredCategoryPicklistValues({ data, error }) {
        if (data && data.values) {
            this.categoryOptions = [
                { label: 'All', value: '' },
                ...data.values.map(item => ({ label: item.label, value: item.value }))
            ];
        } else if (error) {
            console.error('Error fetching category picklist values: ', error);
        }
    }

    @wire(getPicklistValues, {
        recordTypeId: '$waTemplateMetadata.data.defaultRecordTypeId',
        fieldApiName: STATUS_FIELD
    })
    wiredStatusPicklistValues({ data, error }) {
        if (data && data.values) {
            const uniqueStatuses = data.values
                .filter(item => item.value !== 'Pending')
                .map(item => ({ label: item.label, value: item.value }));
            this.statusOptions = [
                { label: 'All', value: '' },
                ...uniqueStatuses
            ];
        } else if (error) {
            console.error('Error fetching status picklist values: ', error);
        }
    }

    fetchAllTemplate(showSpinner) {
        if (showSpinner) {
            this.isLoading = true;
        }
        getWhatsAppTemplates()
            .then(data => {
                try {
                    if (data) {
                        this.allRecords = data.map((record, index) => {
                            const rawStatus = record.Status__c || '';
                            let statusVal = rawStatus;
                            if (rawStatus?.toUpperCase() === 'PENDING') {
                                statusVal = 'In-Review';
                            }

                            let cooldownHours = 0;
                            let cooldownMins = 0;
                            let hasCooldown = false;
                            let cooldownBadgeText = '';

                            if (record.Last_Meta_Edit_Time__c) {
                                const lastEdit = new Date(record.Last_Meta_Edit_Time__c);
                                const cooldownEnd = new Date(lastEdit.getTime() + (24 * 60 * 60 * 1000));
                                const now = new Date();
                                if (now < cooldownEnd) {
                                    hasCooldown = true;
                                    const diffMs = cooldownEnd - now;
                                    const totalMins = Math.floor(diffMs / 60000);
                                    cooldownHours = Math.floor(totalMins / 60);
                                    cooldownMins = totalMins % 60;
                                    cooldownBadgeText = `${cooldownHours}h ${cooldownMins}m edit cooldown`;
                                }
                            }

                            // Calculate if editing this template is disabled and reason
                            let isEditDisabled = false;
                            let editDisabledReason = '';
                            const upperStatus = (statusVal || '').toUpperCase();

                            if (upperStatus === 'IN-REVIEW' || upperStatus === 'IN_REVIEW' || upperStatus === 'PENDING') {
                                isEditDisabled = true;
                                editDisabledReason = 'This template is currently under review by Meta and cannot be edited until approved or rejected.';
                            } else if (upperStatus === 'PENDING_DELETION') {
                                isEditDisabled = true;
                                editDisabledReason = 'This template is scheduled for deletion and cannot be edited.';
                            } else if (hasCooldown) {
                                isEditDisabled = true;
                                editDisabledReason = `Meta permits only 1 edit every 24 hours for approved templates. You can edit this template in ${cooldownHours} hr ${cooldownMins} min.`;
                            } else {
                                let editsUsed30Days = record.Edit_Count_30_Days__c || 0;
                                if (record.Edit_Timestamps_JSON__c) {
                                    try {
                                        const timestamps = JSON.parse(record.Edit_Timestamps_JSON__c);
                                        const thirtyDaysAgo = new Date(Date.now() - (30 * 24 * 60 * 60 * 1000));
                                        const active = timestamps.filter(t => new Date(t) >= thirtyDaysAgo);
                                        editsUsed30Days = active.length;
                                    } catch (e) {
                                        // ignore parse issue
                                    }
                                }
                                if (editsUsed30Days >= 10) {
                                    isEditDisabled = true;
                                    editDisabledReason = "This template has reached Meta's maximum limit of 10 edits in a rolling 30-day window.";
                                }
                            }

                            const editMenuItemClass = isEditDisabled
                                ? 'exp-action-menu-item exp-menu-item-disabled'
                                : 'exp-action-menu-item';
                            const editTitle = isEditDisabled ? editDisabledReason : 'Edit';

                            return {
                                ...record,
                                id: record.Id,
                                serialNumber: index + 1, 
                                Template_Name__c: this.handleEmptyValue(record.Template_Name__c),
                                Template_Category__c: this.handleEmptyValue(record.Template_Category__c),
                                LanguageLabel: this.handleEmptyValue(record.LanguageLabel),
                                Status__c: this.handleEmptyValue(statusVal),
                                Quality_Rating__c: record.Quality_Rating__c || '',
                                Rejection_Reason__c: record.Rejection_Reason__c || '',
                                hasCooldown,
                                cooldownBadgeText,
                                isEditDisabled,
                                editDisabledReason,
                                editMenuItemClass,
                                editTitle,
                                rawLastModifiedDate: record.LastModifiedDate,
                                rawCreatedDate: record.CreatedDate,
                                LastModifiedDate: this.formatDate(record.LastModifiedDate),
                                CreatedDate: this.formatDate(record.CreatedDate),
                                statusClass: this.getStatusClass(statusVal)
                            };
                        });
                        this.filteredRecords = [...this.allRecords];
                        this.sortData();
                        this.filterRecords();
                        this.currentPage = 1;
                        this.updateShownData();
                        this.isLoading = false;
                    }
                } catch (err) {
                    console.error('Unexpected error in fetchAllTemplate: ', err);
                    this.isLoading = false;
                }
            })
            .catch(error => {
                console.error('Error fetching WhatsApp templates: ', error);
                this.isLoading = false;
            });
    }

    showCreateTemplate() {
        this.manageTemplateId = null;
        this.isCloneMode = false;
        this.isManageTemplateView = true;
        this.dispatchEvent(new CustomEvent('templatenavigate', {
            bubbles: true,
            composed: true,
            detail: { title: 'Create Template', parentTitle: 'Message Templates' }
        }));
    }

    handleChange(event) {
        try {
            const fieldName = event.target.name; 
            const value = event.detail?.value !== undefined ? event.detail.value : event.target.value; 
        
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
                    this.searchInput = value;
                    break;
                default:
                    console.warn(`Unhandled field: ${fieldName}`);
                    break;
            }
            this.filterRecords();
        } catch (error) {
            console.error('Error while handling changes in the filter.', error);
        }
    }

    handleEmptyValue(value) {
        return (value !== null && value !== undefined && value !== '' && value !== 'null') ? value : '-';
    }

    formatDate(dateStr) {
        try {
            if (!dateStr) return '-';

            let formatdate = new Date(dateStr);

            const day = formatdate.getDate();
            const month = formatdate.getMonth() + 1;
            const year = formatdate.getFullYear();

            const paddedDay = day < 10 ? `0${day}` : day;
            const paddedMonth = month < 10 ? `0${month}` : month;

            let hours = formatdate.getHours();
            const minutes = formatdate.getMinutes();
            const ampm = hours >= 12 ? 'PM' : 'AM';

            hours = hours % 12;
            hours = hours ? hours : 12;
            const paddedMinutes = minutes < 10 ? `0${minutes}` : minutes;
            const paddedHours = hours < 10 ? `0${hours}` : hours;

            return `${paddedDay}/${paddedMonth}/${year} ${paddedHours}:${paddedMinutes} ${ampm}`;
        } catch (error) {
            console.error('Error in formatDate:', error);
            return '-';
        }
    }

    getStatusClass(status) {
        const base = 'status-badge ';
        const s = (status || '').toUpperCase();
        switch (s) {
            case 'ACTIVE-QUALITY PENDING':
            case 'APPROVED':
                return base + 'status-approved-class';
            case 'IN-REVIEW':
            case 'PENDING':
                return base + 'status-inreview-class';
            case 'REJECTED':
                return base + 'status-rejected-class';
            case 'DISABLED':
                return base + 'status-disabled-class';
            case 'DRAFT':
            default:
                return base + 'status-draft-class';
        }
    }

    filterRecords() {
        try {
            let filtered = [...this.allRecords];

            if (this.categoryValue) {
                filtered = filtered.filter(record => record.Template_Category__c === this.categoryValue);
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
                filtered = filtered.filter(record => new Date(record.rawCreatedDate || record.CreatedDate) >= fromDate);
            }
            if (this.statusValues && this.statusValues.length > 0) {
                filtered = filtered.filter(record => {
                    if (!record.Status__c) return false;
                    if (this.statusValues.includes(record.Status__c)) return true;
                    if (this.statusValues.includes('In-Review') && (record.Status__c === 'Pending' || record.Status__c === 'In-Review')) return true;
                    return false;
                });
            }
    
            if (this.searchInput) {
                const term = this.searchInput.toLowerCase();
                filtered = filtered.filter(record => 
                    record.Template_Name__c && record.Template_Name__c.toLowerCase().includes(term)
                );
            }
    
            this.filteredRecords = filtered;
            this.sortData();
            this.currentPage = 1;
            this.updateShownData();
        } catch (error) {
            this.showToastError('An error occurred while filtering the records.');
        }
    }

    updateShownData() {
        const startIndex = (this.currentPage - 1) * this.pageSize;
        const endIndex = Math.min(startIndex + this.pageSize, this.totalItems);
        const pagedList = this.filteredRecords.slice(startIndex, endIndex);
        this.visibleRecords = pagedList.map((item) => {
            const isActionMenuOpen = this.openActionMenuId === item.id;
            const openUpwards = isActionMenuOpen && this.openActionMenuUpwards;
            return {
                ...item,
                isActionMenuOpen,
                actionButtonClass: `exp-action-dots-btn ${isActionMenuOpen ? 'active' : ''}`,
                actionMenuClass: `exp-action-dropdown-menu ${openUpwards ? 'open-upwards' : 'open-downwards'}`,
                rowClass: `table-tr ${isActionMenuOpen ? 'has-open-menu' : ''}`
            };
        });
    }

    handlePageSizeChange(event) {
        this.pageSize = parseInt(event.target.value, 10);
        this.currentPage = 1;
        this.updateShownData();
    }

    handlePrevious() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.updateShownData();
        }
    }

    handleNext() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
            this.updateShownData();
        }
    }

    handlePageChange(event) {
        const selectedPage = parseInt(event.currentTarget.dataset.id, 10);
        if (selectedPage && selectedPage !== this.currentPage) {
            this.currentPage = selectedPage;
            this.updateShownData();
        }
    }

    showToastError(message) {
        const toastEvent = new ShowToastEvent({
            title: 'Error',
            message,
            variant: 'error'
        });
        this.dispatchEvent(toastEvent);
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

    sortClick(event) {
        try {
            const fieldName = event.currentTarget.dataset.id;
            if (!fieldName) return;
            if (this.sortField === fieldName) {
                this.sortOrder = this.sortOrder === 'asc' ? 'desc' : 'asc';
            } else {
                this.sortField = fieldName;
                this.sortOrder = 'asc';
            }
            this.sortData();
            this.updateSortIcons();
        } catch (error) {
            console.error('Error in sortClick --> ' + error);
        }
    }

    sortData() {
        try {
            this.filteredRecords = [...this.filteredRecords].sort((a, b) => {
                let aValue = a[this.sortField];
                let bValue = b[this.sortField];

                if (this.sortField === 'LastModifiedDate') {
                    aValue = a.rawLastModifiedDate ? new Date(a.rawLastModifiedDate) : (aValue ? new Date(aValue) : '');
                    bValue = b.rawLastModifiedDate ? new Date(b.rawLastModifiedDate) : (bValue ? new Date(bValue) : '');
                } else if (this.sortField === 'CreatedDate') {
                    aValue = a.rawCreatedDate ? new Date(a.rawCreatedDate) : (aValue ? new Date(aValue) : '');
                    bValue = b.rawCreatedDate ? new Date(b.rawCreatedDate) : (bValue ? new Date(bValue) : '');
                }

                if (aValue === undefined) aValue = '';
                if (bValue === undefined) bValue = '';

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

            this.filteredRecords = this.filteredRecords.map((record, index) => ({
                ...record,
                serialNumber: index + 1
            }));
            this.currentPage = 1;
            this.updateShownData();
        } catch (error) {
            console.error('Error in sortData --> ', error.stack);
        }
    }

    updateSortIcons() {
        try {
            const allIcons = this.template.querySelectorAll('.exp-arrow-icon');
            allIcons.forEach(icon => {
                icon.classList.remove('exp-rotate-asc', 'exp-rotate-desc');
            });

            const allHeaders = this.template.querySelectorAll('.exp-sorting-header');
            allHeaders.forEach(header => {
                header.classList.remove('active-sort');
            });

            const currentHeader = this.template.querySelector('[data-id="' + this.sortField + '"]');
            if (currentHeader) {
                currentHeader.classList.add('active-sort');
                const icon = currentHeader.querySelector('.exp-arrow-icon');
                if (icon) {
                    icon.classList.add(this.sortOrder === 'asc' ? 'exp-rotate-asc' : 'exp-rotate-desc');
                }
            }
        } catch (error) {
            console.error('Error in updateSortIcons --> ' + error);
        }
    }
}