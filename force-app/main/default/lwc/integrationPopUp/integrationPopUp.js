import { LightningElement, track, api } from 'lwc';
import saveSettings from '@salesforce/apex/IntegrationPopupController.saveSettings';
import getSettings from '@salesforce/apex/IntegrationPopupController.getSettings';
import saveCustomTempData from '@salesforce/apex/IntegrationPopupController.saveCustomTempData';
import siteData from '@salesforce/apex/IntegrationPopupController.siteData';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { loadStyle } from 'lightning/platformResourceLoader';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';

export default class IntegrationPopUp extends NavigationMixin(LightningElement) {
    @api integrationname = '';
    @track isModalOpen = true;
    @track saveDisable = true;
    @track fieldsData = {};
    @track isLoading = true;
    @track isInitalRender = true;
    @track isClientSecretHidden = true;
    @track siteInfo = {};
    @api channelName = '/event/MVEX__ResponseEvent__e';
    @track callbackURL = '';
    
    // Store original credentials
    originalCredentials = {};
    CREDENTIAL_PLACEHOLDER = '••••••••••••••••';
    CREDENTIAL_DISPLAY_TEXT = 'Confidential Information - Hidden for Security';

    /**
    * Method Name: isAWS
    * @description: Used to check integration name.
    * @returns {Boolean} - Returns true if AWS integration name.
    * Created Date: 27/12/2024
    * Created By: Karan Singh
    */
    get isAWS() {
        return this.integrationname === 'AWS';
    }

    /**
    * Method Name: isGmail
    * @description: Used to check integration name.
    * @returns {Boolean} - Returns true if Gmail integration name.
    * Created Date: 27/12/2024
    * Created By: Karan Singh
    */
    get isGmail() {
        return this.integrationname === 'Gmail';
    }

    /**
    * Method Name: isOutlook
    * @description: Used to check integration name.
    * @returns {Boolean} - Returns true if Outlook integration name.
    * Created Date: 27/12/2024
    * Created By: Karan Singh
    */
    get isOutlook() {
        return this.integrationname === 'Outlook';
    }

    /**
    * Method Name: isWhatsApp
    * @description: Used to check integration name.
    * @returns {Boolean} - Returns true if Whatsapp integration name.
    * Created Date: 27/12/2024
    * Created By: Karan Singh
    */
    get isWhatsApp() {
        return this.integrationname === 'WhatsApp';
    }

    /**
    * Method Name: isGoogle
    * @description: Used to check integration name.
    * @returns {Boolean} - Returns true if Goole integration name.
    * Created Date: 27/12/2024
    * Created By: Vyom Soni
    */
    get isGoogle() {
        return this.integrationname === 'Google';
    }

    get isMeta() {
        return this.integrationname === 'Meta';
    }

    get isInstagram() {
        return this.integrationname === 'Instagram';
    }

    /**
    * Method Name : connectedCallback
    * @description : call the intializeValues method
    * Created Date: 06/08/2024
    * Updated Date: 27/12/2024
    * Created By: Vyom Soni
    * Updated By: Karan Singh
    */
    connectedCallback() {
        try {
            loadStyle(this, MulishFontCss)
                .then(() => {
                    console.log('Css loaded successfully');
                })
                .catch(error => {
                    console.log('Error loading style:', error);
                });
            this.intializeValues();
            this.getSiteInfo();
        } catch (error) {
            console.log('Error in connectedCallback:', error);
        }
    }

