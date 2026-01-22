import { LightningElement } from 'lwc';

/******************************************
* 
* Purpose of used this component to export method and variable(properties) to use them globally every where in any component...
* So, in future if we need to make changes in below method or variable, then we do not need change in every component one by one,
* Change at here will reflect every where, where this is following export properties are used...
*
*******************************************/

/**
 * name space change globally after packed building,
 * used for navigation...
 */
export var nameSpace = 'MVEX';


/**
 * To Define Component Name Globally, Used in Navigation.
 */
export var navigationComps = {
    simpleTemplateBuilder: 'templateEditor',
    csvTemplateBuilder: 'editCSVTemplate',
    dNdTemplateBuilder: 'editDragDropTemplate',
    home: 'templateHomePage',
    googleDocTemplateEditor: 'googleDocTemplateEditor',
}


/**
 * Key Mapping Symbol,
 * Used to extract mapping keys,
 */
export var mappingSymbols = {
    object: '#',
    generalField: 'Doc.',
    mergeTemplate: 'Temp.',
    childObjectField: '!'
}

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
        console.error('Error from DG Component : ', errorInfo);
    }
    else if (debugMode?.toLowerCase() === 'warn') {
        console.warn('Warning from DG Component : ', errorInfo);
    }
    else {
        console.log('Message from DG Component : ', errorInfo);
    }
}

export default class GlobalProperties extends LightningElement {


}

/**
 * custom icon svg and path,
 * used in summernote editor, that used in simple template builder,
 */
