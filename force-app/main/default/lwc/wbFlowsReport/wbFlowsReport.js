import { LightningElement, track, api } from 'lwc';
import getWhatsAppFlowById from '@salesforce/apex/WhatsAppFlowController.getWhatsAppFlowById';
import getFlowSubmissionByFlowId from '@salesforce/apex/WhatsAppFlowController.getFlowSubmissionByFlowId';
import getFlowSubmissionById from '@salesforce/apex/WhatsAppFlowController.getFlowSubmissionById';
import { NavigationMixin } from 'lightning/navigation';

export default class WbFlowsReport extends NavigationMixin(LightningElement) {
    @api selectedFlowId;
    @api selectedFlowName;

    @track recordId;
    @track flowDetails;
    @track flowSubmissionDetails;
    @track record;
    @track paginatedData = [];
    @track filteredData = [];
    @track filteredDetails = [];
    @track currentPage = 1;
    @track pageSize = 15;
    @track visiblePages = 5;
    @track flowReport=true;
    @track isFlowSubmissionDetails=false;
    @track isLoading = false;
    @track paginatedDetails = [];
    @track currentGrpPage = 1;
    @track pageGrpSize = 15;
    @track visibleGrpPages = 5;
    @track breadcrumbs = [{ label: 'Flows' }];

    connectedCallback() {
        this.fetchFlowDetailsById();
        // console.log('flowReport = ', this.flowReport);
        // console.log('Selected Flow ID:', this.selectedFlowId);
        // console.log('Selected Flow Name:', this.selectedFlowName);
        this.breadcrumbs = [
            { label: 'All flows' },
            { label: this.selectedFlowName }
        ];
        this.updateBreadcrumbs();
        this.updateShownData();
    }

    get showNoRecordsMessage() {
        return this.filteredData.length === 0;
    }

    get isAnyReportActive() {
        return this.isFlowSubmissionDetails || this.flowReport;
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
        const group = this.data?.find(item => item.Id === this.selectedSubmissionId);
        return group?.Name || '—';
    }
    
    get memberCount() {
        const group = this.data?.find(item => item.Id === this.selectedSubmissionId);
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
            console.error('Error in getPageNumbers :: ', error);
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
        return this.filteredDetails.length === 0;
    }

