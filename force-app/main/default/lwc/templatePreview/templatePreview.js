import { LightningElement, api, track } from 'lwc';
import getTemplatePreviewData from '@salesforce/apex/ChatWindowController.getTemplatePreviewData';
import NoPreviewAvailable from '@salesforce/resourceUrl/NoPreviewAvailable';

/**
 * TemplatePreview
 *
 * Renders a read-only WhatsApp template bubble.
 *
 * Mode A – standalone (chat history):
 *   Supply `templateId` + `chatId`. The component fetches its own data.
 *
 * Mode B – embedded inside templateSend:
 *   Supply `previewData` (pre-fetched by the parent). No Apex call is made.
 */
export default class TemplatePreview extends LightningElement {

    // ─── @api (public) ────────────────────────────────────────────────────────

    /** Mode A: chat-history record ID */
    @api templateId;
    /** Mode A: chat record ID */
    @api chatId;

    /**
     * Mode B: pre-fetched data from the parent.
     * Shape: { template, templateMergeDetails, headerParams, bodyParams }
     */
    @api
    get previewData() {
        return this.inflightPreviewData;
    }
    set previewData(value) {
        this.inflightPreviewData = value;
        if (value) {
            this.processTemplateData(value);
        }
    }

    // ─── Private fields ───────────────────────────────────────────────────────

    inflightPreviewData;
    NoPreviewAvailableImg = NoPreviewAvailable;

    // ─── @track (reactive) ────────────────────────────────────────────────────

    @track templateData;
    @track templateMergeDetails;
    @track headerBody;
    @track templateBody;
    @track footerBody;
    @track isTextHeader;
    @track isImageHeader;
    @track isVideoHeader;
    @track isDocHeader;
    @track headerParams;
    @track bodyParams;
    @track buttonList = [];
    @track isInteractiveTemplate = false;
    @track isInteractiveLocationRequest = false;
    @track isInteractiveList = false;
    @track isInteractiveButton = false;
    @track interactiveActionLabel = '';
    @track interactiveSections = [];
    @track interactiveButtons = [];
    @track isSecurityRecommedation = false;
    @track isCodeExpiration = false;
    @track expireTime;
    @track isTemplateDeleted = false;
    @track isUpdateBody = false;
    @track showSpinner = false;

    // ─── Getters ──────────────────────────────────────────────────────────────

    @api
    refreshComponent(templateId) {
        try {
            this.templateId = templateId;
            this.inflightPreviewData = null; // reset Mode B
            this.fetchInitialData(); // call Apex again
        } catch (e) {
            console.error('Error in refreshComponent:::', e);
        }
    }

    get hasStandardButtons() {
        return this.buttonList?.length > 0;
    }

    get hasInteractiveButtons() {
        return this.interactiveButtons?.length > 0;
    }

    get hasInteractiveSections() {
        return this.interactiveSections?.length > 0;
    }

    // ─── Lifecycle ────────────────────────────────────────────────────────────

    connectedCallback() {
        try {
            if (!this.inflightPreviewData) {
                this.fetchInitialData();
            }
        } catch (e) {
            console.error('Error in connectedCallback:::', e.message);
        }
    }

    renderedCallback() {
        try {
            const bodyText = this.template.querySelector('.body-text');
            if (bodyText && this.isUpdateBody) {
                bodyText.innerHTML = this.applyMarkdownFormatting(this.templateBody);
                this.isUpdateBody = false;
            }
        } catch (e) {
            console.error('Error in renderedCallback:::', e.message);
        }
    }

    // ─── Data Fetching ────────────────────────────────────────────────────────

    fetchInitialData() {
        this.showSpinner = true;
        try {
            getTemplatePreviewData({ templateId: this.templateId, chatId: this.chatId })
                .then((result) => {
                    if (!result) {
                        this.isTemplateDeleted = true;
                        this.showSpinner = false;
                        return;
                    }
                    this.processTemplateData(result);
                })
                .catch((e) => {
                    this.showSpinner = false;
                    console.error('Error in fetchInitialData > getTemplatePreviewData:::', e.message);
                });
        } catch (e) {
            this.showSpinner = false;
            console.error('Error in fetchInitialData:::', e.message);
        }
    }

    // ─── Core Processing ──────────────────────────────────────────────────────

    processTemplateData(rawData) {
        this.templateData           = rawData.template;
        this.templateMergeDetails   = rawData.templateMergeDetails;
        this.resetPreviewState();

        if (this.resolveInteractivePreview()) {
            if (rawData.headerParams) this.headerParams = rawData.headerParams;
            if (rawData.bodyParams)   this.bodyParams   = rawData.bodyParams;
            this.showSpinner  = false;
            this.isUpdateBody = true;
            return;
        }

        this.resolveStandardPreview(rawData);
    }

