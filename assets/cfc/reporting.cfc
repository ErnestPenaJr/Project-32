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
    <!--- Get Dashboard Data --->
    <cffunction name="getDashboardData" access="remote" returntype="struct" returnformat="JSON">
        <cfargument name="period" type="string" required="true">
        
        <cfset var result = {
            "stats": {},
            "chartData": {},
            "tableData": {}
        }>
        
        <!--- Get date range based on period --->
        <cfset var dateRange = getDateRange(arguments.period)>
        
        <!--- Get overview statistics --->
        <cfset result.stats = getOverviewStats(dateRange.startDate, dateRange.endDate)>
        
        <!--- Get chart data --->
        <cfset result.chartData = getChartData(dateRange.startDate, dateRange.endDate, arguments.period)>
        
        <!--- Get table data --->
        <cfset result.tableData = getTableData(dateRange.startDate, dateRange.endDate)>
        
        <cfreturn result>
    </cffunction>
    
    <!--- Get Overview Statistics --->
    <cffunction name="getOverviewStats" access="private" returntype="struct">
        <cfargument name="startDate" type="date" required="true">
        <cfargument name="endDate" type="date" required="true">
        
        <cfquery name="qStats" datasource="your_datasource">
            SELECT 
                COUNT(*) as total_reservations,
                COUNT(DISTINCT user_id) as active_users,
                ROUND(AVG(CASE 
                    WHEN status != 'Cancelled' THEN 1 
                    ELSE 0 
                END) * 100, 2) as utilization_rate,
                ROUND(AVG(CASE 
                    WHEN status = 'Cancelled' THEN 1 
                    ELSE 0 
                END) * 100, 2) as cancellation_rate
            FROM bookings
            WHERE start_time BETWEEN <cfqueryparam value="#arguments.startDate#" cfsqltype="CF_SQL_TIMESTAMP">
                AND <cfqueryparam value="#arguments.endDate#" cfsqltype="CF_SQL_TIMESTAMP">
        </cfquery>
        
        <!--- Get trend percentages by comparing with previous period --->
        <cfset var prevStartDate = DateAdd("d", -DateDiff("d", arguments.startDate, arguments.endDate), arguments.startDate)>
        <cfset var prevEndDate = DateAdd("d", -1, arguments.startDate)>
        
        <cfquery name="qPrevStats" datasource="your_datasource">
            SELECT COUNT(*) as total_reservations,
                   COUNT(DISTINCT user_id) as active_users
            FROM bookings
            WHERE start_time BETWEEN <cfqueryparam value="#prevStartDate#" cfsqltype="CF_SQL_TIMESTAMP">
                AND <cfqueryparam value="#prevEndDate#" cfsqltype="CF_SQL_TIMESTAMP">
        </cfquery>
        
        <cfset var stats = {
            "totalReservations": qStats.total_reservations,
            "activeUsers": qStats.active_users,
            "roomUtilization": qStats.utilization_rate,
            "cancellationRate": qStats.cancellation_rate,
            "reservationTrend": calculateTrendPercentage(qStats.total_reservations, qPrevStats.total_reservations),
            "usersTrend": calculateTrendPercentage(qStats.active_users, qPrevStats.active_users),
            "utilizationTrend": 0,
            "cancellationTrend": 0
        }>
        
        <cfreturn stats>
    </cffunction>
    
    <!--- Get Chart Data --->
    <cffunction name="getChartData" access="private" returntype="struct">
        <cfargument name="startDate" type="date" required="true">
        <cfargument name="endDate" type="date" required="true">
        <cfargument name="period" type="string" required="true">
        
        <cfset var chartData = {
            "trends": {"labels": [], "data": []},
            "distribution": {"labels": [], "data": []}
        }>
        
        <!--- Get reservation trends --->
        <cfquery name="qTrends" datasource="your_datasource">
            SELECT 
                <cfif arguments.period EQ "daily">
                    TRUNC(start_time, 'HH24') as time_period
                <cfelseif arguments.period EQ "weekly">
                    TRUNC(start_time, 'IW') as time_period
                <cfelse>
                    TRUNC(start_time, 'MM') as time_period
                </cfif>,
                COUNT(*) as reservation_count
            FROM bookings
            WHERE start_time BETWEEN <cfqueryparam value="#arguments.startDate#" cfsqltype="CF_SQL_TIMESTAMP">
                AND <cfqueryparam value="#arguments.endDate#" cfsqltype="CF_SQL_TIMESTAMP">
            GROUP BY 
                <cfif arguments.period EQ "daily">
                    TRUNC(start_time, 'HH24')
                <cfelseif arguments.period EQ "weekly">
                    TRUNC(start_time, 'IW')
                <cfelse>
                    TRUNC(start_time, 'MM')
                </cfif>
            ORDER BY time_period
        </cfquery>
        
        <cfloop query="qTrends">
            <cfset ArrayAppend(chartData.trends.labels, DateFormat(time_period, "mm/dd"))>
            <cfset ArrayAppend(chartData.trends.data, reservation_count)>
        </cfloop>
        
        <!--- Get room distribution --->
        <cfquery name="qDistribution" datasource="your_datasource">
            SELECT r.room_name,
                   COUNT(b.booking_id) as booking_count
            FROM rooms r
            LEFT JOIN bookings b ON r.room_id = b.room_id
            WHERE b.start_time BETWEEN <cfqueryparam value="#arguments.startDate#" cfsqltype="CF_SQL_TIMESTAMP">
                AND <cfqueryparam value="#arguments.endDate#" cfsqltype="CF_SQL_TIMESTAMP">
            GROUP BY r.room_name
            ORDER BY booking_count DESC
        </cfquery>
        
        <cfloop query="qDistribution">
            <cfset ArrayAppend(chartData.distribution.labels, room_name)>
            <cfset ArrayAppend(chartData.distribution.data, booking_count)>
        </cfloop>
        
        <cfreturn chartData>
    </cffunction>
    
    <!--- Get Table Data --->
    <cffunction name="getTableData" access="private" returntype="struct">
        <cfargument name="startDate" type="date" required="true">
        <cfargument name="endDate" type="date" required="true">
        
        <cfset var tableData = {
            "rooms": [],
            "users": []
        }>
        
        <!--- Get room statistics --->
        <cfquery name="qRooms" datasource="your_datasource">
            SELECT r.room_name,
                   COUNT(b.booking_id) as total_bookings,
                   ROUND(AVG(CASE WHEN b.status != 'Cancelled' THEN 1 ELSE 0 END) * 100, 2) as utilization_rate,
                   ROUND(AVG(rt.rating), 2) as average_rating,
                   r.maintenance_status
            FROM rooms r
            LEFT JOIN bookings b ON r.room_id = b.room_id
            LEFT JOIN room_ratings rt ON b.booking_id = rt.booking_id
            WHERE b.start_time BETWEEN <cfqueryparam value="#arguments.startDate#" cfsqltype="CF_SQL_TIMESTAMP">
                AND <cfqueryparam value="#arguments.endDate#" cfsqltype="CF_SQL_TIMESTAMP">
            GROUP BY r.room_name, r.maintenance_status
            ORDER BY total_bookings DESC
        </cfquery>
        
        <cfloop query="qRooms">
            <cfset ArrayAppend(tableData.rooms, {
                "name": room_name,
                "totalBookings": total_bookings,
                "utilizationRate": utilization_rate,
                "averageRating": average_rating,
                "status": maintenance_status EQ 'NO' ? 'Available' : 'Maintenance'
            })>
        </cfloop>
        
        <!--- Get user statistics --->
        <cfquery name="qUsers" datasource="your_datasource">
            SELECT u.first_name || ' ' || u.last_name as full_name,
                   COUNT(b.booking_id) as total_bookings,
                   ROUND(AVG((EXTRACT(EPOCH FROM b.end_time) - EXTRACT(EPOCH FROM b.start_time))/3600), 2) as avg_duration,
                   MAX(b.start_time) as last_active,
                   (
                       SELECT r.room_name
                       FROM bookings b2
                       JOIN rooms r ON b2.room_id = r.room_id
                       WHERE b2.user_id = u.user_id
                       GROUP BY r.room_name
                       ORDER BY COUNT(*) DESC
                       FETCH FIRST 1 ROW ONLY
                   ) as preferred_room
            FROM users u
            LEFT JOIN bookings b ON u.user_id = b.user_id
            WHERE b.start_time BETWEEN <cfqueryparam value="#arguments.startDate#" cfsqltype="CF_SQL_TIMESTAMP">
                AND <cfqueryparam value="#arguments.endDate#" cfsqltype="CF_SQL_TIMESTAMP">
            GROUP BY u.user_id, u.first_name, u.last_name
            ORDER BY total_bookings DESC
        </cfquery>
        
        <cfloop query="qUsers">
            <cfset ArrayAppend(tableData.users, {
                "name": full_name,
                "totalBookings": total_bookings,
                "avgDuration": avg_duration,
                "preferredRoom": preferred_room,
                "lastActive": DateFormat(last_active, "mm/dd/yyyy")
            })>
        </cfloop>
        
        <cfreturn tableData>
    </cffunction>
    
    <!--- Helper Functions --->
    <cffunction name="getDateRange" access="private" returntype="struct">
        <cfargument name="period" type="string" required="true">
        
        <cfset var now = Now()>
        <cfset var result = {}>
        
        <cfswitch expression="#arguments.period#">
            <cfcase value="daily">
                <cfset result.startDate = CreateDateTime(Year(now), Month(now), Day(now), 0, 0, 0)>
                <cfset result.endDate = CreateDateTime(Year(now), Month(now), Day(now), 23, 59, 59)>
            </cfcase>
            <cfcase value="weekly">
                <cfset result.startDate = DateAdd("d", -7, now)>
                <cfset result.endDate = now>
            </cfcase>
            <cfcase value="monthly">
                <cfset result.startDate = DateAdd("m", -1, now)>
                <cfset result.endDate = now>
            </cfcase>
        </cfswitch>
        
        <cfreturn result>
    </cffunction>
    
    <cffunction name="calculateTrendPercentage" access="private" returntype="numeric">
        <cfargument name="current" type="numeric" required="true">
        <cfargument name="previous" type="numeric" required="true">
        
        <cfif arguments.previous EQ 0>
            <cfreturn 0>
        </cfif>
        
        <cfreturn Round(((arguments.current - arguments.previous) / arguments.previous) * 100, 2)>
    </cffunction>
    
    <!--- Export Dashboard Data --->
    <cffunction name="exportDashboardData" access="remote" returntype="string" returnformat="plain">
        <cfargument name="period" type="string" required="true">
        
        <cfset var dateRange = getDateRange(arguments.period)>
        <cfset var data = getDashboardData(arguments.period)>
        
        <!--- Create CSV content --->
        <cfsavecontent variable="csvContent">
            "Room Reservation Dashboard Report"
            "Period: #arguments.period#"
            "From: #DateFormat(dateRange.startDate, 'mm/dd/yyyy')#"
            "To: #DateFormat(dateRange.endDate, 'mm/dd/yyyy')#"
            
            "Overview Statistics"
            "Total Reservations,Active Users,Room Utilization,Cancellation Rate"
            "#data.stats.totalReservations#,#data.stats.activeUsers#,#data.stats.roomUtilization#%,#data.stats.cancellationRate#%"
            
            "Room Statistics"
            "Room Name,Total Bookings,Utilization Rate,Average Rating,Status"
            <cfloop array="#data.tableData.rooms#" index="room">
                "#room.name#,#room.totalBookings#,#room.utilizationRate#%,#room.averageRating#,#room.status#"
            </cfloop>
            
            "User Statistics"
            "User Name,Total Bookings,Average Duration,Preferred Room,Last Active"
            <cfloop array="#data.tableData.users#" index="user">
                "#user.name#,#user.totalBookings#,#user.avgDuration# hours,#user.preferredRoom#,#user.lastActive#"
            </cfloop>
        </cfsavecontent>
        
        <cfreturn csvContent>
    </cffunction>
    
</cfcomponent>
