import { LightningElement, track } from 'lwc';
import getTemplates from '@salesforce/apex/TemplateBuilderController.getTemplates';
import deleteTemplate from '@salesforce/apex/TemplateBuilderController.deleteTemplate';
import { loadStyle } from 'lightning/platformResourceLoader';
import externalCss from '@salesforce/resourceUrl/templateCss';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import updateTemplateStatus from '@salesforce/apex/TemplateBuilderController.updateTemplateStatus';
import NoDataImage from '@salesforce/resourceUrl/NoDataImage';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
import FORM_FACTOR from '@salesforce/client/formFactor';

const PAGE_SIZE = 20;

export default class TemplateHomePage extends NavigationMixin(LightningElement) {
    @track currentPage = 1;
    @track templates = [];
    @track filteredTemplates = [];
    @track visibleTemplates = [];
    @track selectedTemplateId;
    @track selectedObjectName;
    @track isModalOpen = false;
    @track isLoading = false;
    @track isPreviewModal = false;
    @track visiblePages = 5;
    @track pageSize = 20;
    @track pageNumber = 1;
    @track templateType = '';
    @track selectedTempStatus = '';
    @track NoDataImageUrl = NoDataImage;
    @track sortField = 'LastModifiedDate';
    @track sortOrder = 'asc';
    @track showMoreFilters = false;
    @track selectedObject = '';
    @track selectedTemplateType = '';
    @track selectedTemplateStatus = '';
    @track dateField = '';
    @track dateFrom = '';
    @track dateTo = '';
    @track tableColumns = [
        {
            key: 'rowIndex',
            label: 'No.',
            fieldName: 'rowIndex',
            type: 'text',
            isSortable: false,
            class: 'sno',
            dataLabel: 'S.No.'
        },
        {
            key: 'MVEX__Template_Name__c',
            label: 'Template Name',
            fieldName: 'MVEX__Template_Name__c',
            type: 'text',
            isSortable: true,
            class: 'truncate_css',
            dataLabel: 'Template Name'
        },
        {
            key: 'status',
            label: 'Status',
            fieldName: 'isActive',
            type: 'status',
            isSortable: false,
            class: 'truncate_css',
            dataLabel: 'Status'
        },
        {
            key: 'MVEX__Object_Name__c',
            label: 'Object Name',
            fieldName: 'MVEX__Object_Name__c',
            type: 'text',
            isSortable: true,
            class: 'truncate_css',
            dataLabel: 'Object Name'
        },
        {
            key: 'MVEX__Template_pattern__c',
            label: 'Template Type',
            fieldName: 'MVEX__Template_pattern__c',
            type: 'text',
            isSortable: true,
            class: 'truncate_css',
            dataLabel: 'Template Type'
        },
        {
            key: 'MVEX__Subject__c',
            label: 'Subject',
            fieldName: 'MVEX__Subject__c',
            type: 'text',
            isSortable: false,
            class: 'truncate_css',
            dataLabel: 'Subject'
        },
        {
            key: 'MVEX__Description__c',
            label: 'Description',
            fieldName: 'MVEX__Description__c',
            type: 'text',
            isSortable: false,
            class: 'truncate_css',
            dataLabel: 'Description'
        },
        {
            key: 'CreatedDateformatted',
            label: 'Created Date',
            fieldName: 'CreatedDateformatted',
            type: 'date',
            isSortable: true,
            class: 'truncate_css',
            dataLabel: 'Created Date'
        },
        {
            key: 'LastModifiedDate',
            label: 'Last Modified Date',
            fieldName: 'LastModifiedDate',
            type: 'date',
            isSortable: true,
            class: 'truncate_css',
            dataLabel: 'Last Modified Date'
        },
        {
            key: 'actions',
            label: 'Action',
            fieldName: 'actions',
            type: 'action',
            isSortable: false,
            class: 'truncate_css',
            dataLabel: 'Actions'
        }
    ];

