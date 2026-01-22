import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { loadStyle } from 'lightning/platformResourceLoader';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';

export default class CustomDatatable extends NavigationMixin(LightningElement) {
    @api tableTitle = 'Data Table';
    @api tableColumns = [];
    @api recordKeyField = 'Id';
    @api enableRowSelection = false;
    @api enableColumnSorting = false;
    @api enableTablePagination = false;
    @api recordsPerPage = 10;
    @api hideSelectionColumn = false;
    @api maxSelectionLimit = 0; // 0 means unlimited
    @api defaultSortField = '';
    @api defaultSortDirection = 'asc';
    @api isDataLoading = false;
    @api hideTableFooter = false;
    @api headerActionButtons = [];
    @api rowActionButtons = [];
    @api linkFieldName = ''; // Field to make clickable for record navigation
    @api sObjectApiName = '';
    @api customTableClass = '';
    @api paginationVisiblePages = 5; // Number of pagination buttons to show
    @api enableSearch = false;
    @api searchPlaceholder = 'Search...';
    @api searchableFields = []; // Array of field names to search in
    
    // New properties for dynamic no data messages
    @api noDataTitle = 'No data found';
    @api noDataMessage = 'There are no records to display.';
    @api noDataIconName = 'utility:search';

    @track processedTableData = [];
    @track selectedTableRows = [];
    @track currentPageNumber = 1;
    @track sortFieldName = '';
    @track sortDirection = 'asc';
    @track totalSelectedRows = 0;
    @track searchTerm = '';

    // Internal tracking
    _originalTableData = [];
    _filteredTableData = []; // Property for filtered data
    _componentRendered = false;

    _tableData = [];

    @api 
    get tableData() {
        return this._tableData;
    }

    set tableData(value) {
        this._tableData = value || [];
        // Reinitialize when data changes and component is rendered
        if (this._componentRendered && this._tableData.length > 0) {
            this.initializeTableComponent();
        }
    }

    // Getters
    get hasTableData() {
        return this.processedTableData && this.processedTableData.length > 0;
    }

    get totalDataItems() {
        return this._filteredTableData.length;
    }

    get totalPaginationPages() {
        return Math.ceil(this.totalDataItems / this.recordsPerPage);
    }

    get isCurrentPageFirst() {
        return this.currentPageNumber === 1;
    }

    get isCurrentPageLast() {
        return this.currentPageNumber >= this.totalPaginationPages;
    }

    get currentPageData() {
        if (!this.enableTablePagination) {
            return this.processedTableData;
        }
        
        const startIndex = (this.currentPageNumber - 1) * this.recordsPerPage;
        const endIndex = startIndex + this.recordsPerPage;
        return this.processedTableData.slice(startIndex, endIndex);
    }

    get paginationNumbers() {
        const totalPages = this.totalPaginationPages;
        const currentPage = this.currentPageNumber;
        const visiblePages = this.paginationVisiblePages;
        let pages = [];

        if (totalPages <= visiblePages) {
            for (let i = 1; i <= totalPages; i++) {
                pages.push({
                    number: i,
                    isEllipsis: false,
                    buttonClass: `pagination-button ${i === currentPage ? 'active' : ''}`
                });
            }
        } else {
            // Always show first page
            pages.push({
                number: 1,
                isEllipsis: false,
                buttonClass: `pagination-button ${currentPage === 1 ? 'active' : ''}`
            });

            if (currentPage > 3) {
                pages.push({ isEllipsis: true });
            }

            // Show middle pages
            let start = Math.max(2, currentPage - 1);
            let end = Math.min(currentPage + 1, totalPages - 1);

            for (let i = start; i <= end; i++) {
                pages.push({
                    number: i,
                    isEllipsis: false,
                    buttonClass: `pagination-button ${i === currentPage ? 'active' : ''}`
                });
            }

            if (currentPage < totalPages - 2) {
                pages.push({ isEllipsis: true });
            }

            // Always show last page
            pages.push({
                number: totalPages,
                isEllipsis: false,
                buttonClass: `pagination-button ${currentPage === totalPages ? 'active' : ''}`
            });
        }

        return pages;
    }

