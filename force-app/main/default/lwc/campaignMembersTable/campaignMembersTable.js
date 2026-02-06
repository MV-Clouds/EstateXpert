import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getCampaignMemberEmails from '@salesforce/apex/EmailCampaignController.getCampaignMemberEmails';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
import { loadStyle } from 'lightning/platformResourceLoader';

export default class CampaignMembersTable extends NavigationMixin(LightningElement) {
    @api campaignId; // Public property to receive the campaign ID
    @track memberEmails = [];
    @track filteredMembers = [];
    @track visibleMembers = [];
    @track isLoading = false;
    @track isFilterModalOpen = false;
    @track statusFilter = '';
    @track statusFilterList = [];
    @track sendTimeStart = '';
    @track sendTimeEnd = '';
    @track currentPage = 1;
    @track pageSize = 20;
    @track visiblePages = 5;
    searchInput = '';

    @track statusOptions = [
        { label: 'None', value: '' },
        { label: 'Pending', value: 'Pending' },
        { label: 'Success', value: 'Success' },
        { label: 'Failed', value: 'Failed' }
    ];

    get totalItems() {
        return this.filteredMembers.length;
    }

    get totalPages() {
        return Math.ceil(this.totalItems / this.pageSize);
    }

    get showEllipsis() {
        return this.totalPages > this.visiblePages;
    }

    get isFirstPage() {
        return this.currentPage === 1;
    }

