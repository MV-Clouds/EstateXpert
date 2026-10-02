import { LightningElement, track, api, wire } from "lwc";
import fetchListingAndImages from "@salesforce/apex/ImageAndMediaController.fetchListingAndImages";
import deletelistingmedia from "@salesforce/apex/ImageAndMediaController.deletelistingmedia";
import { publish, MessageContext } from 'lightning/messageService';
import Refresh_msg from '@salesforce/messageChannel/refreshImagesChannel__c';
import { NavigationMixin } from "lightning/navigation";
import updatePropertyFileRecords from '@salesforce/apex/ImageAndMediaController.updatePropertyFileRecords';
import getS3ConfigSettings from "@salesforce/apex/ImageAndMediaController.getS3ConfigSettings";
import { loadStyle, loadScript } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import AWS_SDK from "@salesforce/resourceUrl/AWSSDK";
import placeholderImage from '@salesforce/resourceUrl/placeholderImage';
import globalStyles from '@salesforce/resourceUrl/globalStyles';
import { errorDebugger } from "c/globalProperties";
import FORM_FACTOR from '@salesforce/client/formFactor';

export default class ImagesAndMedia extends NavigationMixin(LightningElement) {
    placeholderImage = placeholderImage;
    @api recordId;
    @track showSpinner = true;
    @track data = [];
    @track isData = false;
    @track isPopup = false;
    @track isEdit = false;
    @track isDeleteAll = false;
    @track recIdToDelete;
    @track isdelete = false;
    @track recIdToUpdate = [];
    @track currentImgName;
    @track imgOldName = [];
    @track exposeData = [];
    @track websiteData = [];
    @track portalData = [];
    @track sortOn = [];
    @track propertyId;
    @track eventImgName;
    @track floorplanChecked = false;
    @track virtualTourChecked = false;
    @track tourChecked = false;
    @track interiorChecked = false;
    @track exteriorChecked = false;
    @track picklistValues = [];
    @track finalPicklistValues = [];
    @track disabledDelete = true;
    @track fetchedData = [];
    @track selectedTags = [];
    @track selectedStatus = [];
    @track currentPage = 1;
    @track pageSize = 20;
    visiblePages = 5;

    constructor() {
        super();
        loadStyle(this, globalStyles);
    }

    get totalItems() {
        return this.data ? this.data.length : 0;
    }

    get totalPages() {
        return Math.ceil(this.totalItems / this.pageSize) || 1;
    }

    get isFirstPage() {
        return this.currentPage === 1;
    }

    get isLastPage() {
        return this.currentPage >= this.totalPages;
    }

    get startIndex() {
        return this.totalItems === 0 ? 0 : (this.currentPage - 1) * this.pageSize + 1;
    }

    get endIndex() {
        return Math.min(this.currentPage * this.pageSize, this.totalItems);
    }

    get recordCountInfo() {
        if (this.totalItems === 0) {
            return 'Showing 0 records';
        }
        return `Showing ${this.startIndex} - ${this.endIndex} of ${this.totalItems}`;
    }

