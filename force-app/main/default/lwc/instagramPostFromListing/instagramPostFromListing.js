import { LightningElement, track, wire } from 'lwc';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';
import getS3ConfigSettings from "@salesforce/apex/ImageAndMediaController.getS3ConfigSettings";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { loadStyle, loadScript } from 'lightning/platformResourceLoader';
import picaLib from '@salesforce/resourceUrl/imageConverter';
import AWS_SDK from "@salesforce/resourceUrl/AWSSDK";
import NoUploadImage from "@salesforce/resourceUrl/NoUploadImage";
import { CurrentPageReference } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';
import postToInstagram from '@salesforce/apex/InstagramPostController.postToInstagram';
import getPropertyMediaUrls from '@salesforce/apex/InstagramPostController.getPropertyMediaUrls';
import checkInstagramIntegration from '@salesforce/apex/InstagramPostController.checkInstagramIntegration';

export default class InstagramPostFromListing extends LightningElement {

    @track listingId;
    @track confData;
    @track s3;
    @track showSpinner = false;
    @track isLoading = true;
    @track selectedFilesToUpload = [];
    @track fileURLs = [];
    @track awsObjectKeysToPreserve = [];
    @track awsObjectKeys = [];
    @track selectedFileWithPreview = [];
    @track largeImageFiles = [];
    @track isContentVersionDataIsAvailable = false;
    @track isAwsSdkInitialized = true;
    @track picaInstance;
    @track caption = '';
    @track noUploadImageLink = NoUploadImage;
    @track progressText = 'Uploading Files...';
    @track progressStyle = 'width: 0%';
    @track hasAWSCredentials = false;
    @track hasInstagramCredentials = false;
    @track invalidVideoDuration = [];
    @track invalidVideoSize = [];

    get isFileAvailable() {
        return this.selectedFileWithPreview.length > 0;
    }

    get hasAllCredentials() {
        return this.hasAWSCredentials && this.hasInstagramCredentials;
    }

    get missingCredentialsMessage() {
        if (!this.hasAWSCredentials && !this.hasInstagramCredentials) {
            return 'AWS and Instagram credentials are required to upload media.';
        } else if (!this.hasAWSCredentials) {
            return 'AWS credentials are required to upload media.';
        } else if (!this.hasInstagramCredentials) {
            return 'Instagram credentials are required to upload media.';
        }
        return '';
    }

    get isUploadDisabled() {
        return !this.isFileAvailable;
    }

    get uploadButtonClass() {
        return this.isFileAvailable
            ? 'upload-button upload-button-enabled'
            : 'upload-button upload-button-disabled';
    }

    get submitContainerClass() {
        return this.isFileAvailable
            ? 'submit-button-selected'
            : 'submit-button-empty';
    }

    @wire(CurrentPageReference)
    setCurrentPageReference(pageRef) {
        if (pageRef && pageRef.state && pageRef.state.recordId) {
            this.listingId = pageRef.state.recordId;
            console.log('listingId-->', this.listingId);
            this.fetchPropertyMediaUrls();
        }
    }

    /**
    * Method Name: ConnectedCallback
    * @description: Standard ConnectedCallback method which executes when the component is loaded
    * Date: 24/10/2024
    * Created By: Rachit Shah
    * Last modified by : Rachit Shah
    */
    connectedCallback() {
        loadStyle(this, MulishFontCss)
            .then(() => {
                console.log('Css loaded successfully');
            })
            .catch(error => {
                console.log('Error loading Css', error);
            });

        this.getS3ConfigDataAsync();
        this.checkInstagramCredentials();

    }

    renderedCallback() {
        try {
            if (this.isAwsSdkInitialized) {
                Promise.all([loadScript(this, AWS_SDK), loadScript(this, picaLib)])
                    .then(() => {
                        console.log('Script loaded successfully');
                        this.picaInstance = window.pica();
                    })
                    .catch((error) => {
                        console.error("error -> ", error);
                    });

                this.isAwsSdkInitialized = false;
            }
        } catch (error) {
            console.log('error in renderedcallback -> ', error);
        }
    }

