-- =============================================================================
-- ROOM RESERVATION -- COMPLETE DATABASE DEPLOYMENT
--
-- ONE FILE. Run this and nothing else. It contains every schema change the
-- reservation-improvements release needs, in dependency order.
--
-- Target  : the CONFROOM schema (verified against staging PS17 on 2026-07-30)
-- Run as  : the schema owner -- CONFROOM. See "WHO TO RUN IT AS" below.
--
-- HOW TO RUN
--   sqlplus CONFROOM/<password>@<tns> @DEPLOY_ALL_2026-07-30.sql > deploy.log
--
-- Then read deploy.log. The script reports what it did, what it skipped, and
-- ends with a READY / NOT READY verdict. Two items are reported for a human
-- decision and never changed automatically -- sections 7 and 8.
--
-- RUN THIS BEFORE DEPLOYING THE APPLICATION CODE. Without it, cancellation,
-- the dashboard detail view and bulk approval fail with ORA-00904, and no
-- approver is ever notified that a request needs action.
--
-- -----------------------------------------------------------------------------
-- THIS FILE SUPERSEDES, AND YOU SHOULD NOT ALSO RUN:
--   * assets/sql/notification_preferences.sql
--   * assets/sql/system_notification_controls.sql
--   * assets/sql/add_pending_approval_notification_types.sql
--   * assets/sql/add_notification_reminder_log.sql
--   * assets/sql/add_reservation_for_and_decision_audit.sql
--   * assets/sql/STAGING_DEPLOY_2026-07-30.sql
-- Everything they do is folded in here, with two bugs fixed that made
-- notification_preferences.sql fail partway through on Oracle:
--   1. It used multi-row "INSERT ... VALUES (...),(...)" -- valid in MySQL and
--      Postgres, NOT valid in Oracle. It raised an error, and on staging that
--      aborted the run: the tables were created but left with ZERO rows and
--      none of its three indexes were created. Rewritten here as one guarded
--      INSERT ... SELECT FROM DUAL per row.
--   2. Its admin back-fill filtered on USERS.ROLE, a column that does not
--      exist. USERS has ROLE_ID, which joins to ROLES.ROLE_NAME. As written it
--      would have failed with ORA-00904 had it been reached. Corrected in
--      section 5.
--
-- NOT INCLUDED, DELIBERATELY
--   * add_recurring_bookings.sql -- the recurring-booking feature is unshipped
--     and this release does not use it. Do not apply it.
--   * audit_booking_data_integrity.sql -- a read-only audit tool, run when you
--     like; it changes nothing.
--
-- -----------------------------------------------------------------------------
-- WHO TO RUN IT AS
--   Must be the schema owner, because this reads USER_* dictionary views and
--   alters the CONNECTED schema. Section 0 verifies this and aborts before
--   changing anything if you are connected as anyone else.
--   Do NOT use the web application's datasource login. On dev and staging that
--   authenticates as WEBSCHEDULE_USER, which owns none of these tables.
--
-- PROPERTIES
--   * Idempotent. Every change is guarded by an existence check, so re-running
--     changes nothing further. This matters here: staging is already PARTIALLY
--     applied, and the script is designed to complete it rather than fail.
--   * Additive. It creates columns, tables, a sequence, triggers, indexes and
--     reference rows. It does not drop or retype any existing column and does
--     not rewrite any row of existing business data.
--   * Order-safe. Every block guards its own prerequisites, so a block run on
--     its own still reports rather than failing obscurely.
--
-- IF YOU RUN THIS IN A GUI TOOL (SQL Developer, Toad, PL/SQL Developer)
--   The SET and PROMPT lines are sqlplus-only -- skip them. Execute each block
--   (everything between one slash-on-its-own-line and the next) as a single
--   statement, in order, and turn DBMS_OUTPUT on first or you will see no
--   report at all. You lose only the automatic stop after section 0, so read
--   section 0's output yourself before continuing.
--
-- BEFORE YOU START
--   Confirm a backup or snapshot exists. Oracle DDL auto-commits, so there is
--   no ROLLBACK for the structural changes; recovery means the DROP statements
--   at the end, which discard whatever has been recorded since.
--   ALTER TABLE needs a brief exclusive lock on BOOKINGS. Adding nullable
--   columns with no default is a fast metadata-only change, but if the
--   application is mid-transaction you may get ORA-00054 (resource busy).
--   Nothing is left half-done that re-running will not finish.
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET PAGESIZE 100
SET FEEDBACK OFF

