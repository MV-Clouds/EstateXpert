/*
*Method Name: displayCampaigns
* @description: lwc to display component
* Date: 23/06/2024
* Created By: Rachit Shah
*/
import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import deleteCampaign from '@salesforce/apex/EmailCampaignController.deleteCampaign';
import getCampaigns from '@salesforce/apex/EmailCampaignController.getCampaigns';
import getMetadataRecords from '@salesforce/apex/ControlCenterController.getMetadataRecords';
import { loadStyle } from 'lightning/platformResourceLoader';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';

export default class DisplayCampaigns extends NavigationMixin(LightningElement) {
    @track campaigns = [];
    @track filteredCampaigns = [];
    @track visibleCampaigns = [];
    @track isLoading = false;
    @track isModalOpen = false;
    @track currentRecId = '';
    @track currentPage = 1;
    @track isFilterModalOpen = false;
    @track statusFilter = '';
    @track statusFilterList = [];
    @track createdDateStart = '';
    @track createdDateEnd = '';
    @track screenWidth = 0;
    @track visiblePages = 5;
    @track pageSize = 20;
    @track pageNumber = 1;
    @track isAccessible = false;

    @track statusOptions = [
        {label: 'None' , value: ''},
        { label: 'Pending', value: 'Pending' },
        { label: 'In Progress', value: 'In Progress' },
        { label: 'Completed', value: 'Completed' },
    ];

