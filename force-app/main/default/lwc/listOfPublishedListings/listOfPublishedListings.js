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
    @track sortField = 'name';
    @track sortOrder = 'asc';

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

    /**
    * Method Name: sortClick
    * @description: Method to handle sort header click and apply sorting
    * Created Date: 06/04/2026
    * Created By: Kajal Tiwari
    */
    sortClick(event) {
        try {
            const fieldName = event.currentTarget.dataset.id;
            
            // Toggle sort order if clicking same field, otherwise set to ascending
            if (this.sortField === fieldName) {
                this.sortOrder = this.sortOrder === 'asc' ? 'desc' : 'asc';
            } else {
                this.sortField = fieldName;
                this.sortOrder = 'asc';
            }
            
            this.sortData();
            this.updateSortIcons();
        } catch (error) {
            errorDebugger('ListOfPublishedListings', 'sortClick', error, 'warn', 'Error in sortClick');
        }
    }

    /**
    * Method Name: sortData
    * @description: Method to sort the listings data based on current sort field and order
    * Created Date: 06/04/2026
    * Created By: Kajal Tiwari
    */
    sortData() {
        try {
            if (!this.listingsDatas || this.listingsDatas.length === 0) {
                return;
            }

            let sortedData = [...this.listingsDatas];
            
            sortedData.sort((a, b) => {
                let aValue = a[this.sortField];
                let bValue = b[this.sortField];

                // Handle null/undefined values
                if (aValue == null) aValue = '';
                if (bValue == null) bValue = '';

                // Convert to lowercase for string comparison
                if (typeof aValue === 'string') aValue = aValue.toLowerCase();
                if (typeof bValue === 'string') bValue = bValue.toLowerCase();

                let comparison = 0;
                if (aValue < bValue) {
                    comparison = -1;
                } else if (aValue > bValue) {
                    comparison = 1;
                }

                return this.sortOrder === 'asc' ? comparison : -comparison;
            });

            this.listingsDatas = sortedData;
        } catch (error) {
            errorDebugger('ListOfPublishedListings', 'sortData', error, 'warn', 'Error in sortData');
        }
    }

    /**
    * Method Name: updateSortIcons
    * @description: Update the sort icons to show current sort state
    * Created Date: 06/04/2026
    * Created By: Kajal Tiwari
    */
    updateSortIcons() {
        try {
            const headers = this.template.querySelectorAll('.sorting_header');
            
            headers.forEach(header => {
                const headerFieldName = header.dataset.id;
                const icon = header.querySelector('.listing-manager-icon');
                
                if (headerFieldName === this.sortField) {
                    // Active sort header
                    header.classList.add('active-sort');
                    if (icon) {
                        if (this.sortOrder === 'desc') {
                            icon.classList.remove('rotate-asc');
                            icon.classList.add('rotate-desc');
                        } else {
                            icon.classList.remove('rotate-desc');
                            icon.classList.add('rotate-asc');
                        }
                    }
                } else {
                    // Inactive sort header
                    header.classList.remove('active-sort');
                    if (icon) {
                        icon.classList.remove('rotate-asc', 'rotate-desc');
                    }
                }
            });
        } catch (error) {
            errorDebugger('ListOfPublishedListings', 'updateSortIcons', error, 'warn', 'Error in updateSortIcons');
        }
    }
}