-- Section 0 ends in a hard gate that raises if the connected user does not own
-- BOOKINGS, so sqlplus stops there before anything has been altered.
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
    DBMS_OUTPUT.PUT_LINE('Host                : ' || SYS_CONTEXT('USERENV','SERVER_HOST'));
    DBMS_OUTPUT.PUT_LINE('Timestamp           : ' || TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE('---------------------------------------------------------------');

    -- Tables this release depends on but does NOT create.
    FOR t IN (SELECT COLUMN_VALUE tn FROM TABLE(SYS.ODCIVARCHAR2LIST(
                'BOOKINGS','USERS','ROLES','ROOMS','NOTIFICATIONS','SYSTEM_LOGS'))) LOOP
        IF tab_exists(t.tn) THEN
            DBMS_OUTPUT.PUT_LINE('required  ' || RPAD(t.tn,28) || 'present');
        ELSE
            SELECT COUNT(*), MIN(OWNER) INTO v_n, v_owner
              FROM ALL_TABLES WHERE TABLE_NAME = t.tn;
            IF v_n > 0 THEN
                DBMS_OUTPUT.PUT_LINE('required  ' || RPAD(t.tn,28)
                    || '*** owned by ' || v_owner || ', not ' || USER || ' -- note D');
            ELSE
                DBMS_OUTPUT.PUT_LINE('required  ' || RPAD(t.tn,28) || '*** MISSING -- note A');
            END IF;
        END IF;
    END LOOP;

    -- Tables this script creates if absent.
    FOR t IN (SELECT COLUMN_VALUE tn FROM TABLE(SYS.ODCIVARCHAR2LIST(
                'NOTIFICATION_TYPES','NOTIFICATION_PREFERENCES','NOTIFICATION_REMINDER_LOG'))) LOOP
        IF tab_exists(t.tn) THEN
            DBMS_OUTPUT.PUT_LINE('creates   ' || RPAD(t.tn,28) || 'already present');
        ELSE
            DBMS_OUTPUT.PUT_LINE('creates   ' || RPAD(t.tn,28) || 'will be created');
        END IF;
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('---------------------------------------------------------------');

    -- How much of the notification reference data is actually there. A table
    -- that exists but is EMPTY is the state a half-applied migration leaves,
    -- and it is indistinguishable from "applied" unless you count rows.
    IF tab_exists('NOTIFICATION_TYPES') THEN
        EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM NOTIFICATION_TYPES' INTO v_n;
        DBMS_OUTPUT.PUT_LINE('NOTIFICATION_TYPES rows      : ' || v_n || ' (expect 16 after this runs)');
        IF v_n = 0 THEN
            DBMS_OUTPUT.PUT_LINE('   -> table exists but is EMPTY: a previous migration stopped partway.');
            DBMS_OUTPUT.PUT_LINE('      Section 2 fills it in. Nothing needs to be dropped first.');
        END IF;
    END IF;
    IF tab_exists('NOTIFICATION_PREFERENCES') THEN
        EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM NOTIFICATION_PREFERENCES' INTO v_n;
        DBMS_OUTPUT.PUT_LINE('NOTIFICATION_PREFERENCES rows: ' || v_n);
    END IF;

    DBMS_OUTPUT.PUT_LINE('---------------------------------------------------------------');

    -- The eight BOOKINGS columns this release requires.
    v_n := 0;
    FOR c IN (SELECT COLUMN_VALUE cn FROM TABLE(SYS.ODCIVARCHAR2LIST(
                'BOOKED_FOR_NAME','BOOKED_FOR_EMAIL','BOOKED_FOR_DEPARTMENT',
                'CANCELLED_AT','CANCELLED_BY','CANCELLATION_REASON',
                'DECIDED_AT','DECIDED_BY'))) LOOP
        IF col_exists('BOOKINGS', c.cn) THEN
            v_n := v_n + 1;
        ELSE
            DBMS_OUTPUT.PUT_LINE('column BOOKINGS.' || RPAD(c.cn,24) || 'will be added (section 3)');
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
        DBMS_OUTPUT.PUT_LINE('SYSTEM_LOGS shape   : *** MISMATCH -- note B, section 7');
    END IF;

    -- Status constraint.
    BEGIN
        SELECT SEARCH_CONDITION INTO v_txt FROM USER_CONSTRAINTS
         WHERE TABLE_NAME = 'BOOKINGS' AND CONSTRAINT_NAME = 'CHK_BOOKINGS_STATUS';
        DBMS_OUTPUT.PUT_LINE('CHK_BOOKINGS_STATUS : ' || SUBSTR(v_txt,1,150));
    EXCEPTION WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('CHK_BOOKINGS_STATUS : ABSENT -- note C, section 8');
    END;

    IF tab_exists('BOOKINGS') THEN
        EXECUTE IMMEDIATE
            'SELECT COUNT(*) FROM BOOKINGS WHERE STATUS IS NOT NULL '
         || 'AND LOWER(STATUS) NOT IN (''pending'',''approved'',''rejected'',''cancelled'',''archived'')'
            INTO v_n;
        DBMS_OUTPUT.PUT_LINE('Rows with a status outside the expected five: ' || v_n
                             || CASE WHEN v_n > 0 THEN '   <-- note C' ELSE '' END);
    END IF;

    DBMS_OUTPUT.PUT_LINE('===============================================================');
    DBMS_OUTPUT.PUT_LINE('Note A: a required table is missing. That is not something this');
    DBMS_OUTPUT.PUT_LINE('        script can create -- it means you are pointed at the wrong');
    DBMS_OUTPUT.PUT_LINE('        database, or the schema was never built here. Stop and check.');
    DBMS_OUTPUT.PUT_LINE('Note B: the bulk-approval audit entry writes ACTION_TYPE,');
    DBMS_OUTPUT.PUT_LINE('        CHANGE_DETAILS, LOG_TIMESTAMP, TABLE_NAME and RECORD_ID.');
    DBMS_OUTPUT.PUT_LINE('        Legacy ACTION/DETAILS/TIMESTAMP columns mean audit writes');
    DBMS_OUTPUT.PUT_LINE('        fail with ORA-00904. Approval still succeeds; you lose the');
    DBMS_OUTPUT.PUT_LINE('        audit trail. Renaming is NOT automatic -- section 7.');
    DBMS_OUTPUT.PUT_LINE('Note C: the application writes lowercase status values. A constraint');
    DBMS_OUTPUT.PUT_LINE('        permitting only Confirmed/Cancelled would make every approval');
    DBMS_OUTPUT.PUT_LINE('        fail with ORA-02290 -- section 8.');
    DBMS_OUTPUT.PUT_LINE('Note D: the table exists but another schema owns it, so you are');
    DBMS_OUTPUT.PUT_LINE('        connected as the wrong user. Reconnect as the owner named.');
    DBMS_OUTPUT.PUT_LINE('===============================================================');

    -- HARD GATE. Everything below alters the CONNECTED schema.
    IF NOT tab_exists('BOOKINGS') THEN
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('*** STOPPING. BOOKINGS is not owned by ' || USER || '. Nothing changed.');
        DBMS_OUTPUT.PUT_LINE('    Reconnect as the schema owner (CONFROOM) and run this again.');
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
PROMPT  SECTION 1 -- Notification preference infrastructure
PROMPT ==========================================================================
PROMPT  NOTIFICATION_TYPES defines every notification the system can send.
PROMPT  ApprovalNotification joins it to resolve recipients, so a missing or
PROMPT  empty table means no approver is ever notified.

DECLARE
    v_count NUMBER;

    PROCEDURE ddl(p_sql VARCHAR2, p_label VARCHAR2) IS
    BEGIN
        EXECUTE IMMEDIATE p_sql;
        DBMS_OUTPUT.PUT_LINE('created ' || p_label);
    EXCEPTION WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('*** could not create ' || p_label || ': ' || SQLERRM);
    END;
BEGIN
    SELECT COUNT(*) INTO v_count FROM USER_TABLES WHERE TABLE_NAME = 'USERS';
    IF v_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('*** SKIPPED -- USERS is not owned by ' || USER || '. Nothing changed.');
        RETURN;
    END IF;

    SELECT COUNT(*) INTO v_count FROM USER_TABLES WHERE TABLE_NAME = 'NOTIFICATION_TYPES';
    IF v_count = 0 THEN
        ddl('CREATE TABLE NOTIFICATION_TYPES (
                TYPE_CODE              VARCHAR2(50) PRIMARY KEY,
                DISPLAY_NAME           VARCHAR2(100) NOT NULL,
                DESCRIPTION            VARCHAR2(500),
                CATEGORY               VARCHAR2(50) NOT NULL,
                DEFAULT_EMAIL_ENABLED  NUMBER(1) DEFAULT 1 CHECK (DEFAULT_EMAIL_ENABLED IN (0,1)),
                DEFAULT_IN_APP_ENABLED NUMBER(1) DEFAULT 1 CHECK (DEFAULT_IN_APP_ENABLED IN (0,1)),
                ADMIN_ONLY             NUMBER(1) DEFAULT 0 CHECK (ADMIN_ONLY IN (0,1)),
                CREATED_AT             TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UPDATED_AT             TIMESTAMP DEFAULT CURRENT_TIMESTAMP
             )', 'NOTIFICATION_TYPES');
    ELSE
        DBMS_OUTPUT.PUT_LINE('skipped NOTIFICATION_TYPES (already present)');
    END IF;

    SELECT COUNT(*) INTO v_count FROM USER_TABLES WHERE TABLE_NAME = 'NOTIFICATION_PREFERENCES';
    IF v_count = 0 THEN
        ddl('CREATE TABLE NOTIFICATION_PREFERENCES (
                NOTIFICATION_ID   NUMBER PRIMARY KEY,
                USER_ID           NUMBER NOT NULL,
                NOTIFICATION_TYPE VARCHAR2(50) NOT NULL,
                EMAIL_ENABLED     NUMBER(1) DEFAULT 1 CHECK (EMAIL_ENABLED IN (0,1)),
                IN_APP_ENABLED    NUMBER(1) DEFAULT 1 CHECK (IN_APP_ENABLED IN (0,1)),
                CREATED_AT        TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UPDATED_AT        TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                CONSTRAINT FK_NOTIF_PREF_USER FOREIGN KEY (USER_ID)
                    REFERENCES USERS(USER_ID) ON DELETE CASCADE,
                CONSTRAINT FK_NOTIF_PREF_TYPE FOREIGN KEY (NOTIFICATION_TYPE)
                    REFERENCES NOTIFICATION_TYPES(TYPE_CODE) ON DELETE CASCADE,
                CONSTRAINT UQ_USER_NOTIF_TYPE UNIQUE (USER_ID, NOTIFICATION_TYPE)
             )', 'NOTIFICATION_PREFERENCES');
    ELSE
        DBMS_OUTPUT.PUT_LINE('skipped NOTIFICATION_PREFERENCES (already present)');
    END IF;

    SELECT COUNT(*) INTO v_count FROM USER_SEQUENCES
     WHERE SEQUENCE_NAME = 'NOTIFICATION_PREFERENCES_SEQ';
    IF v_count = 0 THEN
        ddl('CREATE SEQUENCE NOTIFICATION_PREFERENCES_SEQ START WITH 1 INCREMENT BY 1 NOCACHE',
            'NOTIFICATION_PREFERENCES_SEQ');
    ELSE
        DBMS_OUTPUT.PUT_LINE('skipped NOTIFICATION_PREFERENCES_SEQ (already present)');
    END IF;

    -- The three indexes notification_preferences.sql never reached because it
    -- aborted on the invalid multi-row INSERT above them.
    FOR ix IN (SELECT * FROM TABLE(SYS.ODCIVARCHAR2LIST(
                 'IDX_NOTIF_PREF_USER|NOTIFICATION_PREFERENCES(USER_ID)',
                 'IDX_NOTIF_PREF_TYPE|NOTIFICATION_PREFERENCES(NOTIFICATION_TYPE)',
                 'IDX_NOTIF_TYPES_CATEGORY|NOTIFICATION_TYPES(CATEGORY)'))) LOOP
        DECLARE
            v_name VARCHAR2(128) := REGEXP_SUBSTR(ix.COLUMN_VALUE, '[^|]+', 1, 1);
            v_on   VARCHAR2(200) := REGEXP_SUBSTR(ix.COLUMN_VALUE, '[^|]+', 1, 2);
            v_have NUMBER;
        BEGIN
            SELECT COUNT(*) INTO v_have FROM USER_INDEXES WHERE INDEX_NAME = v_name;
            IF v_have = 0 THEN
                ddl('CREATE INDEX ' || v_name || ' ON ' || v_on, v_name);
            ELSE
                DBMS_OUTPUT.PUT_LINE('skipped ' || v_name || ' (already present)');
            END IF;
        END;
    END LOOP;
END;
/

-- Triggers. CREATE OR REPLACE is inherently idempotent, so these are plain
-- top-level statements. They are kept OUT of a PL/SQL block on purpose: a
-- trigger body contains :NEW bind-style references, which EXECUTE IMMEDIATE
-- handles inconsistently across versions.
CREATE OR REPLACE TRIGGER TRG_NOTIFICATION_PREFERENCES_ID
    BEFORE INSERT ON NOTIFICATION_PREFERENCES
    FOR EACH ROW
BEGIN
    IF :NEW.NOTIFICATION_ID IS NULL THEN
        SELECT NOTIFICATION_PREFERENCES_SEQ.NEXTVAL INTO :NEW.NOTIFICATION_ID FROM DUAL;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER TRG_NOTIFICATION_PREF_UPDATE
    BEFORE UPDATE ON NOTIFICATION_PREFERENCES
    FOR EACH ROW
BEGIN
    :NEW.UPDATED_AT := CURRENT_TIMESTAMP;
END;
/

CREATE OR REPLACE TRIGGER TRG_NOTIFICATION_TYPES_UPDATE
    BEFORE UPDATE ON NOTIFICATION_TYPES
    FOR EACH ROW
BEGIN
    :NEW.UPDATED_AT := CURRENT_TIMESTAMP;
END;
/

PROMPT
PROMPT ==========================================================================
PROMPT  SECTION 2 -- Notification type reference rows (16)
PROMPT ==========================================================================
PROMPT  The last two are new for this release and are what make approver
PROMPT  notification work at all. The other fourteen are the original set that
PROMPT  notification_preferences.sql intended to insert but could not, because
PROMPT  multi-row INSERT ... VALUES is not Oracle syntax.

DECLARE
    TYPE t_tab IS TABLE OF VARCHAR2(800);
    -- code | display name | description | category | email | in-app | admin only
    v t_tab := t_tab(
      'BOOKING_CONFIRMATION|Booking Confirmation|Email sent when a new booking is created|Booking Lifecycle|1|1|0',
      'BOOKING_CANCELLATION|Booking Cancellation|Email sent when a booking is cancelled|Booking Lifecycle|1|1|0',
      'BOOKING_REMINDER|Booking Reminder|Reminder email sent before booking start time|Booking Lifecycle|1|1|0',
      'BOOKING_END_REMINDER|Booking End Reminder|Reminder email sent before booking end time|Booking Lifecycle|1|1|0',
      'BOOKING_APPROVAL_CONFIRMED|Booking Approval Confirmed|Email sent when admin approves a booking|Approval Workflow|1|1|0',
      'BOOKING_REJECTION|Booking Rejection|Email sent when admin rejects a booking|Approval Workflow|1|1|0',
      'NEW_USER_CREATED|New User Account Created|Welcome email sent to new users|User Management|1|1|0',
      'USER_ACCOUNT_UPDATED|User Account Updated|Email sent when user account is modified|User Management|1|1|0',
      'USER_ACCOUNT_DEACTIVATED|User Account Deactivated|Email sent when user account is deactivated|User Management|1|1|0',
      'NEW_USER_ACCESS_REQUEST|New User Access Request|Email sent to admins when new user requests access|User Management|1|1|1',
      'PASSWORD_RESET|Password Reset|Email sent for password reset requests|System|1|0|0',
      'HELP_REQUEST|Help Request|Email sent when user submits help request|System|1|1|1',
      'BULK_NOTIFICATION|Bulk Notification|Custom notifications sent by administrators|Administrative|1|1|0',
      'SYSTEM_MAINTENANCE|System Maintenance|System maintenance and update notifications|Administrative|1|1|0',
      'BOOKING_PENDING_APPROVAL|Booking Pending Approval|Immediate alert sent to approvers when a reservation request is submitted|Approval Workflow|1|1|1',
      'BOOKING_PENDING_APPROVAL_DIGEST|Booking Pending Approval Digest|Recurring summary of reservation requests still awaiting a decision|Approval Workflow|1|0|1'
    );
    v_have  NUMBER;
    v_ins   NUMBER := 0;
    v_total NUMBER;

    FUNCTION fld(p VARCHAR2, n NUMBER) RETURN VARCHAR2 IS
    BEGIN
        RETURN REGEXP_SUBSTR(p, '[^|]+', 1, n);
    END;
BEGIN
    SELECT COUNT(*) INTO v_have FROM USER_TABLES WHERE TABLE_NAME = 'NOTIFICATION_TYPES';
    IF v_have = 0 THEN
        DBMS_OUTPUT.PUT_LINE('*** SKIPPED -- NOTIFICATION_TYPES does not exist. Section 1 could not');
        DBMS_OUTPUT.PUT_LINE('    create it; resolve the error it reported and re-run. Nothing changed.');
        RETURN;
    END IF;

    -- Dynamic, so this block still compiles where the table is absent, and one
    -- guarded statement per row because Oracle has no multi-row VALUES clause.
    FOR i IN 1 .. v.COUNT LOOP
        BEGIN
            EXECUTE IMMEDIATE
                'INSERT INTO NOTIFICATION_TYPES (TYPE_CODE, DISPLAY_NAME, DESCRIPTION,
                     CATEGORY, DEFAULT_EMAIL_ENABLED, DEFAULT_IN_APP_ENABLED, ADMIN_ONLY)
                 SELECT :a, :b, :c, :d, :e, :f, :g FROM DUAL
                  WHERE NOT EXISTS (SELECT 1 FROM NOTIFICATION_TYPES WHERE TYPE_CODE = :h)'
                USING fld(v(i),1), fld(v(i),2), fld(v(i),3), fld(v(i),4),
                      TO_NUMBER(fld(v(i),5)), TO_NUMBER(fld(v(i),6)), TO_NUMBER(fld(v(i),7)),
                      fld(v(i),1);
            IF SQL%ROWCOUNT > 0 THEN
                v_ins := v_ins + 1;
                DBMS_OUTPUT.PUT_LINE('inserted ' || fld(v(i),1));
            END IF;
        EXCEPTION WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('*** failed ' || fld(v(i),1) || ': ' || SQLERRM);
        END;
    END LOOP;

    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM NOTIFICATION_TYPES' INTO v_total;
    DBMS_OUTPUT.PUT_LINE('---------------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('rows inserted this run: ' || v_ins
                         || '   (already present: ' || (v.COUNT - v_ins) || ')');
    DBMS_OUTPUT.PUT_LINE('NOTIFICATION_TYPES now holds ' || v_total || ' rows');