    constructor() {
        super();
        this.handleOutsideClick = this.handleOutsideClick.bind(this);
        // Add type flags to tableColumns
        this.tableColumns = this.tableColumns.map((col, index) => ({
            ...col,
            isText: col.type === 'text',
            isDate: col.type === 'date',
            isTextOrDate: col.type === 'text' || col.type === 'date',
            isStatus: col.type === 'status',
            isAction: col.type === 'action',
            // Add specific column flags for field value access in template
            isRowIndex: col.key === 'rowIndex',
            isTemplateName: col.key === 'MVEX__Template_Name__c',
            isObjectName: col.key === 'MVEX__Object_Name__c',
            isTemplatePattern: col.key === 'MVEX__Template_pattern__c',
            isSubject: col.key === 'MVEX__Subject__c',
            isDescription: col.key === 'MVEX__Description__c',
            isCreatedDate: col.key === 'CreatedDateformatted',
            isLastModifiedDate: col.key === 'LastModifiedDate'
        }));
    }
    
    get filterIconName() {
        return this.showMoreFilters ? 'utility:close' : 'utility:filter';
    }

    get objectOptions() {
        const uniqueObjects = [...new Set(this.templates.map(template => template.MVEX__Object_Name__c))];
        return [
            { label: 'Select Object...', value: '' },
            ...uniqueObjects.map(obj => ({ label: obj, value: obj }))
        ];
    }

    get templateTypeOptions() {
        return [
            { label: 'Select Template Type', value: '' },
            { label: 'PDF Template', value: 'PDF Template' },
            { label: 'Marketing Template', value: 'Marketing Template' }
        ];
    }

    get templateStatusOptions() {
        return [
            { label: 'Select Template Status', value: '' },
            { label: 'Active', value: 'Active' },
            { label: 'Inactive', value: 'Inactive' }
        ];
    }

    get dateFieldOptions() {
        return [
            { label: 'Select Date Field', value: '' },
            { label: 'Created Date', value: 'CreatedDate' },
            { label: 'Last Modified Date', value: 'LastModifiedDate' }
        ];
    }

    get totalItems() {
        return this.filteredTemplates.length;
    }

    get isMobileOrTablet() {
        return FORM_FACTOR === 'Small' || FORM_FACTOR === 'Medium';
    }

    /**
    * Method Name : totalPages
    * @description : set the totalpages count.
    * Created Date: 20/08/2024
    * Created By: Karan Singh
    */
    get totalPages() {
        return Math.ceil(this.filteredTemplates.length / this.pageSize);
    }

    // New getter to indicate when pagination has more than one page
    get totalPagesGreaterThanOne() {
        return this.totalPages > 1;
    }

    /**
    * Method Name : showEllipsis
    * @description : show the elipsis when the total pages is gretaer then the visible pages.
    * Created Date: 20/08/2024
    * Created By: Karan Singh
    */
    get showEllipsis() {
        return Math.ceil(this.totalItems / this.pageSize) > this.visiblePages;
    }

    /**
    * Method Name : isFirstPage
    * @description : check the current page is first.
    * Created Date: 20/08/2024
    * Created By: Karan Singh
    */
    get isFirstPage() {
        return this.currentPage === 1;
    }

    /**
    * Method Name : isLastPage
    * @description : check the current page is last.
    * Created Date: 20/08/2024
    * Created By: Karan Singh
    */
    get isLastPage() {
        return this.currentPage === Math.ceil(this.totalItems / this.pageSize);
    }

    /**
    * Method Name : startIndex
    * @description : set the start Index.
    * Created Date: 20/08/2024
    * Created By: Karan Singh
    */
    get startIndex() {
        return (this.currentPage - 1) * this.pageSize + 1;
    }

    /**
    * Method Name : endIndex
    * @description : set the end Index.
    * Created Date: 20/08/2024
    * Created By: Karan Singh
    */
    get endIndex() {
        return Math.min(this.currentPage * this.pageSize, this.totalItems);
    }

