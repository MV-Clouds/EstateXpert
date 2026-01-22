import { LightningElement, track } from 'lwc';
import { loadScript, loadStyle } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import calculateAgentCommissions from '@salesforce/apex/AgentCommissionReportController.calculateAgentCommissions';
import getRolesAndUsers from '@salesforce/apex/AgentCommissionReportController.getRolesAndUsers';
import getMetadataRecords from '@salesforce/apex/ControlCenterController.getMetadataRecords';
import ECHARTS from '@salesforce/resourceUrl/echarts';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';

export default class AgentCommissionReport extends LightningElement {
    @track dateRange = 'Last 30 Days';
    @track closingType = 'All Closings';
    @track displayType = 'Datatable';
    @track showCustomDate = false;
    @track startDate;
    @track endDate;
    @track commissionData = [];
    @track filteredCommissionData = [];
    @track isLoading = true;
    @track sortField = '';
    @track sortDirection = 'asc';
    @track selectedRole = 'All';
    @track selectedUser = 'All';
    @track agentNameSearch = '';
    @track showMoreFilters = false;
    @track roleOptions = [];
    @track userOptions = [];
    @track currencyCode = 'AED';
    @track usersByRoleMap = {};
    @track isAccessible = false;

    constructor() {
        super();
        this.handleOutsideClick = this.handleOutsideClick.bind(this);
    }

    dateRangeOptions = [
        { id: '1', label: 'Lifetime', value: 'Lifetime' },
        { id: '2', label: 'Custom', value: 'Custom' },
        {
            id: '3',
            groupName: 'Fiscal Year',
            childs: [
                { id: '1', label: 'Current FY', value: 'Current FY' },
                { id: '2', label: 'Previous FY', value: 'Previous FY' },
                { id: '3', label: 'Previous 2 FY', value: 'Previous 2 FY' }
            ]
        },
        {
            id: '4',
            groupName: 'Fiscal Quarter',
            childs: [
                { id: '1', label: 'Current FQ', value: 'Current FQ' },
                { id: '2', label: 'Current and Next FQ', value: 'Current and Next FQ' },
                { id: '3', label: 'Current and Previous FQ', value: 'Current and Previous FQ' },
                { id: '4', label: 'Previous FQ', value: 'Previous FQ' },
                { id: '5', label: 'Next FQ', value: 'Next FQ' }
            ]
        },
        {
            id: '5',
            groupName: 'Calendar Year',
            childs: [
                { id: '1', label: 'Current CY', value: 'Current CY' },
                { id: '2', label: 'Previous CY', value: 'Previous CY' }
            ]
        },
        {
            id: '6',
            groupName: 'Calendar Month',
            childs: [
                { id: '1', label: 'Last Month', value: 'Last Month' },
                { id: '2', label: 'This Month', value: 'This Month' }
            ]
        },
        {
            id: '7',
            groupName: 'Day',
            childs: [
                { id: '1', label: 'Last 7 Days', value: 'Last 7 Days' },
                { id: '2', label: 'Last 30 Days', value: 'Last 30 Days' },
                { id: '3', label: 'Last 60 Days', value: 'Last 60 Days' },
                { id: '4', label: 'Last 90 Days', value: 'Last 90 Days' }
            ]
        }
    ];

    closingTypeOptions = [
        { label: 'All Closings', value: 'All Closings' },
        { label: 'Closed Closings', value: 'Closed Closings' },
        { label: 'Open Closings', value: 'Open Closings' },
        { label: 'Rent Closings', value: 'Rent Closings' },
        { label: 'Sale Closings', value: 'Sale Closings' }
    ];

    displayTypeOptions = [
        { label: 'Datatable', value: 'Datatable' },
        { label: 'Chart', value: 'Chart' }
    ];

    get filterIconName() {
        return this.showMoreFilters ? 'utility:close' : 'utility:filter';
    }

    get isDatatable() {
        return this.displayType === 'Datatable';
    }

    get isChart() {
        return this.displayType === 'Chart';
    }

    get sortedCommissionData() {
        if (!this.filteredCommissionData.length) {
            return [];
        }
        return this.filteredCommissionData.map((item, idx) => ({
            ...item,
            index: idx + 1
        }));
    }

