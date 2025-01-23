<cfcomponent output="false">
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

<cffunction name="availableRooms" access="remote" returntype="any" returnformat="JSON" output="false" hint="Get the total number of available rooms.">
    <cfset var retVal = {} />
    <cftry>
        <cfquery name="availableRooms" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
            WITH RoomCounts AS (
                SELECT
                    COUNT(*) AS TotalRooms
                FROM ROOMS
            ),
            ActiveBookings AS (
                SELECT
                    COUNT(DISTINCT b.ROOM_ID) AS TotalBookedRooms
                FROM BOOKINGS b
                WHERE SYSDATE >= b.START_TIME 
                AND SYSDATE <= b.END_TIME
                AND STATUS NOT IN ('cancelled', 'rejected')
            )
            SELECT
                rc.TotalRooms,
                ab.TotalBookedRooms,
                rc.TotalRooms - ab.TotalBookedRooms AS TotalAvailableRooms
            FROM
                RoomCounts rc
                CROSS JOIN ActiveBookings ab
        </cfquery>

        <cfset retVal["data"] = {
            "totalRooms": availableRooms.TotalRooms,
            "totalBookedRooms": availableRooms.TotalBookedRooms,
            "totalAvailableRooms": availableRooms.TotalAvailableRooms
        }>
        <cfset retVal["status"] = "success">
    <cfcatch>
        <cfset retVal["data"] = { "error": cfcatch.message }>
        <cfset retVal["status"] = "error">
    </cfcatch>
    </cftry>
    <cfreturn retVal />
