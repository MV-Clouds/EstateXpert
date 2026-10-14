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

const LIMITS = {
    maxTempNamelength: 255,
    maxShortlength: 60,
    maxTempBodyLength: 1024,
    maxWebsiteUrl: 2000,
    maxBtnTxt: 25,
    maxPhonetxt: 20
};

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


const ALLOWED_MEDIA_TYPES = {
    'Image': { mimes: ['image/png', 'image/jpeg', 'image/jpg'], label: 'JPG or PNG' },
    'Video': { mimes: ['video/mp4'], label: 'MP4' },
    'Document': { mimes: ['application/pdf'], label: 'PDF' }
};

export default class WaManageTemplatePage extends NavigationMixin(LightningElement) {
    LIMITS = LIMITS;
    typeOptions = TYPE_OPTIONS;
    typeactionOption = TYPE_ACTION_OPTIONS;

    // Assets directly exposed as properties
    tempVideoIcon = `${waIcons}/tempVideoIcon.png`;
    imageUploadPreview = `${waIcons}/imageUploadPreview.png`;
    docUploadPreviewImg = `${waIcons}/documentPreviewIcon.png`;
    NoPreviewAvailableImg = `${waIcons}/NoPreviewAvailable.png`;

    dropdownOptions = [
        { title: 'Custom', value: 'QUICK_REPLY', iconName: 'custom', description: 'Quick reply button for customer response' },
        { title: 'Marketing Opt-Out', value: 'Marketing opt-out', iconName: 'marketing', description: 'Opt-out quick reply (Marketing only)' },
        { title: 'Call Phone Number', value: 'PHONE_NUMBER', iconName: 'phone', description: 'Maximum 1 button can be added' },
        { title: 'Visit Website', value: 'URL', iconName: 'site', description: 'Maximum 2 buttons can be added' }
    ];

    // Core Form Fields
    templateName = '';
    selectedLanguage = 'en_US';
    activeTab = 'Utility';
    selectedOption = 'Custom';
    selectedContentType = 'None';
    header = '';
    tempBody = 'Hello! Thank you for choosing us for your property needs. Our team will be happy to assist you.';
    formatedTempBody = 'Hello! Thank you for choosing us for your property needs. Our team will be happy to assist you.';
    footer = '';
    selectedObject = 'Contact';
    selectedVariableType = 'Number';
    selectedCountryType = '+971';
    selectedCountryTypeLabel = 'United Arab Emirates (+971)';
    isCheckboxChecked = false;

    // Media & File State
    file = null;
    fileName = '';
    fileData = null;
    fileSize = 0;
    fileType = '';
    filePreview = '';
    contentVersionId = null;
    originalContentVersionId = null;
    headerHandle = '';
    awsFileName = '';
    isAWSEnabled = false;
    confData = null;
    s3 = null;

    // Collections
    @track variables = [];
    @track header_variables = [];
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
    @track objectFieldMap = {};
    countryPhoneMap = {};
    countryLabelToCodeMap = {};
    countryCodeToLabelMap = {};

    // UI & Validation State
    isLoading = false;
    iseditTemplatevisible = false;
    showReviewTemplate = false;
    showEmojis = false;
    templateExists = false;
    isDropdownOpen = false;
    dropdownClass = 'dropdown-hidden';
    headerError = '';
    bodyVariablePlacementError = '';
    bodyVariableFormatError = '';
    headerVariableFormatError = '';

    // Edit Mode & Indexing
    _edittemplateid;
    isEditTemplate = false;
    originalTemplateName = '';
    originalHeader = '';
    metaTemplateId = '';
    nextIndex = 1;
    headIndex = 1;
    pendingConfirmAction = null;
    @api isTemplateClone = false;

    // Event listener bindings
    _boundHandleOutsideClick = null;
    _boundHandleBeforeUnload = null;
    _boundHandleKeyDown = null;

    // ==========================================
    // GETTERS: Directly derived state logic
    // ==========================================

    get isMarketingCategory() {
        return (this.activeTab || 'Marketing').toLowerCase() === 'marketing';
    }

    get isUtilityCategory() {
        return (this.activeTab || '').toLowerCase() === 'utility';
    }

    get isCategoryDisabled() {
        return this.isEditTemplate && !this.isTemplateClone;
    }

    get templateNameDisabled() {
        return this.isCategoryDisabled;
    }

    get isLanguageDisabled() {
        return this.isCategoryDisabled;
    }

    get marketingBtnClass() {
        const selected = this.isMarketingCategory ? 'category-segmented-btn active' : 'category-segmented-btn';
        return this.isCategoryDisabled ? `${selected} disabled` : selected;
    }

    get utilityBtnClass() {
        const selected = this.isUtilityCategory ? 'category-segmented-btn active' : 'category-segmented-btn';
        return this.isCategoryDisabled ? `${selected} disabled` : selected;
    }

    get templateNamePlaceholder() {
        return this.isUtilityCategory ? 'e.g. order_update_v1' : 'e.g. promotional_offer_v1';
    }

    // Media & File State Getters
    get IsHeaderText() {
        return this.selectedContentType === 'Text';
    }

    get addMedia() {
        return ['Image', 'Video', 'Document'].includes(this.selectedContentType);
    }

    get isfilename() {
        return !!this.fileName;
    }

    get NoFileSelected() {
        return !this.fileName;
    }

    get isMediaPlaceholder() {
        return this.addMedia && !this.fileName;
    }

    get isMediaPreview() {
        return this.addMedia && !!this.fileName;
    }

    get isVideoPreview() {
        return this.selectedContentType === 'Video';
    }

    get mediaPlaceholderImg() {
        return this.selectedContentType === 'Video' ? this.tempVideoIcon
            : (this.selectedContentType === 'Document' ? this.docUploadPreviewImg : this.imageUploadPreview);
    }

    get mediaPreviewImg() {
        return this.selectedContentType === 'Document' ? this.NoPreviewAvailableImg : this.filePreview;
    }

    get uploadMediaIcon() {
        return this.selectedContentType === 'Image' ? '/resource/MVEX__uploadImgIcon'
            : (this.selectedContentType === 'Video' ? '/resource/MVEX__uploadvideoIcon' : '/resource/MVEX__uploadDocIcon');
    }

    get mediaFileDescription() {
        return this.selectedContentType === 'Image' ? 'JPG or PNG file'
            : (this.selectedContentType === 'Video' ? 'MP4 file' : 'PDF file');
    }

    get mediaAccept() {
        return this.selectedContentType === 'Image' ? 'image/png, image/jpeg, image/jpg'
            : (this.selectedContentType === 'Video' ? 'video/mp4' : 'application/pdf');
    }

    // Buttons State Getters
    get totalButtonsCount() {
        return this.buttonList.length + this.customButtonList.length;
    }

    get isButtonDisabled() {
        return this.totalButtonsCount >= 10;
    }

    get buttonClass() {
        return this.isButtonDisabled ? 'select-button disabled' : 'select-button';
    }

    get createButton() {
        return this.buttonList.length > 0;
    }

    get isCustom() {
        return this.customButtonList.length > 0;
    }

    get isVisitSite() {
        return this.buttonList.some(b => b.isVisitSite);
    }

    get isStopMarketing() {
        return this.customButtonList.some(b => b.showFooterText || b.selectedCustomType === 'Marketing opt-out');
    }

    get callPhoneNumber() {
        return this.buttonList.filter(b => b.isCallPhone).length;
    }

    get visitWebsiteCount() {
        return this.buttonList.filter(b => b.isVisitSite).length;
    }

    get marketingOpt() {
        return this.customButtonList.filter(b => b.showFooterText || b.selectedCustomType === 'Marketing opt-out').length;
    }

