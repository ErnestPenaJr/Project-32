component {
    property name="dsn" type="string";
    
    public function init(required string dsn) {
        variables.dsn = arguments.dsn;
        return this;
    }
    
    public function getRoomById(required numeric roomId) {
        var qRoom = queryExecute(
            "SELECT r.*, 
                    LISTAGG(a.AMENITY_NAME, ', ') WITHIN GROUP (ORDER BY a.AMENITY_NAME) as AMENITIES
             FROM ROOMS r
             LEFT JOIN ROOM_AMENITIES ra ON r.ROOM_ID = ra.ROOM_ID
             LEFT JOIN AMENITIES a ON ra.AMENITY_ID = a.AMENITY_ID
             WHERE r.ROOM_ID = :roomId
             GROUP BY r.ROOM_ID, r.ROOM_NAME, r.BUILDING, r.FLOOR, r.CAPACITY, 
                      r.DESCRIPTION, r.MAINTENANCE_STATUS",
            {roomId = {value=arguments.roomId, cfsqltype="cf_sql_numeric"}},
            {datasource=variables.dsn}
        );
        return qRoom;
    }
    
    public function searchRooms(struct criteria = {}) {
        var sql = "SELECT r.*, 
                         LISTAGG(a.AMENITY_NAME, ', ') WITHIN GROUP (ORDER BY a.AMENITY_NAME) as AMENITIES
                  FROM ROOMS r
                  LEFT JOIN ROOM_AMENITIES ra ON r.ROOM_ID = ra.ROOM_ID
                  LEFT JOIN AMENITIES a ON ra.AMENITY_ID = a.AMENITY_ID
                  WHERE 1=1 ";
        var params = {};
        
        if (structKeyExists(arguments.criteria, "building")) {
            sql &= "AND r.BUILDING = :building ";
            params.building = {value=arguments.criteria.building, cfsqltype="cf_sql_varchar"};
        }
        
        if (structKeyExists(arguments.criteria, "floor")) {
            sql &= "AND r.FLOOR = :floor ";
            params.floor = {value=arguments.criteria.floor, cfsqltype="cf_sql_numeric"};
        }
        
        if (structKeyExists(arguments.criteria, "minCapacity")) {
            sql &= "AND r.CAPACITY >= :minCapacity ";
            params.minCapacity = {value=arguments.criteria.minCapacity, cfsqltype="cf_sql_numeric"};
        }
        
        if (structKeyExists(arguments.criteria, "amenities")) {
            sql &= "AND EXISTS (
                    SELECT 1 FROM ROOM_AMENITIES ra2 
                    JOIN AMENITIES a2 ON ra2.AMENITY_ID = a2.AMENITY_ID
                    WHERE ra2.ROOM_ID = r.ROOM_ID 
                    AND a2.AMENITY_NAME IN (:amenities)
                   ) ";
            params.amenities = {value=arguments.criteria.amenities, list=true, cfsqltype="cf_sql_varchar"};
        }
        
        sql &= "GROUP BY r.ROOM_ID, r.ROOM_NAME, r.BUILDING, r.FLOOR, r.CAPACITY, 
                         r.DESCRIPTION, r.MAINTENANCE_STATUS";
        
        var qRooms = queryExecute(sql, params, {datasource=variables.dsn});
        return qRooms;
    }
    
    public function checkAvailability(required numeric roomId, required date startTime, required date endTime) {
        var qBookings = queryExecute(
            "SELECT COUNT(*) as CONFLICT_COUNT
             FROM BOOKINGS
             WHERE ROOM_ID = :roomId
             AND STATUS = 'Confirmed'
             AND NOT (END_TIME <= :startTime OR START_TIME >= :endTime)",
            {
                roomId = {value=arguments.roomId, cfsqltype="cf_sql_numeric"},
                startTime = {value=arguments.startTime, cfsqltype="cf_sql_timestamp"},
                endTime = {value=arguments.endTime, cfsqltype="cf_sql_timestamp"}
            },
            {datasource=variables.dsn}
        );
        return qBookings.CONFLICT_COUNT == 0;
    }
    
    public function updateMaintenanceStatus(required numeric roomId, required string status) {
        queryExecute(
            "UPDATE ROOMS 
             SET MAINTENANCE_STATUS = :status
             WHERE ROOM_ID = :roomId",
            {
                roomId = {value=arguments.roomId, cfsqltype="cf_sql_numeric"},
                status = {value=arguments.status, cfsqltype="cf_sql_varchar"}
            },
            {datasource=variables.dsn}
        );
        return true;
    }
    
    public function getRoomStatistics() {
        var qStats = queryExecute(
            "SELECT 
                COUNT(*) as TOTAL_ROOMS,
                SUM(CASE WHEN MAINTENANCE_STATUS = 'Available' THEN 1 ELSE 0 END) as AVAILABLE_ROOMS,
                SUM(CASE WHEN MAINTENANCE_STATUS = 'Under Maintenance' THEN 1 ELSE 0 END) as MAINTENANCE_ROOMS,
                AVG(CAPACITY) as AVG_CAPACITY
             FROM ROOMS",
            {},
            {datasource=variables.dsn}
        );
        return qStats;
    }
}
