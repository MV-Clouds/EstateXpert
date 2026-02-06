import { LightningElement, track } from 'lwc';
import picaLib from '@salesforce/resourceUrl/imageConverter';
import AWS_SDK from "@salesforce/resourceUrl/AWSSDK";
import NoUploadImage from "@salesforce/resourceUrl/NoUploadImage";
import { loadScript, loadStyle } from 'lightning/platformResourceLoader';
import getS3ConfigData from '@salesforce/apex/InstagramPostController.getS3ConfigSettings';
import createInstagramContainer from '@salesforce/apex/InstagramPostController.createInstagramContainer';
import publishToInstagram from '@salesforce/apex/InstagramPostController.publishToInstagram';
import checkInstagramIntegration from '@salesforce/apex/InstagramPostController.checkInstagramIntegration';
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { NavigationMixin } from 'lightning/navigation';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
import getMetadataRecords from '@salesforce/apex/ControlCenterController.getMetadataRecords';

export default class InstagramPost extends NavigationMixin(LightningElement) {
    s3;
    @track progressText = 'Uploading Files...';
    @track showSpinner = false;
    @track isAWS = true;
    @track selectedFilesToUpload = [];
    @track awsObjectKeys = [];
    @track uploadProgress = 0;
    @track fileURL = [];
    @track confData = '';
    @track picaInstance;
    @track allFilesData = [];
    @track largeImageFiles = [];
    @track noUploadImagelink = NoUploadImage;
    @track isAwsSdkInitialized = false;
    @track caption = '';
    @track progressStyle = 'width: 0%';
    @track isIntegrated = false;
    @track containerId = '';
    @track containerIds = [];
    @track isCarousel = false;
    @track showPublishButton = false;
    @track isAccessible = false;


    get isFileAvailable() {
        return this.selectedFilesToUpload.length > 0;
    }

    /**
    * Method Name : connectedCallback
    * @description : Method to load intial metadata and script in the component
    * * Date: 04/11/2024
    * Created By:Rachit Shah
    */
    async connectedCallback() {
        loadStyle(this, MulishFontCss)
            .then(() => {
                console.log('Mulish Font loaded successfully');
            })
            .catch((error) => {
                console.error('Error loading Mulish Font:', error);
            });

        await this.getAccessible();
        if (!this.isAccessible) {
            this.showSpinner = false;
            return;
        }

        this.loadScripts();
        this.getS3ConfigDataAsync();
        this.checkIntegration();
    }

    /*
    * Method Name: getAccessible
    * @description: Method to check if user has access to Instagram Post Uploader feature
    * Date: 03/02/2026
    * Created By: Karan Singh
    */
    async getAccessible() {
        try {
            const data = await getMetadataRecords();
            const broadcastFeature = data.find(
                item => item.DeveloperName === 'Instagram_Post_Uploader'
            );
            this.isAccessible = broadcastFeature ? Boolean(broadcastFeature.MVEX__isAvailable__c) : false;
        } catch (error) {
            console.error('Error fetching accessible fields', error);
            this.isAccessible = false;
        }
    }

    checkIntegration(){
        checkInstagramIntegration()
            .then(result => {
                this.isIntegrated = result;
            })
            .catch(error => {
                console.error('Error checking Instagram integration:', error);
            });
    }

    /**
    * Method Name : renderedCallback
    * @description : Method to aws script if not loaded when component changes
    * * Date: 04/11/2024
    * Created By:Rachit Shah
    */
    renderedCallback() {
        try {
            if (this.isAwsSdkInitialized) {
                Promise.all([loadScript(this, AWS_SDK)])
                    .then(() => {
                        console.log('Script loaded successfully');
                    })
                    .catch((error) => {
                        console.error("Error loading script -> ", error);
                    });

                this.isAwsSdkInitialized = false;
            }
        } catch (error) {
            console.log('Error in renderedCallback -> ', error);
        }
    }

    /**
    * Method Name : loadScripts
    * @description : Method to load external library
    * * Date: 04/11/2024
    * Created By:Rachit Shah
    */
    async loadScripts() {
        try {
            await loadScript(this, picaLib);
            this.picaInstance = window.pica();
            if (!this.isAwsSdkInitialized) {
                await loadScript(this, AWS_SDK);
                this.isAwsSdkInitialized = true;
                console.log('AWS SDK and pica loaded successfully');
            }
        } catch (error) {
            console.error("Error loading scripts -> ", error);
        }
    }

    
    /**
    * Method Name : getS3ConfigDataAsync
    * @description : Method to get S3ConfigDataAsync
    * * Date: 04/11/2024
    * Created By:Rachit Shah
    */
    async getS3ConfigDataAsync() {
        try {
            this.confData = await getS3ConfigData();
        } catch (error) {
            console.error('Error fetching S3 config data:', error);
        }
    }

        
    /**
    * Method Name : allowDrop
    * @description : Method to allow drop
    * * Date: 04/11/2024
    * Created By:Rachit Shah
    */
    allowDrop(event) {
        event.preventDefault();
    }