    get totalCommissionSum() {
        return this.getFormattedSum('totalCommission');
    }

    get finalCommissionSum() {
        return this.getFormattedSum('finalCommission');
    }

    get totalClosingSum() {
        return this.getFormattedSum('closingCount', true);
    }

    get totalRentPriceSum() {
        return this.getFormattedSum('rentPrice');
    }

    get totalRentCountSum() {
        return this.getFormattedSum('rentCount', true);
    }

    get totalSaleCountSum() {
        return this.getFormattedSum('saleCount', true);
    }

    get totalRentCommissionSum() {
        return this.getFormattedSum('rentCommission');
    }

    get totalSalePriceSum() {
        return this.getFormattedSum('salePrice');
    }

    get totalPriceSum() {
        return this.getFormattedSum('totalPrice');
    }

    get totalSaleCommissionSum() {
        return this.getFormattedSum('saleCommission');
    }

    getFormattedSum(fieldName, isInteger = false) {
        const total = this.filteredCommissionData.reduce((sum, item) => {
            let value = item[fieldName] || '0';
            if (typeof value === 'string') {
                value = value.replace(/[^0-9.-]+/g, '');
            }
            return sum + (Number(value) || 0);
        }, 0);

        return isInteger
            ? Math.round(total).toLocaleString('en')
            : total.toLocaleString('en', { style: 'currency', currency: this.currencyCode, minimumFractionDigits: 2, maximumFractionDigits: 2 });
    }

    get moreFiltersLabel() {
        return this.showMoreFilters ? 'Hide Filters' : 'More Filters';
    }

    connectedCallback() {
        try {
            Promise.all([
                loadStyle(this, MulishFontCss),
                loadScript(this, ECHARTS)
            ]);
            this.getAccessible();
        } catch (error) {
            this.showToast('Error', 'Failed to initialize component: ' + error.message, 'error');
        }
    }

    getAccessible() {
        getMetadataRecords()
            .then(data => {
                const agentsCommissionReportFeature = data.find(
                    item => item.DeveloperName === 'Agents_Commission_Report'
                );
                this.isAccessible = agentsCommissionReportFeature ? Boolean(agentsCommissionReportFeature.MVEX__isAvailable__c) : false;
                if (this.isAccessible) {
                    this.loadRoleAndUserOptions();
                    this.fetchCommissionData();
                } else {
                    this.isLoading = false;
                }
            })
            .catch(error => {
                this.showToast('Error', 'Failed to check feature accessibility: ' + error.message, 'error');
                this.isAccessible = false;
                this.isLoading = false;
            });
    }

    renderedCallback() {
        if (this.isChart && this.filteredCommissionData.length) {
            setTimeout(() => {
                this.renderChart();
            }, 0);
        }
        this.updateSortIcons();
    }

    async loadRoleAndUserOptions() {
        try {
            const result = await getRolesAndUsers();
            this.roleOptions = [{ label: 'All', value: 'All' }, ...result.roles.map(r => ({ label: r, value: r }))];
            this.usersByRoleMap = result.usersByRole;
            this.currencyCode = result.currency || 'AED';
            this.updateUserOptions();
        } catch (error) {
            this.showToast('Error', 'Failed to load roles and users', 'error');
        }
    }

    updateUserOptions() {
        const users = this.selectedRole === 'All'
            ? Object.values(this.usersByRoleMap).flat()
            : this.usersByRoleMap[this.selectedRole] || [];
        
        this.userOptions = [
            { label: 'All', value: 'All' },
            ...users.map(u => ({ label: u, value: u })).sort((a, b) => a.label.localeCompare(b.label))
        ];
    }

    toggleMoreFilters(event) {
        if (event) {
            event.stopPropagation();
        }
        this.showMoreFilters = !this.showMoreFilters;
        if (this.showMoreFilters) {
            document.addEventListener('click', this.handleOutsideClick);
        } else {
            document.removeEventListener('click', this.handleOutsideClick);
        }
    }

    handleOutsideClick(event) {
        const dropdown = this.template.querySelector('.filter-dropdown-box');
        if (dropdown && !event.composedPath().includes(dropdown)) {
            this.showMoreFilters = false;
            document.removeEventListener('click', this.handleOutsideClick);
        }
    }

