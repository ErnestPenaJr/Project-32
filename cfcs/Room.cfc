component {
    // Properties matching our table structure
    property name="roomID" type="string";
    property name="roomName" type="string";
    property name="deptID" type="string";
    property name="location" type="string";
    property name="capacity" type="numeric";
    property name="telecomType" type="string";
    property name="videoconf" type="boolean";
    property name="clickshare" type="boolean";
    property name="startDateTime" type="date";
    property name="endDateTime" type="date";
    property name="enteredByID" type="string";
    property name="dateEntered" type="date";
    property name="modifiedByID" type="string";
    property name="dateModified" type="date";
    property name="status" type="string";
    property name="eventColor" type="string";
    property name="roomType" type="string";
    property name="hasDoor" type="boolean";
    property name="floor" type="string";
    property name="building" type="string";
    property name="roomDescription" type="string";
    property name="roomImage" type="string";
    property name="computer" type="boolean";
    property name="phone" type="boolean";
    property name="camera" type="boolean";
    property name="keyboardMouse" type="boolean";
    property name="dockingStation" type="boolean";
    property name="monitors" type="numeric";
    property name="recurring" type="boolean";
    property name="maintenance" type="boolean";
    property name="equipment" type="string";
    property name="comments" type="string";
    property name="department" type="string";

    // Constructor
    public function init() {
        variables.dbService = application.dbService;
        return this;
    }

    // Get all rooms
    remote array function getAllRooms() returnformat="json" {
        var sql = "SELECT * FROM rooms ORDER BY roomName";
        return variables.dbService.executeQuery(sql);
    }

    // Get room by ID
    remote struct function getRoomByID(required string roomID) returnformat="json" {
        var sql = "SELECT * FROM rooms WHERE roomID = :roomID";
        var params = {roomID = arguments.roomID};
        var result = variables.dbService.executeQuery(sql, params);
        return result.len() ? result[1] : {};
    }

    // Create new room
    remote boolean function createRoom() returnformat="json" {
        try {
            var roomData = {
                roomName = form.roomName,
                deptID = form.deptId,
                location = form.location,
                capacity = form.capacity,
                videoconf = form.videoconf,
                clickshare = form.clickshare,
                status = 'ACTIVE',
                roomType = form.roomType,
                hasDoor = form.hasDoor,
                floor = form.floor,
                building = form.building,
                roomDescription = form.roomDescription,
                computer = form.computer,
                phone = form.phone,
                camera = form.camera,
                equipment = form.equipment,
                comments = form.comments,
                enteredByID = session.userID,
                dateEntered = now(),
                modifiedByID = session.userID,
                dateModified = now()
            };
            
            var columns = structKeyList(roomData);
            var values = columns.listMap(function(item) {
                return ":" & item;
            });
            
            var sql = "
                INSERT INTO rooms (#columns#)
                VALUES (#values#)
            ";
            
            variables.dbService.executeQuery(sql, roomData);
            return true;
        } catch (any e) {
            writeLog(
                file = "roomError",
                type = "error",
                text = "Error creating room: " & e.message
            );
            return false;
        }
    }

    // Update room
    remote boolean function updateRoom() returnformat="json" {
        try {
            var roomData = {
                roomID = form.roomId,
                roomName = form.roomName,
                deptID = form.deptId,
                location = form.location,
                capacity = form.capacity,
                videoconf = form.videoconf,
                clickshare = form.clickshare,
                roomType = form.roomType,
                hasDoor = form.hasDoor,
                floor = form.floor,
                building = form.building,
                roomDescription = form.roomDescription,
                computer = form.computer,
                phone = form.phone,
                camera = form.camera,
                equipment = form.equipment,
                comments = form.comments,
                modifiedByID = session.userID,
                dateModified = now()
            };
            
            var updates = structKeyList(roomData)
                .listToArray()
                .filter(function(item) {
                    return item != "roomID";
                })
                .map(function(item) {
                    return item & " = :" & item;
                })
                .toList();
            
            var sql = "
                UPDATE rooms
                SET #updates#
                WHERE roomID = :roomID
            ";
            
            variables.dbService.executeQuery(sql, roomData);
            return true;
        } catch (any e) {
            writeLog(
                file = "roomError",
                type = "error",
                text = "Error updating room: " & e.message
            );
            return false;
        }
    }

    // Delete room
    remote boolean function deleteRoom() returnformat="json" {
        try {
            var sql = "DELETE FROM rooms WHERE roomID = :roomID";
            var params = {roomID = form.roomID};
            variables.dbService.executeQuery(sql, params);
            return true;
        } catch (any e) {
            writeLog(
                file = "roomError",
                type = "error",
                text = "Error deleting room: " & e.message
            );
            return false;
        }
    }

    // Get departments for dropdown
    remote array function getDepartments() returnformat="json" {
        var sql = "SELECT * FROM departments ORDER BY department_name";
        return variables.dbService.executeQuery(sql);
    }
}
