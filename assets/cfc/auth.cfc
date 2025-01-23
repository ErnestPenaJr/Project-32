<cfcomponent>
    <cffunction name="login" access="remote" returntype="struct" returnformat="JSON">
        <cfargument name="username" type="string" required="true">
        <cfargument name="password" type="string" required="true">
        
        <cfset var response = {}>
        
        <cftry>
            <cfquery name="qLogin" datasource="booking_system">
                SELECT user_id, name, password, is_admin
                FROM users
                WHERE username = <cfqueryparam value="#arguments.username#" cfsqltype="cf_sql_varchar">
            </cfquery>
            
            <cfif qLogin.recordCount EQ 1>
                <cfif hash(arguments.password, "SHA-256") EQ qLogin.password>
                    <cfset session.loggedin = true>
                    <cfset session.userid = qLogin.user_id>
                    <cfset session.name = qLogin.name>
                    <cfset session.isadmin = qLogin.is_admin>
                    
                    <cfset response = {
                        "success" = true,
                        "userid" = qLogin.user_id,
                        "name" = qLogin.name,
                        "isadmin" = qLogin.is_admin
                    }>
                <cfelse>
                    <cfset response = {
                        "success" = false,
                        "message" = "Invalid password"
                    }>
                </cfif>
            <cfelse>
                <cfset response = {
                    "success" = false,
                    "message" = "User not found"
                }>
            </cfif>
            
            <cfcatch>
                <cfset response = {
                    "success" = false,
                    "message" = "An error occurred during login"
                }>
            </cfcatch>
        </cftry>
        
        <cfreturn response>
    </cffunction>
    
    <cffunction name="logout" access="remote" returntype="struct" returnformat="JSON">
        <cfset var response = {}>
        
        <cftry>
            <cfset structClear(session)>
            <cfset response = {
                "success" = true,
                "message" = "Successfully logged out"
            }>
            
            <cfcatch>
                <cfset response = {
                    "success" = false,
                    "message" = "An error occurred during logout"
                }>
            </cfcatch>
        </cftry>
        
        <cfreturn response>
    </cffunction>
    
    <cffunction name="checkSession" access="remote" returntype="struct" returnformat="JSON">
        <cfset var response = {}>
        
        <cfif structKeyExists(session, "loggedin") AND session.loggedin>
            <cfset response = {
                "success" = true,
                "userid" = session.userid,
                "name" = session.name,
                "isadmin" = session.isadmin
            }>
        <cfelse>
            <cfset response = {
                "success" = false,
                "message" = "No active session"
            }>
        </cfif>
        
        <cfreturn response>
    </cffunction>
</cfcomponent>
