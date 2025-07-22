<cfcomponent>
    <cfif ListFirst(CGI.SERVER_NAME,'.') EQ 'cmapps'>
        <cfset this.DBSERVER = "inside2_docmp" />
        <cfset this.DBUSER = "CONFROOM_USER" />
        <cfset this.DBPASS = "1DOCMAU4CNFRM6" />
         <cfset this.DBSCHEMA = "CONFROOM" />
    <cfelseif ListFirst(CGI.SERVER_NAME,'.') EQ 's-cmapps'>
        <cfset this.DBSERVER = "inside2_docms" />
        <cfset this.DBUSER = "CONFROOM" />
        <cfset this.DBPASS = "1DOCMOA4CNFRM3" />
        <cfset this.DBSCHEMA = "CONFROOM" />
    <cfelse>
        <cfset this.DBSERVER = "inside2_docmd" />
        <cfset this.DBUSER = "CONFROOM" />
        <cfset this.DBPASS = "1DOCMOA4CNFRM3" />
        <cfset this.DBSCHEMA = "CONFROOM" />
    </cfif>
    <!--- Get all rooms --->
<cffunction name="getRooms" access="remote"  returntype="any" returnformat="JSON">
    <cftry>
        <cfset var retVal = [] />
        <cfset var temp = {} />
        <cfset var result = {} />
        
        <!--- Get rooms with amenities --->
        <cfquery name="qGetRooms" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
            WITH RoomAmenities AS (
                SELECT 
                    ra.ROOM_ID,
                    LISTAGG(ra.AMENITY_ID, ',') WITHIN GROUP (ORDER BY ra.AMENITY_ID) as amenity_list
                FROM #this.DBSCHEMA#.ROOM_AMENITIES ra
                GROUP BY ra.ROOM_ID
            )
            SELECT 
                r.ROOM_ID AS id,
                r.ROOM_NAME AS roomName,
                r.BUILDING AS building,
                r.ROOM_NUMBER AS roomNumber,
                r.CAPACITY AS capacity,
                r.DESCRIPTION AS description,
                r.MAINTENANCE_STATUS AS maintenance,
                r.RECURRING AS recurring,
                r.STATUS AS active_status,
                ra.amenity_list AS amenities,
                CASE 
                    WHEN EXISTS (
                        SELECT 1 FROM #this.DBSCHEMA#.BOOKINGS 
                        WHERE ROOM_ID = r.ROOM_ID 
                        AND current_timestamp BETWEEN start_time AND end_time
                    ) THEN 'Occupied'
                    ELSE 'Available'
                END AS status
            FROM #this.DBSCHEMA#.ROOMS r
            LEFT JOIN RoomAmenities ra ON r.ROOM_ID = ra.ROOM_ID
            ORDER BY r.ROOM_NUMBER
        </cfquery>

        <cfloop query="qGetRooms">
            <cfset temp = {} />
            <cfset temp["id"] = qGetRooms.id />
            <cfset temp["roomName"] = qGetRooms.roomName />
            <cfset temp["building"] = qGetRooms.building />
            <cfset temp["roomNumber"] = qGetRooms.roomNumber />
            <cfset temp["capacity"] = qGetRooms.capacity />
            <cfset temp["description"] = qGetRooms.description />
            <cfset temp["maintenance"] = qGetRooms.maintenance />
            <cfset temp["recurring"] = qGetRooms.recurring />
            <cfset temp["status"] = qGetRooms.status />
            <cfset temp["active_status"] = qGetRooms.active_status />
            
            <!--- Convert amenity list to array --->
            <cfif len(qGetRooms.amenities)>
                <cfset temp["amenities"] = listToArray(qGetRooms.amenities) />
            <cfelse>
                <cfset temp["amenities"] = [] />
            </cfif>
            
            <cfset ArrayAppend(retVal, temp)>
        </cfloop>
        
        <cfset result["rooms"] = retVal />
        <cfreturn result />
        
    <cfcatch type="any">
        <cflog file="roomManagement" text="Error in getRooms: #cfcatch.message#. Details: #cfcatch.detail#">
        <cfthrow message="Error retrieving rooms" detail="#cfcatch.detail#">
    </cfcatch>
    </cftry>
</cffunction>


