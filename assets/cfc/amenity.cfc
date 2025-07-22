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

    <cfset variables.logger = createObject("component", "system-logger")>

    <cffunction name="getAllAmenities" access="remote" returntype="any" returnformat="JSON">
        <cfset var retVal = [] />
        <cfset var temp = {} />
        <cfset var result = {} />
        
        <cftry>
            <cfquery name="qGetAmenities" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT 
                    AMENITY_ID as id,
                    AMENITY_NAME as name,
                    DESCRIPTION as description,
                    ICON as icon
                FROM #this.DBSCHEMA#.AMENITIES
                ORDER BY AMENITY_NAME
            </cfquery>

            <cfloop query="qGetAmenities">
                <cfset temp = {
                    "id": qGetAmenities.id,
                    "name": qGetAmenities.name,
                    "description": qGetAmenities.description,
                    "icon": qGetAmenities.icon
                } />
                <cfset arrayAppend(retVal, temp) />
            </cfloop>

            <cfset result.success = true />
            <cfset result.data = retVal />
            <cfreturn result />

        <cfcatch type="any">
            <cflog file="amenityManagement" text="Error in getAllAmenities: #cfcatch.message#. Details: #cfcatch.detail#">
            <cfset result.success = false />
            <cfset result.message = cfcatch.message />
            <cfreturn result />
        </cfcatch>
        </cftry>
    </cffunction>

    <cffunction name="updateAmenity" access="remote" returntype="boolean" returnformat="JSON">
        <cfargument name="amenityId" type="numeric" required="true">
        <cfargument name="amenityName" type="string" required="true">
        <cfargument name="description" type="string" required="true">
        <cfargument name="icon" type="string" required="true">
        <cfargument name="userId" type="numeric" required="false" default="0">

        <cftry>
            <cfquery datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                UPDATE #this.DBSCHEMA#.AMENITIES
                SET 
                    AMENITY_NAME = <cfqueryparam value="#arguments.amenityName#" cfsqltype="cf_sql_varchar">,
                    DESCRIPTION = <cfqueryparam value="#arguments.description#" cfsqltype="cf_sql_varchar">,
                    ICON = <cfqueryparam value="#arguments.icon#" cfsqltype="cf_sql_varchar">
                WHERE AMENITY_ID = <cfqueryparam value="#arguments.amenityId#" cfsqltype="cf_sql_numeric">
            </cfquery>

            <!--- Log the change --->
            <cfset variables.logger.logDatabaseChange(
                actionType="UPDATE",
                tableName="AMENITIES",
                recordId=arguments.amenityId,
                userId=val(arguments.userId),
                changeDetails=serializeJSON(arguments)
            )>

            <cfreturn true>
            
            <cfcatch type="any">
                <cflog file="amenityManagement" text="Error in updateAmenity: #cfcatch.message#. Details: #cfcatch.detail#">
                <cfthrow message="Failed to update amenity" detail="#cfcatch.message#">
            </cfcatch>
        </cftry>
    </cffunction>

    <cffunction name="getAmenityIcons" access="remote" returntype="array" returnformat="JSON">
        <cfset var retVal = [] />
        
        <cfquery name="qAmenitiesIcons" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
            SELECT DISTINCT ICON, AMENITY_NAME
            FROM #this.DBSCHEMA#.AMENITIES
            ORDER BY AMENITY_NAME
        </cfquery>

        <cfloop query="qAmenitiesIcons">
            <cfset var temp = {
                "ICON": qAmenitiesIcons.ICON,
                "NAME": qAmenitiesIcons.AMENITY_NAME
            } />
            <cfset arrayAppend(retVal, temp) />
        </cfloop>

        <cfreturn retVal />
    </cffunction>

    <cffunction name="getAmenity" access="remote" returntype="any" returnformat="JSON">
        <cfargument name="amenityId" type="numeric" required="true">
        
        <cftry>
            <cfquery name="qAmenity" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT 
                    AMENITY_ID,
                    AMENITY_NAME,
                    DESCRIPTION,
                    ICON
                FROM #this.DBSCHEMA#.AMENITIES
                WHERE AMENITY_ID = <cfqueryparam value="#arguments.amenityId#" cfsqltype="cf_sql_numeric">
            </cfquery>

            <cfif qAmenity.recordCount GT 0>
                <cfset var result = {
                    "id": qAmenity.AMENITY_ID,
                    "name": qAmenity.AMENITY_NAME,
                    "description": qAmenity.DESCRIPTION,
                    "icon": qAmenity.ICON
                } />
                <cfreturn result />
            <cfelse>
                <cfthrow message="Amenity not found" detail="No amenity found with ID #arguments.amenityId#">
            </cfif>

        <cfcatch type="any">
            <cflog file="amenityManagement" text="Error in getAmenity: #cfcatch.message#. Details: #cfcatch.detail#">
            <cfthrow message="Error retrieving amenity details" detail="#cfcatch.detail#">
        </cfcatch>
        </cftry>
    </cffunction>

    <cffunction name="getRoomAmenities" access="remote" returntype="any" returnformat="JSON">
        <cfargument name="roomId" type="numeric" required="true">
        <cftry>
            <cfset var retVal = [] />
            <cfset var temp = {} />
            <cfset var result = {} />
            <cfquery name="qRoomAmenities" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
               SELECT a.AMENITY_ID, a.AMENITY_NAME, a.DESCRIPTION, a.ICON
                FROM #this.DBSCHEMA#.AMENITIES a
                INNER JOIN #this.DBSCHEMA#.ROOM_AMENITIES ra ON a.AMENITY_ID = ra.AMENITY_ID
                WHERE ra.ROOM_ID = <cfqueryparam value="#arguments.roomId#" cfsqltype="cf_sql_numeric">
                ORDER BY a.AMENITY_NAME
            </cfquery>

            <cfloop query="qRoomAmenities">
                <cfset temp = {} />
                <cfset temp["id"] = qRoomAmenities.AMENITY_ID />
                <cfset temp["name"] = qRoomAmenities.AMENITY_NAME />
                <cfset temp["description"] = qRoomAmenities.DESCRIPTION />
                <cfset temp["icon"] = qRoomAmenities.ICON />
                <cfset ArrayAppend(retVal, temp) />
            </cfloop>

            <cfset result = retVal />
            <cfreturn retVal />

            <cfcatch type="any">
                <cflog file="amenityManagement" text="Error in getRoomAmenities: #cfcatch.message#. Details: #cfcatch.detail#">
                <cfthrow message="Error retrieving room amenities" detail="#cfcatch.detail#">
            </cfcatch>
        </cftry>
    </cffunction>

