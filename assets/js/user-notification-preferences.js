/**
 * User Notification Preferences JavaScript
 * Provides enhanced user interface for managing personal notification preferences
 * with real-time system status awareness
 */

class UserNotificationPreferences {
    constructor() {
        this.currentUserId = this.getCurrentUserId();
        this.notificationTypes = [];
        this.userPreferences = {};
        this.systemStatus = {};
        this.autoSaveEnabled = true;
        this.autoSaveTimeout = null;
        this.unsavedChanges = false;

        this.init();
    }

    async init() {
        try {
            await this.loadSystemStatus();
            await this.loadNotificationTypes();
            await this.loadUserPreferences();
            await this.loadUserSettings();
            
            this.setupEventListeners();
            this.startAutoRefresh();
            this.updateNotificationSummary();
            
            this.showToast('Notification preferences loaded successfully', 'success');
        } catch (error) {
            console.error('Failed to initialize user notification preferences:', error);
            this.showToast('Failed to load notification preferences', 'error');
        }
    }

    getCurrentUserId() {
        // Get user ID from session storage (matches the pattern used in topNav.js)
        return sessionStorage.getItem('USER_ID') || sessionStorage.getItem('userId') || localStorage.getItem('userId') || '1';
    }

    async loadSystemStatus() {
        try {
            const response = await fetch('assets/cfc/SystemNotificationManager.cfc?method=getAllSystemSettings', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                }
            });

