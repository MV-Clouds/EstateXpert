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
import richTextZip from '@salesforce/resourceUrl/richTextZip';
import buttonIconsZip from '@salesforce/resourceUrl/buttonIconsZip';
import emojiData from '@salesforce/resourceUrl/emojis_data';
import COUNTRY_PHONE_LENGTHS from '@salesforce/resourceUrl/CountryPhoneLengths';
import wbCreateTempStyle from '@salesforce/resourceUrl/wbCreateTempStyle';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
import LanguageJson from '@salesforce/resourceUrl/LanguageJson';
import createWhatsappTemplate from '@salesforce/apex/WBTemplateController.createWhatsappTemplate';
import editWhatsappTemplate from '@salesforce/apex/WBTemplateController.editWhatsappTemplate';
import startUploadSession from '@salesforce/apex/WBTemplateController.startUploadSession';
import uploadFileChunk from '@salesforce/apex/WBTemplateController.uploadFileChunk';
import getObjectFields from '@salesforce/apex/WBTemplateController.getObjectFields';
import getObjectFieldsWithRelationships from '@salesforce/apex/WBTemplateController.getObjectFieldsWithRelationships';
import getWhatsAppTemplates from '@salesforce/apex/WBTemplateController.getWhatsAppTemplates';
import checkTemplateExistance from '@salesforce/apex/WBTemplateController.checkTemplateExistance';
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
import getPreviewURLofWhatsAppFlow from '@salesforce/apex/WBTemplateController.getPreviewURLofWhatsAppFlow';
import AWS_SDK from "@salesforce/resourceUrl/AWSSDK";
import buildPayload from './wbCreateTemplateWrapper'
import getAllFlowScreenIds from '@salesforce/apex/WBTemplateController.getAllFlowScreenIds';
import getMetaHeaderHandler from '@salesforce/apex/WBTemplateController.getMetaHeaderHandler';


// ============================
// MODULE-LEVEL CONSTANTS
// ============================
const EXPIRE_TIME_OPTIONS = [
    { label: '1 minute', value: '1 minute' },
    { label: '2 minutes', value: '2 minutes' },
    { label: '3 minutes', value: '3 minutes' },
    { label: '5 minutes', value: '5 minutes' },
    { label: '10 minutes', value: '10 minutes' }
];

const CONTENT_OPTIONS = [
    { label: 'Add security recommendation', value: 'Add security recommendation' },
    { label: 'Add expiry time for the code', value: 'Add expiry time for the code' }
];

const VARIABLE_TYPE_OPTIONS = [
    { label: 'Name', value: 'Name' },
    { label: 'Number', value: 'Number' }
];

const TYPE_OPTIONS = [
    { label: 'None', value: 'None' },
    { label: 'Text', value: 'Text' },
    { label: 'Image', value: 'Image' },
    { label: 'Video', value: 'Video' },
    { label: 'Document', value: 'Document' }
];

const TYPE_ACTION_OPTIONS = [
    { label: 'Call Phone Number', value: 'PHONE_NUMBER' },
    { label: 'Visit Website', value: 'URL' },
    { label: 'Copy Offer Code', value: 'COPY_CODE' }
];

const CUSTOM_OPTIONS = [
    { label: 'Custom', value: 'QUICK_REPLY' },
    { label: 'Marketing opt-out', value: 'Marketing opt-out' }
];

const URL_TYPE_OPTIONS = [
    { label: 'Static', value: 'Static' }
];

const TIME_TO_SECONDS_MAP = {
    '1 minute': 60,
    '2 minutes': 120,
    '3 minutes': 180,
    '5 minutes': 300,
    '10 minutes': 600
};

const BUTTON_ICON_MAP = {
    'QUICK_REPLY': 'utility:reply',
    'Marketing opt-out': 'utility:reply',
    'PHONE_NUMBER': 'utility:call',
    'URL': 'utility:new_window',
    'COPY_CODE': 'utility:copy',
    'FLOW': 'utility:file'
};

