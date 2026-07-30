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

    <!--- Get pending bookings for admin --->
    <cffunction name="getPendingBookings" access="remote" returntype="struct" returnformat="json">
        <cfargument name="date" type="string" required="false" default="">
        <cfargument name="status" type="string" required="false" default="">
        <cfargument name="search" type="string" required="false" default="">
        
        
        <cftry>
            <cfquery name="qGetPending" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT
                    b.BOOKING_ID as ID,
                    u.FIRST_NAME || ' ' || u.LAST_NAME as USER_NAME,
                    b.COMMENTS as MEETING_TITLE,
                    r.ROOM_NAME,
                    r.BUILDING as BUILDING,
                    r.ROOM_NUMBER as ROOM_NUMBER,
                    TO_NUMBER(r.CAPACITY) as CAPACITY,
                    TO_CHAR(b.START_TIME, 'YYYY-MM-DD') as BOOKING_DATE,
                    TO_CHAR(b.START_TIME, 'HH12:MI AM') as START_TIME,
                    TO_CHAR(b.END_TIME, 'HH12:MI AM') as END_TIME,
                    TO_CHAR(b.START_TIME, 'MM/DD/YYYY HH12:MI AM')as START_DATE,
                    TO_CHAR(b.END_TIME, 'MM/DD/YYYY HH12:MI AM') as END_DATE,
                    b.STATUS as STATUSx
                FROM #this.DBSCHEMA#.BOOKINGS b
                JOIN #this.DBSCHEMA#.USERS u ON b.USER_ID = u.USER_ID
                JOIN #this.DBSCHEMA#.ROOMS r ON b.ROOM_ID = r.ROOM_ID
                WHERE LOWER(b.STATUS) = 'pending'
                <cfif arguments.date IS NOT "" AND arguments.date IS NOT "null">
                    AND TO_CHAR(b.START_TIME, 'YYYY-MM-DD') = <cfqueryparam value="#arguments.date#" cfsqltype="cf_sql_varchar">
                <cfelse>
                    AND b.START_TIME >= TRUNC(SYSDATE)
                </cfif>
                
                <cfif arguments.status IS NOT "" AND arguments.status IS NOT "null">
                    AND b.STATUS = <cfqueryparam value="#arguments.status#" cfsqltype="cf_sql_varchar">
                </cfif>
                
                <cfif arguments.search IS NOT "" AND arguments.search IS NOT "null">
                    AND (
                        LOWER(u.FIRST_NAME || ' ' || u.LAST_NAME) LIKE <cfqueryparam value="%#LCase(arguments.search)#%" cfsqltype="cf_sql_varchar">
                        OR LOWER(r.ROOM_NAME) LIKE <cfqueryparam value="%#LCase(arguments.search)#%" cfsqltype="cf_sql_varchar">
                    )
                </cfif>
                ORDER BY b.START_TIME DESC
            </cfquery>
            
            <cfset var result = {
                "SUCCESS" = true,
                "DATA" = []
            }>
            
            <cfloop query="qGetPending">
                <cfset arrayAppend(result.DATA, {
                    "ID" = ID,
                    "USER_NAME" = USER_NAME,
                    "MEETING_TITLE" = MEETING_TITLE,
                    "ROOM_NAME" = ROOM_NAME,
                    "LOCATION" = "#BUILDING#-#ROOM_NUMBER#",
                    "CAPACITY" = CAPACITY,
                    "BOOKING_DATE" = BOOKING_DATE,
                    "TIME" = "#START_TIME# - #END_TIME#",
                    "START_DATE" = START_DATE,
                    "END_DATE" = END_DATE,
                    "STATUS" = STATUSx
                })>
            </cfloop>
            
            <cfreturn result>
            
            <cfcatch>
                <cflog type="error"  file="#GetDirectoryFromPath(GetCurrentTemplatePath())#assets/logs/error.log" text="Error in getPendingBookings: #cfcatch.message# #cfcatch.detail#">
                <cfreturn {
                    "SUCCESS" = false,
                    "MESSAGE" = "Error retrieving bookings: " & cfcatch.message
                }>
            </cfcatch>
        </cftry>
    </cffunction>

    <!--- Get booking details --->
    <cffunction name="getBookingDetails" access="remote" returntype="struct" returnformat="json">
        <cfargument name="bookingId" type="numeric" required="true">
        
        <cftry>
            <cfquery name="qryDetails" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT
                    b.BOOKING_ID,
                    u.FIRST_NAME || ' ' || u.LAST_NAME AS FULL_NAME,
                    b.COMMENTS AS MEETING_TITLE,
                    r.ROOM_NAME,
                    TO_CHAR(b.CREATED_AT, 'FMDay, FMMonth DD, YYYY') as DATEBOOKED,
                    TO_CHAR(b.START_TIME, 'HH12:MI AM') || ' - ' || TO_CHAR(b.END_TIME, 'HH12:MI AM') as TIME,
                    TO_CHAR(b.START_TIME, 'MM/DD/YYYY HH24:MI AM') as START_DATE,
                    TO_CHAR(b.END_TIME, 'MM/DD/YYYY HH24:MI AM') as END_DATE,
                    b.STATUS,
                    b.RECURRING_DETAILS,
                    b.BOOKED_FOR_NAME,
                    b.BOOKED_FOR_EMAIL,
                    b.BOOKED_FOR_DEPARTMENT,
                    b.CANCELLATION_REASON,
                    r.CAPACITY,
                    r.BUILDING,
                    r.ROOM_NUMBER,
                    r.ROOM_IMAGE,
                    r.DESCRIPTION as NOTES,
                    u.EMAIL
                FROM #this.DBSCHEMA#.BOOKINGS b
                JOIN #this.DBSCHEMA#.USERS u ON b.USER_ID = u.USER_ID
                JOIN #this.DBSCHEMA#.ROOMS r ON b.ROOM_ID = r.ROOM_ID
                WHERE b.BOOKING_ID = <cfqueryparam value="#arguments.bookingId#" cfsqltype="cf_sql_numeric">
            </cfquery>
            
            <cfif qryDetails.recordCount eq 0>
                <cfreturn {
                    "SUCCESS" = false,
                    "MESSAGE" = "Booking not found"
                }>
            </cfif>
            
            <cfreturn {
                "SUCCESS" = true,
                "BOOKING" = {
                    "BOOKING_ID" = qryDetails.BOOKING_ID,
                    "FULL_NAME" = qryDetails.FULL_NAME,
                    <!--- Approvers must be able to tell these two apart. Older
                          records have no BOOKED_FOR_NAME, so fall back to the
                          requester and flag that it was not explicitly recorded. --->
                    "REQUESTED_BY" = qryDetails.FULL_NAME,
                    "RESERVATION_FOR" = len(trim(qryDetails.BOOKED_FOR_NAME)) ? qryDetails.BOOKED_FOR_NAME : qryDetails.FULL_NAME,
                    "RESERVATION_FOR_RECORDED" = len(trim(qryDetails.BOOKED_FOR_NAME)) GT 0,
                    "RESERVATION_FOR_EMAIL" = trim(qryDetails.BOOKED_FOR_EMAIL),
                    "DEPARTMENT" = trim(qryDetails.BOOKED_FOR_DEPARTMENT),
                    "RECURRENCE" = trim(qryDetails.RECURRING_DETAILS),
                    "CANCELLATION_REASON" = trim(qryDetails.CANCELLATION_REASON),
                    "MEETING_TITLE" = qryDetails.MEETING_TITLE,
                    "ROOM_NAME" = qryDetails.ROOM_NAME,
                    "LOCATION" = "#qryDetails.BUILDING#.#qryDetails.ROOM_NUMBER#",
                    "CAPACITY" = qryDetails.CAPACITY,
                    "DATE" = qryDetails.DATEBOOKED,
                    "TIME" = qryDetails.TIME,
                    "STATUS" = qryDetails.STATUS,
                    "IMAGE" = qryDetails.ROOM_IMAGE,
                    "NOTES" = qryDetails.NOTES,
                    "USER_EMAIL" = qryDetails.EMAIL,
                    "START_DATE" = qryDetails.START_DATE,
                    "END_DATE" = qryDetails.END_DATE
                }
            }>
            
        <cfcatch>
            <cfreturn {
                "SUCCESS" = false,
                "MESSAGE" = "Error retrieving booking details: " & cfcatch.message
            }>
        </cfcatch>
        </cftry>
    </cffunction>

    <!--- Helper function to update booking status --->
    <cffunction name="updateBookingStatus" access="private" returntype="struct">
        <cfargument name="bookingId" type="numeric" required="true">
        <cfargument name="status" type="string" required="true">
        <cfargument name="userId" type="string" required="false">
        <cfargument name="comment" type="string" required="false" default="">
    
        <cftry>
            <!--- COMMENTS holds the requester's meeting title / purpose. The
                  previous version assigned arguments.comment unconditionally, so
                  approving a booking (which passes no comment) blanked the
                  purpose outright. Approvals now leave it alone, and a rejection
                  reason is appended rather than overwriting it. --->
            <cfquery datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                UPDATE #this.DBSCHEMA#.BOOKINGS
                SET STATUS = <cfqueryparam value="#arguments.status#" cfsqltype="cf_sql_varchar">,
                APPROVED_BY = <cfqueryparam value="#arguments.userId#" cfsqltype="cf_sql_varchar">,
                DECIDED_BY = <cfqueryparam value="#val(arguments.userId)#" cfsqltype="cf_sql_numeric" null="#!isNumeric(arguments.userId)#">,
                DECIDED_AT = CURRENT_TIMESTAMP,
                UPDATED_AT = CURRENT_TIMESTAMP
                <cfif len(trim(arguments.comment))>
                , COMMENTS = SUBSTR(
                    NVL2(COMMENTS, COMMENTS || ' | ', '') ||
                    <cfqueryparam value="#uCase(arguments.status)#: #trim(arguments.comment)#" cfsqltype="cf_sql_varchar">,
                    1, 1000)
                </cfif>
                WHERE BOOKING_ID = <cfqueryparam value="#arguments.bookingId#" cfsqltype="cf_sql_numeric">
            </cfquery>
             <cfset var bookingDetails = getBookingDetails(arguments.bookingId)>

            <!--- Send notification email --->  
            <cfif arguments.status eq "Approved">

                <cfif bookingDetails.SUCCESS eq true>
                    <cfset var booking = bookingDetails.BOOKING>
                    <cfset var emailBody = "
                        <h2>BOOKING CONFIRMATION</h2>
                        
                        <p>Greetings, <cfoutput>#booking.FULL_NAME#</cfoutput></p>
                        
                        <p>Thank you for your reservation! We're happy to confirm that your office space is successfully booked.</p>
                        <p>Below are the details of your reservation:</p>
                        
                        <h3>Reservation Details:</h3>
                        <ul>
                            <li><strong>Office Space Location:</strong> <cfoutput>#booking.LOCATION#</cfoutput></li>
                            <li><strong>Date :</strong> <cfoutput>#booking.START_DATE#</cfoutput></li>
                            <li><strong>Time:</strong> <cfoutput>#booking.TIME#</cfoutput></li>
                        </ul>
                        
                        <h3>Important Information:</h3>
                        <ul>
                            <li><strong>If the office door is locked:</strong> If you have a key for the FC11 floor, you can use it to open any door on that floor. If you do not have a key, spare keys are available at the front desk in the overhead.</li>
                            <li><strong>Key Return:</strong> Please make sure to return the key to the front desk after your reservation to ensure it's available for the next person.</li>
                            <li><strong>Personal belongings and Cleanliness:</strong> Please remember not to leave any personal belongings in the office, and kindly clean up after yourself before leaving to maintain the space for others.</li>
                            <li><strong>Cancellation Reminder:</strong> If your plans change and you no longer need the office space, please cancel your reservation as soon as possible to allow others the opportunity to use the space.</li>
                        </ul>
                        
                        <p>We hope this space meets your needs, and please don't hesitate to reach out if you have any questions or need assistance.</p>
                        
                        <p>Best regards,</p>
                    ">
                    
                    <!--- Get admin users for CC --->
                <cfquery name="qryGetAdminEmails" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                    SELECT EMAIL
                    FROM #this.DBSCHEMA#.USERS
                    WHERE ROLE_ID = 2
                </cfquery>
                <cfset adminEmails = "">
                <cfloop query="qryGetAdminEmails">
                    <cfset adminEmails = ListAppend(adminEmails, qryGetAdminEmails.EMAIL)>
                </cfloop>
                    
                    <!--- Send email --->
                    <cfmail to="#booking.USER_EMAIL#" from="NO-REPLY@mdanderson.org" subject="Office Space Reservation Confirmation" type="html" bcc="#adminEmails#">
                        <cfmailpart type="text/html">
                            <cfoutput>#emailBody#</cfoutput>
                        </cfmailpart>
                    </cfmail>
                </cfif>
            </cfif>

            <!--- Send rejection email --->
            <cfif arguments.status eq "Rejected">
                <cfif bookingDetails.SUCCESS eq true>
                    <cfset var booking = bookingDetails.BOOKING>
                    <cfset var emailBody = "
                        <h2>BOOKING DECLINED</h2>
                        
                        <p>Dear, #booking.FULL_NAME#</p>
                        
                        <p>Unfortunately, your booking request has been declined.</p>
                        <p></p>
                        
                            <p>Booking Details:</p>
                            <ul>
                                <li><strong>Office Space Location:</strong> #booking.LOCATION#</li>
                                <li><strong>Date:</strong> #booking.DATE#</li>
                                <li><strong>Time:</strong> #booking.TIME#</li>
                                <li><strong>Reason:</strong> ""#arguments.comment#""</li>
                            </ul><p></p>
                            
                            <p>Please contact the admin if you have any questions.</p>
                            
                            <p>Thank you for your understanding.</p>
                        ">
                        
                        <!--- Get admin users for CC --->
                        <cfquery name="qryGetAdminEmails" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                            SELECT EMAIL
                            FROM #this.DBSCHEMA#.USERS
                            WHERE ROLE_ID = 1
                        </cfquery>
                        <cfset adminEmails = "">
                        <cfloop query="qryGetAdminEmails">
                            <cfset adminEmails = ListAppend(adminEmails, qryGetAdminEmails.EMAIL)>
                        </cfloop>
                        
                        <!--- Send email logic here --->
                        <cfmail to="#booking.USER_EMAIL#" from="NO-REPLY@mdanderson.org" subject="Booking Declined" type="html" bcc="#adminEmails#">
                            <cfmailpart type="text/html">
                                <cfoutput>#emailBody#</cfoutput>
                            </cfmailpart>
                        </cfmail>
                </cfif>
            </cfif>
           
            
            <cfreturn {
                "SUCCESS": true,
                "MESSAGE": "Booking status updated successfully"
            }>
            
            <cfcatch type="any">
                <!--- Include cfcatch.detail: ColdFusion's message for a database
                      failure is the useless "Error Executing Database Query." and
                      the actual cause (constraint name, ORA- code) is only in
                      detail. Bulk approval surfaces this string to the approver as
                      the per-request failure reason, so it has to be diagnostic. --->
                <cflog type="error" file="bulk_approvals"
                       text="updateBookingStatus failed for booking #arguments.bookingId# (status '#arguments.status#'): #cfcatch.message# #cfcatch.detail#">
                <cfreturn {
                    "SUCCESS": false,
                    "MESSAGE": "Error updating booking status: #cfcatch.message# #cfcatch.detail#"
                }>
            </cfcatch>
        </cftry>
    </cffunction>

    <!--- Approve booking --->
    <!--- Status values MUST be lowercase. CHK_BOOKINGS_STATUS permits only
          'pending','approved','rejected','cancelled','archived', so passing
          'Approved' raised ORA-02290 and EVERY approval and rejection failed --
          individual as well as bulk. The rest of the application already writes
          lowercase ('pending' on insert, 'cancelled' on cancel) and compares with
          LOWER(), so lowercase is the consistent choice. updateBookingStatus
          compares this argument with `eq`, which is case-insensitive, so the
          notification branches still select correctly. --->
    <!--- `comment` carries an explicit default on all four entry points: without
          one, arguments.comment is undefined whenever the caller omits it and
          passing it through throws "Element COMMENT is undefined". --->
    <cffunction name="approveBooking" access="remote" returntype="struct" returnformat="json">
        <cfargument name="bookingId" type="numeric" required="true">
        <cfargument name="userId" type="string" required="true">
        <cfargument name="comment" type="string" required="false" default="">
        <cfreturn updateBookingStatus(arguments.bookingId, "approved", arguments.userId, arguments.comment)>
    </cffunction>

    <!--- Reject booking --->
    <cffunction name="rejectBooking" access="remote" returntype="struct" returnformat="json">
        <cfargument name="bookingId" type="numeric" required="true">
        <cfargument name="userId" type="string" required="true">
        <cfargument name="comment" type="string" required="false" default="">
        <cfreturn updateBookingStatus(arguments.bookingId, "rejected", arguments.userId, arguments.comment)>
    </cffunction>

    <!--- Bulk approve bookings --->
    <cffunction name="bulkApproveBookings" access="remote" returntype="struct" returnformat="json">
        <cfargument name="bookingIds" type="string" required="true">
        <cfargument name="userId" type="string" required="true">
        <cfargument name="comment" type="string" required="false" default="">
        <cfreturn bulkUpdateBookingStatus(arguments.bookingIds, "approved", arguments.userId, arguments.comment)>
    </cffunction>

    <!--- Bulk reject bookings --->
    <cffunction name="bulkRejectBookings" access="remote" returntype="struct" returnformat="json">
        <cfargument name="bookingIds" type="string" required="true">
        <cfargument name="userId" type="string" required="true">
        <cfargument name="comment" type="string" required="false" default="">
        <cfreturn bulkUpdateBookingStatus(arguments.bookingIds, "rejected", arguments.userId, arguments.comment)>
    </cffunction>

    <!---
        Look up an asserted user's role so bulk actions can be gated server-side.

        KNOWN GAP -- this application has no Application.cfc, so no session scope
        exists and `userId` arrives as a client-supplied assertion the server
        cannot authenticate. The role check enforces the business rule but is not
        yet a security boundary. See docs/reservation-improvements-progress.md.
    --->
    <cffunction name="getActorAuthorization" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">

        <cfset var result = { "found" = false, "isAdmin" = false, "roleName" = "", "fullName" = "" }>
        <cfset var qActor = "">

        <cfquery name="qActor" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
            SELECT u.USER_ID, u.FIRST_NAME, u.LAST_NAME, NVL(ro.ROLE_NAME, '') AS ROLE_NAME
            FROM #this.DBSCHEMA#.USERS u
            LEFT JOIN #this.DBSCHEMA#.ROLES ro ON ro.ROLE_ID = u.ROLE_ID
            WHERE u.USER_ID = <cfqueryparam value="#arguments.userId#" cfsqltype="cf_sql_numeric">
              AND UPPER(u.STATUS) = 'ACTIVE'
        </cfquery>

        <cfif qActor.recordCount>
            <cfset result.found = true>
            <cfset result.roleName = qActor.ROLE_NAME>
            <cfset result.isAdmin = ListFindNoCase("Admin,Site Admin", trim(qActor.ROLE_NAME)) GT 0>
            <cfset result.fullName = trim(qActor.FIRST_NAME & " " & qActor.LAST_NAME)>
        </cfif>

        <cfreturn result>
    </cffunction>

    <!---
        Does this booking overlap an already-approved booking in the same room?
        Called immediately before each approval so a request that was fine when
        the queue was rendered cannot be approved into a conflict.

        excludeId keeps the booking under test from matching itself.
    --->
    <cffunction name="hasApprovedConflict" access="private" returntype="struct" output="false">
        <cfargument name="bookingId" type="numeric" required="true">

        <cfset var result = { "conflict" = false, "detail" = "" }>
        <cfset var qConflict = "">

        <cfquery name="qConflict" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
            SELECT
                other.BOOKING_ID,
                TO_CHAR(other.START_TIME, 'MM/DD/YYYY HH12:MI AM') AS OTHER_START,
                TO_CHAR(other.END_TIME, 'HH12:MI AM') AS OTHER_END
            FROM #this.DBSCHEMA#.BOOKINGS b
            JOIN #this.DBSCHEMA#.BOOKINGS other
              ON other.ROOM_ID = b.ROOM_ID
             AND other.BOOKING_ID <> b.BOOKING_ID
             AND LOWER(other.STATUS) = 'approved'
             AND other.START_TIME < b.END_TIME
             AND other.END_TIME > b.START_TIME
            WHERE b.BOOKING_ID = <cfqueryparam value="#arguments.bookingId#" cfsqltype="cf_sql_numeric">
            ORDER BY other.START_TIME
            FETCH FIRST 1 ROWS ONLY
        </cfquery>

        <cfif qConflict.recordCount>
            <cfset result.conflict = true>
            <cfset result.detail = "Overlaps approved reservation ##" & qConflict.BOOKING_ID &
                                   " (" & trim(qConflict.OTHER_START) & " - " & trim(qConflict.OTHER_END) & ")">
        </cfif>

        <cfreturn result>
    </cffunction>

    <!---
        Bulk status update.

        Processes each request individually through the same updateBookingStatus()
        path a single approval uses, so notifications and business rules cannot
        drift between the two. One failure does not abort the batch -- each
        request gets its own outcome, and the caller receives a per-request
        breakdown so partial success is visible.
    --->
    <cffunction name="bulkUpdateBookingStatus" access="private" returntype="struct" output="false">
        <cfargument name="bookingIds" type="string" required="true">
        <cfargument name="status" type="string" required="true">
        <cfargument name="userId" type="string" required="true">
        <cfargument name="comment" type="string" required="false" default="">

        <cfset var actor = "">
        <cfset var succeeded = []>
        <cfset var failed = []>
        <cfset var id = "">
        <cfset var cleanId = "">
        <cfset var seen = {}>
        <cfset var idList = "">
        <cfset var qLock = "">
        <cfset var claimResult = "">
        <cfset var conflictCheck = "">
        <cfset var updateResult = "">
        <cfset var batchWindows = []>
        <cfset var qWindow = "">
        <cfset var w = "">
        <cfset var overlapsBatch = false>
        <cfset var priorWindow = "">

        <!--- Authorization: only administrators may act in bulk. --->
        <cfif NOT isNumeric(arguments.userId)>
            <cfreturn { "SUCCESS" = false, "MESSAGE" = "A valid acting user is required." }>
        </cfif>

        <cfset actor = getActorAuthorization(val(arguments.userId))>

        <cfif NOT actor.found>
            <cfreturn { "SUCCESS" = false, "MESSAGE" = "The acting user is not an active account." }>
        </cfif>

        <cfif NOT actor.isAdmin>
            <cflog type="warning" file="bulk_approvals"
                   text="Denied bulk #arguments.status# by user #arguments.userId# (role '#actor.roleName#'): not an administrator.">
            <cfreturn { "SUCCESS" = false, "MESSAGE" = "You do not have permission to perform bulk approvals." }>
        </cfif>

        <!--- Normalise and de-duplicate the id list. A repeated id must not be
              processed twice or it would notify the requester twice. --->
        <cfloop list="#arguments.bookingIds#" index="id">
            <cfset cleanId = trim(id)>
            <cfif isNumeric(cleanId) AND NOT structKeyExists(seen, cleanId)>
                <cfset seen[cleanId] = true>
                <cfset idList = ListAppend(idList, cleanId)>
            </cfif>
        </cfloop>

        <cfif NOT ListLen(idList)>
            <cfreturn { "SUCCESS" = false, "MESSAGE" = "No valid reservation numbers were supplied." }>
        </cfif>

        <cfif ListLen(idList) GT 200>
            <cfreturn { "SUCCESS" = false, "MESSAGE" = "Please select 200 or fewer reservations per batch." }>
        </cfif>

        <cfloop list="#idList#" index="id">
            <cftry>
                <!--- Claim the row: flip pending -> in-progress status atomically so
                      a second approver working the same queue cannot also claim it.
                      recordCount 0 means somebody else already resolved it. --->
                <cfquery name="qLock" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#" result="claimResult">
                    UPDATE #this.DBSCHEMA#.BOOKINGS
                    SET UPDATED_AT = CURRENT_TIMESTAMP
                    WHERE BOOKING_ID = <cfqueryparam value="#id#" cfsqltype="cf_sql_numeric">
                      AND LOWER(STATUS) = 'pending'
                </cfquery>

                <cfif NOT structKeyExists(claimResult, "recordCount") OR claimResult.recordCount EQ 0>
                    <cfset arrayAppend(failed, {
                        "bookingId" = id,
                        "reason" = "No longer pending - it was already approved, rejected or cancelled by someone else."
                    })>
                    <cfcontinue>
                </cfif>

                <!--- Re-check availability against approved bookings. --->
                <cfif arguments.status EQ "Approved">
                    <cfset conflictCheck = hasApprovedConflict(val(id))>
                    <cfif conflictCheck.conflict>
                        <cfset arrayAppend(failed, {
                            "bookingId" = id,
                            "reason" = conflictCheck.detail
                        })>
                        <cfcontinue>
                    </cfif>

                    <!--- Conflicts *within this batch*: two selected requests for the
                          same room at overlapping times cannot both be approved. --->
                    <cfquery name="qWindow" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                        SELECT ROOM_ID, START_TIME, END_TIME,
                               TO_CHAR(START_TIME, 'MM/DD/YYYY HH12:MI AM') AS DISPLAY_START
                        FROM #this.DBSCHEMA#.BOOKINGS
                        WHERE BOOKING_ID = <cfqueryparam value="#id#" cfsqltype="cf_sql_numeric">
                    </cfquery>

                    <cfset overlapsBatch = false>
                    <cfset priorWindow = "">
                    <cfloop array="#batchWindows#" index="w">
                        <cfif w.roomId EQ qWindow.ROOM_ID
                              AND w.startTime LT qWindow.END_TIME
                              AND w.endTime GT qWindow.START_TIME>
                            <cfset overlapsBatch = true>
                            <cfset priorWindow = w.bookingId>
                            <cfbreak>
                        </cfif>
                    </cfloop>

                    <cfif overlapsBatch>
                        <cfset arrayAppend(failed, {
                            "bookingId" = id,
                            "reason" = "Conflicts with reservation ##" & priorWindow & " also selected in this batch."
                        })>
                        <cfcontinue>
                    </cfif>
                </cfif>

                <!--- Same code path as an individual approval, so notifications and
                      rules stay identical. --->
                <cfset updateResult = updateBookingStatus(
                    bookingId = val(id),
                    status = arguments.status,
                    userId = arguments.userId,
                    comment = arguments.comment
                )>

                <cfif isStruct(updateResult) AND structKeyExists(updateResult, "SUCCESS") AND updateResult.SUCCESS>
                    <cfset arrayAppend(succeeded, id)>

                    <!--- Only reserve the time window once the approval stuck. --->
                    <cfif arguments.status EQ "Approved" AND isQuery(qWindow) AND qWindow.recordCount>
                        <cfset arrayAppend(batchWindows, {
                            "bookingId" = id,
                            "roomId" = qWindow.ROOM_ID,
                            "startTime" = qWindow.START_TIME,
                            "endTime" = qWindow.END_TIME
                        })>
                    </cfif>

                    <cfset writeAuditEntry(
                        bookingId = val(id),
                        actorId = val(arguments.userId),
                        actorName = actor.fullName,
                        action = arguments.status,
                        detail = "Bulk " & lCase(arguments.status) & " of " & ListLen(idList) & " selected reservations."
                    )>
                <cfelse>
                    <cfset arrayAppend(failed, {
                        "bookingId" = id,
                        "reason" = isStruct(updateResult) AND structKeyExists(updateResult, "MESSAGE")
                                   ? updateResult.MESSAGE
                                   : "The status update did not complete."
                    })>
                </cfif>

            <cfcatch>
                <!--- One bad request must not abort the rest of the batch. --->
                <cflog type="error" file="bulk_approvals"
                       text="Bulk #arguments.status# failed for booking #id#: #cfcatch.message# #cfcatch.detail#">
                <cfset arrayAppend(failed, {
                    "bookingId" = id,
                    "reason" = "Unexpected error: " & cfcatch.message
                })>
            </cfcatch>
            </cftry>
        </cfloop>

        <cflog type="information" file="bulk_approvals"
               text="Bulk #arguments.status# by user #arguments.userId#: #arrayLen(succeeded)# succeeded, #arrayLen(failed)# failed of #ListLen(idList)# selected.">

        <cfreturn {
            "SUCCESS" = arrayLen(succeeded) GT 0,
            "MESSAGE" = arrayLen(failed) EQ 0
                        ? "All #arrayLen(succeeded)# reservation(s) were #lCase(arguments.status)#."
                        : "#arrayLen(succeeded)# of #ListLen(idList)# reservation(s) were #lCase(arguments.status)#. #arrayLen(failed)# could not be processed.",
            "TOTALREQUESTED" = ListLen(idList),
            "SUCCEEDEDCOUNT" = arrayLen(succeeded),
            "FAILEDCOUNT" = arrayLen(failed),
            "SUCCEEDED" = succeeded,
            "FAILED" = failed
        }>
    </cffunction>

    <!--- Audit trail for approval decisions. Never allowed to break the decision
          it is recording -- a logging failure is logged and swallowed. --->
    <cffunction name="writeAuditEntry" access="private" returntype="void" output="false">
        <cfargument name="bookingId" type="numeric" required="true">
        <cfargument name="actorId" type="numeric" required="true">
        <cfargument name="actorName" type="string" required="true">
        <cfargument name="action" type="string" required="true">
        <cfargument name="detail" type="string" required="false" default="">

        <cftry>
            <!--- Live SYSTEM_LOGS columns: LOG_ID, USER_ID, ACTION_TYPE (NOT NULL),
                  CHANGE_DETAILS, LOG_TIMESTAMP, TABLE_NAME, RECORD_ID.
                  Note assets/sql/tables.sql is stale here and lists
                  ACTION/DETAILS/TIMESTAMP instead. --->
            <cfquery datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                INSERT INTO #this.DBSCHEMA#.SYSTEM_LOGS
                    (USER_ID, ACTION_TYPE, CHANGE_DETAILS, TABLE_NAME, RECORD_ID, LOG_TIMESTAMP)
                VALUES (
                    <cfqueryparam value="#arguments.actorId#" cfsqltype="cf_sql_numeric">,
                    <cfqueryparam value="#left('BOOKING_' & uCase(arguments.action), 100)#" cfsqltype="cf_sql_varchar">,
                    <cfqueryparam value="#left('Reservation ##' & arguments.bookingId & ' ' & lCase(arguments.action) & ' by ' & arguments.actorName & '. ' & arguments.detail, 1000)#" cfsqltype="cf_sql_varchar">,
                    <cfqueryparam value="BOOKINGS" cfsqltype="cf_sql_varchar">,
                    <cfqueryparam value="#arguments.bookingId#" cfsqltype="cf_sql_varchar">,
                    CURRENT_TIMESTAMP
                )
            </cfquery>
        <cfcatch>
            <cflog type="error" file="bulk_approvals"
                   text="Audit write failed for booking #arguments.bookingId# (#arguments.action#): #cfcatch.message#">
        </cfcatch>
        </cftry>
    </cffunction>

    <!--- Helper function to get all admin users' emails --->
    <cffunction name="getAdminEmails" access="private" returntype="string">
        <cftry>
            <cfquery name="getAdmins" datasource="#this.DATASOURCE#">
                SELECT EMAIL
                FROM #this.DBSCHEMA#.USERS
                WHERE ROLE_ID = 2
            </cfquery>
            
            <cfset var emailList = "">
            <cfloop query="getAdmins">
                <cfset emailList = listAppend(emailList, EMAIL)>
            </cfloop>
            
            <cfreturn emailList>
            
        <cfcatch>
            <!--- Return default admin emails if query fails --->
            <cfreturn "erniep@mdanderson.org,tglover@mdanderson.org">
        </cfcatch>
        </cftry>
    </cffunction>
    
    <!--- Helper function to send approval email --->
    <cffunction name="sendApprovalEmail" access="private" returntype="void">
        <cfargument name="bookingId" type="numeric" required="true">
 
            <cfset var bookingDetails = getBookingDetails(arguments.bookingId)>
            <cfdump var="#bookingDetails#">

            <cfif bookingDetails.SUCCESS eq true>
                <cfset var booking = bookingDetails.BOOKING>
                <cfset var emailBody = "
                    <h2>BOOKING CONFIRMATION</h2>
                    
                    <p>Subject: Your Office Space Reservation Confirmation email</p>
                    
                    <p>Greetings <cfoutput>#booking.FULL_NAME#</cfoutput></p>
                    
                    <p>Thank you for your reservation! We're happy to confirm that your office space is successfully booked.</p>
                    <p>Below are the details of your reservation:</p>
                    
                    <h3>Reservation Details:</h3>
                    <ul>
                        <li><strong>Office Space Location:</strong> <cfoutput>#booking.LOCATION#</cfoutput></li>
                        <li><strong>Date:</strong> <cfoutput>#booking.DATE#</cfoutput></li>
                        <li><strong>Time:</strong> <cfoutput>#booking.TIME#</cfoutput></li>
                    </ul>
                    
                    <h3>Important Information:</h3>
                    <ul>
                        <li><strong>If the office door is locked:</strong> If you have a key for the FC11 floor, you can use it to open any door on that floor. If you do not have a key, spare keys are available at the front desk in the overhead.</li>
                        <li><strong>Key Return:</strong> Please make sure to return the key to the front desk after your reservation to ensure it's available for the next person.</li>
                        <li><strong>Personal belongings and Cleanliness:</strong> Please remember not to leave any personal belongings in the office, and kindly clean up after yourself before leaving to maintain the space for others.</li>
                        <li><strong>Cancellation Reminder:</strong> If your plans change and you no longer need the office space, please cancel your reservation as soon as possible to allow others the opportunity to use the space.</li>
                    </ul>
                    
                    <p>We hope this space meets your needs, and please don't hesitate to reach out if you have any questions or need assistance.</p>
                    
                    <p>Best regards,</p>
                ">
                <!--- Get admin emails --->
                <cfquery name="qryGetAdminEmails" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                    SELECT EMAIL
                    FROM #this.DBSCHEMA#.USERS
                    WHERE ROLE_ID = 1
                </cfquery>
                <cfset adminEmails = "">
                <cfloop query="qryGetAdminEmails">
                    <cfset adminEmails = ListAppend(adminEmails, qryGetAdminEmails.EMAIL)>
                </cfloop>
                <!--- Send email --->
                <cfmail to="#booking.USER_EMAIL#" from="NO-REPLY@mdanderson.org" subject="Your Office Space Reservation Booking Confirmed" type="html" bcc="#adminEmails#">
                    <cfmailpart type="text/html">
                        <cfoutput>#emailBody#</cfoutput>
                    </cfmailpart>
                </cfmail>
            </cfif>
   
    </cffunction>

    <!--- Helper function to send rejection email --->
    <cffunction name="sendRejectionEmail" access="private" returntype="void">
        <cfargument name="bookingId" type="numeric" required="true">
        <cfargument name="comments" type="string" required="true">
        <!-- get booking details -->
        <cftry>
            <cfset var bookingDetails = getBookingDetails(arguments.bookingId)>
            <cfif bookingDetails.SUCCESS>
                <cfset var booking = bookingDetails.BOOKING>
                <cfset var emailBody = "
                    Dear #booking.USER_NAME#,
                    
                    Unfortunately, your booking request has been rejected.
                    
                    Booking Details:
                    - Room: #booking.LOCATION#
                    - Date: #booking.DATE#
                    - Time: #booking.TIME# - #booking.END_TIME#
                    - Reason for Rejection: #arguments.comments#
                    
                    Please contact the admin if you have any questions.
                    
                    Thank you for your understanding.
                ">
                <cfquery name="qryGetAdminEmails" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                    SELECT EMAIL
                    FROM #this.DBSCHEMA#.USERS
                    WHERE ROLE_ID = 1
                </cfquery>
                <cfset adminEmails = "">
                <cfloop query="qryGetAdminEmails">
                    <cfset adminEmails = ListAppend(adminEmails, qryGetAdminEmails.EMAIL)>
                </cfloop>
                <!--- Send email logic here --->
                <cfmail to="#booking.USER_EMAIL#" from="NO-REPLY@mdanderson.org" subject="Booking Rejected" type="html" bcc="#adminEmails#">
                    #emailBody#
                </cfmail>
            </cfif>
            
        <cfcatch>
            <cflog type="error"  file="#GetDirectoryFromPath(GetCurrentTemplatePath())#assets/logs/error.log" text="Error sending rejection email: #cfcatch.message#">
        </cfcatch>
        </cftry>
    </cffunction>

    <cffunction name="sendReminderEmail" access="private" returntype="void">
        <cfargument name="bookingId" type="numeric" required="true">

        <cftry>
            <cfset var bookingDetails = getBookingDetails(arguments.bookingId)>
            <cfif bookingDetails.SUCCESS>
                <cfset var booking = bookingDetails.BOOKING>
                <cfset var emailBody = "
                    Dear #booking.USER_NAME#,
                    This is a friendly reminder that you have an upcoming reservation for office space on #booking.DATE#. Below are the details of your booking:
                    Reservation Details:
                    •	Office Location: #booking.LOCATION#
                    •	Date: #booking.DATE#
                    •	Time: #booking.TIME# - #booking.END_TIME#
                    Important Information:
                    •	If the office door is locked: If you have a key for the FC11 floor, you can use it to open any door on that floor. If you do not have a key, spare keys are available at the front desk in the overhead.
                    •	Key Return: Please make sure to return the key to the front desk after your reservation to ensure it's available for the next person.
                    •	Personal Belongings and Cleanliness: Please remember not to leave any personal belongings in the office, and kindly clean up after yourself before leaving to maintain the space for others.
                    •	Cancellation Reminder: If your plans change and you no longer need the office space, please cancel your reservation as soon as possible to allow others the opportunity to use the space.
                    We hope this space meets your needs, and please don't hesitate to reach out if you have any questions or need assistance.
                    Best regards,
                ">
                
                <!--- Get admin users for CC --->
                <cfquery name="qryGetAdminEmails" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                    SELECT EMAIL
                    FROM #this.DBSCHEMA#.USERS
                    WHERE ROLE_ID = 1
                </cfquery>
                <cfset adminEmails = "">
                <cfloop query="qryGetAdminEmails">
                    <cfset adminEmails = ListAppend(adminEmails, qryGetAdminEmails.EMAIL)>
                </cfloop>
                
                <!--- Send email logic here --->
                <cfmail to="#booking.USER_EMAIL#" from="NO-REPLY@mdanderson.org" subject="Booking Rejected" type="html" cc="#adminEmails#">
                    #emailBody#
                </cfmail>
            </cfif>
            
        <cfcatch>
            <cflog type="error"  file="#GetDirectoryFromPath(GetCurrentTemplatePath())#assets/logs/error.log" text="Error sending rejection email: #cfcatch.message#">
        </cfcatch>
        </cftry>
    </cffunction>

    <cffunction name="queryToArray" access="private" returntype="array">
        <cfargument name="qry" type="query" required="true">
        
        <cfset var array = []>
        <cfloop query="arguments.qry">
            <cfset arrayAppend(array, {})>
            <cfloop list="#arguments.qry.columnList#" index="col">
                <cfset array[arrayLen(array)][col] = arguments.qry[col][currentRow]>
            </cfloop>
        </cfloop>
        
        <cfreturn array>
    </cffunction>

    <!--- Mark expired pending bookings as 'Expired' --->  
    <cffunction name="markExpiredBookings" access="remote" returntype="struct" returnformat="json">
        <cftry>
            <cfset currentDateTime = Now()>
            
            <!--- First, get all expired pending bookings --->  
            <cfquery name="qGetExpiredBookings" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT BOOKING_ID
                FROM #this.DBSCHEMA#.BOOKINGS
                WHERE LOWER(STATUS) = 'pending'
                AND END_TIME <= <cfqueryparam value="#currentDateTime#" cfsqltype="CF_SQL_TIMESTAMP">
            </cfquery>
            
            <cfset expiredCount = qGetExpiredBookings.RecordCount>
            
            <!--- Update status to 'Expired' for these bookings --->  
            <cfif expiredCount GT 0>
                <cfquery datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                    UPDATE #this.DBSCHEMA#.BOOKINGS
                    SET STATUS = 'Expired'
                    WHERE LOWER(STATUS) = 'pending'
                    AND END_TIME <= <cfqueryparam value="#currentDateTime#" cfsqltype="CF_SQL_TIMESTAMP">
                </cfquery>
                
                <cflog file="booking_approvals" text="Marked #expiredCount# expired bookings as 'Expired'">
            </cfif>
            
            <cfreturn {"SUCCESS": true, "EXPIRED_COUNT": expiredCount}>
            
            <cfcatch type="any">
                <cflog file="booking_approvals" text="Error marking expired bookings: #cfcatch.message#">
                <cfreturn {"SUCCESS": false, "MESSAGE": cfcatch.message}>
            </cfcatch>
        </cftry>
    </cffunction>
    
    <cffunction name="getPendingApprovalsCount" access="remote" returntype="numeric" returnformat="plain">
        <cftry>
            <!--- First mark any expired bookings --->  
            <cfset markExpiredBookings()>
            
            <!--- Get current date/time --->  
            <cfset currentDateTime = Now()>
            
            <cfquery name="qGetPendingCount" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT COUNT(*) as PendingCount
                FROM #this.DBSCHEMA#.BOOKINGS
                WHERE LOWER(STATUS) = 'pending'
            </cfquery>
            
            <cflog file="booking_approvals" text="Pending approvals count: #qGetPendingCount.PendingCount#">
            
            <cfreturn qGetPendingCount.PendingCount>
            
            <cfcatch type="any">
                <cfreturn 0>
            </cfcatch>
        </cftry>
    </cffunction>

</cfcomponent>
