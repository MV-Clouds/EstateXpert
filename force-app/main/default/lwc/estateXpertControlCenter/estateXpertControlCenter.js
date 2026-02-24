import { LightningElement, track, wire } from "lwc";
import MulishFontCss from "@salesforce/resourceUrl/MulishFontCss";
import { NavigationMixin } from "lightning/navigation";
import { loadStyle } from "lightning/platformResourceLoader";
import getMetadataRecords from "@salesforce/apex/ControlCenterController.getMetadataRecords";

export default class EstateXpertControlCenter extends NavigationMixin(LightningElement) {
    @track featureAvailability = {};
    @track isLoading = true;
    @track currentView = 'controlCenter'; // 'controlCenter' or 'childComponent'
    @track selectedComponent = null;
    @track selectedComponentTitle = '';
    @track selectedComponentDescription = '';
    @track parentComponentTitle = ''; // For nested navigation breadcrumb
    
    // Portal mapping state
    @track portalId = null;
    @track portalGen = null;
    @track portalName = null;
    @track portalIconUrl = null;
    @track portalStatus = null;
    @track isXMLForPF = false;
    
    // Lead capture state
    @track integrationType = null; // 'Google' or 'Meta'

    connectedCallback() {
        // Load Mulish font
        loadStyle(this, MulishFontCss)
            .then(() => {
                console.log("Css loaded successfully");
            })
            .catch((error) => {
                console.log("Error loading style:", error);
            });
    }

    @wire(getMetadataRecords)
    metadataRecords({ error, data }) {
        if (data) {
            this.featureAvailability = data.reduce((acc, record) => {
                acc[record.DeveloperName] = record.MVEX__isAvailable__c;
                return acc;
            }, {});
            setTimeout(() => {
                this.isLoading = false;
            }, 1000);
        } else if (error) {
            console.error("Error fetching metadata records:", error);
            this.isLoading = false;
        }
    }

    get isWhatsappSectionAvailable() {
        return !this.featureAvailability?.Whatsapp_Flow_Builder &&
            !this.featureAvailability?.Whatsapp_Template_Builder &&
            !this.featureAvailability?.Whatsapp_Embedded_Signup
            ? false
            : true;
    }

    get isIntegrationSectionAvailable() {
        return !this.featureAvailability?.General_Integrations &&
            !this.featureAvailability?.Portal_Integration &&
            !this.featureAvailability?.Lead_Capture
            ? false
            : true;
    }

    get isGeneralSectionAvailable() {
        return !this.featureAvailability?.Map_Listing_And_Property &&
            !this.featureAvailability?.Map_Listing_And_Inquiry &&
            !this.featureAvailability?.Configure_Settings &&
            !this.featureAvailability?.Lead_Assignment_Rule &&
            !this.featureAvailability?.Object_Config &&
            !this.featureAvailability?.Template_Builder
            ? false
            : true;
    }

    get isControlCenterView() {
        return this.currentView === 'controlCenter';
    }

    get isChildComponentView() {
        return this.currentView === 'childComponent';
    }

    get layoutClass() {
        return this.isChildComponentView 
            ? 'control-center-layout with-breadcrumb' 
            : 'control-center-layout';
    }

    // Component type getters for in-place rendering
    get isMapFieldsComponent() {
        return this.selectedComponent === 'mapFields';
    }

    get isLeadAssignmentRuleComponent() {
        return this.selectedComponent === 'leadAssignmentRule';
    }

    get isStorageIntegrationComponent() {
        return this.selectedComponent === 'storageIntegration';
    }

    get isLeadCaptureCmpComponent() {
        return this.selectedComponent === 'leadCaptureCmp';
    }

    get isObjectConfigCompComponent() {
        return this.selectedComponent === 'objectConfigComp';
    }

    get isPortalMappingComponent() {
        return this.selectedComponent === 'portalMapping';
    }

    get isPortalMappingLandingPageComponent() {
        return this.selectedComponent === 'portalMappingLandingPage';
    }