    /**
    * Method Name : pageNumbers
    * @description : set the list for page number in pagination.
    * Created Date: 20/08/2024
    * Created By: Karan Singh
    */
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
            console.log('Error pageNumbers -> ' + error);
            return null;
        }
    }


    /**
    * Method Name: connectedCallback
    * @description: Method to load static resource css and call fetchTemplates method
    * Created Date: 12/06/2024
    * Updated Date: 01/01/2025
    * Created By: Karan Singh
    * Updated By: Karan Singh
    */
    connectedCallback() {
        try {
            Promise.all([
                loadStyle(this, externalCss),
                loadStyle(this, MulishFontCss)
            ]).then(() => {
                console.log('External Css Loaded');
            }).catch(error => {
                console.log('Error occuring during loading external css', error);
            });
            this.fetchTemplates();
        } catch (error) {
            console.log('error in connectedCallback -> ' + error);
        }
    }

        /**
    * Method Name: renderedCallback
    * @description: Ensure sort icons are updated after DOM is rendered
    * Created Date: 25/03/2026
    * Created By: Kajal Tiwari
    */
    renderedCallback() {
        // Only update sort icons if we have data loaded
        if (this.templates && this.templates.length > 0) {
            this.updateSortIcons();
        }
    }

    get enhancedVisibleTemplates() {
        return this.visibleTemplates.map(template => {
            const enhanced = { ...template };
            // For each column, add a pre-computed property with the field value
            enhanced.col_rowIndex = template.rowIndex;
            enhanced.col_MVEX__Template_Name__c = template.MVEX__Template_Name__c;
            enhanced.col_MVEX__Object_Name__c = template.MVEX__Object_Name__c;
            enhanced.col_MVEX__Template_pattern__c = template.MVEX__Template_pattern__c;
            enhanced.col_MVEX__Subject__c = template.MVEX__Subject__c;
            enhanced.col_MVEX__Description__c = template.MVEX__Description__c;
            enhanced.col_CreatedDateformatted = template.CreatedDateformatted;
            enhanced.col_LastModifiedDate = template.LastModifiedDateformatted;
            enhanced.col_actions = template.actions;
            return enhanced;
        });
    }

    updateShownData() {
        try {
            const startIndex = (this.currentPage - 1) * this.pageSize;
            const endIndex = Math.min(startIndex + this.pageSize, this.totalItems);
            this.visibleTemplates = this.filteredTemplates.slice(startIndex, endIndex);
        } catch (error) {
            console.log('Error updateShownData -> ' + error);
        }
    }

    /**
    * Method Name : handlePrevious
    * @description : handle the previous button click in the pagination.
    * Created Date: 20/08/2024
    * Updated Date: 01/01/2025
    * Created By: Karan Singh
    * Updated By: Karan Singh
    */
    handlePrevious() {
        try {
            if (this.currentPage > 1) {
                this.currentPage--;
                this.updateShownData();
            }
        } catch (error) {
            console.log('Error handlePrevious -> ' + error);
        }
    }

    /**
    * Method Name : handleNext
    * @description : handle the next button click in the pagination.
    * Created Date: 20/08/2024
    * Updated Date: 01/01/2025
    * Created By: Karan Singh
    * Updated By: Karan Singh
    */
    handleNext() {
        try {
            if (this.currentPage < this.totalPages) {
                this.currentPage++;
                this.updateShownData();
            }
        } catch (error) {
            console.log('Error handleNext -> ' + error);
        }
    }

    /**
    * Method Name : handlePageChange
    * @description : handle the direct click on page number.
    * Created Date: 20/08/2024
    * Updated Date: 01/01/2025
    * Created By: Karan Singh
    * Updated By: Karan Singh
    */
    handlePageChange(event) {
        try {
            const selectedPage = parseInt(event.target.getAttribute('data-id'), 10);
            if (selectedPage !== this.currentPage) {
                this.currentPage = selectedPage;
                this.updateShownData();
            }
        } catch (error) {
            console.log('Error handlePageChange -> ' + error);
        }
    }

    /**
    * Method Name: fetchTemplates
    * @description: Method to call apex and get all the templates
    * Created Date: 12/06/2024
    * Updated Date: 01/01/2025
    * Created By: Karan Singh
    * Updated By: Karan Singh
    */
    fetchTemplates() {
        try {
            this.isLoading = true;
            getTemplates()
                .then(data => {
                    console.log('OUTPUT : ', data);
                    this.processTemplates(data);
                    this.isLoading = false;
                })
                .catch(error => {
                    console.log('Error in fetchTemplates ==> ', error);
                    this.isLoading = false;
                });
        } catch (error) {
            console.log('Error in fetchTemplates ==> ', error.stack);
            this.isLoading = false;
        }
    }

    /**
    * Method Name: processTemplates
    * @param {JSON} data : response from getTemplates
    * @description: helper method to add the extra column in the data and call pagination methods
    * Created Date: 12/06/2024
    * Updated Date: 01/01/2025
    * Created By: Karan Singh
    * Updated By: Karan Singh
    */
    processTemplates(data) {
        try {
            this.templates = data.map((template, index) => ({
                ...template,
                rowIndex: index + 1,
                isActive: template.MVEX__Template_Status__c,
                MVEX__Template_Name__c: this.handleEmptyValue(template.MVEX__Template_Name__c),
                MVEX__Object_Name__c: this.handleEmptyValue(template.MVEX__Object_Name__c),
                MVEX__Template_pattern__c: this.handleEmptyValue(template.MVEX__Template_pattern__c),
                MVEX__Subject__c: this.handleEmptyValue(template.MVEX__Subject__c),
                MVEX__Description__c: this.handleEmptyValue(template.MVEX__Description__c),
                CreatedDateformatted: this.formatDate(template.CreatedDate) || '-',
                LastModifiedDateformatted: this.formatDate(template.LastModifiedDate) || '-'
            }));
            this.filteredTemplates = [...this.templates];
            this.applyFilters();
        } catch (error) {
            console.log('Error in processTemplates ==> ', error.stack);
        }
    }

    /**
    * Method Name: handleEmptyValue
    * @param {Any} value : value to check
    * @return {String} : returns the value or '-' if empty
    * @description: helper method to replace null/undefined/empty values with '-'
    * Created Date: 18/02/2026
    * Created By: Karan Singh
    */
    handleEmptyValue(value) {
        return (value !== null && value !== undefined && value !== '' && value !== 'null') ? value : '-';
    }


    /**
    * Method Name: formatDate
    * @param {Date} date : date to be formated
    * @return {String} : date formated to display in js
    * @description: method to change the date formate to display in js
    * Created Date: 12/06/2024
    * Updated Date: 01/01/2025
    * Created By: Karan Singh
    * Updated By: Karan Singh
    */
    formatDate(dateStr) {
        try {
            if (!dateStr) return '-';
            
            let formatdate = new Date(dateStr);
            formatdate.setDate(formatdate.getDate());

            const day = formatdate.getDate();
            const month = formatdate.getMonth() + 1;
            const year = formatdate.getFullYear();

            const paddedDay = day < 10 ? `0${day}` : day;
            const paddedMonth = month < 10 ? `0${month}` : month;

            return `${paddedDay}/${paddedMonth}/${year}`;
        } catch (error) {
            console.log('Error in formatDate ==> ', error.stack);
            return '-';
        }
    }


    /**
    * Method Name: handleSearch
    * @description: method search the template based on the label of that template
    * Created Date: 12/06/2024
    * Created By: Karan Singh
    */
    handleSearch(event) {
        try {
            const searchTerm = event.target.value.toLowerCase();

            this.filteredTemplates = this.templates.filter(template =>
                template.MVEX__Template_Name__c && template.MVEX__Template_Name__c.toLowerCase().includes(searchTerm)
            );
            this.filteredTemplates = this.filteredTemplates.map((template, index) => ({
                ...template,
                rowIndex: index + 1,
            }));
            this.currentPage = 1;
            
            this.updateShownData();
            this.sortData();
        } catch (error) {
            console.log('Error in handleSearch ==> ', error.stack);
        }
    }

    /**
    * Method Name: handleStatusChange
    * @description: method to change the status of the template in ui based on toggle effect
    * Created Date: 12/06/2024
    * Created By: Karan Singh
    */
    handleStatusChange(event) {
        try {
            const templateId = event.target.dataset.id;
            const isActive = event.target.checked;
            updateTemplateStatus({ templateId: templateId, status: isActive })
                .then(() => {
                    const template = this.templates.find(tmpl => tmpl.Id === templateId);
                    if (template) {
                        template.isActive = isActive;
                        template.MVEX__Template_Status__c = isActive ? 'Active' : 'Inactive';
                        this.filteredTemplates = [...this.templates];
                        this.applyFilters();
                        this.showToast('Status Change', `Template status changed to: ${template.MVEX__Template_Status__c}`, 'success');
                    }
                })
                .catch(error => {
                    this.showToast('Error', `Error updating template status: ${error.body.message}`, 'error');
                });
        } catch (error) {
            console.log('Error in handleStatusChange ==> ', error.stack);
        }
    }

    /**
    * Method Name: handleModalClose
    * @description: method to close the modal
    * Created Date: 12/06/2024
    * Created By: Karan Singh
    */
    handleModalClose() {
        try {
            this.isModalOpen = false;
        } catch (error) {
            console.log('Error in handleModalClose ==> ', error.stack);
        }
    }

    /**
    * Method Name: handlePreview
    * @description: method to preview component(ui is pending)
    * Created Date: 12/06/2024
    * Created By: Karan Singh
    */
    handlePreview(event) {
        try {
            this.selectedObjectName = event.currentTarget.dataset.objectapi;
            this.selectedTemplateId = event.currentTarget.dataset.id;
            this.templateType = event.currentTarget.dataset.type;
            this.selectedTempStatus = event.currentTarget.dataset.status;
            this.isPreviewModal = true;
        } catch (error) {
            console.log('Error in handlePreview ==> ', error.stack);
        }
    }

    /**
    * Method Name: handleEdit
    * @description: method to call Template_Editor tab with sending data
    * Created Date: 12/06/2024
    * Created By: Karan Singh
    */
    handleEdit(event) {
        try {
            const templateId = event.currentTarget.dataset.id;
            const objectName = event.currentTarget.dataset.objectapi;
            const templatetype = event.currentTarget.dataset.type;

            let componentDef = {
                componentDef: "MVEX:templateEditor",
                attributes: {
                    objectName: objectName,
                    templateId: templateId,
                    templateType: templatetype
                }
            };
            let encodedComponentDef = btoa(JSON.stringify(componentDef));
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: '/one/one.app#' + encodedComponentDef
                }
            });
        } catch (error) {
            console.log('Error in handleEdit ==> ', error.stack);
        }
    }

    /**
    * Method Name: handleDelete
    * @description: method to delete the template from the table
    * Created Date: 12/06/2024
    * Created By: Karan Singh
    */
    handleDelete(event) {
        this.showMessagePopup('Warning', 'Delete Template', 'Are you sure you want to delete this Template? This action cannot be undone.');
        this.selectedTemplateId = event.currentTarget.dataset.id;
    }

    /**
    * Method Name: handleAdd
    * @description: method to open the modal for the adding template
    * Created Date: 12/06/2024
    * Created By: Karan Singh
    */
    handleAdd() {
        try {
            this.isModalOpen = true;
        } catch (error) {
            console.log('Error in handleAdd ==> ', error.stack);
        }
    }

    /**
    * Method Name: showToast
    * @description: method to show toast message
    * Created Date: 12/06/2024
    * Created By: Karan Singh
    */
    showToast(title, message, variant) {
        try {
            if (typeof window !== 'undefined') {
                const event = new ShowToastEvent({
                    title: title,
                    message: message,
                    variant: variant,
                });
                this.dispatchEvent(event);
            }
        } catch (error) {
            console.log('Error in showToast ->', error.stack);
        }
    }

    /**
    * Method Name: handleCloseModal
    * @description: method to close modal
    * Created Date: 12/06/2024
    * Created By: Karan Singh
    */
    handleCloseModal() {
        this.isPreviewModal = false;
    }

    /**
    * Method Name: backToControlCenter
    * @description: method to go back in the control center
    * Created Date: 12/06/2024
    * Created By: Karan Singh
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
            console.log('error in backToControlCenter --> ', error);
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
            this.filteredTemplates = [...this.filteredTemplates].sort((a, b) => {
                let aValue = a[this.sortField];
                let bValue = b[this.sortField];

                if (aValue === undefined) aValue = '';
                if (bValue === undefined) bValue = '';

                if (typeof aValue === 'string' && typeof bValue === 'string') {
                    aValue = aValue.toLowerCase();
                    bValue = bValue.toLowerCase();
                }

                if (this.sortField === 'CreatedDate') {
                    aValue = new Date(aValue);
                    bValue = new Date(bValue);
                }

                let compare = 0;
                if (aValue > bValue) {
                    compare = 1;
                } else if (aValue < bValue) {
                    compare = -1;
                }

                return this.sortOrder === 'asc' ? compare : -compare;
            });

            this.filteredTemplates = this.filteredTemplates.map((template, index) => ({
                ...template,
                rowIndex: index + 1
            }));

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
            this.isLoading = true;
            const templateId = this.selectedTemplateId;
            const templateIndex = this.templates.findIndex(tmpl => tmpl.Id === templateId);
            if (templateIndex !== -1) {
                const template = this.templates[templateIndex];
                deleteTemplate({ templateId: template.Id })
                    .then(() => {
                        this.templates.splice(templateIndex, 1);
                        this.templates.forEach((tmpl, index) => { tmpl.rowIndex = index + 1; });
                        this.filteredTemplates = [...this.templates];
                        this.applyFilters();
                        const startIndex = (this.currentPage - 1) * PAGE_SIZE;
                        if (startIndex >= this.filteredTemplates.length && this.currentPage > 1) {
                            this.currentPage--;
                        }
                        this.updateShownData();
                        this.isLoading = false;
                        this.showToast('Success', `Template '${template.MVEX__Template_Name__c}' deleted successfully.`, 'success');
                        this.selectedTemplateId = null;
                    })
                    .catch(error => {
                        this.isLoading = false;
                        this.showToast('Error', `Error deleting template: ${error.body.message}`, 'error');
                        this.selectedTemplateId = null;
                    });
            }
        } else {
            this.selectedTemplateId = null;
        }
    }

    toggleMoreFilters(event) {
        if (event) event.stopPropagation();
        this.showMoreFilters = !this.showMoreFilters;
        if (this.showMoreFilters) {
            document.addEventListener('click', this.handleOutsideClick);
        } else {
            document.removeEventListener('click', this.handleOutsideClick);
        }
    }

    handleFilterContainerClick(event) {
        event.stopPropagation(); // Prevent clicks within the filter container from closing the dropdown
    }

    handleOutsideClick(event) {
        const dropdown = this.template.querySelector('.filter-dropdown-box');
        const filterIcon = this.template.querySelector('.filter-icon-container');
        
        // Only close if the click is outside both the dropdown and filter icon
        if (dropdown && filterIcon && !event.composedPath().includes(dropdown) && !event.composedPath().includes(filterIcon)) {
            this.showMoreFilters = false;
            document.removeEventListener('click', this.handleOutsideClick);
        }
    }

    handleObjectFilterChange(event) {
        event.stopPropagation();
        this.selectedObject = event.detail.value;
    }

    handleTemplateTypeFilterChange(event) {
        event.stopPropagation();
        this.selectedTemplateType = event.detail.value;
    }

    handleTemplateStatusFilterChange(event) {
        event.stopPropagation();
        this.selectedTemplateStatus = event.detail.value;
    }

    handleDateFieldChange(event) {
        event.stopPropagation();
        this.dateField = event.detail.value;
        this.dateFrom = '';
        this.dateTo = '';
    }

    handleDateFromChange(event) {
        event.stopPropagation();
        this.dateFrom = event.target.value;
    }

    handleDateToChange(event) {
        event.stopPropagation();
        this.dateTo = event.target.value;
    }

    setThisWeek(event) {
        event.stopPropagation();
        const today = new Date();
        const start = new Date(today.setDate(today.getDate() - today.getDay()));
        const end = new Date(today.setDate(today.getDate() - today.getDay() + 6));
        this.dateFrom = this.formatDateInput(start);
        this.dateTo = this.formatDateInput(end);
    }

    setLastWeek(event) {
        event.stopPropagation();
        const today = new Date();
        const start = new Date(today.setDate(today.getDate() - today.getDay() - 7));
        const end = new Date(today.setDate(today.getDate() - today.getDay() - 1));
        this.dateFrom = this.formatDateInput(start);
        this.dateTo = this.formatDateInput(end);
    }

    setThisMonth(event) {
        event.stopPropagation();
        const today = new Date();
        const start = new Date(today.getFullYear(), today.getMonth(), 1);
        const end = new Date(today.getFullYear(), today.getMonth() + 1, 0);
        this.dateFrom = this.formatDateInput(start);
        this.dateTo = this.formatDateInput(end);
    }

    setLastMonth(event) {
        event.stopPropagation();
        const today = new Date();
        const start = new Date(today.getFullYear(), today.getMonth() - 1, 1);
        const end = new Date(today.getFullYear(), today.getMonth(), 0);
        this.dateFrom = this.formatDateInput(start);
        this.dateTo = this.formatDateInput(end);
    }

    formatDateInput(date) {
        const year = date.getFullYear();
        const month = String(date.getMonth() + 1).padStart(2, '0');
        const day = String(date.getDate()).padStart(2, '0');
        return `${year}-${month}-${day}`;
    }

    clearFilters(event) {
        event.stopPropagation();
        this.sortField = 'LastModifiedDate';
        this.sortOrder = 'asc';
        this.selectedObject = '';
        this.selectedTemplateType = '';
        this.selectedTemplateStatus = '';
        this.dateField = 'LastModifiedDate';
        this.dateFrom = '';
        this.dateTo = '';
    }

    applyFilters(event) {
        if (event) event.stopPropagation();
        this.filteredTemplates = [...this.templates].filter(template => {
            let matches = true;

            if (this.selectedObject && template.MVEX__Object_Name__c !== this.selectedObject) {
                matches = false;
            }
            if (this.selectedTemplateType && template.MVEX__Template_pattern__c !== this.selectedTemplateType) {
                matches = false;
            }
            if (this.selectedTemplateStatus) {
                const statusString = template.MVEX__Template_Status__c === true || template.MVEX__Template_Status__c === 'Active' ? 'Active' : 'Inactive';
                if (statusString !== this.selectedTemplateStatus) {
                    matches = false;
                }
            }
            if (this.dateFrom && this.dateTo) {
                const templateDate = new Date(template[this.dateField]);
                const fromDate = new Date(this.dateFrom);
                const toDate = new Date(this.dateTo);
                if (templateDate < fromDate || templateDate > toDate) {
                    matches = false;
                }
            }

            return matches;
        });

        this.sortData();
        this.currentPage = 1;
        this.updateShownData();
        this.showMoreFilters = false;
        document.removeEventListener('click', this.handleOutsideClick);
    }

    isColumnTypeText(columnType) {
        return columnType === 'text';
    }

    isColumnTypeDate(columnType) {
        return columnType === 'date';
    }

    isColumnTypeStatus(columnType) {
        return columnType === 'status';
    }

    isColumnTypeAction(columnType) {
        return columnType === 'action';
    }

    isTextType(columnType) {
        return columnType === 'text';
    }

    isDateType(columnType) {
        return columnType === 'date';
    }

    isStatusType(columnType) {
        return columnType === 'status';
    }

    isActionType(columnType) {
        return columnType === 'action';
    }

    getTableRowsWithTypes() {
        return this.visibleTemplates.map(template => {
            const columns = this.tableColumns.map(col => ({
                ...col,
                columnId: col.key,
                isTextOrDate: col.type === 'text' || col.type === 'date',
                isStatus: col.type === 'status',
                isAction: col.type === 'action',
                value: template[col.fieldName]
            }));
            return {
                ...template,
                columns: columns
            };
        });
    }

    disconnectedCallback() {
        document.removeEventListener('click', this.handleOutsideClick);
    }
}