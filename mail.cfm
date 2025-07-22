<cfoutput>
    #server.coldfusion.productName#
    <cfset serverName = #GetPageContext().GetRequest().GetServerName().ToString()# />
    <cfif findNoCase("s-cmapps.mdanderson.org", serverName) or findNoCase("s-cmapps-a.mdanderson.org", serverName) or findNoCase("s-cmapps-b.mdanderson.org", serverName)>
        STAGING
    <cfelseif findNoCase("cmapps.mdanderson.org", serverName) or  findNoCase("cmapps-a.mdanderson.org", serverName) or  findNoCase("cmapps-b.mdanderson.org", serverName)>
        PROD
    <cfelse>
        TESTING
    </cfif>
            
</cfoutput>     