    get isAllRowsSelected() {
        return this.processedTableData.length > 0 && this.processedTableData.every(item => item.isRowSelected);
    }

    get showNoDataMessage() {
        return !this.hasTableData && !this.isDataLoading;
    }

    get processedTableColumns() {
        return this.tableColumns.map(col => ({
            ...col,
            sortable: col.sortable !== false && this.enableColumnSorting,
            isSorted: col.fieldName === this.sortFieldName,
            sortDirection: col.fieldName === this.sortFieldName ? this.sortDirection : '',
        }));
    }

    get computedTableClass() {
        return `datatable-table ${this.customTableClass}`;
    }

    get containerClass() {
        return `custom-datatable-container ${this.customTableClass}-wrapper`;
    }

    get hasRowActions() {
        return this.rowActionButtons && this.rowActionButtons.length > 0;
    }

    get startRecord() {
        return (this.currentPageNumber - 1) * this.recordsPerPage + 1;
    }

    get endRecord() {
        return Math.min(this.currentPageNumber * this.recordsPerPage, this.totalDataItems);
    }

    @api
    getSelectedRows() {
        return this.selectedTableRows;
    }

    @api
    setSelectedRows(selectedIds) {
        try {
            this.processedTableData = this.processedTableData.map(item => ({
                ...item,
                isRowSelected: selectedIds.includes(item[this.recordKeyField])
            }));
            this.updateSelectedRowsData();
        } catch (error) {
            console.error('Error in setSelectedRows:', error);
        }
    }

    @api
    clearAllSelections() {
        this.processedTableData = this.processedTableData.map(item => ({
            ...item,
            isRowSelected: false
        }));
        this.updateSelectedRowsData();
    }

    @api
    refreshTableData(newData) {
        try {
            this._originalTableData = JSON.parse(JSON.stringify(newData || []));
            this._filteredTableData = [...this._originalTableData];
            this.searchTerm = ''; // Reset search
            this.processedTableData = this.addRowProperties(this._filteredTableData);
            this.currentPageNumber = 1;
            this.updateSelectedRowsData();
        } catch (error) {
            console.error('Error in refreshTableData:', error);
        }
    }

    @api
    clearSearch() {
        this.searchTerm = '';
        this.performSearch();
    }

    connectedCallback() {
        Promise.all([
            loadStyle(this, MulishFontCss)
        ])
        .then(() => {
            this.initializeTableComponent();
        })
        .catch(() => {
            this.displayToastMessage('Error', 'Error loading external CSS', 'error');
        });    
    }

    renderedCallback() {
        if (!this._componentRendered) {
            this._componentRendered = true;
            
            // Initialize with data if it exists after render
            if (this._tableData && this._tableData.length > 0) {
                this.initializeTableComponent();
            }
        }

        // Setup SVG icons on render to ensure they appear
        this.setupActionButtonsSvg();
    }

    /**
     * Initialize component with data
     */
    initializeTableComponent() {
        try {
            
            this._originalTableData = JSON.parse(JSON.stringify(this._tableData || []));
            this._filteredTableData = [...this._originalTableData]; // Initialize filtered data
            
            this.processedTableData = this.addRowProperties(this._filteredTableData);
            this.sortFieldName = this.defaultSortField;
            this.sortDirection = this.defaultSortDirection;
            
            if (this.sortFieldName) {
                this.performDataSorting();
            }
        } catch (error) {
            console.error('Error initializing custom datatable:', error);
        }
    }

    /**
     * Add required properties to each row
     */
    addRowProperties(dataArray) {
        return dataArray.map((item) => ({
            ...item,
            isRowSelected: false,
            recordId: item[this.recordKeyField],
            columnData: this.createColumnData(item)
        }));
    }