    resolveStandardPreview(rawData) {
        const data = this.templateData;

        this.isTextHeader  = data?.MVEX__Header_Type__c === 'Text';
        this.isImageHeader = data?.MVEX__Header_Type__c === 'Image';
        this.isVideoHeader = data?.MVEX__Header_Type__c === 'Video';
        this.isDocHeader   = data?.MVEX__Header_Type__c === 'Document';

        const miscData = this.safeJsonParse(data?.MVEX__Template_Miscellaneous_Data__c);
        this.isSecurityRecommedation = miscData?.isSecurityRecommedation || false;
        this.isCodeExpiration        = miscData?.isCodeExpiration || false;
        this.expireTime              = miscData?.expireTime;

        this.headerBody = this.decodeHtmlEntities(data?.MVEX__WBHeader_Body__c);

        if (this.isTextHeader && this.templateMergeDetails) {
            this.applyHeaderMergeFields();
        } else if (this.isImageHeader || this.isVideoHeader || this.isDocHeader) {
            this.applyHeaderMediaUrl();
        }

        this.templateBody = data?.MVEX__WBTemplate_Body__c;
        this.footerBody   = data?.MVEX__WBFooter_Body__c;

        if (data?.MVEX__Template_Category__c === 'Authentication') {
            this.templateBody = '{{code}} ' + this.templateBody;
            if (this.isSecurityRecommedation) {
                this.templateBody += '\n For your security, do not share this code.';
            }
            this.footerBody = this.isCodeExpiration
                ? `This code expires in ${this.expireTime} seconds.`
                : '';
        } else if (this.templateMergeDetails) {
            this.applyBodyMergeFields();
        }

        const buttonBody = this.safeJsonParse(data?.MVEX__WBButton_Body__c) || [];
        this.buttonList = buttonBody.map((btn, index) => ({
            id: index,
            btntext: btn.text?.trim(),
            btnType: btn.type,
            iconName: this.getIconName(btn.type)
        }));

        if (rawData.headerParams) this.headerParams = rawData.headerParams;
        if (rawData.bodyParams)   this.bodyParams   = rawData.bodyParams;

        this.showSpinner  = false;
        this.isUpdateBody = true;
    }

    resetPreviewState() {
        this.isTextHeader             = false;
        this.isImageHeader            = false;
        this.isVideoHeader            = false;
        this.isDocHeader              = false;
        this.headerBody               = '';
        this.templateBody             = '';
        this.footerBody               = '';
        this.buttonList               = [];
        this.isInteractiveTemplate    = false;
        this.isInteractiveLocationRequest = false;
        this.isInteractiveList        = false;
        this.isInteractiveButton      = false;
        this.interactiveActionLabel   = '';
        this.interactiveSections      = [];
        this.interactiveButtons       = [];
    }

    // ─── Interactive Preview ──────────────────────────────────────────────────

    resolveInteractivePreview() {
        const payloadSource = this.getInteractiveSentPayload() || this.templateData?.MVEX__WBTemplate_Body__c;
        const payload = this.safeJsonParse(payloadSource);

        if (!payload || payload?.type !== 'interactive' || !payload?.interactive) {
            return false;
        }

        const interactive    = payload.interactive;
        const interactiveType = (interactive?.type || '').toLowerCase();

        this.isInteractiveTemplate        = true;
        this.isInteractiveLocationRequest = interactiveType === 'location_request_message';
        this.isInteractiveList            = interactiveType === 'list';
        this.isInteractiveButton          = interactiveType === 'button';

        this.resolveInteractiveHeader(interactive?.header);
        this.templateBody = interactive?.body?.text || '';
        this.footerBody   = interactive?.footer?.text || '';

        if (this.isInteractiveLocationRequest) {
            this.interactiveActionLabel = interactive?.action?.name === 'send_location'
                ? 'Send Location'
                : (interactive?.action?.name || 'Location Request');

        } else if (this.isInteractiveButton) {
            this.interactiveButtons = (interactive?.action?.buttons || []).map((btn, index) => ({
                id: `btn-${index}`,
                btntext: btn?.reply?.title || btn?.title || `Button ${index + 1}`,
                iconName: 'utility:reply'
            }));

        } else if (this.isInteractiveList) {
            this.interactiveActionLabel = interactive?.action?.button || '';
            this.interactiveSections = (interactive?.action?.sections || []).map((section, sIdx) => ({
                id: `section-${sIdx}`,
                title: section?.title || '',
                rows: (section?.rows || []).map((row, rIdx) => ({
                    id: row?.id || `section-${sIdx}-row-${rIdx}`,
                    title: row?.title || '',
                    description: row?.description || ''
                }))
            }));
        }

        return true;
    }

