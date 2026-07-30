<!---
    SUPERSEDED AND DELIBERATELY DISABLED — 2026-07-29

    Cancellation is handled by cfcs/dashboard-data.cfc?method=cancelBooking,
    which is what index.html actually calls. This endpoint is referenced by no
    frontend code (verified by grep across .html/.js/.cfm/.cfc).

    Why it is disabled rather than merely left alone:

      1. It issued a hard `DELETE FROM CONFROOM.BOOKINGS`, destroying the
         reservation row outright. The supported path sets STATUS = 'cancelled'
         and records CANCELLED_BY / CANCELLED_AT / CANCELLATION_REASON, keeping
         the history the dashboard and audit trail depend on.
      2. It queried columns that do not exist -- BOOKINGID and EMPLID on
         BOOKINGS, whose real columns are BOOKING_ID and USER_ID -- so it could
         only ever have raised ORA-00904.
      3. It sent no cancellation notification, so Requirement 1 could not be met
         through it.
      4. It had no CSRF protection on a destructive operation.

    The reason it appeared harmless is the dangerous part: it fails closed today
    only because `session.user.EMPLID` is never set -- this application has no
    Application.cfc, so there is no session scope. Introducing one (the
    documented fix for the authentication gap) would ACTIVATE this endpoint and
    give it a working session to authorise against, at which point an
    unreferenced, unprotected hard-delete becomes reachable over HTTP.

    Rather than leave that trap, the handler now refuses unconditionally.
    Restoring it would mean rewriting it against the real schema and routing it
    through the supported cancellation path -- at which point it is redundant.

    Safe to delete outright; kept only so the change is visible in review.
--->
<cfsetting showdebugoutput="false">

<cflog type="warning" file="booking_cancellations"
       text="Disabled endpoint api/cancel-booking.cfm was called from #cgi.REMOTE_ADDR# (referer: #cgi.HTTP_REFERER#). Use cfcs/dashboard-data.cfc?method=cancelBooking.">

<cfheader statuscode="410" statustext="Gone">
<cfcontent type="application/json">
<cfoutput>#serializeJSON({
    "success": false,
    "message": "This endpoint has been retired. Cancellation is handled by cfcs/dashboard-data.cfc?method=cancelBooking.",
    "supersededBy": "cfcs/dashboard-data.cfc?method=cancelBooking"
})#</cfoutput>
