import { LightningElement, api, track } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
import getXMLFeedListingsData from "@salesforce/apex/PortalMappingController.getXMLFeedListingsData";
import { NavigationMixin } from 'lightning/navigation';
import { errorDebugger } from 'c/globalProperties';

export default class ListOfPublishedListings extends NavigationMixin(LightningElement) {

    @api portalName;
    @api portalId;
    @track listingsDatas = [];
    @track isLoading = true;

    /**
    * Method Name: isDataAvailable
    * @description: Used to check the data is available.
    * @return Boolean
    * Created Date: 23/12/2024
    * Created By: Karan Singh
    */
    get isDataAvailable() {
        return this.listingsDatas && this.listingsDatas.length > 0;
    }

    /**
    * Method Name: connectedCallback
    * @description: Used to call the getListingsData method.
    * Created Date: 23/12/2024
    * Created By: Karan Singh
    */
    connectedCallback() {
        try {
            loadStyle(this, MulishFontCss);
            this.getListingsData();
        } catch (error) {
            errorDebugger('ListOfPublishedListings', 'connectedCallback', error, 'warn', 'Error in connectedCallback');
        }
    }

    /**
    * Method Name: getListingsData
    * @description: Used to get the XML Feed listing.
    * Created Date: 23/12/2024
    * Created By: Karan Singh
    */
    getListingsData() {
        try {
            getXMLFeedListingsData({ portalId: this.portalId })
            .then(result => {
                if (result.status == 'Success') {
                    if (result.data?.length > 0) {
                        this.listingsDatas = result.data;
                    }
                }
                this.isLoading = false;
            })
            .catch(error => {
                errorDebugger('ListOfPublishedListings', 'getListingsData', error, 'warn', 'Error in getListingsData');
                this.isLoading = false;
            });
        } catch (error) {
            errorDebugger('ListOfPublishedListings', 'getListingsData', error, 'warn', 'Error in getListingsData');
        }
    }
    
    /**
    * Method Name: handleCloseModal
    * @description: Used to close the modal.
    * Created Date: 23/12/2024
    * Created By: Karan Singh
    */
    handleCloseModal() {
        try {
            if (typeof window !== 'undefined') {
                let custEvent = new CustomEvent('closemodal', {
                    detail: false
                });
                this.dispatchEvent(custEvent);
            }
        } catch (error) {
            errorDebugger('ListOfPublishedListings', 'handleCloseModal', error, 'warn', 'Error in handleCloseModal');  
        }
    }

    /**
    * Method Name: redirectToListing
    * @description: Used to redirect to listing.
    * Created Date: 23/12/2024
    * Created By: Karan Singh
    */
    redirectToListing(event) {
        try {
            const listingId = event.target.dataset.id;
            this[NavigationMixin.GenerateUrl]({
                type: "standard__recordPage",
                attributes: {
                    recordId: listingId,
                    objectApiName: 'MVEX__Listing__c',
                    actionName: 'view'
                }
            }).then(url => {
                window?.globalThis?.open(url, "_blank");
            });
        } catch (error) {
            errorDebugger('ListOfPublishedListings', 'redirectToListing', error, 'warn', 'Error in redirectToListing');
        }
    }
}