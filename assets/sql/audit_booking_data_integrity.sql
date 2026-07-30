-- Data integrity audit for CONFROOM.BOOKINGS
-- Date: 2026-07-29
--
-- READ ONLY. Every statement is a SELECT. Nothing is inserted, updated or
-- deleted, so this is safe to run against staging and production.
--
-- WHY THIS EXISTS
-- ---------------
-- Several defects fixed in this work were silently corrupting or failing to
-- record data for an unknown length of time. Fixing the code does not repair
-- rows already written. This script quantifies the damage so you can decide
-- whether any of it needs correcting.
--
--   * Room.checkAvailability and the edit-booking conflict check both filtered on
--     STATUS = 'Confirmed', a value CHK_BOOKINGS_STATUS no longer permits. They
--     matched nothing, so overlapping reservations could be created or edited into
--     existence with no warning. Query 1 finds them.
--   * cancelBooking overwrote COMMENTS with 'Cancelled by <name>', destroying the
--     requester's meeting purpose. Query 4 counts the rows that lost it.
--   * Approval never recorded DECIDED_BY / DECIDED_AT, and cancellation never
--     recorded CANCELLED_BY / CANCELLED_AT, before this work. Queries 5 and 6
--     show how much history is missing.
--   * BOOKINGS.APPROVED_BY has no foreign key, so it can reference a user that no
--     longer exists. Query 7 checks.
--
-- Run each query and review the counts. A non-zero result is not automatically a
-- problem -- see the note under each one.

SET LINESIZE 200
SET PAGESIZE 100

PROMPT ============================================================
PROMPT 1. DOUBLE-BOOKINGS: overlapping live reservations in one room
PROMPT ============================================================
-- The important one. Two reservations that hold the same room at overlapping
-- times. 'pending' counts as holding the slot, matching the conflict rules the
-- application now enforces.
--
-- Any row here is a genuine clash that the dead conflict check allowed through.
-- Decide per row which reservation should keep the slot.
SELECT a.BOOKING_ID        AS BOOKING_A,
       b.BOOKING_ID        AS BOOKING_B,
       a.ROOM_ID,
       r.ROOM_NAME,
       TO_CHAR(a.START_TIME, 'YYYY-MM-DD HH24:MI') AS A_START,
       TO_CHAR(a.END_TIME,   'HH24:MI')            AS A_END,
       a.STATUS            AS A_STATUS,
       TO_CHAR(b.START_TIME, 'YYYY-MM-DD HH24:MI') AS B_START,
       TO_CHAR(b.END_TIME,   'HH24:MI')            AS B_END,
       b.STATUS            AS B_STATUS
  FROM BOOKINGS a
  JOIN BOOKINGS b
    ON b.ROOM_ID    = a.ROOM_ID
   AND b.BOOKING_ID > a.BOOKING_ID          -- each pair once, not twice
   AND b.START_TIME < a.END_TIME
   AND b.END_TIME   > a.START_TIME
  JOIN ROOMS r ON r.ROOM_ID = a.ROOM_ID
 WHERE LOWER(a.STATUS) IN ('pending', 'approved')
   AND LOWER(b.STATUS) IN ('pending', 'approved')
 ORDER BY a.ROOM_ID, a.START_TIME;

PROMPT ============================================================
PROMPT 1a. Double-bookings still in the future (act on these first)
PROMPT ============================================================
SELECT COUNT(*) AS FUTURE_CLASHING_PAIRS
  FROM BOOKINGS a
  JOIN BOOKINGS b
    ON b.ROOM_ID    = a.ROOM_ID
   AND b.BOOKING_ID > a.BOOKING_ID
   AND b.START_TIME < a.END_TIME
   AND b.END_TIME   > a.START_TIME
 WHERE LOWER(a.STATUS) IN ('pending', 'approved')
   AND LOWER(b.STATUS) IN ('pending', 'approved')
   AND a.START_TIME > SYSTIMESTAMP;

