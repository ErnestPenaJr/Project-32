component {
    property name="dsn" type="string";
    property name="roomService";
    property name="notificationService";
    
    public function init(required string dsn, required any roomService, required any notificationService) {
        variables.dsn = arguments.dsn;
        variables.roomService = arguments.roomService;
        variables.notificationService = arguments.notificationService;
        return this;
    }
    
    public function createBooking(required struct bookingData) {
        // Check room availability first
        if (!variables.roomService.checkAvailability(
            bookingData.roomId,
            bookingData.startTime,
            bookingData.endTime
        )) {
            throw(type="Booking.ConflictError", message="Room is not available for the selected time slot");
        }
        
        transaction {
            try {
                var qCreate = queryExecute(
                    "INSERT INTO BOOKINGS (USER_ID, ROOM_ID, START_TIME, END_TIME, RECURRING_DETAILS, STATUS) 
                     VALUES (:userId, :roomId, :startTime, :endTime, :recurringDetails, :status)
                     RETURNING BOOKING_ID INTO :generatedId",
                    {
                        userId = {value=arguments.bookingData.userId, cfsqltype="cf_sql_numeric"},
                        roomId = {value=arguments.bookingData.roomId, cfsqltype="cf_sql_numeric"},
                        startTime = {value=arguments.bookingData.startTime, cfsqltype="cf_sql_timestamp"},
                        endTime = {value=arguments.bookingData.endTime, cfsqltype="cf_sql_timestamp"},
                        recurringDetails = {value=arguments.bookingData.recurringDetails, null=(arguments.bookingData.recurringDetails == ""), cfsqltype="cf_sql_varchar"},
                        status = {value='Confirmed', cfsqltype="cf_sql_varchar"},
                        generatedId = {type="out", variable="newBookingId", cfsqltype="cf_sql_numeric"}
                    },
                    {datasource=variables.dsn, result="result"}
                );
                
                // Send notification
                variables.notificationService.sendBookingConfirmation(result.generatedKey);
                
                transaction action="commit";
                return result.generatedKey;
            }
            catch (any e) {
                transaction action="rollback";
                rethrow;
            }
        }
    }
    
    public function getBookingById(required numeric bookingId) {
        var qBooking = queryExecute(
            "SELECT b.*, 
                    r.ROOM_NAME, r.BUILDING, r.FLOOR,
                    u.FIRST_NAME, u.LAST_NAME, u.EMAIL
             FROM BOOKINGS b
             JOIN ROOMS r ON b.ROOM_ID = r.ROOM_ID
             JOIN USERS u ON b.USER_ID = u.USER_ID
             WHERE b.BOOKING_ID = :bookingId",
            {bookingId = {value=arguments.bookingId, cfsqltype="cf_sql_numeric"}},
            {datasource=variables.dsn}
        );
        return qBooking;
    }
    
    public function getUserBookings(required numeric userId, string status = "") {
        var sql = "SELECT b.*, 
                         r.ROOM_NAME, r.BUILDING, r.FLOOR
                  FROM BOOKINGS b
                  JOIN ROOMS r ON b.ROOM_ID = r.ROOM_ID
                  WHERE b.USER_ID = :userId ";
        var params = {
            userId = {value=arguments.userId, cfsqltype="cf_sql_numeric"}
        };
        
        if (len(arguments.status)) {
            sql &= "AND b.STATUS = :status ";
            params.status = {value=arguments.status, cfsqltype="cf_sql_varchar"};
        }
        
        sql &= "ORDER BY b.START_TIME DESC";
        
        var qBookings = queryExecute(sql, params, {datasource=variables.dsn});
        return qBookings;
    }
    
    public function cancelBooking(required numeric bookingId, required numeric userId) {
        var qBooking = queryExecute(
            "SELECT USER_ID, STATUS FROM BOOKINGS WHERE BOOKING_ID = :bookingId",
            {bookingId = {value=arguments.bookingId, cfsqltype="cf_sql_numeric"}},
            {datasource=variables.dsn}
        );
        
        if (qBooking.recordCount == 0) {
            throw(type="Booking.NotFound", message="Booking not found");
        }
        
        if (qBooking.USER_ID != arguments.userId) {
            throw(type="Booking.Unauthorized", message="User not authorized to cancel this booking");
        }
        
        if (qBooking.STATUS == 'Cancelled') {
            throw(type="Booking.AlreadyCancelled", message="Booking is already cancelled");
        }
        
        queryExecute(
            "UPDATE BOOKINGS SET STATUS = 'Cancelled', UPDATED_AT = CURRENT_TIMESTAMP 
             WHERE BOOKING_ID = :bookingId",
            {bookingId = {value=arguments.bookingId, cfsqltype="cf_sql_numeric"}},
            {datasource=variables.dsn}
        );
        
        // Send cancellation notification
        variables.notificationService.sendBookingCancellation(bookingId);
        
        return true;
    }
    
    public function getRoomBookings(required numeric roomId, required date startDate, required date endDate) {
        var qBookings = queryExecute(
            "SELECT b.*, 
                    u.FIRST_NAME, u.LAST_NAME
             FROM BOOKINGS b
             JOIN USERS u ON b.USER_ID = u.USER_ID
             WHERE b.ROOM_ID = :roomId
             AND b.START_TIME >= :startDate
             AND b.END_TIME <= :endDate
             AND b.STATUS = 'Confirmed'
             ORDER BY b.START_TIME",
            {
                roomId = {value=arguments.roomId, cfsqltype="cf_sql_numeric"},
                startDate = {value=arguments.startDate, cfsqltype="cf_sql_timestamp"},
                endDate = {value=arguments.endDate, cfsqltype="cf_sql_timestamp"}
            },
            {datasource=variables.dsn}
        );
        return qBookings;
    }
}