<cffunction name="toggleActiveStatus" access="remote" returntype="struct" returnformat="JSON">
    <cfargument name="roomId" type="numeric" required="true">
 
        <cfquery name="qToggleActiveStatus" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
            UPDATE #this.DBSCHEMA#.ROOMS
            SET STATUS = CASE WHEN STATUS = 'Active' THEN 'Inactive' ELSE 'Active' END
            WHERE ROOM_ID = <cfqueryparam value="#arguments.roomId#" cfsqltype="cf_sql_numeric">
        </cfquery>
        
        <cfset var result = {} />
        <cfset result["success"] = true />
        <cfset result["message"] = "Active status updated successfully" />
        <cfreturn result>

</cffunction>

<cffunction name="getRoom" access="remote" returntype="struct" returnformat="JSON">
    <cfargument name="roomId" type="numeric" required="true">
    
    <cftry>
        <cfquery name="qGetAmenities" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
        SELECT LISTAGG(a.AMENITY_ID, ', ') WITHIN GROUP (ORDER BY a.AMENITY_NAME) AS amenities
        FROM #this.DBSCHEMA#.ROOM_AMENITIES ra 
        JOIN #this.DBSCHEMA#.AMENITIES a ON a.AMENITY_ID = ra.AMENITY_ID
        WHERE ra.ROOM_ID = <cfqueryparam value="#arguments.roomId#" cfsqltype="cf_sql_numeric">
        </cfquery>

        <cfquery name="qGetRoom" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
        SELECT 
            r.ROOM_ID AS id,
            r.ROOM_NAME AS roomName,
            r.BUILDING AS building,
            r.ROOM_NUMBER AS roomNumber,
            r.CAPACITY AS capacity,
            r.DESCRIPTION AS description,
            r.MAINTENANCE_STATUS AS maintenance,
            r.RECURRING AS recurring,
            r.ROOM_IMAGE AS image,
            CASE 
                WHEN EXISTS (
                    SELECT 1 
                    FROM #this.DBSCHEMA#.BOOKINGS b
                    WHERE b.ROOM_ID = r.ROOM_ID
                    AND CURRENT_TIMESTAMP BETWEEN b.START_TIME AND b.END_TIME
                ) THEN 'Occupied'
                ELSE 'Available'
            END AS status
        FROM #this.DBSCHEMA#.ROOMS r
        WHERE r.ROOM_ID = <cfqueryparam value="#arguments.roomId#" cfsqltype="cf_sql_numeric">
        </cfquery>

        <cfif qGetRoom.recordCount>
            <cfreturn {
                "id": qGetRoom.id,
                "roomName": qGetRoom.roomName,
                "building": qGetRoom.building,
                "roomNumber": qGetRoom.roomNumber,
                "capacity": qGetRoom.capacity,
                "description": qGetRoom.description,
                "maintenance": qGetRoom.maintenance,
                "recurring": qGetRoom.recurring,
                "status": qGetRoom.status,
                "image": qGetRoom.image,
                "amenities": qGetAmenities.amenities,
                "success": true

            }>
        <cfelse>
            <cfthrow message="Room not found" detail="No room found with ID #arguments.roomId#">
        </cfif>
        
    <cfcatch type="any">
        <cflog file="roomManagement" text="Error in getRoom: #cfcatch.message#. Details: #cfcatch.detail#">
        <cfthrow message="Error retrieving room" detail="#cfcatch.detail#">
    </cfcatch>
    </cftry>
</cffunction>

