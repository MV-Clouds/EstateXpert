/*
 * Component Name: WbCreateTemplatePage
 * @description: Used LWC components to show create templates in meta and store in the template record.
 * Date: 25/11/2024
 * Created By: Rachit Shah
 */
/***********************************************************************
MODIFICATION LOG*
* Last Update Date : 29/04/2025
* Updated By : Rachit Shah
* Change Description : Code Rework
********************************************************************** */

import { LightningElement, track, api } from 'lwc';
import { loadStyle, loadScript } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import wbCreateTempStyle from '@salesforce/resourceUrl/wbCreateTempStyle';
import richTextZip from '@salesforce/resourceUrl/richTextZip';
import buttonIconsZip from '@salesforce/resourceUrl/buttonIconsZip';
import emojiData from '@salesforce/resourceUrl/emojis_data';
import CountryJson from '@salesforce/resourceUrl/CountryJson';
import LanguageJson from '@salesforce/resourceUrl/LanguageJson';
import createWhatsappTemplate from '@salesforce/apex/WBTemplateController.createWhatsappTemplate';
import editWhatsappTemplate from '@salesforce/apex/WBTemplateController.editWhatsappTemplate';
import startUploadSession from '@salesforce/apex/WBTemplateController.startUploadSession';
import uploadFileChunk from '@salesforce/apex/WBTemplateController.uploadFileChunk';
import getObjectFields from '@salesforce/apex/WBTemplateController.getObjectFields';
import getWhatsAppTemplates from '@salesforce/apex/WBTemplateController.getWhatsAppTemplates';
import getDynamicObjectData from '@salesforce/apex/WBTemplateController.getDynamicObjectData';
import tempLocationIcon from '@salesforce/resourceUrl/tempLocationIcon';
import tempVideoIcon from '@salesforce/resourceUrl/tempVideoIcon';
import imageUploadPreview from '@salesforce/resourceUrl/imageUploadPreview';
import docUploadPreview from '@salesforce/resourceUrl/documentPreviewIcon';
import NoPreviewAvailable from '@salesforce/resourceUrl/NoPreviewAvailable';
import uploadFile from '@salesforce/apex/FileUploaderController.uploadFile';
import deleteFile from '@salesforce/apex/FileUploaderController.deleteFile';
import getObjectsWithPhoneField from '@salesforce/apex/WBTemplateController.getObjectsWithPhoneField';
import getCompanyName from '@salesforce/apex/WBTemplateController.getCompanyName';
import getS3ConfigSettings from '@salesforce/apex/AWSFilesController.getS3ConfigSettings';
import deleteImagesFromS3 from '@salesforce/apex/AWSFilesController.deleteImagesFromS3';
import AWS_SDK from "@salesforce/resourceUrl/AWSSDK";
import buildPayload from './wbCreateTemplateWrapper'
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';

export default class WbCreateTemplatePage extends NavigationMixin(LightningElement) {
    LIMITS = {
        maxTempNamelength: 512,
        maxShortlength: 60,
        maxTempBodyLength: 1024,
        maxWebsiteUrl: 2000,
        maxBtnTxt: 25,
        maxPhonetxt: 20,
        maxCodetxt: 15,
        maxPackTxt: 224,
        maxHashTxt: 11,
        chunkSize: 3145728
    };
    _edittemplateid;
    file;
    fileName = '';
    fileSize = 0;
    fileType = '';
    uploadSessionId = '';
    companyName = '';

    dropdownOptions = [
        { title: 'Custom', value: 'QUICK_REPLY', iconName: 'custom' },
        { title: 'Marketing Opt-Out', value: 'Marketing opt-out', iconName: 'marketing', description: 'Maximum 1 button can be added' },
        { title: 'Call Phone Number', value: 'PHONE_NUMBER', iconName: 'phone', description: 'Maximum 1 button can be added' },
        { title: 'Visit Website', value: 'URL', iconName: 'site', description: 'Maximum 2 buttons can be added' },
        { title: 'Copy Offer Code', value: 'COPY_CODE', iconName: 'copy', description: 'Maximum 1 button can be added' },
        // { title: 'Complete flow', value: 'FLOW', iconName: 'flow', description: 'Maximum 1 button can be added' }
    ];

    toolbarButtons = [
        { title: 'bold', iconName: 'bold' },
        { title: 'italic', iconName: 'italic' },
        { title: 'strikethrough', iconName: 'stike' },
        { title: 'codeIcon', iconName: 'code' }
    ];

    @track contentVersionId;
    @track isNewTemplate = true;
    @track isEditTemplate = false;
    @track totalButtonsCount = 0;
    @track visitWebsiteCount = 0;
    @track callPhoneNumber = 0;
    @track copyOfferCode = 0;
    @track flowCount = 0;
    @track marketingOpt = 0;
    @track iseditTemplatevisible = false;
    @track isPreviewTemplate = false;
    @track showReviewTemplate = false;
    @track IsHeaderText = false;
    @track addHeaderVar = false;
    @track addMedia = false;
    @track isImageFile = false;
    @track isImageFileUploader = false;
    @track isImgSelected = false;
    @track isDocSelected = false;
    @track isVidSelected = false;
    @track isVideoFile = false;
    @track isDocFile = false;
    @track isVideoFileUploader = false;
    @track isDocFileUploader = false;
    @track isLocation = false;
    @track isCallPhone = false;
    @track isOfferCode = false;
    @track isVisitSite = false;
    @track isFlow = false;
    @track isCustom = false;
    @track createButton = false;
    @track isButtonDisabled = false;
    @track isStopMarketing = false;
    @track buttonDisabled = false;
    @track isRefreshEnabled = true;
    @track isLoading = false;
    @track templateExists = false;
    @track showEmojis = false;
    @track isCheckboxChecked = false;
    @track showDefaultBtn = true;
    @track templateName = '';
    @track header = '';
    @track footer = '';
    @track tempBody = 'Hello';
    @track formatedTempBody = this.tempBody;
    @track previewBody = 'Hello';
    @track previewHeader = '';
    @track btntext = '';
    @track webURL = '';
    @track Cbtntext = '';
    @track selectedAction = '';
    @track selectedUrlType = 'Static';
    @track variables = [];
    @track header_variables = [];
    @track nextIndex = 1;
    @track headIndex = 1;
    @track selectedOption = 'Custom';
    @track activeSection = 'section1';
    @track selectedLabel = 'Add button';
    @track selectedContentType = 'None';
    @track selectedLanguage = 'en_US';
    @track selectedActionType = '';
    @track selectedCountryType = '+971';
    @track originalTempBody = '';
    @track placeholderMap = {};
    @track buttonList = [];
    @track customButtonList = [];
    @track emojis;
    @track originalHeader = '';
    @track menuButtonSelected;
    @track headerHandle = '';
    @track isfilename = false;
    @track NoFileSelected = true;
    @track filePreview = '';
    @track languageOptions = [];
    @track countryType = [];
    @track availableObjects = [];
    @track selectedObject = '';
    @track fields = [];
    @track chatMessages = [];
    @track richTextZip = richTextZip;
    @track buttonIconsZip = buttonIconsZip;
    @track isDropdownOpen = false;
    @track dropdownClass = 'dropdown-hidden';
    @track emojiCategories = [];
    @track templateId = '';
    @track metaTemplateId = '';
    @track allTemplates = [];
    @track headerError = '';
    @track imageurl = '';
    @track contentDocumentId = '';
    @track isRendered = false;
    @track utilityOrderStatusSelected = false;
    @track defaultPreview = true;
    @track authenticationPasscodeSelected = false;
    @track UtilityCustomSelected = false;
    @track isDefault = true;
    @track ifAuthentication = false;
    @track isAppSetup = true;
    @track showAutofill = true;
    @track showAuthBtn = false;
    @track authZeroTab = true;
    @track isautofillChecked = false;
    @track selectContent = ['Add security recommendation'];
    @track showOneTap = false;
    @track autofilLabel = 'Autofill';
    @track autoCopyCode = 'Copy Code';
    @track value = 'zero_tap';
    @track packages = [
        { id: 1, packagename: '', signature: '', curPackageName: 0, curHashCode: 0 }
    ];
    @track expirationTime = 300;
    @track isExpiration = false;
    @track prevContent = true;
    @track maxPackages = 5;
    @track showMsgValidity = false;
    @track authPrevBody = `{{1}}`;
    @track isAddCallPhoneNumber = false;
    @track isAddVisitWebsiteCount = false;
    @track isAddCopyOfferCode = false;
    @track isAddFlow = false;
    @track tempLocationIcon = tempLocationIcon;
    @track tempVideoIcon = tempVideoIcon;
    @track imageUploadPreview = imageUploadPreview;
    @track docUploadPreviewImg = docUploadPreview;
    @track NoPreviewAvailableImg = NoPreviewAvailable;
    @track isFeatureEnabled = false;
    @track selectedTime = '5 minutes';
    @track isFlowMarketing = false;
    @track isFlowUtility = false;
    @track isFlowSelected = false;
    @track isModalOpen = false;
    @track selectedFlowId = '';
    @track selectedFlow;
    @track iframeSrc;
    @track isModalPreview = false;
    @track showCategoryPage = true;
    @track isAWSEnabled = false;
    @track confData;
    @track s3;
    @track isAwsSdkInitialized = true;
    @track selectedFilesToUpload = [];
    @track awsFileName;
    @api activeTab;
    @api selectedTab;

    // ============================
    // OPTIONS PROVIDERS (Dropdown values)
    // ============================

    get expireTime() {
        // Options for expiration times
        return [
            { label: '1 minute', value: '1 minute' },
            { label: '2 minutes', value: '2 minutes' },
            { label: '3 minutes', value: '3 minutes' },
            { label: '5 minutes', value: '5 minutes' },
            { label: '10 minutes', value: '10 minutes' }
        ];
    }

    get contentOption() {
        // Options for content actions
        return [
            { label: 'Add security recommendation', value: 'Add security recommendation' },
            { label: 'Add expiry time for the code', value: 'Add expiry time for the code' },
        ];
    }

    get typeOptions() {
        // Options for content types
        return [
            { label: 'None', value: 'None' },
            { label: 'Text', value: 'Text' },
            { label: 'Image', value: 'Image' },
            { label: 'Video', value: 'Video' },
            { label: 'Document', value: 'Document' }
        ];
    }

    get typeactionOption() {
        // Options for call-to-action buttons

        return [
            { label: 'Call Phone Number', value: 'PHONE_NUMBER' },
            { label: 'Visit Website', value: 'URL' },
            { label: 'Copy Offer Code', value: 'COPY_CODE' },
            { label: 'Complete flow', value: 'FLOW' }
        ];
    }

    get customOption() {
        // Options for custom quick reply buttons
        return [
            { label: 'Custom', value: 'QUICK_REPLY' },
            { label: 'Marketing opt-out', value: 'Marketing opt-out' }
        ];
    }

    get urlType() {
        // Options for URL types
        return [
            { label: 'Static', value: 'Static' }
        ];
    }

    // ============================
    // GETTERS FOR CONDITIONS / DISABLES
    // ============================

    get flowBooleanCheck() {
        // Check if the active flow is Marketing or Utility
        return this.isFlowMarketing || this.isFlowUtility;
    }

    get acceptedFormats() {
        // Allowed file formats for upload
        return ['png', 'jpeg', 'jpg'];
    }

    get selectedLanguageLabel() {
        // Get the selected language's label
        const selectedOption = this.languageOptions.find(option => option.value === this.selectedLanguage);
        return selectedOption ? selectedOption.label : '';
    }

    get hasButtons() {
        // Check if there are any buttons present
        return this.buttonList.length > 0 || this.customButtonList.length > 0;
    }

