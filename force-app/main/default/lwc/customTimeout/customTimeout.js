import { LightningElement,api } from 'lwc';
import {errorDebugger} from 'c/globalProperties';

export default class CustomTimeout extends LightningElement {

    customSetTimeout;
    customSetTimeoutMethod;
    customTimeoutProcessList = [];
    usedTimeoutProcessNumber = [];

    // === === === === Custom Timeout Methods -- START --- === === === ====

    @api
    setCustomTimeoutMethod(methodToRun, delayTime){
        try {
            let maxTimeoutProcesses = 10
            if(this.customTimeoutProcessList.length < maxTimeoutProcesses){
                const timeoutProcessInstance = {
                    // ** Add Method into variable which you want run after timeout...
                    delay : delayTime,
                    method : methodToRun,
                    name : `customSetTimeout${this.setProcessNumber()}`,
                    processNumber : this.setProcessNumber(),
                }
                
                this.customTimeoutProcessList.push(timeoutProcessInstance);
                this.addedEventListener(timeoutProcessInstance);
            }
            else{
                console.warn('you have reach maximum limit of custom settimeout')
            }

        } catch (error) {
            errorDebugger('CustomTimeout', 'setCustomTimeoutMethod', error, 'warn');
        }
    }

    addedEventListener(method){
        try {
            const customSetTimeoutDiv = this.template.querySelector(`[data-name="${method.name}"]`);
            if(customSetTimeoutDiv){
                customSetTimeoutDiv.addEventListener('animationend', this.executeTimeoutMethod);

                // ** Add setTimeout time into CSS variable...
                customSetTimeoutDiv.style.setProperty('--timeoutTime', `${method.delay}ms`);
                // ** Add css class to start timeout animation.. at end of this animation, settimeout method will run....
                customSetTimeoutDiv.classList.add('setTimeAnimation');
            }
        } catch (error) {
            errorDebugger('CustomTimeout', 'addedEventListener', error, 'warn');
        }
    }

    // Use Arrow Function for EventListener Method....
    executeTimeoutMethod = (event) =>{
        try {
            // ** This method will at the end of the animation...
            let processNumber;
            this.customTimeoutProcessList.forEach(ele =>{
                if(ele.name === event.target.dataset.name){
                    // ** Remove eventLister and animation class once method run...
                    event.target.removeEventListener('animationend', null);
                    event.target.classList.remove('setTimeAnimation');
                    processNumber = ele.processNumber;

                    // ** Run Timeout method...
                    // ele.method();
                    this.dispatchEvent(new CustomEvent('timeoutmethod', 
                        {detail : {
                            function : ele.method,
                        }}
                    ));
                }
            });

            this.customTimeoutProcessList = this.customTimeoutProcessList.filter(ele => ele.processNumber !== processNumber);
            this.usedTimeoutProcessNumber = this.usedTimeoutProcessNumber.filter(ele => ele !== processNumber);

        } catch (error) {
            errorDebugger('CustomTimeout', 'executeTimeoutMethod', error, 'warn');
        }
    }

    setProcessNumber(){
        try {
            if(!this.usedTimeoutProcessNumber.includes(this.customTimeoutProcessList.length)){
                this.usedTimeoutProcessNumber.push(this.customTimeoutProcessList.length);
                return this.customTimeoutProcessList.length;
            }
            else{
                for(let i = 0; i < 9; i++){
                    if(!this.usedTimeoutProcessNumber.includes(i)){
                        this.usedTimeoutProcessNumber.push(i);
                        return i;
                    }
                }
            }
        } catch (error) {
            errorDebugger('CustomTimeout', 'setProcessNumber', error, 'warn');
        }
        return 0;
    }

    // === === === === Custom Timeout Methods -- END --- === === === ====

}