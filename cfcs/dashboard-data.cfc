<cfcomponent output="false">
    <cfif ListFirst(CGI.SERVER_NAME,'.') EQ 'cmapps'>
        <cfset this.DBSERVER = "inside2_docmp" />
        <cfset this.DBUSER = "CONFROOM_USER" />
        <cfset this.DBPASS = "1DOCMAU4CNFRM6" />
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

        <!--- The calendar must never render a stale booking list. Refusing the
              cache here means callers do not need a cache-busting URL parameter,
              which a remote CFC method would reject outright. --->
        <cfheader name="Cache-Control" value="no-store, no-cache, must-revalidate" />
        <cfheader name="Pragma" value="no-cache" />

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
                    r.BUILDING || '.' || r.ROOM_NUMBER AS LOCATION,
                    r.CAPACITY,
                    b.START_TIME,
                    b.STATUS,
                    b.COMMENTS AS PURPOSE,
                    b.RECURRING_DETAILS,
                    b.BOOKED_FOR_NAME,
                    b.BOOKED_FOR_DEPARTMENT,
                    TO_CHAR(b.CREATED_AT, 'MM/DD/YYYY HH12:MI AM') AS SUBMITTEDAT,
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
                    "LOCATION": qryUpcoming.LOCATION,
                    "CAPACITY": qryUpcoming.CAPACITY,
                    "STATUS": qryUpcoming.STATUS,
                    "STARTDATE": qryUpcoming.STARTDATE,
                    "STARTTIME": qryUpcoming.STARTTIME,
                    "ENDDATE": qryUpcoming.ENDDATE,
                    "ENDTIME": qryUpcoming.ENDTIME,
                    "DESCRIPTION": qryUpcoming.DESCRIPTION,
                    "PURPOSE": qryUpcoming.PURPOSE,
                    "RECURRING_DETAILS": qryUpcoming.RECURRING_DETAILS,
                    "BOOKED_FOR_NAME": qryUpcoming.BOOKED_FOR_NAME,
                    "BOOKED_FOR_DEPARTMENT": qryUpcoming.BOOKED_FOR_DEPARTMENT,
                    "SUBMITTEDAT": qryUpcoming.SUBMITTEDAT
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

    <!---
        Look up an asserted user's role so callers can enforce business rules
        server-side. Note: this establishes *authorization* for a claimed
        identity, not authentication -- see the header comment on cancelBooking.
    --->
    <cffunction name="getUserAuthorization" access="private" returntype="struct" output="false">
        <cfargument name="userId" required="true" type="numeric">

        <cfset var result = { "found": false, "roleName": "", "isAdmin": false, "fullName": "", "email": "" }>
        <cfset var qryUser = "">

        <cfquery name="qryUser" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
            SELECT
                u.USER_ID,
                u.FIRST_NAME,
                u.LAST_NAME,
                u.EMAIL,
                u.STATUS,
                NVL(ro.ROLE_NAME, '') AS ROLE_NAME
            FROM #this.DBSCHEMA#.USERS u
            LEFT JOIN #this.DBSCHEMA#.ROLES ro ON ro.ROLE_ID = u.ROLE_ID
            WHERE u.USER_ID = <cfqueryparam value="#arguments.userId#" cfsqltype="cf_sql_numeric">
              AND UPPER(u.STATUS) = 'ACTIVE'
        </cfquery>

        <cfif qryUser.recordCount>
            <cfset result.found = true>
            <cfset result.roleName = qryUser.ROLE_NAME>
            <cfset result.isAdmin = ListFindNoCase("Admin,Site Admin", trim(qryUser.ROLE_NAME)) GT 0>
            <cfset result.fullName = trim(qryUser.FIRST_NAME & " " & qryUser.LAST_NAME)>
            <cfset result.email = qryUser.EMAIL>
        </cfif>

        <cfreturn result>
    </cffunction>

