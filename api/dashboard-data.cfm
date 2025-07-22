<cfset response = {}>

<cftry>
    <!--- Get today's bookings count --->
    <cfquery name="todayBookings" datasource="#application.datasource#">
        SELECT COUNT(*) as count
        FROM BOOKINGS
        WHERE TRUNC(BOOKINGDATE) = TRUNC(SYSDATE)
        AND EMPLID = <cfqueryparam value="#session.user.EMPLID#" cfsqltype="cf_sql_varchar">
    </cfquery>

    <!--- Get available rooms count --->
    <cfquery name="availableRooms" datasource="#application.datasource#">
        SELECT COUNT(DISTINCT r.ROOMID) as count
        FROM ROOMS r
        WHERE NOT EXISTS (
            SELECT 1 
            FROM BOOKINGS b
            WHERE b.ROOMID = r.ROOMID
            AND TRUNC(b.BOOKINGDATE) = TRUNC(SYSDATE)
            AND SYSDATE BETWEEN b.STARTTIME AND b.ENDTIME
        )
    </cfquery>

    <!--- Debug output --->
    <cfset debug = {
        "availableRoomsCount": availableRooms.count,
        "currentTime": NOW()
    }>
    <cflog file="confroom" text="Debug info: #SerializeJSON(debug)#">

    <!--- Get total hours booked --->
    <cfquery name="hoursBooked" datasource="#application.datasource#">
        SELECT NVL(SUM((ENDTIME - STARTTIME) * 24), 0) as hours
        FROM BOOKINGS
        WHERE EMPLID = <cfqueryparam value="#session.user.EMPLID#" cfsqltype="cf_sql_varchar">
        AND BOOKINGDATE >= TRUNC(SYSDATE) - 30
    </cfquery>

    <!--- Get total meetings count --->
    <cfquery name="totalMeetings" datasource="#application.datasource#">
        SELECT COUNT(*) as count
        FROM BOOKINGS
        WHERE EMPLID = <cfqueryparam value="#session.user.EMPLID#" cfsqltype="cf_sql_varchar">
        AND BOOKINGDATE >= TRUNC(SYSDATE)
    </cfquery>

    <!--- Get upcoming bookings --->
    <cfquery name="upcomingBookings" datasource="#application.datasource#">
        SELECT 
            b.BOOKINGID,
            r.ROOMNAME,
            TO_CHAR(b.BOOKINGDATE, 'MM/DD/YYYY') as BOOKINGDATE,
            TO_CHAR(b.STARTTIME, 'HH:MI AM') as STARTTIME,
            TO_CHAR(b.ENDTIME, 'HH:MI AM') as ENDTIME
        FROM BOOKINGS b
        JOIN ROOMS r ON b.ROOMID = r.ROOMID
        WHERE b.EMPLID = <cfqueryparam value="#session.user.EMPLID#" cfsqltype="cf_sql_varchar">
        AND b.BOOKINGDATE >= TRUNC(SYSDATE)
        ORDER BY b.BOOKINGDATE, b.STARTTIME
        FETCH FIRST 5 ROWS ONLY
    </cfquery>

    <!--- Build response object --->
    <cfset response = {
        "todayBookings": todayBookings.count,
        "availableRooms": availableRooms.count,
        "hoursBooked": NumberFormat(hoursBooked.hours, "0"),
        "totalMeetings": totalMeetings.count,
        "upcomingBookings": []
    }>

    <!--- Format upcoming bookings --->
    <cfloop query="upcomingBookings">
        <cfset arrayAppend(response.upcomingBookings, {
            "id": BOOKINGID,
            "roomName": ROOMNAME,
            "date": BOOKINGDATE,
            "time": "#STARTTIME# - #ENDTIME#"
        })>
    </cfloop>

    <!--- Return JSON response --->
    <cfheader statuscode="200" statustext="OK">
    <cfcontent type="application/json">
    <cfoutput>#SerializeJSON(response)#</cfoutput>

    <cfcatch type="any">
        <cflog file="roomreservation" text="Error in dashboard-data.cfm: #cfcatch.message# - #cfcatch.detail#">
        <cfheader statuscode="500" statustext="Internal Server Error">
        <cfcontent type="application/json">
        <cfoutput>#SerializeJSON({
            "error": cfcatch.message,
            "detail": cfcatch.detail
        })#</cfoutput>
    </cfcatch>
</cftry>
