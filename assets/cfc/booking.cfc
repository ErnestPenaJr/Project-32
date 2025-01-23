component {
    // Get available rooms
    remote function getAvailableRooms() returnformat="json" {
        var sql = "
            SELECT r.room_id, r.room_name, r.capacity, r.room_type, r.floor
            FROM rooms r
            WHERE r.status = 'active'
            ORDER BY r.room_name
        ";
        
        return queryToArray(queryExecute(sql));
    }

    // Create new booking
    remote function createBooking(
        required numeric user_id,
        required numeric room_id,
        required string start_time,
        required string end_time,
        string recurring_details = ""
    ) returnformat="json" {
        var result = {success: false, message: "", booking_id: 0};
        
        // Validate time slot availability
        if (isTimeSlotAvailable(arguments.room_id, arguments.start_time, arguments.end_time)) {
            try {
                var sql = "
                    INSERT INTO bookings (
                        user_id, room_id, start_time, end_time, 
                        recurring_details, status, created_at, updated_at
                    )
                    VALUES (
                        :user_id, :room_id, :start_time, :end_time,
                        :recurring_details, 'confirmed', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
                    )
                    RETURNING booking_id INTO :booking_id
                ";
                
                var params = {
                    user_id: {value: arguments.user_id, cfsqltype: "cf_sql_numeric"},
                    room_id: {value: arguments.room_id, cfsqltype: "cf_sql_numeric"},
                    start_time: {value: arguments.start_time, cfsqltype: "cf_sql_timestamp"},
                    end_time: {value: arguments.end_time, cfsqltype: "cf_sql_timestamp"},
                    recurring_details: {value: arguments.recurring_details, cfsqltype: "cf_sql_varchar"},
                    booking_id: {value: 0, cfsqltype: "cf_sql_numeric", direction: 2}
                };
                
                queryExecute(sql, params);
                
                result.success = true;
                result.message = "Booking created successfully";
                result.booking_id = params.booking_id.value;
            } catch (any e) {
                result.message = "Error creating booking: " & e.message;
            }
        } else {
            result.message = "Selected time slot is not available";
        }
        
        return result;
    }

    // Check if time slot is available
    private boolean function isTimeSlotAvailable(
        required numeric room_id,
        required string start_time,
        required string end_time
    ) {
        var sql = "
            SELECT COUNT(*) as conflict_count
            FROM bookings
            WHERE room_id = :room_id
            AND status = 'confirmed'
            AND (
                (start_time BETWEEN :start_time AND :end_time)
                OR (end_time BETWEEN :start_time AND :end_time)
                OR (start_time <= :start_time AND end_time >= :end_time)
            )
        ";
        
        var params = {
            room_id: {value: arguments.room_id, cfsqltype: "cf_sql_numeric"},
            start_time: {value: arguments.start_time, cfsqltype: "cf_sql_timestamp"},
            end_time: {value: arguments.end_time, cfsqltype: "cf_sql_timestamp"}
        };
        
        var result = queryExecute(sql, params);
        return result.conflict_count[1] == 0;
    }

    // Get user bookings
    remote function getUserBookings(
        required numeric user_id,
        string start_date = "",
        string end_date = "",
        string status = ""
    ) returnformat="json" {
        try {
            var sql = "
                SELECT 
                    b.BOOKING_ID as ID,
                    r.ROOM_NAME as TITLE,
                    b.START_TIME as START,
                    b.END_TIME as END,
                    b.STATUS as STATUS
                FROM BOOKINGS b
                JOIN ROOMS r ON b.ROOM_ID = r.ROOM_ID
                WHERE b.USER_ID = :user_id
                AND b.START_TIME >= TRUNC(SYSDATE)
            ";
            
            // Add optional filters
            if (len(arguments.start_date)) {
                sql &= " AND b.START_TIME >= :start_date";
            }
            if (len(arguments.end_date)) {
                sql &= " AND b.END_TIME <= :end_date";
            }
            if (len(arguments.status)) {
                sql &= " AND b.STATUS = :status";
            }
            
            sql &= " ORDER BY b.START_TIME";
            
            var params = {
                user_id: {value: arguments.user_id, cfsqltype: "cf_sql_numeric"}
            };
            
            // Add optional parameters
            if (len(arguments.start_date)) {
                params.start_date = {value: arguments.start_date, cfsqltype: "cf_sql_timestamp"};
            }
            if (len(arguments.end_date)) {
                params.end_date = {value: arguments.end_date, cfsqltype: "cf_sql_timestamp"};
            }
            if (len(arguments.status)) {
                params.status = {value: arguments.status, cfsqltype: "cf_sql_varchar"};
            }
            
            var result = queryExecute(sql, params, {datasource=this.DBSERVER});
            return {
                success: true,
                data: queryToArray(result)
            };
            
        } catch (any e) {
            return {
                success: false,
                message: "Error retrieving bookings: " & e.message,
                detail: e.detail
            };
        }
    }

    // Helper function to convert query to array
    private function queryToArray(required query qry) {
        var array = [];
        for (var row in arguments.qry) {
            arrayAppend(array, row);
        }
        return array;
    }

    // Cancel booking
    remote function cancelBooking(
        required numeric booking_id,
        required numeric user_id
    ) returnformat="json" {
        var result = {success: false, message: ""};
        
        try {
            var sql = "
                UPDATE bookings
                SET status = 'cancelled', updated_at = CURRENT_TIMESTAMP
                WHERE booking_id = :booking_id
                AND user_id = :user_id
                AND status = 'confirmed'
            ";
            
            var params = {
                booking_id: {value: arguments.booking_id, cfsqltype: "cf_sql_numeric"},
                user_id: {value: arguments.user_id, cfsqltype: "cf_sql_numeric"}
            };
            
            queryExecute(sql, params);
            
            result.success = true;
            result.message = "Booking cancelled successfully";
        } catch (any e) {
            result.message = "Error cancelling booking: " & e.message;
        }
        
        return result;
    }
}