    /**
    * Method Name : intializeValues
    * @description : get the record data from the custom settings
    * Created Date: 06/08/2024
    * Created By: Vyom Soni
    */
    intializeValues() {
        try {
            getSettings({ integrationType: this.integrationname })
                .then(data => {
                    this.isLoading = true;
                    if (data) {
                        if (this.integrationname === 'Outlook' || this.integrationname === 'Gmail' || this.integrationname === 'Instagram') {
                            if (data.objectData) {
                                data.objectData.MVEX__Redirect_URI__c = data.siteUrl;
                                this.fieldsData = { ...data.objectData };
                            } else {
                                this.fieldsData = { MVEX__Redirect_URI__c: data.siteUrl };
                            }
                        } else if (this.integrationname === 'Google') {
                            if (data.objectData?.MVEX__Google_Ads_Endpoint__c && data.objectData?.MVEX__Google_Ads_Endpoint__c !== '') {
                                let siteUrl = data.objectData.MVEX__Google_Ads_Endpoint__c;
                                if (siteUrl[siteUrl.length - 1] !== '/') {
                                    this.callbackURL = siteUrl + '/' + 'services/apexrest/MVEX/Lead';
                                } else {
                                    this.callbackURL = siteUrl + 'services/apexrest/MVEX/Lead';
                                }
                            }
                            this.fieldsData = { ...data.objectData };
                        } else if (this.integrationname === 'Meta') {
                            if (data.objectData?.MVEX__META_PAGE_ENDPOINT__c && data.objectData?.MVEX__META_PAGE_ENDPOINT__c !== '') {
                                let siteUrl = data.objectData.MVEX__META_PAGE_ENDPOINT__c;
                                if (siteUrl[siteUrl.length - 1] !== '/') {
                                    this.callbackURL = siteUrl + '/' + 'services/apexrest/MVEX/PAGE/webhooks';
                                } else {
                                    this.callbackURL = siteUrl + 'services/apexrest/MVEX/PAGE/webhooks';
                                }
                            }
                            this.fieldsData = { ...data.objectData };
                        } else {
                            this.fieldsData = { ...data.objectData };
                        }
                        
                        // Store original AWS credentials if editing (only if values exist)
                        if (this.integrationname === 'AWS' && data.objectData) {
                            if (data.objectData.MVEX__AWS_Access_Key__c) {
                                this.originalCredentials.MVEX__AWS_Access_Key__c = data.objectData.MVEX__AWS_Access_Key__c;
                                this.fieldsData.MVEX__AWS_Access_Key__c = this.CREDENTIAL_DISPLAY_TEXT;
                            }
                            if (data.objectData.MVEX__AWS_Secret_Access_Key__c) {
                                this.originalCredentials.MVEX__AWS_Secret_Access_Key__c = data.objectData.MVEX__AWS_Secret_Access_Key__c;
                                this.fieldsData.MVEX__AWS_Secret_Access_Key__c = this.CREDENTIAL_DISPLAY_TEXT;
                            }
                        }
                        
                        // Store original Gmail credentials if editing (only if values exist)
                        if (this.integrationname === 'Gmail' && data.objectData) {
                            if (data.objectData.MVEX__Client_ID__c) {
                                this.originalCredentials.MVEX__Client_ID__c = data.objectData.MVEX__Client_ID__c;
                                this.fieldsData.MVEX__Client_ID__c = data.objectData.MVEX__Client_ID__c;
                            }
                            if (data.objectData.MVEX__Client_Secret__c) {
                                this.originalCredentials.MVEX__Client_Secret__c = data.objectData.MVEX__Client_Secret__c;
                                this.fieldsData.MVEX__Client_Secret__c = data.objectData.MVEX__Client_Secret__c;
                            }
                            if (data.objectData.MVEX__Refresh_Token__c) {
                                this.originalCredentials.MVEX__Refresh_Token__c = data.objectData.MVEX__Refresh_Token__c;
                                this.fieldsData.MVEX__Refresh_Token__c = data.objectData.MVEX__Refresh_Token__c;
                            }
                        }
                        
                        // Store original Outlook credentials if editing (only if values exist)
                        if (this.integrationname === 'Outlook' && data.objectData) {
                            if (data.objectData.MVEX__Client_ID__c) {
                                this.originalCredentials.MVEX__Client_ID__c = data.objectData.MVEX__Client_ID__c;
                                this.fieldsData.MVEX__Client_ID__c = this.CREDENTIAL_DISPLAY_TEXT;
                            }
                            if (data.objectData.MVEX__Azure_Client_Secret__c) {
                                this.originalCredentials.MVEX__Azure_Client_Secret__c = data.objectData.MVEX__Azure_Client_Secret__c;
                                this.fieldsData.MVEX__Azure_Client_Secret__c = this.CREDENTIAL_DISPLAY_TEXT;
                            }
                            if (data.objectData.MVEX__Refresh_Token__c) {
                                this.originalCredentials.MVEX__Refresh_Token__c = data.objectData.MVEX__Refresh_Token__c;
                                this.fieldsData.MVEX__Refresh_Token__c = this.CREDENTIAL_DISPLAY_TEXT;
                            }
                        }
                        
                        // Store original Instagram credentials if editing (only if values exist)
                        if (this.integrationname === 'Instagram' && data.objectData) {
                            if (data.objectData.MVEX__ClientId__c) {
                                this.originalCredentials.MVEX__ClientId__c = data.objectData.MVEX__ClientId__c;
                                this.fieldsData.MVEX__ClientId__c = this.CREDENTIAL_DISPLAY_TEXT;
                            }
                            if (data.objectData.MVEX__ClientSecret__c) {
                                this.originalCredentials.MVEX__ClientSecret__c = data.objectData.MVEX__ClientSecret__c;
                                this.fieldsData.MVEX__ClientSecret__c = this.CREDENTIAL_DISPLAY_TEXT;
                            }
                            if (data.objectData.MVEX__AccessToken__c) {
                                this.originalCredentials.MVEX__AccessToken__c = data.objectData.MVEX__AccessToken__c;
                                this.fieldsData.MVEX__AccessToken__c = this.CREDENTIAL_DISPLAY_TEXT;
                            }
                            if (data.objectData.MVEX__Long_Access_Token__c) {
                                this.originalCredentials.MVEX__Long_Access_Token__c = data.objectData.MVEX__Long_Access_Token__c;
                                this.fieldsData.MVEX__Long_Access_Token__c = this.CREDENTIAL_DISPLAY_TEXT;
                            }
                        }
                        
                        // Store original Meta credentials if editing (only if values exist)
                        if (this.integrationname === 'Meta' && data.objectData) {
                            if (data.objectData.MVEX__VERIFY_TOKEN__c) {
                                this.originalCredentials.MVEX__VERIFY_TOKEN__c = data.objectData.MVEX__VERIFY_TOKEN__c;
                                this.fieldsData.MVEX__VERIFY_TOKEN__c = this.CREDENTIAL_DISPLAY_TEXT;
                            }
                            if (data.objectData.MVEX__APP_ID__c) {
                                this.originalCredentials.MVEX__APP_ID__c = data.objectData.MVEX__APP_ID__c;
                                this.fieldsData.MVEX__APP_ID__c = this.CREDENTIAL_DISPLAY_TEXT;
                            }
                            if (data.objectData.MVEX__APP_SECRET__c) {
                                this.originalCredentials.MVEX__APP_SECRET__c = data.objectData.MVEX__APP_SECRET__c;
                                this.fieldsData.MVEX__APP_SECRET__c = this.CREDENTIAL_DISPLAY_TEXT;
                            }
                            if (data.objectData.MVEX__ACCESS_TOKEN__c) {
                                this.originalCredentials.MVEX__ACCESS_TOKEN__c = data.objectData.MVEX__ACCESS_TOKEN__c;
                                this.fieldsData.MVEX__ACCESS_TOKEN__c = this.CREDENTIAL_DISPLAY_TEXT;
                            }
                        }
                    } else {
                        this.fieldsData = {};
                    }
                    this.isLoading = false;
                    this.registerErrorListener();
                    this.handleSubscribe();
                })
                .catch(error => {
                    this.showToast('Error loading settings', error, 'error');
                    this.isLoading = false;
                });
        } catch (error) {
            console.log('error in intializeValues -> ', error.stack);
        }
    }