    /**
     * Create column data for each row to avoid computed property access
     */
    createColumnData(record) {
        return this.tableColumns.map(col => {
            const rawValue = this.getNestedFieldValue(record, col.fieldName);
            return {
                fieldName: col.fieldName,
                displayValue: rawValue || '',
                rawValue: rawValue,
                isRecordLink: col.isRecordLink || false,
                isCurrency: col.isCurrency || false,
                isDate: col.isDate || false,
                isDateTime: col.isDateTime || false, // New property for datetime fields
                isEmail: col.isEmail || false,
                isPhone: col.isPhone || false,
                isUrl: col.isUrl || false,
                isBoolean: col.isBoolean || false,
                isToggle: col.isToggle || false,
                isProgress: col.isProgress || false,
                isImage: col.isImage || false,                     
                isReadOnly: col.isReadOnly || false,
                hasSpecialType: col.isCurrency || col.isDate || col.isDateTime || col.isEmail || 
                               col.isPhone || col.isUrl || col.isBoolean || 
                               col.isToggle || col.isProgress || col.isImage   
            };
        });
    }

    /**
     * Setup SVG content for action buttons - Fixed Version
     */
    setupActionButtonsSvg() {
        try {
            // Use setTimeout to ensure DOM elements are rendered
            setTimeout(() => {
                // Setup header action buttons SVG
                if (this.headerActionButtons.length > 0) {
                    this.headerActionButtons.forEach((action) => {
                        if (action.svgContent) {
                            const headerButtons = this.template.querySelectorAll(`.header-action-btn[data-actionname="${action.name}"] .action-icon`);
                            headerButtons.forEach((iconElement) => {
                                if (iconElement) {
                                    iconElement.innerHTML = action.svgContent;
                                }
                            });
                        }
                    });
                }

                // Setup row action buttons SVG
                if (this.rowActionButtons.length > 0) {
                    this.rowActionButtons.forEach((action) => {
                        if (action.svgContent) {
                            const rowButtons = this.template.querySelectorAll(`.row-action-btn[data-actionname="${action.name}"] .action-icon`);
                            rowButtons.forEach((iconElement) => {
                                if (iconElement) {
                                    iconElement.innerHTML = action.svgContent;
                                }
                            });
                        }
                    });
                }
            }, 200);
            
        } catch (error) {
            console.error('Error setting up SVG icons:', error);
        }
    }


    // Event Handlers
    handleSelectAllRows(event) {
        try {
            const isChecked = event.target.checked;
            
            this.processedTableData = this.processedTableData.map(item => ({
                ...item,
                isRowSelected: isChecked
            }));

            this.updateSelectedRowsData();
            this.dispatchSelectionChangeEvent();
        } catch (error) {
            console.error('Error in handleSelectAllRows:', error);
        }
    }

    handleSingleRowSelection(event) {
        try {
            const rowIndex = parseInt(event.target.dataset.index);
            const isChecked = event.target.checked;

            // Check max selection limit
            if (isChecked && this.maxSelectionLimit > 0 && this.selectedTableRows.length >= this.maxSelectionLimit) {
                event.target.checked = false;
                this.displayToastMessage('Warning', `You can only select up to ${this.maxSelectionLimit} records`, 'warning');
                return;
            }

            // Find the actual row in processedTableData that corresponds to the current page data
            const actualRowIndex = (this.currentPageNumber - 1) * this.recordsPerPage + rowIndex;
            this.processedTableData[actualRowIndex].isRowSelected = isChecked;
            
            this.updateSelectedRowsData();
            this.dispatchSelectionChangeEvent();
        } catch (error) {
            console.error('Error in handleSingleRowSelection:', error);
        }
    }

    handleColumnSort(event) {
        try {
            if (!this.enableColumnSorting) return;
            
            const fieldName = event.currentTarget.dataset.fieldname;
            
            if (this.sortFieldName === fieldName) {
                this.sortDirection = this.sortDirection === 'asc' ? 'desc' : 'asc';
            } else {
                this.sortFieldName = fieldName;
                this.sortDirection = 'asc';
            }
            
            this.performDataSorting();
            this.updateSortIndicators();
            
            // Dispatch sort event
            this.dispatchEvent(new CustomEvent('sort', {
                detail: {
                    fieldName: this.sortFieldName,
                    sortDirection: this.sortDirection
                }
            }));
        } catch (error) {
            console.error('Error in handleColumnSort:', error);
        }
    }