PROMPT ============================================================
PROMPT 2. Status values outside CHK_BOOKINGS_STATUS
PROMPT ============================================================
-- Should be empty. A non-empty result means the constraint is absent or disabled
-- in this environment, which also means the approval fix is required here.
SELECT STATUS, COUNT(*) AS ROWS_WITH_STATUS
  FROM BOOKINGS
 GROUP BY STATUS
 ORDER BY ROWS_WITH_STATUS DESC;

PROMPT ============================================================
PROMPT 2a. Is the constraint actually present in this environment?
PROMPT ============================================================
-- If this returns no row, approvals were failing here with ORA-02290 only if the
-- constraint exists elsewhere -- confirm before assuming the environments match.
SELECT CONSTRAINT_NAME, STATUS AS CONSTRAINT_STATE, SEARCH_CONDITION
  FROM USER_CONSTRAINTS
 WHERE TABLE_NAME = 'BOOKINGS'
   AND CONSTRAINT_TYPE = 'C'
   AND CONSTRAINT_NAME = 'CHK_BOOKINGS_STATUS';

PROMPT ============================================================
PROMPT 3. Reservations ending before they start
PROMPT ============================================================
-- No constraint prevents this. Should be empty.
SELECT BOOKING_ID, ROOM_ID, STATUS,
       TO_CHAR(START_TIME, 'YYYY-MM-DD HH24:MI') AS START_TIME,
       TO_CHAR(END_TIME,   'YYYY-MM-DD HH24:MI') AS END_TIME
  FROM BOOKINGS
 WHERE END_TIME <= START_TIME
 ORDER BY BOOKING_ID;

PROMPT ============================================================
PROMPT 4. Meeting purpose destroyed by the old cancellation code
PROMPT ============================================================
-- The previous cancelBooking replaced COMMENTS with 'Cancelled by <name>'. The
-- original purpose is not recoverable from this table. This is a count of the
-- loss, for the record; there is nothing to repair.
SELECT COUNT(*) AS PURPOSE_OVERWRITTEN_ON_CANCEL
  FROM BOOKINGS
 WHERE COMMENTS LIKE 'Cancelled by %';

PROMPT ============================================================
PROMPT 5. Cancelled reservations with no cancellation audit trail
PROMPT ============================================================
-- Rows cancelled before CANCELLED_BY / CANCELLED_AT were populated. Expected to
-- be non-zero on any environment with history; informational only.
SELECT COUNT(*) AS CANCELLED_WITHOUT_AUDIT
  FROM BOOKINGS
 WHERE LOWER(STATUS) = 'cancelled'
   AND (CANCELLED_BY IS NULL OR CANCELLED_AT IS NULL);

PROMPT ============================================================
PROMPT 6. Approved reservations with no decision audit trail
PROMPT ============================================================
-- Rows approved before DECIDED_BY / DECIDED_AT were populated. Note: if approval
-- was failing with ORA-02290 in this environment, there may be very few approved
-- rows at all -- which is itself the finding.
SELECT COUNT(*) AS APPROVED_WITHOUT_AUDIT
  FROM BOOKINGS
 WHERE LOWER(STATUS) = 'approved'
   AND (DECIDED_BY IS NULL OR DECIDED_AT IS NULL);

PROMPT ============================================================
PROMPT 7. Orphaned user references
PROMPT ============================================================
-- APPROVED_BY has no foreign key, so it can point at a deleted user.
-- CANCELLED_BY and DECIDED_BY do have FKs and should always return zero.
SELECT 'APPROVED_BY'  AS COLUMN_CHECKED, COUNT(*) AS ORPHANED_ROWS
  FROM BOOKINGS b
 WHERE b.APPROVED_BY IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM USERS u WHERE u.USER_ID = b.APPROVED_BY)