    /**
    * Method Name : getSiteInfo
    * @description : get the site info and store it in the siteInfo variable.
    * Created Date: 27/12/2024
    * Created By: Karan Singh
    */
    getSiteInfo() {
        try {
            if (this.integrationname == 'WhatsApp' || this.integrationname == 'Google' || this.integrationname == 'Meta') {
                siteData()
                    .then(data => {
                        this.siteInfo = data;
                    })
                    .catch(error => {
                        this.showToast('Error loading site info', error, 'error');
                    });
            }
        } catch (error) {
            console.log('error in getSiteInfo -> ', error.stack);
        }
    }

    handleSubscribe() {
        const self = this;
        const messageCallback = function (response) {
            let obj = JSON.parse(JSON.stringify(response));
            let objData = obj.data.payload;
            self.status = objData.MVEX__Status__c;
            self.responseBody = objData.MVEX__JSONBody__c;
            if (self.status === 'Success') {
                self.fieldsData.MVEX__Refresh_Token__c = self.responseBody;
                self.showToast('Success', 'Authorization has been successfully completed.', 'success');
            } else if (self.status === 'Instagram') {
                self.fieldsData.MVEX__AccessToken__c = self.responseBody;
                self.fieldsData.MVEX__Long_Access_Token__c = objData.MVEX__PortalName__c;
                self.fieldsData.MVEX__User_Id__c = objData.MVEX__Listing_Id__c;
                self.showToast('Success', 'Authorization has been successfully completed.', 'success');
            }
        };

        subscribe(self.channelName, -1, messageCallback).then(response => {
            self.subscription = response;
        });
    }

    registerErrorListener() {
        onError(error => {
            console.log('Received error from server: ', JSON.stringify(error));
        });
    }

    /**
    * Method Name : openModal
    * @description : show the pop-up modal
    * Created Date: 06/08/2024
    * Updated Date: 27/12/2024
    * Created By: Vyom Soni
    * Updated By: Karan Singh
    */
    openModal() {
        try {
            this.isModalOpen = true;
        } catch (error) {
            console.log('error in openModal -> ', error.stack);
        }
    }

    /**
    * Method Name : closeModal
    * @description : close the pop-up modal
    * Created Date: 06/08/2024
    * Updated Date: 27/12/2024
    * Created By: Vyom Soni
    * Updated By: Karan Singh
    */
    closeModal() {
        try {
            if (typeof window !== 'undefined') {
                this.dispatchEvent(new CustomEvent('closemodal', { detail: true }));
            }
        } catch (error) {
            console.log('error in closeModal -> ', error.stack);
        }
    }