            const result = await response.json();
            if (result.success) {
                this.processSystemStatus(result.data);
                this.updateSystemStatusBanner();
            } else {
                console.error('Failed to load system status:', result.message);
                this.showSystemStatusError();
            }
        } catch (error) {
            console.error('Failed to load system status:', error);
            this.showSystemStatusError();
        }
    }

    processSystemStatus(settings) {
        this.systemStatus = {
            notificationsEnabled: true,
            emailEnabled: true,
            inAppEnabled: true,
            maintenanceMode: false,
            emergencyMode: false
        };

        // Process the settings array
        if (Array.isArray(settings)) {
            settings.forEach(setting => {
                switch(setting.setting_name) {
                    case 'NOTIFICATIONS_ENABLED':
                        this.systemStatus.notificationsEnabled = setting.setting_value === '1';
                        break;
                    case 'EMAIL_NOTIFICATIONS_ENABLED':
                        this.systemStatus.emailEnabled = setting.setting_value === '1';
                        break;
                    case 'IN_APP_NOTIFICATIONS_ENABLED':
                        this.systemStatus.inAppEnabled = setting.setting_value === '1';
                        break;
                    case 'MAINTENANCE_MODE':
                        this.systemStatus.maintenanceMode = setting.setting_value === '1';
                        break;
                    case 'EMERGENCY_MODE':
                        this.systemStatus.emergencyMode = setting.setting_value === '1';
                        break;
                }
            });
        }
    }

    updateSystemStatusBanner() {
        const banner = document.getElementById('systemStatusBanner');
        const title = document.getElementById('bannerTitle');
        const message = document.getElementById('bannerMessage');

        banner.style.display = 'block';
        banner.className = 'system-status-banner';

        if (this.systemStatus.emergencyMode) {
            banner.classList.add('disabled');
            title.textContent = '🚨 Emergency Mode Active';
            message.textContent = 'System administrators may override your notification preferences for critical notifications.';
        } else if (this.systemStatus.maintenanceMode) {
            banner.classList.add('maintenance');
            title.textContent = '🛠️ Maintenance Mode';
            message.textContent = 'Only critical notifications are currently being sent. Non-critical notifications are paused.';
        } else if (!this.systemStatus.notificationsEnabled) {
            banner.classList.add('disabled');
            title.textContent = '🔴 Notifications Disabled';
            message.textContent = 'Notifications are currently disabled system-wide by administrators.';
        } else {
            banner.classList.add('normal');
            title.textContent = '🟢 System Operational';
            message.textContent = 'All notification systems are functioning normally.';
        }
    }

    showSystemStatusError() {
        const banner = document.getElementById('systemStatusBanner');
        const title = document.getElementById('bannerTitle');
        const message = document.getElementById('bannerMessage');

        banner.style.display = 'block';
        banner.className = 'system-status-banner disabled';
        title.textContent = '⚠️ Status Unknown';
        message.textContent = 'Unable to retrieve system status. Some features may not work correctly.';
    }

    async loadNotificationTypes() {
        try {
            const response = await fetch('assets/cfc/SystemNotificationManager.cfc?method=getAllNotificationTypesWithStatus', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                }
            });

            const result = await response.json();
            if (result.success) {
                this.notificationTypes = Array.isArray(result.data) ? result.data : [];
            } else {
                console.error('Failed to load notification types:', result.message);
                this.notificationTypes = [];
            }
        } catch (error) {
            console.error('Failed to load notification types:', error);
            throw error;
        }
    }

    async loadUserPreferences() {
        try {
            const response = await fetch(`assets/cfc/notifications.cfc?method=getUserNotificationPreferences&user_id=${this.currentUserId}`, {
                method: 'GET',
                headers: {
                    'Content-Type': 'application/json',
                }
            });

            const preferences = await response.json();
            this.processUserPreferences(preferences);
            this.displayNotificationPreferences();
        } catch (error) {
            console.error('Failed to load user preferences:', error);
            throw error;
        }
    }

    processUserPreferences(preferences) {
        this.userPreferences = {};
        
        if (Array.isArray(preferences)) {
            preferences.forEach(pref => {
                this.userPreferences[pref.NOTIFICATION_TYPE] = {
                    emailEnabled: pref.EMAIL_ENABLED === 1 || pref.EMAIL_ENABLED === true,
                    inAppEnabled: pref.IN_APP_ENABLED === 1 || pref.IN_APP_ENABLED === true
                };
            });
        }
    }

    async loadUserSettings() {
        try {
            const response = await fetch(`assets/cfc/SystemNotificationManager.cfc?method=getUserNotificationSettings&user_id=${this.currentUserId}`, {
                method: 'GET',
                headers: {
                    'Content-Type': 'application/json',
                }
            });

            const settings = await response.json();
            this.applyUserSettings(settings);
        } catch (error) {
            console.error('Failed to load user settings:', error);
            // Use defaults if settings can't be loaded
            this.applyDefaultSettings();
        }
    }

    applyUserSettings(settings) {
        if (Array.isArray(settings)) {
            settings.forEach(setting => {
                switch (setting.SETTING_NAME) {
                    case 'QUIET_HOURS_START':
                        document.getElementById('quietHoursStart').value = setting.SETTING_VALUE;
                        break;
                    case 'QUIET_HOURS_END':
                        document.getElementById('quietHoursEnd').value = setting.SETTING_VALUE;
                        break;
                    case 'QUIET_HOURS_ENABLED':
                        document.getElementById('enableQuietHours').checked = setting.SETTING_VALUE === '1';
                        break;
                    case 'MAX_DAILY_NOTIFICATIONS':
                        document.getElementById('maxDailyNotifications').value = setting.SETTING_VALUE;
                        document.getElementById('maxDailyValue').textContent = setting.SETTING_VALUE;
                        break;
                    case 'DIGEST_MODE':
                        document.getElementById('digestMode').checked = setting.SETTING_VALUE === '1';
                        break;
                }
            });
        }
    }

    applyDefaultSettings() {
        document.getElementById('quietHoursStart').value = '22:00';
        document.getElementById('quietHoursEnd').value = '08:00';
        document.getElementById('enableQuietHours').checked = true;
        document.getElementById('maxDailyNotifications').value = '50';
        document.getElementById('maxDailyValue').textContent = '50';
        document.getElementById('digestMode').checked = false;
    }

    displayNotificationPreferences() {
        const container = document.getElementById('notificationCategories');
        
        if (this.notificationTypes.length === 0) {
            container.innerHTML = `
                <div class="text-center py-5">
                    <i class="bi bi-inbox text-muted" style="font-size: 3rem;"></i>
                    <p class="text-muted mt-3">No notification types available</p>
                </div>
            `;
            return;
        }

        const categorized = this.groupNotificationsByCategory();
        let html = '';

        Object.entries(categorized).forEach(([category, types]) => {
            html += this.createCategorySection(category, types);
        });

        container.innerHTML = html;
        this.updateNotificationSummary();
    }

    groupNotificationsByCategory() {
        const categories = {};
        
        this.notificationTypes.forEach(type => {
            // Skip admin-only notifications for regular users
            if (type.ADMIN_ONLY === 1 && !this.isCurrentUserAdmin()) {
                return;
            }

            const category = type.CATEGORY || 'Other';
            if (!categories[category]) {
                categories[category] = [];
            }
            categories[category].push(type);
        });

        return categories;
    }

    createCategorySection(category, types) {
        const categoryIcons = {
            'Booking Lifecycle': 'bi-calendar-check',
            'Approval Workflow': 'bi-check-circle',
            'User Management': 'bi-people',
            'System': 'bi-gear',
            'Administrative': 'bi-shield-check'
        };

        const icon = categoryIcons[category] || 'bi-bell';

        let html = `
            <div class="mb-4">
                <div class="category-header">
                    <h4><i class="bi ${icon}"></i> ${category}</h4>
                    <p class="text-muted mb-0">${types.length} notification type${types.length !== 1 ? 's' : ''}</p>
                </div>
                <div class="row">
        `;

        types.forEach(type => {
            html += this.createNotificationTypeCard(type);
        });

        html += `
                </div>
            </div>
        `;

        return html;
    }

    createNotificationTypeCard(type) {
        const userPref = this.userPreferences[type.TYPE_CODE] || {};
        const emailEnabled = userPref.emailEnabled !== undefined ? userPref.emailEnabled : (type.DEFAULT_EMAIL_ENABLED === 1);
        const inAppEnabled = userPref.inAppEnabled !== undefined ? userPref.inAppEnabled : (type.DEFAULT_IN_APP_ENABLED === 1);
        
        const isSystemDisabled = type.ENABLED === 0;
        const hasSystemOverride = type.OVERRIDE_USER_PREFERENCES === 1;
        const isCritical = type.CRITICAL_NOTIFICATION === 1;
        
        let cardClass = 'preference-card';
        let statusInfo = '';
        
        if (isSystemDisabled) {
            cardClass += ' system-disabled';
            statusInfo = '<div class="alert alert-danger alert-sm mb-2"><i class="bi bi-x-circle"></i> Disabled by system administrator</div>';
        } else if (hasSystemOverride) {
            cardClass += ' system-override';
            statusInfo = '<div class="alert alert-warning alert-sm mb-2"><i class="bi bi-exclamation-triangle"></i> System may override your preferences</div>';
        }

        const emailDisabled = !this.systemStatus.emailEnabled || isSystemDisabled;
        const inAppDisabled = !this.systemStatus.inAppEnabled || isSystemDisabled;

        return `
            <div class="col-md-6 col-lg-4 mb-3">
                <div class="card ${cardClass}">
                    <div class="card-body">
                        <div class="d-flex justify-content-between align-items-start mb-2">
                            <h6 class="card-title mb-0">${type.DISPLAY_NAME}</h6>
                            <div class="text-end">
                                ${isCritical ? '<span class="badge bg-danger">Critical</span>' : ''}
                                ${hasSystemOverride ? '<span class="badge bg-warning">Override</span>' : ''}
                            </div>
                        </div>
                        
                        ${statusInfo}
                        
                        <p class="card-text small text-muted">${type.DESCRIPTION || 'No description available'}</p>
                        
                        <div class="row">
                            <div class="col-6">
                                <div class="text-center">
                                    <label class="form-label small">
                                        <i class="bi bi-envelope"></i> Email
                                    </label>
                                    <div>
                                        <label class="toggle-switch">
                                            <input type="checkbox" 
                                                   ${emailEnabled ? 'checked' : ''} 
                                                   ${emailDisabled ? 'disabled' : ''}
                                                   data-type="${type.TYPE_CODE}" 
                                                   data-method="email"
                                                   onchange="userPrefs.handlePreferenceChange(this)">
                                            <span class="slider"></span>
                                        </label>
                                    </div>
                                </div>
                            </div>
                            <div class="col-6">
                                <div class="text-center">
                                    <label class="form-label small">
                                        <i class="bi bi-app-indicator"></i> In-App
                                    </label>
                                    <div>
                                        <label class="toggle-switch">
                                            <input type="checkbox" 
                                                   ${inAppEnabled ? 'checked' : ''} 
                                                   ${inAppDisabled ? 'disabled' : ''}
                                                   data-type="${type.TYPE_CODE}" 
                                                   data-method="in_app"
                                                   onchange="userPrefs.handlePreferenceChange(this)">
                                            <span class="slider"></span>
                                        </label>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        `;
    }

    setupEventListeners() {
        // Max daily notifications range input
        document.getElementById('maxDailyNotifications').addEventListener('input', (e) => {
            document.getElementById('maxDailyValue').textContent = e.target.value;
            this.scheduleAutoSave();
        });

        // Personal settings change listeners
        ['quietHoursStart', 'quietHoursEnd', 'enableQuietHours', 'digestMode'].forEach(id => {
            document.getElementById(id).addEventListener('change', () => {
                this.scheduleAutoSave();
            });
        });

        // Warn about unsaved changes when leaving page
        window.addEventListener('beforeunload', (e) => {
            if (this.unsavedChanges) {
                e.preventDefault();
                e.returnValue = '';
            }
        });
    }

    handlePreferenceChange(checkbox) {
        const typeCode = checkbox.dataset.type;
        const method = checkbox.dataset.method;
        const enabled = checkbox.checked;

        // Update local preferences
        if (!this.userPreferences[typeCode]) {
            this.userPreferences[typeCode] = {};
        }
        
        if (method === 'email') {
            this.userPreferences[typeCode].emailEnabled = enabled;
        } else if (method === 'in_app') {
            this.userPreferences[typeCode].inAppEnabled = enabled;
        }

        this.updateNotificationSummary();
        this.scheduleAutoSave();
    }

    scheduleAutoSave() {
        this.unsavedChanges = true;
        
        if (!this.autoSaveEnabled) return;

        // Clear existing timeout
        if (this.autoSaveTimeout) {
            clearTimeout(this.autoSaveTimeout);
        }

        // Schedule save in 2 seconds
        this.autoSaveTimeout = setTimeout(() => {
            this.saveAllPreferences(true); // true = auto save
        }, 2000);
    }

    async saveAllPreferences(isAutoSave = false) {
        try {
            const promises = [];

            // Save notification preferences
            Object.entries(this.userPreferences).forEach(([typeCode, prefs]) => {
                promises.push(this.saveNotificationPreference(typeCode, prefs.emailEnabled, prefs.inAppEnabled));
            });

            // Save personal settings
            promises.push(this.saveUserSetting('QUIET_HOURS_START', document.getElementById('quietHoursStart').value));
            promises.push(this.saveUserSetting('QUIET_HOURS_END', document.getElementById('quietHoursEnd').value));
            promises.push(this.saveUserSetting('QUIET_HOURS_ENABLED', document.getElementById('enableQuietHours').checked ? '1' : '0'));
            promises.push(this.saveUserSetting('MAX_DAILY_NOTIFICATIONS', document.getElementById('maxDailyNotifications').value));
            promises.push(this.saveUserSetting('DIGEST_MODE', document.getElementById('digestMode').checked ? '1' : '0'));

            await Promise.all(promises);

            this.unsavedChanges = false;
            
            if (isAutoSave) {
                this.showSaveIndicator();
            } else {
                this.showToast('All preferences saved successfully', 'success');
            }

        } catch (error) {
            console.error('Failed to save preferences:', error);
            this.showToast('Failed to save some preferences', 'error');
        }
    }

    async saveNotificationPreference(typeCode, emailEnabled, inAppEnabled) {
        const formData = new FormData();
        formData.append('user_id', this.currentUserId);
        formData.append('notification_type', typeCode);
        formData.append('email_enabled', emailEnabled ? '1' : '0');
        formData.append('in_app_enabled', inAppEnabled ? '1' : '0');

        const response = await fetch('assets/cfc/notifications.cfc?method=updateNotificationPreference', {
            method: 'POST',
            body: formData
        });

        if (!response.ok) {
            throw new Error(`Failed to save preference for ${typeCode}`);
        }

        return response.json();
    }

    async saveUserSetting(settingName, settingValue) {
        console.log('Saving user setting:', settingName, 'Value:', settingValue, 'User ID:', this.currentUserId);
        
        const formData = new FormData();
        formData.append('user_id', this.currentUserId);
        formData.append('setting_name', settingName);
        formData.append('setting_value', settingValue);

        const response = await fetch('assets/cfc/SystemNotificationManager.cfc?method=updateUserNotificationSetting', {
            method: 'POST',
            body: formData
        });

        if (!response.ok) {
            const errorText = await response.text();
            console.error('Save user setting error:', errorText);
            throw new Error(`Failed to save user setting ${settingName}`);
        }

        return response.json();
    }

    updateNotificationSummary() {
        let emailCount = 0;
        let inAppCount = 0;
        let overrideCount = 0;

        this.notificationTypes.forEach(type => {
            if (type.ADMIN_ONLY === 1 && !this.isCurrentUserAdmin()) {
                return;
            }

            const userPref = this.userPreferences[type.TYPE_CODE] || {};
            const emailEnabled = userPref.emailEnabled !== undefined ? userPref.emailEnabled : (type.DEFAULT_EMAIL_ENABLED === 1);
            const inAppEnabled = userPref.inAppEnabled !== undefined ? userPref.inAppEnabled : (type.DEFAULT_IN_APP_ENABLED === 1);

            if (emailEnabled && type.ENABLED === 1) emailCount++;
            if (inAppEnabled && type.ENABLED === 1) inAppCount++;
            if (type.OVERRIDE_USER_PREFERENCES === 1) overrideCount++;
        });

        document.getElementById('emailCount').textContent = emailCount;
        document.getElementById('inAppCount').textContent = inAppCount;
        document.getElementById('overrideCount').textContent = overrideCount;
    }

    async resetToDefaults() {
        const confirmed = confirm('Are you sure you want to reset all notification preferences to their default values? This cannot be undone.');
        
        if (!confirmed) return;

        try {
            // Reset notification preferences to defaults
            this.userPreferences = {};
            this.notificationTypes.forEach(type => {
                this.userPreferences[type.TYPE_CODE] = {
                    emailEnabled: type.DEFAULT_EMAIL_ENABLED === 1,
                    inAppEnabled: type.DEFAULT_IN_APP_ENABLED === 1
                };
            });

            // Reset personal settings to defaults
            this.applyDefaultSettings();

            // Save all changes
            await this.saveAllPreferences();
            
            // Refresh display
            this.displayNotificationPreferences();
            
            this.showToast('All preferences reset to defaults', 'success');
        } catch (error) {
            console.error('Failed to reset preferences:', error);
            this.showToast('Failed to reset preferences', 'error');
        }
    }

    async sendTestEmail() {
        try {
            const response = await fetch('assets/cfc/notifications.cfc?method=createBulkNotification', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    user_ids: this.currentUserId,
                    notification_type: 'TEST_EMAIL',
                    notification_message: 'This is a test email notification to verify your settings are working correctly.'
                })
            });

            const result = await response.json();
            
            if (result.success) {
                this.showToast('Test email sent successfully', 'success');
            } else {
                this.showToast('Failed to send test email', 'error');
            }
        } catch (error) {
            console.error('Failed to send test email:', error);
            this.showToast('Failed to send test email', 'error');
        }
    }

    async sendTestInApp() {
        try {
            const response = await fetch('assets/cfc/notifications.cfc?method=create_notification', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    user_id: this.currentUserId,
                    notification_type: 'TEST_IN_APP',
                    notification_message: 'This is a test in-app notification to verify your settings are working correctly.'
                })
            });

            if (response.ok) {
                this.showToast('Test in-app notification created successfully', 'success');
            } else {
                this.showToast('Failed to create test notification', 'error');
            }
        } catch (error) {
            console.error('Failed to send test in-app notification:', error);
            this.showToast('Failed to send test notification', 'error');
        }
    }

    startAutoRefresh() {
        // Refresh system status every 60 seconds
        setInterval(() => {
            this.loadSystemStatus();
        }, 60000);
    }

    showSaveIndicator() {
        const indicator = document.getElementById('saveIndicator');
        indicator.style.display = 'block';
        
        setTimeout(() => {
            indicator.style.display = 'none';
        }, 3000);
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

    isCurrentUserAdmin() {
        // This should be implemented based on your authentication system
        // For now, return false - users can't see admin-only notifications
        return false;
    }
}

// Initialize when DOM is loaded
let userPrefs;
document.addEventListener('DOMContentLoaded', () => {
    userPrefs = new UserNotificationPreferences();
});

// Global functions for HTML onclick handlers
window.resetToDefaults = () => userPrefs.resetToDefaults();
window.saveAllPreferences = () => userPrefs.saveAllPreferences();
window.sendTestEmail = () => userPrefs.sendTestEmail();
window.sendTestInApp = () => userPrefs.sendTestInApp();

// Export for global access
window.userPrefs = userPrefs;