<cfcomponent>
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

    <!--- Get all notifications for a user --->
    <cffunction name="get_user_notifications" access="remote" returntype="query" returnformat="json">
        <cfargument name="user_id" type="string" required="true">
        
        <cfquery name="qGetNotifications" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
            SELECT 
                NOTIFICATION_ID,
                USER_ID,
                TYPE,
                CONTENT,
                STATUS
            FROM #this.DBSCHEMA#.NOTIFICATIONS
            WHERE USER_ID = <cfqueryparam value="#arguments.user_id#" cfsqltype="cf_sql_varchar">
            ORDER BY CREATED_AT DESC
        </cfquery>
        
        <cfreturn qGetNotifications>
    </cffunction>

    <!--- Create a new notification --->
    <cffunction name="create_notification" access="remote" returntype="boolean" returnformat="json">
        <cfargument name="user_id" type="string" required="true">
        <cfargument name="notification_type" type="string" required="true">
        <cfargument name="notification_message" type="string" required="true">
        
        <cftry>
            <cfquery datasource="#this.DBSERVER#">
                INSERT INTO notifications (
                    user_id,
                    notification_type,
                    notification_message,
                    is_read,
                    created_date,
                    modified_date
                ) VALUES (
                    <cfqueryparam value="#arguments.user_id#" cfsqltype="cf_sql_numeric">,
                    <cfqueryparam value="#arguments.notification_type#" cfsqltype="cf_sql_varchar">,
                    <cfqueryparam value="#arguments.notification_message#" cfsqltype="cf_sql_varchar">,
                    0,
                    CURRENT_TIMESTAMP,
                    CURRENT_TIMESTAMP
                )
            </cfquery>
            <cfreturn true>
            <cfcatch>
                <cfreturn false>
            </cfcatch>
        </cftry>
    </cffunction>

    <!--- Mark notification as read --->
    <cffunction name="mark_notification_read" access="remote" returntype="boolean" returnformat="json">
        <cfargument name="notification_id" type="numeric" required="true">
        
        <cftry>
            <cfquery datasource="#this.DBSERVER#">
                UPDATE notifications
                SET 
                    is_read = 1,
                    modified_date = CURRENT_TIMESTAMP
                WHERE notification_id = <cfqueryparam value="#arguments.notification_id#" cfsqltype="cf_sql_numeric">
            </cfquery>
            <cfreturn true>
            <cfcatch>
                <cfreturn false>
            </cfcatch>
        </cftry>
    </cffunction>

    <!--- Delete a notification --->
    <cffunction name="delete_notification" access="remote" returntype="boolean" returnformat="json">
        <cfargument name="notification_id" type="numeric" required="true">
        <cfargument name="user_id" type="numeric" required="true">
        
        <cftry>
            <cfquery datasource="#this.DBSERVER#">
                DELETE FROM notifications
                WHERE notification_id = <cfqueryparam value="#arguments.notification_id#" cfsqltype="cf_sql_numeric">
                AND user_id = <cfqueryparam value="#arguments.user_id#" cfsqltype="cf_sql_numeric">
            </cfquery>
            <cfreturn true>
            <cfcatch>
                <cfreturn false>
            </cfcatch>
        </cftry>
    </cffunction>

    <!--- Get unread notification count --->
    <cffunction name="get_unread_count" access="remote" returntype="numeric" returnformat="json">
        <cfargument name="user_id" type="numeric" required="true">
        
        <cfquery name="qUnreadCount" datasource="#this.DBSERVER#">
            SELECT COUNT(*) as unread_count
            FROM notifications
            WHERE user_id = <cfqueryparam value="#arguments.user_id#" cfsqltype="cf_sql_numeric">
            AND is_read = 0
        </cfquery>
        
        <cfreturn qUnreadCount.unread_count>
    </cffunction>

    <!--- Mark all notifications as read for a user --->
    <cffunction name="mark_all_read" access="remote" returntype="boolean" returnformat="json">
        <cfargument name="user_id" type="numeric" required="true">
        
        <cftry>
            <cfquery datasource="#this.DBSERVER#">
                UPDATE notifications
                SET 
                    is_read = 1,
                    modified_date = CURRENT_TIMESTAMP
                WHERE user_id = <cfqueryparam value="#arguments.user_id#" cfsqltype="cf_sql_numeric">
                AND is_read = 0
            </cfquery>
            <cfreturn true>
            <cfcatch>
                <cfreturn false>
            </cfcatch>
        </cftry>
    </cffunction>

    <!--- Get recent notifications with pagination --->
    <cffunction name="get_recent_notifications" access="remote" returntype="query" returnformat="json">
        <cfargument name="user_id" type="numeric" required="true">
        <cfargument name="page_size" type="numeric" required="false" default="10">
        <cfargument name="page_number" type="numeric" required="false" default="1">
        
        <cfset local.offset = (arguments.page_number - 1) * arguments.page_size>
        
        <cfquery name="qRecentNotifications" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
            SELECT 
                NOTIFICATION_ID,
                USER_ID,
                TYPE,
                CONTENT,
                STATUS
            FROM #this.DBSCHEMA#.NOTIFICATIONS
            WHERE USER_ID = <cfqueryparam value="#arguments.user_id#" cfsqltype="cf_sql_numeric">
            ORDER BY CREATED_AT DESC
            OFFSET <cfqueryparam value="#local.offset#" cfsqltype="cf_sql_integer">
            ROWS FETCH NEXT <cfqueryparam value="#arguments.page_size#" cfsqltype="cf_sql_integer"> ROWS ONLY
        </cfquery>
        
        <cfreturn qRecentNotifications>
    </cffunction>

    <!--- Send booking reminder notification --->
    <cffunction name="sendBookingReminder" access="remote" returntype="boolean" returnformat="json">
        <cfargument name="booking_id" type="numeric" required="true">
        
        <cftry>
            <!--- Get booking details --->
            <cfquery name="qGetBooking" datasource="#this.DBSERVER#">
                SELECT 
                    b.booking_id,
                    b.user_id,
                    b.start_time,
                    b.end_time,
                    b.room_id,
                    r.room_name,
                    u.email,
                    u.first_name,
                    u.last_name
                FROM bookings b
                INNER JOIN rooms r ON b.room_id = r.room_id
                INNER JOIN users u ON b.user_id = u.user_id
                WHERE b.booking_id = <cfqueryparam value="#arguments.booking_id#" cfsqltype="cf_sql_numeric">
            </cfquery>

            <!--- Send email notification --->
            <cfif qGetBooking.recordCount>
                <cfmail 
                    to="#qGetBooking.email#"
                    from="noreply@company.com"
                    subject="Upcoming Booking Reminder"
                    type="html">
                    <cfoutput>
                    <h2>Booking Reminder</h2>
                    <p>Dear #qGetBooking.first_name# #qGetBooking.last_name#,</p>
                    <p>This is a reminder for your upcoming booking:</p>
                    <ul>
                        <li>Room: #qGetBooking.room_name#</li>
                        <li>Start Time: #DateTimeFormat(qGetBooking.start_time, "mmm d, yyyy h:nn tt")#</li>
                        <li>End Time: #DateTimeFormat(qGetBooking.end_time, "mmm d, yyyy h:nn tt")#</li>
                    </ul>
                    <p>Thank you for using our booking system.</p>
                    </cfoutput>
                </cfmail>

                <!--- Create notification record --->
                <cfset createNotification(
                    user_id = qGetBooking.user_id,
                    notification_type = "BOOKING_REMINDER",
                    notification_message = "Reminder: You have an upcoming booking in #qGetBooking.room_name# at #DateTimeFormat(qGetBooking.start_time, 'h:nn tt')#"
                )>
                
                <cfreturn true>
            </cfif>
            
            <cfcatch>
                <cfreturn false>
            </cfcatch>
        </cftry>
    </cffunction>

    <!--- Send booking end reminder notification --->
    <cffunction name="sendBookingEndReminder" access="remote" returntype="boolean" returnformat="json">
        <cfargument name="booking_id" type="numeric" required="true">
        
        <cftry>
            <!--- Get booking details --->
            <cfquery name="qGetBooking" datasource="#this.DBSERVER#">
                SELECT 
                    b.booking_id,
                    b.user_id,
                    b.start_time,
                    b.end_time,
                    b.room_id,
                    r.room_name,
                    u.email,
                    u.first_name,
                    u.last_name
                FROM bookings b
                INNER JOIN rooms r ON b.room_id = r.room_id
                INNER JOIN users u ON b.user_id = u.user_id
                WHERE b.booking_id = <cfqueryparam value="#arguments.booking_id#" cfsqltype="cf_sql_numeric">
            </cfquery>

            <!--- Send email notification --->
            <cfif qGetBooking.recordCount>
                <cfmail 
                    to="#qGetBooking.email#"
                    from="noreply@company.com"
                    subject="Booking End Reminder"
                    type="html">
                    <cfoutput>
                    <h2>Booking End Reminder</h2>
                    <p>Dear #qGetBooking.first_name# #qGetBooking.last_name#,</p>
                    <p>Your booking will end in one hour:</p>
                    <ul>
                        <li>Room: #qGetBooking.room_name#</li>
                        <li>End Time: #DateTimeFormat(qGetBooking.end_time, "mmm d, yyyy h:nn tt")#</li>
                    </ul>
                    <p>Please ensure you wrap up your meeting on time to allow for the next booking.</p>
                    </cfoutput>
                </cfmail>

                <!--- Create notification record --->
                <cfset createNotification(
                    user_id = qGetBooking.user_id,
                    notification_type = "BOOKING_END_REMINDER",
                    notification_message = "Your booking in #qGetBooking.room_name# will end at #DateTimeFormat(qGetBooking.end_time, 'h:nn tt')#"
                )>
                
                <cfreturn true>
            </cfif>
            
            <cfcatch>
                <cfreturn false>
            </cfcatch>
        </cftry>
    </cffunction>

    <!--- Check and send notifications for upcoming bookings --->
    <cffunction name="checkAndSendNotifications" access="remote" returntype="void">
        <!--- Get upcoming bookings that need notifications --->
        <cfquery name="qUpcomingBookings" datasource="#this.DBSERVER#">
            SELECT 
                booking_id,
                start_time,
                end_time
            FROM bookings
            WHERE start_time > CURRENT_TIMESTAMP
            AND start_time <= DATEADD(hour, 24, CURRENT_TIMESTAMP)
            AND notification_sent = 0
        </cfquery>

        <!--- Send notifications for upcoming bookings --->
        <cfloop query="qUpcomingBookings">
            <cfset sendBookingReminder(booking_id)>
            
            <!--- Update notification sent status --->
            <cfquery datasource="#this.DBSERVER#">
                UPDATE bookings
                SET notification_sent = 1
                WHERE booking_id = <cfqueryparam value="#booking_id#" cfsqltype="cf_sql_numeric">
            </cfquery>
        </cfloop>

        <!--- Get bookings ending in one hour --->
        <cfquery name="qEndingBookings" datasource="#this.DBSERVER#">
            SELECT 
                booking_id,
                end_time
            FROM bookings
            WHERE end_time > CURRENT_TIMESTAMP
            AND end_time <= DATEADD(hour, 1, CURRENT_TIMESTAMP)
            AND end_notification_sent = 0
        </cfquery>

        <!--- Send notifications for ending bookings --->
        <cfloop query="qEndingBookings">
            <cfset sendBookingEndReminder(booking_id)>
            
            <!--- Update end notification sent status --->
            <cfquery datasource="#this.DBSERVER#">
                UPDATE bookings
                SET end_notification_sent = 1
                WHERE booking_id = <cfqueryparam value="#booking_id#" cfsqltype="cf_sql_numeric">
            </cfquery>
        </cfloop>
    </cffunction>

    <!--- Admin Functions for Notification Management --->
    
    <!--- Get all notifications for admin management ----->
    <cffunction name="getAllNotifications" access="remote" returntype="query" returnformat="json">
        <cfargument name="page_size" type="numeric" required="false" default="25">
        <cfargument name="page_number" type="numeric" required="false" default="1">
        <cfargument name="filter_type" type="string" required="false" default="">
        <cfargument name="filter_status" type="string" required="false" default="">
        
        <cfset local.offset = (arguments.page_number - 1) * arguments.page_size>
        
        <cfquery name="qAllNotifications" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
            SELECT 
                n.NOTIFICATION_ID,
                n.USER_ID,
                n.TYPE,
                n.CONTENT,
                n.STATUS,
                n.CREATED_AT,
                u.FIRST_NAME,
                u.LAST_NAME,
                u.EMAIL
            FROM #this.DBSCHEMA#.NOTIFICATIONS n
            LEFT JOIN #this.DBSCHEMA#.USERS u ON n.USER_ID = u.USER_ID
            WHERE 1=1
            <cfif len(trim(arguments.filter_type))>
                AND UPPER(n.TYPE) = <cfqueryparam value="#UCase(arguments.filter_type)#" cfsqltype="cf_sql_varchar">
            </cfif>
            <cfif len(trim(arguments.filter_status))>
                AND UPPER(n.STATUS) = <cfqueryparam value="#UCase(arguments.filter_status)#" cfsqltype="cf_sql_varchar">
            </cfif>
            ORDER BY n.CREATED_AT DESC
            OFFSET <cfqueryparam value="#local.offset#" cfsqltype="cf_sql_integer"> ROWS 
            FETCH NEXT <cfqueryparam value="#arguments.page_size#" cfsqltype="cf_sql_integer"> ROWS ONLY
        </cfquery>
        
        <cfreturn qAllNotifications>
    </cffunction>

    <!--- Get notification statistics for admin dashboard ----->
    <cffunction name="getNotificationStats" access="remote" returntype="struct" returnformat="json">
        <cfset local.stats = {}>
        
        <!--- Total notifications ----->
        <cfquery name="qTotalCount" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
            SELECT COUNT(*) as total_count
            FROM #this.DBSCHEMA#.NOTIFICATIONS
        </cfquery>
        <cfset local.stats.total = qTotalCount.total_count>
        
        <!--- Unread notifications ----->
        <cfquery name="qUnreadCount" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
            SELECT COUNT(*) as unread_count
            FROM #this.DBSCHEMA#.NOTIFICATIONS
            WHERE UPPER(STATUS) = 'UNREAD'
        </cfquery>
        <cfset local.stats.unread = qUnreadCount.unread_count>
        
        <!--- Notifications by type ----->
        <cfquery name="qByType" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
            SELECT TYPE, COUNT(*) as count
            FROM #this.DBSCHEMA#.NOTIFICATIONS
            GROUP BY TYPE
            ORDER BY count DESC
        </cfquery>
        <cfset local.stats.byType = []>
        <cfloop query="qByType">
            <cfset arrayAppend(local.stats.byType, {"type": qByType.TYPE, "count": qByType.count})>
        </cfloop>
        
        <!--- Recent notifications (last 7 days) ----->
        <cfquery name="qRecentCount" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
            SELECT COUNT(*) as recent_count
            FROM #this.DBSCHEMA#.NOTIFICATIONS
            WHERE CREATED_AT >= SYSDATE - 7
        </cfquery>
        <cfset local.stats.recent = qRecentCount.recent_count>
        
        <cfreturn local.stats>
    </cffunction>

    <!--- Create bulk notification for multiple users ----->
    <cffunction name="createBulkNotification" access="remote" returntype="struct" returnformat="json">
        <cfargument name="user_ids" type="string" required="true">
        <cfargument name="notification_type" type="string" required="true">
        <cfargument name="notification_message" type="string" required="true">
        
        <cfset local.result = {"success": false, "message": "", "created_count": 0}>
        
        <cftry>
            <cfset local.userList = listToArray(arguments.user_ids)>
            <cfset local.createdCount = 0>
            
            <cfloop array="#local.userList#" index="userId">
                <cfquery datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                    INSERT INTO #this.DBSCHEMA#.NOTIFICATIONS (
                        USER_ID,
                        TYPE,
                        CONTENT,
                        STATUS,
                        CREATED_AT
                    ) VALUES (
                        <cfqueryparam value="#trim(userId)#" cfsqltype="cf_sql_numeric">,
                        <cfqueryparam value="#arguments.notification_type#" cfsqltype="cf_sql_varchar">,
                        <cfqueryparam value="#arguments.notification_message#" cfsqltype="cf_sql_varchar">,
                        'UNREAD',
                        CURRENT_TIMESTAMP
                    )
                </cfquery>
                <cfset local.createdCount++>
            </cfloop>
            
            <cfset local.result.success = true>
            <cfset local.result.message = "Successfully created #local.createdCount# notifications">
            <cfset local.result.created_count = local.createdCount>
            
        <cfcatch>
            <cfset local.result.message = "Error creating notifications: #cfcatch.message#">
        </cfcatch>
        </cftry>
        
        <cfreturn local.result>
    </cffunction>

    <!--- Update notification status (admin function) ----->
    <cffunction name="updateNotificationStatus" access="remote" returntype="struct" returnformat="json">
        <cfargument name="notification_id" type="numeric" required="true">
        <cfargument name="new_status" type="string" required="true">
        
        <cfset local.result = {"success": false, "message": ""}>
        
        <cftry>
            <cfquery datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                UPDATE #this.DBSCHEMA#.NOTIFICATIONS
                SET STATUS = <cfqueryparam value="#arguments.new_status#" cfsqltype="cf_sql_varchar">
                WHERE NOTIFICATION_ID = <cfqueryparam value="#arguments.notification_id#" cfsqltype="cf_sql_numeric">
            </cfquery>
            
            <cfset local.result.success = true>
            <cfset local.result.message = "Notification status updated successfully">
            
        <cfcatch>
            <cfset local.result.message = "Error updating notification: #cfcatch.message#">
        </cfcatch>
        </cftry>
        
        <cfreturn local.result>
    </cffunction>

    <!--- Delete notification (admin function) ----->
    <cffunction name="deleteNotificationAdmin" access="remote" returntype="struct" returnformat="json">
        <cfargument name="notification_id" type="numeric" required="true">
        
        <cfset local.result = {"success": false, "message": ""}>
        
        <cftry>
            <cfquery datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                DELETE FROM #this.DBSCHEMA#.NOTIFICATIONS
                WHERE NOTIFICATION_ID = <cfqueryparam value="#arguments.notification_id#" cfsqltype="cf_sql_numeric">
            </cfquery>
            
            <cfset local.result.success = true>
            <cfset local.result.message = "Notification deleted successfully">
            
        <cfcatch>
            <cfset local.result.message = "Error deleting notification: #cfcatch.message#">
        </cfcatch>
        </cftry>
        
        <cfreturn local.result>
    </cffunction>

    <!--- Get users for bulk notification dropdown ----->
    <cffunction name="getUsersForNotification" access="remote" returntype="query" returnformat="json">
        <cfquery name="qUsers" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
            SELECT 
                USER_ID,
                FIRST_NAME,
                LAST_NAME,
                EMAIL,
                ROLE
            FROM #this.DBSCHEMA#.USERS
            WHERE ROLE IN ('User', 'Admin', 'Site Admin')
            ORDER BY LAST_NAME, FIRST_NAME
        </cfquery>
        
        <cfreturn qUsers>
    </cffunction>

    <!--- Notification Preferences Management Functions --->

    <!--- Get notification preferences for a user --->
    <cffunction name="getUserNotificationPreferences" access="remote" returntype="query" returnformat="json">
        <cfargument name="user_id" type="numeric" required="true">
        
        <cftry>
            <cfquery name="qPreferences" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT 
                    np.NOTIFICATION_TYPE,
                    np.EMAIL_ENABLED,
                    np.IN_APP_ENABLED,
                    nt.DISPLAY_NAME,
                    nt.DESCRIPTION,
                    nt.CATEGORY
                FROM #this.DBSCHEMA#.NOTIFICATION_PREFERENCES np
                RIGHT JOIN #this.DBSCHEMA#.NOTIFICATION_TYPES nt ON np.NOTIFICATION_TYPE = nt.TYPE_CODE
                    AND np.USER_ID = <cfqueryparam value="#arguments.user_id#" cfsqltype="cf_sql_numeric">
                ORDER BY nt.CATEGORY, nt.DISPLAY_NAME
            </cfquery>
            
            <cfreturn qPreferences>
            
        <cfcatch>
            <!--- Return empty preferences if tables don't exist --->
            <cfset local.emptyPrefs = queryNew("NOTIFICATION_TYPE,EMAIL_ENABLED,IN_APP_ENABLED,DISPLAY_NAME,DESCRIPTION,CATEGORY", "varchar,bit,bit,varchar,varchar,varchar")>
            <cfreturn local.emptyPrefs>
        </cfcatch>
        </cftry>
    </cffunction>

    <!--- Update notification preference for a user --->
    <cffunction name="updateNotificationPreference" access="remote" returntype="struct" returnformat="json">
        <cfargument name="user_id" type="numeric" required="true">
        <cfargument name="notification_type" type="string" required="true">
        <cfargument name="email_enabled" type="boolean" required="true">
        <cfargument name="in_app_enabled" type="boolean" required="true">
        
        <cfset local.result = {"success": false, "message": ""}>
        
        <cftry>
            <!--- Check if preference exists --->
            <cfquery name="qCheckExists" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT COUNT(*) as count
                FROM #this.DBSCHEMA#.NOTIFICATION_PREFERENCES
                WHERE USER_ID = <cfqueryparam value="#arguments.user_id#" cfsqltype="cf_sql_numeric">
                AND NOTIFICATION_TYPE = <cfqueryparam value="#arguments.notification_type#" cfsqltype="cf_sql_varchar">
            </cfquery>
            
            <cfif qCheckExists.count GT 0>
                <!--- Update existing preference --->
                <cfquery datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                    UPDATE #this.DBSCHEMA#.NOTIFICATION_PREFERENCES
                    SET 
                        EMAIL_ENABLED = <cfqueryparam value="#arguments.email_enabled#" cfsqltype="cf_sql_bit">,
                        IN_APP_ENABLED = <cfqueryparam value="#arguments.in_app_enabled#" cfsqltype="cf_sql_bit">,
                        UPDATED_AT = CURRENT_TIMESTAMP
                    WHERE USER_ID = <cfqueryparam value="#arguments.user_id#" cfsqltype="cf_sql_numeric">
                    AND NOTIFICATION_TYPE = <cfqueryparam value="#arguments.notification_type#" cfsqltype="cf_sql_varchar">
                </cfquery>
            <cfelse>
                <!--- Insert new preference --->
                <cfquery datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                    INSERT INTO #this.DBSCHEMA#.NOTIFICATION_PREFERENCES (
                        USER_ID, NOTIFICATION_TYPE, EMAIL_ENABLED, IN_APP_ENABLED, CREATED_AT, UPDATED_AT
                    ) VALUES (
                        <cfqueryparam value="#arguments.user_id#" cfsqltype="cf_sql_numeric">,
                        <cfqueryparam value="#arguments.notification_type#" cfsqltype="cf_sql_varchar">,
                        <cfqueryparam value="#arguments.email_enabled#" cfsqltype="cf_sql_bit">,
                        <cfqueryparam value="#arguments.in_app_enabled#" cfsqltype="cf_sql_bit">,
                        CURRENT_TIMESTAMP,
                        CURRENT_TIMESTAMP
                    )
                </cfquery>
            </cfif>
            
            <cfset local.result.success = true>
            <cfset local.result.message = "Notification preference updated successfully">
            
        <cfcatch>
            <cfset local.result.message = "Error updating notification preference: #cfcatch.message#">
        </cfcatch>
        </cftry>
        
        <cfreturn local.result>
    </cffunction>

    <!--- Get all notification types --->
    <cffunction name="getAllNotificationTypes" access="remote" returntype="query" returnformat="json">
        <cftry>
            <cfquery name="qTypes" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT 
                    TYPE_CODE,
                    DISPLAY_NAME,
                    DESCRIPTION,
                    CATEGORY,
                    DEFAULT_EMAIL_ENABLED,
                    DEFAULT_IN_APP_ENABLED,
                    ADMIN_ONLY
                FROM #this.DBSCHEMA#.NOTIFICATION_TYPES
                ORDER BY CATEGORY, DISPLAY_NAME
            </cfquery>
            
            <cfreturn qTypes>
            
        <cfcatch>
            <!--- Return default notification types if table doesn't exist --->
            <cfset local.defaultTypes = queryNew("TYPE_CODE,DISPLAY_NAME,DESCRIPTION,CATEGORY,DEFAULT_EMAIL_ENABLED,DEFAULT_IN_APP_ENABLED,ADMIN_ONLY", "varchar,varchar,varchar,varchar,bit,bit,bit")>
            
            <!--- Add default notification types --->
            <cfset queryAddRow(local.defaultTypes)>
            <cfset querySetCell(local.defaultTypes, "TYPE_CODE", "BOOKING_CONFIRMATION")>
            <cfset querySetCell(local.defaultTypes, "DISPLAY_NAME", "Booking Confirmation")>
            <cfset querySetCell(local.defaultTypes, "DESCRIPTION", "Email sent when a new booking is created")>
            <cfset querySetCell(local.defaultTypes, "CATEGORY", "Booking Lifecycle")>
            <cfset querySetCell(local.defaultTypes, "DEFAULT_EMAIL_ENABLED", 1)>
            <cfset querySetCell(local.defaultTypes, "DEFAULT_IN_APP_ENABLED", 1)>
            <cfset querySetCell(local.defaultTypes, "ADMIN_ONLY", 0)>
            
            <cfset queryAddRow(local.defaultTypes)>
            <cfset querySetCell(local.defaultTypes, "TYPE_CODE", "BOOKING_CANCELLATION")>
            <cfset querySetCell(local.defaultTypes, "DISPLAY_NAME", "Booking Cancellation")>
            <cfset querySetCell(local.defaultTypes, "DESCRIPTION", "Email sent when a booking is cancelled")>
            <cfset querySetCell(local.defaultTypes, "CATEGORY", "Booking Lifecycle")>
            <cfset querySetCell(local.defaultTypes, "DEFAULT_EMAIL_ENABLED", 1)>
            <cfset querySetCell(local.defaultTypes, "DEFAULT_IN_APP_ENABLED", 1)>
            <cfset querySetCell(local.defaultTypes, "ADMIN_ONLY", 0)>
            
            <cfset queryAddRow(local.defaultTypes)>
            <cfset querySetCell(local.defaultTypes, "TYPE_CODE", "NEW_USER_ACCESS_REQUEST")>
            <cfset querySetCell(local.defaultTypes, "DISPLAY_NAME", "New User Access Request")>
            <cfset querySetCell(local.defaultTypes, "DESCRIPTION", "Email sent to admins when new user requests access")>
            <cfset querySetCell(local.defaultTypes, "CATEGORY", "User Management")>
            <cfset querySetCell(local.defaultTypes, "DEFAULT_EMAIL_ENABLED", 1)>
            <cfset querySetCell(local.defaultTypes, "DEFAULT_IN_APP_ENABLED", 1)>
            <cfset querySetCell(local.defaultTypes, "ADMIN_ONLY", 1)>
            
            <cfreturn local.defaultTypes>
        </cfcatch>
        </cftry>
    </cffunction>

    <!--- Check if user should receive specific notification type --->
    <cffunction name="shouldReceiveNotification" access="public" returntype="struct" output="false">
        <cfargument name="user_id" type="numeric" required="true">
        <cfargument name="notification_type" type="string" required="true">
        
        <cfset local.result = {"email": true, "in_app": true}>
        
        <cftry>
            <!--- Get user's preference for this notification type --->
            <cfquery name="qPreference" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT 
                    np.EMAIL_ENABLED,
                    np.IN_APP_ENABLED,
                    nt.DEFAULT_EMAIL_ENABLED,
                    nt.DEFAULT_IN_APP_ENABLED
                FROM #this.DBSCHEMA#.NOTIFICATION_TYPES nt
                LEFT JOIN #this.DBSCHEMA#.NOTIFICATION_PREFERENCES np ON nt.TYPE_CODE = np.NOTIFICATION_TYPE
                    AND np.USER_ID = <cfqueryparam value="#arguments.user_id#" cfsqltype="cf_sql_numeric">
                WHERE nt.TYPE_CODE = <cfqueryparam value="#arguments.notification_type#" cfsqltype="cf_sql_varchar">
            </cfquery>
            
            <cfif qPreference.recordCount GT 0>
                <!--- Use user preference if exists, otherwise use defaults --->
                <cfif NOT IsNull(qPreference.EMAIL_ENABLED)>
                    <cfset local.result.email = qPreference.EMAIL_ENABLED>
                <cfelse>
                    <cfset local.result.email = qPreference.DEFAULT_EMAIL_ENABLED>
                </cfif>
                
                <cfif NOT IsNull(qPreference.IN_APP_ENABLED)>
                    <cfset local.result.in_app = qPreference.IN_APP_ENABLED>
                <cfelse>
                    <cfset local.result.in_app = qPreference.DEFAULT_IN_APP_ENABLED>
                </cfif>
            </cfif>
            
        <cfcatch>
            <!--- On error, default to enabled (backwards compatibility) --->
            <cfset local.result = {"email": true, "in_app": true}>
        </cfcatch>
        </cftry>
        
        <cfreturn local.result>
    </cffunction>

    <!--- Get admin users who should receive specific notification type --->
    <cffunction name="getAdminsForNotification" access="public" returntype="query" output="false">
        <cfargument name="notification_type" type="string" required="true">
        <cfargument name="delivery_method" type="string" required="false" default="email">
        
        <cftry>
            <cfset local.emailField = (arguments.delivery_method EQ "email") ? "np.EMAIL_ENABLED" : "np.IN_APP_ENABLED">
            <cfset local.defaultField = (arguments.delivery_method EQ "email") ? "nt.DEFAULT_EMAIL_ENABLED" : "nt.DEFAULT_IN_APP_ENABLED">
            
            <cfquery name="qAdmins" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT DISTINCT
                    u.USER_ID,
                    u.FIRST_NAME,
                    u.LAST_NAME,
                    u.EMAIL,
                    u.ROLE
                FROM #this.DBSCHEMA#.USERS u
                INNER JOIN #this.DBSCHEMA#.NOTIFICATION_TYPES nt ON nt.TYPE_CODE = <cfqueryparam value="#arguments.notification_type#" cfsqltype="cf_sql_varchar">
                LEFT JOIN #this.DBSCHEMA#.NOTIFICATION_PREFERENCES np ON np.USER_ID = u.USER_ID 
                    AND np.NOTIFICATION_TYPE = nt.TYPE_CODE
                WHERE u.ROLE IN ('Admin', 'Site Admin')
                AND u.STATUS = 'Active'
                AND (
                    (np.NOTIFICATION_ID IS NOT NULL AND #PreserveSingleQuotes(local.emailField)# = 1)
                    OR (np.NOTIFICATION_ID IS NULL AND #PreserveSingleQuotes(local.defaultField)# = 1)
                )
                ORDER BY u.LAST_NAME, u.FIRST_NAME
            </cfquery>
            
            <cfreturn qAdmins>
            
        <cfcatch>
            <!--- If tables don't exist, return all active admins --->
            <cfquery name="qDefaultAdmins" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT DISTINCT
                    u.USER_ID,
                    u.FIRST_NAME,
                    u.LAST_NAME,
                    u.EMAIL,
                    u.ROLE
                FROM #this.DBSCHEMA#.USERS u
                WHERE u.ROLE IN ('Admin', 'Site Admin')
                AND u.STATUS = 'Active'
                ORDER BY u.LAST_NAME, u.FIRST_NAME
            </cfquery>
            
            <cfreturn qDefaultAdmins>
        </cfcatch>
        </cftry>
    </cffunction>

</cfcomponent>
