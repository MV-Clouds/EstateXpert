import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAllFlows from '@salesforce/apex/WBTemplateController.getAllFlows';
import getPreviewURLofWhatsAppFlow from '@salesforce/apex/WBTemplateController.getPreviewURLofWhatsAppFlow';

export default class FlowPreviewModel extends LightningElement {
    @track flows = [];
    @track filteredFlows = []; // Stores search-filtered flows
    @track selectedFlow = '';
    @track iframeSrc = '';
    @track cachedPreviewURLs = new Map(); // Store preview URLs for caching
    @track searchTerm = ''; // Stores search input
    isSubmitDisabled = true;
    
    get flowDataAvailable(){
        return this.flows.length > 0;
    }
    
    connectedCallback() {
        this.fetchFlows();
    }

    // Fetch all flows from Apex
    fetchFlows() {
        try {
            getAllFlows()
                .then((data) => {
                    this.flows = data.map(flow => ({
                        id: flow.MVEX__Flow_Id__c,
                        name: flow.MVEX__Flow_Name__c,
                        date: this.formatDate(flow.LastModifiedDate),
                        isSelected: false
                    }));
                    if(data && data.length > 0){
                        this.isSubmitDisabled = false;
                    }
                    this.filteredFlows = [...this.flows]; // Initialize search-filtered list
                })
                .catch(error => {
                    console.error('Error fetching flows:', error);
                });
        } catch (error) {
            console.error('Error in fetchFlows:', error);
        }
    }

    // Handle search input and filter flows
    handleSearch(event) {
        try {
            this.searchTerm = event.target.value.toLowerCase();
            this.filteredFlows = this.flows.filter(flow =>
                flow.name.toLowerCase().includes(this.searchTerm)
            );
        } catch (error) {
            console.error('Error in handleSearch:', error);
        }
    }

    // Handle flow selection
    handleFlowChange(event) {
        try {
            const selectedId = event.target.value;
            this.selectedFlow = selectedId;
            
            // Update UI to show selected radio button
            this.filteredFlows = this.filteredFlows.map(flow => ({
                ...flow,
                isSelected: flow.id === this.selectedFlow
            }));
    
            // Check if URL is cached
            if (this.cachedPreviewURLs.has(selectedId)) {
                this.iframeSrc = this.cachedPreviewURLs.get(selectedId);
            } else {
                // Fetch preview URL from Apex
                getPreviewURLofWhatsAppFlow({ flowId: selectedId })
                .then((data) => {
                    if (data && data.status !== 'failed') {
    
                        const urlValue = typeof data === 'object' ? data.previewUrl : data;
    
                        if (urlValue) {
                            this.iframeSrc = urlValue;
                            this.cachedPreviewURLs.set(selectedId, urlValue); // Cache
                        } else {
                            console.error('URL key not found in the returned Map:', data);
                        }
                    } else {
                        console.error('Error: Backend returned "failed" or empty data');
                    }
                })
                .catch(error => {
                    console.error('Error in getting Flow Preview URL:', error);
                })
                .finally(() => {
                    this.isLoading = false;
                });
            }
        } catch (error) {
            console.error('Error in handleFlowChange:', error);
        }
    }

    // Format date to DD MMM YYYY
    formatDate(dateString) {
        if (dateString) {
            const date = new Date(dateString);
            return date.toLocaleDateString('en-GB', {
                day: 'numeric',
                month: 'short',
                year: 'numeric'
            });
        }
        return '';
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleSubmit() {
        if(!this.selectedFlow){
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: 'Please select a flow.',
                variant: 'error'
            }));
            return; // No flow selected, do not proceed
        }
        const selectedFlowData = {
            selectedFlow: this.selectedFlow, // Selected flow ID,
            iframeSrc : this.iframeSrc, // URL of WhatsApp preview
            flows: this.flows.find(flow => flow.id === this.selectedFlow)// Entire list of flows
        };   
        this.dispatchEvent(new CustomEvent('submit', { detail: selectedFlowData })); // Dispatch event to parent
    }
}