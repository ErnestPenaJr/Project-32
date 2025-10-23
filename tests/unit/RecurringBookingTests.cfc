<cfcomponent displayname="RecurringBookingTests" output="false">

    <!--- Test: Daily recurring pattern generation --->
    <cffunction name="testDailyRecurringPattern" access="public" returntype="struct">
        <cfset var result = {}>
        <cfset var recurringBooking = createObject("component", "components.RecurringBooking")>

        <cfset var testPattern = {
            frequency = "DAILY",
            intervalCount = 1,
            endType = "occurrences",
            maxOccurrences = 5,
            endDate = "",
            daysOfWeek = ""
        }>

        <cfset var startDate = createDateTime(2025, 10, 20, 9, 0, 0)>

        <cftry>
            <cfset var dates = recurringBooking.generateRecurringDates(startDate, testPattern)>

            <!--- Assert we got 5 dates --->
            <cfif arrayLen(dates) eq 5>
                <cfset result.success = true>
                <cfset result.message = "Daily pattern generated 5 occurrences correctly">
            <cfelse>
                <cfset result.success = false>
                <cfset result.message = "Expected 5 occurrences, got #arrayLen(dates)#">
            </cfif>

            <!--- Assert dates are consecutive --->
            <cfloop from="2" to="#arrayLen(dates)#" index="i">
                <cfset var dayDiff = dateDiff("d", dates[i-1], dates[i])>
                <cfif dayDiff neq 1>
                    <cfset result.success = false>
                    <cfset result.message = "Dates are not consecutive. Day difference: #dayDiff#">
                    <cfbreak>
                </cfif>
            </cfloop>

            <cfcatch type="any">
                <cfset result.success = false>
                <cfset result.message = "Error: #cfcatch.message#">
            </cfcatch>
        </cftry>

        <cfreturn result>
    </cffunction>

    <!--- Test: Weekly recurring pattern with specific days --->
    <cffunction name="testWeeklyRecurringPattern" access="public" returntype="struct">
        <cfset var result = {}>
        <cfset var recurringBooking = createObject("component", "components.RecurringBooking")>

        <cfset var testPattern = {
            frequency = "WEEKLY",
            intervalCount = 1,
            endType = "occurrences",
            maxOccurrences = 4,
            endDate = "",
            daysOfWeek = "1,3,5"  // Monday, Wednesday, Friday
        }>

        <cfset var startDate = createDateTime(2025, 10, 20, 9, 0, 0)>  // Monday

        <cftry>
            <cfset var dates = recurringBooking.generateRecurringDates(startDate, testPattern)>

            <!--- Assert we got 4 dates --->
            <cfif arrayLen(dates) eq 4>
                <cfset result.success = true>
                <cfset result.message = "Weekly pattern generated 4 occurrences correctly">
            <cfelse>
                <cfset result.success = false>
                <cfset result.message = "Expected 4 occurrences, got #arrayLen(dates)#">
            </cfif>

            <!--- Verify all dates are Mon/Wed/Fri --->
            <cfloop array="#dates#" index="date">
                <cfset var dow = dayOfWeek(date)>
                <cfif not listFind("2,4,6", dow)>  // 2=Mon, 4=Wed, 6=Fri (CF uses 1=Sunday)
                    <cfset result.success = false>
                    <cfset result.message = "Found date on wrong day of week: #dayOfWeekAsString(dow)#">
                    <cfbreak>
                </cfif>
            </cfloop>

            <cfcatch type="any">
                <cfset result.success = false>
                <cfset result.message = "Error: #cfcatch.message#">
            </cfcatch>
        </cftry>

        <cfreturn result>
    </cffunction>

    <!--- Test: Monthly recurring pattern --->
    <cffunction name="testMonthlyRecurringPattern" access="public" returntype="struct">
        <cfset var result = {}>
        <cfset var recurringBooking = createObject("component", "components.RecurringBooking")>

        <cfset var testPattern = {
            frequency = "MONTHLY",
            intervalCount = 1,
            endType = "occurrences",
            maxOccurrences = 3,
            endDate = "",
            daysOfWeek = ""
        }>

        <cfset var startDate = createDateTime(2025, 10, 15, 9, 0, 0)>

        <cftry>
            <cfset var dates = recurringBooking.generateRecurringDates(startDate, testPattern)>

            <!--- Assert we got 3 dates --->
            <cfif arrayLen(dates) eq 3>
                <cfset result.success = true>
                <cfset result.message = "Monthly pattern generated 3 occurrences correctly">
            <cfelse>
                <cfset result.success = false>
                <cfset result.message = "Expected 3 occurrences, got #arrayLen(dates)#">
            </cfif>

            <!--- Verify month differences --->
            <cfloop from="2" to="#arrayLen(dates)#" index="i">
                <cfset var monthDiff = dateDiff("m", dates[i-1], dates[i])>
                <cfif monthDiff neq 1>
                    <cfset result.success = false>
                    <cfset result.message = "Months are not consecutive. Month difference: #monthDiff#">
                    <cfbreak>
                </cfif>
            </cfloop>

            <cfcatch type="any">
                <cfset result.success = false>
                <cfset result.message = "Error: #cfcatch.message#">
            </cfcatch>
        </cftry>

        <cfreturn result>
    </cffunction>

    <!--- Test: Pattern validation - max occurrences limit --->
    <cffunction name="testMaxOccurrencesLimit" access="public" returntype="struct">
        <cfset var result = {}>
        <cfset var recurringBooking = createObject("component", "components.RecurringBooking")>

        <cfset var testPattern = {
            frequency = "DAILY",
            intervalCount = 1,
            endType = "occurrences",
            maxOccurrences = 100,  // Over the limit of 52
            endDate = "",
            daysOfWeek = ""
        }>

        <cftry>
            <cfset var validationResult = recurringBooking.validateRecurringPattern(testPattern)>

            <cfif validationResult.valid eq false>
                <cfset result.success = true>
                <cfset result.message = "Correctly rejected pattern exceeding max occurrences">
            <cfelse>
                <cfset result.success = false>
                <cfset result.message = "Failed to reject pattern exceeding max occurrences">
            </cfif>

            <cfcatch type="any">
                <cfset result.success = false>
                <cfset result.message = "Error: #cfcatch.message#">
            </cfcatch>
        </cftry>

        <cfreturn result>
    </cffunction>

    <!--- Test: Pattern validation - end date beyond limit --->
    <cffunction name="testEndDateLimit" access="public" returntype="struct">
        <cfset var result = {}>
        <cfset var recurringBooking = createObject("component", "components.RecurringBooking")>

        <cfset var futureDate = dateAdd("m", 7, now())>  // 7 months from now (limit is 6)

        <cfset var testPattern = {
            frequency = "WEEKLY",
            intervalCount = 1,
            endType = "date",
            maxOccurrences = 0,
            endDate = dateFormat(futureDate, "yyyy-mm-dd"),
            daysOfWeek = "1,2,3,4,5"
        }>

        <cftry>
            <cfset var validationResult = recurringBooking.validateRecurringPattern(testPattern)>

            <cfif validationResult.valid eq false>
                <cfset result.success = true>
                <cfset result.message = "Correctly rejected pattern with end date beyond limit">
            <cfelse>
                <cfset result.success = false>
                <cfset result.message = "Failed to reject pattern with end date beyond limit">
            </cfif>

            <cfcatch type="any">
                <cfset result.success = false>
                <cfset result.message = "Error: #cfcatch.message#">
            </cfcatch>
        </cftry>

        <cfreturn result>
    </cffunction>

    <!--- Test: Conflict detection across recurring dates --->
    <cffunction name="testConflictDetection" access="public" returntype="struct">
        <cfset var result = {}>
        <cfset var recurringBooking = createObject("component", "components.RecurringBooking")>

        <cfset var roomId = 1>
        <cfset var testDates = []>

        <!--- Create test dates --->
        <cfset arrayAppend(testDates, createDateTime(2025, 10, 20, 9, 0, 0))>
        <cfset arrayAppend(testDates, createDateTime(2025, 10, 21, 9, 0, 0))>
        <cfset arrayAppend(testDates, createDateTime(2025, 10, 22, 9, 0, 0))>

        <cftry>
            <cfset var conflicts = recurringBooking.checkRecurringConflicts(roomId, testDates)>

            <!--- Should return a struct with conflicts information --->
            <cfif isStruct(conflicts)>
                <cfset result.success = true>
                <cfset result.message = "Conflict detection returned valid response structure">
                <cfset result.data = conflicts>
            <cfelse>
                <cfset result.success = false>
                <cfset result.message = "Conflict detection did not return expected structure">
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
            testName = "testDailyRecurringPattern",
            result = testDailyRecurringPattern()
        })>

        <cfset arrayAppend(results, {
            testName = "testWeeklyRecurringPattern",
            result = testWeeklyRecurringPattern()
        })>

        <cfset arrayAppend(results, {
            testName = "testMonthlyRecurringPattern",
            result = testMonthlyRecurringPattern()
        })>

        <cfset arrayAppend(results, {
            testName = "testMaxOccurrencesLimit",
            result = testMaxOccurrencesLimit()
        })>

        <cfset arrayAppend(results, {
            testName = "testEndDateLimit",
            result = testEndDateLimit()
        })>

        <cfset arrayAppend(results, {
            testName = "testConflictDetection",
            result = testConflictDetection()
        })>

        <cfreturn results>
    </cffunction>

</cfcomponent>