</cffunction>

    
    <cffunction name="todayBookings" access="remote" returntype="any" returnformat="JSON" output="false">
        <cfargument name="userId" required="false" type="string" />
        <cfset var retVal = {} />
        <cftry>
            <cfquery name="qryTodayBookings" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT COUNT(*) as count
                FROM #this.DBSCHEMA#.BOOKINGS
                WHERE TRUNC(START_TIME) = TRUNC(SYSDATE)
                AND SYSDATE BETWEEN START_TIME AND END_TIME
                AND STATUS = 'pending'
                <cfif arguments.userId>
                    AND USER_ID = <cfqueryparam value="#arguments.userId#" cfsqltype="cf_sql_numeric">
                </cfif>
            </cfquery>

            <cfset retVal["data"] = { "TOTAL": qryTodayBookings.count }>
            <cfset retVal["status"] = "success">
        <cfcatch>
            <cfset retVal["data"] = { "error": cfcatch.message }>
            <cfset retVal["status"] = "error">
        </cfcatch>
        </cftry>
        <cfreturn retVal />
    </cffunction>

    <cffunction name="totalMeetings" access="remote" returntype="any" returnformat="JSON" output="false">
        <cfargument name="userId" required="false" type="string" />
        <cfset var retVal = {} />
        <cftry>
            <cfquery name="qryTotalMeetings" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT COUNT(*) as count
                FROM #this.DBSCHEMA#.BOOKINGS
                WHERE START_TIME >= TRUNC(SYSDATE)
                <cfif arguments.userId>
                    AND USER_ID = <cfqueryparam value="#arguments.userId#" cfsqltype="cf_sql_numeric">
                </cfif>
            </cfquery>

            <cfset retVal["data"] = { "TOTAL": qryTotalMeetings.count }>
            <cfset retVal["status"] = "success">
        <cfcatch>
            <cfset retVal["data"] = { "error": cfcatch.message }>
            <cfset retVal["status"] = "error">
        </cfcatch>
        </cftry>
        <cfreturn retVal />
    </cffunction>  

    <cffunction name="MyBookings" access="remote" returntype="any" returnformat="JSON" output="false">
        <cfargument name="userId" required="false" type="string" />
        <cfset var retVal = {} />
        <cftry>
            <cfquery name="qryUpcoming" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT 
                    b.BOOKING_ID ID,
                    r.ROOM_NAME TITLE,
                    b.START_TIME,
                    TO_CHAR(b.START_TIME, 'HH:MI AM') as STARTTIME,
                    TO_CHAR(b.END_TIME, 'HH:MI AM') as ENDTIME
                FROM #this.DBSCHEMA#.BOOKINGS b
                JOIN #this.DBSCHEMA#.ROOMS r ON b.ROOM_ID = r.ROOM_ID
                WHERE b.START_TIME >= SYSDATE
                <cfif arguments.userId>
                    AND b.USER_ID = <cfqueryparam value="#arguments.userId#" cfsqltype="cf_sql_numeric">
                </cfif>
                ORDER BY b.START_TIME
            </cfquery>

            <cfset var meetings = [] />
            <cfloop query="qryUpcoming">
                <cfset arrayAppend(meetings, {
                    "ID": qryUpcoming.ID,
                    "NAME": qryUpcoming.TITLE,
                    "STARTTIME": qryUpcoming.STARTTIME,
                    "ENDTIME": qryUpcoming.ENDTIME
                }) />
            </cfloop>

            <cfset retVal["data"] = meetings>
            <cfset retVal["status"] = "success">
        <cfcatch>
            <cfset retVal["data"] = { "error": cfcatch.message }>
            <cfset retVal["status"] = "error">
        </cfcatch>
        </cftry>
        <cfreturn retVal />
    </cffunction>

    <cffunction name="getAllBookings" access="remote" returntype="any" returnformat="JSON" output="false">
        <cfset var retVal = {} />
        <cftry>
            <cfquery name="qryUpcoming" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT 
                    u.FIRST_NAME,
                    u.LAST_NAME,
                    u.EMPLID,
                    b.USER_ID,
                    b.BOOKING_ID ID,
                    r.ROOM_ID,
                    r.ROOM_NAME as NAME,
                    r.DESCRIPTION,
                    b.START_TIME,
                    b.STATUS,
                    TO_CHAR(b.START_TIME,'YYYY-MM-DD') AS STARTDATE,
                    TO_CHAR(b.END_TIME,'YYYY-MM-DD') AS ENDDATE,
                    TO_CHAR(b.START_TIME, 'HH:MI AM') as STARTTIME,
                    TO_CHAR(b.END_TIME, 'HH:MI AM') as ENDTIME
                FROM #this.DBSCHEMA#.BOOKINGS b
                JOIN #this.DBSCHEMA#.ROOMS r ON b.ROOM_ID = r.ROOM_ID
                JOIN #this.DBSCHEMA#.USERS u ON b.USER_ID = u.USER_ID 
                WHERE CURRENT_TIMESTAMP <= b.END_TIME
                AND LOWER(b.STATUS) IN ('pending', 'approved')
                ORDER BY b.START_TIME
            </cfquery>

            <cfset var meetings = [] />
            <cfloop query="qryUpcoming">
                <cfset arrayAppend(meetings, {
                    "EMPLID": qryUpcoming.EMPLID,
                    "USERID": qryUpcoming.USER_ID,
                    "FIRSTNAME": qryUpcoming.FIRST_NAME,
                    "LASTNAME": qryUpcoming.LAST_NAME,
                    "ID": qryUpcoming.ID,
                    "ROOM_ID": qryUpcoming.ROOM_ID,
                    "NAME": qryUpcoming.NAME,
                    "STATUS": qryUpcoming.STATUS,
                    "STARTDATE": qryUpcoming.STARTDATE,
                    "STARTTIME": qryUpcoming.STARTTIME,
                    "ENDDATE": qryUpcoming.ENDDATE,
                    "ENDTIME": qryUpcoming.ENDTIME,
                    "DESCRIPTION": qryUpcoming.DESCRIPTION
                }) />
            </cfloop>

            <cfset retVal["BOOKINGS"] = meetings>
            <cfset retVal["status"] = "success">
        <cfcatch>
            <cfset retVal["BOOKINGS"] = { "error": cfcatch.message }>
            <cfset retVal["status"] = "error">
        </cfcatch>
        </cftry>
        <cfreturn retVal />
    </cffunction>

    <cffunction name="roomUtilization" access="remote" returntype="any" returnformat="JSON" output="false">
        <cfset var retVal = {} />
        <cftry>
            <cfquery name="qryRoomUtilization" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT r.ROOM_NAME,
                       COUNT(b.BOOKING_ID) as BookingCount,
                       r.CAPACITY,
                       ROUND((COUNT(b.BOOKING_ID) / r.CAPACITY) * 100, 2) as UtilizationPercentage
                FROM #this.DBSCHEMA#.ROOMS r
                LEFT JOIN #this.DBSCHEMA#.BOOKINGS b ON r.ROOM_ID = b.ROOM_ID
                    AND TRUNC(b.START_TIME) = TRUNC(SYSDATE)
                    AND b.STATUS = 'Confirmed'
                WHERE r.MAINTENANCE_STATUS IS NULL
                GROUP BY r.ROOM_NAME, r.CAPACITY
                ORDER BY UtilizationPercentage DESC
            </cfquery>

            <cfset retVal["data"] = qryRoomUtilization />
            <cfset retVal["success"] = true />
        <cfcatch>
            <cfset retVal["success"] = false />
            <cfset retVal["message"] = cfcatch.message />
        </cfcatch>
        </cftry>
        <cfreturn retVal />
    </cffunction>

    <cffunction name="maintenanceStatus" access="remote" returntype="any" returnformat="JSON" output="false">
        <cfset var retVal = {} />
        <cftry>
            <cfquery name="qryMaintenanceStatus" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT 
                    COUNT(CASE WHEN MAINTENANCE_STATUS = 'Under Maintenance' THEN 1 END) as UnderMaintenance,
                    COUNT(CASE WHEN MAINTENANCE_STATUS = 'Available' OR MAINTENANCE_STATUS IS NULL THEN 1 END) as Available
                FROM #this.DBSCHEMA#.ROOMS
            </cfquery>

            <cfset retVal["data"] = qryMaintenanceStatus />
            <cfset retVal["success"] = true />
        <cfcatch>
            <cfset retVal["success"] = false />
            <cfset retVal["message"] = cfcatch.message />
        </cfcatch>
        </cftry>
        <cfreturn retVal />
    </cffunction>

    <cffunction name="getAllDashboardData" access="remote" returntype="any" returnformat="JSON" produces="application/json" output="false">
        <cftry>
            <!--- Get today's bookings count --->
            <cfquery username="#this.DBUSER#" password="#this.DBPASS#" datasource="#this.DBSERVER#" name="todayBookings">
                SELECT COUNT(*) as count
                FROM CONFROOM.BOOKINGS
                WHERE TRUNC(BOOKINGDATE) = TRUNC(SYSDATE)
                AND EMPLID = <cfqueryparam value="#sessionStorage.getItem('EMPLID')#" cfsqltype="cf_sql_varchar">
            </cfquery>

            <!--- Get available rooms count --->
            <cfquery username="#this.DBUSER#" password="#this.DBPASS#" datasource="#this.DBSERVER#" name="availableRooms">
                SELECT COUNT(*) AS TotalAvailableRooms
                FROM CONFROOM.ROOMS r
                WHERE r.MAINTENANCE = 'NO' -- Room is not under maintenance
                AND NOT EXISTS (
                    SELECT 1
                    FROM CONFROOM.BOOKINGS b
                    WHERE b.ROOMID = r.ROOMID
                    AND b.BOOKINGDATE = TRUNC(SYSDATE) -- Booking is for today
                    AND SYSDATE BETWEEN b.STARTTIME AND b.ENDTIME -- Booking overlaps current time
                )
            </cfquery>

            <!--- Get total meetings count --->
            <cfquery username="#this.DBUSER#" password="#this.DBPASS#" datasource="#this.DBSERVER#" name="totalMeetings">
                SELECT COUNT(*) as count
                FROM CONFROOM.BOOKINGS
                WHERE EMPLID = <cfqueryparam value="#sessionStorage.getItem('EMPLID')#" cfsqltype="cf_sql_varchar">
                AND BOOKINGDATE >= TRUNC(SYSDATE)
            </cfquery>

            <!--- Get upcoming bookings --->
            <cfquery username="#this.DBUSER#" password="#this.DBPASS#" datasource="#this.DBSERVER#" name="upcomingBookings">
                SELECT 
                    b.BOOKINGID,
                    r.ROOMNAME,
                    TO_CHAR(b.BOOKINGDATE, 'MM/DD/YYYY') as BOOKINGDATE,
                    TO_CHAR(b.STARTTIME, 'HH:MI AM') as STARTTIME,
                    TO_CHAR(b.ENDTIME, 'HH:MI AM') as ENDTIME
                FROM CONFROOM.BOOKINGS b
                JOIN CONFROOM.ROOMS r ON b.ROOMID = r.ROOMID
                WHERE b.EMPLID = <cfqueryparam value="#sessionStorage.getItem('EMPLID')#" cfsqltype="cf_sql_varchar">
                AND b.BOOKINGDATE >= TRUNC(SYSDATE)
                ORDER BY b.BOOKINGDATE, b.STARTTIME
                FETCH FIRST 5 ROWS ONLY
            </cfquery>

            <!--- Build response object --->
            <cfset response = {
                "success": true,
                "data": {
                    "todayBookings": todayBookings.count,
                    "availableRooms": availableRooms.TotalRooms,
                    "totalMeetings": totalMeetings.count,
                    "upcomingBookings": []
                }
            }>

            <!--- Format upcoming bookings --->
            <cfloop query="upcomingBookings">
                <cfset arrayAppend(response.data.upcomingBookings, {
                    "BOOKINGID": BOOKINGID,
                    "ROOMNAME": ROOMNAME,
                    "BOOKINGDATE": BOOKINGDATE,
                    "STARTTIME": STARTTIME,
                    "ENDTIME": ENDTIME
                })>
            </cfloop>

            <cfreturn response>
            
            <cfcatch type="any">
                <cfset errorResponse = {
                    "success": false,
                    "message": "Error fetching dashboard data",
                    "detail": cfcatch.message
                }>
                <cfheader statuscode="500" statustext="Internal Server Error">
                <cfreturn errorResponse>
            </cfcatch>
        </cftry>
    </cffunction>

    <cffunction name="getRooms" access="remote" returntype="array" returnformat="JSON">
        <cftry>
            <cfquery name="qGetRooms" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT 
                    r.ROOM_ID AS id,
                    r.ROOM_NAME AS roomName,
                    r.BUILDING AS building,
                    r.ROOM_NUMBER AS roomNumber,
                    r.CAPACITY AS capacity,
                    r.DESCRIPTION AS description,
                    r.MAINTENANCE_STATUS AS maintenance,
                    r.STATUS AS activeStatus,
                    r.RECURRING AS recurring,
                    CASE 
                        WHEN EXISTS (
                            SELECT 1
                            FROM #this.DBSCHEMA#.BOOKINGS 
                            WHERE ROOM_ID = r.ROOM_ID 
                            AND current_timestamp BETWEEN start_time AND end_time
                        ) THEN 'Occupied'
                        ELSE 'Available'
                    END AS status
                FROM #this.DBSCHEMA#.ROOMS r
                ORDER BY r.ROOM_ID ASC
            </cfquery>

            <cfset local.rooms = []>
            <cfloop query="qGetRooms">
                <cfset arrayAppend(local.rooms, {
                    "id": qGetRooms.id,
                    "roomName": qGetRooms.roomName,
                    "building": qGetRooms.building,
                    "roomNumber": qGetRooms.roomNumber,
                    "capacity": qGetRooms.capacity,
                    "description": qGetRooms.description,
                    "maintenance": qGetRooms.maintenance,
                    "recurring": qGetRooms.recurring,
                    "status": qGetRooms.status,
                    "active_status": qGetRooms.activeStatus
                })>
            </cfloop>

            <cfreturn local.rooms>
        <cfcatch type="any">
            <cflog file="roomManagement" text="Error in getRooms: #cfcatch.message#. Details: #cfcatch.detail#">
            <cfthrow message="Error retrieving rooms" detail="#cfcatch.detail#">
        </cfcatch>
        </cftry>
    </cffunction>

    <cffunction name="getRoom" access="remote" returntype="struct" returnformat="JSON">
        <cfargument name="roomId" type="numeric" required="true">
        
        <cftry>
            <cfquery name="qGetRoom" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
            SELECT 
                r.ROOM_ID AS id,
                r.ROOM_NAME AS roomName,
                r.BUILDING AS building,
                r.ROOM_NUMBER AS roomNumber,
                r.CAPACITY AS capacity,
                r.DESCRIPTION AS description,
                r.MAINTENANCE_STATUS AS maintenance,
                r.RECURRING AS recurring,
                r.ROOM_IMAGE AS image,
                CASE 
                    WHEN EXISTS (
                        SELECT 1 
                        FROM BOOKINGS b
                        WHERE b.ROOM_ID = r.ROOM_ID
                        AND CURRENT_TIMESTAMP BETWEEN b.START_TIME AND b.END_TIME
                    ) THEN 'Occupied'
                    ELSE 'Available'
                END AS status,
                LISTAGG(a.AMENITY_ID, ', ') WITHIN GROUP (ORDER BY a.AMENITY_NAME) AS amenities
            FROM ROOMS r
            LEFT JOIN ROOM_AMENITIES ra ON ra.ROOM_ID = r.ROOM_ID
            LEFT JOIN AMENITIES a ON a.AMENITY_ID = ra.AMENITY_ID
            WHERE r.ROOM_ID = <cfqueryparam value="#arguments.roomId#" cfsqltype="cf_sql_numeric">
           GROUP BY r.ROOM_ID,r.ROOM_NAME,r.BUILDING,r.ROOM_NUMBER,r.CAPACITY,r.DESCRIPTION,r.MAINTENANCE_STATUS,r.RECURRING
            </cfquery>

            <cfif qGetRoom.recordCount>
                <cfreturn {
                    "id": qGetRoom.id,
                    "roomName": qGetRoom.roomName,
                    "building": qGetRoom.building,
                    "roomNumber": qGetRoom.roomNumber,
                    "capacity": qGetRoom.capacity,
                    "description": qGetRoom.description,
                    "maintenance": qGetRoom.maintenance,
                    "recurring": qGetRoom.recurring,
                    "status": qGetRoom.status,
                    "amenities": qGetRoom.amenities,
                    "success": true
                }>
            <cfelse>
                <cfthrow message="Room not found" detail="No room found with ID #arguments.roomId#">
            </cfif>
            
        <cfcatch type="any">
            <cflog file="roomManagement" text="Error in getRoom: #cfcatch.message#. Details: #cfcatch.detail#">
            <cfthrow message="Error retrieving room" detail="#cfcatch.detail#">
        </cfcatch>
        </cftry>
    </cffunction>

    <cffunction name="updateRoom" access="remote" returntype="boolean" returnformat="JSON">
        <cfargument name="id" type="numeric" required="true">
        <cfargument name="roomName" type="string" required="true">
        <cfargument name="building" type="string" required="true">
        <cfargument name="roomNumber" type="string" required="true">
        <cfargument name="capacity" type="numeric" required="true">
        <cfargument name="description" type="string" required="true">
        <cfargument name="recurring" type="string" required="true">
        <cfargument name="maintenance" type="string" required="true">
        
        <cftransaction>
            <cftry>
                <cfquery datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                    UPDATE #this.DBSCHEMA#.ROOMS
                    SET 
                        ROOM_NAME = <cfqueryparam value="#arguments.roomName#" cfsqltype="cf_sql_varchar">,
                        BUILDING = <cfqueryparam value="#arguments.building#" cfsqltype="cf_sql_varchar">,
                        ROOM_NUMBER = <cfqueryparam value="#arguments.roomNumber#" cfsqltype="cf_sql_varchar">,
                        CAPACITY = <cfqueryparam value="#arguments.capacity#" cfsqltype="cf_sql_numeric">,
                        DESCRIPTION = <cfqueryparam value="#arguments.description#" cfsqltype="cf_sql_varchar">,
                        RECURRING = <cfqueryparam value="#arguments.recurring#" cfsqltype="cf_sql_varchar">,
                        MAINTENANCE_STATUS = <cfqueryparam value="#arguments.maintenance#" cfsqltype="cf_sql_varchar">
                    WHERE ROOM_ID = <cfqueryparam value="#arguments.id#" cfsqltype="cf_sql_numeric">
                </cfquery>

                <cfreturn true>
                
            <cfcatch type="any">
                <cflog file="roomManagement" text="Error in updateRoom: #cfcatch.message#. Details: #cfcatch.detail#">
                <cfthrow message="Error updating room" detail="#cfcatch.detail#">
            </cfcatch>
            </cftry>
        </cftransaction>
    </cffunction>