    get pageSizeOptions() {
        const sizes = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100];
        return sizes.map(size => ({
            label: String(size),
            value: size,
            isSelected: this.pageSize === size
        }));
    }

    get pagedData() {
        if (!this.data || this.data.length === 0) {
            return [];
        }
        const startIndex = (this.currentPage - 1) * this.pageSize;
        const endIndex = startIndex + this.pageSize;
        return this.data.slice(startIndex, endIndex);
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
                    pages.push({ isEllipsis: true });
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
                    pages.push({ isEllipsis: true });
                }

                pages.push({
                    number: totalPages,
                    isEllipsis: false,
                    className: `exp-pagination-button ${currentPage === totalPages ? 'active' : ''}`
                });
            }

            return pages;
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'pageNumbers', error, 'warn', 'Error in pageNumbers');
            return [];
        }
    }

    handlePrevious() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.scrollToTop();
        }
    }

    handleNext() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
            this.scrollToTop();
        }
    }

    handlePageChange(event) {
        const selectedPage = parseInt(event.target.getAttribute('data-id'), 10);
        if (selectedPage && selectedPage !== this.currentPage) {
            this.currentPage = selectedPage;
            this.scrollToTop();
        }
    }

    handlePageSizeChange(event) {
        const value = parseInt(event.target.value, 10);
        if (!isNaN(value) && this.pageSize !== value) {
            this.pageSize = value;
            this.currentPage = 1;
            this.scrollToTop();
        }
    }

    scrollToTop() {
        try {
            const tableContainer = this.template.querySelector('.exp-table-content');
            if (tableContainer) {
                tableContainer.scrollTop = 0;
            }
        } catch (error) {
            console.error('Error scrolling to top:', error);
        }
    }

    get tagOptions() {
        return [
            { label: 'Floorplan', value: 'Floorplan' },
            { label: 'Virtual Tour', value: 'Virtual Tour' },
            { label: '360tour', value: '360tour' },
            { label: 'Interior', value: 'Interior' },
            { label: 'Exterior', value: 'Exterior' }
        ];
    }

    get statusOptions() {
        return [
            { label: 'Is On Expose', value: 'MVEX__IsOnExpose__c' },
            { label: 'Is On Website', value: 'MVEX__IsOnWebsite__c' },
            { label: 'Is On Portal Feed', value: 'MVEX__IsOnPortalFeed__c' }
        ];
    }

    handleTagsChange(event) {
        this.selectedTags = event.detail.value;
    }

    handleStatusChange(event) {
        this.selectedStatus = event.detail.value;
    }

    formatMediaItem(row) {
        let tags = [];
        if (row.MVEX__Tags__c) {
            if (Array.isArray(row.MVEX__Tags__c)) {
                tags = row.MVEX__Tags__c;
            } else if (typeof row.MVEX__Tags__c === 'string') {
                tags = row.MVEX__Tags__c.split(';');
            }
        }
        tags = tags.map(t => t.trim()).filter(Boolean);
        row.hasTags = tags.length > 0;
        row.formattedTagsList = tags.map((t, idx) => idx < tags.length - 1 ? `${t};` : t);
        row.tagsTooltip = tags.join('; ');
        row.tagsDisplay = tags.length > 0 ? tags.join('; ') : '-';

        let statuses = [];
        if (row.MVEX__IsOnExpose__c) {
            statuses.push('Is On Expose');
        }
        if (row.MVEX__IsOnWebsite__c) {
            statuses.push('Is On Website');
        }
        if (row.MVEX__IsOnPortalFeed__c) {
            statuses.push('Is On Portal Feed');
        }
        row.hasStatus = statuses.length > 0;
        row.formattedStatusList = statuses.map((s, idx) => idx < statuses.length - 1 ? `${s};` : s);
        row.statusTooltip = statuses.join('; ');
        row.statusDisplay = statuses.length > 0 ? statuses.join('; ') : '-';
    }

    @track screenWidth = 0;
    @track showExpose = true;
    @track showWebsite = false;
    @track showPortal = false;
    @track showModal = false;

    @track showImagePreview = false;
    @track previewImageTitle;
    @track isImageHavePreview = true;
    @track previewImageSrc;
    @track previewImageId;
    @track previewImgSpinner = false;
    @track notFirstImg = false;
    @track notLastImg = false;
    @track viewAllImageList = [];
    @track isNextAndPreviousBtn = false;

    @track s3;
    @track confData;
    @track isAwsSdkInitialized = true;
    @track FileNameInAWS;
    @track fileListToDelete = [];
    @track sortBy;
    @track sortDirection = 'asc';

    get isMobileOrTablet() {
        return FORM_FACTOR === 'Small' || FORM_FACTOR === 'Medium';
    }

    /**
    * Method Name: showMobileView
    * @description: Used to show mobile view.
    * Created Date: 27/06/2024
    * Created By: Karan Singh
    */
    get showMobileView() {
        return false;
    }

    /**
    * Method Name: disableEnableBtn
    * @description: Enable and Disable the save and cancel buttons.
    * Created Date: 27/06/2024
    * Last Updated: 23/12/2024
    * Created By: Karan Singh
    */
    get disableEnableBtn() {
        try {
            let recordMap = new Map();
            let combinedMediaListToSave = this.saveOrder();
            this.data?.forEach(record => {
                let existingRecord = { Id: record.Id };
                for (let key in record) {
                    existingRecord[key] = record[key];
                }
                recordMap.set(record.Id, existingRecord);
            });

            combinedMediaListToSave?.forEach(media => {
                if (!recordMap.has(media.Id)) {
                    recordMap.set(media.Id, { Id: media.Id });
                }
                let existingRecord = recordMap.get(media.Id);
                for (let key in media) {
                    if (Object.prototype.hasOwnProperty.call(media, key) && key !== 'Id') {
                        existingRecord[key] = media[key];
                    }
                }
            });

            let finalListToUpdate = Array.from(recordMap.values());
            const fetchedDataString = JSON.stringify(this.fetchedData);
            const dataString = JSON.stringify(finalListToUpdate);
            return fetchedDataString === dataString;
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'disableEnableBtn', error, 'warn', 'Error while enabling and disabling the buttons');
            return true;
        }
    }

    /**
    * Method Name: isAllDelete
    * @description: Used to check if all media is deleted.
    * Created Date: 27/06/2024
    * Created By: Karan Singh
    */
    get isAllDelete() {
        return !this.isData;
    }

    @wire(MessageContext)
    messageContext;

    /**
    * Method Name: connectedCallback
    * @description: Used to load css and fetch data.
    * Created Date: 27/06/2024
    * Created By: Karan Singh
    */
    connectedCallback() {
        try {
            this.getS3ConfigDataAsync();
            this.screenWidth = window?.globalThis?.innerWidth;
            window?.globalThis?.addEventListener('resize', this.handleResize);
            this.fetchingdata();
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'connectedCallback', error, 'warn', 'Error while loading css and fetching data');
        }
    }

    /**
    * Method Name: renderedCallback
    * @description: Used to load the AWS SDK.
    * Created Date: 27/06/2024
    * Created By: Karan Singh
    */
    renderedCallback() {
        try {
            if (this.isAwsSdkInitialized) {
                Promise.all([loadScript(this, AWS_SDK)]);
                this.isAwsSdkInitialized = false;
            }
            this.updateSortIcons();
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'renderedCallback', error, 'warn', 'Error while loading AWS SDK');
        }
    }

    /**
    * Method Name : disconnectedCallback
    * @description : remove the resize event.
    * Created Date: 27/06/2024
    * Created By: Vyom Soni
    */
    disconnectedCallback() {
        try {
            window?.globalThis?.removeEventListener('resize', this.handleResize);
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'disconnectedCallback', error, 'warn', 'Error while removing the resize event');
        }
    }

    /**
    * Method Name : tabing
    * @description : handle the tabing.
    * Created Date: 27/06/2024
    * Created By: Karan Singh
    */
    tabing(event) {
        try {
            const target = event.currentTarget.querySelector('a').getAttribute('data-tab-id');

            this.template.querySelectorAll("a").forEach(tabel => {
                tabel.classList.remove("active-tab");
            });

            this.template.querySelectorAll(".tab").forEach(tabdata => {
                tabdata.classList.remove("active-tab-content");
            });

            this.template.querySelector('[data-tab-id="' + target + '"]').classList.add("active-tab");

            this.template.querySelector('[data-id="' + target + '"]').classList.add("active-tab-content");
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'tabing', error, 'warn', 'Error while handling the tabing');
        }
    }

    /**
    * Method Name : handleResize
    * @description : call when component is resize.
    * Created Date: 27/07/2024
    * Last Updated: 23/12/2024
    * Created By: Vyom Soni
    * Modified By: Karan Singh
    */
    handleResize = () => {
        try {
            this.screenWidth = window?.globalThis?.innerWidth;
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'handleResize', error, 'warn', 'Error while handling the resize event');
        }
    }

    /**
    * Method Name : handleMenuTabClick
    * @description : handle the menu clicks in the header
    * Created Date: 27/07/2024
    * Created By: Vyom Soni
    */
    handleMenuTabClick(evt) {
        try {
            let target = evt.currentTarget.dataset.tabId;
            this.showExpose = false;
            this.showPortal = false;
            this.showWebsite = false;
            if (target == "1") {
                this.showExpose = true;
            } else if (target == "2") {
                this.showWebsite = true;
            } else if (target == "3") {
                this.showPortal = true;
            }
            this.template.querySelectorAll(".feed-tab").forEach(tabel => {
                tabel.classList.remove("feed-tab-active");
            });
            this.template.querySelector('[data-tab-id="' + target + '"]').classList.add("feed-tab-active");
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'handleMenuTabClick', error, 'warn', 'Error while handling the menu clicks');
        }
    }

    /**
    * Method Name : sortClick
    * @description : handle sorting when column header is clicked
    */
    sortClick(event) {
        try {
            let sortField = event.currentTarget.dataset.id;
            this.sortBy = sortField;
            if (this.sortDirection === 'asc') {
                this.sortDirection = 'desc';
            } else {
                this.sortDirection = 'asc';
            }
            this.updateSortIcons(event);
            this.sortData();
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'sortClick', error, 'warn', 'Error while sorting items');
        }
    }

    /**
    * Method Name : sortData
    * @description : performs data sorting based on current sortBy and sortDirection
    */
    sortData() {
        try {
            let dataArr = [...this.data];
            let reverse = this.sortDirection === 'asc' ? 1 : -1;
            dataArr.sort((a, b) => {
                let valueA = a[this.sortBy] ? a[this.sortBy].toLowerCase() : '';
                let valueB = b[this.sortBy] ? b[this.sortBy].toLowerCase() : '';
                
                // Size column parsing specifically 
                if(this.sortBy === 'MVEX__Size__c') {
                    valueA = a[this.sortBy] && a[this.sortBy] !== 'External' ? parseFloat(a[this.sortBy]) : 0;
                    valueB = b[this.sortBy] && b[this.sortBy] !== 'External' ? parseFloat(b[this.sortBy]) : 0;
                }
                
                return valueA > valueB ? 1 * reverse : -1 * reverse;
            });
            this.data = dataArr;
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'sortData', error, 'warn', 'Error while sorting data');
        }
    }

    /**
    * Method Name : updateSortIcons
    * @description : handles visual rotation state of sorting SVG icons
    */
    updateSortIcons(event) {
        try {
            let svgElements = this.template.querySelectorAll('svg.exp-arrow-icon');
            let clickedSortField = event ? event.currentTarget.dataset.id : this.sortBy;
            
            this.template.querySelectorAll('.exp-sorting-header').forEach(el => {
                el.classList.remove('active-sort');
            });
            
            if (event) {
                event.currentTarget.classList.add('active-sort');
            } else if (this.sortBy) {
                let activeHeader = this.template.querySelector(`th[data-id="${this.sortBy}"]`);
                if (activeHeader) activeHeader.classList.add('active-sort');
            }

            svgElements.forEach(svg => {
                const sortFieldParent = svg.dataset.index;
                svg.classList.remove('exp-rotate-asc', 'exp-rotate-desc');
                if (sortFieldParent === clickedSortField) {
                    if (this.sortDirection === 'asc') {
                        svg.classList.add('exp-rotate-asc');
                    } else {
                        svg.classList.add('exp-rotate-desc');
                    }
                }
            });
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'updateSortIcons', error, 'warn', 'Error while updating sort icons');
        }
    }

    /**
    * Method Name: fetchingdata
    * @description: Used to fetch data from server.
    * Created Date: 27/06/2024
    * Created By: Karan Singh
    */
    fetchingdata() {
        try {
            this.data = [];
            this.currentPage = 1;
            this.showSpinner = true;
            fetchListingAndImages({ recordId: this.recordId })
                .then(result => {
                    if (result != null) {
                        this.data = result.listingImages;
                        this.propertyId = result.propertyId;
                        this.exposeData = this.data.filter(media => media.MVEX__Sort_on_Expose__c !== null && media.MVEX__IsOnExpose__c !== false).sort((a, b) => a.MVEX__Sort_on_Expose__c - b.MVEX__Sort_on_Expose__c);
                        this.websiteData = this.data.filter(media => media.MVEX__Sort_on_Website__c !== null && media.MVEX__IsOnWebsite__c !== false).sort((a, b) => a.MVEX__Sort_on_Website__c - b.MVEX__Sort_on_Website__c);
                        this.portalData = this.data.filter(media => media.MVEX__Sort_on_Portal_Feed__c !== null && media.MVEX__IsOnPortalFeed__c !== false).sort((a, b) => a.MVEX__Sort_on_Portal_Feed__c - b.MVEX__Sort_on_Portal_Feed__c);
                        this.data.forEach(row => {
                            row.MVEX__Size__c = row.MVEX__Size__c ? row.MVEX__Size__c + ' ' + 'kb' : 'External';
                            row.MVEX__Tags__c = row.MVEX__Tags__c ? row.MVEX__Tags__c.split(";") : [];
                            this.formatMediaItem(row);
                        });
                        this.isData = result.listingImages && result.listingImages.length > 0;
                        this.fetchedData = JSON.parse(JSON.stringify(this.data));
                        this.showSpinner = false;

                        this.fileListToDelete = this.data
                            .filter(row => row.MVEX__Size__c !== 'External')
                            .map(row => row.MVEX__Filename__c);

                        const message = { refresh: true };

                        if (this.isData == true) {
                            this.disabledDelete = false;
                        } else if (this.isData == false) {
                            this.disabledDelete = true;
                        }

                        publish(this.messageContext, Refresh_msg, message);

                    } else {
                        this.showSpinner = false;
                    }
                }).catch(error => {
                    this.showSpinner = false;
                    errorDebugger('ImagesAndMedia', 'fetchingdata:fetchListingAndImages', error, 'warn', 'Error while fetching data');
                });
        } catch (error) {
            this.showSpinner = false;
            errorDebugger('ImagesAndMedia', 'fetchingdata', error, 'warn', 'Error while fetching data');
        }
    }

    /**
    * Method Name: saveChanges
    * @description: Used to save changes.
    * Created Date: 27/06/2024
    * Created By: Karan Singh
    */
    saveChanges() {
        try {
            let recordMap = new Map();

            // Prepare the media list to save
            let combinedMediaListToSave = this.saveOrder();

            const ignoredKeys = [
                'MVEX__BaseUrl__c', 'MVEX__Size__c', 'MVEX__Property__c',
                'formattedTagsList', 'formattedStatusList', 'hasTags', 'hasStatus', 'tagsTooltip', 'statusTooltip',
                'tagsDisplay', 'statusDisplay'
            ];

            // Iterate over this.data to initialize the map with existing records
            this.data.forEach(record => {
                let existingRecord = { Id: record.Id };
                for (let key in record) {
                    if (!ignoredKeys.includes(key)) {
                        if (key === 'MVEX__Tags__c' && Array.isArray(record[key])) {
                            existingRecord[key] = record[key].join(';');
                        } else {
                            existingRecord[key] = record[key];
                        }
                    }
                }
                recordMap.set(record.Id, existingRecord);
            });

            // Iterate over combinedMediaListToSave and merge sort fields into the map
            combinedMediaListToSave.forEach(media => {
                if (!recordMap.has(media.Id)) {
                    recordMap.set(media.Id, { Id: media.Id });
                }
                let existingRecord = recordMap.get(media.Id);
                for (let key in media) {
                    if (Object.prototype.hasOwnProperty.call(media, key) && key !== 'Id') {
                        existingRecord[key] = media[key];
                    }
                }
            });

            let finalListToUpdate = Array.from(recordMap.values());

            // Make a single Apex callout with the final list
            updatePropertyFileRecords({ itemsToUpdate: finalListToUpdate })
                .then(result => {
                    if (result === 'success') {
                        this.showToast('Success', 'Records updated successfully', 'success');
                        this.fetchingdata();
                    } else {
                        this.showToast('Error', result, 'error');
                    }
                })
                .catch(error => {
                    errorDebugger('ImagesAndMedia', 'saveChanges:updatePropertyFileRecords', error, 'warn', 'Error while updating records');
                });

        } catch (error) {
            errorDebugger('ImagesAndMedia', 'saveChanges', error, 'warn', 'Error while saving changes');
        }
    }

    /**
    * Method Name: saveOrder
    * @description: Used to save order.
    * Created Date: 09/07/2024
    * Created By: Karan Singh
    */
    saveOrder() {
        try {
            let combinedMediaListToSave = [];

            if (this.sortOn.includes('exposeData')) {
                combinedMediaListToSave = combinedMediaListToSave.concat(this.prepareMediaListToSave('exposeData', this.exposeData));
            }
            if (this.sortOn.includes('websiteData')) {
                combinedMediaListToSave = combinedMediaListToSave.concat(this.prepareMediaListToSave('websiteData', this.websiteData));
            }
            if (this.sortOn.includes('portalData')) {
                combinedMediaListToSave = combinedMediaListToSave.concat(this.prepareMediaListToSave('portalData', this.portalData));
            }

            return combinedMediaListToSave;
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'saveOrder', error, 'warn', 'Error while saving order');
        }
    }

    /**
    * Method Name: prepareMediaListToSave
    * @description: Used to prepare media list to save.
    * @param {string} type - The type to prepare media list to save.
    * @param {object} mediaList - The media list to prepare.
    * Created Date: 09/07/2024
    * Last Updated: 23/12/2024
    * Created By: Karan Singh
    */
    prepareMediaListToSave(type, mediaList) {
        try {
            return mediaList.map((media, index) => {
                let mediaObject = {
                    Id: media.Id,
                };
    
                switch (type) {
                    case 'exposeData':
                        mediaObject.MVEX__Sort_on_Expose__c = index;
                        break;
                    case 'websiteData':
                        mediaObject.MVEX__Sort_on_Website__c = index;
                        break;
                    case 'portalData':
                        mediaObject.MVEX__Sort_on_Portal_Feed__c = index;
                        break;
                    default:
                        break;
                }
    
                return mediaObject;
            });
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'prepareMediaListToSave', error, 'warn', 'Error while preparing media list to save');
        }
    }

    /**
    * Method Name: cancelChanges
    * @description: Used to cancel changes.
    * Created Date: 27/06/2024
    * Last Updated: 23/12/2024
    * Created By: Karan Singh
    */
    cancelChanges() {
        try {
            this.imgOldName = [];
            this.recIdToUpdate = [];
            this.picklistValues = [];
            this.finalPicklistValues = [];
            this.data = [];
            this.sortOn = [];
            this.fetchingdata();
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'cancelChanges', error, 'warn', 'Error while cancelling changes');
        }
    }

    /**
    * Method Name: modalPopup
    * @description: Used to show modal popup.
    * Created Date: 27/06/2024
    * Last Updated: 23/12/2024
    * Created By: Karan Singh
    */
    modalPopup() {
        try {
            this.hideMainDiv();
            this.isPopup = true;
            this.updateShowModal();
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'modalPopup', error, 'warn', 'Error while showing modal popup');
        }
    }

    /**
    * Method Name: toDeleteAllMedia
    * @description: Used to delete all media.
    * Created Date: 27/06/2024
    * Last Updated: 23/12/2024
    * Created By: Karan Singh
    */
    toDeleteAllMedia() {
        try {
            this.hideMainDiv();
            this.isDeleteAll = true;
            this.updateShowModal();
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'toDeleteAllMedia', error, 'warn', 'Error while deleting all media');
        }
    }

    /**
    * Method Name: deleteAllMedia
    * @description: Used to delete all media.
    * Created Date: 27/06/2024
    * Created By: Karan Singh
    */
    deleteAllMedia() {
        try {
            this.showSpinner = true;
            this.isDeleteAll = false;
            this.updateShowModal();
            deletelistingmedia({ propertyId: this.recordId })
            .then(() => {
                this.deleteAllFilesInAWS();
                this.fetchingdata();
            })
            .catch(error => {
                errorDebugger('ImagesAndMedia', 'deleteAllMedia:deletelistingmedia', error, 'warn', 'Error while deleting all media');
            });
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'deleteAllMedia', error, 'warn', 'Error while deleting all media');
        } finally {
            this.showSpinner = false;
        }
    }

    /**
    * Method Name: storeImgName
    * @description: Used to store image name.
    * Created Date: 27/06/2024
    * Last Updated: 23/12/2024
    * Created By: Karan Singh
    */
    storeImgName(event) {
        try {
            this.eventImgName = event.target.value;
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'storeImgName', error, 'warn', 'Error while storing image name');
        }
    }

    /**
    * Method Name: editImageNameToStore
    * @description: Used to edit image name and details to store.
    * Created Date: 27/06/2024
    * Created By: Karan Singh
    */
    editImageNameToStore(event) {
        try {
            this.hideMainDiv();
            this.isEdit = true;
            const recId = event.currentTarget.dataset.key;
            this.recIdToUpdate.push(recId);
            const currentRecord = this.data.find(item => item.Id === recId);
            this.currentImgName = currentRecord ? currentRecord.Name : event.currentTarget.dataset.name;
            this.eventImgName = this.currentImgName;
            this.imgOldName.push(this.currentImgName);

            // Populate selected tags
            let tags = [];
            if (currentRecord && currentRecord.MVEX__Tags__c) {
                if (Array.isArray(currentRecord.MVEX__Tags__c)) {
                    tags = [...currentRecord.MVEX__Tags__c];
                } else if (typeof currentRecord.MVEX__Tags__c === 'string') {
                    tags = currentRecord.MVEX__Tags__c.split(';');
                }
            } else if (event.currentTarget.dataset.tags) {
                tags = event.currentTarget.dataset.tags.split(',');
            }
            this.selectedTags = tags.map(t => t.trim()).filter(Boolean);

            // Populate selected status
            this.selectedStatus = [];
            if (currentRecord?.MVEX__IsOnExpose__c) {
                this.selectedStatus.push('MVEX__IsOnExpose__c');
            }
            if (currentRecord?.MVEX__IsOnWebsite__c) {
                this.selectedStatus.push('MVEX__IsOnWebsite__c');
            }
            if (currentRecord?.MVEX__IsOnPortalFeed__c) {
                this.selectedStatus.push('MVEX__IsOnPortalFeed__c');
            }

            this.updateShowModal();
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'editImageNameToStore', error, 'warn', 'Error while editing image details');
        }
    }

    /**
    * Method Name: confirmEdit
    * @description: Used to confirm edit.
    * Created Date: 27/06/2024
    * Created By: Karan Singh
    */
    confirmEdit() {
        try {
            if (this.eventImgName && this.eventImgName != undefined && this.eventImgName.trim() != '') {
                let rec_id = this.recIdToUpdate[this.recIdToUpdate.length - 1];
                let index_of_record = this.data.findIndex(item => item.Id === rec_id);
                if (index_of_record !== -1) {
                    if (this.eventImgName != undefined) {
                        this.data[index_of_record].Name = this.eventImgName;
                    }
                    this.data[index_of_record].MVEX__Tags__c = [...this.selectedTags];
                    this.data[index_of_record].MVEX__IsOnExpose__c = this.selectedStatus.includes('MVEX__IsOnExpose__c');
                    this.data[index_of_record].MVEX__IsOnWebsite__c = this.selectedStatus.includes('MVEX__IsOnWebsite__c');
                    this.data[index_of_record].MVEX__IsOnPortalFeed__c = this.selectedStatus.includes('MVEX__IsOnPortalFeed__c');

                    this.formatMediaItem(this.data[index_of_record]);
                    this.data = [...this.data];

                    this.exposeData = this.data.filter(media => media.MVEX__Sort_on_Expose__c !== null && media.MVEX__IsOnExpose__c !== false).sort((a, b) => a.MVEX__Sort_on_Expose__c - b.MVEX__Sort_on_Expose__c);
                    this.websiteData = this.data.filter(media => media.MVEX__Sort_on_Website__c !== null && media.MVEX__IsOnWebsite__c !== false).sort((a, b) => a.MVEX__Sort_on_Website__c - b.MVEX__Sort_on_Website__c);
                    this.portalData = this.data.filter(media => media.MVEX__Sort_on_Portal_Feed__c !== null && media.MVEX__IsOnPortalFeed__c !== false).sort((a, b) => a.MVEX__Sort_on_Portal_Feed__c - b.MVEX__Sort_on_Portal_Feed__c);
                }

                this.eventImgName = undefined;
                this.selectedTags = [];
                this.selectedStatus = [];
                this.isEdit = false;
                this.updateShowModal();
                this.addMainDiv();
            } else {
                this.showToast('Error', 'Name field should not be empty.', 'error');
            }

        } catch (error) {
            errorDebugger('ImagesAndMedia', 'confirmEdit', error, 'warn', 'Error while confirming edit');
        }
    }

    /**
    * Method Name: removeDuplicates
    * @description: Used to remove duplicates.
    * Created Date: 27/06/2024
    * Last Updated: 23/12/2024
    * Created By: Karan Singh
    */
    removeDuplicates(arr) {
        try {
            return [...new Set(arr)];
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'removeDuplicates', error, 'warn', 'Error while removing duplicates');
        }
    }

    /**
    * Method Name: closePopupEdit
    * @description: Used to close popup edit.
    * Created Date: 27/06/2024
    * Created By: Karan Singh
    */
    closePopupEdit() {
        try {
            this.addMainDiv();
            this.selectedTags = [];
            this.selectedStatus = [];
            this.isEdit = false;
            this.imgOldName.pop();
            this.recIdToUpdate.pop();
            this.updateShowModal();
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'closePopupEdit', error, 'warn', 'Error while closing popup edit');
        }
    }

    /**
    * Method Name: closePopup
    * @description: Used to close popup.
    * Created Date: 27/06/2024
    * Last Updated: 23/12/2024
    * Created By: Karan Singh
    */
    closePopup() {
        try {
            this.addMainDiv();
            this.isPopup = false;
            this.isdelete = false;
            this.isEdit = false;
            this.isDeleteAll = false;
            if (this.isData != true) {
                this.disabledDelete = true;
            }
            this.updateShowModal();
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'closePopup', error, 'warn', 'Error while closing popup');
        }
    }

    /**
    * Method Name: handleDelete
    * @description: Used to handle delete.
    * Created Date: 27/06/2024
    * Created By: Karan Singh
    */
    handleDelete() {
        try {
            this.isdelete = false;
            deletelistingmedia({ id: this.recIdToDelete })
            .then(() => {
                this.fetchingdata();
                this.addMainDiv();
            })
            .catch(error => {
                errorDebugger('ImagesAndMedia', 'handleDelete:deletelistingmedia', error, 'warn', 'Error while handling delete');
            });
            this.deleteFileInAWS();
            this.updateShowModal();
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'handleDelete', error, 'warn', 'Error while handling delete');
            this.showToast('Error', 'Something went wrong while deleting media.', 'error');
        }
    }

    /**
    * Method Name: handleCheckboxChange
    * @description: Used to handle checkbox change.
    * Created Date: 08/07/2024
    * Created By: Karan Singh
    */
    handleCheckboxChange(event) {
        try {
            const key = event.currentTarget.dataset.key;
            const field = event.currentTarget.dataset.field;
            const value = event.currentTarget.checked;

            const updatedData = this.data.map(item => {
                if (item.Id === key) {
                    return { ...item, [field]: value };
                }
                return item;
            });

            this.data = updatedData;
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'handleCheckboxChange', error, 'warn', 'Error while handling checkbox change');
        }
    }

    /**
    * Method Name: deleteRow
    * @description: Used to delete row.
    * Created Date: 27/06/2024
    * Last Updated: 23/12/2024
    * Created By: Karan Singh
    */
    deleteRow(event) {
        try {
            this.hideMainDiv();
            this.recIdToDelete = event.currentTarget.dataset.key;
            var imagesize = event.currentTarget.dataset.size;
            if (imagesize != 'External') {
                this.FileNameInAWS = event.currentTarget.dataset.label;
            }
            this.isdelete = true;
            this.updateShowModal();
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'deleteRow', error, 'warn', 'Error while deleting row');
        }
    }

    /**
    * Method Name: downloadRowImage
    * @description: Used to download row image.
    * Created Date: 27/06/2024
    * Created By: Karan Singh
    */
    downloadRowImage(event) {
        try {
            const url = event.currentTarget.dataset.url;
            const fileName = event.currentTarget.dataset.name;
            const isExternal = event.currentTarget.dataset.isexternal === 'External';
    
            if (fileName != undefined && !isExternal) {
                this.initializeAwsSdk(this.confData);
                const oldKey = fileName.replace(/\s+/g, "_").toLowerCase();
                const bucketName = this.confData.MVEX__S3_Bucket_Name__c;
    
                // Generate the signed URL for the S3 object
                const signedUrl = this.s3.getSignedUrl('getObject', {
                    Bucket: bucketName,
                    Key: oldKey,
                    Expires: 60 // URL expires in 60 seconds
                });
    
                // Fetch the file as a Blob
                fetch(signedUrl)
                    .then(response => {
                        if (!response.ok) {
                            return null;
                        }
                        return response.blob();
                    })
                    .then(blob => {
                        if (blob) {
                            const blobUrl = window.URL.createObjectURL(blob);
                            const link = window?.globalThis?.document?.createElement('a');
                            link.href = blobUrl;
                            link.download = oldKey;
                            document.body.appendChild(link);
                            link.click();
                            document.body.removeChild(link);
                            window.URL.revokeObjectURL(blobUrl);
                        }
                    })
                    .catch(error => errorDebugger('ImagesAndMedia', 'downloadRowImage:fetch', error, 'warn', 'Error while downloading row image'));
            } else {
                const downloadContainer = this.template.querySelector('.download-container');
                const a = window?.globalThis?.document?.createElement("a");
    
                a.href = url;
                a.download = fileName;
                a.target = '_blank';
                if (downloadContainer) {
                    downloadContainer.appendChild(a);
                }
                a.click();
                if (downloadContainer) {
                    downloadContainer.removeChild(a);
                }
            }
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'downloadRowImage', error, 'warn', 'Error while downloading row image');
        }
    }

    /**
    * Method Name: handleDragOver
    * @description: Used to handle drag over.
    * Created Date: 27/06/2024
    * Last Updated: 23/12/2024
    * Created By: Karan Singh
    */
    handleDragOver(event) {
        try {
            event.preventDefault();
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'handleDragOver', error, 'warn', 'Error while handling drag over');
        }
    }

    /**
    * Method Name: handleDragStart
    * @description: Used to handle drag start.
    * Created Date: 27/06/2024
    * Last Updated: 23/12/2024
    * Created By: Karan Singh
    */
    handleDragStart(event) {
        try {
            const index = event.target.dataset.index;
            event.dataTransfer.setData('index', index);
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'handleDragStart', error, 'warn', 'Error while handling drag start');
        }
    }

    /**
    * Method Name: findParentWithDataIndex
    * @description: Used to find parent with data index.
    * @param {object} element - The element to find parent with data index.
    * Created Date: 27/06/2024
    * Created By: Karan Singh
    */
    findParentWithDataIndex(element) {
        try {
            let parent = element.parentElement;
            while (parent) {
                const index = parent.getAttribute('data-index');
                if (index !== null) {
                    return index;
                }
                parent = parent.parentElement;
            }
            return null;
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'findParentWithDataIndex', error, 'warn', 'Error while finding parent with data index');
        }
    }

    /**
    * Method Name: handleDragEnter
    * @description: Used to handle drag enter.
    * Created Date: 27/06/2024
    * Created By: Karan Singh
    */
    handleDragEnter(event) {
        try {
            event.preventDefault();
            event.target.closest(".dropable-image").classList.add("highlight");
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'handleDragEnter', error, 'warn', 'Error while handling drag enter');
        }
    }

    /**
    * Method Name: handleDragLeave
    * @description: Used to handle drag leave.
    * @param {object} event - The event to handle drag leave.
    * Date: 27/06/2024
    * Created By: Karan Singh
    */
    handleDragLeave(event) {
        try {
            event.preventDefault();
            const dropableImage = event.currentTarget.closest(".dropable-image");
            if (!dropableImage.contains(event.relatedTarget)) {
                dropableImage.classList.remove("highlight");
            }
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'handleDragLeave', error, 'warn', 'Error while handling drag leave');
        }
    }

    /**
    * Method Name: handledDrop
    * @description: Used to handle drop.
    * @param {object} event - The event to handle drop.
    * Created Date: 27/06/2024
    * Created By: Karan Singh
    */
    handledDrop(event) {
        try {
            event.preventDefault();
            event.target.closest(".dropable-image").classList.remove("highlight");
            var tempdata = [];
            const draggedIndex = event.dataTransfer.getData('index');
            const droppedIndex = this.findParentWithDataIndex(event.target);
            const dataType = event.currentTarget.dataset.type;
            if (!this.sortOn.includes(dataType)) {
                this.sortOn.push(dataType);
            }
            switch (dataType) {
                case 'exposeData':
                    tempdata = this.exposeData;
                    break;
                case 'websiteData':
                    tempdata = this.websiteData;
                    break;
                case 'portalData':
                    tempdata = this.portalData;
                    break;
                default:
                    break;
            }

            if (draggedIndex === droppedIndex) {
                return;
            }

            const draggedMediaId = tempdata[draggedIndex].Id;

            // Rearrange the media IDs based on the new order
            var reorderedMediaIds = this.reorderMediaIds(draggedMediaId, draggedIndex, droppedIndex, tempdata);
            tempdata = reorderedMediaIds.map(mediaId => {
                return tempdata.find(item => item.Id === mediaId);
            });

            switch (dataType) {
                case 'exposeData':
                    this.exposeData = reorderedMediaIds.map(mediaId => {
                        return this.exposeData.find(item => item.Id === mediaId);
                    });
                    break;
                case 'websiteData':
                    this.websiteData = reorderedMediaIds.map(mediaId => {
                        return this.websiteData.find(item => item.Id === mediaId);
                    });
                    break;
                case 'portalData':
                    this.portalData = reorderedMediaIds.map(mediaId => {
                        return this.portalData.find(item => item.Id === mediaId);
                    });
                    break;
                default:
                    break;
            }
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'handledDrop', error, 'warn', 'Error while handling drop');
        }
    }

    /**
    * Method Name: reorderMediaIds
    * @description: Used to reorder media ids.
    * @param {string} draggedMediaId - The media id to drag.
    * @param {string} draggedIndex - The index of the media id to drag.
    * @param {string} droppedIndex - The index of the media id to drop.
    * @param {object} tempdata - The data to reorder.
    * Created Date: 27/06/2024
    * Created By: Karan Singh
    */
    reorderMediaIds(draggedMediaId, draggedIndex, droppedIndex, tempdata) {
        try {
            // Create a copy of the current order of IDs
            let reorderedMediaIds = [...tempdata.map(media => media.Id)];
    
            // Remove the dragged item from its original position
            reorderedMediaIds.splice(draggedIndex, 1);
    
            // Insert the dragged item at its new position
            reorderedMediaIds.splice(droppedIndex, 0, draggedMediaId);
    
            return reorderedMediaIds;
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'reorderMediaIds', error, 'warn', 'Error while reordering media ids');
        }
    }
    

    /**
    * Method Name: getWebsite
    * @description: Used to get website.
    * Created Date: 27/06/2024
    * Last Updated: 23/12/2024
    * Created By: Karan Singh
    */
    getWebsite() {
        try {
            this.websiteData = this.data;
            this.data.forEach(item => {
                item.MVEX__IsOnWebsite__c = true;
            });
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'getWebsite', error, 'warn', 'Error while getting website');
        }
    }

    /**
    * Method Name: clearWebsite
    * @description: Used to clear website.
    * Created Date: 27/06/2024
    * Last Updated: 23/12/2024
    * Created By: Karan Singh
    */
    clearWebsite() {
        try {
            this.websiteData = null;
            this.data.forEach(item => {
                item.MVEX__IsOnWebsite__c = false;
            });
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'clearWebsite', error, 'warn', 'Error while clearing website');
        }
    }

    /**
    * Method Name: getExpose
    * @description: Used to get expose.
    * Created Date: 27/06/2024
    * Last Updated: 23/12/2024
    * Created By: Karan Singh
    */
    getExpose() {
        try {
            this.exposeData = this.data;
            this.data.forEach(item => {
                item.MVEX__IsOnExpose__c = true;
            });
            this.getPortal();
            this.getWebsite();
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'getExpose', error, 'warn', 'Error while getting expose');
        }
    }

    /**
    * Method Name: clearExpose
    * @description: Used to clear expose.
    * Created Date: 27/06/2024
    * Last Updated: 23/12/2024
    * Created By: Karan Singh
    */
    clearExpose() {
        try {
            this.exposeData = null;
            this.data.forEach(item => {
                item.MVEX__IsOnExpose__c = false;
            });
            this.clearPortal();
            this.clearWebsite();
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'clearExpose', error, 'warn', 'Error while clearing expose');
        }
    }

    /**
    * Method Name: getPortal
    * @description: Used to get portal.
    * Created Date: 27/06/2024
    * Last Updated: 23/12/2024
    * Created By: Karan Singh
    */
    getPortal() {
        try {
            this.portalData = this.data;
            this.data.forEach(item => {
                item.MVEX__IsOnPortalFeed__c = true;
            });
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'getPortal', error, 'warn', 'Error while getting portal');
        }
    }

    /**
    * Method Name: clearPortal
    * @description: Used to clear portal.
    * Created Date: 27/06/2024
    * Last Updated: 23/12/2024
    * Created By: Karan Singh
    */
    clearPortal() {
        try {
            this.portalData = null;
            this.data.forEach(item => {
                item.MVEX__IsOnPortalFeed__c = false;
            });
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'clearPortal', error, 'warn', 'Error while clearing portal');
        }
    }

    /**
    * Method Name: tagsChecked
    * @description: Used to get tags checked.
    * @param {object} event - The event to get tags checked.
    * Created Date: 27/06/2024
    * Created By: Karan Singh
    */
    tagsChecked(event) {
        try {
            if (event.target.name === 'Floorplan') {
                this.floorplanChecked = event.target.checked;

                if (this.floorplanChecked) {
                    this.picklistValues.push(event.target.name);

                } else {
                    let index_of_item = this.picklistValues.indexOf(event.target.name);
                    this.picklistValues.splice(index_of_item, 1);
                }
            }
            if (event.target.name === 'Virtual Tour') {
                this.virtualTourChecked = event.target.checked;
                if (this.virtualTourChecked) {
                    this.picklistValues.push(event.target.name);

                } else {
                    let index_of_item = this.picklistValues.indexOf(event.target.name);
                    this.picklistValues.splice(index_of_item, 1);
                }
            }
            if (event.target.name === '360tour') {
                this.tourChecked = event.target.checked;
                if (this.tourChecked) {
                    this.picklistValues.push(event.target.name);

                } else {
                    let index_of_item = this.picklistValues.indexOf(event.target.name);
                    this.picklistValues.splice(index_of_item, 1);
                }
            }
            if (event.target.name === 'Interior') {
                this.interiorChecked = event.target.checked;
                if (this.interiorChecked) {
                    this.picklistValues.push(event.target.name);

                } else {
                    let index_of_item = this.picklistValues.indexOf(event.target.name);
                    this.picklistValues.splice(index_of_item, 1);
                }
            }
            if (event.target.name === 'Exterior') {
                this.exteriorChecked = event.target.checked;
                if (this.exteriorChecked) {
                    this.picklistValues.push(event.target.name);

                } else {
                    let index_of_item = this.picklistValues.indexOf(event.target.name);
                    this.picklistValues.splice(index_of_item, 1);
                }
            }
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'tagsChecked', error, 'warn', 'Error while tags checked');
        }

    }

    /**
    * Method Name: resetCheckboxes
    * @description: Used to reset checkboxes.
    * Created Date: 27/06/2024
    * Created By: Karan Singh
    */
    resetCheckboxes() {
        try {
            const exposeCheckbox = this.template.querySelectorAll('.checkbox-expose');
            if (exposeCheckbox) {
                exposeCheckbox.forEach(checkbox => {
                    checkbox.checked = false;
                });
            }

            const websiteCheckboxes = this.template.querySelectorAll('.checkbox-website');
            if (websiteCheckboxes) {
                websiteCheckboxes.forEach(checkbox => {
                    checkbox.checked = false;
                });
            }

            const portalCheckboxes = this.template.querySelectorAll('.checkbox-portal');
            if (portalCheckboxes) {
                portalCheckboxes.forEach(checkbox => {
                    checkbox.checked = false;
                });
            }
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'resetCheckboxes', error, 'warn', 'Error while resetting checkboxes');
        }
    }

    /**
    * Method Name: showToast
    * @description: Used to show toast message.
    * @param: title - title of toast message.
    * @param: mesaage - message to show in toast message.
    * @param: variant- type of toast message.
    * Created Date: 27/06/2024
    * Last Updated: 23/12/2024
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
            errorDebugger('ImagesAndMedia', 'showToast', error, 'warn', 'Error while showing toast message');
        }
    }

    /**
    * Method Name: closePopupModal
    * @description: Used to close popup modal.
    * Created Date: 27/06/2024
    * Last Updated: 23/12/2024
    * Created By: Karan Singh
    */
    closePopupModal() {
        try {
            this.addMainDiv();
            this.isPopup = false;
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'closePopupModal', error, 'warn', 'Error while closing popup modal');
        }
    }

    /**
    * Method Name: closePopupAndRefresh
    * @description: Used to close popup and refresh.
    * Created Date: 27/06/2024
    * Last Updated: 23/12/2024
    * Created By: Karan Singh
    */
    closePopupAndRefresh() {
        try {
            this.addMainDiv();
            this.isPopup = false;
            this.cancelChanges();
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'closePopupAndRefresh', error, 'warn', 'Error while closing popup and refreshing');
        }
    }

    /**
    * Method Name: updateShowModal
    * @description: Used to update showModal.
    * Created Date: 27/06/2024
    * Last Updated: 23/12/2024
    * Created By: Karan Singh
    */
    updateShowModal() {
        try {
            this.showModal = !this.showModal;
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'updateShowModal', error, 'warn', 'Error while updating showModal');
        }
    }

    /**
    * Method Name: stopEventPropogation
    * @description: Used to stop event propogation.
    * Created Date: 27/06/2024
    * Last Updated: 23/12/2024
    * Created By: Karan Singh
    */
    stopEventPropogation(event) {
        try {
            event.stopPropagation();
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'stopEventPropogation', error, 'warn', 'Error while stopping event propogation');
        }
    }

    /**
    * Method Name: closeImagePreview
    * @description: Used to close image preview.
    * Created Date: 27/06/2024
    * Last Updated: 23/12/2024
    * Created By: Karan Singh
    */
    closeImagePreview() {
        try {
            this.addMainDiv();
            this.isImageHavePreview = false;
            this.showImagePreview = false;
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'closeImagePreview', error, 'warn', 'Error while closing image preview');
        }
    }

    /**
    * Method Name: openCustomPreview
    * @description: Used to open custom preview.
    * @param imageSrc: imageSrc
    * @param imageTitle: imageTitle
    * @param imageId: imageId
    * Created Date: 27/06/2024
    * Created By: Karan Singh
    */
    openCustomPreview(imageSrc, imageTitle, imageId) {
        try {
            this.hideMainDiv();
            if (this.previewImageSrc == imageSrc) {
                this.previewImgSpinner = false;
            } else {
                this.previewImgSpinner = true;
            }
            this.previewImageSrc = imageSrc;
            this.previewImageTitle = imageTitle;
            this.previewImageId = imageId;
            this.isImageHavePreview = true;
            this.showImagePreview = true;
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'openCustomPreview', error, 'warn', 'Error while opening custom preview');
            this.previewImgSpinner = false;
        }
    }

    /**
    * Method Name: changeImage
    * @description: Used to change image.
    * @param imageId: imageId
    * @param operationName: operationName
    * Created Date: 27/06/2024
    * Created By: Karan Singh
    */
    changeImage(imageId, operationName) {
        try {
            let imagesList = this.viewAllImageList;
            for (var i in imagesList) {
                if (imagesList[i].Id == imageId) {
                    if (operationName != null) {
                        if (operationName == 'Previous_Image') {
                            var imageSrc1 = imagesList[parseInt(i) - 1].MVEX__BaseUrl__c;
                            var imageTitle1 = imagesList[parseInt(i) - 1].Name;
                            var previewImageId1 = imagesList[parseInt(i) - 1].Id;
                            this.changeImage(previewImageId1, null);
                            this.openCustomPreview(imageSrc1, imageTitle1, previewImageId1);
                        } else if (operationName == 'Next_Image') {
                            var imageSrc2 = imagesList[parseInt(i) + 1].MVEX__BaseUrl__c;
                            var imageTitle2 = imagesList[parseInt(i) + 1].Name;
                            var previewImageId2 = imagesList[parseInt(i) + 1].Id;
                            this.changeImage(previewImageId2, null);
                            this.openCustomPreview(imageSrc2, imageTitle2, previewImageId2);
                        }
                    } else {
                        // Check if it's the first image
                        if (i == 0) {
                            this.notFirstImg = false;
                        } else {
                            this.notFirstImg = true;
                        }

                        // Check if it's the last image
                        if (i == imagesList.length - 1) {
                            this.notLastImg = false;
                        } else {
                            this.notLastImg = true;
                        }
                    }
                }
            }
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'changeImage', error, 'warn', 'Error while changing image');
        }
    }

    /**
    * Method Name: handleImageLoaded
    * @description: Used to handle image loaded.
    * Created Date: 27/06/2024
    * Last Updated: 23/12/2024
    * Created By: Karan Singh
    */
    handleImageLoaded() {
        this.previewImgSpinner = false;
    }

    /**
    * Method Name: handleImageError
    * @description: Used to handle image loading errors and display placeholder image.
    * Created Date: 21/09/2026
    * Created By: Karan Singh
    */
    handleImageError(event) {
        try {
            const img = event ? (event.target || event.currentTarget) : null;
            if (img && !img.dataset.fallbackApplied) {
                img.dataset.fallbackApplied = 'true';
                img.src = placeholderImage;
            }
            if (this.showImagePreview) {
                this.previewImageSrc = placeholderImage;
                this.isImageHavePreview = true;
                this.previewImgSpinner = false;
            }
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'handleImageError', error, 'warn', 'Error while handling image error');
        }
    }

    /**
    * Method Name: handleImageNotLoaded
    * @description: Used to handle image not loaded in preview modal.
    * Created Date: 27/06/2024
    * Last Updated: 21/09/2026
    * Created By: Karan Singh
    */
    handleImageNotLoaded(event) {
        this.handleImageError(event);
    }

    /**
    * Method Name: handleImgClick
    * @description: Used to handle image click.
    * Created Date: 27/06/2024
    * Created By: Karan Singh
    */
    handleImgClick(event) {
        try {
            this.isNextAndPreviousBtn = false;
            var imageSize = event.currentTarget.dataset.size;
            var mimeType = event.currentTarget.dataset.mimetype;
            var imageExSrc = event.currentTarget.dataset.exturl;
            var imageSrc = event.currentTarget.dataset.src;
            var imageId = event.currentTarget.dataset.recid;
            var imageTitle = event.currentTarget.dataset.description;
            this.viewAllImageList = this.data;
            const isVideo = mimeType === 'video/mp4' || mimeType === 'video/quicktime' || (mimeType && mimeType.startsWith('video/'));
            if (imageSize == 'External' || isVideo) {
                window.open(imageExSrc, '_blank');
            } else {
                this.changeImage(imageId, null);
                this.openCustomPreview(imageSrc, imageTitle, imageId);
            }
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'handleImgClick', error, 'warn', 'Error while handling image click');
        }
    }

    /**
    * Method Name: changeImg
    * @description: Used to change image.
    * Created Date: 27/06/2024
    * Last Updated: 23/12/2024
    * Created By: Karan Singh
    */
    changeImg(event) {
        try {
            var operationName = event.currentTarget.dataset.name;
            this.isImageHavePreview = false;
            this.showImagePreview = false;
            this.changeImage(this.previewImageId, operationName);
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'changeImg', error, 'warn', 'Error while changing image');
        }
    }

    /**
    * Method Name: showImages
    * @description: Used to show images.
    * Created Date: 27/06/2024
    * Last Updated: 23/12/2024
    * Created By: Karan Singh
    */
    showImages(event) {
        try {
            this.isNextAndPreviousBtn = true;
            var actionName = event.target.dataset.name;
            if (actionName == 'Expose') {
                this.handleFromShowImage(this.exposeData);
            } else if (actionName == 'Website') {
                this.handleFromShowImage(this.websiteData);
            } else if (actionName == 'Portal') {
                this.handleFromShowImage(this.portalData);
            }
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'showImages', error, 'warn', 'Error while showing images');
        }
    }

    /**
    * Method Name: handleFromShowImage
    * @description: Used to handle from show image.
    * Created Date: 27/06/2024
    * Created By: Karan Singh
    */
    handleFromShowImage(imageList) {
        try {
            if (imageList.length > 0) {
                this.viewAllImageList = imageList;
    
                this.changeImage(imageList[0].Id, null);
                this.openCustomPreview(imageList[0].MVEX__BaseUrl__c, imageList[0].Name, imageList[0].Id);
            } else {
                this.showToast('Error', 'No Images found to show.', 'error');
            }
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'handleFromShowImage', error, 'warn', 'Error while handling from show image');
        }
    }

    /**
    * Method Name: deleteIcon
    * @description: Used to delete icon.
    * Created Date: 27/06/2024
    * Created By: Karan Singh
    */
    deleteIcon(event) {
        try {
            const id = event.currentTarget.dataset.id;
            const field = event.currentTarget.dataset.field;

            if (field == 'MVEX__IsOnExpose__c') {
                this.exposeData = this.exposeData.filter((item) => item.Id != id);
                this.websiteData = this.websiteData.filter((item) => item.Id != id);
                this.portalData = this.portalData.filter((item) => item.Id != id);
                const updatedData = this.data.map(item => {
                    if (item.Id === id) {
                        return { ...item, ['MVEX__IsOnExpose__c']: false, ['MVEX__IsOnWebsite__c']: false, ['MVEX__IsOnPortalFeed__c']: false };
                    }
                    return item;
                });

                this.data = updatedData;
            } else if (field == 'MVEX__IsOnWebsite__c') {
                this.websiteData = this.websiteData.filter((item) => item.Id != id);
                const updatedData = this.data.map(item => {
                    if (item.Id === id) {
                        return { ...item, [field]: false };
                    }
                    return item;
                });

                this.data = updatedData;
            } else if (field == 'MVEX__IsOnPortalFeed__c') {
                this.portalData = this.portalData.filter((item) => item.Id != id);
                const updatedData = this.data.map(item => {
                    if (item.Id === id) {
                        return { ...item, [field]: false };
                    }
                    return item;
                });

                this.data = updatedData;
            }
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'deleteIcon', error, 'warn', 'Error while deleting icon');
        }
    }

    /**
    * Method Name: hideMainDiv
    * @description: Used to hide main div.
    * Created Date: 27/06/2024
    * Created By: Karan Singh
    */
    hideMainDiv() {
        try {
            if (this.screenWidth <= 500 && this.isData) {
                this.template.querySelector('.main-div-continer').classList.add("remove-main");
                this.template.querySelector('.img-main-div').classList.add("add-div");
            }
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'hideMainDiv', error, 'warn', 'Error while hiding main div');
        }
    }

    /**
    * Method Name: addMainDiv
    * @description: Used to add main div.
    * Created Date: 27/06/2024
    * Created By: Karan Singh
    */
    addMainDiv() {
        try {
            if (this.screenWidth <= 500 && this.isData) {
                this.template.querySelector('.main-div-continer').classList.remove("remove-main");
                this.template.querySelector('.img-main-div').classList.remove("add-div");
            }
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'addMainDiv', error, 'warn', 'Error while adding main div');
        }
    }

    /**
    * Method Name: deleteFileInAWS
    * @description: Used to delete file in AWS.
    * Created Date: 27/06/2024
    * Created By: Karan Singh
    */
    deleteFileInAWS() {
        try {
            if (this.FileNameInAWS != undefined) {
                this.initializeAwsSdk(this.confData);
                const oldKey = this.FileNameInAWS.replace(/\s+/g, "_").toLowerCase();
                const bucketName = this.confData.MVEX__S3_Bucket_Name__c;
                
                this.s3.deleteObject({
                    Bucket: bucketName,
                    Key: oldKey,
                }).promise().then(() => {
                    errorDebugger('ImagesAndMedia', 'deleteFileInAWS', null, 'info', 'File deleted successfully in S3.'); 
                }).catch((error) => {
                    errorDebugger('ImagesAndMedia', 'deleteFileInAWS', error, 'warn', 'Error while deleting file in AWS');
                });
            }
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'deleteFileInAWS', error, 'warn', 'Error while deleting file in AWS');
        }
    }
    
    /**
    * Method Name: deleteAllFilesInAWS
    * @description: Used to delete all files in AWS.
    * Created Date: 27/06/2024
    * Created By: Karan Singh
    */
    deleteAllFilesInAWS() {
        try {
            if (this.fileListToDelete.length > 0) {
                this.initializeAwsSdk(this.confData);
                const allFileNames = [...this.fileListToDelete];
                const bucketName = this.confData.MVEX__S3_Bucket_Name__c;
    
                const deletePromises = allFileNames.map((fileName) => {
                    const oldKey = fileName.replace(/\s+/g, "_").toLowerCase();
                    return this.s3.deleteObject({
                        Bucket: bucketName,
                        Key: oldKey,
                    }).promise();
                });
    
                Promise.all(deletePromises)
                    .then(() => {
                        this.fileListToDelete = [];
                    })
                    .catch((error) => {
                        errorDebugger('ImagesAndMedia', 'deleteAllFilesInAWS', error, 'warn', 'Error while deleting all files in AWS');
                    });
            }
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'deleteAllFilesInAWS', error, 'warn', 'Error while deleting all files in AWS');
        }
    }
    
    /**
    * Method Name: initializeAwsSdk
    * @description: Used to initialize aws sdk.
    * @param {object} confData - The configuration data to initialize the AWS SDK.
    * Created Date: 27/06/2024
    * Created By: Karan Singh
    */
    initializeAwsSdk(confData) {
        try {
            let AWS = window?.globalThis?.AWS;

            AWS.config.update({
                accessKeyId: confData.MVEX__AWS_Access_Key__c,
                secretAccessKey: confData.MVEX__AWS_Secret_Access_Key__c
            });

            AWS.config.region = confData.MVEX__S3_Region_Name__c;

            this.s3 = new AWS.S3({
                apiVersion: "2006-03-01",
                params: {
                    Bucket: confData.MVEX__S3_Bucket_Name__c
                }
            });

        } catch (error) {
            errorDebugger('ImagesAndMedia', 'initializeAwsSdk', error, 'warn', 'Error while initializing AWS SDK');
        }
    }

    /**
    * Method Name: getS3ConfigDataAsync
    * @description: Used to get s3 config data.
    * Created Date: 27/06/2024
    * Created By: Karan Singh
    */
    getS3ConfigDataAsync() {
        try {
            getS3ConfigSettings()
                .then(result => {
                    if (result.status) {
                        this.confData = result.awsConfigData;
                    } else {
                        this.showToast('Error', 'No Data Found.', 'error');
                    }
                }).catch(error => {
                    this.showToast('Error', error, 'error');
                    errorDebugger('ImagesAndMedia', 'getS3ConfigDataAsync', error, 'warn', 'Error while getting S3 config data');
                });
        } catch (error) {
            errorDebugger('ImagesAndMedia', 'getS3ConfigDataAsync', error, 'warn', 'Error while getting S3 config data');
        }
    }
}