import { LightningElement, track, api } from 'lwc';
import { loadStyle, loadScript } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import globalStyles from '@salesforce/resourceUrl/globalStyles';
import waJSONFiles from '@salesforce/resourceUrl/waJSONFiles';
import waIcons from '@salesforce/resourceUrl/waIcons';
import createWhatsappTemplate from '@salesforce/apex/WAManageTemplatePageController.createWhatsappTemplate';
import editWhatsappTemplate from '@salesforce/apex/WAManageTemplatePageController.editWhatsappTemplate';
import getObjectFields from '@salesforce/apex/WAManageTemplatePageController.getObjectFields';
import getWhatsAppTemplates from '@salesforce/apex/WAManageTemplatePageController.getWhatsAppTemplates';
import getDynamicObjectData from '@salesforce/apex/WAManageTemplatePageController.getDynamicObjectData';
import uploadFile from '@salesforce/apex/WAManageTemplatePageController.uploadFile';
import deleteFile from '@salesforce/apex/WAManageTemplatePageController.deleteFile';
import getS3ConfigSettings from '@salesforce/apex/ImageAndMediaController.getS3ConfigSettings';
import AWS_SDK from "@salesforce/resourceUrl/AWSSDK";
import buildPayload from './waManageTemplateWrapper';
import getMetaHeaderHandler from '@salesforce/apex/WAManageTemplatePageController.getMetaHeaderHandler';

const TYPE_OPTIONS = [
    { label: 'None', value: 'None' },
    { label: 'Text', value: 'Text' },
    { label: 'Image', value: 'Image' },
    { label: 'Video', value: 'Video' },
    { label: 'Document', value: 'Document' }
];

const TYPE_ACTION_OPTIONS = [
    { label: 'Call Phone Number', value: 'PHONE_NUMBER' },
    { label: 'Visit Website', value: 'URL' }
];

const CUSTOM_OPTIONS = [
    { label: 'Custom', value: 'QUICK_REPLY' },
    { label: 'Marketing opt-out', value: 'Marketing opt-out' }
];

const URL_TYPE_OPTIONS = [
    { label: 'Static', value: 'Static' }
];

const BUTTON_ICON_MAP = {
    'QUICK_REPLY': 'utility:reply',
    'Marketing opt-out': 'utility:reply',
    'PHONE_NUMBER': 'utility:call',
    'URL': 'utility:new_window'
};

const TOAST_TITLES = {
    error: 'Error',
    warning: 'Information',
    success: 'Success',
    info: 'Information'
};

export default class WaManageTemplatePage extends NavigationMixin(LightningElement) {
    LIMITS = {
        maxTempNamelength: 255,
        maxShortlength: 60,
        maxTempBodyLength: 1024,
        maxWebsiteUrl: 2000,
        maxBtnTxt: 25,
        maxPhonetxt: 20
    };
    _edittemplateid;
    _boundHandleOutsideClick;
    _cachedQuickReplyOptions;
    _cachedCallToActionOptions;
    _lastActiveTabForQuickReply;
    file;
    fileName = '';
    fileData;
    fileSize = 0;
    fileType = '';

    dropdownOptions = [
        { title: 'Custom', value: 'QUICK_REPLY', iconName: 'custom', description: 'Quick reply button for customer response' },
        { title: 'Marketing Opt-Out', value: 'Marketing opt-out', iconName: 'marketing', description: 'Opt-out quick reply (Marketing only)' },
        { title: 'Call Phone Number', value: 'PHONE_NUMBER', iconName: 'phone', description: 'Maximum 1 button can be added' },
        { title: 'Visit Website', value: 'URL', iconName: 'site', description: 'Maximum 2 buttons can be added' }
    ];

    contentVersionId;
    isEditTemplate = false;
    totalButtonsCount = 0;
    visitWebsiteCount = 0;
    callPhoneNumber = 0;
    marketingOpt = 0;
    pendingConfirmAction = null;
    _boundHandleBeforeUnload = null;
    _boundHandleKeyDown = null;
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
    isVisitSite = false;
    isCustom = false;
    createButton = false;
    isButtonDisabled = false;
    isStopMarketing = false;
    buttonDisabled = false;
    isLoading = false;
    templateExists = false;
    showEmojis = false;
    isCheckboxChecked = false;
    templateName = '';
    header = '';
    footer = '';
    tempBody = 'Hello';
    formatedTempBody = this.tempBody;
    nextIndex = 1;
    headIndex = 1;
    selectedContentType = 'None';
    selectedLanguage = 'en_US';
    selectedCountryType = '+971';
    selectedCountryTypeLabel = 'United Arab Emirates (+971)';
    phonePattern = '^[0-9]+$';
    phoneErrorMessage = 'Enter a valid phone number';
    originalTemplateName = '';
    originalHeader = '';
    headerHandle = '';
    isfilename = false;
    NoFileSelected = true;
    filePreview = '';
    selectedObject = 'Contact';
    isDropdownOpen = false;
    dropdownClass = 'dropdown-hidden';
    metaTemplateId = '';
    headerError = '';

    /**
     * Returns the video preview icon asset URL.
     */
    get tempVideoIcon() {
        return `${waIcons}/tempVideoIcon.png`;
    }

    /**
     * Returns the image upload placeholder icon asset URL.
     */
    get imageUploadPreview() {
        return `${waIcons}/imageUploadPreview.png`;
    }

    /**
     * Returns the document upload preview icon asset URL.
     */
    get docUploadPreviewImg() {
        return `${waIcons}/documentPreviewIcon.png`;
    }

    /**
     * Returns the fallback icon asset URL when no preview is available.
     */
    get NoPreviewAvailableImg() {
        return `${waIcons}/NoPreviewAvailable.png`;
    }
    isAWSEnabled = false;
    confData;
    s3;
    awsFileName;
    originalContentVersionId = null;
    selectedVariableType = 'Number';

    @track variables = [];
    @track header_variables = [];
    @track countryPhoneMap = {};
    @track countryLabelToCodeMap = {};
    @track countryCodeToLabelMap = {};
    @track buttonList = [];
    @track customButtonList = [];
    @track languageOptions = [];
    @track countryType = [];
    @track availableObjects = [
        { label: 'Contact', value: 'Contact' },
        { label: 'Listing', value: 'MVEX__Listing__c' }
    ];
    @track fields = [];
    @track emojiCategories = [];
    @track allTemplates = [];
    @track bodyVariablePlacementError = '';
    @track bodyVariableFormatError = '';
    @track headerVariableFormatError = '';
    @track selectedFilesToUpload = [];
    @track objectFieldMap = {};

    activeTab = 'Utility';
    selectedOption = 'Custom';
    @track addVar = false;
    @api isTemplateClone = false;

    /**
    * Provides dropdown options for header media and text types.
    */
    get typeOptions() {
        return TYPE_OPTIONS;
    }

    /**
    * Provides button action type options for call-to-action buttons.
    */
    get typeactionOption() {
        return TYPE_ACTION_OPTIONS;
    }

    /**
    * Returns an example placeholder for the template name based on selected category.
    */
    get templateNamePlaceholder() {
        return this.isUtilityCategory ? 'e.g. order_update_v1' : 'e.g. promotional_offer_v1';
    }

    /**
    * Provides button options for quick reply and marketing opt-out actions based on category.
    */
    get customOption() {
        if (this.isUtilityCategory) {
            return CUSTOM_OPTIONS.filter(opt => opt.value === 'QUICK_REPLY');
        }
        return CUSTOM_OPTIONS;
    }

    /**
    * Determines if Meta link tracking consent should be shown (Marketing templates with website buttons).
    */
    get showVisitSiteConsent() {
        return this.isMarketingCategory && this.isVisitSite;
    }

    /**
    * Determines if marketing opt-out responsibility consent is shown.
    */
    get showStopMarketingConsent() {
        return this.isMarketingCategory && this.isStopMarketing;
    }

    /**
    * Provides URL type options for website buttons.
    */
    get urlType() {
        return URL_TYPE_OPTIONS;
    }

    /**
    * Checks if the active template category is Marketing.
    */
    get isMarketingCategory() {
        return (this.activeTab || 'Marketing').toLowerCase() === 'marketing';
    }

    /**
    * Checks if the active template category is Utility.
    */
    get isUtilityCategory() {
        return (this.activeTab || '').toLowerCase() === 'utility';
    }

    /**
    * Determines if category switching is disabled during template edit mode.
    */
    get isCategoryDisabled() {
        return this.isEditTemplate && !this.isTemplateClone;
    }

    /**
    * Computes CSS classes for the Marketing category button.
    */
    get marketingBtnClass() {
        const selected = this.isMarketingCategory ? 'category-segmented-btn active' : 'category-segmented-btn';
        return this.isCategoryDisabled ? `${selected} disabled` : selected;
    }

    /**
    * Computes CSS classes for the Utility category button.
    */
    get utilityBtnClass() {
        const selected = this.isUtilityCategory ? 'category-segmented-btn active' : 'category-segmented-btn';
        return this.isCategoryDisabled ? `${selected} disabled` : selected;
    }

    /**
    * Returns the display label for the currently selected language.
    */
    get selectedLanguageLabel() {
        const selectedOption = this.languageOptions.find(option => option.value === this.selectedLanguage);
        return selectedOption ? selectedOption.label : '';
    }

    /**
    * Returns the maximum allowable phone number length for the selected country.
    */
    get maxtelephonelength() {
        return this.countryPhoneMap[this.selectedCountryType] || 15;
    }

    /**
    * Computes CSS classes for action buttons based on disabled state.
    */
    get buttonClass() {
        return this.isButtonDisabled ? 'select-button disabled' : 'select-button';
    }

