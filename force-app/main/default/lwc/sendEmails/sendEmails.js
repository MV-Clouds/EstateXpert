import { LightningElement, api, track } from 'lwc';
import getMessagingServiceOptions from '@salesforce/apex/SendEmailsController.getMessagingServiceOptions';
import getTemplatesByObject from '@salesforce/apex/SendEmailsController.getTemplatesByObject';
import getListings from '@salesforce/apex/SendEmailsController.getListings';
import getAllContacts from '@salesforce/apex/SendEmailsController.getAllContacts';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
import { loadStyle } from 'lightning/platformResourceLoader';
import sendEmails from '@salesforce/apex/SendEmailsController.sendEmails';
import getBroadcastGroups from '@salesforce/apex/BroadcastMessageController.getBroadcastEmailGroups';

export default class SendEmails extends LightningElement {
    @api showModal = false;
    @api objectApiName;
    @api selectedContacts = [];

    @track isPreviewModal = false;
    @track templateStatus = false;
    @track previewObjectName = 'Contact';

    @track messagingServiceOptions = [];
    @track selectedTemplate = '';
    @track selectedTemplateType = '';
    @track templatePreview = {
        subject: '',
        body: '',
        name: ''
    };

    @track allEmailTemplates = [];
    @track allCustomTemplates = [];
    @track filteredEmailTemplates = [];
    @track filteredCustomTemplates = [];

    @track listingOptions = [];
    @track selectedListing = null;
    @track selectedListingName = '';
    @track activeTab = 'All';

    @track allContacts = [];
    @track selectedCCContacts = [];

    @track allContactOptions = [];
    @track selectedContactsDetails = [];
    @track selectedCCContactsDetails = [];


    @track isListingDropdownOpen = false;
    @track listingSearchTerm = '';


    // Single object to store email details
    @track campaignDetails = {
        objectName: 'Contact',
        templateRelatedObject: 'Contact',
        templateType: 'EstateXpert Template',
        messagingService: '',
        selectedTemplate: '',
        isObjectDropDownDisabled: false
    };

    @track broadcastGroupOptions = [];
    @track selectedBroadcastGroups = [];

    // Combobox options
    objectOptions = [
        { label: 'Contact', value: 'Contact' }
    ];

    templateTypeOptions = [
        // { label: 'Email Template', value: 'Email Template' },
        { label: 'EstateXpert Template', value: 'EstateXpert Template' }
    ];

    get templateObjectOptions() {
        return [
            { label: 'Contact', value: 'Contact' },
            { label: 'Listing', value: 'MVEX__Listing__c' }
        ];
    }


    get showSingleListingSelector() {
        return this.campaignDetails.templateRelatedObject === 'MVEX__Listing__c';
    }

    // Computed filtered listings based on active tab with enhanced listing data
    get filteredListings() {
        let listings;
        if (this.activeTab === 'All') {
            listings = this.listingOptions;
        } else {
            listings = this.listingOptions.filter(listing => listing.type === this.activeTab);
        }

        // Add computed classes to each listing (removed typeClass)
        return listings.map(listing => ({
            ...listing,
            listingClass: this.getListingClass(listing)
        }));
    }

    // Check if there are no listings
    get hasNoListings() {
        return this.listingOptions.length === 0;
    }

    // Template combobox label based on selection
    get templateComboboxLabel() {
        if (this.selectedListing) {
            return `${this.campaignDetails.templateType} (Generic + Listing Templates)`;
        }
        return this.campaignDetails.templateType;
    }

    // Tab classes for active state
    get allTabClass() {
        return this.activeTab === 'All' ? 'slds-button slds-button_brand' : 'slds-button slds-button_neutral';
    }

    get rentTabClass() {
        return this.activeTab === 'Rent' ? 'slds-button slds-button_brand' : 'slds-button slds-button_neutral';
    }

    get saleTabClass() {
        return this.activeTab === 'Sale' ? 'slds-button slds-button_brand' : 'slds-button slds-button_neutral';
    }

    get isSendDisabled() {
        const hasRecipients = (this.selectedContacts && this.selectedContacts.length > 0) || (this.selectedBroadcastGroups && this.selectedBroadcastGroups.length > 0);
        const hasMessagingService = !!this.campaignDetails.messagingService;
        const hasTemplate = !!this.selectedTemplate;
        const hasListingIfRequired = !this.showSingleListingSelector || !!this.selectedListing;
        return !hasRecipients || !hasMessagingService || !hasTemplate || !hasListingIfRequired;
    }

