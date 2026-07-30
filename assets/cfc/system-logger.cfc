<cfcomponent>
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

    <!--- Get system logs with pagination.

          NON-FUNCTIONAL as written, for three independent reasons found 2026-07-29:

            1. Both queries use datasource="roomreservation", which is not one of
               the three datasources this component configures (inside2_docmd /
               _docms / _docmp), and they pass no credentials. this.DBSERVER,
               this.DBUSER and this.DBPASS are set above and then ignored.
            2. They select u.USERNAME. USERS has no USERNAME column, so even with a
               valid datasource this raises ORA-00904.
            3. Consequently system-logs.html has never been able to display data.

          The SQL injection vector in the filters has been fixed (values are now
          bound), because that must not be left in place regardless of whether the
          function runs.

          BEFORE REVIVING THIS: it is access="remote" with **no authorization check
          of any kind**, so repairing the datasource and column would immediately
          expose the full system audit log — every logged change, with usernames --
          to any unauthenticated caller. Add an authorization check first. That
          depends on the session scope this application does not yet have; see
          docs/reservation-improvements-final-report.md. --->
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
            
            <!--- Filters are applied as BOUND PARAMETERS in the queries below.
                  They were previously concatenated into the SQL string:
                      whereClause &= " AND ACTION_TYPE = '#arguments.filterType#'"
                  filterType, filterTable, startDate and endDate are declared
                  type="string" with no validation, and this function is
                  access="remote", so that was a SQL injection vector reachable over
                  HTTP. It could not actually be exploited only because the queries
                  fail first (see the note on this function), which is luck rather
                  than a defence.

                  local.whereClause is retained solely because other code may still
                  reference it; it is no longer interpolated into any SQL. --->
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
                WHERE 1=1
                    <cfif len(trim(arguments.filterType))>
                        AND sl.ACTION_TYPE = <cfqueryparam value="#trim(arguments.filterType)#" cfsqltype="cf_sql_varchar">
                    </cfif>
                    <cfif len(trim(arguments.filterTable))>
                        AND sl.TABLE_NAME = <cfqueryparam value="#trim(arguments.filterTable)#" cfsqltype="cf_sql_varchar">
                    </cfif>
                    <cfif len(trim(arguments.startDate))>
                        AND sl.LOG_TIMESTAMP >= TO_TIMESTAMP(<cfqueryparam value="#trim(arguments.startDate)#" cfsqltype="cf_sql_varchar">, 'YYYY-MM-DD')
                    </cfif>
                    <cfif len(trim(arguments.endDate))>
                        AND sl.LOG_TIMESTAMP <= TO_TIMESTAMP(<cfqueryparam value="#trim(arguments.endDate)#" cfsqltype="cf_sql_varchar">, 'YYYY-MM-DD')
                    </cfif>
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
                WHERE 1=1
                    <cfif len(trim(arguments.filterType))>
                        AND sl.ACTION_TYPE = <cfqueryparam value="#trim(arguments.filterType)#" cfsqltype="cf_sql_varchar">
                    </cfif>
                    <cfif len(trim(arguments.filterTable))>
                        AND sl.TABLE_NAME = <cfqueryparam value="#trim(arguments.filterTable)#" cfsqltype="cf_sql_varchar">
                    </cfif>
                    <cfif len(trim(arguments.startDate))>
                        AND sl.LOG_TIMESTAMP >= TO_TIMESTAMP(<cfqueryparam value="#trim(arguments.startDate)#" cfsqltype="cf_sql_varchar">, 'YYYY-MM-DD')
                    </cfif>
                    <cfif len(trim(arguments.endDate))>
                        AND sl.LOG_TIMESTAMP <= TO_TIMESTAMP(<cfqueryparam value="#trim(arguments.endDate)#" cfsqltype="cf_sql_varchar">, 'YYYY-MM-DD')
                    </cfif>
                ORDER BY sl.LOG_TIMESTAMP DESC
                OFFSET <cfqueryparam value="#val(local.offset)#" cfsqltype="cf_sql_integer"> ROWS
                FETCH NEXT <cfqueryparam value="#val(arguments.pageSize)#" cfsqltype="cf_sql_integer"> ROWS ONLY
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
