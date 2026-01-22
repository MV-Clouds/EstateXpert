import { LightningElement,api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
// import externalDocUrl from '@salesforce/label/c.MetaDocumentationUrl';

export default class WbFlowPreview extends NavigationMixin(LightningElement) {
    @api flowname;
    showPreview=false;
    screens = [];
    detailsOptions = [];
    detailsValue;
    previewClass = 'preview';
    // documentationUrl = externalDocUrl;
    theme = 'light';

    @api
    set jsonstringdata(value) {
        this._jsonstringdata = value;
        try {
            const parsed = JSON.parse(value);
            this.screens = parsed.screens || [];
            this.detailsOptions = this.screens.map(screen => ({
                label: screen.id,
                value: screen.id
            }));
            this.detailsValue = this.detailsOptions.length ? this.detailsOptions[0].value : null;
        } catch (e) {
            this.detailsOptions = [];
            this.detailsValue = null;
        }
    }

    get jsonstringdata() {
        return this._jsonstringdata;
    }

    get previewContainerClass() {
        return `preview-container ${this.theme}-theme`;
    }

    @api
    runPreview() {
        this.showPreview = true; // Show the preview
        const previewer = this.template.querySelector('c-whatsapp-flow-previewer');
        if (previewer) {
            previewer.runPreview(); 
        }
    }
    
    handlePreviewFlow() {
        this.showPreview= true;
         requestAnimationFrame(() => {
            this.previewClass = 'preview slide-up';
        });
    }

    handleSettingsMenuSelect(event) {
        this.theme = event.detail.value; 
        this.showPreview=false;
    }

    handleDetailsChange(event) {
        this.detailsValue = event.detail.value;
    }

    // handleDocumentClick() {
    //     this[NavigationMixin.Navigate]({
    //         type: 'standard__webPage',
    //         attributes: {
    //             url: this.documentationUrl
    //         }
    //     });
    // }

    handleRefreshAll() {
        const previewer = this.template.querySelector('c-whatsapp-flow-previewer');
        if (previewer) {
            previewer.runPreview(); 
        }
    }

    handleClose() {
        this.previewClass = 'preview slide-down';
        setTimeout(() => {
            this.showPreview = false;
        }, 300); 
    }
}