    get buttonListWithDisabledState() {
        // Disable 'Marketing opt-out' buttons from editing
        return this.customButtonList.map(button => ({
            ...button,
            isDisabled: button.selectedCustomType === 'Marketing opt-out'
        }));
    }

    // Limits for buttons
    get visitWebsiteDisabled() {
        return this.visitWebsiteCount >= 2;
    }

    get callPhoneNumberDisabled() {
        return this.callPhoneNumber >= 1;
    }

    get copyOfferDisabled() {
        return this.copyOfferCode >= 1;
    }

    get flowDisabled() {
        return this.flowCount >= 1;
    }

    get marketingOptDisabled() {
        return this.marketingOpt >= 1;
    }

    get buttonClass() {
        // Class for buttons depending on disabled state
        return this.isButtonDisabled ? 'select-button disabled' : 'select-button';
    }

    // ============================
    // TEMPLATE VARIABLES MAPPINGS
    // ============================

    get tempHeaderExample() {
        // Map header variables into string format
        return this.header_variables.map(varItem => `{{${varItem.object}.${varItem.field}}}`);
    }

    get templateBodyText() {
        // Map body variables into string format
        return this.variables.map(varItem => `{{${varItem.object}.${varItem.field}}}`);
    }

    // ============================
    // BUTTONS, TOOLBARS, OPTIONS
    // ============================

    get refreshButtonClass() {
        // Class for refresh button based on enabled state
        return this.isRefreshEnabled ? 'refresh-icon refresh-disabled' : 'refresh-icon';
    }

    get computedVariables() {
        // Add selection state to fields for each variable
        return this.variables.map(varItem => ({
            ...varItem,
            options: this.fields ? this.fields.map(field => ({
                ...field,
                isSelected: field.value === varItem.field
            })) : []

        }));
    }

    get computedHeaderVariables() {
        // Add selection state to fields for each variable
        return this.header_variables.map(varItem => ({
            ...varItem,
            options: this.fields ? this.fields.map(field => ({
                ...field,
                isSelected: field.value === varItem.field
            })) : []

        }));
    }

    get availableObjectsWithSelection() {
        // Highlight the selected object
        return this.availableObjects.map(obj => ({
            ...obj,
            isSelected: obj.value === this.selectedObject
        }));
    }

    get toolbarButtonsWithClasses() {
        // Set icon paths and classes for toolbar buttons
        return this.toolbarButtons.map(button => ({
            ...button,
            iconUrl: this.getIconPath(button.iconName),
            classes: `toolbar-button ${button.title.toLowerCase()}`,
            imgClasses: `custom-icon ${button.iconName.toLowerCase()}`
        }));
    }

    // ============================
    // FORM SUBMIT ENABLE / DISABLE
    // ============================

    get isSubmitDisabled() {
        // Logic to determine if form submission should be disabled based on fields' validity
        const currentTemplate = this.activeTab;
        const areButtonFieldsFilled = this.buttonList.every(button =>
            button.btntext && (button.webURL || button.phonenum || button.offercode || button.isFlow)
        );
        const areCustomButtonFilled = this.customButtonList.every(button => button.Cbtntext);
        const hasCustomButtonError = this.customButtonList.some(button => button.hasError);
        const hasButtonListError = this.buttonList.some(button => button.hasError);

        // Header validation
        const headerImageNotSelected = this.selectedContentType === 'Image' && !this.headerHandle;
        const headerVideoNotSelected = this.selectedContentType === 'Video' && !this.headerHandle;
        const headerDocumentNotSelected = this.selectedContentType === 'Document' && !this.headerHandle;
        const headerTextNotSelected = this.selectedContentType === 'Text' && !this.header;
        const hasHeaderError = !!this.headerError;

        let headerFileNotSelected = false;
        if (this.selectedContentType === 'Document') {
            headerFileNotSelected = headerDocumentNotSelected;
        } else if (this.selectedContentType === 'Image') {
            headerFileNotSelected = headerImageNotSelected;
        } else if (this.selectedContentType === 'Video') {
            headerFileNotSelected = headerVideoNotSelected;
        }

        const result = (() => {
            switch (currentTemplate) {
                case 'Marketing':
                case 'Utility':
                    if (this.flowBooleanCheck) {
                        return !(this.selectedFlow !== undefined && this.templateName && this.tempBody &&
                            areButtonFieldsFilled && areCustomButtonFilled && !this.templateExists &&
                            !hasCustomButtonError && !hasButtonListError && !headerFileNotSelected &&
                            !hasHeaderError && !headerTextNotSelected);
                    }
                    return !(this.templateName && this.tempBody && areButtonFieldsFilled && areCustomButtonFilled &&
                        !this.templateExists && !hasCustomButtonError && !hasButtonListError &&
                        !headerFileNotSelected && !hasHeaderError && !headerTextNotSelected);

                case 'Authentication':
                    if (this.value === 'zero_tap') {
                        return !(this.templateName && this.isautofillChecked && this.autoCopyCode && this.autofilLabel);
                    } else if (this.value === 'ONE_TAP') {
                        return !(this.templateName && this.autoCopyCode && this.autofilLabel);
                    } else if (this.value === 'COPY_CODE') {
                        return !(this.templateName && this.autoCopyCode);
                    } else {
                        return true;
                    }
                default:
                    return true;
            }
        })();
        return result;
    }

    // ============================
    // UI CONDITIONALS
    // ============================

    get showRemoveButton() {
        // Show remove button if more than one package
        return this.packages.length > 1;
    }

    get quickReplyOptions() {
        // Dropdown options for quick replies
        return this.dropdownOptions
            .filter(option => this.activeTab == 'Utility' ?
                option.value === 'QUICK_REPLY' :
                option.value === 'QUICK_REPLY' || option.value === 'Marketing opt-out')
            .map(option => ({
                ...option,
                iconUrl: this.getButtonPath(option.iconName),
                classes: `dropdown-item ${option.title.toLowerCase().replace(/\s+/g, '-')}`
            }));
    }

    get callToActionOptions() {
        // Dropdown options for call-to-actions
        return this.dropdownOptions
            .filter(option => ['PHONE_NUMBER', 'URL', 'FLOW', 'COPY_CODE'].includes(option.value))
            .map(option => ({
                ...option,
                iconUrl: this.getButtonPath(option.iconName),
                classes: `dropdown-item ${option.title.toLowerCase().replace(/\s+/g, '-')}`
            }));
    }

    get isZeroTapSelected() {
        return this.value === 'zero_tap';
    }

    get isOneTapSelected() {
        return this.value === 'ONE_TAP';
    }

    get isCopyCodeSelected() {
        return this.value === 'COPY_CODE';
    }

    // ============================
    // API PROPERTIES (GET/SET)
    // ============================

    @api
    get edittemplateid() {
        // API exposed getter for edittemplateid
        return this._edittemplateid;
    }

    set edittemplateid(value) {
        // Setter to control template states when edittemplateid is set
        this._edittemplateid = value;
        if (this._edittemplateid) {
            this.isNewTemplate = false;
            this.isEditTemplate = true;

            // this.isAllTemplate = false;
            this.fetchTemplateData(); // Load template data when ID is set
        }
    }

    getIconPath(iconName) {
        return `${richTextZip}/rich-texticon/${iconName}.png`;
    }

    openModal() {
        this.isModalOpen = true;
    }

    closeModal() {
        this.isModalOpen = false;
        this.isModalPreview = false;
    }
    modalPreview() {
        this.isModalPreview = true;
    }

    handleFlowSelection(event) {
        const { selectedFlow, iframeSrc, flows } = event.detail; // Destructure the received data

        this.selectedFlowId = selectedFlow; // Get selected Flow ID
        this.iframeSrc = iframeSrc;
        this.selectedFlow = flows; // Store the entire list of flows


        this.isFlowSelected = true; // Hide "Choose Flow" button after selection
        this.NoFileSelected = false; // Hide text after selection
        this.closeModal();
    }

    handleFlowDeleteClick() {
        this.isFlowSelected = false;
        this.selectedFlowId = ''; // Get selected Flow ID
        this.selectedFlow = undefined;
        this.NoFileSelected = true;
    }

    convertTimeToSeconds(label) {
        const timeMap = {
            '1 minute': 60,
            '2 minutes': 120,
            '3 minutes': 180,
            '5 minutes': 300,
            '10 minutes': 600
        };
        return timeMap[label] || 300; // Default to 5 minutes if not found
    }

    getButtonIcon(type) {
        const iconMap = {
            'QUICK_REPLY': 'utility:reply',
            'Marketing opt-out': 'utility:reply',
            'PHONE_NUMBER': 'utility:call',
            'URL': 'utility:new_window',
            'COPY_CODE': 'utility:copy',
            'FLOW': 'utility:file'
        };
        return iconMap[type] || 'utility:question';
    }

    handleTabClick(sectionname) {
        this.activeSection = sectionname;
        this.isFlowMarketing = false;
        this.isFlowUtility = false;
        this.showMsgValidity = false;
        this.ifAuthentication = false;
        this.isDefault = true;
        if (this.activeSection === 'section2') {
            this.showMsgValidity = true;
        } else if (this.activeSection === 'section3') {
            this.ifAuthentication = true;
            this.showMsgValidity = true;
            this.isDefault = false;
        }
        this.handleDefaultValues();
    }

    handleDefaultValues() {
        this.utilityOrderStatusSelected = false;
        this.authenticationPasscodeSelected = false;
        this.UtilityCustomSelected = false;
        this.defaultPreview = false;

        this.isFlowMarketing = false;
        this.isFlowUtility = false;
        this.showDefaultBtn = true;

        switch (this.selectedOption) {
            case 'ORDER_STATUS':
                this.utilityOrderStatusSelected = true;
                this.showDefaultBtn = false;
                break;
            case 'One-time passcode':
                this.authenticationPasscodeSelected = true;
                break;
            case 'Custom':
                this.UtilityCustomSelected = true;
                break;
            case 'CustomMarketing':
                this.defaultPreview = true;
                break;
            case 'Flow':
                this.isFlowMarketing = true;
                break;
            case 'flowutility':
                this.isFlowUtility = true;
                break;
            default:
                this.defaultPreview = true;
                break;
        }

    }

    handleRadioChange(optionname) {
        // this.selectedOption = '';
        this.selectedOption = optionname;


        this.ifUtilty = false;
        // this.showDefaultBtn = false;
        this.utilityOrderStatusSelected = false;
        this.authenticationPasscodeSelected = false;
        this.UtilityCustomSelected = false;
        this.defaultPreview = false;
        this.isFlowMarketing = false;
        this.isFlowUtility = false;
        this.showDefaultBtn = true;

        switch (this.selectedOption) {
            case 'ORDER_STATUS':
                this.ifUtilty = true;
                this.utilityOrderStatusSelected = true;
                this.showDefaultBtn = false;
                break;
            case 'One-time passcode':
                this.authenticationPasscodeSelected = true;
                break;
            case 'Custom':
                this.UtilityCustomSelected = true;
                break;
            case 'Flow':
                this.isFlowMarketing = true;
                this.handleMenuSelect({
                    currentTarget: {
                        dataset: {
                            value: 'FLOW',
                            buttonData: false
                        }
                    }
                });
                break;
            case 'flowutility':
                this.isFlowUtility = true;
                this.handleMenuSelect({
                    currentTarget: {
                        dataset: {
                            value: 'FLOW',
                            buttonData: false
                        }
                    }
                });
                break;
            default:
                this.defaultPreview = true;
                break;
        }

    }

