component {
    // Email configuration
    property name="smtpServer" default="smtp.office365.com";
    property name="smtpPort" default="587";
    property name="useSSL" default="true";
    property name="useTLS" default="true";
    property name="emailFrom" default="roomreservation@mdanderson.org";
    property name="emailFromName" default="MD Anderson Room Reservation";

    // Constructor - automatically initialize when component is created
    public function init() {
        // Set default values first
        variables.smtpServer = "smtp.office365.com";
        variables.smtpPort = "587";
        variables.useSSL = "true";
        variables.useTLS = "true";
        variables.emailFrom = "roomreservation@mdanderson.org";
        variables.emailFromName = "MD Anderson Room Reservation";
        
        // Override with Application settings if available.
        //
        // The isDefined("application") guard is required, not cosmetic: this
        // application has no Application.cfc, so the application scope does not
        // exist and a bare structKeyExists(application, ...) throws
        // "Variable APPLICATION is undefined". That throw propagated up through
        // ApprovalNotification.init() and silently killed every new-request
        // approver notification. Falling through to the defaults above is
        // correct -- with no server/port passed to cfmail, ColdFusion uses the
        // mail server configured in the CF Administrator.
        if (isDefined("application") AND structKeyExists(application, "config") AND structKeyExists(application.config, "email")) {
            variables.smtpServer = application.config.email.smtpServer ?: variables.smtpServer;
            variables.smtpPort = application.config.email.smtpPort ?: variables.smtpPort;
            variables.useSSL = application.config.email.useSSL ?: variables.useSSL;
            variables.useTLS = application.config.email.useTLS ?: variables.useTLS;
            variables.emailFrom = application.config.email.from ?: variables.emailFrom;
            variables.emailFromName = application.config.email.fromName ?: variables.emailFromName;
        }
        
        return this;
    }

    // Send booking confirmation email
    public boolean function sendBookingConfirmation(required struct booking, required struct user) {
        var subject = "Room Booking Confirmation - #booking.roomName#";
        var template = "emails/booking-confirmation.cfm";
        
        var emailArgs = {
            booking = arguments.booking,
            user = arguments.user
        };
        
        return sendEmail(
            to = user.email,
            toName = user.firstName & " " & user.lastName,
            subject = subject,
            template = template,
            args = emailArgs
        );
    }

    // Send booking cancellation email
    public boolean function sendBookingCancellation(required struct booking, required struct user) {
        var subject = "Room Booking Cancellation - #booking.roomName#";
        var template = "emails/booking-cancellation.cfm";
        
        var emailArgs = {
            booking = arguments.booking,
            user = arguments.user
        };
        
        return sendEmail(
            to = user.email,
            toName = user.firstName & " " & user.lastName,
            subject = subject,
            template = template,
            args = emailArgs
        );
    }

    // Send booking reminder email
    public boolean function sendBookingReminder(required struct booking, required struct user) {
        var subject = "Upcoming Room Booking Reminder - #booking.roomName#";
        var template = "emails/booking-reminder.cfm";
        
        var emailArgs = {
            booking = arguments.booking,
            user = arguments.user
        };
        
        return sendEmail(
            to = user.email,
            toName = user.firstName & " " & user.lastName,
            subject = subject,
            template = template,
            args = emailArgs
        );
    }

    // Send password reset email
    public boolean function sendPasswordReset(required string email, required string resetToken) {
        var subject = "Password Reset Request - MD Anderson Room Reservation";
        var template = "emails/password-reset.cfm";
        
        var emailArgs = {
            resetToken = arguments.resetToken,
            resetUrl = "#application.config.baseUrl#/reset-password.html?token=#arguments.resetToken#"
        };
        
        return sendEmail(
            to = arguments.email,
            toName = "",
            subject = subject,
            template = template,
            args = emailArgs
        );
    }

    // Send booking revision notification email
    public boolean function sendBookingRevisionNotification(required numeric bookingId) {
        try {
            // Get database configuration
            if (listFirst(CGI.SERVER_NAME, '.') EQ 'cmapps') {
                var DBSERVER = "inside2_docmp";
                var DBUSER = "CONFROOM_USER";
                var DBPASS = "1DOCMAU4CNFRM6";
                var DBSCHEMA = "CONFROOM";
            } else if (listFirst(CGI.SERVER_NAME, '.') EQ 's-cmapps') {
                var DBSERVER = "inside2_docms";
                var DBUSER = "CONFROOM";
                var DBPASS = "1DOCMOA4CNFRM3";
                var DBSCHEMA = "CONFROOM";
            } else {
                var DBSERVER = "inside2_docmd";
                var DBUSER = "CONFROOM";
                var DBPASS = "1DOCMOA4CNFRM3";
                var DBSCHEMA = "CONFROOM";
            }

            // Get the current booking details
            var qGetBooking = queryExecute("
                SELECT
                    b.BOOKING_ID,
                    b.USER_ID,
                    b.ROOM_ID,
                    b.START_TIME,
                    b.END_TIME,
                    b.COMMENTS,
                    b.STATUS,
                    b.REVISION_NUMBER,
                    b.REVISION_DATE,
                    b.MODIFIED_BY,
                    u.FIRST_NAME as USER_FIRST_NAME,
                    u.LAST_NAME as USER_LAST_NAME,
                    u.EMAIL as USER_EMAIL,
                    r.ROOM_NAME,
                    r.BUILDING,
                    r.ROOM_NUMBER,
                    m.FIRST_NAME as MODIFIER_FIRST_NAME,
                    m.LAST_NAME as MODIFIER_LAST_NAME
                FROM #DBSCHEMA#.BOOKINGS b
                JOIN #DBSCHEMA#.USERS u ON b.USER_ID = u.USER_ID
                JOIN #DBSCHEMA#.ROOMS r ON b.ROOM_ID = r.ROOM_ID
                LEFT JOIN #DBSCHEMA#.USERS m ON b.MODIFIED_BY = m.USER_ID
                WHERE b.BOOKING_ID = :bookingId
            ", {
                bookingId = {value = arguments.bookingId, cfsqltype = "cf_sql_numeric"}
            }, {
                datasource = DBSERVER,
                username = DBUSER,
                password = DBPASS
            });

            if (qGetBooking.recordCount EQ 0) {
                writeLog(
                    type = "error",
                    text = "Booking not found for revision notification: #arguments.bookingId#",
                    application = "yes"
                );
                return false;
            }

            // Get the original booking details from revision history or previous state
            // For now, we'll use a simple approach - in a full implementation, you'd query revision history
            var qGetOriginal = queryExecute("
                SELECT
                    b.BOOKING_ID,
                    b.ROOM_ID,
                    b.START_TIME,
                    b.END_TIME,
                    b.COMMENTS,
                    r.ROOM_NAME,
                    r.BUILDING,
                    r.ROOM_NUMBER
                FROM #DBSCHEMA#.BOOKINGS b
                JOIN #DBSCHEMA#.ROOMS r ON b.ROOM_ID = r.ROOM_ID
                WHERE b.BOOKING_ID = :bookingId
                AND b.REVISION_NUMBER = :revisionNum
            ", {
                bookingId = {value = arguments.bookingId, cfsqltype = "cf_sql_numeric"},
                revisionNum = {value = max(0, qGetBooking.REVISION_NUMBER - 1), cfsqltype = "cf_sql_numeric"}
            }, {
                datasource = DBSERVER,
                username = DBUSER,
                password = DBPASS
            });

            // If no previous revision exists, use current values as fallback
            if (qGetOriginal.recordCount EQ 0) {
                qGetOriginal = qGetBooking;
            }

            // Prepare email data structures
            var booking = {
                bookingId = qGetBooking.BOOKING_ID,
                roomId = qGetBooking.ROOM_ID,
                roomName = qGetBooking.ROOM_NAME,
                building = qGetBooking.BUILDING,
                roomNumber = qGetBooking.ROOM_NUMBER,
                startTime = qGetBooking.START_TIME,
                endTime = qGetBooking.END_TIME,
                comments = qGetBooking.COMMENTS,
                status = qGetBooking.STATUS,
                revisionNumber = qGetBooking.REVISION_NUMBER,
                revisionDate = qGetBooking.REVISION_DATE
            };

            var original = {
                roomId = qGetOriginal.ROOM_ID,
                roomName = qGetOriginal.ROOM_NAME,
                building = qGetOriginal.BUILDING,
                roomNumber = qGetOriginal.ROOM_NUMBER,
                startTime = qGetOriginal.START_TIME,
                endTime = qGetOriginal.END_TIME,
                comments = qGetOriginal.COMMENTS
            };

            var user = {
                firstName = qGetBooking.USER_FIRST_NAME,
                lastName = qGetBooking.USER_LAST_NAME,
                email = qGetBooking.USER_EMAIL
            };

            var modifiedBy = {
                firstName = qGetBooking.MODIFIER_FIRST_NAME ?: "System",
                lastName = qGetBooking.MODIFIER_LAST_NAME ?: "Administrator"
            };

            var subject = "Booking Revision Notice - #booking.roomName# (Revision ###booking.revisionNumber#)";
            var template = "views/emails/booking-revision.cfm";

            var emailArgs = {
                booking = booking,
                original = original,
                user = user,
                modifiedBy = modifiedBy
            };

            return sendEmail(
                to = user.email,
                toName = user.firstName & " " & user.lastName,
                subject = subject,
                template = template,
                args = emailArgs
            );
        }
        catch (any e) {
            writeLog(
                type = "error",
                text = "Error sending booking revision notification for booking #arguments.bookingId#: #e.message# #e.detail#",
                application = "yes"
            );
            return false;
        }
    }

    // Send test email
    remote struct function sendTestEmail(required string recipient, string type = "system_test") returnformat="json" {
        // Ensure init() has been called (remote invocations skip the constructor)
        if (!structKeyExists(variables, "emailFrom")) {
            init();
        }
        try {
            var subject = "Test Email - DoCM Room Reservation System";
            var testContent = "
                <h2>Test Email Notification</h2>
                <p>This is a test email from the DoCM Room Reservation System.</p>
                <p>If you received this email, the email notification system is working correctly.</p>
                <p><strong>Test Details:</strong></p>
                <ul>
                    <li>Test Time: #dateTimeFormat(now(), 'mmm d, yyyy h:nn:ss tt')#</li>
                    <li>Test Type: #arguments.type#</li>
                    <li>Recipient: #arguments.recipient#</li>
                </ul>
                <p>Thank you for using the DoCM Room Reservation System.</p>
            ";

            // Send email using ColdFusion mail
            cfmail(
                to = arguments.recipient,
                from = variables.emailFrom,
                subject = subject,
                type = "html"
            ) {
                writeOutput(testContent);
            }
            
            // Log successful test email
            writeLog(
                type = "information",
                text = "Test email sent successfully to #arguments.recipient#",
                application = "yes"
            );
            
            return {
                "success" = true,
                "message" = "Test email sent successfully",
                "recipient" = arguments.recipient,
                "type" = arguments.type,
                "timestamp" = now()
            };
        }
        catch (any e) {
            // Log error
            writeLog(
                type = "error",
                text = "Test email sending failed to #arguments.recipient#: #e.message# #e.detail#",
                application = "yes"
            );
            
            return {
                "success" = false,
                "message" = "Error sending test email: " & e.message,
                "detail" = e.detail,
                "recipient" = arguments.recipient,
                "type" = arguments.type,
                "timestamp" = now()
            };
        }
    }

    // Core email sending function
    // Public because this component is used by composition, not inheritance:
    // ApprovalNotification holds an EmailService instance and calls this
    // directly. While it was private that call failed with "Neither the method
    // sendEmail was found in component components.EmailService", so no approval
    // email could ever be sent.
    public boolean function sendEmail(
        required string to,
        required string toName,
        required string subject,
        required string template,
        struct args = {}
    ) {
        try {
            // Resolve the template against the application root. A bare relative
            // include resolves against the *including* template's directory --
            // that is components/, where views/emails/ does not exist -- so the
            // include failed for every caller outside this directory.
            var templatePath = arguments.template;
            if (left(templatePath, 1) NEQ "/") {
                templatePath = "/" & listFirst(cgi.script_name, "/") & "/" & templatePath;
            }

            if (!fileExists(expandPath(templatePath))) {
                writeLog(
                    type = "error",
                    file = "approval_notifications",
                    text = "Email template not found: #templatePath# (requested as '#arguments.template#')"
                );
                return false;
            }

            // Generate email content from template
            savecontent variable="emailContent" {
                include templatePath;
            }

            // Send email using ColdFusion mail
            cfmail(
                to = arguments.to,
                from = variables.emailFrom,
                subject = arguments.subject,
                type = "html"
            ) {
                writeOutput(emailContent);
            }
            
            // Log successful email
            writeLog(
                type = "information",
                text = "Email sent successfully to #arguments.to#: #arguments.subject#",
                application = "yes"
            );
            
            return true;
        }
        catch (any e) {
            // Log error
            writeLog(
                type = "error",
                text = "Email sending failed to #arguments.to#: #e.message# #e.detail#",
                application = "yes"
            );
            
            return false;
        }
    }
}
