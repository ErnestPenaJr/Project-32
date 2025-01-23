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
    <!--- Get all rooms --->
    <cffunction name="getTotalRooms" access="remote" returntype="any" returnformat="JSON">
        <cfset var retVal = [] />
        <cfset var temp = {} />
        <cfset var result = {} />

        <cfquery name="qRooms" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
            SELECT 
                COUNT(*) as TotalRooms
            FROM #this.DBSCHEMA#.ROOMS
            WHERE MAINTENANCE_STATUS IS NULL OR MAINTENANCE_STATUS = 'NO'
        </cfquery>

        <cfset temp = {} />
        <cfset temp["TotalRooms"] = qRooms.TotalRooms />
        <cfset ArrayAppend(retVal, temp) />

        <cfreturn retVal />
    </cffunction>

    <cffunction name="getTotalBookings" access="remote" returntype="any" returnformat="JSON">
        <cfset var retVal = [] />
        <cfset var temp = {} />
        <cfset var result = {} />

        <cfquery name="qBookings" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
            SELECT 
                COUNT(*) as TotalBookings
            FROM #this.DBSCHEMA#.BOOKINGS
            WHERE STATUS = 'CONFIRMED'
        </cfquery>

        <cfset temp = {} />
        <cfset temp["TotalBookings"] = qBookings.TotalBookings />
        <cfset ArrayAppend(retVal, temp) />

        <cfreturn retVal />
    </cffunction>

    <cffunction name="getBookings" access="remote" returntype="any" returnformat="JSON">
        <cfset var retVal = [] />
        <cfset var temp = {} />
        <cfset var result = {} />

        <cfquery name="qBookings" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
            SELECT 
                COUNT(*) as TotalBookings
            FROM #this.DBSCHEMA#.BOOKINGS
        </cfquery>

        <cfset temp = {} />
        <cfset temp["TotalBookings"] = qBookings.TotalBookings />
        <cfset ArrayAppend(retVal, temp) />

        <cfreturn retVal />
    </cffunction>

    <cffunction name="getTotalMeetings" access="remote" returntype="any" returnformat="JSON">
        <cfset var retVal = [] />
        <cfset var temp = {} />
        <cfset var result = {} />

        <cfquery name="qMeetings" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
            SELECT 
                COUNT(*) as TotalMeetings
            FROM #this.DBSCHEMA#.MEETINGS
        </cfquery>

        <cfset temp = {} />
        <cfset temp["TotalMeetings"] = qMeetings.TotalMeetings />
        <cfset ArrayAppend(retVal, temp) />

        <cfreturn retVal />
    </cffunction>
    </cfcomponent>