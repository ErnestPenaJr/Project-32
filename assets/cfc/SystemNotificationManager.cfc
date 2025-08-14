<cfcomponent displayname="SystemNotificationManager" hint="System-wide notification control and management component">
    
    <!--- Database configuration based on server environment --->
    <cfif ListFirst(CGI.SERVER_NAME,'.') EQ 'cmapps'>
        <cfset this.DBSERVER = "inside2_docmp" />
        <cfset this.DBUSER = "CONFROOM_USER" />
        <cfset this.DBPASS = "1DOCMAU4CNFRM6" />
        <cfset this.DBSCHEMA = "CONFROOM" />
    <cfelseif ListFirst(CGI.SERVER_NAME,'.') EQ 's-cmapps'>
        <cfset this.DBSERVER = "inside2_docms" />
        <cfset this.DBUSER = "CONFROOM" />
        <cfset this.DBPASS = "1DOCMOA4CNFRM3" />
        <cfset this.DBSCHEMA = "CONFROOM" />
    <cfelse>
        <cfset this.DBSERVER = "inside2_docmd" />
        <cfset this.DBUSER = "CONFROOM" />
        <cfset this.DBPASS = "1DOCMOA4CNFRM3" />
        <cfset this.DBSCHEMA = "CONFROOM" />
    </cfif>

    <!--- Initialize component with caching for system settings --->
    <cfset variables.systemSettingsCache = {}>
    <cfset variables.cacheTimeout = 300> <!--- 5 minutes cache timeout --->
    <cfset variables.lastCacheUpdate = now()>

    <!--- ============================================
          SYSTEM-WIDE NOTIFICATION CONTROL FUNCTIONS
          ============================================ --->

    <!--- Check if notifications are globally enabled --->
    <cffunction name="areNotificationsEnabled" access="public" returntype="boolean" output="false">
        <cfreturn getSystemSetting("NOTIFICATIONS_ENABLED", "1") EQ "1">
    </cffunction>

    <!--- Check if system is in maintenance mode --->
    <cffunction name="isMaintenanceMode" access="public" returntype="boolean" output="false">
        <cfreturn getSystemSetting("MAINTENANCE_MODE", "0") EQ "1">
    </cffunction>

    <!--- Check if system is in emergency mode --->
    <cffunction name="isEmergencyMode" access="public" returntype="boolean" output="false">
        <cfreturn getSystemSetting("EMERGENCY_MODE", "0") EQ "1">
    </cffunction>

    <!--- Check if email notifications are globally enabled --->
    <cffunction name="areEmailNotificationsEnabled" access="public" returntype="boolean" output="false">
        <cfreturn getSystemSetting("EMAIL_NOTIFICATIONS_ENABLED", "1") EQ "1">
    </cffunction>

    <!--- Check if in-app notifications are globally enabled --->
    <cffunction name="areInAppNotificationsEnabled" access="public" returntype="boolean" output="false">
        <cfreturn getSystemSetting("IN_APP_NOTIFICATIONS_ENABLED", "1") EQ "1">
    </cffunction>

    <!--- Main function to check if a notification should be sent --->
    <cffunction name="shouldSendNotification" access="public" returntype="struct" output="false">
        <cfargument name="user_id" type="numeric" required="true">
        <cfargument name="notification_type" type="string" required="true">
        <cfargument name="bypass_user_preferences" type="boolean" required="false" default="false">
        
        <cfset local.result = {
            "allow_email": false,
            "allow_in_app": false,
            "reason": "",
            "system_override": false,
            "critical_notification": false
        }>
        
        <cftry>
            <!--- First check if notifications are globally disabled --->
            <cfif NOT areNotificationsEnabled()>
                <cfset local.result.reason = "Notifications globally disabled">
                <cfreturn local.result>
            </cfif>

            <!--- Get notification type details --->
            <cfquery name="qNotificationType" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT 
                    TYPE_CODE,
                    ENABLED,
                    CRITICAL_NOTIFICATION,
                    OVERRIDE_USER_PREFERENCES,
                    EMERGENCY_OVERRIDE,
                    DEFAULT_EMAIL_ENABLED,
                    DEFAULT_IN_APP_ENABLED,
                    ADMIN_ONLY
                FROM #this.DBSCHEMA#.NOTIFICATION_TYPES
                WHERE TYPE_CODE = <cfqueryparam value="#arguments.notification_type#" cfsqltype="cf_sql_varchar">
            </cfquery>

            <cfif qNotificationType.recordCount EQ 0>
                <cfset local.result.reason = "Notification type not found">
                <cfreturn local.result>
            </cfif>

            <!--- Check if notification type is enabled --->
            <cfif qNotificationType.ENABLED EQ 0>
                <cfset local.result.reason = "Notification type disabled">
                <cfreturn local.result>
            </cfif>

            <cfset local.result.critical_notification = qNotificationType.CRITICAL_NOTIFICATION EQ 1>

            <!--- Emergency override bypasses all restrictions --->
            <cfif qNotificationType.EMERGENCY_OVERRIDE EQ 1 OR isEmergencyMode()>
                <cfset local.result.allow_email = areEmailNotificationsEnabled()>
                <cfset local.result.allow_in_app = areInAppNotificationsEnabled()>
                <cfset local.result.system_override = true>
                <cfset local.result.reason = "Emergency override active">
                <cfreturn local.result>
            </cfif>

            <!--- Check maintenance mode (allow only critical notifications) --->
            <cfif isMaintenanceMode() AND qNotificationType.CRITICAL_NOTIFICATION EQ 0>
                <cfset local.result.reason = "System in maintenance mode - non-critical notifications disabled">
                <cfreturn local.result>
            </cfif>

            <!--- Check if it's within quiet hours for non-critical notifications --->
            <cfif NOT local.result.critical_notification AND isWithinQuietHours(arguments.user_id)>
                <cfset local.result.reason = "Within quiet hours - non-critical notifications paused">
                <cfreturn local.result>
            </cfif>

            <!--- Check daily notification limits for user --->
            <cfif hasExceededDailyLimit(arguments.user_id)>
                <cfset local.result.reason = "User has exceeded daily notification limit">
                <cfreturn local.result>
            </cfif>

            <!--- Check admin-only notifications --->
            <cfif qNotificationType.ADMIN_ONLY EQ 1>
                <cfquery name="qUserRole" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                    SELECT r.ROLE_NAME
                    FROM #this.DBSCHEMA#.USERS u
                    JOIN #this.DBSCHEMA#.ROLES r ON u.ROLE_ID = r.ROLE_ID
                    WHERE u.USER_ID = <cfqueryparam value="#arguments.user_id#" cfsqltype="cf_sql_numeric">
                </cfquery>
                
                <cfif qUserRole.recordCount EQ 0 OR NOT listFindNoCase("Admin,Site Admin", qUserRole.ROLE_NAME)>
                    <cfset local.result.reason = "Admin-only notification for non-admin user">
                    <cfreturn local.result>
                </cfif>
            </cfif>

            <!--- Get user preferences --->
            <cfset local.userPrefs = getUserEffectivePreferences(arguments.user_id, arguments.notification_type)>

            <!--- System override or manual bypass of user preferences --->
            <cfif qNotificationType.OVERRIDE_USER_PREFERENCES EQ 1 OR arguments.bypass_user_preferences>
                <cfset local.result.allow_email = areEmailNotificationsEnabled() AND qNotificationType.DEFAULT_EMAIL_ENABLED EQ 1>
                <cfset local.result.allow_in_app = areInAppNotificationsEnabled() AND qNotificationType.DEFAULT_IN_APP_ENABLED EQ 1>
                <cfset local.result.system_override = true>
                <cfset local.result.reason = "System override of user preferences">
            <cfelse>
                <!--- Use user preferences --->
                <cfset local.result.allow_email = areEmailNotificationsEnabled() AND local.userPrefs.email_enabled>
                <cfset local.result.allow_in_app = areInAppNotificationsEnabled() AND local.userPrefs.in_app_enabled>
                <cfset local.result.reason = "User preferences applied">
            </cfif>

            <!--- Log the decision for analytics --->
            <cfset logNotificationDecision(
                user_id = arguments.user_id,
                notification_type = arguments.notification_type,
                email_allowed = local.result.allow_email,
                in_app_allowed = local.result.allow_in_app,
                reason = local.result.reason
            )>

            <cfreturn local.result>

        <cfcatch>
            <!--- On error, log and default to not sending --->
            <cfset local.result.reason = "Error checking notification permissions: #cfcatch.message#">
            <cfreturn local.result>
        </cfcatch>
        </cftry>
    </cffunction>

    <!--- =======================================
          SYSTEM SETTINGS MANAGEMENT FUNCTIONS
          ======================================= --->

    <!--- Get system setting with caching --->
    <cffunction name="getSystemSetting" access="public" returntype="string" output="false">
        <cfargument name="setting_name" type="string" required="true">
        <cfargument name="default_value" type="string" required="false" default="">
        
        <!--- Check cache validity --->
        <cfif dateDiff("s", variables.lastCacheUpdate, now()) GT variables.cacheTimeout>
            <cfset refreshSystemSettingsCache()>
        </cfif>

        <!--- Return cached value or default --->
        <cfif structKeyExists(variables.systemSettingsCache, arguments.setting_name)>
            <cfreturn variables.systemSettingsCache[arguments.setting_name]>
        <cfelse>
            <cfreturn arguments.default_value>
        </cfif>
    </cffunction>

    <!--- Refresh system settings cache --->
    <cffunction name="refreshSystemSettingsCache" access="public" returntype="void" output="false">
        <cftry>
            <cfquery name="qSettings" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT SETTING_NAME, SETTING_VALUE
                FROM #this.DBSCHEMA#.SYSTEM_NOTIFICATION_SETTINGS
                WHERE IS_ACTIVE = 1
            </cfquery>

            <cfset variables.systemSettingsCache = {}>
            <cfloop query="qSettings">
                <cfset variables.systemSettingsCache[qSettings.SETTING_NAME] = qSettings.SETTING_VALUE>
            </cfloop>
            
            <cfset variables.lastCacheUpdate = now()>
        <cfcatch>
            <!--- If table doesn't exist, use defaults --->
            <cfset variables.systemSettingsCache = {
                "NOTIFICATIONS_ENABLED": "1",
                "EMAIL_NOTIFICATIONS_ENABLED": "1",
                "IN_APP_NOTIFICATIONS_ENABLED": "1",
                "MAINTENANCE_MODE": "0",
                "EMERGENCY_MODE": "0"
            }>
            <cfset variables.lastCacheUpdate = now()>
        </cfcatch>
        </cftry>
    </cffunction>

    <!--- Update system setting --->
    <cffunction name="updateSystemSetting" access="remote" returntype="struct" returnformat="json">
        <cfargument name="setting_name" type="string" required="true">
        <cfargument name="setting_value" type="string" required="true">
        <cfargument name="updated_by" type="numeric" required="true">
        
        <cfset local.result = {"success": false, "message": ""}>
        
        <cftry>
            <!--- Check if setting exists --->
            <cfquery name="qCheckExists" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT COUNT(*) as count
                FROM #this.DBSCHEMA#.SYSTEM_NOTIFICATION_SETTINGS
                WHERE SETTING_NAME = <cfqueryparam value="#arguments.setting_name#" cfsqltype="cf_sql_varchar">
            </cfquery>
            
            <cfif qCheckExists.count GT 0>
                <!--- Update existing setting --->
                <cfquery datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                    UPDATE #this.DBSCHEMA#.SYSTEM_NOTIFICATION_SETTINGS
                    SET 
                        SETTING_VALUE = <cfqueryparam value="#arguments.setting_value#" cfsqltype="cf_sql_varchar">,
                        UPDATED_BY = <cfqueryparam value="#arguments.updated_by#" cfsqltype="cf_sql_numeric">,
                        UPDATED_AT = CURRENT_TIMESTAMP
                    WHERE SETTING_NAME = <cfqueryparam value="#arguments.setting_name#" cfsqltype="cf_sql_varchar">
                </cfquery>
            <cfelse>
                <!--- Insert new setting --->
                <cfquery datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                    INSERT INTO #this.DBSCHEMA#.SYSTEM_NOTIFICATION_SETTINGS (
                        SETTING_NAME, SETTING_VALUE, CREATED_BY, UPDATED_BY
                    ) VALUES (
                        <cfqueryparam value="#arguments.setting_name#" cfsqltype="cf_sql_varchar">,
                        <cfqueryparam value="#arguments.setting_value#" cfsqltype="cf_sql_varchar">,
                        <cfqueryparam value="#arguments.updated_by#" cfsqltype="cf_sql_numeric">,
                        <cfqueryparam value="#arguments.updated_by#" cfsqltype="cf_sql_numeric">
                    )
                </cfquery>
            </cfif>

            <!--- Refresh cache --->
            <cfset refreshSystemSettingsCache()>
            
            <cfset local.result.success = true>
            <cfset local.result.message = "System setting updated successfully">
            
        <cfcatch>
            <cfset local.result.message = "Error updating system setting: #cfcatch.message#">
        </cfcatch>
        </cftry>
        
        <cfreturn local.result>
    </cffunction>

    <!--- Get all system settings --->
    <cffunction name="getAllSystemSettings" access="remote" returntype="struct" returnformat="json">
        <cfargument name="category" type="string" required="false" default="">
        
        <cfset local.result = {"success": false, "data": [], "message": ""}>
        
        <cftry>
            <cfquery name="qSettings" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT 
                    SETTING_ID,
                    SETTING_NAME,
                    SETTING_VALUE,
                    SETTING_TYPE,
                    DESCRIPTION,
                    CATEGORY,
                    IS_ACTIVE,
                    REQUIRES_RESTART,
                    TO_CHAR(CREATED_AT, 'YYYY-MM-DD HH24:MI:SS') as CREATED_AT_STR,
                    TO_CHAR(UPDATED_AT, 'YYYY-MM-DD HH24:MI:SS') as UPDATED_AT_STR
                FROM #this.DBSCHEMA#.SYSTEM_NOTIFICATION_SETTINGS
                WHERE 1=1
                <cfif len(trim(arguments.category))>
                    AND UPPER(CATEGORY) = <cfqueryparam value="#UCase(arguments.category)#" cfsqltype="cf_sql_varchar">
                </cfif>
                ORDER BY CATEGORY, SETTING_NAME
            </cfquery>
            
            <cfset local.result.data = []>
            <cfloop query="qSettings">
                <cfset arrayAppend(local.result.data, {
                    "setting_id": qSettings.SETTING_ID,
                    "setting_name": qSettings.SETTING_NAME,
                    "setting_value": qSettings.SETTING_VALUE,
                    "setting_type": qSettings.SETTING_TYPE,
                    "description": qSettings.DESCRIPTION,
                    "category": qSettings.CATEGORY,
                    "is_active": qSettings.IS_ACTIVE,
                    "requires_restart": qSettings.REQUIRES_RESTART,
                    "created_at": qSettings.CREATED_AT_STR,
                    "updated_at": qSettings.UPDATED_AT_STR
                })>
            </cfloop>
            
            <cfset local.result.success = true>
            <cfset local.result.message = "System settings retrieved successfully">
            
        <cfcatch>
            <cfset local.result.message = "Error retrieving system settings: #cfcatch.message#">
        </cfcatch>
        </cftry>
        
        <cfreturn local.result>
    </cffunction>

    <!--- ========================================
          NOTIFICATION TYPE MANAGEMENT FUNCTIONS
          ======================================== --->

    <!--- Enable/disable notification type globally --->
    <cffunction name="toggleNotificationType" access="remote" returntype="struct" returnformat="json">
        <cfargument name="notification_type" type="string" required="true">
        <cfargument name="enabled" type="boolean" required="true">
        <cfargument name="updated_by" type="numeric" required="true">
        
        <cfset local.result = {"success": false, "message": ""}>
        
        <cftry>
            <cfquery datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                UPDATE #this.DBSCHEMA#.NOTIFICATION_TYPES
                SET ENABLED = <cfqueryparam value="#arguments.enabled#" cfsqltype="cf_sql_bit">
                WHERE TYPE_CODE = <cfqueryparam value="#arguments.notification_type#" cfsqltype="cf_sql_varchar">
            </cfquery>
            
            <!--- Log the change --->
            <cfset logSystemChange(
                action = "TOGGLE_NOTIFICATION_TYPE",
                details = "Set #arguments.notification_type# to #arguments.enabled#",
                user_id = arguments.updated_by
            )>
            
            <cfset local.result.success = true>
            <cfset local.result.message = "Notification type #arguments.enabled ? 'enabled' : 'disabled'# successfully">
            
        <cfcatch>
            <cfset local.result.message = "Error updating notification type: #cfcatch.message#">
        </cfcatch>
        </cftry>
        
        <cfreturn local.result>
    </cffunction>

    <!--- Get all notification types with system status --->
    <cffunction name="getAllNotificationTypesWithStatus" access="remote" returntype="struct" returnformat="json">
        <cfset local.result = {"success": false, "data": [], "message": ""}>
        
        <cftry>
            <cfquery name="qTypes" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT 
                    TYPE_CODE,
                    DISPLAY_NAME,
                    DESCRIPTION,
                    CATEGORY,
                    ENABLED,
                    CRITICAL_NOTIFICATION,
                    OVERRIDE_USER_PREFERENCES,
                    EMERGENCY_OVERRIDE,
                    DEFAULT_EMAIL_ENABLED,
                    DEFAULT_IN_APP_ENABLED,
                    ADMIN_ONLY,
                    TO_CHAR(CREATED_AT, 'YYYY-MM-DD HH24:MI:SS') as CREATED_AT_STR,
                    TO_CHAR(UPDATED_AT, 'YYYY-MM-DD HH24:MI:SS') as UPDATED_AT_STR
                FROM #this.DBSCHEMA#.NOTIFICATION_TYPES
                ORDER BY CATEGORY, DISPLAY_NAME
            </cfquery>
            
            <cfset local.result.data = []>
            <cfloop query="qTypes">
                <cfset arrayAppend(local.result.data, {
                    "type_code": qTypes.TYPE_CODE,
                    "display_name": qTypes.DISPLAY_NAME,
                    "description": qTypes.DESCRIPTION,
                    "category": qTypes.CATEGORY,
                    "enabled": qTypes.ENABLED,
                    "critical_notification": qTypes.CRITICAL_NOTIFICATION,
                    "override_user_preferences": qTypes.OVERRIDE_USER_PREFERENCES,
                    "emergency_override": qTypes.EMERGENCY_OVERRIDE,
                    "default_email_enabled": qTypes.DEFAULT_EMAIL_ENABLED,
                    "default_in_app_enabled": qTypes.DEFAULT_IN_APP_ENABLED,
                    "admin_only": qTypes.ADMIN_ONLY,
                    "created_at": qTypes.CREATED_AT_STR,
                    "updated_at": qTypes.UPDATED_AT_STR
                })>
            </cfloop>
            
            <cfset local.result.success = true>
            <cfset local.result.message = "Notification types retrieved successfully">
            
        <cfcatch>
            <cfset local.result.message = "Error retrieving notification types: #cfcatch.message#">
        </cfcatch>
        </cftry>
        
        <cfreturn local.result>
    </cffunction>

    <!--- ===================================
          USER PREFERENCE HELPER FUNCTIONS
          =================================== --->

    <!--- Get effective user preferences considering system overrides --->
    <cffunction name="getUserEffectivePreferences" access="public" returntype="struct" output="false">
        <cfargument name="user_id" type="numeric" required="true">
        <cfargument name="notification_type" type="string" required="true">
        
        <cfset local.result = {"email_enabled": true, "in_app_enabled": true}>
        
        <cftry>
            <cfquery name="qPrefs" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT 
                    COALESCE(np.EMAIL_ENABLED, nt.DEFAULT_EMAIL_ENABLED) AS EMAIL_ENABLED,
                    COALESCE(np.IN_APP_ENABLED, nt.DEFAULT_IN_APP_ENABLED) AS IN_APP_ENABLED
                FROM #this.DBSCHEMA#.NOTIFICATION_TYPES nt
                LEFT JOIN #this.DBSCHEMA#.NOTIFICATION_PREFERENCES np ON nt.TYPE_CODE = np.NOTIFICATION_TYPE
                    AND np.USER_ID = <cfqueryparam value="#arguments.user_id#" cfsqltype="cf_sql_numeric">
                WHERE nt.TYPE_CODE = <cfqueryparam value="#arguments.notification_type#" cfsqltype="cf_sql_varchar">
            </cfquery>
            
            <cfif qPrefs.recordCount GT 0>
                <cfset local.result.email_enabled = qPrefs.EMAIL_ENABLED EQ 1>
                <cfset local.result.in_app_enabled = qPrefs.IN_APP_ENABLED EQ 1>
            </cfif>
            
        <cfcatch>
            <!--- Default to enabled on error --->
            <cfset local.result = {"email_enabled": true, "in_app_enabled": true}>
        </cfcatch>
        </cftry>
        
        <cfreturn local.result>
    </cffunction>

    <!--- Check if current time is within user's quiet hours --->
    <cffunction name="isWithinQuietHours" access="public" returntype="boolean" output="false">
        <cfargument name="user_id" type="numeric" required="true">
        
        <cftry>
            <!--- Get system-wide quiet hours settings --->
            <cfset local.quietStart = getSystemSetting("QUIET_HOURS_START", "22:00")>
            <cfset local.quietEnd = getSystemSetting("QUIET_HOURS_END", "08:00")>
            
            <!--- Check for user-specific quiet hours override --->
            <cfquery name="qUserQuietHours" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT SETTING_VALUE
                FROM #this.DBSCHEMA#.USER_NOTIFICATION_SETTINGS
                WHERE USER_ID = <cfqueryparam value="#arguments.user_id#" cfsqltype="cf_sql_numeric">
                AND SETTING_NAME IN ('QUIET_HOURS_START', 'QUIET_HOURS_END')
                ORDER BY SETTING_NAME
            </cfquery>
            
            <!--- Use user-specific settings if available --->
            <cfif qUserQuietHours.recordCount EQ 2>
                <cfset local.quietEnd = qUserQuietHours.SETTING_VALUE[1]>   <!--- QUIET_HOURS_END --->
                <cfset local.quietStart = qUserQuietHours.SETTING_VALUE[2]> <!--- QUIET_HOURS_START --->
            </cfif>
            
            <cfset local.currentTime = timeFormat(now(), "HH:mm")>
            <cfset local.startTime = local.quietStart>
            <cfset local.endTime = local.quietEnd>
            
            <!--- Handle overnight quiet hours (e.g., 22:00 to 08:00) --->
            <cfif timeCompare(local.startTime, local.endTime) GT 0>
                <cfreturn (timeCompare(local.currentTime, local.startTime) GTE 0 OR timeCompare(local.currentTime, local.endTime) LTE 0)>
            <cfelse>
                <cfreturn (timeCompare(local.currentTime, local.startTime) GTE 0 AND timeCompare(local.currentTime, local.endTime) LTE 0)>
            </cfif>
            
        <cfcatch>
            <!--- Default to not within quiet hours on error --->
            <cfreturn false>
        </cfcatch>
        </cftry>
    </cffunction>

    <!--- Check if user has exceeded daily notification limit --->
    <cffunction name="hasExceededDailyLimit" access="public" returntype="boolean" output="false">
        <cfargument name="user_id" type="numeric" required="true">
        
        <cftry>
            <cfset local.maxDaily = getSystemSetting("MAX_DAILY_NOTIFICATIONS_PER_USER", "50")>
            
            <cfquery name="qDailyCount" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT COUNT(*) as daily_count
                FROM #this.DBSCHEMA#.NOTIFICATIONS
                WHERE USER_ID = <cfqueryparam value="#arguments.user_id#" cfsqltype="cf_sql_numeric">
                AND CREATED_AT >= TRUNC(SYSDATE)
                AND CREATED_AT < TRUNC(SYSDATE) + 1
            </cfquery>
            
            <cfreturn qDailyCount.daily_count GTE val(local.maxDaily)>
            
        <cfcatch>
            <!--- Default to not exceeded on error --->
            <cfreturn false>
        </cfcatch>
        </cftry>
    </cffunction>

    <!--- ============================
          ANALYTICS AND LOGGING FUNCTIONS
          ============================ --->

    <!--- Log notification decision for analytics --->
    <cffunction name="logNotificationDecision" access="private" returntype="void" output="false">
        <cfargument name="user_id" type="numeric" required="true">
        <cfargument name="notification_type" type="string" required="true">
        <cfargument name="email_allowed" type="boolean" required="true">
        <cfargument name="in_app_allowed" type="boolean" required="true">
        <cfargument name="reason" type="string" required="true">
        
        <!--- This could be expanded to log to a decision audit table --->
        <!--- For now, we'll just track basic analytics --->
        <cftry>
            <cfset updateNotificationAnalytics(
                notification_type = arguments.notification_type,
                delivery_method = "DECISION",
                increment_sent = 0,
                increment_delivered = (arguments.email_allowed OR arguments.in_app_allowed) ? 1 : 0,
                increment_failed = (arguments.email_allowed OR arguments.in_app_allowed) ? 0 : 1
            )>
        <cfcatch>
            <!--- Silently fail analytics logging --->
        </cfcatch>
        </cftry>
    </cffunction>

    <!--- Log system changes for audit trail --->
    <cffunction name="logSystemChange" access="private" returntype="void" output="false">
        <cfargument name="action" type="string" required="true">
        <cfargument name="details" type="string" required="true">  
        <cfargument name="user_id" type="numeric" required="true">
        
        <!--- This would typically log to an audit table --->
        <!--- Implementation depends on existing audit system --->
    </cffunction>

    <!--- Update notification analytics --->
    <cffunction name="updateNotificationAnalytics" access="public" returntype="void" output="false">
        <cfargument name="notification_type" type="string" required="true">
        <cfargument name="delivery_method" type="string" required="true">
        <cfargument name="increment_sent" type="numeric" required="false" default="0">
        <cfargument name="increment_delivered" type="numeric" required="false" default="0">
        <cfargument name="increment_failed" type="numeric" required="false" default="0">
        <cfargument name="increment_opened" type="numeric" required="false" default="0">
        
        <cftry>
            <!--- Upsert analytics record for today --->
            <cfquery datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                MERGE INTO #this.DBSCHEMA#.NOTIFICATION_ANALYTICS na
                USING (
                    SELECT 
                        <cfqueryparam value="#arguments.notification_type#" cfsqltype="cf_sql_varchar"> AS NOTIFICATION_TYPE,
                        <cfqueryparam value="#arguments.delivery_method#" cfsqltype="cf_sql_varchar"> AS DELIVERY_METHOD,
                        TRUNC(SYSDATE) AS ANALYTICS_DATE
                    FROM DUAL
                ) src ON (
                    na.NOTIFICATION_TYPE = src.NOTIFICATION_TYPE
                    AND na.DELIVERY_METHOD = src.DELIVERY_METHOD
                    AND na.ANALYTICS_DATE = src.ANALYTICS_DATE
                )
                WHEN MATCHED THEN
                    UPDATE SET
                        TOTAL_SENT = TOTAL_SENT + <cfqueryparam value="#arguments.increment_sent#" cfsqltype="cf_sql_numeric">,
                        TOTAL_DELIVERED = TOTAL_DELIVERED + <cfqueryparam value="#arguments.increment_delivered#" cfsqltype="cf_sql_numeric">,
                        TOTAL_FAILED = TOTAL_FAILED + <cfqueryparam value="#arguments.increment_failed#" cfsqltype="cf_sql_numeric">,
                        TOTAL_OPENED = TOTAL_OPENED + <cfqueryparam value="#arguments.increment_opened#" cfsqltype="cf_sql_numeric">,
                        UPDATED_AT = CURRENT_TIMESTAMP
                WHEN NOT MATCHED THEN
                    INSERT (
                        NOTIFICATION_TYPE,
                        DELIVERY_METHOD,
                        TOTAL_SENT,
                        TOTAL_DELIVERED,
                        TOTAL_FAILED,
                        TOTAL_OPENED,
                        ANALYTICS_DATE
                    ) VALUES (
                        src.NOTIFICATION_TYPE,
                        src.DELIVERY_METHOD,
                        <cfqueryparam value="#arguments.increment_sent#" cfsqltype="cf_sql_numeric">,
                        <cfqueryparam value="#arguments.increment_delivered#" cfsqltype="cf_sql_numeric">,
                        <cfqueryparam value="#arguments.increment_failed#" cfsqltype="cf_sql_numeric">,
                        <cfqueryparam value="#arguments.increment_opened#" cfsqltype="cf_sql_numeric">,
                        src.ANALYTICS_DATE
                    )
            </cfquery>
        <cfcatch>
            <!--- Silently fail analytics updates --->
        </cfcatch>
        </cftry>
    </cffunction>

    <!--- Get notification analytics data --->
    <cffunction name="getNotificationAnalytics" access="remote" returntype="query" returnformat="json">
        <cfargument name="start_date" type="string" required="false" default="">
        <cfargument name="end_date" type="string" required="false" default="">
        <cfargument name="notification_type" type="string" required="false" default="">
        
        <cftry>
            <cfif NOT len(trim(arguments.start_date))>
                <cfset arguments.start_date = dateFormat(dateAdd("d", -30, now()), "yyyy-mm-dd")>
            </cfif>
            <cfif NOT len(trim(arguments.end_date))>
                <cfset arguments.end_date = dateFormat(now(), "yyyy-mm-dd")>
            </cfif>
            
            <cfquery name="qAnalytics" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT 
                    na.NOTIFICATION_TYPE,
                    na.DELIVERY_METHOD,
                    na.ANALYTICS_DATE,
                    na.TOTAL_SENT,
                    na.TOTAL_DELIVERED,
                    na.TOTAL_FAILED,
                    na.TOTAL_OPENED,
                    nt.DISPLAY_NAME,
                    nt.CATEGORY
                FROM #this.DBSCHEMA#.NOTIFICATION_ANALYTICS na
                INNER JOIN #this.DBSCHEMA#.NOTIFICATION_TYPES nt ON na.NOTIFICATION_TYPE = nt.TYPE_CODE
                WHERE na.ANALYTICS_DATE >= TO_DATE(<cfqueryparam value="#arguments.start_date#" cfsqltype="cf_sql_varchar">, 'YYYY-MM-DD')
                AND na.ANALYTICS_DATE <= TO_DATE(<cfqueryparam value="#arguments.end_date#" cfsqltype="cf_sql_varchar">, 'YYYY-MM-DD')
                <cfif len(trim(arguments.notification_type))>
                    AND na.NOTIFICATION_TYPE = <cfqueryparam value="#arguments.notification_type#" cfsqltype="cf_sql_varchar">
                </cfif>
                ORDER BY na.ANALYTICS_DATE DESC, na.NOTIFICATION_TYPE, na.DELIVERY_METHOD
            </cfquery>
            
            <cfreturn qAnalytics>
            
        <cfcatch>
            <!--- Return empty query if table doesn't exist --->
            <cfset local.emptyAnalytics = queryNew("NOTIFICATION_TYPE,DELIVERY_METHOD,ANALYTICS_DATE,TOTAL_SENT,TOTAL_DELIVERED,TOTAL_FAILED,TOTAL_OPENED,DISPLAY_NAME,CATEGORY", "varchar,varchar,date,numeric,numeric,numeric,numeric,varchar,varchar")>
            <cfreturn local.emptyAnalytics>
        </cfcatch>
        </cftry>
    </cffunction>

    <!--- =================================
          SCHEDULED NOTIFICATION FUNCTIONS
          ================================= --->

    <!--- Create scheduled notification toggle --->
    <cffunction name="createNotificationSchedule" access="remote" returntype="struct" returnformat="json">
        <cfargument name="notification_type" type="string" required="true">
        <cfargument name="action" type="string" required="true">
        <cfargument name="start_time" type="string" required="true">
        <cfargument name="end_time" type="string" required="false" default="">
        <cfargument name="recurrence_pattern" type="string" required="false" default="">
        <cfargument name="created_by" type="numeric" required="true">
        
        <cfset local.result = {"success": false, "message": ""}>
        
        <cftry>
            <cfquery datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                INSERT INTO #this.DBSCHEMA#.NOTIFICATION_SCHEDULES (
                    NOTIFICATION_TYPE,
                    ACTION,
                    START_TIME,
                    END_TIME,
                    RECURRENCE_PATTERN,
                    CREATED_BY
                ) VALUES (
                    <cfqueryparam value="#arguments.notification_type#" cfsqltype="cf_sql_varchar">,
                    <cfqueryparam value="#arguments.action#" cfsqltype="cf_sql_varchar">,
                    TO_TIMESTAMP(<cfqueryparam value="#arguments.start_time#" cfsqltype="cf_sql_varchar">, 'YYYY-MM-DD HH24:MI:SS'),
                    <cfif len(trim(arguments.end_time))>
                        TO_TIMESTAMP(<cfqueryparam value="#arguments.end_time#" cfsqltype="cf_sql_varchar">, 'YYYY-MM-DD HH24:MI:SS')
                    <cfelse>
                        NULL
                    </cfif>,
                    <cfif len(trim(arguments.recurrence_pattern))>
                        <cfqueryparam value="#arguments.recurrence_pattern#" cfsqltype="cf_sql_varchar">
                    <cfelse>
                        NULL
                    </cfif>,
                    <cfqueryparam value="#arguments.created_by#" cfsqltype="cf_sql_numeric">
                )
            </cfquery>
            
            <cfset local.result.success = true>
            <cfset local.result.message = "Notification schedule created successfully">
            
        <cfcatch>
            <cfset local.result.message = "Error creating notification schedule: #cfcatch.message#">
        </cfcatch>
        </cftry>
        
        <cfreturn local.result>
    </cffunction>

    <!--- Process scheduled notification changes (called by scheduled task) --->
    <cffunction name="processScheduledNotifications" access="public" returntype="struct" output="false">
        <cfset local.result = {"processed": 0, "errors": 0}>
        
        <cftry>
            <!--- Get active schedules that should be processed now --->
            <cfquery name="qSchedules" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT 
                    SCHEDULE_ID,
                    NOTIFICATION_TYPE,
                    ACTION
                FROM #this.DBSCHEMA#.NOTIFICATION_SCHEDULES
                WHERE IS_ACTIVE = 1
                AND START_TIME <= CURRENT_TIMESTAMP
                AND (END_TIME IS NULL OR END_TIME >= CURRENT_TIMESTAMP)
            </cfquery>
            
            <cfloop query="qSchedules">
                <cftry>
                    <cfswitch expression="#qSchedules.ACTION#">
                        <cfcase value="ENABLE">
                            <cfquery datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                                UPDATE #this.DBSCHEMA#.NOTIFICATION_TYPES
                                SET ENABLED = 1
                                WHERE TYPE_CODE = <cfqueryparam value="#qSchedules.NOTIFICATION_TYPE#" cfsqltype="cf_sql_varchar">
                            </cfquery>
                        </cfcase>
                        <cfcase value="DISABLE">
                            <cfquery datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                                UPDATE #this.DBSCHEMA#.NOTIFICATION_TYPES
                                SET ENABLED = 0
                                WHERE TYPE_CODE = <cfqueryparam value="#qSchedules.NOTIFICATION_TYPE#" cfsqltype="cf_sql_varchar">
                            </cfquery>
                        </cfcase>
                        <cfcase value="PAUSE">
                            <!--- Custom logic for pausing notifications temporarily --->
                        </cfcase>
                    </cfswitch>
                    
                    <cfset local.result.processed++>
                    
                <cfcatch>
                    <cfset local.result.errors++>
                </cfcatch>
                </cftry>
            </cfloop>
            
        <cfcatch>
            <cfset local.result.errors++>
        </cfcatch>
        </cftry>
        
        <cfreturn local.result>
    </cffunction>

    <!--- ============================
          API ENDPOINTS FOR AJAX CALLS
          ============================ --->

    <!--- Get user notification settings --->
    <cffunction name="getUserNotificationSettings" access="remote" returntype="query" returnformat="json">
        <cfargument name="user_id" type="numeric" required="true">
        
        <cftry>
            <cfquery name="qUserSettings" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT 
                    SETTING_NAME,
                    SETTING_VALUE,
                    SETTING_TYPE,
                    CREATED_AT,
                    UPDATED_AT
                FROM #this.DBSCHEMA#.USER_NOTIFICATION_SETTINGS
                WHERE USER_ID = <cfqueryparam value="#arguments.user_id#" cfsqltype="cf_sql_numeric">
                ORDER BY SETTING_NAME
            </cfquery>
            
            <cfreturn qUserSettings>
            
        <cfcatch>
            <!--- Return empty query if table doesn't exist --->
            <cfset local.emptySettings = queryNew("SETTING_NAME,SETTING_VALUE,SETTING_TYPE,CREATED_AT,UPDATED_AT", "varchar,varchar,varchar,timestamp,timestamp")>
            <cfreturn local.emptySettings>
        </cfcatch>
        </cftry>
    </cffunction>

    <!--- Update user notification setting --->
    <cffunction name="updateUserNotificationSetting" access="remote" returntype="struct" returnformat="json">
        <cfargument name="user_id" type="numeric" required="true">
        <cfargument name="setting_name" type="string" required="true">
        <cfargument name="setting_value" type="string" required="true">
        <cfargument name="setting_type" type="string" required="false" default="STRING">
        
        <cfset local.result = {"success": false, "message": ""}>
        
        <cftry>
            <!--- Check if setting exists --->
            <cfquery name="qCheckExists" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT COUNT(*) as count
                FROM #this.DBSCHEMA#.USER_NOTIFICATION_SETTINGS
                WHERE USER_ID = <cfqueryparam value="#arguments.user_id#" cfsqltype="cf_sql_numeric">
                AND SETTING_NAME = <cfqueryparam value="#arguments.setting_name#" cfsqltype="cf_sql_varchar">
            </cfquery>
            
            <cfif qCheckExists.count GT 0>
                <!--- Update existing setting --->
                <cfquery datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                    UPDATE #this.DBSCHEMA#.USER_NOTIFICATION_SETTINGS
                    SET 
                        SETTING_VALUE = <cfqueryparam value="#arguments.setting_value#" cfsqltype="cf_sql_varchar">,
                        SETTING_TYPE = <cfqueryparam value="#arguments.setting_type#" cfsqltype="cf_sql_varchar">,
                        UPDATED_AT = CURRENT_TIMESTAMP
                    WHERE USER_ID = <cfqueryparam value="#arguments.user_id#" cfsqltype="cf_sql_numeric">
                    AND SETTING_NAME = <cfqueryparam value="#arguments.setting_name#" cfsqltype="cf_sql_varchar">
                </cfquery>
            <cfelse>
                <!--- Insert new setting --->
                <cfquery datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                    INSERT INTO #this.DBSCHEMA#.USER_NOTIFICATION_SETTINGS (
                        USER_ID, SETTING_NAME, SETTING_VALUE, SETTING_TYPE
                    ) VALUES (
                        <cfqueryparam value="#arguments.user_id#" cfsqltype="cf_sql_numeric">,
                        <cfqueryparam value="#arguments.setting_name#" cfsqltype="cf_sql_varchar">,
                        <cfqueryparam value="#arguments.setting_value#" cfsqltype="cf_sql_varchar">,
                        <cfqueryparam value="#arguments.setting_type#" cfsqltype="cf_sql_varchar">
                    )
                </cfquery>
            </cfif>
            
            <cfset local.result.success = true>
            <cfset local.result.message = "User notification setting updated successfully">
            
        <cfcatch>
            <cfset local.result.message = "Error updating user notification setting: #cfcatch.message#">
        </cfcatch>
        </cftry>
        
        <cfreturn local.result>
    </cffunction>

    <!--- Get notification delivery status for a specific notification --->
    <cffunction name="getNotificationDeliveryStatus" access="remote" returntype="struct" returnformat="json">
        <cfargument name="user_id" type="numeric" required="true">
        <cfargument name="notification_type" type="string" required="true">
        
        <cfset local.result = shouldSendNotification(
            user_id = arguments.user_id,
            notification_type = arguments.notification_type
        )>
        
        <!--- Add additional context information --->
        <cfset local.result.system_status = {
            "notifications_enabled": areNotificationsEnabled(),
            "email_enabled": areEmailNotificationsEnabled(),
            "in_app_enabled": areInAppNotificationsEnabled(),
            "maintenance_mode": isMaintenanceMode(),
            "emergency_mode": isEmergencyMode()
        }>
        
        <cfreturn local.result>
    </cffunction>

    <!--- Bulk update notification types --->
    <cffunction name="bulkUpdateNotificationTypes" access="remote" returntype="struct" returnformat="json">
        <cfargument name="type_codes" type="string" required="true">
        <cfargument name="action" type="string" required="true">
        <cfargument name="updated_by" type="numeric" required="true">
        
        <cfset local.result = {"success": false, "message": "", "updated_count": 0, "failed_count": 0}>
        
        <cftry>
            <cfset local.typeList = listToArray(arguments.type_codes)>
            <cfset local.updatedCount = 0>
            <cfset local.failedCount = 0>
            
            <cfloop array="#local.typeList#" index="typeCode">
                <cftry>
                    <cfswitch expression="#arguments.action#">
                        <cfcase value="enable">
                            <cfquery datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                                UPDATE #this.DBSCHEMA#.NOTIFICATION_TYPES
                                SET ENABLED = 1
                                WHERE TYPE_CODE = <cfqueryparam value="#trim(typeCode)#" cfsqltype="cf_sql_varchar">
                            </cfquery>
                        </cfcase>
                        <cfcase value="disable">
                            <cfquery datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                                UPDATE #this.DBSCHEMA#.NOTIFICATION_TYPES
                                SET ENABLED = 0
                                WHERE TYPE_CODE = <cfqueryparam value="#trim(typeCode)#" cfsqltype="cf_sql_varchar">
                            </cfquery>
                        </cfcase>
                        <cfcase value="enable_override">
                            <cfquery datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                                UPDATE #this.DBSCHEMA#.NOTIFICATION_TYPES
                                SET OVERRIDE_USER_PREFERENCES = 1
                                WHERE TYPE_CODE = <cfqueryparam value="#trim(typeCode)#" cfsqltype="cf_sql_varchar">
                            </cfquery>
                        </cfcase>
                        <cfcase value="disable_override">
                            <cfquery datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                                UPDATE #this.DBSCHEMA#.NOTIFICATION_TYPES
                                SET OVERRIDE_USER_PREFERENCES = 0
                                WHERE TYPE_CODE = <cfqueryparam value="#trim(typeCode)#" cfsqltype="cf_sql_varchar">
                            </cfquery>
                        </cfcase>
                    </cfswitch>
                    
                    <cfset local.updatedCount++>
                    
                <cfcatch>
                    <cfset local.failedCount++>
                </cfcatch>
                </cftry>
            </cfloop>
            
            <cfset local.result.success = local.updatedCount GT 0>
            <cfset local.result.updated_count = local.updatedCount>
            <cfset local.result.failed_count = local.failedCount>
            <cfset local.result.message = "Updated #local.updatedCount# notification types, #local.failedCount# failed">
            
            <!--- Log the bulk change --->
            <cfset logSystemChange(
                action = "BULK_UPDATE_NOTIFICATION_TYPES",
                details = "Action: #arguments.action#, Updated: #local.updatedCount#, Failed: #local.failedCount#",
                user_id = arguments.updated_by
            )>
            
        <cfcatch>
            <cfset local.result.message = "Error performing bulk update: #cfcatch.message#">
        </cfcatch>
        </cftry>
        
        <cfreturn local.result>
    </cffunction>

    <!--- Get notification queue status and metrics --->
    <cffunction name="getNotificationQueueStatus" access="remote" returntype="struct" returnformat="json">
        <cfset local.result = {
            "queue_size": 0,
            "processing_rate": 0,
            "recent_failures": 0,
            "system_health": "unknown"
        }>
        
        <cftry>
            <!--- Get recent notification count (last hour) --->
            <cfquery name="qRecentNotifications" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT COUNT(*) as recent_count
                FROM #this.DBSCHEMA#.NOTIFICATIONS
                WHERE CREATED_AT >= SYSDATE - INTERVAL '1' HOUR
            </cfquery>
            
            <!--- Get recent analytics for failure rate --->
            <cfquery name="qRecentAnalytics" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT 
                    SUM(TOTAL_SENT) as total_sent,
                    SUM(TOTAL_FAILED) as total_failed
                FROM #this.DBSCHEMA#.NOTIFICATION_ANALYTICS
                WHERE ANALYTICS_DATE >= TRUNC(SYSDATE) - 1
            </cfquery>
            
            <cfset local.result.queue_size = qRecentNotifications.recent_count>
            <cfset local.result.processing_rate = qRecentNotifications.recent_count>
            
            <cfif qRecentAnalytics.recordCount GT 0 AND qRecentAnalytics.total_sent GT 0>
                <cfset local.failureRate = (qRecentAnalytics.total_failed / qRecentAnalytics.total_sent) * 100>
                <cfset local.result.recent_failures = local.failureRate>
                
                <cfif local.failureRate LT 5>
                    <cfset local.result.system_health = "excellent">
                <cfelseif local.failureRate LT 15>
                    <cfset local.result.system_health = "good">
                <cfelseif local.failureRate LT 30>
                    <cfset local.result.system_health = "warning">
                <cfelse>
                    <cfset local.result.system_health = "critical">
                </cfif>
            <cfelse>
                <cfset local.result.system_health = "good">
            </cfif>
            
        <cfcatch>
            <cfset local.result.system_health = "error">
        </cfcatch>
        </cftry>
        
        <cfreturn local.result>
    </cffunction>

    <!--- Test notification delivery --->
    <cffunction name="testNotificationDelivery" access="remote" returntype="struct" returnformat="json">
        <cfargument name="user_id" type="numeric" required="true">
        <cfargument name="delivery_method" type="string" required="true">
        <cfargument name="notification_type" type="string" required="false" default="TEST_NOTIFICATION">
        
        <cfset local.result = {"success": false, "message": ""}>
        
        <cftry>
            <!--- Check if test notifications should be sent --->
            <cfset local.notificationDecision = shouldSendNotification(
                user_id = arguments.user_id,
                notification_type = arguments.notification_type
            )>
            
            <cfif arguments.delivery_method EQ "email" AND local.notificationDecision.allow_email>
                <!--- Get user email --->
                <cfquery name="qUser" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                    SELECT EMAIL, FIRST_NAME, LAST_NAME
                    FROM #this.DBSCHEMA#.USERS
                    WHERE USER_ID = <cfqueryparam value="#arguments.user_id#" cfsqltype="cf_sql_numeric">
                </cfquery>
                
                <cfif qUser.recordCount GT 0>
                    <cfmail 
                        to="#qUser.EMAIL#"
                        from="noreply@mdanderson.org"
                        subject="Test Notification - DoCM Room Reservation System"
                        type="html">
                        <cfoutput>
                        <h2>Test Email Notification</h2>
                        <p>Dear #qUser.FIRST_NAME# #qUser.LAST_NAME#,</p>
                        <p>This is a test email notification from the DoCM Room Reservation System.</p>
                        <p>If you received this email, your email notification preferences are working correctly.</p>
                        <p><strong>Test Details:</strong></p>
                        <ul>
                            <li>Test Time: #DateTimeFormat(now(), "mmm d, yyyy h:nn:ss tt")#</li>
                            <li>User ID: #arguments.user_id#</li>
                            <li>Notification Type: #arguments.notification_type#</li>
                        </ul>
                        <p>Thank you for using the DoCM Room Reservation System.</p>
                        </cfoutput>
                    </cfmail>
                    
                    <cfset local.result.success = true>
                    <cfset local.result.message = "Test email sent successfully">
                    
                    <!--- Update analytics --->
                    <cfset updateNotificationAnalytics(
                        notification_type = arguments.notification_type,
                        delivery_method = "EMAIL",
                        increment_sent = 1,
                        increment_delivered = 1
                    )>
                <cfelse>
                    <cfset local.result.message = "User not found">
                </cfif>
                
            <cfelseif arguments.delivery_method EQ "in_app" AND local.notificationDecision.allow_in_app>
                <!--- Create test in-app notification --->
                <cfquery datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                    INSERT INTO #this.DBSCHEMA#.NOTIFICATIONS (
                        USER_ID,
                        TYPE,
                        CONTENT,
                        STATUS,
                        CREATED_AT
                    ) VALUES (
                        <cfqueryparam value="#arguments.user_id#" cfsqltype="cf_sql_numeric">,
                        <cfqueryparam value="#arguments.notification_type#" cfsqltype="cf_sql_varchar">,
                        'This is a test in-app notification. If you can see this, your in-app notification preferences are working correctly.',
                        'UNREAD',
                        CURRENT_TIMESTAMP
                    )
                </cfquery>
                
                <cfset local.result.success = true>
                <cfset local.result.message = "Test in-app notification created successfully">
                
                <!--- Update analytics --->
                <cfset updateNotificationAnalytics(
                    notification_type = arguments.notification_type,
                    delivery_method = "IN_APP",
                    increment_sent = 1,
                    increment_delivered = 1
                )>
                
            <cfelse>
                <cfset local.result.message = "Test notifications are not allowed for this user/method combination. Reason: #local.notificationDecision.reason#">
            </cfif>
            
        <cfcatch>
            <cfset local.result.message = "Error sending test notification: #cfcatch.message#">
            
            <!--- Update failed analytics --->
            <cfset updateNotificationAnalytics(
                notification_type = arguments.notification_type,
                delivery_method = UCase(arguments.delivery_method),
                increment_sent = 1,
                increment_failed = 1
            )>
        </cfcatch>
        </cftry>
        
        <cfreturn local.result>
    </cffunction>

    <!--- Get scheduled notifications --->
    <cffunction name="getScheduledNotifications" access="remote" returntype="query" returnformat="json">
        <cfargument name="active_only" type="boolean" required="false" default="true">
        
        <cftry>
            <cfquery name="qScheduled" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT 
                    ns.SCHEDULE_ID,
                    ns.NOTIFICATION_TYPE,
                    ns.ACTION,
                    ns.START_TIME,
                    ns.END_TIME,
                    ns.RECURRENCE_PATTERN,
                    ns.IS_ACTIVE,
                    ns.CREATED_AT,
                    nt.DISPLAY_NAME,
                    u.FIRST_NAME || ' ' || u.LAST_NAME as CREATED_BY_NAME
                FROM #this.DBSCHEMA#.NOTIFICATION_SCHEDULES ns
                INNER JOIN #this.DBSCHEMA#.NOTIFICATION_TYPES nt ON ns.NOTIFICATION_TYPE = nt.TYPE_CODE
                LEFT JOIN #this.DBSCHEMA#.USERS u ON ns.CREATED_BY = u.USER_ID
                WHERE 1=1
                <cfif arguments.active_only>
                    AND ns.IS_ACTIVE = 1
                </cfif>
                ORDER BY ns.START_TIME ASC
            </cfquery>
            
            <cfreturn qScheduled>
            
        <cfcatch>
            <!--- Return empty query if table doesn't exist --->
            <cfset local.emptyScheduled = queryNew("SCHEDULE_ID,NOTIFICATION_TYPE,ACTION,START_TIME,END_TIME,RECURRENCE_PATTERN,IS_ACTIVE,CREATED_AT,DISPLAY_NAME,CREATED_BY_NAME", "numeric,varchar,varchar,timestamp,timestamp,varchar,bit,timestamp,varchar,varchar")>
            <cfreturn local.emptyScheduled>
        </cfcatch>
        </cftry>
    </cffunction>

    <!--- Cancel scheduled notification --->
    <cffunction name="cancelScheduledNotification" access="remote" returntype="struct" returnformat="json">
        <cfargument name="schedule_id" type="numeric" required="true">
        <cfargument name="updated_by" type="numeric" required="true">
        
        <cfset local.result = {"success": false, "message": ""}>
        
        <cftry>
            <cfquery datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                UPDATE #this.DBSCHEMA#.NOTIFICATION_SCHEDULES
                SET 
                    IS_ACTIVE = 0,
                    UPDATED_BY = <cfqueryparam value="#arguments.updated_by#" cfsqltype="cf_sql_numeric">,
                    UPDATED_AT = CURRENT_TIMESTAMP
                WHERE SCHEDULE_ID = <cfqueryparam value="#arguments.schedule_id#" cfsqltype="cf_sql_numeric">
            </cfquery>
            
            <cfset local.result.success = true>
            <cfset local.result.message = "Scheduled notification cancelled successfully">
            
        <cfcatch>
            <cfset local.result.message = "Error cancelling scheduled notification: #cfcatch.message#">
        </cfcatch>
        </cftry>
        
        <cfreturn local.result>
    </cffunction>

</cfcomponent>