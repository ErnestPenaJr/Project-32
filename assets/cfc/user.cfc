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
    
<cffunction name="search4Employees" access="remote" returntype="any" returnformat="JSON" produces="JSON" >
		<cfargument name="query" type="string" required="true" >
		<cfargument name="scope" type="string" required="false" default="everyone" hint="The scope to search within for matching employee names.  Valid argument values are 'Everyone' (default), 'WebSchedule' (only registered users), 'Department', and 'Division'." >
		<cfargument name="maxrows" type="numeric" default="100">
		<cfset var retVal = ArrayNew(1)>
		<cfquery username="#this.DBUSER#" password="#this.DBPASS#" datasource="#this.DBSERVER#" name="results" maxrows="#arguments.maxrows#">
			SELECT
				PS.EMPLID, PS.FIRST_NAME || ' ' || PS.LAST_NAME AS NAME, 
                PS.NAME_DISPLAY,
                PS.PREF_DISPLAY_NAME AS DISPLAYNAME,
				LOWER(PS.WORK_EMAIL) AS EMAIL,
				PS.JOBTITLE,
                PS.JOBCODE,
				PS.USERNAME,
				PS.FULL_NAME,
				PS.WORK_PHONE AS PHONE,
				PS.DEPARTMENTNAME,
				PS.DEPTID,
                ps.LEV4_DEPTID AS DIVISIONID,
                PS.LEV4_DEPTNAME AS DIVISIONNAME,
				PS.OFFICE_LOC AS LOCATION
			FROM #this.DBSCHEMA#.ACTIVE_PEOPLESOFT PS
			WHERE PS.HR_STATUS = 'A'
				<cfloop list="#lcase(arguments.query)#" delimiters=" ," index="i">
                    <cfif isNumeric(i)>
                        AND PS.EMPLID like <cfqueryparam cfsqltype="cf_sql_varchar" value="#val(i)#%" /> OR RFID = <cfqueryparam cfsqltype="cf_sql_numeric" value="#val(i)#">
                    <cfelse>
                        AND lower(PS.FULL_NAME) like <cfqueryparam cfsqltype="cf_sql_varchar" value="%#i#%">
                    </cfif>
				</cfloop>
			ORDER BY PS.DEPARTMENTNAME, PS.LAST_NAME, PS.FIRST_NAME ASC
		</cfquery>

		<cfloop query="results">
			<cfset temp = {} />
			<cfset temp["total"] = RECORDCOUNT />
			<cfset temp["name"] = NAME />
			<cfset temp["emplID"] = EMPLID />
			<cfset temp["departmentname"] = DEPARTMENTNAME />
			<cfset temp["displayName"] = DISPLAYNAME />
            <cfset temp["username"] = USERNAME />
            <cfset temp["divid"] = DIVISIONID />
            <cfset temp["divname"] = DIVISIONNAME />
            <cfset temp["orgcode"] = DEPTID />
			<cfset temp["email"] = EMAIL />
			<cfset temp["jobTitle"] = JOBTITLE />
			<cfset temp["fullName"] = FULL_NAME />
			<cfset temp["phone"] = PHONE />
			<cfset temp["location"] = LOCATION />
			 <cfset ArrayAppend(retval, temp)>
		</cfloop>

		<cfset result = {} />
		<cfset result['EMPLOYEESFOUND'] = retVal />
		<cfreturn result />
	</cffunction>

    <cffunction name="getUserRole" access="remote" returntype="struct" returnformat="json">
        <cfset var response = {}>
        
        <cftry>
            <cfif not structKeyExists(session, "loggedIn") or not session.loggedIn>
                <cfset response.STATUS = "ERROR">
                <cfset response.MESSAGE = "User not logged in">
                <cfset response.ROLE = "">
                <cfreturn response>
            </cfif>
            
            <cfquery name="qGetUserRole" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT r.ROLE_ID, r.ROLE_NAME
                FROM #this.DBSCHEMA#.ROLES r
                WHERE user_id = <cfqueryparam value="#session.userId#" cfsqltype="cf_sql_varchar">
            </cfquery>
            
            <cfset response.STATUS = "SUCCESS">
            <cfset response.ROLE = qGetUserRole.role>
            
            <cfcatch type="any">
                <cfset response.STATUS = "ERROR">
                <cfset response.MESSAGE = cfcatch.message>
                <cfset response.ROLE = "">
            </cfcatch>
        </cftry>
        
        <cfreturn response>
    </cffunction>

    <cffunction name="getUsers" access="remote" returntype="struct" returnformat="json">
        <cfset var retVal = [] />
        <cftry>
            <cfquery name="qGetUsers" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT u.USER_ID, u.FIRST_NAME, u.LAST_NAME,u.EMAIL,u.ROLE_ID, u.EMPLID, u.LASTLOGGEDON, u.STATUS, r.ROLE_NAME, u.FIRST_NAME || ' ' || u.LAST_NAME as FULL_NAME 
                FROM #this.DBSCHEMA#.USERS u, #this.DBSCHEMA#.ROLES r 
                WHERE u.ROLE_ID = r.ROLE_ID
                AND u.STATUS in ('Active', 'Inactive','NEW')
                ORDER BY u.LAST_NAME ASC
            </cfquery>

            <cfloop query="qGetUsers">
                <cfset temp = {} />
                <cfset temp["ID"] = qGetUsers.USER_ID />
                <cfset temp["FULL_NAME"] = qGetUsers.FULL_NAME />
                <cfset temp["FIRST_NAME"] = qGetUsers.FIRST_NAME />
                <cfset temp["LAST_NAME"] = qGetUsers.LAST_NAME />
                <cfset temp["EMAIL"] = qGetUsers.EMAIL />
                <cfset temp["ROLE"] = qGetUsers.ROLE_NAME />
                <cfset temp["EMPLID"] = qGetUsers.EMPLID />
                <cfset temp["LAST_LOGGED_IN"] = qGetUsers.LASTLOGGEDON />
                <cfset temp["STATUS"] = qGetUsers.STATUS />
                <cfset temp["SUCCESS"] = true />
                <cfset ArrayAppend(retVal, temp) />
            </cfloop>

             <cfset result["users"] = retVal />
            <cfreturn result />
            
            <cfcatch type="any">
                <cfset response.SUCCESS = false>
                <cfset response.MESSAGE = cfcatch.message>
            </cfcatch>
        </cftry>
        
        <cfreturn response>
    </cffunction>

    <cffunction name="getUser" access="remote" returntype="struct" returnformat="json">
        <cfargument name="userId" type="string" required="true">
        <cfset var response = {}>
        
        <cftry>
            <cfquery name="qGetUser" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT u.USER_ID as ID, u.EMPLID, u.EMAIL, u.FIRST_NAME ||' '|| u.LAST_NAME AS FULL_NAME, r.ROLE_NAME, r.ROLE_ID, u.STATUS, ap.DEPARTMENTNAME, ap.JOBTITLE
                FROM #this.DBSCHEMA#.USERS u, #this.DBSCHEMA#.ROLES r, #this.DBSCHEMA#.ACTIVE_PEOPLESOFT ap
                WHERE u.ROLE_ID = r.ROLE_ID 
                AND u.EMPLID = ap.EMPLID
                AND u.USER_ID = <cfqueryparam value="#arguments.userId#" cfsqltype="cf_sql_varchar">
            </cfquery>
            
            <cfif qGetUser.recordCount>
                <cfset response.SUCCESS = true>
                <cfset response.DATA = queryToStruct(qGetUser)>
            <cfelse>
                <cfset response.SUCCESS = false>
                <cfset response.MESSAGE = "User not found">
            </cfif>
            
            <cfcatch type="any">
                <cfset response.SUCCESS = false>
                <cfset response.MESSAGE = cfcatch.message>
            </cfcatch>
        </cftry>
        
        <cfreturn response>
    </cffunction>

    <cffunction name="addUser" access="remote" returntype="struct" returnformat="json">
        <cfargument name="emplid" type="string" required="true">
        <cfargument name="permissions" type="string" required="true">
        <cfargument name="status" type="string" required="true">
        <cfargument name="eid" type="string" required="false" default="">
        <cfset var response = {}>
        
            <cflog file="userManagement" text="Adding user - EMPLID: #arguments.emplid#, Permissions: #arguments.permissions#, Status: #arguments.status#, EID: #arguments.eid#">
            
            <cfquery name="qCheckUsername" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT COUNT(*) as userCount
                FROM #this.DBSCHEMA#.USERS
                WHERE EMPLID = <cfqueryparam value="#arguments.emplid#" cfsqltype="cf_sql_varchar">
            </cfquery>
            
            <cfif qCheckUsername.userCount GT 0>
                <cfset response.SUCCESS = false>
                <cfset response.MESSAGE = "User with EMPLID #arguments.emplid# already exists">
                <cflog file="userManagement" text="User already exists - EMPLID: #arguments.emplid#">
                <cfreturn response>
            </cfif>

            <cfquery name="qGetUserFromPeoplesoft" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT ap.EMPLID, ap.LAST_NAME, ap.FIRST_NAME, ap.WORK_EMAIL
                FROM #this.DBSCHEMA#.ACTIVE_PEOPLESOFT ap
                WHERE EMPLID = <cfqueryparam value="#arguments.emplid#" cfsqltype="cf_sql_varchar">
            </cfquery>
            
            <cfif qGetUserFromPeoplesoft.recordCount EQ 0>
                <cfset response.SUCCESS = false>
                <cfset response.MESSAGE = "User not found in Peoplesoft - EMPLID: #arguments.emplid#">
                <cflog file="userManagement" text="User not found in Peoplesoft - EMPLID: #arguments.emplid#">
                <cfreturn response>
            </cfif>

                <cfquery name="qAddUser" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#" result="insertResult">
                    INSERT INTO #this.DBSCHEMA#.USERS (
                        EMPLID,
                        FIRST_NAME,
                        LAST_NAME,
                        EMAIL,
                        ROLE_ID,
                        STATUS,
                        DATEENTERED,
                        ENTEREDBYID
                    ) VALUES (
                        <cfqueryparam value="#arguments.emplid#" cfsqltype="cf_sql_varchar">,
                        <cfqueryparam value="#qGetUserFromPeoplesoft.FIRST_NAME#" cfsqltype="cf_sql_varchar">,
                        <cfqueryparam value="#qGetUserFromPeoplesoft.LAST_NAME#" cfsqltype="cf_sql_varchar">,
                        <cfqueryparam value="#qGetUserFromPeoplesoft.WORK_EMAIL#" cfsqltype="cf_sql_varchar">,
                        <cfqueryparam value="#arguments.permissions#" cfsqltype="cf_sql_numeric">,
                        <cfqueryparam value="#arguments.status#" cfsqltype="cf_sql_varchar">,
                        <cfqueryparam value="#now()#" cfsqltype="cf_sql_timestamp">,
                        <cfqueryparam value="#arguments.eid#" cfsqltype="cf_sql_varchar">
                    )
                </cfquery>
                <cfquery name="qGetRole" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                    SELECT ROLE_NAME
                    FROM #this.DBSCHEMA#.ROLES
                    WHERE ROLE_ID = <cfqueryparam value="#arguments.permissions#" cfsqltype="cf_sql_varchar">
                </cfquery>
                
                <cfset response.SUCCESS = true>
                <cfset response.MESSAGE = "User added successfully">
                <cflog file="userManagement" text="User added successfully - EMPLID: #arguments.emplid#">
              <cfset var emailBody = "Hi #qGetUserFromPeoplesoft.FIRST_NAME#,<br><br>You have been added to the DoCM Reservation System, with the following permissions: <b>#qGetRole.ROLE_NAME#</b>.<br><br>Best regards,<br>Room Reservation System">
             <cfmail 
                to="#qGetUserFromPeoplesoft.WORK_EMAIL#" 
                from="NO-REPLY@mdanderson.org" 
                subject="DoCM Reservation System - New User Added" 
                type="html"
                bcc="erniep@mdanderson.org, tlouie@mdanderson.org, cpender@mdanderson.org,tglover@mdanderson.org">
                <cfoutput>
                    #emailBody#
                </cfoutput>
                </cfmail>
        
        <cfreturn response>
    </cffunction>

    <cffunction name="updateUser" access="remote" returntype="struct" returnformat="json">
        <cfargument name="userId" type="string" required="true">
        <cfargument name="username" type="string" required="true">
        <cfargument name="role" type="string" required="true">
        <cfargument name="status" type="string" required="true">
        <cfargument name="modifiedbyid" type="string" required="false" default="">
        
        <cfset var response = {}>
        
       
            <!--- Check if username exists for other users --->
            <cfquery name="qGetUserDetails" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT u.USER_ID, u.EMPLID, u.FIRST_NAME, u.LAST_NAME, u.EMAIL, u.STATUS, u.ROLE_ID, r.ROLE_NAME
                FROM #this.DBSCHEMA#.USERS u, #this.DBSCHEMA#.ROLES r
                WHERE u.ROLE_ID = r.ROLE_ID
                AND USER_ID = <cfqueryparam value="#arguments.userId#" cfsqltype="cf_sql_varchar">
            </cfquery>

            <cfquery name="qGetRole" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT ROLE_ID, ROLE_NAME
                FROM #this.DBSCHEMA#.ROLES
                WHERE ROLE_ID = <cfqueryparam value="#arguments.role#" cfsqltype="cf_sql_varchar">
            </cfquery>

   
            <!--- Update user --->
            <cfquery name="qUpdateUser" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                UPDATE #this.DBSCHEMA#.USERS
                SET ROLE_ID = <cfqueryparam value="#arguments.role#" cfsqltype="cf_sql_varchar">,
                    STATUS = <cfqueryparam value="#arguments.status#" cfsqltype="cf_sql_varchar">,
                    MODIFIEDBYID = <cfqueryparam value="#arguments.modifiedbyid#" cfsqltype="cf_sql_varchar">,
                    DATEMODIFIED = <cfqueryparam value="#now()#" cfsqltype="cf_sql_timestamp">
                WHERE USER_ID = <cfqueryparam value="#arguments.userId#" cfsqltype="cf_sql_varchar">
            </cfquery>
            
            <cfset response.SUCCESS = true>
            <cfset response.MESSAGE = "User updated successfully">

            <!--- Initialize email body --->
            <cfset var emailBody = "
            <html>
                <head>
                    <title>DoCM Reservation User Status Change</title>
                </head>
                <body>
                    <p>Hi #qGetUserDetails.first_name#,</p>
                    <p>Your DoCM reservation User account has changed; below are the details.</p><br>
            ">

            <!--- Add conditional content dynamically --->
            <cfif arguments.status NEQ qGetUserDetails.status>
                <cfset emailBody &= "
                    <span>New Status: ""<b>#arguments.status#</b>""</span><br>
                ">
            </cfif>

            <cfif arguments.role NEQ qGetUserDetails.role_id>
                <cfset emailBody &= "
                    <span>New Role: ""<b>#qGetRole.role_name#</b>""</span><br>
                ">
            </cfif>

            <!--- Append the remaining content --->
            <cfset emailBody &= "
                    <p>Please log in to your account to view the changes.</p>
                    <p>Best regards,</p>
                    <p>DoCM Reservation System</p>
                </body>
            </html>
            ">

            <!--- Send email --->
            <cfmail 
                to="#qGetUserDetails.email#" 
                from="NO-REPLY@mdanderson.org" 
                subject="User Status Update - DoCM Reservation System" 
                type="html" 
                bcc="erniep@mdanderson.org, tlouie@mdanderson.org, cpender@mdanderson.org,tglover@mdanderson.org">
                <cfoutput>#emailBody#</cfoutput>
            </cfmail>
        
        <cfreturn response>
    </cffunction>

    <cffunction name="updateUserStatus" access="remote" returntype="struct" returnformat="json">
        <cfargument name="userId" type="string" required="true">
        <cfargument name="status" type="string" required="true">
        
        <cfset var response = {
            "SUCCESS" = false,
            "MESSAGE" = ""
        }>
        
        <cftry>
            <cfquery username="#this.DBUSER#" password="#this.DBPASS#" datasource="#this.DBSERVER#">
                UPDATE #this.DBSCHEMA#.USERS
                SET STATUS = <cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.status#">
                WHERE USER_ID = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.userId#">
            </cfquery>
            
            <cfset response.SUCCESS = true>
            <cfset response.MESSAGE = "User status updated successfully">
            
            <cfcatch>
                <cfset response.MESSAGE = "Error updating user status: " & cfcatch.message>
            </cfcatch>
        </cftry>
        
        <cfreturn response>
    </cffunction>

    <cffunction name="deleteUser" access="remote" returntype="struct" returnformat="json">
        <cfargument name="userId" type="string" required="true">
        <cfargument name="uid" type="string" required="true">
        
        <cfset var response = {}>
        
            <cfif arguments.userId EQ arguments.uid>
                <cfset response.SUCCESS = false>
                <cfset response.MESSAGE = "Cannot delete your own account">
                <cfreturn response>
            </cfif>
            <cfquery name="qCheckReservations" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT COUNT(*) as reservationCount
                FROM #this.DBSCHEMA#.BOOKINGS
                WHERE USER_ID = <cfqueryparam value="#arguments.userId#" cfsqltype="cf_sql_varchar">
                AND STATUS = 'Active'
            </cfquery>
            
            <cfif qCheckReservations.reservationCount GT 0>
                <cfset response.SUCCESS = false>
                <cfset response.MESSAGE = "User has active reservations and cannot be deleted, please cancel them first">
                <cfreturn response>
            <cfelse>
            
                <cfquery name="qGetUserFromPeoplesoft" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                    SELECT ap.WORK_EMAIL, u.FIRST_NAME
                    FROM #this.DBSCHEMA#.USERS u
                    JOIN #this.DBSCHEMA#.ACTIVE_PEOPLESOFT ap ON u.EMPLID = ap.EMPLID
                    WHERE u.USER_ID = <cfqueryparam value="#arguments.userId#" cfsqltype="cf_sql_varchar">
                </cfquery>
                
                <cfquery name="qDeleteUser" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                    UPDATE #this.DBSCHEMA#.USERS
                    SET STATUS = 'Deleted'
                    WHERE USER_ID = <cfqueryparam value="#arguments.userId#" cfsqltype="cf_sql_varchar">
                </cfquery>
            
                <cfset response.SUCCESS = true>
                <cfset response.MESSAGE = "User deleted successfully">
                <!---Send user an email to let them know they have been removed--->
                <cfmail 
                    to="#qGetUserFromPeoplesoft.WORK_EMAIL#" 
                    from="NO-REPLY@mdanderson.org" 
                    subject="DoCM Reservation System - User Removed" 
                    type="html">
                    <cfoutput>
                        Hi #qGetUserFromPeoplesoft.FIRST_NAME#,<br><br>
                        You have been set to an 'Inactive' status from the DoCM Reservation System.<br><br>
                        Best regards,<br>
                        Room Reservation System
                    </cfoutput>
                </cfmail>

            </cfif>
        
        <cfreturn response>
    </cffunction>

    <cffunction name="queryToArray" access="private" returntype="array">
        <cfargument name="query" type="query" required="true">
        
        <cfset var arr = []>
        <cfset var cols = listToArray(arguments.query.columnList)>
        
        <cfloop query="arguments.query">
            <cfset var obj = {}>
            <cfloop array="#cols#" index="col">
                <cfset obj[col] = arguments.query[col][currentRow]>
            </cfloop>
            <cfset arrayAppend(arr, obj)>
        </cfloop>
        
        <cfreturn arr>
    </cffunction>

    <cffunction name="queryToStruct" access="private" returntype="struct">
        <cfargument name="query" type="query" required="true">
        
        <cfset var obj = {}>
        <cfset var cols = listToArray(arguments.query.columnList)>
        
        <cfif arguments.query.recordCount>
            <cfloop array="#cols#" index="col">
                <cfset obj[col] = arguments.query[col][1]>
            </cfloop>
        </cfif>
        
        <cfreturn obj>
    </cffunction>

    <cffunction name="getNewUsersCount" access="remote" returntype="numeric" returnformat="plain">
        <cftry>
            <cfquery name="qGetNewUsers" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT COUNT(*) as NewCount
                FROM #this.DBSCHEMA#.USERS
                WHERE STATUS = 'NEW'
            </cfquery>
            
            <cfreturn qGetNewUsers.NewCount>
            
            <cfcatch type="any">
                <cfreturn 0>
            </cfcatch>
        </cftry>
    </cffunction>

</cfcomponent>