    // Template options based on selected template type and listing
    get availableTemplates() {
        const relatedObj = this.campaignDetails.templateRelatedObject;
        return this.allCustomTemplates.filter(template =>
            template.objectName === relatedObj || template.objectName === 'Generic'
        );
    }

    // Show template preview only for EstateXpert templates
    get showTemplatePreview() {
        return this.campaignDetails.templateType === 'EstateXpert Template' &&
            this.selectedTemplate &&
            this.templatePreview.body;
    }


    // Show broadcast groups only when no individual contacts selected and object is selected
    get showBroadcastGroups() {
        return this.campaignDetails.objectName &&
            (this.selectedContacts.length === 0 || this.selectedContacts.length === null) &&
            this.filteredBroadcastGroups.length > 0;
    }

    // Filter broadcast groups based on selected object
    get filteredBroadcastGroups() {
        if (!this.campaignDetails.objectName || !this.broadcastGroupOptions) {
            return [];
        }

        return this.broadcastGroupOptions.filter(group =>
            group.objectName === 'Contact'
        ).map(group => ({
            ...group,
            selected: this.selectedBroadcastGroups.includes(group.value)
        }));
    }

    // Get selected broadcast groups count
    get selectedBroadcastGroupsCount() {
        return this.selectedBroadcastGroups.length;
    }

    // Estimate contacts from selected groups
    get estimatedContactsFromGroups() {
        if (!this.selectedBroadcastGroups.length) return 0;

        return this.filteredBroadcastGroups
            .filter(group => group.selected)
            .reduce((total, group) => total + (group.contactCount || 0), 0);
    }

    get totalRecipientCount() {
        return (this.selectedContactsDetails ? this.selectedContactsDetails.length : 0) + this.estimatedContactsFromGroups;
    }


    get selectedTemplateDisalbed() {
        return !this.selectedTemplate;
    }

    connectedCallback() {
        loadStyle(this, MulishFontCss);
        if (this.objectApiName) {
            this.campaignDetails.objectName = this.objectApiName;
            this.campaignDetails.isObjectDropDownDisabled = true;
        }

        // Convert selectedContacts from objects to IDs if needed
        if (this.selectedContacts && this.selectedContacts.length > 0) {
            if (typeof this.selectedContacts[0] === 'object' && this.selectedContacts[0].Id) {
                this.selectedContacts = this.selectedContacts.map(contact => contact.Id);
            }
        }

        this.loadMessageOptions();
        this.loadTemplates();
        this.loadListings();
        this.loadAllContacts();
        this.loadBroadcastGroups();

        this._documentClickHandler = this.handleDocumentClick.bind(this);
        document.addEventListener('click', this._documentClickHandler);
    }

    disconnectedCallback() {
        if (this._documentClickHandler) {
            document.removeEventListener('click', this._documentClickHandler);
        }
    }

    loadMessageOptions() {
        getMessagingServiceOptions()
            .then(data => {
                if (data && data.length > 0) {
                    this.messagingServiceOptions = data.map(option => ({
                        label: option.label,
                        value: option.value
                    }));
                }
            })
            .catch(error => {
                this.showToast('Error', 'Failed to fetch message options', 'error');
                console.error(error);
            });
    }

    loadBroadcastGroups() {
        getBroadcastGroups()
            .then(data => {
                if (data && data.length > 0) {
                    this.broadcastGroupOptions = data.map(option => ({
                        label: option.Name,
                        value: option.Id,
                        objectName: option.MVEX__Object_Name__c, // Assuming this field exists
                        contactCount: option.MVEX__Count_of_Members__c || 0, // Assuming this field exists
                        selected: false
                    }));
                }
            })
            .catch(error => {
                this.showToast('Error', 'Failed to fetch broadcast groups', 'error');
                console.error('Error loading broadcast groups:', error);
            });
    }