    get showVisitSiteConsent() {
        return this.isMarketingCategory && this.isVisitSite;
    }

    get showStopMarketingConsent() {
        return this.isMarketingCategory && this.isStopMarketing;
    }

    get customOption() {
        if (this.isUtilityCategory) {
            return CUSTOM_OPTIONS.filter(opt => opt.value === 'QUICK_REPLY');
        }
        return CUSTOM_OPTIONS;
    }

    get quickReplyOptions() {
        return this.dropdownOptions
            .filter(opt => opt.value === 'QUICK_REPLY' || (!this.isUtilityCategory && opt.value === 'Marketing opt-out'))
            .map(opt => ({
                ...opt,
                iconUrl: this.getButtonPath(opt.iconName),
                classes: `dropdown-item ${opt.title.toLowerCase().replace(/\s+/g, '-')}`
            }));
    }

    get callToActionOptions() {
        return this.dropdownOptions
            .filter(opt => opt.value === 'PHONE_NUMBER' || opt.value === 'URL')
            .map(opt => ({
                ...opt,
                iconUrl: this.getButtonPath(opt.iconName),
                classes: `dropdown-item ${opt.title.toLowerCase().replace(/\s+/g, '-')}`
            }));
    }

    // Variables State Getters
    get addVar() {
        return this.variables.length > 0;
    }

    get addHeaderVar() {
        return this.header_variables.length > 0;
    }

    get buttonDisabled() {
        return this.header_variables.length >= 1;
    }

    get selectedLanguageLabel() {
        const option = this.languageOptions.find(o => o.value === this.selectedLanguage);
        return option ? option.label : '';
    }

    get maxtelephonelength() {
        return this.countryPhoneMap[this.selectedCountryType] || 15;
    }

    get tempHeaderExample() {
        return this.header_variables.map(v => `{{${v.field}}}`);
    }

    get templateBodyText() {
        return this.variables.map(v => {
            if (v.variableType === 'Name' && v.nameValue) {
                return v.nameValue;
            }
            return `{{${v.field}}}`;
        });
    }

    get computedVariables() {
        return this.mapComputedVariables(this.variables);
    }

    get computedHeaderVariables() {
        return this.mapComputedVariables(this.header_variables);
    }

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

    get isSubmitDisabled() {
        const areButtonFieldsFilled = this.buttonList.every(b => b.btntext && (b.webURL || b.phonenum));
        const areCustomButtonsFilled = this.customButtonList.every(b => b.Cbtntext);
        const hasButtonError = this.customButtonList.some(b => b.hasError) || this.buttonList.some(b => b.hasError);

        const mediaMissing = this.addMedia && !this.headerHandle;
        const textMissing = this.selectedContentType === 'Text' && !this.header;

        return !(
            this.templateName &&
            this.tempBody &&
            areButtonFieldsFilled &&
            areCustomButtonsFilled &&
            !this.templateExists &&
            !hasButtonError &&
            !mediaMissing &&
            !this.headerError &&
            !textMissing
        );
    }

    @api
    get edittemplateid() {
        return this._edittemplateid;
    }

    set edittemplateid(value) {
        this._edittemplateid = value;
        if (this._edittemplateid) {
            this.isEditTemplate = true;
            this.fetchTemplateData();
        }
    }

    // ==========================================
    // LIFECYCLE
    // ==========================================

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
                .catch(error => console.error('Error in initialisation:', error))
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

    disconnectedCallback() {
        if (this._boundHandleOutsideClick) {
            document.removeEventListener('click', this._boundHandleOutsideClick);
        }
        if (this._boundHandleBeforeUnload) {
            window.removeEventListener('beforeunload', this._boundHandleBeforeUnload);
        }
        if (this._boundHandleKeyDown) {
            window.removeEventListener('keydown', this._boundHandleKeyDown);
        }
    }

    // ==========================================
    // HELPER: VARIABLE MAPPING & PROCESSING
    // ==========================================

    mapComputedVariables(varList) {
        const isNameType = this.selectedVariableType === 'Name';
        return varList.map(varItem => {
            const computed = this.computeVariableFields(varItem);
            const displayIndex = isNameType
                ? (varItem.nameValue ? `{{${varItem.nameValue}}}` : '{{}}')
                : varItem.index;

            return {
                ...varItem,
                ...computed,
                index: displayIndex,
                placeholderText: isNameType ? 'Enter example' : 'Enter alternative text'
            };
        });
    }

    computeVariableFields(varItem) {
        const fieldOptions = (this.fields && this.fields.length > 0) ? this.fields : (varItem.options || []);
        const selectedField = fieldOptions.find(f => f.value === varItem.field);
        const fieldLabel = varItem.fieldLabel || selectedField?.label || varItem.field || 'Select field';

        let options = fieldOptions.map(f => ({ label: f.label, value: f.value }));
        if (varItem.field && !options.some(opt => opt.value === varItem.field)) {
            options = [{ label: fieldLabel, value: varItem.field }, ...options];
        }

        return { fieldLabel, options };
    }

    // ==========================================
    // CATEGORY, OBJECT & FIELDS HANDLING
    // ==========================================

    handleCategorySelect(event) {
        if (this.isCategoryDisabled) return;
        const selected = event.currentTarget.dataset.category;
        if (!selected || selected.toLowerCase() === (this.activeTab || '').toLowerCase()) return;

        this.activeTab = selected;
        this.selectedOption = (selected === 'Marketing') ? 'CustomMarketing' : 'Custom';

        if (this.isUtilityCategory) {
            const hadOptOut = this.customButtonList.some(btn => btn.selectedCustomType === 'Marketing opt-out');
            if (hadOptOut) {
                this.customButtonList = this.customButtonList.filter(btn => btn.selectedCustomType !== 'Marketing opt-out');
                this.showToast('Removed Marketing Opt-Out button as it is prohibited in Utility templates.', 'warning');
            }
        }
    }

    generateFieldLabelFromPath(fieldPath, objectName = null) {
        if (!fieldPath) return 'Select field';
        const fieldList = (objectName && this.objectFieldMap[objectName]) ? this.objectFieldMap[objectName] : this.fields;
        const field = fieldList?.find(f => f.value === fieldPath);
        return field?.label || fieldPath;
    }

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

