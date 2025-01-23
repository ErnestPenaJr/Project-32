<cfcomponent>
    <!--- Database configuration based on server environment --->
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

    <!--- Get all notifications for a user --->
    <cffunction name="get_user_notifications" access="remote" returntype="query" returnformat="json">
        <cfargument name="user_id" type="string" required="true">
        
        <cfquery name="qGetNotifications" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
            SELECT 
                NOTIFICATION_ID,
                USER_ID,
                TYPE,
                CONTENT,
                STATUS
            FROM #this.DBSCHEMA#.NOTIFICATIONS
            WHERE USER_ID = <cfqueryparam value="#arguments.user_id#" cfsqltype="cf_sql_varchar">
            ORDER BY CREATED_AT DESC
        </cfquery>
        
        <cfreturn qGetNotifications>
    </cffunction>

    <!--- Create a new notification --->
    <cffunction name="create_notification" access="remote" returntype="boolean" returnformat="json">
        <cfargument name="user_id" type="string" required="true">
        <cfargument name="notification_type" type="string" required="true">
        <cfargument name="notification_message" type="string" required="true">
        
        <cftry>
            <cfquery datasource="#this.DBSERVER#">
                INSERT INTO notifications (
                    user_id,
                    notification_type,
                    notification_message,
                    is_read,
                    created_date,
                    modified_date
                ) VALUES (
                    <cfqueryparam value="#arguments.user_id#" cfsqltype="cf_sql_numeric">,
                    <cfqueryparam value="#arguments.notification_type#" cfsqltype="cf_sql_varchar">,
                    <cfqueryparam value="#arguments.notification_message#" cfsqltype="cf_sql_varchar">,
                    0,
                    CURRENT_TIMESTAMP,
                    CURRENT_TIMESTAMP
                )
            </cfquery>
            <cfreturn true>
            <cfcatch>
                <cfreturn false>
            </cfcatch>
        </cftry>
    </cffunction>

    <!--- Mark notification as read --->
    <cffunction name="mark_notification_read" access="remote" returntype="boolean" returnformat="json">
        <cfargument name="notification_id" type="numeric" required="true">
        
        <cftry>
            <cfquery datasource="#this.DBSERVER#">
                UPDATE notifications
                SET 
                    is_read = 1,
                    modified_date = CURRENT_TIMESTAMP
                WHERE notification_id = <cfqueryparam value="#arguments.notification_id#" cfsqltype="cf_sql_numeric">
            </cfquery>
            <cfreturn true>
            <cfcatch>
                <cfreturn false>
            </cfcatch>
        </cftry>
    </cffunction>

    <!--- Delete a notification --->
    <cffunction name="delete_notification" access="remote" returntype="boolean" returnformat="json">
        <cfargument name="notification_id" type="numeric" required="true">
        <cfargument name="user_id" type="numeric" required="true">
        
        <cftry>
            <cfquery datasource="#this.DBSERVER#">
                DELETE FROM notifications
                WHERE notification_id = <cfqueryparam value="#arguments.notification_id#" cfsqltype="cf_sql_numeric">
                AND user_id = <cfqueryparam value="#arguments.user_id#" cfsqltype="cf_sql_numeric">
            </cfquery>
            <cfreturn true>
            <cfcatch>
                <cfreturn false>
            </cfcatch>
        </cftry>
    </cffunction>

    <!--- Get unread notification count --->
    <cffunction name="get_unread_count" access="remote" returntype="numeric" returnformat="json">
        <cfargument name="user_id" type="numeric" required="true">
        
        <cfquery name="qUnreadCount" datasource="#this.DBSERVER#">
            SELECT COUNT(*) as unread_count
            FROM notifications
            WHERE user_id = <cfqueryparam value="#arguments.user_id#" cfsqltype="cf_sql_numeric">
            AND is_read = 0
        </cfquery>
        
        <cfreturn qUnreadCount.unread_count>
    </cffunction>

    <!--- Mark all notifications as read for a user --->
    <cffunction name="mark_all_read" access="remote" returntype="boolean" returnformat="json">
        <cfargument name="user_id" type="numeric" required="true">
        
        <cftry>
            <cfquery datasource="#this.DBSERVER#">
                UPDATE notifications
                SET 
                    is_read = 1,
                    modified_date = CURRENT_TIMESTAMP
                WHERE user_id = <cfqueryparam value="#arguments.user_id#" cfsqltype="cf_sql_numeric">
                AND is_read = 0
            </cfquery>
            <cfreturn true>
            <cfcatch>
                <cfreturn false>
            </cfcatch>
        </cftry>
    </cffunction>

    <!--- Get recent notifications with pagination --->
    <cffunction name="get_recent_notifications" access="remote" returntype="query" returnformat="json">
        <cfargument name="user_id" type="numeric" required="true">
        <cfargument name="page_size" type="numeric" required="false" default="10">
        <cfargument name="page_number" type="numeric" required="false" default="1">
        
        <cfset local.offset = (arguments.page_number - 1) * arguments.page_size>
        
        <cfquery name="qRecentNotifications" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
            SELECT 
                NOTIFICATION_ID,
                USER_ID,
                TYPE,
                CONTENT,
                STATUS
            FROM #this.DBSCHEMA#.NOTIFICATIONS
            WHERE USER_ID = <cfqueryparam value="#arguments.user_id#" cfsqltype="cf_sql_numeric">
            ORDER BY CREATED_AT DESC
            OFFSET <cfqueryparam value="#local.offset#" cfsqltype="cf_sql_integer">
            ROWS FETCH NEXT <cfqueryparam value="#arguments.page_size#" cfsqltype="cf_sql_integer"> ROWS ONLY
        </cfquery>
        
        <cfreturn qRecentNotifications>
    </cffunction>

    <!--- Send booking reminder notification --->
    <cffunction name="sendBookingReminder" access="remote" returntype="boolean" returnformat="json">
        <cfargument name="booking_id" type="numeric" required="true">
        
        <cftry>
            <!--- Get booking details --->
            <cfquery name="qGetBooking" datasource="#this.DBSERVER#">
                SELECT 
                    b.booking_id,
                    b.user_id,
                    b.start_time,
                    b.end_time,
                    b.room_id,
                    r.room_name,
                    u.email,
                    u.first_name,
                    u.last_name
                FROM bookings b
                INNER JOIN rooms r ON b.room_id = r.room_id
                INNER JOIN users u ON b.user_id = u.user_id
                WHERE b.booking_id = <cfqueryparam value="#arguments.booking_id#" cfsqltype="cf_sql_numeric">
            </cfquery>

            <!--- Send email notification --->
            <cfif qGetBooking.recordCount>
                <cfmail 
                    to="#qGetBooking.email#"
                    from="noreply@company.com"
                    subject="Upcoming Booking Reminder"
                    type="html">
                    <cfoutput>
                    <h2>Booking Reminder</h2>
                    <p>Dear #qGetBooking.first_name# #qGetBooking.last_name#,</p>
                    <p>This is a reminder for your upcoming booking:</p>
                    <ul>
                        <li>Room: #qGetBooking.room_name#</li>
                        <li>Start Time: #DateTimeFormat(qGetBooking.start_time, "mmm d, yyyy h:nn tt")#</li>
                        <li>End Time: #DateTimeFormat(qGetBooking.end_time, "mmm d, yyyy h:nn tt")#</li>
                    </ul>
                    <p>Thank you for using our booking system.</p>
                    </cfoutput>
                </cfmail>

                <!--- Create notification record --->
                <cfset createNotification(
                    user_id = qGetBooking.user_id,
                    notification_type = "BOOKING_REMINDER",
                    notification_message = "Reminder: You have an upcoming booking in #qGetBooking.room_name# at #DateTimeFormat(qGetBooking.start_time, 'h:nn tt')#"
                )>
                
                <cfreturn true>
            </cfif>
            
            <cfcatch>
                <cfreturn false>
            </cfcatch>
        </cftry>
    </cffunction>

    <!--- Send booking end reminder notification --->
    <cffunction name="sendBookingEndReminder" access="remote" returntype="boolean" returnformat="json">
        <cfargument name="booking_id" type="numeric" required="true">
        
        <cftry>
            <!--- Get booking details --->
            <cfquery name="qGetBooking" datasource="#this.DBSERVER#">
                SELECT 
                    b.booking_id,
                    b.user_id,
                    b.start_time,
                    b.end_time,
                    b.room_id,
                    r.room_name,
                    u.email,
                    u.first_name,
                    u.last_name
                FROM bookings b
                INNER JOIN rooms r ON b.room_id = r.room_id
                INNER JOIN users u ON b.user_id = u.user_id
                WHERE b.booking_id = <cfqueryparam value="#arguments.booking_id#" cfsqltype="cf_sql_numeric">
            </cfquery>

            <!--- Send email notification --->
            <cfif qGetBooking.recordCount>
                <cfmail 
                    to="#qGetBooking.email#"
                    from="noreply@company.com"
                    subject="Booking End Reminder"
                    type="html">
                    <cfoutput>
                    <h2>Booking End Reminder</h2>
                    <p>Dear #qGetBooking.first_name# #qGetBooking.last_name#,</p>
                    <p>Your booking will end in one hour:</p>
                    <ul>
                        <li>Room: #qGetBooking.room_name#</li>
                        <li>End Time: #DateTimeFormat(qGetBooking.end_time, "mmm d, yyyy h:nn tt")#</li>
                    </ul>
                    <p>Please ensure you wrap up your meeting on time to allow for the next booking.</p>
                    </cfoutput>
                </cfmail>

                <!--- Create notification record --->
                <cfset createNotification(
                    user_id = qGetBooking.user_id,
                    notification_type = "BOOKING_END_REMINDER",
                    notification_message = "Your booking in #qGetBooking.room_name# will end at #DateTimeFormat(qGetBooking.end_time, 'h:nn tt')#"
                )>
                
                <cfreturn true>
            </cfif>
            
            <cfcatch>
                <cfreturn false>
            </cfcatch>
        </cftry>
    </cffunction>

    <!--- Check and send notifications for upcoming bookings --->
    <cffunction name="checkAndSendNotifications" access="remote" returntype="void">
        <!--- Get upcoming bookings that need notifications --->
        <cfquery name="qUpcomingBookings" datasource="#this.DBSERVER#">
            SELECT 
                booking_id,
                start_time,
                end_time
            FROM bookings
            WHERE start_time > CURRENT_TIMESTAMP
            AND start_time <= DATEADD(hour, 24, CURRENT_TIMESTAMP)
            AND notification_sent = 0
        </cfquery>

        <!--- Send notifications for upcoming bookings --->
        <cfloop query="qUpcomingBookings">
            <cfset sendBookingReminder(booking_id)>
            
            <!--- Update notification sent status --->
            <cfquery datasource="#this.DBSERVER#">
                UPDATE bookings
                SET notification_sent = 1
                WHERE booking_id = <cfqueryparam value="#booking_id#" cfsqltype="cf_sql_numeric">
            </cfquery>
        </cfloop>

        <!--- Get bookings ending in one hour --->
        <cfquery name="qEndingBookings" datasource="#this.DBSERVER#">
            SELECT 
                booking_id,
                end_time
            FROM bookings
            WHERE end_time > CURRENT_TIMESTAMP
            AND end_time <= DATEADD(hour, 1, CURRENT_TIMESTAMP)
            AND end_notification_sent = 0
        </cfquery>

        <!--- Send notifications for ending bookings --->
        <cfloop query="qEndingBookings">
            <cfset sendBookingEndReminder(booking_id)>
            
            <!--- Update end notification sent status --->
            <cfquery datasource="#this.DBSERVER#">
                UPDATE bookings
                SET end_notification_sent = 1
                WHERE booking_id = <cfqueryparam value="#booking_id#" cfsqltype="cf_sql_numeric">
            </cfquery>
        </cfloop>
    </cffunction>

</cfcomponent>
