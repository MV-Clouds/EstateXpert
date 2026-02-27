import { LightningElement, track, api } from 'lwc';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
import { loadStyle } from 'lightning/platformResourceLoader';
import { errorDebugger } from 'c/globalProperties';

export default class ListingManagerMapviewCmp extends LightningElement {
    @track listings = [];
    @track data = [];
    @track mapMarkers = [];
    @track mapMarkers1 = [];
    @track mapMarkers2 = [];
    @track pageSize = 30;
    @track currentPage = 1;
    @track visiblePages = 5;

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
        if (value && Array.isArray(value)) {
            if (this.listings.length != value.length) {
                this.currentPage = 1;
            }
            this.listings = value;
            this.loadPropertyData(this.listings);
        } else {
            this.listings = [];
            this.currentPage = 1;
        }
    }

    /**
    * Method Name : connectedCallback
    * @description : load selected listing data in map-markers list.
    * date:5/06/2024
    * Created By: Vyom Soni
    */
    connectedCallback() {
        loadStyle(this, MulishFontCss);
        if (this.listings != null) {
            this.loadPropertyData(this.listings);
        }
    }

    /**
    * Method Name : totalItems
    * @description : get the total number of listings
    * date:26/02/2026
    * Created By: Karan Singh
    */
    get totalItems() {
        return this.listings.length;
    }

    /**
    * Method Name : totalPages
    * @description : get the total number of pages
    * date:26/02/2026
    * Created By: Karan Singh
    */
    get totalPages() {
        return Math.ceil(this.totalItems / this.pageSize);
    }

    /**
    * Method Name : pageNumbers
    * @description : get the page numbers for pagination display
    * date:26/02/2026
    * Created By: Karan Singh
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
            errorDebugger('ListingManagerMapviewCmp', 'pageNumbers', error, 'warn', 'Error in pageNumbers');
            return [];
        }
    }

    /**
    * Method Name : isFirstPage
    * @description : check if current page is first page
    * date:26/02/2026
    * Created By: Karan Singh
    */
    get isFirstPage() {
        return this.currentPage === 1;
    }

    /**
    * Method Name : isLastPage
    * @description : check if current page is last page
    * date:26/02/2026
    * Created By: Karan Singh
    */
    get isLastPage() {
        return this.currentPage === this.totalPages;
    }

    /**
    * Method Name : handlePrevious
    * @description : handle previous page button click
    * date:26/02/2026
    * Created By: Karan Singh
    */
    handlePrevious() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.loadPropertyData(this.listings);
        }
    }

    /**
    * Method Name : handleNext
    * @description : handle next page button click
    * date:26/02/2026
    * Created By: Karan Singh
    */
    handleNext() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
            this.loadPropertyData(this.listings);
        }
    }

    /**
    * Method Name : handlePageChange
    * @description : handle page number button click
    * date:26/02/2026
    * Created By: Karan Singh
    */
    handlePageChange(event) {
        try {
            const selectedPage = parseInt(event.target.getAttribute('data-id'), 10);
            if (selectedPage !== this.currentPage) {
                this.currentPage = selectedPage;
                this.loadPropertyData(this.listings);
            }
        } catch (error) {
            errorDebugger('ListingManagerMapviewCmp', 'handlePageChange', error, 'warn', 'Error in handlePageChange');
        }
    }

    /**
    * Method Name : loadPropertyData
    * @description : load the marker from the selected properties.
    * @param: data- properties data.
    * date:5/06/2024
    * Created By: Vyom Soni
    */
    loadPropertyData(data) {
        try {
            if (data) {
                // Calculate pagination
                const startIndex = (this.currentPage - 1) * this.pageSize;
                const endIndex = Math.min(startIndex + this.pageSize, data.length);
                const paginatedData = data.slice(startIndex, endIndex);
                
                this.data = paginatedData;
                this.mapMarkers = [];
                this.mapMarkers1 = [];
                this.mapMarkers2 = [];
                this.data.forEach(record => {
                    this.mapMarkers1.push({
                        id: record.Id
                    });
                    this.mapMarkers2.push({
                        location: {
                            id: record.Id,
                            rooms: record.MVEX__Number_of_Bedrooms__c,
                            City: record.MVEX__Listing_Address__City__s,
                            Country: record.MVEX__Listing_Address__CountryCode__s,
                            PostalCode: record.MVEX__Listing_Address__PostalCode__s,
                            State: record.MVEX__Listing_Address__StateCode__s,
                            Street: record.MVEX__Listing_Address__Street__s
                        },
                        title: record.Name,
                        description: `
                        
                        <b>Listing Type:-</b>
                        ${record.MVEX__Listing_Type__c ? record.MVEX__Listing_Type__c : ''}
                        <br><b>Property Type:-</b> 
                        ${record.MVEX__Property_Type__c ? record.MVEX__Property_Type__c : ''}
                        <br><b>Property Category:-</b>
                        ${record.MVEX__Property_Category__c ? record.MVEX__Property_Category__c : ''}
                        <br><b>Address:-</b></br>
                        ${record.MVEX__Listing_Address__Street__s ? record.MVEX__Listing_Address__Street__s + ',' : ''} 
                        ${record.MVEX__Listing_Address__City__s ? record.MVEX__Listing_Address__City__s + ',' : ''}
                        ${record.MVEX__Listing_Address__StateCode__s ? record.MVEX__Listing_Address__StateCode__s + ',' : ''}
                        ${record.MVEX__Listing_Address__CountryCode__s ? record.MVEX__Listing_Address__CountryCode__s + ',' : ''} 

                    `
                    });
                });
                this.mapMarkers = [...this.mapMarkers2];
            }
        } catch (error) {
            errorDebugger('ListingManagerMapviewCmp', 'loadPropertyData', error, 'warn', 'Error in loadPropertyData');
        }
    }
}