    /**
    * Method Name : handleInputChange
    * @description : validate the change object as per input values
    * Created Date: 06/08/2024
    * Updated Date: 27/12/2024
    * Created By:Vyom Soni
    * Updated By: Karan Singh
    */
    handleInputChange(event) {
        try {
            const urlPattern = new RegExp(
                '^(https?:\\/\\/)?' +
                '((([a-zA-Z0-9\\-\\.]+)\\.([a-zA-Z]{2,})|([0-9]{1,3}\\.){3}[0-9]{1,3}))' +
                '(\\:[0-9]{1,5})?' +
                '(\\/.*)?$'
            );

            const field = event.target.dataset.id;
            const value = event.target.value;

            this.saveDisable = false;
            
            // Check if user is changing placeholder credential fields
            if (this.integrationname === 'AWS' && 
                (field === 'MVEX__AWS_Access_Key__c' || field === 'MVEX__AWS_Secret_Access_Key__c')) {
                // If the value is still the placeholder, don't update
                if (value !== this.CREDENTIAL_DISPLAY_TEXT && value !== '') {
                    this.fieldsData[field] = value;
                } else if (value === '') {
                    this.fieldsData[field] = value;
                }
            } else if (this.integrationname === 'Gmail' && 
                (field === 'MVEX__Client_ID__c' || field === 'MVEX__Client_Secret__c' || field === 'MVEX__Refresh_Token__c')) {
                // If the value is still the placeholder, don't update
                if (value !== this.CREDENTIAL_DISPLAY_TEXT && value !== '') {
                    this.fieldsData[field] = value;
                } else if (value === '') {
                    this.fieldsData[field] = value;
                }
            } else if (this.integrationname === 'Outlook' && 
                (field === 'MVEX__Client_ID__c' || field === 'MVEX__Azure_Client_Secret__c' || field === 'MVEX__Refresh_Token__c')) {
                // If the value is still the placeholder, don't update
                if (value !== this.CREDENTIAL_DISPLAY_TEXT && value !== '') {
                    this.fieldsData[field] = value;
                } else if (value === '') {
                    this.fieldsData[field] = value;
                }
            } else if (this.integrationname === 'Instagram' && 
                (field === 'MVEX__ClientId__c' || field === 'MVEX__ClientSecret__c' || field === 'MVEX__AccessToken__c' || field === 'MVEX__Long_Access_Token__c')) {
                // If the value is still the placeholder, don't update
                if (value !== this.CREDENTIAL_DISPLAY_TEXT && value !== '') {
                    this.fieldsData[field] = value;
                } else if (value === '') {
                    this.fieldsData[field] = value;
                }
            } else if (this.integrationname === 'Meta' && 
                (field === 'MVEX__ACCESS_TOKEN__c' || field === 'MVEX__VERIFY_TOKEN__c' || field === 'MVEX__APP_ID__c' || field === 'MVEX__APP_SECRET__c')) {
                // If the value is still the placeholder, don't update
                if (value !== this.CREDENTIAL_DISPLAY_TEXT && value !== '') {
                    this.fieldsData[field] = value;
                } else if (value === '') {
                    this.fieldsData[field] = value;
                }
            } else {
                this.fieldsData[field] = value;
            }

            // Validate the input
            if (field === 'MVEX__Redirect_URI__c' && !urlPattern.test(value)) {
                event.target.setCustomValidity('Please enter a valid URL.');
            } else if (/\s/.test(value)) {
                event.target.setCustomValidity('Spaces are not allowed.');
            } else {
                event.target.setCustomValidity('');
            }

            event.target.reportValidity();

            this.addCSSForBtns(field);
        } catch (error) {
            console.log('error in handleInputChange -> ', error.stack);
        }
    }

    /**
    * Method Name : handleInputChange
    * @description : validate the change object as per input values
    * @param {field} - field name
    * Created Date: 06/08/2024
    * Created By:Vyom Soni
    */
    addCSSForBtns(field) {
        try {
            if (field == 'MVEX__Redirect_URI__c') {
                const inputField = this.template.querySelector('lightning-input[data-id="MVEX__Redirect_URI__c"]');

                if (inputField && !inputField.checkValidity()) {
                    const button = this.template.querySelector('.copy-button');
                    button.style.marginBottom = '18px';
                } else {
                    const button = this.template.querySelector('.copy-button');
                    button.style.marginBottom = '0px';
                }
            } else if (field == 'MVEX__Refresh_Token__c') {
                const inputField = this.template.querySelector('lightning-input[data-id="MVEX__Refresh_Token__c"]');

                if (inputField && !inputField.checkValidity()) {
                    const button = this.template.querySelector('.link-button');
                    button.style.marginBottom = '18px';
                } else {
                    const button = this.template.querySelector('.link-button');
                    button.style.marginBottom = '0px';
                }
            } else if (field == 'MVEX__AWS_Secret_Access_Key__c') {
                const inputField = this.template.querySelector('lightning-input[data-id="MVEX__AWS_Secret_Access_Key__c"]');

                if (inputField && !inputField.checkValidity()) {
                    const button = this.template.querySelector('.toggle-btn');
                    button.style.marginBottom = '18px';
                } else {
                    const button = this.template.querySelector('.toggle-btn');
                    button.style.marginBottom = '0px';
                }
            } else if (field == 'MVEX__Client_Secret__c') {
                const inputField = this.template.querySelector('lightning-input[data-id="MVEX__Client_Secret__c"]');

                if (inputField && !inputField.checkValidity()) {
                    const button = this.template.querySelector('.toggle-btn');
                    button.style.marginBottom = '18px';
                } else {
                    const button = this.template.querySelector('.toggle-btn');
                    button.style.marginBottom = '0px';
                }
            } else if (field == 'MVEX__Azure_Client_Secret__c') {
                const inputField = this.template.querySelector('lightning-input[data-id="MVEX__Azure_Client_Secret__c"]');

                if (inputField && !inputField.checkValidity()) {
                    const button = this.template.querySelector('.toggle-btn');
                    button.style.marginBottom = '18px';
                } else {
                    const button = this.template.querySelector('.toggle-btn');
                    button.style.marginBottom = '0px';
                }
            }
        } catch (error) {
            console.log('error in addcssforbts -->', error.stack);
        }
    }

