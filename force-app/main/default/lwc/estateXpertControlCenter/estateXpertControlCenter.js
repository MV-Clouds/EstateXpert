import { LightningElement, wire } from "lwc";
import MulishFontCss from "@salesforce/resourceUrl/MulishFontCss";
import { NavigationMixin, CurrentPageReference } from "lightning/navigation";
import { loadStyle } from "lightning/platformResourceLoader";
import FORM_FACTOR from "@salesforce/client/formFactor";

export default class EstateXpertControlCenter extends NavigationMixin(LightningElement) {
    currentView = 'controlCenter';
    selectedComponent = null;
    selectedComponentTitle = '';
    selectedComponentDescription = '';
    parentComponentTitle = ''; // For nested navigation breadcrumb
    
    // Portal mapping state
    portalId = null;
    portalGen = null;
    portalName = null;
    portalIconUrl = null;
    portalStatus = null;
    isXMLForPF = false;
    
    // Lead capture state
    integrationType = null; // 'Google' or 'Meta'

    /**
     * Method Name: getStateParameters
     * @description: Retrieves and processes the current page reference parameters
     * Date: 23/09/2026
     * Created By: Vyom Soni
     */
    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference && currentPageReference.state) {
            const target = currentPageReference.state.c__openComponent;
            if (target === 'storageIntegration') {
                this.generalIntegrationMethod();
            }
        }
    }

    /**
     * Method Name: connectedCallback
     * @description: Lifecycle hook that fires when the component is inserted into the DOM
     * Date: 23/09/2026
     * Created By: Vyom Soni
     */
    connectedCallback() {
        loadStyle(this, MulishFontCss);
    }

    /**
     * Method Name: isControlCenterView
     * @description: Getter to check if the current view is the main control center
     * Date: 23/09/2026
     * Created By: Vyom Soni
     */
    get isControlCenterView() {
        return this.currentView === 'controlCenter';
    }

    /**
     * Method Name: isChildComponentView
     * @description: Getter to check if the current view is a child component
     * Date: 23/09/2026
     * Created By: Vyom Soni
     */
    get isChildComponentView() {
        return this.currentView === 'childComponent';
    }

    /**
     * Method Name: layoutClass
     * @description: Getter to dynamically set layout CSS classes based on the active view
     * Date: 23/09/2026
     * Created By: Vyom Soni
     */
    get layoutClass() {
        return this.isChildComponentView 
            ? 'control-center-layout with-breadcrumb' 
            : 'control-center-layout';
    }

    /**
     * Method Name: showRightSidebar
     * @description: Getter to check if the right sidebar should be displayed based on form factor
     * Date: 23/09/2026
     * Created By: Vyom Soni
     */
    get showRightSidebar() {
        return FORM_FACTOR === 'Large';
    }

    /**
     * Method Name: isMapFieldsComponent
     * @description: Checks if MapFields component is selected
     * Date: 23/09/2026
     * Created By: Vyom Soni
     */
    get isMapFieldsComponent() {
        return this.selectedComponent === 'mapFields';
    }

    /**
     * Method Name: isLeadAssignmentRuleComponent
     * @description: Checks if LeadAssignmentRule component is selected
     * Date: 23/09/2026
     * Created By: Vyom Soni
     */
    get isLeadAssignmentRuleComponent() {
        return this.selectedComponent === 'leadAssignmentRule';
    }

    /**
     * Method Name: isStorageIntegrationComponent
     * @description: Checks if StorageIntegration component is selected
     * Date: 23/09/2026
     * Created By: Vyom Soni
     */
    get isStorageIntegrationComponent() {
        return this.selectedComponent === 'storageIntegration';
    }

    /**
     * Method Name: isLeadCaptureCmpComponent
     * @description: Checks if LeadCaptureCmp component is selected
     * Date: 23/09/2026
     * Created By: Vyom Soni
     */
    get isLeadCaptureCmpComponent() {
        return this.selectedComponent === 'leadCaptureCmp';
    }

    /**
     * Method Name: isPortalMappingComponent
     * @description: Checks if PortalMapping component is selected
     * Date: 23/09/2026
     * Created By: Vyom Soni
     */
    get isPortalMappingComponent() {
        return this.selectedComponent === 'portalMapping';
    }

    /**
     * Method Name: isPortalMappingLandingPageComponent
     * @description: Checks if PortalMappingLandingPage component is selected
     * Date: 23/09/2026
     * Created By: Vyom Soni
     */
    get isPortalMappingLandingPageComponent() {
        return this.selectedComponent === 'portalMappingLandingPage';
    }

    /**
     * Method Name: isGoogleLeadFieldMappingComponent
     * @description: Checks if GoogleLeadFieldMapping component is selected
     * Date: 23/09/2026
     * Created By: Vyom Soni
     */
    get isGoogleLeadFieldMappingComponent() {
        return this.selectedComponent === 'googleLeadFieldMapping';
    }

    /**
     * Method Name: hasParentComponent
     * @description: Checks if there is a parent component set for breadcrumbs
     * Date: 23/09/2026
     * Created By: Vyom Soni
     */
    get hasParentComponent() {
        return this.parentComponentTitle !== '';
    }

    /**
     * Method Name: handleCardHover
     * @description: Updates sidebar with feature description on hover
     * Date: 13/02/2026
     * Created By: Karan Singh
     */
    handleCardHover(event) {
        const card = event.currentTarget;
        const title = card.dataset.title;
        const desc = card.dataset.desc;
        
        const sidebar = this.template.querySelector('.feature-description');
        if (sidebar) {
            sidebar.classList.add('active');
            const titleEl = sidebar.querySelector('.description-title');
            const descEl = sidebar.querySelector('.description-text');
            if (titleEl) titleEl.textContent = title;
            if (descEl) descEl.textContent = desc;
        }
    }

    /**
     * Method Name: handleCardLeave
     * @description: Resets sidebar to default state
     * Date: 13/02/2026
     * Created By: Karan Singh
     */
    handleCardLeave(event) {
        const sidebar = this.template.querySelector('.feature-description');
        if (sidebar) {
            sidebar.classList.remove('active');
            const titleEl = sidebar.querySelector('.description-title');
            const descEl = sidebar.querySelector('.description-text');
            if (titleEl) titleEl.textContent = 'Hover over a feature';
            if (descEl) descEl.textContent = 'Hover over any feature card to see detailed information here';
        }
    }

    /**
     * Method Name: openComponent
     * @description: Opens a child component in-place
     * Date: 17/02/2026
     * Created By: Karan Singh
     */
    openComponent(componentName, title, description) {
        this.selectedComponent = componentName;
        this.selectedComponentTitle = title;
        this.selectedComponentDescription = description;
        this.currentView = 'childComponent';
    }

    /**
     * Method Name: goToControlCenter
     * @description: Always returns to the main control center view
     * Date: 17/02/2026
     * Created By: Karan Singh
     */
    goToControlCenter() {
        try {
            this.currentView = 'controlCenter';
            this.selectedComponent = null;
            this.selectedComponentTitle = '';
            this.selectedComponentDescription = '';
            this.parentComponentTitle = '';
            this.portalId = null;
            this.portalGen = null;
            this.portalName = null;
            this.portalIconUrl = null;
            this.portalStatus = null;
            this.integrationType = null;
        
            if (window?.history?.replaceState && window?.location?.pathname) {
                window.history.replaceState({}, document.title, window.location.pathname);
            }
        } catch (e) {
            console.log('Error in goToControlCenter:', e);
        }
    }

    /**
     * Method Name: goToParentComponent
     * @description: Goes back one level to the parent component
     * Date: 17/02/2026
     * Created By: Karan Singh
     */
    goToParentComponent() {
        // Go back to parent component (one level up)
        if (this.parentComponentTitle === 'Portal Integration') {
            this.selectedComponent = 'portalMapping';
            this.selectedComponentTitle = 'Portal Integration';
            this.selectedComponentDescription = 'Connect and manage your portal integrations';
            this.parentComponentTitle = '';
            // Clear portal state
            this.portalId = null;
            this.portalGen = null;
            this.portalName = null;
            this.portalIconUrl = null;
            this.portalStatus = null;
        } else if (this.parentComponentTitle === 'Lead Capture') {
            this.selectedComponent = 'leadCaptureCmp';
            this.selectedComponentTitle = 'Lead Capture';
            this.selectedComponentDescription = 'The "Lead Capture" integrates with Meta Ads and Google Ads to automatically capture leads from your advertising accounts directly into Salesforce. Configure custom field mapping to ensure lead data flows seamlessly into your CRM for immediate follow-up.';
            this.parentComponentTitle = '';
            // Clear lead capture state
            this.integrationType = null;
        }
    }

    /**
     * Method Name: mapListingAndPropertyMethod
     * @description: Used to open mapFields component.
     * Date: 09/09/2024
     * Created By: Karan Singh
     */
    mapListingAndPropertyMethod(event) {
        event.preventDefault();
        this.openComponent(
            'mapFields', 
            'Map Listing & Property',
            'The "Map Listing and Property" modal streamlines data synchronization between Listing and Property records by allowing users to define field correspondences. This automation ensures that relevant information is consistently transferred between the two object types, eliminating manual data entry and reducing errors.'
        );
    }

    /**
     * Method Name: leadAssignmentRule
     * @description: Used to open supportRequestCmp component.
     * Date: 09/09/2024
     * Created By: Karan Singh
     */
    leadAssignmentRule(event) {
        event.preventDefault();
        this.openComponent(
            'leadAssignmentRule', 
            'Contact Assignment Rules',
            'The "Contact Assignment Rule" modal allows users to configure contact assignment rules, enabling automatic distribution of contacts based on custom criteria. Set up intelligent routing to ensure contacts reach the right team members efficiently.'
        );
    }

    /**
     * Method Name: generalIntegrationMethod
     * @description: Used to open storageIntegration component.
     * Date: 09/09/2024
     * Created By: Karan Singh
     */
    generalIntegrationMethod(event) {
        if (event && typeof event.preventDefault === 'function') {
            event.preventDefault();
        }
        this.openComponent(
            'storageIntegration', 
            'Integration Hub',
            'The "Integration Hub" modal simplifies storage, email, instagram integration by providing seamless connectivity with various third-party services, enhancing overall functionality and user experience. Connect your favorite tools and platforms in one centralized location.'
        );
    }

    /**
     * Method Name: leadCaptureMethod
     * @description: Used to open leadCaptureCmp component.
     * Date: 09/09/2024
     * Created By: Karan Singh
     */
    leadCaptureMethod() {
        this.openComponent(
            'leadCaptureCmp', 
            'Lead Capture',
            'The "Lead Capture" integrates with Meta Ads and Google Ads to automatically capture leads from your advertising accounts directly into Salesforce. Configure custom field mapping to ensure lead data flows seamlessly into your CRM for immediate follow-up.'
        );
    }

    /**
     * Method Name: handleLeadCaptureNavigation
     * @description: Handles navigation from leadCaptureCmp to googleLeadFieldMapping
     * Date: 17/02/2026
     * Created By: Karan Singh
     */
    handleLeadCaptureNavigation(event) {
        const { integrationType } = event.detail;
        
        // Store integration type
        this.integrationType = integrationType;
        
        // Set parent component for breadcrumb
        this.parentComponentTitle = 'Lead Capture';
        
        // Set description for sidebar based on integration type
        const integrationLabel = integrationType === 'Meta' ? 'Meta Ads' : 'Google Ads';
        const description = `Map ${integrationLabel} form fields to Salesforce Contact fields. This ensures seamless data integration from ${integrationLabel} leads into Salesforce, reducing manual data entry and errors. Configure field mappings to automatically sync lead information.`;
        
        // Navigate to field mapping page
        this.selectedComponent = 'googleLeadFieldMapping';
        this.selectedComponentTitle = `Map ${integrationLabel} Fields`;
        this.selectedComponentDescription = description;
        this.currentView = 'childComponent';
    }

    /**
     * Method Name: portalIntegrationMethod
     * @description: Used to open portalMapping component in-place.
     * Date: 09/09/2024
     * Updated: 17/02/2026
     * Created By: Karan Singh
     */
    portalIntegrationMethod(event) {
        event.preventDefault();
        this.openComponent(
            'portalMapping',
            'Portal Integration',
            'Connect and manage your portal integrations. Configure field mappings and synchronize data between Salesforce and external portals seamlessly.'
        );
    }

    /**
     * Method Name: handlePortalNavigation
     * @description: Handles navigation from portalMapping to portalMappingLandingPage
     * Date: 17/02/2026
     * Created By: Karan Singh
     */
    handlePortalNavigation(event) {
        const { portalId, portalGen, portalName, portalIconUrl, portalStatus, isXMLForPF } = event.detail;
        this.portalId = portalId;
        this.portalGen = portalGen;
        this.portalName = portalName;
        this.portalIconUrl = portalIconUrl;
        this.portalStatus = portalStatus;
        this.isXMLForPF = isXMLForPF;
        this.parentComponentTitle = 'Portal Integration';
        this.selectedComponent = 'portalMappingLandingPage';
        this.selectedComponentTitle = portalName;
        this.currentView = 'childComponent';
    }
}