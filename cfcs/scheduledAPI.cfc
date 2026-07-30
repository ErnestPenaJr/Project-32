<cfcomponent name="RRSNotificationEmails">
    <!--- Existing database configuration code remains the same --->
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

    <cffunction name="getUpcomingBookings" access="private" returntype="query">
        <cftry>
            <cfquery name="qryUpcoming" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT 
                    b.BOOKING_ID,
                    b.START_TIME,
                    b.END_TIME,
                    u.FIRST_NAME,
                    u.LAST_NAME,
                    u.EMAIL,
                    r.ROOM_NAME,
                    r.BUILDING,
                    r.ROOM_NUMBER
                FROM #this.DBSCHEMA#.BOOKINGS b
                INNER JOIN #this.DBSCHEMA#.USERS u 
                    ON b.USER_ID = u.USER_ID
                INNER JOIN #this.DBSCHEMA#.ROOMS r 
                    ON b.ROOM_ID = r.ROOM_ID
                <!--- CHK_BOOKINGS_STATUS permits lowercase only. 'APPROVED'
                     matched nothing, so this upcoming-booking reminder never
                     selected a single row for anyone. --->
                WHERE LOWER(b.STATUS) = 'approved'
                AND b.START_TIME BETWEEN 
                    SYSTIMESTAMP + INTERVAL '1' HOUR 
                    AND SYSTIMESTAMP + INTERVAL '2' HOUR
            </cfquery>
            <cfreturn qryUpcoming>
            
        <cfcatch>
            <cflog text="Database Error in getUpcomingBookings: #cfcatch.message# - #cfcatch.detail#" type="error" file="reminder_emails"/>
            <cfrethrow>
        </cfcatch>
        </cftry>
    </cffunction>

    <cffunction name="sendReminderEmail" access="remote" returntype="struct" returnformat="JSON">
        <cftry>
            <cfset var results = {}>
            <cfset var bookings = getUpcomingBookings()>
            
            <cfif bookings.recordCount eq 0>
                <cfset results["status"] = "success">
                <cfset results["message"] = "No upcoming bookings requiring reminders">
                <cfreturn results>
            </cfif>
            
            <cfloop query="bookings">
                <cfmail to="#bookings.EMAIL#"
                        from="NO-REPLY@MDANDERSON.ORG"
                        subject="Reminder: Upcoming Room Booking in 1 Hour"
                        type="html">
                    <cfoutput>
                    <h3>Room Booking Reminder</h3>
                    <p>Hello #bookings.FIRST_NAME# #bookings.LAST_NAME#,</p>
                    <p>This is a reminder of your upcoming room booking:</p>
                    <ul>
                        <li>Room: #bookings.ROOM_NAME#</li>
                        <li>Location: #bookings.BUILDING#.#bookings.ROOM_NUMBER#</li>
                        <li>Date: #DateFormat(parseDateTime(bookings.START_TIME), "dddd, mmmm dd, yyyy")#</li>
                        <li>Time: #TimeFormat(parseDateTime(bookings.START_TIME), "hh:mm tt")# - #TimeFormat(parseDateTime(bookings.END_TIME), "hh:mm tt")#</li>
                    </ul>
                    </cfoutput>
                </cfmail>
            </cfloop>
            
            <cfset results["status"] = "success">
            <cfset results["message"] = "Reminder emails sent successfully">
            <cfreturn results>
            
        <cfcatch>
            <cflog text="Error in sendReminderEmail: #cfcatch.message# - #cfcatch.detail#" type="error" file="reminder_emails"/>
            <cfreturn {
                "status": "error",
                "message": "Error sending reminder emails: #cfcatch.message# - #cfcatch.detail#"
            }>
        </cfcatch>
        </cftry>
    </cffunction>


    <cffunction name="CalendarCleanUp" access="remote" returntype="any" returnformat="JSON" output="false">

        <!--- Archiving changes the status and nothing else.
              This previously also wrote:
                APPROVED_BY = 0  -- there is no USER_ID 0, so every archived row
                                    was left holding an orphaned user reference
                                    (19 such rows found in dev) and the identity of
                                    the actual approver was destroyed. It only went
                                    unnoticed because APPROVED_BY has no foreign
                                    key; adding one would make this job fail.
                COMMENTS = 'Auto-Archived: End time passed'
                                 -- which destroyed the requester's meeting purpose
                                    on every booking it touched. Same data loss as
                                    the old cancelBooking, still happening here.
              Neither is needed to archive a past booking. --->
        <cfquery name="qryCleanUp" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#" result="cleanUpResult">
            UPDATE #this.DBSCHEMA#.BOOKINGS
            SET STATUS = 'archived',
                UPDATED_AT = CURRENT_TIMESTAMP
            WHERE LOWER(STATUS) IN ('pending', 'approved', 'rejected')
                AND END_TIME < CURRENT_TIMESTAMP
        </cfquery>

        <cfset var archivedCount = structKeyExists(cleanUpResult, "recordCount") ? cleanUpResult.recordCount : 0>

        <cfset results = {}>
        <cfset results["status"] = "success">
        <cfset results["message"] = "Archived #archivedCount# past booking(s)">
        <cfset results["archivedCount"] = archivedCount>
        <!--- `#now#` referenced the function without parentheses, which raises
              "Variable NOW is undefined" -- after the UPDATE had already
              committed, so the job silently reported failure while having done its
              work. Also logs how many rows were touched, which it never did. --->
        <cflog file="calendar_cleanup" type="information"
               text="CalendarCleanUp archived #archivedCount# past booking(s) at #dateTimeFormat(now(), 'yyyy-mm-dd HH:nn:ss')#" />


        <cfreturn results>

    </cffunction>

    <cffunction name="getPendingRequests" access="private" returntype="query">
        <cftry>
            <cfquery name="qryPending" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT
                    b.BOOKING_ID,
                    b.START_TIME,
                    b.END_TIME,
                    b.CREATED_AT,
                    b.COMMENTS,
                    r.ROOM_NAME,
                    r.BUILDING,
                    r.ROOM_NUMBER,
                    u.FIRST_NAME,
                    u.LAST_NAME,
                    u.EMAIL
                FROM #this.DBSCHEMA#.BOOKINGS b
                INNER JOIN #this.DBSCHEMA#.USERS u
                    ON b.USER_ID = u.USER_ID
                INNER JOIN #this.DBSCHEMA#.ROOMS r
                    ON b.ROOM_ID = r.ROOM_ID
                WHERE LOWER(b.STATUS) = 'pending'
                ORDER BY b.CREATED_AT ASC
            </cfquery>
            <cfreturn qryPending>
        <cfcatch>
            <cflog text="Database Error in getPendingRequests: #cfcatch.message# - #cfcatch.detail#" type="error" file="pending_reminders"/>
            <cfrethrow>
        </cfcatch>
        </cftry>
    </cffunction>

    <cffunction name="getAdminEmails" access="private" returntype="query">
        <cftry>
            <!--- Recipients are Admin *and* Site Admin.
                  This previously filtered LOWER(r.ROLE_NAME) = 'admin' exactly,
                  which silently excluded every Site Admin. Where all
                  administrators hold the Site Admin role the reminder resolved
                  zero recipients and mailed nobody, while still reporting
                  success. The role set here now matches
                  ApprovalNotification.getApprovalRecipients(), so the immediate
                  alert and the reminder agree on who an approver is.

                  STATUS is compared case-insensitively for the same reason. --->
            <cfquery name="qryAdmins" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT
                    u.USER_ID,
                    u.EMAIL,
                    u.FIRST_NAME,
                    u.LAST_NAME,
                    r.ROLE_NAME
                FROM #this.DBSCHEMA#.USERS u
                JOIN #this.DBSCHEMA#.ROLES r ON u.ROLE_ID = r.ROLE_ID
                WHERE UPPER(TRIM(r.ROLE_NAME)) IN ('ADMIN', 'SITE ADMIN')
                AND UPPER(u.STATUS) = 'ACTIVE'
                AND u.EMAIL IS NOT NULL
            </cfquery>
            <cfreturn qryAdmins>
        <cfcatch>
            <cflog text="Database Error in getAdminEmails: #cfcatch.message# - #cfcatch.detail#" type="error" file="pending_reminders"/>
            <cfrethrow>
        </cfcatch>
        </cftry>
    </cffunction>

    <!---
        Reminder bucket for duplicate suppression.

        Derived from the DATABASE clock, not the application server's: several
        scheduler instances may run on hosts with skewed clocks, and they must
        agree on which interval a send belongs to or the unique constraint in
        NOTIFICATION_REMINDER_LOG will not suppress anything.

        Requirement 4 asks that times use "the application's configured time
        zone". This application has no configured time zone anywhere, so the
        database session time zone is used as the single authority and documented
        as such. Flagged for confirmation in the progress checklist.
    --->
    <cffunction name="getReminderIntervalKey" access="private" returntype="string" output="false">
        <cfargument name="granularity" type="string" required="false" default="HOUR">

        <cfset var qKey = "">
        <cfset var mask = arguments.granularity EQ "DAY" ? "YYYY-MM-DD" : "YYYY-MM-DD HH24">

        <cfquery name="qKey" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
            SELECT TO_CHAR(SYSTIMESTAMP, <cfqueryparam value="#mask#" cfsqltype="cf_sql_varchar">) AS INTERVAL_KEY
            FROM DUAL
        </cfquery>

        <cfreturn qKey.INTERVAL_KEY>
    </cffunction>

    <!---
        Claim the right to notify one recipient for one interval.

        Returns true only if this caller won the claim. The unique constraint
        UQ_REMINDER_ONCE_PER_INTERVAL makes this atomic across processes, so when
        two scheduler runs overlap exactly one of them sends. A duplicate-key
        error is the expected, healthy "someone else has this" signal -- not an
        error condition.

        If the log table is missing the claim is refused-open (returns true) so
        reminders keep flowing; that is logged, and the trade-off is documented in
        assets/sql/add_notification_reminder_log.sql.
    --->
    <cffunction name="claimReminderSlot" access="private" returntype="struct" output="false">
        <cfargument name="recipientUserId" type="numeric" required="true">
        <cfargument name="notificationType" type="string" required="true">
        <cfargument name="intervalKey" type="string" required="true">
        <cfargument name="pendingCount" type="numeric" required="false" default="0">

        <cfset var result = { "claimed" = false, "logId" = 0, "reason" = "" }>
        <cfset var qLog = "">

        <cftry>
            <cfquery datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                INSERT INTO #this.DBSCHEMA#.NOTIFICATION_REMINDER_LOG
                    (RECIPIENT_USER_ID, NOTIFICATION_TYPE, INTERVAL_KEY, PENDING_COUNT, DELIVERY_STATUS, CLAIMED_AT)
                VALUES (
                    <cfqueryparam value="#arguments.recipientUserId#" cfsqltype="cf_sql_numeric">,
                    <cfqueryparam value="#arguments.notificationType#" cfsqltype="cf_sql_varchar">,
                    <cfqueryparam value="#arguments.intervalKey#" cfsqltype="cf_sql_varchar">,
                    <cfqueryparam value="#arguments.pendingCount#" cfsqltype="cf_sql_numeric">,
                    'PENDING',
                    CURRENT_TIMESTAMP
                )
            </cfquery>

            <cfquery name="qLog" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT LOG_ID FROM #this.DBSCHEMA#.NOTIFICATION_REMINDER_LOG
                WHERE RECIPIENT_USER_ID = <cfqueryparam value="#arguments.recipientUserId#" cfsqltype="cf_sql_numeric">
                  AND NOTIFICATION_TYPE = <cfqueryparam value="#arguments.notificationType#" cfsqltype="cf_sql_varchar">
                  AND INTERVAL_KEY = <cfqueryparam value="#arguments.intervalKey#" cfsqltype="cf_sql_varchar">
            </cfquery>

            <cfset result.claimed = true>
            <cfset result.logId = qLog.LOG_ID>

        <cfcatch>
            <!--- ColdFusion reports "Error Executing Database Query." as the
                  message and puts the ORA- text in detail, so both must be
                  inspected. Matching only on message silently misclassified an
                  expected duplicate as an unexpected failure. --->
            <cfset var errText = cfcatch.message & " " & (structKeyExists(cfcatch, "detail") ? cfcatch.detail : "")>

            <cfif findNoCase("ORA-00001", errText) OR findNoCase("unique constraint", errText)>
                <!--- Expected: another run already owns this interval. --->
                <cfset result.reason = "already sent this interval">
            <cfelseif findNoCase("ORA-00942", errText) OR findNoCase("does not exist", errText)>
                <!--- Table not deployed: keep reminders working, without suppression. --->
                <cflog type="warning" file="pending_reminders"
                       text="NOTIFICATION_REMINDER_LOG is missing; sending without duplicate suppression. Apply assets/sql/add_notification_reminder_log.sql. #errText#">
                <cfset result.claimed = true>
                <cfset result.reason = "log table absent">
            <cfelse>
                <cflog type="error" file="pending_reminders"
                       text="Reminder claim failed for user #arguments.recipientUserId# interval #arguments.intervalKey#: #errText#">
                <cfset result.reason = cfcatch.message>
            </cfif>
        </cfcatch>
        </cftry>

        <cfreturn result>
    </cffunction>

    <!--- Record the outcome of a claimed slot so failures can be found and retried. --->
    <cffunction name="recordReminderOutcome" access="private" returntype="void" output="false">
        <cfargument name="logId" type="numeric" required="true">
        <cfargument name="status" type="string" required="true">
        <cfargument name="failureDetail" type="string" required="false" default="">

        <cfif arguments.logId LTE 0>
            <cfreturn>
        </cfif>

        <cftry>
            <cfquery datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                UPDATE #this.DBSCHEMA#.NOTIFICATION_REMINDER_LOG
                SET DELIVERY_STATUS = <cfqueryparam value="#arguments.status#" cfsqltype="cf_sql_varchar">,
                    FAILURE_DETAIL = <cfqueryparam value="#left(arguments.failureDetail, 1000)#" cfsqltype="cf_sql_varchar" null="#!len(trim(arguments.failureDetail))#">,
                    SENT_AT = CASE WHEN <cfqueryparam value="#arguments.status#" cfsqltype="cf_sql_varchar"> = 'SENT'
                                   THEN CURRENT_TIMESTAMP ELSE SENT_AT END
                WHERE LOG_ID = <cfqueryparam value="#arguments.logId#" cfsqltype="cf_sql_numeric">
            </cfquery>
        <cfcatch>
            <cflog type="error" file="pending_reminders"
                   text="Could not record reminder outcome for log #arguments.logId#: #cfcatch.message#">
        </cfcatch>
        </cftry>
    </cffunction>

    <cffunction name="sendPendingRequestReminder" access="remote" returntype="struct" returnformat="JSON">
        <cftry>
            <cfset var results = {}>
            <cfset var pendingBookings = getPendingRequests()>

            <!--- Resolved requests are excluded by getPendingRequests(), so an
                  approved, rejected or cancelled request stops generating
                  reminders on the very next run with no extra bookkeeping. --->
            <cfif pendingBookings.recordCount eq 0>
                <cfset results["status"] = "success">
                <cfset results["message"] = "No pending requests">
                <cfset results["pendingCount"] = 0>
                <cfset results["adminCount"] = 0>
                <cfset results["emailsSent"] = 0>
                <cfset results["skippedDuplicates"] = 0>
                <cfset results["failed"] = 0>
                <cfreturn results>
            </cfif>

            <cfset var adminList = getAdminEmails()>

            <cfif adminList.recordCount eq 0>
                <!--- Recipients could not be determined. Surface it rather than
                      reporting a quiet success. --->
                <cflog type="warning" file="pending_reminders"
                       text="#pendingBookings.recordCount# request(s) are pending but no active administrator could be resolved as a recipient.">
                <cfset results["status"] = "success">
                <cfset results["message"] = "No admin recipients">
                <cfset results["pendingCount"] = pendingBookings.recordCount>
                <cfset results["adminCount"] = 0>
                <cfset results["emailsSent"] = 0>
                <cfset results["skippedDuplicates"] = 0>
                <cfset results["failed"] = 0>
                <cfreturn results>
            </cfif>

            <cfset var reportTimestamp = DateFormat(now(), "mmmm dd, yyyy") & " at " & TimeFormat(now(), "h:mm:ss tt")>
            <cfset var emailsSent = 0>
            <cfset var skippedDuplicates = 0>
            <cfset var failedSends = 0>
            <cfset var intervalKey = getReminderIntervalKey("HOUR")>
            <cfset var claim = "">
            <cfset var currentLogId = 0>

            <cfloop query="adminList">
                <!--- One recipient's failure must not stop the others. --->
                <cftry>
                <cfset claim = claimReminderSlot(
                    recipientUserId = adminList.USER_ID,
                    notificationType = "PENDING_REQUEST_REMINDER",
                    intervalKey = intervalKey,
                    pendingCount = pendingBookings.recordCount
                )>

                <cfif NOT claim.claimed>
                    <cfset skippedDuplicates++>
                    <cfcontinue>
                </cfif>

                <cfset currentLogId = claim.logId>
                <cfmail to="#adminList.EMAIL#"
                        from="no-reply@mdanderson.org"
                        subject="Action Required: #pendingBookings.recordCount# Pending Room Reservation Request(s)"
                        type="html">
                    <cfoutput>
                    <!DOCTYPE html>
                    <html>
                    <head>
                        <style>
                            body { font-family: Arial, sans-serif; color: ##333333; margin: 0; padding: 0; }
                            .email-container { max-width: 700px; margin: 0 auto; }
                            .header { background-color: ##003C7F; color: ##ffffff; padding: 20px; text-align: center; }
                            .header h1 { margin: 0; font-size: 20px; }
                            .content { padding: 20px; }
                            .disclaimer-box { background-color: ##FFF8E1; border: 1px solid ##FFD54F; border-radius: 4px; padding: 12px 16px; margin-bottom: 20px; font-size: 13px; color: ##5D4037; }
                            .disclaimer-box strong { color: ##E65100; }
                            table.requests { width: 100%; border-collapse: collapse; margin-top: 10px; font-size: 13px; }
                            table.requests th { background-color: ##003C7F; color: ##ffffff; padding: 8px 10px; text-align: left; }
                            table.requests td { padding: 8px 10px; border-bottom: 1px solid ##dddddd; }
                            table.requests tr:nth-child(even) { background-color: ##f9f9f9; }
                            .footer { padding: 15px 20px; font-size: 12px; color: ##777777; border-top: 1px solid ##dddddd; margin-top: 20px; }
                        </style>
                    </head>
                    <body>
                        <div class="email-container">
                            <div class="header">
                                <h1>Pending Booking Requests Requiring Your Attention</h1>
                            </div>
                            <div class="content">
                                <p>Hello #adminList.FIRST_NAME#,</p>
                                <p>There are currently <strong>#pendingBookings.recordCount#</strong> pending booking request(s) awaiting review.</p>

                                <div class="disclaimer-box">
                                    <strong>Please Note:</strong> This report was generated on <strong>#reportTimestamp#</strong>.
                                    Some requests listed below may have already been approved or processed by another administrator.
                                    If a request is no longer in the pending queue when you review it, it has been handled.
                                </div>

                                <table class="requests">
                                    <thead>
                                        <tr>
                                            <th>ID</th>
                                            <th>Requester</th>
                                            <th>Room</th>
                                            <th>Requested Date/Time</th>
                                            <th>Submitted</th>
                                            <th>Age (hrs)</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        <cfloop query="pendingBookings">
                                            <cfset var ageHours = Round(DateDiff("h", parseDateTime(pendingBookings.CREATED_AT), now()))>
                                            <tr>
                                                <td>#pendingBookings.BOOKING_ID#</td>
                                                <td>#pendingBookings.FIRST_NAME# #pendingBookings.LAST_NAME#</td>
                                                <td>#pendingBookings.ROOM_NAME# (#pendingBookings.BUILDING#.#pendingBookings.ROOM_NUMBER#)</td>
                                                <td>#DateFormat(parseDateTime(pendingBookings.START_TIME), "mm/dd/yyyy")# #TimeFormat(parseDateTime(pendingBookings.START_TIME), "hh:mm tt")# - #TimeFormat(parseDateTime(pendingBookings.END_TIME), "hh:mm tt")#</td>
                                                <td>#DateFormat(parseDateTime(pendingBookings.CREATED_AT), "mm/dd/yyyy")# #TimeFormat(parseDateTime(pendingBookings.CREATED_AT), "hh:mm tt")#</td>
                                                <td>#ageHours#</td>
                                            </tr>
                                        </cfloop>
                                    </tbody>
                                </table>
                            </div>
                            <div class="footer">
                                You are receiving this email because you are an administrator of the DoCM Room Reservation System.
                            </div>
                        </div>
                    </body>
                    </html>
                    </cfoutput>
                </cfmail>
                <cfset emailsSent = emailsSent + 1>
                <cfset recordReminderOutcome(logId = currentLogId, status = "SENT")>

                <cfcatch>
                    <!--- Leave the row FAILED with detail so it can be found and
                          retried; the claim row itself stays, so a retry within
                          the same interval is still suppressed until an operator
                          clears or re-runs it deliberately. --->
                    <cfset failedSends++>
                    <cflog type="error" file="pending_reminders"
                           text="Reminder to admin #adminList.USER_ID# (#adminList.EMAIL#) failed for interval #intervalKey#: #cfcatch.message# #cfcatch.detail#">
                    <cfset recordReminderOutcome(
                        logId = currentLogId,
                        status = "FAILED",
                        failureDetail = cfcatch.message & " " & cfcatch.detail
                    )>
                </cfcatch>
                </cftry>
            </cfloop>

            <cfset results["status"] = "success">
            <cfset results["message"] = "Reminder run complete: #emailsSent# sent, #skippedDuplicates# already sent this interval, #failedSends# failed.">
            <cfset results["pendingCount"] = pendingBookings.recordCount>
            <cfset results["adminCount"] = adminList.recordCount>
            <cfset results["emailsSent"] = emailsSent>
            <cfset results["skippedDuplicates"] = skippedDuplicates>
            <cfset results["failed"] = failedSends>
            <cfset results["intervalKey"] = intervalKey>
            <cfreturn results>

        <cfcatch>
            <cflog text="Error in sendPendingRequestReminder: #cfcatch.message# - #cfcatch.detail#" type="error" file="pending_reminders"/>
            <cfreturn {
                "status": "error",
                "message": "Error sending pending request reminders: #cfcatch.message# - #cfcatch.detail#",
                "pendingCount": 0,
                "adminCount": 0,
                "emailsSent": 0,
                "skippedDuplicates": 0,
                "failed": 0
            }>
        </cfcatch>
        </cftry>
    </cffunction>

</cfcomponent>