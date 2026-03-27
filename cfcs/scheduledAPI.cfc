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
                WHERE b.STATUS = 'APPROVED'
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

        <cfquery name="qryCleanUp" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
            UPDATE #this.DBSCHEMA#.BOOKINGS
            SET STATUS = 'archived',
                APPROVED_BY = 0,
                COMMENTS = 'Auto-Archived: End time passed',
                UPDATED_AT = CURRENT_TIMESTAMP
            WHERE LOWER(STATUS) IN ('pending', 'approved', 'rejected')
                AND END_TIME < CURRENT_TIMESTAMP
        </cfquery>

        <cfset results = {}>
        <cfset results["status"] = "success">
        <cfset results["message"] = "Bookings cleaned up successfully">
        <!--- add cleanup resultes in to a log file with date--->
        <cflog text="Bookings cleaned up successfully at #now#" type="info" />


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
            <cfquery name="qryAdmins" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT
                    u.USER_ID,
                    u.EMAIL,
                    u.FIRST_NAME,
                    u.LAST_NAME
                FROM #this.DBSCHEMA#.USERS u
                JOIN #this.DBSCHEMA#.ROLES r ON u.ROLE_ID = r.ROLE_ID
                WHERE LOWER(r.ROLE_NAME) = 'admin'
                AND u.STATUS = 'Active'
            </cfquery>
            <cfreturn qryAdmins>
        <cfcatch>
            <cflog text="Database Error in getAdminEmails: #cfcatch.message# - #cfcatch.detail#" type="error" file="pending_reminders"/>
            <cfrethrow>
        </cfcatch>
        </cftry>
    </cffunction>

    <cffunction name="sendPendingRequestReminder" access="remote" returntype="struct" returnformat="JSON">
        <cftry>
            <cfset var results = {}>
            <cfset var pendingBookings = getPendingRequests()>

            <cfif pendingBookings.recordCount eq 0>
                <cfset results["status"] = "success">
                <cfset results["message"] = "No pending requests">
                <cfset results["pendingCount"] = 0>
                <cfset results["adminCount"] = 0>
                <cfset results["emailsSent"] = 0>
                <cfreturn results>
            </cfif>

            <cfset var adminList = getAdminEmails()>

            <cfif adminList.recordCount eq 0>
                <cfset results["status"] = "success">
                <cfset results["message"] = "No admin recipients">
                <cfset results["pendingCount"] = pendingBookings.recordCount>
                <cfset results["adminCount"] = 0>
                <cfset results["emailsSent"] = 0>
                <cfreturn results>
            </cfif>

            <cfset var reportTimestamp = DateFormat(now(), "mmmm dd, yyyy") & " at " & TimeFormat(now(), "h:mm:ss tt")>
            <cfset var emailsSent = 0>

            <cfloop query="adminList">
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
            </cfloop>

            <cfset results["status"] = "success">
            <cfset results["message"] = "Pending request reminder emails sent successfully">
            <cfset results["pendingCount"] = pendingBookings.recordCount>
            <cfset results["adminCount"] = adminList.recordCount>
            <cfset results["emailsSent"] = emailsSent>
            <cfreturn results>

        <cfcatch>
            <cflog text="Error in sendPendingRequestReminder: #cfcatch.message# - #cfcatch.detail#" type="error" file="pending_reminders"/>
            <cfreturn {
                "status": "error",
                "message": "Error sending pending request reminders: #cfcatch.message# - #cfcatch.detail#",
                "pendingCount": 0,
                "adminCount": 0,
                "emailsSent": 0
            }>
        </cfcatch>
        </cftry>
    </cffunction>

</cfcomponent>