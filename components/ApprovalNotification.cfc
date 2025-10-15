component {
    property name="dsn" type="string";
    property name="emailService";
    property name="notificationService";
    property name="systemManager";

    public function init(required string dsn) {
        variables.dsn = arguments.dsn;
        variables.emailService = createObject("component", "components.EmailService").init();
        variables.notificationService = createObject("component", "components.Notification").init(arguments.dsn);
        variables.systemManager = createObject("component", "assets.cfc.SystemNotificationManager");
        return this;
    }

    public struct function sendPendingApprovalAlert(required struct bookingDetails) {
        var response = {
            success: false,
            recipients: [],
            emailSent: 0,
            inAppCreated: 0,
            skipped: 0
        };

        var recipients = getApprovalRecipients("BOOKING_PENDING_APPROVAL", false);

        if (!arrayLen(recipients)) {
            return response;
        }

        for (var admin in recipients) {
            var decision = variables.systemManager.shouldSendNotification(
                user_id = admin.USER_ID,
                notification_type = "BOOKING_PENDING_APPROVAL"
            );

            if (!decision.allow_email && !decision.allow_in_app) {
                response.skipped++;
                continue;
            }

            var approvalPrefs = variables.systemManager.getApprovalNotificationPreferences(admin.USER_ID);

            if (approvalPrefs.mode NEQ "immediate") {
                response.skipped++;
                continue;
            }

            if (decision.allow_email && admin.EMAIL_ENABLED EQ 1 && approvalPrefs.enabled) {
                if (sendApprovalEmail(admin, arguments.bookingDetails)) {
                    response.emailSent++;
                }
            }

            if (decision.allow_in_app && admin.IN_APP_ENABLED EQ 1 && approvalPrefs.enabled) {
                var notificationId = variables.notificationService.createNotification({
                    userId: admin.USER_ID,
                    type: "BOOKING_PENDING_APPROVAL",
                    content: buildInAppMessage(arguments.bookingDetails)
                }, true);

                if (notificationId) {
                    response.inAppCreated++;
                }
            }

            arrayAppend(response.recipients, admin.USER_ID);
        }

        response.success = (response.emailSent + response.inAppCreated) GT 0;
        return response;
    }

    public struct function sendApprovalDigest(required array pendingApprovals, date runDate = now()) {
        var response = {
            success: false,
            recipients: [],
            emailSent: 0,
            skipped: 0
        };

        if (!arrayLen(arguments.pendingApprovals)) {
            return response;
        }

        var recipients = getApprovalRecipients("BOOKING_PENDING_APPROVAL_DIGEST", true);

        if (!arrayLen(recipients)) {
            return response;
        }

        for (var admin in recipients) {
            var decision = variables.systemManager.shouldSendNotification(
                user_id = admin.USER_ID,
                notification_type = "BOOKING_PENDING_APPROVAL_DIGEST"
            );

            if (!decision.allow_email || admin.EMAIL_ENABLED EQ 0) {
                response.skipped++;
                continue;
            }

            var approvalPrefs = variables.systemManager.getApprovalNotificationPreferences(admin.USER_ID, false, "digest");

            if (!approvalPrefs.enabled || approvalPrefs.mode NEQ "digest") {
                response.skipped++;
                continue;
            }

            if (sendDigestEmail(admin, arguments.pendingApprovals, arguments.runDate)) {
                response.emailSent++;
                arrayAppend(response.recipients, admin.USER_ID);
            }
        }

        response.success = response.emailSent GT 0;
        return response;
    }

    private array function getApprovalRecipients(required string typeCode, boolean isDigest) {
        var recipients = [];

        var sql = "
            SELECT
                u.USER_ID,
                u.EMAIL,
                u.FIRST_NAME,
                u.LAST_NAME,
                NVL(np.EMAIL_ENABLED, t.DEFAULT_EMAIL_ENABLED) AS EMAIL_ENABLED,
                NVL(np.IN_APP_ENABLED, t.DEFAULT_IN_APP_ENABLED) AS IN_APP_ENABLED
            FROM USERS u
            JOIN NOTIFICATION_TYPES t ON t.TYPE_CODE = :typeCode
            LEFT JOIN NOTIFICATION_PREFERENCES np
              ON np.USER_ID = u.USER_ID
             AND np.NOTIFICATION_TYPE = t.TYPE_CODE
            WHERE UPPER(u.STATUS) = 'ACTIVE'
              AND UPPER(u.ROLE) IN ('ADMIN','SITE ADMIN')
        ";

        var params = {
            typeCode: { value = arguments.typeCode, cfsqltype = "cf_sql_varchar" }
        };

        var qRecipients = queryExecute(sql, params, { datasource = variables.dsn });

        for (var row in qRecipients) {
            arrayAppend(recipients, row);
        }

        return recipients;
    }

    private boolean function sendApprovalEmail(required struct admin, required struct bookingDetails) {
        var templateArgs = {
            admin = arguments.admin,
            booking = arguments.bookingDetails,
            approveUrl = buildActionUrl(arguments.bookingDetails.bookingId, "approve"),
            rejectUrl = buildActionUrl(arguments.bookingDetails.bookingId, "reject"),
            detailUrl = buildDetailUrl(arguments.bookingDetails.bookingId)
        };

        return variables.emailService.sendEmail(
            to = arguments.admin.EMAIL,
            toName = arguments.admin.FIRST_NAME & " " & arguments.admin.LAST_NAME,
            subject = "Booking Approval Needed - " & arguments.bookingDetails.roomName,
            template = "views/emails/approval-notification.cfm",
            args = templateArgs
        );
    }

    private boolean function sendDigestEmail(required struct admin, required array pendingApprovals, required date runDate) {
        var templateArgs = {
            admin = arguments.admin,
            pendingApprovals = arguments.pendingApprovals,
            runDate = arguments.runDate,
            detailBaseUrl = buildDetailUrl(0)
        };

        return variables.emailService.sendEmail(
            to = arguments.admin.EMAIL,
            toName = arguments.admin.FIRST_NAME & " " & arguments.admin.LAST_NAME,
            subject = "Pending Approvals Digest - " & dateFormat(arguments.runDate, "mmmm dd, yyyy"),
            template = "views/emails/approval-digest.cfm",
            args = templateArgs
        );
    }

    private string function buildInAppMessage(required struct bookingDetails) {
        return "Approval needed: " &
            arguments.bookingDetails.roomName &
            " on " & dateFormat(arguments.bookingDetails.startTime, "mmm dd, yyyy") &
            " at " & timeFormat(arguments.bookingDetails.startTime, "h:nn tt");
    }

    private string function buildActionUrl(required numeric bookingId, required string action) {
        var baseUrl = structKeyExists(application, "config") AND structKeyExists(application.config, "baseUrl")
            ? application.config.baseUrl
            : "";
        return baseUrl & "/admin/booking-action.cfm?bookingId=" & arguments.bookingId & "&action=" & arguments.action;
    }

    private string function buildDetailUrl(numeric bookingId) {
        var baseUrl = structKeyExists(application, "config") AND structKeyExists(application.config, "baseUrl")
            ? application.config.baseUrl
            : "";
        if (structKeyExists(arguments, "bookingId") AND arguments.bookingId GT 0) {
            return baseUrl & "/admin/booking-details.cfm?bookingId=" & arguments.bookingId;
        }
        return baseUrl & "/admin/pending-approvals.cfm";
    }
}
