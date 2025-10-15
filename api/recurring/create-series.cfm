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
    <cfset userId = val(form.userId ?: url.userId ?: 0)>
    <cfset roomId = val(form.roomId ?: url.roomId ?: 0)>
    <cfset startTime = form.startTime ?: url.startTime ?: "">
    <cfset endTime = form.endTime ?: url.endTime ?: "">
    <cfset comments = form.comments ?: url.comments ?: "">
    <cfset frequency = form.frequency ?: url.frequency ?: "">
    <cfset intervalCount = val(form.intervalCount ?: url.intervalCount ?: 1)>
    <cfset endType = form.endType ?: url.endType ?: "">
    <cfset endDate = form.endDate ?: url.endDate ?: "">
    <cfset maxOccurrences = val(form.maxOccurrences ?: url.maxOccurrences ?: 0)>
    <cfset daysOfWeek = form.daysOfWeek ?: url.daysOfWeek ?: "">

    <!--- Validation ----->
    <cfif userId EQ 0>
        <cfset response = {
            success = false,
            message = "User ID is required"
        }>
        <cfoutput>#serializeJSON(response)#</cfoutput>
        <cfabort>
    </cfif>

    <cfif roomId EQ 0>
        <cfset response = {
            success = false,
            message = "Room ID is required"
        }>
        <cfoutput>#serializeJSON(response)#</cfoutput>
        <cfabort>
    </cfif>

    <cfif len(trim(startTime)) EQ 0 OR len(trim(endTime)) EQ 0>
        <cfset response = {
            success = false,
            message = "Start time and end time are required"
        }>
        <cfoutput>#serializeJSON(response)#</cfoutput>
        <cfabort>
    </cfif>

    <cfif len(trim(frequency)) EQ 0>
        <cfset response = {
            success = false,
            message = "Frequency is required"
        }>
        <cfoutput>#serializeJSON(response)#</cfoutput>
        <cfabort>
    </cfif>

    <!--- Check if room allows recurring bookings ----->
    <cfquery name="qCheckRoom" datasource="#DBSERVER#" username="#DBUSER#" password="#DBPASS#">
        SELECT RECURRING_ENABLED, ROOM_NAME
        FROM #DBSCHEMA#.ROOMS
        WHERE ROOM_ID = <cfqueryparam value="#roomId#" cfsqltype="cf_sql_numeric">
    </cfquery>

    <cfif qCheckRoom.recordCount EQ 0>
        <cfset response = {
            success = false,
            message = "Room not found"
        }>
        <cfoutput>#serializeJSON(response)#</cfoutput>
        <cfabort>
    </cfif>

    <cfif qCheckRoom.RECURRING_ENABLED NEQ 'Y'>
        <cfset response = {
            success = false,
            message = "Recurring bookings are not allowed for this room"
        }>
        <cfoutput>#serializeJSON(response)#</cfoutput>
        <cfabort>
    </cfif>

    <!--- Prepare booking data ----->
    <cfset bookingData = {
        userId = userId,
        roomId = roomId,
        startTime = startTime,
        endTime = endTime,
        comments = comments
    }>

    <!--- Prepare recurring pattern ----->
    <cfset pattern = {
        frequency = frequency,
        intervalCount = intervalCount,
        endType = endType
    }>

    <cfif endType EQ "DATE" AND len(trim(endDate)) GT 0>
        <cfset pattern.endDate = endDate>
    </cfif>

    <cfif endType EQ "OCCURRENCES" AND maxOccurrences GT 0>
        <cfset pattern.maxOccurrences = maxOccurrences>
    </cfif>

    <cfif frequency EQ "WEEKLY" AND len(trim(daysOfWeek)) GT 0>
        <cfset pattern.daysOfWeek = daysOfWeek>
    </cfif>

    <!--- Create recurring booking using component ----->
    <cfset recurringBooking = createObject("component", "components.RecurringBooking").init()>
    <cfset result = recurringBooking.createRecurringBooking(bookingData, pattern)>

    <!--- Send notifications for all created instances if successful ----->
    <cfif result.success AND result.instancesCreated GT 0>
        <cftry>
            <!--- Get user details ----->
            <cfquery name="qUser" datasource="#DBSERVER#" username="#DBUSER#" password="#DBPASS#">
                SELECT FIRST_NAME, LAST_NAME, EMAIL
                FROM #DBSCHEMA#.USERS
                WHERE USER_ID = <cfqueryparam value="#userId#" cfsqltype="cf_sql_numeric">
            </cfquery>

            <!--- Log successful creation ----->
            <cflog file="recurring-bookings"
                   text="Created recurring series: Parent ID #result.parentBookingId#, Instances: #result.instancesCreated#, User: #qUser.FIRST_NAME# #qUser.LAST_NAME#"
                   type="information">

            <!--- Send admin notification if system requires approval ----->
            <cfset settings = recurringBooking.getSystemSettings()>
            <cfif structKeyExists(settings, "RECURRING_REQUIRE_APPROVAL") AND settings.RECURRING_REQUIRE_APPROVAL>
                <!--- TODO: Send admin notification for recurring booking approval ----->
            </cfif>

        <cfcatch>
            <!--- Log but don't fail the booking ----->
            <cflog file="recurring-bookings"
                   text="Failed to send notifications for recurring series: #cfcatch.message#"
                   type="error">
        </cfcatch>
        </cftry>
    </cfif>

    <!--- Return result ----->
    <cfoutput>#serializeJSON(result)#</cfoutput>

<cfcatch>
    <cflog file="recurring-bookings" text="Error creating recurring series: #cfcatch.message# #cfcatch.detail#" type="error">
    <cfset response = {
        success = false,
        message = "Error creating recurring booking: " & cfcatch.message
    }>
    <cfoutput>#serializeJSON(response)#</cfoutput>
</cfcatch>
</cftry>
