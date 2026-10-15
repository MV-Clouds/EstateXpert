import { LightningElement, api, track } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import getTemplatePreviewData from '@salesforce/apex/WATemplateHomePageController.getTemplatePreviewData';
import searchPreviewRecords from '@salesforce/apex/WATemplateHomePageController.searchPreviewRecords';
import getTemplatePreviewDataWithRecord from '@salesforce/apex/WATemplateHomePageController.getTemplatePreviewDataWithRecord';
import waIcons from '@salesforce/resourceUrl/waIcons';
import globalStyles from '@salesforce/resourceUrl/globalStyles';

export default class WaTemplatePreview extends LightningElement {
    @track isLoading = false;
    @track hasError = false;

    // Template properties
    @track headerType = 'None';
    @track rawHeaderText = '';
    @track replacedHeaderText = '';
    @track headerMediaUrl = '';
    @track documentName = 'Document.pdf';
    @track imageLoadFailed = false;
    @track videoLoadFailed = false;
    @track rawBodyText = '';
    @track replacedBodyText = '';
    @track footerText = '';
    @track buttons = [];
    @track variables = [];
    @track replacements = {};

    // Searchable Combobox & Object Record Selection
    @track detectedObjects = [];
    @track activeObjectName = 'Contact';
    @track selectedRecord = null;
    @track isComboboxOpen = false;
    @track searchTerm = '';
    @track searchResults = [];
    @track isSearchingRecords = false;

    _templateId;
    _previewData;
    _currentTemplate;
    _searchTimeout;

    @api
    get templateId() {
        return this._templateId;
    }
    set templateId(value) {
        this._templateId = value;
        if (this._templateId) {
            this.fetchTemplateData();
        }
    }

    @api
    get templateid() {
        return this._templateId;
    }
    set templateid(value) {
        this.templateId = value;
    }

    @api
    get previewData() {
        return this._previewData;
    }
    set previewData(value) {
        this._previewData = value;
        if (this._previewData) {
            this.processTemplateData(this._previewData);
        }
    }

    connectedCallback() {
        try {
            loadStyle(this, globalStyles);
        } catch (e) {
            console.error('Error loading globalStyles in waTemplatePreview:', e);
        }

        if (this._previewData) {
            this.processTemplateData(this._previewData);
        } else if (this._templateId) {
            this.fetchTemplateData();
        }
    }

    /**
     * Fetches template details and variable mappings from Apex controller.
     */
    async fetchTemplateData() {
        if (!this._templateId) return;
        this.isLoading = true;
        this.hasError = false;
        this.selectedRecord = null;
        this.isComboboxOpen = false;
        this.replacedHeaderText = '';
        this.replacedBodyText = '';
        this.replacements = {};

        try {
            const result = await getTemplatePreviewData({ templateId: this._templateId });
            if (result && result.template) {
                this.processTemplateData(result);
            } else {
                this.hasError = true;
            }
        } catch (error) {
            console.error('Error fetching template preview data:', error);
            this.hasError = true;
        } finally {
            this.isLoading = false;
        }
    }

    /**
     * Strips HTML tags or entities if a field was rich-text formatted.
     */
    cleanMediaUrl(val) {
        if (!val || typeof val !== 'string') return '';
        let str = val.trim();
        if (str.includes('<') && str.includes('>')) {
            try {
                const parser = new DOMParser();
                const doc = parser.parseFromString(str, 'text/html');
                str = doc.documentElement.textContent || '';
                str = str.trim();
            } catch (e) {
                str = str.replace(/<[^>]+>/g, '').trim();
            }
        }
        return str;
    }

    /**
     * Checks if a string looks like a valid URL or media source path.
     */
    isLikelyUrl(val) {
        if (!val || typeof val !== 'string') return false;
        const str = val.trim().toLowerCase();
        return (
            str.startsWith('http://') ||
            str.startsWith('https://') ||
            str.startsWith('/') ||
            str.startsWith('data:') ||
            str.startsWith('blob:') ||
            str.includes('amazonaws.com') ||
            str.includes('.s3.')
        );
    }

