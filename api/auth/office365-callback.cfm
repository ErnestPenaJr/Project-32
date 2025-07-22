<cfscript>
// Set content type to JSON
getPageContext().getResponse().setContentType("application/json");

try {
    // Validate the authorization code
    if (!structKeyExists(url, "code")) {
        throw(
            type="ValidationError",
            message="Missing authorization code",
            detail="The authorization code from Office 365 is required"
        );
    }
    
    // Create Office 365 integration instance
    office365 = new components.Office365Integration();
    
    // Exchange the code for access token
    tokenResponse = office365.getAccessToken(url.code);
    
    // Store tokens in session
    session.office365 = {
        accessToken: tokenResponse.access_token,
        refreshToken: tokenResponse.refresh_token,
        expiresIn: tokenResponse.expires_in,
        tokenTimestamp: now()
    };
    
    // Update user's Office 365 connection status
    userObj = new components.User();
    userObj.updateOffice365Status(
        userId = session.userId,
        isConnected = true,
        refreshToken = tokenResponse.refresh_token
    );
    
    // Format response
    response = {
        "success": true,
        "message": "Successfully connected to Office 365"
    };
} catch (any e) {
    response = {
        "success": false,
        "message": e.message,
        "detail": e.detail
    };
    getPageContext().getResponse().setStatus(500);
}

// Output JSON response
writeOutput(serializeJSON(response));
</cfscript>
