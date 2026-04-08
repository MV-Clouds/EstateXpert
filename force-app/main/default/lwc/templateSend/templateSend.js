import { LightningElement, api, track } from 'lwc';
import getTemplateData from '@salesforce/apex/ChatWindowController.getTemplateData';
import sendWhatsappMessage from '@salesforce/apex/ChatWindowController.sendWhatsappMessage';
import createChat from '@salesforce/apex/ChatWindowController.createChat';
import buildInteractivePayload from '@salesforce/apex/ChatWindowController.buildInteractivePayload';

/**
 * TemplateSend
 *
 * Renders a template preview (via c-template-message-preview) and provides
 * Back / Send action buttons. All preview rendering is delegated to the child.
 */
export default class TemplateSend extends LightningElement {

    // ─── @api (public) ────────────────────────────────────────────────────────

    @api templateId;
    @api recordId;
    @api objectApiName;
    @api mobileNumber;
    @api showButtons;

    // ─── Private fields ───────────────────────────────────────────────────────

    templateData;
    headerParams;
    bodyParams;
    isInteractiveTemplate = false;
    previewDataForChild;

    // ─── @track (reactive) ────────────────────────────────────────────────────

    @track showSpinner = false;

    // ─── Getters ──────────────────────────────────────────────────────────────

    get childPreviewData() {
        return this.previewDataForChild;
    }

    // ─── Lifecycle ────────────────────────────────────────────────────────────

    connectedCallback() {
        try {
            this.fetchTemplateMetadata();
        } catch (e) {
            console.error('Error in connectedCallback:::', e.message);
        }
    }

    // ─── Data Fetching ────────────────────────────────────────────────────────

    fetchTemplateMetadata() {
        this.showSpinner = true;
        try {
            getTemplateData({
                templateId: this.templateId,
                contactId: this.recordId,
                objectApiName: this.objectApiName
            })
                .then((result) => {
                    if (!result) {
                        this.showSpinner = false;
                        return;
                    }
                    this.templateData         = result.template;
                    this.headerParams         = result.headerParams;
                    this.bodyParams           = result.bodyParams;
                    this.isInteractiveTemplate = this.detectIsInteractive(result.template);
                    this.previewDataForChild  = {
                        template:             result.template,
                        templateMergeDetails: null,
                        headerParams:         result.headerParams,
                        bodyParams:           result.bodyParams
                    };
                    this.showSpinner = false;
                })
                .catch((e) => {
                    this.showSpinner = false;
                    console.error('Error in fetchTemplateMetadata > getTemplateData:::', e.message);
                });
        } catch (e) {
            this.showSpinner = false;
            console.error('Error in fetchTemplateMetadata:::', e.message);
        }
    }

    detectIsInteractive(template) {
        try {
            const body = template?.MVEX__WBTemplate_Body__c;
            if (!body) return false;
            const parsed = JSON.parse(body);
            return parsed?.type === 'interactive' && !!parsed?.interactive;
        } catch {
            return false;
        }
    }

    // ─── Event Handlers ───────────────────────────────────────────────────────

    handleBack() {
        try {
            this.dispatchEvent(new CustomEvent('back'));
        } catch (e) {
            console.error('Error in handleBack:::', e.message);
        }
    }

    handleSend() {
        this.showSpinner = true;
        try {
            const messageType = this.isInteractiveTemplate ? 'interactive' : 'template';
            createChat({
                chatData: {
                    message: '',
                    templateId: this.templateId,
                    messageType,
                    recordId: this.recordId,
                    replyToChatId: null,
                    phoneNumber: this.mobileNumber
                }
            })
                .then((chat) => {
                    if (!chat) {
                        this.showSpinner = false;
                        console.error('Error creating chat record for template send.');
                        return;
                    }
                    return this.isInteractiveTemplate
                        ? this.sendInteractiveMessage(chat.Id)
                        : this.sendStandardMessage(chat.Id);
                })
                .catch((e) => {
                    this.showSpinner = false;
                    console.error('Error in handleSend > createChat:::', e);
                });
        } catch (e) {
            this.showSpinner = false;
            console.error('Error in handleSend:::', e.message);
        }
    }

    // ─── Send Strategies ──────────────────────────────────────────────────────

    sendInteractiveMessage(chatId) {
        return buildInteractivePayload({
            templateId: this.templateId,
            contactId: this.recordId,
            objectApiName: this.objectApiName,
            phoneNumber: this.mobileNumber
        })
            .then((templatePayload) => {
                if (!templatePayload) {
                    this.showSpinner = false;
                    console.error('Interactive template payload could not be created.');
                    return null;
                }
                return sendWhatsappMessage({
                    jsonData: templatePayload,
                    chatId,
                    isReaction: false,
                    reaction: null
                });
            })
            .then((result) => {
                if (!result) return;
                this.showSpinner = false;
                this.dispatchEvent(new CustomEvent('message', { detail: result }));
            })
            .catch((e) => {
                this.showSpinner = false;
                console.error('Error in sendInteractiveMessage:::', e);
            });
    }