    /**
     * Formats URL with protocol if missing (e.g. direct S3 hostnames).
     */
    normalizeMediaUrl(val) {
        const cleaned = this.cleanMediaUrl(val);
        if (!cleaned) return '';
        if (cleaned.startsWith('//')) {
            return `https:${cleaned}`;
        }
        if ((cleaned.includes('amazonaws.com') || cleaned.includes('.s3.')) && !cleaned.startsWith('http://') && !cleaned.startsWith('https://')) {
            return `https://${cleaned}`;
        }
        return cleaned;
    }

    /**
     * Extracts a human-readable file name from URL path or query string.
     */
    extractFileName(url) {
        if (!url || typeof url !== 'string') return '';
        try {
            const clean = url.split('?')[0].split('#')[0];
            const lastPart = clean.substring(clean.lastIndexOf('/') + 1);
            return decodeURIComponent(lastPart);
        } catch (e) {
            return '';
        }
    }

    /**
     * Resolves the media URL from template fields:
     * 1. Header_Body__c (when header is Image, Video, or Document, this stores the media link)
     * 2. Template_Miscellaneous_Data__c (contentVersionId -> /sfc/servlet.shepherd/version/download/...)
     * 3. Image_Header_Handle__c (if containing a URL rather than an opaque Meta handle)
     */
    resolveMediaUrl(template, headerType) {
        if (!template) return '';

        const normalizedType = (headerType || '').trim().toLowerCase();
        const isMedia = ['image', 'video', 'document', 'location'].includes(normalizedType);

        // 1. Check Header_Body__c (standard location for tempImgUrl / media link)
        const rawHeaderBody = template.Header_Body__c || template.MVEX__Header_Body__c || template.MVEX__WBHeader_Body__c;
        const cleanedHeaderBody = this.normalizeMediaUrl(rawHeaderBody);
        if (isMedia && this.isLikelyUrl(cleanedHeaderBody)) {
            return cleanedHeaderBody;
        }

        // 2. Check Template_Miscellaneous_Data__c for contentVersionId or stored file URLs
        const rawMisc = template.Template_Miscellaneous_Data__c || template.MVEX__Template_Miscellaneous_Data__c;
        if (rawMisc) {
            try {
                const misc = typeof rawMisc === 'string' ? JSON.parse(rawMisc) : rawMisc;
                if (misc && misc.contentVersionId) {
                    return `/sfc/servlet.shepherd/version/download/${misc.contentVersionId}`;
                }
                if (misc && misc.awsFileUrl && this.isLikelyUrl(misc.awsFileUrl)) {
                    return this.normalizeMediaUrl(misc.awsFileUrl);
                }
                if (misc && misc.fileUrl && this.isLikelyUrl(misc.fileUrl)) {
                    return this.normalizeMediaUrl(misc.fileUrl);
                }
            } catch (e) {
                console.warn('Could not parse Template_Miscellaneous_Data__c:', e);
            }
        }

        // 3. Check Image_Header_Handle__c (in case a direct URL was stored instead of handle)
        const rawHandle = template.Image_Header_Handle__c || template.MVEX__Image_Header_Handle__c || template.Header_Handle__c || template.MVEX__Header_Handle__c || template.MVEX__WBImage_Header_Handle__c;
        const cleanedHandle = this.normalizeMediaUrl(rawHandle);
        if (this.isLikelyUrl(cleanedHandle)) {
            return cleanedHandle;
        }

        // 4. Fallback if Header_Body__c is non-empty without spaces/newlines
        if (isMedia && cleanedHeaderBody && !cleanedHeaderBody.includes('\n') && !cleanedHeaderBody.includes(' ')) {
            return cleanedHeaderBody;
        }

        return '';
    }