export var customeIcons = {
    dgPreview: `<svg class="previewBtn" onclick={handlePreviewTemplate} viewBox="0 0 32.00 32.00" transform="matrix(1, 0, 0, 1, 0, 0)rotate(0)"><g stroke-width="0"></g><g stroke-linecap="round" stroke-linejoin="round"></g><g><defs></defs><title>document--view</title><circle cx="22" cy="24" r="2"></circle><path id="_inner_path_" data-name="<inner path>" class="cls-1" style="fill: none;" d="M22,28a4,4,0,1,1,4-4A4.0039,4.0039,0,0,1,22,28Zm0-6a2,2,0,1,0,2,2A2.0027,2.0027,0,0,0,22,22Z"></path><path d="M29.7769,23.4785A8.64,8.64,0,0,0,22,18a8.64,8.64,0,0,0-7.7769,5.4785L14,24l.2231.5215A8.64,8.64,0,0,0,22,30a8.64,8.64,0,0,0,7.7769-5.4785L30,24ZM22,28a4,4,0,1,1,4-4A4.0045,4.0045,0,0,1,22,28Z"></path><path d="M12,28H8V4h8v6a2.0058,2.0058,0,0,0,2,2h6v4h2V10a.9092.9092,0,0,0-.3-.7l-7-7A.9087.9087,0,0,0,18,2H8A2.0058,2.0058,0,0,0,6,4V28a2.0058,2.0058,0,0,0,2,2h4ZM18,4.4,23.6,10H18Z"></path><rect data-name="<Transparent Rectangle>" class="cls-1" style="fill: none;" width="32" height="32"></rect></g></svg>`,

    table: `<svg class="customIcon" stroke-linecap="round" stroke-linejoin="round" stroke-width="1" viewBox="0 0 24 24"><path d="M3 6v12a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6a2 2 0 0 0-2-2H5a2 2 0 0 0-2 2Z"></path><path d="M3 8h18"></path><path d="M21 14H3"></path><path d="M15 8v12"></path><path d="M9 8v12"></path></svg>`,
    table2: `<svg viewBox="0 0 24 24" class="remixicon"><path d="M4 8H20V5H4V8ZM14 19V10H10V19H14ZM16 19H20V10H16V19ZM8 19V10H4V19H8ZM3 3H21C21.5523 3 22 3.44772 22 4V20C22 20.5523 21.5523 21 21 21H3C2.44772 21 2 20.5523 2 20V4C2 3.44772 2.44772 3 3 3Z"></path></svg>`,
    table3: `<svg class="svgRepo" viewBox="0 0 24 24"><g id="SVGRepo_bgCarrier" stroke-width="0"></g><g id="SVGRepo_tracerCarrier" stroke-linecap="round" stroke-linejoin="round"></g><g id="SVGRepo_iconCarrier"> <path d="M3 9H21M3 15H21M9 9L9 20M15 9L15 20M6.2 20H17.8C18.9201 20 19.4802 20 19.908 19.782C20.2843 19.5903 20.5903 19.2843 20.782 18.908C21 18.4802 21 17.9201 21 16.8V7.2C21 6.0799 21 5.51984 20.782 5.09202C20.5903 4.71569 20.2843 4.40973 19.908 4.21799C19.4802 4 18.9201 4 17.8 4H6.2C5.0799 4 4.51984 4 4.09202 4.21799C3.71569 4.40973 3.40973 4.71569 3.21799 5.09202C3 5.51984 3 6.07989 3 7.2V16.8C3 17.9201 3 18.4802 3.21799 18.908C3.40973 19.2843 3.71569 19.5903 4.09202 19.782C4.51984 20 5.07989 20 6.2 20Z" stroke="#000000" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"></path> </g></svg>`,

    image: `<svg class="customIcon2" viewBox="0 0 24 24">
              <path d="M14.25 10.5a2.25 2.25 0 1 0 0-4.5 2.25 2.25 0 0 0 0 4.5Zm0-3a.75.75 0 1 1 0 1.5.75.75 0 0 1 0-1.5Z"></path>
              <path d="M19.5 3h-15A1.5 1.5 0 0 0 3 4.5v15A1.5 1.5 0 0 0 4.5 21h15a1.5 1.5 0 0 0 1.5-1.5v-15A1.5 1.5 0 0 0 19.5 3Zm0 16.5h-15V15l3.75-3.75 4.193 4.193a1.5 1.5 0 0 0 2.114 0l1.193-1.193L19.5 18v1.5Zm0-3.623-2.692-2.692a1.5 1.5 0 0 0-2.115 0L13.5 14.377l-4.193-4.192a1.5 1.5 0 0 0-2.115 0L4.5 12.877V4.5h15v11.377Z"></path>
          </svg>`,
    image2: `<svg viewBox="0 0 24 24" class="remixicon"><path d="M21 15V18H24V20H21V23H19V20H16V18H19V15H21ZM21.0082 3C21.556 3 22 3.44495 22 3.9934V13H20V5H4V18.999L14 9L17 12V14.829L14 11.8284L6.827 19H14V21H2.9918C2.44405 21 2 20.5551 2 20.0066V3.9934C2 3.44476 2.45531 3 2.9918 3H21.0082ZM8 7C9.10457 7 10 7.89543 10 9C10 10.1046 9.10457 11 8 11C6.89543 11 6 10.1046 6 9C6 7.89543 6.89543 7 8 7Z"></path></svg>`,

    bold: `<svg class="customIcon" stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" viewBox="0 0 24 24">
              <path d="M13 6H6v6h7a3 3 0 0 0 0-6Zm2 6H6v6h9a3 3 0 0 0 0-6v0Z"></path>
          </svg>`,
    bold2: `<svg viewBox="0 0 24 24" class="remixicon"><path d="M8 11H12.5C13.8807 11 15 9.88071 15 8.5C15 7.11929 13.8807 6 12.5 6H8V11ZM18 15.5C18 17.9853 15.9853 20 13.5 20H6V4H12.5C14.9853 4 17 6.01472 17 8.5C17 9.70431 16.5269 10.7981 15.7564 11.6058C17.0979 12.3847 18 13.837 18 15.5ZM8 13V18H13.5C14.8807 18 16 16.8807 16 15.5C16 14.1193 14.8807 13 13.5 13H8Z"></path></svg>`,
    bold3: `<svg class="svgRepo" viewBox="0 0 20 20"><g id="SVGRepo_bgCarrier" stroke-width="0"></g><g id="SVGRepo_tracerCarrier" stroke-linecap="round" stroke-linejoin="round"></g><g id="SVGRepo_iconCarrier"> <path fill="#000000" fill-rule="evenodd" d="M4 1a1 1 0 00-1 1v16a1 1 0 001 1v-1 1h8a5 5 0 001.745-9.687A5 5 0 0010 1H4zm6 8a3 3 0 100-6H5v6h5zm-5 2v6h7a3 3 0 100-6H5z"></path> </g></svg>`,


    italic: `<svg class="customIcon" stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" viewBox="0 0 24 24">
              <path d="M10 18H6m4-12h4-4Zm8 0h-4 4Zm-4 0-4 12 4-12Zm-4 12h4-4Z"></path>
          </svg>`,
    italic2: `<svg viewBox="0 0 24 24" class="remixicon"><path d="M15 20H7V18H9.92661L12.0425 6H9V4H17V6H14.0734L11.9575 18H15V20Z"></path></svg>`,

    underline: `<svg class="customIcon" stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" viewBox="0 0 24 24">
                  <path d="M15.5 12h-7M5 19h14H5Zm2-4 1.5-3L7 15Zm10 0-1.5-3 1.5 3Zm-1.5-3L12 5l-3.5 7h7Z"></path>
              </svg>`,
    underline2: `<svg viewBox="0 0 24 24" class="remixicon"><path d="M8 3V12C8 14.2091 9.79086 16 12 16C14.2091 16 16 14.2091 16 12V3H18V12C18 15.3137 15.3137 18 12 18C8.68629 18 6 15.3137 6 12V3H8ZM4 20H20V22H4V20Z"></path></svg>`,

    strikethrough: `<svg class="customIcon" stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" viewBox="0 0 24 24">
                      <path d="M17 5h-7a3 3 0 0 0-3 3v1a3 3 0 0 0 3 3"></path>
                      <path d="M7 19h7a3 3 0 0 0 3-3v-1"></path>
                      <path d="M5 12h14"></path>
                  </svg>`,
    strikethrough2: `<svg viewBox="0 0 24 24" class="remixicon"><path d="M17.1538 14C17.3846 14.5161 17.5 15.0893 17.5 15.7196C17.5 17.0625 16.9762 18.1116 15.9286 18.867C14.8809 19.6223 13.4335 20 11.5862 20C9.94674 20 8.32335 19.6185 6.71592 18.8555V16.6009C8.23538 17.4783 9.7908 17.917 11.3822 17.917C13.9333 17.917 15.2128 17.1846 15.2208 15.7196C15.2208 15.0939 15.0049 14.5598 14.5731 14.1173C14.5339 14.0772 14.4939 14.0381 14.4531 14H3V12H21V14H17.1538ZM13.076 11H7.62908C7.4566 10.8433 7.29616 10.6692 7.14776 10.4778C6.71592 9.92084 6.5 9.24559 6.5 8.45207C6.5 7.21602 6.96583 6.165 7.89749 5.299C8.82916 4.43299 10.2706 4 12.2219 4C13.6934 4 15.1009 4.32808 16.4444 4.98426V7.13591C15.2448 6.44921 13.9293 6.10587 12.4978 6.10587C10.0187 6.10587 8.77917 6.88793 8.77917 8.45207C8.77917 8.87172 8.99709 9.23796 9.43293 9.55079C9.86878 9.86362 10.4066 10.1135 11.0463 10.3004C11.6665 10.4816 12.3431 10.7148 13.076 11H13.076Z"></path></svg>`,
    // Note --  For Color Pallet Buttons, Do not Forget to add 'note-recent-color'....
    fontColor: `<svg class="customIcon2 colorFormate note-recent-color" viewBox="0 0 24 24">
                  <path d="M16.5 15.75H18L12.75 3h-1.5L6 15.75h1.5l1.207-3h6.555l1.238 3Zm-7.178-4.5 2.58-6.277h.196l2.557 6.277H9.323Z"></path>
                  <path d="M19.5 18h-15v3h15v-3Z"></path>
              </svg>`,
    fontColor2: `<svg viewBox="0 0 24 24" class="remixicon colorFormate note-recent-color"><path d="M15.2459 14H8.75407L7.15407 18H5L11 3H13L19 18H16.8459L15.2459 14ZM14.4459 12L12 5.88516L9.55407 12H14.4459ZM3 20H21V22H3V20Z"></path></svg>`,

    clearFormat: `<svg class="customIcon2" viewBox="0 0 24 24" >
                  <path d="m15 18.9 1.05 1.05 2.4-2.4 2.4 2.4 1.2-1.05-2.55-2.4 2.55-2.4-1.2-1.2-2.4 2.55-2.4-2.55L15 14.1l2.4 2.4-2.4 2.4ZM1.5 6h21V4.5h-21V6Zm0 4.5h21V9h-21v1.5Zm12 3.75v-.75h-12V15h12v-.75Zm0 5.25V18h-12v1.5h12Z"></path>
              </svg>`,
    clearFormat2: `<svg viewBox="0 0 24 24" class="remixicon"><path d="M12.6512 14.0654L11.6047 20H9.57389L10.9247 12.339L3.51465 4.92892L4.92886 3.51471L20.4852 19.0711L19.071 20.4853L12.6512 14.0654ZM11.7727 7.53009L12.0425 5.99999H10.2426L8.24257 3.99999H19.9999V5.99999H14.0733L13.4991 9.25652L11.7727 7.53009Z"></path></svg>`,

    fullScreen: `<svg class="customIcon" stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" viewBox="0 0 24 24">
                  <path d="m5 19 4-4m6 4h4-4Zm4 0v-4 4Zm0 0-4-4 4 4ZM9 5H5h4ZM5 5v4-4Zm0 0 4 4-4-4Zm10 0h4-4Zm4 0v4-4Zm0 0-4 4 4-4ZM9 19H5h4Zm-4 0v-4 4Z"></path>
              </svg>`,
    fullScreen2: `<svg viewBox="0 0 24 24" class="remixicon"><path d="M8 3V5H4V9H2V3H8ZM2 21V15H4V19H8V21H2ZM22 21H16V19H20V15H22V21ZM22 9H20V5H16V3H22V9Z"></path></svg>`,

    lineHeight: `<svg class="customIcon" stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" viewBox="0 0 24 24" >
                  <path d="M12 17h8M6 10V5v5Zm0-5L4 7l2-2Zm0 0 2 2-2-2Zm0 9v5-5Zm0 5 2-2-2 2Zm0 0-2-2 2 2Zm6-12h8-8Zm8 5h-8 8Z"></path>
              </svg>`,
    lineHeight2: `<svg viewBox="0 0 24 24" class="remixicon"><path d="M11 4H21V6H11V4ZM6 7V11H4V7H1L5 3L9 7H6ZM6 17H9L5 21L1 17H4V13H6V17ZM11 18H21V20H11V18ZM9 11H21V13H9V11Z"></path></svg>`,
    subscript: `<svg viewBox="0 0 24 24" class="remixicon"><path d="M5.59567 4L10.5 9.92831L15.4043 4H18L11.7978 11.4971L18 18.9943V19H15.4091L10.5 13.0659L5.59092 19H3V18.9943L9.20216 11.4971L3 4H5.59567ZM21.8 16C21.8 15.5582 21.4418 15.2 21 15.2C20.5582 15.2 20.2 15.5582 20.2 16C20.2 16.0762 20.2107 16.15 20.2306 16.2198L19.0765 16.5496C19.0267 16.375 19 16.1906 19 16C19 14.8954 19.8954 14 21 14C22.1046 14 23 14.8954 23 16C23 16.5727 22.7593 17.0892 22.3735 17.4538L20.7441 19H23V20H19V19L21.5507 16.5803C21.7042 16.4345 21.8 16.2284 21.8 16Z"></path></svg>`,
    superscript: `<svg viewBox="0 0 24 24" class="remixicon"><path d="M5.59567 5L10.5 10.9283L15.4043 5H18L11.7978 12.4971L18 19.9943V20H15.4091L10.5 14.0659L5.59092 20H3V19.9943L9.20216 12.4971L3 5H5.59567ZM21.5507 6.5803C21.7042 6.43453 21.8 6.22845 21.8 6C21.8 5.55817 21.4418 5.2 21 5.2C20.5582 5.2 20.2 5.55817 20.2 6C20.2 6.07624 20.2107 6.14999 20.2306 6.21983L19.0765 6.54958C19.0267 6.37497 19 6.1906 19 6C19 4.89543 19.8954 4 21 4C22.1046 4 23 4.89543 23 6C23 6.57273 22.7593 7.08923 22.3735 7.45384L20.7441 9H23V10H19V9L21.5507 6.5803V6.5803Z"></path></svg>`,
    link: `<svg viewBox="0 0 24 24" class="remixicon"><path d="M17.6567 14.8284L16.2425 13.4142L17.6567 12C19.2188 10.4379 19.2188 7.90524 17.6567 6.34314C16.0946 4.78105 13.5619 4.78105 11.9998 6.34314L10.5856 7.75736L9.17139 6.34314L10.5856 4.92893C12.9287 2.58578 16.7277 2.58578 19.0709 4.92893C21.414 7.27208 21.414 11.0711 19.0709 13.4142L17.6567 14.8284ZM14.8282 17.6569L13.414 19.0711C11.0709 21.4142 7.27189 21.4142 4.92875 19.0711C2.5856 16.7279 2.5856 12.9289 4.92875 10.5858L6.34296 9.17157L7.75717 10.5858L6.34296 12C4.78086 13.5621 4.78086 16.0948 6.34296 17.6569C7.90506 19.2189 10.4377 19.2189 11.9998 17.6569L13.414 16.2426L14.8282 17.6569ZM14.8282 7.75736L16.2425 9.17157L9.17139 16.2426L7.75717 14.8284L14.8282 7.75736Z"></path></svg>`,
    unlink: `<svg viewBox="0 0 24 24" class="remixicon"><path d="M17 17H22V19H19V22H17V17ZM7 7H2V5H5V2H7V7ZM18.364 15.5355L16.9497 14.1213L18.364 12.7071C20.3166 10.7545 20.3166 7.58866 18.364 5.63604C16.4113 3.68342 13.2455 3.68342 11.2929 5.63604L9.87868 7.05025L8.46447 5.63604L9.87868 4.22183C12.6123 1.48816 17.0445 1.48816 19.7782 4.22183C22.5118 6.9555 22.5118 11.3877 19.7782 14.1213L18.364 15.5355ZM15.5355 18.364L14.1213 19.7782C11.3877 22.5118 6.9555 22.5118 4.22183 19.7782C1.48816 17.0445 1.48816 12.6123 4.22183 9.87868L5.63604 8.46447L7.05025 9.87868L5.63604 11.2929C3.68342 13.2455 3.68342 16.4113 5.63604 18.364C7.58866 20.3166 10.7545 20.3166 12.7071 18.364L14.1213 16.9497L15.5355 18.364ZM14.8284 7.75736L16.2426 9.17157L9.17157 16.2426L7.75736 14.8284L14.8284 7.75736Z"></path></svg>`,
    help: `<svg viewBox="0 0 24 24" class="remixicon"><path d="M12 22C6.47715 22 2 17.5228 2 12 2 6.47715 6.47715 2 12 2 17.5228 2 22 6.47715 22 12 22 17.5228 17.5228 22 12 22ZM12 20C16.4183 20 20 16.4183 20 12 20 7.58172 16.4183 4 12 4 7.58172 4 4 7.58172 4 12 4 16.4183 7.58172 20 12 20ZM13 10.5V15H14V17H10V15H11V12.5H10V10.5H13ZM13.5 8C13.5 8.82843 12.8284 9.5 12 9.5 11.1716 9.5 10.5 8.82843 10.5 8 10.5 7.17157 11.1716 6.5 12 6.5 12.8284 6.5 13.5 7.17157 13.5 8Z"></path></svg>`,
    rowcolor: `<svg viewBox="0 0 24 24" class="remixicon popoverIcon"><path d="M19.2277 18.7323L20.9955 16.9645L22.7632 18.7323C23.7395 19.7086 23.7395 21.2915 22.7632 22.2678C21.7869 23.2441 20.204 23.2441 19.2277 22.2678C18.2514 21.2915 18.2514 19.7086 19.2277 18.7323ZM8.87861 1.07971L20.1923 12.3934C20.5828 12.7839 20.5828 13.4171 20.1923 13.8076L11.707 22.2929C11.3165 22.6834 10.6833 22.6834 10.2928 22.2929L1.80754 13.8076C1.41702 13.4171 1.41702 12.7839 1.80754 12.3934L9.58572 4.61525L7.4644 2.49393L8.87861 1.07971ZM10.9999 6.02946L3.92886 13.1005L10.9999 20.1716L18.071 13.1005L10.9999 6.02946Z"></path></svg>`,
    cellColor: `<svg viewBox="0 0 24 24" class="remixicon popoverIcon"><path d="M19.2277 18.7323L20.9955 16.9645L22.7632 18.7323C23.7395 19.7086 23.7395 21.2915 22.7632 22.2678C21.7869 23.2441 20.204 23.2441 19.2277 22.2678C18.2514 21.2915 18.2514 19.7086 19.2277 18.7323ZM8.87861 1.07971L20.1923 12.3934C20.5828 12.7839 20.5828 13.4171 20.1923 13.8076L11.707 22.2929C11.3165 22.6834 10.6833 22.6834 10.2928 22.2929L1.80754 13.8076C1.41702 13.4171 1.41702 12.7839 1.80754 12.3934L9.58572 4.61525L7.4644 2.49393L8.87861 1.07971ZM10.9999 6.02946L3.92886 13.1005H18.071L10.9999 6.02946Z"></path></svg>`,
    tableBorder: `<svg viewBox="0 0 24 24" class="remixicon popoverIcon"><path d="M21 3C21.5523 3 22 3.44772 22 4V20C22 20.5523 21.5523 21 21 21H3C2.44772 21 2 20.5523 2 20V4C2 3.44772 2.44772 3 3 3H21ZM11 13H4V19H11V13ZM20 13H13V19H20V13ZM11 5H4V11H11V5ZM20 5H13V11H20V5Z"></path></svg>`,
    plusSize: `<svg viewBox="0 0 24 24" class="remixicon"><path d="M11 11V5H13V11H19V13H13V19H11V13H5V11H11Z"></path></svg>`,
    minusSize: `<svg viewBox="0 0 24 24" class="remixicon"><path d="M5 11V13H19V11H5Z"></path></svg>`,
    unorderedlist: `<svg viewBox="0 0 24 24" class="remixicon"><path d="M8 4H21V6H8V4ZM4.5 6.5C3.67157 6.5 3 5.82843 3 5C3 4.17157 3.67157 3.5 4.5 3.5C5.32843 3.5 6 4.17157 6 5C6 5.82843 5.32843 6.5 4.5 6.5ZM4.5 13.5C3.67157 13.5 3 12.8284 3 12C3 11.1716 3.67157 10.5 4.5 10.5C5.32843 10.5 6 11.1716 6 12C6 12.8284 5.32843 13.5 4.5 13.5ZM4.5 20.4C3.67157 20.4 3 19.7284 3 18.9C3 18.0716 3.67157 17.4 4.5 17.4C5.32843 17.4 6 18.0716 6 18.9C6 19.7284 5.32843 20.4 4.5 20.4ZM8 11H21V13H8V11ZM8 18H21V20H8V18Z"></path></svg>`,
    orderedlist: `<svg viewBox="0 0 24 24" class="remixicon"><path d="M8 4H21V6H8V4ZM5 3V6H6V7H3V6H4V4H3V3H5ZM3 14V11.5H5V11H3V10H6V12.5H4V13H6V14H3ZM5 19.5H3V18.5H5V18H3V17H6V21H3V20H5V19.5ZM8 11H21V13H8V11ZM8 18H21V20H8V18Z"></path></svg>`,
    alignleft: `<svg viewBox="0 0 24 24" class="remixicon"><path d="M3 4H21V6H3V4ZM3 19H17V21H3V19ZM3 14H21V16H3V14ZM3 9H17V11H3V9Z"></path></svg>`,
    alignright: `<svg viewBox="0 0 24 24" class="remixicon"><path d="M3 4H21V6H3V4ZM7 19H21V21H7V19ZM3 14H21V16H3V14ZM7 9H21V11H7V9Z"></path></svg>`,
    aligncenter: `<svg viewBox="0 0 24 24" class="remixicon"><path d="M3 4H21V6H3V4ZM5 19H19V21H5V19ZM3 14H21V16H3V14ZM5 9H19V11H5V9Z"></path></svg>`,
    alignjustify: `<svg viewBox="0 0 24 24" class="remixicon"><path d="M3 4H21V6H3V4ZM3 19H21V21H3V19ZM3 14H21V16H3V14ZM3 9H21V11H3V9Z"></path></svg>`,
    aligntop: `<svg viewBox="0 0 24 24" class="remixicon"><path d="M3 3H21V5H3V3ZM8 11V21H6V11H3L7 7L11 11H8ZM18 11V21H16V11H13L17 7L21 11H18Z"></path></svg>`,
    alignmiddle: `<svg viewBox="0 0 24 24" class="remixicon"><path d="M3 11H21V13H3V11ZM18 18V21H16V18H13L17 14L21 18H18ZM8 18V21H6V18H3L7 14L11 18H8ZM18 6H21L17 10L13 6H16V3H18V6ZM8 6H11L7 10L3 6H6V3H8V6Z"></path></svg>`,
    alignbottom: `<svg viewBox="0 0 24 24" class="remixicon"><path d="M3 19H21V21H3V19ZM8 13H11L7 17L3 13H6V3H8V13ZM18 13H21L17 17L13 13H16V3H18V13Z"></path></svg>`,
    save: `<svg class="sldsIcon" viewBox="0 0 520 520" ><g><path d="M371 40v136c0 10-8 19-19 19H139c-10 0-19-8-19-19V40H80a40 40 0 00-40 40v360a40 40 0 0040 40h360a40 40 0 0040-40V112l-72-72zm70 381c0 10-8 19-19 19H99c-10 0-19-8-19-19V254c0-10 8-19 19-19h323c10 0 19 8 19 19zM248 136c0 10 8 19 19 19h46c10 0 19-8 19-19V40h-83z"></path></g></svg>`,
    preview: `<svg class="sldsIcon" viewBox="0 0 520 520" ><g><path d="M518 251a288 288 0 00-516 0 20 20 0 000 18 288 288 0 00516 0 20 20 0 000-18zM260 370c-61 0-110-49-110-110s49-110 110-110 110 49 110 110-49 110-110 110zm0-180c-39 0-70 31-70 70s31 70 70 70 70-31 70-70-31-70-70-70z"></path></g></svg>`,
    cancel: `<svg class="sldsIcon" viewBox="0 0 520 520"><g><path d="M310 254l130-131c6-6 6-15 0-21l-20-21c-6-6-15-6-21 0L268 212a10 10 0 01-14 0L123 80c-6-6-15-6-21 0l-21 21c-6 6-6 15 0 21l131 131c4 4 4 10 0 14L80 399c-6 6-6 15 0 21l21 21c6 6 15 6 21 0l131-131a10 10 0 0114 0l131 131c6 6 15 6 21 0l21-21c6-6 6-15 0-21L310 268a10 10 0 010-14z"></path></g></svg>`,
    truncate: `<svg class="remixicon" viewBox="0 0 512 512"><g stroke-width="0"></g><g id="SVGRepo_tracerCarrier" stroke-linecap="round" stroke-linejoin="round"></g><g id="SVGRepo_iconCarrier"> <g> <g> <path d="M320,243.115h-17.067c-11.759,0-21.333,9.574-21.333,21.333c0,11.759,9.574,21.333,21.333,21.333H320 c11.759,0,21.333-9.574,21.333-21.333C341.333,252.689,331.759,243.115,320,243.115z"></path> </g> </g> <g> <g> <path d="M310.076,74.189c-10.889-4.429-23.364,0.836-27.793,11.733L150.519,410.018c-4.429,10.897,0.836,23.364,11.733,27.793 c2.62,1.067,5.333,1.57,8.004,1.57c8.422,0,16.427-5.026,19.789-13.295l131.755-324.105 C326.229,91.085,320.973,78.617,310.076,74.189z"></path> </g> </g> <g> <g> <path d="M490.667,243.115H473.6c-11.759,0-21.333,9.574-21.333,21.333c0,11.759,9.574,21.333,21.333,21.333h17.067 c11.759,0,21.333-9.574,21.333-21.333C512,252.689,502.426,243.115,490.667,243.115z"></path> </g> </g> <g> <g> <path d="M405.333,243.115h-17.067c-11.759,0-21.333,9.574-21.333,21.333c0,11.759,9.574,21.333,21.333,21.333h17.067 c11.759,0,21.333-9.574,21.333-21.333C426.667,252.689,417.092,243.115,405.333,243.115z"></path> </g> </g> <g> <g> <path d="M157.867,243.115H21.333C9.574,243.115,0,252.689,0,264.448c0,11.759,9.574,21.333,21.333,21.333h136.533 c11.759,0,21.333-9.566,21.333-21.333C179.2,252.689,169.626,243.115,157.867,243.115z"></path> </g> </g> </g></svg>`,

    google1: `<svg class="googleAlign"><g ><g><g fill="none" fill-rule="evenodd"> <path fill="#DADCE0" d="M28 8h14v8H28zM8 32h34v8H8zM28 20h14v8H28zM8 44h34v8H8z"/> <path fill="#4285F4" d="M8 8h15v20H8z"/> </g> </g>ll="none" fill-rule="evenodd"><path fill="#DADCE0" d="M8 8h56v8H8zM8 32h14v8H8zM50 32h14v8H50zM8 20h14v8H8zM50 20h14v8H50zM8 44h56v8H8zM8 56h56v8H8z"/><path fill="#4285F4" d="M26 20h20v20H26z"/></g></svg>`,
    google2: `<svg class="googleAlign"><g><g fill="none" fill-rule="evenodd"><path fill="#DADCE0" d="M8 8h6v8H8zM36 8h6v8h-6zM8 32h34v8H8zM8 20h6v8H8zM36 20h6v8h-6zM8 44h34v8H8z"/><path fill="#4285F4" d="M18 8h14v20H18z"/></g></g></svg>`,
    google3: `<svg class="googleAlign"><g><g fill="none" fill-rule="evenodd"> <path fill="#DADCE0" d="M8 8h34v8H8zM28 32h14v8H28zM8 20h34v8H8zM28 44h14v8H28z"/> <path fill="#4285F4" d="M8 32h15v20H8z"/> </g> </g></svg>`,
    google4: `<svg class="googleAlign"><g><g fill="none" fill-rule="evenodd"> <path fill="#DADCE0" d="M8 8h34v8H8zM8 44h6v8H8zM36 44h6v8h-6zM8 32h6v8H8zM36 32h6v8h-6zM8 20h34v8H8z"/> <path fill="#4285F4" d="M18 32h14v20H18z"/> </g> </g></svg>`,
    google5: `<svg class="googleAlign"><g><g fill="none" fill-rule="evenodd"> <path fill="#DADCE0" d="M8 8h56v8H8zM8 32h14v8H8zM50 32h14v8H50zM8 44h56v8H8zM8 56h56v8H8z"/> <path fill="#4285F4" d="M26 20h20v20H26z"/> </g> </g></svg>`,
    google6: `<svg class="googleAlign"><g><g fill="none" fill-rule="evenodd"> <path fill="#DADCE0" d="M8 8h16v8H8zM8 32h34v8H8zM8 20h16v8H8zM8 44h34v8H8z"/> <path fill="#4285F4" d="M28 8h14v20H28z"/> </g> </g></svg>`,
    google7: `<svg class="googleAlign"><g><g fill="none" fill-rule="evenodd"> <path fill="#DADCE0" d="M8 8h56v8H8zM8 44h56v8H8zM8 56h56v8H8z"/> <path fill="#4285F4" d="M26 20h20v20H26z"/> </g> </g></svg>`,
    google8: `<svg class="googleAlign"><<g><g fill="none" fill-rule="evenodd"> <path fill="#DADCE0" d="M8 8h34v8H8zM8 32h16v8H8zM8 20h34v8H8zM8 44h16v8H8z"/> <path fill="#4285F4" d="M28 32h14v20H28z"/> </g> </g>/svg>`,
    google9: `<svg class="googleAlign"><g><g fill="none" fill-rule="evenodd"> <path fill="#DADCE0" d="M8 8h34v8H8zM28 32h14v8H28zM28 20h14v8H28zM8 44h34v8H8z"/> <path fill="#4285F4" d="M8 20h15v20H8z"/> </g> </g></svg>`,
    google10: `<svg class="googleAlign"><g><g fill="none" fill-rule="evenodd"> <path fill="#DADCE0" d="M8 8h34v8H8zM8 32h6v8H8zM36 32h6v8h-6zM8 20h6v8H8zM36 20h6v8h-6zM8 44h34v8H8z"/> <path fill="#4285F4" d="M18 20h14v20H18z"/> </g> </g></svg>`,
    google11: `<svg class="googleAlign"><g><g fill="none" fill-rule="evenodd"> <path fill="#DADCE0" d="M8 8h34v8H8zM8 32h16v8H8zM8 20h16v8H8zM8 44h34v8H8z"/> <path fill="#4285F4" d="M28 20h14v20H28z"/> </g> </g></svg>`,
    googleSheet: `<svg class="googleAlign"><g><path fill="none" d="M0 0h40v40H0z"/> <path fill="#fff" d="M10.5 14H30v16H10.5z"/> <path fill="#188038" d="M24 12l7 3.1 2-4.1-9-9-2.5 4.2z"/> <path fill="#34a853" d="M21 23h5v3h-5zm-7-5h5v3h-5z"/> <path fill="#34a853" d="M24 11V2H10C8.3 2 7 3.3 7 5v30c0 1.7 1.3 3 3 3h20c1.7 0 3-1.3 3-3V11h-9zm4 17H12V16h16v12z"/> <path fill="#34a853" d="M14 23h5v3h-5zm7-5h5v3h-5z"/> </g></svg>`,
    googleDoc: `<svg class="googleAlign"><g><defs><linearGradient id="a" x1="50.005%" x2="50.005%" y1="8.586%" y2="100.014%"><stop stop-color="#1A237E" stop-opacity=".2" offset="0%"/><stop stop-color="#1A237E" stop-opacity=".02" offset="100%"/></linearGradient><radialGradient id="b" cx="3.168%" cy="2.718%" r="161.248%" fx="3.168%" fy="2.718%" gradientTransform="matrix(1 0 0 .72222 0 .008)"><stop stop-color="#FFF" offset="0%"/><stop stop-color="#FFF" stop-opacity="0" offset="100%"/></radialGradient></defs><g fill="none" fill-rule="evenodd"><path fill="#4285F4" d="M9.5 2H24l9 9v24.5c0 1.3807119-1.1192881 2.5-2.5 2.5h-21C8.11928813 38 7 36.8807119 7 35.5v-31C7 3.11928813 8.11928813 2 9.5 2z"/><path fill="#1A237E" fill-opacity=".2" d="M7 35c0 1.3807119 1.11928813 2.5 2.5 2.5h21c1.3807119 0 2.5-1.1192881 2.5-2.5v.5c0 1.3807119-1.1192881 2.5-2.5 2.5h-21C8.11928813 38 7 36.8807119 7 35.5V35z"/><path fill="#FFF" fill-opacity=".2" d="M9.5 2H24v.5H9.5C8.11928813 2.5 7 3.61928813 7 5v-.5C7 3.11928813 8.11928813 2 9.5 2z"/><path fill="url(#a)" fill-rule="nonzero" d="M17.5 8l8.5 8.5V9" transform="7 2)"/><path fill="#A1C2FA" d="M24 2l9 9h-6.5C25.1192881 11 24 9.88071187 24 8.5V2z"/><path fill="#F1F1F1" d="M13 18h14v2H13v-2zm0 4h14v2H13v-2zm0 4h14v2H13v-2zm0 4h10v2H13v-2z"/><path fill="url(#b)" fill-opacity=".1" d="M2.5 0H17l9 9v24.5c0 1.3807119-1.1192881 2.5-2.5 2.5h-21C1.11928813 36 0 34.8807119 0 33.5v-31C0 1.11928813 1.11928813 0 2.5 0z" transform="7 2)"/></g></g></svg>`,
    googlePoint: `<svg class="googleAlign"><g><path fill="none" d="M0 0h40v40H0z"/> <path fill="#fff" d="M10.5 14H30v16H10.5z"/> <path fill="#f29900" d="M24 12l7 3.1 2-4.1-9-9-2.5 4.2z"/> <path fill="#fbbc04" d="M24 11V2H10C8.3 2 7 3.3 7 5v30c0 1.7 1.3 3 3 3h20c1.7 0 3-1.3 3-3V11h-9zm4 5v11H12V16h16z"/> <path fill="#fbbc04" d="M14 18h12v7H14z"/> </g></svg>`,
    googleFile: `<svg class="googleAlign"><g><defs><linearGradient id="a" x1="50.005%" x2="50.005%" y1="8.586%" y2="100.014%"><stop stop-opacity=".2" offset="0%"/><stop stop-opacity=".02" offset="100%"/></linearGradient><radialGradient id="b" cx="3.168%" cy="2.718%" r="161.248%" fx="3.168%" fy="2.718%" gradientTransform="matrix(1 0 0 .72222 0 .008)"><stop stop-color="#FFF" offset="0%"/><stop stop-color="#FFF" stop-opacity="0" offset="100%"/></radialGradient></defs><g fill="none" fill-rule="evenodd"><path fill="#90A4AE" d="M9.5 2H24l9 9v24.5c0 1.3807119-1.1192881 2.5-2.5 2.5h-21C8.11928813 38 7 36.8807119 7 35.5v-31C7 3.11928813 8.11928813 2 9.5 2z"/><path fill="#444746" fill-opacity=".1" d="M7 35c0 1.3807119 1.11928813 2.5 2.5 2.5h21c1.3807119 0 2.5-1.1192881 2.5-2.5v.5c0 1.3807119-1.1192881 2.5-2.5 2.5h-21C8.11928813 38 7 36.8807119 7 35.5V35z"/><path fill="#FFF" fill-opacity=".2" d="M9.5 2H24v.5H9.5C8.11928813 2.5 7 3.61928813 7 5v-.5C7 3.11928813 8.11928813 2 9.5 2z"/><path fill="url(#a)" fill-rule="nonzero" d="M17.5 8l8.5 8.5V9" transform="7 2)"/><path fill="#F1F1F1" d="M24 2l9 9h-6.5C25.1192881 11 24 9.88071187 24 8.5V2zm4.86 25l-5.89-10h-5.26l5.89 10h5.26zm-13.15 6h10.53l2.61-5H18.29l-2.58 5zm.92-14.55l-5.49 10L13.8 33l5.48-9.98-2.65-4.57z"/><path fill="url(#b)" fill-opacity=".1" d="M2.5 0H17l9 9v24.5c0 1.3807119-1.1192881 2.5-2.5 2.5h-21C1.11928813 36 0 34.8807119 0 33.5v-31C0 1.11928813 1.11928813 0 2.5 0z" transform="7 2)"/></g></g></svg>`,
    googleTable: `<svg class="googleAlign"><g"><path fill="#444746" d="M20 21H5c-.55 0-1.02083-.1958-1.4125-.5875C3.19583 20.0208 3 19.55 3 19V5c0-.55.19583-1.02083.5875-1.4125C3.97917 3.19583 4.45 3 5 3h15c.55 0 1.0208.19583 1.4125.5875C21.8042 3.97917 22 4.45 22 5v14c0 .55-.1958 1.0208-.5875 1.4125C21.0208 20.8042 20.55 21 20 21ZM5 8h15V5H5v3Zm3 2H5v9h3v-9Zm9 0v9h3v-9h-3Zm-2 0h-5v9h5v-9Z"/> </g></svg>`,

    pageConfig: `<svg class="pageIcon" viewBox="0 0 32 32"><g id="SVGRepo_bgCarrier" stroke-width="0"></g><g id="SVGRepo_tracerCarrier" stroke-linecap="round" stroke-linejoin="round"></g><g id="SVGRepo_iconCarrier"> <style type="text/css"> .st0{fill:none;stroke:#000000;stroke-width:2;stroke-linecap:round;stroke-linejoin:round;stroke-miterlimit:10;} .st1{fill:none;stroke:#000000;stroke-width:2;stroke-linejoin:round;stroke-miterlimit:10;} </style> <path class="st0" d="M28.8,17.2c-1.1,0.2-2,0-2.4-0.7c-0.4-0.7-0.1-1.7,0.6-2.5c-0.9-0.9-1.9-1.5-3.1-1.8c-0.3,1-1,1.8-1.8,1.8 s-1.5-0.7-1.8-1.8c-1.2,0.3-2.3,0.9-3.1,1.8c0.7,0.8,1,1.8,0.6,2.5c-0.4,0.7-1.4,0.9-2.4,0.7C15.1,17.8,15,18.4,15,19 s0.1,1.2,0.2,1.8c1.1-0.2,2,0,2.4,0.7c0.4,0.7,0.1,1.7-0.6,2.5c0.9,0.9,1.9,1.5,3.1,1.8c0.3-1,1-1.8,1.8-1.8s1.5,0.7,1.8,1.8 c1.2-0.3,2.3-0.9,3.1-1.8c-0.7-0.8-1-1.8-0.6-2.5c0.4-0.7,1.4-0.9,2.4-0.7c0.2-0.6,0.2-1.2,0.2-1.8S28.9,17.8,28.8,17.2z"></path> <circle class="st0" cx="22" cy="19" r="2"></circle> <polyline class="st0" points="19,3 19,9 25,9 19,3 7,3 7,29 25,29 25,25.3 "></polyline> <line class="st0" x1="25" y1="9" x2="25" y2="12"></line> </g></svg>`,
    pageSetup: `<svg class="pageSetup" viewBox="0 0 512 512" ><g stroke-width="0"></g><g  stroke-linecap="round" stroke-linejoin="round"></g><g id="SVGRepo_iconCarrier"> <g> <g> <g> <path d="M438.187,101.428L339.872,3.124c-2-2-4.713-3.124-7.541-3.124H103.979C85.622,0,70.688,14.934,70.688,33.291v445.419 c0,18.356,14.934,33.291,33.291,33.291h304.043c18.356,0,33.291-14.934,33.291-33.291V108.971 C441.312,106.142,440.188,103.428,438.187,101.428z M404.892,98.304h-61.894V36.416l-0.002-0.002L404.892,98.304z M419.979,478.709c0,6.594-5.363,11.957-11.957,11.957H103.979c-6.594,0-11.957-5.363-11.957-11.957V33.291 c0-6.594,5.363-11.957,11.957-11.957h217.685v87.637c0,5.89,4.777,10.667,10.667,10.667h87.648V478.709z"></path> <path d="M226.358,199.968c-23.526,0-42.667,19.14-42.667,42.667c0,23.526,19.14,42.667,42.667,42.667 c23.526,0,42.667-19.14,42.667-42.667C269.025,219.108,249.885,199.968,226.358,199.968z M226.358,263.968 c-11.763,0-21.333-9.57-21.333-21.333c0-11.763,9.57-21.333,21.333-21.333s21.333,9.57,21.333,21.333 C247.692,254.398,238.123,263.968,226.358,263.968z"></path> <path d="M299.282,318.08c2.734-0.733,5.062-2.519,6.477-4.97l21.333-36.951c2.946-5.102,1.198-11.625-3.904-14.571l-12.33-7.119 c0.555-3.933,0.833-7.89,0.833-11.836c0-3.946-0.279-7.903-0.833-11.836l12.33-7.118c2.45-1.414,
              4.238-3.744,4.97-6.477 c0.733-2.733,0.349-5.644-1.066-8.094l-21.333-36.951c-2.945-5.101-9.466-6.85-14.571-3.904l-12.373,7.142 c-6.243-4.871-13.152-8.874-20.457-11.846v-14.249c0-5.89-4.777-10.667-10.667-10.667h-42.667 c-5.89,0-10.667,4.776-10.667,10.667v14.25c-7.305,2.973-14.213,6.974-20.458,11.846l-12.372-7.142 c-5.103-2.945-11.627-1.198-14.571,3.904l-21.333,36.951c-1.414,2.45-1.798,5.361-1.066,8.094 c0.733,2.734,2.519,5.062,4.97,6.477l12.33,7.118c-0.555,3.933-0.833,7.89-0.833,11.836c0,3.946,0.279,7.903,0.833,11.836 l-12.33,7.119c-5.102,2.946-6.85,9.469-3.904,14.571l21.333,36.951c1.414,2.45,3.744,4.238,6.477,4.97 c2.732,0.734,5.644,0.35,8.094-1.066l12.372-7.142c6.244,4.871,13.152,8.873,20.458,11.846v14.249 c0,5.89,4.777,10.667,10.667,10.667h42.667c5.89,0,10.667-4.777,10.667-10.667v-14.251c7.307-2.974,14.213-6.974,20.457-11.846 l12.373,7.143C293.637,318.429,296.548,318.814,299.282,318.08z M270.28,289.108c-7.27,6.876-16.138,12.012-25.642,14.85 c-4.517,1.35-7.614,5.506-7.614,10.221v11.122h-21.333v-11.122c0-4.716-3.095-8.87-7.614-10.221 c-9.504-2.838-18.371-7.974-25.642-14.85c-3.427-3.242-8.578-3.847-12.662-1.488l-9.674,5.585l-10.667-18.476l9.635-5.564 c4.085-2.358,6.137-7.121,5.043-11.71c-1.164-4.884-1.754-9.872-1.754-14.822c0-4.95,0.59-9.938,1.754-14.822 c1.093-4.59-0.957-9.351-5.043-11.71l-9.635-5.563l10.667-18.476l9.674,5.584c4.087,2.361,9.235,1.755,12.661-1.488 c7.274-6.877,16.141-12.012,25.643-14.85c4.517-1.35,7.614-5.505,7.614-10.221v-11.12h21.333v11.122 c0,
              4.715,3.095,8.87,7.614,10.221c9.503,2.838,18.37,7.974,25.643,14.85c3.426,3.241,8.573,3.846,12.661,1.488l9.674-5.584 l10.667,18.476l-9.635,5.563c-4.085,2.358-6.136,7.12-5.043,11.71c1.164,4.884,1.754,9.872,1.754,14.822 s-0.59,9.938-1.754,14.822c-1.093,4.589,0.957,9.351,5.043,11.71l9.635,5.564l-10.667,18.476l-9.674-5.585 C278.858,285.263,273.709,285.868,270.28,289.108z"></path> <path d="M321.664,347.131v6.361c-2.478,0.74-4.85,1.724-7.084,2.937l-4.499-4.499c-4.166-4.164-10.918-4.164-15.086,0 c-4.165,4.165-4.165,10.919,0,15.086l4.499,4.499c-1.213,2.234-2.196,4.606-2.937,7.084h-6.361 c-5.89,0-10.667,4.777-10.667,10.667s4.776,10.667,10.667,10.667h6.361c0.74,2.478,1.724,4.85,2.937,7.084l-4.499,4.499 c-4.165,4.165-4.165,10.919,0,15.086c2.083,2.082,4.813,3.124,7.542,3.124s5.459-1.042,7.542-3.124l4.499-4.499 c2.234,1.213,4.607,2.196,7.084,2.937v6.361c0,5.89,4.777,10.667,10.667,10.667s10.667-4.777,10.667-10.667v-6.361 c2.478-0.74,4.85-1.724,7.084-2.937l4.499,4.499c2.083,2.082,4.813,3.124,7.542,3.124s5.459-1.042,7.542-3.124 c4.165-4.165,4.165-10.919,0-15.086l-4.499-4.499c1.213-2.234,2.196-4.606,2.937-7.084h6.361c5.89,0,10.667-4.776,10.667-10.667 s-4.773-10.667-10.665-10.667h-6.361c-0.74-2.478-1.724-4.85-2.937-7.084l4.499-4.499c4.165-4.165,4.165-10.919,0-15.086 c-4.166-4.164-10.918-4.164-15.086,0l-4.499,4.499c-2.234-1.213-4.607-2.196-7.084-2.937v-6.361 c0-5.89-4.777-10.667-10.667-10.667S321.664,341.241,321.664,347.131z M348.331,389.264c0,8.822-7.178,16-16,16s-16-7.178-16-16 s7.178-16,16-16S348.331,380.442,348.331,389.264z"></path> <path d="M194.358,442.837h-59.495c-5.89,0-10.667,4.777-10.667,10.667s4.776,10.667,10.667,10.667h59.495 c5.89,0,10.667-4.777,10.667-10.667S200.25,442.837,194.358,442.837z"></path> <path d="M239.776,442.837h-1.067c-5.89,0-10.667,4.777-10.667,10.667s4.777,10.667,10.667,10.667h1.067 c5.89,0,10.667-4.777,10.667-10.667S245.666,442.837,239.776,442.837z"></path> </g> </g> </g> </g></svg>`,
    pageMargin: `<svg class="msIcon" viewBox="0,0,2048,2048" ><path type="path" class="OfficeIconColors_HighContrast" d="M 256 128 h 1472 v 1792 h -1472 m 1088 -1728 h -704 v 256 h 704 m -704 64 v 1024 h 704 v -1024 m -1024 -320 v 256 h 256 v -256 m -256 320 v 1024 h 256 v -1024 m -256 1344 h 256 v -256 h -256 m 320 256 h 704 v -256 h -704 m 1024 256 v -256 h -256 v 256 m 256 -320 v -1024 h -256 v 1024 m 256 -1088 v -256 h -256 v 256 z"></path><path type="path" class="OfficeIconColors_m20" d="M 1693 1888 h -1405 v -1728 h 1405 z"></path><path type="path" class="OfficeIconColors_m22" d="M 256 128 h 1472 v 1792 h -1472 m 1408 -64 v -1664 h -1344 v 1664 z"></path><path type="path" class="OfficeIconColors_m24" d="M 1408 512 v 1024 h 256 v 64 h -256 v 256 h -64 v -256 h -704 v 256 h -64 v -256 h -256 v -64 h 256 v -1024 h -256 v -64 h 256 v -256 h 64 v 256 h 704 v -256 h 64 v 256 h 256 v 64 m -320 0 h -704 v 1024 h 704 z"></path></svg>`,
    pageOriantation: `<svg class="msIcon" viewBox="0,0,2048,2048" ><path type="path" class="OfficeIconColors_HighContrast" d="M 512 1920 v -1024 h 1024 l 384 384 v 640 m -384 -933 v 293 h 293 m -357 64 v -384 h -896 v 896 h 1280 v -512 m -1408 192 h -320 v -1408 h 639 l 385 384 v 320 h -64 v -256 h -384 v -384 h -512 v 1280 h 256 m 320 -960 h 293 l -293 -293 z"></path><path type="path" class="OfficeIconColors_m20" d="M 448 1504 h -288 v -1344 h 597 l 363 363 v 309 h -672 m 1440 450 v 606 h -1344 v -960 h 986 z"></path><path type="path" class="OfficeIconColors_m22" d="M 512 1920 v -1024 h 1024 l 384 384 v 640 m -384 -933 v 293 h 293 m -357 64 v -384 h -896 v 896 h 1280 v -512 m -1408 192 h -320 v -1408 h 639 l 385 384 v 320 h -64 v -256 h -384 v -384 h -512 v 1280 h 256 m 320 -960 h 293 l -293 -293 z"></path></svg>`,
    pageSize: `<svg class="msIcon" viewBox="0,0,2048,2048" ><path type="path" class="OfficeIconColors_HighContrast" d="M 1536 896 v 1024 h -1088 v -1472 h 640 m 0 448 h 352 l -352 -348 m 384 412 h -448 v -448 h -512 v 1344 h 960 m 64 -1728 v 192 h -64 v -64 h -960 v 64 h -64 v -192 h 64 v 64 h 960 v -64 m -1344 320 h 192 v 64 h -64 v 1344 h 64 v 64 h -192 v -64 h 64 v -1344 h -64 z"></path><path type="path" class="OfficeIconColors_m20" d="M 1066 480 l 438 421 v 992 h -1029 v -1413 z"></path><path type="path" class="OfficeIconColors_m22" d="M 1536 896 v 1024 h -1088 v -1472 h 640 m 0 448 h 352 l -352 -348 m 384 412 h -448 v -448 h -512 v 1344 h 960 z"></path><path type="path" class="OfficeIconColors_m24" d="M 1536 128 v 192 h -64 v -64 h -960 v 64 h -64 v -192 h 64 v 64 h 960 v -64 m -1344 320 h 192 v 64 h -64 v 1344 h 64 v 64 h -192 v -64 h 64 v -1344 h -64 z"></path></svg>`,
    pageColumn: `<svg class="msIcon" viewBox="0,0,2048,2048" ><path type="path" class="OfficeIconColors_HighContrast" d="M 1728 128 v 1792 h -1408 v -1792 m 1344 64 h -1280 v 1664 h 1280 m -704 -704 h -384 v -64 h 384 m 0 256 v 64 h -384 v -64 m 384 -448 h -384 v -64 h 384 m 0 -192 h -384 v -64 h 384 m 128 512 h 384 v 64 h -384 m 0 192 h 384 v 64 h -384 m 384 -832 v 64 h -384 v -64 m 0 256 h 384 v 64 h -384 z"></path><path type="path" class="OfficeIconColors_m20" d="M 1696 1888 h -1344 v -1728 h 1344 z"></path><path type="path" class="OfficeIconColors_m22" d="M 1728 128 v 1792 h -1408 v -1792 m 1344 64 h -1280 v 1664 h 1280 z"></path><path type="path" class="OfficeIconColors_m24" d="M 960 1152 h -384 v -64 h 384 m 0 256 v 64 h -384 v -64 m 384 -448 h -384 v -64 h 384 m 0 -192 h -384 v -64 h 384 m 128 512 h 384 v 64 h -384 m 0 192 h 384 v 64 h -384 m 384 -832 v 64 h -384 v -64 m 0 256 h 384 v 64 h -384 z"></path></svg>`,

    pageBreak: `<svg class="remixicon" viewBox="0 0 24 24"><path d="M17 21V17H7V21H5V16C5 15.4477 5.44772 15 6 15H18C18.5523 15 19 15.4477 19 16V21H17ZM7 3V7H17V3H19V8C19 8.55228 18.5523 9 18 9H6C5.44772 9 5 8.55228 5 8V3H7ZM2 9L6 12L2 15V9ZM22 9V15L18 12L22 9Z"></path></svg>`
}