    handleAgentNameSearch(event) {
        this.agentNameSearch = event.detail.value;
        this.applyAgentNameFilter();
    }

    applyAgentNameFilter() {
        if (!this.agentNameSearch) {
            this.filteredCommissionData = [...this.commissionData];
        } else {
            const searchTerm = this.agentNameSearch.toLowerCase();
            this.filteredCommissionData = this.commissionData.filter(item =>
                item.agentName.toLowerCase().includes(searchTerm)
            );
        }
        if (this.sortField) {
            this.sortData();
        }
        if (this.isChart) {
            setTimeout(() => {
                this.renderChart();
            }, 0);
        }
    }

    async handleRoleChange(event) {
        this.selectedRole = event.detail.value;
        this.selectedUser = 'All';
        this.updateUserOptions();
        await this.fetchCommissionData();
    }

    async handleUserChange(event) {
        this.selectedUser = event.detail.value;
        await this.fetchCommissionData();
    }

    async handleDateRangeChange(event) {
        this.dateRange = event.detail.value;
        this.showCustomDate = this.dateRange === 'Custom';
        await this.fetchCommissionData();
    }

    async handleClosingTypeChange(event) {
        this.closingType = event.detail.value;
        await this.fetchCommissionData();
    }

    async handleDisplayTypeChange(event) {
        this.displayType = event.detail.value;
        if (this.isChart && this.filteredCommissionData.length) {
            setTimeout(() => {
                this.renderChart();
            }, 0);
        }
    }

    async handleStartDateChange(event) {
        this.startDate = event.detail.value;
        if (this.isDateInvalid(this.startDate, this.endDate)) {
            this.commissionData = [];
            this.filteredCommissionData = [];
            return;
        }
        await this.fetchCommissionData();
    }

    async handleEndDateChange(event) {
        this.endDate = event.detail.value;
        if (this.isDateInvalid(this.startDate, this.endDate)) {
            this.commissionData = [];
            this.filteredCommissionData = [];
            return;
        }
        await this.fetchCommissionData();
    }

    sortClick(event) {
        try {
            const fieldName = event.currentTarget.dataset.id;
            if (fieldName === 'index') return; // Prevent sorting on index column
            if (this.sortField === fieldName) {
                this.sortDirection = this.sortDirection === 'asc' ? 'desc' : 'asc';
            } else {
                this.sortField = fieldName;
                this.sortDirection = 'asc';
            }
            this.sortData();
            this.updateSortIcons();
        } catch (error) {
            this.showToast('Error', 'Error in sorting: ' + error.message, 'error');
        }
    }

    naturalSort(a, b) {
        const aValue = a.toString().toLowerCase();
        const bValue = b.toString().toLowerCase();
        
        const re = /(\d+)|(\D+)/g;
        const aParts = aValue.match(re) || [];
        const bParts = bValue.match(re) || [];

        for (let i = 0; i < Math.min(aParts.length, bParts.length); i++) {
            const aPart = aParts[i];
            const bPart = bParts[i];

            if (!isNaN(aPart) && !isNaN(bPart)) {
                const aNum = parseInt(aPart, 10);
                const bNum = parseInt(bPart, 10);
                if (aNum !== bNum) {
                    return aNum - bNum;
                }
            } else {
                if (aPart !== bPart) {
                    return aPart.localeCompare(bPart);
                }
            }
        }
        return aParts.length - bParts.length;
    }

    sortData() {
        try {
            this.filteredCommissionData = [...this.filteredCommissionData].sort((a, b) => {
                let aValue = a[this.sortField] || '';
                let bValue = b[this.sortField] || '';

                if (this.sortField === 'agentName') {
                    const compare = this.naturalSort(aValue, bValue);
                    return this.sortDirection === 'asc' ? compare : -compare;
                } else if (this.sortField === 'rentCount' || this.sortField === 'saleCount' || this.sortField === 'closingCount') {
                    aValue = Number(aValue) || 0;
                    bValue = Number(bValue) || 0;
                    let compare = aValue - bValue;
                    return this.sortDirection === 'asc' ? compare : -compare;
                } else if (this.sortField.includes('Price') || this.sortField.includes('Commission')) {
                    aValue = Number(aValue.replace(/[^0-9.-]+/g, '')) || 0;
                    bValue = Number(bValue.replace(/[^0-9.-]+/g, '')) || 0;
                    let compare = aValue - bValue;
                    return this.sortDirection === 'asc' ? compare : -compare;
                }
                return 0;
            });
        } catch (error) {
            this.showToast('Error', 'Error in sortData: ' + error.message, 'error');
        }
    }

