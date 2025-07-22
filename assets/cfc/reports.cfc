<cfcomponent output="false">
        <!--- Database configuration based on server environment --->
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
    <!--- Get Quick Stats --->
    <cffunction name="getQuickStats" access="remote" returntype="struct" returnformat="json">
        <cfset var stats = {}>
        
        <!--- Get Total Bookings --->
        <cfquery name="qTotalBookings" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
            SELECT COUNT(*) as total_bookings
            FROM BOOKINGS
            WHERE STATUS = 'Confirmed'
            AND START_TIME >= TRUNC(SYSDATE) - 30
        </cfquery>
        
        <!--- Get Active Users --->
        <cfquery name="qActiveUsers" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
            SELECT COUNT(DISTINCT USER_ID) as active_users
            FROM BOOKINGS
            WHERE START_TIME >= TRUNC(SYSDATE) - 30
            AND STATUS = 'Confirmed'
        </cfquery>
        
        <!--- Get Room Utilization --->
        <cfquery name="qRoomUtilization" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
            SELECT 
                (SUM(EXTRACT(HOUR FROM (END_TIME - START_TIME)) * 60 + 
                 EXTRACT(MINUTE FROM (END_TIME - START_TIME))) /
                (COUNT(DISTINCT ROOM_ID) * 24 * 60)) * 100 as utilization_rate
            FROM BOOKINGS
            WHERE START_TIME >= TRUNC(SYSDATE)
            AND STATUS = 'Confirmed'
        </cfquery>
        
        <!--- Get Average Rating --->
        <cfquery name="qAvgRating" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
            SELECT AVG(RATING) as avg_rating
            FROM ROOM_RATINGS
            WHERE CREATED_AT >= TRUNC(SYSDATE) - 30
        </cfquery>
        
        <cfset stats = {
            "totalBookings": qTotalBookings.total_bookings,
            "activeUsers": qActiveUsers.active_users,
            "roomUtilization": NumberFormat(qRoomUtilization.utilization_rate, "99.9"),
            "avgRating": qAvgRating.avg_rating
        }>
        
        <cfreturn stats>
    </cffunction>
    
    <!--- Get Booking Trends --->
    <cffunction name="getBookingTrends" access="remote" returntype="struct" returnformat="json">
        <cfset var labels = []>
        <cfset var data = []>
        
        <cfquery name="qBookingTrends" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
            SELECT 
                TRUNC(START_TIME) as booking_date,
                COUNT(*) as total_bookings
            FROM BOOKINGS
            WHERE START_TIME >= TRUNC(SYSDATE) - 30
            AND STATUS = 'Confirmed'
            GROUP BY TRUNC(START_TIME)
            ORDER BY booking_date
        </cfquery>
        
        <cfset var labels = []>
        <cfset var data = []>
        
        <cfloop query="qBookingTrends">
            <cfset ArrayAppend(labels, DateFormat(booking_date, "mmm dd"))>
            <cfset ArrayAppend(data, total_bookings)>
        </cfloop>
        
        <cfreturn {
            "labels": labels,
            "data": data
        }>
    </cffunction>
    
    <!--- Get Room Usage Distribution --->
    <cffunction name="getRoomUsage" access="remote" returntype="struct" returnformat="json">
        <cfset var labels = []>
        <cfset var data = []>
        
        <cfquery name="qRoomUsage" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
            SELECT 
                r.ROOM_NAME,
                COUNT(b.BOOKING_ID) as booking_count
            FROM ROOMS r
            LEFT JOIN BOOKINGS b ON r.ROOM_ID = b.ROOM_ID
            WHERE b.START_TIME >= TRUNC(SYSDATE) - 30
            AND b.STATUS = 'Confirmed'
            GROUP BY r.ROOM_NAME
            ORDER BY booking_count DESC
        </cfquery>
        
        <cfset var labels = []>
        <cfset var data = []>
        
        <cfloop query="qRoomUsage">
            <cfset ArrayAppend(labels, ROOM_NAME)>
            <cfset ArrayAppend(data, booking_count)>
        </cfloop>
        
        <cfreturn {
            "labels": labels,
            "data": data
        }>
    </cffunction>
    
    <!--- Get Room Ratings --->
    <cffunction name="getRoomRatings" access="remote" returntype="array" returnformat="json">
        <cfset var ratings = []>
        
        <cfquery name="qRoomRatings" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
            SELECT 
                r.ROOM_NAME,
                AVG(rr.RATING) as avg_rating,
                COUNT(rr.RATING_ID) as total_reviews,
                (SELECT AVG(RATING) 
                 FROM ROOM_RATINGS 
                 WHERE ROOM_ID = r.ROOM_ID 
                 AND CREATED_AT >= TRUNC(SYSDATE) - 7) -
                (SELECT AVG(RATING) 
                 FROM ROOM_RATINGS 
                 WHERE ROOM_ID = r.ROOM_ID 
                 AND CREATED_AT >= TRUNC(SYSDATE) - 14 
                 AND CREATED_AT < TRUNC(SYSDATE) - 7) as rating_trend
            FROM ROOMS r
            LEFT JOIN ROOM_RATINGS rr ON r.ROOM_ID = rr.ROOM_ID
            GROUP BY r.ROOM_ID, r.ROOM_NAME
            ORDER BY avg_rating DESC
        </cfquery>
        
        <cfset var ratings = []>
        
        <cfloop query="qRoomRatings">
            <cfset ArrayAppend(ratings, {
                "name": ROOM_NAME,
                "avgRating": avg_rating,
                "totalReviews": total_reviews,
                "trend": rating_trend
            })>
        </cfloop>
        
        <cfreturn ratings>
    </cffunction>
    
    <!--- Get Maintenance Status --->
    <cffunction name="getMaintenanceStatus" access="remote" returntype="array" returnformat="json">
        <cfset var maintenance = []>
        
        <cfquery name="qMaintenanceStatus" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
            SELECT 
                r.ROOM_NAME,
                m.STATUS,
                MAX(CASE WHEN m.STATUS = 'Completed' THEN m.END_TIME END) as last_maintenance,
                MIN(CASE WHEN m.STATUS = 'Scheduled' THEN m.START_TIME END) as next_scheduled
            FROM ROOMS r
            LEFT JOIN MAINTENANCE m ON r.ROOM_ID = m.ROOM_ID
            GROUP BY r.ROOM_ID, r.ROOM_NAME, m.STATUS
            ORDER BY r.ROOM_NAME
        </cfquery>
        
        <cfset var maintenance = []>
        
        <cfloop query="qMaintenanceStatus">
            <cfset ArrayAppend(maintenance, {
                "name": ROOM_NAME,
                "status": STATUS,
                "lastMaintenance": DateTimeFormat(last_maintenance, "mmm dd, yyyy"),
                "nextScheduled": DateTimeFormat(next_scheduled, "mmm dd, yyyy")
            })>
        </cfloop>
        
        <cfreturn maintenance>
    </cffunction>

</cfcomponent>
