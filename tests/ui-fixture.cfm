<!---
    Fixture endpoint for tests/playwright/bulk-approval-ui.spec.js.

    ?mode=seed&count=N  -> remove existing fixtures, then create N pending plus
                           one approved reservation, all tagged with the marker
    ?mode=clean         -> remove every tagged reservation

    DEVELOPMENT ONLY. Refuses to run on the staging and production hostnames
    because it writes and deletes reservation rows. Every row it creates carries
    the marker in COMMENTS, and it only ever deletes rows carrying that marker,
    so real reservations are never touched.

    Seeding cleans first, so the endpoint is idempotent and a re-run cannot leave
    duplicate fixtures behind.
--->

<!--- Requirement 5 acceptance criteria this endpoint supports:
      * select-all limited to eligible rows in the current filtered result set
      * interface responsive with at least 50 selected requests (default 55)
      * only pending requests are selectable (hence the one approved row) --->
<cfsetting showdebugoutput="false" requesttimeout="180">
<cfparam name="url.mode" default="clean">
<cfparam name="url.count" default="55">

<cfif ListFindNoCase("cmapps,s-cmapps", ListFirst(CGI.SERVER_NAME,'.'))>
    <cfoutput>{"error":"refused on this host"}</cfoutput><cfabort>
</cfif>

<cfset DS = "inside2_docmd"><cfset DU = "CONFROOM"><cfset DP = "1DOCMOA4CNFRM3">
<cfset MARK = "UIFIXTURE">
<cfset out = {}>

<cftry>
    <!--- Always clean first so seeding is repeatable. --->
    <cfquery datasource="#DS#" username="#DU#" password="#DP#" result="dc">
        DELETE FROM CONFROOM.BOOKINGS WHERE COMMENTS LIKE <cfqueryparam value="#MARK#%" cfsqltype="cf_sql_varchar">
    </cfquery>
    <cfset out.deleted = dc.recordCount>

    <cfif url.mode EQ "seed">
        <cfquery name="qadmin" datasource="#DS#" username="#DU#" password="#DP#">
            SELECT u.USER_ID FROM CONFROOM.USERS u JOIN CONFROOM.ROLES ro ON ro.ROLE_ID=u.ROLE_ID
            WHERE UPPER(u.STATUS)='ACTIVE' AND UPPER(ro.ROLE_NAME) IN ('ADMIN','SITE ADMIN') AND ROWNUM=1
        </cfquery>
        <cfquery name="qroom" datasource="#DS#" username="#DU#" password="#DP#">
            SELECT ROOM_ID FROM CONFROOM.ROOMS ORDER BY ROOM_ID FETCH FIRST 1 ROWS ONLY
        </cfquery>

        <cfset n = min(val(url.count), 120)>
        <!--- Spread across distinct future days so none of them collide. --->
        <cfloop from="1" to="#n#" index="i">
            <cfset d = dateFormat(dateAdd("d", i, createDate(2032,1,1)), "yyyy-mm-dd")>
            <cfquery datasource="#DS#" username="#DU#" password="#DP#">
                INSERT INTO CONFROOM.BOOKINGS
                    (USER_ID, ROOM_ID, START_TIME, END_TIME, STATUS, COMMENTS, CREATED_AT, UPDATED_AT)
                VALUES (
                    <cfqueryparam value="#qadmin.USER_ID#" cfsqltype="cf_sql_numeric">,
                    <cfqueryparam value="#qroom.ROOM_ID#" cfsqltype="cf_sql_numeric">,
                    TO_DATE(<cfqueryparam value="#d# 09:00" cfsqltype="cf_sql_varchar">, 'YYYY-MM-DD HH24:MI'),
                    TO_DATE(<cfqueryparam value="#d# 10:00" cfsqltype="cf_sql_varchar">, 'YYYY-MM-DD HH24:MI'),
                    'pending',
                    <cfqueryparam value="#MARK# pending #i#" cfsqltype="cf_sql_varchar">,
                    CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            </cfquery>
        </cfloop>

        <!--- One approved row: the grid must not offer a checkbox for it. --->
        <cfquery datasource="#DS#" username="#DU#" password="#DP#">
            INSERT INTO CONFROOM.BOOKINGS
                (USER_ID, ROOM_ID, START_TIME, END_TIME, STATUS, COMMENTS, CREATED_AT, UPDATED_AT)
            VALUES (
                <cfqueryparam value="#qadmin.USER_ID#" cfsqltype="cf_sql_numeric">,
                <cfqueryparam value="#qroom.ROOM_ID#" cfsqltype="cf_sql_numeric">,
                TO_DATE('2032-06-01 09:00','YYYY-MM-DD HH24:MI'),
                TO_DATE('2032-06-01 10:00','YYYY-MM-DD HH24:MI'),
                'approved',
                <cfqueryparam value="#MARK# approved marker" cfsqltype="cf_sql_varchar">,
                CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        </cfquery>

        <!--- One pending row booked on someone else's behalf, so the approver view
              can be checked for showing "Requested By" and "Reservation For" as
              distinct values. The name carries markup to prove it is escaped. --->
        <cfquery datasource="#DS#" username="#DU#" password="#DP#">
            INSERT INTO CONFROOM.BOOKINGS
                (USER_ID, ROOM_ID, START_TIME, END_TIME, STATUS, COMMENTS, CREATED_AT, UPDATED_AT,
                 BOOKED_FOR_NAME, BOOKED_FOR_EMAIL, BOOKED_FOR_DEPARTMENT)
            VALUES (
                <cfqueryparam value="#qadmin.USER_ID#" cfsqltype="cf_sql_numeric">,
                <cfqueryparam value="#qroom.ROOM_ID#" cfsqltype="cf_sql_numeric">,
                TO_DATE('2032-07-01 09:00','YYYY-MM-DD HH24:MI'),
                TO_DATE('2032-07-01 10:00','YYYY-MM-DD HH24:MI'),
                'pending',
                <cfqueryparam value="#MARK# onbehalf marker" cfsqltype="cf_sql_varchar">,
                CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,
                <cfqueryparam value="Dr Onbehalf <script>alert(1)</script>" cfsqltype="cf_sql_varchar">,
                <cfqueryparam value="onbehalf@example.invalid" cfsqltype="cf_sql_varchar">,
                <cfqueryparam value="Haematology" cfsqltype="cf_sql_varchar">)
        </cfquery>

        <cfset out.seededPending = n + 1>
        <cfset out.seededApproved = 1>
        <cfset out.seededOnBehalf = 1>
        <cfset out.adminUserId = qadmin.USER_ID>
    </cfif>

    <cfquery name="qleft" datasource="#DS#" username="#DU#" password="#DP#">
        SELECT COUNT(*) AS C FROM CONFROOM.BOOKINGS WHERE COMMENTS LIKE <cfqueryparam value="#MARK#%" cfsqltype="cf_sql_varchar">
    </cfquery>
    <cfset out.markedRowsNow = qleft.C>
    <cfset out.ok = true>
<cfcatch>
    <cfset out.ok = false>
    <cfset out.error = "#cfcatch.message# | #cfcatch.detail#">
</cfcatch>
</cftry>

<cfcontent type="application/json"><cfoutput>#serializeJSON(out)#</cfoutput>