    sendStandardMessage(chatId) {
        const data = this.templateData;
        const templatePayload = this.buildStandardPayload({
            templateName:     data?.MVEX__Template_Name__c,
            languageCode:     data?.MVEX__Language__c,
            headerImageURL:   data?.MVEX__WBHeader_Body__c,
            headerType:       data?.MVEX__Header_Type__c,
            headerParameters: this.headerParams,
            bodyParameters:   this.bodyParams || '',
            buttonValue:      this.safeJsonParse(data?.MVEX__WBButton_Body__c) || ''
        });

        if (!templatePayload) {
            this.showSpinner = false;
            console.error('Standard template payload could not be created.');
            return Promise.resolve();
        }

        return sendWhatsappMessage({
            jsonData: templatePayload,
            chatId,
            isReaction: false,
            reaction: null
        })
            .then((result) => {
                this.showSpinner = false;
                this.dispatchEvent(new CustomEvent('message', { detail: result }));
            })
            .catch((e) => {
                this.showSpinner = false;
                console.error('Error in sendStandardMessage:::', e);
            });
    }

    // ─── Payload Builders ─────────────────────────────────────────────────────

    buildStandardPayload(data) {
        try {
            const randomCode = String(Math.floor(Math.random() * 900000) + 100000);
            const isAuth = this.templateData?.MVEX__Template_Category__c === 'Authentication';

            const payload = {
                messaging_product: 'whatsapp',
                to: this.mobileNumber,
                type: 'template',
                template: {
                    name: data.templateName,
                    language: { code: data.languageCode }
                }
            };

            const components = [];

            if (data.headerParameters?.length > 0) {
                components.push({
                    type: 'header',
                    parameters: data.headerParameters.map((param) => ({ type: 'text', text: param }))
                });
            }

            const mediaHeader = this.buildMediaHeaderComponent(data);
            if (mediaHeader) components.push(mediaHeader);

            if (data.bodyParameters?.length > 0) {
                components.push({
                    type: 'body',
                    parameters: data.bodyParameters.map((param) => ({ type: 'text', text: param }))
                });
            } else if (isAuth) {
                components.push({
                    type: 'body',
                    parameters: [{ type: 'text', text: randomCode }]
                });
            }

            if (data.buttonValue?.length > 0) {
                this.appendButtonComponents(components, data.buttonValue, randomCode);
            }

            if (components.length > 0) {
                payload.template.components = components;
            }

            return JSON.stringify(payload);
        } catch (e) {
            console.error('Error in buildStandardPayload:::', e.message);
            return null;
        }
    }

    buildMediaHeaderComponent(data) {
        const mediaMap = {
            Image:    { type: 'image',    key: 'image'    },
            Document: { type: 'document', key: 'document' },
            Video:    { type: 'video',    key: 'video'    }
        };
        const media = mediaMap[data.headerType];
        if (!media || !data.headerImageURL) return null;
        return {
            type: 'header',
            parameters: [{ type: media.type, [media.key]: { link: data.headerImageURL } }]
        };
    }

    appendButtonComponents(components, buttons, randomCode) {
        buttons.forEach((button, index) => {
            const type = (button.type || '').toUpperCase();
            switch (type) {
                case 'PHONE_NUMBER':
                    components.push({ type: 'button', sub_type: 'voice_call', index, parameters: [{ type: 'text', text: button.phone_number }] });
                    break;
                case 'FLOW':
                    components.push({ type: 'button', sub_type: 'flow', index, parameters: [{ type: 'payload', payload: 'PAYLOAD' }] });
                    break;
                case 'COPY_CODE':
                case 'COUPON_CODE':
                    components.push({ type: 'button', sub_type: 'copy_code', index, parameters: [{ type: 'coupon_code', coupon_code: button.example }] });
                    break;
                case 'OTP':
                    if (button.otp_type?.toUpperCase() === 'COPY_CODE') {
                        components.push({ type: 'button', sub_type: 'url', index, parameters: [{ type: 'text', text: randomCode }] });
                    } else {
                        console.warn(`OTP button at index ${index} missing otp_code parameter.`);
                    }
                    break;
                case 'URL':
                case 'QUICK_REPLY':
                    break;
                default:
                    console.warn(`Unknown button type: ${button.type}`);
            }
        });
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
}