import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import saveTimesheetEntry from '@salesforce/apex/TimesheetController.saveTimesheetEntry';
import getCurrentTimesheet from '@salesforce/apex/TimesheetController.getCurrentTimesheet';
import getTimesheetEntries from '@salesforce/apex/TimesheetController.getTimesheetEntries';
import deleteTimesheetEntry from '@salesforce/apex/TimesheetController.deleteTimesheetEntry';
import USER_ID from '@salesforce/user/Id';

export default class ClockInOutComponent extends LightningElement {
    @track currentTime = new Date();
    @track currentStatus = 'Stopped';
    @track elapsedTime = '00:00:00';
    @track showModal = false;
    @track taskName = '';
    @track taskDescription = '';
    @track manualClockIn = '';
    @track manualClockOut = '';
    @track selectedDate = new Date().toISOString().split('T')[0];
    @track timesheetEntries = [];
    timerInterval;
    currentTimeInterval;

    get isClockInDisabled(){
        return this.currentStatus !== 'Stopped';
    }

    get isClockedIn() {
        return this.currentStatus === 'Clocked In';
    }

    get isPaused() {
        return this.currentStatus === 'Paused';
    }
    
    get isResumeButtonVisible() {
        return this.currentStatus === 'Paused';
    }

    get isPauseButtonVisible() {
        return this.currentStatus === 'Resumed' || this.currentStatus === 'Clocked In';
    }

    get isClockOutDisabled() {
        return this.currentStatus === 'Stopped';
    }

    connectedCallback() {
        this.loadTimerState();
        this.getCurrentTimesheetData();
        this.getTimesheetEntriesData();
        this.setIntervalForCurrentTime();
    }

    disconnectedCallback() {
        clearInterval(this.timerInterval);
    }

    getCurrentTimesheetData() {
        getCurrentTimesheet({ userId: USER_ID })
            .then(result => {
                if (result) {
                    this.currentStatus = result.MVEX__Status__c;
                    console.log('Current Status:', this.currentStatus);

                    this.taskName = result.MVEX__Task_Name__c || '';
                    console.log('Task Name:', this.taskName);
                    this.taskDescription = result.MVEX__Task_Description__c || '';
                    if (result.MVEX__Status__c === 'Clocked In' && result.MVEX__Clock_In__c) {
                        this.saveTimerState('Clocked In', result.MVEX__Clock_In__c);
                        this.startTimer();
                    } else if (result.MVEX__Status__c === 'Paused' && result.MVEX__Clock_In__c) {
                        this.saveTimerState('Paused', result.MVEX__Clock_In__c);
                    } else {
                        this.saveTimerState('Stopped');
                    }
                } else {
                    this.currentStatus = 'Stopped';

                    this.elapsedTime = '00:00:00';
                    this.stopTimer();
                }
            })
            .catch(error => {
                this.showToast('Error', 'Failed to load timesheet data: ' + error.body.message, 'error');
            });
    }

    getTimesheetEntriesData() {
        getTimesheetEntries({ userId: USER_ID, selectedDate: this.selectedDate })
            .then(entries => {
                this.timesheetEntries = this.processEntries(entries);                
            })
            .catch(error => {
                this.showToast('Error', 'Failed to load timesheet entries: ' + error.body.message, 'error');
            });
    }

    updateTime() {
        this.currentTime = new Date();
    }

    setIntervalForCurrentTime() {
        if (this.currentTimeInterval) {
            clearInterval(this.currentTimeInterval);
        }
        this.currentTimeInterval = setInterval(() => {
            this.updateTime();
        }, 1000);
    }

    updateElapsedTime() {
        const state = JSON.parse(localStorage.getItem('timerState') || '{}');
        if (state.status === 'Clocked In' && state.startTime) {
            const start = new Date(state.startTime);
            const now = new Date();
            if (!isNaN(start.getTime())) {
                const diffMs = now.getTime() - start.getTime();
                const diffSec = Math.floor(diffMs / 1000);
                const hours = Math.floor(diffSec / 3600).toString().padStart(2, '0');
                const minutes = Math.floor((diffSec % 3600) / 60).toString().padStart(2, '0');
                const seconds = (diffSec % 60).toString().padStart(2, '0');
                this.elapsedTime = `${hours}:${minutes}:${seconds}`;
            } else {
                this.elapsedTime = '00:00:00';
                this.saveTimerState('Stopped');
            }
        } else if (state.status === 'Paused' && state.elapsedTime) {
            this.elapsedTime = state.elapsedTime; // Preserve elapsed time when paused
        } else {
            this.elapsedTime = '00:00:00';
        }
    }

