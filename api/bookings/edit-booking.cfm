<cfif ListFirst(CGI.SERVER_NAME,'.') EQ 'cmapps'>
    <cfset DBSERVER = "inside2_docmp" />
    <cfset DBUSER = "CONFROOM_USER" />
    <cfset DBPASS = "1DOCMAU4CNFRM6" />
    <cfset DBSCHEMA = "CONFROOM" />
<cfelseif ListFirst(CGI.SERVER_NAME,'.') EQ 's-cmapps'>
    <cfset DBSERVER = "inside2_docms" />
    <cfset DBUSER = "CONFROOM" />
    <cfset DBPASS = "1DOCMOA4CNFRM3" />
    <cfset DBSCHEMA = "CONFROOM" />
<cfelse>
    <cfset DBSERVER = "inside2_docmd" />
    <cfset DBUSER = "CONFROOM" />
    <cfset DBPASS = "1DOCMOA4CNFRM3" />
    <cfset DBSCHEMA = "CONFROOM" />
</cfif>

<cfheader name="Content-Type" value="application/json">

<cftry>
    <!--- Get parameters from request --->
    <cfset bookingId = val(form.bookingId ?: url.bookingId ?: 0)>
    <cfset userId = val(form.userId ?: url.userId ?: 0)>
    <cfset roomId = val(form.roomId ?: url.roomId ?: 0)>
    <cfset startTime = form.startTime ?: url.startTime ?: "">
    <cfset endTime = form.endTime ?: url.endTime ?: "">
    <cfset comments = form.comments ?: url.comments ?: "">

    <!--- Validation --->
    <cfif bookingId EQ 0>
        <cfset response = {
            "success" = false,
            "message" = "Booking ID is required"
        }>
        <cfoutput>#serializeJSON(response)#</cfoutput>
        <cfabort>
    </cfif>

    <cfif userId EQ 0>
        <cfset response = {
            "success" = false,
            "message" = "User ID is required"
        }>
        <cfoutput>#serializeJSON(response)#</cfoutput>
        <cfabort>
    </cfif>

    <!--- Get existing booking details --->
    <cfquery name="qGetBooking" datasource="#DBSERVER#" username="#DBUSER#" password="#DBPASS#">
        SELECT
            b.BOOKING_ID,
            b.USER_ID,
            b.ROOM_ID,
            b.START_TIME,
            b.END_TIME,
            TO_CHAR(b.START_TIME, 'YYYY-MM-DD HH24:MI:SS') as START_TIME_STR,
            TO_CHAR(b.END_TIME, 'YYYY-MM-DD HH24:MI:SS') as END_TIME_STR,
            b.COMMENTS,
            b.STATUS,
            b.REVISION_NUMBER,
            u.FIRST_NAME,
            u.LAST_NAME,
            u.EMAIL,
            r.ROOM_NAME
        FROM #DBSCHEMA#.BOOKINGS b
        JOIN #DBSCHEMA#.USERS u ON b.USER_ID = u.USER_ID
        JOIN #DBSCHEMA#.ROOMS r ON b.ROOM_ID = r.ROOM_ID
        WHERE b.BOOKING_ID = <cfqueryparam value="#bookingId#" cfsqltype="cf_sql_numeric">
    </cfquery>

    <cfif qGetBooking.recordCount EQ 0>
        <cfset response = {
            "success" = false,
            "message" = "Booking not found"
        }>
        <cfoutput>#serializeJSON(response)#</cfoutput>
        <cfabort>
    </cfif>

    <!--- Check if user has permission to edit (creator or admin) --->
    <cfquery name="qCheckUser" datasource="#DBSERVER#" username="#DBUSER#" password="#DBPASS#">
        SELECT r.ROLE_NAME
        FROM #DBSCHEMA#.USERS u
        JOIN #DBSCHEMA#.ROLES r ON u.ROLE_ID = r.ROLE_ID
        WHERE u.USER_ID = <cfqueryparam value="#userId#" cfsqltype="cf_sql_numeric">
    </cfquery>

    <cfset isAdmin = (qCheckUser.ROLE_NAME EQ 'Admin' OR qCheckUser.ROLE_NAME EQ 'Site Admin')>
    <cfset isCreator = (qGetBooking.USER_ID EQ userId)>

    <cfif NOT isAdmin AND NOT isCreator>
        <cfset response = {
            "success" = false,
            "message" = "You do not have permission to edit this booking"
        }>
        <cfoutput>#serializeJSON(response)#</cfoutput>
        <cfabort>
    </cfif>

    <!--- Check if booking has already ended (cannot edit completed bookings) --->
    <!--- Use END_TIME instead of START_TIME to allow editing bookings that are currently in progress --->
    <cfset bookingEnd = parseDateTime(qGetBooking.END_TIME_STR)>

    <cfif dateCompare(bookingEnd, now()) LT 0>
        <cfset response = {
            "success" = false,
            "message" = "Cannot edit bookings that have already ended"
        }>
        <cfoutput>#serializeJSON(response)#</cfoutput>
        <cfabort>
    </cfif>

    <!--- Check if booking is cancelled or rejected --->
    <cfif lCase(qGetBooking.STATUS) EQ 'cancelled' OR lCase(qGetBooking.STATUS) EQ 'rejected'>
        <cfset response = {
            "success" = false,
            "message" = "Cannot edit cancelled or rejected bookings"
        }>
        <cfoutput>#serializeJSON(response)#</cfoutput>
        <cfabort>
    </cfif>

    <!--- Use provided values or keep existing ones --->
    <cfset newRoomId = roomId GT 0 ? roomId : qGetBooking.ROOM_ID>
    <cfset newStartTime = len(trim(startTime)) ? startTime : dateFormat(qGetBooking.START_TIME, "yyyy-mm-dd") & " " & timeFormat(qGetBooking.START_TIME, "HH:mm:ss")>
    <cfset newEndTime = len(trim(endTime)) ? endTime : dateFormat(qGetBooking.END_TIME, "yyyy-mm-dd") & " " & timeFormat(qGetBooking.END_TIME, "HH:mm:ss")>
    <cfset newComments = len(trim(comments)) ? comments : qGetBooking.COMMENTS>

    <!--- Check room availability for new time slot (if time/room changed) --->
    <cfif newRoomId NEQ qGetBooking.ROOM_ID OR newStartTime NEQ qGetBooking.START_TIME OR newEndTime NEQ qGetBooking.END_TIME>
        <cfquery name="qCheckConflict" datasource="#DBSERVER#" username="#DBUSER#" password="#DBPASS#">
            SELECT COUNT(*) as CONFLICT_COUNT
            FROM #DBSCHEMA#.BOOKINGS
            WHERE ROOM_ID = <cfqueryparam value="#newRoomId#" cfsqltype="cf_sql_numeric">
            AND BOOKING_ID != <cfqueryparam value="#bookingId#" cfsqltype="cf_sql_numeric">
            AND STATUS IN ('Pending', 'Approved', 'Confirmed')
            AND (
                (START_TIME < <cfqueryparam value="#newEndTime#" cfsqltype="cf_sql_timestamp">
                AND END_TIME > <cfqueryparam value="#newStartTime#" cfsqltype="cf_sql_timestamp">)
            )
        </cfquery>

        <cfif qCheckConflict.CONFLICT_COUNT GT 0>
            <cfset response = {
                "success" = false,
                "message" = "Room is not available for the selected time slot"
            }>
            <cfoutput>#serializeJSON(response)#</cfoutput>
            <cfabort>
        </cfif>
    </cfif>

    <!--- Update the booking --->
    <cfquery datasource="#DBSERVER#" username="#DBUSER#" password="#DBPASS#">
        UPDATE #DBSCHEMA#.BOOKINGS
        SET
            ROOM_ID = <cfqueryparam value="#newRoomId#" cfsqltype="cf_sql_numeric">,
            START_TIME = <cfqueryparam value="#newStartTime#" cfsqltype="cf_sql_timestamp">,
            END_TIME = <cfqueryparam value="#newEndTime#" cfsqltype="cf_sql_timestamp">,
            COMMENTS = <cfqueryparam value="#newComments#" cfsqltype="cf_sql_varchar">,
            IS_MODIFIED = 'Y',
            REVISION_NUMBER = <cfqueryparam value="#qGetBooking.REVISION_NUMBER + 1#" cfsqltype="cf_sql_numeric">,
            REVISION_DATE = CURRENT_TIMESTAMP,
            MODIFIED_BY = <cfqueryparam value="#userId#" cfsqltype="cf_sql_numeric">,
            UPDATED_AT = CURRENT_TIMESTAMP
        WHERE BOOKING_ID = <cfqueryparam value="#bookingId#" cfsqltype="cf_sql_numeric">
    </cfquery>

    <!--- Send revision notification email --->
    <cftry>
        <cfset emailService = createObject("component", "components.EmailService").init()>
        <cfset emailService.sendBookingRevisionNotification(bookingId)>
    <cfcatch>
        <!--- Log error but don't fail the update --->
        <cflog file="booking-edit" text="Failed to send revision notification: #cfcatch.message#">
    </cfcatch>
    </cftry>

    <!--- Return success response --->
    <cfset response = {
        "success" = true,
        "message" = "Booking updated successfully",
        "bookingId" = bookingId,
        "revisionNumber" = qGetBooking.REVISION_NUMBER + 1
    }>

    <cfoutput>#serializeJSON(response)#</cfoutput>

<cfcatch>
    <cflog file="booking-edit" text="Error editing booking: #cfcatch.message# #cfcatch.detail#">
    <cfset response = {
        "success" = false,
        "message" = "Error updating booking: " & cfcatch.message
    }>
    <cfoutput>#serializeJSON(response)#</cfoutput>
</cfcatch>
</cftry>
