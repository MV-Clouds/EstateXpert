import { LightningElement, track } from 'lwc';
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
    

    connectedCallback() {
        this.fetchFlows();
    }

    // Fetch all flows from Apex
    fetchFlows() {
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
    }

    get flowDataAvailable(){
        return this.flows.length > 0;
    }


    // Handle search input and filter flows
    handleSearch(event) {
        this.searchTerm = event.target.value.toLowerCase();
        this.filteredFlows = this.flows.filter(flow =>
            flow.name.toLowerCase().includes(this.searchTerm)
        );
    }

    // Handle flow selection
    handleFlowChange(event) {
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
                    if (data !== 'failed') {
                        this.iframeSrc = data;
                        this.cachedPreviewURLs.set(selectedId, data); // Cache the URL
                    } else {
                        console.error('Invalid preview URL received');
                    }
                })
                .catch(error => {
                    console.error('Error fetching preview URL:', error);
                });
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
        
        
        const selectedFlowData = {
            selectedFlow: this.selectedFlow, // Selected flow ID,
            iframeSrc : this.iframeSrc, // URL of WhatsApp preview
            flows: this.flows.find(flow => flow.id === this.selectedFlow)// Entire list of flows
        };
    
        
        this.dispatchEvent(new CustomEvent('submit', { detail: selectedFlowData })); // Dispatch event to parent
    }
    
}