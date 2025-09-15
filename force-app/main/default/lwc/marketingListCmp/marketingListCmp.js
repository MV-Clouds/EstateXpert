import { LightningElement, track, api } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import designcss from '@salesforce/resourceUrl/listingManagerCss';
import getMetadataRecords from '@salesforce/apex/ControlCenterController.getMetadataRecords';
import getContactData from '@salesforce/apex/MarketingListCmpController.getContactData';
import getListViewId from '@salesforce/apex/MarketingListCmpController.getListViewId';
import { NavigationMixin } from 'lightning/navigation';
import sendEmail from '@salesforce/apex/MarketingListCmpController.sendEmail';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import summerNote_Editor from '@salesforce/resourceUrl/summerNoteEditor';
import getQuickTemplates from '@salesforce/apex/EmailCampaignController.getQuickTemplates';
import processBroadcastMessageWithObject from '@salesforce/apex/MarketingListCmpController.processBroadcastMessageWithObject';
import getMessagingServiceOptions from '@salesforce/apex/EmailCampaignController.getMessagingServiceOptions';
import getTemplatesByObject from '@salesforce/apex/BroadcastMessageController.getTemplatesByObject';
import createChatRecods from '@salesforce/apex/BroadcastMessageController.createChatRecods';

export default class MarketingListCmp extends NavigationMixin(LightningElement) {
    @api objectName = 'Contact';
    @api recordId;
    @track addModal = false;
    @track spinnerShow = true;
    @track showList = true
    @track showTile = false;
    @track contactData = [];
    @track fields = [];
    @track processedContactData = [];
    @track unchangedProcessContact = [];
    @track sortField = '';
    @track sortOrder = 'asc';
    @track totalSelected = 0;
    @track isPrevDisabled = true;
    @track isNextDisabled = false;
    @track pageNumber = 1;
    @track pageSize = 30;
    @track shownProcessedContactData = [];
    @track isModalOpen = false;
    @track selectedContactList = [];
    @track isContactSelected = true;

    //new variables
    @track wrapOn = false;
    @track screenWidth = 0;
    @track currentPage = 1;
    @track visiblePages = 5;
    @track fieldsModal = false;
    @track mobileAddModal = false;

    // rachit changes
    @track isMassEmailModalOpen = false;
    @track sendMethod = '';
    @track selectedTemplate = '';
    @track isTemplateBody = false;
    @track isFirstScreen = true;
    @track footerButtonLabel = 'Next';

    @track messageOptions = [];

    @track getQuickTemplates = [];
    @track showTemplate = false;
    @track isMainModal = true;

    @track messageText = '';
    @track broadcastGroupName = '';
    @track tempBroadcastGroupName = '';
    @track listViewId = '';

    @track popUpFirstPage = true;
    @track popUpSecondPage = false;
    @track popUpLastPage = false;
    @track popupHeader = 'Create Broadcast Group';
    @track templateOptions = [];
    @track selectedDateTime = '';
    @track selectedObject = 'Contact';
    @track broadcastGroupId = null;
    @track templateMap = new Map();
    @track isAccessible = false;

    /**
    * Method Name : totalPages
    * @description : set the totalpages count.
    * * Date: 20/08/2024
    * Created By:Vyom Soni
    */
    get totalItems() {
        return this.processedContactData.length;
    }

    /**
    * Method Name : totalPages
    * @description : set the totalpages count.
    * * Date: 20/08/2024
    * Created By:Vyom Soni
    */
    get totalPages() {
        return Math.ceil(this.totalItems / this.pageSize);
    }

    /**
    * Method Name : showEllipsis
    * @description : show the elipsis when the total pages is gretaer then the visible pages.
    * * Date: 20/08/2024
    * Created By:Vyom Soni
    */
    get showEllipsis() {
        return Math.ceil(this.totalItems / this.pageSize) > this.visiblePages;
    }

    /**
    * Method Name : isFirstPage
    * @description : check the current page is first.
    * * Date: 20/08/2024
    * Created By:Vyom Soni
    */
    get isFirstPage() {
        return this.currentPage === 1;
    }

    /**
    * Method Name : isLastPage
    * @description : check the current page is last.
    * * Date: 20/08/2024
    * Created By:Vyom Soni
    */
    get isLastPage() {
        return this.currentPage === Math.ceil(this.totalItems / this.pageSize);
    }

    /**
    * Method Name : startIndex
    * @description : set the start Index.
    * * Date: 20/08/2024
    * Created By:Vyom Soni
    */
    get startIndex() {
        return (this.currentPage - 1) * this.pageSize + 1;
    }

    /**
    * Method Name : endIndex
    * @description : set the end Index.
    * * Date: 20/08/2024
    * Created By:Vyom Soni
    */
    get endIndex() {
        return Math.min(this.currentPage * this.pageSize, this.totalItems);
    }