END;
/

COMMIT;

PROMPT
PROMPT ==========================================================================
PROMPT  SECTION 2A -- System notification controls
PROMPT ==========================================================================
PROMPT  THIS SECTION IS NOT OPTIONAL. SystemNotificationManager.shouldSendNotification
PROMPT  is called on every notification, and it SELECTs ENABLED,
PROMPT  CRITICAL_NOTIFICATION, OVERRIDE_USER_PREFERENCES and EMERGENCY_OVERRIDE
PROMPT  from NOTIFICATION_TYPES, then reads SYSTEM_NOTIFICATION_SETTINGS. Its
PROMPT  result struct defaults allow_email and allow_in_app to FALSE and its
PROMPT  exception handler sets only .reason -- so if any of these objects are
PROMPT  missing it fails CLOSED and silently sends nothing at all. No error
PROMPT  surfaces to the user; notifications just never arrive.

DECLARE
    v_count      NUMBER;
    v_addedFlags BOOLEAN := FALSE;
    v_seeded     NUMBER  := 0;

    PROCEDURE ddl(p_sql VARCHAR2, p_label VARCHAR2) IS
    BEGIN
        EXECUTE IMMEDIATE p_sql;
        DBMS_OUTPUT.PUT_LINE('created ' || p_label);
    EXCEPTION WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('*** could not create ' || p_label || ': ' || SQLERRM);
    END;

    FUNCTION have_tab(p VARCHAR2) RETURN BOOLEAN IS
        c NUMBER;
    BEGIN
        SELECT COUNT(*) INTO c FROM USER_TABLES WHERE TABLE_NAME = p;
        RETURN c > 0;
    END;
