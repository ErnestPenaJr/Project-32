component {
    property name="dsn" type="string";
    property name="mailService";
    
    public function init(required string dsn) {
        variables.dsn = arguments.dsn;
        return this;
    }
    
    public function createNotification(required struct notificationData) {
        var qCreate = queryExecute(
            "INSERT INTO NOTIFICATIONS (USER_ID, TYPE, CONTENT, STATUS) 
             VALUES (:userId, :type, :content, :status)
             RETURNING NOTIFICATION_ID INTO :generatedId",
            {
                userId = {value=arguments.notificationData.userId, cfsqltype="cf_sql_numeric"},
                type = {value=arguments.notificationData.type, cfsqltype="cf_sql_varchar"},
                content = {value=arguments.notificationData.content, cfsqltype="cf_sql_varchar"},
                status = {value='Unread', cfsqltype="cf_sql_varchar"},
                generatedId = {type="out", variable="newNotificationId", cfsqltype="cf_sql_numeric"}
            },
            {datasource=variables.dsn, result="result"}
        );
        return result.generatedKey;
    }
    
    public function getUserNotifications(required numeric userId, string status = "") {
        var sql = "SELECT n.*, u.EMAIL, u.FIRST_NAME, u.LAST_NAME
                  FROM NOTIFICATIONS n
                  JOIN USERS u ON n.USER_ID = u.USER_ID
                  WHERE n.USER_ID = :userId ";
        var params = {
            userId = {value=arguments.userId, cfsqltype="cf_sql_numeric"}
        };
        
        if (len(arguments.status)) {
            sql &= "AND n.STATUS = :status ";
            params.status = {value=arguments.status, cfsqltype="cf_sql_varchar"};
        }
        
        sql &= "ORDER BY n.CREATED_AT DESC";
        
        var qNotifications = queryExecute(sql, params, {datasource=variables.dsn});
        return qNotifications;
    }
    
    public function markAsRead(required numeric notificationId, required numeric userId) {
        queryExecute(
            "UPDATE NOTIFICATIONS 
             SET STATUS = 'Read'
             WHERE NOTIFICATION_ID = :notificationId
             AND USER_ID = :userId",
            {
                notificationId = {value=arguments.notificationId, cfsqltype="cf_sql_numeric"},
                userId = {value=arguments.userId, cfsqltype="cf_sql_numeric"}
            },
            {datasource=variables.dsn}
        );
        return true;
    }
    
    public function sendBookingConfirmation(required numeric bookingId) {
        var qBooking = queryExecute(
            "SELECT b.*, r.ROOM_NAME, r.BUILDING, r.FLOOR,
                    u.USER_ID, u.EMAIL, u.FIRST_NAME, u.LAST_NAME
             FROM BOOKINGS b
             JOIN ROOMS r ON b.ROOM_ID = r.ROOM_ID
             JOIN USERS u ON b.USER_ID = u.USER_ID
             WHERE b.BOOKING_ID = :bookingId",
            {bookingId = {value=arguments.bookingId, cfsqltype="cf_sql_numeric"}},
            {datasource=variables.dsn}
        );
        
        if (qBooking.recordCount) {
            // Create in-app notification
            var notificationContent = "Your booking for #qBooking.ROOM_NAME# (#qBooking.BUILDING#, Floor #qBooking.FLOOR#) " &
                                    "on #dateTimeFormat(qBooking.START_TIME, 'mm/dd/yyyy h:nn tt')# has been confirmed.";
            
            createNotification({
                userId: qBooking.USER_ID,
                type: "BOOKING_CONFIRMATION",
                content: notificationContent
            });
            
            // Send email notification
            var emailBody = "
                <h2>Booking Confirmation</h2>
                <p>Dear #qBooking.FIRST_NAME#,</p>
                <p>Your room booking has been confirmed with the following details:</p>
                <ul>
                    <li>Room: #qBooking.ROOM_NAME#</li>
                    <li>Building: #qBooking.BUILDING#</li>
                    <li>Floor: #qBooking.FLOOR#</li>
                    <li>Date: #dateFormat(qBooking.START_TIME, 'mmm dd, yyyy')#</li>
                    <li>Time: #timeFormat(qBooking.START_TIME, 'h:nn tt')# - #timeFormat(qBooking.END_TIME, 'h:nn tt')#</li>
                </ul>
                <p>Thank you for using our room reservation system.</p>
            ";
            
            sendEmail(qBooking.EMAIL, "Room Booking Confirmation", emailBody);
        }
    }
    
    public function sendBookingCancellation(required numeric bookingId) {
        var qBooking = queryExecute(
            "SELECT b.*, r.ROOM_NAME, r.BUILDING, r.FLOOR,
                    u.USER_ID, u.EMAIL, u.FIRST_NAME, u.LAST_NAME
             FROM BOOKINGS b
             JOIN ROOMS r ON b.ROOM_ID = r.ROOM_ID
             JOIN USERS u ON b.USER_ID = u.USER_ID
             WHERE b.BOOKING_ID = :bookingId",
            {bookingId = {value=arguments.bookingId, cfsqltype="cf_sql_numeric"}},
            {datasource=variables.dsn}
        );
        
        if (qBooking.recordCount) {
            // Create in-app notification
            var notificationContent = "Your booking for #qBooking.ROOM_NAME# (#qBooking.BUILDING#, Floor #qBooking.FLOOR#) " &
                                    "on #dateTimeFormat(qBooking.START_TIME, 'mm/dd/yyyy h:nn tt')# has been cancelled.";
            
            createNotification({
                userId: qBooking.USER_ID,
                type: "BOOKING_CANCELLATION",
                content: notificationContent
            });
            
            // Send email notification
            var emailBody = "
                <h2>Booking Cancellation</h2>
                <p>Dear #qBooking.FIRST_NAME#,</p>
                <p>Your room booking has been cancelled:</p>
                <ul>
                    <li>Room: #qBooking.ROOM_NAME#</li>
                    <li>Building: #qBooking.BUILDING#</li>
                    <li>Floor: #qBooking.FLOOR#</li>
                    <li>Date: #dateFormat(qBooking.START_TIME, 'mmm dd, yyyy')#</li>
                    <li>Time: #timeFormat(qBooking.START_TIME, 'h:nn tt')# - #timeFormat(qBooking.END_TIME, 'h:nn tt')#</li>
                </ul>
                <p>If you did not cancel this booking, please contact the system administrator.</p>
            ";
            
            sendEmail(qBooking.EMAIL, "Room Booking Cancellation", emailBody);
        }
    }
    
    private function sendEmail(required string to, required string subject, required string body) {
        // Implementation depends on your email service configuration
        cfmail(
            to = arguments.to,
            from = "roomreservation@mdanderson.org",
            subject = arguments.subject,
            type = "html"
        ) {
            writeOutput(arguments.body);
        }
    }
}