    /**
     * Parses the template record, headers, body formatting, variables, and buttons.
     */
    processTemplateData(data) {
        try {
            const template = data.template || data;
            this._currentTemplate = template;
            const variables = data.variables || [];
            this.variables = variables;

            // Reset media load flags
            this.imageLoadFailed = false;
            this.videoLoadFailed = false;

            // Handle detected objects for merge variables
            const detected = data.detectedObjects || [];
            if (Array.isArray(detected) && detected.length > 0) {
                this.detectedObjects = detected;
                this.activeObjectName = detected[0];
            } else if (variables.length > 0) {
                const uniqueObjs = [...new Set(variables.map(v => v.objectName || v.objName).filter(Boolean))];
                this.detectedObjects = uniqueObjs.length > 0 ? uniqueObjs : ['Contact'];
                this.activeObjectName = this.detectedObjects[0];
            } else {
                this.detectedObjects = [];
                this.activeObjectName = 'Contact';
            }

            // Header handling
            this.headerType = template.Header_Type__c || template.MVEX__Header_Type__c || template.headerType || 'None';
            const normalizedType = this.normalizedHeaderType;

            if (normalizedType === 'text') {
                this.rawHeaderText = template.Header_Body__c || template.MVEX__Header_Body__c || template.MVEX__WBHeader_Body__c || '';
                this.headerMediaUrl = '';
            } else if (['image', 'video', 'document', 'location'].includes(normalizedType)) {
                this.rawHeaderText = '';
                this.headerMediaUrl = this.resolveMediaUrl(template, this.headerType);
            } else {
                this.rawHeaderText = '';
                this.headerMediaUrl = '';
            }

            const explicitName = template.File_Name__c || template.MVEX__File_Name__c;
            const extractedName = this.extractFileName(this.headerMediaUrl);
            this.documentName = explicitName || extractedName || 'Document.pdf';

            // Body handling
            this.rawBodyText = template.Template_Body__c || '';

            // Footer handling
            this.footerText = template.Footer_Body__c || '';

            // Buttons handling
            const buttonRaw = template.Button_Body__c;
            this.buttons = this.parseButtons(buttonRaw);

            this.hasError = false;

            // Prefetch recent records if variables exist
            if (this.hasVariables) {
                this.fetchRecordsForActiveObject('');
            }
        } catch (err) {
            console.error('Error processing template preview data:', err);
            this.hasError = true;
        }
    }

    /**
     * Fetches search results / recent records for active sObject.
     */
    async fetchRecordsForActiveObject(term) {
        if (!this.activeObjectName) return;
        this.isSearchingRecords = true;

        try {
            const results = await searchPreviewRecords({
                objectName: this.activeObjectName,
                searchTerm: term || ''
            });

            this.searchResults = (results || []).map(r => ({
                id: r.id,
                title: r.title,
                subtitle: r.subtitle
            }));
        } catch (e) {
            console.error('Error searching records:', e);
            this.searchResults = [];
        } finally {
            this.isSearchingRecords = false;
        }
    }

    /**
     * Combobox trigger click toggles the dropdown and auto-focuses search input.
     */
    handleComboboxToggle() {
        this.isComboboxOpen = !this.isComboboxOpen;
        if (this.isComboboxOpen) {
            this.searchTerm = '';
            this.fetchRecordsForActiveObject('');
            setTimeout(() => {
                const input = this.template.querySelector('.combobox-search-input');
                if (input) {
                    input.focus();
                }
            }, 60);
        }
    }

    /**
     * Prevents search input clicks from closing or re-toggling the combobox.
     */
    handleSearchInputClick(event) {
        event.stopPropagation();
    }

    /**
     * Filters record options as user types in combobox.
     */
    handleSearchInput(event) {
        this.searchTerm = event.target.value;
        clearTimeout(this._searchTimeout);
        this._searchTimeout = setTimeout(() => {
            this.fetchRecordsForActiveObject(this.searchTerm);
        }, 200);
    }

    /**
     * Closes dropdown when focus leaves the combobox wrapper.
     */
    handleComboboxFocusOut(event) {
        const wrapper = event.currentTarget;
        const relatedTarget = event.relatedTarget;
        if (relatedTarget && wrapper && wrapper.contains(relatedTarget)) {
            return;
        }
        this.isComboboxOpen = false;
    }

    /**
     * Selecting a record fetches its live fields and replaces variable tokens in the preview.
     */
    async handleOptionSelect(event) {
        const recordId = event.currentTarget.dataset.id;
        const record = this.searchResults.find(r => r.id === recordId);
        if (!record) return;

        this.selectedRecord = record;
        this.isComboboxOpen = false;
        this.isLoading = true;

        try {
            const result = await getTemplatePreviewDataWithRecord({
                templateId: this.templateId,
                objectName: this.activeObjectName,
                recordId: record.id
            });

            if (result) {
                this.replacedHeaderText = result.replacedHeader || '';
                this.replacedBodyText = result.replacedBody || '';
                this.replacements = result.replacements || {};

                // If media header and replaced header contains a dynamic URL from the record
                if (this.isMediaHeader && result.replacedHeader && this.isLikelyUrl(result.replacedHeader)) {
                    this.headerMediaUrl = this.normalizeMediaUrl(result.replacedHeader);
                    this.imageLoadFailed = false;
                    this.videoLoadFailed = false;
                }
            }
        } catch (error) {
            console.error('Error fetching preview data with record:', error);
        } finally {
            this.isLoading = false;
        }
    }

