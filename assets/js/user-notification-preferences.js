/**
 * User Notification Preferences JavaScript - World-Class Edition
 * Provides a modern, intuitive interface for managing personal notification preferences
 * with real-time system status awareness, progressive disclosure, and enhanced UX
 * 
 * Features:
 * - Glass morphism design with smooth animations
 * - Progressive disclosure for complex settings
 * - Real-time validation and feedback
 * - Keyboard navigation support
 * - Auto-save with visual feedback
 * - Smart defaults and recommendations
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
        this.approvalSettings = {
            enabled: true,
            mode: 'immediate'
        };
        
        // Enhanced UX state
        this.isLoading = false;
        this.expandedCategories = new Set();
        this.searchQuery = '';
        this.filterActive = false;
        this.lastSaveTime = null;
        this.keyboardNavigationEnabled = false;
        
        // Performance optimization
        this.debouncedSearch = this.debounce(this.performSearch.bind(this), 300);
        this.throttledScroll = this.throttle(this.handleScroll.bind(this), 100);
        
        this.init();
    }

    async saveApprovalNotificationSettings() {
        const payload = {
            enabled: this.approvalSettings.enabled,
            mode: this.approvalSettings.mode
        };

        const formData = new FormData();
        formData.append('user_id', this.currentUserId);
        formData.append('setting_name', 'APPROVAL_NOTIFICATIONS');
        formData.append('setting_type', 'JSON');
        formData.append('setting_value', JSON.stringify(payload));

        const response = await fetch('assets/cfc/SystemNotificationManager.cfc?method=updateUserNotificationSetting', {
            method: 'POST',
            body: formData
        });

        if (!response.ok) {
            throw new Error('Failed to save approval notification settings');
        }

        return response.json();
    }

    async init() {
        try {
            // Show elegant loading state
            this.showLoadingState(true);
            
            // Initialize AOS animations
            if (typeof AOS !== 'undefined') {
                AOS.init({
                    duration: 800,
                    easing: 'ease-out-cubic',
                    once: true,
                    offset: 100
                });
            }
            
            // Load data with progress feedback
            await this.loadSystemStatus();
            await this.loadNotificationTypes();
            await this.loadUserPreferences();
            await this.loadUserSettings();
            await this.loadApprovalSettings();
            
            // Setup enhanced interactions
            this.setupEventListeners();
            this.setupKeyboardNavigation();
            this.setupAdvancedFeatures();
            this.startAutoRefresh();
            this.updateNotificationSummary();
            this.renderApprovalSettings();
            
            // Hide loading and show success
            this.showLoadingState(false);
            Swal.fire({
                title: '🎉 Ready to Go!',
                text: 'Your notification preferences have been loaded successfully',
                icon: 'success',
                confirmButtonColor: 'var(--md-primary)',
                background: 'var(--glass-bg)',
                timer: 3000,
                timerProgressBar: true,
                customClass: {
                    popup: 'swal-modern'
                }
            });
            
        } catch (error) {
            console.error('Failed to initialize user notification preferences:', error);
            this.showLoadingState(false);
            Swal.fire({
                title: 'Loading Error',
                text: 'Failed to load notification preferences. Please refresh the page or contact support if the issue persists.',
                icon: 'error',
                showCancelButton: true,
                confirmButtonColor: 'var(--md-primary)',
                cancelButtonColor: '#6c757d',
                confirmButtonText: 'Retry',
                cancelButtonText: 'Close',
                background: 'var(--glass-bg)',
                customClass: {
                    popup: 'swal-modern'
                }
            }).then((result) => {
                if (result.isConfirmed) {
                    this.init();
                }
            });
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
        const icon = document.getElementById('statusIcon');

        banner.style.display = 'block';
        banner.className = 'system-status-banner';

        if (this.systemStatus.emergencyMode) {
            banner.classList.add('disabled');
            icon.className = 'fas fa-exclamation-triangle status-icon text-danger';
            title.innerHTML = '<span class="text-danger">Emergency Mode Active</span>';
            message.textContent = 'System administrators may override your notification preferences for critical notifications.';
        } else if (this.systemStatus.maintenanceMode) {
            banner.classList.add('maintenance');
            icon.className = 'fas fa-tools status-icon text-warning';
            title.innerHTML = '<span class="text-warning">Maintenance Mode</span>';
            message.textContent = 'Only critical notifications are currently being sent. Non-critical notifications are paused.';
        } else if (!this.systemStatus.notificationsEnabled) {
            banner.classList.add('disabled');
            icon.className = 'fas fa-times-circle status-icon text-danger';
            title.innerHTML = '<span class="text-danger">Notifications Disabled</span>';
            message.textContent = 'Notifications are currently disabled system-wide by administrators.';
        } else {
            banner.classList.add('normal');
            icon.className = 'fas fa-check-circle status-icon text-success';
            title.innerHTML = '<span class="text-success">System Operational</span>';
            message.textContent = 'All notification systems are functioning normally.';
        }
        
        // Animate banner entrance
        banner.style.opacity = '0';
        banner.style.transform = 'translateY(-20px)';
        
        setTimeout(() => {
            banner.style.transition = 'all 0.5s cubic-bezier(0.25, 0.46, 0.45, 0.94)';
            banner.style.opacity = '1';
            banner.style.transform = 'translateY(0)';
        }, 100);
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

    /**
     * A CFC returning returntype="query" serialises as
     * {"COLUMNS":["A","B"],"DATA":[[1,2],[3,4]]}, not as an array of objects.
     * This only ever tested Array.isArray(), so userPreferences stayed empty
     * forever: every per-type toggle showed as unset and saveAllPreferences had
     * nothing to persist. Normalise both shapes to an array of row objects.
     */
    static normalizeQueryResult(payload) {
        if (Array.isArray(payload)) return payload;
        if (payload && Array.isArray(payload.COLUMNS) && Array.isArray(payload.DATA)) {
            return payload.DATA.map(row => {
                const obj = {};
                payload.COLUMNS.forEach((col, i) => { obj[col] = row[i]; });
                return obj;
            });
        }
        return [];
    }

    processUserPreferences(preferences) {
        this.userPreferences = {};

        const truthy = v => v === 1 || v === true || v === '1';

        UserNotificationPreferences.normalizeQueryResult(preferences).forEach(pref => {
            // Skip rows with no type code rather than creating a "null" key.
            if (!pref.NOTIFICATION_TYPE) return;
            this.userPreferences[pref.NOTIFICATION_TYPE] = {
                emailEnabled: truthy(pref.EMAIL_ENABLED),
                inAppEnabled: truthy(pref.IN_APP_ENABLED)
            };
        });
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

    async loadApprovalSettings() {
        try {
            const params = new URLSearchParams({
                user_id: this.currentUserId,
                setting_name: 'APPROVAL_NOTIFICATIONS'
            });

            const response = await fetch(`assets/cfc/SystemNotificationManager.cfc?method=getUserNotificationSetting&${params.toString()}`, {
                method: 'GET',
                headers: {
                    'Content-Type': 'application/json'
                }
            });

            const result = await response.json();
            if (result && result.success && result.data) {
                if (typeof result.data.enabled === 'boolean') {
                    this.approvalSettings.enabled = result.data.enabled;
                }
                if (result.data.mode) {
                    this.approvalSettings.mode = result.data.mode;
                }
            } else {
                this.approvalSettings = { enabled: true, mode: 'immediate' };
            }
        } catch (error) {
            console.error('Failed to load approval settings:', error);
            this.approvalSettings = { enabled: true, mode: 'immediate' };
        }
    }

    renderApprovalSettings() {
        const toggle = document.getElementById('approvalNotificationsToggle');
        const modeSelect = document.getElementById('approvalNotificationMode');

        if (toggle && modeSelect) {
            toggle.checked = this.approvalSettings.enabled;
            modeSelect.value = this.approvalSettings.mode;
            modeSelect.disabled = !this.approvalSettings.enabled;
        }
    }

    handleApprovalToggleChange(enabled) {
        this.approvalSettings.enabled = enabled;
        const modeSelect = document.getElementById('approvalNotificationMode');
        if (modeSelect) {
            modeSelect.disabled = !enabled;
        }
        this.scheduleAutoSave();
    }

    handleApprovalModeChange(mode) {
        this.approvalSettings.mode = mode;
        this.scheduleAutoSave();
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
            'Booking Lifecycle': 'fas fa-calendar-check',
            'Approval Workflow': 'fas fa-check-circle',
            'User Management': 'fas fa-users',
            'System': 'fas fa-cogs',
            'Administrative': 'fas fa-shield-alt'
        };

        const icon = categoryIcons[category] || 'fas fa-bell';
        const isExpanded = this.expandedCategories.has(category);
        const categoryId = category.replace(/\s+/g, '-').toLowerCase();

        let html = `
            <div class="category-section mb-4" data-aos="fade-up" data-aos-duration="600">
                <div class="category-header cursor-pointer" onclick="userPrefs.toggleCategory('${category}')" 
                     role="button" tabindex="0" aria-expanded="${isExpanded}" 
                     aria-controls="${categoryId}-content">
                    <div class="d-flex align-items-center justify-content-between">
                        <div class="d-flex align-items-center">
                            <i class="${icon} me-3 text-primary"></i>
                            <div>
                                <h4 class="category-title mb-0">${category}</h4>
                                <small class="text-muted">${types.length} notification type${types.length !== 1 ? 's' : ''}</small>
                            </div>
                        </div>
                        <div class="d-flex align-items-center gap-3">
                            <div class="category-summary small text-muted">
                                <span id="${categoryId}-enabled-count">0</span> enabled
                            </div>
                            <i class="fas fa-chevron-down category-chevron ${isExpanded ? 'rotated' : ''}" 
                               style="transition: transform 0.3s ease;"></i>
                        </div>
                    </div>
                </div>
                <div class="category-content ${isExpanded ? 'show' : ''}" id="${categoryId}-content" 
                     style="max-height: ${isExpanded ? 'none' : '0'}; overflow: hidden; transition: max-height 0.5s cubic-bezier(0.25, 0.46, 0.45, 0.94);">
                    <div class="row g-3 mt-2">
        `;

        types.forEach((type, index) => {
            html += this.createNotificationTypeCard(type, index);
        });

        html += `
                    </div>
                </div>
            </div>
        `;

        return html;
    }

    createNotificationTypeCard(type, index) {
        const userPref = this.userPreferences[type.TYPE_CODE] || {};
        const emailEnabled = userPref.emailEnabled !== undefined ? userPref.emailEnabled : (type.DEFAULT_EMAIL_ENABLED === 1);
        const inAppEnabled = userPref.inAppEnabled !== undefined ? userPref.inAppEnabled : (type.DEFAULT_IN_APP_ENABLED === 1);
        
        const isSystemDisabled = type.ENABLED === 0;
        const hasSystemOverride = type.OVERRIDE_USER_PREFERENCES === 1;
        const isCritical = type.CRITICAL_NOTIFICATION === 1;
        const isEmergencyOverride = type.EMERGENCY_OVERRIDE === 1;
        
        let cardClass = 'preference-card';
        let statusInfo = '';
        
        if (isSystemDisabled) {
            cardClass += ' system-disabled';
            statusInfo = `
                <div class="alert alert-danger alert-sm mb-3 d-flex align-items-center">
                    <i class="fas fa-times-circle me-2"></i>
                    <span>Disabled by administrator</span>
                </div>`;
        } else if (hasSystemOverride) {
            cardClass += ' system-override';
            statusInfo = `
                <div class="alert alert-warning alert-sm mb-3 d-flex align-items-center">
                    <i class="fas fa-exclamation-triangle me-2"></i>
                    <span>System may override preferences</span>
                </div>`;
        }

        const emailDisabled = !this.systemStatus.emailEnabled || isSystemDisabled;
        const inAppDisabled = !this.systemStatus.inAppEnabled || isSystemDisabled;

        return `
            <div class="col-md-6 col-xl-4 mb-3">
                <div class="card ${cardClass}" data-aos="fade-up" data-aos-delay="${index * 50}">
                    <div class="card-body p-4">
                        <div class="d-flex justify-content-between align-items-start mb-3">
                            <div class="flex-grow-1">
                                <h6 class="card-title mb-1 fw-bold">${type.DISPLAY_NAME}</h6>
                                <div class="d-flex gap-1 mb-0">
                                    ${isCritical ? '<span class="badge bg-danger rounded-pill"><i class="fas fa-exclamation-circle me-1"></i>Critical</span>' : ''}
                                    ${hasSystemOverride ? '<span class="badge bg-warning rounded-pill"><i class="fas fa-shield-alt me-1"></i>Override</span>' : ''}
                                    ${isEmergencyOverride ? '<span class="badge bg-dark rounded-pill"><i class="fas fa-bolt me-1"></i>Emergency</span>' : ''}
                                </div>
                            </div>
                        </div>
                        
                        ${statusInfo}
                        
                        <p class="card-text text-muted mb-4">${type.DESCRIPTION || 'No description available'}</p>
                        
                        <div class="notification-toggles">
                            <div class="toggle-group mb-3">
                                <div class="d-flex justify-content-between align-items-center">
                                    <div class="toggle-label">
                                        <i class="fas fa-envelope me-2 text-primary"></i>
                                        <span class="fw-semibold">Email</span>
                                        <br>
                                        <small class="text-muted">Receive via email</small>
                                    </div>
                                    <label class="toggle-switch">
                                        <input type="checkbox" 
                                               ${emailEnabled ? 'checked' : ''} 
                                               ${emailDisabled ? 'disabled' : ''}
                                               data-type="${type.TYPE_CODE}" 
                                               data-method="email"
                                               onchange="userPrefs.handlePreferenceChange(this)"
                                               aria-label="Toggle email notifications for ${type.DISPLAY_NAME}">
                                        <span class="slider"></span>
                                    </label>
                                </div>
                            </div>
                            
                            <div class="toggle-group">
                                <div class="d-flex justify-content-between align-items-center">
                                    <div class="toggle-label">
                                        <i class="fas fa-mobile-alt me-2 text-success"></i>
                                        <span class="fw-semibold">In-App</span>
                                        <br>
                                        <small class="text-muted">Show in application</small>
                                    </div>
                                    <label class="toggle-switch">
                                        <input type="checkbox" 
                                               ${inAppEnabled ? 'checked' : ''} 
                                               ${inAppDisabled ? 'disabled' : ''}
                                               data-type="${type.TYPE_CODE}" 
                                               data-method="in_app"
                                               onchange="userPrefs.handlePreferenceChange(this)"
                                               aria-label="Toggle in-app notifications for ${type.DISPLAY_NAME}">
                                        <span class="slider"></span>
                                    </label>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        `;
    }

    setupEventListeners() {
        // Enhanced range input with real-time feedback
        const rangeInput = document.getElementById('maxDailyNotifications');
        const rangeValue = document.getElementById('maxDailyValue');
        
        rangeInput.addEventListener('input', (e) => {
            const value = e.target.value;
            rangeValue.textContent = value;
            rangeValue.style.transform = 'scale(1.1)';
            setTimeout(() => rangeValue.style.transform = 'scale(1)', 200);
            
            // Color coding based on value
            if (value < 20) {
                rangeValue.style.color = 'var(--md-success)';
            } else if (value > 75) {
                rangeValue.style.color = 'var(--md-warning)';
            } else {
                rangeValue.style.color = 'var(--md-primary)';
            }
            
            this.scheduleAutoSave();
        });

        // Personal settings with enhanced feedback
        ['quietHoursStart', 'quietHoursEnd', 'enableQuietHours', 'digestMode'].forEach(id => {
            const element = document.getElementById(id);
            element.addEventListener('change', (e) => {
                this.animateSettingChange(e.target);
                this.scheduleAutoSave();
            });
        });

        const approvalToggle = document.getElementById('approvalNotificationsToggle');
        const approvalMode = document.getElementById('approvalNotificationMode');

        if (approvalToggle) {
            approvalToggle.addEventListener('change', (e) => {
                this.handleApprovalToggleChange(e.target.checked);
            });
        }

        if (approvalMode) {
            approvalMode.addEventListener('change', (e) => {
                this.handleApprovalModeChange(e.target.value);
            });
        }

        // Enhanced beforeunload with better UX
        window.addEventListener('beforeunload', (e) => {
            if (this.unsavedChanges) {
                const message = 'You have unsaved changes that will be lost.';
                e.preventDefault();
                e.returnValue = message;
                return message;
            }
        });
        
        // Page visibility change handling
        document.addEventListener('visibilitychange', () => {
            if (document.visibilityState === 'visible' && this.lastSaveTime) {
                this.refreshSystemStatus();
            }
        });
        
        // Scroll handling for enhanced effects
        window.addEventListener('scroll', this.throttledScroll);
    }

    handlePreferenceChange(checkbox) {
        const typeCode = checkbox.dataset.type;
        const method = checkbox.dataset.method;
        const enabled = checkbox.checked;

        // Animate the change
        this.animateToggleChange(checkbox, enabled);

        // Update local preferences
        if (!this.userPreferences[typeCode]) {
            this.userPreferences[typeCode] = {};
        }
        
        if (method === 'email') {
            this.userPreferences[typeCode].emailEnabled = enabled;
        } else if (method === 'in_app') {
            this.userPreferences[typeCode].inAppEnabled = enabled;
        }

        // Show immediate feedback
        this.showPreferenceChangeToast(typeCode, method, enabled);
        
        // Update summary and schedule save
        this.updateNotificationSummary();
        this.scheduleAutoSave();
        
        // Update category counts
        this.updateCategoryCounts();
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
            promises.push(this.saveApprovalNotificationSettings());

            await Promise.all(promises);

            this.unsavedChanges = false;
            
            if (isAutoSave) {
                this.showSaveIndicator();
            } else {
                Swal.fire({
                    title: 'Success!',
                    text: 'All preferences have been saved successfully',
                    icon: 'success',
                    confirmButtonColor: 'var(--md-primary)',
                    background: 'var(--glass-bg)',
                    timer: 2000,
                    timerProgressBar: true,
                    customClass: {
                        popup: 'swal-modern'
                    }
                });
            }

        } catch (error) {
            console.error('Failed to save preferences:', error);
            Swal.fire({
                title: 'Save Error!',
                text: 'Failed to save some preferences. Please try again or contact support.',
                icon: 'error',
                confirmButtonColor: 'var(--md-danger)',
                background: 'var(--glass-bg)',
                customClass: {
                    popup: 'swal-modern'
                }
            });
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
        const result = await Swal.fire({
            title: 'Reset to Defaults?',
            text: 'Are you sure you want to reset all notification preferences to their default values? This action cannot be undone.',
            icon: 'warning',
            showCancelButton: true,
            confirmButtonColor: 'var(--md-primary)',
            cancelButtonColor: '#6c757d',
            confirmButtonText: 'Yes, Reset All',
            cancelButtonText: 'Cancel',
            background: 'var(--glass-bg)',
            backdrop: 'rgba(0, 0, 0, 0.4)',
            customClass: {
                popup: 'swal-modern'
            }
        });
        
        if (!result.isConfirmed) return;

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
            
            Swal.fire({
                title: 'Success!',
                text: 'All preferences have been reset to their default values',
                icon: 'success',
                confirmButtonColor: 'var(--md-primary)',
                background: 'var(--glass-bg)',
                customClass: {
                    popup: 'swal-modern'
                }
            });
        } catch (error) {
            console.error('Failed to reset preferences:', error);
            Swal.fire({
                title: 'Error!',
                text: 'Failed to reset preferences. Please try again or contact support.',
                icon: 'error',
                confirmButtonColor: 'var(--md-danger)',
                background: 'var(--glass-bg)',
                customClass: {
                    popup: 'swal-modern'
                }
            });
        }
    }

    async sendTestEmail() {
        try {
            // CFC remote methods invoked as ?method=... read their arguments from
            // form/URL scope. A JSON request body is never unpacked into
            // `arguments`, so posting one made CF throw "The USER_IDS parameter
            // ... is required but was not passed in" and return a 500 HTML error
            // page, which then broke response.json(). Post form-encoded instead.
            const response = await fetch('assets/cfc/notifications.cfc?method=createBulkNotification', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/x-www-form-urlencoded',
                },
                body: new URLSearchParams({
                    user_ids: this.currentUserId,
                    notification_type: 'TEST_EMAIL',
                    notification_message: 'This is a test email notification to verify your settings are working correctly.'
                })
            });

            const result = await response.json();
            
            if (result.success) {
                Swal.fire({
                    title: 'Test Email Sent!',
                    text: 'A test email has been sent to your registered email address',
                    icon: 'success',
                    confirmButtonColor: 'var(--md-primary)',
                    background: 'var(--glass-bg)',
                    timer: 3000,
                    timerProgressBar: true,
                    customClass: {
                        popup: 'swal-modern'
                    }
                });
            } else {
                Swal.fire({
                    title: 'Email Error!',
                    text: 'Failed to send test email. Please check your email settings.',
                    icon: 'error',
                    confirmButtonColor: 'var(--md-danger)',
                    background: 'var(--glass-bg)',
                    customClass: {
                        popup: 'swal-modern'
                    }
                });
            }
        } catch (error) {
            console.error('Failed to send test email:', error);
            Swal.fire({
                title: 'Network Error!',
                text: 'Failed to send test email due to network issues. Please try again.',
                icon: 'error',
                confirmButtonColor: 'var(--md-danger)',
                background: 'var(--glass-bg)',
                customClass: {
                    popup: 'swal-modern'
                }
            });
        }
    }

    async sendTestInApp() {
        try {
            // Form-encoded for the same reason as sendTestEmail: a JSON body is
            // not unpacked into a CFC's `arguments` scope.
            //
            // force_create bypasses shouldSendNotification(). TEST_IN_APP is not
            // a row in NOTIFICATION_TYPES, so the gate would return
            // "Notification type not found" and silently drop a test the user
            // explicitly asked for.
            const response = await fetch('assets/cfc/notifications.cfc?method=create_notification', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/x-www-form-urlencoded',
                },
                body: new URLSearchParams({
                    user_id: this.currentUserId,
                    notification_type: 'TEST_IN_APP',
                    notification_message: 'This is a test in-app notification to verify your settings are working correctly.',
                    force_create: 'true'
                })
            });

            // create_notification returns a bare JSON boolean. A 200 with `false`
            // means the insert failed, so response.ok alone would report a
            // success that never happened.
            const created = response.ok ? await response.json() : false;

            if (created === true) {
                Swal.fire({
                    title: 'In-App Test Created!',
                    text: 'A test in-app notification has been created successfully',
                    icon: 'success',
                    confirmButtonColor: 'var(--md-primary)',
                    background: 'var(--glass-bg)',
                    timer: 3000,
                    timerProgressBar: true,
                    customClass: {
                        popup: 'swal-modern'
                    }
                });
            } else {
                Swal.fire({
                    title: 'Notification Error!',
                    text: 'Failed to create test in-app notification. Please try again.',
                    icon: 'error',
                    confirmButtonColor: 'var(--md-danger)',
                    background: 'var(--glass-bg)',
                    customClass: {
                        popup: 'swal-modern'
                    }
                });
            }
        } catch (error) {
            console.error('Failed to send test in-app notification:', error);
            Swal.fire({
                title: 'Network Error!',
                text: 'Failed to send test in-app notification due to network issues. Please try again.',
                icon: 'error',
                confirmButtonColor: 'var(--md-danger)',
                background: 'var(--glass-bg)',
                customClass: {
                    popup: 'swal-modern'
                }
            });
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
        indicator.classList.add('show');
        
        setTimeout(() => {
            indicator.classList.remove('show');
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
        // Check session storage for admin role
        const userRole = sessionStorage.getItem('ROLE');
        return userRole === 'Site Admin' || userRole === 'Admin';
    }

    // Enhanced UX Methods
    
    toggleCategory(categoryName) {
        if (this.expandedCategories.has(categoryName)) {
            this.expandedCategories.delete(categoryName);
        } else {
            this.expandedCategories.add(categoryName);
        }
        
        const categoryId = categoryName.replace(/\s+/g, '-').toLowerCase();
        const content = document.getElementById(`${categoryId}-content`);
        const chevron = document.querySelector(`[onclick="userPrefs.toggleCategory('${categoryName}')"] .category-chevron`);
        
        if (content && chevron) {
            const isExpanding = this.expandedCategories.has(categoryName);
            
            if (isExpanding) {
                content.style.maxHeight = content.scrollHeight + 'px';
                chevron.style.transform = 'rotate(180deg)';
                content.classList.add('show');
            } else {
                content.style.maxHeight = '0px';
                chevron.style.transform = 'rotate(0deg)';
                content.classList.remove('show');
            }
        }
    }
    
    setupKeyboardNavigation() {
        document.addEventListener('keydown', (e) => {
            // Enable keyboard navigation with Tab and Arrow keys
            if (e.key === 'Tab' || e.key === 'ArrowUp' || e.key === 'ArrowDown') {
                this.keyboardNavigationEnabled = true;
            }
            
            // Save with Ctrl+S
            if (e.ctrlKey && e.key === 's') {
                e.preventDefault();
                this.saveAllPreferences();
            }
            
            // Search with Ctrl+F
            if (e.ctrlKey && e.key === 'f') {
                e.preventDefault();
                this.focusSearch();
            }
        });
    }
    
    setupAdvancedFeatures() {
        // Add search functionality
        this.addSearchCapability();
        
        // Add bulk actions
        this.addBulkActions();
        
        // Add smart recommendations
        this.showSmartRecommendations();
    }
    
    addSearchCapability() {
        const categoriesContainer = document.getElementById('notificationCategories');
        if (!categoriesContainer.querySelector('.search-container')) {
            const searchHTML = `
                <div class="search-container mb-4">
                    <div class="input-group">
                        <span class="input-group-text">
                            <i class="fas fa-search"></i>
                        </span>
                        <input type="text" class="form-control form-control-modern" 
                               placeholder="Search notification types..." 
                               id="notificationSearch">
                        <button class="btn btn-outline-secondary" type="button" onclick="userPrefs.clearSearch()">
                            <i class="fas fa-times"></i>
                        </button>
                    </div>
                </div>
            `;
            
            categoriesContainer.insertAdjacentHTML('afterbegin', searchHTML);
            
            document.getElementById('notificationSearch').addEventListener('input', (e) => {
                this.debouncedSearch(e.target.value);
            });
        }
    }
    
    addBulkActions() {
        const categoriesContainer = document.getElementById('notificationCategories');
        if (!categoriesContainer.querySelector('.bulk-actions')) {
            const bulkHTML = `
                <div class="bulk-actions mb-4 d-none" id="bulkActions">
                    <div class="card">
                        <div class="card-body p-3">
                            <div class="d-flex align-items-center justify-content-between">
                                <div class="d-flex align-items-center gap-3">
                                    <span class="fw-bold">Bulk Actions:</span>
                                    <button class="btn btn-sm btn-outline-success" onclick="userPrefs.enableAllVisible(true)">
                                        <i class="fas fa-check-double me-1"></i> Enable All Email
                                    </button>
                                    <button class="btn btn-sm btn-outline-primary" onclick="userPrefs.enableAllVisible(false)">
                                        <i class="fas fa-mobile-alt me-1"></i> Enable All In-App
                                    </button>
                                </div>
                                <button class="btn btn-sm btn-outline-secondary" onclick="userPrefs.hideBulkActions()">
                                    <i class="fas fa-times"></i>
                                </button>
                            </div>
                        </div>
                    </div>
                </div>
            `;
            
            categoriesContainer.insertAdjacentHTML('afterbegin', bulkHTML);
        }
    }
    
    animateToggleChange(checkbox, enabled) {
        const card = checkbox.closest('.preference-card');
        if (card) {
            card.style.transform = 'scale(0.98)';
            setTimeout(() => {
                card.style.transform = 'scale(1)';
            }, 150);
        }
        
        // Add ripple effect
        const ripple = document.createElement('div');
        ripple.classList.add('ripple');
        checkbox.parentNode.appendChild(ripple);
        
        setTimeout(() => {
            ripple.remove();
        }, 600);
    }
    
    animateSettingChange(element) {
        element.style.transform = 'scale(1.05)';
        setTimeout(() => {
            element.style.transform = 'scale(1)';
        }, 200);
    }
    
    showPreferenceChangeToast(typeCode, method, enabled) {
        const type = this.notificationTypes.find(t => t.TYPE_CODE === typeCode);
        const typeName = type ? type.DISPLAY_NAME : typeCode;
        const methodName = method === 'email' ? 'Email' : 'In-App';
        const action = enabled ? 'enabled' : 'disabled';
        
        // Mini toast for quick feedback
        this.showMiniToast(`${methodName} notifications ${action} for ${typeName}`, enabled ? 'success' : 'info');
    }
    
    showMiniToast(message, type) {
        const toast = document.createElement('div');
        toast.className = `mini-toast ${type}`;
        toast.innerHTML = `
            <i class="fas fa-${type === 'success' ? 'check' : 'info-circle'} me-2"></i>
            <span>${message}</span>
        `;
        
        toast.style.cssText = `
            position: fixed;
            top: 80px;
            right: 20px;
            background: var(--glass-bg);
            backdrop-filter: blur(20px);
            border: 1px solid var(--glass-border);
            border-radius: 8px;
            padding: 12px 16px;
            color: ${type === 'success' ? 'var(--md-success)' : 'var(--md-info)'};
            font-weight: 500;
            z-index: 1060;
            transform: translateX(100%);
            transition: transform 0.3s ease;
            box-shadow: var(--shadow-soft);
        `;
        
        document.body.appendChild(toast);
        
        setTimeout(() => {
            toast.style.transform = 'translateX(0)';
        }, 100);
        
        setTimeout(() => {
            toast.style.transform = 'translateX(100%)';
            setTimeout(() => toast.remove(), 300);
        }, 2000);
    }
    
    updateCategoryCounts() {
        const categories = this.groupNotificationsByCategory();
        
        Object.entries(categories).forEach(([categoryName, types]) => {
            const categoryId = categoryName.replace(/\s+/g, '-').toLowerCase();
            const countElement = document.getElementById(`${categoryId}-enabled-count`);
            
            if (countElement) {
                const enabledCount = types.reduce((count, type) => {
                    const userPref = this.userPreferences[type.TYPE_CODE] || {};
                    const emailEnabled = userPref.emailEnabled !== undefined ? userPref.emailEnabled : (type.DEFAULT_EMAIL_ENABLED === 1);
                    const inAppEnabled = userPref.inAppEnabled !== undefined ? userPref.inAppEnabled : (type.DEFAULT_IN_APP_ENABLED === 1);
                    
                    return count + ((emailEnabled || inAppEnabled) ? 1 : 0);
                }, 0);
                
                countElement.textContent = enabledCount;
            }
        });
    }
    
    performSearch(query) {
        this.searchQuery = query.toLowerCase();
        const cards = document.querySelectorAll('.preference-card');
        
        cards.forEach(card => {
            const title = card.querySelector('.card-title').textContent.toLowerCase();
            const description = card.querySelector('.card-text').textContent.toLowerCase();
            const matches = title.includes(this.searchQuery) || description.includes(this.searchQuery);
            
            card.style.display = matches || !this.searchQuery ? 'block' : 'none';
        });
        
        // Show/hide bulk actions based on search
        const bulkActions = document.getElementById('bulkActions');
        if (bulkActions) {
            bulkActions.classList.toggle('d-none', !this.searchQuery);
        }
    }
    
    clearSearch() {
        document.getElementById('notificationSearch').value = '';
        this.performSearch('');
    }
    
    showLoadingState(show) {
        const container = document.getElementById('notificationCategories');
        if (show) {
            container.innerHTML = `
                <div class="text-center py-5">
                    <div class="d-flex flex-column align-items-center">
                        <div class="loading-spinner mb-3"></div>
                        <h5 class="text-muted">Loading your notification preferences</h5>
                        <p class="text-muted mb-0">Please wait while we fetch your settings...</p>
                    </div>
                </div>
            `;
        }
        this.isLoading = show;
    }
    
    showSuccessMessage(title, options = {}) {
        const { icon = '✅', description = '', action = null } = options;
        
        this.showToast(`${icon} ${title}`, 'success');
        
        if (description) {
            setTimeout(() => {
                this.showMiniToast(description, 'info');
            }, 500);
        }
    }
    
    showErrorMessage(title, options = {}) {
        const { description = '', action = null } = options;
        
        this.showToast(title, 'error');
        
        if (action) {
            // Add retry button or other action
            console.log('Action available:', action);
        }
    }
    
    refreshSystemStatus() {
        this.loadSystemStatus();
    }
    
    handleScroll() {
        // Add scroll-based effects if needed
        const scrolled = window.scrollY > 100;
        document.body.classList.toggle('scrolled', scrolled);
    }
    
    // Utility functions
    debounce(func, wait) {
        let timeout;
        return function executedFunction(...args) {
            const later = () => {
                clearTimeout(timeout);
                func(...args);
            };
            clearTimeout(timeout);
            timeout = setTimeout(later, wait);
        };
    }
    
    throttle(func, limit) {
        let inThrottle;
        return function() {
            const args = arguments;
            const context = this;
            if (!inThrottle) {
                func.apply(context, args);
                inThrottle = true;
                setTimeout(() => inThrottle = false, limit);
            }
        };
    }
    
    showSmartRecommendations() {
        // Analyze user's current settings and show intelligent recommendations
        setTimeout(() => {
            this.analyzeAndSuggest();
        }, 2000);
    }
    
    analyzeAndSuggest() {
        const enabledCount = Object.values(this.userPreferences).filter(pref => 
            pref.emailEnabled || pref.inAppEnabled
        ).length;
        
        const totalTypes = this.notificationTypes.filter(type => 
            type.ADMIN_ONLY === 0 || this.isCurrentUserAdmin()
        ).length;
        
        if (enabledCount < totalTypes * 0.3) {
            this.showRecommendation('Consider enabling more notification types to stay informed about important updates.', 'info');
        } else if (enabledCount > totalTypes * 0.8) {
            this.showRecommendation('You have many notifications enabled. Consider using digest mode to reduce frequency.', 'suggestion');
        }
    }
    
    showRecommendation(message, type) {
        // Show smart recommendation
        console.log('Recommendation:', message, type);
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

// Enhanced global functions
window.expandAll = () => {
    Object.keys(userPrefs.groupNotificationsByCategory()).forEach(category => {
        if (!userPrefs.expandedCategories.has(category)) {
            userPrefs.toggleCategory(category);
        }
    });
};

window.collapseAll = () => {
    Array.from(userPrefs.expandedCategories).forEach(category => {
        userPrefs.toggleCategory(category);
    });
};

// Export for global access
window.userPrefs = userPrefs;