    /**
    * Method Name : handleFileDrop
    * @description : Method to handle file drop
    * * Date: 04/11/2024
    * Created By:Rachit Shah
    */
    handleFileDrop(event) {

        try {
            event.preventDefault();

            const files = Array.from(event.dataTransfer.files);
            if (!files.length) return;

            const fileType = event.currentTarget.dataset.id;

            if (fileType === 'tab1') {
                this.handleSelectedFiles({ target: { files } });

            } else if (fileType === 'tab2') {
                this.handleVideoUpload({ target: { files } });
            }
        } catch (error) {
            console.log('Error in handleFileDrop -> ', error.stack);
        }
    }


    /**
    * Method Name : handleDragStart
    * @description : Method to handle drag start
    * * Date: 04/11/2024
    * Created By:Rachit Shah
    */
    handleDragStart(event) {
        const index = event.target.dataset.index;
        event.dataTransfer.setData('index', index);

        event.target.classList.add('dragging');
    }

    /**
    * Method Name : handleDragOver
    * @description : Method to handle drag over
    * * Date: 04/11/2024
    * Created By:Rachit Shah
    */
    handleDragOver(event) {
        event.preventDefault();
        event.target.classList.add('drag-over');
    }

    /**
    * Method Name : handleDragEnter
    * @description : Method to handle drag enter
    * * Date: 04/11/2024
    * Created By:Rachit Shah
    */
    handleDragEnter(event) {
        event.preventDefault();
        const dropTarget = event.target.closest(".dropableimage");
        if (dropTarget) {
            dropTarget.classList.add('highlight');
        }
    }

    /**
    * Method Name : handleDrop
    * @description : Method to handle drag drop
    * * Date: 04/11/2024
    * Created By:Rachit Shah
    */
    handleDrop(event) {
        event.preventDefault();
        event.stopPropagation();

        const draggedIndex = parseInt(event.dataTransfer.getData('index'), 10);
        const droppedIndex = parseInt(event.target.closest('.dropableimage').dataset.index, 10);

        if (draggedIndex !== droppedIndex) {
            const draggedFile = this.selectedFilesToUpload.splice(draggedIndex, 1)[0];
            this.selectedFilesToUpload.splice(droppedIndex, 0, draggedFile);

            const draggedAllFileData = this.allFilesData.splice(draggedIndex, 1)[0];
            this.allFilesData.splice(droppedIndex, 0, draggedAllFileData);
        }

        this.template.querySelectorAll('.highlight').forEach(el => el.classList.remove('highlight'));
        this.template.querySelectorAll('.dragging').forEach(el => el.classList.remove('dragging'));

    }

    /**
    * Method Name : handleDragEnd
    * @description : Method to handle drag end
    * * Date: 04/11/2024
    * Created By:Rachit Shah
    */
    handleDragEnd(event) {
        event.target.classList.remove('dragging');
        this.template.querySelectorAll('.dropableimage').forEach(el => el.classList.remove('highlight'));
    }

    /**
    * Method Name : handleDragLeave
    * @description : Method to handle drag leave
    * * Date: 04/11/2024
    * Created By:Rachit Shah
    */
    handleDragLeave(event) {
        try {
            event.preventDefault();
            const dropableImage = event.currentTarget.closest(".dropableimage");
            if (!dropableImage.contains(event.relatedTarget)) {
                dropableImage.classList.remove("highlight");
            }
        } catch (error) {
            console.log('error in handleDragLeave', error.stack);
        }
    }


    /**
    * Method Name : handleCaptionChange
    * @description : Method to handle caption change
    * * Date: 04/11/2024
    * Created By:Rachit Shah
    */
    handleCaptionChange(event) {
        const caption = event.target.value;
        this.caption = caption;
        const captionInput = this.template.querySelector('[data-id="caption"]');

        if (this.caption.trim() != '') {
            captionInput.classList.remove('error-border');
        }
        else {
            captionInput.classList.add('error-border');
        }
    }

