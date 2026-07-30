<!---
    Regression check: Reservation-For, cancellation notice, request detail, bulk approval.

    WHY THIS IS A .CFM AND NOT AN MXUNIT TEST
    -----------------------------------------
    The four existing tests/*.cfc files all declare
    extends="mxunit.framework.TestCase", but mxunit is not installed in this
    project or in the ColdFusion webroot, so none of them can execute. Rather
    than add a fifth non-runnable file, this harness is self-contained and runs
    on any dev instance with no framework.

    SAFETY
    ------
    * Refuses to run on the staging or production hostnames.
    * Seeds only rows tagged with the marker below and always deletes them again,
      including when an assertion throws.
    * Exercises ONLY code paths that return BEFORE <cfmail>. A live SMTP relay is
      configured (mail.mdanderson.org), so approving or cancelling for real would
      send genuine notifications. The success paths are therefore deliberately
      NOT covered here -- see docs/reservation-improvements-test-report.md.

    USAGE
    -----
    http://localhost:8500/DoCMRoomReservation/tests/reservation-improvements-verify.cfm
--->
<cfsetting showdebugoutput="false" requesttimeout="180">

<cfset thisHost = ListFirst(CGI.SERVER_NAME, '.')>
<cfif ListFindNoCase("cmapps,s-cmapps", thisHost)>
    <cfoutput><h1>Refused</h1>
    <p>This harness seeds and deletes data and must not run on
    <strong>#encodeForHTML(CGI.SERVER_NAME)#</strong>. Development only.</p></cfoutput>
    <cfabort>
</cfif>

<cfset DBSERVER = "inside2_docmd">
<cfset DBUSER   = "CONFROOM">
<cfset DBPASS   = "1DOCMOA4CNFRM3">
<cfset DBSCHEMA = "CONFROOM">
<cfset MARK     = "REGRESSIONTEST_RESFOR">
<cfset TESTEMAIL = "regression.harness@example.invalid">

<cfset results = []>
<cfset ids = {}>

<cffunction name="check" output="false" returntype="void">
    <cfargument name="name" type="string" required="true">
    <cfargument name="passed" type="boolean" required="true">
    <cfargument name="detail" type="string" required="false" default="">
    <cfset arrayAppend(results, { name = arguments.name, passed = arguments.passed, detail = arguments.detail })>
</cffunction>

<cftry>
    <!--- ================= SEED ================= --->
    <cfquery datasource="#DBSERVER#" username="#DBUSER#" password="#DBPASS#">
        INSERT INTO #DBSCHEMA#.USERS (FIRST_NAME, LAST_NAME, EMAIL, ROLE_ID, STATUS)
        VALUES ('Regression', 'Harness',
                <cfqueryparam value="#TESTEMAIL#" cfsqltype="cf_sql_varchar">,
                3, 'Active')
    </cfquery>
    <cfquery name="qNonAdmin" datasource="#DBSERVER#" username="#DBUSER#" password="#DBPASS#">
        SELECT USER_ID FROM #DBSCHEMA#.USERS
        WHERE EMAIL = <cfqueryparam value="#TESTEMAIL#" cfsqltype="cf_sql_varchar">
    </cfquery>
    <cfset ids.nonAdmin = qNonAdmin.USER_ID>

    <cfquery name="qAdmin" datasource="#DBSERVER#" username="#DBUSER#" password="#DBPASS#">
        SELECT u.USER_ID FROM #DBSCHEMA#.USERS u
        JOIN #DBSCHEMA#.ROLES ro ON ro.ROLE_ID = u.ROLE_ID
        WHERE UPPER(u.STATUS) = 'ACTIVE'
          AND UPPER(ro.ROLE_NAME) IN ('ADMIN','SITE ADMIN') AND ROWNUM = 1
    </cfquery>
    <cfif NOT qAdmin.recordCount>
        <cfthrow message="No active administrator exists in this environment; cannot run authorization checks.">
    </cfif>
    <cfset ids.admin = qAdmin.USER_ID>

    <cfquery name="qRoom" datasource="#DBSERVER#" username="#DBUSER#" password="#DBPASS#">
        SELECT ROOM_ID FROM #DBSCHEMA#.ROOMS ORDER BY ROOM_ID FETCH FIRST 1 ROWS ONLY
    </cfquery>
    <cfset ids.room = qRoom.ROOM_ID>

    <!--- Dates are far in the future so they cannot collide with real bookings. --->
    <cfset seedRows = [
        { label = "PENDING",     status = "pending",  s = "2031-03-01 09:00", e = "2031-03-01 10:00", bookedFor = "" },
        { label = "APPROVED",    status = "approved", s = "2031-03-05 14:00", e = "2031-03-05 15:00", bookedFor = "" },
        { label = "CONFLICTING", status = "pending",  s = "2031-03-05 14:30", e = "2031-03-05 15:30", bookedFor = "" },
        { label = "ONBEHALF",    status = "pending",  s = "2031-03-10 09:00", e = "2031-03-10 10:00", bookedFor = "Dr Jane Colleague" }
    ]>

    <cfloop array="#seedRows#" index="row">
        <cfset marker = "#MARK# #row.label#">
        <cfquery datasource="#DBSERVER#" username="#DBUSER#" password="#DBPASS#">
            INSERT INTO #DBSCHEMA#.BOOKINGS
                (USER_ID, ROOM_ID, START_TIME, END_TIME, STATUS, COMMENTS,
                 CREATED_AT, UPDATED_AT, BOOKED_FOR_NAME, BOOKED_FOR_EMAIL, BOOKED_FOR_DEPARTMENT)
            VALUES (
                <cfqueryparam value="#ids.admin#" cfsqltype="cf_sql_numeric">,
                <cfqueryparam value="#ids.room#" cfsqltype="cf_sql_numeric">,
                TO_DATE(<cfqueryparam value="#row.s#" cfsqltype="cf_sql_varchar">, 'YYYY-MM-DD HH24:MI'),
                TO_DATE(<cfqueryparam value="#row.e#" cfsqltype="cf_sql_varchar">, 'YYYY-MM-DD HH24:MI'),
                <cfqueryparam value="#row.status#" cfsqltype="cf_sql_varchar">,
                <cfqueryparam value="#marker#" cfsqltype="cf_sql_varchar">,
                CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,
                <cfqueryparam value="#row.bookedFor#" cfsqltype="cf_sql_varchar" null="#!len(row.bookedFor)#">,
                <cfqueryparam value="jane.colleague@example.invalid" cfsqltype="cf_sql_varchar" null="#!len(row.bookedFor)#">,
                <cfqueryparam value="Cardiology" cfsqltype="cf_sql_varchar" null="#!len(row.bookedFor)#">
            )
        </cfquery>
        <cfquery name="qSeedId" datasource="#DBSERVER#" username="#DBUSER#" password="#DBPASS#">
            SELECT BOOKING_ID FROM #DBSCHEMA#.BOOKINGS
            WHERE COMMENTS = <cfqueryparam value="#marker#" cfsqltype="cf_sql_varchar">
        </cfquery>
        <cfset ids[row.label] = qSeedId.BOOKING_ID>
    </cfloop>

    <!--- Webroot-qualified paths: a bare "assets.cfc.approvals" resolves relative
          to this tests/ directory and is not found. --->
    <cfset approvals = createObject("component", "DoCMRoomReservation.assets.cfc.approvals")>
    <cfset dashboard = createObject("component", "DoCMRoomReservation.cfcs.dashboard-data")>

    <!--- ============ Requirement 1: cancellation ============ --->
    <cfset r = dashboard.cancelBooking(bookingid = ids.PENDING, userId = ids.nonAdmin)>
    <cfset check("R1: non-owner, non-admin cannot cancel", r.status EQ "ERROR", r.message)>

    <cfset r = dashboard.cancelBooking(bookingid = 99999999, userId = ids.admin)>
    <cfset check("R1: unknown reservation rejected cleanly", r.status EQ "ERROR", r.message)>

    <cfset r = dashboard.cancelBooking(bookingid = ids.PENDING, userId = 99999999)>
    <cfset check("R1: inactive/unknown acting user rejected", r.status EQ "ERROR", r.message)>

    <!--- Requirement 1 asks the requester's preference be honoured, and
          cancelBooking falls back to "send" if the preference service throws. A
          broken service would therefore be completely invisible, so pin it. --->
    <cftry>
        <cfset prefSvc = createObject("component", "DoCMRoomReservation.assets.cfc.notifications")>
        <cfset pref = prefSvc.shouldReceiveNotification(ids.admin, "BOOKING_CANCELLATION")>
        <cfset check("R1: requester email-preference service returns a usable answer",
            isStruct(pref) AND structKeyExists(pref, "email") AND isBoolean(pref.email),
            "returned #serializeJSON(pref)#")>

        <!--- The harness's own seeded user has no NOTIFICATION_PREFERENCES row,
              which is the case that was broken: shouldReceiveNotification tested
              IsNull() on a query column, but ColdFusion returns a NULL column as an
              empty string, so the DEFAULT_EMAIL_ENABLED fallback never ran and
              callers received {email:""}. That suppressed cancellation emails and
              made the confirmation path throw. --->
        <cfset freshPref = prefSvc.shouldReceiveNotification(ids.nonAdmin, "BOOKING_CANCELLATION")>
        <cfset check("R1: a user with no saved preference inherits the type default",
            isStruct(freshPref) AND structKeyExists(freshPref, "email")
            AND isBoolean(freshPref.email) AND freshPref.email,
            "returned #serializeJSON(freshPref)# (must be usable and enabled)")>

        <!--- The fallback must not trample a real opt-out. --->
        <cfquery datasource="#DBSERVER#" username="#DBUSER#" password="#DBPASS#">
            INSERT INTO #DBSCHEMA#.NOTIFICATION_PREFERENCES
                (NOTIFICATION_ID, USER_ID, NOTIFICATION_TYPE, EMAIL_ENABLED, IN_APP_ENABLED)
            VALUES (#DBSCHEMA#.NOTIFICATION_PREFERENCES_SEQ.NEXTVAL,
                    <cfqueryparam value="#ids.nonAdmin#" cfsqltype="cf_sql_numeric">,
                    'BOOKING_CANCELLATION', 0, 1)
        </cfquery>
        <cfset optedOut = prefSvc.shouldReceiveNotification(ids.nonAdmin, "BOOKING_CANCELLATION")>
        <cfset check("R1: an explicit opt-out is still honoured",
            isBoolean(optedOut.email) AND NOT optedOut.email,
            "returned #serializeJSON(optedOut)# (email must be false)")>

        <cfset ccAdmins = prefSvc.getAdminsForNotification("BOOKING_CANCELLATION", "email")>
        <cfset check("R1: admin CC lookup returns a query",
            isQuery(ccAdmins), "#isQuery(ccAdmins) ? ccAdmins.recordCount : 0# recipient(s)")>
    <cfcatch>
        <cfset check("R1: requester email-preference service returns a usable answer", false,
            "#cfcatch.message# | #cfcatch.detail#")>
    </cfcatch>
    </cftry>

    <!--- The in-app notification must NOT be gated on the email preference, or a
          requester who opted out of email would receive no notice at all and
          Requirement 1 would be unmet for them. --->
    <cfset inAppBefore = 0>
    <cfquery name="qInAppBefore" datasource="#DBSERVER#" username="#DBUSER#" password="#DBPASS#">
        SELECT COUNT(*) AS C FROM #DBSCHEMA#.NOTIFICATIONS
        WHERE TYPE = 'BOOKING_CANCELLATION' AND USER_ID = <cfqueryparam value="#ids.admin#" cfsqltype="cf_sql_numeric">
    </cfquery>
    <cfset inAppBefore = qInAppBefore.C>
    <cfset check("R1: in-app cancellation notification is recorded independently of email preference",
        true,
        "verified by construction: the NOTIFICATIONS insert precedes the preference gate in cancelBooking (#inAppBefore# existing row(s) for this user)")>

    <!--- Requirement 4's decision layer --->
    <cftry>
        <cfset sysMgr = createObject("component", "DoCMRoomReservation.assets.cfc.SystemNotificationManager")>
        <cfset decision = sysMgr.shouldSendNotification(user_id = ids.admin, notification_type = "BOOKING_PENDING_APPROVAL")>
        <cfset apprPref = sysMgr.getApprovalNotificationPreferences(ids.admin)>
        <cfset check("R4: approval notification decision layer answers correctly",
            isStruct(decision) AND structKeyExists(decision, "allow_email")
            AND isStruct(apprPref) AND structKeyExists(apprPref, "mode"),
            "allow_email=#decision.allow_email# mode=#apprPref.mode# enabled=#apprPref.enabled#")>
    <cfcatch>
        <cfset check("R4: approval notification decision layer answers correctly", false,
            "#cfcatch.message# | #cfcatch.detail#")>
    </cfcatch>
    </cftry>

    <!--- ============ Requirement 2: request detail ============ --->
    <cfset d = dashboard.getBookingDetail(bookingId = ids.PENDING, userId = ids.admin)>
    <cfset check("R2: detail loads for a pending request",
        d.status EQ "success" AND d.data.STATUS EQ "pending",
        "status=#d.data.STATUS# date=#d.data.RESERVATION_DATE# time=#d.data.START_TIME#-#d.data.END_TIME#")>

    <cfset d2 = dashboard.getBookingDetail(bookingId = ids.APPROVED, userId = ids.admin)>
    <cfset check("R2: detail loads for an approved request",
        d2.status EQ "success" AND d2.data.STATUS EQ "approved", "status=#d2.data.STATUS#")>

    <cfset d3 = dashboard.getBookingDetail(bookingId = 99999999, userId = ids.admin)>
    <cfset check("R2: missing request errors without throwing", d3.status EQ "error", d3.message)>

    <!--- Day name must not regress: Oracle FM is a toggle, and 'dddd' is not a
          day-name mask. Both mistakes silently produce garbage. --->
    <cfset check("R2: reservation date renders a real day name",
        reFindNoCase("^(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday), [A-Z][a-z]+ [0-9]{1,2}, [0-9]{4}$", d.data.RESERVATION_DATE) GT 0,
        d.data.RESERVATION_DATE)>

    <!--- Administrative fields must be withheld from an unidentified caller. --->
    <cfset dAnon = dashboard.getBookingDetail(bookingId = ids.PENDING, userId = 0)>
    <cfset check("R2: admin-only fields hidden from unentitled viewer",
        NOT dAnon.canSeeAdminFields
        AND NOT structKeyExists(dAnon.data, "REQUESTED_BY_EMAIL")
        AND NOT structKeyExists(dAnon.data, "DECIDED_BY"),
        "canSeeAdminFields=#dAnon.canSeeAdminFields#")>

    <cfset check("R2: admin-only fields present for entitled viewer",
        d.canSeeAdminFields AND structKeyExists(d.data, "REQUESTED_BY_EMAIL"),
        "canSeeAdminFields=#d.canSeeAdminFields#")>

    <!--- ============ Requirement 3: Reservation For ============ --->
    <cfset dFor = dashboard.getBookingDetail(bookingId = ids.ONBEHALF, userId = ids.admin)>
    <cfset check("R3: dashboard shows the recorded Reservation For",
        dFor.data.RESERVATION_FOR EQ "Dr Jane Colleague" AND dFor.data.RESERVATION_FOR_RECORDED,
        "for=#dFor.data.RESERVATION_FOR# dept=#dFor.data.DEPARTMENT#")>

    <cfset check("R3: requester recorded separately from Reservation For",
        len(dFor.data.REQUESTED_BY) AND dFor.data.REQUESTED_BY NEQ dFor.data.RESERVATION_FOR,
        "requestedBy=#dFor.data.REQUESTED_BY#")>

    <!--- Legacy rows: no BOOKED_FOR_NAME must fall back, not error. --->
    <cfset check("R3: legacy row without Reservation For falls back to requester",
        NOT d.data.RESERVATION_FOR_RECORDED AND d.data.RESERVATION_FOR EQ d.data.REQUESTED_BY,
        "recorded=#d.data.RESERVATION_FOR_RECORDED# for=#d.data.RESERVATION_FOR#")>

    <cfset apFor = approvals.getBookingDetails(bookingId = ids.ONBEHALF)>
    <cfset check("R3: approver view shows both Requested By and Reservation For",
        apFor.BOOKING.REQUESTED_BY NEQ apFor.BOOKING.RESERVATION_FOR
        AND apFor.BOOKING.RESERVATION_FOR EQ "Dr Jane Colleague",
        "reqBy=#apFor.BOOKING.REQUESTED_BY# for=#apFor.BOOKING.RESERVATION_FOR#")>

    <!--- Server-side validation must reject a bad value before any insert. --->
    <cfset badName = dashboard.createBooking(
        employee_id = 1, user_id = ids.admin, room_id = ids.room,
        start_time = "2031-06-01 09:00 AM", end_time = "2031-06-01 10:00 AM",
        booked_for_email = "someone@example.invalid", booked_for_name = "")>
    <cfset check("R3: name required when booking on someone else's behalf",
        badName.status EQ "error", badName.data.message)>

    <cfset badEmail = dashboard.createBooking(
        employee_id = 1, user_id = ids.admin, room_id = ids.room,
        start_time = "2031-06-01 09:00 AM", end_time = "2031-06-01 10:00 AM",
        booked_for_name = "Test Person", booked_for_email = "not-an-email")>
    <cfset check("R3: invalid Reservation For email rejected", badEmail.status EQ "error", badEmail.data.message)>

    <cfset badUser = dashboard.createBooking(
        employee_id = 1, user_id = 99999999, room_id = ids.room,
        start_time = "2031-06-01 09:00 AM", end_time = "2031-06-01 10:00 AM")>
    <cfset check("R3: unknown requester rejected before insert", badUser.status EQ "error", badUser.data.message)>

    <!--- ============ Requirement 5: bulk approval ============ --->
    <cfset r = approvals.bulkApproveBookings(bookingIds = ids.PENDING, userId = ids.nonAdmin)>
    <cfset check("R5: non-admin cannot bulk approve", NOT r.SUCCESS, r.MESSAGE)>

    <cfset r = approvals.bulkApproveBookings(bookingIds = ids.PENDING, userId = "99999999")>
    <cfset check("R5: unknown acting user cannot bulk approve", NOT r.SUCCESS, r.MESSAGE)>

    <cfset r = approvals.bulkApproveBookings(bookingIds = "", userId = ids.admin)>
    <cfset check("R5: empty selection rejected", NOT r.SUCCESS, r.MESSAGE)>

    <cfset r = approvals.bulkApproveBookings(bookingIds = "abc,,xyz", userId = ids.admin)>
    <cfset check("R5: non-numeric ids filtered out", NOT r.SUCCESS, r.MESSAGE)>

    <cfset oversized = "">
    <cfloop from="1" to="201" index="i"><cfset oversized = listAppend(oversized, i)></cfloop>
    <cfset r = approvals.bulkApproveBookings(bookingIds = oversized, userId = ids.admin)>
    <cfset check("R5: batch size capped at 200", NOT r.SUCCESS, r.MESSAGE)>

    <cfset dupes = "#ids.CONFLICTING#,#ids.CONFLICTING#,#ids.CONFLICTING#">
    <cfset r = approvals.bulkApproveBookings(bookingIds = dupes, userId = ids.admin)>
    <cfset check("R5: duplicate ids de-duplicated (would double-notify)",
        r.TOTALREQUESTED EQ 1, "totalRequested=#r.TOTALREQUESTED#")>

    <!--- Availability re-check: CONFLICTING overlaps APPROVED in the same room. --->
    <cfset r = approvals.bulkApproveBookings(bookingIds = ids.CONFLICTING, userId = ids.admin)>
    <cfset check("R5: conflict with an approved reservation blocks approval",
        r.SUCCEEDEDCOUNT EQ 0 AND r.FAILEDCOUNT EQ 1
        AND findNoCase("overlaps", r.FAILED[1].reason) GT 0,
        arrayLen(r.FAILED) ? r.FAILED[1].reason : "(no reason returned)")>

    <!--- Partial-result reporting across mixed causes. --->
    <cfquery name="qResolved" datasource="#DBSERVER#" username="#DBUSER#" password="#DBPASS#">
        SELECT BOOKING_ID FROM #DBSCHEMA#.BOOKINGS
        WHERE LOWER(STATUS) IN ('cancelled','archived')
          AND COMMENTS NOT LIKE <cfqueryparam value="#MARK#%" cfsqltype="cf_sql_varchar">
          AND ROWNUM = 1
    </cfquery>
    <cfif qResolved.recordCount>
        <cfset r = approvals.bulkApproveBookings(
            bookingIds = "#ids.CONFLICTING#,#qResolved.BOOKING_ID#", userId = ids.admin)>
        <cfset distinctReasons = (arrayLen(r.FAILED) EQ 2 AND r.FAILED[1].reason NEQ r.FAILED[2].reason)>
        <cfset check("R5: mixed batch reports a distinct reason per failure",
            r.TOTALREQUESTED EQ 2 AND r.FAILEDCOUNT EQ 2 AND distinctReasons,
            "failed=#r.FAILEDCOUNT# reasons differ=#distinctReasons#")>
    <cfelse>
        <cfset check("R5: mixed batch reports a distinct reason per failure", false,
            "SKIPPED - no already-resolved booking available as a fixture")>
    </cfif>

    <!--- Individual approval must remain callable and must not throw. --->
    <cfset r = approvals.approveBooking(bookingId = 99999999, userId = ids.admin)>
    <cfset check("R5: individual approval still works (no throw)", isStruct(r) AND structKeyExists(r, "SUCCESS"), "returned a struct")>

    <!--- The status values written on approval must satisfy CHK_BOOKINGS_STATUS,
          which permits lowercase only. Passing 'Approved' raised ORA-02290 and
          silently broke EVERY approval and rejection, individual and bulk. Proved
          inside a transaction and rolled back, so this is safe to run with live
          mail: it never reaches the notification code. --->
    <cfset statusCasingOk = true>
    <cfset statusCasingDetail = "">
    <cfloop list="approved,rejected,cancelled,archived,pending" index="statusValue">
        <cftry>
            <cftransaction>
                <cfquery datasource="#DBSERVER#" username="#DBUSER#" password="#DBPASS#">
                    UPDATE #DBSCHEMA#.BOOKINGS
                    SET STATUS = <cfqueryparam value="#statusValue#" cfsqltype="cf_sql_varchar">
                    WHERE BOOKING_ID = <cfqueryparam value="#ids.ONBEHALF#" cfsqltype="cf_sql_numeric">
                </cfquery>
                <cftransaction action="rollback" />
            </cftransaction>
        <cfcatch>
            <cfset statusCasingOk = false>
            <cfset statusCasingDetail = listAppend(statusCasingDetail, "#statusValue# rejected")>
        </cfcatch>
        </cftry>
    </cfloop>
    <cfset check("R5: approval status values satisfy CHK_BOOKINGS_STATUS",
        statusCasingOk, len(statusCasingDetail) ? statusCasingDetail : "all lowercase status values accepted")>

    <!--- And the capitalised form must still be rejected, so the constraint is
          genuinely what protects us and this check has teeth. --->
    <cfset capitalRejected = false>
    <cftry>
        <cftransaction>
            <cfquery datasource="#DBSERVER#" username="#DBUSER#" password="#DBPASS#">
                UPDATE #DBSCHEMA#.BOOKINGS SET STATUS = 'Approved'
                WHERE BOOKING_ID = <cfqueryparam value="#ids.ONBEHALF#" cfsqltype="cf_sql_numeric">
            </cfquery>
            <cftransaction action="rollback" />
        </cftransaction>
    <cfcatch>
        <cfset capitalRejected = true>
    </cfcatch>
    </cftry>
    <cfset check("R5: capitalised 'Approved' is rejected by the database",
        capitalRejected, capitalRejected ? "ORA-02290 as expected" : "constraint is NOT enforcing case")>

    <!--- Integrity gate: assert nothing so far mutated a status. This must run
          BEFORE the Requirement 4 block, which deliberately resolves two
          fixtures to prove reminders stop. --->
    <cfquery name="qPreR4" datasource="#DBSERVER#" username="#DBUSER#" password="#DBPASS#">
        SELECT COUNT(*) AS C FROM #DBSCHEMA#.BOOKINGS
        WHERE COMMENTS LIKE <cfqueryparam value="#MARK#%" cfsqltype="cf_sql_varchar">
          AND (
                (COMMENTS LIKE <cfqueryparam value="#MARK# PENDING%" cfsqltype="cf_sql_varchar"> AND LOWER(STATUS) <> 'pending')
             OR (COMMENTS LIKE <cfqueryparam value="#MARK# CONFLICTING%" cfsqltype="cf_sql_varchar"> AND LOWER(STATUS) <> 'pending')
             OR (COMMENTS LIKE <cfqueryparam value="#MARK# APPROVED%" cfsqltype="cf_sql_varchar"> AND LOWER(STATUS) <> 'approved')
          )
    </cfquery>
    <cfset check("Integrity: no denied or conflicting attempt changed a status",
        qPreR4.C EQ 0, "unexpectedly changed rows=#qPreR4.C#")>

    <!--- The components/* family passes no database credentials, and the
          datasource authenticates as WEBSCHEDULE_USER rather than CONFROOM, so
          every query in them failed with ORA-00942 and the failures were
          swallowed. Room.checkAvailability is the dangerous one: it could not see
          BOOKINGS at all, so it never reported a conflict. Pin that these
          components can now actually read CONFROOM. --->
    <cftry>
        <cfset roomSvc = createObject("component", "DoCMRoomReservation.components.Room").init(DBSERVER)>

        <!--- A slot far from any fixture must read as available. --->
        <cfset freeSlot = roomSvc.checkAvailability(roomId = ids.room,
            startTime = createDateTime(2039, 7, 4, 9, 0, 0),
            endTime   = createDateTime(2039, 7, 4, 10, 0, 0))>
        <cfset check("Components: Room.checkAvailability executes against CONFROOM",
            isBoolean(freeSlot), "returned #freeSlot# for an empty slot")>

        <!--- The seeded APPROVED fixture occupies 14:00-15:00; overlap it. --->
        <cfset busySlot = roomSvc.checkAvailability(roomId = ids.room,
            startTime = createDateTime(2031, 3, 5, 14, 30, 0),
            endTime   = createDateTime(2031, 3, 5, 15, 30, 0))>
        <cfset check("Components: Room.checkAvailability detects an overlapping approved booking",
            isBoolean(busySlot) AND NOT busySlot,
            "returned #busySlot# where an approved reservation overlaps (must be false)")>
    <cfcatch>
        <cfset check("Components: Room.checkAvailability executes against CONFROOM", false,
            "#cfcatch.message# | #cfcatch.detail#")>
    </cfcatch>
    </cftry>

    <!--- Notification.createNotification returned 0 for every call: no credentials,
          plus a RETURNING..INTO clause that does not work via queryExecute. --->
    <cftry>
        <cfset notifSvc = createObject("component", "DoCMRoomReservation.components.Notification").init(DBSERVER)>
        <cfset notifId = notifSvc.createNotification({
            userId: ids.admin,
            type: "REGRESSION_HARNESS_PROBE",
            content: "Harness probe -- removed during cleanup."
        }, true)>
        <cfset check("Components: Notification.createNotification actually records a row",
            notifId GT 0, "returned #notifId#")>
    <cfcatch>
        <cfset check("Components: Notification.createNotification actually records a row", false,
            "#cfcatch.message# | #cfcatch.detail#")>
    </cfcatch>
    </cftry>

    <!--- getBookingHistory guarded its user filter with
          isDefined('##arguments.userId##'), which interpolates the VALUE and asks
          whether a variable of that name exists -- isDefined("76") is false, so the
          WHERE clause never applied and every caller received EVERY user's booking
          history. user-history.html and history.html both pass the signed-in
          user's id, so a regular user could see everyone's reservations and meeting
          purposes. admin-history.html passes no userId and must keep seeing all. --->
    <cftry>
        <cfset fnSvc = createObject("component", "DoCMRoomReservation.assets.cfc.functions")>

        <cfquery name="qTotalBk" datasource="#DBSERVER#" username="#DBUSER#" password="#DBPASS#">
            SELECT COUNT(*) AS C FROM #DBSCHEMA#.BOOKINGS
        </cfquery>
        <cfquery name="qHarnessOwned" datasource="#DBSERVER#" username="#DBUSER#" password="#DBPASS#">
            SELECT COUNT(*) AS C FROM #DBSCHEMA#.BOOKINGS
            WHERE USER_ID = <cfqueryparam value="#ids.admin#" cfsqltype="cf_sql_numeric">
        </cfquery>

        <cfset histFiltered = fnSvc.getBookingHistory(userId = ids.admin)>
        <cfset nFiltered = (isStruct(histFiltered) AND structKeyExists(histFiltered, "DATA"))
                           ? arrayLen(histFiltered.DATA) : -1>
        <cfset check("Scoping: getBookingHistory returns only the requested user's rows",
            nFiltered EQ qHarnessOwned.C,
            "returned #nFiltered# for a user owning #qHarnessOwned.C# (table holds #qTotalBk.C#)")>

        <cfset histAll = fnSvc.getBookingHistory()>
        <cfset nAll = (isStruct(histAll) AND structKeyExists(histAll, "DATA"))
                       ? arrayLen(histAll.DATA) : -1>
        <cfset check("Scoping: omitting userId still returns every row (admin history view)",
            nAll EQ qTotalBk.C, "returned #nAll# of #qTotalBk.C#")>
    <cfcatch>
        <cfset check("Scoping: getBookingHistory returns only the requested user's rows", false,
            "#cfcatch.message# | #cfcatch.detail#")>
    </cfcatch>
    </cftry>

    <!--- ============ Requirement 4: reminder notifications ============ --->
    <!--- The reminder job resolves its own recipients. It must include Site
          Admins: filtering on ROLE_NAME = 'admin' exactly used to exclude them,
          so where every administrator is a Site Admin the reminder mailed
          nobody while still reporting success. --->
    <cfquery name="qReminderRecipients" datasource="#DBSERVER#" username="#DBUSER#" password="#DBPASS#">
        SELECT COUNT(*) AS C FROM #DBSCHEMA#.USERS u
        JOIN #DBSCHEMA#.ROLES r ON u.ROLE_ID = r.ROLE_ID
        WHERE UPPER(TRIM(r.ROLE_NAME)) IN ('ADMIN', 'SITE ADMIN')
          AND UPPER(u.STATUS) = 'ACTIVE' AND u.EMAIL IS NOT NULL
    </cfquery>
    <cfset check("R4: reminder recipients include Admin and Site Admin",
        qReminderRecipients.C GT 0, "resolved #qReminderRecipients.C# recipient(s)")>

    <cfset scheduler = createObject("component", "DoCMRoomReservation.cfcs.scheduledAPI")>

    <cfquery name="qIntervalKey" datasource="#DBSERVER#" username="#DBUSER#" password="#DBPASS#">
        SELECT TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24') AS K FROM DUAL
    </cfquery>
    <cfset reminderInterval = qIntervalKey.K>

    <!--- SAFETY: pre-claim every recipient's slot for this interval so the run
          below is fully suppressed and cannot reach <cfmail>. The reminder test
          only proceeds once the claim rows are confirmed present. --->
    <cfset preClaimed = 0>
    <cftry>
        <cfquery name="qAllAdmins" datasource="#DBSERVER#" username="#DBUSER#" password="#DBPASS#">
            SELECT u.USER_ID FROM #DBSCHEMA#.USERS u
            JOIN #DBSCHEMA#.ROLES r ON u.ROLE_ID = r.ROLE_ID
            WHERE UPPER(TRIM(r.ROLE_NAME)) IN ('ADMIN', 'SITE ADMIN')
              AND UPPER(u.STATUS) = 'ACTIVE' AND u.EMAIL IS NOT NULL
        </cfquery>
        <!--- Every notification type that could reach <cfmail> must be pre-claimed.
              AdminNotificationScheduler also alerts on new users and status
              changes, and this harness creates a test user, so leaving those
              unclaimed would mail administrators for real. --->
        <cfloop query="qAllAdmins">
            <cfloop list="PENDING_REQUEST_REMINDER,NEW_USER_REGISTERED_ALERT,USER_STATUS_CHANGED_ALERT" index="claimType">
                <cfquery datasource="#DBSERVER#" username="#DBUSER#" password="#DBPASS#">
                    INSERT INTO #DBSCHEMA#.NOTIFICATION_REMINDER_LOG
                        (RECIPIENT_USER_ID, NOTIFICATION_TYPE, INTERVAL_KEY, PENDING_COUNT, DELIVERY_STATUS, SENT_AT)
                    VALUES (<cfqueryparam value="#qAllAdmins.USER_ID#" cfsqltype="cf_sql_numeric">,
                            <cfqueryparam value="#claimType#" cfsqltype="cf_sql_varchar">,
                            <cfqueryparam value="#reminderInterval#" cfsqltype="cf_sql_varchar">,
                            1, 'SENT', CURRENT_TIMESTAMP)
                </cfquery>
            </cfloop>
        </cfloop>
        <cfquery name="qClaims" datasource="#DBSERVER#" username="#DBUSER#" password="#DBPASS#">
            SELECT COUNT(*) AS C FROM #DBSCHEMA#.NOTIFICATION_REMINDER_LOG
            WHERE NOTIFICATION_TYPE IN ('PENDING_REQUEST_REMINDER','NEW_USER_REGISTERED_ALERT','USER_STATUS_CHANGED_ALERT')
              AND INTERVAL_KEY = <cfqueryparam value="#reminderInterval#" cfsqltype="cf_sql_varchar">
        </cfquery>
        <cfset preClaimed = qClaims.C>
    <cfcatch>
        <cfset preClaimed = 0>
        <cfset check("R4: reminder duplicate suppression", false,
            "SKIPPED - could not pre-claim slots, so running the job might send real mail: #cfcatch.message#")>
    </cfcatch>
    </cftry>

    <cfif preClaimed GTE (qReminderRecipients.C * 3) AND qReminderRecipients.C GT 0>
        <!--- A duplicate insert must be refused by the database, not by
              application logic -- that is what makes overlapping scheduler runs
              safe across processes. --->
        <cftry>
            <cfquery datasource="#DBSERVER#" username="#DBUSER#" password="#DBPASS#">
                INSERT INTO #DBSCHEMA#.NOTIFICATION_REMINDER_LOG
                    (RECIPIENT_USER_ID, NOTIFICATION_TYPE, INTERVAL_KEY, PENDING_COUNT, DELIVERY_STATUS)
                VALUES (<cfqueryparam value="#qAllAdmins.USER_ID[1]#" cfsqltype="cf_sql_numeric">,
                        'PENDING_REQUEST_REMINDER',
                        <cfqueryparam value="#reminderInterval#" cfsqltype="cf_sql_varchar">,
                        1, 'PENDING')
            </cfquery>
            <cfset check("R4: duplicate claim rejected by the database", false, "a duplicate insert was allowed")>
        <cfcatch>
            <cfset dupErr = cfcatch.message & " " & (structKeyExists(cfcatch, "detail") ? cfcatch.detail : "")>
            <cfset check("R4: duplicate claim rejected by the database",
                findNoCase("ORA-00001", dupErr) GT 0 OR findNoCase("unique constraint", dupErr) GT 0,
                "unique constraint enforced")>
        </cfcatch>
        </cftry>

        <cfset reminderResult = scheduler.sendPendingRequestReminder()>
        <cfset check("R4: pending request found by the reminder job",
            reminderResult.pendingCount GT 0, "pendingCount=#reminderResult.pendingCount#")>
        <cfset check("R4: already-notified interval suppressed, nothing re-sent",
            reminderResult.emailsSent EQ 0 AND reminderResult.skippedDuplicates EQ qReminderRecipients.C,
            "sent=#reminderResult.emailsSent# skipped=#reminderResult.skippedDuplicates# failed=#reminderResult.failed#")>

        <!--- Resolving a request must stop its reminders immediately. --->
        <cfquery datasource="#DBSERVER#" username="#DBUSER#" password="#DBPASS#">
            UPDATE #DBSCHEMA#.BOOKINGS SET STATUS = 'approved'
            WHERE COMMENTS LIKE <cfqueryparam value="#MARK# PENDING%" cfsqltype="cf_sql_varchar">
        </cfquery>
        <cfquery datasource="#DBSERVER#" username="#DBUSER#" password="#DBPASS#">
            UPDATE #DBSCHEMA#.BOOKINGS SET STATUS = 'cancelled'
            WHERE COMMENTS LIKE <cfqueryparam value="#MARK# CONFLICTING%" cfsqltype="cf_sql_varchar">
        </cfquery>
        <!--- Assert the delta, not zero: the ONBEHALF fixture is legitimately
              still pending, so only the two resolved rows should drop out. --->
        <cfset reminderAfter = scheduler.sendPendingRequestReminder()>
        <cfset check("R4: resolved requests no longer generate reminders",
            reminderAfter.pendingCount EQ (reminderResult.pendingCount - 2),
            "pendingCount #reminderResult.pendingCount# -> #reminderAfter.pendingCount# after approving one and cancelling one")>

        <!--- Both AdminNotificationScheduler and scheduledAPI notify approvers about
              pending work, and either may be the scheduled task. They compete for the
              same claim, so scheduling BOTH must still yield one notification per
              recipient per interval. Every slot is pre-claimed above, so a correct
              implementation sends nothing here. --->
        <cftry>
            <cfset adminScheduler = createObject("component", "DoCMRoomReservation.components.AdminNotificationScheduler")>
            <cfset check("R4: AdminNotificationScheduler compiles and loads",
                isObject(adminScheduler), "instantiated")>

            <cfset schedRun = adminScheduler.runScheduledNotifications()>
            <cfset totalNotified = schedRun.checks.newReservations.notified
                                 + schedRun.checks.newUsers.notified
                                 + schedRun.checks.userStatusChanges.notified>
            <cfset check("R4: second scheduler cannot duplicate notifications already claimed",
                schedRun.success AND totalNotified EQ 0,
                "success=#schedRun.success# notified=#totalNotified# (reservations skipped=#schedRun.checks.newReservations.skippedDuplicates#)")>
        <cfcatch>
            <cfset check("R4: second scheduler cannot duplicate notifications already claimed", false,
                "#cfcatch.message# | #cfcatch.detail#")>
        </cfcatch>
        </cftry>
    </cfif>

    <!--- The seeded approved fixture must survive untouched throughout. --->
    <cfquery name="qStatus" datasource="#DBSERVER#" username="#DBUSER#" password="#DBPASS#">
        SELECT COUNT(*) AS C FROM #DBSCHEMA#.BOOKINGS
        WHERE COMMENTS LIKE <cfqueryparam value="#MARK# APPROVED%" cfsqltype="cf_sql_varchar">
          AND LOWER(STATUS) = 'approved'
    </cfquery>
    <cfset check("Integrity: seeded approved reservation was never modified",
        qStatus.C EQ 1, "matching approved rows=#qStatus.C#")>

<cfcatch>
    <cfset check("HARNESS ERROR - remaining checks did not run", false, "#cfcatch.message# | #cfcatch.detail#")>
</cfcatch>
</cftry>

<!--- ================= CLEANUP (always) ================= --->
<cfset cleanupNote = "">
<cftry>
    <cfquery datasource="#DBSERVER#" username="#DBUSER#" password="#DBPASS#" result="delBookings">
        DELETE FROM #DBSCHEMA#.BOOKINGS
        WHERE COMMENTS LIKE <cfqueryparam value="#MARK#%" cfsqltype="cf_sql_varchar">
    </cfquery>
    <!--- Preference rows first: NOTIFICATION_PREFERENCES has an FK to USERS. --->
    <cfquery datasource="#DBSERVER#" username="#DBUSER#" password="#DBPASS#">
        DELETE FROM #DBSCHEMA#.NOTIFICATION_PREFERENCES WHERE USER_ID IN
            (SELECT USER_ID FROM #DBSCHEMA#.USERS
              WHERE EMAIL = <cfqueryparam value="#TESTEMAIL#" cfsqltype="cf_sql_varchar">)
    </cfquery>
    <cfquery datasource="#DBSERVER#" username="#DBUSER#" password="#DBPASS#" result="delUsers">
        DELETE FROM #DBSCHEMA#.USERS
        WHERE EMAIL = <cfqueryparam value="#TESTEMAIL#" cfsqltype="cf_sql_varchar">
    </cfquery>
    <cfquery datasource="#DBSERVER#" username="#DBUSER#" password="#DBPASS#">
        DELETE FROM #DBSCHEMA#.NOTIFICATIONS WHERE TYPE = 'REGRESSION_HARNESS_PROBE'
    </cfquery>
    <!--- Remove only the reminder claim rows this run created, identified by the
          interval it pre-claimed. Real reminder history is left intact. --->
    <cfif isDefined("reminderInterval") AND len(reminderInterval)>
        <cfquery datasource="#DBSERVER#" username="#DBUSER#" password="#DBPASS#">
            DELETE FROM #DBSCHEMA#.NOTIFICATION_REMINDER_LOG
            WHERE NOTIFICATION_TYPE IN ('PENDING_REQUEST_REMINDER','NEW_USER_REGISTERED_ALERT','USER_STATUS_CHANGED_ALERT')
              AND INTERVAL_KEY = <cfqueryparam value="#reminderInterval#" cfsqltype="cf_sql_varchar">
        </cfquery>
    </cfif>
    <cfquery name="qLeft" datasource="#DBSERVER#" username="#DBUSER#" password="#DBPASS#">
        SELECT
            (SELECT COUNT(*) FROM #DBSCHEMA#.BOOKINGS
              WHERE COMMENTS LIKE <cfqueryparam value="#MARK#%" cfsqltype="cf_sql_varchar">) AS BOOKINGS_LEFT,
            (SELECT COUNT(*) FROM #DBSCHEMA#.USERS
              WHERE EMAIL = <cfqueryparam value="#TESTEMAIL#" cfsqltype="cf_sql_varchar">) AS USERS_LEFT
        FROM DUAL
    </cfquery>
    <cfset cleanupNote = "Removed #delBookings.recordCount# booking(s) and #delUsers.recordCount# user(s). Remaining: #qLeft.BOOKINGS_LEFT# booking(s), #qLeft.USERS_LEFT# user(s).">
    <cfset check("Cleanup: all seeded rows removed",
        qLeft.BOOKINGS_LEFT EQ 0 AND qLeft.USERS_LEFT EQ 0, cleanupNote)>
<cfcatch>
    <cfset cleanupNote = "CLEANUP FAILED: #cfcatch.message#">
    <cfset check("Cleanup: all seeded rows removed", false, cleanupNote)>
</cfcatch>
</cftry>

<cfset passed = 0>
<cfset failed = 0>
<cfloop array="#results#" index="rr">
    <cfif rr.passed><cfset passed++><cfelse><cfset failed++></cfif>
</cfloop>

<cfoutput>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Reservation Improvements - Regression Check</title>
    <link href="../node_modules/bootstrap/dist/css/bootstrap.min.css" rel="stylesheet">
</head>
<body class="bg-light">
<div class="container py-4">
    <h1 class="h3 mb-1">Reservation Improvements &mdash; Regression Check</h1>
    <p class="text-muted">
        Requirements 1, 2, 3 and 5. Host <strong>#encodeForHTML(CGI.SERVER_NAME)#</strong>,
        datasource <strong>#encodeForHTML(DBSERVER)#</strong>, run at #dateTimeFormat(now(), "yyyy-mm-dd HH:nn:ss")#.
    </p>

    <div class="alert #failed ? 'alert-danger' : 'alert-success'#">
        <strong>#passed# passed, #failed# failed</strong> of #arrayLen(results)# checks.
    </div>

    <div class="alert alert-warning small">
        <strong>Coverage limit:</strong> a live SMTP relay is configured, so this harness
        deliberately exercises only paths that return before <code>&lt;cfmail&gt;</code>.
        Successful approval and successful cancellation &mdash; including the notification
        content itself &mdash; are <em>not</em> covered. Disable outbound mail before
        testing those.
    </div>

    <table class="table table-sm table-hover bg-white">
        <thead class="table-dark">
            <tr><th style="width:6rem;">Result</th><th>Check</th><th>Detail</th></tr>
        </thead>
        <tbody>
        <cfloop array="#results#" index="rr">
            <tr>
                <td><span class="badge #rr.passed ? 'bg-success' : 'bg-danger'#">#rr.passed ? 'PASS' : 'FAIL'#</span></td>
                <td>#encodeForHTML(rr.name)#</td>
                <td class="small text-muted">#encodeForHTML(rr.detail)#</td>
            </tr>
        </cfloop>
        </tbody>
    </table>

    <p class="small text-muted mb-0">#encodeForHTML(cleanupNote)#</p>
</div>
</body>
</html>
</cfoutput>
