-- =============================================================================
-- STAGING DEPLOYMENT SCRIPT
-- Everything the reservation-improvements branch needs in the database.
--
-- Target : CONFROOM schema on staging (inside2_docms)
-- Date   : 2026-07-30
-- Run as : CONFROOM  (this script uses USER_* data dictionary views, so it must
--          be run as the schema owner, not as a DBA looking at another schema)
--
-- HOW TO RUN
--   sqlplus CONFROOM/<password>@<tns> @STAGING_DEPLOY_2026-07-30.sql
--
-- PREREQUISITES
--   This script ADDS TO an existing schema; it does not create it. These must
--   already exist in the target: BOOKINGS, USERS, ROLES, ROOMS, NOTIFICATIONS,
--   SYSTEM_LOGS, NOTIFICATION_TYPES, NOTIFICATION_PREFERENCES.
--   If NOTIFICATION_TYPES is absent, apply assets/sql/notification_preferences.sql
--   first, then re-run this. Section 0 reports exactly which are missing.
--
-- IF YOU ARE RUNNING THIS IN A GUI TOOL (SQL Developer, Toad, PL/SQL Developer)
--   rather than sqlplus: the SET and PROMPT lines are sqlplus-only and will
--   error or be ignored -- skip them. Run each PL/SQL block (everything between
--   one slash-on-its-own-line and the next) as a single statement, and turn
--   DBMS_OUTPUT on first or you will see no report at all.
--   Every block is independently self-guarding, so a block run on its own still
--   reports rather than failing obscurely. The one thing you lose is the
--   automatic stop after section 0, so read section 0's output yourself before
--   running the rest.
--
-- The script prints a report as it goes. Read section 0 before letting it
-- continue -- it tells you what state staging is in.
--
-- PROPERTIES
--   * Idempotent. Every change is guarded by an existence check, so re-running
--     it is safe and makes no further changes. Verified by running it twice
--     against a database that already had every object.
--   * Purely additive. It creates columns, one table, two reference rows and
--     indexes. It does not drop or modify existing columns, and it does not
--     rewrite any row of business data.
--   * It will NOT silently change BOOKINGS.STATUS values or replace the status
--     constraint. Those need a decision -- see section 5.
--
-- RUN THIS BEFORE DEPLOYING THE CODE. Without it, cancellation, the dashboard
-- detail view and bulk approval all fail with ORA-00904 (invalid identifier).
--
-- NOT INCLUDED, DELIBERATELY
--   * add_recurring_bookings.sql -- the recurring-booking feature is unshipped
--     (non-functional at four separate layers) and this release does not use it.
--     Do not apply it as part of this deployment.
--   * audit_booking_data_integrity.sql -- a read-only audit tool, run separately.
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET PAGESIZE 100
SET FEEDBACK OFF

-- Section 0 ends in a hard gate that raises if the connected user does not own
-- BOOKINGS. This makes sqlplus stop there, before anything has been altered,
-- rather than running the whole deployment against the wrong schema.
WHENEVER SQLERROR EXIT FAILURE

PROMPT
PROMPT ==========================================================================
PROMPT  SECTION 0 -- PRE-FLIGHT REPORT (read-only, changes nothing)
PROMPT ==========================================================================

DECLARE
    v_n     NUMBER;
    v_txt   VARCHAR2(4000);
    v_owner VARCHAR2(128);

    FUNCTION col_exists(p_table VARCHAR2, p_col VARCHAR2) RETURN BOOLEAN IS
        c NUMBER;
    BEGIN
        SELECT COUNT(*) INTO c FROM USER_TAB_COLUMNS
         WHERE TABLE_NAME = p_table AND COLUMN_NAME = p_col;
        RETURN c > 0;
    END;

    FUNCTION tab_exists(p_table VARCHAR2) RETURN BOOLEAN IS
        c NUMBER;
    BEGIN
        SELECT COUNT(*) INTO c FROM USER_TABLES WHERE TABLE_NAME = p_table;
        RETURN c > 0;
    END;
