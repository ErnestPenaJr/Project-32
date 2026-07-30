-- Migration: Reservation-For and decision/cancellation audit columns
-- Table:     CONFROOM.BOOKINGS
-- Date:      2026-07-29
--
-- Purpose
-- -------
-- Adds the columns behind three requirements:
--   * "Reservation For"  -> BOOKED_FOR_NAME / BOOKED_FOR_EMAIL / BOOKED_FOR_DEPARTMENT
--   * Cancellation detail -> CANCELLED_AT / CANCELLED_BY / CANCELLATION_REASON
--   * Approval audit trail -> DECIDED_AT / DECIDED_BY
--
-- IMPORTANT -- why this file exists
-- ---------------------------------
-- These eight columns were already present in the DEVELOPMENT database
-- (inside2_docmd) when this work began, but no migration in assets/sql/ creates
-- them. They were applied out of band. This script reproduces that change so
-- staging (inside2_docms) and production (inside2_docmp) can be brought in line.
--
-- Run this BEFORE deploying the code that reads and writes these columns.
-- Without it, cancelBooking, getBookingDetail, createBooking and the approval
-- audit trail will all fail with ORA-00904 (invalid identifier).
--
-- Widths below match what is live in development, verified by querying
-- ALL_TAB_COLUMNS -- do not narrow them.
--
-- Safety
-- ------
-- Purely additive. Every column is nullable with no default, so existing rows
-- are untouched and no data is rewritten or lost. Existing reservations simply
-- carry NULL, which the application treats as "not recorded" and falls back to
-- the requester.
--
-- Apply
-- -----
--   sqlplus CONFROOM/<password>@<tns> @add_reservation_for_and_decision_audit.sql
--
-- This script is NOT idempotent: re-running it raises ORA-01430 (column already
-- exists). Check first with the verification query at the bottom, or run the
-- guarded PL/SQL block instead of the plain ALTER below.

ALTER TABLE BOOKINGS ADD (
    BOOKED_FOR_NAME       VARCHAR2(200),
    BOOKED_FOR_EMAIL      VARCHAR2(255),
    BOOKED_FOR_DEPARTMENT VARCHAR2(100),
    CANCELLED_AT          TIMESTAMP,
    CANCELLED_BY          NUMBER,
    CANCELLATION_REASON   VARCHAR2(1000),
    DECIDED_AT            TIMESTAMP,
    DECIDED_BY            NUMBER
);

-- Referential integrity for the two user references. Named to match the
-- existing FK_BOOKINGS_* convention.
ALTER TABLE BOOKINGS ADD CONSTRAINT FK_BOOKINGS_CANCELLED_BY
    FOREIGN KEY (CANCELLED_BY) REFERENCES USERS(USER_ID);

ALTER TABLE BOOKINGS ADD CONSTRAINT FK_BOOKINGS_DECIDED_BY
    FOREIGN KEY (DECIDED_BY) REFERENCES USERS(USER_ID);

COMMENT ON COLUMN BOOKINGS.BOOKED_FOR_NAME IS
    'Display name of the person the reservation is for. NULL on records created before this field existed; the application then falls back to the requester.';
COMMENT ON COLUMN BOOKINGS.BOOKED_FOR_EMAIL IS
    'Email address of the person the reservation is for.';
COMMENT ON COLUMN BOOKINGS.BOOKED_FOR_DEPARTMENT IS
    'Department or team of the person the reservation is for.';
COMMENT ON COLUMN BOOKINGS.CANCELLED_AT IS
    'Timestamp the reservation was cancelled.';
COMMENT ON COLUMN BOOKINGS.CANCELLED_BY IS
    'USER_ID of whoever cancelled the reservation.';
COMMENT ON COLUMN BOOKINGS.CANCELLATION_REASON IS
    'Optional reason supplied at cancellation. Included in the requester notification. Stored separately so COMMENTS keeps the requester original meeting purpose.';
COMMENT ON COLUMN BOOKINGS.DECIDED_AT IS
    'Timestamp the approve/reject decision was recorded.';
COMMENT ON COLUMN BOOKINGS.DECIDED_BY IS
    'USER_ID of the approver who decided the request.';

COMMIT;