    handleChange(event) {
        this.value = event.target.value;

        this.authZeroTab = false;
        this.isAppSetup = false;
        this.showAutofill = false;
        this.showAuthBtn = false;
        this.showOneTap = false;

        switch (this.value) {
            case 'zero_tap':
                this.authZeroTab = true;
                this.isAppSetup = true;
                this.showAutofill = true;
                break;

            case 'COPY_CODE':
                this.showAuthBtn = true;
                break;

            case 'ONE_TAP':
                this.isAppSetup = true;
                this.showAutofill = true;
                this.showOneTap = true;
                break;

            default:
                break;
        }
    }

    addOutsideClickListener() {
        document.addEventListener('click', this.handleOutsideClick.bind(this));
    }

    connectedCallback() {
        try {
            loadStyle(this, MulishFontCss)
            .then(() => {
                console.log('External Css Loaded');
            })
            .catch(error => {
                console.log('Error occuring during loading external css', error);
            });

            this.iseditTemplatevisible = true;
            if (this.selectedTab != undefined && this.selectedOption != undefined) {
                this.handleTabClick(this.selectedTab);
                this.handleRadioChange(this.selectedOption);
            }

            this.getS3ConfigDataAsync();
            this.fetchCountries();
            this.fetchLanguages();
            this.generateEmojiCategories();
            this.fetchUpdatedTemplates(false);
            this.fetchObjectsWithPhoneField();
            getCompanyName()
                .then(result => {
                    this.companyName = result;
                })
                .catch(error => {
                    console.error('Error fetching company name:', error);
                });
        } catch (e) {
            console.error('Error in connectedCallback:::', e.message);
        }
    }

    getS3ConfigDataAsync() {
        try {
            getS3ConfigSettings()
                .then(result => {
                    if (result != null) {
                        this.confData = result;
                        this.isAWSEnabled = true;
                    }
                }).catch(error => {
                    console.error('error in apex -> ', error.stack);
                });
        } catch (error) {
            console.error('error in getS3ConfigDataAsync -> ', error.stack);
        }
    }

    removeOutsideClickListener() {
        document.removeEventListener('click', this.handleOutsideClick.bind(this));
    }

    disconnectedCallback() {
        this.removeOutsideClickListener();
    }

    handleOutsideClick(event) {
        const emojiContainer = this.template.querySelector('.toolbar-button');
        const button = this.template.querySelector('button');
        if (
            (emojiContainer && !emojiContainer.contains(event.target)) &&
            (button && !button.contains(event.target))
        ) {
            this.showEmojis = false;
            this.removeOutsideClickListener();
        }
        if (this.template.querySelector('.dropdown-container') && !this.template.querySelector('.dropdown-container').contains(event.target)) {
            if (this.isDropdownOpen) {
                this.isDropdownOpen = false;
                this.dropdownClass = 'dropdown-hidden';
            }
        }
    }

