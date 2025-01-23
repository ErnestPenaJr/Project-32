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
    <cffunction name="getAllIcons" access="remote" returntype="any" returnformat="JSON">
        <cfset var retVal = [] />
        <cfset var temp = {} />
        <cfset var result = {} />

        <cfquery name="qIcons" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
            SELECT 
                ICON_ID,
                ICON_CLASS,
                ICON_NAME
            FROM #this.DBSCHEMA#.ICONS
            ORDER BY ICON_NAME
        </cfquery>

        <cfloop query="qIcons">
            <cfset temp = {} />
            <cfset temp["ICON_ID"] = qIcons.ICON_ID />
            <cfset temp["ICON_CLASS"] = qIcons.ICON_CLASS />
            <cfset temp["ICON_NAME"] = qIcons.ICON_NAME />
            <cfset ArrayAppend(retVal, temp) />
        </cfloop>

        <cfset result["icons"] = retVal />
        <cfreturn result />
    </cffunction>

    <cffunction name="getIcon" access="remote" returntype="any" returnformat="JSON">
        <cfargument name="iconId" type="numeric" required="true">
        <cfset var retVal = [] />
        <cfset var temp = {} />
        <cfset var result = {} />

        <cfquery name="qIcons" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
            SELECT 
                ICON_ID,
                ICON_CLASS,
                ICON_NAME
            FROM #this.DBSCHEMA#.ICONS
            WHERE ICON_ID = <cfqueryparam value="#arguments.iconId#" cfsqltype="cf_sql_numeric">
        </cfquery>

        <cfset temp = {} />
        <cfset temp["ICON_ID"] = qIcons.ICON_ID />
        <cfset temp["ICON_CLASS"] = qIcons.ICON_CLASS />
        <cfset temp["ICON_NAME"] = qIcons.ICON_NAME />
        <cfset ArrayAppend(retVal, temp) />

        <cfset result["icons"] = retVal />
        <cfreturn result />
    </cffunction>

     <cffunction name="addIcon" access="remote" returntype="any" returnformat="JSON">
        <cfargument name="iconClass" type="string" required="true" />
        <cfargument name="iconName" type="string" required="true" />

        <cfquery name="qAddIcon" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
            INSERT INTO #this.DBSCHEMA#.ICONS (ICON_CLASS, ICON_NAME) VALUES 
            (<cfqueryparam value="#arguments.iconClass#" cfsqltype="cf_sql_varchar">, <cfqueryparam value="#arguments.iconName#" cfsqltype="cf_sql_varchar">)
        </cfquery>

        <cfreturn true />

     </cffunction>
     
     <cffunction name="deleteIcon" access="remote" returntype="any" returnformat="JSON">
        <cfargument name="iconId" type="numeric" required="true">
        <cfquery name="qDeleteIcon" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
            DELETE FROM #this.DBSCHEMA#.ICONS WHERE ICON_ID = <cfqueryparam value="#arguments.iconId#" cfsqltype="cf_sql_numeric">
        </cfquery>
        <cfreturn true />
     </cffunction>
</cfcomponent>