BEGIN
    DBMS_OUTPUT.PUT_LINE('Connected as        : ' || USER);
    DBMS_OUTPUT.PUT_LINE('Database            : ' || SYS_CONTEXT('USERENV','DB_NAME'));
    DBMS_OUTPUT.PUT_LINE('Timestamp           : ' || TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE('---------------------------------------------------------------');

    -- Prerequisite tables the notification code depends on
    FOR t IN (SELECT COLUMN_VALUE tn FROM TABLE(SYS.ODCIVARCHAR2LIST(
                'BOOKINGS','USERS','ROLES','ROOMS','NOTIFICATIONS','SYSTEM_LOGS',
                'NOTIFICATION_TYPES','NOTIFICATION_PREFERENCES'))) LOOP
        IF tab_exists(t.tn) THEN
            DBMS_OUTPUT.PUT_LINE('table  ' || RPAD(t.tn,28) || 'present');
        ELSE
            -- Not owned by us. Say whether it exists elsewhere, because
            -- "connected as the wrong user" and "migration never applied" look
            -- identical in USER_TABLES and have opposite remedies.
            SELECT COUNT(*), MIN(OWNER) INTO v_n, v_owner
              FROM ALL_TABLES WHERE TABLE_NAME = t.tn;
            IF v_n > 0 THEN
                DBMS_OUTPUT.PUT_LINE('table  ' || RPAD(t.tn,28)
                    || '*** owned by ' || v_owner || ', not ' || USER || ' -- see note D');
            ELSE
                DBMS_OUTPUT.PUT_LINE('table  ' || RPAD(t.tn,28) || '*** MISSING -- see note A below');
            END IF;
        END IF;
    END LOOP;

    IF tab_exists('NOTIFICATION_REMINDER_LOG') THEN
        DBMS_OUTPUT.PUT_LINE('table  ' || RPAD('NOTIFICATION_REMINDER_LOG',28) || 'present');
    ELSE
        DBMS_OUTPUT.PUT_LINE('table  ' || RPAD('NOTIFICATION_REMINDER_LOG',28) || 'will be created (section 2)');
    END IF;

    DBMS_OUTPUT.PUT_LINE('---------------------------------------------------------------');

    -- The eight BOOKINGS columns this release requires
    v_n := 0;
    FOR c IN (SELECT COLUMN_VALUE cn FROM TABLE(SYS.ODCIVARCHAR2LIST(
                'BOOKED_FOR_NAME','BOOKED_FOR_EMAIL','BOOKED_FOR_DEPARTMENT',
                'CANCELLED_AT','CANCELLED_BY','CANCELLATION_REASON',
                'DECIDED_AT','DECIDED_BY'))) LOOP
        IF col_exists('BOOKINGS', c.cn) THEN
            v_n := v_n + 1;
        ELSE
            DBMS_OUTPUT.PUT_LINE('column BOOKINGS.' || RPAD(c.cn,24) || 'will be added (section 1)');
        END IF;
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('BOOKINGS audit columns already present: ' || v_n || ' of 8');

    DBMS_OUTPUT.PUT_LINE('---------------------------------------------------------------');

    -- SYSTEM_LOGS shape. The bulk-approval audit trail writes these names.
    IF col_exists('SYSTEM_LOGS','ACTION_TYPE') AND col_exists('SYSTEM_LOGS','CHANGE_DETAILS')
       AND col_exists('SYSTEM_LOGS','LOG_TIMESTAMP') AND col_exists('SYSTEM_LOGS','TABLE_NAME')
       AND col_exists('SYSTEM_LOGS','RECORD_ID') THEN
        DBMS_OUTPUT.PUT_LINE('SYSTEM_LOGS shape   : OK -- matches what the audit writer expects');
    ELSE
        DBMS_OUTPUT.PUT_LINE('SYSTEM_LOGS shape   : *** MISMATCH -- see note B below');
        IF col_exists('SYSTEM_LOGS','ACTION') THEN
            DBMS_OUTPUT.PUT_LINE('                      found legacy column ACTION (expected ACTION_TYPE)');
        END IF;
        IF col_exists('SYSTEM_LOGS','DETAILS') THEN
            DBMS_OUTPUT.PUT_LINE('                      found legacy column DETAILS (expected CHANGE_DETAILS)');
        END IF;
    END IF;

    -- Status constraint. This is the one that can break the release.
    BEGIN
        SELECT SEARCH_CONDITION INTO v_txt FROM USER_CONSTRAINTS
         WHERE TABLE_NAME = 'BOOKINGS' AND CONSTRAINT_NAME = 'CHK_BOOKINGS_STATUS';
        DBMS_OUTPUT.PUT_LINE('CHK_BOOKINGS_STATUS : ' || SUBSTR(v_txt,1,150));
    EXCEPTION WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('CHK_BOOKINGS_STATUS : ABSENT -- see note C below');
    END;

    -- Any status values the new code would not produce.
    -- Dynamic, and skipped when BOOKINGS is not ours: a static reference here
    -- would stop this entire pre-flight block from COMPILING on a target where
    -- BOOKINGS is not visible, so the report whose whole job is to tell you the
    -- target is wrong would never print. See the note above section 3.
    IF tab_exists('BOOKINGS') THEN
        EXECUTE IMMEDIATE
            'SELECT COUNT(*) FROM BOOKINGS WHERE STATUS IS NOT NULL '
         || 'AND LOWER(STATUS) NOT IN (''pending'',''approved'',''rejected'',''cancelled'',''archived'')'
            INTO v_n;
        DBMS_OUTPUT.PUT_LINE('Rows with a status outside the expected five: ' || v_n);

        EXECUTE IMMEDIATE
            'SELECT COUNT(*) FROM BOOKINGS WHERE STATUS IS NOT NULL AND STATUS <> LOWER(STATUS)'
            INTO v_n;
        DBMS_OUTPUT.PUT_LINE('Rows whose status is not lowercase          : ' || v_n
                             || CASE WHEN v_n > 0 THEN '   <-- see note C' ELSE '' END);
    ELSE
        DBMS_OUTPUT.PUT_LINE('Status scan skipped -- BOOKINGS is not owned by ' || USER);
    END IF;

    DBMS_OUTPUT.PUT_LINE('===============================================================');
    DBMS_OUTPUT.PUT_LINE('Note A: a missing prerequisite table means an earlier migration was');
    DBMS_OUTPUT.PUT_LINE('        never applied here. Apply notification_preferences.sql and');
    DBMS_OUTPUT.PUT_LINE('        system_notification_controls.sql first, then re-run this.');
    DBMS_OUTPUT.PUT_LINE('Note B: the bulk-approval audit entry writes ACTION_TYPE,');
    DBMS_OUTPUT.PUT_LINE('        CHANGE_DETAILS, LOG_TIMESTAMP, TABLE_NAME and RECORD_ID. If');
    DBMS_OUTPUT.PUT_LINE('        staging still has the legacy ACTION/DETAILS/TIMESTAMP shape,');
    DBMS_OUTPUT.PUT_LINE('        audit writes will fail with ORA-00904. Renaming columns on a');
    DBMS_OUTPUT.PUT_LINE('        live audit table is NOT done automatically -- section 4.');
    DBMS_OUTPUT.PUT_LINE('Note C: the application writes lowercase status values. If staging');
    DBMS_OUTPUT.PUT_LINE('        carries a constraint permitting only Confirmed/Cancelled, every');
    DBMS_OUTPUT.PUT_LINE('        approval will fail with ORA-02290 -- section 5.');
    DBMS_OUTPUT.PUT_LINE('Note D: the table exists but another schema owns it, so you are');
    DBMS_OUTPUT.PUT_LINE('        connected as the wrong user. This script reads USER_* views and');
    DBMS_OUTPUT.PUT_LINE('        alters the CONNECTED schema, so running it as anyone but the');
    DBMS_OUTPUT.PUT_LINE('        owner would report everything as missing and add the columns to');
    DBMS_OUTPUT.PUT_LINE('        the WRONG schema. Reconnect as the owner named above.');
    DBMS_OUTPUT.PUT_LINE('        The web datasource authenticates as WEBSCHEDULE_USER, which is');
    DBMS_OUTPUT.PUT_LINE('        NOT the owner -- do not use those credentials to run this.');
    DBMS_OUTPUT.PUT_LINE('===============================================================');

    -- HARD GATE -- the last thing section 0 does.
    -- Every section below this point alters the CONNECTED schema. If BOOKINGS
    -- is not ours then the target is wrong, and continuing would either fail
    -- statement by statement or, worse, succeed against the wrong schema. Abort
    -- while the database is still untouched. Paired with WHENEVER SQLERROR EXIT
    -- FAILURE above, this stops sqlplus here and returns a non-zero exit code.
    IF NOT tab_exists('BOOKINGS') THEN
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('*** STOPPING. BOOKINGS is not owned by ' || USER || ', so this is not');
        DBMS_OUTPUT.PUT_LINE('    the right connection for a deployment. Nothing has been changed.');
        DBMS_OUTPUT.PUT_LINE('    Reconnect as the schema owner (CONFROOM on staging) and re-run.');
        RAISE_APPLICATION_ERROR(-20001,
            'Wrong schema: connected as ' || USER || ', which does not own BOOKINGS. '
            || 'Reconnect as the CONFROOM schema owner. Nothing was changed.');
    END IF;
END;
/

-- Target confirmed. From here a failure should report and carry on rather than
-- abandon the run half-applied.
WHENEVER SQLERROR CONTINUE

PROMPT
PROMPT ==========================================================================
PROMPT  SECTION 1 -- BOOKINGS: Reservation-For and decision/cancellation audit
PROMPT ==========================================================================
PROMPT  Purely additive. Every column is nullable with no default, so existing
PROMPT  rows are untouched and simply carry NULL, which the application treats as
PROMPT  "not recorded" and falls back to the requester.

DECLARE
    TYPE t_cols IS TABLE OF VARCHAR2(200);
    v_cols t_cols := t_cols(
        'BOOKED_FOR_NAME       VARCHAR2(200)',
        'BOOKED_FOR_EMAIL      VARCHAR2(255)',
        'BOOKED_FOR_DEPARTMENT VARCHAR2(100)',
        'CANCELLED_AT          TIMESTAMP',
        'CANCELLED_BY          NUMBER',
        'CANCELLATION_REASON   VARCHAR2(1000)',
        'DECIDED_AT            TIMESTAMP',
        'DECIDED_BY            NUMBER'
    );
    v_name  VARCHAR2(128);
    v_count NUMBER;
    v_added NUMBER := 0;
BEGIN
    -- Independently self-guarding, so this block still reports usefully when it
    -- is run on its own in a GUI tool rather than through the whole script.
    SELECT COUNT(*) INTO v_count FROM USER_TABLES WHERE TABLE_NAME = 'BOOKINGS';
    IF v_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('*** SKIPPED -- BOOKINGS is not owned by ' || USER || '.');
        DBMS_OUTPUT.PUT_LINE('    Reconnect as the schema owner (CONFROOM) and re-run. Nothing changed.');
        RETURN;
    END IF;

    FOR i IN 1 .. v_cols.COUNT LOOP
        v_name := UPPER(REGEXP_SUBSTR(v_cols(i), '^\S+'));
        SELECT COUNT(*) INTO v_count FROM USER_TAB_COLUMNS
         WHERE TABLE_NAME = 'BOOKINGS' AND COLUMN_NAME = v_name;
        IF v_count = 0 THEN
            EXECUTE IMMEDIATE 'ALTER TABLE BOOKINGS ADD (' || v_cols(i) || ')';
            DBMS_OUTPUT.PUT_LINE('added   BOOKINGS.' || v_name);
            v_added := v_added + 1;
        ELSE
            DBMS_OUTPUT.PUT_LINE('skipped BOOKINGS.' || v_name || ' (already present)');
        END IF;
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('columns added: ' || v_added);
END;
/

-- Referential integrity for the two user references, added only if absent.
-- Note APPROVED_BY deliberately gets no foreign key: the archiving job used to
-- write APPROVED_BY = 0, so historical rows may hold an id that does not exist
-- and adding the constraint would fail validation. See
-- assets/sql/audit_booking_data_integrity.sql query 7 and remediation R1.
DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM USER_TABLES WHERE TABLE_NAME = 'BOOKINGS';
    IF v_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('*** SKIPPED -- BOOKINGS is not owned by ' || USER || '. Nothing changed.');
        RETURN;
    END IF;

    SELECT COUNT(*) INTO v_count FROM USER_CONSTRAINTS
     WHERE CONSTRAINT_NAME = 'FK_BOOKINGS_CANCELLED_BY';
    IF v_count = 0 THEN
        EXECUTE IMMEDIATE 'ALTER TABLE BOOKINGS ADD CONSTRAINT FK_BOOKINGS_CANCELLED_BY '
                       || 'FOREIGN KEY (CANCELLED_BY) REFERENCES USERS(USER_ID)';
        DBMS_OUTPUT.PUT_LINE('added   FK_BOOKINGS_CANCELLED_BY');
    ELSE
        DBMS_OUTPUT.PUT_LINE('skipped FK_BOOKINGS_CANCELLED_BY (already present)');
    END IF;

    SELECT COUNT(*) INTO v_count FROM USER_CONSTRAINTS
     WHERE CONSTRAINT_NAME = 'FK_BOOKINGS_DECIDED_BY';
    IF v_count = 0 THEN
        EXECUTE IMMEDIATE 'ALTER TABLE BOOKINGS ADD CONSTRAINT FK_BOOKINGS_DECIDED_BY '
                       || 'FOREIGN KEY (DECIDED_BY) REFERENCES USERS(USER_ID)';
        DBMS_OUTPUT.PUT_LINE('added   FK_BOOKINGS_DECIDED_BY');
    ELSE
        DBMS_OUTPUT.PUT_LINE('skipped FK_BOOKINGS_DECIDED_BY (already present)');
    END IF;
EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('FK creation reported: ' || SQLERRM);
    DBMS_OUTPUT.PUT_LINE('  (a foreign key can fail validation if historical rows hold an');
    DBMS_OUTPUT.PUT_LINE('   id that no longer exists in USERS. The release does not require');
    DBMS_OUTPUT.PUT_LINE('   these constraints; the columns alone are enough.)');
END;
/

COMMENT ON COLUMN BOOKINGS.BOOKED_FOR_NAME IS
    'Display name of the person the reservation is for. NULL on records created before this field existed, in which case the application falls back to the requester.';
COMMENT ON COLUMN BOOKINGS.BOOKED_FOR_EMAIL IS 'Email address of the person the reservation is for.';
COMMENT ON COLUMN BOOKINGS.BOOKED_FOR_DEPARTMENT IS 'Department or team of the person the reservation is for.';
COMMENT ON COLUMN BOOKINGS.CANCELLED_AT IS 'Timestamp the reservation was cancelled.';
COMMENT ON COLUMN BOOKINGS.CANCELLED_BY IS 'USER_ID of whoever cancelled the reservation.';
COMMENT ON COLUMN BOOKINGS.CANCELLATION_REASON IS
    'Optional reason supplied at cancellation, included in the requester notification. Stored separately so COMMENTS keeps the original meeting purpose.';
COMMENT ON COLUMN BOOKINGS.DECIDED_AT IS 'Timestamp the approve/reject decision was recorded.';
COMMENT ON COLUMN BOOKINGS.DECIDED_BY IS 'USER_ID of the approver who decided the request.';

PROMPT
PROMPT ==========================================================================
PROMPT  SECTION 2 -- NOTIFICATION_REMINDER_LOG
PROMPT ==========================================================================
PROMPT  Provides duplicate suppression for approver reminders. The unique
PROMPT  constraint is the mechanism: the reminder job inserts its claim row
PROMPT  BEFORE sending, so when two scheduler runs overlap exactly one wins and
PROMPT  the other skips. That guarantee holds across processes and servers, which
PROMPT  an application-level lock cannot.

DECLARE
    v_count NUMBER;
BEGIN
    -- This table's foreign keys point at USERS and BOOKINGS, so it can only be
    -- built in the schema that owns them.
    SELECT COUNT(*) INTO v_count FROM USER_TABLES WHERE TABLE_NAME IN ('BOOKINGS','USERS');
    IF v_count < 2 THEN
        DBMS_OUTPUT.PUT_LINE('*** SKIPPED -- BOOKINGS/USERS are not owned by ' || USER || '.');
        DBMS_OUTPUT.PUT_LINE('    Reconnect as the schema owner (CONFROOM) and re-run. Nothing changed.');
        RETURN;
    END IF;

    SELECT COUNT(*) INTO v_count FROM USER_TABLES WHERE TABLE_NAME = 'NOTIFICATION_REMINDER_LOG';
    IF v_count = 0 THEN
        EXECUTE IMMEDIATE '
            CREATE TABLE NOTIFICATION_REMINDER_LOG (
                LOG_ID            NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
                RECIPIENT_USER_ID NUMBER NOT NULL,
                NOTIFICATION_TYPE VARCHAR2(50) NOT NULL,
                INTERVAL_KEY      VARCHAR2(20) NOT NULL,
                BOOKING_ID        NUMBER,
                PENDING_COUNT     NUMBER,
                DELIVERY_STATUS   VARCHAR2(20) DEFAULT ''PENDING''
                    CHECK (DELIVERY_STATUS IN (''PENDING'',''SENT'',''FAILED'')),
                FAILURE_DETAIL    VARCHAR2(1000),
                CLAIMED_AT        TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                SENT_AT           TIMESTAMP,
                CONSTRAINT UQ_REMINDER_ONCE_PER_INTERVAL
                    UNIQUE (RECIPIENT_USER_ID, NOTIFICATION_TYPE, INTERVAL_KEY),
                CONSTRAINT FK_REMINDER_LOG_USER
                    FOREIGN KEY (RECIPIENT_USER_ID) REFERENCES USERS(USER_ID)
            )';
        DBMS_OUTPUT.PUT_LINE('created NOTIFICATION_REMINDER_LOG');
    ELSE
        DBMS_OUTPUT.PUT_LINE('skipped NOTIFICATION_REMINDER_LOG (already present)');
    END IF;

    SELECT COUNT(*) INTO v_count FROM USER_INDEXES WHERE INDEX_NAME = 'IDX_REMINDER_LOG_SENT_AT';
    IF v_count = 0 THEN
        EXECUTE IMMEDIATE 'CREATE INDEX IDX_REMINDER_LOG_SENT_AT ON NOTIFICATION_REMINDER_LOG(SENT_AT)';
        DBMS_OUTPUT.PUT_LINE('created IDX_REMINDER_LOG_SENT_AT');
    ELSE
        DBMS_OUTPUT.PUT_LINE('skipped IDX_REMINDER_LOG_SENT_AT (already present)');
    END IF;
END;
/

PROMPT
PROMPT ==========================================================================
PROMPT  SECTION 3 -- NOTIFICATION_TYPES reference rows
PROMPT ==========================================================================
PROMPT  ApprovalNotification resolves its recipients with an INNER JOIN against
PROMPT  NOTIFICATION_TYPES. Without these two rows the join matches nothing and
PROMPT  no approver is ever notified that a request needs action.

-- Every reference to NOTIFICATION_TYPES below is issued through EXECUTE
-- IMMEDIATE rather than as static SQL, and that is deliberate.
--
-- Static SQL in a PL/SQL block is resolved when the block is COMPILED, which
-- happens before any line of it executes. So if NOTIFICATION_TYPES is absent,
-- a statically-written INSERT makes the whole block fail to compile with
--     ORA-06550 ... PL/SQL: ORA-00942: table or view does not exist
--     ORA-06550 ... PL/SQL: SQL Statement ignored
-- and the IF guard never runs -- meaning the script aborts with a raw Oracle
-- error instead of printing the actionable message it was written to print.
-- A runtime existence check cannot protect a static reference; only dynamic
-- SQL defers name resolution to runtime.
DECLARE
    v_owned   NUMBER;
    v_visible NUMBER;
    v_owner   VARCHAR2(128);
    v_cols    NUMBER;
    v_rows    NUMBER;

    FUNCTION ins(p_sql VARCHAR2) RETURN NUMBER IS
    BEGIN
        EXECUTE IMMEDIATE p_sql;
        RETURN SQL%ROWCOUNT;
    END;
BEGIN
    SELECT COUNT(*) INTO v_owned
      FROM USER_TABLES WHERE TABLE_NAME = 'NOTIFICATION_TYPES';

    IF v_owned = 0 THEN
        -- USER_TABLES lists only what the connected user OWNS. A zero here has
        -- two very different causes and they need opposite remedies, so name
        -- which one it is instead of guessing.
        SELECT COUNT(*), MIN(OWNER) INTO v_visible, v_owner
          FROM ALL_TABLES WHERE TABLE_NAME = 'NOTIFICATION_TYPES';

        IF v_visible > 0 THEN
            DBMS_OUTPUT.PUT_LINE('*** WRONG SCHEMA. NOTIFICATION_TYPES exists and is owned by '
                                 || v_owner || ',');
            DBMS_OUTPUT.PUT_LINE('    but you are connected as ' || USER || '. This script must run as the');
            DBMS_OUTPUT.PUT_LINE('    schema owner. Reconnect as ' || v_owner || ' and run it again.');
            DBMS_OUTPUT.PUT_LINE('    Nothing was changed.');
        ELSE
            DBMS_OUTPUT.PUT_LINE('*** NOTIFICATION_TYPES does not exist in this schema, and is not');
            DBMS_OUTPUT.PUT_LINE('    visible to ' || USER || '. Either an earlier migration was never');
            DBMS_OUTPUT.PUT_LINE('    applied here -- apply assets/sql/notification_preferences.sql');
            DBMS_OUTPUT.PUT_LINE('    first, then re-run this script -- or the table is owned by');
            DBMS_OUTPUT.PUT_LINE('    another schema and no grant reaches you. Nothing was changed.');
            DBMS_OUTPUT.PUT_LINE('    Note: PL/SQL ignores privileges granted through a ROLE. If you');
            DBMS_OUTPUT.PUT_LINE('    can SELECT the table but this still reports it missing, you need');
            DBMS_OUTPUT.PUT_LINE('    a direct grant, not a role.');
        END IF;
    ELSE
        -- The table can exist with a different shape on an older environment.
        -- Check before inserting so the failure names the cause.
        SELECT COUNT(*) INTO v_cols FROM USER_TAB_COLUMNS
         WHERE TABLE_NAME = 'NOTIFICATION_TYPES'
           AND COLUMN_NAME IN ('TYPE_CODE','DISPLAY_NAME','DESCRIPTION','CATEGORY',
                               'DEFAULT_EMAIL_ENABLED','DEFAULT_IN_APP_ENABLED','ADMIN_ONLY');

        IF v_cols < 7 THEN
            DBMS_OUTPUT.PUT_LINE('*** NOTIFICATION_TYPES exists but has an unexpected shape: only '
                                 || v_cols || ' of the 7');
            DBMS_OUTPUT.PUT_LINE('    required columns are present (TYPE_CODE, DISPLAY_NAME,');
            DBMS_OUTPUT.PUT_LINE('    DESCRIPTION, CATEGORY, DEFAULT_EMAIL_ENABLED,');
            DBMS_OUTPUT.PUT_LINE('    DEFAULT_IN_APP_ENABLED, ADMIN_ONLY). No rows were inserted.');
            DBMS_OUTPUT.PUT_LINE('    Reconcile the table against notification_preferences.sql.');
        ELSE
            BEGIN
                v_rows := ins(q'[INSERT INTO NOTIFICATION_TYPES (
                        TYPE_CODE, DISPLAY_NAME, DESCRIPTION, CATEGORY,
                        DEFAULT_EMAIL_ENABLED, DEFAULT_IN_APP_ENABLED, ADMIN_ONLY)
                    SELECT 'BOOKING_PENDING_APPROVAL', 'Booking Pending Approval',
                           'Immediate alert sent to approvers when a reservation request is submitted',
                           'Approval Workflow', 1, 1, 1
                      FROM DUAL
                     WHERE NOT EXISTS (SELECT 1 FROM NOTIFICATION_TYPES
                                        WHERE TYPE_CODE = 'BOOKING_PENDING_APPROVAL')]');
                DBMS_OUTPUT.PUT_LINE('BOOKING_PENDING_APPROVAL        rows inserted: ' || v_rows);

                v_rows := ins(q'[INSERT INTO NOTIFICATION_TYPES (
                        TYPE_CODE, DISPLAY_NAME, DESCRIPTION, CATEGORY,
                        DEFAULT_EMAIL_ENABLED, DEFAULT_IN_APP_ENABLED, ADMIN_ONLY)
                    SELECT 'BOOKING_PENDING_APPROVAL_DIGEST', 'Booking Pending Approval Digest',
                           'Recurring summary of reservation requests still awaiting a decision',
                           'Approval Workflow', 1, 0, 1
                      FROM DUAL
                     WHERE NOT EXISTS (SELECT 1 FROM NOTIFICATION_TYPES
                                        WHERE TYPE_CODE = 'BOOKING_PENDING_APPROVAL_DIGEST')]');
                DBMS_OUTPUT.PUT_LINE('BOOKING_PENDING_APPROVAL_DIGEST rows inserted: ' || v_rows);
            EXCEPTION WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('*** Could not insert the reference rows: ' || SQLERRM);
                DBMS_OUTPUT.PUT_LINE('    No approver notification will be sent until these two rows');
                DBMS_OUTPUT.PUT_LINE('    exist. Resolve the error above and re-run this script.');
            END;
        END IF;
    END IF;