BEGIN
    IF NOT have_tab('NOTIFICATION_TYPES') OR NOT have_tab('USERS') THEN
        DBMS_OUTPUT.PUT_LINE('*** SKIPPED -- needs NOTIFICATION_TYPES and USERS owned by '
                             || USER || '. Nothing changed.');
        RETURN;
    END IF;

    -- 1. The five control columns on NOTIFICATION_TYPES.
    FOR c IN (SELECT COLUMN_VALUE d FROM TABLE(SYS.ODCIVARCHAR2LIST(
                'ENABLED|NUMBER(1) DEFAULT 1 CHECK (ENABLED IN (0,1))',
                'OVERRIDE_USER_PREFERENCES|NUMBER(1) DEFAULT 0 CHECK (OVERRIDE_USER_PREFERENCES IN (0,1))',
                'CRITICAL_NOTIFICATION|NUMBER(1) DEFAULT 0 CHECK (CRITICAL_NOTIFICATION IN (0,1))',
                'EMERGENCY_OVERRIDE|NUMBER(1) DEFAULT 0 CHECK (EMERGENCY_OVERRIDE IN (0,1))',
                'MAINTENANCE_MODE|NUMBER(1) DEFAULT 0 CHECK (MAINTENANCE_MODE IN (0,1))'))) LOOP
        DECLARE
            v_nm VARCHAR2(128) := REGEXP_SUBSTR(c.d, '[^|]+', 1, 1);
            v_ty VARCHAR2(200) := REGEXP_SUBSTR(c.d, '[^|]+', 1, 2);
        BEGIN
            SELECT COUNT(*) INTO v_count FROM USER_TAB_COLUMNS
             WHERE TABLE_NAME = 'NOTIFICATION_TYPES' AND COLUMN_NAME = v_nm;
            IF v_count = 0 THEN
                EXECUTE IMMEDIATE 'ALTER TABLE NOTIFICATION_TYPES ADD (' || v_nm || ' ' || v_ty || ')';
                DBMS_OUTPUT.PUT_LINE('added   NOTIFICATION_TYPES.' || v_nm);
                v_addedFlags := TRUE;
            ELSE
                DBMS_OUTPUT.PUT_LINE('skipped NOTIFICATION_TYPES.' || v_nm || ' (already present)');
            END IF;
        END;
    END LOOP;

    -- 2. The four control tables and their sequences.
    IF NOT have_tab('SYSTEM_NOTIFICATION_SETTINGS') THEN
        ddl('CREATE TABLE SYSTEM_NOTIFICATION_SETTINGS (
                SETTING_ID       NUMBER PRIMARY KEY,
                SETTING_NAME     VARCHAR2(100) NOT NULL UNIQUE,
                SETTING_VALUE    VARCHAR2(1000),
                SETTING_TYPE     VARCHAR2(50) NOT NULL
                    CHECK (SETTING_TYPE IN (''BOOLEAN'',''INTEGER'',''STRING'',''TIME'',''JSON'')),
                DESCRIPTION      VARCHAR2(500),
                CATEGORY         VARCHAR2(100) NOT NULL
                    CHECK (CATEGORY IN (''SYSTEM'',''EMAIL'',''IN_APP'',''USER_EXPERIENCE'',''ANALYTICS'',
                                        ''SECURITY'',''LIMITS'',''PERFORMANCE'',''RELIABILITY'')),
                IS_ACTIVE        NUMBER(1) DEFAULT 1 CHECK (IS_ACTIVE IN (0,1)),
                REQUIRES_RESTART NUMBER(1) DEFAULT 0 CHECK (REQUIRES_RESTART IN (0,1)),
                CREATED_BY       NUMBER NOT NULL,
                CREATED_AT       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UPDATED_BY       NUMBER,
                UPDATED_AT       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                CONSTRAINT FK_SYSTEM_SETTINGS_CREATOR FOREIGN KEY (CREATED_BY) REFERENCES USERS(USER_ID),
                CONSTRAINT FK_SYSTEM_SETTINGS_UPDATER FOREIGN KEY (UPDATED_BY) REFERENCES USERS(USER_ID)
             )', 'SYSTEM_NOTIFICATION_SETTINGS');
    ELSE
        DBMS_OUTPUT.PUT_LINE('skipped SYSTEM_NOTIFICATION_SETTINGS (already present)');
    END IF;

    IF NOT have_tab('NOTIFICATION_SCHEDULES') THEN
        ddl('CREATE TABLE NOTIFICATION_SCHEDULES (
                SCHEDULE_ID        NUMBER PRIMARY KEY,
                NOTIFICATION_TYPE  VARCHAR2(50) NOT NULL,
                ACTION             VARCHAR2(20) NOT NULL CHECK (ACTION IN (''ENABLE'',''DISABLE'',''PAUSE'')),
                START_TIME         TIMESTAMP NOT NULL,
                END_TIME           TIMESTAMP,
                RECURRENCE_PATTERN VARCHAR2(100),
                IS_ACTIVE          NUMBER(1) DEFAULT 1 CHECK (IS_ACTIVE IN (0,1)),
                CREATED_BY         NUMBER NOT NULL,
                CREATED_AT         TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UPDATED_BY         NUMBER,
                UPDATED_AT         TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                CONSTRAINT FK_NOTIF_SCHEDULE_TYPE FOREIGN KEY (NOTIFICATION_TYPE)
                    REFERENCES NOTIFICATION_TYPES(TYPE_CODE) ON DELETE CASCADE,
                CONSTRAINT FK_NOTIF_SCHEDULE_CREATOR FOREIGN KEY (CREATED_BY) REFERENCES USERS(USER_ID),
                CONSTRAINT FK_NOTIF_SCHEDULE_UPDATER FOREIGN KEY (UPDATED_BY) REFERENCES USERS(USER_ID)
             )', 'NOTIFICATION_SCHEDULES');
    ELSE
        DBMS_OUTPUT.PUT_LINE('skipped NOTIFICATION_SCHEDULES (already present)');
    END IF;

    IF NOT have_tab('NOTIFICATION_ANALYTICS') THEN
        ddl('CREATE TABLE NOTIFICATION_ANALYTICS (
                ANALYTICS_ID      NUMBER PRIMARY KEY,
                NOTIFICATION_TYPE VARCHAR2(50) NOT NULL,
                DELIVERY_METHOD   VARCHAR2(20) NOT NULL
                    CHECK (DELIVERY_METHOD IN (''EMAIL'',''IN_APP'',''BOTH'')),
                TOTAL_SENT        NUMBER DEFAULT 0,
                TOTAL_DELIVERED   NUMBER DEFAULT 0,
                TOTAL_FAILED      NUMBER DEFAULT 0,
                TOTAL_OPENED      NUMBER DEFAULT 0,
                ANALYTICS_DATE    DATE NOT NULL,
                CREATED_AT        TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UPDATED_AT        TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                CONSTRAINT FK_NOTIF_ANALYTICS_TYPE FOREIGN KEY (NOTIFICATION_TYPE)
                    REFERENCES NOTIFICATION_TYPES(TYPE_CODE) ON DELETE CASCADE,
                CONSTRAINT UQ_ANALYTICS_DATE_TYPE UNIQUE (NOTIFICATION_TYPE, DELIVERY_METHOD, ANALYTICS_DATE)
             )', 'NOTIFICATION_ANALYTICS');
    ELSE
        DBMS_OUTPUT.PUT_LINE('skipped NOTIFICATION_ANALYTICS (already present)');
    END IF;

    IF NOT have_tab('USER_NOTIFICATION_SETTINGS') THEN
        ddl('CREATE TABLE USER_NOTIFICATION_SETTINGS (
                SETTING_ID    NUMBER PRIMARY KEY,
                USER_ID       NUMBER NOT NULL,
                SETTING_NAME  VARCHAR2(100) NOT NULL,
                SETTING_VALUE VARCHAR2(1000),
                SETTING_TYPE  VARCHAR2(50) NOT NULL
                    CHECK (SETTING_TYPE IN (''BOOLEAN'',''INTEGER'',''STRING'',''TIME'',''JSON'')),
                CREATED_AT    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UPDATED_AT    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                CONSTRAINT FK_USER_NOTIF_SETTINGS_USER FOREIGN KEY (USER_ID)
                    REFERENCES USERS(USER_ID) ON DELETE CASCADE,
                CONSTRAINT UQ_USER_SETTING_NAME UNIQUE (USER_ID, SETTING_NAME)
             )', 'USER_NOTIFICATION_SETTINGS');
    ELSE
        DBMS_OUTPUT.PUT_LINE('skipped USER_NOTIFICATION_SETTINGS (already present)');
    END IF;

    FOR s IN (SELECT COLUMN_VALUE sn FROM TABLE(SYS.ODCIVARCHAR2LIST(
                'SYSTEM_NOTIFICATION_SETTINGS_SEQ','NOTIFICATION_SCHEDULES_SEQ',
                'NOTIFICATION_ANALYTICS_SEQ','USER_NOTIFICATION_SETTINGS_SEQ'))) LOOP
        SELECT COUNT(*) INTO v_count FROM USER_SEQUENCES WHERE SEQUENCE_NAME = s.sn;
        IF v_count = 0 THEN
            ddl('CREATE SEQUENCE ' || s.sn || ' START WITH 1 INCREMENT BY 1 NOCACHE', s.sn);
        ELSE
            DBMS_OUTPUT.PUT_LINE('skipped ' || s.sn || ' (already present)');
        END IF;
    END LOOP;

    -- 3. Indexes.
    FOR ix IN (SELECT COLUMN_VALUE d FROM TABLE(SYS.ODCIVARCHAR2LIST(
                 'IDX_SYSTEM_SETTINGS_NAME|SYSTEM_NOTIFICATION_SETTINGS(SETTING_NAME)',
                 'IDX_SYSTEM_SETTINGS_CATEGORY|SYSTEM_NOTIFICATION_SETTINGS(CATEGORY)',
                 'IDX_NOTIF_TYPES_ENABLED|NOTIFICATION_TYPES(ENABLED)',
                 'IDX_NOTIF_TYPES_CRITICAL|NOTIFICATION_TYPES(CRITICAL_NOTIFICATION)',
                 'IDX_NOTIF_SCHEDULE_ACTIVE|NOTIFICATION_SCHEDULES(IS_ACTIVE)',
                 'IDX_NOTIF_SCHEDULE_START|NOTIFICATION_SCHEDULES(START_TIME)',
                 'IDX_NOTIF_ANALYTICS_DATE|NOTIFICATION_ANALYTICS(ANALYTICS_DATE)',
                 'IDX_USER_NOTIF_SETTINGS_USER|USER_NOTIFICATION_SETTINGS(USER_ID)'))) LOOP
        DECLARE
            v_nm VARCHAR2(128) := REGEXP_SUBSTR(ix.d, '[^|]+', 1, 1);
            v_on VARCHAR2(200) := REGEXP_SUBSTR(ix.d, '[^|]+', 1, 2);
        BEGIN
            SELECT COUNT(*) INTO v_count FROM USER_INDEXES WHERE INDEX_NAME = v_nm;
            IF v_count = 0 THEN
                ddl('CREATE INDEX ' || v_nm || ' ON ' || v_on, v_nm);
            ELSE
                DBMS_OUTPUT.PUT_LINE('skipped ' || v_nm || ' (already present)');
            END IF;
        END;
    END LOOP;

    -- 4. Default system settings. NOTIFICATIONS_ENABLED in particular is the
    --    master switch areNotificationsEnabled() reads; without the row, every
    --    notification is treated as globally disabled.
    IF have_tab('SYSTEM_NOTIFICATION_SETTINGS') THEN
        FOR st IN (SELECT COLUMN_VALUE d FROM TABLE(SYS.ODCIVARCHAR2LIST(
            'NOTIFICATIONS_ENABLED|1|BOOLEAN|Master switch for all notifications system-wide|SYSTEM',
            'EMAIL_NOTIFICATIONS_ENABLED|1|BOOLEAN|Global switch for email notifications|EMAIL',
            'IN_APP_NOTIFICATIONS_ENABLED|1|BOOLEAN|Global switch for in-app notifications|IN_APP',
            'MAINTENANCE_MODE|0|BOOLEAN|System maintenance mode - only critical notifications allowed|SYSTEM',
            'EMERGENCY_MODE|0|BOOLEAN|Emergency mode - override all user preferences for critical notifications|SYSTEM',
            'MAX_DAILY_NOTIFICATIONS_PER_USER|50|INTEGER|Maximum number of notifications per user per day|LIMITS',
            'BULK_NOTIFICATION_BATCH_SIZE|100|INTEGER|Number of notifications to process in each batch|PERFORMANCE',
            'NOTIFICATION_RETRY_ATTEMPTS|3|INTEGER|Number of retry attempts for failed notifications|RELIABILITY',
            'QUIET_HOURS_START|22:00|TIME|Start time for quiet hours (no non-critical notifications)|USER_EXPERIENCE',
            'QUIET_HOURS_END|08:00|TIME|End time for quiet hours|USER_EXPERIENCE'))) LOOP
            BEGIN
                EXECUTE IMMEDIATE
                    'INSERT INTO SYSTEM_NOTIFICATION_SETTINGS
                         (SETTING_NAME, SETTING_VALUE, SETTING_TYPE, DESCRIPTION, CATEGORY, CREATED_BY)
                     SELECT :a, :b, :c, :d, :e,
                            (SELECT MIN(u.USER_ID) FROM USERS u JOIN ROLES r ON u.ROLE_ID = r.ROLE_ID
                              WHERE UPPER(r.ROLE_NAME) = ''SITE ADMIN'')
                       FROM DUAL
                      WHERE EXISTS (SELECT 1 FROM USERS u JOIN ROLES r ON u.ROLE_ID = r.ROLE_ID
                                     WHERE UPPER(r.ROLE_NAME) = ''SITE ADMIN'')
                        AND NOT EXISTS (SELECT 1 FROM SYSTEM_NOTIFICATION_SETTINGS
                                         WHERE SETTING_NAME = :f)'
                    USING REGEXP_SUBSTR(st.d,'[^|]+',1,1), REGEXP_SUBSTR(st.d,'[^|]+',1,2),
                          REGEXP_SUBSTR(st.d,'[^|]+',1,3), REGEXP_SUBSTR(st.d,'[^|]+',1,4),
                          REGEXP_SUBSTR(st.d,'[^|]+',1,5), REGEXP_SUBSTR(st.d,'[^|]+',1,1);
                v_seeded := v_seeded + SQL%ROWCOUNT;
            EXCEPTION WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('*** setting ' || REGEXP_SUBSTR(st.d,'[^|]+',1,1)
                                     || ' failed: ' || SQLERRM);
            END;
        END LOOP;
        DBMS_OUTPUT.PUT_LINE('system settings inserted: ' || v_seeded);

        EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM SYSTEM_NOTIFICATION_SETTINGS' INTO v_count;
        IF v_count = 0 THEN
            DBMS_OUTPUT.PUT_LINE('*** WARNING: SYSTEM_NOTIFICATION_SETTINGS is EMPTY.');
            DBMS_OUTPUT.PUT_LINE('    CREATED_BY is NOT NULL and references a Site Admin, so the');
            DBMS_OUTPUT.PUT_LINE('    seed inserts nothing when no user holds the Site Admin role.');
            DBMS_OUTPUT.PUT_LINE('    Without the NOTIFICATIONS_ENABLED row every notification is');
            DBMS_OUTPUT.PUT_LINE('    treated as globally disabled. Create a Site Admin and re-run.');
        END IF;
    END IF;

    -- 5. Classify the notification types -- ONLY when the flag columns were
    --    added by this run. On a re-run the flags may have been tuned by an
    --    administrator through the UI, and blindly re-applying the defaults
    --    would silently discard that.
    IF v_addedFlags THEN
        EXECUTE IMMEDIATE q'[
            UPDATE NOTIFICATION_TYPES SET
                ENABLED = 1,
                CRITICAL_NOTIFICATION = CASE WHEN TYPE_CODE IN
                    ('BOOKING_CONFIRMATION','BOOKING_CANCELLATION','BOOKING_REJECTION','PASSWORD_RESET')
                    THEN 1 ELSE 0 END,
                OVERRIDE_USER_PREFERENCES = CASE WHEN TYPE_CODE IN
                    ('SYSTEM_MAINTENANCE','NEW_USER_ACCESS_REQUEST')
                    THEN 1 ELSE 0 END]';
        DBMS_OUTPUT.PUT_LINE('classified ' || SQL%ROWCOUNT || ' notification types (flags were new)');
    ELSE
        DBMS_OUTPUT.PUT_LINE('left notification type flags untouched (columns already existed --');
        DBMS_OUTPUT.PUT_LINE('  an administrator may have tuned them; not overwriting)');
    END IF;
