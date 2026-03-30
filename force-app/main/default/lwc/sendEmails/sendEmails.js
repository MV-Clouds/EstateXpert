import { LightningElement, api, track } from 'lwc';
import getMessagingServiceOptions from '@salesforce/apex/SendEmailsController.getMessagingServiceOptions';
import getTemplatesByObject from '@salesforce/apex/SendEmailsController.getTemplatesByObject';
import getListings from '@salesforce/apex/SendEmailsController.getListings';
import getAllContacts from '@salesforce/apex/SendEmailsController.getAllContacts';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
import { loadStyle } from 'lightning/platformResourceLoader';
// Import the correct methods for single and drip campaigns
import createCampaignAndEmails from '@salesforce/apex/EmailCampaignController.createCampaignAndEmails';
import getBroadcastGroups from '@salesforce/apex/BroadcastMessageController.getBroadcastEmailGroups';

export default class SendEmails extends LightningElement {
    @api showModal = false;
    @api objectApiName;
    @api selectedContacts = [];

    @track isPreviewModal = false;
    @track selectedTemplateId = '';
    @track selectedobject = '';
    @track templateStatus = false;
    
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

    @track selectedDripId = null;

    @track isListingDropdownOpen = false;
    @track listingSearchTerm = '';

    @track selectedOption = '';
    @track selectedOptionLabel = '';
    @track currentStep = 1;
    @track totalSteps = 3;
    
    // Single object to store all campaign details
    @track campaignDetails = {
        objectName: 'Contact',
        templateRelatedObject: 'Contact',
        campaignName: '',
        templateType: 'EstateXpert Template',
        messagingService: '',
        selectedTemplate: '',
        isObjectDropDownDisabled: false
    };
    
    // Drip Campaign Properties
    @track dripSequence = [];
    @track dripStartDate = null;
    @track nextDripId = 1;
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
    
    steps = [
        { label: 'Select Type', value: 'step-1' },
        { label: 'Template Configuration', value: 'step-2' },
        { label: 'Recipients & Send', value: 'step-3' }
    ];

    get dynamicSteps() {
        return this.steps;
    }

    // Get current step value for progress indicator
    get currentStepValue() {
        return `step-${this.currentStep}`;
    }

    // Step visibility getters
    get isStep1() {
        return this.currentStep === 1;
    }

    get isStep2() {
        return this.currentStep === 2;
    }

    get isStep3() {
        return this.currentStep === 3;
    }

    // Check if drip campaign is selected
    get isDripCampaign() {
        return this.selectedOption === 'drip';
    }

    // Check if single campaign is selected
    get isSingleCampaign() {
        return this.selectedOption === 'single';
    }

    get showSingleListingSelector() {
        return this.isSingleCampaign && this.campaignDetails.templateRelatedObject === 'MVEX__Listing__c';
    }