    get isGoogleLeadFieldMappingComponent() {
        return this.selectedComponent === 'googleLeadFieldMapping';
    }

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
        // Always go back to control center, clear all state
        this.currentView = 'controlCenter';
        this.selectedComponent = null;
        this.selectedComponentTitle = '';
        this.selectedComponentDescription = '';
        this.parentComponentTitle = '';
        // Clear portal state
        this.portalId = null;
        this.portalGen = null;
        this.portalName = null;
        this.portalIconUrl = null;
        this.portalStatus = null;
        // Clear lead capture state
        this.integrationType = null;
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
     * Method Name: goBackToControlCenter (kept for backward compatibility)
     * @description: Smart navigation - goes to parent if exists, otherwise control center
     * Date: 17/02/2026
     * Created By: Karan Singh
     */
    goBackToControlCenter() {
        if (this.parentComponentTitle) {
            this.goToParentComponent();
        } else {
            this.goToControlCenter();
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
            'Lead Assignment Rules',
            'The "Lead Assignment Rule" modal allows users to configure lead assignment rules, enabling automatic distribution of leads based on custom criteria. Set up intelligent routing to ensure leads reach the right team members efficiently.'
        );
    }

    /**
     * Method Name: generalIntegrationMethod
     * @description: Used to open storageIntegration component.
     * Date: 09/09/2024
     * Created By: Karan Singh
     */
    generalIntegrationMethod(event) {
        event.preventDefault();
        this.openComponent(
            'storageIntegration', 
            'Integration Hub',
            'The "Integration Hub" modal simplifies storage, email, outlook, instagram integration by providing seamless connectivity with various third-party services, enhancing overall functionality and user experience. Connect your favorite tools and platforms in one centralized location.'
        );
    }

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
     * Method Name: templateBuilderMethod
     * @description: Used to open templateHomePage component.
     * Date: 09/09/2024
     * Created By: Karan Singh
     */
    templateBuilderMethod(event) {
        event.preventDefault();
        let componentDef = {
            componentDef: "MVEX:templateHomePage"
        };

        let encodedComponentDef = btoa(JSON.stringify(componentDef));
        this[NavigationMixin.Navigate]({
            type: "standard__webPage",
            attributes: {
                url: "/one/one.app#" + encodedComponentDef
            }
        });
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
        
        // Store portal parameters
        this.portalId = portalId;
        this.portalGen = portalGen;
        this.portalName = portalName;
        this.portalIconUrl = portalIconUrl;
        this.portalStatus = portalStatus;
        this.isXMLForPF = isXMLForPF;
        
        // Set parent component for breadcrumb
        this.parentComponentTitle = 'Portal Integration';
        
        // Navigate to landing page
        this.selectedComponent = 'portalMappingLandingPage';
        this.selectedComponentTitle = portalName;
        this.currentView = 'childComponent';
    }

    /**
     * Method Name: whatsappEmbeddedSignuprMethod
     * @description: Used to open WhatsApp Embedded Signup.
     * Date: 09/09/2024
     * Created By: Karan Singh
     */
    whatsappEmbeddedSignuprMethod(event) {
        event.preventDefault();
        // For VF page, we still need to navigate
        this[NavigationMixin.Navigate]({
            type: "standard__webPage",
            attributes: {
                url: '/apex/MVEX__facebookSDK'
            }
        });
    }

    /**
     * Method Name: whatsappTemplateBuilderMethod
     * @description: Used to open WhatsApp template builder.
     * Date: 09/09/2024
     * Created By: Karan Singh
     */
    whatsappTemplateBuilderMethod(event) {
        event.preventDefault();
        let componentDef = {
            componentDef: "MVEX:wbAllTemplatePage"
        };

        let encodedComponentDef = btoa(JSON.stringify(componentDef));
        this[NavigationMixin.Navigate]({
            type: "standard__webPage",
            attributes: {
                url: "/one/one.app#" + encodedComponentDef
            }
        });
    }

    /**
     * Method Name: whatsappFlowBuilderMethod
     * @description: Used to open WhatsApp flow builder.
     * Date: 09/09/2024
     * Created By: Karan Singh
     */
    whatsappFlowBuilderMethod(event) {
        event.preventDefault();
        let componentDef = {
            componentDef: "MVEX:wbAllFlowsPage"
        };

        let encodedComponentDef = btoa(JSON.stringify(componentDef));
        this[NavigationMixin.Navigate]({
            type: "standard__webPage",
            attributes: {
                url: "/one/one.app#" + encodedComponentDef
            }
        });
    }

    objectConfigurationMethod(event) {
        event.preventDefault();
        this.openComponent(
            'objectConfigComp', 
            'Object Configuration',
            'The "Object Config" allows you to configure which objects and fields should be available when creating groups of members or sending email and WhatsApp messages from broadcast or campaign features, ensuring precise control over your marketing data structure.'
        );
    }
}