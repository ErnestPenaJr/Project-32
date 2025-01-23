component {
    // Email configuration
    property name="smtpServer" default="smtp.office365.com";
    property name="smtpPort" default="587";
    property name="useSSL" default="true";
    property name="useTLS" default="true";
    property name="emailFrom" default="roomreservation@mdanderson.org";
    property name="emailFromName" default="MD Anderson Room Reservation";

    // Initialize email settings
    public void function init() {
        // Load email configuration from Application settings
        variables.smtpServer = application.config.email.smtpServer ?: variables.smtpServer;
        variables.smtpPort = application.config.email.smtpPort ?: variables.smtpPort;
        variables.useSSL = application.config.email.useSSL ?: variables.useSSL;
        variables.useTLS = application.config.email.useTLS ?: variables.useTLS;
        variables.emailFrom = application.config.email.from ?: variables.emailFrom;
        variables.emailFromName = application.config.email.fromName ?: variables.emailFromName;
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

    // Core email sending function
    private boolean function sendEmail(
        required string to,
        required string toName,
        required string subject,
        required string template,
        struct args = {}
    ) {
        try {
            // Generate email content from template
            savecontent variable="emailContent" {
                include template=arguments.template;
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