    /**
    * Formats header merge variables into placeholder strings for API submission.
    */
    get tempHeaderExample() {
        return this.header_variables.map(varItem => `{{${varItem.field}}}`);
    }

    /**
    * Formats body merge variables into placeholder strings for API submission.
    */
    get templateBodyText() {
        return this.variables.map(varItem => {
            if (varItem.variableType === 'Name' && varItem.nameValue) {
                return varItem.nameValue;
            }
            return `{{${varItem.field}}}`;
        });
    }

    /**
    * Computes display indices and placeholders for body merge variables.
    */
    get computedVariables() {
        return this.variables.map(varItem => {
            const computed = this.computeVariableFields(varItem);
            const isNameType = varItem.variableType === 'Name';

            const displayIndex = isNameType
                ? (varItem.nameValue ? `{{${varItem.nameValue}}}` : `{{}}`)
                : varItem.index;

            const placeholderText = isNameType ? 'Enter example' : 'Enter alternative text';

            return {
                ...varItem,
                ...computed,
                index: displayIndex,
                placeholderText
            };
        });
    }

    /**
    * Computes display indices and placeholders for header merge variables.
    */
    get computedHeaderVariables() {
        return this.header_variables.map(varItem => {
            const computed = this.computeVariableFields(varItem);
            const isNameType = varItem.variableType === 'Name';

            const displayIndex = isNameType
                ? (varItem.nameValue ? `{{${varItem.nameValue}}}` : `{{}}`)
                : varItem.index;

            const placeholderText = isNameType ? 'Enter example' : 'Enter alternative text';

            return {
                ...varItem,
                ...computed,
                index: displayIndex,
                placeholderText
            };
        });
    }

    /**
    * Returns available Salesforce objects tagged with current selection state.
    */
    get availableObjectsWithSelection() {
        let objects = [...this.availableObjects];
        if (this.selectedObject && !objects.some(obj => obj.value === this.selectedObject)) {
            objects.push({ label: this.selectedObject, value: this.selectedObject });
        }
        return objects.map(obj => ({
            ...obj,
            isSelected: obj.value === this.selectedObject
        }));
    }

    /**
    * Evaluates form validity to determine if template submission is disabled.
    */
    get isSubmitDisabled() {
        const areButtonFieldsFilled = this.buttonList.every(button =>
            button.btntext && (button.webURL || button.phonenum)
        );
        const areCustomButtonFilled = this.customButtonList.every(button => button.Cbtntext);
        const hasCustomButtonError = this.customButtonList.some(button => button.hasError);
        const hasButtonListError = this.buttonList.some(button => button.hasError);

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

        return !(this.templateName && this.tempBody && areButtonFieldsFilled && areCustomButtonFilled &&
            !this.templateExists && !hasCustomButtonError && !hasButtonListError &&
            !headerFileNotSelected && !hasHeaderError && !headerTextNotSelected);
    }

    /**
    * Determines whether the template name input is disabled.
    */
    get templateNameDisabled() {
        return this.isEditTemplate && !this.isTemplateClone;
    }

    /**
    * Determines whether the language selection is disabled.
    */
    get isLanguageDisabled() {
        return this.isEditTemplate && !this.isTemplateClone;
    }

    /**
    * Computes and caches dropdown options for quick reply buttons.
    */
    get quickReplyOptions() {
        if (!this._cachedQuickReplyOptions || this._lastActiveTabForQuickReply !== this.activeTab) {
            this._lastActiveTabForQuickReply = this.activeTab;
            this._cachedQuickReplyOptions = this.dropdownOptions
                .filter(option => this.isUtilityCategory ?
                    option.value === 'QUICK_REPLY' :
                    (option.value === 'QUICK_REPLY' || option.value === 'Marketing opt-out'))
                .map(option => ({
                    ...option,
                    iconUrl: this.getButtonPath(option.iconName),
                    classes: `dropdown-item ${option.title.toLowerCase().replace(/\s+/g, '-')}`
                }));
        }
        return this._cachedQuickReplyOptions;
    }

    /**
    * Computes and caches dropdown options for call-to-action buttons.
    */
    get callToActionOptions() {
        if (!this._cachedCallToActionOptions) {
            this._cachedCallToActionOptions = this.dropdownOptions
                .filter(option => ['PHONE_NUMBER', 'URL'].includes(option.value))
                .map(option => ({
                    ...option,
                    iconUrl: this.getButtonPath(option.iconName),
                    classes: `dropdown-item ${option.title.toLowerCase().replace(/\s+/g, '-')}`
                }));
        }
        return this._cachedCallToActionOptions;
    }

    /**
    * Gets the record ID of the template being edited.
    */
    @api
    get edittemplateid() {
        return this._edittemplateid;
    }

    /**
    * Sets the template ID to edit and loads existing template data.
    */
    set edittemplateid(value) {
        this._edittemplateid = value;
        if (this._edittemplateid) {
            this.isEditTemplate = true;
            this.fetchTemplateData();
        }
    }

    /**
    * Initializes component resources, styles, SDKs, event listeners, and initial data.
    */
    connectedCallback() {
        try {
            loadStyle(this, globalStyles);
            loadScript(this, AWS_SDK);
            this.isLoading = true;
            this.iseditTemplatevisible = true;
            this.loadStaticResourceData();

            const apexPromises = [
                this.getS3ConfigDataAsync(),
                this.fetchAllTemplates(false)
            ];

            if (!this.isEditTemplate && !this.isTemplateClone) {
                apexPromises.push(this.loadObjectFields(this.selectedObject));
            }

            Promise.all(apexPromises)
                .catch(error => {
                    console.error('Error in connector initialisation:', error);
                })
                .finally(() => {
                    this.isLoading = false;
                });
        } catch (e) {
            console.error('Error in connectedCallback:', e.message);
        }

        this._boundHandleOutsideClick = this.handleOutsideClick.bind(this);
        document.addEventListener('click', this._boundHandleOutsideClick);

        this._boundHandleBeforeUnload = this.handleBeforeUnload.bind(this);
        this._boundHandleKeyDown = this.handleKeyDown.bind(this);
        window.addEventListener('beforeunload', this._boundHandleBeforeUnload);
        window.addEventListener('keydown', this._boundHandleKeyDown);
    }

    /**
    * Computes field options and selected field label for a merge variable item.
    */
    computeVariableFields(varItem) {
        const fieldOptions = (this.fields && this.fields.length > 0) ? this.fields : (varItem.options || []);
        const selectedField = fieldOptions.find(field => field.value === varItem.field);
        const fieldLabel = varItem.fieldLabel || selectedField?.label || varItem.field || 'Select field';

        let options = fieldOptions.map(field => ({
            label: field.label,
            value: field.value
        }));

        if (varItem.field && !options.some(opt => opt.value === varItem.field)) {
            options = [{ label: fieldLabel, value: varItem.field }, ...options];
        }

        return {
            fieldLabel,
            options
        };
    }

    /**
    * Resets all media selection and preview state flags to false.
    */
    resetMediaFlags() {
        this.isImgSelected = false;
        this.isDocSelected = false;
        this.isVidSelected = false;
        this.isImageFileUploader = false;
        this.isVideoFileUploader = false;
        this.isDocFileUploader = false;
        this.addMedia = false;
        this.isImageFile = false;
        this.isVideoFile = false;
        this.isDocFile = false;
    }

    /**
    * Handles object selection changes and refreshes field options for merge variables.
    */
    async handleObjectChange(event) {
        const selectedObject = event.detail?.value !== undefined ? event.detail.value : event.target.value;
        this.isLoading = true;
        this.selectedObject = selectedObject;

        try {
            const fields = await this.loadObjectFields(selectedObject);
            const firstField = fields[0];

            this.fields = fields;

            if (this.variables.length > 0) {
                this.variables = this.variables.map(varItem => ({
                    ...varItem,
                    object: selectedObject,
                    field: firstField?.value || '',
                    fieldLabel: firstField?.label || 'Select field',
                    options: fields
                }));
                this.formatedTempBody = this.formatText(this.tempBody);
                this.updateTextarea();
            }

            if (this.header_variables.length > 0) {
                this.header_variables = this.header_variables.map(varItem_1 => ({
                    ...varItem_1,
                    object: selectedObject,
                    field: firstField?.value || '',
                    fieldLabel: firstField?.label || 'Select field',
                    options: fields
                }));
            }
        } catch (error) {
            console.error('Error fetching fields: ', error);
        } finally {
            this.isLoading = false;
        }
    }

    /**
    * Maps a button action type to its corresponding utility icon name.
    */
    getButtonIcon(type) {
        return BUTTON_ICON_MAP[type] || 'utility:question';
    }

    /**
    * Retrieves AWS S3 configuration settings from the server.
    */
    getS3ConfigDataAsync() {
        return getS3ConfigSettings()
            .then(result => {
                if (result != null) {
                    this.confData = result.awsConfigData;
                    this.isAWSEnabled = result.isIntegrated;
                }
                return result;
            }).catch(error => {
                console.error('error in getS3ConfigDataAsync -> ', error?.stack || error);
                return null;
            });
    }

    /**
    * Closes dropdown menus and emoji pickers when clicking outside their containers.
    */
    handleOutsideClick(event) {
        const target = event.target;

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

        if (this.isDropdownOpen) {
            const dropdownContainer = this.template.querySelector('.dropdown-container');
            if (dropdownContainer && !dropdownContainer.contains(target)) {
                this.isDropdownOpen = false;
                this.dropdownClass = 'dropdown-hidden';
            }
        }
    }