    get isLastPage() {
        return this.currentPage === this.totalPages;
    }

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
            console.log('Error pageNumbers->' + error);
            return null;
        }
    }

    connectedCallback() {

        Promise.all([
            loadStyle(this, MulishFontCss)
        ])
        .then(() => {
            console.log('External Css Loaded');
        })
        .catch(error => {
            console.log('Error occuring during loading external css', error);
        });

        if (!this.campaignId) {
            this.showToast('Error', 'Campaign ID is not provided.', 'error');
            return;
        }
        this.fetchMemberEmails();
    }

    fetchMemberEmails() {
        this.isLoading = true;
        getCampaignMemberEmails({ campaignId: this.campaignId })
            .then(result => {
                this.memberEmails = result.map((email, index) => ({
                    ...email,
                    rowIndex: index + 1,
                    statusClass: this.getStatusClass(email.status),
                    sendTimeFormatted: this.formatDate(email.sendTime)
                }));
                console.log('Member Emails:', this.memberEmails);
                this.filteredMembers = this.memberEmails;
                this.updateShownData();
                this.isLoading = false;
            })
            .catch(error => {
                this.isLoading = false;
                this.showToast('Error', 'Failed to load campaign members: ' + error.body.message, 'error');
            });
    }

    getStatusClass(status) {
        status = status.split(' ')[0];
        switch (status) {
            case 'Pending':
                return 'pending-class';
            case 'Success':
                return 'completed-class';
            case 'Failed':
                return 'failed-class';
            default:
                return '';
        }
    }

    formatDate(dateStr) {
        if (!dateStr) return '';
        const date = new Date(dateStr);
        const day = date.getDate().toString().padStart(2, '0');
        const month = (date.getMonth() + 1).toString().padStart(2, '0');
        const year = date.getFullYear();
        return `${day}/${month}/${year}`;
    }

    updateShownData() {
        try {
            const startIndex = (this.currentPage - 1) * this.pageSize;
            const endIndex = Math.min(startIndex + this.pageSize, this.totalItems);
            this.visibleMembers = this.filteredMembers.slice(startIndex, endIndex);
        } catch (error) {
            console.log('Error updateShownData->' + error);
        }
    }

    handlePrevious() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.updateShownData();
        }
    }

    handleNext() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
            this.updateShownData();
        }
    }

    handlePageChange(event) {
        const selectedPage = parseInt(event.target.getAttribute('data-id'), 10);
        if (selectedPage !== this.currentPage) {
            this.currentPage = selectedPage;
            this.updateShownData();
        }
    }

    handleSearch(event) {
        const searchKey = event.target.value.toLowerCase();
        this.searchInput = searchKey;
        this.filteredMembers = this.memberEmails.filter(member => 
            (member.contactName && member.contactName.toLowerCase().includes(searchKey)) ||
            (member.contactEmail && member.contactEmail.toLowerCase().includes(searchKey)) ||
            (member.emailName && member.emailName.toLowerCase().includes(searchKey))
        );
        this.currentPage = 1;
        this.statusFilterList = [];
        this.statusFilter = '';
        this.sendTimeStart = '';
        this.sendTimeEnd = '';
        this.updateShownData();

    }

    handleFilterClick() {
        this.isFilterModalOpen = true;
    }

    clearFilterModal() {
        this.isFilterModalOpen = false;
        this.statusFilterList = [];
        this.statusFilter = '';
        this.sendTimeStart = '';
        this.sendTimeEnd = '';
        this.filteredMembers = this.memberEmails;
        this.currentPage = 1;
        this.updateShownData();
    }

    closeFilterModal() {
        this.isFilterModalOpen = false;
    }

    handleFilterChange(event) {
        try {
            const filterId = event.target.dataset.id;
            if (filterId === 'statusFilter') {
                this.statusFilter = event.target.value;
                if (!this.statusFilterList.includes(this.statusFilter) && this.statusFilter !== '') {
                    this.statusFilterList.push(this.statusFilter);
                }
            } else if (filterId === 'sendTimeStart') {
                this.sendTimeStart = event.target.value;
            } else if (filterId === 'sendTimeEnd') {
                this.sendTimeEnd = event.target.value;
            }
        } catch (error) {
            console.log('error ==> ', error);
        }
    }

    handleRemove(event) {
        const valueRemoved = event.target.name;
        if (this.statusFilter === valueRemoved) {
            this.statusFilter = '';
        }
        const index = this.statusFilterList.indexOf(valueRemoved);
        if (index > -1) {
            this.statusFilterList.splice(index, 1);
        }
    }

    applyFilter() {
        if (this.sendTimeStart && this.sendTimeEnd) {
            const startDate = new Date(this.sendTimeStart);
            const endDate = new Date(this.sendTimeEnd);
            if (endDate < startDate) {
                this.showToast('Error', 'End Date should be the same or later than Start Date.', 'error');
                return;
            }
        }

        this.filteredMembers = this.memberEmails.filter(member => {
            const sendTime = member.sendTime ? new Date(member.sendTime) : null;
            const startDate = this.sendTimeStart ? new Date(this.sendTimeStart) : null;
            const endDate = this.sendTimeEnd ? new Date(this.sendTimeEnd) : null;

            if (startDate) {
                startDate.setHours(0, 0, 0, 0);
            }
            if (endDate) {
                endDate.setHours(23, 59, 59, 999);
            }

            const isStatusMatch = this.statusFilterList.length === 0 || this.statusFilterList.includes(member.status);
            const isDateMatch = (!startDate || !sendTime || sendTime >= startDate) && (!endDate || !sendTime || sendTime <= endDate);

            return isStatusMatch && isDateMatch;
        });
        this.currentPage = 1;
        this.isFilterModalOpen = false;
        this.updateShownData();
        this.clearSearchInput();
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(event);
    }

    backToCampaigns() {
        try {
            this[NavigationMixin.Navigate]({
                type: "standard__navItemPage",
                attributes: {
                    apiName: "MVEX__Marketing_Campaign",
                },
            });
        } catch (error) {
            console.log('error--> ', error);
        }
    }

    clearSearchInput() {
        const searchInput = this.template.querySelector('.input-members');
        if (searchInput) {
            searchInput.value = '';
        }
    }

    refreshTable() {
        this.fetchMemberEmails();
        this.statusFilterList = [];
        this.statusFilter = '';
        this.sendTimeStart = '';
        this.sendTimeEnd = '';
        this.clearSearchInput();
    }
}