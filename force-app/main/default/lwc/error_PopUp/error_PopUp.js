import { LightningElement, api, track } from 'lwc';
import errorImage from '@salesforce/resourceUrl/ErrorIcons'

export default class Error_PopUp extends LightningElement {
    @track isError = false;
    @track isSuccess = false;
    @track isWarning = false;
    @track iconUrl = errorImage + '/ErrorIcons/ErrorIcon.png';
    @track message = '';
    @track title = '';
    backGroundUrl = errorImage + '/ErrorIcons/ErrorPopUpBg.png';

    // connectedCallback(){
    //     if(this.isSuccess){
    //         this.iconUrl = errorImage + '/ErrorIcons/SuccessIcon.png';
    //         this.isSuccess = true;
    //     }else if(this.isError){
    //         this.isError = true;
    //     }else if(this.isWarning){
    //         this.isWarning = true;
    //         this.iconUrl = errorImage + '/ErrorIcons/WarningIcon.png';
    //     }
    // };

    /**
    * Method Name: showToast
    * @description: Method to display error, warning and success message as per conditions
    * Date: 12/06/2024
    * Created By: Mitrajsinh Gohil
    */
    @api
    showToast(type, message, title){
        try {
            if(type != undefined && message != undefined && title != undefined){
                this.message = message;
                this.title = title;
                if(type == 'success'){
                    this.iconUrl = errorImage + '/ErrorIcons/SuccessIcon.png';
                    this.isSuccess = true;
                }else if(type == 'error'){
                    this.isError = true;
                }else if(type == 'warning'){
                    this.isWarning = true;
                    this.iconUrl = errorImage + '/ErrorIcons/WarningIcon.png';
                }
            }
        } catch (error) {
            console.log('EX error_PopUp:- showToast Error');
        }
    }
    
    /**
    * Method Name: copyCode
    * @description: method to copy the unique code of error
    * Date: 12/06/2024
    * Created By: Mitrajsinh Gohil
    */
    copyCode() {
        // Copy code to clipboard
        var range = document.createRange();
        range.selectNode(this.template.querySelector(".copy"));
        window.getSelection().removeAllRanges(); // clear current selection
        window.getSelection().addRange(range); // to select text
        document.execCommand("copy");
        window.getSelection().removeAllRanges();// to deselect
    }

    /**
    * Method Name: cancel
    * @description: Method for closing the pop up using the custom event
    * Date: 12/06/2024
    * Created By: Mitrajsinh Gohil
    */
    cancel(){
        //Handle Cancel action
        console.log('Cancel button clicked');
        const event1 = CustomEvent('cancel');
        this.dispatchEvent(event1);
    }

    /**
    * Method Name: support
    * @description: Method for support redirect from the pop up using the custom event
    * Date: 12/06/2024
    * Created By: Mitrajsinh Gohil
    */
    support() {
        // Handle support action
        console.log('Support button clicked');
    }

    /**
    * Method Name: knowledge
    * @description: Method for knowledge redirect from the pop up using the custom event
    * Date: 12/06/2024
    * Created By: Mitrajsinh Gohil
    */
    knowledge() {
        // Handle knowledge action
        console.log('Knowledge button clicked');
    }
    
    /**
    * Method Name: resume
    * @description: Method for resuming the task and closing the pop up using the custom event
    * Date: 12/06/2024
    * Created By: Mitrajsinh Gohil
    */
    resume() {
        // Handle knowledge action
        console.log('Knowledge button clicked');
        const event1 = CustomEvent('continue');
        this.dispatchEvent(event1);
    }
    
}