    fetchPropertyMediaUrls() {
        if (this.listingId) {
            getPropertyMediaUrls({ listingId: this.listingId })
                .then(result => {
                    console.log('result-->', result);
                    for (const key in result) {
                        if (Object.prototype.hasOwnProperty.call(result, key)) {
                            const fileUrl = result[key];

                            const jpegFile = {
                                name: key,
                                size: 0,
                                preview: fileUrl,
                                isDelete: false
                            };
                            this.awsObjectKeysToPreserve.push(key);
                            this.fileURLs.push(fileUrl);
                            this.selectedFileWithPreview.push(jpegFile);
                        }
                    }
                })
                .catch(error => {
                    this.error = error;
                    console.error('Error fetching media URLs:', error);
                });
        }
    }

    getS3ConfigDataAsync() {
        try {
            getS3ConfigSettings()
                .then(result => {
                    console.log('result--> ', result);
                    if (result.status) {
                        this.confData = result.awsConfigData;
                        this.isContentVersionDataIsAvailable = result.contentVersionData !== '' ? true : false;
                        this.hasAWSCredentials = true;
                        this.initializeAwsSdk(this.confData);
                    } else {
                        this.hasAWSCredentials = false;
                        console.log('AWS credentials not configured');
                    }
                    this.isLoading = false;
                }).catch(error => {
                    this.hasAWSCredentials = false;
                    console.log('error in apex -> ', error.stack);
                    this.isLoading = false;
                });
        } catch (error) {
            this.hasAWSCredentials = false;
            console.log('error in getS3ConfigDataAsync -> ', error.stack);
            this.isLoading = false;
        }
    }

    checkInstagramCredentials() {
        try {
            checkInstagramIntegration()
                .then(result => {
                    this.hasInstagramCredentials = result;
                    if (!result) {
                        console.log('Instagram credentials not configured');
                    }
                    this.isLoading = false;
                })
                .catch(error => {
                    this.hasInstagramCredentials = false;
                    console.log('error checking Instagram credentials -> ', error);
                    this.isLoading = false;
                });
        } catch (error) {
            this.hasInstagramCredentials = false;
            console.log('error in checkInstagramCredentials -> ', error.stack);
            this.isLoading = false;
        }
    }

    initializeAwsSdk(confData) {
        try {
            let AWS = window.AWS;

            AWS.config.update({
                accessKeyId: confData.MVEX__AWS_Access_Key__c,
                secretAccessKey: confData.MVEX__AWS_Secret_Access_Key__c
            });

            AWS.config.region = confData.MVEX__S3_Region_Name__c;

            this.s3 = new AWS.S3({
                apiVersion: "2006-03-01",
                params: {
                    Bucket: confData.MVEX__S3_Bucket_Name__c
                }
            });


        } catch (error) {
            this.showSpinner = false;
            console.log("error initializeAwsSdk ", error);
        }
    }