    /**
    * Handles template category selection changes.
    */
    handleCategorySelect(event) {
        if (this.isCategoryDisabled) {
            return;
        }
        const selected = event.currentTarget.dataset.category;
        if (!selected || selected.toLowerCase() === (this.activeTab || '').toLowerCase()) {
            return;
        }
        this.activeTab = selected;
        this.selectedOption = (selected === 'Marketing') ? 'CustomMarketing' : 'Custom';

        if (this.isUtilityCategory) {
            const hadOptOut = this.customButtonList.some(btn => btn.selectedCustomType === 'Marketing opt-out');
            if (hadOptOut) {
                this.customButtonList = this.customButtonList.filter(btn => btn.selectedCustomType !== 'Marketing opt-out');
                this.marketingOpt = 0;
                this.isStopMarketing = false;
                this.totalButtonsCount = this.buttonList.length + this.customButtonList.length;
                if (this.customButtonList.length === 0) {
                    this.isCustom = false;
                }
                this.showToast('Removed Marketing Opt-Out button as it is prohibited in Utility templates.', 'warning');
            }
        }

        this._cachedQuickReplyOptions = null;
        this._cachedCallToActionOptions = null;
        this.updateButtonDisabledState();
    }

    /**
    * Resolves a user-friendly label for a field API name or path.
    */
    generateFieldLabelFromPath(fieldPath, objectName = null) {
        if (!fieldPath) return 'Select field';
        const fieldList = (objectName && this.objectFieldMap[objectName]) ? this.objectFieldMap[objectName] : this.fields;
        const field = fieldList?.find(f => f.value === fieldPath);
        return field?.label || fieldPath;
    }

    /**
    * Fetches and caches field definitions for a specified Salesforce object.
    */
    async loadObjectFields(objectName) {
        if (!objectName) return [];
        if (this.objectFieldMap[objectName]) {
            const cachedFields = this.objectFieldMap[objectName];
            this.fields = cachedFields;
            this.updateVariablesWithDefaultFields(cachedFields, objectName);
            return cachedFields;
        }

        try {
            const result = await getObjectFields({ objectName: objectName });
            const fields = (result || []).map(f =>
                typeof f === 'string'
                    ? { label: f, value: f }
                    : { label: f.label || f.value, value: f.value }
            );
            fields.sort((a, b) => (a.label || '').localeCompare(b.label || ''));
            this.objectFieldMap[objectName] = fields;
            this.fields = fields;

            this.updateVariablesWithDefaultFields(fields, objectName);

            return fields;
        } catch (error) {
            console.error('Error fetching fields for object ' + objectName, error);
            return [];
        }
    }

