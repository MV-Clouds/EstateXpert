import { LightningElement, track, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
import { loadStyle } from 'lightning/platformResourceLoader';
export default class MarketingListTileView extends NavigationMixin(LightningElement) {
    @track contacts = [];
    @track isPrevDisabled = true;
    @track isNextDisabled = false;
    @track pageNumber = 1;
    @track pageSize = 30;
    @track shownProcessedContactData = [];
    @track screenWidth = 0;
    @track currentPage = 1;
    @track visiblePages = 5;
    // @track pageSize = 50;

    /**
    * Method Name : totalPages
    * @description : set the totalpages count.
    * * Date: 20/08/2024
    * Created By:Vyom Soni
    */
    get totalItems() {
        return this.contacts.length;
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
        const totalPages = this.totalPages;
        const currentPage = this.currentPage;
        const visiblePages = this.visiblePages;

        let pages = [];

        if (totalPages <= visiblePages) {
            // If the total pages are less than or equal to the visible pages, show all
            for (let i = 1; i <= totalPages; i++) {
                pages.push({
                    number: i,
                    isEllipsis: false,
                    className: `pagination-button ${i === currentPage ? 'active' : ''}`
                });
            }
        } else {
            // Always show the first page
            pages.push({
                number: 1,
                isEllipsis: false,
                className: `pagination-button ${currentPage === 1 ? 'active' : ''}`
            });

            if (currentPage > 3) {
                // Show ellipsis if the current page is greater than 3
                pages.push({ isEllipsis: true });
            }

            // Show the middle pages
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
                // Show ellipsis if the current page is less than totalPages - 2
                pages.push({ isEllipsis: true });
            }

            // Always show the last page
            pages.push({
                number: totalPages,
                isEllipsis: false,
                className: `pagination-button ${currentPage === totalPages ? 'active' : ''}`
            });
        }
        return pages;
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
   * Method Name : get contactsdata
   * @description : get the filtered contact data from MarketinglistCmp component reactively
   * date:24/06/2024
   * Created By: Vyom Soni
   */
    @api
    get contactsdata() {
        return this.contacts;
    }

    /**
     * Method Name : set contactsdata
     * @description : set the filtered contact data from contact manager component reactively
     * @param: value- data from the parent component
     * date:24/06/2024
     * Created By: Vyom Soni
    */
    set contactsdata(value) {
        try {
            if (value && Array.isArray(value)) {
                if (this.contacts.length !== value.length) {
                    this.currentPage = 1;
                }
                this.contacts = value.map(item => ({ ...item, isChecked: item.isChecked || false }));
                console.log('contact ->' + JSON.stringify(this.contacts));
                this.updateShownData();
            } else {
                this.contacts = [];
                this.currentPage = 1;
                this.shownProcessedContactData = [];
                this.updateShownData();
            }
        } catch (error) {
            console.log('Error contactsdata->' + error);
        }
    }

    @api
    get pagesize() {
        return this.pageSize;
    }

    set pagesize(value) {
        this.pageSize = value;
    }

    /**
    * Method Name : showSection
    * @description : handle error message when no contacts is found in the filtering
    * date:24/06/2024
    * Created By: Vyom Soni
    */
    get showSection() {
        return this.shownProcessedContactData.length === 0;
    }

    /**
    * Method Name : connectedCallback
    * @description : update the pagination button and contacts when component loads
    * date:24/06/2024
    * Created By: Vyom Soni
    */
    connectedCallback() {
        // this.totalPages = Math.ceil(this.contacts.length / this.pageSize);
        // if(this.totalPages == 0){
        //     this.totalPages = 1;
        // }
        // this.updateProcessedContactData();
        // this.updatePaginationButtons();
        loadStyle(this, MulishFontCss)
            .then(() => {
                console.log('Styles loaded successfully');
            })
            .catch(error => {
                console.error('Error loading styles', error);
            });
        this.screenWidth = window?.globalThis?.innerWidth;
        window?.globalThis?.addEventListener('resize', this.handleResize);
        this.updateShownData();
    }

    /**
   * Method Name : disconnectedCallback
   * @description : remove the event listener
   * date:4/06/2024
   * Created By: Vyom Soni
   */
    disconnectedCallback() {
        window?.globalThis?.removeEventListener('resize', this.handleResize);
    }

    /**
    * Method Name : handleResize
    * @description : call the update width method
    * date:4/06/2024
    * Created By: Vyom Soni
    */
    handleResize = () => {
        this.screenWidth = window?.globalThis?.innerWidth;
    }

    /**
    * Method Name : setValueInParent
    * @description : set the contact value from the contact manager component
    * date:24/06/2024
    * Created By: Vyom Soni
    */
    setValueInParent() {
        try {
            // Create a custom event with the value you want to pass to the parent
            const customEvent = new CustomEvent('valueselected', {
                detail: this.contacts
            });
            // Dispatch the custom event
            if (!import.meta.env.SSR) {
                this.dispatchEvent(customEvent);
            }
        } catch (error) {
            console.log('Error setValueInParent->' + error);
        }
    }

    /**
    * Method Name : checkBoxValueChange
    * @description : change the contact state when the checkboxs is updated
    * date:24/06/2024
    * Created By: Vyom Soni
    */
    checkBoxValueChange(event) {
        try {
            const checkboxId = Number(event.target.dataset.id);
            const isChecked = event.target.checked;
            const contactId = this.shownProcessedContactData[checkboxId].Id;
            this.shownProcessedContactData = this.shownProcessedContactData.map((contact, index) =>
                index === checkboxId ? { ...contact, isChecked } : contact
            );

            // Update the contacts array to reflect the change
            this.contacts = this.contacts.map(contact =>
                contact.Id === contactId ? { ...contact, isChecked } : contact
            );

            this.setValueInParent();
        } catch (e) {
            console.error('Error checkBoxValueChange:', e.stack);
        }
    }

    /**
   * Method Name : redirectToRecord
   * @description : use for the redirect the contact manager to record page of the property
   * date:24/06/2024
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
                    objectApiName: 'Contact',
                    actionName: 'view'
                }
            })
        } catch (error) {
            console.log('Error redirectToRecord ->' + error);
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
            this.shownProcessedContactData = [...this.contacts.slice(startIndex, endIndex)];
        } catch (error) {
            console.log('Error updateShownData ->' + error);
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
        const selectedPage = parseInt(event.target.getAttribute('data-id'), 10);
        if (selectedPage !== this.currentPage) {
            this.currentPage = selectedPage;
            this.updateShownData();
            this.scrollToTop();
        }
    }

    /**
    * Method Name :scrollToTop
    * @description : scroll to top in tile view
    * Created By: Vyom Soni
    * date:24/06/2024
    */
    scrollToTop() {
        const tableDiv = this.template.querySelector('.mainDiv');
        if (tableDiv) {
            tableDiv.scrollTop = 0;
        }
    }

}