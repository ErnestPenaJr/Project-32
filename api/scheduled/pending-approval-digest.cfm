<cfscript>
getPageContext().getResponse().setContentType("application/json");

function fetchPendingApprovals(required string datasource, required date runDate) {
    var sql = "\n        SELECT\n            b.BOOKING_ID,\n            b.USER_ID,\n            b.START_TIME,\n            b.END_TIME,\n            b.CREATED_AT,\n            b.COMMENTS,\n            r.ROOM_NAME,\n            r.BUILDING,\n            r.ROOM_NUMBER,\n            u.FIRST_NAME,\n            u.LAST_NAME,\n            u.EMAIL\n        FROM #application.config.dbSchema#.BOOKINGS b\n        JOIN #application.config.dbSchema#.ROOMS r ON r.ROOM_ID = b.ROOM_ID\n        JOIN #application.config.dbSchema#.USERS u ON u.USER_ID = b.USER_ID\n        WHERE LOWER(b.STATUS) = 'pending'\n        ORDER BY b.CREATED_AT ASC\n    ";

    var pending = [];
    var qPending = queryExecute(sql, {}, {datasource = arguments.datasource});

    for (var row in qPending) {
        var submittedAt = row.CREATED_AT;
        if (!isDate(submittedAt)) {
            submittedAt = now();
        }

        var ageHours = numberFormat(dateDiff("s", submittedAt, arguments.runDate) / 3600, "0.0");

        arrayAppend(pending, {
            bookingId = row.BOOKING_ID,
            requesterId = row.USER_ID,
            requesterName = trim((row.FIRST_NAME ?: "") & " " & (row.LAST_NAME ?: "")),
            requesterEmail = row.EMAIL,
            roomName = row.ROOM_NAME,
            location = trim(row.BUILDING & "." & row.ROOM_NUMBER),
            startTime = row.START_TIME,
            endTime = row.END_TIME,
            meetingTitle = row.COMMENTS ?: "",
            submittedAt = submittedAt,
            ageHours = val(ageHours)
        });
    }

    return pending;
}

response = {
    success = false,
    message = "",
    runDate = now(),
    totalPending = 0,
    digestSent = 0,
    recipients = [],
    skipped = 0
};

try {
    if (!structKeyExists(application, "datasource")) {
        throw(message = "Application datasource is not configured.");
    }

    if (!structKeyExists(application, "config") or !structKeyExists(application.config, "dbSchema")) {
        throw(message = "Database schema configuration missing.");
    }

    datasource = application.datasource;
    approvals = fetchPendingApprovals(datasource = datasource, runDate = response.runDate);

    response.totalPending = arrayLen(approvals);

    if (!response.totalPending) {
        response.success = true;
        response.message = "No pending approvals to include in digest.";
    } else {
        approvalService = createObject("component", "components.ApprovalNotification").init(datasource);
        digestResult = approvalService.sendApprovalDigest(
            pendingApprovals = approvals,
            runDate = response.runDate
        );

        response.digestSent = digestResult.emailSent;
        response.recipients = digestResult.recipients;
        response.skipped = digestResult.skipped;
        response.success = digestResult.success;
        response.message = digestResult.success ? "Approval digest dispatched successfully." : "Approval digest could not be sent.";
    }
}
catch (any e) {
    response.success = false;
    response.message = e.message;
    if (structKeyExists(e, "detail")) {
        response.detail = e.detail;
    }
    getPageContext().getResponse().setStatus(500);
}

writeOutput(serializeJSON(response));
</cfscript>
