component {
    // Get dashboard data
    remote struct function getDashboardData() returnformat="json" {
        var response = {};
        
        // Get room statistics
        response.roomStats = application.roomService.getRoomStatistics();
        
        // Get featured rooms
        var featuredRooms = queryExecute("
            SELECT r.*, COUNT(ra.AMENITY_ID) as AMENITY_COUNT,
                   LISTAGG(a.AMENITY_NAME, ', ') WITHIN GROUP (ORDER BY a.AMENITY_NAME) as AMENITIES
            FROM ROOMS r
            LEFT JOIN ROOM_AMENITIES ra ON r.ROOM_ID = ra.ROOM_ID
            LEFT JOIN AMENITIES a ON ra.AMENITY_ID = a.AMENITY_ID
            WHERE r.MAINTENANCE_STATUS = 'Available'
            GROUP BY r.ROOM_ID, r.ROOM_NAME, r.BUILDING, r.FLOOR, r.CAPACITY, r.DESCRIPTION, r.MAINTENANCE_STATUS
            ORDER BY COUNT(ra.AMENITY_ID) DESC, r.CAPACITY DESC
            FETCH FIRST 3 ROWS ONLY
        ", {}, {datasource=application.dsn});
        
        response.featuredRooms = queryToArray(featuredRooms);
        
        // Get user's upcoming bookings if logged in
        if (session.loggedin) {
            response.upcomingBookings = application.bookingService.getUserBookings(session.userid, "Confirmed");
        }
        
        return response;
    }

    // Helper function to convert query to array
    private array function queryToArray(required query qry) {
        var array = [];
        for(var i = 1; i <= qry.recordCount; i++) {
            var row = {};
            for(var column in qry.columnList) {
                row[column] = qry[column][i];
            }
            arrayAppend(array, row);
        }
        return array;
    }
}
