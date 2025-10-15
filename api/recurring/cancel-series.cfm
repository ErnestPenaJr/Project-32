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
    <!--- Get parameters ----->
    <cfset parentBookingId = val(form.parentBookingId ?: url.parentBookingId ?: 0)>
    <cfset userId = val(form.userId ?: url.userId ?: 0)>

    <!--- Validation ----->
    <cfif parentBookingId EQ 0>
        <cfset response = {
            success = false,
            message = "Parent Booking ID is required"
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

    <!--- Verify user has permission to cancel ----->
    <cfquery name="qCheckPermission" datasource="#DBSERVER#" username="#DBUSER#" password="#DBPASS#">
        SELECT
            b.USER_ID,
            u.FIRST_NAME,
            u.LAST_NAME,
            r.ROLE_NAME
        FROM #DBSCHEMA#.BOOKINGS b
        JOIN #DBSCHEMA#.USERS u ON b.USER_ID = u.USER_ID
        JOIN #DBSCHEMA#.USERS currentUser ON currentUser.USER_ID = <cfqueryparam value="#userId#" cfsqltype="cf_sql_numeric">
        JOIN #DBSCHEMA#.ROLES r ON currentUser.ROLE_ID = r.ROLE_ID
        WHERE b.BOOKING_ID = <cfqueryparam value="#parentBookingId#" cfsqltype="cf_sql_numeric">
    </cfquery>

    <cfif qCheckPermission.recordCount EQ 0>
        <cfset response = {
            success = false,
            message = "Booking not found"
        }>
        <cfoutput>#serializeJSON(response)#</cfoutput>
        <cfabort>
    </cfif>

    <cfset isAdmin = (qCheckPermission.ROLE_NAME EQ 'Admin' OR qCheckPermission.ROLE_NAME EQ 'Site Admin')>
    <cfset isCreator = (qCheckPermission.USER_ID EQ userId)>

    <cfif NOT isAdmin AND NOT isCreator>
        <cfset response = {
            success = false,
            message = "You do not have permission to cancel this recurring series"
        }>
        <cfoutput>#serializeJSON(response)#</cfoutput>
        <cfabort>
    </cfif>

    <!--- Cancel the recurring series ----->
    <cfset recurringBooking = createObject("component", "components.RecurringBooking").init()>
    <cfset result = recurringBooking.cancelRecurringSeries(parentBookingId, userId)>

    <!--- Log the cancellation ----->
    <cfif result.success>
        <cflog file="recurring-bookings"
               text="Cancelled recurring series: Parent ID #parentBookingId#, Cancelled: #result.cancelled#, User: #userId#"
               type="information">
    </cfif>

    <!--- Return result ----->
    <cfoutput>#serializeJSON(result)#</cfoutput>

<cfcatch>
    <cflog file="recurring-bookings" text="Error cancelling recurring series: #cfcatch.message# #cfcatch.detail#" type="error">
    <cfset response = {
        success = false,
        message = "Error cancelling recurring series: " & cfcatch.message
    }>
    <cfoutput>#serializeJSON(response)#</cfoutput>
</cfcatch>
</cftry>
