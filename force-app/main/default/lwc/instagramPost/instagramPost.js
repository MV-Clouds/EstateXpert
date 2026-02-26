import { LightningElement } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
export default class InstagramPost extends LightningElement {
    connectedCallback() {
        loadStyle(this, MulishFontCss);
    }
}