const TOAST_TITLES = {
    error: 'Error',
    warning: 'Information',
    success: 'Success',
    info: 'Information'
};

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
        chunkSize: 3145728,
        maxHierarchyLevel: 5
    };

    // ============================
    // INSTANCE PROPERTIES
    // ============================
    _edittemplateid;
    _boundHandleOutsideClick; // Stored bound reference for event listener cleanup
    _cachedToolbarButtons; // Cached toolbar buttons with classes
    _cachedQuickReplyOptions; // Cached quick reply options
    _cachedCallToActionOptions; // Cached call to action options
    _lastActiveTab; // Track activeTab for cache invalidation
    
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
        { title: 'Copy Offer Code', value: 'COPY_CODE', iconName: 'copy', description: 'Maximum 1 button can be added' }
    ];

    toolbarButtons = [
        { title: 'bold', iconName: 'bold' },
        { title: 'italic', iconName: 'italic' },
        { title: 'strikethrough', iconName: 'stike' },
        { title: 'codeIcon', iconName: 'code' }
    ];

    // Primitives - auto-tracked by LWC (no @track needed)
    contentVersionId;
    isNewTemplate = true;
    isEditTemplate = false;
    totalButtonsCount = 0;
    visitWebsiteCount = 0;
    callPhoneNumber = 0;
    copyOfferCode = 0;
    flowCount = 0;
    marketingOpt = 0;
    iseditTemplatevisible = false;
    showReviewTemplate = false;
    IsHeaderText = false;
    addHeaderVar = false;
    addMedia = false;
    isImageFile = false;
    isImageFileUploader = false;
    isImgSelected = false;
    isDocSelected = false;
    isVidSelected = false;
    isVideoFile = false;
    isDocFile = false;
    isVideoFileUploader = false;
    isDocFileUploader = false;
    isLocation = false;
    isCallPhone = false;
    isOfferCode = false;
    isVisitSite = false;
    isFlow = false;
    isCustom = false;
    createButton = false;
    isButtonDisabled = false;
    isStopMarketing = false;
    buttonDisabled = false;
    isRefreshEnabled = true;
    isLoading = false;
    templateExists = false;
    showEmojis = false;
    isCheckboxChecked = false;
    showDefaultBtn = true;
    templateName = '';
    header = '';
    footer = '';
    tempBody = 'Hello';
    formatedTempBody = this.tempBody;
    previewBody = 'Hello';
    previewHeader = '';
    btntext = '';
    webURL = '';
    Cbtntext = '';
    selectedUrlType = 'Static';
    nextIndex = 1;
    headIndex = 1;
    selectedOption = 'Custom';
    activeSection = 'section1';
    selectedContentType = 'None';
    selectedLanguage = 'en_US';
    selectedActionType = '';
    selectedCountryType = '+971';
    selectedCountryTypeLabel = 'United Arab Emirates (+971)';
    phonePattern = '^[0-9]+$';
    phoneErrorMessage = 'Enter a valid phone number';
    originalTempBody = '';
    originalHeader = '';
    menuButtonSelected;
    headerHandle = '';
    isfilename = false;
    NoFileSelected = true;
    filePreview = '';
    selectedObject = '';
    richTextZip = richTextZip;
    buttonIconsZip = buttonIconsZip;
    isDropdownOpen = false;
    dropdownClass = 'dropdown-hidden';
    metaTemplateId = '';
    headerError = '';
    isRendered = false;
    showLicenseError = false;
    utilityOrderStatusSelected = false;
    defaultPreview = true;
    authenticationPasscodeSelected = false;
    UtilityCustomSelected = false;
    isDefault = true;
    ifAuthentication = false;
    isAppSetup = true;
    showAutofill = true;
    showAuthBtn = false;
    authZeroTab = true;
    isautofillChecked = false;
    showOneTap = false;
    autofilLabel = 'Autofill';
    autoCopyCode = 'Copy Code';
    value = 'zero_tap';
    expirationTime = 300;
    isExpiration = false;
    prevContent = true;
    maxPackages = 5;
    showMsgValidity = false;
    authPrevBody = `{{1}}`;
    isAddCallPhoneNumber = false;
    isAddVisitWebsiteCount = false;
    isAddCopyOfferCode = false;
    isAddFlow = false;
    tempLocationIcon = tempLocationIcon;
    tempVideoIcon = tempVideoIcon;
    imageUploadPreview = imageUploadPreview;
    docUploadPreviewImg = docUploadPreview;
    NoPreviewAvailableImg = NoPreviewAvailable;
    isFeatureEnabled = false;
    selectedTime = '5 minutes';
    isFlowMarketing = false;
    isFlowUtility = false;
    isFlowSelected = false;
    isModalOpen = false;
    selectedFlowId = '';
    selectedFlow;
    iframeSrc;
    isModalPreview = false;
    isAWSEnabled = false;
    confData;
    s3;
    isAwsSdkInitialized = true;
    awsFileName;
    flowScreenIds;
    originalContentVersionId = null;
    ifUtilty = false;
    appError = false;
    orderStatusBody = '';
    catalogName = '';
    locationNameMerge = '';
    locationAddressMerge = '';
    selectedVariableType = 'Number'; // Default variable type (Name or Number)

    // Arrays and Objects - need @track for deep reactivity
    @track variables = [];
    @track header_variables = [];
    @track countryPhoneMap = {};
    @track countryLabelToCodeMap = {};
    @track countryCodeToLabelMap = {};
    @track buttonList = [];
    @track customButtonList = [];
    @track languageOptions = [];
    @track countryType = [];
    @track availableObjects = [];
    @track fields = [];
    @track chatMessages = [];
    @track emojiCategories = [];
    @track allTemplates = [];
    @track headerVarAlternateTextErrors = {};
    @track bodyVarAlternateTextErrors = {};
    @track bodyVariablePlacementError = '';
    @track bodyVariableFormatError = '';
    @track headerVariableFormatError = '';
    @track selectContent = ['Add security recommendation'];
    @track packages = [
        { id: 1, packagename: '', signature: '', curPackageName: 0, curHashCode: 0 }
    ];
    @track selectedFilesToUpload = [];
    @track objectFieldMap = {};
    @track fieldOptionsWithRelationships = [];
    @track allObjectFieldsMap = {};
    @track uniqueErrorMessages = { packageErrors: [], signatureErrors: [] };

    @api activeTab;
    @api selectedTab;
    @api selectedOption;
    @track addVar = false;
    @api isTemplateClone = false;

    // ============================
    // OPTIONS PROVIDERS (Dropdown values)
    // ============================

    get expireTime() {
        return EXPIRE_TIME_OPTIONS;
    }

    get contentOption() {
        return CONTENT_OPTIONS;
    }

    get typeOptions() {
        return TYPE_OPTIONS;
    }

    get typeactionOption() {
        return TYPE_ACTION_OPTIONS;
    }

    get customOption() {
        return CUSTOM_OPTIONS;
    }

    get urlType() {
        return URL_TYPE_OPTIONS;
    }

    get variableTypeOptions() {
        return VARIABLE_TYPE_OPTIONS;
    }

    // Getter to check if Number type is selected (for showing object selector)
    get isNumberTypeSelected() {
        return this.selectedVariableType === 'Number';
    }

    // Getter to check if Name type is selected
    get isNameTypeSelected() {
        return this.selectedVariableType === 'Name';
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

    get maxtelephonelength(){
        return this.countryPhoneMap[this.selectedCountryType] || 15;
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
        return this.header_variables.map(varItem => `{{${varItem.field}}}`);
    }

    get templateBodyText() {
        // Map body variables into string format
        // For Name type variables, use the nameValue
        return this.variables.map(varItem => {
            if (varItem.variableType === 'Name' && varItem.nameValue) {
                return varItem.nameValue;
            }
            return `{{${varItem.field}}}`;
        });
    }

    // ============================
    // BUTTONS, TOOLBARS, OPTIONS
    // ============================

    get refreshButtonClass() {
        // Class for refresh button based on enabled state
        return this.isRefreshEnabled ? 'refresh-icon refresh-disabled' : 'refresh-icon';
    }

    get computedVariables() {
        return this.variables.map(varItem => {
            const computed = this.computeVariableFields(varItem, false);
            const hasAlternateTextError = !!this.bodyVarAlternateTextErrors[varItem.id];
            const isNameType = varItem.variableType === 'Name';
            const isNumberType = varItem.variableType === 'Number';
            
            // For Name type, display the content from nameValue; for Number type, show {{1}}, {{2}} etc.
            const displayIndex = isNameType 
                ? (varItem.nameValue ? `{{${varItem.nameValue}}}` : `{{}}`)
                : varItem.index;

            // Dynamic placeholder based on variable type
            const placeholderText = isNameType ? 'Enter example' : 'Enter alternative text';

            return {
                ...varItem,
                ...computed,
                index: displayIndex, // Override index for display
                placeholderText, // Dynamic placeholder text
                hasAlternateTextError,
                isNameType, // Flag to show name value input
                isNumberType, // Flag to show field picker and alternate text
                showNameValueInput: isNameType, // Show name value input for Name type
                showAlternateTextInput: isNumberType // Show alternate text for Number type
            };
        });
    }


    get computedHeaderVariables() {
        return this.header_variables.map(varItem => {
            const objectOptions = this.availableObjectsWithSelection
                ? this.availableObjectsWithSelection.map(object => ({
                    ...object,
                    isSelected: object.value === varItem.object
                }))
                : [];

            const computed = this.computeVariableFields(varItem, true);
            const hasAlternateTextError = !!this.headerVarAlternateTextErrors[varItem.id];
            const isNameType = varItem.variableType === 'Name';
            const isNumberType = varItem.variableType === 'Number' || !varItem.variableType;
            
            // For Name type, display the content from nameValue
            const displayIndex = isNameType 
                ? (varItem.nameValue ? `{{${varItem.nameValue}}}` : `{{}}`)
                : varItem.index;
            
            // Dynamic placeholder based on variable type
            const placeholderText = isNameType ? 'Enter example' : 'Enter alternative text';
            
            return {
                ...varItem,
                ...computed,
                index: displayIndex,
                placeholderText, // Dynamic placeholder text
                hasAlternateTextError,
                isNameType,
                isNumberType,
                objectOptions
            };
        });
    }


    get availableObjectsWithSelection() {
        // Highlight the selected object
        return this.availableObjects.map(obj => ({
            ...obj,
            isSelected: obj.value === this.selectedObject
        }));
    }

    get toolbarButtonsWithClasses() {
        // Cache toolbar buttons since they never change after initial computation
        if (!this._cachedToolbarButtons) {
            this._cachedToolbarButtons = this.toolbarButtons.map(button => ({
                ...button,
                iconUrl: this.getIconPath(button.iconName),
                classes: `toolbar-button ${button.title.toLowerCase()}`,
                imgClasses: `custom-icon ${button.iconName.toLowerCase()}`
            }));
        }
        return this._cachedToolbarButtons;
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

    get templateNameDisabled() {
        return this.isEditTemplate && (this.isTemplateClone == false);
    }

    // ============================
    // UI CONDITIONALS
    // ============================

    get showRemoveButton() {
        // Show remove button if more than one package
        return this.packages.length > 1;
    }

    get quickReplyOptions() {
        // Cache with invalidation when activeTab changes
        if (!this._cachedQuickReplyOptions || this._lastActiveTabForQuickReply !== this.activeTab) {
            this._lastActiveTabForQuickReply = this.activeTab;
            this._cachedQuickReplyOptions = this.dropdownOptions
                .filter(option => this.activeTab == 'Utility' ?
                    option.value === 'QUICK_REPLY' :
                    option.value === 'QUICK_REPLY' || option.value === 'Marketing opt-out')
                .map(option => ({
                    ...option,
                    iconUrl: this.getButtonPath(option.iconName),
                    classes: `dropdown-item ${option.title.toLowerCase().replace(/\s+/g, '-')}`
                }));
        }
        return this._cachedQuickReplyOptions;
    }

    get callToActionOptions() {
        // Cache call-to-action options (static, never changes)
        if (!this._cachedCallToActionOptions) {
            this._cachedCallToActionOptions = this.dropdownOptions
                .filter(option => ['PHONE_NUMBER', 'URL', 'FLOW', 'COPY_CODE'].includes(option.value))
                .map(option => ({
                    ...option,
                    iconUrl: this.getButtonPath(option.iconName),
                    classes: `dropdown-item ${option.title.toLowerCase().replace(/\s+/g, '-')}`
                }));
        }
        return this._cachedCallToActionOptions;
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

            this.fetchTemplateData(); // Load template data when ID is set
        }
    }

    getIconPath(iconName) {
        return `${richTextZip}/rich-texticon/${iconName}.png`;
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

            this.isLoading = true;
            this.iseditTemplatevisible = true;
            if (this.selectedTab != undefined && this.selectedOption != undefined) {
                this.handleTabClick(this.selectedTab);
                this.handleRadioChange(this.selectedOption);
            }

            // Generate synchronous data first
            this.generateEmojiCategories();

            // Execute independent async operations in parallel for better performance
            Promise.all([
                this.getS3ConfigDataAsync(),
                this.fetchCountries(),
                this.fetchLanguages(),
                this.fetchUpdatedTemplates(false),
                this.fetchObjectsWithPhoneField(),
                getCompanyName()
            ]).then(results => {
                // getCompanyName result is the last one
                this.companyName = results[5] || '';
            }).catch(error => {
                console.error('Error in parallel initialization:', error);
            });
        } catch (e) {
            console.error('Error in connectedCallback:', e.message);
        }
        
        // Store bound reference for proper cleanup in disconnectedCallback
        this._boundHandleOutsideClick = this.handleOutsideClick.bind(this);
        document.addEventListener('click', this._boundHandleOutsideClick);
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
                        // Script loaded successfully
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

    getAllFlowScreens() {
        getAllFlowScreenIds({
            flowId: this.selectedFlowId
        }).then(result => {
            this.flowScreenIds = result;
        }).catch(error => {
            console.error('Error fetching flow screen ids:', error);
        });
    }

    /**
     * Shared helper to compute variable field options with selection state
     * Simplified version since wbMergeFieldSelector component now handles the picker logic
     */
    computeVariableFields(varItem, isHeaderVariable = false) {
        const fieldOptions = this.fields || [];
        const selectedField = fieldOptions.find(field => field.value === varItem.field);
        const fieldLabel = varItem.fieldLabel || selectedField?.label || varItem.field || 'Search fields...';
        
        return {
            fieldLabel,
            options: fieldOptions.map(field => ({
                ...field,
                isSelected: field.value === varItem.field
            }))
        };
    }

    /**x
     * Shared method to reset media/content type flags
     */
    resetMediaFlags() {
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
    }

    /**
     * Shared method to reset radio/option selection flags
     */
    resetOptionFlags() {
        this.utilityOrderStatusSelected = false;
        this.authenticationPasscodeSelected = false;
        this.UtilityCustomSelected = false;
        this.defaultPreview = false;
        this.isFlowMarketing = false;
        this.isFlowUtility = false;
        this.showDefaultBtn = true;
    }

    /**
     * Unified handler for object selection changes (both header and body)
     */
    async handleObjectChange(event) {
        const selectedObject = event.target.value;
        this.isLoading = true;
        this.selectedObject = selectedObject;

        try {
            const fieldOptions = await this.loadObjectFields(selectedObject);
            const simpleFields = this.flattenFieldsForDropdown(fieldOptions);
            const firstField = simpleFields[0] || fieldOptions[0];

            this.fields = simpleFields;

            // Update body variables
            if (this.variables.length > 0) {
                this.variables = this.variables.map(varItem => ({
                    ...varItem,
                    object: selectedObject,
                    field: firstField?.value || '',
                    fieldLabel: firstField?.label || 'Search fields...',
                    options: simpleFields
                }));
                this.formatedTempBody = this.formatText(this.tempBody);
                this.updateTextarea();
                this.updatePreviewContent(this.formatedTempBody, 'body');
            }

            // Update header variables
            if (this.header_variables.length > 0) {
                this.header_variables = this.header_variables.map(varItem_1 => ({
                    ...varItem_1,
                    object: selectedObject,
                    field: firstField?.value || '',
                    fieldLabel: firstField?.label || 'Search fields...',
                    options: simpleFields
                }));
                this.updatePreviewContent(this.header, 'header');
            }
        } catch (error) {
            console.error('Error fetching fields with relationships: ', error);
        }
        finally {
            this.isLoading = false;
        }
}

    /**
     * Extract all unique object names from a field path
     * Example: "Account.Owner.Profile.Name" -> ["Account", "User", "Profile"]
     */
    extractObjectsFromFieldPath(objectName, fieldPath) {
        const objects = [objectName];
        
        if (!fieldPath || !fieldPath.includes('.')) {
            return objects;
        }

        // Split by dots and process each relationship
        const parts = fieldPath.split('.');
        let currentObject = objectName;
        
        for (let i = 0; i < parts.length - 1; i++) {
            const fieldName = parts[i];
            
            // Try to find the field in our cached object field map
            const cachedFields = this.allObjectFieldsMap[currentObject];
            if (cachedFields) {
                const field = cachedFields.find(f => f.value === fieldName || f.value === fieldName + '.');
                if (field && field.relatedObject) {
                    currentObject = field.relatedObject;
                    objects.push(currentObject);
                }
            }
        }
        
        return objects;
    }

    /**
     * Get all unique objects needed for the current template variables
     */
    getAllRequiredObjects() {
        const objectSet = new Set();
        
        // Add the main selected object
        if (this.selectedObject) {
            objectSet.add(this.selectedObject);
        }
        
        // Extract objects from body variables
        if (this.variables && this.variables.length > 0) {
            this.variables.forEach(variable => {
                if (variable.object) {
                    objectSet.add(variable.object);
                    
                    // Extract objects from nested field paths
                    if (variable.field && variable.field.includes('.')) {
                        const objects = this.extractObjectsFromFieldPath(variable.object, variable.field);
                        objects.forEach(obj => objectSet.add(obj));
                    }
                }
            });
        }

        // Extract objects from header variables
        if (this.header_variables && this.header_variables.length > 0) {
            this.header_variables.forEach(variable => {
                if (variable.object) {
                    objectSet.add(variable.object);
                    
                    // Extract objects from nested field paths
                    if (variable.field && variable.field.includes('.')) {
                        const objects = this.extractObjectsFromFieldPath(variable.object, variable.field);
                        objects.forEach(obj => objectSet.add(obj));
                    }
                }
            });
        }

        return Array.from(objectSet);
    }

    /**
     * Pre-fetch all object fields for edit mode
     */
    async prefetchAllObjectFields() {
        const requiredObjects = this.getAllRequiredObjects();
        
        if (requiredObjects.length === 0) {
            return;
        }        
        
        try {
            // Use the unified method with multiple objects and empty relationship paths
            const result = await getObjectFieldsWithRelationships({ 
                objectNames: requiredObjects,
                relationshipPaths: []
            });
            
            // Store all fields in the map
            this.allObjectFieldsMap = result || {};
            
            // Now load relationship children for nested field paths and regenerate labels
            this.loadRelationshipChildrenForVariables();
        } catch (error) {
            console.error('Error pre-fetching object fields:', error);
            this.showToast('Error loading field data: ' + (error.body?.message || error.message), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async loadRelationshipChildrenForVariables() {

        try {
            // Collect all unique relationship paths from variables
            const relationshipPaths = new Set();
            
            const processVariable = (variable) => {
                if (variable.field && variable.field.includes('.')) {
                    const parts = variable.field.split('.');
                    for (let i = 0; i < parts.length - 1; i++) {
                        const path = parts.slice(0, i + 1).join('.');
                        relationshipPaths.add(path);
                    }
                }
            };
            
            // Process body variables
            if (this.variables && this.variables.length > 0) {
                this.variables.forEach(processVariable);
            }
            
            // Process header variables
            if (this.header_variables && this.header_variables.length > 0) {
                this.header_variables.forEach(processVariable);
            }
            
            if (relationshipPaths.size === 0) {
                return;
            }
            
            const resultMap = await getObjectFieldsWithRelationships({
                objectNames: [this.selectedObject],
                relationshipPaths: Array.from(relationshipPaths)
            });
            
            for (const [path, childFields] of Object.entries(resultMap)) {
                if (childFields && childFields.length > 0) {
                    this.updateFieldOptionsTree(path, childFields);
                }
            }

            this.regenerateVariableLabels();
            
        } catch (error) {
            console.error('Error loading relationship children:', error.stack);
        }
        
        // After loading all children, regenerate labels for variables
    }

    /**
     * Regenerate field labels for all variables after relationship children are loaded
     */
    regenerateVariableLabels() {
        // Regenerate labels for body variables
        if (this.variables && this.variables.length > 0) {
            this.variables = this.variables.map(variable => {
                const fieldLabel = this.generateFieldLabelFromPath(variable.field);
                return {
                    ...variable,
                    fieldLabel: fieldLabel
                };
            });
        }
        
        // Regenerate labels for header variables
        if (this.header_variables && this.header_variables.length > 0) {
            this.header_variables = this.header_variables.map(variable => {
                const fieldLabel = this.generateFieldLabelFromPath(variable.field);
                return {
                    ...variable,
                    fieldLabel: fieldLabel
                };
            });
        }
    }

    /**
     * Update the field options tree with loaded children for a relationship path
     */
    updateFieldOptionsTree(relationshipPath, childFields) {
        const updateChildren = (fields, path) => {
            return fields.map(field => {
                if (field.value === path) {
                    return { ...field, children: childFields };
                }
                if (field.children && field.children.length > 0) {
                    return { ...field, children: updateChildren(field.children, path) };
                }
                return field;
            });
        };

        this.fieldOptionsWithRelationships = updateChildren(
            this.fieldOptionsWithRelationships, 
            relationshipPath
        );
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
        setTimeout(()=>{
            this.getAllFlowScreens();
        },400);

        this.isFlowSelected = true; // Hide "Choose Flow" button after selection
        this.NoFileSelected = false; // Hide text after selection
        
        // Add flow button if it doesn't exist in buttonList
        const hasFlowButton = this.buttonList.some(button => button.isFlow);
        if (!hasFlowButton && this.flowCount < 1) {
            // Create and add flow button
            const newFlowButton = {
                id: this.buttonList.length + 1,
                selectedActionType: 'FLOW',
                iconName: this.getButtonIcon('FLOW'),
                btntext: 'View flow',
                webURL: '',
                phonenum: '',
                offercode: '',
                selectedUrlType: 'Static',
                selectedCountryType: '',
                selectedCountryTypeLabel: '',
                isCallPhone: false,
                isVisitSite: false,
                isOfferCode: false,
                isFlow: true,
                hasError: false,
                errorMessage: ''
            };
            
            this.buttonList.push(newFlowButton);
            this.flowCount++;
            this.totalButtonsCount++;
            this.createButton = true;
            
            this.updateButtonErrors();
            this.updateButtonDisabledState();
        }
        
        this.closeModal();
    }

    handleFlowDeleteClick(event) {
        // Remove the flow selection
        this.isFlowSelected = false;
        this.selectedFlowId = '';
        this.selectedFlow = undefined;
        this.NoFileSelected = true;
        
        // Also remove any FLOW button from buttonList
        const flowButtonIndex = this.buttonList.findIndex(button => button.isFlow);
        if (flowButtonIndex !== -1) {
            this.buttonList = this.buttonList.filter((_, i) => i !== flowButtonIndex);
            this.flowCount--;
            this.totalButtonsCount--;
            
            if (this.buttonList.length === 0) {
                this.createButton = false;
            }
            
            this.updateButtonDisabledState();
        }
    }

    convertTimeToSeconds(label) {
        return TIME_TO_SECONDS_MAP[label] || 300; // Default to 5 minutes if not found
    }

    getButtonIcon(type) {
        return BUTTON_ICON_MAP[type] || 'utility:question';
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
        this.resetOptionFlags();

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
        this.selectedOption = optionname;
        this.ifUtilty = false;
        this.resetOptionFlags();

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

    getS3ConfigDataAsync() {
        return getS3ConfigSettings()
            .then(result => {
                if (result != null) {
                    this.confData = result;
                    this.isAWSEnabled = true;
                }
                return result;
            }).catch(error => {
                console.error('error in getS3ConfigDataAsync -> ', error?.stack || error);
                return null;
            });
    }

    handleOutsideClick(event) {
        const target = event.target;
        
        // Handle emoji picker close
        if (this.showEmojis) {
            const emojiContainer = this.template.querySelector('.toolbar-button');
            const button = this.template.querySelector('button');
            if (
                (emojiContainer && !emojiContainer.contains(target)) &&
                (button && !button.contains(target))
            ) {
                this.showEmojis = false;
            }
        }
        
        // Note: Field picker dropdown closing is now handled by wbMergeFieldSelector component
        
        // Close button dropdown when clicking outside
        if (this.isDropdownOpen) {
            const dropdownContainer = this.template.querySelector('.dropdown-container');
            if (dropdownContainer && !dropdownContainer.contains(target)) {
                this.isDropdownOpen = false;
                this.dropdownClass = 'dropdown-hidden';
            }
        }
    }

    // Helper method to flatten fields for dropdown display
    flattenFieldsForDropdown(fields, parentLabel = '') {
        let result = [];
        if (!fields || !Array.isArray(fields)) return result;
        
        fields.forEach(field => {
            const displayLabel = parentLabel ? `${parentLabel} > ${field.label}` : field.label;
            const displayValue = parentLabel ? `${parentLabel.replace(/ > /g, '.')}.${field.value}` : field.value;
            
            if (!field.isRelationship) {
                result.push({ label: displayLabel, value: displayValue });
            }
            
            if (field.children && field.children.length > 0) {
                result = result.concat(this.flattenFieldsForDropdown(field.children, displayLabel));
            }
        });
        return result;
    }

    // Generate a display label from a field path (e.g., "Account.Owner.Name" -> "Account (Account) > Owner (User) > Name")
    generateFieldLabelFromPath(fieldPath) {
        if (!fieldPath) return 'Search fields...';
        
        // If it's a simple field (no dots), just return it
        if (!fieldPath.includes('.')) {
            // Try to find the label from fieldOptionsWithRelationships - use exact match only
            const field = this.fieldOptionsWithRelationships?.find(f => f.value === fieldPath || f.apiName === fieldPath);
            return field?.label || fieldPath;
        }
        
        // For relationship paths, build the label from the path parts
        const pathParts = fieldPath.split('.');
        let labelParts = [];
        let currentFields = this.fieldOptionsWithRelationships || [];
        
        for (let i = 0; i < pathParts.length; i++) {
            const part = pathParts[i];
            const isLastPart = i === pathParts.length - 1;
            
            if (isLastPart) {
                // Last part is the field name - find it in current fields using EXACT match only
                const field = currentFields.find(f => {
                    // Use strict exact matching to avoid selecting wrong fields
                    // e.g., "Name" should not match "CompanyName"
                    return f.apiName === part || f.value === part;
                });
                if (field && !field.isRelationship) {
                    labelParts.push(field.label);
                } else {
                    labelParts.push(part);
                }
            } else {
                // Intermediate parts are relationships - use exact match for apiName/relationshipName/value
                const relationshipField = currentFields.find(f => {
                    if (!f.isRelationship) return false;
                    // Use strict matching for relationships
                    return f.apiName === part || 
                           f.relationshipName === part ||
                           f.value === part;
                });
                if (relationshipField) {
                    labelParts.push(relationshipField.label);
                    currentFields = relationshipField.children || [];
                } else {
                    // Fallback - just use the part name
                    labelParts.push(part);
                    currentFields = [];
                }
            }
        }
        
        return labelParts.join(' > ') || fieldPath;
    }

    // Load and process fields for a given object
    async loadObjectFields(objectName, relationshipPath = '') {
        // Check if we already have cached fields for this object at root level
        if (!relationshipPath && this.allObjectFieldsMap[objectName]) {
            const cachedFields = this.allObjectFieldsMap[objectName];
            this.fieldOptionsWithRelationships = cachedFields;
            const simpleFields = this.flattenFieldsForDropdown(cachedFields);
            this.objectFieldMap[objectName] = simpleFields;
            this.fields = simpleFields;
            
            // Update any existing variables with empty fields
            this.updateVariablesWithDefaultFields(simpleFields, objectName);
            
            return cachedFields;
        }
        
        // Call the unified method with list parameter
        const resultMap = await getObjectFieldsWithRelationships({ 
            objectNames: [objectName], 
            relationshipPaths: relationshipPath ? [relationshipPath] : []
        });
        
        // Extract the field options for the requested object (key is path if provided, else objectName)
        const fieldOptions = relationshipPath ? (resultMap[relationshipPath] || []) : (resultMap[objectName] || []);
        
        if (!relationshipPath) {
            // Root level - store in main cache
            this.fieldOptionsWithRelationships = fieldOptions;
            const simpleFields = this.flattenFieldsForDropdown(fieldOptions);
            this.objectFieldMap[objectName] = simpleFields;
            this.fields = simpleFields;
            // Also cache in allObjectFieldsMap
            this.allObjectFieldsMap[objectName] = fieldOptions;
            
            // Update any existing variables with empty fields
            this.updateVariablesWithDefaultFields(simpleFields, objectName);
        }
        
        return fieldOptions;
    }

    /**
     * Update variables that have empty field values with the first field from the loaded fields
     * This ensures that when fields are loaded after variables are created (e.g., paste body then fields load),
     * the variables get proper default field values
     */
    updateVariablesWithDefaultFields(fields, objectName) {
        if (!fields || fields.length === 0) return;
        
        const firstField = fields[0];
        let variablesUpdated = false;
        let headerVariablesUpdated = false;
        
        // Update body variables with empty field values
        if (this.variables.length > 0) {
            this.variables = this.variables.map(varItem => {
                // Only update if field is empty and object matches
                if ((!varItem.field || varItem.field === '') && varItem.object === objectName) {
                    variablesUpdated = true;
                    return {
                        ...varItem,
                        field: firstField.value || '',
                        fieldLabel: firstField.label || 'Search fields...',
                        options: fields
                    };
                }
                return varItem;
            });
            
            if (variablesUpdated) {
                this.formatedTempBody = this.formatText(this.tempBody);
                this.updateTextarea();
                this.updatePreviewContent(this.formatedTempBody, 'body');
            }
        }
        
        // Update header variables with empty field values
        if (this.header_variables.length > 0) {
            this.header_variables = this.header_variables.map(varItem => {
                if ((!varItem.field || varItem.field === '') && varItem.object === objectName) {
                    headerVariablesUpdated = true;
                    return {
                        ...varItem,
                        field: firstField.value || '',
                        fieldLabel: firstField.label || 'Search fields...',
                        options: fields
                    };
                }
                return varItem;
            });
            
            if (headerVariablesUpdated) {
                this.updatePreviewContent(this.header, 'header');
            }
        }
    }

    fetchObjectsWithPhoneField() {
        getObjectsWithPhoneField()
            .then((result) => {
                this.availableObjects = result;
                // Only set default selectedObject for new templates, not in edit/clone mode
                if (!this.isEditTemplate && !this.isTemplateClone) {
                    this.selectedObject = this.availableObjects[0].value;
                    this.isLoading = false;
                    return this.loadObjectFields(this.selectedObject);
                }
                return Promise.resolve();
            })
            .catch((error) => {
                this.showToast('Error fetching objects with phone field: ' + error.message, 'error');
            })
    }

    fetchTemplateData() {
        try {
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

                        this.templateName = template.MVEX__Template_Name__c || '';
                        this.templateName += this.isTemplateClone ? '_clone' : '';
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
                            this.contentVersionId = templateMiscellaneousData?.contentVersionId
                            this.originalContentVersionId = templateMiscellaneousData?.contentVersionId
                            this.isImageFile = templateMiscellaneousData?.isImageFile
                            this.isImgSelected = templateMiscellaneousData?.isImgSelected
                            this.isDocSelected = templateMiscellaneousData?.isDocSelected
                            this.isVidSelected = templateMiscellaneousData?.isVidSelected
                            this.IsHeaderText = templateMiscellaneousData?.isHeaderText
                            this.addHeaderVar = templateMiscellaneousData?.addHeaderVar
                            this.addMedia = templateMiscellaneousData?.addMedia
                            this.isImageFileUploader = templateMiscellaneousData?.isImageFileUploader
                            this.isVideoFileUploader = templateMiscellaneousData?.isVideoFileUploader
                            this.isDocFileUploader = templateMiscellaneousData?.isDocFileUploader
                            this.isVideoFile = templateMiscellaneousData?.isVideoFile
                            this.isDocFile = templateMiscellaneousData?.isDocFile
                            this.prevContent = templateMiscellaneousData?.isSecurityRecommedation
                            this.isExpiration = templateMiscellaneousData?.isCodeExpiration
                            this.expirationTime = templateMiscellaneousData?.expireTime
                            this.value = templateMiscellaneousData?.authRadioButton
                            this.isautofillChecked = templateMiscellaneousData?.autofillCheck
                            this.isVisitSite = templateMiscellaneousData?.isVisitSite
                            this.isCheckboxChecked = templateMiscellaneousData?.isCheckboxChecked
                            this.isFlowMarketing = templateMiscellaneousData?.isFlowMarketing
                            this.isFlowUtility = templateMiscellaneousData?.isFlowUtility
                            this.isFlowSelected = templateMiscellaneousData?.isFlowSelected
                            this.selectedFlow = templateMiscellaneousData?.selectedFlow
                            this.isFeatureEnabled = templateMiscellaneousData?.isFeatureEnabled
                            this.awsFileName = templateMiscellaneousData?.awsFileName
                            this.catalogName = templateMiscellaneousData?.selectedCatalog
                            this.flowScreenIds = templateMiscellaneousData?.flowNavigationScreen
                                
                            if(this.awsFileName && !this.isAWSEnabled){
                                this.showToast('AWS Configration missing.', 'warning');
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

                        if (template?.MVEX__Header_Type__c == 'Image' || template?.MVEX__Header_Type__c == 'Video' || template?.MVEX__Header_Type__c == 'Document') {
                            const parser = new DOMParser();
                            const doc = parser.parseFromString(template?.MVEX__WBHeader_Body__c, "text/html");
                            this.previewHeader = doc.documentElement.textContent || "";
                            this.fileName = template?.MVEX__File_Name__c;
                            this.fileType = template?.MVEX__Header_Type__c;
                            this.filePreview = template?.MVEX__WBHeader_Body__c;
                            this.headerHandle = template?.MVEX__Header_Handle__c || '';

                            if ((this.headerHandle == '' || this.headerHandle == null) && this.isEditTemplate == true) {
                                getMetaHeaderHandler({ fileUrlOrContentVersionId: this.previewHeader, contentVersionId: this.contentVersionId })
                                    .then((result) => {
                                        if (!result || !result.trim()) {
                                            this.showToast('Header handle missing, please reupload file.', 'warning');
                                        }
                                        this.headerHandle = result
                                    }).catch((error) => {
                                        console.error('Error fetching header handler: ', error);
                                    });
                            }
                            else {
                                if (this.filePreview) {
                                    this.handleFileFromUrl(this.filePreview, this.fileName || 'headerfile');
                                }
                            }
                        } else {
                            this.previewHeader = this.formatText(headerBody) || '';
                        }


                        this.selectedContentType = template.MVEX__Header_Type__c || 'None';
                        
                        // Set IsHeaderText flag and header value when header type is Text
                        if (this.selectedContentType === 'Text') {
                            this.IsHeaderText = true;
                            this.header = headerBody || '';
                        }
                        
                        this.btntext = template.MVEX__Button_Label__c || '';

                        const tvs = templateVariables.map(tv => ({
                            object: tv.objName,
                            field: tv.fieldName,
                            alternateText: tv.alternateText ? tv.alternateText : '',
                            id: tv.variable.slice(2, 3),
                            index: tv.variable,
                            type: tv.type
                        }));

                        // Identify all unique objects
                        const uniqueObjects = [...new Set(tvs.map(tv => tv.object))];
                        
                        // Set the selectedObject from template variables for Body type
                        const bodyVariables = tvs.filter(tv => tv.type === 'Body');
                        if (bodyVariables.length > 0 && bodyVariables[0].object) {
                            this.selectedObject = bodyVariables[0].object;
                        }

                        // Fetch field maps for all unique objects (if not already cached)
                        const fieldFetchPromises = uniqueObjects.map(obj => {
                            return this.objectFieldMap[obj]
                                ? Promise.resolve()
                                : this.fetchFields(obj); // this must return a Promise
                        });

                        Promise.all(fieldFetchPromises)
                            .then(() => {
                                // Load fields with relationships for the selected object (for the field picker)
                                if (this.selectedObject) {
                                    return this.loadObjectFields(this.selectedObject);
                                }
                                return Promise.resolve();
                            })
                            .then(() => {
                                // Split variables into body and header groups
                                const tempfieldsBody = tvs.filter(tv => tv.type === 'Body').map(tv => tv.field);
                                const tempfieldsHead = tvs.filter(tv => tv.type === 'Header').map(tv => tv.field);
                                
                                // Body variables with individual field options and proper fieldLabel
                                this.variables = tvs
                                    .filter(tv => tv.type === 'Body')
                                    .map((variable, index) => {
                                        const objectFields = this.objectFieldMap[variable.object] || [];
                                        const fieldValue = tempfieldsBody[index] || variable.field;
                                        
                                        // Generate fieldLabel from field path (e.g., "Account.Owner.Name" -> "Account (Account) > Owner (User) > Name")
                                        const fieldLabel = this.generateFieldLabelFromPath(fieldValue);
                                        
                                        return {
                                            ...variable,
                                            field: fieldValue,
                                            fieldLabel: fieldLabel,
                                            variableType: variable.variableType || 'Number', // Default to 'Number' type
                                            nameValue: variable.nameValue || variable.alternateText || '', // Use alternateText as nameValue for backward compatibility
                                            options: objectFields
                                        };
                                    });
                                
                             

                                // Header variables with individual field options and proper fieldLabel
                                this.header_variables = tvs
                                    .filter(tv => tv.type === 'Header')
                                    .map((variable, index) => {
                                        const objectFields = this.objectFieldMap[variable.object] || [];
                                        const fieldValue = tempfieldsHead[index] || variable.field;
                                        
                                        // Generate fieldLabel from field path for header variables too
                                        const fieldLabel = this.generateFieldLabelFromPath(fieldValue);
                                        
                                        return {
                                            ...variable,
                                            field: fieldValue,
                                            fieldLabel: fieldLabel,
                                            variableType: variable.variableType || 'Number', // Default to 'Number' type
                                            nameValue: variable.nameValue || variable.alternateText || '',
                                            options: objectFields
                                        };
                                    });                            

                                // Toggle flags
                                this.addHeaderVar = this.header_variables.length > 0;
                                this.addVar = this.variables.length > 0;

                                // Update preview
                                this.updatePreviewContent(this.previewHeader, 'header');
                                this.updatePreviewContent(this.previewBody, 'body');
                                
                                // Pre-fetch all required object fields for edit mode (after variables are set)
                                return this.prefetchAllObjectFields();
                            })
                            .catch(error => {
                                console.error('Error while loading field data for editing:', error);
                                this.isLoading = false;
                            });
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

                                    // Handle phone number parsing
                                    let parsedPhoneNum = '';
                                    let parsedCountryCode = '';
                                    let parsedCountryLabel = 'India (+91)';
                                    
                                    if(button?.type === 'PHONE_NUMBER' && button?.phone_number) {
                                        const phone = button.phone_number;
                                        
                                        // If phone starts with +, find matching country code
                                        if (phone.startsWith('+')) {
                                            const countryCodes = Object.keys(this.countryCodeToLabelMap).sort((a, b) => b.length - a.length); // Sort by length descending
                                            const matchedCode = countryCodes.find(code => phone.startsWith(code));
                                            
                                            if (matchedCode) {
                                                parsedCountryCode = matchedCode;
                                                parsedCountryLabel = this.countryCodeToLabelMap[matchedCode] || parsedCountryLabel;
                                                parsedPhoneNum = phone.slice(matchedCode.length).trim();
                                            } else {
                                                parsedPhoneNum = phone;
                                            }
                                        } else {
                                            // Phone doesn't start with +, check if it's already formatted as "code number"
                                            const parts = phone.split(' ');
                                            if (parts.length >= 2 && parts[0].startsWith('+')) {
                                                parsedCountryCode = parts[0];
                                                parsedCountryLabel = this.countryCodeToLabelMap[parts[0]] || parsedCountryLabel;
                                                parsedPhoneNum = parts.slice(1).join(' ');
                                            } else {
                                                parsedPhoneNum = phone;
                                            }
                                        }
                                    }
                                    
                                    // Handle regular buttons
                                    let newButton = {
                                        id: index + 1, // Unique ID for button
                                        selectedActionType: button?.type || '',
                                        iconName: this.getButtonIcon(button?.type),
                                        btntext: button?.text || '',
                                        webURL: button?.url || '',
                                        phonenum: parsedPhoneNum,
                                        offercode: button?.example || '',
                                        selectedUrlType: button?.type === 'URL' ? 'Static' : '',
                                        selectedCountryType: parsedCountryCode || '+91',
                                        selectedCountryTypeLabel: parsedCountryLabel,
                                        isCallPhone: button?.type === 'PHONE_NUMBER',
                                        isVisitSite: button?.type === 'URL',
                                        isOfferCode: button?.type === 'COPY_CODE',
                                        isFlow: button?.type === 'FLOW',
                                        hasError: false,
                                        errorMessage: ''
                                    };

                                    this.selectedCountryType = newButton.selectedCountryType; 
                                    this.selectedCountryTypeLabel = newButton.selectedCountryTypeLabel;

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
                        this.fetchFlowPreviewId();
                    }, 2000);
                })
                .catch((error) => {
                    console.error('Error fetching fields: ', error);
                })
        } catch (error) {
            console.error('Error fetching template data: ', error);
            this.isLoading = false;
        }
    }

    fetchFlowPreviewId() {
        try {
            if (this.isFlowSelected && this.selectedFlow && (this.selectedFlow.id || this.selectedFlow.flow_id)) {
                let selectedId = this.selectedFlow.id || this.selectedFlow.flow_id;
                
                getPreviewURLofWhatsAppFlow({ flowId: this.flowId })
                .then((data) => {
                    if (data && data.status !== 'failed') {
                        const urlValue = typeof data === 'object' ? data.previewUrl : data;
                        if (urlValue) {
                            this.iframeSrc = urlValue;
                        } else {
                            console.error('URL key not found in the returned Map:', data);
                        }
                    } else {
                        console.error('Error: Backend returned "failed" or empty data');
                    }
                })
                .catch(error => {
                    console.error('Error in getting Flow Preview URL:', error);
                })
                .finally(() => {
                    this.isLoading = false;
                });
            }
        } catch (error) {
            console.error('Error in fetchFlowPreviewId :', error);
        } finally {
            this.isLoading = false;
        }
    }

    fetchFields(objectName) {
        try {
            getObjectFields({ objectName: objectName })
                .then((result) => {
                    const fields = result.map((field) => ({ label: field, value: field }));
                    this.fields = fields;
                    this.objectFieldMap[objectName] = fields;
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

                if (isValid) {
                    this.selectedFilesToUpload.push(file);
                    this.isLoading = true;
                    if (this.isAWSEnabled) {
                        await this.uploadToAWS(this.selectedFilesToUpload);
                    } else {
                        const reader = new FileReader();
                        reader.onload = () => {
                            this.fileData = reader.result.split(',')[1];
                            this.handleUpload();
                        };
                        reader.readAsDataURL(file);
                    }
                } else {
                    this.showToast(`${file.name} exceeds the ${maxSize}MB limit`, 'error');
                }
                this.isLoading = false;
            }
        } catch (error) {
            this.isLoading = false;
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

                    this.uploadFileToMeta();
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
                    this.showToast('Unsupported file type! Please select an image, PDF, or video.', 'error');
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

                    this.uploadFileToMeta(); // Upload to Meta to get header handle
                })
                .catch((error) => {
                    this.isLoading = false;
                    this.showToast('Error uploading file!', 'error');
                });
        } else {
            this.showToast('Please select a file first!', 'error');

        }
    }

    // Delete file from ContentVersion
    handleDelete() {
        const isOriginalFileInEditMode = (this.isEditTemplate || this.isTemplateClone) && 
                                          this.originalContentVersionId !== null && 
                                          this.contentVersionId === this.originalContentVersionId;

        if (isOriginalFileInEditMode) {
            this.resetFileData();
            return;
        }

        // Delete the file based on storage location
        // When AWS is enabled, file is stored in S3, otherwise in Salesforce ContentVersion
        if (this.isAWSEnabled && this.awsFileName) {
            // AWS S3 deletion - file is stored in S3
            deleteImagesFromS3({ fileNames: [this.awsFileName] })
                .then(() => {
                    this.showToast('File deleted successfully', 'success');
                    this.resetFileData();
                })
                .catch((error) => {
                    this.showToast('Error deleting file!', 'error');
                });
        } else if (this.contentVersionId) {
            // Local Salesforce ContentVersion deletion
            deleteFile({ contentVersionId: this.contentVersionId })
                .then((result) => {
                    this.showToast('File deleted successfully', 'success');
                    this.resetFileData();
                })
                .catch((error) => {
                    this.showToast('Error deleting file!', 'error');
                });
        } else {
            // No file to delete, just reset
            this.resetFileData();
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

    /**
     * Uploads file to Meta to get header handle for WhatsApp template creation.
     * This is called after file is uploaded to AWS (if AWS enabled) or after local upload.
     */
    uploadFileToMeta() {
        try {
            this.isLoading = true;
            if (!this.file) {
                this.isLoading = false;
                this.showToast('Please select a file to upload.', 'error');
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
                    console.log('Upload seesion Id ::',result);
                    console.log('Upload seesion Id ::',this.uploadSessionId);
                    
                    this.uploadChunksToMeta();
                    console.log('After chunk');
                    
                } else {
                    this.showToast('Failed to start upload session.', 'error');
                    this.isLoading = false;
                }
            })
            .catch(error => {
                console.error('Failed upload session.', error.body);
                this.isLoading = false;
            });
        } catch (error) {
            console.error('Error starting upload session: ', error);
        }
    }

    /**
     * Uploads file chunks to Meta to get header handle for WhatsApp template.
     * Called by uploadFileToMeta() after getting upload session ID.
     */
    uploadChunksToMeta() {
        try {
            console.log('INside upload chunk');
            
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
                    console.log('Serialized File Chunk Wrapper ::', serializedWrapper);
                    console.log('Is AWS Enabled :: ',this.isAWSEnabled);
                    
                    // Pass isAWSEnabled to backend - it will skip ContentVersion creation when AWS is enabled
                    uploadFileChunk({ serializedWrapper: serializedWrapper, isAWSEnabled: this.isAWSEnabled })
                        .then(result => {
                            if (result) {
                                let serializeResult = JSON.parse(result);
                                this.headerHandle = serializeResult.headerHandle;
                                console.log('Header Handle :::',this.headerHandle);
                                
                                // Only set contentDocumentId when NOT using AWS (local Salesforce storage)
                                if (!this.isAWSEnabled && serializeResult.contentDocumentId) {
                                    this.contentDocumentId = serializeResult.contentDocumentId;
                                }

                                chunkStart += this.LIMITS.chunkSize;
                                if (chunkStart < this.fileSize) {
                                    uploadNextChunk();
                                } else {
                                    this.isLoading = false;
                                    this.showToast('File upload successfully.', 'success');
                                }
                            } else {
                                this.isLoading = false;
                                this.showToast('Failed to upload file chunk.', 'error');
                            }
                        })
                        .catch(error => {
                            this.isLoading = false;
                            console.error('Error uploading file chunk: ', error.body);
                            this.showToast(error.body?.message || 'An error occurred while uploading image.', 'error');
                        });
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
            this.IsHeaderText = this.selectedContentType === 'Text';

            // Reset all media flags first
            this.resetMediaFlags();

            // Set flags based on content type
            const contentTypeConfig = {
                'Image': { isImageFile: true, isImageFileUploader: true, addMedia: true },
                'Video': { isVideoFile: true, isVideoFileUploader: true, addMedia: true },
                'Document': { isDocFile: true, isDocFileUploader: true, addMedia: true },
                'Location': { isLocation: true }
            };

            const config = contentTypeConfig[this.selectedContentType];
            if (config) {
                Object.assign(this, config);
            }
        } catch (error) {
            console.error('Something went wrong while selecting content type: ', JSON.stringify(error));
        }
    }

    handlePrevclick() {
        try {
            if (this.contentVersionId != null) {
                this.handleDelete();
            }
    
            this.clearEditTemplateData();
    
            if( this.isTemplateClone || this.isEditTemplate){
                this.closeAndReturnToTemplateList();
                return;
            } 
    
            const previousEvent = new CustomEvent('previous', {
                detail: {
                    selectedTab: this.selectedTab,
                    selectedOption: this.selectedOption,
                    activeTab: this.activeTab
                }
            });
            this.dispatchEvent(previousEvent);   
        } catch (error) {
            console.error('Error in handlePrevclick: ', error);
        }
    }


    clearEditTemplateData() {
        try {
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
            // Reset original content version ID
            this.originalContentVersionId = null;
            const headerInput = this.template.querySelector('input[name="header"]');
            if (headerInput) {
                headerInput.value = '';
            }
        } catch (error) {
            console.error('Error in clearEditTemplateData: ', error);
        }
    }

    handleCustom(event) {
        this.selectedCustomType = event.target.value;
    }

    // Input change handler map for cleaner code organization
    inputChangeHandlers = {
        templateName: (value) => {
            this.templateName = value.replace(/\s+/g, '_').toLowerCase();
            this.checkTemplateExistence();
        },
        language: (value) => {
            this.selectedLanguage = value;
            this.languageOptions = this.languageOptions.map(option => ({
                ...option,
                isSelected: option.value === this.selectedLanguage
            }));
        },
        footer: (value) => {
            this.footer = value;
        },
        tempBody: (value) => {
            this.tempBody = value.replace(/(\n\s*){3,}/g, '\n\n');
            this.formatedTempBody = this.formatText(this.tempBody);
            this.updatePreviewContent(this.formatedTempBody, 'body');
            // Validate variable format in real-time
            this.updateFormatErrors();
            // Validate variable placement immediately on change
            this.checkBodyVariablePlacement();
            // Sync variables from body text for both types
            this.syncVariablesFromBody();
        },
        btntext: (value, index) => {
            this.updateButtonProperty(index, 'btntext', value);
            this.validateButtonText(index, value);
        },
        isCheckboxChecked: (value, index, checked) => {
            this.isCheckboxChecked = checked;
        },
        isautofillChecked: (value, index, checked) => {
            this.isautofillChecked = checked;
        },
        prevContent: () => {
            this.prevContent = !this.prevContent;
        },
        isExpiration: () => {
            this.isExpiration = !this.isExpiration;
        },
        autofill: (value) => {
            this.autofilLabel = value;
        },
        expirationTime: (value) => {
            this.expirationTime = value;
        },
        selectedTime: (value) => {
            this.selectedTime = value;
            this.expirationTime = this.convertTimeToSeconds(value);
        },
        autoCopyCode: (value) => {
            this.autoCopyCode = value;
        },
        toggle: (value, index, checked) => {
            this.isFeatureEnabled = this.isFeatureEnabled ? false : checked;
        },
        header: (value) => {
            this.header = value;
            // Check variable count based on type
            const allVariableMatches = (value.match(/\{\{[^}]*\}\}/g) || []).length;
            if (allVariableMatches > 1) {
                this.headerError = 'Only one variable is allowed in the header.';
            } else {
                this.headerError = '';
                this.updatePreviewContent(this.header, 'header');
            }
            // Validate variable format in real-time
            this.updateFormatErrors();
            // Sync header variables from header text
            this.syncHeaderVariablesFromText();
        }
    };

    handleInputChange(event) {
        try {
            const { name, value, checked, dataset } = event.target;
            const index = dataset.index;

            // Handle button-related fields that need special processing
            const buttonFields = ['selectedUrlType', 'webURL', 'selectedCountryTypeLabel', 'phonenum', 'offercode'];
            if (buttonFields.includes(name)) {
                if (name === 'selectedCountryTypeLabel') {
                    this.updateButtonProperty(index, 'selectedCountryType', this.countryLabelToCodeMap[value] || value);
                    this.selectedCountryTypeLabel = value;
                }
                this.updateButtonProperty(index, name, value);
                this.selectedCountryType = this.countryLabelToCodeMap[this.selectedCountryTypeLabel];
                this.updatePhonePattern(this.selectedCountryType);
                return;
            }

            // Use handler map for other fields
            const handler = this.inputChangeHandlers[name];
            if (handler) {
                handler(value, index, checked);
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
            this.showToast(error.message || 'An error occurred while checking template existence.', 'error');
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
                // Also remove the flow selection when flow button is removed
                this.isFlowSelected = false;
                this.selectedFlowId = '';
                this.selectedFlow = undefined;
                this.NoFileSelected = true;
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
            
            // Check if this is edit mode (buttonData exists and already has button configured)
            const isEditMode = buttonData && (buttonData.isCallPhone || buttonData.isVisitSite || buttonData.isOfferCode || buttonData.isFlow);
            
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
                selectedCountryTypeLabel: '',
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
                    if (isEditMode || this.callPhoneNumber < 1) {
                        this.createButton = true;
                        newButton.isCallPhone = true;
                        newButton.btntext = buttonData?.btntext || 'Call Phone Number';
                        this.btntext = buttonData?.btntext || 'Call Phone Number';
                        
                        if (!isEditMode) {
                            this.callPhoneNumber++;
                        } else {
                            this.callPhoneNumber = 1;
                        }
                        this.isAddCallPhoneNumber = true;
                    }
                    break;
                case 'URL':
                    if (isEditMode || this.visitWebsiteCount < 2) {
                        this.createButton = true;
                        newButton.isVisitSite = true;
                        this.isVisitSite = true;
                        newButton.btntext = buttonData?.btntext || 'Visit Website';
                        this.btntext = buttonData?.btntext || 'Visit Website';
                        
                        if (!isEditMode) {
                            this.visitWebsiteCount++;
                        } else {
                            // In edit mode, count how many URL buttons exist
                            const existingUrlCount = this.buttonList.filter(b => b.isVisitSite).length;
                            this.visitWebsiteCount = existingUrlCount + 1;
                        }
                        this.isAddVisitWebsiteCount = true;
                    }
                    break;
                case 'COPY_CODE':
                    if (isEditMode || this.copyOfferCode < 1) {
                        this.createButton = true;
                        newButton.isOfferCode = true;
                        newButton.btntext = buttonData?.btntext || 'Copy Offer Code';
                        this.btntext = newButton.btntext;
                        
                        if (!isEditMode) {
                            this.copyOfferCode++;
                        } else {
                            this.copyOfferCode = 1;
                        }
                        this.isAddCopyOfferCode = true;
                    }
                    break;
                case 'FLOW':

                    // In edit mode, always add the flow button if it exists in the data
                    // In create mode, check if we haven't added a flow button yet
                    if (isEditMode || this.flowCount < 1) {

                        this.createButton = true;
                        newButton.isFlow = true;
                        newButton.btntext = buttonData?.btntext || 'View flow';
                        this.btntext = buttonData?.btntext || 'View flow';
                        
                        // Only increment if not in edit mode (to avoid double counting)
                        if (!isEditMode) {
                            this.flowCount++;
                        } else {
                            this.flowCount = 1; // Set to 1 in edit mode
                        }
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
            const defaultField = this.fields[0]?.value || '';
            const defaultFieldLabel = this.fields[0]?.label || 'Select Field';

            // Use the currently selected variable type from the dropdown
            const currentVariableType = this.selectedVariableType || 'Name';

            // For Name type, use empty placeholder; for Number type, use numbered placeholder
            const placeholderIndex = currentVariableType === 'Name' ? '' : this.nextIndex;
            const displayIndex = currentVariableType === 'Name' ? `{{}}` : `{{${this.nextIndex}}}`;

            const newVariable = {
                id: this.nextIndex,
                object: this.selectedObject,
                field: defaultField,
                fieldLabel: defaultFieldLabel,
                alternateText: '',
                variableType: currentVariableType, // Use selected type (Name or Number)
                nameValue: '', // Store the content inside {{}} for Name type
                index: displayIndex,
                options: this.fields
            };

            this.variables = [...this.variables, newVariable];
            
            // Initialize error for both Name and Number types - alternate text is required for both
            this.bodyVarAlternateTextErrors = {
                ...this.bodyVarAlternateTextErrors,
                [this.nextIndex]: 'This field is required'
            };

            // Add placeholder to body text
            const placeholderToAdd = currentVariableType === 'Name' ? '{{}}' : `{{${this.nextIndex}}}`;
            this.tempBody = `${this.tempBody} ${placeholderToAdd} `;
            this.formatedTempBody = this.formatText(this.tempBody);
            this.updateTextarea();
            this.updatePreviewContent(this.formatedTempBody, 'body');
            // Validate variable placement after adding
            this.checkBodyVariablePlacement();
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

    /**
     * Handle field selection from wbMergeFieldSelector component
     */
    handleMergeFieldSelected(event) {
        const { fieldPath, fieldLabel } = event.detail;
        const variableIndex = event.currentTarget.dataset.index;
        const isHeader = event.currentTarget.dataset.isHeader === 'true';
        
        // Update the appropriate variable array
        if (isHeader) {
            // Update header variables
            this.header_variables = this.header_variables.map((varItem) =>
                String(varItem.index) === variableIndex
                    ? {
                        ...varItem,
                        field: fieldPath,
                        fieldLabel: fieldLabel
                    }
                    : varItem
            );
            this.updatePreviewContent(this.header, 'header');
        } else {
            // Update body variables
            this.variables = this.variables.map((varItem) =>
                String(varItem.index) === variableIndex
                    ? {
                        ...varItem,
                        field: fieldPath,
                        fieldLabel: fieldLabel
                    }
                    : varItem
            );
            this.formatedTempBody = this.formatText(this.tempBody);
            this.updatePreviewContent(this.formatedTempBody, 'body');
        }
    }

    handleNameValueChange(event) {
        const variableIndex = String(event.target.dataset.index);
        const variableId = String(event.target.dataset.id);
        const nameValue = event.target.value.trim();
        
        // Update the variables array with nameValue
        this.variables = this.variables.map(varItem =>
            String(varItem.index) === variableIndex
                ? { ...varItem, nameValue }
                : varItem
        );
        
        // Validate name value
        if (!nameValue) {
            this.bodyVarAlternateTextErrors = {
                ...this.bodyVarAlternateTextErrors,
                [variableId]: 'Name value is required'
            };
        } else {
            // Remove error if name value is provided
            const updatedErrors = { ...this.bodyVarAlternateTextErrors };
            delete updatedErrors[variableId];
            this.bodyVarAlternateTextErrors = updatedErrors;
        }
        
        // Update the preview with the new name value
        this.updatePreviewContentWithNameValue();
    }

    handleGlobalVariableTypeChange(event) {
        const newVariableType = event.detail.value;
        
        // Simply switch the type - errors will update automatically
        this.selectedVariableType = newVariableType;
        
        // Re-validate format errors with the new type
        this.updateFormatErrors();
        
        // Update all existing body variables to use the new type
        this.variables = this.variables.map(varItem => ({
            ...varItem,
            variableType: newVariableType
        }));
        
        // Update all existing header variables to use the new type
        this.header_variables = this.header_variables.map(varItem => ({
            ...varItem,
            variableType: newVariableType
        }));

        // Sync variables from body after type change
        this.syncVariablesFromBody();
        
        // Sync header variables after type change
        this.syncHeaderVariablesFromText();

        // Update error messages based on new type
        const updatedErrors = {};
        this.variables.forEach(varItem => {
            if (newVariableType === 'Name') {
                // For Name type, only validate field selection
                if (!varItem.field || varItem.field.trim() === '') {
                    updatedErrors[varItem.id] = 'Field selection is required';
                }
            } else {
                // For Number type, validate alternate text
                if (!varItem.alternateText || varItem.alternateText.trim() === '') {
                    updatedErrors[varItem.id] = 'Alternate text is required';
                }
            }
        });
        this.bodyVarAlternateTextErrors = updatedErrors;

        // Update preview
        this.updatePreviewContent(this.formatedTempBody, 'body');
        
        // Revalidate body placement
        this.checkBodyVariablePlacement();
    }

    /**
     * Validate variable format in text based on variable type
     * @param {string} text - The text to validate
     * @param {string} variableType - 'Name' or 'Number'
     * @param {boolean} strictMode - If true, empty {{}} is not allowed (used for submission)
     * @returns {object} - { isValid: boolean, errorMessage: string }
     */
    validateVariableFormat(text, variableType, strictMode = false) {
        if (!text) {
            return { isValid: true, errorMessage: '' };
        }
        
        // Find all variables in the text
        const allVariables = text.match(/\{\{([^}]*)\}\}/g) || [];
        
        if (allVariables.length === 0) {
            return { isValid: true, errorMessage: '' };
        }
        
        // Check for empty {{}} - not allowed in strict mode (submission)
        if (strictMode) {
            const hasEmptyVars = allVariables.some(v => v === '{{}}');
            if (hasEmptyVars) {
                return {
                    isValid: false,
                    errorMessage: 'Variable parameters cannot be empty. Please provide a name for all variables).'                };
            }
        }
        
        if (variableType === 'Number') {
            // For Number type: variables must be whole numbers like {{1}}, {{2}}
            const numberPattern = /^\{\{\d+\}\}$/;
            const invalidVars = allVariables.filter(v => !numberPattern.test(v));
            
            if (invalidVars.length > 0) {
                return {
                    isValid: false,
                    errorMessage: 'This template contains variable parameters with incorrect formatting. Variable parameters must be whole numbers with two sets of curly brackets (for example, {{1}}, {{2}}).'
                };
            }
        } else if (variableType === 'Name') {
            const namePattern = /^\{\{([a-zA-Z_][a-zA-Z0-9_]*|)\}\}$/;
            const pureNumberPattern = /^\{\{\d+\}\}$/;
            
            const invalidVars = allVariables.filter(v => {
                if (v === '{{}}') return false;
                if (pureNumberPattern.test(v)) return true;
                return !namePattern.test(v);
            });
            
            if (invalidVars.length > 0) {
                return {
                    isValid: false,
                    errorMessage: 'This template contains variable parameters with incorrect formatting. Variable parameters must be letters, underscores and numbers (not starting with a number) with two sets of curly brackets (for example, {{customer_name}}, {{Name}}).'
                };
            }
        }
        
        return { isValid: true, errorMessage: '' };
    }

    /**
     * Update body and header format errors based on current variable type
     * Call this after any change to body/header text or variable type
     */
    updateFormatErrors() {
        const bodyValidation = this.validateVariableFormat(this.tempBody, this.selectedVariableType);
        this.bodyVariableFormatError = bodyValidation.isValid ? '' : bodyValidation.errorMessage;
        
        const headerValidation = this.validateVariableFormat(this.header, this.selectedVariableType);
        this.headerVariableFormatError = headerValidation.isValid ? '' : headerValidation.errorMessage;
    }

    handleVariableTypeChange(event) {
        const variableIndex = String(event.target.dataset.index);
        const variableType = event.target.value;
        
        // Update the variables array with the new variable type
        this.variables = this.variables.map(varItem =>
            String(varItem.index) === variableIndex
                ? { ...varItem, variableType }
                : varItem
        );
    }

    updatePreviewContentWithNameValue() {
        try {
            let updatedContent = this.tempBody;
            
            this.variables.forEach(varItem => {
                const variablePlaceholder = varItem.index;
                // Use nameValue for display in preview when variableType is 'Name'
                const replacementValue = varItem.variableType === 'Name' && varItem.nameValue 
                    ? `{{${varItem.nameValue}}}` 
                    : `{{${varItem.object}.${varItem.field}}}`;

                let index = updatedContent.indexOf(variablePlaceholder);
                while (index !== -1) {
                    updatedContent = updatedContent.slice(0, index) + replacementValue + updatedContent.slice(index + variablePlaceholder.length);
                    index = updatedContent.indexOf(variablePlaceholder, index + replacementValue.length);
                }
            });

            this.previewBody = updatedContent;
        } catch (error) {
            console.error('Something wrong while updating preview with name value.', error);
        }
    }

    /**
     * Sync variables from body text for both Name and Number types
     * Parses {{content}} from body and updates variables array sequentially
     */
    syncVariablesFromBody() {
        try {
            // Match all {{...}} patterns including empty {{}}
            const variablePattern = /\{\{([^}]*)\}\}/g;
            const matches = [...this.tempBody.matchAll(variablePattern)];
            
            if (matches.length === 0) {
                // No variables in body, clear all variables
                this.variables = [];
                this.addVar = false;
                return;
            }

            // Extract the content inside each {{}}
            const bodyVariables = matches.map((match, idx) => ({
                position: idx,
                content: match[1].trim(), // Content inside {{}}
                fullMatch: match[0]
            }));

            const isNameType = this.selectedVariableType === 'Name';
            const defaultField = this.fields[0]?.value || '';
            const defaultFieldLabel = this.fields[0]?.label || 'Select Field';

            // Update existing variables or create new ones based on body content
            const updatedVariables = bodyVariables.map((bodyVar, idx) => {
                const existingVar = this.variables[idx];

                if (existingVar) {
                    // Update existing variable with the content from body
                    if (isNameType) {
                        return {
                            ...existingVar,
                            nameValue: bodyVar.content,
                            index: bodyVar.content ? `{{${bodyVar.content}}}` : `{{}}`
                        };
                    } else {
                        // For Number type, the index is the number
                        return {
                            ...existingVar,
                            index: `{{${bodyVar.content}}}`
                        };
                    }
                } else {
                    // Create new variable
                    return {
                        id: idx + 1,
                        object: this.selectedObject,
                        field: defaultField,
                        fieldLabel: defaultFieldLabel,
                        alternateText: '',
                        variableType: this.selectedVariableType,
                        nameValue: isNameType ? bodyVar.content : '',
                        index: bodyVar.content ? `{{${bodyVar.content}}}` : `{{}}`,
                        options: this.fields
                    };
                }
            });

            this.variables = updatedVariables;
            
            // Show the variable section if there are variables
            if (this.variables.length > 0) {
                this.addVar = true;
            }
        } catch (error) {
            console.error('Error syncing variables from body:', error);
        }
    }

    /**
     * Sync header variables from header text for both Name and Number types
     */
    syncHeaderVariablesFromText() {
        try {
            if (!this.header) {
                return;
            }
            
            // Match all {{...}} patterns including empty {{}}
            const variablePattern = /\{\{([^}]*)\}\}/g;
            const matches = [...this.header.matchAll(variablePattern)];
            
            if (matches.length === 0) {
                // No variables in header, clear header variables
                this.header_variables = [];
                this.addHeaderVar = false;
                return;
            }

            const isNameType = this.selectedVariableType === 'Name';
            const defaultField = this.fields[0]?.value || '';
            const defaultFieldLabel = this.fields[0]?.label || 'Select Field';

            // Update existing header variables or create new ones
            const updatedHeaderVariables = matches.map((match, idx) => {
                const content = match[1].trim();
                const existingVar = this.header_variables[idx];

                if (existingVar) {
                    if (isNameType) {
                        return {
                            ...existingVar,
                            nameValue: content,
                            index: content ? `{{${content}}}` : `{{}}`
                        };
                    } else {
                        return {
                            ...existingVar,
                            index: `{{${content}}}`
                        };
                    }
                } else {
                    return {
                        id: idx + 1,
                        object: this.selectedObject,
                        field: defaultField,
                        fieldLabel: defaultFieldLabel,
                        alternateText: '',
                        variableType: this.selectedVariableType,
                        nameValue: isNameType ? content : '',
                        index: content ? `{{${content}}}` : `{{}}`
                    };
                }
            });

            this.header_variables = updatedHeaderVariables;
            
            // Show the header variable section if there are variables
            if (this.header_variables.length > 0) {
                this.addHeaderVar = true;
            }
        } catch (error) {
            console.error('Error syncing header variables from text:', error);
        }
    }

    handleAlternateVarChange(event) {
        const variableIndex = String(event.target.dataset.index);
        const variableId = String(event.target.dataset.id);
        const alternateText = event.target.value.trim();
        
        // Update the variables array - store in alternateText field for both Name and Number types
        this.variables = this.variables.map(varItem =>
            String(varItem.index) === variableIndex
                ? { ...varItem, alternateText }
                : varItem
        );
        
        // Validate alternate text - required for both Name and Number types
        if (!alternateText) {
            this.bodyVarAlternateTextErrors = {
                ...this.bodyVarAlternateTextErrors,
                [variableId]: 'This field is required'
            };
        } else {
            // Remove error if alternate text is provided
            const updatedErrors = { ...this.bodyVarAlternateTextErrors };
            delete updatedErrors[variableId];
            this.bodyVarAlternateTextErrors = updatedErrors;
        }
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
            const varToRemove = this.variables[parseInt(index)];
            
            if (this.selectedVariableType === 'Name') {
                // For Name type, remove the variable by its content or empty placeholder
                const variableToRemove = varToRemove.nameValue 
                    ? `{{${varToRemove.nameValue}}}` 
                    : `{{}}`;
                let updatedTempBody = this.tempBody.replace(variableToRemove, '');
                this.variables = this.variables.filter((_, i) => i !== parseInt(index));
                
                // Re-index remaining variables
                this.variables = this.variables.map((varItem, idx) => ({
                    ...varItem,
                    id: idx + 1
                }));
                
                this.tempBody = updatedTempBody.trim();
                this.originalTempBody = this.tempBody;
                this.formatedTempBody = this.formatText(this.tempBody);
                
                // Sync variables from body after removal
                this.syncVariablesFromBody();
            } else {
                // For Number type, use existing logic
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
            }
            
            // Clear errors and rebuild for remaining variables
            const updatedErrors = {};
            this.variables.forEach(varItem => {
                if (this.bodyVarAlternateTextErrors[varItem.id]) {
                    updatedErrors[varItem.id] = this.bodyVarAlternateTextErrors[varItem.id];
                }
            });
            this.bodyVarAlternateTextErrors = updatedErrors;

            this.updatePreviewContent(this.tempBody, 'body');
            this.nextIndex = this.variables.length + 1;
            if (this.variables.length === 0) {
                this.addVar = false;
                this.nextIndex = 1;
            }
            this.updateTextarea();
            // Validate variable placement after removing
            this.checkBodyVariablePlacement();
        } catch (error) {
            console.error('Something wrong while removing the variable.', error);
        }
    }

    // Header variable add-remove functionality start here
    addheadervariable() {
        try {
            this.addHeaderVar = true;
            const defaultField = this.fields[0]?.value || '';
            const defaultFieldLabel = this.fields[0]?.label || 'Search fields...';
            
            // Use the currently selected variable type
            const currentVariableType = this.selectedVariableType || 'Name';
            const isNameType = currentVariableType === 'Name';
            
            // For Name type, use empty placeholder; for Number type, use numbered placeholder
            const displayIndex = isNameType ? `{{}}` : `{{${this.headIndex}}}`;
            const placeholderToAdd = isNameType ? '{{}}' : `{{${this.headIndex}}}`;
            
            const newVariable = {
                id: this.headIndex,
                object: this.selectedObject,
                field: defaultField,
                fieldLabel: defaultFieldLabel,
                alternateText: '',
                variableType: currentVariableType,
                nameValue: '',
                index: displayIndex,
            };

            this.header_variables = [...this.header_variables, newVariable];
            
            // Initialize error for new variable - alternate text is required for both Name and Number types
            this.headerVarAlternateTextErrors = {
                ...this.headerVarAlternateTextErrors,
                [this.headIndex]: 'This field is required'
            };
            
            this.originalHeader = (this.originalHeader || this.header || '') + ` ${placeholderToAdd}`;
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
        const alternateText = event.target.value.trim();
        
        // Update the header_variables array
        this.header_variables = this.header_variables.map(varItem =>
            String(varItem.id) === variableId
                ? { ...varItem, alternateText }
                : varItem
        );
        
        // Validate alternate text - required for both Name and Number types
        if (!alternateText) {
            this.headerVarAlternateTextErrors = {
                ...this.headerVarAlternateTextErrors,
                [variableId]: 'This field is required'
            };
        } else {
            // Remove error if alternate text is provided
            const updatedErrors = { ...this.headerVarAlternateTextErrors };
            delete updatedErrors[variableId];
            this.headerVarAlternateTextErrors = updatedErrors;
        }
    }

    updatePreviewContent(inputContent, type) {
        try {
            let updatedContent = inputContent;

            const variables = type === 'header' ? this.header_variables : this.variables;
            variables.forEach(varItem => {
                const variablePlaceholder = varItem.index;
                // For Name type variables, use nameValue if available
                let replacementValue;
                if (varItem.variableType === 'Name' && varItem.nameValue) {
                    replacementValue = `{{${varItem.nameValue}}}`;
                } else {
                    replacementValue = `{{${varItem.object}.${varItem.field}}}`;
                }

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
            const varToRemove = this.header_variables[parseInt(index)];
            const isNameType = this.selectedVariableType === 'Name';
            
            let updatedHeader = this.header;
            
            if (isNameType) {
                // For Name type, remove by nameValue or empty placeholder
                const variableToRemove = varToRemove.nameValue 
                    ? `{{${varToRemove.nameValue}}}` 
                    : `{{}}`;
                updatedHeader = this.header.replace(variableToRemove, '');
            } else {
                // For Number type, use existing logic
                const varIndexToRemove = parseInt(index, 10) + 1;
                const variableToRemove = `{{${varIndexToRemove}}}`;
                updatedHeader = this.header.replace(variableToRemove, '');
            }
            
            // Get the variable ID before removing it
            const removedVarId = this.header_variables[parseInt(index)]?.id;
            
            this.header_variables = this.header_variables.filter((_, i) => i !== parseInt(index));
            
            if (isNameType) {
                // Re-index remaining variables for Name type
                this.header_variables = this.header_variables.map((varItem, idx) => ({
                    ...varItem,
                    id: idx + 1
                }));
            } else {
                // Re-index for Number type
                this.header_variables = this.header_variables.map((varItem, idx) => {
                    const newIndex = idx + 1;
                    return {
                        ...varItem,
                        id: newIndex,
                        index: `{{${newIndex}}}`,
                        placeholder: `Enter content for {{${newIndex}}}`
                    };
                });
                
                // Renumber placeholders in header text
                let placeholders = updatedHeader.match(/\{\{\d+\}\}/g) || [];
                placeholders.forEach((placeholder, idx) => {
                    const newIndex = `{{${idx + 1}}}`;
                    updatedHeader = updatedHeader.replace(placeholder, newIndex);
                });
            }
            
            // Clear error for removed variable and rebuild errors object for remaining variables
            const updatedErrors = {};
            this.header_variables.forEach(varItem => {
                if (this.headerVarAlternateTextErrors[varItem.id]) {
                    updatedErrors[varItem.id] = this.headerVarAlternateTextErrors[varItem.id];
                }
            });
            this.headerVarAlternateTextErrors = updatedErrors;
            
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

    fetchCountries(){
        try{
            fetch(COUNTRY_PHONE_LENGTHS)
                .then(response => response.json())
                .then(data => {
                    // Build options for combobox
                    this.countryType = data.map(item => ({
                        label: item?.label,
                        value: item?.label
                    }));

                    // Map code → length for validation
                    data.forEach(item => {
                        this.countryLabelToCodeMap[item?.label] = item?.code;
                        this.countryCodeToLabelMap[item?.code] = item?.label;
                        this.countryPhoneMap[item?.code] = item.lengths;
                    });
                    
                    this.updatePhonePattern(this.selectedCountryType);
                })
                .catch(error => console.error('Error loading country codes', error));
        }
        catch(e){
            console.error('Something wrong while fetching country data:', e);
        }
    }
        
    updatePhonePattern(code) {
        const validLengths = this.countryPhoneMap[code];
        if (validLengths && validLengths.length > 0) {
            // Build regex: only digits, allowed lengths only
            const lengths = validLengths.join('|');
            this.phonePattern = `^\\d{${lengths.replace(/,/g, '}$|^\\d{')}}$`;
            this.phoneErrorMessage = `Phone number must be ${validLengths.join(' or ')} digits long.`;
        } else {
            // fallback: at least 1 digit
            this.phonePattern = '^\\d+$';
            this.phoneErrorMessage = 'Enter a valid phone number';
        }
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
                this.showToast('Template Name is required', 'error');
                return false;
            }

            if (!this.selectedLanguage) {
                this.showToast('Please select a language', 'error');
                return false;
            }

            if (!this.tempBody || this.tempBody.trim() === '') {
                this.showToast('Template Body is required', 'error');
                return false;
            }
            
            // Check if body starts or ends with a variable
            if (this.checkBodyVariablePlacement()) {
                this.showToast(this.bodyVariablePlacementError, 'error');
                return false;
            }

            const buttonData = [...this.buttonList, ...this.customButtonList];
            for (let button of buttonData) {
                if (button.isVisitSite) {
                    if (!button.selectedUrlType || !button.webURL || !this.validateUrl(button.webURL)) {
                        this.showToast('Please provide a valid URL that should be properly formatted (e.g., https://example.com)', 'error');
                        return false;
                    }
                } else if (button.isCallPhone) {
                    if (!button.selectedCountryType || !button.phonenum || !this.validatePhoneNumber(button.phonenum)) {
                        this.showToast('Please provide a valid country and phone number for the "Call Phone Number" button', 'error');
                        return false;
                    }
                } else if (button.isOfferCode) {
                    const alphanumericPattern = /^[a-zA-Z0-9]+$/;
                    const offerButton = Array.isArray(button?.offercode) ? button?.offercode[0] : button?.offercode;
                    if (!alphanumericPattern.test(offerButton?.trim())) {
                        this.showToast('Offer code must only contain alphanumeric characters (letters and numbers)', 'error');
                        return false;
                    }
                }

                if (button.isCustom) {
                    if (!button.Cbtntext || button.Cbtntext.trim() === '') {
                        this.showToast('Button text is required for the custom button', 'error');
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

    /**
     * Check if the template body starts or ends with a variable
     * Variables cannot be at the start or end - there must be static text surrounding them
     * @returns {boolean} true if there's a placement error, false otherwise
     */
    checkBodyVariablePlacement() {
        if (!this.tempBody || this.tempBody.trim() === '') {
            this.bodyVariablePlacementError = '';
            return false;
        }

        const errors = [];

        // Normalize the body by replacing all whitespace (including newlines) with single spaces and trim
        const normalizedBody = this.tempBody.replace(/\s+/g, ' ').trim();
        
        // Pattern to match variables - handle both {{1}} and {{name}} formats based on type
        const variablePattern = this.selectedVariableType === 'Name' ? /\{\{[^}]*\}\}/ : /\{\{\d+\}\}/;
        const variablePatternGlobal = this.selectedVariableType === 'Name' ? /\{\{[^}]*\}\}/g : /\{\{\d+\}\}/g;
        
        const startsWithVariable = new RegExp(`^${variablePattern.source}`).test(normalizedBody);
        const endsWithVariable = new RegExp(`${variablePattern.source}$`).test(normalizedBody);

        // Check for back-to-back variables (e.g., {{1}}{{2}} or {{name}}{{other}} without any separator)
        const backToBackPattern = this.selectedVariableType === 'Name' 
            ? /\{\{[^}]*\}\}\{\{[^}]*\}\}/ 
            : /\{\{\d+\}\}\{\{\d+\}\}/;
        const hasBackToBackVariables = backToBackPattern.test(normalizedBody);

        // Collect all placement errors
        if (hasBackToBackVariables) {
            errors.push('Variables cannot be placed directly next to each other. Please add text or a space between variables');
        }
        
        if (startsWithVariable && endsWithVariable) {
            errors.push('Template body cannot start and end with a variable. Please add static text before and after the variables');
        } else if (startsWithVariable) {
            errors.push('Template body cannot start with a variable. Please add static text before the variable');
        } else if (endsWithVariable) {
            errors.push('Template body cannot end with a variable. Please add static text after the variable');
        }

        // Check for variable sequence gaps only for Number type
        if (this.selectedVariableType !== 'Name') {
            const sequenceError = this.checkBodyVariableSequence(normalizedBody);
            if (sequenceError) {
                errors.push(sequenceError);
            }
        }

        // Check variable to word ratio: for x variables, need at least 2x + 1 non-variable words
        const variableWordRatioError = this.checkVariableToWordRatio(normalizedBody);
        if (variableWordRatioError) {
            errors.push(variableWordRatioError);
        }

        // Combine all errors or clear if none
        if (errors.length > 0) {
            this.bodyVariablePlacementError = errors.join('. ');
            return true;
        }

        this.bodyVariablePlacementError = '';
        return false;
    }

    checkVariableToWordRatio(body) {
        // Count the number of variables - handle both {{1}} and {{name}} formats
        const numberedVarMatches = body.match(/\{\{\d+\}\}/g) || [];
        const namedVarMatches = body.match(/\{\{[^}]*\}\}/g) || [];
        
        // Use named vars for Name type, numbered for Number type
        const variableCount = this.selectedVariableType === 'Name' 
            ? namedVarMatches.length 
            : numberedVarMatches.length;

        // If no variables, no need to check
        if (variableCount === 0) {
            return null;
        }

        // Remove all variables from the body to get only the text content
        const textWithoutVariables = body.replace(/\{\{[^}]*\}\}/g, ' ').trim();

        // Split by whitespace and filter out empty strings to get non-variable words
        const nonVariableWords = textWithoutVariables.split(/\s+/).filter(word => word.length > 0);
        const nonVariableWordCount = nonVariableWords.length;

        // Required minimum words: 2x + 1 where x is the number of variables
        const requiredMinWords = (2 * variableCount) + 1;

        if (nonVariableWordCount < requiredMinWords) {
            return `This template has too many variables for its length. Reduce the number of variables or increase the message length.`;
        }

        return null;
    }

    checkBodyVariableSequence(body) {
        // For Name type, skip sequence check as they use {{name}} format
        if (this.selectedVariableType === 'Name') {
            return null;
        }
        
        // Extract all unique variable numbers from the body
        const variableNumbers = new Set();
        const variablePattern = /\{\{(\d+)\}\}/g;
        let match;

        while ((match = variablePattern.exec(body)) !== null) {
            variableNumbers.add(parseInt(match[1], 10));
        }

        if (variableNumbers.size === 0) return null;

        // Find max and check if all numbers from 1 to max are present
        const maxVar = Math.max(...variableNumbers);
        const missingNumbers = [];
        
        for (let i = 1; i <= maxVar; i++) {
            if (!variableNumbers.has(i)) missingNumbers.push(i);
        }

        if (missingNumbers.length > 0) {
            const missingVars = missingNumbers.map(n => `{{${n}}}`).join(', ');
            return `Variable sequence is incomplete. Missing variable(s): ${missingVars}. Variables must be present from {{1}} to {{${maxVar}}}.`;
        }

        return null;
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
        // Validate variable format with strict mode (empty {{}} not allowed)
        const bodyFormatValidation = this.validateVariableFormat(this.tempBody, this.selectedVariableType, true);
        if (!bodyFormatValidation.isValid) {
            this.showToast(bodyFormatValidation.errorMessage, 'error');
            return;
        }
        
        // Also validate header if it has content
        if (this.header) {
            const headerFormatValidation = this.validateVariableFormat(this.header, this.selectedVariableType, true);
            if (!headerFormatValidation.isValid) {
                this.showToast(headerFormatValidation.errorMessage, 'error');
                return;
            }
        }
        
        // Check for missing alternate text in header variables (both Name and Number types)
        const headerMissingAlt = this.header_variables.some(varItem => {
            // AlternateText is required for both Name and Number types
            return !varItem.alternateText || varItem.alternateText.trim() === '';
        });
        
        // Check for missing alternate text in body variables (both Name and Number types)
        const bodyMissingValue = this.variables.some(varItem => {
            // AlternateText is required for both Name and Number types
            return !varItem.alternateText || varItem.alternateText.trim() === '';
        });
        
        if (headerMissingAlt) {
            this.showToast('Example/Alternative Text value is required for all header variables', 'error');
            return;
        }
        
        if (bodyMissingValue) {
            this.showToast('Example/Alternative Text value is required for all body variables', 'error');
            return;
        }
        
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
            this.showToast('Package name must be unique', 'error');

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
            this.showToast('Signature hash must be unique', 'error');

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
        }
    }

    handleSubmit() {
        try {
            if ((this.activeTab == 'Marketing' || this.activeTab == 'Utiltiy') && !this.isCheckboxChecked && this.visitWebsiteCount > 0) {
                this.showToast('Please select check-box to report website clicks.', 'error');
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

            if (this.activeTab == 'Authentication') {
                this.tempBody = ' is your verification code';
            }

            // Extract marketingOptText from customButtonList if Marketing opt-out button exists
            let marketingOptText = null;
            if (this.customButtonList && this.customButtonList.length > 0) {
                const marketingOptButton = this.customButtonList.find(btn => btn.selectedCustomType === 'Marketing opt-out');
                if (marketingOptButton) {
                    marketingOptText = marketingOptButton.Cbtntext;
                }
            }

            // Miscellaneous data for UI state restoration during edit
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
                awsFileName: this.awsFileName,
                catalogName: this.catalogName,
                flowNavigationScreen: this.flowScreenIds
            };

            // Template object with only fields required by Apex TemplateWrapper
            const template = {
                // Required for template record creation
                templateName: this.templateName || null,
                templateCategory: this.activeTab || null,
                templateType: this.selectedOption || null,
                tempLanguage: this.selectedLanguage || null,
                
                // Header fields
                tempHeaderFormat: this.selectedContentType || null,
                tempHeaderHandle: this.headerHandle || null,
                tempHeaderText: this.header || '',
                tempHeaderExample: (this.tempHeaderExample && this.tempHeaderExample.length > 0) ? this.tempHeaderExample : null,
                
                // Media header fields
                tempImgUrl: this.filePreview || null,
                tempImgId: this.contentVersionId || null,
                tempImgName: this.fileName || null,
                
                // Body fields
                templateBody: this.tempBody || '',
                templateBodyText: (this.templateBodyText && this.templateBodyText.length > 0) ? this.templateBodyText : null,
                
                // Footer field
                tempFooterText: (this.activeTab === 'Authentication') ? '' : (this.footer || null),
                
                // Button fields
                typeOfButton: buttonData.length > 0 ? JSON.stringify(buttonData) : null,
                marketingOptText: marketingOptText,
                
                // Authentication template fields
                packagename: formData.length > 0 ? formData.map(pkg => pkg.packagename) : null,
                signaturename: formData.length > 0 ? formData.map(pkg => pkg.signaturename) : null,
                
                // Miscellaneous data (for UI state restoration)
                templateMiscellaneousData: templateMiscellaneousData ? JSON.stringify(templateMiscellaneousData) : null,
                
                // Variable mappings for Template_Variable__c records
                variables: this.variables ? this.variables.map(v => ({
                    placeholder: v.index,
                    alternateText: v.alternateText,
                    objectName: v.object,
                    fieldName: v.field,
                    variableType: v.variableType
                })) : [],
                header_variables: this.header_variables ? this.header_variables.map(v => ({
                    placeholder: v.index,
                    alternateText: v.alternateText,
                    objectName: v.object,
                    fieldName: v.field,
                    variableType: v.variableType
                })) : [],
                
                // Fields needed by buildPayload for Meta API (not stored in Apex)
                selectedVariableType: this.selectedVariableType || 'Name',
                isSecurityRecommedation: this.prevContent || null,
                isCodeExpiration: this.isExpiration != null,
                expireTime: this.expirationTime || 300,
                selectedFlow: this.selectedFlow ? JSON.stringify(this.selectedFlow) : null
            };


            const serializedWrapper = JSON.stringify(template);
            const payload = JSON.stringify(buildPayload(template));
            
            if (this.metaTemplateId && !this.isTemplateClone) {
                editWhatsappTemplate({ serializedWrapper: serializedWrapper, payloadWrapper: payload, templateId: this.metaTemplateId })
                    .then(result => {
                        if (result && result.success) {
                            this.showToast('Template successfully edited.', 'success');
                            this.isLoading = false;
                            this.clearEditTemplateData();
                            this.closeAndReturnToTemplateList();
                        } else if (result && result.success == false && result.status == 'warning') {
                            this.showToast('Template updation taking too much time, please wait for few minutes and refresh the page to see the updated template.', 'warning');
                            this.isLoading = false;
                            setTimeout(() => {
                                checkTemplateExistance({ templateName: this.templateName, serializedWrapper: serializedWrapper, payloadWrapper: payload, metaTempId: this.metaTemplateId, isCreate: false });
                            }, 60000);
                            this.isLoading = false;
                            this.clearEditTemplateData();
                            this.closeAndReturnToTemplateList();
                        } else {
                            const errorResponse = JSON.parse(result.errorMessage);
                            const errorMsg = errorResponse.error.error_user_msg || 'Due to unknown error';

                            this.showToast('Template updation failed, reason - ' + errorMsg, 'error');
                            this.isLoading = false;
                        }
                    })
                    .catch(error => {
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

                        this.showToast('Template edition failed: ' + errorMsg, 'error');
                        this.isLoading = false;
                    });

            } else {
                
                createWhatsappTemplate({ serializedWrapper: serializedWrapper, payloadWrapper: payload, templateName: this.templateName })
                    .then(result => {

                        if (result && result.success) {
                            this.showToast('Template successfully created', 'success');
                            this.isLoading = false;
                            this.clearEditTemplateData();
                            this.closeAndReturnToTemplateList();
                        } else if (result && result.success == false && result.status == 'warning') {
                            this.showToast('Template creation taking too much time, please wait for few minutes and refresh the page to see the template.', 'warning');
                            this.isLoading = false;
                            this.clearEditTemplateData();
                            this.closeAndReturnToTemplateList();
                        } else {
                            const errorResponse = JSON.parse(result.errorMessage);
                            const errorMsg = errorResponse.error.error_user_msg || errorResponse.error.message || 'Due to unknown error';

                            this.showToast('Template creation failed, reason - ' + errorMsg, 'error');
                            this.isLoading = false;
                        }
                    })
                    .catch(error => {
                        console.error('Error creating template', error);
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

                        this.showToast('Template creation failed: ' + errorMsg, 'error');
                        this.isLoading = false;
                    });

            }


        } catch (error) {
            this.showToast('An unexpected error occurred while submitting the template.', 'error');
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
                this.showToast('Failed to fetch updated templates.', 'error');
            });
    }

    showToast(message, variant = 'info', title = null) {
        this.dispatchEvent(new ShowToastEvent({
            title: title || TOAST_TITLES[variant] || 'Notification',
            message,
            variant
        }));
    }

    closePreview() {
        this.closeAndReturnToTemplateList();
    }

    getButtonPath(iconName) {
        return `${buttonIconsZip}/button-sectionIcons/${iconName}.png`;
    }

    toggleDropdown(event) {
        try {
            event.stopPropagation();
            this.isDropdownOpen = !this.isDropdownOpen;
            this.dropdownClass = this.isDropdownOpen ? 'dropdown-visible' : 'dropdown-hidden';
        } catch(error) {
            console.error('Error in toggleDropdown:', error);
        }
    }

    navigateToAllTemplatePage() {
        let cmpDef = {
            componentDef: 'MVWB:wbAllTemplatePage',

        };

        let encodedDef = btoa(JSON.stringify(cmpDef));
        this[NavigationMixin.Navigate]({
            type: "standard__webPage",
            attributes: {
                url: "/one/one.app#" + encodedDef
            }
        });
    }

    closeAndReturnToTemplateList() {
        try {
            let componentDef = {
                componentDef: "MVEX:wbAllTemplatePage"
            };

            let encodedComponentDef = btoa(JSON.stringify(componentDef));

            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: '/one/one.app#' + encodedComponentDef
                }
            });
        } catch (error) {
            console.error('Error in closeAndReturnToTemplateList: ', error);
        }
    }

    disconnectedCallback() {
        // Use stored bound reference to properly remove the event listener
        if (this._boundHandleOutsideClick) {
            document.removeEventListener('click', this._boundHandleOutsideClick);
            this._boundHandleOutsideClick = null;
        }
    }
}