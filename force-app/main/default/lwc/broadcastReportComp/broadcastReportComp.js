import { LightningElement, api, track } from 'lwc';
import getBroadcastGroupsWithStats from '@salesforce/apex/BroadcastMessageController.getBroadcastGroupsWithStats';
import getBroadcastMembersByGroupId from '@salesforce/apex/BroadcastMessageController.getBroadcastMembersByGroupId';
import { loadStyle } from 'lightning/platformResourceLoader';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
import { NavigationMixin } from 'lightning/navigation';

export default class BroadcastReportComp extends NavigationMixin(LightningElement) {
    @api recordId;
    @api record;
    @api templateName;
    @track paginatedData = [];
    @track filteredData = [];
    @track currentPage = 1;
    @track pageSize = 15;
    @track visiblePages = 5;
    @track broadcastReport=true;
    @track broadcastGroupReport=false;
    @track isLoading = false;
    @track groupData;
    @track paginatedGrpData = [];
    @track filteredGrpData = [];
    @track currentGrpPage = 1;
    @track pageGrpSize = 15;
    @track visibleGrpPages = 5;
    @track selectedGroupObject = '';

    connectedCallback() {
        loadStyle(this, MulishFontCss);
        this.loadBroadcastGroups();
    }

    get showNoRecordsMessage() {
        return this.filteredData.length === 0;
    }

    get name() {
        return this.record?.Name || '—';
    }

    get status() {
        return this.record?.MVEX__Status__c || '—';
    }

    get recipientCount() {
        return this.record?.MVEX__Recipient_Count__c || '0';
    }

    get groupName() {
        const group = this.data?.find(item => item.Id === this.selectedGroupId);
        return group?.Name || '—';
    }
    
    get memberCount() {
        const group = this.data?.find(item => item.Id === this.selectedGroupId);
        return group?.MVEX__Count_of_Members__c?.toString() || '0';
    }    

    get totalItems() {
        return this.filteredData.length;
    }
    
    get totalPages() {
        return Math.ceil(this.totalItems / this.pageSize);
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
            this.showToast('Error', 'Error in pageNumbers->' + error, 'error');
            return null;
        }
    }
    
    get isFirstPage() {
        return this.currentPage === 1;
    }
    
    get isLastPage() {
        return this.currentPage === Math.ceil(this.totalItems / this.pageSize);
    }

    // ------ Group Member --- 

    get showNoGroupMember() {
        return this.filteredGrpData.length === 0;
    }

    get totalGrpItems() {
        return this.filteredGrpData.length;
    }
    
    get totalGrpPages() {
        return Math.ceil(this.totalGrpItems / this.pageGrpSize);
    }
    
    get pageGrpNumbers() {
        try {
            const totalPages = this.totalGrpPages;
            const currentPage = this.currentGrpPage;
            const visiblePages = this.visibleGrpPages;

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
            this.showToast('Error', 'Error in pageGrpNumbers->' + error, 'error');
            return null;
        }
    }
    
    get isFirstGrpPage() {
        return this.currentGrpPage === 1;
    }
    
    get isLastGrpPage() {
        return this.currentGrpPage === Math.ceil(this.totalGrpItems / this.pageGrpSize);
    }


    loadBroadcastGroups() {
        this.isLoading = true;
        getBroadcastGroupsWithStats({broadcastId: this.recordId})
            .then(result => {
                this.data = result;
                this.filteredData = [...this.data];
                this.updateShownData();
            })
            .catch(() => {
                this.showToast('Error', 'Failed to load broadcast groups', 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }   

    updateShownData() {
        try {
            const startIndex = (this.currentPage - 1) * this.pageSize;
            const endIndex = Math.min(startIndex + this.pageSize, this.totalItems);
            this.paginatedData = this.filteredData.slice(startIndex, endIndex);
        } catch (error) {
            this.showToast('Error', 'Error updating shown data', 'error');
        }
    }

    handlePrevious() {
        try{
            if (this.currentPage > 1) {
                this.currentPage--;
                this.updateShownData();
            }
        }catch(error){
            this.showToast('Error', 'Error navigating to previous page', 'error');
        }
    }
    
    handleNext() {
        try{
            if (this.currentPage < this.totalPages) {
                this.currentPage++;
                this.updateShownData();
            }
        }catch(error){
            this.showToast('Error', 'Error navigating pages', 'error');
        }
    }

    handlePageChange(event) {
        try{
            const selectedPage = parseInt(event.target.getAttribute('data-id'), 10);
            if (selectedPage !== this.currentPage) {
                this.currentPage = selectedPage;
                this.updateShownData();
            }
        }catch(error){
            this.showToast('Error', 'Error navigating pages', 'error');
        }
    } 

    handleBack() {
        this[NavigationMixin.Navigate]({
                type: "standard__navItemPage",
                attributes: {
                    apiName: "MVEX__WhatsApp_Broadcast",
                },
            });
    }

    handleNameClick(event){
        this.broadcastGroupReport=true;
        this.broadcastReport=false;
        this.selectedGroupId = event.target.dataset.recordId;  
        this.selectedGroupObject = event.target.dataset.objectName;               
        this.fetchGroupMembers();
    }

    fetchGroupMembers() {
        this.isLoading = true;
        getBroadcastMembersByGroupId({
            groupId: this.selectedGroupId,
            objectName: this.selectedGroupObject,
            broadcastId: this.recordId
        })
        .then(result => {
            this.groupData = result.map((item, index) => ({
                id: item.record.Id,
                name: item.record.Name || 'Not Specified',
                phone: item.record.Phone || item.record.MobilePhone || '',
                status: item.status || '',
                hasReplied: item.hasReplied || false,
                repliedText: item.hasReplied ? 'Yes' : 'No',
                repliedClass: item.hasReplied ? 'replied-yes' : 'replied-no',
                index: index + 1
            }));
            
            this.filteredGrpData = [...this.groupData];
            this.updateGroupData();
        })
        .catch(() => {
            this.showToast('Error', 'Failed to load broadcast members', 'error');
        })
        .finally(() => {
            this.isLoading = false;
        });
    }

    updateGroupData() {
        try {
            const startIndex = (this.currentGrpPage - 1) * this.pageGrpSize;
            const endIndex = Math.min(startIndex + this.pageGrpSize, this.totalGrpItems);
            this.paginatedGrpData = this.filteredGrpData.slice(startIndex, endIndex);
            
        } catch (error) {
            this.showToast('Error', 'Error updating shown data', 'error');
        }
    }

    handleGrpPrevious() {
        try{
            if (this.currentGrpPage > 1) {
                this.currentGrpPage--;
                this.updateGroupData();
            }
        }catch(error){
            this.showToast('Error', 'Error navigating to previous page', 'error');
        }
    }
    
    handleGrpNext() {
        try{
            if (this.currentGrpPage < this.totalGrpPages) {
                this.currentGrpPage++;
                this.updateGroupData();
            }
        }catch(error){
            this.showToast('Error', 'Error navigating pages', 'error');
        }
    }

    handleGrpPageChange(event) {
        try{
            const selectedPage = parseInt(event.target.getAttribute('data-id'), 10);
            if (selectedPage !== this.currentGrpPage) {
                this.currentGrpPage = selectedPage;
                this.updateGroupData();
            }
        }catch(error){
            this.showToast('Error', 'Error navigating pages', 'error');
        }
    } 
}