<cfcomponent output="false">
    <!--- Enable session management --->
    <cfset SetClientCookies = "Yes">
    <cfset SetDomainCookies = "No">
    <cfset sessionManagement = "Yes">
    <cfset sessionTimeout = "#CreateTimeSpan(0,0,30,0)#">

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
    
    <cffunction name="remote_LDAP" returnformat="JSON" access="remote" returntype="Any">
        <cfargument name="UserID" required="yes" />
        <cfargument name="UserPassword" required="yes" />

        <cfset LDAP = {} />
        <cfset LDAP.authenticates = 0>
        
        <cftry>
            <cfldap 
                action="QUERY" 
                name="auth" 
                start="OU=People,dc=mdanderson,dc=edu" 
                separator="|" 
                attributes="dn,employeeID" 
                server="ldap.mdanderson.edu"	
                username="MDANDERSON\#listFirst(arguments.UserID,'|')#"	
                password="#arguments.UserPassword#" 
                scope="subtree"	
                filter="sAMAccountName=#listLast(arguments.UserID,'|')#"/>

            <cfif auth.RecordCount>
                <cfset LDAP.Authenticates = "true" />
                <cfset LDAP.UserID = auth.employeeID />
                
                <!--- Set session variables on successful authentication --->
                <cfset session.loggedin = true>
                <cfset session.userID = auth.employeeID>
                <cfset session.lastActivity = now()>
                <cfset session.username = arguments.UserID>
            </cfif>

        <cfcatch type="ANY">

            <cfset originalError = cfcatch />
            <cfset LDAP.ErrorCode = Mid(cfcatch.Message,Find(", data ", cfcatch.message)+7,Find(",", cfcatch.Message,Find(", data ", cfcatch.message)+1)-Find(", data ", cfcatch.message)-7) />

            <cfif LDAP.ErrorCode eq "525">
                <cfset LDAP["ADMessage"] = "User Not Found" />
            <cfelseif LDAP.ErrorCode eq "52e">
                <cfset LDAP["ADMessage"] = "Password or Username is incorrect" />
            <cfelseif LDAP.ErrorCode eq "530">
                <cfset LDAP["ADMessage"] = "User not permitted to log on at this time" />
            <cfelseif LDAP.ErrorCode eq "532">
                <cfset LDAP["ADMessage"] = "Password expired" />
            <cfelseif LDAP.ErrorCode eq "533">
                <cfset LDAP["ADMessage"] = "Account disabled" />
            <cfelseif LDAP.ErrorCode eq "701">
                <cfset LDAP["ADMessage"] = "Account expired" />
            <cfelseif LDAP.ErrorCode eq "733">
                <cfset LDAP["ADMessage"] = "Account disabled" />
            <cfelseif LDAP.ErrorCode eq "775">
                <cfset LDAP["ADMessage"] =  "Account locked out" />
            <cfelse>
                <cfset LDAP["ADMessage"] = "Rejected with unknown reason code (#LDAP.ErrorCode#)." />
            </cfif>
        </cfcatch>
        </cftry>

        <cfif LDAP.authenticates eq "true">

            <cfquery username="#this.DBUSER#" password="#this.DBPASS#" datasource="#this.DBSERVER#" name="ldap_results">
                SELECT 
                u.USER_ID,
                u.EMPLID, 
                ap.FULL_NAME, 
                ap.LAST_NAME,
                ap.FIRST_NAME,
                ap.NAME_DISPLAY,
                ap.USERNAME,
                ap.OFFICE_LOC,
                ap.WORK_PHONE,
                ap.JOBCODE,
                ap.JOBTITLE,
                ap.WORK_EMAIL,
                ap.LEV4_DEPTID AS DIVISIONID, 
                ap.DEPTID,
                u.STATUS, 
                u.DATEENTERED, 
                u.ENTEREDBYID, 
                u.DATEMODIFIED, 
                u.MODIFIEDBYID,  
                CAST(u.LASTLOGGEDON AS DATE) AS LASTLOGGEDON,
                r.ROLE_NAME, 
                r.ROLE_ID
                FROM 
                    CONFROOM.USERS u
                JOIN 
                    CONFROOM.ACTIVE_PEOPLESOFT ap ON u.EMPLID = ap.EMPLID
                JOIN 
                    CONFROOM.ROLES r ON u.ROLE_ID = r.ROLE_ID
                WHERE 
                    u.EMPLID = #LDAP.UserID#
            </cfquery>

            <cfif ldap_results.STATUS eq "Active">

                <cfset temp = {} />
                <cfset temp["USER_ID"] = ldap_results.USER_ID />
                <cfset temp['NAME'] = ldap_results.FULL_NAME />
                <cfset temp["NAME_DISPLAY"] = ldap_results.NAME_DISPLAY />
                <cfset temp["DIVISIONID"] = ldap_results.DIVISIONID />
                <cfset temp["DEPTID"] = ldap_results.DEPTID />
                <cfset temp['LASTLOGGEDIN'] = ldap_results.LASTLOGGEDON />
                <cfset temp["EMPLID"] = ldap_results.EMPLID />
                <cfset temp["WORKPHONE"] = ldap_results.WORK_PHONE />
                <cfset temp["OFFICE"] = ldap_results.OFFICE_LOC />
                <cfset temp["JOBTITLE"] = ldap_results.JOBTITLE />
                <cfset temp["JOBCODE"] = ldap_results.JOBCODE />
                <cfset temp["ROLE"] = ldap_results.ROLE_NAME />
                <cfset temp["ROLEID"] = ldap_results.ROLE_ID />
                <cfset temp["EMAIL"] = ldap_results.WORK_EMAIL />
                <cfset temp["USERNAME"] = ldap_results.USERNAME />
                <cfset temp["ISLOGGINEDIN"] = 1 />
                <cfset temp["AUTHORIZED_USER"] = true />
                <cfset temp["ISADMIN"] = ldap_results.ROLE_ID />
                <cfset temp["ADMESSAGE"] = 'Authentication Successful' />
            
            <cfelseif ldap_results.STATUS eq "NEW" or ldap_results.STATUS eq "Inactive">
                
                <cfset temp["AUTHORIZED_USER"] = false />
                <cfset temp["ISADMIN"] = 0 />
                <cfset temp["ADMESSAGE"] = 'We found your account but it is not active, please be patient while we complete the activation process' />
            
            <cfelse>
                <!--- if user is found in active peoplesoft but not in the users table, add them--->
                <cfquery username="#this.DBUSER#" password="#this.DBPASS#" datasource="#this.DBSERVER#" name="getUser">
                    SELECT
                    ap.EMPLID,             
                    ap.FULL_NAME, 
                    ap.LAST_NAME,
                    ap.FIRST_NAME,
                    ap.NAME_DISPLAY,
                    ap.USERNAME,
                    ap.OFFICE_LOC,
                    ap.WORK_PHONE,
                    ap.JOBCODE,
                    ap.JOBTITLE,
                    ap.WORK_EMAIL,
                    ap.LEV4_DEPTID AS DIVISIONID, 
                    ap.DEPTID
                    FROM 
                        CONFROOM.ACTIVE_PEOPLESOFT ap
                    WHERE ap.LEV4_DEPTID = 900014
                    <cfif isNumeric(LDAP.UserID)>
                        AND ap.EMPLID = #LDAP.UserID#
                    <cfelse>
                        AND LOWER(ap.USERNAME) = LOWER(#LDAP.UserID#)
                    </cfif>
                </cfquery>

                <!--- Insert user into users table with an active status --->
                <cfif getUser.RecordCount>
                    <cfquery username="#this.DBUSER#" password="#this.DBPASS#" datasource="#this.DBSERVER#">
                        INSERT INTO #this.DBSCHEMA#.USERS (EMPLID, FIRST_NAME, LAST_NAME, EMAIL, ROLE_ID, STATUS, DATEENTERED, ENTEREDBYID)
                        VALUES (
                        <cfqueryparam value="#getUser.EMPLID#" cfsqltype="cf_sql_numeric">,
                        <cfqueryparam value="#getUser.FIRST_NAME#" cfsqltype="cf_sql_varchar">,
                        <cfqueryparam value="#getUser.LAST_NAME#" cfsqltype="cf_sql_varchar">,
                        <cfqueryparam value="#getUser.WORK_EMAIL#" cfsqltype="cf_sql_varchar">,
                        <cfqueryparam value="3" cfsqltype="cf_sql_numeric">,
                        <cfqueryparam value="Active" cfsqltype="cf_sql_varchar">,
                        <cfqueryparam value="#Now()#" cfsqltype="cf_sql_timestamp">,
                        <cfqueryparam value="#getUser.EMPLID#" cfsqltype="cf_sql_numeric">
                        )
                    </cfquery>

                    <cfquery username="#this.DBUSER#" password="#this.DBPASS#" datasource="#this.DBSERVER#" name="ldap_results">
                        SELECT 
                        u.USER_ID,
                        u.EMPLID, 
                        ap.FULL_NAME, 
                        ap.LAST_NAME,
                        ap.FIRST_NAME,
                        ap.NAME_DISPLAY,
                        ap.USERNAME,
                        ap.OFFICE_LOC,
                        ap.WORK_PHONE,
                        ap.JOBCODE,
                        ap.JOBTITLE,
                        ap.WORK_EMAIL,
                        ap.LEV4_DEPTID AS DIVISIONID, 
                        ap.DEPTID,
                        u.STATUS, 
                        u.DATEENTERED, 
                        u.ENTEREDBYID, 
                        u.DATEMODIFIED, 
                        u.MODIFIEDBYID,  
                        CAST(u.LASTLOGGEDON AS DATE) AS LASTLOGGEDON,
                        r.ROLE_NAME, 
                        r.ROLE_ID
                        FROM 
                            CONFROOM.USERS u
                        JOIN 
                            CONFROOM.ACTIVE_PEOPLESOFT ap ON u.EMPLID = ap.EMPLID
                        JOIN 
                            CONFROOM.ROLES r ON u.ROLE_ID = r.ROLE_ID
                        WHERE 
                            u.EMPLID = #LDAP.UserID#
                    </cfquery>

                    <cfset temp = {} />
                    <cfset temp["USER_ID"] = ldap_results.USER_ID />
                    <cfset temp['NAME'] = ldap_results.FULL_NAME />
                    <cfset temp["NAME_DISPLAY"] = ldap_results.NAME_DISPLAY />
                    <cfset temp["DIVISIONID"] = ldap_results.DIVISIONID />
                    <cfset temp["DEPTID"] = ldap_results.DEPTID />
                    <cfset temp['LASTLOGGEDIN'] = ldap_results.LASTLOGGEDON />
                    <cfset temp["EMPLID"] = ldap_results.EMPLID />
                    <cfset temp["WORKPHONE"] = ldap_results.WORK_PHONE />
                    <cfset temp["OFFICE"] = ldap_results.OFFICE_LOC />
                    <cfset temp["JOBTITLE"] = ldap_results.JOBTITLE />
                    <cfset temp["JOBCODE"] = ldap_results.JOBCODE />
                    <cfset temp["ROLE"] = ldap_results.ROLE_NAME />
                    <cfset temp["ROLEID"] = ldap_results.ROLE_ID />
                    <cfset temp["EMAIL"] = ldap_results.WORK_EMAIL />
                    <cfset temp["USERNAME"] = ldap_results.USERNAME />
                    <cfset temp["ISLOGGINEDIN"] = 1 />
                    <cfset temp["AUTHORIZED_USER"] = true />
                    <cfset temp["ISADMIN"] = ldap_results.ROLE_ID />
                    <cfset temp["ADMESSAGE"] = 'Authentication Successful' />

                <cfelse>
                    <cfquery username="#this.DBUSER#" password="#this.DBPASS#" datasource="#this.DBSERVER#" name="getNewUser">
                        SELECT
                        ap.EMPLID,   
                        ap.DEPARTMENTNAME,
                        ap.LEV4_DEPTNAME as DIVISIONNAME,          
                        ap.LEV4_DEPTID as DIVISIONID,          
                        ap.FULL_NAME, 
                        ap.LAST_NAME,
                        ap.FIRST_NAME,
                        ap.NAME_DISPLAY,
                        ap.USERNAME,
                        ap.OFFICE_LOC,
                        ap.WORK_PHONE,
                        ap.JOBCODE,
                        ap.JOBTITLE,
                        ap.WORK_EMAIL,
                        ap.LEV4_DEPTID AS DIVISIONID, 
                        ap.DEPTID
                        FROM 
                            CONFROOM.ACTIVE_PEOPLESOFT ap
                        <cfif isNumeric(LDAP.UserID)>
                            WHERE ap.EMPLID = #LDAP.UserID#
                        <cfelse>
                            WHERE LOWER(ap.USERNAME) = LOWER(#LDAP.UserID#)
                        </cfif>
                    </cfquery>
                    
                    <cfif getNewUser.RecordCount == 0>

                        <cfset temp["ADMESSAGE"] = "User Not Found in Active Peoplesoft" />
                        <cfset temp["AUTHORIZED_USER"] = false />
                        <cfset temp["ISADMIN"] = 0 />

                    <cfelse>
                        
                         <cfquery username="#this.DBUSER#" password="#this.DBPASS#" datasource="#this.DBSERVER#">
                            INSERT INTO #this.DBSCHEMA#.USERS (EMPLID, FIRST_NAME, LAST_NAME, EMAIL, ROLE_ID, STATUS, DATEENTERED, ENTEREDBYID)
                            VALUES (
                            <cfqueryparam value="#getNewUser.EMPLID#" cfsqltype="cf_sql_numeric">,
                            <cfqueryparam value="#getNewUser.FIRST_NAME#" cfsqltype="cf_sql_varchar">,
                            <cfqueryparam value="#getNewUser.LAST_NAME#" cfsqltype="cf_sql_varchar">,
                            <cfqueryparam value="#getNewUser.WORK_EMAIL#" cfsqltype="cf_sql_varchar">,
                            <cfqueryparam value="3" cfsqltype="cf_sql_numeric">,
                            <cfqueryparam value="NEW" cfsqltype="cf_sql_varchar">,
                            <cfqueryparam value="#Now()#" cfsqltype="cf_sql_timestamp">,
                            <cfqueryparam value="#getNewUser.EMPLID#" cfsqltype="cf_sql_numeric">
                            )
                        </cfquery>

                          <!--- Get admin emails --->
                        <cfset emailArray = [] />
                        <cfquery username="#this.DBUSER#" password="#this.DBPASS#" datasource="#this.DBSERVER#" name="getAdmins">
                            SELECT EMAIL 
                            FROM #this.DBSCHEMA#.USERS 
                            WHERE ROLE_ID in (1,2)
                            AND STATUS = 'Active'
                        </cfquery>

                        <cfloop query="getAdmins">
                            <cfset arrayAppend(emailArray, getAdmins.EMAIL) />
                        </cfloop>

                        <!--- Create a comma-delimited string of emails --->
                        <cfif ArrayLen(emailArray) EQ 0>
                            <cfset emailList = "erniep@mdanderson.org" />
                        <cfelse>
                            <cfset emailList = arrayToList(emailArray, ",") />
                        </cfif>

                        <!--- Send email to admin --->
                        <cfmail 
                            to="#emailList#"
                            cc="#getNewUser.WORK_EMAIL#"
                            bcc="erniep@mdanderson.org, tlouie@mdanderson.org, cpender@mdanderson.org,tglover@mdanderson.org"
                            from="NO-REPLY@mdanderson.org" 
                            subject="NEW USER: Request for Access" 
                            type="html">
                            Team,<br><br>
                            <cfoutput>
                            <p><b>#getNewUser.FIRST_NAME# #getNewUser.LAST_NAME#</b> has submitted a request for access to the Room Reservation System. Below are the details of the user for your review and action:</p>
                            <ul>
                                <li><strong>Employee ID:</strong> #LDAP.UserID#</li>
                                <li><strong>Full Name:</strong> #getNewUser.FIRST_NAME# #getNewUser.LAST_NAME#</li>
                                <li><strong>Position:</strong> #getNewUser.JOBTITLE#</li>
                                <li><strong>Wrk. Phone:</strong> #getNewUser.WORK_PHONE#</li>
                                <li><strong>Office:</strong> #getNewUser.OFFICE_LOC#</li>
                                <li><strong>Division:</strong> #getNewUser.DIVISIONNAME#</li>
                                <li><strong>Department:</strong> #getNewUser.DEPARTMENTNAME#</li>
                                <li><strong>Email:</strong> #getNewUser.WORK_EMAIL#</li>
                            </ul>
                            </cfoutput>
                            <b>Please note:</b> The user is currently marked as "NEW" in the system and will not be granted access unless their status is updated to active.<br><br>

                            Best regards,<br>
                            Room Reservation System Notification
                        </cfmail>

                        <!--- send email to user --->
                        <cfmail to="#getNewUser.WORK_EMAIL#" from="NO-REPLY@mdanderson.org" subject="Access Request - DoCM Reservation System" type="html">
                            <cfmailpart type="text/html">
                                <cfoutput>
                                    <p>Hi #getNewUser.FIRST_NAME#,</p>
                                    <p>Thank you for your interest in the DoCM Reservation System. Your request for access has been submitted for review.</p>
                                    <p>Once a decision has been made, you will receive a notification via email.</p>
                                    <p>Thank you for your patience and understanding.</p>
                                    <p>Best regards,<br>
                                    Room Reservation System</p>
                                </cfoutput>
                            </cfmailpart>
                        </cfmail>
                        

                        <cfset temp = {} />
                        <cfset temp['USER_ID'] = '' />
                        <cfset temp['NAME'] = 'NOT FOUND!' />
                        <cfset temp["NAME_DISPLAY"] = '' />
                        <cfset temp["DIVISIONID"] = '' />
                        <cfset temp["DEPTID"] = '' />
                        <cfset temp['LASTLOGGEDIN'] = '' />
                        <cfset temp["EMPLID"] = 'auth.employeeID' />
                        <cfset temp["WORKPHONE"] = '' />
                        <cfset temp["OFFICE"] =  '' />
                        <cfset temp["JOBTITLE"] = '' />
                        <cfset temp["JOBCODE"] = '' />
                        <cfset temp["EMAIL"] = ''/>
                        <cfset temp["USERNAME"] = ''>
                        <cfset temp["ISLOGGINEDIN"] = 0 />
                        <cfset temp["AUTHORIZED_USER"] = false />
                        <cfset temp["ISADMIN"] = 0 />
                        <cfset temp["ADMESSAGE"] = "
                        <span class=""text-start"">
                        <p><b>#getNewUser.FIRST_NAME#</b>, thank you for your interest in the DoCM Reservation System. It appears that you are not a registered user. As a result, an ""Access Request"" has been submitted on your behalf for review. You will be notified once a decision regarding your access has been made.</p>
                        <p>Should you have any questions or need further assistance in the meantime, please do not hesitate to reach out to <b><i>Laura Paiz, Lapaiz@mdanderson.org, 713-745-2587</i></b>.</p> 
                        <p>Thank you,<br>Room Reservation System</p>
                        </span> " />

                    </cfif>
                </cfif>
            </cfif>

        <cfelseif LDAP.authenticates eq 0>
            <cfset temp = {} />
            <cfset temp['USER_ID'] = '' />
            <cfset temp['NAME'] = 'NOT FOUND!' />
            <cfset temp["NAME_DISPLAY"] = '' />
            <cfset temp["DIVISIONID"] = '' />
            <cfset temp["DEPTID"] = '' />
            <cfset temp['LASTLOGGEDIN'] = '' />
            <cfset temp["EMPLID"] = 'auth.employeeID' />
            <cfset temp["WORKPHONE"] = '' />
            <cfset temp["OFFICE"] =  '' />
            <cfset temp["JOBTITLE"] = '' />
            <cfset temp["JOBCODE"] = '' />
            <cfset temp["EMAIL"] = ''/>
            <cfset temp["USERNAME"] = ''>
            <cfset temp["ISLOGGINEDIN"] = 0 />
            <cfset temp["AUTHORIZED_USER"] = false />
            <cfset temp["ISADMIN"] = 0 />
            <cfset temp["ADMESSAGE"] = LDAP.ADMessage />
        </cfif>

            <cfset result = {} />
            <cfset result['LDAP'] = temp />
            <cfreturn result />
    </cffunction>
    
    <cffunction name="login" returnformat="JSON" access="remote" returntype="struct">
        <cfargument name="username" required="yes" />
        <cfargument name="password" required="yes" />
        
        <cfset var result = {}>
        
        <cftry>
            <!--- Call remote_LDAP function --->
            <cfset var LDAPResult = remote_LDAP(arguments.username, arguments.password) />
            
            <cfif structKeyExists(LDAPResult, "LDAP") and LDAPResult.LDAP.AUTHENTICATES eq "true">
                <!--- Get user information --->
                <cfquery name="userInfo" username="#this.DBUSER#" password="#this.DBPASS#" datasource="#this.DBSERVER#">
                    SELECT 
                        USER_ID,
                        EMPLID,
                        USERNAME,
                        FIRSTNAME,
                        LASTNAME,
                        EMAIL,
                        ROLE,
                        LASTLOGGEDON
                    FROM #this.DBSCHEMA#.USERS 
                    WHERE EMPLID = <cfqueryparam value="#LDAPResult.LDAP.UserID#" cfsqltype="cf_sql_varchar">
                </cfquery>

                <!--- Set session variables --->
                <cfset session.loggedin = true />
                <cfset session.lastActivity = now() />
                <cfset session.user = {
                    "EMPLID": userInfo.EMPLID,
                    "USERNAME": userInfo.USERNAME,
                    "FIRSTNAME": userInfo.FIRSTNAME,
                    "LASTNAME": userInfo.LASTNAME,
                    "EMAIL": userInfo.EMAIL,
                    "ROLE": userInfo.ROLE
                } />

                <!--- Update last login time --->
                <cfquery username="#this.DBUSER#" password="#this.DBPASS#" datasource="#this.DBSERVER#">
                    UPDATE #this.DBSCHEMA#.USERS 
                    SET LASTLOGGEDON = SYSDATE 
                    WHERE EMPLID = <cfqueryparam value="#LDAPResult.LDAP.UserID#" cfsqltype="cf_sql_varchar">
                </cfquery>

                <cfset result.SUCCESS = true />
                <cfset result.MESSAGE = "Login successful" />
                <cfset result.USER = session.user />
            <cfelse>
                <cfset result.SUCCESS = false />
                <cfset result.MESSAGE = LDAPResult.LDAP.ADMessage />
            </cfif>
            
        <cfcatch type="any">
            <cfset result.SUCCESS = false />
            <cfset result.MESSAGE = "An error occurred during login. Please try again." />
            <cfset result.DETAIL = cfcatch.message />
            
            <!--- Log the error --->
            <cfset callErrorHandler(
                errorMessage = "Login error: #cfcatch.message#",
                logFile = "login_errors",
                stackTrace = cfcatch.stackTrace
            ) />
        </cfcatch>
        </cftry>
        
        <cfreturn result />
    </cffunction>
    
    <cffunction name="checkSession" access="remote" returntype="struct" returnformat="JSON" output="false">
        <cfset var result = {}>
        
        <!--- Initialize session if it doesn't exist --->
        <cfif not isDefined("session")>
            <cfset session = {}>
        </cfif>
        
        <!--- Check if current page requires authentication --->
        <cfset var publicPages = ["/login.html", "/assets/", "/node_modules/"]>
        <cfset var currentPage = cgi.script_name>
        <cfset var requiresAuth = true>
        
        <cfloop array="#publicPages#" index="page">
            <cfif findNoCase(page, currentPage)>
                <cfset requiresAuth = false>
                <cfbreak>
            </cfif>
        </cfloop>
        
        <!--- If it's a public page, return valid --->
        <cfif not requiresAuth>
            <cfset result.valid = true>
            <cfset result.message = "Public page">
            <cfreturn result>
        </cfif>
        
        <!--- Check if session exists and is valid --->
        <cfif not structKeyExists(session, "loggedin") or not session.loggedin>
            <cfset result.valid = false>
            <cfset result.message = "Session expired">
            <cfreturn result>
        </cfif>
        
        <!--- Check session timeout --->
        <cfif structKeyExists(session, "lastActivity")>
            <cfset var idleTime = dateDiff("n", session.lastActivity, now())>
            <cfif idleTime gt 20>
                <cfset structClear(session)>
                <cfset result.valid = false>
                <cfset result.message = "Session timeout">
                <cfreturn result>
            </cfif>
        </cfif>
        
        <!--- Update last activity --->
        <cfset session.lastActivity = now()>
        <cfset result.valid = true>
        <cfset result.message = "Session valid">
        <cfreturn result>
    </cffunction>
    
    <cffunction name="extendSession" returnformat="JSON" access="remote" returntype="struct">
        <cfset var result = {}>
        <cftry>
            <cfif structKeyExists(session, "loggedin") AND session.loggedin>
                <cfset session.lastActivity = now() />
                <cfset result["SUCCESS"] = true />
                <cfset result["MESSAGE"] = "Session extended successfully" />
            <cfelse>
                <cfset result["SUCCESS"] = false />
                <cfset result["MESSAGE"] = "No active session found" />
            </cfif>
        <cfcatch type="any">
            <cfset result["SUCCESS"] = false />
            <cfset result["MESSAGE"] = cfcatch.message />
        </cfcatch>
        </cftry>
        <cfreturn result />
    </cffunction>
    
    <cffunction name="isLoggedIn" returnformat="JSON" access="remote" returntype="struct">
        <cfset var result = {}>
        <cfset result["LOGGEDIN"] = (structKeyExists(session, "loggedin") AND session.loggedin) />
        <cfset result["LAST_ACTIVITY"] = (structKeyExists(session, "lastActivity") ? session.lastActivity : "") />
        <cfreturn result />
    </cffunction>
    
    <cffunction name="logout" access="remote" returntype="struct" returnformat="JSON" output="false">
        <cfset var result = {}>
        <cftry>
            <!--- Clear the session --->
            <cfset structClear(session)>
            <cfset session.loggedin = false>
            
            <cfset result.success = true>
            <cfset result.message = "Successfully logged out">
            
        <cfcatch>
            <cfset result.success = false>
            <cfset result.message = "Error during logout: " & cfcatch.message>
        </cfcatch>
        </cftry>
        <cfreturn result>
    </cffunction>
    
    <cffunction name="callErrorHandler" access="private" returntype="void">
        <cfargument name="errorMessage" required="true" type="string">
        <cfargument name="logFile" required="true" type="string">
        <cfargument name="stackTrace" required="false" type="string" default="">

        <cftry>
            <!-- Use error_handler.cfc to log the error -->
            <cfobject component="error_handler" name="errorHandler">
            <cfset errorHandler.logError(
                errorMessage = arguments.errorMessage, 
                logFile = arguments.logFile, 
                stackTrace = arguments.stackTrace
            )>
        <cfcatch type="any">
            <!-- Handle logging errors if error_handler.cfc fails -->
            <cflog file="critical_error_log" type="error" text="Failed to log error: #cfcatch.message#">
        </cfcatch>
        </cftry>
    </cffunction>
    
</cfcomponent>