UNION ALL
SELECT 'DECIDED_BY', COUNT(*)
  FROM BOOKINGS b
 WHERE b.DECIDED_BY IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM USERS u WHERE u.USER_ID = b.DECIDED_BY)
UNION ALL
SELECT 'CANCELLED_BY', COUNT(*)
  FROM BOOKINGS b
 WHERE b.CANCELLED_BY IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM USERS u WHERE u.USER_ID = b.CANCELLED_BY);

PROMPT ============================================================
PROMPT 8. Reservation-For adoption
PROMPT ============================================================
-- Rows predating the field carry NULL and fall back to the requester in the UI.
-- Purely informational.
SELECT
    COUNT(*)                                                   AS TOTAL_ROWS,
    SUM(CASE WHEN BOOKED_FOR_NAME IS NULL THEN 1 ELSE 0 END)   AS NO_RESERVATION_FOR,
    SUM(CASE WHEN BOOKED_FOR_NAME IS NOT NULL THEN 1 ELSE 0 END) AS HAS_RESERVATION_FOR
  FROM BOOKINGS;

PROMPT ============================================================
PROMPT 9. Are the columns this code needs actually present?
PROMPT ============================================================
-- Expect 8 rows. Fewer means add_reservation_for_and_decision_audit.sql has not
-- been applied here, and the new code will fail with ORA-00904.
SELECT COLUMN_NAME, DATA_TYPE, DATA_LENGTH, NULLABLE
  FROM USER_TAB_COLUMNS
 WHERE TABLE_NAME = 'BOOKINGS'
   AND COLUMN_NAME IN ('BOOKED_FOR_NAME','BOOKED_FOR_EMAIL','BOOKED_FOR_DEPARTMENT',
                       'CANCELLED_AT','CANCELLED_BY','CANCELLATION_REASON',
                       'DECIDED_AT','DECIDED_BY')
 ORDER BY COLUMN_NAME;


-- ===========================================================================
-- OPTIONAL REMEDIATION — review before running. These DO modify data.
-- Everything above this line is read-only; everything below is not.
-- ===========================================================================
--
-- R1. Orphaned APPROVED_BY = 0 left by the old CalendarCleanUp
-- -----------------------------------------------------------
-- The archiving job used to write APPROVED_BY = 0. There is no USER_ID 0, so
-- those rows hold a reference to a user that does not exist, and the identity of
-- the real approver was overwritten and is NOT recoverable. Setting the column to
-- NULL is more honest than leaving 0: it says "unknown" rather than "user 0".
--
-- Count first:
--   SELECT COUNT(*) FROM BOOKINGS WHERE APPROVED_BY = 0;
--
-- Then, if you want them cleared:
--   UPDATE BOOKINGS SET APPROVED_BY = NULL WHERE APPROVED_BY = 0;
--   COMMIT;
--
-- Rollback is not possible — the previous value was already the meaningless 0.
-- Doing nothing is also defensible; the code no longer writes 0, so the count
-- will not grow.
--
--
-- R2. Meeting purposes destroyed by the old cancel and archive jobs
-- ----------------------------------------------------------------
-- COMMENTS was overwritten with 'Cancelled by <name>' or
-- 'Auto-Archived: End time passed'. The original purpose is not stored anywhere
-- else in this table. **There is nothing to repair** — this is recorded only so
-- the loss is known. Both write paths are now fixed and no further rows will be
-- affected.
--
-- If BOOKING_REVISIONS or an equivalent history table exists in your
-- environment, an earlier COMMENTS value may be recoverable from it; check
-- before assuming the data is gone for good.
--
--
-- R3. Double-bookings found by query 1
-- ------------------------------------
-- Do NOT bulk-resolve these. Each pair needs a human decision about which
-- reservation keeps the room, and the losing requester should be told. Cancel
-- through the application (cfcs/dashboard-data.cfc?method=cancelBooking) rather
-- than by direct UPDATE, so the requester is notified and the cancellation is
-- recorded with a reason.