<!--- Update room --->
<cffunction name="updateRoom" access="remote" returntype="struct" returnformat="JSON">
    <cfargument name="id" type="numeric" required="true">
    <cfargument name="roomName" type="string" required="true">
    <cfargument name="building" type="string" required="true">
    <cfargument name="roomNumber" type="string" required="true">
    <cfargument name="capacity" type="numeric" required="true">
    <cfargument name="description" type="string" required="false" default="">
    <cfargument name="recurring" type="string" required="false" default="NO">
    <cfargument name="maintenance" type="string" required="false" default="NO">
    <cfargument name="image" type="string" required="false" default="">

        <cftry>
            <cfquery datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                UPDATE #this.DBSCHEMA#.ROOMS
                SET 
                    ROOM_NAME = <cfqueryparam value="#arguments.roomName#" cfsqltype="cf_sql_varchar">,
                    BUILDING = <cfqueryparam value="#arguments.building#" cfsqltype="cf_sql_varchar">,
                    ROOM_NUMBER = <cfqueryparam value="#arguments.roomNumber#" cfsqltype="cf_sql_varchar">,
                    CAPACITY = <cfqueryparam value="#arguments.capacity#" cfsqltype="cf_sql_numeric">,
                    DESCRIPTION = <cfqueryparam value="#arguments.description#" cfsqltype="cf_sql_varchar">,
                    RECURRING = <cfqueryparam value="#arguments.recurring#" cfsqltype="cf_sql_varchar">,
                    MAINTENANCE_STATUS = <cfqueryparam value="#arguments.maintenance#" cfsqltype="cf_sql_varchar">,
                    ROOM_IMAGE = <cfqueryparam value="#arguments.image#" cfsqltype="cf_sql_clob">
                WHERE ROOM_ID = <cfqueryparam value="#arguments.id#" cfsqltype="cf_sql_numeric">
            </cfquery>

            <cfreturn {
                "success": true,
                "message": "Room updated successfully"
            }>

        <cfcatch type="any">
            <cflog file="roomManagement" text="Error in updateRoom: #cfcatch.message#. Details: #cfcatch.detail#">
            <cfreturn {
                "success": false,
                "message": "Error updating room: #cfcatch.message#"
            }>
        </cfcatch>
        </cftry>
    </cffunction>

   <cffunction name="addRoom" access="remote" returntype="struct" returnformat="JSON">
    <cfargument name="roomName" type="string" required="true">
    <cfargument name="building" type="string" required="true">
    <cfargument name="roomNumber" type="string" required="true">
    <cfargument name="capacity" type="numeric" required="true">
    <cfargument name="description" type="string" required="true">
    <cfargument name="recurring" type="string" required="true" default="NO">
    <cfargument name="maintenance" type="string" required="false" default="NO">
    <cfargument name="image" type="string" required="false" default="">
    
    <cftry>
        <cfquery name="qAddRoom" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#" result="result">
            INSERT INTO #this.DBSCHEMA#.ROOMS (
                ROOM_NAME,
                BUILDING,
                ROOM_NUMBER,
                CAPACITY,
                DESCRIPTION,
                RECURRING,
                MAINTENANCE_STATUS,
                ROOM_IMAGE,
                STATUS
            ) VALUES (
                <cfqueryparam value="#arguments.roomName#" cfsqltype="cf_sql_varchar">,
                <cfqueryparam value="#arguments.building#" cfsqltype="cf_sql_varchar">,
                <cfqueryparam value="#arguments.roomNumber#" cfsqltype="cf_sql_varchar">,
                <cfqueryparam value="#arguments.capacity#" cfsqltype="cf_sql_numeric">,
                <cfqueryparam value="#arguments.description#" cfsqltype="cf_sql_varchar">,
                <cfqueryparam value="#arguments.recurring#" cfsqltype="cf_sql_varchar">,
                <cfqueryparam value="#arguments.maintenance#" cfsqltype="cf_sql_varchar">,
                <cfif len(trim(arguments.image))>
                    <cfqueryparam value="#arguments.image#" cfsqltype="cf_sql_clob">,
                <cfelse>
                    NULL,
                </cfif>
                'Active'
            )
        </cfquery>

        <!--- Get the ID of the newly inserted room --->
        <cfset var newRoomId = "">
        <cfquery name="qGetRoomId" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
            SELECT MAX(ROOM_ID) AS ROOM_ID
            FROM #this.DBSCHEMA#.ROOMS
            WHERE ROOM_NAME = <cfqueryparam value="#arguments.roomName#" cfsqltype="cf_sql_varchar">
            AND BUILDING = <cfqueryparam value="#arguments.building#" cfsqltype="cf_sql_varchar">
            AND ROOM_NUMBER = <cfqueryparam value="#arguments.roomNumber#" cfsqltype="cf_sql_varchar">
        </cfquery>
        
        <cfset newRoomId = qGetRoomId.ROOM_ID>
        
        <cfreturn {
            "success": true,
            "message": "Room added successfully",
            "roomId": newRoomId
        }>
        
        <cfcatch type="any">
            <cflog file="roomManagement" text="Error in addRoom: #cfcatch.message#. Details: #cfcatch.detail#">
            <cfreturn {
                "success": false,
                "message": "Error adding room: #cfcatch.message#"
            }>
        </cfcatch>
    </cftry>
    }>
    <cfreturn result>
