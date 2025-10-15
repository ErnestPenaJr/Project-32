<!--- 
Admin Test Email API Endpoint
Sends test emails for system verification
 --->

<cfparam name="form.recipient" default="">
<cfparam name="form.type" default="system_test">

<cfset response = structNew()>

<cftry>
    <!--- Validate recipient email --->
    <cfif NOT len(trim(form.recipient)) OR NOT isValid("email", form.recipient)>
        <cfset response.success = false>
        <cfset response.message = "Invalid email address">
        <cfcontent type="application/json; charset=utf-8">
        <cfoutput>#serializeJSON(response)#</cfoutput>
        <cfabort>
    </cfif>
    
    <!--- Get current user info --->
    <cfset currentUser = "System Administrator">
    <cfif structKeyExists(session, "firstName") AND structKeyExists(session, "lastName")>
        <cfset currentUser = session.firstName & " " & session.lastName>
    </cfif>
    
    <!--- Set email subject and body based on type --->
    <cfswitch expression="#form.type#">
        <cfcase value="booking_confirmation">
            <cfset emailSubject = "Test Booking Confirmation - DoCM Room Reservation">
            <cfsavecontent variable="emailBody">
                <html>
                <body style="font-family: Arial, sans-serif; line-height: 1.6; color: ##333;">
                    <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                        <h2 style="color: ##003C7F;">Test Booking Confirmation</h2>
                        <p>This is a test booking confirmation email from the DoCM Room Reservation System.</p>
                        <div style="background: ##f8f9fa; padding: 15px; border-radius: 8px; margin: 20px 0;">
                            <h3>Test Booking Details:</h3>
                            <p><strong>Room:</strong> Test Conference Room</p>
                            <p><strong>Date:</strong> #dateFormat(now(), "mmmm d, yyyy")#</p>
                            <p><strong>Time:</strong> #timeFormat(now(), "h:mm tt")# - #timeFormat(dateAdd("h", 1, now()), "h:mm tt")#</p>
                            <p><strong>Organizer:</strong> #currentUser#</p>
                        </div>
                        <p>This email was sent as a system test by #currentUser# at #dateFormat(now(), "mmmm d, yyyy")# #timeFormat(now(), "h:mm tt")#.</p>
                        <hr style="border: 1px solid ##eee; margin: 20px 0;">
                        <p style="font-size: 12px; color: ##666;">
                            MD Anderson Cancer Center<br>
                            DoCM Room Reservation System
                        </p>
                    </div>
                </body>
                </html>
            </cfsavecontent>
        </cfcase>
        
        <cfcase value="booking_reminder">
            <cfset emailSubject = "Test Booking Reminder - DoCM Room Reservation">
            <cfsavecontent variable="emailBody">
                <html>
                <body style="font-family: Arial, sans-serif; line-height: 1.6; color: ##333;">
                    <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                        <h2 style="color: ##ffc107;">Test Booking Reminder</h2>
                        <p>This is a test booking reminder email from the DoCM Room Reservation System.</p>
                        <div style="background: ##fff3cd; padding: 15px; border-radius: 8px; margin: 20px 0; border-left: 4px solid ##ffc107;">
                            <h3>Upcoming Test Booking:</h3>
                            <p><strong>Room:</strong> Test Conference Room</p>
                            <p><strong>Date:</strong> #dateFormat(dateAdd("d", 1, now()), "mmmm d, yyyy")#</p>
                            <p><strong>Time:</strong> #timeFormat(now(), "h:mm tt")# - #timeFormat(dateAdd("h", 1, now()), "h:mm tt")#</p>
                            <p><strong>Organizer:</strong> #currentUser#</p>
                        </div>
                        <p style="background: ##e7f3ff; padding: 10px; border-radius: 5px;">
                            <strong>Reminder:</strong> Please remember to cancel your booking if you no longer need the room.
                        </p>
                        <p>This email was sent as a system test by #currentUser# at #dateFormat(now(), "mmmm d, yyyy")# #timeFormat(now(), "h:mm tt")#.</p>
                        <hr style="border: 1px solid ##eee; margin: 20px 0;">
                        <p style="font-size: 12px; color: ##666;">
                            MD Anderson Cancer Center<br>
                            DoCM Room Reservation System
                        </p>
                    </div>
                </body>
                </html>
            </cfsavecontent>
        </cfcase>
        
        <cfdefaultcase>
            <cfset emailSubject = "System Test Email - DoCM Room Reservation">
            <cfsavecontent variable="emailBody">
                <html>
                <body style="font-family: Arial, sans-serif; line-height: 1.6; color: ##333;">
                    <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                        <h2 style="color: ##003C7F;">System Test Email</h2>
                        <p>This is a test email to verify that the DoCM Room Reservation System email functionality is working correctly.</p>
                        <div style="background: ##d4edda; padding: 15px; border-radius: 8px; margin: 20px 0; border-left: 4px solid ##28a745;">
                            <h3>Test Details:</h3>
                            <p><strong>Test Type:</strong> System Email Test</p>
                            <p><strong>Sent By:</strong> #currentUser#</p>
                            <p><strong>Date & Time:</strong> #dateFormat(now(), "mmmm d, yyyy")# at #timeFormat(now(), "h:mm:ss tt")#</p>
                            <p><strong>Server:</strong> #cgi.server_name#</p>
                        </div>
                        <p>If you received this email, the notification system is functioning properly.</p>
                        <hr style="border: 1px solid ##eee; margin: 20px 0;">
                        <p style="font-size: 12px; color: ##666;">
                            MD Anderson Cancer Center<br>
                            DoCM Room Reservation System<br>
                            Email Notification Test
                        </p>
                    </div>
                </body>
                </html>
            </cfsavecontent>
        </cfdefaultcase>
    </cfswitch>
    
    <!--- Send the test email --->
    <cfmail 
        to="#form.recipient#"
        from="noreply@mdanderson.org"
        subject="#emailSubject#"
        type="html">
        #emailBody#
    </cfmail>
    
    <!--- Log the test email --->
    <cflog file="docm_test_emails" text="Test email sent to #form.recipient# by #currentUser# (type: #form.type#)">
    
    <cfset response.success = true>
    <cfset response.message = "Test email sent successfully">
    <cfset response.recipient = form.recipient>
    <cfset response.type = form.type>
    <cfset response.timestamp = now()>
    
<cfcatch type="any">
    <cfset response.success = false>
    <cfset response.message = "Error sending test email: " & cfcatch.message>
    <cfset response.detail = cfcatch.detail>
    
    <!--- Log the error --->
    <cflog file="docm_email_errors" text="Test email failed for #form.recipient#: #cfcatch.message#">
</cfcatch>
</cftry>

<!--- Set appropriate content type and return JSON response --->
<cfcontent type="application/json; charset=utf-8">
<cfoutput>#serializeJSON(response)#</cfoutput>