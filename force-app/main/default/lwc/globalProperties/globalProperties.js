import { LightningElement } from 'lwc';

/**
 * Use to execute debug log in proper format, 
 * to maintain debug format for error handling,
 * @param {*} componentName 
 * @param {*} methodName 
 * @param {*} error 
 * @param {*} debugMode 
 * @param {*} additionalInfo 
 */
export function errorDebugger(componentName, methodName, error, debugMode, additionalInfo) {
    const errorInfo = {}

    componentName && (errorInfo.component = componentName);
    methodName && (errorInfo.method = methodName);
    error?.message && (errorInfo.errorMessage = error?.message);
    additionalInfo && (errorInfo.additionalInfo = additionalInfo);

    if (debugMode?.toLowerCase() === 'error') {
        console.error('Error from EXP Component : ', errorInfo);
    }
    else if (debugMode?.toLowerCase() === 'warn') {
        console.warn('Warning from EXP Component : ', errorInfo);
    }
    else {
        console.log('Message from EXP Component : ', errorInfo);
    }
}

export default class GlobalProperties extends LightningElement {
// Default not in use
}