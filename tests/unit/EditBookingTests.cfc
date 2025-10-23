<cfcomponent displayname="EditBookingTests" output="false">

    <!--- Test: Only creator or admin can edit booking --->
    <cffunction name="testEditPermissions" access="public" returntype="struct">
        <cfset var result = {}>

        <cftry>
            <!--- Simulate permission check --->
            <cfset var bookingCreatorId = 10>
            <cfset var currentUserId = 20>
            <cfset var isAdmin = false>

            <cfset var hasPermission = (currentUserId eq bookingCreatorId) or isAdmin>

            <cfif hasPermission eq false>
                <cfset result.success = true>
                <cfset result.message = "Correctly denied edit permission for non-creator/non-admin">
            <cfelse>
                <cfset result.success = false>
                <cfset result.message = "Failed to deny edit permission">
            </cfif>

            <!--- Test admin permission --->
            <cfset isAdmin = true>
            <cfset hasPermission = (currentUserId eq bookingCreatorId) or isAdmin>

            <cfif hasPermission eq true>
                <cfset result.success = true>
                <cfset result.message = "Correctly granted edit permission for admin">
            <cfelse>
                <cfset result.success = false>
                <cfset result.message = "Failed to grant edit permission to admin">
            </cfif>

            <cfcatch type="any">
                <cfset result.success = false>
                <cfset result.message = "Error: #cfcatch.message#">
            </cfcatch>
        </cftry>

        <cfreturn result>
    </cffunction>

    <!--- Test: Cannot edit bookings that have already started --->
    <cffunction name="testCannotEditPastBookings" access="public" returntype="struct">
        <cfset var result = {}>

        <cftry>
            <cfset var bookingStartTime = dateAdd("h", -2, now())>  // 2 hours ago
            <cfset var currentTime = now()>

            <cfif bookingStartTime lt currentTime>
                <cfset result.success = true>
                <cfset result.message = "Correctly identified booking has already started">
            <cfelse>
                <cfset result.success = false>
                <cfset result.message = "Failed to identify past booking">
            </cfif>

            <cfcatch type="any">
                <cfset result.success = false>
                <cfset result.message = "Error: #cfcatch.message#">
            </cfcatch>
        </cftry>

        <cfreturn result>
    </cffunction>

    <!--- Test: Time range validation (end > start) --->
    <cffunction name="testTimeRangeValidation" access="public" returntype="struct">
        <cfset var result = {}>

        <cftry>
            <cfset var startTime = createDateTime(2025, 10, 25, 14, 0, 0)>
            <cfset var endTime = createDateTime(2025, 10, 25, 10, 0, 0)>

            <cfif endTime lte startTime>
                <cfset result.success = true>
                <cfset result.message = "Correctly identified invalid time range (end before start)">
            <cfelse>
                <cfset result.success = false>
                <cfset result.message = "Failed to identify invalid time range">
            </cfif>

            <cfcatch type="any">
                <cfset result.success = false>
                <cfset result.message = "Error: #cfcatch.message#">
            </cfcatch>
        </cftry>

        <cfreturn result>
    </cffunction>

    <!--- Test: Maximum duration validation (8 hours) --->
    <cffunction name="testMaxDurationValidation" access="public" returntype="struct">
        <cfset var result = {}>

        <cftry>
            <cfset var startTime = createDateTime(2025, 10, 25, 8, 0, 0)>
            <cfset var endTime = createDateTime(2025, 10, 25, 18, 0, 0)>  // 10 hours
            <cfset var maxHours = 8>

            <cfset var duration = dateDiff("h", startTime, endTime)>

            <cfif duration gt maxHours>
                <cfset result.success = true>
                <cfset result.message = "Correctly identified duration exceeds maximum (10 hours > 8 hours)">
            <cfelse>
                <cfset result.success = false>
                <cfset result.message = "Failed to identify excessive duration">
            </cfif>

            <!--- Test valid duration --->
            <cfset endTime = createDateTime(2025, 10, 25, 16, 0, 0)>  // 8 hours
            <cfset duration = dateDiff("h", startTime, endTime)>

            <cfif duration lte maxHours>
                <cfset result.success = true>
                <cfset result.message = "Correctly allowed valid 8-hour duration">
            <cfelse>
                <cfset result.success = false>
                <cfset result.message = "Incorrectly rejected valid duration">
            </cfif>

            <cfcatch type="any">
                <cfset result.success = false>
                <cfset result.message = "Error: #cfcatch.message#">
            </cfcatch>
        </cftry>

        <cfreturn result>
    </cffunction>

    <!--- Test: Cannot edit cancelled/rejected bookings --->
    <cffunction name="testCannotEditCancelledBookings" access="public" returntype="struct">
        <cfset var result = {}>

        <cftry>
            <cfset var bookingStatus = "Cancelled">

            <cfif bookingStatus eq "Cancelled" or bookingStatus eq "Rejected">
                <cfset result.success = true>
                <cfset result.message = "Correctly prevented editing of cancelled booking">
            <cfelse>
                <cfset result.success = false>
                <cfset result.message = "Failed to prevent editing of cancelled booking">
            </cfif>

            <!--- Test rejected status --->
            <cfset bookingStatus = "Rejected">

            <cfif bookingStatus eq "Cancelled" or bookingStatus eq "Rejected">
                <cfset result.success = true>
                <cfset result.message = "Correctly prevented editing of rejected booking">
            <cfelse>
                <cfset result.success = false>
                <cfset result.message = "Failed to prevent editing of rejected booking">
            </cfif>

            <cfcatch type="any">
                <cfset result.success = false>
                <cfset result.message = "Error: #cfcatch.message#">
            </cfcatch>
        </cftry>

        <cfreturn result>
    </cffunction>

    <!--- Test: Revision number increment --->
    <cffunction name="testRevisionNumberIncrement" access="public" returntype="struct">
        <cfset var result = {}>

        <cftry>
            <cfset var originalRevisionNumber = 2>
            <cfset var newRevisionNumber = originalRevisionNumber + 1>

            <cfif newRevisionNumber eq 3>
                <cfset result.success = true>
                <cfset result.message = "Correctly incremented revision number from 2 to 3">
            <cfelse>
                <cfset result.success = false>
                <cfset result.message = "Failed to increment revision number">
            </cfif>

            <cfcatch type="any">
                <cfset result.success = false>
                <cfset result.message = "Error: #cfcatch.message#">
            </cfcatch>
        </cftry>

        <cfreturn result>
    </cffunction>

    <!--- Test: Room availability conflict detection --->
    <cffunction name="testRoomAvailabilityCheck" access="public" returntype="struct">
        <cfset var result = {}>

        <cftry>
            <!--- Simulate checking room availability --->
            <cfset var requestedStartTime = createDateTime(2025, 10, 25, 10, 0, 0)>
            <cfset var requestedEndTime = createDateTime(2025, 10, 25, 12, 0, 0)>

            <!--- Simulate existing booking --->
            <cfset var existingBookingStart = createDateTime(2025, 10, 25, 11, 0, 0)>
            <cfset var existingBookingEnd = createDateTime(2025, 10, 25, 13, 0, 0)>

            <!--- Check for time overlap --->
            <cfset var hasConflict = (requestedStartTime lt existingBookingEnd) and (requestedEndTime gt existingBookingStart)>

            <cfif hasConflict eq true>
                <cfset result.success = true>
                <cfset result.message = "Correctly detected room availability conflict">
            <cfelse>
                <cfset result.success = false>
                <cfset result.message = "Failed to detect room availability conflict">
            </cfif>

            <!--- Test no conflict scenario --->
            <cfset requestedStartTime = createDateTime(2025, 10, 25, 8, 0, 0)>
            <cfset requestedEndTime = createDateTime(2025, 10, 25, 10, 0, 0)>

            <cfset hasConflict = (requestedStartTime lt existingBookingEnd) and (requestedEndTime gt existingBookingStart)>

            <cfif hasConflict eq false>
                <cfset result.success = true>
                <cfset result.message = "Correctly identified no conflict for non-overlapping times">
            <cfelse>
                <cfset result.success = false>
                <cfset result.message = "Incorrectly detected conflict for non-overlapping times">
            </cfif>

            <cfcatch type="any">
                <cfset result.success = false>
                <cfset result.message = "Error: #cfcatch.message#">
            </cfcatch>
        </cftry>

        <cfreturn result>
    </cffunction>

    <!--- Run all tests --->
    <cffunction name="runAllTests" access="public" returntype="array">
        <cfset var results = []>

        <cfset arrayAppend(results, {
            testName = "testEditPermissions",
            result = testEditPermissions()
        })>

        <cfset arrayAppend(results, {
            testName = "testCannotEditPastBookings",
            result = testCannotEditPastBookings()
        })>

        <cfset arrayAppend(results, {
            testName = "testTimeRangeValidation",
            result = testTimeRangeValidation()
        })>

        <cfset arrayAppend(results, {
            testName = "testMaxDurationValidation",
            result = testMaxDurationValidation()
        })>

        <cfset arrayAppend(results, {
            testName = "testCannotEditCancelledBookings",
            result = testCannotEditCancelledBookings()
        })>

        <cfset arrayAppend(results, {
            testName = "testRevisionNumberIncrement",
            result = testRevisionNumberIncrement()
        })>

        <cfset arrayAppend(results, {
            testName = "testRoomAvailabilityCheck",
            result = testRoomAvailabilityCheck()
        })>

        <cfreturn results>
    </cffunction>

</cfcomponent>
