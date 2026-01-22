import { LightningElement, track, wire, api } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import getRecords from '@salesforce/apex/PropertySearchController.getRecords';
import getContactsForInquiries from '@salesforce/apex/PropertySearchController.getContactsForInquiries';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getMetadata from '@salesforce/apex/DynamicMappingCmp.getMetadata';
import getFieldMap from '@salesforce/apex/PropertySearchController.getObjectFields';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
import sendEmail from '@salesforce/apex/PropertySearchController.sendEmail';
import summerNoteEditor from '@salesforce/resourceUrl/summerNoteEditor';
import getQuickTemplates from '@salesforce/apex/EmailCampaignController.getQuickTemplates';
import getMessagingServiceOptions from '@salesforce/apex/EmailCampaignController.getMessagingServiceOptions';
import { loadStyle, loadScript } from 'lightning/platformResourceLoader';
import getObjectName from '@salesforce/apex/PropertySearchController.getObjectName';
import getListViewId from '@salesforce/apex/MarketingListCmpController.getListViewId';
import getTemplatesByObject from '@salesforce/apex/BroadcastMessageController.getTemplatesByObject';
import createChatRecods from '@salesforce/apex/BroadcastMessageController.createChatRecods';
import processBroadcastMessageWithObject from '@salesforce/apex/MarketingListCmpController.processBroadcastMessageWithObject';
import { errorDebugger } from 'c/globalProperties';
import getConfigObjectFields from '@salesforce/apex/RecordManagersCmpController.getObjectFields';

export default class displayInquiry extends NavigationMixin(LightningElement) {
    @api recordId;
    @track objectApiName = '';
    @track totalRecords = 0;
    @track inquiries = [];
    @track currentPage = 1;
    @track searchTerm = '';
    @track isLoading = true;
    @track pageSize = 9;
    @track pagedFilteredInquiryData = [];
    @track sendMailInquiryDataList = [];
    @track inquirydata = [];
    @track totalinquiry = [];
    @track isInquiryAvailable = true;
    @track filters = '';
    @track logicalExpression = '';
    @track listingRecord = {};
    @track condtiontype = '';
    @track checkAll = false;

    @track isShowModal = false;

    @track isMassEmailModalOpen = false;
    @track sendMethod = '';
    @track selectedTemplate = '';
    @track selectedListingTemplate = '';
    @track templateBody = '';
    @track isTemplateBody = false;
    @track isFirstScreen = true;
    @track footerButtonLabel = 'Next';
    @track selectedMappingId;

    @track messageOptions = [];

    @track quickTemplates = [];
    @track listingTemplateOptions = [];

    @track selectedConditionType = 'Custom Logic Is Met';
    @track mappings = [];

    @track isAddConditionModalVisible = false;

    @track inquiryFieldObject = {
        'MVEX__Field_Name__c': '',
        'MVEX__Value__c': '',
        'MVEX__Operator__c': '',
        'MVEX__Data_Type__c': '',
        'isPrimary': true,
        'isPicklist': false,
        'isReference': false
    };

    @track selectedConditionOperator = '';
    @track selectedListingField = '';

    @track inquiryFieldOptions = [];
    @track inquirypicklistoptions = [];
    @track conditionOperatorOptions = [
        { label: 'Less Than', value: 'lessThan' },
        { label: 'Greater Than', value: 'greaterThan' },
        { label: 'Equal To', value: 'equalTo' },
        { label: 'Contains', value: 'contains' },
        { label: 'Not Contains', value: 'notContains' },
        { label: 'Not Equal To', value: 'notEqualTo' }
    ];
    @track visiblePages = 5;
    @track divElement;
    @track showTemplate = false;
    @track isMainModal = true;
    @track selectedRecord = false;
    @track templateHeader = '';
    @track templateFooter = '';
    @track isShowSchedule = false;
    @track isShowNextSchedule = false;
    @track selectedDate = '';

    @track vfGeneratePageSRC;

    @track inquiryColumns = [];
    @track defaultColumns = [
        { label: 'Name', fieldName: 'name', type: 'text' },
        { label: 'Listing Type', fieldName: 'mvex__listing_type__c', type: 'text' },
        { label: 'City', fieldName: 'mvex__city__c', type: 'text' },
        { label: 'Min Bedrooms', fieldName: 'mvex__bedrooms_min__c', type: 'number' },
        { label: 'Max Bedrooms', fieldName: 'mvex__bedrooms_max__c', type: 'number' },
        { label: 'Max Bathrooms', fieldName: 'mvex__bathrooms_max__c', type: 'number' },
        { label: 'Min Bathrooms', fieldName: 'mvex__bathrooms_min__c', type: 'number' },
        { label: 'Price', fieldName: 'mvex__price_min__c', type: 'currency' }
    ];

    conditionOptions = [
        { label: 'All Condition Are Met', value: 'All Condition Are Met' },
        { label: 'Any Condition Is Met', value: 'Any Condition Is Met' },
        { label: 'Custom Logic Is Met', value: 'Custom Logic Is Met' },
        { label: 'Related List', value: 'Related List' },
        { label: 'No Filter', value: 'None' },
    ];

    @track broadcastContactList = [];
    @track popUpFirstPage = true;
    @track popUpSecondPage = false;
    @track popUpLastPage = false;
    @track popupHeader = 'Create Broadcast Group';
    @track broadcastGroupName = '';
    @track tempBroadcastGroupName = '';
    @track messageText = '';
    @track selectedDateTime = '';
    @track broadcastGroupId = null;
    @track templateOptions = [];
    @track templateMap = new Map();
    @track selectedObject = 'Contact'; // Default to Contact for messaging
    @track listViewId = '';
    @track spinnerShow = false;

    /**
    * Method Name : isCustomLogicSelected
    * @description : set isCustomLogicSelected field based on condition
    * * Date: 20/08/2024
    * Created By: Rachit Shah
    */
    get isCustomLogicSelected() {
        return this.selectedConditionType === 'Custom Logic Is Met' && this.mappings.length > 0;
    }

    /**
    * Method Name : totalItems
    * @description : set the totalpages count.
    * * Date: 20/08/2024
    * Created By:Vyom Soni
    */
    get totalItems() {
        return this.pagedFilteredInquiryData.length;
    }

    /**
    * Method Name : totalSelectedItems
    * @description : set the total selected items count.
    * * Date: 20/08/2024
    * Created By:Rachit Shah
    */
    get totalSelectedItems() {
        return this.sendMailInquiryDataList.length;
    }

    /**
    * Method Name : mappingClass
    * @description : method to set mapping class
    * Date: 29/07/2024
    * Created By:Rachit Shah
    */
    get mappingClass() {
        return this.selectedConditionType !== 'Related List' && this.selectedConditionType !== 'None' ? 'mapping-item-active' : 'mapping-item-inactive';
    }