    async handleDrop(event) {
        event.preventDefault();
        try {
            const files = event.dataTransfer.files;
            this.isImageData = true;
            this.largeImageFiles = [];
            this.invalidVideoDuration = [];
            const fileProcessingPromises = [];
            let invalidFileTypes = [];

            // Check if adding files would exceed 10 file limit
            const totalFilesAfter = this.selectedFileWithPreview.length + files.length;
            if (totalFilesAfter > 10) {
                this.showToast('Error', `Cannot add ${files.length} files. Maximum 10 files allowed.`, 'error');
                return;
            }

            // It's a carousel if: there are already existing files, OR multiple files are being added together
            const isCarousel = this.selectedFileWithPreview.length > 0 || files.length > 1;

            for (let i = 0; i < files.length; i++) {
                const file = files[i];
                const isValidFileType = ['image/png', 'image/jpg', 'image/jpeg', 'video/mp4'].includes(file.type);
                const fileSizeInKB = Math.floor(file.size / 1024);
                const isAllowedSize = file.type === 'video/mp4'
                    ? fileSizeInKB <= 25000  // Updated to 25MB for consistency
                    : fileSizeInKB <= 8000;

                if (!isValidFileType) {
                    invalidFileTypes.push(file.name);
                    continue;
                }

                // For videos, validate duration with explicit carousel flag
                if (file.type === 'video/mp4') {
                    const validation = await this.validateVideo(file, isCarousel);
                    if (!validation.isValid) {
                        this.invalidVideoDuration.push(validation.errorMessage);
                        continue;
                    }
                }

                if (isAllowedSize) {
                    if (this.picaInstance && file.type !== 'video/mp4') {
                        const jpegFilePromise = this.convertToJpeg(file).then(jpegFile => {
                            this.selectedFilesToUpload.push(jpegFile);
                            return {
                                name: jpegFile.name,
                                size: jpegFile.size,
                                preview: URL.createObjectURL(jpegFile),
                                isDelete: true
                            };
                        });
                        fileProcessingPromises.push(jpegFilePromise);
                    } else {
                        const thumbnailPromise = this.createThumbnail(file).then(preview => {
                            this.selectedFilesToUpload.push(file);
                            return {
                                name: file.name,
                                size: file.size,
                                preview: preview,
                                isDelete: true
                            };
                        });
                        fileProcessingPromises.push(thumbnailPromise);
                    }
                } else {
                    this.largeImageFiles.push(file.name);
                }
            }

            const fileDataArray = await Promise.all(fileProcessingPromises);
            this.selectedFileWithPreview = [...this.selectedFileWithPreview, ...fileDataArray];

            if (invalidFileTypes.length > 0) {
                this.showToast('Error', `Invalid file types: ${invalidFileTypes.join(', ')}`, 'error');
            }

            if (this.invalidVideoDuration.length > 0) {
                this.showToast('Error', `Video validation errors:\n${this.invalidVideoDuration.join('\n')}`, 'error');
            }

            if (this.largeImageFiles.length > 0) {
                this.showToast('Error', `File(s) too large: ${this.largeImageFiles.join(', ')}`, 'error');
            }

            console.log('selectedFileWithPreview:', this.selectedFileWithPreview);
            console.log('selectedFilesToUpload:', this.selectedFilesToUpload);

        } catch (error) {
            console.error('Error in file drop handling:', error.stack);
        }
    }

    async convertToJpeg(file) {

        try {
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
        } catch (error) {
            console.log('error in convertToJpeg -> ', error.stack);
        }
    }

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

    allowDrop(event) {
        event.preventDefault();
    }

    handleCaptionChange(event) {
        const caption = event.target.value;
        this.caption = caption;
    }

    /**
     * Get video duration in seconds
     * @param {File} file - Video file
     * @returns {Promise<number>} Duration in seconds
     */
    getVideoDuration(file) {
        return new Promise((resolve, reject) => {
            try {
                const video = document.createElement('video');
                const objectUrl = URL.createObjectURL(file);
                video.src = objectUrl;

                video.addEventListener('loadedmetadata', () => {
                    URL.revokeObjectURL(objectUrl);
                    resolve(video.duration);
                });

                video.addEventListener('error', () => {
                    URL.revokeObjectURL(objectUrl);
                    reject(new Error('Failed to load video metadata'));
                });

                // Set a timeout to handle cases where metadata never loads
                setTimeout(() => {
                    URL.revokeObjectURL(objectUrl);
                    reject(new Error('Video metadata timeout'));
                }, 10000);
            } catch (error) {
                reject(error);
            }
        });
    }

    /**
     * Determine if current selection is a carousel (multiple files) or single video
     * @returns {boolean} True if carousel, False if single video
     */
    isCarouselPost() {
        const totalMedia = this.selectedFileWithPreview.length + this.selectedFilesToUpload.length;
        return totalMedia > 1 || (totalMedia === 1 && this.selectedFilesToUpload.some(f => f.type !== 'video/mp4'));
    }