<cffunction name="updateRoomAmenities" access="remote" returntype="struct" returnformat="JSON">
    <cfargument name="roomId" type="numeric" required="true">
    <cfargument name="amenityId" type="numeric" required="true">

    <cftry>
        <cfquery datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#" name="qRmCheck">
            SELECT AMENITY_ID 
            FROM #this.DBSCHEMA#.ROOM_AMENITIES
            WHERE ROOM_ID = <cfqueryparam value="#arguments.roomId#" cfsqltype="cf_sql_numeric">
            AND AMENITY_ID = <cfqueryparam value="#arguments.amenityId#" cfsqltype="cf_sql_numeric">
        </cfquery>

        <cfif qRmCheck.recordcount GTE 1>

            <cfquery datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#" name="deleteAmenities">
                DELETE FROM #this.DBSCHEMA#.ROOM_AMENITIES
                WHERE ROOM_ID = <cfqueryparam value="#arguments.roomId#" cfsqltype="cf_sql_numeric">
                AND AMENITY_ID = <cfqueryparam value="#arguments.amenityId#" cfsqltype="cf_sql_numeric">
            </cfquery>

            <cfquery datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#" name="insertAmenity">
                INSERT INTO #this.DBSCHEMA#.ROOM_AMENITIES (ROOM_ID, AMENITY_ID)
                VALUES (
                    <cfqueryparam value="#arguments.roomId#" cfsqltype="cf_sql_numeric">,
                    <cfqueryparam value="#arguments.amenityId#" cfsqltype="cf_sql_numeric">
                )
            </cfquery>
            
        <cfelse>
            <cfquery datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#" name="insertAmenityIfNone">
                INSERT INTO #this.DBSCHEMA#.ROOM_AMENITIES (ROOM_ID, AMENITY_ID)
                VALUES (
                    <cfqueryparam value="#arguments.roomId#" cfsqltype="cf_sql_numeric">,
                    <cfqueryparam value="#arguments.amenityId#" cfsqltype="cf_sql_numeric">
                )
            </cfquery>
        </cfif>

        <cfset result = {
            "success": true,
            "roomId": arguments.roomId,
            "amenityId": arguments.amenityId
        } />

        <cfreturn result>

    <cfcatch>
        <cfset errorMessage = {
            "success": false,
            "error": {
                "message": cfcatch.message,
                "detail": cfcatch.detail,
                "type": cfcatch.type,
                "queryError": cfcatch.queryError
            }
        } />

        <cflog file="room_amenities_error" text="Error updating room amenities: #serializeJSON(errorMessage)#" type="error">

        <cfreturn errorMessage>
    </cfcatch>
    </cftry>