    /**
     * Selecting the default option reverts to raw placeholders.
     */
    handleSelectDefaultTemplate() {
        this.selectedRecord = null;
        this.replacedHeaderText = '';
        this.replacedBodyText = '';
        this.replacements = {};
        this.isComboboxOpen = false;
        if (this._currentTemplate && this.isMediaHeader) {
            this.headerMediaUrl = this.resolveMediaUrl(this._currentTemplate, this.headerType);
            this.imageLoadFailed = false;
            this.videoLoadFailed = false;
        }
    }

    /**
     * Clears selected record and reverts to raw template placeholders.
     */
    handleClearRecord(event) {
        if (event) {
            event.stopPropagation();
        }
        this.selectedRecord = null;
        this.replacedHeaderText = '';
        this.replacedBodyText = '';
        this.replacements = {};
        if (this._currentTemplate && this.isMediaHeader) {
            this.headerMediaUrl = this.resolveMediaUrl(this._currentTemplate, this.headerType);
            this.imageLoadFailed = false;
            this.videoLoadFailed = false;
        }
    }

    /**
     * Handles switching between objects if variables reference multiple objects.
     */
    handleSelectObjectTab(event) {
        const objectName = event.currentTarget.dataset.object;
        if (objectName && objectName !== this.activeObjectName) {
            this.activeObjectName = objectName;
            this.handleClearRecord();
            this.fetchRecordsForActiveObject('');
        }
    }

    /**
     * Formats WhatsApp markdown and replaces variables with styled badges or merged values.
     */
    applyFormatting(rawText, isReplaced = false) {
        if (!rawText) return '';

        // Escape raw HTML characters to prevent XSS injection
        let text = rawText
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;');

        if (!isReplaced) {
            // Render variable tokens as distinct highlighted pill badges
            text = text.replace(/\{\{([a-zA-Z0-9_]+)\}\}/g, (match, varName) => {
                let label = match;
                if (Array.isArray(this.variables)) {
                    const found = this.variables.find(v => v.name === varName || v.Name === varName);
                    if (found && found.alternateText) {
                        label = found.alternateText;
                    }
                }
                return `<span class="preview-var-badge">${label}</span>`;
            });
        }

        // WhatsApp Markdown parsing
        text = text.replaceAll('\n', '<br/>');
        text = text.replace(/\*(.*?)\*/g, '<b>$1</b>');
        text = text.replace(/_(.*?)_/g, '<i>$1</i>');
        text = text.replace(/~(.*?)~/g, '<s>$1</s>');
        text = text.replace(/```(.*?)```/g, '<code>$1</code>');

        return text;
    }

    /**
     * Parses the button JSON and attaches appropriate icons.
     */
    parseButtons(rawButtons) {
        if (!rawButtons) return [];
        let parsed = [];

        try {
            if (typeof rawButtons === 'string') {
                parsed = JSON.parse(rawButtons);
            } else if (Array.isArray(rawButtons)) {
                parsed = rawButtons;
            }
        } catch (e) {
            console.warn('Could not parse button body JSON:', rawButtons);
            return [];
        }

        if (!Array.isArray(parsed)) return [];

        return parsed.map((btn, index) => {
            const btnType = (btn.type || btn.buttonType || '').toUpperCase();
            let iconName = 'utility:reply';

            if (btnType === 'PHONE_NUMBER' || btnType === 'CALL_PHONE') {
                iconName = 'utility:call';
            } else if (btnType === 'URL') {
                iconName = 'utility:new_window';
            } else if (btnType === 'OTP' || btnType === 'COPY_CODE') {
                iconName = 'utility:copy';
            } else if (btnType === 'QUICK_REPLY' || btn.isMarketingOpt || btnType === 'MARKETING OPT-OUT') {
                iconName = 'utility:reply';
            }

            return {
                id: `btn-${index}`,
                btntext: btn.text || btn.label || btn.btntext || 'Action',
                iconName: iconName,
                type: btnType
            };
        });
    }