    /**
    * Method Name : checkValidity
    * @description : check the validation for the all input fields.
    * Created Date: 06/08/2024
    * Updated Date: 27/12/2024
    * Created By: Vyom Soni
    * Updated By: Karan Singh
    */
    checkValidity() {
        try {
            const inputs = this.template.querySelectorAll('lightning-input');
            let allValid = true;

            inputs.forEach(input => {
                // Trigger validation on each input
                input.reportValidity();

                // If any input is invalid, set allValid to false
                if (!input.checkValidity()) {
                    allValid = false;
                }

                // Check for masked sensitive data
                if (input.value === '[SENSITIVE_DATA_MASKED]') {
                    input.setCustomValidity('Please enter a valid value.');
                    input.reportValidity();
                    allValid = false;
                }
            });

            // Disable the save button if any input is invalid
            this.saveDisable = !allValid;
            return allValid;
        } catch (error) {
            console.log('error in checkValidity -> ', error.stack);
        }
    }

    /**
    * Method Name : saveDetails
    * @description : save the input data in custom settings
    * Created Date: 06/08/2024
    * Updated Date: 27/12/2024
    * Created By: Vyom Soni
    * Updated By: Karan Singh
    */
    saveDetails() {
        try {
            if (this.checkValidity()) {
                let dataToSave = { ...this.fieldsData };
                
                // For AWS, restore original credentials if placeholder is still there
                if (this.integrationname === 'AWS') {
                    if (dataToSave.MVEX__AWS_Access_Key__c === this.CREDENTIAL_DISPLAY_TEXT) {
                        dataToSave.MVEX__AWS_Access_Key__c = this.originalCredentials.MVEX__AWS_Access_Key__c;
                    }
                    if (dataToSave.MVEX__AWS_Secret_Access_Key__c === this.CREDENTIAL_DISPLAY_TEXT) {
                        dataToSave.MVEX__AWS_Secret_Access_Key__c = this.originalCredentials.MVEX__AWS_Secret_Access_Key__c;
                    }
                }
                
                // For Gmail: STRICTLY FILTER to only save Refresh Token
                // We discard Client ID, Secret, and Redirect URI here so they are never sent to Apex for saving
                if (this.integrationname === 'Gmail') {
                    // dataToSave = {
                    //     MVEX__Refresh_Token__c: this.fieldsData.MVEX__Refresh_Token__c
                    // };
                    if (this.fieldsData.MVEX__Client_ID__c) {
                        dataToSave.MVEX__Client_ID__c = this.fieldsData.MVEX__Client_ID__c;
                    }
                    if (this.fieldsData.MVEX__Client_Secret__) {
                        dataToSave.MVEX__Client_Secret__c = this.fieldsData.MVEX__Client_Secret__c;
                    }
                    if (this.fieldsData.MVEX__Refresh_Token__c) {
                        dataToSave.MVEX__Refresh_Token__c = this.fieldsData.MVEX__Refresh_Token__c;
                    }
                }
                
                // For Outlook, restore original credentials if placeholder is still there
                if (this.integrationname === 'Outlook') {
                    if (dataToSave.MVEX__Client_ID__c === this.CREDENTIAL_DISPLAY_TEXT) {
                        dataToSave.MVEX__Client_ID__c = this.originalCredentials.MVEX__Client_ID__c;
                    }
                    if (dataToSave.MVEX__Azure_Client_Secret__c === this.CREDENTIAL_DISPLAY_TEXT) {
                        dataToSave.MVEX__Azure_Client_Secret__c = this.originalCredentials.MVEX__Azure_Client_Secret__c;
                    }
                    if (dataToSave.MVEX__Refresh_Token__c === this.CREDENTIAL_DISPLAY_TEXT) {
                        dataToSave.MVEX__Refresh_Token__c = this.originalCredentials.MVEX__Refresh_Token__c;
                    }
                }
                
                // For Instagram, restore original credentials if placeholder is still there
                if (this.integrationname === 'Instagram') {
                    if (dataToSave.MVEX__ClientId__c === this.CREDENTIAL_DISPLAY_TEXT) {
                        dataToSave.MVEX__ClientId__c = this.originalCredentials.MVEX__ClientId__c;
                    }
                    if (dataToSave.MVEX__ClientSecret__c === this.CREDENTIAL_DISPLAY_TEXT) {
                        dataToSave.MVEX__ClientSecret__c = this.originalCredentials.MVEX__ClientSecret__c;
                    }
                    if (dataToSave.MVEX__AccessToken__c === this.CREDENTIAL_DISPLAY_TEXT) {
                        dataToSave.MVEX__AccessToken__c = this.originalCredentials.MVEX__AccessToken__c;
                    }
                    if (dataToSave.MVEX__Long_Access_Token__c === this.CREDENTIAL_DISPLAY_TEXT) {
                        dataToSave.MVEX__Long_Access_Token__c = this.originalCredentials.MVEX__Long_Access_Token__c;
                    }
                }
                
                // For Meta, restore original credentials if placeholder is still there
                if (this.integrationname === 'Meta') {
                    if (dataToSave.MVEX__VERIFY_TOKEN__c === this.CREDENTIAL_DISPLAY_TEXT) {
                        dataToSave.MVEX__VERIFY_TOKEN__c = this.originalCredentials.MVEX__VERIFY_TOKEN__c;
                    }
                    if (dataToSave.MVEX__APP_ID__c === this.CREDENTIAL_DISPLAY_TEXT) {
                        dataToSave.MVEX__APP_ID__c = this.originalCredentials.MVEX__APP_ID__c;
                    }
                    if (dataToSave.MVEX__APP_SECRET__c === this.CREDENTIAL_DISPLAY_TEXT) {
                        dataToSave.MVEX__APP_SECRET__c = this.originalCredentials.MVEX__APP_SECRET__c;
                    }
                    if (dataToSave.MVEX__ACCESS_TOKEN__c === this.CREDENTIAL_DISPLAY_TEXT) {
                        dataToSave.MVEX__ACCESS_TOKEN__c = this.originalCredentials.MVEX__ACCESS_TOKEN__c;
                    }
                }
                
                const jsonData = JSON.stringify(dataToSave);

                console.log('jsonData -> ', jsonData);
                
                saveSettings({ jsonData: jsonData, integrationType: this.integrationname })
                    .then(() => {
                        this.showToast('Success', 'Credentials saved successfully.', 'success');
                        this.dispatchEvent(new CustomEvent('closemodal', { detail: false }));
                    })
                    .catch(error => {
                        this.showToast('Error while saving settings', error.body.message, 'error');
                    });
            } else {
                this.showToast('Error', 'Please fill out all required fields.', 'error');
            }
        } catch (error) {
            console.log('error in saveDetails -> ', error.stack);
        }
    }