    getInteractiveSentPayload() {
        if (!this.templateMergeDetails) return null;
        const outer = this.safeJsonParse(this.templateMergeDetails) || this.templateMergeDetails;
        const sentDetails = outer?.MVEX__Sent_Template_Details__c || outer?.Sent_Template_Details__c;
        return typeof sentDetails === 'string' && sentDetails.trim().length > 0 ? sentDetails : null;
    }

    resolveInteractiveHeader(headerData) {
        const headerType = (headerData?.type || '').toLowerCase();
        if (!headerType) return;

        this.isTextHeader  = headerType === 'text';
        this.isImageHeader = headerType === 'image';
        this.isVideoHeader = headerType === 'video';
        this.isDocHeader   = headerType === 'document';

        if      (this.isTextHeader)  this.headerBody = headerData?.text || '';
        else if (this.isImageHeader) this.headerBody = headerData?.image?.link || '';
        else if (this.isVideoHeader) this.headerBody = headerData?.video?.link || '';
        else if (this.isDocHeader)   this.headerBody = headerData?.document?.link || '';
    }

    // ─── Merge Field Helpers ──────────────────────────────────────────────────

    getParsedMergeDetails() {
        const parsedOuter = this.safeJsonParse(this.templateMergeDetails) || this.templateMergeDetails;
        const detailsStr  = parsedOuter?.MVEX__Sent_Template_Details__c || parsedOuter?.Sent_Template_Details__c;
        return this.safeJsonParse(detailsStr) || [];
    }

    applyBodyMergeFields() {
        try {
            const bodyParams = this.getParsedMergeDetails().find(c => c.type === 'body')?.parameters || [];
            let body = this.templateBody;
            for (let i = 0; i < bodyParams.length; i++) {
                body = body.replaceAll(`{{${i + 1}}}`, bodyParams[i]?.text || '');
            }
            this.templateBody = body;
        } catch (err) {
            console.error('Error in applyBodyMergeFields:::', err);
        }
    }

    applyHeaderMergeFields() {
        try {
            if (!this.isTextHeader) return;
            const headerVal = this.getParsedMergeDetails().find(c => c.type === 'header')?.parameters?.[0]?.text || '';
            const rawHeader = (this.templateData?.MVEX__WBHeader_Body__c || '').replace('{{1}}', headerVal);
            this.headerBody = this.decodeHtmlEntities(rawHeader);
        } catch (err) {
            console.error('Error in applyHeaderMergeFields:::', err);
        }
    }

    applyHeaderMediaUrl() {
        try {
            const headerComp = this.getParsedMergeDetails().find(c => c.type === 'header');
            if (!headerComp) return;
            const mediaParam = headerComp.parameters.find(p =>
                p.type === 'image' || p.type === 'video' || p.type === 'document'
            );
            this.headerBody = mediaParam?.image?.link
                || mediaParam?.video?.link
                || mediaParam?.document?.link
                || '';
        } catch (err) {
            console.error('Error in applyHeaderMediaUrl:::', err);
        }
    }

    // ─── Utilities ────────────────────────────────────────────────────────────

    safeJsonParse(data) {
        try {
            if (!data || typeof data !== 'string') {
                return typeof data === 'object' ? data : null;
            }
            return JSON.parse(data);
        } catch {
            return null;
        }
    }

    decodeHtmlEntities(html) {
        if (!html) return '';
        return new DOMParser().parseFromString(html, 'text/html').documentElement.textContent || '';
    }

    applyMarkdownFormatting(text) {
        if (!text) return '';
        return text
            .replaceAll(/\*(.+?)\*/g,     '<b>$1</b>')
            .replaceAll(/\_(.+?)\_/g,     '<i>$1</i>')
            .replaceAll(/\~(.+?)\~/g,     '<s>$1</s>')
            .replaceAll(/\```(.+?)\```/g, '<code>$1</code>');
    }

    getIconName(btntype) {
        const ICON_MAP = {
            QUICK_REPLY:  'utility:reply',
            PHONE_NUMBER: 'utility:call',
            URL:          'utility:new_window',
            COPY_CODE:    'utility:copy',
            Flow:         'utility:file'
        };
        return ICON_MAP[btntype] ?? 'utility:question';
    }
}