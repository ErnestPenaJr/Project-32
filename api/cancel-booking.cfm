<cfset response = {}>

<cftry>
    <!--- Verify user is logged in --->
    <cfif NOT IsDefined("session.user.EMPLID")>
        <cfset response.success = false>
        <cfset response.message = "User not authenticated">
        <cfthrow message="User not authenticated">
    </cfif>

    <!--- Get booking ID from URL --->
    <cfparam name="url.bookingId" type="numeric" default="0">
    
    <!--- Verify booking exists and belongs to user --->
    <cfquery name="checkBooking" datasource="#application.datasource#">
        SELECT BOOKINGID, EMPLID
        FROM CONFROOM.BOOKINGS
        WHERE BOOKINGID = <cfqueryparam value="#url.bookingId#" cfsqltype="cf_sql_numeric">
        AND EMPLID = <cfqueryparam value="#session.user.EMPLID#" cfsqltype="cf_sql_varchar">
    </cfquery>

    <cfif checkBooking.recordCount EQ 0>
        <cfset response.success = false>
        <cfset response.message = "Booking not found or unauthorized">
        <cfthrow message="Booking not found or unauthorized">
    </cfif>

    <!--- Delete the booking --->
    <cfquery datasource="#application.datasource#">
        DELETE FROM CONFROOM.BOOKINGS
        WHERE BOOKINGID = <cfqueryparam value="#url.bookingId#" cfsqltype="cf_sql_numeric">
        AND EMPLID = <cfqueryparam value="#session.user.EMPLID#" cfsqltype="cf_sql_varchar">
    </cfquery>

    <cfset response.success = true>
    <cfset response.message = "Booking cancelled successfully">

    <cfcatch>
        <cfset response.success = false>
        <cfset response.message = cfcatch.message>
    </cfcatch>
</cftry>

<!--- Return JSON response --->
<cfcontent type="application/json">
<cfoutput>#SerializeJSON(response)#</cfoutput>
