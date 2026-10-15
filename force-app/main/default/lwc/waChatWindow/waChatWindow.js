import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { loadScript, loadStyle } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { subscribe } from 'lightning/empApi';

// Apex imports from WAChatWindowController
import getCombinedData from '@salesforce/apex/WAChatWindowController.getCombinedData';
import createChat from '@salesforce/apex/WAChatWindowController.createChat';
import createChatForAWSFiles from '@salesforce/apex/WAChatWindowController.createChatForAWSFiles';
import updateReaction from '@salesforce/apex/WAChatWindowController.updateReaction';
import sendWhatsappMessage from '@salesforce/apex/WAChatWindowController.sendWhatsappMessage';
import updateStatus from '@salesforce/apex/WAChatWindowController.updateStatus';
import getTemplatesOnly from '@salesforce/apex/WAChatWindowController.getTemplatesOnly';
import sendSelectedTemplate from '@salesforce/apex/WAChatWindowController.sendSelectedTemplate';
import hasBusinessAccountId from '@salesforce/apex/WATemplateHomePageController.hasBusinessAccountId';

// AWS & Static resources
import getS3ConfigSettings from '@salesforce/apex/ImageAndMediaController.getS3ConfigSettings';
import waJSONFiles from '@salesforce/resourceUrl/waJSONFiles';
import waIcons from '@salesforce/resourceUrl/waIcons';
import AWS_SDK from '@salesforce/resourceUrl/AWSSDK';
import globalStyles from '@salesforce/resourceUrl/globalStyles';