END;
/

COMMIT;

-- Triggers for the four control tables. Top-level CREATE OR REPLACE, for the
-- same reason as section 1's: idempotent by nature, and a trigger body's :NEW
-- references do not survive EXECUTE IMMEDIATE reliably.
CREATE OR REPLACE TRIGGER TRG_SYSTEM_SETTINGS_ID
    BEFORE INSERT ON SYSTEM_NOTIFICATION_SETTINGS
    FOR EACH ROW
BEGIN
    IF :NEW.SETTING_ID IS NULL THEN
        SELECT SYSTEM_NOTIFICATION_SETTINGS_SEQ.NEXTVAL INTO :NEW.SETTING_ID FROM DUAL;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER TRG_SYSTEM_SETTINGS_UPDATE
    BEFORE UPDATE ON SYSTEM_NOTIFICATION_SETTINGS
    FOR EACH ROW
BEGIN
    :NEW.UPDATED_AT := CURRENT_TIMESTAMP;
END;
/

CREATE OR REPLACE TRIGGER TRG_NOTIF_SCHEDULE_ID
    BEFORE INSERT ON NOTIFICATION_SCHEDULES
    FOR EACH ROW
BEGIN
    IF :NEW.SCHEDULE_ID IS NULL THEN
        SELECT NOTIFICATION_SCHEDULES_SEQ.NEXTVAL INTO :NEW.SCHEDULE_ID FROM DUAL;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER TRG_NOTIF_SCHEDULE_UPDATE
    BEFORE UPDATE ON NOTIFICATION_SCHEDULES
    FOR EACH ROW
BEGIN
    :NEW.UPDATED_AT := CURRENT_TIMESTAMP;
END;
/

CREATE OR REPLACE TRIGGER TRG_NOTIF_ANALYTICS_ID
    BEFORE INSERT ON NOTIFICATION_ANALYTICS
    FOR EACH ROW
BEGIN
    IF :NEW.ANALYTICS_ID IS NULL THEN
        SELECT NOTIFICATION_ANALYTICS_SEQ.NEXTVAL INTO :NEW.ANALYTICS_ID FROM DUAL;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER TRG_NOTIF_ANALYTICS_UPDATE
    BEFORE UPDATE ON NOTIFICATION_ANALYTICS
    FOR EACH ROW
BEGIN
    :NEW.UPDATED_AT := CURRENT_TIMESTAMP;
END;
/

CREATE OR REPLACE TRIGGER TRG_USER_NOTIF_SETTINGS_ID
    BEFORE INSERT ON USER_NOTIFICATION_SETTINGS
    FOR EACH ROW
BEGIN
    IF :NEW.SETTING_ID IS NULL THEN
        SELECT USER_NOTIFICATION_SETTINGS_SEQ.NEXTVAL INTO :NEW.SETTING_ID FROM DUAL;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER TRG_USER_NOTIF_SETTINGS_UPDATE
    BEFORE UPDATE ON USER_NOTIFICATION_SETTINGS
    FOR EACH ROW