    loadTemplates() {
        getTemplatesByObject()
            .then(data => {
                if (data) {
                    this.allEmailTemplates = data.emailTemplates ? data.emailTemplates.map(template => ({
                        label: template.label,
                        value: template.value,
                        type: template.type,
                        subject: template.subject,
                        body: template.body
                    })) : [];

                    this.allCustomTemplates = data.customTemplates ? data.customTemplates.map(template => ({
                        label: template.label,
                        value: template.value,
                        type: template.type,
                        subject: template.subject,
                        body: template.body,
                        objectName: template.objectName
                    })) : [];

                    this.filterTemplatesByObject();
                }
            })
            .catch(error => {
                this.showToast('Error', 'Failed to load templates', 'error');
                console.error('Template loading error:', error);
            });
    }

    loadListings() {
        getListings()
            .then(data => {
                if (!data || data.length === 0) {
                    this.listingOptions = [];
                } else {
                    this.listingOptions = data.map(listing => ({
                        label: listing.Name,
                        value: listing.Id,
                        name: listing.Name,
                        address: listing.MVEX__Address__c || 'No address available',
                        type: listing.MVEX__Listing_Type__c || 'Unknown',
                        price: listing.MVEX__Listing_Price__c || 'No price available',
                        status: listing.MVEX__Status__c || '',
                        selected: false
                    }));
                }
                this.activeTab = 'All';
            })
            .catch(error => {
                this.listingOptions = [];
                this.showToast('Error', 'Failed to load listings', 'error');
                console.error('Listing loading error:', error);
            });
    }

    loadAllContacts() {
        getAllContacts()
            .then(data => {
                if (data && data.length > 0) {
                    this.allContacts = data.map(contact => ({
                        id: contact.Id,
                        name: contact.Name,
                        email: contact.Email,
                        company: contact.MVEX__Company__c || ''
                    }));

                    // Create options for combobox with searchable format
                    this.allContactOptions = this.allContacts.map(contact => ({
                        label: `${contact.name} (${contact.email})`,
                        value: contact.id
                    }));

                    // Update selected contacts details if any pre-selected
                    this.updateSelectedContactsDetails();
                } else {
                    this.allContacts = [];
                    this.allContactOptions = [];
                }
            })
            .catch(error => {
                this.showToast('Error', 'Failed to load contacts', 'error');
                console.error('Contact loading error:', error);
                console.error('Contact loading error:', error.stack);
            });
    }

    // Update selected contacts details
    updateSelectedContactsDetails() {

        // Ensure safe defaults
        this.selectedContacts = this.selectedContacts || [];
        this.selectedCCContacts = this.selectedCCContacts || [];
        // Ensure selectedContacts contains only IDs
        if (this.selectedContacts && this.selectedContacts.length > 0 && typeof this.selectedContacts[0] === 'object') {
            this.selectedContacts = this.selectedContacts.map(contact => contact.Id || contact.id);
        }

        this.selectedContactsDetails = this.selectedContacts.map(contactId => {
            const contact = this.allContacts.find(c => c.id === contactId);
            return contact ? { ...contact } : null;
        }).filter(Boolean);

        // Handle CC contacts similarly
        let ccContactIds = this.selectedCCContacts;
        if (ccContactIds && ccContactIds.length > 0 && typeof ccContactIds[0] === 'object') {
            ccContactIds = ccContactIds.map(contact => contact.Id || contact.id);
            this.selectedCCContacts = ccContactIds;
        }
        this.selectedCCContactsDetails = this.selectedCCContacts.map(contactId => {
            const contact = this.allContacts.find(c => c.id === contactId);
            return contact ? { ...contact } : null;
        }).filter(Boolean);
    }

    // Handle primary contact selection from custom combobox
    handlePrimaryContactSelect(event) {
        const selectedContactIds = event.detail; // This will be an array from multiselect
        if (selectedContactIds && selectedContactIds.length > 0) {
            this.selectedContacts = [...selectedContactIds];
            // Clear broadcast groups when individual contacts are selected
            this.selectedBroadcastGroups = [];
            this.updateSelectedContactsDetails();
        } else {
            this.selectedContacts = [];
            this.updateSelectedContactsDetails();
        }
    }

    // Handle CC contact selection from custom combobox
    handleCCContactSelect(event) {
        const selectedContactIds = event.detail; // This will be an array from multiselect
        if (selectedContactIds && selectedContactIds.length > 0) {
            this.selectedCCContacts = [...selectedContactIds];
            this.updateSelectedContactsDetails();
        } else {
            this.selectedCCContacts = [];
            this.updateSelectedContactsDetails();
        }
    }

