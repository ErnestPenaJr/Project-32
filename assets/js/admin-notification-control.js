/**
 * Admin Notification Control JavaScript
 * Handles system-wide notification management interface
 */

class AdminNotificationControl {
    constructor() {
        this.systemManager = null;
        this.notificationTypes = [];
        this.selectedTypes = new Set();
        this.currentUserId = this.getCurrentUserId();
        
        this.init();
    }

    async init() {
        try {
            await this.loadSystemStatus();
            await this.loadSystemSettings();
            await this.loadNotificationTypes();
            await this.loadAnalytics();
            
            this.setupEventListeners();
            this.startAutoRefresh();
            
            this.showToast('System notification control loaded successfully', 'success');
        } catch (error) {
            console.error('Failed to initialize admin notification control:', error);
            this.showToast('Failed to load notification control system', 'error');
        }
    }

    getCurrentUserId() {
        // This would typically come from session or authentication system
        // For now, return a placeholder that should be replaced with actual implementation
        return sessionStorage.getItem('userId') || '1';
    }

    async loadSystemStatus() {
        try {
            const response = await fetch('assets/cfc/SystemNotificationManager.cfc?method=getAllSystemSettings', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({})
            });

            const settings = await response.json();
            this.updateSystemStatusDisplay(settings);
        } catch (error) {
            console.error('Failed to load system status:', error);
            this.setSystemStatusError();
        }
    }

    updateSystemStatusDisplay(settings) {
        const statusElement = document.getElementById('systemStatus');
        const titleElement = document.getElementById('systemStatusTitle');
        const messageElement = document.getElementById('systemStatusMessage');

        let isGlobalEnabled = true;
        let isMaintenanceMode = false;
        let isEmergencyMode = false;

        // Parse settings array to find relevant status
        if (Array.isArray(settings)) {
            settings.forEach(setting => {
                switch (setting.SETTING_NAME) {
                    case 'NOTIFICATIONS_ENABLED':
                        isGlobalEnabled = setting.SETTING_VALUE === '1';
                        break;
                    case 'MAINTENANCE_MODE':
                        isMaintenanceMode = setting.SETTING_VALUE === '1';
                        break;
                    case 'EMERGENCY_MODE':
                        isEmergencyMode = setting.SETTING_VALUE === '1';
                        break;
                }
            });
        }

        // Update status display
        statusElement.className = 'system-status';
        
        if (isEmergencyMode) {
            statusElement.classList.add('critical');
            titleElement.textContent = '🚨 Emergency Mode Active';
            messageElement.textContent = 'All critical notifications are being sent regardless of user preferences';
        } else if (isMaintenanceMode) {
            statusElement.classList.add('maintenance');
            titleElement.textContent = '🛠️ Maintenance Mode Active';
            messageElement.textContent = 'Only critical notifications are being sent';
        } else if (!isGlobalEnabled) {
            statusElement.classList.add('disabled');
            titleElement.textContent = '🔴 Notifications Disabled';
            messageElement.textContent = 'All notifications are currently disabled system-wide';
        } else {
            statusElement.classList.add('enabled');
            titleElement.textContent = '🟢 System Operational';
            messageElement.textContent = 'All notification systems are functioning normally';
        }
    }

    setSystemStatusError() {
        const statusElement = document.getElementById('systemStatus');
        const titleElement = document.getElementById('systemStatusTitle');
        const messageElement = document.getElementById('systemStatusMessage');

        statusElement.className = 'system-status disabled';
        titleElement.textContent = '⚠️ Status Unknown';
        messageElement.textContent = 'Unable to retrieve system status';
    }

    async loadSystemSettings() {
        try {
            const response = await fetch('assets/cfc/SystemNotificationManager.cfc?method=getAllSystemSettings', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                }
            });

            const settings = await response.json();
            this.populateSystemSettings(settings);
        } catch (error) {
            console.error('Failed to load system settings:', error);
        }
    }

    populateSystemSettings(settings) {
        if (!Array.isArray(settings)) return;

        settings.forEach(setting => {
            switch (setting.SETTING_NAME) {
                case 'NOTIFICATIONS_ENABLED':
                    document.getElementById('globalNotifications').checked = setting.SETTING_VALUE === '1';
                    break;
                case 'EMAIL_NOTIFICATIONS_ENABLED':
                    document.getElementById('emailNotifications').checked = setting.SETTING_VALUE === '1';
                    break;
                case 'IN_APP_NOTIFICATIONS_ENABLED':
                    document.getElementById('inAppNotifications').checked = setting.SETTING_VALUE === '1';
                    break;
                case 'MAX_DAILY_NOTIFICATIONS_PER_USER':
                    document.getElementById('maxDailyNotifications').value = setting.SETTING_VALUE;
                    break;
                case 'QUIET_HOURS_START':
                    document.getElementById('quietHoursStart').value = setting.SETTING_VALUE;
                    break;
                case 'QUIET_HOURS_END':
                    document.getElementById('quietHoursEnd').value = setting.SETTING_VALUE;
                    break;
            }
        });
    }

    async loadNotificationTypes() {
        try {
            const response = await fetch('assets/cfc/SystemNotificationManager.cfc?method=getAllNotificationTypesWithStatus', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                }
            });

            const types = await response.json();
            this.notificationTypes = Array.isArray(types) ? types : [];
            this.displayNotificationTypes();
            this.populateScheduledTypeDropdown();
        } catch (error) {
            console.error('Failed to load notification types:', error);
            this.displayNotificationTypesError();
        }
    }

    displayNotificationTypes() {
        const container = document.getElementById('notificationTypes');
        const categoryFilter = document.getElementById('categoryFilter').value;

        if (this.notificationTypes.length === 0) {
            container.innerHTML = `
                <div class="text-center text-muted">
                    <i class="bi bi-inbox"></i>
                    <p>No notification types found</p>
                </div>
            `;
            return;
        }

        const filteredTypes = categoryFilter 
            ? this.notificationTypes.filter(type => type.CATEGORY === categoryFilter)
            : this.notificationTypes;

        const groupedTypes = this.groupByCategory(filteredTypes);
        
        let html = '';
        Object.entries(groupedTypes).forEach(([category, types]) => {
            html += `
                <div class="mb-4">
                    <h6 class="text-muted mb-3">
                        <i class="bi bi-folder"></i> ${category}
                        <span class="badge bg-secondary ms-2">${types.length}</span>
                    </h6>
                    <div class="row">
            `;

            types.forEach(type => {
                const isEnabled = type.ENABLED === 1;
                const isCritical = type.CRITICAL_NOTIFICATION === 1;
                const hasOverride = type.OVERRIDE_USER_PREFERENCES === 1;

                html += `
                    <div class="col-md-6 col-lg-4 mb-3">
                        <div class="notification-card card ${isCritical ? 'critical' : ''}">
                            <div class="card-body">
                                <div class="d-flex justify-content-between align-items-start mb-2">
                                    <div class="form-check">
                                        <input class="form-check-input" type="checkbox" 
                                               id="type_${type.TYPE_CODE}" 
                                               data-type="${type.TYPE_CODE}"
                                               onchange="adminControl.handleTypeSelection(this)">
                                        <label class="form-check-label fw-bold" for="type_${type.TYPE_CODE}">
                                            ${type.DISPLAY_NAME}
                                        </label>
                                    </div>
                                    <div class="text-end">
                                        ${isCritical ? '<span class="badge bg-danger status-badge">Critical</span>' : ''}
                                        ${hasOverride ? '<span class="badge bg-warning status-badge">Override</span>' : ''}
                                    </div>
                                </div>
                                <p class="card-text small text-muted mb-3">${type.DESCRIPTION || 'No description available'}</p>
                                <div class="d-flex justify-content-between align-items-center">
                                    <div class="small">
                                        <i class="bi bi-envelope${type.DEFAULT_EMAIL_ENABLED ? '-fill' : ''} me-1" 
                                           title="Email ${type.DEFAULT_EMAIL_ENABLED ? 'enabled' : 'disabled'} by default"></i>
                                        <i class="bi bi-app${type.DEFAULT_IN_APP_ENABLED ? '-indicator' : ''} me-1" 
                                           title="In-app ${type.DEFAULT_IN_APP_ENABLED ? 'enabled' : 'disabled'} by default"></i>
                                        ${type.ADMIN_ONLY ? '<i class="bi bi-shield-fill text-warning" title="Admin only"></i>' : ''}
                                    </div>
                                    <label class="toggle-switch">
                                        <input type="checkbox" ${isEnabled ? 'checked' : ''} 
                                               onchange="adminControl.toggleNotificationType('${type.TYPE_CODE}', this.checked)">
                                        <span class="slider"></span>
                                    </label>
                                </div>
                            </div>
                        </div>
                    </div>
                `;
            });

            html += `
                    </div>
                </div>
            `;
        });

        container.innerHTML = html;
    }

    displayNotificationTypesError() {
        const container = document.getElementById('notificationTypes');
        container.innerHTML = `
            <div class="text-center text-danger">
                <i class="bi bi-exclamation-triangle"></i>
                <p>Failed to load notification types</p>
                <button class="btn btn-outline-primary btn-sm" onclick="adminControl.loadNotificationTypes()">
                    <i class="bi bi-arrow-clockwise"></i> Retry
                </button>
            </div>
        `;
    }

    groupByCategory(types) {
        return types.reduce((groups, type) => {
            const category = type.CATEGORY || 'Other';
            if (!groups[category]) {
                groups[category] = [];
            }
            groups[category].push(type);
            return groups;
        }, {});
    }

    populateScheduledTypeDropdown() {
        const dropdown = document.getElementById('scheduledNotificationType');
        dropdown.innerHTML = '<option value="">Select Type...</option>';
        
        this.notificationTypes.forEach(type => {
            dropdown.innerHTML += `<option value="${type.TYPE_CODE}">${type.DISPLAY_NAME}</option>`;
        });
    }

    async loadAnalytics() {
        try {
            const endDate = new Date().toISOString().split('T')[0];
            const startDate = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0];

            const response = await fetch(`assets/cfc/SystemNotificationManager.cfc?method=getNotificationAnalytics&start_date=${startDate}&end_date=${endDate}`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                }
            });

            const analytics = await response.json();
            this.displayAnalytics(analytics);
        } catch (error) {
            console.error('Failed to load analytics:', error);
            this.displayAnalyticsError();
        }
    }

    displayAnalytics(analytics) {
        const container = document.getElementById('analyticsSummary');
        
        if (!Array.isArray(analytics) || analytics.length === 0) {
            container.innerHTML = `
                <div class="metric-card">
                    <div class="metric-value text-muted">-</div>
                    <div class="metric-label">No analytics data available</div>
                </div>
            `;
            return;
        }

        // Calculate summary metrics
        const totalSent = analytics.reduce((sum, item) => sum + (item.TOTAL_SENT || 0), 0);
        const totalDelivered = analytics.reduce((sum, item) => sum + (item.TOTAL_DELIVERED || 0), 0);
        const totalFailed = analytics.reduce((sum, item) => sum + (item.TOTAL_FAILED || 0), 0);
        const totalOpened = analytics.reduce((sum, item) => sum + (item.TOTAL_OPENED || 0), 0);
        
        const deliveryRate = totalSent > 0 ? ((totalDelivered / totalSent) * 100).toFixed(1) : 0;
        const openRate = totalDelivered > 0 ? ((totalOpened / totalDelivered) * 100).toFixed(1) : 0;

        container.innerHTML = `
            <div class="metric-card">
                <div class="metric-value text-primary">${totalSent.toLocaleString()}</div>
                <div class="metric-label">Total Sent (30 days)</div>
            </div>
            <div class="metric-card">
                <div class="metric-value text-success">${totalDelivered.toLocaleString()}</div>
                <div class="metric-label">Successfully Delivered</div>
            </div>
            <div class="metric-card">
                <div class="metric-value text-danger">${totalFailed.toLocaleString()}</div>
                <div class="metric-label">Failed Deliveries</div>
            </div>
            <div class="metric-card">
                <div class="metric-value text-info">${deliveryRate}%</div>
                <div class="metric-label">Delivery Rate</div>
            </div>
            <div class="metric-card">
                <div class="metric-value text-warning">${openRate}%</div>
                <div class="metric-label">Open Rate</div>
            </div>
        `;
    }

    displayAnalyticsError() {
        const container = document.getElementById('analyticsSummary');
        container.innerHTML = `
            <div class="metric-card">
                <div class="metric-value text-danger">
                    <i class="bi bi-exclamation-triangle"></i>
                </div>
                <div class="metric-label">Failed to load analytics</div>
            </div>
        `;
    }

    setupEventListeners() {
        // Global toggle listeners
        document.getElementById('globalNotifications').addEventListener('change', (e) => {
            this.updateSystemSetting('NOTIFICATIONS_ENABLED', e.target.checked ? '1' : '0');
        });

        document.getElementById('emailNotifications').addEventListener('change', (e) => {
            this.updateSystemSetting('EMAIL_NOTIFICATIONS_ENABLED', e.target.checked ? '1' : '0');
        });

        document.getElementById('inAppNotifications').addEventListener('change', (e) => {
            this.updateSystemSetting('IN_APP_NOTIFICATIONS_ENABLED', e.target.checked ? '1' : '0');
        });

        // Category filter
        document.getElementById('categoryFilter').addEventListener('change', () => {
            this.displayNotificationTypes();
        });

        // Bulk action selector
        document.getElementById('bulkAction').addEventListener('change', (e) => {
            document.getElementById('executeBulkBtn').disabled = !e.target.value;
        });

        // Modal confirmation checkbox
        document.getElementById('confirmEmergency').addEventListener('change', (e) => {
            document.getElementById('activateEmergencyBtn').disabled = !e.target.checked;
        });

        // Mode buttons
        document.getElementById('maintenanceModeBtn').addEventListener('click', () => {
            this.toggleMaintenanceMode();
        });

        document.getElementById('emergencyModeBtn').addEventListener('click', () => {
            const modal = new bootstrap.Modal(document.getElementById('emergencyModeModal'));
            modal.show();
        });
    }

    handleTypeSelection(checkbox) {
        const typeCode = checkbox.dataset.type;
        
        if (checkbox.checked) {
            this.selectedTypes.add(typeCode);
        } else {
            this.selectedTypes.delete(typeCode);
        }

        // Update bulk action button state
        const bulkBtn = document.getElementById('executeBulkBtn');
        const bulkAction = document.getElementById('bulkAction').value;
        
        if (bulkAction && (this.selectedTypes.size > 0 || bulkAction.includes('all'))) {
            bulkBtn.disabled = false;
        } else {
            bulkBtn.disabled = !bulkAction;
        }
    }

    async toggleNotificationType(typeCode, enabled) {
        try {
            const response = await fetch('assets/cfc/SystemNotificationManager.cfc?method=toggleNotificationType', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    notification_type: typeCode,
                    enabled: enabled,
                    updated_by: this.currentUserId
                })
            });

            const result = await response.json();
            
            if (result.success) {
                this.showToast(`${typeCode} ${enabled ? 'enabled' : 'disabled'} successfully`, 'success');
                await this.loadSystemStatus(); // Refresh status
            } else {
                this.showToast(result.message || 'Failed to update notification type', 'error');
                // Revert the toggle
                this.loadNotificationTypes();
            }
        } catch (error) {
            console.error('Failed to toggle notification type:', error);
            this.showToast('Failed to update notification type', 'error');
            this.loadNotificationTypes();
        }
    }

    async updateSystemSetting(settingName, settingValue) {
        try {
            const response = await fetch('assets/cfc/SystemNotificationManager.cfc?method=updateSystemSetting', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    setting_name: settingName,
                    setting_value: settingValue,
                    updated_by: this.currentUserId
                })
            });

            const result = await response.json();
            
            if (result.success) {
                this.showToast('System setting updated successfully', 'success');
                await this.loadSystemStatus(); // Refresh status display
            } else {
                this.showToast(result.message || 'Failed to update system setting', 'error');
            }
        } catch (error) {
            console.error('Failed to update system setting:', error);
            this.showToast('Failed to update system setting', 'error');
        }
    }

    async toggleMaintenanceMode() {
        const currentStatus = await this.getSystemSetting('MAINTENANCE_MODE');
        const newStatus = currentStatus === '1' ? '0' : '1';
        
        if (newStatus === '1') {
            const confirmed = confirm('Are you sure you want to activate maintenance mode? This will disable all non-critical notifications.');
            if (!confirmed) return;
        }

        await this.updateSystemSetting('MAINTENANCE_MODE', newStatus);
    }

    async getSystemSetting(settingName) {
        try {
            const response = await fetch('assets/cfc/SystemNotificationManager.cfc?method=getAllSystemSettings', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                }
            });

            const settings = await response.json();
            if (Array.isArray(settings)) {
                const setting = settings.find(s => s.SETTING_NAME === settingName);
                return setting ? setting.SETTING_VALUE : '0';
            }
            return '0';
        } catch (error) {
            console.error('Failed to get system setting:', error);
            return '0';
        }
    }

    startAutoRefresh() {
        // Refresh system status every 30 seconds
        setInterval(() => {
            this.loadSystemStatus();
        }, 30000);

        // Refresh analytics every 5 minutes
        setInterval(() => {
            this.loadAnalytics();
        }, 300000);
    }

    refreshNotificationTypes() {
        this.loadNotificationTypes();
    }

    async saveSystemSettings() {
        const settings = [
            {
                name: 'MAX_DAILY_NOTIFICATIONS_PER_USER',
                value: document.getElementById('maxDailyNotifications').value
            },
            {
                name: 'QUIET_HOURS_START',
                value: document.getElementById('quietHoursStart').value
            },
            {
                name: 'QUIET_HOURS_END',
                value: document.getElementById('quietHoursEnd').value
            }
        ];

        let allSuccessful = true;
        
        for (const setting of settings) {
            try {
                await this.updateSystemSetting(setting.name, setting.value);
            } catch (error) {
                allSuccessful = false;
                console.error(`Failed to update ${setting.name}:`, error);
            }
        }

        if (allSuccessful) {
            this.showToast('All system settings saved successfully', 'success');
        } else {
            this.showToast('Some settings failed to save', 'error');
        }
    }

    async executeBulkAction() {
        const action = document.getElementById('bulkAction').value;
        if (!action) return;

        let confirmed = true;
        let message = '';

        switch (action) {
            case 'enable':
                message = `Enable ${this.selectedTypes.size} selected notification types?`;
                break;
            case 'disable':
                message = `Disable ${this.selectedTypes.size} selected notification types?`;
                break;
            case 'enable_all':
                message = 'Enable all notification types?';
                break;
            case 'disable_all_non_critical':
                message = 'Disable all non-critical notification types?';
                break;
        }

        if (message) {
            confirmed = confirm(message);
        }

        if (!confirmed) return;

        // Implementation would depend on having a bulk action method in the CFC
        this.showToast('Bulk action functionality not yet implemented', 'info');
    }

    async scheduleAction() {
        const notificationType = document.getElementById('scheduledNotificationType').value;
        const action = document.getElementById('scheduledAction').value;
        const dateTime = document.getElementById('scheduledDateTime').value;

        if (!notificationType || !dateTime) {
            this.showToast('Please select notification type and date/time', 'error');
            return;
        }

        try {
            const response = await fetch('assets/cfc/SystemNotificationManager.cfc?method=createNotificationSchedule', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    notification_type: notificationType,
                    action: action,
                    start_time: dateTime.replace('T', ' ') + ':00',
                    created_by: this.currentUserId
                })
            });

            const result = await response.json();
            
            if (result.success) {
                this.showToast('Scheduled action created successfully', 'success');
                // Clear the form
                document.getElementById('scheduledNotificationType').value = '';
                document.getElementById('scheduledDateTime').value = '';
            } else {
                this.showToast(result.message || 'Failed to create scheduled action', 'error');
            }
        } catch (error) {
            console.error('Failed to schedule action:', error);
            this.showToast('Failed to create scheduled action', 'error');
        }
    }

    async activateEmergencyMode() {
        const modal = bootstrap.Modal.getInstance(document.getElementById('emergencyModeModal'));
        modal.hide();

        await this.updateSystemSetting('EMERGENCY_MODE', '1');
        
        // Reset the confirmation checkbox
        document.getElementById('confirmEmergency').checked = false;
        document.getElementById('activateEmergencyBtn').disabled = true;
    }

    showToast(message, type = 'info') {
        const toast = document.getElementById('notificationToast');
        const toastMessage = document.getElementById('toastMessage');
        const toastHeader = toast.querySelector('.toast-header');
        
        toastMessage.textContent = message;
        
        // Update toast styling based on type
        toastHeader.className = 'toast-header';
        const icon = toastHeader.querySelector('i');
        
        switch (type) {
            case 'success':
                toastHeader.classList.add('bg-success', 'text-white');
                icon.className = 'bi bi-check-circle-fill text-white me-2';
                break;
            case 'error':
                toastHeader.classList.add('bg-danger', 'text-white');
                icon.className = 'bi bi-exclamation-triangle-fill text-white me-2';
                break;
            case 'warning':
                toastHeader.classList.add('bg-warning', 'text-dark');
                icon.className = 'bi bi-exclamation-triangle-fill text-dark me-2';
                break;
            default:
                toastHeader.classList.add('bg-info', 'text-white');
                icon.className = 'bi bi-info-circle-fill text-white me-2';
        }
        
        const bsToast = new bootstrap.Toast(toast);
        bsToast.show();
    }
}

// Initialize the admin control when DOM is loaded
let adminControl;
document.addEventListener('DOMContentLoaded', () => {
    adminControl = new AdminNotificationControl();
});

// Global functions for HTML onclick handlers
window.adminControl = {
    handleTypeSelection: (checkbox) => adminControl.handleTypeSelection(checkbox),
    toggleNotificationType: (typeCode, enabled) => adminControl.toggleNotificationType(typeCode, enabled),
    refreshNotificationTypes: () => adminControl.refreshNotificationTypes(),
    saveSystemSettings: () => adminControl.saveSystemSettings(),
    executeBulkAction: () => adminControl.executeBulkAction(),
    scheduleAction: () => adminControl.scheduleAction(),
    activateEmergencyMode: () => adminControl.activateEmergencyMode()
};