component {
    // Microsoft Graph API endpoints
    variables.graphApiEndpoint = "https://graph.microsoft.com/v1.0";
    variables.authEndpoint = "https://login.microsoftonline.com/common/oauth2/v2.0";
    
    // Constructor
    public function init() {
        variables.clientId = application.office365Config.clientId;
        variables.clientSecret = application.office365Config.clientSecret;
        variables.redirectUri = application.office365Config.redirectUri;
        variables.scopes = "Calendars.ReadWrite User.Read";
        return this;
    }
    
    // Get OAuth authorization URL
    public string function getAuthorizationUrl() {
        var authUrl = variables.authEndpoint & "/authorize";
        authUrl &= "?client_id=" & variables.clientId;
        authUrl &= "&response_type=code";
        authUrl &= "&redirect_uri=" & urlEncodedFormat(variables.redirectUri);
        authUrl &= "&scope=" & urlEncodedFormat(variables.scopes);
        authUrl &= "&response_mode=query";
        return authUrl;
    }
    
    // Exchange authorization code for access token
    public struct function getAccessToken(required string code) {
        var httpService = new http();
        httpService.setMethod("POST");
        httpService.setUrl(variables.authEndpoint & "/token");
        
        var body = {
            client_id: variables.clientId,
            client_secret: variables.clientSecret,
            code: arguments.code,
            redirect_uri: variables.redirectUri,
            grant_type: "authorization_code"
        };
        
        httpService.addParam(type="header", name="Content-Type", value="application/x-www-form-urlencoded");
        httpService.addParam(type="body", value=buildHttpQuery(body));
        
        var response = httpService.send().getPrefix();
        return deserializeJSON(response.fileContent);
    }
    
    // Refresh access token
    public struct function refreshToken(required string refreshToken) {
        var httpService = new http();
        httpService.setMethod("POST");
        httpService.setUrl(variables.authEndpoint & "/token");
        
        var body = {
            client_id: variables.clientId,
            client_secret: variables.clientSecret,
            refresh_token: arguments.refreshToken,
            grant_type: "refresh_token"
        };
        
        httpService.addParam(type="header", name="Content-Type", value="application/x-www-form-urlencoded");
        httpService.addParam(type="body", value=buildHttpQuery(body));
        
        var response = httpService.send().getPrefix();
        return deserializeJSON(response.fileContent);
    }
    
    // Create calendar event
    public struct function createCalendarEvent(
        required string accessToken,
        required string subject,
        required string startTime,
        required string endTime,
        required string location,
        required array attendees,
        string description = ""
    ) {
        var httpService = new http();
        httpService.setMethod("POST");
        httpService.setUrl(variables.graphApiEndpoint & "/me/events");
        
        var eventBody = {
            "subject": arguments.subject,
            "start": {
                "dateTime": arguments.startTime,
                "timeZone": "UTC"
            },
            "end": {
                "dateTime": arguments.endTime,
                "timeZone": "UTC"
            },
            "location": {
                "displayName": arguments.location
            },
            "body": {
                "contentType": "HTML",
                "content": arguments.description
            }
        };
        
        // Add attendees
        if (arrayLen(arguments.attendees)) {
            eventBody["attendees"] = [];
            for (var attendee in arguments.attendees) {
                arrayAppend(eventBody["attendees"], {
                    "emailAddress": {
                        "address": attendee
                    },
                    "type": "required"
                });
            }
        }
        
        httpService.addParam(type="header", name="Authorization", value="Bearer #arguments.accessToken#");
        httpService.addParam(type="header", name="Content-Type", value="application/json");
        httpService.addParam(type="body", value=serializeJSON(eventBody));
        
        var response = httpService.send().getPrefix();
        return deserializeJSON(response.fileContent);
    }
    
    // Get user's calendar events
    public array function getCalendarEvents(
        required string accessToken,
        string startDateTime = "",
        string endDateTime = ""
    ) {
        var httpService = new http();
        httpService.setMethod("GET");
        var url = variables.graphApiEndpoint & "/me/events";
        
        // Add date filters if provided
        if (len(arguments.startDateTime) && len(arguments.endDateTime)) {
            url &= "?$filter=start/dateTime ge '" & arguments.startDateTime;
            url &= "' and end/dateTime le '" & arguments.endDateTime & "'";
        }
        
        httpService.setUrl(url);
        httpService.addParam(type="header", name="Authorization", value="Bearer #arguments.accessToken#");
        
        var response = httpService.send().getPrefix();
        var result = deserializeJSON(response.fileContent);
        return result.value ?: [];
    }
    
    // Cancel calendar event
    public void function cancelCalendarEvent(
        required string accessToken,
        required string eventId,
        string comment = ""
    ) {
        var httpService = new http();
        httpService.setMethod("POST");
        httpService.setUrl(variables.graphApiEndpoint & "/me/events/" & arguments.eventId & "/cancel");
        
        var cancelBody = {};
        if (len(arguments.comment)) {
            cancelBody["Comment"] = arguments.comment;
        }
        
        httpService.addParam(type="header", name="Authorization", value="Bearer #arguments.accessToken#");
        httpService.addParam(type="header", name="Content-Type", value="application/json");
        httpService.addParam(type="body", value=serializeJSON(cancelBody));
        
        httpService.send();
    }
    
    // Helper function to build query string
    private string function buildHttpQuery(required struct params) {
        var queryString = "";
        for (var key in params) {
            if (len(queryString)) queryString &= "&";
            queryString &= urlEncodedFormat(key) & "=" & urlEncodedFormat(params[key]);
        }
        return queryString;
    }
}