<cffunction name="cancelBooking" access="remote" returntype="any" returnformat="JSON" output="false">
        <cfargument name="bookingid" required="true" type="numeric">
        <cfargument name="userId" required="true" type="numeric" default="#sessionStorage.getItem('EMPLID')#">

        
        <cfquery name="qryGetBooking" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
           SELECT 
                b.BOOKING_ID,
                b.USER_ID, 
                b.ROOM_ID, 
                r.ROOM_NAME, 
                r.BUILDING || '.' || r.ROOM_NUMBER AS LOCATION,
                u.EMAIL,
                u.FIRST_NAME,
                u.LAST_NAME,
                TO_CHAR(b.START_TIME, 'YYYY-MM-DD HH24:MI:SS') AS START_TIME,
                TO_CHAR(b.END_TIME, 'YYYY-MM-DD HH24:MI:SS') AS END_TIME
            FROM 
                #this.DBSCHEMA#.BOOKINGS b
            JOIN 
                #this.DBSCHEMA#.ROOMS r ON r.ROOM_ID = b.ROOM_ID
            JOIN 
                #this.DBSCHEMA#.USERS u ON u.USER_ID = b.USER_ID
            WHERE 
                b.BOOKING_ID = <cfqueryparam value="#arguments.bookingid#" cfsqltype="cf_sql_numeric">
        </cfquery>

        <cfquery name="qryGetCancellingAgent" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
            SELECT 
                u.FIRST_NAME, 
                u.LAST_NAME,
                u.EMAIL
            FROM 
                #this.DBSCHEMA#.USERS u
            WHERE 
                u.USER_ID = <cfqueryparam value="#arguments.userId#" cfsqltype="cf_sql_numeric">
        </cfquery>

        <cfquery name="qryCheckAvailability" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
            UPDATE #this.DBSCHEMA#.BOOKINGS
            SET STATUS = 'cancelled',
                APPROVED_BY = #arguments.userId#,
                COMMENTS = 'Cancelled by #qryGetCancellingAgent.FIRST_NAME# #qryGetCancellingAgent.LAST_NAME#',
                UPDATED_AT = CURRENT_TIMESTAMP
            WHERE BOOKING_ID = <cfqueryparam value="#arguments.bookingid#" cfsqltype="cf_sql_numeric">
        </cfquery>
            <cfset startTime = ParseDateTime(qryGetBooking.START_TIME)>
            <cfset endTime = ParseDateTime(qryGetBooking.END_TIME)>
           
            <cfif arguments.userId NEQ qryGetBooking.USER_ID>
                <cfset cancellingAgent = " By #qryGetCancellingAgent.FIRST_NAME# #qryGetCancellingAgent.LAST_NAME#." >
            <cfelse>
                <cfset cancellingAgent = "." >
            </cfif>

        <cfset var emailBody = "
            <cfoutput>
                <p>Dear #qryGetBooking.FIRST_NAME#,</p>

                <p>
                    We would like to confirm that your booking for the room ""<strong>#qryGetBooking.ROOM_NAME#</strong>"" has been
                    successfully cancelled#cancellingAgent#
                </p>

                <p>
                    <strong>Details of the canceled booking:</strong><br>
                <ul>
                    <li><strong>Location:</strong> #qryGetBooking.LOCATION#</li>
                    <li><strong>Room:</strong> #qryGetBooking.ROOM_NAME#</li>
                    <li><strong>Start Date:</strong> #DateFormat(startTime, "dddd, mmmm dd, yyyy")#  #TimeFormat(startTime, "h:mm tt")# </li>
                    <li><strong>End Date:</strong> #DateFormat(endTime, "dddd, mmmm dd, yyyy")#  #TimeFormat(endTime, "h:mm tt")# </li>
                    <li><strong>Booking ID:</strong> #qryGetBooking.BOOKING_ID#</li>
                </ul>
                </p>

                <p>
                    If you have any questions or need further assistance, please feel free to reach out to our team at your
                    convenience. We are here to help.
                </p>

                <p>Kind regards,<br>
                    <strong>DoCM Reservation System</strong>
                </p>
            </cfoutput>
        ">

        <cfmail to="#qryGetBooking.EMAIL#" from="#qryGetBooking.EMAIL#" subject="Cancellation Confirmation - Room ""#qryGetBooking.ROOM_NAME#""" type="html" bcc="erniep@mdanderson.org, tlouie@mdanderson.org, cpender@mdanderson.org, tglover@mdanderson.org">
            <cfmailpart type="text/html">
                <cfoutput>#emailBody#</cfoutput>
            </cfmailpart>
        </cfmail>

    <cfset response = {
        "status": "SUCCESS",
        "message": "Booking cancelled successfully"
        }>

    <cfreturn response>

    </cffunction> 



    <cffunction name="createBooking" access="remote" returntype="any" returnformat="JSON" output="false">
        <cfargument name="employee_id" required="true" type="numeric">
        <cfargument name="user_id" required="true" type="numeric">
        <cfargument name="room_id" required="true" type="numeric">
        <cfargument name="start_time" required="true" type="string">
        <cfargument name="end_time" required="true" type="string">
        <cfargument name="recurring" required="false" type="string" default="NO">
        <cfargument name="recurring_type" required="false" type="string" default="DAILY">
        
        <cfset var retVal = {} />
        
        <cftry>
            <!-- Parse date and time while considering AM/PM -->
            <cfset local.cleanStartTime = Trim(arguments.start_time) />
            <cfset local.cleanEndTime = Trim(arguments.end_time) />

            <!-- Use LSParseDateTime for better locale-based parsing -->
            <cfset local.parsedStartTime = LSParseDateTime(local.cleanStartTime) />
            <cfset local.parsedEndTime = LSParseDateTime(local.cleanEndTime) />
        <cfcatch>
            <cfset retVal["status"] = "error" />
            <cfset retVal["message"] = "Invalid date/time format. Please use format: YYYY-MM-DD HH:mm AM/PM" />
            <cfreturn retVal />
        </cfcatch>
        </cftry>

            <!--- Check if time slot is available --->
            <cfquery name="qryCheckAvailability" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT COUNT(*) as conflict_count
                FROM #this.DBSCHEMA#.BOOKINGS
                WHERE ROOM_ID = <cfqueryparam value="#arguments.room_id#" cfsqltype="cf_sql_numeric">
                AND LOWER(STATUS) IN('approved', 'pending')
                AND (
                    (START_TIME BETWEEN 
                        TO_DATE(<cfqueryparam value="#DateFormat(local.parsedStartTime, 'yyyy-mm-dd')# #TimeFormat(local.parsedStartTime, 'HH:mm')#" cfsqltype="cf_sql_varchar">, 'YYYY-MM-DD HH24:MI')
                        AND TO_DATE(<cfqueryparam value="#DateFormat(local.parsedEndTime, 'yyyy-mm-dd')# #TimeFormat(local.parsedEndTime, 'HH:mm')#" cfsqltype="cf_sql_varchar">, 'YYYY-MM-DD HH24:MI'))
                    OR (END_TIME BETWEEN 
                        TO_DATE(<cfqueryparam value="#DateFormat(local.parsedStartTime, 'yyyy-mm-dd')# #TimeFormat(local.parsedStartTime, 'HH:mm')#" cfsqltype="cf_sql_varchar">, 'YYYY-MM-DD HH24:MI')
                        AND TO_DATE(<cfqueryparam value="#DateFormat(local.parsedEndTime, 'yyyy-mm-dd')# #TimeFormat(local.parsedEndTime, 'HH:mm')#" cfsqltype="cf_sql_varchar">, 'YYYY-MM-DD HH24:MI'))
                    OR (START_TIME <= TO_DATE(<cfqueryparam value="#DateFormat(local.parsedStartTime, 'yyyy-mm-dd')# #TimeFormat(local.parsedStartTime, 'HH:mm')#" cfsqltype="cf_sql_varchar">, 'YYYY-MM-DD HH24:MI')
                        AND END_TIME >= TO_DATE(<cfqueryparam value="#DateFormat(local.parsedEndTime, 'yyyy-mm-dd')# #TimeFormat(local.parsedEndTime, 'HH:mm')#" cfsqltype="cf_sql_varchar">, 'YYYY-MM-DD HH24:MI'))
                )
            </cfquery>

            <cfif qryCheckAvailability.conflict_count GT 0>
                <cfset retVal["status"] = "error">
                <cfset retVal["data"] = {"message": "Selected time slot is not available"}>
                <cfreturn retVal>
            </cfif>

            <!--- Create the booking --->
            <cfquery name="qryCreateBooking" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                INSERT INTO #this.DBSCHEMA#.BOOKINGS (
                    USER_ID, ROOM_ID, START_TIME, END_TIME, 
                    RECURRING_DETAILS, STATUS, CREATED_AT, UPDATED_AT
                )
                VALUES (
                <cfqueryparam value="#arguments.user_id#" cfsqltype="cf_sql_numeric">,
                <cfqueryparam value="#arguments.room_id#" cfsqltype="cf_sql_numeric">,
                TO_DATE(<cfqueryparam value="#DateFormat(local.parsedStartTime, 'yyyy-mm-dd')# #TimeFormat(local.parsedStartTime, 'HH:mm')#" cfsqltype="cf_sql_varchar">, 'YYYY-MM-DD HH24:MI'),
                TO_DATE(<cfqueryparam value="#DateFormat(local.parsedEndTime, 'yyyy-mm-dd')# #TimeFormat(local.parsedEndTime, 'HH:mm')#" cfsqltype="cf_sql_varchar">, 'YYYY-MM-DD HH24:MI'),
                NULL,
                'approved',
                CURRENT_TIMESTAMP,
                CURRENT_TIMESTAMP
                )
            </cfquery>

            <cfquery name="qryGetBookingID" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT MAX(BOOKING_ID) AS booking_id
                FROM #this.DBSCHEMA#.BOOKINGS
            </cfquery>

            <cfquery name="qryGetBooking" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT 
                    b.BOOKING_ID,
                    b.USER_ID, 
                    b.ROOM_ID,
                    r.BUILDING || '.' || r.ROOM_NUMBER AS LOCATION,
                    r.ROOM_NAME, 
                    u.EMAIL,
                    u.FIRST_NAME,
                    u.LAST_NAME,
                    TO_CHAR(b.START_TIME, 'YYYY-MM-DD HH24:MI:SS') AS START_TIME,
                    TO_CHAR(b.END_TIME, 'YYYY-MM-DD HH24:MI:SS') AS END_TIME
                FROM 
                    #this.DBSCHEMA#.BOOKINGS b
                JOIN 
                    #this.DBSCHEMA#.ROOMS r ON r.ROOM_ID = b.ROOM_ID
                JOIN 
                    #this.DBSCHEMA#.USERS u ON u.USER_ID = b.USER_ID
                WHERE b.BOOKING_ID = <cfqueryparam value="#qryGetBookingID.booking_id#" cfsqltype="cf_sql_numeric">
            </cfquery>

            <cfset startTime = ParseDateTime(qryGetBooking.START_TIME)>
            <cfset endTime = ParseDateTime(qryGetBooking.END_TIME)>

            <!-- Generate ICS file -->
            <cfset var icsContent = [
                "BEGIN:VCALENDAR",
                "VERSION:2.0",
                "PRODID:-//DoCM//Office Space Reservation//EN",
                "BEGIN:VEVENT",
                "UID:#CreateUUID()#",
                "DTSTAMP:#DateFormat(Now(), "yyyyMMdd")#T#TimeFormat(Now(), "HHmmss")#Z",
                "DTSTART:#DateFormat(startTime, "yyyyMMdd")#T#TimeFormat(startTime, "HHmmss")#",
                "DTEND:#DateFormat(endTime, "yyyyMMdd")#T#TimeFormat(endTime, "HHmmss")#",
                "SUMMARY:Office Space Reservation",
                "DESCRIPTION:Reservation at #qryGetBooking.LOCATION#.",
                "LOCATION:#qryGetBooking.LOCATION#",
                "STATUS:CONFIRMED",
                "END:VEVENT",
                "END:VCALENDAR"
            ]>
            <!--- Join array with CRLF and create file --->
            <cfset var icsFileName = "booking_#qryGetBooking.BOOKING_ID#.ics">
            <cfset var icsFilePath = ExpandPath("../assets/temp/#icsFileName#")>
            <cfset var finalContent = arrayToList(icsContent, chr(13) & chr(10))>

            <!--- Write the ICS file --->
            <cffile action="write" file="#icsFilePath#" output="#finalContent#" charset="utf-8">
            

            <cfset var emailBody = "
                <cfoutput>
                     <h2>BOOKING CONFIRMATION</h2>

                    <p>Greetings, #qryGetBooking.FIRST_NAME#,</p>

                    <p>Thank you for your reservation! We're happy to confirm that your office space (#qryGetBooking.ROOM_NAME#) is successfully booked.</p>
                    <p>Below are the details of your reservation:</p>
                    
                    <h3>Reservation Details:</h3>
                    <ul>
                        <li><strong>Location:</strong> #qryGetBooking.LOCATION#</li>
                        <li><strong>Room:</strong> #qryGetBooking.ROOM_NAME#</li>
                        <li><strong>Starting On:</strong> #DateFormat(startTime, "dddd, mmmm dd, yyyy")# at #TimeFormat(startTime, "h:mm tt")# </li>
                        <li><strong>Ending On:</strong> #DateFormat(endTime, "dddd, mmmm dd, yyyy")# at #TimeFormat(endTime, "h:mm tt")# </li>
                        <li><strong>Booking ID:</strong> #qryGetBooking.BOOKING_ID#</li>
                        <li><strong>Add to Calendar:</strong> <a href="" https://#cgi.SERVER_NAME#:#cgi.SERVER_PORT#/#ListFirst(CGI.SCRIPT_NAME,'/')#/assets/temp/#icsFileName#"" target=""_blank"">Add to Calendar</a> | <a href="" https://#cgi.SERVER_NAME#:#cgi.SERVER_PORT#/#ListFirst(CGI.SCRIPT_NAME,'/')#/assets/temp/#icsFileName#"">Download iCalendar</a></li>
                    </ul>
                                   
                        <h3>Important Information:</h3>
                        <ul>
                            <li><strong>If the office door is locked:</strong> If you have a key for the FC11 floor, you can use it to open any door on that floor. If you do not have a key, spare keys are available at the front desk in the overhead.</li>
                            <li><strong>Key Return:</strong> Please make sure to return the key to the front desk after your reservation to ensure it's available for the next person.</li>
                            <li><strong>Personal belongings and Cleanliness:</strong> Please remember not to leave any personal belongings in the office, and kindly clean up after yourself before leaving to maintain the space for others.</li>
                            <li><strong>Cancellation Reminder:</strong> If your plans change and you no longer need the office space, please cancel your reservation as soon as possible to allow others the opportunity to use the space.</li>
                        </ul>
                        
                        <p>We hope this space meets your needs, and please don't hesitate to reach out if you have any questions or need assistance.</p>
                        

                    <p>Kind regards,<br>
                        <strong>DoCM Reservation System</strong>
                    </p>
                </cfoutput>
            ">

            <cfmail to="#qryGetBooking.EMAIL#" from="#qryGetBooking.EMAIL#" subject="Office Space Reservation Confirmation" type="html" bcc="erniep@mdanderson.org, tlouie@mdanderson.org, cpender@mdanderson.org, tglover@mdanderson.org">
                <cfmailpart type="text/html">
                    <cfoutput>#emailBody#</cfoutput>
                </cfmailpart>
            </cfmail>



            <cfset retVal["status"] = "success">
            <cfset retVal["data"] = {"message": "Booking created successfully, please check your email for confirmation"}>
  
        <cfreturn retVal>
    </cffunction>




    <cffunction name="getRoomImage" access="remote" returntype="any" returnformat="JSON" output="false">
        <cfargument name="roomId" required="true" type="string">
        <cfset var retVal = {}>
        
        <cftry>
            <cfquery name="qryRoomImage" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT ROOM_IMAGE AS IMAGE_DATA
                FROM #this.DBSCHEMA#.ROOMS
                WHERE ROOM_ID = <cfqueryparam value="#arguments.roomId#" cfsqltype="cf_sql_varchar">
            </cfquery>
            
            <cfif qryRoomImage.recordCount GT 0 AND len(qryRoomImage.IMAGE_DATA)>
                <cfset retVal["IMAGE_DATA"] = "data:image/png;base64," & qryRoomImage.IMAGE_DATA>
                <cfset retVal["status"] = "success">
            <cfelse>
                <cfset retVal["status"] = "no_image">
            </cfif>
            
        <cfcatch>
            <cfset retVal["status"] = "error">
            <cfset retVal["message"] = cfcatch.message>
        </cfcatch>
        </cftry>
        
        <cfreturn retVal>
    </cffunction>

    <cffunction name="getRoomDescription" access="remote" returntype="any" returnformat="JSON" output="false">
        <cfargument name="roomId" required="true" type="string">
        <cfset var retVal = {}>
        
        <cftry>
            <cfquery name="qryRoomDescription" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT DESCRIPTION, CAPACITY,ROOM_NUMBER,BUILDING
                FROM #this.DBSCHEMA#.ROOMS
                WHERE ROOM_ID = <cfqueryparam value="#arguments.roomId#" cfsqltype="cf_sql_varchar">
            </cfquery>
            
            <cfif qryRoomDescription.recordCount GT 0 AND len(qryRoomDescription.DESCRIPTION)>
                <cfset retVal["DESCRIPTION"] = qryRoomDescription.DESCRIPTION>
                <cfset retVal["CAPACITY"] = qryRoomDescription.CAPACITY>
                <cfset retVal["ROOM_NUMBER"] = qryRoomDescription.ROOM_NUMBER>
                <cfset retVal["BUILDING"] = qryRoomDescription.BUILDING>
                <cfset retVal["status"] = "success">
            <cfelse>
                <cfset retVal["status"] = "no_description">
            </cfif>
            
        <cfcatch>
            <cfset retVal["status"] = "error">
            <cfset retVal["message"] = cfcatch.message>
        </cfcatch>
        </cftry>
        
        <cfreturn retVal>
    </cffunction>

</cfcomponent>