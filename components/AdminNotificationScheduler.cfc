<cfcomponent displayname="Admin Notification Scheduler" hint="Scheduled task to send admin notifications for new users, pending bookings, and user status changes">

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

    <!---
        Main scheduler function to be called by ColdFusion scheduler
        Runs all notification checks and sends notifications to admins
    --->
    <cffunction name="runScheduledNotifications" access="remote" returntype="struct" returnformat="json" output="false">
        <cfset var result = {
            success = true,
            message = "",
            timestamp = now(),
            checks = {}
        }>

        <cftry>
            <!--- Check for new users --->
            <cfset result.checks.newUsers = checkNewUsers()>

            <!--- Check for new reservation requests --->
            <cfset result.checks.newReservations = checkNewReservations()>

            <!--- Check for user status changes --->
            <cfset result.checks.userStatusChanges = checkUserStatusChanges()>

            <cfset result.message = "Admin notification checks completed successfully">

        <cfcatch>
            <cfset result.success = false>
            <cfset result.message = "Error in runScheduledNotifications: #cfcatch.message#">
            <cflog type="error" file="admin_notifications" text="Error in runScheduledNotifications: #cfcatch.message# #cfcatch.detail#">
        </cfcatch>
        </cftry>

        <cfreturn result>
    </cffunction>

    <!---
        Check for new users created since last check
        Sends notification to all admins about new user registrations
    --->
    <cffunction name="checkNewUsers" access="private" returntype="struct" output="false">
        <cfset var result = {
            found = 0,
            notified = 0,
            failed = 0,
            userDetails = [],
            skippedDuplicates = 0
        }>

        <cftry>
            <!--- Get admin users --->
            <cfset var admins = getAdminUsers()>

            <!--- Get new users (created in last 24 hours and not yet notified) --->
            <cfquery name="qNewUsers" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT
                    u.USER_ID,
                    u.FIRST_NAME,
                    u.LAST_NAME,
                    u.EMAIL,
                    u.EMPLID,
                    r.ROLE_NAME,
                    u.DATEENTERED,
                    u.STATUS
                FROM #this.DBSCHEMA#.USERS u
                LEFT JOIN #this.DBSCHEMA#.ROLES r ON u.ROLE_ID = r.ROLE_ID
                WHERE u.DATEENTERED >= TRUNC(SYSDATE) - 1
                AND NOT EXISTS (
                    SELECT 1 FROM #this.DBSCHEMA#.NOTIFICATIONS n
                    WHERE n.USER_ID IN (
                        -- USERS has no ROLE_NAME column, only ROLE_ID. The previous
                        -- subquery referenced it directly and raised ORA-00904, so
                        -- every check in this component threw on each run and was
                        -- swallowed by its cfcatch. Site Admins are included, matching
                        -- getAdminUsers().
                        SELECT au.USER_ID
                        FROM #this.DBSCHEMA#.USERS au
                        JOIN #this.DBSCHEMA#.ROLES ar ON ar.ROLE_ID = au.ROLE_ID
                        WHERE UPPER(TRIM(ar.ROLE_NAME)) IN ('ADMIN', 'SITE ADMIN')
                    )
                    AND n.TYPE = 'NEW_USER_REGISTERED'
                    AND n.CONTENT LIKE '%' || u.USER_ID || '%'
                    AND n.CREATED_AT >= TRUNC(SYSDATE) - 1
                )
                ORDER BY u.DATEENTERED DESC
            </cfquery>

            <cfset result.found = qNewUsers.recordCount>

            <cfif qNewUsers.recordCount GT 0>
                <!--- Send notification to each admin --->
                <cfloop query="admins">
                    <cftry>
                        <!--- Same once-per-interval guard as the reservation check, so
                              overlapping runs cannot re-mail the same administrator
                              about the same new users. --->
                        <cfif NOT claimNotificationSlot(
                                recipientUserId = admins.USER_ID,
                                notificationType = "NEW_USER_REGISTERED_ALERT",
                                pendingCount = qNewUsers.recordCount)>
                            <cfset result.skippedDuplicates++>
                            <cfcontinue>
                        </cfif>

                        <cfset var notificationId = createAdminNotification(
                            adminUserId = admins.USER_ID,
                            type = "NEW_USER_REGISTERED",
                            newUserCount = qNewUsers.recordCount,
                            userDetails = qNewUsers
                        )>

                        <!--- Send email notification --->
                        <cfset sendNewUserNotificationEmail(
                            adminEmail = admins.EMAIL,
                            adminName = admins.FIRST_NAME & " " & admins.LAST_NAME,
                            newUsers = qNewUsers
                        )>

                        <cfset result.notified++>
                    <cfcatch>
                        <cfset result.failed++>
                        <cflog type="error" file="admin_notifications" text="Failed to notify admin #admins.USER_ID# about new users: #cfcatch.message#">
                    </cfcatch>
                    </cftry>
                </cfloop>

                <!--- Store details for return --->
                <cfloop query="qNewUsers">
                    <cfset arrayAppend(result.userDetails, {
                        userId = qNewUsers.USER_ID,
                        name = qNewUsers.FIRST_NAME & " " & qNewUsers.LAST_NAME,
                        email = qNewUsers.EMAIL,
                        role = qNewUsers.ROLE_NAME ?: "User",
                        createdAt = qNewUsers.DATEENTERED
                    })>
                </cfloop>
            </cfif>

        <cfcatch>
            <cflog type="error" file="admin_notifications" text="Error in checkNewUsers: #cfcatch.message# #cfcatch.detail#">
        </cfcatch>
        </cftry>

        <cfreturn result>
    </cffunction>

    <!---
        Check for new reservation requests (pending bookings)
        Sends notification to all admins about pending approvals
    --->
    <cffunction name="checkNewReservations" access="private" returntype="struct" output="false">
        <cfset var result = {
            found = 0,
            notified = 0,
            failed = 0,
            reservationDetails = [],
            skippedDuplicates = 0
        }>

        <cftry>
            <!--- Get admin users --->
            <cfset var admins = getAdminUsers()>

            <!--- Get new pending bookings (created/updated in last 24 hours) --->
            <cfquery name="qPendingBookings" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT
                    b.BOOKING_ID,
                    u.FIRST_NAME,
                    u.LAST_NAME,
                    u.EMAIL as USER_EMAIL,
                    r.ROOM_NAME,
                    r.BUILDING,
                    r.ROOM_NUMBER,
                    b.START_TIME,
                    b.END_TIME,
                    b.COMMENTS as MEETING_TITLE,
                    b.CREATED_AT,
                    b.STATUS
                FROM #this.DBSCHEMA#.BOOKINGS b
                JOIN #this.DBSCHEMA#.USERS u ON b.USER_ID = u.USER_ID
                JOIN #this.DBSCHEMA#.ROOMS r ON b.ROOM_ID = r.ROOM_ID
                WHERE LOWER(b.STATUS) = 'pending'
                AND (b.CREATED_AT >= TRUNC(SYSDATE) - 1
                     OR b.UPDATED_AT >= TRUNC(SYSDATE) - 1)
                AND NOT EXISTS (
                    SELECT 1 FROM #this.DBSCHEMA#.NOTIFICATIONS n
                    WHERE n.USER_ID IN (
                        -- USERS has no ROLE_NAME column, only ROLE_ID. The previous
                        -- subquery referenced it directly and raised ORA-00904, so
                        -- every check in this component threw on each run and was
                        -- swallowed by its cfcatch. Site Admins are included, matching
                        -- getAdminUsers().
                        SELECT au.USER_ID
                        FROM #this.DBSCHEMA#.USERS au
                        JOIN #this.DBSCHEMA#.ROLES ar ON ar.ROLE_ID = au.ROLE_ID
                        WHERE UPPER(TRIM(ar.ROLE_NAME)) IN ('ADMIN', 'SITE ADMIN')
                    )
                    AND n.TYPE = 'NEW_RESERVATION_REQUEST'
                    AND n.CONTENT LIKE '%' || b.BOOKING_ID || '%'
                    AND n.CREATED_AT >= TRUNC(SYSDATE) - 1
                )
                ORDER BY b.CREATED_AT DESC
            </cfquery>

            <cfset result.found = qPendingBookings.recordCount>

            <cfif qPendingBookings.recordCount GT 0>
                <!--- Send notification to each admin --->
                <cfloop query="admins">
                    <cftry>
                        <!--- Compete for the same claim cfcs/scheduledAPI.cfc uses, so
                              an administrator gets one pending-work notification per
                              interval even if both components are scheduled. --->
                        <cfif NOT claimNotificationSlot(
                                recipientUserId = admins.USER_ID,
                                pendingCount = qPendingBookings.recordCount)>
                            <cfset result.skippedDuplicates++>
                            <cfcontinue>
                        </cfif>

                        <cfset var notificationId = createAdminNotification(
                            adminUserId = admins.USER_ID,
                            type = "NEW_RESERVATION_REQUEST",
                            reservationCount = qPendingBookings.recordCount,
                            reservationDetails = qPendingBookings
                        )>

                        <!--- Send email notification --->
                        <cfset sendNewReservationNotificationEmail(
                            adminEmail = admins.EMAIL,
                            adminName = admins.FIRST_NAME & " " & admins.LAST_NAME,
                            pendingReservations = qPendingBookings
                        )>

                        <cfset result.notified++>
                    <cfcatch>
                        <cfset result.failed++>
                        <cflog type="error" file="admin_notifications" text="Failed to notify admin #admins.USER_ID# about pending reservations: #cfcatch.message#">
                    </cfcatch>
                    </cftry>
                </cfloop>

                <!--- Store details for return --->
                <cfloop query="qPendingBookings">
                    <cfset arrayAppend(result.reservationDetails, {
                        bookingId = qPendingBookings.BOOKING_ID,
                        userName = qPendingBookings.FIRST_NAME & " " & qPendingBookings.LAST_NAME,
                        roomName = qPendingBookings.ROOM_NAME,
                        location = qPendingBookings.BUILDING & "-" & qPendingBookings.ROOM_NUMBER,
                        meetingTitle = qPendingBookings.MEETING_TITLE ?: "No Title",
                        startTime = qPendingBookings.START_TIME,
                        endTime = qPendingBookings.END_TIME
                    })>
                </cfloop>
            </cfif>

        <cfcatch>
            <cflog type="error" file="admin_notifications" text="Error in checkNewReservations: #cfcatch.message# #cfcatch.detail#">
        </cfcatch>
        </cftry>

        <cfreturn result>
    </cffunction>

    <!---
        Check for user status changes
        Sends notification to admins when user status changes
    --->
    <cffunction name="checkUserStatusChanges" access="private" returntype="struct" output="false">
        <cfset var result = {
            found = 0,
            notified = 0,
            failed = 0,
            statusChangeDetails = [],
            skippedDuplicates = 0
        }>

        <cftry>
            <!--- Get admin users --->
            <cfset var admins = getAdminUsers()>

            <!--- Get users with recent status changes --->
            <cfquery name="qStatusChanges" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT
                    u.USER_ID,
                    u.FIRST_NAME,
                    u.LAST_NAME,
                    u.EMAIL,
                    u.STATUS,
                    u.DATEMODIFIED,
                    u.MODIFIEDBYID,
                    CASE
                        WHEN u.STATUS = 'Active' THEN 'Activated'
                        WHEN u.STATUS = 'Inactive' THEN 'Deactivated'
                        ELSE u.STATUS
                    END as STATUS_CHANGE
                FROM #this.DBSCHEMA#.USERS u
                WHERE u.DATEMODIFIED >= TRUNC(SYSDATE) - 1
                AND u.DATEMODIFIED > u.DATEENTERED
                AND NOT EXISTS (
                    SELECT 1 FROM #this.DBSCHEMA#.NOTIFICATIONS n
                    WHERE n.USER_ID IN (
                        -- USERS has no ROLE_NAME column, only ROLE_ID. The previous
                        -- subquery referenced it directly and raised ORA-00904, so
                        -- every check in this component threw on each run and was
                        -- swallowed by its cfcatch. Site Admins are included, matching
                        -- getAdminUsers().
                        SELECT au.USER_ID
                        FROM #this.DBSCHEMA#.USERS au
                        JOIN #this.DBSCHEMA#.ROLES ar ON ar.ROLE_ID = au.ROLE_ID
                        WHERE UPPER(TRIM(ar.ROLE_NAME)) IN ('ADMIN', 'SITE ADMIN')
                    )
                    AND n.TYPE = 'USER_STATUS_CHANGED'
                    AND n.CONTENT LIKE '%' || u.USER_ID || '%'
                    AND n.CREATED_AT >= TRUNC(SYSDATE) - 1
                )
                ORDER BY u.DATEMODIFIED DESC
            </cfquery>

            <cfset result.found = qStatusChanges.recordCount>

            <cfif qStatusChanges.recordCount GT 0>
                <!--- Send notification to each admin --->
                <cfloop query="admins">
                    <cftry>
                        <cfif NOT claimNotificationSlot(
                                recipientUserId = admins.USER_ID,
                                notificationType = "USER_STATUS_CHANGED_ALERT",
                                pendingCount = qStatusChanges.recordCount)>
                            <cfset result.skippedDuplicates++>
                            <cfcontinue>
                        </cfif>

                        <cfset var notificationId = createAdminNotification(
                            adminUserId = admins.USER_ID,
                            type = "USER_STATUS_CHANGED",
                            statusChangeCount = qStatusChanges.recordCount,
                            statusChangeDetails = qStatusChanges
                        )>

                        <!--- Send email notification --->
                        <cfset sendStatusChangeNotificationEmail(
                            adminEmail = admins.EMAIL,
                            adminName = admins.FIRST_NAME & " " & admins.LAST_NAME,
                            statusChanges = qStatusChanges
                        )>

                        <cfset result.notified++>
                    <cfcatch>
                        <cfset result.failed++>
                        <cflog type="error" file="admin_notifications" text="Failed to notify admin #admins.USER_ID# about status changes: #cfcatch.message#">
                    </cfcatch>
                    </cftry>
                </cfloop>

                <!--- Store details for return --->
                <cfloop query="qStatusChanges">
                    <cfset arrayAppend(result.statusChangeDetails, {
                        userId = qStatusChanges.USER_ID,
                        userName = qStatusChanges.FIRST_NAME & " " & qStatusChanges.LAST_NAME,
                        email = qStatusChanges.EMAIL,
                        newStatus = qStatusChanges.STATUS,
                        changeType = qStatusChanges.STATUS_CHANGE,
                        changedAt = qStatusChanges.DATEMODIFIED
                    })>
                </cfloop>
            </cfif>

        <cfcatch>
            <cflog type="error" file="admin_notifications" text="Error in checkUserStatusChanges: #cfcatch.message# #cfcatch.detail#">
        </cfcatch>
        </cftry>

        <cfreturn result>
    </cffunction>

    <!--- Helper function to get all admin users.

         Recipients are Admin *and* Site Admin. This previously matched
         LOWER(r.ROLE_NAME) = 'admin' exactly, silently excluding every Site
         Admin — the same defect that was fixed in
         cfcs/scheduledAPI.cfc:getAdminEmails() and
         components/ApprovalNotification.cfc:getApprovalRecipients(). All three
         now agree on who counts as an approver. --->
    <cffunction name="getAdminUsers" access="private" returntype="query" output="false">
        <cfquery name="qAdmins" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
            SELECT
                u.USER_ID,
                u.FIRST_NAME,
                u.LAST_NAME,
                u.EMAIL,
                u.STATUS
            FROM #this.DBSCHEMA#.USERS u
            JOIN #this.DBSCHEMA#.ROLES r ON u.ROLE_ID = r.ROLE_ID
            WHERE UPPER(TRIM(r.ROLE_NAME)) IN ('ADMIN', 'SITE ADMIN')
            AND UPPER(u.STATUS) = 'ACTIVE'
            AND u.EMAIL IS NOT NULL
        </cfquery>
        <cfreturn qAdmins>
    </cffunction>

    <!---
        Claim the right to notify one recipient for one interval.

        Shares NOTIFICATION_REMINDER_LOG and the same interval key and type as
        cfcs/scheduledAPI.cfc, deliberately. Both components notify approvers
        about pending work, and either may be wired up as the scheduled task. By
        competing for the same claim, whichever runs first wins and the other
        skips — so an administrator receives one notification per interval even if
        BOTH are scheduled. That removes the duplicate-mail risk without having to
        decide which entry point is canonical.

        Returns true only if this caller won the claim. A duplicate-key error is
        the expected "someone else has this" signal, not a failure. If the log
        table is absent the claim is refused-open so notifications keep flowing,
        and that is logged.
    --->
    <cffunction name="claimNotificationSlot" access="private" returntype="boolean" output="false">
        <cfargument name="recipientUserId" type="numeric" required="true">
        <cfargument name="notificationType" type="string" required="false" default="PENDING_REQUEST_REMINDER">
        <cfargument name="pendingCount" type="numeric" required="false" default="0">

        <cfset var qKey = "">
        <cfset var intervalKey = "">
        <cfset var errText = "">

        <cftry>
            <!--- Database clock, so instances with skewed clocks agree on the bucket. --->
            <cfquery name="qKey" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24') AS INTERVAL_KEY FROM DUAL
            </cfquery>
            <cfset intervalKey = qKey.INTERVAL_KEY>

            <cfquery datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                INSERT INTO #this.DBSCHEMA#.NOTIFICATION_REMINDER_LOG
                    (RECIPIENT_USER_ID, NOTIFICATION_TYPE, INTERVAL_KEY, PENDING_COUNT, DELIVERY_STATUS, CLAIMED_AT)
                VALUES (
                    <cfqueryparam value="#arguments.recipientUserId#" cfsqltype="cf_sql_numeric">,
                    <cfqueryparam value="#arguments.notificationType#" cfsqltype="cf_sql_varchar">,
                    <cfqueryparam value="#intervalKey#" cfsqltype="cf_sql_varchar">,
                    <cfqueryparam value="#arguments.pendingCount#" cfsqltype="cf_sql_numeric">,
                    'SENT',
                    CURRENT_TIMESTAMP
                )
            </cfquery>
            <cfreturn true>

        <cfcatch>
            <!--- ColdFusion reports "Error Executing Database Query." as the
                  message and puts the ORA- text in detail, so inspect both. --->
            <cfset errText = cfcatch.message & " " & (structKeyExists(cfcatch, "detail") ? cfcatch.detail : "")>

            <cfif findNoCase("ORA-00001", errText) OR findNoCase("unique constraint", errText)>
                <cfreturn false>
            <cfelseif findNoCase("ORA-00942", errText) OR findNoCase("does not exist", errText)>
                <cflog type="warning" file="admin_notifications"
                       text="NOTIFICATION_REMINDER_LOG is missing; notifying without duplicate suppression. Apply assets/sql/add_notification_reminder_log.sql. #errText#">
                <cfreturn true>
            <cfelse>
                <cflog type="error" file="admin_notifications"
                       text="Notification claim failed for user #arguments.recipientUserId#: #errText#">
                <cfreturn false>
            </cfif>
        </cfcatch>
        </cftry>
    </cffunction>

    <!--- Create in-app notification for admin --->
    <cffunction name="createAdminNotification" access="private" returntype="numeric" output="false">
        <cfargument name="adminUserId" type="numeric" required="true">
        <cfargument name="type" type="string" required="true">
        <cfargument name="newUserCount" type="numeric" required="false" default="0">
        <cfargument name="reservationCount" type="numeric" required="false" default="0">
        <cfargument name="statusChangeCount" type="numeric" required="false" default="0">
        <cfargument name="userDetails" type="query" required="false">
        <cfargument name="reservationDetails" type="query" required="false">
        <cfargument name="statusChangeDetails" type="query" required="false">

        <cfset var notificationId = 0>
        <cfset var content = "">

        <cfswitch expression="#arguments.type#">
            <cfcase value="NEW_USER_REGISTERED">
                <cfset content = "#arguments.newUserCount# new user(s) registered in the system. Review and manage them in the admin dashboard.">
            </cfcase>

            <cfcase value="NEW_RESERVATION_REQUEST">
                <cfset content = "#arguments.reservationCount# new room reservation request(s) pending approval. Please review and approve or reject them.">
            </cfcase>

            <cfcase value="USER_STATUS_CHANGED">
                <cfset content = "#arguments.statusChangeCount# user status change(s) detected. #arguments.statusChangeCount# user(s) have been activated or deactivated.">
            </cfcase>
        </cfswitch>

        <cftry>
            <cfquery datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                INSERT INTO #this.DBSCHEMA#.NOTIFICATIONS
                (USER_ID, TYPE, CONTENT, STATUS, CREATED_AT)
                VALUES
                (<cfqueryparam value="#arguments.adminUserId#" cfsqltype="cf_sql_numeric">,
                 <cfqueryparam value="#arguments.type#" cfsqltype="cf_sql_varchar">,
                 <cfqueryparam value="#content#" cfsqltype="cf_sql_varchar">,
                 <cfqueryparam value="Unread" cfsqltype="cf_sql_varchar">,
                 CURRENT_TIMESTAMP)
            </cfquery>

            <cfquery name="result" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT LAST_NUMBER as notificationId FROM USER_SEQUENCES WHERE SEQUENCE_NAME = 'NOTIFICATIONS'
            </cfquery>

            <cfif isDefined('result.recordCount') AND result.recordCount GT 0>
                <cfset notificationId = result.notificationId>
            </cfif>

        <cfcatch>
            <cflog type="error" file="admin_notifications" text="Error creating notification: #cfcatch.message#">
        </cfcatch>
        </cftry>

        <cfreturn notificationId>
    </cffunction>

    <!--- Send email notification for new users --->
    <cffunction name="sendNewUserNotificationEmail" access="private" returntype="boolean" output="false">
        <cfargument name="adminEmail" type="string" required="true">
        <cfargument name="adminName" type="string" required="true">
        <cfargument name="newUsers" type="query" required="true">

        <cftry>
            <cfmail to="#arguments.adminEmail#"
                    from="roomreservation@mdanderson.org"
                    subject="Room Reservation System - New User Registrations"
                    type="html">
                <cfoutput>
                    <h2>New User Registration Alert</h2>
                    <p>Dear #arguments.adminName#,</p>
                    <p>The following #arguments.newUsers.recordCount# new user(s) have registered in the Room Reservation System:</p>

                    <table border="1" cellpadding="8" style="border-collapse: collapse; width: 100%;">
                        <tr style="background-color: ##f0f0f0; font-weight: bold;">
                            <td>Name</td>
                            <td>Email</td>
                            <td>Employee ID</td>
                            <td>Role</td>
                            <td>Registration Date</td>
                        </tr>
                        <cfloop query="arguments.newUsers">
                            <tr>
                                <td>#newUsers.FIRST_NAME# #newUsers.LAST_NAME#</td>
                                <td>#newUsers.EMAIL#</td>
                                <td>#newUsers.EMPLID ?: 'N/A'#</td>
                                <td>#newUsers.ROLE_NAME ?: 'User'#</td>
                                <td>#dateTimeFormat(newUsers.DATEENTERED, 'mm/dd/yyyy hh:nn tt')#</td>
                            </tr>
                        </cfloop>
                    </table>

                    <p><br />Please review these new users and manage their accounts as needed through the admin dashboard.</p>
                    <p>Regards,<br />Room Reservation System</p>
                </cfoutput>
            </cfmail>
            <cfreturn true>

        <cfcatch>
            <cflog type="error" file="admin_notifications" text="Error sending new user email: #cfcatch.message#">
            <cfreturn false>
        </cfcatch>
        </cftry>
    </cffunction>

    <!--- Send email notification for pending reservations --->
    <cffunction name="sendNewReservationNotificationEmail" access="private" returntype="boolean" output="false">
        <cfargument name="adminEmail" type="string" required="true">
        <cfargument name="adminName" type="string" required="true">
        <cfargument name="pendingReservations" type="query" required="true">

        <cftry>
            <cfmail to="#arguments.adminEmail#"
                    from="roomreservation@mdanderson.org"
                    subject="Room Reservation System - New Reservation Requests Pending Approval"
                    type="html">
                <cfoutput>
                    <h2>Pending Reservation Requests</h2>
                    <p>Dear #arguments.adminName#,</p>
                    <p>The following #arguments.pendingReservations.recordCount# room reservation request(s) are pending your approval:</p>

                    <table border="1" cellpadding="8" style="border-collapse: collapse; width: 100%;">
                        <tr style="background-color: ##f0f0f0; font-weight: bold;">
                            <td>Requester</td>
                            <td>Room</td>
                            <td>Location</td>
                            <td>Meeting Title</td>
                            <td>Date & Time</td>
                            <td>Duration</td>
                        </tr>
                        <cfloop query="arguments.pendingReservations">
                            <cfset startTime = dateTimeFormat(pendingReservations.START_TIME, 'mm/dd/yyyy hh:nn tt')>
                            <cfset endTime = dateTimeFormat(pendingReservations.END_TIME, 'hh:nn tt')>
                            <cfset duration = dateDiff('n', pendingReservations.START_TIME, pendingReservations.END_TIME)>
                            <cfset durationHours = int(duration / 60)>
                            <cfset durationMins = duration % 60>
                            <tr>
                                <td>#pendingReservations.FIRST_NAME# #pendingReservations.LAST_NAME#</td>
                                <td>#pendingReservations.ROOM_NAME#</td>
                                <td>#pendingReservations.BUILDING#-#pendingReservations.ROOM_NUMBER#</td>
                                <td>#pendingReservations.MEETING_TITLE ?: 'No Title'#</td>
                                <td>#startTime# to #endTime#</td>
                                <td>#durationHours# hrs #durationMins# mins</td>
                            </tr>
                        </cfloop>
                    </table>

                    <p><br />Please review and approve or reject these requests through the admin dashboard.</p>
                    <p>Regards,<br />Room Reservation System</p>
                </cfoutput>
            </cfmail>
            <cfreturn true>

        <cfcatch>
            <cflog type="error" file="admin_notifications" text="Error sending reservation email: #cfcatch.message#">
            <cfreturn false>
        </cfcatch>
        </cftry>
    </cffunction>

    <!--- Send email notification for user status changes --->
    <cffunction name="sendStatusChangeNotificationEmail" access="private" returntype="boolean" output="false">
        <cfargument name="adminEmail" type="string" required="true">
        <cfargument name="adminName" type="string" required="true">
        <cfargument name="statusChanges" type="query" required="true">

        <cftry>
            <cfmail to="#arguments.adminEmail#"
                    from="roomreservation@mdanderson.org"
                    subject="Room Reservation System - User Status Changes"
                    type="html">
                <cfoutput>
                    <h2>User Status Change Alert</h2>
                    <p>Dear #arguments.adminName#,</p>
                    <p>The following #arguments.statusChanges.recordCount# user status change(s) have been made:</p>

                    <table border="1" cellpadding="8" style="border-collapse: collapse; width: 100%;">
                        <tr style="background-color: ##f0f0f0; font-weight: bold;">
                            <td>User Name</td>
                            <td>Email</td>
                            <td>New Status</td>
                            <td>Change Type</td>
                            <td>Changed At</td>
                        </tr>
                        <cfloop query="arguments.statusChanges">
                            <!--- Hex colours must be escaped as ## inside cfoutput: a
                                  single # opens a CFML expression, so '#90EE90' was a
                                  COMPILE error ("90EE90 is not a valid identifier
                                  name"). That made this entire component unloadable —
                                  createObject() on it threw, so no scheduled run could
                                  ever have executed. --->
                            <cfset statusColor = statusChanges.STATUS EQ 'Active' ? '##90EE90' : '##FFB6C6'>
                            <tr>
                                <td>#statusChanges.FIRST_NAME# #statusChanges.LAST_NAME#</td>
                                <td>#statusChanges.EMAIL#</td>
                                <td style="background-color: #statusColor#;">#statusChanges.STATUS#</td>
                                <td>#statusChanges.STATUS_CHANGE#</td>
                                <td>#dateTimeFormat(statusChanges.DATEMODIFIED, 'mm/dd/yyyy hh:nn tt')#</td>
                            </tr>
                        </cfloop>
                    </table>

                    <p><br />Please review these changes and take any necessary action through the admin dashboard.</p>
                    <p>Regards,<br />Room Reservation System</p>
                </cfoutput>
            </cfmail>
            <cfreturn true>

        <cfcatch>
            <cflog type="error" file="admin_notifications" text="Error sending status change email: #cfcatch.message#">
            <cfreturn false>
        </cfcatch>
        </cftry>
    </cffunction>

</cfcomponent>