<!---
        Cancel a booking and notify the original requester.

        Authorization: the acting user must be the booking's requester or hold
        the Admin / Site Admin role. This is checked against the database rather
        than trusted from the caller.

        KNOWN GAP -- this app has no Application.cfc, so neither the session nor
        the application scope exists and Authenticate.cfc's session writes do not
        persist. `userId` therefore arrives as a client-supplied assertion that
        the server cannot authenticate. The role check below enforces the
        business rule but is not yet a security boundary: a caller who forges a
        different userId can still act as that user. Closing that gap requires
        Application.cfc with sessionManagement enabled. Tracked in
        docs/reservation-improvements-progress.md.
    --->
    <cffunction name="cancelBooking" access="remote" returntype="any" returnformat="JSON" output="false">
        <cfargument name="bookingid" required="true" type="numeric">
        <cfargument name="userId" required="true" type="numeric">
        <cfargument name="reason" required="false" type="string" default="">

        <cfset var qryGetBooking = "">
        <cfset var actor = "">
        <cfset var startTime = "">
        <cfset var endTime = "">
        <cfset var cancellingAgent = ".">
        <cfset var emailBody = "">
        <cfset var cleanReason = trim(arguments.reason)>
        <cfset var bookedForLine = "">
        <cfset var reasonLine = "">
        <cfset var detailUrl = "">

        <!--- Cancellation reasons are shown back to the requester; cap at the
              declared CANCELLATION_REASON VARCHAR2(1000) width. --->
        <cfif len(cleanReason) GT 1000>
            <cfset cleanReason = left(cleanReason, 1000)>
        </cfif>

        <cfquery name="qryGetBooking" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
           SELECT
                b.BOOKING_ID,
                b.USER_ID,
                b.ROOM_ID,
                b.STATUS,
                b.COMMENTS,
                b.BOOKED_FOR_NAME,
                b.BOOKED_FOR_EMAIL,
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

        <cfif NOT qryGetBooking.recordCount>
            <cfreturn { "status": "ERROR", "message": "Booking not found" }>
        </cfif>

        <cfset actor = getUserAuthorization(arguments.userId)>

        <cfif NOT actor.found>
            <cfreturn { "status": "ERROR", "message": "Cancelling user is not an active account" }>
        </cfif>

        <!--- Requester or admin only. --->
        <cfif arguments.userId NEQ qryGetBooking.USER_ID AND NOT actor.isAdmin>
            <cflog type="warning" file="booking_cancellations"
                   text="Denied cancellation of booking #arguments.bookingid# by user #arguments.userId# (role '#actor.roleName#'): not the requester and not an administrator.">
            <cfreturn { "status": "ERROR", "message": "You do not have permission to cancel this booking" }>
        </cfif>

        <!--- Already-cancelled bookings return success without re-notifying, so a
              double submit cannot produce a second cancellation email. --->
        <cfif ListFindNoCase("cancelled,canceled", trim(qryGetBooking.STATUS))>
            <cfreturn {
                "status": "SUCCESS",
                "message": "Booking was already cancelled",
                "alreadyCancelled": true
            }>
        </cfif>

        <!--- Record the cancellation in its own columns. COMMENTS holds the
              requester's meeting title and must not be overwritten. Guarded on
              status so two concurrent callers cannot both proceed to notify. --->
        <cfset var qryCancel = "">
        <cfquery name="qryCancel" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#" result="cancelResult">
            UPDATE #this.DBSCHEMA#.BOOKINGS
            SET STATUS = 'cancelled',
                CANCELLED_BY = <cfqueryparam value="#arguments.userId#" cfsqltype="cf_sql_numeric">,
                CANCELLED_AT = CURRENT_TIMESTAMP,
                CANCELLATION_REASON = <cfqueryparam value="#cleanReason#" cfsqltype="cf_sql_varchar" null="#!len(cleanReason)#">,
                UPDATED_AT = CURRENT_TIMESTAMP
            WHERE BOOKING_ID = <cfqueryparam value="#arguments.bookingid#" cfsqltype="cf_sql_numeric">
              AND LOWER(STATUS) NOT IN ('cancelled', 'canceled')
        </cfquery>

        <cfif structKeyExists(cancelResult, "recordCount") AND cancelResult.recordCount EQ 0>
            <!--- Another request cancelled it between our read and write. --->
            <cfreturn {
                "status": "SUCCESS",
                "message": "Booking was already cancelled",
                "alreadyCancelled": true
            }>
        </cfif>

        <!--- The booking is cancelled from here on. Notification is best-effort:
              every failure is logged and swallowed so the caller still sees the
              cancellation succeed. --->
        <cftry>
            <cfset startTime = ParseDateTime(qryGetBooking.START_TIME)>
            <cfset endTime = ParseDateTime(qryGetBooking.END_TIME)>

            <cfif arguments.userId NEQ qryGetBooking.USER_ID>
                <cfset cancellingAgent = " by #encodeForHTML(actor.fullName)#.">
            </cfif>

            <cfif len(trim(qryGetBooking.BOOKED_FOR_NAME))>
                <cfset bookedForLine = "<li><strong>Reservation For:</strong> " & encodeForHTML(qryGetBooking.BOOKED_FOR_NAME) & "</li>">
            </cfif>

            <cfif len(cleanReason)>
                <cfset reasonLine = "<li><strong>Reason:</strong> " & encodeForHTML(cleanReason) & "</li>">
            </cfif>

            <cfset detailUrl = "https://" & cgi.SERVER_NAME & "/" & ListFirst(CGI.SCRIPT_NAME, '/') & "/index.html?bookingId=" & qryGetBooking.BOOKING_ID>

            <cfsavecontent variable="emailBody">
                <cfoutput>
                <p>Dear #encodeForHTML(qryGetBooking.FIRST_NAME)#,</p>

                <p>Your reservation for "<strong>#encodeForHTML(qryGetBooking.ROOM_NAME)#</strong>" has been cancelled#cancellingAgent#</p>

                <p><strong>Details of the cancelled reservation:</strong></p>
                <ul>
                    <li><strong>Request Number:</strong> #qryGetBooking.BOOKING_ID#</li>
                    <li><strong>Room:</strong> #encodeForHTML(qryGetBooking.ROOM_NAME)#</li>
                    <li><strong>Location:</strong> #encodeForHTML(qryGetBooking.LOCATION)#</li>
                    #bookedForLine#
                    <li><strong>Date:</strong> #DateFormat(startTime, "dddd, mmmm dd, yyyy")#</li>
                    <li><strong>Time:</strong> #TimeFormat(startTime, "h:mm tt")# &ndash; #TimeFormat(endTime, "h:mm tt")#</li>
                    <li><strong>Status:</strong> Cancelled</li>
                    #reasonLine#
                </ul>

                <p><a href="#detailUrl#">View this reservation</a></p>

                <p>If you did not expect this cancellation, please contact the reservation team.</p>

                <p>Kind regards,<br />
                    <strong>DoCM Reservation System</strong>
                </p>
                </cfoutput>
            </cfsavecontent>

            <!--- In-app notification for the requester. --->
            <cftry>
                <cfquery datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                    INSERT INTO #this.DBSCHEMA#.NOTIFICATIONS (USER_ID, TYPE, CONTENT, STATUS, CREATED_AT)
                    VALUES (
                        <cfqueryparam value="#qryGetBooking.USER_ID#" cfsqltype="cf_sql_numeric">,
                        <cfqueryparam value="BOOKING_CANCELLATION" cfsqltype="cf_sql_varchar">,
                        <cfqueryparam value="#left('Reservation ##' & qryGetBooking.BOOKING_ID & ' for ' & qryGetBooking.ROOM_NAME & ' on ' & DateFormat(startTime, 'mm/dd/yyyy') & ' has been cancelled.' & (len(cleanReason) ? ' Reason: ' & cleanReason : ''), 1000)#" cfsqltype="cf_sql_varchar">,
                        <cfqueryparam value="Unread" cfsqltype="cf_sql_varchar">,
                        CURRENT_TIMESTAMP
                    )
                </cfquery>
            <cfcatch>
                <cflog type="error" file="booking_cancellations"
                       text="Booking #arguments.bookingid# cancelled but in-app notification insert failed: #cfcatch.message#">
            </cfcatch>
            </cftry>

            <!--- Respect the requester's email preference; default to sending if
                  the preference service is unavailable. --->
            <cfset var sendEmail = true>
            <cfset var notificationService = "">
            <cfset var adminEmails = "">

            <cftry>
                <cfset notificationService = createObject("component", "DoCMRoomReservation.assets.cfc.notifications")>
                <cfset var userPreferences = notificationService.shouldReceiveNotification(qryGetBooking.USER_ID, "BOOKING_CANCELLATION")>
                <cfset sendEmail = (isStruct(userPreferences) AND structKeyExists(userPreferences, "email") AND isBoolean(userPreferences.email) AND userPreferences.email)>
            <cfcatch>
                <cflog type="warning" file="booking_cancellations"
                       text="Preference lookup failed for booking #arguments.bookingid#; defaulting to send. #cfcatch.message#">
                <cfset sendEmail = true>
                <cfset notificationService = "">
            </cfcatch>
            </cftry>

            <cfif sendEmail>
                <!--- Only ask for admin CCs if the service actually loaded. The
                      previous version called this on an undefined variable
                      whenever the lookup above threw. --->
                <cfif isObject(notificationService)>
                    <cftry>
                        <cfset var qryAdminsToNotify = notificationService.getAdminsForNotification("BOOKING_CANCELLATION", "email")>
                        <cfloop query="qryAdminsToNotify">
                            <cfset adminEmails = ListAppend(adminEmails, qryAdminsToNotify.EMAIL)>
                        </cfloop>
                    <cfcatch>
                        <cflog type="warning" file="booking_cancellations"
                               text="Admin CC lookup failed for booking #arguments.bookingid#: #cfcatch.message#">
                    </cfcatch>
                    </cftry>
                </cfif>

                <cfmail to="#qryGetBooking.EMAIL#" from="NO-REPLY@mdanderson.org"
                        subject="Cancellation Confirmation - Reservation ###qryGetBooking.BOOKING_ID# - #qryGetBooking.ROOM_NAME#"
                        type="html" cc="#adminEmails#">
                    <cfmailpart type="text/html">
                        <cfoutput>#emailBody#</cfoutput>
                    </cfmailpart>
                </cfmail>
            </cfif>

        <cfcatch>
            <!--- Notification failure must never undo a completed cancellation. --->
            <cflog type="error" file="booking_cancellations"
                   text="Booking #arguments.bookingid# cancelled successfully but notification failed: #cfcatch.message# #cfcatch.detail#">
        </cfcatch>
        </cftry>

        <cfreturn {
            "status": "SUCCESS",
            "message": "Booking cancelled successfully"
        }>

    </cffunction>



    <!---
        Complete detail for a single reservation request, for the dashboard
        detail view. Optional fields come back as empty strings rather than
        nulls so the client never has to guard against missing keys.

        Administrative fields (who approved/cancelled it, created/modified-by)
        are only populated when the asserted user is the requester or holds an
        administrator role. Same authentication caveat as cancelBooking.
    --->
    <cffunction name="getBookingDetail" access="remote" returntype="any" returnformat="JSON" output="false">
        <cfargument name="bookingId" required="true" type="numeric">
        <cfargument name="userId" required="false" type="numeric" default="0">

        <cfset var retVal = {} />
        <cfset var qryDetail = "" />
        <cfset var actor = { "found": false, "isAdmin": false } />
        <cfset var canSeeAdminFields = false />
        <cfset var detail = {} />

        <cftry>
            <cfquery name="qryDetail" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT
                    b.BOOKING_ID,
                    b.USER_ID,
                    b.STATUS,
                    b.COMMENTS,
                    b.RECURRING_DETAILS,
                    b.BOOKED_FOR_NAME,
                    b.BOOKED_FOR_EMAIL,
                    b.BOOKED_FOR_DEPARTMENT,
                    b.CANCELLATION_REASON,
                    b.REVISION_NUMBER,
                    b.IS_MODIFIED,
                    TO_CHAR(b.CREATED_AT, 'MM/DD/YYYY HH12:MI AM') AS SUBMITTED_AT,
                    TO_CHAR(b.UPDATED_AT, 'MM/DD/YYYY HH12:MI AM') AS UPDATED_AT,
                    TO_CHAR(b.DECIDED_AT, 'MM/DD/YYYY HH12:MI AM') AS DECIDED_AT,
                    TO_CHAR(b.CANCELLED_AT, 'MM/DD/YYYY HH12:MI AM') AS CANCELLED_AT,
                    <!--- FM is a toggle in Oracle: one leading FM keeps fill mode
                          on for the rest of the mask. A second FM would switch it
                          back off and re-pad the month name. --->
                    TO_CHAR(b.START_TIME, 'FMDay, Month DD, YYYY') AS RESERVATION_DATE,
                    TO_CHAR(b.START_TIME, 'HH12:MI AM') AS START_TIME,
                    TO_CHAR(b.END_TIME, 'HH12:MI AM') AS END_TIME,
                    r.ROOM_NAME,
                    r.CAPACITY,
                    r.BUILDING || '.' || r.ROOM_NUMBER AS LOCATION,
                    req.FIRST_NAME || ' ' || req.LAST_NAME AS REQUESTED_BY,
                    req.EMAIL AS REQUESTED_BY_EMAIL,
                    NVL(decu.FIRST_NAME || ' ' || decu.LAST_NAME, '') AS DECIDED_BY_NAME,
                    NVL(canu.FIRST_NAME || ' ' || canu.LAST_NAME, '') AS CANCELLED_BY_NAME,
                    NVL(apru.FIRST_NAME || ' ' || apru.LAST_NAME, '') AS APPROVED_BY_NAME,
                    NVL(modu.FIRST_NAME || ' ' || modu.LAST_NAME, '') AS MODIFIED_BY_NAME
                FROM #this.DBSCHEMA#.BOOKINGS b
                JOIN #this.DBSCHEMA#.ROOMS r ON r.ROOM_ID = b.ROOM_ID
                JOIN #this.DBSCHEMA#.USERS req ON req.USER_ID = b.USER_ID
                LEFT JOIN #this.DBSCHEMA#.USERS decu ON decu.USER_ID = b.DECIDED_BY
                LEFT JOIN #this.DBSCHEMA#.USERS canu ON canu.USER_ID = b.CANCELLED_BY
                LEFT JOIN #this.DBSCHEMA#.USERS apru ON apru.USER_ID = b.APPROVED_BY
                LEFT JOIN #this.DBSCHEMA#.USERS modu ON modu.USER_ID = b.MODIFIED_BY
                WHERE b.BOOKING_ID = <cfqueryparam value="#arguments.bookingId#" cfsqltype="cf_sql_numeric">
            </cfquery>

            <cfif NOT qryDetail.recordCount>
                <cfset retVal["status"] = "error" />
                <cfset retVal["message"] = "Reservation not found" />
                <cfreturn retVal />
            </cfif>

            <cfif arguments.userId GT 0>
                <cfset actor = getUserAuthorization(arguments.userId) />
            </cfif>
            <cfset canSeeAdminFields = (actor.isAdmin OR (arguments.userId GT 0 AND arguments.userId EQ qryDetail.USER_ID)) />

            <cfset detail = {
                "BOOKING_ID": qryDetail.BOOKING_ID,
                "STATUS": qryDetail.STATUS,
                "REQUESTED_BY": qryDetail.REQUESTED_BY,
                "RESERVATION_FOR": len(trim(qryDetail.BOOKED_FOR_NAME)) ? qryDetail.BOOKED_FOR_NAME : qryDetail.REQUESTED_BY,
                "RESERVATION_FOR_RECORDED": len(trim(qryDetail.BOOKED_FOR_NAME)) GT 0,
                "DEPARTMENT": trim(qryDetail.BOOKED_FOR_DEPARTMENT),
                "ROOM_NAME": qryDetail.ROOM_NAME,
                "LOCATION": qryDetail.LOCATION,
                "CAPACITY": qryDetail.CAPACITY,
                "RESERVATION_DATE": trim(qryDetail.RESERVATION_DATE),
                "START_TIME": trim(qryDetail.START_TIME),
                "END_TIME": trim(qryDetail.END_TIME),
                "RECURRENCE": trim(qryDetail.RECURRING_DETAILS),
                "PURPOSE": trim(qryDetail.COMMENTS),
                "SUBMITTED_AT": trim(qryDetail.SUBMITTED_AT),
                "CANCELLATION_REASON": trim(qryDetail.CANCELLATION_REASON),
                "CANCELLED_AT": trim(qryDetail.CANCELLED_AT),
                "REVISION_NUMBER": val(qryDetail.REVISION_NUMBER),
                "IS_MODIFIED": trim(qryDetail.IS_MODIFIED)
            } />

            <!--- Who acted on the request is administrative detail. --->
            <cfif canSeeAdminFields>
                <cfset detail["REQUESTED_BY_EMAIL"] = qryDetail.REQUESTED_BY_EMAIL />
                <cfset detail["RESERVATION_FOR_EMAIL"] = trim(qryDetail.BOOKED_FOR_EMAIL) />
                <cfset detail["DECIDED_BY"] = trim(qryDetail.DECIDED_BY_NAME) />
                <cfset detail["DECIDED_AT"] = trim(qryDetail.DECIDED_AT) />
                <cfset detail["APPROVED_BY"] = trim(qryDetail.APPROVED_BY_NAME) />
                <cfset detail["CANCELLED_BY"] = trim(qryDetail.CANCELLED_BY_NAME) />
                <cfset detail["MODIFIED_BY"] = trim(qryDetail.MODIFIED_BY_NAME) />
                <cfset detail["LAST_UPDATED_AT"] = trim(qryDetail.UPDATED_AT) />
            </cfif>

            <cfset retVal["status"] = "success" />
            <cfset retVal["canSeeAdminFields"] = canSeeAdminFields />
            <cfset retVal["data"] = detail />

        <cfcatch>
            <cflog type="error" file="dashboard_data"
                   text="getBookingDetail failed for booking #arguments.bookingId#: #cfcatch.message# #cfcatch.detail#">
            <cfset retVal["status"] = "error" />
            <cfset retVal["message"] = "Unable to load reservation details" />
        </cfcatch>
        </cftry>

        <cfreturn retVal />
    </cffunction>

    <cffunction name="calculateRecurringDates" access="private" returntype="array" output="false">
        <cfargument name="startDate" required="true" type="date">
        <cfargument name="endDate" required="true" type="date">
        <cfargument name="recurringType" required="true" type="string">
        <cfargument name="maxOccurrences" required="false" type="numeric" default="52">
        
        <cfset var dates = [] />
        <cfset var currentDate = arguments.startDate />
        <cfset var currentEndDate = arguments.endDate />
        <cfset var occurrenceCount = 0 />
        <cfset var maxEndDate = DateAdd("yyyy", 1, arguments.startDate) />
        
        <cfloop condition="occurrenceCount LT arguments.maxOccurrences AND currentDate LTE maxEndDate">
            <cfset arrayAppend(dates, {
                "startDate": currentDate,
                "endDate": currentEndDate
            }) />
            <cfset occurrenceCount = occurrenceCount + 1 />
            
            <cfswitch expression="#UCase(arguments.recurringType)#">
                <cfcase value="DAILY">
                    <cfset currentDate = DateAdd("d", 1, currentDate) />
                    <cfset currentEndDate = DateAdd("d", 1, currentEndDate) />
                </cfcase>
                <cfcase value="WEEKLY">
                    <cfset currentDate = DateAdd("ww", 1, currentDate) />
                    <cfset currentEndDate = DateAdd("ww", 1, currentEndDate) />
                </cfcase>
                <cfcase value="BI-WEEKLY">
                    <cfset currentDate = DateAdd("ww", 2, currentDate) />
                    <cfset currentEndDate = DateAdd("ww", 2, currentEndDate) />
                </cfcase>
                <cfcase value="MONTHLY">
                    <cfset currentDate = DateAdd("m", 1, currentDate) />
                    <cfset currentEndDate = DateAdd("m", 1, currentEndDate) />
                </cfcase>
                <cfcase value="QUARTERLY">
                    <cfset currentDate = DateAdd("q", 1, currentDate) />
                    <cfset currentEndDate = DateAdd("q", 1, currentEndDate) />
                </cfcase>
                <cfcase value="SEMI-ANNUAL">
                    <cfset currentDate = DateAdd("m", 6, currentDate) />
                    <cfset currentEndDate = DateAdd("m", 6, currentEndDate) />
                </cfcase>
                <cfcase value="YEARLY">
                    <cfset currentDate = DateAdd("yyyy", 1, currentDate) />
                    <cfset currentEndDate = DateAdd("yyyy", 1, currentEndDate) />
                </cfcase>
                <cfdefaultcase>
                    <cfbreak />
                </cfdefaultcase>
            </cfswitch>
        </cfloop>
        
        <cfreturn dates />
    </cffunction>

    <cffunction name="createBooking" access="remote" returntype="any" returnformat="JSON" output="false">
        <cfargument name="employee_id" required="true" type="numeric">
        <cfargument name="user_id" required="true" type="numeric">
        <cfargument name="room_id" required="true" type="numeric">
        <cfargument name="start_time" required="true" type="string">
        <cfargument name="end_time" required="true" type="string">
        <cfargument name="recurring" required="false" type="string" default="NO">
        <cfargument name="recurring_type" required="false" type="string" default="DAILY">
        <cfargument name="comments" required="false" type="string" default="">
        <!--- "Reservation For" -- who the space is actually being reserved for.
              Left empty the reservation is for the requester themselves, which is
              the common case and must stay a zero-effort path. --->
        <cfargument name="booked_for_name" required="false" type="string" default="">
        <cfargument name="booked_for_email" required="false" type="string" default="">
        <cfargument name="booked_for_department" required="false" type="string" default="">

        <cfset var retVal = {} />
        <cfset var warnings = [] />
        <cfset var bookingIds = [] />
        <cfset var qryRequester = "" />
        <cfset var bookedForName = trim(arguments.booked_for_name) />
        <cfset var bookedForEmail = trim(arguments.booked_for_email) />
        <cfset var bookedForDept = trim(arguments.booked_for_department) />
        <cfset var bookedForIsSelf = true />
        
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

            <!--- Determine if this is a recurring booking --->
            <cfset var isRecurring = (UCase(arguments.recurring) EQ "YES" OR UCase(arguments.recurring) EQ "TRUE") />
            <cfset var recurringDetails = "" />
            <cfset var bookingDates = [] />
            
            <!--- Calculate booking dates (single or recurring) --->
            <cfif isRecurring>
                <cfset bookingDates = calculateRecurringDates(local.parsedStartTime, local.parsedEndTime, arguments.recurring_type) />
                <cfset recurringDetails = "Type: #arguments.recurring_type#, Created: #DateFormat(Now(), 'yyyy-mm-dd')#" />
            <cfelse>
                <!--- For extended single bookings, validate date range --->
                <cfset dateDifference = DateDiff("d", local.parsedStartTime, local.parsedEndTime) />
                <cfif dateDifference GT 365>
                    <cfset retVal["status"] = "error" />
                    <cfset retVal["data"] = {"message": "Maximum booking duration is 365 days"} />
                    <cfreturn retVal />
                </cfif>
                
                <cfset arrayAppend(bookingDates, {
                    "startDate": local.parsedStartTime,
                    "endDate": local.parsedEndTime
                }) />
            </cfif>
            
            <!--- Get room information for better error messages --->
            <cfquery name="qryRoomInfo" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT
                    ROOM_NAME,
                    BUILDING,
                    ROOM_NUMBER,
                    (BUILDING || ' ' || ROOM_NUMBER) AS LOCATION
                FROM #this.DBSCHEMA#.ROOMS
                WHERE ROOM_ID = <cfqueryparam value="#arguments.room_id#" cfsqltype="cf_sql_numeric">
            </cfquery>

            <!--- Resolve "Reservation For". The requester is always recorded in
                  USER_ID; these columns only say who the space is for. --->
            <cfquery name="qryRequester" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT FIRST_NAME, LAST_NAME, EMAIL
                FROM #this.DBSCHEMA#.USERS
                WHERE USER_ID = <cfqueryparam value="#arguments.user_id#" cfsqltype="cf_sql_numeric">
            </cfquery>

            <cfif NOT qryRequester.recordCount>
                <cfset retVal["status"] = "error" />
                <cfset retVal["data"] = {"message": "The requesting user account could not be found."} />
                <cfreturn retVal />
            </cfif>

            <!--- Default to the authenticated requester when nothing was supplied. --->
            <cfif NOT len(bookedForName) AND NOT len(bookedForEmail)>
                <cfset bookedForName = trim(qryRequester.FIRST_NAME & " " & qryRequester.LAST_NAME) />
                <cfset bookedForEmail = qryRequester.EMAIL />
                <cfset bookedForIsSelf = true />
            <cfelse>
                <cfset bookedForIsSelf = (compareNoCase(bookedForEmail, trim(qryRequester.EMAIL)) EQ 0) />

                <!--- A name is required whenever booking on someone else's behalf,
                      otherwise the approver has nothing to act on. --->
                <cfif NOT len(bookedForName)>
                    <cfset retVal["status"] = "error" />
                    <cfset retVal["data"] = {"message": "Please provide the name of the person this reservation is for."} />
                    <cfreturn retVal />
                </cfif>

                <cfif len(bookedForEmail) AND NOT isValid("email", bookedForEmail)>
                    <cfset retVal["status"] = "error" />
                    <cfset retVal["data"] = {"message": "The email address for the person this reservation is for is not valid."} />
                    <cfreturn retVal />
                </cfif>
            </cfif>

            <!--- Keep inserts inside the declared VARCHAR2 sizes:
                  BOOKED_FOR_NAME(200), BOOKED_FOR_EMAIL(255), BOOKED_FOR_DEPARTMENT(100). --->
            <cfset bookedForName = left(bookedForName, 200) />
            <cfset bookedForEmail = left(bookedForEmail, 255) />
            <cfset bookedForDept = left(bookedForDept, 100) />

            <!--- Check availability for all dates before creating any bookings --->
            <cfset var conflictDates = [] />
            <cfset var conflictDetails = [] />
            <cfloop array="#bookingDates#" index="dateSlot">
                <cfquery name="qryCheckAvailability" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                    SELECT 
                        COUNT(*) as conflict_count,
                        MIN(TO_CHAR(START_TIME, 'HH12:MI AM')) as earliest_start,
                        MAX(TO_CHAR(END_TIME, 'HH12:MI AM')) as latest_end
                    FROM #this.DBSCHEMA#.BOOKINGS
                    WHERE ROOM_ID = <cfqueryparam value="#arguments.room_id#" cfsqltype="cf_sql_numeric">
                    AND LOWER(STATUS) IN('approved', 'pending')
                    AND (
                        (START_TIME BETWEEN 
                            TO_DATE(<cfqueryparam value="#DateFormat(dateSlot.startDate, 'yyyy-mm-dd')# #TimeFormat(dateSlot.startDate, 'HH:mm')#" cfsqltype="cf_sql_varchar">, 'YYYY-MM-DD HH24:MI')
                            AND TO_DATE(<cfqueryparam value="#DateFormat(dateSlot.endDate, 'yyyy-mm-dd')# #TimeFormat(dateSlot.endDate, 'HH:mm')#" cfsqltype="cf_sql_varchar">, 'YYYY-MM-DD HH24:MI'))
                        OR (END_TIME BETWEEN 
                            TO_DATE(<cfqueryparam value="#DateFormat(dateSlot.startDate, 'yyyy-mm-dd')# #TimeFormat(dateSlot.startDate, 'HH:mm')#" cfsqltype="cf_sql_varchar">, 'YYYY-MM-DD HH24:MI')
                            AND TO_DATE(<cfqueryparam value="#DateFormat(dateSlot.endDate, 'yyyy-mm-dd')# #TimeFormat(dateSlot.endDate, 'HH:mm')#" cfsqltype="cf_sql_varchar">, 'YYYY-MM-DD HH24:MI'))
                        OR (START_TIME <= TO_DATE(<cfqueryparam value="#DateFormat(dateSlot.startDate, 'yyyy-mm-dd')# #TimeFormat(dateSlot.startDate, 'HH:mm')#" cfsqltype="cf_sql_varchar">, 'YYYY-MM-DD HH24:MI')
                            AND END_TIME >= TO_DATE(<cfqueryparam value="#DateFormat(dateSlot.endDate, 'yyyy-mm-dd')# #TimeFormat(dateSlot.endDate, 'HH:mm')#" cfsqltype="cf_sql_varchar">, 'YYYY-MM-DD HH24:MI'))
                    )
                </cfquery>
                
                <cfif qryCheckAvailability.conflict_count GT 0>
                    <cfset arrayAppend(conflictDates, DateFormat(dateSlot.startDate, 'yyyy-mm-dd')) />
                    <cfset arrayAppend(conflictDetails, {
                        "date": DateFormat(dateSlot.startDate, 'dddd, mmmm dd, yyyy'),
                        "requestedTime": TimeFormat(dateSlot.startDate, 'h:mm tt') & ' - ' & TimeFormat(dateSlot.endDate, 'h:mm tt'),
                        "conflictTime": qryCheckAvailability.earliest_start & ' - ' & qryCheckAvailability.latest_end
                    }) />
                </cfif>
            </cfloop>
            
            <!--- If any conflicts found, return error --->
            <cfif arrayLen(conflictDates) GT 0>
                <cfset retVal["status"] = "error" />
                <cfset var roomName = qryRoomInfo.RecordCount GT 0 ? qryRoomInfo.ROOM_NAME : "Selected room" />
                <cfset var roomLocation = qryRoomInfo.RecordCount GT 0 ? qryRoomInfo.LOCATION : "" />
                <cfset var fullRoomInfo = roomName & (len(trim(roomLocation)) GT 0 ? " (" & roomLocation & ")" : "") />
                
                <cfif arrayLen(conflictDates) EQ 1>
                    <cfset var conflict = conflictDetails[1] />
                    <cfset retVal["data"] = {"message": "#fullRoomInfo# is not available on #conflict.date# from #conflict.requestedTime#. The room is already booked during #conflict.conflictTime#. Please choose a different time or room."} />
                <cfelse>
                    <cfset var detailedMessage = "#fullRoomInfo# is not available for the following dates:" />
                    <cfloop array="#conflictDetails#" index="i" item="conflict">
                        <cfset detailedMessage &= chr(10) & "• #conflict.date# from #conflict.requestedTime# (conflicting booking: #conflict.conflictTime#)" />
                    </cfloop>
                    <cfset detailedMessage &= chr(10) & chr(10) & "Please choose different dates and times, or select an available room." />
                    <cfset retVal["data"] = {"message": detailedMessage} />
                </cfif>
                <cfreturn retVal />
            </cfif>
            
            <!--- Create all bookings --->
            <cfloop array="#bookingDates#" index="dateSlot">
                <cfquery name="qryCreateBooking" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                    INSERT INTO #this.DBSCHEMA#.BOOKINGS (
                        USER_ID, ROOM_ID, START_TIME, END_TIME,
                        RECURRING_DETAILS, STATUS, COMMENTS, CREATED_AT, UPDATED_AT,
                        BOOKED_FOR_NAME, BOOKED_FOR_EMAIL, BOOKED_FOR_DEPARTMENT
                    )
                    VALUES (
                    <cfqueryparam value="#arguments.user_id#" cfsqltype="cf_sql_numeric">,
                    <cfqueryparam value="#arguments.room_id#" cfsqltype="cf_sql_numeric">,
                    TO_DATE(<cfqueryparam value="#DateFormat(dateSlot.startDate, 'yyyy-mm-dd')# #TimeFormat(dateSlot.startDate, 'HH:mm')#" cfsqltype="cf_sql_varchar">, 'YYYY-MM-DD HH24:MI'),
                    TO_DATE(<cfqueryparam value="#DateFormat(dateSlot.endDate, 'yyyy-mm-dd')# #TimeFormat(dateSlot.endDate, 'HH:mm')#" cfsqltype="cf_sql_varchar">, 'YYYY-MM-DD HH24:MI'),
                    <cfqueryparam value="#recurringDetails#" cfsqltype="cf_sql_varchar" null="#!len(trim(recurringDetails))#">,
                    'pending',
                    <cfqueryparam value="#arguments.comments#" cfsqltype="cf_sql_varchar" null="#!len(trim(arguments.comments))#">,
                    CURRENT_TIMESTAMP,
                    CURRENT_TIMESTAMP,
                    <cfqueryparam value="#bookedForName#" cfsqltype="cf_sql_varchar" null="#!len(bookedForName)#">,
                    <cfqueryparam value="#bookedForEmail#" cfsqltype="cf_sql_varchar" null="#!len(bookedForEmail)#">,
                    <cfqueryparam value="#bookedForDept#" cfsqltype="cf_sql_varchar" null="#!len(bookedForDept)#">
                    )
                </cfquery>
                
                <cfquery name="qryGetBookingID" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                    SELECT MAX(BOOKING_ID) AS booking_id
                    FROM #this.DBSCHEMA#.BOOKINGS
                </cfquery>
                
                <cfset arrayAppend(bookingIds, qryGetBookingID.booking_id) />
            </cfloop>
            
            <!--- Get the first booking for email notification --->
            <cfquery name="qryGetBookingID" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT BOOKING_ID as booking_id
                FROM #this.DBSCHEMA#.BOOKINGS
                WHERE BOOKING_ID = <cfqueryparam value="#bookingIds[1]#" cfsqltype="cf_sql_numeric">
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
                    TO_CHAR(b.END_TIME, 'YYYY-MM-DD HH24:MI:SS') AS END_TIME,
                    b.COMMENTS
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

            <cfset var bookingDetails = {
                bookingId = qryGetBooking.BOOKING_ID,
                requesterId = qryGetBooking.USER_ID,
                requesterName = trim(qryGetBooking.FIRST_NAME & " " & qryGetBooking.LAST_NAME),
                requesterEmail = qryGetBooking.EMAIL,
                roomId = qryGetBooking.ROOM_ID,
                roomName = qryGetBooking.ROOM_NAME,
                location = qryGetBooking.LOCATION,
                startTime = startTime,
                endTime = endTime,
                meetingTitle = qryGetBooking.COMMENTS,
                submittedAt = now(),
                bookedForName = bookedForName,
                bookedForEmail = bookedForEmail,
                bookedForDepartment = bookedForDept,
                bookedForIsSelf = bookedForIsSelf
            }>

            <cftry>
                <cfset var approvalNotificationService = createObject("component", "components.ApprovalNotification").init(this.DBSERVER)>
                <cfset var approvalNotificationResult = approvalNotificationService.sendPendingApprovalAlert(bookingDetails = bookingDetails)>
                <cfif NOT approvalNotificationResult.success>
                    <cfset arrayAppend(warnings, {
                        message = "Approval notification dispatch partially failed",
                        detail = serializeJSON(approvalNotificationResult)
                    })>
                </cfif>
            <cfcatch>
                <cfset arrayAppend(warnings, {
                    message = "Approval notification dispatch error",
                    detail = cfcatch.message
                })>
            </cfcatch>
            </cftry>

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
            <!--- Wrap ICS generation and email sending to prevent breaking JSON response --->
            <cftry>
                <!--- Join array with CRLF and create file --->
                <cfset var icsFileName = "booking_#qryGetBooking.BOOKING_ID#.ics">
                <cfset var icsFilePath = ExpandPath("../assets/temp/#icsFileName#")>
                <cfset var finalContent = arrayToList(icsContent, chr(13) & chr(10))>

                <!--- Write the ICS file --->
                <cffile action="write" file="#icsFilePath#" output="#finalContent#" charset="utf-8">
                <!--- <p>Thank you for your reservation! We're happy to confirm that your office space (#qryGetBooking.ROOM_NAME#) is successfully booked.</p>--->

                <!--- Build calendar link URLs outside of cfoutput --->
                <cfset var calendarLinkURL = "https://#cgi.SERVER_NAME#:#cgi.SERVER_PORT#/#ListFirst(CGI.SCRIPT_NAME,'/')#/assets/temp/#icsFileName#" />
                
                <!--- Build email body using cfoutput properly --->
                <cfsavecontent variable="emailBody">
                <cfoutput>
                     <h2>BOOKING CONFIRMATION - PENDING APPROVAL</h2>

                    <p>Greetings, #qryGetBooking.FIRST_NAME#,</p>

                    <p>Thank you for making a reservation! Your request for office space (#qryGetBooking.ROOM_NAME#) has been received and is pending approval.</p>
                    <p>Below are the details of your reservation:</p>
                    
                    <h3>Reservation Details:</h3>
                    <ul>
                        <li><strong>Location:</strong> #qryGetBooking.LOCATION#</li>
                        <li><strong>Room:</strong> #qryGetBooking.ROOM_NAME#</li>
                        <cfif NOT bookedForIsSelf AND len(bookedForName)>
                            <li><strong>Reservation For:</strong> #HTMLEditFormat(bookedForName)#<cfif len(bookedForDept)> (#HTMLEditFormat(bookedForDept)#)</cfif></li>
                            <li><strong>Requested By:</strong> #HTMLEditFormat(trim(qryGetBooking.FIRST_NAME & " " & qryGetBooking.LAST_NAME))#</li>
                        </cfif>
                        <cfif len(trim(qryGetBooking.COMMENTS))>
                            <li><strong>Meeting Title:</strong> #HTMLEditFormat(qryGetBooking.COMMENTS)#</li>
                        </cfif>
                        <li><strong>Starting On:</strong> #DateFormat(startTime, "dddd, mmmm dd, yyyy")# at #TimeFormat(startTime, "h:mm tt")# </li>
                        <li><strong>Ending On:</strong> #DateFormat(endTime, "dddd, mmmm dd, yyyy")# at #TimeFormat(endTime, "h:mm tt")# </li>
                        <li><strong>Booking ID:</strong> #qryGetBooking.BOOKING_ID#</li>
                        <li><strong>Add to Calendar:</strong> <a href="#calendarLinkURL#" target="_blank">Add to Calendar</a> | <a href="#calendarLinkURL#">Download iCalendar</a></li>
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
                </cfsavecontent>
                <!--- Check if user should receive booking confirmation email --->
                <cfset notificationService = createObject("component", "DoCMRoomReservation.assets.cfc.notifications") />
                <cfset userPreferences = notificationService.shouldReceiveNotification(qryGetBooking.USER_ID, "BOOKING_CONFIRMATION") />
                
                <!--- Only send email if user has email notifications enabled for booking confirmations --->
                <cfif userPreferences.email>
                        <cfmail to="#qryGetBooking.EMAIL#" from="NO-REPLY@mdanderson.org" 
                                subject="Office Space Reservation - Pending Approval" type="html">
                            <cfmailpart type="text/html">
                                <cfoutput>#emailBody#</cfoutput>
                            </cfmailpart>
                        </cfmail>
                </cfif>
            <cfcatch type="any">
                <!--- Do not fail booking if ICS or email fails; collect warning --->
                <cfset arrayAppend(warnings, {
                    message = "Post-booking notification failed",
                    detail = cfcatch.message
                })>
            </cfcatch>
            </cftry>



            <cfset retVal["status"] = "success">
            <cfif isRecurring>
                <cfset retVal["data"] = {
                    "message": "Recurring booking created successfully! #arrayLen(bookingIds)# bookings were created. Please check your email for confirmation.",
                    "bookingCount": arrayLen(bookingIds),
                    "bookingIds": bookingIds,
                    "recurringType": arguments.recurring_type
                }>
            <cfelse>
                <cfset retVal["data"] = {
                    "message": "Booking created successfully, please check your email for confirmation",
                    "bookingCount": 1,
                    "bookingIds": bookingIds
                }>
            </cfif>
            <!--- Include warnings if any --->
            <cfif arrayLen(warnings)>
                <cfset retVal["warnings"] = warnings>
            </cfif>
  
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