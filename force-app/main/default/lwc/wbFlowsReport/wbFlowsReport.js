import { LightningElement, track, api } from 'lwc';
import getWhatsAppFlowById from '@salesforce/apex/WhatsAppFlowController.getWhatsAppFlowById';
import getFlowSubmissionByFlowId from '@salesforce/apex/WhatsAppFlowController.getFlowSubmissionByFlowId';
import { loadStyle } from 'lightning/platformResourceLoader';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
import FORM_FACTOR from '@salesforce/client/formFactor';

export default class WbFlowsReport extends LightningElement {
    @api selectedFlowId;
    @api selectedFlowName;

    @track recordId;
    @track flowDetails;
    @track record;
    @track paginatedData = [];
    @track filteredData = [];
    @track currentPage = 1;
    @track pageSize = 15;
    @track visiblePages = 5;
    @track flowReport = true;
    @track isLoading = false;
    @track searchTerm = '';
    @track allData = [];
    @track expandedRows = {};

    // Sorting properties for Flow Report
    @track sortField = 'CreatedDate';
    @track sortOrder = 'desc';

    connectedCallback() {
        loadStyle(this, MulishFontCss);
        this.fetchFlowDetailsById();
    }

    get showNoRecordsMessage() {
        return this.filteredData.length === 0;
    }

    get searchPlaceholder() {
        return 'Search record by Name or Phone...';
    }

    get isMobileOrTablet() {
        return FORM_FACTOR === 'Small' || FORM_FACTOR === 'Medium';
    }

    // --- Flow Report Pagination ---
    get totalItems() {
        return this.filteredData.length;
    }

