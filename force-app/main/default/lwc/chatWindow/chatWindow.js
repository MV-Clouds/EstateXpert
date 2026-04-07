import { LightningElement, api, track, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getCombinedData from '@salesforce/apex/ChatWindowController.getCombinedData';
import createChat from '@salesforce/apex/ChatWindowController.createChat';
import createChatForAWSFiles from '@salesforce/apex/ChatWindowController.createChatForAWSFiles';
import updateReaction from '@salesforce/apex/ChatWindowController.updateReaction';
import sendWhatsappMessage from '@salesforce/apex/ChatWindowController.sendWhatsappMessage';
import updateThemePreference from '@salesforce/apex/ChatWindowController.updateThemePreference';
import updateStatus from '@salesforce/apex/ChatWindowController.updateStatus';
import getS3ConfigSettings from '@salesforce/apex/AWSFilesController.getS3ConfigSettings';
import hasBusinessAccountId from '@salesforce/apex/PropertySearchController.hasBusinessAccountId';
import emojiData from '@salesforce/resourceUrl/emojis_data';
import NoPreviewAvailable from '@salesforce/resourceUrl/NoPreviewAvailable';
import whatsappAudioIcon from '@salesforce/resourceUrl/whatsAppAudioIcon';
import AWS_SDK from "@salesforce/resourceUrl/AWSSDK";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { NavigationMixin } from 'lightning/navigation';
import { loadScript } from 'lightning/platformResourceLoader';
import { subscribe} from 'lightning/empApi';

export default class ChatWindow extends NavigationMixin(LightningElement) {

    _recordId;
    @api height;
    @api isCalledFromGlobal = false;
    @track chats = [];
    @track recordData;
    @track groupedChats = [];
    @track isLightMode = true;
    @track messageText = '';
    @track selectedTemplate = null;
    @track allTemplates = [];
    @track templateSelectionMode = 'Template';
    @track templateSearchKey = null;
    @track emojiCategories = [];
    @track replyToMessage = null;
    @track reactToMessage = null;
    @track noteText = '';
    @track showSpinner = false;
    @track noChatMessages = true;
    @track showEmojiPicker = false;
    @track showAttachmentOptions = false;
    @track scrollBottom = false;
    @track showReactEmojiPicker = false;
    @track sendOnlyTemplate = false;
    @track acceptedFormats = [];
    @track showFileUploader = false;
    @track showTemplateSelection = false;
    @track showTemplatePreview = false;
    @track uploadFileType = null;
    @track NoPreviewAvailable = NoPreviewAvailable;
    @track headphone = whatsappAudioIcon;
    @track audioPreview = false;
    @track audioURL = '';
    @track isAWSEnabled = false;
    @track confData;
    @track s3;
    @track isAwsSdkInitialized = true;
    @track selectedFilesToUpload = [];
    @track selectedFileName;
    @track showLicenseError = false;
    @api objectApiName;
    @track phoneNumber;
    @track recordName;
    @track replyBorderColors = ['#34B7F1', '#FF9500', '#B38F00', '#ffa5c0', '#ff918b'];
    @track subscription = {};
    @track channelName = '/event/MVEX__Chat_Message__e';
    @track chatwindowerror = '';
    @track hasBusinessAccountConfigured = false;

    @wire(CurrentPageReference) pageRef;

    @api 
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        if (value && value !== this._recordId) {
            this._recordId = value;
            if(this.isCalledFromGlobal){
                this.connectedCallback();
            }
        }
    }

    //Get Variables
    get sunClass() {
        return `toggle-button sun-icon ${this.isLightMode ? "" : "hide"}`;
    }

    get moonClass() {
        return `toggle-button moon-icon ${this.isLightMode ? "hide" : "show"}`;
    }

    get mainChatWindowContainerClass(){
        return this.isCalledFromGlobal ? 'main-chat-window-div-for-global lightTheme' : 'main-chat-window-div lightTheme';
    }

    get showPopup(){
        return this.showFileUploader || this.showTemplateSelection || this.showTemplatePreview || this.audioPreview;
    }
    
    get displayBackDrop(){
        return this.showEmojiPicker || this.showAttachmentOptions || this.showFileUploader || this.showTemplateSelection || this.showTemplatePreview || this.audioPreview;
    }

    get uploadLabel(){
        return 'Upload '+ this.uploadFileType || 'File';
    }

    get filteredTemplate(){
        const sourceTemplates = (this.templateSelectionMode === 'Interactive Message'
            ? this.interactiveTemplates
            : this.standardTemplates) || [];
        const templatesWithDisplay = sourceTemplates.map(template => ({
            ...template,
            displayName: this.getTemplateDisplayName(template)
        }));
        const searchKey = this.templateSearchKey?.toLowerCase();
        let searchedResult = templatesWithDisplay.filter(template =>
            template.displayName.toLowerCase().includes(searchKey)
        );
        return this.templateSearchKey ? (searchedResult.length > 0 ? searchedResult : null) : templatesWithDisplay;
    }

    getTemplateDisplayName(template) {
        return template?.MVEX__Template_Name__c || template?.Name || '';
    }

    get standardTemplates() {
        return (this.allTemplates || []).filter(template => !this.isInteractiveTemplateRecord(template));
    }

    get interactiveTemplates() {
        return (this.allTemplates || []).filter(template => this.isInteractiveTemplateRecord(template));
    }

    get templateSelectionTitle() {
        return this.templateSelectionMode === 'Interactive Message'
            ? 'Select Interactive Message'
            : 'Select Template';
    }

    get recordMobileNumber(){
        return this.phoneNumber;
    }

    get replyToTemplateId(){
        return this.allTemplates.find(t => t.Id == this.replyToMessage.MVEX__WhatsappTemplate__c)?.MVEX__Template_Name__c || null;
    }

    get showChatWindow(){
        return !this.showLicenseError && !this.showchatwindowerror;
    }

    async connectedCallback(){
        try {
            this.checkBusinessAccountConfig();
        } catch (e) {
            console.error('Error in connectedCallback:::', e.message);
        }
    }

    async checkBusinessAccountConfig() {
        try {
            this.showSpinner = true; // Show spinner immediately during license check
            const result = await hasBusinessAccountId();
            this.hasBusinessAccountConfigured = result;
            
            // If configuration is not valid, stop here and don't fetch any other data
            if (!this.hasBusinessAccountConfigured) {
                this.showSpinner = false;
                return;
            }
            
            // If configuration is valid, load the data (spinner will hide when data loads)
            this.initializeData();
        } catch (error) {
            console.error('Error checking business account configuration:', error);
            this.showSpinner = false;
        }
    }

    initializeData() {
        if(this.pageRef && !this.isCalledFromGlobal){
            this.objectApiName = this.pageRef.attributes.objectApiName;
        }
        this.configureHeight();
        this.getS3ConfigDataAsync();
        this.getInitialData();
        this.generateEmojiCategories();
        this.handleSubscribe();
    }

    handlePackageUpdate(event){
        this.showLicenseError = event.detail.isPackageValid;
    }

    renderedCallback(){
        try {
            if(this.scrollBottom){
                let chatDiv = this.template.querySelector('.chat-div');
                if(chatDiv){
                    chatDiv.scrollTop = chatDiv.scrollHeight;
                }
                this.scrollBottom = false;
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
        } catch (e) {
            console.error('Error in function renderedCallback:::', e.message);
        }
    }

    handleSubscribe() {

        let self = this;
        let messageCallback = function (response) {
            try {
                let receivedChat = response?.data?.payload?.MVEX__Chat_Data__c 
                    ? JSON.parse(response.data.payload.MVEX__Chat_Data__c) 
                    : null;
                
                if (!receivedChat) return;
                
                let actionType = response?.data?.payload?.MVEX__Type__c;
                
                if(response?.data?.payload?.MVEX__ContactId__c !== self.phoneNumber) return;

                let chatIndex = self.chats?.findIndex(ch => ch?.Id === receivedChat?.Id);
                let chat = chatIndex > -1 ? self.chats[chatIndex] : null;
                
                switch (actionType) {

                    case 'new':
                        if (!chat) {
                            chat = receivedChat;
                            self.chats = [...self.chats, chat];
                            self.processChats?.(true);
                            self.sendOnlyTemplate = false;
                        }
                        break;

                    case 'status':
                        if (chat && receivedChat?.MVEX__Message_Status__c !== undefined) {
                            // Create new array with updated chat object to trigger reactivity
                            self.chats = self.chats.map((ch, index) => 
                                index === chatIndex 
                                    ? { ...ch, MVEX__Message_Status__c: receivedChat.MVEX__Message_Status__c } 
                                    : ch
                            );
                            self.processChats?.();
                        }
                        break;

                    case 'react':
                        if (chat) {
                            // Create new array with updated chat object to trigger reactivity
                            self.chats = self.chats.map((ch, index) => 
                                index === chatIndex 
                                    ? { 
                                        ...ch, 
                                        MVEX__Reaction__c: receivedChat.MVEX__Reaction__c,
                                        MVEX__Last_Interaction_Date__c: receivedChat.MVEX__Last_Interaction_Date__c
                                    } 
                                    : ch
                            );
                            self.processChats?.();
                        }
                        break;

                    case 'update':
                        if (chat && receivedChat?.MVEX__Message__c !== undefined) {
                            // Create new array with updated chat object to trigger reactivity
                            self.chats = self.chats.map((ch, index) => 
                                index === chatIndex 
                                    ? { ...ch, MVEX__Message__c: receivedChat.MVEX__Message__c } 
                                    : ch
                            );
                            self.processChats?.();
                        }
                        break;

                    case 'delete':
                        if (self.chats && receivedChat?.Id) {
                            self.chats = self.chats.filter(ch => ch?.Id !== receivedChat.Id);
                            self.processChats?.();
                        }
                        break;
                
                    default:
                        break;
                }
            } catch (error) {
                console.error('Error in handleSubscribe messageCallback:', error);
            }
        };
 
        subscribe(this.channelName, -1, messageCallback).then(response => {
            this.subscription = response;
        }).catch(error => {
            console.error('Error subscribing to platform event:', error);
        });
    }


    getInitialData(){
        this.showSpinner = true;
        try {
            getCombinedData({ contactId: this.recordId, objectApiName: this.objectApiName })
            .then(combinedData => {

                if(combinedData.theme && !this.isCalledFromGlobal){
                    this.isLightMode = combinedData.theme == 'light';
                    if(!this.isLightMode) {
                        this.template.querySelector('.main-chat-window-div').classList.toggle('darkTheme');
                        this.template.querySelector('.main-chat-window-div').classList.toggle('lightTheme');
                    }
                }

                if(combinedData?.record){
                    if(!combinedData.phoneNumber){
                        this.chatwindowerror = 'The record does not have a mobile number.';
                        this.showchatwindowerror = true;
                        // this.showToast('Something went wrong!', 'The record does not have a mobile number.', 'error');
                        this.showSpinner = false;
                        return;
                    }
                    combinedData.phoneNumber = combinedData.phoneNumber.replaceAll(' ', '');
                    this.recordData = combinedData.record;
                }else{
                    
                    if(combinedData.error){
                        this.chatwindowerror = combinedData.error;
                        this.showchatwindowerror = true;
                    }
                    else{
                        this.showToast('Something went wrong!', 'Couldn\'t fetch data of record', 'error');
                    }
                    this.showSpinner = false;
                    return;
                }

                this.allTemplates = combinedData.templates.length > 0 ? combinedData.templates : null;
                
                this.chats = JSON.parse(JSON.stringify(combinedData.chats));
                this.phoneNumber = combinedData.phoneNumber;
                this.recordName = combinedData.recordName;
                this.showSpinner = false;
                this.processChats(true);
                
                let chatIdsToSeen = [];
                this.chats.filter(ch => ch.MVEX__Type_of_Message__c != 'Outbound Messages').forEach(ch =>{
                    if(ch.MVEX__Message_Status__c!='Seen') chatIdsToSeen.push(ch.Id);
                })
                updateStatus({messageIds:chatIdsToSeen});
            })
            .catch(e => {
                this.showSpinner = false;
                console.error('Error in getCombinedData:', e.message);
            });
        } catch (e) {
            this.showSpinner = false;
            console.error('Error in function getInitialData:::', e.message);
        }
    }

    processChats(needToScroll){
        try {
            this.noChatMessages = this.chats?.length < 1 ? true : false;
            if(this.noChatMessages) {
                this.sendOnlyTemplate = true;
                this.noteText = 'The conversation hasn\'t started yet. Begin by sending a template!';
                return;
            }
            this.chats = this.chats?.map(ch => {
                console.log(ch);
                
                ch.isText = ch.MVEX__Message_Type__c == 'Text';
                ch.isImage = ch.MVEX__Message_Type__c == 'Image';
                ch.isVideo = ch.MVEX__Message_Type__c == 'Video';
                ch.isAudio = ch.MVEX__Message_Type__c == 'Audio';
                ch.isDoc = ch.MVEX__Message_Type__c == 'Document';
                ch.isFlow = ch.MVEX__Message_Type__c == 'interactive';
                // For interactive messages, show a detailed template-style preview for outbound
                // messages (with merge fields), and keep a simple label only for inbound
                ch.isFlowResponse = ch.isFlow && ch.MVEX__Type_of_Message__c != 'Outbound Messages';
                ch.isTemplate = ch.MVEX__Message_Type__c == 'Template'
                    || (ch.isFlow && ch.MVEX__Type_of_Message__c == 'Outbound Messages');
                ch.isOther = !['Text', 'Image', 'Template', 'Video', 'Document', 'Audio', 'interactive'].includes(ch.MVEX__Message_Type__c);
                ch.messageBy = ch.MVEX__Type_of_Message__c == 'Outbound Messages' ? 'You' : this.recordName;
                if ((ch.isDoc || ch.isAudio) && ch.MVEX__File_Data__c) {
                    if(ch.MVEX__Message__c?.includes('amazonaws.com') && ch.isDoc){
                        ch.isAWSFile = true;
                        const fileData = JSON.parse(ch.MVEX__File_Data__c);
                        const fileName = fileData?.fileName;
                        const mimeType = fileData?.mimeType;
                        ch.fileName = fileName;
                        if(mimeType.includes('pdf')){
                            ch.isPreviewable = true;
                        } else {
                            ch.isPreviewable = false;
                        }
                    } else {
                        ch.isAWSFile = false;
                        try {
                            const fileData = JSON.parse(ch.MVEX__File_Data__c);
                            const fileName = fileData?.fileName;
                            ch.fileName = fileName;
                            ch.contentDocumentId = fileData?.documentId;
                            ch.fileUrl = `/sfc/servlet.shepherd/version/download/${fileData?.contentVersionId}?as=${fileName}`;
                            ch.fileThumbnail = `/sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId=${fileData?.contentVersionId}`;
                        } catch (error) {
                            console.error("Error parsing File_Data__c:", error);
                        }
                    }
                }
                return ch;
            });

            this.showSpinner = true;
            let today = new Date();
            let yesterday = new Date(today);
            yesterday.setDate(yesterday.getDate() - 1);
            
            let options = { 
                day: '2-digit', 
                month: 'short', 
                year: 'numeric' 
            };
            let groupedChats = this.chats?.reduce((acc, ch) => {
                let createDate = new Date(ch.CreatedDate).toLocaleDateString('en-GB', options);
                let dateGroup = createDate == today.toLocaleDateString('en-GB', options) ? 'Today' : (createDate == yesterday.toLocaleDateString('en-GB', options) ? 'Yesterday' : createDate);
                let yourReaction= ch.MVEX__Reaction__c?.split('<|USER|>')[0];
                let userReaction= ch.MVEX__Reaction__c?.split('<|USER|>')[1];
                let chat = {
                    ...ch,
                    className: ch.MVEX__Type_of_Message__c === 'Outbound Messages' ? 'sent-message' : 'received-message',
                    isTick : ['Sent', 'Delivered', 'Seen'].includes(ch.MVEX__Message_Status__c), 
                    isFailed: ch.MVEX__Message_Status__c === 'Failed',
                    isSending: ch.MVEX__Message_Status__c == null,
                    dateGroup: dateGroup,
                    yourReaction: yourReaction,
                    userReaction: userReaction,
                    isReaction: yourReaction || userReaction,
                    replyTo: this.chats?.find( chat => chat.Id === ch.MVEX__Reply_to__c)
                };
                
                if (!acc[chat.dateGroup]) {
                    acc[chat.dateGroup] = [];
                }
                acc[chat.dateGroup].push(chat);
                return acc;
            }, {});
    
            this.groupedChats = Object.entries(groupedChats).map(([date, messages]) => ({
                date,
                messages
            }));
            
            this.showSpinner = false;
            if(needToScroll) this.scrollBottom = true;
            this.checkLastMessage();
        } catch (e) {
            console.error('Error in function processChats:::', e.message);
            this.showSpinner = false;
        }
    }
    
    checkLastMessage(){
        this.showSpinner = true;
        try {
            let interactionMessages = this.chats.filter(msg => msg.MVEX__Last_Interaction_Date__c);            
            let lastInteraction = interactionMessages?.sort((a, b) => new Date(b.MVEX__Last_Interaction_Date__c) - new Date(a.MVEX__Last_Interaction_Date__c))[0];

            if (lastInteraction) {
                let currentTime = new Date();
                let messageTime = new Date(lastInteraction.MVEX__Last_Interaction_Date__c);
                let timeDifferenceInMilliseconds = currentTime - messageTime;
                let hoursDifference = timeDifferenceInMilliseconds / (1000 * 60 * 60);

                if (hoursDifference > 24){
                    this.sendOnlyTemplate = true;
                    this.noteText = "Only template can be sent as no messages were received from this record in last 24 hours.";
                }else{
                    this.sendOnlyTemplate = false;
                }
            }else{
                this.sendOnlyTemplate = true;
                this.noteText = "Only template can be sent as no messages were received from this record in last 24 hours.";
            }
            this.showSpinner = false;
        } catch (e) {
            this.showSpinner = false;
            console.error('Error in function checkLastMessage:::', e.message);
        }
    }

    configureHeight(){
        try {
            if(!this.height || this.height<400) this.height = 400;
            if(this.height > 640) this.height = 640;
            this.template?.querySelector('.main-chat-window-div')?.style?.setProperty("--height-of-main-chat-container", this.height + "px");

            let randomIndex = Math.floor(Math.random() * this.replyBorderColors.length);
            this.template?.querySelector('.main-chat-window-div')?.style?.setProperty('--reply-to-received-border-color', this.replyBorderColors[randomIndex]);
        } catch (e) {
            console.error('Error in function configureHeight:::', e.message);
        }
    }

    handleBackDropClick(){
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
            this.templateSelectionMode = 'Template';
            this.templateSearchKey = null;
            this.audioPreview = false;
            this.audioURL = '';
            this.selectedFileName = null;
            this.selectedFilesToUpload = [];
            this.closeAllPopups();
            // this.template.querySelector('input[type="file"]').value = null;
            let fileInput = this.template?.querySelector('input[type="file"]');
            if (fileInput && fileInput.value) {
                fileInput.value = null;
            }
        } catch (e) {
            console.error('Error in function handleBackDropClick:::', e.message);
        }
    }
    
    toggleTheme() {
        try{
            this.isLightMode = !this.isLightMode;
            let theme = this.isLightMode ? "light" : "dark";
            // if(this.isLightMode){
            //     this.template.querySelector('.main-chat-window-div').classList.remove('darkTheme');
            //     this.template.querySelector('.main-chat-window-div').classList.add('lightTheme');
            // }else{
            //     this.template.querySelector('.main-chat-window-div').classList.remove('lightTheme');
            //     this.template.querySelector('.main-chat-window-div').classList.add('darkTheme');
            // }
            this.template?.querySelector('.main-chat-window-div')?.classList.toggle('darkTheme');
            this.template?.querySelector('.main-chat-window-div')?.classList.toggle('lightTheme');
            updateThemePreference({theme: theme})
            .then((isSuccess) => {
                if(!isSuccess){
                    this.showToast('Error!','Failed to save preference, you can continue using theme for this session.', 'error');
                }
            })
            .catch((e) => {
                console.error('Failed to update theme preference!.', e.message);
            });
        }catch(e){
            console.error('Error in toggleTheme:::', e.message);
        }
    }

    closeAllPopups(){
        try {
            var className = this.isCalledFromGlobal ? '.main-chat-window-div-for-global' : '.main-chat-window-div';
            this.template?.querySelector(className)?.style?.setProperty("--max-height-for-attachment-options","0rem");
            this.template?.querySelector(className)?.style?.setProperty("--max-height-for-send-options","0rem");
            this.template?.querySelector(className)?.style?.setProperty("--height-for-emoji","0rem");
        } catch (error) {
            console.error('Error in function closeAllPopups:::', error);
        }
    }

    handleToggleActions(event){
        try {
            event.currentTarget.classList.toggle('show-options');
        } catch (e) {
            console.error('Error in function handleToggleActions:::', e.message);
        }
    }

    handleHideActions(event){
        try {
            event.currentTarget?.querySelector('.action-options-btn')?.classList.remove('show-options');
        } catch (e) {
            console.error('Error in function handleHideActions:::', e.message);
        }
    }

    handleChatAction(event){
        try {
            let actionType = event.currentTarget.dataset.action;
            let chatId = event.currentTarget.dataset.chat;
            if(actionType === 'reply'){
                this.replyToMessage = this.chats?.find( chat => chat.Id === chatId);
                this.template.querySelector('.message-input').focus();
            }else if(actionType === 'react'){
                this.reactToMessage = chatId;
                this.showReactEmojiPicker = true;
            }else if(actionType === 'copy'){
                navigator.clipboard.writeText(event.currentTarget.dataset.message);
                this.showToast('Success!', 'The message text has been copied to clipboard.', 'success');
            }else if(actionType === 'cancel-reply'){
                this.replyToMessage = null;
            }else if(actionType === 'cancel-react'){
                this.reactToMessage = null;
                this.showReactEmojiPicker = false;
            }
        } catch (e) {
            console.error('Error in function handleReply:::', e.message);
        }
    }

    handleReactWithEmoji(event){
        try {
            if(this.reactToMessage){
                let chat = this.chats?.find( ch => ch.Id === this.reactToMessage);                
                chat.MVEX__Reaction__c = event.target.innerText + (chat.MVEX__Reaction__c ? chat.MVEX__Reaction__c.slice(chat.MVEX__Reaction__c.indexOf('<|USER|>')) : '<|USER|>');
                this.reactToMessage = null;
                this.showReactEmojiPicker = false;
                this.updateMessageReaction(chat);
            }
        } catch (e) {
            console.error('Error in function handleReactWithEmoji:::', e.message);
        }
    }

    handleRemoveReaction(event){
        try {
            let chat = this.chats?.find( chat => chat.Id === event.currentTarget.dataset.chat);
            chat.MVEX__Reaction__c = chat.MVEX__Reaction__c?.slice(chat.MVEX__Reaction__c.indexOf('<|USER|>'));
            this.updateMessageReaction(chat);
        } catch (e) {
            console.error('Error in function handleRemoveReaction:::', e.message);
        }
    }

    handleReplyMessageClick(event){
        try {            
            let replyTo = event.currentTarget.dataset.replyTo;

            let replyToChatEle = this.template.querySelector(`.message-full-length-div[data-id="${replyTo}"]`);
            if(!replyToChatEle){
                return;
            }
            replyToChatEle.scrollIntoView({behavior: 'smooth', block:'center'});

            let chatBlink = [
                { backgroundColor: "#a9a9a990" },
                { backgroundColor: "transparent" },
            ];
            
            let blinkTiming = {
                duration: 1000,
                iterations: 1,
            };
            let observer = new IntersectionObserver(
                (entries) => {
                    entries.forEach((entry) => {
                        if (entry.isIntersecting) {
                            replyToChatEle.animate(chatBlink, blinkTiming);
                            observer.unobserve(entry.target);
                        }
                    });
                },
                { threshold: 0.1 }
            );
    
            // Start observing the element
            observer.observe(replyToChatEle);
        } catch (e) {
            console.error('Error in function handleReplyMessageClick:::', e.message);
        }
    }

    handleToggleImagePreview(event){
        try {
            let isMobileDevice = /Mobi|Android|iPhone|iPad|iPod/i.test(navigator.userAgent); 
            if(isMobileDevice){
                return;
            }
            let action = event.currentTarget.dataset.action;
            
            if(action == 'open'){
                event.currentTarget.classList.add('show-image-preview');
            }else if(action == 'close'){
                this.template.querySelector('.show-image-preview').classList.remove('show-image-preview');
                event.stopPropagation()
            }
        } catch (e) {
            console.error('Error in function handleToggleImagePreview:::', e.message);
        }
    }

    handleToggleAudioPreview(event){
        let isMobileDevice = /Mobi|Android|iPhone|iPad|iPod/i.test(navigator.userAgent); 
        if(isMobileDevice){
            return;
        }
        let audioURL = event.currentTarget.dataset.url;
        this.audioPreview = !this.audioPreview;
        this.audioURL = audioURL;
    }

    handleTogglePDFPreview(event){
        let isMobileDevice = /Mobi|Android|iPhone|iPad|iPod/i.test(navigator.userAgent); 
        if(isMobileDevice){
            return;
        }
        let action = event.currentTarget.dataset.action;
        
        if(action == 'open'){
            event.currentTarget.classList.add('pdf-preview');
        }else if(action == 'close'){
            this.template.querySelector('.pdf-preview').classList.remove('pdf-preview');
            event.stopPropagation()
        }
    }

    generateEmojiCategories() {
        try{
            fetch(emojiData)
            .then((response) => response.json())
            .then((data) => {
                // Group emojis by category
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
        }catch(e){
            console.error('Error in generateEmojiCategories', e);
        }
    }

    handleEmojiButtonClick(){
        try {
            this.showEmojiPicker = !this.showEmojiPicker;
            this.closeAllPopups();
            var className = this.isCalledFromGlobal ? '.main-chat-window-div-for-global' : '.main-chat-window-div';
            this.template?.querySelector(className)?.style.setProperty("--height-for-emoji",this.showEmojiPicker ? "20rem" : "0rem");
            if(this.showEmojiPicker){
                this.template.querySelector('.emoji-picker-div').scrollTop = 0;
            }
        } catch (e) {
            console.error('Error in function handleEmojiButtonClick:::', e.message);
        }
    }

    handleEmojiClick(event){
        try {
            let textareaMessageElement = this.template.querySelector('.message-input');
            let textareaMessage = textareaMessageElement.value;
            let curPos = textareaMessageElement.selectionStart;
            textareaMessageElement.value = textareaMessage.slice(0, curPos) + event.target.innerText + textareaMessage.slice(curPos);
            textareaMessageElement.focus();
            textareaMessageElement.setSelectionRange(curPos + event.target.innerText.length,curPos + event.target.innerText.length); 
        } catch (e) {
            console.error('Error in function handleEmojiClick:::', e.message);
        }
    }

    handleMessageTextChange(event) {
        try {
            let isMobileDevice = /Mobi|Android|iPhone|iPad|iPod/i.test(navigator.userAgent); 
            let textareaMessageElement = this.template.querySelector('.message-input');
            if (!isMobileDevice && event.key === 'Enter') {
                if (event.shiftKey || event.ctrlKey || event.altKey || event.metaKey) {
                    return;
                }
                event.preventDefault();
                this.handleSendMessage();
                textareaMessageElement.blur();
                return;
            }
            textareaMessageElement.style.height = 'auto';
            textareaMessageElement.style.height = `${textareaMessageElement.scrollHeight}px`;
            this.showAttachmentOptions = false;
            
            var className = this.isCalledFromGlobal ? '.main-chat-window-div-for-global' : '.main-chat-window-div';
            this.template?.querySelector(className)?.style.setProperty("--max-height-for-attachment-options","0rem");
            this.template?.querySelector(className)?.style?.setProperty("--height-for-emoji","0rem");
        } catch (e) {
            console.error('Error in function handleMessageTextChange:::', e.message);
        }
    }
    
    handleAttachmentButtonClick(){
        try {
            this.showAttachmentOptions = !this.showAttachmentOptions;
            // this.closeAllPopups();
            var className = this.isCalledFromGlobal ? '.main-chat-window-div-for-global' : '.main-chat-window-div';
            // console.log(className);
            // console.log(this.isCalledFromGlobal);
            
            
            this.template?.querySelector(className)?.style.setProperty("--max-height-for-attachment-options",this.showAttachmentOptions ? "13rem" : "0rem");
            // console.log(this.template?.querySelector(className)?.style.getPropertyValue("--max-height-for-attachment-options",this.showAttachmentOptions));
            
        } catch (e) {
            console.error('Error in function handleAttachmentButtonClick:::', e.message);
        }
    }

    handleAttachmentOptionClick(event) {
        try {
            let mediaType = event.target.dataset.media;
            this.checkLastMessage();
            // WhatsApp policy: outside the 24h conversation window only approved
            // Template messages may be sent — interactive messages require an open session.
            if (this.sendOnlyTemplate && mediaType !== 'Template') {
                if (mediaType === 'Interactive Message') {
                    this.showToast(
                        'Cannot send Interactive Message!',
                        'Interactive messages can only be sent within the 24-hour conversation window. Please send an approved template first.',
                        'info'
                    );
                } else {
                    this.showToast(
                        `Cannot send ${mediaType}!`,
                        'You don\'t have any response from record in last 24 hours.',
                        'info'
                    );
                }
                return;
            }
            
            switch (mediaType) {
                case 'Template':
                    this.templateSelectionMode = 'Template';
                    this.templateSearchKey = null;
                    this.selectedTemplate = null;
                    this.showFileUploader = false;
                    this.showTemplatePreview = false;
                    this.showTemplateSelection = true;
                    this.replyToMessage = null;
                    break;
                case 'Interactive Message':
                    this.templateSelectionMode = 'Interactive Message';
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
                    this.showToast('Something went wrong!', 'Could not process request, please try again.', 'error');
                    break;
            }
            this.closeAllPopups();
        } catch (e) {
            console.error('Error in function handleAttachmentOptionClick:::', e.message);
        }
    }

    handleUploadFinished(event){
        this.showSpinner = true;
        try {
            if(!(event.detail.files.length > 0)){
                this.handleBackDropClick();
                this.showSpinner = false;
                return;
            }

            var messageType = '';
            if(event.detail.files[0].mimeType.includes('image/')){
                messageType = 'Image';
            } else if (event.detail.files[0].mimeType.includes('application/') || event.detail.files[0].mimeType.includes('text/')){
                messageType = 'Document';
            } else if (event.detail.files[0].mimeType.includes('audio/')){
                messageType = 'Audio';
            } else if(event.detail.files[0].mimeType.includes('video/')){
                messageType = 'Video';
            }
            // console.log('Object Name ::: ',this.objectApiName);
            
            createChat({chatData: {message: event.detail.files[0].contentVersionId, templateId: this.selectedTemplate, messageType: messageType, recordId: this.recordId, replyToChatId: this.replyToMessage?.Id || null, phoneNumber: this.phoneNumber, objectName: this.objectApiName}})
            .then(chat => {
                if(chat){
                    this.chats.push(chat);
                    this.processChats(true);
                    
                    let imagePayload = this.createJSONBody(this.phoneNumber, messageType, this.replyToMessage?.MVEX__WhatsAppMessageId__c || null, {
                        link: chat.MVEX__Message__c,
                        fileName: event.detail.files[0].name || 'whatsapp file'
                    });
                    sendWhatsappMessage({jsonData: imagePayload, chatId: chat.Id, isReaction: false, reaction: null})
                    .then(result => {
                        if(result.errorMessage == 'METADATA_ERROR'){
                            this.showToast('Something went wrong!', 'Please add/update the configurations for the whatsapp.', 'error');
                        }
                        let resultChat = result.chat;
                        this.chats.find(ch => ch.Id === chat.Id).MVEX__Message_Status__c = resultChat.MVEX__Message_Status__c;
                        this.chats.find(ch => ch.Id === chat.Id).MVEX__WhatsAppMessageId__c = resultChat?.MVEX__WhatsAppMessageId__c;
                        this.messageText = '';
                        this.template.querySelector('.message-input').value = '';
                        this.replyToMessage = null;
                        this.showSpinner = false;
                        this.processChats(true);
                    })
                    .catch((e) => {
                        this.showSpinner = false;
                        console.error('Error in handleUploadFinished > sendWhatsappMessage :: ', e);
                    })
                    this.handleBackDropClick();
                }else{
                    this.showSpinner = false;
                    this.showToast('Something went wrong!', 'The photo is not sent, please make sure image size does not exceed 5MB.', 'error');
                    console.error('there was some error sending the message!');
                }
            })
            .catch((e) => {
                this.showSpinner = false;
                this.showToast('Something went wrong!', 'The photo could not be sent, please try again.', 'error');
                console.error('Error in handleUploadFinished > createChat :: ', e);
            })
            this.uploadFileType = null;
            this.showFileUploader = false;
            this.acceptedFormats = [];
        } catch (e) {
            this.showSpinner = false;
            this.showToast('Something went wrong!', 'The photo could not be sent, please try again.', 'error');
            console.error('Error in function handleUploadFinished:::', e.message);
        }
    }

    handlePreview(event) {
        const contentDocumentId = event.target.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__namedPage',
            attributes: {
                pageName: 'filePreview'
            },
            state: {
                selectedRecordId: contentDocumentId
            }
        });
    }

    handleDocError(event){
        event.target.onerror=null; 
        event.target.src = this.NoPreviewAvailable;
    }
    
    handleImageError(event){
        try {
            event.currentTarget.src = "/resource/MVEX__Alt_Image";
            event.currentTarget.parentNode.classList.add('not-loaded-image');
        } catch (e) {
            console.error('Error in function handleImageError:::', e.message);
        }
    }

    handleSearchTemplate(event){
        try {
            this.templateSearchKey = event.target.value || null;
        } catch (e) {
            console.error('Error in function handleSearchTemplate:::', e.message);
        }
    }

    handleShowTemplatePreview(event){
        try {
            if(event.currentTarget.dataset.id){
                this.selectedTemplate = event.currentTarget.dataset.id;
                this.showTemplateSelection = false;
                this.showTemplatePreview = true;
            }
        } catch (e) {
            console.error('Error in function handleShowTemplatePreview:::', e.message);
        }
    }

    handleBackToList(){
        try {
            this.selectedTemplate = null;
            this.showTemplatePreview = false;
            this.showTemplateSelection = true;
        } catch (e) {
            console.error('Error in function handleBackToList:::', e.message);
        }
    }

    isInteractiveTemplateRecord(template) {
        if (!template) {
            return false;
        }

        const recordTypeName = template.RecordType?.Name || template.MVEX__RecordType?.Name || '';
        const templateType = template.MVEX__Template_Type__c || template.Template_Type__c || '';
        const interactiveType = template.MVEX__Interactive_Type__c || template.Interactive_Type__c || '';

        return recordTypeName === 'Interactive Message'
            || templateType === 'Interactive Message'
            || !!interactiveType;
    }

    handleTemplateSent(event){
        try {
            this.showTemplateSelection = false;
            if(event.detail.errorMessage == 'METADATA_ERROR') this.showToast('Something went wrong!', 'Please add/update the configurations for the whatsapp.', 'error');
            let chat = event.detail.chat;
            this.chats.push(chat);
            this.handleBackDropClick();
            this.showSpinner = false;
            this.processChats(true);
        } catch (e) {
            console.error('Error in function handleTemplateSent:::', e.message);
        }
    }

    createJSONBody(to, type, replyId, data){
        try {
                let payload = `{ "messaging_product": "whatsapp", "to": "${to}", "type": "${type}"`;

                if(replyId) {
                    payload += `, "context": {"message_id": "${replyId}"}`;
                }
            
                if (type === "text") {
                    payload += `, "text": { "body": "${data.textBody.replace(/\n/g, "\\n")}" }`;
                } else if (type === "Image") {
                    const parser = new DOMParser();
                    const doc = parser.parseFromString(data.link, "text/html");
                    payload += `, "image": { "link": "${doc.documentElement.textContent}" } `;
                } else if (type === "Video") {
                    const parser = new DOMParser();
                    const doc = parser.parseFromString(data.link, "text/html");
                    payload += `, "video": { "link": "${doc.documentElement.textContent}" } `;
                } else if (type === "Document") {
                    const parser = new DOMParser();
                    const doc = parser.parseFromString(data.link, "text/html");
                    payload += `, "document": { "link": "${doc.documentElement.textContent}", "filename": "${data.fileName}" } `;
                } else if (type === "Audio") {
                    const parser = new DOMParser();
                    const doc = parser.parseFromString(data.link, "text/html");
                    payload += `, "audio": { "link": "${doc.documentElement.textContent}" } `;
                } else if (type === "reaction"){
                    payload += `, "reaction": { "message_id": "${data.reactToId}", "emoji": "${data.emoji}" }`;
                }
                payload += ` }`;
                
                return payload;
        } catch (e) {
            console.error('Error in function createJSONBody:::', e.message);
        }
    }

    updateMessageReaction(chat){
        try {
            updateReaction({chatId: chat.Id, reaction:chat.MVEX__Reaction__c})
            .then(ch => {
                this.processChats();
                let reactPayload = this.createJSONBody(this.phoneNumber, "reaction", this.replyToMessage?.MVEX__WhatsAppMessageId__c || null, {
                    reactToId : chat.MVEX__WhatsAppMessageId__c,
                    emoji: chat.MVEX__Reaction__c?.split('<|USER|>')[0]
                });
                
                sendWhatsappMessage({jsonData: reactPayload, chatId: chat.Id, isReaction: true, reaction: chat.MVEX__Reaction__c})
                .then(result => {
                    if(result.errorMessage == 'METADATA_ERROR'){
                        this.showToast('Something went wrong!', 'Please add/update the configurations for the whatsapp.', 'error');
                    }

                    let resultChat = result.chat;
                    this.chats.find(ch => ch.Id === chat.Id).MVEX__Reaction__c = resultChat.MVEX__Reaction__c;
                    this.processChats();
                })
                .catch((e) => {
                    console.error('Error in updateMessageReaction > sendWhatsappMessage :: ', e);
                })
            })
            .catch((e) => {
                this.showToast('Something went wrong!', 'The reaction could not be updated, please try again.', 'error');
                console.error('Error in updateMessageReaction > updateReaction :: ', e);
            })
        } catch (e) {
            this.showToast('Something went wrong!', 'The reaction could not be updated, please try again.', 'error');
            console.error('Error in function updateMessageReaction:::', e.message);
        }
    }

    handleSendMessage(){
        this.showSpinner = true;
        try {
            this.handleBackDropClick();
            this.template.querySelector('.dropdown-menu')?.classList?.add('hidden');
            this.messageText = this.template.querySelector('.message-input').value;
            this.checkLastMessage();
            if(this.sendOnlyTemplate){
                this.showToast('Cannot send text message!', 'You don\'t have any response from record in last 24 hours.', 'info');
                return;
            }
            if(this.messageText.trim().length < 1){
                this.showToast('Something went wrong!', 'Please enter a message to send.', 'error');
                this.showSpinner = false;
                return;
            }
            if(this.sendOnlyTemplate){
                this.showToast('Cannot send text message.', 'You don\'t have any message from record since last 24 hours.', 'info');
                this.showSpinner = false;
                return;
            }
            createChat({chatData: {message: this.messageText, templateId: this.selectedTemplate, messageType: 'text', recordId: this.recordId, replyToChatId: this.replyToMessage?.Id || null, phoneNumber: this.phoneNumber, objectName: this.objectApiName}})
            .then(chat => {
                if(chat){
                    let textPayload = this.createJSONBody(this.phoneNumber, "text", this.replyToMessage?.MVEX__WhatsAppMessageId__c || null, {
                        textBody: this.messageText
                    });
                    let textareaMessageElement = this.template.querySelector('.message-input');
                    this.chats.push(chat);
                    this.showSpinner = false;
                    this.messageText = '';
                    this.replyToMessage = null;
                    this.processChats(true);
                    textareaMessageElement.value = '';
                    textareaMessageElement.style.height = 'auto';
                    textareaMessageElement.style.height = `${textareaMessageElement.scrollHeight}px`;

                    sendWhatsappMessage({jsonData: textPayload, chatId: chat.Id, isReaction: false, reaction: null})
                    .then(result => {
                        if(result.errorMessage == 'METADATA_ERROR'){
                            this.showToast('Something went wrong!', 'Please add/update the configurations for the whatsapp.', 'error');
                        }
                        let resultChat = result.chat;
                        this.chats.find(ch => ch.Id === chat.Id).MVEX__Message_Status__c = resultChat.MVEX__Message_Status__c;
                        this.chats.find(ch => ch.Id === chat.Id).MVEX__WhatsAppMessageId__c = resultChat?.MVEX__WhatsAppMessageId__c;
                        this.showSpinner = false;
                        this.processChats();
                    })
                    .catch((e) => {
                        this.showSpinner = false;
                        console.error('Error in handleSendMessage > sendWhatsappMessage :: ', e);
                    })
                }else{
                    this.showSpinner = false;
                    this.showToast('Something went wrong!', 'Message could not be sent, please try again.', 'error');
                    console.error('there was some error sending the message!');
                }
            })
            .catch((e) => {
                this.showToast('Something went wrong!', (e.body.message == 'STORAGE_LIMIT_EXCEEDED' ? 'Storage Limit Exceeded, please free up space and try again.' : 'Message could not be sent, please try again.'), 'error');
                this.showSpinner = false;
                console.error('Error in handleSendMessage > createChat :: ', e);
            })
        } catch (e) {
            this.showSpinner = false;
            this.showToast('Something went wrong!', 'Message could not be sent, please try again.', 'error');
            console.error('Error in handleSendMessage:::', e.message);
        }
    }
    
    handleScheduleMessage(event){
        try {
            this.template.querySelector('.dropdown-menu').classList.add('hidden');
        } catch (e) {
            console.error('Error in function handleScheduleMessage:::', e.message);
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

    async handleSelectedFiles(event) {
        try {
            const file = event.target.files[0];
            if (file) {
                let fileType = file.type;
                let fileSizeMB = Math.floor(file.size / (1024 * 1024));
                let isValid = false;
                let maxSize = 0;
    
                if (fileType.includes('image/')) {
                    maxSize = 5;
                    isValid = fileSizeMB <= maxSize;
                } else if (fileType.includes('video/') || fileType.includes('audio/')) {
                    maxSize = 16;
                    isValid = fileSizeMB <= maxSize;
                } else if (fileType.includes('application/') || fileType.includes('text/')) {
                    maxSize = 100;
                    isValid = fileSizeMB <= maxSize;
                }
    
                if (isValid) {
                    this.selectedFilesToUpload.push(file);
                    this.selectedFileName = file.name;
                } else {
                    this.showToast('Error', `${file.name} exceeds the ${maxSize}MB limit`, 'error');
                }
            }
        } catch (error) {
            console.error('Error in file upload:', error);
        }
    }

    removeFile() {
        this.selectedFileName = null;
        this.selectedFilesToUpload = [];
        this.template.querySelector('input[type="file"]').value = null;
    }

    async handleUploadClick(){
        if(this.selectedFilesToUpload.length > 0){
            this.showSpinner = true;
            await this.uploadToAWS(this.selectedFilesToUpload);
        }
    }

    async uploadToAWS() {
        try {
            this.showSpinner = true;
            this.initializeAwsSdk(this.confData);
            const uploadPromises = this.selectedFilesToUpload.map(async (file) => {
                this.showSpinner = true;
                let objKey = this.renameFileName(this.selectedFileName);

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

                    var messageType = '';
                    if(this.selectedFilesToUpload[0].type.includes('image/')){
                        messageType = 'Image';
                    } else if (this.selectedFilesToUpload[0].type.includes('application/') || this.selectedFilesToUpload[0].type.includes('text/')){
                        messageType = 'Document';
                    } else if (this.selectedFilesToUpload[0].type.includes('audio/')){
                        messageType = 'Audio';
                    } else if(this.selectedFilesToUpload[0].type.includes('video/')){
                        messageType = 'Video';
                    }

                    createChatForAWSFiles({chatData: {message: awsFileUrl, fileName: objKey, mimeType: this.selectedFilesToUpload[0].type, messageType: messageType, recordId: this.recordId, replyToChatId: this.replyToMessage?.Id || null, phoneNumber: this.phoneNumber}})
                        .then(chat => {
                            if(chat){
                                this.chats.push(chat);
                                this.processChats(true);
                                
                                let imagePayload = this.createJSONBody(this.phoneNumber, messageType, this.replyToMessage?.MVEX__WhatsAppMessageId__c || null, {
                                    link: chat.MVEX__Message__c,
                                    fileName: objKey || 'whatsapp file'
                                });

                                sendWhatsappMessage({jsonData: imagePayload, chatId: chat.Id, isReaction: false, reaction: null})
                                    .then(result => {
                                        if(result.errorMessage == 'METADATA_ERROR'){
                                            this.showToast('Something went wrong!', 'Please add/update the configurations for the whatsapp.', 'error');
                                        }
                                        let resultChat = result.chat;
                                        this.chats.find(ch => ch.Id === chat.Id).MVEX__Message_Status__c = resultChat.MVEX__Message_Status__c;
                                        this.chats.find(ch => ch.Id === chat.Id).MVEX__WhatsAppMessageId__c = resultChat?.MVEX__WhatsAppMessageId__c;
                                        this.messageText = '';
                                        this.template.querySelector('.message-input').value = '';
                                        this.replyToMessage = null;
                                        this.showSpinner = false;
                                        this.processChats(true);
                                    })
                                    .catch((e) => {
                                        this.showSpinner = false;
                                        console.error('Error in handleUploadFinished > sendWhatsappMessage :: ', e);
                                    })
                                this.handleBackDropClick();
                            }else{
                                this.showSpinner = false;
                                this.showToast('Something went wrong!', 'The photo is not sent, please make sure image size does not exceed 5MB.', 'error');
                                console.error('there was some error sending the message!');
                            }
                        })
                        .catch((e) => {
                            this.showSpinner = false;
                            this.showToast('Something went wrong!', 'The photo could not be sent, please try again.', 'error');
                            console.error('Error in handleUploadFinished > createChat :: ', e);
                        })
                    this.uploadFileType = null;
                    this.showFileUploader = false;
                    this.acceptedFormats = [];
                    this.removeFile();
                }
            });

        } catch (error) {
            this.showSpinner = false;
            console.error("Error in uploadToAWS: ", error);
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
            let originalFileName = filename;
            let extensionIndex = originalFileName.lastIndexOf('.');
            let baseFileName = originalFileName.substring(0, extensionIndex);
            let extension = originalFileName.substring(extensionIndex + 1);
            
            let objKey = `${baseFileName}.${extension}`
                .replace(/\s+/g, "_");
            return objKey;
        } catch (error) {
            console.error('error in renameFileName -> ', error.stack);            
        }
    }

    downloadRowImage(event) {
        try {
            const fileName = event.currentTarget.dataset.name;
            const vfPageUrl = `/apex/FileDownloadVFPage?fileName=${encodeURIComponent(fileName)}`;
            window.open(vfPageUrl, '_blank');
        } catch (error) {
            this.showSpinner = false;
            console.error('Error downloading file:', error.stack);
        }
    }

    showToast(title ,message, status){
        try {
            let evt = new ShowToastEvent({
                title: title,
                message: message,
                variant: status,
                mode: 'dismissible'
            });
            this.dispatchEvent(evt);
        } catch (e) {
            console.error('Error in function showToast:::', e.message);
        }
    }
}