    /**
    * Method Name : handleRemoveFile
    * @description : Method to handle remove file
    * * Date: 04/11/2024
    * Created By:Rachit Shah
    */
    handleRemoveFile(event) {
        const fileNameToRemove = event.currentTarget.dataset.name;

        this.selectedFilesToUpload = this.selectedFilesToUpload.filter(file => file.fileName !== fileNameToRemove);
        this.allFilesData = this.allFilesData.filter(file => file.name !== fileNameToRemove);

        console.log('OUTPUT : ', this.allFilesData);
        console.log('OUTPUT : ',JSON.stringify(this.allFilesData));

    }

    /**
    * Method Name : initializeAwsSdk
    * @description : Method to initalize aws data
    * * Date: 04/11/2024
    * Created By:Rachit Shah
    */
    initializeAwsSdk(confData) {
        try {
            const AWS = window.AWS;
            AWS.config.update({
                accessKeyId: confData.MVEX__AWS_Access_Key__c,
                secretAccessKey: confData.MVEX__AWS_Secret_Access_Key__c,
                region: confData.MVEX__S3_Region_Name__c
            });
            this.s3 = new AWS.S3({
                apiVersion: "2006-03-01",
                params: { Bucket: confData.MVEX__S3_Bucket_Name__c }
            });
        } catch (error) {
            console.error("Error initializing AWS SDK:", error);
        }
    }

    /**
    * Method Name : tabing
    * @description : Method to do tabing between image and video upload
    * * Date: 04/11/2024
    * Created By:Rachit Shah
    */
    tabing(event) {
        const actionName = event.currentTarget.dataset.name;
        this.isAWS = actionName === 'AWS';
        const target = event.currentTarget.querySelector('a').dataset.tabId;

        this.template.querySelectorAll("a").forEach(tab => tab.classList.remove("active-tab"));
        this.template.querySelectorAll(".tab").forEach(tab => tab.classList.remove("active-tab-content"));

        this.template.querySelector(`[data-tab-id="${target}"]`).classList.add("active-tab");
        this.template.querySelector(`[data-id="${target}"]`).classList.add("active-tab-content");
    }

    /**
    * Method Name : handleSelectedFiles
    * @description : Method to handle selected files
    * * Date: 04/11/2024
    * Created By:Rachit Shah
    */
    async handleSelectedFiles(event) {
        try {

            const files = Array.from(event.target.files);
            if (!files.length) return;

            this.largeImageFiles = [];
            for (let file of files) {
                const initialSizeKB = file.size / 1024;
                if (initialSizeKB <= 5000) {
                    if (this.picaInstance) file = await this.convertToJpeg(file);

                    this.addFileToSelected(file, true);
                } else {
                    this.largeImageFiles.push(file.name);
                }
            }

            if (this.largeImageFiles.length) {
                this.showToast('Error', this.largeImageFiles.join(', ') + ' exceeds the 5MB limit.', 'error');
            }

            this.resetFileInput();
        }
        catch (error) {
            console.log('Error in handleSelectedFiles -> ', error.stack);
        }
    }

    /**
    * Method Name : handleVideoUpload
    * @description : Method to handle uploaded video 
    * * Date: 04/11/2024
    * Created By:Rachit Shah
    */
    handleVideoUpload(event) {
        const files = Array.from(event.target.files);

        for (let file of files) {
            const isMp4 = file.name.split('.').pop().toLowerCase() === 'mp4';

            if (!isMp4) {
                this.showToast('Error', isMp4 ? 'File exceeds the 30MB limit.' : 'Only MP4 files are allowed.', 'error');
                continue;
            }

            this.createThumbnail(file, (thumbnailDataURL) => {
                this.addFileToSelected(file, false, thumbnailDataURL);
            });
        }

        this.resetFileInput();
    }

    /**
    * Method Name : addFileToSelected
    * @description : Method to add file to selected files
    * * Date: 04/11/2024
    * Created By:Rachit Shah
    */
    addFileToSelected(file, isImage, previewUrl = URL.createObjectURL(file)) {
        this.allFilesData.push(file);
        this.selectedFilesToUpload.push({ ...file, previewUrl, isImage, isVideo: !isImage, fileName: file.name });

        console.log('selectedFilesToUpload JSON ==> ', JSON.stringify(this.selectedFilesToUpload));
    }