export default class WaChatWindow extends NavigationMixin(LightningElement) {
    _recordId;
    @track chats = [];
    @track recordData;
    @track groupedChats = [];
    @track messageText = '';
    @track selectedTemplate = null;
    @track allTemplates = [];
    @track templateSearchKey = null;
    @track emojiCategories = [];
    @track replyToMessage = null;
    @track reactToMessage = null;
    @track noteText = 'The 24-hour conversation window has closed. Begin by sending an approved template.';
    @track showSpinner = false;
    @track isSendingMessage = false;
    @track noChatMessages = true;
    @track showEmojiPicker = false;
    @track showAttachmentOptions = false;
    @track scrollBottom = false;
    @track showReactEmojiPicker = false;
    @track sendOnlyTemplate = true;
    @track acceptedFormats = [];
    @track showFileUploader = false;
    @track showTemplateSelection = false;
    @track showTemplatePreview = false;
    @track uploadFileType = null;
    get NoPreviewAvailable() {
        return `${waIcons}/NoPreviewAvailable.png`;
    }
    @track audioPreview = false;
    @track audioURL = '';
    @track isAWSEnabled = false;
    @track confData;
    @track s3;
    @track selectedFilesToUpload = [];
    @track selectedFileName;
    @track showLicenseError = false;
    @track phoneNumber = '';
    @track recordName = '';
    @track subscription = {};
    @track chatwindowerror = '';
    @track showchatwindowerror = false;
    @track isErrorBannerDismissed = false;
    @track hasBusinessAccountConfigured = false;

    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        const changed = value && value !== this._recordId;
        this._recordId = value;
        if (changed && this.hasBusinessAccountConfigured) {
            this.getInitialData();
        }
    }

    get contactInitials() {
        if (this.recordName && this.recordName.trim().length > 0) {
            const parts = this.recordName.trim().split(/\s+/);
            if (parts.length >= 2) {
                return (parts[0][0] + parts[1][0]).toUpperCase();
            }
            return parts[0].substring(0, 2).toUpperCase();
        }
        return 'WA';
    }

    get recordNameDisplay() {
        return this.recordName || 'WhatsApp Contact';
    }

    get phoneNumberDisplay() {
        return this.phoneNumber ? this.phoneNumber : 'No Phone Number';
    }

    get showPopup() {
        return this.showFileUploader || this.showTemplateSelection || this.showTemplatePreview;
    }

    get displayBackDrop() {
        return this.showEmojiPicker || this.showAttachmentOptions || this.audioPreview || this.showReactEmojiPicker;
    }

    get messageDraftClass() {
        return (this.showAttachmentOptions || this.showEmojiPicker) ? 'message-draft-div has-open-popover' : 'message-draft-div';
    }

    get selectedTemplateRecord() {
        return (this.allTemplates || []).find(t => t.Id === this.selectedTemplate);
    }

    get previewTemplateName() {
        const t = this.selectedTemplateRecord;
        return t?.Template_Name__c || t?.MVEX__Template_Name__c || t?.Name || 'Template Preview';
    }

    get previewTemplateCategory() {
        const t = this.selectedTemplateRecord;
        return t?.Template_Category__c || t?.MVEX__Template_Category__c || 'Marketing';
    }

    get previewTemplateLanguage() {
        const t = this.selectedTemplateRecord;
        return t?.Language__c || t?.MVEX__Language__c || '';
    }

    get popupTitle() {
        if (this.showFileUploader) {
            return 'Upload ' + (this.uploadFileType || 'File');
        }
        if (this.showTemplatePreview) {
            return 'Preview Template';
        }
        if (this.showTemplateSelection) {
            return 'Select WhatsApp Template';
        }
        return '';
    }

    get popupSubtitle() {
        if (this.showFileUploader) {
            return 'Choose a file to attach and send to recipient';
        }
        if (this.showTemplatePreview) {
            return 'Review the template formatting before sending';
        }
        if (this.showTemplateSelection) {
            return 'Pick an approved Meta template to start or continue the conversation';
        }
        return '';
    }

    get uploadLabel() {
        return 'Upload ' + (this.uploadFileType || 'File');
    }

    get filteredTemplate() {
        const templates = (this.allTemplates || []).map(t => ({
            ...t,
            displayName: t.Template_Name__c || t.MVEX__Template_Name__c || t.Name || ''
        }));

        if (!this.templateSearchKey) {
            return templates.length > 0 ? templates : null;
        }

        const key = this.templateSearchKey.toLowerCase();
        const res = templates.filter(t => t.displayName.toLowerCase().includes(key));
        return res.length > 0 ? res : null;
    }

    get showChatWindow() {
        return !this.showLicenseError;
    }

    get showChatWarningBanner() {
        if (this.isErrorBannerDismissed) {
            return false;
        }
        if (this.showchatwindowerror) {
            return !this.noChatMessages;
        }
        return !this.noChatMessages && this.sendOnlyTemplate;
    }

    get chatWarningBannerText() {
        if (this.showchatwindowerror) {
            return this.chatwindowerror;
        }
        return '24-Hour Policy: The conversation window has closed (last chat gap is more than 24 hours). Re-open it by sending an approved template.';
    }

    get showChatEmptyErrorState() {
        return this.noChatMessages && this.showchatwindowerror;
    }

    get showChatEmptyNormalState() {
        return this.noChatMessages && !this.showchatwindowerror;
    }

    get chatEmptyErrorTitle() {
        return !this.phoneNumber ? 'Phone Number Required' : 'Notice';
    }

    handleDismissErrorBanner() {
        this.isErrorBannerDismissed = true;
    }

    get footerNoticePrefix() {
        return this.noChatMessages ? 'New Conversation:' : '24h Policy:';
    }

    get footerNoticeText() {
        return this.noChatMessages
            ? 'The conversation has not started yet. Begin by sending an approved template.'
            : 'The conversation window has closed (last chat gap is more than 24 hours). Re-open by sending an approved template.';
    }

    connectedCallback() {
        try {
            loadStyle(this, globalStyles);
            loadScript(this, AWS_SDK);
            this.checkBusinessAccountConfig();
        } catch (e) {
            console.error('Error in connectedCallback:::', e.message);
        }
    }

    renderedCallback() {
        try {
            if (this.scrollBottom) {
                const chatDiv = this.template.querySelector('.chat-div');
                if (chatDiv) {
                    chatDiv.scrollTop = chatDiv.scrollHeight;
                }
                this.scrollBottom = false;
            }
        } catch (e) {
            console.error('Error in renderedCallback:::', e.message);
        }
    }

    async checkBusinessAccountConfig() {
        try {
            this.showSpinner = true;
            const result = await hasBusinessAccountId();
            this.hasBusinessAccountConfigured = result;

            if (!this.hasBusinessAccountConfigured) {
                this.showSpinner = false;
                return;
            }

            this.initializeData();
        } catch (error) {
            console.error('Error checking business account configuration:', error);
            this.showSpinner = false;
        }
    }

    initializeData() {
        this.getS3ConfigDataAsync();
        this.getInitialData();
        this.generateEmojiCategories();
        this.handleSubscribe();
    }

    /**
     * Subscribes to WhatsApp platform event updates (new, status, reactions, templates)
     */
    handleSubscribe() {
        const self = this;
        const messageCallback = function (response) {
            try {
                const payload = response?.data?.payload;
                if (!payload) return;

                const actionType = payload.Type__c || payload.MVEX__Type__c;
                if (actionType === 'refresh-template' || actionType === 'delete' || actionType === 'undelete') {
                    self.refreshTemplateList();
                    return;
                }

                const rawChatJson = payload.Chat_Data__c || payload.MVEX__Chat_Data__c;
                const receivedChat = rawChatJson ? JSON.parse(rawChatJson) : null;
                if (!receivedChat) return;

                const eventPhone = payload.ContactId__c || payload.MVEX__ContactId__c;
                if (eventPhone && self.phoneNumber && eventPhone !== self.phoneNumber) return;

                const normChat = self.normalizeChat(receivedChat);
                const chatIndex = self.chats?.findIndex(ch => ch.Id === normChat.Id);
                const existingChat = chatIndex > -1 ? self.chats[chatIndex] : null;

                switch (actionType) {
                    case 'new':
                        if (!existingChat) {
                            self.chats = [...self.chats, normChat];
                            self.processChats(true);
                        }
                        break;

                    case 'status':
                        if (existingChat && normChat.Message_Status__c !== undefined) {
                            self.chats = self.chats.map((ch, idx) =>
                                idx === chatIndex ? { ...ch, Message_Status__c: normChat.Message_Status__c } : ch
                            );
                            self.processChats();
                        }
                        break;

                    case 'react':
                        if (existingChat) {
                            self.chats = self.chats.map((ch, idx) =>
                                idx === chatIndex ? { ...ch, Reaction__c: normChat.Reaction__c } : ch
                            );
                            self.processChats();
                        }
                        break;

                    case 'update':
                        if (existingChat && normChat.Message__c !== undefined) {
                            self.chats = self.chats.map((ch, idx) =>
                                idx === chatIndex ? { ...ch, Message__c: normChat.Message__c } : ch
                            );
                            self.processChats();
                        }
                        break;

                    case 'delete':
                        if (self.chats && normChat.Id) {
                            self.chats = self.chats.filter(ch => ch.Id !== normChat.Id);
                            self.processChats();
                        }
                        break;

                    default:
                        break;
                }
            } catch (error) {
                console.error('Error in handleSubscribe messageCallback:', error);
            }
        };

        // Attempt subscribe to standard event then namespace event fallback
        subscribe('/event/Chat_Message__e', -1, messageCallback)
            .then(res => { this.subscription = res; })
            .catch(() => {
                subscribe('/event/MVEX__Chat_Message__e', -1, messageCallback)
                    .then(res => { this.subscription = res; })
                    .catch(err => console.warn('Platform event subscription skipped:', err));
            });
    }

    /**
     * Normalizes a raw chat object so that standard un-prefixed fields are always available
     */
    normalizeChat(rawChat) {
        if (!rawChat) return rawChat;
        return {
            ...rawChat,
            Id: rawChat.Id,
            Message__c: rawChat.Message__c ?? rawChat.MVEX__Message__c ?? '',
            Message_Type__c: rawChat.Message_Type__c ?? rawChat.MVEX__Message_Type__c ?? 'Text',
            Type_of_Message__c: rawChat.Type_of_Message__c ?? rawChat.MVEX__Type_of_Message__c ?? 'Outbound Messages',
            Message_Status__c: rawChat.Message_Status__c ?? rawChat.MVEX__Message_Status__c ?? null,
            Message_ID__c: rawChat.Message_ID__c ?? rawChat.WhatsAppMessageId__c ?? rawChat.MVEX__WhatsAppMessageId__c ?? '',
            Reaction__c: rawChat.Reaction__c ?? rawChat.MVEX__Reaction__c ?? null,
            WA_Template__c: rawChat.WA_Template__c ?? rawChat.WhatsappTemplate__c ?? rawChat.MVEX__WhatsappTemplate__c ?? null,
            WA_Template__r: rawChat.WA_Template__r ?? rawChat.WhatsappTemplate__r ?? rawChat.MVEX__WhatsappTemplate__r ?? null,
            Reply_to__c: rawChat.Reply_to__c ?? rawChat.Reply_To__c ?? rawChat.MVEX__Reply_to__c ?? null,
            File_Data__c: rawChat.File_Data__c ?? rawChat.MVEX__File_Data__c ?? null,
            Sent_Template_Details__c: rawChat.Sent_Template_Details__c ?? rawChat.MVEX__Sent_Template_Details__c ?? null,
            CreatedDate: rawChat.CreatedDate
        };
    }

    /**
     * Safely adds or updates a chat in the chats list avoiding duplicate entries
     */
    upsertChat(normChat) {
        if (!normChat || !normChat.Id) return;
        const chats = this.chats ? [...this.chats] : [];
        const idx = chats.findIndex(c => c.Id === normChat.Id);
        if (idx > -1) {
            chats[idx] = { ...chats[idx], ...normChat };
        } else {
            chats.push(normChat);
        }
        this.chats = chats;
    }

    getInitialData() {
        this.showSpinner = true;
        this.sendOnlyTemplate = true;
        this.isErrorBannerDismissed = false;
        this.showchatwindowerror = false;
        this.chatwindowerror = '';
        this.noteText = 'The 24-hour conversation window has closed. Begin by sending an approved template.';
        try {
            getCombinedData({ contactId: this.recordId })
                .then(combinedData => {
                    if (combinedData?.record) {
                        this.recordData = combinedData.record;
                        const configuredPhoneField = combinedData.phoneField;
                        this.phoneNumber = combinedData.phoneNumber || (configuredPhoneField && this.recordData && this.recordData[configuredPhoneField] ? this.recordData[configuredPhoneField] : '') || '';
                        this.recordName = combinedData.recordName || (this.recordData ? this.recordData.Name : '');

                        if (!this.phoneNumber) {
                            this.chatwindowerror = 'The selected record does not have a phone number configured in WhatsApp settings.';
                            this.showchatwindowerror = true;
                        } else {
                            this.phoneNumber = this.phoneNumber.replaceAll(' ', '');
                        }
                    } else {
                        if (combinedData?.error) {
                            this.chatwindowerror = combinedData.error;
                            this.showchatwindowerror = true;
                        } else {
                            this.chatwindowerror = "Could not retrieve record information.";
                            this.showchatwindowerror = true;
                        }
                        this.chats = [];
                        this.processChats(false);
                        this.showSpinner = false;
                        return;
                    }

                    this.allTemplates = combinedData.templates && combinedData.templates.length > 0 ? combinedData.templates : [];
                    const rawChats = combinedData.chats || [];
                    this.chats = rawChats.map(c => this.normalizeChat(c));
                    this.showSpinner = false;
                    this.processChats(true);

                    // Mark unread inbound messages as seen
                    if (this.phoneNumber) {
                        const chatIdsToSeen = [];
                        this.chats.filter(ch => !(ch.Type_of_Message__c || '').toLowerCase().includes('outbound')).forEach(ch => {
                            if (ch.Message_Status__c !== 'Seen') chatIdsToSeen.push(ch.Id);
                        });
                        if (chatIdsToSeen.length > 0) {
                            updateStatus({ messageIds: chatIdsToSeen });
                        }
                    }
                })
                .catch(e => {
                    this.showSpinner = false;
                    this.chatwindowerror = e?.body?.message || e?.message || 'Error loading WhatsApp chat data.';
                    this.showchatwindowerror = true;
                    this.chats = [];
                    this.processChats(false);
                    console.error('Error in getCombinedData:', e.message);
                });
        } catch (e) {
            this.showSpinner = false;
            this.chatwindowerror = e.message || 'Error initializing chat window.';
            this.showchatwindowerror = true;
            this.chats = [];
            this.processChats(false);
            console.error('Error in getInitialData:::', e.message);
        }
    }

    handleManualRefresh() {
        this.getInitialData();
    }

    refreshTemplateList() {
        try {
            getTemplatesOnly()
                .then(templates => {
                    this.allTemplates = templates && templates.length > 0 ? templates : [];
                })
                .catch(e => {
                    console.error('Error in refreshTemplateList:', e.message);
                });
        } catch (e) {
            console.error('Error in refreshTemplateList:::', e.message);
        }
    }

    processChats(needToScroll) {
        try {
            this.noChatMessages = !this.chats || this.chats.length < 1;
            if (this.noChatMessages) {
                this.sendOnlyTemplate = true;
                this.noteText = "The conversation has not started yet. Begin by sending an approved template.";
                this.groupedChats = [];
                return;
            }

            const processed = this.chats.map(ch => {
                const item = this.normalizeChat(ch);
                const isOutbound = (item.Type_of_Message__c || '').toLowerCase().includes('outbound');

                item.isOutbound = isOutbound;
                item.isText = item.Message_Type__c === 'Text';
                item.isImage = item.Message_Type__c === 'Image';
                item.isVideo = item.Message_Type__c === 'Video';
                item.isAudio = item.Message_Type__c === 'Audio';
                item.isDoc = item.Message_Type__c === 'Document';
                item.isFlow = item.Message_Type__c === 'interactive';
                item.isFlowResponse = item.isFlow && !isOutbound;
                item.isTemplate = item.Message_Type__c === 'Template' || (item.isFlow && isOutbound);
                item.isOther = !['Text', 'Image', 'Template', 'Video', 'Document', 'Audio', 'interactive'].includes(item.Message_Type__c);
                item.messageBy = isOutbound ? 'You' : (this.recordName || 'Contact');

                // Template card properties for native WhatsApp chat-window structure
                if (item.isTemplate) {
                    const temp = item.WA_Template__r;
                    item.templateHeader = temp?.Header_Body__c || '';
                    item.headerType = (temp?.Header_Type__c || 'NONE').toUpperCase();
                    item.isTextHeader = item.headerType === 'TEXT' && !!item.templateHeader;
                    item.isImageHeader = item.headerType === 'IMAGE';
                    item.isVideoHeader = item.headerType === 'VIDEO';
                    item.isDocHeader = item.headerType === 'DOCUMENT';
                    item.hasTemplateHeader = item.isTextHeader || item.isImageHeader || item.isVideoHeader || item.isDocHeader;
                    item.headerMediaUrl = (['IMAGE', 'VIDEO', 'DOCUMENT'].includes(item.headerType) && temp?.Header_Body__c)
                        ? temp.Header_Body__c
                        : (temp?.Image_Header_Handle__c || '');

                    item.templateBody = item.Message__c || temp?.Template_Body__c || '';
                    item.templateFooter = temp?.Footer_Body__c || '';
                    item.templateButtons = this.parseTemplateButtons(temp?.Button_Body__c);
                    item.hasButtons = item.templateButtons && item.templateButtons.length > 0;
                }

                // Status flags - only outbound (sent) messages show status ticks
                const statusLower = (item.Message_Status__c || '').toLowerCase();
                item.isSeen = isOutbound && (statusLower === 'seen' || statusLower === 'read');
                item.isDelivered = isOutbound && statusLower === 'delivered';
                item.isSent = isOutbound && statusLower === 'sent';
                item.isFailed = isOutbound && statusLower === 'failed';
                item.isSending = isOutbound && (!item.Message_Status__c || statusLower === 'sending');
                item.isTick = isOutbound && (item.isSeen || item.isDelivered || item.isSent);

                // File parsing
                if ((item.isDoc || item.isAudio) && item.File_Data__c) {
                    try {
                        const fileData = JSON.parse(item.File_Data__c);
                        item.fileName = fileData?.fileName || 'Attachment';
                        if (item.Message__c?.includes('amazonaws.com') && item.isDoc) {
                            item.isAWSFile = true;
                            item.isPreviewable = (fileData?.mimeType || '').includes('pdf');
                        } else {
                            item.isAWSFile = false;
                            item.contentDocumentId = fileData?.documentId;
                            item.fileUrl = `/sfc/servlet.shepherd/version/download/${fileData?.contentVersionId}?as=${item.fileName}`;
                        }
                    } catch (err) {
                        item.fileName = 'Attachment';
                    }
                }

                // Bubble class & full-row class for WhatsApp inbound/outbound styling
                item.className = isOutbound ? 'sent-message' : 'received-message';
                item.rowClass = `message-full-length-div ${item.className}`;

                // Copy text (available for text & template messages)
                item.copyText = item.isTemplate ? (item.templateBody || item.Message__c || '') : (item.Message__c || '');
                item.hasCopyText = !!(item.copyText && item.copyText.trim());

                // Reactions
                let yourReaction = item.Reaction__c?.split('<|USER|>')[0];
                let userReaction = item.Reaction__c?.split('<|USER|>')[1];
                item.yourReaction = yourReaction;
                item.userReaction = userReaction;
                item.isReaction = !!(yourReaction || userReaction);

                // Reply to
                item.replyTo = this.chats.find(c => c.Id === item.Reply_to__c);

                return item;
            });

            // Group by Date
            const today = new Date();
            const yesterday = new Date(today);
            yesterday.setDate(yesterday.getDate() - 1);
            const dateOptions = { day: '2-digit', month: 'short', year: 'numeric' };

            const groups = processed.reduce((acc, ch) => {
                const createDate = new Date(ch.CreatedDate).toLocaleDateString('en-GB', dateOptions);
                let dateGroup = createDate === today.toLocaleDateString('en-GB', dateOptions)
                    ? 'Today'
                    : (createDate === yesterday.toLocaleDateString('en-GB', dateOptions) ? 'Yesterday' : createDate);

                if (!acc[dateGroup]) {
                    acc[dateGroup] = [];
                }
                acc[dateGroup].push(ch);
                return acc;
            }, {});

            this.groupedChats = Object.entries(groups).map(([date, messages]) => ({
                date,
                messages
            }));

            if (needToScroll) {
                this.scrollBottom = true;
            }
            this.checkLastMessage();
        } catch (e) {
            console.error('Error in function processChats:::', e.message);
        }
    }

    /**
     * Parses raw button JSON from WA_Template__c into structured action buttons
     */
    parseTemplateButtons(rawButtons) {
        if (!rawButtons) return [];
        let parsed = [];
        try {
            if (typeof rawButtons === 'string') {
                parsed = JSON.parse(rawButtons);
            } else if (Array.isArray(rawButtons)) {
                parsed = rawButtons;
            }
        } catch (e) {
            return [];
        }
        if (!Array.isArray(parsed)) return [];
        return parsed.map((btn, index) => {
            const btnType = (btn.type || btn.buttonType || '').toUpperCase();
            return {
                id: `btn-${index}`,
                btntext: btn.text || btn.label || btn.btntext || 'Action',
                type: btnType,
                isUrl: btnType === 'URL',
                isCall: btnType === 'PHONE_NUMBER' || btnType === 'CALL_PHONE',
                isQuickReply: !['URL', 'PHONE_NUMBER', 'CALL_PHONE'].includes(btnType)
            };
        });
    }

    /**
     * Checks WhatsApp 24-hour conversation care window:
     * Outside of 24h from last inbound message, only approved templates may be sent.
     */
    checkLastMessage() {
        try {
            if (!this.chats || this.chats.length === 0) {
                this.sendOnlyTemplate = true;
                this.noteText = "The conversation has not started yet. Begin by sending an approved template.";
                return;
            }

            const currentTime = new Date();

            // Find latest chat overall
            const allChatsWithDate = this.chats.filter(msg => msg.CreatedDate);
            const sortedAll = [...allChatsWithDate].sort((a, b) => new Date(b.CreatedDate) - new Date(a.CreatedDate));
            const lastChat = sortedAll.length > 0 ? sortedAll[0] : null;

            // Find latest inbound message
            const inboundMessages = this.chats.filter(msg => {
                const type = (msg.Type_of_Message__c || '').toLowerCase();
                return type.includes('inbound') && msg.CreatedDate;
            });
            const sortedInbound = [...inboundMessages].sort((a, b) => new Date(b.CreatedDate) - new Date(a.CreatedDate));
            const lastInbound = sortedInbound.length > 0 ? sortedInbound[0] : null;

            let isGapOver24Hours = false;

            if (lastInbound) {
                const inboundHoursDiff = (currentTime - new Date(lastInbound.CreatedDate)) / (1000 * 60 * 60);
                if (inboundHoursDiff > 24) {
                    isGapOver24Hours = true;
                }
            } else if (lastChat) {
                const chatHoursDiff = (currentTime - new Date(lastChat.CreatedDate)) / (1000 * 60 * 60);
                if (chatHoursDiff > 24) {
                    isGapOver24Hours = true;
                } else {
                    isGapOver24Hours = true;
                }
            } else {
                isGapOver24Hours = true;
            }

            if (isGapOver24Hours) {
                this.sendOnlyTemplate = true;
                this.noteText = "The 24-hour customer window is closed (last chat gap is more than 24 hours). Re-open it by sending an approved template.";
            } else {
                this.sendOnlyTemplate = false;
                this.noteText = "";
            }
        } catch (e) {
            console.error('Error in checkLastMessage:::', e.message);
            this.sendOnlyTemplate = true;
            this.noteText = "The 24-hour conversation window has closed. Begin by sending an approved template.";
        }
    }

    handleBackDropClick() {
        try {
            this.reactToMessage = null;
            this.showReactEmojiPicker = false;
            this.showFileUploader = false;
            this.showTemplateSelection = false;
            this.showTemplatePreview = false;
            this.acceptedFormats = [];
            this.uploadFileType = null;
            this.showEmojiPicker = false;
            this.showAttachmentOptions = false;
            this.selectedTemplate = null;
            this.templateSearchKey = null;
            this.audioPreview = false;
            this.audioURL = '';
            this.selectedFileName = null;
            this.selectedFilesToUpload = [];

            const fileInput = this.template?.querySelector('input[type="file"]');
            if (fileInput) {
                fileInput.value = null;
            }
            this.handleCloseAllActionMenus();
        } catch (e) {
            console.error('Error in handleBackDropClick:::', e.message);
        }
    }

    handleToggleActions(event) {
        event.stopPropagation();
        try {
            const btn = event.currentTarget;
            const wasOpen = btn.classList.contains('show-options');
            this.handleCloseAllActionMenus();
            if (!wasOpen) {
                btn.classList.add('show-options');
                const row = btn.closest('.message-full-length-div');
                if (row) row.classList.add('menu-open-row');
            }
        } catch (e) {
            console.error('Error in handleToggleActions:::', e.message);
        }
    }

    handleCloseAllActionMenus() {
        try {
            this.template?.querySelectorAll('.action-options-btn.show-options').forEach(el => {
                el.classList.remove('show-options');
            });
            this.template?.querySelectorAll('.menu-open-row').forEach(el => {
                el.classList.remove('menu-open-row');
            });
        } catch (e) {
            console.error('Error in handleCloseAllActionMenus:::', e.message);
        }
    }

    handleHideActions(event) {
        try {
            const row = event.currentTarget;
            if (row && !row.classList.contains('menu-open-row')) {
                row.querySelector('.action-options-btn')?.classList.remove('show-options');
            }
        } catch (e) {
            console.error('Error in handleHideActions:::', e.message);
        }
    }

    handleChatAction(event) {
        event.stopPropagation();
        try {
            const actionType = event.currentTarget.dataset.action;
            const chatId = event.currentTarget.dataset.chat;

            this.handleCloseAllActionMenus();

            if (actionType === 'reply') {
                this.replyToMessage = this.chats?.find(chat => chat.Id === chatId);
                const inputEl = this.template.querySelector('.message-input');
                if (inputEl) inputEl.focus();
            } else if (actionType === 'react') {
                this.reactToMessage = chatId;
                this.showReactEmojiPicker = true;
            } else if (actionType === 'copy') {
                const text = event.currentTarget.dataset.message || '';
                if (text && navigator.clipboard) {
                    navigator.clipboard.writeText(text);
                    this.showToast('Copied', 'Message text copied to clipboard.', 'success');
                } else if (text) {
                    // Fallback copy
                    const tempInput = document.createElement('textarea');
                    tempInput.value = text;
                    document.body.appendChild(tempInput);
                    tempInput.select();
                    document.execCommand('copy');
                    document.body.removeChild(tempInput);
                    this.showToast('Copied', 'Message text copied to clipboard.', 'success');
                }
            } else if (actionType === 'cancel-reply') {
                this.replyToMessage = null;
            } else if (actionType === 'cancel-react') {
                this.reactToMessage = null;
                this.showReactEmojiPicker = false;
            }
        } catch (e) {
            console.error('Error in handleChatAction:::', e.message);
        }
    }

    handleReactWithEmoji(event) {
        try {
            if (this.reactToMessage) {
                const chat = this.chats?.find(ch => ch.Id === this.reactToMessage);
                if (chat) {
                    const emoji = event.target.innerText;
                    chat.Reaction__c = emoji + (chat.Reaction__c ? chat.Reaction__c.slice(chat.Reaction__c.indexOf('<|USER|>')) : '<|USER|>');
                    this.reactToMessage = null;
                    this.showReactEmojiPicker = false;
                    this.updateMessageReaction(chat);
                }
            }
        } catch (e) {
            console.error('Error in handleReactWithEmoji:::', e.message);
        }
    }

    handleRemoveReaction(event) {
        try {
            const chat = this.chats?.find(c => c.Id === event.currentTarget.dataset.chat);
            if (chat) {
                chat.Reaction__c = chat.Reaction__c?.slice(chat.Reaction__c.indexOf('<|USER|>'));
                this.updateMessageReaction(chat);
            }
        } catch (e) {
            console.error('Error in handleRemoveReaction:::', e.message);
        }
    }

    handleReplyMessageClick(event) {
        try {
            const replyTo = event.currentTarget.dataset.replyTo;
            const replyEl = this.template.querySelector(`.message-full-length-div[data-id="${replyTo}"]`);
            if (replyEl) {
                replyEl.scrollIntoView({ behavior: 'smooth', block: 'center' });
                replyEl.classList.add('highlight-reply');
                setTimeout(() => {
                    replyEl.classList.remove('highlight-reply');
                }, 1500);
            }
        } catch (e) {
            console.error('Error in handleReplyMessageClick:::', e.message);
        }
    }

    handleToggleImagePreview(event) {
        try {
            const action = event.currentTarget.dataset.action;
            if (action === 'open') {
                event.currentTarget.classList.add('show-image-preview');
            } else if (action === 'close') {
                const el = this.template.querySelector('.show-image-preview');
                if (el) el.classList.remove('show-image-preview');
                event.stopPropagation();
            }
        } catch (e) {
            console.error('Error in handleToggleImagePreview:::', e.message);
        }
    }

    handleToggleAudioPreview(event) {
        const audioUrl = event.currentTarget.dataset.url;
        this.audioURL = audioUrl;
        this.audioPreview = !this.audioPreview;
    }

    handleImageError(event) {
        try {
            event.currentTarget.src = this.NoPreviewAvailable;
            event.currentTarget.parentNode?.classList?.add('not-loaded-image');
        } catch (e) {
            console.error('Error in handleImageError:::', e.message);
        }
    }

    handleScroll(event) {
        // Optional scroll event handler
    }

    async generateEmojiCategories() {
        try {
            const fetchEmoji = async (fileName) => {
                try {
                    const res = await fetch(`${waJSONFiles}/${fileName}`);
                    const okRes = res.ok ? res : await fetch(`${waJSONFiles}/${fileName.replace(/\.json$/, '')}`);
                    return await okRes.json();
                } catch (err) {
                    return null;
                }
            };

            let data = await fetchEmoji('whatsapp-emojis.json');
            if (!data) {
                data = await fetchEmoji('whatsapp-emojis');
            }

            if (data && Array.isArray(data)) {
                const grouped = Object.values(
                    data.reduce((acc, item) => {
                        const cat = item.category;
                        if (!acc[cat]) {
                            acc[cat] = { category: cat, emojis: [] };
                        }
                        acc[cat].emojis.push(item);
                        return acc;
                    }, {})
                );
                this.emojiCategories = grouped;
            }
        } catch (e) {
            console.error('Error in generateEmojiCategories from waJSONFiles:', e);
        }
    }

    handleEmojiButtonClick() {
        this.showEmojiPicker = !this.showEmojiPicker;
        this.showAttachmentOptions = false;
    }

    handleEmojiClick(event) {
        try {
            const textarea = this.template.querySelector('.message-input');
            if (textarea) {
                const text = textarea.value || '';
                const pos = textarea.selectionStart;
                const emoji = event.target.innerText;
                textarea.value = text.slice(0, pos) + emoji + text.slice(pos);
                textarea.focus();
                textarea.setSelectionRange(pos + emoji.length, pos + emoji.length);
            }
        } catch (e) {
            console.error('Error in handleEmojiClick:::', e.message);
        }
    }

    handleMessageInput(event) {
        const textarea = event.target;
        textarea.style.height = 'auto';
        textarea.style.height = `${Math.min(textarea.scrollHeight, 120)}px`;
    }

    handleMessageTextChange(event) {
        try {
            const isMobile = /Mobi|Android|iPhone|iPad|iPod/i.test(navigator.userAgent);
            if (!isMobile && event.key === 'Enter') {
                if (event.shiftKey || event.ctrlKey || event.altKey) {
                    return;
                }
                event.preventDefault();
                event.stopPropagation();
                if (!this.isSendingMessage) {
                    this.handleSendMessage();
                }
            }
        } catch (e) {
            console.error('Error in handleMessageTextChange:::', e.message);
        }
    }

    handleAttachmentButtonClick() {
        this.showAttachmentOptions = !this.showAttachmentOptions;
        this.showEmojiPicker = false;
    }

    handleAttachmentOptionClick(event) {
        try {
            const mediaType = event.currentTarget.dataset.media;
            this.checkLastMessage();

            if (this.sendOnlyTemplate && mediaType !== 'Template') {
                this.showToast('Notice', 'Only approved templates can be sent outside the 24-hour window.', 'info');
                return;
            }

            this.showAttachmentOptions = false;

            switch (mediaType) {
                case 'Template':
                    this.templateSearchKey = null;
                    this.selectedTemplate = null;
                    this.showFileUploader = false;
                    this.showTemplatePreview = false;
                    this.showTemplateSelection = true;
                    this.replyToMessage = null;
                    break;
                case 'Image':
                    this.showFileUploader = true;
                    this.acceptedFormats = ['.jpg', '.png', '.jpeg', '.jpe'];
                    this.uploadFileType = 'Image';
                    break;
                case 'Document':
                    this.showFileUploader = true;
                    this.acceptedFormats = ['.txt', '.xls', '.xlsx', '.doc', '.docx', '.ppt', '.pptx', '.pdf'];
                    this.uploadFileType = 'Document';
                    break;
                case 'Video':
                    this.showFileUploader = true;
                    this.acceptedFormats = ['.3gp', '.mp4'];
                    this.uploadFileType = 'Video';
                    break;
                case 'Audio':
                    this.showFileUploader = true;
                    this.acceptedFormats = ['.aac', '.amr', '.mp3', '.m4a', '.ogg'];
                    this.uploadFileType = 'Audio';
                    break;
                default:
                    break;
            }
        } catch (e) {
            console.error('Error in handleAttachmentOptionClick:::', e.message);
        }
    }

    handleUploadFinished(event) {
        this.showSpinner = true;
        try {
            if (!(event.detail.files.length > 0)) {
                this.handleBackDropClick();
                this.showSpinner = false;
                return;
            }

            const file = event.detail.files[0];
            let messageType = 'Document';
            if (file.mimeType.includes('image/')) {
                messageType = 'Image';
            } else if (file.mimeType.includes('audio/')) {
                messageType = 'Audio';
            } else if (file.mimeType.includes('video/')) {
                messageType = 'Video';
            }

            createChat({
                chatData: {
                    message: file.contentVersionId,
                    templateId: this.selectedTemplate,
                    messageType: messageType,
                    recordId: this.recordId,
                    replyToChatId: this.replyToMessage?.Id || null,
                    phoneNumber: this.phoneNumber,
                }
            })
            .then(chat => {
                if (chat) {
                    const norm = this.normalizeChat(chat);
                    this.upsertChat(norm);
                    this.processChats(true);

                    const payload = this.createJSONBody(this.phoneNumber, messageType, this.replyToMessage?.Message_ID__c || null, {
                        link: norm.Message__c,
                        fileName: file.name || 'whatsapp file'
                    });

                    sendWhatsappMessage({ jsonData: payload, chatId: norm.Id, isReaction: false, reaction: null })
                        .then(res => {
                            if (res.chat) {
                                const updated = this.normalizeChat(res.chat);
                                const idx = this.chats.findIndex(c => c.Id === updated.Id);
                                if (idx > -1) this.chats[idx] = updated;
                            }
                            this.replyToMessage = null;
                            this.showSpinner = false;
                            this.processChats(true);
                        })
                        .catch(err => {
                            this.showSpinner = false;
                            console.error('Error in sendWhatsappMessage:', err);
                        });

                    this.handleBackDropClick();
                } else {
                    this.showSpinner = false;
                    this.showToast('Error', 'File could not be uploaded. Ensure size is under 5MB.', 'error');
                }
            })
            .catch(err => {
                this.showSpinner = false;
                this.showToast('Error', 'Error uploading file.', 'error');
                console.error(err);
            });
        } catch (e) {
            this.showSpinner = false;
            console.error('Error in handleUploadFinished:::', e.message);
        }
    }

    handleSearchTemplate(event) {
        this.templateSearchKey = event.target.value || null;
    }

    handleShowTemplatePreview(event) {
        const tId = event.currentTarget.dataset.id;
        if (tId) {
            this.selectedTemplate = tId;
            this.showTemplateSelection = false;
            this.showTemplatePreview = true;
        }
    }

    handleBackToList() {
        this.selectedTemplate = null;
        this.showTemplatePreview = false;
        this.showTemplateSelection = true;
    }

    /**
     * Dispatches selected template to recipient
     */
    async handleSendSelectedTemplateClick() {
        if (!this.selectedTemplate) return;
        this.showSpinner = true;
        try {
            const result = await sendSelectedTemplate({
                templateId: this.selectedTemplate,
                recordId: this.recordId,
                phoneNumber: this.phoneNumber
            });

            if (result && result.success) {
                this.showToast('Success', 'Template sent successfully!', 'success');
                if (result.chat) {
                    this.upsertChat(this.normalizeChat(result.chat));
                }
                this.handleBackDropClick();
                this.processChats(true);
            } else {
                this.showToast('Error', result?.message || 'Failed to send template.', 'error');
            }
        } catch (error) {
            console.error('Error in handleSendSelectedTemplateClick:', error);
            this.showToast('Error', error?.body?.message || error?.message || 'Error sending template', 'error');
        } finally {
            this.showSpinner = false;
        }
    }

    createJSONBody(to, type, replyId, data) {
        try {
            let payload = `{ "messaging_product": "whatsapp", "to": "${to}", "type": "${type.toLowerCase()}"`;

            if (replyId) {
                payload += `, "context": {"message_id": "${replyId}"}`;
            }

            if (type === 'text') {
                payload += `, "text": { "body": "${(data.textBody || '').replace(/"/g, '\\"').replace(/\n/g, '\\n')}" }`;
            } else if (type === 'Image') {
                payload += `, "image": { "link": "${data.link}" }`;
            } else if (type === 'Video') {
                payload += `, "video": { "link": "${data.link}" }`;
            } else if (type === 'Document') {
                payload += `, "document": { "link": "${data.link}", "filename": "${data.fileName}" }`;
            } else if (type === 'Audio') {
                payload += `, "audio": { "link": "${data.link}" }`;
            } else if (type === 'reaction') {
                payload += `, "reaction": { "message_id": "${data.reactToId}", "emoji": "${data.emoji}" }`;
            }
            payload += ` }`;
            return payload;
        } catch (e) {
            console.error('Error in createJSONBody:::', e.message);
            return '{}';
        }
    }

    updateMessageReaction(chat) {
        try {
            updateReaction({ chatId: chat.Id, reaction: chat.Reaction__c })
                .then(() => {
                    this.processChats();
                    const reactPayload = this.createJSONBody(this.phoneNumber, 'reaction', null, {
                        reactToId: chat.Message_ID__c,
                        emoji: chat.Reaction__c?.split('<|USER|>')[0] || ''
                    });

                    sendWhatsappMessage({ jsonData: reactPayload, chatId: chat.Id, isReaction: true, reaction: chat.Reaction__c })
                        .then(res => {
                            if (res.chat) {
                                const updated = this.normalizeChat(res.chat);
                                const idx = this.chats.findIndex(c => c.Id === updated.Id);
                                if (idx > -1) this.chats[idx].Reaction__c = updated.Reaction__c;
                                this.processChats();
                            }
                        })
                        .catch(err => console.error('Error in sendWhatsappMessage reaction:', err));
                })
                .catch(err => {
                    this.showToast('Error', 'Could not update reaction.', 'error');
                    console.error(err);
                });
        } catch (e) {
            console.error('Error in updateMessageReaction:::', e.message);
        }
    }

    handleSendMessage() {
        if (this.isSendingMessage) {
            return;
        }

        try {
            this.handleBackDropClick();
            const textarea = this.template.querySelector('.message-input');
            const message = (textarea?.value || '').trim();

            this.checkLastMessage();
            if (this.sendOnlyTemplate) {
                this.showToast('Notice', 'Cannot send freeform text outside the 24-hour window. Please send an approved template.', 'info');
                return;
            }

            if (!message) {
                return;
            }

            this.isSendingMessage = true;
            this.showSpinner = true;

            // Immediately clear textarea so double clicks/enter cannot re-read identical text
            if (textarea) {
                textarea.value = '';
                textarea.style.height = 'auto';
            }

            const replyChatId = this.replyToMessage?.Id || null;
            const replyMessageId = this.replyToMessage?.Message_ID__c || null;
            this.replyToMessage = null;

            createChat({
                chatData: {
                    message: message,
                    templateId: null,
                    messageType: 'text',
                    recordId: this.recordId,
                    replyToChatId: replyChatId,
                    phoneNumber: this.phoneNumber
                }
            })
            .then(chat => {
                if (chat) {
                    const norm = this.normalizeChat(chat);
                    this.upsertChat(norm);
                    this.processChats(true);

                    const textPayload = this.createJSONBody(this.phoneNumber, 'text', replyMessageId, {
                        textBody: message
                    });

                    sendWhatsappMessage({ jsonData: textPayload, chatId: norm.Id, isReaction: false, reaction: null })
                        .then(res => {
                            if (res.chat) {
                                const updated = this.normalizeChat(res.chat);
                                const idx = this.chats.findIndex(c => c.Id === updated.Id);
                                if (idx > -1) {
                                    this.chats[idx].Message_Status__c = updated.Message_Status__c;
                                    this.chats[idx].Message_ID__c = updated.Message_ID__c;
                                }
                            }
                            this.processChats();
                        })
                        .catch(err => {
                            console.error('Error in sendWhatsappMessage text:', err);
                        })
                        .finally(() => {
                            this.showSpinner = false;
                            this.isSendingMessage = false;
                        });
                } else {
                    this.showSpinner = false;
                    this.isSendingMessage = false;
                    if (textarea) textarea.value = message;
                    this.showToast('Error', 'Message could not be created.', 'error');
                }
            })
            .catch(e => {
                this.showSpinner = false;
                this.isSendingMessage = false;
                if (textarea) textarea.value = message;
                const msg = e?.body?.message === 'STORAGE_LIMIT_EXCEEDED' ? 'Storage Limit Exceeded.' : 'Message could not be sent.';
                this.showToast('Error', msg, 'error');
            });
        } catch (e) {
            this.showSpinner = false;
            this.isSendingMessage = false;
            console.error('Error in handleSendMessage:::', e.message);
        }
    }

    getS3ConfigDataAsync() {
        try {
            getS3ConfigSettings()
                .then(res => {
                    if (res != null) {
                        this.confData = res;
                        this.isAWSEnabled = true;
                    }
                })
                .catch(err => console.warn('S3 config skipped:', err));
        } catch (err) {
            console.warn('getS3ConfigDataAsync error:', err);
        }
    }

    handleSelectedFiles(event) {
        try {
            const file = event.target.files[0];
            if (file) {
                const fileType = file.type;
                const sizeMB = file.size / (1024 * 1024);
                let maxSize = 100;
                if (fileType.includes('image/')) maxSize = 5;
                else if (fileType.includes('video/') || fileType.includes('audio/')) maxSize = 16;

                if (sizeMB <= maxSize) {
                    this.selectedFilesToUpload = [file];
                    this.selectedFileName = file.name;
                } else {
                    this.showToast('File Too Large', `${file.name} exceeds ${maxSize}MB limit`, 'error');
                }
            }
        } catch (e) {
            console.error('Error in handleSelectedFiles:', e);
        }
    }

    removeFile() {
        this.selectedFileName = null;
        this.selectedFilesToUpload = [];
        const input = this.template.querySelector('input[type="file"]');
        if (input) input.value = null;
    }

    async handleUploadClick() {
        if (this.selectedFilesToUpload.length > 0) {
            this.showSpinner = true;
            await this.uploadToAWS();
        }
    }

    async uploadToAWS() {
        try {
            this.showSpinner = true;
            this.initializeAwsSdk(this.confData);
            const file = this.selectedFilesToUpload[0];
            const objKey = this.renameFileName(file.name);

            const bucketName = this.confData.S3_Bucket_Name__c || this.confData.MVEX__S3_Bucket_Name__c;
            const params = {
                Key: objKey,
                ContentType: file.type,
                Body: file,
                ACL: 'public-read'
            };

            const upload = this.s3.upload(params);
            await upload.promise();

            const awsFileUrl = `https://${bucketName}.s3.amazonaws.com/${objKey}`;
            let messageType = 'Document';
            if (file.type.includes('image/')) messageType = 'Image';
            else if (file.type.includes('video/')) messageType = 'Video';
            else if (file.type.includes('audio/')) messageType = 'Audio';

            createChatForAWSFiles({
                chatData: {
                    message: awsFileUrl,
                    fileName: objKey,
                    mimeType: file.type,
                    messageType: messageType,
                    recordId: this.recordId,
                    replyToChatId: this.replyToMessage?.Id || null,
                    phoneNumber: this.phoneNumber
                }
            })
            .then(chat => {
                if (chat) {
                    const norm = this.normalizeChat(chat);
                    this.upsertChat(norm);
                    this.processChats(true);

                    const payload = this.createJSONBody(this.phoneNumber, messageType, this.replyToMessage?.Message_ID__c || null, {
                        link: awsFileUrl,
                        fileName: objKey
                    });

                    sendWhatsappMessage({ jsonData: payload, chatId: norm.Id, isReaction: false, reaction: null })
                        .then(res => {
                            if (res.chat) {
                                const updated = this.normalizeChat(res.chat);
                                const idx = this.chats.findIndex(c => c.Id === updated.Id);
                                if (idx > -1) {
                                    this.chats[idx].Message_Status__c = updated.Message_Status__c;
                                    this.chats[idx].Message_ID__c = updated.Message_ID__c;
                                }
                            }
                            this.showSpinner = false;
                            this.processChats(true);
                        })
                        .catch(err => {
                            this.showSpinner = false;
                            console.error('Error in sendWhatsappMessage AWS:', err);
                        });

                    this.handleBackDropClick();
                } else {
                    this.showSpinner = false;
                    this.showToast('Error', 'Could not create chat record for AWS file.', 'error');
                }
            })
            .catch(err => {
                this.showSpinner = false;
                this.showToast('Error', 'Upload failed.', 'error');
                console.error(err);
            });
        } catch (error) {
            this.showSpinner = false;
            console.error('Error in uploadToAWS:', error);
            this.showToast('Error', 'AWS upload failed.', 'error');
        }
    }

    initializeAwsSdk(confData) {
        try {
            const AWS = window.AWS;
            const accessKey = confData.AWS_Access_Key__c || confData.MVEX__AWS_Access_Key__c;
            const secretKey = confData.AWS_Secret_Access_Key__c || confData.MVEX__AWS_Secret_Access_Key__c;
            const region = confData.S3_Region_Name__c || confData.MVEX__S3_Region_Name__c;
            const bucket = confData.S3_Bucket_Name__c || confData.MVEX__S3_Bucket_Name__c;

            AWS.config.update({
                accessKeyId: accessKey,
                secretAccessKey: secretKey,
                region: region
            });

            this.s3 = new AWS.S3({
                apiVersion: '2006-03-01',
                params: { Bucket: bucket }
            });
        } catch (error) {
            console.error('Error initializing AWS SDK:', error);
        }
    }

    renameFileName(filename) {
        const lastDot = filename.lastIndexOf('.');
        const base = filename.substring(0, lastDot);
        const ext = filename.substring(lastDot + 1);
        return `${base.replace(/\s+/g, '_')}_${Date.now()}.${ext}`;
    }

    downloadRowImage(event) {
        try {
            const fileName = event.currentTarget.dataset.name;
            const vfPageUrl = `/apex/FileDownloadVFPage?fileName=${encodeURIComponent(fileName)}`;
            window.open(vfPageUrl, '_blank');
        } catch (error) {
            console.error('Error downloading file:', error);
        }
    }

    showToast(title, message, status) {
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: status,
            mode: 'dismissible'
        }));
    }

    /**
     * Navigates to Control Center to open WhatsApp configuration
     */
    navigateToWhatsAppIntegration(event) {
        try {
            if (event) {
                event.preventDefault();
            }

            this[NavigationMixin.GenerateUrl]({
                type: 'standard__navItemPage',
                attributes: {
                    apiName: 'Control_Center_Dev'
                },
                state: {
                    c__openComponent: 'whatsappConnect'
                }
            }).then((url) => {
                window.open(url, '_blank');
            }).catch(() => {
                this[NavigationMixin.GenerateUrl]({
                    type: 'standard__navItemPage',
                    attributes: {
                        apiName: 'Control_Center'
                    },
                    state: {
                        c__openComponent: 'whatsappConnect'
                    }
                }).then((url2) => {
                    window.open(url2, '_blank');
                }).catch(() => {
                    this[NavigationMixin.GenerateUrl]({
                        type: 'standard__navItemPage',
                        attributes: {
                            apiName: 'MVEX__Control_Center'
                        },
                        state: {
                            c__openComponent: 'whatsappConnect'
                        }
                    }).then((url3) => {
                        window.open(url3, '_blank');
                    }).catch(() => {
                        window.open('/lightning/n/Control_Center_Dev?c__openComponent=whatsappConnect', '_blank');
                    });
                });
            });
        } catch (error) {
            console.error('Error in navigateToWhatsAppIntegration: ', error);
            window.open('/lightning/n/Control_Center_Dev?c__openComponent=whatsappConnect', '_blank');
        }
    }
}