</cffunction>


    <cffunction name="addDefaultAmenities" access="remote" returntype="boolean" returnformat="JSON">
        <cftry>
            <!--- Check if we have any amenities --->
            <cfquery name="checkAmenities" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT COUNT(*) as CNT FROM #this.DBSCHEMA#.AMENITIES
            </cfquery>
            
            <cfif checkAmenities.CNT EQ 0>
                <!--- Add default amenities with icons --->
                <cfquery datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                    ALTER TABLE #this.DBSCHEMA#.AMENITIES ADD ICON VARCHAR(50)
                </cfquery>
                
                <cfquery datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                    INSERT INTO #this.DBSCHEMA#.AMENITIES (AMENITY_ID, AMENITY_NAME, DESCRIPTION, ICON)
                    SELECT #this.DBSCHEMA#.AMENITIES_SEQ.NEXTVAL, A.* FROM (
                        SELECT 'Projector' as NAME, 'Digital projector for presentations' as DESC, 'fas fa-projector' as ICON FROM DUAL UNION ALL
                        SELECT 'Whiteboard', 'Wall-mounted whiteboard', 'fas fa-chalkboard' FROM DUAL UNION ALL
                        SELECT 'Video Conference', 'Video conferencing equipment', 'fas fa-video' FROM DUAL UNION ALL
                        SELECT 'TV Screen', 'Large TV display', 'fas fa-tv' FROM DUAL
                    ) A
                </cfquery>
                <cfreturn true>
            </cfif>
            
            <cfreturn false>
            
            <cfcatch type="any">
                <cflog file="amenityManagement" text="Error in addDefaultAmenities: #cfcatch.message#. Details: #cfcatch.detail#">
                <cfthrow message="Error adding default amenities" detail="#cfcatch.detail#">
            </cfcatch>
        </cftry>
    </cffunction>

    <cffunction name="addAmenity" access="remote" returntype="numeric" returnformat="JSON">
        <cfargument name="amenityName" type="string" required="true">
        <cfargument name="description" type="string" required="true">
        <cfargument name="icon" type="string" required="true">
        <cfargument name="userId" type="string" required="false" default="sessionStorage.getItem('EMPLID')">
        
        <cftry>

            <!--- Insert new amenity --->
            <cfquery datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                INSERT INTO #this.DBSCHEMA#.AMENITIES (
                    AMENITY_NAME,
                    DESCRIPTION,
                    ICON
                )
                VALUES (
                    <cfqueryparam value="#arguments.amenityName#" cfsqltype="cf_sql_varchar">,
                    <cfqueryparam value="#arguments.description#" cfsqltype="cf_sql_varchar">,
                    <cfqueryparam value="#arguments.icon#" cfsqltype="cf_sql_varchar">
                )
            </cfquery>

            <!---Get the new amenity ID --->
            <cfquery name="getNextId" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT MAX(AMENITY_ID) AS NEXT_ID FROM #this.DBSCHEMA#.AMENITIES
            </cfquery>
            
            <cfreturn getNextId.NEXT_ID>

        <cfcatch type="any">
            <cflog file="amenityManagement" text="Error in addAmenity: #cfcatch.message#. Details: #cfcatch.detail#">
            <cfthrow message="Error adding amenity: #cfcatch.message#" detail="#cfcatch.detail#">
        </cfcatch>
        </cftry>
    </cffunction>

    <cffunction name="removeAmenity" access="remote" returntype="struct" returnformat="JSON">
        <cfargument name="roomId" type="numeric" required="true">
        <cfargument name="amenityId" type="numeric" required="true">
        
        <cftry>
        <cfquery datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#" name="qRmCheck">
            SELECT AMENITY_ID 
            FROM #this.DBSCHEMA#.ROOM_AMENITIES
            WHERE ROOM_ID = <cfqueryparam value="#arguments.roomId#" cfsqltype="cf_sql_numeric">
            AND AMENITY_ID = <cfqueryparam value="#arguments.amenityId#" cfsqltype="cf_sql_numeric">
        </cfquery>

        <cfif qRmCheck.recordcount NEQ 0>
            <cfquery datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                DELETE FROM #this.DBSCHEMA#.ROOM_AMENITIES
                WHERE ROOM_ID = <cfqueryparam value="#arguments.roomId#" cfsqltype="cf_sql_numeric">
                AND AMENITY_ID = <cfqueryparam value="#arguments.amenityId#" cfsqltype="cf_sql_numeric">
            </cfquery>

            <cfset result = {
                "success": true,
                "roomId": arguments.roomId,
                "amenityId": arguments.amenityId
            } />
        <cfelse>
            <cfset result = {
                "success": false,
                "message": "Amenity not found in room"
            } />
        </cfif>

            <cfreturn result>
        <cfcatch type="any">
            <cflog file="amenityManagement" text="Error in deleteAmenity: #cfcatch.message#. Details: #cfcatch.detail#">
            <cfthrow message="Error deleting amenity: #cfcatch.message#" detail="#cfcatch.detail#">
        </cfcatch>
        </cftry>
    </cffunction>

    <cffunction name="deleteAmenity" access="remote" returntype="struct" returnformat="JSON">
        <cfargument name="amenityId" type="numeric" required="true">

        <cfquery datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#" name="qRmCheck">
            SELECT AMENITY_ID 
            FROM #this.DBSCHEMA#.AMENITIES
            WHERE AMENITY_ID = <cfqueryparam value="#arguments.amenityId#" cfsqltype="cf_sql_numeric">
        </cfquery>

        <cfif qRmCheck.recordcount NEQ 0>
            <cfquery datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                DELETE FROM #this.DBSCHEMA#.ROOM_AMENITIES
                WHERE AMENITY_ID = <cfqueryparam value="#arguments.amenityId#" cfsqltype="cf_sql_numeric">
            </cfquery>
            <cfquery datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                DELETE FROM #this.DBSCHEMA#.AMENITIES
                WHERE AMENITY_ID = <cfqueryparam value="#arguments.amenityId#" cfsqltype="cf_sql_numeric">
            </cfquery>

  

            <cfset result = {
                "success": true,
                "amenityId": arguments.amenityId,
                "message": "Amenity deleted successfully, and removed from all rooms"
            } />
        <cfelse>
            <cfset result = {
                "success": false,
                "message": "Amenity not found"
            } />
        </cfif>

            <cfreturn result>
  
    </cffunction>

    <cffunction name="removeRoomAmenities" access="remote" returntype="struct" returnformat="JSON">
        <cfargument name="roomId" type="numeric" required="true">
            <cfquery datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                DELETE FROM #this.DBSCHEMA#.ROOM_AMENITIES
                WHERE ROOM_ID = <cfqueryparam value="#arguments.roomId#" cfsqltype="cf_sql_numeric">
            </cfquery>
            <cfreturn {
                "success": true,
                "roomId": arguments.roomId
            } />
    </cffunction>
</cfcomponent>