    /**
    * Assigns default field values to merge variables that have empty selections.
    */
    updateVariablesWithDefaultFields(fields, objectName) {
        if (!fields || fields.length === 0) return;

        const firstField = fields[0];
        let variablesUpdated = false;

        if (this.variables.length > 0) {
            this.variables = this.variables.map(varItem => {
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
            }
        }

        if (this.header_variables.length > 0) {
            this.header_variables = this.header_variables.map(varItem => {
                if ((!varItem.field || varItem.field === '') && varItem.object === objectName) {
                    return {
                        ...varItem,
                        field: firstField.value || '',
                        fieldLabel: firstField.label || 'Search fields...',
                        options: fields
                    };
                }
                return varItem;
            });
        }
    }

    /**
    * Retrieves existing template details from Apex and populates form fields for editing.
    */
    fetchTemplateData() {
        try {
            getDynamicObjectData({ templateId: this.edittemplateid })
                .then((data) => {
                    const { template, templateVariables } = data;

                    this.activeTab = template.Template_Category__c || template.MVEX__Template_Category__c || 'Utility';
                    this.selectedOption = template.Template_Type__c || template.MVEX__Template_Type__c || (this.activeTab === 'Marketing' ? 'CustomMarketing' : 'Custom');

                    setTimeout(() => {

                        this.templateName = template.Template_Name__c || template.MVEX__Template_Name__c || '';
                        this.originalTemplateName = this.templateName;
                        this.templateName += this.isTemplateClone ? '_clone' : '';
                        this.metaTemplateId = template.Template_Id__c || template.MVEX__Template_Id__c || '';
                        const headerBody = template.Header_Body__c || template.MVEX__WBHeader_Body__c || '';

                        const headerType = template.Header_Type__c || template.MVEX__Header_Type__c || 'None';

                        this.footer = template.Footer_Body__c || template.MVEX__WBFooter_Body__c || '';
                        this.selectedLanguage = template.Language__c || template.MVEX__Language__c;
                        this.languageOptions = this.languageOptions.map(option => ({
                            ...option,
                            isSelected: option.value === this.selectedLanguage
                        }));

                        this.tempBody = template.Template_Body__c || template.MVEX__WBTemplate_Body__c || 'Hello';
                        this.formatedTempBody = this.formatText(this.tempBody);

                        try {
                            const rawMiscData = template.Template_Miscellaneous_Data__c || template.MVEX__Template_Miscellaneous_Data__c;
                            const templateMiscellaneousData = rawMiscData ? JSON.parse(rawMiscData) : null;
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

                            this.isVisitSite = templateMiscellaneousData?.isVisitSite
                            this.isCheckboxChecked = templateMiscellaneousData?.isCheckboxChecked
                            this.awsFileName = templateMiscellaneousData?.awsFileName

                            if (this.awsFileName && !this.isAWSEnabled) {
                                this.showToast('AWS Configration missing.', 'warning');
                            }

                        }
                        catch (error) {
                            console.error('templateMiscellaneousData Error ::: ', error)
                        }

                        const currentHeaderType = template?.Header_Type__c || template?.MVEX__Header_Type__c;
                        const currentHeaderBody = template?.Header_Body__c || template?.MVEX__WBHeader_Body__c;
                        if (currentHeaderType == 'Image' || currentHeaderType == 'Video' || currentHeaderType == 'Document') {
                            const parser = new DOMParser();
                            const doc = parser.parseFromString(currentHeaderBody, "text/html");
                            const mediaUrl = doc.documentElement.textContent || "";
                            this.fileName = template?.File_Name__c || template?.MVEX__File_Name__c;
                            this.fileType = currentHeaderType;
                            this.filePreview = currentHeaderBody;
                            this.headerHandle = template?.Image_Header_Handle__c || template?.Header_Handle__c || template?.MVEX__Header_Handle__c || template?.MVEX__WBImage_Header_Handle__c || '';

                            if ((this.headerHandle == '' || this.headerHandle == null) && this.isEditTemplate == true) {
                                getMetaHeaderHandler({ fileUrlOrContentVersionId: mediaUrl, contentVersionId: this.contentVersionId })
                                    .then((result) => {
                                        if (!result || !result.trim()) {
                                            this.showToast('Header handle missing, please reupload file.', 'warning');
                                        }
                                        this.headerHandle = result
                                    }).catch((error) => {
                                        console.error('Error fetching header handler: ', error);
                                    });
                            }
                        }

                        this.selectedContentType = template.Header_Type__c || template.MVEX__Header_Type__c || 'None';

                        if (this.selectedContentType === 'Text') {
                            this.IsHeaderText = true;
                            this.header = headerBody || '';
                        }

                        const tvs = templateVariables.map(tv => ({
                            object: tv.objName,
                            field: tv.fieldName,
                            alternateText: tv.alternateText ? tv.alternateText : '',
                            id: tv.variable.slice(2, 3),
                            index: tv.variable,
                            type: tv.type
                        }));

                        const uniqueObjects = [...new Set(tvs.map(tv => tv.object))];

                        const bodyVariables = tvs.filter(tv => tv.type === 'Body');
                        if (bodyVariables.length > 0 && bodyVariables[0].object) {
                            this.selectedObject = bodyVariables[0].object;
                        }

                        const fieldFetchPromises = uniqueObjects.map(obj => {
                            return this.objectFieldMap[obj]
                                ? Promise.resolve()
                                : this.loadObjectFields(obj);
                        });

                        Promise.all(fieldFetchPromises)
                            .then(() => {
                                if (this.selectedObject) {
                                    return this.loadObjectFields(this.selectedObject);
                                }
                                return Promise.resolve();
                            })
                            .then(() => {
                                const tempfieldsBody = tvs.filter(tv => tv.type === 'Body').map(tv => tv.field);
                                const tempfieldsHead = tvs.filter(tv => tv.type === 'Header').map(tv => tv.field);

                                this.variables = tvs
                                    .filter(tv => tv.type === 'Body')
                                    .map((variable, index) => {
                                        const objectFields = this.objectFieldMap[variable.object] || [];
                                        const fieldValue = tempfieldsBody[index] || variable.field;

                                        const fieldLabel = this.generateFieldLabelFromPath(fieldValue, variable.object);

                                        return {
                                            ...variable,
                                            field: fieldValue,
                                            fieldLabel: fieldLabel,
                                            variableType: variable.variableType || 'Number',
                                            nameValue: variable.nameValue || variable.alternateText || '',
                                            options: objectFields
                                        };
                                    });

                                this.header_variables = tvs
                                    .filter(tv => tv.type === 'Header')
                                    .map((variable, index) => {
                                        const objectFields = this.objectFieldMap[variable.object] || [];
                                        const fieldValue = tempfieldsHead[index] || variable.field;

                                        const fieldLabel = this.generateFieldLabelFromPath(fieldValue, variable.object);

                                        return {
                                            ...variable,
                                            field: fieldValue,
                                            fieldLabel: fieldLabel,
                                            variableType: variable.variableType || 'Number',
                                            nameValue: variable.nameValue || variable.alternateText || '',
                                            options: objectFields
                                        };
                                    });

                                this.addHeaderVar = this.header_variables.length > 0;
                                this.addVar = this.variables.length > 0;

                                this.isLoading = false;
                            })
                            .catch(error => {
                                console.error('Error while loading field data for editing:', error);
                                this.isLoading = false;
                            });
                        if (this.addHeaderVar) {
                            this.buttonDisabled = true;
                        }
                        const buttonDataRaw = template.Button_Body__c || template.MVEX__WBButton_Body__c;
                        if (buttonDataRaw) {
                            let buttonDataList = JSON.parse(buttonDataRaw);

                            this.buttonList = [];
                            this.customButtonList = [];
                            this.callPhoneNumber = 0;
                            this.visitWebsiteCount = 0;
                            this.marketingOpt = 0;

                            buttonDataList.forEach((button, index) => {
                                if (button.type === 'QUICK_REPLY' || button.type === 'Marketing opt-out') {
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

                                    let parsedPhoneNum = '';
                                    let parsedCountryCode = '';
                                    let parsedCountryLabel = 'India (+91)';

                                    if (button?.type === 'PHONE_NUMBER' && button?.phone_number) {
                                        const phone = button.phone_number;

                                        if (phone.startsWith('+')) {
                                            const countryCodes = Object.keys(this.countryCodeToLabelMap).sort((a, b) => b.length - a.length);
                                            const matchedCode = countryCodes.find(code => phone.startsWith(code));

                                            if (matchedCode) {
                                                parsedCountryCode = matchedCode;
                                                parsedCountryLabel = this.countryCodeToLabelMap[matchedCode] || parsedCountryLabel;
                                                parsedPhoneNum = phone.slice(matchedCode.length).trim();
                                            } else {
                                                parsedPhoneNum = phone;
                                            }
                                        } else {
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

                                    let newButton = {
                                        id: index + 1,
                                        selectedActionType: button?.type || '',
                                        iconName: this.getButtonIcon(button?.type),
                                        btntext: button?.text || '',
                                        webURL: button?.url || '',
                                        phonenum: parsedPhoneNum,
                                        selectedUrlType: button?.type === 'URL' ? 'Static' : '',
                                        selectedCountryType: parsedCountryCode || '+91',
                                        selectedCountryTypeLabel: parsedCountryLabel,
                                        isCallPhone: button?.type === 'PHONE_NUMBER',
                                        isVisitSite: button?.type === 'URL',
                                        hasError: false,
                                        errorMessage: ''
                                    };

                                    this.selectedCountryType = newButton.selectedCountryType;
                                    this.selectedCountryTypeLabel = newButton.selectedCountryTypeLabel;

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
                            this.headerHandle = template.Image_Header_Handle__c || template.MVEX__WBImage_Header_Handle__c;
                            this.NoFileSelected = false;
                            this.isfilename = true;
                            this.fileName = template.File_Name__c || template.MVEX__File_Name__c;
                            this.fileType = (template.Header_Type__c || template.MVEX__Header_Type__c || '').toLowerCase();

                            this.filePreview = headerBody;
                        }
                        else {
                            this.header = headerBody.trim().replace(/^\*\*|\*\*$/g, '');
                        }
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

    /**
    * Validates and processes a selected header media file for upload.
    */
    async handleFileChange(event) {
        try {
            const file = event.target.files[0];

            if (file) {
                const allowedTypeMap = {
                    'Image': { mimes: ['image/png', 'image/jpeg', 'image/jpg'], label: 'JPG or PNG' },
                    'Video': { mimes: ['video/mp4'], label: 'MP4' },
                    'Document': { mimes: ['application/pdf'], label: 'PDF' }
                };

                const typeConfig = allowedTypeMap[this.selectedContentType];
                if (typeConfig && !typeConfig.mimes.includes(file.type)) {
                    this.showToast(
                        `Invalid file type. Please upload a valid ${typeConfig.label} file.`,
                        'error'
                    );
                    event.target.value = '';
                    return;
                }

                this.file = file;
                this.fileName = file.name;
                this.fileType = file.type;
                this.fileSize = file.size;

                let maxSize = 4;
                let isValid = file.size <= maxSize * 1024 * 1024;

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

    /**
    * Configures AWS SDK credentials and region for S3 operations.
    */
    initializeAwsSdk(confData) {
        try {
            let AWS = window?.globalThis?.AWS || window.AWS;

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

    /**
    * Generates a unique timestamped filename for AWS S3 upload.
    */
    renameFileName(filename) {
        try {
            let extensionIndex = filename.lastIndexOf('.');
            let baseFileName = filename.substring(0, extensionIndex);
            let extension = filename.substring(extensionIndex + 1);

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

    /**
    * Uploads selected media files to Amazon S3.
    */
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

    /**
    * Sets preview URLs and flags according to the uploaded media file type.
    */
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

    /**
    * Uploads media file to Salesforce ContentVersion via Apex.
    */
    handleUpload() {
        if (this.fileData) {
            this.isLoading = true;
            uploadFile({ base64Data: this.fileData, fileName: this.fileName })
                .then((result) => {
                    this.contentVersionId = result.contentVersionId;
                    const publicUrl = result.publicUrl;

                    this.generatePreview(publicUrl.replace('/sfc/p/#', '/sfc/p/'));

                    this.uploadFileToMeta();
                })
                .catch((error) => {
                    this.isLoading = false;
                    this.showToast('Error uploading file!', 'error');
                    console.error('Error uploading file - ', error);
                });
        } else {
            this.showToast('Please select a file first!', 'error');

        }
    }

    /**
    * Deletes an uploaded file from Amazon S3 using AWS SDK.
    */
    deleteFileInAWS() {
        try {
            if (this.awsFileName) {
                this.initializeAwsSdk(this.confData);
                const oldKey = this.awsFileName.replace(/\s+/g, "_");
                const bucketName = this.confData.MVEX__S3_Bucket_Name__c;

                this.s3.deleteObject({
                    Bucket: bucketName,
                    Key: oldKey,
                }).promise().then(() => {
                    this.showToast('File deleted successfully', 'success');
                    this.resetFileData();
                }).catch((error) => {
                    console.error('Error while deleting file in AWS: ', error);
                    this.showToast('Error deleting file!', 'error');
                });
            }
        } catch (error) {
            console.error('Error while deleting file in AWS: ', error);
            this.showToast('Error deleting file!', 'error');
        }
    }

    /**
    * Deletes the uploaded media file from AWS S3 or Salesforce ContentVersion.
    */
    handleDelete() {
        const isOriginalFileInEditMode = (this.isEditTemplate || this.isTemplateClone) &&
            this.originalContentVersionId !== null &&
            this.contentVersionId === this.originalContentVersionId;

        if (isOriginalFileInEditMode) {
            this.resetFileData();
            return;
        }

        if (this.isAWSEnabled && this.awsFileName) {
            this.deleteFileInAWS();
        } else if (this.contentVersionId) {
            deleteFile({ contentVersionId: this.contentVersionId })
                .then((result) => {
                    this.showToast('File deleted successfully', 'success');
                    this.resetFileData();
                })
                .catch((error) => {
                    this.showToast('Error deleting file!', 'error');
                });
        } else {
            this.resetFileData();
        }
    }

    /**
    * Resets file upload properties, previews, and file input elements.
    */
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
    * Requests a WhatsApp media header handle from Meta for the uploaded file.
    */
    uploadFileToMeta() {
        try {
            this.isLoading = true;
            if (!this.file && !this.contentVersionId && !this.filePreview) {
                this.isLoading = false;
                this.showToast('Please select a file to upload.', 'error');
                return;
            }

            getMetaHeaderHandler({
                fileUrlOrContentVersionId: this.filePreview || '',
                contentVersionId: this.contentVersionId || ''
            })
                .then(result => {
                    if (result && result.trim()) {
                        this.headerHandle = result;
                        this.isLoading = false;
                        this.showToast('File uploaded successfully.', 'success');
                    } else {
                        this.showToast('Failed to get header handle from Meta.', 'error');
                        this.isLoading = false;
                    }
                })
                .catch(error => {
                    console.error('Failed upload session: ', error);
                    this.isLoading = false;
                    this.showToast(error.body?.message || 'Failed to upload file to Meta.', 'error');
                });
        } catch (error) {
            console.error('Error starting upload session: ', error);
            this.isLoading = false;
        }
    }

    /**
    * Handles header content type selection changes and updates media flags.
    */
    handleContentType(event) {
        try {
            this.NoFileSelected = true;
            this.isfilename = false;
            this.selectedContentType = event.detail?.value !== undefined ? event.detail.value : event.target.value;
            this.IsHeaderText = this.selectedContentType === 'Text';

            this.resetMediaFlags();

            const contentTypeConfig = {
                'Image': { isImageFile: true, isImageFileUploader: true, addMedia: true },
                'Video': { isVideoFile: true, isVideoFileUploader: true, addMedia: true },
                'Document': { isDocFile: true, isDocFileUploader: true, addMedia: true }
            };

            const config = contentTypeConfig[this.selectedContentType];
            if (config) {
                Object.assign(this, config);
            }
        } catch (error) {
            console.error('Something went wrong while selecting content type: ', JSON.stringify(error));
        }
    }

    /**
    * Handles back/cancel button clicks, prompting confirmation if unsaved changes exist.
    * @param {string|Event} destinationOrEvent - Destination identifier ('parent' or 'controlCenter') or DOM click event
    * @returns {boolean} True if handled (either modal shown or cancel executed), false on error
    */
    @api
    handlePrevclick(destinationOrEvent = 'parent') {
        try {
            const destination = (typeof destinationOrEvent === 'string') ? destinationOrEvent : 'parent';
            if (this.hasUnsavedChanges()) {
                this.pendingConfirmAction = destination === 'controlCenter' ? 'cancel_to_control_center' : 'cancel';
                const popup = this.template.querySelector('c-message-popup');
                if (popup) {
                    popup.showMessagePopup({
                        status: 'warning',
                        title: 'Discard Changes?',
                        message: 'This may remove the changes you have done. Are you sure you want to proceed?'
                    });
                    return true;
                }
            }
            this.executeCancel();
            if (destination === 'controlCenter') {
                this.dispatchEvent(new CustomEvent('backtocontrolcenter', {
                    bubbles: true,
                    composed: true
                }));
            }
            return true;
        } catch (error) {
            console.error('Error in handlePrevclick: ', error);
            return false;
        }
    }

    /**
    * Executes cancellation cleanup, deletes temporary files, and returns to template list.
    */
    executeCancel() {
        if (this.contentVersionId != null) {
            this.handleDelete();
        }
        this.clearEditTemplateData();
        this.closeAndReturnToTemplateList();
    }

    /**
    * Resets all template form inputs, variables, buttons, and state properties.
    */
    clearEditTemplateData() {
        try {
            this.templateName = '';
            this.selectedContentType = 'None';
            this.header = '';
            this.addHeaderVar = false;
            this.tempBody = 'Hello';
            this.addVar = false;
            this.footer = '';
            this.buttonList = [];
            this.customButtonList = [];
            this.variables = [];
            this.header_variables = [];
            this.buttonDisabled = false;
            this.originalHeader = '';
            this.nextIndex = 1;
            this.headIndex = 1;
            this.createButton = false;
            this.IsHeaderText = false;
            this.isCustom = false;
            this.formatedTempBody = this.tempBody;
            this.visitWebsiteCount = 0;
            this.callPhoneNumber = 0;
            this.marketingOpt = 0;
            this.addMedia = false;
            this.isDocSelected = false;
            this.isVidSelected = false;
            this.isImgSelected = false;
            this.isDocFile = false;
            this.activeTab = 'Utility';
            this.selectedOption = 'Custom';
            this._cachedQuickReplyOptions = null;
            this._cachedCallToActionOptions = null;

            this.originalContentVersionId = null;
            const headerInput = this.template.querySelector('input[name="header"]');
            if (headerInput) {
                headerInput.value = '';
            }
        } catch (error) {
            console.error('Error in clearEditTemplateData: ', error);
        }
    }

    /**
    * Updates custom button type for an entry in the custom button list.
    */
    handleCustom(event) {
        const index = event.target?.dataset?.index;
        if (index !== undefined && this.customButtonList[index]) {
            this.customButtonList[index].selectedCustomType = event.target.value;
        }
    }

    /**
    * Maps form field names to their specific input change handler functions.
    */
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
            this.updateFormatErrors();
            this.checkBodyVariablePlacement();
            this.syncVariablesFromBody();
        },
        btntext: (value, index) => {
            this.updateButtonProperty(index, 'btntext', value);
            this.validateButtonText(index, value);
        },
        isCheckboxChecked: (value, index, checked) => {
            this.isCheckboxChecked = checked;
        },
        header: (value) => {
            this.header = value;
            const allVariableMatches = (value.match(/\{\{[^}]*\}\}/g) || []).length;
            if (allVariableMatches > 1) {
                this.headerError = 'Only one variable is allowed in the header.';
            } else {
                this.headerError = '';
            }
            this.updateFormatErrors();
            this.syncHeaderVariablesFromText();
        }
    };

    /**
    * Dispatches input change events to their respective field handlers.
    */
    handleInputChange(event) {
        try {
            const name = event.target.name;
            const checked = event.target.checked;
            const dataset = event.target.dataset || {};
            const value = event.detail?.value !== undefined ? event.detail.value : event.target.value;
            const index = dataset.index;

            const buttonFields = ['selectedUrlType', 'webURL', 'selectedCountryTypeLabel', 'phonenum'];
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

            const handler = this.inputChangeHandlers[name];
            if (handler) {
                handler(value, index, checked);
            }
        } catch (error) {
            console.error('Something went wrong: ', error);
        }
    }

    /**
    * Updates a specific property on a button at the specified index.
    */
    updateButtonProperty(index, property, value) {
        this.buttonList[index][property] = value;
    }

    /**
    * Checks if a template with the currently entered name already exists.
    */
    checkTemplateExistence() {
        try {
            if (Array.isArray(this.allTemplates)) {
                this.templateExists = this.allTemplates.some(template => {
                    const tId = template.Template_Id__c || template.MVEX__Template_Id__c;
                    const tName = template.Template_Name__c || template.MVEX__Template_Name__c;
                    if (this.isEditTemplate && !this.isTemplateClone) {
                        const matchesById = tId
                            && this.metaTemplateId
                            && tId === this.metaTemplateId;
                        const matchesByOriginalName = this.originalTemplateName
                            && tName?.toLowerCase() === this.originalTemplateName?.toLowerCase();
                        if (matchesById || matchesByOriginalName) return false;
                    }
                    return tName?.toLowerCase() === this.templateName?.toLowerCase();
                });
            } else {
                console.warn('allTemplates is not an array or is null/undefined');
                this.templateExists = false;
            }
        } catch (error) {
            this.showToast(error.message || 'An error occurred while checking template existence.', 'error');
        }
    }

    /**
    * Removes an action button from the button list and updates button counters.
    */
    handleRemove(event) {
        try {
            const index = event.currentTarget.dataset.index;
            const removedButton = this.buttonList[index];
            if (removedButton && removedButton.isVisitSite) {
                this.visitWebsiteCount--;
            } else if (removedButton && removedButton.isCallPhone) {
                this.callPhoneNumber--;
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

    /**
    * Handles the addition of action or custom buttons from menu selection.
    */
    handleMenuSelect(event) {
        try {
            const selectedValue = event.currentTarget.dataset.value;
            let buttonData = event.currentTarget.dataset.buttonData;

            const isEditMode = buttonData && (buttonData.isCallPhone || buttonData.isVisitSite);

            let newButton = buttonData ? buttonData : {
                id: this.buttonList.length + 1,
                selectedActionType: selectedValue,
                iconName: this.getButtonIcon(selectedValue),
                btntext: '',
                webURL: '',
                phonenum: '',
                selectedUrlType: 'Static',
                selectedCountryType: '',
                selectedCountryTypeLabel: '',
                isCallPhone: false,
                isVisitSite: false,
                hasError: false,
                errorMessage: ''
            };

            let buttonAdded = false;

            switch (selectedValue) {
                case 'QUICK_REPLY':
                    this.isCustom = true;

                    const quickReplyText = buttonData && buttonData.btntext ? buttonData.btntext : 'Quick reply';
                    this.createCustomButton('QUICK_REPLY', quickReplyText);
                    this.isStopMarketing = false;
                    break;
                case 'Marketing opt-out':
                    if (!this.isMarketingCategory) {
                        this.showToast('Marketing opt-out buttons are only permitted in Marketing templates under Meta guidelines.', 'warning');
                        break;
                    }
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

                        if (!isEditMode) {
                            this.callPhoneNumber++;
                        } else {
                            this.callPhoneNumber = 1;
                        }
                        buttonAdded = true;
                    }
                    break;
                case 'URL':
                    if (isEditMode || this.visitWebsiteCount < 2) {
                        this.createButton = true;
                        newButton.isVisitSite = true;
                        this.isVisitSite = true;
                        newButton.btntext = buttonData?.btntext || 'Visit Website';

                        if (!isEditMode) {
                            this.visitWebsiteCount++;
                        } else {
                            const existingUrlCount = this.buttonList.filter(b => b.isVisitSite).length;
                            this.visitWebsiteCount = existingUrlCount + 1;
                        }
                        buttonAdded = true;
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
                if (buttonAdded) {
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

    /**
    * Validates button labels for duplicates and sets error flags across buttons.
    */
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

    /**
    * Creates and adds a new custom or marketing opt-out button.
    */
    createCustomButton(btnType, btnText) {
        try {
            const btnTextExists = this.customButtonList.some(button => button.Cbtntext === btnText);

            let newCustomButton = {
                id: this.customButtonList.length + 1,
                selectedCustomType: btnType,
                Cbtntext: btnText,
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

    /**
    * Updates custom button type for an entry in the custom button list.
    */
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

            this.updateButtonErrors(true);
        } catch (error) {
            console.error('Error while handling the custom text.', error);
        }
    }

    /**
    * Removes an action button from the button list and updates button counters.
    */
    handleRemoveCustom(event) {
        try {
            const index = event.currentTarget.dataset.index;
            const removedButton = this.customButtonList[index];

            if (removedButton && removedButton.showFooterText) {
                this.marketingOpt--;
                if (this.marketingOpt <= 0) {
                    this.marketingOpt = 0;
                    this.isStopMarketing = false;
                }
            }
            this.customButtonList = this.customButtonList.filter((_, i) => i !== parseInt(index));
            if (this.customButtonList.length === 0) {
                this.isCustom = false;
            }

            this.totalButtonsCount--;

            this.customButtonList = [...this.customButtonList];
            this.updateButtonDisabledState();
        } catch (error) {
            console.error('Error while removing custom buttons.', error);
        }
    }

    /**
    * Updates button creation disabled state based on the total button count limit.
    */
    updateButtonDisabledState() {
        this.isDropdownOpen = false;
        this.isButtonDisabled = this.totalButtonsCount >= 10;
    }

    /**
    * Appends a new merge variable to the body variables list and inserts placeholder in text.
    */
    addvariable() {
        try {
            this.addVar = true;
            const maxId = this.variables.reduce((max, variable) => {
                return Math.max(max, parseInt(variable.id));
            }, 0);

            this.nextIndex = maxId + 1;
            const defaultField = this.fields[0]?.value || '';
            const defaultFieldLabel = this.fields[0]?.label || 'Select Field';

            const currentVariableType = this.selectedVariableType || 'Name';

            const displayIndex = currentVariableType === 'Name' ? `{{}}` : `{{${this.nextIndex}}}`;

            const newVariable = {
                id: this.nextIndex,
                object: this.selectedObject,
                field: defaultField,
                fieldLabel: defaultFieldLabel,
                alternateText: '',
                variableType: currentVariableType,
                nameValue: '',
                index: displayIndex,
                options: this.fields
            };

            this.variables = [...this.variables, newVariable];

            const placeholderToAdd = currentVariableType === 'Name' ? '{{}}' : `{{${this.nextIndex}}}`;
            this.tempBody = `${this.tempBody} ${placeholderToAdd} `;
            this.formatedTempBody = this.formatText(this.tempBody);
            this.updateTextarea();
            this.checkBodyVariablePlacement();
            this.nextIndex++;
        } catch (error) {
            console.error('Error in adding variables.', error);
        }
    }

    /**
    * Updates the selected merge field for a body variable.
    */
    handleVarFieldChange(event) {
        try {
            const variableIndex = String(event.currentTarget?.dataset?.index || event.target?.dataset?.index || '');
            const variableId = String(event.currentTarget?.dataset?.id || event.target?.dataset?.id || '');
            const fieldName = event.detail?.value !== undefined ? event.detail.value : event.target.value;
            const selectedOption = this.fields?.find(f => f.value === fieldName);
            const fieldLabel = selectedOption?.label || fieldName;

            this.variables = this.variables.map((varItem) => {
                const matchIndex = variableIndex && (String(varItem.index) === variableIndex || `{{${varItem.index}}}` === variableIndex);
                const matchId = variableId && String(varItem.id) === variableId;
                if (matchId || matchIndex) {
                    return {
                        ...varItem,
                        field: fieldName,
                        fieldLabel: fieldLabel
                    };
                }
                return varItem;
            });
            this.formatedTempBody = this.formatText(this.tempBody);
        } catch (error) {
            console.error('Something went wrong while updating variable field.', error);
        }
    }

    /**
    * Validates syntax and format of merge variable placeholders in text.
    */
    validateVariableFormat(text, variableType, strictMode = false) {
        if (!text) {
            return { isValid: true, errorMessage: '' };
        }

        const allVariables = text.match(/\{\{([^}]*)\}\}/g) || [];

        if (allVariables.length === 0) {
            return { isValid: true, errorMessage: '' };
        }

        if (strictMode) {
            const hasEmptyVars = allVariables.some(v => v === '{{}}');
            if (hasEmptyVars) {
                return {
                    isValid: false,
                    errorMessage: 'Variable parameters cannot be empty. Please provide a name for all variables).'
                };
            }
        }

        if (variableType === 'Number') {
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
    * Updates format error messages for header and body variables.
    */
    updateFormatErrors() {
        const bodyValidation = this.validateVariableFormat(this.tempBody, this.selectedVariableType);
        this.bodyVariableFormatError = bodyValidation.isValid ? '' : bodyValidation.errorMessage;

        const headerValidation = this.validateVariableFormat(this.header, this.selectedVariableType);
        this.headerVariableFormatError = headerValidation.isValid ? '' : headerValidation.errorMessage;
    }

    /**
    * Synchronizes body variable definitions by parsing placeholders from body text.
    */
    syncVariablesFromBody() {
        try {
            const variablePattern = /\{\{([^}]*)\}\}/g;
            const matches = [...this.tempBody.matchAll(variablePattern)];

            if (matches.length === 0) {
                this.variables = [];
                this.addVar = false;
                return;
            }

            const bodyVariables = matches.map((match, idx) => ({
                position: idx,
                content: match[1].trim(),
                fullMatch: match[0]
            }));

            const isNameType = this.selectedVariableType === 'Name';
            const defaultField = this.fields[0]?.value || '';
            const defaultFieldLabel = this.fields[0]?.label || 'Select Field';

            const updatedVariables = bodyVariables.map((bodyVar, idx) => {
                const existingVar = this.variables[idx];

                if (existingVar) {
                    if (isNameType) {
                        return {
                            ...existingVar,
                            nameValue: bodyVar.content,
                            index: bodyVar.content ? `{{${bodyVar.content}}}` : `{{}}`
                        };
                    } else {
                        return {
                            ...existingVar,
                            index: `{{${bodyVar.content}}}`
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
                        nameValue: isNameType ? bodyVar.content : '',
                        index: bodyVar.content ? `{{${bodyVar.content}}}` : `{{}}`,
                        options: this.fields
                    };
                }
            });

            this.variables = updatedVariables;

            if (this.variables.length > 0) {
                this.addVar = true;
            }
        } catch (error) {
            console.error('Error syncing variables from body:', error);
        }
    }

    /**
    * Synchronizes header variable definitions by parsing placeholders from header text.
    */
    syncHeaderVariablesFromText() {
        try {
            if (!this.header) {
                return;
            }

            const variablePattern = /\{\{([^}]*)\}\}/g;
            const matches = [...this.header.matchAll(variablePattern)];

            if (matches.length === 0) {
                this.header_variables = [];
                this.addHeaderVar = false;
                return;
            }

            const isNameType = this.selectedVariableType === 'Name';
            const defaultField = this.fields[0]?.value || '';
            const defaultFieldLabel = this.fields[0]?.label || 'Select Field';

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

            if (this.header_variables.length > 0) {
                this.addHeaderVar = true;
            }
        } catch (error) {
            console.error('Error syncing header variables from text:', error);
        }
    }

    /**
    * Updates fallback text for a body merge variable.
    */
    handleAlternateVarChange(event) {
        const variableIndex = String(event.target.dataset.index);
        const alternateText = event.target.value.trim();

        this.variables = this.variables.map(varItem =>
            String(varItem.index) === variableIndex
                ? { ...varItem, alternateText }
                : varItem
        );
    }

    /**
    * Synchronizes the body textarea DOM value with component state and focuses it.
    */
    updateTextarea() {
        const textarea = this.template.querySelector('textarea');
        if (textarea) {
            textarea.value = this.tempBody;
        }
        textarea.focus();
    }

    /**
    * Removes a merge variable from body text and re-indexes remaining variables.
    */
    handleVarRemove(event) {
        try {
            const index = event.currentTarget.dataset.index;
            const varToRemove = this.variables[parseInt(index)];

            if (this.selectedVariableType === 'Name') {
                const variableToRemove = varToRemove.nameValue
                    ? `{{${varToRemove.nameValue}}}`
                    : `{{}}`;
                let updatedTempBody = this.tempBody.replace(variableToRemove, '');
                this.variables = this.variables.filter((_, i) => i !== parseInt(index));

                this.variables = this.variables.map((varItem, idx) => ({
                    ...varItem,
                    id: idx + 1
                }));

                this.tempBody = updatedTempBody.trim();
                this.formatedTempBody = this.formatText(this.tempBody);

                this.syncVariablesFromBody();
            } else {
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
                this.formatedTempBody = this.formatText(this.tempBody);
            }

            this.nextIndex = this.variables.length + 1;
            if (this.variables.length === 0) {
                this.addVar = false;
                this.nextIndex = 1;
            }
            this.updateTextarea();
            this.checkBodyVariablePlacement();
        } catch (error) {
            console.error('Something wrong while removing the variable.', error);
        }
    }

    /**
    * Adds a merge variable placeholder to header text and appends to header variables.
    */
    addheadervariable() {
        try {
            this.addHeaderVar = true;
            const defaultField = this.fields[0]?.value || '';
            const defaultFieldLabel = this.fields[0]?.label || 'Search fields...';

            const currentVariableType = this.selectedVariableType || 'Name';
            const isNameType = currentVariableType === 'Name';

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

            this.originalHeader = (this.originalHeader || this.header || '') + ` ${placeholderToAdd}`;
            this.header = this.originalHeader;
            this.headIndex++;
            this.buttonDisabled = true;
        } catch (error) {
            console.error('Error in adding header variables.', error);
        }
    }

    /**
    * Updates the selected merge field for a header variable.
    */
    handleFieldChange(event) {
        try {
            const variableId = String(event.currentTarget?.dataset?.id || event.target?.dataset?.id || '');
            const fieldName = event.detail?.value !== undefined ? event.detail.value : event.target.value;
            const selectedOption = this.fields?.find(f => f.value === fieldName);
            const fieldLabel = selectedOption?.label || fieldName;

            this.header_variables = this.header_variables.map(varItem =>
                String(varItem.id) === variableId
                    ? {
                        ...varItem,
                        field: fieldName,
                        fieldLabel: fieldLabel
                    }
                    : varItem
            );
        } catch (error) {
            console.error('Something wrong while header variable input.', error);
        }
    }

    /**
    * Updates fallback text for a header merge variable.
    */
    handleAlternateTextChange(event) {
        const variableId = String(event.target.dataset.id);
        const alternateText = event.target.value.trim();

        this.header_variables = this.header_variables.map(varItem =>
            String(varItem.id) === variableId
                ? { ...varItem, alternateText }
                : varItem
        );
    }

    /**
    * Removes a merge variable from header text and re-indexes remaining header variables.
    */
    handleHeaderVarRemove(event) {
        try {
            const index = event.currentTarget.dataset.index;
            const varToRemove = this.header_variables[parseInt(index)];
            const isNameType = this.selectedVariableType === 'Name';

            let updatedHeader = this.header;

            if (isNameType) {
                const variableToRemove = varToRemove.nameValue
                    ? `{{${varToRemove.nameValue}}}`
                    : `{{}}`;
                updatedHeader = this.header.replace(variableToRemove, '');
            } else {
                const varIndexToRemove = parseInt(index, 10) + 1;
                const variableToRemove = `{{${varIndexToRemove}}}`;
                updatedHeader = this.header.replace(variableToRemove, '');
            }

            this.header_variables = this.header_variables.filter((_, i) => i !== parseInt(index));

            if (isNameType) {
                this.header_variables = this.header_variables.map((varItem, idx) => ({
                    ...varItem,
                    id: idx + 1
                }));
            } else {
                this.header_variables = this.header_variables.map((varItem, idx) => {
                    const newIndex = idx + 1;
                    return {
                        ...varItem,
                        id: newIndex,
                        index: `{{${newIndex}}}`
                    };
                });

                let placeholders = updatedHeader.match(/\{\{\d+\}\}/g) || [];
                placeholders.forEach((placeholder, idx) => {
                    const newIndex = `{{${idx + 1}}}`;
                    updatedHeader = updatedHeader.replace(placeholder, newIndex);
                });
            }

            this.header = updatedHeader.trim();
            this.originalHeader = this.header;
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

    /**
    * Loads emoji categories, country phone data, and supported languages.
    */
    async loadStaticResourceData() {
        const fetchJson = async (fileName) => {
            try {
                const res = await fetch(`${waJSONFiles}/${fileName}`);
                const okRes = res.ok ? res : await fetch(`${waJSONFiles}/${fileName.replace(/\.json$/, '')}`);
                return await okRes.json();
            } catch (error) {
                console.error(`Error loading ${fileName}:`, error);
                return null;
            }
        };

        const [emojiData, countryData, languageData] = await Promise.all([
            fetchJson('whatsapp-emojis.json'),
            fetchJson('CountryPhoneLengths.json'),
            fetchJson('LanguageJson.json')
        ]);

        if (emojiData) {
            this.emojiCategories = Object.values(
                emojiData.reduce((acc, item) => {
                    const category = item.category;
                    if (!acc[category]) {
                        acc[category] = { category, emojis: [] };
                    }
                    acc[category].emojis.push(item);
                    return acc;
                }, {})
            );
        }

        if (countryData) {
            this.countryType = countryData.map(item => ({
                label: item?.label,
                value: item?.label
            }));
            countryData.forEach(item => {
                this.countryLabelToCodeMap[item?.label] = item?.code;
                this.countryCodeToLabelMap[item?.code] = item?.label;
                this.countryPhoneMap[item?.code] = item.lengths;
            });
            this.updatePhonePattern(this.selectedCountryType);
        }

        if (languageData) {
            this.languageOptions = languageData.map(lang => ({
                label: `${lang.language}`,
                value: lang.code,
                isSelected: lang.code === this.selectedLanguage
            }));
            if (!this.languageOptions.some(option => option.isSelected)) {
                this.selectedLanguage = this.languageOptions[0]?.value || '';
                if (this.languageOptions[0]) {
                    this.languageOptions[0].isSelected = true;
                }
            }
        }
    }

    /**
    * Updates phone validation regex pattern and error message for the selected country.
    */
    updatePhonePattern(code) {
        const validLengths = this.countryPhoneMap[code];
        if (validLengths && validLengths.length > 0) {
            const lengths = validLengths.join('|');
            this.phonePattern = `^\\d{${lengths.replace(/,/g, '}$|^\\d{')}}$`;
            this.phoneErrorMessage = `Phone number must be ${validLengths.join(' or ')} digits long.`;
        } else {
            this.phonePattern = '^\\d+$';
            this.phoneErrorMessage = 'Enter a valid phone number';
        }
    }

    /**
    * Toggles visibility of the emoji picker popup.
    */
    handleEmoji(event) {
        event.stopPropagation();
        this.showEmojis = !this.showEmojis;
    }

    /**
    * Toggles visibility of the emoji picker popup.
    */
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

    /**
    * Applies WhatsApp text formatting markers around selected text in body.
    */
    handleFormat(event) {
        try {
            const button = event.target.closest('button');
            const formatType = button.dataset.format;

            const textarea = this.template.querySelector('textarea');
            const selStart = textarea.selectionStart;
            const selEnd = textarea.selectionEnd;
            const currentText = textarea.value;

            const markerMap = {
                'Bold': '*',
                'Italic': '_',
                'Strikethrough': '~',
                'Code': '```'
            };

            const marker = markerMap[formatType];
            if (!marker) return;

            const selectedText = currentText.slice(selStart, selEnd);
            const wrapped = marker + selectedText + marker;
            const newText = currentText.slice(0, selStart) + wrapped + currentText.slice(selEnd);

            this.tempBody = newText;
            this.formatedTempBody = this.formatText(newText);

            const newSelStart = selStart + marker.length;
            const newSelEnd = newSelStart + selectedText.length;
            this.updateCursorRange(newSelStart, newSelEnd);
        } catch (error) {
            console.error('Something wrong while handling rich text.', error);
        }
    }

    /**
    * Converts WhatsApp text markdown formatting into HTML tags for preview display.
    */
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

    /**
    * Restores cursor position and text selection range in body textarea.
    */
    updateCursorRange(selStart, selEnd) {
        const textarea = this.template.querySelector('textarea');
        textarea.value = this.tempBody;
        textarea.focus();
        textarea.selectionStart = selStart;
        textarea.selectionEnd = selEnd;
    }

    /**
    * Performs comprehensive validation of template fields, variables, and buttons.
    */
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

            if (this.checkBodyVariablePlacement()) {
                this.showToast(this.bodyVariablePlacementError, 'error');
                return false;
            }

            if (this.tempBody) {
                const varMatches = [...this.tempBody.matchAll(/\{\{(\d+)\}\}/g)].map(m => parseInt(m[1], 10));
                if (varMatches.length > 0) {
                    const uniqueSorted = [...new Set(varMatches)].sort((a, b) => a - b);
                    for (let i = 0; i < uniqueSorted.length; i++) {
                        if (uniqueSorted[i] !== i + 1) {
                            this.showToast(`Body variables must be numbered sequentially starting from {{1}}. Expected {{${i + 1}}} but found {{${uniqueSorted[i]}}}.`, 'error');
                            return false;
                        }
                    }
                }
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
                }

                if (button.isCustom) {
                    if (!button.Cbtntext || button.Cbtntext.trim() === '') {
                        this.showToast('Button text is required for the custom button', 'error');
                        return false;
                    }
                }
            }

            if (this.isUtilityCategory) {
                const hasMarketingOptOut = this.customButtonList.some(btn => btn.selectedCustomType === 'Marketing opt-out');
                if (hasMarketingOptOut) {
                    this.showToast('Marketing opt-out buttons are not allowed in Utility templates according to Meta guidelines.', 'error');
                    return false;
                }
            }
            return true;
        } catch (error) {
            console.error('Something went wrong while validating template.', error);
            return false;
        }

    }

    /**
    * Validates website URL format using a regular expression.
    */
    validateUrl(value) {
        const urlPattern = new RegExp(
            '^(https?:\\/\\/)?(www\\.)?([a-zA-Z0-9-]+\\.)+[a-zA-Z]{2,6}($|\\/.*)$'
        );
        const isValid = urlPattern.test(value);
        return isValid;
    }

    /**
    * Validates phone number format to ensure valid numeric input.
    */
    validatePhoneNumber(value) {
        const phonePattern = /^[0-9]{10,}$/;
        return phonePattern.test(value);
    }

    /**
    * Checks body variable placement rules including boundaries, spacing, and word ratio.
    */
    checkBodyVariablePlacement() {
        if (!this.tempBody || this.tempBody.trim() === '') {
            this.bodyVariablePlacementError = '';
            return false;
        }

        const errors = [];

        const normalizedBody = this.tempBody.replace(/\s+/g, ' ').trim();

        const variablePattern = this.selectedVariableType === 'Name' ? /\{\{[^}]*\}\}/ : /\{\{\d+\}\}/;

        const startsWithVariable = new RegExp(`^${variablePattern.source}`).test(normalizedBody);
        const endsWithVariable = new RegExp(`${variablePattern.source}$`).test(normalizedBody);

        const backToBackPattern = this.selectedVariableType === 'Name'
            ? /\{\{[^}]*\}\}\{\{[^}]*\}\}/
            : /\{\{\d+\}\}\{\{\d+\}\}/;
        const hasBackToBackVariables = backToBackPattern.test(normalizedBody);

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

        if (this.selectedVariableType !== 'Name') {
            const sequenceError = this.checkBodyVariableSequence(normalizedBody);
            if (sequenceError) {
                errors.push(sequenceError);
            }
        }

        const variableWordRatioError = this.checkVariableToWordRatio(normalizedBody);
        if (variableWordRatioError) {
            errors.push(variableWordRatioError);
        }

        if (errors.length > 0) {
            this.bodyVariablePlacementError = errors.join('. ');
            return true;
        }

        this.bodyVariablePlacementError = '';
        return false;
    }

    /**
    * Validates that template body contains sufficient text relative to variable count.
    */
    checkVariableToWordRatio(body) {
        const numberedVarMatches = body.match(/\{\{\d+\}\}/g) || [];
        const namedVarMatches = body.match(/\{\{[^}]*\}\}/g) || [];

        const variableCount = this.selectedVariableType === 'Name'
            ? namedVarMatches.length
            : numberedVarMatches.length;

        if (variableCount === 0) {
            return null;
        }

        const textWithoutVariables = body.replace(/\{\{[^}]*\}\}/g, ' ').trim();

        const nonVariableWords = textWithoutVariables.split(/\s+/).filter(word => word.length > 0);
        const nonVariableWordCount = nonVariableWords.length;

        const requiredMinWords = (2 * variableCount) + 1;

        if (nonVariableWordCount < requiredMinWords) {
            return `This template has too many variables for its length. Reduce the number of variables or increase the message length.`;
        }

        return null;
    }

    /**
    * Verifies that numbered body variables follow a contiguous sequence from 1.
    */
    checkBodyVariableSequence(body) {
        if (this.selectedVariableType === 'Name') {
            return null;
        }

        const variableNumbers = new Set();
        const variablePattern = /\{\{(\d+)\}\}/g;
        let match;

        while ((match = variablePattern.exec(body)) !== null) {
            variableNumbers.add(parseInt(match[1], 10));
        }

        if (variableNumbers.size === 0) return null;

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

    /**
    * Validates button label for duplicates across action buttons.
    */
    validateButtonText(index, newValue) {
        const isDuplicate = this.buttonList.some((button, idx) => button.btntext === newValue && idx !== parseInt(index));

        if (index === 0) {
            this.buttonList[index].hasError = false;
            this.buttonList[index].errorMessage = '';
        } else {
            this.buttonList[index].hasError = isDuplicate;
            this.buttonList[index].errorMessage = isDuplicate ? 'You have entered the same text for multiple buttons.' : '';
        }

        this.updateButtonErrors();
    }

    /**
    * Validates template variables and opens the review template preview modal.
    */
    handleConfirm() {
        const bodyFormatValidation = this.validateVariableFormat(this.tempBody, this.selectedVariableType, true);
        if (!bodyFormatValidation.isValid) {
            this.showToast(bodyFormatValidation.errorMessage, 'error');
            return;
        }

        if (this.header) {
            const headerFormatValidation = this.validateVariableFormat(this.header, this.selectedVariableType, true);
            if (!headerFormatValidation.isValid) {
                this.showToast(headerFormatValidation.errorMessage, 'error');
                return;
            }
        }

        const headerMissingAlt = this.header_variables.some(varItem => {
            return !varItem.alternateText || varItem.alternateText.trim() === '';
        });

        const bodyMissingValue = this.variables.some(varItem => {
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

    /**
    * Closes the review template modal and returns to the editor.
    */
    handleCloseTemplate() {
        this.showReviewTemplate = false;
        this.iseditTemplatevisible = true;
        this.isLoading = false;
    }

    /**
    * Builds payload and submits create or edit request to Apex.
    */
    handleSubmit() {
        try {
            if (this.isMarketingCategory && !this.isCheckboxChecked && this.visitWebsiteCount > 0) {
                this.showToast('Please select check-box to report website clicks.', 'error');
                return;
            }

            this.isLoading = true;
            this.showReviewTemplate = false;
            if (!this.validateTemplate()) {
                this.isLoading = false;
                return;
            }

            const buttonData = [];

            if (this.buttonList && this.buttonList.length > 0) {
                buttonData.push(...this.buttonList);
            }

            if (this.customButtonList && this.customButtonList.length > 0) {
                buttonData.push(...this.customButtonList);
            }

            let marketingOptText = null;
            if (this.customButtonList && this.customButtonList.length > 0) {
                const marketingOptButton = this.customButtonList.find(btn => btn.selectedCustomType === 'Marketing opt-out');
                if (marketingOptButton) {
                    marketingOptText = marketingOptButton.Cbtntext;
                }
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
                isVisitSite: this.isVisitSite,
                isCheckboxChecked: this.isCheckboxChecked,
                awsFileName: this.awsFileName
            };

            const template = {
                templateName: this.templateName || null,
                templateCategory: this.activeTab || null,
                templateType: this.selectedOption || null,
                tempLanguage: this.selectedLanguage || null,

                tempHeaderFormat: this.selectedContentType || null,
                tempHeaderHandle: this.headerHandle || null,
                tempHeaderText: this.header || '',
                tempHeaderExample: (this.tempHeaderExample && this.tempHeaderExample.length > 0) ? this.tempHeaderExample : null,

                tempImgUrl: this.filePreview || null,
                tempImgId: this.contentVersionId || null,
                tempImgName: this.fileName || null,

                templateBody: this.tempBody || '',
                templateBodyText: (this.templateBodyText && this.templateBodyText.length > 0) ? this.templateBodyText : null,

                tempFooterText: this.footer || null,

                typeOfButton: buttonData.length > 0 ? JSON.stringify(buttonData) : null,
                marketingOptText: marketingOptText,

                templateMiscellaneousData: templateMiscellaneousData ? JSON.stringify(templateMiscellaneousData) : null,

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
                selectedVariableType: this.selectedVariableType || 'Name'
            };
            const serializedWrapper = JSON.stringify(template);
            const payload = JSON.stringify(buildPayload(template));

            if (this.metaTemplateId && this.metaTemplateId !== 'DRAFT' && !this.isTemplateClone) {
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
                            this.clearEditTemplateData();
                            this.closeAndReturnToTemplateList();
                        } else {
                            let errorMsg = result ? (result.message || result.errorMessage) : 'Due to unknown error';
                            if (result && result.errorMessage) {
                                try {
                                    const errorResponse = JSON.parse(result.errorMessage);
                                    if (errorResponse && errorResponse.error) {
                                        errorMsg = errorResponse.error.error_user_msg || errorResponse.error.message || errorMsg;
                                    }
                                } catch (e) {
                                }
                            }

                            this.showToast('Template update failed: ' + errorMsg, 'error');
                            this.isLoading = false;
                        }
                    }).catch(error => {
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
                    }).catch(error => {
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

    /**
    * Fetches all WhatsApp templates and optionally dispatches an update event.
    */
    fetchAllTemplates(dispatchEvent = true) {
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

    /**
    * Dispatches a toast notification event to the platform.
    */
    showToast(message, variant = 'info', title = null) {
        this.dispatchEvent(new ShowToastEvent({
            title: title || TOAST_TITLES[variant] || 'Notification',
            message,
            variant
        }));
    }

    /**
    * Returns the full static resource URL for a specified button icon asset.
    */
    getButtonPath(iconName) {
        return `${waIcons}/${iconName}.png`;
    }

    /**
    * Toggles visibility of the button type selection dropdown menu.
    */
    toggleDropdown(event) {
        try {
            event.stopPropagation();
            this.isDropdownOpen = !this.isDropdownOpen;
            this.dropdownClass = this.isDropdownOpen ? 'dropdown-visible' : 'dropdown-hidden';
        } catch (error) {
            console.error('Error in toggleDropdown:', error);
        }
    }

    /**
    * Dispatches events to close the template manager and navigate back to list.
    */
    closeAndReturnToTemplateList() {
        try {
            this.dispatchEvent(new CustomEvent('closetemplatemanager', {
                bubbles: true,
                composed: true
            }));
            this.dispatchEvent(new CustomEvent('previous', {
                bubbles: true,
                composed: true,
                detail: {
                    activeTab: this.activeTab
                }
            }));
        } catch (error) {
            console.error('Error in closeAndReturnToTemplateList: ', error);
        }
    }

    /**
    * Determines whether any unsaved changes exist in the template form.
    */
    @api
    hasUnsavedChanges() {
        if (!this.iseditTemplatevisible) {
            return false;
        }
        return Boolean(this.templateName) ||
            (this.tempBody && this.tempBody !== 'Hello') ||
            Boolean(this.header) ||
            Boolean(this.footer) ||
            (this.buttonList && this.buttonList.length > 0) ||
            (this.customButtonList && this.customButtonList.length > 0) ||
            Boolean(this.contentVersionId) ||
            this.isEditTemplate;
    }

    /**
    * Prompts browser confirmation dialog when attempting to leave with unsaved changes.
    */
    handleBeforeUnload(event) {
        if (this.hasUnsavedChanges()) {
            event.preventDefault();
            event.returnValue = 'This may remove the changes you have done.';
            return event.returnValue;
        }
    }

    /**
    * Intercepts browser refresh shortcuts to prevent losing unsaved changes.
    */
    handleKeyDown(event) {
        const isRefreshKey = event.key === 'F5' ||
            ((event.ctrlKey || event.metaKey) && (event.key === 'r' || event.key === 'R'));
        if (isRefreshKey && this.hasUnsavedChanges()) {
            event.preventDefault();
            this.pendingConfirmAction = 'refresh';
            const popup = this.template.querySelector('c-message-popup');
            if (popup) {
                popup.showMessagePopup({
                    status: 'warning',
                    title: 'Discard Changes?',
                    message: 'This may remove the changes you have done. Are you sure you want to refresh?'
                });
            }
        }
    }

    /**
    * Handles modal confirmation result for discarding changes, navigating, or refreshing.
    */
    handleConfirmation(event) {
        const isConfirmed = event.detail === true;
        const action = this.pendingConfirmAction;
        this.pendingConfirmAction = null;

        if (!isConfirmed) {
            return;
        }

        if (action === 'cancel') {
            this.executeCancel();
        } else if (action === 'cancel_to_control_center') {
            this.executeCancel();
            this.dispatchEvent(new CustomEvent('backtocontrolcenter', {
                bubbles: true,
                composed: true
            }));
        } else if (action === 'refresh') {
            window.location.reload();
        }
    }

    /**
    * Removes global document and window event listeners when component is destroyed.
    */
    disconnectedCallback() {
        if (this._boundHandleOutsideClick) {
            document.removeEventListener('click', this._boundHandleOutsideClick);
            this._boundHandleOutsideClick = null;
        }
        if (this._boundHandleBeforeUnload) {
            window.removeEventListener('beforeunload', this._boundHandleBeforeUnload);
            this._boundHandleBeforeUnload = null;
        }
        if (this._boundHandleKeyDown) {
            window.removeEventListener('keydown', this._boundHandleKeyDown);
            this._boundHandleKeyDown = null;
        }
    }
}