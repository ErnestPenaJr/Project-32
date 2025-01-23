<cfcomponent>
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
    <!--- Get Rooms --->
    <cffunction name="getRooms" access="remote" returntype="query" returnformat="json">
        <cfquery name="qRooms" datasource="project_32">
            SELECT 
                location,
                capacity,
                CASE 
                    WHEN EXISTS (
                        SELECT 1 
                        FROM bookings b 
                        WHERE b.room_id = r.room_id 
                        AND CURRENT_TIMESTAMP BETWEEN b.start_time AND b.end_time
                    ) THEN 'Occupied'
                    ELSE 'Available'
                END as status
            FROM rooms r
            ORDER BY location ASC
        </cfquery>
        <cfreturn qRooms>
    </cffunction>

    <cffunction name="getBookingHistory"access="remote" returntype="struct" returnformat="json">
        <cfargument name="userId" type="numeric" required="false" default="#session.userId#">
        
 <cfargument name="date" type="string" required="false" default="">
        <cfargument name="status" type="string" required="false" default="">
        <cfargument name="search" type="string" required="false" default="">
        
        
        <cftry>
            <cfquery name="qGetHistory" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT 
                    b.BOOKING_ID as ID,
                    u.FIRST_NAME || ' ' || u.LAST_NAME as USER_NAME,
                    r.ROOM_NAME,
                    r.BUILDING as BUILDING,
                    r.ROOM_NUMBER as ROOM_NUMBER,
                    TO_NUMBER(r.CAPACITY) as CAPACITY,
                    TO_CHAR(b.START_TIME, 'YYYY-MM-DD') as BOOKING_DATE,
                    TO_CHAR(b.END_TIME, 'YYYY-MM-DD') as BOOKING_END_DATE,
                    TO_CHAR(b.START_TIME, 'HH24:MI') as START_TIME,
                    TO_CHAR(b.END_TIME, 'HH24:MI') as END_TIME,
                    TO_CHAR(b.START_TIME, 'MM/DD/YYYY HH24:MI AM')as START_DATE,
                    TO_CHAR(b.END_TIME, 'MM/DD/YYYY HH24:MI AM') as END_DATE,
                    b.STATUS as STATUSx
                FROM #this.DBSCHEMA#.BOOKINGS b
                JOIN #this.DBSCHEMA#.USERS u ON b.USER_ID = u.USER_ID
                JOIN #this.DBSCHEMA#.ROOMS r ON b.ROOM_ID = r.ROOM_ID
                WHERE b.USER_ID = <cfqueryparam value="#arguments.userId#" cfsqltype="cf_sql_numeric">
                ORDER BY b.START_TIME DESC
            </cfquery>
            
            <cfset var result = {
                "SUCCESS" = true,
                "DATA" = []
            }>
            
            <cfloop query="qGetHistory">
                <cfset arrayAppend(result.DATA, {
                    "ID" = qGetHistory.ID,
                    "USER_NAME" = qGetHistory.USER_NAME,
                    "ROOM_NAME" = qGetHistory.ROOM_NAME,
                    "LOCATION" = qGetHistory.BUILDING & '-' & qGetHistory.ROOM_NUMBER,
                    "CAPACITY" = qGetHistory.CAPACITY,
                    "BOOKING_DATE" = qGetHistory.BOOKING_DATE,
                    "BOOKING_END_DATE" = qGetHistory.BOOKING_END_DATE,
                    "START_TIME" = TIMEFORMAT(qGetHistory.START_TIME, 'h:mm tt'),
                    "END_TIME" = TIMEFORMAT(qGetHistory.END_TIME, 'h:mm tt'),
                    "TIME" = TIMEFORMAT(qGetHistory.START_TIME, 'h:mm tt') & ' - ' & TIMEFORMAT(qGetHistory.END_TIME, 'h:mm tt'),
                    "START_DATE" = qGetHistory.START_DATE,
                    "END_DATE" = qGetHistory.END_DATE,
                    "STATUS" = qGetHistory.STATUSx
                })>
            </cfloop>
            <cfreturn result>
            
            <cfcatch>
                <cflog type="error"  file="#GetDirectoryFromPath(GetCurrentTemplatePath())#assets/logs/error.log" text="Error in getPendingBookings: #cfcatch.message# #cfcatch.detail#">
                <cfreturn {
                    "SUCCESS" = false,
                    "MESSAGE" = "Error retrieving bookings: " & cfcatch.message
                }>
            </cfcatch>
        </cftry>
    </cffunction>
</cfcomponent>