    handleRowActionClick(event) {
        try {
            event.preventDefault();
            event.stopPropagation();
            
            // Get action name from the clicked element or its parent
            let actionName = event.target.dataset.actionname || 
                           event.currentTarget.dataset.actionname ||
                           event.target.closest('[data-actionname]')?.dataset.actionname;
            
            let rowIndex = event.target.dataset.rowindex || 
                          event.currentTarget.dataset.rowindex ||
                          event.target.closest('[data-rowindex]')?.dataset.rowindex;
            
            rowIndex = parseInt(rowIndex);
            const rowData = this.currentPageData[rowIndex];
                        
            this.dispatchEvent(new CustomEvent('rowaction', {
                detail: {
                    actionName: actionName,
                    action: { name: actionName },
                    row: rowData
                }
            }));
        } catch (error) {
            console.error('Error in handleRowActionClick:', error);
        }
    }

    handleHeaderAction(event) {
        try {
            event.preventDefault();
            event.stopPropagation();
            
            const actionName = event.target.dataset.actionname || 
                              event.currentTarget.dataset.actionname ||
                              event.target.closest('[data-actionname]')?.dataset.actionname;
                        
            this.dispatchEvent(new CustomEvent('headeraction', {
                detail: {
                    actionName: actionName,
                    action: { name: actionName }
                }
            }));
        } catch (error) {
            console.error('Error in handleHeaderAction:', error);
        }
    }

