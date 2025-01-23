<cfcomponent>
    <cfif ListFirst(CGI.SERVER_NAME,'.') EQ 'cmapps'>
        <cfset this.DBSERVER = "inside2_docmp" />
        <cfset this.DBUSER = "CONFROOM_USER" />
        <cfset this.DBPASS = "1docmD4OU6D88" />
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
                    r.ROOM_NAME,
                    r.BUILDING as BUILDING,
                    r.ROOM_NUMBER as ROOM_NUMBER,
                    TO_NUMBER(r.CAPACITY) as CAPACITY,
                    TO_CHAR(b.START_TIME, 'YYYY-MM-DD') as BOOKING_DATE,
                    TO_CHAR(b.START_TIME, 'HH24:MI') as START_TIME,
                    TO_CHAR(b.END_TIME, 'HH24:MI') as END_TIME,
                    TO_CHAR(b.START_TIME, 'MM/DD/YYYY HH24:MI AM')as START_DATE,
                    TO_CHAR(b.END_TIME, 'MM/DD/YYYY HH24:MI AM') as END_DATE,
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
                    r.ROOM_NAME,
                    TO_CHAR(b.CREATED_AT, 'FMDay, FMMonth DD, YYYY') as DATEBOOKED,
                    TO_CHAR(b.START_TIME, 'HH12:MI AM') || ' - ' || TO_CHAR(b.END_TIME, 'HH12:MI AM') as TIME,
                    TO_CHAR(b.START_TIME, 'MM/DD/YYYY HH24:MI AM') as START_DATE,
                    TO_CHAR(b.END_TIME, 'MM/DD/YYYY HH24:MI AM') as END_DATE,
                    b.STATUS,
                    b.RECURRING_DETAILS,
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
            <cfquery datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                UPDATE #this.DBSCHEMA#.BOOKINGS
                SET STATUS = <cfqueryparam value="#arguments.status#" cfsqltype="cf_sql_varchar">,
                APPROVED_BY = <cfqueryparam value="#arguments.userId#" cfsqltype="cf_sql_varchar">,
                UPDATED_AT = CURRENT_TIMESTAMP,
                COMMENTS = <cfqueryparam value="#arguments.comment#" cfsqltype="cf_sql_varchar">
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
                    
                    <!--- Send email --->
                    <cfmail to="#booking.USER_EMAIL#" from="NO-REPLY@mdanderson.org" subject="Office Space Reservation Confirmation" type="html" bcc="erniep@mdanderson.org, tlouie@mdanderson.org, cpender@mdanderson.org, tglover@mdanderson.org">
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
                        
                        <!--- Send email logic here --->
                        <cfmail to="#booking.USER_EMAIL#" from="NO-REPLY@mdanderson.org" subject="Booking Declined" type="html" bcc="erniep@mdanderson.org, tlouie@mdanderson.org, cpender@mdanderson.org, tglover@mdanderson.org">
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
                <cfreturn {
                    "SUCCESS": false,
                    "MESSAGE": "Error updating booking status: #cfcatch.message#"
                }>
            </cfcatch>
        </cftry>
    </cffunction>

    <!--- Approve booking --->
    <cffunction name="approveBooking" access="remote" returntype="struct" returnformat="json">
        <cfargument name="bookingId" type="numeric" required="true">
        <cfargument name="userId" type="string" required="true">
        <cfargument name="comment" type="string" required="false">
        <cfreturn updateBookingStatus(arguments.bookingId,"Approved", arguments.userId)>
    </cffunction>

    <!--- Reject booking --->
    <cffunction name="rejectBooking" access="remote" returntype="struct" returnformat="json">
        <cfargument name="bookingId" type="numeric" required="true">
        <cfargument name="userId" type="string" required="true">
        <cfargument name="comment" type="string" required="false">
        <cfreturn updateBookingStatus(arguments.bookingId, "Rejected", arguments.userId, arguments.comment)>
    </cffunction>

    <!--- Bulk approve bookings --->
    <cffunction name="bulkApproveBookings" access="remote" returntype="struct" returnformat="json">
        <cfargument name="bookingIds" type="string" required="true">
        <cfargument name="userId" type="string" required="true">
        <cfargument name="comment" type="string" required="false">
        <cfreturn bulkUpdateBookingStatus(arguments.bookingIds, "Approved", arguments.userId, arguments.comment)>
    </cffunction>

    <!--- Bulk reject bookings --->
    <cffunction name="bulkRejectBookings" access="remote" returntype="struct" returnformat="json">
        <cfargument name="bookingIds" type="string" required="true">
        <cfargument name="userId" type="string" required="true">
        <cfargument name="comment" type="string" required="false">
        <cfreturn bulkUpdateBookingStatus(arguments.bookingIds, "Rejected", arguments.userId, arguments.comment)>
    </cffunction>

    <!--- Helper function to bulk update booking status --->
    <cffunction name="bulkUpdateBookingStatus" access="private" returntype="struct">
        <cfargument name="bookingIds" type="string" required="true">
        <cfargument name="status" type="string" required="true">
        <cfargument name="userId" type="string" required="true">
        <cfargument name="comment" type="string" required="false">
        
        <cftry>
            <cfquery datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                UPDATE #this.DBSCHEMA#.bookings
                SET status = <cfqueryparam value="#arguments.status#" cfsqltype="cf_sql_varchar">,
                    updated_at = CURRENT_TIMESTAMP
                WHERE booking_id IN (<cfqueryparam value="#arguments.bookingIds#" cfsqltype="cf_sql_varchar" list="true">)
                AND status = <cfqueryparam value="pending" cfsqltype="cf_sql_varchar">
            </cfquery>
            
            <!--- Send notifications for each booking --->
            <cfloop list="#arguments.bookingIds#" index="id">
                <cfif arguments.status eq "Approved">
                   sendApprovalEmail(bookingId=id)
                <cfelseif arguments.status eq "Rejected">
                    sendRejectionEmail(id)
                </cfif>
            </cfloop>
            
            <cfreturn {
                "SUCCESS" = true,
                "MESSAGE" = "Booking statuses updated successfully"
            }>
            
        <cfcatch>
            <cfreturn {
                "SUCCESS" = false,
                "MESSAGE" = "Error updating booking statuses: " & cfcatch.message
            }>
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
                
                <!--- Send email --->
                <cfmail to="#booking.USER_EMAIL#" from="NO-REPLY@mdanderson.org" subject="Your Office Space Reservation Confirmation email" type="html" bcc="erniep@mdanderson.org, tlouie@mdanderson.org, cpender@mdanderson.org, tglover@mdanderson.org">
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
                
                <!--- Send email logic here --->
                <cfmail to="#booking.USER_EMAIL#" from="NO-REPLY@mdanderson.org" subject="Booking Rejected" type="html" bcc="erniep@mdanderson.org,tlouis@mdanderson.org,cpender@mdanderson.org">
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
                
                <!--- Send email logic here --->
                <cfmail to="#booking.USER_EMAIL#" from="NO-REPLY@mdanderson.org" subject="Booking Rejected" type="html" bcc="erniep@mdanderson.org,tlouis@mdanderson.org,cpender@mdanderson.org">
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

    <cffunction name="getPendingApprovalsCount" access="remote" returntype="numeric" returnformat="plain">
        <cftry>
            <cfquery name="qGetPendingCount" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
                SELECT COUNT(*) as PendingCount
                FROM #this.DBSCHEMA#.BOOKINGS
                WHERE LOWER(STATUS) = 'pending'
            </cfquery>
            
            <cfreturn qGetPendingCount.PendingCount>
            
            <cfcatch type="any">
                <cfreturn 0>
            </cfcatch>
        </cftry>
    </cffunction>

</cfcomponent>