</cffunction>


    <cffunction name="deleteRoom" access="remote" returntype="any" returnformat="JSON">
        <cfargument name="roomId" type="numeric" required="true">
        <cfargument name="userId" type="string" required="true" default="sessionStorage.getItem('EMPLID')">

        <cfquery name="qCheckRoom" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
            SELECT COUNT(*) AS COUNT
            FROM #this.DBSCHEMA#.BOOKINGS b
            WHERE b.ROOM_ID = <cfqueryparam value="#arguments.roomId#" cfsqltype="cf_sql_numeric">
            AND b.START_TIME >= CURRENT_TIMESTAMP
        </cfquery>
        
        <cfif qCheckRoom.COUNT GT 0>
            <cfset result = {
                "success": false,
                "message": "Room is occupied starting from today and future dates, please cancel all bookings before setting room to inactive"
            }>
        <cfelse>

            <cfquery name="qDeleteRoomAmenities" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                DELETE FROM #this.DBSCHEMA#.ROOM_AMENITIES
                WHERE ROOM_ID = <cfqueryparam value="#arguments.roomId#" cfsqltype="cf_sql_numeric">
            </cfquery>
            <cfquery name="qDeleteRoom" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                UPDATE #this.DBSCHEMA#.ROOMS SET STATUS = 'Inactive'
                WHERE ROOM_ID = <cfqueryparam value="#arguments.roomId#" cfsqltype="cf_sql_numeric">
            </cfquery>
            
            <cfset result = {
                "success": true,
                "message": "Room deleted successfully"
            }>

        </cfif>

        <cfreturn result>
    </cffunction>

    <cffunction name="updateRoomAmenities" access="remote" returntype="struct" returnformat="JSON">
        <cfargument name="roomId" type="numeric" required="true">
        <cfargument name="amenityIds" type="string" required="true">
        
        <cftry>
            <!--- First, delete existing amenities --->
            <cfquery datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                DELETE FROM #this.DBSCHEMA#.ROOM_AMENITIES
                WHERE ROOM_ID = <cfqueryparam value="#arguments.roomId#" cfsqltype="cf_sql_numeric">
            </cfquery>
            
            <!--- Then insert new amenities if any are selected --->
            <cfif len(trim(arguments.amenityIds))>
                <cfloop list="#arguments.amenityIds#" index="amenityId">
                    <cfquery datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                        INSERT INTO #this.DBSCHEMA#.ROOM_AMENITIES (
                            ROOM_ID,
                            AMENITY_ID
                        ) VALUES (
                            <cfqueryparam value="#arguments.roomId#" cfsqltype="cf_sql_numeric">,
                            <cfqueryparam value="#amenityId#" cfsqltype="cf_sql_numeric">
                        )
                    </cfquery>
                </cfloop>
            </cfif>
            
            <cfreturn {
                "success": true,
                "message": "Room amenities updated successfully"
            }>
            
        <cfcatch type="any">
            <cflog file="roomManagement" text="Error in updateRoomAmenities: #cfcatch.message#. Details: #cfcatch.detail#">
            <cfreturn {
                "success": false,
                "message": "Error updating room amenities: #cfcatch.message#"
            }>
        </cfcatch>
        </cftry>
    </cffunction>
<!--- Toggle room maintenance status --->
<cffunction name="toggleMaintenance" access="remote" returntype="struct" returnformat="JSON">
    <cfargument name="roomId" type="numeric" required="true">
    
    <cftry>
        <!--- Get current maintenance status --->
        <cfquery name="qGetStatus" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
            SELECT MAINTENANCE_STATUS 
            FROM #this.DBSCHEMA#.ROOMS
            WHERE ROOM_ID = <cfqueryparam value="#arguments.roomId#" cfsqltype="cf_sql_numeric">
        </cfquery>
        
        <!--- Toggle the status --->
        <cfset newStatus = qGetStatus.MAINTENANCE_STATUS EQ 'YES' ? 'NO' : 'YES'>
        
        <cfquery datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
            UPDATE #this.DBSCHEMA#.ROOMS
            SET MAINTENANCE_STATUS = <cfqueryparam value="#newStatus#" cfsqltype="cf_sql_varchar">
            WHERE ROOM_ID = <cfqueryparam value="#arguments.roomId#" cfsqltype="cf_sql_numeric">
        </cfquery>
        
        <cfreturn {
            "success": true,
            "message": "Maintenance status updated successfully",
            "newStatus": newStatus
        }>
        
    <cfcatch type="any">
        <cflog file="roomManagement" text="Error in toggleMaintenance: #cfcatch.message#. Details: #cfcatch.detail#">
        <cfreturn {
            "success": false,
            "message": "Error updating maintenance status: #cfcatch.message#"
        }>
    </cfcatch>
    </cftry>