BEGIN
    :NEW.UPDATED_AT := CURRENT_TIMESTAMP;
END;
/

-- Views. CREATE OR REPLACE is idempotent.
CREATE OR REPLACE VIEW VW_ACTIVE_NOTIFICATION_TYPES AS
SELECT
    nt.*,
    CASE
        WHEN sns_global.SETTING_VALUE = '0' THEN 0
        WHEN sns_maint.SETTING_VALUE = '1' AND nt.CRITICAL_NOTIFICATION = 0 THEN 0
        WHEN nt.ENABLED = 0 THEN 0
        ELSE 1
    END AS IS_CURRENTLY_ACTIVE,
    sns_global.SETTING_VALUE AS GLOBAL_NOTIFICATIONS_ENABLED,
    sns_maint.SETTING_VALUE AS MAINTENANCE_MODE_ACTIVE
FROM NOTIFICATION_TYPES nt
CROSS JOIN (SELECT SETTING_VALUE FROM SYSTEM_NOTIFICATION_SETTINGS
             WHERE SETTING_NAME = 'NOTIFICATIONS_ENABLED') sns_global
CROSS JOIN (SELECT SETTING_VALUE FROM SYSTEM_NOTIFICATION_SETTINGS
             WHERE SETTING_NAME = 'MAINTENANCE_MODE') sns_maint;

CREATE OR REPLACE VIEW VW_EFFECTIVE_USER_PREFERENCES AS
SELECT
    u.USER_ID, u.FIRST_NAME, u.LAST_NAME, u.EMAIL,
    nt.TYPE_CODE, nt.DISPLAY_NAME, nt.CATEGORY,
    nt.ENABLED AS TYPE_ENABLED,
    nt.CRITICAL_NOTIFICATION,
    nt.OVERRIDE_USER_PREFERENCES,
    COALESCE(np.EMAIL_ENABLED,  nt.DEFAULT_EMAIL_ENABLED)  AS EMAIL_ENABLED,
    COALESCE(np.IN_APP_ENABLED, nt.DEFAULT_IN_APP_ENABLED) AS IN_APP_ENABLED,
    CASE WHEN nt.OVERRIDE_USER_PREFERENCES = 1 THEN 1
         WHEN nt.ENABLED = 0 THEN 0
         ELSE COALESCE(np.EMAIL_ENABLED, nt.DEFAULT_EMAIL_ENABLED) END AS EFFECTIVE_EMAIL_ENABLED,
    CASE WHEN nt.OVERRIDE_USER_PREFERENCES = 1 THEN 1
         WHEN nt.ENABLED = 0 THEN 0
         ELSE COALESCE(np.IN_APP_ENABLED, nt.DEFAULT_IN_APP_ENABLED) END AS EFFECTIVE_IN_APP_ENABLED
FROM USERS u
JOIN ROLES r ON u.ROLE_ID = r.ROLE_ID
CROSS JOIN NOTIFICATION_TYPES nt
LEFT JOIN NOTIFICATION_PREFERENCES np
       ON u.USER_ID = np.USER_ID AND nt.TYPE_CODE = np.NOTIFICATION_TYPE
WHERE u.STATUS = 'Active'
  AND (nt.ADMIN_ONLY = 0 OR UPPER(r.ROLE_NAME) IN ('ADMIN','SITE ADMIN'));

PROMPT
PROMPT ==========================================================================
PROMPT  SECTION 3 -- BOOKINGS: Reservation-For and decision/cancellation audit
PROMPT ==========================================================================
PROMPT  Purely additive. Every column is nullable with no default, so existing
PROMPT  rows are untouched and simply carry NULL, which the application treats
PROMPT  as "not recorded" and falls back to the requester.

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
    SELECT COUNT(*) INTO v_count FROM USER_TABLES WHERE TABLE_NAME = 'BOOKINGS';
    IF v_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('*** SKIPPED -- BOOKINGS is not owned by ' || USER || '. Nothing changed.');
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
-- APPROVED_BY deliberately gets no foreign key: the archiving job used to write
-- APPROVED_BY = 0, so historical rows may hold an id that does not exist and
-- adding the constraint would fail validation. See
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
PROMPT  SECTION 4 -- NOTIFICATION_REMINDER_LOG
PROMPT ==========================================================================
PROMPT  Provides duplicate suppression for approver reminders. The unique
PROMPT  constraint is the mechanism: the reminder job inserts its claim row
PROMPT  BEFORE sending, so when two scheduler runs overlap exactly one wins and
PROMPT  the other skips. That guarantee holds across processes and servers,
PROMPT  which an application-level lock cannot.

DECLARE
    v_count NUMBER;
BEGIN
    -- This table's foreign key points at USERS, so it can only be built in the
    -- schema that owns it.
    SELECT COUNT(*) INTO v_count FROM USER_TABLES WHERE TABLE_NAME IN ('BOOKINGS','USERS');
    IF v_count < 2 THEN
        DBMS_OUTPUT.PUT_LINE('*** SKIPPED -- BOOKINGS/USERS are not owned by ' || USER || '. Nothing changed.');
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
PROMPT  SECTION 5 -- Admin notification preferences for existing users
PROMPT ==========================================================================
PROMPT  Replicates what notification_preferences.sql intended, with its role
PROMPT  filter corrected: it tested USERS.ROLE, a column that does not exist.
PROMPT  USERS has ROLE_ID, which joins to ROLES.ROLE_NAME. Role names are
PROMPT  compared case-insensitively because the data holds mixed case
PROMPT  ("Site Admin", "Admin") while parts of the application use upper case.

DECLARE
    v_have NUMBER;
    v_ins  NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_have FROM USER_TABLES
     WHERE TABLE_NAME IN ('NOTIFICATION_PREFERENCES','NOTIFICATION_TYPES','USERS','ROLES');
    IF v_have < 4 THEN
        DBMS_OUTPUT.PUT_LINE('*** SKIPPED -- need NOTIFICATION_PREFERENCES, NOTIFICATION_TYPES,');
        DBMS_OUTPUT.PUT_LINE('    USERS and ROLES all owned by ' || USER || '. Nothing changed.');
        RETURN;
    END IF;

    -- The FK to NOTIFICATION_TYPES means the type row must exist first; if
    -- section 2 could not insert it, insert nothing here rather than fail.
    EXECUTE IMMEDIATE
        'SELECT COUNT(*) FROM NOTIFICATION_TYPES WHERE TYPE_CODE = ''NEW_USER_ACCESS_REQUEST'''
        INTO v_have;
    IF v_have = 0 THEN
        DBMS_OUTPUT.PUT_LINE('*** SKIPPED -- NEW_USER_ACCESS_REQUEST is not in NOTIFICATION_TYPES.');
        DBMS_OUTPUT.PUT_LINE('    Fix section 2 first. Nothing changed.');
        RETURN;
    END IF;

    EXECUTE IMMEDIATE q'[
        INSERT INTO NOTIFICATION_PREFERENCES (USER_ID, NOTIFICATION_TYPE, EMAIL_ENABLED, IN_APP_ENABLED)
        SELECT u.USER_ID, 'NEW_USER_ACCESS_REQUEST', 1, 1
          FROM USERS u
          JOIN ROLES r ON u.ROLE_ID = r.ROLE_ID
         WHERE UPPER(r.ROLE_NAME) IN ('ADMIN','SITE ADMIN')
           AND u.STATUS = 'Active'
           AND NOT EXISTS (SELECT 1 FROM NOTIFICATION_PREFERENCES np
                            WHERE np.USER_ID = u.USER_ID
                              AND np.NOTIFICATION_TYPE = 'NEW_USER_ACCESS_REQUEST')]';
    v_ins := SQL%ROWCOUNT;
    DBMS_OUTPUT.PUT_LINE('admin preference rows inserted: ' || v_ins);

    -- Approvers deliberately get NO explicit rows for the two pending-approval
    -- types. The application treats an absent preference as "use the type
    -- default", and both default to enabled, so inserting rows here would only
    -- freeze today's defaults and pre-empt a choice each admin can still make
    -- on the preferences page.
    DBMS_OUTPUT.PUT_LINE('(no rows written for the pending-approval types -- absent means');
    DBMS_OUTPUT.PUT_LINE(' "use the type default", which is enabled, and stays user-editable)');
END;
/

COMMIT;

PROMPT
PROMPT ==========================================================================
PROMPT  SECTION 6 -- Grants (only where the grantee exists)
PROMPT ==========================================================================
PROMPT  The application components connect with explicit schema-owner
PROMPT  credentials, so these grants are not required for this release. They are
PROMPT  applied for consistency with the original migration, and skipped
PROMPT  silently where the grantee does not exist in this database.

DECLARE
    v_exists NUMBER;