    handleRecordLinkNavigation(event) {
        try {
            if (!this.linkFieldName || !this.sObjectApiName) return;
            
            const recordId = event.currentTarget.dataset.recordid;
            
            this[NavigationMixin.GenerateUrl]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: recordId,
                    objectApiName: this.sObjectApiName,
                    actionName: 'view'
                }
            }).then(url => {
                // open in a new tab
                window.open(url, "_blank");
            });
        } catch (error) {
            console.error('Error in handleRecordLinkNavigation:', error);
        }
    }

    /**
     * Handle image click event
     */
    handleImageClick(event) {
        try {
            event.preventDefault();
            event.stopPropagation();
            
            const imageUrl = event.target.dataset.imageurl;
            const recordId = event.target.dataset.recordid;

            console.log('Image clicked:', imageUrl, recordId);
            
            
        } catch (error) {
            console.error('Error in handleImageClick:', error);
        }
    }

    /**
     * Handle image error event
     */
    handleImageError(event) {
        try {
            const img = event.target;
            img.style.display = 'none';
            
            // Create placeholder div
            const placeholder = document.createElement('div');
            placeholder.className = 'cell-image error';
            placeholder.innerHTML = 'No Image';
            placeholder.style.width = '40px';
            placeholder.style.height = '40px';
            placeholder.style.display = 'flex';
            placeholder.style.alignItems = 'center';
            placeholder.style.justifyContent = 'center';
            placeholder.style.fontSize = '10px';
            placeholder.style.color = '#666';
            placeholder.style.backgroundColor = '#f3f3f3';
            placeholder.style.border = '2px solid #c23934';
            placeholder.style.borderRadius = '6px';
            
            // Replace image with placeholder
            if (img.parentNode) {
                img.parentNode.appendChild(placeholder);
            }
            
        } catch (error) {
            console.error('Error in handleImageError:', error);
        }
    }

    // Pagination handlers
    handlePreviousPage() {
        if (this.currentPageNumber > 1) {
            this.currentPageNumber--;
            this.dispatchPaginationChangeEvent();
        }
    }

    handleNextPage() {
        if (this.currentPageNumber < this.totalPaginationPages) {
            this.currentPageNumber++;
            this.dispatchPaginationChangeEvent();
        }
    }

    handlePageNumberChange(event) {
        const selectedPage = parseInt(event.target.getAttribute('data-page'));
        if (selectedPage !== this.currentPageNumber) {
            this.currentPageNumber = selectedPage;
            this.dispatchPaginationChangeEvent();
        }
    }

    // Utility Methods
    performDataSorting() {
        try {
            this.processedTableData = [...this.processedTableData].sort((a, b) => {
                let aValue = this.getNestedFieldValue(a, this.sortFieldName);
                let bValue = this.getNestedFieldValue(b, this.sortFieldName);

                // Handle null/undefined values
                if (aValue === null || aValue === undefined) aValue = '';
                if (bValue === null || bValue === undefined) bValue = '';

                // Convert to lowercase for string comparison
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

                return this.sortDirection === 'asc' ? compare : -compare;
            });
            
            // Update sort indicators after sorting
            setTimeout(() => {
                this.updateSortIndicators();
            }, 100);
            
        } catch (error) {
            console.error('Error in performDataSorting:', error);
        }
    }

    getNestedFieldValue(record, fieldName) {
        try {
            if (fieldName.includes('.')) {
                const parts = fieldName.split('.');
                let value = record;
                for (let part of parts) {
                    value = value ? value[part] : null;
                }
                return value;
            }
            return record[fieldName];
        } catch (error) {
            return null;
        }
    }

    updateSelectedRowsData() {
        this.selectedTableRows = this.processedTableData.filter(item => item.isRowSelected);
        this.totalSelectedRows = this.selectedTableRows.length;
    }

    // Update the updateSortIndicators method to use new class names
    updateSortIndicators() {
        try {
            // Reset all sort headers and icons
            const allHeaders = this.template.querySelectorAll('.sortable-header');
            const allIcons = this.template.querySelectorAll('.sort-icon-container');
            
            // Remove all classes first
            allHeaders.forEach(header => {
                header.classList.remove('currently-sorted');
            });
            
            allIcons.forEach(icon => {
                icon.classList.remove('rotate-asc', 'rotate-desc');
            });

            // Apply classes to current sorted field
            const currentHeader = this.template.querySelector(`[data-fieldname="${this.sortFieldName}"]`);
            const currentIcon = this.template.querySelector(`[data-field="${this.sortFieldName}"]`);
            
            if (currentHeader && currentIcon) {
                // Add currently-sorted class to keep icon visible
                currentHeader.classList.add('currently-sorted');
                
                // Find the icon container and apply rotation
                const iconContainer = currentIcon.closest('.sort-icon-container');
                if (iconContainer) {
                    iconContainer.classList.add(this.sortDirection === 'asc' ? 'rotate-asc' : 'rotate-desc');
                }
            }
        } catch (error) {
            console.error('Error updating sort indicators:', error);
        }
    }

    // New search handler
    handleSearchChange(event) {
        try {
            this.searchTerm = event.target.value;
            this.performSearch();
            this.currentPageNumber = 1; // Reset to first page after search
            
            // Dispatch search event
            this.dispatchEvent(new CustomEvent('search', {
                detail: {
                    searchTerm: this.searchTerm,
                    filteredData: this._filteredTableData
                }
            }));
        } catch (error) {
            console.error('Error in handleSearchChange:', error);
        }
    }

    // New search method
    performSearch() {
        try {
            if (!this.searchTerm || this.searchTerm.trim() === '') {
                this._filteredTableData = [...this._originalTableData];
            } else {
                const searchLower = this.searchTerm.toLowerCase();
                const fieldsToSearch = this.searchableFields.length > 0 ? 
                    this.searchableFields : 
                    this.tableColumns.map(col => col.fieldName);

                this._filteredTableData = this._originalTableData.filter(record => {
                    return fieldsToSearch.some(fieldName => {
                        const fieldValue = this.getNestedFieldValue(record, fieldName);
                        if (fieldValue !== null && fieldValue !== undefined) {
                            return String(fieldValue).toLowerCase().includes(searchLower);
                        }
                        return false;
                    });
                });
            }

            // Re-process data with search results
            this.processedTableData = this.addRowProperties(this._filteredTableData);
            
            // Re-apply sorting if active
            if (this.sortFieldName) {
                this.performDataSorting();
            }

            // Update selected rows to maintain consistency
            this.updateSelectedRowsAfterFilter();
            
        } catch (error) {
            console.error('Error in performSearch:', error);
        }
    }

    // Method to update selected rows after filtering
    updateSelectedRowsAfterFilter() {
        try {
            const selectedIds = this.selectedTableRows.map(row => row[this.recordKeyField]);
            this.processedTableData = this.processedTableData.map(item => ({
                ...item,
                isRowSelected: selectedIds.includes(item[this.recordKeyField])
            }));
            this.updateSelectedRowsData();
        } catch (error) {
            console.error('Error in updateSelectedRowsAfterFilter:', error);
        }
    }

    /**
     * Handle toggle change event
     */
    handleToggleChange(event) {
        try {
            const fieldName = event.target.dataset.fieldname;
            const recordId = event.target.dataset.recordid;
            const newValue = event.target.checked;
            
            // Update the data in processedTableData
            this.processedTableData = this.processedTableData.map(row => {
                if (row.recordId === recordId) {
                    // Update the main record field
                    const updatedRow = { ...row };
                    this.setNestedFieldValue(updatedRow, fieldName, newValue);
                    
                    // Update the columnData for this field
                    updatedRow.columnData = updatedRow.columnData.map(col => {
                        if (col.fieldName === fieldName) {
                            return { ...col, rawValue: newValue, displayValue: newValue };
                        }
                        return col;
                    });
                    
                    return updatedRow;
                }
                return row;
            });
            
            // Also update the original and filtered data
            this._originalTableData = this._originalTableData.map(row => {
                if (row[this.recordKeyField] === recordId) {
                    const updatedRow = { ...row };
                    this.setNestedFieldValue(updatedRow, fieldName, newValue);
                    return updatedRow;
                }
                return row;
            });
            
            this._filteredTableData = this._filteredTableData.map(row => {
                if (row[this.recordKeyField] === recordId) {
                    const updatedRow = { ...row };
                    this.setNestedFieldValue(updatedRow, fieldName, newValue);
                    return updatedRow;
                }
                return row;
            });
            
            // Dispatch toggle change event
            this.dispatchEvent(new CustomEvent('togglechange', {
                detail: {
                    recordId: recordId,
                    fieldName: fieldName,
                    newValue: newValue,
                    record: this.processedTableData.find(row => row.recordId === recordId)
                }
            }));
            
        } catch (error) {
            console.error('Error in handleToggleChange:', error);
        }
    }

    /**
     * Set nested field value
     */
    setNestedFieldValue(record, fieldName, value) {
        try {
            if (fieldName.includes('.')) {
                const parts = fieldName.split('.');
                let current = record;
                for (let i = 0; i < parts.length - 1; i++) {
                    if (!current[parts[i]]) {
                        current[parts[i]] = {};
                    }
                    current = current[parts[i]];
                }
                current[parts[parts.length - 1]] = value;
            } else {
                record[fieldName] = value;
            }
        } catch (error) {
            console.error('Error setting nested field value:', error);
        }
    }

    // Event Dispatchers
    dispatchSelectionChangeEvent() {
        this.dispatchEvent(new CustomEvent('selectionchange', {
            detail: {
                selectedRows: this.selectedTableRows
            }
        }));
    }

    dispatchPaginationChangeEvent() {
        this.dispatchEvent(new CustomEvent('pagechange', {
            detail: {
                currentPage: this.currentPageNumber,
                pageSize: this.recordsPerPage
            }
        }));
    }

    // Toast utility
    displayToastMessage(title, message, variant) {
        const toastEvent = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(toastEvent);
    }
}