</cffunction>
<!--- Toggle room recurring status --->
<cffunction name="toggleRecurring" access="remote" returntype="struct" returnformat="JSON">
    <cfargument name="roomId" type="numeric" required="true">
    
    <cftry>
        <!--- Get current recurring status --->
        <cfquery name="qGetStatus" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
            SELECT RECURRING 
            FROM #this.DBSCHEMA#.ROOMS
            WHERE ROOM_ID = <cfqueryparam value="#arguments.roomId#" cfsqltype="cf_sql_numeric">
        </cfquery>
        
        <!--- Toggle the status --->
        <cfset newStatus = qGetStatus.RECURRING EQ 'YES' ? 'NO' : 'YES'>
        
        <cfquery datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
            UPDATE #this.DBSCHEMA#.ROOMS
            SET RECURRING = <cfqueryparam value="#newStatus#" cfsqltype="cf_sql_varchar">
            WHERE ROOM_ID = <cfqueryparam value="#arguments.roomId#" cfsqltype="cf_sql_numeric">
        </cfquery>
        
        <cfreturn {
            "success": true,
            "message": "Recurring status updated successfully",
            "newStatus": newStatus
        }>
        
    <cfcatch type="any">
        <cflog file="roomManagement" text="Error in toggleRecurring: #cfcatch.message#. Details: #cfcatch.detail#">
        <cfreturn {
            "success": false,
            "message": "Error updating recurring status: #cfcatch.message#"
        }>
    </cfcatch>
    </cftry>
</cffunction>

    <cffunction name="addRoomAmenities" access="remote" returntype="struct" returnformat="JSON">
        <cfargument name="roomId" type="numeric" required="true">
        <cfargument name="amenityIds" type="string" required="true">
        
        <cftry>
            <cfif len(trim(arguments.amenityIds))>
                <cfloop list="#arguments.amenityIds#" index="amenityId">
                    <cfquery datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                        INSERT INTO #this.DBSCHEMA#.ROOM_AMENITIES (
                            ROOM_ID,
                            AMENITY_ID
                        ) VALUES (
                            <cfqueryparam value="#arguments.roomId#" cfsqltype="cf_sql_numeric">,
                            <cfqueryparam value="#amenityId#" cfsqltype="cf_sql_numeric">
                        )
                    </cfquery>
                </cfloop>
            </cfif>
            
            <cfreturn {
                "success": true,
                "message": "Room amenities added successfully"
            }>
            
        <cfcatch type="any">
            <cflog file="roomManagement" text="Error in addRoomAmenities: #cfcatch.message#. Details: #cfcatch.detail#">
            <cfreturn {
                "success": false,
                "message": "Error adding room amenities: #cfcatch.message#"
            }>
        </cfcatch>
        </cftry>
    </cffunction>

    <cffunction name="removeRoomAmenity" access="remote" returntype="struct" returnformat="JSON">
        <cfargument name="roomId" type="numeric" required="true">
        <cfargument name="amenityId" type="numeric" required="true">
        
        <cftry>
            <cfquery datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                DELETE FROM #this.DBSCHEMA#.ROOM_AMENITIES
                WHERE ROOM_ID = <cfqueryparam value="#arguments.roomId#" cfsqltype="cf_sql_numeric">
                AND AMENITY_ID = <cfqueryparam value="#arguments.amenityId#" cfsqltype="cf_sql_numeric">
            </cfquery>
            
            <cfreturn {
                "success": true,
                "message": "Amenity removed successfully"
            }>
            
        <cfcatch type="any">
            <cflog file="roomManagement" text="Error in removeRoomAmenity: #cfcatch.message#. Details: #cfcatch.detail#">
            <cfreturn {
                "success": false,
                "message": "Error removing amenity: #cfcatch.message#"
            }>
        </cfcatch>
        </cftry>
    </cffunction>
</cfcomponent>
