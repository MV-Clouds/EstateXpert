import { LightningElement, track } from 'lwc';
import getBroadcastGroups from '@salesforce/apex/BroadcastMessageController.getBroadcastGroups';
import deleteBroadcastGroup from '@salesforce/apex/BroadcastMessageController.deleteBroadcastGroup';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { loadStyle } from 'lightning/platformResourceLoader';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';

export default class WbAllBroadcastGroupPage extends NavigationMixin(LightningElement) {
    @track data = [];
    @track filteredData = [];
    @track paginatedData = [];
    @track currentPage = 1;
    @track pageSize = 12;
    @track visiblePages = 5;
    @track isLoading = true;
    @track showCommunicationPopup = false;
    @track selectedCommunicationType = 'Email';

    broadcastGroupId = null;

    get showNoRecordsMessage() {
        return this.filteredData.length === 0;
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

    get isEmailChecked() {
        return this.selectedCommunicationType === 'Email';
    }

    get isWhatsAppChecked() {
        return this.selectedCommunicationType === 'WhatsApp';
    }

    get isBothChecked() {
        return this.selectedCommunicationType === 'Both';
    }
    
    connectedCallback() {
        try {
            loadStyle(this, MulishFontCss)
                .then(() => {
                    console.log('External Css Loaded');
                })
                .catch(error => {
                    console.log('Error occurring during loading external css', error);
                });
            this.loadBroadcastGroups();
        } catch (e) {
            console.error('Error in connectedCallback:::', e.message);
        }
    }

    loadBroadcastGroups() {
        this.isLoading = true;
        getBroadcastGroups()
            .then(result => {
                console.log('Broadcast Groups fetched:', JSON.stringify(result));
                
                this.data = result.map((item, index) => ({
                    ...item,
                    index: index + 1,
                }));
                this.filteredData = [...this.data];
                this.updateShownData();
            })
            .catch(() => {
                this.showToast('Error', 'Error loading records', 'error');
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

    handleSearch(event) {
        try {
            this.filteredData = this.data.filter((item) =>
                (item.Name?.toLowerCase() ?? '').includes(
                    (event.detail.value.toLowerCase() ?? ''))
            );
            this.updateShownData();
        } catch (error) {
            this.showToast('Error', 'Error searching records', 'error');
        }
    }
    
    handlePrevious() {
        try {
            if (this.currentPage > 1) {
                this.currentPage--;
                this.updateShownData();
            }
        } catch (error) {
            this.showToast('Error', 'Error navigating pages', 'error');
        }
    }
    
    handleNext() {
        try {
            if (this.currentPage < this.totalPages) {
                this.currentPage++;
                this.updateShownData();
            }
        } catch (error) {
            this.showToast('Error', 'Error navigating pages', 'error');
        }
    }
    
    handlePageChange(event) {
        try {
            const selectedPage = parseInt(event.currentTarget.getAttribute('data-id'), 10);
            if (selectedPage !== this.currentPage) {
                this.currentPage = selectedPage;
                this.updateShownData();
            }
        } catch (error) {
            this.showToast('Error', 'Error navigating pages', 'error');
        }
    } 

    handleEditGroup(event) {
        const recordId = event.currentTarget.dataset.id;
        const communicationType = event.currentTarget.dataset.communicationType;
        console.log();
        
        this.broadcastGroupId = recordId;
        this.selectedCommunicationType = communicationType;
        this.navigateToNewBroadcast();
    }

    handleDeleteGroup(event) {
        this.broadcastGroupId = event.currentTarget.dataset.id;
        this.showMessagePopup('Warning', 'Delete Broadcast Group', 'Are you sure you want to delete this broadcast group? This action cannot be undone.');
    }

    handleNewGroupClick() {
        this.showCommunicationPopup = true;
    }

    handleCommunicationTypeChange(event) {
        this.selectedCommunicationType = event.currentTarget.value;

        console.log('Selected Communication Type:', this.selectedCommunicationType);
        
    }

    handlePopupContinue() {
        this.showCommunicationPopup = false;
        this.navigateToNewBroadcast();
    }

    handlePopupClose() {
        this.showCommunicationPopup = false;
        this.selectedCommunicationType = 'Email'; // Reset to default
    }

    backToControlCenter() {
        this[NavigationMixin.Navigate]({
            type: "standard__navItemPage",
            attributes: {
                apiName: "MVEX__Control_Center",
            },
        });
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }

    showMessagePopup(Status, Title, Message) {
        const messageContainer = this.template.querySelector('c-message-popup');
        if (messageContainer) {
            messageContainer.showMessagePopup({
                status: Status,
                title: Title,
                message: Message,
            });
        }
    }

    handleConfirmation(event) {
        if (event.detail === true) {
            this.isLoading = true;
            let recordId = this.broadcastGroupId;
            deleteBroadcastGroup({ groupId: recordId })
                .then(() => {
                    this.showToast('Success', 'Broadcast Group deleted successfully', 'success');
                    this.data = this.data
                        .filter(item => item.Id !== recordId)
                        .map((item, index) => ({
                            ...item,
                            index: index + 1,
                        }));
                    this.filteredData = this.data;
                    this.updateShownData();
                })
                .catch(() => {
                    this.showToast('Error', 'Failed to delete Broadcast Group', 'error');
                })
                .finally(() => {
                    this.isLoading = false;
                    this.broadcastGroupId = null;
                });
        } else {
            this.broadcastGroupId = null;
        }
    }

    navigateToNewBroadcast() {
        console.log('Navigate to new broadcast');
        console.log('broadcastGroupId: ' + this.broadcastGroupId);
        console.log('communicationType: ' + this.selectedCommunicationType);
        
        let componentDef = {
            componentDef: "MVEX:broadcastMessageComp",
            attributes: {
                broadcastGroupId: this.broadcastGroupId,
                communicationType: this.selectedCommunicationType
            }
        };

        let encodedComponentDef = btoa(JSON.stringify(componentDef));
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: '/one/one.app#' + encodedComponentDef
            }
        });
    }
}