    /**
    * Method Name : createThumbnail
    * @description : Method to add create thumbnail for selected file
    * * Date: 04/11/2024
    * Created By:Rachit Shah
    */
    createThumbnail(file, callback) {
        const video = document.createElement('video');
        const canvas = document.createElement('canvas');
        const context = canvas.getContext('2d');

        video.src = URL.createObjectURL(file);
        video.addEventListener('loadeddata', () => {
            video.currentTime = 1;
            video.addEventListener('seeked', () => {
                canvas.width = video.videoWidth;
                canvas.height = video.videoHeight;
                context.drawImage(video, 0, 0, canvas.width, canvas.height);
                callback(canvas.toDataURL('image/jpeg'));
                URL.revokeObjectURL(video.src);
            });
        });
    }


    /**
    * Method Name : convertToJpeg
    * @description : Method to convert image to jpeg
    * * Date: 04/11/2024
    * Created By:Rachit Shah
    */
    async convertToJpeg(file) {
        const img = await this.loadImage(file);
        const size = Math.min(img.width, img.height);
        const canvas = document.createElement('canvas');
        const ctx = canvas.getContext('2d');
        canvas.width = size;
        canvas.height = size;

        const x = (img.width - size) / 2;
        const y = (img.height - size) / 2;
        ctx.drawImage(img, x, y, size, size, 0, 0, size, size);

        const jpegBlob = await this.picaInstance.toBlob(canvas, 'image/jpeg', 0.90);
        return new File([jpegBlob], file.name.replace(/\.[^/.]+$/, ".jpeg"), { type: 'image/jpeg' });
    }

