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

    <cffunction name="helpRequest" access="remote" returntype="any" returnformat="JSON">
        <cfargument name="emplid" type="string" required="false" default="" />
        <cfargument name="description" type="string" required="false" default="" />
        <cfargument name="priority" type="string" required="false" default="" />
        <cfargument name="priorityText" type="string" required="false" default="" />

        <cfquery datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#" name="results">
			SELECT
            PS.NAME_DISPLAY,
            LOWER(PS.WORK_EMAIL) AS EMAIL
            FROM DS.NEW_PS_EMP PS
            WHERE PS.HR_STATUS = 'A'
            AND PS.EMPLID = <cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.emplid#" >
		</cfquery>

        <!--- Send email to DoCM Application Developers DoCMApplicationDevelopers@mdanderson.org ,cpender@mdanderson.org bcc="erniep@mdanderson.org,cpender@mdanderson.org, tlouie@mdanderson.org,tglover@mdanderson.org"--->    
        <cfmail to="DoCMApplicationDevelopers@mdanderson.org" from="#results.EMAIL#" bcc="erniep@mdanderson.org,cpender@mdanderson.org, tlouie@mdanderson.org,tglover@mdanderson.org" subject="DoCM Office Space Help Request" type="html">
            <cfoutput>
                <p><strong>Name:</strong> #results.NAME_DISPLAY#</p>
                <p><strong>Email:</strong> #results.EMAIL#</p>
                <p><strong>Priority:</strong> #arguments.priorityText#</p>
                <p><strong>Description:</strong> #arguments.description#</p>
            </cfoutput>
        </cfmail>

        <cfset response = {status="success"} />
        <cfreturn response />

    </cffunction>
</cfcomponent>