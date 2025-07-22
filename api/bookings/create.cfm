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
    if (!structKeyExists(requestBody, "roomId") || 
        !structKeyExists(requestBody, "startTime") || 
        !structKeyExists(requestBody, "endTime")) {
        throw(
            type="ValidationError",
            message="Missing required fields",
            detail="roomId, startTime, and endTime are required"
        );
    }
    
    // Create booking instance
    bookingObj = new components.Booking();
    
    // Create the booking
    booking = bookingObj.createBooking(
        roomId = requestBody.roomId,
        userId = session.userId,
        startTime = requestBody.startTime,
        endTime = requestBody.endTime,
        title = structKeyExists(requestBody, "title") ? requestBody.title : "",
        description = structKeyExists(requestBody, "description") ? requestBody.description : "",
        attendees = structKeyExists(requestBody, "attendees") ? requestBody.attendees : []
    );
    
    // If user has Office 365 connected, create calendar event
    if (structKeyExists(session, "office365") && structKeyExists(session.office365, "accessToken")) {
        try {
            // Get room details for location
            roomObj = new components.Room();
            room = roomObj.getRoom(requestBody.roomId);
            
            // Create Office 365 integration instance
            office365 = new components.Office365Integration();
            
            // Create calendar event
            calendarEvent = office365.createCalendarEvent(
                accessToken = session.office365.accessToken,
                subject = len(booking.title) ? booking.title : "Room Reservation",
                startTime = booking.startTime,
                endTime = booking.endTime,
                location = room.name & " - " & room.building & ", Floor " & room.floor,
                attendees = booking.attendees,
                description = booking.description
            );
            
            // Update booking with calendar event ID
            bookingObj.updateCalendarEventId(
                bookingId = booking.bookingId,
                calendarEventId = calendarEvent.id
            );
        } catch (any e) {
            // Log the error but don't fail the booking
            application.errorLogger.logError(
                "Failed to create Office 365 calendar event",
                e.message,
                e.detail
            );
        }
    }
    
    // Send notification
    notificationObj = new components.Notification();
    notificationObj.sendBookingConfirmation(booking.bookingId);
    
    // Format response
    response = {
        "success": true,
        "data": booking,
        "message": "Booking created successfully"
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
