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
    <!--- Log database changes --->
    <cffunction name="logDatabaseChange" access="public" returntype="void">
        <cfargument name="actionType" type="string" required="true">
        <cfargument name="tableName" type="string" required="true">
        <cfargument name="recordId" type="any" required="true">
        <cfargument name="userId" type="any" required="true">
        <cfargument name="changeDetails" type="string" required="true">
        <cfargument name="datasource" type="string" required="false" default="#this.DBSERVER#">
        
        <cftry>
            <!--- Validate userId is numeric --->
            <cfif not isNumeric(arguments.userId) or arguments.userId lte 0>
                <cfset arguments.userId = 0>
            </cfif>

            <cfquery datasource="#arguments.datasource#" username="#this.DBUSER#" password="#this.DBPASS#">
                INSERT INTO #this.DBSCHEMA#.SYSTEM_LOGS (
                    USER_ID,
                    ACTION_TYPE,
                    TABLE_NAME,
                    RECORD_ID,
                    CHANGE_DETAILS,
                    LOG_TIMESTAMP
                ) VALUES (
                    <cfqueryparam value="#val(arguments.userId)#" cfsqltype="cf_sql_numeric">,
                    <cfqueryparam value="#arguments.actionType#" cfsqltype="cf_sql_varchar">,
                    <cfqueryparam value="#arguments.tableName#" cfsqltype="cf_sql_varchar">,
                    <cfqueryparam value="#arguments.recordId#" cfsqltype="cf_sql_varchar">,
                    <cfqueryparam value="#arguments.changeDetails#" cfsqltype="cf_sql_varchar">,
                    CURRENT_TIMESTAMP
                )
            </cfquery>
            
            <cfcatch type="any">
                <cflog file="systemLogger" text="Error in logDatabaseChange: #cfcatch.message#. Details: #cfcatch.detail#">
            </cfcatch>
        </cftry>
    </cffunction>

    <!--- Get system logs with pagination --->
    <cffunction name="getSystemLogs" access="remote" returntype="struct" returnformat="JSON">
        <cfargument name="page" type="numeric" required="false" default="1">
        <cfargument name="pageSize" type="numeric" required="false" default="10">
        <cfargument name="filterType" type="string" required="false" default="">
        <cfargument name="filterTable" type="string" required="false" default="">
        <cfargument name="startDate" type="string" required="false" default="">
        <cfargument name="endDate" type="string" required="false" default="">
        
        <cftry>
            <!--- Calculate offset --->
            <cfset local.offset = (arguments.page - 1) * arguments.pageSize>
            
            <!--- Build where clause --->
            <cfset local.whereClause = "">
            <cfif len(arguments.filterType)>
                <cfset local.whereClause = local.whereClause & " AND ACTION_TYPE = '#arguments.filterType#'">
            </cfif>
            <cfif len(arguments.filterTable)>
                <cfset local.whereClause = local.whereClause & " AND TABLE_NAME = '#arguments.filterTable#'">
            </cfif>
            <cfif len(arguments.startDate)>
                <cfset local.whereClause = local.whereClause & " AND LOG_TIMESTAMP >= TO_TIMESTAMP('#arguments.startDate#', 'YYYY-MM-DD')">
            </cfif>
            <cfif len(arguments.endDate)>
                <cfset local.whereClause = local.whereClause & " AND LOG_TIMESTAMP <= TO_TIMESTAMP('#arguments.endDate#', 'YYYY-MM-DD')">
            </cfif>
            
            <!--- Get total count --->
            <cfquery name="qGetCount" datasource="roomreservation">
                SELECT COUNT(*) as total_count
                FROM SYSTEM_LOGS sl
                INNER JOIN USERS u ON sl.USER_ID = u.USER_ID
                WHERE 1=1 #local.whereClause#
            </cfquery>
            
            <!--- Get paginated logs --->
            <cfquery name="qGetLogs" datasource="roomreservation">
                SELECT 
                    sl.LOG_ID,
                    sl.ACTION_TYPE,
                    sl.TABLE_NAME,
                    sl.RECORD_ID,
                    sl.CHANGE_DETAILS,
                    sl.LOG_TIMESTAMP,
                    u.USERNAME,
                    u.FIRST_NAME,
                    u.LAST_NAME
                FROM SYSTEM_LOGS sl
                INNER JOIN USERS u ON sl.USER_ID = u.USER_ID
                WHERE 1=1 #local.whereClause#
                ORDER BY sl.LOG_TIMESTAMP DESC
                OFFSET #local.offset# ROWS
                FETCH NEXT #arguments.pageSize# ROWS ONLY
            </cfquery>
            
            <!--- Format response --->
            <cfset local.logs = []>
            <cfloop query="qGetLogs">
                <cfset arrayAppend(local.logs, {
                    "logId": LOG_ID,
                    "actionType": ACTION_TYPE,
                    "tableName": TABLE_NAME,
                    "recordId": RECORD_ID,
                    "changeDetails": CHANGE_DETAILS,
                    "timestamp": LOG_TIMESTAMP,
                    "username": USERNAME,
                    "userFullName": FIRST_NAME & " " & LAST_NAME
                })>
            </cfloop>
            
            <cfreturn {
                "logs": local.logs,
                "totalCount": qGetCount.total_count,
                "currentPage": arguments.page,
                "totalPages": ceiling(qGetCount.total_count / arguments.pageSize)
            }>
            
            <cfcatch type="any">
                <cflog file="systemLogger" text="Error in getSystemLogs: #cfcatch.message#">
                <cfthrow message="Error retrieving system logs">
            </cfcatch>
        </cftry>
    </cffunction>
</cfcomponent>
