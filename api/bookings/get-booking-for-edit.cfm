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
    <!--- Get parameters --->
    <cfset bookingId = val(url.bookingId ?: form.bookingId ?: 0)>
    <cfset userId = val(url.userId ?: form.userId ?: 0)>

    <cfif bookingId EQ 0>
        <cfset response = {
            success = false,
            message = "Booking ID is required"
        }>
        <cfoutput>#serializeJSON(response)#</cfoutput>
        <cfabort>
    </cfif>

    <cfif userId EQ 0>
        <cfset response = {
            success = false,
            message = "User ID is required"
        }>
        <cfoutput>#serializeJSON(response)#</cfoutput>
        <cfabort>
    </cfif>

    <!--- Get booking details with permission check --->
    <cfquery name="qGetBooking" datasource="#DBSERVER#" username="#DBUSER#" password="#DBPASS#">
        SELECT
            b.BOOKING_ID,
            b.USER_ID,
            b.ROOM_ID,
            TO_CHAR(b.START_TIME, 'YYYY-MM-DD HH24:MI') as START_TIME,
            TO_CHAR(b.END_TIME, 'YYYY-MM-DD HH24:MI') as END_TIME,
            b.COMMENTS,
            b.STATUS,
            b.REVISION_NUMBER,
            b.IS_MODIFIED,
            TO_CHAR(b.REVISION_DATE, 'YYYY-MM-DD HH24:MI:SS') as REVISION_DATE,
            b.MODIFIED_BY,
            u.FIRST_NAME || ' ' || u.LAST_NAME as REQUESTER_NAME,
            u.EMAIL,
            r.ROOM_NAME,
            r.BUILDING,
            r.ROOM_NUMBER,
            r.CAPACITY,
            currentUser.FIRST_NAME || ' ' || currentUser.LAST_NAME as CURRENT_USER_NAME,
            currentRole.ROLE_NAME as CURRENT_USER_ROLE
        FROM #DBSCHEMA#.BOOKINGS b
        JOIN #DBSCHEMA#.USERS u ON b.USER_ID = u.USER_ID
        JOIN #DBSCHEMA#.ROOMS r ON b.ROOM_ID = r.ROOM_ID
        JOIN #DBSCHEMA#.USERS currentUser ON currentUser.USER_ID = <cfqueryparam value="#userId#" cfsqltype="cf_sql_numeric">
        JOIN #DBSCHEMA#.ROLES currentRole ON currentUser.ROLE_ID = currentRole.ROLE_ID
        WHERE b.BOOKING_ID = <cfqueryparam value="#bookingId#" cfsqltype="cf_sql_numeric">
    </cfquery>

    <cfif qGetBooking.recordCount EQ 0>
        <cfset response = {
            success = false,
            message = "Booking not found"
        }>
        <cfoutput>#serializeJSON(response)#</cfoutput>
        <cfabort>
    </cfif>

    <!--- Check permissions --->
    <cfset isAdmin = (qGetBooking.CURRENT_USER_ROLE EQ 'Admin' OR qGetBooking.CURRENT_USER_ROLE EQ 'Site Admin')>
    <cfset isCreator = (qGetBooking.USER_ID EQ userId)>

    <cfif NOT isAdmin AND NOT isCreator>
        <cfset response = {
            success = false,
            message = "You do not have permission to edit this booking",
            canEdit = false
        }>
        <cfoutput>#serializeJSON(response)#</cfoutput>
        <cfabort>
    </cfif>

    <!--- Check if booking can be edited --->
    <cfset canEdit = true>
    <cfset editBlockReason = "">

    <!--- Cannot edit if already started --->
    <cfif parseDateTime(qGetBooking.START_TIME) LT now()>
        <cfset canEdit = false>
        <cfset editBlockReason = "Booking has already started">
    </cfif>

    <!--- Cannot edit if cancelled or rejected --->
    <cfif lCase(qGetBooking.STATUS) EQ 'cancelled' OR lCase(qGetBooking.STATUS) EQ 'rejected'>
        <cfset canEdit = false>
        <cfset editBlockReason = "Cannot edit cancelled or rejected bookings">
    </cfif>

    <!--- Get available rooms for the current time slot (if user wants to change room) --->
    <cfquery name="qAvailableRooms" datasource="#DBSERVER#" username="#DBUSER#" password="#DBPASS#">
        SELECT
            r.ROOM_ID,
            r.ROOM_NAME,
            r.BUILDING,
            r.ROOM_NUMBER,
            r.CAPACITY
        FROM #DBSCHEMA#.ROOMS r
        WHERE r.MAINTENANCE_STATUS != 'YES'
        ORDER BY r.ROOM_NAME
    </cfquery>

    <!--- Build available rooms array --->
    <cfset availableRooms = []>
    <cfloop query="qAvailableRooms">
        <cfset arrayAppend(availableRooms, {
            roomId = qAvailableRooms.ROOM_ID,
            roomName = qAvailableRooms.ROOM_NAME,
            building = qAvailableRooms.BUILDING,
            roomNumber = qAvailableRooms.ROOM_NUMBER,
            capacity = qAvailableRooms.CAPACITY,
            location = qAvailableRooms.BUILDING & "-" & qAvailableRooms.ROOM_NUMBER
        })>
    </cfloop>

    <!--- Return booking details with edit permission info --->
    <cfset response = {
        success = true,
        canEdit = canEdit,
        editBlockReason = editBlockReason,
        booking = {
            bookingId = qGetBooking.BOOKING_ID,
            userId = qGetBooking.USER_ID,
            roomId = qGetBooking.ROOM_ID,
            roomName = qGetBooking.ROOM_NAME,
            location = qGetBooking.BUILDING & "-" & qGetBooking.ROOM_NUMBER,
            startTime = qGetBooking.START_TIME,
            endTime = qGetBooking.END_TIME,
            comments = qGetBooking.COMMENTS,
            status = qGetBooking.STATUS,
            revisionNumber = qGetBooking.REVISION_NUMBER,
            isModified = qGetBooking.IS_MODIFIED,
            revisionDate = qGetBooking.REVISION_DATE,
            requesterName = qGetBooking.REQUESTER_NAME,
            requesterEmail = qGetBooking.EMAIL
        },
        availableRooms = availableRooms,
        userPermissions = {
            isAdmin = isAdmin,
            isCreator = isCreator
        }
    }>

    <cfoutput>#serializeJSON(response)#</cfoutput>

<cfcatch>
    <cflog file="booking-edit" text="Error getting booking for edit: #cfcatch.message# #cfcatch.detail#">
    <cfset response = {
        success = false,
        message = "Error retrieving booking details: " & cfcatch.message
    }>
    <cfoutput>#serializeJSON(response)#</cfoutput>
</cfcatch>
</cftry>
