function buildPayload(templateWrapper) {
    try {
        const payload = {
            name: templateWrapper.templateName,
            language: templateWrapper.tempLanguage,
            category: templateWrapper.templateCategory
        };

        const components = buildMarketingOrUtilityComponents(templateWrapper);
        if (components.length > 0) {
            payload.components = components;
        }

        if (templateWrapper.templateCategory === 'Authentication' || templateWrapper.templateCategory === 'Utility') {
            payload.message_send_ttl_seconds = templateWrapper.expireTime || 300;
        }
        
        return payload;
    } catch (e) {
        logException('buildPayload', e);
        return {};
    }
}

function buildMarketingOrUtilityComponents(templateWrapper) {
    try {
        const components = [];

        const headerComponent = buildHeaderComponent(templateWrapper);
        if (Object.keys(headerComponent).length > 0) {
            components.push(headerComponent);
        }

        if (templateWrapper.templateBody) {
            components.push(buildBodyComponent(templateWrapper));
        }

        if (templateWrapper.tempFooterText) {
            components.push({
                type: 'FOOTER',
                text: templateWrapper.tempFooterText
            });
        } else if (templateWrapper.templateCategory === 'Authentication' && templateWrapper.isCodeExpiration) {
            const expirationMinutes = Math.floor(templateWrapper.expireTime / 60);
            components.push({
                type: 'FOOTER',
                code_expiration_minutes: expirationMinutes
            });
        }

        const buttonComponents = buildButtonComponent(templateWrapper);
        if (buttonComponents.length > 0) {
            components.push({
                type: 'BUTTONS',
                buttons: buttonComponents
            });
        }

        return components;
    } catch (e) {
        logException('buildMarketingOrUtilityComponents', e);
        return [];
    }
}

function buildHeaderComponent(templateWrapper) {
    const headerComponent = {};

    try {
        if (!templateWrapper.tempHeaderFormat || templateWrapper.tempHeaderFormat === 'None') {
            return headerComponent;
        }

        headerComponent.type = 'HEADER';
        headerComponent.format = templateWrapper.tempHeaderFormat;

        if (templateWrapper.tempHeaderFormat === 'Text' && templateWrapper.tempHeaderText) {
            headerComponent.text = templateWrapper.tempHeaderText;
            if (templateWrapper.tempHeaderExample && templateWrapper.tempHeaderExample.length > 0) {
                headerComponent.example = {
                    header_text: templateWrapper.tempHeaderExample
                };
            }
        } else if (
            ['Image', 'Video', 'Document'].includes(templateWrapper.tempHeaderFormat) &&
            templateWrapper.tempHeaderHandle
        ) {
            headerComponent.example = {
                header_handle: templateWrapper.tempHeaderHandle
            };
        }
    } catch (e) {
        logException('buildHeaderComponent', e);
    }

    return headerComponent;
}

function buildBodyComponent(templateWrapper) {
    try {
        let bodyComponent = {
            type: 'BODY'
        };

        if (templateWrapper.templateCategory === 'Authentication') {
            bodyComponent.add_security_recommendation = templateWrapper.isSecurityRecommedation;
        } else {
            bodyComponent.text = templateWrapper.templateBody.replace(/\\n/g, '\n');
        }

        if (templateWrapper.templateBodyText && templateWrapper.templateBodyText.length > 0) {
            bodyComponent.example = {
                body_text: [templateWrapper.templateBodyText]
            };
        }

        return bodyComponent;
    } catch (e) {
        logException('buildBodyComponent', e);
        return {};
    }
}

function buildButtonComponent(templateWrapper) {
    const buttonComponents = [];

    try {
        if (templateWrapper.templateCategory === 'Authentication') {
            buttonComponents.push({
                type: 'OTP',
                text: 'Verify Code',
                otp_type: 'COPY_CODE'
            });
            return buttonComponents;
        }

        if (!templateWrapper.typeOfButton) return buttonComponents;

        const untypedList = JSON.parse(templateWrapper.typeOfButton);

        for (const item of untypedList) {
            const actionType = item.selectedActionType;
            const customActionType = item.selectedCustomType;
            const phoneNumber = `${item.selectedCountryType} ${item.phonenum}`;
            const buttonComponent = {};

            if (actionType === 'PHONE_NUMBER') {
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
            } else if (actionType === 'COPY_CODE') {
                Object.assign(buttonComponent, {
                    type: 'COPY_CODE',
                    text: 'Copy offer code',
                    example: item.offercode
                });
            } else if (actionType === 'FLOW') {
                const selectedFlowMap = JSON.parse(templateWrapper.selectedFlow);
                Object.assign(buttonComponent, {
                    type: 'FLOW',
                    text: item.btntext,
                    flow_id: selectedFlowMap.id
                });
            }
            else if (actionType === 'CATALOG') {
                // const selectedFlowMap = JSON.parse(templateWrapper.selectedFlow);
                Object.assign(buttonComponent, {
                    type: 'CATALOG',
                    text: item.btntext
                });
            }
            else if (actionType === 'MPM') {
                // const selectedFlowMap = JSON.parse(templateWrapper.selectedFlow);
                Object.assign(buttonComponent, {
                    type: 'MPM',
                    text: item.btntext
                });
            }

            if (Object.keys(buttonComponent).length > 0) {
                buttonComponents.push(buttonComponent);
            }
        }

    } catch (e) {
        logException('buildButtonComponent', e);
    }

    return buttonComponents;
}

// Simple logger simulating Apex ExceptionHandler
function logException(methodName, error) {
    console.error(`[ERROR] ${methodName}:`, error.message || error);
}

export default buildPayload;