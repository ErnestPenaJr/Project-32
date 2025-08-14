component {
    property name="dsn" type="string";
    property name="mailService";
    property name="systemManager";
    
    public function init(required string dsn) {
        variables.dsn = arguments.dsn;
        variables.systemManager = createObject("component", "assets.cfc.SystemNotificationManager");
        return this;
    }
    
    public function createNotification(required struct notificationData, boolean forceCreate = false) {
        // Check system permissions if not forcing creation
        if (!arguments.forceCreate) {
            var notificationDecision = variables.systemManager.shouldSendNotification(
                user_id = arguments.notificationData.userId,
                notification_type = arguments.notificationData.type,
                bypass_user_preferences = arguments.notificationData.keyExists("bypassUserPreferences") ? arguments.notificationData.bypassUserPreferences : false
            );
            
            // If neither email nor in-app notifications are allowed, don't create
            if (!notificationDecision.allow_email && !notificationDecision.allow_in_app) {
                return 0; // Return 0 to indicate no notification was created
            }
        }
        
        try {
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
            
            // Update analytics
            if (!arguments.forceCreate) {
                variables.systemManager.updateNotificationAnalytics(
                    notification_type = arguments.notificationData.type,
                    delivery_method = "IN_APP",
                    increment_sent = 1,
                    increment_delivered = 1
                );
            }
            
            return result.generatedKey;
        } catch (any e) {
            // Update failed analytics
            if (!arguments.forceCreate) {
                variables.systemManager.updateNotificationAnalytics(
                    notification_type = arguments.notificationData.type,
                    delivery_method = "IN_APP",
                    increment_sent = 1,
                    increment_failed = 1
                );
            }
            return 0;
        }
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
            // Check if notification should be sent
            var notificationDecision = variables.systemManager.shouldSendNotification(
                user_id = qBooking.USER_ID,
                notification_type = "BOOKING_CONFIRMATION"
            );
            
            // Create in-app notification if allowed
            if (notificationDecision.allow_in_app) {
                var notificationContent = "Your booking for #qBooking.ROOM_NAME# (#qBooking.BUILDING#, Floor #qBooking.FLOOR#) " &
                                        "on #dateTimeFormat(qBooking.START_TIME, 'mm/dd/yyyy h:nn tt')# has been confirmed.";
                
                createNotification({
                    userId: qBooking.USER_ID,
                    type: "BOOKING_CONFIRMATION",
                    content: notificationContent
                }, true); // Force create since we already validated
            }
            
            // Send email notification if allowed
            if (notificationDecision.allow_email) {
                try {
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
                    
                    // Update successful email analytics
                    variables.systemManager.updateNotificationAnalytics(
                        notification_type = "BOOKING_CONFIRMATION",
                        delivery_method = "EMAIL",
                        increment_sent = 1,
                        increment_delivered = 1
                    );
                } catch (any e) {
                    // Update failed email analytics
                    variables.systemManager.updateNotificationAnalytics(
                        notification_type = "BOOKING_CONFIRMATION",
                        delivery_method = "EMAIL",
                        increment_sent = 1,
                        increment_failed = 1
                    );
                }
            }
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