    fetchObjectsWithPhoneField() {
        this.isLoading = true;
        getObjectsWithPhoneField()
            .then((result) => {
                this.availableObjects = result;
                const showingObject = {"label":"Showing","value":"MVEX__Showing__c"};
                this.availableObjects = [showingObject, ...this.availableObjects];
                this.selectedObject = this.availableObjects[0].value;
                this.fetchFields(this.selectedObject);
            })
            .catch((error) => {
                console.error('Error fetching objects with phone field: ', error);
                this.showToastError('Error fetching objects with phone field: ' + error.message);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    renderedCallback() {
        try {
            loadStyle(this, wbCreateTempStyle).then().catch(error => {
                console.error("Error in loading the colors", error);
            })


            if (this.isRendered) return;
            this.isRendered = true;
            let headerEls = this.template.querySelectorAll('.field-header-dd');
            if (headerEls != null && this.addHeaderVar) {
                for (let i = 0; i < this.header_variables.length; i++) {
                    this.header_variables.forEach((hv, i) => {
                        headerEls[i].value = hv.field;
                    })
                }
                this.addHeaderVar = false;
            }
            let bodyEls = this.template.querySelectorAll('.field-body-dd');
            if (bodyEls != null && this.addVar) {
                this.variables.forEach((bv, i) => {
                    bodyEls[i].value = bv.field;
                })
                this.addVar = false;
            }

            if (this.isAwsSdkInitialized) {
                Promise.all([loadScript(this, AWS_SDK)])
                    .then(() => {
                        // console.log('Script loaded successfully');
                    })
                    .catch((error) => {
                        console.error("error -> ", error);
                    });

                this.isAwsSdkInitialized = false;
            }
        } catch (error) {
            console.error('Error in function renderedCallback:::', error.message);
        }
    }

    fetchTemplateData() {
        try {
            this.isLoading = true;
            getDynamicObjectData({ templateId: this.edittemplateid })
                .then((data) => {
                    const { template, templateVariables } = data;

                    this.selectedOption = template.MVEX__Template_Type__c;
                    this.activeTab = template.MVEX__Template_Category__c;
                    if (this.activeTab === 'Marketing') {
                        this.selectedTab = 'section1';
                    } else if (this.activeTab === 'Utility') {
                        this.selectedTab = 'section2';
                    } else if (this.activeTab === 'Authentication') {
                        this.selectedTab = 'section3';
                    }

                    this.handleTabClick(this.selectedTab);
                    this.handleRadioChange(this.selectedOption);
                    setTimeout(() => {
                        this.handleObjectChange({ target: { value: templateVariables[0].objName } });
                    }, 700);
                    setTimeout(() => {

                        this.templateName = template.MVEX__Template_Name__c || '';
                        this.metaTemplateId = template.MVEX__Template_Id__c || '';
                        const headerBody = template.MVEX__WBHeader_Body__c || '';

                        const headerType = template.MVEX__Header_Type__c || 'None';

                        this.footer = template.MVEX__WBFooter_Body__c || '';
                        this.selectedLanguage = template.MVEX__Language__c;
                        this.languageOptions = this.languageOptions.map(option => ({
                            ...option,
                            isSelected: option.value === this.selectedLanguage
                        }));

                        this.tempBody = template.MVEX__WBTemplate_Body__c || 'Hello';
                        this.formatedTempBody = this.formatText(this.tempBody);
                        this.previewBody = this.tempBody ? this.formatText(this.tempBody) : 'Hello';

                        try {
                            const templateMiscellaneousData = JSON.parse(template.MVEX__Template_Miscellaneous_Data__c);
                            this.contentVersionId = templateMiscellaneousData.contentVersionId
                            this.isImageFile = templateMiscellaneousData.isImageFile
                            this.isImgSelected = templateMiscellaneousData.isImgSelected
                            this.isDocSelected = templateMiscellaneousData.isDocSelected
                            this.isVidSelected = templateMiscellaneousData.isVidSelected
                            this.IsHeaderText = templateMiscellaneousData.isHeaderText
                            this.addHeaderVar = templateMiscellaneousData.addHeaderVar
                            this.addMedia = templateMiscellaneousData.addMedia
                            this.isImageFileUploader = templateMiscellaneousData.isImageFileUploader
                            this.isVideoFileUploader = templateMiscellaneousData.isVideoFileUploader
                            this.isDocFileUploader = templateMiscellaneousData.isDocFileUploader
                            this.isVideoFile = templateMiscellaneousData.isVideoFile
                            this.isDocFile = templateMiscellaneousData.isDocFile
                            this.prevContent = templateMiscellaneousData.isSecurityRecommedation
                            this.isExpiration = templateMiscellaneousData.isCodeExpiration
                            this.expirationTime = templateMiscellaneousData.expireTime
                            this.value = templateMiscellaneousData.authRadioButton
                            this.isautofillChecked = templateMiscellaneousData.autofillCheck
                            this.isVisitSite = templateMiscellaneousData.isVisitSite
                            this.isCheckboxChecked = templateMiscellaneousData.isCheckboxChecked
                            // this.flowBooleanCheck = templateMiscellaneousData.flowBooleanCheck
                            this.isFlowMarketing = templateMiscellaneousData.isFlowMarketing
                            this.isFlowUtility = templateMiscellaneousData.isFlowUtility
                            this.isFlowSelected = templateMiscellaneousData.isFlowSelected
                            this.selectedFlow = templateMiscellaneousData.isFlowSelected
                            this.isFeatureEnabled = templateMiscellaneousData.isFeatureEnabled
                            this.awsFileName = templateMiscellaneousData.awsFileName

                            if (this.awsFileName && !this.isAWSEnabled) {
                                this.showToastError('AWS Configration missing')
                            }
                        }
                        catch (error) {
                            console.error('templateMiscellaneousData Error ::: ', error)
                        }

                        if (this.activeTab === 'Authentication' && this.value) {
                            const event = {
                                target: {
                                    value: this.value
                                }
                            };
                            this.handleChange(event);
                        }

                        // const parser = new DOMParser();
                        // const doc = parser.parseFromString(template?.WBHeader_Body__c, "text/html");
                        // this.previewHeader = doc.documentElement.textContent;
                        if (template.MVEX__Header_Type__c == 'Image' || template.MVEX__Header_Type__c == 'Video' || template.MVEX__Header_Type__c == 'Document') {
                            const parser = new DOMParser();
                            const doc = parser.parseFromString(template?.MVEX__WBHeader_Body__c, "text/html");
                            this.previewHeader = doc.documentElement.textContent || "";

                            this.fileName = template.MVEX__File_Name__c;
                            this.fileType = template.MVEX__Header_Type__c;

                            this.filePreview = template.MVEX__WBHeader_Body__c;

                        } else {
                            this.previewHeader = this.formatText(headerBody) || '';
                        }


                        // this.previewHeader= this.formatText(headerBody) ||'';
                        this.selectedContentType = template.MVEX__Header_Type__c || 'None';
                        this.btntext = template.MVEX__Button_Label__c || '';
                        let tvs = templateVariables.map(tv => {
                            let temp = {
                                object: tv.objName,
                                field: tv.fieldName,
                                alternateText: tv.alternateText ? tv.alternateText : '',
                                id: tv.variable.slice(2, 3),
                                index: tv.variable,
                                type: tv.type
                            };
                            return temp;
                        })
                        // this.fields = tvs.map(tv => tv.field);
                        const tempfieldsBody = tvs.filter(tv => tv.type == 'Body').map(tv => tv.field);
                        this.variables = tvs.filter(tv => tv.type == 'Body') || [];
                        this.variables = this.variables.map((variable, index) => ({
                            ...variable,
                            field: tempfieldsBody[index] || variable.field // fallback to original field if index is missing
                        }));

                        const tempfieldsHead = tvs.filter(tv => tv.type == 'Header').map(tv => tv.field);
                        this.header_variables = tvs.filter(tv => tv.type == 'Header') || [];
                        this.header_variables = this.header_variables.map((variable, index) => ({
                            ...variable,
                            field: tempfieldsHead[index] || variable.field // fallback to original field if index is missing
                        }));
                        this.updatePreviewContent(this.previewHeader, 'header');
                        this.updatePreviewContent(this.previewBody, 'body');
                        this.addHeaderVar = this.header_variables?.length > 0 ? true : false;
                        this.addVar = this.variables?.length > 0 ? true : false;
                        if (this.addHeaderVar) {
                            this.buttonDisabled = true;
                        }
                        if (template.MVEX__WBButton_Body__c) {
                            // Parse JSON from WBButton_Body__c
                            let buttonDataList = JSON.parse(template.MVEX__WBButton_Body__c);

                            // Clear existing button and custom button lists before populating
                            this.buttonList = [];
                            this.customButtonList = [];
                            this.callPhoneNumber = 0;
                            this.visitWebsiteCount = 0;
                            this.copyOfferCode = 0;
                            this.flowCount = 0;
                            this.marketingOpt = 0;

                            buttonDataList.forEach((button, index) => {
                                if (button.type === 'QUICK_REPLY' || button.type === 'Marketing opt-out') {
                                    // Handle custom buttons
                                    try {
                                        if (button.isMarketingOpt) {
                                            button.type = 'Marketing opt-out';
                                        }
                                    }
                                    catch (error) {
                                        console.error(error);
                                    }
                                    let buttonData = {
                                        btntext: button.text
                                    }

                                    this.handleMenuSelect({
                                        currentTarget: {
                                            dataset: {
                                                value: button.type,
                                                buttonData: buttonData
                                            }
                                        }
                                    });
                                } else {

                                    // Handle regular buttons
                                    let newButton = {
                                        id: index + 1, // Unique ID for button
                                        selectedActionType: button.type || '',
                                        iconName: this.getButtonIcon(button.type),
                                        btntext: button.text || '',
                                        webURL: button.url || '',
                                        phonenum: button.phone_number || '',
                                        offercode: button.example || '',
                                        selectedUrlType: button.type === 'URL' ? 'Static' : '',
                                        selectedCountryType: button.phone_number ? button.phone_number.split(' ')[0] : '',
                                        isCallPhone: button.type === 'PHONE_NUMBER',
                                        isVisitSite: button.type === 'URL',
                                        isOfferCode: button.type === 'COPY_CODE',
                                        isFlow: button.type === 'FLOW',
                                        hasError: false,
                                        errorMessage: ''
                                    };

                                    // Call handleMenuSelect() to process button creation correctly
                                    this.handleMenuSelect({
                                        currentTarget: {
                                            dataset: {
                                                value: button.type,
                                                buttonData: newButton
                                            }
                                        }
                                    });
                                }
                            });

                        }


                        if (headerType.toLowerCase() == 'image' || headerType.toLowerCase() == 'video') {
                            this.headerHandle = template.MVEX__WBImage_Header_Handle__c;
                            this.imageurl = template.MVEX__WBHeader_Body__c;
                            this.NoFileSelected = false;
                            this.isfilename = true;
                            this.fileName = template.MVEX__File_Name__c;
                            this.fileType = template.MVEX__Header_Type__c.toLowerCase();

                            this.filePreview = headerBody;
                        }
                        else {
                            this.header = headerBody.trim().replace(/^\*\*|\*\*$/g, '');
                        }
                        this.loading = false;
                    }, 2000);
                })
                .catch((error) => {
                    console.error('Error fetching fields: ', error);
                    this.isLoading = false;
                });
        } catch (error) {
            console.error('Error fetching template data: ', error);
            this.isLoading = false;
        }
    }

    //fetch object related fields
    fetchFields(objectName) {
        try {
            getObjectFields({ objectName: objectName })
                .then((result) => {
                    this.fields = result.map((field) => ({ label: field, value: field }));
                })
                .catch((error) => {
                    console.error('Error fetching fields: ', error);
                });
        } catch (error) {
            console.error('Error fetching objects fields: ', error);
        }
    }

    // Handle file selection
    async handleFileChange(event) {
        try {
            const file = event.target.files[0];

            if (file) {
                this.file = file;
                this.fileName = file.name;
                this.fileType = file.type;
                this.fileSize = file.size;

                // if (this.isAWSEnabled) {
                let isValid = false;
                let maxSize = 4;
                let fileSizeMB = Math.floor(file.size / (1024 * 1024));
                isValid = fileSizeMB <= maxSize;
                // if (this.fileType.startsWith('image/')) {
                //     maxSize = 5;
                //     isValid = fileSizeMB <= maxSize;
                // } else if (this.fileType.startsWith('video/')) {
                //     maxSize = 16;
                //     isValid = fileSizeMB <= maxSize;
                // } else if (this.fileType.includes('application/') || this.fileType.includes('text/')) {
                //     maxSize = 100;
                //     isValid = fileSizeMB <= maxSize;
                // }
                // else {
                //     // console.log('Else OUT');
                // }

                if (isValid) {
                    this.selectedFilesToUpload.push(file);
                    // this.fileName = file.name;
                    this.isLoading = true;
                    if (this.isAWSEnabled) {
                        await this.uploadToAWS(this.selectedFilesToUpload);
                    } else {
                        const reader = new FileReader();
                        reader.onload = () => {
                            this.fileData = reader.result.split(',')[1];
                            // this.generatePreview(file);
                            this.handleUpload(); // Auto-upload
                        };
                        reader.readAsDataURL(file);
                    }
                } else {
                    // this.isLoading = false;
                    this.showToastError(`${file.name} exceeds the ${maxSize}MB limit`);
                }
                // }
                // else {
                // const reader = new FileReader();
                // reader.onload = () => {
                //     this.fileData = reader.result.split(',')[1];
                //     // this.generatePreview(file);
                //     this.handleUpload(); // Auto-upload
                // };
                // reader.readAsDataURL(file);
                // }

            }
        } catch (error) {
            console.error('Error in file upload:', error);
        }
    }

    initializeAwsSdk(confData) {
        try {
            let AWS = window.AWS;

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
            console.error("error initializeAwsSdk ", error);
        }
    }

    // renameFileName(filename) {
    //     try {
    //         let originalFileName = filename;
    //         let extensionIndex = originalFileName.lastIndexOf('.');
    //         let baseFileName = originalFileName.substring(0, extensionIndex);
    //         let extension = originalFileName.substring(extensionIndex + 1);

    //         let objKey = `${baseFileName}.${extension}`
    //             .replace(/\s+/g, "_");
    //         return objKey;
    //     } catch (error) {
    //         console.error('error in renameFileName -> ', error.stack);
    //     }
    // }
    renameFileName(filename) {
        try {
            let extensionIndex = filename.lastIndexOf('.');
            let baseFileName = filename.substring(0, extensionIndex);
            let extension = filename.substring(extensionIndex + 1);

            // Get current timestamp in YYYYMMDD_HHmmss format
            let now = new Date();
            let timestamp = `${now.getFullYear()}${(now.getMonth() + 1)
                .toString().padStart(2, '0')}${now.getDate()
                    .toString().padStart(2, '0')}_${now.getHours()
                        .toString().padStart(2, '0')}${now.getMinutes()
                            .toString().padStart(2, '0')}${now.getSeconds()
                                .toString().padStart(2, '0')}`;

            let uniqueFileName = `${baseFileName}_${timestamp}.${extension}`.replace(/\s+/g, "_");
            return uniqueFileName;
        } catch (error) {
            console.error('error in renameFileName -> ', error.stack);
        }
    }

    async uploadToAWS() {
        try {
            this.isLoading = true;
            this.initializeAwsSdk(this.confData);
            const uploadPromises = this.selectedFilesToUpload.map(async (file) => {
                this.isLoading = true;
                let objKey = this.renameFileName(this.fileName);

                let params = {
                    Key: objKey,
                    ContentType: file.type,
                    Body: file,
                    ACL: "public-read"
                };

                let upload = this.s3.upload(params);

                return await upload.promise();
            });
            // Wait for all uploads to complete
            const results = await Promise.all(uploadPromises);
            results.forEach((result) => {
                if (result) {
                    let bucketName = this.confData.MVEX__S3_Bucket_Name__c;
                    let objKey = result.Key;
                    let awsFileUrl = `https://${bucketName}.s3.amazonaws.com/${objKey}`;

                    this.awsFileName = objKey;
                    this.generatePreview(awsFileUrl);
                    // this.

                    this.uploadFile();
                }
            });

        } catch (error) {
            this.isLoading = false;
            console.error("Error in uploadToAWS: ", error);
        }
    }

    // Generate file preview
    generatePreview(publicUrl) {
        try {
            let typeCategory = '';

            if (this.fileType.startsWith('image/')) {
                typeCategory = 'image';
            } else if (this.fileType.startsWith('video/')) {
                typeCategory = 'video';
            } else if (this.fileType === 'application/pdf') {
                typeCategory = 'pdf';
            } else {
                typeCategory = 'unsupported';
            }

            switch (typeCategory) {
                case 'image':
                    this.isImgSelected = true;
                    this.isDocSelected = false;
                    this.isVidSelected = false;
                    this.isImageFile = false;
                    this.filePreview = publicUrl;
                    break;

                case 'video':
                    this.isImgSelected = false;
                    this.isDocSelected = false;
                    this.isVidSelected = true;
                    this.isVideoFile = false;
                    this.filePreview = publicUrl;
                    break;

                case 'pdf':
                    this.isDocSelected = true;
                    this.isImgSelected = false;
                    this.isVidSelected = false;
                    this.isDocFile = false;
                    this.filePreview = publicUrl;
                    break;

                case 'unsupported':
                default:
                    this.isImgSelected = false;
                    this.isDocSelected = false;
                    this.isVidSelected = false;
                    this.showToastError('Unsupported file type! Please select an image, PDF, or video.');
                    break;
            }

            this.isfilename = true;
            this.NoFileSelected = false;
        } catch (error) {
            console.error('Error in generatePreview: ', error);
        }
    }


    // Upload file to Apex
    handleUpload() {
        if (this.fileData) {
            this.isLoading = true;
            uploadFile({ base64Data: this.fileData, fileName: this.fileName })
                .then((result) => {
                    this.contentVersionId = result.contentVersionId;
                    const publicUrl = result.publicUrl;

                    // Replace '/sfc/p/#' with '/sfc/p/' if needed
                    this.generatePreview(publicUrl.replace('/sfc/p/#', '/sfc/p/'));

                    this.uploadFile(); // If this is a different method, otherwise consider renaming
                })
                .catch((error) => {
                    console.error('❌ Error uploading file: ', error);
                    this.isLoading = false;
                    this.showToastError('Error uploading file!');
                });
        } else {
            this.showToastError('Please select a file first!');

        }
    }

    // Delete file from ContentVersion
    handleDelete() {

        if (this.contentVersionId) {
            deleteFile({ contentVersionId: this.contentVersionId })
                .then(() => {
                    this.showToastSuccess('File deleted successfully');
                    this.resetFileData(); // Reset file data after deletion
                })
                .catch((error) => {
                    console.error('Error deleting file: ', error);
                    this.showToastError('Error deleting file!');
                });
        }
        else if (this.isAWSEnabled) {
            deleteImagesFromS3({ fileNames: [this.awsFileName] })
                .then(() => {
                    this.showToastSuccess('File deleted successfully');
                    this.resetFileData(); // Reset file data after deletion
                })
                .catch((error) => {
                    console.error('Error deleting file: ', error);
                    this.showToastError('Error deleting file!');
                });
        }
    }

    // Reset file data after deletion
    resetFileData() {
        this.file = null;
        this.fileName = null;
        this.fileData = null;
        this.fileType = null;
        this.fileSize = null;
        this.filePreview = null;

        const fileInput = this.template.querySelector('.file-input');
        if (fileInput) {
            fileInput.value = '';
        }

        if (this.isImgSelected) {
            this.isImageFile = true;
        }
        else if (this.isVidSelected) {
            this.isVideoFile = true;
        }
        else if (this.isDocSelected) {
            this.isDocFile = true;
        }
        this.isImgSelected = false;
        this.isDocSelected = false;
        this.isVidSelected = false;
        this.isfilename = false;
        this.NoFileSelected = true;
        this.contentVersionId = null;
        this.headerHandle = '';
        this.awsFileName = '';
    }

    uploadFile() {
        try {
            this.isLoading = true;
            if (!this.file) {
                this.isLoading = false;
                this.showToastError('Please select a file to upload.');

                return;
            }

            startUploadSession({
                fileName: this.fileName,
                fileLength: this.fileSize,
                fileType: this.fileType
            })
                .then(result => {
                    if (result) {
                        this.uploadSessionId = result;
                        this.uploadChunks();
                    } else {
                        console.error('Failed to start upload session.');
                        this.showToastError('Failed to start upload session.');
                        this.isLoading = false;
                    }
                })
                .catch(error => {
                    console.error('Failed upload session.', error.body);
                    this.isLoading = false;
                })
        } catch (error) {
            console.error('Error starting upload session: ', error);
        }
    }

    uploadChunks() {
        try {
            let chunkStart = 0;
            const uploadNextChunk = () => {

                const chunkEnd = Math.min(chunkStart + this.LIMITS.chunkSize, this.fileSize);
                const chunk = this.file.slice(chunkStart, chunkEnd);
                const reader = new FileReader();
                const isLastChunk = (chunkEnd >= this.fileSize);


                reader.onloadend = async () => {
                    const base64Data = reader.result.split(',')[1];
                    const fileChunkWrapper = {
                        uploadSessionId: this.uploadSessionId,
                        fileContent: base64Data,
                        chunkStart: chunkStart,
                        chunkSize: base64Data.length,
                        fileName: this.fileName,
                        isLastChunk: isLastChunk
                    };
                    const serializedWrapper = JSON.stringify(fileChunkWrapper);

                    uploadFileChunk({ serializedWrapper: serializedWrapper, isAWSEnabled: this.isAWSEnabled })
                        .then(result => {
                            if (result) {
                                let serializeResult = JSON.parse(result);
                                this.headerHandle = serializeResult.headerHandle;
                                if (!this.isAWSEnabled) {
                                    this.contentDocumentId = serializeResult.contentDocumentId;
                                }

                                chunkStart += this.LIMITS.chunkSize;
                                if (chunkStart < this.fileSize) {
                                    uploadNextChunk();
                                } else {
                                    this.isLoading = false;
                                    this.showToastSuccess('File upload successfully.');
                                }
                            } else {
                                console.error('Failed to upload file chunk.');
                                this.isLoading = false;
                                this.showToastError('Failed to upload file chunk.');
                            }
                        })
                        .catch(error => {
                            console.error('Failed upload session.', error);
                            this.isLoading = false;
                            this.showToastError(error.body.message || 'An error occurred while uploading image.');
                        })
                };

                reader.readAsDataURL(chunk);
            };

            uploadNextChunk();
        } catch (error) {
            this.isLoading = false;
            console.error('Error uploading file chunk: ', error);
        }
    }

    handleContentType(event) {
        try {
            this.NoFileSelected = true;
            this.isfilename = false;
            this.selectedContentType = event.target.value;

            // Check if the content type is 'Text'
            if (this.selectedContentType === 'Text') {
                this.IsHeaderText = true;
            } else {
                this.IsHeaderText = false;
            }

            // Reset all flags
            const resetFlags = () => {
                this.isImgSelected = false;
                this.isDocSelected = false;
                this.isVidSelected = false;
                this.isImageFileUploader = false;
                this.isVideoFileUploader = false;
                this.isDocFileUploader = false;
                this.isLocation = false;
                this.addMedia = false;
                this.isImageFile = false;
                this.isVideoFile = false;
                this.isDocFile = false;
            };

            // Handle the different content types
            if (['Image', 'Video', 'Document', 'Location'].includes(this.selectedContentType)) {
                resetFlags();

                if (this.selectedContentType === 'Image') {
                    this.isImageFile = true;
                    this.isImageFileUploader = true;
                    this.addMedia = true;
                } else if (this.selectedContentType === 'Video') {
                    this.isVideoFile = true;
                    this.isVideoFileUploader = true;
                    this.addMedia = true;
                } else if (this.selectedContentType === 'Document') {
                    this.isDocFile = true;
                    this.isDocFileUploader = true;
                    this.addMedia = true;
                } else if (this.selectedContentType === 'Location') {
                    this.isLocation = true;
                }
            } else {
                // If the selected content type is invalid or none of the above
                resetFlags();
            }

        } catch (error) {
            console.error('Something went wrong while selecting content type: ', JSON.stringify(error));
        }
    }

    handlePrevclick() {
        if (this.contentVersionId != null && !this.isEditTemplate) {
            this.handleDelete();
        }
        this.clearEditTemplateData();

        if (!this.isEditTemplate) {
            const previousEvent = new CustomEvent('previous', {
                detail: {
                    selectedTab: this.selectedTab,
                    selectedOption: this.selectedOption,
                    activeTab: this.activeTab
                }
            });
            this.dispatchEvent(previousEvent);
        } else {
            this.navigateToAllTemplatePage();
        }

    }


    clearEditTemplateData() {

        this.templateName = '';
        this.selectedContentType = 'None';
        this.header = '';
        this.addHeaderVar = false;
        this.content = '';
        this.tempBody = 'Hello';
        this.addVar = false;
        this.footer = '';
        var tempList = [];
        this.buttonList = tempList;
        this.customButtonList = [];
        this.variables = [];
        this.header_variables = [];
        this.buttonDisabled = false;
        this.originalHeader = [];
        this.nextIndex = 1;
        this.headIndex = 1;
        this.createButton = false;
        this.IsHeaderText = false;
        this.isCustom = false;
        this.formatedTempBody = this.tempBody;
        this.visitWebsiteCount = 0;
        this.callPhoneNumber = 0;
        this.copyOfferCode = 0;
        this.flowCount = 0;
        this.marketingOpt = 0;
        this.selectContent = 'Add security recommendation';
        this.addMedia = false;
        this.isDocSelected = false;
        this.isVidSelected = false;
        this.isImgSelected = false;
        this.isDocFile = false;
        this.isFlowSelected = false;

        this.isautofillChecked = false;
        this.isExpiration = false;
        const headerInput = this.template.querySelector('input[name="header"]');
        if (headerInput) {
            headerInput.value = '';
        }

    }

    handleCustom(event) {
        this.selectedCustomType = event.target.value;
    }

    handleInputChange(event) {
        try {
            const { name, value, checked, dataset } = event.target;
            const index = dataset.index;



            switch (name) {
                case 'templateName':

                    this.templateName = value.replace(/\s+/g, '_').toLowerCase();

                    this.checkTemplateExistence();
                    break;
                case 'language':
                    this.selectedLanguage = value;
                    this.languageOptions = this.languageOptions.map(option => ({
                        ...option,
                        isSelected: option.value === this.selectedLanguage
                    }));
                    break;
                case 'footer':
                    this.footer = value;
                    break;
                case 'tempBody':
                    this.tempBody = value.replace(/(\n\s*){3,}/g, '\n\n');
                    this.formatedTempBody = this.formatText(this.tempBody);
                    this.updatePreviewContent(this.formatedTempBody, 'body');
                    break;
                case 'btntext':
                    this.updateButtonProperty(index, 'btntext', value);
                    this.validateButtonText(index, value);
                    break;
                case 'selectedUrlType':
                    this.updateButtonProperty(index, 'selectedUrlType', value);
                    break;
                case 'webURL':
                    this.updateButtonProperty(index, 'webURL', value);
                    break;
                case 'selectedCountryType':
                    this.updateButtonProperty(index, 'selectedCountryType', value);
                    this.selectedCountryType = value;
                    break;
                case 'phonenum':
                    this.updateButtonProperty(index, 'phonenum', value);
                    break;
                case 'offercode':
                    this.updateButtonProperty(index, 'offercode', value);
                    break;
                case 'isCheckboxChecked':
                    this.isCheckboxChecked = checked;
                    break;
                case 'isautofillChecked':
                    this.isautofillChecked = checked;
                    break;
                // Change
                case 'prevContent':
                    if (this.prevContent) {
                        this.prevContent = false;
                    }
                    else {
                        this.prevContent = true;
                    }
                    break;

                case 'isExpiration':
                    if (this.isExpiration) {
                        this.isExpiration = false;
                    }
                    else {
                        this.isExpiration = true;
                    }
                    break;

                case 'autofill':
                    this.autofilLabel = value;
                    break;

                case 'expirationTime':
                    this.expirationTime = value;
                    break;

                case 'selectedTime':
                    this.selectedTime = value;
                    this.expirationTime = this.convertTimeToSeconds(value); // Convert selected time to seconds
                    break;
                case 'autoCopyCode':
                    this.autoCopyCode = value;
                    break;

                case 'toggle':
                    if (this.isFeatureEnabled) {
                        this.isFeatureEnabled = false;
                    }
                    else {
                        this.isFeatureEnabled = checked;
                    }
                    break;
                case 'header':
                    this.header = value;
                    const variableMatches = (value.match(/\{\{\d+\}\}/g) || []).length;
                    if (variableMatches > 1) {
                        this.headerError = 'Only one variable is allowed in the header.';
                    } else {
                        this.headerError = '';
                        this.updatePreviewContent(this.header, 'header');
                    }

                    break;
                default:
                    break;
            }
        } catch (error) {
            console.error('Something went wrong: ', error);
        }
    }

    updateButtonProperty(index, property, value) {
        this.buttonList[index][property] = value;
    }

    checkTemplateExistence() {
        try {

            if (Array.isArray(this.allTemplates)) {
                this.templateExists = this.allTemplates.some(
                    template => template.MVEX__Template_Name__c?.toLowerCase() === this.templateName?.toLowerCase()
                );
            } else {
                console.warn('allTemplates is not an array or is null/undefined');
                this.templateExists = false;
            }
        } catch (error) {
            console.error(error.message);
            this.showToastError(error.message || 'An error occurred while checking template existence.');
        }

    }

    handleRemove(event) {
        try {
            const index = event.currentTarget.dataset.index;
            const removedButton = this.buttonList[index];
            if (removedButton && removedButton.isVisitSite) {
                this.visitWebsiteCount--;
            } else if (removedButton && removedButton.isCallPhone) {
                this.callPhoneNumber--;
            } else if (removedButton && removedButton.isOfferCode) {
                this.copyOfferCode--;
            }
            else if (removedButton && removedButton.isFlow) {
                this.flowCount--;
            }
            this.buttonList = this.buttonList.filter((_, i) => i !== parseInt(index));
            if (this.buttonList.length == 0) {
                this.createButton = false;
            }
            this.totalButtonsCount--;
            this.updateButtonDisabledState();
        } catch (error) {
            console.error('Error while removing button.', error);
        }
    }

    handleMenuSelect(event) {
        try {
            // const selectedValue = event.detail.value;
            const selectedValue = event.currentTarget.dataset.value;
            this.menuButtonSelected = selectedValue;
            let buttonData = event.currentTarget.dataset.buttonData;
            let newButton = buttonData ? buttonData : {
                id: this.buttonList.length + 1,
                selectedActionType: selectedValue,
                iconName: this.getButtonIcon(selectedValue),
                btntext: '',
                webURL: '',
                phonenum: '',
                offercode: '',
                selectedUrlType: 'Static',
                selectedCountryType: '',
                isCallPhone: false,
                isVisitSite: false,
                isOfferCode: false,
                isFlow: false,
                hasError: false,
                errorMessage: ''
            };



            this.isAddCallPhoneNumber = false;
            this.isAddVisitWebsiteCount = false;
            this.isAddCopyOfferCode = false;
            this.isAddFlow = false;

            switch (selectedValue) {
                case 'QUICK_REPLY':
                    this.isCustom = true;

                    const quickReplyText = buttonData && buttonData.btntext ? buttonData.btntext : 'Quick reply';
                    this.createCustomButton('QUICK_REPLY', quickReplyText);
                    this.isStopMarketing = false;
                    break;
                case 'Marketing opt-out':
                    if (this.marketingOpt < 1) {
                        this.isCustom = true;

                        this.isStopMarketing = true;
                        const stopPromoText = buttonData && buttonData.btntext ? buttonData.btntext : 'Stop promotions';
                        this.createCustomButton('Marketing opt-out', stopPromoText);
                        this.marketingOpt++;
                    }
                    break;
                case 'PHONE_NUMBER':
                    if (this.callPhoneNumber < 1) {
                        this.createButton = true;
                        newButton.isCallPhone = true;
                        newButton.btntext = buttonData?.btntext || 'Call Phone Number';
                        this.btntext = buttonData?.btntext || 'Call Phone Number';
                        this.callPhoneNumber++;
                        this.isAddCallPhoneNumber = true;
                    }
                    break;
                case 'URL':
                    if (this.visitWebsiteCount < 2) {
                        this.createButton = true;
                        newButton.isVisitSite = true;
                        this.isVisitSite = true;
                        newButton.btntext = buttonData?.btntext || 'Visit Website';
                        this.btntext = buttonData?.btntext || 'Visit Website';
                        this.visitWebsiteCount++;
                        this.isAddVisitWebsiteCount = true;
                    }
                    break;
                case 'COPY_CODE':
                    if (this.copyOfferCode < 1) {

                        this.createButton = true;
                        newButton.isOfferCode = true;
                        newButton.btntext = buttonData?.btntext || 'Copy Offer Code';
                        this.btntext = buttonData?.btntext || 'Copy Offer Code';

                        // newButton.btntext = buttonData?.btntext || 'Copy Offer Code';
                        // this.btntext = buttonData?.btntext || 'Copy Offer Code';
                        this.copyOfferCode++;
                        this.isAddCopyOfferCode = true;
                    }
                    break;
                case 'FLOW':

                    if (this.flowCount < 1) {

                        this.createButton = true;
                        newButton.isFlow = true;
                        newButton.btntext = buttonData?.btntext || 'View flow';
                        this.btntext = buttonData?.btntext || 'View flow';

                        // newButton.btntext = buttonData?.btntext || 'Copy Offer Code';
                        // this.btntext = buttonData?.btntext || 'Copy Offer Code';
                        this.flowCount++;
                        this.isAddFlow = true;
                    }
                    break;
                default:
                    newButton.btntext = 'Add Button';
            }

            const isDuplicate = this.buttonList.some(button => button.btntext === newButton.btntext);
            if (isDuplicate) {
                newButton.hasError = true;
                newButton.errorMessage = 'You have entered same text for multiple buttons.';
            } else {
                newButton.hasError = false;
                newButton.errorMessage = '';
            }

            if (newButton.selectedActionType != 'QUICK_REPLY' && newButton.selectedActionType != 'Marketing opt-out') {
                if (this.isAddCallPhoneNumber || this.isAddCopyOfferCode || this.isAddVisitWebsiteCount || this.isAddFlow) {

                    this.buttonList.push(newButton);
                    this.totalButtonsCount++;
                }
            }

            this.updateButtonErrors();
            this.updateButtonDisabledState();
        } catch (error) {
            console.error('Error handling menu selection:', error);
        }
    }

    updateButtonErrors(isCustom = false) {
        const buttonListToCheck = isCustom ? this.customButtonList : this.buttonList;
        const buttonTexts = buttonListToCheck.map(button => isCustom ? button.Cbtntext : button.btntext);

        const duplicates = {};
        buttonTexts.forEach(text => {
            duplicates[text] = (duplicates[text] || 0) + 1;
        });

        buttonListToCheck.forEach((button, idx) => {
            const isDuplicate = duplicates[isCustom ? button.Cbtntext : button.btntext] > 1;

            if (idx === 0) {
                button.hasError = false;
                button.errorMessage = '';
            } else {
                if (isDuplicate) {
                    button.hasError = true;
                    button.errorMessage = 'You have entered the same text for multiple buttons.';
                } else {
                    button.hasError = false;
                    button.errorMessage = '';
                }
            }
        });
    }

    createCustomButton(btnType, btnText) {
        try {
            const btnTextExists = this.customButtonList.some(button => button.Cbtntext === btnText);


            let newCustomButton = {
                id: this.customButtonList.length + 1,
                selectedCustomType: btnType,
                Cbtntext: btnText,
                buttonClass: 'button-label-preview',
                showFooterText: btnType === 'Marketing opt-out',
                iconName: this.getButtonIcon(btnType),
                hasError: false,
                errorMessage: ''
            };

            if (btnTextExists) {
                newCustomButton.hasError = true;
                newCustomButton.errorMessage = 'You have entered same text for multiple buttons.';
            } else {
                newCustomButton.hasError = false;
                newCustomButton.errorMessage = '';
            }

            this.customButtonList.push(newCustomButton);
            this.customButtonList = [...this.customButtonList]

            this.totalButtonsCount++;

            this.updateButtonErrors(true);
            this.updateButtonDisabledState();
        } catch (error) {
            console.error('Error creating custom button:', error);
        }
    }

    handleButtonClick(event) {
        try {
            const buttonId = event.currentTarget.dataset.id;
            const clickedButton = this.customButtonList.find(button => button.id == buttonId);

            if (clickedButton) {
                if (clickedButton.isDisabled) {
                    return;
                }
                let replyMessage = {
                    id: Date.now(),
                    body: `${clickedButton.Cbtntext}`,
                    timestamp: new Date().toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit' }),
                    replyToMessage: {
                        body: this.formatedTempBody,
                    }
                };

                this.chatMessages = [...this.chatMessages, replyMessage];

                clickedButton.isDisabled = true;
                clickedButton.buttonClass = 'button-label-preview disabled';

                this.customButtonList = [...this.customButtonList];
                this.isRefreshEnabled = false;
            }
        } catch (error) {
            console.error('Error while replying to template.', error);
        }
    }

    handleCustomText(event) {
        try {
            const index = event.currentTarget.dataset.index;
            const newValue = event.target.value;
            this.customButtonList[index].Cbtntext = newValue;

            const isDuplicate = this.customButtonList.some((button, idx) => button.Cbtntext === newValue && idx !== parseInt(index));

            if (index === 0) {
                this.customButtonList[index].hasError = false;
                this.customButtonList[index].errorMessage = '';
            } else {
                if (isDuplicate) {
                    this.customButtonList[index].hasError = true;
                    this.customButtonList[index].errorMessage = 'You have entered the same text for multiple buttons.';
                } else {
                    this.customButtonList[index].hasError = false;
                    this.customButtonList[index].errorMessage = '';
                }
            }

            this.Cbtntext = newValue;
            this.updateButtonErrors(true);
        } catch (error) {
            console.error('Error while handling the custom text.', error);
        }
    }

    handleRemoveCustom(event) {
        try {
            const index = event.currentTarget.dataset.index;
            const removedButton = this.customButtonList[index];

            if (removedButton && removedButton.showFooterText) {
                this.marketingOpt--;
            }
            this.customButtonList = this.customButtonList.filter((_, i) => i !== parseInt(index));
            if (this.customButtonList.length === 0) {
                this.isCustom = false;
            }

            this.totalButtonsCount--;

            if (removedButton?.Cbtntext) {
                const filteredMessages = this.chatMessages.filter(message => {
                    const isReplyToRemoved = message.replyToMessage?.body === this.formatedTempBody && message.body === removedButton.Cbtntext;
                    return !isReplyToRemoved;
                });
                this.chatMessages = [...filteredMessages];
            }

            this.customButtonList = [...this.customButtonList];
            this.updateButtonDisabledState();
        } catch (error) {
            console.error('Error while removing custom buttons.', error);

        }
    }

    updateButtonDisabledState() {
        this.isDropdownOpen = false;
        this.isButtonDisabled = this.totalButtonsCount >= 10;
        this.buttonList.forEach(button => {
            button.isDisabled = button.selectedActionType === 'COPY_CODE';
        });
    }

    refreshTempPreview() {
        try {
            this.customButtonList = this.customButtonList.map(button => {
                return {
                    ...button,
                    isDisabled: false,
                    buttonClass: 'button-label-preview'
                };
            });
            this.chatMessages = [];
            this.isRefreshEnabled = true;

        } catch (error) {
            console.error('Error while refreshing the template.', error);
        }
    }

    addvariable() {
        try {
            this.addVar = true;
            const maxId = this.variables.reduce((max, variable) => {
                return Math.max(max, parseInt(variable.id));
            }, 0);

            this.nextIndex = maxId + 1;
            const defaultField = this.fields[0].value;

            const newVariable = {
                id: this.nextIndex,
                object: this.selectedObject,
                field: defaultField,
                alternateText: '',
                index: `{{${this.nextIndex}}}`,
            };
            this.variables = [...this.variables, newVariable];

            this.tempBody = `${this.tempBody} {{${this.nextIndex}}} `;
            this.formatedTempBody = this.formatText(this.tempBody);
            this.updateTextarea();
            this.updatePreviewContent(this.formatedTempBody, 'body');
            this.nextIndex++;
        } catch (error) {
            console.error('Error in adding variables.', error);
        }
    }

    handleVarFieldChange(event) {
        try {
            const variableIndex = String(event.target.dataset.index);
            const fieldName = event.target.value;
            this.variables = this.variables.map((varItem) =>
                String(varItem.index) === variableIndex
                    ? {
                        ...varItem,
                        field: fieldName,
                    }
                    : varItem
            );
            this.formatedTempBody = this.formatText(this.tempBody);
            this.updatePreviewContent(this.formatedTempBody, 'body');
        } catch (error) {
            console.error('Something went wrong while updating variable field.', error);
        }
    }

    handleObjectChange(event) {
        try {
            const selectedObject = event.target.value;
            this.selectedObject = selectedObject;

            // Update all object dropdowns to show the same selected value
            this.template.querySelectorAll('[data-name="objectPicklist"]').forEach(dropdown => {
                dropdown.value = selectedObject;
            });

            getObjectFields({ objectName: selectedObject })
                .then((result) => {
                    this.fields = result.map((field) => ({ label: field, value: field }));

                    // Update variables for both header and body
                    this.variables = this.variables.map(varItem => ({
                        ...varItem,
                        object: selectedObject,
                        field: this.fields[0].value
                    }));

                    this.header_variables = this.header_variables.map(varItem => ({
                        ...varItem,
                        object: selectedObject,
                        field: this.fields[0].value
                    }));

                    this.formatedTempBody = this.formatText(this.tempBody);
                    this.updateTextarea();
                    this.updatePreviewContent(this.header, 'header');
                    this.updatePreviewContent(this.formatedTempBody, 'body');
                })
                .catch((error) => {
                    console.error('Error fetching fields: ', error);
                });
        } catch (error) {
            console.error('Something went wrong while updating variable object.', error);
        }
    }

    handleAlternateVarChange(event) {
        const variableIndex = String(event.target.dataset.index);
        const alternateText = event.target.value;
        this.variables = this.variables.map(varItem =>
            String(varItem.index) === variableIndex
                ? { ...varItem, alternateText }
                : varItem
        );
    }

    updateTextarea() {
        const textarea = this.template.querySelector('textarea');
        if (textarea) {
            textarea.value = this.tempBody;
        }
        textarea.focus();
    }

    handleVarRemove(event) {
        try {
            const index = event.currentTarget.dataset.index;
            const varIndexToRemove = parseInt(index, 10) + 1;
            const variableToRemove = `{{${varIndexToRemove}}}`;
            let updatedTempBody = this.tempBody.replace(variableToRemove, '');
            this.variables = this.variables.filter((_, i) => i !== parseInt(index));
            this.variables = this.variables.map((varItem, idx) => {
                const newIndex = idx + 1;
                return {
                    ...varItem,
                    id: newIndex,
                    index: `{{${newIndex}}}`
                };
            });

            let placeholders = updatedTempBody.match(/\{\{\d+\}\}/g) || [];
            placeholders.forEach((placeholder, idx) => {
                const newIndex = `{{${idx + 1}}}`;
                updatedTempBody = updatedTempBody.replace(placeholder, newIndex);
            });
            this.tempBody = updatedTempBody.trim();
            this.originalTempBody = this.tempBody;
            this.formatedTempBody = this.originalTempBody;
            this.updatePreviewContent(this.tempBody, 'body');
            this.nextIndex = this.variables.length + 1;
            if (this.variables.length === 0) {
                this.addVar = false;
                this.nextIndex = 1;
            }
            this.updateTextarea();
        } catch (error) {
            console.error('Something wrong while removing the variable.', error);
        }
    }

    // Header variable add-remove functionality start here
    addheadervariable() {
        try {
            this.addHeaderVar = true;
            const defaultField = this.fields[0].value;
            const newVariable = {
                id: this.headIndex,
                object: this.selectedObject,
                field: defaultField,
                alternateText: '',
                index: `{{${this.headIndex}}}`,
            };

            this.header_variables = [...this.header_variables, newVariable];
            this.originalHeader = (this.originalHeader || this.header || '') + ` {{${this.headIndex}}}`;
            this.header = this.originalHeader;
            this.updatePreviewContent(this.header, 'header');
            this.headIndex++;
            this.buttonDisabled = true;
        } catch (error) {
            console.error('Error in adding header variables.', error);
        }
    }

    handleFieldChange(event) {
        try {
            // const variableId = event.target.dataset.id;
            const variableId = String(event.target.dataset.id);
            const fieldName = event.target.value;
            this.header_variables = this.header_variables.map(varItem =>
                String(varItem.id) === variableId
                    ? {
                        ...varItem,
                        field: fieldName,
                    }
                    : varItem
            );
            this.updatePreviewContent(this.header, 'header');
        } catch (error) {
            console.error('Something wrong while header variable input.', error);
        }
    }

    handleAlternateTextChange(event) {
        const variableId = String(event.target.dataset.id);
        const alternateText = event.target.value;
        this.header_variables = this.header_variables.map(varItem =>
            String(varItem.id) === variableId
                ? { ...varItem, alternateText }
                : varItem
        );
    }

    updatePreviewContent(inputContent, type) {
        try {
            let updatedContent = inputContent;

            const variables = type === 'header' ? this.header_variables : this.variables;
            variables.forEach(varItem => {
                const variablePlaceholder = varItem.index;
                const replacementValue = `{{${varItem.object}.${varItem.field}}}`;

                let index = updatedContent.indexOf(variablePlaceholder);
                while (index !== -1) {
                    updatedContent = updatedContent.slice(0, index) + replacementValue + updatedContent.slice(index + variablePlaceholder.length);
                    index = updatedContent.indexOf(variablePlaceholder, index + replacementValue.length);
                }
            });

            if (type === 'header') {
                this.previewHeader = updatedContent;
            } else if (type === 'body') {
                this.previewBody = updatedContent;
            }
        } catch (error) {
            console.error('Something wrong while updating preview.', error);
        }
    }

    handleHeaderVarRemove(event) {
        try {
            const index = event.currentTarget.dataset.index;
            const varIndexToRemove = parseInt(index, 10) + 1;
            const variableToRemove = `{{${varIndexToRemove}}}`;
            let updatedHeader = this.header.replace(variableToRemove, '');
            this.header_variables = this.header_variables.filter((_, i) => i !== parseInt(index));
            this.header_variables = this.header_variables.map((varItem, idx) => {
                const newIndex = idx + 1;
                return {
                    ...varItem,
                    id: newIndex,
                    index: `{{${newIndex}}}`,
                    placeholder: `Enter content for {{${newIndex}}}`
                };
            });
            let placeholders = updatedHeader.match(/\{\{\d+\}\}/g) || [];
            placeholders.forEach((placeholder, idx) => {
                const newIndex = `{{${idx + 1}}}`;
                updatedHeader = updatedHeader.replace(placeholder, newIndex);
            });
            this.header = updatedHeader.trim();
            this.originalHeader = this.header;
            this.updatePreviewContent(this.originalHeader, 'header');
            this.headIndex = this.header_variables.length + 1;
            if (this.header_variables.length === 0) {
                this.addHeaderVar = false;
                this.buttonDisabled = false;
                this.headIndex = 1;
            }
        } catch (error) {
            console.error('Something wrong while removing header variable.', error);
        }
    }

    generateEmojiCategories() {
        fetch(emojiData)
            .then((response) => response.json())
            .then((data) => {
                let groupedEmojis = Object.values(
                    data.reduce((acc, item) => {
                        let category = item.category;
                        if (!acc[category]) {
                            acc[category] = { category, emojis: [] };
                        }
                        acc[category].emojis.push(item);
                        return acc;
                    }, {})
                );

                this.emojiCategories = groupedEmojis;
            })
            .catch((e) => console.error('There was an error fetching the emoji.', e));
    }
    fetchCountries() {
        fetch(CountryJson)
            .then((response) => response.json())
            .then((data) => {
                this.countryType = data.map(country => {
                    return { label: `${country.name} (${country.callingCode})`, value: country.callingCode };
                });
            })
            .catch((e) => console.error('Error fetching country data:', e));

    }

    fetchLanguages() {

        fetch(LanguageJson)
            .then((response) => response.json())
            .then((data) => {
                this.languageOptions = data.map(lang => {
                    return { label: `${lang.language}`, value: lang.code, isSelected: lang.code === this.selectedLanguage };
                });
                if (!this.languageOptions.some(option => option.isSelected)) {
                    this.selectedLanguage = this.languageOptions[0]?.value || '';
                    if (this.languageOptions[0]) {
                        this.languageOptions[0].isSelected = true;
                    }
                }
            })
            .catch((e) => console.error('Error fetching language data:', e));

    }

    handleEmoji(event) {
        event.stopPropagation();
        this.showEmojis = !this.showEmojis;

        if (this.showEmojis) {
            this.addOutsideClickListener();
        } else {
            this.removeOutsideClickListener();
        }
    }

    handleEmojiSelection(event) {
        try {
            event.stopPropagation();
            const emojiChar = event.target.textContent;
            const textarea = this.template.querySelector('textarea');
            const currentText = textarea.value || '';
            const cursorPos = textarea.selectionStart;

            const newText = currentText.slice(0, cursorPos) + emojiChar + currentText.slice(cursorPos);
            this.tempBody = newText;
            this.formatedTempBody = this.tempBody;
            this.previewBody = this.formatedTempBody;
            textarea.value = newText;

            setTimeout(() => {
                const newCursorPos = cursorPos + emojiChar.length;
                textarea.focus();
                textarea.setSelectionRange(newCursorPos, newCursorPos);
            }, 0);
        } catch (error) {
            console.error('Error in emoji selection.', error);

        }
    }

    handleFormat(event) {
        try {
            const button = event.target.closest('button');
            const formatType = button.dataset.format;

            const textarea = this.template.querySelector('textarea');
            const cursorPos = textarea.selectionStart;
            const currentText = textarea.value;
            let marker;
            let markerLength;
            switch (formatType) {
                case 'bold':
                    marker = '**';
                    markerLength = 1;
                    break;
                case 'italic':
                    marker = '__';
                    markerLength = 1;
                    break;
                case 'strikethrough':
                    marker = '~~';
                    markerLength = 1;
                    break;
                case 'codeIcon':
                    marker = '``````';
                    markerLength = 3;
                    break;
                default:
                    return;
            }
            const newText = this.applyFormattingAfter(currentText, cursorPos, marker);
            const newCursorPos = cursorPos + markerLength;

            this.tempBody = newText;
            this.updateCursor(newCursorPos);
        } catch (error) {
            console.error('Something wrong while handling rich text.', error);
        }
    }

    applyFormattingAfter(text, cursorPos, marker) {
        return text.slice(0, cursorPos) + marker + text.slice(cursorPos);
    }

    formatText(inputText) {
        try {
            inputText = inputText.replace(/(\n\s*){3,}/g, '\n\n');
            let formattedText = inputText.replaceAll('\n', '<br/>');
            formattedText = formattedText.replace(/\*(.*?)\*/g, '<b>$1</b>');
            formattedText = formattedText.replace(/_(.*?)_/g, '<i>$1</i>');
            formattedText = formattedText.replace(/~(.*?)~/g, '<s>$1</s>');
            formattedText = formattedText.replace(/```(.*?)```/g, '<code>$1</code>');

            return formattedText;
        } catch (error) {
            console.error('Error while returning formatted text.', error);
        }
    }

    updateCursor(cursorPos) {
        const textarea = this.template.querySelector('textarea');
        textarea.value = this.tempBody;
        textarea.focus();
        textarea.selectionStart = textarea.selectionEnd = cursorPos;
    }

    validateTemplate() {
        try {
            if (!this.templateName || this.templateName.trim() === '') {
                this.showToastError('Template Name is required');
                return false;
            }

            if (!this.selectedLanguage) {
                this.showToastError('Please select a language');
                return false;
            }

            if (!this.tempBody || this.tempBody.trim() === '') {
                this.showToastError('Template Body is required');
                return false;
            }

            const buttonData = [...this.buttonList, ...this.customButtonList];
            for (let button of buttonData) {
                if (button.isVisitSite) {
                    if (!button.selectedUrlType || !button.webURL || !this.validateUrl(button.webURL)) {
                        this.showToastError('Please provide a valid URL that should be properly formatted (e.g., https://example.com)');
                        return false;
                    }
                } else if (button.isCallPhone) {
                    if (!button.selectedCountryType || !button.phonenum || !this.validatePhoneNumber(button.phonenum)) {
                        this.showToastError('Please provide a valid country and phone number for the "Call Phone Number" button');
                        return false;
                    }
                } else if (button.isOfferCode) {
                    const alphanumericPattern = /^[a-zA-Z0-9]+$/;
                    if (!alphanumericPattern.test(button.offercode.trim())) {
                        this.showToastError('Offer code must only contain alphanumeric characters (letters and numbers)');
                        return false;
                    }
                }

                if (button.isCustom) {
                    if (!button.Cbtntext || button.Cbtntext.trim() === '') {
                        this.showToastError('Button text is required for the custom button');
                        return false;
                    }
                }
            }
            return true;
        } catch (error) {
            console.error('Something went wrong while validating template.', error);
            return false;
        }

    }

    validateUrl(value) {
        const urlPattern = new RegExp(
            '^(https?:\\/\\/)?(www\\.)?([a-zA-Z0-9-]+\\.)+[a-zA-Z]{2,6}($|\\/.*)$'
        );
        const isValid = urlPattern.test(value);
        return isValid;
    }

    validatePhoneNumber(value) {
        const phonePattern = /^[0-9]{10,}$/;
        return phonePattern.test(value);
    }

    validateButtonText(index, newValue) {
        const isDuplicate = this.buttonList.some((button, idx) => button.btntext === newValue && idx !== parseInt(index));

        if (index === 0) {
            this.buttonList[index].hasError = false;
            this.buttonList[index].errorMessage = '';
        } else {
            this.buttonList[index].hasError = isDuplicate;
            this.buttonList[index].errorMessage = isDuplicate ? 'You have entered the same text for multiple buttons.' : '';
        }

        this.btntext = newValue;
        this.updateButtonErrors();
    }

    handleConfirm() {
        this.showReviewTemplate = true;
    }
    handleCloseTemplate() {
        this.showReviewTemplate = false;
        this.iseditTemplatevisible = true;
        this.isLoading = false;
    }

    handlePackagename(event) {
        const index = parseInt(event.target.dataset.index, 10);
        const value = event.target.value;

        this.packages[index].errorPackageMessage = '';

        if (!this.isPackageValid(value)) {
            this.packages[index].errorPackageMessage = 'Package name must have at least two segments separated by dots, and each segment must start with a letter and contain only alphanumeric characters or underscores.';
        }

        this.packages[index].packagename = value;
        this.packages[index].curPackageName = value.length;

        const isDuplicate = this.packages.some((pkg, i) => i < index && pkg.packagename === value);

        if (isDuplicate) {
            this.showToastError('Package name must be unique');

        }
        this.updateErrorMessages();


    }


    handleSignaturehash(event) {
        const index = parseInt(event.target.dataset.index, 10);
        const value = event.target.value;

        this.packages[index].errorSignature = '';

        if (!this.isSignatureValid(value)) {
            this.packages[index].errorSignature = 'Signature hash must contain only alphanumeric characters, /, +, = and must be exactly 11 characters long.';
        }

        this.packages[index].signature = value;
        this.packages[index].curHashCode = value.length;

        const isDuplicate = this.packages.some((pkg, i) => i < index && pkg.signature === value);

        if (isDuplicate) {
            this.showToastError('Signature hash must be unique');

        }
        this.updateErrorMessages();

    }
    updateErrorMessages() {
        this.uniqueErrorMessages.packageErrors = [];
        this.uniqueErrorMessages.signatureErrors = [];
        this.appError = false;

        this.packages.forEach(pkg => {
            if (pkg.errorPackageMessage && !this.uniqueErrorMessages.packageErrors.includes(pkg.errorPackageMessage)) {
                this.uniqueErrorMessages.packageErrors.push(pkg.errorPackageMessage);
                this.appError = true;
            }
            if (pkg.errorSignature && !this.uniqueErrorMessages.signatureErrors.includes(pkg.errorSignature)) {
                this.uniqueErrorMessages.signatureErrors.push(pkg.errorSignature);
                this.appError = true;
            }
        });
    }

    addPackageApp() {
        if (this.packages.length < this.maxPackages) {
            const newPackage = {
                id: this.packages.length + 1,
                packagename: '',
                signature: '',
                curPackageName: 0,
                curHashCode: 0
            };
            this.packages = [...this.packages, newPackage];
            // this.addAppBtn=true;
        } else {
            console.warn('Maximum number of packages reached.');
        }
    }

    removePackageApp(event) {
        const index = parseInt(event.target.dataset.index, 10);

        if (index >= 0 && index < this.packages.length) {
            this.packages = this.packages.filter((pkg, i) => i !== index);

            this.packages = this.packages.map((pkg, i) => ({
                ...pkg,
                id: i + 1
            }));
        } else {
            console.warn('Invalid package index for removal.');
        }
    }

    handleSubmit() {
        try {
            if ((this.activeTab == 'Marketing' || this.activeTab == 'Utiltiy') && !this.isCheckboxChecked && this.visitWebsiteCount > 0) {
                this.showToastError('Please select check-box to report website clicks.');
                return;
            }
            this.isLoading = true;
            this.showReviewTemplate = false;
            if (!this.validateTemplate()) {
                this.isLoading = false;

                return;
            }
            const formData = this.packages.map(pkg => ({
                packagename: pkg.packagename,
                signaturename: pkg.signature
            }));

            const buttonData = [];

            if (this.buttonList && this.buttonList.length > 0) {
                buttonData.push(...this.buttonList);
            }

            if (this.customButtonList && this.customButtonList.length > 0) {

                buttonData.push(...this.customButtonList);
            }
            let fileUrl = null;
            if (this.filePreview) {
                fileUrl = this.filePreview; // Use ContentVersion if available
            }


            // Change
            if (this.activeTab == 'Authentication') {
                this.tempBody = ' is your verification code';
            }

            const templateMiscellaneousData = {
                contentVersionId: this.contentVersionId,
                isImageFile: this.isImageFile,
                isImgSelected: this.isImgSelected,
                isDocSelected: this.isDocSelected,
                isVidSelected: this.isVidSelected,
                isHeaderText: this.IsHeaderText,
                addHeaderVar: this.addHeaderVar,
                addMedia: this.addMedia,
                isImageFileUploader: this.isImageFileUploader,
                isVideoFileUploader: this.isVideoFileUploader,
                isDocFileUploader: this.isDocFileUploader,
                isVideoFile: this.isVideoFile,
                isDocFile: this.isDocFile,
                isSecurityRecommedation: this.prevContent,
                isCodeExpiration: this.isExpiration,
                expireTime: this.expirationTime,
                authRadioButton: this.value,
                autofillCheck: this.isautofillChecked,
                isVisitSite: this.isVisitSite,
                isCheckboxChecked: this.isCheckboxChecked,
                isFlowMarketing: this.isFlowMarketing,
                isFlowUtility: this.isFlowUtility,
                isFlowSelected: this.isFlowSelected,
                selectedFlow: this.selectedFlow,
                isFeatureEnabled: this.isFeatureEnabled,
                awsFileName: this.awsFileName
            }



            const template = {
                templateName: this.templateName ? this.templateName : null,
                templateCategory: this.activeTab ? this.activeTab : null,
                templateType: this.selectedOption ? this.selectedOption : null,
                tempHeaderHandle: this.headerHandle ? this.headerHandle : null,
                tempHeaderFormat: this.selectedContentType ? this.selectedContentType : null,
                tempImgUrl: this.filePreview ? this.filePreview : null,
                tempImgId: this.contentVersionId ? this.contentVersionId : null,
                tempImgName: this.fileName ? this.fileName : null,
                tempLanguage: this.selectedLanguage ? this.selectedLanguage : null,
                tempHeaderText: this.header ? this.header : '',
                varAlternateTexts: (this.templateCategory === 'Authentication')
                    ? [null]  // Placeholder {{1}} is automatically handled, so no alternate text required
                    : this.variables.map(varItem => varItem.alternateText || null),
                tempHeaderExample: (this.tempHeaderExample && this.tempHeaderExample.length > 0) ? this.tempHeaderExample : null,
                headAlternateTexts: this.header_variables.map(varItem => varItem.alternateText || null),
                templateBody: this.tempBody ? this.tempBody : '',
                templateBodyText: (this.templateBodyText && this.templateBodyText.length > 0) ? this.templateBodyText : null,
                tempFooterText: this.footer ? this.footer : null,
                typeOfButton: buttonData.length > 0 ? JSON.stringify(buttonData) : null,
                autofillCheck: this.isautofillChecked ? this.isautofillChecked : null,
                expireTime: this.expirationTime ? this.expirationTime : 300,
                packagename: formData.length > 0 ? formData.map(pkg => pkg.packagename) : null,
                signaturename: formData.length > 0 ? formData.map(pkg => pkg.signaturename) : null,
                selectedFlow: this.selectedFlow ? JSON.stringify(this.selectedFlow) : null,
                templateMiscellaneousData: templateMiscellaneousData ? JSON.stringify(templateMiscellaneousData) : null,
                isSecurityRecommedation: this.prevContent ? this.prevContent : null,
                isCodeExpiration: this.isExpiration == null ? false : true

            };


            const serializedWrapper = JSON.stringify(template);
            const payload = JSON.stringify(buildPayload(template));
            if (this.metaTemplateId) {
                editWhatsappTemplate({ serializedWrapper: serializedWrapper, payloadWrapper: payload, templateId: this.metaTemplateId })
                    .then(result => {
                        if (result && result.success) {
                            this.showToastSuccess('Template successfully edited.');
                            // this.isAllTemplate=true;
                            // this.iseditTemplatevisible=false;
                            // this.isLoading=false;
                            // const templateId = result.templateId;  
                            // this.templateId = templateId;
                            // this.fetchUpdatedTemplates();
                            this.navigateToAllTemplatePage();
                        } else {
                            const errorResponse = JSON.parse(result.errorMessage);
                            const errorMsg = errorResponse.error.error_user_msg || 'Due to unknown error';

                            this.showToastError('Template updation failed, reason - ' + errorMsg);
                            this.isLoading = false;
                        }
                    })
                    .catch(error => {
                        console.error('Error creating template', error);
                        const errorTitle = 'Template creation failed: ';
                        let errorMsg;
                        if (error.body && error.body.message) {
                            if (error.body.message.includes('Read timed out')) {
                                errorMsg = 'The request timed out. Please try again.';
                            } else {
                                errorMsg = error.body.message.error_user_title || 'An unknown error occurred';
                            }
                        } else {
                            errorMsg = 'An unknown error occurred';
                        }

                        this.showToastError(errorTitle, errorMsg);
                        this.isLoading = false;
                    });

            } else {
                createWhatsappTemplate({ serializedWrapper: serializedWrapper, payloadWrapper: payload, templateName: this.templateName })
                    .then(result => {

                        if (result && result.success) {
                            this.showToastSuccess('Template successfully created');

                            this.navigateToAllTemplatePage();
                        } else if (result && result.success == false && result.status == 'warning') {
                            this.showToastWarning('Template creation taking too much time, please wait for few minutes and refresh the page to see the template.');
                            this.navigateToAllTemplatePage();
                            this.isLoading = false;
                        } else {
                            const errorResponse = JSON.parse(result.errorMessage);
                            const errorMsg = errorResponse.error.error_user_msg || errorResponse.error.message || 'Due to unknown error';

                            this.showToastError('Template creation failed, reason - ' + errorMsg);
                            this.isLoading = false;
                        }
                    })
                    .catch(error => {
                        console.error('Error creating template', error);
                        const errorTitle = 'Template creation failed: ';
                        let errorMsg;
                        if (error.body && error.body.message) {
                            if (error.body.message.includes('Read timed out')) {
                                errorMsg = 'The request timed out. Please try again.';
                            } else {
                                errorMsg = error.body.message.error_user_title || 'An unknown error occurred';
                            }
                        } else {
                            errorMsg = 'An unknown error occurred';
                        }

                        this.showToastError(errorTitle, errorMsg);
                        this.isLoading = false;
                    });

            }


        } catch (error) {
            console.error('Unexpected error occurred', error);
            this.showToastError('An unexpected error occurred while submitting the template.');
            this.isLoading = false;
        }
    }

    fetchUpdatedTemplates(dispatchEvent = true) {
        getWhatsAppTemplates()
            .then(data => {
                this.allTemplates = data;
                if (dispatchEvent) {
                    const event = new CustomEvent('templateupdate', { detail: data });
                    this.dispatchEvent(event);
                }
            })
            .catch(error => {
                console.error('Error fetching templates:', error);
                this.showToastError('Failed to fetch updated templates.');
            });
    }

    showToastError(message) {
        const toastEvent = new ShowToastEvent({
            title: 'Error',
            message,
            variant: 'error'
        });
        this.dispatchEvent(toastEvent);
    }

    showToastWarning(message) {
        const toastEvent = new ShowToastEvent({
            title: 'Information',
            message,
            variant: 'warning'
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

    closePreview() {
        this.navigateToAllTemplatePage();
    }

    getButtonPath(iconName) {
        return `${buttonIconsZip}/button-sectionIcons/${iconName}.png`;
    }

    toggleDropdown(event) {
        event.stopPropagation();
        this.isDropdownOpen = !this.isDropdownOpen;
        if (this.isDropdownOpen) {
            this.addOutsideClickListener();
        } else {
            this.removeOutsideClickListener();
        }
        this.dropdownClass = this.isDropdownOpen ? 'dropdown-visible' : 'dropdown-hidden';
    }

    navigateToAllTemplatePage() {
        let cmpDef = {
            componentDef: 'MVEX:wbAllTemplatePage',

        };

        let encodedDef = btoa(JSON.stringify(cmpDef));
        this[NavigationMixin.Navigate]({
            type: "standard__webPage",
            attributes: {
                url: "/one/one.app#" + encodedDef
            }
        });
    }
}