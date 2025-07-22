<cfscript>
// Office 365 Configuration
application.office365Config = {
    // Application (client) ID from Azure AD app registration
    clientId: "YOUR_CLIENT_ID",
    
    // Client secret from Azure AD app registration
    clientSecret: "YOUR_CLIENT_SECRET",
    
    // Redirect URI for OAuth callback
    redirectUri: "https://your-domain.com/api/auth/office365-callback.cfm",
    
    // Tenant ID (use "common" for multi-tenant apps)
    tenantId: "common"
};
</cfscript>