    /**
    * Method Name : isRealatedList
    * @description : method to check if related list is selected or not
    * Date: 29/07/2024
    * Created By:Rachit Shah
    */
    get isRealatedList() {
        return this.selectedConditionType === 'Related List' || this.selectedConditionType === 'None';
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
            errorDebugger('displayInquiry', 'pageNumbers', error, 'warn', 'Error in pageNumbers');
            return null;
        }
    }

    /**
    * Method Name : pagedInquries
    * @description : getter for paged inquiries with processed data
    */
    get pagedInquries() {
        if (!this.pagedFilteredInquiryData || this.pagedFilteredInquiryData.length === 0) {
            return [];
        }
        return this.processInquiryData(this.pagedFilteredInquiryData);
    }

    /**
    * Method Name : isInquiryObject
    * @description : check if selected object is inquiry
    * * Date: 20/08/2024
    * Created By:Rachit Shah
    */
    get isInquiryObject() {
        return this.objectName === 'MVEX__Inquiry__c';
    }

    /**
    * Method Name : IsMappingAvailable
    * @description : check if mapping is available or not
    * * Date: 20/08/2024
    * Created By:Rachit Shah
    */
    get IsMappingAvailable() {
        return this.mappings.length > 0;
    }

    /**
    * Method Name : isSendEmailButtonDisabled
    * @description : check if inquirylist is empty or not
    * * Date: 20/08/2024
    * Created By:Rachit Shah
    */
    get isSendEmailButtonDisabled() {
        return this.sendMailInquiryDataList.length === 0;
    }

    get isForSingle() {
        return this.sendMethod === 'single';
    }

    /**
    * Method Name : objectName
    * @description : method to set objectname from currentPage reference
    * * Date: 20/08/2024
    * Created By:Rachit Shah
    */
    @wire(CurrentPageReference) pageRef;
    get objectName() {
        let objectName = '';
        if (this.pageRef && this.pageRef.attributes) {
            objectName = this.pageRef.attributes.objectApiName;
        }
        if (!objectName) {
            objectName = this.objectApiName;
        }
        return objectName;
    }

    /**
    * Method Name : getPageReferenceParameters
    * @description : method to set recordId from currentPage reference
    * * Date: 20/08/2024
    * Created By:Rachit Shah
    */
    @wire(CurrentPageReference)
    getPageReferenceParameters(currentPageReference) {
        if (currentPageReference) {
            // const isCommunity = String(window.location).
            this.recordId = currentPageReference.attributes.recordId;
        }
    }

    /**
    * Method Name: ConnectedCallback
    * @description: Standard ConnectedCallback method which executes when the component is loaded and it is calling apex to fetch all the inquiries and loading map library
    * Date: 17/06/2024
    * Created By: Mitrajsinh Gohil
    * Last modified by : Rachit Shah
    */
    async connectedCallback() {
        await this.getObjectApiName();
        loadStyle(this, MulishFontCss)
            .then(() => {
                console.log('Css loaded successfully');
            })
            .catch(error => {
                errorDebugger('displayInquiry', 'loadStyle:connectedCallback', error, 'warn', 'Error while loading css');
            });
        this.getInquiryFields();
        this.fetchInquiryConfiguration(); // This will call fetchInquiries after config is loaded
        this.fetchMetadataRecords();
        window?.globalThis?.addEventListener('click', this.handleClickOutside);

        this.loadQuickTemplates();
        this.loadMessageOptions();
        this.vfPageMessageHandler();
        this.loadListViewId();
        this.loadAllTemplates();
    }

    processInquiryData(inquiries) {
        console.log('inquiries', inquiries);
        
        const cols = this.tableColumns;
        console.log('tableColumns', cols);
        
        return (inquiries || []).map(inquiry => {
            const row = { ...inquiry };
            row.displayFields = cols.map(col => {
                // Ensure fieldName is lowercase to match inquiry data keys
                const key = (col.fieldName || '').toLowerCase();
                let value = inquiry[key];
                
                // Handle special cases for field mapping
                if (!value && key === 'name' && inquiry.name) {
                    value = inquiry.name;
                }
                
                // Convert value to string for display if it exists
                const displayValue = value !== null && value !== undefined ? String(value) : '';
                
                console.log(`Field: ${key}, Value: ${value}, DisplayValue: ${displayValue}`);
                
                return {
                    key,
                    value: displayValue,
                    rawValue: value, // Keep original value for type checking
                    hasValue: value !== null && value !== undefined && String(value).trim() !== '',
                    isNameField: key === 'name',
                    isCurrency: col.type === 'currency'
                };
            });
            return row;
        });
    }

    async getObjectApiName() {
        try {
            const result = await getObjectName({ recId: this.recordId });
            this.objectApiName = result;
            return result;
        } catch (error) {
            errorDebugger('displayInquiry', 'getObjectApiName', error, 'warn', 'Error fetching object API name');
            return null;
        }
    }

    vfPageMessageHandler() {
        if (typeof window !== 'undefined') {
            window.addEventListener('message', this.simpleTempFileGenResponse);
        }
    }

    simpleTempFileGenResponse = (message) => {
        try {
            if (message.data.messageFrom == 'docGenerate') {
                let listingTemplateStatus = message.data.status;
                let listingTemplateError = message.data.error;
                if (listingTemplateStatus) {
                    this.handleSave();
                } else {
                    this.showToast('Failed to generate PDF', listingTemplateError, 'error');
                    this.isLoading = false;
                }
            }
        } catch (error) {
            errorDebugger('displayInquiry', 'simpleTempFileGenResponse', error, 'warn', 'Error processing message');
        }
    }

    /**
    * Method Name : renderedCallback
    * @description : method to load all data initially in the component
    * * Date: 20/08/2024
    * Created By:Rachit Shah
    */
    renderedCallback() {
        this.divElement = this.template.querySelector('.open-mapping-div');
        if (!this.isFirstScreen) {
            Promise.all([
                loadScript(this, summerNoteEditor + '/jquery-3.7.1.min.js'),
            ])
                .then(() => {
                    Promise.all([
                        loadStyle(this, summerNoteEditor + '/summernote-lite.css'),
                        loadScript(this, summerNoteEditor + '/summernote-lite.js'),
                    ])
                        .then(() => {
                            const richText = this.template.querySelector('.richText');
                            if (richText) {
                                richText.innerHTML = this.setTempValue(this.templateBody);
                            }
                        })
                        .catch(error => {
                            errorDebugger('displayInquiry', 'renderedCallback:loadStyle', error, 'warn', 'Error loading style');
                        })
                })
                .catch(error => {
                    errorDebugger('displayInquiry', 'renderedCallback:loadScript', error, 'warn', 'Error loading script');
                })
        }
    }

    loadAllTemplates() {
        getTemplatesByObject()
            .then(result => {
                this.templateMap = new Map(Object.entries(result));
                this.updateTemplateOptions();
            })
            .catch(error => {
                errorDebugger('displayInquiry', 'loadAllTemplates', error, 'warn', 'Failed to load templates');
                this.showToast('Error', 'Failed to load templates', 'error');
            });
    }

    loadListViewId() {
        getListViewId()
            .then(data => {
                this.listViewId = data;
            })
            .catch(error => {
                errorDebugger('displayInquiry', 'loadListViewId', error, 'warn', 'Failed to load list view id');
                this.showToast('Error', 'Failed to load list view id', 'error');
            });
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
                this.quickTemplates = [
                    { label: 'None', value: '', body: '' },
                    ...result.marketingTemplates
                        .filter(option => option.objectApiName === 'Contact')
                        .map(option => {
                            return {
                                label: option.templateName,
                                value: option.templateId,
                                body: option.body
                            };
                        })
                ];

                this.listingTemplateOptions = [
                    { label: 'None', value: '', body: '' },
                    ...result.listingTemplates.map(option => {
                        return { label: option.templateName, value: option.templateId };
                    })
                ];
            })
            .catch(error => {
                errorDebugger('displayInquiry', 'loadQuickTemplates', error, 'warn', 'Failed to load quick templates');
                this.showToast('Error', 'Failed to load quick templates', 'error');
            });
    }

    /**
    * Method Name : fetchMetadataRecords
    * @description : method to fetch metadata records
    * Date: 29/07/2024
    * Created By:Rachit Shah
    */
    fetchMetadataRecords() {
        this.isLoading = true;
        getMetadata()
            .then((result) => {
                if (result && result.length > 0) {
                    let allFilters = result[0] ? result[0].split(';') : [];
                    const inquiryLogic = result[3];
                    const inquiryCondition = result[4];

                    this.filters = allFilters.filter(filter => filter.includes('MVEX__Inquiry__c'));

                    this.logicalExpression = inquiryLogic === 'empty' ? '' : inquiryLogic;
                    this.condtiontype = inquiryCondition;
                }

                this.fetchListings();
                this.isLoading = false;
            })
            .catch(error => {
                errorDebugger('displayInquiry', 'fetchMetadataRecords', error, 'warn', 'Error fetching metadata');
                this.showToast('Error', 'Error fetching metadata', 'error');
                this.isLoading = false;
            });
    }

    /**
    * Method Name : loadMessageOptions
    * @description : method to get all message service options from apex
    * * Date: 20/08/2024
    * Created By:Rachit Shah
    */
    loadMessageOptions() {
        getMessagingServiceOptions()
            .then(data => {
                this.messageOptions = data.map(option => {
                    return { label: option.label, value: option.value };
                });
            })
            .catch(error => {
                errorDebugger('displayInquiry', 'loadMessageOptions', error, 'warn', 'Failed to fetch message options');
                this.showToast('Error', 'Failed to fetch message options', 'error');
            });
    }

    /**
    * Method Name : getInquiryFields
    * @description : method to get all inquiry fields
    * * Date: 20/08/2024
    * Created By:Rachit Shah
    */
    getInquiryFields() {
        getFieldMap({ objectName: 'MVEX__Inquiry__c' })
            .then(result => {
                this.inquiryFieldOptions = result.fields;
                this.inquirypicklistoptions = result.fields.map(field => {
                    return { label: field.label, value: field.value };
                }).sort((a, b) => a.label.localeCompare(b.label));
            })
            .catch(error => {
                errorDebugger('displayInquiry', 'getInquiryFields', error, 'warn', 'Error fetching inquiry fields');
            });
    }

    /**
    * Method Name : handleClickOutside
    * @description : method to hide modal if user clickes anywhere outside modal
    * * Date: 20/08/2024
    * Created By:Rachit Shah
    */
    handleClickOutside = (event) => {
        if (this.divElement && !this.divElement.contains(event.target)) {
            this.hideModalBox();
            this.closeAddConditionModal();
        }
    }

    /**
    * Method Name : handleInsideClick
    * @description : method to remain open modal if clicked inside modal
    * * Date: 20/08/2024
    * Created By:Rachit Shah
    */
    handleInsideClick(event) {
        event.stopPropagation();
    }

    /**
    * Method Name : handleSendMethodChange
    * @description : method to handle sender mode change
    * * Date: 20/08/2024
    * Created By:Rachit Shah
    */
    handleSendMethodChange(event) {
        this.sendMethod = event.detail.value;
    }

    /**
    * Method Name : handletemplateChange
    * @description : method to handle template change
    * Date: 29/07/2024
    * Created By:Rachit Shah
    */
    handletemplateChange(event) {
        try {
            this.selectedTemplate = event.detail.value;
            const selectedOption = this.quickTemplates.find(option => option.value === this.selectedTemplate);
            if (selectedOption.label === 'None') {
                this.isTemplateBody = false;
            } else {
                this.isTemplateBody = true;
                this.templateBody = selectedOption ? selectedOption.body : '';
            }
        } catch (error) {
            errorDebugger('displayInquiry', 'handletemplateChange', error, 'warn', 'Error selecting template');
            this.showToast('Error', 'An error occurred while selecting template', 'error');
        }
    }

    /**
    * Method Name : handleListingTemplateChange
    * @description : method to handle listing template change
    * Date: 29/07/2024
    * Created By:Rachit Shah
    */
    handleListingTemplateChange(event) {
        this.selectedListingTemplate = event.detail.value;
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
                this.isLoading = true;
                if (this.selectedListingTemplate != '' && this.selectedListingTemplate != undefined && this.sendMethod == 'single') {
                    let paraData = {
                        'templateId': this.selectedListingTemplate,
                        'recordId': this.recordId,
                        'selectedExtension': '.pdf',
                        'selectedChannels': 'Files',
                        'fileName': 'ListingPDF'
                    }
                    let paraDataStringify = JSON.stringify(paraData);
                    let newSRC = '/apex/DocGeneratePage?paraData=' + encodeURIComponent(paraDataStringify);
                    this.vfGeneratePageSRC = newSRC;
                } else {
                    this.handleSave();
                }
            }
        } catch (error) {
            errorDebugger('displayInquiry', 'handleFooterButtonClick', error, 'warn', 'Error processing footer button click');
            this.showToast('Error', 'An error occurred while processing', 'error');
        }
    }

    /**
    * Method Name : handleSave
    * @description : method to send email and save data based on all condition
    * Date: 29/07/2024
    * Created By:Rachit Shah
    */
    handleSave() {
        try {
            const emailData = {
                sendMethod: this.sendMethod,
                templateId: this.selectedTemplate,
                listingId: this.recordId,
                inquiry: this.sendMailInquiryDataList
            };

            sendEmail({ emailDataJson: JSON.stringify(emailData) })
                .then(() => {
                    this.showToast('Success', 'Emails sent successfully!', 'success');
                    this.pagedFilteredInquiryData = this.pagedFilteredInquiryData.map(inquiry => {
                        return { ...inquiry, isSelected: false };
                    });
                    this.checkAll = false;
                    this.sendMailInquiryDataList = [];
                    this.selectedListingTemplate = '';
                    this.closeModal();
                    this.isLoading = false;
                })
                .catch(error => {
                    errorDebugger('displayInquiry', 'handleSave', error, 'warn', 'Failed to send emails');
                    this.showToast('Error', 'Failed to send emails', 'error');
                    this.isLoading = false;
                });
        } catch (error) {
            errorDebugger('displayInquiry', 'handleSave', error, 'warn', 'Error sending emails');
            this.showToast('Error', 'An error occurred while sending emails', 'error');
            this.isLoading = false;
        }
    }

    /**
    * Method Name : handleBack
    * @description : method to back in the first screen for selecting template
    * * Date: 20/08/2024
    * Created By:Rachit Shah
    */
    handleBack() {
        this.isFirstScreen = true;
    }

    /**
    * Method Name : handleDeleteMapping
    * @description : method to delete mapping
    * * Date: 20/08/2024
    * Created By:Rachit Shah
    */
    handleDeleteMapping(event) {
        const mappingIdToDelete = event.currentTarget.dataset.id;
        this.mappings = this.mappings
            .filter(mapping => mapping.id !== parseInt(mappingIdToDelete, 10))
            .map((mapping, index) => {
                return { ...mapping, id: index + 1 };
            });
    }

    /**
    * Method Name : getValueFromLabel
    * @description : method to get api name from label
    * * Date: 20/08/2024
    * Created By:Rachit Shah
    */
    getValueFromLabel(label) {
        let tempLabel = label.toLowerCase();
        const option = this.inquiryFieldOptions.find(opt => opt.value.toLowerCase() === tempLabel);
        return option ? option.label : tempLabel;
    }

    /**
    * Method Name : applyFiltersData
    * @description : method to apply filter initially
    * * Date: 20/08/2024
    * Created By:Rachit Shah
    */
    applyFiltersData(listing) {
        try {
            this.pagedFilteredInquiryData = this.totalinquiry.map(inquiry => ({
                ...inquiry,
                isSelected: false // Add isSelected field initialized to false
            }));

            this.mappings = this.filters.map((mappingStr, index) => {
                let [object, field, operator, valueField] = mappingStr.split(':');
                let fieldLabel = '';
                field = field.toLowerCase();
                valueField = valueField.toLowerCase();

                if (object === 'MVEX__Inquiry__c') {
                    fieldLabel = this.getValueFromLabel(field);
                    return {
                        id: index + 1,
                        field: field,
                        operator: operator,
                        displayOperator: this.displayOperator(operator),
                        valueField: listing[valueField] ? listing[valueField] : '',
                        label: fieldLabel
                    };
                }
                return null;
            }).filter(mapping => mapping !== null);

            console.log('applyFiltersData: mappings', JSON.stringify(this.mappings));
            console.log('applyFiltersData: logicalExpression', this.logicalExpression);
            console.log('applyFiltersData: condtiontype', this.condtiontype);

            const parsedFilters = this.filters.map(filter => {
                const [object, field, operator, valueField] = filter.split(':');
                return { object, field: field.toLowerCase(), operator, valueField: valueField.toLowerCase() };
            });

            if (this.condtiontype === 'custom') {
                if (!this.logicalExpression || this.logicalExpression.trim() === '') {
                    this.logicalExpression = parsedFilters.map((_, index) => index + 1).join(' AND ');
                }

                // Validate logical expression
                const mappinglength = this.mappings.length;
                const regex = /\d+\s*(?:AND|OR)\s*\d+/i;

                if (!regex.test(this.logicalExpression)) {
                    this.showToast('Error', 'Invalid condition syntax in custom logic. Use numbers, AND, OR, spaces, and parentheses only.', 'error');
                    this.pagedFilteredInquiryData = this.totalinquiry;
                    this.isInquiryAvailable = this.pagedFilteredInquiryData.length > 0;
                    this.totalRecords = this.pagedFilteredInquiryData.length;
                    this.currentPage = 1;
                    return;
                }

                const numbers = this.logicalExpression.match(/\d+/g);
                if (numbers) {
                    const numberSet = new Set(numbers.map(Number));
                    const invalidIndex = Array.from(numberSet).some(num => num >= mappinglength + 1 || num < 1);

                    if (invalidIndex) {
                        this.showToast('Error', `Condition uses invalid index. Use indices from 1 to ${mappinglength}.`, 'error');
                        this.pagedFilteredInquiryData = this.totalinquiry;
                        this.isInquiryAvailable = this.pagedFilteredInquiryData.length > 0;
                        this.totalRecords = this.pagedFilteredInquiryData.length;
                        this.currentPage = 1;
                        return;
                    }

                    if (numberSet.size !== mappinglength) {
                        this.showToast('Error', 'Condition must include all indices.', 'error');
                        this.pagedFilteredInquiryData = this.totalinquiry;
                        this.isInquiryAvailable = this.pagedFilteredInquiryData.length > 0;
                        this.totalRecords = this.pagedFilteredInquiryData.length;
                        this.currentPage = 1;
                        return;
                    }

                    // Basic syntax check for balanced parentheses
                    let openParens = 0;
                    for (let char of this.logicalExpression) {
                        if (char === '(') openParens++;
                        if (char === ')') openParens--;
                        if (openParens < 0) {
                            this.showToast('Error', 'Unbalanced parentheses in custom logic expression.', 'error');
                            this.pagedFilteredInquiryData = this.totalinquiry;
                            this.isInquiryAvailable = this.pagedFilteredInquiryData.length > 0;
                            this.totalRecords = this.pagedFilteredInquiryData.length;
                            this.currentPage = 1;
                            return;
                        }
                    }
                    if (openParens !== 0) {
                        this.showToast('Error', 'Unbalanced parentheses in custom logic expression.', 'error');
                        this.pagedFilteredInquiryData = this.totalinquiry;
                        this.isInquiryAvailable = this.pagedFilteredInquiryData.length > 0;
                        this.totalRecords = this.pagedFilteredInquiryData.length;
                        this.currentPage = 1;
                        return;
                    }
                } else {
                    this.showToast('Error', 'Condition syntax is correct but contains no indices.', 'error');
                    this.pagedFilteredInquiryData = this.totalinquiry;
                    this.isInquiryAvailable = this.pagedFilteredInquiryData.length > 0;
                    this.totalRecords = this.pagedFilteredInquiryData.length;
                    this.currentPage = 1;
                    return;
                }

                this.pagedFilteredInquiryData = this.totalinquiry.filter(inquiry => {
                    let filterResults = [];

                    parsedFilters.forEach((filter, index) => {
                        let fieldValue, filterValue;

                        if (filter.object === 'Inquiry__c') {
                            // Validate field existence
                            if (!(filter.field in inquiry)) {
                                console.warn(`applyFiltersData: Field ${filter.field} not found in inquiry`, inquiry);
                                filterResults[index + 1] = false;
                                return;
                            }
                            if (!(filter.valueField in listing)) {
                                console.warn(`applyFiltersData: Value field ${filter.valueField} not found in listing`, listing);
                                filterResults[index + 1] = false;
                                return;
                            }

                            fieldValue = inquiry[filter.field];
                            filterValue = listing[filter.valueField];

                            // Ensure values are defined
                            fieldValue = fieldValue !== undefined && fieldValue !== null ? fieldValue : '';
                            filterValue = filterValue !== undefined && fieldValue !== null ? filterValue : '';

                            switch (filter.operator) {
                                case 'lessThan':
                                    filterResults[index + 1] = isNaN(parseFloat(fieldValue)) || isNaN(parseFloat(filterValue)) ? false : parseFloat(fieldValue) < parseFloat(filterValue);
                                    break;
                                case 'greaterThan':
                                    filterResults[index + 1] = isNaN(parseFloat(fieldValue)) || isNaN(parseFloat(filterValue)) ? false : parseFloat(fieldValue) > parseFloat(filterValue);
                                    break;
                                case 'equalTo':
                                    filterResults[index + 1] = String(fieldValue) === String(filterValue);
                                    break;
                                case 'contains':
                                    filterResults[index + 1] = String(fieldValue).includes(String(filterValue));
                                    break;
                                case 'notEqualTo':
                                    filterResults[index + 1] = String(fieldValue) !== String(filterValue);
                                    break;
                                case 'notContains':
                                    filterResults[index + 1] = !String(fieldValue).includes(String(filterValue));
                                    break;
                                default:
                                    filterResults[index + 1] = false;
                            }
                        } else {
                            filterResults[index + 1] = false;
                        }
                    });

                    console.log(`applyFiltersData: filterResults for inquiry ${inquiry.id}`, filterResults);

                    // Transform AND/OR to &&/|| for eval
                    const evalExpression = this.logicalExpression
                        .replace(/\bAND\b/gi, '&&')
                        .replace(/\bOR\b/gi, '||');
                    console.log(`applyFiltersData: evalExpression for inquiry ${inquiry.id}`, evalExpression);
                    const evaluationResult = eval(evalExpression.replace(/\d+/g, match => filterResults[match]));
                    console.log(`applyFiltersData: evaluationResult for inquiry ${inquiry.id}`, evaluationResult);

                    return evaluationResult;
                });

                console.log('applyFiltersData: filtered inquiries count', this.pagedFilteredInquiryData.length);

                this.isInquiryAvailable = this.pagedFilteredInquiryData.length > 0;
                this.totalRecords = this.pagedFilteredInquiryData.length;
                this.currentPage = 1;
            } else if (this.condtiontype === 'any') {
                this.selectedConditionType = 'Any Condition Is Met';
                this.logicalExpression = '';
                this.applyModalFilters();
            } else if (this.condtiontype === 'all') {
                this.selectedConditionType = 'All Condition Are Met';
                this.logicalExpression = '';
                this.applyModalFilters();
            }
        } catch (error) {
            errorDebugger('displayInquiry', 'applyFiltersData', error, 'warn', 'Error applying filters');
            this.showToast('Error', 'Error applying filters', 'error');
        }
    }

    /**
    * Method Name : displayOperator
    * @description : method to display Operator label
    * * Date: 20/08/2024
    * Created By:Rachit Shah
    */
    displayOperator(operator) {
        switch (operator) {
            case 'lessThan':
                return 'Less than';
            case 'greaterThan':
                return 'Greater than';
            case 'equalTo':
                return 'Equals to';
            case 'contains':
                return 'Contains';
            case 'notEqualTo':
                return 'Not Equal To';
            case 'notContains':
                return 'Not Contains';
            default:
                return operator;
        }
    }

    /**
    * Method Name : setTempValue
    * @description : method to display value of template body
    * * Date: 20/08/2024
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
    * Method Name: fetchListings
    * @description: this method is used to get all inquiries data from the apex and update the property list to display them
    * Date: 17/06/2024
    * Created By: Mitrajsinh Gohil
    * Last modified by : Rachit Shah
    */
    fetchListings() {
        getRecords({ recId: this.recordId, objectName: this.objectName })
            .then(result => {
                const data = result;
                let listing = {};
                if (this.objectName === 'Listing__c') {
                    this.totalinquiry = this.convertKeysToLowercase(data.inquiries);
                    listing = data.listings[0];
                }

                const convertoLowerCase = (obj) => {
                    return Object.keys(obj).reduce((acc, key) => {
                        acc[key.toLowerCase()] = obj[key];
                        return acc;
                    }, {});
                };

                const lowerCaseListing = convertoLowerCase(listing);

                this.listingRecord = lowerCaseListing;

                this.applyFiltersData(this.listingRecord);
            })
            .catch(error => {
                errorDebugger('displayInquiry', 'fetchListings', error, 'warn', 'Error getting inquiries from apex');
            });
    }

    /**
    * Method Name: convertKeysToLowercase
    * @description: this method is used to convert all things in lowercase
    * Date: 17/06/2024
    * Created By: Rachit Shah
    */
    convertKeysToLowercase(array) {
        return array.map(item => {
            const newItem = {};
            Object.keys(item).forEach(key => {
                newItem[key.toLowerCase()] = item[key];
            });
            return newItem;
        });
    }

    /**
    * Method Name : handleMappingClick
    * @description : method to handle mapping click
    * * Date: 16/10/2024
    * Created By:Rachit Shah
    */
    handleMappingClick(event) {
        const nameAttribute = event.currentTarget.dataset.name;

        if (nameAttribute && nameAttribute !== 'delete') {
            const previouslySelected = this.template.querySelector('.selected');
            if (previouslySelected) {
                previouslySelected.classList.remove('selected');
            }

            event.currentTarget.classList.add('selected');

            const mappingId = event.target.dataset.id;
            this.isAddConditionModalVisible = true;

            const currentMapping = this.mappings.find(mapping => mapping.id === parseInt(mappingId, 10));

            if (currentMapping) {
                this.selectedMappingId = currentMapping.id;
                const selectedField = this.inquiryFieldOptions.find(field => field.value === currentMapping.field);

                if (selectedField) {
                    const fieldType = selectedField.type;

                    const primaryFieldTypes = ['TEXT', 'DATETIME', 'DATE', 'NUMBER', 'EMAIL'];
                    const picklistFieldTypes = ['PICKLIST', 'BOOLEAN', 'MULTIPICKLIST'];
                    const referenceFieldTypes = ['REFERENCE'];

                    this.inquiryFieldObject.isPrimary = primaryFieldTypes.includes(fieldType);
                    this.inquiryFieldObject.isPicklist = picklistFieldTypes.includes(fieldType);
                    this.inquiryFieldObject.isReference = referenceFieldTypes.includes(fieldType);
                    this.inquiryFieldObject.Data_Type__c = fieldType;

                    if (fieldType === 'REFERENCE') {
                        this.inquiryFieldObject.objectApiName = selectedField.referenceTo;
                    } else {
                        if (this.inquiryFieldObject.isPicklist && selectedField.picklistValues.length > 0) {
                            this.inquiryFieldObject.picklistValues = selectedField.picklistValues.map(picklistValue => {
                                return { label: picklistValue, value: picklistValue };
                            });
                        } else {
                            this.inquiryFieldObject.picklistValues = null;
                        }
                    }

                    this.inquiryFieldObject.Field_Name__c = currentMapping.field;
                    this.selectedConditionOperator = currentMapping.operator;
                    this.selectedListingField = currentMapping.valueField;
                }
            }
        }
    }

    /**
    * Method Name: handleSearch
    * @description: this method is used to filter the properties based on the search key without overriding other filters
    * Date: 17/06/2024
    * Created By: Mitrajsinh Gohil
    */
    handleSearch(event) {
        try {
            this.searchTerm = event.target.value.toLowerCase();
            this.currentPage = 1;
            this.totalRecords = this.pagedFilteredInquiryData.length;
            this.isInquiryAvailable = this.totalRecords > 0;
            this.applyFilters();
        } catch (error) {
            errorDebugger('displayInquiry', 'handleSearch', error, 'warn', 'Error in handleSearch method');
        }
    }

    /**
    * Method Name: applyFilters
    * @description: this method is used apply filter
    * Date: 25/07/2024
    * Created By: Rachit Shah
    */
    applyFilters() {
        try {
            this.pagedFilteredInquiryData = this.totalinquiry.filter(inquiry => {
                const searchInquiry = inquiry.name.toLowerCase().includes(this.searchTerm);
                return searchInquiry;
            });

            this.isInquiryAvailable = this.pagedFilteredInquiryData.length > 0;
            this.currentPage = 1;
            this.totalRecords = this.pagedFilteredInquiryData.length;

        } catch (error) {
            errorDebugger('displayInquiry', 'applyFilters', error, 'warn', 'Error applying filters');
            this.showToast('Error', 'Error applying filters', 'error');
        }
    }

    /**
    * Method Name: navigateToRecord
    * @description: this method is used to navigate to listing record page on click of view more
    * Date: 17/06/2024
    * Created By: Mitrajsinh Gohil
    */
    navigateToRecord(event) {
        const inquiryid = event.target.dataset.id;
        this[NavigationMixin.GenerateUrl]({
            type: 'standard__recordPage',
            attributes: {
                recordId: inquiryid,
                actionName: 'view'
            }
        }).then(url => {
            window?.globalThis?.open(url, '_blank');
        }).catch(error => {
            errorDebugger('displayInquiry', 'navigateToRecord', error, 'warn', 'Error generating URL');
        });
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
        }
    }

    /**
    * Method Name: showModalBox
    * @description: this method is used to show modal
    * Date: 25/07/2024
    * Created By: Rachit Shah
    */
    showModalBox() {
        this.isShowModal = true;
    }

    /**
    * Method Name: hideModalBox
    * @description: this method is used hide modal
    * Date: 25/07/2024
    * Created By: Rachit Shah
    */
    hideModalBox() {
        this.closeAddConditionModal();
        this.isShowModal = false;
    }

    /**
    * Method Name: handleConditionTypeChange
    * @description: this method is used to handle condition type change
    * Date: 17/06/2024
    * Created By: Rachit Shah
    */
    handleConditionTypeChange(event) {
        this.selectedConditionType = event.detail.value;
    }

    /**
    * Method Name: handleLogicalExpressionChange
    * @description: this method is used to handle logical expression change
    * Date: 17/06/2024
    * Created By: Rachit Shah
    */
    handleLogicalExpressionChange(event) {
        this.logicalExpression = event.detail.value;
    }

    /**
    * Method Name: addCondition
    * @description: this method is used to open add condition modal
    * Date: 17/06/2024
    * Created By: Rachit Shah
    */
    addCondition() {
        this.isAddConditionModalVisible = true;
    }

    /**
    * Method Name: applyModalFilters
    * @description: this method is used to apply filter data
    * Date: 25/07/2024
    * Created By: Rachit Shah
    */
    applyModalFilters() {
        try {
            if (this.mappings.length === 0) {
                this.pagedFilteredInquiryData = [...this.totalinquiry];
                this.isInquiryAvailable = this.pagedFilteredInquiryData.length > 0;
                this.totalRecords = this.pagedFilteredInquiryData.length;
                this.currentPage = 1;
                this.logicalExpression = '';
                this.hideModalBox();
                this.checkAll = false;
                this.sendMailInquiryDataList = [];
                this.isLoading = false;
                return;
            }

            if (this.selectedConditionType === 'All Condition Are Met') {
                this.pagedFilteredInquiryData = this.totalinquiry.filter(inquiry => {
                    return this.mappings.every(mapping => {
                        let inquiryValue = inquiry[mapping.field.toLowerCase()];
                        let filterValue = mapping.valueField;

                        switch (mapping.operator) {
                            case 'greaterThan':
                                inquiryValue = inquiryValue !== undefined ? inquiryValue : 0;
                                filterValue = filterValue !== undefined ? filterValue : 0;
                                return parseFloat(inquiryValue) > parseFloat(filterValue);
                            case 'lessThan':
                                inquiryValue = inquiryValue !== undefined ? inquiryValue : 0;
                                filterValue = filterValue !== undefined ? filterValue : 0;
                                return parseFloat(inquiryValue) < parseFloat(filterValue);
                            case 'equalTo':
                                inquiryValue = inquiryValue !== undefined ? inquiryValue : '';
                                filterValue = filterValue !== undefined ? filterValue : '';
                                return inquiryValue === filterValue;
                            case 'contains':
                                inquiryValue = inquiryValue !== undefined ? inquiryValue : '';
                                filterValue = filterValue !== undefined ? filterValue : '';
                                return inquiryValue.includes(filterValue);
                            case 'notEqualTo':
                                inquiryValue = inquiryValue !== undefined ? inquiryValue : '';
                                filterValue = filterValue !== undefined ? filterValue : '';
                                return inquiryValue !== filterValue;
                            case 'notContains':
                                inquiryValue = inquiryValue !== undefined ? inquiryValue : '';
                                filterValue = filterValue !== undefined ? filterValue : '';
                                return !inquiryValue.includes(filterValue);
                            default:
                                return false;
                        }
                    });
                });
            } else if (this.selectedConditionType === 'Any Condition Is Met') {
                this.pagedFilteredInquiryData = this.totalinquiry.filter(inquiry => {
                    return this.mappings.some(mapping => {
                        let fieldValue = inquiry[mapping.field.toLowerCase()];

                        switch (mapping.operator) {
                            case 'equalTo':
                                fieldValue = fieldValue !== undefined ? fieldValue : '';
                                return fieldValue === mapping.valueField;
                            case 'greaterThan':
                                fieldValue = fieldValue !== undefined ? fieldValue : 0;
                                return parseFloat(fieldValue) > parseFloat(mapping.valueField);
                            case 'lessThan':
                                fieldValue = fieldValue !== undefined ? fieldValue : 0;
                                return parseFloat(fieldValue) < parseFloat(mapping.valueField);
                            case 'contains':
                                fieldValue = fieldValue !== undefined ? fieldValue : '';
                                return fieldValue && fieldValue.includes(mapping.valueField);
                            case 'notEqualTo':
                                fieldValue = fieldValue !== undefined ? fieldValue : '';
                                return fieldValue !== mapping.valueField;
                            case 'notContains':
                                fieldValue = fieldValue !== undefined ? fieldValue : '';
                                return fieldValue && !fieldValue.includes(mapping.valueField);
                            default:
                                return false;
                        }
                    });
                });
            } else if (this.selectedConditionType === 'Related List') {
                this.pagedFilteredInquiryData = this.totalinquiry.filter(inquiry => {
                    return inquiry.listing__c === this.recordId;
                });
            } else if (this.selectedConditionType === 'None') {
                this.pagedFilteredInquiryData = this.totalinquiry;
            } else {
                const inputElement = this.template.querySelector('lightning-input[data-id="condition-input"]');

                if (this.logicalExpression.trim() === '') {
                    inputElement.setCustomValidity('Expression cannot be empty');
                    inputElement.reportValidity();
                    return;
                }

                const mappinglength = this.mappings.length;
                const regex = /\d+\s*(?:AND|OR)\s*\d+/i;

                if (!regex.test(this.logicalExpression)) {
                    inputElement.setCustomValidity('Invalid condition syntax. Use numbers, AND, OR, spaces, and parentheses only.');
                    inputElement.reportValidity();
                    return;
                }

                const numbers = this.logicalExpression.match(/\d+/g);
                if (numbers) {
                    const numberSet = new Set(numbers.map(Number));
                    const invalidIndex = Array.from(numberSet).some(num => num >= mappinglength + 1 || num < 1);

                    if (invalidIndex) {
                        inputElement.setCustomValidity(`Condition uses invalid index. Use indices from 1 to ${mappinglength}.`);
                        inputElement.reportValidity();
                        return;
                    }

                    if (numberSet.size !== mappinglength) {
                        inputElement.setCustomValidity('Condition must include all indices.');
                        inputElement.reportValidity();
                        return;
                    }

                    // Basic syntax check for balanced parentheses
                    let openParens = 0;
                    for (let char of this.logicalExpression) {
                        if (char === '(') openParens++;
                        if (char === ')') openParens--;
                        if (openParens < 0) {
                            inputElement.setCustomValidity('Unbalanced parentheses in custom logic expression.');
                            inputElement.reportValidity();
                            return;
                        }
                    }
                    if (openParens !== 0) {
                        inputElement.setCustomValidity('Unbalanced parentheses in custom logic expression.');
                        inputElement.reportValidity();
                        return;
                    }
                } else {
                    inputElement.setCustomValidity('Condition syntax is correct but contains no indices');
                    inputElement.reportValidity();
                    return;
                }

                this.pagedFilteredInquiryData = this.totalinquiry.filter(inquiry => {
                    let filterResults = [];

                    this.mappings.forEach((mapping, index) => {
                        let fieldValue = inquiry[mapping.field.toLowerCase()];
                        let filterValue = mapping.valueField;

                        switch (mapping.operator) {
                            case 'lessThan':
                                fieldValue = fieldValue !== undefined ? fieldValue : 0;
                                filterValue = filterValue !== undefined ? filterValue : 0;
                                filterResults[index + 1] = isNaN(parseFloat(fieldValue)) || isNaN(parseFloat(filterValue)) ? false : parseFloat(fieldValue) < parseFloat(filterValue);
                                break;
                            case 'greaterThan':
                                fieldValue = fieldValue !== undefined ? fieldValue : 0;
                                filterValue = filterValue !== undefined ? filterValue : 0;
                                filterResults[index + 1] = isNaN(parseFloat(fieldValue)) || isNaN(parseFloat(filterValue)) ? false : parseFloat(fieldValue) > parseFloat(filterValue);
                                break;
                            case 'equalTo':
                                fieldValue = fieldValue !== undefined ? fieldValue : '';
                                filterValue = filterValue !== undefined ? filterValue : '';
                                filterResults[index + 1] = String(fieldValue) === String(filterValue);
                                break;
                            case 'contains':
                                fieldValue = fieldValue !== undefined ? fieldValue : '';
                                filterValue = filterValue !== undefined ? filterValue : '';
                                filterResults[index + 1] = String(fieldValue).includes(String(filterValue));
                                break;
                            case 'notEqualTo':
                                fieldValue = fieldValue !== undefined ? fieldValue : '';
                                filterValue = filterValue !== undefined ? filterValue : '';
                                filterResults[index + 1] = String(fieldValue) !== String(filterValue);
                                break;
                            case 'notContains':
                                fieldValue = fieldValue !== undefined ? fieldValue : '';
                                filterValue = filterValue !== undefined ? filterValue : '';
                                filterResults[index + 1] = !String(fieldValue).includes(String(filterValue));
                                break;
                            default:
                                filterResults[index + 1] = false;
                        }
                    });

                    const evalExpression = this.logicalExpression
                        .replace(/\bAND\b/gi, '&&')
                        .replace(/\bOR\b/gi, '||');
                    const evaluationResult = eval(evalExpression.replace(/\d+/g, match => filterResults[match]));
                    return evaluationResult;
                });
            }

            this.isInquiryAvailable = this.pagedFilteredInquiryData.length > 0;
            this.totalRecords = this.pagedFilteredInquiryData.length;
            this.currentPage = 1;
            this.hideModalBox();
            this.searchTerm = '';
            this.checkAll = false;
            this.sendMailInquiryDataList = [];
            this.isLoading = false;
        } catch (error) {
            errorDebugger('displayInquiry', 'applyModalFilters', error, 'warn', 'Error applying modal filters');
            this.showToast('Error', 'Error applying filters', 'error');
        }
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
        this.selectedListingTemplate = '';
    }

    /**
    * Method Name : handleInquiryFieldChange
    * @description : method to handle inquiry field change
    * Date: 29/07/2024
    * Created By:Rachit Shah
    */
    handleInquiryFieldChange(event) {
        try {
            const value = event.detail.value;
            this.inquiryFieldObject.Field_Name__c = value;
            this.selectedConditionOperator = '';
            this.selectedListingField = '';

            const selectedField = this.inquiryFieldOptions.find(field => field.value === value);

            if (selectedField) {
                const fieldType = selectedField.type;

                const primaryFieldTypes = ['TEXT', 'DATETIME', 'DATE', 'NUMBER', 'EMAIL'];
                const picklistFieldTypes = ['PICKLIST', 'BOOLEAN', 'MULTIPICKLIST'];
                const referenceFieldTypes = ['REFERENCE'];

                this.inquiryFieldObject.isPrimary = primaryFieldTypes.includes(fieldType);
                this.inquiryFieldObject.isPicklist = picklistFieldTypes.includes(fieldType);
                this.inquiryFieldObject.isReference = referenceFieldTypes.includes(fieldType);
                this.inquiryFieldObject.Data_Type__c = fieldType;

                if (fieldType === 'REFERENCE') {
                    this.inquiryFieldObject.objectApiName = selectedField.referenceTo;
                } else {
                    if (this.inquiryFieldObject.isPicklist && selectedField.picklistValues.length > 0) {
                        this.inquiryFieldObject.picklistValues = selectedField.picklistValues.map(picklistValue => {
                            return { label: picklistValue, value: picklistValue };
                        });
                    } else {
                        this.inquiryFieldObject.picklistValues = null;
                    }
                }
            }
        } catch (error) {
            errorDebugger('displayInquiry', 'handleInquiryFieldChange', error, 'warn', 'Error selecting inquiry field');
            this.showToast('Error', 'An error occurred while selecting inquiry field', 'error');
        }
    }

    /**
    * Method Name : handleConditionOperatorChange
    * @description : method to handle condition operator change
    * Date: 29/07/2024
    * Created By:Rachit Shah
    */
    handleConditionOperatorChange(event) {
        this.selectedConditionOperator = event.detail.value;
    }

    /**
    * Method Name : handleListingFieldChange
    * @description : method to handle listing
    * Date: 29/07/2024
    * Created By:Rachit Shah
    */
    handleListingFieldChange(event) {
        this.selectedListingField = event.target.value;
    }

    /**
    * Method Name : handleRefChange
    * @description : method to handle refrence for the object selection
    * Date: 29/07/2024
    * Created By:Rachit Shah
    */
    handleRefChange(event) {
        event.stopPropagation();
        let selectedValueId = event.detail.recordId;
        this.selectedListingField = selectedValueId;
    }

    /**
    * Method Name : closeAddConditionModal
    * @description : method to handle close add condition
    * Date: 29/07/2024
    * Created By:Rachit Shah
    */
    closeAddConditionModal() {
        try {
            this.inquiryFieldObject.Field_Name__c = '';
            this.inquiryFieldObject.isPrimary = true;
            this.inquiryFieldObject.isPicklist = false;
            this.inquiryFieldObject.isReference = false;
            this.selectedConditionOperator = '';
            this.selectedListingField = '';
            this.selectedMappingId = null;
            this.isAddConditionModalVisible = false;
            const previouslySelected = this.template.querySelector('.selected');
            if (previouslySelected) {
                previouslySelected.classList.remove('selected');
            }
        } catch (error) {
            errorDebugger('displayInquiry', 'closeAddConditionModal', error, 'warn', 'Error closing add condition modal');
            this.showToast('Error', 'An error occurred while closing add condition modal', 'error');
        }
    }

    /**
    * Method Name : saveCondition
    * @description : method to save condition
    * Date: 29/07/2024
    * Created By:Rachit Shah
    */
    saveCondition() {
        if (this.inquiryFieldObject.Field_Name__c && this.selectedListingField && this.selectedConditionOperator) {
            let displaylabel = this.getValueFromLabel(this.inquiryFieldObject.Field_Name__c);

            if (!this.selectedMappingId) {
                this.mappings.push({
                    id: this.mappings.length + 1,
                    field: this.inquiryFieldObject.Field_Name__c,
                    operator: this.selectedConditionOperator,
                    displayOperator: this.displayOperator(this.selectedConditionOperator),
                    valueField: this.selectedListingField ? this.selectedListingField : '',
                    label: displaylabel,
                });
            } else {
                this.mappings = this.mappings.map(mapping => {
                    if (mapping.id === this.selectedMappingId) {
                        return {
                            ...mapping,
                            field: this.inquiryFieldObject.Field_Name__c,
                            operator: this.selectedConditionOperator,
                            displayOperator: this.displayOperator(this.selectedConditionOperator),
                            valueField: this.selectedListingField ? this.selectedListingField : '',
                            label: displaylabel,
                        };
                    }
                    return mapping;
                });
            }

            this.closeAddConditionModal();
        } else {
            this.showToast('Error', 'Select all required fields', 'error');
        }
    }

    selectAllCheckbox(event) {
        this.checkAll = event.target.checked;
        // Set all checkboxes to match the state of the "Select All" checkbox
        this.pagedFilteredInquiryData = this.pagedFilteredInquiryData.map(inquiry => {
            return { ...inquiry, isSelected: this.checkAll };
        });

        // If "Select All" is checked, add all inquiries to sendMailInquiryDataList
        if (this.checkAll) {
            this.sendMailInquiryDataList = [...this.pagedFilteredInquiryData];
        } else {
            this.sendMailInquiryDataList = [];
        }
    }

    // Method to handle individual checkbox change
    checkBoxValueChange(event) {
        const inquiryId = event.target.dataset.id;
        const isChecked = event.target.checked;

        // Update the selected status of the specific inquiry
        this.pagedFilteredInquiryData = this.pagedFilteredInquiryData.map(inquiry => {
            if (inquiry.id === inquiryId) {
                inquiry.isSelected = isChecked;
            }
            return inquiry;
        });

        // Add or remove inquiry from sendMailInquiryDataList based on checkbox state
        if (isChecked) {
            const selectedInquiry = this.pagedFilteredInquiryData.find(inq => inq.id === inquiryId);
            this.sendMailInquiryDataList.push(selectedInquiry);
        } else {
            this.sendMailInquiryDataList = this.sendMailInquiryDataList.filter(inq => inq.id !== inquiryId);
        }

        // Check if all checkboxes are selected, if yes, check "Select All" checkbox
        this.checkAll = this.pagedFilteredInquiryData.every(inquiry => inquiry.isSelected);
    }

    /**
    * Method Name: showToast
    * @description: this method is used to show toast message
    * Date: 26/07/2024
    * Created By: Mitrajsinh Gohil
    */
    showToast(title, message, variant) {
        if (typeof window !== 'undefined') {
            this.dispatchEvent(new ShowToastEvent({
                title,
                message,
                variant
            }));
        }
    }

    /**
    * Method Name : disconnectedCallback
    * @description : method to remove click event when component destroy
    * Date: 29/07/2024
    * Created By:Rachit Shah
    */
    disconnectedCallback() {
        try {
            window?.globalThis?.removeEventListener('message', this.simpleTempFileGenResponse);
            window?.globalThis?.removeEventListener('click', this.handleClickOutside);
            const richTextElement = this.template.querySelector('.richText');
            if (richTextElement) {
                $(richTextElement).summernote('destroy');
            }
        } catch (error) {
            errorDebugger('displayInquiry', 'disconnectedCallback', error, 'warn', 'Error destroying Summernote editor');
        }
    }

    handleNameClick(event) {
        this.selectedRecordId = event.target.dataset.recordId;
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
                        { Id: groupId, ObjName: selectedGroup.Object_Name__c, Name: selectedGroup.Name }
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
            errorDebugger('displayInquiry', 'handleGroupSelection', error, 'warn', 'Error handling group selection');
            this.showToast('Error', 'Error handling group selection', 'error');
        }
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
                console.warn(`Unhandled input change for name: ${name}`);
                break;
        }
    }

    // Handle send message button click
    handleSendMessage() {
        try {
            if (this.sendMailInquiryDataList.length === 0) {
                this.showToast('Error', 'Please select at least one inquiry', 'error');
                return;
            }

            this.isLoading = true;
            const inquiryIds = this.sendMailInquiryDataList.map(inquiry => inquiry.id);

            // Fetch inquiry and contact records
            getContactsForInquiries({ inquiryIds })
                .then(records => {
                    if (records.length === 0) {
                        this.showToast('Error', 'No contacts found for the selected inquiries', 'error');
                        this.isLoading = false;
                        return;
                    }

                    this.broadcastContactList = records.map(record => ({
                        InquiryId: record.InquiryId,
                        InquiryName: record.InquiryName,
                        ContactId: record.ContactId,
                        ContactName: record.ContactName,
                        Phone: record.Phone
                    }));

                    this.showTemplate = true;
                    this.popUpFirstPage = true;
                    this.popUpSecondPage = false;
                    this.popUpLastPage = false;
                    this.popupHeader = 'Create Broadcast Group';
                    this.broadcastGroupName = '';
                    this.messageText = '';
                    this.selectedTemplate = '';
                    this.selectedDateTime = '';
                    this.broadcastGroupId = null;
                })
                .catch(error => {
                    errorDebugger('displayInquiry', 'handleSendMessage', error, 'warn', 'Failed to fetch records');
                    this.showToast('Error', 'Failed to fetch records', 'error');
                })
                .finally(() => {
                    this.isLoading = false;
                });
        } catch (error) {
            errorDebugger('displayInquiry', 'handleSendMessage', error, 'warn', 'Error opening send message modal');
            this.showToast('Error', 'Error opening send message modal', 'error');
            this.isLoading = false;
        }
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
        this.broadcastContactList = [];
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

        const phoneNumbers = this.broadcastContactList
            .map(record => record.Phone)
            .filter(phone => phone);

        if (phoneNumbers.length === 0) {
            this.showToast('Error', 'No valid phone numbers found for the selected contacts', 'error');
            return;
        }

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
                this.broadcastGroupId = result;
                this.showToast('Success', 'Broadcast group created successfully', 'success');
                this.popUpFirstPage = false;
                this.popUpSecondPage = true;
                this.popupHeader = 'Choose Template';
                this.tempBroadcastGroupName = this.broadcastGroupName;
                this.updateTemplateOptions();
            })
            .catch(error => {
                errorDebugger('displayInquiry', 'handleNextOnPopup', error, 'warn', 'Failed to create broadcast group');
                this.showToast('Error', 'Failed to create broadcast group', 'error');
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
                errorDebugger('displayInquiry', 'handleSendOnPopup', error, 'warn', 'Broadcast failed');
                this.showToast('Error', 'Broadcast failed', 'error');
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
                errorDebugger('displayInquiry', 'handleSchedule', error, 'warn', 'Scheduling failed');
                this.showToast('Error', 'Scheduling failed', 'error');
            })
            .finally(() => {
                this.spinnerShow = false;
            });
    }

    /**
    * Method Name : fetchInquiryConfiguration
    * @description : method to fetch inquiry configuration from metadata
    * Date: 25/08/2025
    * Created By: Rachit Shah
    */
    fetchInquiryConfiguration() {
        getConfigObjectFields({ objectApiName: 'Inquiry__c', configName: 'Inquiry_Fields' })
            .then(result => {
                if (result && result.metadataRecords && result.metadataRecords.length > 0) {
                    try {
                        const fieldsData = JSON.parse(result.metadataRecords[0]);
                        this.inquiryColumns = fieldsData.map(field => ({
                            label: field.label || field.fieldLabel,
                            fieldName: (field.fieldName || field.value || '').toLowerCase(),
                            type: this.getColumnType(field.fieldType),
                            format: field.format
                        }));
                        this.pageSize = parseInt(result.metadataRecords[1], 10) || this.pageSize;
                    } catch (e) {
                        this.inquiryColumns = this.defaultColumns;
                    }
                } else {
                    this.inquiryColumns = this.defaultColumns;
                }
            })
            .catch(() => {
                this.inquiryColumns = this.defaultColumns;
            })
            .finally(() => {
                // Ensure data loads after config to avoid unhandled promise rejection
                this.fetchListings();
            });
    }

    /**
    * Method Name : getColumnType
    * @description : method to convert field type to column type
    */
    getColumnType(fieldType) {
        switch ((fieldType || '').toUpperCase()) {
            case 'DATE':
                return 'date';
            case 'DATETIME':
                return 'date';
            case 'CURRENCY':
                return 'currency';
            case 'NUMBER':
            case 'DOUBLE':
            case 'INTEGER':
                return 'number';
            case 'EMAIL':
                return 'email';
            case 'PHONE':
                return 'phone';
            case 'URL':
                return 'url';
            case 'BOOLEAN':
                return 'boolean';
            default:
                return 'text';
        }
    }
       

    /**
    * Method Name : get tableColumns
    * @description : getter for table columns
    */
    get tableColumns() {
        return this.inquiryColumns.length > 0 ? this.inquiryColumns : this.defaultColumns;
    }
}