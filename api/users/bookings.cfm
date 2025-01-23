<cfscript>
// Set content type to JSON
getPageContext().getResponse().setContentType("application/json");

// Get query parameters
param name="url.status" default="active";  // active, past, cancelled
param name="url.page" default="1";
param name="url.limit" default="10";

try {
    // Create booking instance
    bookingObj = new components.Booking();
    
    // Get user's bookings
    bookings = bookingObj.getUserBookings(
        userId = session.userId,
        status = url.status,
        page = val(url.page),
        limit = val(url.limit)
    );
    
    // Format response
    response = {
        "success": true,
        "data": {
            "bookings": bookings.items,
            "pagination": {
                "currentPage": bookings.currentPage,
                "totalPages": bookings.totalPages,
                "totalItems": bookings.totalItems,
                "limit": bookings.limit
            }
        },
        "message": "Bookings retrieved successfully"
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