    /**
    * Method Name : generateToken
    * @description : generate the token for whatsapp.
    * Created Date: 27/12/2024
    * Created By: Karan Singh
    */
    generateToken() {
        try {
            let clientId = this.fieldsData.MVEX__Whatsapp_App_Id__c;
            let clientSecret = this.fieldsData.MVEX__WhatsApp_Client_Secret__c;
            let configId = this.fieldsData.MVEX__Whatsapp_Configure_Id__c;
            let selectedSite = this.fieldsData.MVEX__Webhook_Callback_URL__c;
            let phoneId = this.fieldsData.MVEX__Whatsapp_Phone_Number_Id__c;
            let accountId = this.fieldsData.MVEX__Whatsapp_Business_Account_Id__c;

            const vfPageUrl = `/apex/MVEX__FacebookSDK?clientId=${clientId}&clientSecret=${clientSecret}&configId=${configId}&selectedSite=${selectedSite}&phoneId=${phoneId}&accountId=${accountId}`;
            window.globalThis.location.href = vfPageUrl;
        } catch (error) {
            console.log('error in generateToken -> ', error.stack);
        }
    }

    /**
    * Method Name : handleCredentialFocus
    * @description : Select all text when focusing on credential input fields
    * Created Date: 21/01/2026
    * Created By: Karan Singh
    */
    handleCredentialFocus(event) {
        try {
            const input = event.target;
            if (input && input.value === this.CREDENTIAL_DISPLAY_TEXT) {
                // Select all text
                setTimeout(() => {
                    const inputElement = this.template.querySelector(`lightning-input[data-id="${event.target.dataset.id}"]`);
                    if (inputElement) {
                        const nativeInput = inputElement.shadowRoot?.querySelector('input');
                        if (nativeInput) {
                            nativeInput.select();
                        }
                    }
                }, 0);
            }
        } catch (error) {
            console.log('error in handleCredentialFocus -> ', error.stack);
        }
    }

