component {
    property name="dsn" type="string";
    property name="emailService";
    property name="notificationService";
    property name="systemManager";

    property name="dbUser" type="string";
    property name="dbPass" type="string";

    public function init(required string dsn) {
        variables.dsn = arguments.dsn;

        // Every query here must pass explicit credentials.
        //
        // The datasource itself authenticates as WEBSCHEDULE_USER, not CONFROOM,
        // so a queryExecute given only {datasource=...} cannot see a single
        // CONFROOM table -- every statement fails with
        // "ORA-00942: table or view does not exist". That is why the immediate
        // approver notification never worked, independently of the recipient
        // query, the missing NOTIFICATION_TYPES rows, the application-scope guard,
        // the private sendEmail and the relative template path.
        //
        // The rest of the application already does this: cfcs/*.cfc and
        // assets/cfc/*.cfc pass username and password on every query. This
        // component (and Notification, Room, User and Booking) did not.
        if (listFirst(CGI.SERVER_NAME, '.') EQ 'cmapps') {
            variables.dbUser = "CONFROOM_USER";
            variables.dbPass = "1DOCMAU4CNFRM6";
        } else {
            variables.dbUser = "CONFROOM";
            variables.dbPass = "1DOCMOA4CNFRM3";
        }

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
            JOIN ROLES ro ON ro.ROLE_ID = u.ROLE_ID
            JOIN NOTIFICATION_TYPES t ON t.TYPE_CODE = :typeCode
            LEFT JOIN NOTIFICATION_PREFERENCES np
              ON np.USER_ID = u.USER_ID
             AND np.NOTIFICATION_TYPE = t.TYPE_CODE
            WHERE UPPER(u.STATUS) = 'ACTIVE'
              AND UPPER(ro.ROLE_NAME) IN ('ADMIN','SITE ADMIN')
        ";

        var params = {
            typeCode: { value = arguments.typeCode, cfsqltype = "cf_sql_varchar" }
        };

        var qRecipients = queryNew("");

        try {
            qRecipients = queryExecute(sql, params, {
                datasource = variables.dsn,
                username   = variables.dbUser,
                password   = variables.dbPass
            });
        } catch (any e) {
            // A recipient lookup that throws must not be mistaken for "nobody
            // needs to be told". Log it so the missed approval alert is visible.
            writeLog(
                type = "error",
                file = "approval_notifications",
                text = "getApprovalRecipients failed for #arguments.typeCode#: #e.message# #e.detail#"
            );
            return recipients;
        }

        for (var row in qRecipients) {
            arrayAppend(recipients, row);
        }

        if (!arrayLen(recipients)) {
            // Silent when nobody matches was how the missing NOTIFICATION_TYPES
            // row went unnoticed. Record it instead.
            writeLog(
                type = "warning",
                file = "approval_notifications",
                text = "No approval recipients resolved for #arguments.typeCode#. " &
                       "Check that the NOTIFICATION_TYPES row exists and that at least " &
                       "one Active user holds the Admin or Site Admin role."
            );
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

    // Same guard as EmailService.init(): with no Application.cfc the application
    // scope does not exist, so an unguarded structKeyExists(application, ...)
    // throws rather than returning false. Falling back to a CGI-derived base URL
    // keeps the links in the email usable.
    private string function resolveBaseUrl() {
        if (isDefined("application") AND structKeyExists(application, "config")
            AND structKeyExists(application.config, "baseUrl")
            AND len(trim(application.config.baseUrl))) {
            return application.config.baseUrl;
        }
        if (len(cgi.SERVER_NAME)) {
            return "https://" & cgi.SERVER_NAME & "/" & listFirst(cgi.SCRIPT_NAME, "/");
        }
        return "";
    }

    private string function buildActionUrl(required numeric bookingId, required string action) {
        return resolveBaseUrl() & "/admin/booking-action.cfm?bookingId=" & arguments.bookingId & "&action=" & arguments.action;
    }

    private string function buildDetailUrl(numeric bookingId) {
        var baseUrl = resolveBaseUrl();
        if (structKeyExists(arguments, "bookingId") AND arguments.bookingId GT 0) {
            return baseUrl & "/admin/booking-details.cfm?bookingId=" & arguments.bookingId;
        }
        return baseUrl & "/admin/pending-approvals.cfm";
    }
}
