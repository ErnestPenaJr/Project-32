<cfcomponent name="RRSNotificationEmails">
    <!--- Existing database configuration code remains the same --->
    <cfif ListFirst(CGI.SERVER_NAME,'.') EQ 'cmapps'>
        <cfset this.DBSERVER = "inside2_docmp" />
        <cfset this.DBUSER = "CONFROOM_USER" />
        <cfset this.DBPASS = "1docmD4OU6D88" />
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
                        from="conferenceroom@company.com"
                        subject="Reminder: Upcoming Room Booking in 1 Hour"
                        type="html">
                    <cfoutput>
                    <h3>Room Booking Reminder</h3>
                    <p>Hello #bookings.FIRST_NAME# #bookings.LAST_NAME#,</p>
                    <p>This is a reminder of your upcoming room booking:</p>
                    <ul>
                        <li>Room: #bookings.ROOM_NAME#</li>
                        <li>Location: #bookings.BUILDING#.#bookings.ROOM_NUMBER#</li>
                        <li>Date: #DateFormat(bookings.START_TIME, "dddd, mmmm dd, yyyy")#</li>
                        <li>Time: #TimeFormat(bookings.START_TIME, "hh:mm tt")# - #TimeFormat(bookings.END_TIME, "hh:mm tt")#</li>
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
</cfcomponent>