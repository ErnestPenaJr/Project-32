<cfscript>
getPageContext().getResponse().setContentType("application/json");

// Environment-based credentials (same pattern as scheduledAPI.cfc)
if (listFirst(CGI.SERVER_NAME, ".") == "cmapps") {
    DBSERVER = "inside2_docmp";
    DBUSER = "CONFROOM_USER";
    DBPASS = "1DOCMAU4CNFRM6";
    DBSCHEMA = "CONFROOM";
} else if (listFirst(CGI.SERVER_NAME, ".") == "s-cmapps") {
    DBSERVER = "inside2_docms";
    DBUSER = "CONFROOM";
    DBPASS = "1DOCMOA4CNFRM3";
    DBSCHEMA = "CONFROOM";
} else {
    DBSERVER = "inside2_docmd";
    DBUSER = "CONFROOM";
    DBPASS = "1DOCMOA4CNFRM3";
    DBSCHEMA = "CONFROOM";
}

response = {
    success = false,
    message = "",
    generated_at = dateTimeFormat(now(), "yyyy-mm-dd'T'HH:nn:ss'Z'"),
    total = 0,
    flags = [],
    admins = []
};

try {
    // Optional query parameter: inactive_days (default 0 = show all)
    inactiveDays = val(url.inactive_days ?: 0);

    // Query all admin users with last login info
    qAdmins = queryExecute(
        "SELECT
            u.USER_ID,
            u.EMPLID,
            u.FIRST_NAME,
            u.LAST_NAME,
            u.EMAIL,
            u.STATUS,
            u.LASTLOGGEDON,
            u.DATEENTERED,
            r.ROLE_NAME
        FROM #DBSCHEMA#.USERS u
        JOIN #DBSCHEMA#.ROLES r ON u.ROLE_ID = r.ROLE_ID
        WHERE LOWER(r.ROLE_NAME) IN ('admin', 'site admin')
        ORDER BY u.LASTLOGGEDON ASC NULLS FIRST",
        {},
        {datasource = DBSERVER, username = DBUSER, password = DBPASS}
    );

    admins = [];
    flags = [];

    for (row in qAdmins) {
        daysSinceLogin = 0;
        lastLoginFormatted = "";
        hasNeverLoggedIn = false;

        if (isDate(row.LASTLOGGEDON)) {
            daysSinceLogin = dateDiff("d", row.LASTLOGGEDON, now());
            lastLoginFormatted = dateTimeFormat(row.LASTLOGGEDON, "yyyy-mm-dd'T'HH:nn:ss'Z'");
        } else {
            hasNeverLoggedIn = true;
            daysSinceLogin = -1;
        }

        // Apply inactive_days filter if provided
        if (inactiveDays > 0 && !hasNeverLoggedIn && daysSinceLogin < inactiveDays) {
            continue;
        }

        adminRecord = {
            user_id = row.USER_ID,
            emplid = row.EMPLID,
            first_name = row.FIRST_NAME,
            last_name = row.LAST_NAME,
            email = row.EMAIL,
            role = row.ROLE_NAME,
            status = row.STATUS,
            last_login_at = hasNeverLoggedIn ? javacast("null", "") : lastLoginFormatted,
            days_since_login = hasNeverLoggedIn ? javacast("null", "") : daysSinceLogin,
            is_active = (uCase(row.STATUS) == "ACTIVE"),
            date_added = isDate(row.DATEENTERED) ? dateTimeFormat(row.DATEENTERED, "yyyy-mm-dd'T'HH:nn:ss'Z'") : ""
        };

        arrayAppend(admins, adminRecord);

        // Flag security risks
        if (hasNeverLoggedIn) {
            arrayAppend(flags, {
                user_id = row.USER_ID,
                email = row.EMAIL,
                reason = "Never logged in",
                severity = "high"
            });
        } else if (daysSinceLogin > 90) {
            arrayAppend(flags, {
                user_id = row.USER_ID,
                email = row.EMAIL,
                reason = "Inactive for #daysSinceLogin# days (last login: #lastLoginFormatted#)",
                severity = daysSinceLogin > 180 ? "high" : "medium"
            });
        }
    }

    response.success = true;
    response.message = "Admin audit completed successfully.";
    response.total = arrayLen(admins);
    response.admins = admins;
    response.flags = flags;
}
catch (any e) {
    response.success = false;
    response.message = e.message;
    if (structKeyExists(e, "detail")) {
        response["detail"] = e.detail;
    }
    getPageContext().getResponse().setStatus(500);
}

writeOutput(serializeJSON(response));
</cfscript>