    // Handle removing primary contact from pill
    handleRemovePrimaryContact(event) {
        const contactId = event.currentTarget.name;

        // Remove from selectedContacts
        this.selectedContacts = this.selectedContacts.filter(id => id !== contactId);
        this.updateSelectedContactsDetails();

        // Unselect from combobox
        const combobox = this.template.querySelector('c-custom-combobox[data-id="primary-combo"]');
        if (combobox) {
            combobox.unselectOption(contactId);
        }
    }

    // Handle removing CC contact from pill
    handleRemoveCCContact(event) {
        const contactId = event.currentTarget.name;

        // Remove from selectedCCContacts
        this.selectedCCContacts = this.selectedCCContacts.filter(id => id !== contactId);
        this.updateSelectedContactsDetails();

        // Unselect from combobox
        const combobox = this.template.querySelector('c-custom-combobox[data-id="cc-combo"]');
        if (combobox) {
            combobox.unselectOption(contactId);
        }
    }

    // Filter templates based on selected object
    filterTemplatesByObject() {
        const objectName = this.campaignDetails.templateRelatedObject;

        if (!objectName) {
            this.filteredEmailTemplates = [];
            this.filteredCustomTemplates = [];
            return;
        }

        this.filteredEmailTemplates = [...this.allEmailTemplates];

        this.filteredCustomTemplates = this.allCustomTemplates.filter(template =>
            template.objectName === objectName || template.objectName === 'Generic'
        );
    }


    // Handle related object change in template selection step (kept for Single Campaign)
    handleRelatedObjectChange(event) {
        this.campaignDetails.templateRelatedObject = event.detail.value;
        this.campaignDetails.objectName = event.detail.value;

        // Reset selections on related object change
        this.selectedTemplate = '';
        this.selectedListing = null;
        this.selectedListingName = '';


    }

    get filteredListingsOptions() {
        let term = this.listingSearchTerm.toLowerCase();
        let options = this.listingOptions.map(l => ({ label: l.name, value: l.value }));
        if (term) {
            return options.filter(opt => opt.label.toLowerCase().includes(term));
        }
        return options;
    }

    handleListingComboboxClick(event) {
        event.stopPropagation();
        this.isListingDropdownOpen = true;
    }

    handleListingDropdownClick(event) {
        event.stopPropagation();
    }

    handleListingSearchInput(event) {
        this.listingSearchTerm = event.target.value;
    }

    handleSingleListingSelect(event) {
        this.selectedListing = event.currentTarget.dataset.value;
        this.selectedListingName = event.currentTarget.dataset.label;
        this.isListingDropdownOpen = false;
        this.listingSearchTerm = '';
    }

    handleClearSingleListing(event) {
        event.stopPropagation();
        this.selectedListing = null;
        this.selectedListingName = '';
    }

    handleDocumentClick(event) {
        const comboboxContainers = this.template.querySelectorAll('.custom-combobox-container');
        let clickedInside = false;

        comboboxContainers.forEach(container => {
            if (container.contains(event.target)) {
                clickedInside = true;
            }
        });

        if (!clickedInside) {
            this.isListingDropdownOpen = false;
        }
    }


    // Handle tab click for listing filters
    handleTabClick(event) {
        this.activeTab = event.currentTarget.dataset.tab;
    }

    // Handle campaign field changes
    handleCampaignFieldChange(event) {
        const fieldName = event.target.dataset.id;
        const value = event.detail.value || event.target.value;

        this.campaignDetails = {
            ...this.campaignDetails,
            [fieldName]: value
        };
    }

    // Handle template selection
    handleTemplateSelect(event) {
        this.selectedTemplate = event.detail.value;
    }

    // Handle finish button
    handleFinish() {
        if (!this.validateForm()) {
            return;
        }

        // Show loading state
        const finishButton = this.template.querySelector('.send-emails-btn');
        if (finishButton) {
            finishButton.disabled = true;
            finishButton.textContent = 'Sending Emails...';
        }

        try {
            this.handleSendEmails();
        } catch (error) {
            console.error('Error in handleFinish:', error);
            this.showToast('Error', 'An unexpected error occurred: ' + error.message, 'error');
            this.resetFinishButton(finishButton);
        }
    }

