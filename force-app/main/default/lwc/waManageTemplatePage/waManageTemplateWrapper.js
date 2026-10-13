/**
 * Method Name: buildPayload 
 * @description Constructs the complete payload object for creating or updating a WhatsApp template.
 */
function buildPayload(templateWrapper) {
    try {
        // Start with the top-level properties of the payload.
        const payload = {
            name: templateWrapper.templateName,
            language: templateWrapper.tempLanguage,
            category: (templateWrapper.templateCategory || 'MARKETING').toUpperCase()
        };

        // Add parameter_format based on variable type (Name = named, Number = positional)
        if (templateWrapper.selectedVariableType === 'Name') {
            payload.parameter_format = 'named';
        }

        // Build the 'components' array (header, body, footer, buttons) using a helper function.
        const components = buildMarketingOrUtilityComponents(templateWrapper);
        if (components.length > 0) {
            payload.components = components;
        }
        
        return payload;
    } catch (e) {
        console.error('Error in buildPayload:', e);
        return {};
    }
}

/**
 * Method Name: buildMarketingOrUtilityComponents 
 * @description Constructs the 'components' array for Marketing or Utility templates.
 */
function buildMarketingOrUtilityComponents(templateWrapper) {
    try {
        const components = [];

        // Build the HEADER component and add it if it's not empty.
        const headerComponent = buildHeaderComponent(templateWrapper);
        if (Object.keys(headerComponent).length > 0) {
            components.push(headerComponent);
        }

        // Build the BODY component if body text exists.
        if (templateWrapper.templateBody) {
            components.push(buildBodyComponent(templateWrapper));
        }

        // Build the FOOTER component with conditional logic.
        if (templateWrapper.tempFooterText) {
            components.push({
                type: 'FOOTER',
                text: templateWrapper.tempFooterText
            });
        }

        // Build the BUTTONS component if any buttons are defined.
        const buttonComponents = buildButtonComponent(templateWrapper);
        if (buttonComponents.length > 0) {
            components.push({
                type: 'BUTTONS',
                buttons: buttonComponents
            });
        }

        return components;
    } catch (e) {
        console.error('Error in buildMarketingOrUtilityComponents:', e);
        return [];
    }
}

/**
 * Method Name: buildHeaderComponent 
 * @description Constructs the HEADER component object.
 */
function buildHeaderComponent(templateWrapper) {
    const headerComponent = {};
    try {
        // If there's no header format specified, return an empty object.
        if (!templateWrapper.tempHeaderFormat || templateWrapper.tempHeaderFormat === 'None') {
            return headerComponent;
        }

        headerComponent.type = 'HEADER';
        headerComponent.format = templateWrapper.tempHeaderFormat.toUpperCase();

        // Handle TEXT format headers, including example text if provided.
        if (templateWrapper.tempHeaderFormat === 'Text' && templateWrapper.tempHeaderText) {
            headerComponent.text = templateWrapper.tempHeaderText;
            if (templateWrapper.tempHeaderExample && templateWrapper.tempHeaderExample.length > 0) {
                // For Name type (named parameters), use header_text_named_params format
                if (templateWrapper.selectedVariableType === 'Name') {
                    // Extract variable names from header text
                    const variablePattern = /\{\{([a-zA-Z_][a-zA-Z0-9_]*)\}\}/g;
                    const matches = [...templateWrapper.tempHeaderText.matchAll(variablePattern)];
                    
                    if (matches.length > 0) {
                        // Build header_text_named_params array using alternateText from variable objects
                        const namedParams = matches.map((match) => {
                            const paramName = match[1];
                            const variable = templateWrapper.header_variables?.find(v => v.nameValue === paramName);
                            const exampleValue = variable?.alternateText?.trim() || '';
                            if (!exampleValue) {
                                console.error(`Header variable "${paramName}" has no example value`);
                            }
                            return {
                                param_name: paramName,
                                example: exampleValue
                            };
                        });
                        
                        headerComponent.example = {
                            header_text_named_params: namedParams
                        };
                    }
                } else {
                    // For Number type (positional parameters), use header_text format
                    headerComponent.example = {
                        header_text: templateWrapper.tempHeaderExample
                    };
                }
            }
        // Handle MEDIA format headers (Image, Video, Document) by providing the media handle.
        } else if (['Image', 'Video', 'Document'].includes(templateWrapper.tempHeaderFormat) && templateWrapper.tempHeaderHandle) {
            headerComponent.example = {
                header_handle: [templateWrapper.tempHeaderHandle]
            };
        }
    } catch (e) {
        console.error('Error in buildHeaderComponent:', e);
    }
    return headerComponent;
}

