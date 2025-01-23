<cfscript>
// Set content type to JSON
getPageContext().getResponse().setContentType("application/json");

// Get query parameters
param name="url.roomId" default="";
param name="url.date" default="#dateFormat(now(), 'yyyy-mm-dd')#";

try {
    // Validate required fields
    if (len(url.roomId) eq 0) {
        throw(
            type="ValidationError",
            message="Missing required fields",
            detail="roomId is required"
        );
    }
    
    // Create room instance
    roomObj = new components.Room();
    
    // Get room availability
    availability = roomObj.getRoomAvailability(
        roomId = url.roomId,
        date = url.date
    );
    
    // Format response
    response = {
        "success": true,
        "data": {
            "roomId": url.roomId,
            "date": url.date,
            "timeSlots": availability
        },
        "message": "Room availability retrieved successfully"
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