    loadTimerState() {
        const state = JSON.parse(localStorage.getItem('timerState') || '{}');
        if (state.status) {
            this.currentStatus = state.status;
            if (state.status === 'Clocked In' && state.startTime) {
                const start = new Date(state.startTime);
                if (!isNaN(start.getTime())) {
                    this.updateElapsedTime();
                    this.startTimer();
                } else {
                    this.saveTimerState('Stopped');
                }
            } else if (state.status === 'Paused' && state.elapsedTime) {                
                this.elapsedTime = state.elapsedTime;
            } else if (state.status === 'Stopped') {
                this.elapsedTime = '00:00:00';
                this.stopTimer();
            }
        } else {
            this.saveTimerState('Stopped');
        }
    }

    saveTimerState(status, startTime = null) {
        const state = {
            status,
            startTime: startTime ? new Date(startTime).toISOString() : null,
            elapsedTime: this.elapsedTime
        };
        localStorage.setItem('timerState', JSON.stringify(state));
        this.currentStatus = status;
        if (status === 'Stopped') {
            this.elapsedTime = '00:00:00';
            this.stopTimer();
        }
    }

    processEntries(entries) {
        return entries.map(entry => {
            let formattedDuration = '-';
            if (entry.MVEX__Total_Session_Duration__c) {
                const durationMinutes = Math.floor(entry.MVEX__Total_Session_Duration__c); // Total duration in minutes
                const hours = Math.floor(durationMinutes / 60); // Calculate hours
                const minutes = durationMinutes % 60; // Calculate remaining minutes
    
                // Dynamically format the duration
                if (hours > 0) {
                    formattedDuration = `${hours} Hours`;
                    if (minutes > 0) {
                        formattedDuration += ` ${minutes} Minutes`;
                    }
                } else {
                    formattedDuration = `${minutes} Minutes`;
                }
            }            
            return {
                ...entry,
                UserName: entry.MVEX__User__r.Name || '',
                MVEX__Total_Session_Duration__c: entry.MVEX__Total_Session_Duration__c || 0,
                formattedDuration
            };
        });
    }

    handleClockIn() {
        if (this.isClockedIn || this.isPaused) {
            this.showToast('Error', 'Cannot clock in while already clocked in or paused.', 'error');
            return;
        }

        if(!this.taskName || this.taskName.trim() === '') {
            this.showToast('Error', 'Please enter a task name before clocking in.', 'error');
            return;
        }
        
        const now = new Date().toISOString();
        saveTimesheetEntry({
            userId: USER_ID,
            clockIn: now,
            status: 'Clocked In',
            taskName: this.taskName,
            taskDescription: null,
            isMannual: false
        })
        .then(() => {
            this.saveTimerState('Clocked In', now);
            this.startTimer();
            this.showToast('Success', 'Clocked in successfully', 'success');
            this.getTimesheetEntriesData();
        })
        .catch(error => {
            this.showToast('Error', 'Failed to clock in: ' + error.body.message, 'error');
        });
    }

    handleClockOut() {
        if (!this.isClockedIn && !this.isPaused) {
            this.showToast('Error', 'No active session to clock out.', 'error');
            return;
        }
        const now = new Date().toISOString();
        saveTimesheetEntry({
            userId: USER_ID,
            clockOut: now,
            status: 'Stopped',
            taskName: null,
            taskDescription: null,
            isMannual: false
        })
        .then(() => {
            this.stopTimer();
            this.saveTimerState('Stopped');
            this.taskName = '';
            this.taskDescription = '';
            this.showToast('Success', 'Clocked out successfully', 'success');
            this.getTimesheetEntriesData();
        })
        .catch(error => {
            this.showToast('Error', 'Failed to clock out: ' + error.body.message, 'error');
        });
    }

    handlePause() {
        if (!this.isClockedIn || this.isPaused) {
            this.showToast('Error', 'Cannot pause unless clocked in.', 'error');
            return;
        }
        const now = new Date().toISOString();
        saveTimesheetEntry({
            userId: USER_ID,
            clockIn: now,
            status: 'Paused',
            taskName: null,
            taskDescription: null,
            isMannual: false
        })
        .then(() => {                        
            this.stopTimer();
            this.saveTimerState('Paused');
            this.showToast('Success', 'Timer paused', 'success');
            this.getTimesheetEntriesData();
        })
        .catch(error => {
            this.showToast('Error', 'Failed to pause: ' + error.body.message, 'error');
        });
    }