END;
/

COMMIT;

PROMPT
PROMPT ==========================================================================
PROMPT  SECTION 4 -- SYSTEM_LOGS shape (REPORT ONLY -- no automatic change)
PROMPT ==========================================================================

DECLARE
    v_ok NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_ok FROM USER_TAB_COLUMNS
     WHERE TABLE_NAME = 'SYSTEM_LOGS'
       AND COLUMN_NAME IN ('ACTION_TYPE','CHANGE_DETAILS','LOG_TIMESTAMP','TABLE_NAME','RECORD_ID');

    IF v_ok = 5 THEN
        DBMS_OUTPUT.PUT_LINE('SYSTEM_LOGS is the expected shape. Bulk-approval audit entries will write.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('*** ACTION REQUIRED. SYSTEM_LOGS has ' || v_ok || ' of the 5 expected columns.');
        DBMS_OUTPUT.PUT_LINE('    The bulk-approval audit entry writes:');
        DBMS_OUTPUT.PUT_LINE('      USER_ID, ACTION_TYPE, CHANGE_DETAILS, TABLE_NAME, RECORD_ID, LOG_TIMESTAMP');
        DBMS_OUTPUT.PUT_LINE('    Missing columns cause ORA-00904 and the audit entry is skipped.');
        DBMS_OUTPUT.PUT_LINE('    Approval itself still succeeds -- writeAuditEntry logs and swallows');
        DBMS_OUTPUT.PUT_LINE('    the failure -- so this is not release-blocking, but you lose the');
        DBMS_OUTPUT.PUT_LINE('    audit trail until it is corrected.');
        DBMS_OUTPUT.PUT_LINE('    Renaming columns on a live audit table is not done automatically.');
        DBMS_OUTPUT.PUT_LINE('    If the legacy names are present, the mapping is:');
        DBMS_OUTPUT.PUT_LINE('      ALTER TABLE SYSTEM_LOGS RENAME COLUMN ACTION    TO ACTION_TYPE;');
        DBMS_OUTPUT.PUT_LINE('      ALTER TABLE SYSTEM_LOGS RENAME COLUMN DETAILS   TO CHANGE_DETAILS;');
        DBMS_OUTPUT.PUT_LINE('      ALTER TABLE SYSTEM_LOGS RENAME COLUMN TIMESTAMP TO LOG_TIMESTAMP;');
        DBMS_OUTPUT.PUT_LINE('      ALTER TABLE SYSTEM_LOGS ADD (TABLE_NAME VARCHAR2(100), RECORD_ID VARCHAR2(100));');
        DBMS_OUTPUT.PUT_LINE('    Check for other readers of those columns before renaming.');
    END IF;
END;
/

PROMPT
PROMPT ==========================================================================
PROMPT  SECTION 5 -- BOOKINGS.STATUS constraint (REPORT ONLY -- no automatic change)
PROMPT ==========================================================================
PROMPT  This is the one thing that can break the release outright.

DECLARE
    v_cond    VARCHAR2(4000);
    v_bad     NUMBER;
    v_mixed   NUMBER;
    v_present NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_present FROM USER_TABLES WHERE TABLE_NAME = 'BOOKINGS';
    IF v_present = 0 THEN
        DBMS_OUTPUT.PUT_LINE('*** SKIPPED -- BOOKINGS is not owned by ' || USER || '.');
        DBMS_OUTPUT.PUT_LINE('    Reconnect as the schema owner (CONFROOM) to get this report.');
        RETURN;
    END IF;

    SELECT COUNT(*) INTO v_present FROM USER_CONSTRAINTS
     WHERE TABLE_NAME = 'BOOKINGS' AND CONSTRAINT_NAME = 'CHK_BOOKINGS_STATUS';

    -- Dynamic for the same reason as sections 0 and 3: a static BOOKINGS
    -- reference would stop this report block from compiling wherever BOOKINGS
    -- is not visible.
    EXECUTE IMMEDIATE
        'SELECT COUNT(*) FROM BOOKINGS WHERE STATUS IS NOT NULL '
     || 'AND LOWER(STATUS) NOT IN (''pending'',''approved'',''rejected'',''cancelled'',''archived'')'
        INTO v_bad;

    EXECUTE IMMEDIATE
        'SELECT COUNT(*) FROM BOOKINGS WHERE STATUS IS NOT NULL AND STATUS <> LOWER(STATUS)'
        INTO v_mixed;

    IF v_present = 1 THEN
        SELECT SEARCH_CONDITION INTO v_cond FROM USER_CONSTRAINTS
         WHERE TABLE_NAME = 'BOOKINGS' AND CONSTRAINT_NAME = 'CHK_BOOKINGS_STATUS';
        DBMS_OUTPUT.PUT_LINE('Constraint present: ' || SUBSTR(v_cond,1,160));

        IF LOWER(v_cond) LIKE '%''pending''%' AND LOWER(v_cond) LIKE '%''approved''%' THEN
            DBMS_OUTPUT.PUT_LINE('-> Permits the lowercase vocabulary. Nothing to do.');
        ELSE
            DBMS_OUTPUT.PUT_LINE('*** RELEASE BLOCKER. The constraint does not permit the values the');
            DBMS_OUTPUT.PUT_LINE('    application writes (lowercase pending/approved/rejected/cancelled/');
            DBMS_OUTPUT.PUT_LINE('    archived). Every approval will fail with ORA-02290.');
            DBMS_OUTPUT.PUT_LINE('    Replacing it is NOT automatic because existing rows may hold values');
            DBMS_OUTPUT.PUT_LINE('    the new constraint would reject. See the remediation below.');
        END IF;
    ELSE
        DBMS_OUTPUT.PUT_LINE('Constraint CHK_BOOKINGS_STATUS is ABSENT.');
        DBMS_OUTPUT.PUT_LINE('-> The application will work: it writes lowercase values and compares');
        DBMS_OUTPUT.PUT_LINE('   with LOWER(), so nothing depends on the constraint existing.');
        DBMS_OUTPUT.PUT_LINE('   Adding it is optional and is left to you (statement below).');
    END IF;

    DBMS_OUTPUT.PUT_LINE('Rows outside the five expected values : ' || v_bad);
    DBMS_OUTPUT.PUT_LINE('Rows whose status is not lowercase    : ' || v_mixed);

    IF v_bad > 0 OR v_mixed > 0 THEN
        DBMS_OUTPUT.PUT_LINE('*** Data needs attention. The application compares status with LOWER(),');
        DBMS_OUTPUT.PUT_LINE('    so mixed-case rows are matched correctly on READ, but any row whose');
        DBMS_OUTPUT.PUT_LINE('    value is outside the five will not appear in any status-filtered');
        DBMS_OUTPUT.PUT_LINE('    view. Inspect them before normalising:');
        DBMS_OUTPUT.PUT_LINE('      SELECT STATUS, COUNT(*) FROM BOOKINGS GROUP BY STATUS;');
    END IF;
END;
/

PROMPT
PROMPT  -- OPTIONAL REMEDIATION for section 5. Review before running. These
PROMPT  -- statements MODIFY DATA and are intentionally left commented out.
PROMPT  --
PROMPT  -- 1. Inspect first:
PROMPT  --      SELECT STATUS, COUNT(*) FROM BOOKINGS GROUP BY STATUS ORDER BY 2 DESC;
PROMPT  --
PROMPT  -- 2. Normalise casing (safe -- same values, lowercased):
PROMPT  --      UPDATE BOOKINGS SET STATUS = LOWER(STATUS)
PROMPT  --       WHERE STATUS IS NOT NULL AND STATUS <> LOWER(STATUS);
PROMPT  --
PROMPT  -- 3. Map any retired vocabulary. 'Confirmed' was the old equivalent of
PROMPT  --    'approved'. CONFIRM THIS MAPPING IS RIGHT FOR YOUR DATA FIRST:
PROMPT  --      UPDATE BOOKINGS SET STATUS = 'approved' WHERE LOWER(STATUS) = 'confirmed';
PROMPT  --
PROMPT  -- 4. Then replace the constraint:
PROMPT  --      ALTER TABLE BOOKINGS DROP CONSTRAINT CHK_BOOKINGS_STATUS;
PROMPT  --      ALTER TABLE BOOKINGS ADD CONSTRAINT CHK_BOOKINGS_STATUS
PROMPT  --        CHECK (STATUS IN ('pending','approved','rejected','cancelled','archived'));
PROMPT  --      COMMIT;

PROMPT
PROMPT ==========================================================================
PROMPT  SECTION 6 -- POST-FLIGHT VERIFICATION
PROMPT ==========================================================================

DECLARE
    v_cols NUMBER; v_tab NUMBER; v_uq NUMBER; v_types NUMBER; v_ok BOOLEAN := TRUE;
BEGIN
    SELECT COUNT(*) INTO v_cols FROM USER_TAB_COLUMNS
     WHERE TABLE_NAME = 'BOOKINGS'
       AND COLUMN_NAME IN ('BOOKED_FOR_NAME','BOOKED_FOR_EMAIL','BOOKED_FOR_DEPARTMENT',
                           'CANCELLED_AT','CANCELLED_BY','CANCELLATION_REASON','DECIDED_AT','DECIDED_BY');
    SELECT COUNT(*) INTO v_tab  FROM USER_TABLES WHERE TABLE_NAME = 'NOTIFICATION_REMINDER_LOG';
    SELECT COUNT(*) INTO v_uq   FROM USER_CONSTRAINTS WHERE CONSTRAINT_NAME = 'UQ_REMINDER_ONCE_PER_INTERVAL';

    -- Dynamic for the same reason as section 3: a static reference to
    -- NOTIFICATION_TYPES would stop this whole verification block from
    -- compiling on an environment where the table is missing, so the report
    -- that is supposed to TELL you it is missing would never print.
    BEGIN
        EXECUTE IMMEDIATE
            'SELECT COUNT(*) FROM NOTIFICATION_TYPES '
         || 'WHERE TYPE_CODE LIKE ''BOOKING_PENDING_APPROVAL%'''
            INTO v_types;
    EXCEPTION WHEN OTHERS THEN
        v_types := -1;   -- table absent or unreadable; reported as INCOMPLETE below
    END;

    DBMS_OUTPUT.PUT_LINE('BOOKINGS audit columns          : ' || v_cols  || ' of 8   ' || CASE WHEN v_cols=8 THEN 'OK' ELSE '*** INCOMPLETE' END);
    DBMS_OUTPUT.PUT_LINE('NOTIFICATION_REMINDER_LOG       : ' || v_tab   || ' of 1   ' || CASE WHEN v_tab=1 THEN 'OK' ELSE '*** MISSING' END);
    DBMS_OUTPUT.PUT_LINE('UQ_REMINDER_ONCE_PER_INTERVAL   : ' || v_uq    || ' of 1   ' || CASE WHEN v_uq=1 THEN 'OK' ELSE '*** MISSING' END);
    IF v_types < 0 THEN
        DBMS_OUTPUT.PUT_LINE('Pending-approval type rows      : *** NOTIFICATION_TYPES missing or unreadable');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Pending-approval type rows      : ' || v_types || ' of 2   ' || CASE WHEN v_types=2 THEN 'OK' ELSE '*** INCOMPLETE' END);
    END IF;

    IF v_cols = 8 AND v_tab = 1 AND v_uq = 1 AND v_types = 2 THEN
        DBMS_OUTPUT.PUT_LINE('---------------------------------------------------------------');
        DBMS_OUTPUT.PUT_LINE('RESULT: the schema is ready for the application code.');
        DBMS_OUTPUT.PUT_LINE('Re-read sections 4 and 5 -- neither is fixed automatically, and');
        DBMS_OUTPUT.PUT_LINE('section 5 can still block approvals.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('---------------------------------------------------------------');
        DBMS_OUTPUT.PUT_LINE('RESULT: *** NOT READY. Resolve the items marked above and re-run.');
    END IF;
END;
/

SET FEEDBACK ON

PROMPT
PROMPT ==========================================================================
PROMPT  ROLLBACK
PROMPT ==========================================================================
PROMPT  Dropping these columns permanently discards every recorded Reservation For
PROMPT  value, cancellation reason and approval audit entry. Export first if there
PROMPT  is any chance they are needed:
PROMPT
PROMPT    CREATE TABLE BOOKINGS_AUDIT_BACKUP AS
PROMPT    SELECT BOOKING_ID, BOOKED_FOR_NAME, BOOKED_FOR_EMAIL, BOOKED_FOR_DEPARTMENT,
PROMPT           CANCELLED_AT, CANCELLED_BY, CANCELLATION_REASON, DECIDED_AT, DECIDED_BY
PROMPT      FROM BOOKINGS
PROMPT     WHERE BOOKED_FOR_NAME IS NOT NULL OR CANCELLATION_REASON IS NOT NULL
PROMPT        OR DECIDED_BY IS NOT NULL;
PROMPT
PROMPT  Then, in this order:
PROMPT    ALTER TABLE BOOKINGS DROP CONSTRAINT FK_BOOKINGS_CANCELLED_BY;
PROMPT    ALTER TABLE BOOKINGS DROP CONSTRAINT FK_BOOKINGS_DECIDED_BY;
PROMPT    ALTER TABLE BOOKINGS DROP COLUMN BOOKED_FOR_NAME;
PROMPT    ALTER TABLE BOOKINGS DROP COLUMN BOOKED_FOR_EMAIL;
PROMPT    ALTER TABLE BOOKINGS DROP COLUMN BOOKED_FOR_DEPARTMENT;
PROMPT    ALTER TABLE BOOKINGS DROP COLUMN CANCELLED_AT;
PROMPT    ALTER TABLE BOOKINGS DROP COLUMN CANCELLED_BY;
PROMPT    ALTER TABLE BOOKINGS DROP COLUMN CANCELLATION_REASON;
PROMPT    ALTER TABLE BOOKINGS DROP COLUMN DECIDED_AT;
PROMPT    ALTER TABLE BOOKINGS DROP COLUMN DECIDED_BY;
PROMPT    DROP TABLE NOTIFICATION_REMINDER_LOG CASCADE CONSTRAINTS;
PROMPT    DELETE FROM NOTIFICATION_TYPES
PROMPT     WHERE TYPE_CODE IN ('BOOKING_PENDING_APPROVAL','BOOKING_PENDING_APPROVAL_DIGEST');
PROMPT    COMMIT;
PROMPT
PROMPT  Deleting a NOTIFICATION_TYPES row cascades to any per-user preference
PROMPT  override saved against it. Rolling back also requires reverting the
PROMPT  application code, or cancellation, the detail view and bulk approval will
PROMPT  fail with ORA-00904.
PROMPT ==========================================================================