/**
 * page size for page formats,
 * used to set page-size in simple template builder,
 * all thew page format as per the html2pdf library, so Add/Remove page formate as per html2pdf library,
 * all values are in (pt) unit,
 */
export var pageFormats = {
    'a0': [2383.94, 3370.39],
    'a1': [1683.78, 2383.94],
    'a2': [1190.55, 1683.78],
    'a3': [841.89, 1190.55],
    'a4': [595.28, 841.89],
    'a5': [419.53, 595.28],
    'a6': [297.64, 419.53],
    'a7': [209.76, 297.64],
    'a8': [147.40, 209.76],
    'a9': [104.88, 147.40],
    'a10': [73.70, 104.88],
    'b0': [2834.65, 4008.19],
    'b1': [2004.09, 2834.65],
    'b2': [1417.32, 2004.09],
    'b3': [1000.63, 1417.32],
    'b4': [708.66, 1000.63],
    'b5': [498.90, 708.66],
    'b6': [354.33, 498.90],
    'b7': [249.45, 354.33],
    'b8': [175.75, 249.45],
    'b9': [124.72, 175.75],
    'b10': [87.87, 124.72],
    'c0': [2599.37, 3676.54],
    'c1': [1836.85, 2599.37],
    'c2': [1298.27, 1836.85],
    'c3': [918.43, 1298.27],
    'c4': [649.13, 918.43],
    'c5': [459.21, 649.13],
    'c6': [323.15, 459.21],
    'c7': [229.61, 323.15],
    'c8': [161.57, 229.61],
    'c9': [113.39, 161.57],
    'c10': [79.37, 113.39],
    'dl': [311.81, 623.62],
    'letter': [612, 792],
    'government-letter': [576, 756],
    'legal': [612, 1008],
    'junior-legal': [576, 360],
    'ledger': [1224, 792],
    'tabloid': [792, 1224],
    'credit-card': [153, 243],
    'executive': [522, 756],       // EstateXpert Changes....
    'statement': [396, 594],       // EstateXpert Changes....
};

/** 
 * method that return value that used to convert pt unit value in other units value,
 * i.e, pxValue = ptValue * unitMultiplier('px');
 * 
 * @param {*} unit 
 * @returns 
 */
export function unitMultiplier(unit) {
    switch (unit) {
        case 'pt':
            return 1;

        case 'mm':
            return 72 / 25.4;

        case 'cm':
            return 72 / 2.54;

        case 'in':
            return 72;

        case 'px':
            return 72 / 96;

        case 'pc':
            return 12;

        case 'em':
            return 12;

        case 'ex':
            return 6;

        default:
            return null;
    }
}

/**
 * method that convert value from one unit to another...
 *
 * @param {string} fromUnit
 * @param {string} toUnit
 * @param {number} valueToConvert
 * @returns {number}
 */
export function unitConverter(fromUnit, toUnit, valueToConvert) {
    var fromUnitMultiplier = unitMultiplier(fromUnit);
    var toUnitMultiplier = unitMultiplier(toUnit);
    var value = valueToConvert * fromUnitMultiplier / toUnitMultiplier;
    return value;
}