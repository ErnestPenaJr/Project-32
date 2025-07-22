<cfscript>
// Set content type to JSON
getPageContext().getResponse().setContentType("application/json");

// Ensure request is POST
if (cgi.request_method neq "POST") {
    getPageContext().getResponse().setStatus(405);
    writeOutput(serializeJSON({
        "success": false,
        "message": "Method not allowed"
    }));
    abort;
}

// Get POST data
requestBody = deserializeJSON(toString(getHttpRequestData().content));

try {
    // Validate required fields
    if (!structKeyExists(requestBody, "bookingId")) {
        throw(
            type="ValidationError",
            message="Missing required fields",
            detail="bookingId is required"
        );
    }
    
    // Create booking instance
    bookingObj = new components.Booking();
    
    // Verify user has permission to cancel this booking
    if (!bookingObj.canUserModifyBooking(requestBody.bookingId, session.userId)) {
        getPageContext().getResponse().setStatus(403);
        throw(
            type="PermissionError",
            message="Unauthorized",
            detail="You don't have permission to cancel this booking"
        );
    }
    
    // Cancel the booking
    bookingObj.cancelBooking(
        bookingId = requestBody.bookingId,
        reason = structKeyExists(requestBody, "reason") ? requestBody.reason : ""
    );
    
    // If user has Office 365 connected and booking has a calendar event, cancel it
    if (structKeyExists(session, "office365") && structKeyExists(session.office365, "accessToken")) {
        try {
            // Get booking details to check for calendar event
            booking = bookingObj.getBooking(requestBody.bookingId);
            
            if (len(booking.calendarEventId)) {
                // Create Office 365 integration instance
                office365 = new components.Office365Integration();
                
                // Cancel calendar event
                office365.cancelCalendarEvent(
                    accessToken = session.office365.accessToken,
                    eventId = booking.calendarEventId,
                    comment = structKeyExists(requestBody, "reason") ? requestBody.reason : "Booking cancelled"
                );
            }
        } catch (any e) {
            // Log the error but don't fail the cancellation
            application.errorLogger.logError(
                "Failed to cancel Office 365 calendar event",
                e.message,
                e.detail
            );
        }
    }
    
    // Send cancellation notification
    notificationObj = new components.Notification();
    notificationObj.sendBookingCancellation(requestBody.bookingId);
    
    // Format response
    response = {
        "success": true,
        "message": "Booking cancelled successfully"
    };
} catch (any e) {
    response = {
        "success": false,
        "message": e.message,
        "detail": e.detail
    };
    if (e.type eq "PermissionError") {
        getPageContext().getResponse().setStatus(403);
    } else {
        getPageContext().getResponse().setStatus(500);
    }
}

// Output JSON response
writeOutput(serializeJSON(response));
</cfscript>