    /**
     * Validate video based on carousel or single video rules
     * @param {File} file - Video file to validate
     * @param {boolean} isCarousel - Explicitly indicate if this is a carousel post (if null, auto-detect)
     * @returns {Promise<Object>} Validation result { isValid, errorMessage, duration }
     */
    async validateVideo(file, isCarousel = null) {
        try {
            const duration = await this.getVideoDuration(file);
            const fileSizeInMB = file.size / (1024 * 1024);
            
            let willBeCarousel;
            if (isCarousel !== null) {
                willBeCarousel = isCarousel;
            } else {
                willBeCarousel = this.selectedFileWithPreview.length > 0 || this.selectedFilesToUpload.length > 0;
            }
            
            if (willBeCarousel) {
                // Carousel rules: 60s max, 3s min, 25MB max
                if (duration < 3) {
                    return {
                        isValid: false,
                        errorMessage: `${file.name}: Video duration is too short (minimum 3 seconds for carousel)`,
                        duration
                    };
                }
                if (duration > 60) {
                    return {
                        isValid: false,
                        errorMessage: `${file.name}: Video duration exceeds 60 seconds for carousel posts`,
                        duration
                    };
                }
                if (fileSizeInMB > 25) {
                    return {
                        isValid: false,
                        errorMessage: `${file.name}: Video file size exceeds 25MB for carousel posts`,
                        duration
                    };
                }
            } else {
                // Single video rules: 15 min (900s) max, 3s min, 25MB max
                if (duration < 3) {
                    return {
                        isValid: false,
                        errorMessage: `${file.name}: Video duration is too short (minimum 3 seconds)`,
                        duration
                    };
                }
                if (duration > 900) {
                    return {
                        isValid: false,
                        errorMessage: `${file.name}: Video duration exceeds 15 minutes for single video posts`,
                        duration
                    };
                }
                if (fileSizeInMB > 25) {
                    return {
                        isValid: false,
                        errorMessage: `${file.name}: Video file size exceeds 25MB`,
                        duration
                    };
                }
            }

            return {
                isValid: true,
                duration
            };
        } catch (error) {
            return {
                isValid: false,
                errorMessage: `${file.name}: Failed to validate video - ${error.message}`,
                duration: 0
            };
        }
    }

    async handleSelectedFiles(event) {
        try {
            if (event.target.files && event.target.files.length > 0) {
                const files = event.target.files;
                this.isImageData = true;
                this.largeImageFiles = [];
                this.invalidVideoDuration = [];
                this.invalidVideoSize = [];

                // Check if adding files would exceed 10 file limit
                const totalFilesAfter = this.selectedFileWithPreview.length + files.length;
                if (totalFilesAfter > 10) {
                    this.showToast('Error', `Cannot add ${files.length} files. Maximum 10 files allowed.`, 'error');
                    this.template.querySelector('.slds-file-selector__input').value = null;
                    return;
                }

                // Determine if this will be a carousel post
                // It's a carousel if: there are already existing files, OR multiple files are being added together
                const isCarousel = this.selectedFileWithPreview.length > 0 || files.length > 1;

                const fileProcessingPromises = [];

                for (let i = 0; i < files.length; i++) {
                    const file = files[i];
                    const fileType = file.type;
                    const fileSizeInKB = Math.floor(file.size / 1024);
                    const fileSizeInMB = file.size / (1024 * 1024);
                    
                    // Check basic file size limits
                    const isAllowedSize = fileType === 'video/mp4'
                        ? fileSizeInKB <= 25000  // 25MB for videos
                        : fileSizeInKB <= 8000;   // 8MB for images

                    // For videos, validate duration with explicit carousel flag
                    if (fileType === 'video/mp4') {
                        const validation = await this.validateVideo(file, isCarousel);
                        if (!validation.isValid) {
                            this.invalidVideoDuration.push(validation.errorMessage);
                            continue;
                        }
                    }

                    if (isAllowedSize) {
                        if (this.picaInstance && file.type !== 'video/mp4') {
                            const jpegFilePromise = this.convertToJpeg(file).then(jpegFile => {
                                this.selectedFilesToUpload.push(jpegFile);
                                return {
                                    name: jpegFile.name,
                                    size: jpegFile.size,
                                    preview: URL.createObjectURL(jpegFile),
                                    isDelete: true
                                };
                            });
                            fileProcessingPromises.push(jpegFilePromise);
                        } else {
                            const thumbnailPromise = this.createThumbnail(file).then(preview => {
                                this.selectedFilesToUpload.push(file);
                                return {
                                    name: file.name,
                                    size: file.size,
                                    preview: preview,
                                    isDelete: true
                                };
                            });
                            fileProcessingPromises.push(thumbnailPromise);
                        }
                    } else {
                        this.largeImageFiles.push(file.name);
                    }
                }

                const fileDataArray = await Promise.all(fileProcessingPromises);
                this.selectedFileWithPreview = [...this.selectedFileWithPreview, ...fileDataArray];

                // Show error messages for invalid files
                if (this.invalidVideoDuration.length > 0) {
                    this.showToast('Error', `Video validation errors:\n${this.invalidVideoDuration.join('\n')}`, 'error');
                }

                if (this.largeImageFiles.length > 0) {
                    this.showToast('Error', `File(s) too large: ${this.largeImageFiles.join(', ')}`, 'error');
                }
            }

            this.template.querySelector('.slds-file-selector__input').value = null;

            console.log('selectedFileWithPreview:', this.selectedFileWithPreview);
            console.log('selectedFilesToUpload:', this.selectedFilesToUpload);

        } catch (error) {
            console.error('Error in file upload:', error.stack);
        }
    }


