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

    <!--- Get recurring pattern information ----->
    <cfquery name="qPattern" datasource="#DBSERVER#" username="#DBUSER#" password="#DBPASS#">
        SELECT
            rp.PATTERN_ID,
            rp.FREQUENCY,
            rp.INTERVAL_COUNT,
            rp.END_TYPE,
            TO_CHAR(rp.END_DATE, 'YYYY-MM-DD') as END_DATE,
            rp.MAX_OCCURRENCES,
            rp.DAYS_OF_WEEK,
            TO_CHAR(rp.CREATED_AT, 'YYYY-MM-DD HH24:MI:SS') as CREATED_AT
        FROM #DBSCHEMA#.RECURRING_PATTERNS rp
        WHERE rp.PARENT_BOOKING_ID = <cfqueryparam value="#parentBookingId#" cfsqltype="cf_sql_numeric">
    </cfquery>

    <cfif qPattern.recordCount EQ 0>
        <cfset response = {
            success = false,
            message = "Recurring pattern not found"
        }>
        <cfoutput>#serializeJSON(response)#</cfoutput>
        <cfabort>
    </cfif>

    <!--- Get all instances in the series ----->
    <cfset recurringBooking = createObject("component", "components.RecurringBooking").init()>
    <cfset qInstances = recurringBooking.getSeriesInstances(parentBookingId)>

    <!--- Build instances array ----->
    <cfset instances = []>
    <cfloop query="qInstances">
        <cfset arrayAppend(instances, {
            bookingId = qInstances.BOOKING_ID,
            userId = qInstances.USER_ID,
            roomId = qInstances.ROOM_ID,
            roomName = qInstances.ROOM_NAME,
            startTime = dateFormat(qInstances.START_TIME, "yyyy-mm-dd") & " " & timeFormat(qInstances.START_TIME, "HH:mm:ss"),
            endTime = dateFormat(qInstances.END_TIME, "yyyy-mm-dd") & " " & timeFormat(qInstances.END_TIME, "HH:mm:ss"),
            comments = qInstances.COMMENTS,
            status = qInstances.STATUS,
            instanceNumber = qInstances.SERIES_INSTANCE_NUMBER,
            requester = qInstances.FIRST_NAME & " " & qInstances.LAST_NAME
        })>
    </cfloop>

    <!--- Build response ----->
    <cfset response = {
        success = true,
        pattern = {
            patternId = qPattern.PATTERN_ID,
            frequency = qPattern.FREQUENCY,
            intervalCount = qPattern.INTERVAL_COUNT,
            endType = qPattern.END_TYPE,
            endDate = qPattern.END_DATE,
            maxOccurrences = qPattern.MAX_OCCURRENCES,
            daysOfWeek = qPattern.DAYS_OF_WEEK,
            createdAt = qPattern.CREATED_AT
        },
        instances = instances,
        totalInstances = arrayLen(instances)
    }>

    <cfoutput>#serializeJSON(response)#</cfoutput>

<cfcatch>
    <cflog file="recurring-bookings" text="Error getting recurring series: #cfcatch.message# #cfcatch.detail#" type="error">
    <cfset response = {
        success = false,
        message = "Error retrieving recurring series: " & cfcatch.message
    }>
    <cfoutput>#serializeJSON(response)#</cfoutput>
</cfcatch>
</cftry>