    get hasVariables() {
        return Array.isArray(this.variables) && this.variables.length > 0;
    }

    get variableBadgeLabel() {
        const count = this.variables ? this.variables.length : 0;
        return `${count} ${count === 1 ? 'Variable' : 'Variables'}`;
    }

    get hasMultipleObjects() {
        return Array.isArray(this.detectedObjects) && this.detectedObjects.length > 1;
    }

    get objectTabList() {
        return (this.detectedObjects || []).map(obj => ({
            name: obj,
            className: `object-tab-btn ${obj === this.activeObjectName ? 'active' : ''}`
        }));
    }

    get selectedDisplayLabel() {
        if (this.selectedRecord) {
            return this.selectedRecord.title;
        }
        return `Select a ${this.activeObjectName} record...`;
    }

    get comboboxTriggerClass() {
        return `combobox-trigger ${this.isComboboxOpen ? 'open' : ''}`;
    }

    get comboboxTriggerTextClass() {
        return `combobox-trigger-text ${!this.selectedRecord ? 'combobox-placeholder' : ''}`;
    }

    get comboboxArrowClass() {
        return `combobox-arrow ${this.isComboboxOpen ? 'open' : ''}`;
    }

    get searchPlaceholder() {
        return `Search ${this.activeObjectName} records...`;
    }

    get filteredRecordOptions() {
        const selectedId = this.selectedRecord ? this.selectedRecord.id : null;
        return (this.searchResults || []).map(r => {
            const isSelected = r.id === selectedId;
            return {
                ...r,
                isSelected: isSelected,
                optionClass: `combobox-option ${isSelected ? 'combobox-option--selected' : ''}`
            };
        });
    }

    get noResults() {
        return (!this.searchResults || this.searchResults.length === 0) && !this.isSearchingRecords;
    }

    get displayedHeaderText() {
        if (this.selectedRecord && this.replacedHeaderText) {
            return this.replacedHeaderText;
        }
        return this.rawHeaderText;
    }

    get formattedBody() {
        if (this.selectedRecord && this.replacedBodyText) {
            return this.applyFormatting(this.replacedBodyText, true);
        }
        return this.applyFormatting(this.rawBodyText, false);
    }

    handleImageError() {
        this.imageLoadFailed = true;
    }

    handleVideoError() {
        this.videoLoadFailed = true;
    }

    get normalizedHeaderType() {
        return (this.headerType || '').trim().toLowerCase();
    }

    get isTextHeader() {
        return this.normalizedHeaderType === 'text' && !!this.displayedHeaderText;
    }

    get isImageHeader() {
        return this.normalizedHeaderType === 'image';
    }

    get isVideoHeader() {
        return this.normalizedHeaderType === 'video';
    }

    get isDocHeader() {
        return this.normalizedHeaderType === 'document';
    }

    get isLocationHeader() {
        return this.normalizedHeaderType === 'location';
    }

    get isMediaHeader() {
        return ['image', 'video', 'document', 'location'].includes(this.normalizedHeaderType);
    }

    get hasValidImageUrl() {
        if (this.imageLoadFailed) return false;
        return !!this.headerMediaUrl && this.isLikelyUrl(this.headerMediaUrl);
    }

    get hasValidVideoUrl() {
        if (this.videoLoadFailed) return false;
        return !!this.headerMediaUrl && this.isLikelyUrl(this.headerMediaUrl);
    }

    get hasValidDocUrl() {
        return !!this.headerMediaUrl && this.isLikelyUrl(this.headerMediaUrl);
    }

    get imageUploadPreview() {
        return `${waIcons}/imageUploadPreview.png`;
    }

    get tempVideoIcon() {
        return `${waIcons}/tempVideoIcon.png`;
    }

    get docUploadPreviewImg() {
        return `${waIcons}/documentPreviewIcon.png`;
    }

    get hasButtons() {
        return Array.isArray(this.buttons) && this.buttons.length > 0;
    }

    get chatBubbleClass() {
        return `whatsapp-bubble ${this.hasButtons ? 'with-buttons' : 'no-buttons'}`;
    }
}