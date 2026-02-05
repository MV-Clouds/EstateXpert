import { LightningElement, track, wire } from "lwc";
import MulishFontCss from "@salesforce/resourceUrl/MulishFontCss";
import { NavigationMixin } from "lightning/navigation";
import { loadStyle } from "lightning/platformResourceLoader";
import getMetadataRecords from "@salesforce/apex/ControlCenterController.getMetadataRecords";
export default class EstateXpertControlCenter extends NavigationMixin(LightningElement) {
    @track featureAvailability = {};
    @track isLoading = true;

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
        return !this.featureAvailability?.Cloud_Storage_Integration &&
            !this.featureAvailability?.Email_Integration &&
            !this.featureAvailability?.Social_Media_Integration &&
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
    /**
     * Method Name: connectedCallback
     * @description: Used to load css styles.
     * Date: 09/09/2024
     * Created By: Karan Singh
     */
    connectedCallback() {
        loadStyle(this, MulishFontCss)
            .then(() => {
                console.log("Css loaded successfully");
            })
            .catch((error) => {
                console.log("Error loading style:", error);
            });
    }

    /**
     * Method Name: mapListingAndPropertyMethod
     * @description: Used to open mapFields component.
     * Date: 09/09/2024
     * Created By: Karan Singh
     */
    mapListingAndPropertyMethod(event) {
        event.preventDefault();
        let componentDef = {
            componentDef: "MVEX:mapFields"
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
     * @description: Used to open portalMapping component.
     * Date: 09/09/2024
     * Created By: Karan Singh
     */
    portalIntegrationMethod(event) {
        event.preventDefault();
        let componentDef = {
            componentDef: "MVEX:portalMappingComponent"
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
     * Method Name: leadAssignmentRule
     * @description: Used to open supportRequestCmp component.
     * Date: 09/09/2024
     * Created By: Karan Singh
     */
    leadAssignmentRule(event) {
        event.preventDefault();
        let componentDef = {
            componentDef: "MVEX:leadAssignmentRule"
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
     * Method Name: mapListingAndInquiryMethod
     * @description: Used to open mappingComponent component.
     * Date: 09/09/2024
     * Created By: Karan Singh
     */
    mapListingAndInquiryMethod(event) {
        event.preventDefault();
        let componentDef = {
            componentDef: "MVEX:mappingComponent"
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
     * Method Name: emailIntegrationMethod
     * @description: Used to open emailIntegration component.
     * Date: 09/09/2024
     * Created By: Karan Singh
     */
    emailIntegrationMethod(event) {
        event.preventDefault();
        let componentDef = {
            componentDef: "MVEX:emailIntegration"
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
     * Method Name: cloudStorageIntegrationMethod
     * @description: Used to open storageIntegration component.
     * Date: 09/09/2024
     * Created By: Karan Singh
     */
    cloudStorageIntegrationMethod(event) {
        event.preventDefault();
        let componentDef = {
            componentDef: "MVEX:storageIntegration"
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
     * Method Name: socialMediaIntegrationMethod
     * @description: Used to open Social Media integration component.
     * Date: 09/09/2024
     * Created By: Karan Singh
     */
    socialMediaIntegrationMethod(event) {
        event.preventDefault();
        let componentDef = {
            componentDef: "MVEX:socialMediaIntegration"
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
     * Method Name: marketingCampaignMethod
     * @description: Used to open displayCampaigns component.
     * Date: 09/09/2024
     * Created By: Karan Singh
     */
    marketingCampaignMethod(event) {
        event.preventDefault();
        let componentDef = {
            componentDef: "MVEX:displayCampaigns"
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
     * Method Name: whatsappBroadcastMethod
     * @description: Used to open broadcastMessageComp component.
     * Date: 09/09/2024
     * Created By: Karan Singh
     */
    whatsappBroadcastMethod(event) {
        event.preventDefault();
        let componentDef = {
            componentDef: "MVEX:broadcastMessageComp"
        };

        let encodedComponentDef = btoa(JSON.stringify(componentDef));
        this[NavigationMixin.Navigate]({
            type: "standard__webPage",
            attributes: {
                url: "/one/one.app#" + encodedComponentDef
            }
        });
    }

    whatsappEmbeddedSignuprMethod(event) {
        event.preventDefault();
        
        this[NavigationMixin.Navigate]({
            type: "standard__webPage",
            attributes: {
                url: '/apex/facebookSDK'
            }
        });
    }

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

    leadCaptureMethod() {
        let componentDef = {
            componentDef: "MVEX:leadCaptureCmp"
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
        let componentDef = {
            componentDef: "MVEX:objectConfigComp"
        };

        let encodedComponentDef = btoa(JSON.stringify(componentDef));
        this[NavigationMixin.Navigate]({
            type: "standard__webPage",
            attributes: {
                url: "/one/one.app#" + encodedComponentDef
            }
        });
    }
}