     /**
    * Method Name : totalItems
    * @description : set the totalItems count.
    * * Date: 20/08/2024
    * Created By:Vyom Soni
    */
     get totalItems() {
        return this.filteredCampaigns.length;
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
    * Method Name : pageNumbers
    * @description : set the list for page number in pagination.
    * * Date: 20/08/2024
    * Created By:Vyom Soni
    */
    get pageNumbers() {
        try{
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
        }catch(error){
            return null;
        }
    }

    /*
    * Method Name: connectedCallback
    * @description: Method to load all the data initially
    * Date: 23/06/2024
    * Created By: Rachit Shah
    */
    connectedCallback() {
        Promise.all([
            loadStyle(this, MulishFontCss)
        ])
        .then(() => {
            console.log('External Css Loaded');
        })
        .catch(() => {
            this.showToast('Error', 'Error loading external CSS', 'error');
        });
        this.getAccessible();
    }

    /*
    * Method Name: getAccessible
    * @description: Method to check if user has access to Marketing Campaign feature
    * Date: 03/02/2026
    * Created By: Karan Singh
    */
    getAccessible() {
        getMetadataRecords()
        .then(data => {
            const marketingCampaignFeature = data.find(
                item => item.DeveloperName === 'Marketing_Campaign'
            );
            this.isAccessible = marketingCampaignFeature ? Boolean(marketingCampaignFeature.MVEX__isAvailable__c) : false;
            if (this.isAccessible) {
                this.loadCampaigns();
            } else {
                this.isLoading = false;
            }
        })
        .catch(error => {
            console.error('Error fetching accessible fields', error);
            this.isAccessible = false;
            this.isLoading = false;
        });
    }

    /*
    * Method Name: loadCampaigns
    * @description: Method to load data from apex and sort it based on date
    * Date: 23/06/2024
    * Created By: Rachit Shah
    */
    loadCampaigns() {
        this.isLoading = true;
        getCampaigns()
            .then(result => {
                // result.sort((a, b) => new Date(b.CreatedDate) - new Date(a.CreatedDate));
                this.processTemplates(result);
                this.updateShownData();
                this.isLoading = false;
            })
            .catch(error => {
                console.error('Error:', error);
                this.isLoading = false;
            });
    }

    /*
    * Method Name: processTemplates
    * @description: Method to add custom column in the value
    * Date: 23/06/2024
    * Created By: Rachit Shah
    */
    processTemplates(data) {
        this.campaigns = data.map((campaign, index) => {
            const total = campaign.MVEX__Total_Emails__c - campaign.MVEX__Failed_Emails__c;
            const remaining = campaign.MVEX__Remaining_Emails__c;
            const completed = total - remaining;
            const progressPercentage = total > 0 ? `${(completed / total) * 100}` : '0';
    
            return {
                ...campaign,
                rowIndex: index + 1,
                StartDateformatted: campaign.MVEX__Schedule_Type__c === 'Specific Date' ? this.formatDate(campaign.MVEX__Campaign_Start_Date__c) : this.formatDate(campaign.CreatedDate),
                CreatedDateformatted: this.formatDate(campaign.CreatedDate),
                statusClass: this.getStatusClass(campaign.MVEX__Status__c),
                canDelete: campaign.MVEX__Status__c === 'Pending' || campaign.MVEX__Status__c === 'Failed' ? false : true,
                canEdit : campaign.MVEX__Status__c === 'Pending' || campaign.MVEX__Status__c === 'In Progress' ? false : true, 
                IsCampaignTemplate: campaign.MVEX__Is_Marketing_Campaign_Template__c ? 'Yes' : 'No',
                progressPercentage: progressPercentage,
            };
        });

        this.filteredCampaigns = this.campaigns;
    }

    /*
    * Method Name: getStatusClass
    * @description: Method to give dynamic class to the status
    * Date: 23/06/2024
    * Created By: Rachit Shah
    */
    getStatusClass(status) {
        switch (status) {
            case 'Pending':
                return 'pending-class';
            case 'In Progress':
                return 'in-progress-class';
            case 'Completed':
                return 'completed-class';
            case 'Failed':
                return 'failed-class';
            default:
                return '';
        }
    }

    /**
    * Method Name : updateShownData
    * @description : update the shownProcessedLisitingData when pagination is applied.
    * date: 20/08/2024
    * Created By:Vyom Soni
    */
    updateShownData() {
        try{
        const startIndex = (this.currentPage - 1) * this.pageSize;
        const endIndex = Math.min(startIndex + this.pageSize, this.totalItems);
        this.visibleCampaigns = this.filteredCampaigns.slice(startIndex, endIndex);
        }catch(error){
            console.log('Error updateShownData->'+error);
        }
    }

    /**
    * Method Name : handlePrevious
    * @description : handle the previous button click in the pagination.
    * date: 20/08/2024
    * Created By:Vyom Soni
    */
    handlePrevious() {
       if (this.currentPage > 1) {
            this.currentPage--;
            this.updateShownData();
        }
    }

    /**
    * Method Name : handleNext
    * @description : handle the next button click in the pagination.
    * date: 20/08/2024
    * Created By:Vyom Soni
    */
    handleNext() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
            this.updateShownData();
        }
    }
 
    /**
    * Method Name : handlePageChange
    * @description : handle the direct click on page number.
    * date: 20/08/2024
    * Created By:Vyom Soni
    */
    handlePageChange(event) {
        const selectedPage = parseInt(event.target.getAttribute('data-id'), 10);
        if (selectedPage !== this.currentPage) {
            this.currentPage = selectedPage;
            this.updateShownData();
        }
    }

    
    /*
    * Method Name: formatDate
    * @description: Method to customize date string
    * Date: 23/06/2024
    * Created By: Rachit Shah
    */
    formatDate(dateStr) {
        let formatdate = new Date(dateStr);
        formatdate.setDate(formatdate.getDate());
        let formattedDate = new Date(formatdate.getFullYear(), formatdate.getMonth(), formatdate.getDate(), 0, 0, 0);
        const day = formattedDate.getDate();
        const month = formattedDate.getMonth() + 1; // Month is zero-based, so we add 1
        const year = formattedDate.getFullYear();
        const paddedDay = day < 10 ? `0${day}` : day;
        const paddedMonth = month < 10 ? `0${month}` : month;
        const formattedDateStr = `${paddedDay}/${paddedMonth}/${year}`;
        return formattedDateStr;
    }

    /*
    * Method Name: handleSearch
    * @description: Method to search record based on the name
    * Date: 23/06/2024
    * Created By: Rachit Shah
    */
    handleSearch(event) {
        const searchKey = event.target.value.toLowerCase();
        this.filteredCampaigns = this.campaigns.filter(campaign => 
            campaign.MVEX__Label__c.toLowerCase().includes(searchKey)
        );
        this.currentPage = 1;
        this.updateShownData();
        this.statusFilterList = [];
        this.statusFilter = '';
        this.createdDateStart = '';
        this.createdDateEnd = '';
    }
    
    /*
    * Method Name: handleAdd
    * @description: Method to open popup to create camapaign
    * Date: 23/06/2024
    * Created By: Rachit Shah
    */
    handleAdd() {
        this.isModalOpen = true;
    }

    /*
    * Method Name: handleEdit
    * @description: Method to pass data and redirect to component
    * Date: 23/06/2024
    * Created By: Rachit Shah
    */
    handleEdit(event) {
        try{
            this.currentRecId = event.currentTarget.dataset.id;

            const navigationState = {
                campaign : this.currentRecId
            };

            const serializedState = JSON.stringify(navigationState);

            let cmpDef;                
            cmpDef = {
                componentDef: 'MVEX:emailCampaignTemplateForm',
                attributes: {                    
                        c__navigationState: serializedState,
                        c__recordId : this.currentRecId
                    }                
                };

            let encodedDef = btoa(JSON.stringify(cmpDef));
                this[NavigationMixin.Navigate]({
                type: "standard__webPage",
                attributes: {
                    url:  "/one/one.app#" + encodedDef                                                         
                }
            });
        }
        catch(e){
            console.log('error in handleEdit - ', e.stack);
            this.showToast('Error', 'Error while redirecting to edit campaign', 'error');
            
        }
    }

    /*
    * Method Name: handleDelete
    * @description: Method to delete record and update page
    * Date: 23/06/2024
    * Created By: Rachit Shah
    */
    handleDelete(event) {
        this.currentRecId = event.currentTarget.dataset.id;
        this.showMessagePopup('Warning','Delete Campaign','Are you sure you want to delete this campaign? This action cannot be undone.');
    }

    /*
    * Method Name: handleModalClose
    * @description: Method to close modal
    * Date: 23/06/2024
    * Created By: Rachit Shah
    */
    handleModalClose() {
        this.isModalOpen = false;
    }

    /*
    * Method Name: handleFilterClick
    * @description: Method to open filter modal
    * Date: 23/06/2024
    * Created By: Rachit Shah
    */
    handleFilterClick() {
        this.isFilterModalOpen = true;
    }

    /*
    * Method Name: clearFilterModal
    * @description: Method to clear filter modal
    * Date: 23/06/2024
    * Created By: Rachit Shah
    */
    clearFilterModal() {
        this.isFilterModalOpen = false;
        this.statusFilterList = [];
        this.statusFilter = '';
        this.createdDateStart = '';
        this.createdDateEnd = '';
        this.filteredCampaigns = this.campaigns;
        this.currentPage = 1;
        this.updateShownData();
    }

    /*
    * Method Name: closeFilterModal
    * @description: Method to close modal
    * Date: 23/06/2024
    * Created By: Rachit Shah
    */
    closeFilterModal(){
        this.isFilterModalOpen = false;
    }

    /*
    * Method Name: handleFilterChange
    * @description: Method to  handle changes in filter
    * Date: 23/06/2024
    * Created By: Rachit Shah
    */
    handleFilterChange(event) {
        try {
            const filterId = event.target.dataset.id;
            if (filterId === 'statusFilter') {
                this.statusFilter = event.target.value;

                if(!this.statusFilterList.includes(this.statusFilter) && this.statusFilter !== ''){
                    this.statusFilterList.push(this.statusFilter);
                }
    
            } else if (filterId === 'createdDateStart') {
                this.createdDateStart = event.target.value;
            } else if (filterId === 'createdDateEnd') {
                this.createdDateEnd = event.target.value;
            }
        } catch (error) {
            this.showToast('Error', 'Error while applying filter', 'error');
        }

    }

    /*
    * Method Name: handleRemove
    * @description: Method to remove filter status
    * Date: 23/06/2024
    * Created By: Rachit Shah
    */
    handleRemove(event){
        const valueRemoved = event.target.name;

        if(this.statusFilter === valueRemoved){
            this.statusFilter = '';
        }
        
        const index = this.statusFilterList.indexOf(valueRemoved);
        if (index > -1) {
            this.statusFilterList.splice(index, 1);
        }
    }
    
    /*
    * Method Name: applyFilter
    * @description: Method to apply filter
    * Date: 23/06/2024
    * Created By: Rachit Shah
    */
    applyFilter() {
        
        if (this.createdDateStart && this.createdDateEnd) {
            const startDate = new Date(this.createdDateStart);
            const endDate = new Date(this.createdDateEnd);
    
            if (endDate < startDate) {
                this.showToast('Error', 'End Date should be the same or later than Start Date.', 'error');
                return;
            }
        }

        this.filteredCampaigns = this.campaigns.filter(campaign => {
            const createdDate = new Date(campaign.CreatedDate);
            const startDate = this.createdDateStart ? new Date(this.createdDateStart) : null;
            const endDate = this.createdDateEnd ? new Date(this.createdDateEnd) : null;

            if (startDate) {
                startDate.setHours(0, 0, 0, 0);
            }
            if (endDate) {
                endDate.setHours(23, 59, 59, 999);
            }    

            const isStatusMatch = this.statusFilterList.length === 0 || this.statusFilterList.includes(campaign.MVEX__Status__c);
            const isDateMatch = (!startDate || createdDate >= startDate) && (!endDate || createdDate <= endDate);
    
            return isStatusMatch && isDateMatch;
    
        });
        this.currentPage = 1;
        this.isFilterModalOpen = false;
        this.updateShownData();
        this.clearSearchInput();
    }


    /*
    * Method Name: showToast
    * @description: Method to show toast message
    * Date: 23/06/2024
    * Created By: Rachit Shah
    */
    showToast(title, message, variant) {
        if (typeof window !== 'undefined') {
            const event = new ShowToastEvent({
                title: title,
                message: message,
                variant: variant,
            });
            this.dispatchEvent(event);
        }
    }

    /*
    * Method Name: backToControlCenter
    * @description: Method to go back in the control center
    * Date: 23/06/2024
    * Created By: Rachit Shah
    */
    backToControlCenter(event) {
        try {
            event.preventDefault();
            this[NavigationMixin.Navigate]({
                type: "standard__navItemPage",
                attributes: {
                    apiName: "MVEX__Control_Center",
                },
            });
        } catch (error) {
            console.log('error--> ',error);
        }
    }

    clearSearchInput() {
        const searchInput = this.template.querySelector('.input-campaign');
        if (searchInput) {
            searchInput.value = ''; // Clear the input value
        }
    }

    refreshTable() {
        this.loadCampaigns();
    }

    redirectToCampaign(event) {
        try {
            const campaignId = event.target.dataset.id;
            this[NavigationMixin.GenerateUrl]({
                type: "standard__recordPage",
                attributes: {
                    recordId: campaignId,
                    objectApiName: 'MVEX__Marketing_Campaign__c',
                    actionName: 'view'
                }
            }).then(url => {
                window?.globalThis?.open(url, "_blank");
            });
        } catch (error) {
            console.log('error in redirectToListing - ', error.stack);
        }
    }

    openMemberModal(event){
        try{
            const campaignId = event.currentTarget.dataset.id;
            let cmpDef;                
            cmpDef = {
                componentDef: 'MVEX:campaignMembersTable',
                attributes: {                    
                    campaignId: campaignId
                }                
            };
    
            let encodedDef = btoa(JSON.stringify(cmpDef));
                this[NavigationMixin.Navigate]({
                type: "standard__webPage",
                attributes: {
                    url:  "/one/one.app#" + encodedDef                                                         
                }
            });
        }catch(e){
            console.log('error in openMemberModal - ', e.stack);
            // this.showToast('Error', 'Error while redirecting to campaign members '+e.stack, 'error');
            
        }
    }

    showMessagePopup(Status, Title, Message) {
        const messageContainer = this.template.querySelector('c-message-popup')
        if (messageContainer) {
            messageContainer.showMessagePopup({
                status: Status,
                title: Title,
                message: Message,
            });
        }
    }

    handleConfirmation(event) {
        if(event.detail === true){
            this.isLoading = true;
            let campaignId = this.currentRecId;
            deleteCampaign({ campaignId })
                .then(() => {
                    this.campaigns = this.campaigns.filter(campaign => campaign.Id != campaignId);
                    this.filteredCampaigns = this.filteredCampaigns.filter(campaign => campaign.Id !==campaignId);
                    this.updateShownData();
                    this.showToast('Success', 'Campaign deleted successfully', 'success');
                })
                .catch(error => {
                    this.showToast('Error', error.body.message, 'error');
                }).finally(() => {
                    this.currentRecId = '';
                    this.isLoading = false;
                });
        } else {
            this.currentRecId = '';
        }
    }

}