BEGIN
    -- CONFROOM_USER only, matching the original migration exactly.
    -- WEBSCHEDULE_USER is deliberately NOT granted anything here. It is the
    -- login the web datasource authenticates as, but the components pass
    -- explicit schema-owner credentials on every query, so it needs no access
    -- to these tables. Granting it DML would widen access for no benefit.
    FOR g IN (SELECT COLUMN_VALUE gn FROM TABLE(SYS.ODCIVARCHAR2LIST(
                'CONFROOM_USER'))) LOOP
        SELECT COUNT(*) INTO v_exists FROM ALL_USERS WHERE USERNAME = g.gn;
        IF v_exists = 0 THEN
            DBMS_OUTPUT.PUT_LINE('skipped grants to ' || g.gn || ' (no such user here)');
        ELSIF g.gn = USER THEN
            DBMS_OUTPUT.PUT_LINE('skipped grants to ' || g.gn || ' (that is us -- owner already has full access)');
        ELSE
            FOR o IN (SELECT COLUMN_VALUE obj FROM TABLE(SYS.ODCIVARCHAR2LIST(
                        'NOTIFICATION_TYPES','NOTIFICATION_PREFERENCES','NOTIFICATION_REMINDER_LOG',
                        'SYSTEM_NOTIFICATION_SETTINGS','NOTIFICATION_SCHEDULES',
                        'NOTIFICATION_ANALYTICS','USER_NOTIFICATION_SETTINGS'))) LOOP
                BEGIN
                    EXECUTE IMMEDIATE 'GRANT SELECT, INSERT, UPDATE, DELETE ON '
                                   || o.obj || ' TO ' || g.gn;
                    DBMS_OUTPUT.PUT_LINE('granted DML on ' || RPAD(o.obj,30) || ' to ' || g.gn);
                EXCEPTION WHEN OTHERS THEN
                    DBMS_OUTPUT.PUT_LINE('*** grant on ' || o.obj || ' to ' || g.gn
                                         || ' failed: ' || SQLERRM);
                END;
            END LOOP;
            FOR o IN (SELECT COLUMN_VALUE obj FROM TABLE(SYS.ODCIVARCHAR2LIST(
                        'NOTIFICATION_PREFERENCES_SEQ','SYSTEM_NOTIFICATION_SETTINGS_SEQ',
                        'NOTIFICATION_SCHEDULES_SEQ','NOTIFICATION_ANALYTICS_SEQ',
                        'USER_NOTIFICATION_SETTINGS_SEQ','VW_ACTIVE_NOTIFICATION_TYPES',
                        'VW_EFFECTIVE_USER_PREFERENCES'))) LOOP
                BEGIN
                    EXECUTE IMMEDIATE 'GRANT SELECT ON ' || o.obj || ' TO ' || g.gn;
                    DBMS_OUTPUT.PUT_LINE('granted SELECT on ' || RPAD(o.obj,30) || ' to ' || g.gn);
                EXCEPTION WHEN OTHERS THEN
                    DBMS_OUTPUT.PUT_LINE('*** grant on ' || o.obj || ' to ' || g.gn
                                         || ' failed: ' || SQLERRM);
                END;
            END LOOP;
        END IF;
    END LOOP;
END;
/

PROMPT
PROMPT ==========================================================================
PROMPT  SECTION 7 -- SYSTEM_LOGS shape (REPORT ONLY -- no automatic change)
PROMPT ==========================================================================