    get totalPages() {
        return Math.ceil(this.totalItems / this.pageSize) || 1;
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
            console.error('Error in getPageNumbers :: ', error);
            return null;
        }
    }

    get isFirstPage() {
        return this.currentPage === 1;
    }

    get isLastPage() {
        return this.currentPage === this.totalPages || this.totalPages === 0;
    }

    get showPagination() {
        return this.totalPages > 1;
    }

    fetchFlowDetailsById() {
        this.isLoading = true;
        getWhatsAppFlowById({ flowId: this.selectedFlowId })
            .then(result => {
                if (result && result.length > 0) {
                    this.flowDetails = result[0];
                    this.recordId = this.flowDetails.Id;
                }
                this.fetchFlowReportById();
            })
            .catch((error) => {
                console.error('Error fetching flow details:', error);
                this.isLoading = false;
            });
    }

    fetchFlowReportById() {
        this.isLoading = true;
        getFlowSubmissionByFlowId({ flowId: this.recordId })
            .then(result => {
                this.allData = result.map((item, index) => {
                    let parsedDetails = [];
                    let rowDetailIndex = 1;

                    try {
                        if (item.MVEX__Flow_Response_Mapping__c) {
                            const parsedJson = JSON.parse(item.MVEX__Flow_Response_Mapping__c);
                            for (const key in parsedJson) {
                                const value = parsedJson[key];
                                const parts = key.split(' - ');
                                const flowScreen = parts[0]?.trim() || '';
                                let flowField = parts[1]?.trim() || '';
                                flowField = flowField.replace(/[:\-]\s*$/, '');
                                
                                parsedDetails.push({
                                    id: `${item.Id}-${rowDetailIndex}`,
                                    flowScreen,
                                    flowField,
                                    userInput: Array.isArray(value) ? value.join(', ') : value,
                                    index: rowDetailIndex++
                                });
                            }
                        }
                    } catch (parseError) {
                        console.error('Error parsing Flow_Response_Mapping__c JSON:', parseError);
                    }

                    return {
                        ...item,
                        details: parsedDetails,
                        CreatedDate: this.formatDate(item.CreatedDate),
                        index: index + 1,
                        isExpanded: this.expandedRows[item.Id] || false,
                        accordionKey: `${item.Id}-accordion`
                    };
                });
                
                this.data = [...this.allData];
                this.applySearch(); // applySearch will also sort and then update data
            })
            .catch((error) => {
                console.error('Error fetching flow report:', error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    updateShownData() {
        try {
            const startIndex = (this.currentPage - 1) * this.pageSize;
            const endIndex = Math.min(startIndex + this.pageSize, this.totalItems);
            let rowIdx = 1;
            
            this.paginatedData = this.filteredData.slice(startIndex, endIndex).map((item, index) => ({
                ...item,
                isExpanded: this.expandedRows[item.Id] || false,
                rowClass: index % 2 === 0 ? 'parent-row even-row' : 'parent-row odd-row',
                index: startIndex + rowIdx++
            }));
            
            // Use setTimeout to ensure DOM is updated before updating sort icons
            setTimeout(() => {
                this.updateSortIcons();
            }, 0);
        } catch (error) {
            console.error('Error updating shown data:', error);
        }
    }

    handlePrevious() {
        try {
            if (this.currentPage > 1) {
                this.currentPage--;
                this.updateShownData();
            }
        } catch (error) {
            console.error('Error navigating to previous page:', error);
        }
    }

    handleNext() {
        try {
            if (this.currentPage < this.totalPages) {
                this.currentPage++;
                this.updateShownData();
            }
        } catch (error) {
            console.error('Error navigating pages:', error);
        }
    }

    handlePageChange(event) {
        try {
            const selectedPage = parseInt(event.target.getAttribute('data-id'), 10);
            if (selectedPage !== this.currentPage) {
                this.currentPage = selectedPage;
                this.updateShownData();
            }
        } catch (error) {
            console.error('Error navigating pages:', error);
        }
    }

    handleBack() {
        if (this.flowReport) {
            this.flowReport = false;
            this.record = null;
            this.paginatedData = [];
        }
    }

    handleNameClick(event) {
        try {
            const recordId = event.currentTarget.dataset.recordId;
            if (this.expandedRows[recordId]) {
                this.expandedRows = { ...this.expandedRows, [recordId]: false };
            } else {
                this.expandedRows = { ...this.expandedRows, [recordId]: true };
            }
            this.updateShownData();
        } catch (error) {
            console.error('Error in handleNameClick:', error);
        }
    }

    handleSearch(event) {
        try {
            this.searchTerm = event.target.value;
            this.currentPage = 1;
            this.applySearch();
        } catch (error) {
            console.error('Error in handleSearch:', error);
        }
    }

    applySearch() {
        try {
            if (!this.searchTerm || this.searchTerm.trim() === '') {
                this.filteredData = [...this.allData];
            } else {
                const searchTermLower = this.searchTerm.toLowerCase();
                this.filteredData = this.allData.filter(item => {
                    const name = (item.MVEX__Submitter_Name__c || '').toLowerCase();
                    const phone = (item.MVEX__Submitter_Phone__c || '').toLowerCase();
                    return name.includes(searchTermLower) || phone.includes(searchTermLower);
                });
            }
            this.sortData(); // Apply sort after search
        } catch (error) {
            console.error('Error in applySearch:', error);
        }
    }

    formatDate(dateString) {
        if (dateString) {
            const date = new Date(dateString);
            return date.toLocaleDateString('en-GB', {
                day: 'numeric',
                month: 'short',
                year: 'numeric'
            });
        }
    }

    /**
     * Sorting Logic for Flow Report
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
        } catch (error) {
            console.error('Error in sortClick --> ', error);
        }
    }

    sortData() {
        try {
            this.filteredData = [...this.filteredData].sort((a, b) => {
                let aValue = a[this.sortField];
                let bValue = b[this.sortField];

                if (aValue === undefined || aValue === null) aValue = '';
                if (bValue === undefined || bValue === null) bValue = '';

                if (this.sortField === 'CreatedDate') {
                    // CreatedDate comes formatted from formatDate, but it's simpler to sort using raw date object if we parse.
                    // Or we can rely on standard JS sorting since formatting preserves parts, but MM/DD/YYYY might fail.
                    // Thus, original string sorting or parsing is required.
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

            this.currentPage = 1;
            this.updateShownData();
        } catch (error) {
            console.error('Error in sortData --> ', error);
        }
    }

    updateSortIcons() {
        try {
            const allIcons = this.template.querySelectorAll('.table-content .slds-icon-utility-arrowdown svg');
            allIcons.forEach(icon => {
                icon.classList.remove('rotate-asc', 'rotate-desc');
            });

            const allHeaders = this.template.querySelectorAll('.table-content .sorting_header');
            allHeaders.forEach(header => {
                header.classList.remove('active-sort');
            });

            if (this.sortField) {
                const currentHeader = this.template.querySelector(`.table-content [data-id="${this.sortField}"]`);
                if (currentHeader) {
                    currentHeader.classList.add('active-sort');
                    const icon = currentHeader.querySelector('svg');
                    if (icon) {
                        icon.classList.add(this.sortOrder === 'asc' ? 'rotate-asc' : 'rotate-desc');
                    }
                }
            }
        } catch (error) {
            console.error('Error in updateSortIcons --> ', error);
        }
    }
}
