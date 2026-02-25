import { LightningElement, api, track } from 'lwc';
import getBroadcastGroupsWithStats from '@salesforce/apex/BroadcastMessageController.getBroadcastGroupsWithStats';
import getAllBroadcastMembers from '@salesforce/apex/BroadcastMessageController.getAllBroadcastMembers';
import getBroadcastRecord from '@salesforce/apex/BroadcastMessageController.getBroadcastRecord';
import { loadStyle } from 'lightning/platformResourceLoader';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class BroadcastReportComp extends NavigationMixin(LightningElement) {
    @api recordId;
    // @api record;
    @track record;
    @track paginatedData = [];
    @track filteredData = [];
    @track currentPage = 1;
    @track pageSize = 15;
    @track visiblePages = 5;
    @track isLoading = false;
    @track expandedRows = {};
    @track groupMembersData = {};

    connectedCallback() {
        loadStyle(this, MulishFontCss);
        console.log('broadcastReportComp recordId', this.recordId);
        console.log('broadcastReportComp record', this.record);
        this.loadBroadcastGroups();
        this.loadBroadcastGroupsWithBroadcastId();
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

    get templateName(){
        return this.record?.MVEX__Template_Name__c || '-';
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

    loadBroadcastGroups() {
        this.isLoading = true;
        console.log('broadcastReportComp recordId 2', this.recordId);
        
        getBroadcastGroupsWithStats({broadcastId: this.recordId})
            .then(result => {
                this.data = result.map((group, index) => ({
                    ...group,
                    index: index + 1
                }));
                console.log('result', result);
                
                this.filteredData = [...this.data];
                
                // Load all group members data upfront
                this.loadAllGroupMembers();
            })
            .catch(() => {
                this.showToast('Error', 'Failed to load broadcast groups', 'error');
                this.isLoading = false;
            });
    }   

     loadBroadcastGroupsWithBroadcastId() {
        getBroadcastRecord({broadcastId: this.recordId})
            .then(result => {
                console.log('result--> ',result);
                this.record = result;
                console.log('this.data in report--> ',this.record);               

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
            this.paginatedData = this.filteredData.slice(startIndex, endIndex).map(group => ({
                ...group,
                isExpanded: this.expandedRows[group.Id] || false,
                members: this.groupMembersData[group.Id] || [],
                accordionKey: `${group.Id}-accordion`
            }));
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

    loadAllGroupMembers() {
        // Fetch all members for all groups in a single Apex call
        getAllBroadcastMembers({ broadcastId: this.recordId })
            .then(result => {
                console.log('getAllBroadcastMembers result:', result);
                
                // Result is a Map<String, List<BroadcastMemberWrapper>>
                // Process the map to format member data
                const membersData = {};
                
                // Check if result is valid
                if (result) {
                    for (const groupId in result) {
                        if (result.hasOwnProperty(groupId)) {
                            const membersList = result[groupId];
                            console.log(`Processing group ${groupId} with ${membersList.length} members`);
                            
                            const members = membersList.map((item, index) => ({
                                id: item.record.Id,
                                name: item.record.Name || 'Not Specified',
                                phone: item.record.Phone || item.record.MobilePhone || '',
                                status: item.status || '',
                                hasReplied: item.hasReplied || false,
                                repliedText: item.hasReplied ? 'Yes' : 'No',
                                repliedClass: item.hasReplied ? 'replied-yes' : 'replied-no',
                                index: index + 1
                            }));
                            
                            membersData[groupId] = members;
                        }
                    }
                }
                
                this.groupMembersData = membersData;
                console.log('Updated groupMembersData:', this.groupMembersData);
                
                // Update display to include the loaded member data
                this.updateShownData();
            })
            .catch((error) => {
                console.error('Error loading group members:', error);
                this.showToast('Error', 'Failed to load group members', 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleNameClick(event){
        // Use currentTarget to get the element with data attributes, not the clicked child element
        const groupId = event.currentTarget.dataset.recordId;  
        
        console.log('Clicked groupId:', groupId);
        console.log('Current expandedRows:', this.expandedRows);
        console.log('Available members for this group:', this.groupMembersData[groupId]);
        
        // Just toggle accordion state - data is already loaded
        if (this.expandedRows[groupId]) {
            // Collapse
            this.expandedRows = { ...this.expandedRows, [groupId]: false };
        } else {
            // Expand
            this.expandedRows = { ...this.expandedRows, [groupId]: true };
        }
        this.updateShownData();
    }

    getStatusClass(status) {
        const statusMap = {
            'Sent': 'Sent',
            'Delivered': 'Delivered',
            'Seen': 'Seen',
            'Failed': 'Failed'
        };
        return statusMap[status] || '';
    } 

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(event);
    }
}