-- ---------------------------------------------------------------------------
-- Guarded alternative (safe to re-run) -- use instead of the ALTER above if you
-- are unsure whether a given environment already has some of these columns.
-- ---------------------------------------------------------------------------
-- DECLARE
--     TYPE col_list IS TABLE OF VARCHAR2(200);
--     cols col_list := col_list(
--         'BOOKED_FOR_NAME VARCHAR2(200)',
--         'BOOKED_FOR_EMAIL VARCHAR2(255)',
--         'BOOKED_FOR_DEPARTMENT VARCHAR2(100)',
--         'CANCELLED_AT TIMESTAMP',
--         'CANCELLED_BY NUMBER',
--         'CANCELLATION_REASON VARCHAR2(1000)',
--         'DECIDED_AT TIMESTAMP',
--         'DECIDED_BY NUMBER'
--     );
--     v_name  VARCHAR2(128);
--     v_count NUMBER;
-- BEGIN
--     FOR i IN 1 .. cols.COUNT LOOP
--         v_name := UPPER(REGEXP_SUBSTR(cols(i), '^\S+'));
--         SELECT COUNT(*) INTO v_count FROM USER_TAB_COLUMNS
--          WHERE TABLE_NAME = 'BOOKINGS' AND COLUMN_NAME = v_name;
--         IF v_count = 0 THEN
--             EXECUTE IMMEDIATE 'ALTER TABLE BOOKINGS ADD (' || cols(i) || ')';
--         END IF;
--     END LOOP;
-- END;
-- /


-- ---------------------------------------------------------------------------
-- Verification -- expect 8 rows
-- ---------------------------------------------------------------------------
-- SELECT COLUMN_NAME, DATA_TYPE, DATA_LENGTH, NULLABLE
--   FROM USER_TAB_COLUMNS
--  WHERE TABLE_NAME = 'BOOKINGS'
--    AND COLUMN_NAME IN ('BOOKED_FOR_NAME','BOOKED_FOR_EMAIL','BOOKED_FOR_DEPARTMENT',
--                        'CANCELLED_AT','CANCELLED_BY','CANCELLATION_REASON',
--                        'DECIDED_AT','DECIDED_BY')
--  ORDER BY COLUMN_NAME;


-- ---------------------------------------------------------------------------
-- ROLLBACK
-- ---------------------------------------------------------------------------
-- WARNING: dropping these columns permanently discards every recorded
-- "Reservation For" value, cancellation reason, and approval audit entry. Those
-- cannot be reconstructed from anywhere else. Export them first if there is any
-- chance they are needed:
--
--   CREATE TABLE BOOKINGS_AUDIT_BACKUP AS
--   SELECT BOOKING_ID, BOOKED_FOR_NAME, BOOKED_FOR_EMAIL, BOOKED_FOR_DEPARTMENT,
--          CANCELLED_AT, CANCELLED_BY, CANCELLATION_REASON, DECIDED_AT, DECIDED_BY
--     FROM BOOKINGS
--    WHERE BOOKED_FOR_NAME IS NOT NULL
--       OR CANCELLATION_REASON IS NOT NULL
--       OR DECIDED_BY IS NOT NULL;
--
-- Then, in this order:
--
--   ALTER TABLE BOOKINGS DROP CONSTRAINT FK_BOOKINGS_CANCELLED_BY;
--   ALTER TABLE BOOKINGS DROP CONSTRAINT FK_BOOKINGS_DECIDED_BY;
--   ALTER TABLE BOOKINGS DROP COLUMN BOOKED_FOR_NAME;
--   ALTER TABLE BOOKINGS DROP COLUMN BOOKED_FOR_EMAIL;
--   ALTER TABLE BOOKINGS DROP COLUMN BOOKED_FOR_DEPARTMENT;
--   ALTER TABLE BOOKINGS DROP COLUMN CANCELLED_AT;
--   ALTER TABLE BOOKINGS DROP COLUMN CANCELLED_BY;
--   ALTER TABLE BOOKINGS DROP COLUMN CANCELLATION_REASON;
--   ALTER TABLE BOOKINGS DROP COLUMN DECIDED_AT;
--   ALTER TABLE BOOKINGS DROP COLUMN DECIDED_BY;
--   COMMIT;
--
-- Rolling back also requires reverting the application code that reads these
-- columns (cfcs/dashboard-data.cfc and assets/cfc/approvals.cfc), otherwise
-- cancellation, the dashboard detail view, and bulk approval will all throw
-- ORA-00904.
