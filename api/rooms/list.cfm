<cfscript>
// Set content type to JSON
getPageContext().getResponse().setContentType("application/json");

// Get query parameters
param name="url.building" default="";
param name="url.floor" default="";
param name="url.capacity" default="0";
param name="url.date" default="";
param name="url.amenities" default="";

try {
    // Create instance of Room component
    roomObj = new components.Room();
    
    // Get rooms based on filters
    rooms = roomObj.getRooms(
        building = url.building,
        floor = url.floor,
        capacity = val(url.capacity),
        date = url.date,
        amenities = url.amenities
    );
    
    // Format response
    response = {
        "success": true,
        "data": rooms,
        "message": "Rooms retrieved successfully"
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