/**
 * Method Name: buildBodyComponent 
 * @description Constructs the BODY component object.
 */
function buildBodyComponent(templateWrapper) {
    try {
        let bodyComponent = { type: 'BODY' };

        bodyComponent.text = templateWrapper.templateBody.replace(/\\n/g, '\n');
        
        // Add example text for variables if provided.
        if (templateWrapper.templateBodyText && templateWrapper.templateBodyText.length > 0) {
            // For Name type (named parameters), use body_text_named_params format
            if (templateWrapper.selectedVariableType === 'Name') {
                // Extract variable names from the body text
                const variablePattern = /\{\{([a-zA-Z_][a-zA-Z0-9_]*)\}\}/g;
                const matches = [...templateWrapper.templateBody.matchAll(variablePattern)];
                
                if (matches.length > 0) {
                    // Build body_text_named_params array using alternateText from variable objects
                    const namedParams = matches.map((match) => {
                        const paramName = match[1];
                        const variable = templateWrapper.variables?.find(v => v.nameValue === paramName);
                        const exampleValue = variable?.alternateText?.trim() || '';
                        if (!exampleValue) {
                            console.error(`Body variable "${paramName}" has no example value`);
                        }
                        return {
                            param_name: paramName,
                            example: exampleValue
                        };
                    });
                    
                    bodyComponent.example = {
                        body_text_named_params: namedParams
                    };
                }
            } else {
                // For Number type (positional parameters), use body_text format
                bodyComponent.example = {
                    body_text: [templateWrapper.templateBodyText]
                };
            }
        }

        return bodyComponent;
    } catch (e) {
        console.error('Error in buildBodyComponent:', e);
        return {};
    }
}

/**
 * Method Name: buildButtonComponent 
 * @description Constructs the BUTTONS component array.
 */
function buildButtonComponent(templateWrapper) {
    const buttonComponents = [];

    try {
        if (!templateWrapper.typeOfButton) return buttonComponents;

        const untypedList = JSON.parse(templateWrapper.typeOfButton);

        for (const item of untypedList) {
            const actionType = item.selectedActionType;
            const customActionType = item.selectedCustomType;
            const buttonComponent = {};

            if (actionType === 'PHONE_NUMBER') {
                const phoneNumber = `${item.selectedCountryType} ${item.phonenum}`;
                Object.assign(buttonComponent, {
                    type: 'PHONE_NUMBER',
                    text: item.btntext,
                    phone_number: phoneNumber
                });
            } else if (['QUICK_REPLY', 'Marketing opt-out'].includes(customActionType)) {
                Object.assign(buttonComponent, {
                    type: 'QUICK_REPLY',
                    text: item.Cbtntext
                });
                if (customActionType === 'Marketing opt-out') {
                    templateWrapper.marketingOptText = item.Cbtntext;
                }
            } else if (actionType === 'URL') {
                Object.assign(buttonComponent, {
                    type: 'URL',
                    text: item.btntext,
                    url: item.webURL
                });
            }

            if (Object.keys(buttonComponent).length > 0) {
                buttonComponents.push(buttonComponent);
            }
        }
    } catch (e) {
        console.error('Error in buildButtonComponent:', e);
    }

    return buttonComponents;
}

// Export the main builder function as the default export of this module.
export default buildPayload;