    handleResume() {
        if (!this.isPaused) {
            this.showToast('Error', 'Cannot resume unless paused.', 'error');
            return;
        }
        const now = new Date();
        const state = JSON.parse(localStorage.getItem('timerState') || '{}');
        const savedElapsedTime = state.elapsedTime || '00:00:00';
        const [hours, minutes, seconds] = savedElapsedTime.split(':').map(Number);
        const savedElapsedSeconds = hours * 3600 + minutes * 60 + seconds;
        const startTime = new Date(now.getTime() - savedElapsedSeconds * 1000);

        saveTimesheetEntry({
            userId: USER_ID,
            clockIn: now.toISOString(),
            status: 'Resumed',
            taskName: null,
            taskDescription: null,
            isMannual: false
        })
        .then(() => {
            this.saveTimerState('Clocked In', startTime.toISOString());
            this.startTimer();
            this.showToast('Success', 'Timer resumed', 'success');
            this.getTimesheetEntriesData();
        })
        .catch(error => {
            this.showToast('Error', 'Failed to resume: ' + error.body.message, 'error');
        });
    }

    openModal() {
        this.showModal = true;
        this.taskName = '';
        this.taskDescription = '';
        this.manualClockIn = '';
        this.manualClockOut = '';
    }

    closeModal() {
        this.showModal = false;
    }

    handleInputChange(event) {
        const fieldName = event.target.dataset.name;
        this[fieldName] = event.target.value;
    }

    saveManualEntry() {
        const inputs = this.template.querySelectorAll('.modal-input');
        let isValid = true;

        const taskNameRegex = /^[a-zA-Z0-9\s-]{1,50}$/;

        inputs.forEach(input => {
            const field = input.dataset.name;
            const value = input.value.trim();            
            switch (field) {
                case 'taskName':
                    if (!taskNameRegex.test(value) || !value) {
                        input.setCustomValidity('Task Name must be 1-50 alphanumeric characters, spaces, or hyphens.');
                        isValid = false;
                    } else {
                        input.setCustomValidity('');
                    }
                    break;
                case 'manualClockIn':
                    if (value.trim() == '' || !value) {
                        input.setCustomValidity('Please enter a valid datetime (YYYY-MM-DDTHH:MM).');
                        isValid = false;
                    } else {
                        input.setCustomValidity('');
                    }
                    break;
                case 'manualClockOut':
                    if (value.trim() == '' || !value) {
                        input.setCustomValidity('Please enter a valid datetime (YYYY-MM-DDTHH:MM).');
                        isValid = false;
                    } else {
                        input.setCustomValidity('');
                    }
                    break;
                default:
                    break;
            }
            input.reportValidity();
        });

        if (isValid) {
            saveTimesheetEntry({
                userId: USER_ID,
                clockIn: this.manualClockIn,
                clockOut: this.manualClockOut || null,
                status: 'Stopped',
                taskName: this.taskName,
                taskDescription: this.taskDescription,
                isMannual : true
            })
            .then(() => {
                this.showToast('Success', 'Manual entry saved', 'success');
                this.closeModal();
                this.getTimesheetEntriesData();
            })
            .catch(error => {
                this.showToast('Error', 'Failed to save manual entry: ' + error.body.message, 'error');
            });
        }
    }

    handleDateChange(event) {
        this.selectedDate = event.target.value;
        this.getTimesheetEntriesData();
    }

    handleDelete(event) {
        const entryId = event.target.dataset.id;
        deleteTimesheetEntry({ sessionId: entryId })
            .then(() => {
                this.showToast('Success', 'Timesheet entry deleted', 'success');
                this.getTimesheetEntriesData();
            })
            .catch(error => {
                this.showToast('Error', 'Failed to delete entry: ' + error.body.message, 'error');
            });
    }

    startTimer() {
        if (this.isPaused || !this.isClockInDisabled || this.timerInterval) {
            return;
        }
        this.timerInterval = setInterval(() => {
            this.updateTime();
            this.updateElapsedTime();
        }, 1000);
    }

    stopTimer() {
        if (this.timerInterval) {
            clearInterval(this.timerInterval);
            this.timerInterval = null;
        }
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({ title, message, variant });
        this.dispatchEvent(event);
    }
}