    /**
    * Method Name : copyTheText
    * @description : copy the text in textbox to clipboard
    * Created Date: 27/12/2024
    * Created By: Karan Singh
    */
    copyTheText() {
        try {
            const redirectURI = this.fieldsData.MVEX__Redirect_URI__c;
            const webhookUrl = this.fieldsData.MVEX__Webhook_Callback_URL__c;
            const googleWebhookUrl = this.fieldsData.MVEX__Google_Ads_Endpoint__c;
            const metaPageWebhookUrl = this.fieldsData.MVEX__META_PAGE_ENDPOINT__c;

            if (redirectURI) {
                navigator.clipboard.writeText(redirectURI).then(() => {
                    this.showToast('Success', 'The Redirect URI has been copied to the clipboard.', 'success');
                }).catch(err => {
                    console.log('Error while copying text : ', err);
                    this.showToast('Error', 'Failed to copy text.', 'error');
                });
            } else if (webhookUrl) {
                navigator.clipboard.writeText(this.callbackURL).then(() => {
                    this.showToast('Success', 'The Redirect URI has been copied to the clipboard.', 'success');
                }).catch(err => {
                    console.log('Error while copying text : ', err);
                    this.showToast('Error', 'Failed to copy text.', 'error');
                });
            } else if (googleWebhookUrl) {
                navigator.clipboard.writeText(this.callbackURL).then(() => {
                    this.showToast('Success', 'The Redirect URI has been copied to the clipboard.', 'success');
                }).catch(err => {
                    console.log('Error while copying text : ', err);
                    this.showToast('Error', 'Failed to copy text.', 'error');
                });
            } else if (metaPageWebhookUrl) {
                navigator.clipboard.writeText(this.callbackURL).then(() => {
                    this.showToast('Success', 'The Redirect URI has been copied to the clipboard.', 'success');
                }).catch(err => {
                    console.log('Error while copying text : ', err);
                    this.showToast('Error', 'Failed to copy text.', 'error');
                });
            }
            else {
                this.showToast('Error', 'Field is empty.', 'error');
            }
        } catch (error) {
            console.log('error in copyTheText -> ', error.stack);
        }
    }

    /**
    * Method Name : redirectToLoginPage
    * @description : redirect to login page
    * Created Date: 27/12/2024
    * Created By: Karan Singh
    */
    redirectToLoginPage() {
        try {
            if (this.integrationname == 'Gmail') {
                this.redirectToGmailLoginPage();
            } else if (this.integrationname == 'Outlook') {
                this.redirectToOutlookLoginPage();
            } else if (this.integrationname == 'Instagram') {
                this.redirectToInstagramLoginPage();
            }
        } catch (error) {
            console.log('error in redirectToLoginPage ->', error.stack);
        }
    }