    get totalGrpItems() {
        return this.filteredDetails.length;
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
            console.error('Error in pageGrpNumber :: ',error);
            return null;
        }
    }
    
    get isFirstGrpPage() {
        return this.currentGrpPage === 1;
    }
    
    get isLastGrpPage() {
        return this.currentGrpPage === Math.ceil(this.totalGrpItems / this.pageGrpSize);
    }

    fetchFlowDetailsById() {
        this.isLoading = true;
        // console.log('Fetching flow details for ID:', this.selectedFlowId);
        getWhatsAppFlowById({ flowId: this.selectedFlowId })
            .then(result => {
                if (result && result.length > 0) {
                    this.flowDetails = result[0];
                    this.recordId = this.flowDetails.Id;
                }
                this.fetchFlowReportById();
            })
            .catch((error) => {
                console.error('Error fetching flow details:', error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    fetchFlowReportById(){
        // console.log('Fetching flow report for ID:', this.recordId);
        this.isLoading = true;
        getFlowSubmissionByFlowId({ flowId: this.recordId })
            .then(result => {
                this.data = result.map((item, index) => ({
                    ...item,
                    CreatedDate: this.formatDate(item.CreatedDate),
                    index: index + 1,
                }));
                this.filteredData = [...this.data];
                this.updateShownData();
            })
            .catch((error) => {
                console.error('Error fetching flow report:', error);
            });
    }

    fetchSubmissionDetailsById() {
        console.log('Fetching submission details for ID:', this.selectedSubmissionId);
        this.isLoading = true;

        getFlowSubmissionById({ submissionId: this.selectedSubmissionId })
            .then(result => {
                console.log('result:', JSON.stringify(result), 'type:', typeof result, 'length:', result.length, 'typeof length:');
                
                if (result && result.length > 0) {
                    const transformed = [];
                    let rowIndex = 1; // Counter for the overall row index

                    result.forEach((item) => {
                        try {
                            const parsedJson = JSON.parse(item.MVEX__Flow_Response_Mapping__c);
                            for (const key in parsedJson) {
                                const value = parsedJson[key];

                                const parts = key.split(' - ');
                                const flowScreen = parts[0]?.trim() || '';
                                let flowField = parts[1]?.trim() || '';
                                flowField = flowField.replace(/[:\-]\s*$/, '');

                                transformed.push({
                                    flowScreen,
                                    flowField,
                                    userInput: Array.isArray(value) ? value.join(', ') : value,
                                    CreatedDate: item.CreatedDate,
                                    MVEX__Submitter_Name__c: item.MVEX__Submitter_Name__c,
                                    MVEX__Submitter_Phone__c: item.MVEX__Submitter_Phone__c,
                                    Id: item.Id,
                                    index: rowIndex++
                                });
                            }
                        } catch (parseError) {
                            console.error('Error parsing Flow_Response_Mapping__c JSON:', parseError);
                        }
                    });

                    this.flowSubmissionDetails = transformed;
                    console.log('Transformed Submission Details:', JSON.stringify(this.flowSubmissionDetails));
                }

                this.isFlowSubmissionDetails = true;
                this.flowReport = false;
                this.filteredDetails = [...this.flowSubmissionDetails];
                this.updateGroupData();
            })
            .catch((e) => {
                console.error('Error fetching submission details:', e);
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
            console.error('Error updating shown data:', error);
        }
    }

    handlePrevious() {
        try{
            if (this.currentPage > 1) {
                this.currentPage--;
                this.updateShownData();
            }
        }catch(error){
            console.error('Error navigating to previous page:', error);
        }
    }
    
    handleNext() {
        try{
            if (this.currentPage < this.totalPages) {
                this.currentPage++;
                this.updateShownData();
            }
        }catch(error){
            console.error('Error navigating pages:', error);
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
            console.error('Error navigating pages:', error);
        }
    } 

    handleBack() {
        if (this.isFlowSubmissionDetails) {
            // If on isFlowSubmissionDetails, go back to flowReport
            this.isFlowSubmissionDetails = false;
            this.flowReport = true;
            this.flowSubmissionDetails = null; 
            this.paginatedDetails = []; 
        } else if (this.flowReport) {
            // If on flowReport, go back to main page
            this.flowReport = false;
            this.record = null; 
            this.paginatedData = []; 
        }
    }

    handleNameClick(event){
        try {
            this.isFlowSubmissionDetails=true;
            this.flowReport=false;
            this.selectedSubmissionId = event.target.dataset.recordId;
    
            const submitterName = event.currentTarget.textContent;
            if (!this.breadcrumbs.find(b => b.label === submitterName)) {
                this.breadcrumbs = [...this.breadcrumbs, { label: submitterName }];
                this.updateBreadcrumbs();
            }
            this.fetchSubmissionDetailsById();
        } catch (error) {
            console.error('Error in handleNameClick:', error);
        }
    }

    updateBreadcrumbs() {
        this.breadcrumbs = this.breadcrumbs.map((b, i, arr) => {
            return {
                ...b,
                className:
                    i === arr.length - 1
                        ? 'breadcrumb-link current-crumb'
                        : 'breadcrumb-link'
            };
        });
    }

    updateGroupData() {
        try {
            const startIndex = (this.currentGrpPage - 1) * this.pageGrpSize;
            const endIndex = Math.min(startIndex + this.pageGrpSize, this.totalGrpItems);
            this.paginatedDetails = this.filteredDetails.slice(startIndex, endIndex);
        } catch (error) {
            console.error('Error updating shown data:', error);
        }
    }

    handleGrpPrevious() {
        try{
            if (this.currentGrpPage > 1) {
                this.currentGrpPage--;
                this.updateGroupData();
            }
        }catch(error){
            console.error('Error in handleGrpPrevious:', error);
        }
    }
    
    handleGrpNext() {
        try{
            if (this.currentGrpPage < this.totalGrpPages) {
                this.currentGrpPage++;
                this.updateGroupData();
            }
        }catch(error){
            console.error('Error in handleGrpNext:', error);
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
            console.error('Error in handleGrpPageChange:', error);
        }
    }

    formatDate(dateString) {
        if(dateString){
            const date = new Date(dateString);
            return date.toLocaleDateString('en-GB', {
                day: 'numeric',
                month: 'short',
                year: 'numeric'
            });
        }
    }

    backToAllFlowPage(){
        if(!this.isFlowSubmissionDetails){
            let componentDef = {
                componentDef: "MVEX:wbAllFlowsPage",
            };
            
            let encodedComponentDef = btoa(JSON.stringify(componentDef));
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: '/one/one.app#' + encodedComponentDef
                }
            });
        }else{
            this.isFlowSubmissionDetails = false;
            this.flowReport = true;
        }
        // let cmpDef = {
        //             componentDef: "c:wbAllFlowsPage",
        //             attributes: {
        //                 isEditMode: this.isEditMode,
        //                 selectedFlowId: this.selectedFlowId
        //             }
        //         };
        
        //         let encodedDef = btoa(JSON.stringify(cmpDef));
        //             this[NavigationMixin.Navigate]({
        //             type: "standard__webPage",
        //             attributes: {
        //                 url:  "/one/one.app#" + encodedDef                                                         
        //             }
        //         });
    }
}