    updateSortIcons() {
        try {
            const allHeaders = this.template.querySelectorAll('.sorting_header svg');
            allHeaders.forEach(icon => {
                icon.classList.remove('rotate-asc', 'rotate-desc');
                icon.closest('.slds-icon_container').style.opacity = '0.3';
            });

            if (this.sortField) {
                const currentHeader = this.template.querySelector(`[data-index="${this.sortField}"]`);
                if (currentHeader) {
                    currentHeader.classList.add(this.sortDirection === 'asc' ? 'rotate-asc' : 'rotate-desc');
                    currentHeader.closest('.slds-icon_container').style.opacity = '1';
                }
            }
        } catch (error) {
            this.showToast('Error', 'Error in updateSortIcons: ' + error.message, 'error');
        }
    }

    async fetchCommissionData() {
        if (this.dateRange === 'Custom' && (!this.startDate || !this.endDate)) {
            this.isLoading = false;
            return;
        }

        this.isLoading = true;
        try {
            const agentData = {
                dateRange: this.dateRange,
                closingType: this.closingType,
                startDate: this.startDate,
                endDate: this.endDate,
                selectedRole: this.selectedRole,
                selectedUser: this.selectedUser
            };

            const result = await calculateAgentCommissions({ agentData });
            this.commissionData = Object.entries(result).map(([agentName, data], idx) => ({
                id: agentName + idx,
                index: idx + 1,
                agentName,
                totalCommission: this.formatCurrency(data.commission),
                finalCommission: this.formatCurrency(data.overallCommission),
                closingCount: data.count,
                rentCommission: this.formatCurrency(data.rentCommission),
                saleCommission: this.formatCurrency(data.saleCommission),
                rentPrice: this.formatCurrency(data.rentPrice),
                salePrice: this.formatCurrency(data.salePrice),
                totalPrice: this.formatCurrency(data.totalPrice),
                rentCount: data.rentCount,
                saleCount: data.saleCount
            }));

            this.applyAgentNameFilter();

            if (this.sortField) {
                this.sortData();
            }

            if (this.isChart) {
                setTimeout(() => {
                    this.renderChart();
                }, 0);
            }
        } catch (error) {
            this.showToast('Error', 'Failed to fetch commission data', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    formatCurrency(number) {
        if (number == null) return '0.00';
        return Number(number).toLocaleString('en', {
            style: 'currency',
            currency: this.currencyCode,
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
        });
    }

    isDateInvalid(start, end) {
        const today = new Date().toISOString().split('T')[0];
        
        if (start && start > today) {
            this.showToast('Warning', 'Start date cannot be in the future.', 'warning');
            return true;
        }
        if (end && end > today) {
            this.showToast('Warning', 'End date cannot be in the future.', 'warning');
            return true;
        }
        if (start && end && end < start) {
            this.showToast('Warning', 'End date cannot be earlier than start date.', 'warning');
            return true;
        }
        return false;
    }

    disconnectedCallback() {
        if (this.chartInstance) {
            this.chartInstance.dispose();
            this.chartInstance = null;
        }
        window.removeEventListener('resize', this.handleResize);
        document.removeEventListener('click', this.handleOutsideClick);
    }

    renderChart() {
        if (!this.filteredCommissionData.length) {
            // this.showToast('Warning', 'No commission data available to display in chart.', 'warning');
            return;
        }

        const chartDom = this.template.querySelector('.chart-container');
        if (!chartDom) {
            this.showToast('Error', 'Chart container not found', 'error');
            return;
        }

        if (this.chartInstance) {
            this.chartInstance.dispose();
        }
        this.chartInstance = window.echarts.init(chartDom, null, { renderer: 'svg' });

        const agentNames = this.filteredCommissionData.map(item => item.agentName);
        const saleCommissionData = this.filteredCommissionData.map(item => ({
            value: parseFloat(item.saleCommission.replace(/[^0-9.-]+/g, '')),
            name: item.agentName
        }));
        const rentCommissionData = this.filteredCommissionData.map(item => ({
            value: parseFloat(item.rentCommission.replace(/[^0-9.-]+/g, '')),
            name: item.agentName
        }));
        const totalCommissionData = this.filteredCommissionData.map(item => ({
            value: parseFloat(item.finalCommission.replace(/[^0-9.-]+/g, '')),
            name: item.agentName
        }));

        const option = {
            title: {
                text: 'Agent Commission Report',
                left: 'center',
                top: 0,
                textStyle: {
                    fontSize: 18,
                    fontWeight: '500'
                }
            },
            tooltip: {
                trigger: 'axis',
                axisPointer: { type: 'shadow' },
                formatter: params => {
                    let result = `${params[0].axisValue}<br/>`;
                    params.forEach(item => {
                        result += `${item.marker} ${item.seriesName}: ${item.value.toLocaleString('en-AE', {
                            style: 'currency',
                            currency: this.currencyCode
                        })}<br/>`;
                    });
                    return result;
                }
            },
            legend: {
                data: ['Sale Commission', 'Rent Commission', 'Total Commission'],
                top: 30,
                type: 'scroll',
                width: '80%',
                itemGap: 15
            },
            toolbox: {
                show: true,
                feature: {
                    dataView: {
                        show: true,
                        readOnly: false,
                        title: 'Data View',
                        lang: ['Data View', 'Close', 'Refresh']
                    },
                    magicType: {
                        show: true,
                        type: ['bar', 'stack', 'pie'],
                        title: {
                            bar: 'Bar Chart',
                            stack: 'Stacked Bar',
                            pie: 'Pie Chart'
                        },
                        option: {
                            pie: {
                                series: [
                                    {
                                        type: 'pie',
                                        radius: ['40%', '70%'],
                                        label: {
                                            show: true,
                                            formatter: '{b}: {c} ({d}%)'
                                        },
                                        data: totalCommissionData
                                    }
                                ]
                            }
                        }
                    },
                    restore: { show: true, title: 'Restore' },
                    saveAsImage: {
                        show: true,
                        title: 'Download Chart',
                        name: 'Agent_Commission_Report'
                    }
                },
                right: 10
            },
            grid: {
                left: '5%',
                right: '5%',
                bottom: '10%',
                top: '15%',
                containLabel: true
            },
            xAxis: {
                type: 'value',
                boundaryGap: [0, 0.01],
                axisLabel: {
                    formatter: value => {
                        return value.toLocaleString('en', {
                            style: 'currency',
                            currency: this.currencyCode,
                            minimumFractionDigits: 0
                        });
                    }
                }
            },
            yAxis: {
                type: 'category',
                data: agentNames,
                axisLabel: {
                    rotate: 45,
                    formatter: value => value.length > 15 ? value.slice(0, 15) + '...' : value
                }
            },
            series: [
                {
                    name: 'Sale Commission',
                    type: 'bar',
                    data: saleCommissionData.map(item => item.value),
                    itemStyle: { color: '#5470C6' },
                    emphasis: { focus: 'series' },
                    animationEasing: 'easeInBounce'
                },
                {
                    name: 'Rent Commission',
                    type: 'bar',
                    data: rentCommissionData.map(item => item.value),
                    itemStyle: { color: '#91CC75' },
                    emphasis: { focus: 'series' },
                    animationEasing: 'easeInBounce'
                },
                {
                    name: 'Total Commission',
                    type: 'bar',
                    data: totalCommissionData.map(item => item.value),
                    itemStyle: { color: '#EE6666' },
                    emphasis: { focus: 'series' },
                    animationEasing: 'easeInBounce'
                }
            ],
            animation: true,
            animationDuration: 1000
        };

        this.chartInstance.setOption(option);

        this.handleResize = () => {
            if (this.chartInstance) {
                this.chartInstance.resize();
            }
        };
        window.addEventListener('resize', this.handleResize);
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}