    /**
    * Method Name : loadImage
    * @description : Method to load image
    * * Date: 04/11/2024
    * Created By:Rachit Shah
    */
    loadImage(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = (event) => {
                const img = new Image();
                img.onload = () => resolve(img);
                img.src = event.target.result;
            };
            reader.onerror = reject;
            reader.readAsDataURL(file);
        });
    }

    /**
    * Method Name : uploadToAWS
    * @description : Method to upload file to aws
    * * Date: 04/11/2024
    * Created By:Rachit Shah
    */
    async uploadToAWS() {
        this.initializeAwsSdk(this.confData);
        this.showSpinner = true;
        this.progressText = 'Uploading...';
        this.progressStyle = 'width: 0%';

        try {
            const totalFiles = this.allFilesData.length;
            const percentagePerFile = 100 / totalFiles;
            const fileProgressArray = new Array(totalFiles).fill(0); // Track progress for each file

            const uploadPromises = this.allFilesData.map((file, index) =>
                this.uploadFileToS3(file, percentagePerFile, index, fileProgressArray)
            );

            const results = await Promise.all(uploadPromises);

            this.fileURL = results.map(result => result.Location);
            this.awsObjectKeys = results.map(result => result.key);

            console.log('this.fileURL -> ', this.fileURL);
            console.log('JSON.stringify(this.fileURL) -> ', JSON.stringify(this.fileURL));
    
            return true;
        } catch (error) {
            console.error("Error during AWS upload:", error);
            return false;
        } finally {
            setTimeout(() => {
                this.progressText = 'Uploading Files...';
            }, 1000);
        }
    }

    /**
    * Method Name : uploadFileToS3
    * @description : Method to upload file to S3
    * * Date: 04/11/2024
    * Created By:Rachit Shah
    */
    uploadFileToS3(file, percentagePerFile, index, fileProgressArray) {
        const params = {
            Key: file.name,
            ContentType: file.type,
            Body: file,
            ACL: "public-read"
        };

        return this.s3.upload(params)
            .on('httpUploadProgress', (progress) => {
                const fileProgress = (progress.loaded / progress.total) * percentagePerFile;
                fileProgressArray[index] = fileProgress;

                const cumulativeProgress = fileProgressArray.reduce((acc, curr) => acc + curr, 0);
                this.uploadProgress = Math.min(100, Math.round(cumulativeProgress));

                this.progressText = `Uploading: ${this.uploadProgress}%`;
                this.progressStyle = `width: ${this.uploadProgress}%`;
            })
            .promise();
    }


    /**
    * Method Name : handlePost
    * @description : Method to upload handle posting to the instagram
    * * Date: 04/11/2024
    * Created By:Rachit Shah
    */
    async handlePost() {

        const captionInput = this.template.querySelector('[data-id="caption"]');

        captionInput.classList.remove('error-border');

        if (!this.selectedFilesToUpload.length && this.caption.trim() == '') {
            this.showToast('Error', 'Please select a file to upload and enter a caption.', 'error');
            captionInput.classList.add('error-border');
            return;
        }

        if (!this.selectedFilesToUpload.length) {
            this.showToast('Error', 'Please select a file to upload.', 'error');
            return;
        }

        if (this.selectedFilesToUpload.length > 10) {
            this.showToast('Error', 'You can upload a maximum of 10 files.', 'error');
            return;
        }

        if (this.caption.trim() == '') {
            this.showToast('Error', 'Please enter a caption.', 'error');
            captionInput.classList.add('error-border');
            return;
        }    
        
        console.log('this.confData -> ', this.confData);
        if (!this.confData || !this.confData.MVEX__AWS_Access_Key__c || !this.confData.MVEX__AWS_Secret_Access_Key__c || !this.confData.MVEX__S3_Bucket_Name__c || !this.confData.MVEX__S3_Region_Name__c) {
            this.showToast('Error', 'Please configure the S3 settings in the EstateXpert Settings.', 'error');
            return;
        }
    
        this.showSpinner = true;

        console.log('this.fileURL -> ', this.fileURL);
        console.log('JSON.stringify(this.fileURL) -> ', JSON.stringify(this.fileURL));

        const isSuccess = await this.uploadToAWS();

        if (!isSuccess) {
            this.showToast('Error', 'Failed to upload files to AWS.', 'error');
            return;
        }

        createInstagramContainer({ mediaUrls: this.fileURL, caption: this.caption })
            .then(result => {
                console.log('Container creation result -> ', result);
                if (result.success) {

                    console.log('Container created successfully:', result);
                    this.containerId = result.containerId || '';
                    this.containerIds = result.containerIds || [];
                    this.isCarousel = result.isCarousel || false;
                    this.showPublishButton = true;
                    this.showToast('Success', 'Media container created successfully. Click "Publish to Instagram" to complete the post.', 'success');
                } else {
                    this.showToast('Error', result.message, 'error');
                }
            })
            .catch(error => {
                console.error('Error creating Instagram container:', error);
                this.showToast('Error', 'Failed to create Instagram container.', 'error');
            }).finally(() => {
                this.showSpinner = false;
            });
    }
    
    /**
    * Method Name : handlePublish
    * @description : Method to publish the created container to Instagram
    * * Date: 04/11/2024
    * Created By:Rachit Shah
    */
    async handlePublish() {
        
        this.showSpinner = true;
        this.progressText = 'Publishing to Instagram...';
        
        
        publishToInstagram({ 
            containerId: this.containerId, 
            containerIds: this.containerIds, 
            isCarousel: this.isCarousel, 
            caption: this.caption, 
            awsObjectKeys: this.awsObjectKeys, 
            awsObjectKeysToPreserve: '' 
        })
        .then(result => {
            console.log('Publish to Instagram result -> ', result);
            this.showToast('Success', 'Post successfully published to Instagram.', 'success');
            this.clearFiles();
            this.showPublishButton = false;
        })
        .catch(error => {
            console.error('Error publishing to Instagram:', error);
            this.showToast('Error', 'Failed to publish to Instagram.', 'error');
        }).finally(() => {
            this.showSpinner = false;
        });
    }

    /**
    * Method Name : clearFiles
    * @description : Method to clear all data
    * * Date: 04/11/2024
    * Created By:Rachit Shah
    */
    clearFiles() {
        this.selectedFilesToUpload = [];
        this.allFilesData = [];
        this.caption = '';
        this.containerId = '';
        this.containerIds = [];
        this.isCarousel = false;
        this.showPublishButton = false;
        this.fileURL = [];
        this.awsObjectKeys = [];
    }

    /**
    * Method Name : resetFileInput
    * @description : Method to reset input file uploader
    * * Date: 04/11/2024
    * Created By:Rachit Shah
    */
    resetFileInput() {
        const fileSelectorInput = this.template.querySelector('.slds-file-selector__input');
        if (fileSelectorInput) {
            fileSelectorInput.value = null;
        }
    }

    /**
    * Method Name : showToast
    * @description : Method to show toast message
    * * Date: 04/11/2024
    * Created By:Rachit Shah
    */
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant,
        }));
    }

    /**
    * Method Name : backToControlCenter
    * @description : Method to to back to control center
    * * Date: 04/11/2024
    * Created By:Rachit Shah
    */
    backToControlCenter() {
        this[NavigationMixin.Navigate]({
            type: "standard__navItemPage",
            attributes: {
                apiName: "MVEX__Control_Center",
            },
        });
    }

    navigateToIntegrationPage() {
        let componentDef = {
            componentDef: "MVEX:socialMediaIntegration",
            attributes: {
                redirectto: "instagramPost"
            }
        };

        let encodedComponentDef = btoa(JSON.stringify(componentDef));
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: '/one/one.app#' + encodedComponentDef
            }
        });
    }
}