DECLARE
    v_new NUMBER;
    v_old NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_new FROM USER_TAB_COLUMNS
     WHERE TABLE_NAME = 'SYSTEM_LOGS'
       AND COLUMN_NAME IN ('ACTION_TYPE','CHANGE_DETAILS','LOG_TIMESTAMP','TABLE_NAME','RECORD_ID');
    SELECT COUNT(*) INTO v_old FROM USER_TAB_COLUMNS
     WHERE TABLE_NAME = 'SYSTEM_LOGS'
       AND COLUMN_NAME IN ('ACTION','DETAILS','TIMESTAMP');

    IF v_new = 5 THEN
        DBMS_OUTPUT.PUT_LINE('SYSTEM_LOGS: OK -- all 5 expected columns present.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('*** ACTION REQUIRED. SYSTEM_LOGS has ' || v_new || ' of the 5 expected columns');
        DBMS_OUTPUT.PUT_LINE('    (' || v_old || ' legacy columns found).');
        DBMS_OUTPUT.PUT_LINE('    The bulk-approval audit entry writes:');
        DBMS_OUTPUT.PUT_LINE('      USER_ID, ACTION_TYPE, CHANGE_DETAILS, TABLE_NAME, RECORD_ID, LOG_TIMESTAMP');
        DBMS_OUTPUT.PUT_LINE('    Missing columns cause ORA-00904 and the audit entry is skipped.');
        DBMS_OUTPUT.PUT_LINE('    Approval itself still succeeds -- writeAuditEntry logs and swallows');
        DBMS_OUTPUT.PUT_LINE('    the failure -- so this is NOT release-blocking, but you lose the');
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
PROMPT  SECTION 8 -- BOOKINGS.STATUS constraint (REPORT ONLY -- no automatic change)
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
        RETURN;
    END IF;

    SELECT COUNT(*) INTO v_present FROM USER_CONSTRAINTS
     WHERE TABLE_NAME = 'BOOKINGS' AND CONSTRAINT_NAME = 'CHK_BOOKINGS_STATUS';

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
            DBMS_OUTPUT.PUT_LINE('    application writes (lowercase pending/approved/rejected/');
            DBMS_OUTPUT.PUT_LINE('    cancelled/archived). Every approval will fail with ORA-02290.');
            DBMS_OUTPUT.PUT_LINE('    Deciding this needs a human: replacing a live constraint and');
            DBMS_OUTPUT.PUT_LINE('    normalising existing rows is not done automatically.');
        END IF;
    ELSE
        DBMS_OUTPUT.PUT_LINE('No CHK_BOOKINGS_STATUS constraint exists on this database.');
        DBMS_OUTPUT.PUT_LINE('-> Nothing enforces the status vocabulary, so approvals will NOT');
        DBMS_OUTPUT.PUT_LINE('   fail with ORA-02290. No action needed for this release.');
    END IF;

    DBMS_OUTPUT.PUT_LINE('Rows with a status outside the expected five: ' || v_bad);
    DBMS_OUTPUT.PUT_LINE('Rows whose status is not lowercase          : ' || v_mixed);
    IF v_bad > 0 OR v_mixed > 0 THEN
        DBMS_OUTPUT.PUT_LINE('    These rows are inert for this release: bulk approval and the');
        DBMS_OUTPUT.PUT_LINE('    reminder job only touch ''pending'', and the detail view displays');
        DBMS_OUTPUT.PUT_LINE('    status as stored. But do NOT add CHK_BOOKINGS_STATUS later without');
        DBMS_OUTPUT.PUT_LINE('    first deciding what to do with them -- it would fail validation.');
        DBMS_OUTPUT.PUT_LINE('    To see them:');
        DBMS_OUTPUT.PUT_LINE('      SELECT STATUS, COUNT(*) FROM BOOKINGS GROUP BY STATUS;');
    END IF;
END;
/

PROMPT
PROMPT ==========================================================================
PROMPT  SECTION 9 -- POST-FLIGHT VERIFICATION
PROMPT ==========================================================================

DECLARE
    v_cols  NUMBER; v_tab NUMBER; v_uq NUMBER;
    v_types NUMBER; v_pend NUMBER; v_prefTab NUMBER; v_seq NUMBER; v_trg NUMBER;
    v_ctlTab NUMBER; v_ctlCol NUMBER; v_views NUMBER; v_master NUMBER;
    v_ok    BOOLEAN;
BEGIN
    SELECT COUNT(*) INTO v_cols FROM USER_TAB_COLUMNS
     WHERE TABLE_NAME = 'BOOKINGS'
       AND COLUMN_NAME IN ('BOOKED_FOR_NAME','BOOKED_FOR_EMAIL','BOOKED_FOR_DEPARTMENT',
                           'CANCELLED_AT','CANCELLED_BY','CANCELLATION_REASON','DECIDED_AT','DECIDED_BY');
    SELECT COUNT(*) INTO v_tab      FROM USER_TABLES WHERE TABLE_NAME = 'NOTIFICATION_REMINDER_LOG';
    SELECT COUNT(*) INTO v_prefTab  FROM USER_TABLES WHERE TABLE_NAME = 'NOTIFICATION_PREFERENCES';
    SELECT COUNT(*) INTO v_uq       FROM USER_CONSTRAINTS WHERE CONSTRAINT_NAME = 'UQ_REMINDER_ONCE_PER_INTERVAL';
    SELECT COUNT(*) INTO v_seq      FROM USER_SEQUENCES WHERE SEQUENCE_NAME = 'NOTIFICATION_PREFERENCES_SEQ';
    SELECT COUNT(*) INTO v_trg      FROM USER_TRIGGERS
     WHERE TRIGGER_NAME IN ('TRG_NOTIFICATION_PREFERENCES_ID','TRG_NOTIFICATION_PREF_UPDATE',
                            'TRG_NOTIFICATION_TYPES_UPDATE')
       AND STATUS = 'ENABLED';

    -- Dynamic: a static reference would stop this verification block from
    -- compiling on a database where the table is missing, so the report whose
    -- job is to TELL you it is missing would never print.
    BEGIN
        EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM NOTIFICATION_TYPES' INTO v_types;
        EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM NOTIFICATION_TYPES '
                       || 'WHERE TYPE_CODE LIKE ''BOOKING_PENDING_APPROVAL%''' INTO v_pend;
    EXCEPTION WHEN OTHERS THEN
        v_types := -1; v_pend := -1;
    END;

    DBMS_OUTPUT.PUT_LINE('BOOKINGS audit columns          : ' || v_cols || ' of 8   ' || CASE WHEN v_cols=8 THEN 'OK' ELSE '*** INCOMPLETE' END);
    DBMS_OUTPUT.PUT_LINE('NOTIFICATION_PREFERENCES table  : ' || v_prefTab || ' of 1   ' || CASE WHEN v_prefTab=1 THEN 'OK' ELSE '*** MISSING' END);
    DBMS_OUTPUT.PUT_LINE('NOTIFICATION_PREFERENCES_SEQ    : ' || v_seq || ' of 1   ' || CASE WHEN v_seq=1 THEN 'OK' ELSE '*** MISSING' END);
    DBMS_OUTPUT.PUT_LINE('Notification triggers enabled   : ' || v_trg || ' of 3   ' || CASE WHEN v_trg=3 THEN 'OK' ELSE '*** INCOMPLETE' END);
    DBMS_OUTPUT.PUT_LINE('NOTIFICATION_REMINDER_LOG       : ' || v_tab || ' of 1   ' || CASE WHEN v_tab=1 THEN 'OK' ELSE '*** MISSING' END);
    DBMS_OUTPUT.PUT_LINE('UQ_REMINDER_ONCE_PER_INTERVAL   : ' || v_uq || ' of 1   ' || CASE WHEN v_uq=1 THEN 'OK' ELSE '*** MISSING' END);
    IF v_types < 0 THEN
        DBMS_OUTPUT.PUT_LINE('NOTIFICATION_TYPES rows         : *** MISSING OR UNREADABLE');
    ELSE
        DBMS_OUTPUT.PUT_LINE('NOTIFICATION_TYPES rows         : ' || v_types || ' of 16  ' || CASE WHEN v_types>=16 THEN 'OK' ELSE '*** INCOMPLETE' END);
        DBMS_OUTPUT.PUT_LINE('Pending-approval type rows      : ' || v_pend || ' of 2   ' || CASE WHEN v_pend=2 THEN 'OK' ELSE '*** INCOMPLETE' END);
    END IF;

    -- The system-control objects. shouldSendNotification fails CLOSED without
    -- these, so a deployment missing them looks healthy and silently sends
    -- nothing. They are part of the READY verdict, not an optional extra.
    SELECT COUNT(*) INTO v_ctlTab FROM USER_TABLES
     WHERE TABLE_NAME IN ('SYSTEM_NOTIFICATION_SETTINGS','NOTIFICATION_SCHEDULES',
                          'NOTIFICATION_ANALYTICS','USER_NOTIFICATION_SETTINGS');
    SELECT COUNT(*) INTO v_ctlCol FROM USER_TAB_COLUMNS
     WHERE TABLE_NAME = 'NOTIFICATION_TYPES'
       AND COLUMN_NAME IN ('ENABLED','OVERRIDE_USER_PREFERENCES','CRITICAL_NOTIFICATION',
                           'EMERGENCY_OVERRIDE','MAINTENANCE_MODE');
    SELECT COUNT(*) INTO v_views FROM USER_VIEWS
     WHERE VIEW_NAME IN ('VW_ACTIVE_NOTIFICATION_TYPES','VW_EFFECTIVE_USER_PREFERENCES');

    BEGIN
        EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM SYSTEM_NOTIFICATION_SETTINGS '
                       || 'WHERE SETTING_NAME = ''NOTIFICATIONS_ENABLED''' INTO v_master;
    EXCEPTION WHEN OTHERS THEN
        v_master := -1;
    END;

    DBMS_OUTPUT.PUT_LINE('NOTIFICATION_TYPES control cols : ' || v_ctlCol || ' of 5   ' || CASE WHEN v_ctlCol=5 THEN 'OK' ELSE '*** INCOMPLETE' END);
    DBMS_OUTPUT.PUT_LINE('System control tables           : ' || v_ctlTab || ' of 4   ' || CASE WHEN v_ctlTab=4 THEN 'OK' ELSE '*** INCOMPLETE' END);
    DBMS_OUTPUT.PUT_LINE('Notification views              : ' || v_views || ' of 2   ' || CASE WHEN v_views=2 THEN 'OK' ELSE '*** INCOMPLETE' END);
    IF v_master = 1 THEN
        DBMS_OUTPUT.PUT_LINE('NOTIFICATIONS_ENABLED setting   : present   OK');
    ELSE
        DBMS_OUTPUT.PUT_LINE('NOTIFICATIONS_ENABLED setting   : *** MISSING -- notifications are');
        DBMS_OUTPUT.PUT_LINE('                                  treated as globally disabled');
    END IF;

    v_ok := (v_cols = 8 AND v_prefTab = 1 AND v_seq = 1 AND v_trg = 3
             AND v_tab = 1 AND v_uq = 1 AND v_types >= 16 AND v_pend = 2
             AND v_ctlCol = 5 AND v_ctlTab = 4 AND v_views = 2 AND v_master = 1);

    DBMS_OUTPUT.PUT_LINE('---------------------------------------------------------------');
    IF v_ok THEN
        DBMS_OUTPUT.PUT_LINE('RESULT: READY. The schema supports the application code.');
        DBMS_OUTPUT.PUT_LINE('Re-read sections 7 and 8 before deploying -- neither is fixed');
        DBMS_OUTPUT.PUT_LINE('automatically, and section 8 can still block approvals.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('RESULT: *** NOT READY. Resolve the items marked above and re-run.');
        DBMS_OUTPUT.PUT_LINE('Re-running is safe: every step is guarded and skips what exists.');
    END IF;
END;
/

COMMIT;

SET FEEDBACK ON

PROMPT
PROMPT ==========================================================================
PROMPT  ROLLBACK
PROMPT ==========================================================================
PROMPT  Dropping these permanently discards every recorded Reservation For value,
PROMPT  cancellation reason, approval audit entry and notification preference.
PROMPT  Export anything you may need first:
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
PROMPT
PROMPT  To remove ONLY this release's notification types, leaving the preference
PROMPT  system in place (usually what you want):
PROMPT    DELETE FROM NOTIFICATION_TYPES
PROMPT     WHERE TYPE_CODE IN ('BOOKING_PENDING_APPROVAL','BOOKING_PENDING_APPROVAL_DIGEST');
PROMPT    COMMIT;
PROMPT
PROMPT  Removing the preference and control system entirely is a bigger step and
PROMPT  takes the user-notification-preferences and admin-notification-control
PROMPT  pages with it:
PROMPT    DROP VIEW  VW_EFFECTIVE_USER_PREFERENCES;
PROMPT    DROP VIEW  VW_ACTIVE_NOTIFICATION_TYPES;
PROMPT    DROP TABLE USER_NOTIFICATION_SETTINGS CASCADE CONSTRAINTS;
PROMPT    DROP TABLE NOTIFICATION_ANALYTICS CASCADE CONSTRAINTS;
PROMPT    DROP TABLE NOTIFICATION_SCHEDULES CASCADE CONSTRAINTS;
PROMPT    DROP TABLE SYSTEM_NOTIFICATION_SETTINGS CASCADE CONSTRAINTS;
PROMPT    DROP TABLE NOTIFICATION_PREFERENCES CASCADE CONSTRAINTS;
PROMPT    DROP TABLE NOTIFICATION_TYPES CASCADE CONSTRAINTS;
PROMPT    DROP SEQUENCE NOTIFICATION_PREFERENCES_SEQ;
PROMPT    DROP SEQUENCE SYSTEM_NOTIFICATION_SETTINGS_SEQ;
PROMPT    DROP SEQUENCE NOTIFICATION_SCHEDULES_SEQ;
PROMPT    DROP SEQUENCE NOTIFICATION_ANALYTICS_SEQ;
PROMPT    DROP SEQUENCE USER_NOTIFICATION_SETTINGS_SEQ;
PROMPT    (dropping the tables drops their triggers with them)
PROMPT
PROMPT  To drop ONLY the five control columns, leaving the tables:
PROMPT    ALTER TABLE NOTIFICATION_TYPES DROP (ENABLED, OVERRIDE_USER_PREFERENCES,
PROMPT          CRITICAL_NOTIFICATION, EMERGENCY_OVERRIDE, MAINTENANCE_MODE);
PROMPT    (the two views reference these columns -- drop the views first)
PROMPT
PROMPT  Deleting a NOTIFICATION_TYPES row cascades to every per-user preference
PROMPT  saved against it. Rolling back also requires reverting the application
PROMPT  code, or cancellation, the detail view and bulk approval will fail with
PROMPT  ORA-00904.
PROMPT ==========================================================================