    createThumbnail(file) {
        return new Promise((resolve, reject) => {
            try {
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

                        const thumbnailDataUrl = canvas.toDataURL('image/jpeg');
                        console.log('canvas.toDataURL-->', thumbnailDataUrl);

                        resolve(thumbnailDataUrl);
                    });
                });

                video.onerror = () => {
                    reject('Error loading video file');
                };
            } catch (error) {
                reject(`Error in createThumbnail -> ${error.stack}`);
            }
        });
    }

    handleDragStart(event) {
        const index = event.target.dataset.index;
        event.dataTransfer.setData('index', index);

        event.target.classList.add('dragging');
    }

    handleDragEnter(event) {
        event.preventDefault();
        const dropTarget = event.target.closest(".dropableimage");
        if (dropTarget) {
            dropTarget.classList.add('highlight');
        }
    }

    handleDragLeave(event) {
        event.preventDefault();
        const dropTarget = event.target.closest(".dropableimage");
        if (dropTarget) {
            dropTarget.classList.remove('highlight');
        }
    }

    handleDragEnd(event) {
        event.target.classList.remove('dragging');
        this.template.querySelectorAll('.dropableimage').forEach(el => el.classList.remove('highlight'));
    }


    handleDropImages(event) {
        event.preventDefault();

        const draggedIndex = parseInt(event.dataTransfer.getData('index'), 10);
        const droppedIndex = parseInt(event.target.closest('.dropableimage').dataset.index, 10);

        if (draggedIndex !== droppedIndex) {
            const draggedFile = this.selectedFileWithPreview.splice(draggedIndex, 1)[0];
            this.selectedFileWithPreview.splice(droppedIndex, 0, draggedFile);

        }

        console.log('selectedFileWithPreview-->', this.selectedFileWithPreview);
        console.log('JSON selectedFileWithPreview-->', JSON.stringify(this.selectedFileWithPreview));

        this.template.querySelectorAll('.highlight').forEach(el => el.classList.remove('highlight'));
        this.template.querySelectorAll('.dragging').forEach(el => el.classList.remove('dragging'));

    }

    handleDragOver(event) {
        event.preventDefault();
        event.target.classList.add('drag-over');
    }

    handleRemoveFile(event) {

        console.log('fileURLs BEFORE ==> ', this.fileURLs.length);

        const fileNameToRemove = event.currentTarget.dataset.name;

        const selectedFileURL = this.selectedFileWithPreview.find(file => file.name === fileNameToRemove);

        if (selectedFileURL) {
            this.fileURLs = this.fileURLs.filter(file => file !== selectedFileURL.preview);
        }

        this.selectedFileWithPreview = this.selectedFileWithPreview.filter(file => file.name !== fileNameToRemove);
        this.selectedFilesToUpload = this.selectedFilesToUpload.filter(file => file.name !== fileNameToRemove);

        console.log('fileURLs AFTER ==> ', this.fileURLs.length);
    }

    async handlePost() {
        const totalFiles = this.fileURLs.length + this.selectedFilesToUpload.length;

        if (totalFiles === 0) {
            this.showToast('Error', 'Please select a file to upload.', 'error');
            return;
        }

        if (totalFiles > 10) {
            this.showToast('Error', 'You can upload maximum 10 files.', 'error');
            return;
        }

        const isSuccess = await this.uploadToAWS();

        if (isSuccess) {
            postToInstagram({ mediaUrls: this.fileURLs, caption: this.caption, awsObjectKeys: this.awsObjectKeys, awsObjectKeysToPreserve: this.awsObjectKeysToPreserve })
                .then(result => {
                    console.log('Post to Instagram result -> ', result);
                    if (result.status === 'SUCCESS') {
                        this.showToast('Success', result.message, 'success');
                        this.clearFiles();
                        this.closeAction();
                    } else {
                        this.showToast('Error', result.message, 'error');
                    }
                    this.showSpinner = false;
                    this.isLoading = false;
                })
                .catch(error => {
                    console.error('Error posting to Instagram:', error);
                    this.showToast('Error', 'Failed to post to Instagram.', 'error');
                    this.showSpinner = false;
                    this.isLoading = false;
                });
        }
        else {
            this.showToast('Error', 'Error during uploading files', 'error');
        }


    }

    clearFiles() {
        this.selectedFilesToUpload = [];
        this.selectedFileWithPreview = [];
        this.allFilesData = [];
        this.caption = '';
        this.fileURLs = [];
        this.awsObjectKeys = [];
        this.awsObjectKeysToPreserve = [];
    }

    async uploadToAWS() {
        console.log('uploadToAWS-->');

        if (this.selectedFilesToUpload.length > 0) {
            this.initializeAwsSdk(this.confData);
            this.showSpinner = true;
            this.isLoading = true;
            this.progressText = 'Uploading...';
            this.progressStyle = 'width: 0%';

            try {
                const totalFiles = this.selectedFilesToUpload.length;
                const percentagePerFile = 100 / totalFiles;
                const fileProgressArray = new Array(totalFiles).fill(0);

                const uploadPromises = this.selectedFilesToUpload
                    .filter(file => file.size > 0)
                    .map((file, index) =>
                        this.uploadFileToS3(file, percentagePerFile, index, fileProgressArray)
                    );

                const results = await Promise.all(uploadPromises);

                this.selectedFileWithPreview.forEach(file => {
                    const result = results.find(res => res.key === file.name);
                    console.log('JSON-->', JSON.stringify(result));


                    if (result) {
                        file.preview = result.Location;
                    }
                });

                this.fileURLs = this.selectedFileWithPreview.map(file => file.preview);
                this.awsObjectKeys = results.map(result => result.key);

                return true;
            } catch (error) {
                console.error("Error during AWS upload:", error);
                console.log('Error Stack-->', error.stack);

                return false;
            } finally {
                setTimeout(() => {
                    this.progressText = 'Uploading Files...';
                }, 1000);
            }
        }
        else {
            return true;
        }

    }
    uploadFileToS3(file, percentagePerFile, index, fileProgressArray) {
        return new Promise((resolve, reject) => {
            try {
                const params = {
                    Key: file.name,
                    ContentType: file.type,
                    Body: file,
                    ACL: "public-read"
                };

                this.s3.upload(params)
                    .on('httpUploadProgress', (progress) => {
                        const fileProgress = (progress.loaded / progress.total) * percentagePerFile;
                        fileProgressArray[index] = fileProgress;

                        const cumulativeProgress = fileProgressArray.reduce((acc, curr) => acc + curr, 0);
                        this.uploadProgress = Math.min(100, Math.round(cumulativeProgress));

                        this.progressText = `Uploading: ${this.uploadProgress}%`;
                        this.progressStyle = `width: ${this.uploadProgress}%`;
                    })
                    .promise()
                    .then(response => {
                        console.log("AWS Upload Response:", response);
                        resolve({
                            key: response.Key,
                            Location: response.Location
                        });
                    })
                    .catch(error => {
                        console.error('Error in uploadFileToS3-->', error.stack);
                        reject(error);
                    });
            } catch (error) {
                console.error('Error in uploadFileToS3-->', error.stack);
                reject(error);
            }
        });
    }


    showToast(title, message, variant) {
        if (typeof window !== 'undefined') {
            const event = new ShowToastEvent({
                title: title,
                message: message,
                variant: variant,
            });
            this.dispatchEvent(event);
        }
    }

    closeAction() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

}