    /**
    * Method Name : pageNumbers
    * @description : set the list for page number in pagination.
    * * Date: 20/08/2024
    * Created By:Vyom Soni
    */
    get pageNumbers() {
        try {
            const totalPages = this.totalPages;
            const currentPage = this.currentPage;
            const visiblePages = this.visiblePages;

            let pages = [];

            if (totalPages <= visiblePages) {
                // If the total pages are less than or equal to the visible pages, show all
                for (let i = 1; i <= totalPages; i++) {
                    pages.push({
                        number: i,
                        isEllipsis: false,
                        className: `pagination-button ${i === currentPage ? 'active' : ''}`
                    });
                }
            } else {
                // Always show the first page
                pages.push({
                    number: 1,
                    isEllipsis: false,
                    className: `pagination-button ${currentPage === 1 ? 'active' : ''}`
                });

                if (currentPage > 3) {
                    // Show ellipsis if the current page is greater than 3
                    pages.push({ isEllipsis: true });
                }

                // Show the middle pages
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
                    // Show ellipsis if the current page is less than totalPages - 2
                    pages.push({ isEllipsis: true });
                }

                // Always show the last page
                pages.push({
                    number: totalPages,
                    isEllipsis: false,
                    className: `pagination-button ${currentPage === totalPages ? 'active' : ''}`
                });
            }

            return pages;
        } catch (error) {
            console.error('Error pageNumbers->' + error);
            return null;
        }
    }

    /**
    * Method Name : mobileView
    * @description : set the mobile view when the screen width is the less then the 900.
    * * Date: 20/08/2024
    * Created By:Vyom Soni
    */
    get mobileView() {
        return window?.globalThis?.innerWidth <= 900 ? true : false;
    }


    /**
   * Method Name : checkAll
   * @description : handle the checkAll checkbox in list view.
   * Date: 22/06/2024
   * Created By:Vyom Soni
   */
    get checkAll() {
        return this.processedContactData.every(item => item.isChecked);
    }

    /**
   * Method Name : showSection
   * @description : getter for the show no result found text when shownProcessedContactData.length === 0.
   * Date: 22/06/2024
   * Created By:Vyom Soni
   */
    get showSection() {
        return this.shownProcessedContactData.length === 0;
    }

    /**
    * Method Name : sortDescription
    * @description : set the header sort description.
    * Date: 16/07/2024
    * Created By:Vyom Soni
    */
    get sortDescription() {
        try {
            if (this.sortField != '' && this.showTile == false) {
                const orderDisplayName = this.sortOrder === 'asc' ? 'Ascending' : 'Descending';

                let field = null;
                // Assuming `listings` is an array of objects where each object has a `value` and a `label` property
                if (this.sortField != 'Name') {
                    field = this.fields.find(item => item.fieldName === this.sortField);
                } else {
                    field = { fieldName: 'Name', fieldLabel: 'Contact Name' };
                }
                if (!field) {
                    return '';
                }

                const fieldDisplayName = field.fieldLabel;

                return `Sorted by : ${fieldDisplayName} (${orderDisplayName})`;
            }

            return '';
        } catch (error) {
            console.error('Error sortDescription->' + error);
            return null;
        }
    }

    /**
    * Method Name : totalContacts
    * @description : set the total filtered contacts.
    * Date: 16/07/2024
    * Created By:Vyom Soni
    */
    get totalContacts() {
        return this.processedContactData.length;
    }

    /**
    * Method Name : isSelected
    * @description : set value true if any option is true.
    * Date: 16/07/2024
    * Created By:Vyom Soni
    */
    get isSelected() {
        return this.totalSelected > 0;
    }

    /**
    * Method Name : items
    * @description : set 'Items' string when the user select more then 1 options.
    * Date: 16/07/2024
    * Created By:Vyom Soni
    */
    get items() {
        return this.totalSelected > 1 ? 'Items' : 'Item';
    }

    /**
    * Method Name : contactItems
    * @description : set 'Items' when the filtered items is more then the 1  .
    * Date: 16/07/2024
    * Created By:Vyom Soni
    */
    get contactItems() {
        return this.processedContactData.length > 1 ? 'Items' : 'Item';

    }

    /**
     * Method Name : checkAllBroadcast
     * @description : Getter to check if all contacts in the broadcast group table are selected
     * Date: 13/06/2025
     * Created By: [Your Name]
     */
    get checkAllBroadcast() {
        return this.selectedContactList.every(item => item.isChecked);
    }

    /**
     * Method Name : connectedCallback
     * @description : retrieve fields name from the field-set and retrieve Contact records.
     * Date: 22/06/2024
     * Created By:Vyom Soni
     */
    connectedCallback() {
        this.screenWidth = window?.globalThis?.innerWidth;
        window?.globalThis?.addEventListener('resize', this.handleResize);
        loadStyle(this, designcss);
        this.getAccessible();
    }

    getAccessible() {
        getMetadataRecords()
            .then(data => {
                const marketingListFeature = data.find(
                    item => item.DeveloperName === 'Marketing_List'
                );
                this.isAccessible = marketingListFeature ? Boolean(marketingListFeature.MVEX__isAvailable__c) : false;

                if (this.isAccessible) {
                    this.getContactDataMethod();
                    this.loadQuickTemplates();
                    this.loadMessageOptions();
                    this.loadListViewId();
                    this.loadAllTemplates();
                } else {
                    this.spinnerShow = false;
                }
            })
            .catch(error => {
                console.error('Error fetching accessible fields', error);
                this.isAccessible = false;
                this.spinnerShow = false;
            });
    }

    /**
    * Method Name : renderedCallback
    * @description : to display content of templte body.
    * Date: 29/07/2024
    * Created By:Rachit shah
    */
    renderedCallback() {
        try {
            if (!this.isFirstScreen) {
                Promise.all([
                    loadStyle(this, summerNote_Editor + '/summernote-lite-pdf.css'),
                ]).then(() => {
                    const richText = this.template.querySelector('.richText');
                    richText && (richText.innerHTML = this.setTempValue(this.templateBody));
                }).catch(error => {
                    console.error('Error ==> ', error);
                });
            }
        } catch (error) {
            console.error('Error renderedCallback->' + error);
        }
    }

    /**
    * Method Name : disconnectedCallback
    * @description : to display content of templte body.
    * Date: 29/07/2024
    * Created By:Vyom Soni
    */
    disconnectedCallback() {
        window?.globalThis?.removeEventListener('resize', this.handleResize);
    }

    loadAllTemplates() {
        getTemplatesByObject()
            .then(result => {
                this.templateMap = new Map(Object.entries(result));
                this.updateTemplateOptions();
            })
            .catch(error => {
                this.showToast('Error', 'Failed to load templates', 'error');
                console.error('Error loadAllTemplates->', error);
            });
    }

    /**
    * Method Name : loadMessageOptions
    * @description : fetch the message options.
    * Date: 29/07/2024
    * Created By:Vyom Soni
    */
    loadMessageOptions() {
        getMessagingServiceOptions()
            .then(data => {
                this.messageOptions = data.map(option => {
                    return { label: option.label, value: option.value };
                });
            })
            .catch(error => {
                this.showToast('Error', 'Failed to fetch message options', 'error');
            })
    }

    loadListViewId() {
        getListViewId().then(data => {
            this.listViewId = data;
        }).catch(error => {
            this.showToast('Error', 'Failed to load list view id: ' + error.stack, 'error');
        })
    }

    /**
     * Method Name : getContactDataMethod
     * @description : retrieve the Contact data from the salesforce
     * Date: 22/06/2024
     * Created By:Vyom Soni
     */
    getContactDataMethod() {
        this.spinnerShow = true;
        getContactData()
            .then(result => {
                this.contactData = result.contacts;
                this.pageSize = result.pageSize;
                this.fields = result.selectedFields.map(field => ({
                    fieldLabel: field.label,
                    fieldName: field.fieldApiname,
                    cardView: field.cardView,
                    format: field.format
                }));

                this.contactData.forEach((con) => {
                    con.isChecked = false;
                })
                this.processContacts();
            })
            .catch(error => {
                this.spinnerShow = false;
                this.showToast('Error', error.body.message || 'An unknown error occurred', 'error');
            });
    }

    /**
    * Method Name : handleSave
    * @description : method to do save changes
    * Date: 29/07/2024
    * Created By:Rachit Shah
    */
    handleSave() {
        try {
            this.spinnerShow = true;
            const emailData = {
                sendMethod: this.sendMethod,
                templateId: this.selectedTemplate,
                contacts: this.selectedContactList
            };

            sendEmail({ emailDataJson: JSON.stringify(emailData) })
                .then(() => {
                    this.showToast('Success', 'Emails sent successfully!', 'success');
                    this.closeModal();
                })
                .catch(error => {
                    this.showToast('Error', 'Failed to send emails. ' + error.body.message, 'error');
                })
                .finally(() => {
                    this.spinnerShow = false;
                });
        } catch (error) {
            this.spinnerShow = false;
        }
    }

    convertKeysToLowercase(obj) {
        if (obj && typeof obj === 'object') {
            if (Array.isArray(obj)) {
                return obj.map(item => this.convertKeysToLowercase(item));
            } else {
                return Object.keys(obj).reduce((acc, key) => {
                    const newKey = key.toLowerCase();
                    acc[newKey] = this.convertKeysToLowercase(obj[key]);
                    return acc;
                }, {});
            }
        }
        return obj;
    }

    /**
    * Method Name : processContacts
    * @description : set the contact data inorder of the fields data
    * Date: 22/06/2024
    * Created By:Vyom Soni
    */
    processContacts() {
        try {
            this.processedContactData = this.contactData.map(con => {
                let orderedFields = this.fields.map(field => {
                    // Handle reference fields (e.g., Contact_r.LastName)
                    let fieldValue;
                    if (field.fieldName.includes('.')) {
                        // Split the reference field name into relationship and field (e.g., Contact_r.LastName)
                        let fieldParts = field.fieldName.split('.');
                        let relatedObject = con[fieldParts[0]]; // Get the related object (e.g., Contact_r)
                        fieldValue = relatedObject ? relatedObject[fieldParts[1]] : ''; // Get the related field (e.g., LastName)
                    } else {
                        fieldValue = con[field.fieldName] || ''; // Regular field
                    }

                    if (field.format && fieldValue) {
                        fieldValue = this.applyFieldFormat(fieldValue, field.format); // Apply the appropriate format
                    }

                    return {
                        fieldName: field.fieldName,
                        value: fieldValue // Use the calculated field value
                    };
                });

                let cardViewFields = this.fields
                    .filter(field => field.cardView === 'true')
                    .map(field => {
                        let fieldValue;
                        if (field.fieldName.includes('.')) {
                            let fieldParts = field.fieldName.split('.');
                            let relatedObject = con[fieldParts[0]];
                            fieldValue = relatedObject ? relatedObject[fieldParts[1]] : '';
                        } else {
                            fieldValue = con[field.fieldName] || '';
                        }

                        if (field.format && fieldValue) {
                            fieldValue = this.applyFieldFormat(fieldValue, field.format); // Apply the appropriate format
                        }

                        return {
                            fieldName: field.fieldLabel,
                            value: fieldValue
                        };
                    });
                return {
                    ...con,
                    isChecked: con.isChecked,
                    cardViewFields,
                    orderedFields
                };
            });
            this.unchangedProcessContact = this.processedContactData;
            this.updateShownData();
            this.spinnerShow = false;
        } catch (error) {
            console.error('Error processContacts->' + error);
        }
    }

    // Method to apply formatting based on the format value from dateOptions and dateTimeOptions
    applyFieldFormat(fieldValue, format) {
        let date = new Date(fieldValue);
        let day = String(date.getDate()).padStart(2, '0');
        let month = String(date.getMonth() + 1).padStart(2, '0'); // Months are zero-based in JS
        let year = date.getFullYear();
        let hours24 = String(date.getHours()).padStart(2, '0');
        let minutes = String(date.getMinutes()).padStart(2, '0');
        let hours12 = hours24 > 12 ? String(hours24 - 12).padStart(2, '0') : hours24;
        let period = hours24 >= 12 ? 'PM' : 'AM';

        switch (format) {
            // Date formats
            case 'ddmmyyyy':
                return `${day}-${month}-${year}`;
            case 'mmddyyyy':
                return `${month}-${day}-${year}`;
            case 'yyyymmdd':
                return `${year}-${month}-${day}`;

            // DateTime 24-hour formats
            case 'ddmmyyy24':
                return `${day}-${month}-${year} ${hours24}:${minutes}`;
            case 'mmddyyyy24':
                return `${month}-${day}-${year} ${hours24}:${minutes}`;
            case 'yyyymmdd24':
                return `${year}-${month}-${day} ${hours24}:${minutes}`;

            // DateTime 12-hour formats
            case 'ddmmyyy12':
                return `${day}-${month}-${year} ${hours12}:${minutes} ${period}`;
            case 'mmddyyyy12':
                return `${month}-${day}-${year} ${hours12}:${minutes} ${period}`;
            case 'yyyymmdd12':
                return `${year}-${month}-${day} ${hours12}:${minutes} ${period}`;

            default:
                return fieldValue; // Return unformatted value if no match
        }
    }

    /**
    * Method Name : handleResize
    * @description : call when component is resize.
    * * Date: 3/06/2024
    * Created By:Vyom Soni
    */
    handleResize = () => {
        this.screenWidth = window?.globalThis?.innerWidth;
    }

    /**
    * Method Name : updateShownData
    * @description : update the shownProcessedLisitingData when pagination is applied.
    * date: 20/08/2024
    * Created By:Vyom Soni
    */
    updateShownData() {
        try {
            const startIndex = (this.currentPage - 1) * this.pageSize;
            const endIndex = Math.min(startIndex + this.pageSize, this.totalItems);
            this.shownProcessedContactData = this.processedContactData.slice(startIndex, endIndex);
        } catch (error) {
            console.error('Error updateShownData->' + error);
        }
    }

    /**
    * Method Name : handlePrevious
    * @description : handle the previous button click in the pagination.
    * date: 20/08/2024
    * Created By:Vyom Soni
    */
    handlePrevious() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.updateShownData();
            this.scrollToTop();
            this.sortData();
        }
    }

    /**
    * Method Name : handleNext
    * @description : handle the next button click in the pagination.
    * date: 20/08/2024
    * Created By:Vyom Soni
    */
    handleNext() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
            this.updateShownData();
            this.scrollToTop();
            this.sortData();
        }
    }

    /**
    * Method Name : handlePageChange
    * @description : handle the direct click on page number.
    * date: 20/08/2024
    * Created By:Vyom Soni
    */
    handlePageChange(event) {
        const selectedPage = parseInt(event.target.getAttribute('data-id'), 10);
        if (selectedPage !== this.currentPage) {
            this.currentPage = selectedPage;
            this.updateShownData();
            this.scrollToTop();
            this.sortData();
        }
    }


    /**
    * Method Name : handleFilteredContacts
    * @description : set the data comming from the filter cmp
    *  Date: 22/06/2024
    * Created By:Vyom Soni
    */
    handleFilteredContacts(event) {
        try {
            this.sortField = '';
            this.sortOrder = 'asc';

            // Reset all icons to remove rotation classes
            const allHeaders = this.template.querySelectorAll('.slds-icon-utility-arrowdown svg');
            allHeaders.forEach(icon => icon.classList.remove('rotate-asc', 'rotate-desc'));

            // Deselect all items in processedListingData and unchangedProcessListings
            const resetCheckedFlag = item => ({ ...item, isChecked: false });
            this.processedContactData = this.processedContactData.map(resetCheckedFlag);
            this.unchangedProcessContact = this.unchangedProcessContact.map(resetCheckedFlag);

            // Apply filtered listings
            const filteredListingIds = new Set(event.detail.filtercontacts.map(filtered => filtered.Id));
            this.processedContactData = this.unchangedProcessContact.filter(processListing =>
                filteredListingIds.has(processListing.Id)
            );

            // Reset current page and update view
            this.currentPage = 1;
            this.updateShownData();
            this.updateSelectedProperties();
        } catch (e) {
            console.error('handleFilteredContacts' + e);
        }
    }

    handleReset(event) {
        try {
            if (event.detail.filtercontacts == true) {
                this.sortField = '';
                this.sortOrder = 'asc';

                // Reset all icons to remove rotation classes
                const allHeaders = this.template.querySelectorAll('.slds-icon-utility-arrowdown svg');
                allHeaders.forEach(icon => icon.classList.remove('rotate-asc', 'rotate-desc'));

                // Deselect all items in processedListingData and unchangedProcessListings
                const resetCheckedFlag = item => ({ ...item, isChecked: false });
                this.processedContactData = this.processedContactData.map(resetCheckedFlag);
                this.unchangedProcessContact = this.unchangedProcessContact.map(resetCheckedFlag);
                this.processedContactData = this.unchangedProcessContact;
                this.currentPage = 1;
                this.updateShownData();
                this.updateSelectedProperties();
            }
        } catch (error) {
            console.error('Error -> handleFilteredListings' + error);
        }
    }

    handlAddModalChange(event) {
        this.fieldsModal = event.detail;
    }

    /**
    * Method Name : handleContactSelect
    * @description : handle data from the tile cmp
    *  Date: 22/06/2024
    * Created By:Vyom Soni
    * 
    */
    handleContactSelect(event) {
        try {
            this.processedContactData = event.detail;
            this.updateShownData();
            this.updateSelectedProperties();
            this.selectedContactList = this.processedContactData.filter(item => item.isChecked == true);
            this.isContactSelected = this.selectedContactList.length <= 0;
        } catch (error) {
            console.error('Error handleContactSelect->' + error);
        }
    }

    /**
    * Method Name : handleMenuTabClick
    * @description : handle the menu clicks in the header
    * Date: 22/06/2024
    * Created By:Vyom Soni
    */
    handleMenuTabClick(evt) {
        try {
            let target = evt.currentTarget.dataset.tabId;
            this.showList = false;
            this.showTile = false;
            if (target == "1") {
                this.showList = true;
            } else if (target == "2") {
                this.showTile = true;
            }

            this.template.querySelectorAll(".tab-div").forEach(tabEl => {
                tabEl.classList.remove("active-tab-div");
                const pathEl = tabEl.querySelector('path');
                if (pathEl) {
                    pathEl.style.fill = '#131314';
                }
            });

            // Add active class and set fill color for the selected tab
            const selectedTab = this.template.querySelector(`[data-tab-id="${target}"]`);
            selectedTab.classList.add("active-tab-div");
            const selectedPath = selectedTab.querySelector('path[data-tab-index="' + target + '"]');
            if (selectedPath) {
                selectedPath.style.fill = '#fff';
            }
        } catch (error) {
            console.error('Error handleMenuTabClick->' + error);
        }
    }

    /**
    * Method Name : redirectToRecord
    * @description : redirect to contact record recordPage
    * Date: 22/06/2024
    * Created By:Vyom Soni
    */
    redirectToRecord(event) {
        const recordId = event.target.dataset.id;
        if (this.screenWidth > 900) {
            this[NavigationMixin.GenerateUrl]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: recordId,
                    objectApiName: 'Contact',
                    actionName: 'view'
                }
            }).then(url => {
                window?.globalThis?.open(url, '_blank');
            });
        } else {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: recordId,
                    objectApiName: 'Contact', // Object API Name
                    actionName: 'view'
                }
            });
        }
    }

    /**
    * Method Name : checkBoxValueChange
    * @description : handle the checkbox change
    * Date: 22/06/2024
    * Created By:Vyom Soni
    */
    checkBoxValueChange(event) {
        try {
            const checkboxId = Number(event.target.dataset.id);
            this.shownProcessedContactData[checkboxId].isChecked = event.target.checked;
            this.processedContactData.forEach(item1 => {
                this.shownProcessedContactData.forEach(item2 => {
                    if (item1.Id == item2.Id) {
                        item1.isChecked = item2.isChecked;
                    }
                })
            })

            this.selectedContactList = this.processedContactData.filter(item => item.isChecked == true);

            this.isContactSelected = this.selectedContactList.length <= 0;

            this.unchangedProcessContact.forEach(item1 => {
                this.shownProcessedContactData.forEach(item2 => {
                    if (item1.Id == item2.Id) {
                        item1.isChecked = item2.isChecked;
                    }
                })
            })
            this.updateSelectedProperties();
        } catch (e) {
            console.error('Error checkCoxValueChange ->' + e);
        }
    }

    /**
    * Method Name : selectAllCheckbox
    * @description : select the all checkbox
    * Date: 22/06/2024
    * Created By:Vyom Soni
    */
    selectAllCheckbox(event) {
        try {
            const isChecked = event.target.checked;
            this.sortField = '';
            this.sortOrder = 'asc';
            const allHeaders = this.template.querySelectorAll('.slds-icon-utility-arrowdown svg');
            allHeaders.forEach(icon => {
                icon.classList.remove('rotate-asc', 'rotate-desc');
            });
            this.processedContactData = this.processedContactData.map(item => {
                return { ...item, isChecked: isChecked };
            });

            if (isChecked) {
                this.selectedContactList = this.processedContactData;
                this.isContactSelected = false;
            }
            else {
                this.selectedContactList = [];
                this.isContactSelected = true;
            }

            this.unchangedProcessContact = this.unchangedProcessContact.map(item => {
                return { ...item, isChecked: isChecked };
            });
            this.updateShownData();
            this.updateSelectedProperties();
        } catch (error) {
            console.error('Error selectAllCheckbox->' + error);
        }
    }


    /**
    * Method Name : goTOContactPage
    * @description : Open Modal for new contact form
    * Date: 18/07/2024
    * Created By:Vyom Soni
    */
    goTOContactPage() {
        try {
            this[NavigationMixin.Navigate]({
                type: 'standard__objectPage',
                attributes: {
                    objectApiName: 'Contact',
                    actionName: 'new'
                },
                state: {
                    c__customParam: 'MarketingList' // Add your custom parameter here
                }
            });
        } catch (error) {
            console.error('Error in goTOContactPage --> ' + error);
        }
    }

    /**
    * Method Name : newContactHandle
    * @description : Redirect the marketing list component after contact is created
    * Date: 18/07/2024
    * Created By:Vyom Soni
    */
    newContactHandle() {
        var cmpDef;
        cmpDef = {
            componentDef: 'MVEX:marketingListCmp',
        };

        let encodedDef = btoa(JSON.stringify(cmpDef));
        this[NavigationMixin.Navigate]({
            type: "standard__webPage",
            attributes: {
                url: "/one/one.app#" + encodedDef
            }
        });
    }

    /**
    * Method Name : handleClose
    * @description : close Modal for new contact form
    * Date: 18/07/2024
    * Created By:Vyom Soni
    */
    handleClose() {
        this.addModal = false;
        if (this.mobileView == true) {
            this.mobileAddModal = false;
        }
    }

    /**
    * Method Name : updateSelectedProperties
    * @description : update the properties as selected
    * Date: 22/06/2024
    * Created By:Vyom Soni
    */
    updateSelectedProperties() {
        this.selectedContactList = this.processedContactData.filter(con => con.isChecked);
        this.totalSelected = this.selectedContactList.length;
        this.isContactSelected = this.selectedContactList.length <= 0;
    }

    /**
    * Method Name : sortClick
    * @description : this methods apply the sorting on the all fields
    * Date: 22/06/2024
    * Created By:Vyom Soni
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
            this.updateShownData();
        } catch (error) {
            console.error('Error sortClick->' + error);
        }
    }

    /**
    * Method Name : sortData
    * @description : this methods apply the sorting on the all fields
    * Date: 22/06/2024
    * Created By:Vyom Soni
    */
    sortData() {
        try {
            this.processedContactData = [...this.processedContactData].sort((a, b) => {
                let aValue, bValue;

                if (this.sortField === 'Name') {
                    aValue = a.Name;
                    bValue = b.Name;
                } else {
                    aValue = a.orderedFields.find(field => field.fieldName === this.sortField).value;
                    bValue = b.orderedFields.find(field => field.fieldName === this.sortField).value;
                }

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
        } catch (error) {
            console.error('Error sortData->' + error);
        }

    }

    /**
    * Method Name : handleAdd
    * @description : this method open the modal
    * Date: 20/07/2024
    * Created By:Vyom Soni
    */
    handleAdd() {
        this.isModalOpen = true;
    }

    /**
    * Method Name : handleModalClose
    * @description : this method close the modal
    * Date: 20/07/2024
    * Created By:Vyom Soni
    */
    handleModalClose() {
        this.isModalOpen = false;
    }

    /**
    * Method Name : updateSortIcons
    * @description : this method update the sort icons in the wrapbutton
    * Date: 22/06/2024
    * Created By:Vyom Soni
    */
    updateSortIcons() {
        try {
            const allHeaders = this.template.querySelectorAll('.slds-icon-utility-arrowdown svg');
            allHeaders.forEach(icon => {
                icon.classList.remove('rotate-asc', 'rotate-desc');
            });

            const currentHeader = this.template.querySelector('[data-index="' + this.sortField + '"]');
            if (currentHeader) {
                currentHeader.classList.add(this.sortOrder === 'asc' ? 'rotate-asc' : 'rotate-desc');
            }
        } catch (error) {
            console.error('Error updateSprtIcons->' + error);
        }
    }

    /**
    * Method Name : scrollToTop
    * @description : scroll to top in list
    * Date: 22/06/2024
    * Created By:Vyom Soni
    */
    scrollToTop() {
        try {
            const tableDiv = this.template.querySelector('.tableDiv');
            if (tableDiv) {
                tableDiv.scrollTop = 0;
            }
        } catch (error) {
            console.error('Error scrollToTop->' + error);
        }
    }

    /**
    * Method Name : cancelRecordForm
    * @description : method to cancel the new contact modal
    * Date: 29/07/2024
    * Created By:Vyom Soni
    */
    cancelRecordForm() {
        this.handleClose();
    }

    /**
    * Method Name : openModal
    * @description : method to open modal
    * Date: 29/07/2024
    * Created By:Rachit Shah
    */
    openModal() {
        this.isMassEmailModalOpen = true;
        this.isFirstScreen = true;
        this.footerButtonLabel = 'Next';
    }

    /**
    * Method Name : closeModal
    * @description : method to close modal
    * Date: 29/07/2024
    * Created By:Rachit Shah
    */
    closeModal() {
        this.isMassEmailModalOpen = false;
        this.templateBody = '';
        this.sendMethod = '';
        this.selectedTemplate = '';
    }

    /**
    * Method Name : handleSendMethodChange
    * @description : method to handle sender mode
    * Date: 29/07/2024
    * Created By:Rachit Shah
    */
    handleSendMethodChange(event) {
        this.sendMethod = event.detail.value;
    }

    /**
    * Method Name : loadQuickTemplates
    * @description : method to load contacts
    * Date: 29/07/2024
    * Created By:Rachit Shah
    */
    loadQuickTemplates() {
        getQuickTemplates()
            .then(result => {
                this.getQuickTemplates = [
                    { label: 'None', value: '', body: '' },
                    ...result.marketingTemplates.map(option => {
                        return { label: option.templateName, value: option.templateId, body: option.body };
                    })
                ];
            })
            .catch(error => {
                console.error('Error loading Gmail template options stack', error.stack);
            });
    }

    /**
    * Method Name : handleGmailTemplateChange
    * @description : method to handle template change
    * Date: 29/07/2024
    * Created By:Rachit Shah
    */
    handleGmailTemplateChange(event) {
        try {
            this.selectedTemplate = event.detail.value;
            const selectedOption = this.getQuickTemplates.find(option => option.value === this.selectedTemplate);
            if (selectedOption.label == 'None') {
                this.isTemplateBody = false;
            }
            else {
                this.isTemplateBody = true;
                this.templateBody = selectedOption ? selectedOption.body : '';
            }
        } catch (error) {
            console.error('Error handleGmailTemplateChange->' + error);
        }
    }

    /**
    * Method Name : handleFooterButtonClick
    * @description : method to check validation and call save method
    * Date: 29/07/2024
    * Created By:Rachit Shah
    */
    handleFooterButtonClick() {
        try {
            if (this.isFirstScreen) {
                if (!this.sendMethod || !this.selectedTemplate) {
                    this.showToast('Error', 'Please Ensure all required fields are filled', 'error');
                    return;
                }
                this.isFirstScreen = false;
                this.footerButtonLabel = 'Save';
            } else {
                this.handleSave();
            }
        } catch (error) {
            console.error('Error handleFooterButtonClick->' + error);
        }
    }

    /**
    * Method Name : handleBack
    * @description : method to go in previous sreen
    * Date: 29/07/2024
    * Created By:Rachit Shah
    */
    handleBack() {
        this.isFirstScreen = true;
    }

    /**
    * Method Name : showToast
    * @description : show the toast message
    * Date: 29/07/2024
    * Created By:Rachit Shah
    */
    showToast(title, message, variant) {
        const toastEvent = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        if (!import.meta.env.SSR) {
            this.dispatchEvent(toastEvent);
        }
    }

    /**
    * Method Name : setTempValue
    * @description : method to set value for the body
    * Date: 29/07/2024
    * Created By:Rachit Shah
    */
    setTempValue(value) {
        return `<div class=" note-editor2 note-frame2">
                    <div class="note-editing-area2">
                        <div aria-multiline="true" role="textbox" class="note-editable2">
                            ${value}
                        </div>
                    </div>
                </div>`
    }

    /**
   * Method Name : wrapFilter
   * @description : this method is used for the wrap the filter
   * date: 3/06/2024
   * Created By:Vyom Soni
   */
    wrapFilter() {
        try {
            if (this.wrapOn) {
                const svgElement = this.template.querySelector('.innerDiv1 .filterWrap svg');
                svgElement.classList.remove('svgRotate');

                const filterDiv = this.template.querySelector('.innerDiv1 .filterDiv');
                filterDiv.classList.remove('removeInnerDiv1');

                if (this.screenWidth >= 900) {
                    const div1 = this.template.querySelector('.innerDiv1');
                    div1.style.width = '22%';
                    div1.style.height = '100%';
                    const div2 = this.template.querySelector('.innerDiv2');
                    div2.style.width = '78%';
                    div2.style.height = '100%';
                } else {
                    const div1 = this.template.querySelector('.innerDiv1');
                    div1.style.height = 'fit-content';
                    div1.style.width = '100%';
                    const div2 = this.template.querySelector('.innerDiv2');
                    div2.style.height = '30rem';
                    div2.style.width = '100%';
                }
                this.wrapOn = false;
            } else {
                const svgElement = this.template.querySelector('.innerDiv1 .filterWrap svg');
                svgElement.classList.add('svgRotate');

                const filterDiv = this.template.querySelector('.innerDiv1 .filterDiv');
                filterDiv.classList.add('removeInnerDiv1');

                if (this.screenWidth >= 900) {
                    const div1 = this.template.querySelector('.innerDiv1');
                    div1.style.width = 'fit-content';
                    div1.style.height = '100%';
                    const div2 = this.template.querySelector('.innerDiv2');
                    div2.style.height = '100%';
                    div2.style.width = '100%';
                } else {
                    const div1 = this.template.querySelector('.innerDiv1');
                    div1.style.height = 'fit-content';
                    div1.style.width = '100%';
                    const div2 = this.template.querySelector('.innerDiv2');
                    div2.style.height = '100%';
                    div2.style.width = '100%';
                }

                this.wrapOn = true;
            }
        } catch (error) {
            console.error('Error wrapFilter->' + error);
        }
    }

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
            console.error('error--> ', error);
        }
    }

    handleRecordManager() {
        let componentDef = {
            componentDef: "MVEX:recordConfigBodyCmp",
            attributes: {
                customParam: 'MarketingList'
            }
        };

        let encodedComponentDef = btoa(JSON.stringify(componentDef));
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: '/one/one.app#' + encodedComponentDef
            }
        });

    }

    updateTemplateOptions() {
        if (!this.selectedObject || this.templateMap.size === 0) {
            this.templateOptions = [];
            return;
        }

        let combinedTemplates = [];

        // Add object-specific templates
        if (this.templateMap.has(this.selectedObject)) {
            combinedTemplates = [...this.templateMap.get(this.selectedObject)];
        }

        // Add Generic templates
        if (this.templateMap.has('Generic')) {
            combinedTemplates = [...combinedTemplates, ...this.templateMap.get('Generic')];
        }

        // Convert to combobox options format
        this.templateOptions = combinedTemplates.map(template => ({
            label: template.Template_Name__c,
            value: template.Id
        }));
    }

    handleInputChange(event) {
        const { name, value } = event.target;
        switch (name) {
            case 'name':
                this.broadcastGroupName = value;
                break;
            case 'message':
                this.messageText = value;
                break;
            case 'template':
                this.selectedTemplate = value;
                break;
            case 'dateTime':
                this.selectedDateTime = value;
                break;
            default:
                console.warn(`Unexpected input name: ${name}`);
        }
    }

    // Handle send message button click
    handleSendMessage() {
        this.showTemplate = true;
        this.popUpFirstPage = true;
        this.popUpSecondPage = false;
        this.popUpLastPage = false;
        this.popupHeader = 'Create Broadcast Group';
        this.broadcastGroupName = '';
        this.messageText = '';
        this.selectedTemplate = '';
        this.selectedDateTime = '';
    }

    // Handle closing the template modal
    handleCloseTemplate() {
        this.showTemplate = false;
        this.popUpFirstPage = true;
        this.popUpSecondPage = false;
        this.popUpLastPage = false;
        this.popupHeader = 'Create Broadcast Group';
        this.broadcastGroupName = '';
        this.messageText = '';
        this.selectedTemplate = '';
        this.selectedDateTime = '';
        this.broadcastGroupId = null;
    }

    // Handle next button on first page (create broadcast group)
    handleNextOnPopup() {
        if (this.messageText.trim() === '' || this.broadcastGroupName.trim() === '') {
            this.showToast('Error', 'Please fill in all required fields', 'error');
            return;
        }

        if (this.tempBroadcastGroupName == this.broadcastGroupName) {
            this.popUpFirstPage = false;
            this.popUpSecondPage = true;
            this.popupHeader = 'Choose Template';
            return;
        }

        const phoneNumbers = this.selectedContactList
            .map(contact => contact.Phone)
            .filter(phone => phone);

        const messageData = {
            objectApiName: this.selectedObject,
            listViewName: this.listViewId,
            phoneNumbers: phoneNumbers,
            description: this.messageText,
            name: this.broadcastGroupName,
            isUpdate: false,
            broadcastGroupId: null,
            phoneField: 'Phone'
        };

        this.spinnerShow = true;

        processBroadcastMessageWithObject({ requestJson: JSON.stringify(messageData) })
            .then(result => {
                this.broadcastGroupId = result; // Assuming Apex returns the created Broadcast Group ID
                this.showToast('Success', 'Broadcast group created successfully', 'success');
                this.popUpFirstPage = false;
                this.popUpSecondPage = true;
                this.popupHeader = 'Choose Template';
                this.tempBroadcastGroupName = this.broadcastGroupName;
                this.updateTemplateOptions();
            })
            .catch(error => {
                this.showToast('Error', error.body?.message || 'Failed to create broadcast group', 'error');
                console.error('Error handleNextOnPopup->', error);
            })
            .finally(() => {
                this.spinnerShow = false;
            });
    }

    // Handle previous button on second page
    handlePreviousOnPopup() {
        this.popUpFirstPage = true;
        this.popUpSecondPage = false;
        this.popupHeader = 'Create Broadcast Group';
        this.selectedTemplate = '';
    }

    // Handle send button on second page
    handleSendOnPopup() {
        if (!this.selectedTemplate) {
            this.showToast('Error', 'Please select a template', 'error');
            return;
        }

        this.spinnerShow = true;

        createChatRecods({
            templateId: this.selectedTemplate,
            groupIds: [this.broadcastGroupId],
            isScheduled: false,
            timeOfMessage: ''
        })
            .then(result => {
                if (result === 'Success') {
                    this.showToast('Success', 'Broadcast sent successfully', 'success');
                    this.handleCloseTemplate();
                } else {
                    this.showToast('Error', `Broadcast failed: ${result}`, 'error');
                }
            })
            .catch(error => {
                this.showToast('Error', `Broadcast failed: ${error.body?.message || error.message}`, 'error');
                console.error('Error handleSendOnPopup->', error);
            })
            .finally(() => {
                this.spinnerShow = false;
            });
    }

    // Handle schedule button on second page
    handleSchedulePopup() {
        if (!this.selectedTemplate) {
            this.showToast('Error', 'Please select a template', 'error');
            return;
        }

        this.popUpSecondPage = false;
        this.popUpLastPage = true;
        this.popupHeader = 'Select Date and Time';
    }

    // Handle previous button on last page
    handlePreviousLastPage() {
        this.popUpSecondPage = true;
        this.popUpLastPage = false;
        this.popupHeader = 'Choose Template';
    }

    // Handle schedule and send button on last page
    handleSchedule() {
        if (!this.selectedDateTime) {
            this.showToast('Error', 'Please select date and time', 'error');
            return;
        }

        const selectedTime = new Date(this.selectedDateTime);
        const now = new Date();

        if (selectedTime < now) {
            this.showToast('Error', 'Selected date and time cannot be in the past', 'error');
            return;
        }

        this.spinnerShow = true;

        createChatRecods({
            templateId: this.selectedTemplate,
            groupIds: [this.broadcastGroupId],
            isScheduled: true,
            timeOfMessage: this.selectedDateTime
        })
            .then(result => {
                if (result === 'Success') {
                    this.showToast('Success', 'Broadcast scheduled successfully', 'success');
                    this.handleCloseTemplate();
                } else {
                    this.showToast('Error', `Scheduling failed: ${result}`, 'error');
                }
            })
            .catch(error => {
                this.showToast('Error', `Scheduling failed: ${error.body?.message || error.message}`, 'error');
                console.error('Error handleSchedule->', error);
            })
            .finally(() => {
                this.spinnerShow = false;
            });
    }

}