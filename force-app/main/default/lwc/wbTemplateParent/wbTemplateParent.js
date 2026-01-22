/**
 * Component Name: WbTemplateParent
 * @description: Used LWC components to display child lwc component that are wbcreateTemplatePage and wbTemplateCategory.
 * Date: 30/04/2025
 * Created By: Rachit Shah
 */


import { LightningElement,track,api } from 'lwc';

export default class wbTemplateParent extends LightningElement {
    @track showTemplateCategory = true;
    @track showCreateTemplateTest = false;

    @api edittemplateid;

    selectedOption = 'custom';
    selectedTab = 'section1';
    activeTab;
    showLicenseError = false;

    connectedCallback(){
        if((this.edittemplateid != undefined) && (this.edittemplateid != '') && (this.edittemplateid != null)){
            this.showTemplateCategory = false;
            this.showCreateTemplateTest = true;
        }
    }

    // Handling 'Next' event from Category page
    handleNext(event) {
        const { selectedOption, selectedTab, activeTab } = event.detail;
        // this.selectedTabName = selectedTabName;
        this.selectedOption = selectedOption;
        this.selectedTab = selectedTab;
        this.activeTab = activeTab;

        this.showTemplateCategory = false;
        this.showCreateTemplateTest = true;
    }

    // Handling 'Previous' event from CreateTemplate page
    handlePrevious(event) {
        const { selectedOption, selectedTab, activeTab } = event.detail;
        this.selectedOption = selectedOption;
        this.selectedTab = selectedTab;
        this.activeTab = activeTab;

        this.showTemplateCategory = true;
        this.showCreateTemplateTest = false;
    }

    // Handling special case if createTemplate clicks "back" (same as previous)
    handleCreatedTemplateBack(event) {
        this.handlePrevious(event);
    }
}