    redirectToInstagramLoginPage() {
        const requiredFields = ['MVEX__Redirect_URI__c', 'MVEX__ClientId__c', 'MVEX__ClientSecret__c'];

        for (let i = 0; i < requiredFields.length; i++) {
            const field = requiredFields[i];
            if (!this.fieldsData[field]) {
                this.showToast('Error', `${field.replace('', '').replace('__c', '').replace(/_/g, ' ')} is empty. Please fill it before proceeding.`, 'error');
                return;
            }
        }

        this.saveTempData(this.fieldsData.MVEX__ClientId__c, this.fieldsData.MVEX__ClientSecret__c, this.fieldsData.MVEX__Redirect_URI__c);

        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: 'https://www.instagram.com/oauth/authorize?client_id=' + this.fieldsData.MVEX__ClientId__c + '&redirect_uri=' + this.fieldsData.MVEX__Redirect_URI__c + '&response_type=code&scope=business_basic%2Cbusiness_manage_messages%2Cbusiness_manage_comments%2Cbusiness_content_publish'
            }
        });
    }

    /**
    * Method Name : redirectToGmailLoginPage
    * @description : redirect to gmail login page
    * Created Date: 27/12/2024
    * Created By: Karan Singh
    */
    redirectToGmailLoginPage() {
        try {
            const requiredFields = ['MVEX__Redirect_URI__c', 'MVEX__Client_ID__c', 'MVEX__Client_Secret__c'];

            for (let i = 0; i < requiredFields.length; i++) {
                const field = requiredFields[i];
                if (!this.fieldsData[field]) {
                    this.showToast('Error', 'Missing Configuration (Metadata). Please check Custom Metadata configuration.', 'error');
                    return;
                }
            }

            console.log('Client ID:', this.fieldsData.MVEX__Client_ID__c, 'Client Secret:', this.fieldsData.MVEX__Client_Secret__c, 'Redirect URI:', this.fieldsData.MVEX__Redirect_URI__c);
            

            this.saveTempData(this.fieldsData.MVEX__Client_ID__c, this.fieldsData.MVEX__Client_Secret__c, this.fieldsData.MVEX__Redirect_URI__c);
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: 'https://accounts.google.com/o/oauth2/auth?client_id=' + this.fieldsData.MVEX__Client_ID__c + '&redirect_uri=' + this.fieldsData.MVEX__Redirect_URI__c + '&response_type=code&access_type=offline&prompt=consent&scope=https://www.googleapis.com/auth/gmail.send'
                }
            });
        } catch (error) {
            console.log('error in redirectToGmailLoginPage ->', error.stack);
        }
    }

    /**
    * Method Name : redirectToOutlookLoginPage
    * @description : redirect to outlook login page
    * Created Date: 27/12/2024
    * Created By: Karan Singh
    */
    redirectToOutlookLoginPage() {
        try {
            const requiredFields = ['MVEX__Redirect_URI__c', 'MVEX__Client_ID__c', 'MVEX__Client_Secret__c'];

            for (let i = 0; i < requiredFields.length; i++) {
                const field = requiredFields[i];
                if (!this.fieldsData[field]) {
                    this.showToast('Error', `${field.replace('', '').replace('__c', '').replace(/_/g, ' ')} is empty. Please fill it before proceeding.`, 'error');
                    return;
                }
            }

            this.saveTempData(this.fieldsData.MVEX__Client_ID__c, this.fieldsData.MVEX__Client_Secret__c, this.fieldsData.MVEX__Redirect_URI__c);
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: 'https://login.microsoftonline.com/common/oauth2/v2.0/authorize?client_id=' + this.fieldsData.MVEX__Client_ID__c + '&response_type=code&redirect_uri=' + this.fieldsData.MVEX__Redirect_URI__c + '&response_mode=query&scope=offline_access%20User.Read%20Mail.Read%20Mail.Send&state=12345&prompt=login'
                }
            });
        } catch (error) {
            console.log('error in redirectToOutlookLoginPage ->', error.stack);
        }
    }

    /**
    * Method Name : saveTempData
    * @description : save temp data
    * @param {String} clientId
    * @param {String} clientSecret
    * @param {String} redirectURI
    * Created Date: 27/12/2024
    * Created By: Karan Singh
    */
    saveTempData(clientId, clientSecret, redirectURI) {
        try {
            saveCustomTempData({ clientId, clientSecret, redirectURI })
                .then(() => {
                    console.log('Data Saved Successfully.');
                })
                .catch(error => {
                    console.log('Failed to save data : ', error);
                });
        } catch (error) {
            console.log('error in saveTempData ->', error.stack);
        }
    }

    /**
    * Method Name : showToast
    * @description : show toast message
    * @param {String} title
    * @param {String} message
    * @param {String} variant
    * Created Date: 27/12/2024
    * Created By: Karan Singh
    */
    showToast(title, message, variant) {
        try {
            if (typeof window !== 'undefined') {
                const event = new ShowToastEvent({
                    title: title,
                    message: message,
                    variant: variant,
                });
                this.dispatchEvent(event);
            }
        } catch (error) {
            console.log('error in showToast ->', error.stack);
        }
    }

    /**
    * Method Name : toggleClientSecret
    * @description : toggle client secret
    * Created Date: 27/12/2024
    * Created By: Karan Singh
    */
    toggleClientSecret() {
        try {
            const secretKeyInput = this.template.querySelector('lightning-input[data-name="secret-key-input"]');

            if (this.isClientSecretHidden) {
                secretKeyInput.type = 'text';
            } else {
                secretKeyInput.type = 'password';
            }

            this.isClientSecretHidden = !this.isClientSecretHidden;
        } catch (error) {
            console.log('error in toggleClientSecret ->', error.stack);
        }
    }

    /**
    * Method Name : handleValueChange
    * @description : handle value change
    * Created Date: 27/12/2024
    * Created By: Karan Singh
    */
    handleValueChange(event) {
        try {
            const field = event.target.dataset.id;
            const selectedValue = event.detail.value;
            if (this.integrationname == 'Google') {
                if (selectedValue[selectedValue.length - 1] !== '/') {
                    this.callbackURL = selectedValue + '/' + 'services/apexrest/MVEX/Lead';
                } else {
                    this.callbackURL = selectedValue + 'services/apexrest/MVEX/Lead';
                }
            } else if (this.integrationname == 'Meta') {
                if (selectedValue[selectedValue.length - 1] !== '/') {
                    this.callbackURL = selectedValue + '/' + 'services/apexrest/MVEX/PAGE/webhooks/';
                } else {
                    this.callbackURL = selectedValue + 'services/apexrest/MVEX/PAGE/webhooks/';
                }
            }

            this.fieldsData[field] = selectedValue;

        } catch (error) {
            console.log('error in handleChange: ', error.stack);
        }
    }


    disconnectedCallback() {
        unsubscribe(this.subscription, response => {
            console.log('Unsubscribed from platform event channel', response);
        });
    }

}