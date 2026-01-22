/**
 * Component Name: WbTemplateCategory
 * @description: Used LWC components to select template category and template type.
 * Date: 30/04/2025
 * Created By: Rachit Shah
 */

import { LightningElement,track,api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { loadStyle } from 'lightning/platformResourceLoader';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';


export default class WbTemplateCategory extends NavigationMixin(LightningElement) {
    @api selectedTab = 'section1';    
    @api selectedOption = 'custom';   
    @api activeTab = 'Marketing';
    
    defaultPreview = true;
    activeTemplateId = 'defaultPreview';
    showLicenseError = false;

    @track tabOptions = [
        { label: 'Marketing', value: 'section1', className: 'slds-button slds-button_neutral section-tab-li slds-button_brand' },
        { label: 'Utility', value: 'section2', className: 'slds-button slds-button_neutral section-tab-li' },
        { label: 'Authentication', value: 'section3', className: 'slds-button slds-button_neutral section-tab-li' },
    ];

    @track sections = {
        section1: {
            options: [
                {
                    className: 'radio1',
                    label: 'Custom',
                    value: 'custom',
                    description: 'Send promotions or announcements to increase awareness and engagement.',
                    checked: true
                },
                {
                    className: 'radio2',
                    label: 'Flows',
                    value: 'Flow',
                    description: 'Send a form to capture customer interests, appointment requests or run surveys.',
                    checked: false
                }
            ]
        },
        section2: {
            options: [
                {
                    className: 'radio1',
                    label: 'Custom',
                    value: 'Custom',
                    description: 'Send messages about an existing order or account.',
                    checked: true
                },
                {
                    className: 'radio2',
                    label: 'Order status',
                    value: 'ORDER_STATUS',
                    description: 'Send messages to tell customers about the progress of their orders.',
                    checked: false
                },
                {
                    className: 'radio3',
                    label: 'Flows',
                    value: 'flowutility',
                    description: 'Send a form to collect feedback, send reminders or manage orders.',
                    checked: false
                }
            ]
        },
        section3: {
            options: [
                {
                    className: 'radio1',
                    label: 'One-time passcode',
                    value: 'One-time passcode',
                    description: 'Send codes to verify a transaction or login.',
                    checked: true
                }
            ]
        }
    };

    @track templates = {
        "defaultPreview": {
            "image": "/resource/previewImage",
            "hey": "Hey there! Check out our fresh groceries now!",
            "code": "Use code <b>HEALTH</b> to get additional 10% off on your entire purchase.",
            "time": "11:59",
            "buttons": [
                { "icon": "/resource/redirect", "label": "Shop now" },
                { "icon": "/resource/copy", "label": "Copy code" }
            ],
            "goodFor": "Welcome messages, promotions, offers, coupons, newsletters, announcements",
            "customizable": "Header, body, footer, button"
        },
        "isFlowMarketing": {
            "hey": "Make dinner with Jaspher Market",
            "code": "Our free online course will be available soon! Sign up today to reserve a spot",
            "time": "11:59",
            "buttons": [{ "label": "Sign up" }],
            "goodFor": "Sign-ups, promotions, surveys, appointments",
            "customizable": "Form, body, button"
        },
        "isFlowUtility": {
            "hey": "We have delivered your order!",
            "code": "Your feedback ensures we continually improve. Please share your thoughts on your recent order",
            "time": "11:59",
            "buttons": [{ "label": "Share feedback" }],
            "goodFor": "Sign-ups, promotions, surveys, appointments",
            "customizable": "Form, body, button"
        },
        "utilityOrderStatusSelected": {
            "hey": "<b>Status: Order Processing</b><br>We've received your payment of <b>$239.00</b> for order <b>23KFEJJ2312</b>. You'll receive a notification when the order is shipped.",
            "time": "11:59",
            "buttons": [],
            "goodFor": "Order confirmation, order status, delivery status",
            "customizable": "body, footer"
        },
        "UtilityCustomSelected": {
            "hey": "Good news! Your order <b>23KFEJJ2312</b> has shipped!<br>Here's your tracking information, please check link below",
            "time": "11:59",
            "buttons": [{ "label": "Track Shipment" }],
            "goodFor": "Order confirmations, account update, receipts, appointment reminders, billing",
            "customizable": "Header, body, footer, button"
        },
        "authenticationPasscodeSelected": {
            "hey": "<b>123456</b> is your verification code. For your security, do not share this code.",
            "time": "11:59",
            "buttons": [],
            "goodFor": "One-time password, account recovery code, account verification, integrity challenges",
            "customizable": "Code delivery method"
        }
    }

    
    get activeSection() {
        return this.sections[this.selectedTab];
    }

    get currentTemplate() {
        return this.templates[this.activeTemplateId] || null;
    }    
    
    connectedCallback() {
        loadStyle(this, MulishFontCss)
        .then(() => {
            console.log('External Css Loaded');
        })
        .catch(error => {
            console.log('Error occuring during loading external css', error);
        });
        if(this.selectedTab!= undefined && this.selectedOption != undefined){
            this.handleTabClick(this.selectedTab);      
            this.handleRadioChange(this.selectedOption);
        }
    }

    // Send data back to Parent when Next is clicked
    handleNextclick() {
        const tabName = this.tabOptions.find(tab => tab.value === this.selectedTab)?.label || '';

        const selectionEvent = new CustomEvent('next', {
            detail: {
                selectedTab: this.selectedTab,
                selectedOption: this.selectedOption,
                tabName: tabName,
                activeTab: this.activeTab,
                activeTemplateId: this.activeTemplateId
            }
        });

        this.dispatchEvent(selectionEvent);
    }

    renderedCallback() {
        const hey = this.template.querySelector('.chatBubbleHeyMessage');
        const code = this.template.querySelector('.chatBubbleCodeMessage');

        if (hey) hey.innerHTML = this.currentTemplate.hey;
        if (code && this.currentTemplate.code) code.innerHTML = this.currentTemplate.code;
    }

    handleTabClick(eventOrTab) {
        // this.selectedTab = event.target.dataset.tab;
        let tabValue;
        if (typeof eventOrTab === 'string') {
            tabValue = eventOrTab; // manual call
        } else {
            
            tabValue = eventOrTab.target.dataset.tab; // click event
        }
        this.selectedTab = tabValue;
        
        // Update button styles dynamically
        this.tabOptions = this.tabOptions.map(tab => ({
            ...tab,
            className: `slds-button slds-button_neutral section-tab-li${tab.value === this.selectedTab ? ' slds-button_brand' : ''}`
        }));

        switch (this.selectedTab) {
            case 'section1':
                this.selectedOption = !['custom', 'Flow'].includes(this.selectedOption) ? 'custom' : this.selectedOption;
                this.activeTemplateId = 'defaultPreview';
                this.activeTab = 'Marketing';
                break;
            case 'section2':
                // this.selectedOption = this.selectedOption ? this.selectedOption : 'Custom';
                this.selectedOption = ![ 'Custom', 'ORDER_STATUS', 'flowutility'].includes(this.selectedOption) ? 'Custom' : this.selectedOption;
                this.activeTemplateId = 'UtilityCustomSelected';
                this.activeTab ='Utility';
                break;
            case 'section3':
                // this.selectedOption = this.selectedOption ? this.selectedOption : 'One-time passcode';
                this.selectedOption = !['One-time passcode'].includes(this.selectedOption) ? 'One-time passcode' : this.selectedOption;
                this.activeTemplateId = 'authenticationPasscodeSelected';
                this.activeTab = 'Authentication';
                break;
            default:
                break;
        }
    }

    handleRadioChange(eventOrTab) {
        // this.selectedOption = event.target.value;
        let tabValue;
        if (typeof eventOrTab === 'string') {
            tabValue = eventOrTab; // manual call
        } else {
            
            tabValue = eventOrTab.target.value; // click event
        }
        this.selectedOption = tabValue;

        const updatedOptions = this.activeSection.options.map(option => ({
            ...option,
            checked: option.value === this.selectedOption
        }));

        // Update the specific section with new checked values
        this.sections = {
            ...this.sections,
            [this.selectedTab]: {
                ...this.sections[this.selectedTab],
                options: updatedOptions
            }
        };
        
        switch (this.selectedOption) {
            case 'custom':
                this.activeTemplateId = 'defaultPreview';
                break;
            case 'Flow':
                this.activeTemplateId = 'isFlowMarketing';
                break;
            case 'Custom':
                this.activeTemplateId = 'UtilityCustomSelected';
                break;
            case 'ORDER_STATUS':
                this.activeTemplateId = 'utilityOrderStatusSelected';
                break;
            case 'flowutility':
                this.activeTemplateId  = 'isFlowUtility';
                break;
            case 'One-time passcode':
                this.activeTemplateId  = 'authenticationPasscodeSelected';
                break;
            default:   
                this.activeTemplateId = 'defaultPreview';
                break;
        }
    }

    navigateToAllTemplatePage(){
        let cmpDef = {
            componentDef : 'MVEX:wbAllTemplatePage',
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