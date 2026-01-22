import { LightningElement, track, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
import { loadStyle } from 'lightning/platformResourceLoader';
export default class RecordConfigBodyCmp extends NavigationMixin(LightningElement) {

    @track activeTabId = 'tab1';
    @api customParam = '';
    // @track selectedTabObject = 'Listing__c';
    @api featureName;
    @api isFromListingManager;
    @track isModalOpen = false;

    // Computed properties for conditional rendering and styling
    get isTab1Active() {
        return this.featureName === 'Listing Manager';
    }

    get isTab2Active() {
        return this.featureName === 'Marketing List';
    }

    // get isTab3Active() {
    //     return this.activeTabId === 'tab3';
    // }

    // get isTab4Active() {
    //     return this.activeTabId === 'tab4';
    // }

    get selectedTabObject() {

        switch (this.featureName) {
            case 'Marketing List':
                return 'Contact';
            case 'Listing Manager':
                return 'MVEX__Listing__c';
            case 'Listing_Configuration':  // Add this new case
                return 'MVEX__Listing__c';
            case 'Inquiry Manager':  // Add this new case
                return 'MVEX__Inquiry__c';
            default:
                return '';
        }
    }

    // get tab2Class() {
    //     return this.isTab2Active ? 'active-tab' : 'tab';
    // }

    // get tab3Class() {
    //     return this.isTab3Active ? 'active-tab' : 'tab';
    // }

    // get tab4Class() {
    //     return this.isTab4Active ? 'active-tab' : 'tab';
    // }

    connectedCallback() {
        loadStyle(this, MulishFontCss)
            .then(() => {
                console.log('External Css Loaded');
            })
            .catch(error => {
                console.log('Error occuring during loading external css', error);
            });
        // if (this.customParam == 'MarketingList') {
        //     this.activeTabId = 'tab2';
        //     this.selectedTabObject = 'Contact';
        // }
    }

    handleTabClick(event) {
        this.activeTabId = event.target.dataset.tabId;
        // this.selectedTabObject = event.target.dataset.objectname;
    }

    backToControlCenter(event) {
        try {
            event.preventDefault();
            let componentDef = {};
            if (this.customParam == 'MarketingList') {
                componentDef = { componentDef: "MVEX:marketingListCmp" };
            } else if (this.isFromListingManager) {
                componentDef = { componentDef: "MVEX:listingManager" };
            } else {
                this[NavigationMixin.Navigate]({
                    type: "standard__navItemPage",
                    attributes: {
                        apiName: "Control_Center",
                    },
                });
                return;
            }

            let encodedComponentDef = btoa(JSON.stringify(componentDef));
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: '/one/one.app#' + encodedComponentDef
                }
            });
        } catch (error) {
            console.log('error--> ', error);
        }
    }

    openModal(){
        this.isModalOpen = true
    }

    @api
    handleDialogueClose(){
        this.isModalOpen = false;
    }
}