    get showDripListingSelector() {
        if (this.isDripCampaign && this.selectedDrip) {
            return this.selectedDrip.relatedObject === 'MVEX__Listing__c';
        }
        return false;
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
        const currentListing = this.isDripCampaign && this.selectedDrip ? this.selectedDrip.selectedListingId : this.selectedListing;
        if (currentListing) {
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

    // Footer button configurations
    get footerButtons() {
        const buttons = [];

        // Back button (show on step 2 and later)
        if (this.currentStep > 1) {
            buttons.push({
                label: 'Back',
                variant: 'neutral',
                onclick: 'handleBack',
                disabled: false,
                buttonClass: 'white-btn-css',
                isBack: true,
                isNext: false,
                isFinish: false
            });
        }

        // Next/Finish button
        if (this.currentStep === 2) {
            let isDisabled = false;
            if (this.isDripCampaign) {
                // For drip campaigns, check if we have at least one drip and start date
                isDisabled = !this.dripStartDate || this.dripSequence.length === 0 ||
                    !this.validateDripSequence();
            } else {
                // For single campaigns, check if template is selected and listing if required
                isDisabled = !this.selectedTemplate || (this.showSingleListingSelector && !this.selectedListing);
            }

            buttons.push({
                label: 'Next',
                variant: 'brand',
                onclick: 'handleNext',
                disabled: isDisabled,
                buttonClass: 'blue-btn-css',
                isBack: false,
                isNext: true,
                isFinish: false
            });
        } else if (this.currentStep === 3) {
            const hasRecipients = this.selectedContacts.length > 0 || this.selectedBroadcastGroups.length > 0;
            const hasCampaignDetails = this.campaignDetails.campaignName && this.campaignDetails.messagingService;
            buttons.push({
                label: this.isDripCampaign ? 'Create Campaign' : 'Send Emails',
                variant: 'brand',
                onclick: 'handleFinish',
                disabled: !hasRecipients || !hasCampaignDetails,
                buttonClass: 'custom-footer-button finish-button',
                isBack: false,
                isNext: false,
                isFinish: true
            });
        }

        return buttons;
    }

    get showFooter() {
        return this.footerButtons.length > 0;
    }

    // Template options based on selected template type and listing
    get availableTemplates() {
        let relatedObj;
        if (this.isDripCampaign && this.selectedDrip) {
            relatedObj = this.selectedDrip.relatedObject || 'Contact';
        } else {
            relatedObj = this.campaignDetails.templateRelatedObject;
        }
        
        return this.allCustomTemplates.filter(template =>
            template.objectName === relatedObj || template.objectName === 'Generic'
        );
    }

    // Show template preview only for EstateXpert templates and Single Marketing Campaign
    get showTemplatePreview() {
        return this.selectedOption === 'single' &&
            this.campaignDetails.templateType === 'EstateXpert Template' &&
            this.selectedTemplate &&
            this.templatePreview.body;
    }

    // Get minimum date for drip start date (today)
    get minDripStartDate() {
        return new Date().toISOString().split('T')[0];
    }

    // Check if we can add more drips
    get canAddDrip() {
        return this.dripSequence.length < 10; // Limit to 10 drips
    }

    get cannotAddDrip() {
        return !this.canAddDrip;
    }

    // Get the selected drip details
    get selectedDrip() {
        return this.dripSequence.find(drip => drip.id === this.selectedDripId);
    }

    // Get the selected drip index (1-based for display)
    get selectedDripIndex() {
        const index = this.dripSequence.findIndex(drip => drip.id === this.selectedDripId);
        return index >= 0 ? index + 1 : 1;
    }

    // Update the dripSequence getter to include formatted time
    get dripSequenceWithFormattedTime() {
        return this.dripSequence.map(drip => ({
            ...drip,
            formattedTime: this.formatTimeForDisplay(drip.timeToSend)
        }));
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

    get computeTimingClass() {
        const drip = this.selectedDrip;
        if (drip && drip.hasInvalidTime) {
            return 'drip-sequence-timing invalid-time';
        }
        return 'drip-sequence-timing';
    }
    
    // Compute CSS class for delay input
    get computeDelayInputClass() {
        const drip = this.selectedDrip;
        if (drip && drip.hasInvalidTime) {
            return 'custom-input delay-input invalid';
        }
        return 'custom-input delay-input';
    }
    
    // Compute CSS class for time input
    get computeTimeInputClass() {
        const drip = this.selectedDrip;
        if (drip && drip.hasInvalidTime) {
            return 'custom-input time-input invalid';
        }
        return 'custom-input time-input';
    }

    get formattedDripStartDate() {
        if (this.dripStartDate) {
            // dripStartDate is in YYYY-MM-DD format
            const [year, month, day] = this.dripStartDate.split('-');
            return `${day}-${month}-${year}`;
        }
        return '';
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

    loadBroadcastGroups(){
        getBroadcastGroups()
        .then(data => {
            if(data && data.length > 0){
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
                    console.log('data from backend ',data);
                    
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

                    console.log('all custom template => ', JSON.stringify(this.allCustomTemplates));
                    
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

                    console.log('Data ==> ', this.allContacts);
                    
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
            return contact ? {...contact} : null;
        }).filter(Boolean);
            
        // Handle CC contacts similarly
        let ccContactIds = this.selectedCCContacts;
        if (ccContactIds && ccContactIds.length > 0 && typeof ccContactIds[0] === 'object') {
            ccContactIds = ccContactIds.map(contact => contact.Id || contact.id);
            this.selectedCCContacts = ccContactIds;
        }
        this.selectedCCContactsDetails = this.selectedCCContacts.map(contactId => {
            const contact = this.allContacts.find(c => c.id === contactId);
            return contact ? {...contact} : null;
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

        console.log('obj name => ',objectName);
        
        if (!objectName) {
            this.filteredEmailTemplates = [];
            this.filteredCustomTemplates = [];
            return;
        }
        
        this.filteredEmailTemplates = [...this.allEmailTemplates];
        
        this.filteredCustomTemplates = this.allCustomTemplates.filter(template => 
            template.objectName === objectName || template.objectName === 'Generic'
        );

        console.log('all custom ',JSON.stringify(this.allCustomTemplates));
        console.log('filter custom temp--> ', JSON.stringify(this.filteredCustomTemplates));
        
    }

    // Handle campaign type selection (auto-advance)
    handleOptionSelect(event) {
        const selectedValue = event.currentTarget.dataset.value;
        this.selectedOption = selectedValue;
        
        if (selectedValue === 'single') {
            this.selectedOptionLabel = 'Single Marketing Campaign';
            // Reset drip data for single campaigns
            this.dripSequence = [];
            this.dripStartDate = null;
            this.nextDripId = 1;
        } else if (selectedValue === 'drip') {
            this.selectedOptionLabel = 'Marketing Campaign Drip';
            // Initialize with one drip when drip campaign is selected
            this.initializeDripSequence();
        }
        
        // Go directly to step 2 (Template Configuration)
        this.currentStep = 2;
    }

    // Helper to get current time + 1 hour in HH:mm format
    getDefaultTimePlusOneHour() {
        const now = new Date();
        now.setHours(now.getHours() + 1);
        return now.getHours().toString().padStart(2, '0') + ':' + 
               now.getMinutes().toString().padStart(2, '0');
    }

    // Initialize drip sequence with first drip
    initializeDripSequence() {
        const defaultTime = this.getDefaultTimePlusOneHour(); 
        this.dripSequence = [{
            id: this.nextDripId++,
            name: 'Email 1',
            template: '',
            subject: '',
            daysAfterStartDate: 0,
            timeToSend: defaultTime,
            formattedTime: this.formatTimeForDisplay(defaultTime),
            displayIndex: 1,
            selectedClass: 'selected',
            canDelete: false,
            hasNoTemplate: true,
            relatedObject: 'Contact', // Added default related object per drip
            selectedListingId: null,
            selectedListingName: '',
            templateLabel: 'No Template Selected',
            templateClass: 'drip-sequence-template no-template'
        }];
        
        // Set the first drip as selected by default
        this.selectedDripId = this.dripSequence[0].id;
        
        // Set default start date to today
        this.dripStartDate = new Date().toISOString().split('T')[0];
    }

    // Get current date and time for validation
    getCurrentDateTime() {
        const now = new Date();
        return {
            date: now.toISOString().split('T')[0],
            time: now.getHours().toString().padStart(2, '0') + ':' + 
                  now.getMinutes().toString().padStart(2, '0')
        };
    }

    // Calculate the minimum allowed time for a specific date and days offset
    getMinimumTimeForDate(startDate, daysOffset) {
        const currentDateTime = this.getCurrentDateTime();
        const targetDate = new Date(startDate);
        targetDate.setDate(targetDate.getDate() + daysOffset);
        const targetDateString = targetDate.toISOString().split('T')[0];
        
        // If target date is today, minimum time should be current time + 15 minutes
        if (targetDateString === currentDateTime.date) {
            const currentTime = new Date();
            currentTime.setMinutes(currentTime.getMinutes() + 15);
            return currentTime.getHours().toString().padStart(2, '0') + ':' + 
                   currentTime.getMinutes().toString().padStart(2, '0');
        }
        
        // For future dates, any time is allowed
        return '00:00';
    }

    // Validate if a date/time combination is in the future
    isDateTimeInFuture(startDate, daysOffset, timeToSend) {
        const currentDateTime = this.getCurrentDateTime();
        const targetDate = new Date(startDate);
        targetDate.setDate(targetDate.getDate() + daysOffset);
        const targetDateString = targetDate.toISOString().split('T')[0];
        
        // If target date is in the past, it's invalid
        if (targetDateString < currentDateTime.date) {
            return false;
        }
        
        // If target date is today, check if time is at least 15 minutes in the future
        if (targetDateString === currentDateTime.date) {
            const currentMinutes = new Date().getHours() * 60 + new Date().getMinutes();
            const [hours, minutes] = timeToSend.split(':');
            const targetMinutes = parseInt(hours) * 60 + parseInt(minutes);
            
            // Must be at least 15 minutes in the future
            return targetMinutes >= currentMinutes + 15;
        }
        
        // Future dates are always valid
        return true;
    }

    // Handle drip start date change
    handleDripStartDateChange(event) {
        const selectedDate = event.target.value;
        const currentDate = this.getCurrentDateTime().date;
        
        // Prevent selecting past dates
        if (selectedDate < currentDate) {
            this.showToast('Error', 'Cannot select a past date for campaign start.', 'error');
            event.target.value = this.dripStartDate; // Reset to previous value
            return;
        }
        
        this.dripStartDate = selectedDate;
        
        // Validate all existing drip times for the new start date
        let hasInvalidTimes = false;
        this.dripSequence = this.dripSequence.map(drip => {
            const isValid = this.isDateTimeInFuture(this.dripStartDate, drip.daysAfterStartDate, drip.timeToSend);
            if (!isValid) {
                hasInvalidTimes = true;
            }
            return {
                ...drip,
                hasInvalidTime: !isValid
            };
        });
        
        if (hasInvalidTimes) {
            this.showToast('Warning', 'Some email times are now in the past and need to be updated.', 'warning');
        }
    }

    // Add new drip to sequence
    handleAddNewEmail() {
        if (!this.canAddDrip) {
            this.showToast('Drip Limit Reached', 'You can add up to 10 emails in a drip sequence.', 'info');
            return;
        }
        if (this.canAddDrip) {
            const defaultTime = this.getDefaultTimePlusOneHour();
            const newDrip = {
                id: this.nextDripId++,
                name: `Email ${this.dripSequence.length + 1}`,
                template: '',
                subject: '',
                daysAfterStartDate: this.dripSequence.length > 0 ? 
                    Math.max(...this.dripSequence.map(d => parseInt(d.daysAfterStartDate) || 0)) + 1 : 1,
                timeToSend: defaultTime,
                formattedTime: this.formatTimeForDisplay(defaultTime),
                displayIndex: this.dripSequence.length + 1,
                selectedClass: '',
                canDelete: true,
                hasNoTemplate: true,
                relatedObject: 'Contact', // Added default related object per drip
                selectedListingId: null,
                selectedListingName: '',
                templateLabel: 'No Template Selected',
                templateClass: 'drip-sequence-template no-template'
            };
            
            // Update existing drips to unselect them and update classes
            this.dripSequence = this.dripSequence.map(drip => ({
                ...drip,
                selectedClass: '',
                canDelete: this.dripSequence.length > 0 // Enable delete for all when we have more than 1
            }));
            
            // Add new drip and select it
            newDrip.selectedClass = 'selected';
            this.dripSequence = [...this.dripSequence, newDrip];
            
            // Select the newly added drip
            this.selectedDripId = newDrip.id;
        }
    }

    // Remove drip from sequence
    handleDeleteEmail(event) {
        event.stopPropagation(); // Prevent triggering the select event
        const dripId = parseInt(event.currentTarget.dataset.id);
        if (this.dripSequence.length > 1) {
            this.dripSequence = this.dripSequence.filter(drip => drip.id !== dripId);
            // Renumber the remaining drips
            this.dripSequence = this.dripSequence.map((drip, index) => ({
                ...drip,
                name: `Email ${index + 1}`,
                displayIndex: index + 1,
                canDelete: this.dripSequence.length > 1 // Update delete availability
            }));
            
            // If deleted drip was selected, select the first available drip
            if (this.selectedDripId === dripId && this.dripSequence.length > 0) {
                this.selectedDripId = this.dripSequence[0].id;
                this.updateDripSelection();
            }
        } else {
            this.showToast('Error', 'At least one email is required for drip campaign.', 'error');
        }
    }

    // Handle drip selection with visual feedback
    handleSelectDrip(event) {
        const dripId = parseInt(event.currentTarget.dataset.id);
        this.selectedDripId = dripId;
        this.updateDripSelection();
    }

    // Update drip selection classes
    updateDripSelection() {
        this.dripSequence = this.dripSequence.map(drip => ({
            ...drip,
            selectedClass: drip.id === this.selectedDripId ? 'selected' : ''
        }));
    }

    // Handle name change for drip emails
    handleNameChange(event) {
        const dripId = parseInt(event.target.dataset.id);
        const emailName = event.target.value;
        
        this.dripSequence = this.dripSequence.map(drip => {
            if (drip.id === dripId) {
                return { ...drip, name: emailName };
            }
            return drip;
        });
    }

    // Handle related object change for a specific drip
    handleDripRelatedObjectChange(event) {
        const dripId = parseInt(event.target.dataset.id);
        const newObject = event.detail.value;
        
        this.dripSequence = this.dripSequence.map(drip => {
            if (drip.id === dripId) {
                return {
                    ...drip,
                    relatedObject: newObject,
                    template: '',
                    subject: '',
                    hasNoTemplate: true,
                    selectedListingId: null,
                    selectedListingName: '',
                    templateLabel: 'No Template Selected',
                    templateClass: 'drip-sequence-template no-template'
                };
            }
            return drip;
        });
    }

    // New getter to get templates based on selected drip
    get dripAvailableTemplates() {
        const drip = this.selectedDrip;
        if (!drip) return [];
        
        let relatedObj = drip.relatedObject || 'Contact';
        return this.allCustomTemplates.filter(template =>
            template.objectName === relatedObj || template.objectName === 'Generic'
        );
    }

    // Handle related object change in template selection step (kept for Single Campaign)
    handleRelatedObjectChange(event) {
        this.campaignDetails.templateRelatedObject = event.detail.value;
        
        // Reset selections on related object change
        this.selectedTemplate = '';
        this.selectedListing = null;
        this.selectedListingName = '';
        
        if (this.isDripCampaign) {
            this.dripSequence = this.dripSequence.map(drip => ({
                ...drip,
                template: '',
                subject: '',
                hasNoTemplate: true,
                selectedListingId: null,
                selectedListingName: '',
                templateLabel: 'No Template Selected',
                templateClass: 'drip-sequence-template no-template'
            }));
        }
    }

    // Handle template change for drip emails
    handleTemplateChange(event) {
        const dripId = parseInt(event.target.dataset.id);
        const selectedTemplateId = event.detail.value;
        
        const selectedTemplate = this.availableTemplates.find(template => template.value === selectedTemplateId);
        
        if (selectedTemplate) {
            this.dripSequence = this.dripSequence.map(drip => {
                if (drip.id === dripId) {
                    return {
                        ...drip,
                        template: selectedTemplate.value,
                        subject: selectedTemplate.subject || '',
                        hasNoTemplate: false,
                        templateLabel: 'Template Selected',
                        templateClass: 'drip-sequence-template',
                        templateType: this.campaignDetails.templateType === 'Email Template' ? 'EmailTemplate' : 'EstateXpertTemplate'
                    };
                }
                return drip;
            });
        }
    }

    // Handle days after start date change
    handleDaysAfterStartDateChange(event) {
        const dripId = parseInt(event.target.dataset.id);
        const newDays = parseInt(event.target.value) || 0;
        
        this.dripSequence = this.dripSequence.map(drip => {
            if (drip.id === dripId) {
                // Validate the new date/time combination
                const isValid = this.isDateTimeInFuture(this.dripStartDate, newDays, drip.timeToSend);
                
                if (!isValid && this.dripStartDate) {
                    this.showToast('Error', 'This date and time combination is in the past. Please select a future time.', 'error');
                }
                
                return { 
                    ...drip, 
                    daysAfterStartDate: newDays,
                    hasInvalidTime: !isValid
                };
            }
            return drip;
        });
    }

    // Handle time to send change
    handleTimeToSendChange(event) {
        const dripId = parseInt(event.target.dataset.id);
        const newTime = event.target.value;
        
        this.dripSequence = this.dripSequence.map(drip => {
            if (drip.id === dripId) {
                // Validate the new date/time combination
                const isValid = this.isDateTimeInFuture(this.dripStartDate, drip.daysAfterStartDate, newTime);
                
                if (!isValid && this.dripStartDate) {
                    const minTime = this.getMinimumTimeForDate(this.dripStartDate, drip.daysAfterStartDate);
                    this.showToast('Error', `Time must be at least ${this.formatTimeForDisplay(minTime)} for this date.`, 'error');
                }
                
                return { 
                    ...drip, 
                    timeToSend: newTime,
                    formattedTime: this.formatTimeForDisplay(newTime),
                    hasInvalidTime: !isValid
                };
            }
            return drip;
        });
    }

    // Handle custom combobox actions for drip listing
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

    handleDripListingSelect(event) {
        event.stopPropagation();
        const listingId = event.currentTarget.dataset.value;
        const listingName = event.currentTarget.dataset.label;
        const dripId = this.selectedDripId;
        
        this.dripSequence = this.dripSequence.map(drip => {
            if (drip.id === dripId) {
                return { 
                    ...drip, 
                    selectedListingId: listingId, 
                    selectedListingName: listingName,
                    template: '', 
                    subject: '',
                    hasNoTemplate: true,
                    templateLabel: 'No Template Selected',
                    templateClass: 'drip-sequence-template no-template'
                };
            }
            return drip;
        });
        this.isListingDropdownOpen = false;
        this.listingSearchTerm = '';
    }

    handleClearDripListing(event) {
        event.stopPropagation();
        const dripId = this.selectedDripId;
        this.dripSequence = this.dripSequence.map(drip => {
            if (drip.id === dripId) {
                return { 
                    ...drip, 
                    selectedListingId: null, 
                    selectedListingName: '',
                    template: '', 
                    subject: '',
                    hasNoTemplate: true,
                    templateLabel: 'No Template Selected',
                    templateClass: 'drip-sequence-template no-template'
                };
            }
            return drip;
        });
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

    // Validate drip sequence
    validateDripSequence() {
        if (!this.dripSequence || this.dripSequence.length === 0) {
            return false;
        }

        // Check if all required fields are filled
        for (let drip of this.dripSequence) {
            // Check basic fields
            if (!drip.name || !drip.template || !drip.timeToSend || drip.daysAfterStartDate == null || !drip.relatedObject) {
                return false;
            }
            
            // Mandatory listing for Listing-type drips
            if (drip.relatedObject === 'MVEX__Listing__c' && !drip.selectedListingId) {
                return false;
            }
            
            // Validate that date/time is in the future
            if (this.dripStartDate && !this.isDateTimeInFuture(this.dripStartDate, drip.daysAfterStartDate, drip.timeToSend)) {
                return false;
            }
        }

        return true;
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

    // Generic button handler
    handleButtonClick(event) {
        const action = event.currentTarget.dataset.action;
        
        switch(action) {
            case 'handleBack':
                this.handleBack();
                break;
            case 'handleNext':
                this.handleNext();
                break;
            case 'handleFinish':
                this.handleFinish();
                break;
        }
    }

    // Handle back button
    handleBack() {
        if (this.currentStep > 1) {
            this.currentStep--;
            if (this.currentStep === 1) {
                this.selectedOption = '';
                this.selectedOptionLabel = '';
                this.dripSequence = [];
                this.dripStartDate = null;
                this.nextDripId = 1;
            }
        }
    }

    // Handle next button
    handleNext() {
        if (!this.validateCurrentStep()) {
            return;
        }

        if (this.currentStep < this.totalSteps) {
            this.currentStep++;
        }
    }

    // Handle finish button - Now doing all transformations in JavaScript
    handleFinish() {
        if (!this.validateCurrentStep()) {
            return;
        }

        // Show loading state
        const finishButton = this.template.querySelector('[data-action="handleFinish"]');
        if (finishButton) {
            finishButton.disabled = true;
            finishButton.textContent = this.isDripCampaign ? 'Creating Campaign...' : 'Sending Emails...';
        }

        try {
            if (this.isSingleCampaign) {
                console.log('handleSingleCampaignSend');
                this.handleSingleCampaignSend();
            } else {
                console.log('handleDripCampaignCreate');
                this.handleDripCampaignCreate();
            }
        } catch (error) {
            console.error('Error in handleFinish:', error);
            this.showToast('Error', 'An unexpected error occurred: ' + error.message, 'error');
            this.resetFinishButton(finishButton);
        }
    }

    // Handle single campaign - create campaign record and send immediately
    handleSingleCampaignSend() {
        try {
            // Validate recipients limit for single messaging service
            const estimatedTotalRecipients = this.selectedContactsDetails.length + this.estimatedContactsFromGroups;
            if (this.campaignDetails.messagingService === 'outlook' && estimatedTotalRecipients > 20) {
                throw new Error('Outlook has a limit of 20 recipients. Please select fewer recipients or use a different messaging service.');
            }

            // Create a single email record for immediate sending
            const currentDateTime = new Date();
            const singleEmailRecord = {
                id: 1,
                name: 'Immediate Email',
                template: this.selectedTemplate,
                templateType: this.campaignDetails.templateType === 'Email Template' ? 'EmailTemplate' : 'EstateXpertTemplate',
                subject: this.templatePreview.subject || 'Marketing Email',
                daysAfterStartDate: 0, // Send immediately
                timeToSend: currentDateTime.getHours().toString().padStart(2, '0') + ':' + 
                           currentDateTime.getMinutes().toString().padStart(2, '0') + ':00',
                exactDate: currentDateTime.toISOString().split('T')[0], // Today's date
                disabled: false,
                selectedListingId: this.selectedListing || '',
                isListingSelectionDisabled: !this.selectedListing
            };

            // Transform data to match EmailCampaignController structure
            const campaignEmailData = {
                templateId: '', // No template ID for new campaigns
                campaignId: '', // No campaign ID for new campaigns
                relatedObject: this.campaignDetails.objectName,
                campaignName: this.campaignDetails.campaignName,
                messagingService: this.campaignDetails.messagingService,
                saveForFuture: false, // Not saving as template
                selectedPrimaryRecipients: this.transformRecipientsPrimary(this.selectedContactsDetails),
                selectedCCRecipients: this.transformRecipients(this.selectedCCContactsDetails),
                selectedBCCRecipients: [], // No BCC in current implementation
                emails: [singleEmailRecord], // Single email record
                specificDate: currentDateTime.toISOString().split('T')[0], // Today's date
                selectedContactDateField: '', // Using specific date
                deletedEmailList: [], // No deleted emails for new campaigns
                // Add broadcast groups to the data
                selectedBroadcastGroups: this.selectedBroadcastGroups
            };

            console.log('Creating single campaign with immediate send:', JSON.stringify(campaignEmailData));

            // Call EmailCampaignController.createCampaignAndEmails for single campaign too
            createCampaignAndEmails({ jsonCampaignEmailData: JSON.stringify(campaignEmailData), isImmediateSend: true })
                .then((campaignId) => {
                    this.showToast('Success', 'Marketing campaign created and emails will be sent immediately!', 'success');
                    console.log('Single campaign created with ID:', campaignId);
                    this.closeModal();
                })
                .catch(error => {
                    console.error('Error creating single campaign:', error);
                    this.showToast('Error', 'Failed to create campaign: ' + (error.body?.message || error.message), 'error');
                })
                .finally(() => {
                    this.resetFinishButton();
                });

        } catch (error) {
            console.error('Error preparing single campaign:', error);
            this.showToast('Error', 'Failed to prepare campaign data: ' + error.message, 'error');
            this.resetFinishButton();
        }
    }

    // Handle drip campaign - create campaign records like emailCampaignTemplateForm.js
    handleDripCampaignCreate() {
        try {
            // Validate recipients limit
            const totalRecipients = this.selectedContactsDetails.length + this.selectedCCContactsDetails.length;
            if (this.campaignDetails.messagingService === 'outlook' && totalRecipients > 20) {
                throw new Error('Outlook has a limit of 20 recipients. Please select fewer recipients.');
            }

            // Transform drip emails to match EmailCampaignController structure
            const transformedEmails = this.dripSequence.map(drip => ({
                id: drip.id,
                name: drip.name || `Email ${drip.displayIndex}`,
                template: drip.template,
                templateType: this.campaignDetails.templateType === 'Email Template' ? 'EmailTemplate' : 'EstateXpertTemplate',
                subject: drip.subject,
                daysAfterStartDate: drip.daysAfterStartDate,
                timeToSend: drip.timeToSend + ':00', // Add seconds as EmailCampaignController expects
                exactDate: this.dripStartDate,
                disabled: false,
                selectedListingId: drip.selectedListingId || this.selectedListing || '',
                isListingSelectionDisabled: !drip.selectedListingId && !this.selectedListing
            }));

            // Transform data exactly like emailCampaignTemplateForm.js does
            const campaignEmailData = {
                templateId: '', // No template ID for new campaigns
                campaignId: '', // No campaign ID for new campaigns
                relatedObject: this.campaignDetails.objectName,
                campaignName: this.campaignDetails.campaignName,
                messagingService: this.campaignDetails.messagingService,
                saveForFuture: false, // Not saving as template
                selectedPrimaryRecipients: this.transformRecipientsPrimary(this.selectedContactsDetails),
                selectedCCRecipients: this.transformRecipients(this.selectedCCContactsDetails),
                selectedBCCRecipients: [], // No BCC in current implementation
                emails: transformedEmails,
                specificDate: this.dripStartDate,
                selectedContactDateField: '', // Using specific date, not contact field
                deletedEmailList: [], // No deleted emails for new campaigns
                // Add broadcast groups to the data
                selectedBroadcastGroups: this.selectedBroadcastGroups
            };

            // Log the combination for debugging
            console.log('Individual recipients:', this.selectedContactsDetails.length);
            console.log('Broadcast groups selected:', this.selectedBroadcastGroups.length);
            console.log('Estimated total from groups:', this.estimatedContactsFromGroups);
            console.log('Creating drip campaign with data:', JSON.stringify(campaignEmailData));

            // Call EmailCampaignController.createCampaignAndEmails
            createCampaignAndEmails({ jsonCampaignEmailData: JSON.stringify(campaignEmailData), isImmediateSend: false })
                .then((campaignId) => {
                    this.showToast('Success', 'Drip campaign created successfully!', 'success');
                    console.log('Campaign created with ID:', campaignId);
                    this.closeModal();
                })
                .catch(error => {
                    console.error('Error creating drip campaign:', error);
                    this.showToast('Error', 'Failed to create campaign: ' + (error.body?.message || error.message), 'error');
                })
                .finally(() => {
                    this.resetFinishButton();
                });

        } catch (error) {
            console.error('Error preparing drip campaign:', error);
            this.showToast('Error', 'Failed to prepare campaign data: ' + error.message, 'error');
            this.resetFinishButton();
        }
    }

    // Transform primary recipients like emailCampaignTemplateForm.js
    transformRecipientsPrimary(recipients) {
        return recipients.map(recipient => recipient.id);
    }

    // Transform CC/BCC recipients like emailCampaignTemplateForm.js
    transformRecipients(recipients) {
        return recipients.map(recipient => `${recipient.id}:${recipient.email}`);
    }

    // Reset finish button state
    resetFinishButton(button) {
        const finishButton = button || this.template.querySelector('[data-action="handleFinish"]');
        if (finishButton) {
            finishButton.disabled = this.selectedContacts.length === 0;
            finishButton.textContent = this.isDripCampaign ? 'Create Campaign' : 'Send Emails';
        }
    }

    // Validate current step
    validateCurrentStep() {
        if (this.currentStep === 1) {
            if (!this.selectedOption) {
                this.showToast('Error', 'Please select a campaign type.', 'error');
                return false;
            }
        } else if (this.currentStep === 2) {
            if (this.isDripCampaign) {
                if (!this.dripStartDate) {
                    this.showToast('Error', 'Please select a start date for your drip campaign.', 'error');
                    return false;
                }
                
                // Validate start date is not in the past
                if (this.dripStartDate < this.getCurrentDateTime().date) {
                    this.showToast('Error', 'Campaign start date cannot be in the past.', 'error');
                    return false;
                }
                
                if (this.dripSequence.length === 0) {
                    this.showToast('Error', 'Please add at least one drip email.', 'error');
                    return false;
                }
                
                if (!this.validateDripSequence()) {
                    this.showToast('Error', 'Please fill in all required fields for each drip email and ensure all dates/times are in the future.', 'error');
                    return false;
                }
                
                // Check for invalid times
                const hasInvalidTimes = this.dripSequence.some(drip => 
                    !this.isDateTimeInFuture(this.dripStartDate, drip.daysAfterStartDate, drip.timeToSend)
                );
                
                if (hasInvalidTimes) {
                    this.showToast('Error', 'Some emails are scheduled for past dates/times. Please update them to future dates/times.', 'error');
                    return false;
                }
                
                // Validate duplicate date-time combinations
                const uniqueDateTimeValues = new Set();
                let hasDuplicateDateTime = false;
                this.dripSequence.forEach(drip => {
                    const dateTimeKey = `${drip.daysAfterStartDate}-${drip.timeToSend}`;
                    if (uniqueDateTimeValues.has(dateTimeKey)) {
                        hasDuplicateDateTime = true;
                        return;
                    } else {
                        uniqueDateTimeValues.add(dateTimeKey);
                    }
                });
                if (hasDuplicateDateTime) {
                    this.showToast('Error', 'There are duplicate "Days After Start Date" and "Time to Send" values. Please ensure each email has a unique combination.', 'error');
                    return false;
                }
            } else {
                // Single campaign validation
                if (!this.selectedTemplate) {
                    this.showToast('Error', 'Please select a template.', 'error');
                    return false;
                }
                if (this.showSingleListingSelector && !this.selectedListing) {
                    this.showToast('Error', 'Please select a listing.', 'error');
                    return false;
                }
            }
        } else if (this.currentStep === 3) {
            if (!this.campaignDetails.campaignName || !this.campaignDetails.messagingService) {
                this.showToast('Error', 'Please fill in all campaign details.', 'error');
                return false;
            }
            if (this.selectedContacts.length === 0 && this.selectedBroadcastGroups.length === 0) {
                this.showToast('Error', 'Please select at least one contact or broadcast group.', 'error');
                return false;
            }
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
        this.currentStep = 1;
        this.selectedOption = '';
        this.selectedOptionLabel = '';
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
        
        // Reset drip campaign data
        this.dripSequence = [];
        this.dripStartDate = null;
        this.nextDripId = 1;
        this.selectedDripId = null; // Reset selected drip
        
        this.campaignDetails = {
            objectName: 'Contact',
            templateRelatedObject: 'Contact',
            campaignName: '',
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

    handleCloseModal(){
        this.isPreviewModal = false;
        this.selectedTemplateId = '';
    }

    handlePreviewSingleTemplate() {
        if (this.selectedTemplate) {
            this.selectedTemplateId = this.selectedTemplate;
            this.templateStatus = true;
            this.isPreviewModal = true;
        }
    }

    // Preview selected template for a drip email via parent/another component
    handlePreviewDripTemplate(event) {
        const dripId = parseInt(event.currentTarget.dataset.id);
        const drip = this.dripSequence.find(d => d.id === dripId);

        if (!drip || !drip.template) {
            this.showToast('Error', 'Please select a template to preview.', 'error');
            return;
        }

        // Find template details from availableTemplates
        const selectedTemplate = this.availableTemplates.find(t => t.value === drip.template);

        if (selectedTemplate) {
            this.selectedTemplateId = selectedTemplate.value;
            this.templateStatus = true; // Assuming template is active
            this.isPreviewModal = true;
        } else {
            this.showToast('Error', 'Selected template not found.', 'error');
        }
    }

    // Method to compute listing class (removed type class logic)
    getListingClass(listing) {
        return `listing-item slds-box slds-box_x-small ${this.selectedListing === listing.value ? 'selected' : ''}`;
    }

    // Add this method to format time for display
    formatTimeForDisplay(time24) {
        if (!time24) return '';
        
        const [hours, minutes] = time24.split(':');
        const hour = parseInt(hours);
        const minute = parseInt(minutes);
        const ampm = hour >= 12 ? 'PM' : 'AM';
        const displayHour = hour === 0 ? 12 : hour > 12 ? hour - 12 : hour;
        
        return `${displayHour}:${minute.toString().padStart(2, '0')} ${ampm}`;
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