import { LightningElement, track, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
import { loadStyle } from 'lightning/platformResourceLoader';
import { errorDebugger } from 'c/globalProperties';

export default class ListingManagerTileViewCmp extends NavigationMixin(LightningElement) {
    @track listings = [];
    @track pageSize = 30;
    @track shownProcessedListingData = [];
    @track screenWidth = 0;
    @track currentPage = 1;
    @track visiblePages = 5;

    @api
    get pagesize() {
        return this.pageSize;
    }

    set pagesize(value) {
        this.pageSize = value;
    }

    /**
    * Method Name : totalPages
    * @description : set the totalpages count.
    * * Date: 20/08/2024
    * Created By:Vyom Soni
    */
    get totalItems() {
        return this.listings.length;
    }

    /**
    * Method Name : totalPages
    * @description : set the totalpages count.
    * * Date: 20/08/2024
    * Created By:Vyom Soni
    */
    get totalPages() {
        return Math.ceil(this.totalItems / this.pageSize);
    }

    /**
    * Method Name : pageNumbers
    * @description : set the list for page number in pagination.
    * * Date: 20/08/2024
    * Created By:Vyom Soni
    */
    get pageNumbers() {
        try {
            const totalPages = this.totalPages;
            const currentPage = this.currentPage;
            const visiblePages = this.visiblePages;

            let pages = [];

            if (totalPages <= visiblePages) {
                for (let i = 1; i <= totalPages; i++) {
                    pages.push({
                        number: i,
                        isEllipsis: false,
                        className: `pagination-button ${i === currentPage ? 'active' : ''}`
                    });
                }
            } else {
                pages.push({
                    number: 1,
                    isEllipsis: false,
                    className: `pagination-button ${currentPage === 1 ? 'active' : ''}`
                });
                if (currentPage > 3) {
                    pages.push({ isEllipsis: true });
                }
                let start = Math.max(2, currentPage - 1);
                let end = Math.min(currentPage + 1, totalPages - 1);
                for (let i = start; i <= end; i++) {
                    pages.push({
                        number: i,
                        isEllipsis: false,
                        className: `pagination-button ${i === currentPage ? 'active' : ''}`
                    });
                }
                if (currentPage < totalPages - 2) {
                    pages.push({ isEllipsis: true });
                }
                pages.push({
                    number: totalPages,
                    isEllipsis: false,
                    className: `pagination-button ${currentPage === totalPages ? 'active' : ''}`
                });
            }
            return pages;
        } catch (error) {
            errorDebugger('ListingManagerTileViewCmp', 'pageNumbers', error, 'warn', 'Error in pageNumbers');
            return null;
        }
    }

    /**
    * Method Name : showEllipsis
    * @description : show the elipsis when the total pages is gretaer then the visible pages.
    * * Date: 20/08/2024
    * Created By:Vyom Soni
    */
    get showEllipsis() {
        return Math.ceil(this.totalItems / this.pageSize) > this.visiblePages;
    }

    /**
    * Method Name : isFirstPage
    * @description : check the current page is first.
    * * Date: 20/08/2024
    * Created By:Vyom Soni
    */
    get isFirstPage() {
        return this.currentPage === 1;
    }

    /**
    * Method Name : isLastPage
    * @description : check the current page is last.
    * * Date: 20/08/2024
    * Created By:Vyom Soni
    */
    get isLastPage() {
        return this.currentPage === Math.ceil(this.totalItems / this.pageSize);
    }

    /**
    * Method Name : startIndex
    * @description : set the start Index.
    * * Date: 20/08/2024
    * Created By:Vyom Soni
    */
    get startIndex() {
        return (this.currentPage - 1) * this.pageSize + 1;
    }

    /**
    * Method Name : endIndex
    * @description : set the end Index.
    * * Date: 20/08/2024
    * Created By:Vyom Soni
    */
    get endIndex() {
        return Math.min(this.currentPage * this.pageSize, this.totalItems);
    }

    /**
    * Method Name : get listingsdata
    * @description : get the filtered listing data from listing manager component reactively
    * date:4/06/2024
    * Created By: Vyom Soni
    */
    @api
    get listingsdata() {
        return this.listings;
    }

    /**
    * Method Name : set listingsdata
    * @description : set the filtered listing data from listing manager component reactively
    * @param: value- data from the parent component
    * date:4/06/2024
    * Created By: Vyom Soni
    */
    set listingsdata(value) {
        try {
            if (value && Array.isArray(value)) {
                if (this.listings.length != value.length) {
                    this.currentPage = 1;
                }
                this.listings = value;
                this.updateShownData();
            } else {
                this.listings = [];
                this.currentPage = 1;
                this.shownProcessedListingData = [];
                this.updateShownData();
            }
        } catch (error) {
            errorDebugger('ListingManagerTileViewCmp', 'listingsdata', error, 'warn', 'Error in listingsdata');
        }
    }

    /**
    * Method Name : showSection
    * @description : handle error message when no listings is found in the filtering
    * date:4/06/2024
    * Created By: Vyom Soni
    */
    get showSection() {
        return this.shownProcessedListingData.length === 0;
    }

    /**
    * Method Name : connectedCallback
    * @description : update the pagination button and listings when component loads
    * date:4/06/2024
    * Created By: Vyom Soni
    */
    connectedCallback() {
        loadStyle(this, MulishFontCss);
        this.updateScreenWidth();
        if (!import.meta.env.SSR) {
            window?.globalThis?.addEventListener('resize', this.updateScreenWidth);
        }
        this.updateShownData();
    }

    /**
    * Method Name : disconnectedCallback
    * @description : remove the event listener
    * date:4/06/2024
    * Created By: Vyom Soni
    */
    disconnectedCallback() {
        if (!import.meta.env.SSR) {
            window?.globalThis?.removeEventListener('resize', this.updateScreenWidth);
        }
    }

    /**
    * Method Name : updateScreenWidth
    * @description : update the layout and width variabel
    * date:4/06/2024
    * Created By: Vyom Soni
    */
    updateScreenWidth = () => {
        try {
            this.screenWidth = window.innerWidth;
        } catch (error) {
            errorDebugger('ListingManagerTileViewCmp', 'updateScreenWidth', error, 'warn', 'Error in updateScreenWidth');
        }
    }

    /**
    * Method Name : setValueInParent
    * @description : set the listing value from the listing manager component
    * date:4/06/2024
    * Created By: Vyom Soni
    */
    setValueInParent() {
        const customEvent = new CustomEvent('valueselected', {
            detail: this.listings
        });
        if (!import.meta.env.SSR) {
            this.dispatchEvent(customEvent);
        }
    }

    /**
    * Method Name : checkBoxValueChange
    * @description : change the listing state when the checkboxs is updated
    * date:4/06/2024
    * Created By: Vyom Soni
    */
    checkBoxValueChange(event) {
        try {
            const checkboxId = Number(event.target.dataset.id);
            const isChecked = event.target.checked;

            this.shownProcessedListingData = this.shownProcessedListingData.map((item, index) => {
                if (index === checkboxId) {
                    return { ...item, isChecked: isChecked };
                }
                return item;
            });
            this.listings = this.listings.map(item1 => {
                const matchedItem = this.shownProcessedListingData.find(item2 => item1.Id === item2.Id);
                if (matchedItem) {
                    return { ...item1, isChecked: matchedItem.isChecked };
                }
                return item1;
            });

            this.setValueInParent();
        } catch (error) {
            errorDebugger('ListingManagerTileViewCmp', 'checkBoxValueChange', error, 'warn', 'Error in checkBoxValueChange');
        }
    }

    /**
    * Method Name :updateShownData
    * @description : update  the shown lisitng data when the pagination or filter is applied.
    * Created By: Vyom Soni
    * date:20/08/2024
    */
    updateShownData() {
        try {
            const startIndex = (this.currentPage - 1) * this.pageSize;
            const endIndex = Math.min(startIndex + this.pageSize, this.totalItems);
            this.shownProcessedListingData = this.listings.slice(startIndex, endIndex);
        } catch (error) {
            errorDebugger('ListingManagerTileViewCmp', 'updateShownData', error, 'warn', 'Error in updateShownData');
        }
    }

    /**
    * Method Name :handlePrevious
    * @description : handle the click on the previous button in the pagination
    * Created By: Vyom Soni
    * date:20/08/2024
    */
    handlePrevious() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.updateShownData();
            this.scrollToTop();
        }
    }

    /**
    * Method Name :handleNext
    * @description : handle the click on the next button in the pagination
    * Created By: Vyom Soni
    * date:20/08/2024
    */
    handleNext() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
            this.updateShownData();
            this.scrollToTop();
        }
    }

    /**
    * Method Name :handlePageChange
    * @description : handle the click on page numbers
    * Created By: Vyom Soni
    * date:20/08/2024
    */
    handlePageChange(event) {
        try {
            const selectedPage = parseInt(event.target.getAttribute('data-id'), 10);
            if (selectedPage !== this.currentPage) {
                this.currentPage = selectedPage;
                this.updateShownData();
                this.scrollToTop();
            }
        } catch (error) {
            errorDebugger('ListingManagerTileViewCmp', 'handlePageChange', error, 'warn', 'Error in handlePageChange');
        }
    }

    /**
    * Method Name : redirectToRecord
    * @description : use for the redirect the listing manager to record page of the property
    * date:4/06/2024
    * Created By: Vyom Soni
    */
    redirectToRecord(event) {
        try {
            event.preventDefault();
            const recordId = event.target.dataset.id;
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: recordId,
                    objectApiName: 'MVEX__Listing__c',
                    actionName: 'view'
                }
            })
        } catch (error) {
            errorDebugger('ListingManagerTileViewCmp', 'redirectToRecord', error, 'warn', 'Error in redirectToRecord');
        }
    }

    /**
    * Method Name :scrollToTop
    * @description : scroll to top in tile view
    * Created By: Vyom Soni
    * date:4/06/2024
    */
    scrollToTop() {
        try {
            const tableDiv = this.template.querySelector('.mainDiv');
            if (tableDiv) {
                tableDiv.scrollTop = 0;
            }
        } catch (error) {
            errorDebugger('ListingManagerTileViewCmp', 'scrollToTop', error, 'warn', 'Error in scrollToTop');
        }
    }

}