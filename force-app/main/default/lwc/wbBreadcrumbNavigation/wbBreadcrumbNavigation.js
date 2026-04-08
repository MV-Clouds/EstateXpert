/*
 * Component Name: WbBreadcrumbNavigation
 * @description: Reusable breadcrumb navigation component for hierarchical navigation
 * Date: 06/02/2026
 * Created By: Rachit Shah
 */
import { LightningElement, api } from 'lwc';

export default class WbBreadcrumbNavigation extends LightningElement {
    // Public properties to receive breadcrumb data from parent
    @api breadcrumbs = [];
    @api showBreadcrumbs = false;

    /**
     * Handle breadcrumb click event
     * Dispatches a custom event to parent component with the clicked path
     */
    handleBreadcrumbClick(event) {
        event.stopPropagation();
        const targetPath = event.currentTarget.dataset.path;
        
        // Dispatch custom event with path data to parent
        const breadcrumbClickEvent = new CustomEvent('breadcrumbclick', {
            detail: {
                path: targetPath
            }
        });
        this.dispatchEvent(breadcrumbClickEvent);
    }
}