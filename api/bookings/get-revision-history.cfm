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

    <!--- Validation --->
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

    <!--- Check if booking exists and user has permission to view --->
    <cfquery name="qCheckBooking" datasource="#DBSERVER#" username="#DBUSER#" password="#DBPASS#">
        SELECT
            b.BOOKING_ID,
            b.USER_ID,
            currentUser.ROLE_ID
        FROM #DBSCHEMA#.BOOKINGS b
        JOIN #DBSCHEMA#.USERS currentUser ON currentUser.USER_ID = <cfqueryparam value="#userId#" cfsqltype="cf_sql_numeric">
        WHERE b.BOOKING_ID = <cfqueryparam value="#bookingId#" cfsqltype="cf_sql_numeric">
    </cfquery>

    <cfif qCheckBooking.recordCount EQ 0>
        <cfset response = {
            success = false,
            message = "Booking not found"
        }>
        <cfoutput>#serializeJSON(response)#</cfoutput>
        <cfabort>
    </cfif>

    <!--- Check if user has permission (creator or admin) --->
    <cfquery name="qCheckRole" datasource="#DBSERVER#" username="#DBUSER#" password="#DBPASS#">
        SELECT r.ROLE_NAME
        FROM #DBSCHEMA#.ROLES r
        WHERE r.ROLE_ID = <cfqueryparam value="#qCheckBooking.ROLE_ID#" cfsqltype="cf_sql_numeric">
    </cfquery>

    <cfset isAdmin = (qCheckRole.ROLE_NAME EQ 'Admin' OR qCheckRole.ROLE_NAME EQ 'Site Admin')>
    <cfset isCreator = (qCheckBooking.USER_ID EQ userId)>

    <cfif NOT isAdmin AND NOT isCreator>
        <cfset response = {
            success = false,
            message = "You do not have permission to view this booking's revision history"
        }>
        <cfoutput>#serializeJSON(response)#</cfoutput>
        <cfabort>
    </cfif>

    <!--- Get revision history from BOOKING_REVISIONS table --->
    <cfquery name="qRevisions" datasource="#DBSERVER#" username="#DBUSER#" password="#DBPASS#">
        SELECT
            br.REVISION_ID,
            br.BOOKING_ID,
            br.REVISION_NUMBER,
            br.ROOM_ID,
            r.ROOM_NAME,
            r.BUILDING,
            r.ROOM_NUMBER,
            TO_CHAR(br.START_TIME, 'YYYY-MM-DD HH24:MI') as START_TIME,
            TO_CHAR(br.END_TIME, 'YYYY-MM-DD HH24:MI') as END_TIME,
            br.COMMENTS,
            br.MODIFIED_BY,
            u.FIRST_NAME || ' ' || u.LAST_NAME as MODIFIED_BY_NAME,
            TO_CHAR(br.REVISION_DATE, 'YYYY-MM-DD HH24:MI:SS') as REVISION_DATE,
            br.CHANGE_DESCRIPTION
        FROM #DBSCHEMA#.BOOKING_REVISIONS br
        LEFT JOIN #DBSCHEMA#.ROOMS r ON br.ROOM_ID = r.ROOM_ID
        LEFT JOIN #DBSCHEMA#.USERS u ON br.MODIFIED_BY = u.USER_ID
        WHERE br.BOOKING_ID = <cfqueryparam value="#bookingId#" cfsqltype="cf_sql_numeric">
        ORDER BY br.REVISION_NUMBER DESC
    </cfquery>

    <!--- If no revisions exist in BOOKING_REVISIONS, try to get current booking as baseline --->
    <cfif qRevisions.recordCount EQ 0>
        <cfquery name="qCurrentBooking" datasource="#DBSERVER#" username="#DBUSER#" password="#DBPASS#">
            SELECT
                b.BOOKING_ID,
                b.REVISION_NUMBER,
                b.ROOM_ID,
                r.ROOM_NAME,
                r.BUILDING,
                r.ROOM_NUMBER,
                TO_CHAR(b.START_TIME, 'YYYY-MM-DD HH24:MI') as START_TIME,
                TO_CHAR(b.END_TIME, 'YYYY-MM-DD HH24:MI') as END_TIME,
                b.COMMENTS,
                b.MODIFIED_BY,
                u.FIRST_NAME || ' ' || u.LAST_NAME as MODIFIED_BY_NAME,
                TO_CHAR(b.REVISION_DATE, 'YYYY-MM-DD HH24:MI:SS') as REVISION_DATE,
                b.IS_MODIFIED
            FROM #DBSCHEMA#.BOOKINGS b
            LEFT JOIN #DBSCHEMA#.ROOMS r ON b.ROOM_ID = r.ROOM_ID
            LEFT JOIN #DBSCHEMA#.USERS u ON b.MODIFIED_BY = u.USER_ID
            WHERE b.BOOKING_ID = <cfqueryparam value="#bookingId#" cfsqltype="cf_sql_numeric">
        </cfquery>

        <!--- If booking has been modified but no revision history, return current state --->
        <cfif qCurrentBooking.recordCount GT 0 AND qCurrentBooking.IS_MODIFIED EQ 'Y'>
            <cfset revisions = []>
            <cfset arrayAppend(revisions, {
                revisionNumber = qCurrentBooking.REVISION_NUMBER,
                roomName = qCurrentBooking.ROOM_NAME,
                location = qCurrentBooking.BUILDING & "-" & qCurrentBooking.ROOM_NUMBER,
                startTime = qCurrentBooking.START_TIME,
                endTime = qCurrentBooking.END_TIME,
                comments = qCurrentBooking.COMMENTS,
                modifiedBy = qCurrentBooking.MODIFIED_BY_NAME ?: "Unknown",
                revisionDate = qCurrentBooking.REVISION_DATE ?: "N/A"
            })>

            <cfset response = {
                success = true,
                revisions = revisions
            }>
        <cfelse>
            <!--- No revisions at all --->
            <cfset response = {
                success = false,
                message = "No revision history available for this booking"
            }>
        </cfif>
    <cfelse>
        <!--- Build revisions array from query results --->
        <cfset revisions = []>
        <cfloop query="qRevisions">
            <cfset arrayAppend(revisions, {
                revisionNumber = qRevisions.REVISION_NUMBER,
                roomName = qRevisions.ROOM_NAME,
                location = qRevisions.BUILDING & "-" & qRevisions.ROOM_NUMBER,
                startTime = qRevisions.START_TIME,
                endTime = qRevisions.END_TIME,
                comments = qRevisions.COMMENTS,
                modifiedBy = qRevisions.MODIFIED_BY_NAME,
                revisionDate = qRevisions.REVISION_DATE,
                changeDescription = qRevisions.CHANGE_DESCRIPTION ?: ""
            })>
        </cfloop>

        <cfset response = {
            success = true,
            revisions = revisions
        }>
    </cfif>

    <cfoutput>#serializeJSON(response)#</cfoutput>

<cfcatch>
    <cflog file="booking-revision-history" text="Error getting revision history: #cfcatch.message# #cfcatch.detail#">
    <cfset response = {
        success = false,
        message = "Error retrieving revision history: " & cfcatch.message
    }>
    <cfoutput>#serializeJSON(response)#</cfoutput>
</cfcatch>
</cftry>
