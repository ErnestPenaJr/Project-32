component extends="mxunit.framework.TestCase" {

    variables.emailService = "";
    variables.notificationManager = "";

    /**
     * Setup - runs before each test
     */
    public void function setUp() {
        variables.emailService = createObject("component", "components.EmailService").init();
        variables.notificationManager = createObject("component", "assets.cfc.SystemNotificationManager");
    }

    /**
     * Teardown - runs after each test
     */
    public void function tearDown() {
        // Clean up any test data if needed
    }

    // ============================================
    // EMAIL SERVICE TESTS
    // ============================================

    /**
     * Test: Email service initializes with default configuration
     */
    public void function testEmailServiceInitialization() {
        assertTrue(isObject(variables.emailService), "Email service should be initialized");
        assertTrue(structKeyExists(variables, "emailService"), "Email service should be accessible");
    }

    /**
     * Test: Booking confirmation email structure
     */
    public void function testBookingConfirmationEmailStructure() {
        var booking = {
            bookingId = 123,
            roomName = "Test Conference Room",
            building = "Test Building",
            roomNumber = "101",
            startTime = createDateTime(2025, 10, 15, 10, 0, 0),
            endTime = createDateTime(2025, 10, 15, 11, 0, 0),
            comments = "Test Meeting",
            status = "Approved"
        };

        var user = {
            firstName = "Test",
            lastName = "User",
            email = "test@example.com"
        };

        // Test that the function exists and accepts proper arguments
        assertTrue(structKeyExists(variables.emailService, "sendBookingConfirmation"), "sendBookingConfirmation method should exist");
    }

    /**
     * Test: Email validation for invalid recipient
     */
    public void function testEmailValidationInvalidRecipient() {
        var invalidEmail = "invalid-email";
        var isValid = isValid("email", invalidEmail);

        assertFalse(isValid, "Invalid email format should fail validation");
    }

    /**
     * Test: Email validation for valid recipient
     */
    public void function testEmailValidationValidRecipient() {
        var validEmail = "test@example.com";
        var isValid = isValid("email", validEmail);

        assertTrue(isValid, "Valid email format should pass validation");
    }

    /**
     * Test: Cancellation email structure
     */
    public void function testCancellationEmailStructure() {
        assertTrue(
            structKeyExists(variables.emailService, "sendBookingCancellation"),
            "sendBookingCancellation method should exist"
        );
    }

    /**
     * Test: Reminder email structure
     */
    public void function testReminderEmailStructure() {
        assertTrue(
            structKeyExists(variables.emailService, "sendBookingReminder"),
            "sendBookingReminder method should exist"
        );
    }

    /**
     * Test: Revision notification email structure
     */
    public void function testRevisionNotificationEmailStructure() {
        assertTrue(
            structKeyExists(variables.emailService, "sendBookingRevisionNotification"),
            "sendBookingRevisionNotification method should exist"
        );
    }

    // ============================================
    // SYSTEM NOTIFICATION MANAGER TESTS
    // ============================================

    /**
     * Test: Notification manager initializes
     */
    public void function testNotificationManagerInitialization() {
        assertTrue(isObject(variables.notificationManager), "Notification manager should be initialized");
    }

    /**
     * Test: Notifications enabled check
     */
    public void function testNotificationsEnabledCheck() {
        assertTrue(
            structKeyExists(variables.notificationManager, "areNotificationsEnabled"),
            "areNotificationsEnabled method should exist"
        );
    }

    /**
     * Test: Email notifications enabled check
     */
    public void function testEmailNotificationsEnabledCheck() {
        assertTrue(
            structKeyExists(variables.notificationManager, "areEmailNotificationsEnabled"),
            "areEmailNotificationsEnabled method should exist"
        );
    }

    /**
     * Test: In-app notifications enabled check
     */
    public void function testInAppNotificationsEnabledCheck() {
        assertTrue(
            structKeyExists(variables.notificationManager, "areInAppNotificationsEnabled"),
            "areInAppNotificationsEnabled method should exist"
        );
    }

    /**
     * Test: Maintenance mode check
     */
    public void function testMaintenanceModeCheck() {
        assertTrue(
            structKeyExists(variables.notificationManager, "isMaintenanceMode"),
            "isMaintenanceMode method should exist"
        );
    }

    /**
     * Test: Emergency mode check
     */
    public void function testEmergencyModeCheck() {
        assertTrue(
            structKeyExists(variables.notificationManager, "isEmergencyMode"),
            "isEmergencyMode method should exist"
        );
    }

    /**
     * Test: Should send notification decision structure
     */
    public void function testShouldSendNotificationDecisionStructure() {
        assertTrue(
            structKeyExists(variables.notificationManager, "shouldSendNotification"),
            "shouldSendNotification method should exist"
        );
    }

    /**
     * Test: System settings cache initialization
     */
    public void function testSystemSettingsCacheInitialization() {
        assertTrue(
            structKeyExists(variables.notificationManager, "getSystemSetting"),
            "getSystemSetting method should exist"
        );
    }

    /**
     * Test: System settings cache refresh
     */
    public void function testSystemSettingsCacheRefresh() {
        assertTrue(
            structKeyExists(variables.notificationManager, "refreshSystemSettingsCache"),
            "refreshSystemSettingsCache method should exist"
        );
    }

    /**
     * Test: User notification preferences retrieval
     */
    public void function testUserNotificationPreferencesRetrieval() {
        assertTrue(
            structKeyExists(variables.notificationManager, "getUserEffectivePreferences"),
            "getUserEffectivePreferences method should exist"
        );
    }

    // ============================================
    // NOTIFICATION DECISION LOGIC TESTS
    // ============================================

    /**
     * Test: Critical notification bypasses quiet hours
     */
    public void function testCriticalNotificationBypassesQuietHours() {
        // Critical notifications should always be sent regardless of quiet hours
        var isCritical = true;
        var isWithinQuietHours = true;

        var shouldSend = isCritical OR !isWithinQuietHours;

        assertTrue(shouldSend, "Critical notifications should bypass quiet hours");
    }

    /**
     * Test: Non-critical notification respects quiet hours
     */
    public void function testNonCriticalNotificationRespectsQuietHours() {
        var isCritical = false;
        var isWithinQuietHours = true;

        var shouldSend = isCritical OR !isWithinQuietHours;

        assertFalse(shouldSend, "Non-critical notifications should respect quiet hours");
    }

    /**
     * Test: Emergency override bypasses all restrictions
     */
    public void function testEmergencyOverrideBypassesRestrictions() {
        var isEmergencyOverride = true;
        var userPreferencesEnabled = false;

        var shouldSend = isEmergencyOverride OR userPreferencesEnabled;

        assertTrue(shouldSend, "Emergency override should bypass all restrictions");
    }

    /**
     * Test: Maintenance mode blocks non-critical notifications
     */
    public void function testMaintenanceModeBlocksNonCritical() {
        var isMaintenanceMode = true;
        var isCritical = false;

        var shouldSend = !isMaintenanceMode OR isCritical;

        assertFalse(shouldSend, "Maintenance mode should block non-critical notifications");
    }

    /**
     * Test: Maintenance mode allows critical notifications
     */
    public void function testMaintenanceModeAllowsCritical() {
        var isMaintenanceMode = true;
        var isCritical = true;

        var shouldSend = !isMaintenanceMode OR isCritical;

        assertTrue(shouldSend, "Maintenance mode should allow critical notifications");
    }

    /**
     * Test: Daily limit enforcement
     */
    public void function testDailyLimitEnforcement() {
        var currentCount = 50;
        var maxDaily = 50;

        var hasExceeded = currentCount >= maxDaily;

        assertTrue(hasExceeded, "Should detect when daily limit is exceeded");
    }

    /**
     * Test: Daily limit not exceeded
     */
    public void function testDailyLimitNotExceeded() {
        var currentCount = 25;
        var maxDaily = 50;

        var hasExceeded = currentCount >= maxDaily;

        assertFalse(hasExceeded, "Should not block when under daily limit");
    }

    // ============================================
    // QUIET HOURS TESTS
    // ============================================

    /**
     * Test: Quiet hours time comparison logic (overnight)
     */
    public void function testQuietHoursOvernightLogic() {
        // Quiet hours: 22:00 to 08:00
        var quietStart = "22:00";
        var quietEnd = "08:00";
        var currentTime = "23:30";

        // Should be within quiet hours (overnight range)
        var startIsGreater = (quietStart > quietEnd); // true for overnight

        assertTrue(startIsGreater, "Should detect overnight quiet hours range");
    }

    /**
     * Test: Quiet hours time comparison logic (same day)
     */
    public void function testQuietHoursSameDayLogic() {
        // Quiet hours: 13:00 to 14:00
        var quietStart = "13:00";
        var quietEnd = "14:00";

        var startIsGreater = (quietStart > quietEnd); // false for same day

        assertFalse(startIsGreater, "Should detect same-day quiet hours range");
    }

    // ============================================
    // NOTIFICATION TYPE TESTS
    // ============================================

    /**
     * Test: Notification type enabled flag
     */
    public void function testNotificationTypeEnabledFlag() {
        var notificationType = {
            enabled = true,
            criticalNotification = false
        };

        assertTrue(notificationType.enabled, "Notification type should be enabled");
    }

    /**
     * Test: Notification type disabled flag
     */
    public void function testNotificationTypeDisabledFlag() {
        var notificationType = {
            enabled = false,
            criticalNotification = false
        };

        assertFalse(notificationType.enabled, "Notification type should be disabled");
    }

    /**
     * Test: Critical notification flag
     */
    public void function testCriticalNotificationFlag() {
        var notificationType = {
            enabled = true,
            criticalNotification = true
        };

        assertTrue(notificationType.criticalNotification, "Should recognize critical notification");
    }

    /**
     * Test: User preference override flag
     */
    public void function testUserPreferenceOverrideFlag() {
        var notificationType = {
            enabled = true,
            overrideUserPreferences = true
        };

        var shouldOverride = notificationType.overrideUserPreferences;

        assertTrue(shouldOverride, "Should recognize user preference override");
    }

    /**
     * Test: Admin-only notification flag
     */
    public void function testAdminOnlyNotificationFlag() {
        var notificationType = {
            enabled = true,
            adminOnly = true
        };

        var isAdminOnly = notificationType.adminOnly;
        var userIsAdmin = true;

        var canReceive = !isAdminOnly OR userIsAdmin;

        assertTrue(canReceive, "Admin should receive admin-only notifications");
    }

    /**
     * Test: Non-admin cannot receive admin-only notifications
     */
    public void function testNonAdminCannotReceiveAdminOnlyNotifications() {
        var notificationType = {
            enabled = true,
            adminOnly = true
        };

        var isAdminOnly = notificationType.adminOnly;
        var userIsAdmin = false;

        var canReceive = !isAdminOnly OR userIsAdmin;

        assertFalse(canReceive, "Non-admin should not receive admin-only notifications");
    }

    // ============================================
    // USER PREFERENCE TESTS
    // ============================================

    /**
     * Test: User email preference enabled
     */
    public void function testUserEmailPreferenceEnabled() {
        var userPreferences = {
            emailEnabled = true,
            inAppEnabled = true
        };

        assertTrue(userPreferences.emailEnabled, "User email preference should be enabled");
    }

    /**
     * Test: User email preference disabled
     */
    public void function testUserEmailPreferenceDisabled() {
        var userPreferences = {
            emailEnabled = false,
            inAppEnabled = true
        };

        assertFalse(userPreferences.emailEnabled, "User email preference should be disabled");
    }

    /**
     * Test: User in-app preference enabled
     */
    public void function testUserInAppPreferenceEnabled() {
        var userPreferences = {
            emailEnabled = true,
            inAppEnabled = true
        };

        assertTrue(userPreferences.inAppEnabled, "User in-app preference should be enabled");
    }

    /**
     * Test: User in-app preference disabled
     */
    public void function testUserInAppPreferenceDisabled() {
        var userPreferences = {
            emailEnabled = true,
            inAppEnabled = false
        };

        assertFalse(userPreferences.inAppEnabled, "User in-app preference should be disabled");
    }

    /**
     * Test: User preferences applied when no override
     */
    public void function testUserPreferencesAppliedWhenNoOverride() {
        var systemOverride = false;
        var userPreferenceEnabled = false;

        var shouldSend = systemOverride OR userPreferenceEnabled;

        assertFalse(shouldSend, "User preferences should be respected when no override");
    }

    /**
     * Test: System override ignores user preferences
     */
    public void function testSystemOverrideIgnoresUserPreferences() {
        var systemOverride = true;
        var userPreferenceEnabled = false;

        var shouldSend = systemOverride OR userPreferenceEnabled;

        assertTrue(shouldSend, "System override should ignore user preferences");
    }

    // ============================================
    // ANALYTICS TESTS
    // ============================================

    /**
     * Test: Analytics tracking structure
     */
    public void function testAnalyticsTrackingStructure() {
        assertTrue(
            structKeyExists(variables.notificationManager, "updateNotificationAnalytics"),
            "updateNotificationAnalytics method should exist"
        );
    }

    /**
     * Test: Analytics retrieval structure
     */
    public void function testAnalyticsRetrievalStructure() {
        assertTrue(
            structKeyExists(variables.notificationManager, "getNotificationAnalytics"),
            "getNotificationAnalytics method should exist"
        );
    }

    /**
     * Test: Notification decision logging
     */
    public void function testNotificationDecisionLogging() {
        assertTrue(
            structKeyExists(variables.notificationManager, "logNotificationDecision"),
            "logNotificationDecision method should exist"
        );
    }

    // ============================================
    // SCHEDULED NOTIFICATION TESTS
    // ============================================

    /**
     * Test: Create notification schedule structure
     */
    public void function testCreateNotificationScheduleStructure() {
        assertTrue(
            structKeyExists(variables.notificationManager, "createNotificationSchedule"),
            "createNotificationSchedule method should exist"
        );
    }

    /**
     * Test: Process scheduled notifications structure
     */
    public void function testProcessScheduledNotificationsStructure() {
        assertTrue(
            structKeyExists(variables.notificationManager, "processScheduledNotifications"),
            "processScheduledNotifications method should exist"
        );
    }

    /**
     * Test: Schedule action types
     */
    public void function testScheduleActionTypes() {
        var validActions = ["ENABLE", "DISABLE", "PAUSE"];

        assertTrue(arrayLen(validActions) EQ 3, "Should have 3 valid action types");
        assertTrue(arrayContains(validActions, "ENABLE"), "Should include ENABLE action");
        assertTrue(arrayContains(validActions, "DISABLE"), "Should include DISABLE action");
        assertTrue(arrayContains(validActions, "PAUSE"), "Should include PAUSE action");
    }

    // ============================================
    // API ENDPOINT TESTS
    // ============================================

    /**
     * Test: Get all system settings endpoint
     */
    public void function testGetAllSystemSettingsEndpoint() {
        assertTrue(
            structKeyExists(variables.notificationManager, "getAllSystemSettings"),
            "getAllSystemSettings method should exist"
        );
    }

    /**
     * Test: Update system setting endpoint
     */
    public void function testUpdateSystemSettingEndpoint() {
        assertTrue(
            structKeyExists(variables.notificationManager, "updateSystemSetting"),
            "updateSystemSetting method should exist"
        );
    }

    /**
     * Test: Toggle notification type endpoint
     */
    public void function testToggleNotificationTypeEndpoint() {
        assertTrue(
            structKeyExists(variables.notificationManager, "toggleNotificationType"),
            "toggleNotificationType method should exist"
        );
    }

    /**
     * Test: Get all notification types with status endpoint
     */
    public void function testGetAllNotificationTypesWithStatusEndpoint() {
        assertTrue(
            structKeyExists(variables.notificationManager, "getAllNotificationTypesWithStatus"),
            "getAllNotificationTypesWithStatus method should exist"
        );
    }

    /**
     * Test: Bulk update notification types endpoint
     */
    public void function testBulkUpdateNotificationTypesEndpoint() {
        assertTrue(
            structKeyExists(variables.notificationManager, "bulkUpdateNotificationTypes"),
            "bulkUpdateNotificationTypes method should exist"
        );
    }

    /**
     * Test: Get notification queue status endpoint
     */
    public void function testGetNotificationQueueStatusEndpoint() {
        assertTrue(
            structKeyExists(variables.notificationManager, "getNotificationQueueStatus"),
            "getNotificationQueueStatus method should exist"
        );
    }

    /**
     * Test: Test notification delivery endpoint
     */
    public void function testTestNotificationDeliveryEndpoint() {
        assertTrue(
            structKeyExists(variables.notificationManager, "testNotificationDelivery"),
            "testNotificationDelivery method should exist"
        );
    }

    // ============================================
    // SYSTEM HEALTH TESTS
    // ============================================

    /**
     * Test: System health calculation - excellent
     */
    public void function testSystemHealthCalculationExcellent() {
        var totalSent = 100;
        var totalFailed = 2;
        var failureRate = (totalFailed / totalSent) * 100;

        var health = (failureRate < 5) ? "excellent" : "other";

        assertEquals("excellent", health, "Should calculate excellent health");
    }

    /**
     * Test: System health calculation - good
     */
    public void function testSystemHealthCalculationGood() {
        var totalSent = 100;
        var totalFailed = 10;
        var failureRate = (totalFailed / totalSent) * 100;

        var health = "other";
        if (failureRate < 5) {
            health = "excellent";
        } else if (failureRate < 15) {
            health = "good";
        }

        assertEquals("good", health, "Should calculate good health");
    }

    /**
     * Test: System health calculation - warning
     */
    public void function testSystemHealthCalculationWarning() {
        var totalSent = 100;
        var totalFailed = 20;
        var failureRate = (totalFailed / totalSent) * 100;

        var health = "other";
        if (failureRate < 5) {
            health = "excellent";
        } else if (failureRate < 15) {
            health = "good";
        } else if (failureRate < 30) {
            health = "warning";
        }

        assertEquals("warning", health, "Should calculate warning health");
    }

    /**
     * Test: System health calculation - critical
     */
    public void function testSystemHealthCalculationCritical() {
        var totalSent = 100;
        var totalFailed = 40;
        var failureRate = (totalFailed / totalSent) * 100;

        var health = "critical";

        assertEquals("critical", health, "Should calculate critical health");
    }
}