    updateVariablesWithDefaultFields(fields, objectName) {
        if (!fields || fields.length === 0) return;
        const firstField = fields[0];

        const updateList = (list) => list.map(varItem => {
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

        this.variables = updateList(this.variables);
        this.header_variables = updateList(this.header_variables);
    }

    async handleObjectChange(event) {
        const selectedObject = event.detail?.value !== undefined ? event.detail.value : event.target.value;
        this.isLoading = true;
        this.selectedObject = selectedObject;

        try {
            const fields = await this.loadObjectFields(selectedObject);
            const firstField = fields[0];
            this.fields = fields;

            const mapToNewObject = (list) => list.map(item => ({
                ...item,
                object: selectedObject,
                field: firstField?.value || '',
                fieldLabel: firstField?.label || 'Select field',
                options: fields
            }));

            if (this.variables.length > 0) {
                this.variables = mapToNewObject(this.variables);
                this.formatedTempBody = this.formatText(this.tempBody);
                this.updateTextarea();
            }

            if (this.header_variables.length > 0) {
                this.header_variables = mapToNewObject(this.header_variables);
            }
        } catch (error) {
            console.error('Error fetching fields: ', error);
        } finally {
            this.isLoading = false;
        }
    }

    // ==========================================
    // TEMPLATE DATA LOADING (EDIT MODE)
    // ==========================================

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
                        this.selectedContentType = template.Header_Type__c || template.MVEX__Header_Type__c || 'None';
                        this.footer = template.Footer_Body__c || template.MVEX__WBFooter_Body__c || '';
                        this.selectedLanguage = template.Language__c || template.MVEX__Language__c;

                        this.languageOptions = this.languageOptions.map(option => ({
                            ...option,
                            isSelected: option.value === this.selectedLanguage
                        }));

                        this.tempBody = template.Template_Body__c || template.MVEX__WBTemplate_Body__c || 'Hello';
                        this.formatedTempBody = this.formatText(this.tempBody);

                        // Miscellaneous Data Parsing
                        try {
                            const rawMiscData = template.Template_Miscellaneous_Data__c || template.MVEX__Template_Miscellaneous_Data__c;
                            const miscData = rawMiscData ? JSON.parse(rawMiscData) : null;
                            this.contentVersionId = miscData?.contentVersionId;
                            this.originalContentVersionId = miscData?.contentVersionId;
                            this.isCheckboxChecked = miscData?.isCheckboxChecked || false;
                            this.awsFileName = miscData?.awsFileName;

                            if (this.awsFileName && !this.isAWSEnabled) {
                                this.showToast('AWS Configration missing.', 'warning');
                            }
                        } catch (error) {
                            console.error('templateMiscellaneousData Error ::: ', error);
                        }

                        // Header Media vs Text
                        if (['Image', 'Video', 'Document'].includes(this.selectedContentType)) {
                            const parser = new DOMParser();
                            const doc = parser.parseFromString(headerBody, "text/html");
                            const mediaUrl = doc.documentElement.textContent || "";
                            this.fileName = template?.File_Name__c || template?.MVEX__File_Name__c || '';
                            this.fileType = this.selectedContentType.toLowerCase();
                            this.filePreview = headerBody;
                            this.headerHandle = template?.Image_Header_Handle__c || template?.Header_Handle__c || template?.MVEX__Header_Handle__c || template?.MVEX__WBImage_Header_Handle__c || '';

                            if (!this.headerHandle && this.isEditTemplate) {
                                getMetaHeaderHandler({ fileUrlOrContentVersionId: mediaUrl, contentVersionId: this.contentVersionId })
                                    .then((result) => {
                                        if (!result || !result.trim()) {
                                            this.showToast('Header handle missing, please reupload file.', 'warning');
                                        }
                                        this.headerHandle = result;
                                    }).catch((error) => console.error('Error fetching header handler: ', error));
                            }
                        } else if (this.selectedContentType === 'Text') {
                            this.header = headerBody.trim().replace(/^\*\*|\*\*$/g, '');
                        }

                        // Parse Variables
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

                        const fieldFetchPromises = uniqueObjects.map(obj =>
                            this.objectFieldMap[obj] ? Promise.resolve() : this.loadObjectFields(obj)
                        );

                        Promise.all(fieldFetchPromises)
                            .then(() => (this.selectedObject ? this.loadObjectFields(this.selectedObject) : Promise.resolve()))
                            .then(() => {
                                const mapVars = (type) => tvs
                                    .filter(tv => tv.type === type)
                                    .map(variable => {
                                        const objectFields = this.objectFieldMap[variable.object] || [];
                                        const fieldLabel = this.generateFieldLabelFromPath(variable.field, variable.object);
                                        return {
                                            ...variable,
                                            field: variable.field,
                                            fieldLabel: fieldLabel,
                                            variableType: variable.variableType || 'Number',
                                            nameValue: variable.nameValue || variable.alternateText || '',
                                            options: objectFields
                                        };
                                    });

                                this.variables = mapVars('Body');
                                this.header_variables = mapVars('Header');
                                this.isLoading = false;
                            })
                            .catch(error => {
                                console.error('Error loading field data:', error);
                                this.isLoading = false;
                            });

                        // Parse Buttons
                        const buttonDataRaw = template.Button_Body__c || template.MVEX__WBButton_Body__c;
                        if (buttonDataRaw) {
                            const buttonDataList = JSON.parse(buttonDataRaw);
                            this.buttonList = [];
                            this.customButtonList = [];

                            buttonDataList.forEach((button, index) => {
                                if (button.type === 'QUICK_REPLY' || button.type === 'Marketing opt-out' || button.isMarketingOpt) {
                                    const btnType = button.isMarketingOpt ? 'Marketing opt-out' : button.type;
                                    this.createCustomButton(btnType, button.text || (btnType === 'Marketing opt-out' ? 'Stop promotions' : 'Quick reply'));
                                } else {
                                    let parsedPhoneNum = '';
                                    let parsedCountryCode = '+91';
                                    let parsedCountryLabel = 'India (+91)';

                                    if (button?.type === 'PHONE_NUMBER' && button?.phone_number) {
                                        const phone = button.phone_number;
                                        if (phone.startsWith('+')) {
                                            const codes = Object.keys(this.countryCodeToLabelMap).sort((a, b) => b.length - a.length);
                                            const matched = codes.find(c => phone.startsWith(c));
                                            if (matched) {
                                                parsedCountryCode = matched;
                                                parsedCountryLabel = this.countryCodeToLabelMap[matched] || parsedCountryLabel;
                                                parsedPhoneNum = phone.slice(matched.length).trim();
                                            } else {
                                                parsedPhoneNum = phone;
                                            }
                                        } else {
                                            parsedPhoneNum = phone;
                                        }
                                    }

                                    const newButton = {
                                        id: index + 1,
                                        selectedActionType: button?.type || '',
                                        iconName: this.getButtonIcon(button?.type),
                                        btntext: button?.text || '',
                                        webURL: button?.url || '',
                                        phonenum: parsedPhoneNum,
                                        selectedUrlType: button?.type === 'URL' ? 'Static' : '',
                                        selectedCountryType: parsedCountryCode,
                                        selectedCountryTypeLabel: parsedCountryLabel,
                                        isCallPhone: button?.type === 'PHONE_NUMBER',
                                        isVisitSite: button?.type === 'URL',
                                        hasError: false,
                                        errorMessage: ''
                                    };

                                    this.buttonList.push(newButton);
                                }
                            });
                            this.updateButtonErrors();
                        }
                    }, 500);
                })
                .catch((error) => {
                    console.error('Error fetching template data: ', error);
                    this.isLoading = false;
                });
        } catch (error) {
            console.error('Error in fetchTemplateData: ', error);
            this.isLoading = false;
        }
    }

    // ==========================================
    // MEDIA & FILE UPLOAD (AWS & SALESFORCE)
    // ==========================================

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
                params: { Bucket: confData.MVEX__S3_Bucket_Name__c }
            });
        } catch (error) {
            console.error("error initializeAwsSdk ", error);
        }
    }

    renameFileName(filename) {
        try {
            const extensionIndex = filename.lastIndexOf('.');
            const baseFileName = filename.substring(0, extensionIndex);
            const extension = filename.substring(extensionIndex + 1);
            const now = new Date();
            const timestamp = `${now.getFullYear()}${(now.getMonth() + 1).toString().padStart(2, '0')}${now.getDate().toString().padStart(2, '0')}_${now.getHours().toString().padStart(2, '0')}${now.getMinutes().toString().padStart(2, '0')}${now.getSeconds().toString().padStart(2, '0')}`;
            return `${baseFileName}_${timestamp}.${extension}`.replace(/\s+/g, "_");
        } catch (error) {
            console.error('error in renameFileName -> ', error.stack);
            return filename;
        }
    }

    async handleFileChange(event) {
        try {
            const file = event.target.files[0];
            if (!file) return;

            const typeConfig = ALLOWED_MEDIA_TYPES[this.selectedContentType];
            if (typeConfig && !typeConfig.mimes.includes(file.type)) {
                this.showToast(`Invalid file type. Please upload a valid ${typeConfig.label} file.`, 'error');
                event.target.value = '';
                return;
            }

            const maxSize = 4;
            if (file.size > maxSize * 1024 * 1024) {
                this.showToast(`${file.name} exceeds the ${maxSize}MB limit`, 'error');
                return;
            }

            this.file = file;
            this.fileName = file.name;
            this.fileType = file.type;
            this.fileSize = file.size;
            this.isLoading = true;

            if (this.isAWSEnabled) {
                await this.uploadToAWS([file]);
            } else {
                const reader = new FileReader();
                reader.onload = () => {
                    this.fileData = reader.result.split(',')[1];
                    this.handleUpload();
                };
                reader.readAsDataURL(file);
            }
        } catch (error) {
            this.isLoading = false;
            console.error('Error in file upload:', error);
        }
    }

    async uploadToAWS(files) {
        try {
            this.isLoading = true;
            this.initializeAwsSdk(this.confData);
            const uploadPromises = files.map(async (file) => {
                const objKey = this.renameFileName(file.name);
                const params = {
                    Key: objKey,
                    ContentType: file.type,
                    Body: file,
                    ACL: "public-read"
                };
                return await this.s3.upload(params).promise();
            });

            const results = await Promise.all(uploadPromises);
            results.forEach((result) => {
                if (result) {
                    const bucketName = this.confData.MVEX__S3_Bucket_Name__c;
                    const objKey = result.Key;
                    const awsFileUrl = `https://${bucketName}.s3.amazonaws.com/${objKey}`;
                    this.awsFileName = objKey;
                    this.filePreview = awsFileUrl;
                    this.uploadFileToMeta();
                }
            });
        } catch (error) {
            this.isLoading = false;
            console.error("Error in uploadToAWS: ", error);
        }
    }

    handleUpload() {
        if (!this.fileData) {
            this.showToast('Please select a file first!', 'error');
            return;
        }

        this.isLoading = true;
        uploadFile({ base64Data: this.fileData, fileName: this.fileName })
            .then((result) => {
                this.contentVersionId = result.contentVersionId;
                this.filePreview = (result.publicUrl || '').replace('/sfc/p/#', '/sfc/p/');
                this.uploadFileToMeta();
            })
            .catch((error) => {
                this.isLoading = false;
                this.showToast('Error uploading file!', 'error');
                console.error('Error uploading file - ', error);
            });
    }

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
                    this.isLoading = false;
                    if (result && result.trim()) {
                        this.headerHandle = result;
                        this.showToast('File uploaded successfully.', 'success');
                    } else {
                        this.showToast('Failed to get header handle from Meta.', 'error');
                    }
                })
                .catch(error => {
                    this.isLoading = false;
                    console.error('Failed upload session: ', error);
                    this.showToast(error.body?.message || 'Failed to upload file to Meta.', 'error');
                });
        } catch (error) {
            this.isLoading = false;
            console.error('Error starting upload session: ', error);
        }
    }

    handleDelete() {
        const isOriginalInEdit = (this.isEditTemplate || this.isTemplateClone) &&
            this.originalContentVersionId !== null &&
            this.contentVersionId === this.originalContentVersionId;

        if (isOriginalInEdit) {
            this.resetFileData();
            return;
        }

        if (this.isAWSEnabled && this.awsFileName) {
            try {
                this.initializeAwsSdk(this.confData);
                this.s3.deleteObject({
                    Bucket: this.confData.MVEX__S3_Bucket_Name__c,
                    Key: this.awsFileName.replace(/\s+/g, "_")
                }).promise().then(() => {
                    this.showToast('File deleted successfully', 'success');
                    this.resetFileData();
                }).catch(() => {
                    this.showToast('Error deleting file!', 'error');
                });
            } catch (e) {
                this.resetFileData();
            }
        } else if (this.contentVersionId) {
            deleteFile({ contentVersionId: this.contentVersionId })
                .then(() => {
                    this.showToast('File deleted successfully', 'success');
                    this.resetFileData();
                })
                .catch(() => this.showToast('Error deleting file!', 'error'));
        } else {
            this.resetFileData();
        }
    }

    resetFileData() {
        this.file = null;
        this.fileName = '';
        this.fileData = null;
        this.fileType = '';
        this.fileSize = 0;
        this.filePreview = '';
        this.contentVersionId = null;
        this.headerHandle = '';
        this.awsFileName = '';

        const fileInput = this.template.querySelector('.file-input');
        if (fileInput) {
            fileInput.value = '';
        }
    }

    handleContentType(event) {
        this.selectedContentType = event.detail?.value !== undefined ? event.detail.value : event.target.value;
        if (this.selectedContentType === 'None' || this.selectedContentType === 'Text') {
            this.resetFileData();
        }
    }

    // ==========================================
    // FORM INPUTS HANDLING
    // ==========================================

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
                    this.selectedCountryType = this.countryLabelToCodeMap[value] || value;
                }
                this.updateButtonProperty(index, name, value);
                return;
            }

            if (name === 'templateName') {
                this.templateName = value.replace(/\s+/g, '_').toLowerCase();
                this.checkTemplateExistence();
            } else if (name === 'language') {
                this.selectedLanguage = value;
                this.languageOptions = this.languageOptions.map(opt => ({
                    ...opt,
                    isSelected: opt.value === this.selectedLanguage
                }));
            } else if (name === 'footer') {
                this.footer = value;
            } else if (name === 'tempBody') {
                this.tempBody = value.replace(/(\n\s*){3,}/g, '\n\n');
                this.formatedTempBody = this.formatText(this.tempBody);
                this.updateFormatErrors();
                this.checkBodyVariablePlacement();
                this.syncVariablesFromBody();
            } else if (name === 'header') {
                this.header = value;
                const matches = (value.match(/\{\{[^}]*\}\}/g) || []).length;
                this.headerError = matches > 1 ? 'Only one variable is allowed in the header.' : '';
                this.updateFormatErrors();
                this.syncHeaderVariablesFromText();
            } else if (name === 'isCheckboxChecked') {
                this.isCheckboxChecked = checked;
            } else if (name === 'btntext') {
                this.updateButtonProperty(index, 'btntext', value);
                this.validateButtonText(index, value);
            }
        } catch (error) {
            console.error('Error in handleInputChange: ', error);
        }
    }

    updateButtonProperty(index, property, value) {
        if (this.buttonList[index]) {
            this.buttonList[index][property] = value;
        }
    }

    checkTemplateExistence() {
        if (!Array.isArray(this.allTemplates)) {
            this.templateExists = false;
            return;
        }
        this.templateExists = this.allTemplates.some(template => {
            const tId = template.Template_Id__c || template.MVEX__Template_Id__c;
            const tName = template.Template_Name__c || template.MVEX__Template_Name__c;
            if (this.isEditTemplate && !this.isTemplateClone) {
                if (tId && this.metaTemplateId && tId === this.metaTemplateId) return false;
                if (this.originalTemplateName && tName?.toLowerCase() === this.originalTemplateName?.toLowerCase()) return false;
            }
            return tName?.toLowerCase() === this.templateName?.toLowerCase();
        });
    }

    // ==========================================
    // BUTTONS MANAGEMENT
    // ==========================================

    getButtonIcon(type) {
        return type === 'PHONE_NUMBER' ? 'utility:call' : (type === 'URL' ? 'utility:new_window' : 'utility:reply');
    }

    getButtonPath(iconName) {
        return `${waIcons}/${iconName}.png`;
    }

    toggleDropdown(event) {
        event.stopPropagation();
        this.isDropdownOpen = !this.isDropdownOpen;
        this.dropdownClass = this.isDropdownOpen ? 'dropdown-visible' : 'dropdown-hidden';
    }

    handleMenuSelect(event) {
        try {
            const selectedValue = event.currentTarget.dataset.value;
            const buttonData = event.currentTarget.dataset.buttonData;
            this.isDropdownOpen = false;
            this.dropdownClass = 'dropdown-hidden';

            if (selectedValue === 'QUICK_REPLY') {
                const text = buttonData?.btntext || 'Quick reply';
                this.createCustomButton('QUICK_REPLY', text);
            } else if (selectedValue === 'Marketing opt-out') {
                if (!this.isMarketingCategory) {
                    this.showToast('Marketing opt-out buttons are only permitted in Marketing templates under Meta guidelines.', 'warning');
                    return;
                }
                if (this.marketingOpt < 1) {
                    const text = buttonData?.btntext || 'Stop promotions';
                    this.createCustomButton('Marketing opt-out', text);
                }
            } else if (selectedValue === 'PHONE_NUMBER') {
                if (this.callPhoneNumber < 1) {
                    const btn = {
                        id: this.buttonList.length + 1,
                        selectedActionType: 'PHONE_NUMBER',
                        iconName: this.getButtonIcon('PHONE_NUMBER'),
                        btntext: buttonData?.btntext || 'Call Phone Number',
                        webURL: '',
                        phonenum: buttonData?.phonenum || '',
                        selectedUrlType: 'Static',
                        selectedCountryType: this.selectedCountryType || '+91',
                        selectedCountryTypeLabel: this.selectedCountryTypeLabel || 'India (+91)',
                        isCallPhone: true,
                        isVisitSite: false,
                        hasError: false,
                        errorMessage: ''
                    };
                    this.buttonList.push(btn);
                    this.updateButtonErrors();
                }
            } else if (selectedValue === 'URL') {
                if (this.visitWebsiteCount < 2) {
                    const btn = {
                        id: this.buttonList.length + 1,
                        selectedActionType: 'URL',
                        iconName: this.getButtonIcon('URL'),
                        btntext: buttonData?.btntext || 'Visit Website',
                        webURL: buttonData?.webURL || '',
                        phonenum: '',
                        selectedUrlType: 'Static',
                        selectedCountryType: '',
                        selectedCountryTypeLabel: '',
                        isCallPhone: false,
                        isVisitSite: true,
                        hasError: false,
                        errorMessage: ''
                    };
                    this.buttonList.push(btn);
                    this.updateButtonErrors();
                }
            }
        } catch (error) {
            console.error('Error handling menu selection:', error);
        }
    }

    createCustomButton(btnType, btnText) {
        const isOptOut = btnType === 'Marketing opt-out';
        const newCustomButton = {
            id: this.customButtonList.length + 1,
            selectedCustomType: btnType,
            Cbtntext: btnText,
            showFooterText: isOptOut,
            iconName: this.getButtonIcon(btnType),
            hasError: false,
            errorMessage: ''
        };
        this.customButtonList.push(newCustomButton);
        this.customButtonList = [...this.customButtonList];
        this.updateButtonErrors(true);
    }

    handleCustom(event) {
        const index = event.target?.dataset?.index;
        if (index !== undefined && this.customButtonList[index]) {
            this.customButtonList[index].selectedCustomType = event.target.value;
        }
    }

    handleCustomText(event) {
        const index = parseInt(event.currentTarget.dataset.index, 10);
        const newValue = event.target.value;
        if (this.customButtonList[index]) {
            this.customButtonList[index].Cbtntext = newValue;
            this.updateButtonErrors(true);
        }
    }

    handleRemove(event) {
        const index = parseInt(event.currentTarget.dataset.index, 10);
        this.buttonList = this.buttonList.filter((_, i) => i !== index);
        this.updateButtonErrors(false);
    }

    handleRemoveCustom(event) {
        const index = parseInt(event.currentTarget.dataset.index, 10);
        this.customButtonList = this.customButtonList.filter((_, i) => i !== index);
        this.updateButtonErrors(true);
    }

    validateButtonText(index, newValue) {
        this.updateButtonErrors(false);
    }

    updateButtonErrors(isCustom = false) {
        const list = isCustom ? this.customButtonList : this.buttonList;
        const textKey = isCustom ? 'Cbtntext' : 'btntext';
        const texts = list.map(b => b[textKey]);

        const duplicates = {};
        texts.forEach(t => {
            if (t) duplicates[t] = (duplicates[t] || 0) + 1;
        });

        list.forEach((b, idx) => {
            const hasDuplicate = idx > 0 && duplicates[b[textKey]] > 1;
            b.hasError = hasDuplicate;
            b.errorMessage = hasDuplicate ? 'You have entered the same text for multiple buttons.' : '';
        });
    }

    // ==========================================
    // VARIABLE SYNCHRONIZATION & MANIPULATION
    // ==========================================

    addvariable() {
        this.addVariableHelper('body');
    }

    addheadervariable() {
        this.addVariableHelper('header');
    }

    addVariableHelper(target) {
        const isHeader = target === 'header';
        const list = isHeader ? this.header_variables : this.variables;
        const isNameType = this.selectedVariableType === 'Name';

        const nextId = list.reduce((max, v) => Math.max(max, parseInt(v.id || 0, 10)), 0) + 1;
        const defaultField = this.fields[0]?.value || '';
        const defaultFieldLabel = this.fields[0]?.label || 'Select Field';
        const placeholderToAdd = isNameType ? '{{}}' : `{{${nextId}}}`;

        const newVar = {
            id: nextId,
            object: this.selectedObject,
            field: defaultField,
            fieldLabel: defaultFieldLabel,
            alternateText: '',
            variableType: this.selectedVariableType,
            nameValue: '',
            index: placeholderToAdd,
            options: this.fields
        };

        if (isHeader) {
            this.header_variables = [...this.header_variables, newVar];
            this.originalHeader = (this.originalHeader || this.header || '') + ` ${placeholderToAdd}`;
            this.header = this.originalHeader;
        } else {
            this.variables = [...this.variables, newVar];
            this.tempBody = `${this.tempBody} ${placeholderToAdd} `;
            this.formatedTempBody = this.formatText(this.tempBody);
            this.updateTextarea();
            this.checkBodyVariablePlacement();
        }
    }

    handleVarFieldChange(event) {
        this.updateVariableFieldHelper('body', event);
    }

    handleFieldChange(event) {
        this.updateVariableFieldHelper('header', event);
    }

    updateVariableFieldHelper(target, event) {
        const variableIndex = String(event.currentTarget?.dataset?.index || event.target?.dataset?.index || '');
        const variableId = String(event.currentTarget?.dataset?.id || event.target?.dataset?.id || '');
        const fieldName = event.detail?.value !== undefined ? event.detail.value : event.target.value;
        const selectedOption = this.fields?.find(f => f.value === fieldName);
        const fieldLabel = selectedOption?.label || fieldName;

        const updateList = (list) => list.map(item => {
            const matchIndex = variableIndex && (String(item.index) === variableIndex || `{{${item.index}}}` === variableIndex);
            const matchId = variableId && String(item.id) === variableId;
            if (matchId || matchIndex) {
                return { ...item, field: fieldName, fieldLabel: fieldLabel };
            }
            return item;
        });

        if (target === 'header') {
            this.header_variables = updateList(this.header_variables);
        } else {
            this.variables = updateList(this.variables);
            this.formatedTempBody = this.formatText(this.tempBody);
        }
    }

    handleAlternateVarChange(event) {
        this.updateAlternateTextHelper('body', event);
    }

    handleAlternateTextChange(event) {
        this.updateAlternateTextHelper('header', event);
    }

    updateAlternateTextHelper(target, event) {
        const idOrIndex = String(event.target.dataset.id || event.target.dataset.index || '');
        const alternateText = (event.target.value || '').trim();

        const updateList = (list) => list.map(item =>
            (String(item.id) === idOrIndex || String(item.index) === idOrIndex)
                ? { ...item, alternateText }
                : item
        );

        if (target === 'header') {
            this.header_variables = updateList(this.header_variables);
        } else {
            this.variables = updateList(this.variables);
        }
    }

    handleVarRemove(event) {
        this.removeVariableHelper('body', parseInt(event.currentTarget.dataset.index, 10));
    }

    handleHeaderVarRemove(event) {
        this.removeVariableHelper('header', parseInt(event.currentTarget.dataset.index, 10));
    }

    removeVariableHelper(target, removeIdx) {
        const isHeader = target === 'header';
        const list = isHeader ? this.header_variables : this.variables;
        const varToRemove = list[removeIdx];
        if (!varToRemove) return;

        const isNameType = this.selectedVariableType === 'Name';
        const placeholder = isNameType
            ? (varToRemove.nameValue ? `{{${varToRemove.nameValue}}}` : '{{}}')
            : `{{${removeIdx + 1}}}`;

        if (isHeader) {
            this.header = (this.header || '').replace(placeholder, '').trim();
            this.header_variables = this.header_variables.filter((_, i) => i !== removeIdx);
        } else {
            let updatedBody = (this.tempBody || '').replace(placeholder, '').trim();
            this.variables = this.variables.filter((_, i) => i !== removeIdx);

            if (!isNameType) {
                this.variables = this.variables.map((v, idx) => ({
                    ...v,
                    id: idx + 1,
                    index: `{{${idx + 1}}}`
                }));
                const placeholders = updatedBody.match(/\{\{\d+\}\}/g) || [];
                placeholders.forEach((pl, idx) => {
                    updatedBody = updatedBody.replace(pl, `{{${idx + 1}}}`);
                });
            }

            this.tempBody = updatedBody;
            this.formatedTempBody = this.formatText(this.tempBody);
            this.updateTextarea();
            this.checkBodyVariablePlacement();
        }
    }

    syncVariablesFromBody() {
        this.syncVariablesFromTextHelper('body', this.tempBody);
    }

    syncHeaderVariablesFromText() {
        this.syncVariablesFromTextHelper('header', this.header);
    }

    syncVariablesFromTextHelper(target, text) {
        const isHeader = target === 'header';
        if (!text) {
            if (isHeader) this.header_variables = [];
            else this.variables = [];
            return;
        }

        const matches = [...text.matchAll(/\{\{([^}]*)\}\}/g)];
        if (matches.length === 0) {
            if (isHeader) this.header_variables = [];
            else this.variables = [];
            return;
        }

        const isNameType = this.selectedVariableType === 'Name';
        const existingList = isHeader ? this.header_variables : this.variables;
        const defaultField = this.fields[0]?.value || '';
        const defaultFieldLabel = this.fields[0]?.label || 'Select Field';

        const updated = matches.map((match, idx) => {
            const content = match[1].trim();
            const existing = existingList[idx];
            const displayIndex = content ? `{{${content}}}` : '{{}}';

            if (existing) {
                return {
                    ...existing,
                    nameValue: isNameType ? content : existing.nameValue,
                    index: isNameType ? displayIndex : `{{${content}}}`
                };
            }
            return {
                id: idx + 1,
                object: this.selectedObject,
                field: defaultField,
                fieldLabel: defaultFieldLabel,
                alternateText: '',
                variableType: this.selectedVariableType,
                nameValue: isNameType ? content : '',
                index: isNameType ? displayIndex : `{{${content}}}`,
                options: this.fields
            };
        });

        if (isHeader) {
            this.header_variables = updated;
        } else {
            this.variables = updated;
        }
    }

    // ==========================================
    // VALIDATION LOGIC
    // ==========================================

    validateVariableFormat(text, variableType, strictMode = false) {
        if (!text) return { isValid: true, errorMessage: '' };
        const allVars = text.match(/\{\{([^}]*)\}\}/g) || [];
        if (allVars.length === 0) return { isValid: true, errorMessage: '' };

        if (strictMode && allVars.some(v => v === '{{}}')) {
            return {
                isValid: false,
                errorMessage: 'Variable parameters cannot be empty. Please provide a name for all variables.'
            };
        }

        if (variableType === 'Number') {
            const pattern = /^\{\{\d+\}\}$/;
            if (allVars.some(v => !pattern.test(v))) {
                return {
                    isValid: false,
                    errorMessage: 'This template contains variable parameters with incorrect formatting. Variable parameters must be whole numbers with two sets of curly brackets (for example, {{1}}, {{2}}).'
                };
            }
        } else if (variableType === 'Name') {
            const namePattern = /^\{\{([a-zA-Z_][a-zA-Z0-9_]*|)\}\}/;
            const pureNumberPattern = /^\{\{\d+\}\}$/;
            const invalidVars = allVars.filter(v => v !== '{{}}' && (pureNumberPattern.test(v) || !namePattern.test(v)));
            if (invalidVars.length > 0) {
                return {
                    isValid: false,
                    errorMessage: 'This template contains variable parameters with incorrect formatting. Variable parameters must be letters, underscores and numbers (not starting with a number) with two sets of curly brackets (for example, {{customer_name}}, {{Name}}).'
                };
            }
        }
        return { isValid: true, errorMessage: '' };
    }

    updateFormatErrors() {
        const bodyValidation = this.validateVariableFormat(this.tempBody, this.selectedVariableType);
        this.bodyVariableFormatError = bodyValidation.isValid ? '' : bodyValidation.errorMessage;

        const headerValidation = this.validateVariableFormat(this.header, this.selectedVariableType);
        this.headerVariableFormatError = headerValidation.isValid ? '' : headerValidation.errorMessage;
    }

    checkBodyVariablePlacement() {
        if (!this.tempBody || this.tempBody.trim() === '') {
            this.bodyVariablePlacementError = '';
            return false;
        }

        const errors = [];
        const normalized = this.tempBody.replace(/\s+/g, ' ').trim();
        const pattern = this.selectedVariableType === 'Name' ? /\{\{[^}]*\}\}/ : /\{\{\d+\}\}/;

        const startsWithVar = new RegExp(`^${pattern.source}`).test(normalized);
        const endsWithVar = new RegExp(`${pattern.source}$`).test(normalized);
        const backToBackPattern = this.selectedVariableType === 'Name' ? /\{\{[^}]*\}\}\{\{[^}]*\}\}/ : /\{\{\d+\}\}\{\{\d+\}\}/;

        if (backToBackPattern.test(normalized)) {
            errors.push('Variables cannot be placed directly next to each other. Please add text or a space between variables');
        }
        if (startsWithVar && endsWithVar) {
            errors.push('Template body cannot start and end with a variable. Please add static text before and after the variables');
        } else if (startsWithVar) {
            errors.push('Template body cannot start with a variable. Please add static text before the variable');
        } else if (endsWithVar) {
            errors.push('Template body cannot end with a variable. Please add static text after the variable');
        }

        if (this.selectedVariableType !== 'Name') {
            const seqError = this.checkBodyVariableSequence(normalized);
            if (seqError) errors.push(seqError);
        }

        const ratioError = this.checkVariableToWordRatio(normalized);
        if (ratioError) errors.push(ratioError);

        if (errors.length > 0) {
            this.bodyVariablePlacementError = errors.join('. ');
            return true;
        }
        this.bodyVariablePlacementError = '';
        return false;
    }

    checkVariableToWordRatio(body) {
        const varMatches = body.match(/\{\{[^}]*\}\}/g) || [];
        if (varMatches.length === 0) return null;

        const nonVarText = body.replace(/\{\{[^}]*\}\}/g, ' ').trim();
        const words = nonVarText.split(/\s+/).filter(w => w.length > 0);
        if (words.length < (2 * varMatches.length) + 1) {
            return 'This template has too many variables for its length. Reduce the number of variables or increase the message length.';
        }
        return null;
    }

    checkBodyVariableSequence(body) {
        if (this.selectedVariableType === 'Name') return null;
        const matches = [...body.matchAll(/\{\{(\d+)\}\}/g)].map(m => parseInt(m[1], 10));
        if (matches.length === 0) return null;

        const maxVar = Math.max(...matches);
        const set = new Set(matches);
        const missing = [];
        for (let i = 1; i <= maxVar; i++) {
            if (!set.has(i)) missing.push(`{{${i}}}`);
        }
        if (missing.length > 0) {
            return `Variable sequence is incomplete. Missing variable(s): ${missing.join(', ')}. Variables must be present from {{1}} to {{${maxVar}}}.`;
        }
        return null;
    }

    validateTemplate() {
        if (!this.templateName?.trim()) {
            this.showToast('Template Name is required', 'error');
            return false;
        }
        if (!this.selectedLanguage) {
            this.showToast('Please select a language', 'error');
            return false;
        }
        if (!this.tempBody?.trim()) {
            this.showToast('Template Body is required', 'error');
            return false;
        }
        if (this.checkBodyVariablePlacement()) {
            this.showToast(this.bodyVariablePlacementError, 'error');
            return false;
        }

        const allButtons = [...this.buttonList, ...this.customButtonList];
        for (const btn of allButtons) {
            if (btn.isVisitSite && (!btn.webURL || !this.validateUrl(btn.webURL))) {
                this.showToast('Please provide a valid URL that should be properly formatted (e.g., https://example.com)', 'error');
                return false;
            }
            if (btn.isCallPhone && (!btn.phonenum || !this.validatePhoneNumber(btn.phonenum, btn.selectedCountryType))) {
                this.showToast('Please provide a valid country and phone number for the "Call Phone Number" button', 'error');
                return false;
            }
            if (btn.isCustom && !btn.Cbtntext?.trim()) {
                this.showToast('Button text is required for the custom button', 'error');
                return false;
            }
        }

        if (this.isUtilityCategory && this.customButtonList.some(b => b.selectedCustomType === 'Marketing opt-out')) {
            this.showToast('Marketing opt-out buttons are not allowed in Utility templates according to Meta guidelines.', 'error');
            return false;
        }

        return true;
    }

    validateUrl(value) {
        return /^(https?:\/\/)?(www\.)?([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,6}($|\/.*)$/.test(value);
    }

    validatePhoneNumber(value, countryCode) {
        if (!/^\d+$/.test(value)) return false;
        const validLengths = this.countryPhoneMap[countryCode];
        return validLengths && validLengths.length > 0 ? validLengths.includes(value.length) : value.length >= 7;
    }

    // ==========================================
    // EMOJI & TEXT FORMATTING
    // ==========================================

    handleEmoji(event) {
        event.stopPropagation();
        this.showEmojis = !this.showEmojis;
    }

    handleEmojiSelection(event) {
        try {
            event.stopPropagation();
            const emojiChar = event.target.textContent;
            const textarea = this.template.querySelector('textarea');
            const currentText = textarea?.value || '';
            const cursorPos = textarea?.selectionStart || currentText.length;

            const newText = currentText.slice(0, cursorPos) + emojiChar + currentText.slice(cursorPos);
            this.tempBody = newText;
            this.formatedTempBody = this.formatText(newText);
            if (textarea) textarea.value = newText;

            setTimeout(() => {
                const newPos = cursorPos + emojiChar.length;
                if (textarea) {
                    textarea.focus();
                    textarea.setSelectionRange(newPos, newPos);
                }
            }, 0);
        } catch (error) {
            console.error('Error in emoji selection:', error);
        }
    }

    handleFormat(event) {
        try {
            const button = event.target.closest('button');
            const formatType = button?.dataset?.format;
            const textarea = this.template.querySelector('textarea');
            if (!textarea) return;

            const markerMap = { 'Bold': '*', 'Italic': '_', 'Strikethrough': '~', 'Code': '```' };
            const marker = markerMap[formatType];
            if (!marker) return;

            const selStart = textarea.selectionStart;
            const selEnd = textarea.selectionEnd;
            const currentText = textarea.value;
            const selectedText = currentText.slice(selStart, selEnd);
            const wrapped = marker + selectedText + marker;

            const newText = currentText.slice(0, selStart) + wrapped + currentText.slice(selEnd);
            this.tempBody = newText;
            this.formatedTempBody = this.formatText(newText);

            const newStart = selStart + marker.length;
            const newEnd = newStart + selectedText.length;
            this.updateCursorRange(newStart, newEnd);
        } catch (error) {
            console.error('Error in handleFormat:', error);
        }
    }

    formatText(inputText) {
        try {
            if (!inputText) return '';
            let formatted = inputText.replace(/(\n\s*){3,}/g, '\n\n');
            formatted = formatted.replaceAll('\n', '<br/>');
            formatted = formatted.replace(/\*(.*?)\*/g, '<b>$1</b>');
            formatted = formatted.replace(/_(.*?)_/g, '<i>$1</i>');
            formatted = formatted.replace(/~(.*?)~/g, '<s>$1</s>');
            formatted = formatted.replace(/```(.*?)```/g, '<code>$1</code>');
            return formatted;
        } catch (error) {
            return inputText || '';
        }
    }

    updateCursorRange(selStart, selEnd) {
        const textarea = this.template.querySelector('textarea');
        if (textarea) {
            textarea.value = this.tempBody;
            textarea.focus();
            textarea.selectionStart = selStart;
            textarea.selectionEnd = selEnd;
        }
    }

    updateTextarea() {
        const textarea = this.template.querySelector('textarea');
        if (textarea) {
            textarea.value = this.tempBody;
            textarea.focus();
        }
    }

    // ==========================================
    // DIALOGS & CONFIRMATION
    // ==========================================

    handleConfirm() {
        const bodyFormat = this.validateVariableFormat(this.tempBody, this.selectedVariableType, true);
        if (!bodyFormat.isValid) {
            this.showToast(bodyFormat.errorMessage, 'error');
            return;
        }

        if (this.header) {
            const headerFormat = this.validateVariableFormat(this.header, this.selectedVariableType, true);
            if (!headerFormat.isValid) {
                this.showToast(headerFormat.errorMessage, 'error');
                return;
            }
        }

        const missingHeaderAlt = this.header_variables.some(v => !v.alternateText?.trim());
        const missingBodyAlt = this.variables.some(v => !v.alternateText?.trim());

        if (missingHeaderAlt || missingBodyAlt) {
            this.showToast('Example/Alternative Text value is required for all variables', 'error');
            return;
        }

        this.showReviewTemplate = true;
    }

    handleCloseTemplate() {
        this.showReviewTemplate = false;
        this.iseditTemplatevisible = true;
        this.isLoading = false;
    }

    // ==========================================
    // TEMPLATE SUBMISSION
    // ==========================================

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

            const buttonData = [...this.buttonList, ...this.customButtonList];
            const optOutBtn = this.customButtonList.find(b => b.selectedCustomType === 'Marketing opt-out');

            const miscData = {
                contentVersionId: this.contentVersionId,
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
                tempHeaderExample: this.tempHeaderExample.length > 0 ? this.tempHeaderExample : null,
                tempImgUrl: this.filePreview || null,
                tempImgId: this.contentVersionId || null,
                tempImgName: this.fileName || null,
                templateBody: this.tempBody || '',
                templateBodyText: this.templateBodyText.length > 0 ? this.templateBodyText : null,
                tempFooterText: this.footer || null,
                typeOfButton: buttonData.length > 0 ? JSON.stringify(buttonData) : null,
                marketingOptText: optOutBtn ? optOutBtn.Cbtntext : null,
                templateMiscellaneousData: JSON.stringify(miscData),
                variables: this.variables.map(v => ({
                    placeholder: v.index,
                    alternateText: v.alternateText,
                    objectName: v.object,
                    fieldName: v.field,
                    variableType: v.variableType
                })),
                header_variables: this.header_variables.map(v => ({
                    placeholder: v.index,
                    alternateText: v.alternateText,
                    objectName: v.object,
                    fieldName: v.field,
                    variableType: v.variableType
                })),
                selectedVariableType: this.selectedVariableType || 'Name'
            };

            const serializedWrapper = JSON.stringify(template);
            const payload = JSON.stringify(buildPayload(template));

            const isEditOperation = this.metaTemplateId && this.metaTemplateId !== 'DRAFT' && !this.isTemplateClone;
            const submitPromise = isEditOperation
                ? editWhatsappTemplate({ serializedWrapper, payloadWrapper: payload, templateId: this.metaTemplateId })
                : createWhatsappTemplate({ serializedWrapper, payloadWrapper: payload, templateName: this.templateName });

            submitPromise.then(result => {
                this.isLoading = false;
                if (result?.success) {
                    this.showToast(isEditOperation ? 'Template successfully edited.' : 'Template successfully created', 'success');
                    this.clearEditTemplateData();
                    this.closeAndReturnToTemplateList();
                } else if (result?.success === false && result?.status === 'warning') {
                    this.showToast(
                        isEditOperation
                            ? 'Template updation taking too much time, please wait for few minutes and refresh.'
                            : 'Template creation taking too much time, please wait for few minutes and refresh.',
                        'warning'
                    );
                    this.clearEditTemplateData();
                    this.closeAndReturnToTemplateList();
                } else {
                    let errorMsg = result?.message || result?.errorMessage || 'Due to unknown error';
                    if (result?.errorMessage) {
                        try {
                            const parsed = JSON.parse(result.errorMessage);
                            errorMsg = parsed?.error?.error_user_msg || parsed?.error?.message || errorMsg;
                        } catch (e) { }
                    }
                    this.showToast(`${isEditOperation ? 'Template update' : 'Template creation'} failed: ${errorMsg}`, 'error');
                }
            }).catch(error => {
                this.isLoading = false;
                const msg = error?.body?.message?.includes?.('Read timed out')
                    ? 'The request timed out. Please try again.'
                    : (error?.body?.message?.error_user_title || 'An unknown error occurred');
                this.showToast(`${isEditOperation ? 'Template update' : 'Template creation'} failed: ${msg}`, 'error');
            });
        } catch (error) {
            this.isLoading = false;
            this.showToast('An unexpected error occurred while submitting the template.', 'error');
        }
    }

    // ==========================================
    // NAVIGATION & CANCEL LOGIC
    // ==========================================

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
                this.dispatchEvent(new CustomEvent('backtocontrolcenter', { bubbles: true, composed: true }));
            }
            return true;
        } catch (error) {
            console.error('Error in handlePrevclick: ', error);
            return false;
        }
    }

    executeCancel() {
        if (this.contentVersionId != null) {
            this.handleDelete();
        }
        this.clearEditTemplateData();
        this.closeAndReturnToTemplateList();
    }

    clearEditTemplateData() {
        this.templateName = '';
        this.selectedContentType = 'None';
        this.header = '';
        this.tempBody = 'Hello';
        this.formatedTempBody = 'Hello';
        this.footer = '';
        this.buttonList = [];
        this.customButtonList = [];
        this.variables = [];
        this.header_variables = [];
        this.originalHeader = '';
        this.nextIndex = 1;
        this.headIndex = 1;
        this.activeTab = 'Utility';
        this.selectedOption = 'Custom';
        this.resetFileData();
    }

    closeAndReturnToTemplateList() {
        this.dispatchEvent(new CustomEvent('closetemplatemanager', { bubbles: true, composed: true }));
        this.dispatchEvent(new CustomEvent('previous', {
            bubbles: true,
            composed: true,
            detail: { activeTab: this.activeTab }
        }));
    }

    @api
    hasUnsavedChanges() {
        if (!this.iseditTemplatevisible) return false;
        return Boolean(this.templateName) ||
            (this.tempBody && this.tempBody !== 'Hello') ||
            Boolean(this.header) ||
            Boolean(this.footer) ||
            (this.buttonList && this.buttonList.length > 0) ||
            (this.customButtonList && this.customButtonList.length > 0) ||
            Boolean(this.contentVersionId) ||
            this.isEditTemplate;
    }

    handleBeforeUnload(event) {
        if (this.hasUnsavedChanges()) {
            event.preventDefault();
            event.returnValue = 'This may remove the changes you have done.';
            return event.returnValue;
        }
    }

    handleKeyDown(event) {
        const isRefresh = event.key === 'F5' || ((event.ctrlKey || event.metaKey) && (event.key === 'r' || event.key === 'R'));
        if (isRefresh && this.hasUnsavedChanges()) {
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

    handleConfirmation(event) {
        const isConfirmed = event.detail === true;
        const action = this.pendingConfirmAction;
        this.pendingConfirmAction = null;
        if (!isConfirmed) return;

        if (action === 'cancel') {
            this.executeCancel();
        } else if (action === 'cancel_to_control_center') {
            this.executeCancel();
            this.dispatchEvent(new CustomEvent('backtocontrolcenter', { bubbles: true, composed: true }));
        } else if (action === 'refresh') {
            window.location.reload();
        }
    }

    handleOutsideClick(event) {
        const target = event.target;
        if (this.showEmojis) {
            const emojiContainer = this.template.querySelector('.toolbar-button');
            const button = this.template.querySelector('button');
            if (emojiContainer && !emojiContainer.contains(target) && button && !button.contains(target)) {
                this.showEmojis = false;
            }
        }
        if (this.isDropdownOpen) {
            const dropdown = this.template.querySelector('.dropdown-container');
            if (dropdown && !dropdown.contains(target)) {
                this.isDropdownOpen = false;
                this.dropdownClass = 'dropdown-hidden';
            }
        }
    }

    // ==========================================
    // STATIC RESOURCES & TOASTS
    // ==========================================

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
                    const cat = item.category;
                    if (!acc[cat]) acc[cat] = { category: cat, emojis: [] };
                    acc[cat].emojis.push(item);
                    return acc;
                }, {})
            );
        }

        if (countryData) {
            this.countryType = countryData.map(item => ({ label: item?.label, value: item?.label }));
            countryData.forEach(item => {
                this.countryLabelToCodeMap[item?.label] = item?.code;
                this.countryCodeToLabelMap[item?.code] = item?.label;
                this.countryPhoneMap[item?.code] = item.lengths;
            });
        }

        if (languageData) {
            this.languageOptions = languageData.map(lang => ({
                label: `${lang.language}`,
                value: lang.code,
                isSelected: lang.code === this.selectedLanguage
            }));
            if (!this.languageOptions.some(opt => opt.isSelected) && this.languageOptions[0]) {
                this.selectedLanguage = this.languageOptions[0].value;
                this.languageOptions[0].isSelected = true;
            }
        }
    }

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

    fetchAllTemplates(dispatchEvent = true) {
        getWhatsAppTemplates()
            .then(data => {
                this.allTemplates = data;
                if (dispatchEvent) {
                    this.dispatchEvent(new CustomEvent('templateupdate', { detail: data }));
                }
            })
            .catch(() => this.showToast('Failed to fetch updated templates.', 'error'));
    }

    showToast(message, variant = 'info', title = null) {
        this.dispatchEvent(new ShowToastEvent({
            title: title || (variant === 'error' ? 'Error' : variant === 'success' ? 'Success' : 'Information'),
            message,
            variant
        }));
    }
}