    // Directly send emails without creating campaign records
    handleSendEmails() {
        sendEmails({
            templateId: this.selectedTemplate,
            relatedObject: this.campaignDetails.templateRelatedObject,
            messagingService: this.campaignDetails.messagingService,
            listingId: this.selectedListing || null,
            primaryContactIds: this.selectedContacts || [],
            broadcastGroupIds: this.selectedBroadcastGroups || [],
            ccContactIds: this.selectedCCContacts || []
        })
            .then((result) => {
                if (result && result.status === 'success') {
                    this.showToast('Success', result.message || 'Emails sent successfully!', 'success');
                    this.closeModal();
                } else {
                    this.showToast('Error', (result && result.message) ? result.message : 'Failed to send emails.', 'error');
                }
            })
            .catch(error => {
                console.error('Error sending emails:', error);
                this.showToast('Error', 'Failed to send emails: ' + (error.body?.message || error.message), 'error');
            })
            .finally(() => {
                this.resetFinishButton();
            });
    }

    // Reset finish button state
    resetFinishButton(button) {
        const finishButton = button || this.template.querySelector('.send-emails-btn');
        if (finishButton) {
            finishButton.disabled = this.isSendDisabled;
            finishButton.textContent = 'Send Emails';
        }
    }

    // Validate form before submission
    validateForm() {
        if (!this.campaignDetails.messagingService) {
            this.showToast('Error', 'Please select a messaging service.', 'error');
            return false;
        }
        if (!this.selectedTemplate) {
            this.showToast('Error', 'Please select a template.', 'error');
            return false;
        }
        if (this.showSingleListingSelector && !this.selectedListing) {
            this.showToast('Error', 'Please select a listing.', 'error');
            return false;
        }
        if ((!this.selectedContacts || this.selectedContacts.length === 0) &&
            (!this.selectedBroadcastGroups || this.selectedBroadcastGroups.length === 0)) {
            this.showToast('Error', 'Please select at least one contact or broadcast group.', 'error');
            return false;
        }
        return true;
    }

    // Add this method if you need custom validation
    validateContacts() {
        const primaryCombobox = this.template.querySelector('c-custom-combobox');
        if (this.selectedContacts.length === 0) {
            primaryCombobox?.isInvalidInput(true);
            return false;
        }
        primaryCombobox?.isInvalidInput(false);
        return true;
    }

    // Close modal
    closeModal() {
        this.selectedTemplate = '';
        this.selectedTemplateType = '';
        this.templatePreview = { subject: '', body: '', name: '' };
        this.selectedListing = null;
        this.selectedListingName = '';
        this.activeTab = 'All';

        // Reset contact selections
        this.selectedContacts = [];
        this.selectedCCContacts = [];
        this.selectedContactsDetails = [];
        this.selectedCCContactsDetails = [];



        this.campaignDetails = {
            objectName: 'Contact',
            templateRelatedObject: 'Contact',
            templateType: 'EstateXpert Template',
            messagingService: '',
            selectedTemplate: '',
            isObjectDropDownDisabled: !!this.objectApiName
        };

        this.selectedBroadcastGroups = [];

        this.dispatchEvent(new CustomEvent('close'));
        this.showModal = false;
    }

    // Utility method to show toast messages
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(event);
    }

    handleCloseModal() {
        this.isPreviewModal = false;
        this.selectedTemplateId = '';
    }

    handlePreviewSingleTemplate() {
        if (this.selectedTemplate) {
            this.selectedTemplateId = this.selectedTemplate;
            this.previewObjectName = this.campaignDetails.templateRelatedObject;
            this.templateStatus = true;
            this.isPreviewModal = true;
        }
    }

    // Method to compute listing class (removed type class logic)
    getListingClass(listing) {
        return `listing-item slds-box slds-box_x-small ${this.selectedListing === listing.value ? 'selected' : ''}`;
    }

    // Handle broadcast group selection
    handleBroadcastGroupChange(event) {
        const groupId = event.target.dataset.value;
        const isChecked = event.target.checked;

        if (isChecked) {
            if (!this.selectedBroadcastGroups.includes(groupId)) {
                this.selectedBroadcastGroups = [...this.selectedBroadcastGroups, groupId];
            }
        } else {
            this.selectedBroadcastGroups = this.selectedBroadcastGroups.filter(id => id !== groupId);
        }
    }
}